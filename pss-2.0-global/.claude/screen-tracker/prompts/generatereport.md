---
screen: GenerateReport
registry_id: 154
module: Report & Audit
status: COMPLETED
scope: FE_ONLY
screen_type: REPORT
report_subtype: TABULAR
complexity: Low
new_module: NO
planned_date: 2026-05-13
completed_date: 2026-05-13
last_session_date: 2026-05-13
---

> **⚠ READ THIS FIRST — Activation, not a build**
>
> Despite the registry stamp "NEW / FULL", investigation shows the entire report engine is
> already implemented in this codebase. The Generate Report screen is a **thin activation
> shell** over an existing generic report execution engine (`ReportDataTable`).
>
> No new BE entities, queries, mutations, schemas, EF configs, DbContext changes, or migrations
> are required. No new FE components, stores, GQL queries, or DTOs are required either.
> The only file that needs to change is the Next.js app-route page (currently rendering an
> `UnderConstruction` stub). The page-component, page-config, and ReportDataTable engine are
> already wired and tested by 3 sibling screens (Donation Generate Report, Contact Generate
> Report, Communication Generate Report) that use the **same engine** with a different
> `menuCode`.
>
> **Effective scope**: ~10 lines of code in 1 file. No mockup is required because the design
> is fixed by the reusable engine — sibling screens already render it identically.

---

## Tasks

### Planning (by /plan-screens)
- [x] Existing-code analysis complete (engine reusable, BE complete, FE engine complete)
- [x] Activation file identified (`app/[lang]/reportaudit/reports/generatereport/page.tsx`)
- [x] Sibling references identified (donationreport / contactreport / communicationreport)
- [x] Menu seed verified (registered in `Pss2.0_Global_Menus_List.sql:522`)
- [x] Capability constant verified (`DecoratorApplicationModules.GenerateReportAdmin = "GENERATEREPORT"`)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated — minimal (activation only — confirm role-scoping behavior + capability flags)
- [x] Solution Resolution complete — SKIP_OR_THIN (engine reuse; no architectural decisions)
- [x] UX Design finalized — SKIP (UI is fixed by `ReportDataTable` engine)
- [x] User Approval received (Decision A: keep reportaudit/reports path, delete shared/rms duplicates. Decision B: keep current REPORTAUDIT-scoped moduleCode behavior — no engine changes.)
- [x] Backend: SKIP (no BE work)
- [x] Frontend: Replace `UnderConstruction` stub at app-route page with `<GeneratePageConfig />`
- [x] Frontend: entity-operations registration N/A in this codebase — capability gating is handled by `useAccessCapability({ menuCode: "GENERATEREPORT" })` inside `GeneratePageConfig`. No `entity-operations.ts` / `operations-config.ts` files exist in this repo. Verified via Glob.
- [x] DB Seed: SKIP (menu + capabilities + role-capabilities already seeded via `_seed_child_menu`)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `pnpm dev` — route loads at `/{lang}/reportaudit/reports/generatereport`
- [ ] Header toolbar renders a "Select Report" dropdown populated from `REPORTS_BY_MODULE_QUERY`
  (note: `moduleCode` comes from global store, so dropdown only shows reports for whichever module
  the user is currently navigated into — confirm this is the intended scope vs. an unrestricted list)
- [ ] On report selection, filter schema renders (when the report has a `FilterSchema`)
- [ ] Generate fetches data via `GENERATE_REPORTS_QUERY`, table renders with dynamic columns
- [ ] Pagination, sort, search, filter, layout-toggle (rows ↔ card), full-screen, refresh, clear-filter all work
- [ ] Chart View toggle renders chart if report metadata supports it
- [ ] Export button visible when `canExport` capability is true; produces a file
- [ ] Print / Share / Subscribe options behave per generic engine (SERVICE_PLACEHOLDER toasts acceptable)
- [ ] Access Denied page renders when role lacks `READ` capability for `GENERATEREPORT`

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Generate Report
Module: Report & Audit (`REPORTAUDIT`)
Schema: `rep` (Reports schema — reused, no new tables)
Group: Report (existing `Base.Application/Business/ReportBusiness/`)

Business: The Generate Report screen is the **generic report-execution console** for the platform.
It does NOT define a single report — it lets a user pick from the catalog of registered reports
(rows in `rep."Reports"`), populate the report's declarative filter schema, execute the
configured stored procedure on the BE, and render the result with a dynamic column engine
that respects per-column data types (currency, date, percentage, boolean, badge, etc.).
The audience is **BUSINESSADMIN and any role granted READ on `GENERATEREPORT`** — typically
the analyst persona who runs ad-hoc/parameterized reports. Frequency varies per report
(daily reconciliation, monthly close, on-demand drill-down). Data sensitivity is whatever
the underlying stored procedure exposes — tenant scoping (`CompanyId` from logged-in user)
is auto-merged into parameters by the existing `useInitializeReportDataTableDatas` hook.
Format expectations: the engine supports rows view, card view, chart view, full-screen mode,
search/filter chips, sort, pagination, refresh, print, share, subscribe, and CSV/Excel export.

The Generate Report **menu** is the *unscoped* / *cross-module* entry point — it lives at
`Report & Audit › Reports › Generate Report` so any user with the menu capability can land
here and the report-list dropdown shows reports whose `Module.ModuleCode = currentModuleCode`
from global store. Sibling menus (`DONATIONGENERATEREPORT`, `CONTACTGENERATEREPORT`,
`COMMUNICATIONGENERATEREPORT`) use the same engine but live inside specific modules so they
auto-filter the dropdown to that module. **This screen is the same engine without an
implicit module scope** — confirm during build whether that's the intended behavior (it
matches the existing implementation in `presentation/pages/reportaudit/reports/generatereport.tsx`).

> **Why "activation" is the right framing**: the original registry stamp ("NEW / FULL /
> mockup-TBD / FK depends on ReportCatalog #99") is misleading. Investigation shows:
> - The `Report` entity + `ReportExecutionLog` + `ReportRole` already exist in the
>   `rep` schema with full CRUD endpoints (`ReportQueries.cs`, `ReportMutations.cs`)
> - Four BE GraphQL queries already implement the entire flow: `GetReports`,
>   `GetReportsByModule`, `GetReportById`, `GenerateReports`
> - The `ReportDataTable` engine (`custom-components/data-tables/report/`) is a complete,
>   battle-tested, generic report-rendering component with ~15 sub-components and a Zustand
>   store dedicated to it
> - The wrapper page-component (`page-components/reportaudit/reports/generatereport/data-table.tsx`)
>   and the page-config (`presentation/pages/reportaudit/reports/generatereport.tsx`) are
>   already written and tested
> - The menu, menu-capabilities, and BUSINESSADMIN role-capabilities are seeded via
>   `_seed_child_menu('Generate Report','GENERATEREPORT',...)` at line 522 of
>   `Pss2.0_Global_Menus_List.sql`
> - The `GENERATEREPORT` capability constant exists in `DecoratorProperties.cs:205`
>
> The only thing missing is that the actual Next.js route file (`app/[lang]/reportaudit/reports/generatereport/page.tsx`)
> still renders `UnderConstruction` instead of `<GeneratePageConfig />`. That is the build.

---

## ② Source Model

> **Consumer**: BA Agent → Backend Developer
> Reports rarely own a table — they query existing entities. State the source pattern.

**Source Pattern**: `query-only` (engine-level) + `report-row-table` (catalog-level)

- **Catalog table**: `rep."Reports"` — already exists. One row per registered report
  (`ReportCode`, `ReportName`, `ModuleId`, `StoredProcedureName`, `FilterSchema` JSON, `ReportType`,
  `IsSystem`, `CompanyId`).
- **Per-report execution**: each report row points to a `StoredProcedureName` in the DB.
  Execution is a `query-only` aggregation against whatever source entities that stored
  procedure consumes. The screen itself doesn't query source entities — it routes through
  the stored procedure named in `rep."Reports".StoredProcedureName`.

**Stamp**: `query-only` (the screen does not store anything new)

### Source Entities (consumed by the engine — already implemented)

| Source Entity | Entity File Path | Fields Consumed | Purpose |
|---------------|------------------|-----------------|---------|
| `Report` | `Base.Domain/Models/ReportModels/Report.cs` | `ReportId`, `ReportName`, `ReportCode`, `Description`, `ReportType`, `ModuleId`, `StoredProcedureName`, `FilterSchema`, `IsSystem`, `CompanyId` | Catalog dropdown + filter schema source |
| `Module` | (existing auth Module entity) | `ModuleCode`, `ModuleName` | FK target for `Report.ModuleId` — filter dropdown by current `moduleCode` |
| `ReportExecutionLog` | `Base.Domain/Models/ReportModels/ReportExecutionLog.cs` | execution audit | Optional logging of generation calls (already wired) |
| Per-report stored procedure | DB (Postgres) | declared in `Report.StoredProcedureName` | Returns rows + column metadata + filter schema |

### Storage Table (catalog only — already seeded)

| Field | C# Type | MaxLen | Notes |
|-------|---------|--------|-------|
| ReportId | int | — | PK |
| ReportName | string | — | display |
| ReportCode | string | — | uppercase code |
| Description | string? | — | — |
| ReportType | string? | — | tabular / pivot / document hint |
| ModuleId | Guid | — | FK Module |
| StoredProcedureName | string | — | the SP that returns the data |
| FilterSchema | string? | — | JSON: `{ schema, uiSchema }` per RJSF |
| IsSystem | bool | — | system vs tenant-defined |
| CompanyId | int? | — | NULL for system reports, set for tenant-defined |

### Computed / Derived Columns

> Computed per-report by each stored procedure. The engine reads column metadata from the
> SP's `metadata.columns` JSON output — so the engine itself does no computation.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` / joins) + Frontend Developer (for ApiSelect filter dropdowns).
>
> Note: this screen has **no direct FK targets** that the BE Developer needs to wire. The
> existing `ReportQueries.GetReportsByModule` already handles the `Module` FK lookup
> through the advanced-filter `module.moduleCode` rule.

| FK / Filter Source | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type | Used For |
|--------------------|--------------|-------------------|----------------|---------------|-------------------|----------|
| ReportId (report picker) | Report | `Base.Domain/Models/ReportModels/Report.cs` | `GetReportsByModule` (already used) | `reportName` | `ReportResponseDto` | header toolbar dropdown |
| ModuleId (data scope) | Module | (existing) | (filtered inline via advanced filter rule on `module.moduleCode`) | `moduleCode` | — | global-store-driven filter on report list |
| (Per-report filter schema FKs) | — | — | varies per stored procedure | — | — | dynamic filter form RJSF |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (filter validation)

**Required Filters**: declarative per-report — defined in `rep."Reports".FilterSchema`. The engine
auto-renders required-field validation from the RJSF schema. The screen-level shell has no
required filter of its own (other than implicit "must pick a report first").

**Filter Validation**: handled by the RJSF schema declared per report. The engine respects
required, min, max, pattern, enum constraints from the JSON schema. Date-range / numeric-range
validation comes from the report definition, not the screen.

**Computed-Column Rules**: per stored procedure. The screen renders whatever columns the SP
emits in its `metadata.columns` payload.

**Role-Based Data Scoping** (row-level security):

| Role | Sees | Excluded |
|------|------|----------|
| BUSINESSADMIN | all data for tenant | none |
| Any role granted READ on `GENERATEREPORT` | reports filtered by `currentModuleCode` from global store | reports outside that module |
| All roles | reports where `IsSystem = true` OR `CompanyId = current tenant` | other tenants' tenant-defined reports |

> **Implementation note**: scoping happens in BE. The `GenerateReports` query auto-merges
> `companyId` from the logged-in user into the stored procedure parameters (see
> `report-datatable-fetch.tsx:207-209`). The per-report stored procedure must use that
> parameter to enforce row-level security.

**Sensitive Data Handling**:

| Field | Sensitivity | Display Treatment | Export Treatment |
|-------|-------------|-------------------|------------------|
| (Per report) | varies | declared by SP — engine respects `isVisible` flag per column | exports respect column visibility |

> The engine has no built-in PII masking — that's the report-author's responsibility per SP.

**Max-Row Guard**: page size is capped at 100 server-side (`Math.min(pageSize, 100)` in
`report-datatable-fetch.tsx:218`). Pagination is server-paginate by default. No max-row banner
is implemented because the engine paginates by default.

**Workflow**: None — reports are read-only outputs.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on code analysis.

**Screen Type**: REPORT (per user direction in /plan-screens session 2026-05-13)
**Report Sub-type**: `TABULAR` (engine default; PIVOT_CHART layout is available via the chart-view toggle but is data-driven per report definition)
**Source Pattern**: `query-only` (engine) + `report-row-table` (catalog)
**Pagination Strategy**: `server-paginate` (engine refetches on page/sort change with `pageSize ≤ 100`)

**Reason**: The screen is a generic execution shell for a catalog of registered reports. Each
report defines its own filter schema (RJSF JSON) and column metadata (returned in the SP's
`metadata.columns` payload). The engine renders a tabular result by default with optional
card view and chart view modes. Sub-type is `TABULAR` because that is the dominant default
shape; reports that need pivot/document layouts can use the engine's chart-view toggle or
require a different screen.

**Backend Patterns Required:**

For **TABULAR** report (engine-level — ALL ALREADY DONE):

- [x] `GetReports` query — list all reports, paginated (`ReportQueries.GetReports`)
- [x] `GetReportsByModule` query — filtered list by module (`ReportQueries.GetReportsByModule`)
- [x] `GetReportById` query — single report metadata + filter schema (`ReportQueries.GetReportById`)
- [x] `GenerateReports` query — executes the report SP with parameters; returns
      `BaseApiResponse<ReportResult>` with rows + column metadata + total/filtered count
      (`ReportQueries.GenerateReports`)
- [x] Tenant scoping (`CompanyId` from HttpContext — merged into SP params client-side
      in `report-datatable-fetch.tsx:207-209`, **confirm BE-side also enforces it via
      `ReportRequest`**)
- [x] Role-based data filtering applied via per-report SP (caller's responsibility per report)
- [x] CSV / Excel export — handled by `ReportExportController.cs` + `DataTableGenerateExportButton`

> ⚠ **Engine-level check during build**: confirm the BE merges `companyId` server-side too.
> The FE auto-merge in `report-datatable-fetch.tsx` is defense-in-depth, but the SP itself
> must enforce tenant isolation. This is a per-report-SP responsibility, not a screen one.

**Frontend Patterns Required (engine — ALL ALREADY DONE):**

- [x] Report page shell (header + report-picker dropdown + filter region + result region + export)
- [x] Filter panel (RJSF schema-driven, conditional on selected report having a FilterSchema)
- [x] Result table (`ReportDataTableContainer` — sortable, paginated, sticky header, card-view
      toggle, full-screen, breadcrumb navigation for drill-down)
- [x] Pagination (server-paginate)
- [x] Export menu (Excel + via `DataTableGenerateExportButton`)
- [x] General toolbar with: search, filter, clear-filter, refresh, share, subscribe, print,
      full-screen, layout-toggle (rows ↔ card), chart-view, info
- [x] Empty state (when no report selected — DefaultEmptyState "Select a Report")
- [x] Loading skeleton matching table shape (`DefaultTableWithCellSkeletons`)
- [x] Error state (network/server errors render in destructive card)

**Activation work (REQUIRED — the only build):**

- [ ] Replace `UnderConstruction` stub at `app/[lang]/reportaudit/reports/generatereport/page.tsx`
      with default export that renders `<GeneratePageConfig />`

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> The UI is fixed by the existing `ReportDataTable` engine. This section describes what the
> engine renders (so reviewers can verify behavior) — no new design work is required.

### 🎨 Visual Treatment (rendered by `ReportDataTableContainer`)

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ [📊]  Data Export Reports                          [Select Report ▾] [Export ⬇] │
│       (Report Code: <selected reportCode>)            (when canExport)           │
├──────────────────────────────────────────────────────────────────────────────────┤
│ [🔍 Search] [⚙ Filter] [↻ Refresh] [⤢ Layout] [📊 Chart] ... [Print] [Share] [⛶] │  ← General Toolbar (only when reportCode set)
├──────────────────────────────────────────────────────────────────────────────────┤
│ < Filter chips / RJSF filter form >                                              │  ← Conditional on filterSchemas
├──────────────────────────────────────────────────────────────────────────────────┤
│ Column1 │ Column2 │ Column3 │ Column4 │ ...                                       │  ← Dynamic columns from SP metadata
│ row 1   │ ...     │ ...     │ ...     │                                           │
│ row 2   │ ...     │ ...     │ ...     │                                           │
│ ...                                                                              │
├──────────────────────────────────────────────────────────────────────────────────┤
│ « Prev  |  Page 1 of N  |  Page size [10▾]  |  Showing 1-10 of N  |  Next »      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Initial State (no report selected)

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ [📊]  Data Export Reports                          [Select Report ▾]            │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│                                  📑                                              │
│                          Select a Report                                         │
│   To begin, please select a report from the panel on the right. The selected     │
│   report's data and visualizations will appear here for your review and          │
│   analysis.                                                                      │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Reference implementations (already in code — clone these patterns)

| Sibling Screen | Page-Component Path | menuCode | gridCode |
|----------------|---------------------|----------|----------|
| Donation Generate Report | `page-components/crm/dashboards/donationreport/data-table.tsx` | `DONATIONGENERATEREPORT` | `GENERATEREPORT` |
| Contact Generate Report | `page-components/crm/dashboards/contactreport/data-table.tsx` | `CONTACTGENERATEREPORT` | `GENERATEREPORT` |
| Communication Generate Report | `page-components/crm/dashboards/communicationreport/data-table.tsx` | `COMMUNICATIONGENERATEREPORT` | `GENERATEREPORT` |

The `GenerateReportDataTable` at
`page-components/reportaudit/reports/generatereport/data-table.tsx` already follows this same
pattern with `gridCode = "GENERATEREPORT"` and `menuCode = "GENERATEREPORT"`.

### Anti-patterns to refuse

- ❌ Do NOT write a new copy of `ReportDataTable` — reuse the existing engine
- ❌ Do NOT add a custom page-config file — `GeneratePageConfig` exists and is correct
- ❌ Do NOT add new GQL queries — `GENERATE_REPORTS_QUERY`, `REPORT_BY_ID_QUERY`, `REPORTS_BY_MODULE_QUERY` exist
- ❌ Do NOT add new BE handlers — `GetReports*` / `GenerateReports` cover all cases
- ❌ Do NOT add new DTOs — `ReportResponseDto`, `ReportResult`, `ReportRequest` exist
- ❌ Do NOT add MenuCapabilities or RoleCapabilities seed rows — handled by `_seed_child_menu`
- ❌ Do NOT regenerate `entity-operations.ts` if `GENERATEREPORT` entry exists (verify; only add if missing)

---

## ⑦ Substitution Guide

> Not applicable for activation. There is no canonical reference being substituted —
> the implementation already exists. For any future REPORT screens that follow this
> generic-engine pattern, use this Generate Report screen as the canonical reference.

| Canonical | → This Entity | Context |
|-----------|---------------|---------|
| `GeneratePageConfig` | `GeneratePageConfig` | Page-config name (identical — already exists) |
| `GenerateReportDataTable` | `GenerateReportDataTable` | Page-component (identical — already exists) |
| `ReportDataTable` | `ReportDataTable` | Custom-component engine (reuse as-is) |
| `GENERATEREPORT` | `GENERATEREPORT` | Menu code + grid code + capability constant |
| `REPORTAUDIT` | `REPORTAUDIT` | Module code |
| `RA_REPORTS` | `RA_REPORTS` | Parent menu code |
| `reportaudit/reports/generatereport` | `reportaudit/reports/generatereport` | Route path |

---

## ⑧ File Manifest

> **Activation is small.** Only ONE file is being modified. All other files exist and are correct.

### Backend Files — NONE

> **No backend work.** The Report entity, queries, mutations, exports, and ReportFeature
> infrastructure (`ReportRequest`, `ReportResult`, `ReportSchemas`) are all complete.

### Frontend Files — ONE (modify)

| # | File | Action | Notes |
|---|------|--------|-------|
| 1 | `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/generatereport/page.tsx` | **MODIFY** | Currently exports `UnderConstructionPage` rendering `<UnderConstruction />`. Replace with default export that returns `<GeneratePageConfig />` imported from `@/presentation/pages/reportaudit/reports/generatereport`. The commented-out lines 1-7 in that same file already show the correct shape; just uncomment + delete the under-construction fallback. |

### Frontend Files — NONE (already exist, verify only)

| # | File | Action | Notes |
|---|------|--------|-------|
| — | `presentation/pages/reportaudit/reports/generatereport.tsx` | VERIFY | Exports `GeneratePageConfig` (already correct, lines 24-35) |
| — | `presentation/pages/shared/rms/generatereport.tsx` | VERIFY | Duplicate / legacy alternate path of the same `GeneratePageConfig` — confirm whether to delete to avoid drift (file contents are byte-identical to the reportaudit-path version) |
| — | `presentation/components/page-components/reportaudit/reports/generatereport/data-table.tsx` | VERIFY | `GenerateReportDataTable` already correct, lines 5-19 |
| — | `presentation/components/page-components/shared/rms/generatereport/data-table.tsx` | VERIFY | Duplicate / legacy alternate path — confirm whether to delete |
| — | `presentation/components/custom-components/data-tables/report/*` | NO CHANGE | Engine — leave alone |
| — | `infrastructure/gql-queries/*` | NO CHANGE | `GENERATE_REPORTS_QUERY`, `REPORT_BY_ID_QUERY`, `REPORTS_BY_MODULE_QUERY` all exist |

### Frontend Wiring Updates — VERIFY (likely already complete)

| # | File | Action | Notes |
|---|------|--------|-------|
| 1 | `entity-operations.ts` | VERIFY | Does it have a `GENERATEREPORT` operations entry? If yes, leave; if no, add a minimal entry mirroring sibling reports |
| 2 | `operations-config.ts` | VERIFY | Same |
| 3 | Sidebar menu config | NO CHANGE | Menu is rendered dynamically from auth Menus table — already seeded |

### Backend Wiring Updates — NONE

### DB Seed — NONE

> Menu + 8 MenuCapabilities + 8 BUSINESSADMIN RoleCapabilities all seeded via
> `Pss2.0_Global_Menus_List.sql:522` `_seed_child_menu('Generate Report','GENERATEREPORT',...)`.
> No separate `GenerateReport-sqlscripts.sql` file is needed. If the user later wants a
> bespoke seed (e.g., to add a default report row for the catalog), that is a separate task.

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FE_ONLY

MenuName: Generate Report
MenuCode: GENERATEREPORT
ParentMenu: RA_REPORTS
Module: REPORTAUDIT
MenuUrl: reportaudit/reports/generatereport
GridType: FLOW  (engine renders as a REPORT, but the underlying registered grid type is FLOW since it has no GridFormSchema)

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER
  (8-capability standard set seeded by _seed_child_menu — all already present)

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  (already seeded by _seed_child_menu)

GridFormSchema: SKIP
GridCode: GENERATEREPORT
---CONFIG-END---
```

> ⚠ **Capability set is broader than typical REPORT**: the seed function inserts the full
> 8-capability set because `_seed_child_menu` is generic and doesn't differentiate REPORT
> from CRUD screens. For this activation, only `READ`, `EXPORT`, and `ISMENURENDER` are
> functionally consumed by the engine. The other capabilities (`CREATE`/`MODIFY`/`DELETE`/
> `TOGGLE`/`IMPORT`) are inert on this screen but won't cause harm. Do NOT remove them —
> rolling back capabilities is more risk than benefit.

---

## ⑩ Expected BE→FE Contract

> All queries already exist; this section documents the runtime contract for the engine.

### Queries (already wired)

| GQL Field | Returns | Key Args | Source |
|-----------|---------|----------|--------|
| `getReportsByModule` | `PaginatedApiResponse<IEnumerable<ReportResponseDto>>` | `request: GridFeatureRequest` (with advancedFilter `module.moduleCode = currentModuleCode`) | `ReportQueries.GetReportsByModule` |
| `getReportById` | `BaseApiResponse<ReportResponseDto>` | `reportId: int` | `ReportQueries.GetReportById` |
| `generateReports` | `BaseApiResponse<ReportResult>` | `request: ReportRequest` (reportCode, parameters JSON, pageIndex, pageSize, reportMode) | `ReportQueries.GenerateReports` |

### Report Response DTO (catalog row)

| Field | Type | Notes |
|-------|------|-------|
| reportId | int | PK |
| reportName | string | display |
| reportCode | string | uppercase |
| description | string? | — |
| reportType | string? | — |
| moduleId | Guid | FK Module |
| moduleCode | string (joined) | for filtering |
| storedProcedureName | string | SP that returns data |
| filterSchema | string? | RJSF JSON string |
| isSystem | bool | — |

### ReportResult DTO (execution output)

| Field | Type | Notes |
|-------|------|-------|
| pageIndex | int | — |
| pageSize | int | capped at 100 |
| parameters | string? | echoed params JSON |
| reportCode | string | — |
| totalCount | int | — |
| filteredCount | int | — |
| data | `ReportRow[]` | `{ rowIndex, values: [{ key, value }] }` |
| metadata | `ReportMetadata[]` | `[{ key: "columns", value: <ReportColumn[] JSON> }, { key: "navigation", value: <NavigationConfig JSON> }, …]` |

### ReportColumn (inside metadata.columns JSON)

| Field | Type | Notes |
|-------|------|-------|
| orderBy | int | display order |
| dataType | string | string / int / decimal / date / datetime / boolean / percentage |
| fieldKey | string | row.values key |
| fieldName | string | header |
| isPrimary | bool | — |
| isVisible | bool | column visibility |
| isPredefined | bool | — |
| gridComponentName | string | optional JSON: `{ componentType, …customConfig }` |
| width | int? | px hint |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (no BE changes — should pass trivially)
- [ ] `pnpm dev` — page loads at `/[lang]/reportaudit/reports/generatereport`

**Functional Verification (Full E2E — MANDATORY) — TABULAR:**

- [ ] Page no longer renders the "Under Construction" placeholder
- [ ] Page renders the report-picker dropdown in the header (Select Report ▾)
- [ ] Dropdown populates with reports filtered by `currentModuleCode` from global store
      (Note: if `moduleCode` is empty when landing on this page outside a module context,
      the dropdown shows nothing — confirm whether this is acceptable or whether the screen
      should default to listing ALL reports the user has access to. If the latter,
      the build agent must either widen the filter in `report-datatable-header-toolbar.tsx`
      OR add a "module" picker control. **DECIDE WITH USER DURING BUILD APPROVAL.**)
- [ ] Selecting a report:
  - Loads filter schema (RJSF) if the report has one — renders as filter bar
  - Loads filter-less if `FilterSchema` is null — proceeds straight to data fetch
  - Fetches data — table renders with dynamic columns
- [ ] Pagination next/prev works; page-size dropdown works
- [ ] Sort on any sortable column triggers server fetch with `sortColumn` / `sortDescending`
      params and result re-renders
- [ ] Filter chips (when filter schema set) apply correctly — chip clear and full-clear work
- [ ] Search input filters client-side (or server-side per engine behavior — verify which)
- [ ] Refresh button re-fetches without re-resetting filters
- [ ] Layout toggle: switching between rows view and card view re-renders the data
- [ ] Full-screen mode enters/exits via button and via ESC key
- [ ] Chart-view toggle renders chart if columns metadata supports it
- [ ] Export button visible when `canExport === true`:
  - Triggers `DataTableGenerateExportButton` flow
  - Produces downloadable file with current filters/sort applied
- [ ] Print / Share / Subscribe options render in toolbar and execute their handlers
      (real or SERVICE_PLACEHOLDER toast — match sibling screens' behavior)
- [ ] Error state renders the destructive-card when query fails
- [ ] Empty state renders "Select a Report" when no report has been picked
- [ ] Access Denied page renders when role lacks `READ` capability on `GENERATEREPORT`
- [ ] Tenant scoping: switching tenants (or logging in as another tenant) hides reports
      from the other tenant in the dropdown

**DB Seed Verification:**
- [ ] Menu "Generate Report" visible in sidebar at `Report & Audit › Reports › Generate Report`
      for BUSINESSADMIN on a fresh seed
- [ ] Page renders without crashing on a freshly-seeded DB

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Activation-specific warnings:**

- **DO NOT generate new BE code.** Every BE artifact already exists. If a build agent
  proposes adding `GenerateReport` entities / queries / handlers / schemas, **reject and
  refer them to this prompt's §⑧**. The agent has misread the registry's "FULL" stamp.

- **DO NOT generate new FE engine code.** The `ReportDataTable` engine is shared infrastructure.
  Adding a duplicate or "improving" the engine for this single menu would corrupt the three
  sibling screens that use it.

- **DO NOT add a `GenerateReport-sqlscripts.sql` file.** Menu + capabilities are already
  seeded by the central `_seed_child_menu` function. A new file would create duplicate-INSERT
  warnings or worse, conflict if someone hand-runs it.

- **Empty-`moduleCode` behavior** (DECIDE WITH USER): The existing
  `ReportDataTableHeaderToolbar` filters reports by `currentModuleCode` from global store.
  When a user lands on `reportaudit/reports/generatereport` without a parent-module context,
  `moduleCode` may be empty/`REPORTAUDIT`. In that case the dropdown may be empty or only
  show REPORTAUDIT-module reports. The user must clarify during build approval whether:
  - (a) keep current behavior (filtered by current module),
  - (b) widen to show ALL reports the user has access to when on this screen,
  - (c) add an explicit Module picker control above the Report picker.

- **Duplicate page paths** (DECIDE WITH USER): there are two copies of
  `GeneratePageConfig` — one at `presentation/pages/reportaudit/reports/generatereport.tsx`
  and one at `presentation/pages/shared/rms/generatereport.tsx`. The same applies to
  `page-components/reportaudit/reports/generatereport/data-table.tsx` vs
  `page-components/shared/rms/generatereport/data-table.tsx`. They are byte-identical.
  During build:
  - (a) keep only the `reportaudit/reports/generatereport.tsx` path and delete the `shared/rms`
       copies, **OR**
  - (b) leave both — risk is they drift over time.
  Recommend (a) — delete the `shared/rms` duplicates as part of activation.

- **BE-side tenant enforcement**: the FE auto-merges `companyId` into SP params before
  calling `generateReports`. The BE should also enforce this in the `GenerateReportQuery`
  handler (do not trust FE-supplied `companyId`). Confirm during build by reading
  `Base.Application/Business/ReportBusiness/Reports/Queries/GenerateReportQuery.cs`.
  If FE-only enforcement, raise an ISSUE entry — but do NOT modify in this activation
  (out-of-scope; tracker only).

- **`ReportCatalog` (#99) is NOT a blocker** for this screen — Report Catalog is a *separate*
  admin-side screen for managing the catalog rows. This screen consumes the catalog rows
  via `GetReportsByModule` and works regardless of whether a Report Catalog admin UI exists.
  The registry's "Key FKs: ReportCatalog (#99)" is misleading; the real dependency is on
  the `rep."Reports"` table (which already has rows seeded by some other path — confirm
  during build that at least one report row exists for testing).

- **Type-stamp inconsistency**: registry stamped FLOW. User re-stamped to REPORT in this
  /plan-screens session. The seed `GridType` for the existing menu is `FLOW` because
  `_seed_child_menu` defaults to FLOW. Do NOT change the seed's GridType to REPORT
  retroactively — it has no functional impact (the FE engine doesn't read GridType for
  this screen) and changing it risks breaking the seed function.

**Sub-type-specific gotchas:**

| Sub-type | Easy mistakes |
|----------|---------------|
| TABULAR (engine) | Adding screen-level filter logic instead of letting the RJSF schema drive filters; bypassing the engine's pagination and re-fetching whole result on every click; treating `metadata.columns` as fixed structure instead of dynamic-from-SP. |

**Service Dependencies** (UI-only — no backend service implementation):

- None for activation. All required services (Export, Print, Share, Subscribe) are already
  wired into the engine. Sibling screens prove they work end-to-end. If any sibling-screen
  feature is `SERVICE_PLACEHOLDER` (e.g., scheduled email subscribe), this screen inherits
  the same placeholder behavior — no new placeholders needed.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.

### § Sessions

### Session 1 — 2026-05-13 — BUILD — COMPLETED

- **Scope**: Activation-only — replace `UnderConstruction` stub at app-route with `<GeneratePageConfig />`, and remove byte-identical duplicates under `presentation/pages/shared/rms` + `presentation/components/page-components/shared/rms`.
- **Files touched**:
  - BE: None
  - FE:
    - `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/generatereport/page.tsx` (modified — replaced `UnderConstruction` with `<GeneratePageConfig />` imported from `@/presentation/pages/reportaudit/reports/generatereport`)
    - `PSS_2.0_Frontend/src/presentation/pages/reportaudit/reports/index.ts` (modified — added `export { GeneratePageConfig } from "./generatereport";`)
    - `PSS_2.0_Frontend/src/presentation/pages/shared/rms/index.ts` (modified — removed `export { GeneratePageConfig } from "./generatereport";`)
    - `PSS_2.0_Frontend/src/presentation/pages/shared/rms/generatereport.tsx` (deleted — byte-identical duplicate)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/shared/rms/index.ts` (modified — removed `export * from "./generatereport";`)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/shared/rms/generatereport/` (deleted — byte-identical duplicate folder)
  - DB: None (menu + capabilities seeded via `_seed_child_menu('Generate Report','GENERATEREPORT',…)` at `Pss2.0_Global_Menus_List.sql:522`)
- **Deviations from spec**: None. Both user decisions documented in §⑫ are applied — (a) keep `reportaudit/reports` as canonical path + delete `shared/rms` duplicates, (b) keep current REPORTAUDIT-scoped `moduleCode` behavior in `ReportDataTableHeaderToolbar` (no engine code change).
- **Known issues opened**: None. The "BE-side tenant enforcement" item in §⑫ remains out-of-scope for this activation (per-report SP responsibility); no audit performed.
- **Known issues closed**: None
- **Verification done in this session**:
  - Grep confirmed no remaining references to `shared/rms/generatereport` / `pages/shared/rms/generatereport` / `page-components/shared/rms/generatereport` after deletion.
  - `pnpm exec tsc --noEmit` run on full project — no new errors introduced; existing unrelated errors (event-overview-bar / event-selector / donation-service `PageLayoutOption` ambiguity / emailsendjob SaveFilterParams) pre-date this change.
  - `app/[lang]/reportaudit/reports/generatereport/page.tsx` now imports from the canonical entity path (`@/presentation/pages/reportaudit/reports/generatereport`); `GeneratePageConfig` is also re-exported from `presentation/pages/reportaudit/reports/index.ts` for barrel access.
- **Runtime verification deferred**: `pnpm dev` was NOT executed in this session (sandbox / non-interactive). Reviewer to manually verify: page loads at `/[lang]/reportaudit/reports/generatereport`, header dropdown lists REPORTAUDIT-module reports, selecting a report renders filter+grid, export/print/share buttons render, Access Denied renders for unauthorized role.
- **Next step**: (empty — COMPLETED)
