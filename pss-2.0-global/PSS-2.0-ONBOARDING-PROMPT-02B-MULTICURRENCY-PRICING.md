# DEV PROMPT P-02b — Multi-currency plan pricing (billing amendment)

> Paste everything below the line into a **fresh development session**. It is self-contained.
> When done, report back to the PM session; do **not** proceed to P-03.
>
> **Why this exists:** P-02 modelled a plan with a **single** `Price` + single `Currency` (INR). The product is global with multiple payment gateways, so a tenant must be able to subscribe **in their own currency**. This amendment adds a per-currency **price book** + a **price-resolution service** (curated price → FX fallback), and gives `Subscription` the **currency/amount snapshot** it currently lacks. It folds into the **same not-yet-applied P-02 billing migration** — you produce a migration *amendment*, not a second migration.

---

## Role & mission

You are a Senior Backend Developer on the PSS 2.0 multi-tenant .NET platform (**target framework `net10.0`**). Your task is **P-02b**: extend the billing layer built in P-02 so a plan can be priced in **any currency** and each subscription **snapshots** the currency + amount it was sold at.

This is **schema + one new entity + EF config + one service + one seed + a migration-spec amendment only.** No enforcement changes, no GraphQL, no UI, no usage logic. Do **not** touch `IEntitlementService` (pricing is not entitlement).

The billing layer from P-02 already exists and compiles: `billing.Plan / PlanEntitlement / PlanQuota / Subscription / SubscriptionOverride / UsageCounter`, the `IBillingDbContext` partial-class facet, `IEntitlementService`, `BillingCodes`, and two seeds. **Assume they are present** — you are adding on top.

## Read first (grounding — do not skip)

1. `PSS-2.0-ONBOARDING-P02-HANDBACK.md` — how the billing layer was actually built (folder layout, the partial-class facet, the config conventions: `UseIdentityAlwaysColumn`, `HasPrecision(18,2)`, the filtered-unique subscription index).
2. `PSS-2.0-ONBOARDING-PROMPT-02-BILLING-ENTITLEMENTS.md` — the P-02 prompt, for the same context.
3. The real entities before you touch them — **verify property names against these files**, do not trust this brief blindly:
   - `Base.Domain/Models/BillingModels/Plan.cs` — `PlanId int`, `PlanCode` (`[CaseFormat("upper")]`), `PlanName`, `Description?`, **`Price decimal`**, **`Currency string`** (ISO, seeded INR — **you convert this to a `CurrencyId int` FK, see §1b**), **`BillingCycle string`** (Monthly|Annual — **stays a string**), `IsCustom bool`, `SortOrder int`; children `Entitlements`, `Quotas`, `Subscriptions`.
   - `Base.Domain/Models/BillingModels/Subscription.cs` — `SubscriptionId, CompanyId, PlanId, CommercialTermId? (no FK), Status, StartDate, CurrentPeriodStart, CurrentPeriodEnd, TrialEndsOn?, CancelledOn?`; navs `Company?`, `Plan?`, `Overrides`. **Carries NO currency/amount today — that is the gap you close.**
   - `Base.Infrastructure/Data/Configurations/BillingConfigurations/PlanConfiguration.cs` and `SubscriptionConfiguration.cs` — match their style exactly for the new config + the added columns.
   - **`Base.Domain/Models/SharedModels/Currency.cs` — the real currency master (`[Table("Currencies", Schema = "com")]`).** Columns: `CurrencyId int` PK, `CurrencyCode string` (`[CaseFormat("upper")]`, the ISO code e.g. `INR`/`USD`), `CurrencyName`, `CurrencySymbol`, `DecimalPlaces int`. This is the FK target for **all catalog-side currency** (Plan + PlanPrice). Match on `CurrencyCode` in seeds.
4. **The FX service you will reuse** — `IFxRateService` (registered in `Base.Infrastructure/DependencyInjection.cs`, next to where `IEntitlementService` was added). **Read its real signature before wiring** — per project memory it is **direct-pair only, no triangulation**, keyed on **`(FromCurrencyId, ToCurrencyId)` (int currency IDs, NOT ISO strings)**, and `GetRateAsync` **returns null on a miss** (fail-closed). **Because the catalog now stores `CurrencyId` directly (§1/§1b), the FX from/to are already int IDs — no ISO→Id resolution needed on the catalog side.** The only value to map is the *requested* currency if the caller passes it as an ISO string; the service contract below takes `int currencyId` to avoid even that.

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add`, `database update`, or `remove`, and do **NOT** hand-author a migration or model-snapshot file. Build the solution to prove it compiles, then produce a **migration-spec amendment** (markdown) that the user merges into the single, still-unapplied P-02 billing migration.
- 🌱 **Seed files:** you write them (idempotent `INSERT … WHERE NOT EXISTS`, matching `sql-scripts-dyanmic/*.sql` style); the **user applies** them. Do not execute SQL against any DB.
- **All PKs/FKs are `int` identity** (`UseIdentityAlwaysColumn().ValueGeneratedOnAdd()`). No Guid keys.
- **UTC only.** Every date column is `timestamp with time zone`; write `DateTime.UtcNow`, build boundaries with `DateTimeKind.Utc`. (This amendment adds no date columns, but the snapshot service still obeys it.)
- **Snapshot rule (project memory — non-negotiable).** A subscription stores the **resolved amount + currency VALUE**, never an FK to a mutable `PlanPrice` or FX rate row. Editing the price book later must **never** rewrite an existing subscription's price.
- **Verify every property name before use.** Read the entity first.
- **No BE build is required of you if the user opted out** — but write to the established patterns so it compiles.

## Scope — build exactly this

### 1 · New entity `billing.PlanPrice` (the price book)

Create `Base.Domain/Models/BillingModels/PlanPrice.cs`, `[Table("PlanPrices", Schema = "billing")]`, inherits `Entity`, all `int` identity — one row per **(Plan, Currency, BillingCycle)** sellable combination:

| Property | Type | Notes |
|---|---|---|
| `PlanPriceId` | `int` | PK, identity |
| `PlanId` | `int` | FK → `billing.Plans`, **CASCADE** (deleting a plan removes its price rows) |
| `CurrencyId` | `int` | **FK → `com.Currencies` (CurrencyId), `DeleteBehavior.Restrict`** — a currency in use must not be deletable. **NOT an ISO string.** |
| `Amount` | `decimal` | `HasPrecision(18,2)`, the hand-set marketing price in that currency |
| `BillingCycle` | `string` | `Monthly | Annual`, `HasMaxLength(20).IsRequired()` |
| nav `Plan` | `Plan?` | back-reference |
| nav `Currency` | `Currency?` | FK nav → `com.Currencies` (`Base.Domain.Models.SharedModels`) |

- `IsActive` comes from the `Entity` base — a price row can be deactivated without deleting (reuse it, do **not** re-declare it; P-02's `Plan` did the same).
- **UNIQUE index `(PlanId, CurrencyId, BillingCycle)`** — at most one active price per combo.
- Add `public virtual ICollection<PlanPrice> Prices { get; set; } = new List<PlanPrice>();` to `Plan.cs`, and wire the `HasMany(p => p.Prices)…HasForeignKey(pp => pp.PlanId).OnDelete(Cascade)` in a new `PlanPriceConfiguration : IEntityTypeConfiguration<PlanPrice>` under `BillingConfigurations/` (auto-discovered by `ApplyConfigurationsFromAssembly`). Also configure the `Currency` FK (`HasOne(pp => pp.Currency).WithMany().HasForeignKey(pp => pp.CurrencyId).OnDelete(Restrict)`). Add a matching back-nav `ICollection<PlanPrice>? PlanPrices` to `Currency.cs` **only if** you prefer an explicit inverse — `WithMany()` (no inverse nav) is acceptable and lighter; state which you chose.
- Register the DbSet on the **billing facet**: add `DbSet<PlanPrice> PlanPrices { get; }` to `IBillingDbContext` (at the `//IBillingDbContextLines` marker) and expose it via `Set<PlanPrice>()` in `BillingDbContext`. **No new DbContext, no DI change** — same pattern P-02 used for its 6 sets.

**Keep `Plan.Price` / `Plan.BillingCycle` — do NOT drop them.** They remain the plan's **base / anchor** list price and cycle, and `Plan`'s base currency (now `Plan.CurrencyId`, §1b) is the **source the FX fallback converts from**. `PlanPrice` is the curated per-currency override book layered on top. Document this two-level model in the entity XML-doc.

### 1b · Convert `Plan.Currency` (string) → `Plan.CurrencyId` (FK) — P-02 amendment

The catalog decision is: **all catalog-side currency is an FK to `com.Currencies`, not an ISO string.** `Plan.Currency` was built in P-02 as an ISO string; since the **P-02 billing migration is not yet applied**, change it in place (no data migration needed):

- In `Plan.cs`: **replace** `public string Currency { get; set; }` with `public int CurrencyId { get; set; }` + nav `public Currency? Currency { get; set; }` (`Base.Domain.Models.SharedModels`).
- In `PlanConfiguration.cs`: drop the old `Currency` string config; add `HasOne(p => p.Currency).WithMany().HasForeignKey(p => p.CurrencyId).OnDelete(Restrict)`.
- **`billing-plan-catalog-seed.sql` (a P-02 seed) must be updated too:** its plan rows currently set `Currency = 'INR'`; change to set `CurrencyId = (SELECT "CurrencyId" FROM com."Currencies" WHERE "CurrencyCode" = 'INR')`. Call this out in the migration-spec amendment and edit the seed if it is in the repo (`sql-scripts-dyanmic/billing-plan-catalog-seed.sql`) — if the user has already applied it, note that the plan rows need a one-line `UPDATE` to backfill `CurrencyId` from `Currency` before the column is dropped.
- **`Subscription.Currency` is the exception — it stays an ISO string (§2), because it is a snapshot VALUE, not a catalog FK.**

### 2 · `Subscription` currency/amount snapshot (additive columns)

Add to `Subscription.cs` + `SubscriptionConfiguration.cs` — **all nullable/additive** so the existing (P-02-backfilled) subscription rows stay valid:

| Property | Type | Config | Meaning |
|---|---|---|---|
| `Currency` | `string?` | `HasMaxLength(10)` | ISO code the tenant subscribed in (snapshot) |
| `Amount` | `decimal?` | `HasPrecision(18,2)` | Price charged at subscription time (snapshot) |
| `BillingCycle` | `string?` | `HasMaxLength(20)` | Monthly/Annual at subscription time (snapshot) |
| `PaymentGatewayCode` | `string?` | `HasMaxLength(30)` | e.g. `RAZORPAY`/`STRIPE` — **plain string, NO FK** (gateway config is deferred; we only capture the routing choice) |

- These are the **snapshot**: once written, a later price-book edit must not touch them.
- **Backfill (in the migration-spec amendment, not code):** for existing subscription rows, set `Currency = COALESCE(Plan.Currency,'INR')`, `BillingCycle = COALESCE(Plan.BillingCycle,'Monthly')`, `Amount = Plan.Price`, `PaymentGatewayCode = NULL` (unknown for legacy/CUSTOM-backfill rows) — so history is at least coherent. State this as an `UPDATE … FROM billing.Plans` step.

### 3 · `IPlanPricingService` (curated price → FX fallback → fail closed)

Create the interface + impl mirroring where `IEntitlementService` lives (`Base.Application/Interfaces/` + `Base.Infrastructure/Services/Billing/`), and register `AddScoped<IPlanPricingService, PlanPricingService>()` next to the entitlement registration.

**Contract** — resolve the sellable price for `(planCode | planId, currencyId, billingCycle)`. The catalog is now `CurrencyId`-keyed (§1/§1b), so the request currency is an **int `CurrencyId`**, and the FX call needs no ISO→Id lookup:

```
record PriceResolution(decimal Amount, int CurrencyId, string CurrencyCode, string BillingCycle, string Source);
// Source = "BOOK" (curated PlanPrice hit) | "FX" (converted from base) | "FREE" (zero-price plan)
// CurrencyCode = the ISO string resolved from com.Currencies — this is what P-03 SNAPSHOTS onto Subscription.Currency.

Task<PriceResolution?> ResolveAsync(string planCode, int currencyId, string billingCycle, CancellationToken ct);
```

The service resolves `CurrencyId → CurrencyCode` once (single `com.Currencies` lookup) so the caller can snapshot the ISO string without re-querying. Accept `currencyId` as the input, not an ISO string — the caller (P-03) already holds the tenant's `CurrencyId`.

Resolution order (fail-closed at the end):
1. **FREE / zero-price plan** → return `Amount = 0` for the requested `CurrencyId`, `Source="FREE"` (a free plan is sellable in every currency).
2. **Curated hit** → if a `PlanPrice` exists for `(PlanId, CurrencyId, BillingCycle)` (active, not soft-deleted), return it, `Source="BOOK"`.
3. **FX fallback** → else convert `Plan.Price` from **`Plan.CurrencyId` → requested `currencyId`** via `IFxRateService` — **both are already int IDs, pass them straight in** (`GetRateAsync(fromCurrencyId, toCurrencyId, …)`). If a **direct-pair rate exists**, return the converted amount (round to 2 dp), `Source="FX"`. Honour the FX memory: **direct-pair only, no USD triangulation.**
4. **Miss** → `IFxRateService` returns null (no rate) **and** no curated row ⇒ return **`null`** = *this currency is not sellable for this plan*. The caller (P-03 provisioning) treats null as a hard validation failure. Never invent a rate, never fall back to the base currency silently.

- Read `Plan` / `PlanPrice` with **`IgnoreQueryFilters()` + explicit `IsDeleted != true` guard** — they are SUPERADMIN catalog rows with no `CompanyId`, but keep the pattern consistent with `EntitlementService` (P-02 hand-back §2) so it is correct in provisioning/background contexts.
- **The ISO→Id resolution that used to be a risk is now gone** — the catalog stores `CurrencyId` and the FX service is int-keyed, so steps 1–3 are all int-native. The only lookup is `CurrencyId → CurrencyCode` for the snapshot string, which is a trivial `com.Currencies` read. No `// TODO` degrade path is needed; the FX fallback ships.

### 4 · Seed `billing-plan-prices-seed.sql` (curated price book)

Idempotent `INSERT … WHERE NOT EXISTS`, under `sql-scripts-dyanmic/`, **run after** `billing-plan-catalog-seed.sql` (needs the plans to exist). Seed the curated book for the **paid** plans (`PLAN_50K`, `PLAN_100K`) across a starter set of currencies in **both** cycles:

- Currencies (illustrative, editable — like P-02's placeholder prices): **INR (base), USD, EUR, GBP, AUD, SGD, AED, CAD.**
- **`PlanPrices.CurrencyId` is a FK**, so the seed resolves each ISO code to its id with a subquery: `(SELECT "CurrencyId" FROM com."Currencies" WHERE "CurrencyCode" = 'USD')`. Guard the insert so a currency missing from `com.Currencies` is skipped, not inserted as NULL (either `WHERE (SELECT CurrencyId …) IS NOT NULL` or an `INNER JOIN` on the subquery). Note in a comment that the target tenant must have these currencies seeded first.
- `FREE` → no price rows needed (the service special-cases zero); optionally seed `Amount=0` rows for UI completeness — your call, note it.
- `CUSTOM` → priced per-deal, **no book rows** (state this).
- Match by `(PlanId via PlanCode, CurrencyId via CurrencyCode, BillingCycle)` in the `WHERE NOT EXISTS`. Amounts are illustrative — put a comment saying so and that they're edited via the Plan Catalog screen later.

### 5 · Migration-spec amendment

Produce `PSS-2.0-ONBOARDING-P02B-MIGRATION-SPEC.md` describing, for the user to **merge into the single unapplied P-02 billing migration**:
- **`billing.Plans` column change (§1b):** `Currency string` → `CurrencyId int NOT NULL`, FK→`com.Currencies` (Restrict). Because the P-02 migration is unapplied, this replaces the column in-place; if P-02 is already applied, spell out the two-step (add `CurrencyId`, backfill `UPDATE billing.Plans SET CurrencyId = c.CurrencyId FROM com.Currencies c WHERE c.CurrencyCode = Plans.Currency`, then drop `Currency`).
- new table `billing.PlanPrices` (columns/types/nullability, FK→Plans CASCADE, **FK `CurrencyId`→`com.Currencies` Restrict**, the `(PlanId,CurrencyId,BillingCycle)` UNIQUE index);
- the 4 additive nullable columns on `billing.Subscriptions` (`Currency` **stays an ISO string snapshot — NOT a CurrencyId FK**, `Amount`, `BillingCycle`, `PaymentGatewayCode`);
- the backfill `UPDATE billing.Subscriptions … FROM billing.Plans` for the snapshot columns — since `Plan.Currency` is now `Plan.CurrencyId`, resolve the ISO for the snapshot via a join to `com.Currencies` (`SET Currency = c.CurrencyCode FROM billing.Plans p JOIN com.Currencies c ON c.CurrencyId = p.CurrencyId …`).
State explicitly at the top: **"Fold into the P-02 billing migration if it has not been run; if P-02's migration is already applied, this is a standalone follow-up migration."**

## Out of scope for P-02b (do NOT build)

- Payment-gateway config entity / credentials / webhooks / currency→gateway routing — **deferred** (we only capture `Subscription.PaymentGatewayCode` as a string).
- Any change to `IEntitlementService` / entitlement resolution — pricing ≠ entitlement.
- Provisioning wiring (P-03 step 2 will *call* `IPlanPricingService` and write the snapshot — not your job here).
- GraphQL, UI, the Plan Catalog admin screen, usage/billing runs, invoices.

## Definition of done

1. Solution **builds clean** (real `dotnet build` exit 0 — not "only a pre-existing error remained").
2. `billing.PlanPrice` entity (`CurrencyId` FK, not ISO string) + `PlanPriceConfiguration` + `Plan.Prices` nav + DbSet on the billing facet, `(PlanId,CurrencyId,BillingCycle)` unique.
2b. **`Plan.Currency` (string) converted to `Plan.CurrencyId` FK** → `com.Currencies`; `PlanConfiguration` updated; `billing-plan-catalog-seed.sql` resolves `CurrencyCode`→`CurrencyId`.
3. `Subscription` has the 4 additive nullable snapshot columns, config'd (`HasPrecision(18,2)` on `Amount`, lengths on the strings) — `Subscription.Currency` stays an **ISO string snapshot value**.
4. `IPlanPricingService` resolves FREE → curated BOOK → FX fallback → null(unsellable), taking `int currencyId`, returning `CurrencyId + CurrencyCode`, FX honouring direct-pair-only with int IDs passed straight through, reading catalog with `IgnoreQueryFilters()` + `IsDeleted` guard; DI-registered.
5. `billing-plan-prices-seed.sql` idempotent, `CurrencyId` resolved from `CurrencyCode`, curated currencies for the paid plans, runs after the catalog seed.
6. `PSS-2.0-ONBOARDING-P02B-MIGRATION-SPEC.md` — `Plan.CurrencyId` change + PlanPrices table + Subscription columns + backfill, marked "fold into the P-02 migration."
7. Short **hand-back note**: build clean (Y/N); confirm `Plan.CurrencyId` + `PlanPrice.CurrencyId` are FKs to `com.Currencies` and `Subscription.Currency` stayed an ISO snapshot; whether the FX fallback shipped; every property/table name that differed from this brief.

## Report back to the PM session

State: build clean (Y/N); `Plan.CurrencyId` + `PlanPrice.CurrencyId` FKs (Y/N); `(PlanId,CurrencyId,BillingCycle)` unique index (Y/N); Subscription snapshot columns with `Currency` as ISO value (Y/N); `IPlanPricingService` with int-keyed FX fallback (Y/N); seed path; migration-spec-amendment path; and any deviations. **Do not start P-03.**
