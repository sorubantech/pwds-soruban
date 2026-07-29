# P-02b Hand-back — Multi-currency plan pricing (billing amendment)

> **Currency is modelled as an `int CurrencyId` FK → `com."Currencies"`** (with a `virtual Currency? Currency`
> nav), matching the platform-wide convention (every money-bearing entity — e.g. `grant.GrantFundReceipt` —
> carries `int CurrencyId` + nav, never a string ISO code). This applies to **all three** billing currency
> columns: `Plan.CurrencyId` (a P-02 column, converted), `PlanPrice.CurrencyId` (P-02b), and
> `Subscription.CurrencyId` (P-02b). The snapshot rule is untouched: it governs the price/rate **VALUE**
> (`Subscription.Amount`), never currency identity — same as `GrantFundReceipt` (CurrencyId FK + ExchangeRate value).

## What I built (schema + 1 entity + EF config + 1 service + 1 seed + migration-spec amendment)

**New `billing` entity**
- `Base.Domain/Models/BillingModels/PlanPrice.cs` — `[Table("PlanPrices", Schema="billing")]`, inherits
  `Entity`, int identity. Curated price book: one row per (Plan, CurrencyId, BillingCycle). `CurrencyId`
  int FK → `com.Currencies` + `virtual Currency? Currency` nav; `Amount` decimal(18,2); `BillingCycle`;
  nav `Plan?`. `IsActive`/`IsDeleted` reuse the Entity base (not re-declared). XML-doc documents the
  **two-level model** (Plan base/anchor price = FX source; PlanPrice = curated override layer).

**Entity edits**
- `Plan.cs` — added `public virtual ICollection<PlanPrice> Prices` nav; **converted `Currency string`
  → `CurrencyId int` FK + `Currency` nav** (base Price/CurrencyId/BillingCycle **kept**, as the anchor
  list price + FX-fallback source).

**Subscription snapshot (4 additive nullable columns)**
- `Subscription.cs` — `CurrencyId int?` FK + `Currency` nav, `Amount decimal?`, `BillingCycle string?`,
  `PaymentGatewayCode string?` (plain string, NO FK — gateway config deferred). Nullable so
  P-02-backfilled rows stay valid. These are the sold-at snapshot; the VALUE (`Amount`) is never rewritten.

**EF configs**
- `BillingConfigurations/PlanPriceConfiguration.cs` (new) — identity PK, lengths, `Amount`
  `HasPrecision(18,2)`, FK→Plans **CASCADE**, FK→com."Currencies" **RESTRICT**, UNIQUE
  `(PlanId, CurrencyId, BillingCycle)`. Auto-discovered by `ApplyConfigurationsFromAssembly`.
- `PlanConfiguration.cs` — dropped the `Currency` string property config; added FK→com."Currencies" **RESTRICT**.
- `SubscriptionConfiguration.cs` — the 4 snapshot columns + FK→com."Currencies" **RESTRICT** on `CurrencyId`.

**Context facet (partial-class pattern — NO new DbContext, NO DI-for-context change)**
- `IBillingDbContext.cs` — added `DbSet<PlanPrice> PlanPrices` (before the marker).
- `BillingDbContext.cs` — exposed `PlanPrices => Set<PlanPrice>()`.

**Service (`IPlanPricingService`)**
- `Base.Application/Interfaces/IPlanPricingService.cs` — `ResolveAsync(string planCode, int currencyId,
  string billingCycle, …)` (keyed on **`int currencyId`**, matching the FK model) + immutable
  `PriceResolution(decimal Amount, int CurrencyId, string CurrencyCode, string BillingCycle, string Source)`
  record. Carries **both** `CurrencyId` (to stamp `Subscription.CurrencyId`) and `CurrencyCode`
  (display / logging). Source = BOOK | FX | FREE.
- `Base.Infrastructure/Services/Billing/PlanPricingService.cs` — resolution order:
  **FREE (zero-price) → curated BOOK → FX fallback → null (unsellable, fail-closed)**. Reads catalog
  with `IgnoreQueryFilters()` + explicit `IsDeleted != true` guard (same pattern as `EntitlementService`).
  Resolves the requested + plan-base `CurrencyId`s to their ISO `CurrencyCode`s in **one**
  `com.Currencies` read (BOOK keys on `CurrencyId`; FX needs the ISO strings).
- Registered `AddScoped<IPlanPricingService, PlanPricingService>()` in `DependencyInjection.cs`, next
  to `IEntitlementService`. Did **not** touch `IEntitlementService` (pricing ≠ entitlement).

**Seed**
- `sql-scripts-dyanmic/billing-plan-prices-seed.sql` — idempotent `INSERT … WHERE NOT EXISTS` on
  `(PlanId, Currency, BillingCycle)`. Curated book for the paid plans (`PLAN_50K`, `PLAN_100K`) across
  INR/USD/EUR/GBP/AUD/SGD/AED/CAD in **both** cycles (32 rows). Illustrative amounts. **Run AFTER**
  `billing-plan-catalog-seed.sql`. FREE → no rows (service special-cases zero); CUSTOM → no rows
  (priced per-deal).

**Migration-spec amendment**
- `PSS-2.0-ONBOARDING-P02B-MIGRATION-SPEC.md` — new `billing.PlanPrices` table (FK CASCADE + unique
  index), the 4 additive `Subscriptions` columns, and the `UPDATE … FROM billing.Plans` snapshot
  backfill. Header states: **fold into the P-02 migration if unrun; else standalone follow-up.**

---

## FX fallback: SHIPPED (full), not degraded

The real `IFxRateService` public API takes **ISO code strings**
(`GetRateAsync(string from, string to, DateOnly asOfDate, CancellationToken)`) and resolves ISO→Id
**internally** against `dbContext.Currencies` (`CurrencyCode` ↔ `CurrencyId`). Since the billing
entities now key currency on **`int CurrencyId`**, the pricing service does one `com.Currencies`
read to map the requested + plan-base `CurrencyId`s to their `CurrencyCode`s, then passes those ISO
codes to the FX call — a cheap, single-round-trip mapping, and the full FX-fallback path shipped. FX
honours the memory: strict direct-pair, no USD triangulation, null on a miss (fail-closed).
Same-currency resolves via the service's built-in rate 1.0.

**Currency master:** `com."Currencies"` (exposed as `dbContext.Currencies`), columns `CurrencyCode`
(ISO) ↔ `CurrencyId` (int) — the FK target for all three billing currency columns and the ISO↔Id
lookup source for the FX hop.

---

## Build clean? **NOT RUN** — per standing user policy (BE builds are user-owned)

Consistent with the P-02 hand-back ("avoid BE build, I can build that") and project memory, I did not
run the full solution build. Compile-risk review (all patterns mirror existing, compiling code):

- Config auto-discovery, global usings (`Base.Domain.Models.BillingModels` in Base.Infrastructure),
  and the partial-class facet are the same mechanisms P-02's 6 sets already use.
- `IApplicationDbContext` inherits `IBillingDbContext`, so `dbContext.Plans` / `dbContext.PlanPrices`
  are visible to the new service.
- `PlanPricingService` explicit usings: `Base.Application.Data.Persistence`, `Base.Application.Interfaces`,
  `Microsoft.EntityFrameworkCore`. DI file already `using`s both `Base.Application.Interfaces` and
  `Base.Infrastructure.Services.Billing`.
- `pp.IsActive == true` / `IsDeleted != true` on `bool?` return `bool` (same idiom as `EntitlementService`).

No obvious compile risk. **Please run `dotnet build` to confirm exit 0 before merging** (DoD #1).

---

## Deviations from the brief

- **Currency modelled as an `int CurrencyId` FK, not a string ISO code** — deliberate, at the user's
  direction, to match the platform-wide money-entity convention (`grant.GrantFundReceipt` et al). This
  spans all three columns (`Plan`, `PlanPrice`, `Subscription`) and converts one **P-02** column
  (`Plans."Currency" varchar` → `Plans."CurrencyId" int`) — see migration-spec §0.
- The FX fallback shipped **fully** (not the curated-only degrade the brief hedged for): `IFxRateService`
  is ISO-string-keyed at its API, so the service maps `CurrencyId → CurrencyCode` in one read and calls it.
- Seed amounts are illustrative round marketing numbers (noted in-file); edited later via the Plan
  Catalog screen.

## Constraints honored
- No `dotnet ef migrations add/update/remove`; no hand-authored migration/snapshot file.
- No SQL executed against any DB (seed written only, user-applied).
- All keys int identity; no Guid. Snapshot rule obeyed (price **VALUE** on `Subscription.Amount`;
  currency **identity** is an FK, exactly as `GrantFundReceipt` does).
- `IEntitlementService` untouched. No GraphQL / UI / usage / gateway-config / provisioning wiring.
- **Did NOT start P-03.**

---

## Report to PM
- **Build clean:** NOT RUN (user owns BE build) — compile-risk review clean; please build to confirm.
- **Currency = FK across all 3 billing columns:** Y (`Plan.CurrencyId`, `PlanPrice.CurrencyId`,
  `Subscription.CurrencyId` → `com."Currencies"`, RESTRICT). Converts one P-02 column (`Plans.Currency`).
- **PlanPrice + unique index:** Y (`(PlanId, CurrencyId, BillingCycle)` UNIQUE, FK→Plans CASCADE + FK→Currencies RESTRICT).
- **Subscription snapshot columns:** Y (CurrencyId FK, Amount, BillingCycle, PaymentGatewayCode — all nullable).
- **IPlanPricingService with FX fallback:** **SHIPPED (full FX)** — FREE → BOOK → FX(direct-pair) → null; keyed on `int currencyId`.
- **Seed path:** `sql-scripts-dyanmic/billing-plan-prices-seed.sql` (after catalog seed; needs `com."Currencies"` seeded).
- **Migration-spec amendment:** `PSS-2.0-ONBOARDING-P02B-MIGRATION-SPEC.md` (fold into P-02 migration; note §0 changes a P-02 column).
- **Do NOT proceed to P-03.**
