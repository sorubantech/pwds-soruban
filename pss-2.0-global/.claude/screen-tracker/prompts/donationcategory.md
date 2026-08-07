---
screen: DonationCategory
registry_id: 3
module: Fundraising
status: COMPLETED
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
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/setting/donationconfig/donationcategory`
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete)
- [ ] Grid columns render correctly (including "Group" badge + "Purposes" count link)
- [ ] RJSF modal form renders all 5 fields with validation
- [ ] FK dropdown loads (DonationGroup via ApiSelectV2)
- [ ] Per-row aggregation `purposesCount` shows correct value
- [ ] Inactive rows are dimmed but remain visible
- [ ] DB Seed — menu visible under CRM → Organization (MODULE_MENU_REFERENCE), grid + form schema render

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: DonationCategory
Module: Fundraising (Setup)
Schema: `fund`
Group: Donation (`DonationModels` / `DonationConfigurations` / `DonationSchemas` / `DonationBusiness` / `Donation` endpoints)

Business: DonationCategory is the **middle tier** of the three-level fund allocation hierarchy (Group → Category → Purpose). Categories like "Education Programs", "Health Services", "Infrastructure Projects", "Emergency Response" bucket related donation purposes under a broader theme, and each category rolls up to a parent DonationGroup (e.g., "Program Funds", "Capital Funds", "Operating", "Special Funds"). NGO admins use this screen to manage the reference list; fundraising managers rely on it when setting up Purposes (screen #2) because the Category field there is sourced from this table. The "Purposes" count link in this grid tells the admin at a glance how many active Purposes currently reference each Category.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Entity already exists in `fund` schema — fields below are the **target state after ALIGN**. Current BE is missing `DonationGroupId`; current EF config makes `Description` required. Both must change.

Table: `fund."DonationCategories"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| DonationCategoryId | int | — | PK | — | Primary key (existing) |
| DonationCategoryCode | string | 100 | YES | — | Unique per Company (existing) |
| DonationCategoryName | string | 100 | YES | — | Display name (existing) |
| **DonationGroupId** | int | — | **YES** | fund.DonationGroup | **NEW — must be added to entity, EF config, DTO, mutation, query, and mockup form shows this as a required dropdown.** |
| Description | string? | 1000 | **NO** | — | **Was required — relax to optional (mockup shows no red star).** |
| OrderBy | int | — | NO | — | Display order (existing) |
| CompanyId | int? | — | NO | app.Company | FK (existing — set from HttpContext) |
| IsActive | bool | — | inherited | — | Inherited from Entity base |

**Child collections** (already on entity — no change):
- `DonationPurposes` — 1:Many (used for `PurposesCount` aggregation — see § ⑥)

**Computed/aggregated (NEW for grid display — not persisted):**

| Field | Type | Source |
|-------|------|--------|
| PurposesCount | int | `COUNT(fund."DonationPurposes" WHERE DonationPurposes.DonationCategoryId = row.DonationCategoryId AND DonationPurposes.IsDeleted = false)` — LINQ `dbContext.DonationPurposes.Count(...)` per row in `GetDonationCategoriesQueryHandler` |

> **Migration note**: Adding `DonationGroupId` as a **NOT NULL** column to an existing table requires a data-migration step: assign a sensible default (e.g. pick the most common `DonationGroupId` from existing `DonationPurposes.DonationGroupId` values grouped by `DonationCategoryId`, or create a "Unassigned" group) before applying the `NOT NULL` constraint. BE dev MUST surface this in the migration.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| DonationGroupId | DonationGroup | `Base.Domain/Models/DonationModels/DonationGroup.cs` | `donationGroups` (operation name `GetDonationGroups`) | donationGroupName | DonationGroupResponseDto |

> **NAMING NOTE (same as DonationPurpose)**: Existing queries in this project do NOT follow the `GetAll{Entity}List` convention used in the MASTER_GRID template — they use `Get{Entities}` (plural) and expose a `donation{Entities}` GQL field. **Keep existing names during ALIGN — do not rename**, or other screens (#1, #2 completed, #5, #6, #7, etc.) will break. Only the FE DTO / GQL query bodies and mutation argument list for THIS screen need to change.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `DonationCategoryCode` is unique per CompanyId (already enforced via `HasIndex(Code, CompanyId, IsActive).IsUnique()` — keep). `ValidateUniqueWhenCreate` + `ValidateUniqueWhenUpdate` already on validators.
- `DonationCategoryName` should be unique per DonationGroup within CompanyId (add this validator — mockup distinct names per group).

**Required Field Rules:**
- DonationCategoryCode, DonationCategoryName, **DonationGroupId** are mandatory
- Description and OrderBy are optional (current BE has Description required — relax)

**Conditional Rules:**
- None — flat master entity.

**Business Logic:**
- Soft-delete only (`IsActive = false`) — never hard-delete if any DonationPurpose rows reference this category (`DonationPurposes.DonationCategoryId` FK constraint; show friendly error "Cannot delete: N purposes reference this category — deactivate instead")
- Inactive categories must NOT appear in the DonationPurpose `Category` dropdown (Purpose screen #2) — only `IsActive = true`
- CompanyId is set from HttpContext on create (multi-tenant scope)
- **Must validate `DonationGroupId` exists via `ValidateForeignKeyRecord`** (new validator line)

**Workflow**: None (flat master entity).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered decisions.

**Screen Type**: MASTER_GRID
**Type Classification**: Type 1 — simple master/reference with one FK + per-row aggregation
**Reason**: flat entity, 1 FK (DonationGroup), no child grid, single grid + modal form. Aggregation column (PurposesCount) + the new FK add Medium complexity.

**Backend Patterns Required:**
- [x] Standard CRUD (entity + 11 files exist — verify and align; ADD DonationGroupId throughout)
- [ ] Nested child creation — NO
- [x] Multi-FK validation (ValidateForeignKeyRecord × 1: DonationGroup) — NEW
- [x] Unique validation — DonationCategoryCode per CompanyId (existing), DonationCategoryName per DonationGroupId+CompanyId (NEW)
- [x] Per-row aggregation — PurposesCount via LINQ per-row count in `GetDonationCategoriesQueryHandler`
- [ ] File upload — NO

**Frontend Patterns Required:**
- [x] AdvancedDataTable
- [x] RJSF Modal Form (driven by GridFormSchema from DB seed)
- [ ] File upload — NO
- [ ] Summary cards — NO (mockup has no KPI cards above Categories grid — the tab-nav count badges are out of scope per § ⑥)
- [x] Grid aggregation column — "Purposes" count link (computed via `purposesCount`)
- [ ] Info / side panel — NO
- [ ] Drag-to-reorder — NO (OrderBy is a numeric input, not drag UI)
- [x] **Click-through filter**: "Purposes" count link navigates to DonationPurpose grid pre-filtered by this category (optional — see § ⑥ User Interaction Flow step 8)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer. Extracted directly from `html_mockup_screens/screens/fundraising/donation-purposes.html` TAB 2 "Donation Categories" — this IS the design spec.
> **Scope reminder**: The mockup has 3 tabs (Purposes / Categories / Groups). Only the **Categories tab** is in scope for this prompt. Purposes (#2 — COMPLETED) and Groups (#4) are separate registry screens with their own menu routes. Tab navigation UI is OUT of scope here — render as a standalone grid.

### Grid/List View

**Grid Columns** (in display order — matches mockup Tab 2 exactly):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | # | (row index) | number | 40px | NO | Row number only — rendered by grid |
| 2 | Code | donationCategoryCode | badge (monospace pill — `purpose-code` style) | 120px | YES | e.g. "Education", "Health" |
| 3 | Category Name | donationCategoryName | text (bold) | auto | YES | Primary column, e.g. "Education Programs" |
| 4 | Group | donationGroup.donationGroupName | badge (purple/amber/blue/pink — color varies by group) | 160px | YES | From FK navigation |
| 5 | Purposes | purposesCount | count link (teal, underlines on hover — `count-link` style) | 100px | YES | **Clickable** — navigates to `/{lang}/setting/donationconfig/donationpurpose?donationCategoryId=<id>` to filter Purpose grid by this category |
| 6 | Description | description | text (truncated if long) | auto | NO | `—` when null |
| 7 | Order | orderBy | numeric badge (`order-num`) | 60px | YES | 26×26 circle badge |
| 8 | Actions | — | icon buttons | 100px | NO | Edit (pen), Delete (trash). If inactive → show only View (eye) |

> **Status column is NOT in the mockup** for the Categories tab, but `isActive` is still tracked on the entity. Inactive rows dim via `opacity: 0.6` row className (consistent with DonationPurpose). The Toggle action can be triggered from the modal form (isActive switch) or the grid action-icons row-menu.

**Search/Filter Fields**: donationCategoryCode, donationCategoryName, donationGroup.donationGroupName, description, isActive

**Grid Actions**: Add (top-right "New Category" button — note mockup shows a single "+ New Purpose" button that changes label on tab switch; since this screen is standalone, the button MUST read "+ New Category"), Edit (row), Toggle Active (via modal), Delete (row), Export (top-right `Export` button → calls standard AdvancedDataTable export)

**Grid-level behavior**:
- Inactive rows shown with `opacity: 0.6` (consistent with DonationPurpose screen precedent)
- Export button in page header → uses AdvancedDataTable built-in export

### RJSF Modal Form

> Modal size: `modal-md` (gradient teal header with folder icon per mockup). Fields driven by GridFormSchema in DB seed.
> **Mockup**: title "New Category" on create, "Edit Category" on edit. Footer has Cancel + "Save Category" (check icon).

**Form Sections** (single section, 1-column layout for simplicity — mockup shows single-column stacked except Display Order which is col-md-6):

| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | (no title — flat form) | 1-column mostly; Display Order is half-width | donationCategoryCode, donationCategoryName, donationGroupId, description, orderBy, isActive |

**Field Widget Mapping**:

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| donationCategoryCode | text | "e.g. Education" | required, max 100 | Unique per Company |
| donationCategoryName | text | "Enter category name" | required, max 100 | — |
| donationGroupId | ApiSelectV2 | "Select group..." | required | Query: `GetDonationGroups` (gql field `donationGroups`) → display `donationGroupName`. **NEW field — must appear in form.** |
| description | textarea | "Describe this category..." | optional, max 1000 | Rows=3. Full-width. |
| orderBy | number | "1" | int ≥ 0 | Default next available (e.g. "7" when 6 rows exist) |
| isActive | toggle switch | — | default `true` | Teal switch, label "Active". (Not shown in mockup modal but added for consistency with Purpose and to allow toggle from form.) |

### Page Widgets & Summary Cards

**Widgets**: NONE (mockup has no KPI cards above grid — only the tab nav, which is out of scope here)

**Layout Variant** (REQUIRED): `grid-only`
→ FE Dev uses **Variant A**: `<AdvancedDataTable>` with internal header. No `<ScreenHeader>` in page component. (Same precedent as DonationPurpose #2.)

### Grid Aggregation Columns

**Aggregation Columns**: ONE (the "Purposes" count link)

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Purposes | Count of DonationPurpose rows where `DonationPurposes.DonationCategoryId = row.DonationCategoryId` AND `IsDeleted = false` | `PurposesCount` (computed, int) | BE: In `GetDonationCategoriesQueryHandler`, after `ApplyGridFeatures`, project `PurposesCount = dbContext.DonationPurposes.Count(p => p.DonationCategoryId == row.DonationCategoryId && !p.IsDeleted)`. Exposed as `purposesCount` in `DonationCategoryResponseDto` and GQL. FE: custom cell renderer `CountLinkRenderer` that renders `<a href="/{lang}/setting/donationconfig/donationpurpose?donationCategoryId={row.donationCategoryId}">{purposesCount}</a>` — teal text with hover underline (matches `count-link` CSS in mockup). |

> **Implementation hint for BE dev**: EF Core supports this as a correlated subquery via `.Select(c => new DonationCategoryResponseDto { ..., PurposesCount = c.DonationPurposes.Count(p => !p.IsDeleted) })` using the existing navigation `DonationCategory.DonationPurposes`. This avoids a second query round-trip.

### Side Panels / Info Displays

**Side Panel**: NONE

### User Interaction Flow

1. User navigates to `/{lang}/setting/donationconfig/donationcategory` → grid loads with pagination
2. Clicks "New Category" (top-right) → modal opens (title: "New Category", gradient header)
3. Fills Category Code, Category Name → selects Group (ApiSelectV2) → optionally fills Description and Display Order → Save → Create mutation fires → grid refreshes → toast "Donation Category created"
4. Edit: clicks pen icon on row → modal opens pre-filled → fields editable → Save
5. Toggle Active: user flips isActive switch inside the modal form → Update mutation runs (OR use separate ActivateDeactivate mutation from grid row-action context menu) → status updates; inactive rows show at 0.6 opacity
6. Delete: clicks trash icon → confirm dialog → Delete mutation → if FK protected (DonationPurpose rows reference this), show "N purposes reference this — deactivate instead"
7. Export: clicks Export button (top-right) → CSV/Excel download via AdvancedDataTable export handler
8. Click-through filter: clicks "Purposes" count link on a row → navigates to `/{lang}/setting/donationconfig/donationpurpose?donationCategoryId=<id>` → DonationPurpose grid loads pre-filtered to that category's purposes. If the target route does not support this query-param filter yet, render the count as plain teal text (no anchor) and note in Known Issues.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer. Canonical reference: `ContactType` (MASTER_GRID). Closer precedent for this screen: **DonationPurpose (#2 COMPLETED)** — same schema, same group, same parent menu, same split FE route, same GQL naming convention.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | DonationCategory | Entity/class name |
| contactType | donationCategory | Variable/field names |
| ContactTypeId | DonationCategoryId | PK field |
| ContactTypes | DonationCategories | Table name, collection names |
| contact-type | donation-category | (not used — no dashes in current paths) |
| contacttype | donationcategory | FE folder, import paths |
| CONTACTTYPE | DONATIONCATEGORY | Grid code, menu code |
| corg | fund | DB schema |
| Corg | Donation | Backend group name |
| CorgModels | DonationModels | Namespace suffix |
| CONTACT | CRM_ORGANIZATION | Parent menu code |
| CRM | CRM | Module code |
| crm/contact/contacttype | setting/donationconfig/donationcategory | FE route path |
| corg-service | donation-service | FE entity folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer. ALIGN scope — **most files already exist**; list below covers which files to MODIFY vs leave alone.

### Backend Files (all exist — MODIFY only)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/DonationCategory.cs` | MODIFY: ADD `public int DonationGroupId { get; set; }` and `public DonationGroup DonationGroup { get; set; } = default!;`. Relax `Description` to `string?` (nullable). |
| 2 | EF Config | `.../Base.Infrastructure/Data/Configurations/DonationConfigurations/DonationCategoryConfiguration.cs` | MODIFY: change `Description` `.IsRequired()` → remove (make nullable). Add `builder.HasOne(o => o.DonationGroup).WithMany().HasForeignKey(o => o.DonationGroupId).OnDelete(DeleteBehavior.Restrict);`. Keep existing unique index; optionally add composite unique index `(DonationCategoryName, DonationGroupId, CompanyId, IsActive)` for the name-per-group rule. |
| 3 | DonationGroup inverse collection | `.../Base.Domain/Models/DonationModels/DonationGroup.cs` | MODIFY: ADD `public ICollection<DonationCategory> DonationCategories { get; set; } = default!;` so the inverse navigation exists (optional but cleaner). |
| 4 | Schemas (DTOs) | `.../Base.Application/Schemas/DonationSchemas/DonationCategorySchemas.cs` | MODIFY: ADD `DonationGroupId` (int) to Request + Response DTOs. ADD `DonationGroupDto? DonationGroup` nav on Response DTO. ADD `PurposesCount` (int) to Response DTO. Make `Description` nullable (`string?`). |
| 5 | Create Command | `.../Base.Application/Business/DonationBusiness/DonationCategories/Commands/CreateDonationCategory.cs` | MODIFY: add `ValidatePropertyIsRequired(x => x.donationCategory.DonationGroupId)`; add `ValidateForeignKeyRecord(x => x.donationCategory.DonationGroupId, _dbContext.DonationGroups, g => g.DonationGroupId)`; REMOVE `ValidatePropertyIsRequired(...Description)` (relax to optional); REMOVE `ValidateStringLength(...Description, 1000)` if it is no longer non-null — or keep max-length but drop required. Add uniqueness-of-name-per-group validator. Confirm CompanyId is set from HttpContext. |
| 6 | Update Command | `.../DonationCategories/Commands/UpdateDonationCategory.cs` | MODIFY: mirror Create validator changes. |
| 7 | Delete Command | `.../DonationCategories/Commands/DeleteDonationCategory.cs` | VERIFY: soft-delete + friendly error when child DonationPurposes exist. |
| 8 | Toggle Command | `.../DonationCategories/Commands/ToggleDonationCategory.cs` | VERIFY |
| 9 | GetAll Query Handler | `.../DonationCategories/Queries/GetDonationCategory.cs` | MODIFY: Include DonationGroup (or project via LINQ); add `PurposesCount = c.DonationPurposes.Count(p => !p.IsDeleted)` projection; extend `searchTerm` clause to also search `DonationGroup.DonationGroupName`; **keep existing query name `GetDonationCategories` — do not rename.** |
| 10 | GetById Query Handler | `.../DonationCategories/Queries/GetDonationCategoryById.cs` | MODIFY: Include DonationGroup nav + project PurposesCount |
| 11 | Mutations | `.../Base.API/EndPoints/Donation/Mutations/DonationCategoryMutations.cs` | LEAVE AS-IS — existing operation names (`CreateDonationCategory`, `UpdateDonationCategory`, `ActivateDeactivateDonationCategory`, `DeleteDonationCategory`) must not change; they are referenced by DB seed and possibly by DonationPurpose flows. |
| 12 | Queries | `.../Base.API/EndPoints/Donation/Queries/DonationCategoryQueries.cs` | LEAVE AS-IS — keep `GetDonationCategories`, `GetDonationCategoryById`. |

### Backend Wiring Updates (verify — already wired for existing entity)

| # | File to Modify | What to Verify |
|---|---------------|---------------|
| 1 | IDonationDbContext.cs / IApplicationDbContext.cs | `DbSet<DonationCategory>` exists |
| 2 | DonationDbContext.cs | `DbSet<DonationCategory>` exists |
| 3 | DecoratorProperties.cs | `DecoratorDonationModules.DonationCategory` entry exists (confirmed via `GetDonationCategory.cs` line 6 `[CustomAuthorize(DecoratorDonationModules.DonationCategory, Permissions.Read)]`) |
| 4 | DonationMappings.cs | Mapster config for Request↔Entity, Response↔Entity; confirm `DonationGroup` nav + `PurposesCount` are mapped (add explicit mapping if Adapt doesn't pick up the count projection automatically) |
| 5 | DB Migration | A new migration is required: (a) add `DonationGroupId` NOT NULL column with a data-backfill step, (b) relax `Description` from NOT NULL to NULL |

### Frontend Files (ALIGN — modify existing, remove duplicates)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/donation-service/DonationCategoryDto.ts` | MODIFY: ADD `donationGroupId: number`, `donationGroup?: { donationGroupId: number; donationGroupName: string }`, `purposesCount: number`. Make `description?: string` optional. |
| 2 | GQL Query | `src/infrastructure/gql-queries/donation-queries/DonationCategoryQuery.ts` | MODIFY: reformat (newlines); ADD `donationGroupId`, `donationGroup { donationGroupId donationGroupName }`, `purposesCount`, `companyId` to selection sets of both list and by-id queries. |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/donation-mutations/DonationCategoryMutation.ts` | MODIFY: ADD `$donationGroupId: Int!` variable to Create and Update mutations; RELAX `$description: String!` → `$description: String` (optional); reformat for readability; include `donationGroupId` in mutation response selection. |
| 4 | Page Config | `src/presentation/pages/setting/donationconfig/donationcategory.tsx` | KEEP as-is (exports `DonationCategoryPageConfig` renders `<DonationCategoryDataTable />` — already correct) |
| 5 | Data Table | `src/presentation/components/page-components/setting/donationconfig/donationcategory/data-table.tsx` | MODIFY: register a custom cell renderer for the "Purposes" column → count-link (navigates to `/{lang}/setting/donationconfig/donationpurpose?donationCategoryId=<id>`). Existing CRUD-enable flags (`enableAdd/Import/Export/Print/Pagination/AdvanceFilter`) are already `true` — leave. Decide whether toggle/view/edit/delete flags need adding (likely missing — add `enableView`, `enableEdit`, `enableDelete`, `enableToggle` = true, consistent with DonationPurpose fix). |
| 6 | Count-link Renderer | `src/presentation/components/custom-components/data-tables/shared-cell-renderers/count-link.tsx` | CREATE (if not already present from other screens) — generic `CountLinkRenderer({ value, href })` component rendering teal anchor. Register it in `shared-cell-renderers/index.ts` and the three column-type switch files (`advanced/`, `basic/`, `flow/data-table-column-types/component-column.tsx`) following the `target-raised-progress` precedent from DonationPurpose session 1. **Check first — may already exist as a shared renderer.** |
| 7 | Route Page | `src/app/[lang]/setting/donationconfig/donationcategory/page.tsx` | KEEP (already exists, correct per MODULE_MENU_REFERENCE) |

**Routes to DELETE (obsolete duplicates — same pattern as DonationPurpose fix):**
- `src/app/[lang]/crm/organization/donationcategory/page.tsx` ← obsolete
- `src/app/[lang]/organization/donationsetup/donationcategory/page.tsx` ← obsolete

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | Verify `DONATIONCATEGORY` operations config (create/update/delete/toggle mutations + query) — likely already present |
| 2 | operations-config.ts | Verify import + registration exists |
| 3 | Sidebar menu config | Verify `DONATIONCATEGORY` menu entry under `CRM_ORGANIZATION` with URL `setting/donationconfig/donationcategory` (per MODULE_MENU_REFERENCE.md) |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens. User reviews and confirms.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Donation Category
MenuCode: DONATIONCATEGORY
ParentMenu: CRM_ORGANIZATION
Module: CRM
MenuUrl: setting/donationconfig/donationcategory
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: DONATIONCATEGORY
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — final shapes after ALIGN.

**GraphQL Types:**
- Query type: `DonationCategoryQueries` (extends Query)
- Mutation type: `DonationCategoryMutations` (extends Mutation)

**Queries** (EXISTING names — do not rename):

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| donationCategories | PaginatedApiResponse<DonationCategoryResponseDto> | GridFeatureRequest (pageSize, pageIndex, sortColumn, sortDescending, searchTerm, advancedFilter) |
| donationCategoryById | BaseApiResponse<DonationCategoryResponseDto> | donationCategoryId |

**Mutations** (EXISTING names — do not rename):

| GQL Field | Input | Returns |
|-----------|-------|---------|
| createDonationCategory | DonationCategoryRequestDto | DonationCategoryRequestDto (with new id) |
| updateDonationCategory | DonationCategoryRequestDto | DonationCategoryRequestDto |
| deleteDonationCategory | donationCategoryId | DonationCategoryRequestDto |
| activateDeactivateDonationCategory | donationCategoryId | DonationCategoryRequestDto |

**Response DTO Fields** (what FE receives — AFTER align):

| Field | Type | Notes |
|-------|------|-------|
| donationCategoryId | int | PK |
| donationCategoryCode | string | Unique per Company |
| donationCategoryName | string | — |
| **donationGroupId** | int | **NEW — required FK** |
| **donationGroup** | { donationGroupId, donationGroupName } | **NEW — nav from Include** |
| **purposesCount** | int | **NEW — computed via `.DonationPurposes.Count(!p.IsDeleted)` subquery** |
| description | string? | Optional (relaxed from required) |
| orderBy | int | — |
| companyId | int? | — |
| isActive | bool | Inherited |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/setting/donationconfig/donationcategory`
- [ ] EF migration generated and applied: `DonationGroupId` NOT NULL column added + `Description` relaxed to NULL

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 8 columns: #, Code, Category Name, Group, Purposes, Description, Order, Actions
- [ ] Search filters by code, name, group name, description
- [ ] Add new category → modal shows 5 fields (Code, Name, Group dropdown, Description, Order) → selecting Group loads `donationGroups` query → save succeeds → appears in grid with Group badge + Purposes count = 0
- [ ] Edit existing category → modal pre-fills all fields including Group → save succeeds → grid updates
- [ ] Toggle active/inactive via form switch → Update mutation fires OR via row action → ActivateDeactivate mutation fires; inactive rows show at 0.6 opacity
- [ ] Delete active category with no purposes → soft-delete succeeds
- [ ] Delete category with referenced purposes → friendly error "N purposes reference this — deactivate instead"
- [ ] Group dropdown (ApiSelectV2) loads from `donationGroups` query → shows `donationGroupName`
- [ ] "Purposes" column renders as teal count link (monospace or regular)
- [ ] Clicking Purposes count link navigates to `/{lang}/setting/donationconfig/donationpurpose?donationCategoryId=<id>` and Purpose grid filters by that category (if Purpose route supports it — otherwise render plain text and log Known Issue)
- [ ] When Description is null, grid shows `—`
- [ ] Obsolete routes at `crm/organization/donationcategory` and `organization/donationsetup/donationcategory` return 404
- [ ] Permissions: non-BUSINESSADMIN role hides Create/Edit/Delete buttons

**DB Seed Verification:**
- [ ] Menu "Donation Category" visible under CRM → Organization (Parent `CRM_ORGANIZATION`) with URL `setting/donationconfig/donationcategory`
- [ ] Grid config renders all 8 columns with correct cell types (badge for Code, badge for Group, count-link for Purposes, order-num for Order)
- [ ] GridFormSchema renders modal form with Code + Name + Group (ApiSelect) + Description (textarea) + Display Order

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **ALIGN scope — do NOT regenerate the entity or add a new module.** Schema `fund` and group `Donation` already exist. Touch only the files listed in § ⑧.
- **This screen resolves ISSUE-1 from `donationpurpose.md`.** That session shipped the Category→Group auto-fill as two independent ApiSelects because `DonationCategory` had no `DonationGroupId` FK. Adding the FK here is the correct data-model fix. After this screen ships, a follow-up enhancement should revisit the DonationPurpose modal (screen #2) to re-enable the Category→Group auto-fill from `DonationCategory.DonationGroup.DonationGroupName`. Flag this in a follow-up ticket; do NOT change screen #2 as part of this build.
- **Query/mutation naming deviates from template convention**: project uses `GetDonationCategories` / `donationCategories` / `activateDeactivateDonationCategory` instead of `GetAllDonationCategoryList` / `ToggleDonationCategory`. Do **NOT rename** — DB seed GridConfig references these operation names, and renaming breaks the RJSF form + CRUD wiring.
- **Add `DonationGroupId` as NOT NULL — needs data backfill.** Existing `DonationCategories` rows have no value. Either (a) backfill from `DonationPurposes.DonationGroupId` per category (most common group wins), or (b) create an "Unassigned" DonationGroup first and default all existing rows to it. The EF migration MUST include this `Up()` data step, not just the schema change.
- **Duplicate FE routes**: three `page.tsx` files exist for `donationcategory` (at `crm/organization/`, `organization/donationsetup/`, `setting/donationconfig/`). The canonical per MODULE_MENU_REFERENCE.md is `setting/donationconfig/donationcategory`. Delete the other two after verifying no imports/links point to them (grep for `donationcategory` in the FE codebase before deletion).
- **Mockup shows 3 tabs** (Purposes / Categories / Groups) but MODULE_MENU_REFERENCE.md treats each as a separate menu. Build this screen as a **standalone grid** — do NOT build the tab navigation shell. Purposes (#2 COMPLETED) and Groups (#4) are separate screens.
- **PurposesCount aggregation**: EF Core handles `c.DonationPurposes.Count(...)` as a correlated subquery when projected through `.Select()`. After `ApplyGridFeatures`, either (a) project the count in the final `.Select(new DonationCategoryResponseDto { ..., PurposesCount = c.DonationPurposes.Count(p => !p.IsDeleted) })`, or (b) post-process the returned page rows with a second query `dbContext.DonationPurposes.Where(p => categoryIds.Contains(p.DonationCategoryId) && !p.IsDeleted).GroupBy(p => p.DonationCategoryId).Select(g => new { g.Key, Count = g.Count() })` and merge. Choice (a) is cleaner; choice (b) may be needed if `ApplyGridFeatures` does the final projection itself. BE dev picks based on how `ApplyGridFeatures` is implemented — refer to DonationPurpose Session 1 for the precedent of post-projection for `RaisedAmount`.
- **Description nullability change**: Current EF config makes `Description` `.IsRequired()` with max-length 1000; entity declares `string Description { get; set; } = default!;`. Change BOTH: entity → `string? Description`, EF config → drop `.IsRequired()`. DB migration drops NOT NULL.
- **Unique index**: existing `(DonationCategoryCode, CompanyId, IsActive)` unique index stays. Optionally add a second index `(DonationCategoryName, DonationGroupId, CompanyId, IsActive)` if the name-per-group uniqueness rule is enforced at the DB level; otherwise keep it as a validator-only rule.
- **Search in handler currently includes `OrderBy.ToString()`** — keep this behaviour but ADD a search-clause for `c.DonationGroup.DonationGroupName` after Include so users can filter by group name from the grid search box.
- **Click-through filter dependency**: The "Purposes count" link targets `/{lang}/setting/donationconfig/donationpurpose?donationCategoryId=<id>`. Verify the DonationPurpose data-table supports filtering by query-param on page load. If it does not, render the count as plain text and open a follow-up issue — do NOT block this build.

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
| ISSUE-1 | 1 | Low | Frontend | `link-count` renderer substitutes only row-field tokens — the `{lang}` prefix is omitted from the "Purposes" click-through URL (`/setting/donationconfig/donationpurpose?donationCategoryId=<id>`). With Next.js `[lang]` dynamic segment, navigating to a root-relative path without lang prefix will lose locale. Renderer needs a `useLang()` enhancement, or a lang-aware Link wrapper. | OPEN |
| ISSUE-2 | 1 | Low | Frontend | Mockup shows Group column as color-varying badge (purple/amber/blue/pink by group value); implementation uses `badge-code` (single-color pill) matching DonationPurpose precedent. Color-by-value requires a custom `group-color-badge` renderer. Deferred. | OPEN |
| ISSUE-3 | 1 | Medium | Backend/DB | Migration backfill for `DonationGroupId` NOT NULL assumes every `DonationCategory`'s Company has at least one `DonationGroup`. If a Company has no DonationGroups at all, the backfill leaves NULL and step (c) `ALTER NOT NULL` fails. Verify on target DB before apply; add defensive "Unassigned" group creation if needed. | OPEN |
| ISSUE-4 | 1 | Info | Frontend | Pre-existing `link-count.tsx` uses inline hex colors (`#0e7490`, `#155e75`) violating design-token rule. Not touched in this ALIGN (renderer reused, not modified). Should be cleaned up in a dedicated UI polish pass. | OPEN |
| ISSUE-5 | 1 | Info | Cross-screen | Resolves DonationPurpose (#2) ISSUE-1 at the data-model layer. Follow-up enhancement: revisit DonationPurpose modal to re-enable Category → Group auto-fill from `DonationCategory.DonationGroup.DonationGroupName`. Open a ticket; do NOT modify #2 as part of this build. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-18 — BUILD — COMPLETED

- **Scope**: Initial full ALIGN build from PROMPT_READY prompt. MASTER_GRID, `fund` schema, new DonationGroupId FK + PurposesCount aggregation + link-count renderer reuse.
- **Files touched**:
  - BE:
    - `Base.Domain/Models/DonationModels/DonationCategory.cs` (modified — added DonationGroupId + DonationGroup nav; relaxed Description to nullable)
    - `Base.Domain/Models/DonationModels/DonationGroup.cs` (modified — added inverse DonationCategories collection)
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/DonationCategoryConfiguration.cs` (modified — dropped Description.IsRequired, added HasOne(DonationGroup).WithMany().HasForeignKey().OnDelete(Restrict), added composite unique index Name+GroupId+CompanyId+IsActive)
    - `Base.Application/Schemas/DonationSchemas/DonationCategorySchemas.cs` (modified — added DonationGroupId on Request; added DonationGroupId, DonationGroupDto nav, PurposesCount on Response; Description → string?)
    - `Base.Application/Business/DonationBusiness/DonationCategories/Commands/CreateDonationCategory.cs` (modified — ValidatePropertyIsRequired(DonationGroupId), ValidateForeignKeyRecord(DonationGroup), removed Description required, added name-per-group uniqueness via MustAsync)
    - `Base.Application/Business/DonationBusiness/DonationCategories/Commands/UpdateDonationCategory.cs` (modified — mirrors Create; uniqueness excludes current record)
    - `Base.Application/Business/DonationBusiness/DonationCategories/Queries/GetDonationCategory.cs` (modified — Include DonationGroup, searchTerm over DonationGroupName, post-projection PurposesCount via group-by lookup following RaisedAmount precedent)
    - `Base.Application/Business/DonationBusiness/DonationCategories/Queries/GetDonationCategoryById.cs` (modified — Include DonationGroup + CountAsync PurposesCount on single record)
    - `Base.Application/Mappings/DonationMappings.cs` (modified — explicit Mapster config for DonationGroup nav + PurposesCount on Response/Dto)
    - `Base.Infrastructure/Migrations/20260418101417_Add_DonationGroupId_To_DonationCategory_And_Relax_Description.cs` (created — adds nullable column, backfills from DonationPurposes groupby / company fallback / global fallback, ALTER NOT NULL, FK Restrict, Description nullable, composite unique index; full Down() reversal)
    - `Base.Infrastructure/Migrations/ApplicationDbContextModelSnapshot.cs` (modified — DonationCategory snapshot updated)
  - FE:
    - `src/domain/entities/donation-service/DonationCategoryDto.ts` (modified — donationGroupId, donationGroup nav, purposesCount, companyId; description optional)
    - `src/infrastructure/gql-queries/donation-queries/DonationCategoryQuery.ts` (modified — added operation names GetDonationCategories / GetDonationCategoryById; added donationGroupId, donationGroup { ... }, purposesCount, companyId to both selection sets; reformatted)
    - `src/infrastructure/gql-mutations/donation-mutations/DonationCategoryMutation.ts` (modified — added operation names to all 4; $donationGroupId: Int! on Create + Update; $description: String (relaxed); donationGroupId in response selections; reformatted)
    - `src/presentation/components/page-components/setting/donationconfig/donationcategory/data-table.tsx` (modified — enableSearch, enableActions { View, Edit, Delete, Toggle } all true)
    - `src/app/[lang]/crm/organization/donationcategory/page.tsx` (deleted — obsolete duplicate, no inbound references)
    - `src/app/[lang]/organization/donationsetup/donationcategory/page.tsx` (deleted — obsolete duplicate, no inbound references)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/link-count.tsx` (reused — renderer already existed and registered in advanced/basic/flow column-type switches; GridComponentName = `link-count`)
  - DB: `Base/sql-scripts-dyanmic/DonationCategory-sqlscripts.sql` (created — auth.Menus + MenuCapabilities + RoleCapabilities (BUSINESSADMIN) + sett.Grids + Fields (6 new: DONATIONCATEGORYID, DONATIONCATEGORY_CODE, DONATIONCATEGORY_NAME, DONATIONCATEGORY_DESCRIPTION, DONATIONCATEGORY_ORDERBY, DONATIONCATEGORY_PURPOSESCOUNT) + GridFields (8 columns: PK hidden, Code badge, Name text-bold, Group badge-code FK nav, Purposes link-count, Description, Order badge-circle, IsActive status-badge) + GridFormSchema (6 fields: Code/Name full-width, Group ApiSelectV2 full-width, Description textarea, Order+Active half-width row))
- **Deviations from spec**:
  - PurposesCount implementation: chose option (b) post-projection group-by lookup over option (a) in-`.Select()` because `ApplyGridFeatures` performs the Mapster projection internally. Matches the RaisedAmount precedent from DonationPurpose Session 1.
  - `ValidateStringLength(Description, 1000)` kept (works with `string?` — confirmed via DonationPurpose precedent).
  - Group column uses `badge-code` (single-color pill) not color-by-value badge (see ISSUE-2).
  - linkTemplate omits `{lang}` prefix (see ISSUE-1).
- **Known issues opened**: ISSUE-1, ISSUE-2, ISSUE-3, ISSUE-4, ISSUE-5 (see table above).
- **Known issues closed**: Resolves DonationPurpose (#2) ISSUE-1 at the data-model layer (new DonationGroupId FK). Follow-up to re-enable Category→Group auto-fill in #2 modal is tracked as ISSUE-5 here.
- **Next step**: (empty — COMPLETED). User should run the migration + seed SQL, then `dotnet build` and `pnpm dev` for full E2E verification.

### Session 2 — 2026-06-29 — ENHANCE — COMPLETED

- **Scope**: This screen's grid (`DonationCategoryDataTable`) is now mounted as the **"Categories" tab** of the new combined **"Donation Configuration"** screen (#2+#3+#4 consolidation, reverting to the original 3-tab mockup). FE-only; **zero backend changes** — this grid, its entity, queries and mutations are untouched and still resolve CRUD by `gridCode="DONATIONCATEGORY"`.
- **Files touched**: None owned by this screen. New combined shell + seed live with screen #2 — see **donationpurpose.md Session 2** for the full file manifest and RBAC mechanics. Net effect here: the standalone `DONATIONCATEGORY` sidebar menu is hidden (its ISMENURENDER role-grant set to `HasAccess=false`); the menu stays `IsActive=true` so the Categories tab keeps full CRUD. The standalone route `setting/donationconfig/donationcategory` is left in place for count-link deep-links.
- **Deviations from spec**: Supersedes the "build as standalone grid" note in §⑥/§⑫ — the grid now lives inside a tabbed shell. No code change to the grid itself.
- **Known issues opened/closed**: None.
- **Next step**: See donationpurpose.md Session 2 (run `DonationConfig-sqlscripts.sql`, re-login, verify).

### Session 3 — 2026-07-15 — ENHANCE — COMPLETED

- **Scope**: Tenant-configurable auto-generation of `DonationCategoryCode` on Create via `NumberSequenceGenerator` (entityTypeCode `DONATIONCATEGORY`, default pattern `DC-{SEQ:000}`), mirroring the Contact/Grant pattern. Code field is now server-owned.
- **Files touched**:
  - BE: `Business/DonationBusiness/DonationCategories/Commands/CreateDonationCategory.cs` — validator dropped `DonationCategoryCode` required + unique checks (length-only now); handler injects `IHttpContextAccessor`, resolves tenant `CompanyId`, wraps unit-of-work in `CreateExecutionStrategy` + transaction, calls `NumberSequenceGenerator.GenerateAsync(...)` and assigns the code when non-empty.
  - FE: `infrastructure/gql-mutations/donation-mutations/DonationCategoryMutation.ts` — CREATE mutation `$donationCategoryCode` relaxed `String!` → `String` (Update left `String!`).
  - DB: `sql-scripts-dyanmic/NumberSequenceEntityType-BulkRegister-sqlscripts.sql` + `NumberSequenceConfig-CounterBackfill-sqlscripts.sql` — appended `DONATIONCATEGORY` rows (eligibility + `DC-` collision backfill).
- **Deviations from spec**: None.
- **Known issues opened/closed**: None.
- **Next step**: User must re-run both seed scripts (BulkRegister first, then CounterBackfill) in each environment before Create is used — the generator throws if the `DONATIONCATEGORY` eligibility row is absent. Build verified: `Base.Application` compiles clean (0 errors).
