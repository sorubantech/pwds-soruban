---
screen: DonationInKind
registry_id: 7
module: Fundraising
status: COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-19
completed_date: 2026-04-19
last_session_date: 2026-04-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + FORM layout + DETAIL drawer layout)
- [x] Existing code reviewed (11 BE files + 4 FE page-components + DTO/Query/Mutation)
- [x] Business rules + workflow extracted (2-phase: Record DIK → Complete Valuation)
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt §①–④ contain full BA output; orchestrator skipped BA spawn per SavedFilter #27 precedent)
- [x] Solution Resolution complete (prompt §⑤ classifies FLOW + patterns)
- [x] UX Design finalized (FORM + DETAIL drawer layouts specified) (prompt §⑥ blueprint)
- [x] User Approval received (2026-04-19, unchanged CONFIG)
- [x] Backend code generated (3 created: DeleteDonationInKind, ToggleDonationInKind, GetDonationInKindSummary; 7 modified)
- [x] Backend wiring complete (Mutations/Queries endpoints register new GQL fields; DonationMappings Mapster config added)
- [x] Frontend code generated (7 created: page-config, router, index-page Variant B, view-page FORM, dik-detail-drawer, Zustand store, category-badge renderer)
- [x] Frontend wiring complete (DTO/GQL/registries updated, 6 legacy files deleted incl. donationinkindcreate.tsx / donationinkindupdate.tsx / dik-view-page.tsx / dik-update-form.tsx / data-table.tsx / old index.ts barrel)
- [x] DB Seed script generated (PSS_2.0_Backend/.../sql-scripts-dyanmic/DonationInKind-sqlscripts.sql — idempotent menu upsert + legacy DONATIONINKIND{CREATE,UPDATE} cleanup + Grid + 10 FLOW columns; GridFormSchema SKIP)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/donation/donationinkind`
- [ ] Grid loads with columns (Receipt #, Date, Donor, Item Category+icon, Description, Est. Value, Currency, Status, Valuation, Actions)
- [ ] 3 widgets above grid: This Month, Top Category, Pending Valuation
- [ ] Filters: search, Item Category, Date Range, Status, Branch, Amount Range
- [ ] `?mode=new` — empty FORM layout renders (Contact search hero + 5 sections)
- [ ] `?mode=edit&id=X` — FORM layout pre-filled (for Pending records only; Valued records are read-only)
- [ ] Row click on grid → side drawer opens with 6 sections (Donor Info, Item Details, Photos, Bill/Invoice, Valuation, Receipt & Allocation)
- [ ] Grid row "Value" button (pending rows) → opens drawer with inline Complete Valuation sub-form
- [ ] Complete Valuation: payment mode card + (conditional) bank/instrument fields → Save → row refreshes to Valued
- [ ] FK dropdowns load via FormSearchableSelect (Branch, Contact, Currency, ItemCategory-MasterData, ContactSource, PaymentMode, Bank)
- [ ] Summary widgets display correct values after each create/valuation
- [ ] Photos grid renders receipt + valuation-receipt attachments
- [ ] Service placeholders render with toast (Receipt action, Download Receipt PDF, Allocated-To)
- [ ] Old split routes (`donationinkindcreate`, `donationinkindupdate`) no longer resolve
- [ ] DB Seed — menu visible under CRM_DONATION

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: DonationInKind (In-Kind Donations)
Module: Fundraising (CRM)
Schema: fund
Group: DonationModels

Business: In-Kind Donations capture non-cash gifts received by the NGO (medical supplies, equipment, food, clothing, etc.) along with a donor-provided valuation (bill/invoice) and an internal finance valuation. Finance staff record each gift with donor, item category, description, estimated value, and photographs; a receipt is issued. Each record has two workflow states — **Pending Valuation** (item received, awaiting internal assessment) and **Valued** (finance has verified the fair-market value and attached a valuation receipt). Valuation is a second-pass step that captures payment-mode metadata (used when the donor converts an in-kind pledge into an instrument-backed gift) and writes back the official valuation amount + valuation receipt. The screen also drives reporting: monthly totals, pending-valuation count, and top-donated category. Related screens: Global Donation (#1) and Bulk Donation (#5) — all three share the Donation module but operate on different physical records.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **STATUS**: Entity already exists at `Base.Domain/Models/DonationModels/DonationInKind.cs`. This table lists the CURRENT schema — the ALIGN pass does NOT add columns; all mockup fields map onto existing columns. **No migration is required for this screen.**

Table: `fund."DonationInKinds"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| DonationInKindId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | acl.Companies | Tenant scope — NOT a form field (HttpContext) |
| BranchId | int | — | YES | org.Branches | Collection centre |
| ReceiptNumber | string? | 50 | auto | — | Format `IK-YYYY-NNNN` or `{BranchCode}/YYYYMMDD/Seq` — auto-generated in Create handler |
| DonationDate | DateTime | — | YES | — | Date gift received; defaults to today |
| ContactId | int | — | YES | corg.Contacts | Donor |
| ContactSourceId | int? | — | NO | corg.ContactSources | Incoming sub-mode / channel |
| ItemCategoryId | int | — | YES | sys.MasterDatas (typeCode=DIKCATEGORY) | Medical Supplies, Equipment, Food, Clothing, Other |
| ItemDetails | string | 200 | YES | — | Free-text description |
| BillNo | string? | 50 | NO | — | Donor-provided invoice number |
| BillDate | string? | — | NO | — | Donor invoice date (stored as string per existing schema) |
| CurrencyId | int | — | YES | gen.Currencies | For bill amount |
| BillAmount | decimal(18,2) | — | YES | — | Donor-stated value; may be updated during valuation |
| Purpose | string? | 200 | NO | — | Free-text purpose / allocation note |
| Remarks | string? | 200 | NO | — | Internal notes |
| PrayerRequest | string? | — | NO | — | Optional pastoral / spiritual request |
| ReplyRequired | bool | — | YES | — | Donor wants acknowledgement — default true |
| DIKStatusId | int | — | YES | sys.MasterDatas (typeCode=DIKSTATUS) | Workflow: PEN = Pending Valuation, ACT = Valued |
| ReceiptPath | string? | — | NO | — | Receipt image upload (record phase) |
| ValuationReceiptPath | string? | — | NO | — | Valuation receipt upload (value phase) |
| PaymentModeId | int? | — | set-in-valuation | gen.PaymentModes | Cash / Cheque / DD / Bank Transfer |
| BankId | int? | — | conditional | gen.Banks | Required if PaymentMode ≠ Cash |
| InstrumentNo | string? | 50 | conditional | — | Required if PaymentMode ≠ Cash |
| InstrumentDate | DateTime? | — | conditional | — | Required if PaymentMode ≠ Cash |
| InstrumentTotal | decimal(18,2)? | — | NO | — | Total across selected items in batch valuation |

**Computed / Projected Fields** (NOT stored — derived in GetAll / Summary / GetById):
| Projected Field | Source |
|-----------------|--------|
| `receivedStatus` | Constant `"Received"` for all records (mockup shows Received badge always-on) |
| `valuationStatusCode` | `DIKStatus.DataValue` — `"PEN"` or `"ACT"` |
| `valuationStatusLabel` | `DIKStatus.DataName` — `"Pending"` or `"Valued"` |

**Child Entities**: NONE — DonationInKind is a flat record. Photos (mockup §Photos) reuse ReceiptPath + ValuationReceiptPath single-file columns (no dedicated Attachments table in current schema — note this as known-limitation in §⑫).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for FormSearchableSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| BranchId | Branch | PSS_2.0_Backend/.../Base.Domain/Models/OrgModels/Branch.cs | GetBranches | branchName | BranchResponseDto |
| ContactId | Contact | PSS_2.0_Backend/.../Base.Domain/Models/CorgModels/Contact.cs | GetContacts (+ CONTACTS_BY_CODE_QUERY for hero lookup) | displayName (contactCode + displayName) | ContactResponseDto |
| ContactSourceId | ContactSource | PSS_2.0_Backend/.../Base.Domain/Models/CorgModels/ContactSource.cs | GetContactSources | contactSourceName | ContactSourceResponseDto |
| CurrencyId | Currency | PSS_2.0_Backend/.../Base.Domain/Models/GenModels/Currency.cs | GetCurrencies | currencyName (+ currencySymbol) | CurrencyResponseDto |
| ItemCategoryId | MasterData (DIKCATEGORY) | PSS_2.0_Backend/.../Base.Domain/Models/SysModels/MasterData.cs | GetMasterDatas (filter typeCode=`DIKCATEGORY`) | dataName | MasterDataResponseDto |
| DIKStatusId | MasterData (DIKSTATUS) | PSS_2.0_Backend/.../Base.Domain/Models/SysModels/MasterData.cs | GetMasterDatas (filter typeCode=`DIKSTATUS`) | dataName (+ dataValue for PEN/ACT) | MasterDataResponseDto |
| PaymentModeId | PaymentMode | PSS_2.0_Backend/.../Base.Domain/Models/GenModels/PaymentMode.cs | GetPaymentModes | paymentModeName | PaymentModeResponseDto |
| BankId | Bank | PSS_2.0_Backend/.../Base.Domain/Models/GenModels/Bank.cs | GetBanks | bankName | BankResponseDto |

**NOTE**: `ItemCategory` and `DIKStatus` share the MasterData table discriminated by `typeCode`. Use the existing FormSearchableSelect pattern with typeCode filter (see `dik-create-form.tsx` current implementation).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `ReceiptNumber` is unique per Company — **auto-generated** by backend in Create handler (format: `IK-YYYY-NNNN` per mockup, or existing `{BranchCode}/YYYYMMDD/Seq`). Frontend never submits a ReceiptNumber.
- No user-facing uniqueness validation on the form.

**Required Field Rules (Create / Record phase):**
- BranchId, DonationDate, ContactId, ItemCategoryId, ItemDetails, CurrencyId, BillAmount — required
- ReplyRequired — defaults to `true`
- ItemDetails max 200 chars; Purpose / Remarks max 200 chars each
- BillAmount must be ≥ 0

**Required Field Rules (Valuation phase):**
- PaymentModeId — required
- If `PaymentMode.PaymentModeCode ≠ "CASH"` (not the cash row): BankId, InstrumentNo, InstrumentDate are ALL required
- BillAmount (valuation amount) — must be ≥ 0; overrides the donor-stated BillAmount when user edits it
- ValuationReceiptPath — optional (upload)

**Conditional Rules:**
- UPDATE mutation (batch valuation) accepts an `Items[]` array. For single-record valuation (mockup "Value" action), frontend submits a list with one item. Bank + Instrument fields are validated via Zod refinement (`paymentModeId !== 1` → cash-ID-assumed-1; use PaymentModeCode lookup instead for robustness — see §⑫).
- DIKStatusId is **owned by backend**: Create handler sets it to PEN; Update handler flips it to ACT.

**Business Logic:**
- Auto-receipt generation: Create handler computes `ReceiptNumber` using company/branch-scoped sequence.
- Status transition: `PEN → ACT` on successful valuation save; no backward transition.
- Delete is soft-delete (IsDeleted flag from base Entity).
- Toggle: Activate / Deactivate via `IsActive` — rarely used for DIK but include for FLOW completeness.

**Workflow:**
- States: `PEN (Pending Valuation)` → `ACT (Valued)` — terminal
- Transitions:
  - **Record** (anyone with CREATE capability): Create → new row, DIKStatusId = PEN, receipt-path optional upload
  - **Value** (finance staff with MODIFY capability): Update → sets PaymentMode + instrument details + valuation amount + valuation-receipt upload, DIKStatusId = ACT
- Side effects on valuation save: none beyond the DB update; NO automatic receipt regeneration (receipt PDF uses ReceiptPath image uploaded at record time).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: FLOW with side-drawer DETAIL (non-standard variant — see §⑫)
**Reason**: Add action (+Record In-Kind Donation) navigates to a full-page form (`?mode=new`). Row click opens a side drawer on the grid page (NOT a separate `?mode=read` page). Two distinct UI layouts: FORM (new/edit) and DETAIL drawer. Valuation is a secondary workflow that can be completed inline in the drawer OR via a dedicated batch-valuation page (existing DikUpdateForm — REMOVE in ALIGN).

**Backend Patterns Required:**
- [x] Standard CRUD — Create + Update already exist; **ADD Delete + Toggle** commands for FLOW completeness
- [x] Tenant scoping (CompanyId from HttpContext — already in place)
- [x] **Summary query — NEW**: `GetDonationInKindSummary` returning `DonationInKindSummaryDto` for the 3 widget cards
- [x] Single-record valuation — reuse existing `UpdateDonationInKind` (batch shape with single-item array)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 8) — already in Create/Update
- [x] Auto ReceiptNumber generation — already in Create handler
- [x] Unique validation — ReceiptNumber (backend-owned)
- [ ] Workflow commands (no separate Submit/Approve — status flips via Update)
- [x] File upload — ReceiptPath + ValuationReceiptPath already supported (string columns + multipart endpoint — verify pattern)
- [x] Custom business rule validators: PaymentMode ≠ CASH → Bank/Instrument required (enforce in Update validator, not only Zod)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) with Variant B layout (ScreenHeader + widgets + FlowDataTableContainer showHeader={false})
- [x] view-page.tsx with 2 URL modes (new, edit) — **read mode replaced by side drawer on grid page**
- [x] React Hook Form (for FORM layout) — reuse existing Zod schemas with minor cleanup
- [x] **Zustand store — NEW**: `donationinkind-store.ts` (drawer open state, selected row id, current valuation buffer)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back, Save buttons)
- [x] **Side-drawer detail panel — NEW** (520px right drawer, overlay, close on Esc) — 6 sections per mockup
- [x] Inline Complete Valuation sub-form (inside drawer) with conditional Bank/Instrument fields
- [x] Workflow status badges — 2 per row: Received (always green) + Valuation (Valued/Pending)
- [x] File upload widget — for ReceiptPath (record phase) + ValuationReceiptPath (valuation phase)
- [x] Summary cards / count widgets above grid (3 widgets)
- [x] Grid filter row: search + Item Category + Date Range + Status + Branch + Amount Range

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **CRITICAL for FLOW**: describe BOTH the FORM layout (new/edit) AND the DETAIL drawer layout (read).

### Grid/List View

**Display Mode**: `table` (default — transactional list, dense rows)

**Grid Layout Variant**: `widgets-above-grid` (mockup shows 3 KPI cards ABOVE the grid → **Variant B mandatory**: `<ScreenHeader>` + widget components + `<FlowDataTableContainer showHeader={false}>`)

**Page Header Row** (above widgets):
- Left: title `In-Kind Donations` with gift icon; subtitle `{totalCount} in-kind gifts | Estimated value: {totalValueFormatted}` (the subtitle values come from Summary query)
- Right: Back button (history.back), **+ Record In-Kind Donation** primary button → navigates to `?mode=new`

**Grid Columns** (in display order, from mockup):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | # | (row index) | row-number | 40px | NO | Zero-config row counter |
| 2 | Receipt # | receiptNumber | text (bold + accent color) | 140px | YES | `IK-YYYY-NNNN` |
| 3 | Date | donationDate | date | 100px | YES | Format: `MMM D` (e.g., "Apr 4") |
| 4 | Donor | contact.displayName | link | auto | YES | Click → navigates to contact detail page (service-placeholder if contact screen not wired) |
| 5 | Item Category | itemCategory.dataName | category-badge-renderer | 180px | YES | Badge with Font Awesome icon per category (Medical Supplies → fa-kit-medical, Equipment → fa-gear, Food → fa-wheat-awn, Clothing → fa-shirt, Other → fa-couch) — **NEW renderer `category-badge` required** |
| 6 | Description | itemDetails | text (truncate 40 chars with tooltip) | 260px | NO | — |
| 7 | Est. Value | billAmount | currency (bold) | 120px | YES | Formatted with thousand separators; currency symbol prefix from `currency.currencySymbol` |
| 8 | Currency | currency.currencyName | text (uppercase code) | 80px | YES | Show currency code like `USD`, `JPY`, `AED` — pull from `currency.currencyCode` or map |
| 9 | Status | (constant "Received") | status-badge (green) | 110px | NO | Always green "Received" — mockup shows this as always-on badge |
| 10 | Valuation | dikStatus.dataValue | status-badge | 110px | YES | `ACT` → blue "Valued" badge with check icon; `PEN` → amber "Pending" badge with clock icon — **reuse existing status-badge renderer with mapping** |
| 11 | Actions | — | row-actions | 140px | NO | See row actions below |

**Row Actions**:
- `View` (always visible) → opens side drawer with detail
- `Receipt` (visible if DIKStatusId = ACT) → placeholder toast "Receipt PDF download — service pending"
- `Value` (visible if DIKStatusId = PEN, styled primary) → opens drawer with inline valuation sub-form pre-expanded

**Row Click** (body, not action buttons): opens side drawer in View mode (same as View action).

**Search/Filter Row** (below widgets, above grid):
| Control | Widget | Data Source | Placeholder |
|---------|--------|-------------|-------------|
| Search | text input | — | "Search by donor, item description, receipt..." — hits backend `searchTerm` → ItemDetails, ReceiptNumber, Purpose, DIKStatus.DataName |
| Item Category | FormSearchableSelect | MASTERDATAS filter typeCode=DIKCATEGORY | "Item Category" |
| Date Range | DateRange widget | — | "Date Range" → advanced filter on `donationDate` |
| Status | FormSearchableSelect | MASTERDATAS filter typeCode=DIKSTATUS | "Status" (valuation status) |
| Branch | FormSearchableSelect | BRANCHES | "Branch" |
| Amount Range | segmented filter or min/max | — | "Amount Range" — bins: <1k, 1k-5k, 5k-10k, >10k → advanced filter on `billAmount` |

Apply all filters via `AdvancedFilter` (QueryBuilderModel) on `GetDonationInKinds` — no new backend query args required.

**Grid Actions Toolbar**: Export (enabled), Print (enabled), Add (enabled). Import/Delete/Toggle disabled at toolbar level — keep DELETE/TOGGLE on row-level via entity-operations.

### Page Widgets & Summary Cards

**Widgets**: YES — 3 KPI cards above the grid.

| # | Widget Title | Value Source (from Summary DTO) | Display Type | Icon | Icon Color |
|---|-------------|--------------------------------|-------------|------|-----------|
| 1 | This Month | `thisMonthCount` (number) + subtitle `"gifts \| Est. ${thisMonthValueFormatted}"` | stat-card with count | fa-gift | teal (brand) |
| 2 | Top Category | `topCategoryName` (string, e.g., "Medical Supplies") + subtitle `"{topCategoryPercent}% of all in-kind donations"` | stat-card with text | fa-kit-medical (dynamic per category or generic) | green |
| 3 | Pending Valuation | `pendingValuationCount` (number) + subtitle `"items awaiting assessment"` | stat-card with count | fa-scale-balanced | orange |

Reuse existing `<StatCard>` widget component if available (see feedback_ui_uniformity memory — tokens, uniform spacing). If not registered, use the donationcategory / branch widget pattern as reference.

**Summary GQL Query** (NEW):
- Query name: `GetDonationInKindSummary` (camelCase field: `donationInKindSummary`)
- Returns: `DonationInKindSummaryDto`
- Fields:
  - `totalCount` (int) — all DIKs (for header subtitle)
  - `totalEstimatedValue` (decimal) — SUM(BillAmount) — for header subtitle (displayed in **base company currency**; rollup is approximate — see §⑫ ISSUE)
  - `thisMonthCount` (int) — COUNT where DonationDate in current month
  - `thisMonthValue` (decimal) — SUM(BillAmount) where DonationDate in current month
  - `topCategoryId` (int?)
  - `topCategoryName` (string?) — ItemCategory.DataName ranked by COUNT DESC
  - `topCategoryPercent` (decimal?) — (topCategoryCount / totalCount) * 100
  - `pendingValuationCount` (int) — COUNT where DIKStatus.DataValue = 'PEN'

Add to `Base.Application/Business/DonationBusiness/DonationInKinds/Queries/GetDonationInKindSummary.cs` + register in `DonationInKindQueries.cs` endpoint.

### Grid Aggregation Columns

**Aggregation Columns**: NONE (mockup does not show per-row aggregated values beyond the record's own fields).

---

### FLOW View-Page — URL Modes & 2 Distinct UI Layouts

> This screen uses a **non-standard FLOW variant**: only `?mode=new` and `?mode=edit&id=X` invoke the view-page. The **read layout is a side drawer** overlaid on the grid page (no separate `?mode=read` page). Row click does NOT navigate — it dispatches a Zustand action to open the drawer.

```
URL MODE                              UI LAYOUT
─────────────────────────────────     ─────────────────────────────
/donationinkind                   →   GRID + side drawer (if open)
/donationinkind?mode=new          →   FORM LAYOUT (empty)
/donationinkind?mode=edit&id=243  →   FORM LAYOUT (pre-filled; ONLY for Pending records)
```

**Edit-mode eligibility**: Only records with `DIKStatusId = PEN` (Pending Valuation) are editable via the FORM layout. Valued records (`ACT`) are read-only via the drawer — clicking Edit on a Valued record's drawer is HIDDEN. Enforce at FE (hide Edit button) + BE (Update validator rejects if already ACT — or accept as reopen-valuation if business permits; **default to reject with 403 business rule violation**).

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

**Page Header**: FlowFormPageHeader with Back, Save, Save & New buttons + unsaved changes dialog. Reuse existing `dik-create-form` floating action bar pattern (Cancel | Save & Close | Save & New).

**Section Container Type**: Stacked cards (one card per section) — matches existing `dik-create-form.tsx` implementation. KEEP this structure.

**Form Sections** (in display order — consolidated from existing implementation, minor ALIGN tweaks):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | fa-user-search | Donor Lookup (hero) | full-width search + inline donor card | expanded | `contactId` (via code/name search), displays donor info card + recent DIKs table |
| 2 | fa-building | Collection Details | 3-column | expanded | `branchId`, `donationDate`, `contactSourceId` |
| 3 | fa-box | Item Details | 2-column | expanded | `itemCategoryId`, `itemDetails` (full-width), `purpose`, `remarks` |
| 4 | fa-money-bill | Billing & Amount | 2-column | expanded | `currencyId`, `billAmount`, `billNo`, `billDate` |
| 5 | fa-hands-praying | Prayer & Reply | 2-column | expanded | `replyRequired` (checkbox), `prayerRequest` (textarea, full-width) |
| 6 | fa-paperclip | Receipt Attachment | full-width | expanded | `receiptPath` file upload (JPG/PNG, max 200KB, drag-drop) |

**Field Widget Mapping** (all fields across all sections):
| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| (donor search) | 1 | DonorSearch hero | "Search by code or name..." | required (selects `contactId`) | Queries: `CONTACTS_BY_CODE_QUERY` — reuse existing hook |
| contactId | 1 | (set via DonorSearch) | — | required > 0 | Shows inline donor card (displayName, code, status, phone, email, address) |
| branchId | 2 | FormSearchableSelect | "Select centre" | required > 0 | Query: `GetBranches` |
| donationDate | 2 | FormDatePicker | "Select date" | required | Default: today |
| contactSourceId | 2 | FormSearchableSelect | "Channel" | optional | Query: `GetContactSources` |
| itemCategoryId | 3 | FormSearchableSelect | "Select category" | required > 0 | Query: `GetMasterDatas` (typeCode=DIKCATEGORY) |
| itemDetails | 3 | FormInput (multiline single-line) | "Describe the item(s)..." | required, max 200 | — |
| purpose | 3 | FormTextarea | "Program / purpose" | optional, max 200 | — |
| remarks | 3 | FormTextarea | "Internal notes" | optional, max 200 | — |
| currencyId | 4 | FormSearchableSelect | "Select currency" | required > 0 | Query: `GetCurrencies`; show currency symbol prefix on amount field |
| billAmount | 4 | number input (currency-prefixed) | "0.00" | required, >= 0 | Monospace, large font |
| billNo | 4 | FormInput | "Invoice #" | optional, max 50 | — |
| billDate | 4 | FormDatePicker | "Invoice date" | optional | — |
| replyRequired | 5 | FormCheckbox | — | default true | — |
| prayerRequest | 5 | FormTextarea (8 rows) | "Optional prayer / spiritual request" | optional | — |
| receiptPath | 6 | FileUpload (drag-drop) | "Drop receipt image or click to browse" | optional, JPG/PNG, max 200KB | — |

**Special Form Widgets**:

- **Donor Search Hero** (existing — keep as-is): Search input → queries contacts → selection → inline donor card with Avatar, displayName, contactCode, contactStatus, phone, email, address, + "Recent DIKs for this donor" mini-table (Receipt, Date, Item, Category, Amount, Status-badge). Purely informational; no state to persist beyond `contactId`.

- **Conditional Sub-forms**: NONE on the FORM layout (valuation is a separate phase done in the drawer). Keep the FORM flat.

- **Inline Mini Display** (Donor Card — part of Donor Search hero): Populated when `contactId` is selected. Shows Avatar + name + code + type badge + score + email + phone + "View Profile" link (SERVICE_PLACEHOLDER — toast).

**Child Grids in Form**: NONE.

---

#### LAYOUT 2: DETAIL (side drawer invoked from grid row) — NOT a separate URL mode

> Row click on grid → Zustand action `openDikDetailDrawer(donationInKindId)` → drawer slides in from right, grid remains behind (with 30% opacity overlay). Close via X button, overlay click, or Escape key.
> Drawer width: 520px desktop, full-width mobile.
> **IMPORTANT**: Data is fetched via `donationInKindById` on drawer open (not pre-loaded). Show drawer skeleton while fetching.

**Drawer Header**:
- Icon: fa-gift in brand color
- Title: `In-Kind Donation Detail`
- Subtitle: `{receiptNumber}` + Valuation badge (Pending/Valued)
- Close button (X) on right

**Drawer Body** (scrollable, 6 sections separated by uppercase small-caps headers with bottom border):

| # | Section Title | Icon | Fields Shown (label : value pairs, right-aligned value) |
|---|--------------|------|---------------------------------------------------------|
| 1 | Donor Information | fa-user | Donor (link → contact detail SERVICE_PLACEHOLDER), Organization (if contact.orgName), Email, Phone |
| 2 | Item Details | fa-box | Receipt # (accent color), Date Received, Category, Description, Quantity *(see §⑫ — derive from ItemDetails or mark N/A)*, Condition *(see §⑫ — not stored, N/A)* |
| 3 | Photos | fa-camera | 3-tile photo-placeholder grid; show ReceiptPath image + ValuationReceiptPath image; remaining tiles render placeholder |
| 4 | Bill / Invoice | fa-file-invoice | Invoice Number (billNo), Invoice Date (billDate), Invoice Amount (billAmount + currencySymbol/code), Attachment *(link to ReceiptPath if present, else "—")* |
| 5 | Valuation Details | fa-scale-balanced | Estimated Value (billAmount + currency code), Valuation Method *(static "Fair Market Value" — see §⑫)*, Valued By *(derived: ModifiedBy name)*, Valuation Date *(derived: ModifiedDate)*, Status (Valued/Pending badge) |
| 6 | Receipt & Allocation | fa-receipt | Receipt Status (Issued/Pending badge from DIKStatus), Receipt # (receiptNumber), Purpose (from `purpose`), Allocated To *(SERVICE_PLACEHOLDER — field not in schema; show "—" or purpose)*, Download *(SERVICE_PLACEHOLDER — "Download Receipt PDF" link with paperclip icon → toast)* |

**Drawer Footer / Actions**:
- For **Valued records** (DIKStatusId = ACT): close-only (drawer has no action buttons)
- For **Pending records** (DIKStatusId = PEN):
  - Default view: `Complete Valuation` primary button (amber)
  - Click → drawer body extends with inline Complete Valuation sub-form (below section 6); footer buttons become `Cancel` + `Save Valuation` (emerald)

**Complete Valuation Sub-form (inline in drawer)**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| valuationAmount (→ `billAmount`) | number input (currency-prefixed) | "0.00" | required, >= 0 | Pre-filled with existing `billAmount` |
| paymentModeId | FormSearchableSelect | "Select mode" | required > 0 | Query: `GetPaymentModes` |
| bankId | FormSearchableSelect | "Select bank" | **conditional**: required if PaymentMode ≠ Cash | Query: `GetBanks` |
| instrumentNo | FormInput | "Instrument #" | **conditional**: required if PaymentMode ≠ Cash | max 50 |
| instrumentDate | FormDatePicker | "Instrument date" | **conditional**: required if PaymentMode ≠ Cash | — |
| valuationReceiptPath | FileUpload | "Upload valuation receipt" | optional, JPG/PNG, max 200KB | — |

On Save → invokes `UpdateDonationInKind` mutation with `Items: [{ donationInKindId, billAmount: valuationAmount, valuationReceiptPath }]` + top-level payment fields. Handler flips DIKStatusId → ACT. Drawer refreshes in Valued state; grid row auto-refreshes; widgets refetch.

---

### Removed UI (ALIGN — delete from existing code)

- Standalone **Batch Valuation page** (`donationinkindupdate.tsx` + `DikUpdateForm`) — mockup does NOT show batch valuation. Remove from Navigation and from page-components. If business requires batch mode later, re-introduce as `?mode=valuate` variant.
- Old split-routes `donationinkindcreate.tsx` and `donationinkindupdate.tsx` — delete both; single entry point is `donationinkind/page.tsx`.

### User Interaction Flow (FLOW variant — 2 modes + drawer)

1. User lands on `/crm/donation/donationinkind` → grid + 3 KPI widgets + filter row
2. Click **+ Record In-Kind Donation** → URL: `?mode=new` → FORM LAYOUT (empty)
3. Fill form (Donor Search → Collection/Item/Billing/Prayer/Receipt sections) → Save → API creates → URL: `/donationinkind` (no params) → grid refreshes; new row visible with Pending badge
4. On grid: click row → side drawer opens (fetches by id) → shows 6 sections of detail
5. For Pending record in drawer: click **Complete Valuation** → inline sub-form → fill payment mode (+ conditional bank/instrument) + valuation amount + optional upload → Save → API updates → drawer refreshes to Valued state; grid row refreshes
6. For Valued record in drawer: no action buttons; Close via X / overlay / Esc
7. From drawer: click **Edit** (Pending records only) → URL: `?mode=edit&id=X` → FORM LAYOUT pre-filled → Save → back to grid
8. Unsaved changes in FORM: dirty-form guard on navigation
9. Row "Value" action button (Pending rows only) → same as row-click + auto-expand valuation sub-form

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to DonationInKind.

**Canonical Reference**: **SavedFilter** (FLOW canonical) for view-page + Zustand store structure. Reference the existing `dik-create-form.tsx` / `dik-view-page.tsx` for form + drawer content since they already contain the target sections.

| Canonical | → DonationInKind | Context |
|-----------|------------------|---------|
| SavedFilter | DonationInKind | Entity/class name |
| savedFilter | donationInKind | Variable/field names |
| SavedFilterId | DonationInKindId | PK field |
| SavedFilters | DonationInKinds | Table name, collection names |
| saved-filter | donation-in-kind | kebab-case |
| savedfilter | donationinkind | FE folder, import paths, file names |
| SAVEDFILTER | DONATIONINKIND | Grid code, menu code |
| notify | fund | DB schema |
| Notify | Donation | Backend group name (Models/Schemas/Business) |
| NotifyModels | DonationModels | Namespace suffix |
| CRM_COMMUNICATION | CRM_DONATION | Parent menu code |
| CRM | CRM | Module code (same) |
| crm/communication/savedfilter | crm/donation/donationinkind | FE route path |
| notify-service | donation-service | FE service folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> **ALIGN scope** — most files exist; only NEW/MODIFIED/DELETED flags matter. "Exists" = already in repo.

### Backend Files

| # | File | Path | Status |
|---|------|------|--------|
| 1 | Entity | PSS_2.0_Backend/.../Base.Domain/Models/DonationModels/DonationInKind.cs | **EXISTS** — no schema change |
| 2 | EF Config | PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/DonationConfigurations/DonationInKindConfiguration.cs | **EXISTS** — no change |
| 3 | Schemas (DTOs) | PSS_2.0_Backend/.../Base.Application/Schemas/DonationSchemas/DonationInKindSchemas.cs | **MODIFY** — add `DonationInKindSummaryDto` |
| 4 | Create Command | .../Business/DonationBusiness/DonationInKinds/Commands/CreateDonationInKind.cs | **EXISTS** — verify ReceiptNumber format aligns with mockup (`IK-YYYY-NNNN`) |
| 5 | Update Command (batch valuation) | .../Commands/UpdateDonationInKind.cs | **EXISTS** — validate single-item path; **ADD** guard: reject if target already ACT |
| 6 | **Delete Command — NEW** | .../Commands/DeleteDonationInKind.cs | **CREATE** — soft delete |
| 7 | **Toggle Command — NEW** | .../Commands/ToggleDonationInKind.cs | **CREATE** — IsActive flip |
| 8 | GetAll Query | .../Queries/GetDonationInKinds.cs | **MODIFY** — add projection fields (`valuationStatusCode`, `valuationStatusLabel`, `currencyCode`); add advanced-filter support for `Status` (DIKStatus.DataValue), `Branch` (BranchId), `AmountRange` (BillAmount bins) |
| 9 | GetById Query | .../Queries/GetDonationInKindById.cs | **MODIFY** — include ModifiedBy user name for "Valued By" field in drawer (join User table) |
| 10 | **Summary Query — NEW** | .../Queries/GetDonationInKindSummary.cs | **CREATE** — returns `DonationInKindSummaryDto` |
| 11 | Mutations endpoint | .../Base.API/EndPoints/Donation/Mutations/DonationInKindMutations.cs | **MODIFY** — add `DeleteDonationInKind`, `ToggleDonationInKind` |
| 12 | Queries endpoint | .../Base.API/EndPoints/Donation/Queries/DonationInKindQueries.cs | **MODIFY** — add `GetDonationInKindSummary` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | NO CHANGE (DbSet<DonationInKind> already registered) |
| 2 | DonationDbContext.cs | NO CHANGE |
| 3 | DecoratorProperties.cs | NO CHANGE |
| 4 | DonationMappings.cs | **MODIFY** — add Mapster config for `DonationInKindSummaryDto` (source: projected tuple from Summary handler) |

### Frontend Files

| # | File | Path | Status |
|---|------|------|--------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/donation-service/DonationInKindDto.ts | **MODIFY** — add `DonationInKindSummaryDto`; add projected fields (`valuationStatusCode`, `valuationStatusLabel`, `currencyCode`, `valuedByName`, `valuedAt`) |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/DonationInKindQuery.ts | **MODIFY** — add `DONATION_IN_KIND_SUMMARY_QUERY`; extend existing queries to request new projected fields |
| 3 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/donation-mutations/DonationInKindMutation.ts | **MODIFY** — add `DELETE_DONATION_IN_KIND_MUTATION`, `TOGGLE_DONATION_IN_KIND_MUTATION` |
| 4 | Page Config | PSS_2.0_Frontend/src/presentation/pages/crm/donation/donationinkind.tsx | **CREATE** (new consolidated page config) |
| 5 | Index Page Router | .../presentation/components/page-components/crm/donation/donationinkind/index.tsx | **CREATE** — 3-mode router: default (index-page), new/edit (view-page) |
| 6 | **Index Page (Variant B) — NEW** | .../donationinkind/index-page.tsx | **CREATE** — `<ScreenHeader>` (title + subtitle + Back + +Record button) + 3 widget cards + filter row + `<FlowDataTableContainer showHeader={false}>` + **side-drawer mount** |
| 7 | **View Page (FORM) — NEW** | .../donationinkind/view-page.tsx | **CREATE** — 2-mode (new/edit) view-page rendering the 6 form sections; reuses existing field layouts |
| 8 | **Zustand Store — NEW** | .../donationinkind/donationinkind-store.ts | **CREATE** — state: `drawerOpen`, `drawerRecordId`, `drawerMode` ('view' \| 'valuate'), `dirty`; actions: `openDrawer(id, mode)`, `closeDrawer`, `setValuationBuffer` |
| 9 | **Side Drawer — NEW** | .../donationinkind/dik-detail-drawer.tsx | **CREATE** — 520px right drawer, 6 sections, inline Complete Valuation sub-form for PEN records |
| 10 | Create Form (existing) | .../donationinkind/dik-create-form.tsx | **MODIFY** — extract pure form body from existing file; wire into view-page.tsx |
| 11 | View Page (existing) | .../donationinkind/dik-view-page.tsx | **DELETE** — replaced by `dik-detail-drawer.tsx` |
| 12 | Update Form (existing batch valuation) | .../donationinkind/dik-update-form.tsx | **DELETE** — batch valuation removed from mockup scope; single-record valuation via drawer only |
| 13 | Data Table (existing) | .../donationinkind/data-table.tsx | **DELETE** — replaced by index-page.tsx Variant B composition |
| 14 | Form Schemas | .../crm/donation/shared/dik-form-schemas.ts | **MODIFY** — keep `dikCreateSchema`; replace `dikUpdateSchema` with `dikValuationSchema` (single-item form, same conditional rules) |
| 15 | Route Page | PSS_2.0_Frontend/src/app/[lang]/crm/donation/donationinkind/page.tsx | **MODIFY** — replace `DikCreatePageConfig` import with new `DonationInKindPageConfig` |
| 16 | **Category Badge Renderer — NEW** | .../presentation/components/data-table/column-renderers/category-badge.tsx | **CREATE** — renders MasterData.DataName with Font Awesome icon mapped per category (Medical Supplies, Equipment, Food, Clothing, Other); register in column-renderers barrel |
| 17 | Column renderers barrel | .../column-renderers/index.ts | **MODIFY** — register `category-badge` |
| 18 | Old page config (create) | PSS_2.0_Frontend/src/presentation/pages/crm/donation/donationinkindcreate.tsx | **DELETE** |
| 19 | Old page config (update) | PSS_2.0_Frontend/src/presentation/pages/crm/donation/donationinkindupdate.tsx | **DELETE** |
| 20 | Old route (update) | PSS_2.0_Frontend/src/app/[lang]/crm/donation/donationinkindupdate/page.tsx | **DELETE if exists** — verify with glob |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts (donation-service) | Add `DELETE` + `TOGGLE` ops for DONATIONINKIND; remove batch-valuation op if present |
| 2 | operations-config.ts | Verify `DONATIONINKIND` operations registered |
| 3 | Sidebar menu config | Already references `crm/donation/donationinkind` per DB seed; remove any `donationinkindupdate` entry |
| 4 | Route config | Verify single route; remove `donationinkindupdate` route if configured |
| 5 | Domain entity operations barrel | Export new summary DTO + delete/toggle mutation hooks |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: ALIGN

MenuName: In-Kind Donations
MenuCode: DONATIONINKIND
ParentMenu: CRM_DONATION
Module: CRM
MenuUrl: crm/donation/donationinkind
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: DONATIONINKIND
---CONFIG-END---
```

**Seed notes:**
- Menu row under `CRM_DONATION` already exists from earlier generation — **re-verify** it points to `crm/donation/donationinkind` (NOT `donationinkindcreate`).
- Remove any legacy menu rows for `DONATIONINKINDCREATE` or `DONATIONINKINDUPDATE` if present.
- Re-seed the Grid row + Fields with the new column list (§⑥ grid columns table).

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `DonationInKindQueries`
- Mutation type: `DonationInKindMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `donationInKinds` | `GridFeatureResult<DonationInKindResponseDto>` | searchTerm, pageSize, pageIndex, sortDescending, sortColumn, advancedFilter |
| `donationInKindById` | `DonationInKindResponseDto` | donationInKindId |
| **`donationInKindSummary` — NEW** | `DonationInKindSummaryDto` | (none — tenant-scoped from HttpContext) |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createDonationInKind` | `DonationInKindCreateRequestDtoInput!` | `DonationInKindCreateResponseDto` (donationInKindId, receiptNumber, dikStatusId) |
| `updateDonationInKind` | `DonationInKindUpdateRequestDtoInput!` | `DonationInKindUpdateResponseDto` (updatedCount) |
| **`deleteDonationInKind` — NEW** | donationInKindId (Int!) | int |
| **`toggleDonationInKind` — NEW** | donationInKindId (Int!) | int |

**Response DTO Fields** (`DonationInKindResponseDto` — existing + ADDED projections):
| Field | Type | Notes |
|-------|------|-------|
| donationInKindId | number | PK |
| companyId | number | Tenant |
| branchId | number | FK |
| receiptNumber | string? | Auto-gen |
| donationDate | string (ISO) | — |
| contactId | number | FK |
| channelTypeId | number? | FK (alias: contactSourceId — verify naming) |
| itemCategoryId | number | FK MasterData DIKCATEGORY |
| itemDetails | string | — |
| billNo | string? | — |
| billDate | string? | — |
| currencyId | number | FK |
| billAmount | number | — |
| purpose | string? | — |
| remarks | string? | — |
| prayerRequest | string? | — |
| replyRequired | boolean | — |
| dikStatusId | number | FK MasterData DIKSTATUS |
| receiptPath | string? | — |
| valuationReceiptPath | string? | — |
| paymentModeId | number? | — |
| bankId | number? | — |
| instrumentNo | string? | — |
| instrumentDate | string? | — |
| instrumentTotal | number? | — |
| isActive | boolean | Inherited |
| createdDate | string | Inherited |
| modifiedDate | string? | Inherited |
| **valuationStatusCode — NEW** | string | `"PEN"` \| `"ACT"` — projected from DIKStatus.DataValue |
| **valuationStatusLabel — NEW** | string | `"Pending"` \| `"Valued"` — projected from DIKStatus.DataName |
| **currencyCode — NEW** | string | Projected `currency.currencyCode` for column display |
| **valuedByName — NEW** | string? | Projected — ModifiedBy user's display name (NULL if not yet valued) |
| **valuedAt — NEW** | string? | Projected — ModifiedDate when DIKStatusId flipped to ACT (use ModifiedDate as proxy; add a dedicated `ValuedAt` column later if needed — see §⑫) |
| branch | `{ branchName }` | Nav |
| contact | `{ displayName, contactCode, email?, phone?, orgName? }` | Nav — extend for drawer |
| currency | `{ currencyName, currencySymbol, currencyCode }` | Nav |
| itemCategory | `{ dataName }` | Nav |
| dikStatus | `{ dataName, dataValue }` | Nav |
| paymentMode | `{ paymentModeName, paymentModeCode }` | Nav — need code for cash check |
| bank | `{ bankName }` | Nav |

**Summary DTO** (`DonationInKindSummaryDto` — NEW):
| Field | Type | Notes |
|-------|------|-------|
| totalCount | number | All DIKs for company |
| totalEstimatedValue | number | SUM(BillAmount) |
| thisMonthCount | number | COUNT in current calendar month (DonationDate) |
| thisMonthValue | number | SUM in current calendar month |
| topCategoryId | number? | — |
| topCategoryName | string? | — |
| topCategoryPercent | number? | % of total |
| pendingValuationCount | number | COUNT where DIKStatus.DataValue = 'PEN' |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/[lang]/crm/donation/donationinkind`
- [ ] No 404 for route; old split routes (`donationinkindcreate`, `donationinkindupdate`) return 404 (deleted)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with columns: #, Receipt #, Date, Donor, Item Category (icon+badge), Description, Est. Value, Currency, Status (Received), Valuation (Valued/Pending), Actions
- [ ] 3 widgets above grid render correct values and refresh after create/valuation
- [ ] Page subtitle reads `{totalCount} in-kind gifts | Estimated value: ${totalEstimatedValue}`
- [ ] Search filters by donor name/code, itemDetails, receiptNumber, purpose
- [ ] Filter controls: Item Category, Date Range, Status (valuation), Branch, Amount Range — all apply via advancedFilter
- [ ] `?mode=new`: empty FORM renders 6 sections (Donor Search hero + Collection + Item + Billing + Prayer + Receipt Attachment)
- [ ] Donor Search hero: typing contact code/name loads results; selecting populates inline donor card + recent-DIKs mini-table
- [ ] Save on new → URL returns to grid; new row visible with Pending badge; widgets re-fetch
- [ ] Row click on grid → side drawer opens (520px right), shows 6 sections
- [ ] Pending records in drawer: `Complete Valuation` button (amber); click expands inline sub-form
- [ ] Valuation sub-form: conditional Bank + Instrument fields appear when PaymentMode ≠ Cash
- [ ] Save valuation → drawer refreshes to Valued state; grid row Valuation badge flips to Valued; widgets refetch
- [ ] Valued records in drawer: NO action buttons, close-only
- [ ] `?mode=edit&id=X` (Pending records only): FORM pre-filled; Valued records' Edit button is hidden
- [ ] Drawer close: X button, overlay click, Escape key — all close and restore body scroll
- [ ] FK dropdowns load via FormSearchableSelect: Branch, Contact (hero search), ContactSource, Currency, ItemCategory (MasterData DIKCATEGORY), PaymentMode, Bank
- [ ] Category badge renderer shows correct FA icon per category (Medical Supplies → medical, Equipment → gear, Food → wheat, Clothing → shirt, Other → couch)
- [ ] Status badges use design tokens (no hex literals — reuse existing status-badge renderer)
- [ ] Service placeholders wired with toast: Receipt action, Receipt PDF download, Allocated-To, donor-profile link
- [ ] Unsaved changes dialog triggers on FORM navigation with dirty state
- [ ] Permissions: Edit / Delete / Toggle respect BUSINESSADMIN capabilities

**DB Seed Verification:**
- [ ] Menu appears in sidebar under CRM_DONATION with label `In-Kind Donations` at OrderBy=4 (per MODULE_MENU_REFERENCE)
- [ ] Grid row seeded with `GridType=FLOW`, 10 grid columns (matches mockup)
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)
- [ ] Legacy menu rows (if any) for `DONATIONINKINDCREATE` / `DONATIONINKINDUPDATE` removed

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **Schema unchanged — no migration**: The entity has all fields needed. Do NOT add columns; project/derive missing mockup fields (valuationMethod = static "Fair Market Value", quantity = not stored, condition = not stored, allocatedTo = not stored).
- **CompanyId is NOT a form field** — injected from HttpContext (FLOW convention).
- **ReceiptNumber is auto-generated** — do NOT add to any form; the mockup's `IK-YYYY-NNNN` format does not match current generator (`{BranchCode}/YYYYMMDD/Seq`). **Business decision required**: align generator to mockup format OR keep current. Default: **keep current** and flag as ISSUE-1.
- **FLOW variant with drawer detail**: This screen does NOT use the standard `?mode=read` full-page detail. The drawer is opened via Zustand action from the grid row click — NOT via URL routing. This is intentional and matches the mockup.
- **Old split-page files MUST be deleted** (`donationinkindcreate.tsx`, `donationinkindupdate.tsx`, `dik-update-form.tsx`, `dik-view-page.tsx`, `data-table.tsx`). Do NOT leave them as dead code.
- **Status column is constant "Received"** — it's a visual always-on badge, not a data field. Valuation column is the real workflow state from DIKStatus.
- **Cash-mode check**: Current `dik-update-form.tsx` uses `paymentModeId !== 1` as cash test — this is fragile (assumes ID=1). **Use `paymentMode.paymentModeCode === 'CASH'` instead** (requires joining PaymentMode in GetById + in form hooks). Carry this forward to new drawer valuation sub-form + backend Update validator.
- **ALIGN scope**: Only modify what's different. Do NOT regenerate existing BE handlers; only add Summary + Delete + Toggle + projection fields.
- **Menu seed: OrderBy=4** under CRM_DONATION (not end of list) per MODULE_MENU_REFERENCE.md line 66.

### Known ALIGN issues to log in §⑬ after build:

- **ISSUE-1**: Receipt number format mismatch (mockup `IK-YYYY-NNNN` vs current `{BranchCode}/YYYYMMDD/Seq`) — track as OPEN pending business decision.
- **ISSUE-2**: "Allocated To" field in mockup not stored — schema gap. Proposal: add `AllocatedTo` or `AllocatedProgramId` in a follow-up migration (out of scope here).
- **ISSUE-3**: "Quantity" and "Condition" fields in mockup not stored — embedded inside ItemDetails free-text. Proposal: extract to separate columns in a follow-up.
- **ISSUE-4**: `ValuedAt` uses ModifiedDate as proxy — accurate only if no other post-valuation edits occur. Add dedicated column in follow-up if precision required.
- **ISSUE-5**: Photos section is limited to 2 attachments (ReceiptPath + ValuationReceiptPath) — mockup shows 3-tile grid; 3rd tile always placeholder. Multi-attachment support needs a new `DonationInKindAttachments` child table (out of scope).
- **ISSUE-6**: Total Estimated Value in header subtitle is a cross-currency SUM — currently SUMs raw BillAmount regardless of CurrencyId. Flag as approximate; fix later via Currency-to-Base conversion service (out of scope).

### Service Dependencies (UI-only — no backend service implementation)

- **SERVICE_PLACEHOLDER: "Receipt" row action + "Download Receipt PDF" link in drawer** — full UI implemented (button/link + toast); actual PDF generation service not in codebase. Handler: toast "Receipt PDF generation — service pending".
- **SERVICE_PLACEHOLDER: Donor-profile link** (`contact.displayName` click in grid and drawer) — navigates via `parent.loadContent('contacts/contact-detail')` in mockup; currently contact detail screen (#18) is PARTIAL. UI wires an href to `/crm/contact/allcontacts?id={contactId}` but displays toast if route not mounted.
- **SERVICE_PLACEHOLDER: "Allocated To" field in drawer** — field not stored; displays `"—"` literal with tooltip "Allocation tracking coming soon".

Full UI must be built (buttons, forms, drawer, valuation sub-form). Only the 3 external/missing-service calls above are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | LOW | BE/biz | Receipt # format mismatch: mockup spec `IK-YYYY-NNNN` vs current generator `{BranchCode}/YYYYMMDD/Seq`. Kept current; business decision pending. | OPEN |
| ISSUE-2 | 1 | MED | Schema | "Allocated To" field in drawer mockup not stored. UI shows `—` placeholder with tooltip. Needs follow-up migration (AllocatedTo / AllocatedProgramId col). | OPEN |
| ISSUE-3 | 1 | LOW | Schema | "Quantity" and "Condition" fields shown in mockup embedded inside `ItemDetails` free-text. UI displays N/A on drawer. Needs structured columns in follow-up. | OPEN |
| ISSUE-4 | 1 | LOW | BE/data | `valuedAt` projected from `ModifiedDate` as proxy (populated only when DIKStatus.DataValue='ACT'). Inaccurate if any post-valuation edit updates ModifiedDate. Dedicated `ValuedAt` column recommended later. | OPEN |
| ISSUE-5 | 1 | MED | Schema | Photos section fixed to 2 attachments (ReceiptPath + ValuationReceiptPath); mockup shows 3-tile grid. 3rd tile is always placeholder. Multi-attachment needs new `DonationInKindAttachments` child table. | OPEN |
| ISSUE-6 | 1 | MED | BE/biz | Header subtitle `totalEstimatedValue` is cross-currency SUM(BillAmount) — no FX conversion. Approximate for companies with multiple CurrencyIds. Needs base-currency-conversion service. | OPEN |
| ISSUE-7 | 1 | LOW | FE | Edit-mode form reads `contact.addressLine1/2` but BE `GetDonationInKindById` query does not project these nested contact address fields → empty on first load. Name/code/phone/email display correctly. | OPEN |
| ISSUE-8 | 1 | LOW | FE | Legacy `DikCreateForm` named export retained as thin compat wrapper around new `DikFormBody`. Can be removed after a global importer sweep. | OPEN |
| ISSUE-9 | 1 | LOW | DB seed | Seed uses `GridTypeCode = 'FLOW'`; pre-existing row for DONATIONINKIND may have used `'FLOW_GRID'`. Orchestrator should verify `sett."GridTypes"` actual code; the `UPDATE` silently no-ops if the code mismatches. | OPEN |
| ISSUE-10 | 1 | LOW | DB seed | Shared `Fields` rows (`DISPLAYNAME`, `DATANAME`, `CURRENCYNAME`) assumed to pre-exist from Contact / MasterData / Currency seeds. `NOT EXISTS` guard silently skips the 3 corresponding `GridFields` inserts if any source Field row is missing. | OPEN |
| ISSUE-11 | 1 | LOW | BE/auth | `DecoratorDonationModules.DonationInKind` not defined in `DecoratorProperties.cs`. New Delete / Toggle / Summary handlers follow the existing DIK convention of commented-out `[CustomAuthorize]` attributes. A one-line decorator entry + uncommenting is needed before role-based auth activates for DIK. | OPEN |
| ISSUE-12 | 1 | INFO | BE/map | `DonationMappings` uses default Mapster config; the 5 new projected fields (`valuationStatusCode`, `valuationStatusLabel`, `currencyCode`, `valuedByName`, `valuedAt`) are populated post-map in handlers rather than via dedicated Mapster `.Map(...)` configs. Intentional — avoids join in Mapster expression tree. | RESOLVED |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. ALIGN scope — schema unchanged (no migration), FLOW type with non-standard side-drawer detail variant. Orchestrator skipped BA / Solution-Resolver / UX-Architect spawns (prompt §①–⑥ already contained deep pre-analysis — SavedFilter #27 precedent). Spawned BE + FE in parallel, both Opus (FLOW + complexity=High per model-selection matrix).
- **Files touched**:
  - BE:
    - `PSS_2.0_Backend/.../Business/DonationBusiness/DonationInKinds/Commands/DeleteDonationInKind.cs` (created)
    - `PSS_2.0_Backend/.../Commands/ToggleDonationInKind.cs` (created)
    - `PSS_2.0_Backend/.../Queries/GetDonationInKindSummary.cs` (created)
    - `PSS_2.0_Backend/.../Schemas/DonationSchemas/DonationInKindSchemas.cs` (modified — +DonationInKindSummaryDto + 5 projected fields + ModifiedDate on response DTO)
    - `PSS_2.0_Backend/.../Queries/GetDonationInKinds.cs` (modified — extended search on donor displayName+contactCode, post-map populates valuationStatusCode/Label + currencyCode + valuedAt, advanced filters Status/Branch/AmountRange via ApplyGridFeatures)
    - `PSS_2.0_Backend/.../Queries/GetDonationInKindById.cs` (modified — single-call drawer payload, joins auth.Users once on ModifiedBy, valuedByName/valuedAt only when DIKStatus.DataValue='ACT')
    - `PSS_2.0_Backend/.../Commands/UpdateDonationInKind.cs` (modified — ACT-guard rejects if all items already valued, Cash-mode check now uses PaymentMode.PaymentModeCode='CASH', conditional Bank/Instrument validation)
    - `PSS_2.0_Backend/.../EndPoints/Donation/Mutations/DonationInKindMutations.cs` (modified — registers deleteDonationInKind + toggleDonationInKind)
    - `PSS_2.0_Backend/.../EndPoints/Donation/Queries/DonationInKindQueries.cs` (modified — registers donationInKindSummary)
    - `PSS_2.0_Backend/.../Mappings/DonationMappings.cs` (modified — Mapster config for DonationInKind↔DonationInKindResponseDto)
  - FE:
    - `PSS_2.0_Frontend/src/presentation/pages/crm/donation/donationinkind.tsx` (created — consolidated page config)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/donationinkind/index.tsx` (created — 3-mode router)
    - `.../donationinkind/index-page.tsx` (created — Variant B: FlowDataTableStoreProvider@60 + ScreenHeader@169 + 3 widgets + filter row + FlowDataTableContainer showHeader=false@221 + DikDetailDrawer mount@225)
    - `.../donationinkind/view-page.tsx` (created — 2-mode FORM new/edit, 6 stacked cards)
    - `.../donationinkind/dik-detail-drawer.tsx` (created — 520px right drawer, 6 sections, inline Complete Valuation sub-form for PEN records)
    - `.../donationinkind/donationinkind-store.ts` (created — Zustand drawer state)
    - `.../custom-components/data-tables/shared-cell-renderers/category-badge.tsx` (created — MasterData DIKCATEGORY dataName → Phosphor icon + token chip)
    - `src/domain/entities/donation-service/DonationInKindDto.ts` (modified — +summary DTO + 5 projected fields + extended contact/currency/paymentMode/dikStatus nested types)
    - `src/infrastructure/gql-queries/donation-queries/DonationInKindQuery.ts` (modified — +DONATION_IN_KIND_SUMMARY_QUERY, extended list+byId with 5 projected fields + nested nav)
    - `src/infrastructure/gql-mutations/donation-mutations/DonationInKindMutation.ts` (modified — +DELETE + +TOGGLE mutations)
    - `.../donationinkind/dik-create-form.tsx` (modified — extracted DikFormBody for reuse; legacy DikCreateForm retained as compat wrapper)
    - `.../crm/donation/shared/dik-form-schemas.ts` (modified — kept dikCreateSchema, replaced batch dikUpdateSchema with single-record dikValuationSchema keyed on paymentModeCode)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (modified — +export CategoryBadge)
    - `.../data-tables/{advanced,basic,flow}/data-table-column-types/component-column.tsx` (modified ×3 — register `case "category-badge"`)
    - `src/app/[lang]/crm/donation/donationinkind/page.tsx` (modified — imports DonationInKindPageConfig)
    - `src/presentation/pages/crm/donation/index.ts` (modified — export DonationInKindPageConfig)
    - `src/application/configs/data-table-configs/donation-service-entity-operations.ts` (modified — re-wired DONATIONINKIND to real CREATE/UPDATE/DELETE/TOGGLE mutations; previously aliased to RECURRINGDONATIONSCHEDULE)
    - `.../donationinkind/dik-view-page.tsx` (deleted)
    - `.../donationinkind/dik-update-form.tsx` (deleted)
    - `.../donationinkind/data-table.tsx` (deleted)
    - `.../donationinkind/index.ts` (deleted — old barrel replaced by index.tsx router)
    - `PSS_2.0_Frontend/src/presentation/pages/crm/donation/donationinkindcreate.tsx` (deleted)
    - `PSS_2.0_Frontend/src/presentation/pages/crm/donation/donationinkindupdate.tsx` (deleted)
  - DB:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/DonationInKind-sqlscripts.sql` (modified — idempotent; upserts Menu@OrderBy=4 under CRM_DONATION, deletes legacy DONATIONINKIND{CREATE,UPDATE} menu rows, rewrites Grid+10 FLOW columns, GridFormSchema SKIP)
- **Deviations from spec**: None material. Minor: FE agent placed `category-badge.tsx` under `custom-components/data-tables/shared-cell-renderers/` (repo convention) rather than the prompt's suggested `data-table/column-renderers/` path; all 3 column-type registries were still updated correctly — no runtime impact.
- **Known issues opened**: ISSUE-1 through ISSUE-11 (ISSUE-1..6 were pre-flagged in §⑫; ISSUE-7..11 newly surfaced during build — see table above).
- **Known issues closed**: ISSUE-12 was considered RESOLVED in-session (post-map projection vs Mapster config is intentional to avoid joins in expression tree).
- **Post-build alignment checks (orchestrator, pre-COMPLETED)**:
  - GQL field name alignment BE↔FE: ✓ (`deleteDonationInKind` / `toggleDonationInKind` / `donationInKindSummary` match exactly; `donationInKindId: Int!` arg matches).
  - GridComponentName renderer coverage: ✓ (BE seed uses `text-bold`, `text-truncate`, `DateOnlyPreview`, `status-badge`, `category-badge` — all 5 resolve in FE flow/component-column.tsx switch).
  - Variant B compliance: ✓ (FlowDataTableStoreProvider@60 wraps ScreenHeader@169 + widgets + FlowDataTableContainer showHeader={false}@221 in index-page.tsx).
  - UI uniformity grep (5 patterns): all 0 matches in new files.
  - No hot-patch required this session (contrast SMSTemplate #29 which needed a post-parallel-build rename of 7 params + 1 method).
- **Next step**: User actions per §⑪ acceptance: (1) no migration needed — schema unchanged; (2) apply DB seed SQL; (3) `dotnet build` (verify no regressions); (4) `pnpm dev` + navigate to `/[lang]/crm/donation/donationinkind`; (5) full E2E per §⑪ — especially drawer open/close on row click, Complete Valuation flow PEN→ACT, Photos 2-attachment limit, Edit button hidden for Valued records, legacy `donationinkindcreate` / `donationinkindupdate` routes return 404.