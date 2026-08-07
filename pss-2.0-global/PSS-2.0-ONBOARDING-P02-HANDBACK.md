# P-02 Hand-back — Billing schema + IEntitlementService + plan catalog seed

## What I built (schema + entities + EF config + one service + two seeds only)

**New `billing` entities** (`Base.Domain/Models/BillingModels/` — new folder mirroring `OpsModels/`;
all inherit `Entity`, all `int` identity keys):
- `Plan.cs` — `[Table("Plans", Schema = "billing")]`. `PlanCode` `[CaseFormat("upper")]`. **`IsActive`
  reuses the Entity base column — not re-declared** (no shadow property).
- `PlanEntitlement.cs` — MODULE:*/CHANNEL:* on/off; nav → Plan (CASCADE).
- `PlanQuota.cs` — STOCK/FLOW numeric limits; `LimitValue` NULL = unlimited; nav → Plan (CASCADE).
- `Subscription.cs` — company↔plan over a period; `CommercialTermId` int **no FK yet**; nav → Company,
  Plan, and Overrides (CASCADE).
- `SubscriptionOverride.cs` — per-company feature/meter deviation; XOR CHECK; nav → Subscription (CASCADE).
- `UsageCounter.cs` — company/meter/period counter (shape only; no increment behaviour in P-02).

**EF configs** (`Base.Infrastructure/Data/Configurations/BillingConfigurations/` — new folder,
auto-discovered by `ApplyConfigurationsFromAssembly`): one per entity —
`PlanConfiguration`, `PlanEntitlementConfiguration`, `PlanQuotaConfiguration`,
`SubscriptionConfiguration`, `SubscriptionOverrideConfiguration`, `UsageCounterConfiguration`.
Keys (`UseIdentityAlwaysColumn`), lengths, `Price` `HasPrecision(18,2)`, all FKs with explicit
`DeleteBehavior`, the unique indexes, the **filtered unique** subscription index
(`HasFilter("\"Status\" IN ('Trial','Active','PastDue')")`), and the SubscriptionOverride
**XOR check constraint** (`ToTable(t => t.HasCheckConstraint(...))`).

**Context facet (partial-class pattern, NO new DbContext, NO DI-for-context change):**
- `Base.Application/Data/Persistence/IBillingDbContext.cs` — 6 DbSets + `//IBillingDbContextLines` marker.
- `Base.Infrastructure/Data/Persistence/BillingDbContext.cs` — `public partial class ApplicationDbContext : IBillingDbContext` exposing DbSets via `Set<T>()`.
- Added `IBillingDbContext` to the `IApplicationDbContext` inheritance list.
- Added `global using Base.Domain.Models.BillingModels;` to `Base.Infrastructure/GlobalUsing.cs`.

**Service (`IEntitlementService`):**
- `Base.Application/Interfaces/IEntitlementService.cs` — interface + immutable
  `TenantEntitlements(int CompanyId, string PlanCode, string Status, IReadOnlyDictionary<string,bool>
  Features, IReadOnlyDictionary<string,long?> Limits)` record.
- `Base.Application/Interfaces/BillingCodes.cs` — `FeatureCodes`, `MeterCodes`, `MeterTypes`,
  `PlanCodes`, `SubscriptionStatuses` constants (single source of truth shared by service + intent-of-seed).
- `Base.Infrastructure/Services/Billing/EntitlementService.cs` — resolution (`override ?? plan`),
  fail-closed on no active subscription (Status `"None"`, empty maps, **never throws**), IMemoryCache
  keyed by companyId with 60s TTL + `Invalidate`.
- Registered `services.AddScoped<IEntitlementService, EntitlementService>();` in
  `Base.Infrastructure/DependencyInjection.cs` (next to `IFxRateService`). `AddMemoryCache()` is
  already registered in `Base.API/DependencyInjection.cs`.

**Seeds** (`sql-scripts-dyanmic/`, idempotent `INSERT … WHERE NOT EXISTS`, user-applied):
- `billing-plan-catalog-seed.sql` — 4 plans + 40 entitlements (10×4) + 16 quotas (4×4), verbatim
  from the DQ4 matrix.
- `billing-backfill-subscriptions.sql` — every non-deleted company (incl. `__TEMPLATE__`) with no
  active subscription → default **CUSTOM / Active** (all-modules-on, unlimited ⇒ existing tenants
  keep working). **Run AFTER the catalog seed** (needs CUSTOM to exist).

**Migration spec:** `PSS-2.0-ONBOARDING-P02-MIGRATION-SPEC.md` (all 6 tables, columns/types/nullability,
FKs, indexes incl. the raw partial-index DDL, the XOR CHECK DDL, no-FK-yet table).

---

## ⚠️ Key deviation — FeatureCode vocabulary vs real `auth.Modules` (flag for P-03)

The DQ4 map + prompt assume **fine-grained** module codes (`CONTACTS`, `DONATION`, `CASE`, `GRANT`,
`VOLUNTEER`, `EVENT`, `MEMBERSHIP`). The **real** `auth.Modules` rows are **coarse** with **Guid**
keys: `SETTING`, `REPORTAUDIT`, `ACCESSCONTROL`, `ORGANIZATION`, `CRM`, `GENERAL`
(verified in `html_mockup_screens/Pss2.0_Menus.sql` + `Base.Domain/Models/AuthModels/Module.cs`).

**Decision:** `PlanEntitlement.FeatureCode` is a **free string with NO FK** to `auth.Modules`, so I
seeded the **DQ4-decided vocabulary verbatim** (`MODULE:CONTACTS`, `CHANNEL:WHATSAPP`, …) — it is the
decided spec and the prompt explicitly allows "if a code differs, use the real one and note it."
**No mapping to the coarse auth modules exists yet.** P-03 step 4 ("grant new tenant role-capabilities
∩ plan entitlements") **must add an auth `ModuleCode` → `FeatureCode` mapping layer** — the two
vocabularies do not line up 1:1 (e.g. `CRM` ⊃ Contacts+Donation; Case/Grant have no coarse-module
equivalent). This is the single most important thing to carry into P-03.

## Placeholder values (editable later; MVP only needs the tier SHAPE)
- Plan `Price`/`Currency`/`BillingCycle` are illustrative (INR; FREE monthly, paid annual).
- `PLAN_50K`/`PLAN_100K` `EMAILS`/mo limits (50,000 / 200,000) are **invented** — the DQ4 map says
  "plan limit" with no number. Adjust in the seed or via the Plan Catalog screen.
- Per the DQ4 MVP note, exact quotas are trivially editable later; the module→tier shape is locked.

## Design choices worth noting
1. **Fail-closed, no throw.** No active subscription ⇒ `TenantEntitlements` with Status `"None"` and
   empty Feature/Limit maps. `HasFeatureAsync` → false; `GetLimitAsync` → **0** for an absent meter
   (not-provisioned), and **null** only when a provisioned meter is explicitly unlimited.
2. **`IgnoreQueryFilters()` in the resolver.** `Subscription`/`UsageCounter` carry `CompanyId`, so the
   global `ApplyTenantFilters` would scope them to the ambient tenant. The resolver reads by an
   **explicit** companyId with `IgnoreQueryFilters()` (and an explicit `IsDeleted != true` guard,
   since ignoring filters also drops any soft-delete filter) so it is correct in background /
   provisioning / cross-tenant SuperAdmin contexts. Flagged in the migration spec too.
3. **Override semantics.** Feature override → `OverrideValue` read as 0/1 boolean. Meter override →
   `OverrideValue` is the numeric limit (NULL = unlimited). Resolution layers overrides on top of the
   plan baseline (`override ?? plan`).
4. **CUSTOM = enterprise default.** All modules/channels enabled, all quotas seeded **unlimited**
   (LimitValue NULL); real per-company numbers come from `SubscriptionOverride`, never the plan row.
   This is why the backfill assigns CUSTOM — existing tenants are unconstrained until re-planned.

## Constraints honored
- **No `dotnet ef migrations add/update/remove`; no hand-authored migration or snapshot file.**
- **No BE build run** (per user: "avoid BE build, I can build that"). Entities/configs/service are
  written to the established patterns; the user builds.
- No SQL executed against any DB (seeds written only).
- All keys `int` identity (`UseIdentityAlwaysColumn().ValueGeneratedOnAdd()`); no `Guid`.
- No new `DbContext` subclass, no manual `ApplyConfiguration`; single scoped-service DI line added.
- Scope = schema + entities + EF config + one service + two seeds. **No enforcement, no GraphQL, no
  UI, no usage-increment.** Did **not** start P-03.

---

## Report to PM
- **Files created:** 6 entities, 6 configs, `IBillingDbContext`/`BillingDbContext`, `IEntitlementService`
  + `BillingCodes` + `EntitlementService`; edits to `IApplicationDbContext`, `GlobalUsing.cs`,
  `DependencyInjection.cs`.
- **Build clean:** **not run** (user owns the BE build). No obvious compile risks — patterns mirror P-01
  + `FxRateService`; global usings/DI/using-statements wired.
- **Migration spec:** ✅ `PSS-2.0-ONBOARDING-P02-MIGRATION-SPEC.md`.
- **Seed paths:** `sql-scripts-dyanmic/billing-plan-catalog-seed.sql`,
  `sql-scripts-dyanmic/billing-backfill-subscriptions.sql` (apply in that order, after the migration).
- **Modules verified:** ✅ — real `auth.Modules` are coarse Guid-keyed (CRM/SETTING/…); FeatureCode is a
  no-FK string, seeded with the DQ4 vocabulary. **Mismatch flagged for P-03 (mapping layer required).**
- **Do NOT proceed to P-03.**
