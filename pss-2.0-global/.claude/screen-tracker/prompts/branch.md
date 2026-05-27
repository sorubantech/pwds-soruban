---
screen: Branch
registry_id: 41
module: Organization
status: NEEDS_FIX
scope: ALIGN
screen_type: MASTER_GRID
complexity: High
new_module: NO
planned_date: 2026-04-18
completed_date: 2026-04-18
last_session_date: 2026-05-22
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed (BE + FE)
- [x] Business rules extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized
- [x] User Approval received
- [x] Backend code aligned (extend entity + add aggregations + add Summary query)
- [x] Backend wiring updated
- [x] Frontend code aligned (Variant B layout + widgets + side panel + grid columns)
- [x] Frontend wiring updated (remove duplicate route under organizationsetup/)
- [x] DB Seed script generated/updated (GridFormSchema refreshed)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/organization/company/branch`
- [ ] Duplicate route `/{lang}/organizationsetup/branch` removed (or confirmed intentional)
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete)
- [ ] Grid columns render: Branch, Code, Region, Country, City, Head/Manager, Staff, Annual Target, YTD Collected, Performance bar+%, Status
- [ ] RJSF modal form renders all fields + validation
- [ ] FK dropdowns load (Company, Country, State, City, ManagerStaff) via ApiSelectV2
- [ ] Summary widgets display (Total Branches, Total Staff, YTD All, Top Performer)
- [ ] Grid aggregations: StaffCount / YtdCollected / Performance% correctly computed per row
- [ ] Side panel opens on row click (Quick Stats + Recent Activity + Staff mini-list)
- [ ] View-toggle shows Map View as a SERVICE_PLACEHOLDER with toast
- [ ] DB Seed — menu still visible under ORG_COMPANY, grid + form schema render
- [ ] Row-link navigation (View Staff / View Donations dropdown actions) routes correctly

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Branch
Module: Organization → Company
Schema: app
Group: ApplicationModels (namespace `Base.Domain.Models.ApplicationModels`)

Business: Branches are physical or logical office locations of the NGO/charity — e.g., "Mumbai", "New York", "Dubai". Administrators (BusinessAdmin) use this screen to configure every branch: name, code, address, location hierarchy (Region/Country/City), branch head/manager, annual fundraising target, and active status. Branch is a foundational reference table — Staff belong to branches, Donations are attributed to branches, Campaigns can be branch-scoped, and field-collection Ambassadors operate out of branches. The Branch Management screen also serves as a performance overview: summary cards show the fleet-wide view (total branches, total staff, combined YTD collection, top performer), while each grid row shows per-branch staff count, target, YTD collected, and a traffic-light performance bar. A side panel (opened by clicking a branch) shows Quick Stats, a recent activity feed, and a staff mini-list — enabling quick health checks without leaving the grid.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Existing entity is minimal. This ALIGN task ADDS mockup-required fields. Audit columns inherited from Entity base.

Table: `app.Branches`

**Existing fields** (already in `Base.Domain/Models/ApplicationModels/Branch.cs`):
| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| BranchId | int | — | PK | — | Primary key |
| BranchCode | string | 50 | YES | — | e.g., "BR-MUM" — unique per Company |
| BranchName | string | 100 | YES | — | e.g., "Mumbai" |
| CompanyId | int | — | YES | shared.Companies | Multi-tenant FK |
| Address | string | 500 | NO | — | Street address |
| IsActive | bool | — | — | — | Inherited from Entity base |

**New fields to ADD** (from mockup — ALIGN scope):
| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CountryId | int? | — | NO | general.Countries | Location hierarchy — enables country filter + flag display |
| StateId | int? | — | NO | general.States | Location hierarchy — optional (state-less countries allowed) |
| CityId | int? | — | NO | general.Cities | Location hierarchy |
| Region | string | 50 | NO | — | Grouping label (e.g., "South Asia", "MEA", "Europe") — free text or enum |
| ManagerStaffId | int? | — | NO | app.Staffs | Branch head / manager — FK to Staff |
| AnnualTarget | decimal(18,2)? | — | NO | — | Fundraising target in base currency — null = not set |

**Fields NOT added** (covered via aggregation, not stored):
- StaffCount — derived (Staff WHERE BranchId = row.BranchId). Requires `BranchId` FK on Staff entity (ISSUE flagged below).
- YtdCollected — derived (Sum GlobalDonation.NetAmount WHERE BranchId = row.BranchId AND Year = current).
- PerformancePct — derived (YtdCollected / AnnualTarget × 100).

**Existing navs to keep**: Company, BranchUsers, GlobalDonations.
**New reverse nav suggested** (if added during build): `ICollection<Staff>? Staffs` (requires Staff.BranchId FK — flagged in §⑫).

**Children**: None.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (.Include / nav props) + Frontend Developer (ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CompanyId | Company | `Base.Domain/Models/ApplicationModels/Company.cs` | `GetCompanies` (existing; use `GetAllCompanyList` if present) | CompanyName | CompanyResponseDto |
| CountryId | Country | `Base.Domain/Models/RegionModels/Country.cs` | `GetCountries` / `GetAllCountryList` | CountryName | CountryResponseDto |
| StateId | State | `Base.Domain/Models/RegionModels/State.cs` | `GetStates` / `GetAllStateList` (filter by CountryId) | StateName | StateResponseDto |
| CityId | City | `Base.Domain/Models/RegionModels/City.cs` | `GetCities` / `GetAllCityList` (filter by StateId) | CityName | CityResponseDto |
| ManagerStaffId | Staff | `Base.Domain/Models/ApplicationModels/Staff.cs` | `GetStaffs` / `GetAllStaffList` | StaffName | StaffResponseDto |

> **Verify-at-build-time**: The backend agent must confirm the exact GQL query name for each FK by grepping `Base.API/EndPoints/*/Queries/` — the codebase uses both `GetAll{Entity}List` and `Get{Entities}` conventions.

---

## ④ Business Rules & Validation

> **Consumer**: BA → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `BranchCode` must be unique per Company (ValidateUniqueWhenCreate + ValidateUniqueWhenUpdate).
- `BranchName` must be unique per Company.

**Required Field Rules:**
- `BranchCode`, `BranchName`, `CompanyId` are mandatory.
- All other fields (Address, CountryId, StateId, CityId, Region, ManagerStaffId, AnnualTarget) are optional.

**Conditional Rules:**
- If `StateId` is provided, it must belong to the chosen `CountryId` (ValidateParentChildRelationship — if infrastructure exists) — otherwise validator-only at command handler.
- If `CityId` is provided, it must belong to the chosen `StateId`.
- `AnnualTarget` ≥ 0 when provided.

**Business Logic:**
- `PerformancePct` = (YtdCollected / AnnualTarget) × 100 — computed post-projection. If `AnnualTarget` is null or 0, return null (show `—` in grid).
- Performance traffic-light mapping: ≥ 75 % → green; 50–75 % → amber; < 50 % → red.
- Deactivating a branch does NOT cascade — Staff/Donations keep their BranchId. UI shows an "inactive" badge but history is preserved.

**Workflow**: None.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered decisions.

**Screen Type**: MASTER_GRID
**Type Classification**: Type 2 — flat master with multiple FKs + aggregation columns + side panel + summary widgets (enriched master grid, same class as ContactType #19).
**Reason**: Add/Edit in mockup opens a form (mockup's `parent.loadContent('organization/org-unit-form')` is a mockup-preview convention shared with Org Unit). In PSS 2.0 convention, MASTER_GRID uses an RJSF modal driven by GridFormSchema — Branch fits this pattern because the form is shallow and flat (no sections / tabs / child grids).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — entity, EF config, schemas, Create/Update/Delete/Toggle, GetAll, GetById, Mutations, Queries
- [x] Multi-FK validation (ValidateForeignKeyRecord × 5) — Company, Country, State, City, ManagerStaff
- [x] Unique validation — BranchCode + BranchName per Company
- [x] Summary query (`GetBranchSummary`) — drives the 4 KPI cards
- [x] Grid aggregation via post-projection — StaffCount, YtdCollected, PerformancePct
- [ ] Nested child creation — no
- [ ] File upload — no
- [x] ALIGN-mode migrations — new columns on app.Branches (CountryId, StateId, CityId, Region, ManagerStaffId, AnnualTarget)

**Frontend Patterns Required:**
- [x] AdvancedDataTable (via `DataTableContainer` with `showHeader={false}` — Variant B)
- [x] ScreenHeader at page root (title, subtitle, fullscreen toggle, breadcrumb)
- [x] RJSF Modal Form (driven by GridFormSchema from DB seed)
- [x] Summary cards / count widgets (4 widgets — see ⑥)
- [x] Grid aggregation columns (StaffCount, YtdCollected, Performance bar+%)
- [x] Info panel / side panel (Quick Stats + Activity Feed + Staff mini-list)
- [x] Service placeholder: Map View toggle (opens toast — no map lib wired yet)
- [x] Row click-through actions: View Staff, View Donations (navigate to existing routes with pre-filter)
- [ ] Drag-to-reorder — no
- [x] Custom column renderer: `performance-bar` (reuse `link-count`/`progress-bar` family, or create new renderer)
- [x] Custom column renderer: `country-flag` (flag-emoji + country name — small, new)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Source: [html_mockup_screens/screens/organization/branch-management.html](../../../html_mockup_screens/screens/organization/branch-management.html).

### Grid/List View

**Grid Columns** (in display order — 12 columns):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Branch | branchName | text (primary — clickable opens side panel) | auto | YES | Accent color, bold |
| 2 | Code | branchCode | badge-code (mono font, light bg) | 100px | YES | e.g., "BR-MUM" |
| 3 | Region | region | text | 120px | YES | e.g., "South Asia" |
| 4 | Country | country.countryName + flag | country-flag renderer | 140px | YES | Emoji flag + name |
| 5 | City | city.cityName | text | 120px | YES | — |
| 6 | Head / Manager | managerStaff.staffName | text | 160px | YES | FK display |
| 7 | Staff | staffCount | number | 80px | YES | Aggregation — count of Staff WHERE BranchId = row.Id |
| 8 | Annual Target | annualTarget | currency | 130px | YES | Format: `$300,000` |
| 9 | YTD Collected | ytdCollected | currency | 130px | YES | Aggregation — sum over current year |
| 10 | Performance | performancePct | **performance-bar** renderer (bar + % label, traffic-light color) | 160px | YES | Color rule: ≥75 green, 50-75 amber, <50 red |
| 11 | Status | isActive | status-badge (Active/Inactive) | 100px | YES | Standard active badge |
| 12 | Actions | — | row-actions | 140px | NO | View / Edit / More dropdown |

**Search Fields** (for the single search input): `branchName`, `branchCode`, `city.cityName`.

**Filters** (dropdown selects in filter bar — map to grid-config filters):
- Region (text dropdown populated from distinct Region values)
- Country (`ApiSelectV2` → GetAllCountryList)
- Status (Active / Inactive / All)
- Performance bucket (`Above Target (>75%)` / `On Track (50-75%)` / `Below Target (<50%)`) — client-side filter on `performancePct`

**Row Actions** (primary pair + 3-dot dropdown):
- Primary: **View** (opens side panel) — already rendered inline
- Primary: **Edit** (opens RJSF modal)
- Dropdown: View Details, Edit, **View Staff** (link to `/{lang}/organization/staff/staff?branchId={id}`), **View Donations** (link to `/{lang}/crm/donation/globaldonation?branchId={id}`), Deactivate/Activate

### RJSF Modal Form

> Modal popup form — fields driven by GridFormSchema in DB seed. FE developer does NOT hand-code the form.

**Form Sections** (in order — 2 sections):
| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | Branch Information | 2-column | branchCode, branchName, region, managerStaffId, annualTarget |
| 2 | Location | 2-column | countryId, stateId, cityId, address (full-width textarea) |

**Field Widget Mapping**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| branchCode | text | "e.g., BR-MUM" | required, max 50, unique per company | Uppercase hint |
| branchName | text | "e.g., Mumbai" | required, max 100, unique per company | — |
| region | text (or select if enum seeded) | "e.g., South Asia" | max 50 | Free text for now (seed common values in DB seed) |
| managerStaffId | ApiSelectV2 | "Select manager" | — | Query: `GetAllStaffList` (can filter by CompanyId) |
| annualTarget | number (currency) | "0.00" | ≥ 0 | Decimal(18,2) |
| countryId | ApiSelectV2 | "Select country" | — | Query: `GetAllCountryList`, onChange resets state/city |
| stateId | ApiSelectV2 (cascading) | "Select state" | — | Query: `GetAllStateList` filtered by countryId |
| cityId | ApiSelectV2 (cascading) | "Select city" | — | Query: `GetAllCityList` filtered by stateId |
| address | textarea (full-width) | "Street address" | max 500 | Optional |

### Page Widgets & Summary Cards

**Widgets**: 4 summary KPI cards above the grid.

**Layout Variant**: `widgets-above-grid+side-panel`
→ FE Dev **MUST** use **Variant B**: `<ScreenHeader>` at page root, followed by `<BranchWidgets>` (4-col grid), followed by a flex row with `<DataTableContainer showHeader={false}>` on the left (flex-1) and `<BranchSidePanel>` on the right (w-80/w-96). Wrap the whole page in `<AdvancedDataTableStoreProvider>` at page root so the side panel can consume the selected row. Follow ContactType #19 (Session 2 UI fix) precedent exactly. Failing to use Variant B causes the duplicate-header bug.

| # | Widget Title | Value Source (from `GetBranchSummary`) | Display Type | Position | Icon |
|---|-------------|----------------------------------------|-------------|----------|------|
| 1 | Total Branches | `totalBranches` (main) + `"Active: {active} · Inactive: {inactive}"` (sub) | count + sub-text | 1/4 | ph:buildings (blue) |
| 2 | Total Staff | `totalStaff` (main) + `"Avg per branch: {avgPerBranch}"` (sub) | count + sub-text | 2/4 | ph:users (purple) |
| 3 | YTD Collection (All Branches) | `ytdCollectionAll` (currency) + `"Target: {totalTarget} ({targetAchievedPct}%)"` (sub) | currency + sub-text | 3/4 | ph:coins (green) |
| 4 | Top Performing Branch | `topBranchName` (main) + `"{topBranchPct}% of target"` (sub) | text + sub-text | 4/4 | ph:trophy (amber) |

**Summary GQL Query** (NEW — must be added):
- Query name: `GetBranchSummary`
- Returns: `BranchSummaryDto`
  - `totalBranches: int`
  - `activeCount: int`
  - `inactiveCount: int`
  - `totalStaff: int` (derived — see §⑫ ISSUE-1 if Staff.BranchId FK missing)
  - `avgPerBranch: decimal` (totalStaff / activeCount; 0 if activeCount == 0)
  - `ytdCollectionAll: decimal` (sum GlobalDonation.NetAmount this year, across active branches)
  - `totalTarget: decimal` (sum of AnnualTarget across active branches)
  - `targetAchievedPct: decimal` (ytdCollectionAll / totalTarget × 100; null if totalTarget == 0)
  - `topBranchName: string?` (branch with highest `(ytdCollected / annualTarget)` ratio among active)
  - `topBranchPct: decimal?` (that branch's performancePct)
- Handler file: `Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranchSummary.cs` (NEW)
- Endpoint: add field to `Base.API/EndPoints/Application/Queries/BranchQueries.cs`

### Grid Aggregation Columns

**Aggregation Columns**:
| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Staff | Count of Staff rows with `BranchId = row.BranchId` | `app.Staffs` | LINQ subquery in `GetBranches` handler — **requires Staff.BranchId FK** (see ISSUE-1 in §⑫) |
| YTD Collected | Sum of `GlobalDonation.NetAmount` where `BranchId = row.BranchId` AND `DonationDate` is in current year | `dom.GlobalDonations` | LINQ subquery or grouped sum — navigation `branch.GlobalDonations` already exists |
| Performance % | `(ytdCollected / annualTarget) × 100` when AnnualTarget > 0 else null | Computed | Post-projection in the handler after the two above |

### Side Panel (Branch Detail)

**Side Panel**: Opens when a row is clicked (click on the bold branch name OR the "View" action button). Closes with overlay click, X button, or Escape key. Use the same pattern as ContactType #19's `ContactTypeSidePanel`.

| Panel Section | Fields / Content | Source |
|--------------|------------------|--------|
| Header | BranchName, BranchCode badge, Active/Inactive badge, Edit button, Close button | Row data |
| **Quick Stats** (6 stat tiles in 2×3 grid) | Staff count, Contacts (assigned), Active Campaigns, Events (upcoming), YTD Donations (currency), Target Achievement (percent + mini bar) | Row data + `GetBranchById` (enriched detail) |
| **Recent Activity** (feed — last 4-5 items) | Date column + activity text (e.g., "Donation $500 from Sarah J.") + "View All" link | **SERVICE_PLACEHOLDER — no activity-stream service exists**. FE renders the card with "No recent activity" empty state or 4 stub rows; "View All" link triggers toast. |
| **Staff (mini list)** (3 top staff + "View All" link) | Avatar (initials), StaffName, Role/Title | `GetAllStaffList?branchId={id}&pageSize=3` — **requires Staff.BranchId FK** (ISSUE-1). If FK missing → empty state + "View All Staff" link that navigates to staff grid |

**Panel Behavior**:
- Width: `w-96` (384px) on desktop, `w-full` on mobile (sm:)
- Smooth slide-in animation (same token as ContactType)
- Sticky header within panel, body scrolls
- "View All Activity" → toast (SERVICE_PLACEHOLDER)
- "View All Staff" → `/{lang}/organization/staff/staff?branchId={id}`

### Map View (SERVICE_PLACEHOLDER)

The mockup shows a View Toggle (List / Map) and a Map View pane with world-map pins.

**Scope for this ALIGN session**: Build the view-toggle button pair. On clicking "Map View":
- Hide the data-table + side-panel row
- Show a placeholder card with a "Map integration coming soon" empty state (Phosphor `ph:map-pin` icon + text)
- Display a legend (green/amber/red dots) and the legend text from the mockup
- Show a simple non-interactive list of branches grouped by country (fallback)
- Button to switch back to List View

**Why placeholder**: Leaflet / Google Maps / Mapbox are not wired into the frontend dependency graph — picking a map lib and adding geo-coordinates to Branch are both out of scope for a single ALIGN session. Flag as ISSUE-3.

### User Interaction Flow

1. User opens `/organization/company/branch` → ScreenHeader + 4 widgets load (summary query fires) + grid loads (paginated query with aggregations) → view-toggle defaults to "List".
2. User clicks "+Add Branch" → RJSF modal opens with empty form → selects Country → State/City dropdowns cascade → saves → grid refreshes + summary refreshes.
3. User clicks a row's **bold Branch name** → side panel slides in from right → shows Quick Stats + Activity + Staff mini-list.
4. User clicks **Edit** (row action or panel header) → RJSF modal opens pre-filled → saves → grid refreshes.
5. User clicks **3-dot → View Staff** → navigates to `/organization/staff/staff?branchId={id}` (pre-filtered).
6. User clicks **3-dot → View Donations** → navigates to `/crm/donation/globaldonation?branchId={id}` (pre-filtered).
7. User clicks **Toggle** (status icon or 3-dot → Deactivate) → confirm dialog → API → badge updates.
8. User clicks **Delete** → confirm → soft-delete → row disappears → summary refreshes.
9. User clicks **Map View** toggle → placeholder card shown (SERVICE_PLACEHOLDER).
10. User clicks **Export** → triggers existing `ExportBranch` CSV (already implemented — verify still works after schema change).

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Canonical MASTER_GRID reference: **ContactType** (Registry #19) — the side-panel + widget pattern (Variant B) is the template.

| Canonical (ContactType) | → This Entity (Branch) | Context |
|-------------------------|------------------------|---------|
| ContactType | Branch | Entity/class name |
| contactType | branch | Variable/field names |
| ContactTypeId | BranchId | PK field |
| ContactTypes | Branches | Table name, DbSet, collection names |
| contact-type | branch | Kebab — (same word; use `branch` folder) |
| contacttype | branch | FE folder (lowercase, no-dash) |
| CONTACTTYPE | BRANCH | Grid code, menu code |
| corg | app | DB schema (wait — **app** is the runtime table schema; EF config may override) |
| Corg | Application | Backend group name — **NOT `App`** (verify in `ApplicationMappings.cs`) |
| CorgModels | ApplicationModels | Namespace suffix — Branch is in `Base.Domain.Models.ApplicationModels` |
| CorgBusiness | ApplicationBusiness | Business folder: `Base.Application/Business/ApplicationBusiness/Branches/` |
| CorgSchemas | ApplicationSchemas | Schemas folder |
| CorgConfigurations | ApplicationConfigurations | EF Configurations folder |
| Application (endpoint folder) | Application | Endpoint folder already `Base.API/EndPoints/Application/` |
| corg-service | application-service | FE folder under `src/domain/entities/` and `src/infrastructure/gql-*` |
| CONTACT | COMPANY | Parent menu code → `ORG_COMPANY` (MenuId 362) |
| CRM | ORGANIZATION | Module code |
| crm/contact/contacttype | organization/company/branch | FE route path (matches MenuUrl from `Module_Menu_List.sql`) |
| IContactDbContext | **IContactDbContext** | ⚠ Branch's DbSet currently lives in `IContactDbContext`, NOT `IApplicationDbContext` — preserve during ALIGN |

> ⚠ **Naming quirk — read carefully**: Branch lives in the **`ApplicationModels`** namespace group but its DbSet is declared on `IContactDbContext` (historical — Branch was originally conceived as a contact-assignment dimension). Do NOT move it to `IApplicationDbContext` during ALIGN — that would break existing queries. The substitution `Corg → Application` applies to folder/namespace paths only.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> ALIGN scope — files are MODIFIED not created from scratch, except the 2 new Summary files.

### Backend Files (existing — MODIFY)

| # | File | Path | Change Kind |
|---|------|------|-------------|
| 1 | Entity | `Pss2.0_Backend/.../Base.Domain/Models/ApplicationModels/Branch.cs` | ADD: CountryId, StateId, CityId, Region, ManagerStaffId, AnnualTarget fields + navs |
| 2 | EF Config | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/BranchConfiguration.cs` | ADD: HasOne for each new FK + index on (CompanyId, BranchCode), (CompanyId, BranchName) |
| 3 | Schemas (DTOs) | `Pss2.0_Backend/.../Base.Application/Schemas/ApplicationSchemas/BranchSchemas.cs` | ADD: new fields to Request/Response DTOs + new `BranchSummaryDto` + projection fields (staffCount, ytdCollected, performancePct) on ResponseDto |
| 4 | Create Command | `Pss2.0_Backend/.../Base.Application/Business/ApplicationBusiness/Branches/Commands/CreateBranch.cs` | ADD: new FK validations + map new fields + unique(BranchName) |
| 5 | Update Command | `Pss2.0_Backend/.../Base.Application/Business/ApplicationBusiness/Branches/Commands/UpdateBranch.cs` | ADD: same as CreateBranch |
| 6 | Delete Command | `Pss2.0_Backend/.../Base.Application/Business/ApplicationBusiness/Branches/Commands/DeleteBranch.cs` | No functional change — verify still works |
| 7 | Toggle Command | `Pss2.0_Backend/.../Base.Application/Business/ApplicationBusiness/Branches/Commands/ToggleBranch.cs` | No change |
| 8 | GetAll Query | `Pss2.0_Backend/.../Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranch.cs` | ADD: Includes for Country/State/City/ManagerStaff + aggregation subqueries (StaffCount, YtdCollected, PerformancePct) + filter args (regionFilter, countryId, statusFilter) |
| 9 | GetById Query | `Pss2.0_Backend/.../Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranchById.cs` | ADD: enriched detail for side panel (contactsCount, activeCampaigns, eventsUpcoming) — flag placeholders with constant 0 where source entities lack BranchId FK |
| 10 | Export Query | `Pss2.0_Backend/.../Base.Application/Business/ApplicationBusiness/Branches/Queries/ExportBranch.cs` | ADD: new columns to ExportBranchDto + CSV projection |
| 11 | Mutations | `Pss2.0_Backend/.../Base.API/EndPoints/Application/Mutations/BranchMutations.cs` | No change (CRUD signatures unchanged) |
| 12 | Queries | `Pss2.0_Backend/.../Base.API/EndPoints/Application/Queries/BranchQueries.cs` | ADD: `GetBranchSummary` field |

### Backend Files (NEW)

| # | File | Path |
|---|------|------|
| 13 | Summary Query | `Pss2.0_Backend/.../Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranchSummary.cs` |
| 14 | Migration (optional — generated by EF) | `Pss2.0_Backend/.../Base.Infrastructure/Data/Migrations/{timestamp}_AddBranchLocationAndTarget.cs` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IContactDbContext.cs` | No change — `DbSet<Branch> Branches` already present |
| 2 | `ContactDbContext.cs` | No change |
| 3 | `ApplicationMappings.cs` (group's Mapster config) | ADD mappings for new fields on Branch + BranchSummaryDto |
| 4 | `BranchConfiguration.cs` (already listed above) | FK relationships + indexes |

### Frontend Files (MODIFY)

| # | File | Path | Change Kind |
|---|------|------|-------------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/application-service/BranchDto.ts` | ADD: new fields to Request/Response + new `BranchSummaryDto` interface |
| 2 | GQL Query | `Pss2.0_Frontend/src/infrastructure/gql-queries/application-queries/BranchQuery.ts` | ADD: new fields (countryId + country.countryName, state/city/manager navs, staffCount, ytdCollected, performancePct, annualTarget, region) + new `GET_BRANCH_SUMMARY_QUERY` |
| 3 | GQL Mutation | `Pss2.0_Frontend/src/infrastructure/gql-mutations/application-mutations/BranchMutation.ts` | ADD: new fields in Create/Update mutation variables shape |
| 4 | Page Config | `Pss2.0_Frontend/src/presentation/pages/organization/company/branch.tsx` | REPLACE with Variant B layout: ScreenHeader + widgets + [DataTableContainer | side-panel] flex row, wrapped in `AdvancedDataTableStoreProvider` |
| 5 | DataTable | `Pss2.0_Frontend/src/presentation/components/page-components/organization/company/branch/data-table.tsx` | REWRITE to use `DataTableContainer` with `showHeader={false}`, pass `onRowSelect` to feed the side-panel store, add custom column renderers + client-side performance-bucket filter |
| 6 | Entity Operations | `Pss2.0_Frontend/src/application/configs/data-table-configs/application-service-entity-operations.ts` | UPDATE BRANCH entry to include new custom renderer references + ensure gridCode "BRANCH" stays intact |
| 7 | Sidebar entry | (Menu is server-driven via `useAccessCapability` — no static JSON) | No file change needed; DB Seed maintains the menu record |

### Frontend Files (NEW)

| # | File | Path |
|---|------|------|
| 8 | Widgets component | `Pss2.0_Frontend/src/presentation/components/page-components/organization/company/branch/branch-widgets.tsx` |
| 9 | Side panel component | `Pss2.0_Frontend/src/presentation/components/page-components/organization/company/branch/branch-side-panel.tsx` |
| 10 | Page layout wrapper | `Pss2.0_Frontend/src/presentation/components/page-components/organization/company/branch/branch-page-layout.tsx` |
| 11 | Map-view placeholder | `Pss2.0_Frontend/src/presentation/components/page-components/organization/company/branch/branch-map-placeholder.tsx` |
| 12 | Performance-bar renderer | `Pss2.0_Frontend/src/presentation/components/data-table/renderers/performance-bar.tsx` (or reuse existing progress-bar renderer if present — check first) |
| 13 | Country-flag renderer | `Pss2.0_Frontend/src/presentation/components/data-table/renderers/country-flag.tsx` (small — emoji flag + country name) |

### Frontend Cleanup (DELETE)

| # | File | Path | Reason |
|---|------|------|--------|
| 1 | Duplicate route | `Pss2.0_Frontend/src/app/[lang]/organizationsetup/branch/page.tsx` (and its parent folder if empty) | Obsolete duplicate — confirm with ContactType-style delete-unused-route precedent. Keep `organization/company/branch` per MODULE_MENU_REFERENCE MenuUrl |

### DB Seed Updates

- `GridFormSchema` for MenuCode `BRANCH`: regenerate with new fields (Country/State/City cascading, ManagerStaffId, Region, AnnualTarget).
- Add sample seed rows with Region values to test dropdown ("South Asia", "MEA", "North America", "Europe").
- Verify menu record exists under `ORG_COMPANY` with MenuCode `BRANCH`, MenuUrl `organization/company/branch`, OrderBy 2.

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — review and confirm.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Branches
MenuCode: BRANCH
ParentMenu: ORG_COMPANY
Module: ORGANIZATION
MenuUrl: organization/company/branch
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: BRANCH
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer.

**GraphQL Types:**
- Query type: `BranchQueries`
- Mutation type: `BranchMutations`

**Queries:**
| GQL Field | Returns | Key Args | Notes |
|-----------|---------|----------|-------|
| GetBranches (existing) | PaginatedResponse of BranchResponseDto | searchText, pageNo, pageSize, sortField, sortDir, isActive, companyId?, countryId?, region? | Extend args for filter bar |
| GetBranchById (existing) | BranchResponseDto (enriched) | branchId | ADD contactsCount, activeCampaigns, eventsUpcoming (placeholder 0 where source lacks BranchId) |
| **GetBranchSummary** (NEW) | BranchSummaryDto | (companyId from context) | Drives 4 KPI cards |
| ExportBranch (existing) | ExportBranchDto[] | searchText, filters | No change needed besides extended DTO |

**Mutations** (existing — signatures unchanged):
| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateBranch | BranchRequestDto | int (new ID) |
| UpdateBranch | BranchRequestDto | int |
| DeleteBranch | branchId | int |
| ToggleBranch (ActivateDeactivate) | branchId | int |

**BranchResponseDto Fields** (what FE receives after ALIGN):
| Field | Type | Notes |
|-------|------|-------|
| branchId | number | PK |
| branchCode | string | e.g., "BR-MUM" |
| branchName | string | — |
| companyId | number | FK |
| company.companyName | string | FK display |
| countryId | number \| null | NEW FK |
| country.countryName | string \| null | NEW FK display |
| country.countryCode | string \| null | NEW — for flag emoji mapping |
| stateId | number \| null | NEW FK |
| state.stateName | string \| null | NEW FK display |
| cityId | number \| null | NEW FK |
| city.cityName | string \| null | NEW FK display |
| region | string \| null | NEW — free text |
| managerStaffId | number \| null | NEW FK |
| managerStaff.staffName | string \| null | NEW FK display |
| annualTarget | number \| null | NEW — decimal |
| address | string \| null | existing |
| isActive | boolean | inherited |
| **staffCount** | number | NEW — aggregation |
| **ytdCollected** | number | NEW — aggregation |
| **performancePct** | number \| null | NEW — computed; null when annualTarget missing |

**BranchSummaryDto Fields**:
| Field | Type | Notes |
|-------|------|-------|
| totalBranches | number | — |
| activeCount | number | — |
| inactiveCount | number | — |
| totalStaff | number | — |
| avgPerBranch | number | — |
| ytdCollectionAll | number | — |
| totalTarget | number | — |
| targetAchievedPct | number \| null | — |
| topBranchName | string \| null | — |
| topBranchPct | number \| null | — |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors after adding new fields + migration
- [ ] EF Core migration successfully applies (new columns on `app.Branches`; FK indexes created)
- [ ] `pnpm dev` — page loads at `/{lang}/organization/company/branch`
- [ ] Route `/{lang}/organizationsetup/branch` returns 404 (duplicate removed)

**Functional Verification (Full E2E — MANDATORY):**

> Run 1 (2026-05-21) BLOCKED — all 15 functional specs failed at `beforeEach → waitForGridReady()`. Page hangs at `<main>Loading…</main>` before the grid mounts. Root cause is FE-only and affects every item below uniformly; not annotating each line individually. See [branch.test-result.md](branch.test-result.md) Run 1 for diagnosis + verification steps.

- [ ] Grid loads with 12 columns in correct order (Branch, Code, Region, Country, City, Head, Staff, Annual Target, YTD Collected, Performance, Status, Actions)
- [ ] Country column renders emoji flag + country name
- [~] Performance column renders traffic-light bar with correct color (green ≥75, amber 50-75, red <50)  *(SKIPPED in Run 1 — depends on YtdCollected, blocked by ISSUE-4-YTD OPEN §⑬)*
- [~] Staff count, YTD Collected, Performance % show correct per-row values  *(SKIPPED in Run 1 — YtdCollected blocked by ISSUE-4-YTD OPEN §⑬)*
- [ ] Search filters by branch name / code / city
- [ ] Region / Country / Status / Performance filters narrow results
- [ ] Add new branch → modal form shows all fields with cascading Country→State→City → save succeeds → appears in grid + widgets update
- [ ] Edit branch → modal pre-fills → save succeeds → row updates
- [ ] Toggle → badge changes → widgets update (Active/Inactive counts)
- [ ] Delete → soft-delete → row disappears → widgets update
- [ ] FK dropdowns load data correctly (Company, Country, State cascades, City cascades, ManagerStaff)
- [ ] Summary widgets (4) show correct values matching grid data
- [ ] Click on branch name → side panel opens → Quick Stats render → Activity feed shows placeholder empty or 4 stub items (toast on "View All") → Staff mini-list shows top 3 or empty state  *(side-panel Activity feed + CRM Quick-Stat tiles SKIPPED in Run 1 — ISSUE-2 / ISSUE-4 OPEN §⑬)*
- [ ] Side panel close works (X, overlay click, Escape)
- [ ] Edit from side panel header opens modal
- [ ] "View Staff" dropdown action navigates to `/{lang}/organization/staff/staff?branchId={id}`
- [ ] "View Donations" dropdown action navigates to `/{lang}/crm/donation/globaldonation?branchId={id}`
- [~] Map View toggle → shows SERVICE_PLACEHOLDER card with legend + branches-by-country list  *(SKIPPED in Run 1 — SERVICE_PLACEHOLDER §⑫ + ISSUE-3 OPEN §⑬)*
- [ ] Export button triggers existing ExportBranch flow with new columns in CSV
- [ ] Permissions: buttons/actions respect BUSINESSADMIN capabilities; other roles (if any) see READ-only

**DB Seed Verification:**
- [ ] Menu "Branches" visible in sidebar under Organization → Company (OrderBy 2, after Company)
- [ ] Grid columns + cells render correctly from `GridCode: BRANCH`
- [ ] GridFormSchema drives modal form with 2 sections, correct cascading widgets
- [ ] Seed sample branches have Region values + AnnualTarget values to demo the screen

**Responsiveness:**
- [ ] xs (mobile): widgets collapse to 1-col, side panel becomes full-width slide-over
- [ ] md/lg: widgets 2-col then 4-col; side panel `w-96`
- [ ] Full-screen toggle in ScreenHeader works (hides sidebar/topbar)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things easy to get wrong.

- **Layout Variant is `widgets-above-grid+side-panel`** → FE MUST use Variant B (ScreenHeader at page root + widgets row + flex [DataTable | SidePanel], wrapped in `AdvancedDataTableStoreProvider`). Do NOT use the in-table header. Follow ContactType #19 Session 2 precedent. Any deviation will produce the duplicate-header bug.
- **Branch DbSet lives in IContactDbContext, NOT IApplicationDbContext** — preserve this during ALIGN. The namespace/folder substitution `Corg → Application` applies to models/schemas/business/endpoint paths only.
- **ApplicationModels ≠ AppModels** — the Branch entity is under `Base.Domain.Models.ApplicationModels` (full word). Do not abbreviate.
- **ALIGN scope** — only modify listed files. Do NOT regenerate from scratch. Do NOT rename existing GQL fields (`GetBranches` stays — don't rename to `GetAllBranchList` even though newer screens use that convention; it would break existing callers).
- **Duplicate route cleanup** — a stale `/app/[lang]/organizationsetup/branch/page.tsx` exists and renders the same config; delete it (or confirm with user) so only `/organization/company/branch` remains.
- **Country flag rendering** — use Unicode regional-indicator emojis derived from `country.countryCode` (e.g., "IN" → 🇮🇳). Build a small helper, not an image lookup.
- **Region field storage** — store as plain string for now. If a dedicated `Region` entity emerges later, migrate with a backfill.
- **Cascading location dropdowns** — State depends on Country; City depends on State. RJSF / ApiSelectV2 must react to upstream field change and clear downstream selections.

**Service Dependencies** (UI-only — no backend service wired):

- ⚠ **SERVICE_PLACEHOLDER — Map View**: Full button-toggle UI built, map pane shows placeholder card + legend + grouped-by-country list. No map library (Leaflet / Google Maps / Mapbox) is currently installed. Picking a map lib + adding geo-coordinates to Branch are out of scope. `ISSUE-3`.
- ⚠ **SERVICE_PLACEHOLDER — Recent Activity feed (side panel)**: Full card UI built, renders empty state or 4 stub items. No activity-stream service exists (there is no `ActivityLog` table scoped to Branch). "View All Activity" link triggers toast. `ISSUE-2`.
- ⚠ **SERVICE_PLACEHOLDER — Staff mini-list (side panel)** and **Staff Count (grid column)**: Full UI built. Backend aggregation is a LINQ subquery `Staffs.Count(s => s.BranchId == branchId)` — **requires `Staff.BranchId` FK which does not currently exist**. The BE agent must either (a) add the FK on Staff as part of this ALIGN (preferred) or (b) return constant 0 and flag ISSUE-1 as OPEN. `ISSUE-1`.
- ⚠ **Side-panel Quick Stats — Contacts/Campaigns/Events scoping**: The 6 tile grid in the panel includes "Contacts (assigned)", "Active Campaigns", "Events (upcoming)". None of Contact/Campaign/Event currently carry a `BranchId` FK. Return constant 0 and flag as ISSUE-4 — full implementation requires data-model changes across CRM entities (out of scope for this ALIGN).

Full UI must be built (summary cards, side panel, activity feed shell, staff mini-list shell, map-view toggle + placeholder card). Only the data-source handlers for the listed service placeholders return stubs or zeros.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning | Medium | BE aggregation | `Staff.BranchId` FK does not exist. Required for per-row StaffCount column AND side-panel Staff mini-list. Fix options: (a) add FK during build (preferred), (b) return 0. | RESOLVED — FK added to Staff entity + StaffConfiguration + migration |
| ISSUE-2 | planning | Low | UX placeholder | Side-panel Recent Activity feed has no source service. Render empty-state or stub rows; "View All" toast. | OPEN |
| ISSUE-3 | planning | Low | UX placeholder | Map View needs a map library (Leaflet/Google/Mapbox) + geo-coords on Branch. Render placeholder card + legend + grouped list. | OPEN |
| ISSUE-4 | planning | Low | BE aggregation | Side-panel Quick Stats for Contacts/Campaigns/Events need BranchId FKs on CRM entities. Return 0 with TODO comment. | OPEN |
| ISSUE-4-YTD | session 1 | Low | BE aggregation | `GlobalDonation.BranchId` FK does not exist, so per-row YtdCollected aggregation returns 0. Requires CRM schema change to wire. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-18 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt (ALIGN — extend Branch entity + aggregations + Summary + Variant B UI + DB seed).
- **Files touched**:
  - BE: `Base.Domain/Models/ApplicationModels/Branch.cs` (modified — 6 new fields + 5 nav props + Staffs collection), `Base.Domain/Models/ApplicationModels/Staff.cs` (modified — BranchId FK + nav, ISSUE-1 resolution), `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/BranchConfiguration.cs` (modified — 5 HasOne FKs + 2 composite unique indexes + Address nullable), `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/StaffConfiguration.cs` (modified — BranchId HasOne), `Base.Application/Schemas/ApplicationSchemas/BranchSchemas.cs` (modified — DTOs + BranchSummaryDto + ExportBranchDto), `Base.Application/Business/ApplicationBusiness/Branches/Commands/CreateBranch.cs` (modified — FK + unique validation), `Base.Application/Business/ApplicationBusiness/Branches/Commands/UpdateBranch.cs` (modified — FK + update-mode unique validation), `Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranch.cs` (modified — Includes + StaffCount subquery + filter args), `Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranchById.cs` (modified — enriched detail + side-panel placeholders), `Base.Application/Business/ApplicationBusiness/Branches/Queries/ExportBranch.cs` (modified — 8 new columns), `Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranchSummary.cs` (created — 4-KPI query), `Base.Application/Mappings/ApplicationMappings.cs` (modified — Mapster configs), `Base.API/EndPoints/Application/Queries/BranchQueries.cs` (modified — GetBranchSummary endpoint), `Base.Infrastructure/Migrations/20260418111648_AddBranchLocationAndTarget.cs` (created — EF migration)
  - FE: `src/domain/entities/application-service/BranchDto.ts` (modified — new fields + FK nav DTOs + BranchSummaryDto), `src/infrastructure/gql-queries/application-queries/BranchQuery.ts` (modified — extended BRANCHES_QUERY + BRANCH_BY_ID_QUERY + new BRANCH_SUMMARY_QUERY), `src/infrastructure/gql-mutations/application-mutations/BranchMutation.ts` (modified — extended Create/Update mutations), `src/presentation/pages/organization/company/branch.tsx` (modified — REPLACED with Variant B layout), `src/presentation/components/page-components/organization/company/branch/data-table.tsx` (modified — AdvancedDataTableContainer showHeader=false + row-select callback), `src/presentation/components/page-components/organization/company/branch/branch-widgets.tsx` (created — 4 KPI cards), `src/presentation/components/page-components/organization/company/branch/branch-side-panel.tsx` (created — Quick Stats + Activity stub + Staff mini-list), `src/presentation/components/page-components/organization/company/branch/branch-map-placeholder.tsx` (created — view-toggle placeholder), `src/presentation/components/page-components/organization/company/branch/index.ts` (modified — barrel exports), `src/presentation/components/custom-components/data-tables/shared-cell-renderers/performance-bar.tsx` (created — traffic-light bar), `src/presentation/components/custom-components/data-tables/shared-cell-renderers/country-flag.tsx` (created — emoji + name), `src/presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (modified — barrel), `src/presentation/components/custom-components/data-tables/advanced/data-table-column-types/component-column.tsx` (modified — registered performance-bar + country-flag), `src/presentation/components/custom-components/data-tables/basic/data-table-column-types/component-column.tsx` (modified — registered performance-bar + country-flag), `src/presentation/components/custom-components/data-tables/flow/data-table-column-types/component-column.tsx` (modified — registered performance-bar + country-flag), `src/app/[lang]/organization/organizationsetup/branch/page.tsx` (deleted — duplicate route)
  - DB: `Services/Base/sql-scripts-dyanmic/Branch-sqlscripts.sql` (created — menu + capabilities + grid + 12 GridFields + GridFormSchema RJSF cascading + 4 sample rows)
- **Deviations from spec**: Country/State/City entity path in prompt §③ listed `Base.Domain/Models/RegionModels/` but actual path is `Base.Domain/Models/SharedModels/` — BE used the correct path. `managerStaffId` form widget uses ApiSelectV3 (not V2) to match existing Staff-selection convention. No other deviations.
- **Known issues opened**: ISSUE-4-YTD (GlobalDonation.BranchId missing → YtdCollected=0). ISSUE-2 / ISSUE-3 / ISSUE-4 remain OPEN from planning as intentional SERVICE_PLACEHOLDERS.
- **Known issues closed**: ISSUE-1 (Staff.BranchId FK added during this build — chose the preferred option).
- **Next step**: None for this build. Outside-screen follow-ups: (1) add `BranchId` FK on `GlobalDonation` to close ISSUE-4-YTD; (2) add `BranchId` FK on Contact/Campaign/Event to close ISSUE-4; (3) wire an activity-stream service to close ISSUE-2; (4) pick a map library + add geo-coords to close ISSUE-3.

**Build status**: BE `dotnet build` — GREEN (all 4 projects, 0 errors). FE `tsc --noEmit` — GREEN for Branch files (5 pre-existing errors inherited from screens #22 + dashboards/overview, unrelated).

- Session 2 — 2026-05-21 — TEST — NEEDS_FIX — see [branch.test-result.md](branch.test-result.md) — 15 failures (single root cause: `<main>Loading…</main>` hang), 5 intentional skips
- Session 3 — 2026-05-22 — TEST — INFRA_ERROR — see [branch.test-result.md](branch.test-result.md) — 15 fast-fails (auth setup never ran under `--grep @screen-41`; storageState missing → `page.goto` invalid-URL). Screen status unchanged at NEEDS_FIX; Run 1 page-hang not re-verified.
- Session 4 — 2026-05-22 — TEST — NEEDS_FIX — see [branch.test-result.md](branch.test-result.md) — Run 3 vs IIS (FE :8080, BE :7001); auth setup PASSED; 15 chromium failures REPRODUCED Run 1 `<main>Loading…</main>` page-hang; 5 intentional skips. Root cause IDENTIFIED: spec missing module-warmup step before `page.goto(menuUrl)`.
- Session 5 — 2026-05-22 — REGENERATE — see [branch.test-result.md](branch.test-result.md) — `/test-screen #41 --generate-only`; spec `beforeEach` patched to use `navigateToScreen(page, "ORGANIZATION", "organization/company/branch")` per updated `/test-screen` skill § Navigation constraint. Not executed — re-run with `/test-screen #41 --rerun` to verify.
- Session 6 — 2026-05-22 — TEST — NEEDS_FIX — see [branch.test-result.md](branch.test-result.md) — Run 4 (after navigateToScreen patch) vs IIS; 1 pass (setup), 15 chromium fail at `waitForGridReady`, 5 intentional skips, 4m 24s. Page snapshot shows sidebar `<list>` STILL EMPTY after `/en/organization/dashboards/overview` warm-up → `<main>Loading…</main>` REPRODUCED. The skill's Navigation constraint assumption is incomplete; menu hydration does not fire on hard `page.goto`. Also caught a `/test-screen` meta-bug: invocations from `PSS_2.0_Frontend/` CWD silently load an empty default config (must pass `--config tests/e2e/playwright.config.ts`). Runs 4a/4b were INFRA_ERROR before Run 4c reached this real result.
- Session 7 — 2026-05-22 — TEST — NEEDS_FIX — see [branch.test-result.md](branch.test-result.md) — Run 5 (nav-helpers Option 2 patch — wait for `nav a[href*="/organization/"]` instead of networkidle); 1 pass (setup), 15 chromium fail at `waitForModuleReady`, 5 skips, 5m 0s. Screenshot now reveals the REAL gap: the Organization dashboard PAGE rendered fine, but the sidebar is **completely empty** (no menu items at all). Two candidates: (a) `businessadmin@gmail.com`/`humanity` has no menu permissions in IIS, or (b) menu fetch only fires on post-login redirect, not on storageState-restored sessions. Blocking on user input before patching further.
- Session 8 — 2026-05-22 — TEST — NEEDS_FIX (but first real screen pass) — see [branch.test-result.md](branch.test-result.md) — Runs 6+7. User confirmed menus DO appear manually → diagnosed via FE-code Explore: `useMenu()` skips its query if `useGlobalStore.moduleCode === ""`; cookies-only storageState restore never sets it because the user normally clicks a module in the navigator. Patched `nav-helpers.ts` to (a) seed `localStorage["global-store"]` with `{state:{moduleCode}, version:0}` via `page.addInitScript`, (b) drop the `nav` ancestor from the menu-link selector (sidebar is `<div><ul><li><a>`). Run 7 result: **2 passed** (setup + `grid loads with toolbar`) / 14 failed / 5 skipped / 7m 36s. The 14 failures are now REAL screen-level: 8× grid timeout in beforeEach (10s too tight for IIS build), 3× form-modal/FK-selector mismatches, 2× missing `branch-widgets`/`side-panel` testids, 1× 12-column assertion. Recommended next: bump `waitForGridReady` to 20s (clears 8 of 14 in one shot), then `/test-fix #41 --until-green`.

### Session 9 — 2026-05-22 — UI — COMPLETED

- **Scope**: Remove hardcoded `$` currency symbol, `en-US` locale, and stub-data date strings from Branch components. Make currency/number formatting tenant-aware via the existing `companySettingsFormatters` utility (CompanySettings session store #75).
- **Files touched**:
  - BE: None
  - FE: `src/presentation/utils/companySettingsFormatters.ts` (modified — added `formatCompactCurrency` export with K/M for non-Indian orgs and L/Cr for Indian-grouping orgs; reuses base `formatCurrency` for symbol/code/grouping); `src/presentation/components/page-components/organization/company/branch/branch-widgets.tsx` (modified — deleted local `formatCurrency` with hardcoded `$` + `en-US`; replaced all 4 KpiCard call sites to use `formatCompactCurrency` for monetary values and `formatNumber` for counts + percentages); `src/presentation/components/page-components/organization/company/branch/branch-side-panel.tsx` (modified — deleted local `formatCurrency`; deleted `STUB_ACTIVITIES` array with hardcoded "Apr 15"/"Apr 12"/"Apr 10"/"Apr 8" dates + `$1,200` literal; replaced 4-item stub render with proper `Activity feed coming soon` dashed-border empty-state tile; swapped 6 Quick Stats tiles + Target Achievement % to `formatNumber` / `displayCompactCurrency`).
  - DB: None
- **Deviations from spec**: None. The §⑥ UI Blueprint already specified Variant B + KPI cards + side panel; only the implementation primitives changed. ISSUE-2 (no activity service) now renders an honest empty-state instead of fake April dates — semantically closer to the OPEN status.
- **Known issues opened**: None.
- **Known issues closed**: None. ISSUE-2 stays OPEN (still no activity-stream source — the stub data went away but the underlying capability gap remains).
- **Next step**: Test failures from Session 8/Run 7 (8× grid timeout, 3× FK-selector mismatch, 2× missing testid, 1× column count) are still pending. Run `/test-fix #41 --until-green` when ready.

### Session 10 — 2026-05-22 — FIX — COMPLETED

- **Scope**: Three form-input fixes surfaced from manual QA of the Branch Add/Edit modal — (1) numeric fields (`annualTarget`) accepted alphabetic input in Firefox + on paste; (2) `managerStaffId` ApiSelectV3 fired no API call because the `STAFF` queryKey was missing from the static query map (fell through to `EMPTY_QUERY`); (3) introduce a generic `ui:options: { autoCaps: true }` flag on free-text inputs (so `branchCode` displays + persists as uppercase as the user types).
- **Files touched**:
  - BE: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Branch-sqlscripts.sql` (modified — added `"ui:options": { "autoCaps": true }` to the `branchCode` uiSchema block inside the BRANCH `GridFormSchema` UPDATE statement; re-run the seed against the dev DB to take effect).
  - FE: `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/data-table-form/dgf-widgets/api-selectv3-widget/use-api-selectv3.ts` (modified — added new `STAFF` gql query aliasing `value: staffId, label: staffName` against `staffs(...)`; registered in `queries` map alongside existing `STAFFWITHUSERID`); `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/data-table-form/dgf-templates/base-input-template.tsx` (modified — added schema-type-driven numeric input hardening: `_onKeyDown` blocks alphabetic keystrokes for `integer`/`number` schemas, `_onChange` sanitizes paste/programmatic input to digits + single sign + single decimal; added generic `autoCaps` ui:option that uppercases value on change/blur and applies `uppercase placeholder:normal-case` Tailwind classes to the `<Input>` for visual parity).
  - DB: None (the seed-SQL edit is the DB delivery vehicle; user re-runs `Branch-sqlscripts.sql` to apply).
- **Deviations from spec**: None. The Spec did not pin a specific input-validation strategy for numeric fields; the new behavior is purely defensive (no rejected valid inputs). `autoCaps` is a new generic primitive available to any GridField uiSchema — opt-in only, no implicit behavior change for fields that don't set the flag.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User must re-run `Branch-sqlscripts.sql` against the dev DB for the `branchCode` autoCaps flag to take effect (the FE feature works the moment the JSON property exists in `GridFormSchema`). Optionally roll `autoCaps: true` to other code/key fields (e.g. tax codes, currency codes) by editing their respective seed SQLs.

### Session 11 — 2026-05-22 — FIX — COMPLETED

- **Scope**: NRE in `branches(...)` list query after a Branch record gets its `managerStaffId` assigned. Stack trace pointed at `EntityExtensions.ToDtoList<Branch, BranchResponseDto>` → Mapster crash inside the inner `Staff → StaffResponseDto` adapter. Root cause: `Staff.StaffCategory` is declared non-nullable in both the entity (`= default!`) and the destination DTO (`StaffCategoryRequestDto StaffCategory { get; set; } = default!`). `GetBranchHandler` does `.Include(x => x.ManagerStaff)` but no `.ThenInclude(s => s.StaffCategory)`, so at runtime the manager Staff's `StaffCategory` nav is null. Mapster's convention mapping into a non-nullable destination property omits the source-null guard and dereferences null. Before the manager assignment, ManagerStaff itself was null and the outer null-safe BranchResponseDto map (`src.ManagerStaff != null ? src.ManagerStaff.Adapt<...>() : null`) short-circuited, hiding the latent bug.
- **Files touched**:
  - BE: `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Mappings/ApplicationMappings.cs` (modified — Staff→StaffResponseDto config: added 3 explicit null-safe `.Map(...)` lines for the nested DTO refs `StaffCategory` (non-nullable dest, uses `null!` forgiving assignment), `User` (nullable dest), `Company` (nullable dest); short comment documents why the override is necessary).
  - FE: None.
  - DB: None.
- **Deviations from spec**: None. The fix is purely defensive — non-null cases keep producing the same projected DTOs; only the null-source path now safely emits null instead of NRE-ing.
- **Known issues opened**: None.
- **Known issues closed**: None directly. (This was a new runtime crash surfaced post-Session-10 manual QA, not a pre-existing ISSUE row.)
- **Next step**: After `dotnet build` succeeds, re-test the Branch list query with an assigned manager to confirm the NRE is gone. Other consumers of Staff→StaffResponseDto that intentionally read `dto.StaffCategory.*` should already be including StaffCategory, but if any silently relied on the convention NRE to surface a missing include, they'll now see a null-ref at the read site instead — easier to diagnose.

### Session 12 — 2026-05-22 — FIX — COMPLETED

- **Scope**: User re-ran the Branch list after Session 11 and **still** hit `System.NullReferenceException` from `EntityExtensions.ToDtoList → ApplyGridFeatures → GetBranchHandler.Handle`. Two-layer fix: (a) wrapped the handler body in `try/catch` and rethrew as `ApplicationException` carrying the **root inner exception type + message + originating frame** so the next crash surfaces in the GraphQL error payload instead of being swallowed by Mapster's wrapper frames; (b) added `.ThenInclude(s => s!.StaffCategory)`, `.ThenInclude(s => s!.User)`, `.ThenInclude(s => s!.Company)` to the EF query so the three non-nullable Staff navs are eagerly loaded — belt-and-suspenders alongside the Session 11 Mapster null-guards, in case the user's BE hasn't picked up the mapper config change (cached compiled Mapster expression, stale assembly, etc.).
- **Files touched**:
  - BE: `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranch.cs` (modified — added try/catch around the entire handler body with root-cause-extracting rethrow; added `.ThenInclude` chains for ManagerStaff → StaffCategory / User / Company).
  - FE: None.
  - DB: None.
- **Deviations from spec**: None. Two `.ThenInclude` chains add one extra JOIN each to the list query — acceptable cost (PageSize ≤ 50 typical, manager Staff per branch). If volume grows, the projection could be flattened in the EF query rather than relying on Mapster.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User must `dotnet build` and **restart** the API process so the new IL + the Session-11 Mapster config recompile. If the NRE still surfaces, the new ApplicationException wrapper will report the **exact** inner type + originating member — paste that back here to pinpoint.


### Session 13 — 2026-05-25 — FIX — COMPLETED

- **Scope**: Same `System.NullReferenceException` resurfaced in `GetBranchByIdHandler.Handle` (the detail-drawer / edit-mode loader) for branches with a `ManagerStaffId` assigned. Root cause is identical to Session 12 — Mapster projects `branch.Adapt<BranchResponseDto>()` and walks the manager Staff's non-nullable nested nav targets (`StaffCategory`, `User`, `Company`), which weren't eager-loaded. Applied the same two-layer fix as Session 12.
- **Files touched**:
  - BE: `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ApplicationBusiness/Branches/Queries/GetBranchById.cs` (modified — added `.ThenInclude(s => s!.StaffCategory)`, `.ThenInclude(s => s!.User)`, `.ThenInclude(s => s!.Company)` chains for ManagerStaff; wrapped the entire handler body in `try/catch` with root-cause-extracting `ApplicationException` rethrow naming `GetBranchByIdHandler`).
  - FE: None.
  - DB: None.
- **Deviations from spec**: None. Adds 3 LEFT JOINs to the single-row detail query — negligible cost since it's `FirstOrDefaultAsync` on a PK lookup.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: `dotnet build` + restart the API process. If the NRE still surfaces from this path, the rethrow will report `GetBranchByIdHandler failed: [<TypeName>] <message> @ <Namespace>.<Class>.<Method>` — paste that back to pinpoint any remaining null source. If the user hits the same pattern on a sibling handler (e.g. an `Update*` flow that re-fetches the row before returning), apply the same Include + try/catch pattern — every code path that projects a Staff-with-non-nullable-navs through Mapster needs the eager-loads.


### Session 14 — 2026-05-25 — UI — COMPLETED

- **Scope**: User UI polish — KPI widget icon circles + status badge were using the "light tint bg + colored icon" treatment. Flipped to the inverse "solid color bg + white icon/text" treatment for stronger visual weight, per user direction "icon color set to icon bg color and icon color will be white. same for this screen badge".
- **Files touched**:
  - FE: `PSS_2.0_Frontend/src/presentation/components/page-components/organization/company/branch/branch-widgets.tsx` (removed the `iconColorClass` prop from `KpiCardProps` + all 4 call sites; icon now hard-coded to `text-white`; `bgClass` switched from light `bg-{color}-100 dark:bg-{color}-900/30` to solid `bg-{color}-600 dark:bg-{color}-500` for all 4 cards — blue/purple/green/amber).
  - FE: `PSS_2.0_Frontend/src/presentation/components/page-components/organization/company/branch/branch-side-panel.tsx` (Active/Inactive status badge in header — flipped from `bg-green-100 text-green-700 …` to `bg-green-600 text-white …`; inactive variant now `bg-muted-foreground text-white`; inner status dot is now `bg-white` in both states for consistent contrast against the new solid backgrounds).
  - BE / DB: None.
- **Deviations from spec**: None — UI polish only, no behavioural change. Other inline icons (QuickStatTile, header `Branch Details` icon, location icons, recent-activity placeholder) intentionally **left as muted-foreground text-affordances** — they sit next to labels with no enclosing pill/circle, so the "solid bg + white icon" treatment doesn't apply.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: No build/restart required (FE-only). User can hot-reload `pnpm dev` and the 4 widget tiles + side-panel status pill will pick up the new solid-color treatment.
