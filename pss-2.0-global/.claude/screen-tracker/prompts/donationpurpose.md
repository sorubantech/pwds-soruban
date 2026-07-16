---
screen: DonationPurpose
registry_id: 2
module: Fundraising
status: COMPLETED
pending_revision: R2_FUND_ALLOCATION
scope: ALIGN
screen_type: MASTER_GRID
complexity: Medium
new_module: NO
planned_date: 2026-04-18
completed_date: 2026-04-18
last_session_date: 2026-07-15
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
- [x] BA Analysis validated (prompt pre-analysis used — no re-analysis)
- [x] Solution Resolution complete
- [x] UX Design finalized
- [x] User Approval received
- [x] Backend alignment changes applied
- [x] Backend wiring verified
- [x] Frontend alignment changes applied
- [x] Frontend wiring verified
- [x] DB Seed script regenerated (GridFormSchema + GridConfig)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes (not run — token optimization; requires manual verification)
- [ ] pnpm dev — page loads at `/[lang]/setting/donationconfig/donationpurpose` (not run — manual verification)
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete) (manual)
- [ ] Grid columns render correctly (including "Target / Raised" progress bar + "Org Unit") (manual)
- [ ] RJSF modal form renders all fields with validation (manual)
- [ ] FK dropdowns load (DonationCategory, DonationGroup independent, OrganizationalUnit)
- [x] ~~Group field auto-fills when Category is selected (readonly)~~ — REMOVED (data model doesn't support; see ISSUE-1)
- [ ] Inactive rows are dimmed but remain visible (manual — `opacity-60` applied via row className)
- [ ] DB Seed — menu visible under CRM → Organization (MODULE_MENU_REFERENCE), grid + form schema render (manual after running seed SQL)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: DonationPurpose
Module: Fundraising (Setup)
Schema: `fund`
Group: Donation (`DonationModels` / `DonationConfigurations` / `DonationSchemas` / `DonationBusiness` / `Donation` endpoints)

Business: DonationPurpose is the **reason a donor gives**. It is the leaf of the three-level fund allocation hierarchy (Group → Category → Purpose) that every donation is posted against. NGO admins and fundraising managers use this screen to configure purposes like "Children's Education Fund", "Medical Aid Fund", or "Clean Water Initiative" — each with a target amount, start/end dates, and an owning organizational unit. During donation entry (screen #1 Global Donation, #5 Bulk Donation, #7 In-Kind Donation, #65 Field Collection), the donor-facing Purpose dropdown is sourced from this table. The per-row "Target / Raised" progress bar is what lets program leads see at a glance how much of each fund's goal has been met.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Entity already exists in `fund` schema — fields below are **current state**. ALIGN = adjust DTOs/GQL/FE only; DO NOT recreate the entity.

Table: `fund."DonationPurposes"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| DonationPurposeId | int | — | PK | — | Primary key |
| DonationPurposeCode | string | 50 | YES | — | Unique per Company (e.g. "EDU-001") |
| DonationPurposeName | string | 200 | YES | — | Display name |
| DonationCategoryId | int | — | YES | fund.DonationCategory | FK |
| DonationGroupId | int | — | YES | fund.DonationGroup | FK (auto-derived from selected Category on FE) |
| OrganizationalUnitId | int? | — | NO | app.OrganizationalUnit | FK (optional — owning department) |
| CompanyId | int? | — | NO | app.Company | FK (set from HttpContext) |
| TargetAmount | decimal(18,2) | — | NO | — | Optional target (0 or null = no target) |
| StartDate | DateTime | — | NO | — | Optional. Existing type is non-null — BE should relax to DateTime? to match mockup ("—" when empty) |
| EndDate | DateTime? | — | NO | — | Optional |
| Description | string | 500 | NO | — | Optional |
| OrderBy | int | — | NO | — | Display order |
| IsActive | bool | — | inherited | — | Inherited from Entity base |

**Child collections** (already on entity — no change):
- `ContactDonationPurposes` (many-to-many Contact ↔ Purpose link)
- `Products` (inventory linkage — legacy)

**Computed/aggregated (NEW for grid display — not persisted):**

| Field | Type | Source |
|-------|------|--------|
| RaisedAmount | decimal | `SUM(fund.Donations.Amount WHERE Donations.DonationPurposeId = row.DonationPurposeId AND IsActive = true)` — subquery in `GetDonationPurposes` GetAll handler |
| RaisedPercent | decimal | `RaisedAmount / NULLIF(TargetAmount, 0) * 100` — optionally computed in FE from RaisedAmount + TargetAmount |

> NOTE for BE Dev: verify the exact FK column on the `Donation` entity that points to Purpose (likely `DonationPurposeId` on `Donation` table — check `Base.Domain/Models/DonationModels/Donation.cs`). If a Donation has multiple purpose distributions (see `DonationDistribution`-style table), the SUM must go through that child instead.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| DonationCategoryId | DonationCategory | `Base.Domain/Models/DonationModels/DonationCategory.cs` | `donationCategories` (operation name `GetDonationCategories`) | donationCategoryName | DonationCategoryResponseDto |
| DonationGroupId | DonationGroup | `Base.Domain/Models/DonationModels/DonationGroup.cs` | `donationGroups` (operation name `GetDonationGroups`) | donationGroupName | DonationGroupResponseDto |
| OrganizationalUnitId | OrganizationalUnit | `Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs` | `organizationalUnits` (operation name `GetOrganizationalUnits`) | organizationalUnitName | OrganizationalUnitResponseDto |

> **NAMING NOTE**: Existing queries in this project do NOT follow the `GetAll{Entity}List` convention used in the MASTER_GRID template — they use `Get{Entities}` (plural) and expose a `donation{Entities}` GQL field. **Keep existing names during ALIGN — do not rename**, or other screens (#1, #5, #6, #7, etc.) will break. Only the FE DTO / GQL query bodies for THIS screen need to change.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `DonationPurposeCode` is unique per CompanyId (`ValidateUniqueWhenCreate` + `ValidateUniqueWhenUpdate`)
- `DonationPurposeName` should be unique per Category within CompanyId

**Required Field Rules:**
- DonationPurposeCode, DonationPurposeName, DonationCategoryId, DonationGroupId are mandatory
- All other fields optional

**Conditional Rules:**
- If `TargetAmount > 0`, then `StartDate` must be set (a fund with a target needs a start)
- If `EndDate` is provided, it must be ≥ `StartDate`
- When Category is selected in FE modal, Group auto-populates from `DonationCategory.DonationGroupId` and is displayed readonly (user cannot change Group independently)

**Business Logic:**
- Soft-delete only (`IsActive = false`) — never hard-delete if any Donation rows reference this purpose (FK constraint; show friendly error "Cannot delete: N donations reference this purpose — deactivate instead")
- Inactive purposes must NOT appear in the donation-entry Purpose dropdown (Global Donation etc.) — only `IsActive = true` and within `[StartDate, EndDate]` window
- CompanyId is set from HttpContext on create (multi-tenant scope)

**Workflow**: None (flat master entity).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered decisions.

**Screen Type**: MASTER_GRID
**Type Classification**: Type 1 — simple master/reference with multi-FK validation + per-row aggregation
**Reason**: flat entity, 3 FKs, no child grid, single grid + modal form. Aggregation column adds Medium complexity.

**Backend Patterns Required:**
- [x] Standard CRUD (entity + 11 files exist — verify and align)
- [ ] Nested child creation — NO
- [x] Multi-FK validation (ValidateForeignKeyRecord × 3: DonationCategory, DonationGroup, OrganizationalUnit)
- [x] Unique validation — DonationPurposeCode per CompanyId
- [x] Per-row aggregation — RaisedAmount via LINQ subquery in `GetDonationPurposes` handler
- [ ] File upload — NO

**Frontend Patterns Required:**
- [x] AdvancedDataTable
- [x] RJSF Modal Form (driven by GridFormSchema from DB seed)
- [ ] File upload — NO
- [ ] Summary cards — NO (mockup has no KPI cards above grid)
- [x] Grid aggregation column — "Target / Raised" progress bar (computed via `raisedAmount` + `targetAmount`)
- [ ] Info / side panel — NO
- [ ] Drag-to-reorder — NO (OrderBy is a numeric input, not drag UI)
- [ ] Click-through filter — NO
- [x] **Cross-field dependency**: Category dropdown → auto-fill readonly Group input (RJSF `ui:dependencies` or custom onChange handler)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer. Extracted directly from `html_mockup_screens/screens/fundraising/donation-purposes.html` — this IS the design spec.
> **Scope reminder**: The mockup has 3 tabs (Purposes / Categories / Groups). Only the **Purposes tab** is in scope for this prompt. Categories (#3) and Groups (#4) are separate registry screens with their own menu routes. Tab navigation UI is OUT of scope here — render as a standalone grid.

### Grid/List View

**Grid Columns** (in display order — matches mockup exactly):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | # | (row index) | number | 40px | NO | Row number only — rendered by grid |
| 2 | Code | donationPurposeCode | badge (monospace pill) | 100px | YES | Rendered with `purpose-code` badge style |
| 3 | Purpose Name | donationPurposeName | text (bold) | auto | YES | Primary column |
| 4 | Category | donationCategory.donationCategoryName | badge (teal `cat-badge`) | 140px | YES | From FK navigation |
| 5 | Group | donationGroup.donationGroupName | badge (purple/amber/blue/pink — color varies by group) | 140px | YES | From FK navigation |
| 6 | Org Unit | organizationalUnit.organizationalUnitName | text | 130px | NO | `—` when null |
| 7 | Target / Raised | computed | progress bar + "$X / $Y (%)" | 240px | NO | See "Aggregation Column" below |
| 8 | Start | startDate | date (MMM YYYY) | 80px | YES | `—` when null |
| 9 | End | endDate | date (MMM YYYY) | 80px | YES | `—` when null |
| 10 | Order | orderBy | numeric badge (`order-num`) | 60px | YES | 26×26 circle badge |
| 11 | Status | isActive | status badge | 90px | YES | green "Active" / amber "Inactive" with status dot |
| 12 | Actions | — | icon buttons | 100px | NO | Edit (pen), Delete (trash). If inactive → show only View (eye) |

**Search/Filter Fields**: donationPurposeCode, donationPurposeName, donationCategory.donationCategoryName, donationGroup.donationGroupName, organizationalUnit.organizationalUnitName, isActive

**Grid Actions**: Add (top-right "New Purpose" button), Edit (row), Toggle Active (row context), Delete (row), Export (top-right `Export` button → calls standard grid export)

**Grid-level behavior**:
- Inactive rows shown with `opacity: 0.6` (mockup row 8 "Legacy Building Fund")
- Export button in page header → calls AdvancedDataTable export

### RJSF Modal Form

> Modal size: `modal-lg` (gradient teal header with bullseye icon). Fields driven by GridFormSchema in DB seed.
> **Mockup**: title "New Purpose" on create, "Edit Purpose" on edit. Footer has Cancel + "Save Purpose" (check icon).

**Form Sections** (single section, 2-column layout — no section headers in mockup):

| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | (no title — flat form) | 2-column with 1-column overrides for Description | donationPurposeCode, donationPurposeName, donationCategoryId, donationGroupId, organizationalUnitId, targetAmount, startDate, endDate, description (full-width), orderBy, isActive |

**Field Widget Mapping**:

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| donationPurposeCode | text | "Auto-generated" | required, max 50 | Unique per Company |
| donationPurposeName | text | "Enter purpose name" | required, max 200 | — |
| donationCategoryId | ApiSelectV2 | "Select category..." | required | Query: `GetDonationCategories` (gql field `donationCategories`) → display `donationCategoryName` |
| donationGroupId | text (readonly) | "Auto-filled from category" | required | **Auto-populated** when Category changes: FE fetches the selected Category's `donationGroupId` + `donationGroup.donationGroupName` and sets both the hidden int value and the visible readonly string. Background `#f8fafc`. |
| organizationalUnitId | ApiSelectV2 | "Select org unit..." | optional | Query: `GetOrganizationalUnits` → display `organizationalUnitName` |
| targetAmount | number | "0.00" | min 0, 2 decimals | Optional |
| startDate | date | — | optional | HTML5 date picker |
| endDate | date | — | optional, ≥ startDate | HTML5 date picker |
| description | textarea | "Describe the purpose of this fund..." | max 500 | Rows=3. **Full-width** (col-12). |
| orderBy | number | "1" | int ≥ 0 | Default next available |
| isActive | toggle switch | — | default `true` | Teal switch, label "Active" |

### Page Widgets & Summary Cards

**Widgets**: NONE (mockup has no KPI cards above grid — only the tab nav, which is out of scope here)

**Layout Variant** (REQUIRED): `grid-only`
→ FE Dev uses **Variant A**: `<AdvancedDataTable>` with internal header. No `<ScreenHeader>` in page component.

### Grid Aggregation Columns

**Aggregation Columns**: ONE (the "Target / Raised" column, rendered as a progress bar + text)

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Target / Raised | Inline progress bar showing raised vs target, plus `$X / $Y (N%)` text. When no target, shows `$X raised (no target)` with no bar. | `RaisedAmount` + existing `TargetAmount` | BE: LINQ subquery in `GetDonationPurposes` GetAll query — `RaisedAmount = fund.Donations.Where(d => d.DonationPurposeId == row.DonationPurposeId && d.IsActive).Sum(d => d.Amount)`. Exposed as `raisedAmount` in `DonationPurposeResponseDto` and GQL. FE: custom cell renderer with 4-band color (`low` red <25%, `mid` amber 25-99%, `full` teal 100%). |

**Progress bar color bands** (from mockup CSS):
- 0–24% → `danger-color` (#dc2626)
- 25–74% → `warning-color` (#f59e0b)
- 75–99% → `success-color` (#22c55e)
- 100%+ → `accent` (#0e7490) — teal "full"

### Side Panels / Info Displays

**Side Panel**: NONE

### User Interaction Flow

1. User navigates to `/{lang}/setting/donationconfig/donationpurpose` → grid loads with pagination
2. Clicks "New Purpose" (top-right) → modal opens (title: "New Purpose", gradient header)
3. Selects Category → Group field auto-populates readonly (triggered by Category onChange)
4. Fills other fields → Save → Create mutation fires → grid refreshes → toast "Donation Purpose created"
5. Edit: clicks pen icon on row → modal opens pre-filled → fields editable → Save
6. Toggle Active: (triggered via grid action or modal switch) → Activate/Deactivate mutation → status badge updates + row opacity toggles
7. Delete: clicks trash icon → confirm dialog → Delete mutation → if FK protected, show "N donations reference this — deactivate instead"
8. Export: clicks Export button (top-right) → CSV/Excel download via AdvancedDataTable export handler

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer. Canonical reference: `ContactType` (MASTER_GRID).

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | DonationPurpose | Entity/class name |
| contactType | donationPurpose | Variable/field names |
| ContactTypeId | DonationPurposeId | PK field |
| ContactTypes | DonationPurposes | Table name, collection names |
| contact-type | donation-purpose | (not used — no dashes in current paths) |
| contacttype | donationpurpose | FE folder, import paths |
| CONTACTTYPE | DONATIONPURPOSE | Grid code, menu code |
| corg | fund | DB schema |
| Corg | Donation | Backend group name |
| CorgModels | DonationModels | Namespace suffix |
| CONTACT | CRM_ORGANIZATION | Parent menu code |
| CRM | CRM | Module code |
| crm/contact/contacttype | setting/donationconfig/donationpurpose | FE route path |
| corg-service | donation-service | FE entity folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer. ALIGN scope — **most files already exist**; list below covers which files to MODIFY vs leave alone.

### Backend Files (all exist — MODIFY only)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/DonationPurpose.cs` | MODIFY: relax `StartDate` from `DateTime` → `DateTime?` (optional per mockup). Leave child collections. |
| 2 | EF Config | `.../Base.Infrastructure/Data/Configurations/DonationConfigurations/DonationPurposeConfiguration.cs` | VERIFY: StartDate optional, FK to OrganizationalUnit optional |
| 3 | Schemas (DTOs) | `.../Base.Application/Schemas/DonationSchemas/DonationPurposeSchemas.cs` | MODIFY: add `OrganizationalUnitDto? OrganizationalUnit` nav to `DonationPurposeResponseDto`; add `RaisedAmount` (decimal) field. Make `StartDate` nullable. |
| 4 | Create Command | `.../Base.Application/Business/DonationBusiness/DonationPurposes/Commands/CreateDonationPurposeCommand.cs` (and handler) | VERIFY: sets CompanyId from HttpContext; validates 3 FKs |
| 5 | Update Command | `.../DonationBusiness/DonationPurposes/Commands/UpdateDonationPurposeCommand.cs` | VERIFY |
| 6 | Delete Command | `.../DonationBusiness/DonationPurposes/Commands/DeleteDonationPurposeCommand.cs` | VERIFY: soft-delete + FK protection |
| 7 | Toggle Command | `.../DonationBusiness/DonationPurposes/Commands/ToggleDonationPurposeStatusCommand.cs` | VERIFY |
| 8 | GetAll Query Handler | `.../DonationBusiness/DonationPurposes/Queries/GetDonationPurposesQueryHandler.cs` | MODIFY: project `OrganizationalUnit` nav; add `RaisedAmount` subquery (see § ⑥ Aggregation Column). **Use existing query name `GetDonationPurposes` — do not rename.** |
| 9 | GetById Query Handler | `.../DonationBusiness/DonationPurposes/Queries/GetDonationPurposeByIdQueryHandler.cs` | MODIFY: project OrganizationalUnit nav |
| 10 | Mutations | `.../Base.API/EndPoints/Donation/Mutations/DonationPurposeMutations.cs` | LEAVE AS-IS — existing operation names (`CreateDonationPurpose`, `UpdateDonationPurpose`, `ActivateDeactivateDonationPurpose`, `DeleteDonationPurpose`) are used by #1 and other screens. |
| 11 | Queries | `.../Base.API/EndPoints/Donation/Queries/DonationPurposeQueries.cs` | LEAVE AS-IS — keep `GetDonationPurposes`, `GetDonationPurposeById`, `GetOrganizationalDonationPurposeById` |

### Backend Wiring Updates (verify — already wired for existing entity)

| # | File to Modify | What to Verify |
|---|---------------|---------------|
| 1 | IDonationDbContext.cs | `DbSet<DonationPurpose>` exists |
| 2 | DonationDbContext.cs | `DbSet<DonationPurpose>` exists |
| 3 | DecoratorProperties.cs | `DecoratorDonationModules` entry exists |
| 4 | DonationMappings.cs | Mapster config for Request↔Entity, Response↔Entity; confirm `OrganizationalUnit` nav is mapped |

### Frontend Files (ALIGN — modify existing, remove duplicates)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/donation-service/DonationPurposeDto.ts` | MODIFY: REMOVE `currencyId` and `currency` fields (not on BE, not in mockup). ADD `raisedAmount: number`, `organizationalUnit?: { organizationalUnitName: string; organizationalUnitId: number }`. Make `organizationalUnitId?: number`, `startDate?: string`, `endDate?: string`, `targetAmount?: number`. |
| 2 | GQL Query | `src/infrastructure/gql-queries/donation-queries/DonationPurposeQuery.ts` | MODIFY: fix formatting (newlines); add `organizationalUnit { organizationalUnitId organizationalUnitName }`, `raisedAmount`, `companyId` to selection set. Remove bogus `currency` (not in current query). |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/donation-mutations/DonationPurposeMutation.ts` | MODIFY: change `$organizationalUnitId: Int!` → `$organizationalUnitId: Int` (optional); change `$startDate: DateTime!` → `$startDate: DateTime` (optional); make `$description: String!` → `$description: String` (optional per entity). Reformat for readability. |
| 4 | Page Config | `src/presentation/pages/setting/donationconfig/donationpurpose.tsx` (verify exists; create if missing) | Export `DonationPurposePageConfig` — renders `<DonationPurposeDataTable />` |
| 5 | Index Page / Data Table | `src/presentation/components/page-components/setting/donationconfig/donationpurpose/data-table.tsx` | MODIFY: flip `enableAdd: false → true`; flip `enableView/Edit/Delete/Toggle: false → true`; add custom cell renderer for "Target / Raised" aggregation column (progress bar). |
| 6 | Route Page | `src/app/[lang]/setting/donationconfig/donationpurpose/page.tsx` | KEEP (already exists, correct) |

**Routes to DELETE (obsolete — duplicate implementations not matching MODULE_MENU_REFERENCE):**
- `src/app/[lang]/crm/organization/donationpurpose/page.tsx` ← obsolete
- `src/app/[lang]/organization/donationsetup/donationpurpose/page.tsx` ← obsolete

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | Verify `DONATIONPURPOSE` operations config (create/update/delete/toggle mutations + query) |
| 2 | operations-config.ts | Verify import + registration exists |
| 3 | Sidebar menu config | Verify `DONATIONPURPOSE` menu entry under `CRM_ORGANIZATION` with URL `setting/donationconfig/donationpurpose` |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens. User reviews and confirms.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Donation Purpose
MenuCode: DONATIONPURPOSE
ParentMenu: CRM_ORGANIZATION
Module: CRM
MenuUrl: setting/donationconfig/donationpurpose
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: DONATIONPURPOSE
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — final shapes after ALIGN.

**GraphQL Types:**
- Query type: `DonationPurposeQueries` (extend Query)
- Mutation type: `DonationPurposeMutations` (extend Mutation)

**Queries** (EXISTING names — do not rename):

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| donationPurposes | PaginatedApiResponse<DonationPurposeResponseDto> | GridFeatureRequest (pageSize, pageIndex, sortColumn, sortDescending, searchTerm, advancedFilter) |
| donationPurposeById | BaseApiResponse<DonationPurposeResponseDto> | donationPurposeId |
| organizationalDonationPurposeById | BaseApiResponse<OrganizationalDonationPurposeResponseDto> | organizationalUnitId (leave as-is — used elsewhere) |

**Mutations** (EXISTING names — do not rename):

| GQL Field | Input | Returns |
|-----------|-------|---------|
| createDonationPurpose | DonationPurposeRequestDto | DonationPurposeRequestDto (with new id) |
| updateDonationPurpose | DonationPurposeRequestDto | DonationPurposeRequestDto |
| deleteDonationPurpose | donationPurposeId | DonationPurposeRequestDto |
| activateDeactivateDonationPurpose | donationPurposeId | DonationPurposeRequestDto |

**Response DTO Fields** (what FE receives — AFTER align):

| Field | Type | Notes |
|-------|------|-------|
| donationPurposeId | int | PK |
| donationPurposeCode | string | — |
| donationPurposeName | string | — |
| donationCategoryId | int | FK |
| donationCategory | { donationCategoryId, donationCategoryName, donationGroupId? } | Nav — include DonationGroupId for auto-fill on FE |
| donationGroupId | int | FK |
| donationGroup | { donationGroupId, donationGroupName } | Nav |
| organizationalUnitId | int? | FK (optional) |
| organizationalUnit | { organizationalUnitId, organizationalUnitName } \| null | Nav (NEW — add to query + DTO) |
| companyId | int? | FK (optional) |
| targetAmount | decimal? | Optional |
| raisedAmount | decimal | **NEW** computed via subquery |
| startDate | string (ISO) \| null | Nullable after align |
| endDate | string (ISO) \| null | Already nullable |
| description | string? | Optional |
| orderBy | int | — |
| isActive | bool | Inherited |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/setting/donationconfig/donationpurpose`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 12 columns: #, Code, Purpose Name, Category, Group, Org Unit, Target / Raised, Start, End, Order, Status, Actions
- [ ] Search filters by code, name, category name, group name, org unit name
- [ ] Add "EDU-003 / Children's Books Fund" → modal shows → select "Education" category → Group field auto-fills "Program Funds" readonly → save succeeds → appears in grid
- [ ] Edit existing purpose → modal pre-fills all fields → changing Category updates Group readonly → save updates grid
- [ ] Toggle active/inactive → status badge flips green↔amber; inactive rows show at 0.6 opacity
- [ ] Delete active purpose with no donations → soft-delete succeeds
- [ ] Delete purpose with referenced donations → friendly error "N donations reference this — deactivate instead"
- [ ] Category dropdown (ApiSelectV2) loads from `donationCategories` query
- [ ] OrganizationalUnit dropdown (ApiSelectV2) loads from `organizationalUnits` query
- [ ] "Target / Raised" progress bar renders with correct color band (red <25, amber 25-74, green 75-99, teal 100+)
- [ ] When TargetAmount is null/0, column shows `$X raised (no target)` with no bar
- [ ] When StartDate/EndDate are null, grid shows `—`
- [ ] Obsolete routes at `crm/organization/donationpurpose` and `organization/donationsetup/donationpurpose` return 404 or redirect
- [ ] Permissions: non-BUSINESSADMIN role hides Create/Edit/Delete buttons

**DB Seed Verification:**
- [ ] Menu "Donation Purpose" visible under CRM → Organization with URL `setting/donationconfig/donationpurpose`
- [ ] Grid config renders all 12 columns with correct types
- [ ] GridFormSchema renders modal form with 2-column layout and readonly Group field

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **ALIGN scope — do NOT regenerate the entity or add a new module.** Schema `fund` and group `Donation` already exist. Touch only the files listed in § ⑧.
- **Query/mutation naming deviates from template convention**: project uses `GetDonationPurposes` / `donationPurposes` / `activateDeactivateDonationPurpose` instead of `GetAllDonationPurposeList` / `ToggleDonationPurpose`. Do **NOT rename** — these are referenced by #1 Global Donation and other completed/partial screens. Only modify field selections inside the query bodies.
- **Currency dead field**: FE `DonationPurposeDto.ts` currently declares `currencyId` and `currency` — these are NOT on the BE entity and NOT in the mockup. Remove them from the FE DTO and any form that references them. If a screen elsewhere imports `DonationPurposeDto.currency`, fix that importer to not use it (search before removing).
- **Duplicate FE routes**: three `page.tsx` files exist for `donationpurpose` (at `crm/organization/`, `organization/donationsetup/`, `setting/donationconfig/`). The canonical per MODULE_MENU_REFERENCE.md is `setting/donationconfig/donationpurpose`. Delete the other two after verifying no imports/links point to them.
- **Mockup shows 3 tabs** (Purposes / Categories / Groups) but MODULE_MENU_REFERENCE.md treats each as a separate menu. Build this screen as a **standalone grid** — do NOT build the tab navigation shell. Categories (#3) and Groups (#4) are separate screens with their own prompts and routes.
- **Category→Group auto-fill**: the "Group" field in the modal is readonly and auto-populates from the selected Category. This requires the Category ApiSelect response to expose `donationGroupId` + `donationGroup.donationGroupName` so the form can mirror them into the Group field on Category change. Update the Category query selection if needed.
- **Aggregation column requires DB inspection**: confirm the correct source table/column for `RaisedAmount`. Likely `fund.Donations.DonationPurposeId` — but if donations store purpose allocation through a distribution/split table (similar to `RecurringDonationScheduleDistribution`), the SUM must traverse that. BE dev MUST verify by reading `Base.Domain/Models/DonationModels/Donation.cs` (and any `DonationDistribution`-like entity) before writing the subquery.
- **StartDate nullability change**: Entity currently declares `DateTime StartDate` (non-null). Mockup permits empty (`—` for General Fund, Emergency Relief). Change to `DateTime?` in entity + DTOs + GQL + EF config. A data migration may be needed if the DB column is NOT NULL.
- **`enableAdd = false` in current data-table**: existing FE grid disables all CRUD actions. Flip these to `true` to match the "New Purpose" button and row action icons in the mockup.
- **`DONATIONPURPOSE` appears twice in MODULE_MENU_REFERENCE section CRM_ORGANIZATION** but under SET_DONATIONCONFIG the URLs go through `setting/donationconfig/...` — parent stays `CRM_ORGANIZATION`, URL uses `setting/donationconfig/donationpurpose`. This is intentional per the "Note" at line 130 of that file. Use exactly these values in the CONFIG block.

**Service Dependencies** (UI-only — no backend service implementation):

_(none — this is a standard master-grid CRUD screen; every action has a backend implementation path in this repo.)_

---

## ⑭ REVISION R1 — Donation Purpose Detail / View Mode

> **Planned by** `/plan-screens` on 2026-07-07. **Status**: `REVISION_PLANNED` (ready for `/build-screen` or `/continue-screen`).
> **Driver**: New requirement — opening a Donation Purpose must show program details, goal / raised / remaining / progress, a donation summary **by source**, and the full donation history for that purpose.
> **This section REVISES §②/③/⑥/⑧/⑩/⑪/⑫ for the detail-view addition. The original MASTER_GRID sections above remain valid — the modal CRUD is unchanged.**

### R1.0 — Architecture decision (LOCKED)

| Decision | Value | Rationale |
|----------|-------|-----------|
| Detail placement | Same route `setting/donationconfig?tab=purpose&mode=read&id={id}` — no new route, no dashboard-widget seed | Reuse `AdvancedDataTable` built-in View action + a `mode=read` dispatch branch in the shell (Receipt Management `generated-tab.tsx` pattern) |
| Screen-type note | Stays `MASTER_GRID` for CRUD (modal); **adds a read-only DETAIL layout** (FLOW-like `mode=read`). Divergence noted per plan rule 13. | The add/edit form is still a modal; only a read view is added |
| **Attribution model** | **Dedicated OrganizationalUnit node per DonationPurpose (1:1)** — mirrors the Event "own OrganizationalUnit node" pattern (`project_event_org_unit_node_pattern`). Cash is attributed via `fund.GlobalDonationDistributions.OrganizationalUnitId → DonationPurpose.OrganizationalUnitId`. | The donation pipeline already writes `GlobalDonationDistribution.OrganizationalUnitId`; making each purpose own a unique node turns that existing split into a unique per-purpose attribution with no new FK on the ledger. **`fund.GlobalDonations` gets NO `DonationPurposeId` column.** |
| Total Raised | **Settled cash only** — `SUM(GlobalDonationDistribution.AllocatedAmount)` for distributions whose org unit = the purpose's node. Pledges count only paid installments (`PledgePayments` with a `GlobalDonationId`). No open-commitment / expected figures. | User decision |
| Remaining / % | `Remaining = TargetAmount − Raised`; `% = Raised / NULLIF(TargetAmount,0) × 100`. When no target → "no target", no bar. | Matches existing `target-raised-progress` bands |

**Why the current `OrganizationalUnitId` can't be used as-is**: today it is an *optional, user-picked FK to an existing shared department* (`CreateDonationPurpose.cs:30`), so many purposes can share one org unit and org-unit→purpose is **not unique**. R1 repoints this field to a **dedicated per-purpose node**. This is a semantic change to the column + requires a backfill.

### R1.1 — Build phasing (my scope call)

- **Phase 1 (this effort — makes the model structurally correct + ships the page):**
  1. BE: `CreateDonationPurpose` auto-creates a dedicated `OrganizationalUnit` node (`UnitType = DONATIONPURPOSE`) and sets `DonationPurpose.OrganizationalUnitId` to it. Wrap the two inserts in one transaction via `CreateExecutionStrategy().ExecuteAsync` (Npgsql retrying strategy — see `reference_npgsql_execution_strategy_transactions`).
  2. BE: **Backfill migration** — create a node for every existing purpose that lacks a dedicated one and repoint `OrganizationalUnitId`. (User writes the EF migration + backfill SQL.)
  3. BE: New `GetDonationPurposeDetail(donationPurposeId)` query + handler + DTO — returns purpose + program(s) + goal/raised/remaining + by-source breakdown (see R1.5). Model on `CaseBusiness/Programs/GetFundingAllocationQuery/GetProgramFundingAllocation.cs`.
  4. BE: fix `GetDonationPurposeByIdHandler` so `RaisedAmount` is populated (today it is silently `0` — the handler only Includes navs, `GetDonationPurposeById.cs:36-42`). Either reuse the detail query's raised calc or leave GetById as-is and drive the page solely off `GetDonationPurposeDetail`.
  5. FE (I build): `enableView:true`, `mode=read` shell branch, `DonationPurposeDetailPage`, by-source summary component, embedded history grid, query + DTO extensions.
- **Phase 2 (documented here, sequenced next — broadens coverage):** every donation channel that already knows its `DonationPurposeId` (P2P via `P2PCampaignPage`, Crowdfund via `CrowdFund`, Pledge via `Pledge`, Online-resolve via staff-supplied purpose, Recurring via `RecurringDonationScheduleDistribution`) must set its `GlobalDonationDistribution.OrganizationalUnitId = purpose.OrganizationalUnitId` (the node) at create/resolve time, so **future** donations attribute uniformly through the single org-unit path. Until Phase 2 lands, only distributions already routed to the purpose's node count toward Raised.

### R1.2 — Entity / data-model changes (§② delta)

| Change | Detail |
|--------|--------|
| `DonationPurpose.OrganizationalUnitId` | Semantic change: was "owning department (optional, shared)" → now "the purpose's own dedicated node (1:1, set by the system on create)". Keep the column; the FE org-unit picker in the modal should be **removed or made read-only** (the node is system-managed, not user-picked). |
| New OrganizationalUnit `UnitType` | `DONATIONPURPOSE` MasterData code (mirror `EVENT`). Confirm the `UnitType`/`OrganizationalUnitType` MasterData set + seed the code. |
| `fund.GlobalDonations` | **NO change** — no `DonationPurposeId` column added. |

### R1.3 — New FK / reverse-lookups (§③ delta)

| Lookup | Path | Purpose |
|--------|------|---------|
| Purpose → Program(s) | Query `case.ProgramFundingSource` WHERE `DonationPurposeId = @id AND IsDeleted = false`, `.Include(f => f.Program)` | "Program details" panel. No reverse nav exists on `DonationPurpose` — query the join table directly. A purpose may fund 0..N programs. |
| Distributions → Purpose | `GlobalDonationDistribution.OrganizationalUnitId == DonationPurpose.OrganizationalUnitId` | Raised + history + by-source aggregation |
| Distribution → source | Parent `GlobalDonation` columns: `P2PCampaignPageId` (P2P Campaign, `P2PFundraiserId IS NULL`), `P2PFundraiserId` (P2P Fundraiser), `OnlineDonationPageId` (Online); Crowdfund via `fund.CrowdFundDonations` junction; Pledge via `fund.PledgePayments.GlobalDonationId → Pledge`. **`SourceTypeId` is NOT a reliable discriminator** (its EF FK targets `Branch`). | Summary-by-source classification |

### R1.4 — Detail view UI blueprint (§⑥ — LAYOUT 2: DETAIL, `mode=read`)

Clone `.../donationconfig/receiptmanagement/tabs/generated-detail-page.tsx` structure (Card + DetailRow helpers, `DetailSkeleton`, `handleBack()` → `router.push` back to `?tab=purpose`). Bootstrap `row g-3`, left `col-lg-8` / right `col-lg-4`.

- **Header row**: Purpose name (bold) + `donationPurposeCode` mono pill + Category (teal) & Group badges + Status badge; right-aligned **Back** + **Edit** (opens the existing modal) buttons.
- **KPI tiles** (reuse `crowdfunding/crowdfund-widgets.tsx` `WidgetTile`; solid `bg-{tone}-600 text-white` icon badges per `feedback_solid_icon_bg_white_foreground`): **Goal** (`targetAmount`), **Total Raised** (settled), **Remaining**, **% Funded**. Loading skeletons.
- **Funding progress bar**: reuse `shared-cell-renderers/target-raised-progress.tsx` (4-band: red <25 / amber <75 / green <100 / teal ≥100). No-target → "$X raised (no target)".
- **Program Details card** (left col): for each linked program — program name + code, status badge, funding model, annual budget, approved date. If none → empty state "This purpose is not linked to a Case Management program."
- **Donation Summary by Source** (left col, **NET-NEW component**): one card/row per source — **P2P Campaigns, P2P Fundraisers, Crowdfunding, Online Donations, Pledges** — each with donation count + total amount + % of raised. A small bar or the `WidgetTile` grid is fine (see `dataviz` skill if a chart is added). Sources with zero read as `$0 (0)`.
- **Donation History grid** (full-width below): embedded `AdvancedDataTable` reusing an existing global-donation gridCode, scoped via `extraVariables={{ organizationalUnitId: <purpose node id> }}` (or a new `donationPurposeId` filter honored by the resolver). Columns: Date, Donor, Source, Amount, Mode, Receipt #. `showHeader={false}`.

### R1.5 — BE→FE contract (§⑩ delta)

New query (do **NOT** rename existing ones):

| GQL field | Args | Returns |
|-----------|------|---------|
| `donationPurposeDetail` | `donationPurposeId: Int!` | `BaseApiResponse<DonationPurposeDetailResponseDto>` |

`DonationPurposeDetailResponseDto` (new):
- `donationPurposeId, donationPurposeCode, donationPurposeName, isActive`
- `donationCategory { … }, donationGroup { … }, organizationalUnit { organizationalUnitId, unitName }`
- `targetAmount: decimal?`, `raisedAmount: decimal`, `remainingAmount: decimal`, `raisedPercent: decimal`
- `programs: [{ programId, programCode, programName, statusName, fundingModelName, annualBudget, approvedDate }]` (from `ProgramFundingSource`)
- `sourceBreakdown: [{ source: string, donationCount: int, totalAmount: decimal }]` (P2P Campaign / P2P Fundraiser / Crowdfund / Online / Pledge)
- (history is served by the embedded grid's own gridCode query, not this DTO)

### R1.6 — File manifest (§⑧ delta)

**Backend (user builds — I make compiling changes only where I touch shared code):**
| File | Action |
|------|--------|
| `DonationPurposes/Commands/CreateDonationPurpose.cs` | Auto-create `DONATIONPURPOSE` OrganizationalUnit node in a tx (execution-strategy), set `OrganizationalUnitId`. |
| `DonationPurposes/Queries/GetDonationPurposeDetail.cs` | **NEW** query+validator+handler+result (raised/remaining/by-source/programs). |
| `DonationPurposes/Queries/GetDonationPurposeById.cs` | Optional: compute `RaisedAmount` (currently 0). |
| `Base.API/EndPoints/Donation/Queries/DonationPurposeQueries.cs` | Add `donationPurposeDetail` field (keep all existing). |
| `Schemas/DonationSchemas/DonationPurposeSchemas.cs` | Add `DonationPurposeDetailResponseDto` + nested program/source DTOs. |
| EF migration + backfill | **NEW** — dedicated nodes for existing purposes + repoint `OrganizationalUnitId`; seed `DONATIONPURPOSE` UnitType MasterData. (User creates migration per `feedback_user_creates_migrations`.) |
| *(Phase 2)* each channel's create/resolve handler | Set `GlobalDonationDistribution.OrganizationalUnitId = purpose node` where purpose is known. |

**Frontend (I build):**
| File | Action |
|------|--------|
| `domain/entities/donation-service/DonationPurposeDto.ts` | Add `DonationPurposeDetailResponseDto` (raised/remaining/percent, `programs[]`, `sourceBreakdown[]`). |
| `infrastructure/gql-queries/donation-queries/DonationPurposeQuery.ts` | Add `DONATIONPURPOSE_DETAIL_QUERY`. |
| `.../setting/donationconfig/donationpurpose/data-table.tsx` | `enableActions.enableView: true`; ensure `primaryKey: "donationPurposeId"`. |
| `.../donationconfig/donationconfig/index-page.tsx` | Add `mode=read` branch on the `purpose` tab → render `DonationPurposeDetailPage` (clone `generated-tab.tsx` dispatch). |
| `.../donationconfig/donationpurpose/detail-page.tsx` | **NEW** `DonationPurposeDetailPage` (KPI tiles + progress + program card + history grid). |
| `.../donationconfig/donationpurpose/donation-summary-by-source.tsx` | **NEW** by-source summary component. |
| reuse | `shared-cell-renderers/target-raised-progress.tsx`, `crowdfunding/crowdfund-widgets.tsx` `WidgetTile`. |

### R1.7 — Acceptance criteria (§⑪ delta)

- [ ] Grid row → View icon → `?mode=read&id=` opens the detail page inside the Purposes tab (Back returns to the grid).
- [ ] KPI tiles show Goal, Total Raised (settled cash), Remaining, % — Raised is non-zero for a purpose whose node has distributions.
- [ ] Progress bar color band matches % (red/amber/green/teal); no-target purpose shows "no target" with no bar.
- [ ] Program Details card lists linked program(s) via `ProgramFundingSource`; empty state when none.
- [ ] Summary-by-source shows all 5 sources with count + amount; zero sources render `$0 (0)`.
- [ ] Donation history grid lists the purpose's donations, scoped by the node org unit.
- [ ] Creating a new purpose auto-creates its dedicated org-unit node; the modal no longer asks the user to pick an org unit (or shows it read-only).
- [ ] Existing purposes have nodes after backfill; their historical distributions attribute correctly.

### R1.8 — Special notes & known gaps (§⑫ delta)

- **Transaction + retrying strategy**: node + purpose insert must use `CreateExecutionStrategy().ExecuteAsync` (Npgsql forbids manual `BeginTransaction` — `reference_npgsql_execution_strategy_transactions`).
- **`OrganizationalUnitId` semantic change + backfill** is the highest-risk item (ISSUE-2-style DB work). Existing rows must be migrated before the detail page reads correctly.
- **Crowdfund source reads empty today** — `fund.CrowdFundDonations` is never populated (donations stay in `OnlineDonationStaging`; `ConfirmCrowdFundDonation` defers promotion and `ResolveOnlineDonationStaging` has no CrowdFund backfill). Show the Crowdfund card but expect `$0` until that pipeline gap is fixed. (See ISSUE-6.)
- **Online source is partial** — one-time online donations persist no purpose; only recurring-flagged online resolves seed a `RecurringDonationScheduleDistribution`. Under the Phase-2 node mapping this resolves; pre-Phase-2 it undercounts. (See ISSUE-7.)
- **Do NOT rename** existing queries/mutations (`GetDonationPurposes`, `donationPurposes`, `activateDeactivateDonationPurpose`) — used by #1 and others.
- **Do NOT add** `DonationPurposeId` to `fund.GlobalDonations`.

---

## ⑮ REVISION R2 — Program → Donation Purpose Fund Allocation

> **Planned by** `/plan-screens #2` on 2026-07-09. **Status**: `REVISION_PLANNED` (ready for `/build-screen #2` or `/continue-screen #2`).
> **Driver**: Extend the existing **Program → Grant fund-allocation loop** (grant `prompts/grant.md` §⑭, BUILT 2026-07-08) to **Donation Purpose**. This is the deferred **ISSUE-20** (grant.md L1092): grant path shipped; DonationPurpose/Sponsor were left on program self-approve. Case Management already raises the fund request against a specific Donation Purpose; this revision lets the **purpose owner allocate** its raised cash to the requesting program(s) and track **which source the money was collected from vs which program it was allocated to**.
> **This section REVISES §②/③/④/⑥/⑧/⑩/⑪/⑫ for the allocation loop. R1 (detail view, §⑭) is a hard prerequisite — the "available to allocate" ceiling = R1's raised-cash figure. Sponsor stays deferred (future).**

### R2.0 — Business framing — the loop we are closing

A **program** (Case Management #51) is funded by any number of grants and/or **donation purposes** via the COMMON table `case.ProgramFundingSource` (M:N; `GrantId` XOR `DonationPurposeId` XOR `SponsorContactId` — funder type is inferred from which FK is set, **no discriminator column**). Today a donation-purpose-funded source is **self-approved** by the program manager. This revision moves the approval to the **purpose owner** — exactly as the grant loop moved it to the grantor — so a purpose cannot be over-committed beyond the cash it has actually raised.

Two sides the Donation Purpose detail page must now show (user's framing — "which source collected vs which source allocated"):
- **Collected-from** — R1's existing **by-source breakdown** (P2P Campaign / P2P Fundraiser / Crowdfund / Online / Pledge). Already built (`GetDonationPurposeDetail.cs` `SourceBreakdown`).
- **Allocated-to** — the **NEW fund-requests inbox**: the list of programs requesting funding from this purpose, with the amount allocated to each.

**Out of scope (this build):** Sponsor allocation-from-source (`SponsorContactId != null`) — stays on program self-approve, same deferral as grant §⑭ (ISSUE-20 / ISSUE-8 below).

### R2.1 — Build phasing + HARD PREREQUISITE

**⚠ PREREQUISITE (blocks the whole feature — user-owned seed + backfill, per `feedback_migrations_strictly_user_owned`):**
R1's raised-cash attribution depends on each purpose owning a dedicated `OrganizationalUnit` node (`UnitType = DONATIONPURPOSE`). **Verified 2026-07-09: the `UNITTYPE` MasterData set seeds only `HQ / REG / BR / SU` (`OrganizationalUnit-sqlscripts.sql` L45-50) — there is NO `DONATIONPURPOSE` row, and no node backfill for existing purposes.** Consequences until applied: (a) `CreateDonationPurpose` **throws** at create-time (it hard-requires the MasterData row, `CreateDonationPurpose.cs` L123-134); (b) existing purposes have no node → `RaisedAmount` reads **$0** → "available to allocate" is $0 and no allocation can be made. **The developer writes the seed + backfill SPEC; the user applies it.** Spec:
1. **Seed** `sett.MasterDatas` `UNITTYPE = DONATIONPURPOSE` (`DataName='Donation Purpose'`, `DataValue='DONATIONPURPOSE'`, `Icon='ph:target'`, idempotent NOT-EXISTS guard — mirror the 4 existing UNITTYPE rows).
2. **Backfill** — for every `fund.DonationPurposes` row with `OrganizationalUnitId IS NULL`: create a dedicated `app.OrganizationalUnit` node (`UnitTypeId`=the DONATIONPURPOSE MasterData, `HierarchyLevel=1`, `ParentUnitId=NULL`, `AcceptsDonationsDirectly=true`, name/code from the purpose) and set `DonationPurposes.OrganizationalUnitId` to it. Wrap per-tenant; idempotent.
3. **(Optional, Phase-2 of R1)** repoint historical `GlobalDonationDistribution.OrganizationalUnitId` for donations that belong to a purpose — otherwise pre-existing donations don't count toward Raised even after the node exists. This is R1 ISSUE-5 (channel wiring); the allocation loop works on go-forward cash without it, but historical raised will undercount.

**Phase 1 (this effort):** BE inbox + allocate command + 2 guard edits; FE allocation surface on the R1 detail page + the #177 workbench pool-strip. **No schema change, no migration** — `ProgramFundingSource` already has `DonationPurposeId`, `AllocatedAmount`, and the full `SourceStatusId`/`ApprovedByStaffId`/`ApprovedDate` lifecycle.

### R2.2 — Entity / data-model (§② delta)

**NO entity change. NO migration.** Operates on existing:
- `case.ProgramFundingSource` — writes `AllocatedAmount` + flips `SourceStatusId` (PENDING→APPROVED) + stamps `ApprovedByStaffId`/`ApprovedDate` on rows where `DonationPurposeId != null`. `AllocatedAmount` — comment currently says "only meaningful for grant-funded"; this revision makes it meaningful for purpose-funded too (same column, same semantics: the committed amount).
- `fund.GlobalDonationDistribution` — read-only; the raised pool = `Σ AllocatedAmount` where `OrganizationalUnitId == purpose.OrganizationalUnitId` (R1's calc).

### R2.3 — Cash-only ceiling model (§④ delta) — DECISION LOCKED

Unlike a grant (which has a contractual `AwardedAmount` reservation ceiling AND a received-cash ceiling), a donation purpose has **no award** — only a soft `TargetAmount` goal and the actual `RaisedAmount`. **User decision (2026-07-09): CASH-ONLY.**

- **`AvailableToAllocate(purpose) = RaisedAmount − Σ AllocatedAmount`** over the purpose's **non-CLOSED** funding sources. This is the ONE pool ceiling.
- **`TargetAmount` is informational only** — drives the R1 goal/progress bar; it is NOT a reservation ceiling (a purpose may allocate up to what it has RAISED, regardless of goal).
- **Source-generic ceilings kept from grant §⑭.3** (reuse the same guard shapes):
  - allocatedAmount ≤ the program's **total term ask** = `ProgramFundingMath.ComputeTermTotalAsk(source, source.Program)` (NOT raw `ExpectedAnnualAmount` — mirror `AllocateGrantToFundingSource.cs:70`).
  - on revise-down, allocatedAmount ≥ `Σ TRANSFERRED` for that source (can't strand cash already moved to the program).
- **Program TRANSFERRED cap** (the money actually leaving the purpose to the program) also caps at `AllocatedAmount` for purpose-funded sources (§⑮.7 #177 delta) — same as grant.
- **Currency**: `DonationPurpose` has no currency FK; allocation is in the company base currency. Do NOT copy the grant's `source.CurrencyId = grant.CurrencyId` step — instead leave `source.CurrencyId` as set by the program form (defaults to company base), or stamp company base if null. No cross-currency validation.

### R2.4 — Purpose-side INBOX query (NEW)

`GetDonationPurposeFundingRequests(donationPurposeId)` → `Base.Application/Business/DonationBusiness/DonationPurposes/Queries/GetDonationPurposeFundingRequests.cs`, `[CustomAuthorize(DecoratorDonationModules.DonationPurpose, Permissions.Read)]`. **Mirror `GetGrantFundingRequests.cs`** but swap the grant pool for the raised pool.

- **Header** (`DonationPurposeFundingRequestHeaderDto`): `raisedAmount` (reuse R1 calc — extract `GetDonationPurposeDetail`'s raised computation into a shared helper `DonationPurposeRaisedHelper.ComputeRaisedAsync(dbContext, purpose.OrganizationalUnitId, ct)` and call it from BOTH places, OR compute inline identically), `targetAmount`, `totalCommitted` (Σ `AllocatedAmount` over non-CLOSED sources), `availableToAllocate` (= raised − committed), `programTransferred` (Σ TRANSFERRED), `programDrawn` (beneficiary drawdown), `requestCount`, `pendingCount`. **No `awardedAmount` / `receivedAmount` fields** (no award/receipt concept for a purpose).
- **Rows** (one per `ProgramFundingSource` where `DonationPurposeId == donationPurposeId && IsDeleted == false`): `fundingSourceId`, `programId`, `programName`, `sourceStatusCode` (PENDING/APPROVED/CLOSED), `expectedAnnualAmount`, `totalAskAmount` (`ComputeTermTotalAsk`), `termYears`, `programTypeCode`, `allocatedAmount` (nullable), `transferredAmount` (Σ TRANSFERRED this source), `drawnAmount` (beneficiary drawdown this source), `currencyCode`, `allocationFrequencyCode`, `startDate`, `endDate`, `canAllocate` (purpose `IsActive` AND status != CLOSED), `approvedByStaffName`, `approvedDate`. (Same row shape as `GrantFundingRequestRowDto` minus grant-specifics.)

### R2.5 — Purpose-side commands (NEW + guard edits)

**⑮.5a — `AllocateDonationPurposeToFundingSource` (NEW).** `.../DonationPurposes/Commands/AllocateDonationPurposeToFundingSource.cs`, `[CustomAuthorize(DecoratorDonationModules.DonationPurpose, Permissions.Modify)]`. **Mirror `AllocateGrantToFundingSource.cs`** with the cash-only guard chain:
- Command: `AllocateDonationPurposeToFundingSourceCommand(int fundingSourceId, decimal allocatedAmount)` → Result `(int fundingSourceId, decimal? allocatedAmount)`.
- Execution-strategy transaction (`efDb.Database.CreateExecutionStrategy().ExecuteAsync` + `BeginTransactionAsync`) — Npgsql forbids manual `BeginTransaction` outside it (`reference_npgsql_execution_strategy_transactions`).
- Load source `.Include(f => f.Program).ThenInclude(p => p.ProgramType)`, `.Include(f => f.SourceStatus)`.
- Guards:
  1. `source.DonationPurposeId != null` (else "This funding source is not donation-purpose-funded."); not CLOSED.
  2. Purpose exists AND `IsActive` (analog of grant's funding-active check). Load `DonationPurposes.FirstOrDefault(DonationPurposeId == source.DonationPurposeId)`; must have an `OrganizationalUnitId` (else raised can't be computed → "This purpose has no fund node yet — apply the DONATIONPURPOSE unit-type seed + backfill.").
  3. `allocatedAmount > 0 && ask > 0 && allocatedAmount > ask` → reject (ask = `ComputeTermTotalAsk`).
  4. **Cash-only:** `otherCommitted` = Σ `AllocatedAmount` over the purpose's non-CLOSED sources excluding this one; `raised` = R2.4 helper; `availableToAllocate = raised − otherCommitted`; if `allocatedAmount > availableToAllocate` → reject ("Allocating {x} would exceed the purpose's available raised funds ({avail} available). Only settled donations can be allocated.").
  5. Revise-down: `alreadyTransferred` = Σ TRANSFERRED this source; `allocatedAmount < alreadyTransferred` → reject.
  6. Set `source.AllocatedAmount = allocatedAmount == 0 ? null : allocatedAmount`. If currently PENDING/NULL and `allocatedAmount > 0` → flip `SourceStatusId → FUNDSOURCESTATUS.APPROVED`, stamp `ApprovedByStaffId = ProgramLifecycleHelpers.ResolveCurrentStaffIdAsync(...)`, `ApprovedDate = DateTime.UtcNow` (Kind=Utc, `feedback_db_utc_only`).
- `allocatedAmount == 0` = **release** (guard 5 already ensures nothing transferred). Books NO ledger row (commitment is a reservation).

**⑮.5b — `ApproveFundingSourceHandler` guard edit (MODIFY).** `CaseBusiness/Programs/LifecycleCommand/FundingSourceLifecycle.cs` L38-42 — currently rejects only `source.GrantId.HasValue`. **Add** `|| source.DonationPurposeId.HasValue`: purpose-funded sources are now approved by the purpose owner via the allocate command, NOT program self-approve. Message: "Donation-purpose-funded sources are approved by the purpose owner from the Donation Purpose screen." (Sponsor `SponsorContactId` still self-approves — keep it out of the guard.)

**⑮.5c — `SaveProgramFundingAllocation` cap edit (MODIFY).** `CaseBusiness/Programs/SaveFundingAllocationCommand/SaveProgramFundingAllocation.cs` `SyncFundingTransactions` — the TRANSFERRED cap currently applies `≤ AllocatedAmount` for grant-funded sources only. **Extend the same cap to purpose-funded sources** (`DonationPurposeId != null`): `Σ TRANSFERRED ≤ AllocatedAmount`, and block any TRANSFERRED payment before allocation (`AllocatedAmount == null`). Sponsor keeps `≤ ExpectedAnnualAmount`.

**⑮.5d — `GetProgramFundingAllocation` read-gate edit (MODIFY).** `Base.Application/.../GetFundingAllocationQuery/GetProgramFundingAllocation.cs` — mirror the grant treatment for purpose-funded: `committed = (GrantId != null || DonationPurposeId != null) ? CommittedAmount : ExpectedAnnualAmount`; `CanApprove = PENDING && programActive && GrantId == null && DonationPurposeId == null` (route purpose through allocate, so the workbench does NOT render a self-Approve button for purpose-funded rows).

### R2.6 — Detail-view UI (§⑥ — new "Fund Requests / Allocations" surface on the R1 detail page)

The R1 detail page (`.../donationconfig/donationpurpose/detail-page.tsx`) already renders: Header · KPI tiles (Goal/Raised/Remaining/%) · progress bar · **left col: Program Details + Donation Summary by Source** · right col: Fund Details · full-width Donation History. **ADD a new full-width `Card` "Fund Requests" (icon `ph:hand-coins`)** below "Donation Summary by Source" (or below the History) — this is the **allocated-to** side beside the existing **collected-from** breakdown.

Card contents (mirror grant `grant-fund-requests-tab.tsx` + `grant-allocate-modal.tsx`, simplified to the cash-only pool):
1. **Pool strip** (KPI row; solid `bg-X-600 text-white` icon badges per `feedback_widget_icon_badge_styling`; amounts right-aligned per `feedback_amount_field_alignment`): **Raised · Committed · Available to Allocate**. (Drop the grant's Awarded/Received tiles — a purpose has neither.)
2. **Requests table** — one row per linked program funding source: Program · Ask (`totalAskAmount`) · Allocated (`allocatedAmount`) · Transferred · Status badge (reuse the `sourceStatusChip` wording pattern — "Waiting for Allocation" → "Allocated") · **Allocate** action (enabled when `canAllocate`). Empty state: "No programs have requested funding from this purpose yet."
3. **Allocate modal** (RHF + Zod): shows Program, Ask, current Available; single `allocatedAmount` numeric input (right-aligned), default `min(ask, available)`; inline validation ≤ available, ≤ ask, ≥ already-transferred; "Allocate full ask" quick button. Submit → `allocateDonationPurposeToFundingSource` → refetch the fund-requests query + the R1 detail query (raised/committed shift). Allocate `0` = release.

New FE files under the donationpurpose feature folder: `donation-purpose-fund-requests.tsx`, `donation-purpose-allocate-modal.tsx`. New GQL docs `DONATION_PURPOSE_FUNDING_REQUESTS_QUERY` + `ALLOCATE_DONATION_PURPOSE_TO_FUNDING_SOURCE` mutation. New DTOs in `donation-service/`.

### R2.7 — #177 Program Fund Allocation — matching deltas (also update `prompts/programfundallocation.md`)

The requester FE (`crm/casemanagement/program/program-funding-sources.tsx`) already has a "Donation Purpose Funds" section + `ProgramDonationPurposePicker`. Deltas:
- **Purpose-funded cards get the "awaiting allocation" treatment** (mirror the grant-funded branch): while PENDING show "Awaiting allocation" instead of a self-Approve button (the BE `CanApprove` now returns false — R2.5d); once APPROVED show the read-only `AllocatedAmount`.
- **Pool-position strip on purpose-funded cards** (mirror `GrantFundPositionStrip`): a compact read-only strip **Raised · Committed · Available** fed by the new `DONATION_PURPOSE_FUNDING_REQUESTS_QUERY(donationPurposeId)` — so staff see how much the purpose still has before the owner commits. Render in allocate mode only. Add a new `DonationPurposeFundPositionStrip` sub-component.
- **`committed` for purpose-funded** = `AllocatedAmount` (BE R2.5d), not `ExpectedAnnualAmount`.

### R2.8 — BE→FE contract (§⑩ delta)

| Kind | Name | Args | Returns |
|------|------|------|---------|
| Query (NEW) | `donationPurposeFundingRequests` | `donationPurposeId: Int!` | `BaseApiResponse<DonationPurposeFundingRequestsDto>` (header rollup + `[DonationPurposeFundingRequestRow]`) |
| Mutation (NEW) | `allocateDonationPurposeToFundingSource` | `fundingSourceId: Int!, allocatedAmount: Decimal!` | `data: { fundingSourceId, allocatedAmount }` |

Wire into `Base.API/EndPoints/Donation/Queries/DonationPurposeQueries.cs` + `.../Mutations/DonationPurposeMutations.cs` (keep ALL existing fields — do NOT rename). New DTOs live in `Base.Application/Schemas/DonationSchemas/DonationPurposeSchemas.cs`.

### R2.9 — File manifest (§⑧ delta)

**BE (new):** `DonationPurposes/Queries/GetDonationPurposeFundingRequests.cs`, `DonationPurposes/Commands/AllocateDonationPurposeToFundingSource.cs` (+validator), optional shared `DonationPurposeRaisedHelper.cs`. **BE (edit):** `FundingSourceLifecycle.cs` (reject `DonationPurposeId != null` in ApproveFundingSourceHandler), `SaveProgramFundingAllocation.cs` (TRANSFERRED cap for purpose-funded), `GetProgramFundingAllocation.cs` (committed + CanApprove gate), `GetDonationPurposeDetail.cs` (extract raised calc to helper — optional), `DonationPurposeQueries.cs` + `DonationPurposeMutations.cs` (endpoints), `DonationPurposeSchemas.cs` (new DTOs). **No migration.** **PREREQUISITE (user-owned):** `UNITTYPE=DONATIONPURPOSE` MasterData seed + node backfill (R2.1).
**FE (new):** `.../donationpurpose/donation-purpose-fund-requests.tsx`, `.../donation-purpose-allocate-modal.tsx`, GQL query+mutation docs, DTOs in `donation-service/`. **FE (edit):** `.../donationpurpose/detail-page.tsx` (mount the Fund Requests card), `crm/casemanagement/program/program-funding-sources.tsx` (purpose pool-strip + awaiting-allocation), barrels/entity-operations.

### R2.10 — Acceptance criteria (§⑪ delta)

- [ ] PREREQUISITE applied: `UNITTYPE=DONATIONPURPOSE` seeded; existing purposes have nodes; new-purpose create no longer throws; a purpose with settled donations shows non-zero Raised.
- [ ] Program links a Donation Purpose as a funding source (#177) → saves PENDING → the workbench shows "Awaiting allocation", **no self-Approve button**.
- [ ] Donation Purpose detail page → "Fund Requests" card lists that program with Ask + PENDING status + Allocate action; pool strip shows Raised / Committed / Available.
- [ ] Allocate full/partial ≤ Available (raised − committed) AND ≤ ask → source flips APPROVED, `AllocatedAmount` set, `ApprovedBy/Date` stamped; Committed rises, Available falls.
- [ ] Attempting to allocate > available raised cash → rejected server-side with the cash message.
- [ ] Program can then record TRANSFERRED ≤ `AllocatedAmount`; TRANSFERRED before allocation is blocked.
- [ ] Allocate `0` releases the reservation (only when nothing transferred).
- [ ] Detail page shows BOTH sides: "Donation Summary by Source" (collected-from) and "Fund Requests" (allocated-to).
- [ ] Sponsor-funded sources are unchanged (still self-approve).

### R2.11 — Special notes & known gaps (§⑫ delta)

- **R1 seed/backfill is the gate** — without the `DONATIONPURPOSE` unit-type + node backfill, Raised = $0 and nothing can be allocated (and purpose-create throws). Do this first.
- **Raised = settled cash only** (R1 semantics) — pledges count only paid installments; one-time online donations that persist no purpose undercount pre-R1-Phase-2 (R1 ISSUE-5/7). "Available to allocate" inherits these gaps.
- **Crowdfund reads $0** until `fund.CrowdFundDonations` is populated (R1 ISSUE-6) — the collected-from card shows it but expect $0.
- **No award/reservation concept** — deliberately cash-only (user decision). Do NOT port the grant's `AwardedAmount` reservation ceiling or `GrantFundReceipts`/`GrantExpenses` cash math.
- **Sponsor deferred** — `SponsorContactId != null` sources keep program self-approve (ISSUE-8). The allocate command + guards must test `DonationPurposeId`, never a generic "non-grant".
- **Do NOT** add a schema column or migration — `ProgramFundingSource` already carries everything.
- **Do NOT rename** existing DonationPurpose queries/mutations.

### R2.12 — Current-code verification (re-reviewed 2026-07-09, after grant fixed/ongoing-period work merged)

Re-verified the live grant flow before building. The recent "program fixed vs ongoing period" change is fully absorbed by this plan — but note two build-critical facts:

1. **Fixed/ongoing = `Program.ProgramTypeId`** → MasterData `PROGRAMTYPE`, values `ONGOING` (no end date) / `FIXEDTERM` (hard start+end). **No `IsOngoing`/period column, no stored term** — term-years are *derived from `StartDate`/`EndDate`* by `ProgramFundingMath.ComputeTermYears`. The ask ceiling branches in exactly ONE place: `ProgramFundingMath.ComputeTermTotalAsk(source, source.Program)` = `annual` for ONETIME cadence **or** ONGOING type; `annual × ComputeTermYears` for FIXEDTERM-recurring. **Reuse this helper verbatim** in the purpose allocate command (§⑮.5a guard 3) and inbox rows (§⑮.4) — do NOT fork the math. It's `internal static` in `Base.Application/Business/CaseBusiness/Programs/ProgramFundingMath.cs`; the purpose command is in the same assembly, so the call compiles. Inbox rows must still surface `termYears` (`ComputeTermYears`) + `programTypeCode` (`Program.ProgramType.DataValue`) exactly as `GetGrantFundingRequests` does, so the FE can show the term basis.

2. **⚠ §⑮.5c divergence from grant — CAP, do NOT EXCLUDE.** The live `SaveProgramFundingAllocation.SyncFundingTransactions` **entirely skips** grant-funded sources (`if (isApproved && !row.GrantId.HasValue)`, ~L162) because grant transfers are recorded on the *Grant* screen (`RecordProgramFundingTransfer`), and running the diff-sync would soft-delete them. **The cash-only purpose model has NO purpose-side transfer surface** — purpose→program transfers stay on the **program** screen (#177 workbench). Therefore the purpose branch must **remain inside** `SyncFundingTransactions` (NOT be excluded like grant), but change its cap: for `DonationPurposeId != null`, cap `Σ scheduled ≤ AllocatedAmount` (the committed amount) and block any transfer while `AllocatedAmount == null`. Current code caps non-grant sources at `ExpectedAnnualAmount` — for purpose-funded that must become `AllocatedAmount`. Do NOT copy the grant `!row.GrantId.HasValue` exclusion onto DonationPurpose or transfers become impossible.

3. **Exact edit anchors confirmed:** `FundingSourceLifecycle.cs` ~L41-42 (add `|| source.DonationPurposeId.HasValue` to the grant self-approve reject); `GetProgramFundingAllocation.cs` ~L141 `committed` ternary (widen to `s.GrantId != null || s.DonationPurposeId != null ? CommittedAmount : ExpectedAnnualAmount`) + ~L150 `CanApprove` (append `&& s.DonationPurposeId == null`). `AllocateGrantToFundingSource.cs` lives at `Base.Application/Business/GrantBusiness/Grants/UpdateCommand/`; `GetGrantFundingRequests.cs` at `.../Grants/GetFundingRequestsQuery/` — mirror both into the DonationPurpose namespace. `AllocatedAmount` was added by migration `20260708065411_Add_AllocatedAmount_To_ProgramFundSource` (already present — no new migration).

### § R2 Known Issues (seed the §⑬ table on build)

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-8 | Low | Scope | Sponsor (`SponsorContactId`) allocation-from-source is out of R2 scope — sponsor sources keep program self-approve. Future revision mirrors R2 for sponsor. |
| ISSUE-9 | High | Prerequisite | `UNITTYPE=DONATIONPURPOSE` MasterData + node backfill not yet in DB (verified 2026-07-09, `OrganizationalUnit-sqlscripts.sql` seeds only HQ/REG/BR/SU). Blocks Raised (=0) and purpose-create (throws). User-owned seed + backfill. |
| ISSUE-10 | Medium | Coverage | "Available to allocate" = R1 settled raised cash, which undercounts until R1 Phase-2 channel wiring (R1 ISSUE-5) + Crowdfund pipeline (ISSUE-6) land. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | Medium | Data model | `DonationCategory` entity has no `DonationGroupId` FK — mockup-implied Category→Group auto-fill cannot be achieved within ALIGN scope. Shipped as two independent ApiSelectV2 dropdowns. Permanent fix: add `DonationGroupId` FK to `DonationCategory` entity + data migration to populate it from existing Purpose rows + update `DonationCategoryResponseDto` to expose the nav. | OPEN |
| ISSUE-2 | 1 | High | DB migration | Entity relaxes `StartDate`, `TargetAmount`, `Description` to nullable in C#; existing Postgres columns in `fund."DonationPurposes"` may still be `NOT NULL`. A migration (`ALTER COLUMN ... DROP NOT NULL`) is required before `dotnet build` runs migrations or before the screen is used against the live DB. | OPEN |
| ISSUE-3 | 1 | Low | Aggregation scope | `RaisedAmount` subquery currently sums only `fund."RecurringDonationScheduleDistributions"` — the only child table presently carrying a `DonationPurposeId` FK. When GlobalDonation / BulkDonation / ChequeDonation add direct `DonationPurposeId` references, the handler subquery must be extended to union those sources. | SUPERSEDED by R1 (attribution moved to org-unit node model — see §⑭) |
| ISSUE-4 | R1-plan | High | Attribution model | Org-unit→purpose attribution requires each purpose to own a **dedicated** OrganizationalUnit node (1:1). Today `OrganizationalUnitId` is an optional, user-picked *shared* department, so attribution is non-unique. R1 Phase 1 fixes purpose-create + backfill; **`GetDonationPurposeById` currently returns `RaisedAmount = 0`** (handler never computes it). | OPEN (R1 Phase 1) |
| ISSUE-5 | R1-plan | Medium | Pipeline coverage | Donation channels write `GlobalDonationDistribution.OrganizationalUnitId` from the value chosen at entry, NOT from the selected purpose's node. Until R1 **Phase 2** wires each channel (P2P/Crowdfund/Online/Pledge/Recurring) to set the distribution org unit = the purpose's node, only donations already routed to that node count toward Raised. | OPEN (R1 Phase 2) |
| ISSUE-6 | R1-plan | Medium | Source gap | Crowdfund summary reads `$0` — `fund."CrowdFundDonations"` is never populated (crowdfund donations stay in `OnlineDonationStaging`; `ConfirmCrowdFundDonation` defers promotion and `ResolveOnlineDonationStaging` has no CrowdFund backfill). | OPEN |
| ISSUE-7 | R1-plan | Low | Source gap | One-time Online donations persist no purpose (only recurring-flagged resolves seed a `RecurringDonationScheduleDistribution`), so the Online source undercounts pre-Phase-2. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

> _[7 older session entries trimmed to save tokens — full history in git: `git log -p -- donationpurpose.md`. Most recent 5 kept below.]_

### Session 8 — 2026-07-10 — FIX (R2 §⑮.10) — Record Transfer: per-CHANNEL cash ceiling (aggregate ceiling was too loose)

- **Bug (reported)**: user attributed a transfer to the **Online Donation** channel while that channel had **raised nothing** for the purpose, yet it was accepted. Session 7's guard only checked the **aggregate** pool (`Raised − Σ transferred`), so any channel split passed as long as the whole purpose had cash — a lie at the channel level. *"online donation not have money for that particular donation purpose but its allocated — its wrong."*
- **Key discovery** (reverses the §⑮.9 assumption that channels have no reliable flag): each channel **is** computable against settled cash. A distribution's parent `GlobalDonation` carries: `OnlineDonationPageId` (→ ONLINE), `P2PCampaignPageId` (→ CROWDFUND); and a donation settling a `PledgePayment` installment (`PledgePayment.GlobalDonationId`, scoped to the purpose via `Pledge.DonationPurposeId`) → PLEDGE; **GENERAL** = the remainder (so the four always sum to Raised). Precedence Online→Crowdfund→Pledge→General resolves the rare overlap (a pledge paid online counts as Online — where the cash physically arrived).
- **Fix = per-channel cash ceiling** (each split ≤ that channel's `Raised − already-transferred`; summed over the four this is exactly the old aggregate ceiling, only tighter):
  - **BE** `DonationPurposeRaisedHelper.cs` — new `ComputeChannelRaisedAsync(dbContext, orgUnitId, purposeId, ct)` returning `ChannelCash {Pledge,Online,Crowdfund,General}` (+`ForChannel(code)`). Distributions projected with parent flags, materialised, classified in memory; pledge donation-ids fetched separately.
  - **BE** `RecordDonationPurposeFundingTransfer.cs` guard **(g)** rewritten: computes `channelRaised` (helper) + `channelTransferred` (Σ `ProgramFundingTransactionSource.Amount` grouped by channel across the purpose's TRANSFERRED txns, nav `Transaction`), then per-split throws `"{Channel} has only {avail} available…"` if `split.Amount > channelAvailable`.
  - **BE** `GetDonationPurposeFundingRequests.cs` header — new `ChannelCash` (per-channel available floored at 0) via the same two computations; `DonationPurposeChannelCashDto` added to `DonationPurposeSchemas.cs`.
  - **FE** `DonationPurposeFundingRequestDto.ts` (+`DonationPurposeChannelCashDto`, header `channelCash`), `DonationPurposeQuery.ts` (header `channelCash{ pledge/online/crowdfund/general Available }`).
  - **FE modal** — new `channelAvailable` prop → per-channel `channelCap`; each channel input shows **"{amt} available" / "no funds"**, is **capped (`max`) and disabled at 0**; Zod `superRefine` rejects any split over its channel cap; **seed/full-remaining/auto-attribute now greedy-fill by cap** (Pledge→Online→Crowdfund→General) instead of dumping into General, so the default split is always valid AND channel-legal. `fund-requests.tsx` passes `channelAvailable={header.channelCash}`.
- **Build**: FE `npx tsc --noEmit` → **0 errors** whole project. BE build **left to user** (per instruction). No schema change, no new migration (still only the §⑮.9 `ProgramFundingTransactionSource` table).

### Session 9 — 2026-07-10 — ENHANCEMENT (R2 §⑮.11) — Tabbed detail (Overview / Fund Requests / Utilization) + allocate "track-before-next" gate

- **Ask (user)**: (1) *"handle Record Transfer enable/disable — if allocated but not tracked, no need to allow next fund allocation"* (refer grant); (2) restructure the purpose detail into **tabs like grant** — Overview / Fund Request details / Utilization — with proper money math (**collected / used / transferred / utilized / pending on the program-managing side**).
- **Gate (both BE + FE, no schema change)** — "one-at-a-time" cash discipline, forces order **Allocate → Record Transfer → Allocate**:
  - **BE** `AllocateDonationPurposeToFundingSource.cs` guard **(6)**: `currentAllocated = source.AllocatedAmount; untransferred = currentAllocated − alreadyTransferred`; block when `command.allocatedAmount > currentAllocated && untransferred > 0` (*"already has {X} allocated but only {Y} transferred — record the outstanding transfer before allocating more"*). First allocation (current 0) + top-ups after full transfer + non-increasing corrections all pass.
  - **FE** `donation-purpose-fund-requests.tsx`: `hasUntrackedAllocation = (allocated − transferred) > 0` → **Allocate disabled** with `{amt} allocated but not yet transferred…` tooltip; Record Transfer stays enabled (its exact complement). The two actions are now mutually exclusive per row.
- **Tabs** — `detail-page.tsx` reworked: header + KPI tiles (Goal/Raised/Remaining/%) + progress bar stay **above** a `DetailTabsBar` (mirrors grant `TabsBar`; `cn`-based). Three tabs:
  - **Overview** — the old body (Program Details, Donation Summary by Source, Fund Details, Donation History).
  - **Fund Requests** — existing `DonationPurposeFundRequests` (pool strip + requests table + Allocate/Record-Transfer). Tab shows a `pendingCount` badge.
  - **Utilization** — NEW `donation-purpose-utilization.tsx`.
- **Utilization tab** (NEW file `donation-purpose-utilization.tsx`) — reads the **same** `DONATION_PURPOSE_FUNDING_REQUESTS_QUERY` (Apollo cache-dedupes; **no new BE surface** — every figure is already in the header rollup + rows):
  - 5 KPI tiles (solid `bg-X-600` + white icons): **Collected / Committed / Available / Transferred / Utilized**.
  - **Fund-flow segmented bar** over the raised pool — 4 bands that sum to Collected: **Utilized** (teal) + **With managers** (amber, = transferred−drawn, *pending on program side*) + **Committed-not-transferred** (violet, = committed−transferred) + **Uncommitted** (slate) — with legend + amounts. Caption states purpose funds are used **only through programs — no direct spend** (donation purpose has no grant-style direct-spend concept).
  - **Utilization by Program** table: Allocated / Transferred / Utilized / With Mgr / Balance(alloc−drawn) + totals footer.
- **Build**: FE `npx tsc --noEmit` → **0 errors** whole project. BE build **left to user** (guard is one added block, no signature/schema change, no migration).
- **Files**: BE edit `AllocateDonationPurposeToFundingSource.cs`. FE new `donation-purpose-utilization.tsx`; FE edit `detail-page.tsx` (tabs), `donation-purpose-fund-requests.tsx` (allocate gate). No DTO/GQL change.

### Session 10 — 2026-07-14 — ENHANCEMENT (DBA utility) — FK-safe purpose teardown script — COMPLETED

- **Ask (user)**: mirror the program cleanup script (`DatabaseScripts/Seed/cleanup_case_management_by_program.sql`) for a Donation Purpose — "delete that record and those mapped childs also", FK-safe.
- **Delivered**: `PSS_2.0_Backend/DatabaseScripts/Seed/cleanup_donation_purpose.sql` — a `DO $cleanup$` block, scope by `v_purpose_id` (or `v_purpose_code`). Prints a per-table **preflight report**, then a **transactional guard** that ABORTS by default when cash-bearing rows exist (upholds the §④ soft-delete-only rule); `v_force := true` overrides. Deletes in FK-safe order: **grandchildren** (AmbassadorCollectionDistributions, ContactCertificates, PledgePayments, CrowdFundDonations; NULL OnlineDonationStagings.CrowdFundId) → **children/direct FKs** (ContactDonationPurposes, AmbassadorCollections [col `DonationTypeId`], Pledges, CrowdFunds, CampaignDonationPurposes, OrganizationalUnitDonationPurposes, RecurringDonationScheduleDistributions, AccountingAccountMappings) → **NULL nullable config refs** (CertificateTemplates, ReceiptTemplates, P2PCampaignPages, ProgramFundingSource, ScheduledReports, Products.PurposeId; `v_null_config_refs`) → **the purpose row** + **optional dedicated org-unit node** (`v_drop_node`, guards settled GlobalDonationDistributions).
- **FK map verified from EF configs** (all referencers are `DeleteBehavior.Restrict`, so nothing cascades — every child cleared explicitly). Correction vs earlier note: `fund.AmbassadorCollections.DonationTypeId` **is** a real FK → `fund.DonationPurposes` (not a MasterData ref).
- **Deviations**: none. **No code/schema/migration change** — standalone operational SQL. Screen #2 code untouched; status stays COMPLETED.
- **Known issues opened/closed**: none.
- **Next step**: user runs the script against a target purpose (starts with `v_force=false` to read the preflight before deciding).

### Session 11 — 2026-07-14 — ENHANCEMENT (DBA utility) — teardown now includes the dedicated org-unit node — COMPLETED

- **Ask (user)**: "organization unit also we need to include and delete" — the purpose's dedicated `app.OrganizationalUnits` node (referenced by `DonationPurpose.OrganizationalUnitId`) should be torn down with the purpose, not left behind under the default-OFF flag.
- **Delivered** (edit to `cleanup_donation_purpose.sql`): flipped `v_drop_node` default `false → true` (node deleted by default; set `false` to keep). Rewrote Phase D node-drop as a proper **FK-safe dedicated-node teardown** with a hard **safety guard** — the node is dropped ONLY when it is a genuine per-purpose node: (1) `UnitTypeId` = the `UNITTYPE/DONATIONPURPOSE` master-data id (matches `CreateDonationPurpose.BuildOwnOrganizationalUnitAsync`), (2) no OTHER `DonationPurpose` points at it, (3) no child org units are parented to it, (4) no settled `GlobalDonationDistributions` / `GlobalDonations` at it unless `v_force`. Any failed check → `RAISE NOTICE … KEPT` (never nukes a shared branch). Teardown order: node distributions → NULL `GlobalDonations.OrganizationalUnitId` → node junctions (`OrganizationalUnitDonationPurposes` / `OrganizationalUnitPaymentModes` / `OrganizationalUnitStaffs`) → the node row (D2–D7 notices).
- **Verified from EF models**: `OrganizationalUnit` is a full org-tree entity (self-ref `ParentUnitId`, staff/payment/campaign/donation nav), so the type+ownership guard is essential — the purpose node is created as a root `DONATIONPURPOSE` unit 1:1 with the purpose. Table/column names (`sett.MasterDatas`/`MasterDataTypes`, `app.OrganizationalUnit*`, `fund.GlobalDonations.OrganizationalUnitId`) confirmed against the model files. Block balance re-checked (1 DO/END, 7 IF/7 END IF).
- **Deviations**: none. **No code/schema/migration change** — standalone operational SQL. Screen #2 code untouched; status stays COMPLETED.
- **Known issues opened/closed**: none.
- **Next step**: user runs with `v_force=false` first — the node is kept + a reason printed if it isn't a clean dedicated node or still carries cash.

### Session 12 — 2026-07-15 — ENHANCE — Tenant-configurable code generation (DONATIONPURPOSE) — COMPLETED

- **Scope**: mirror the #3/#4 NumberSequence rollout on Donation Purpose — auto-generate `DonationPurposeCode` per tenant on Create. Because `CreateDonationPurpose.BuildOwnOrganizationalUnitAsync` copies `DonationPurposeCode` onto the purpose's dedicated `app.OrganizationalUnits` node (`UnitCode`), the **same generated code is shared** by the purpose AND its parent org-unit node — one sequence, two records. Generation is placed **before** the own-node build so the shared value propagates.
- **Files touched**:
  - BE: `DonationBusiness/DonationPurposes/Commands/CreateDonationPurpose.cs` — handler calls `NumberSequenceGenerator.GenerateAsync(dbContext, companyId, "DONATIONPURPOSE", DateTime.UtcNow, ct)` inside the existing execution-strategy transaction, right after OrderBy and before `BuildOwnOrganizationalUnitAsync`; validator drops `ValidatePropertyIsRequired`/`ValidateUniqueWhenCreate` on `DonationPurposeCode` (length check retained). Update path unchanged.
  - FE: `gql-mutations/donation-mutations/DonationPurposeMutation.ts` — CREATE `$donationPurposeCode` relaxed `String!` → `String` (server-generated); Update stays `String!`.
  - DB: `sql-scripts-dyanmic/NumberSequenceEntityType-BulkRegister-sqlscripts.sql` (+`DONATIONPURPOSE` → `fund.DonationPurposes.DonationPurposeCode`, prefix `DP`, pattern `{PREFIX}-{SEQ:000}`) and `NumberSequenceConfig-CounterBackfill-sqlscripts.sql` (+`DONATIONPURPOSE`, match prefix `DP-`).
- **Build**: `dotnet build Base.Application.csproj` → **0 errors** (551 warnings, pre-existing).
- **Deviations from spec**: none — §④ "DonationPurposeCode unique per Company" is now enforced by the generator's per-tenant counter + backfill instead of a client-boundary uniqueness rule.
- **Known issues opened/closed**: none.
- **Next step**: user re-runs the two seed scripts (BulkRegister FIRST, then CounterBackfill) per environment before Create is used — the generator throws if the `DONATIONPURPOSE` eligibility row is absent.
