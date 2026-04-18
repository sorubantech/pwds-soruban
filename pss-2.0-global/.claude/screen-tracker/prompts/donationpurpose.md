---
screen: DonationPurpose
registry_id: 2
module: Fundraising
status: COMPLETED
scope: ALIGN
screen_type: MASTER_GRID
complexity: Medium
new_module: NO
planned_date: 2026-04-18
completed_date: 2026-04-18
last_session_date: 2026-04-18
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

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | Medium | Data model | `DonationCategory` entity has no `DonationGroupId` FK — mockup-implied Category→Group auto-fill cannot be achieved within ALIGN scope. Shipped as two independent ApiSelectV2 dropdowns. Permanent fix: add `DonationGroupId` FK to `DonationCategory` entity + data migration to populate it from existing Purpose rows + update `DonationCategoryResponseDto` to expose the nav. | OPEN |
| ISSUE-2 | 1 | High | DB migration | Entity relaxes `StartDate`, `TargetAmount`, `Description` to nullable in C#; existing Postgres columns in `fund."DonationPurposes"` may still be `NOT NULL`. A migration (`ALTER COLUMN ... DROP NOT NULL`) is required before `dotnet build` runs migrations or before the screen is used against the live DB. | OPEN |
| ISSUE-3 | 1 | Low | Aggregation scope | `RaisedAmount` subquery currently sums only `fund."RecurringDonationScheduleDistributions"` — the only child table presently carrying a `DonationPurposeId` FK. When GlobalDonation / BulkDonation / ChequeDonation add direct `DonationPurposeId` references, the handler subquery must be extended to union those sources. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-18 — BUILD — COMPLETED

- **Scope**: Initial full ALIGN build from PROMPT_READY prompt. Entity, DTOs, query handlers, mappings, validators, FE DTO, GQL query/mutation, data-table, progress-bar renderer, DB seed, and obsolete route cleanup.
- **Files touched**:
  - BE (8 modified, 1 created):
    - `Base.Domain/Models/DonationModels/DonationPurpose.cs` (modified — `StartDate`/`TargetAmount`/`Description` → nullable)
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/DonationPurposeConfiguration.cs` (modified)
    - `Base.Application/Schemas/DonationSchemas/DonationPurposeSchemas.cs` (modified — `OrganizationalUnit` nav + `RaisedAmount`)
    - `Base.Application/Business/DonationBusiness/DonationPurposes/Queries/GetDonationPurpose.cs` (modified — Include OrgUnit, `RaisedAmount` post-projection)
    - `Base.Application/Business/DonationBusiness/DonationPurposes/Queries/GetDonationPurposeById.cs` (modified — Include OrgUnit)
    - `Base.Application/Mappings/DonationMappings.cs` (modified — explicit `OrganizationalUnit` + `RaisedAmount` mapping)
    - `Base.Application/Business/DonationBusiness/DonationPurposes/Commands/CreateDonationPurpose.cs` (modified — nullable validators + conditional `StartDate when TargetAmount > 0`)
    - `Base.Application/Business/DonationBusiness/DonationPurposes/Commands/UpdateDonationPurpose.cs` (modified — same as Create)
  - FE (6 modified, 1 created, 2 deleted):
    - `src/domain/entities/donation-service/DonationPurposeDto.ts` (modified — removed `currency` nav, added `raisedAmount` + `organizationalUnit.unitName`)
    - `src/infrastructure/gql-queries/donation-queries/DonationPurposeQuery.ts` (modified — reformat, add OrgUnit nav + raisedAmount + companyId; uses `unitName`)
    - `src/infrastructure/gql-mutations/donation-mutations/DonationPurposeMutation.ts` (modified — optional inputs)
    - `src/presentation/components/page-components/setting/donationconfig/donationpurpose/data-table.tsx` (modified — all CRUD flags → true, `enableSearch` added)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/target-raised-progress.tsx` (created — 4-band progress bar, Tailwind tokens)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (modified — export renderer)
    - `src/presentation/components/custom-components/data-tables/{advanced,basic,flow}/data-table-column-types/component-column.tsx` (modified — import + register `target-raised-progress` switch case in all 3)
    - `src/app/[lang]/crm/organization/donationpurpose/` (deleted — obsolete route)
    - `src/app/[lang]/organization/donationsetup/donationpurpose/` (deleted — obsolete route)
  - DB (1 created):
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/DonationPurpose-sqlscripts.sql` (created — 7 steps: Menu, MenuCapabilities, RoleCapabilities, Grid, Fields, GridFields, GridFormSchema)
- **Deviations from spec**:
  1. **Category→Group auto-fill REMOVED.** Spec § ⑥ / ④ described a readonly Group field auto-populated from the selected Category. Implementation impossible: `DonationCategory` entity has no `DonationGroupId` FK — the Category/Group relationship exists only on `DonationPurpose` itself. Shipped: `donationGroupId` is a normal independent `ApiSelectV2`. See ISSUE-1.
  2. **OrganizationalUnit display field is `unitName`, not `organizationalUnitName`.** The OrganizationalUnit entity uses `UnitName`. Spec § ③/⑥ had the wrong field name. GQL query + DTO + DB seed grid column all use `unitName`.
  3. **Additional BE fields relaxed to nullable**: `TargetAmount` and `Description` — spec only explicitly required relaxing `StartDate`, but mockup shows all three as optional. This is a consistency improvement, not a divergence.
  4. **RaisedAmount source table**: uses `RecurringDonationScheduleDistributions` (the only existing table with `DonationPurposeId` FK). Spec § ⑫ suggested the BE dev verify this — choice documented.
- **Known issues opened**: ISSUE-1 (Category→Group auto-fill data-model gap), ISSUE-2 (DB column nullability migration required), ISSUE-3 (RaisedAmount aggregation scope limited to one source table)
- **Known issues closed**: None
- **Next step**: (empty — COMPLETED; manual verification pending per checklist)
