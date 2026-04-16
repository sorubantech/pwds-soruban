# Screen Prompt Template — v2

> `/plan-screens` generates prompt files following this exact structure.
> `/build-screen` reads these files and feeds them to `/generate-screen`.
>
> **Design principle**: Each section is written for a specific CONSUMER in the pipeline.
> The prompt should PRE-ANSWER questions agents would ask, not just describe what was found.

---

## Template

```markdown
---
screen: {EntityName}
registry_id: {#}
module: {Module Name}
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: {MASTER_GRID | FLOW}
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
- [ ] DB Seed script generated
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at correct route
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete)
- [ ] Grid columns render correctly with search/filter
- [ ] Form fields render with validation
- [ ] FK dropdowns load data via ApiSelect
- [ ] Summary widgets display (if applicable)
- [ ] Service placeholder buttons render (if applicable)
- [ ] DB Seed — menu visible in sidebar

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: {EntityName}
Module: {ModuleName}
Schema: {db_schema}
Group: {BackendGroupName} (e.g., GrantModels, VolModels, CaseModels)

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

**Child Entities** (if any):
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
| CampaignId | Campaign | Base.Domain/Models/CampModels/Campaign.cs | GetAllCampaignList | CampaignName | CampaignResponseDto |
| BranchId | Branch | Base.Domain/Models/AppModels/Branch.cs | GetAllBranchList | BranchName | BranchResponseDto |
| ... | ... | ... | ... | ... | ... |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- {EntityName}Code must be unique per Company (ValidateUniqueWhenCreate + ValidateUniqueWhenUpdate)
- {Other unique field rules}

**Required Field Rules:**
- {FieldA}, {FieldB}, {FieldC} are mandatory (NOT NULL in DB, required in form)
- {FKField}Id is mandatory FK

**Conditional Rules:**
- {If Status = "X", then FieldY is required}
- {If FieldA has value, FieldB becomes optional}

**Business Logic:**
- {e.g., "Only one active membership per contact per tier"}
- {e.g., "RequestedAmount must be > 0"}
- {e.g., "AwardedAmount only set when status is Awarded"}

**Workflow** (if applicable):
- States: {Draft → Submitted → Under Review → Approved → Completed}
- Transitions: {who can trigger each transition}
- Side effects: {what happens on each transition}

**Workflow**: None
{or the workflow definition above}

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.
> Solution Resolver should VALIDATE these, not re-derive from scratch.

**Screen Type**: {MASTER_GRID | FLOW}
**Type Classification**: {Type 1, Type 2, Type 3, etc. from solution-resolver.md}
**Reason**: {why this classification — e.g., "Simple flat entity with 2 optional FKs, no workflow, no children"}

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — always
- [ ] Nested child creation — {if has child collections}
- [ ] Multi-FK validation (ValidateForeignKeyRecord × {N}) — {if 3+ FKs}
- [ ] Unique validation — {fields}
- [ ] Workflow commands — {if has state machine}
- [ ] File upload command — {if has file fields}
- [ ] Tenant scoping (CompanyId from HttpContext) — {FLOW screens}
- [ ] Custom business rule validators — {list}

**Frontend Patterns Required:**
- [x] {AdvancedDataTable | FlowDataTable}
- [x] {RJSF Modal Form | React Hook Form View Page}
- [ ] Child grid in view page — {if parent-child}
- [ ] Workflow status badge + action buttons — {if workflow}
- [ ] File upload widget — {if file fields}
- [ ] Zustand store — {FLOW screens only}
- [ ] Unsaved changes dialog — {FLOW screens only}
- [ ] Summary cards / count widgets — {if mockup shows stats above grid}
- [ ] Grid aggregation columns — {if rows show computed/aggregated values}

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

### Form Layout

**Form Type**: {RJSF Modal (MASTER_GRID) | React Hook Form View Page (FLOW)}

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
| StartDate | datepicker | "Select date" | required | — |
| IsRecurring | checkbox | — | — | — |
| ... | ... | ... | ... | ... |

**Child Grids in View Page** (if any):
| Child | Grid Columns | Add/Edit Method | Delete |
|-------|-------------|----------------|--------|
| {ChildEntity} | {col1, col2, col3} | Inline row / Modal | Soft delete |

### Page Widgets & Summary Cards

> If the mockup shows count cards / summary widgets above the grid, define them here.
> Each widget needs a dedicated GraphQL summary query.

**Widgets**: {NONE | list below}

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | {e.g., "Total Donations"} | {GQL summary query field} | count / currency / percentage | Top-left |
| 2 | {e.g., "Active Members"} | {GQL summary query field} | count | Top-center |
| ... | ... | ... | ... | ... |

**Summary GQL Query** (if widgets exist):
- Query name: `Get{EntityName}Summary`
- Returns: `{EntityName}SummaryDto` with fields matching widget values
- Must be added to `{EntityName}Queries.cs` alongside `GetAll` and `GetById`

### Grid Aggregation Columns

> Some grids have computed/aggregated columns where EACH ROW shows a calculated value
> (e.g., "Total Donations" column showing the sum of donations for that specific contact).
> These are row-level computed values, NOT footer totals.
> Implement using Entity/DbContext layer (LINQ projections) or PostgreSQL functions (PGFunctions).

**Aggregation Columns**: {NONE | list below}

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| {e.g., "Total Donations"} | Sum of all donations for this contact | Donation table → SUM(Amount) WHERE ContactId = row.ContactId | LINQ subquery / PGFunction |
| {e.g., "Member Count"} | Count of active members in this tier | Membership table → COUNT WHERE TierId = row.TierId AND IsActive | LINQ subquery |
| {e.g., "Last Activity"} | Most recent activity date for this record | ActivityLog → MAX(ActivityDate) WHERE EntityId = row.Id | LINQ subquery |

### User Interaction Flow

{For MASTER_GRID}:
1. User sees grid list → clicks "+Add" → modal opens with RJSF form
2. Fills form → clicks Save → API call → grid refreshes → toast notification
3. Edit: clicks row → modal opens pre-filled → edits → Save
4. Toggle: clicks toggle icon → confirm dialog → API call → badge updates

{For FLOW}:
1. User sees FlowDataTable list → clicks "+Add" → navigates to ?mode=new
2. View page loads with empty form → fills fields → clicks Save → API call
3. Success → redirects to ?mode=read&id={id} → view page shows read-only data
4. Edit: clicks Edit button → form becomes editable (?mode=edit&id={id})
5. Back: clicks back → returns to list with state preserved

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity. Use when copying from code-reference files.

**Canonical Reference**: {SavedFilter (FLOW) | ContactType (MASTER_GRID)}

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | {EntityName} | Entity/class name |
| savedFilter | {entityCamelCase} | Variable/field names |
| SavedFilterId | {EntityName}Id | PK field |
| SavedFilters | {PluralName} | Table name, collection names |
| saved-filter | {kebab-case} | FE route path, file names |
| savedfilter | {entity-lower-no-dash} | FE folder, import paths |
| SAVEDFILTER | {ENTITY_UPPER} | Grid code, menu code |
| notify | {schema} | DB schema |
| Notify | {Group} | Backend group name (Models/Schemas/Business) |
| NotifyModels | {Group}Models | Namespace suffix |
| NOTIFICATIONSETUP | {PARENTMENUCODE} | Parent menu code |
| NOTIFICATION | {MODULECODE} | Module code |
| crm/communication/savedfilter | {feRouteBase} | FE route path |
| notify-service | {group}-service | FE service folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Exact files to create, with computed paths. No guessing.

### Backend Files ({N} files)

| # | File | Path | Template Source |
|---|------|------|-----------------|
| 1 | Entity | Pss2.0_Backend/.../Base.Domain/Models/{Group}Models/{EntityName}.cs | code-ref §1 |
| 2 | EF Config | Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/{Group}Configurations/{EntityName}Configuration.cs | code-ref §2 |
| 3 | Schemas (DTOs) | Pss2.0_Backend/.../Base.Application/Schemas/{Group}Schemas/{EntityName}Schemas.cs | code-ref §3 |
| 4 | Create Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/CreateCommand/Create{EntityName}.cs | code-ref §4 |
| 5 | Update Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/UpdateCommand/Update{EntityName}.cs | code-ref §5 |
| 6 | Delete Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/DeleteCommand/Delete{EntityName}.cs | code-ref §6 |
| 7 | Toggle Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/ToggleCommand/Toggle{EntityName}.cs | code-ref §7 |
| 8 | GetAll Query | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/GetAllQuery/GetAll{EntityName}.cs | code-ref §8 |
| 9 | GetById Query | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/GetByIdQuery/Get{EntityName}ById.cs | code-ref §9 |
| 10 | Mutations | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Mutations/{EntityName}Mutations.cs | code-ref §10 |
| 11 | Queries | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Queries/{EntityName}Queries.cs | code-ref §11 |

### Backend Wiring Updates ({N} files to modify)

| # | File to Modify | What to Add | Marker/Location |
|---|---------------|-------------|-----------------|
| 1 | IApplicationDbContext.cs | DbSet<{EntityName}> property | With other DbSets |
| 2 | {Group}DbContext.cs | DbSet<{EntityName}> property | Partial class |
| 3 | DecoratorProperties.cs | Decorator{Group}Modules entry | With other decorators |
| 4 | {Group}Mappings.cs | Mapster mapping config | ConfigureMappings method |

### Frontend Files ({N} files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/{group}-service/{EntityName}Dto.ts |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/{group}-queries/{EntityName}Query.ts |
| 3 | GQL Mutation | Pss2.0_Frontend/src/infrastructure/gql-mutations/{group}-mutations/{EntityName}Mutation.ts |
| 4 | Page Config | Pss2.0_Frontend/src/presentation/pages/{group}/{feFolder}/{entity-lower}.tsx |
| 5 | Index Page | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/index.tsx |
| 6 | Index Page Component | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/index-page.tsx |
| 7 | View Page (FLOW) | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/view-page.tsx |
| 8 | Zustand Store (FLOW) | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/{entity-lower}-store.ts |
| 9 | Route Page | Pss2.0_Frontend/src/app/[lang]/(core)/{group}/{feFolder}/{entity-lower}/page.tsx |

### Frontend Wiring Updates ({N} files to modify)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | {ENTITY_UPPER} operations config |
| 2 | operations-config.ts | Import + register operations |
| 3 | sidebar menu config | Menu entry under parent |
| 4 | route config | Route definition |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.
> This block is presented to the user in Phase 2 of /generate-screen.

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}

MenuName: {Entity Display Name}
MenuCode: {ENTITYUPPER}
ParentMenu: {PARENTMENUCODE}
Module: {MODULECODE}
MenuUrl: {group/feFolder/entitylower}
GridType: {MASTER_GRID | FLOW}

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  SUPERADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  ADMINISTRATOR: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT
  STAFF: READ, CREATE, MODIFY, EXPORT
  STAFFDATAENTRY: READ, CREATE, MODIFY
  STAFFCORRESPONDANCE: READ
  SYSTEMROLE:

GridFormSchema: {GENERATE | SKIP}
GridCode: {ENTITYUPPER}
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose before BE is even built.
> This prevents FE from waiting or guessing.

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

> **Consumer**: Verification phase — how to know the screen is done correctly.

**Build Verification:**
- [ ] `dotnet build` — no errors in Base.Domain, Base.Application, Base.Infrastructure, Base.API
- [ ] `pnpm dev` — page loads at `/{lang}/{group}/{feFolder}/{entitylower}`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with columns: {col1, col2, col3, ...}
- [ ] Search filters by: {field1, field2}
- [ ] Add new record → form shows all fields → save succeeds → appears in grid
- [ ] Edit record → form pre-fills → save succeeds → grid updates
- [ ] Toggle active/inactive → badge changes
- [ ] Delete → soft delete → removed from grid (when filtered to active)
- [ ] FK dropdowns load data correctly (ApiSelectV2 queries fire)
- [ ] {Summary widgets show correct counts/values — if applicable}
- [ ] {Grid aggregation columns show correct per-row computed values — if applicable}
- [ ] {Service placeholder buttons render and show "coming soon" toast — if applicable}
- [ ] {Workflow: status transitions work as defined}
- [ ] {Child grid: child records CRUD works within view page}
- [ ] Permissions: buttons/actions respect role capabilities

**DB Seed Verification:**
- [ ] Menu appears in sidebar under {ParentMenu}
- [ ] Grid columns render correctly
- [ ] {GridFormSchema renders form correctly — MASTER_GRID only}

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- {e.g., "This is the FIRST entity in the `grant` schema — new module infrastructure must be created first (see DEPENDENCY-ORDER.md New Module section)"}
- {e.g., "CompanyId is NOT a field in the table — it comes from HttpContext in FLOW screens"}
- {e.g., "FLOW screens do NOT generate GridFormSchema in DB seed — SKIP it"}
- {e.g., "The ContactId FK should use the CorgModels group, NOT the AppModels group"}
- {e.g., "This screen has an EXISTING FE route at src/app/[lang]/(core)/grants/grant/page.tsx — the FE dev must USE this path, not create a new one"}
- {e.g., "For ALIGN scope: only modify existing files, do not regenerate from scratch"}

**Service Dependencies** (UI-only — no backend service implementation):
- {e.g., "⚠ SERVICE_PLACEHOLDER: 'Send SMS' button — render the button with proper placement, but use a placeholder/mock handler. Backend SMS service will be implemented in a later phase."}
- {e.g., "⚠ SERVICE_PLACEHOLDER: 'Send WhatsApp' action — implement the UI trigger (button/menu item) and any associated form/modal, but DO NOT implement the actual service call. Use a no-op handler or toast notification as placeholder."}
- {e.g., "⚠ SERVICE_PLACEHOLDER: 'Generate Certificate' action — build the UI flow (button, progress indicator), but mock the generation. Actual PDF generation service is out of scope."}
- Note: For all SERVICE_PLACEHOLDER items — implement full UI (buttons, forms, modals, grid interactions) but bind to a placeholder action that shows a "Feature coming soon" toast or similar. The user interaction flow must be complete even if the backend service doesn't exist yet.
```

---

## Section Purpose Summary

| # | Section | Who Reads It | What It Answers |
|---|---------|-------------|-----------------|
| ① | Identity & Context | All agents | "What am I building and why?" |
| ② | Entity Definition | BA → BE Dev | "What fields, types, and constraints?" |
| ③ | FK Resolution | BE Dev + FE Dev | "WHERE is each FK entity, HOW to query it?" |
| ④ | Business Rules | BA → BE Dev → FE Dev | "What validation and logic?" |
| ⑤ | Classification | Solution Resolver | "What type and patterns? (pre-answered)" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "What does the screen look like? Widgets? Aggregations?" |
| ⑦ | Substitution Guide | BE Dev + FE Dev | "How to map canonical → this entity?" |
| ⑧ | File Manifest | BE Dev + FE Dev | "What files to create, exact paths?" |
| ⑨ | Approval Config | User | "Review and confirm DB seed config" |
| ⑩ | BE→FE Contract | FE Dev | "What will the backend expose?" |
| ⑪ | Acceptance Criteria | Verification | "How to verify it works?" |
| ⑫ | Special Notes | All agents | "What's easy to get wrong? Service placeholders?" |
