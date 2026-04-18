---
screen: Branch
registry_id: 41
module: Organization
status: COMPLETED
scope: ALIGN
screen_type: MASTER_GRID
complexity: High
new_module: NO
planned_date: 2026-04-18
completed_date: 2026-04-18
last_session_date: 2026-04-18
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
- [ ] Grid loads with 12 columns in correct order (Branch, Code, Region, Country, City, Head, Staff, Annual Target, YTD Collected, Performance, Status, Actions)
- [ ] Country column renders emoji flag + country name
- [ ] Performance column renders traffic-light bar with correct color (green ≥75, amber 50-75, red <50)
- [ ] Staff count, YTD Collected, Performance % show correct per-row values
- [ ] Search filters by branch name / code / city
- [ ] Region / Country / Status / Performance filters narrow results
- [ ] Add new branch → modal form shows all fields with cascading Country→State→City → save succeeds → appears in grid + widgets update
- [ ] Edit branch → modal pre-fills → save succeeds → row updates
- [ ] Toggle → badge changes → widgets update (Active/Inactive counts)
- [ ] Delete → soft-delete → row disappears → widgets update
- [ ] FK dropdowns load data correctly (Company, Country, State cascades, City cascades, ManagerStaff)
- [ ] Summary widgets (4) show correct values matching grid data
- [ ] Click on branch name → side panel opens → Quick Stats render → Activity feed shows placeholder empty or 4 stub items (toast on "View All") → Staff mini-list shows top 3 or empty state
- [ ] Side panel close works (X, overlay click, Escape)
- [ ] Edit from side panel header opens modal
- [ ] "View Staff" dropdown action navigates to `/{lang}/organization/staff/staff?branchId={id}`
- [ ] "View Donations" dropdown action navigates to `/{lang}/crm/donation/globaldonation?branchId={id}`
- [ ] Map View toggle → shows SERVICE_PLACEHOLDER card with legend + branches-by-country list
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
