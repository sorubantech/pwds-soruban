# ODP-B5 — Next-Session Kickoff Prompt

> Paste the block below into the next session to resume. Screen #10 Online Donation Page
> (EXTERNAL_PAGE / DONATION_PAGE). Active bug: **ODP-B5 — "captured ≠ recorded"
> auto-promotion**. Design spec is DONE and approved-to-write; build has NOT started.

---

## ▶ Paste this into the next session

```
Resume ODP-B5 (Screen #10 Online Donation Page). The design spec is written and
reviewed — proceed to BUILD per that spec. Read it first, do NOT re-plan:
  .claude/screen-tracker/bug-reports/onlinedonationpage-ODP-B5-SPEC.md

Build the backend changes, prove they compile (dotnet build), then hand me:
  - the migration SPEC (do not run dotnet ef add/update/remove — I own migrations)
  - the one-off dedup SQL + partial-unique-index script for me to apply
  - a per-repo list of what changed (I commit myself — do NOT commit anything)

Honour standing constraints: DB is UTC timestamptz (Kind=Utc), default Sonnet for
build agents, prove compile before handoff, nothing committed, migrations user-owned.
```

---

## Current Status (as of 2026-07-14)

| Item | State |
|------|-------|
| ODP-B5 root-cause analysis | ✅ Done |
| Auth-boundary constraint confirmed | ✅ Done (decisive — see below) |
| Schema field verification (staging/contact/email/globaldonation) | ✅ Done, all confirmed |
| **Design spec** `onlinedonationpage-ODP-B5-SPEC.md` | ✅ **Written & approved** |
| Backend build | ⏳ **NOT started — start here** |
| Migration (partial unique index) | ⏳ Spec-only; user authors/runs |
| Dedup backfill SQL | ⏳ Spec-only; user applies |
| Commits | ⏳ None — user commits per-repo |

**Where to start:** implement §③–§⑧ of the SPEC in the backend, in this order:
1. `IGlobalDonationCompositeWriter` + `GlobalDonationCompositeWriter` (extract the
   transaction/receipt/back-ref core; CompanyId as **param**, never HttpContext).
2. Refactor `CreateGlobalDonationWithChildrenCommand` to delegate to the writer
   (keeps `[CustomAuthorize]` + `GetCurrentUserStaffCompanyId()` — no #175 regression).
3. New non-authorized `PromoteOnlineDonationStagingCommand` (NOT a GraphQL mutation).
4. Inject into `ConfirmOnlineDonation` (one-time + first recurring cycle → returns real
   ReceiptNumber).
5. Inject per-cycle writer calls into Braintree `SUBSCRIPTION_CHARGED_SUCCESSFULLY`
   and Razorpay `subscription.charged` webhook handlers (PayU cron already writes — leave it).
6. Contact policy (§④), two-state decouple `PromotedGlobalDonationId` vs
   `ResolvedContactId` (§⑧), idempotency guard + partial unique index (§⑦).

---

## The one thing that drives the whole design

`CreateGlobalDonationWithChildrenCommand` is `[CustomAuthorize]` and reads CompanyId
**only** from `httpContextAccessor.GetCurrentUserStaffCompanyId()` (0 when not
authenticated). Public mutation + `[AllowAnonymous]` webhooks have no staff claim, so
that command **cannot** be reused from anonymous contexts. → extract a CompanyId-
parameterized writer that both the authorized command and the new promote path share.

## Pending issues / flags for the build (from SPEC §⑫)

1. **Nested-transaction risk** — verify `ConfirmOnlineDonation` / webhook handlers do
   NOT already hold an ambient transaction when the writer opens its own
   (`CreateExecutionStrategy` + `BeginTransactionAsync`). If they do, the writer needs a
   "join ambient tx" flag instead of opening a new one.
2. **MasterData TypeCodes** must be verified against seed, not assumed:
   INDIVIDUAL (ContactBaseType), ACTIVE (ContactStatus), PERSONAL (EmailType),
   ONETIMEDONATION (DonationType), RECURRINGFREQUENCY (Frequency).
3. **RECURRING type block** — each recurring cycle records as **ONETIMEDONATION**, so
   the command's hard block on RECURRING donation-TYPE never trips. Keep it that way.
4. **FX** — direct-pair only via `IFxRateService.GetRateAsync`, 1:1 on miss. No USD pivot.
5. **Contact.PrimaryCountryId is non-nullable** — auto-create path must supply it
   (source from page/company default). ContactStatusId is nullable but set ACTIVE.
6. **Contact email is a child collection** (`corg.ContactEmailAddresses`, Email+CompanyId),
   NOT a scalar — match/auto-create against it.
7. **Coupling:** ODP-B7 (consent) and ODP-B8 (receipts) touch the same promotion path —
   confirm they aren't being built in parallel to avoid merge collisions.

## Reference files (paths verified)

- SPEC: `.claude/screen-tracker/bug-reports/onlinedonationpage-ODP-B5-SPEC.md`
- `...\Base.Domain\Models\DonationModels\OnlineDonationStaging.cs`
- `...\Base.Domain\Models\DonationModels\GlobalDonation.cs`
- `...\Base.Domain\Models\ContactModels\Contact.cs`
- `...\Base.Domain\Models\ContactModels\ContactEmailAddress.cs`
- `...\Application\...\GlobalDonations\CreateGlobalDonationWithChildren.cs` (752 ln)
- `...\ResolveOnlineDonationStaging.cs` (574 ln — mirror step-5 DTO build)
- `...\ConfirmOnlineDonation.cs` (~1236 ln)
- `PaymentWebhookController.cs` / `RazorpayWebhookController.cs` / `PayURecurringChargeService.cs`
- `GlobalOnlineDonationConfiguration.cs` (add the partial unique index here)

> Backend repo is nested — absolute Reads MUST include the full
> `pss-2.0-global\PSS_2.0_Backend\...` prefix.
