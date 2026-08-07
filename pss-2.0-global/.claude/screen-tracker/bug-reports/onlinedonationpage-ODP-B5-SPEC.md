# ODP-B5 — "Captured ≠ Recorded" Auto-Promotion — Design & Build Spec

> **Screen:** #10 Online Donation Page (EXTERNAL_PAGE / DONATION_PAGE) — already COMPLETED.
> **Type:** BE-enhancement spec (adapted `/plan-screens`). Not a fresh 12-section screen build.
> **Status:** DESIGN — for review. **Migration specced, NOT run. Nothing committed.**
> **Date:** 2026-07-14

---

## ① Problem Statement

A successful public donation (`ConfirmOnlineDonation` mutation, or a recurring-cycle gateway webhook)
writes **only** an `fund.OnlineDonationStaging` row. The `fund.GlobalDonation` that every total,
receipt, and recurring-cycle rollup reads is created **only when staff manually resolve the staging
row** in the Donation Inbox (#175).

Consequences:
- **Totals understated** — `totalRaised` / `donorCount` / `lastDonationAt` per page ignore captured-but-unresolved donations.
- **No receipts** — `ConfirmOnlineDonation` returns `ReceiptNumber = null`; receipt generation is impossible until manual resolution.
- **Recurring cycles vanish** — Braintree `SUBSCRIPTION_CHARGED_SUCCESSFULLY` and Razorpay
  `subscription.charged` update only `RecurringDonationSchedule` counters (+ a Razorpay `PaymentTransaction`);
  **neither writes a `GlobalDonation`.** Only the PayU Hangfire cron writes a per-cycle ledger row today.

**Goal:** a captured payment auto-creates the `GlobalDonation` at capture time, idempotently, for both
one-time and recurring cycles, without waiting on staff.

---

## ② Decisive Constraint (why we can't just call the existing command)

`CreateGlobalDonationWithChildrenCommand`
(`Base.Application/.../GlobalDonations/Commands/CreateGlobalDonationWithChildren.cs`):

- Carries `[CustomAuthorize(DecoratorDonationModules.GlobalDonation, Permissions.Create)]` (line 15).
- Sources CompanyId **exclusively** from `httpContextAccessor.GetCurrentUserStaffCompanyId()` (line 232),
  which reads the `"CurrentCompanyId"` claim **only when `IsAuthenticated`, else returns `0`**.
- CompanyId is deliberately **absent** from the request DTO.

⟹ It **cannot** be invoked from the anonymous public `ConfirmOnlineDonation` mutation or from
`[AllowAnonymous]` webhook controllers. It would stamp `CompanyId = 0` and the auth gate rejects the
unauthenticated caller. The manual inbox path works only because staff invoke it with an authenticated
HttpContext.

**This single fact drives the whole design:** we must extract a CompanyId-parameterized core.

---

## ③ Architecture

### 3.1 New shared writer — `IGlobalDonationCompositeWriter`

Extract the entity-building core of `CreateGlobalDonationWithChildren` into an internal service.

```
Base.Application/Business/DonationBusiness/GlobalDonations/Services/
    IGlobalDonationCompositeWriter.cs
    GlobalDonationCompositeWriter.cs
```

```csharp
public interface IGlobalDonationCompositeWriter
{
    // Server-trusted CompanyId passed explicitly — NEVER read from HttpContext here.
    Task<GlobalDonation> WriteAsync(
        CreateGlobalDonationWithChildrenRequestDto payload,
        int companyId,
        CancellationToken ct);
}
```

`WriteAsync` owns exactly what the command owns today (moved verbatim, minus the `[CustomAuthorize]`
attribute and the `GetCurrentUserStaffCompanyId()` call):
- `CreateExecutionStrategy()` (NpgsqlRetryingExecutionStrategy is on) + own `BeginTransactionAsync` that commits.
- Fan `companyId` (the **param**) to parent + all children.
- `ReceiptNumber` generation, unconditional for all modes:
  `NumberSequenceGenerator.GenerateAsync(dbContext, companyId, "GLOBALDONATION", payload.Donation.DonationDate, ct)`.
- `DetachGlobalDonationBackRefs` after commit (Mapster cycle break).
- Keep the RECURRING donation-**type** hard-block intact (never triggers here — see §5).

**Refactor of the existing command:** `CreateGlobalDonationWithChildrenCommand` keeps its
`[CustomAuthorize]` attribute and its `httpContextAccessor.GetCurrentUserStaffCompanyId()` call, then
delegates to `writer.WriteAsync(payload, companyId, ct)`. **Behaviorally identical** for the manual
inbox path — no regression to #175.

### 3.2 New internal command — `PromoteOnlineDonationStagingCommand`

```
Base.Application/Business/DonationBusiness/OnlineDonations/Commands/
    PromoteOnlineDonationStaging.cs
```

- **No `[CustomAuthorize]`.** Internal-only; invoked from server-trusted contexts (public mutation /
  webhooks), never exposed as a GraphQL mutation.
- Takes `int OnlineDonationStagingId` (+ optional `int? contactIdOverride`, `string? gatewayTransactionIdOverride`
  for cycle webhooks that carry their own txn id).
- Loads the staging row; builds `CreateGlobalDonationWithChildrenRequestDto` from staging fields
  (mirrors `ResolveOnlineDonationStaging` step-5 mapping: DonationMode/Type = ONETIMEDONATION, amount,
  currency, FX via `IFxRateService.GetRateAsync`, page-source FK backfill, GlobalOnlineDonation child
  with gateway txn fields).
- Calls `writer.WriteAsync(payload, staging.CompanyId, ct)` — **CompanyId from `staging.CompanyId`,
  server-trusted, never HttpContext.**
- Sets `staging.PromotedGlobalDonationId`, `staging.ReceivedDate`; leaves `IsResolved`/`ResolvedContactId`
  to the contact policy (§4).
- Reuses the CF-H5 orphan-compensation and page-source/junction backfill logic from
  `ResolveOnlineDonationStaging` (extract into a shared helper if duplication is heavy).

---

## ④ Contact Policy (anonymous donor → Contact)

Staging carries donor fields: `ProvidedEmail` (required), `ProvidedFirstName`, `ProvidedLastName`,
`ProvidedPhone`, `ProvidedOrganization`, `ProvidedContactCode`, `IsAnonymous`.
**Email is a child collection** — match against `corg.ContactEmailAddresses.Email` (CompanyId-scoped),
not a scalar on `Contact`.

| Case | Policy |
|------|--------|
| **Recurring** (`staging.FrequencyId.HasValue`) | Contact **REQUIRED** (RecurringDonationSchedule needs a `ResolvedContactId`). Resolve: (1) `ProvidedContactCode` exact match → Contact; else (2) unique `ContactEmailAddresses.Email == ProvidedEmail` (CompanyId, `IsDeleted=false`) → its ContactId; else (3) **auto-create** Contact + primary ContactEmailAddress from staging donor fields. |
| **One-time** | **Best-effort.** Steps (1)+(2) only. On miss → `ContactId = null` (schema permits; `GlobalDonation.ContactId` nullable). No auto-create. |

**Auto-create Contact shape** (recurring miss): required non-nullables are `CompanyId`,
`ContactBaseTypeId` (INDIVIDUAL), `PrimaryCountryId` (from page/tenant default), `ContactStatusId`
(ACTIVE). Names from `ProvidedFirstName`/`ProvidedLastName`; `DisplayName` composed. Then insert a
`ContactEmailAddress` (`Email = ProvidedEmail`, `IsPrimary = true`, `EmailTypeId` = PERSONAL,
`IsVerified = false`, same CompanyId). Confirm MasterData TypeCodes against existing seeds before build.

---

## ⑤ Recurring — donation-type & schedule ordering

- Online donations record as **DONATIONTYPE / ONETIMEDONATION** per cycle (matches
  `ResolveOnlineDonationStaging` step 5 and the PayU cron). So the writer's RECURRING donation-**type**
  hard-block never triggers — each cycle = one ONETIMEDONATION-typed `GlobalDonation`.
- **Ordering fix:** move `CreateRecurringDonationScheduleCommand` out of manual `ResolveOnlineDonationStaging`
  and into the **first-cycle auto-promotion** (inside/after `PromoteOnlineDonationStagingCommand` when
  `staging.FrequencyId.HasValue`). This guarantees the schedule exists before any subsequent webhook
  cycle looks it up by `GatewaySubscriptionId` + CompanyId.
  - Keep manual-resolve capable of creating the schedule too, but **idempotently** (get-or-create by
    `GatewaySubscriptionId` + CompanyId) so a manual resolution after auto-promotion doesn't double-insert.

---

## ⑥ Injection Points

| Trigger | Path | Action |
|---------|------|--------|
| **One-time capture** | `ConfirmOnlineDonation` mutation (public) | After staging set COMPLETED + ReceivedDate, call `PromoteOnlineDonationStagingCommand`. Return the generated `ReceiptNumber` (no longer null). |
| **Recurring first cycle** | `ConfirmOnlineDonation` (subscription setup capture) | Same promote call; also create the RecurringDonationSchedule (§5). |
| **Recurring subsequent cycles — Braintree** | `PaymentWebhookController` `SUBSCRIPTION_CHARGED_SUCCESSFULLY` (lines 174-183) | After updating schedule counters, build a per-cycle `GlobalDonation` **directly** via `writer.WriteAsync(payload, companyId, ct)` — CompanyId from the gateway-config tenant resolution (URL `{companyCode}` → CompanyPaymentGateways), ContactId from the schedule's `ResolvedContactId`, GatewayTransactionId from the webhook. Mirrors the PayU cron. |
| **Recurring subsequent cycles — Razorpay** | `RazorpayWebhookController` `subscription.charged` (lines 318-371) | Same: after the existing schedule-counter + idempotent `PaymentTransaction` insert, add a per-cycle `GlobalDonation` via the writer. |
| **Recurring — PayU** | `PayURecurringChargeService` cron | **No change** — already writes a full per-cycle GlobalDonation. (Optionally refactor to route through the writer for consistency — mark OPTIONAL, do not block.) |

---

## ⑦ Idempotency & Dedup

Two layers:

1. **Application guard (one-time / first cycle):** `PromoteOnlineDonationStagingCommand` is a no-op when
   `staging.PromotedGlobalDonationId.HasValue` (webhook/mutation retries, double Confirm).
2. **DB guard (cycle-level, webhook retries with same txn):** new **partial unique index**

   ```
   CREATE UNIQUE INDEX "UX_GlobalOnlineDonations_Company_GatewayTxn"
     ON fund."GlobalOnlineDonations" ("CompanyId", "GatewayTransactionId")
     WHERE "GatewayTransactionId" IS NOT NULL AND "IsDeleted" = false;
   ```

   Currently there is **no** unique index on any gateway-transaction column anywhere. Webhook cycle
   writes catch the unique-violation and treat it as already-processed (idempotent success). Recurring
   webhooks already dedup at the event level via `PaymentWebhookLogs.GatewayEventId`; this index is the
   ledger-level backstop.

---

## ⑧ Two-State Decoupling (ledger vs contact) + Inbox change

Split the staging row's two independent facts:

- **Ledger state** = `PromotedGlobalDonationId` — set **immediately** on auto-promotion.
- **Contact state** = `ResolvedContactId` — set when a Contact is known (recurring always; one-time when
  matched); **left null** for unmatched one-time donations.

Consequences:
- **Donation Inbox (#175) / `OnlineDonationMapJobRunner`** filter changes from
  `PromotedGlobalDonationId == null` to **contact-unresolved** semantics
  (`ResolvedContactId == null && IsAnonymous == false`, tenant-scoped). The inbox becomes a
  **contact-reconciliation queue**, not a promotion queue.
- When the inbox later resolves a contact for an **already-promoted** row, it **UPDATES the existing
  `GlobalDonation.ContactId`** (via `ExecuteUpdateAsync`) — it does **NOT** create a second GlobalDonation.
- `IsResolved` semantics: set true when both ledger AND contact are settled (promoted + contact known).

---

## ⑨ Migration (SPEC ONLY — user authors/runs/commits)

Single migration adds one object:

- Partial unique index `UX_GlobalOnlineDonations_Company_GatewayTxn` on
  `fund."GlobalOnlineDonations" ("CompanyId","GatewayTransactionId")` WHERE
  `"GatewayTransactionId" IS NOT NULL AND "IsDeleted" = false`.

No column additions (all needed staging fields already exist: `PromotedGlobalDonationId`,
`ResolvedContactId`, `ReceivedDate`, `FrequencyId`, gateway fields).

> ⚠️ Pre-flight: dedup any existing duplicate `(CompanyId, GatewayTransactionId)` rows in
> `GlobalOnlineDonations` before the index is created, or `database update` will fail. Provide a
> detection query in the migration handoff.

Configuration change: add the index in `GlobalOnlineDonationConfiguration.cs` (the currently
commented-out unique index at lines 71-72 is unrelated — leave it).

---

## ⑩ Files (manifest)

**New:**
- `.../GlobalDonations/Services/IGlobalDonationCompositeWriter.cs`
- `.../GlobalDonations/Services/GlobalDonationCompositeWriter.cs`
- `.../OnlineDonations/Commands/PromoteOnlineDonationStaging.cs`
- DI registration (Application service-collection extension).

**Modified:**
- `CreateGlobalDonationWithChildren.cs` — delegate core to writer (keep auth + HttpContext CompanyId).
- `ConfirmOnlineDonation.cs` — call promote; return real ReceiptNumber.
- `PaymentWebhookController.cs` (Braintree) — per-cycle writer call in SUBSCRIPTION_CHARGED case.
- `RazorpayWebhookController.cs` — per-cycle writer call in subscription.charged case.
- `ResolveOnlineDonationStaging.cs` — schedule creation made idempotent; promotion path now
  no-ops if already promoted; contact-only update path when GlobalDonation exists.
- `CreateRecurringDonationSchedule.cs` — get-or-create (idempotent) by GatewaySubscriptionId+CompanyId.
- `GlobalOnlineDonationConfiguration.cs` — add partial unique index.
- `OnlineDonationMapJobRunner` / inbox query — filter → contact-unresolved semantics.

---

## ⑪ Acceptance Criteria

1. A one-time public donation via `ConfirmOnlineDonation` creates a `GlobalDonation` with a non-null
   `ReceiptNumber`, returned to the caller; staging row has `PromotedGlobalDonationId` set.
2. Page totals (`totalRaised`/`donorCount`/`lastDonationAt`) reflect the donation immediately, pre-inbox.
3. Duplicate Confirm (same PaymentSessionId) does **not** create a second GlobalDonation.
4. A Braintree `SUBSCRIPTION_CHARGED_SUCCESSFULLY` and a Razorpay `subscription.charged` each create one
   per-cycle GlobalDonation; a redelivered webhook (same GatewayTransactionId) does not duplicate it.
5. Recurring first cycle creates the RecurringDonationSchedule; a webhook cycle arriving before any
   manual action finds the schedule and posts its ledger row.
6. Recurring donor with no existing Contact → Contact auto-created with a primary email; one-time donor
   with no match → GlobalDonation with `ContactId = null`.
7. Inbox lists only contact-unresolved rows; resolving a contact on an already-promoted row updates the
   existing GlobalDonation's ContactId (no second ledger row).
8. Manual inbox resolution (#175) behavior unchanged for rows not yet auto-promoted (no regression).
9. `dotnet build` clean (prove compile before handoff). Default Sonnet for build agents.

---

## ⑫ Special Notes / Risks

- **Auth boundary is the crux** — the writer must NEVER read HttpContext. CompanyId is always a
  server-trusted param (`staging.CompanyId` or gateway-config tenant). Verify no hidden
  `httpContextAccessor` reads leak into the extracted core.
- **Transaction nesting** — `ConfirmOnlineDonation` and webhook handlers may already hold a transaction;
  the writer opens its own via `CreateExecutionStrategy` + `BeginTransactionAsync`. Confirm no
  nested-transaction conflict; if the caller has an ambient transaction, the writer should participate,
  not open a competing one. **Flag for BE dev to verify at build.**
- **MasterData TypeCodes** (ONETIMEDONATION, INDIVIDUAL contact base type, ACTIVE contact status,
  PERSONAL email type, PAYMENTSTATUS COMPLETED) — verify against seeds before hardcoding lookups.
- **FX** — direct-pair only via `IFxRateService.GetRateAsync`; 1:1 fallback on miss (per memory rule).
- **DB UTC** — all DateTime params `Kind=Utc`; use `DateTime.UtcNow`.
- Migration & seed: **specced only. User authors, runs, commits. Per-repo staging.**
- Couples to **ODP-B7** (consent capture) and **ODP-B8** (compliant receipts) — receipts now generate at
  capture, so B8's receipt-content rules apply to auto-promoted rows; B7 consent must be persisted on the
  staging row before promotion. Sequence B5 to land with or before B8.
```
