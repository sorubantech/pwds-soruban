# Screen Prompt Template — MASTER_GRID (v2)

> For screens that show a list/grid + a **modal RJSF form** for add/edit.
> Canonical reference: `ContactType` (MASTER_GRID).
>
> Use this when: simple flat entity, modal popup form, grid stays on one route.
> Do NOT use for multi-mode view pages (use `_FLOW.md`) or widget-heavy dashboards (use `_DASHBOARD.md`).

---

## Template

```markdown
---
screen: {EntityName}
registry_id: {#}
module: {Module Name}
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: MASTER_GRID
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
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
- [ ] Backend code generated          ← skip if FE_ONLY
- [ ] Backend wiring complete         ← skip if FE_ONLY
- [ ] Frontend code generated         ← skip if BE_ONLY
- [ ] Frontend wiring complete        ← skip if BE_ONLY
- [ ] DB Seed script generated (including GridFormSchema)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at correct route
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete)
- [ ] Grid columns render correctly with search/filter
- [ ] RJSF modal form renders with all fields + validation
- [ ] FK dropdowns load data via ApiSelect
- [ ] Summary widgets display (if applicable)
- [ ] Grid aggregation columns show per-row values (if applicable)
- [ ] Service placeholder buttons render with toast (if applicable)
- [ ] DB Seed — menu visible in sidebar, grid + form schema render

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: {EntityName}
Module: {ModuleName}
Schema: {db_schema}
Group: {BackendGroupName} (e.g., CorgModels, AppModels, NotifyModels)

Business: {Rich description — 3-5 sentences covering:
  - What the screen does
  - Who uses it (admin, staff, field agent, etc.) and when
  - Why it exists in the NGO workflow
  - How it relates to other screens in the same module}

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from HTML mockup. Audit columns (CreatedBy, CreatedDate, etc.) omitted — inherited from Entity base.

Table: {schema}."{PluralTableName}"

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| {EntityName}Id | int | — | PK | — | Primary key |
| {EntityName}Code | string | 50 | YES | — | Unique |
| {EntityName}Name | string | 100 | YES | — | — |
| {FKField}Id | int | — | YES | {schema}.{FKTable} | FK |
| Description | string | 500 | NO | — | Optional |
| ... | ... | ... | ... | ... | ... |

**Child Entities** (if any — rare for MASTER_GRID):
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| {ChildName} | 1:Many via {EntityName}Id | {field1}, {field2} |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)
> Each FK must be fully resolved — not just "FK: Contact" but WHERE it lives and HOW to query it.

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId | Contact | Base.Domain/Models/CorgModels/Contact.cs | GetAllContactList | ContactName | ContactResponseDto |
| BranchId | Branch | Base.Domain/Models/AppModels/Branch.cs | GetAllBranchList | BranchName | BranchResponseDto |
| ... | ... | ... | ... | ... | ... |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- {EntityName}Code must be unique per Company (ValidateUniqueWhenCreate + ValidateUniqueWhenUpdate)
- {Other unique field rules}

**Required Field Rules:**
- {FieldA}, {FieldB}, {FieldC} are mandatory
- {FKField}Id is mandatory FK

**Conditional Rules:**
- {If Status = "X", then FieldY is required}

**Business Logic:**
- {e.g., "Only one active record per parent"}

**Workflow**: None (MASTER_GRID rarely has workflow; if present, see `_FLOW.md` instead)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: MASTER_GRID
**Type Classification**: {Type 1, Type 2, Type 3, etc. from solution-resolver.md}
**Reason**: {why this classification — e.g., "Simple flat entity with 2 optional FKs, no workflow, no children"}

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — always
- [ ] Nested child creation — {if has child collections}
- [ ] Multi-FK validation (ValidateForeignKeyRecord × {N}) — {if 3+ FKs}
- [ ] Unique validation — {fields}
- [ ] File upload command — {if has file fields}
- [ ] Custom business rule validators — {list}

**Frontend Patterns Required:**
- [x] AdvancedDataTable
- [x] RJSF Modal Form (driven by GridFormSchema from DB seed)
- [ ] File upload widget — {if file fields}
- [ ] Summary cards / count widgets — {if mockup shows stats above grid}
- [ ] Grid aggregation columns — {if rows show computed/aggregated values}
- [ ] Info panel / side panel — {if mockup shows row-detail side panel}
- [ ] Drag-to-reorder — {if mockup shows reorder UI}
- [ ] Click-through filter — {if a column value navigates/filters}

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Grid/List View

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | {Code} | {entityCamelCase}Code | text | 120px | YES | — |
| 2 | {Name} | {entityCamelCase}Name | text | auto | YES | Primary column |
| 3 | {FK Name} | {fkEntityCamelCase}Name | text | 150px | YES | FK display |
| 4 | {Status} | isActive | badge | 100px | YES | Active/Inactive |
| ... | ... | ... | ... | ... | ... | ... |

**Search/Filter Fields**: {field1}, {field2}, {field3}

**Grid Actions**: Edit, Toggle Active, Delete {+ any custom actions}

### RJSF Modal Form

> Simple modal popup form. Fields are driven by GridFormSchema in DB seed.
> FE developer does NOT build a custom form — RJSF renders it from backend schema.

**Form Sections** (in order):
| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | {Basic Information} | 2-column | {field1, field2, field3, field4} |
| 2 | {Details} | 2-column | {field5, field6, field7} |
| 3 | {Notes} | 1-column full-width | {description/notes textarea} |

**Field Widget Mapping**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| {EntityName}Code | text | "Enter code" | required, max 50 | Unique |
| {EntityName}Name | text | "Enter name" | required, max 100 | — |
| {FKField}Id | ApiSelectV2 | "Select {FKEntity}" | required | Query: {GQLQueryName} |
| Description | textarea | "Enter description" | max 500 | Optional |
| ... | ... | ... | ... | ... |

### Page Widgets & Summary Cards

> If the mockup shows count cards / summary widgets above the grid, define them here.

**Widgets**: {NONE | list below}

**Layout Variant** (REQUIRED — stamp one): `{grid-only | widgets-above-grid | side-panel | widgets-above-grid+side-panel}`
- `grid-only` → FE Dev uses **Variant A**: `<AdvancedDataTable>` with internal header. No `<ScreenHeader>` in page component.
- `widgets-above-grid` → FE Dev uses **Variant B**: `<ScreenHeader>` + widget components + `<DataTableContainer showHeader={false}>`. MANDATORY to avoid duplicate headers.
- `side-panel` / `widgets-above-grid+side-panel` → Variant B + layout row (grid on left, panel on right).

**Detection cue**: if this table has any rows (count cards, KPIs, stats) OR a Side Panel block is non-NONE → variant is NOT `grid-only`.

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | {e.g., "Total Types"} | {GQL summary query field} | count | Top-left |
| ... | ... | ... | ... | ... |

**Summary GQL Query** (if widgets exist):
- Query name: `Get{EntityName}Summary`
- Returns: `{EntityName}SummaryDto` with fields matching widget values
- Must be added to `{EntityName}Queries.cs` alongside `GetAll` and `GetById`

### Grid Aggregation Columns

> Per-row computed values (NOT footer totals). Implement via LINQ subquery or PGFunction.

**Aggregation Columns**: {NONE | list below}

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| {e.g., "Contact Count"} | Count of contacts with this type | Contact table → COUNT WHERE ContactTypeId = row.Id | LINQ subquery |
| ... | ... | ... | ... |

### Side Panels / Info Displays (if mockup shows)

> Some MASTER_GRID screens have a side panel that shows details when a row is clicked,
> or a quick-view panel. Extract layout here.

**Side Panel**: {NONE | describe below}

| Panel Section | Fields / Content | Trigger |
|--------------|------------------|---------|
| {e.g., "Type Details"} | {fields shown} | {row click / hover} |
| {e.g., "Recent Records"} | {table of related records} | {row click} |

### User Interaction Flow

1. User sees grid list → clicks "+Add" → modal opens with RJSF form
2. Fills form → clicks Save → API call → grid refreshes → toast notification
3. Edit: clicks row's Edit icon → modal opens pre-filled → edits → Save
4. Toggle: clicks toggle icon → confirm dialog → API call → badge updates
5. Delete: clicks delete icon → confirm dialog → soft-delete API → row disappears
6. {If side panel: user clicks row → panel opens on right with details}
7. {If click-through filter: user clicks a column value → grid filters by that value}

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity. Use when copying from code-reference files.

**Canonical Reference**: ContactType (MASTER_GRID)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | {EntityName} | Entity/class name |
| contactType | {entityCamelCase} | Variable/field names |
| ContactTypeId | {EntityName}Id | PK field |
| ContactTypes | {PluralName} | Table name, collection names |
| contact-type | {kebab-case} | FE route path, file names |
| contacttype | {entity-lower-no-dash} | FE folder, import paths |
| CONTACTTYPE | {ENTITY_UPPER} | Grid code, menu code |
| corg | {schema} | DB schema |
| Corg | {Group} | Backend group name |
| CorgModels | {Group}Models | Namespace suffix |
| CONTACT | {PARENTMENUCODE} | Parent menu code |
| CRM | {MODULECODE} | Module code |
| crm/contact/contacttype | {feRouteBase} | FE route path |
| corg-service | {group}-service | FE service folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Exact files to create, with computed paths. No guessing.

### Backend Files (11 files)

| # | File | Path |
|---|------|------|
| 1 | Entity | Pss2.0_Backend/.../Base.Domain/Models/{Group}Models/{EntityName}.cs |
| 2 | EF Config | Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/{Group}Configurations/{EntityName}Configuration.cs |
| 3 | Schemas (DTOs) | Pss2.0_Backend/.../Base.Application/Schemas/{Group}Schemas/{EntityName}Schemas.cs |
| 4 | Create Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/CreateCommand/Create{EntityName}.cs |
| 5 | Update Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/UpdateCommand/Update{EntityName}.cs |
| 6 | Delete Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/DeleteCommand/Delete{EntityName}.cs |
| 7 | Toggle Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/ToggleCommand/Toggle{EntityName}.cs |
| 8 | GetAll Query | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/GetAllQuery/GetAll{EntityName}.cs |
| 9 | GetById Query | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/GetByIdQuery/Get{EntityName}ById.cs |
| 10 | Mutations | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Mutations/{EntityName}Mutations.cs |
| 11 | Queries | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Queries/{EntityName}Queries.cs |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | DbSet<{EntityName}> property |
| 2 | {Group}DbContext.cs | DbSet<{EntityName}> property |
| 3 | DecoratorProperties.cs | Decorator{Group}Modules entry |
| 4 | {Group}Mappings.cs | Mapster mapping config |

### Frontend Files (6 files — no view-page, no Zustand store for MASTER_GRID)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/{group}-service/{EntityName}Dto.ts |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/{group}-queries/{EntityName}Query.ts |
| 3 | GQL Mutation | Pss2.0_Frontend/src/infrastructure/gql-mutations/{group}-mutations/{EntityName}Mutation.ts |
| 4 | Page Config | Pss2.0_Frontend/src/presentation/pages/{group}/{feFolder}/{entity-lower}.tsx |
| 5 | Index Page Component | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/index-page.tsx |
| 6 | Route Page | Pss2.0_Frontend/src/app/[lang]/(core)/{group}/{feFolder}/{entity-lower}/page.tsx |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | {ENTITY_UPPER} operations config |
| 2 | operations-config.ts | Import + register operations |
| 3 | sidebar menu config | Menu entry under parent |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}

MenuName: {Entity Display Name}
MenuCode: {ENTITYUPPER}
ParentMenu: {PARENTMENUCODE}
Module: {MODULECODE}
MenuUrl: {group/feFolder/entitylower}
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: {ENTITYUPPER}
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose before BE is even built.

**GraphQL Types:**
- Query type: `{EntityName}Queries`
- Mutation type: `{EntityName}Mutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAll{EntityName}List | [{EntityName}ResponseDto] | searchText, pageNo, pageSize, sortField, sortDir, isActive |
| Get{EntityName}ById | {EntityName}ResponseDto | {entityCamelCase}Id |
| Get{EntityName}Summary | {EntityName}SummaryDto | — | ← Only if screen has summary widgets (Section ⑥) |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| Create{EntityName} | {EntityName}RequestDto | int (new ID) |
| Update{EntityName} | {EntityName}RequestDto | int |
| Delete{EntityName} | {entityCamelCase}Id | int |
| Toggle{EntityName} | {entityCamelCase}Id | int |

**Response DTO Fields** (what FE receives):
| Field | Type | Notes |
|-------|------|-------|
| {entityCamelCase}Id | number | PK |
| {entityCamelCase}Code | string | — |
| {entityCamelCase}Name | string | — |
| {fkCamelCase}Id | number | FK |
| {fkEntityCamelCase}Name | string | FK display name (from navigation) |
| isActive | boolean | Inherited |
| ... | ... | ... |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/{group}/{feFolder}/{entitylower}`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with columns: {col1, col2, col3, ...}
- [ ] Search filters by: {field1, field2}
- [ ] Add new record → modal form shows all fields → save succeeds → appears in grid
- [ ] Edit record → modal pre-fills → save succeeds → grid updates
- [ ] Toggle active/inactive → badge changes
- [ ] Delete → soft delete → removed from grid
- [ ] FK dropdowns load data correctly (ApiSelectV2 queries fire)
- [ ] {Summary widgets show correct values — if applicable}
- [ ] {Grid aggregation columns show correct per-row values — if applicable}
- [ ] {Side panel shows details when row clicked — if applicable}
- [ ] {Click-through filter works — if applicable}
- [ ] {Service placeholder buttons render with toast — if applicable}
- [ ] Permissions: buttons/actions respect role capabilities

**DB Seed Verification:**
- [ ] Menu appears in sidebar under {ParentMenu}
- [ ] Grid columns render correctly
- [ ] GridFormSchema renders form correctly

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- {e.g., "This is the FIRST entity in the `{schema}` schema — new module infrastructure must be created first"}
- {e.g., "The ContactId FK uses CorgModels group, NOT AppModels"}
- {e.g., "This screen has an EXISTING FE route — FE dev must USE this path, not create a new one"}
- {e.g., "For ALIGN scope: only modify existing files, do not regenerate from scratch"}

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup is in scope. List items here ONLY if they require an
> external service or infrastructure that doesn't exist in the codebase yet.

{Only list genuine external-service dependencies — leave empty if none.}
- {e.g., "⚠ SERVICE_PLACEHOLDER: 'Send X' — full UI implemented. Handler uses toast because {specific missing service layer} doesn't exist yet."}

Full UI must be built (buttons, side panels, forms, modals, interactions). Only the handler for the external service call is mocked.
```

---

## Section Purpose Summary

| # | Section | Who Reads It | What It Answers |
|---|---------|-------------|-----------------|
| ① | Identity & Context | All agents | "What am I building and why?" |
| ② | Entity Definition | BA → BE Dev | "What fields, types, and constraints?" |
| ③ | FK Resolution | BE Dev + FE Dev | "WHERE is each FK entity, HOW to query it?" |
| ④ | Business Rules | BA → BE Dev → FE Dev | "What validation and logic?" |
| ⑤ | Classification | Solution Resolver | "What patterns? (pre-answered)" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "Grid + modal form + widgets + aggregations + side panels" |
| ⑦ | Substitution Guide | BE Dev + FE Dev | "How to map ContactType → this entity?" |
| ⑧ | File Manifest | BE Dev + FE Dev | "What files to create, exact paths?" |
| ⑨ | Approval Config | User | "Review and confirm DB seed config" |
| ⑩ | BE→FE Contract | FE Dev | "What will the backend expose?" |
| ⑪ | Acceptance Criteria | Verification | "How to verify it works?" |
| ⑫ | Special Notes | All agents | "What's easy to get wrong? Service placeholders?" |
