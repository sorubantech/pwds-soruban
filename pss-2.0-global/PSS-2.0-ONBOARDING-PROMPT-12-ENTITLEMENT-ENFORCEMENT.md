# PSS 2.0 — ONBOARDING PROMPT 12 — Entitlement & Quota Enforcement (Soft-block)

**Task ID:** T-A18 (P2 phase — the enforcement half of Plans & Entitlements)
**Surface:** BE (2 MediatR behaviors + 2 attributes · menu/module entitlement filter · integration on first gated commands) · FE (usage meters + 80%/100% upgrade CTAs + entitlement-driven menu hide)
**Model:** Sonnet (the pipeline slot, attribute pattern, advisory-lock, and resolution service are all proven precedents copied below; §①–⑫ are detailed)
**Depends on:** PROMPT-11 (catalog editable + `myEntitlements` returns real data), T-A5 (`IEntitlementService` — DONE), the MediatR pipeline (`Base.Application/DependencyInjection.cs` L30-37 — DONE)
**Companion:** PROMPT-11 (screens). Build 11 first — there is nothing to enforce until the catalog is editable and entitlements resolve.

> **Blueprint:** `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md` — §7 (pipeline enforcement: 7.1 feature gate, 7.2 quota gate + advisory lock, 7.3 first integration points), §8 (menu/module gating), §11 (soft-block policy — **the confirmed policy for this build**).
>
> **Over-limit policy (user-confirmed, soft-block):** warn at **80%**, block only **NEW creates at 100%**, existing data stays **readable + editable**. A downgrade below current usage = **read-only-over-limit**, never delete. This governs every gate below.

---

## ① Why this exists

PROMPT-11 makes plans editable and lets a tenant *read* its entitlements. But **reading is advisory** — right now a Free-plan tenant can create a 60,001st contact, send WhatsApp it isn't entitled to, and see menu items for modules it doesn't have. Enforcement is the "BE is truth" half: the same resolved map that `myEntitlements` displays must actually **gate commands and menus**.

**Three independent gates** (blueprint §6), each a separate concern, composed — a command passes only if all that apply to it pass:

1. **Entitlement** — does the plan enable this *feature*? (`[RequiresFeature("CHANNEL:WHATSAPP")]` → 403 if not)
2. **Quota** — is the tenant under the *limit* for this *meter*? (`[MeteredResource("CONTACTS", Stock)]` → soft-block at 100% → 402 if over)
3. **RBAC** — does the user's role permit it? (already enforced by the existing `AuthorizationBehavior` — untouched)

Plus **menu/module hiding** (§8): the tenant's nav only shows modules its plan entitles — cosmetic reinforcement of gate 1, never a substitute for it.

**First gates this build (user-confirmed — all three kinds):**
- **Stock quotas:** CONTACTS + DONATIONS.
- **Channel features:** EMAIL / WHATSAPP / SMS sends (`CHANNEL:*`).
- **Menu/module hiding** by entitlement.

---

## ② Reuse-first — copy these precedents, do not invent

| Need | Copy from | Location |
|---|---|---|
| Behavior + attribute shape | `TenantAccessBehavior` + `[TenantScope]` — the two new behaviors/attributes mirror these **exactly** (attribute `[AttributeUsage(Class, Inherited=true, AllowMultiple=false)]` on the command; behavior reads it via `typeof(TRequest).GetCustomAttributes`) | `Base.Application/Behaviors/TenantAccessBehavior.cs`, `TenantScopeAttribute.cs` |
| Pipeline registration order | DI registers behaviors in order; insert the two new ones **after `TenantAccessBehavior` (slot 3), before `CommandValidationBehavior`** | `Base.Application/DependencyInjection.cs` L30-37 |
| SuperAdmin / background bypass | `GetCurrentTenantId() == null && !IsSuperAdmin()` → background context, bypass; SuperAdmin → bypass. Same guard both new behaviors use | `TenantAccessBehavior` (its existing guard) |
| Resolution | `IEntitlementService.HasFeatureAsync(companyId, featureCode)`, `GetLimitAsync(companyId, meterCode)` (null=unlimited, 0=no-sub/fail-closed) | `Base.Application/Interfaces/IEntitlementService.cs` |
| Code constants | `FeatureCodes`, `MeterCodes`, `MeterTypes` — attributes carry these constant values, never literals | `Base.Application/Interfaces/BillingCodes.cs` |
| TOCTOU quota lock | `SELECT pg_advisory_xact_lock({0})` via `Database.ExecuteSqlRaw`/interpolated **inside the handler transaction** before count+insert | precedents: `NumberSequenceGenerator.cs:81`, `CreateBeneficiaryServiceLog.cs:116`, `ConfirmOnlineDonation.cs` |
| Menu resolution query | filter the resolved menu/module set by `TenantEntitlements.Features` | `Base.Application/Business/AuthBusiness/MenuCapabilities/Queries/GetMenuCapabilities.cs`, `.../Modules/Queries/GetUserRoleModule.cs`, `Base.API/EndPoints/Auth/Queries/MenuCapabilities.cs` |
| FE meters source | `myEntitlements` (built in PROMPT-11 §4.2 / §5.C) | tenant-side gql-queries |

**No schema change, no migration, no new entity.** `UsageCounter` already exists; this prompt writes to it only for FLOW meters (§④).

---

## ③ Backend — Gate 1: Feature entitlement

### 3.1 Attribute

```csharp
[AttributeUsage(AttributeTargets.Class, Inherited = true, AllowMultiple = true)]  // a command may require >1 feature
public sealed class RequiresFeatureAttribute : Attribute
{
    public string FeatureCode { get; }
    public RequiresFeatureAttribute(string featureCode) => FeatureCode = featureCode;
}
```

(`AllowMultiple = true` so a command can require, e.g., both a module and a channel — read *all* attributes and require every one.)

### 3.2 Behavior — `FeatureEntitlementBehavior<TRequest,TResponse>`

Insert in the pipeline **after `TenantAccessBehavior`, before `CommandValidationBehavior`**. Logic:

1. `var attrs = typeof(TRequest).GetCustomAttributes<RequiresFeatureAttribute>(true).ToList();` — none → `next()` (fast path, no service hit).
2. **Bypass guard (identical to `TenantAccessBehavior`):** SuperAdmin → `next()`; `GetCurrentTenantId() == null && !IsSuperAdmin()` (background/system) → `next()`.
3. `var companyId = GetCurrentTenantId()!.Value;` For each attribute: `if (!await _entitlements.HasFeatureAsync(companyId, attr.FeatureCode, ct))` → throw the feature-not-entitled error.
4. **Error:** a typed exception carrying HTTP **403** and code **`PLAN_FEATURE_NOT_ENTITLED`** + the feature code + a human message (`"Your plan does not include {feature}. Upgrade to enable it."`). Reuse the platform's existing forbidden/exception-to-GraphQL-error mapping (match how `AuthorizationBehavior` surfaces its 403 so the FE sees a consistent shape).

### 3.3 First integration points — channel sends

Put `[RequiresFeature(FeatureCodes.ChannelWhatsApp)]` / `ChannelSms` / `ChannelEmail` on the **send** commands (not the compose/draft, not the template CRUD — gate the moment of send). Identify the actual command records for each channel's send path and annotate them:
- WhatsApp send command → `[RequiresFeature(FeatureCodes.ChannelWhatsApp)]`
- SMS send command → `[RequiresFeature(FeatureCodes.ChannelSms)]`
- Email send command → `[RequiresFeature(FeatureCodes.ChannelEmail)]`

> Verify the exact send-command class names before annotating (the campaign/blast send vs the transactional/system send may differ — gate the **user-triggered** channel sends; do **not** gate system/transactional mail like the activation link, which must always deliver regardless of plan). If a single command serves both, gate at the call site or split — flag the decision in the build log rather than accidentally blocking system mail.

---

## ④ Backend — Gate 2: Quota (soft-block)

### 4.1 Attribute

```csharp
[AttributeUsage(AttributeTargets.Class, Inherited = true, AllowMultiple = false)]
public sealed class MeteredResourceAttribute : Attribute
{
    public string MeterCode { get; }
    public string MeterType { get; }   // MeterTypes.Stock | MeterTypes.Flow
    public MeteredResourceAttribute(string meterCode, string meterType) { MeterCode = meterCode; MeterType = meterType; }
}
```

### 4.2 Behavior — `QuotaBehavior<TRequest,TResponse>` (soft-block semantics)

Insert **immediately after `FeatureEntitlementBehavior`** (both after `TenantAccessBehavior`, before `CommandValidationBehavior`). Logic:

1. Attribute absent → `next()`. Bypass guard identical to §3.2.2 (SuperAdmin / background bypass).
2. `var limit = await _entitlements.GetLimitAsync(companyId, attr.MeterCode, ct);`
   - `limit == null` → **unlimited** → `next()`.
   - `limit == 0` → no live subscription / not provisioned (fail-closed) → **block** (402, see 4.4). (A real "zero allowed" plan and "no subscription" both correctly block a create.)
3. **Read current usage** (the soft-block decision is `used >= limit` → block the *new* create; `used < limit` → allow):
   - **STOCK** → authoritative `COUNT(*)` on the real table for this tenant (contacts / global-donations), standard soft-delete filter. **Not** the `UsageCounter` cache — count is drift-free.
   - **FLOW** → the current-period `UsageCounter` row's `CurrentValue` (absent → 0).
4. **Soft-block rule:** block only when the action would create the `(limit+1)`-th record, i.e. `used >= limit`. **Existing data is untouched** — this behavior only runs on the create commands it annotates, never on reads/updates/deletes, so over-limit tenants keep full read/edit access by construction. A tenant already over limit (post-downgrade) simply cannot create *new* ones until under.
5. **TOCTOU — for STOCK creates, the count+insert must be atomic.** Wrap in the proven advisory-lock pattern **inside the handler's transaction** (the behavior can enforce the check, but the authoritative count+insert race is closed in the handler — see 4.3): `Database.ExecuteSqlRaw("SELECT pg_advisory_xact_lock({0})", lockKey)` where `lockKey` is a stable hash of `(companyId, meterCode)`. Same pattern as `NumberSequenceGenerator.cs:81`.

### 4.3 Where the atomic check lives (STOCK)

The behavior gives a fast pre-check (good UX: rejects most over-limit calls before the handler runs), **but the drift-free guarantee needs the count under the advisory lock inside the same transaction as the insert.** Two acceptable shapes — pick and document:
- **(preferred)** Behavior does the cheap pre-check (reject early if clearly over); the annotated **handler** takes the advisory lock, re-counts, and inserts — all in its existing transaction. This is the fund-guard precedent exactly.
- **(fallback)** If threading the lock into each handler is too invasive this pass, the behavior itself opens the transaction + advisory lock + count + calls `next()` (the insert) + commit. Heavier, but keeps handlers untouched. Document which you chose.

FLOW meters have no count-then-insert race (the `UsageCounter` row is the single source and is incremented under its own row lock) — so FLOW needs no advisory lock, just an atomic `UPDATE … SET CurrentValue = CurrentValue + 1 WHERE … RETURNING` guarded by the limit, or increment-then-check-rollback.

### 4.4 Error + FLOW increment

- **Over-limit error:** typed exception, HTTP **402**, code **`PLAN_QUOTA_EXCEEDED`**, payload `{ meterCode, limit, used }` + message (`"You've reached your plan limit of {limit} {meter}. Upgrade to add more."`). FE maps 402 → upgrade CTA.
- **FLOW increment:** on a successful gated FLOW create/send, increment the current-period `UsageCounter` (upsert the period row, `CurrentValue += 1`). Never decrement; the period-roll (fresh row each `CurrentPeriodStart`) is a later job — for this build, resolve `PeriodStart` from the subscription's `CurrentPeriodStart` and upsert on `(CompanyId, MeterCode, PeriodStart)`.

### 4.5 First integration points — stock quotas

- `[MeteredResource(MeterCodes.Contacts, MeterTypes.Stock)]` on **`CreateContactCommand`**.
- `[MeteredResource(MeterCodes.Donations, MeterTypes.Stock)]` on the **global-donation create** command (verify the exact class — the `GlobalDonation` create handler; DIK/receipt-book paths that create a `GlobalDonation` count too — gate the shared create, or each entry path, so no create route bypasses the meter).

> Verify each create-command class name and that Duplicate/batch/import create paths route through the same gated command (memory `project_numseq_entity_rollout` notes create logic lives on CREATE incl Duplicate/batch). If an import bulk-inserts N contacts, the meter must account for all N (check `used + N <= limit`, not one-at-a-time) — flag bulk paths in the build log if they bypass the single-create command.

---

## ⑤ Backend + FE — Gate-3-adjacent: menu/module hiding

**BE:** in the menu/module resolution queries (`GetMenuCapabilities`, `GetUserRoleModule`), after the existing RBAC filter, **intersect with the tenant's entitled modules**: resolve `TenantEntitlements.Features`, and drop any menu/module whose backing `MODULE:*` feature is not enabled. A module with no `MODULE:*` mapping (platform/always-on) is never hidden. This is **cosmetic reinforcement** — a hidden module's commands are still hard-gated by §③, so hiding is UX, not security (blueprint §8).

**FE:** the nav already renders from the resolved menu query, so once BE filters, the menu hides automatically — verify no client-side hard-coded module list needs a parallel edit.

---

## ⑥ FE — usage meters + upgrade CTAs (consumes `myEntitlements`)

The `myEntitlements` query + types were wired in PROMPT-11 §5.C; this prompt renders them.

- **Usage meters** — for each metered resource (CONTACTS, DONATIONS, channels), a progress bar `Used / Limit` (unlimited → "∞", no bar). Place on the tenant's plan/usage panel (Screen #75 §8 area or a dedicated `/settings/plan` card — reuse the existing subscription panel location). Bars: mid-saturation fill is fine; the **80%+ state** turns the bar/chip solid warning per house tokens (memory `feedback_widget_icon_badge_styling`).
- **80% warn:** at `Percent >= 80 && < 100`, show a non-blocking banner/chip: `"You're at {percent}% of your {meter} limit."` + an **Upgrade** link.
- **100% block CTA:** at `Percent >= 100`, the meter shows "limit reached" and the relevant **Create** entry point (e.g. "+ New contact") is disabled with a tooltip + Upgrade CTA — a *cosmetic* pre-block matching the server's 402 (the server is still the authority; if the FE misses it, the command still 402s).
- **402 / 403 handling:** a global handler maps `PLAN_QUOTA_EXCEEDED` (402) → upgrade dialog naming the meter; `PLAN_FEATURE_NOT_ENTITLED` (403) → "not on your plan" dialog naming the feature. Both link to contact-to-upgrade (no self-serve checkout in P2).
- **Free-trial countdown (PROMPT-11 §②b):** when `myEntitlements.IsTrial`, show a persistent banner "Free trial — {TrialDaysRemaining} days left" (warn styling under ~3 days) with an **Upgrade** CTA. This is display only — enforcement of expiry is already automatic: an expired trial resolves `Status="None"` in `EntitlementService`, so **every** feature 403s and **every** metered create 402s with no extra code here (§⑦ acceptance 8b). Once expired, the banner reads "Your free trial has ended — upgrade to continue."
- **Channel feature hiding:** if `CHANNEL:WHATSAPP` is disabled, the WhatsApp send action is hidden/disabled with an upgrade hint (cosmetic; the send command is hard-gated by §③).

UI tokens, xs→xl responsive, Phosphor icons, shaped Skeletons, empty/error states per house rules. Amounts/limits `text-right` in the meter tiles.

---

## ⑦ Acceptance

1. A Free-plan tenant (CONTACTS limit 50000) at 49,999 creates one contact → succeeds; the next create → **402 `PLAN_QUOTA_EXCEEDED`** with `{limit:50000, used:50000}`. Existing contacts remain fully readable **and editable** (soft-block).
2. Concurrent create at the boundary: two simultaneous "50,000th" creates → the advisory lock serialises them; exactly one succeeds, the other 402s. No off-by-one over the limit.
3. A tenant downgraded from 100K to 50K while holding 60,000 contacts: reads/edits all 60,000 fine; **cannot create a new one** until under 50,000; nothing is deleted.
4. `limit == null` (unlimited plan) → creates never blocked; no advisory-lock overhead beyond the count skip.
5. A plan without `CHANNEL:WHATSAPP` → the WhatsApp send command returns **403 `PLAN_FEATURE_NOT_ENTITLED`**; enabling it on the plan (PROMPT-11) makes the same send succeed within cache TTL.
6. **System/transactional mail (activation link, password reset) always sends** regardless of plan — it is not annotated `[RequiresFeature]`; verify a Free tenant's admin still receives the activation email.
7. SuperAdmin and background/system contexts bypass both gates (a system job creating records is never quota-blocked).
8. A no-subscription company (`Status="None"`) is fail-closed: every feature 403s, every metered create 402s (`limit` resolves 0).
8b. **Expired Free trial (PROMPT-11 §②b):** a tenant whose `TrialEndsOn` has passed resolves `Status="None"` → identical fail-closed behaviour as #8 (all features 403, all metered creates 402), with **no enforcement code added in this prompt** — the resolution-time expiry check from PROMPT-11 does it. The FE shows the "trial ended — upgrade" banner. A tenant still inside its trial window behaves as fully entitled to its plan.
9. Menu: a tenant without `MODULE:GRANT` does not see the Grant menu/module; a tenant with it does. Hiding a module never exposes its commands (calling a hidden module's command still hard-gates via §③).
10. FLOW meter: sending emails increments the current-period `UsageCounter`; at the monthly limit the next send 402s; the counter is per-period (never decremented).
11. FE: at 80% a warn banner shows; at 100% the Create entry point is disabled with an Upgrade CTA; a 402/403 from any other path still surfaces the right upgrade dialog.
12. BE `dotnet build` 0 errors; FE `tsc --noEmit --incremental false` exits 0. Pipeline order verified: `TenantAccess → FeatureEntitlement → Quota → CommandValidation`.

---

## ⑦b Out of scope (do not build)

- Plan/subscription **screens** and `myEntitlements` query itself → PROMPT-11.
- Meters beyond CONTACTS + DONATIONS (stock) and EMAIL/WHATSAPP/SMS (channel) — USERS quota, storage, API-rate (429) are later.
- The `UsageCounter` **period-roll job** (fresh FLOW row per period boundary) — this build resolves `PeriodStart` from the subscription and upserts; the scheduled roll is separate.
- Self-serve upgrade/checkout, payment-gateway calls, dunning on `PastDue`.
- Any schema change, migration, or new entity. No new seed (catalog seed from T-A5 stands).
- Rewriting `AuthorizationBehavior` / RBAC (gate 3 is untouched — the two new gates compose *with* it).

---

## ⑬ Build Log

_(append per session — keep last 5; git holds the rest)_

- **PENDING** — generated by PM/prompt-engineer 2026-07-29. Not yet built. Enforcement half of Plans P2; depends on PROMPT-11 (screens + `myEntitlements`). Confirmed policy: soft-block (warn 80% / block-new-create 100% / existing stays read+edit). First gates: CONTACTS+DONATIONS stock, EMAIL/WHATSAPP/SMS channel, menu/module hiding.
- **AMENDED** 2026-07-29 — Free-plan expiry (PROMPT-11 §②b): expired Free trial is fail-closed automatically via resolution (`Status="None"`) with no new enforcement code; added the FE trial-countdown/expired banner + acceptance 8b.
- **BUILT** 2026-07-29 — T-A18 implemented end to end. FE `npx tsc --noEmit --incremental false` **exits 0**. BE compile is user-owned (not run this session).
  - **BE.** `RequiresFeatureAttribute` + `FeatureEntitlementBehavior` (403 `PLAN_FEATURE_NOT_ENTITLED`); `IUsageMeterService` + `QuotaBehavior` (402 `PLAN_QUOTA_EXCEEDED`, soft-block, STOCK=`COUNT(*)` / FLOW=period counter, advisory lock reusing the fund-guard pattern); both registered in `DependencyInjection`; `CustomErrorFilter` carries `meterCode/limit/used` and `featureCode` in extensions so the FE dialog needs no follow-up round trip.
  - **Gated create paths.** `CreateContact` (CONTACTS), GlobalDonation create (DONATIONS), channel sends (`CHANNEL:EMAIL` / `CHANNEL:WHATSAPP` / `CHANNEL:SMS`).
  - **Menu filter** went into `GetParentChildMenu` via `MenuFeatureMap` — *not* `GetMenuCapabilities`, which is the admin CRUD grid over menu rows and must keep showing everything. `GetUserRoleModule` is unfiltered by construction.
  - **Rollout guard (both layers).** An EMPTY features list means billing has not resolved a plan, so cosmetic gates stay **OPEN** rather than blanking the product: BE `if (entitlements.Features.Count > 0)`; FE `resolved = features.length > 0`, with `hasFeature` returning `true` while unresolved. The hard server gate is unaffected.
  - **FE.** `useEntitlements` hook (+ `FEATURE_CODES` / `METER_CODES` / `GRID_METER_MAP` vocabulary mirroring `BillingCodes.cs`); `PlanUsagePanel` (mounted in CompanySettings #75 §8 `subscription-section.tsx`, above the legacy placeholder panel); `PlanStatusBanner` (mounted once in `dashboard-layout-provider`'s `<main>`); `QuotaGuard` wrapping the shared advanced-grid "+ New" (`data-table-general-toolbar.tsx`) for mapped grids; `FeatureGuard` on the WhatsApp campaign **Send Now** (`mode="disable"`, not hide). Apollo `errorLink` dispatches `plan:quota-exceeded` / `plan:feature-not-entitled` window events (mirroring the existing `site-maintenance` seam) and `PlanEnforcementProvider` — mounted in `(core)/layout.tsx`, inside the authenticated shell — renders the two upgrade dialogs. Every FE gate is cosmetic; the 402/403 is the boundary.
  - **Intentionally ungated.** Anonymous public promote paths (captured ≠ recorded) and `SendSupportQueryEmailCommand` (a tenant at its limit must still be able to ask for help).
  - **§4.3** built in its **preferred** shape.
  - **KNOWN GAP.** Bulk-campaign EMAILS FLOW metering: `EmailSendQueueRepository.AddBulkToQueueAsync` is left untouched, so a bulk enqueue does not increment the EMAILS counter. Per-send paths do.
  - **CONFIG REQUIRED.** Upgrade CTAs read `NEXT_PUBLIC_UPGRADE_CONTACT`; unset, they render as plain text ("Contact your account manager to upgrade.") rather than a dead link. There is no self-serve checkout by design.
  - **User-owned follow-ups.** `dotnet build`; any migration this introduces; then smoke-test the 402/403 dialogs against a seeded low-limit plan.
- **AMENDED** 2026-07-30 — **plan surfaces restricted to BUSINESSADMIN.** FE `tsc` re-run **exits 0**. No migration.
  - **Why.** `PlanStatusBanner` is mounted once in the authenticated shell, so as first shipped it followed *every* user of the tenant across every screen with a trial countdown and org-wide meter strain — an alarm about a problem only the account owner can solve. `PlanUsagePanel` reports organisation-wide totals (all contacts / donations / seats).
  - **BE.** `MyEntitlementsResult` gains `bool IsBillingAdmin`, resolved in `GetMyEntitlementsHandler` from `UserRoles` on the immutable `RoleCode == "BUSINESSADMIN"` (same shape as `GrantCommunicationHelper`'s recipient resolution) — deliberately **not** from the `CurrentCompanyRoles` JWT claim, which carries tenant-editable display *names* ("Business Admin"). The no-tenant early return reports `false`. The query stays unattributed and self-scoped: every user still needs to read it for the menu filter, and nothing in the payload is a secret.
  - **FE.** `isBillingAdmin` threaded through `PlanQuery` → `MyEntitlementsDto` → `useEntitlements`. `PlanStatusBanner` and `PlanUsagePanel` each self-gate on it (the panel's host, CompanySettings, is capability-gated already; the self-gate is so the card stays correct wherever it is mounted). `UpgradeCta` renders "Ask your organisation admin to upgrade the plan." instead of the button for non-admins — so the `QuotaGuard`/`FeatureGuard` tooltips and the 402/403 dialogs keep their *explanation* for everyone and drop only the un-followable CTA.
  - **Fails CLOSED, unlike the feature/quota gates.** `isBillingAdmin` defaults `false` while unresolved: an admin sees the banner a beat later, whereas failing open would flash org-wide usage at every user on every page load. The cosmetic entitlement gates still fail open, unchanged.
  - **Why not the house `useAccessCapability({menuCode:"COMPANYSETTINGS"})` proxy.** That hook scopes its query by `moduleCode` from the global store and skips entirely when it is falsy, so a `COMPANYSETTINGS` lookup from a globally-mounted component resolves to the all-false defaults on every non-settings module — it would have suppressed the banner almost everywhere. It remains correct for route-level gates like `golive.tsx`.
- **AMENDED** 2026-07-30 — **operator-side per-tenant Usage card** on the control-plane tenant hub. FE `tsc` re-run **exits 0**. No migration (the query is computed over existing tables).
  - **Why.** Nothing on the control plane showed CONSUMPTION. `/ops/plans` defines limits, and `tenant-subscription-panel` shows plan + overrides + the resolved limit map — all entitlement, no used-vs-limit. So the only live usage surface was the tenant's own `PlanUsagePanel`, which an operator cannot see; a support call about a blocked Create meant asking the tenant to read their settings screen back over the phone.
  - **Why a NEW query and not `myEntitlements`.** That query deliberately takes **no** `CompanyId` — its tenant comes from the JWT, which is exactly what makes it untamperable — so an operator on `/ops/tenants/47` has no way to ask it about 47.
  - **BE.** `GetTenantUsage.cs` (alongside `GetMyEntitlements.cs`): `GetTenantUsageQuery(int CompanyId)` → `TenantUsageResult` (company, plan, status, trial fields, `Meters`, reusing `MeterStateDto`). Same measurement rules, copied on purpose so operator and tenant never see two different numbers — STOCK = authoritative `COUNT(*)`, FLOW = current-period `UsageCounters` row (absent ⇒ 0), `IgnoreQueryFilters()` throughout for the cross-tenant read, percent null when unlimited and **not** clamped at 100. `[CustomAuthorize("PLATFORM_PLANS", "PLATFORM_PLAN_VIEW", "PLATFORM_PLAN_EDIT")]` — either capability passes, matching `GetSubscriptionForCompany`, so an edit-only operator is not locked out of the read. Validator requires `CompanyId > 0`; unknown company `NotFoundException`; no live subscription is **not** an error (resolves to Status "None", every limit 0). Resolver added to `PlanCatalogQueries` — HotChocolate strips `Get`, so the field is **`tenantUsage`**.
  - **FE.** `TENANT_USAGE_QUERY` + `TenantUsageDto` (narrower than `MyEntitlementsDto`: no feature map — the panel next door covers entitlement — and no `isBillingAdmin`, since the audience here is a platform operator gated by `PLATFORM_PLANS`, not a tenant role). New `tenant-usage-panel.tsx`, mounted under `TenantSubscriptionPanel` in `tenant-detail-page.tsx`; self-resolves `usePlatformCapabilities({menuCode:"PLATFORM_PLANS"})` and renders **nothing** for a tenant-only operator, same pattern as the subscription panel. `cache-and-network` (usage moves under the operator's feet). Reuses `METER_ICONS` / `meterLabel` / `QUOTA_WARN_PERCENT` and the 80/100 tone system from `plan-usage-panel.tsx`; tiles sort **most-strained first** because the canonical code order buries the meter that is about to break. Read-only by design — no "reset usage" (STOCK is a live row count, FLOW rolls over with the period).
  - **User-owned follow-ups.** `dotnet build` (adds `GetTenantUsage.cs` + the resolver); smoke-test `/ops/tenants/{id}` as a PLATFORM_PLANS operator and confirm the card is absent for one without it.
- **AMENDED** 2026-07-30 — **ISSUE-1 placeholder removed; CompanySettings §8 is now 100% live.** FE `tsc` re-run **exits 0**. No migration (the new fields are projections off existing `billing.Subscriptions` columns).
  - **Why.** §8 rendered the live `PlanUsagePanel` *stacked on top of* the pre-billing placeholder it was meant to replace, and the two looked equally real. Concrete contradictions on one screen: a "No active subscription" warning sitting above a "Professional" badge; User Seats printed twice with different numbers; a marketing feature checklist that could promise a feature `FeatureEntitlementBehavior` will 403; and a Storage bar metered by nothing at all. `GetCompanySubscriptionInfo` was a handler with **no DB access** — it returned one hardcoded Professional/Annual/134-of-200-seats/12.3-of-50-GB payload to every tenant.
  - **STORAGE is gone for good, not re-pointed.** This product meters **RECORDS** (contacts, donations, emails, users), never gigabytes — there was never a STORAGE meter behind that bar and `MeterCodes` has no entry for one. Deleting the concept was the user's explicit ruling, not an omission.
  - **BE.** `MyEntitlementsResult` gains the commercials — `decimal? Amount`, `string? CurrencyCode`, `string? BillingCycle`, `DateTime? CurrentPeriodEnd` — so §8 is served **entirely** from this one query. They are the price **SNAPSHOT** on the subscription row (projection follows `GetSubscriptionForCompany`, `s.Currency != null ? s.Currency.CurrencyCode : null`), never re-derived from the current price book: a tenant must see what it was actually charged. All four are null when nothing is live, and the no-tenant early return passes nulls. Removed in three places: the `companySubscriptionInfo` resolver (`CompanySettingsQueries`), `CompanySubscriptionInfoDto` + `SubscriptionFeatureDto` (`CompanySettingsSchemas`), and the whole `GetSubscriptionInfoQuery/` folder. Each site keeps a comment recording why.
  - **FE.** Four fields threaded `PlanQuery` → `MyEntitlementsDto` → `PlanUsagePanel`, which now renders a Status / Billing cycle / Amount / Renews-on (or **Trial ends**, when on trial) fact row above the meters, and a **real** feature checklist off `entitlements.features` + `FEATURE_LABELS` — what is ticked is exactly what `[RequiresFeature]` allows. `subscription-section.tsx` is down to a header + `<PlanUsagePanel />` + a non-admin explanation strip (the panel self-gates on BUSINESSADMIN and would otherwise leave a bare heading). Deleted with the placeholder: `GET_COMPANY_SUBSCRIPTION_INFO_QUERY`, `CompanySubscriptionInfoDto` / `SubscriptionFeature` / `PlanTier` / `BillingCycle`, the `useQuery` block and props in `settings-page.tsx`, both `UsageCard`s, both `InfoCard`s, `SubscriptionSkeleton`, and the two `toast.info("… coming soon")` stub buttons — "View Plans & Pricing" is now the header's `UpgradeCta`, the single upgrade path in the product.
  - **User-owned follow-ups.** `dotnet build` (now also covers `GetMyEntitlements.cs` and the three deletions); confirm §8 shows the real plan/price for a seeded tenant and the no-plan warning for an unseeded one.
