# Screen Prompt Template — FLOW (v2)

> For screens that use a **view-page.tsx** with 3 URL modes and 2 distinct UI layouts.
> Canonical reference: `SavedFilter` (FLOW).
>
> Use this when: workflow/transactional screens where add/edit/read are full pages (not modals),
> URL carries `?mode=new`, `?mode=edit&id=X`, or `?mode=read&id=X`.
>
> **The read layout is a DIFFERENT UI from the form** — not the form in disabled state.
> Do NOT use for modal-form CRUD screens (use `_MASTER_GRID.md`).

---

## Template

```markdown
---
screen: {EntityName}
registry_id: {#}
module: {Module Name}
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: FLOW
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + FORM layout + DETAIL layout)
- [x] Existing code reviewed
- [x] Business rules + workflow extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM + DETAIL layouts specified)
- [ ] User Approval received
- [ ] Backend code generated          ← skip if FE_ONLY
- [ ] Backend wiring complete         ← skip if FE_ONLY
- [ ] Frontend code generated (view-page with 3 modes + Zustand store) ← skip if BE_ONLY
- [ ] Frontend wiring complete        ← skip if BE_ONLY
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at correct route
- [ ] Grid loads with columns and search/filter
- [ ] `?mode=new` — empty FORM layout renders correctly (sections, accordions, cards)
- [ ] `?mode=edit&id=X` — FORM layout loads pre-filled with existing data
- [ ] `?mode=read&id=X` — DETAIL layout renders (multi-column cards, history, audit — NOT disabled form)
- [ ] Create flow: +Add → fill form → Save → redirects to `?mode=read&id={newId}` with detail layout
- [ ] Edit flow: detail → Edit button → FORM loads pre-filled → Save → back to detail
- [ ] FK dropdowns load via ApiSelect in the form
- [ ] Summary widgets display (if applicable)
- [ ] Grid aggregation columns show per-row values (if applicable)
- [ ] Service placeholder buttons render with toast (if applicable)
- [ ] Workflow transitions work (if applicable)
- [ ] Unsaved changes dialog triggers on back/navigate with dirty form
- [ ] DB Seed — menu visible in sidebar

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: {EntityName}
Module: {ModuleName}
Schema: {db_schema}
Group: {BackendGroupName} (e.g., GrantModels, VolModels, CaseModels, DonationModels)

Business: {Rich description — 3-5 sentences covering:
  - What the screen does (transactional workflow)
  - Who uses it (admin, staff, field agent) and when
  - Why it exists in the NGO workflow
  - How it relates to other screens in the same module
  - What the read-mode detail view conveys to the user}

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from HTML mockup. Audit columns (CreatedBy, CreatedDate, etc.) omitted — inherited from Entity base.
> **CompanyId is NOT a field** — FLOW screens get tenant from HttpContext.

Table: {schema}."{PluralTableName}"

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| {EntityName}Id | int | — | PK | — | Primary key |
| {EntityName}Code | string | 50 | YES | — | Unique, auto-generated if empty |
| {EntityName}Date | DateTime | — | YES | — | — |
| {FKField}Id | int | — | YES | {schema}.{FKTable} | FK |
| Amount | decimal(18,2) | — | YES | — | — |
| Status | string | 30 | YES | — | Workflow state |
| ... | ... | ... | ... | ... | ... |

**Child Entities** (common for FLOW — e.g., distribution rows, attachments):
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| {ChildName} | 1:Many via {EntityName}Id | {field1}, {field2} |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId | Contact | Base.Domain/Models/CorgModels/Contact.cs | GetAllContactList | ContactName | ContactResponseDto |
| CampaignId | Campaign | Base.Domain/Models/CampModels/Campaign.cs | GetAllCampaignList | CampaignName | CampaignResponseDto |
| ... | ... | ... | ... | ... | ... |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- {EntityName}Code must be unique per Company
- {Other unique field rules}

**Required Field Rules:**
- {FieldA}, {FieldB}, {FieldC} are mandatory
- {FKField}Id is mandatory FK

**Conditional Rules:**
- {If DonationMode = "Online", then Gateway + TransactionId required}
- {If Status = "Approved", then AwardedAmount must be set}

**Business Logic:**
- {e.g., "RequestedAmount must be > 0"}
- {e.g., "Sum of distribution rows must equal total Amount"}
- {e.g., "AwardedAmount only set when status is Awarded"}

**Workflow** (FLOW screens often have state machines):
- States: {Draft → Submitted → Under Review → Approved → Completed}
- Transitions: {who can trigger each transition}
- Side effects: {what happens on each transition}

{or "Workflow: None" if not applicable}

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: {Type from solution-resolver.md}
**Reason**: {why — e.g., "Transactional workflow with child distribution rows, requires full-page form + detail view"}

**Backend Patterns Required:**
- [x] Standard CRUD (11 files)
- [x] Tenant scoping (CompanyId from HttpContext)
- [ ] Nested child creation — {if has child collections}
- [ ] Multi-FK validation (ValidateForeignKeyRecord × {N})
- [ ] Unique validation — {fields}
- [ ] Workflow commands (Submit, Approve, Reject, etc.) — {if state machine}
- [ ] File upload command — {if file fields}
- [ ] Custom business rule validators — {list}

**Frontend Patterns Required:**
- [x] FlowDataTable (grid)
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (for FORM layout)
- [x] Zustand store ({entityCamelCase}-store.ts)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (with Back, Save/Edit buttons)
- [ ] Child grid inside form — {if parent-child}
- [ ] Workflow status badge + action buttons — {if workflow}
- [ ] File upload widget — {if file fields}
- [ ] Summary cards / count widgets above grid — {if mockup shows stats}
- [ ] Grid aggregation columns — {if per-row computed values}

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **CRITICAL for FLOW**: describe BOTH the FORM layout (new/edit) AND the DETAIL layout (read).
> These are different UIs — not the same component in different states.

### Grid/List View

**Display Mode** (REQUIRED — stamp one): `{table | card-grid}` (default: `table`)

- `table` → records render as dense table rows via `<AdvancedDataTable>` (default for transactional lists — donations, grants, cases).
- `card-grid` → records render as cards in a responsive grid. Filter chips, search, pagination, and toolbar actions are UNCHANGED — only the row rendering differs. Use when the mockup shows a gallery/library layout (templates with editors, campaigns with hero imagery, profile-based listings).
- **Does NOT affect the view-page.** Card-grid is listing-only. Row click navigates to `?mode=read&id={id}` (DETAIL layout) and `?mode=edit` opens the FORM layout — those are unchanged.

**Card Variant** (REQUIRED when `displayMode: card-grid` — stamp one): `{details | profile | iframe}`

| Variant | When to pick | Typical screens |
|---------|--------------|------------------|
| `details` | Row has a name, a few meta chips, and a plain-text snippet. | SMS/WhatsApp/Notification Templates, saved filters |
| `profile` | Row represents a person with avatar + name + role + inline contact actions. | Contacts, Staff, Volunteers, Members, Ambassadors |
| `iframe` | Row has rich HTML that must be visually previewed. Sandbox + lazy-load + size cap. | Email templates |

**Card Config** (REQUIRED when `displayMode: card-grid` — shape depends on variant):

*For `details`:*
```yaml
cardConfig:
  headerField: "{primary field, e.g., templateName}"
  metaFields: ["{fieldA}", "{fieldB}"]
  snippetField: "{body/description field}"
  footerField: "{modifiedAt | updatedAt}"
```

*For `profile`:*
```yaml
cardConfig:
  avatarField: "{photoUrl field | null}"
  nameField: "{full name field}"
  subtitleField: "{role/title/category}"
  metaFields: ["email", "phone"]
  contactActions: ["email", "phone", "whatsapp"]
```

*For `iframe`:*
```yaml
cardConfig:
  htmlField: "{HTML body field}"
  headerField: "{template name}"
  metaFields: ["{channel}", "{category}"]
  fallbackSnippetField: "{plain-text fallback}"
```

**Responsive breakpoints (all variants)**: 1 col (`xs`) → 2 col (`sm`) → 3 col (`lg`) → 4 col (`xl`). Card inner padding `p-4`, gap `gap-3`. Card body click → `?mode=read&id={id}`.

**Build dependency**: `card-grid` requires the `<CardGrid>` infrastructure — see `.claude/feature-specs/card-grid.md` for the full build spec. First screen to use it creates the shell + first variant; subsequent screens reuse or add new variants.

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | {Code} | {entityCamelCase}Code | text | 120px | YES | — |
| 2 | {Date} | {entityCamelCase}Date | date | 110px | YES | — |
| 3 | {Contact} | contactName | text | auto | YES | FK display |
| 4 | {Amount} | amount | currency | 120px | YES | Right-aligned |
| 5 | {Status} | status | badge | 100px | YES | Color-coded |
| ... | ... | ... | ... | ... | ... | ... |

**Search/Filter Fields**: {field1, field2, date range, status}

**Grid Actions**: View (→ read mode), Edit (→ edit mode), Delete {+ custom actions}

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL layout)

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

> **This is the most important section for FLOW screens.**
>
> One component (`view-page.tsx`) renders **3 URL modes** with **2 completely different UI layouts**:
>
> ```
> URL MODE                              UI LAYOUT
> ─────────────────────────────────     ──────────────────────────
> /entity?mode=new                  →   FORM LAYOUT  (empty form)
> /entity?mode=edit&id=243          →   FORM LAYOUT  (pre-filled, editable)
> /entity?mode=read&id=243          →   DETAIL LAYOUT (read-only, different UI)
> ```
>
> **NEW and EDIT share the same form layout** (one is empty, one is pre-filled).
> **READ has a completely different UI** — typically a multi-column detail page with
> info cards, history panels, audit trails — NOT just the form in disabled state.
>
> **WARNING**: This is where most FLOW screens fail. If this section is vague,
> the FE developer will generate a generic flat form instead of the mockup design.
> Be extremely specific about BOTH layouts.

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

> The form that opens when user clicks "+Add" (`?mode=new`) or "Edit" (`?mode=edit&id=243`).
> Built with React Hook Form. Must match the HTML mockup form design exactly.

**Page Header**: FlowFormPageHeader with Back, Save buttons + unsaved changes dialog

**Section Container Type**: {cards / accordion / tabs — as shown in mockup}

**Form Sections** (in display order from mockup):
| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | {fa-icon} | {Section Name} | {2-column / 3-column / full-width} | {expanded / collapsed by default} | {field1, field2, field3...} |
| 2 | {fa-icon} | {Section Name} | {layout} | {state} | {fields} |
| ... | ... | ... | ... | ... | ... |

**Field Widget Mapping** (all fields across all sections):
| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| {EntityName}Code | 1 | text | "Auto-generated" | max 50 | Auto if empty |
| {DateField} | 1 | datepicker | "Select date" | required | Default: today |
| {FKField}Id | 1 | ApiSelectV2 | "Select {FKEntity}" | required | Query: {GQLQueryName} |
| {ModeField} | 2 | card-selector | — | required | {N} visual cards |
| {AmountField} | 3 | number (large) | "0.00" | required, > 0 | Monospace, currency |
| {ComputedField} | 3 | readonly | — | — | Auto-calculated |
| ... | ... | ... | ... | ... | ... |

**Special Form Widgets** (if any — describe each):

- **Card Selector** (if mockup shows visual card options):
  | Card | Icon | Label | Description | Triggers |
  |------|------|-------|-------------|----------|
  | {e.g., "Online"} | {fa-globe} | {Online Payment} | {via payment gateway} | {Shows online sub-form} |
  | {e.g., "Cash"} | {fa-money-bill} | {Cash} | {cash collection} | {Shows cash sub-form} |

- **Conditional Sub-forms** (fields that appear based on a selection):
  | Trigger Field | Trigger Value | Sub-form Fields |
  |--------------|---------------|-----------------|
  | {e.g., DonationMode} | {Online} | {Gateway, TransactionId, Reference, PaymentMethod} |
  | {e.g., DonationMode} | {Cheque} | {ChequeNo, ChequeDate, Bank, BranchName, ChequeStatus} |

- **Inline Mini Display** (summary cards within form):
  | Widget | Trigger | Content |
  |--------|---------|---------|
  | {e.g., "Donor Card"} | {When ContactId is selected} | {Avatar, Name, Score, Email, Phone} |

**Child Grids in Form** (if any):
| Child | Grid Columns | Add/Edit Method | Delete | Notes |
|-------|-------------|----------------|--------|-------|
| {ChildEntity} | {col1, col2, col3} | {Inline row / Modal} | {Soft delete / Remove row} | {e.g., "Allocation status bar, add button below"} |

---

#### LAYOUT 2: DETAIL (mode=read) — DIFFERENT UI from the form

> The read-only detail page shown when user clicks a grid row (`?mode=read&id=243`).
> This is NOT the form with fields disabled — it's a **completely different layout**.
> Typically a multi-column page with info cards, summary sections, tables, and history.
> Must match the HTML mockup detail/view design exactly.

**Page Header**: FlowFormPageHeader with Back, Edit button (Edit navigates to `?mode=edit&id=243`)

**Header Actions**: {Edit (→ switches to form), Print, Send (SERVICE_PLACEHOLDER), More dropdown: Duplicate, Refund, Delete}

**Page Layout**:
| Column | Width | Cards / Sections |
|--------|-------|-----------------|
| {Left} | {2fr} | {Card 1: Summary, Card 2: Amount, Table: Distribution...} |
| {Right} | {1fr} | {Card 1: Contact, Card 2: History, Card 3: Audit Trail} |

**Left Column Cards** (in order):
| # | Card Title | Content |
|---|-----------|---------|
| 1 | {e.g., "Summary"} | {Receipt#, Date, Mode (icon+text), Type, Status (badge)} |
| 2 | {e.g., "Amount"} | {Large amount display, Exchange Rate, Base Amount, Fee, Net} |
| 3 | {e.g., "Distribution"} | {Table: Purpose, Amount, Role, Occasion} |
| 4 | {e.g., "Payment Details"} | {Dynamic fields based on payment mode} |
| ... | ... | ... |

**Right Column Cards** (in order):
| # | Card Title | Content |
|---|-----------|---------|
| 1 | {e.g., "Contact"} | {Avatar, Name, Code, Type badges, Score, Email, Phone, "View Profile" link} |
| 2 | {e.g., "History"} | {Table: Date, Amount, Purpose — past records for same FK} |
| 3 | {e.g., "Audit Trail"} | {Timeline: Created, Updated, Status changes — with timestamps} |
| ... | ... | ... |

**If mockup does NOT have a separate detail view** (some simpler FLOW screens):
> State: "No separate detail layout — use form with disabled fields in read mode."
> Wrap form in `<fieldset disabled>` with CSS override.

### Page Widgets & Summary Cards

> If the mockup shows count cards / summary widgets above the grid, define them here.

**Widgets**: {NONE | list below}

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | {e.g., "Total Donations"} | {GQL summary query field} | currency | Top-left |
| 2 | {e.g., "This Month"} | {GQL summary query field} | currency | Top-center |
| ... | ... | ... | ... | ... |

**Grid Layout Variant** (REQUIRED — applies to the INDEX grid page, not the view-page): `{grid-only | widgets-above-grid}`
- `grid-only` → FE Dev uses **Variant A**: `<FlowDataTable>` with internal header.
- `widgets-above-grid` → FE Dev uses **Variant B**: `<ScreenHeader>` + widget components + `<DataTableContainer showHeader={false}>` (the flow variant). MANDATORY to avoid duplicate headers.

**Detection cue**: if the Widgets table above has any rows → variant is `widgets-above-grid`.

**Summary GQL Query** (if widgets exist):
- Query name: `Get{EntityName}Summary`
- Returns: `{EntityName}SummaryDto` with fields matching widget values
- Added to `{EntityName}Queries.cs` alongside `GetAll` and `GetById`

### Grid Aggregation Columns

> Per-row computed values (NOT footer totals). Implement via LINQ subquery or PGFunction.

**Aggregation Columns**: {NONE | list below}

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| {e.g., "Total Donations"} | Sum of donations for this contact | SUM(Amount) WHERE ContactId = row.ContactId | LINQ subquery |
| ... | ... | ... | ... |

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User sees FlowDataTable grid → clicks "+Add" → URL: `/entity?mode=new`
   → **FORM LAYOUT** loads (empty form with sections/accordions)
2. User fills form → clicks Save → API creates record
   → URL redirects to `/entity?mode=read&id={newId}`
   → **DETAIL LAYOUT** loads (read-only cards, history, audit — DIFFERENT UI from form)
3. User clicks "Edit" button on detail page → URL: `/entity?mode=edit&id={id}`
   → **FORM LAYOUT** loads (same form as new, pre-filled with existing data)
4. User edits fields → clicks Save → API updates record
   → URL redirects to `/entity?mode=read&id={id}` → back to detail layout
5. From grid: user clicks a row → URL: `/entity?mode=read&id={id}` → detail layout
6. Back: clicks back button → URL: `/entity` (no params) → returns to grid list
7. Unsaved changes: if form is dirty and user navigates, show confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: SavedFilter (FLOW)

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

### Frontend Files (9 files — FLOW needs view-page + Zustand store)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/{group}-service/{EntityName}Dto.ts |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/{group}-queries/{EntityName}Query.ts |
| 3 | GQL Mutation | Pss2.0_Frontend/src/infrastructure/gql-mutations/{group}-mutations/{EntityName}Mutation.ts |
| 4 | Page Config | Pss2.0_Frontend/src/presentation/pages/{group}/{feFolder}/{entity-lower}.tsx |
| 5 | Index Page | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/index.tsx |
| 6 | Index Page Component | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/index-page.tsx |
| 7 | **View Page (3 modes)** | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/view-page.tsx |
| 8 | **Zustand Store** | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/{entity-lower}-store.ts |
| 9 | Route Page | Pss2.0_Frontend/src/app/[lang]/(core)/{group}/{feFolder}/{entity-lower}/page.tsx |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | {ENTITY_UPPER} operations config |
| 2 | operations-config.ts | Import + register operations |
| 3 | sidebar menu config | Menu entry under parent |
| 4 | route config | Route definition |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}

MenuName: {Entity Display Name}
MenuCode: {ENTITYUPPER}
ParentMenu: {PARENTMENUCODE}
Module: {MODULECODE}
MenuUrl: {group/feFolder/entitylower}
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: {ENTITYUPPER}
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `{EntityName}Queries`
- Mutation type: `{EntityName}Mutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAll{EntityName}List | [{EntityName}ResponseDto] | searchText, pageNo, pageSize, sortField, sortDir, isActive, dateFrom, dateTo, status |
| Get{EntityName}ById | {EntityName}ResponseDto | {entityCamelCase}Id |
| Get{EntityName}Summary | {EntityName}SummaryDto | — | ← Only if screen has summary widgets |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| Create{EntityName} | {EntityName}RequestDto | int (new ID) |
| Update{EntityName} | {EntityName}RequestDto | int |
| Delete{EntityName} | {entityCamelCase}Id | int |
| Toggle{EntityName} | {entityCamelCase}Id | int |
| {WorkflowAction}{EntityName} | {entityCamelCase}Id | int | ← Only if workflow (Submit, Approve, Reject) |

**Response DTO Fields** (what FE receives):
| Field | Type | Notes |
|-------|------|-------|
| {entityCamelCase}Id | number | PK |
| {entityCamelCase}Code | string | — |
| {entityCamelCase}Date | string (ISO date) | — |
| {fkCamelCase}Id | number | FK |
| {fkEntityCamelCase}Name | string | FK display name |
| amount | number | — |
| status | string | Workflow state |
| children | [{ChildDto}] | Nested child records if applicable |
| isActive | boolean | Inherited |
| ... | ... | ... |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/{group}/{feFolder}/{entitylower}`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with columns: {col1, col2, col3, ...}
- [ ] Search filters by: {field1, field2, date range, status}
- [ ] `?mode=new`: empty FORM renders all sections, accordions, card selectors
- [ ] Conditional sub-forms appear based on card selector choice
- [ ] Child grid add/remove works within form (if applicable)
- [ ] Computed/readonly fields auto-update (if applicable)
- [ ] Save creates record → URL changes to `?mode=read&id={newId}`
- [ ] `?mode=read&id=X`: DETAIL layout renders (multi-column cards, history, audit — NOT disabled form)
- [ ] Edit button on detail → `?mode=edit&id=X` → FORM pre-filled
- [ ] Save in edit mode updates record → back to detail layout
- [ ] FK dropdowns load data correctly (ApiSelectV2 queries fire)
- [ ] {Summary widgets show correct values — if applicable}
- [ ] {Grid aggregation columns show correct per-row values — if applicable}
- [ ] {Workflow transitions work — if applicable}
- [ ] {Service placeholder buttons render with toast — if applicable}
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] Permissions: Edit/Delete buttons respect role capabilities

**DB Seed Verification:**
- [ ] Menu appears in sidebar under {ParentMenu}
- [ ] Grid columns render correctly
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** in the table — it comes from HttpContext in FLOW screens
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout, read has DETAIL layout
- **DETAIL layout is a separate UI**, not the form disabled — do NOT just wrap form in fieldset
- {e.g., "This is the FIRST entity in the `{schema}` schema — new module infrastructure must be created first"}
- {e.g., "The ContactId FK uses CorgModels group, NOT AppModels"}
- {e.g., "For ALIGN scope: only modify existing files, do not regenerate from scratch"}

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup is in scope. List items here ONLY if they require an
> external service or infrastructure that doesn't exist in the codebase yet.

{Only list genuine external-service dependencies — leave empty if none.}
- {e.g., "⚠ SERVICE_PLACEHOLDER: 'Send Receipt' — full UI implemented. Handler uses toast because SMS/Email service layer doesn't exist yet."}

Full UI must be built (buttons, forms, modals, panels, interactions). Only the handler for the external service call is mocked.

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
```

---

## Section Purpose Summary

| # | Section | Who Reads It | What It Answers |
|---|---------|-------------|-----------------|
| ① | Identity & Context | All agents | "What am I building and why?" |
| ② | Entity Definition | BA → BE Dev | "What fields, types, and constraints?" |
| ③ | FK Resolution | BE Dev + FE Dev | "WHERE is each FK entity, HOW to query it?" |
| ④ | Business Rules | BA → BE Dev → FE Dev | "What validation, logic, and workflow?" |
| ⑤ | Classification | Solution Resolver | "FLOW patterns? (pre-answered)" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "Grid + FORM layout (new/edit) + DETAIL layout (read) + widgets" |
| ⑦ | Substitution Guide | BE Dev + FE Dev | "How to map SavedFilter → this entity?" |
| ⑧ | File Manifest | BE Dev + FE Dev | "What files (includes view-page + Zustand store)?" |
| ⑨ | Approval Config | User | "Review and confirm DB seed config" |
| ⑩ | BE→FE Contract | FE Dev | "What will the backend expose?" |
| ⑪ | Acceptance Criteria | Verification | "How to verify 3 modes + 2 layouts work?" |
| ⑫ | Special Notes | All agents | "What's easy to get wrong? Service placeholders?" |
