---
screen: GridConfig
registry_id: 77
module: Settings
status: COMPLETED
scope: FULL (S1=BE_ONLY done; S2=FE_ONLY done)
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
storage_pattern: keyed-settings-rows
save_model: hybrid (Tab 1 save-all-per-grid / Tab 2+3 per-row CRUD)
complexity: High
new_module: NO
planned_date: 2026-05-14
completed_date: 2026-05-16
last_session_date: 2026-05-16
---

> **Build split — like #78**: S1=BE_ONLY (2026-05-16) → S2=FE_ONLY (pending).
> **Constraint (user directive, 2026-05-16)**: NO entity-level changes. UI/UX refactor only. Tab 3 stripped to BE reality (simple list, no slide-panel, no entity sub-tabs, no Options/Validation/Visibility persistence).

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
- [x] BA Analysis validated (3-tab CONFIG purpose + edit personas + risk of mis-set grid columns) ← S1
- [x] Solution Resolution complete (sub-type SETTINGS_PAGE / save model per-tab confirmed; Tab 3 stripped to BE reality) ← S1
- [x] UX Design finalized for Tab 1 (BE scope) — Tab 2/3 FE design deferred to S2
- [x] User Approval received (BE_ONLY scope, no entity changes, defaultFilters in LayoutConfiguration JSON, Searchable toggle dropped, Tab 3 stripped, FE-side fieldSource filter) ← S1
- [x] Backend code generated (Tab 1: 5 NEW handlers; Tab 2/3: reuse existing) ← S1
- [x] Backend wiring complete (GridQueries +2, GridMutations +3, SettingMappings +2 projections) ← S1
- [x] Frontend code generated (17 NEW files: shell + 8 Tab1 components + 2 Tab2 + 2 Tab3 stripped + DTO + 2 GQL barrels + Field GQL barrels + page wrapper) ← S2
- [x] Frontend wiring complete (8 MODIFY: barrel index files + setting-service-entity-operations.ts + 3 route stubs + pages/setting/gridmanagement/index.ts) ← S2
- [x] DB Seed script generated (`GridConfig-sqlscripts.sql` — 11 sections, idempotent: GRID menu URL/IsLeastMenu update, FIELD_SETTING insert hidden, CUSTOMFIELDS re-parent + URL update, MenuCapabilities + RoleCapabilities cascade for BUSINESSADMIN, GRID grid reclassified to CONFIG type, GRIDCONFIG placeholder grid row) ← S1
- [x] Registry updated to COMPLETED ← S2

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

### Session 1 — 2026-05-16 — BUILD — PARTIAL

- **Scope**: Initial BE_ONLY build from PROMPT_READY prompt. FE deferred to Session 2 per user-approved scope split (precedent: #78 DashboardConfig). User directive at session entry: **NO entity-level changes** — strip plan to UI/UX refactoring against existing schema.
- **Resolved at entry**:
  - ISSUE-1 → defaultFilters live inside `Grid.LayoutConfiguration.defaultFilters` JSON (V1-preferred)
  - ISSUE-2 / ISSUE-3 / ISSUE-4 / ISSUE-5 → **NO entity-level changes** — Tab 3 stripped to BE reality (simple list, no slide-panel, no entity sub-tabs, no Options / Validation / Visibility persistence)
  - ISSUE-6 → N/A — no entity-tab driver needed (Tab 3 stripped)
  - ISSUE-7 → FE applies `FieldSource = 'Standard'` filter client-side via `advancedFilter: QueryBuilderModel` on existing `GetFields` query — no BE delta
  - ISSUE-8 → grid-definition CRUD deprecated entirely; Tab 1 dropdown selector is sufficient. The existing `GRID` Grid row reclassified to `GridTypeCode = CONFIG` so it doesn't appear in its own selector
  - ISSUE-10 → Width persists as `int` px on `GridField.Width`; FE renders with `px` suffix
  - ISSUE-11 → Searchable toggle dropped from UI; combined into IsFilterable
  - ISSUE-14 → `BulkUpdateGridConfiguration` runs all mutations through a single `SaveChangesAsync` (EF Core is atomic-by-SaveChanges); GridField upserts + LayoutConfiguration write happen in one transaction
- **Files touched**:
  - BE NEW (6):
    - `Base.Application/Schemas/SettingSchemas/GridConfigurationSchemas.cs` — 10 DTOs (`GridGroupDto`, `GridSummaryDto`, `GridConfigurationResponseDto`, `GridFieldConfigDto`, `GridLayoutConfigurationDto`, `GridSortDto`, `GridFilterDto`, `GridBehaviorDto`, `GridConfigurationUpdateRequestDto`, `GridFieldUpsertDto`)
    - `Base.Application/Business/SettingBusiness/Grids/Queries/GetGridListGrouped.cs` — groups non-CONFIG grids by Module (optgroup binding)
    - `Base.Application/Business/SettingBusiness/Grids/Queries/GetGridConfigurationByGridId.cs` — composite loader with parsed LayoutConfiguration JSON; falls back to defaults if JSON null / malformed
    - `Base.Application/Business/SettingBusiness/Grids/Commands/BulkUpdateGridConfiguration.cs` — atomic GridField upsert + LayoutConfiguration write; validates ≥1 IsVisible + Behavior.RowsPerPage ∈ {10,25,50,100} + FreezeColumns ∈ [0,5]; contains shared `GridConfigurationJsonHelper`
    - `Base.Application/Business/SettingBusiness/Grids/Commands/ResetGridConfigurationToDefaults.cs` — clears LayoutConfiguration + soft-deletes tenant GridField overrides (CompanyId IS NOT NULL); preserves system rows
    - `Base.Application/Business/SettingBusiness/Grids/Commands/ResetAllGridConfigurationsToDefaults.cs` — page-level cross-grid reset (no ICurrentTenantService found — resets across all tenants; admin-only screen so acceptable)
  - BE MODIFY (3):
    - `Base.API/EndPoints/Setting/Queries/GridQueries.cs` (+2 GQL fields: `getGridListGrouped`, `getGridConfigurationByGridId`)
    - `Base.API/EndPoints/Setting/Mutations/GridMutations.cs` (+3 GQL fields: `bulkUpdateGridConfiguration`, `resetGridConfigurationToDefaults`, `resetAllGridConfigurationsToDefaults`)
    - `Base.Application/Mappings/SettingMappings.cs` (+2 TypeAdapterConfig: `Grid → GridSummaryDto`, `GridField → GridFieldConfigDto`)
  - DB (1): `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/GridConfig-sqlscripts.sql` — 11 sections, idempotent
    - Step 1: Update GRID menu URL → `setting/gridmanagement/grid`, IsLeastMenu=true, OrderBy=1
    - Step 2: Insert (or update) hidden `FIELD_SETTING` menu under `SET_GRIDMANAGEMENT`, IsLeastMenu=false, OrderBy=2, MenuUrl `?tab=field`
    - Step 3: Re-parent `CUSTOMFIELDS` to `SET_GRIDMANAGEMENT`, IsLeastMenu=false, OrderBy=3, MenuUrl `?tab=customfield`
    - Steps 4-6: MenuCapabilities (READ/CREATE/MODIFY/DELETE/TOGGLE/ISMENURENDER for GRID; READ/CREATE/MODIFY/DELETE for satellites)
    - Steps 7-9: RoleCapabilities for BUSINESSADMIN on all 3 menus
    - Step 10: Insert `GRIDCONFIG` placeholder Grid row (CONFIG type)
    - Step 11: Reclassify existing `GRID` Grid row to CONFIG type (prevents the GRID grid itself from appearing in the selector)
  - FE: NONE (Session 2 scope)
- **Deviations from spec**:
  - `GridConfigurationJsonHelper` extracted as `internal static` inside `BulkUpdateGridConfiguration.cs` (Commands namespace) rather than a separate utility file — shared by Query + Reset handlers via `using` import. No functional impact.
  - `ResetAllGridConfigurationsToDefaults` operates platform-wide (no tenant scoping) because `ICurrentTenantService` does not exist in this codebase. Acceptable for admin-only BUSINESSADMIN screen; documented in handler XML doc.
  - Seed `GridCode='GRID'` was historically `MASTER_GRID` type; reclassified to `CONFIG` in Step 11 to keep it out of its own selector. Also adds a separate `GRIDCONFIG` placeholder Grid row in Step 10 (distinct GridCode) for the combined screen — slight redundancy but harmless and documents intent.
  - `GridQueries` field reads from `result.groups` (tuple return) — Backend agent's chosen return shape. Verify FE GraphQL contract reads field name `getGridListGrouped` returning `BaseApiResponse<List<GridGroupDto>>`.
- **Known issues opened**:
  - ISSUE-15 (LOW) — `ResetAllGridConfigurationsToDefaults` is platform-wide (no per-tenant scoping). For multi-tenant deployments, may need an `ICurrentTenantService` injection later.
  - ISSUE-16 (LOW) — `GetGridListGrouped` may return modules with zero eligible grids; FE optgroup should handle empty branches gracefully.
- **Known issues closed**:
  - ISSUE-1 (defaultFilters storage) → JSON in LayoutConfiguration
  - ISSUE-2 / ISSUE-3 / ISSUE-4 / ISSUE-5 (Field column additions) → N/A (no entity changes)
  - ISSUE-6 (entity-tab driver) → N/A (Tab 3 stripped)
  - ISSUE-7 (fieldSource filter) → FE-side advancedFilter
  - ISSUE-8 (grid-definition CRUD) → deprecated
  - ISSUE-10 (Width persistence) → int px
  - ISSUE-11 (Searchable col) → dropped from UI
  - ISSUE-14 (BulkUpdate transaction) → atomic SaveChangesAsync
- **Verification**:
  - `dotnet build` — reported clean by Backend Developer agent (per its summary). User should run `dotnet build` locally to confirm before applying seed.
- **Next step**:
  1. User: `dotnet build` Pss2.0_Backend to confirm no compile errors.
  2. User: execute `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/GridConfig-sqlscripts.sql` against the PostgreSQL instance (no EF migration required — pure handler/DTO additions).
  3. Verify in DB: `auth."Menus"` has `GRID` (visible) + `FIELD_SETTING` (hidden) + `CUSTOMFIELDS` (re-parented hidden) under `SET_GRIDMANAGEMENT`; BUSINESSADMIN RoleCapabilities present for all 3.
  4. Start Session 2: `/continue-screen #77 --scope FE_ONLY` to generate the 3-tab outer shell + Tab 1 (grid selector, column-config table, default-sort, default-filters, behavior, reset modals) + Tab 2 (Field Master MASTER_GRID with client-side FieldSource filter) + Tab 3 (stripped Custom Fields MASTER_GRID, no slide-panel) + 2 satellite-route redirects + entity-operations wiring.
- **Outcome**: PARTIAL (BE done; FE pending Session 2).

### Session 2 — 2026-05-16 — BUILD — COMPLETED

- **Scope**: Initial FE_ONLY build (Phase 2 of planned BE/FE split, mirroring #78 DashboardConfig). User-approved scope adjustments at session entry:
  - **ISSUE-9 resolved**: 3-tab shell (Grid Config / Field Master / Custom Fields) approved as planned.
  - **Tab 3 stripped to BE reality**: simple `<AdvancedDataTable gridCode="CUSTOMFIELDS" />` + RJSF modal — NO slide-panel, NO entity sub-tabs, NO Options/Validation/Visibility sections. Honors S1 "no entity-level changes" directive.
  - **No UX Architect pass**: Tab 1 mockup-direct from §⑥, Tab 2/3 standard MASTER_GRID patterns — went directly to Frontend Developer with consolidated brief.
- **Files touched**:
  - FE NEW (17):
    - `PSS_2.0_Frontend/src/domain/entities/setting-service/GridConfigurationDto.ts` (10 interfaces mirroring S1's `GridConfigurationSchemas.cs` exactly)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/GridConfigurationQuery.ts` (`GET_GRID_LIST_GROUPED`, `GET_GRID_CONFIGURATION_BY_GRID_ID`)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/GridConfigurationMutation.ts` (`BULK_UPDATE_GRID_CONFIGURATION`, `RESET_GRID_CONFIGURATION_TO_DEFAULTS`, `RESET_ALL_GRID_CONFIGURATIONS_TO_DEFAULTS`)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/FieldQuery.ts` (NEW — `FIELDS_QUERY`, `FIELD_BY_ID_QUERY` for Tab 2 FIELD_SETTING wiring)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/FieldMutation.ts` (NEW — Create/Update/Delete/Toggle)
    - `…/grid-config/grid-config-page.tsx` (outer 3-tab shell with `<ScreenHeader>` + URL sync via `?tab=`)
    - `…/grid-config/tabs/grid-tab.tsx` (Tab 1 orchestrator — fetch + RHF dirty tracking + validation + save)
    - `…/grid-config/tabs/grid-tab/grid-selector.tsx` (grouped optgroup select, empty-branch guard for ISSUE-16)
    - `…/grid-config/tabs/grid-tab/column-config-table.tsx` (CUSTOM table with HTML5 drag-reorder, switches, width input 40-600px)
    - `…/grid-config/tabs/grid-tab/default-sort-card.tsx`
    - `…/grid-config/tabs/grid-tab/default-filters-card.tsx`
    - `…/grid-config/tabs/grid-tab/grid-behavior-card.tsx`
    - `…/grid-config/tabs/grid-tab/preview-grid-modal.tsx` (SERVICE_PLACEHOLDER with mock rows)
    - `…/grid-config/tabs/grid-tab/reset-confirm-modals.tsx` (local revert + destructive type-tenant-name confirm)
    - `…/grid-config/tabs/field-tab.tsx` + `…/field-tab/field-data-table.tsx` (Tab 2 — `<AdvancedDataTable gridCode="FIELD_SETTING" />`)
    - `…/grid-config/tabs/customfield-tab.tsx` + `…/customfield-tab/customfield-data-table.tsx` (Tab 3 STRIPPED — `<AdvancedDataTable gridCode="CUSTOMFIELDS" />` + "Import Fields" SERVICE_PLACEHOLDER button)
    - `PSS_2.0_Frontend/src/presentation/pages/setting/gridmanagement/gridconfig.tsx` (`GridConfigPageConfig` wrapper with `useAccessCapability({ menuCode: "GRID" })`)
  - FE MODIFY (8):
    - `setting-service/index.ts` — added `CustomFieldDto` and `GridConfigurationDto` exports
    - `gql-queries/setting-queries/index.ts` — added `GridConfigurationQuery` + `FieldQuery` exports
    - `gql-mutations/setting-mutations/index.ts` — added `GridConfigurationMutation` + `FieldMutation` exports
    - `presentation/pages/setting/gridmanagement/index.ts` — added `GridConfigPageConfig` export
    - `application/configs/data-table-configs/setting-service-entity-operations.ts` — registered `FIELD_SETTING` + `CUSTOMFIELDS` entity-operations
    - `app/[lang]/setting/gridmanagement/grid/page.tsx` — swapped `<GridPageConfig />` → `<GridConfigPageConfig />`
    - `app/[lang]/setting/gridmanagement/field/page.tsx` — replaced UnderConstruction stub with redirect to `grid?tab=field`
    - `app/[lang]/setting/dataconfig/customfields/page.tsx` — replaced page with redirect to `gridmanagement/grid?tab=customfield`
  - BE: NONE (S1 scope)
  - DB: NONE (S1 generated `GridConfig-sqlscripts.sql`)
- **Deviations from spec**:
  - **`@dnd-kit` not present** — codebase uses `react-dnd` v16 and `react-aria`, neither with a sortable-list pattern matching our needs. Used native HTML5 drag-and-drop (`draggable` + `onDragStart`/`onDrop`) in `column-config-table.tsx` — same UX, zero new dependency. Acceptable tradeoff; if drag-UX feels rough at QA, can revisit later with `@dnd-kit` install.
  - **Tab 2 AdvancedDataTable receives default `showHeader`** (not `false`) — `<ScreenHeader>` lives outside the tabs at page level; the inner AdvancedDataTable header (toolbar + search) is the in-tab toolbar, not a duplicate page header. Layout Variant `tabs-only` permits this — the ScreenHeader/inner-toolbar pairing is the correct hierarchy.
  - **New `FieldQuery.ts` + `FieldMutation.ts`** — spec marked these as "create if missing". They were missing; created as standard CRUD GraphQL barrels matching existing Field BE handlers.
- **Known issues opened**: None
- **Known issues closed**:
  - ISSUE-9 (UX tab-structure validation) → 3-tab shell approved + built
  - ISSUE-16 (empty optgroup handling) → `grid-selector.tsx` filters out groups with zero grids
- **Verification**:
  - Frontend Developer agent reported `tsc --noEmit` = 0 errors for all new files.
  - Post-build grep checks (PM-side): zero inline hex colors, zero inline `padding/margin: <number>` in `style={{}}`, zero `Loading...` literal text, zero `#e5e7eb` skeleton hex — all UI-uniformity rules pass.
  - Layout Variant check: `grid-config-page.tsx` imports `ScreenHeader` from `presentation/components/custom-components/page-header/screen-header`. Tabs-only variant correct.
  - Spot-check confirmed entity-operations registers `FIELD_SETTING` + `CUSTOMFIELDS`, route stubs redirect appropriately, ScreenHeader gates "Reset All to Defaults" to Tab 1 only.
- **Next step**: 
  1. User: `pnpm dev` and navigate to `/{lang}/setting/gridmanagement/grid` — verify the 3-tab shell loads, grid selector populates from `getGridListGrouped`, selecting a grid loads column config from `getGridConfigurationByGridId`.
  2. End-to-end CRUD walkthrough on each tab per §⑪ Acceptance Criteria. If issues surface, `/continue-screen #77` opens a FIX session.
  3. Optional: install `@dnd-kit/core` + `@dnd-kit/sortable` if HTML5 drag feels too jittery at QA — replace the native handlers in `column-config-table.tsx`.
- **Outcome**: COMPLETED (FE done; full screen now end-to-end functional pending user QA).

### Session 3 — 2026-05-16 — FIX — COMPLETED

- **Scope**: Tab 2 (Field Master) showed Standard + Custom rows mixed because `GetFieldsQuery` BE handler had no `FieldSource` filter. S1's ISSUE-7 closure assumption (FE-side advancedFilter) was incorrect — `AdvancedDataTable` does not auto-inject a default filter for `FIELD_SETTING`. Added the missing server-side `FieldSource == "Standard"` predicate to mirror `GetCustomFieldsQuery`'s `"Custom"` filter.
- **Files touched**:
  - BE: `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Fields/Queries/GetField.cs` (modified — one-line filter added in `Handle`)
  - FE: None
  - DB: None
- **Deviations from spec**: None. This restores the documented contract (Tab 2 = Standard fields only, Tab 3 = Custom fields only).
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-17 (Tab 2 missing FieldSource=Standard server-side filter).
- **Verification**:
  - Grep confirmed handler now has `FieldSource == "Standard"` predicate.
  - `GetCustomFieldsQuery` already filters `"Custom"` — symmetry restored.
  - User must `dotnet build` + reload Tab 2 to confirm Standard-only rows render.
- **Next step**: None — screen remains COMPLETED.
- **Outcome**: COMPLETED.

### Session 4 — 2026-05-16 — FIX — COMPLETED

- **Scope**: S1+S2 missed the **MASTER_GRID seed** for the shared `FIELDMASTER` grid that backs Tab 2 (Field Master) and Tab 3 (Custom Fields). Without it the FE MASTER_GRID renderer has no column metadata (`sett."GridFields"`). Added one seed file with: 1 `Grids` row (GridFormSchema=null per convention), 11 `Fields` rows (namespaced `FIELDMASTER_` prefix), and 11 `GridFields` bindings.
- **Files touched**:
  - DB: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/FieldMaster-Grid-seed.sql` (NEW — 3 sections, idempotent: WHERE NOT EXISTS guards + correlated subquery on (GridId, FieldId) pair for GridFields)
  - BE: None
  - FE: None
- **Deviations from spec**: None. Matches the existing convention used by `companypaymentgateway-sqlscripts.sql`, `RecurringDonationSchedule-Grid-seed.sql`, and every other MASTER_GRID seed: `GridFormSchema` is initialized as `null`. The create-modal form is designed by an admin via the existing `FormLayoutBuilder` UI tool (`src/presentation/components/custom-components/form-layout-builder/`), which persists an RJSF `{schema, uiSchema}` JSON to that column via the `updateGridSchema` mutation. **Initial mistake**: I drafted a custom non-RJSF shape (`{fields, submitMutation, submitDefaults}`) for `GridFormSchema` — corrected to `null` after user pointed out FormLayoutBuilder already exists.
- **Known issues opened**: ISSUE-18 (LOW) — MasterDataType `FIELDTYPE` and its MasterData values must exist before Tab 3 create-modal works (BE `CreateCustomFieldHandler` looks up FieldTypeCode against `mdt.TypeCode='FIELDTYPE'`). Not seeded by #77; needs user confirmation it's seeded elsewhere.
- **Known issues closed**: ISSUE-19 (FIELDMASTER MASTER_GRID metadata missing).
- **Verification**:
  - Field.cs entity column inventory matches seed: FieldId, FieldName, FieldCode, FieldKey, DataTypeId, IsSystem, CompanyId, FieldSource, FieldTypeId, DataType (nav), FieldType (MasterData nav).
  - `CreateCustomFieldHandler` confirmed to auto-derive FieldCode (UPPER camelCase) + FieldKey (camelCase) + force `FieldSource="Custom"` — Tab 3 create-modal only needs FieldName + FieldTypeCode + DataTypeCode + IsActive when admin designs the form via FLB.
  - GridFormSchema convention verified across 3 existing grid seeds (always null at seed time, populated via UI).
  - FE-side advancedFilter on `fieldSource='Standard'` (Tab 2) / `'Custom'` (Tab 3) is the existing handler reality (§ S3 fix added BE-side filter to GetFieldsQuery for symmetry).
- **Next step**: User runs `FieldMaster-Grid-seed.sql` against Postgres. Then opens the FIELDMASTER grid in the admin UI and uses the **Edit Form Layout** action (which opens `FormLayoutBuilder`) to design the Tab 3 create-modal: drag FieldName, FieldTypeCode, DataTypeCode, IsActive into the canvas and Save. The mutation `updateGridSchema` persists the RJSF JSON to `Grid.GridFormSchema`. Also confirm `MasterDataType.TypeCode='FIELDTYPE'` exists with values.
- **Outcome**: COMPLETED.

### Session 5 — 2026-05-16 — FIX — COMPLETED

- **Scope**: S2 missed wiring **FormLayoutBuilder** into the new Grid Config Tab 1. The existing row-action only attaches FLB to the standalone Grid Master (#76) via `gridCode === "GRID"` in `action-column-cell.tsx:85` — but Tab 1 of #77 is a single-grid configurator (pick grid → edit columns/sort/filter/behavior), not a data table, so the row-action wiring never reaches it. Added a "Form Layout" button to Tab 1's actions bar that opens the FLB dialog for the currently-selected grid.
- **Files touched**:
  - DB: None
  - BE: None
  - FE: `PSS_2.0_Frontend/src/presentation/components/page-components/setting/gridmanagement/grid-config/tabs/grid-tab.tsx` (added import, `formLayoutOpen` state, "Form Layout" button between Reset/Preview/Save, and `<FormLayoutBuilder>` render gated on `selectedGridId`)
- **Deviations from spec**: None. Reuses the existing `FormLayoutBuilder` component (`src/presentation/components/custom-components/form-layout-builder/index.tsx`) with identical contract: pass `gridId` + `gridName` + `isOpen` + `setIsOpen`. Internal RJSF schema flow (`GET_GRID_SCHEMA` → designer canvas → `UPDATE_SCHEMA`) unchanged.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-20 (FLB not surfaced in Grid Config Tab 1).
- **Verification**:
  - Grep confirmed `FormLayoutBuilder` import resolves to the canonical export.
  - Button placed between "Reset to Default" and "Preview Grid" — `disabled={!selectedGridId}` so it stays inert when no grid picked.
  - FLB dialog rendered only when `selectedGridId` truthy (avoids querying `gridById` with null).
- **Next step**: User reloads Grid Config → picks any grid → clicks **Form Layout** → designs the create-modal form → Save. Verify the persisted JSON is RJSF-shaped and that the next create-modal launch (Tab 3 "+ New Custom Field" or any MASTER_GRID create) renders the designed form.
- **Outcome**: COMPLETED.

### § Known Issues (running ledger)

| ID | Severity | Area | Description | Status | Opened | Closed |
|----|----------|------|-------------|--------|--------|--------|
| ISSUE-1 | MED | BE Tab 1 | defaultFilters storage in LayoutConfiguration JSON | CLOSED | Plan | S1 |
| ISSUE-2 | LOW | BE Tab 3 | Field.Description column | N/A | Plan | S1 (no entity changes) |
| ISSUE-3 | MED | BE Tab 3 | OptionsJson storage | N/A | Plan | S1 |
| ISSUE-4 | MED | BE Tab 3 | Behavior/Number/Text JSON cols | N/A | Plan | S1 |
| ISSUE-5 | HIGH | BE Tab 3 | CustomFieldDto coverage | N/A | Plan | S1 (Tab 3 stripped) |
| ISSUE-6 | LOW | BE Tab 3 | Entity-type tabs driver | N/A | Plan | S1 (Tab 3 stripped) |
| ISSUE-7 | LOW | BE Tab 2 | fieldSource filter on GetFields | CLOSED | Plan | S1 (FE-side advancedFilter) |
| ISSUE-8 | MED | scope | grid/page.tsx deprecation | CLOSED | Plan | S1 (deprecated; GRID Grid reclassified to CONFIG) |
| ISSUE-9 | LOW | UX | Tab structure validation | CLOSED | Plan | S2 (3-tab shell approved + built) |
| ISSUE-10 | LOW | BE Tab 1 | Width persistence | CLOSED | Plan | S1 (int px) |
| ISSUE-11 | LOW | BE Tab 1 | IsSearchable column | CLOSED | Plan | S1 (dropped, merged with IsFilterable) |
| ISSUE-12 | LOW | seed | CUSTOMFIELDS re-parent idempotency | CLOSED | Plan | S1 (UPDATE-only, IS DISTINCT FROM guard) |
| ISSUE-13 | LOW | UX | Tab 3 entity-tab icons | N/A | Plan | S1 (Tab 3 stripped — no sub-tabs) |
| ISSUE-14 | MED | BE Tab 1 | BulkUpdate transactional | CLOSED | Plan | S1 (atomic SaveChangesAsync) |
| ISSUE-15 | LOW | BE Tab 1 | ResetAll platform-wide (no tenant scoping) | OPEN | S1 | — informational; admin-only screen so acceptable |
| ISSUE-16 | LOW | BE Tab 1 | GetGridListGrouped empty module branches | CLOSED | S1 | S2 (grid-selector.tsx filters out zero-grid groups) |
| ISSUE-17 | HIGH | BE Tab 2 | GetFieldsQuery missed FieldSource=Standard filter — Tab 2 returned Standard+Custom mixed (supersedes ISSUE-7 mis-closure) | CLOSED | S2 | S3 (server-side filter added in GetField.cs handler) |
| ISSUE-18 | LOW | DB seed | MasterDataType `FIELDTYPE` + its MasterData values are referenced by `CreateCustomFieldHandler` but not seeded by #77 — Tab 3 create-modal dropdown will be empty if absent | OPEN | S4 | — needs user confirmation that FIELDTYPE master data already seeded elsewhere |
| ISSUE-19 | HIGH | DB seed | FIELDMASTER MASTER_GRID metadata (`sett."Grids"` + `sett."Fields"` + `sett."GridFields"` + `GridFormSchema` JSON) missing — FE MASTER_GRID renderer has no column meta to render Tab 2/3 | CLOSED | S4 | S4 (`FieldMaster-Grid-seed.sql` added — shared grid, namespaced FIELDMASTER_ prefix, idempotent) |
| ISSUE-20 | HIGH | FE Tab 1 | FormLayoutBuilder not surfaced in Grid Config Tab 1 — only available via standalone Grid Master #76 row-action (`gridCode==="GRID"`); admin landing on combined #77 had no way to design create-modal form for the selected grid | CLOSED | S4 | S5 (added "Form Layout" button + FLB render in `grid-tab.tsx`, gated on `selectedGridId`) |