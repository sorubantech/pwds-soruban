# Screen Prompt Template — DASHBOARD (v3)

> For screens whose primary content is a **widget grid rendered via `react-grid-layout`** — KPI cards, charts, tables, drill-down tiles — driven by a `Dashboard` row + `DashboardLayout` JSON, NOT a CRUD grid + form.
>
> Canonical references:
> - **STATIC_DASHBOARD** variant: `#120 Main Dashboard` (each module's existing `crm/dashboards/overview` style page rendered by [`<DashboardComponent />`](../../../PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/index.tsx))
> - **MENU_DASHBOARD** variant: any analytical surface promoted to its own sidebar menu item (`#17 Fundraising Dashboard`, `#52 Case Dashboard`, `#57 Volunteer Dashboard`, etc.)
>
> Use this when: the mockup shows a widget grid (KPIs + charts + tables) with date-range/filter controls — not a CRUD list.
> Do NOT use for: list/grid + modal form (`_MASTER_GRID.md`), or full-page transactional flow (`_FLOW.md`).
>
> ---
>
> ## Variant — pick ONE before filling the template
>
> | Variant | When to pick | How user reaches it | Dashboard switcher? | Build cost |
> |---------|--------------|---------------------|---------------------|-----------|
> | **STATIC_DASHBOARD** | Module-level overview screen with a **dashboard dropdown** that lets the user switch between system + user-created dashboards for that module. The page lives at the module's main `*/dashboards` route. | Click `<Module> → Dashboards` parent menu → DashboardComponent auto-loads `UserDashboard.IsDefault=true`. Dropdown lists all `IsMenuVisible=false` dashboards (system + user-created). | YES — dropdown + Edit Layout / Add Widget / Reset chrome | Mostly seed + alignment work. Single shared `<DashboardComponent />` already exists. |
> | **MENU_DASHBOARD** | A specific dashboard that should be its own sidebar menu item (e.g., "Donor Retention", "Event Analytics", "Predictive Analytics"). Appears as a leaf under `<Module> → Dashboards`. **EXCLUDED from the dropdown** — only reached by clicking its menu item. | Click sidebar leaf → URL becomes `/[lang]/{module}/dashboards/{slug}` → dynamic route resolves slug → renders the bound Dashboard. | NO — no dropdown, no edit chrome by default; pure widget grid via `react-grid-layout`. | Just seed a Dashboard row + DashboardLayout JSON + Menu link. No new FE page (the dynamic route covers all menu dashboards). |
>
> **Mutually exclusive at the row level**: a single `Dashboard` row is either dropdown-listed (`IsMenuVisible=false`) or menu-rendered (`IsMenuVisible=true`). Never both.
>
> ---
>
> ## First-time MENU_DASHBOARD setup (one-time infra — bundled with the FIRST MENU_DASHBOARD prompt)
>
> The MENU_DASHBOARD variant depends on schema + route + sidebar infrastructure that does not exist yet. The **first** MENU_DASHBOARD prompt that ships MUST include all of the items below in its scope. **Every subsequent** MENU_DASHBOARD prompt is then a pure seed-only task and can omit this section.
>
> ### A. Schema extension — `sett.Dashboards` (4 new columns + 1 filtered unique index)
>
> | Column | Type | Default | Notes |
> |--------|------|---------|-------|
> | `MenuId` | `int?` FK → `auth.Menus` (Restrict) | NULL | Links Dashboard to a sidebar menu item |
> | `MenuUrl` | `varchar(250)?` | NULL | kebab-case slug; auto-gen from `DashboardName` if blank |
> | `OrderBy` | `int` | 999 | Sidebar sort order under the `*_DASHBOARDS` parent |
> | `IsMenuVisible` | `bool` | `false` | `true` ⇒ MENU_DASHBOARD; `false` ⇒ STATIC dropdown candidate |
>
> Filtered unique index: `(CompanyId, MenuUrl) WHERE MenuUrl IS NOT NULL AND IsDeleted = false`
>
> Validator rules:
> - `IsMenuVisible=true` ⇒ `MenuId IS NOT NULL` AND `MenuUrl IS NOT NULL`
> - `MenuUrl` matches `^[a-z0-9]+(-[a-z0-9]+)*$`
> - `Menu.ModuleId` MUST equal `Dashboard.ModuleId` (no cross-module orphans)
> - Reserved-slug list blocked: `config`, `new`, `edit`, `read`, `overview` (+ any other static path collision)
>
> ### B. Dynamic route — single FE page replaces per-dashboard hardcoded pages
>
> - Create: `Pss2.0_Frontend/src/app/[lang]/(core)/[module]/dashboards/[slug]/page.tsx`
> - Resolves `slug` → fetches `Dashboard` where `effectiveSlug === slug` → renders `<DashboardComponent slugOverride={slug} />`
> - When `slugOverride` is present, DashboardComponent skips the `IsDefault` auto-pick and selects by slug. Slug-not-found → render existing "not found" empty state (do NOT silently fall back to default).
> - DELETE per-dashboard hardcoded route pages (`crm/dashboards/contactdashboard/page.tsx`, `donationdashboard/page.tsx`, `overview/page.tsx`, etc.) once the dynamic route is verified — pre-flight grep for any imports first.
>
> ### C. New BE query + 2 mutations
>
> | Endpoint | Type | Args | Purpose |
> |----------|------|------|---------|
> | `menuVisibleDashboardsByModuleCode` | Query | `moduleCode` | Sidebar consumption — returns `IsMenuVisible=true` rows ordered by `OrderBy` |
> | `linkDashboardToMenu` | Mutation | `dashboardId, menuId, menuUrl, orderBy` | Sets MenuId + MenuUrl + OrderBy + IsMenuVisible=true. Validates ModuleId match, slug regex, slug uniqueness. Auto-seeds `MenuCapability(MenuId, READ)` if missing. |
> | `unlinkDashboardFromMenu` | Mutation | `dashboardId` | Clears MenuId, sets IsMenuVisible=false. Preserves MenuUrl for revert. Admin-only. |
>
> Also extend the existing `dashboardByModuleCode` projection to include the 4 new fields + computed `menuName`, `menuParentName`, `effectiveSlug`.
>
> ### D. Sidebar auto-injection
>
> When the menu-tree composer renders a parent whose `MenuCode` matches `\w+_DASHBOARDS$`, fetch `menuVisibleDashboardsByModuleCode(parent.moduleCode)` and inject results as leaf items, sorted by `Dashboard.OrderBy`. Each leaf: `MenuName=Dashboard.MenuName ?? Dashboard.DashboardName`, `MenuUrl=/{module}/dashboards/{effectiveSlug}`, `Icon=Dashboard.DashboardIcon`. Batch the queries (one call per render covering all `*_DASHBOARDS` parents) to avoid N+1.
>
> ### E. DashboardComponent chrome additions (STATIC view only)
>
> Add 2 kebab actions on the existing chrome (admin-only):
> - **Promote to menu** (visible when `IsSystem=false AND IsMenuVisible=false`) → modal with MenuParent (read-only), Display Order, Slug (auto-filled from name) → calls `linkDashboardToMenu`. Sidebar refetches.
> - **Hide from menu** (visible when `IsMenuVisible=true`) → confirm → calls `unlinkDashboardFromMenu`. Dashboard returns to dropdown.
>
> ### F. Backfill seed (idempotent — runs once)
>
> `UPDATE sett.Dashboards SET MenuId = m.MenuId, MenuUrl = LOWER(REPLACE(d.DashboardCode, '_', '-')), IsMenuVisible = true FROM auth.Menus m WHERE d.IsSystem = true AND m.MenuCode = d.DashboardCode AND d.MenuId IS NULL` — links every existing system-seeded module dashboard to its matching `Menu` row by `DashboardCode` ↔ `MenuCode`. Place in `sql-scripts-dyanmic/Dashboard-MenuBackfill-sqlscripts.sql` (preserve repo's `dyanmic` typo). Re-running is safe.
>
> ### G. Pre-flagged ISSUEs to copy into the first MENU_DASHBOARD prompt's ⑫
>
> | Severity | Description |
> |---------|-------------|
> | HIGH | Backfill leaves `MenuId=null` for any system dashboard whose `DashboardCode` does not match a `Menu.MenuCode` — pre-flight check must abort cleanup if any rows remain |
> | HIGH | Hardcoded route deletion is destructive — grep imports first; defer if any references found |
> | MED | External bookmarks to old URLs will 404 — decide release-note vs `next.config.js` redirects for one cycle |
> | MED | Slug collisions with reserved static paths — validator must enforce reserved list |
> | MED | Sidebar performance — batch the menu-visible-dashboards query (single call covering all `*_DASHBOARDS` parents), not N+1 |
> | MED | Slug-vs-default precedence — when `slugOverride` is present, do NOT fall back to `IsDefault` if slug is not found; render "not found" instead |
> | LOW | OrderBy collisions — auto-default to `MAX(OrderBy in module-parent) + 10` on Promote |
> | LOW | FK Restrict on Menu delete — surface friendly error in menu-delete handler listing affected dashboards |
> | LOW | `IsRoleDashboard` flag is independent of `IsMenuVisible`; both can be true |
> | LOW | `MenuCapability(Read)` auto-seed on Link; `RoleCapability` grants left to admin via existing role screens |
> | MED | FE registry filenames are `dashboard-widget-registry.tsx` (NOT `widget-registry.ts`) and `dashboard-widget-query-registry.tsx` — do NOT invent new registry filenames; extend the existing two |
> | MED | Path-A widgets seed `Widget.StoredProcedureName` (column name is misleading — it stores a Postgres FUNCTION name) and reuse the generic `generateWidgets` GraphQL handler. NO new C# code; the deliverable is a Postgres function file at `DatabaseScripts/Functions/{schema}/{function_name}.sql` matching the `rep/donation_summary_report.sql` precedent |
> | HIGH | Path-A functions MUST conform to the fixed 5-arg / 4-column contract (`p_filter_json jsonb, p_page int, p_page_size int, p_user_id int, p_company_id int` → `TABLE(data jsonb, metadata jsonb, total_count int, filtered_count int)`). Filter args go through `p_filter_json`, NEVER as native function parameters. Functions written with SQL Server syntax (`CREATE PROCEDURE`, `IF OBJECT_ID`, `[brackets]`) will fail — this is Postgres |
> | LOW | `<DashboardHeader />` toolbar slot — confirm it accepts custom toolbar children; if not, the first MENU_DASHBOARD that needs Export / Print / extra-filter chrome must include a one-time chrome enhancement to add the slot |
>
> ### Why role gating needs no new code
>
> Once `Dashboard.MenuId` is set, role-based menu visibility flows through the existing `auth.RoleCapabilities(RoleId, MenuId, CapabilityId, HasAccess)` table — same path every other sidebar item uses. **No `RoleDashboard` table needed.** Widget-level gating continues via `auth.WidgetRoles` — orthogonal concern, unchanged.
>
> ---

## Template

```markdown
---
screen: {EntityName}                  # e.g., MainDashboard, FundraisingDashboard, DonorRetentionDashboard
registry_id: {#}
module: {Module Name}                 # e.g., CRM, Settings, Fundraising
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: DASHBOARD
dashboard_variant: {STATIC_DASHBOARD | MENU_DASHBOARD}   # ← REQUIRED — drives sections ⑤–⑩
complexity: {Low | Medium | High}
new_module: NO                        # Dashboards never introduce a schema (they aggregate over existing ones)
planned_date: {YYYY-MM-DD}
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (widgets, charts, filters, drill-downs identified)
- [x] Variant chosen (STATIC_DASHBOARD vs MENU_DASHBOARD) and rationale recorded
- [x] Source entities identified (which existing tables the widgets aggregate over)
- [x] Widget catalog drafted (one row per KPI / chart / table widget)
- [x] react-grid-layout config drafted (i, x, y, w, h per widget)
- [x] DashboardLayout JSON shape drafted (LayoutConfig + ConfiguredWidget)
- [x] If MENU_DASHBOARD: parent menu code + slug + OrderBy decided
- [x] If MENU_DASHBOARD AND this is the first one: the "First-time MENU_DASHBOARD setup" infra (template preamble) is folded into this prompt's BE/FE/seed scope
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (widget grid + chart specs + filter controls)
- [ ] User Approval received
- [ ] Backend aggregate query handlers generated (one per composite DTO; or one fat handler returning all widget data)   ← skip if FE_ONLY
- [ ] Backend wiring complete (Schemas, Mappings, Mutations/Queries endpoints)                                            ← skip if FE_ONLY
- [ ] Widget components generated (or reused — most widget primitives ship with `<DashboardComponent />`)                 ← skip if BE_ONLY
- [ ] If STATIC_DASHBOARD: page-level wiring uses the existing route stub; verify DashboardComponent receives correct moduleCode
- [ ] If MENU_DASHBOARD: NO new page file (dynamic route covers it); only seed work
- [ ] DB Seed script generated:
      • Dashboard row (DashboardCode, DashboardName, ModuleId, IsSystem, IsActive)
      • DashboardLayout row (LayoutConfig JSON, ConfiguredWidget JSON)
      • If MENU_DASHBOARD: Menu row + MenuCapability + RoleCapability + Dashboard.MenuId/MenuUrl/OrderBy/IsMenuVisible=true backfill
      • Widget rows (one per widget type if not already seeded) + WidgetRole grants
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at correct route
- [ ] All widgets fetch and render with sample data (no broken queries)
- [ ] Charts render correctly with sample data (axes, legends, tooltips)
- [ ] Date-range / filter controls update the affected widgets (not all widgets if filter is scoped)
- [ ] Drill-down clicks navigate to the correct list/detail screen with prefilled filters where applicable
- [ ] Empty / loading / error states render (Skeleton shapes match widget shapes)
- [ ] role-based widget gating: WidgetRole(HasAccess=false) → widget hidden / replaced with "no access" placeholder
- [ ] role-based menu gating (MENU_DASHBOARD only): RoleCapability(HasAccess=false) on this Dashboard's menu → sidebar leaf hidden
- [ ] If STATIC_DASHBOARD: dropdown lists all dashboards for module EXCEPT IsMenuVisible=true; switching dropdown updates widget grid in place
- [ ] If MENU_DASHBOARD: NO dropdown rendered; URL is `/{lang}/{module}/dashboards/{slug}`; bookmark survives reload
- [ ] react-grid-layout grid renders responsively (widget reflow at xs / sm / md / lg / xl)
- [ ] DB Seed — Dashboard row + DashboardLayout JSON visible in DB; widgets resolve from registry; (MENU_DASHBOARD: menu visible in sidebar at correct OrderBy)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: {EntityName}
Module: {ModuleName}
Schema: {db_schema — typically NONE; dashboards aggregate across schemas}
Group: {BackendGroupName — usually reuses the module's primary group, e.g., DonationModels for Fundraising Dashboard}

Dashboard Variant: {STATIC_DASHBOARD | MENU_DASHBOARD} — see template preamble for rules.

Business: {Rich description — 4-6 sentences covering:
  - What decisions/actions this dashboard supports (e.g., "executives gauge campaign health weekly", "case workers triage open cases by SLA")
  - Target audience (executive / operations / staff / field agent)
  - Why it exists in the NGO workflow
  - Which source modules it rolls up data from
  - For MENU_DASHBOARD: why it earned its own menu slot vs. living inside the dropdown (e.g., "frequently accessed; deep-linkable from email reports; role-restricted to fundraising directors")
  - For STATIC_DASHBOARD: why this is the module's overview page (e.g., "default landing for all CRM users; allows personal customization via dropdown")}

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Dashboards do NOT introduce a new entity. They compose **two seeded rows** (`sett.Dashboards` + `sett.DashboardLayouts`) over **existing source entities**.
> If a cached aggregate table is genuinely needed (rare — only when widget query is too slow for runtime), call it out as ⑫ ISSUE and define the cache table here.

### A. Dashboard Row (`sett.Dashboards`)

> Seeded — not user-created on this prompt. The CRUD for Dashboard rows is the existing `#78 Dashboard Config` screen.

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | {ENTITYUPPER} | Unique within Company; used as default slug if MenuUrl not set |
| DashboardName | {Display Name} | Shown in sidebar (MENU_DASHBOARD) or in dropdown (STATIC_DASHBOARD context) |
| DashboardIcon | {phosphor-icon-name} | e.g., `ph:chart-line`, `ph:users-three` |
| DashboardColor | {hex or null} | Optional accent |
| ModuleId | (resolve from {MODULECODE}) | Determines which module owns it |
| IsSystem | true | All dashboards seeded by this prompt are system dashboards |
| IsActive | true | — |
| MenuId | (only MENU_DASHBOARD) FK to seeded Menu row | NULL for STATIC_DASHBOARD |
| MenuUrl | (only MENU_DASHBOARD) kebab-case slug | NULL for STATIC_DASHBOARD |
| OrderBy | (only MENU_DASHBOARD) sidebar sort | 999 default |
| IsMenuVisible | MENU_DASHBOARD → true; STATIC_DASHBOARD → false | Drives variant routing |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

> One row per Dashboard. Stores `react-grid-layout` config + widget instance configuration as JSON.

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | JSON: `{ "lg": [{i, x, y, w, h, minW, minH}, ...], "md": [...], "sm": [...] }` | react-grid-layout breakpoint configs. `i` value MUST equal each instance's `instanceId` in ConfiguredWidget |
| ConfiguredWidget | JSON: `[{instanceId, widgetId, title?, customQuery?, customParameter?, configOverrides?: {...}}]` | One element per rendered widget. `widgetId` resolves to a `sett.Widgets` row; `customQuery` / `customParameter` (when present) override `Widget.DefaultQuery` / `Widget.DefaultParameters` for this instance only |

### C. Widget Definitions (`sett.Widgets` + `sett.WidgetTypes`)

> Per-widget metadata. Reuse if already seeded; only create rows for genuinely new shapes.

`sett.WidgetTypes` (catalog of renderers — rarely extended):

| Field | Notes |
|-------|-------|
| WidgetTypeName | Human label (e.g., "Multi Chart") |
| WidgetTypeCode | Stable code (e.g., `MULTI_CHART`) — used to match via the `WidgetType` lookup |
| ComponentPath | **Exact key in FE `dashboard-widget-registry.tsx` `WIDGET_REGISTRY`** (e.g., `MultiChartWidget`, `StatusWidgetType1`, `PieChartWidgetType1`). New value here ⇒ FE must register a new renderer (path C). |
| Description | Optional |

`sett.Widgets` (one per logical widget — pick a data path):

| Field | Notes |
|-------|-------|
| WidgetName | e.g., "Total Beneficiaries Served" |
| WidgetTypeId | FK to a WidgetType row |
| **DefaultQuery** | **Path A**: leave NULL. **Path B**: name registered in FE `dashboard-widget-query-registry.tsx` (e.g., `GET_CASE_DASHBOARD_DATA`). **Path C**: same as B but reused across multiple widget instances. |
| **DefaultParameters** | Flat JSON whose keys match the SP/query parameter names. Filter context overrides at runtime. |
| **StoredProcedureName** | **Path A only**: schema-qualified Postgres function name (despite the column label, it stores a function — e.g., `case.case_dashboard_open_cases_by_status`). Mutually exclusive with a non-null DefaultQuery requiring a typed handler. |
| ModuleId | Source module |
| MinHeight, MinWidth, OrderBy, IsSystem | Standard |
| WidgetProperties (1:M) | Optional per-widget config (icon, color, formatter, threshold) — alternative to baking into DefaultParameters |

### D. Source Entities (read-only — what the widgets aggregate over)

| Source Entity | Purpose | Aggregate(s) |
|---------------|---------|--------------|
| {e.g., GlobalDonation} | Total donations widget | SUM(DonationAmount), COUNT(*), AVG by month |
| {e.g., Pledge} | Pledge fulfillment widget | SUM(FulfilledAmount) / SUM(PledgedAmount) |
| ... | ... | ... |

---

## ③ Source Entity & Aggregate Query Resolution

> **Consumer**: Backend Developer (for query handlers) + Frontend Developer (for widget GQL bindings)
> Replaces the FK Resolution Table from MASTER_GRID/FLOW. Dashboards have no FK form — they have **data source bindings**.

| Source Entity | Entity File Path | Aggregate Query Handler | GQL Field | Returns | Args (typical) |
|---------------|-------------------|-------------------------|-----------|---------|----------------|
| {GlobalDonation} | Base.Domain/Models/{Group}/GlobalDonation.cs | Get{EntityName}DonationStats | get{EntityName}DonationStats | {EntityName}DonationStatsDto | dateFrom, dateTo, campaignIds[] |
| {Contact} | Base.Domain/Models/CorgModels/Contact.cs | Get{EntityName}DonorStats | get{EntityName}DonorStats | {EntityName}DonorStatsDto | dateFrom, dateTo, branchId |
| ... | ... | ... | ... | ... | ... |

**Composite vs. Per-Widget queries** — pick one strategy and document it:
- [ ] **Composite**: ONE handler `Get{EntityName}DashboardData` returning a fat DTO with all widget data. Best for tightly-coupled widgets that share filters and re-fetch together. Drawback: every filter change refetches everything.
- [ ] **Per-widget**: N handlers, each widget binds to its own query. Best for independent widgets that re-fetch on different cadences. Drawback: more endpoints to maintain.
- [ ] **Hybrid**: Composite handler for the always-together core (KPIs + main chart) + per-widget handlers for independent panels (e.g., "Top Donors" table that has its own pagination).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators on aggregate queries) → Frontend Developer (filter behavior)
> Dashboards have **less CRUD validation** and **more aggregation rules** + **role-scoped data access rules**.

**Date Range Defaults:**
- Default range: {e.g., "Last 30 days", "Current FY", "MTD"}
- Allowed presets: {e.g., "Today / 7d / 30d / 90d / YTD / Custom"}
- Custom range max span: {e.g., "2 years"} — to bound query cost

**Role-Scoped Data Access:**
- {e.g., "Branch Manager sees only their branch's data — backend filters by user.branchId"}
- {e.g., "Fundraising Director sees all branches but only their fund's campaigns"}
- {e.g., "Admin sees everything — no scoping filter applied"}
- The data scoping happens in the BACKEND query handler, never client-side.

**Calculation Rules** (one row per non-trivial KPI):
- {e.g., "Donor Retention Rate = (Donors_ThisYear ∩ Donors_LastYear) / Donors_LastYear"}
- {e.g., "Avg Gift = SUM(DonationAmount) / COUNT(DISTINCT ContactId) — anonymous donations excluded"}
- {e.g., "Pipeline = SUM(Pledge.OutstandingBalance WHERE PledgeStatus IN ('OnTrack','Behind'))"}

**Multi-Currency Rules:**
- {e.g., "All KPIs reported in Company.DefaultCurrency; foreign-currency rows converted at row's recorded ExchangeRate"}
- {e.g., "If Company has no DefaultCurrency, fall back to most-frequent currency among rows in window — disclose in widget tooltip"}
- {Pre-flag this as ⑫ ISSUE if multi-currency is non-trivial}

**Widget-Level Rules:**
- A widget is RENDERED only if `WidgetRole(WidgetId, currentRoleId, HasAccess=true)` row exists. Otherwise the slot shows a "Restricted" placeholder OR the widget is omitted (decide one — log in ⑫).
- **Workflow**: None. Dashboards are read-only. Drill-down clicks navigate AWAY from this screen.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED based on mockup + chosen variant.

**Screen Type**: DASHBOARD
**Variant**: {STATIC_DASHBOARD | MENU_DASHBOARD}
**Reason**: {one sentence — e.g., "Module overview with personal-customization dropdown" OR "Standalone analytical surface deep-linkable from emails, role-restricted to directors"}

**Backend Implementation Path** — pick per widget; mix freely within one dashboard:
- [ ] **Path A — Postgres function (generic widget)**: Function returns `(data jsonb, metadata jsonb, total_count integer, filtered_count integer)` — reuses existing `generateWidgets` GraphQL field. Seed `Widget.StoredProcedureName='{schema}.{function_name}'`. NO new C# code; only a SQL deliverable. Best for tabular / simple aggregate widgets. **MUST conform to the FIXED 5-arg contract** — see § Path-A Function Contract below.
- [ ] **Path B — Named GraphQL query**: New CQRS handler returning a typed DTO; registered as a named gql query in FE `dashboard-widget-query-registry.tsx`; seed `Widget.DefaultQuery=<name>`. Use when shape is non-tabular but still single-fetch.
- [ ] **Path C — Composite DTO (fat handler)**: ONE handler returning the entire dashboard's data. All widgets share the gql doc + cache key — single round-trip on filter change. Use when most widgets refresh together.

**Path-A Function Contract (NON-NEGOTIABLE — matches `rep.donation_summary_report` precedent):**

The widget runtime always calls `SELECT * FROM {schema}."{functionName}"(@p_filter_json::jsonb, @p_page, @p_page_size, @p_user_id, @p_company_id)`. Every Path-A function MUST therefore:

- Take 5 fixed inputs in this order: `p_filter_json jsonb`, `p_page integer`, `p_page_size integer`, `p_user_id integer`, `p_company_id integer` (any extra optional params MUST have DEFAULTs and come BEFORE `p_company_id`)
- Return `TABLE(data jsonb, metadata jsonb, total_count integer, filtered_count integer)` — 1 row, 4 columns
- Extract every filter from `p_filter_json` inside the body using `NULLIF(p_filter_json->>'keyName','')::type`. Filter args go through this JSON, never as native parameters
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION`, `LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators). NOT SQL Server — this is a Postgres database
- Live at `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/{schema}/{function_name}.sql` — match the existing `rep/donation_summary_report.sql` precedent. snake_case names
- `Widget.DefaultParameters` JSON keys MUST match what the function reads from `p_filter_json` (e.g., `{ "fromDate": "{dateFrom}", "branchId": "{branchId}" }` — placeholders substituted by the widget runtime)

**Backend Patterns Required (paths B/C only):**
- [ ] Aggregate query handler(s) — composite or per-widget per ③
- [x] Tenant scoping (CompanyId from HttpContext) — every query / SP
- [x] Date-range parameterized queries
- [ ] Role-scoped data filtering — {if rules in ④ require it}
- [ ] Materialized view / cached aggregate — {only if widget query exceeds 2s P95}
- [ ] Drill-down arg handler (e.g., GlobalDonation `prefill_pt={id}`) — {if drill-downs prefill the destination}

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` (responsive breakpoints) — already in `<DashboardComponent />`
- [x] Reuse renderers already present in `dashboard-widget-registry.tsx` `WIDGET_REGISTRY` (StatusWidgetType1/2 for KPI, MultiChartWidget / Pie / Bar / Column / RadialBar variants for charts, TableWidgetType1 / NormalTableWidget / FilterTableWidget for tables, GeographicHeatmapWidgetType1 for geo, HtmlWidgetType1/2 for raw HTML)
- [ ] New renderer (path C only) — escalate; create under `dashboards/widgets/{type}/` and register
- [x] Query registry registration (path B/C only) — extend `QUERY_REGISTRY` in `dashboard-widget-query-registry.tsx` with the new gql doc whose name matches `Widget.DefaultQuery`
- [x] Date-range picker / filter chips / drill-down handlers — page-level filter context already wires these to widgets
- [x] Skeleton states matching widget shapes
- [ ] STATIC_DASHBOARD ONLY:
      • Dashboard dropdown switcher (existing in `<DashboardComponent />`)
      • Edit Layout / Add Widget / Reset Layout chrome (existing)
      • Filter: dropdown lists `IsMenuVisible=false` rows only — system + user-created
- [ ] MENU_DASHBOARD ONLY:
      • NO dropdown, NO edit chrome (read-only menu dashboard by default)
      • Renders via dynamic route `[lang]/(core)/[module]/dashboards/[slug]/page.tsx` (created on first MENU_DASHBOARD per template preamble § B)
      • Loaded by slug → resolves to a single Dashboard row → renders its widget grid
      • **Toolbar overrides** (when mockup shows export / print / extra filters in the dashboard header) — surface via `<DashboardHeader />` toolbar slot or escalate as a one-time chrome enhancement; do NOT open-code on the slug route page

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Dashboards are widget grids. Extract every widget, chart, and filter from the mockup.

### Page Chrome (variant-dependent)

**STATIC_DASHBOARD chrome** (existing — render via `<DashboardComponent />`):
- Header row: dashboard name + icon + color | Refresh | Dashboard Switcher (dropdown) | Settings (Edit Layout / Edit Title / Reset Layout)
- Dropdown content rule: `dashboards.filter(d => d.isMenuVisible === false)` — includes ALL system + user-created dashboards EXCEPT menu-promoted ones
- Max 3 user-created dashboards per user per module rule applies

**MENU_DASHBOARD chrome** (lean by default; the mockup may demand more):
- Header row: dashboard name + icon (no dropdown, no edit chrome)
- Optional refresh button
- Optional toolbar with date-range + filter chips
- **Toolbar overrides** — when mockup shows extra controls (filter dropdowns, Export, Print, "Generate Report"), enumerate them in this section as `Toolbar Action: {Label} → {handler/intent/SERVICE_PLACEHOLDER}`. The slug page surfaces them via `<DashboardHeader />` props (toolbar slot). If `<DashboardHeader />` does not yet support a toolbar slot, this prompt's scope MUST include a one-time chrome enhancement (call out in ⑫ ISSUE).
- Body: pure widget grid via `react-grid-layout`

### Grid Layout (react-grid-layout config)

**Breakpoints**:
| Breakpoint | min width | columns |
|------------|-----------|---------|
| xs | 0 | 4 |
| sm | 640 | 6 |
| md | 768 | 8 |
| lg | 1024 | 12 |
| xl | 1280 | 12 |

**Widget placement** (lg breakpoint shown — restate per breakpoint if responsive shape differs):

| i (instanceId) | Widget | x | y | w | h | minW | minH | Notes |
|----------------|--------|---|---|---|---|------|------|-------|
| {kpi-1} | Total Donations YTD | 0 | 0 | 3 | 2 | 2 | 2 | KPI card |
| {kpi-2} | Avg Gift | 3 | 0 | 3 | 2 | 2 | 2 | KPI card |
| {kpi-3} | New Donors | 6 | 0 | 3 | 2 | 2 | 2 | KPI card |
| {kpi-4} | Retention % | 9 | 0 | 3 | 2 | 2 | 2 | KPI card |
| {chart-1} | Revenue by Month | 0 | 2 | 8 | 4 | 6 | 3 | Bar chart |
| {table-1} | Top Donors | 8 | 2 | 4 | 4 | 4 | 3 | Mini table |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Widget Catalog

> One row per widget INSTANCE on the dashboard. Each row maps to one entry in `DashboardLayout.ConfiguredWidget` and references one `sett.Widgets` row.
> Columns:
> - **WidgetType.ComponentPath** = exact key in FE `dashboard-widget-registry.tsx` `WIDGET_REGISTRY` (e.g., `MultiChartWidget`, `StatusWidgetType1`, `PieChartWidgetType1`, `TableWidgetType1`, `GeographicHeatmapWidgetType1`, `HtmlWidgetType1`)
> - **Path** = A (SP via `Widget.StoredProcedureName`), B (named GQL via `Widget.DefaultQuery`), or C (composite GQL — multiple widgets share the same `Widget.DefaultQuery`)
> - **Data Source** = SP name (path A), gql query name (path B/C) — matches column ③

| # | InstanceId | Title | WidgetType.ComponentPath | Path | Data Source | Filters Honored | Drill-Down |
|---|-----------|-------|--------------------------|------|-------------|------------------|-----------|
| 1 | kpi-total-donations | Total Donations YTD | StatusWidgetType1 | C | GET_FUNDRAISING_DASHBOARD_DATA → totalDonations | dateRange | /crm/donation/globaldonation |
| 2 | kpi-avg-gift | Avg Gift | StatusWidgetType1 | C | GET_FUNDRAISING_DASHBOARD_DATA → avgGift | dateRange | — |
| 3 | chart-revenue-by-month | Revenue by Month | MultiChartWidget | C | GET_FUNDRAISING_DASHBOARD_DATA → revenueByMonth | dateRange, campaignIds | /crm/donation/globaldonation?dateFrom=...&dateTo=... |
| 4 | table-top-donors | Top Donors | TableWidgetType1 | A | fund.fundraising_dashboard_top_donors | dateRange, branchId | /crm/contact/contact?mode=read&id={contactId} |
| ... | ... | ... | ... | ... | ... | ... | ... |

### KPI Cards (detail per card)

| # | Title | Value Source | Format | Subtitle | Sparkline/Trend? | Color Cue |
|---|-------|--------------|--------|----------|------------------|-----------|
| 1 | Total Donations YTD | totalDonations | currency (Company default) | "{n} donations from {m} donors" | line sparkline last 12 mo | none |
| ... | ... | ... | ... | ... | ... | ... |

### Charts (detail per chart)

| # | Title | Type | X | Y | Source | Filters Honored | Empty/Tooltip |
|---|-------|------|---|---|--------|------------------|---------------|
| 1 | Revenue by Month | bar | Month (last 12) | Total Amount | revenueByMonth array | dateRange | "No donations in selected period" |
| ... | ... | ... | ... | ... | ... | ... | ... |

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Date Range | date-range picker | Last 30 days | All widgets | Presets + custom |
| Campaign | multi-select (ApiSelectV2) | All | Charts + KPIs (not Top Donors) | typeahead |
| Branch | single-select | User's branch (or All for admin) | All widgets | role-scoped default |
| ... | ... | ... | ... | ... |

### Drill-Down / Navigation Map

| From Widget / Element | Click On | Navigates To | Prefill |
|-----------------------|----------|--------------|---------|
| KPI: Total Donations | Card click | /crm/donation/globaldonation | dateFrom=..., dateTo=... |
| Chart bar | Bar click | /crm/donation/globaldonation | dateFrom=monthStart, dateTo=monthEnd |
| Top Donor row | Row click | /crm/contact/contact?mode=read&id={contactId} | — |
| ... | ... | ... | ... |

### User Interaction Flow

1. **Initial load**:
   - STATIC_DASHBOARD: user lands on `/{module}/dashboards` → DashboardComponent fetches dashboards (`IsMenuVisible=false`) → picks `UserDashboard.IsDefault=true` → loads layout JSON → renders widget grid → all widgets parallel-fetch with default filters.
   - MENU_DASHBOARD: user clicks sidebar leaf → URL becomes `/{module}/dashboards/{slug}` → dynamic route fetches Dashboard by slug → renders widget grid → widgets parallel-fetch.
2. **Filter change** (date range or filter chip): widgets honoring that filter refetch in parallel; widgets not honoring it stay cached.
3. **Switch dashboard** (STATIC_DASHBOARD only): dropdown → DashboardComponent reloads layout JSON for chosen dashboard → grid recomposes → widgets refetch.
4. **Drill-down click**: navigate per Drill-Down Map → destination screen receives prefill args → user lands on filtered list.
5. **Back navigation**: returns to dashboard → filters preserved (URL search params persist where possible — confirm in mockup).
6. **Edit layout** (STATIC_DASHBOARD only, owner only): toggle Edit Layout → widgets become drag/resize-able → Save → POST new LayoutConfig JSON → grid re-renders read-only.
7. **Empty / loading / error states**: each widget renders its own skeleton during fetch; error → red mini banner + Retry; empty → muted icon + "No data in selected range".

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference (TBD — first DASHBOARD prompt sets this) to THIS dashboard.

**Canonical Reference**: {set after first DASHBOARD ships — likely `#120 Main Dashboard` for STATIC_DASHBOARD, `#17 Fundraising Dashboard` for MENU_DASHBOARD}

| Canonical | → This Dashboard | Context |
|-----------|------------------|---------|
| MainDashboard | {EntityName} | Dashboard class/code name |
| MAIN_DASHBOARD | {ENTITYUPPER} | DashboardCode + GridCode |
| main-dashboard | {kebab-case slug} | MenuUrl (MENU_DASHBOARD only) |
| /crm/dashboards/overview | /{module}/dashboards/{slug or "overview"} | route path |
| corg | {schema reused for source data} | source schema |
| CRM | {MODULECODE} | parent module code |
| CRM_DASHBOARDS | {MODULECODE}_DASHBOARDS | ParentMenu (MENU_DASHBOARD only) |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Far fewer files than MASTER_GRID/FLOW because there is no entity CRUD.

### Backend Files (paths B/C only — path-A widgets need only the SP file)

| # | File | Path | Required When |
|---|------|------|---------------|
| 1 | Dashboard DTO(s) | PSS_2.0_Backend/.../Base.Application/Schemas/{Group}Schemas/{EntityName}DashboardSchemas.cs | path B/C |
| 2 | Composite Dashboard query OR per-widget queries | PSS_2.0_Backend/.../Base.Application/Business/{Group}Business/Dashboards/Queries/Get{EntityName}DashboardData.cs (or per-widget) | path B/C |
| 3 | Drill-down support (e.g., `excludeRefunded` arg on existing list query) | Modification to existing list query handler | if drill-down requires arg |
| 4 | Queries endpoint (add new GQL fields) | PSS_2.0_Backend/.../Base.API/EndPoints/{Group}/Queries/{EntityName}Queries.cs (or DashboardQueries.cs) | path B/C |
| 5 | Mapster config additions | {Group}Mappings.cs | if any new projection |
| 6 | Postgres functions (one file per function — match `rep/donation_summary_report.sql` precedent) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/{schema}/{function_name}.sql | path A — one SQL file per function, snake_case name |
| 7 | Materialized view migration | PSS_2.0_Backend/.../Base.Infrastructure/Migrations/{ts}_Add_{EntityName}DashboardView.cs | only if perf demands |

### Backend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | DashboardQueries / {Group}Queries endpoint | register new GQL fields (path B/C) |
| 2 | {Group}Mappings.cs | TypeAdapterConfig for new DTOs (path B/C) |

### Frontend Files (typical 0–3 — most widgets reuse existing primitives)

| # | File | Path | Required When |
|---|------|------|---------------|
| 1 | Dashboard DTO Types | PSS_2.0_Frontend/src/domain/entities/{group}-service/{EntityName}DashboardDto.ts | path B/C |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/{group}-queries/{EntityName}DashboardQuery.ts | path B/C |
| 3 | New Widget renderer | PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/{type}/{NewName}.tsx | path C only (escalate first) |
| 4 | STATIC_DASHBOARD route page (existing — verify only) | PSS_2.0_Frontend/src/app/[lang]/(core)/{module}/dashboards/page.tsx (or specific name) | if STATIC_DASHBOARD; usually no change |
| 5 | MENU_DASHBOARD page | NONE — covered by dynamic `[slug]/page.tsx` (created on first MENU_DASHBOARD per template preamble § B) | NEVER — do not create per-dashboard pages for MENU_DASHBOARD |

### Frontend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-query-registry.tsx` (existing) | extend `QUERY_REGISTRY` with new query name → gql doc (path B/C) |
| 2 | `dashboard-widget-registry.tsx` (existing) | extend `WIDGET_REGISTRY` with new ComponentPath → React component (path C only) |
| 3 | sidebar / menu config | NONE — sidebar auto-injects MENU_DASHBOARD entries from DB seed |

### DB Seed (the bulk of MENU_DASHBOARD work)

| # | Item | When |
|---|------|------|
| 1 | Dashboard row in `sett.Dashboards` | always |
| 2 | DashboardLayout row in `sett.DashboardLayouts` (LayoutConfig + ConfiguredWidget JSON) | always |
| 3 | Widget rows in `sett.Widgets` + WidgetType values | only if new widget types |
| 4 | WidgetRole grants in `auth.WidgetRoles` | always — at minimum BUSINESSADMIN |
| 5 | Menu row in `auth.Menus` (under {MODULECODE}_DASHBOARDS) | MENU_DASHBOARD only |
| 6 | MenuCapability + RoleCapability rows | MENU_DASHBOARD only |
| 7 | UPDATE Dashboard SET MenuId, MenuUrl, OrderBy, IsMenuVisible=true | MENU_DASHBOARD only |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}
DashboardVariant: {STATIC_DASHBOARD | MENU_DASHBOARD}

# STATIC_DASHBOARD: usually NO new menu (the parent module already has its *_DASHBOARDS menu).
# MENU_DASHBOARD: a NEW menu row is created under the module's *_DASHBOARDS parent.

MenuName: {Display Name | — for STATIC_DASHBOARD}
MenuCode: {ENTITYUPPER | — for STATIC_DASHBOARD}
ParentMenu: {MODULECODE_DASHBOARDS | — for STATIC_DASHBOARD}
Module: {MODULECODE}
MenuUrl: {module/dashboards/{kebab-slug} | — for STATIC_DASHBOARD}
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT
  {OtherRole}: READ      # add per ④ role-scoping rules

GridFormSchema: SKIP    # never SKIP_DASHBOARD; SKIP because dashboards have no RJSF form
GridCode: {ENTITYUPPER}

# Dashboard-specific seed inputs
DashboardCode: {ENTITYUPPER}
DashboardName: {Display Name}
DashboardIcon: {ph:icon-name}
DashboardColor: {hex or null}
IsSystem: true
IsMenuVisible: {true if MENU_DASHBOARD; false if STATIC_DASHBOARD}
OrderBy: {N}    # MENU_DASHBOARD only — sort within the *_DASHBOARDS parent
WidgetGrants:    # at minimum BUSINESSADMIN; expand per ④
  - {WIDGET_CODE_1}: BUSINESSADMIN
  - {WIDGET_CODE_2}: BUSINESSADMIN, FUNDRAISING_DIRECTOR
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**Queries:**

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| get{EntityName}DashboardData | {EntityName}DashboardDto | dateFrom, dateTo, filters... | composite — the bulk of widgets |
| get{EntityName}TopDonors (or similar per-widget) | [{EntityName}TopDonorDto] | dateFrom, dateTo, limit | per-widget |
| dashboardByModuleCode (existing) | [DashboardDto] | moduleCode | STATIC_DASHBOARD dropdown source |
| menuVisibleDashboardsByModuleCode (from `dashboard-menu-system.md`) | [DashboardDto] | moduleCode | sidebar injection — not consumed by this prompt directly |

**Composite Dashboard DTO** (one row per field — what the FE consumes):

| Field | Type | Backing Aggregate | Notes |
|-------|------|-------------------|-------|
| totalDonations | decimal | SUM(GlobalDonation.DonationAmount WHERE date in range) | KPI |
| avgGift | decimal | totalDonations / COUNT(DISTINCT ContactId) | KPI |
| newDonorsCount | int | COUNT contacts with first donation in range | KPI |
| retentionPercent | decimal | rule from ④ | KPI |
| revenueByMonth | [ChartPointDto] (month, amount) | grouped SUM | LineChart |
| topDonors | [DonorRowDto] | top-N | inline mini-table |
| ... | ... | ... | ... |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at correct route
- [ ] STATIC_DASHBOARD: route `/{lang}/{module}/dashboards`
- [ ] MENU_DASHBOARD: route `/{lang}/{module}/dashboards/{slug}` (handled by dynamic route from `dashboard-menu-system.md`)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Dashboard loads with default date range and renders all widgets
- [ ] Each KPI card shows correct value formatted per spec (currency, %, count)
- [ ] Each chart renders with correct axes, legend, tooltip
- [ ] Date range change refetches all date-honoring widgets in parallel
- [ ] Each filter (Campaign / Branch / etc.) refetches only the widgets that honor it
- [ ] Each drill-down click navigates to correct destination with correct prefill args
- [ ] Empty state renders when no data in selected range (per widget)
- [ ] Loading skeleton renders during fetch (per widget — shape matches widget shape)
- [ ] Error state renders if a widget query fails (red mini banner + Retry)
- [ ] Role-based data scoping enforced — BE query filters by user's role/branch/etc.
- [ ] Role-based widget visibility — widgets without WidgetRole grant are hidden / show "Restricted"
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl)
- [ ] STATIC_DASHBOARD: dropdown lists all `IsMenuVisible=false` dashboards for module; switching dropdown reloads layout + widgets
- [ ] STATIC_DASHBOARD: this Dashboard row's `IsMenuVisible` is `false` and it appears in the dropdown
- [ ] MENU_DASHBOARD: this Dashboard row's `IsMenuVisible` is `true` and it appears as a sidebar leaf (NOT in any dropdown)
- [ ] MENU_DASHBOARD: bookmarked URL `/{lang}/{module}/dashboards/{slug}` survives reload
- [ ] MENU_DASHBOARD: role-gating via `RoleCapability(MenuId)` hides the sidebar leaf for unauthorized roles

**DB Seed Verification:**
- [ ] Dashboard row inserted with correct ModuleId, IsSystem=true
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (parses cleanly) and ConfiguredWidget JSON
- [ ] Widget rows + WidgetRole grants inserted (at least BUSINESSADMIN)
- [ ] MENU_DASHBOARD: Menu + MenuCapability + RoleCapability seeded; Dashboard.MenuId/MenuUrl/IsMenuVisible=true correctly set
- [ ] Re-running seed is idempotent (NOT EXISTS guards on every INSERT/UPDATE)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents

**Dashboard-class warnings (apply to most prompts of this template):**
- Dashboards are READ-ONLY. No CRUD on this screen — the CRUD for Dashboard rows is `#78 Dashboard Config`.
- Widget queries must be tenant-scoped (CompanyId from HttpContext on every aggregate handler). Easy to forget on a new query handler.
- Composite vs. per-widget query strategy is a trade-off — pick based on filter coupling, not by reflex.
- N+1 risk on per-row aggregates inside widgets (e.g., "Top Donors with last-gift-date") — verify EF translation.
- Multi-currency aggregation MUST be explicit. Defaulting to "sum raw amounts" silently produces wrong numbers across currencies.
- react-grid-layout LayoutConfig JSON must include configs for every breakpoint actually used by the FE. Missing breakpoints cause widget overlap.
- ConfiguredWidget JSON `instanceId` must be unique per dashboard AND must equal the corresponding `i` value in every LayoutConfig breakpoint array (collisions / mismatches cause widget reuse / orphaned-cell bugs).
- Each ConfiguredWidget element references a `widgetId` from `sett.Widgets`. The widget renderer is resolved via `Widgets.WidgetType.ComponentPath` against `WIDGET_REGISTRY` in `dashboard-widget-registry.tsx`. The widget's data query is resolved via `Widget.DefaultQuery` against `QUERY_REGISTRY` in `dashboard-widget-query-registry.tsx`, OR the widget's SP is run by the generic `generateWidgets` GraphQL field if `Widget.StoredProcedureName` is set.
- Drill-down args must use the destination screen's accepted query-param names exactly. Don't invent new ones.

**MENU_DASHBOARD-only warnings:**
- If this is the FIRST MENU_DASHBOARD prompt: the one-time infra (schema columns + dynamic route + sidebar injection + backfill seed) listed in the template preamble's "First-time MENU_DASHBOARD setup" section MUST be included in this prompt's scope. Subsequent prompts can omit it.
- Slug must be kebab-case, unique within (CompanyId, ModuleId), and not collide with reserved static paths (`config`, `new`, `edit`, `read`, `overview`).
- Menu row's `ModuleId` MUST match `Dashboard.ModuleId`. Validator enforces this.
- Per-dashboard FE page files do NOT exist — single dynamic route `[slug]/page.tsx` covers all menu dashboards. If you find yourself creating `dashboards/myname/page.tsx` for a MENU_DASHBOARD, stop — that's the STATIC pattern.
- Sidebar auto-injection happens via `menuVisibleDashboardsByModuleCode` query — no manual sidebar config edits needed.

**STATIC_DASHBOARD-only warnings:**
- Do NOT introduce a sidebar menu item for the dashboard itself — STATIC_DASHBOARD lives at the module's `*_DASHBOARDS` parent route.
- Dropdown filter rule: `dashboards.filter(d => d.isMenuVisible === false)` — must not show menu-promoted dashboards.
- Per-user max-3-custom-dashboards rule still applies; system dashboards do not count.
- DashboardComponent's "Edit Layout" / "Add Widget" / "Reset Layout" chrome is reused as-is. Do not reinvent.

**Service Dependencies** (UI-only — flag genuine external-service gaps):
- {e.g., "⚠ SERVICE_PLACEHOLDER: Export to PDF — full UI in place; handler toasts because PDF rendering service not wired"}
- {leave empty if none}

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
| ① | Identity & Context | All agents | "What dashboard, which variant, why does it exist?" |
| ② | Entity Definition | BA → BE Dev | "Which Dashboard / DashboardLayout / Widget rows to seed; which source entities the widgets read" |
| ③ | Source & Aggregate Resolution | BE Dev + FE Dev | "WHERE is each source entity, WHICH aggregate handler emits the widget data?" |
| ④ | Business Rules | BA → BE Dev → FE Dev | "Date defaults, role scoping, KPI formulas, multi-currency, widget gating" |
| ⑤ | Classification | Solution Resolver | "STATIC_DASHBOARD or MENU_DASHBOARD? Composite or per-widget queries?" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "Page chrome (variant-specific), react-grid-layout config, widget catalog, KPI cards, charts, filters, drill-downs" |
| ⑦ | Substitution Guide | BE Dev + FE Dev | "How to map the canonical dashboard → this dashboard?" |
| ⑧ | File Manifest | BE Dev + FE Dev | "Few BE files, ~0–4 FE files, mostly DB seed work" |
| ⑨ | Approval Config | User | "Confirm seed inputs incl. variant, slug, OrderBy, widget grants" |
| ⑩ | BE→FE Contract | FE Dev | "Composite DTO shape + per-widget query signatures" |
| ⑪ | Acceptance Criteria | Verification | "Variant-specific E2E checks (dropdown vs sidebar leaf), drill-down, role gating, react-grid-layout reflow" |
| ⑫ | Special Notes | All agents | "Variant pitfalls, dashboard-menu-system prerequisite, multi-currency, N+1, slug rules" |

---

## Variant Decision Tree (quick check before filling the template)

```
Is the dashboard reached via the module's main *_DASHBOARDS route + a dropdown switcher?
  YES → STATIC_DASHBOARD. IsMenuVisible=false. No new menu row. Dashboard appears in dropdown.
  NO  → does the dashboard have its own sidebar menu item under *_DASHBOARDS?
        YES → MENU_DASHBOARD. IsMenuVisible=true. New menu row. NOT in dropdown.
              Prereq: dashboard-menu-system.md must be COMPLETED.
        NO  → re-check the mockup. Dashboards must be reachable somehow.
```
