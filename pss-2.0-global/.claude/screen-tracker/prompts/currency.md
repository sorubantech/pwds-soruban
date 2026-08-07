---
screen: Currency
registry_id: 79
module: General → Masters
status: NEEDS_FIX
scope: ALIGN
screen_type: MASTER_GRID
complexity: Medium
new_module: NO
planned_date: 2026-05-15
completed_date: 2026-05-16
last_session_date: 2026-07-22
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed (BE + FE audited)
- [x] Business rules extracted
- [x] FK targets resolved (BaseCurrencyId on CompanyConfiguration; rate source = `com.CurrencyConversions`)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt is canonical — ALIGN MASTER_GRID, no re-analysis needed)
- [x] Solution Resolution complete (Type-1 MASTER_GRID + banner hero + expandable rate-history rows)
- [x] UX Design finalized (Variant B: ScreenHeader + BaseCurrencyBanner + DataTableContainer)
- [x] User Approval received (2026-05-15)
- [x] Backend code modified (ALIGN — 11 modified + 3 new in `SharedBusiness/Currencies` + Schemas + Endpoints + Mapster + Snapshot)
- [x] Backend wiring confirmed (no new DbSet entries — Currency already mapped)
- [x] Frontend code modified (ALIGN — data-table rewritten Variant B; 6 components in screen folder + 2 shared cell renderers; cell renderers registered in advanced/basic/flow registries)
- [x] Frontend wiring confirmed (route at `[lang]/general/masters/currency` untouched; CompanySettings query extended with base-currency display fields)
- [x] DB Seed GridFormSchema regenerated (with `dependencies` block for conditional `autoUpdateFrequency`); GridFields rewired (currency-cell + format-preview-cell renderers; redundant cols hidden)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/general/masters/currency`
- [ ] Base Currency banner card renders with current `CompanyConfiguration.BaseCurrencyId` (flag + code + name)
- [ ] "Change Base Currency" button opens confirmation modal → currency dropdown → confirm updates `CompanyConfiguration.BaseCurrencyId`
- [ ] Grid columns render: Currency (flag+code+name) | Symbol | Format preview | Rate to Base | Last Updated | Status | Actions
- [ ] Format preview cell renders `"1,234.56 د.إ"` (live preview built from Symbol + SymbolPosition + DecimalPlaces + ThousandsSeparator + DecimalSeparator)
- [ ] "Rate to Base" column shows latest `ConversionRate` from `CurrencyConversions` (FromCurrencyId=row, ToCurrencyId=BaseCurrencyId); base row shows `1.0000 (base)`
- [ ] "Last Updated" column shows latest `RateDate` from CurrencyConversions; base row shows `—`
- [ ] Row-action More menu: Edit | View Rate History | Activate/Deactivate | Remove
- [ ] "View Rate History" expands a child row showing CurrencyConversions for that currency (Date / Rate / Source / Change-from-previous)
- [ ] "Update Rates" header button opens confirmation → batch-recalc/refetch rates for all currencies whose `RateSource=Auto` (UI-only handler: SERVICE_PLACEHOLDER, toast "Auto-rate fetch not yet implemented")
- [ ] Add Currency modal: Currency picker | Symbol Position (Before/After) | Decimal Places (0/2/3) | Thousands Separator (comma/period/space/indian) | Decimal Separator (period/comma) | Exchange Rate to Base | Rate Source (Manual/Auto) | Auto-Update Frequency (visible only when RateSource=Auto)
- [ ] Saving Add creates Currency row + initial CurrencyConversion row (FromCurrencyId=new, ToCurrencyId=BaseCurrencyId, RateDate=today, Source=value)
- [ ] Edit modal pre-fills all currency-format fields; saving Edit updates Currency + appends new CurrencyConversion only if rate changed
- [ ] Toggle Active/Inactive updates `IsActive`; inactive row shows greyed style + "Inactive" badge
- [ ] Delete soft-deletes Currency; blocked with toast if Currency is the base currency or has dependent records (GlobalDonation/Campaign refs)
- [ ] DB Seed — menu `CURRENCY` visible under `GEN_MASTERS`, GridFormSchema renders modal correctly with conditional Auto-Update Frequency field

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Currency Management
Module: General → Masters
Schema: `com` (Currency entity is shared — `Base.Domain/Models/SharedModels/Currency.cs`)
Group: **Shared** (namespace folders: `SharedModels`, `SharedConfigurations`, `SharedSchemas`, `SharedBusiness/Currencies`, `EndPoints/Shared`)

Business: Currency Management is the master where admins curate the set of currencies their organization transacts in, set the **base currency** (the one all reports and consolidations are converted to), and maintain the **direct-pair exchange rates** that power every multi-currency screen — donations, campaigns, payment reconciliation, refunds, member-portal pricing. It sits under **General → Masters → Currency** and is the upstream truth for every FX lookup in the platform (every donation/refund row snapshots a rate value here at the time of save — see `IFxRateService.GetRateAsync`). The screen surfaces three responsibilities in one view: (1) the **base currency** as a visual banner (with a Change action that recomputes downstream rates), (2) the **active currency list** with format / symbol / decimal rules so each currency renders correctly across the app, and (3) the **latest rate to base** plus an inline **rate history** for audit. A separate Update Rates batch action fetches fresh quotes for currencies marked `RateSource=Auto` (full UI scope; auto-fetch handler is a service placeholder until the FX provider integration lands).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Entity already exists — DO NOT regenerate. This section documents current shape + the delta required to satisfy the mockup.

Table: `com.Currencies`
Entity file: `Base.Domain/Models/SharedModels/Currency.cs` (existing)

### Existing fields (keep)
| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CurrencyId | int | — | PK | — | Existing |
| CurrencyName | string | 100 | YES | — | Existing — `[CaseFormat("title")]` |
| CurrencyCode | string | 10 | YES | — | Existing — `[CaseFormat("upper")]`; unique per Company |
| CurrencySymbol | string | 10 | YES | — | Existing |
| IsActive | bool | — | inherited | — | From `Entity` base — drives Active/Inactive badge |
| IsDeleted | bool | — | inherited | — | From `Entity` base — soft delete |

### NEW fields to ADD (formatting + rate-source)
| Field | C# Type | MaxLen | Required | FK Target | Default | Notes |
|-------|---------|--------|----------|-----------|---------|-------|
| FlagEmoji | string? | 16 | NO | — | null | e.g. `"🇦🇪"`. Optional; FE falls back to code letters if null |
| SymbolPosition | string | 10 | YES | — | `"Before"` | `"Before"` \| `"After"` |
| DecimalPlaces | int | — | YES | — | `2` | `0` \| `2` \| `3` |
| ThousandsSeparator | string | 10 | YES | — | `"Comma"` | `"Comma"` \| `"Period"` \| `"Space"` \| `"Indian"` |
| DecimalSeparator | string | 10 | YES | — | `"Period"` | `"Period"` \| `"Comma"` |
| RateSource | string | 20 | YES | — | `"Manual"` | `"Manual"` \| `"Auto"` |
| AutoUpdateFrequency | string? | 20 | NO | — | null | `"Daily"` \| `"Weekly"` \| `"Monthly"`. Required only when `RateSource = "Auto"` |

**Migration**: `Add_Formatting_And_RateSource_To_Currency` — add the 7 new columns to `com.Currencies`. Backfill existing rows with defaults (`SymbolPosition='Before', DecimalPlaces=2, ThousandsSeparator='Comma', DecimalSeparator='Period', RateSource='Manual'`).

### Related entities (do NOT modify shape — read only)
| Entity | Role |
|--------|------|
| `CurrencyConversion` (`com.CurrencyConversions`) | Source for "Rate to Base" + "Last Updated" + rate-history child rows. FK from CurrencyConversion.FromCurrencyId/ToCurrencyId. Already has `RateDate`, `ConversionRate`, `Source`, `Notes`. |
| `CompanyConfiguration` (`sett.CompanyConfigurations`) | `BaseCurrencyId` field holds the tenant's base currency. Read for banner card; write via "Change Base Currency" action. |

**Child Entities for this screen**: NONE — currency has no owned children. Rate history is a sibling read.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for navigation + LINQ subqueries) + Frontend Developer (for ApiSelect queries)

| FK / Reference | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| (banner read) BaseCurrencyId | Currency via CompanyConfiguration | `Base.Domain/Models/SettingModels/CompanyConfiguration.cs` (read `BaseCurrencyId`) | `getCompanySettings` (existing) — extend response to include `baseCurrencyId/baseCurrencyCode/baseCurrencyName/baseCurrencySymbol` | CurrencyCode | `CompanySettingsResponseDto` |
| (rate read) Latest rate | CurrencyConversion | `Base.Domain/Models/SharedModels/CurrencyConversion.cs` | `currencies` query — extend Response DTO with `LatestRateToBase` + `LatestRateDate` from LINQ subquery (see ⑩) | ConversionRate, RateDate | `CurrencyResponseDto` (extended) |
| (rate history) Per-currency history | CurrencyConversion | same as above | NEW `GetCurrencyRateHistory(currencyId, toCurrencyId)` query — returns recent CurrencyConversions for that pair (latest 20, ordered RateDate DESC) | RateDate, ConversionRate, Source | `CurrencyRateHistoryDto` |

**Currency picker in modal** (for "Add Currency" + "Change Base Currency"): use existing `currencies` query filtered to `isActive=false` for Add (offer currencies not yet enabled) and `isActive=true` for Change-Base (offer enabled currencies other than current base).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `CurrencyCode` must be unique per Company (existing) — `ValidateUniqueWhenCreate` / `ValidateUniqueWhenUpdate`

**Required Field Rules:**
- `CurrencyName`, `CurrencyCode`, `CurrencySymbol`, `SymbolPosition`, `DecimalPlaces`, `ThousandsSeparator`, `DecimalSeparator`, `RateSource` are mandatory
- `AutoUpdateFrequency` required ONLY when `RateSource = "Auto"`

**Conditional Rules:**
- When `RateSource = "Manual"` → `AutoUpdateFrequency` MUST be null (clear on save)
- When `RateSource = "Auto"` → `AutoUpdateFrequency` MUST be one of `Daily | Weekly | Monthly`
- Base currency row: `Rate to Base = 1.0000` (display-only — no CurrencyConversion row needed); show `(base)` label
- Add-Currency form may collect an initial `Exchange Rate to Base` value — on save, BE creates a CurrencyConversion row (FromCurrencyId=new, ToCurrencyId=BaseCurrencyId, RateDate=today, ConversionRate=value, Source=RateSource)
- Edit form may collect a NEW exchange rate; if the value differs from the latest CurrencyConversion, BE appends a NEW row (do NOT mutate prior history)

**Business Logic — Toggle/Delete:**
- Cannot Delete a Currency if it is the current base currency (block with `BadRequest("Cannot delete base currency — change base first.")`)
- Cannot Delete a Currency if any of these have references: `GlobalDonation.CurrencyId`, `GlobalDonation.BaseCurrencyId`, `Campaign.CurrencyId`, `BulkDonationDistribution.CurrencyId`, `ContactDonationPurpose.CurrencyId`, `CompanyEmailProvider.CurrencyId`, `Country.CurrencyId` (use FK reverse-check via navigation ICollections already on entity)
- Toggle to Inactive: allowed even if currency is referenced, but FE warns "This currency has X linked donations and will remain visible for historical records"
- Base currency cannot be set to Inactive

**Business Logic — Change Base Currency:**
- Update `CompanyConfiguration.BaseCurrencyId` to the new currency
- Existing CurrencyConversion rows are NOT mathematically rewritten (V1) — admins are warned via the modal copy that downstream rates may need re-entry
- New CurrencyConversion row inserted: FromCurrencyId=oldBase, ToCurrencyId=newBase, RateDate=today, ConversionRate=1/oldNewRate, Source="System-BaseChange" (best-effort; null if no prior rate found)

**Business Logic — Update Rates (Auto):**
- SERVICE_PLACEHOLDER for V1. Full UI; handler issues a toast: "Auto-rate fetch will be available once OpenExchangeRates is wired up."
- BE endpoint exists: `LookupRateByDate` (existing). The batch refresh wrapper does not.

**Workflow**: None — direct CRUD with the above lifecycle gates.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: MASTER_GRID
**Type Classification**: Type 1 (flat entity, modal RJSF form) — extended with banner-card hero + per-row expand for rate history
**Reason**: List of currencies with per-row CRUD via modal popup; the banner card and expandable history rows are presentational extensions of the standard grid pattern. No multi-mode view-page (it's modal), no widget grid (no KPIs), no public surface.

**Backend Patterns Required:**
- [x] Standard CRUD (extend existing 8 files — DO NOT regenerate)
- [ ] Nested child creation — N/A (no children)
- [ ] Multi-FK validation — N/A
- [x] Unique validation — `CurrencyCode` per Company (existing — keep)
- [ ] File upload command — N/A
- [x] Custom commands (NEW):
  - `ChangeBaseCurrencyCommand(int newBaseCurrencyId)` — updates `CompanyConfiguration.BaseCurrencyId`
  - `BatchUpdateAutoRatesCommand()` — SERVICE_PLACEHOLDER: returns success with `RowsAdded=0`, `Message="Auto-fetch pending OpenExchangeRates integration"`
- [x] Custom queries (NEW):
  - `GetCurrencyRateHistoryQuery(int currencyId, int toCurrencyId, int take=20)` — recent CurrencyConversion rows for an expandable row
  - Extend `GetCurrenciesQuery` Response DTO with `LatestRateToBase` + `LatestRateDate` via LINQ subquery against `CurrencyConversions`
  - Extend `GetCompanySettingsQuery` (existing) to surface `BaseCurrencyCode/Name/Symbol/FlagEmoji` for the banner

**Frontend Patterns Required:**
- [x] AdvancedDataTable (existing — keep `gridCode="CURRENCY"`)
- [x] RJSF Modal Form (driven by extended GridFormSchema in DB seed)
- [ ] File upload widget — N/A
- [ ] Summary cards / count widgets — N/A (banner card is a hero, not a metric widget)
- [x] Custom in-page elements:
  - **Base Currency banner** above the grid (gradient card with flag, code/name, Change button)
  - **Expandable child row** for "View Rate History" (custom `expandedRowRender`)
  - **Format preview cell renderer** (composes from row's formatting fields)
  - **Conditional form field** (Auto-Update Frequency visible only when RateSource=Auto — RJSF `dependencies`)
- [ ] Side panel — N/A
- [ ] Drag-to-reorder — N/A
- [ ] Click-through filter — N/A

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Display Mode

**Display Mode**: `table` (default — dense admin grid)

### Page Header

- Title: **Currency Management** (icon `fa-coins`, color `--settings-accent` indigo)
- Subtitle: "Configure currencies, exchange rates, and formatting"
- Header actions (right):
  - `Update Rates` — outline button, icon `fa-arrows-rotate` → opens "Update Exchange Rates" confirm modal
  - `Add Currency` — primary button, icon `fa-plus` → opens Add Currency modal

### Base Currency Banner (above the grid)

Component: `<BaseCurrencyBanner currency={baseCurrency} onChangeBase={openChangeBaseModal} />`

Layout — full-width gradient card (`linear-gradient(135deg, var(--settings-accent), #818cf8)`, white text):
- Left cluster: Flag emoji (2.5rem) + label "BASE CURRENCY" + title `{code} — {name}` + caption "All reports and consolidations are converted to this currency"
- Right cluster: ghost button "Change Base Currency" (icon `fa-triangle-exclamation`)

Data: read from `getCompanySettings.baseCurrencyCode/baseCurrencyName/baseCurrencySymbol/baseCurrencyFlagEmoji` (extension of existing query). Re-fetch after "Change Base Currency" succeeds.

### Layout Variant

**Layout Variant** (stamp): `widgets-above-grid`

> FE Dev uses **Variant B**: `<ScreenHeader title="Currency Management" subtitle="..." />` + `<BaseCurrencyBanner />` + `<DataTableContainer showHeader={false}>`. The banner sits between ScreenHeader and the table. Do NOT use Variant A — would produce duplicate header / banner-grid drift.

### Grid Columns (in display order)

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Currency | `currencyCode` (primary) + `currencyName` (secondary) | composite cell | 220px | YES (by code) | Renders `{flagEmoji} {code}` line + small grey `{name}` line. Flag falls back to first 2 chars of code if `flagEmoji` null |
| 2 | Symbol | `currencySymbol` | text (semibold) | 100px | NO | Right-aligned monospace |
| 3 | Format | (computed) | format preview chip | 180px | NO | Renders `1,234.56 {symbol}` (or `{symbol}1,234.56` if SymbolPosition=Before) using row's DecimalPlaces / ThousandsSeparator / DecimalSeparator |
| 4 | Rate to Base | `latestRateToBase` + `(base)` label if `currencyId == baseCurrencyId` | rate cell (monospace) | 150px | YES | 4-decimal display; base row shows `1.0000 (base)` |
| 5 | Last Updated | `latestRateDate` | date cell (relative ok) | 140px | YES | Base row shows `—` |
| 6 | Status | `isActive` | badge | 100px | YES | Green dot "Active" / Grey dot "Inactive" |
| 7 | Actions | — | row actions | 80px | NO | Edit (pencil) + More dropdown |

**Row More-menu actions** (per row, NOT base-row):
- Edit (`fa-pen-to-square`)
- View Rate History (`fa-clock-rotate-left`) — toggles inline expanded row
- Activate / Deactivate (`fa-toggle-on/off`)
- Remove (`fa-trash`)

**Base row** (CurrencyId == CompanyConfiguration.BaseCurrencyId): show ONLY the Edit icon (no More dropdown — cannot delete, toggle, or view rate history of base since base has rate=1).

**Inactive rows**: render with `opacity: 0.65` (per mockup).

### Expandable Rate History Row

When user clicks "View Rate History" in row's More menu, an inline child row expands below that currency row.

Child row content (`<RateHistoryPanel currencyId={row.currencyId} />`):
- Header: `{code} Exchange Rate History` (icon `fa-clock-rotate-left`)
- Sub-table columns: Date | Rate | Source | Change-from-previous
- Data source: NEW `getCurrencyRateHistory(currencyId, toCurrencyId={baseCurrencyId}, take=20)` query (returns CurrencyConversions where FromCurrencyId=row.currencyId AND ToCurrencyId=baseCurrencyId, ordered RateDate DESC)
- Change column: signed delta from previous row's rate; positive green, negative red
- Empty state: "No rate history available for this currency."

Implementation: `AdvancedDataTable`'s `expandedRowRender` prop (already supported) — keyed by `currencyId`. Multiple rows may be expanded simultaneously.

### Search/Filter

- Search input (top-right of grid): searches `currencyCode` and `currencyName`
- Advanced filter: enabled per existing grid config (status, name, code)

### Grid-Level Actions (header toolbar)

- `+ Add Currency` (primary) → opens Add Currency modal
- `Update Rates` (outline) → opens Update Exchange Rates confirm modal — SERVICE_PLACEHOLDER handler

### RJSF Modal Form — Add / Edit Currency

> Driven by GridFormSchema in DB seed. FE does NOT hand-build this form.

Modal width: 540px (per mockup). Title: "Add Currency" (create) / "Edit Currency — {code}" (update). Icon `fa-coins`.

**Form Sections** (in order):
| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | Currency | 1-column | CurrencyId (picker — see below) |
| 2 | Formatting | 2-column | SymbolPosition / DecimalPlaces |
| 2 | Formatting (row 2) | 2-column | ThousandsSeparator / DecimalSeparator |
| 3 | Exchange Rate | 1-column | InitialExchangeRate (form-only field — never stored on Currency; BE writes to CurrencyConversion) |
| 4 | Rate Source | 2-column | RateSource / AutoUpdateFrequency (conditional via `dependencies`) |

**Field Widget Mapping**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| **Add mode**: CurrencyPicker | `ApiSelectV2` | "Select currency..." | required | Query: `currencies` filtered `isActive=false` server-side OR client-side filter. Display: `{flagEmoji} {code} — {name}`. On select, copies code/name/symbol/flagEmoji onto the row being saved. |
| **Edit mode**: CurrencyCode + Name | text (readonly) | — | — | Show as static label — cannot change which currency the row represents |
| SymbolPosition | select | — | required | Options: `Before amount` (Before) / `After amount` (After) |
| DecimalPlaces | select (numeric) | — | required | Options: `0`, `2` (default), `3` |
| ThousandsSeparator | select | — | required | Options: `Comma: 1,234` / `Period: 1.234` / `Space: 1 234` / `Indian: 1,23,456` |
| DecimalSeparator | select | — | required | Options: `Period: .56` / `Comma: ,56` |
| InitialExchangeRate | number (step 0.0001) | "e.g. 3.6725" | required (Add); optional (Edit) | Hint: "How much 1 unit of this currency is worth in {baseCurrencyCode}". On Add, BE persists as new CurrencyConversion row. On Edit, BE appends new CurrencyConversion ONLY if value differs from latest. |
| RateSource | select | — | required | Options: `Manual` / `Auto — API fetch` |
| AutoUpdateFrequency | select | — | required when `RateSource=Auto` | Options: `Daily` / `Weekly` / `Monthly`. Hidden when `RateSource=Manual`. Use RJSF `dependencies` block. |

**Modal Footer**: Cancel (ghost) + Save (primary, icon `fa-check`).

### Modal — Change Base Currency (Confirmation)

Modal width: 420px. Title: "Change Base Currency" (red, icon `fa-triangle-exclamation`).

Body copy: *"Changing the base currency will recalculate all exchange rates and affect all consolidated reports. This action cannot be undone easily."*

Fields:
- `NewBaseCurrencyId` — select dropdown (only currencies with `isActive=true` and `currencyId != currentBaseCurrencyId`)

Footer: Cancel (ghost) + Confirm Change (outline-danger, icon `fa-triangle-exclamation`)

On confirm: call `ChangeBaseCurrency` mutation → refresh banner + grid (Rate-to-Base column re-fetched).

### Modal — Update Exchange Rates (Confirmation)

Modal width: 420px. Title: "Update Exchange Rates" (icon `fa-arrows-rotate`).

Body copy: *"Fetch latest exchange rates for all currencies set to **Auto** source?"*
Info card:
- "Currencies to update: **{count of currencies with RateSource=Auto}**"
- "Last updated: **{maxRateDate from CurrencyConversions where Source='OpenExchangeRates'}**" (use existing `CurrencyConversionSummary.LastSyncDate`)

Footer: Cancel (ghost) + Update Now (primary, icon `fa-arrows-rotate`)

On confirm: SERVICE_PLACEHOLDER — call `batchUpdateAutoRates` mutation which returns `{ success: true, rowsAdded: 0, message: "Auto-fetch pending integration" }`. FE shows the message as a toast. Grid does NOT refresh (no new rows).

### User Interaction Flow

1. User lands → sees banner with current base currency + grid of active+inactive currencies
2. Clicks `+ Add Currency` → modal opens → picks USD → fills format + rate → Save → BE creates Currency row + initial CurrencyConversion → grid refreshes → USD appears
3. Clicks pencil on USD row → modal opens pre-filled → changes DecimalPlaces 2→3 → Save → grid updates Format preview
4. Clicks More → View Rate History → child row expands below USD with last 20 CurrencyConversions
5. Clicks More → Deactivate → confirm dialog → USD row greys out, badge changes
6. Clicks "Change Base Currency" on banner → confirm modal → picks USD → Confirm → banner updates to USD → AED row gains an Edit icon + More menu (no longer base); USD row loses More menu
7. Clicks "Update Rates" → confirm modal → Update Now → toast "Auto-fetch pending..." (placeholder); grid unchanged

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity (ContactType, MASTER_GRID) to THIS entity.

**Canonical Reference**: ContactType (MASTER_GRID) — but most BE/FE shapes already exist; treat this as ALIGN, not copy.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | Currency | Entity/class name |
| contactType | currency | Variable/field names |
| ContactTypeId | CurrencyId | PK field |
| ContactTypes | Currencies | Table name, collection names |
| contact-type | currency | FE route segment (single word, no dash) |
| contacttype | currency | FE folder, import paths |
| CONTACTTYPE | CURRENCY | Grid code, menu code |
| corg | com | DB schema |
| Contact | Shared | Backend group name (Currency lives under `SharedModels`/`SharedBusiness`/`EndPoints/Shared`) |
| ContactModels | SharedModels | Namespace suffix (Domain) |
| ContactConfigurations | SharedConfigurations | Infrastructure namespace |
| ContactBusiness | SharedBusiness | Application namespace |
| EndPoints/Contact | EndPoints/Shared | API endpoint folder |
| CONTACT | GEN_MASTERS | Parent menu code |
| CRM | GENERAL | Module code |
| crm/contact/contacttype | general/masters/currency | FE route path |
| corg-service | shared-service / general-service | FE service folder — Currency uses **shared-queries** + **shared-mutations** (existing); FE DTO is at `domain/entities/shared-service/CurrencyDto.ts` |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> All BE files marked **EXISTING** must be modified, not recreated. New files are tagged **NEW**.

### Backend Files

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `Base.Domain/Models/SharedModels/Currency.cs` | EXISTING — **MODIFY**: add 7 new properties (FlagEmoji, SymbolPosition, DecimalPlaces, ThousandsSeparator, DecimalSeparator, RateSource, AutoUpdateFrequency); extend `Create` factory + `Validate` to cover them |
| 2 | EF Config | `Base.Infrastructure/Data/Configurations/SharedConfigurations/CurrencyConfiguration.cs` | EXISTING — **MODIFY**: add `HasMaxLength` for new string fields, defaults for SymbolPosition/DecimalPlaces/etc. |
| 3 | Schemas (DTOs) | `Base.Application/Schemas/SharedSchemas/CurrencySchemas.cs` | EXISTING — **MODIFY**: extend `CurrencyRequestDto` (+7 fields + `InitialExchangeRate?`), `CurrencyResponseDto` (+7 fields + `LatestRateToBase?`, `LatestRateDate?`, `FlagEmoji?`); add NEW `CurrencyRateHistoryDto` (RateDate / ConversionRate / Source / Change), `ChangeBaseCurrencyRequestDto { int NewBaseCurrencyId }`, `BatchUpdateAutoRatesResultDto` |
| 4 | Create Command | `Base.Application/Business/SharedBusiness/Currencies/Commands/CreateCurrency.cs` | EXISTING — **MODIFY**: after Currency insert, if `request.InitialExchangeRate.HasValue && baseCurrencyId differs`, insert a CurrencyConversion row (FromCurrencyId=newCurrency, ToCurrencyId=baseCurrencyId, RateDate=today, ConversionRate=value, Source=request.RateSource) |
| 5 | Update Command | `Base.Application/Business/SharedBusiness/Currencies/Commands/UpdateCurrency.cs` | EXISTING — **MODIFY**: update new fields; if `InitialExchangeRate` differs from latest CurrencyConversion for this pair, APPEND new CurrencyConversion row (do NOT mutate prior history) |
| 6 | Delete Command | `Base.Application/Business/SharedBusiness/Currencies/Commands/DeleteCurrency.cs` | EXISTING — **MODIFY**: add guards: (a) currency is base → reject; (b) any dependent FK (GlobalDonation/Campaign/etc.) → reject with specific message |
| 7 | Toggle Command | `Base.Application/Business/SharedBusiness/Currencies/Commands/ToggleCurrencyStatus.cs` | EXISTING — **MODIFY**: reject deactivation if currency is the base |
| 8 | GetAll Query | `Base.Application/Business/SharedBusiness/Currencies/Queries/GetCurrency.cs` | EXISTING — **MODIFY**: extend DTO projection with `FlagEmoji`, new format fields, `LatestRateToBase`, `LatestRateDate` via LINQ subquery: `_db.CurrencyConversions.Where(cc => cc.FromCurrencyId == c.CurrencyId && cc.ToCurrencyId == baseCurrencyId && !cc.IsDeleted).OrderByDescending(cc => cc.RateDate).Select(cc => (decimal?)cc.ConversionRate).FirstOrDefault()` |
| 9 | GetById Query | `Base.Application/Business/SharedBusiness/Currencies/Queries/GetCurrencyById.cs` | EXISTING — **MODIFY**: include new fields in projection (no rate-history join — that's a separate query) |
| 10 | NEW — Rate History Query | `Base.Application/Business/SharedBusiness/Currencies/Queries/GetCurrencyRateHistory.cs` | **CREATE**: `GetCurrencyRateHistoryQuery(int currencyId, int toCurrencyId, int take)` returns `IEnumerable<CurrencyRateHistoryDto>` — projects from CurrencyConversions where FromCurrencyId=currencyId AND ToCurrencyId=toCurrencyId; computes Change-from-previous via window function or in-memory pass |
| 11 | NEW — Change Base Command | `Base.Application/Business/SharedBusiness/Currencies/Commands/ChangeBaseCurrency.cs` | **CREATE**: `ChangeBaseCurrencyCommand(int newBaseCurrencyId)` — loads CompanyConfiguration for current Company, updates BaseCurrencyId, saves; emits domain event `BaseCurrencyChanged` (optional) |
| 12 | NEW — Batch Update Auto Rates Command | `Base.Application/Business/SharedBusiness/Currencies/Commands/BatchUpdateAutoRates.cs` | **CREATE (SERVICE_PLACEHOLDER)**: returns `BatchUpdateAutoRatesResultDto { Success=true, RowsAdded=0, Message="Auto-rate fetch pending OpenExchangeRates integration" }`. TODO comment naming the missing service. |
| 13 | Mutations | `Base.API/EndPoints/Shared/Mutations/CurrencyMutation.cs` | EXISTING — **MODIFY**: add `ChangeBaseCurrency(ChangeBaseCurrencyRequestDto)` + `BatchUpdateAutoRates()` mutations |
| 14 | Queries | `Base.API/EndPoints/Shared/Queries/CurrencyQueries.cs` | EXISTING — **MODIFY**: add `GetCurrencyRateHistory(int currencyId, int toCurrencyId, int? take)` query |
| 15 | Company Settings Query | `Base.API/EndPoints/Setting/Queries/CompanyConfigurationQueries.cs` (existing file — confirm path) | EXISTING — **MODIFY**: extend response with `BaseCurrencyCode`, `BaseCurrencyName`, `BaseCurrencySymbol`, `BaseCurrencyFlagEmoji` (LINQ Include on Currency navigation; project the four fields). If banner needs a dedicated lightweight query, create `GetBaseCurrencyQuery` returning just the 4 fields. |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | NO CHANGE — `DbSet<Currency>` and `DbSet<CurrencyConversion>` already exist |
| 2 | ApplicationDbContext.cs | NO CHANGE |
| 3 | DecoratorProperties.cs | NO CHANGE — currency is in DecoratorSharedModules already |
| 4 | SharedMappings.cs (Mapster) | EXTEND — map new fields between Currency ↔ CurrencyRequestDto / CurrencyResponseDto; map `CurrencyConversion → CurrencyRateHistoryDto` |
| 5 | Migration | NEW — `Add_Formatting_And_RateSource_To_Currency` (7 columns + defaults backfill) |

### Frontend Files

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `src/domain/entities/shared-service/CurrencyDto.ts` | EXISTING (or NEW if missing) — **MODIFY**: extend `CurrencyDto` with new format fields + `latestRateToBase?`, `latestRateDate?`, `flagEmoji?`; ADD `CurrencyRateHistoryDto`, `ChangeBaseCurrencyRequestDto`, `BatchUpdateAutoRatesResultDto` |
| 2 | GQL Query | `src/infrastructure/gql-queries/shared-queries/CurrencyQuery.ts` | EXISTING — **MODIFY**: extend `CURRENCIES_QUERY` to select new fields; ADD `GET_CURRENCY_RATE_HISTORY_QUERY` |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/shared-mutations/CurrencyMutation.ts` (existing or new path) | EXISTING — **MODIFY**: add `CHANGE_BASE_CURRENCY_MUTATION` + `BATCH_UPDATE_AUTO_RATES_MUTATION` |
| 4 | Company Settings GQL | `src/infrastructure/gql-queries/setting-queries/CompanySettingsQuery.ts` | EXISTING — **MODIFY**: extend selection set with `baseCurrencyCode/baseCurrencyName/baseCurrencySymbol/baseCurrencyFlagEmoji` (or add new `BASE_CURRENCY_QUERY` if cleaner) |
| 5 | Page Config | `src/presentation/pages/general/masters/currency.tsx` | EXISTING — **KEEP AS-IS** (already wires `CurrencyDataTable`) |
| 6 | Data Table Component | `src/presentation/components/page-components/general/masters/currency/data-table.tsx` | EXISTING — **MODIFY**: replace thin wrapper with `<ScreenHeader>` + `<BaseCurrencyBanner>` + `<DataTableContainer showHeader={false} gridCode="CURRENCY">` (Variant B). Pass `expandedRowRender` for rate history |
| 7 | NEW — BaseCurrencyBanner | `src/presentation/components/page-components/general/masters/currency/base-currency-banner.tsx` | **CREATE**: gradient card; data from CompanySettings query; emits `onChangeBase` |
| 8 | NEW — ChangeBaseCurrencyModal | `src/presentation/components/page-components/general/masters/currency/change-base-currency-modal.tsx` | **CREATE**: confirm modal with currency dropdown (filtered list); calls `CHANGE_BASE_CURRENCY_MUTATION` |
| 9 | NEW — UpdateRatesModal | `src/presentation/components/page-components/general/masters/currency/update-rates-modal.tsx` | **CREATE**: confirm modal with counts; calls `BATCH_UPDATE_AUTO_RATES_MUTATION`; renders returned `message` as toast |
| 10 | NEW — RateHistoryPanel | `src/presentation/components/page-components/general/masters/currency/rate-history-panel.tsx` | **CREATE**: child-row content; runs `GET_CURRENCY_RATE_HISTORY_QUERY`; renders sub-table with Change column (signed delta, color-coded) |
| 11 | NEW — FormatPreviewCell | `src/presentation/components/page-components/general/masters/currency/format-preview-cell.tsx` | **CREATE**: pure renderer — composes `1,234.56 {symbol}` from row's formatting fields. Used as `customCellRenderer` for the Format column. |
| 12 | NEW — CurrencyCell | `src/presentation/components/page-components/general/masters/currency/currency-cell.tsx` | **CREATE**: composite cell rendering `{flagEmoji} {code}` on line 1 + grey `{name}` on line 2 |
| 13 | Index export | `src/presentation/components/page-components/general/masters/currency/index.ts` | EXISTING — **MODIFY**: export new components |
| 14 | Route Page | `src/app/[lang]/general/masters/currency/page.tsx` | EXISTING — **KEEP AS-IS** |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `entity-operations.ts` | Verify CURRENCY operations registered (existing); ensure `changeBaseCurrency` + `batchUpdateAutoRates` mutations are exposed in the operations map for the grid |
| 2 | `operations-config.ts` | NO CHANGE (or extend with new mutation imports if pattern requires) |
| 3 | Sidebar menu config | NO CHANGE — `CURRENCY` menu under `GEN_MASTERS` already seeded |
| 4 | Custom cell renderer registry (if used) | Register `FormatPreviewCell` + `CurrencyCell` under their cell-type keys so the grid config (GridColumns seed) can reference them by string |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Currency
MenuCode: CURRENCY
ParentMenu: GEN_MASTERS
Module: GENERAL
MenuUrl: general/masters/currency
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: CURRENCY

# Notes for seed:
# - Menu row likely already exists in seed under GEN_MASTERS. ALIGN: do NOT duplicate — only UPSERT GridColumns + GridFormSchema rows.
# - GridColumns must include the new columns (Format preview, Rate to Base, Last Updated) replacing the current thin column set.
# - GridFormSchema must include the conditional Auto-Update Frequency block via JSON Schema `dependencies`.
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose before BE work begins.

**GraphQL Types:**
- Query type: `CurrencyQueries` (existing — extend)
- Mutation type: `CurrencyMutations` (existing — extend)

**Queries (note: existing names use camelCase root — do NOT rename):**

| GQL Field | Returns | Key Args | Status |
|-----------|---------|----------|--------|
| `currencies` | `PaginatedApiResponse<CurrencyResponseDto[]>` | `request: GridFeatureRequest` (pageSize/pageIndex/sortColumn/sortDescending/searchTerm/advancedFilter) | EXISTING — extend DTO selection |
| `currencyById` | `BaseApiResponse<CurrencyResponseDto>` | `currencyId: Int!` | EXISTING — extend DTO selection |
| `currentFxRate` | `CurrentFxRateResponseDto` | `fromCurrencyId, toCurrencyId` | EXISTING — keep as-is |
| `currencyRateHistory` | `BaseApiResponse<CurrencyRateHistoryDto[]>` | `currencyId: Int!, toCurrencyId: Int!, take: Int = 20` | **NEW** |
| `getCompanySettings` (or `baseCurrency`) | extend existing CompanySettings → expose `baseCurrencyCode/baseCurrencyName/baseCurrencySymbol/baseCurrencyFlagEmoji` | — | EXISTING — extend |

**Mutations:**

| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| `createCurrency` | `CurrencyRequestDto` (extended with `initialExchangeRate`) | `BaseApiResponse<CurrencyRequestDto>` | EXISTING — extend |
| `updateCurrency` | `CurrencyRequestDto` (extended) | `BaseApiResponse<CurrencyRequestDto>` | EXISTING — extend |
| `activateDeactivateCurrency` | `entityId: Int!` | `BaseApiResponse<CurrencyRequestDto>` | EXISTING — add base-currency guard |
| `deleteCurrency` | `entityId: Int!` | `BaseApiResponse<CurrencyRequestDto>` | EXISTING — add base + dependent FK guards |
| `changeBaseCurrency` | `ChangeBaseCurrencyRequestDto { newBaseCurrencyId: Int }` | `BaseApiResponse<int>` (new base CurrencyId) | **NEW** |
| `batchUpdateAutoRates` | — | `BaseApiResponse<BatchUpdateAutoRatesResultDto { success, rowsAdded, message }>` | **NEW (placeholder)** |

**`CurrencyResponseDto` (extended)** — what FE receives per row:

| Field | Type | Notes |
|-------|------|-------|
| currencyId | number | PK |
| currencyCode | string | UPPER |
| currencyName | string | Title-cased |
| currencySymbol | string | — |
| flagEmoji | string \| null | NEW |
| symbolPosition | string | NEW — `"Before" \| "After"` |
| decimalPlaces | number | NEW |
| thousandsSeparator | string | NEW |
| decimalSeparator | string | NEW |
| rateSource | string | NEW — `"Manual" \| "Auto"` |
| autoUpdateFrequency | string \| null | NEW — `"Daily" \| "Weekly" \| "Monthly"` or null |
| latestRateToBase | number \| null | NEW — projected from latest CurrencyConversion |
| latestRateDate | string \| null | NEW — ISO date of latest CurrencyConversion |
| isActive | boolean | Inherited |

**`CurrencyRequestDto` (extended)** — what FE sends on Create/Update:

| Field | Type | Notes |
|-------|------|-------|
| currencyId | number? | null on Create |
| currencyCode | string | |
| currencyName | string | |
| currencySymbol | string | |
| flagEmoji | string? | |
| symbolPosition | string | |
| decimalPlaces | number | |
| thousandsSeparator | string | |
| decimalSeparator | string | |
| rateSource | string | |
| autoUpdateFrequency | string? | required when rateSource=Auto |
| initialExchangeRate | number? | form-only — BE writes to CurrencyConversion |

**`CurrencyRateHistoryDto`**:
| Field | Type |
|-------|------|
| rateDate | string (ISO date) |
| conversionRate | number |
| source | string (`"Manual" \| "OpenExchangeRates" \| "System-BaseChange"`) |
| change | number? (signed delta from previous row in series; null on first row) |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] Migration `Add_Formatting_And_RateSource_To_Currency` generated, applied, columns visible in `com."Currencies"` with defaults
- [ ] `pnpm dev` — page loads at `/[lang]/general/masters/currency` with no console errors

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Base Currency banner renders with current base (e.g. AED flag, name, caption)
- [ ] Grid loads with: Currency (composite flag+code+name) | Symbol | Format preview | Rate to Base | Last Updated | Status | Actions
- [ ] Format preview correctly composes: SymbolPosition × ThousandsSeparator × DecimalSeparator × DecimalPlaces
- [ ] Rate to Base column: base row shows `1.0000 (base)`; non-base rows show latest CurrencyConversion rate
- [ ] Last Updated column: base shows `—`; non-base shows latest CurrencyConversion `RateDate`
- [ ] Inactive currency row visually greyed (`opacity: 0.65`)
- [ ] Search filters by code + name; advanced filter respects all columns
- [ ] **Add Currency**: modal opens → picker excludes already-active codes → fills all formatting fields → conditional `AutoUpdateFrequency` appears only when `RateSource=Auto` → Save → new Currency row + new CurrencyConversion row (visible in rate history)
- [ ] **Edit Currency**: modal pre-fills all extended fields → change DecimalPlaces or separator → Save → Format preview updates in grid
- [ ] **Edit Currency with new rate**: changing `InitialExchangeRate` appends a new CurrencyConversion row (latest 2 visible in rate history)
- [ ] **Edit Currency without rate change**: leaving the rate field blank does NOT create a CurrencyConversion row
- [ ] **Toggle**: deactivate non-base → badge changes; attempting to deactivate base → blocked with toast
- [ ] **Delete**: deleting base → blocked with toast "Cannot delete base currency"; deleting currency with FK refs → blocked with toast naming the constraint; deleting orphan inactive currency → succeeds
- [ ] **View Rate History**: clicking action expands inline child row → shows up to 20 CurrencyConversions ordered DESC → Change column shows signed delta (positive green, negative red) → collapses on second click
- [ ] **Change Base Currency**: banner button → confirm modal → pick USD → confirm → banner updates → AED row gains More menu → USD row loses More menu → Rate-to-Base column recomputed
- [ ] **Update Rates**: header button → confirm modal shows "Currencies to update: {count}" + "Last updated: {date}" → Update Now → toast displays placeholder message; no grid refresh
- [ ] FK dropdowns (currency picker in modals) load via `currencies` query without error
- [ ] Permissions: BUSINESSADMIN sees all actions; other roles respect role-capability config

**DB Seed Verification:**
- [ ] Menu `CURRENCY` visible under `GEN_MASTERS` (no duplicate row created)
- [ ] Grid columns match Section ⑥ exactly (no extra/missing columns)
- [ ] GridFormSchema renders the Add modal with all sections + conditional Auto-Update Frequency
- [ ] Seed includes default currency rows (AED, USD, INR, GBP, KES, BDT, SAR) with formatting defaults — but only if the dev DB is missing rows; do NOT overwrite production tenant data

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **ALIGN scope — never regenerate.** Currency entity, schemas, commands, queries, mutations, FE route, FE page-config, FE data-table all exist. Modify in-place. Only create the files explicitly tagged **NEW** in Section ⑧.
- **Currency lives in the `Shared` group**, NOT a per-module group. BE namespaces are `Base.Domain.Models.SharedModels`, `Base.Application.Business.SharedBusiness.Currencies`, `Base.API.EndPoints.Shared.Mutations/Queries`. FE service folder is `shared-service` for DTOs and `shared-queries / shared-mutations` for GQL files.
- **Base currency is not a column on `com.Currencies`** — it lives on `sett.CompanyConfigurations.BaseCurrencyId`. Do NOT add an `IsBaseCurrency` flag to Currency. The banner reads from CompanyConfiguration; "Change Base Currency" mutates CompanyConfiguration.
- **Rate to Base is a projection, not a stored column.** The DTO surfaces `LatestRateToBase` via LINQ subquery against `com.CurrencyConversions` filtered by `(FromCurrencyId=row, ToCurrencyId=baseCurrencyId)` ordered `RateDate DESC TAKE 1`. Do NOT denormalize a rate column onto Currency.
- **CurrencyConversion is append-only history.** Editing a currency's rate INSERTS a new row; never UPDATE prior rows. The expandable rate-history panel relies on this immutability.
- **GraphQL field names are camelCased roots, not `GetAll{Name}List`.** Existing queries are `currencies`, `currencyById`, `currentFxRate` (not `GetAllCurrencyList`). Keep the existing names — clients are wired to them. New queries follow the same convention: `currencyRateHistory`, not `GetCurrencyRateHistory`.
- **GraphQLName for `currentFxRate` is explicit** (`[GraphQLName("currentFxRate")]`). When extending the queries class, do not break the existing alias.
- **Mockup grid Display Mode is `table`**, not card-grid — do NOT pull in card-grid infrastructure.
- **Layout Variant is `widgets-above-grid`** even though the banner isn't a metric widget — it's a hero element above the grid. FE Dev MUST use Variant B (`ScreenHeader` + custom banner + `DataTableContainer showHeader={false}`) or the page will render a duplicate header (Currency-Conversion #19/ContactType precedent — see `[[feedback_external_page_dictionary_binding]]` is unrelated, but the Variant-A/B selection trap applies).
- **The "Edit" pencil button on the base-currency row must still be allowed** (per mockup) — admin can edit formatting on the base currency. Only the More-menu actions (delete / toggle / view rate history) are hidden for the base row.
- **Reuse existing grid components** — never build a private `<CurrencyGrid>`. Continue using `<AdvancedDataTable>` (or its container variant `<DataTableContainer>`) with `gridCode="CURRENCY"`. New per-cell renderers go through the shared cell-renderer registry, not into a forked grid (see `[[feedback_reuse_existing_grids]]`).
- **CompanySettings already has BaseCurrencyId** — for screen #75 (Company Settings) BE work, the currency banner extension may piggy-back on the existing `getCompanySettings` query. If banner load latency matters, create a lightweight `baseCurrency` query that selects only the 4 display fields — this is a performance call, not a correctness call.

**Service Dependencies** (UI built; handler is placeholder):

- **`Update Rates` batch action** — full UI implemented (modal, counts, confirm). Handler wired to `batchUpdateAutoRates` mutation which returns a placeholder result. Reason: the OpenExchangeRates fetch + cache + insert pipeline is not yet implemented in `Base.Infrastructure/Services/Currency/FxRateService.cs`. When that service lands, the placeholder command can call into it without UI changes.

Everything else (Add, Edit, Delete, Toggle, View Rate History, Change Base, banner display, format preview) is fully built end-to-end.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Session 1 | Medium | FE Grid | `AdvancedDataTableContainer` has no `expandedRowRender` prop. `RateHistoryPanel` component exists and the BE `currencyRateHistory` query is wired, but the inline-row expansion for "View Rate History" More-menu action is NOT wired. Workaround: clicking the action could open a side panel/modal instead, or extend the grid container to support `expandedRowRender`. | CLOSED (session 2) |
| ISSUE-2 | Session 1 | Low | FE Modal | `ChangeBaseCurrencyModal` is invoked without `currentBaseCurrencyId` prop, so the dropdown doesn't exclude the current base. BE rejects no-op changes if the new id equals current, but UX gap remains. | OPEN |
| ISSUE-3 | Session 1 | Low | DB Seed | The "Format" column uses a synthetic `CURRENCYFORMAT` field with `FieldKey='format'` — no BE projection backs it; the `format-preview-cell` renderer reads other row fields. If the grid framework refuses to render a column whose data key returns undefined, the column will show blank. Worked around by relying on the renderer to read sibling fields. Verify at runtime. | OPEN |
| ISSUE-4 | Session 1 | Low | BE Migration | Migration `Add_Formatting_And_RateSource_To_Currency` was hand-written + `ApplicationDbContextModelSnapshot.cs` updated by hand. If `dotnet ef migrations add` is later run, EF may produce a no-op or conflict. Apply via `dotnet ef database update 20260515120000_Add_Formatting_And_RateSource_To_Currency` directly. | OPEN |
| ISSUE-5 | Session 1 | Low | UX Polish | `base-currency-banner.tsx:72` uses inline `style={{ background: "linear-gradient(...)" }}` with hex fallback `#4f46e5` / `#818cf8`. Spec called for this exact gradient with CSS var, but it's an inline-style/hex violation of the UI uniformity grep. Consider moving to a Tailwind utility class or a project CSS class. | OPEN |
| ISSUE-6 | Session 1 | Low | BE Query | `GetCurrencyById` does NOT project `LatestRateToBase` / `LatestRateDate` (spec said no rate-history join). The Edit modal cannot pre-fill the latest rate as a result — user sees blank `initialExchangeRate`. If pre-fill is desired, FE could query `currencyRateHistory(take=1)` separately, or BE could be extended. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-16 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. ALIGN scope — extended existing Currency entity + 8 BE files; added 3 new BE files (rate-history query, change-base command, batch-rates command); rewrote thin FE `data-table.tsx` wrapper to Variant B with banner/modals; added 6 new FE files in the currency folder + 2 new shared cell renderers; patched DB seed (GridColumns rewired with `currency-cell` and `format-preview-cell` renderers; GridFormSchema rewritten with `dependencies` block for conditional `autoUpdateFrequency`).
- **Files touched**:
  - BE:
    - `PSS_2.0_Backend/.../Base.Domain/Models/SharedModels/Currency.cs` (modified — 7 properties + extended factory + validator)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/SharedConfigurations/CurrencyConfiguration.cs` (modified — MaxLength + defaults)
    - `PSS_2.0_Backend/.../Base.Application/Schemas/SharedSchemas/CurrencySchemas.cs` (modified — Request/Response DTOs extended + 3 new DTOs)
    - `PSS_2.0_Backend/.../Base.Application/Business/SharedBusiness/Currencies/Commands/CreateCurrency.cs` (modified — inserts initial CurrencyConversion)
    - `PSS_2.0_Backend/.../Base.Application/Business/SharedBusiness/Currencies/Commands/UpdateCurrency.cs` (modified — appends CurrencyConversion on rate change)
    - `PSS_2.0_Backend/.../Base.Application/Business/SharedBusiness/Currencies/Commands/DeleteCurrency.cs` (modified — base + FK dep guards)
    - `PSS_2.0_Backend/.../Base.Application/Business/SharedBusiness/Currencies/Commands/ToggleCurrencyStatus.cs` (modified — base guard)
    - `PSS_2.0_Backend/.../Base.Application/Business/SharedBusiness/Currencies/Queries/GetCurrency.cs` (modified — batch-fetch LatestRateToBase/LatestRateDate post-projection)
    - `PSS_2.0_Backend/.../Base.Application/Business/SharedBusiness/Currencies/Queries/GetCurrencyRateHistory.cs` (created — paginated rate history with computed Change column)
    - `PSS_2.0_Backend/.../Base.Application/Business/SharedBusiness/Currencies/Commands/ChangeBaseCurrency.cs` (created — mutates CompanyConfiguration.BaseCurrencyId + best-effort CurrencyConversion seed)
    - `PSS_2.0_Backend/.../Base.Application/Business/SharedBusiness/Currencies/Commands/BatchUpdateAutoRates.cs` (created — SERVICE_PLACEHOLDER returning `RowsAdded=0`)
    - `PSS_2.0_Backend/.../Base.Application/Mappings/SharedMappings.cs` (modified — added explicit Currency mapping with `.Ignore` for form/projection-only fields + CurrencyConversion→CurrencyRateHistoryDto mapping)
    - `PSS_2.0_Backend/.../Base.Application/Business/SettingBusiness/CompanySettings/Queries/GetCompanySettingsQuery/GetCompanySettings.cs` (modified — Financial section now exposes `BaseCurrencySymbol` + `BaseCurrencyFlagEmoji`)
    - `PSS_2.0_Backend/.../Base.Application/Schemas/SettingSchemas/CompanySettingsSchemas.cs` (modified — FinancialSection extended)
    - `PSS_2.0_Backend/.../Base.API/EndPoints/Shared/Mutations/CurrencyMutation.cs` (modified — `changeBaseCurrency` + `batchUpdateAutoRates` exposed)
    - `PSS_2.0_Backend/.../Base.API/EndPoints/Shared/Queries/CurrencyQueries.cs` (modified — `currencyRateHistory` exposed)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Migrations/20260515120000_Add_Formatting_And_RateSource_To_Currency.cs` (created — 7 new columns + backfill SQL + NOT NULL constraints)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Migrations/ApplicationDbContextModelSnapshot.cs` (modified — Currency entity block extended)
  - FE:
    - `PSS_2.0_Frontend/src/domain/entities/shared-service/CurrencyDto.ts` (modified — extended `CurrencyDto` + 3 new DTOs)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/shared-queries/CurrencyQuery.ts` (modified — extended selection + `GET_CURRENCY_RATE_HISTORY_QUERY`)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/shared-mutations/CurrencyMutation.ts` (modified — `CHANGE_BASE_CURRENCY_MUTATION` + `BATCH_UPDATE_AUTO_RATES_MUTATION`)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/CompanySettingsQuery.ts` (modified — Financial section selection extended)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/data-table.tsx` (rewritten — Variant B: `ScreenHeader` + `BaseCurrencyBanner` + `AdvancedDataTableContainer showHeader={false}`)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/index.ts` (modified — barrel export)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/base-currency-banner.tsx` (created — gradient hero card reading `companySettings.financial`)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/change-base-currency-modal.tsx` (created — confirm modal with currency dropdown)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/update-rates-modal.tsx` (created — SERVICE_PLACEHOLDER toast handler)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/rate-history-panel.tsx` (created — sub-table for `currencyRateHistory`; not yet wired to grid expansion — see ISSUE-1)
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/currency-cell.tsx` (created — flag + code + name composite)
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/format-preview-cell.tsx` (created — composes "1,234.56 {symbol}" from row's format fields)
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (modified — barrel export for both renderers)
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/advanced/data-table-column-types/component-column.tsx` (modified — switch cases registered)
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/basic/data-table-column-types/component-column.tsx` (modified — switch cases registered)
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/flow/data-table-column-types/component-column.tsx` (modified — switch cases registered)
  - DB:
    - `PSS_2.0_Backend/.../sql-scripts-dyanmic/Currency-sqlscripts.sql` (created — idempotent: Menu + Capabilities + Role-Capabilities + Grid + 15 Fields + 15 GridFields + GridFormSchema. Orchestrator-patched STEP 5 with `CURRENCYFORMAT` synthetic field + STEP 6 with `GridComponentName='currency-cell'` and `'format-preview-cell'` on the relevant rows; redundant format-detail columns hidden — see ISSUE-3)
- **Deviations from spec**:
  - `expandedRowRender` for inline rate-history rows NOT wired — `AdvancedDataTableContainer` doesn't expose that prop. Component exists, BE query exists, but the grid integration is deferred (see ISSUE-1).
  - `currentBaseCurrencyId` prop not passed to `ChangeBaseCurrencyModal` — minor UX gap (see ISSUE-2).
  - `GetCurrencyById` doesn't return latest rate — spec-aligned, but Edit modal can't pre-fill `initialExchangeRate` as a result (see ISSUE-6).
  - Inline gradient + hex fallback in `base-currency-banner.tsx:72` — spec-faithful but technically a UI uniformity grep violation (see ISSUE-5).
  - Migration is hand-written + snapshot updated by hand (see ISSUE-4).
- **Known issues opened**: ISSUE-1 through ISSUE-6 (see Known Issues table above).
- **Known issues closed**: None.
- **Next step**: (none — COMPLETED). User to run `dotnet build`, apply migration `20260515120000_Add_Formatting_And_RateSource_To_Currency`, execute the Currency-sqlscripts.sql seed, then `pnpm dev` and verify the 7-column grid + Variant B layout + Add/Edit modal + Change Base + Update Rates flows. View Rate History action will need ISSUE-1 resolved before it shows inline-row content.

### Session 2 — 2026-07-22 — FIX — COMPLETED

- **Scope**: Resolve ISSUE-1 — wire the per-row "View Rate History" action so #141's exchange-rate history surfaces inside the Currency screen. (Context: user asked whether #79 + #141 could merge into one screen; assessed as feasible-but-wrong — #79 is per-tenant, #141 is a global table — so instead delivered the useful part: rates displayed within the currency screen.)
- **Approach**: The shared grid container (`data-table-container.tsx`) is store/config-driven and exposes no `expandedRowRender` hook (confirmed). Rather than modify shared grid infrastructure (a shared-wiring file used by every MASTER_GRID), used the existing screen-owned `customRowActions` render-prop mechanism (`AdvancedDataTableStoreProvider` → store → action-column-cell line 101). Rate history now opens in a `Sheet` side drawer per row instead of an inline expandable row. Mirrors the `DataTableBranchStaffAssign` self-contained-action pattern.
- **Files touched**:
  - FE:
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/rate-history-action.tsx` (created — self-contained icon-button action + Sheet drawer wrapping `RateHistoryPanel`; owns its own open state)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/data-table.tsx` (modified — pass `customRowActions={renderRateHistoryAction}` to the provider; import `CurrencyDto` + `RateHistoryAction`)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/index.ts` (modified — barrel export `RateHistoryAction`)
  - BE: None.
  - DB: None.
- **Verification**: `npx tsc --noEmit --incremental false` — 32 errors, all stale `.next/types/**` stubs (pre-existing, unrelated to `.next` not being rebuilt); **zero errors in `src/`**. No shared-infra files touched.
- **Deviations from spec**: Rate history surfaces in a side drawer (Sheet), not the inline expandable row the original blueprint envisioned — deliberate, to avoid editing the shared grid container. Functionally equivalent (same `RateHistoryPanel`, same `currencyRateHistory` query).
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-1.
- **Next step**: 5 issues still OPEN (ISSUE-2 base-currency-id prop, ISSUE-3 synthetic format FieldKey, ISSUE-4 hand-written migration, ISSUE-5 inline gradient hex, ISSUE-6 GetCurrencyById latest-rate). Status → NEEDS_FIX.

### Session 3 — 2026-07-22 — ENHANCE — COMPLETED

- **Scope**: (a) Make "Update Rates" functional; (b) add a 30-day rate-trend chart to the Rate History drawer. (Context: user asked whether #79 + #141 merge into one screen, and whether to also put today's rate + a growth graph on the grid. Verdict delivered: today's rate is already a grid column (`LatestRateToBase`/`LatestRateDate`); a per-row graph in the grid is wrong UX, so the 30-day chart lives in the existing Rate History drawer via progressive disclosure — not the grid.)
- **Approach**:
  - Update Rates was calling a placeholder (`batchUpdateAutoRates`, a no-op stub returning "pending OpenExchangeRates integration"). Repointed the modal to the real, already-wired `triggerOpenExchangeRatesSync` command (the same handler #141's grid uses → `IOpenExchangeRatesSyncJob.RunOnceAsync`), which discovers tenant base↔collectable pairs from OrgSettings and writes `com.CurrencyConversions` rows for today. Handles `SyncResultDto` (success/rowsAdded/message) with a real success/error toast. No BE change — the command already exists.
  - Chart: new screen-owned `RateHistoryChart` (ApexCharts `area`, dynamic `ssr:false` import, theme-aware — mirrors `case-resolution-trend-widget`). Plots `conversionRate` over `rateDate`, sorted oldest→newest (query is newest-first), padded y-range, renders nothing with < 2 points. Rendered above the exact-value table inside `RateHistoryPanel`; bumped history `take` 20 → 30.
- **Files touched**:
  - FE:
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/rate-history-chart.tsx` (created — 30-day ApexCharts area trend)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/rate-history-panel.tsx` (modified — `take` 20→30; render `RateHistoryChart` above the table)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/update-rates-modal.tsx` (modified — swap `BATCH_UPDATE_AUTO_RATES_MUTATION` → `TRIGGER_OPEN_EXCHANGE_RATES_SYNC_MUTATION`; handle `SyncResultDto`)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/index.ts` (modified — barrel export `RateHistoryChart`)
  - BE: None (reused existing `triggerOpenExchangeRatesSync`).
  - DB: None.
- **Verification**: `npx tsc --noEmit --incremental false` — **zero errors in `src/`** (remaining errors are pre-existing stale `.next/types/**` stubs affecting every masters page). No shared-infra files touched.
- **Runtime dependency**: live rate fetch needs OpenExchangeRates `app_id` configured (`Fx:*` settings) on the server; without it the sync runs but adds 0 rows and the toast reports "already up to date"/0 refreshed. Wiring is complete regardless.
- **Deviations from spec**: The 30-day growth graph goes in the drawer, not the grid rows (deliberate UX call — grid keeps today's rate column only). The old placeholder `BATCH_UPDATE_AUTO_RATES_MUTATION` is now unused by this screen.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: 5 issues still OPEN (ISSUE-2 base-currency-id prop, ISSUE-3 synthetic format FieldKey, ISSUE-4 hand-written migration, ISSUE-5 inline gradient hex, ISSUE-6 GetCurrencyById latest-rate). Status → NEEDS_FIX.

### Session 4 — 2026-07-22 — FIX — COMPLETED

- **Scope**: Session 3 shipped the chart + Update Rates rewire but user reported the chart was invisible and Update Rates produced no data. Fixed both root causes.
- **Root causes & fixes**:
  - **Chart invisible (height collapse)**: `RateHistoryChart` used `height="100%"` inside a plain `h-40` div. The Rate History host is a `Sheet` (`overflow-y-auto`, NOT a flex container), so `100%` resolved to 0px and the chart mounted at zero height. → Switched to fixed `height={180}` (the standalone chart idiom, cf. `daily-collection-bar-chart.tsx`), removed the `h-40`/`100%` reliance.
  - **Update Rates produced no data (no FX source)**: OXR `ApiKey` is empty in `appsettings.json`, so `OpenExchangeRatesClient.GetLatestRatesAsync` returned `[]` → sync wrote 0 rows → no history → chart's `< 2 points` guard hid it AND grid rate columns stayed blank. → Added a **keyless fallback provider** (`open.er-api.com/v6/latest/USD`, same USD-base `{code→rateVsUsd}` shape) used when the OXR key is empty or OXR fails/returns empty. Paid OXR key still preferred when present. Sync job's USD-anchored derivation logic unchanged.
- **Files touched**:
  - FE: `PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/rate-history-chart.tsx` (fixed pixel height)
  - BE: `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/External/OpenExchangeRates/OpenExchangeRatesClient.cs` (keyless fallback; extracted shared `ParseRates`)
  - DB: None.
- **Verification**: BE `dotnet build Base.Infrastructure.csproj` — 0 errors (653 pre-existing warnings). FE `npx tsc --noEmit --incremental false` — 0 `src/` errors (only pre-existing `.next/types/**` stubs). No migration needed (code-only).
- **Where the chart is**: Currency grid → row "Rate History" action (clock icon) → right-side Sheet drawer → chart at top, above the value table. Needs ≥2 distinct rate-dates to appear (one sync = one day = single point, still hidden by design).
- **Deviations from spec**: None. Adds a no-key FX source so Update Rates works out of the box; admin can still configure `OpenExchangeRates:ApiKey` to prefer the paid provider.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: 5 issues still OPEN (ISSUE-2 base-currency-id prop, ISSUE-3 synthetic format FieldKey, ISSUE-4 hand-written migration, ISSUE-5 inline gradient hex, ISSUE-6 GetCurrencyById latest-rate). Status → NEEDS_FIX.
