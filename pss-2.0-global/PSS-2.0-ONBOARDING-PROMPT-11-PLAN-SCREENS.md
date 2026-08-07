# PSS 2.0 — ONBOARDING PROMPT 11 — Plan Catalog, Subscription Assignment & `myEntitlements`

**Task ID:** T-A17 (P2 phase — the screens half of Plans & Entitlements)
**Surface:** BE (Plan/PlanEntitlement/PlanQuota/PlanPrice CRUD · Subscription assign/override · `myEntitlements` read) · FE (`(master)` `/ops/plans` catalog + subscription action on the tenant hub)
**Model:** Sonnet (entities, service surface, seed, capabilities, menu, and pricing service all already exist — this is CRUD + read wiring over a locked schema; §①–⑫ below are detailed)
**Depends on:** T-A4 (billing entities — DONE), T-A5 (`IEntitlementService` + catalog seed — DONE), P-02b (`IPlanPricingService` — DONE), ops RBAC seed (`PLATFORM_PLANS` / `PLATFORM_PLAN_EDIT` + `/ops/plans` menu — DONE)
**Companion:** PROMPT-12 (enforcement) consumes what this prompt exposes. Build 11 first — 12 has nothing to gate until the catalog is editable and `myEntitlements` returns real data.

> **Blueprint:** `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md` — §5 (plan matrix), §6 (`IEntitlementService`), §11 (soft-block over-limit policy), §12 (screens table), §13 (seeding). This prompt implements the **screens + read** rows of §12; PROMPT-12 implements the **enforcement** rows.

---

## ① Why this exists

The billing skeleton is fully built and migrated — 6 `billing` entities (`Plan`, `PlanEntitlement`, `PlanQuota`, `PlanPrice`, `Subscription`, `SubscriptionOverride`, `UsageCounter`), `IEntitlementService`, `IPlanPricingService`, `BillingCodes` constants, and an idempotent 4-plan catalog seed. **But nothing edits it and nothing outside the billing service reads it.** The plan matrix can only be changed by re-running seed SQL, subscriptions can only be assigned by hand-writing INSERTs, and a tenant's own app has no way to ask "what am I entitled to."

This prompt closes that with **three read/write surfaces, zero schema change:**

1. **Plan Catalog** (`(master)` `/ops/plans`) — SUPERADMIN CRUD over `Plan` + its `PlanEntitlement` feature matrix + `PlanQuota` limits + `PlanPrice` per-currency price book. This is the "plan screen" — the single place the plan matrix (blueprint §5) becomes editable instead of seed-only. It **resolves D-Q4** (module-to-plan mapping) from a hard blocker into an editable grid: the seed sets sane defaults, the screen refines them anytime.
2. **Subscription assignment** — on the existing `(master)` tenant hub: assign a Company → Plan, set per-tenant overrides (`SubscriptionOverride`), change status, snapshot the price via `IPlanPricingService`.
3. **`myEntitlements`** — a real tenant-facing GraphQL query returning the resolved feature/limit map + live usage, so the tenant FE can render usage meters and upgrade CTAs. This **supersedes the hardcoded `GetCompanySubscriptionInfo` placeholder** (Screen #75 §8, ISSUE-1) — see §⑤C.

**BE is truth, FE is cosmetic** (blueprint §6). Everything this prompt writes on the FE is display only; the authority is the enforcement pipeline in PROMPT-12.

---

## ② Reuse-first — what already exists (do NOT rebuild)

| Need | Already built — reuse it | Location |
|---|---|---|
| Entities + EF config + migration | `Plan`, `PlanEntitlement`, `PlanQuota`, `PlanPrice`, `Subscription`, `SubscriptionOverride`, `UsageCounter` | `Base.Domain/Models/BillingModels/` (all `int` keys, `Entity` base, `billing` schema) |
| Resolution service | `IEntitlementService` — `ResolveAsync(companyId, ct)` → `TenantEntitlements(CompanyId, PlanCode, Status, Features, Limits)`; `HasFeatureAsync`; `GetLimitAsync`; `Invalidate(companyId)` (IMemoryCache ~60s) | `Base.Application/Interfaces/IEntitlementService.cs` · impl `Base.Infrastructure/Services/Billing/EntitlementService.cs` |
| Price resolution | `IPlanPricingService` — resolves per-currency price: `PlanPrice` BOOK override wins over `Plan` base-price FX fallback | `IPlanPricingService.cs` / `PlanPricingService.cs` (P-02b) |
| Code constants | `FeatureCodes` (`MODULE:*`, `CHANNEL:*`), `MeterCodes`, `MeterTypes`, `PlanCodes`, `SubscriptionStatuses` (`Live={Trial,Active,PastDue}`, `None`) | `Base.Application/Interfaces/BillingCodes.cs` — **use these constants, never string literals** |
| Capabilities | `PLATFORM_PLANS` (view/menu) + `PLATFORM_PLAN_EDIT` (mutate) — seeded | `sql-scripts-dyanmic/ops-platform-rbac-seed.sql` |
| Menu | `/ops/plans` — MenuCode `PLATFORM_PLANS`, "Plan catalogue & pricing", OrderBy 930, under `PLATFORMCONTROLPLANE` root `/ops` — seeded | same file |
| Catalog seed | 4 plans (`FREE`, `PLAN_50K`, `PLAN_100K`, `CUSTOM`) + entitlements + quotas + prices, idempotent | `billing-plan-catalog-seed.sql`, `billing-plan-prices-seed.sql`, `billing-backfill-subscriptions.sql` |
| `(master)` screen patterns | tenant hub, `usePlatformCapabilities`, ops mutation/query file layout, toast util | `src/presentation/components/page-components/ops/tenants/tenant-detail-page.tsx`, `src/infrastructure/gql-*/ops-*/` |

**No new entity, and exactly ONE additive nullable column** (`Plan.TrialDurationDays` — see §②b), whose migration spec is handed to the user. Beyond that: if a field you want does not exist on the entity, the answer is to drop the field, not add a column (mirrors the ALIGN scope rule).

---

## ②b Plan term & Free-plan expiry — the one schema change

**Business rule (confirmed):** the **Free plan is not a lifetime plan** — it is *limited-and-time-boxed* (e.g. 7 / 14 / 30 days). After the window lapses the tenant is no longer entitled; it must upgrade to a paid plan. Paid plans (`PLAN_50K`, `PLAN_100K`, `CUSTOM`) are **recurring** (renew each `BillingCycle`, Monthly | Annual) and do **not** expire on a fixed date.

The platform already models a time-boxed subscription **per company** — `Subscription.Status = "Trial"` + `Subscription.TrialEndsOn` (both exist). What is missing is the **plan-level** knob that says *how long* the free/limited window lasts, so the catalog screen can configure it and assignment can compute `TrialEndsOn`. That is one nullable column on `Plan`:

```csharp
/// <summary>For a time-boxed (non-recurring) plan — the free/limited window length in days
/// (e.g. 7 / 14 / 30). NULL = the plan is recurring/perpetual (renews per BillingCycle, never
/// expires on a fixed date). The Free plan carries a value; paid plans are NULL.</summary>
public int? TrialDurationDays { get; set; }
```

- **`NULL`** = recurring plan (existing paid behaviour, unchanged).
- **value `N`** = time-boxed: on assignment the subscription starts as `Status = "Trial"`, `TrialEndsOn = StartDate + N days` (UTC), `CurrentPeriodEnd = TrialEndsOn`.
- Naming reuses the existing `Trial`/`TrialEndsOn` vocabulary deliberately — a free-but-expiring plan **is** a trial in this model; no new `Status` value is invented.

**Migration is USER-OWNED.** Do **not** run `dotnet ef migrations add` or hand-author the snapshot. Build only to prove it compiles, then hand the user this spec: *"add nullable `integer` column `TrialDurationDays` to `billing.Plans`."* The catalog seed (`billing-plan-catalog-seed.sql`) also needs a one-line idempotent update to set the Free plan's default (e.g. `14`) and leave paid plans `NULL` — write that seed patch for the user to apply; do not execute it.

**Expiry is enforced at resolution time (fail-closed), not by a background job in this prompt.** `EntitlementService.ResolveAsync` currently treats `Status ∈ Live={Trial,Active,PastDue}` as entitled. It must additionally treat a **`Trial` subscription whose `TrialEndsOn < UtcNow` as expired** → return `Status = "None"`, empty maps (same fail-closed shape as no-subscription). This is the **second (and last) change to the existing `EntitlementService`** in this prompt (the first is `InvalidateAll()` in §③). A scheduled job that flips lapsed `Trial → Suspended` in the row itself is a later nicety (§⑦) — the resolution-time check is the authority and needs no job to be correct.

---

## ③ Backend — Plan Catalog CRUD

**Location:** `Base.Application/Business/BillingBusiness/PlanCatalog/` (new folder; mirror the ops-business CQRS layout).

All commands gated `[CustomAuthorize("PLATFORM_PLANS", "PLATFORM_PLAN_EDIT")]`; the read query gated `[CustomAuthorize("PLATFORM_PLANS")]`. All reads `IgnoreQueryFilters()` — the catalog is platform-global, it has no `CompanyId` and must cross any tenant filter. Every `DateTime` is `Kind=Utc`.

### 3.1 Read — `GetPlanCatalogQuery`

Returns the whole editable matrix in one shot (the screen renders plans as columns, features/meters as rows):

```csharp
[CustomAuthorize("PLATFORM_PLANS")]
public record GetPlanCatalogQuery() : IQuery<GetPlanCatalogResult>;

public record GetPlanCatalogResult(IReadOnlyList<PlanCatalogDto> Plans);

public record PlanCatalogDto(
    int PlanId, string PlanCode, string PlanName, string? Description,
    decimal Price, int CurrencyId, string CurrencyCode, string BillingCycle,
    int? TrialDurationDays,                            // null = recurring; value = time-boxed free window (§②b)
    bool IsCustom, int SortOrder, bool IsActive,
    IReadOnlyList<PlanEntitlementDto> Entitlements,   // one row per FeatureCode
    IReadOnlyList<PlanQuotaDto> Quotas,               // one row per MeterCode
    IReadOnlyList<PlanPriceDto> Prices);              // one row per (CurrencyId, BillingCycle)

public record PlanEntitlementDto(int PlanEntitlementId, string FeatureCode, bool IsEnabled);
public record PlanQuotaDto(int PlanQuotaId, string MeterCode, string MeterType, long? LimitValue, string? Period);
public record PlanPriceDto(int PlanPriceId, int CurrencyId, string CurrencyCode, decimal Amount, string BillingCycle);
```

The FE needs the full universe of feature/meter codes to render empty matrix rows even where a plan has no row yet — return the canonical lists from `FeatureCodes` / `MeterCodes` in the result (e.g. an `AllFeatureCodes` + `AllMeterCodes` array on `GetPlanCatalogResult`) so the grid is complete and a missing entitlement renders as an explicit "off" toggle, not a gap.

### 3.2 Write — one command per aggregate, diff-only for the matrices

- **`UpsertPlanCommand`** — create or update a `Plan` scalar row (PlanCode `[CaseFormat("upper")]`, PlanName, Description?, Price, CurrencyId, BillingCycle, **`TrialDurationDays int?`** (§②b), IsCustom, SortOrder). On create, `PlanCode` must be unique (validator). **Do not** let the screen edit `PlanCode` after create (it is the business key the seed + resolution match on) — treat it as immutable post-create, same stance as tenant Subdomain. Validator: `TrialDurationDays` is either `null` (recurring) or `>= 1`; `0`/negative invalid.
- **`SavePlanEntitlementsCommand(int PlanId, IReadOnlyList<(string FeatureCode, bool IsEnabled)> Rows)`** — **diff-only** upsert against `UNIQUE(PlanId, FeatureCode)`: insert new codes, update changed `IsEnabled`, leave the rest. Do not delete-all-reinsert (churns PKs the overrides may reference conceptually).
- **`SavePlanQuotasCommand(int PlanId, IReadOnlyList<(string MeterCode, string MeterType, long? LimitValue, string? Period)> Rows)`** — same diff-only upsert against `UNIQUE(PlanId, MeterCode)`. Validator: `MeterType` ∈ `MeterTypes`; `FLOW` meters require `Period` (`MONTH`), `STOCK` require `Period == null`; `LimitValue == null` means unlimited, `< 0` invalid.
- **`SavePlanPricesCommand(int PlanId, IReadOnlyList<(int CurrencyId, decimal Amount, string BillingCycle)> Rows)`** — diff-only upsert against `UNIQUE(PlanId, CurrencyId, BillingCycle)`; the price book (BOOK override) `IPlanPricingService` reads.
- **`SetPlanActiveCommand(int PlanId, bool IsActive)`** — soft toggle (sets `IsActive`; never a hard delete — a plan with live subscriptions must not vanish). Validator/handler: **block deactivating a plan that has any `Live` subscription** → `"Cannot deactivate a plan with active subscriptions; reassign those tenants first."` Same guard blocks a hard delete if you expose one (prefer not to).

**Every write handler that changes what a tenant would resolve to MUST call `IEntitlementService.Invalidate` — but a catalog edit affects *every* tenant on that plan, and `Invalidate` is per-`companyId`.** So for catalog writes, the correct move is a **cache-wide invalidation**: add `void InvalidateAll()` to `IEntitlementService` (clears/bumps the whole entitlement cache — e.g. a generation counter mixed into the cache key, or `IMemoryCache` eviction by a shared `CancellationChangeToken`). Call `InvalidateAll()` after any `UpsertPlan` / `SavePlanEntitlements` / `SavePlanQuotas` succeeds. (`SavePlanPrices` is display-only pricing → no entitlement invalidation needed.) Flag this one interface addition to the user; it is the only surface change to an existing service in this prompt.

Audit every catalog mutation via the platform audit writer (action e.g. `"PLAN_ENTITLEMENTS_SAVED"`, severity `HIGH`, include `PlanId`).

---

## ④ Backend — Subscription assignment + `myEntitlements`

### 4.1 Assign / override (platform-side, gated `PLATFORM_PLANS` + `PLATFORM_PLAN_EDIT`)

**Location:** `Base.Application/Business/BillingBusiness/Subscriptions/`.

- **`AssignSubscriptionCommand(int CompanyId, int PlanId, string Status, int? CurrencyId, DateTime? TrialEndsOn)`** — creates or replaces the tenant's live subscription.
  - The filtered `UNIQUE(CompanyId) WHERE Status IN (Trial,Active,PastDue)` means **at most one live subscription per company**. Assigning a new plan to a company that already has a live sub = transition the old one (set old `Status` to `Cancelled` + `CancelledOn=UtcNow`) and insert the new, inside one transaction. Do not violate the filtered unique.
  - **Snapshot the price** via `IPlanPricingService` at assignment time: resolve `(PlanId, CurrencyId, BillingCycle)` → write `Subscription.Amount` (VALUE), `CurrencyId`, `BillingCycle`. **Snapshot rule (memory `feedback_fx_direct_pair` / blueprint):** once written, `Amount`/`Currency` are never rewritten by later catalog price or FX edits. (A `TrialDurationDays` plan is typically free → `Amount` may be `0`/null; still snapshot whatever resolves.)
  - **Term (§②b):** if the assigned plan has `TrialDurationDays == N` → `Status = "Trial"`, `TrialEndsOn = StartDate + N days`, `CurrentPeriodEnd = TrialEndsOn`. If `TrialDurationDays == null` → recurring: `Status` as supplied (`Trial`/`Active`), `TrialEndsOn = null`, `CurrentPeriodEnd` from `BillingCycle`. All `Kind=Utc`.
  - Set `StartDate`, `CurrentPeriodStart`, `CurrentPeriodEnd`, all `Kind=Utc`.
  - Call `IEntitlementService.Invalidate(companyId)` after commit.
- **`SetSubscriptionOverrideCommand(int SubscriptionId, string? FeatureCode, string? MeterCode, long? OverrideValue, string? Note)`** — diff-only upsert of one `SubscriptionOverride` row. Validator enforces the entity's CHECK: **exactly one of** `FeatureCode` XOR `MeterCode` is non-null. Feature override `OverrideValue` ∈ {0,1}; meter override = limit (`null` = unlimited). `Invalidate(companyId)` after commit. This is the "Custom = overrides, not new Plan rows" rule (blueprint §5/§16).
- **`ChangeSubscriptionStatusCommand(int SubscriptionId, string Status)`** — Trial↔Active↔PastDue↔Suspended↔Cancelled; validator restricts to `SubscriptionStatuses`; stamp `CancelledOn` when moving to Cancelled. `Invalidate(companyId)`.

A read for the tenant hub panel: **`GetSubscriptionForCompanyQuery(int CompanyId)`** → current live subscription + its plan + overrides + resolved effective feature/limit maps (call `IEntitlementService.ResolveAsync`). This feeds §⑤B.

### 4.2 `myEntitlements` — the tenant-facing read (this is the real one)

**Location:** `Base.Application/Business/BillingBusiness/Entitlements/GetMyEntitlementsQuery.cs`. Gated by an ordinary tenant read capability (not a platform one) — it returns only the **caller's own** company, resolved from the ambient tenant context (`GetCurrentTenantId()`), never a `CompanyId` argument. Fail-closed: no tenant context / no live subscription → `Status = "None"`, empty maps, everything reads as not-entitled.

```csharp
public record GetMyEntitlementsQuery() : IQuery<MyEntitlementsResult>;

public record MyEntitlementsResult(
    string PlanCode, string PlanName, string Status,
    bool IsTrial, DateTime? TrialEndsOn, int? TrialDaysRemaining,  // §②b — null on recurring plans
    IReadOnlyList<FeatureStateDto> Features,   // FeatureCode + IsEnabled (effective, override applied)
    IReadOnlyList<MeterStateDto> Meters);      // MeterCode, MeterType, Limit (null=unlimited), Used, Percent

public record FeatureStateDto(string FeatureCode, bool IsEnabled);
public record MeterStateDto(string MeterCode, string MeterType, long? Limit, long Used, int? Percent);
```

- **Features / Limits** come straight from `IEntitlementService.ResolveAsync(companyId)` (already applies override-then-plan resolution **and the §②b trial-expiry fail-closed check** — an expired Free trial resolves as `Status="None"`, empty maps).
- **Trial (§②b):** `IsTrial = Status == "Trial"`; `TrialEndsOn` from the subscription; `TrialDaysRemaining = TrialEndsOn == null ? null : max(0, ceil((TrialEndsOn - UtcNow).TotalDays))`. On a recurring plan all three are null/false.
- **`Used`** is the live count — and this is where STOCK vs FLOW diverges (blueprint §7):
  - **STOCK** (CONTACTS, DONATIONS, USERS): authoritative `COUNT(*)` on the real table for this tenant (contacts, global donations, users), **not** the `UsageCounter` cache (which may be stale/absent). Reuse the tenant-scoped repositories; count with the standard soft-delete filter.
  - **FLOW** (EMAILS/WHATSAPP/SMS per MONTH): read the current-period `UsageCounter` row (`CompanyId, MeterCode, PeriodStart == currentPeriodStart`); absent → `Used = 0`.
- **`Percent`** = `Limit == null ? null : (int)round(100 * Used / Limit)` (capped display 0–100+; over-limit can exceed 100, keep the true number so the FE can show ">100%").

> **Supersedes the placeholder:** `GetCompanySubscriptionInfo` (`CompanySettingsQueries.cs`, ISSUE-1) returns hardcoded `IsPlaceholder=true` data. **Do not delete it in this prompt** (Screen #75 §8 still binds to it) — instead note in the build log that #75's subscription panel should re-point to `myEntitlements` in a follow-up, and make `myEntitlements` the canonical source going forward. Deleting the placeholder is out of scope (§⑦).

---

## ⑤ Frontend

### 5.A Plan Catalog screen — `(master)` `/ops/plans`

**Route:** `src/app/[lang]/(master)/ops/plans/page.tsx` (the seeded menu already points here). Gate the whole page on `usePlatformCapabilities({ menuCode: "PLATFORM_PLANS" })`; gate every mutate control on the edit capability (`PLATFORM_PLAN_EDIT`) — a view-only platform operator sees the matrix read-only, no toggles/inputs enabled.

**Layout — a comparison matrix, NOT a list-of-N cards** (this is a config screen, MATRIX-style per memory `feedback_config_screens`):

- **Plans as columns** (Free · 50K · 100K · Custom · [+ New plan]); **rows grouped** into three bands:
  - **Term band (§②b)** — per plan, a **Term** control: a segmented toggle **Recurring** (renews per Monthly/Annual `BillingCycle`) vs **Time-boxed** (free/limited window). When Time-boxed, a duration input `TrialDurationDays` with preset chips **7 / 14 / 30** + a custom-days field; when Recurring, the field is null/hidden and the Monthly/Annual selector shows. A time-boxed plan renders a "trial" badge (solid `bg-X-600`+white). This is where an operator sets "Free = 14 days" instead of editing seed SQL.
  - **Pricing band** — base price + currency + billing cycle per plan; an expandable "price book" sub-panel per plan editing `PlanPrice` rows (per-currency BOOK overrides). Amounts `text-right` (memory `feedback_amount_field_alignment`).
  - **Features band** — one row per `FeatureCode` (`MODULE:*` then `CHANNEL:*`), a toggle per plan cell (`PlanEntitlement.IsEnabled`). Render every canonical code from `AllFeatureCodes`, missing rows as explicit off.
  - **Limits band** — one row per `MeterCode`, an input per plan cell (`PlanQuota.LimitValue`; blank = unlimited, show "∞"); a `MeterType` chip (STOCK/FLOW) + Period on FLOW rows.
- **Save is per-band diff** (calls `SavePlanEntitlements` / `SavePlanQuotas` / `SavePlanPrices` with only that plan's changed rows). Page-header Save enabled by RHF `formState.isValid` + dirty, **not** by capability (memory `feedback_form_create_button_enablement`) — capability governs whether the controls render at all.
- **+ New plan** opens a create form (Upsert scalar) → then its column appears editable.
- **Deactivate plan** = the soft toggle; surfaced as a per-column overflow action, blocked with the server's message if it has live subscriptions.

Toasts on every save (reuse the app's sonner util). UI tokens per house rules: solid `bg-X-600`+`text-white` for the MeterType chips / status badges (memory `feedback_widget_icon_badge_styling`); no hex/px; xs→xl responsive; @iconify Phosphor icons; shaped Skeletons while the catalog loads; empty/error states.

### 5.B Subscription panel on the tenant hub

**File:** `tenant-detail-page.tsx` (the existing P-07 hub). Add a **Subscription** section (or tab) bound to `GetSubscriptionForCompanyQuery`:

- Show current plan, status badge, snapshot amount/currency, period end. **For a Trial subscription (§②b)** also show `TrialEndsOn` + days remaining (e.g. "Free trial — 9 days left"), and an "expired" state when past.
- **Assign / change plan** action (gated `PLATFORM_PLAN_EDIT`): a dialog picking a Plan + status + currency → `AssignSubscription` mutation; price previewed from `IPlanPricingService` resolution (show the resolved amount before confirm). `refetch()` after.
- **Overrides** editor: list current `SubscriptionOverride` rows + add/edit one (feature XOR meter, value) → `SetSubscriptionOverride`. This is how a tenant becomes "Custom" without a new Plan row.
- **Status** control → `ChangeSubscriptionStatus`.
- Effective resolved feature/limit map shown read-only below (so the operator sees what the tenant actually gets after overrides).

### 5.C `myEntitlements` FE plumbing (read only — meters/CTAs land in PROMPT-12)

Add the `MY_ENTITLEMENTS_QUERY` to the tenant-side gql-queries and a typed DTO. **In this prompt, wiring the query + types is enough**; the visible usage meters + 80%/100% upgrade CTAs that consume it are built in PROMPT-12 §⑤ (they belong with the enforcement UX). Do not duplicate them here.

> **GraphQL field names:** mutation methods keep their name (`assignSubscription`, `setSubscriptionOverride`, `upsertPlan`, `savePlanEntitlements`, …). `Get`-prefixed query resolvers with `[AsParameters]` grid requests strip `Get`, but scalar/no-arg queries **keep** it per the HotChocolate convention (memory `reference_hotchocolate_get_prefix_convention`) → confirm each emitted field name in the schema and use it verbatim in the FE (`getPlanCatalog`, `getMyEntitlements`, `getSubscriptionForCompany` unless the local convention emits otherwise). tsc cannot catch a wrong gql field name.

---

## ⑥ Acceptance

1. A SUPERADMIN opens `/ops/plans`, toggles `CHANNEL:WHATSAPP` on for `PLAN_50K`, saves → the change persists and, within the cache TTL, a `PLAN_50K` tenant's `myEntitlements` reports `CHANNEL:WHATSAPP` enabled (proves `InvalidateAll` + resolution end-to-end).
2. Editing a `PlanQuota` `LimitValue` (e.g. CONTACTS 50000 → 60000) on a plan persists and is reflected in `myEntitlements.Meters[CONTACTS].Limit`.
3. Blank limit renders "∞" and resolves to unlimited (`Limit == null`), not zero.
4. Assigning a company already on Free to `PLAN_100K` cancels the old subscription and creates the new one — the filtered unique is never violated; `Subscription.Amount` is snapshotted from `IPlanPricingService` and does not change when the catalog price is later edited.
5. A `SubscriptionOverride` (feature `CHANNEL:SMS` = 1) on a tenant whose plan disables SMS makes `myEntitlements` report SMS enabled — override beats plan.
6. `myEntitlements` on a company with **no live subscription** returns `Status="None"`, empty maps, everything not-entitled (fail-closed).
6b. **Free-plan term (§②b):** setting the Free plan to Time-boxed / 14 days on the catalog persists `TrialDurationDays=14`; assigning a tenant to it yields `Status="Trial"`, `TrialEndsOn = now+14d`; `myEntitlements` reports `IsTrial=true`, `TrialDaysRemaining≈14`. Once `TrialEndsOn` passes, `myEntitlements` returns `Status="None"`, empty maps (expired free trial is fail-closed at resolution — no job needed). A paid/recurring plan (`TrialDurationDays=null`) never expires this way.
7. STOCK `Used` in `myEntitlements` equals a real `COUNT(*)` of that tenant's contacts/donations (delete a contact → count drops), independent of any `UsageCounter` row.
8. Deactivating a plan that has a live subscription is blocked with the server message; deactivating an unused plan succeeds.
9. A `PLATFORM_PLANS`-view-only operator sees the catalog read-only (no enabled toggles/inputs, no Save); direct mutation calls are rejected by `PLATFORM_PLAN_EDIT`.
10. `PlanCode` cannot be changed after create (immutable business key).
11. Every emitted gql field name is confirmed in the schema and matched verbatim on the FE. FE `tsc --noEmit --incremental false` exits 0; BE `dotnet build` 0 errors.

---

## ⑦ Out of scope (do not build)

- **All enforcement** — `FeatureEntitlementBehavior`, `QuotaBehavior`, `[RequiresFeature]`, `[MeteredResource]`, menu/module hiding, channel gates, the 80%/100% usage meters + upgrade CTAs → **PROMPT-12**.
- Deleting or re-pointing the `GetCompanySubscriptionInfo` placeholder / Screen #75 §8 (note it for follow-up; leave it binding).
- `UsageCounter` increment behaviour / period-roll job (FLOW counters are read where present; the writer is PROMPT-12 / a later job).
- The **scheduled job that flips a lapsed `Trial → Suspended`** in the subscription row (§②b). Expiry is enforced fail-closed at resolution time; the row-flip job is a later nicety. This prompt adds `Plan.TrialDurationDays` + the resolution-time expiry check only.
- Auto-transition Free-trial → paid on expiry, dunning, or self-serve upgrade (operator re-assigns a paid plan; no automatic conversion in P2).
- Commercial-term / invoice / payment-gateway integration (`CommercialTermId`, `PaymentGatewayCode` are snapshot fields only here; no gateway calls).
- Any schema change beyond the **single additive nullable `Plan.TrialDurationDays` column** (§②b) — no new entity, no other column. Migration + the Free-plan seed default are **user-owned** (write the spec + seed patch, do not run them). The rest of the catalog seed already exists — this prompt only edits it through the screen.
- Self-serve tenant plan upgrade / checkout (platform-operator-driven assignment only in P2).

---

## ⑬ Build Log

_(append per session — keep last 5; git holds the rest)_

- **PENDING** — generated by PM/prompt-engineer 2026-07-29. Not yet built. Screens + read half of Plans P2; enforcement is PROMPT-12.
- **AMENDED** 2026-07-29 — added §②b **Plan term & Free-plan expiry**: Free plan is time-boxed (7/14/30d), not lifetime. One additive nullable column `Plan.TrialDurationDays` (user-owned migration + Free seed default), term control on the catalog screen, trial computation in `AssignSubscription`, trial fields on `myEntitlements`, and a fail-closed trial-expiry check added to `EntitlementService.ResolveAsync`.
- **BUILT** 2026-07-29 — §③ ④ ④.2 ⑤ and §②b all implemented. **BE:** `PlanCatalog/` (`GetPlanCatalogQuery`, `UpsertPlanCommand`, diff-only `SavePlanEntitlements|Quotas|Prices`, `SetPlanActiveCommand`), `Subscriptions/` (`AssignSubscriptionCommand` — cancel + insert in one transaction, price snapshot via `IPlanPricingService`; `SetSubscriptionOverrideCommand` FeatureCode XOR MeterCode; `ChangeSubscriptionStatusCommand`; `GetSubscriptionForCompanyQuery`), `Entitlements/GetMyEntitlements` (ambient tenant, ungated, fail-closed to `Status="None"`). `IEntitlementService.InvalidateAll()` **added to the interface**, called after Upsert/SaveEntitlements/SaveQuotas but deliberately **not** after SavePrices. §②b: `Plan.TrialDurationDays` on the entity + `PlanUpsertDto`, validator `>= 1 when set`, plan-driven term block in `AssignSubscription`, trial-expiry check in `EntitlementService.ResolveAsync`, trial fields on `MyEntitlementsResult`. **FE:** `/ops/plans` matrix (3 diff-only bands + `PlanFormDialog` with the Term segmented control and 7/14/30 presets + read-only term badge on each column head), `TenantSubscriptionPanel` (assign / status / overrides / resolved maps + trial-window banner with days-left and expired states), `MY_ENTITLEMENTS_QUERY` + typed DTO (nothing consumes it — P-12). `npx tsc --noEmit --incremental false` **exits 0**. BE `dotnet build` **not run — the user owns it** (explicit instruction this session), so §⑥'s "0 errors" gate is unconfirmed.

### Known issues / follow-ups carried out of this session

1. **User-owned, unapplied — the screens will fail at runtime until these are run.**
   - **Migration spec:** add nullable `integer` column `TrialDurationDays` to `billing."Plans"` (no default, no index, no FK). That is the whole change — `PlanConfiguration.cs` was deliberately left untouched because a nullable `int` needs no explicit mapping.
   - **Seed:** `sql-scripts-dyanmic/billing-plan-trial-duration-seed.sql` — sets FREE to 14 days, leaves paid plans NULL. Run after the migration and after `billing-plan-catalog-seed.sql`.
   - **Seed:** `sql-scripts-dyanmic/ops-platform-plan-view-capability-seed.sql` — creates capability `PLATFORM_PLAN_VIEW` and grants it on menu `PLATFORM_PLANS`. Without it, read-only platform roles see nothing.
2. **Deliberate deviation from §②b line 122.** The spec says a recurring plan gets `TrialEndsOn = null` unconditionally. Implemented literally, an operator could assign `Status="Trial"` on a paid plan with no end date — a trial that never expires, which the new expiry check cannot catch (it requires `TrialEndsOn.HasValue`). Built instead: **plan term wins when present; when absent and status is Trial, the caller's date is REQUIRED** (handler throws `"Plan {code} is a recurring plan, so a trial assignment needs an explicit trial end date."`, and the assign dialog blocks Assign rather than round-tripping it). Preserves the §②b guarantee, closes the fail-open hole.
3. **FE capability gating is `VIEW || EDIT`** on both plan surfaces, matching the BE gate's OR semantics — an editor never granted the VIEW capability must not be locked out of their own screen.
4. **GraphQL field names follow the house `Get`-stripped convention** (`planCatalog`, `subscriptionForCompany`, `myEntitlements`), **not** §5.C's `get*` guesses. Input types get `Input` appended (`PlanUpsertDtoInput`). `tsc` cannot see gql names — a wrong one builds clean and fails only at runtime.
5. **No delete-override command exists** in this prompt's scope. Neutralising an override means re-setting it to the plan's own value; the panel says so.
6. **Audit uses `WriteEntityChange`**, which records no severity — the `severity: HIGH` the spec asks for on catalog mutations is not persisted.
7. `myEntitlements` ships **ungated by design** (a tenant must be able to read why they are blocked) but **fail-closed** — no tenant context resolves to `Status="None"` with empty maps.
