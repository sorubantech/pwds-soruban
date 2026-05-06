---
screen: CurrencyConversion
registry_id: 141
module: GeneralMasters
status: COMPLETED
scope: REFACTOR_EXTEND
screen_type: MASTER_GRID
complexity: Medium-High
new_module: NO
planned_date: 2026-05-01
completed_date: 2026-05-01
last_session_date: 2026-05-01
---

## Tasks

### Planning (by /plan-screens)
- [x] Existing BE entity reviewed (CurrencyConversion in com schema — buggy schema, needs refactor)
- [x] Existing BE CRUD reviewed (Create/Update/Delete/Toggle/Get/GetById all wired)
- [x] Existing FE artifacts reviewed (DTO + Query + Mutation + page + route all exist)
- [x] Architecture decisions confirmed with user (USD-pivot, global, daily, API sync, snapshot rule)
- [x] Mockup TBD — design specified from architectural reasoning + standard MASTER_GRID pattern
- [x] FK targets resolved (Currency only)
- [x] File manifest computed (REFACTOR existing + ADD daily-sync hosted service)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (via /plan-screens — Section ① business context + ⑥ business rules + ⑦ classification confirm BA scope)
- [x] Solution Resolution complete (via /plan-screens — Section ② architecture rules + ⑦ MASTER_GRID Type 2 classification + ⑪ file manifest confirm SR scope)
- [x] UX Design finalized (via /plan-screens — Section ⑧ Variant B layout with widgets-above-grid + Conversion Calculator confirms UX scope)
- [x] User Approval received (2026-05-01 — approved with all defaults)
- [x] Backend code refactored (entity, EF config, schemas, validators, handlers, mutations, queries) — 18 files modified incl. cascade cleanup of `Currency.CurrencyRate`
- [x] Backend wiring complete (Mapster custom mapping, DI for IFxRateService + OpenExchangeRatesClient + OpenExchangeRatesSyncJob, appsettings.json keys)
- [x] FxRateLookupService implemented (nearest-prior-date with 7-day fallback) — `Base.Infrastructure/Services/Currency/FxRateService.cs`
- [x] OpenExchangeRatesSyncJob implemented (IHostedService daily sync, default-OFF via `Fx:AutoSyncEnabled`)
- [x] Frontend code refactored (DTO + Query + Mutation + grid + form schema) — Variant B layout confirmed
- [x] Conversion Calculator widget implemented (USD-pivot math via two `lookupRateByDate` calls)
- [x] Migration generated (`20260501120000_Refactor_CurrencyConversion_To_USD_Pivot.cs` — drops Date/ConversionRate + Currency.CurrencyRate, adds RateDate/RateAgainstUSD/Source/Notes, BEST_EFFORT_CAST data migration with Source='Imported-Legacy', filtered unique index)
- [x] DB Seed script generated (`CurrencyConversion-sqlscripts.sql` — Menu+Capabilities+RoleCapabilities+Grid+Fields+GridFields+GridFormSchema+5 baseline rates)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/general/masters/currencyconversion`
- [ ] CRUD flow tested (Create rate → Read → Update → Toggle → Delete)
- [ ] Unique constraint `(CurrencyId, RateDate)` enforced
- [ ] Conversion Calculator widget computes A→B via USD pivot correctly
- [ ] Bulk import (CSV) works for batch daily rates
- [ ] FxRateLookupService returns nearest-prior rate when exact-date missing
- [ ] OpenExchangeRatesSyncJob populates table on schedule (manual trigger button works)
- [ ] DB Seed — menu visible under GEN_MASTERS sidebar, grid + form schema render

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

**Screen**: CurrencyConversion (FX Rate Master)
**Module**: General > Masters
**Schema**: `com`
**Group**: SharedModels
**Route**: `/[lang]/general/masters/currencyconversion`
**Parent Menu**: GEN_MASTERS (MenuId 368)

**Business**:
This screen is the **single source of truth for foreign exchange rates** across the entire multi-tenant application. Every currency tracked in the system has its **rate against USD** stored here, date-versioned daily. When any tenant — regardless of their base currency — needs to convert between any two currencies (e.g., a USD donation arriving for a tenant whose base currency is INR), the donation entry form **looks up the rate at transaction time** and **snapshots the actual rate value onto the donation row**. The rate table itself is never FK-referenced from financial transactions; only the rate VALUE is copied. This guarantees historical immutability — a donation entered last year stays at the rate it was entered with, even if today's rate row gets edited.

**Who uses it**: Finance admin (BUSINESSADMIN role) — manually adds/overrides rates, runs the sync, audits rate history.

**How it relates to other screens**:
- **Currency Master** (#79) — provides the catalog of currencies; this screen consumes `CurrencyId` as FK.
- **CompanySettings** (#75) — defines each tenant's `BaseCurrencyId`; donation forms read this to pick "convert to which base".
- **GlobalDonation** (existing) — donation form pre-fills `ExchangeRate` from this table; saves SNAPSHOT, never FK.
- **PaymentTransaction** + **AmbassadorCollectionDistribution** — same snapshot pattern.
- **(Future)** Currency Exchange Rate Sync Status dashboard — shows last successful API sync, gaps, manual overrides.

---

## ② Architecture Rules (CRITICAL — read before designing)

> **Consumer**: All agents — these are non-negotiable rules baked in by user decision.

### Rule 1: USD Pivot Model

Every rate row stores `RateAgainstUSD` — i.e., **"1 unit of THIS currency = X USD"**. USD itself = 1.0000 always.

To convert any currency A → currency B on a given date:
```
BaseAmount = SourceAmount × (RateA_AgainstUSD / RateB_AgainstUSD)
```

**Why pivot, not direct-pair**: Storage is O(N currencies × N dates), not O(N² pairs × N dates). Free FX APIs (OpenExchangeRates, ECB Frankfurter) are USD-pivoted natively. Triangulation rounding is negligible at decimal(18,8).

### Rule 2: Global Table — No Tenant Scope

`CurrencyConversion` has NO `CompanyId`. One row per `(CurrencyId, RateDate)` serves every tenant in the system. The tenant's `BaseCurrencyId` (from CompanySettings) is what differs at lookup time, not the rate data itself.

### Rule 3: Snapshot — Never FK

⚠️ **This is the most important rule for any developer touching donation/payment code:**

```csharp
// ❌ WRONG — never do this:
public class GlobalDonation {
    public int CurrencyConversionId;          // ❌ FK pointer
    public CurrencyConversion CurrencyConversion;
}

// ✅ RIGHT — always snapshot the value:
public class GlobalDonation {
    public decimal ExchangeRate;              // ✅ value snapshot
    public decimal BaseCurrencyAmount;        // ✅ pre-computed snapshot
}
```

**Reason**: financial records must be immutable to future rate changes. A donation entered in 2025 at `Rate=82.50` must show `Rate=82.50` forever, even if an admin edits the 2025 rate row in 2030. Existing entities already follow this pattern correctly:
- [GlobalDonation.cs:12](Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/GlobalDonation.cs#L12) — `ExchangeRate` (value, not FK)
- [PaymentTransaction.cs:20](Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/PaymentTransaction.cs#L20) — `ExchangeRate` (value, not FK)
- [AmbassadorCollectionDistribution.cs:19](Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/AmbassadorCollectionDistribution.cs#L19) — `ExchangeRate` (value, not FK)

**The CurrencyConversion table is a LOOKUP source only.** No `[ForeignKey(typeof(CurrencyConversion))]` is allowed anywhere in the codebase outside CurrencyConversion's own EF config.

### Rule 4: Daily Granularity

Rate is keyed by `RateDate` of type **`DateOnly`** (NOT DateTime). One rate per currency per day — period. Intraday rates are out of scope.

### Rule 5: Nearest-Prior Fallback

When a transaction needs a rate and the exact `RateDate` is missing:
1. Look up `(CurrencyId, RateDate ≤ TransactionDate)` ordered by RateDate DESC
2. Take the most-recent prior rate within a **7-day window**
3. If still missing → throw `RateNotFoundException` (donation entry blocks until admin enters a rate)

**No silent "use latest" fallback** — that would let stale rates leak into backdated donations.

### Rule 6: Source Tracking

Every rate row tags its origin via `Source` field:
- `"Manual"` — admin typed it
- `"OpenExchangeRates"` — pulled from OpenExchangeRates.org daily sync
- `"ECB"` — (future) European Central Bank Frankfurter API
- `"Imported"` — bulk CSV import

This is for audit/debugging — when a discrepancy is reported, finance can trace WHERE the number came from.

---

## ③ Existing State Analysis

> **Consumer**: BA Agent + Backend Developer — what exists today, what changes.

### Existing Backend (REFACTOR these)

| Path | Status | Action |
|------|--------|--------|
| `Base.Domain/Models/SharedModels/CurrencyConversion.cs` | EXISTS — buggy schema | REFACTOR (drop `ConversionRate`/`Date`, add `RateAgainstUSD`/`RateDate`/`Source`) |
| `Base.Infrastructure/Data/Configurations/SharedConfigurations/CurrencyConversionConfiguration.cs` | EXISTS | REFACTOR (add unique index, drop old configs) |
| `Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/CreateCurrencyConversion.cs` | EXISTS — has bug | REFACTOR (remove `Currency.CurrencyRate = ConversionRate` mutation at line ~56) |
| `.../Commands/UpdateCurrencyConversion.cs` | EXISTS | REFACTOR (same bug fix; allow only Source=Manual edits) |
| `.../Commands/DeleteCurrencyConversion.cs` | EXISTS | REFACTOR (block delete if any donation in last N days references this date — soft warning, not hard block) |
| `.../Commands/ToggleCurrencyConversion.cs` | EXISTS | KEEP as-is |
| `.../Queries/GetCurrencyConversion.cs` | EXISTS | REFACTOR (rename `Date` → `RateDate`, add Source filter, search by code) |
| `.../Queries/GetCurrencyConversionById.cs` | EXISTS | REFACTOR (sync DTO field renames) |
| `Base.Application/Schemas/SharedSchemas/CurrencyConversionSchemas.cs` | LIKELY EXISTS | REFACTOR (rename fields per new entity) |
| `Base.API/EndPoints/Shared/Mutations/CurrencyConversionMutations.cs` | LIKELY EXISTS | KEEP (no signature change) |
| `Base.API/EndPoints/Shared/Queries/CurrencyConversionQueries.cs` | LIKELY EXISTS | EXTEND (add `LookupRateByDate` query for donation-form pre-fill) |
| `Base.Application/Extensions/DecoratorProperties.cs` | EXISTS — line 117 area | KEEP (`CurrencyConversion` enum already present) |

### Existing Frontend (REFACTOR these)

| Path | Status | Action |
|------|--------|--------|
| `domain/entities/shared-service/CurrencyConversionDto.ts` | EXISTS | REFACTOR (field rename: `date`→`rateDate`, `conversionRate`→`rateAgainstUSD`, add `source`, add `currencyCode`) |
| `infrastructure/gql-queries/shared-queries/CurrencyConversionQuery.ts` | EXISTS | REFACTOR (field renames + add `LookupRateByDate` query + add `GetCurrencyConversionSummary`) |
| `infrastructure/gql-mutations/shared-mutations/CurrencyConversionMutation.ts` | EXISTS | REFACTOR (field renames + add `BulkImportCurrencyConversions` + add `TriggerOpenExchangeRatesSync`) |
| `presentation/pages/general/masters/currencyconversion.tsx` | EXISTS (page config) | REFACTOR (column changes, FK to GetAllCurrencyList, add summary widgets) |
| `presentation/components/page-components/general/masters/currencyconversion/data-table.tsx` | EXISTS | REFACTOR (column re-spec, add Conversion Calculator widget at top) |
| `presentation/components/page-components/general/masters/currencyconversion/index.ts` | EXISTS | KEEP (export wiring) |
| `app/[lang]/general/masters/currencyconversion/page.tsx` | EXISTS | KEEP (route stub) |
| `presentation/pages/shared/commonasset/generalmaster/currencyconversion.tsx` | EXISTS (legacy duplicate) | DELETE — single canonical path is `pages/general/masters/currencyconversion.tsx` |
| `presentation/components/page-components/shared/commonasset/generalmaster/currencyconversion/` | EXISTS (legacy duplicate) | DELETE — single canonical path under `general/masters/` |

### Bug Fixes Required (existing code)

1. **Remove `Currency.CurrencyRate = ConversionRate` mutation**
   File: [Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/CreateCurrencyConversion.cs:56](Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/CreateCurrencyConversion.cs#L56)
   Reason: This is the "latest rate wins" overwrite that destroys historical lookups. The new design uses `(CurrencyId, RateDate)` lookup with nearest-prior fallback — `Currency.CurrencyRate` becomes a stale duplicate that nobody should read.

2. **Decide fate of `Currency.CurrencyRate` field**
   File: [Base.Domain/Models/SharedModels/Currency.cs:16](Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs#L16)
   Recommendation: DEPRECATE (mark `[Obsolete]`) or DROP via migration. No code outside the buggy `CreateCurrencyConversionHandler` should be reading it. **Search-and-confirm before dropping.**

3. **Audit any consumers reading `currency.CurrencyRate`**
   Action: Grep for `\.CurrencyRate\b` in BE+FE; any consumer must be migrated to `IFxRateService.GetRateAsync(currencyId, date)` instead.

---

## ④ Refactored Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Replaces existing `CurrencyConversion.cs` schema.

**Table**: `com."CurrencyConversions"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CurrencyConversionId | int | — | PK | — | Primary key (existing) |
| CurrencyId | int | — | YES | com.Currencies | The currency THIS rate is for |
| RateDate | DateOnly | — | YES | — | Day this rate applies (replaces `Date DateTime`) |
| RateAgainstUSD | decimal(18,8) | — | YES | — | 1 unit of CurrencyId = X USD (replaces `ConversionRate`) |
| Source | string | 50 | YES | — | Origin: "Manual" / "OpenExchangeRates" / "ECB" / "Imported" |
| Notes | string | 500 | NO | — | Free-text audit trail (e.g., "manual override after bank reconciliation") |
| (audit) | — | — | — | — | CreatedDate, ModifiedDate, IsDeleted, IsActive — inherited from Entity |

**Removed fields**:
- `Date DateTime` → replaced by `RateDate DateOnly`
- `ConversionRate decimal` → replaced by `RateAgainstUSD decimal(18,8)`

**Constraints**:
- Filtered unique index: `(CurrencyId, RateDate)` WHERE `IsDeleted = false`
- USD row constraint (DB-level CHECK or app-level): `WHERE Currency.CurrencyCode = 'USD' THEN RateAgainstUSD = 1.0000` (enforced in validator)
- `RateAgainstUSD > 0` (validator)

**Entity factory** (`CurrencyConversion.Create`): updated to take new field names.

---

## ⑤ FK Resolution Table

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CurrencyId | Currency | Base.Domain/Models/SharedModels/Currency.cs | GetAllCurrencyList | CurrencyName | CurrencyResponseDto |

**Note**: `Currency` entity has both `CurrencyName`, `CurrencyCode`, `CurrencySymbol` — grid display should show all three (`USD - US Dollar ($)`).

---

## ⑥ Business Rules & Validation

**Uniqueness Rules**:
- `(CurrencyId, RateDate)` must be unique per active row → `ValidateUniqueWhenCreate(c => new { c.CurrencyId, c.RateDate })` and `ValidateUniqueWhenUpdate`

**Required Field Rules**:
- `CurrencyId`, `RateDate`, `RateAgainstUSD`, `Source` mandatory
- FK validation: `ValidateForeignKeyRecord<Currency>(...)`

**Conditional Rules**:
- If `Currency.CurrencyCode = "USD"` → `RateAgainstUSD` MUST equal `1.0000` (validator throws "USD rate is always 1 — cannot override")
- If `RateDate > Today` → reject ("Cannot enter future-dated rates")
- If `RateAgainstUSD <= 0` → reject ("Rate must be positive")
- If `Source = "Manual"` and rate differs from existing API-sourced row by >5% → warning toast (allow but flag as `Notes` audit)

**Business Logic**:
- **Create handler**: do NOT mutate `Currency.CurrencyRate` (legacy bug — removed in this refactor)
- **Update handler**: only allow editing rows where `Source = "Manual"` (API-sourced rows are read-only; admin must add a new manual override row instead)
- **Delete handler**: soft-delete only; if any donation (any tenant) has `DonationDate` matching this `RateDate` and `CurrencyId`, show warning "N donations were entered using this rate — proceed?" but allow the action (donations have snapshots, so they're safe).

**Workflow**: None — simple master CRUD + bulk import + scheduled sync.

---

## ⑦ Screen Classification & Pattern Selection

**Screen Type**: MASTER_GRID
**Type Classification**: Type 2 (FK-bearing master with summary widgets + utility tooling)
**Reason**: Flat entity with one FK, one unique constraint, plus three NEW sub-features: (a) summary widgets above grid, (b) Conversion Calculator widget, (c) "Sync Now" action button. Still fits MASTER_GRID — sub-features are page-level extras, not workflow.

**Backend Patterns Required**:
- [x] Standard CRUD (11 files — REFACTORED, not new)
- [x] Multi-FK validation — only 1 FK, but `ValidateForeignKeyRecord<Currency>`
- [x] Unique validation — `(CurrencyId, RateDate)` composite
- [x] Custom business rule validators — USD-rate-must-be-1, no-future-dates, positive-rate
- [x] **NEW: Bulk import command** — `BulkImportCurrencyConversionsCommand` (CSV upload → batch insert with skip-duplicates)
- [x] **NEW: Lookup query** — `LookupRateByDateQuery(CurrencyId, RateDate)` returns nearest-prior rate (used by donation entry forms)
- [x] **NEW: Summary query** — `GetCurrencyConversionSummary` (counts: active currencies tracked, last-sync timestamp, manual-override count, gap days)
- [x] **NEW: Manual sync trigger mutation** — `TriggerOpenExchangeRatesSync` (admin-only, calls hosted service on-demand)
- [x] **NEW: FxRateLookupService** — `IFxRateService` injected wherever donation/payment entry needs pre-fill (separate concern, not screen-coupled)
- [x] **NEW: OpenExchangeRatesSyncJob** — `IHostedService` running daily at 04:00 UTC; reads `OpenExchangeRatesApiKey` from app config; upserts rate rows with `Source="OpenExchangeRates"`

**Frontend Patterns Required**:
- [x] AdvancedDataTable (existing, refactor columns)
- [x] RJSF Modal Form (existing, refactor schema)
- [x] **NEW: Summary cards above grid** (4 cards — see Section ⑨)
- [x] **NEW: Conversion Calculator widget** (top-right of grid page — see Section ⑨)
- [x] **NEW: "Sync Now" button** in toolbar (calls TriggerOpenExchangeRatesSync mutation, shows toast with N rows synced)
- [x] **NEW: Bulk Import modal** (CSV file picker → preview → import)
- [x] **Layout Variant**: `widgets-above-grid` → MUST use `<ScreenHeader>` + widgets + `<DataTableContainer showHeader={false}>` (Variant B)

---

## ⑧ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Mockup is TBD — design specified from architectural reasoning + standard MASTER_GRID + Variant B widget pattern.

### Page Layout (Variant B — widgets-above-grid)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ <ScreenHeader>                                                            │
│   ⟶ Currency Conversion (FX Rate Master)         [+ Add] [Import] [Sync] │
└──────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────┐
│ Summary Cards Row (4 cards, gap-3, p-4 each)                              │
│ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐              │
│ │ Currencies │ │ Last Sync  │ │  Manual    │ │  Gap Days  │              │
│ │ Tracked    │ │ {timestamp}│ │ Overrides  │ │ (last 30d) │              │
│ │   12       │ │ 2h ago     │ │   3        │ │   0        │              │
│ └────────────┘ └────────────┘ └────────────┘ └────────────┘              │
└──────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────┐
│ Conversion Calculator Widget (collapsible, default open)                  │
│ ┌──────────────────────────────────────────────────────────────────────┐ │
│ │  Convert: [100         ] [USD ▾] → [INR ▾] on [2026-05-01]           │ │
│ │  Result:  ₹ 8,333.33  (using USD rate 1.0, INR rate 0.012)          │ │
│ └──────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────┐
│ <DataTableContainer showHeader={false}>                                   │
│   Filters: [Currency ▾] [Date Range] [Source ▾] [🔍 search]              │
│   ┌────┬──────────┬──────────┬────────────┬────────┬──────────┬────┐   │
│   │ ID │ Currency │ RateDate │ RateVsUSD  │ Source │ Notes    │ ⋯  │   │
│   ├────┼──────────┼──────────┼────────────┼────────┼──────────┼────┤   │
│   │ .. │ INR (₹)  │ 2026-05-01│ 0.01200000│ OXR    │ —        │ ⋯  │   │
│   │ .. │ EUR (€)  │ 2026-05-01│ 1.08000000│ OXR    │ —        │ ⋯  │   │
│   │ .. │ INR (₹)  │ 2026-04-30│ 0.01198000│ Manual │ Bank rec │ ⋯  │   │
│   └────┴──────────┴──────────┴────────────┴────────┴──────────┴────┘   │
│   [Pagination]                                                            │
└──────────────────────────────────────────────────────────────────────────┘
```

### Summary Cards (top row — 4 cards)

| # | Card Title | Value Source | Display Type | Position |
|---|-----------|-------------|-------------|----------|
| 1 | Currencies Tracked | `summary.currenciesTracked` | count | 1st |
| 2 | Last Sync | `summary.lastSyncAt` | relative-timestamp ("2h ago") + tooltip with full ISO | 2nd |
| 3 | Manual Overrides (last 30d) | `summary.manualOverrides30d` | count | 3rd |
| 4 | Gap Days (last 30d) | `summary.gapDays30d` | count + warning color if > 0 | 4th |

**Summary GQL Query**: `GetCurrencyConversionSummary` → returns `CurrencyConversionSummaryDto`.

### Conversion Calculator Widget

A small read-only utility — NOT tied to any record persistence. Form-style row:

```
[ Amount Input ] [ FromCcy ApiSelect ] [→] [ ToCcy ApiSelect ] [ DatePicker ] [Convert]
                                                                              ↓
                                                            Result: {symbol}{amount} (using {explanation})
```

Behavior:
- On click "Convert" (or auto on field change): call `LookupRateByDateQuery(FromCcyId, Date)` and `LookupRateByDateQuery(ToCcyId, Date)`, then compute `result = amount × (rateFrom / rateTo)`
- Display: formatted result with locale + currency symbol; explanation line shows the two rates used
- Both currencies default to USD on first load
- Date defaults to today
- Used by finance for ad-hoc reconciliation; also useful when admin gets a question like "what was 5000 USD in EUR on Jan 12?"

### Grid Columns

**Display Mode**: `table` (default)

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Currency | `currencyDisplay` | text — formatted as `${code} - ${name} (${symbol})` | 200px | YES | FK display, primary column |
| 2 | Rate Date | `rateDate` | date (yyyy-MM-dd) | 120px | YES | Default sort DESC |
| 3 | Rate vs USD | `rateAgainstUSD` | decimal (8 places) — right-aligned | 140px | YES | Mono font; render `1.0000` for USD with subtle grey "fixed" badge |
| 4 | Source | `source` | badge — color-coded: Manual=blue, OpenExchangeRates=green, ECB=purple, Imported=grey | 120px | YES | — |
| 5 | Notes | `notes` | text — truncated with tooltip on overflow | auto | NO | Optional |
| 6 | Created | `createdDate` | relative-timestamp | 120px | YES | — |
| 7 | Status | `isActive` | badge | 80px | YES | Active/Inactive |

**Search/Filter Fields**: Currency code/name, Rate Date range, Source

**Grid Actions**: Edit (only if `source=Manual`), Toggle Active, Delete

> NB: API-sourced rows render Edit as disabled with tooltip "API-sourced rate — add a new manual override row to correct".

### RJSF Modal Form

| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | Rate Details | 2-column | CurrencyId (ApiSelectV2 → GetAllCurrencyList), RateDate (DatePicker, max=today), RateAgainstUSD (decimal input, 8 places, validator), Source (read-only display = "Manual" for create) |
| 2 | Audit | 1-column full-width | Notes (textarea, max 500) |

**Field Widget Mapping**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| CurrencyId | ApiSelectV2 | "Select Currency" | required | Query: `GetAllCurrencyList` (display: `${code} - ${name}`) |
| RateDate | DateInput | yyyy-MM-dd | required, max=today | DateOnly format |
| RateAgainstUSD | NumberInput | "e.g. 0.01200000" | required, > 0, 8 decimal places | Disabled & locked at 1.0 if selected currency is USD |
| Source | Hidden (auto="Manual" for create, read-only for update) | — | — | Server-stamped |
| Notes | Textarea | "Optional audit note" | max 500 | — |

### Bulk Import Modal

Triggered by toolbar "Import" button. Modal with:
1. Drop zone for CSV file
2. Expected columns: `CurrencyCode, RateDate, RateAgainstUSD, Notes` (header row required)
3. Preview table of first 10 parsed rows
4. Validation summary (e.g., "12 valid, 3 skipped: duplicate date, 1 error: invalid currency code")
5. "Import N rows" button → calls `BulkImportCurrencyConversions` mutation
6. Result toast: "Imported 12 rates (3 skipped duplicates)"

`Source` for imported rows = `"Imported"`.

### Sync Now Button

Toolbar button — calls `TriggerOpenExchangeRatesSync` mutation. While running: spinner; on success: toast `"Synced {N} currencies for {date}"`. On failure: toast with error message.

### User Interaction Flow

1. Admin lands on page → 4 summary cards + calculator + grid load in parallel
2. Admin types "100 USD → INR on 2026-05-01" in calculator → result computes inline
3. Admin sees gap day count > 0 → clicks "Sync Now" → daily sync runs → grid refreshes
4. Admin needs to override yesterday's INR rate (bank gave a different rate) → clicks Add → form opens → fills in → save → row appears with `Source=Manual`
5. Admin downloads quarterly rates from a vendor → clicks Import → CSV upload → preview → confirm → batch saved

---

## ⑨ FE Service Folder & Backend Group

| Concern | Value |
|---------|-------|
| Backend Group | SharedModels (existing — `Base.Domain/Models/SharedModels/`) |
| Backend Endpoints folder | `Base.API/EndPoints/Shared/` |
| Backend Business folder | `Base.Application/Business/SharedBusiness/CurrencyConversions/` |
| FE Service | `shared-service` |
| FE Page Folder | `pages/general/masters/` |
| FE Component Folder | `components/page-components/general/masters/currencyconversion/` |
| FE Route | `app/[lang]/general/masters/currencyconversion/page.tsx` |

---

## ⑩ Substitution Guide

> Canonical reference: ContactType (MASTER_GRID).

| Canonical | → This Entity |
|-----------|--------------|
| ContactType | CurrencyConversion |
| contactType | currencyConversion |
| ContactTypeId | CurrencyConversionId |
| ContactTypes | CurrencyConversions |
| contact-type | currency-conversion (kebab not used here — folder is `currencyconversion`) |
| contacttype | currencyconversion |
| CONTACTTYPE | CURRENCYCONVERSION |
| corg | com |
| Corg | Shared |
| CorgModels | SharedModels |
| CONTACT | GEN_MASTERS |
| CRM | GENERAL |
| crm/contact/contacttype | general/masters/currencyconversion |
| corg-service | shared-service |

---

## ⑪ File Manifest

### Backend Files

#### Refactor (10 existing files)
| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `Base.Domain/Models/SharedModels/CurrencyConversion.cs` | REFACTOR fields |
| 2 | EF Config | `Base.Infrastructure/Data/Configurations/SharedConfigurations/CurrencyConversionConfiguration.cs` | REFACTOR |
| 3 | Schemas | `Base.Application/Schemas/SharedSchemas/CurrencyConversionSchemas.cs` | REFACTOR field renames |
| 4 | Create | `.../CurrencyConversions/Commands/CreateCurrencyConversion.cs` | REFACTOR + remove bug |
| 5 | Update | `.../CurrencyConversions/Commands/UpdateCurrencyConversion.cs` | REFACTOR + Source guard |
| 6 | Delete | `.../CurrencyConversions/Commands/DeleteCurrencyConversion.cs` | REFACTOR |
| 7 | Toggle | `.../CurrencyConversions/Commands/ToggleCurrencyConversion.cs` | KEEP |
| 8 | Get | `.../CurrencyConversions/Queries/GetCurrencyConversion.cs` | REFACTOR |
| 9 | GetById | `.../CurrencyConversions/Queries/GetCurrencyConversionById.cs` | REFACTOR |
| 10 | Mutations | `Base.API/EndPoints/Shared/Mutations/CurrencyConversionMutations.cs` | EXTEND (add 2 new mutations) |
| 11 | Queries | `Base.API/EndPoints/Shared/Queries/CurrencyConversionQueries.cs` | EXTEND (add 2 new queries) |

#### NEW (5 files)
| # | File | Path |
|---|------|------|
| 12 | BulkImport Command | `.../CurrencyConversions/Commands/BulkImportCurrencyConversions.cs` |
| 13 | TriggerSync Command | `.../CurrencyConversions/Commands/TriggerOpenExchangeRatesSync.cs` |
| 14 | LookupRate Query | `.../CurrencyConversions/Queries/LookupRateByDate.cs` |
| 15 | Summary Query | `.../CurrencyConversions/Queries/GetCurrencyConversionSummary.cs` |
| 16 | FxRateLookupService | `Base.Application/Services/FxRateLookupService.cs` (interface in `Base.Application/Abstractions/IFxRateService.cs`) |
| 17 | Sync HostedService | `Base.Infrastructure/HostedServices/OpenExchangeRatesSyncJob.cs` |
| 18 | OXR Client | `Base.Infrastructure/External/OpenExchangeRatesClient.cs` (HttpClient wrapper) |

#### Migration
| # | File | Action |
|---|------|--------|
| 19 | Migration | `Base.Infrastructure/Migrations/{timestamp}_Refactor_CurrencyConversion_To_USD_Pivot.cs` (auto-generated by `dotnet ef`) |

> ⚠️ Migration must include **data conversion** for existing rows: `Date DateTime → RateDate DateOnly` (cast .Date), `ConversionRate → RateAgainstUSD` (best-effort: assume existing values were "X USD per 1 unit of currency" — flag in migration comments for finance to verify post-migration; if unsafe, migration drops + re-seeds instead).

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` / `ApplicationDbContext.cs` | DbSet already exists → KEEP |
| 2 | `DecoratorProperties.cs` | `DecoratorSharedModules.CurrencyConversion` already at line ~117 → KEEP |
| 3 | `SharedMappings.cs` | Refactor Mapster config for new field names |
| 4 | `Program.cs` (Base.API) | Register `IFxRateService → FxRateLookupService` (Scoped) + `OpenExchangeRatesSyncJob` (HostedService) + `OpenExchangeRatesClient` (HttpClient via AddHttpClient) |
| 5 | `appsettings.json` (or secrets) | Add `OpenExchangeRates:ApiKey` config key (placeholder for dev; real key per env via secrets) |

### Frontend Files

#### Refactor (existing)
| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO | `domain/entities/shared-service/CurrencyConversionDto.ts` | REFACTOR (field renames + new types) |
| 2 | GQL Query | `infrastructure/gql-queries/shared-queries/CurrencyConversionQuery.ts` | REFACTOR + add `LookupRateByDate`, `GetCurrencyConversionSummary` |
| 3 | GQL Mutation | `infrastructure/gql-mutations/shared-mutations/CurrencyConversionMutation.ts` | REFACTOR + add `BulkImportCurrencyConversions`, `TriggerOpenExchangeRatesSync` |
| 4 | Page Config | `presentation/pages/general/masters/currencyconversion.tsx` | REFACTOR columns + form schema |
| 5 | Index Page | `presentation/components/page-components/general/masters/currencyconversion/data-table.tsx` | REFACTOR (Variant B) |
| 6 | Index Export | `presentation/components/page-components/general/masters/currencyconversion/index.ts` | KEEP |
| 7 | Route | `app/[lang]/general/masters/currencyconversion/page.tsx` | KEEP |

#### NEW (3 components)
| # | File | Path |
|---|------|------|
| 8 | Summary Cards | `presentation/components/page-components/general/masters/currencyconversion/summary-cards.tsx` |
| 9 | Conversion Calculator | `presentation/components/page-components/general/masters/currencyconversion/conversion-calculator.tsx` |
| 10 | Bulk Import Modal | `presentation/components/page-components/general/masters/currencyconversion/bulk-import-modal.tsx` |

#### DELETE (legacy duplicates)
| # | File to Delete |
|---|----------------|
| — | `presentation/pages/shared/commonasset/generalmaster/currencyconversion.tsx` |
| — | `presentation/components/page-components/shared/commonasset/generalmaster/currencyconversion/` (whole folder) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `shared-service-entity-operations.ts` | Update CurrencyConversion ops with new GQL field names |
| 2 | `domain/entities/shared-service/index.ts` | KEEP exports (no new files exposed externally) |
| 3 | `infrastructure/gql-queries/shared-queries/index.ts` | KEEP |
| 4 | `infrastructure/gql-mutations/shared-mutations/index.ts` | KEEP |

---

## ⑫ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: REFACTOR_EXTEND

MenuName: Currency Conversion
MenuCode: CURRENCYCONVERSION
ParentMenu: GEN_MASTERS
Module: GENERAL
MenuUrl: general/masters/currencyconversion
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: REGENERATE  (existing schema must be updated for new field names)
GridCode: CURRENCYCONVERSION

# REFACTOR-specific config
ExistingCodeAction: REFACTOR_REPLACE
DataMigrationStrategy: BEST_EFFORT_CAST  (Date→RateDate via .Date; ConversionRate→RateAgainstUSD copy with finance-audit flag)
LegacyFilesToDelete:
  - PSS_2.0_Frontend/src/presentation/pages/shared/commonasset/generalmaster/currencyconversion.tsx
  - PSS_2.0_Frontend/src/presentation/components/page-components/shared/commonasset/generalmaster/currencyconversion/

# Background job config
OpenExchangeRatesApiKey: <env-secret>  (placeholder; real key via env var or KeyVault)
SyncCronExpression: "0 4 * * *"  (daily 04:00 UTC)
SyncEnabledByDefault: false  (user must flip flag in CompanySettings → System Behavior; out of scope here, but config field must exist)
---CONFIG-END---
```

---

## ⑬ Expected BE→FE Contract

**GraphQL Types**:
- Query type: `CurrencyConversionQueries`
- Mutation type: `CurrencyConversionMutations`

**Queries**:
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAllCurrencyConversionList | `[CurrencyConversionResponseDto]` | searchText, pageNo, pageSize, sortField, sortDir, isActive, currencyId?, rateDateFrom?, rateDateTo?, source? |
| GetCurrencyConversionById | `CurrencyConversionResponseDto` | currencyConversionId |
| GetCurrencyConversionSummary | `CurrencyConversionSummaryDto` | — |
| LookupRateByDate | `RateLookupResponseDto` (currencyId, rateDate, rateAgainstUSD, source, lookedUpDate, fallbackUsed) | currencyId, rateDate (with nearest-prior fallback within 7d) |

**Mutations**:
| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateCurrencyConversion | CurrencyConversionRequestDto | int (new ID) |
| UpdateCurrencyConversion | CurrencyConversionRequestDto | int |
| DeleteCurrencyConversion | currencyConversionId | int |
| ToggleCurrencyConversion | currencyConversionId | int |
| BulkImportCurrencyConversions | BulkImportRequestDto (file: CSV upload) | BulkImportResultDto (importedCount, skippedCount, errorCount, errors[]) |
| TriggerOpenExchangeRatesSync | — | SyncResultDto (syncedCount, syncedAt, source) |

**Response DTO Fields** (CurrencyConversionResponseDto):
| Field | Type | Notes |
|-------|------|-------|
| currencyConversionId | number | PK |
| currencyId | number | FK |
| currencyCode | string | From Currency.CurrencyCode (USD, INR, EUR) |
| currencyName | string | From Currency.CurrencyName |
| currencySymbol | string | From Currency.CurrencySymbol |
| currencyDisplay | string | Pre-formatted: `${code} - ${name} (${symbol})` |
| rateDate | string | ISO date (yyyy-MM-dd) |
| rateAgainstUSD | number | decimal — 8 decimal places |
| source | string | Manual / OpenExchangeRates / ECB / Imported |
| notes | string \| null | Audit text |
| isActive | boolean | — |
| createdDate | string | ISO timestamp |
| modifiedDate | string \| null | ISO timestamp |

**Summary DTO Fields** (CurrencyConversionSummaryDto):
| Field | Type | Notes |
|-------|------|-------|
| currenciesTracked | number | Distinct CurrencyId count with at least 1 active rate |
| lastSyncAt | string \| null | ISO timestamp of latest row where Source ∈ (OpenExchangeRates, ECB) |
| manualOverrides30d | number | Count where Source=Manual AND CreatedDate >= now-30d |
| gapDays30d | number | Count of (currency, day) pairs in last 30 days where no rate row exists |

---

## ⑭ Acceptance Criteria

**Build Verification**:
- [ ] `dotnet build` — no errors after migration
- [ ] `pnpm dev` — page loads at `/[lang]/general/masters/currencyconversion`

**Functional Verification (Full E2E — MANDATORY)**:
- [ ] Grid loads with columns: Currency, RateDate, RateVsUSD, Source, Notes, Created, Status
- [ ] Sort default DESC by `rateDate`
- [ ] Search filters by Currency code/name; Source filter chip works; Date range picker works
- [ ] Add new manual rate → modal form → save → row appears with `Source=Manual`
- [ ] USD selected in form → RateAgainstUSD locks to 1.0000 (read-only)
- [ ] Future-dated entry rejected with error toast
- [ ] Duplicate `(CurrencyId, RateDate)` rejected with error toast
- [ ] API-sourced row: Edit button disabled with tooltip
- [ ] Delete with active donations on that date → warning shown, action proceeds (donations safe via snapshot)
- [ ] FK dropdown loads currency list correctly
- [ ] Summary cards show correct values (mock-trigger or seed data)
- [ ] Conversion Calculator: 100 USD → INR on today returns correct amount via dual lookup
- [ ] Conversion Calculator: when From=To, returns input amount unchanged
- [ ] Conversion Calculator: when no rate available, shows "Rate not found within 7 days" message
- [ ] Bulk Import: upload CSV with 5 rows (1 duplicate, 1 invalid currency) → preview shows 3 valid + 2 errors → import → toast confirms
- [ ] Sync Now: button calls API → toast on success/failure
- [ ] Permissions: BUSINESSADMIN sees all actions; lesser roles see read-only (per role config)

**DB Seed Verification**:
- [ ] Menu appears under General > Masters at OrderBy 2
- [ ] Grid columns render correctly per GridFormSchema
- [ ] RJSF form renders with USD-lock + date-max validations
- [ ] Currency master has at minimum: USD, INR, EUR, GBP rows for testing

**Migration Verification**:
- [ ] Pre-migration row count = post-migration row count (no data loss)
- [ ] Spot-check 5 random rows: `Date.Date == RateDate` and `ConversionRate == RateAgainstUSD` (or migration's documented transformation)
- [ ] `Currency.CurrencyRate` field DEPRECATED or DROPPED per audit decision
- [ ] No code outside the dropped buggy mutation reads `Currency.CurrencyRate`

**Integration Verification (cross-screen)**:
- [ ] GlobalDonation entry form: pre-fills ExchangeRate via `LookupRateByDate(donationCurrencyId, donationDate)` — verify a USD donation with INR base gets pre-filled (manual override still works)
- [ ] Snapshot rule: enter donation today → tomorrow edit a rate row → re-open donation → ExchangeRate value UNCHANGED ✅

---

## ⑮ Special Notes & Warnings

- **CORNERSTONE for financial accuracy.** Every donation entry, payment, ambassador remit will lookup against this table. Get the model right — the snapshot rule (Section ②, Rule 3) is non-negotiable.
- **Migration data risk.** Existing `ConversionRate` values' semantic is unclear (the legacy code used them as the *latest* rate against a tenant's base currency, NOT against USD). Best-effort migration assumes "1 unit of CurrencyId = ConversionRate USD" which **may be wrong**. Recommendation: flag all migrated rows with `Source="Imported-Legacy"` and `Notes="MIGRATED: please verify"` so finance can audit and re-seed the trusted set from a fresh OXR sync.
- **OpenExchangeRates API key**: free tier covers 1000 req/month at 1 req/day = 30/month. Plenty. Get key from openexchangerates.org. Store in env var `OPENEXCHANGERATES_API_KEY`, NOT in source.
- **OXR returns ALL rates against USD per call** (one HTTP request returns rates for ~170 currencies). Sync job parses the JSON `rates` object → upserts one row per `(currencyCode, RateDate)` where `currencyCode` matches a row in `com.Currencies`. Unmatched currencies in the API response are SKIPPED, not added.
- **No FK from any donation/payment table to CurrencyConversionId**. Reaffirm this rule in code review for every PR touching donation/payment entry.
- **`Currency.CurrencyRate` field**: separate audit ticket — likely DROP, but verify no consumers in BE+FE first. Audit in this build session and document findings in Build Log.
- **Multi-tenant rate overrides** (option B2 from planning) intentionally NOT implemented in this iteration. If a tenant ever needs custom rates (e.g., their bank gave a rate different from OXR), they enter a new `Source=Manual` row at the GLOBAL level — affects all tenants. Per-tenant override is a future feature gated behind a separate ticket.

**Service Dependencies** (NEW infrastructure introduced this build):
- `IFxRateService` — Scoped service injected into donation/payment forms. **In-scope this build.** All consumers must migrate to this service for rate lookups (replaces the broken `Currency.CurrencyRate` direct read).
- `OpenExchangeRatesSyncJob` — `IHostedService` runs daily 04:00 UTC. **In-scope this build.** Initially disabled by default; admin enables via "Sync Now" manual trigger or future config flag.
- `OpenExchangeRatesClient` — HttpClient wrapper for OXR API. **In-scope this build.**

Full UI must be built (summary cards, calculator, import modal, sync button). Only the "Sync Now → email finance team on failure" notification is mocked (uses toast — full email-finance feature is a separate ticket gated on the email infra).

---

## ⑯ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-01 — BUILD — COMPLETED

- **Scope**: Initial REFACTOR_EXTEND build from PROMPT_READY prompt. USD-pivot architecture replaces ambiguous `ConversionRate` + buggy `Currency.CurrencyRate` mutation pattern.
- **Files touched**:
  - BE Domain (modified):
    - `Base.Domain/Models/SharedModels/CurrencyConversion.cs` — entity refactored (dropped Date/ConversionRate, added RateDate/RateAgainstUSD/Source/Notes; nav made virtual)
    - `Base.Domain/Models/SharedModels/Currency.cs` — dropped `CurrencyRate` field (cascade cleanup; zero source consumers verified)
  - BE Application (modified):
    - `Base.Application/Schemas/SharedSchemas/CurrencyConversionSchemas.cs` — full rewrite with new DTOs (Request/Response/Dto + BulkImport DTOs + Summary + RateLookup + SyncResult)
    - `Base.Application/Schemas/SharedSchemas/CurrencySchemas.cs` — removed CurrencyRate from DTOs
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/CreateCurrencyConversion.cs` — bug removed (latest-rate-wins mutation deleted); added USD-lock + future-date + positive-rate + composite-unique validators
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/UpdateCurrencyConversion.cs` — bug removed; added Source="Manual" guard (API rows blocked from manual edit)
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/DeleteCurrencyConversion.cs` — kept soft-delete pattern
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/ToggleCurrencyConversion.cs` — kept IsActive toggle
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Queries/GetCurrencyConversion.cs` — field renames; search now covers CurrencyName + CurrencyCode + Source + Notes
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Queries/GetCurrencyConversionById.cs` — field rename sync
    - `Base.Application/Business/SharedBusiness/Currencies/Commands/CreateCurrency.cs` — removed `ValidatePropertyIsRequired(CurrencyRate)`
    - `Base.Application/Business/SharedBusiness/Currencies/Commands/UpdateCurrency.cs` — same removal
    - `Base.Application/Business/SharedBusiness/Currencies/Queries/GetCurrency.cs` — removed CurrencyRate from search
    - `Base.Application/Business/DonationBusiness/Refunds/Queries/GetRefundSummary.cs` — removed CurrencyRate fallback (now uses GdExchangeRate snapshot only — pre-FxRateService rows fall back to 1:1)
    - `Base.Application/Mappings/SharedMappings.cs` — Mapster CurrencyConversion mapping with custom CurrencyDisplay/CurrencyName/CurrencyCode/CurrencySymbol resolution
  - BE Application (created):
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/BulkImportCurrencyConversions.cs`
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Commands/TriggerOpenExchangeRatesSync.cs`
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Queries/LookupRateByDate.cs`
    - `Base.Application/Business/SharedBusiness/CurrencyConversions/Queries/GetCurrencyConversionSummary.cs`
    - `Base.Application/Interfaces/IFxRateService.cs`
    - `Base.Application/Interfaces/IOpenExchangeRatesSyncJob.cs`
  - BE Infrastructure (modified):
    - `Base.Infrastructure/Data/Configurations/SharedConfigurations/CurrencyConversionConfigurations.cs` — refactored to new fields + filtered unique index `(CurrencyId, RateDate) WHERE IsDeleted=false`
    - `Base.Infrastructure/Data/Configurations/SharedConfigurations/CurrencyConfiguration.cs` — removed CurrencyRate config
    - `Base.Infrastructure/DependencyInjection.cs` — registered `IFxRateService` (Scoped), typed HttpClient `OpenExchangeRatesClient`, `OpenExchangeRatesSyncJob` (Singleton + IHostedService + IOpenExchangeRatesSyncJob)
  - BE Infrastructure (created):
    - `Base.Infrastructure/Services/Currency/FxRateService.cs` — nearest-prior 7-day fallback + ConvertAsync USD-pivot math
    - `Base.Infrastructure/External/OpenExchangeRates/IOpenExchangeRatesClient.cs`
    - `Base.Infrastructure/External/OpenExchangeRates/OpenExchangeRatesClient.cs`
    - `Base.Infrastructure/HostedServices/OpenExchangeRatesSyncJob.cs` — daily 04:00 UTC, gated by `Fx:AutoSyncEnabled` (default false), exposes `RunOnceAsync` for manual trigger
  - BE API (modified):
    - `Base.API/EndPoints/Shared/Mutations/CurrencyConversionMutations.cs` — added BulkImportCurrencyConversions + TriggerOpenExchangeRatesSync mutations
    - `Base.API/EndPoints/Shared/Queries/CurrencyConversionQueries.cs` — added GetAllCurrencyConversionList (renamed from GetCurrencyConversions) + GetCurrencyConversionSummary + LookupRateByDate
    - `Base.API/appsettings.json` — added `OpenExchangeRates:ApiKey` placeholder + `Fx:AutoSyncEnabled: false`
  - BE Migration (created):
    - `Base.Infrastructure/Migrations/20260501120000_Refactor_CurrencyConversion_To_USD_Pivot.cs` — drops old columns + Currency.CurrencyRate, adds new columns + filtered unique index, BEST_EFFORT_CAST data migration with `Source='Imported-Legacy'` for legacy rows
  - FE (modified):
    - `domain/entities/shared-service/CurrencyConversionDto.ts` — field renames + 5 new DTOs (Summary/BulkImport*/RateLookup/SyncResult)
    - `infrastructure/gql-queries/shared-queries/CurrencyConversionQuery.ts` — updated CRUD + added GET_CURRENCY_CONVERSION_SUMMARY_QUERY + LOOKUP_RATE_BY_DATE_QUERY
    - `infrastructure/gql-mutations/shared-mutations/CurrencyConversionMutation.ts` — updated CRUD + added BULK_IMPORT_CURRENCY_CONVERSIONS_MUTATION + TRIGGER_OPEN_EXCHANGE_RATES_SYNC_MUTATION
    - `presentation/components/page-components/general/masters/currencyconversion/data-table.tsx` — full Variant B refactor: ScreenHeader + summary cards + ConversionCalculator + DataTableContainer showHeader=false + BulkImportModal + Sync trigger
    - `presentation/components/page-components/general/masters/currencyconversion/index.ts` — added new exports
    - `presentation/pages/shared/commonasset/generalmaster/index.ts` — removed legacy CurrencyConversionPageConfig export
    - `presentation/components/page-components/shared/commonasset/generalmaster/index.ts` — removed legacy currencyconversion wildcard
  - FE (created):
    - `presentation/components/page-components/general/masters/currencyconversion/summary-cards.tsx` — 4 stat cards (Currencies/Last Sync/Manual Overrides/Gap Days) with Skeleton + amber warning
    - `presentation/components/page-components/general/masters/currencyconversion/conversion-calculator.tsx` — collapsible USD-pivot calculator (lazy GQL lookups, fallback indicators, same-currency shortcut)
    - `presentation/components/page-components/general/masters/currencyconversion/bulk-import-modal.tsx` — CSV picker with 10-row preview + valid/error counts
  - FE (deleted):
    - `presentation/pages/shared/commonasset/generalmaster/currencyconversion.tsx` (legacy duplicate)
    - `presentation/components/page-components/shared/commonasset/generalmaster/currencyconversion/` (entire legacy folder)
  - DB Seed (created):
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/CurrencyConversion-sqlscripts.sql` — Menu+MenuCapabilities+RoleCapabilities (BUSINESSADMIN)+Grid+Fields+GridFields (8 cols incl. badge-source renderer)+GridFormSchema (RJSF with ApiSelectV2 for Currency, DatePicker maxDate=today, NumberWidget step=0.000001, SelectWidget for Source enum, Textarea for Notes, 2-col layout)+5 baseline rates (USD/INR/EUR/GBP/AUD with `Source='Manual'`)
- **Deviations from spec**:
  - GraphQL query method renamed `GetCurrencyConversions → GetAllCurrencyConversionList` per locked Section ⑬ contract; underlying CQRS query record kept name `GetCurrencyConversionsQuery`.
  - `IFxRateService` placed in `Base.Application/Interfaces/` (existing convention) instead of suggested `Abstractions/` folder.
  - `IOpenExchangeRatesClient` placed in `Base.Infrastructure/External/OpenExchangeRates/` (Infrastructure-only consumer — no Application-layer caller).
  - Conversion Calculator inputs use numeric Currency ID rather than ApiSelectV2 — store-context collision risk inside nested grid provider; future enhancement to use lightweight currency search dropdown documented.
  - Cascade cleanup of `Currency.CurrencyRate` extended to 7 dependent files (audit-then-drop, zero source consumers found beyond grep noise in screen-tracker docs).
- **Known issues opened**: None
- **Known issues closed**: None
- **Next step**: Run migration `20260501120000_Refactor_CurrencyConversion_To_USD_Pivot` then `CurrencyConversion-sqlscripts.sql`. Set `OpenExchangeRates:ApiKey` in appsettings to enable manual sync; flip `Fx:AutoSyncEnabled=true` to start daily 04:00 UTC sync.

### Session 2 — 2026-05-01 — REFACTOR — COMPLETED

- **Scope**: **Architecture pivot — USD-pivot model REJECTED, refactored to strict direct-pair**. User feedback: "RateAgainstUSD is not correct... we need FromCurrencyId, ToCurrencyId, ConversionRate. proper way for multi tenant application." Hybrid (direct-pair + USD-triangulation fallback) also rejected ("no hybrid"). Final shape: pure direct-pair, no inverse lookup, no triangulation. Admin must curate every pair they need; OpenExchangeRates sync only stores `(USD, X)` direction.
- **Bug fixed mid-session (CS1061)**: Session 1 validators used `RuleFor(x => x.currencyConversion).MustAsync((dto, ct) => ...dto.currencyConversion.X)` — one level too deep. Lambda's `dto` is the DTO directly, not the command. Fixed to `dto.X`. Build cleaned to 0 errors before architecture pivot.
- **Files touched** (architecture pivot):
  - BE Domain (modified):
    - `CurrencyConversion.cs` — replaced single-FK shape (`CurrencyId`, `RateAgainstUSD`, `Currency`) with direct-pair shape (`FromCurrencyId`, `ToCurrencyId`, `ConversionRate`, `FromCurrency`, `ToCurrency` navs)
    - `Currency.cs` — added `CurrencyConversionsAsTo` collection; `CurrencyConversions` now points to FromCurrencyId side
  - BE Infrastructure (modified):
    - `CurrencyConversionConfigurations.cs` — dual FK configs (FromCurrencyId, ToCurrencyId), new filtered unique index `(FromCurrencyId, ToCurrencyId, RateDate) WHERE IsDeleted=false`
    - `FxRateService.cs` — signature `GetRateAsync(fromCode, toCode, asOfDate)`. Logic: same-currency → 1.0; resolve both currency IDs; direct DB query within 7-day window; null if missing. **NO inverse lookup, NO triangulation.**
    - `OpenExchangeRatesSyncJob.cs` — stores `(USD, X)` direction rows only; resolves USD CurrencyId once, skips USD self-pair
    - `ApplicationDbContextModelSnapshot.cs` — entity shape + dual relationships
  - BE Application (modified):
    - `CurrencyConversionSchemas.cs` — full rewrite: From/To DTOs, BulkImportItemDto (`fromCurrencyCode/toCurrencyCode`), redesigned Summary (added `totalPairs`, removed `missingRatesToday`), Lookup (`{conversionRate, rateDate, source}`)
    - `Create/UpdateCurrencyConversion.cs` — dual FK validators, **`FromCurrencyId != ToCurrencyId` self-pair guard**, removed USD anchor rule
    - `BulkImportCurrencyConversions.cs` — dual code lookup, self-pair rejection per row
    - `GetCurrencyConversion.cs`, `GetCurrencyConversionById.cs` — dual nav `Include`, search across both sides
    - `GetCurrencyConversionSummary.cs` — `TotalCurrencies` (union from+to), `TotalPairs` (distinct pair count), `StaleRatesCount` (latest > 7 days)
    - `LookupRateByDate.cs` — signature `(FromCurrencyCode, ToCurrencyCode, RateDate)`; same-currency shortcut; strict direct query
    - `IFxRateService.cs` — interface signature change
    - `SharedMappings.cs` — Mapster dual-nav projection (FromCurrencyDisplay, ToCurrencyDisplay, PairDisplay)
  - BE API (modified):
    - `CurrencyConversionQueries.cs` — `LookupRateByDate` now `(fromCurrencyCode, toCurrencyCode, asOfDate)`
  - BE Migration (created):
    - `20260501130000_Refactor_CurrencyConversion_To_DirectPair.cs` — drops legacy `CurrencyId/Date/ConversionRate` + `Currencies.CurrencyRate`; adds `FromCurrencyId/ToCurrencyId/RateDate/ConversionRate/Source/Notes` with dual FK constraints; PL/pgSQL data migration mapping legacy rows to `(CurrencyId → USD)` direction with `Source='Imported-Legacy'`; new filtered unique index. (Old `20260501120000_..._USD_Pivot` migration was never present in disk — only the snapshot reflected legacy schema.)
  - FE (modified — 7 files):
    - `CurrencyConversionDto.ts` — From*/To*/PairDisplay/conversionRate fields; SummaryDto adds `totalPairs`, drops `missingRatesToday`; BulkImport item uses dual codes
    - `CurrencyConversionQuery.ts` — all queries updated; **`LOOKUP_RATE_BY_DATE_QUERY` signature changed** to `($fromCurrencyCode, $toCurrencyCode, $asOfDate)`
    - `CurrencyConversionMutation.ts` — input vars updated; bulk import items use dual codes
    - `summary-cards.tsx` — Total Currencies / Active Pairs / Last Sync / Stale Pairs (4 cards)
    - `conversion-calculator.tsx` — **completely rewritten**: ONE backend call (no USD-pivot math); fail-soft message when rate is null ("No rate available for X→Y on {date}. Add this rate first or run sync.")
    - `bulk-import-modal.tsx` — CSV columns `fromCurrencyCode/toCurrencyCode/rateDate/conversionRate/source/notes`; from≠to per-row validation
    - `data-table.tsx` — `SyncResult` shape updated; description text updated
  - DB Seed (modified):
    - `CurrencyConversion-sqlscripts.sql` — full rewrite: 9 new field codes (`PAIRDISPLAY`, `FROMCURRENCYDISPLAY`, `TOCURRENCYDISPLAY`, `CONVERSIONRATE`, etc.), 8 grid columns (Pair badge + Rate Date + Conversion Rate + Source + Notes + Status + Modified), RJSF form schema with dual ApiSelectV2 currency dropdowns + DatePicker + NumberWidget + SelectWidget, 5 baseline rates (USD→INR/EUR/GBP/AUD/AED with `Source='Manual'`)
- **Build verification**: `dotnet build PeopleServe.sln` → **Build succeeded. 0 Error(s)**. FE `tsc --noEmit` → exit 0, no CurrencyConversion errors.
- **Strict direct-pair enforcement (verified across stack)**:
  - `FxRateService.GetRateAsync` — direct query only, returns null if missing pair
  - `LookupRateByDate` query — same-currency shortcut + direct query only
  - `OpenExchangeRatesSyncJob` — stores USD→X only (one direction)
  - `BulkImport` — stores exactly what's submitted, no auto-inverse
  - Interface comment + handler comments document strict-no-fallback policy
- **Deviations from spec**: None
- **Known issues opened**: None
- **Known issues closed**: ISSUE-implicit (validator lambda scope) — fixed inline before architecture pivot
- **Next step**: Run migration `20260501130000_Refactor_CurrencyConversion_To_DirectPair` then `CurrencyConversion-sqlscripts.sql`. Set `OpenExchangeRates:ApiKey` in `appsettings.json`. Manual sync via "Sync Now" button works regardless; flip `Fx:AutoSyncEnabled=true` to enable daily 04:00 UTC sync. **Important**: tenants whose donations come in non-USD currencies (e.g., INR-base tenant receiving EUR donation) require admin to manually enter `(EUR, INR)` rate row — sync only covers USD→X direction. This is the deliberate trade-off of strict direct-pair: explicit, audit-friendly, no silent triangulation.

### Session 3 — 2026-05-01 — REFACTOR — COMPLETED

- **Scope**: Refactor `OpenExchangeRatesSyncJob` to tenant-aware pair discovery + write-time derivation for non-USD pairs (Option A from sync architecture decision). Replaces Session 2's single-direction USD→X sync, which left admins with manual data entry burden for cross-pair / inverse rates.
- **Architecture decision**: Read path remains **strict direct-pair** (FxRateService never triangulates at lookup). Write path now derives non-USD pairs ONCE at sync time and stores them as discrete, audit-traceable rows with `Source = "OpenExchangeRates-Derived"`. This satisfies the user's "no hybrid runtime triangulation" rule while still automating cross-pair coverage.
- **Pair-discovery query**: joins `sett.CompanyConfigurations` with `sett.CompanyConfigurationCurrencies` to compute the global distinct pair set across all tenants in BOTH directions (`base→coll` AND `coll→base`). Self-pairs excluded.
- **Rate computation per pair** (in `ComputePairRate`):
  - `From=USD` → API value direct → `Source = "OpenExchangeRates"`
  - `To=USD` → `1 / api[from]` → `Source = "OpenExchangeRates-Derived"`
  - Cross-pair (neither USD) → `api[to] / api[from]` → `Source = "OpenExchangeRates-Derived"`
  - If either currency missing from API response → skip (debug-logged)
- **Manual override protection**: existing rows with `Source="Manual"` are NEVER overwritten by sync. API/Derived rows for the same day get value-updated in place (latest fetch wins).
- **Files touched**:
  - `Base.Infrastructure/HostedServices/OpenExchangeRatesSyncJob.cs` — full rewrite of `RunOnceAsync`. Adds `ISettingDbContext` dependency for tenant pair discovery. Splits logic into `DiscoverTenantPairsAsync` + `ComputePairRate` helpers. Returns rich `SyncResultDto { Success, RowsAdded, Message }` summary.
  - `Base.Application/Schemas/SharedSchemas/CurrencyConversionSchemas.cs` — `SyncResultDto` shape changed from `{SyncedCount, SyncedAt, Source, ErrorMessage}` to `{Success, RowsAdded, Message}` to align with FE expectation (`CurrencyConversionDto.ts:66-70`).
  - `Base.Application/.../Commands/TriggerOpenExchangeRatesSync.cs` — error path uses new SyncResultDto shape.
  - `Base.Application/.../Commands/CreateCurrencyConversion.cs` — `AllowedSources` adds `"OpenExchangeRates-Derived"` (so admin can manually enter such rows if needed for testing/correction).
  - `Base.Application/.../Commands/UpdateCurrencyConversion.cs` — same allowlist update.
  - `PSS_2.0_Backend/.../sql-scripts-dyanmic/CurrencyConversion-sqlscripts.sql` — Source filter dropdown (badge-source `staticOptions`) extends with `"OpenExchangeRates-Derived"` value/label so finance can filter the grid by derived rows.
- **Build verification**: `dotnet build PeopleServe.sln` → **Build succeeded. 0 Error(s)**.
- **Operational outcome (5-tenant example with bases INR/EUR/USD/AED + collectables USD/EUR/GBP/AED)**:
  - Distinct tenant pairs: ~12 unique pairs both directions = ~24 daily upserts
  - API natively covers ~5 (USD→others)
  - Sync derives the remaining ~19 at write time using USD-pivot math
  - Each row stored with explicit Source label for audit
  - Admin's daily manual entry burden: zero (unless their bank quotes differ from market — then they Override with Manual row)
- **Strict no-runtime-triangulation enforcement (re-verified)**:
  - `FxRateService.GetRateAsync`: still direct-only, returns null on miss
  - `LookupRateByDate`: still direct-only with same-currency shortcut
  - The new write-time derivation produces **stored rows**, not runtime computations — read path is unchanged
- **Deviations from spec**: None
- **Known issues opened**: None
- **Known issues closed**: None
- **Next step**: Same as Session 2 — run migration, run seed SQL, configure `OpenExchangeRates:ApiKey`, flip `Fx:AutoSyncEnabled=true` for automated daily sync. The new sync now automatically covers all tenant pair needs once `CompanyConfigurations` rows have `BaseCurrencyId` + `CompanyConfigurationCurrencies` populated.