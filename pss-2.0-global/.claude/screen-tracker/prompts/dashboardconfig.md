---
screen: DashboardConfig
registry_id: 78
module: Settings
status: PROMPT_READY
scope: ALIGN
screen_type: CONFIG
config_subtype: DESIGNER_CANVAS
storage_pattern: definition-list
save_model: hybrid (autosave on canvas + save-per-section for sub-entity tabs + standard CRUD modals for catalog rows)
complexity: High
new_module: NO
planned_date: 2026-05-14
completed_date:
last_session_date:
---

> **Combined screen** — absorbs:
> - #78 Dashboard Config (Dashboard entity)
> - #158 Dashboard Layout (drag/drop designer)
> - #159 Widget cluster (Widget + WidgetType + WidgetProperty + WidgetRole + #129)
>
> 6 menu codes resolve to this ONE screen. Primary route is `setting/dashboardwidget/dashboard`;
> the other 5 routes (`/dashboardlayout`, `/widget`, `/widgettype`, `/widgetproperty`, plus
> `accesscontrol/usersroles/widgetrole`) are kept seeded as `IsLeastMenu=false` and either
> redirect to the primary URL with a `?tab=` query OR mount the same React component with a
> default-tab prop.
>
> **Reuse audit (2026-05-14)** — BE is 100% built (all 6 entities + handlers + GraphQL endpoints
> in place). FE has 5 placeholder data-table stubs (one per entity) that will be REPLACED by
> the unified 6-tab DESIGNER_CANVAS shell defined here. Scope is therefore `ALIGN` (mostly FE
> rebuild + targeted BE additions for the dashboard-roles junction + the canvas bulk-save).

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (DESIGNER_CANVAS primary; 6-tab hybrid shell)
- [x] Business context read (admin-only system config governing every module's dashboards + widgets)
- [x] Storage model identified (definition-list across 6 existing entities + 1 NEW junction `DashboardRole`)
- [x] Save model chosen (hybrid — autosave canvas / save-per-section dashboard settings / RJSF modal CRUD for catalog rows / diff save for role matrix)
- [x] Sensitive fields & role gates identified (no secrets; entire screen gated to BUSINESSADMIN)
- [x] FK targets resolved (Module, Role, DataType, Company, Menu — all pre-existing)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (admin config purpose + DASHBOARD/WIDGET/WIDGETROLE governance)
- [ ] Solution Resolution complete (DESIGNER_CANVAS confirmed; hybrid save model confirmed)
- [ ] UX Design finalized (6-tab shell + canvas pane + palette modal + properties pane)
- [ ] User Approval received
- [ ] Backend code generated          ← only the new DashboardRole junction + 2 new aggregate handlers (skip pre-existing CRUD)
- [ ] Backend wiring complete         ← register DbSet + Mapster + endpoints
- [ ] Frontend code generated         ← full FULL rebuild over existing FE data-table stubs
- [ ] Frontend wiring complete        ← register all 6 menus in entity-operations
- [ ] DB Seed script generated (parent menu re-seed + Capability inserts + GridType=CONFIG + sample dashboards/widgets/widget-types)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/setting/dashboardwidget/dashboard`
- [ ] **DESIGNER_CANVAS checks**:
  - [ ] Tab 1 (Dashboards): list renders with Add/Edit/Delete; Add opens modal with Name/Description/Icon/Color/Module/IsDefault/IsSystem fields; per-dashboard role-assignment checkbox group persists
  - [ ] Tab 2 (Layout Designer): selecting a dashboard from Tab 1 → tab-2 canvas loads its current layout
  - [ ] Widget grid renders all configured widgets at their `(x,y,w,h)` positions
  - [ ] "+ Add Widget" cell opens widget-library modal grouped by WidgetType
  - [ ] Selecting a widget on canvas loads properties pane (Widget Type readonly + Title + Data Source + Metric + Group By + Period + Filter + Size + Refresh + Show Comparison)
  - [ ] Drag-reorder persists; click "Save Widget" persists the dashboard's `LayoutConfig` JSON + linked `WidgetProperty` rows
  - [ ] Tab 3 (Widget Catalog): list + RJSF modal CRUD on `Widget` (Name/Type/Module/Description/DefaultQuery/DefaultParameters/MinWidth/MinHeight/OrderBy/StoredProcedureName)
  - [ ] Tab 4 (Widget Types): list + RJSF modal CRUD on `WidgetType` (Name/Code/Description/ComponentPath)
  - [ ] Tab 5 (Widget Properties): nested under a selected Widget — list of `(PropertyKey, PropertyValue, DataType)` rows
  - [ ] Tab 6 (Widget Roles): matrix Widget × Role with checkbox cells; diff-save mutation `bulkUpdateWidgetRoles`
- [ ] Dangerous actions gated:
  - Delete Dashboard if `UserDashboards` count > 0 → confirm with affected-user count + audit log
  - Delete Widget if used in any `DashboardLayout.ConfiguredWidget` → blocked with referenced-dashboard list
  - Delete WidgetType if used by any Widget → blocked
- [ ] Empty / loading / error states render
- [ ] DB Seed — primary menu `DASHBOARD_SETTING` visible at sidebar `Settings → Dashboard & Widget`; other 4 menus remain seeded as hidden (`IsLeastMenu=false`) for capability cascade

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **DashboardConfig** (combined: Dashboard Configuration + Layout Designer + Widget cluster)
Module: **Settings** (Module Code: `SETTING`)
Schema: `sett` (existing — for Dashboard / Widget / WidgetType / WidgetProperty / DashboardLayout) + `auth` (existing — for WidgetRole) + **NEW** `sett.DashboardRoles` junction (created by this build)
Group: `Setting` (Base.Application.Schemas.SettingSchemas + Base.Application.Business.SettingBusiness)

Business:
This is the **system-wide configuration surface** for every dashboard that ships in the platform. PSS 2.0 has multiple per-module dashboards (Contact, Donation, Communication, Ambassador, Volunteer, Case, plus tenant-custom ones), each composed of a grid of widgets (KPI cards / charts / lists / tables). The mockup `settings/dashboard-config.html` is the **designer canvas** that lets a BUSINESSADMIN edit which widgets appear on a dashboard, how they're laid out, what data they query, who can see them, and how often they refresh. Because the original Dashboard, DashboardLayout, Widget, WidgetType, WidgetProperty, and WidgetRole entities were each given their own admin menu, this combined screen also exposes those underlying catalogs as additional tabs — Tab 1 (Dashboards) lets the admin manage the list of dashboards themselves; Tab 2 (Layout Designer) is the visual canvas from the mockup; Tabs 3–5 manage the Widget / WidgetType / WidgetProperty catalogs that the designer consumes; Tab 6 (Widget Roles) is a matrix gating which role can see which widget.

WHO edits: **BUSINESSADMIN only**. Edited rarely — initial platform setup, then occasional per-tenant tweaks (e.g. promoting a new widget into the Executive dashboard).

WHY it exists: every other module's "Dashboard" page (CRM Contact Dashboard, Donation Dashboard, etc.) reads its layout + widget list from `sett.Dashboards` + `sett.DashboardLayouts`. Without this screen, the BUSINESSADMIN cannot adjust those layouts without editing JSON in the DB. It also gates **role visibility**: the `WidgetRole` matrix decides whether a role's user even sees a widget when the dashboard renders.

WHAT BREAKS if mis-set:
- Wrong widget data source → dashboard tile renders empty or shows wrong numbers.
- Missing `WidgetRole` row → users in that role see broken dashboard layout (missing tiles).
- Deleting an in-use widget → existing dashboards crash at render time. **Mitigation**: deletes are guarded server-side (see §④ Dangerous Actions).
- Wrong `LayoutConfig` JSON → react-grid-layout crashes; whole dashboard blank. **Mitigation**: JSON schema validation before persist.

HOW it relates to other screens:
- **Consumed by**: every module dashboard screen (#119 ContactDashboard, #122 DonationDashboard, #156 CommunicationDashboard, #131 AmbassadorDashboard, plus role-scoped variants under `crm/dashboards/*`).
- **Sibling**: #77 Grid Config (combined Grid + Field + CustomFields) — same "admin config surface for the platform's data-presentation infrastructure" pattern.
- **Differs from #77** in that Grid Config governs data tables; this screen governs dashboards & widgets. Visual treatment must NOT be a clone of #77 — different content type, different layout.

WHAT'S unique about this UX:
- Tab 2 is a real **drag/drop designer canvas** (react-grid-layout), not a settings form.
- The Widget Library is a modal with **categorized cards** (KPI Cards / Charts / Lists & Feeds / Tables) — palette items are NOT plain rows, they are rich cards with icons + descriptions + per-type previews.
- Selecting a widget on the canvas swaps the right-pane properties (live editing — changes reflect on canvas without explicit save).
- The Roles tab is a **N×M matrix**, not a per-row form.
- Sub-tabs share state (selecting a dashboard in Tab 1 also pre-loads it for Tab 2 designer).

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer

**Storage Pattern**: `definition-list` (the platform-wide widget/type catalog rows) + a **NEW** `matrix-join` table for Dashboard×Role + the existing `matrix-join` `auth.WidgetRoles` for Widget×Role.

### Existing Tables (REUSE — no schema changes except column lengths if needed)

#### Primary table: `sett."Dashboards"` (EXISTING)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| DashboardId | int | — | PK | — | Primary key |
| DashboardCode | string | 50 | YES | — | Tenant-unique alphanumeric (used by URL routes) |
| DashboardName | string | 100 | YES | — | Display name (`Executive Dashboard`) |
| DashboardIcon | string | 100 | YES | — | `ph:gauge` icon ID |
| DashboardColor | string? | 7 | NO | — | Hex `#6366f1` accent color |
| ModuleId | Guid | — | YES | corg.Modules | Which module owns this dashboard |
| IsSystem | bool | — | YES | — | True = built-in platform dashboard, false = tenant-custom |
| CompanyId | int? | — | NO | corg.Companies | NULL = system dashboard (shared); non-NULL = tenant-custom |
| MenuId | int? | — | NO | corg.Menus | Optional FK to the sidebar menu entry that links to this dashboard |

**Singleton constraint**: NO — many rows.
**Indexes**: composite filtered unique on `(CompanyId, DashboardCode)` WHERE `IsDeleted = false`.

#### `sett."DashboardLayouts"` (EXISTING) — 1:N child of Dashboard

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| DashboardLayoutId | int | — | PK | — | Primary key |
| DashboardId | int | — | YES | sett.Dashboards | Parent |
| LayoutConfig | string? | (text) | NO | — | JSON: react-grid-layout `[{i,x,y,w,h,minW,minH}]` array per breakpoint |
| ConfiguredWidget | string? | (text) | NO | — | JSON: array of `{widgetInstanceId, widgetId, title, dataSource, metric, groupBy, period, filters{}, refreshInterval, showComparison}` — one entry per placed widget on canvas |

> **Note** — these two text columns (`LayoutConfig` + `ConfiguredWidget`) are the dashboard's authoritative schema. They are JSON blobs co-edited by the canvas. Per `feedback_db_utc_only` they're text, not jsonb (Postgres jsonb available but current EF config uses text — keep as-is to avoid migration churn).

#### `sett."Widgets"` (EXISTING) — widget catalog

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WidgetId | int | — | PK | — | Primary key |
| WidgetName | string | 100 | YES | — | Display name (`Total Donors`) |
| WidgetTypeId | int | — | YES | sett.WidgetTypes | Which renderer to use |
| DefaultQuery | string? | (text) | NO | — | Default GraphQL query / SQL hint to feed the widget |
| DefaultParameters | string? | (text) | NO | — | JSON of default parameter values |
| Description | string? | 500 | NO | — | Admin-facing summary |
| MinHeight | int | — | YES | — | Minimum grid height in rows (default 1) |
| MinWidth | int | — | YES | — | Minimum grid width in columns (default 1) |
| ModuleId | Guid | — | YES | corg.Modules | Which module this widget belongs to |
| OrderBy | int | — | YES | — | Catalog display order |
| IsSystem | bool | — | YES | — | True = platform default, false = tenant-custom |
| CompanyId | int? | — | NO | corg.Companies | NULL = system widget; non-NULL = tenant-custom |
| StoredProcedureName | string? | 200 | NO | — | Optional SP-backed data source |
| FilterSchema | string? | (text) | NO | — | JSON schema for filter UI in canvas properties pane |
| QuickFilterSchema | string? | (text) | NO | — | JSON schema for quick-filter chips |

#### `sett."WidgetTypes"` (EXISTING) — renderer catalog

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WidgetTypeId | int | — | PK | — | Primary key |
| WidgetTypeName | string | 100 | YES | — | `KPI Card`, `Line Chart`, `Donut Chart`, etc. |
| WidgetTypeCode | string | 50 | YES | — | UPPER snake (e.g. `KPI_CARD`, `LINE_CHART`) — globally unique |
| Description | string | 500 | YES | — | What it renders |
| ComponentPath | string | 200 | YES | — | FE component module path (e.g. `dashboards/widgets/kpi-card`) |

#### `sett."WidgetProperties"` (EXISTING) — per-widget config schema

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WidgetPropertyId | int | — | PK | — | Primary key |
| WidgetId | int | — | YES | sett.Widgets | Parent widget |
| PropertyKey | string | 50 | YES | — | e.g. `dataSource`, `metric`, `groupBy` |
| PropertyValue | string | (text) | YES | — | Default value (stringified) |
| DataTypeId | int | — | YES | corg.DataTypes | Determines property editor type (text/number/dropdown/json) |

#### `auth."WidgetRoles"` (EXISTING) — Widget × Role matrix join

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WidgetRoleId | int | — | PK | — | Primary key |
| WidgetId | int | — | YES | sett.Widgets | Widget side |
| RoleId | int | — | YES | auth.Roles | Role side |
| HasAccess | bool | — | YES | — | Cell value — true = role can see widget |

**Composite unique**: `(WidgetId, RoleId)`.

### NEW table — `sett."DashboardRoles"` (MUST CREATE)

> **Gap discovered during audit** — the mockup's "Assigned Roles" section in Dashboard Settings has no existing storage. Mirror `auth.WidgetRoles` pattern.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| DashboardRoleId | int | — | PK | — | Primary key |
| DashboardId | int | — | YES | sett.Dashboards | Dashboard side |
| RoleId | int | — | YES | auth.Roles | Role side |
| HasAccess | bool | — | YES | — | true = role can see this dashboard |

**Composite unique**: `(DashboardId, RoleId)`.
**Cascade**: ON DELETE CASCADE from `Dashboards` (deleting a dashboard removes its role grants).

### Existing nav property (re-used)

`sett.Dashboards.UserDashboards` — user-level pin/favorites; not edited by this screen but its count is used to gate Dashboard deletion (see §④).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` / nav props) + Frontend Developer (for ApiSelect dropdowns)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ModuleId (Dashboard / Widget) | Module | Base.Domain/Models/CorgModels/Module.cs | getModules | ModuleName | ModuleResponseDto |
| CompanyId (Dashboard / Widget) | Company | Base.Domain/Models/CorgModels/Company.cs | (HttpContext — not a form field) | CompanyName | CompanyResponseDto |
| MenuId (Dashboard) | Menu | Base.Domain/Models/CorgModels/Menu.cs | getMenuList | MenuName | MenuResponseDto |
| WidgetTypeId (Widget) | WidgetType | Base.Domain/Models/SettingModels/WidgetType.cs | getWidgetType | WidgetTypeName | WidgetTypeResponseDto |
| WidgetId (WidgetProperty / WidgetRole) | Widget | Base.Domain/Models/SettingModels/Widget.cs | getWidget | WidgetName | WidgetResponseDto |
| DashboardId (DashboardLayout / DashboardRole) | Dashboard | Base.Domain/Models/SettingModels/Dashboard.cs | getDashboard | DashboardName | DashboardResponseDto |
| DataTypeId (WidgetProperty) | DataType | Base.Domain/Models/CorgModels/DataType.cs | getDataTypeList | DataTypeName | DataTypeResponseDto |
| RoleId (WidgetRole / DashboardRole) | Role | Base.Domain/Models/AuthModels/Role.cs | getRoles | RoleName | RoleResponseDto |

**Matrix sources (Tab 6 — Widget × Role)**:
| Axis | Source Entity | GQL Query | Order Field | Read-only Filter |
|------|--------------|-----------|-------------|-------------------|
| Rows | Widget (`sett.Widgets`) | getWidget | OrderBy asc | (none — all widgets) |
| Columns | Role (`auth.Roles`) | getRoles | RoleName asc | exclude `IsSystem` roles (e.g. SUPERADMIN) — read-only cells |

**Matrix sources (Tab 1 Dashboards — per-dashboard Assigned Roles)**:
| Axis | Source Entity | GQL Query | Order Field | Read-only Filter |
|------|--------------|-----------|-------------|-------------------|
| Rows | Dashboard (`sett.Dashboards`) | getDashboard | OrderBy / DashboardName | — |
| Columns | Role (`auth.Roles`) | getRoles | RoleName asc | exclude system roles |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Cardinality Rules:**
- A `Dashboard.DashboardCode` is unique per `(CompanyId, ModuleId)`. System dashboards (`CompanyId IS NULL`) must have globally-unique codes.
- A `DashboardLayout` is 1:1 with a Dashboard in the current schema (audit shows `DashboardLayouts` collection but the canvas saves a single active layout per dashboard — multiple rows reserved for future per-breakpoint or per-version variants).
- `WidgetRole` composite unique `(WidgetId, RoleId)`.
- `DashboardRole` (NEW) composite unique `(DashboardId, RoleId)`.
- `WidgetType.WidgetTypeCode` globally unique (system catalog).

**Required Field Rules:**
- Tab 1 Dashboards: `DashboardName`, `DashboardCode`, `DashboardIcon`, `ModuleId` required on Create.
- Tab 3 Widgets: `WidgetName`, `WidgetTypeId`, `ModuleId` required; `MinHeight`, `MinWidth` default 1.
- Tab 4 WidgetTypes: `WidgetTypeName`, `WidgetTypeCode`, `ComponentPath` required.
- Tab 5 WidgetProperties: all 4 columns required (`WidgetId`, `PropertyKey`, `PropertyValue`, `DataTypeId`).

**Conditional Rules:**
- `Dashboard.IsSystem = true` → `CompanyId` MUST be NULL (system dashboards are global).
- `Dashboard.IsSystem = false` → `CompanyId` MUST be the tenant from HttpContext.
- Same rule for `Widget.IsSystem`.
- `WidgetType.ComponentPath` must match a known frontend renderer key — validated server-side against an enum / config; if unknown, save WARNS but does not block (admin may register new renderers).
- `LayoutConfig` JSON must validate against react-grid-layout schema before persist (`i / x / y / w / h` required per item; `minW / minH` optional).
- `ConfiguredWidget` JSON: each entry's `widgetId` must exist in `sett.Widgets`; `widgetInstanceId` (FE-generated UUID) must be unique within the same layout.

**Sensitive Fields**: NONE in this screen — no credentials, tokens, or PII.

**Read-only / System-controlled Fields:**
- `IsSystem` is read-only after Create (cannot flip a system widget/dashboard to custom and vice versa).
- `WidgetType` rows tagged as system (`IsActive` + name in seeded list) cannot be deleted via UI.
- `WidgetRole` rows for system roles (e.g. SUPERADMIN) → cells render disabled (always allowed).

**Dangerous Actions** (require confirm + audit):
| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Delete Dashboard with UserDashboards | Removes layout + role grants + cascades user-pin/favorites | Modal: "{N} users have pinned this dashboard. Delete anyway?" | log "dashboard.deleted" with id+name+affectedUsers |
| Delete Widget used in DashboardLayouts | BLOCKED (cannot delete in-use widget) | Show modal listing referencing dashboards | log attempt |
| Delete WidgetType used by Widgets | BLOCKED (cannot delete in-use type) | Show modal listing referencing widgets | log attempt |
| Reset Dashboard Layout | Overwrites `LayoutConfig` + `ConfiguredWidget` with seeded defaults for that dashboard | Modal: type dashboard name | log "dashboard.reset" |

**Role Gating** (which sections / fields are visible / editable per role):
| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all 6 tabs | all 6 tabs | full access |
| All other roles | (screen hidden — menu capability ISMENURENDER=false) | n/a | screen invisible in sidebar |

**Workflow**: NONE — direct save, no draft/publish lifecycle (changes go live immediately for downstream dashboards).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `DESIGNER_CANVAS`
**Storage Pattern**: `definition-list` (catalog tabs) + `matrix-join` (Tab 6 Widget×Role + per-dashboard role grants)
**Save Model**: `hybrid` — see below

| Surface | Save Mode |
|---------|-----------|
| Tab 1 (Dashboards) — list + Add/Edit/Delete | RJSF modal form (Create/Update mutations on click of Save). `save-all` per record. |
| Tab 1 — per-dashboard "Assigned Roles" checkbox group | `autosave` debounced 500ms on each toggle (PATCH `bulkUpdateDashboardRoles`) — like a mini matrix. |
| Tab 2 (Layout Designer) canvas | `autosave` on drag-end / resize-end / properties-Save (debounced 800ms). Toast `Saved at HH:MM`. |
| Tab 3 (Widget Catalog) | RJSF modal CRUD per row. `save-all` per record. |
| Tab 4 (Widget Types) | RJSF modal CRUD per row. `save-all` per record. |
| Tab 5 (Widget Properties) — nested under selected Widget | Inline-row save OR modal form (modal preferred for first version). |
| Tab 6 (Widget × Role matrix) | `save-all` with dirty count + sticky-footer Save Changes / Discard. Diff payload only. |

**Reason**: the primary mockup is a designer canvas (palette + canvas + properties pane = textbook DESIGNER_CANVAS); the absorbed sub-screens are sub-entity catalogs that the canvas consumes, naturally housed as side tabs with their own CRUD shapes. Forcing a single save model across all 6 tabs would create UX friction — autosave on the canvas (every drag should persist), modal-save on catalog rows (admin expects a Save button), diff-save on the matrix (only changed cells).

**Backend Patterns Required:**

For DESIGNER_CANVAS canvas (Tab 2):
- [x] `GetDashboardDesignerState` query — returns `{ dashboard, layout (LayoutConfig+ConfiguredWidget), widgetCatalog, widgetTypes, assignedRoles }` in ONE call. **NEW** composite handler.
- [x] `SaveDashboardLayout` mutation — accepts `{ dashboardId, layoutConfig, configuredWidget }`. **NEW** handler that wraps existing `UpdateDashboardLayout`.
- [x] Existing `UpdateDashboardLayout` handler is sufficient if FE flattens the call.

For Tab 1 (Dashboards):
- [x] `getDashboard`, `createDashboard`, `updateDashboard`, `deleteDashboard`, `toggleDashboardStatus` — ALL EXIST.
- [x] **NEW** `bulkUpdateDashboardRoles` mutation — accepts `{ dashboardId, addedRoleIds[], removedRoleIds[] }` → upsert into NEW `sett.DashboardRoles` join. Diff-payload only.
- [x] **NEW** `getDashboardRoles(dashboardId)` query — returns `[{ roleId, roleName, hasAccess }]`.

For Tab 3 (Widgets), Tab 4 (WidgetTypes), Tab 5 (WidgetProperties):
- [x] All standard CRUD ALREADY EXISTS — `getWidget` / `createWidget` / `updateWidget` / `deleteWidget` / `toggleWidgetStatus` + same shape for WidgetType + WidgetProperty.

For Tab 6 (WidgetRole matrix):
- [x] `getWidgetRoles` (existing — flat list).
- [x] **NEW or VERIFY** `getWidgetRoleMatrix` query → returns `{ rows: [{widgetId, widgetName, widgetTypeName}], columns: [{roleId, roleName, isSystem}], cells: [{widgetId, roleId, hasAccess}] }`. Wrap existing handler if a similar GQL field already exists; otherwise add.
- [x] **NEW or VERIFY** `bulkUpdateWidgetRoles` mutation — accepts diff (`addedCells[]`, `removedCells[]`, OR `cells[]` with `hasAccess`). Audit log existing handler `CreateAndUpdateWidgetRoleByModule` is close — extend or wrap.

For NEW `DashboardRole` entity:
- [x] Entity + EF Config + Schemas + 4 standard handlers (Create/Update/Delete/Get) + 1 bulk handler.

**Frontend Patterns Required:**

For DESIGNER_CANVAS:
- [x] Three-pane layout for Tab 2: palette modal (Widget Library) + canvas (react-grid-layout) + properties pane (right side, ~320px).
- [x] Drag-to-reorder + drag-to-resize on canvas (react-grid-layout supports both).
- [x] Click widget cell → loads properties pane.
- [x] Properties edits update canvas live (no save needed for non-position fields like Title / Filter).
- [x] Autosave indicator (subtle "Saved at HH:MM").
- [x] Delete-confirm modal for in-use dashboards / widgets.

For all 6 tabs:
- [x] Tab shell uses existing `<Tabs>` shadcn component (used by #157 SMS Setup and #29 EmailTemplate).
- [x] Tabs persist via URL query `?tab=dashboards|designer|widgets|widgettypes|widgetproperties|widgetroles`.
- [x] Selecting a Dashboard in Tab 1 sets store `selectedDashboardId` → Tab 2 / Tab 6 use it.

For Tab 6 matrix:
- [x] Matrix table component (sticky header column + sticky header row).
- [x] Cell renderer: checkbox.
- [x] Row & column header click for bulk select.
- [x] Search by widget name / module filter.
- [x] Dirty-cell indicator + Save All / Discard.
- [x] Read-only cells for system roles (SUPERADMIN row disabled).

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer

### 🎨 Visual Uniqueness Rules

**This screen MUST NOT look like #77 Grid Config or #157 SMS Setup.** Tabs are the same shadcn primitive but the content per tab is dramatically different (matrix vs. canvas vs. RJSF modal vs. settings form). Reference cues:
- Use `@iconify` Phosphor icons: `ph:gauge` for Dashboards, `ph:grip` (or `ph:squares-four`) for Layout Designer, `ph:puzzle-piece` for Widgets, `ph:shapes` for Widget Types, `ph:sliders` for Widget Properties, `ph:lock` for Widget Roles.
- Per-tab visual weight: Layout Designer is the **hero tab** — opens by default when an admin lands on a known dashboard; should feel like a real designer (toolbar + canvas + side pane), not a settings form.
- Widget Library modal: grouped by category with rich icon-bubble cards (mockup-faithful — 4-column grid of bubble-icon + name + description + hover "Add" CTA).

---

### Page Layout

**Page Header**:
- Breadcrumb: `Settings › Dashboard & Widget`
- Title: `Dashboard Configuration` + subtitle `Configure dashboard layouts and widgets for each role`
- Right actions: `+ New Dashboard` (primary, opens Tab 1 Add modal) | `Widget Library` (outline, opens Widget Library modal — same one Tab 2 uses)

**Container**: 6 horizontal tabs (shadcn `<Tabs>`).

| # | Tab | URL `?tab=` | Icon | Default Open |
|---|-----|-------------|------|--------------|
| 1 | Dashboards | `dashboards` | `ph:gauge` | YES (when no dashboard selected) |
| 2 | Layout Designer | `designer` | `ph:squares-four` | YES (when a dashboard is selected from Tab 1) |
| 3 | Widgets | `widgets` | `ph:puzzle-piece` | — |
| 4 | Widget Types | `widgettypes` | `ph:shapes` | — |
| 5 | Widget Properties | `widgetproperties` | `ph:sliders` | — |
| 6 | Widget Roles | `widgetroles` | `ph:lock` | — |

### Tab 1 — Dashboards

**Layout**: 2-column split — left 60% list of dashboards (cards or table), right 40% **Dashboard Settings** panel for the currently-selected dashboard (mockup's "Dashboard Settings" section).

Left:
- Cards or table of dashboards filtered by `IsSystem` toggle (`All / System / Custom`).
- Each card shows DashboardName + ModuleName + DashboardIcon + role-count chip (`{N} roles`) + active toggle + edit/delete actions.
- `+ New Dashboard` button (also in page header).

Right (Dashboard Settings panel — visible when a card is selected):
- Section: "Identity" — DashboardName, DashboardCode (locked after create), Description (NEW field via WidgetProperty or use `Dashboard.DashboardName.subtitle` — see ISSUE-3), ModuleId (ApiSelect), DashboardIcon (icon picker), DashboardColor (hex picker), MenuId (ApiSelect → Menu).
- Section: "Behavior" — Auto-Refresh switch + interval dropdown (1/5/10/15/30 min) — **NOTE**: not on Dashboard entity today; store as a WidgetProperty or extend Dashboard (see ISSUE-1).
- Section: "Default Date Range" — dropdown (Today / Week / Month / Quarter / Year) — same storage decision.
- Section: "Assigned Roles" — checkbox group from `getRoles` query, current state from `getDashboardRoles(selectedDashboardId)`. Autosave on toggle → `bulkUpdateDashboardRoles` PATCH (debounced 500ms).
- Footer: `Save Settings` button + Reset Layout (destructive — clears Tab 2 canvas) + Delete Dashboard (destructive — see §④).

Add Dashboard modal (RJSF):
- DashboardName *, DashboardCode * (auto-suggested from name; admin can override), DashboardIcon * (picker), DashboardColor (optional), ModuleId *, IsDefault, MenuId.
- Submit → `createDashboard` → close modal → select new dashboard in left list.

### Tab 2 — Layout Designer (HERO TAB — DESIGNER_CANVAS)

**Requires**: a selected dashboard from Tab 1. If none selected, render "Pick a dashboard from the Dashboards tab to design its layout" empty state.

**3-pane layout**:
```
┌──────────────────────────────────────────────────────────────────────┐
│ {DashboardName}        [+ Add Widget] [Reset Layout] [Saved at 14:32]│
├──────────────────────────────────────────┬───────────────────────────┤
│ CANVAS (react-grid-layout, 4-col grid)   │ WIDGET PROPERTIES         │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐              │ Selected: Donation Trend  │
│ │KPI │ │KPI │ │KPI │ │KPI │              │ Widget Type: Line Chart   │
│ └────┘ └────┘ └────┘ └────┘              │ Title: [Donation Trends]  │
│ ┌──────────┐ ┌──────────┐                │ Data Source: [Donations▾] │
│ │ Line     │ │ Donut    │                │ Metric: [Total Amount ▾]  │
│ │ Chart 2x2│ │ Chart 2x2│                │ Group By: [Month ▾]       │
│ └──────────┘ └──────────┘                │ Period: [Last 6 Months ▾] │
│ ┌──┐┌──┐┌──────────┐                     │ Filter:                   │
│ │F ││T ││Retention 2x1                   │   Branch [All ▾]          │
│ │e ││a │└──────────┘                     │   Purpose[All ▾]          │
│ │e ││s │┌─────[+Add]────┐                │ Size: [2x2 ▾]             │
│ │d ││k │└────────────────┘                │ Refresh: [Default ▾]     │
│ └──┘└──┘                                  │ Show Comparison: [ ]      │
│                                          │ [Remove]    [Save Widget] │
└──────────────────────────────────────────┴───────────────────────────┘
```

**Canvas details**:
- Use `react-grid-layout` (already a dependency or add). 12-column grid (mockup uses 4 — coarsen by mapping w=1 → 3-col span, w=2 → 6-col, etc., OR keep 4-col exact).
- Each widget cell shows: size badge (`1x1`, `2x2`), icon (from WidgetType), title, type label.
- Hover: shows drag handle (corner) + resize handle (corner) + delete (X) + duplicate.
- Click cell → highlight + load properties pane.
- "+ Add Widget" empty cell at end → opens Widget Library modal.
- Drag/resize → autosave 800ms debounce → toast "Saved at HH:MM".

**Widget Library modal** (the mockup-faithful palette):
- Same modal opens from page-header "Widget Library" button AND from canvas "+ Add Widget" cell.
- Header: `Widget Library`.
- Body: grouped categories from `getWidgetType` join with `getWidget` — each WidgetType is a section header (KPI Cards / Charts / Lists & Feeds / Tables) with its widgets as cards:
  - Card: icon (40px bubble), WidgetName, Description, hover-only `+ Add` CTA.
- Click card → close modal + add widget instance to canvas at `(x: end, y: end, w: MinWidth, h: MinHeight)` + auto-select → properties pane loads.
- Filter: search box at modal top.

**Properties pane** (right pane, 320px wide):
- Widget Type (readonly — `ph:lock` indicator).
- Title (editable — overrides WidgetName for this instance).
- Data Source (dropdown — populated from `Widget.DefaultParameters.dataSourceOptions` JSON).
- Metric (dropdown — same pattern).
- Group By (dropdown).
- Period (dropdown).
- Filter (sub-form rendered from `Widget.FilterSchema` JSON — Branch / Purpose / etc. depending on widget).
- Size (dropdown: `1x1 / 1x2 / 2x1 / 2x2 / 3x1 / Full Width`).
- Refresh Interval (dropdown: `Use Dashboard Default / 1 min / 5 min / 10 min / 30 min`).
- Show Comparison (switch).
- Footer: `Remove` (destructive, confirm) | `Save Widget` (primary — but autosave fires on each change; the Save button is a manual confirm fallback).

**Properties → Canvas live sync**: Title edits update the cell title in real-time; Size dropdown updates `(w,h)` and re-flows.

**Persistence**: all canvas state lives in `DashboardLayout.LayoutConfig` (positions) + `DashboardLayout.ConfiguredWidget` (per-instance properties). One `saveDashboardLayout` mutation.

### Tab 3 — Widgets (catalog)

- Standard data-table grid: WidgetName | WidgetTypeName | ModuleName | Description | MinWxMinH | IsSystem | IsActive | actions.
- `+ Add Widget` opens RJSF modal with full Widget Create form (Name, Type ApiSelect, Module ApiSelect, Description, DefaultQuery textarea, DefaultParameters textarea (JSON), MinWidth, MinHeight, OrderBy, StoredProcedureName, FilterSchema textarea, QuickFilterSchema textarea, IsSystem switch (BUSINESSADMIN only, defaults false)).
- Row actions: Edit (modal), Delete (guarded — see §④), Toggle Active.

### Tab 4 — Widget Types

- Data-table: WidgetTypeName | WidgetTypeCode | Description | ComponentPath | actions.
- `+ Add Widget Type` modal: Name, Code (UPPER_SNAKE pattern validator), Description, ComponentPath.
- Row actions: Edit, Delete (guarded — blocked if any Widget uses this type).

### Tab 5 — Widget Properties

- Left: Widget picker (dropdown of all widgets).
- Right: list of `(PropertyKey, PropertyValue, DataTypeName)` rows for selected widget + `+ Add Property`.
- Modal: Key, Value, DataType ApiSelect.
- Row actions: Edit, Delete.

### Tab 6 — Widget Roles (MATRIX_CONFIG)

```
┌──────────────────────┬────────────────┬──────────────┬─────────────┬───────────┐
│                      │ BUSINESSADMIN  │ STAFFADMIN   │ STAFFENTRY  │ FIELDAGENT│
│                      │ (system, lock) │              │             │           │
├──────────────────────┼────────────────┼──────────────┼─────────────┼───────────┤
│ Total Donors (KPI)   │ ☑ (locked)     │ ☑            │ ☑           │ ☐         │
│ Donations MTD (KPI)  │ ☑ (locked)     │ ☑            │ ☑           │ ☐         │
│ Donation Trend (Line)│ ☑ (locked)     │ ☑            │ ☐           │ ☐         │
│ Recent Activity (Feed│ ☑ (locked)     │ ☑            │ ☑           │ ☑         │
└──────────────────────┴────────────────┴──────────────┴─────────────┴───────────┘
[Filter: Module ▾]    [Search widget…]    Dirty: 3 cells   [Save Changes] [Discard]
```
- Sticky header column (widget names) + sticky header row (role names).
- Cell type: checkbox.
- Bulk: row click → toggle all editable cells in row; column click → toggle all editable cells in column.
- Filter: Module dropdown narrows widget rows.
- Save sends diff: `{ added: [{widgetId, roleId}], removed: [{widgetId, roleId}] }`.

### Page-Level Actions

| Action | Position | Style | Permission | Confirmation |
|--------|----------|-------|------------|--------------|
| + New Dashboard | top-right | primary | BUSINESSADMIN | — |
| Widget Library | top-right | outline | BUSINESSADMIN | — |
| Reset Dashboard Layout | inside Tab 1 settings panel | destructive | BUSINESSADMIN | type-dashboard-name confirm |
| Delete Dashboard | inside Tab 1 settings panel | destructive | BUSINESSADMIN | affected-users confirm |
| Save Changes (Tab 6) | sticky footer | primary | BUSINESSADMIN | — |
| Discard (Tab 6) | sticky footer | tertiary | BUSINESSADMIN | "Discard {N} changes?" |

### User Interaction Flow (DESIGNER_CANVAS — Tab 2 primary flow)

1. Admin lands on `/setting/dashboardwidget/dashboard` → Tab 1 opens by default → list of dashboards loads.
2. Admin clicks an existing dashboard card → tab 2 (Layout Designer) auto-activates → canvas loads its layout.
3. Admin clicks "+ Add Widget" cell → Widget Library modal opens.
4. Admin clicks a widget card from KPI category → modal closes → widget instance appears at end of canvas → auto-selected → properties pane loads.
5. Admin edits properties → canvas re-renders live → autosave fires 800ms after last keystroke → toast "Saved at 14:32".
6. Admin drags widget to new position → autosave fires → toast.
7. Admin resizes widget (corner handle) → autosave fires → toast.
8. Admin clicks "Remove" in properties pane → confirm modal → widget removed from canvas → autosave.
9. Admin switches to Tab 1 (Dashboards) → Assigned Roles checkboxes update on toggle (per-toggle autosave).
10. Admin switches to Tab 6 (Widget Roles) → matrix loads → toggles cells → footer shows "3 unsaved changes" → clicks Save Changes → diff PATCHes → footer resets.

### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Tab 1 empty | No dashboards exist for tenant | "No dashboards yet. Add your first dashboard." + primary CTA |
| Tab 2 no-selection | No dashboard picked in Tab 1 | "Select a dashboard to design its layout" + link to Tab 1 |
| Tab 2 empty canvas | Selected dashboard has empty layout | "This dashboard has no widgets yet. Click '+ Add Widget' to begin." |
| Loading (any tab) | Initial fetch | Shaped skeletons (tab 1 = card grid skeleton; tab 2 = grid skeleton; tab 6 = matrix-row skeleton) |
| Error | Query fails | Error card with retry button + error code |
| Save error | Mutation fails | Inline error per section + toast |

---

## ⑦ Substitution Guide

> First true DESIGNER_CANVAS in the registry — sets the canonical reference for the sub-type.
> Future DESIGNER_CANVAS screens should map their canonical → this entity using this table:

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| DashboardConfig | (this) | Entity / page name |
| dashboardConfig | (this) | Variable / camelCase prefix |
| Dashboard | Dashboard | Primary canvas-owner entity |
| Widget / WidgetType / WidgetProperty / WidgetRole / DashboardLayout | (re-used) | Underlying catalog + layout + matrix entities |
| sett | sett | DB schema for primary tables |
| auth | auth | DB schema for WidgetRole + new DashboardRole |
| Setting | Setting | Backend group name |
| setting/dashboardwidget | setting/dashboardwidget | FE route folder |

---

## ⑧ File Manifest

> Almost all BE files EXIST. NEW BE work is limited to the `DashboardRole` junction + 2 aggregate handlers + matrix helpers. FE is full rebuild (replacing 5 stub data-tables with one unified 6-tab page).

### Backend Files — NEW

| # | File | Path |
|---|------|------|
| 1 | DashboardRole entity | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/DashboardRole.cs |
| 2 | DashboardRole EF Config | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/DashboardRoleConfiguration.cs |
| 3 | DashboardRole Schemas | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/SettingSchemas/DashboardRoleSchemas.cs |
| 4 | BulkUpdateDashboardRoles command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/DashboardRoles/Commands/BulkUpdateDashboardRoles.cs |
| 5 | GetDashboardRoles query | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/DashboardRoles/Queries/GetDashboardRoles.cs |
| 6 | GetDashboardDesignerState query (composite — returns layout+widgets+roles in one call) | …/SettingBusiness/Dashboards/Queries/GetDashboardDesignerState.cs |
| 7 | SaveDashboardLayout command (wraps UpdateDashboardLayout for FE simplicity) | …/SettingBusiness/DashboardLayouts/Commands/SaveDashboardLayout.cs |
| 8 | GetWidgetRoleMatrix query (composite for Tab 6) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/WidgetRoles/Queries/GetWidgetRoleMatrix.cs |
| 9 | BulkUpdateWidgetRoles command (diff payload) | …/AuthBusiness/WidgetRoles/Commands/BulkUpdateWidgetRoles.cs |
| 10 | EF Migration `Add_DashboardRoles_Table` | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations/{timestamp}_Add_DashboardRoles_Table.cs |
| 11 | DB Seed | PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/DashboardConfig-sqlscripts.sql |

### Backend Files — MODIFY (wiring + endpoints)

| # | File | What to Add |
|---|------|-------------|
| 12 | DashboardQueries.cs | Add `getDashboardDesignerState` GQL field |
| 13 | DashboardLayoutMutations.cs | Add `saveDashboardLayout` GQL field |
| 14 | (NEW) DashboardRoleQueries.cs + DashboardRoleMutations.cs | Endpoints for the new junction |
| 15 | WidgetRoleQueries.cs | Add `getWidgetRoleMatrix` GQL field |
| 16 | WidgetRoleMutations.cs | Add `bulkUpdateWidgetRoles` GQL field |
| 17 | ISettingDbContext.cs | DbSet<DashboardRole> |
| 18 | SettingDbContext.cs | DbSet<DashboardRole> |
| 19 | DecoratorProperties.cs (or DecoratorSettingModules.cs) | Add DashboardRole decorator entry |
| 20 | SettingMappings.cs | Mapster config DashboardRole ↔ DashboardRoleRequestDto/ResponseDto |

### Backend Files — REUSE (no changes)

- All existing Dashboard / DashboardLayout / Widget / WidgetType / WidgetProperty / WidgetRole entities, configs, schemas, CRUD handlers, and existing GQL endpoints.

### Frontend Files — NEW (page-components)

> Base path: `PSS_2.0_Frontend/src/presentation/components/page-components/setting/dashboardwidget/`

| # | File | Path |
|---|------|------|
| 1 | DashboardConfig DTO | PSS_2.0_Frontend/src/domain/entities/setting-service/DashboardConfigDto.ts (composite DTO: dashboards+widgets+widgetTypes+widgetProperties+widgetRoles+dashboardRoles) |
| 2 | DashboardConfig Query barrel | PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/DashboardConfigQuery.ts |
| 3 | DashboardConfig Mutation barrel | PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/DashboardConfigMutation.ts |
| 4 | Zustand store | …/dashboardconfig/dashboardconfig-store.ts (selectedDashboardId, selectedWidgetInstanceId, designer state, dirty matrix cells) |
| 5 | Root page component | …/dashboardconfig/dashboard-config-page.tsx (6-tab shell + URL ?tab= sync) |
| 6 | Tab 1: dashboards-tab.tsx (split list+settings) | …/dashboardconfig/tabs/dashboards-tab.tsx |
| 7 | Tab 1 sub: dashboard-list.tsx | …/dashboardconfig/tabs/components/dashboard-list.tsx |
| 8 | Tab 1 sub: dashboard-settings-panel.tsx | …/dashboardconfig/tabs/components/dashboard-settings-panel.tsx |
| 9 | Tab 1 sub: dashboard-create-modal.tsx | …/dashboardconfig/tabs/components/dashboard-create-modal.tsx |
| 10 | Tab 1 sub: dashboard-edit-modal.tsx | …/dashboardconfig/tabs/components/dashboard-edit-modal.tsx |
| 11 | Tab 1 sub: assigned-roles-checkbox-group.tsx | …/dashboardconfig/tabs/components/assigned-roles-checkbox-group.tsx |
| 12 | Tab 2: layout-designer-tab.tsx | …/dashboardconfig/tabs/layout-designer-tab.tsx |
| 13 | Tab 2 sub: designer-canvas.tsx (react-grid-layout) | …/dashboardconfig/tabs/components/designer-canvas.tsx |
| 14 | Tab 2 sub: widget-cell.tsx | …/dashboardconfig/tabs/components/widget-cell.tsx |
| 15 | Tab 2 sub: widget-properties-pane.tsx | …/dashboardconfig/tabs/components/widget-properties-pane.tsx |
| 16 | Tab 2 sub: widget-library-modal.tsx | …/dashboardconfig/tabs/components/widget-library-modal.tsx |
| 17 | Tab 2 sub: widget-library-card.tsx | …/dashboardconfig/tabs/components/widget-library-card.tsx |
| 18 | Tab 2 sub: autosave-indicator.tsx | …/dashboardconfig/tabs/components/autosave-indicator.tsx |
| 19 | Tab 3: widgets-tab.tsx | …/dashboardconfig/tabs/widgets-tab.tsx (RJSF CRUD on Widget) |
| 20 | Tab 4: widget-types-tab.tsx | …/dashboardconfig/tabs/widget-types-tab.tsx |
| 21 | Tab 5: widget-properties-tab.tsx | …/dashboardconfig/tabs/widget-properties-tab.tsx |
| 22 | Tab 6: widget-roles-matrix-tab.tsx | …/dashboardconfig/tabs/widget-roles-matrix-tab.tsx |
| 23 | Tab 6 sub: matrix-grid.tsx (sticky-header matrix) | …/dashboardconfig/tabs/components/matrix-grid.tsx |
| 24 | Tab 6 sub: matrix-cell.tsx | …/dashboardconfig/tabs/components/matrix-cell.tsx |
| 25 | Tab 6 sub: matrix-toolbar.tsx (filter + search + sticky footer) | …/dashboardconfig/tabs/components/matrix-toolbar.tsx |
| 26 | Tab shell wrapper | …/dashboardconfig/tabs/index.ts (barrel) |
| 27 | Page config | PSS_2.0_Frontend/src/presentation/pages/setting/dashboardwidget/dashboard-config-page-config.tsx |
| 28 | Route page (REPLACE existing stub) | PSS_2.0_Frontend/src/app/[lang]/setting/dashboardwidget/dashboard/page.tsx |

### Frontend Files — MODIFY (wiring)

| # | File | What to Add |
|---|------|-------------|
| 29 | PSS_2.0_Frontend/src/app/[lang]/setting/dashboardwidget/dashboardlayout/page.tsx | Replace stub → redirect / re-export DashboardConfigPageConfig with `defaultTab=designer` |
| 30 | …/widget/page.tsx | Replace stub → redirect / re-export with `defaultTab=widgets` |
| 31 | …/widgettype/page.tsx | Replace stub → redirect / re-export with `defaultTab=widgettypes` |
| 32 | …/widgetproperty/page.tsx | Replace stub → redirect / re-export with `defaultTab=widgetproperties` |
| 33 | PSS_2.0_Frontend/src/app/[lang]/accesscontrol/usersroles/widgetrole/page.tsx | Redirect / re-export with `defaultTab=widgetroles` |
| 34 | setting-service-entity-operations.ts | Add/update DASHBOARD / DASHBOARDLAYOUT / WIDGET / WIDGETTYPE / WIDGETPROPERTY / WIDGETROLE / DASHBOARD_SETTING entries pointing to the unified component |
| 35 | operations-config.ts | Register the new operations |
| 36 | barrel files in setting-queries / setting-mutations / setting-service | Re-export DashboardConfig DTO + GQL |
| 37 | shared-cell-renderers/index.ts (only if NEW cell renderers are introduced — likely none needed) | — |

### Frontend Files — DELETE (after replacement is verified)

| # | File | Reason |
|---|------|--------|
| 38 | …/page-components/setting/dashboardwidget/dashboard-components/data-table.tsx | Replaced by unified tab |
| 39 | …/dashboardlayout-components/data-table.tsx | Replaced |
| 40 | …/widget-components/data-table.tsx | Replaced |
| 41 | …/widgettype-components/data-table.tsx | Replaced |
| 42 | …/widgetproperty-components/data-table.tsx | Replaced |
| 43 | …/page-components/shared/configuration/dashboardmanagement/dashboard-components/data-table.tsx | Pre-existing duplicate — verify no other consumer, then delete |

(Deletion is a follow-up — do NOT delete until verification confirms no other screen imports them. See ISSUE-6.)

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN

# Primary menu (visible in sidebar)
MenuName: Dashboard Configuration
MenuCode: DASHBOARD_SETTING
ParentMenu: SET_DASHBOARDWIDGET
Module: SETTING
MenuUrl: setting/dashboardwidget/dashboard
GridType: CONFIG

MenuCapabilities: READ, CREATE, MODIFY, DELETE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE

GridFormSchema: SKIP
GridCode: DASHBOARDCONFIG

# Hidden satellite menus (kept seeded for capability cascade + legacy URL redirect)
SatelliteMenus:
  - { MenuCode: DASHBOARDLAYOUT,   ParentMenu: SET_DASHBOARDWIDGET, MenuUrl: setting/dashboardwidget/dashboardlayout,   IsLeastMenu: false }
  - { MenuCode: WIDGET,            ParentMenu: SET_DASHBOARDWIDGET, MenuUrl: setting/dashboardwidget/widget,            IsLeastMenu: false }
  - { MenuCode: WIDGETTYPE,        ParentMenu: SET_DASHBOARDWIDGET, MenuUrl: setting/dashboardwidget/widgettype,        IsLeastMenu: false }
  - { MenuCode: WIDGETPROPERTY,    ParentMenu: SET_DASHBOARDWIDGET, MenuUrl: setting/dashboardwidget/widgetproperty,    IsLeastMenu: false }
  - { MenuCode: WIDGETROLE,        ParentMenu: AC_USERSROLES,        MenuUrl: accesscontrol/usersroles/widgetrole,       IsLeastMenu: false }
---CONFIG-END---
```

> Notes:
> - `GridFormSchema = SKIP` — all sub-tabs use custom modals or matrix, not RJSF auto-generated forms.
> - `DELETE` capability listed because Tab 3/4/5 require row deletion.
> - All satellite menus retain their capabilities seeded to BUSINESSADMIN — without this, deep-linking to `accesscontrol/usersroles/widgetrole` would 404 in the role middleware even though the component is the same.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- `DashboardQueries` (extended) + `DashboardMutations` (extended)
- `DashboardLayoutQueries` (existing) + `DashboardLayoutMutations` (extended)
- `WidgetQueries` / `WidgetMutations` (existing — reuse)
- `WidgetTypeQueries` / `WidgetTypeMutations` (existing — reuse)
- `WidgetPropertyQueries` / `WidgetPropertyMutations` (existing — reuse)
- `WidgetRoleQueries` (extended) + `WidgetRoleMutations` (extended)
- **NEW**: `DashboardRoleQueries` + `DashboardRoleMutations`

### Queries

| GQL Field | Returns | Key Args | Notes |
|-----------|---------|----------|-------|
| getDashboard | [DashboardResponseDto] | filter, paging | EXISTING — list of dashboards for tenant |
| getDashboardById | DashboardDto | dashboardId | EXISTING |
| getDashboardDesignerState | DashboardDesignerStateDto | dashboardId | **NEW** — composite: `{ dashboard, layout (LayoutConfig+ConfiguredWidget), widgets[], widgetTypes[], assignedRoles[] }` |
| getDashboardRoles | [DashboardRoleDto] | dashboardId | **NEW** — `{ roleId, roleName, hasAccess }` |
| getWidget | [WidgetResponseDto] | filter, paging | EXISTING |
| getWidgetType | [WidgetTypeResponseDto] | — | EXISTING |
| getwidgetProperty (typo in handler — verify) | [WidgetPropertyResponseDto] | widgetId | EXISTING — fix camelCase in endpoint if needed |
| getWidgetRoles | [WidgetRoleResponseDto] | — | EXISTING — flat list |
| getWidgetRoleMatrix | WidgetRoleMatrixDto | moduleId? (optional filter) | **NEW** — `{ rows: [{widgetId, widgetName, moduleName}], columns: [{roleId, roleName, isSystem}], cells: [{widgetId, roleId, hasAccess}] }` |

### Mutations

| GQL Field | Input | Returns | Notes |
|-----------|-------|---------|-------|
| createDashboard | DashboardRequestDto | int | EXISTING |
| updateDashboard | DashboardRequestDto | int | EXISTING |
| deleteDashboard | dashboardId | int | EXISTING — extend handler to check UserDashboards.count() before delete |
| toggleDashboardStatus | dashboardId | int | EXISTING |
| saveDashboardLayout | { dashboardId, layoutConfig, configuredWidget } | int | **NEW** — thin wrapper around UpdateDashboardLayout (autosave-friendly) |
| bulkUpdateDashboardRoles | { dashboardId, addedRoleIds[], removedRoleIds[] } | int | **NEW** — diff payload |
| createWidget / updateWidget / deleteWidget / toggleWidgetStatus | (existing DTO) | int | EXISTING |
| createWidgetType / updateWidgetType / deleteWidgetType | (existing DTO) | int | EXISTING |
| createWidgetProperty / updateWidgetProperty / deleteWidgetProperty | (existing DTO) | int | EXISTING |
| bulkUpdateWidgetRoles | { cells: [{widgetId, roleId, hasAccess}] } OR diff | int | **NEW** — diff payload; existing `CreateAndUpdateWidgetRoleByModule` is module-scoped — generalize |

### DTO Shapes (NEW types only)

```ts
// FE — domain/entities/setting-service/DashboardConfigDto.ts
export interface DashboardDesignerStateDto {
  dashboard: DashboardResponseDto;
  layout: {
    dashboardLayoutId: number;
    layoutConfig: GridLayoutItem[]; // [{i, x, y, w, h, minW?, minH?}]
    configuredWidget: WidgetInstance[]; // [{widgetInstanceId, widgetId, title, dataSource, metric, groupBy, period, filters{}, refreshInterval, showComparison}]
  };
  widgetCatalog: WidgetResponseDto[];   // for the widget library modal
  widgetTypes: WidgetTypeResponseDto[]; // for category grouping
  assignedRoles: { roleId: number; roleName: string; hasAccess: boolean }[];
}

export interface WidgetRoleMatrixDto {
  rows: { widgetId: number; widgetName: string; moduleName: string; widgetTypeName: string }[];
  columns: { roleId: number; roleName: string; isSystem: boolean }[];
  cells: { widgetId: number; roleId: number; hasAccess: boolean }[];
}

export interface DashboardRoleDto {
  dashboardRoleId?: number;
  dashboardId: number;
  roleId: number;
  roleName?: string;
  hasAccess: boolean;
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/[lang]/setting/dashboardwidget/dashboard`

**Functional Verification (DESIGNER_CANVAS sub-type + matrix + per-section save):**

### Tab 1 (Dashboards)
- [ ] List renders all tenant dashboards + system dashboards
- [ ] `+ New Dashboard` opens modal; Create persists via `createDashboard`; new dashboard appears in list selected
- [ ] Selecting a dashboard loads Settings panel on right
- [ ] Editing Name / Description / Icon / Color / Module + click "Save Settings" → `updateDashboard` → toast
- [ ] Toggling Assigned Roles checkboxes → autosave via `bulkUpdateDashboardRoles` → toast at 500ms debounce
- [ ] Reset Layout → confirm modal → clears `LayoutConfig` + `ConfiguredWidget` → Tab 2 canvas shows empty state
- [ ] Delete Dashboard → if `UserDashboards.count > 0`, confirm modal lists affected user count → on confirm, dashboard removed from list

### Tab 2 (Layout Designer)
- [ ] Selecting a dashboard from Tab 1 + switching to Tab 2 → canvas loads its `LayoutConfig` + `ConfiguredWidget`
- [ ] Empty canvas state ("Add your first widget") if no layout exists
- [ ] "+ Add Widget" empty cell + page-header `Widget Library` both open the same Widget Library modal
- [ ] Widget Library modal groups widgets by WidgetType category (KPI Cards / Charts / Lists & Feeds / Tables)
- [ ] Clicking a widget card adds instance to canvas at end + auto-selects + loads properties pane
- [ ] Drag widget → repositions → autosave fires + toast
- [ ] Resize widget (corner handle) → updates `(w,h)` → autosave + toast
- [ ] Click widget cell → properties pane loads its current settings
- [ ] Editing Title in properties → canvas cell title updates live
- [ ] Editing Data Source / Metric / Group By / Period / Filter → autosave fires
- [ ] Remove widget (properties pane footer) → confirm → cell removed from canvas → autosave
- [ ] Reload page → exact canvas state restored

### Tab 3 (Widgets)
- [ ] Data-table renders all widgets with WidgetTypeName + ModuleName joined
- [ ] `+ Add Widget` modal validates required fields; Create persists
- [ ] Edit modal pre-populates from existing row
- [ ] Delete blocked if `Widget` referenced in any `DashboardLayout.ConfiguredWidget` JSON (server-side check) → show referencing dashboards list

### Tab 4 (Widget Types)
- [ ] Same CRUD pattern as Tab 3
- [ ] Delete blocked if any Widget uses this type → show referencing widgets list

### Tab 5 (Widget Properties)
- [ ] Widget picker dropdown selects parent widget
- [ ] Property rows list for selected widget
- [ ] Add / Edit / Delete modal works

### Tab 6 (Widget × Role Matrix)
- [ ] Matrix renders all widgets × all roles
- [ ] System role columns (e.g. SUPERADMIN) cells rendered disabled
- [ ] Toggle cell → marks dirty → footer shows accurate dirty count
- [ ] Row header click → toggle all editable cells in row
- [ ] Column header click → toggle all editable cells in column
- [ ] Module filter narrows widget rows
- [ ] Search narrows widget rows by name
- [ ] Save Changes → diff PATCH only changed cells → toast `{N} changes saved` → dirty count resets
- [ ] Discard → all dirty cells revert
- [ ] Reload → matrix state matches DB

### Cross-cutting
- [ ] URL `?tab=` syncs with active tab and survives reload
- [ ] Deep-linking to legacy URLs (`/widgetrole`, `/widget`, etc.) opens unified screen with the correct default tab
- [ ] Empty / loading / error states all render with shaped skeletons (no generic shimmer)
- [ ] Non-BUSINESSADMIN roles see neither the sidebar entry nor can deep-link (BE 403)

**DB Seed Verification:**
- [ ] Primary menu `DASHBOARD_SETTING` visible at sidebar under `Settings → Dashboard & Widget`
- [ ] Satellite menus (`DASHBOARDLAYOUT`, `WIDGET`, `WIDGETTYPE`, `WIDGETPROPERTY`, `WIDGETROLE`) seeded with `IsLeastMenu=false` so they don't appear in sidebar but capabilities cascade
- [ ] 3-5 sample dashboards seeded (Executive / Operations / Field Agent) with sample LayoutConfig + ConfiguredWidget
- [ ] 5+ WidgetTypes seeded (KPI_CARD / LINE_CHART / DONUT_CHART / BAR_CHART / FEED / LIST / TABLE)
- [ ] 15+ Widgets seeded matching the mockup's Widget Library (Total Donors / Donations MTD / Active Campaigns / Engagement Score / Donation Trend / Purpose Breakdown / Recent Activity / Pending Tasks / Retention Rate Trend / etc.)
- [ ] WidgetRole rows seeded so BUSINESSADMIN has all access
- [ ] DashboardRole rows seeded so BUSINESSADMIN has all access

---

## ⑫ Special Notes & Warnings

**Universal CONFIG warnings:**
- `CompanyId` is from HttpContext for tenant-custom rows; system rows (`IsSystem=true`) have `CompanyId=NULL`.
- `GridFormSchema = SKIP` — entire screen is custom.
- No view-page 3-mode pattern.

**This screen's unique gotchas:**

1. **Hybrid save model is intentional** — do NOT collapse to a single save model. Canvas autosave gives the "designer feel"; modal CRUD gives admins a confirm step on catalog rows; matrix diff saves are correctness-critical (full-grid POSTs would race).

2. **react-grid-layout dependency** — check `package.json`; if not present, add `react-grid-layout` (and `react-resizable`) before Tab 2 build. The mockup's 4-column grid maps cleanly to a 12-col layout where `1x1 → w:3`, `2x2 → w:6 h:2`, `1x2 → w:3 h:2`, `2x1 → w:6 h:1`. Or use 4-col directly (`react-grid-layout` `cols={{ lg: 4 }}`).

3. **WidgetType.ComponentPath registry coupling** — the FE renderer is resolved at runtime by `ComponentPath`. The build must ensure the seeded ComponentPath values match existing renderer keys in `components/custom-components/dashboards/widgets/`. Otherwise, real dashboards (the consumers of this config) will render "missing component" errors. **Build step**: cross-check seeded `WidgetTypeCode` → `ComponentPath` map against `dashboards/widgets/index.ts` exports.

4. **Tab 6 audit log** — every WidgetRole change can affect what other users see on their dashboards. Audit log MUST capture `(widgetId, roleId, oldHasAccess, newHasAccess, changedBy, changedAt)`. Use the existing `auditEvent` pattern (see #28 Email Provider precedent).

5. **Tab 5 (WidgetProperty) potential confusion**: this is **per-widget config schema** (e.g. Widget "Donation Trend" has properties `dataSourceOptions: [...]`, `metricOptions: [...]`). It is NOT per-instance property values (those live in `DashboardLayout.ConfiguredWidget` JSON). Make sure the tab is labeled "Widget Property Defaults" or "Widget Schema" to avoid that confusion.

6. **Legacy data-table stubs deletion** — the 5 existing data-table.tsx files (`dashboard-components/data-table.tsx`, etc.) MUST be kept until the unified replacement passes E2E. Delete in a follow-up commit after build verification. Document path of each in §⑧ Files-to-Delete list.

7. **Module / module-instance notes**:
   - This is the FIRST true DESIGNER_CANVAS in the registry — sets the canonical reference for the sub-type. Update `_COMMON.md` and `_CONFIG.md` §⑦ post-completion.
   - The original #78 was a tiny ALIGN delta; the combined scope is much larger (6-tab mega-CONFIG). Expect dev time to exceed the 1.0h cap (1.5h dev / 2.0h test more realistic — log overrun).

**Service Dependencies (UI-only — no backend service implementation):**

> Everything in the mockup is in scope. NONE of the on-screen actions require external services that don't exist in the codebase. The widget renderers themselves consume existing GraphQL queries; this config screen does not invoke external services.

No SERVICE_PLACEHOLDERs in this build.

---

## § Known Issues (pre-flagged during planning — 2026-05-14)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | MED | BE — Dashboard entity | Dashboard has no AutoRefreshIntervalMinutes / DefaultDateRange columns; mockup's "Behavior" + "Default Date Range" must be stored somewhere. Options: (a) add 2 cols to Dashboard, (b) store as WidgetProperty rows with synthetic keys `dashboard.autoRefresh` + `dashboard.dateRange`. Recommend (a) for simplicity. | OPEN — decide at BUILD entry |
| ISSUE-2 | MED | BE — DashboardRole (NEW junction) | No precedent in current code; mirror `auth.WidgetRole` shape exactly. Verify whether Schema `sett` or `auth` is the right home (recommend `sett` to keep Dashboard ownership co-located). | OPEN — decide at BUILD entry |
| ISSUE-3 | LOW | BE — Dashboard.Description | Mockup shows Description field but entity has no Description column. Add column OR repurpose `DashboardColor`? Recommend adding `Description nvarchar(500) NULL`. | OPEN |
| ISSUE-4 | MED | BE — bulk delete cascade | Deleting a Dashboard must cascade to DashboardLayout + (new) DashboardRole + UserDashboards. Confirm cascade rules in EF Config. | OPEN |
| ISSUE-5 | HIGH | BE — Widget delete guard | Existing `DeleteWidget` handler likely doesn't check `DashboardLayout.ConfiguredWidget` JSON for references (JSON text column, no FK). Must add a defensive scan that parses each `ConfiguredWidget` JSON and looks for `widgetId` matches. Performance concern — index or full-scan? For tenant-scale (~10s of dashboards) full-scan is fine. | OPEN |
| ISSUE-6 | LOW | FE — legacy file deletion | 5 old data-table.tsx files (per §⑧ row 38-42) become unused after unified build. Hold off on deletion until E2E verification passes. Also verify `page-components/shared/configuration/dashboardmanagement/dashboard-components/data-table.tsx` isn't imported by anything else before deleting. | OPEN |
| ISSUE-7 | MED | FE — react-grid-layout dependency | Confirm whether the package is already in `package.json`. If not, add it + `react-resizable` + their CSS imports in `layout.tsx` or page-level. | OPEN — verify at BUILD entry |
| ISSUE-8 | MED | FE — Widget Type → renderer map | When BUSINESSADMIN creates a new Widget Type with a custom `ComponentPath`, the platform needs a way to register a new renderer. For v1 we restrict WidgetType to system-seeded list (UI hint: "Custom widget types require platform support"). Real extensibility is V2. | OPEN — flag in UX |
| ISSUE-9 | LOW | FE — WidgetProperty UI | Tab 5 is the least-polished tab in the mockup (mockup doesn't show it). UX gets to design from first principles. Recommend keeping it as a simple sub-table under a widget picker — don't over-design. | OPEN |
| ISSUE-10 | LOW | BE — `GetwidgetProperty` typo | Existing handler filename has lowercase `widget` (`GetwidgetProperty.cs`). GQL field name needs verification — if `getwidgetProperty` is exposed, leave it but document; if mid-rename is in progress, fix during BUILD. | OPEN |
| ISSUE-11 | MED | BE — WidgetRole bulk-update generalization | Existing `CreateAndUpdateWidgetRoleByModule` is scoped to a module; Tab 6 matrix is platform-wide (all widgets × all roles, optional module filter). Generalize the handler or write a new one. | OPEN |
| ISSUE-12 | LOW | Seed — sql-scripts-dyanmic typo | Folder typo `dyanmic` preserved per existing convention (don't fix). | OPEN — informational |
| ISSUE-13 | MED | FE — autosave debounce conflict | Canvas autosave at 800ms can race with properties pane autosave at 300ms if user edits both in quick succession. Use a single store-level dirty flag + 800ms global debounce to coalesce. | OPEN |
| ISSUE-14 | LOW | Sidebar — DASHBOARD_SETTING vs DASHBOARD code | The existing route stub uses `menuCode: "DASHBOARD"` (see route stub audit) but MODULE_MENU_REFERENCE has `DASHBOARD_SETTING`. Verify which one the seed uses; FE `useAccessCapability` call must match. Recommend seed using `DASHBOARD_SETTING` (matches MODULE_MENU_REFERENCE) and updating the route stub. | OPEN |
| ISSUE-15 | LOW | URL routing | The 4 satellite routes (dashboardlayout/widget/widgettype/widgetproperty) currently each have their own page.tsx with their own PageConfig import; replacing them to all redirect/render the unified screen is in scope, but watch for stale Next.js cache during dev. | OPEN |
| ISSUE-16 | MED | Estimate | 1.0h dev / 1.5h test cap will be exceeded — this is a 6-tab DESIGNER_CANVAS with new BE junction + matrix + canvas. Expected: ~3-4h dev / 2-3h test. Log overrun at session close. | OPEN — informational |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}