---
screen: Ambassador
registry_id: 67
module: Field Collection
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO — FieldCollection group exists (fund schema, IFieldCollectionDbContext)
planned_date: 2026-04-20
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + widgets + side-panel detail)
- [x] Existing code reviewed (FE stub + existing FieldCollection group)
- [x] Business rules + territory/receipt-book workflow extracted
- [x] FK targets resolved (Staff, Branch, StaffCategory, ReceiptBook, Contact)
- [x] File manifest computed
- [x] Approval config pre-filled (AMBASSADORLIST)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (grid + widgets + FORM + DETAIL side-panel)
- [ ] User Approval received
- [ ] Backend code generated (Ambassador + child entities)
- [ ] Backend wiring complete (IFieldCollectionDbContext, DecoratorFieldCollectionModules, FieldCollectionMappings)
- [ ] Frontend code generated (view-page 3 modes + side-panel + Zustand store)
- [ ] Frontend wiring complete (entity-operations, sidebar, route)
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — `/en/crm/fieldcollection/ambassadorlist` loads (stub overwritten)
- [ ] Grid shows 12 columns with avatar cell, receipt-book progress bar, status badge, action buttons
- [ ] 4 KPI widgets render above grid: Total, Collections (Month), Avg per Ambassador, Active Receipt Books
- [ ] 4 filter dropdowns function: Branch, Territory, Status, Performance + free-text search
- [ ] Row click / "View" opens right-side 60% detail panel with 4 tabs (Overview, Territory, Collections, Receipt Books)
- [ ] `?mode=new` — empty FORM renders: Personal Info section (linked to Staff), Territory Assignment (chip picker), Initial Receipt Book (optional ApiSelect)
- [ ] `?mode=edit&id=X` — FORM pre-filled
- [ ] `?mode=read&id=X` — full-page DETAIL layout renders same 4-tab content as side-panel
- [ ] Create flow: +Add → fill form → Save → redirects to `?mode=read&id={newId}`
- [ ] Edit from detail → FORM → Save → back to detail
- [ ] Staff, Branch, StaffCategory, ReceiptBook ApiSelects load
- [ ] Receipt-book progress bar colors: green <60%, amber 60–85%, red >85%
- [ ] Grid aggregation columns populate (Collections Month, YTD, Donors Visited)
- [ ] "Assign New Book" action on Receipt Books tab adds assignment row
- [ ] "Transfer Territory" and "Assign Receipt Book" actions in 3-dot menu open modals
- [ ] "Collections" row button navigates to `/crm/fieldcollection/collectionlist?ambassadorId=X`
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] DB Seed — AMBASSADORLIST menu visible under CRM_FIELDCOLLECTION

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Ambassador (Field Ambassador List)
Module: CRM → Field Collection
Schema: `fund`
Group: `FieldCollection` (folder: FieldCollectionModels, DbContext interface: IFieldCollectionDbContext, concrete partial in ApplicationDbContext declared in `FieldDbContext.cs`, Business folder: FieldCollectionBusiness, API folder: FieldCollection, Schemas: FieldCollectionSchemas, Mappings: FieldCollectionMappings, Decorator: DecoratorFieldCollectionModules)

Business: Field Ambassadors are ground-level collection agents (typically staff members flagged for field duty) who visit donors across assigned territories, issue receipts from paper receipt books, and record cash/cheque donations in the AmbassadorCollection table. This screen is the operational roster — it lists every ambassador, their branch + territory coverage, current receipt-book burn-down, month/YTD collection totals, and donor-visit counts; operations managers use it to assign new receipt books before the current one runs out, transfer territories when an ambassador changes beat, and deactivate agents who leave. Ambassador rows are the pivot that links Staff (HR identity), Branch (org hierarchy), ReceiptBook (supply), Territory (coverage), and AmbassadorCollection (output metrics) into a single field-ops view. The detail side-panel doubles as a mini profile — Overview (personal info), Territory (map + coverage stats), Collections (monthly trend), Receipt Books (assignment history).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from HTML mockup. Audit columns (CreatedBy, CreatedDate, etc.) omitted — inherited from Entity base.
> **CompanyId is NOT a field** — FLOW screens get tenant from HttpContext.

### Primary entity — `fund."Ambassadors"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AmbassadorId | int | — | PK | — | Primary key |
| AmbassadorCode | string | 30 | YES | — | Unique per Company, auto-generated `FA-{###}` if empty |
| StaffId | int | — | YES | app.Staffs | Links ambassador ↔ Staff (source of Name/Email/Phone/EmpId) |
| BranchId | int | — | YES | app.Branches | Primary branch assignment |
| StaffCategoryId | int? | — | NO | app.StaffCategories | Role type (e.g., "Field Officer") — default from Staff.StaffCategoryId |
| JoinDate | DateTime | — | YES | — | Default: today. Separate from Staff.CreatedDate |
| PhoneOverride | string? | 30 | NO | — | If set, overrides Staff.StaffMobileNumber for field context |
| EmailOverride | string? | 100 | NO | — | If set, overrides Staff.StaffEmail |
| CompensationType | string | 20 | YES | — | Enum: `Salaried`, `Commission`, `Hybrid` — default `Salaried` |
| CommissionPercent | decimal(5,2) | — | NO | — | Required if CompensationType in (`Commission`,`Hybrid`); 0–100 |
| Status | string | 20 | YES | — | Enum: `Active`, `Inactive`, `OnLeave` — default `Active` |
| CurrentReceiptBookId | int? | — | NO | fund.ReceiptBooks | Quick-lookup for the active book (mirror of latest AmbassadorReceiptBookAssignment) |
| Notes | string? | 500 | NO | — | Free-text |

### Child entity — `fund."AmbassadorTerritories"` (1:Many)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AmbassadorTerritoryId | int | — | PK | — | |
| AmbassadorId | int | — | YES | fund.Ambassadors | Cascade delete |
| TerritoryName | string | 80 | YES | — | Free-text (e.g., "Deira", "Bur Dubai") |
| OrderBy | int | — | NO | — | Display order in territory badges |

### Child entity — `fund."AmbassadorReceiptBookAssignments"` (1:Many)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AmbassadorReceiptBookAssignmentId | int | — | PK | — | |
| AmbassadorId | int | — | YES | fund.Ambassadors | Cascade delete |
| ReceiptBookId | int | — | YES | fund.ReceiptBooks | |
| IssuedDate | DateTime | — | YES | — | |
| CompletedDate | DateTime? | — | NO | — | Set when book is 100% used |
| UsedCount | int | — | YES | — | Auto-updated from AmbassadorCollection count within receipt range |
| AssignmentStatus | string | 20 | YES | — | Enum: `Active`, `Completed`, `Revoked` |

### Schema change to existing table — `fund."AmbassadorCollections"`

> Add nullable FK so per-row aggregations (Collections Month / YTD / Donors Visited) can be computed.

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| AmbassadorId | int? | NO (nullable, backwards-compatible) | fund.Ambassadors | New column. Nullable preserves existing rows; new collection rows set it from the logged-in field agent or row-level selection |

**Children summary**
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| AmbassadorTerritory | 1:Many via AmbassadorId | TerritoryName, OrderBy |
| AmbassadorReceiptBookAssignment | 1:Many via AmbassadorId | ReceiptBookId, IssuedDate, UsedCount, AssignmentStatus |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelectV2 queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| StaffId | Staff | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Staff.cs` | GetStaffs | StaffName | StaffResponseDto |
| BranchId | Branch | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Branch.cs` | GetBranches | BranchName | BranchResponseDto |
| StaffCategoryId | StaffCategory | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/StaffCategory.cs` | GetStaffCategories | StaffCategoryName | StaffCategoryResponseDto |
| CurrentReceiptBookId / ReceiptBookId (child) | ReceiptBook | `PSS_2.0_Backend/.../Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs` | GetReceiptBooks | BookNo | ReceiptBookResponseDto |
| (Detail-panel Donor links) | Contact | `PSS_2.0_Backend/.../Base.Domain/Models/ContactModels/Contact.cs` | GetContacts | DisplayName | ContactResponseDto |

> **Note on query naming**: this backend uses `GetStaffs` / `GetBranches` style (not `GetAll{Entity}List`). The Ambassador query must follow the same pattern: **`GetAmbassadors`** and **`GetAmbassadorById`**.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `AmbassadorCode` must be unique per Company. If blank on create, auto-generate `FA-{nextSeq:000}` per Company.
- `StaffId` must be unique per Company — a Staff can be registered as an ambassador at most once (a Staff who left cannot be re-registered unless the prior record is soft-deleted).

**Required Field Rules:**
- `StaffId`, `BranchId`, `JoinDate`, `CompensationType`, `Status` are mandatory.
- At least one `AmbassadorTerritory` row is mandatory (otherwise the ambassador has no coverage).

**Conditional Rules:**
- `CommissionPercent` is required when `CompensationType` ∈ {`Commission`, `Hybrid`}; must be between 0.01 and 100 inclusive.
- `CurrentReceiptBookId` must match an `AmbassadorReceiptBookAssignment` row with `AssignmentStatus = Active` for this ambassador.
- On `Status = Inactive` transition: set all `AmbassadorReceiptBookAssignment.AssignmentStatus = Revoked` for this ambassador; null out `CurrentReceiptBookId`.

**Business Logic:**
- When a new `AmbassadorReceiptBookAssignment` is created with status `Active`, any prior `Active` assignment for the same ambassador transitions to `Completed` (only one active book per ambassador).
- `UsedCount` on an assignment = count of `AmbassadorCollection` rows where `AmbassadorId = this` AND `DonationTypeNo` between `ReceiptBook.ReceiptStartNo` and `ReceiptBook.ReceiptEndNo`.
- Phone/Email override: when `PhoneOverride`/`EmailOverride` is null, display `Staff.StaffMobileNumber` / `Staff.StaffEmail` (resolved at query time via navigation).
- `AmbassadorCode` is case-insensitive unique; store in UPPER.

**Workflow** (Status state machine):
- `Active` ⇄ `OnLeave` (reversible; no side-effects beyond UI filtering)
- `Active` / `OnLeave` → `Inactive` (revokes all receipt-book assignments)
- `Inactive` → `Active` (re-activation; does NOT auto-restore prior assignments — operator must re-assign a book)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW (with grid-side-panel quick-detail)
**Type Classification**: Transactional/workflow entity with nested children (territories + receipt-book assignments); full-page form for add/edit; grid uses widgets-above-grid variant with a side-panel quick-view.
**Reason**: Ambassador has child collections (territories, receipt-book history), compensation/status workflow, and per-row aggregations. A modal form cannot fit territory chip picker + child grid — needs full-page FORM. Detail view has 4 tabs — can be rendered as both a side-panel (from grid) and a full `?mode=read` page.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) for Ambassador
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation — AmbassadorTerritory + AmbassadorReceiptBookAssignment batched in Create/Update command
- [x] Multi-FK validation (ValidateForeignKeyRecord × 4: Staff, Branch, StaffCategory?, ReceiptBook?)
- [x] Unique validation — AmbassadorCode, (StaffId per Company)
- [x] Workflow commands — `ChangeAmbassadorStatus` (Active/OnLeave/Inactive), `AssignAmbassadorReceiptBook`, `TransferAmbassadorTerritory`
- [ ] File upload command — N/A (Staff photo inherited)
- [x] Custom business rule validators — CommissionPercent conditional, status transition side-effects
- [x] Aggregation query — `GetAmbassadorSummary` (4 KPI widgets) + per-row subqueries for CollectionsMonth / CollectionsYTD / DonorsVisited / ReceiptBook stats
- [x] Schema migration — add `AmbassadorId` (nullable FK) to `AmbassadorCollections`

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) with custom cell renderers (avatar, receipt-book progress bar, status badge)
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (for FORM layout)
- [x] Zustand store (`ambassador-store.ts`)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back + Save/Edit)
- [x] Child grid inside form — Territory chip picker + Receipt Book assignment table
- [x] Workflow status badge + action buttons — Activate / Deactivate / Set On Leave in 3-dot menu
- [ ] File upload widget — N/A
- [x] Summary cards / count widgets above grid — 4 KPIs
- [x] Grid aggregation columns — Collections (Month), Collections (YTD), Donors Visited, Receipt Book progress
- [x] **Side-panel quick-detail** (60% right drawer with 4 tabs) — opens on row click or "View"; reuses the same tab content as the `?mode=read` full-page layout (shared subcomponents)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup (`html_mockup_screens/screens/field-collection/ambassador-list.html`).

### Grid/List View

**Display Mode**: `table` (dense transactional list — default).

**Grid Layout Variant**: `widgets-above-grid+side-panel`
- FE Dev MUST use **Variant B**: `<ScreenHeader>` + 4 widget cards + `<DataTableContainer showHeader={false}>`.
- Side-panel (60% right drawer) additionally opens on row click — builds on Variant B.
- MANDATORY to avoid duplicate headers (ContactType #19 precedent).

**Page Widgets & Summary Cards** (4 KPIs above grid):

| # | Widget Title | Value Source | Display Type | Sub-text | Position |
|---|-------------|-------------|-------------|----------|----------|
| 1 | Total Ambassadors | `totalAmbassadors` | count | "Active: {n}, Inactive: {n}" | Top-left (blue icon `person-walking`) |
| 2 | Collections (This Month) | `collectionsThisMonth` | currency | "Last month: {prev} ({+/-%})" | Top-center-left (green icon `hand-holding-dollar`) |
| 3 | Avg per Ambassador | `avgPerAmbassador` | currency/month | "Top: {name} (${amount})" | Top-center-right (purple icon `chart-bar`) |
| 4 | Active Receipt Books | `activeReceiptBooks` | count | "Receipts used this month: {n}" | Top-right (amber icon `receipt`) |

**Summary GQL Query**:
- Query name: `GetAmbassadorSummary`
- Returns: `AmbassadorSummaryDto` { totalAmbassadors, activeCount, inactiveCount, onLeaveCount, collectionsThisMonth, collectionsLastMonth, monthOverMonthPercent, avgPerAmbassadorMonthly, topAmbassadorName, topAmbassadorCollectionsMonth, activeReceiptBooks, receiptsUsedThisMonth }
- Added to `AmbassadorQueries.cs` alongside `GetAmbassadors` and `GetAmbassadorById`.

**Grid Columns** (in display order from mockup — 12 cols):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | ☐ (bulk) | `_select` | checkbox | 36px | NO | Bulk selection |
| 2 | ID | `ambassadorCode` | chip (mono) | 100px | YES | e.g., "FA-001" |
| 3 | Ambassador | `_avatarName` | avatar + name | auto | YES (by staffName) | Avatar from initials of StaffName; name is cyan/accent link — opens side panel |
| 4 | Branch | `branchName` | text | 120px | YES | FK display |
| 5 | Territory | `_territoriesCsv` | text | 180px | NO | Comma-joined TerritoryName from child |
| 6 | Phone | `_phone` | text (nowrap) | 140px | NO | PhoneOverride ?? Staff.StaffMobileNumber |
| 7 | Collections (Month) | `_collectionsMonth` | currency + sub | 140px | YES | Amount (bold) + "{visits} visits" muted |
| 8 | Collections (YTD) | `_collectionsYtd` | currency | 120px | YES | Bold |
| 9 | Donors Visited | `_donorsVisited` | number | 110px | YES | Distinct ContactId count |
| 10 | Receipt Book | `_currentBook` | custom (book-id + progress bar + usage) | 140px | NO | BookNo + colored progress (green/amber/red) + "45/100 used" + ⚠ icon if >75% |
| 11 | Status | `status` | badge | 90px | YES | Active (green), Inactive (red), OnLeave (amber) |
| 12 | Actions | `_actions` | button group + kebab | 200px | NO | View / Edit / Collections + 3-dot menu |

**Per-row Aggregation Computation (BE side — LINQ subqueries or view):**
- `_collectionsMonth` = SUM(AmbassadorCollection.DonationAmount) WHERE AmbassadorId = row.Id AND CollectedDate >= startOfCurrentMonth
- `_collectionsMonthVisits` = COUNT(AmbassadorCollection) WHERE AmbassadorId = row.Id AND CollectedDate >= startOfCurrentMonth
- `_collectionsYtd` = SUM WHERE AmbassadorId AND CollectedDate >= Jan 1 of current year
- `_donorsVisited` = COUNT DISTINCT ContactId WHERE AmbassadorId
- `_currentBook` = JOIN AmbassadorReceiptBookAssignment (Active) → ReceiptBook → compute UsedCount / ReceiptCount %

**Search/Filter Fields** (4 dropdowns + free text):
| Filter | Source | Options |
|--------|--------|---------|
| (search) | free text | matches AmbassadorCode, StaffName, Territory, Phone |
| Branch | dropdown — `GetBranches` | "All Branches" + each branch |
| Territory | dropdown — distinct TerritoryName from AmbassadorTerritory | "All Territories" + each territory |
| Status | dropdown — static | All Status / Active / Inactive / OnLeave |
| Performance | dropdown — computed bucket on `_collectionsMonth` | All / Top Performers (>$3000) / Average / Below Target (<$1000) |
| — | — | "Clear Filters" text button |

**Grid Actions** (per row):
- `View` button → opens right-side **detail panel** (60% width, 4 tabs) with the ambassador's record (default behavior = in-page side-panel, NOT navigation to `?mode=read`).
- `Edit` button → navigates to `?mode=edit&id={id}` (FORM layout).
- `Collections` button (green field-accent) → navigates to `/crm/fieldcollection/collectionlist?ambassadorId={id}`.
- **3-dot kebab menu** — items:
  - View Profile (alias for View → side panel)
  - Edit (alias)
  - Assign Receipt Book → opens `AssignReceiptBookModal` (ApiSelect ReceiptBook + IssuedDate; creates AmbassadorReceiptBookAssignment + sets Ambassador.CurrentReceiptBookId + marks prior active assignment Completed)
  - View Territory (opens the side-panel's Territory tab directly)
  - Transfer Territory → opens `TransferTerritoryModal` (pick target ambassador — moves selected TerritoryName rows across)
  - Deactivate (danger) → confirm dialog → calls `ChangeAmbassadorStatus(Inactive)`

**Header Actions** (page level, top-right):
- `+ Add Ambassador` (primary, cyan) → navigates to `?mode=new`
- `Import` (outline) → SERVICE_PLACEHOLDER (bulk import not yet wired — toast)
- `Export` (outline) → calls existing `ExportAmbassador` (backend follows ExportStaff pattern)

**Row Click**: opens the **right-side detail panel** (same as View button). Shift-click or ctrl-click navigates to `?mode=read&id={id}` for the full-page detail layout.

---

### FLOW View-Page — 3 URL Modes & Distinct UI Layouts

```
URL MODE                                             UI LAYOUT
────────────────────────────────────────────────     ─────────────────────────────
/crm/fieldcollection/ambassadorlist                  → INDEX GRID + SIDE-PANEL quick-view
/crm/fieldcollection/ambassadorlist?mode=new         → FORM LAYOUT (empty)
/crm/fieldcollection/ambassadorlist?mode=edit&id=X   → FORM LAYOUT (pre-filled)
/crm/fieldcollection/ambassadorlist?mode=read&id=X   → DETAIL LAYOUT (full-page, same 4 tabs)
```

> The **side-panel** (from grid row click) and the **`?mode=read` full page** render the SAME 4-tab content. Build the 4 tab components as shared subcomponents and mount them in two shells:
>  - `AmbassadorDetailSidePanel` — right drawer, closed on Escape/overlay click
>  - `AmbassadorDetailPage` — full-page view with FlowFormPageHeader + container
> Both shells embed `<AmbassadorOverviewTab />`, `<AmbassadorTerritoryTab />`, `<AmbassadorCollectionsTab />`, `<AmbassadorReceiptBooksTab />` unchanged.

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

> Full-page form. Must support the Ambassador's Staff link + territories chip picker + optional initial receipt book.

**Page Header**: FlowFormPageHeader — Back button, title ("Add Ambassador" / "Edit Ambassador — FA-001"), Save button, unsaved-changes dialog.

**Section Container Type**: **cards** (accordion-style, all expanded by default — territories and receipt book as sub-cards).

**Form Sections** (in display order):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | `fa-id-badge` | Ambassador Identity | 2-column | expanded | AmbassadorCode (disabled + "Auto" hint if new), StaffId (ApiSelectV2), StaffCategoryId (ApiSelectV2, optional), BranchId (ApiSelectV2), JoinDate (datepicker) |
| 2 | `fa-address-card` | Contact Overrides | 2-column | collapsed-by-default | PhoneOverride, EmailOverride (both optional — show placeholder "Inherits from Staff: {staff.mobile/email}") |
| 3 | `fa-map-location-dot` | Territory Assignment | full-width | expanded | **TerritoryChipPicker** — free-text input that adds chips; allows reorder via drag or arrow buttons; delete per chip (×); min 1 required |
| 4 | `fa-book` | Receipt Book (optional initial assignment) | 2-column | collapsed-by-default | InitialReceiptBookId (ApiSelectV2 `GetReceiptBooks`, filter `IsActive = true` & not already assigned), IssuedDate (datepicker, default today). If filled, creates an initial AmbassadorReceiptBookAssignment on save. |
| 5 | `fa-money-bill-wave` | Compensation | 2-column | expanded | CompensationType (card-selector: Salaried / Commission / Hybrid), CommissionPercent (number, 0–100, visible only when type ∈ Commission/Hybrid) |
| 6 | `fa-circle-dot` | Status | 1-column | expanded | Status (radio / segmented: Active / OnLeave / Inactive — default Active on new) |
| 7 | `fa-note-sticky` | Notes | full-width | collapsed-by-default | Notes (textarea, 500 chars) |

**Field Widget Mapping** (all fields):

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| AmbassadorCode | 1 | text (disabled on create) | "Auto-generated" | max 30 | Shown read-only on create; editable only for BUSINESSADMIN on edit |
| StaffId | 1 | ApiSelectV2 | "Select Staff" | required | Query: `GetStaffs`; displayField StaffName; on change, auto-fill phone/email placeholders |
| StaffCategoryId | 1 | ApiSelectV2 | "Select Category" | optional | Query: `GetStaffCategories`; defaults to Staff.StaffCategoryId after StaffId selection |
| BranchId | 1 | ApiSelectV2 | "Select Branch" | required | Query: `GetBranches`; defaults to Staff.BranchId if set |
| JoinDate | 1 | datepicker | "Select date" | required | Default: today |
| PhoneOverride | 2 | text | "Inherits from Staff" | max 30, phone pattern | Blank = use Staff.StaffMobileNumber |
| EmailOverride | 2 | email | "Inherits from Staff" | max 100, email pattern | Blank = use Staff.StaffEmail |
| Territories | 3 | TerritoryChipPicker (custom) | "Type territory and press Enter" | ≥1 required | Chips render like mockup territory-badge (emerald/green with map icon); reorder + delete |
| InitialReceiptBookId | 4 | ApiSelectV2 | "Select Receipt Book (optional)" | optional | Query: `GetReceiptBooks` |
| IssuedDate | 4 | datepicker | — | required if InitialReceiptBookId set | Default: today |
| CompensationType | 5 | card-selector | — | required | 3 visual cards (see below) |
| CommissionPercent | 5 | number | "0.00" | required if Commission/Hybrid; 0–100 | Suffix "%" |
| Status | 6 | segmented-control | — | required | 3 pills |
| Notes | 7 | textarea | "Internal notes (optional)" | max 500 | — |

**Special Form Widgets:**

- **Card Selector** — CompensationType:
  | Card | Icon | Label | Description | Triggers |
  |------|------|-------|-------------|----------|
  | `Salaried` | `fa-money-check-dollar` | Salaried | Fixed monthly salary, no commission | Hides CommissionPercent |
  | `Commission` | `fa-percent` | Commission Only | Earns % of each collection | Shows CommissionPercent (required, >0) |
  | `Hybrid` | `fa-layer-group` | Hybrid | Salary + % commission | Shows CommissionPercent (required, >0) |

- **Conditional Sub-form** (CommissionPercent):
  | Trigger Field | Trigger Value | Sub-form Fields |
  |--------------|---------------|-----------------|
  | CompensationType | `Commission` or `Hybrid` | CommissionPercent (0–100, 2 decimal) |

- **Inline Mini Display** (Staff card after StaffId selected):
  | Widget | Trigger | Content |
  |--------|---------|---------|
  | Staff Summary Card | StaffId selected in Section 1 | Avatar (initials), StaffName, StaffEmpId chip, StaffCategoryName, Phone + Email preview — read-only, anchored right of StaffId field |

**Child Grids in Form:**

| Child | Grid Columns | Add/Edit Method | Delete | Notes |
|-------|-------------|----------------|--------|-------|
| Territories | (chip list — not a grid) | inline add on Enter / paste multi-line splits on comma | × on each chip | Drag or ↑↓ buttons to reorder; min 1 |
| Initial Receipt Book | (not a grid — single ApiSelect pair) | Section 4 widgets | blank the Select to remove | Only editable on `?mode=new` — edit mode shows read-only assignment history below the Select (see Section 4 enhancement below) |

**Section 4 enhancement on `?mode=edit`**: below the InitialReceiptBookId select, show a read-only mini-table of existing `AmbassadorReceiptBookAssignment` rows (BookNo, IssuedDate, UsedCount, Status) plus an "Assign New Book" button that opens the same `AssignReceiptBookModal` used from the grid kebab.

---

#### LAYOUT 2: DETAIL — side-panel (primary) + full-page `?mode=read` (secondary)

> The mockup ships a **right-side drawer** (60% width). Build that as the primary detail UX. The `?mode=read&id={id}` URL renders the same 4 tab subcomponents in a full-page shell (FlowFormPageHeader + container).

**Shared Detail Header**:
- Left: profile-avatar (initials, 64px, cyan-accent bg), Ambassador display name, AmbassadorCode chip + Status badge
- Right: Edit button (outline, navigates to `?mode=edit&id={id}`), in side-panel also a close X

**Tabs** (exactly as mockup — 4 tabs, bottom-border-accent active):

| # | Tab | Icon-less label | Content |
|---|-----|-----|--------|
| 1 | Overview | "Overview" | Personal Information detail grid — see below |
| 2 | Territory | "Territory" | Assigned Areas (badges) + Territory Statistics (4 stat boxes) + Territory Map placeholder |
| 3 | Collections | "Collections" | Monthly Collection Trend chart placeholder + Collection Summary (3 stat boxes) + "View All Collections" link |
| 4 | Receipt Books | "Receipt Books" | Assigned Receipt Books table + "Assign New Book" button |

**Tab 1 — Overview** (2-column detail grid):
| Label | Value |
|-------|-------|
| Full Name | `staff.staffName` |
| Staff ID | `staff.staffEmpId` (clickable → `/organization/staff/staff?id={staffId}`) |
| Branch | `branch.branchName` |
| Category | `staffCategory.staffCategoryName` |
| Phone | `phoneOverride ?? staff.staffMobileNumber` |
| Email | `emailOverride ?? staff.staffEmail` |
| Join Date | `joinDate` formatted "MMM YYYY" |
| Compensation | `"{Salaried|Commission Only|Hybrid}{ + commissionPercent%}"` |

**Tab 2 — Territory**:
- **Assigned Areas** — wrap of `territory-badge` chips (emerald bg, `fa-location-dot` icon), driven by `territories[]`.
- **Territory Statistics** — 4 stat boxes (2×2 grid):
  | Stat | Source | Sub |
  |------|--------|-----|
  | Total Contacts | count of distinct Contact where Contact.AmbassadorId = this OR Contact in this territory bucket | — |
  | Regular Donors | count with ≥3 donations in last 12mo | pct of total |
  | Lapsed Donors | count with last donation 6–24mo ago | pct of total |
  | Never Donated | count with 0 donations | pct of total |
- **Territory Map** — placeholder (`map-placeholder` styling). SERVICE_PLACEHOLDER — no real map provider wired (note in §⑫).

**Tab 3 — Collections**:
- **Monthly Collection Trend** — chart placeholder (`chart-placeholder` styling), intended as a 6-month bar chart. SERVICE_PLACEHOLDER — real chart lib wiring deferred (note in §⑫). Renders stub box with `fa-chart-column` icon.
- **Collection Summary** — 3 stat boxes (3-col grid):
  | Stat | Value | Sub |
  |------|-------|-----|
  | This Month | `collectionsThisMonth` | "{count} collections" |
  | Year to Date | `collectionsYtd` | "{count} collections" |
  | Avg per Collection | `avgPerCollection` | — |
- **"View All Collections" link** → navigates to `/crm/fieldcollection/collectionlist?ambassadorId={id}`.

**Tab 4 — Receipt Books** (table + action):
| Column | Source |
|--------|--------|
| Book ID | `receiptBook.bookNo` (bold) |
| Serial Range | `"{receiptStartNo}-{receiptEndNo}"` |
| Issued Date | `issuedDate` formatted |
| Used | `usedCount` |
| Remaining | `receiptBook.receiptCount - usedCount` |
| Status | `assignmentStatus` → badge: Active (green ✓), Completed (grey ✓), Revoked (red) |

Footer: `+ Assign New Book` outline button → opens `AssignReceiptBookModal` (same modal as grid kebab).

**Shell-specific chrome:**
- **Side-panel shell** (`AmbassadorDetailSidePanel`): 60% right-slide drawer, overlay dims page, close-X button, Escape closes, click-outside closes. Transition `right 0.3s ease`.
- **Full-page shell** (`AmbassadorDetailPage` at `?mode=read`): standard FlowFormPageHeader with Back → `/crm/fieldcollection/ambassadorlist`, Edit → `?mode=edit&id={id}`.

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Collections (Month) | Sum of DonationAmount this month | `SUM(AmbassadorCollection.DonationAmount)` WHERE AmbassadorId=row AND CollectedDate ≥ startOfMonth | LINQ subquery in `GetAmbassadorsHandler` |
| Month Visits (sub) | Count of rows | `COUNT(AmbassadorCollection)` same filter | LINQ subquery |
| Collections (YTD) | Sum year-to-date | `SUM` WHERE CollectedDate ≥ Jan 1 | LINQ subquery |
| Donors Visited | Distinct donor count | `COUNT(DISTINCT ContactId)` WHERE AmbassadorId=row | LINQ subquery |
| Receipt Book Usage | Used / Total of active book | `SUM(ReceiptCount)` + `UsedCount` from active AmbassadorReceiptBookAssignment | Navigation include + compute |

### User Interaction Flow

1. User lands on `/crm/fieldcollection/ambassadorlist` → sees 4 KPI widgets + filter bar + grid (Variant B).
2. Clicks `+ Add Ambassador` → URL `?mode=new` → **FORM LAYOUT** loads empty; Section 1 StaffId ApiSelect on focus.
3. Selects Staff → Staff Summary Card appears; BranchId + StaffCategoryId auto-populate from Staff; PhoneOverride/EmailOverride placeholders show inherited values.
4. Adds territories via TerritoryChipPicker (min 1).
5. (Optional) Picks initial receipt book; selects CompensationType card; enters commission % if conditional.
6. Save → validates → creates Ambassador + territories + assignment → redirects to `?mode=read&id={newId}` (full-page DETAIL).
7. From grid, user clicks a row or "View" → side-panel slides in (60% right drawer) with same 4 tabs; Escape or overlay-click closes.
8. From side-panel or detail, click Edit → `?mode=edit&id={id}` FORM loads pre-filled.
9. From grid kebab: Assign Receipt Book → modal → creates AmbassadorReceiptBookAssignment + sets CurrentReceiptBookId + auto-completes prior active.
10. From grid kebab: Deactivate → confirm → `ChangeAmbassadorStatus(Inactive)` + revokes all Active assignments + nulls CurrentReceiptBookId.
11. Filter bar: Branch / Territory / Status / Performance / free search — debounced, fires `GetAmbassadors` with filters.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: SavedFilter (FLOW)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | Ambassador | Entity / class name |
| savedFilter | ambassador | Variable / field names |
| SavedFilterId | AmbassadorId | PK field |
| SavedFilters | Ambassadors | Table name, collection names |
| saved-filter | ambassador-list | FE folder (existing `ambassadorlist` under crm/fieldcollection) |
| savedfilter | ambassadorlist | FE folder / import paths |
| SAVEDFILTER | AMBASSADORLIST | Grid code, menu code |
| notify | fund | DB schema |
| Notify | FieldCollection | Backend group name |
| NotifyModels | FieldCollectionModels | Namespace suffix under Base.Domain.Models |
| NotifyBusiness | FieldCollectionBusiness | Namespace suffix under Base.Application.Business |
| NotifySchemas | FieldCollectionSchemas | Namespace suffix under Base.Application.Schemas |
| NotificationSetup | CRM_FIELDCOLLECTION | ParentMenuCode |
| NOTIFICATION | CRM | ModuleCode |
| crm/communication/savedfilter | crm/fieldcollection/ambassadorlist | FE route path |
| notify-service | fieldcollection-service | FE domain/entities folder name |
| notify-queries | fieldcollection-queries | FE gql-queries folder name |
| notify-mutations | fieldcollection-mutations | FE gql-mutations folder name |
| IFieldDbContext (FILE)/IFieldCollectionDbContext (INTERFACE) | — | ⚠ Existing file-name/interface-name mismatch in repo — DO NOT rename; use `IFieldCollectionDbContext` as the interface |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files — Ambassador primary entity (11 core + 2 workflow + summary)

| # | File | Path |
|---|------|------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/Ambassador.cs` |
| 2 | EF Config | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/FieldCollectionConfigurations/AmbassadorConfiguration.cs` |
| 3 | Schemas (DTOs) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/FieldCollectionSchemas/AmbassadorSchemas.cs` |
| 4 | Create Command | `PSS_2.0_Backend/.../Business/FieldCollectionBusiness/Ambassadors/Commands/CreateAmbassador.cs` |
| 5 | Update Command | `.../Business/FieldCollectionBusiness/Ambassadors/Commands/UpdateAmbassador.cs` |
| 6 | Delete Command | `.../Business/FieldCollectionBusiness/Ambassadors/Commands/DeleteAmbassador.cs` |
| 7 | Toggle Command | `.../Business/FieldCollectionBusiness/Ambassadors/Commands/ToggleAmbassador.cs` |
| 8 | **Workflow Command** — ChangeStatus | `.../Business/FieldCollectionBusiness/Ambassadors/Commands/ChangeAmbassadorStatus.cs` |
| 9 | **Workflow Command** — AssignReceiptBook | `.../Business/FieldCollectionBusiness/Ambassadors/Commands/AssignAmbassadorReceiptBook.cs` |
| 10 | **Workflow Command** — TransferTerritory | `.../Business/FieldCollectionBusiness/Ambassadors/Commands/TransferAmbassadorTerritory.cs` |
| 11 | GetAll Query | `.../Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadors.cs` (name-matches repo convention `GetStaffs`) |
| 12 | GetById Query | `.../Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorById.cs` |
| 13 | **Summary Query** | `.../Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorSummary.cs` |
| 14 | Export Query | `.../Business/FieldCollectionBusiness/Ambassadors/Queries/ExportAmbassador.cs` (match existing ExportStaff pattern) |
| 15 | Mutations Endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/FieldCollection/Mutations/AmbassadorMutations.cs` |
| 16 | Queries Endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/FieldCollection/Queries/AmbassadorQueries.cs` |

### Backend Files — Child entities (AmbassadorTerritory, AmbassadorReceiptBookAssignment)

> Both children are managed via the parent Ambassador commands (batched create/update). Separate CRUD endpoints NOT required (no standalone UI for these). Only need: Entity + Configuration + Schema DTO.

| # | File | Path |
|---|------|------|
| 17 | Entity | `.../Base.Domain/Models/FieldCollectionModels/AmbassadorTerritory.cs` |
| 18 | Entity | `.../Base.Domain/Models/FieldCollectionModels/AmbassadorReceiptBookAssignment.cs` |
| 19 | EF Config | `.../Base.Infrastructure/.../FieldCollectionConfigurations/AmbassadorTerritoryConfiguration.cs` |
| 20 | EF Config | `.../Base.Infrastructure/.../FieldCollectionConfigurations/AmbassadorReceiptBookAssignmentConfiguration.cs` |
| 21 | Schema DTOs | Appended to `AmbassadorSchemas.cs` — `AmbassadorTerritoryRequestDto/ResponseDto`, `AmbassadorReceiptBookAssignmentRequestDto/ResponseDto` |

### Backend — Schema change to existing `AmbassadorCollection`

| # | File | Modification |
|---|------|--------------|
| 22 | `AmbassadorCollection.cs` | Add `public int? AmbassadorId { get; set; }` + nav `public Ambassador? Ambassador { get; set; }` |
| 23 | `AmbassadorCollectionConfiguration.cs` | Add HasOne→Ambassador with DeleteBehavior.SetNull |
| 24 | `AmbassadorCollectionSchemas.cs` | Add `AmbassadorId` to Request + Response DTOs; add `AmbassadorRequestDto? Ambassador` to Response |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Data/Persistence/IFieldDbContext.cs` (interface `IFieldCollectionDbContext`) | `DbSet<Ambassador> Ambassadors { get; }`, `DbSet<AmbassadorTerritory> AmbassadorTerritories { get; }`, `DbSet<AmbassadorReceiptBookAssignment> AmbassadorReceiptBookAssignments { get; }` |
| 2 | `Base.Infrastructure/Data/Persistence/FieldDbContext.cs` | Matching DbSet implementations |
| 3 | `Base.Application/Extensions/DecoratorProperties.cs` → `DecoratorFieldCollectionModules` | Add: `Ambassador = "AMBASSADOR"`, `AmbassadorTerritory = "AMBASSADORTERRITORY"`, `AmbassadorReceiptBookAssignment = "AMBASSADORRECEIPTBOOKASSIGNMENT"` |
| 4 | `Base.Application/Mappings/FieldCollectionMappings.cs` | Mapster configs for Ambassador (Request↔Response↔Entity), AmbassadorTerritory, AmbassadorReceiptBookAssignment |
| 5 | `GlobalUsing.cs` (Domain, Application, Infrastructure, API) | Add `Base.Domain.Models.FieldCollectionModels` if not present (likely already there) |
| 6 | EF Migration | `dotnet ef migrations add Ambassadors_Initial` — 3 new tables + FK added to AmbassadorCollections |

### Frontend Files (9 core FE files — FLOW with 3 modes + side-panel)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/fieldcollection-service/AmbassadorDto.ts` |
| 2 | GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/fieldcollection-queries/AmbassadorQuery.ts` |
| 3 | GQL Mutation | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/fieldcollection-mutations/AmbassadorMutation.ts` |
| 4 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/crm/fieldcollection/ambassadorlist.tsx` |
| 5 | Index Page | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/fieldcollection/ambassadorlist/index.tsx` |
| 6 | Index Page Component (grid + widgets + side-panel host) | `.../page-components/crm/fieldcollection/ambassadorlist/index-page.tsx` |
| 7 | **View Page (3 modes)** | `.../page-components/crm/fieldcollection/ambassadorlist/view-page.tsx` |
| 8 | **Zustand Store** | `.../page-components/crm/fieldcollection/ambassadorlist/ambassador-store.ts` |
| 9 | Route Page (overwrite existing stub) | `PSS_2.0_Frontend/src/app/[lang]/crm/fieldcollection/ambassadorlist/page.tsx` |

### Frontend Files (supporting subcomponents — reused across side-panel & detail page)

| # | File | Purpose |
|---|------|---------|
| 10 | `.../ambassadorlist/components/data-table.tsx` | Custom cell renderers (avatar, receipt-book progress, status badge, action group) |
| 11 | `.../ambassadorlist/components/detail-side-panel.tsx` | Right-drawer shell (60% width) with 4 tabs |
| 12 | `.../ambassadorlist/components/detail-page.tsx` | Full-page `?mode=read` shell with FlowFormPageHeader |
| 13 | `.../ambassadorlist/components/tabs/overview-tab.tsx` | 2-col detail grid — reused in panel + page |
| 14 | `.../ambassadorlist/components/tabs/territory-tab.tsx` | Badges + stat boxes + map placeholder |
| 15 | `.../ambassadorlist/components/tabs/collections-tab.tsx` | Chart placeholder + 3 stat boxes + "View All" link |
| 16 | `.../ambassadorlist/components/tabs/receipt-books-tab.tsx` | Assignment table + Assign New Book button |
| 17 | `.../ambassadorlist/components/form/ambassador-form.tsx` | Full form with 7 sections (used by view-page in new/edit modes) |
| 18 | `.../ambassadorlist/components/form/territory-chip-picker.tsx` | Custom chip picker widget |
| 19 | `.../ambassadorlist/components/form/staff-summary-card.tsx` | Inline mini-display after StaffId selected |
| 20 | `.../ambassadorlist/components/modals/assign-receipt-book-modal.tsx` | Used by grid kebab + Receipt Books tab |
| 21 | `.../ambassadorlist/components/modals/transfer-territory-modal.tsx` | Used by grid kebab |
| 22 | `.../ambassadorlist/components/widgets/kpi-widgets.tsx` | 4 summary cards wrapper |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/domain/operations/entity-operations.ts` | `AMBASSADOR` operations config with capabilities READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT |
| 2 | `src/domain/operations/operations-config.ts` | Register AMBASSADOR import |
| 3 | `src/domain/entities/fieldcollection-service/index.ts` | Re-export `AmbassadorDto`, `AmbassadorSummaryDto`, `AmbassadorTerritoryDto`, `AmbassadorReceiptBookAssignmentDto` |
| 4 | `src/infrastructure/gql-queries/fieldcollection-queries/index.ts` | Re-export Ambassador queries |
| 5 | `src/infrastructure/gql-mutations/fieldcollection-mutations/index.ts` | Re-export Ambassador mutations (create if missing) |
| 6 | Sidebar menu config (CRM_FIELDCOLLECTION branch) | Ensure `AMBASSADORLIST` entry — if `Module_Menu_List.sql` already seeded it, verify at runtime; else add in DB seed |
| 7 | Route — already exists at `src/app/[lang]/crm/fieldcollection/ambassadorlist/page.tsx` (stub) | **Overwrite** with real route page calling `AmbassadorListPageConfig` |
| 8 | Access control guard | Wrap route with `AccessControlPolicyProvider` matching AMBASSADORLIST menu |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Ambassador List
MenuCode: AMBASSADORLIST
ParentMenu: CRM_FIELDCOLLECTION
Module: CRM
MenuUrl: crm/fieldcollection/ambassadorlist
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: AMBASSADORLIST
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query class: `AmbassadorQueries`
- Mutation class: `AmbassadorMutations`

**Queries** (match repo convention — no `GetAll*List` prefix):

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `GetAmbassadors` | `PaginatedApiResponse<AmbassadorResponseDto[]>` | `GridFeatureRequest` (includes: pageNo, pageSize, searchText, sortField, sortDir, isActive, branchId, territory, status, performanceBucket) |
| `GetAmbassadorById` | `BaseApiResponse<AmbassadorResponseDto>` | `ambassadorId: Int` |
| `GetAmbassadorSummary` | `BaseApiResponse<AmbassadorSummaryDto>` | — |
| `ExportAmbassador` | `BaseApiResponse<string>` (base64 XLSX) | `GridFeatureRequest` |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `CreateAmbassador` | `AmbassadorRequestDto` (with nested `territories[]`, optional `initialReceiptBook{bookId,issuedDate}`) | `int` (new ambassadorId) |
| `UpdateAmbassador` | `AmbassadorRequestDto` | `int` |
| `DeleteAmbassador` | `ambassadorId: Int` | `int` |
| `ToggleAmbassador` | `ambassadorId: Int` | `int` (IsActive flip) |
| `ChangeAmbassadorStatus` | `{ ambassadorId, status }` | `int` — applies status-transition side-effects |
| `AssignAmbassadorReceiptBook` | `{ ambassadorId, receiptBookId, issuedDate }` | `int` (assignmentId) — completes prior Active, sets CurrentReceiptBookId |
| `TransferAmbassadorTerritory` | `{ fromAmbassadorId, toAmbassadorId, territoryNames[] }` | `int` — moves territory rows |

**Response DTO — `AmbassadorResponseDto`**:

| Field | Type | Notes |
|-------|------|-------|
| ambassadorId | number | PK |
| ambassadorCode | string | e.g., "FA-001" |
| staffId | number | FK |
| branchId | number | FK |
| staffCategoryId | number? | FK optional |
| joinDate | string (ISO date) | — |
| phoneOverride | string? | nullable |
| emailOverride | string? | nullable |
| compensationType | string | "Salaried" \| "Commission" \| "Hybrid" |
| commissionPercent | number? | — |
| status | string | "Active" \| "Inactive" \| "OnLeave" |
| currentReceiptBookId | number? | nullable |
| notes | string? | — |
| isActive | boolean | inherited |
| staff | StaffRequestDto | nav include — staffName, staffEmpId, staffEmail, staffMobileNumber |
| branch | BranchRequestDto | nav include — branchName |
| staffCategory | StaffCategoryRequestDto? | nav include |
| currentReceiptBook | ReceiptBookRequestDto? | nav include |
| territories | AmbassadorTerritoryResponseDto[] | child include, ordered by OrderBy |
| receiptBookAssignments | AmbassadorReceiptBookAssignmentResponseDto[] | child include (order by IssuedDate desc) |
| collectionsThisMonth | number | subquery aggregate |
| collectionsThisMonthVisits | number | subquery count |
| collectionsYtd | number | subquery aggregate |
| donorsVisited | number | subquery distinct count |
| currentBookUsagePercent | number? | computed: usedCount / receiptCount × 100 |

**Response DTO — `AmbassadorSummaryDto`**:

| Field | Type |
|-------|------|
| totalAmbassadors | number |
| activeCount | number |
| inactiveCount | number |
| onLeaveCount | number |
| collectionsThisMonth | number |
| collectionsLastMonth | number |
| monthOverMonthPercent | number |
| avgPerAmbassadorMonthly | number |
| topAmbassadorName | string? |
| topAmbassadorCollectionsMonth | number? |
| activeReceiptBooks | number |
| receiptsUsedThisMonth | number |

**Child DTOs** — `AmbassadorTerritoryResponseDto { ambassadorTerritoryId, ambassadorId, territoryName, orderBy }`; `AmbassadorReceiptBookAssignmentResponseDto { ambassadorReceiptBookAssignmentId, ambassadorId, receiptBookId, issuedDate, completedDate?, usedCount, assignmentStatus, receiptBook: ReceiptBookRequestDto }`.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` passes with 0 errors, 0 warnings introduced by new files
- [ ] EF migration `Ambassadors_Initial` adds 3 new tables + `AmbassadorId` FK on AmbassadorCollections
- [ ] `pnpm tsc --noEmit` passes
- [ ] `pnpm dev` serves `/en/crm/fieldcollection/ambassadorlist` (stub overwritten)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid renders 12 columns with custom avatar / receipt-book-progress / status-badge / action cells
- [ ] 4 KPI widgets show live values from `GetAmbassadorSummary`
- [ ] Search + 4 filter dropdowns filter grid (Branch, Territory, Status, Performance)
- [ ] Row click / View → side-panel slides in (60% right); Escape closes; overlay-click closes
- [ ] Side-panel tabs switch without remount (Overview / Territory / Collections / Receipt Books)
- [ ] Edit button in side-panel → `?mode=edit&id=X` → FORM pre-filled
- [ ] `+ Add Ambassador` → `?mode=new` → FORM empty
- [ ] Section 1 StaffId ApiSelect loads via `GetStaffs`; Staff Summary Card renders on selection
- [ ] Auto-populate BranchId and StaffCategoryId from Staff selection
- [ ] Territory Chip Picker: Enter adds chip, × removes, ↑↓ reorders; validation blocks save with <1 chip
- [ ] CompensationType card-selector shows CommissionPercent only when Commission/Hybrid
- [ ] Optional initial ReceiptBook → creates AmbassadorReceiptBookAssignment with Active status on save
- [ ] Save create → redirects to `?mode=read&id={newId}` (full-page DETAIL renders same 4 tabs)
- [ ] Save edit → redirects back to detail
- [ ] Grid aggregation columns show non-zero values after at least one AmbassadorCollection row exists with `AmbassadorId` FK set
- [ ] Receipt book progress bar: green <60%, amber 60–85%, red >85%, ⚠ icon at >75%
- [ ] Kebab → Assign Receipt Book → modal → save → active book swapped, prior marked Completed
- [ ] Kebab → Transfer Territory → modal → moves rows between ambassadors
- [ ] Kebab → Deactivate → confirm → status=Inactive, all Active assignments revoked, CurrentReceiptBookId nulled
- [ ] Collections row button → navigates to `/crm/fieldcollection/collectionlist?ambassadorId=X`
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] Permissions: Edit/Delete buttons respect BUSINESSADMIN capability gates

**DB Seed Verification:**
- [ ] AMBASSADORLIST menu entry present under CRM_FIELDCOLLECTION with MenuUrl `crm/fieldcollection/ambassadorlist`
- [ ] Menu appears in sidebar after login
- [ ] Grid columns render via GRID / GRIDCOLUMN seed rows for `GridCode = AMBASSADORLIST`
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** in `Ambassadors` — it comes from HttpContext in CreateHandler.
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it.
- **view-page.tsx handles ALL 3 URL modes** — new/edit share FORM; read is a full-page DETAIL layout.
- **Side-panel + full-page both exist**. The side-panel opens on grid row click for quick viewing (matching the mockup). The `?mode=read` full-page is also supported so links can deep-link into a detail view. Both reuse the SAME 4 tab subcomponents (`<OverviewTab>`, `<TerritoryTab>`, `<CollectionsTab>`, `<ReceiptBooksTab>`) to avoid drift. Do NOT build two versions of the tabs.
- **FE route stub EXISTS** at `src/app/[lang]/crm/fieldcollection/ambassadorlist/page.tsx` (contents: `<div>Need to Develop</div>`). Overwrite with real route.
- **Group naming mismatch** — the DbContext interface FILE is named `IFieldDbContext.cs` but the INTERFACE inside is `IFieldCollectionDbContext`. Preserve this; do NOT rename. Concrete is `ApplicationDbContext : IFieldCollectionDbContext` in `FieldDbContext.cs`.
- **Backend query naming** — this repo uses bare plural naming (`GetStaffs`, `GetBranches`, `GetAmbassadorCollections`) — NOT `GetAll{Entity}List`. Use `GetAmbassadors` and `GetAmbassadorById` — do NOT invent `GetAllAmbassadorList`.
- **Schema change to existing `AmbassadorCollection`** — adding nullable `AmbassadorId` FK is backwards-compatible. Existing rows stay `AmbassadorId = null` (pre-migration data); new rows populate it via CreateAmbassadorCollection command. Coordinate with screen #65 (Field Collection list) build session to include AmbassadorId in its form.
- **Ambassador ↔ Staff relationship is 1:1 per Company** — Enforce via a unique index on (CompanyId, StaffId) in AmbassadorConfiguration. This means "a Staff member can be registered as an Ambassador once per tenant."
- **StaffId selection cascade** — when StaffId changes in the FORM, auto-populate BranchId and StaffCategoryId from Staff's own fields (but allow override). Don't overwrite if user has manually set them since the last StaffId change (track a `dirty` flag per field).
- **Territory as free text** — The mockup shows territories as human-readable strings ("Deira", "Andheri"). Do NOT introduce a `Territory` master entity in this screen. If a future screen needs territory-as-entity, migrate later.
- **ReceiptBook FK on Ambassador is nullable + "current" only** — The real relationship history lives on `AmbassadorReceiptBookAssignment`. `Ambassador.CurrentReceiptBookId` is a denormalized pointer for grid performance — kept in sync by AssignAmbassadorReceiptBook handler and by status transitions.
- **Schema is `fund`** (same as ReceiptBook/AmbassadorCollection) — do NOT create a new schema.
- **Menu name is "Ambassador List" not "Ambassador"** — per MODULE_MENU_REFERENCE.md, MenuCode is `AMBASSADORLIST`, MenuUrl is `crm/fieldcollection/ambassadorlist`. Keep both consistent; don't shorten to `AMBASSADOR`.
- **Role list** — per user's standing directive, seed only BUSINESSADMIN in RoleCapabilities. Do not enumerate all 7 roles in the seed script.
- **Icons** — use `@iconify-icon/react` with Phosphor icons (per feedback memory). The mockup uses FontAwesome icon names — map them to Phosphor equivalents at implementation time (e.g., `fa-person-walking` → `ph:person-simple-walk`, `fa-hand-holding-dollar` → `ph:hand-coins`, `fa-chart-bar` → `ph:chart-bar`, `fa-receipt` → `ph:receipt`, `fa-map-location-dot` → `ph:map-pin-line`, `fa-location-dot` → `ph:map-pin`, `fa-book` → `ph:book-open`, `fa-right-left` → `ph:arrows-left-right`, `fa-ban` → `ph:prohibit`, `fa-pen-to-square` → `ph:pencil-simple`, `fa-user` → `ph:user`).
- **Token discipline** — no hex colors or px values in code; use theme tokens (`text-muted`, `text-success`, `bg-accent-soft`, `gap-3`, `p-4`, etc.) per feedback memory.
- **Audit fields** — use `createdDate` / `modifiedDate` names (not `createdAt` / `modifiedAt`) per feedback memory.
- **Component reuse** — FE dev MUST search the component registry first. Likely reuses: `ScreenHeader`, `DataTableContainer`, `FlowDataTable`, `FlowFormPageHeader`, `ApiSelectV2`, `Card`, `Badge`, `Skeleton`, `UnsavedChangesDialog`, avatar-initials helper. Creates new only if missing AND static (TerritoryChipPicker is new + static; AssignReceiptBookModal is new + composable from existing primitives). MASTER_GRID/FLOW infra is complex — escalate if shell needs extending.

**Service Dependencies** (UI-only — no backend service implementation):

- **⚠ SERVICE_PLACEHOLDER: Import (page header button)** — full button UI implemented; handler emits toast "Bulk import not yet wired." Bulk import service/worker infrastructure does not yet exist for Ambassadors.
- **⚠ SERVICE_PLACEHOLDER: Territory Map (Territory tab)** — map-placeholder div renders with `ph:map-pin` icon and "Territory Map View" label. No map provider (Google Maps / Mapbox / Leaflet) is wired in this codebase. Handler/component logs a TODO comment.
- **⚠ SERVICE_PLACEHOLDER: Monthly Collection Trend chart (Collections tab)** — chart-placeholder div renders with icon + "Monthly Collections Bar Chart (Last 6 Months)" label. No chart library is yet standardized for this screen. FE dev may render a simple inline bar chart from returned `monthlyTotals[]` if time permits; otherwise placeholder.

Full UI is otherwise in scope — every other button, form, modal, panel, territory picker, receipt-book assignment, status workflow must be implemented end-to-end.

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
