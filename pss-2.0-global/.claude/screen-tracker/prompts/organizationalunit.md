---
screen: OrganizationalUnit
registry_id: 44
module: CRM → Organization
status: PROMPT_READY
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-20
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (org-unit-tree.html + org-unit-form.html)
- [x] Existing code reviewed (BE entity + 7 handlers + GQL endpoints; FE wizard + 3 hidden child tabs + store)
- [x] Business rules + hierarchy workflow extracted
- [x] FK targets resolved (Country/State/City/Staff/Currency/MasterData/PaymentMode/DonationPurpose)
- [x] File manifest computed
- [x] Approval config pre-filled (CRM_ORGANIZATION, MenuCode=ORGANIZATIONALUNIT, OrderBy=1)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM layout = 6 stacked cards; INDEX layout = widgets + split-pane tree/detail-tabs)
- [ ] User Approval received
- [ ] Backend code generated (ALIGN — extend existing 11 BE files, add 5 new queries/commands, add migration, extend validators, mapper, seed)
- [ ] Backend wiring complete
- [ ] Frontend code generated (ALIGN — near-greenfield: keep index/view router shell + store shell; replace wizard/child tabs with 6-section form; replace FlowDataTable with custom split-pane UI)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (GridFormSchema=SKIP; seed MasterData rows: UNITTYPE, TIMEZONE, TARGETPERIOD, DATAVISIBILITY; seed 12 sample org units per mockup)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/[lang]/crm/organization/organizationalunit`
- [ ] INDEX loads: 4 KPI widgets render, tree renders with expanded HQ→Region→Branch→Sub-unit, search filters tree nodes, status filter works, view toggle Tree↔List works
- [ ] Clicking a tree node updates right panel with 4 tabs (Overview + Staff + Targets & Performance + Settings)
- [ ] Context menu (right-click) shows 6 items (Add Child / Edit / Move / Deactivate / Delete)
- [ ] `?mode=new` — empty 6-section FORM renders (Basic Info + Location & Contact + Management + Fundraising + Data Access + Branding)
- [ ] Unit Type 4-card selector selection works; changing type re-computes auto-gen code prefix
- [ ] Parent Unit tree-dropdown shows hierarchical list with codes (can only select units above this node's level; cannot set self/descendant as parent)
- [ ] Country → State → City cascade works (existing ApiSelectV2 pattern)
- [ ] Linked Donation Purposes multi-select chips work
- [ ] Default Payment Methods checkbox group persists
- [ ] Data Visibility 3-radio selector works
- [ ] Primary Color picker syncs hex display
- [ ] Logo/Banner upload areas render (SERVICE_PLACEHOLDER — toast on click)
- [ ] Save creates record → URL switches to `?mode=read&id={newId}` → back on tree with new node selected (right panel shows detail)
- [ ] `?mode=edit&id=X` — form pre-filled with existing 27+ fields
- [ ] Edit button on detail → form pre-filled; Save returns to tree
- [ ] FK dropdowns load via ApiSelect (Country/State/City/Staff/Currency/UnitType/TimezoneType/TargetPeriodType/DataVisibilityType)
- [ ] 4 Summary widgets display with correct counts (Total Units, Levels, Staff Assigned, Total Annual Target + Achieved %)
- [ ] Delete blocked with tooltip when unit has children / staff / contacts (matches mockup disabled-state message)
- [ ] Move (re-parent) command works (no cycles; hierarchy level auto-recomputes for moved subtree)
- [ ] Unsaved-changes dialog triggers on dirty form back/cancel
- [ ] DB Seed — menu visible in sidebar under CRM > Organization, 12 sample units appear in tree

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: OrganizationalUnit
Module: CRM → Organization
Schema: `app` (ApplicationModels)
Group: ApplicationModels

Business: Organizational Unit is the **hierarchy backbone** of the NGO — it models how the organization is structured (Headquarters → Region → Branch → Sub-unit/Program). Every transactional record (contacts, staff, donations, events, campaigns, cases, volunteers) belongs to one Org Unit, and permissions/data-visibility cascade through this hierarchy. Admins use this screen to create the HQ, add geographic Regions, open Branches, and attach operational Sub-units/Programs. The tree view lets admins see the entire organization at a glance, drill into any unit's detail panel (staff, fundraising targets & performance, settings) without leaving the page, and perform re-parenting / deactivation operations via context menu. Re-aligned from the prior "Wizard-with-child-tabs" design (Campaign/Event/DonationPurpose as children) to a standalone hierarchical entity — the child collections now live under their own canonical screens (#39 Campaign, #40 Event, #2 DonationPurpose) and FK back to OrganizationalUnit. This screen exists to let organizations map their real-world structure into PSS and drives multi-tenancy scoping downstream.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> ALIGN scope — extend existing 7-field entity to 34 fields per mockup. Existing entity at [PSS_2.0_Backend/.../ApplicationModels/OrganizationalUnit.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs).

Table: `app."OrganizationalUnits"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| OrganizationalUnitId | int | — | PK | — | Auto-identity — EXISTING |
| CompanyId | int | — | YES | app.Companies | Tenant — EXISTING (from HttpContext) |
| UnitTypeId | int | — | YES | set.MasterDatas (typeCode=UNITTYPE) | HQ / REG / BR / SU — EXISTING |
| ParentUnitId | int? | — | NULL for HQ | self OrganizationalUnits | Parent in tree — EXISTING |
| HierarchyLevel | int | — | YES | — | 1 (HQ) / 2 (REG) / 3 (BR) / 4 (SU) auto-computed from parent — EXISTING |
| UnitCode | string | 100 | YES | — | Unique per Company — EXISTING (e.g., `HQ-001`, `REG-MEA`, `BR-DXB`, `SU-DXB-OC`) |
| UnitName | string | 100 | YES | — | Full unit name — EXISTING |
| **ShortName** | string? | 50 | NO | — | NEW — abbreviated name (e.g., "Dubai" for "Dubai Branch") |
| **Description** | string? | 500 | NO | — | NEW |
| **CountryId** | int? | — | NO | shr.Countries | NEW — for Regions/Branches/Sub-units |
| **StateId** | int? | — | NO | shr.States | NEW |
| **CityId** | int? | — | NO | shr.Cities | NEW |
| **PostalCode** | string? | 20 | NO | — | NEW |
| **AddressLine1** | string? | 200 | NO | — | NEW |
| **AddressLine2** | string? | 200 | NO | — | NEW |
| **PhonePrefix** | string? | 10 | NO | — | NEW — e.g., `+971` (derived from country) |
| **Phone** | string? | 30 | NO | — | NEW |
| **Email** | string? | 100 | NO | — | NEW — email format validation |
| **TimezoneId** | int? | — | NO | set.MasterDatas (typeCode=TIMEZONE) | NEW — Asia/Dubai, America/New_York, etc. |
| **ManagerStaffId** | int? | — | NO | app.Staffs | NEW — Unit Head |
| **DeputyStaffId** | int? | — | NO | app.Staffs | NEW — Alternate |
| **EffectiveDate** | DateOnly? | — | NO | — | NEW |
| **Notes** | string? | 1000 | NO | — | NEW — internal notes |
| **AnnualFundraisingTarget** | decimal(18,2)? | — | NO | — | NEW |
| **TargetCurrencyId** | int? | — | NO | shr.Currencies | NEW |
| **TargetPeriodId** | int? | — | NO | set.MasterDatas (typeCode=TARGETPERIOD) | NEW — Calendar Year / Fiscal Year / Custom |
| **FiscalYearStartMonth** | int? | — | NO | — | NEW — 1..12 |
| **AcceptsDonationsDirectly** | bool | — | YES | — | NEW — default true |
| **DataVisibilityId** | int? | — | NO | set.MasterDatas (typeCode=DATAVISIBILITY) | NEW — Isolated / Inherited / Global; default Inherited |
| **DefaultCurrencyId** | int? | — | NO | shr.Currencies | NEW — reporting currency |
| **AutoAssignContactsByRegion** | bool | — | YES | — | NEW — default false |
| **UnitLogoUrl** | string? | 500 | NO | — | NEW — SERVICE_PLACEHOLDER file upload |
| **UnitBannerUrl** | string? | 500 | NO | — | NEW — SERVICE_PLACEHOLDER file upload |
| **PrimaryColorHex** | string? | 7 | NO | — | NEW — `#0e7490` style |

**Inherited audit columns**: CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive, IsDeleted (from `Entity` base).

**Child / Junction Entities** (NEW):
| Child Entity | Relationship | Key Fields | Notes |
|-------------|-------------|------------|-------|
| OrganizationalUnitDonationPurposes | 1:Many from Unit + 1:Many from DonationPurpose → junction | OrganizationalUnitId, DonationPurposeId | Restricts which donation purposes this unit can collect for. Empty = all allowed. |
| OrganizationalUnitPaymentModes | 1:Many from Unit + 1:Many from PaymentMode → junction | OrganizationalUnitId, PaymentModeId | Default payment methods (Cash/Cheque/Bank Transfer/Online/Mobile Money). |

**Migration name**: `Add_OrganizationalUnit_ExtendedFields` — adds 25 new columns + creates 2 junction tables. Existing unique index `(CompanyId, UnitTypeId, ParentUnitId, UnitCode, IsActive)` preserved.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| UnitTypeId | MasterData | [SettingModels/MasterData.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/MasterData.cs) | `masterDatas` (filter by typeCode=UNITTYPE via advancedFilter) | DataName | MasterDataResponseDto |
| ParentUnitId | OrganizationalUnit | [ApplicationModels/OrganizationalUnit.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs) | `organizationalUnits` (self-ref) | UnitName | OrganizationalUnitResponseDto |
| CountryId | Country | [SharedModels/Country.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Country.cs) | `countries` | CountryName | CountryResponseDto |
| StateId | State | [SharedModels/State.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/State.cs) | `states` (filter by CountryId) | StateName | StateResponseDto |
| CityId | City | [SharedModels/City.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/City.cs) | `cities` (filter by StateId) | CityName | CityResponseDto |
| TimezoneId | MasterData | SettingModels/MasterData.cs | `masterDatas` (filter by typeCode=TIMEZONE) | DataName | MasterDataResponseDto |
| ManagerStaffId | Staff | [ApplicationModels/Staff.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Staff.cs) | `staffs` (optionally filter by OrganizationalUnitId once FK exists) | StaffName (DropDownLabel = EmpId + Name) | StaffResponseDto |
| DeputyStaffId | Staff | ApplicationModels/Staff.cs | `staffs` | StaffName | StaffResponseDto |
| TargetCurrencyId | Currency | [SharedModels/Currency.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs) | `currencies` | CurrencyName + Symbol | CurrencyResponseDto |
| TargetPeriodId | MasterData | SettingModels/MasterData.cs | `masterDatas` (typeCode=TARGETPERIOD) | DataName | MasterDataResponseDto |
| DataVisibilityId | MasterData | SettingModels/MasterData.cs | `masterDatas` (typeCode=DATAVISIBILITY) | DataName | MasterDataResponseDto |
| DefaultCurrencyId | Currency | SharedModels/Currency.cs | `currencies` | CurrencyName | CurrencyResponseDto |
| DonationPurposeId (junction) | DonationPurpose | [DonationModels/DonationPurpose.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/DonationPurpose.cs) | `donationPurposes` | DonationPurposeName | DonationPurposeResponseDto |
| PaymentModeId (junction) | PaymentMode | [SharedModels/PaymentMode.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/PaymentMode.cs) | `paymentModes` | PaymentModeName | PaymentModeResponseDto |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `(CompanyId, UnitTypeId, ParentUnitId, UnitCode, IsActive)` — EXISTING composite unique index preserved
- UnitName should be unique per ParentUnitId (soft validation — warn not block)

**Required Field Rules:**
- UnitTypeId, UnitCode, UnitName, HierarchyLevel are mandatory
- ParentUnitId required WHEN UnitTypeId != HQ (HQ has no parent)
- CountryId required WHEN UnitTypeId IN (Region, Branch, Sub-unit)
- At least one of Country/State/City must be set for geographic units

**Conditional Rules:**
- If UnitTypeId = HQ → ParentUnitId MUST be null; only one HQ allowed per Company (hard-guard)
- If UnitTypeId = Region → Parent must be HQ (HierarchyLevel=1)
- If UnitTypeId = Branch → Parent must be Region or HQ
- If UnitTypeId = Sub-unit → Parent must be Branch or Region
- If AcceptsDonationsDirectly = false → Children must accept donations (no dead donation chain)
- If Email is provided → RFC email format; if Phone provided → digits/dashes/spaces/parens only
- If PrimaryColorHex is provided → must match `#[0-9A-Fa-f]{6}`
- FiscalYearStartMonth must be 1..12; AnnualFundraisingTarget must be ≥ 0

**Business Logic:**
- **UnitCode auto-gen** (when Create submitted without a code): format depends on UnitType —
  - HQ → `HQ-{NNN}` (e.g., `HQ-001`)
  - Region → `REG-{uppercase 3-char hint from name}` (e.g., "Middle East & Africa" → `REG-MEA`)
  - Branch → `BR-{3-char city-or-name hint}` (e.g., "Dubai" → `BR-DXB`)
  - Sub-unit → `SU-{parent-branch-hint}-{2-char}` (e.g., parent BR-DXB + "Orphan Care" → `SU-DXB-OC`)
  - Server-side logic in Create handler; if still colliding, append `-N` numeric suffix.
- **HierarchyLevel auto-compute** on Create/Update/Move: level = parent.HierarchyLevel + 1 (HQ = 1). Persisted (denormalized) for O(1) tree rendering.
- **Cycle prevention** on Move/Update: cannot set ParentUnitId to self or any descendant. Validated by walking child subtree.
- **Descendants level re-compute** on Move: when a unit is re-parented, re-compute HierarchyLevel for unit + all descendants (single batched update).
- **Delete guard**: BadRequestException if unit has (a) child units, (b) staff assigned, (c) contacts assigned, (d) active donations. Mockup disables Delete button with tooltip listing counts ("2 child units, 12 staff, 1,234 contacts").
- **Deactivate cascade**: Deactivating a parent does NOT auto-deactivate children, but GetAll filters should respect `IsActive`. Children remain active and visible.
- **PhonePrefix auto-fill** from Country.PhoneCode when Country selected (FE-side default; user can override).
- **TimezoneId auto-fill** from Country.DefaultTimezoneMasterDataId when Country selected (FE-side default; user can override).

**Workflow** — no explicit state machine. Active/Inactive via existing `Toggle{Entity}` inherited flow.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: **Custom FLOW with non-standard index** (index is NOT `FlowDataTable` — it's a custom split-pane tree + detail-tabs panel; sibling of DuplicateContact #21 which also replaces the grid with a custom card list).
**Reason**: Tree hierarchy + inline detail panel + separate full-page form for add/edit. The mockup's index panel is intrinsically hierarchical — a flat data-table cannot represent the parent/child relationships visually. A List-view toggle is provided as alternate rendering but is still a custom table (not FlowDataTable with gridCode).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files — EXISTING, extend)
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Multi-FK validation (UnitType / Country / State / City / Staff×2 / Currency×2 / PaymentMode / DonationPurpose / MasterData×3)
- [x] Junction tables × 2 (OrganizationalUnitDonationPurposes + OrganizationalUnitPaymentModes)
- [x] Unique validation — composite existing
- [x] Tree query (recursive navigation — NEW `GetOrganizationalUnitTree`)
- [x] Summary query (NEW `GetOrganizationalUnitSummary` — 4 KPI widgets)
- [x] Detail query (NEW `GetOrganizationalUnitDetail` — right-panel tab data)
- [x] Move command (NEW `MoveOrganizationalUnit` — re-parent with cycle check + subtree level re-compute)
- [x] Auto-code generation helper (server-side UnitCode builder)
- [x] System-guard delete validator (children / staff / contacts / donations existence check)
- [x] No workflow state machine — simple IsActive toggle

**Frontend Patterns Required:**
- [x] view-page.tsx with 3 URL modes (new, edit, read) — EXISTING shell (keep index.tsx router), but view-page BODY re-written from wizard → 6-section form
- [x] React Hook Form (for 6-section FORM layout)
- [x] Zustand store — existing to be REWRITTEN (remove child sub-stores / wizard / openTabs; add: selectedNodeId, treeExpandedIds, searchText, statusFilter, viewMode='tree'|'list', detail tab state)
- [x] Unsaved changes dialog — EXISTING, keep
- [x] FlowFormPageHeader (Back + Save + Save&Add Another + Cancel; Edit button in detail panel header)
- [x] Custom split-pane INDEX replacing FlowDataTable
- [x] Tree component (recursive, expand/collapse, search, context menu)
- [x] Alternate List view with indentation rendering
- [x] 4-card UnitType selector (like DonationInKind #7 mode selector)
- [x] Parent-Unit tree dropdown (hierarchical with indentation, search-box inside)
- [x] Multi-select tag chips for Linked Donation Purposes
- [x] Checkbox group for Payment Methods
- [x] Color hex picker (REUSE from StaffCategory #43)
- [x] Logo + Banner upload areas (SERVICE_PLACEHOLDER — toast + file input preview only)
- [x] 4 Summary widgets above tree (Variant B)
- [x] 4-tab detail panel (Overview + Staff + Targets & Performance + Settings)
- [ ] No standard grid aggregation columns — List view is custom component
- [x] Service placeholders for: Export Structure button, Logo/Banner upload, Monthly Breakdown chart, Peer Comparison data source

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Grid/List View → **Custom split-pane replaces FlowDataTable**

**Display Mode**: Custom (NOT `table` nor `card-grid` — this is a tree/detail-panel hybrid). FE dev must NOT render `<FlowDataTable>` on this index.

**Grid Layout Variant**: `widgets-above-grid` → **Variant B** — `<ScreenHeader>` + 4 `<KPIWidgets>` + custom `<SplitPane>` body. `<DataTableContainer>` is NOT used on this screen. Avoid double-header: the screen-level header is rendered manually via `<ScreenHeader>`.

**Page Widgets — 4 KPI Cards (above split-pane):**

| # | Title | Value Source | Display Type | Icon | Accent |
|---|-------|-------------|-------------|------|--------|
| 1 | Total Units | `totalUnits` (active/inactive breakdown in sub-label) | int | fa-sitemap | blue |
| 2 | Levels | `maxHierarchyLevel` (with breadcrumb "HQ → Region → Branch → Sub-unit" in sub-label) | int | fa-layer-group | purple |
| 3 | Staff Assigned | `totalStaffCount` | int | fa-users | green |
| 4 | Total Annual Target | `totalAnnualTarget` (in base currency, with "Achieved: $X (N%)" sub-label computed from `ytdCollected`) | currency | fa-bullseye | amber |

**Summary GQL Query**: `GetOrganizationalUnitSummary` (NEW)
- Returns: `OrganizationalUnitSummaryDto { totalUnits, activeUnits, inactiveUnits, maxHierarchyLevel, totalStaffCount, totalAnnualTarget, ytdCollected, achievedPercent }`
- Staff count uses `Staffs.Where(IsActive)`; donations YTD uses GlobalDonation (same tenant, current calendar year).

**Split-Pane Body** (60/40 left/right on desktop, stacks vertically on mobile):

#### LEFT PANEL — Tree / List toggle

- **Toolbar row** (top of left pane):
  - Search box (placeholder: "Search units by name or code...") — filters tree nodes (hides non-matching rows; parents remain visible if any descendant matches)
  - Status filter select (All / Active / Inactive)
  - View toggle button-group (Tree | List) — default Tree

- **Tree view** (default):
  - Recursive tree rendering `OrganizationalUnit[]` from `GetOrganizationalUnitTree`
  - Each node row: `[chevron-toggle] [typeIcon] [unitName] [unitCode monospace] [statusDot]`
  - Type-icon colors: HQ=blue `fa-building`, Region=green `fa-globe-{americas|africa|asia|europe}`, Branch=amber `fa-building-flag`, Sub-unit=slate `fa-file-alt`
  - Node row click → selects node (updates right panel)
  - Right-click (context menu) → 6-item menu: Add Child Unit, Edit, Move (Re-parent), Deactivate, Delete. Disabled states per business rules.
  - "Expand All" / "Collapse All" toolbar actions in ScreenHeader actions row

- **List view** (alternate):
  - Custom table (NOT FlowDataTable): Unit Name (indented by hierarchyLevel × 4 nbsp) | Code | Type | Parent (code) | Staff | Annual Target | YTD Collection | Status
  - Row click → select node (same behavior as tree row click)
  - List is flat (pre-ordered DFS by parent→child, HierarchyLevel ASC then UnitName ASC)

#### RIGHT PANEL — Selected-Unit Detail (4 tabs)

When a tree node is selected, fetches `GetOrganizationalUnitDetail(unitId)` and renders:

- **Detail Header** (top of right pane):
  - Unit name (h2), 3 badges: code / type / status
  - Action row: Edit (→ `?mode=edit&id=X`), Add Child (→ `?mode=new&parentUnitId=X&unitTypeId={next-level}`), Deactivate (toggle mutation)

- **Tab bar** (4 tabs):
  1. **Overview** — Unit Information grid (Full Name / Short Name / Code / Type / Parent / Level / Country / City / Address / Phone / Email / Head-Manager link / Created / Status) + Child Units list (clickable, selects child node) + "Add Child Unit" button + Quick Stats (5 mini stat cards: Total Contacts / Donations YTD / Active Campaigns / Upcoming Events / Staff Count)
  2. **Staff** — assigned-staff table (Name link / Role / Email / Status / AssignedSince / Actions=Remove-button) + "Assign Staff" button. Staff list comes from `Staffs.Where(OrganizationalUnitId = {unitId})` — requires a new FK `Staff.OrganizationalUnitId` (or fall back to SERVICE_PLACEHOLDER if FK doesn't exist yet, list shows empty with "Coming Soon" tooltip — see ⑫).
  3. **Targets & Performance** —
     - Target card (Annual Target / YTD Collected / Progress bar / Monthly Avg / Projected Year-End / Projected % of Target — all computed from donations)
     - "Monthly Breakdown" chart placeholder (SERVICE_PLACEHOLDER — bar chart of last 12 months collection; render `<ChartPlaceholder>` stub with raw list)
     - Target by Child Unit table (Sub-unit / Target / Collected / Progress bar)
     - Comparison with Peer Branches table (top 5 peer units — same HierarchyLevel, same ParentUnitId's siblings; Rank / Branch / Target / Collected / Progress)
  4. **Settings** — inline editable unit-level config:
     - Data Access Scope 3-radio (Isolated / Inherited / Global) — maps to DataVisibilityId
     - Unit Configuration 4-row (Default Currency / Timezone / Fiscal Year Start / Auto-assign new contacts toggle)
     - Save Settings button — calls `UpdateOrganizationalUnit` with partial payload

### Row Click

Tree/list row click selects node in-page (updates right panel). It does **NOT** navigate to `?mode=read&id=X`. If user wants full read-only page experience, they can type the URL or click Edit then back — but this screen's primary "read" UX is the right panel. URL-mode `?mode=read&id=X` is supported for deep-linking (routes to the index page with that node pre-selected and the panel scrolled into view).

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

```
URL MODE                                     UI LAYOUT
────────────────────────────────────────     ────────────────────────────────────
/organizationalunit                      →   INDEX (widgets + split-pane tree/detail)
/organizationalunit?id=X                 →   INDEX with node X pre-selected (detail)
/organizationalunit?mode=read&id=X       →   INDEX with node X pre-selected (detail)
/organizationalunit?mode=new             →   FORM LAYOUT (empty 6 sections)
/organizationalunit?mode=new&parentUnitId=X&unitTypeId=Y → FORM LAYOUT (pre-filled parent + type)
/organizationalunit?mode=edit&id=X       →   FORM LAYOUT (pre-filled)
```

**NEW and EDIT share the same 6-section form layout.**
**READ is the detail panel ON the index page** (no separate page).

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

> Full-page form with 6 stacked cards (NOT tabs, NOT accordion — always expanded section cards).
> Centered within viewport, max-width 820px (mockup dimension).

**Page Header**: `<FlowFormPageHeader>` — Back / Save / Save & Add Another / Cancel buttons + unsaved-changes dialog on dirty navigation.

**Section Container Type**: **stacked cards** — each section is a card with a header strip (icon + title + optional "(optional)" suffix) and a padded body. No collapse/expand. Sections always visible. Border between sections.

**Form Sections** (in display order from mockup — all cards stacked full-width):

| # | Icon | Section Title | Layout | Fields |
|---|------|--------------|--------|--------|
| 1 | fa-info-circle | Basic Information | 2-col grid | UnitName, ShortName, UnitCode, Status-toggle, UnitType-4card (full-width), ParentUnit-tree-dropdown (full-width), Description (textarea full-width) |
| 2 | fa-map-marker-alt | Location & Contact | 2-col grid | Country, State, City, PostalCode, AddressLine1, AddressLine2, Phone (with PhonePrefix input-group), Email, Timezone (full-width) |
| 3 | fa-user-tie | Management | 2-col grid | ManagerStaffId, DeputyStaffId, EffectiveDate (2-col left), Notes (textarea full-width) |
| 4 | fa-hand-holding-usd | Fundraising Configuration | 2-col grid | AnnualFundraisingTarget (with currency-prefix), TargetCurrencyId, TargetPeriodId, AcceptsDonationsDirectly-toggle, LinkedDonationPurposes multi-chip (full-width), DefaultPaymentMethods checkbox-grid (full-width) |
| 5 | fa-shield-alt | Data Access & Settings | 1-col visibility-radio-cards + 2-col below | DataVisibilityId 3-radio-cards (full-width), DefaultCurrencyId, FiscalYearStartMonth, AutoAssignContactsByRegion-toggle |
| 6 | fa-palette | Branding (optional) | 2-col grid | UnitLogoUrl (upload area), UnitBannerUrl (upload area), PrimaryColorHex color-picker (2-col left) |

**Form Footer** (bottom of form card):
- Left: Save / Save & Add Another / Cancel
- Right (edit mode only): Created + Last-Modified metadata + Delete button (disabled with tooltip showing child/staff/contact counts if delete-blocked)

**Field Widget Mapping** (RHF + Zod schema):

| Field | Section | Widget | Placeholder / Default | Validation | Notes |
|-------|---------|--------|-----------------------|------------|-------|
| UnitName | 1 | text | "Enter unit name" | required, max 100 | |
| ShortName | 1 | text | "Short/abbreviated name" | max 50 | |
| UnitCode | 1 | text | "e.g., BR-DXB" | required, max 100, pattern matches `{prefix}-{chars}` | Helper text: "Auto-generated from type + name. Leave empty to auto-gen." |
| IsActive (Status) | 1 | toggle-switch | Default: true | — | "Active" label |
| UnitTypeId | 1 | **card-selector** (4 cards) | Required | — | Changing re-derives UnitCode prefix |
| ParentUnitId | 1 | **tree-dropdown** | Required UNLESS UnitType=HQ | — | Hierarchical list with indentation + code; search box inside menu; excludes self+descendants |
| Description | 1 | textarea | "Brief description of this unit's purpose and scope" | max 500 | 3 rows |
| CountryId | 2 | ApiSelectV2 | "Select country..." | Required for REG/BR/SU | Query: `countries`; label: flag + name |
| StateId | 2 | ApiSelectV2 | "Select state/province..." | — | Query: `states` filtered by CountryId |
| CityId | 2 | ApiSelectV2 | "Select city..." | — | Query: `cities` filtered by StateId |
| PostalCode | 2 | text | "Postal code" | max 20 | |
| AddressLine1 | 2 | text | "Street address, building" | max 200 | |
| AddressLine2 | 2 | text | "Suite, floor, etc." | max 200 | |
| PhonePrefix | 2 | static-input (read-only) | From Country.PhoneCode | — | Left part of phone-input |
| Phone | 2 | text | "Phone number" | digits/space/dash/parens | Right part of phone-input |
| Email | 2 | email | "unit@organization.org" | RFC email | |
| TimezoneId | 2 | ApiSelectV2 | "Asia/Dubai (GMT+4)" | — | Query: `masterDatas` where typeCode=TIMEZONE; auto-fill from Country |
| ManagerStaffId | 3 | ApiSelectV2 | "Select manager..." | — | Query: `staffs`; label: `{StaffName} — {Role} ({UnitName})` |
| DeputyStaffId | 3 | ApiSelectV2 | "Select deputy (optional)..." | — | Same as Manager |
| EffectiveDate | 3 | date-picker | — | ≤ today + 5y | |
| Notes | 3 | textarea | "Internal notes about this unit" | max 1000 | 4 rows |
| AnnualFundraisingTarget | 4 | number (currency-prefix) | "0.00" | ≥ 0, decimal(18,2) | Prefix shows selected target currency code |
| TargetCurrencyId | 4 | ApiSelectV2 | "AED — UAE Dirham" | — | Query: `currencies`; label: `{Code} ({Symbol}) — {Name}` |
| TargetPeriodId | 4 | ApiSelectV2 | "Calendar Year (Jan-Dec)" | — | Query: `masterDatas` typeCode=TARGETPERIOD |
| AcceptsDonationsDirectly | 4 | toggle-switch | Default: true | — | Hint: "If No, donations allocated to child units only" |
| LinkedDonationPurposes (junction) | 4 | **multi-chip-select** | — | — | Query: `donationPurposes`; chips with × to remove; empty = all allowed |
| DefaultPaymentMethods (junction) | 4 | **checkbox-grid** | Defaults: Cash+Cheque+BankTransfer+Online checked | at least 1 | 5 checkboxes — labels from `paymentModes` query |
| DataVisibilityId | 5 | **3-radio-cards** (stacked) | Default: Inherited (middle) | Required | Isolated / Inherited / Global — description below each |
| DefaultCurrencyId | 5 | ApiSelectV2 | "AED — UAE Dirham" | — | Query: `currencies` |
| FiscalYearStartMonth | 5 | select | Default: 1 (January) | 1..12 | Options: Jan/Apr/Jul/Oct (per mockup) |
| AutoAssignContactsByRegion | 5 | toggle-switch | Default: true | — | Hint: "New contacts from this unit's country/city are auto-assigned" |
| UnitLogoUrl | 6 | file-upload-area | "Click to upload logo" | max 2MB, PNG/JPG/SVG | **SERVICE_PLACEHOLDER** — FE captures file, handler shows toast, URL not persisted (stub) |
| UnitBannerUrl | 6 | file-upload-area | "Click to upload banner" | max 5MB | **SERVICE_PLACEHOLDER** — same |
| PrimaryColorHex | 6 | **color-hex-picker** (REUSE from StaffCategory #43) | Default: empty | pattern `#[0-9A-Fa-f]{6}` | Shows hex next to swatch |

**Special Form Widgets**:

- **UnitType Card Selector** (section 1 — 4 cards in 2×2 grid):
  | Card | Icon | Label | Description |
  |------|------|-------|-------------|
  | HQ | fa-building blue | Headquarters (HQ) | Top-level entity (usually only one) |
  | Region | fa-globe green | Region | Geographic or operational grouping |
  | Branch | fa-building-flag amber | Branch | Physical office or operational unit |
  | Sub-unit | fa-file-alt slate | Sub-unit / Program | Department, program, or project |

- **Parent Unit Tree Dropdown** (section 1):
  - Custom component — toggle button shows "[UnitName] ([UnitCode])"
  - Menu: search input at top + hierarchical list with `indent-1`/`indent-2`/`indent-3` classes matching HierarchyLevel
  - Each item: `[typeIcon colored] [UnitName] [UnitCode monospace right-aligned]`
  - Excludes: self + all descendants (for edit mode — prevents cycle)
  - Excludes: same-type-or-lower units (can't pick a Branch as parent of a Region)
  - When UnitType=HQ → dropdown disabled with value "None (top-level)"

- **Data Visibility 3-Radio Cards** (section 5):
  | Card | Icon | Label | Description |
  |------|------|-------|-------------|
  | Isolated | 🔒 | Own data only | Users in this unit see only this unit's records |
  | Inherited | 👁️ | Include child units | Users see this unit + all children (default) |
  | Global | 🌐 | All units | Users see entire organization's data |

- **Conditional Rules**: When UnitType=HQ is selected, disable ParentUnit dropdown (auto-null) and CountryId is still allowed but optional.

**Inline Mini Display**: None (form is standalone — no donor-card-style displays).

**Child Grids in Form**: None inline — the junction tables (LinkedDonationPurposes, DefaultPaymentMethods) are captured via multi-select widgets, not nested grids.

---

#### LAYOUT 2: DETAIL (mode=read or node selected)

> Not a separate page — rendered as the **right panel of the index view** (see ⑥ Split-Pane → RIGHT PANEL above for full spec). When URL is `?mode=read&id=X`, the index page auto-selects node X in the tree and scrolls its detail panel into view. No dedicated `DetailPage` component is needed beyond what the right panel already provides.

**Page Header**: Reuses main ScreenHeader (no form-page-header). Detail-internal header sits inside right panel (see above).

**If user explicitly expects a standalone detail URL**: fall back to a thin `<DetailStandaloneWrapper>` that mounts the same `<OrganizationalUnitDetailPanel>` component in a full-page container. This is optional — not in mockup, build only if approval deems it needed.

---

### Grid Aggregation Columns

None on the tree view. In the List view mode, computed columns come from the `getOrganizationalUnitTree` response (each node carries `staffCount`, `annualTarget`, `ytdCollection`) — these are per-row LINQ subqueries in the tree-query handler.

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User lands on `/organizationalunit` → INDEX renders (widgets + tree + empty right panel with "Select a unit" prompt).
2. User clicks a tree row → right panel loads detail with 4 tabs.
3. User clicks "+Add Unit" (header) → URL: `?mode=new` → FORM LAYOUT (empty). Submit → redirects to `?mode=read&id={newId}` (tree with new node selected).
4. User clicks detail panel's Edit button → URL: `?mode=edit&id={id}` → FORM LAYOUT (pre-filled). Submit → back to `?mode=read&id={id}`.
5. User clicks "Add Child" in detail panel → URL: `?mode=new&parentUnitId={parentId}&unitTypeId={nextTypeCode}` → FORM with parent+type pre-filled.
6. User right-clicks tree node → context menu → Move opens a `<MoveUnitModal>` (select new parent via tree dropdown); Delete opens a confirm dialog (blocked with reason if guard triggers).
7. Expand/Collapse All → toggles all tree-children groups.
8. View toggle Tree↔List → swaps left panel rendering (no URL change, stored in Zustand).
9. Back from form → `?mode=index` (default) → returns to tree with prior selection restored.
10. Unsaved-changes dialog: existing `OrganizationalUnitViewPage` dialog reused.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical FLOW reference (`SavedFilter`) to THIS entity.

**Canonical Reference**: **SavedFilter (FLOW)** for the router/store/view-page shell + **DuplicateContact #21 (FLOW with custom index)** for the custom split-pane index pattern.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | OrganizationalUnit | Entity/class name |
| savedFilter | organizationalUnit | Variable/field names |
| SavedFilterId | OrganizationalUnitId | PK field |
| SavedFilters | OrganizationalUnits | Table name, collection names |
| saved-filter | organizational-unit | FE file names (kebab-case) — e.g., `organizational-unit-store.ts` (already exists) |
| savedfilter | organizationalunit | FE folder, import paths |
| SAVEDFILTER | ORGANIZATIONALUNIT | Grid code, menu code |
| notify | app | DB schema |
| Notify | Application | Backend group name (NotifyModels → ApplicationModels) |
| NotifyModels | ApplicationModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_ORGANIZATION | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/organization/organizationalunit | FE route path |
| notify-service | contact-service | FE service folder name (existing — keep) |

**Group naming note**: Despite the schema being `app` and group being `ApplicationModels`, the FE DTO/GQL live under `contact-service` folder (existing convention — preserve). Don't move them to an `application-service` folder.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> ALIGN scope — extend 11 existing BE files, add 5 new BE files; keep 5 FE shell files, rewrite 1 wizard + 7 wizard-child files → delete, create ~14 new FE files.

### Backend Files — EXISTING to MODIFY (11)

| # | File | Path | Changes |
|---|------|------|---------|
| 1 | Entity | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs` | Add 25 new scalar/FK props + 2 junction collections (OrganizationalUnitDonationPurposes, OrganizationalUnitPaymentModes) + nav props (Country/State/City/ManagerStaff/DeputyStaff/TimezoneType/TargetPeriodType/DataVisibilityType/TargetCurrency/DefaultCurrency) |
| 2 | EF Config | `.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/OrganizationalUnitConfiguration.cs` | Add HasOne nav configs for 8 new FKs (OnDelete.Restrict), column lengths for new string fields, check constraint for `HierarchyLevel BETWEEN 1 AND 4`, index on ParentUnitId for tree traversal |
| 3 | Schemas (DTOs) | `.../Base.Application/Schemas/ApplicationSchemas/OrganizationalUnitSchemas.cs` | Extend RequestDto with 25 new fields + 2 junction ID lists (DonationPurposeIds: int[] / PaymentModeIds: int[]); extend ResponseDto with nav dtos; add `OrganizationalUnitSummaryDto`, `OrganizationalUnitTreeNodeDto` (recursive: children + staffCount + annualTarget + ytdCollection), `OrganizationalUnitDetailDto` (tabs data) |
| 4 | Create Command | `.../Business/ApplicationBusiness/OrganizationalUnits/Commands/CreateOrganizationalUnit.cs` | Handler: auto-gen UnitCode if empty; auto-compute HierarchyLevel from parent; validate HQ singleton per Company; validate parent type-level ladder; save junction rows |
| 5 | Update Command | `.../Commands/UpdateOrganizationalUnit.cs` | Handler: re-compute HierarchyLevel if ParentUnitId changed; cycle check; re-sync junctions (OrganizationalUnitDonationPurposes / OrganizationalUnitPaymentModes) via diff |
| 6 | Delete Command | `.../Commands/DeleteOrganizationalUnit.cs` | Validator: add BadRequestException guards (has children / has staff / has contacts / has donations); keep existing toggle-based soft-delete |
| 7 | Toggle Command | `.../Commands/ToggleOrganizationalUnit.cs` | Handler: prevent deactivating HQ; no cascade |
| 8 | GetAll Query | `.../Queries/GetOrganizationalUnit.cs` | Extend projection to include 25 new fields, FK nav displays, staffCount/annualTarget/ytdCollection subqueries for list view; add CompanyScope filter; add advancedFilter support (UnitTypeId / ParentUnitId / CountryId / IsActive) |
| 9 | GetById Query | `.../Queries/GetOrganizationalUnitById.cs` | Extend Includes (Country, State, City, ManagerStaff, DeputyStaff, TargetCurrency, DefaultCurrency, TimezoneType, TargetPeriodType, DataVisibilityType, OrganizationalUnitDonationPurposes.DonationPurpose, OrganizationalUnitPaymentModes.PaymentMode) |
| 10 | Mutations | `.../Base.API/EndPoints/Application/Mutations/OrganizationalUnitMutations.cs` | Register 2 new mutations: `MoveOrganizationalUnit(organizationalUnitId, newParentUnitId)`, `UpsertOrganizationalUnitJunctions(organizationalUnitId, donationPurposeIds, paymentModeIds)` (optional — can also be folded into Update); ensure GQL arg names align with FE hot-patch precedent |
| 11 | Queries | `.../Base.API/EndPoints/Application/Queries/OrganizationalUnitQueries.cs` | Register 3 new queries: `getOrganizationalUnitTree`, `getOrganizationalUnitSummary`, `getOrganizationalUnitDetail(organizationalUnitId)` |

### Backend Files — NEW to CREATE (5 + migration + junctions)

| # | File | Path |
|---|------|------|
| 12 | Tree Query | `.../Business/ApplicationBusiness/OrganizationalUnits/Queries/GetOrganizationalUnitTree.cs` |
| 13 | Summary Query | `.../Business/ApplicationBusiness/OrganizationalUnits/Queries/GetOrganizationalUnitSummary.cs` |
| 14 | Detail Query | `.../Business/ApplicationBusiness/OrganizationalUnits/Queries/GetOrganizationalUnitDetail.cs` |
| 15 | Move Command | `.../Business/ApplicationBusiness/OrganizationalUnits/Commands/MoveOrganizationalUnit.cs` |
| 16 | Junction entity | `.../Base.Domain/Models/ApplicationModels/OrganizationalUnitDonationPurpose.cs` |
| 17 | Junction entity | `.../Base.Domain/Models/ApplicationModels/OrganizationalUnitPaymentMode.cs` |
| 18 | Junction EF config | `.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/OrganizationalUnitDonationPurposeConfiguration.cs` |
| 19 | Junction EF config | `.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/OrganizationalUnitPaymentModeConfiguration.cs` |
| 20 | Migration | `.../Base.Infrastructure/Migrations/{timestamp}_Add_OrganizationalUnit_ExtendedFields.cs` + Designer + snapshot delta |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` (Base.Application/Data/Persistence) | DbSet<OrganizationalUnitDonationPurpose>, DbSet<OrganizationalUnitPaymentMode> |
| 2 | `ApplicationDbContext.cs` (Base.Infrastructure/Data/Persistence) | DbSet properties + OnModelCreating apply new configurations |
| 3 | `DecoratorProperties.cs` — DecoratorApplicationModules section | Add junction decorators (or reuse OrganizationalUnit decorator) |
| 4 | `ApplicationMappings.cs` (if exists) OR `ContactMappings.cs` (where existing mappings live) | Add Mapster configs for new DTO fields (junction collections Adapt into List<int>), SummaryDto, TreeNodeDto, DetailDto |

### Frontend Files — EXISTING to MODIFY (4) / REWRITE (4) / DELETE (8+)

**MODIFY (keep shell, update contents):**

| # | File | Path | Changes |
|---|------|------|---------|
| 1 | Route Page | `src/app/[lang]/crm/organization/organizationalunit/page.tsx` | No change (thin wrapper) |
| 2 | Page Config | `src/presentation/pages/crm/organization/organizationalunit.tsx` | No change (capability guard + PageConfig wrapper) |
| 3 | Router Index | `src/presentation/components/page-components/crm/organization/organizationalunit/index.tsx` | Keep URL dispatcher logic; ensure `?mode=read&id=X` routes to `<OrganizationalUnitIndexPage>` with preselectedId (not view-page). Remove `resetStore` call on navigation to same tree — breaks user flow. |
| 4 | DTO | `src/domain/entities/contact-service/OrganizationalUnitDto.ts` | Extend `OrganizationalUnitRequestDto` with 25 new fields + `donationPurposeIds: number[]` + `paymentModeIds: number[]`; extend Response with FK nav dtos; add `OrganizationalUnitSummaryDto`, `OrganizationalUnitTreeNodeDto`, `OrganizationalUnitDetailDto` |
| 5 | GQL Query | `src/infrastructure/gql-queries/contact-queries/OrganizationalUnitQuery.ts` | Fix formatting; extend ORGANIZATIONALUNITS_QUERY to include 25 new fields + junction arrays; extend ORGANIZATIONALUNIT_BY_ID_QUERY same; ADD ORGANIZATIONALUNIT_TREE_QUERY, ORGANIZATIONALUNIT_SUMMARY_QUERY, ORGANIZATIONALUNIT_DETAIL_QUERY |
| 6 | GQL Mutation | `src/infrastructure/gql-mutations/contact-mutations/OrganizationalUnitMutation.ts` | Fix formatting; extend CREATE + UPDATE with 25 new fields + junction arrays; ADD MOVE_ORGANIZATIONALUNIT_MUTATION |

**REWRITE from scratch:**

| # | File | Path | Changes |
|---|------|------|---------|
| 7 | Index Page | `.../organizationalunit/index-page.tsx` | Replace `<FlowDataTable gridCode="ORGANIZATIONALUNIT">` with `<ScreenHeader>` + `<OrganizationalUnitWidgets>` + `<SplitPane>` containing `<OrganizationalUnitTree>` + `<OrganizationalUnitDetailPanel>` |
| 8 | View Page | `.../organizationalunit/view-page.tsx` | Keep shell (FlowFormPageHeader + unsaved dialog + back/edit handlers), replace `<OrganizationalUnitWizard>` body with `<OrganizationalUnitForm>` (6-section stacked-cards RHF form) |
| 9 | Form Fields | `.../organizationalunit/form-fields.tsx` | Rewrite entirely — render 6 sections with 30+ fields per mockup (currently renders tab-driven wizard body) |
| 10 | Validation Schema | `.../organizationalunit/organizational-unit-validation-schema.ts` | Rewrite Zod schema for 30+ fields with conditional rules (ParentUnitId required unless UnitType=HQ; CountryId required for REG/BR/SU; email pattern; phone pattern; decimal ≥ 0; junction min 1 payment method) |
| 11 | Store | `src/application/stores/organizationalunit-stores/organizational-unit-store.ts` | Rewrite: remove `campaignStore`/`eventStore`/`donationpurposeStore` sub-stores; remove `openTabs`/`addTab`/`removeTab`; remove `getVisibleTabs`/`unitTypeCode`/`resetAllChildStores`. Add: `selectedNodeId`, `expandedNodeIds: number[]`, `searchText`, `statusFilter: 'all'|'active'|'inactive'`, `viewMode: 'tree'|'list'`, `activeDetailTab: 'overview'|'staff'|'targets'|'settings'`, `contextMenu: {nodeId,x,y} | null`, `moveModal: {sourceId,open} | null`. Keep: `formData`, `initialFormData`, `isDirty`, `saveFormCallback`, `setSaveFormCallback`, `resetStore`, `validateForm`. |

**DELETE (wizard-specific — no longer used):**

- `.../organizationalunit/organizational-unit-wizard.tsx`
- `.../organizationalunit/tab-header.tsx`
- `.../organizationalunit/unit-type-selector.tsx` — replace with new card-selector (rename or delete and recreate)
- `.../organizationalunit/organizationalcampaign/` (entire folder: campaign-form-fields.tsx, campaign-grid-tab.tsx, campaign-tab.tsx, campaign-validation-schema.ts)
- `.../organizationalunit/organizationalevent/` (entire folder)
- `.../organizationalunit/organizationaldonationpurpose/` (entire folder)
- `.../organizationalunit/child-crud-option/` (entire folder: child-add-option.tsx, child-update-option.tsx, child-delete-option.tsx)

**CREATE (new):**

| # | File | Path |
|---|------|------|
| 12 | Widgets | `.../organizationalunit/organizationalunit-widgets.tsx` — 4 KPI cards from SummaryDto |
| 13 | Tree Panel | `.../organizationalunit/organizationalunit-tree.tsx` — recursive tree with expand/collapse/search, calls `getOrganizationalUnitTree` |
| 14 | List View | `.../organizationalunit/organizationalunit-list-view.tsx` — flat DFS table |
| 15 | Tree Toolbar | `.../organizationalunit/tree-toolbar.tsx` — search + status filter + view-toggle |
| 16 | Detail Panel | `.../organizationalunit/organizationalunit-detail-panel.tsx` — wrapper with detail header + 4 tabs |
| 17 | Tab | `.../organizationalunit/detail-tabs/overview-tab.tsx` — unit info grid + child units + quick stats |
| 18 | Tab | `.../organizationalunit/detail-tabs/staff-tab.tsx` — staff table (empty if no Staff.OrganizationalUnitId FK yet) |
| 19 | Tab | `.../organizationalunit/detail-tabs/targets-tab.tsx` — target card + monthly chart placeholder + by-child table + peer comparison |
| 20 | Tab | `.../organizationalunit/detail-tabs/settings-tab.tsx` — data-access radio + unit config |
| 21 | Context Menu | `.../organizationalunit/context-menu.tsx` — 6-item right-click menu |
| 22 | Move Modal | `.../organizationalunit/move-unit-modal.tsx` — parent picker + cycle-check warning |
| 23 | Form | `.../organizationalunit/organizationalunit-form.tsx` — 6-section stacked-cards RHF form (replaces wizard body) |
| 24 | Card Selector | `.../organizationalunit/unit-type-card-selector.tsx` — 4 visual cards (HQ/REG/BR/SU) |
| 25 | Dropdown | `.../organizationalunit/parent-unit-tree-dropdown.tsx` — hierarchical dropdown with indent |
| 26 | Multi-chip | `.../organizationalunit/donation-purpose-chip-select.tsx` — multi-select chips |
| 27 | Checkbox group | `.../organizationalunit/payment-methods-checkbox-group.tsx` — 5 checkboxes |
| 28 | Uploader | `.../organizationalunit/logo-banner-uploader.tsx` — file-input stub (SERVICE_PLACEHOLDER) |
| 29 | Data Visibility | `.../organizationalunit/data-visibility-radio-cards.tsx` — 3 radio cards |
| 30 | Renderer (shared) | `src/presentation/components/custom-components/renderer/unit-type-badge-renderer.tsx` — colored badge (HQ blue / REG green / BR amber / SU slate) for reuse in list-view + detail header |
| 31 | Renderer (shared) | `src/presentation/components/custom-components/renderer/hierarchy-indent-renderer.tsx` — indented-name cell (used in list view) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/presentation/components/custom-components/index.ts` (or column-type registries — advanced + basic + flow) | Register `unit-type-badge` + `hierarchy-indent` component keys |
| 2 | `src/presentation/components/custom-components/renderer/index.ts` | Export new renderers |
| 3 | `src/application/stores/organizationalunit-stores/index.ts` | Re-export updated store (type changes propagate) |
| 4 | `src/application/stores/index.ts` | No change (re-export via barrel) |
| 5 | `src/presentation/components/page-components/crm/organization/organizationalunit/index.ts` (barrel, if any) | Re-export new sub-components; remove deleted ones |
| 6 | `src/domain/entities/contact-service/index.ts` | No change to named exports (DTO names unchanged) |
| 7 | `src/infrastructure/gql-queries/contact-queries/index.ts` | Add ORGANIZATIONALUNIT_TREE_QUERY, ORGANIZATIONALUNIT_SUMMARY_QUERY, ORGANIZATIONALUNIT_DETAIL_QUERY exports |
| 8 | `src/infrastructure/gql-mutations/contact-mutations/index.ts` | Add MOVE_ORGANIZATIONALUNIT_MUTATION export |

**CROSS-SCREEN FOLLOW-UP (out-of-scope for this build, flagged):**
- `src/presentation/components/page-components/crm/communication/emailsendjob/components/OrganizationalUnitCreateModal.tsx` — currently creates OrgUnit inline; after BE schema change, verify the inline-create modal still sends a valid subset (or update it). ISSUE-9.

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled from `MODULE_MENU_REFERENCE.md` (CRM_ORGANIZATION MenuId=270, OrderBy=1).

```
---CONFIG-START---
Scope: ALIGN

MenuName: Organizational Units
MenuCode: ORGANIZATIONALUNIT
ParentMenu: CRM_ORGANIZATION
Module: CRM
MenuUrl: crm/organization/organizationalunit
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: ORGANIZATIONALUNIT
---CONFIG-END---
```

**Seed expectations:**
- Menu row upsert (idempotent ON CONFLICT) at OrderBy=1 under CRM_ORGANIZATION — likely already present; verify
- MenuCapabilities rows present
- Role×Capability grants for BUSINESSADMIN
- **NO GridFormSchema** (FLOW + custom index — not FlowDataTable)
- **NO Grid row required** — the List view is a custom component, not driven by server Grid/Fields config
- MasterData seed (idempotent): 4 UNITTYPE rows (HQ/REG/BR/SU with icon codes), TIMEZONE rows (10+ common zones per mockup options), TARGETPERIOD 3 rows (CALENDAR/FISCAL/CUSTOM), DATAVISIBILITY 3 rows (ISOLATED/INHERITED/GLOBAL with icons 🔒/👁️/🌐 in DataSetting), ensure existing PAYMENTMODE rows include Cash/Cheque/BankTransfer/Online/MobileMoney (seed-if-missing)
- Sample OrganizationalUnits: 12 rows matching mockup tree (1 HQ + 4 Regions + 8 Branches + 5 Sub-units — HQ-001 + REG-NA/REG-MEA/REG-SA/REG-EU + BR-NY/LA/CHI/DXB/RYD/NBO/CAI[inactive]/MUM/DEL/DHK/LON/PAR[inactive] + SU-NY-ED/SU-NY-HC/SU-LA-CO/SU-DXB-OC/SU-DXB-WW/SU-MUM-SE/SU-MUM-WE) — 26 total matching mockup exactly
- Junction seed: LinkedDonationPurposes for BR-DXB matching mockup 3 chips; DefaultPaymentMethods for all branches
- Seed file path: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/OrganizationalUnit-sqlscripts.sql` (preserve repo typo per SMSTemplate #29 ISSUE-5 precedent)

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `OrganizationalUnitQueries`
- Mutation type: `OrganizationalUnitMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `organizationalUnits` | PaginatedApiResponse<[OrganizationalUnitResponseDto]> | request: GridFeatureRequest (pageSize/pageIndex/sort/searchTerm/advancedFilter) |
| `organizationalUnitById` | BaseApiResponse<OrganizationalUnitResponseDto> | organizationalUnitId: Int! |
| `getOrganizationalUnitTree` | BaseApiResponse<[OrganizationalUnitTreeNodeDto]> | — (returns root nodes with children recursive, tenant-scoped) |
| `getOrganizationalUnitSummary` | BaseApiResponse<OrganizationalUnitSummaryDto> | — |
| `getOrganizationalUnitDetail` | BaseApiResponse<OrganizationalUnitDetailDto> | organizationalUnitId: Int! |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createOrganizationalUnit` | OrganizationalUnitRequestDto (35+ fields incl. donationPurposeIds: [Int!], paymentModeIds: [Int!]) | BaseApiResponse<OrganizationalUnitRequestDto> |
| `updateOrganizationalUnit` | OrganizationalUnitRequestDto | BaseApiResponse<OrganizationalUnitRequestDto> |
| `deleteOrganizationalUnit` | organizationalUnitId: Int! | BaseApiResponse — with guard errors |
| `activateDeactivateOrganizationalUnit` | organizationalUnitId: Int! | BaseApiResponse |
| `moveOrganizationalUnit` | organizationalUnitId: Int!, newParentUnitId: Int! | BaseApiResponse — with cycle check |

**Response DTO Fields (what FE receives)** — `OrganizationalUnitResponseDto`:

All existing fields + all 25 new scalar fields (camelCase) + nav objects (country, state, city, managerStaff, deputyStaff, timezoneType, targetPeriodType, dataVisibilityType, targetCurrency, defaultCurrency) + arrays `donationPurposeIds: number[]` + `paymentModeIds: number[]` + (for list view) subquery fields `staffCount: number`, `annualTargetBase: number` (converted to base currency), `ytdCollectionBase: number`.

**Tree Node DTO** — `OrganizationalUnitTreeNodeDto`:
```ts
{ organizationalUnitId, unitCode, unitName, unitTypeId, unitTypeCode, hierarchyLevel, parentUnitId, isActive, staffCount, annualTargetBase, ytdCollectionBase, children: OrganizationalUnitTreeNodeDto[] }
```

**Summary DTO** — `OrganizationalUnitSummaryDto`:
```ts
{ totalUnits, activeUnits, inactiveUnits, maxHierarchyLevel, totalStaffCount, totalAnnualTargetBase, ytdCollectedBase, achievedPercent }
```

**Detail DTO** — `OrganizationalUnitDetailDto`:
```ts
{
  unit: OrganizationalUnitResponseDto,
  quickStats: { totalContacts, donationsYtdBase, activeCampaigns, upcomingEvents, staffCount },
  childUnits: OrganizationalUnitTreeNodeDto[],
  assignedStaff: { staffId, staffName, roleName, email, isActive, assignedSince }[],
  targets: { annualTargetBase, ytdCollectedBase, monthlyAverage, projectedYearEnd, projectedPercent, monthlyBreakdown: { year, month, amount }[], byChildUnit: { unitId, unitName, target, collected, percent }[], peerComparison: { rank, unitId, unitName, target, collected, percent }[] },
  settings: { dataVisibilityId, defaultCurrencyId, timezoneId, fiscalYearStartMonth, autoAssignContactsByRegion }
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (extended mappings + new junction entities compile)
- [ ] Migration applies cleanly — 25 new columns + 2 junction tables + HierarchyLevel check constraint
- [ ] EF snapshot regenerated (user runs `dotnet ef migrations add --dry-run` locally)
- [ ] `pnpm dev` + `pnpm tsc --noEmit` — 0 new TS errors

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Landing on `/crm/organization/organizationalunit` → 4 widgets render with tenant-scoped counts
- [ ] Tree renders HQ → Regions → Branches → Sub-units from seed
- [ ] Expand/Collapse All toggle works across all levels
- [ ] Search "Dubai" filters tree; Clear search restores full tree
- [ ] Status filter Active/Inactive works
- [ ] View toggle Tree↔List works; List shows indentation + all 8 columns per mockup
- [ ] Clicking HQ-001 → right panel shows detail with 4 tabs; Overview tab shows unit info + child-unit list + 5 quick stats
- [ ] Staff tab shows staff assigned to this unit (empty with "Coming Soon" placeholder if Staff.OrganizationalUnitId FK doesn't exist — see ⑫)
- [ ] Targets tab shows target card + Monthly Breakdown (placeholder chart) + by-child table + peer comparison
- [ ] Settings tab shows data access scope + 4-row unit config + Save button
- [ ] Right-click tree node → 6-item context menu appears; items correctly enabled/disabled
- [ ] `?mode=new` → empty 6-section form renders; type-card selector changes auto-gen prefix
- [ ] UnitType=HQ → ParentUnit dropdown disables; submitting as HQ when another HQ exists → BadRequestException surfaced as toast error
- [ ] UnitType=Branch + Region selected as parent → Save succeeds → tree refreshes → new node selected in right panel
- [ ] Country → State → City cascade works via ApiSelectV2
- [ ] Linked Donation Purposes: add 3 chips → Save → Edit reloads with same 3 chips
- [ ] Default Payment Methods: uncheck Online → Save → reload shows unchecked
- [ ] Data Visibility Inherited radio card selected by default
- [ ] Primary Color picker: choose #0e7490 → hex text updates; Save → reload shows color
- [ ] Logo/Banner upload → toast "File upload coming soon" (SERVICE_PLACEHOLDER)
- [ ] `?mode=edit&id=BR-DXB` → form pre-filled with 30+ fields
- [ ] Delete button disabled when unit has descendants/staff/contacts/donations; tooltip shows counts
- [ ] Move unit via context menu → modal → pick new parent → Save → tree rebuilds with moved subtree + correct HierarchyLevels
- [ ] Deactivate from context menu → toggle persists; node shows inactive status dot
- [ ] Unsaved-changes dialog triggers when dirty form + Back/Cancel clicked
- [ ] `pnpm tsc --noEmit` passes with 0 new errors
- [ ] UI uniformity grep checks: 0 inline hex (colors come from data for typeIcons; everything else tokens), 0 inline pixel spacing, Variant B ScreenHeader confirmed, no raw "Loading…"

**DB Seed Verification:**
- [ ] Menu "Organizational Units" visible in sidebar under CRM → Organization
- [ ] BUSINESSADMIN role has all 8 capabilities (READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT/ISMENURENDER)
- [ ] Tree shows 26 seeded units matching mockup exactly
- [ ] GridFormSchema = NULL (FLOW + custom)
- [ ] MasterData seed applied: UNITTYPE/TIMEZONE/TARGETPERIOD/DATAVISIBILITY populated
- [ ] Junctions seeded per mockup (BR-DXB with 3 donation-purpose chips + 4 payment-methods)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a form field** — set from HttpContext in handlers (EXISTING behavior).
- **FLOW + custom index** — this screen does NOT use `<FlowDataTable>` or a server-driven `gridCode`. Remove the `gridCode="ORGANIZATIONALUNIT"` reference in `index-page.tsx`. The List view is a page-local custom table. GridFormSchema = SKIP.
- **`FlowDataTableStore` still in play** — the existing `index.tsx` router relies on `useFlowDataTableStore().crudMode` / `setCrudMode` / `recordId` / `setRecordId` for URL dispatch. Keep these plumbing hooks; they're orthogonal to the grid. The store's `gridInfo` will be null — that's OK.
- **Mapster configs live in `ContactMappings.cs`, NOT `ApplicationMappings.cs`** — preserve existing location (SavedFilter precedent applied — don't refactor).
- **FE DTO/GQL live under `contact-service` / `contact-queries` / `contact-mutations`** — preserve (BE schema = `app` / group = `ApplicationModels`, but FE convention uses `contact-service`; don't relocate).
- **Existing Wizard design is OBSOLETE** — the wizard treated OrgUnit as a parent wrapping Campaign/Event/DonationPurpose children. Mockup design has OrgUnit as a standalone entity; those children now live under their own screens (#39 Campaign, #40 Event, #2 DonationPurpose). DELETE wizard-child files listed in §⑧. ISSUE-1.
- **Align delete-guard with mockup** — disabled Delete button with tooltip showing counts ("2 child units, 12 staff, 1,234 contacts"). FE reads counts from GetById response (add `descendantsCount`/`staffCount`/`contactsCount`/`donationsCount` to response); BE Delete validator throws BadRequestException with the same 4 counts in the error message.
- **Existing composite unique index** on `(CompanyId, UnitTypeId, ParentUnitId, UnitCode, IsActive)` is preserved. New UnitCode auto-gen logic must check against this index and append numeric suffix on collision.
- **Existing `DropdownLabel` derived prop** in `OrganizationalUnitResponseDto` returns "UnitName - UnitTypeDataName" — preserve (existing consumers in EmailSendJob modal).
- **Staff.OrganizationalUnitId FK may not exist yet** — if it doesn't, the Staff tab in the detail panel renders empty with a "Coming Soon" hint (`SERVICE_PLACEHOLDER`). Check `Staff.cs` for this property before coding; if absent, **do not add it** in this session — flag as ISSUE and route to a dedicated Staff #42 alignment pass. Same applies to Contact.OrganizationalUnitId (for Quick Stats.totalContacts) and Campaign.OrganizationalUnitId (for activeCampaigns).
- **ALIGN scope discipline** — only modify existing files listed in §⑧, do not regenerate from scratch. Preserve existing comments, authorize decorators, mediator patterns.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER: Export Structure button** — mockup shows "Export Structure" button in ScreenHeader. No CSV/PDF export service exists. Full UI implemented, handler shows toast "Export coming soon". ISSUE-2.
- ⚠ **SERVICE_PLACEHOLDER: Unit Logo / Banner upload** — no file-storage service (S3 / Blob) wired. Full UI (upload area with drag-drop) implemented; handler captures File object, shows toast "File upload coming soon", `UnitLogoUrl`/`UnitBannerUrl` remain null. ISSUE-3.
- ⚠ **SERVICE_PLACEHOLDER: Monthly Breakdown chart** — Targets tab shows bar chart mockup. No chart library (Recharts / ECharts) currently wired for this module; render a `<ChartPlaceholder>` with the underlying array shown as text. ISSUE-4.
- ⚠ **SERVICE_PLACEHOLDER: Target by Child Unit + Peer Comparison** — requires donation-by-unit aggregation. BE query returns zeros until `GlobalDonation.OrganizationalUnitId` FK is wired through GlobalDonation's schema alignment (Wave 5 follow-up). For now, show rows with `collected=0` and a subtle hint "Data aggregation pending". ISSUE-5.
- ⚠ **SERVICE_PLACEHOLDER: Staff tab** — contingent on Staff.OrganizationalUnitId FK (see above). ISSUE-6.
- ⚠ **SERVICE_PLACEHOLDER: Assign Staff button (Staff tab)** + **Remove button per row** — no unit-staff assignment flow built yet. Button shows toast. ISSUE-7.
- ⚠ **SERVICE_PLACEHOLDER: Settings tab "Save Settings"** — this writes only the 5 unit-config fields (DataVisibilityId / DefaultCurrencyId / TimezoneId / FiscalYearStartMonth / AutoAssignContactsByRegion) via `updateOrganizationalUnit` with a partial payload. If the BE update validator is strict about required fields, we may need a dedicated `UpsertUnitSettings` mutation. If it accepts partial, reuse. ISSUE-8.
- ⚠ **FOLLOW-UP: emailsendjob OrganizationalUnitCreateModal** — inline-create modal uses old 7-field DTO. After BE schema change, verify the modal still compiles and either gracefully degrades OR is updated to use the new minimal-required-fields subset. Out-of-scope for this build. ISSUE-9.

Full UI must be built (buttons, forms, modals, panels, interactions). Only the handler for the external service call is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning 2026-04-20 | HIGH | FE | Existing wizard/child-tabs design is obsolete — must DELETE 8+ files (wizard, tab-header, unit-type-selector, organizationalcampaign/*, organizationalevent/*, organizationaldonationpurpose/*, child-crud-option/*) before rewrite. Risk: orphaned imports in barrels. | OPEN |
| ISSUE-2 | Planning 2026-04-20 | LOW | FE | "Export Structure" SERVICE_PLACEHOLDER — no CSV/PDF service wired. UI built, handler toasts. | OPEN |
| ISSUE-3 | Planning 2026-04-20 | MED | FE | Logo/Banner upload SERVICE_PLACEHOLDER — no file-storage wired. UI built, handler captures File + toasts. | OPEN |
| ISSUE-4 | Planning 2026-04-20 | LOW | FE | Monthly Breakdown chart SERVICE_PLACEHOLDER — no chart lib wired. Render `<ChartPlaceholder>` stub. | OPEN |
| ISSUE-5 | Planning 2026-04-20 | MED | BE | Target by Child Unit + Peer Comparison aggregation returns zeros until `GlobalDonation.OrganizationalUnitId` wired through. | OPEN |
| ISSUE-6 | Planning 2026-04-20 | HIGH | BE | Staff tab: `Staff.OrganizationalUnitId` FK may not exist. If absent, do NOT add in this session; render empty "Coming Soon" panel. Route to Staff #42 alignment pass. | OPEN |
| ISSUE-7 | Planning 2026-04-20 | LOW | FE | Assign Staff + Remove per-row SERVICE_PLACEHOLDER — no unit-staff assignment flow. Buttons toast. | OPEN |
| ISSUE-8 | Planning 2026-04-20 | MED | BE | Settings-tab "Save Settings" uses partial `updateOrganizationalUnit` payload. If validator requires full RequestDto, create dedicated `UpsertUnitSettings` mutation or relax validator for settings-only scenario. | OPEN |
| ISSUE-9 | Planning 2026-04-20 | LOW | FE-CROSS | `emailsendjob/OrganizationalUnitCreateModal.tsx` uses old 7-field DTO. After BE schema change, verify or update (out of scope for this build). | OPEN |
| ISSUE-10 | Planning 2026-04-20 | MED | BE | Mapster configs live in `ContactMappings.cs` (NOT `ApplicationMappings.cs`) — preserve location on ALIGN edits. | OPEN |
| ISSUE-11 | Planning 2026-04-20 | MED | BE | UnitCode auto-gen collision handling: if generated code collides with `(CompanyId, UnitTypeId, ParentUnitId, UnitCode, IsActive)` composite index, append `-N` numeric suffix. Verify logic handles reactivated-previously-deleted codes. | OPEN |
| ISSUE-12 | Planning 2026-04-20 | HIGH | BE | HQ singleton guard per Company — Create handler must reject if `UnitTypeId == HQ && existing HQ count > 0 for CompanyId`. New business rule (not in existing validator). | OPEN |
| ISSUE-13 | Planning 2026-04-20 | MED | BE | Move command: cycle prevention requires walking descendant subtree — O(N) per move. Pragmatic approach: fetch all descendants once (DbContext `Where(x => x.ParentUnitId == sourceId)` recursively or raw SQL CTE). | OPEN |
| ISSUE-14 | Planning 2026-04-20 | LOW | FE | Existing `resetStore` in `index.tsx` router resets on any grid-mode change. After rewrite, only reset when navigating OUT of form modes; keep tree state (expandedNodeIds/searchText/selectedNodeId) persistent across form↔index transitions for good UX. | OPEN |
| ISSUE-15 | Planning 2026-04-20 | LOW | DB | Seed file path preserves repo typo `sql-scripts-dyanmic/`. | OPEN |
| ISSUE-16 | Planning 2026-04-20 | MED | BE | New junction entities `OrganizationalUnitDonationPurposes` / `OrganizationalUnitPaymentModes` need DbSet registration + Mapster config + Create/Update diff-persist pattern (Family #20 / Contact #18 precedent — add-only / remove-only / keep). | OPEN |
| ISSUE-17 | Planning 2026-04-20 | MED | FE | Tree component must handle deeply-nested recursion without stack overflow (>4 levels unlikely per mockup, but allow any depth). Use iterative DFS for expand-all. | OPEN |
| ISSUE-18 | Planning 2026-04-20 | LOW | UX | Mockup uses both "Deactivate" and "Delete" actions — ensure Delete is hard-delete (with guard) and Deactivate is soft (IsActive=false). Toggle mutation reused for Deactivate. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

No sessions recorded yet — filled in after /build-screen completes.
