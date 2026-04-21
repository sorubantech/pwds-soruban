---
screen: ReceiptBook
registry_id: 66
module: Field Collection
status: PROMPT_READY
scope: ALIGN
screen_type: MASTER_GRID
complexity: High
new_module: NO
planned_date: 2026-04-20
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed
- [x] Business rules extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized
- [ ] User Approval received
- [ ] Backend code aligned (entity + DTOs + queries + commands)
- [ ] Backend wiring complete
- [ ] Frontend code aligned (data-table + modals + tracking panel + KPI cards)
- [ ] Frontend wiring complete
- [ ] DB Seed script corrected (menu re-parented from DONATIONSETUP → CRM_FIELDCOLLECTION; GridFormSchema regenerated with new fields)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/crm/fieldcollection/receiptbook`
- [ ] CRUD flow: Create → Read → Update → Toggle → Delete
- [ ] KPI cards render: Total Books, Total Receipts, Active Ambassadors, Running Low
- [ ] Filter bar: search + Status / Ambassador / Branch / Usage dropdowns
- [ ] Grid columns render incl. computed Used/Voided/Remaining + usage bar + Status badge
- [ ] Create Book modal: auto BookNo, Serial Start/End, Book Size (50/100/custom), Assign To (optional), Notes
- [ ] Bulk Create modal: preview + generate N books
- [ ] Assign modal: assign ambassador → auto-fills branch
- [ ] Tracking panel opens on Track action and shows per-receipt status (Used/Voided/Unused/Gap)
- [ ] DB Seed: menu visible under CRM → Field Collection → Receipt Books

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: ReceiptBook
Module: CRM (Field Collection)
Schema: `fund`
Group: FieldCollection (Models: `FieldCollectionModels`, Schemas: `FieldCollectionSchemas`, Business: `FieldCollectionBusiness`, Endpoints: `FieldCollection`)

Business: Receipt Book tracks the physical booklet inventory used by field-collection ambassadors. NGOs that do doorstep / community collection issue pre-printed, pre-numbered paper receipts; each book holds a continuous range of receipt numbers (e.g., book RB-045 covers receipts 4501–4600). Admins at HQ create books (individually or in bulk), assign them to an ambassador tied to a branch, and track usage over time — how many receipts were used, voided, remain unused, and whether there are gaps (missing paper receipts that must be investigated). Ambassadors record each collection against a specific receipt number (captured separately in `ReceiptBookTransaction` and linked to `GlobalReceiptDonation`). The status of a book (In Stock / Issued / Running Low / Almost Full / Completed / Cancelled) is derived from its assignment state and used-receipt percentage.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Existing entity needs field additions to match mockup. Audit columns (CreatedBy, CreatedDate, etc.) inherited from `Entity` base.

Table: `fund."ReceiptBooks"`

**Existing fields (keep as-is):**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ReceiptBookId | int | — | PK | — | Identity, auto-increment |
| TrustId | int | — | YES | — | Multi-tenant trust scope |
| CompanyId | int | — | YES | app.Companies | From HttpContext |
| BookNo | string | 50 | YES | — | Human-readable code, e.g., `RB-045` — unique per company |
| ReceiptStartNo | long | — | YES | — | First receipt serial in the book (e.g., 4501) |
| ReceiptEndNo | long | — | YES | — | Last receipt serial (e.g., 4600) |
| ReceiptCount | int | — | YES | — | `ReceiptEndNo - ReceiptStartNo + 1` (auto-calculated) |

**New fields to ADD (alignment with mockup):**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| StaffId | int? | — | NO | app.Staffs | Assigned ambassador. NULL → "In Stock". Set when book is issued. |
| BranchId | int? | — | NO | app.Branches | Auto-filled from the assigned ambassador's `Staff.BranchId`. Cached on the book for grid filtering. |
| IssuedDate | DateTime? | — | NO | — | When the book was assigned to an ambassador. NULL when In Stock. |
| Notes | string | 500 | NO | — | Free-text admin notes entered at creation |

**Computed / not stored** (derived at query time or client-side):

| Concept | Source |
|---------|--------|
| UsedCount | `COUNT(ReceiptBookTransaction WHERE ReceiptStatus = 'USED')` |
| VoidedCount | `COUNT(ReceiptBookTransaction WHERE ReceiptStatus = 'VOIDED')` |
| GapCount | Count of missing receipt numbers in `[ReceiptStartNo..ReceiptEndNo]` that have no transaction row at all (integrity anomaly) |
| RemainingCount | `ReceiptCount - UsedCount - VoidedCount` |
| UsagePct | `(UsedCount + VoidedCount) / ReceiptCount * 100` |
| BookStatusCode | `CANCELLED` if `IsActive=false` → else `IN_STOCK` if `StaffId IS NULL` → else `COMPLETED` if `UsagePct == 100` → else `ALMOST_FULL` if `UsagePct >= 90` → else `RUNNING_LOW` if `UsagePct >= 75` → else `ISSUED` |

**Child Entities** (already exists — do NOT recreate):

| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| ReceiptBookTransaction | 1:Many via `ReceiptBookId` | `ReceiptBookNo` (the individual receipt serial), `ReceiptStatusId` (FK MasterData), `CancelReason` |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (Include + navigation) + Frontend Developer (ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| StaffId | Staff | [PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Staff.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Staff.cs) | `staffs` (const `STAFFS_QUERY`) | `staffName` | `StaffResponseDto` |
| BranchId | Branch | [PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Branch.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Branch.cs) | `branches` (const `BRANCHES_QUERY`) | `branchName` | `BranchResponseDto` |
| CompanyId | Company | Base.Domain/Models/ApplicationModels/Company.cs | N/A — from HttpContext | `companyName` | `CompanyRequestDto` |
| ReceiptStatusId (on ReceiptBookTransaction) | MasterData | Base.Domain/Models/SharedModels/MasterData.cs | `masterDatas` (`MASTERDATAS_QUERY`) filtered by MasterDataType `RECEIPTSTATUS` | `masterDataName` | `MasterDataResponseDto` |

**FE ApiSelect wiring**:
- Assign To dropdown → `STAFFS_QUERY` + filter by `staffCategoryName = "Ambassador"` (use `advancedFilter` arg)
- Branch filter chip → `BRANCHES_QUERY` (no extra filter — all branches for the company)
- Status filter chip → static list `[IN_STOCK, ISSUED, RUNNING_LOW, ALMOST_FULL, COMPLETED, CANCELLED]` (computed, not an FK)

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `BookNo` must be unique per `CompanyId` (validate on Create + Update via `ValidateUniqueWhenCreate` / `ValidateUniqueWhenUpdate`).
- `[ReceiptStartNo, ReceiptEndNo]` ranges must NOT overlap with any existing active book in the same company (integrity: two books cannot claim the same receipt number).

**Required Field Rules:**
- `BookNo`, `ReceiptStartNo`, `ReceiptEndNo`, `ReceiptCount` are mandatory.
- `CompanyId`, `TrustId` are always set from HttpContext (not from the form).
- `StaffId`, `BranchId`, `IssuedDate`, `Notes` are optional.

**Conditional Rules:**
- If `StaffId` is provided → `BranchId` must also be set (auto-derive from `Staff.BranchId`) AND `IssuedDate = today` by default.
- If `StaffId` is NULL → `BranchId` and `IssuedDate` must also be NULL.
- `ReceiptEndNo > ReceiptStartNo` (end must be greater than start).
- `ReceiptCount == ReceiptEndNo - ReceiptStartNo + 1` (server recomputes; form shows read-only preview).

**Business Logic:**
- **Book Size presets**: mockup offers 50 / 100 / Custom — purely a UI helper to compute `ReceiptEndNo = ReceiptStartNo + size - 1`. Backend does NOT store `BookSize` — it derives from the range.
- **Auto BookNo generation**: New books get `RB-{next-sequence}` formatted from max(BookNo) per company. Surface as read-only "auto-generated" on the form (see mockup `RB-089`). Backend generates it server-side; frontend sends empty and backend fills on create.
- **Bulk Create (existing)**: `GenerateReceiptBooks` command already exists — it takes `TotalBooks`, `SheetsPerBook` (50 or 100), and optional `StartReceiptNo`, then emits N sequential books starting from the next available serial range. Keep and wire to the Bulk modal.
- **Assign action**: sets `StaffId`, derives `BranchId = Staff.BranchId`, sets `IssuedDate = now`. Implement as either a dedicated `AssignReceiptBook(bookId, staffId)` command OR reuse `UpdateReceiptBook` with the assignment fields — developer preference, but dedicated command is cleaner.
- **Reassign / Return to Stock**: row-action menu items — reuse `AssignReceiptBook` with a different staff, or `UnassignReceiptBook(bookId)` that nulls StaffId/BranchId/IssuedDate.
- **Cancel Book**: maps to Toggle (IsActive=false). Once cancelled, book cannot be reassigned. Mockup distinguishes "Cancelled" visually but mechanically it's `IsActive=false`.
- **Gap detection**: A receipt is a "gap" if its number is in the book's range but has NO corresponding `ReceiptBookTransaction` row AND preceding + following serials have been used. Implement gap count in `GetReceiptBookSummary`.

**Workflow**: None (book status is derived, not a state machine).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: MASTER_GRID
**Type Classification**: Type 3 (MASTER_GRID with summary widgets + computed grid aggregations + side panel)
**Reason**: Grid list with modal popup forms (Create Book, Bulk Create, Assign) — single route, no `?mode=` navigation. Has substantial extras: 4 KPI cards, multiple filter chips, computed-per-row aggregation columns (Used / Voided / Remaining / Usage%), AND a side panel (Tracking Panel) that renders per-receipt detail on demand. Not FLOW because there is no full-page view per record — everything is a modal or an inline expandable panel.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — already exists, needs field alignment
- [ ] Nested child creation — N/A (ReceiptBookTransaction is populated by donation flow, not by book CRUD)
- [x] Multi-FK validation (`ValidateForeignKeyRecord` for StaffId, BranchId when not null)
- [x] Unique validation — `BookNo` per Company + range overlap check
- [ ] File upload command — N/A
- [x] Custom business rule validators — range overlap, BookNo sequence, ambassador→branch derivation
- [x] Summary query (`GetReceiptBookSummary` — 4 KPI cards)
- [x] Custom query for per-receipt tracking (`GetReceiptBookTransactionsByBookId` — already has `GetReceiptBookTransaction` queries, verify they can filter by book)
- [x] Bulk create mutation (existing `GenerateReceiptBooks`)
- [x] Assign / Unassign mutation (new, or via Update)

**Frontend Patterns Required:**
- [x] `AdvancedDataTable` (existing component — already imported)
- [x] RJSF Modal Form (driven by GridFormSchema from DB seed — for standard Create/Edit)
- [x] Custom modals — Bulk Create modal (not a standard RJSF modal), Assign modal (small dedicated dialog)
- [ ] File upload widget — N/A
- [x] Summary cards / count widgets — 4 KPI cards above the grid
- [x] Grid aggregation columns — Used, Voided, Remaining, Usage (computed per-row)
- [x] Info panel / side panel — Tracking Panel shows per-receipt status on "Track" action
- [ ] Drag-to-reorder — N/A
- [ ] Click-through filter — Ambassador column links to Ambassador list (noted as a link with accent color in mockup — implement as clickable link that navigates to `crm/fieldcollection/ambassadorlist`)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Grid/List View

**Display Mode**: `table`

**Layout Variant**: `widgets-above-grid+side-panel` — FE Dev uses **Variant B**: `<ScreenHeader>` at top, then KPI widget row, then `<DataTableContainer showHeader={false}>`, with the side Tracking Panel injected into the page layout (appears below the grid or as a right-docked panel when triggered). MANDATORY to avoid duplicate headers.

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Book ID | bookNo | text (bold) | 100px | YES | Primary identifier |
| 2 | Serial Range | — (computed) | text `{receiptStartNo}–{receiptEndNo}` | 140px | NO | Client-side concatenation |
| 3 | Total | receiptCount | number | 70px | YES | — |
| 4 | Used | usedCount | number (computed) | 70px | YES | From `ReceiptBookTransaction` aggregation |
| 5 | Voided | voidedCount | number (computed) | 70px | YES | — |
| 6 | Remaining | remainingCount | number (color-coded) | 90px | YES | Green if ≥40%, amber if 15-40%, red if <15%, black if 0 |
| 7 | Usage | usagePct | progress bar | 100px | NO | `<UsageBar>` component — green/amber/red fill mirroring the Remaining color logic |
| 8 | Ambassador | staff.staffName | link | 140px | YES | Links to `crm/fieldcollection/ambassadorlist?staffId={id}` when present. Shows "— (Unassigned)" when null. |
| 9 | Branch | branch.branchName | text | 100px | YES | From cached `BranchId`. Shows "—" when null. |
| 10 | Issued Date | issuedDate | date (`MMM d, yyyy`) | 110px | YES | "—" when null |
| 11 | Status | bookStatusCode | badge | 120px | YES | Pill badge: In Stock (blue), Issued (green), Running Low (amber), Almost Full (red), Completed (green-check), Cancelled (grey) |
| 12 | Actions | — | button cluster | 180px | NO | View, Track/Audit (accent), ⋮ overflow menu |

**Row Actions (column 12)**:
- `View` — opens Edit modal in read-only mode
- `Track` (for Issued / Running Low / Almost Full) — opens the tracking side panel for that book
- `Audit` (for Completed books — same as Track, relabeled)
- `Assign` (only for In Stock books) — opens Assign modal
- `⋮` overflow dropdown:
  - View Details
  - Reassign (only if Issued)
  - Return to Stock (only if Issued)
  - Cancel Book
  - Print Cover Sheet — `SERVICE_PLACEHOLDER` (no PDF generator yet)

**Search/Filter Fields (filter bar above grid)**:
- Search box: searches by `bookNo`, serial range, assigned `staffName` (server-side via `searchTerm`)
- Status select: `All Status / In Stock / Issued / Completed / Cancelled` → maps to computed `bookStatusCode` (apply client-side filter OR pass as advancedFilter rule)
- Ambassador select: `All Ambassadors / {staff list filtered by Ambassador category}` → advancedFilter on `staffId`
- Branch select: `All Branches / {branch list}` → advancedFilter on `branchId`
- Usage select: `All Usage / Running Low (>75%) / Almost Full (>90%) / Full (100%)` → maps to computed `usagePct` bucket (client-side filter on fetched page)
- Clear Filters button — resets all selects

**Grid Actions (header bar)**:
- `+ Create Book` (primary) → opens Create Book modal
- `Bulk Create` (outline) → opens Bulk Create modal
- `Export Inventory` (outline) → triggers export (standard `AdvancedDataTable` export handler)

### RJSF Modal Form — "Create Book"

> Driven by `GridFormSchema` in DB seed. FE dev does NOT hand-write this form; regenerate the schema.

**Form Sections** (in order):
| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | Identity | 1-column | bookNo (read-only "auto-generated" hint), notes (optional) |
| 2 | Serial Range | 2-column | receiptStartNo, receiptEndNo |
| 3 | Book Size | inline radio group | bookSize radio (50 / 100 / Custom) — FE-only helper, computes receiptEndNo |
| 4 | Receipt Count | 1-column | receiptCount (read-only, auto-calc preview) |
| 5 | Assignment | 1-column | staffId (optional "Keep in Stock" default), branchId (auto-filled, read-only) |

**Field Widget Mapping**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| bookNo | text (disabled) | "Auto-generated" | read-only | Server-assigned on Create |
| receiptStartNo | NumberWidget | "e.g., 8901" | required, min 1 | — |
| receiptEndNo | NumberWidget | "e.g., 9000" | required, min `receiptStartNo+1` | — |
| receiptCount | NumberWidget (disabled) | "Auto-calculated" | read-only | `endNo - startNo + 1` |
| staffId | ApiSelectV2 | "Keep in Stock (default)" | optional | Query: `STAFFS_QUERY` filtered to Ambassador category |
| branchId | ApiSelectV2 (disabled) | "Auto-filled from ambassador" | optional | Reflects `staff.branchId` when staff picked |
| notes | textarea | "Optional notes…" | max 500 | — |

**Edit mode**: same schema, all fields editable except `bookNo` (always read-only after creation).

### Custom Modal — "Bulk Create Receipt Books"

Not a standard RJSF modal. Hand-built dialog with:
| Field | Widget | Default |
|-------|--------|---------|
| numberOfBooks | number input | 10 |
| startingSerial | number input | `{nextAvailableSerial}` |
| bookSize | radio (50 / 100) | 100 |
| preview | read-only list | Computed on the fly from the three inputs above — shows up to 10 previews `RB-{nextNo} / {start}–{end}` + summary `N books · X total receipts` |

Submit button: `Create N Books` → calls `GENERATE_RECEIPTBOOKS_MUTATION` (already exists).

### Custom Modal — "Assign Book"

Small dialog (`modal-sm`):
| Field | Widget | Notes |
|-------|--------|-------|
| bookLabel | read-only | "RB-086 (8601–8700)" format |
| staffId | ApiSelectV2 | Required. Ambassador list. On select, branch is derived server-side. |

Submit button: `Assign Book` → calls `AssignReceiptBook` (or Update with assignment fields).

### Page Widgets & Summary Cards

**Widgets**: 4 KPI cards above the grid.

| # | Widget Title | Value Source | Display Type | Position | Subtitle |
|---|-------------|-------------|-------------|----------|----------|
| 1 | Total Books | `summary.totalBooks` | count | col 1 | `In Stock: {inStock} · Issued: {issued} · Completed: {completed}` |
| 2 | Total Receipts | `summary.totalReceipts` | count | col 2 | `Used: {used} · Remaining: {remaining} · Voided: {voided} (danger) · Gaps: {gaps} (danger)` |
| 3 | Active Ambassadors with Books | `summary.ambassadorsWithBooks` / `summary.totalAmbassadors` | ratio | col 3 | `{needNewBooks} need new books` (warning) |
| 4 | Books Running Low (>75% used) | `summary.booksRunningLow` | count | col 4 | `Need reorder` (warning) |

Icons per mockup (FE Dev uses @iconify Phosphor equivalents, not font-awesome): Book → `ph:book`, Receipt → `ph:receipt`, Ambassador → `ph:person-simple-walk`, Warning → `ph:warning-circle`.

**Summary GQL Query**:
- Query name: `GetReceiptBookSummary` (GQL field: `receiptBookSummary`)
- Returns: `ReceiptBookSummaryDto` with fields:
  - `totalBooks`, `inStockCount`, `issuedCount`, `completedCount`, `cancelledCount`
  - `totalReceipts`, `usedCount`, `remainingCount`, `voidedCount`, `gapCount`
  - `ambassadorsWithBooks`, `totalAmbassadors`, `ambassadorsNeedingBooks`
  - `booksRunningLow` (count where usagePct >= 75)
- Must be added to `ReceiptBookQueries.cs`.

### Grid Aggregation Columns

> Per-row computed values (NOT footer totals). Implement via LINQ subquery (EF) in `GetReceiptBooksQuery`.

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Used | Count of USED transactions | `ReceiptBookTransaction` WHERE `ReceiptStatus.MasterDataCode='USED'` | LINQ subquery per row |
| Voided | Count of VOIDED transactions | `ReceiptBookTransaction` WHERE `ReceiptStatus.MasterDataCode='VOIDED'` | LINQ subquery per row |
| Remaining | `receiptCount - used - voided` | derived | Project in DTO |
| Usage | `(used + voided) / receiptCount * 100` | derived | Project in DTO |
| BookStatusCode | See § ② "BookStatusCode" derivation | derived | Project in DTO using `case when…` |

`ReceiptBookResponseDto` must expose: `usedCount`, `voidedCount`, `remainingCount`, `usagePct`, `bookStatusCode`, `staff { staffId, staffName }`, `branch { branchId, branchName }`.

### Side Panels / Info Displays

**Side Panel**: Tracking Panel (receipt-level detail for a single book).

| Panel Section | Fields / Content | Trigger |
|--------------|------------------|---------|
| Header | `Book: {bookNo} ({startNo}–{endNo})` + subtitle `{staffName} · {branchName} · {usedCount} of {total} used` | Opens on `Track` or `Audit` row action |
| Receipt Table | Columns: Receipt #, Date, Donor (link), Amount, Status. Status values: Used (green check), Voided (red strikethrough), Unused (grey square), Gap (red pill `?` — entire row highlighted) | Fetched when panel opens |
| Close button | `✕ Close` — hides the panel | User click |

**Data source**: `ReceiptBookTransaction` joined to `GlobalReceiptDonation` (existing entity, provides donor name + amount + date). A new query `GetReceiptBookTrackingByBookId(receiptBookId)` returns an array of rows, one per receipt number in `[startNo..endNo]`, with status derived from whether a transaction exists and its `ReceiptStatus`. Gaps = numbers in the range with no row.

FE component: a collapsible `<ReceiptTrackingPanel>` below the grid (hidden by default, state managed in page component). Default implementation: inline panel below grid; responsive breakpoint ≥lg can dock it to the right.

### User Interaction Flow

1. Page loads → 4 KPI cards render (summary query) → grid loads page 1
2. Admin clicks `+ Create Book` → Create modal opens with auto bookNo preview, empty serial range, `Keep in Stock` default
3. Admin fills range (or selects Book Size preset to auto-compute end) → saves → grid refreshes + success toast
4. Admin clicks `Bulk Create` → Bulk modal → adjusts count/size/start → preview updates live → submits → `GenerateReceiptBooks` runs → grid + KPIs refresh
5. On an `In Stock` row, admin clicks `Assign` → Assign modal → picks ambassador → branch auto-derived → submits → book moves to `Issued` status
6. On an `Issued` row, admin clicks `Track` → Tracking Panel slides in below the grid → shows 100 rows one per receipt serial, colored by status
7. Admin clicks a Donor link in the tracking panel → navigates to contact detail (`crm/contact/allcontacts?contactId={id}`)
8. Admin clicks `Ambassador` in grid → navigates to Ambassador list (prefilter by staff)
9. Overflow menu `Return to Stock` → confirm dialog → unassigns → book back to `In Stock`
10. Overflow menu `Cancel Book` → confirm dialog → toggles `IsActive=false` → badge shows `Cancelled`
11. Filter bar changes → grid re-queries with updated advancedFilter / search

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical `ContactType` reference to `ReceiptBook`. Use when adapting code-reference files.

**Canonical Reference**: `ContactType` (MASTER_GRID)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | ReceiptBook | Entity/class name |
| contactType | receiptBook | Variable/field names |
| ContactTypeId | ReceiptBookId | PK field |
| ContactTypes | ReceiptBooks | Table name, collection names |
| contact-type | receipt-book | FE kebab-case (not used in route — see below) |
| contacttype | receiptbook | FE folder, import paths, URL segment |
| CONTACTTYPE | RECEIPTBOOK | Grid code, menu code |
| corg | fund | DB schema |
| Corg | FieldCollection | Backend group name |
| CorgModels | FieldCollectionModels | Namespace suffix |
| CONTACT | CRM_FIELDCOLLECTION | Parent menu code |
| CRM | CRM | Module code |
| crm/contact/contacttype | crm/fieldcollection/receiptbook | FE route path |
| corg-service | fieldcollection-service | FE service folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> All paths below EXIST already (ALIGN scope) — modify in place, do not regenerate unless noted.

### Backend Files (existing — modify for alignment)

| # | File | Path | Change type |
|---|------|------|-------------|
| 1 | Entity | [Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs) | ADD fields: `StaffId?`, `BranchId?`, `IssuedDate?`, `Notes`, navigation `Staff`, `Branch`, `ICollection<ReceiptBookTransaction>` |
| 2 | EF Config | [Base.Infrastructure/Data/Configurations/FieldCollectionConfigurations/ReceiptBookConfiguration.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/FieldCollectionConfigurations/ReceiptBookConfiguration.cs) | ADD FK configs for Staff (HasOne.WithMany.OnDelete Restrict) and Branch; ADD `Notes` length; mark `IssuedDate` nullable |
| 3 | Schemas (DTOs) | [Base.Application/Schemas/FieldCollectionSchemas/ReceiptBookSchemas.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/FieldCollectionSchemas/ReceiptBookSchemas.cs) | ADD `StaffId?`, `BranchId?`, `IssuedDate?`, `Notes` to Request + Response; ADD to Response `UsedCount`, `VoidedCount`, `RemainingCount`, `UsagePct`, `BookStatusCode`, `StaffName`, `BranchName`; ADD `ReceiptBookSummaryDto`, `ReceiptBookTrackingRowDto`, `AssignReceiptBookRequestDto` |
| 4 | Create Command | Base.Application/Business/FieldCollectionBusiness/ReceiptBooks/Commands/CreateReceiptBook.cs | MODIFY: accept new fields; auto-generate BookNo if empty; validate range non-overlap; derive BranchId from StaffId |
| 5 | Update Command | Base.Application/Business/FieldCollectionBusiness/ReceiptBooks/Commands/UpdateReceiptBook.cs | MODIFY: accept new fields; re-derive BranchId if StaffId changes |
| 6 | Delete Command | .../Commands/DeleteReceiptBook.cs | No change (soft delete only) |
| 7 | Toggle Command | .../Commands/ToggleReceiptBook.cs | No change (maps to Cancel Book) |
| 8 | **Assign Command** (NEW) | Base.Application/Business/FieldCollectionBusiness/ReceiptBooks/Commands/AssignReceiptBook.cs | NEW file — sets StaffId, BranchId, IssuedDate |
| 9 | **Unassign Command** (NEW) | .../Commands/UnassignReceiptBook.cs | NEW file — nulls assignment fields (Return to Stock) |
| 10 | GetAll Query | .../Queries/GetReceiptBooks.cs | MODIFY: `.Include(r => r.Staff).Include(r => r.Branch)`; project `UsedCount` / `VoidedCount` / etc. via subquery; compute `BookStatusCode` via case expression; support advancedFilter on `staffId`/`branchId`/computed status |
| 11 | GetById Query | .../Queries/GetReceiptBookById.cs | MODIFY: same includes + computed fields |
| 12 | **Summary Query** (NEW) | .../Queries/GetReceiptBookSummary.cs | NEW — aggregates for 4 KPI cards |
| 13 | **Tracking Query** (NEW or extend ReceiptBookTransaction) | .../ReceiptBookTransactions/Queries/GetReceiptBookTrackingByBookId.cs | NEW — returns per-receipt row list for Tracking Panel |
| 14 | Mutations endpoint | [Base.API/EndPoints/FieldCollection/Mutations/ReceiptBookMutations.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/FieldCollection/Mutations/ReceiptBookMutations.cs) | ADD `AssignReceiptBook` + `UnassignReceiptBook` endpoints |
| 15 | Queries endpoint | [Base.API/EndPoints/FieldCollection/Queries/ReceiptBookQueries.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/FieldCollection/Queries/ReceiptBookQueries.cs) | ADD `GetReceiptBookSummary` + `GetReceiptBookTrackingByBookId` endpoints |

**Reuse existing**: `ReceiptBookMaster*` (bulk generation — `GenerateReceiptBooks`), `ReceiptBookTransaction*` (per-receipt detail). Do NOT duplicate.

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` | Verify `DbSet<ReceiptBook>` and `DbSet<ReceiptBookTransaction>` already registered (should be — check and fix if missing) |
| 2 | `FieldCollectionDbContext.cs` (if module exists — else `IApplicationDbContext`) | Same verification |
| 3 | `DecoratorProperties.cs` | `DecoratorFieldCollectionModules` entry already present — add `Staff`, `Branch` to decorator Include chain for ReceiptBook |
| 4 | `FieldCollectionMappings.cs` (or equivalent) | Mapster config for new fields + Summary DTO |

### Frontend Files (existing — modify for alignment)

| # | File | Path | Change type |
|---|------|------|-------------|
| 1 | DTO Types | [src/domain/entities/fieldcollection-service/ReceiptBookDto.ts](PSS_2.0_Frontend/src/domain/entities/fieldcollection-service/ReceiptBookDto.ts) | ADD: `staffId?`, `branchId?`, `issuedDate?`, `notes?`, `usedCount`, `voidedCount`, `remainingCount`, `usagePct`, `bookStatusCode`, `staff?`, `branch?`; ADD interfaces: `ReceiptBookSummaryDto`, `ReceiptBookTrackingRowDto`, `AssignReceiptBookRequestDto` |
| 2 | GQL Query | [src/infrastructure/gql-queries/fieldcollection-queries/ReceiptBookQuery.ts](PSS_2.0_Frontend/src/infrastructure/gql-queries/fieldcollection-queries/ReceiptBookQuery.ts) | MODIFY `RECEIPTBOOKS_QUERY` to include new computed fields + staff / branch objects; ADD `RECEIPTBOOK_SUMMARY_QUERY`; ADD `RECEIPTBOOK_TRACKING_QUERY` |
| 3 | GQL Mutation | [src/infrastructure/gql-mutations/fieldcollection-mutations/ReceiptBookMutation.ts](PSS_2.0_Frontend/src/infrastructure/gql-mutations/fieldcollection-mutations/ReceiptBookMutation.ts) | MODIFY `CREATE` + `UPDATE` to include new fields; ADD `ASSIGN_RECEIPTBOOK_MUTATION` + `UNASSIGN_RECEIPTBOOK_MUTATION` |
| 4 | Page Config | [src/presentation/pages/crm/fieldcollection/receiptbook.tsx](PSS_2.0_Frontend/src/presentation/pages/crm/fieldcollection/receiptbook.tsx) | REWRITE: add `<ScreenHeader>` + `<ReceiptBookKpiCards>` + `<ReceiptBookDataTable>` + `<ReceiptTrackingPanel>` in a layout column |
| 5 | Index Page Component (NEW) | src/presentation/components/page-components/crm/fieldcollection/receiptbook/index-page.tsx | NEW — composes KPI + grid + panel |
| 6 | Data Table Component | [src/presentation/components/page-components/crm/fieldcollection/receiptbook/data-table.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/fieldcollection/receiptbook/data-table.tsx) | MODIFY: add custom grid column renderers for `usage-bar`, `status-badge`, `remaining-color`; wire `showHeader={false}` if using Variant B; add custom row actions (Track, Assign) |
| 7 | KPI Cards (NEW) | src/presentation/components/page-components/crm/fieldcollection/receiptbook/kpi-cards.tsx | NEW — 4-card widget row reading `RECEIPTBOOK_SUMMARY_QUERY` |
| 8 | Tracking Panel (NEW) | src/presentation/components/page-components/crm/fieldcollection/receiptbook/tracking-panel.tsx | NEW — per-receipt detail panel, reads `RECEIPTBOOK_TRACKING_QUERY`, open/close state |
| 9 | Bulk Create Modal (NEW) | src/presentation/components/page-components/crm/fieldcollection/receiptbook/bulk-create-modal.tsx | NEW — hand-built dialog over `GENERATE_RECEIPTBOOKS_MUTATION` |
| 10 | Assign Modal (NEW) | src/presentation/components/page-components/crm/fieldcollection/receiptbook/assign-modal.tsx | NEW — small dialog over `ASSIGN_RECEIPTBOOK_MUTATION` |
| 11 | Route Page | [src/app/[lang]/crm/fieldcollection/receiptbook/page.tsx](PSS_2.0_Frontend/src/app/[lang]/crm/fieldcollection/receiptbook/page.tsx) | No change — delegates to `<ReceiptBookPageConfig>` |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | [src/application/configs/data-table-configs/fieldcollection-service-entity-operations.ts](PSS_2.0_Frontend/src/application/configs/data-table-configs/fieldcollection-service-entity-operations.ts) | Existing `RECEIPTBOOK` entry already — no structural change. Ensure new mutations if added are wired. |
| 2 | Sidebar menu config | Re-seed via DB seed (menu moves from DONATIONSETUP → CRM_FIELDCOLLECTION) — no code change on FE side; verify it appears after DB seed runs |
| 3 | `fieldcollection-queries/index.ts` + `fieldcollection-mutations/index.ts` | Already re-export all files — ensure new query / mutation exports remain |

### DB Seed Script (CRITICAL — needs regeneration)

| # | File | Path | Change type |
|---|------|------|-------------|
| 1 | Seed script | [PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/ReceiptBook-sqlscripts.sql](PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/ReceiptBook-sqlscripts.sql) | REWRITE: (a) change `ParentMenuId` lookup from `DONATIONSETUP` → `CRM_FIELDCOLLECTION`; (b) change `ModuleId` lookup from `DONATION` → `CRM`; (c) change `MenuUrl` from `donation/donationsetup/receiptbook` → `crm/fieldcollection/receiptbook`; (d) add `Fields` entries for `staffId`, `branchId`, `issuedDate`, `notes`, `bookStatusCode` (and reference them in `GridFields`); (e) regenerate `GridFormSchema` JSON to include all new form fields and the Assignment section |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Receipt Book
MenuCode: RECEIPTBOOK
ParentMenu: CRM_FIELDCOLLECTION
Module: CRM
MenuUrl: crm/fieldcollection/receiptbook
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: RECEIPTBOOK
---CONFIG-END---
```

> **Note to user**: existing DB seed targets `DONATIONSETUP / DONATION / donation/donationsetup/receiptbook`. The rewrite moves it to `CRM_FIELDCOLLECTION / CRM / crm/fieldcollection/receiptbook` per [MODULE_MENU_REFERENCE.md](.claude/screen-tracker/MODULE_MENU_REFERENCE.md). This is the correct home since Field Collection is a CRM sub-module.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose.

**GraphQL Types:**
- Query type: `ReceiptBookQueries`
- Mutation type: `ReceiptBookMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `receiptBooks` (existing, enhance) | `PaginatedApiResponse<ReceiptBookResponseDto>` | `pageSize`, `pageIndex`, `sortDescending`, `sortColumn`, `searchTerm`, `advancedFilter` |
| `receiptBookById` (existing, enhance) | `BaseApiResponse<ReceiptBookResponseDto>` | `receiptBookId` |
| `receiptBookSummary` (NEW) | `BaseApiResponse<ReceiptBookSummaryDto>` | — |
| `receiptBookTrackingByBookId` (NEW) | `BaseApiResponse<List<ReceiptBookTrackingRowDto>>` | `receiptBookId` |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createReceiptBook` (existing, enhance) | `ReceiptBookRequestDto` | int (new ID) |
| `updateReceiptBook` (existing, enhance) | `ReceiptBookRequestDto` | int |
| `deleteReceiptBook` (existing) | `receiptBookId: Int` | int |
| `activateDeactivateReceiptBook` (existing) | `receiptBookId: Int` | int |
| `assignReceiptBook` (NEW) | `AssignReceiptBookRequestDto { receiptBookId, staffId }` | `ReceiptBookResponseDto` |
| `unassignReceiptBook` (NEW) | `receiptBookId: Int` | `ReceiptBookResponseDto` |
| `generateReceiptBooks` (existing) | `GenerateReceiptBooksRequestDto` | `GenerateReceiptBooksResponseDto` |

**Response DTO Fields — `ReceiptBookResponseDto`** (what FE receives):
| Field | Type | Notes |
|-------|------|-------|
| receiptBookId | number | PK |
| trustId | number | scope |
| companyId | number | scope |
| bookNo | string | `RB-045` |
| receiptStartNo | number (long) | — |
| receiptEndNo | number (long) | — |
| receiptCount | number | end - start + 1 |
| staffId | number \| null | assigned ambassador |
| branchId | number \| null | derived from staff |
| issuedDate | string (ISO) \| null | — |
| notes | string \| null | — |
| usedCount | number | computed |
| voidedCount | number | computed |
| remainingCount | number | computed |
| usagePct | number | 0–100 |
| bookStatusCode | string | `IN_STOCK` \| `ISSUED` \| `RUNNING_LOW` \| `ALMOST_FULL` \| `COMPLETED` \| `CANCELLED` |
| staff | `{ staffId, staffName }` \| null | navigation |
| branch | `{ branchId, branchName }` \| null | navigation |
| company | `{ companyName }` | navigation |
| isActive | boolean | inherited |

**Response DTO — `ReceiptBookSummaryDto`**:
| Field | Type |
|-------|------|
| totalBooks | number |
| inStockCount | number |
| issuedCount | number |
| completedCount | number |
| cancelledCount | number |
| totalReceipts | number |
| usedCount | number |
| remainingCount | number |
| voidedCount | number |
| gapCount | number |
| ambassadorsWithBooks | number |
| totalAmbassadors | number |
| ambassadorsNeedingBooks | number |
| booksRunningLow | number |

**Response DTO — `ReceiptBookTrackingRowDto`**:
| Field | Type |
|-------|------|
| receiptNo | number (long) |
| statusCode | string (`USED` \| `VOIDED` \| `UNUSED` \| `GAP`) |
| transactionDate | string (ISO) \| null |
| donorContactId | number \| null |
| donorName | string \| null |
| amount | number \| null |
| currencyCode | string \| null |
| cancelReason | string \| null |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors; migrations generated for new ReceiptBook fields and applied successfully
- [ ] `pnpm dev` — page loads at `/en/crm/fieldcollection/receiptbook` (plus other supported locales)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] 4 KPI cards render with correct live counts (totalBooks, totalReceipts, ambassadors, runningLow)
- [ ] Grid loads with columns: Book ID, Serial Range, Total, Used, Voided, Remaining (color-coded), Usage (progress bar), Ambassador (link), Branch, Issued Date, Status (badge), Actions
- [ ] Search filters by bookNo / serial range / ambassador name
- [ ] Status / Ambassador / Branch / Usage filter dropdowns work (advancedFilter / client filter mix)
- [ ] Clear Filters button resets all filters
- [ ] Create Book modal: bookNo auto-generated (read-only), serial start/end, book size radio (50/100/custom), receipt count auto-calc, optional Assign To (ambassador), branch auto-fills, notes textarea
- [ ] Create → row appears in grid immediately; KPI refreshes
- [ ] Edit row → modal pre-fills with all fields; bookNo remains read-only; save updates grid
- [ ] Bulk Create modal: N books + starting serial + size → preview list renders → submit generates N books via existing `generateReceiptBooks`
- [ ] Assign modal (on In Stock row): pick ambassador → branch auto-derives → book moves to Issued
- [ ] Track action opens Tracking Panel: shows per-receipt rows colored by status (Used/Voided/Unused/Gap); Close hides it
- [ ] Donor links in tracking panel navigate to `crm/contact/allcontacts?contactId=…`
- [ ] Ambassador links in grid navigate to `crm/fieldcollection/ambassadorlist`
- [ ] Cancel Book (overflow) → toggle to IsActive=false → status badge shows Cancelled
- [ ] Return to Stock (overflow, only for Issued) → book returns to In Stock
- [ ] Delete → soft delete → removed from grid
- [ ] Permissions: BUSINESSADMIN sees all actions; lower roles gated by capabilities
- [ ] Export Inventory: triggers standard export

**Service Placeholders:**
- [ ] `Print Cover Sheet` row action → shows toast `"PDF cover sheet generation not yet implemented"` (no PDF service in codebase)

**DB Seed Verification:**
- [ ] Menu `Receipt Book` appears under `CRM → Field Collection` in sidebar (not under Donation)
- [ ] Old entry under `DONATION / DONATIONSETUP` is removed or updated
- [ ] Grid columns render correctly
- [ ] GridFormSchema renders form including new Assignment section

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **ALIGN scope** — the entity, DTOs, FE DTO, GQL queries/mutations, route page, page config, data-table component, and DB seed ALL already exist. The task is to EXTEND them with missing fields (StaffId, BranchId, IssuedDate, Notes), ADD computed aggregation fields, ADD a Summary query, ADD a Tracking query, and ADD Assign/Unassign mutations. Do NOT regenerate from scratch; modify in place.

- **DB seed re-parenting** — existing [ReceiptBook-sqlscripts.sql](PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/ReceiptBook-sqlscripts.sql) targets `DONATIONSETUP / DONATION / donation/donationsetup/receiptbook`. This is WRONG per [MODULE_MENU_REFERENCE.md](.claude/screen-tracker/MODULE_MENU_REFERENCE.md) — it belongs under `CRM_FIELDCOLLECTION / CRM / crm/fieldcollection/receiptbook`. Update all three places (menu parent, module, URL) plus regenerate the `Fields` / `GridFields` / `GridFormSchema` with the new fields.

- **Schema is `fund`, not `fcol`** — the `[Table(..., Schema = "fund")]` attribute on `ReceiptBook.cs` matches the existing AmbassadorCollection. Keep `fund` — don't introduce a new schema.

- **Group is `FieldCollection` (not `FieldCollectionModels`)** — the models folder is `FieldCollectionModels` but the business/schemas/endpoints folders are `FieldCollectionBusiness`, `FieldCollectionSchemas`, `FieldCollection` (endpoints). Follow the existing naming exactly.

- **Existing FE route at `src/app/[lang]/crm/fieldcollection/receiptbook/page.tsx`** — FE dev must reuse this, not create a new one. The current version delegates to `ReceiptBookPageConfig` — edit that component, don't replace the route.

- **Existing `ReceiptBookMaster*` files** — these are a parallel "bulk generator" pair (entity + DTO + `GenerateReceiptBooks` command) that coexists with the main ReceiptBook entity. Keep `GENERATE_RECEIPTBOOKS_MUTATION` and wire it to the Bulk Create modal — do NOT duplicate bulk logic.

- **Ambassador = Staff filtered by StaffCategory** — there is no standalone Ambassador entity. Filter `Staff` by `staffCategory.staffCategoryName = "Ambassador"` (or equivalent category code — check live DB). `Registry #67` (Ambassador) is still PARTIAL — this screen uses the Staff table directly.

- **Grid aggregation = server-computed** — Used/Voided/Remaining/UsagePct/BookStatusCode MUST be projected by the server in `GetReceiptBooks`. Do NOT compute them on the client per-row; that would require N+1 fetches against `ReceiptBookTransaction`.

- **Status filter** — "Status" dropdown values map to `bookStatusCode` strings. Since this is a computed (non-stored) field, either (a) push the filter into the server-side projection's `WHERE` clause with the same `CASE WHEN` logic, or (b) load the full filtered page and narrow on the client. Prefer (a) for large datasets.

- **Gap detection cost** — computing gaps in the Summary query requires enumerating each book's range against its transactions. For large datasets, consider caching the summary or using a materialized view. V1 implementation: brute force with `generate_series(startNo, endNo)` LEFT JOIN `ReceiptBookTransaction`. Acceptable for demo; flag for optimization later.

- **Ambassador "need new books" metric** — `summary.ambassadorsNeedingBooks` = count of active ambassadors whose assigned books are all ≥75% used. Computable via a subquery joining Staff → ReceiptBook → aggregated usage.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ `SERVICE_PLACEHOLDER`: **Print Cover Sheet** (overflow menu action) — full UI button implemented. Handler shows `"PDF cover sheet generation not yet implemented"` toast because no PDF generator service (QuestPDF/Razor-to-PDF) exists in the codebase yet.
- ⚠ `SERVICE_PLACEHOLDER`: **Export Inventory** — standard `AdvancedDataTable` export handler handles CSV/Excel; no change needed. If a custom "inventory report" format is expected later, that's a future enhancement.

Full UI must be built (all 3 modals, tracking panel, 4 KPI cards, filter bar, grid aggregation). Only the Print Cover Sheet handler is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}