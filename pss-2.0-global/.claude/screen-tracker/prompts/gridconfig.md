---
screen: GridConfig
registry_id: 77
module: Settings
status: PARTIALLY_COMPLETED
scope: FULL
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
complexity: High
new_module: NO
planned_date: 2026-05-14
completed_date:
last_session_date: 2026-05-15
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid-configuration.html + custom-fields.html — Tab 2 has no dedicated mockup; derived from existing Field master entity)
- [x] Business context read (combined screen absorbs #164 Field master + #82 Custom Fields per Round-2 absorption; precedent = #76 MasterData split-panel combination)
- [x] Storage model identified (hybrid — multi-table; per-tab independent: Tab 1 acts on Grid+GridField+UserGridFilter+LayoutConfiguration JSON; Tab 2 = Field CRUD; Tab 3 = CustomField CRUD on Fields where FieldSource ≠ "Standard")
- [x] Save model chosen (Tab 1 = save-all for currently selected grid; Tab 2 = per-row CRUD via RJSF modal; Tab 3 = per-row CRUD via slide-panel)
- [x] Sensitive fields & role gates identified (BUSINESSADMIN only — IsSystem field/grid rows are read-only / non-deletable)
- [x] FK targets resolved (DataType, MasterData[FieldType], Module — paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (Session 1 — see Build Log)
- [x] Solution Resolution complete (Session 1 — all 14 OPEN issues + 4 BA gaps resolved; see Build Log § Resolver Decisions)
- [x] UX Design finalized (Session 1 — see Build Log § UX Design Summary)
- [x] User Approval received (Session 1 — Sonnet for all agents; FULL scope; REPORT/EXTERNAL_PAGE filtered from Tab 1 dropdown)
- [ ] Backend code generated — **PARTIAL**: entities + migration only (pre-existing); 25 handler/wiring/seed files still pending
- [ ] Backend wiring complete
- [ ] Frontend code generated (38 files pending)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — combined page loads at `/{lang}/setting/gridmanagement/grid` with 3 tabs
- [ ] **Tab 1 — Grid Configuration**:
  - [ ] Grid selector dropdown lists all grids (grouped by Module like the mockup); selecting a grid loads its column config
  - [ ] Column-config table renders all `GridField` rows for the selected grid with: order #, Column Name, Field Key, Visible toggle, Searchable toggle, Sortable toggle, Filter-type badge, Width input
  - [ ] Drag-to-reorder updates `OrderBy` in memory; "Save Configuration" persists new order
  - [ ] Default Sort: Primary Sort + Direction + Secondary Sort + Direction saved to `Grid.LayoutConfiguration` JSON
  - [ ] Default Filters: 0..N rows of `(field, value)` saved into `UserGridFilter` rows scoped to tenant (or to `Grid.LayoutConfiguration.defaultFilters` — see §④ decision)
  - [ ] Grid Behavior: rows-per-page, column-resize toggle, column-reorder toggle, row-selection toggle, freeze-columns count, summary-row toggle, export-columns radio — all persisted to `Grid.LayoutConfiguration`
  - [ ] "Reset to Default" reverts in-memory edits to last-saved state (with confirm)
  - [ ] "Reset All to Defaults" (page-level) reseeds the selected Grid's `GridFields` + `LayoutConfiguration` from system defaults (with type-grid-name confirm)
  - [ ] "Preview Grid" opens a modal showing a sample data-table rendered with current config (SERVICE_PLACEHOLDER: render from mock data)
  - [ ] System grids (`Grid.GridFormSchema IS NOT NULL` OR `IsSystem`) — non-system columns are editable; predefined fields (`GridField.IsPredefined=true`) cannot be removed but can be hidden
- [ ] **Tab 2 — Field Master**:
  - [ ] Lists canonical fields (`Field.FieldSource = 'Standard'`) with: FieldName, FieldCode, FieldKey, DataType.DataTypeName, IsSystem badge, FieldType (MasterData lookup), IsActive
  - [ ] +New opens RJSF modal (standard MASTER_GRID pattern) — Create/Update/Delete/Toggle map to existing handlers
  - [ ] System fields (`IsSystem=true`) — Delete blocked; Update allowed for description-only fields (TBD per business rule)
  - [ ] Search + paginate works
- [ ] **Tab 3 — Custom Fields**:
  - [ ] Sub-tabs render per entity type: Contacts / Donations / Events / Campaigns / Volunteers / Members / Organizations — each tab shows count badge
  - [ ] Lists rows filtered by `FieldSource = '{EntityType}'` (or `FieldTypeId` mapped to entity)
  - [ ] Columns: drag handle, #, Field Name, Field Key (mono), Type badge, Required, Section, Active, Sort, Actions (Edit / kebab → Deactivate / Duplicate / Delete)
  - [ ] +New Custom Field opens slide-in panel (520px right-edge) with 4 form sections: Field Definition / Field Type & Options / Validation & Behavior / Visibility Rules + live Field Preview
  - [ ] Field-type-driven conditional sub-form: Dropdown/Multi-Select/Radio → Options editor + "Link to Master Data Type" CTA + "Allow Other" toggle; Number/Currency → decimal places + min/max; Text/URL/Email/Phone → max length + regex + placeholder
  - [ ] Slide-panel save persists; Save&AddAnother resets form keeping entity tab; Cancel closes
  - [ ] Drag-reorder rows persists `OrderBy`
- [ ] Empty / loading / error states render
- [ ] DB Seed — menu visible at `Setting › Grid Management › Grid Config` (combined)
- [ ] Capability cascade: BUSINESSADMIN gets READ/CREATE/MODIFY/DELETE on all three tabs; non-BUSINESSADMIN cannot see this menu

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: GridConfig (combined: Grid Config + Field Master + Custom Fields)
Module: Settings
Schema: `sett`
Group: Setting

Business: This is the central **Grid Management** hub for tenants — a 3-tab CONFIG screen that controls how every list/grid in the application looks and behaves. **Tab 1 — Grid Configuration** lets a BUSINESSADMIN pick any grid in the system (Donation List, Contact List, Volunteer List, etc.) and customise its columns (visibility, search/sort/filter capability, width, order), default sort, default filters, and grid-wide behavior (rows-per-page, column resize, freeze columns, summary row, export scope). The output is persisted to `sett."Grids".LayoutConfiguration` JSON + per-column overrides on `sett."GridFields"` + tenant-scoped default filters on `sett."UserGridFilters"`. **Tab 2 — Field Master** is the system catalog of canonical/standard fields (`Field` rows where `FieldSource = 'Standard'`) — every grid column maps back to a Field; admins manage the master so new system fields can be added before grids reference them. **Tab 3 — Custom Fields** lets a tenant extend any first-class entity (Contact, Donation, Event, Campaign, Volunteer, Member, Organization) with extra data fields (Blood Group, Anniversary Date, Employer, etc.) — these custom fields become available for: grid columns (Tab 1 inclusion), form rendering on entity create/edit pages, search, export, and import. Edits happen weekly during onboarding and ad-hoc thereafter (e.g. a new fundraising campaign reveals a missing donor field). Mis-set columns confuse end-users but rarely break workflows; mis-set custom fields can break form rendering for an entire entity type if a required field has a bad regex or option list — risk is medium. This screen is the precedent-setter for "absorbed multi-entity CONFIG" alongside #76 MasterData (split-panel) and #85 OrgSettings (tabbed combined) — its UX must clearly signal "you are configuring three related concerns under one roof" without making any one tab feel cramped.

> **Why this section is heavier than other types**: CONFIG screens have no canonical layout —
> the design is derived from the business case. The richer §① is, the better the developer
> can design the right §⑥ blueprint.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer
> Hybrid storage — each tab operates on a different table family. The OUTER screen is one CONFIG hub, NOT a singleton.

**Storage Pattern** (REQUIRED — stamp one): `keyed-settings-rows` (hybrid: per-grid configuration + per-field master rows + per-customfield rows — none of the three tabs is a singleton, but the outer screen aggregates them as ONE tenant-level configuration surface)

**Tables touched** (all under `sett` schema):

### Tab 1 — Grid Configuration

Primary: `sett."Grids"` (one row per grid — system-wide, not per-tenant for system grids; tenant-customisable via `LayoutConfiguration` JSON)

| Field | C# Type | Required | FK | Notes |
|-------|---------|----------|----|-------|
| GridId | int | PK | — | |
| GridName | string | YES | — | TitleCase-stored |
| GridCode | string | YES | — | UPPER-stored, unique |
| GridTypeId | int | YES | sett.GridTypes | MASTER_GRID/FLOW/DASHBOARD/REPORT/CONFIG/EXTERNAL_PAGE |
| ModuleId | Guid | YES | auth.Modules | Owning module |
| LayoutConfiguration | string? (JSON) | NO | — | **Used heavily by Tab 1** — stores default sort, default filters, rows-per-page, column-resize, column-reorder, row-selection, freeze-cols, summary-row, export-cols |
| GridFormSchema | string? | NO | — | RJSF schema (MASTER_GRID only — unused by Tab 1) |
| GridAccessRules | string? | NO | — | Role gating JSON |
| GridQuickFilterSchema | string? | NO | — | Quick-filter chip schema |
| Description | string? | NO | — | |

Child: `sett."GridFields"` (one row per Grid × Field)

| Field | C# Type | Required | FK | Notes |
|-------|---------|----------|----|-------|
| GridFieldId | int | PK | — | |
| GridId | int | YES | sett.Grids | |
| FieldId | int | YES | sett.Fields | |
| IsVisible | bool | YES | — | Column visibility toggle |
| IsPredefined | bool | YES | — | System-predefined — cannot delete, can hide |
| IsSystem | bool | YES | — | System row — non-deletable |
| OrderBy | int | YES | — | Column order |
| IsPrimary | bool | YES | — | Primary identifier column |
| CompanyId | int? | NO | corg.Companies | NULL = system-wide; non-NULL = tenant override |
| Width | int? | NO | — | Pixel width (mockup uses `"120px"` strings — store as int px) |
| IsFilterable | bool | YES | — | Filterable toggle |
| FilterOperator | string? | NO | — | Filter-control type (Text/Select/DateRange/NumberRange) |
| IsAggregate | bool | YES | — | |
| AggregationType | string? | NO | — | |
| ValueSource | string? | NO | — | |
| ValueSourceParams | string? | NO | — | |
| FieldDataQuery | string? | NO | — | |
| FieldConfiguration | string? | NO | — | |
| GridComponentName | string? | NO | — | |
| ParentObject | string? | NO | — | |
| CssClass | string? | NO | — | |
| FilterTooltip | string? | NO | — | |
| DefaultOperator | string? | NO | — | |
| UseSummaryTable | bool | YES | — | |
| AggregateConfig | string? | NO | — | |

**Tab 1 also writes** `sett."UserGridFilters"` and `sett."UserGridFilterDetails"` when a default filter row is saved as a tenant-level default. ALTERNATE DESIGN (preferred for V1): store default filters inside `Grid.LayoutConfiguration.defaultFilters` JSON array — keeps Tab 1 atomic and avoids touching the per-user `UserGridFilters` table which has different semantics (user-saved-views). Flag as **ISSUE-1** for resolver.

**Tab 1 saved JSON shape** (`Grid.LayoutConfiguration`):

```json
{
  "defaultSort": [
    { "fieldKey": "donation_date", "direction": "desc" },
    { "fieldKey": "amount",        "direction": "desc" }
  ],
  "defaultFilters": [
    { "fieldKey": "status",        "operator": "equals", "value": "Active" },
    { "fieldKey": "donation_date", "operator": "preset", "value": "ThisMonth" }
  ],
  "behavior": {
    "rowsPerPage": 25,
    "enableColumnResize": true,
    "enableColumnReorder": true,
    "enableRowSelection": true,
    "freezeColumns": 2,
    "showSummaryRow": false,
    "exportColumns": "all"  // "all" | "visible"
  }
}
```

### Tab 2 — Field Master

Primary: `sett."Fields"` filtered by `FieldSource = 'Standard'`

| Field | C# Type | Required | FK | Notes |
|-------|---------|----------|----|-------|
| FieldId | int | PK | — | |
| FieldName | string | YES | — | TitleCase |
| FieldCode | string | YES | — | UPPER, unique |
| FieldKey | string | YES | — | snake_case, unique — programmatic key |
| DataTypeId | int | YES | sett.DataTypes | string/int/decimal/datetime/bool/etc. |
| FieldTypeId | int? | NO | sett.MasterData (FieldType type) | Text/Dropdown/Date/etc. |
| IsSystem | bool | YES | — | System row — non-deletable |
| FieldSource | string | YES | — | `"Standard"` for Tab 2, else entity type for Tab 3 |
| CompanyId | int? | NO | corg.Companies | NULL = system-wide |

### Tab 3 — Custom Fields

Same `sett."Fields"` table, filtered by `FieldSource IN ('Contacts','Donations','Events','Campaigns','Volunteers','Members','Organizations')` and `CompanyId = current-tenant`.

**Additional config columns** (mockup needs the following — verify they exist; otherwise propose ALIGN extension):

| Mockup Field | Suggested Persistence | Notes |
|--------------|------------------------|-------|
| Description | new `Field.Description` (nullable) | Long-form purpose text — flag **ISSUE-2** if missing |
| Form Section | new `Field.FormSection` (nullable string) | Renders the section badge ("Personal Info"/"Professional"/"Additional") |
| Options (Dropdown/Multi-Select/Radio) | new `Field.OptionsJson` (nullable string) OR new child `FieldOptions` table | JSON array of `{value, order}` — flag **ISSUE-3** |
| Link to Master Data Type | new `Field.MasterDataTypeId` (nullable FK → corg.MasterDataTypes) | When set, options come from MasterData rows |
| Allow "Other" option | new `Field.AllowOther` (bool, default false) | |
| Decimal Places / Min / Max (Number/Currency) | new `Field.NumberConfigJson` OR scattered cols | |
| Max Length / Pattern / Placeholder (Text) | new `Field.MaxLength`, `Field.RegexPattern`, `Field.Placeholder` | |
| Required / Unique / ReadOnly / ShowInGrid / ShowInFilters / IncludeInExport / IncludeInImport / Searchable | new `Field.BehaviorJson` OR 8 boolean columns | Flag **ISSUE-4** — preferred = JSON to avoid schema churn |
| Default Value | new `Field.DefaultValue` (nullable string) | |
| Visibility Rules (conditional) | new `Field.VisibilityRulesJson` | JSON array of `{field, operator, value}` |

> **Open question**: existing `CustomFieldDto.ts` and `CreateCustomField.cs` handlers already exist — does the current schema already accommodate these columns? Solution Resolver MUST inspect the existing `CustomFieldDto.ts` + `CreateCustomField` handler to compare against the mockup's field list and produce a precise ALIGN delta. Flag as **ISSUE-5**.

**Behavior summary**:
- Tab 1 = bulk-update of one Grid's columns + LayoutConfiguration JSON (save-all per-grid).
- Tab 2 = standard MASTER_GRID CRUD on `Field` (existing handlers).
- Tab 3 = standard MASTER_GRID CRUD on `Field` (filtered scope) — existing CustomField handlers may need column expansion (see ISSUE-5).

---

## ③ FK Resolution Table

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| Grid.GridTypeId | GridType | Pss2.0_Backend/.../Base.Domain/Models/SettingModels/GridType.cs | GetGridTypes (paginated) | GridTypeName | GridTypeResponseDto |
| Grid.ModuleId | Module | Pss2.0_Backend/.../Base.Domain/Models/AuthModels/Module.cs | GetModules | ModuleName | ModuleResponseDto |
| GridField.GridId | Grid | (same file as primary) | GetGrids / GetGridById | GridName | GridResponseDto |
| GridField.FieldId | Field | Pss2.0_Backend/.../Base.Domain/Models/SettingModels/Field.cs | GetFields | FieldName + FieldKey | FieldResponseDto |
| GridField.CompanyId | Company | Pss2.0_Backend/.../Base.Domain/Models/CorgModels/Company.cs | (from HttpContext — not user-selected) | — | — |
| Field.DataTypeId | DataType | Pss2.0_Backend/.../Base.Domain/Models/SettingModels/DataType.cs | GetDataTypes | DataTypeName | DataTypeResponseDto |
| Field.FieldTypeId | MasterData (FieldType type) | Pss2.0_Backend/.../Base.Domain/Models/CorgModels/MasterData.cs | GetMasterDataByMasterDataTypeCode(masterDataTypeCode: "FIELDTYPE") | DataDisplayName | MasterDataResponseDto |
| Field.MasterDataTypeId (NEW per ISSUE-3) | MasterDataType | Pss2.0_Backend/.../Base.Domain/Models/CorgModels/MasterDataType.cs | GetMasterDataTypes / GetMasterDataTypeById | MasterDataTypeName | MasterDataTypeResponseDto |
| UserGridFilter.UserId | User | (existing) | (existing) | — | — |
| UserGridFilterDetail.FieldId | Field | (same) | (same) | — | — |
| UserGridFilterDetail.ConditionalOperatorId | MasterData (ConditionalOperator type) | (same) | GetMasterDataByMasterDataTypeCode(masterDataTypeCode: "CONDITIONALOPERATOR") | DataDisplayName | MasterDataResponseDto |

**Tab 3 entity-type-tab driver** (NOT a true FK — controlled vocabulary; consider seeding as MasterData type `CUSTOMFIELDENTITY` with rows Contacts/Donations/Events/Campaigns/Volunteers/Members/Organizations to avoid hard-coding):

| Source | Display | Filter |
|--------|---------|--------|
| MasterData of type `CUSTOMFIELDENTITY` | DataDisplayName | `Field.FieldSource = DataDisplayName` |

Flag as **ISSUE-6** — Solution Resolver decides: hard-coded enum vs MasterData seeding. Preferred: MasterData (extensible).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- This is NOT a singleton CONFIG — each tab manages many rows. The "config" framing is that ONE screen surfaces THREE related concerns under one roof for the same persona (BUSINESSADMIN).
- `Grid.LayoutConfiguration` IS a per-Grid singleton — one config JSON per Grid (overwritten on save).
- `GridField` rows: one per Grid × Field. Predefined fields cannot be deleted but `IsVisible` can be toggled. Non-predefined fields can be added/removed.
- `Field` (Tab 2 + Tab 3): list-of-N. System rows (`IsSystem=true`) cannot be deleted; Tab 2 system-row Update restricted to non-key columns.
- Tab 3 custom-field uniqueness: `(CompanyId, FieldSource, FieldKey)` must be unique — prevents two `donor_blood_group` fields on Contacts.

**Required Field Rules** (per tab):

Tab 1:
- A grid must be selected before any save action enables.
- At least 1 GridField must remain `IsVisible=true` (cannot save a grid with zero visible columns).
- `LayoutConfiguration.behavior.rowsPerPage` ∈ {10, 25, 50, 100}.
- `LayoutConfiguration.behavior.freezeColumns` ∈ [0..5] and ≤ count of visible columns.

Tab 2:
- FieldName, FieldCode (auto-UPPER), FieldKey (auto-snake), DataTypeId required.
- FieldKey must be valid snake_case `^[a-z][a-z0-9_]*$`.

Tab 3:
- FieldName, FieldKey (auto from name with `custom_` prefix), FieldType (mockup uses display labels — server maps to FieldTypeId), Entity Type (`FieldSource`), Form Section required.
- If FieldType ∈ {Dropdown, Multi-Select, Radio}: either OptionsJson non-empty OR MasterDataTypeId set (exclusive — one or the other).
- If FieldType ∈ {Number, Currency}: DecimalPlaces 0..4; Min ≤ Max if both set.
- If FieldType ∈ {Text, URL, Email, Phone}: MaxLength 1..4000; RegexPattern must compile.

**Conditional Rules:**
- Tab 3 "Allow Other" toggle only available when FieldType ∈ {Dropdown, Multi-Select, Radio}.
- Tab 3 "Link to Master Data Type" CTA mutually exclusive with manual Options editor — choosing one disables the other.
- Tab 3 Default Value dropdown populated from current Options (or from Master Data values if linked) — must be one of the available options.
- Tab 3 Visibility Rules: only "show this field when {trigger} {operator} {value}" — value field is a dropdown bound to the trigger field's options OR free text if trigger is unbounded.

**Sensitive Fields**: None for this screen (no credentials/secrets). All fields are plain configuration data.

**Read-only / System-controlled Fields:**
- `Field.IsSystem = true` rows in Tab 2: FieldCode + FieldKey + DataTypeId locked; only FieldName + FieldTypeId + Description editable.
- `GridField.IsPredefined = true` rows in Tab 1: Delete blocked; `IsVisible` + `Width` + filter/search/sort flags editable.

**Dangerous Actions:**

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Reset All to Defaults (page-level — top right of Tab 1) | Resets ALL grids' GridField + LayoutConfiguration to system seeds for current tenant | Type tenant name to confirm | Log "grid config bulk reset" |
| Reset to Default (per-grid action in actions-bar) | Resets the currently-selected Grid's GridFields + LayoutConfiguration to system seed | Type grid name OR "RESET" to confirm | Log per-grid reset |
| Delete Field (Tab 2, non-system) | Hard delete — cascade-warns if any `GridField` rows reference it | Modal with cascade summary | Log |
| Delete Custom Field (Tab 3) | Hard delete; warns if any entity records have non-null values for this custom field | Modal with usage count | Log |
| Deactivate (Tab 3 kebab menu) | Soft toggle `IsActive=false` — field stays in DB but no longer rendered on forms | Confirm dialog | Log |

**Role Gating:**

| Role | Tabs Visible | Tabs Editable | Notes |
|------|--------------|---------------|-------|
| BUSINESSADMIN | 1, 2, 3 | 1, 2, 3 | Full access |
| All others | none (menu hidden) | — | This is admin-only |

**Workflow**: None (no draft → publish flow). Saves are immediate.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE`
**Storage Pattern**: `keyed-settings-rows` (hybrid multi-table — see §②)
**Save Model** (REQUIRED — stamp one):

`save-per-section` (per tab):
- Tab 1: `save-all-for-selected-grid` — one big save covering GridFields diff + LayoutConfiguration JSON
- Tab 2: per-row CRUD via RJSF modal (standard MASTER_GRID pattern)
- Tab 3: per-row CRUD via custom slide-in panel (520px right-edge)

**Reason**: Each tab is a semantically independent concern with different cardinality and edit cadence — a single page-level "Save" would be confusing (would Tab 2 changes save when I click Tab 1's Save? unclear). Per-tab save matches user mental model — "I'm configuring a grid right now" vs. "I'm adding a field to the master."

**Backend Patterns Required:**

For **Tab 1 (SETTINGS_PAGE / save-all-per-grid)**:
- [x] **NEW** `GetGridConfigurationByGridId(gridId)` query — returns `{ grid, gridFields[], layoutConfiguration }` composite DTO; includes joined Field info (FieldName, FieldKey, DataType) per GridField for table rendering
- [x] **NEW** `BulkUpdateGridConfiguration` mutation — accepts `{ gridId, gridFields[]{gridFieldId?, fieldId, isVisible, isSearchable, isSortable, isFilterable, filterOperator, width, orderBy}, layoutConfiguration{defaultSort, defaultFilters, behavior} }`. Persists in one transaction: upsert GridFields (add new, update existing, soft-delete removed), set `Grid.LayoutConfiguration` JSON
- [x] **NEW** `ResetGridConfigurationToDefaults(gridId)` mutation — reseeds GridFields from system catalog (`Field` rows in this Grid's module) + clears `LayoutConfiguration`
- [x] **NEW** `ResetAllGridConfigurationsToDefaults()` mutation — page-level reset for entire tenant
- [x] **NEW** `GetGridListGrouped` query — returns grids grouped by Module for the dropdown selector (mockup uses optgroups: Contacts / Fundraising / Communication / Organization / Field Collection / Reports / Administration)
- [x] Tenant scoping (CompanyId from HttpContext — affects `GridField.CompanyId` override layer; system rows have NULL CompanyId)

For **Tab 2 (Field Master MASTER_GRID)**:
- [x] **EXISTS** `GetFields` paginated query, `GetFieldById`, `CreateField`, `UpdateField`, `ActivateDeactivateField`, `DeleteField` — re-use as-is
- [ ] Verify `GetFields` accepts `fieldSource: "Standard"` filter param — add if missing (**ISSUE-7**)

For **Tab 3 (Custom Fields MASTER_GRID with entity-tabs)**:
- [x] **EXISTS** `GetCustomFields` (paginated, scoped to tenant), `GetCustomFieldById`, `CreateCustomField`, `UpdateCustomField`, `ActivateDeactivateCustomField`, `DeleteCustomField` — verify schema covers all mockup fields (see ISSUE-5)
- [x] **EXISTS** `AddCustomFieldGridSchema`, `UpdateCustomFieldGridSchema`, `DeleteCustomFieldGridSchema` — these likely propagate custom field to relevant Grid's GridFields. Verify behavior; document in build prompt
- [ ] **NEW** `GetCustomFieldsByEntityType(entityType)` filter variant — wraps `GetCustomFields` with a server-side filter clause; alternative = use existing query with an `entityType` arg
- [ ] **NEW** `ReorderCustomFields({customFieldId, newOrder}[])` — for drag-reorder persistence
- [ ] **NEW** `DuplicateCustomField(customFieldId)` — kebab menu "Duplicate" action; creates a deep copy with name+key suffixed

**Frontend Patterns Required:**

For **outer tab shell**:
- [x] Custom tab container at `setting/gridmanagement/grid` route — replaces existing `grid/page.tsx` body (existing page is a MASTER_GRID of grid-definitions — DELETE that body, replace with 3-tab CONFIG)
- [x] 3 tabs: Grid Config / Field Master / Custom Fields — preserve tab on URL `?tab=`
- [x] Tab-specific permissions: BUSINESSADMIN sees all; others get menu hidden (BE-enforced)

For **Tab 1**:
- [x] Grid selector (ApiSelectV2 or grouped `<select>` matching mockup optgroups) — bound to `GetGridListGrouped`
- [x] On grid change → fire `GetGridConfigurationByGridId` → load column config + behavior into local form state
- [x] Column config table with drag-reorder (use existing pattern — see `master-data-values-table.tsx` or grant-rows reorder)
- [x] Per-row toggles: Visible, Searchable, Sortable (3 checkboxes); Filter Type badge (computed from FilterOperator); Width input (px integer)
- [x] Default Sort card: 2 rows (primary + secondary), each = field dropdown + direction dropdown
- [x] Default Filters card: dynamic list with "+ Add Default Filter" button; each row = field dropdown + operator/value dropdown (operator depends on field's data type)
- [x] Grid Behavior card: settings grid with toggles + selects + radios per mockup
- [x] Bottom actions bar: Reset to Default (revert local state), Preview Grid (modal SERVICE_PLACEHOLDER), Save Configuration (commits BulkUpdateGridConfiguration)
- [x] Top-right page action: Reset All to Defaults (destructive, gated by tenant-name confirm)

For **Tab 2**:
- [x] Standard `DataTableContainer` with `MASTER_GRID` shape (re-use ContactType / DocumentType pattern)
- [x] +New opens RJSF modal (GridFormSchema GENERATE — but flagged SKIP at the wrapper CONFIG level; Tab 2 internally generates its modal schema from `GetGridByCode("FIELD_SETTING")`)
- [x] Toolbar: search + entity-source filter (Standard / Custom)
- [x] Actions: Edit (modal), Toggle Active, Delete (system rows blocked)

For **Tab 3**:
- [x] Entity-type sub-tabs (Contacts / Donations / Events / Campaigns / Volunteers / Members / Organizations) with count badges
- [x] Per-tab DataTable with custom columns matching mockup (drag handle, #, name, mono key, type badge, required icon, section badge, active chip, sort num, actions menu)
- [x] +New Custom Field opens **slide-in panel** (520px from right, NOT a modal) — see §⑥ Block A for full form
- [x] Slide-panel has 4 form sections + live Field Preview panel; conditional rendering per Field Type
- [x] Drag-reorder rows fires `ReorderCustomFields`
- [x] Kebab menu per row: Edit (open panel) / Deactivate-Activate / Duplicate / Delete

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer

### Layout Variant: tabs-only (no widgets-above; no side-panel at root level)

**Page Layout (outer)**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  📊 Grid Management                              [Reset All to Defaults]   │
│  Customize columns, fields, and tenant extensions across all grids         │
├─────────────────────────────────────────────────────────────────────────────┤
│  [ Grid Config ]  [ Field Master ]  [ Custom Fields ]                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  {active tab content}                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Container Pattern**: `tabs` (3 top-level tabs persisted via `?tab=`)

**Page Header**:
- Title: "Grid Management" (overrides individual mockup titles)
- Subtitle: "Customize columns, fields, and tenant extensions across all grids"
- Page-level action (top right): "Reset All to Defaults" (destructive — applies only when Tab 1 is active; hidden on Tab 2/3)
- Icon: `ph:table-columns` (Phosphor — matches `fa-table-columns` from mockup)

#### Section Definitions (Top-level tabs)

| # | Tab Title | Icon (Phosphor) | URL | Save Mode | Role Gate |
|---|-----------|-----------------|-----|-----------|-----------|
| 1 | Grid Config | `ph:table-columns` | `?tab=grid` (default) | save-all-per-grid | BUSINESSADMIN |
| 2 | Field Master | `ph:list-bullets` | `?tab=field` | per-row CRUD | BUSINESSADMIN |
| 3 | Custom Fields | `ph:puzzle-piece` | `?tab=customfield` | per-row CRUD | BUSINESSADMIN |

---

### Tab 1 — Grid Config (PRIMARY — the only tab with full mockup)

```
┌──── Grid Selector Card ───────────────────────────────────────────────────┐
│  Select Grid *                                                            │
│  ┌────────────────────────────────────────────────┐                       │
│  │ [optgroup: Contacts]                           │                       │
│  │   Contact List / Family List / Tags List       │                       │
│  │ [optgroup: Fundraising]                        │                       │
│  │   Donation List (selected) / Recurring / ...   │                       │
│  │ [optgroup: Communication / Organization / ...] │                       │
│  └────────────────────────────────────────────────┘                       │
└────────────────────────────────────────────────────────────────────────────┘

┌──── Column Configuration ─────────────────────  Donation List — 14 cols ─┐
│  [≡] # │ Column Name      │ Field Key        │ Vis │ Srch │ Sort │ Filter │ Width │
│  [≡] 1 │ Donation ID      │ donation_id      │ ✔   │ ✔    │ ✔   │ Text   │ 120px │
│  [≡] 2 │ Donor Name       │ donor_name       │ ✔   │ ✔    │ ✔   │ Text   │ 200px │
│  ...                                                                       │
└────────────────────────────────────────────────────────────────────────────┘

┌──── Default Sort ──────────────┐ ┌──── Default Filters ──────────────────┐
│  Sort By:     [Date ▾] [Desc ▾]│ │  [Status ▾]      [Active ▾]            │
│  Secondary:   [Amount ▾][Desc▾]│ │  [Date Range ▾]  [This Month ▾]        │
│                                │ │  [+ Add Default Filter]                │
└────────────────────────────────┘ └────────────────────────────────────────┘

┌──── Grid Behavior ────────────────────────────────────────────────────────┐
│  Rows Per Page: [25 ▾]   Enable Column Resize: [on]                       │
│  Enable Column Reorder: [on]   Enable Row Selection: [on]                 │
│  Freeze Columns: [2 ▾]   Show Summary Row: [off]                          │
│  Export Columns: (•) All columns  ( ) Visible columns only                │
└────────────────────────────────────────────────────────────────────────────┘

┌──── Actions Bar (right-aligned) ──────────────────────────────────────────┐
│  [Reset to Default]  [Preview Grid]  [Save Configuration]                 │
└────────────────────────────────────────────────────────────────────────────┘
```

**Field Mapping per Section — Tab 1**

| Section | Widget | Default | Validation | Notes |
|---------|--------|---------|------------|-------|
| Grid Selector | grouped select | first grid alphabetically | required | Bound to `GetGridListGrouped` — optgroups by Module |
| Col table — Visible | switch | from GridField.IsVisible | at-least-1 visible | If predefined, label `(predefined)` tooltip |
| Col table — Searchable | switch | derived (FilterOperator like 'Text') | only if DataType allows | |
| Col table — Sortable | switch | true | — | |
| Col table — Filter type | badge | derived from FilterOperator | — | Read-only — clicking opens filter-type popover (V2) |
| Col table — Width | number input (px) | from GridField.Width or 120 | 40..600 | Suffix "px" hint |
| Col table — Drag handle | drag indicator | — | — | DnD reorders `OrderBy` |
| Default Sort — primary field | select | first sortable column | required | Options = grid's sortable visible cols |
| Default Sort — direction | select | desc | required | asc / desc |
| Default Sort — secondary | select | "(none)" | optional | |
| Default Filters — field | select | required when row added | unique field per row | |
| Default Filters — value | select / date-range / text | required | per data type | |
| Behavior — rowsPerPage | select | 25 | enum [10,25,50,100] | |
| Behavior — column resize | switch | true | — | |
| Behavior — column reorder | switch | true | — | |
| Behavior — row selection | switch | true | — | |
| Behavior — freeze cols | select | 2 | 0..5 | |
| Behavior — summary row | switch | false | — | |
| Behavior — export cols | radio | "all" | enum [all,visible] | |

**Tab 1 Actions**:

| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Reset to Default (actions-bar) | "Reset to Default" | tertiary/outline | "Discard unsaved changes for {grid name}?" | revert local state from server snapshot |
| Preview Grid | "Preview Grid" | secondary/outline | — | Opens modal rendering a sample table with current config — SERVICE_PLACEHOLDER until real grid-preview component exists |
| Save Configuration | "Save Configuration" | primary | inline validation | `BulkUpdateGridConfiguration` mutation |
| Reset All to Defaults (page top-right) | "Reset All to Defaults" | destructive | type tenant name | `ResetAllGridConfigurationsToDefaults` mutation |

---

### Tab 2 — Field Master

```
┌──── Toolbar ───────────────────────────────────────────────────────────────┐
│  [search ⌕]                              [Source: Standard ▾]  [+ New Field]│
├────────────────────────────────────────────────────────────────────────────┤
│  Field Name      │ Field Code   │ Field Key    │ Data Type │ Type    │ Sys │ Actions │
│  Donation Amount │ DONATIONAMT  │ amount       │ Decimal   │ Currency│ ✔   │ [Edit]  │
│  Donor Name      │ DONORNAME    │ donor_name   │ String    │ Text    │ ✔   │ [Edit]  │
│  ...                                                                            │
└────────────────────────────────────────────────────────────────────────────────┘
```

Standard MASTER_GRID. Reuses RJSF modal generated from `GetGridByCode("FIELD_SETTING")`.

**Form schema fields** (RJSF):
- FieldName (text, required)
- FieldCode (text, required, UPPER on save)
- FieldKey (text, required, snake_case)
- DataTypeId (ApiSelectV2 → GetDataTypes)
- FieldTypeId (ApiSelectV2 → MasterData FIELDTYPE)
- Description (textarea)
- IsActive (switch)

**Actions per row**: Edit, Toggle Active, Delete (blocked if `IsSystem=true`).

---

### Tab 3 — Custom Fields (from custom-fields.html mockup — sub-tabs + slide-panel)

```
┌──── Toolbar ───────────────────────────────────────────────────────────────┐
│                                  [Import Fields]   [+ New Custom Field]    │
├────────────────────────────────────────────────────────────────────────────┤
│  [Contacts 8] [Donations 3] [Events 2] [Campaigns 1] [Volunteers 2] [Members 1] [Organizations 0] │
├────────────────────────────────────────────────────────────────────────────┤
│  ▣ Contacts Custom Fields                              8 fields · Drag to reorder │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │ [≡] # │ Field Name      │ Field Key       │ Type    │ Req │ Section    │ Active │ Sort │ Actions │
│  │ [≡] 1 │ Blood Group     │ blood_group     │ Dropdown│ □   │ Personal   │ ✔ Active│ 1   │ [Edit][⋮] │
│  │ [≡] 2 │ Spouse Name     │ spouse_name     │ Text    │ □   │ Personal   │ ✔ Active│ 2   │ [Edit][⋮] │
│  │ ...                                                                                            │
│  └────────────────────────────────────────────────────────────────────────────────────────────────┘
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Entity sub-tab driver**: 7 fixed entity types per mockup (Contacts/Donations/Events/Campaigns/Volunteers/Members/Organizations) — recommend seeding as MasterData type `CUSTOMFIELDENTITY` for extensibility (see ISSUE-6).

**Per-tab actions**:
- Drag-reorder a row → fires `ReorderCustomFields`
- [Edit] button OR kebab → [Edit] → opens slide-in panel for that field
- Kebab → [Deactivate] / [Activate] → fires `ActivateDeactivateCustomField`
- Kebab → [Duplicate] → fires `DuplicateCustomField`
- Kebab → [Delete] → confirm modal, then `DeleteCustomField`

**Slide-in Panel (520px right)** — opens on "+ New Custom Field" OR Edit:

```
┌─ New Custom Field                                                        [×]┐
├─────────────────────────────────────────────────────────────────────────────┤
│ FIELD DEFINITION                                                            │
│   Field Name *           [Blood Group              ]                        │
│   Field Key              [custom_blood_group       ] (auto, readonly)       │
│   Description            [Donor's blood group...   ] (textarea)             │
│   Entity Type *          [Contacts ▾]                                       │
│   Form Section *         [Personal Info ▾]                                  │
│                                                                             │
│ FIELD TYPE & OPTIONS                                                        │
│   Field Type *           [Dropdown (single select) ▾]                       │
│   Options (8)            ╔══════════════════════════════════╗                │
│                          ║ [≡] A+   [×]                     ║                │
│                          ║ [≡] A-   [×]                     ║                │
│                          ║ [≡] B+   [×]                     ║                │
│                          ║ ...                              ║                │
│                          ║ ┌─ add new option ─┐ [Add]       ║                │
│                          ╚══════════════════════════════════╝                │
│                          Or: [⇗ Link to Master Data Type]                   │
│                          [ ] Allow "Other" option                            │
│   (Number-only: Decimal Places + Min + Max)                                 │
│   (Text-only:   Max Length + Pattern + Placeholder)                         │
│                                                                             │
│ VALIDATION & BEHAVIOR                                                       │
│   [ ] Required          [ ] Unique          [ ] Read Only                   │
│   Default Value         [-- No default -- ▾]                                │
│   [✔] Show in Grid      [✔] Show in Filters [✔] Include in Export           │
│   [✔] Include in Import [ ] Searchable                                       │
│                                                                             │
│ VISIBILITY RULES (optional, advanced)                                       │
│   [Contact Type ▾] [equals ▾] [Donor ▾]  [×]                                │
│   "Only show this field when Contact Type is Donor"                         │
│   [+ Add Condition]                                                         │
│                                                                             │
│ FIELD PREVIEW                                                               │
│   ┌──────────────────────────────────────────────────────────┐              │
│   │ Blood Group                                              │              │
│   │ [Select blood group...                              ▾]   │              │
│   │ Donor's blood group for medical camp coordination        │              │
│   └──────────────────────────────────────────────────────────┘              │
├─────────────────────────────────────────────────────────────────────────────┤
│  [💾 Save Field]   [➕ Save & Add Another]   [Cancel]                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Slide-panel form sections** (4 grouped form sections + 1 preview):

| Section | Title | Icon-Color | Default-Collapsed |
|---------|-------|------------|-------------------|
| 1 | Field Definition | settings-accent | expanded |
| 2 | Field Type & Options | settings-accent | expanded |
| 3 | Validation & Behavior | settings-accent | expanded |
| 4 | Visibility Rules (optional, advanced) | muted | expanded |
| 5 | Field Preview (live, computed) | — | expanded |

**Conditional rendering rules** (based on selected FieldType):

| FieldType | Show Options Editor | Show Number Config | Show Text Config | Show "Link to Master Data" |
|-----------|---------------------|---------------------|------------------|-----------------------------|
| Text (single line) | ✕ | ✕ | ✔ | ✕ |
| Text Area | ✕ | ✕ | partial (MaxLength only) | ✕ |
| Number / Currency | ✕ | ✔ | ✕ | ✕ |
| Date / Date+Time | ✕ | ✕ | ✕ | ✕ |
| Dropdown / Multi-Select / Radio | ✔ | ✕ | ✕ | ✔ |
| Checkbox | ✕ | ✕ | ✕ | ✕ |
| Contact Lookup | ✕ | ✕ | ✕ | ✕ (entity ref instead — V2) |
| File Upload | ✕ | ✕ | ✕ | ✕ |
| URL / Email / Phone | ✕ | ✕ | ✔ | ✕ |

**Field Preview** — re-renders live from current form state:
- Label = current FieldName
- Control = renderer matching current FieldType (with current Options for dropdown)
- Hint text = current Description
- Required asterisk if Required toggle is on

**Slide-panel footer actions**:
- Save Field → `CreateCustomField` or `UpdateCustomField`, close panel
- Save & Add Another → save, reset form keeping Entity Type + Form Section selected, stay open
- Cancel → close (confirm if dirty)

---

### Shared blocks (apply to all 3 tabs)

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | Settings › Grid Management › Grid Config |
| Page title | Grid Management |
| Subtitle | Customize columns, fields, and tenant extensions across all grids |
| Right actions | Reset All to Defaults (Tab 1 only) |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading (Tab 1 — initial) | Selecting a grid | Skeleton matching column table |
| Loading (Tab 2/3) | Page load | Standard data-table skeleton |
| Empty (Tab 3 — entity has 0 fields) | No custom fields for selected entity | Centered empty state with "+Add First Field" CTA |
| Error | GET fails | Error card with retry button |
| Save error | Save fails | Inline error + toast |

---

## ⑦ Substitution Guide

> **TBD** — this is the FIRST combined CONFIG/SETTINGS_PAGE in the registry (precedent for future multi-tab combined CONFIG screens). The closest existing precedent is `masterdata.md` (split-panel combined-entity CONFIG/MASTER_GRID). When this builds, set this entry as canonical.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| MasterData (#76) | GridConfig | Combined multi-entity CONFIG precedent |
| ContactType | Field (Tab 2 only) | Inner MASTER_GRID pattern reuse |
| ContactType | CustomField (Tab 3 only) | Inner MASTER_GRID pattern reuse |
| `corg` | `sett` | DB schema (this entity) |
| `Setting` | `Setting` | Backend group |
| `setting/dataconfig/masterdata` | `setting/gridmanagement/grid` | FE route (this entity) |
| `MASTERDATA` | `GRID` | Primary MenuCode (this entity) |
| `MASTERDATATYPE` | `FIELD_SETTING` (Tab 2 hidden) + `CUSTOMFIELDS` (Tab 3 hidden) | Absorbed MenuCodes kept hidden for cascade + legacy URL |

---

## ⑧ File Manifest

### Backend Files — Tab 1 (NEW + EXISTING)

| # | File | Path | New/Modify |
|---|------|------|------------|
| 1 | Grid entity | Pss2.0_Backend/.../Base.Domain/Models/SettingModels/Grid.cs | EXISTS — no change |
| 2 | GridField entity | Pss2.0_Backend/.../Base.Domain/Models/SettingModels/GridField.cs | EXISTS — no change |
| 3 | Composite DTO `GridConfigurationResponseDto` | Pss2.0_Backend/.../Base.Application/Schemas/SettingSchemas/GridConfigurationSchemas.cs | NEW |
| 4 | `GetGridConfigurationByGridId` query | Pss2.0_Backend/.../Base.Application/Business/SettingBusiness/Grids/Queries/GetGridConfigurationByGridId.cs | NEW |
| 5 | `GetGridListGrouped` query | Pss2.0_Backend/.../Base.Application/Business/SettingBusiness/Grids/Queries/GetGridListGrouped.cs | NEW |
| 6 | `BulkUpdateGridConfiguration` command | Pss2.0_Backend/.../Base.Application/Business/SettingBusiness/Grids/Commands/BulkUpdateGridConfiguration.cs | NEW |
| 7 | `ResetGridConfigurationToDefaults` command | Pss2.0_Backend/.../Base.Application/Business/SettingBusiness/Grids/Commands/ResetGridConfigurationToDefaults.cs | NEW |
| 8 | `ResetAllGridConfigurationsToDefaults` command | Pss2.0_Backend/.../Base.Application/Business/SettingBusiness/Grids/Commands/ResetAllGridConfigurationsToDefaults.cs | NEW |
| 9 | GridQueries endpoint | Pss2.0_Backend/.../Base.API/EndPoints/Setting/Queries/GridQueries.cs | MODIFY — add 2 new fields |
| 10 | GridMutations endpoint | Pss2.0_Backend/.../Base.API/EndPoints/Setting/Mutations/GridMutations.cs | MODIFY — add 3 new fields |

### Backend Files — Tab 2 (EXISTING — no changes expected unless ISSUE-7 surfaces)

| # | File | Path | New/Modify |
|---|------|------|------------|
| 1-10 | Field CRUD (Create/Update/Toggle/Delete/Get/GetById) + DTOs + endpoints | (existing in `SettingBusiness/Fields/` and `EndPoints/Setting/{Queries,Mutations}/Field*.cs`) | EXISTS — verify only |
| 11 | (conditional) Add `fieldSource: string` filter arg to `GetFields` | (existing GetFields.cs) | MODIFY if ISSUE-7 confirmed |

### Backend Files — Tab 3 (EXISTING + ALIGN EXTENSIONS)

| # | File | Path | New/Modify |
|---|------|------|------------|
| 1-10 | CustomField CRUD + DTOs + endpoints | (existing in `SettingBusiness/CustomFields/` and `EndPoints/Setting/{Queries,Mutations}/CustomField*.cs`) | EXISTS — verify schema coverage (ISSUE-5) |
| 11 | (NEW) `ReorderCustomFields` command | …/CustomFields/Commands/ReorderCustomFields.cs | NEW |
| 12 | (NEW) `DuplicateCustomField` command | …/CustomFields/Commands/DuplicateCustomField.cs | NEW |
| 13 | (ALIGN) Field entity column additions per ISSUE-2/3/4 (Description, FormSection, OptionsJson, MasterDataTypeId, AllowOther, NumberConfigJson, MaxLength, RegexPattern, Placeholder, BehaviorJson, DefaultValue, VisibilityRulesJson) | Field.cs + FieldConfiguration.cs | MODIFY if ISSUE-2/3/4/5 confirmed; preferred = JSON columns to avoid 10+ scalar adds |
| 14 | (ALIGN) EF migration `Add_CustomField_Config_Columns` | Pss2.0_Backend/.../Base.Infrastructure/Data/Migrations/{timestamp}_Add_CustomField_Config_Columns.cs | NEW migration |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | ISettingDbContext.cs | No DbSet additions (entities exist) — only confirm existing |
| 2 | SettingDbContext.cs | (same) |
| 3 | SettingMappings.cs | NEW mapping for `GridConfigurationResponseDto` |
| 4 | DecoratorProperties.cs | No new decorator |
| 5 | GridMutations.cs / Queries.cs / CustomFieldMutations.cs | Register new commands (see file list above) |

### Frontend Files — Outer shell + Tab 1

| # | File | Path | New/Modify |
|---|------|------|------------|
| 1 | `GridConfigurationDto.ts` (Tab 1 composite DTO) | Pss2.0_Frontend/src/domain/entities/setting-service/GridConfigurationDto.ts | NEW |
| 2 | `GridConfigurationQuery.ts` (Get + Grouped) | Pss2.0_Frontend/src/infrastructure/gql-queries/setting-queries/GridConfigurationQuery.ts | NEW |
| 3 | `GridConfigurationMutation.ts` (BulkUpdate + Reset + ResetAll) | Pss2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/GridConfigurationMutation.ts | NEW |
| 4 | Outer tab shell page | Pss2.0_Frontend/src/presentation/components/page-components/setting/gridmanagement/grid-config/grid-config-page.tsx | NEW |
| 5 | Tab 1 panel | …/gridmanagement/grid-config/tabs/grid-tab.tsx | NEW |
| 6 | Tab 1 — Grid selector | …/grid-config/tabs/grid-tab/grid-selector.tsx | NEW |
| 7 | Tab 1 — Column config table | …/grid-config/tabs/grid-tab/column-config-table.tsx | NEW |
| 8 | Tab 1 — Default Sort card | …/grid-config/tabs/grid-tab/default-sort-card.tsx | NEW |
| 9 | Tab 1 — Default Filters card | …/grid-config/tabs/grid-tab/default-filters-card.tsx | NEW |
| 10 | Tab 1 — Grid Behavior card | …/grid-config/tabs/grid-tab/grid-behavior-card.tsx | NEW |
| 11 | Tab 1 — Preview modal (SERVICE_PLACEHOLDER) | …/grid-config/tabs/grid-tab/preview-grid-modal.tsx | NEW |
| 12 | Tab 1 — Reset confirm modals | …/grid-config/tabs/grid-tab/reset-confirm-modals.tsx | NEW |

### Frontend Files — Tab 2 (Field Master)

| # | File | Path | New/Modify |
|---|------|------|------------|
| 1 | `FieldDto.ts` | (existing) Pss2.0_Frontend/src/domain/entities/setting-service/FieldDto.ts | EXISTS — verify shape |
| 2 | `FieldQuery.ts` + `FieldMutation.ts` | Pss2.0_Frontend/src/infrastructure/gql-{queries,mutations}/setting-{queries,mutations}/Field{Query,Mutation}.ts | NEW (no existing FE for Field master) |
| 3 | Tab 2 panel | …/gridmanagement/grid-config/tabs/field-tab.tsx | NEW |
| 4 | Tab 2 data-table | …/grid-config/tabs/field-tab/field-data-table.tsx | NEW |
| 5 | (optional) Custom Field-master form components | …/grid-config/tabs/field-tab/components/ | NEW — only if RJSF schema cannot cover |

### Frontend Files — Tab 3 (Custom Fields)

| # | File | Path | New/Modify |
|---|------|------|------------|
| 1 | `CustomFieldDto.ts` | (existing) Pss2.0_Frontend/src/domain/entities/setting-service/CustomFieldDto.ts | EXISTS — extend per ISSUE-5 |
| 2 | `CustomFieldQuery.ts` + `CustomFieldMutation.ts` | (existing) Pss2.0_Frontend/src/infrastructure/gql-*/setting-*/CustomField{Query,Mutation}.ts | MODIFY — add Reorder + Duplicate fields |
| 3 | Tab 3 panel | …/gridmanagement/grid-config/tabs/customfield-tab.tsx | NEW |
| 4 | Tab 3 entity sub-tabs | …/customfield-tab/entity-tabs.tsx | NEW |
| 5 | Tab 3 per-entity data-table | …/customfield-tab/customfield-data-table.tsx | NEW |
| 6 | Tab 3 slide-panel container | …/customfield-tab/slide-panel/customfield-slide-panel.tsx | NEW |
| 7 | Slide-panel form sections (5 components) | …/customfield-tab/slide-panel/sections/{field-definition,field-type-options,validation-behavior,visibility-rules,field-preview}.tsx | NEW |
| 8 | Options editor (dropdown options list) | …/customfield-tab/slide-panel/components/options-editor.tsx | NEW |
| 9 | Condition row | …/customfield-tab/slide-panel/components/condition-row.tsx | NEW |

### Frontend page wrapper + routes

| # | File | Path | New/Modify |
|---|------|------|------------|
| 1 | `GridConfigPageConfig` wrapper | Pss2.0_Frontend/src/presentation/pages/setting/gridmanagement/gridconfig.tsx | NEW |
| 2 | Replace existing grid route body | Pss2.0_Frontend/src/app/[lang]/setting/gridmanagement/grid/page.tsx | MODIFY — replace `<GridPageConfig />` with `<GridConfigPageConfig />` |
| 3 | Replace field stub | Pss2.0_Frontend/src/app/[lang]/setting/gridmanagement/field/page.tsx | MODIFY — redirect to `grid?tab=field` OR render same component with tab=field default |
| 4 | Re-route legacy customfields | Pss2.0_Frontend/src/app/[lang]/setting/dataconfig/customfields/page.tsx | MODIFY — redirect to `gridmanagement/grid?tab=customfield` |
| 5 | Pages index | Pss2.0_Frontend/src/presentation/pages/index.ts | MODIFY — export `GridConfigPageConfig` |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | `GRID` (existing) — confirm; `FIELD_SETTING` — add; `CUSTOMFIELDS` — verify/add |
| 2 | operations-config.ts | Register new ops |
| 3 | Sidebar menu (DB-driven) | Seed via SQL — re-parent CUSTOMFIELDS under SET_GRIDMANAGEMENT; ensure GRID is primary leaf; FIELD_SETTING kept seeded as hidden |

### DB Seed (SQL script)

| File | Purpose |
|------|---------|
| Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/gridconfig-sqlscripts.sql | Re-parent CUSTOMFIELDS menu under SET_GRIDMANAGEMENT (currently under SET_DATACONFIG per #82); ensure CUSTOMFIELDENTITY MasterDataType + 7 rows seeded (Contacts/Donations/Events/Campaigns/Volunteers/Members/Organizations); ensure CONDITIONALOPERATOR MasterDataType exists for visibility-rules; ensure FIELDTYPE MasterDataType has all 15 rows from mockup; verify Grid + GridField default-seed for newly tenanted companies; Grid GRIDFORMSCHEMA generation skipped for this CONFIG. **Pattern**: idempotent + sectioned per the SmsSetup/MasterData precedent. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by `/plan-screens`.

```
---CONFIG-START---
Scope: FULL

MenuName: Grid Config
MenuCode: GRID
ParentMenu: SET_GRIDMANAGEMENT
Module: SETTING
MenuUrl: setting/gridmanagement/grid
GridType: CONFIG

MenuCapabilities: READ, CREATE, MODIFY, DELETE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE

GridFormSchema: SKIP
GridCode: GRID

---ABSORBED-MENUS---
# These menus point to the SAME combined screen — seeded but kept hidden (IsLeastMenu=false)
# for capability cascade + legacy URL preservation. Pattern mirrors #76 MasterData → MASTERDATATYPE.

- MenuCode: FIELD_SETTING
  ParentMenu: SET_GRIDMANAGEMENT
  MenuUrl: setting/gridmanagement/grid?tab=field
  IsLeastMenu: false
  OrderBy: 2
  Status: hidden

- MenuCode: CUSTOMFIELDS
  ParentMenu: SET_GRIDMANAGEMENT  (RE-PARENT from current SET_DATACONFIG)
  MenuUrl: setting/gridmanagement/grid?tab=customfield
  IsLeastMenu: false
  OrderBy: 3
  Status: hidden
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query types: `GridQueries`, `FieldQueries`, `CustomFieldQueries`
- Mutation types: `GridMutations`, `FieldMutations`, `CustomFieldMutations`

### Tab 1 — Grid Configuration

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetGridListGrouped | `[GridGroupDto]` where `GridGroupDto = { moduleName, modulesIcon, grids: [{gridId, gridCode, gridName}] }` | — |
| GetGridConfigurationByGridId | `GridConfigurationResponseDto` | `gridId: Int!` |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| BulkUpdateGridConfiguration | `GridConfigurationUpdateRequestDto` | `GridConfigurationResponseDto` (refreshed) |
| ResetGridConfigurationToDefaults | `gridId: Int!` | `GridConfigurationResponseDto` |
| ResetAllGridConfigurationsToDefaults | — | `Boolean` |

**`GridConfigurationResponseDto` shape**:

```ts
{
  gridId: number;
  gridCode: string;
  gridName: string;
  moduleId: string;       // Guid
  moduleName: string;
  gridFields: Array<{
    gridFieldId: number | null;   // null = new (not yet persisted)
    fieldId: number;
    fieldName: string;            // joined from Field
    fieldKey: string;             // joined from Field
    dataTypeName: string;         // joined from Field.DataType
    isVisible: boolean;
    isSearchable: boolean;        // derived from FilterOperator OR new column
    isSortable: boolean;          // derived from data type
    isFilterable: boolean;
    filterOperator: string | null; // "Text" | "Select" | "DateRange" | "NumberRange"
    width: number | null;          // px
    orderBy: number;
    isPredefined: boolean;
    isSystem: boolean;
  }>;
  layoutConfiguration: {
    defaultSort: Array<{ fieldKey: string; direction: "asc" | "desc" }>;
    defaultFilters: Array<{ fieldKey: string; operator: string; value: any }>;
    behavior: {
      rowsPerPage: 10 | 25 | 50 | 100;
      enableColumnResize: boolean;
      enableColumnReorder: boolean;
      enableRowSelection: boolean;
      freezeColumns: number; // 0..5
      showSummaryRow: boolean;
      exportColumns: "all" | "visible";
    };
  };
}
```

### Tab 2 — Field Master

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetFields (existing) | `PagedListOf<FieldResponseDto>` | `pageNo: Int!, pageSize: Int!, fieldSource: String` ← **VERIFY** filter arg exists; add if missing |
| GetFieldById (existing) | `FieldResponseDto` | `fieldId: Int!` |

**Mutations** — existing: CreateField, UpdateField, ActivateDeactivateField, DeleteField — verify signatures match `FieldRequestDto` containing all `Field.cs` columns.

### Tab 3 — Custom Fields

**Queries** (EXISTING — verify):

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetCustomFields | `PagedListOf<CustomFieldResponseDto>` | `pageNo, pageSize, fieldSource?, searchText?` |
| GetCustomFieldById | `CustomFieldResponseDto` | `customFieldId: Int!` |

**Mutations**:

| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| CreateCustomField | `CustomFieldRequestDto` | `Int` (id) | EXISTS — verify request DTO covers all mockup fields (ISSUE-5) |
| UpdateCustomField | `CustomFieldRequestDto` | `Int` | EXISTS |
| DeleteCustomField | `customFieldId: Int!` | `Int` | EXISTS |
| ActivateDeactivateCustomField | `customFieldId: Int!, isActive: Boolean!` | `Int` | EXISTS |
| ReorderCustomFields | `[{customFieldId, orderBy}]` | `Boolean` | **NEW** |
| DuplicateCustomField | `customFieldId: Int!` | `Int` (new id) | **NEW** |

**`CustomFieldResponseDto` expected shape** (verify against existing `CustomFieldDto.ts`):

```ts
{
  customFieldId: number;
  fieldName: string;
  fieldKey: string;             // auto-prefixed "custom_"
  description: string | null;
  fieldSource: string;          // "Contacts" | "Donations" | "Events" | ...
  formSection: string | null;
  fieldTypeCode: string;        // "TEXT" | "TEXTAREA" | "NUMBER" | "CURRENCY" | "DATE" | "DATETIME" | "DROPDOWN" | "MULTISELECT" | "CHECKBOX" | "RADIO" | "CONTACTLOOKUP" | "FILE" | "URL" | "EMAIL" | "PHONE"
  fieldTypeId: number;          // FK → MasterData(FIELDTYPE)
  optionsJson: string | null;       // for dropdown/multi/radio
  masterDataTypeId: number | null;  // alt to optionsJson
  allowOther: boolean;
  numberConfig: { decimalPlaces, min, max } | null;
  textConfig: { maxLength, regexPattern, placeholder } | null;
  behavior: {
    required: boolean; unique: boolean; readOnly: boolean;
    showInGrid: boolean; showInFilters: boolean;
    includeInExport: boolean; includeInImport: boolean;
    searchable: boolean;
  };
  defaultValue: string | null;
  visibilityRules: Array<{ field: string; operator: string; value: any }> | null;
  orderBy: number;
  isActive: boolean;
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/setting/gridmanagement/grid` and renders 3 tabs

**Functional Verification (Full E2E — MANDATORY):**

### Tab 1 — Grid Configuration
- [ ] Grid selector loads grouped options matching mockup's optgroups
- [ ] Selecting a different grid reloads the column config (no stale state)
- [ ] Drag-to-reorder updates row OrderBy in memory
- [ ] Toggling Visible / Searchable / Sortable / Filterable marks dirty
- [ ] Width input accepts 40..600 px integer (validation error otherwise)
- [ ] Default Sort field list updates dynamically when columns become visible/hidden
- [ ] Default Filters "+ Add" adds a new row; "×" removes a row; max 5 rows
- [ ] Grid Behavior toggles + dropdowns persist on Save Configuration
- [ ] Export Columns radio shows current value on reload
- [ ] Save Configuration fires `BulkUpdateGridConfiguration` with diff payload (added / updated / removed gridFields + layoutConfiguration)
- [ ] At least 1 column must remain Visible — validator blocks save otherwise
- [ ] Predefined GridFields cannot be removed; visibility toggle still works
- [ ] System rows in GridField (IsSystem=true) — locked state visible
- [ ] Reset to Default reverts in-memory edits to last-saved snapshot (no server call)
- [ ] Reset All to Defaults gated by type-tenant-name confirm; on confirm fires `ResetAllGridConfigurationsToDefaults`
- [ ] Preview Grid opens modal (SERVICE_PLACEHOLDER — toast "Preview coming soon" OR mock-data table)

### Tab 2 — Field Master
- [ ] List loads with `fieldSource = "Standard"` filter
- [ ] +New opens RJSF modal generated from `GetGridByCode("FIELD_SETTING")`
- [ ] CreateField persists; new row appears in grid
- [ ] System rows (`IsSystem=true`) — Delete blocked, Edit allows non-key cols only
- [ ] Search narrows list; pagination works
- [ ] Toggle Active flips `IsActive` flag; row visibly updates

### Tab 3 — Custom Fields
- [ ] Entity sub-tabs render with count badges from `GetCustomFields` per entity
- [ ] Tab switch changes filter; data-table reloads
- [ ] +New Custom Field opens slide-in panel from right edge (520px)
- [ ] Field Definition section: FieldName auto-derives FieldKey with `custom_` prefix
- [ ] Field Type selector triggers conditional sub-form (Options / Number config / Text config)
- [ ] Options editor: Add/remove/drag-reorder options; "Link to Master Data Type" CTA navigates or opens picker
- [ ] Allow "Other" toggle persists
- [ ] Validation toggles all persist
- [ ] Visibility Rules: Add Condition adds row; Remove × removes; hint shows narrated rule
- [ ] Field Preview renders live (label, control, hint, required asterisk)
- [ ] Save Field closes panel; new row appears in grid
- [ ] Save & Add Another keeps panel open, resets form (preserves Entity Type + Form Section)
- [ ] Drag-reorder rows fires `ReorderCustomFields`
- [ ] Kebab menu: Edit (re-opens panel with values), Deactivate (toggles IsActive), Duplicate (creates copy with name+key suffix), Delete (confirm modal then mutation)
- [ ] Slide-panel Cancel with dirty state shows "Discard unsaved changes?" confirm

**DB Seed Verification:**
- [ ] Menu `GRID` visible under Settings › Grid Management
- [ ] Menus `FIELD_SETTING` and `CUSTOMFIELDS` exist but NOT visible in sidebar (IsLeastMenu=false)
- [ ] Existing CustomFields URL `setting/dataconfig/customfields` redirects to new location
- [ ] CUSTOMFIELDENTITY MasterDataType seeded with 7 rows
- [ ] FIELDTYPE MasterDataType has all 15 types from mockup
- [ ] Sample tenant gets default Grid + GridField rows for at least Donation List + Contact List for first-load demo

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Universal CONFIG warnings:**
- This is a 3-tab combined CONFIG screen — **single FE route hosts 3 distinct UIs**. The tab shell is the "config record"; each tab persists to different tables. Don't model this as 3 separate screens that happen to share a sidebar entry — model it as ONE screen with 3 internal save flows.
- CompanyId is NOT a form field — comes from HttpContext for all tenant-scoped writes (custom fields, tenant GridField overrides).
- This screen has NO singleton record — `keyed-settings-rows` storage pattern is the closest match.
- GridFormSchema = SKIP at the wrapper level. Tab 2 internally generates a modal RJSF schema from `GetGridByCode("FIELD_SETTING")` — that's an inner detail of Tab 2, NOT a property of the wrapper CONFIG.
- BUSINESSADMIN role only — menu must be hidden for all other roles.

**Module / module-instance notes:**
- This screen REPLACES the existing `setting/gridmanagement/grid/page.tsx` (which currently is a MASTER_GRID listing all Grids in the system). The existing functionality (managing grid definitions) is NOT part of #77 — verify with Solution Resolver whether the prior "list of all grids" CRUD is genuinely deprecated by this absorption OR needs a hidden admin-only sub-page (likely **deprecated** — Tab 1 selects a grid by dropdown for config; there's no UX for adding/removing grids in the absorbed screen). Flag as **ISSUE-8**.
- The existing `setting/dataconfig/customfields` page (built by #82) MUST be redirected — the menu re-parent + URL redirect must work for users with bookmarks.

**ALIGN deltas (existing code that needs change)**:
- Existing `grid/page.tsx` — replace with new combined component
- Existing `field/page.tsx` — currently `UnderConstruction` stub → swap to combined component (Tab 2 default)
- Existing `customfields` page → redirect or swap to combined component (Tab 3 default)
- Existing `CustomFieldDto.ts` + handlers may need column additions (ISSUE-5)

**Service Dependencies** (UI-only — no backend service implementation):
- ⚠ **SERVICE_PLACEHOLDER**: "Preview Grid" in Tab 1 actions-bar — full UI implemented; handler renders a stub data-table with mock rows OR shows a toast. A real grid-preview component (rendering a live `DataTableContainer` with current config + mock data) is V2 scope.
- ⚠ **SERVICE_PLACEHOLDER**: "Import Fields" in Tab 3 header (top-right) — full button rendered; click opens a "coming soon" toast. CSV import service for custom fields is V2.
- ⚠ **SERVICE_PLACEHOLDER**: "Reset All to Defaults" (page-level Tab 1 action) — UI + confirm modal implemented; handler calls `ResetAllGridConfigurationsToDefaults` if seeded defaults exist; otherwise toast "no defaults available".

Full UI must be built for all three placeholders — only the underlying handler is mocked.

### § Known Issues (pre-flagged for build session)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | medium | BE Tab 1 | Default filters: persist into `Grid.LayoutConfiguration.defaultFilters` JSON (V1 preferred) vs. `UserGridFilters` rows (more flexible but semantically conflated with user-saved-views). Resolver to confirm. | OPEN |
| ISSUE-2 | low | BE Tab 3 | `Field.Description` column likely missing — needs ALIGN extension OR confirm if `FieldConfiguration` JSON serves the purpose. | OPEN |
| ISSUE-3 | medium | BE Tab 3 | `OptionsJson` storage decision — single JSON column on `Field` (simple) vs. child `FieldOptions` table (queryable). Recommend JSON for V1. | OPEN |
| ISSUE-4 | medium | BE Tab 3 | 8 behavior booleans + 4 number-config + 3 text-config + visibility-rules — preferred = JSON columns (`BehaviorJson`, `NumberConfigJson`, `TextConfigJson`, `VisibilityRulesJson`) to avoid 15+ scalar additions. Resolver to confirm. | OPEN |
| ISSUE-5 | HIGH | BE Tab 3 | Existing `CustomFieldDto.ts` + `CreateCustomField.cs` may not cover all mockup fields. Solution Resolver MUST diff existing DTO against mockup field list and produce precise ALIGN delta before build. | OPEN |
| ISSUE-6 | low | BE Tab 3 | Entity-type tabs: hard-coded enum vs. MasterData type `CUSTOMFIELDENTITY`. Recommend MasterData seeding for extensibility. | OPEN |
| ISSUE-7 | low | BE Tab 2 | `GetFields` query may not accept `fieldSource` filter arg. Verify; add if missing. | OPEN |
| ISSUE-8 | medium | scope | Existing `grid/page.tsx` is a MASTER_GRID listing all Grids. Confirm with user: is grid-definition CRUD genuinely deprecated by #77, or does it need to live in a separate hidden admin screen? Default assumption: deprecated. | OPEN |
| ISSUE-9 | low | UX | Mockup `grid-configuration.html` only shows ONE tab; Tabs 2 + 3 are derived from `custom-fields.html` + Field domain knowledge. UX Architect should validate tab structure with the user before committing to the 3-tab shell. | OPEN |
| ISSUE-10 | low | BE Tab 1 | Width is shown as string `"120px"` in mockup; persist as `int` (pixels) per `GridField.Width: int?` — FE formats with `px` suffix on display. | OPEN |
| ISSUE-11 | low | BE Tab 1 | "Searchable" toggle has no direct column on GridField (existing `IsFilterable` covers filter; search is a separate concept). Add `IsSearchable` column or derive from `FilterOperator IN ('Text')` — Resolver to confirm. | OPEN |
| ISSUE-12 | low | seed | Migrating existing `CUSTOMFIELDS` menu from `SET_DATACONFIG` (its current parent per #82 build) to `SET_GRIDMANAGEMENT` requires preserving capability cascade and URL redirect for live tenants. Seed script must be idempotent and handle re-parent gracefully. | OPEN |
| ISSUE-13 | low | UX | Tab 3 entity-tabs use icons (users / heart / calendar / bullhorn / hands-helping / id-card / building). Map each to Phosphor: ph:users / ph:hand-heart / ph:calendar / ph:megaphone-simple / ph:hands-clapping / ph:identification-card / ph:buildings. Verify icon availability before build. | OPEN |
| ISSUE-14 | medium | BE Tab 1 | `BulkUpdateGridConfiguration` must be transactional — partial save (e.g. GridField updates persist but LayoutConfiguration fails) leaves grid in inconsistent state. Wrap in EF transaction. | RESOLVED — Session 1 (must wrap in `BeginTransactionAsync` + Commit/Rollback) |
| ISSUE-15 | high | session/tooling | Both BE + FE codegen agents stalled with 0 files written in Session 1 — dense mega-prompts (~6KB each, full DTOs inline) triggered stream-idle timeout on Sonnet. Recovery: split into 4-5 smaller spawns OR work inline. Affects ALL future builds for screens of this size. | OPEN — see [[feedback_long_agent_prompts_stall]] memory |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

See §⑫ table above (ISSUE-1 through ISSUE-14 pre-flagged at plan time).

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-15 — BUILD — PARTIAL

- **Scope**: Initial full build attempt from PROMPT_READY. User approved FULL scope with Sonnet for all agents and Tab 1 grid-dropdown filter excluding REPORT + EXTERNAL_PAGE.
- **Files touched**:
  - BE: `Pss2.0_Backend/.../Base.Domain/Models/SettingModels/Field.cs` (pre-existing — already had 10 new columns + MasterDataType nav from prior unrelated commit), `Pss2.0_Backend/.../Base.Domain/Models/SettingModels/GridField.cs` (pre-existing — already had IsSearchable from prior unrelated commit), `Pss2.0_Backend/.../Base.Infrastructure/Migrations/20260515112500_Add_CustomField_Config_Columns.cs` + `.Designer.cs` (pre-existing from prior unrelated commit)
  - FE: None (zero FE code generated in this session)
  - DB: None (seed script not yet written)
  - Tracking: `.claude/screen-tracker/prompts/gridconfig.md` (this file — Phase 1 task checkboxes + Build Log entry); `.claude/screen-tracker/REGISTRY.md` (status PROMPT_READY → PARTIALLY_COMPLETED)
- **Deviations from spec**: None. All Phase 1 outputs (BA, Resolver, UX) align with the original prompt + resolved 14 OPEN issues and 4 BA-surfaced gaps in line with the prompt's recommended defaults.
- **Known issues opened**: ISSUE-15 (CRITICAL — agent stall pattern; see Known Issues table)
- **Known issues closed**: ISSUE-1, ISSUE-3, ISSUE-4, ISSUE-6, ISSUE-8, ISSUE-9, ISSUE-10, ISSUE-12, ISSUE-13, ISSUE-14 — all resolved by Session 1 Resolver. ISSUE-2, ISSUE-5, ISSUE-7, ISSUE-11 partially resolved (decisions made; pending implementation).
- **Next step**: Resume via `/continue-screen #77`. Foundation (entities + migration) is in place. Generate the remaining files per § Pending File Manifest below. Resolver decisions are pre-committed (no need to re-run BA/Resolver/UX). Recommended approach for resume session: ONE focused BE agent (file manifest is well-bounded — schemas + 8 new handlers + 7 modified handlers + GraphQL wiring + seed) and 3-4 split FE agents (tier-by-tier to avoid stall: Tier 1+2 / Tier 3 Tab 1 / Tier 4+5 Tabs 2+3 / Tier 6+7 routes+wiring).

### Session 1.1 — 2026-05-15 — SCHEMA CORRECTION — COMPLETED

- **Scope**: User caught architectural error in foundation — the 11 data-level / per-grid configuration columns added by migration `20260515112500_Add_CustomField_Config_Columns` were placed on `sett.Fields` but belong on `sett.GridFields`. Reason: the same `Field` row is reused across many grids, and per-grid usage may need different defaults/labels/validation/visibility/section/options/order. Storing on Field locks every reuse to one configuration. See [[feedback_data_level_config_on_gridfield]] memory.
- **Columns affected (moved Field → GridField)**: `Description, FormSection, OptionsJson, MasterDataTypeId, AllowOther, NumberConfigJson, TextConfigJson, BehaviorJson, DefaultValue, VisibilityRulesJson, MasterDataType` nav. (`OrderBy` column was duplicated — already exists on GridField line 11; only removed the duplicate from Field. `IsSearchable` was already correctly on GridField.)
- **Files touched**:
  - BE: `Pss2.0_Backend/.../Base.Domain/Models/SettingModels/Field.cs` (stripped lines 24-36 — removed misplaced columns + nav, kept only immutable definition props), `Pss2.0_Backend/.../Base.Domain/Models/SettingModels/GridField.cs` (added the 10 columns + MasterDataType nav after the existing `IsSearchable` declaration)
  - Migration: **NOT touched** — user will regenerate the migration `.cs` file themselves via `dotnet ef migrations` since DB is local-only.
  - Memory: `~/.claude/projects/.../memory/feedback_data_level_config_on_gridfield.md` (NEW), `MEMORY.md` index updated
- **Resolver decisions superseded by this correction** (replaces the corresponding rows in § Resolver Decisions above):
  | Topic | Old (WRONG — superseded) | New (CORRECT) |
  |-------|--------------------------|---------------|
  | Field.Description | Added as nullable column on Field | `GridField.Description` (nullable) — per-grid help text |
  | OptionsJson storage | Single `Field.OptionsJson` JSON column | `GridField.OptionsJson` JSON column (per-grid options) |
  | Behavior/Number/Text/Visibility config | 4 JSON columns on Field | 4 JSON columns on **GridField** |
  | FormSection / DefaultValue / AllowOther / MasterDataTypeId / OrderBy | (implicitly on Field via migration) | All on **GridField** (OrderBy already existed there) |
  | MasterDataType FK | `Field.MasterDataTypeId → MasterDataTypes` | `GridField.MasterDataTypeId → MasterDataTypes` |
- **Implication for CustomField handler logic in Session 2** (overrides DTO/handler guidance above):
  - `CreateCustomField` handler now writes to **TWO** tables in a single transaction:
    1. INSERT `Field` row with **only** immutable definition: `FieldName, FieldCode, FieldKey, DataTypeId, FieldSource, FieldTypeId, IsSystem=false, CompanyId=fromHttpContext`
    2. INSERT `GridField` row binding the new `FieldId` to the user-selected `GridId` with all per-grid config: `Description, FormSection, OptionsJson, MasterDataTypeId, AllowOther, NumberConfigJson, TextConfigJson, BehaviorJson, DefaultValue, VisibilityRulesJson, OrderBy, IsVisible, IsPredefined=false, IsPrimary=false, IsSystem=false, IsSearchable, IsFilterable, Width`
  - `UpdateCustomField` handler now updates **GridField** for per-grid config changes; updates **Field** ONLY when `FieldName`/`FieldCode`/`FieldKey`/`DataTypeId`/`FieldTypeId` change. (Most edits should be GridField-only.)
  - `DeleteCustomField` cascade unchanged (already soft-deletes Field + linked GridFields).
  - `DuplicateCustomField` handler — clones BOTH the Field definition AND the GridField binding for the source grid.
  - DTO `CustomFieldRequestDto` shape (in § DTO Shapes above) is **unchanged** from FE perspective — the user fills in description/default/etc. as part of creating the field on a specific grid; BE handler is responsible for splitting the persistence between the two tables.
  - DTO needs one extra field: `gridId: number` — required so BE knows which grid to bind the new GridField row to. Add to `CustomFieldRequestDto` in both BE `FieldSchemas.cs` and FE `CustomFieldDto.ts` Session 2 work.
- **Action required from user**: Regenerate the migration before Session 2 BE codegen — `dotnet ef migrations remove` (to remove the broken 20260515112500), then `dotnet ef migrations add Add_CustomField_Config_Columns` (will pick up the corrected entity shape and emit columns on GridFields). The new migration should add columns: `Description, FormSection, OptionsJson, MasterDataTypeId, AllowOther, NumberConfigJson, TextConfigJson, BehaviorJson, DefaultValue, VisibilityRulesJson` on `sett.GridFields`, plus FK `GridFields.MasterDataTypeId → MasterDataTypes.MasterDataTypeId`. (`IsSearchable` on GridFields is already correct from the broken migration; OrderBy stays on GridFields.)
- **Known issues opened**: None (correction is clean — no breakage since no handlers/queries referenced the misplaced props yet).
- **Known issues closed**: None.
- **Next step**: User regenerates migration; then Session 2 (`/continue-screen #77`) proceeds per the existing § Pending File Manifest, with the CustomField handler logic adjustments noted above.

### Session 1.2 — 2026-05-15 — REDUNDANT-COLUMN CONSOLIDATION — COMPLETED

- **Scope**: User caught a second-order issue in the Session 1.1 fix — three of the columns just moved to GridField are redundant with existing GridField columns:
  - `OptionsJson` + `MasterDataTypeId` + `MasterDataType` nav → already covered by existing `GridField.ValueSource` JSON column (encodes BOTH API-driven master data AND static options via the `apiRequestRequired` flag — see canonical examples below)
  - `IsSearchable` → already covered by existing `GridField.IsFilterable` (same concern: whether the field participates in grid quick-search / filter chips)
- **Files touched**:
  - BE: `Pss2.0_Backend/.../Base.Domain/Models/SettingModels/GridField.cs` — removed the 3 redundant columns + 1 nav. Final added column set on GridField: `Description, FormSection, AllowOther, NumberConfigJson, TextConfigJson, BehaviorJson, DefaultValue, VisibilityRulesJson` (8 columns, no nav). Comment updated to point future readers at `ValueSource` and `IsFilterable` so the redundant columns are not re-introduced.
  - Migration: **NOT touched** — user regenerates after both 1.1 and 1.2 corrections are absorbed.
  - Memory: `feedback_data_level_config_on_gridfield.md` rewritten — now leads with "use existing ValueSource for option lists, use existing IsFilterable for searchability" + the canonical ValueSource JSON shapes, and adds a "scan existing GridField columns before adding new ones" rule.
- **Canonical ValueSource JSON shapes** (replaces any need for OptionsJson + MasterDataTypeId — the FE renderer branches on `apiRequestRequired`):
  - API-driven (master data): `{"apiRequestRequired":true,"entityName":"masterDatas","valueField":"masterDataId","labelField":"dataName","orderBy":"dataName","orderDescending":false,"whereClause":null,"includeFields":[],"ruleFieldKey":"tracingStatusId","ruleFieldDataType":"Int"}`
  - API-driven (any entity, e.g., paymentModes): `{"apiRequestRequired":true,"entityName":"paymentModes","valueField":"paymentModeId","labelField":"paymentModeName","orderBy":"paymentModeName","orderDescending":false,"whereClause":null,"includeFields":[],"ruleFieldKey":"paymentModeId","ruleFieldDataType":"Int"}`
  - Static (boolean / fixed list): `{"apiRequestRequired":false,"staticOptions":[{"value":"true","label":"Yes"},{"value":"false","label":"No"}],"ruleFieldKey":"isNewContact","ruleFieldDataType":"boolean"}`
- **Resolver decisions superseded by this consolidation** (replaces the corresponding rows in § Resolver Decisions and the Session 1.1 supersession table):
  | Topic | Old (WRONG — superseded) | New (CORRECT) |
  |-------|--------------------------|---------------|
  | OptionsJson storage | `GridField.OptionsJson` JSON column | Use existing `GridField.ValueSource` (set `apiRequestRequired:false, staticOptions:[...]`) |
  | MasterDataType FK | `GridField.MasterDataTypeId → MasterDataTypes` + nav | Use existing `GridField.ValueSource` (set `apiRequestRequired:true, entityName:"masterDatas", valueField, labelField, ...`) — supports any entity, not just MasterDataTypes |
  | IsSearchable column | `GridField.IsSearchable` (NEW bool?) | Use existing `GridField.IsFilterable bool?` |
- **Implication for CustomField handler logic in Session 2** (overrides Session 1.1 list):
  - `CreateCustomField` GridField INSERT now writes: `Description, FormSection, AllowOther, NumberConfigJson, TextConfigJson, BehaviorJson, DefaultValue, VisibilityRulesJson, OrderBy, IsVisible, IsPredefined=false, IsPrimary=false, IsSystem=false, IsFilterable, ValueSource, ValueSourceParams, Width` — no `IsSearchable`, no `OptionsJson`, no `MasterDataTypeId`.
  - DTO `CustomFieldRequestDto` (BE `FieldSchemas.cs` + FE `CustomFieldDto.ts`) — DROP fields: `optionsJson`, `masterDataTypeId`, `searchable` (in `CustomFieldBehaviorDto`). ADD field: `valueSource: string | null` (raw JSON string the form serializes from a structured ValueSource builder UI). Keep all other fields from § DTO Shapes above.
  - FE Custom Fields form (Tab 3): the "Options" panel becomes a **ValueSource builder** with two modes — "From API" (renders fields for entityName/valueField/labelField/orderBy/whereClause) and "Static list" (renders the staticOptions array editor) — driven by `apiRequestRequired` toggle. Output serialized into the `valueSource` JSON string.
  - FE behavior toggles (Tab 3): drop the "Searchable" toggle from `CustomFieldBehaviorDto` UI; the existing "Filterable" toggle (binds to `isFilterable`) covers it.
- **Action required from user**: Regenerate migration AFTER absorbing both Session 1.1 and Session 1.2 corrections. The new migration `Add_CustomField_Config_Columns` should add ONLY these 8 columns to `sett.GridFields`: `Description, FormSection, AllowOther, NumberConfigJson, TextConfigJson, BehaviorJson, DefaultValue, VisibilityRulesJson`. No `IsSearchable`, no `OptionsJson`, no `MasterDataTypeId`, no FK to MasterDataTypes. (`OrderBy`, `IsFilterable`, `ValueSource`, `ValueSourceParams` already exist on GridFields — leave alone.)
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User regenerates migration; then Session 2 (`/continue-screen #77`) proceeds per the existing § Pending File Manifest, with the CustomField handler logic adjustments from BOTH Session 1.1 and Session 1.2 in effect.

### Session 1.3 — 2026-05-15 — NO NEW COLUMNS, JSON SCHEMA AT UI — COMPLETED

- **Scope**: User's final architectural call — stop touching the schema entirely. ALL newly added columns from migration `20260515112500_Add_CustomField_Config_Columns` are removed from BOTH `Field` and `GridField` entities. The per-grid Custom Field configuration is implemented purely at the UI/DTO layer using **existing** GridField columns. Migration becomes a no-op (user regenerates).
- **User intent**: "remove all the newly created columns only ui side proply impleemnt - grid,fields,gridfields,customfields,jsonschema development"
- **Files touched**:
  - BE: `Pss2.0_Backend/.../Base.Domain/Models/SettingModels/GridField.cs` — stripped the 8 columns added in Session 1.1 (Description, FormSection, AllowOther, NumberConfigJson, TextConfigJson, BehaviorJson, DefaultValue, VisibilityRulesJson) AND the IsSearchable column added by the broken migration. GridField is now back to its pre-migration shape (line 23 jumps directly from `Width` to the `// 360 degree filter config property` block).
  - BE: `Field.cs` — already clean from Session 1.1 (immutable definition props only).
  - Migration: **NOT touched** — user runs `dotnet ef migrations remove` to roll back the broken migration; next `dotnet ef migrations add` is empty since no entity has new columns.
  - Memory: `feedback_data_level_config_on_gridfield.md` rewritten with the "no new columns, JSON-schema-driven UI" rule + canonical FieldConfiguration JSON shape; `MEMORY.md` index entry updated to reflect the new policy.
- **Existing GridField columns the UI/handlers will use** (everything stays in this set — nothing else is needed):
  | Concern | Existing column |
  |---|---|
  | Per-grid form behavior (description, formSection, allowOther, defaultValue, required/readonly/hide flags, number/text validation, visibility rules) | `FieldConfiguration` (string?, JSON) — single structured blob |
  | Option list source (API or static) | `ValueSource` (string?, JSON) + `ValueSourceParams` (string?) |
  | Searchability / filter participation | `IsFilterable` (bool?) |
  | Display order | `OrderBy` (int) |
  | Column width | `Width` (int?) |
  | Visibility in grid | `IsVisible` (bool) |
  | Primary column | `IsPrimary` (bool) |
  | Default filter operator | `FilterOperator` + `DefaultOperator` (string?) |
  | Aggregation | `IsAggregate` + `AggregationType` + `AggregateConfig` |
  | CSS / component overrides | `CssClass` + `GridComponentName` + `ParentObject` |
- **Canonical `FieldConfiguration` JSON shape** (UI form serializes/deserializes; BE persists as opaque text):
  ```json
  {
    "description": "Donor's primary email — used for receipts and newsletter.",
    "formSection": "Contact Info",
    "allowOther": false,
    "defaultValue": null,
    "behavior": { "required": true, "readonly": false, "hideOnList": false, "hideOnCreate": false, "hideOnEdit": false },
    "number": { "min": null, "max": null, "step": null, "precision": null, "prefix": null, "suffix": null },
    "text": { "minLength": null, "maxLength": 100, "pattern": null, "multiline": false, "caseFormat": null },
    "visibility": { "rules": [] }
  }
  ```
- **Resolver decisions superseded** (replaces all Session 1, 1.1, 1.2 rows touching per-grid config columns):
  | Topic | Old (WRONG — superseded) | New (FINAL) |
  |-------|--------------------------|-------------|
  | Description / FormSection / AllowOther / DefaultValue / behavior+number+text+visibility configs | Separate columns on Field or GridField | All persisted as nested keys inside existing `GridField.FieldConfiguration` JSON |
  | OptionsJson / MasterDataTypeId | Separate columns + FK | Persisted in existing `GridField.ValueSource` JSON (apiRequestRequired flag branches API vs static) |
  | IsSearchable | New `bool?` column on GridField | Use existing `GridField.IsFilterable bool?` |
  | OrderBy | (unchanged) | Already exists on GridField — still used as-is |
  | Migration `Add_CustomField_Config_Columns` | Required, with corrected target table | NOT REQUIRED — user removes the broken migration; no replacement migration needed |
- **Implication for Session 2 codegen**:
  - **CustomField handler logic** simplifies dramatically:
    - `CreateCustomField`: INSERT `Field` row (immutable definition only) + INSERT `GridField` row binding to user-selected `GridId`. The GridField INSERT writes `FieldConfiguration` (JSON string serialized from typed DTO), `ValueSource` (JSON string for picklists), `OrderBy`, `IsVisible`, `IsFilterable`, `Width`, `IsPredefined=false`, `IsPrimary=false`, `IsSystem=false`, `CompanyId=fromHttpContext`. No new columns referenced anywhere.
    - `UpdateCustomField`: UPDATE `GridField` (re-serialize FieldConfiguration JSON + ValueSource JSON + scalars). UPDATE `Field` only on FieldName/FieldCode/FieldKey/DataTypeId/FieldTypeId change.
    - `DuplicateCustomField`: clone both Field row AND GridField row (FieldConfiguration JSON + ValueSource JSON copy verbatim).
    - `DeleteCustomField`: soft-delete Field + cascade soft-delete linked GridFields (unchanged from Session 1).
  - **DTO shapes**:
    - `CustomFieldRequestDto` (BE `FieldSchemas.cs` + FE `CustomFieldDto.ts`) exposes the structured JSON shape on the wire as **typed nested objects** (description, formSection, allowOther, defaultValue, behavior {…}, number {…}, text {…}, visibility {…}, plus separate valueSource: string | null, isFilterable, orderBy, width, isVisible, gridId). BE handler serializes the typed nested objects to JSON strings before persisting to FieldConfiguration; deserializes on read.
    - `GridFieldConfigDto` (used by Tab 1 GetGridConfigurationByGridId): drop the per-config column flattening; expose `fieldConfiguration: string | null` (raw JSON) OR a typed parsed shape — UX team's call (default to typed parsed shape so the UI doesn't re-parse on every render).
  - **FE Tab 3 form** is JSON-schema-driven: a structured form builder UI emits the FieldConfiguration JSON; a separate ValueSource builder (with API/Static toggle) emits the ValueSource JSON. The two get bundled into the CreateCustomField mutation along with the scalars.
  - **No EF migration needed for Session 2.** Skip any "EF entity / migration" tier from FE Developer prompts. BE Developer prompts must NOT reference removed columns (Description, FormSection, OptionsJson, MasterDataTypeId, AllowOther, NumberConfigJson, TextConfigJson, BehaviorJson, DefaultValue, VisibilityRulesJson, IsSearchable, MasterDataType nav).
  - **Tab 1 (Grid Config) and Tab 2 (Field Master)** — unchanged scope; no new columns there either.
- **Action required from user**: 
  1. `dotnet ef migrations remove` to roll back `20260515112500_Add_CustomField_Config_Columns` (or manually drop the migration file + Down() from DB if already applied).
  2. Verify `sett.Fields` and `sett.GridFields` tables have no leftover columns from the broken migration (drop `Fields.Description, Fields.FormSection, Fields.OptionsJson, Fields.MasterDataTypeId, Fields.AllowOther, Fields.NumberConfigJson, Fields.TextConfigJson, Fields.BehaviorJson, Fields.DefaultValue, Fields.VisibilityRulesJson, Fields.OrderBy, Fields.MasterDataTypeId FK, GridFields.IsSearchable` if migration was already applied).
  3. NO new `dotnet ef migrations add` needed — entities are pre-migration shape.
- **Known issues opened**: None.
- **Known issues closed**: Session 1.1 + 1.2 corrections superseded by Session 1.3 (the cleanest path); the supersession tables in those sessions are now historical context only.
- **Next step**: User confirms migration rollback complete; then Session 2 (`/continue-screen #77`) proceeds per the existing § Pending File Manifest with: (a) zero migration/EF entity work, (b) BE handlers serialize typed DTO → JSON strings into FieldConfiguration/ValueSource, (c) FE Tab 3 form is the JSON-schema-driven builder for FieldConfiguration + ValueSource.

#### § Resolver Decisions (Session 1 — copy-pastable for next session)

| Topic | Decision |
|-------|----------|
| DefaultFilters storage | `Grid.LayoutConfiguration.defaultFilters` JSON (NOT UserGridFilters table) |
| Field.Description | Added as nullable column (already in entity + migration) |
| OptionsJson storage | Single `Field.OptionsJson` JSON column (NOT child table) |
| Behavior/Number/Text/Visibility config | 4 JSON columns (`BehaviorJson`, `NumberConfigJson`, `TextConfigJson`, `VisibilityRulesJson`) — already in entity + migration |
| CustomField DTO | Replace existing — see § DTO Shapes below for new shape |
| Entity-type tabs | MasterData type `CUSTOMFIELDENTITY` with 7 rows (Contacts/Donations/Events/Campaigns/Volunteers/Members/Organizations) |
| GetFields fieldSource arg | ADD optional `string? FieldSource` param to query record + handler |
| GetCustomFields fieldSource arg | REPLACE hard-coded `"Custom"` with `string? FieldSource` arg |
| Old grid/page.tsx | DEPRECATED — body fully replaced by `<GridConfigPageConfig />` |
| Width persistence | int? (px); FE formats with `px` suffix on display |
| IsSearchable column | NEW `GridField.IsSearchable bool?` (NOT derived) — already in entity + migration |
| CUSTOMFIELDS menu | Re-parent from SET_DATACONFIG to SET_GRIDMANAGEMENT in idempotent seed |
| Tab 3 entity-tab icons | ph:users / ph:hand-heart / ph:calendar / ph:megaphone-simple / ph:hands-clapping / ph:identification-card / ph:buildings |
| BulkUpdateGridConfiguration | MUST wrap in explicit EF transaction (BeginTransactionAsync + Commit/Rollback) + validate ≥1 IsVisible server-side |
| Tab 2 cross-tenant | New Standard fields get `CompanyId` from HttpContext (tenant-additive); system rows untouched |
| GetGridListGrouped | Returns ALL system grids EXCEPT GridType IN ('REPORT', 'EXTERNAL_PAGE') — per user approval choice |
| CustomField VALUE storage | OUT OF SCOPE for #77 — usage count = `dbContext.GridFields.Count(x => x.FieldId == fieldId)`, NOT entity record count |
| Field delete cascade (Tab 2) | BLOCK + 2-step confirm modal showing usage count; on confirm, soft-delete Field + linked GridFields in same EF transaction |
| CustomField delete cascade (Tab 3) | Same pattern as Tab 2 |
| Migration name | `Add_CustomField_Config_Columns` (already created) |

#### § DTO Shapes (Session 1 — copy-pastable for next session)

**`CustomFieldDto.ts`** (REPLACE entire existing file with this shape):
```typescript
export interface CustomFieldOptionDto { value: string; label: string; order: number; }
export interface CustomFieldBehaviorDto {
  required: boolean; unique: boolean; readOnly: boolean;
  showInGrid: boolean; showInFilters: boolean;
  includeInExport: boolean; includeInImport: boolean;
  searchable: boolean;
}
export interface CustomFieldNumberConfigDto { decimalPlaces: number; min: number | null; max: number | null; }
export interface CustomFieldTextConfigDto { maxLength: number | null; regexPattern: string | null; placeholder: string | null; }
export interface CustomFieldVisibilityRuleDto { field: string; operator: string; value: any; }

export interface CustomFieldRequestDto {
  fieldName: string;
  fieldSource: string;             // "Contacts" | "Donations" | etc.
  dataTypeCode: string;
  fieldTypeCode: string;
  description: string | null;
  formSection: string | null;
  optionsJson: string | null;
  masterDataTypeId: number | null;
  allowOther: boolean;
  numberConfigJson: string | null;
  textConfigJson: string | null;
  behaviorJson: string | null;
  defaultValue: string | null;
  visibilityRulesJson: string | null;
  orderBy: number;
}
export interface CustomFieldResponseDto extends CustomFieldRequestDto {
  fieldId: number;
  fieldCode: string;
  fieldKey: string;
  isActive: boolean;
  fieldTypeId: number;
  dataTypeId: number;
}
export interface CustomFieldDto extends CustomFieldResponseDto {}

// Vestigial value DTOs — keep for backward compat but do NOT extend in #77
export interface CustomFieldValueRequestDto { customFieldValueId?: number; entityRegistryId: number; entityRecordId: number; fieldValues: any; }
export interface CustomFieldValueResponseDto extends CustomFieldValueRequestDto { customFieldValueId: number; createdDate?: string; modifiedDate?: string; }
export interface CustomFieldValueDto extends CustomFieldValueResponseDto {}
```

**`GridConfigurationDto.ts`** (NEW):
```typescript
export interface GridFieldConfigDto {
  gridFieldId: number | null;
  fieldId: number;
  fieldName: string;
  fieldKey: string;
  dataTypeName: string;
  isVisible: boolean;
  isSearchable: boolean;
  isSortable: boolean;
  isFilterable: boolean;
  filterOperator: string | null;
  width: number | null;
  orderBy: number;
  isPredefined: boolean;
  isSystem: boolean;
}
export interface GridLayoutBehaviorDto {
  rowsPerPage: 10 | 25 | 50 | 100;
  enableColumnResize: boolean;
  enableColumnReorder: boolean;
  enableRowSelection: boolean;
  freezeColumns: number;
  showSummaryRow: boolean;
  exportColumns: "all" | "visible";
}
export interface GridLayoutConfigurationDto {
  defaultSort: Array<{ fieldKey: string; direction: "asc" | "desc" }>;
  defaultFilters: Array<{ fieldKey: string; operator: string; value: any }>;
  behavior: GridLayoutBehaviorDto;
}
export interface GridConfigurationResponseDto {
  gridId: number; gridCode: string; gridName: string;
  moduleId: string; moduleName: string;
  gridFields: GridFieldConfigDto[];
  layoutConfiguration: GridLayoutConfigurationDto;
}
export interface GridConfigurationUpdateRequestDto {
  gridId: number;
  gridFields: GridFieldConfigDto[];
  layoutConfiguration: GridLayoutConfigurationDto;
}
export interface GridGroupItemDto { gridId: number; gridCode: string; gridName: string; }
export interface GridGroupDto { moduleName: string; moduleIcon: string | null; grids: GridGroupItemDto[]; }
```

#### § UX Design Summary (Session 1 — Layout Variants pre-stamped)

| Surface | Variant Stamp | Notes |
|---------|--------------|-------|
| Outer shell | `tabs-only` | ScreenHeader + 3-tab strip; conditional "Reset All to Defaults" page action visible only when `?tab=grid` |
| Tab 1 (Grid Config) | `widgets-above-grid` (Variant B) | NO ScreenHeader inside Tab 1; 6 stacked cards: Grid Selector / Column Configuration (DnD table) / Default Sort + Default Filters (side-by-side at lg) / Grid Behavior / Actions Bar |
| Tab 2 (Field Master) | `grid-only` (Variant A) | AdvancedDataTable with internal toolbar; Source: Standard|Custom|All select + +New Field |
| Tab 3 (Custom Fields) | `widgets-above-grid` (Variant B) | Toolbar + entity-sub-tab strip + DataTable + 520px Sheet slide-panel; 5 always-expanded sections (Field Definition / Field Type & Options / Validation & Behavior / Visibility Rules / Field Preview) |

**Key UX rules** (must honor in next session):
- Tab persistence: `?tab=grid|field|customfield` + Tab 3 also `?entity=contacts|donations|...`. Slide-panel state is local (NOT in URL).
- Grid selector = native `<select>` with `<optgroup>` (NOT ApiSelectV2 — doesn't support optgroups).
- Drag-reorder = `@dnd-kit/sortable` (verify in package.json before use).
- Slide-panel = Shadcn `Sheet` `side="right"` `className="w-[520px] sm:w-full max-w-full"`; body uses `ScrollArea`.
- Conditional sub-form per FieldType in slide-panel: Dropdown/MultiSelect/Radio → Options Editor + Master-Data toggle + Allow Other; Number/Currency → DecimalPlaces+Min+Max; Text/URL/Email/Phone → MaxLength+Placeholder+Regex; TextArea → MaxLength only; Date/DateTime/Checkbox/ContactLookup/File → no sub-form.
- Field Preview re-renders live from form state.
- Reuse: Sheet, Tabs, Switch, DropdownMenu, AlertDialog, ScrollArea, RadioGroup, SettingRow (from OrgSettings).

#### § Pending File Manifest (Session 2+ work)

**Backend — Schemas + Handlers + Wiring (~25 files)**

NEW handlers in `Pss2.0_Backend/.../Base.Application/Business/SettingBusiness/Grids/Queries/`:
1. `GetGridConfigurationByGridId.cs` — composite Grid + GridFields + Field details + LayoutConfiguration JSON deserialization
2. `GetGridListGrouped.cs` — joins Grid → GridType → Module; filters out REPORT + EXTERNAL_PAGE; groups by Module
3. `GetFieldGridUsageCount.cs` — count of GridFields referencing fieldId

NEW handlers in `…/Grids/Commands/`:
4. `BulkUpdateGridConfiguration.cs` — explicit EF transaction; upsert GridFields (add/update/soft-delete); set Grid.LayoutConfiguration JSON; validate ≥1 IsVisible
5. `ResetGridConfigurationToDefaults.cs` — clear LayoutConfiguration to defaults
6. `ResetAllGridConfigurationsToDefaults.cs` — page-level reset

NEW handlers in `…/CustomFields/Commands/`:
7. `ReorderCustomFields.cs` — bulk update OrderBy
8. `DuplicateCustomField.cs` — clone Field with name/key suffix

NEW schema file:
9. `…/Base.Application/Schemas/SettingSchemas/GridConfigurationSchemas.cs` — `GridConfigurationResponseDto`, `GridFieldConfigDto`, `GridLayoutConfigurationDto`, `GridLayoutBehaviorDto`, `GridConfigurationUpdateRequestDto`, `GridGroupDto`, `GridGroupItemDto`

MODIFY existing files:
10. `…/Fields/Queries/GetField.cs` — add `string? FieldSource` to query record + apply Where filter
11. `…/CustomFields/Queries/GetCustomFields.cs` — replace hard-coded `"Custom"` with `string? FieldSource` arg
12. `…/Fields/Commands/CreateField.cs` — set CompanyId from HttpContext for new Standard fields
13. `…/CustomFields/Commands/CreateCustomField.cs` — accept and persist all 10 new DTO fields
14. `…/CustomFields/Commands/UpdateCustomField.cs` — same expanded persistence (current handler reportedly only updates FieldName)
15. `…/Fields/Commands/DeleteField.cs` — pre-flight GridField usage count + cascade-soft-delete on confirm
16. `…/CustomFields/Commands/DeleteCustomField.cs` — same pattern
17. `…/Schemas/SettingSchemas/FieldSchemas.cs` — expand `CustomFieldRequestDto` with new fields

GraphQL endpoint wiring (locate exact file paths via Glob — likely under `Base.API/EndPoints/Setting/`):
18. GridQueries.cs — register GetGridConfigurationByGridId, GetGridListGrouped, GetFieldGridUsageCount
19. GridMutations.cs — register BulkUpdateGridConfiguration, ResetGridConfigurationToDefaults, ResetAllGridConfigurationsToDefaults
20. FieldQueries.cs — update GetFields signature with fieldSource arg
21. FieldMutations.cs — update CreateField/DeleteField signatures
22. CustomFieldQueries.cs — update GetCustomFields signature with fieldSource arg
23. CustomFieldMutations.cs — register Reorder + Duplicate; update Create/Update/Delete signatures
24. SettingMappings.cs — add Profile entries for Grid → GridConfigurationResponseDto and GridFieldConfigDto

DB seed:
25. `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/gridconfig-sqlscripts.sql` — idempotent: CUSTOMFIELDENTITY MasterDataType + 7 rows; verify FIELDTYPE has 15 rows; verify CONDITIONALOPERATOR; GRID menu under SET_GRIDMANAGEMENT (BUSINESSADMIN gets READ/CREATE/MODIFY/DELETE); FIELD_SETTING + CUSTOMFIELDS hidden seeded entries (re-parent CUSTOMFIELDS from SET_DATACONFIG)

**Frontend — All tiers (~38 files)**

Tier 1 — DTOs + GraphQL contracts:
1. `…/domain/entities/setting-service/GridConfigurationDto.ts` (NEW — see § DTO Shapes above)
2. `…/domain/entities/setting-service/CustomFieldDto.ts` (REPLACE — see § DTO Shapes above)
3. `…/infrastructure/gql-queries/setting-queries/GridConfigurationQuery.ts` (NEW) — GET_GRID_CONFIGURATION_BY_GRID_ID, GET_GRID_LIST_GROUPED, GET_FIELD_GRID_USAGE_COUNT
4. `…/infrastructure/gql-mutations/setting-mutations/GridConfigurationMutation.ts` (NEW) — BULK_UPDATE_GRID_CONFIGURATION, RESET_GRID_CONFIGURATION_TO_DEFAULTS, RESET_ALL_GRID_CONFIGURATIONS_TO_DEFAULTS
5. `…/infrastructure/gql-queries/setting-queries/FieldQuery.ts` (NEW) — GET_FIELDS (with fieldSource arg), GET_FIELD_BY_ID
6. `…/infrastructure/gql-mutations/setting-mutations/FieldMutation.ts` (NEW) — CREATE/UPDATE/DELETE/ACTIVATE_DEACTIVATE_FIELD
7. `…/infrastructure/gql-queries/setting-queries/CustomFieldQuery.ts` (modify if exists else NEW) — GET_CUSTOM_FIELDS with fieldSource arg
8. `…/infrastructure/gql-mutations/setting-mutations/CustomFieldMutation.ts` (modify) — add REORDER_CUSTOM_FIELDS, DUPLICATE_CUSTOM_FIELD

Tier 2 — Outer shell + page wrapper:
9. `…/presentation/components/page-components/setting/gridmanagement/grid-config/grid-config-page.tsx` (NEW) — main 3-tab orchestrator with ScreenHeader
10. `…/presentation/pages/setting/gridmanagement/gridconfig.tsx` (NEW) — `GridConfigPageConfig` wrapper
11. `…/presentation/pages/index.ts` (modify) — export `GridConfigPageConfig`

Tier 3 — Tab 1 components (8 files):
12-19. `…/grid-config/tabs/grid-tab/{grid-tab,grid-selector,column-config-table,default-sort-card,default-filters-card,grid-behavior-card,actions-bar,preview-grid-modal,reset-confirm-modals}.tsx`

Tier 4 — Tab 2 components (2 files):
20-21. `…/grid-config/tabs/field-tab/{field-tab,field-data-table}.tsx`

Tier 5 — Tab 3 components (11 files):
22-32. `…/grid-config/tabs/customfield-tab/{customfield-tab,entity-tabs,customfield-data-table}.tsx` + `…/customfield-tab/slide-panel/customfield-slide-panel.tsx` + `…/customfield-tab/slide-panel/sections/{field-definition-section,field-type-options-section,validation-behavior-section,visibility-rules-section,field-preview-panel}.tsx` + `…/customfield-tab/slide-panel/components/{options-editor,condition-row}.tsx`

Tier 6 — Page route swaps + redirects:
33. `…/app/[lang]/setting/gridmanagement/grid/page.tsx` (modify) — swap to `<GridConfigPageConfig />`
34. `…/app/[lang]/setting/gridmanagement/field/page.tsx` (modify) — Next.js `redirect` to `?tab=field`
35. `…/app/[lang]/setting/dataconfig/customfields/page.tsx` (modify) — `redirect` to `?tab=customfield`

Tier 7 — Wiring:
36. `…/infrastructure/config/entity-operations.ts` — register/verify GRID, FIELD_SETTING, CUSTOMFIELDS ops
37. `…/infrastructure/config/operations-config.ts` — register new ops where applicable
38. Verify `@dnd-kit/sortable` is in `package.json` — install if missing (drag-reorder dependency for Column Config Table + Options Editor + custom-field row drag-reorder)

#### § Resume Strategy (Session 2 — read this first)

1. Verify foundation still in place: `Read` Field.cs, GridField.cs, migration file (lines should match § Resolver Decisions table above).
2. Spawn ONE backend-developer agent with focused prompt: "Foundation done. Build files 1-25 from § Pending File Manifest. Use existing CreateCustomField.cs as handler template, FieldSchemas.cs as DTO template." Do NOT pass full DTOs inline — they're already in the prompt file.
3. Spawn 3 frontend-developer agents in sequence (NOT parallel — to avoid stall):
   - FE-A: Tier 1 + Tier 2 (DTOs + GQL contracts + outer shell) — 11 files
   - FE-B: Tier 3 (Tab 1) — 8 files  
   - FE-C: Tier 4 + Tier 5 (Tabs 2 + 3) — 13 files
   - FE-D: Tier 6 + Tier 7 (route swaps + wiring) — 6 files
4. Each agent prompt should be < 3KB (front-load file-write directive; reference this Build Log for context, do NOT re-embed decisions inline).
5. After all agents finish: full E2E test per Step 5b of /build-screen skill (3-tab page loads, Tab 1 grid selector loads grouped options, Tab 1 save persists, Tab 2 +New opens RJSF modal, Tab 3 +New Custom Field opens slide-panel from right edge, conditional sub-forms render per FieldType, drag-reorder fires Reorder mutation, delete shows usage-count modal).
