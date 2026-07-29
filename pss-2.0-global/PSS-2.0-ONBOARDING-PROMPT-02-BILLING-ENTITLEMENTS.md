# DEV PROMPT P-02 — Billing schema + entitlement service + plan seed

> Paste everything below into a **fresh development session**. It is self-contained.
> When done, report back to the PM session; do **not** proceed to P-03.

---

## Role & mission

You are a Senior Backend Developer on the PSS 2.0 multi-tenant **.NET (net10.0)** platform. Your task is **P-02: stand up the `billing` schema (plans, subscriptions, usage), the `IEntitlementService`, and the plan-catalog seed** — the layer that provisioning **step 4** ("grant capabilities ∩ plan entitlements") and the runtime feature/quota gates will run on. You build **schema + entities + EF config + one service + two seed scripts only** — no enforcement behaviors, no GraphQL, no UI.

## Read first (grounding — do not skip)

1. `PSS-2.0-ONBOARDING-TASK-LIST.md` — tasks **T-A4** (billing entities) and **T-A5** (`IEntitlementService` + plan seed) are your scope.
2. `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md` §3 (exact entity columns), §4 (feature/meter code registry), §6 (`IEntitlementService` shape + resolution rule + caching), §13 (seeding + backfill).
3. `PSS-2.0-ONBOARDING-DQ4-MODULE-PLAN-MAP.md` — **the DECIDED module→plan matrix.** This is the seed spec. Use its "Recommended default matrix" table verbatim.

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add`, `database update`, or `remove`, and do **NOT** hand-author a migration or model-snapshot file. Build to prove compile, then produce a **migration spec** (markdown) for the user to author, run, and commit.
- 🌱 **Seed files:** you write them (idempotent upserts, matching `sql-scripts-dyanmic/*.sql` style); the **user applies** them. Do not execute SQL against any database.
- **All PKs/FKs are `int` identity.** `Company.CompanyId` is `int`. No `Guid` keys.
- **UTC only.** Every date column is `timestamp with time zone`; use `DateTime.UtcNow`, build boundaries with `DateTimeKind.Utc`. Npgsql throws on `Kind=Unspecified`. Note the `Entity` base defaults `CreatedDate = DateTime.Now` — override to UtcNow on any write path.
- **Audit fields** come from the `Entity` base (`CreatedDate`/`ModifiedDate` etc.) — inherit `Entity`, do not re-declare them.
- **Verify before using:** the seed references module codes as `MODULE:<ModuleCode>`. **Grep the real `auth.Modules` codes** (table/seed) and confirm the exact strings (`CONTACTS`, `DONATION`, `CASE`, `GRANT`, `VOLUNTEER`, `EVENT`, `MEMBERSHIP`) before writing `FeatureCode` values. If a code differs, use the real one and note it.
- Additive only. Do not modify tenant/business handlers.

## Codebase anchors — **follow the pattern P-01 just committed**

P-01 created the `ops` schema using the house pattern. **Copy that exact structure for `billing`.** Study these now-existing files as your template:

- `Base.Application/Data/Persistence/IOpsDbContext.cs` — the per-module context **interface** (DbSets). Make an equivalent **`IBillingDbContext`**.
- `Base.Infrastructure/Data/Persistence/OpsDbContext.cs` — note it is `public partial class ApplicationDbContext : IOpsDbContext` exposing DbSets via `Set<T>()`. Make an equivalent **`public partial class ApplicationDbContext : IBillingDbContext`** in `BillingDbContext.cs`. **No new `DbContext` subclass, no DI change for the context, no `OnModelCreating`.**
- `Base.Application/Data/Persistence/IApplicationDbContext.cs` — add **`IBillingDbContext`** to its inheritance list (as `IOpsDbContext` was added).
- `Base.Infrastructure/Data/Configurations/OpsConfigurations/*.cs` — the `IEntityTypeConfiguration<T>` classes (keys, `UseIdentityAlwaysColumn().ValueGeneratedOnAdd()`, `HasMaxLength`, FKs via `HasOne().WithMany().HasForeignKey().OnDelete()`, `HasIndex().IsUnique()`). Make a new **`BillingConfigurations/`** folder with one config class per entity. These are **auto-discovered** by the existing `ApplyConfigurationsFromAssembly` — no manual registration.
- Entity models: put the new `billing` models in **`Base.Domain/Models/BillingModels/`** (mirror `OpsModels/`). Add that namespace to `Base.Infrastructure`'s `GlobalUsing.cs` (P-01 did the same for `OpsModels`).
- **Table + schema = annotation only:** `[Table("Plans", Schema = "billing")]` etc. Everything else lives in the config class.
- **Status/type/enum-ish columns = `varchar` strings**, exactly as P-01 mapped `Status`/`Mode`/`StepCode`. Store the literal values from §3 verbatim (see each entity below). Do not introduce int-enums or MasterData FKs for these.
- **jsonb:** none in this prompt.
- **Service pattern:** locate an existing application service interface + implementation + DI registration (e.g. `IFxRateService` / its impl) and mirror the placement + `services.AddScoped<IEntitlementService, EntitlementService>()` registration and `IMemoryCache` usage.

## Scope — build exactly this

### A. `billing` context surface (partial-class facet)
`IBillingDbContext` interface + `public partial class ApplicationDbContext : IBillingDbContext` (DbSets via `Set<T>()`) + add `IBillingDbContext` to `IApplicationDbContext`. Exposes the six DbSets below.

### B. Six `billing` entities (T-A4) — columns exactly per §3

1. **`billing.Plans`** — `PlanId` PK · `PlanCode` varchar(30) **UNIQUE** (`FREE|PLAN_50K|PLAN_100K|CUSTOM`) · `PlanName` · `Description?` · `Price` decimal(18,2) · `Currency` varchar(10) · `BillingCycle` varchar(20) (`Monthly|Annual`) · `IsCustom` bool · `IsActive` bool · `SortOrder` int.
2. **`billing.PlanEntitlements`** — `PlanEntitlementId` PK · `PlanId` FK→Plan (CASCADE) · `FeatureCode` varchar(60) (`MODULE:*`/`CHANNEL:*`) · `IsEnabled` bool · **UNIQUE (PlanId, FeatureCode)**.
3. **`billing.PlanQuotas`** — `PlanQuotaId` PK · `PlanId` FK→Plan (CASCADE) · `MeterCode` varchar(30) · `MeterType` varchar(10) (`STOCK|FLOW`) · `LimitValue` bigint **NULL** (null = unlimited) · `Period` varchar(10) NULL (`MONTH` for FLOW; null for STOCK) · **UNIQUE (PlanId, MeterCode)**.
4. **`billing.Subscriptions`** — `SubscriptionId` PK · `CompanyId` int FK→`app.Companies` (**this FK exists now** — wire it, Restrict) · `PlanId` int FK→Plan (Restrict) · `CommercialTermId` int **NULL — NO FK yet** (`ops.CommercialTerm` is P-05; plain nullable int, same treatment P-01 gave `LeadId`) · `Status` varchar(20) (`Trial|Active|PastDue|Suspended|Cancelled`) · `StartDate`, `CurrentPeriodStart`, `CurrentPeriodEnd` timestamptz · `TrialEndsOn?`, `CancelledOn?` timestamptz NULL · **filtered UNIQUE index (CompanyId) WHERE Status IN ('Trial','Active','PastDue')** — express via `HasIndex(x=>x.CompanyId).IsUnique().HasFilter("...")`; also put the filter SQL in the migration spec.
5. **`billing.SubscriptionOverrides`** — `SubscriptionOverrideId` PK · `SubscriptionId` FK→Subscription (CASCADE) · `FeatureCode` varchar(60) NULL · `MeterCode` varchar(30) NULL · `OverrideValue` bigint NULL · `Note` varchar(500) NULL · **CHECK: exactly one of FeatureCode/MeterCode set** — put the `CHECK ((FeatureCode IS NOT NULL) <> (MeterCode IS NOT NULL))` in the **migration spec** (user authors it); optionally also via `ToTable(t => t.HasCheckConstraint(...))`.
6. **`billing.UsageCounters`** — `UsageCounterId` PK · `CompanyId` int FK→`app.Companies` (Restrict) · `MeterCode` varchar(30) · `PeriodStart` timestamptz · `CurrentValue` bigint · **UNIQUE (CompanyId, MeterCode, PeriodStart)**. (Entity + table only this prompt — no counter logic.)

> `FeatureCode`/`MeterCode` are **string codes, not FKs** — no DB FK to `auth.Modules`. Match the code strings to the real Module codes you verified.

### C. `IEntitlementService` (T-A5) — per §6
Interface (Base.Application) + implementation (Base.Infrastructure), DI-registered scoped:
```csharp
Task<TenantEntitlements> ResolveAsync(int companyId, CancellationToken ct);
Task<bool>  HasFeatureAsync(int companyId, string featureCode, CancellationToken ct);
Task<long?> GetLimitAsync(int companyId, string meterCode, CancellationToken ct); // null = unlimited
void        Invalidate(int companyId); // cache flush hook — callers wired in later prompts
```
- `TenantEntitlements(int CompanyId, string PlanCode, string Status, IReadOnlyDictionary<string,bool> Features, IReadOnlyDictionary<string,long?> Limits)`.
- **Resolution rule:** effective feature = `SubscriptionOverride ?? PlanEntitlement.IsEnabled`; effective limit = `SubscriptionOverride.OverrideValue ?? PlanQuota.LimitValue`. Resolve from the company's **active** Subscription (`Status IN Trial/Active/PastDue`); no active subscription → return an empty/deny set (fail-closed), do **not** throw.
- **Caching:** `IMemoryCache` keyed by `CompanyId`, ~60s TTL backstop; `Invalidate(companyId)` evicts. (Do not wire invalidation callers — that's later.)
- **No enforcement behaviors** (`FeatureEntitlementBehavior`/`QuotaBehavior`), no `myEntitlements` GraphQL — those are a later prompt.

### D. Two seed scripts (🌱 idempotent, under `sql-scripts-dyanmic/`)
1. **`billing-plan-catalog-seed.sql`** — the 4 Plans + their PlanEntitlement + PlanQuota rows, **exactly per the DECIDED matrix in `PSS-2.0-ONBOARDING-DQ4-MODULE-PLAN-MAP.md`** (FREE: Contacts+Donation+capped-Email, 2k/25k/500/2seats · PLAN_50K: +Event/Volunteer/Membership +full Email, 500k/5M/15seats · PLAN_100K: +Case/Grant +WhatsApp/SMS, 1M/10M/50seats · CUSTOM: all features on, unlimited/override). Upsert on `PlanCode` and `(PlanId,MeterCode)`/`(PlanId,FeatureCode)` so re-running is a no-op. Emit `MODULE:*` + `CHANNEL:*` entitlement rows and `CONTACTS/DONATIONS/EMAILS/USERS` quota rows.
2. **`billing-backfill-subscriptions.sql`** — every existing `app.Companies` row with **no active Subscription** gets a default internal **`CUSTOM`** subscription (`Status='Active'`, unlimited via CUSTOM plan), so nothing breaks when guards later go live. Guard with `WHERE NOT EXISTS (active sub for that CompanyId)`. Include the `__TEMPLATE__` company.

## Out of scope for P-02 (do NOT build)
- Enforcement pipeline behaviors, `[RequiresFeature]`/`[MeteredResource]` attributes, quota `COUNT(*)` logic, FLOW counter rollover (all later).
- `myEntitlements` GraphQL, any FE, SUPERADMIN Plan Catalog / Subscription screens.
- `ProvisionTenantCommand` and its step 2 (Subscription create) / step 4 (capability intersection) — that's P-03.
- `ops.CommercialTerm` (P-05) — hence `Subscription.CommercialTermId` gets no FK yet.

## Definition of done
1. Solution **builds clean** (`dotnet build`) — real exit 0, not "only a pre-existing error remained".
2. `billing` surface follows the partial-class pattern: `IBillingDbContext` + `public partial class ApplicationDbContext : IBillingDbContext`, added to `IApplicationDbContext`; six `IEntityTypeConfiguration<T>` classes in `Configurations/BillingConfigurations/`; **no new DbContext subclass, no context DI change.**
3. `IEntitlementService` registered scoped; resolves override-then-plan; caches with `Invalidate`; fail-closed on no active subscription.
4. **Migration spec** (markdown): every table/column/type/nullability/default/index, the filtered-unique Subscription index SQL, the SubscriptionOverride CHECK, and the FKs — explicitly list which columns get **no FK yet** (`CommercialTermId`) and why.
5. Two **seed scripts** under `sql-scripts-dyanmic/`, idempotent, matching the DECIDED matrix.
6. Short **hand-back note:** what you built, the real `auth.Modules` codes you verified, how you mapped the string enums, and any deviation from this brief.

## Report back to the PM session
State: build clean (Y/N), migration spec delivered (Y/N), the two seed script paths, module codes verified (Y/N + any mismatch), and any deviations. **Do not start P-03.**
