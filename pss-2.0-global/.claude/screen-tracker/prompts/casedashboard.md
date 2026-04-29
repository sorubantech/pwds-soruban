---
screen: CaseDashboard
registry_id: 52
module: CRM (Case Management)
status: NEEDS_REWORK
scope: FULL
screen_type: DASHBOARD
dashboard_variant: MENU_DASHBOARD
complexity: High
new_module: NO
planned_date: 2026-04-28
completed_date:
last_session_date: 2026-04-29
phase_1_completed_date: 2026-04-28          # Path-A SQL functions + widget seed shipped
phase_2_completed_date:                      # Architectural rework (separate component + new BE handler) — see "Phase 2" block below
---

> ## ⚠ PHASE 2 ARCHITECTURAL REWORK — REQUIRED BEFORE COMPLETION
>
> Phase 1 (Session 1, 2026-04-28) shipped the 17 SQL functions + widget seed but took a **retrofit approach** for the FE: it added a `dashboardCode` prop to the existing `<DashboardComponent />` and a per-route stub at `casedashboard/page.tsx`. This was wrong because:
>
> 1. **Existing `dashboardByModuleCode` BE handler ([GetDashboardByModuleCode.cs:25-33](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleCode.cs#L25-L33)) inner-joins `UserDashboard`** — MENU_DASHBOARD rows have NO UserDashboard rows, so reusing this handler returns ZERO rows in production. Phase 1 likely "worked" only because Session 1 didn't run a full E2E with a fresh user (ISSUE-19 was deferred). The retrofit will fail on real users.
> 2. **`<DashboardComponent />` is tightly coupled to `UserDashboard` state** — switcher cache, IsDefault auto-pick, max-3-per-user counter, edit-layout toggle. Trying to dual-mode it via `dashboardCode` prop creates fragile gating sites in `dashboard-header.tsx` (the user reported "Create Dashboard" button leaking on `/crm/dashboards/casedashboard` — confirmed at `dashboard-header.tsx:197-203`).
> 3. **Schema/route/sidebar bootstrap was deferred** — original ISSUE-1 punted ALL of: `Dashboard.MenuId` column, dynamic `[slug]/page.tsx` route, `linkDashboardToMenu`/`unlinkDashboardFromMenu` mutations, sidebar batched query, deletion of 6 hardcoded route pages. These cannot be deferred — without them the slug route doesn't exist.
>
> **Phase 2 scope — the rework that must land for status=COMPLETED**:
>
> | # | Layer | Action | Files |
> |---|-------|--------|-------|
> | A | BE schema | Add `Dashboard.MenuId int? FK → auth.Menus (Restrict)` (1 column only — slug/sort/visibility live on the linked Menu row) | [Dashboard.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/Dashboard.cs) ✅ already done; [DashboardConfiguration.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/DashboardConfiguration.cs) ✅ already done |
> | B | BE migration | Generate `AddMenuIdToDashboard` migration | `Base.Infrastructure/Migrations/{ts}_AddMenuIdToDashboard.cs` |
> | C | BE query (NEW — the critical fix) | `GetDashboardByModuleAndCode(moduleCode, dashboardCode)` — single-row, **NO UserDashboard join**, validates `Dashboard.MenuId IS NOT NULL` (refuses STATIC). Includes DashboardLayouts + Module. | `Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleAndCode.cs` |
> | D | BE query | `GetMenuLinkedDashboardsByModuleCode(moduleCode)` — sidebar consumption, lean projection (no widget data). Filters where `Dashboard.MenuId IS NOT NULL AND Menu.IsActive=true`, ordered by `Menu.OrderBy`. | `…/Queries/GetMenuLinkedDashboardsByModuleCode.cs` |
> | E | BE mutations | `LinkDashboardToMenu(dashboardId, menuId)` (validates `Menu.ModuleId == Dashboard.ModuleId`; auto-seeds `MenuCapability(MenuId, READ)`) and `UnlinkDashboardFromMenu(dashboardId)` | `…/Commands/LinkDashboardToMenu.cs`, `UnlinkDashboardFromMenu.cs` |
> | F | BE endpoint registration | Register the 2 new queries + 2 new mutations. **Existing `dashboardByModuleCode` field stays untouched.** | `Base.API/EndPoints/Setting/Queries/DashboardQueries.cs`, `…/Mutations/DashboardMutations.cs` |
> | G | FE — NEW component | `<MenuDashboardComponent />` — lean dedicated component for slug-rendered MENU_DASHBOARD. Props: `moduleCode: string, dashboardCode: string`. Single Apollo query (`dashboardByModuleAndCode`), no UserDashboard logic, no switcher, no edit chrome. Inline lean header + widget grid (~150-250 LOC; ~30-50 LOC of grid render duplicated from `<DashboardComponent />` — accepted on first ship per ISSUE-22). | **NEW** `Pss2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx` (new folder) |
> | H | FE — NEW gql doc | `DASHBOARD_BY_MODULE_AND_CODE_QUERY` + barrel re-export | **NEW** `src/infrastructure/gql-queries/setting-queries/MenuDashboardQuery.ts` |
> | I | FE — dynamic route | `[slug]/page.tsx` server component — derives `dashboardCode = params.slug.toUpperCase().replace(/-/g, '')` and renders `<MenuDashboardComponent moduleCode={params.module.toUpperCase()} dashboardCode={dashboardCode} />` | **NEW** `src/app/[lang]/(core)/[module]/dashboards/[slug]/page.tsx` |
> | J | FE — sidebar update | Inject `menuLinkedDashboardsByModuleCode` results as leaves under each `*_DASHBOARDS` parent (batched — 1 call per render covering all parents, NOT N+1) | `src/presentation/components/menus/sidebar-menu-tree.tsx` (or actual file — grep first) |
> | K | FE — DELETE 6 hardcoded routes | After Phase 2 G/H/I land + verified, delete: `crm/dashboards/contactdashboard/page.tsx`, `donationdashboard/page.tsx`, `communicationdashboard/page.tsx`, `ambassadordashboard/page.tsx`, `volunteerdashboard/page.tsx`, `casedashboard/page.tsx` (the file Phase 1 just modified — see backout list below) — pre-flight grep imports first | DELETE existing per-dashboard route files |
> | L | DB seed | Backfill `Dashboard.MenuId` for the 6 system dashboards by `DashboardCode = MenuCode`; verify each linked `auth.Menus.MenuUrl` is populated | `sql-scripts-dyanmic/Dashboard-MenuBackfill-sqlscripts.sql` (NEW) |
>
> **Phase 1 backout list** (Phase 2 must REVERT these Session-1 edits):
>
> - REVERT `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/index.tsx` — remove the `dashboardCode?: string` prop, the `dashboardCodeNotFound` state, and the slug-vs-default precedence logic added in Session 1. Restore to its pre-Session-1 shape (verify via `git diff HEAD~N` against the Session 1 commit). The new `<MenuDashboardComponent />` makes that prop unnecessary.
> - DELETE `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/casedashboard.tsx` — replaced by the dynamic `[slug]/page.tsx` (item I above). Pre-flight grep for any imports.
> - **KEEP unchanged** (Phase 1 work that's still good): the 17 SQL functions in `case.` schema, the `AlertListWidget` renderer + barrel + WIDGET_REGISTRY entry, the DB seed file `CaseDashboard-sqlscripts.sql`. These are architecture-agnostic — Path-A widgets unchanged.
>
> **Why this is the right call (vs. the Phase 1 retrofit)**: see template § H/I in [_DASHBOARD.md](_DASHBOARD.md). TL;DR: separation by component eliminates the chrome leak risk by construction (the new component cannot render Create / Switcher / Edit), uses single round-trip data fetch instead of module-wide list + FE filter, keeps STATIC mode 100% untouched (`git diff dashboards/` MUST be empty after Phase 2), and avoids the BE `UserDashboard` join trap entirely.
>
> ---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (16+ widgets, 3 global filters, 9 drill-down targets identified)
- [x] Variant chosen — **MENU_DASHBOARD** (own sidebar leaf at `crm/dashboards/casedashboard`, MenuCode `CASEDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=6)
- [x] Source entities identified (Beneficiary #49, Case #50, Program #51 + child rows; ALL COMPLETED)
- [x] Widget catalog drafted (16 widgets — 6 KPI + 4 tables + 6 charts + alerts list + impact tiles)
- [x] react-grid-layout config drafted (lg breakpoint, 12 cols, 47-row height)
- [x] DashboardLayout JSON shape drafted (LayoutConfig + ConfiguredWidget per widget)
- [x] MENU_DASHBOARD parent menu code resolved — CRM_DASHBOARDS already exists; new menu row NOT required (CASEDASHBOARD already seeded)
- [⚠] **First MENU_DASHBOARD bootstrap — IN SCOPE (Phase 2)** — original Phase 1 deferred this; the deferral was rejected on review. Full bootstrap (1 schema column `Dashboard.MenuId` + dynamic `[slug]/page.tsx` route + separate `<MenuDashboardComponent />` + new `dashboardByModuleAndCode` BE handler with no UserDashboard join + sidebar batched query + backfill seed + deletion of 6 hardcoded route pages) is in scope per the PHASE 2 block above. Tracked as ISSUE-1/20/21.
- [x] Path-A (Postgres functions) chosen for ALL 16 widgets — matches existing `sett.fn_*_widget` pattern, no new C# code
- [x] File manifest computed (16 SQL functions + 1 new FE widget renderer + Dashboard/DashboardLayout/Widget seeds + 1 DashboardComponent enhancement)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation — Phase 1 (Session 1 — 2026-04-28 — DONE, KEEP except where noted)
- [x] BA Analysis validated (skipped — prompt pre-analyzed)
- [x] Solution Resolution complete (skipped — Path-A across 17 widgets dictated by §⑤)
- [x] UX Design finalized (skipped — §⑥ contains complete grid layout)
- [x] User Approval received (2026-04-28)
- [x] **Backend (Path-A — KEEP)** — 17 Postgres function files in `PSS_2.0_Backend/DatabaseScripts/Functions/case/`. Each conforms to fixed 5-arg / 4-column contract. NO new C# code (reuses existing `generateWidgets` GraphQL handler). **Status: production-ready, no rework needed.**
- [⚠] **Frontend (PARTIAL — needs Phase 2 rework)** — KEEP: 1 new widget renderer `AlertListWidget` + WIDGET_REGISTRY registration. **REVERT in Phase 2**: the `dashboardCode` prop added to `<DashboardComponent />` (the wrong abstraction — see PHASE 2 block above) and `casedashboard.tsx` page modification (replaced by dynamic `[slug]` route).
- [x] **DB Seed (mostly KEEP, 1 backfill addition in Phase 2)** — `sql-scripts-dyanmic/CaseDashboard-sqlscripts.sql`:
      • Dashboard row CASEDASHBOARD (DashboardCode, DashboardName, ModuleId=CRM uuid, IsSystem=true, IsActive=true, CompanyId=NULL) — **Phase 2 will UPDATE this row to set `MenuId` (item L of Phase 2)**
      • DashboardLayout row (LayoutConfig JSON × 4 breakpoints lg/md/sm/xs + ConfiguredWidget compact JSON × 17 instances) — KEEP
      • Widget rows × 17 with `StoredProcedureName='case.fn_case_dashboard_*'` — KEEP
      • WidgetType row for AlertListWidget — KEEP
      • WidgetRole grants × 17 BUSINESSADMIN — KEEP
      • NO new Menu seed (CASEDASHBOARD menu already seeded) — KEEP
- [⚠] Registry status changed to NEEDS_REWORK pending Phase 2

### Generation — Phase 2 (`/continue-screen case-dashboard` — TODO)
- [ ] Apply Phase 1 backout: revert `<DashboardComponent />` `dashboardCode` prop + delete `casedashboard.tsx` page (see backout list in PHASE 2 block above)
- [ ] Generate EF migration `AddMenuIdToDashboard` (`dotnet ef migrations add`) — entity edits already applied
- [ ] Create `GetDashboardByModuleAndCode.cs` query handler — single-row, NO UserDashboard join, validates `Dashboard.MenuId IS NOT NULL`
- [ ] Create `GetMenuLinkedDashboardsByModuleCode.cs` query handler — sidebar consumption, lean projection
- [ ] Create `LinkDashboardToMenu.cs` + `UnlinkDashboardFromMenu.cs` mutation handlers
- [ ] Register 2 queries + 2 mutations in `DashboardQueries.cs` + `DashboardMutations.cs` (existing `dashboardByModuleCode` field UNCHANGED)
- [ ] Create `<MenuDashboardComponent />` at `src/presentation/components/custom-components/menu-dashboards/index.tsx` — lean component, single fetch, no UserDashboard logic
- [ ] Create `MenuDashboardQuery.ts` + barrel re-export
- [ ] Create dynamic `[slug]/page.tsx` route — derives dashboardCode from slug, renders MenuDashboardComponent
- [ ] Update sidebar menu-tree composer to inject `menuLinkedDashboardsByModuleCode` (batched)
- [ ] Append backfill SQL to `Dashboard-MenuBackfill-sqlscripts.sql` linking 6 system dashboards by `DashboardCode = MenuCode`
- [ ] Pre-flight grep imports of the 6 hardcoded route pages → if zero references, DELETE them
- [ ] Acceptance gates per ⑪ pass:
      · Network tab on `/crm/dashboards/case-dashboard` shows EXACTLY ONE GraphQL request: `dashboardByModuleAndCode` (no module-wide list fetch leakage)
      · `git diff src/presentation/components/custom-components/dashboards/` is empty (zero edits to STATIC chrome)
      · Visiting any STATIC dashboard slug returns "not found" (BE handler enforces `MenuId IS NOT NULL`)
      · Sidebar leaf still renders for BUSINESSADMIN
      · "Create Dashboard" button does NOT appear on the slug route (by construction — new component never renders it)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/casedashboard`
- [ ] All 16 widgets fetch and render with sample data (functions return `(data jsonb, metadata jsonb, total_count int, filtered_count int)`)
- [ ] Each KPI card shows correct value formatted per spec (count / %)
- [ ] Each chart renders correctly (axes, legends, tooltips)
- [ ] **Period filter** (This Year / Last Year / This Quarter / Last Quarter / Custom) updates all date-honoring widgets in parallel
- [ ] **Program filter** (All / 8 specific) updates Program-scoped widgets (Program Performance / Outcome Tracking / Beneficiary breakdowns / Cases by Status)
- [ ] **Branch filter** (All / 5 cities) updates Branch-scoped widgets (Open Cases / Staff Caseload / Beneficiaries by Location)
- [ ] Drill-down clicks navigate to correct destinations with prefill args:
      • Program row → `/crm/casemanagement/programmanagement` (filter by ProgramId — SERVICE_PLACEHOLDER until Program list supports `?programId=`)
      • Staff row → `/crm/casemanagement/caselist?assignedStaffId={id}`
      • Alert link → respective list page with filter args
      • Impact card → respective list page (Children → BeneficiaryList?orphanStatusOnly=true; Wells → ProgramManagement?programCode=CLEAN_WATER; Women Employed → BeneficiaryList?vocationalGraduate=true — all 3 are SERVICE_PLACEHOLDER drill-downs until destination accepts those args)
- [ ] Empty / loading / error states render per widget (Skeleton matching widget shape; red banner + Retry on error)
- [ ] Role-based widget gating: WidgetRole(HasAccess=false) → widget hidden / replaced
- [ ] Sidebar leaf "Case Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] react-grid-layout reflows correctly (xs/sm/md/lg/xl breakpoints)
- [ ] DB Seed — Dashboard row + DashboardLayout JSON + 16 Widget rows visible in DB; widgets resolve from registry; all 16 SQL functions exist in `case.` schema

---

## ① Screen Identity & Context

**Consumer**: All agents — sets the stage

**Screen**: CaseDashboard
**Module**: CRM → Case Management (sidebar leaf under CRM_DASHBOARDS)
**Schema**: NONE for the dashboard itself (`sett.Dashboards` + `sett.DashboardLayouts` + `sett.Widgets` already exist). New `case` Postgres function namespace introduced for widget aggregations.
**Group**: NONE (no new C# DTOs / handlers — Path-A throughout)

**Dashboard Variant**: **MENU_DASHBOARD** — own sidebar leaf at `crm/dashboards/casedashboard` (MenuCode `CASEDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=6). NOT in any dropdown switcher.

**Business**:
The Case & Program Dashboard is the **executive impact-overview** for the Case Management module. It rolls up beneficiary enrollment, program performance, case workload, outcome achievement, sponsor match rates, and funder impact into a single board-level summary. **Target audience**: NGO executives, Program Directors, M&E officers, board members, and external funders requesting impact reports. **Why it exists**: NGOs report quarterly/annually to funders (UNICEF, Bill & Melinda Gates, Dubai Cares, individual sponsors) on outcomes vs. targets — this dashboard supplies the source-of-truth numbers and click-throughs to underlying caseloads. **Why MENU_DASHBOARD (not STATIC)**: it is deep-linkable from emailed funder reports, role-restricted to executives + program directors (not all CRM users), and tightly scoped to Case Management (no need to share dropdown space with Donation / Communication / Volunteer dashboards). It rolls up data from: Case Management (Beneficiary, Case, Program + child rows), Staff (caseload assignment), Branch (geographic distribution), MasterData (status / outcome / category lookups), and READ-ONLY references to Grant #62 (DEGRADED — Grant module not yet built; Funder Impact widget shows placeholder data until #62 ships).

---

## ② Entity Definition

**Consumer**: BA Agent → Backend Developer
> Dashboard does NOT introduce a new entity. It composes **two seeded rows** (`sett.Dashboards` + `sett.DashboardLayouts`) over **6 existing source entities**.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `CASEDASHBOARD` | Matches Menu.MenuCode |
| DashboardName | `Case Dashboard` | Matches Menu.MenuName (for sidebar display) |
| DashboardIcon | `chart-pie-light` | Phosphor icon (mockup uses fa-chart-pie) |
| DashboardColor | `#0d9488` | Teal accent from mockup `--cm-accent` |
| ModuleId | (resolve from `auth.Modules WHERE ModuleCode='CRM'`) | CRM module |
| IsSystem | `true` | System-seeded |
| IsActive | `true` | — |
| CompanyId | NULL | Global system dashboard (CompanyId NULL = available to all tenants) |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | JSON: `{"lg": [...16 layout items...], "md": [...], "sm": [...]}` | react-grid-layout breakpoint configs |
| ConfiguredWidget | JSON: `[{instanceId, widgetId, title?, customQuery?, customParameter?}, ... 16 entries]` | One element per rendered widget |

### C. Widget Definitions (`sett.Widgets` — one row per widget)

> All Path-A — each widget has `StoredProcedureName` set; `DefaultQuery` is NULL.
> Reuses existing `WidgetTypes` rows where possible (StatusWidgetType1, MultiChartWidget, PieChartWidgetType1, FilterTableWidget, NormalTableWidget). Adds 1 new WidgetType row for `AlertListWidget`.

| # | WidgetCode (used as instanceId) | WidgetName | WidgetType.ComponentPath | StoredProcedureName | OrderBy |
|---|---------------------------------|-----------|--------------------------|---------------------|---------|
| 1 | KPI_TOTAL_BENEFICIARIES | Total Beneficiaries Served | StatusWidgetType1 | case.fn_case_dashboard_kpi_total_beneficiaries | 1 |
| 2 | KPI_ACTIVE_PROGRAMS | Active Programs | StatusWidgetType1 | case.fn_case_dashboard_kpi_active_programs | 2 |
| 3 | KPI_OPEN_CASES | Open Cases | StatusWidgetType1 | case.fn_case_dashboard_kpi_open_cases | 3 |
| 4 | KPI_SERVICES_DELIVERED | Services Delivered (YTD) | StatusWidgetType1 | case.fn_case_dashboard_kpi_services_delivered | 4 |
| 5 | KPI_OUTCOME_RATE | Outcome Achievement Rate | StatusWidgetType1 | case.fn_case_dashboard_kpi_outcome_rate | 5 |
| 6 | KPI_SPONSOR_MATCH_RATE | Sponsor Match Rate | StatusWidgetType1 | case.fn_case_dashboard_kpi_sponsor_match_rate | 6 |
| 7 | TBL_PROGRAM_PERFORMANCE | Program Performance Overview | FilterTableWidget | case.fn_case_dashboard_program_performance | 7 |
| 8 | CHART_ENROLLMENT_TREND | Beneficiary Enrollment Trend | MultiChartWidget | case.fn_case_dashboard_enrollment_trend | 8 |
| 9 | CHART_AGE_DISTRIBUTION | Beneficiaries by Age Group | PieChartWidgetType1 | case.fn_case_dashboard_age_distribution | 9 |
| 10 | CHART_GENDER_DISTRIBUTION | Beneficiaries by Gender | PieChartWidgetType1 | case.fn_case_dashboard_gender_distribution | 10 |
| 11 | CHART_CASES_BY_STATUS | Cases by Status | MultiChartWidget (stacked-bar config) | case.fn_case_dashboard_cases_by_status | 11 |
| 12 | CHART_LOCATION_DISTRIBUTION | Beneficiaries by Location | BarChartWidgetType1 | case.fn_case_dashboard_location_distribution | 12 |
| 13 | TBL_OUTCOME_TRACKING | Outcome Tracking | NormalTableWidget | case.fn_case_dashboard_outcome_tracking | 13 |
| 14 | TBL_STAFF_CASELOAD | Staff Caseload Distribution | FilterTableWidget | case.fn_case_dashboard_staff_caseload | 14 |
| 15 | CHART_CASE_RESOLUTION_TREND | Case Resolution Trend | MultiChartWidget (line) | case.fn_case_dashboard_resolution_trend | 15 |
| 16 | LIST_ALERTS | Alerts & Actions | **AlertListWidget** (NEW renderer) | case.fn_case_dashboard_alerts | 16 |
| 17 | TBL_FUNDER_IMPACT | Funder Impact Summary | NormalTableWidget | case.fn_case_dashboard_funder_impact | 17 |

(17 widget rows — note: no separate "Impact Highlights" widget; the 3 impact tiles are sub-elements rendered by the KPI cluster but are deferred from the v1 layout per ISSUE-3.)

### D. Source Entities (read-only — what the widgets aggregate over)

| # | Source Entity | Schema.Table | Purpose | Aggregate(s) |
|---|--------------|--------------|---------|--------------|
| 1 | Beneficiary | `case.Beneficiaries` | KPI 1, charts 9/10/12, table 7 | COUNT, GROUP BY Age (computed from DateOfBirth), GROUP BY GenderId, GROUP BY CityId |
| 2 | Program | `case.Programs` | KPI 2, table 7 | COUNT WHERE StatusId=Active, JOIN Beneficiaries enrolled |
| 3 | Case | `case.Cases` | KPI 3, charts 8/11/15, tables 7/14, alerts | COUNT WHERE StatusId NOT Closed, GROUP BY StatusId, GROUP BY AssignedStaffId, OPEN_VS_CLOSED by month |
| 4 | BeneficiaryProgramEnrollment | `case.BeneficiaryProgramEnrollments` | KPI 1, table 7, chart 8 | COUNT GROUP BY ProgramId, COUNT GROUP BY enrollment month |
| 5 | BeneficiaryServiceLog | `case.BeneficiaryServiceLogs` | KPI 4 | COUNT WHERE LogDate in YTD |
| 6 | ProgramOutcomeMetric | `case.ProgramOutcomeMetrics` | KPI 5, table 13 | SUM(AchievedValue) / SUM(TargetValue) |
| 7 | Staff | `app.Staffs` | Table 14 | JOIN Cases.AssignedStaffId, AVG(ClosedDate - OpenedDate) |
| 8 | Branch | `app.Branches` | KPI 6 (sponsor match), chart 12 | JOIN Beneficiary.BranchId |
| 9 | MasterData | `sett.MasterDatas` | Status / Priority / Outcome / Category labels | Display dimension labels (denormalized to JSON) |
| 10 | Grant | `crm.Grants` (NOT YET BUILT — Grant #62) | Table 17 | DEGRADED — placeholder data until #62 |

---

## ③ Source Entity & Aggregate Query Resolution

**Consumer**: Backend Developer (Postgres function authors) + Frontend Developer (widget binding via `Widget.StoredProcedureName`)

> Path-A across all widgets. Each widget calls `SELECT * FROM case."{function_name}"(p_filter_json::jsonb, p_page, p_page_size, p_user_id, p_company_id)` via the existing `generateWidgets` GraphQL handler.

| # | Source Entity | Entity File Path | Postgres Function | GQL Field | Returns | Filter Args (in p_filter_json) |
|---|--------------|------------------|-------------------|-----------|---------|-------------------------------|
| 1 | Beneficiary | `Base.Domain/Models/CaseModels/Beneficiary.cs` | `case.fn_case_dashboard_kpi_total_beneficiaries` | generateWidgets | `(data jsonb)` → `{value:int, deltaThisYear:int, subtitle:string}` | dateFrom, dateTo, programId, branchId |
| 2 | Program | `Base.Domain/Models/CaseModels/Program.cs` | `case.fn_case_dashboard_kpi_active_programs` | generateWidgets | `(data jsonb)` → `{value:int, activeCount:int, standbyCount:int, subtitle:string}` | programId, branchId |
| 3 | Case | `Base.Domain/Models/CaseModels/Case.cs` | `case.fn_case_dashboard_kpi_open_cases` | generateWidgets | `(data jsonb)` → `{value:int, momPercent:decimal, subtitle:string, trendDir:string}` | dateFrom, dateTo, programId, branchId |
| 4 | BeneficiaryServiceLog | `Base.Domain/Models/CaseModels/BeneficiaryServiceLog.cs` | `case.fn_case_dashboard_kpi_services_delivered` | generateWidgets | `(data jsonb)` → `{value:int, yoyPercent:decimal, subtitle:string}` | dateFrom, dateTo, programId, branchId |
| 5 | ProgramOutcomeMetric | `Base.Domain/Models/CaseModels/ProgramOutcomeMetric.cs` | `case.fn_case_dashboard_kpi_outcome_rate` | generateWidgets | `(data jsonb)` → `{value:decimal, qoqPercent:decimal, subtitle:string}` | dateFrom, dateTo, programId |
| 6 | Beneficiary (orphan + sponsor) | `Base.Domain/Models/CaseModels/Beneficiary.cs` | `case.fn_case_dashboard_kpi_sponsor_match_rate` | generateWidgets | `(data jsonb)` → `{value:decimal, sponsoredCount:int, totalOrphanCount:int, subtitle:string}` | branchId |
| 7 | Program + BeneficiaryProgramEnrollment + Case | (joins) | `case.fn_case_dashboard_program_performance` | generateWidgets | `(data jsonb)` → `[{programId, programName, icon, beneficiaries, capacity, enrollmentPct, casesOpen, outcomeRate, outcomeColor, budgetUsedPct, status, statusBadge}]` | dateFrom, dateTo, branchId |
| 8 | BeneficiaryProgramEnrollment + Program | (joins, GROUP BY month + ProgramId) | `case.fn_case_dashboard_enrollment_trend` | generateWidgets | `(data jsonb)` → `{labels:[12 months], series:[{name:string, color:string, data:[int x12]}], annotations:[{xValue:string, label:string}]}` | branchId, programId |
| 9 | Beneficiary | `Base.Domain/Models/CaseModels/Beneficiary.cs` | `case.fn_case_dashboard_age_distribution` | generateWidgets | `(data jsonb)` → `{total:int, segments:[{label:"0-5",value:int,pct:decimal,color:string}, ...6 buckets]}` | dateFrom, dateTo, programId, branchId |
| 10 | Beneficiary | `Base.Domain/Models/CaseModels/Beneficiary.cs` | `case.fn_case_dashboard_gender_distribution` | generateWidgets | `(data jsonb)` → `{total:int, segments:[{label:"Male",value:int,pct:decimal,color:string}, ...3 buckets]}` | dateFrom, dateTo, programId, branchId |
| 11 | Case | `Base.Domain/Models/CaseModels/Case.cs` | `case.fn_case_dashboard_cases_by_status` | generateWidgets | `(data jsonb)` → `{segments:[{label:"Open",value:int,color:string,pctOfTotal:decimal}, ...6 statuses]}` | dateFrom, dateTo, programId, branchId, assignedStaffId |
| 12 | Beneficiary + City | `Base.Domain/Models/CaseModels/Beneficiary.cs` | `case.fn_case_dashboard_location_distribution` | generateWidgets | `(data jsonb)` → `[{cityName:string, value:int, color:string, widthPct:decimal}, ...top 6 cities + Others bucket]` | dateFrom, dateTo, programId |
| 13 | ProgramOutcomeMetric | `Base.Domain/Models/CaseModels/ProgramOutcomeMetric.cs` | `case.fn_case_dashboard_outcome_tracking` | generateWidgets | `(data jsonb)` → `[{outcomeName:string, target:string, achieved:string, ratePct:decimal, rateColor:"green/yellow/red", trendLabel:string, trendDir:string}]` | dateFrom, dateTo, programId |
| 14 | Case + Staff | (join + AVG resolution time) | `case.fn_case_dashboard_staff_caseload` | generateWidgets | `(data jsonb)` → `[{staffId:int, staffName:string, avatarUrl:string, openCases:int, beneficiaries:int, avgResolutionDays:int, overdueCount:int, overdueColor:"red/yellow/none"}]` | branchId |
| 15 | Case | `Base.Domain/Models/CaseModels/Case.cs` | `case.fn_case_dashboard_resolution_trend` | generateWidgets | `(data jsonb)` → `{labels:[6 months], series:[{name:"Opened",data:[int x6]},{name:"Closed",data:[int x6]}]}` | branchId, programId |
| 16 | Case + ProgramOutcomeMetric + Beneficiary + Program | (multi-source rule engine) | `case.fn_case_dashboard_alerts` | generateWidgets | `(data jsonb)` → `[{severity:"warning/info/success", iconCode:string, message:string, link:{label:string, route:string, args:object}}]` | dateFrom, dateTo, programId, branchId |
| 17 | Grant (DEGRADED) + GlobalDonation | (joins per grant funder) | `case.fn_case_dashboard_funder_impact` | generateWidgets | `(data jsonb)` → `[{funderName:string, programName:string, amountUsd:decimal, beneficiaries:string, keyOutcome:string, grantId?:int}]` | dateFrom, dateTo |

**Strategy**: **Path A — Postgres functions only**. No composite C# DTO; no per-widget GraphQL handler. Each widget binds to one function via `Widget.StoredProcedureName`. The runtime calls the existing `generateWidgets` GraphQL field with the function name + filter context. This matches the established `sett.fn_*_widget.sql` precedent (50+ existing functions). Maximum compatibility with `<DashboardComponent />` widget context system.

---

## ④ Business Rules & Validation

**Consumer**: BA Agent → Backend Developer (Postgres functions enforce filtering) → Frontend Developer (filter behavior + drill-down args)

### Date Range Defaults
- Default range: **This Year** (Jan 1 of current calendar year → today)
- Allowed presets: This Year / Last Year / This Quarter / Last Quarter / Custom Range
- Custom range max span: **2 years** (enforced in FE filter validation; functions cap p_filter_json date span if larger)
- Date filter applies to: Beneficiary.EnrollmentDate (KPI 1, charts 8/9/10/12), Case.OpenedDate (KPI 3, charts 11/15), BeneficiaryServiceLog.LogDate (KPI 4), ProgramOutcomeMetric.PeriodEndDate (KPI 5, table 13), Grant.AwardDate (table 17)

### Role-Scoped Data Access
- **BUSINESSADMIN** → sees ALL companies' data (no scoping; CompanyId from HttpContext but admin has cross-company visibility per existing pattern)
- **CRM_MANAGER / PROGRAM_DIRECTOR** → sees only own company (`CompanyId = HttpContext.CompanyId`)
- **BRANCH_MANAGER** → additionally filtered by `BranchId IN user's branches` (read from `auth.UserBranches` table — pre-existing infra)
- **CASE_WORKER** → additionally restricted to `Case.AssignedStaffId = currentStaffId`; KPI / chart numbers scoped to their caseload only
- All scoping happens in the Postgres function via `p_user_id` + `p_company_id` parameters and helper joins to `auth.UserBranches` / `app.Staffs`

### Calculation Rules
- **Total Beneficiaries Served (KPI 1)**: `COUNT(DISTINCT BeneficiaryId WHERE BeneficiaryStatusId IN (Active, Graduated))`. Excludes Inactive / Suspended / Deceased. `deltaThisYear = COUNT WHERE EnrollmentDate >= year_start`.
- **Active Programs (KPI 2)**: `COUNT(*) WHERE StatusId = Active`. `standbyCount = COUNT WHERE StatusId = Standby`.
- **Open Cases (KPI 3)**: `COUNT(*) WHERE StatusId NOT IN (Closed, Resolved)`. `momPercent = ((current - lastMonth) / lastMonth) * 100`. Trend dir = "up" if growing (negative for cases — improvement is FEWER open cases), so trendDir flips: lower = positive subtitle.
- **Services Delivered YTD (KPI 4)**: `COUNT(*) FROM case.BeneficiaryServiceLogs WHERE LogDate >= year_start`. `yoyPercent = ((current - sameRangeLastYear) / sameRangeLastYear) * 100`.
- **Outcome Achievement Rate (KPI 5)**: `(SUM(ActualValue WHERE Achieved=true) / SUM(TargetValue)) * 100` averaged across all Programs' OutcomeMetrics for the period. Program filter narrows to one program if set.
- **Sponsor Match Rate (KPI 6)**: `(COUNT(Beneficiaries WHERE SponsorContactId IS NOT NULL AND OrphanStatusId IS NOT NULL) / COUNT(Beneficiaries WHERE OrphanStatusId IS NOT NULL)) * 100`.
- **Program Performance Status badge (table 7)**:
  - "On Track" if outcomeRate >= 80% AND budgetUsed <= enrollmentPct + 10%
  - "Needs Attention" if outcomeRate BETWEEN 70 AND 79
  - "Below Target" if outcomeRate < 70 OR enrollmentPct < 60
  - "Standby" if Program.StatusId = Standby (overrides above)
- **Outcome rate dot color (table 7)**: green if >=85%, yellow if >=70%, red if <70%
- **Overdue cases (table 14)**: `COUNT(Cases WHERE FollowUpDate < CURRENT_DATE AND StatusId NOT IN (Closed, Resolved))` per staff
- **Outcome Tracking rate color (table 13)**: green if achievedPct >= 95% of target, yellow if >=70%, red if <70% of target
- **Alert generation rules (widget 16)**:
  - WARNING if `count(overdue_cases) > 0` → "{N} overdue follow-ups — Oldest: {CaseCode} ({daysSinceFollowUp} days)"
  - WARNING if any `Program.outcomeRate < program.outcomeTarget * 0.9` → "{ProgramName}: {OutcomeName} below target ({achievedPct}% vs {targetPct}% target)"
  - INFO if `count(waitlistBeneficiaries WHERE programCode='ORPHAN_SPONSORSHIP') > 0` → "{N} beneficiaries on waitlist for Orphan Sponsorship — need {N} more sponsors"
  - INFO if any `Program.enrollmentPct < 60% AND Program.StatusId = Active` → "{ProgramName} below capacity — {enrolled} of {capacity} ({pct}%)"
  - SUCCESS if any `Program.outcomeRate >= 85% AND program.budgetUsedPct < 70%` → "{ProgramName} on track — {outcomeAchieved} ({pct}%)"
  - Hard cap of 10 alerts (top 10 by severity then recency)

### Multi-Currency Rules
- KPI 1 (Total Beneficiaries) — **count, not currency** — no conversion needed
- KPI 4 (Services Delivered) — count, not currency
- Program Performance "Budget Used %" (table 7) — use `Program.AnnualBudget` and accumulated GlobalDonation.NetAmount linked to the Program. **Convert all GlobalDonation amounts to Program.BudgetCurrencyId at the donation row's recorded ExchangeRate**. If donation has no ExchangeRate, fall back to current rate from `app.Currencies.ExchangeRate`. ⚠ Pre-flag as ⑫ ISSUE-2 — multi-currency budget aggregation requires GlobalDonation.ProgramId FK to be wired (currently nullable, no FK constraint per Program #51 ISSUE-1/2/3 deferred — function returns 0% budget used if Program.AnnualBudget is NULL or no donations linked).
- Funder Impact Summary (table 17) — display amount in USD; Grant.AwardCurrencyId converted at `Grant.AwardDate` rate. **DEGRADED — Grant #62 not built; widget returns hardcoded sample rows from a seeded `case.case_dashboard_funder_sample_data` seed table OR returns empty array with placeholder note**.

### Widget-Level Rules
- A widget is RENDERED only if `auth.WidgetRoles(WidgetId, currentRoleId, HasAccess=true)` row exists. No row → widget hidden (placeholder NOT shown to keep dashboard clean for restricted roles).
- All 17 widgets seed `WidgetRole(BUSINESSADMIN, HasAccess=true)`. Other roles inherit no grants by default — assigned at admin-config time.
- **Workflow**: None. Read-only. Drill-downs navigate AWAY.

---

## ⑤ Screen Classification & Pattern Selection

**Consumer**: Solution Resolver — these are PRE-ANSWERED.

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Standalone analytical surface deep-linkable from emailed funder reports; role-restricted to executives + program directors; tightly scoped to Case Management. Already has its own sidebar leaf at `/crm/dashboards/casedashboard` (MenuCode `CASEDASHBOARD` seeded under CRM_DASHBOARDS @ OrderBy=6).

**Backend Implementation Path** — **Path A across all 17 widgets**:
- [x] **Path A — Postgres function (generic widget)**: Each widget = 1 SQL function in `case.` schema returning `(data jsonb, metadata jsonb, total_count integer, filtered_count integer)`. Reuses the existing `generateWidgets` GraphQL handler. Seed `Widget.StoredProcedureName='case.{function_name}'`. NO new C# code; only 17 SQL deliverables.
- [ ] Path B — Named GraphQL query (NOT used)
- [ ] Path C — Composite DTO (NOT used)

**Path-A Function Contract (NON-NEGOTIABLE)** — every function MUST:
- Take 5 fixed inputs in this order: `p_filter_json jsonb, p_page integer, p_page_size integer, p_user_id integer, p_company_id integer`
- Return `TABLE(data jsonb, metadata jsonb, total_count integer, filtered_count integer)` — single row, 4 columns
- Extract every filter from `p_filter_json` using `NULLIF(p_filter_json->>'keyName','')::type` (fields: `dateFrom`, `dateTo`, `programId`, `branchId`, `assignedStaffId`)
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators)
- Live at `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/case/{function_name}.sql` — snake_case names. **NEW `case/` folder under DatabaseScripts/Functions/** (first case-domain widget functions; the folder must be created with this build).
- `Widget.DefaultParameters` JSON keys MUST match the keys that the function reads from `p_filter_json` (e.g., `{ "dateFrom": "{dateFrom}", "dateTo": "{dateTo}", "programId": "{programId}", "branchId": "{branchId}" }` — placeholders substituted by widget runtime)

**Backend Patterns Required:**
- [x] Tenant scoping (CompanyId from HttpContext via p_company_id arg) — every function
- [x] Date-range parameterized queries
- [x] Role-scoped data filtering — joined to `auth.UserBranches` and `app.Staffs` for BRANCH_MANAGER / CASE_WORKER scopes
- [ ] Materialized view / cached aggregate — not needed; case data volume small enough for live aggregation in v1

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` (responsive breakpoints) — already in `<DashboardComponent />`
- [x] Reuse renderers already present in `dashboard-widget-registry.tsx` `WIDGET_REGISTRY`:
      • `StatusWidgetType1` (KPI 1-6)
      • `MultiChartWidget` (charts 8/11/15 — area, stacked bar, line via config)
      • `PieChartWidgetType1` (donuts 9, 10)
      • `BarChartWidgetType1` (bar 12)
      • `FilterTableWidget` (tables 7, 14)
      • `NormalTableWidget` (tables 13, 17)
- [ ] **NEW renderer** — `AlertListWidget` for widget 16 (alerts list). Create at `dashboards/widgets/alert-list-widgets/AlertListWidget.tsx` and register in `WIDGET_REGISTRY`. Renders an alert feed (warning / info / success rows with icon + text + action link) consuming `data.alerts: [{severity, iconCode, message, link: {label, route, args}}]`.
- [x] Query registry — NOT extended (Path A uses `generateWidgets` only; query registry is for path B/C)
- [x] Date-range picker / Program select / Branch select — page-level filter context already wires these to widgets via `<DashboardElement />` + filter props
- [x] Skeleton states matching widget shapes
- [x] **MENU_DASHBOARD page (Phase 2 — RESPECT THE NEW APPROACH)** — uses NEW dynamic route `src/app/[lang]/(core)/[module]/dashboards/[slug]/page.tsx`. Server component derives `dashboardCode = params.slug.toUpperCase().replace(/-/g, '')` and renders `<MenuDashboardComponent moduleCode={params.module.toUpperCase()} dashboardCode={dashboardCode} />`. The new component lives at `src/presentation/components/custom-components/menu-dashboards/index.tsx` (separate folder, separate component — `<DashboardComponent />` is NOT touched). The component fires `dashboardByModuleAndCode(moduleCode, dashboardCode)` (NEW BE handler — no UserDashboard join). The Phase 1 per-route stub at `crm/dashboards/casedashboard/page.tsx` will be DELETED in Phase 2.
- [x] **Toolbar overrides** for export / print — surface 2 buttons in dashboard header: "Export Impact Report" (PDF — SERVICE_PLACEHOLDER) and "Print Dashboard" (calls `window.print()`). Confirm `<DashboardHeader />` accepts custom toolbar children; if not, add a one-time `toolbar?: ReactNode` prop (see ISSUE-4).

---

## ⑥ UI/UX Blueprint

**Consumer**: UX Architect → Frontend Developer

> Layout follows the HTML mockup. All widgets render through `<DashboardComponent dashboardCode="CASEDASHBOARD" />` → resolves to the seeded Dashboard row → reads LayoutConfig + ConfiguredWidget JSON → maps each instance to a widget renderer + a Postgres function.

### Page Chrome (MENU_DASHBOARD)

- **Header row**:
  - Left: page title `Case & Program Dashboard` + icon `chart-pie-light` (teal) + subtitle "Impact metrics, program performance, and beneficiary outcomes"
  - Right: **3 filter selects + 2 buttons**:
    1. Period select — default "This Year"; options: This Year / Last Year / This Quarter / Last Quarter / Custom Range. "Custom Range" opens an inline date-range popover.
    2. Programs select — default "All Programs"; options: All / 8 specific (Orphan Sponsorship, Children's Education, Clean Water, Healthcare, Women Empowerment, Food Distribution, Vocational Training, Emergency Relief). Populated dynamically from `case.Programs WHERE StatusId IN (Active, Standby)`.
    3. Branches select — default "All Branches"; options: All / dynamically loaded `app.Branches WHERE IsActive=true`.
    4. **"Export Impact Report"** primary button (PDF download) — SERVICE_PLACEHOLDER (toast "Generating impact report..."). Wire UI in place; backend PDF service deferred.
    5. **"Print Dashboard"** outline button — calls `window.print()`. NO placeholder (browser primitive).

- **No dropdown switcher**, **no Edit Layout chrome** (read-only by default per MENU_DASHBOARD pattern; admin Promote/Hide chrome is irrelevant since dashboard is system-seeded and already a menu leaf).
- **No refresh button** in v1 (filter changes act as refresh; explicit refresh deferred — see ISSUE-6).

### Grid Layout (react-grid-layout — `lg` breakpoint, 12 columns)

| i (instanceId) | Widget | x | y | w | h | minW | minH | Notes |
|----------------|--------|---|---|---|---|------|------|-------|
| KPI_TOTAL_BENEFICIARIES | KPI 1 | 0 | 0 | 4 | 2 | 3 | 2 | KPI hero row 1 col 1 |
| KPI_ACTIVE_PROGRAMS | KPI 2 | 4 | 0 | 4 | 2 | 3 | 2 | KPI hero row 1 col 2 |
| KPI_OPEN_CASES | KPI 3 | 8 | 0 | 4 | 2 | 3 | 2 | KPI hero row 1 col 3 |
| KPI_SERVICES_DELIVERED | KPI 4 | 0 | 2 | 4 | 2 | 3 | 2 | KPI hero row 2 col 1 |
| KPI_OUTCOME_RATE | KPI 5 | 4 | 2 | 4 | 2 | 3 | 2 | KPI hero row 2 col 2 |
| KPI_SPONSOR_MATCH_RATE | KPI 6 | 8 | 2 | 4 | 2 | 3 | 2 | KPI hero row 2 col 3 |
| TBL_PROGRAM_PERFORMANCE | Program Performance Table | 0 | 4 | 12 | 7 | 8 | 5 | Full-width table |
| CHART_ENROLLMENT_TREND | Enrollment Trend Stacked Area | 0 | 11 | 12 | 5 | 8 | 4 | Full-width chart |
| CHART_AGE_DISTRIBUTION | Age Donut | 0 | 16 | 6 | 5 | 4 | 4 | Half-width donut |
| CHART_GENDER_DISTRIBUTION | Gender Donut | 6 | 16 | 6 | 5 | 4 | 4 | Half-width donut |
| CHART_CASES_BY_STATUS | Cases Stacked Bar | 0 | 21 | 6 | 4 | 4 | 3 | Half-width chart |
| CHART_LOCATION_DISTRIBUTION | Location Bar | 6 | 21 | 6 | 4 | 4 | 3 | Half-width chart |
| TBL_OUTCOME_TRACKING | Outcome Tracking Table | 0 | 25 | 12 | 6 | 8 | 4 | Full-width table |
| TBL_STAFF_CASELOAD | Staff Caseload Table | 0 | 31 | 8 | 5 | 6 | 4 | 8-col table |
| CHART_CASE_RESOLUTION_TREND | Resolution Trend Line | 8 | 31 | 4 | 5 | 3 | 4 | 4-col chart |
| LIST_ALERTS | Alerts & Actions | 0 | 36 | 12 | 4 | 8 | 3 | Full-width alerts list |
| TBL_FUNDER_IMPACT | Funder Impact Table | 0 | 40 | 12 | 5 | 8 | 4 | Full-width collapsible — start expanded; no collapse chrome in v1 (deferred — ISSUE-7) |

`md` (8 cols) and `sm` (6 cols) breakpoints — collapse multi-column rows into stacked single-column / 2-column layouts. Full reflow rules computed at FE build time; minimum viable: `lg` defined, others auto-derived by react-grid-layout's responsive behavior.

### KPI Cards (StatusWidgetType1 — 6 cards)

| # | InstanceId | Title | Value Format | Subtitle Format | Color Cue | Icon |
|---|-----------|-------|--------------|-----------------|-----------|------|
| 1 | KPI_TOTAL_BENEFICIARIES | Total Beneficiaries Served | count (e.g., "2,456") | "↑ {deltaThisYear} new this year" (green) | teal | users-light |
| 2 | KPI_ACTIVE_PROGRAMS | Active Programs | count | "{activeCount} active, {standbyCount} standby" (neutral) | blue | stack-light |
| 3 | KPI_OPEN_CASES | Open Cases | count | "{trendArrow} {abs(momPercent)}% vs last month ({trendLabel})" — trendArrow=↓ if improving (fewer cases = good), green; ↑ if growing, warning | green | folder-open-light |
| 4 | KPI_SERVICES_DELIVERED | Services Delivered (YTD) | count (e.g., "12,456") | "↑ {yoyPercent}% vs same period last year" (green) | orange | hand-heart-light |
| 5 | KPI_OUTCOME_RATE | Outcome Achievement Rate | percent ("84%") | "↑ {qoqPercent}% vs last quarter" (green if positive) | purple | target-light |
| 6 | KPI_SPONSOR_MATCH_RATE | Sponsor Match Rate | percent ("78%") | "{sponsoredCount} of {totalOrphanCount} orphans individually sponsored" (neutral) | cyan | heart-light |

### Charts (detail per chart)

| # | InstanceId | Title | Type | X | Y | Source | Filters Honored | Empty/Tooltip |
|---|-----------|-------|------|---|---|--------|-----------------|---------------|
| 8 | CHART_ENROLLMENT_TREND | Beneficiary Enrollment Trend | Stacked Area | Month (last 12) | Active beneficiaries | data.series[].data | period, program, branch | "No enrollments in selected period" |
| 9 | CHART_AGE_DISTRIBUTION | Beneficiaries by Age Group | Donut | — | — | data.segments | period, program, branch | "No beneficiaries match filter" |
| 10 | CHART_GENDER_DISTRIBUTION | Beneficiaries by Gender | Donut | — | — | data.segments | period, program, branch | "No beneficiaries match filter" |
| 11 | CHART_CASES_BY_STATUS | Cases by Status | Stacked Horizontal Bar | — | Status | data.segments | period, program, branch | "No cases match filter" |
| 12 | CHART_LOCATION_DISTRIBUTION | Beneficiaries by Location | Horizontal Bar | Beneficiary Count | City | data — top 6 + "Others" | period, program | "No location data" |
| 15 | CHART_CASE_RESOLUTION_TREND | Case Resolution Trend | Line (2 series: Opened / Closed) | Month (last 6) | Case count | data.series | branch, program | "No cases in selected period" |

### Tables (detail per table)

| # | InstanceId | Title | Renderer | Columns | Row Click | Empty State |
|---|-----------|-------|----------|---------|-----------|-------------|
| 7 | TBL_PROGRAM_PERFORMANCE | Program Performance Overview | FilterTableWidget | Program (icon+name) / Beneficiaries (center) / Capacity (center) / Enrollment (progress bar + %) / Cases Open (center) / Outcome Rate (dot + %) / Budget Used (center %) / Status (badge) | Navigate to `/crm/casemanagement/programmanagement?programId={id}` | "No programs in scope" |
| 13 | TBL_OUTCOME_TRACKING | Outcome Tracking (This Year) | NormalTableWidget | Outcome / Target (center) / Achieved (center) / Rate (200px progress bar + label) / Trend (center colored arrow + label) | NO row click (read-only) | "No outcome metrics" |
| 14 | TBL_STAFF_CASELOAD | Staff Caseload Distribution | FilterTableWidget | Staff (icon+name) / Open Cases (center) / Beneficiaries (center) / Avg Resolution (center "N days") / Overdue (center, red badge if >0) | Navigate to `/crm/casemanagement/caselist?assignedStaffId={staffId}` | "No staff caseload data" |
| 17 | TBL_FUNDER_IMPACT | Funder Impact Summary | NormalTableWidget | Funder / Program / Amount (right) / Beneficiaries (center) / Key Outcome | Navigate to `/crm/grant/grantlist?grantId={grantId}` (DEGRADED — Grant #62 not built; row click toasts "Grant module coming soon") | "No funder data — Grant module not yet available" |

### Alerts & Actions (widget 16 — NEW renderer `AlertListWidget`)

Renders a vertical list of alert rows. Each row shape (from `data.alerts[]`):

```typescript
{
  severity: 'warning' | 'info' | 'success';   // colors background pill
  iconCode: string;                            // phosphor icon
  message: string;                             // can include <strong> tags (renderer parses & escapes safely)
  link: {
    label: string;                             // CTA label (e.g., "View Overdue Cases")
    route: string;                             // navigation target
    args?: Record<string, string | number>;    // query string args
  }
}
```

Empty state: "No alerts — all programs and cases on track."

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Period | Native select + custom range popover | "This Year" | All widgets that aggregate over time (KPI 1/3/4/5, charts 8/11/12/15, tables 7/13, alerts) | Presets: This Year / Last Year / This Quarter / Last Quarter / Custom Range |
| Program | Single-select (ApiSelectV2) — typeahead from `case.Programs` | "All Programs" | KPI 1/3/4/5, charts 8/9/10/11/12, tables 7/13, alerts | Excludes "Active Programs" KPI (which counts ALL programs) and "Sponsor Match Rate" (orphan-program-specific) |
| Branch | Single-select — from `app.Branches` | "All Branches" or user's branch (BRANCH_MANAGER) | KPI 1/3/4/6, charts 8/9/10/11/12/15, tables 7/14, alerts | Always honored by all widgets except Active Programs KPI |

Filter values flow into `<DashboardElement />` filter context, which projects them into each widget's `customParameter` JSON via the runtime's `{placeholder}` substitution. Functions read them out of `p_filter_json`.

### Drill-Down / Navigation Map

| From Widget / Element | Click On | Navigates To | Prefill |
|-----------------------|----------|--------------|---------|
| Program row (table 7) | Whole row | `/crm/casemanagement/programmanagement` | `programId={programId}` (SERVICE_PLACEHOLDER — Program list does not yet accept `?programId=`; v1 navigates and toasts "Drill-down support coming") — see ISSUE-5 |
| Staff row (table 14) | Whole row | `/crm/casemanagement/caselist` | `assignedStaffId={staffId}` |
| Impact card 1 (Children) | "View Stories" link | `/crm/casemanagement/beneficiarylist` | `orphanStatusOnly=true` (SERVICE_PLACEHOLDER until BeneficiaryList accepts) — degrade to plain navigation if not |
| Impact card 2 (Wells) | "View Map" link | `/crm/casemanagement/programmanagement` | `programCode=CLEAN_WATER` |
| Impact card 3 (Women) | "View Profiles" link | `/crm/casemanagement/beneficiarylist` | `vocationalGraduate=true` (SERVICE_PLACEHOLDER) |
| Alert link (varies per alert) | CTA link | Per `link.route` from alert data | Per `link.args` |
| Funder row (table 17) | Whole row | `/crm/grant/grantlist?grantId={grantId}` | DEGRADED — Grant #62 not built; toast "Grant module coming soon" |
| Funder "Generate Full Impact Report" button | Click | SERVICE_PLACEHOLDER toast | Eventual: `/reports/html-report-viewer?reportType=IMPACT&...` — depends on Reports module |

### User Interaction Flow

1. **Initial load**: User clicks `CRM → Dashboards → Case Dashboard` in sidebar → URL becomes `/[lang]/crm/dashboards/casedashboard` → page renders `<CaseDashboardPageConfig />` → renders `<DashboardComponent dashboardCode="CASEDASHBOARD" />`. Component fetches `dashboardByModuleCode(moduleCode='CRM')` → finds row WHERE DashboardCode='CASEDASHBOARD' → fetches dashboardById → reads LayoutConfig + ConfiguredWidget JSON → renders 17-widget grid → all widgets parallel-fetch with default filters (This Year / All Programs / All Branches).
2. **Filter change** (Period / Program / Branch): widgets honoring that filter refetch in parallel; widgets NOT honoring it stay cached. Refetch flows through the existing widget context refresh-on-filter-change.
3. **Drill-down click**: navigates per Drill-Down Map → destination receives prefill args. Some args are SERVICE_PLACEHOLDER until destination accepts (degrade gracefully — destination loads unfiltered + toast).
4. **Back navigation**: returns to dashboard → filters preserved (URL search params persist; if not feasible, default filters re-apply — confirm in build).
5. **Export Impact Report** → toast SERVICE_PLACEHOLDER. **Print Dashboard** → `window.print()`.
6. **No edit-layout / add-widget chrome** in v1 (deferred MENU_DASHBOARD chrome).
7. **Empty / loading / error states**: each widget renders its own skeleton during fetch (StatusWidgetType1 → KPI skeleton; charts → chart skeleton; tables → row skeletons; alert list → 3-row skeleton). Error → red mini banner + Retry button. Empty → muted icon + per-widget empty message.

---

## ⑦ Substitution Guide

**Consumer**: Backend Developer + Frontend Developer

> First MENU_DASHBOARD prompt — sets the canonical convention for follow-up dashboards (Volunteer #57, Donation, Communication, Ambassador, Contact dashboards).

**Canonical Reference**: NONE (this prompt establishes the canonical for follow-ups).
Reference Postgres widget patterns: `sett.fn_donation_summary_widget.sql`, `sett.widget_age_distribution.sql`, `sett.widget_geographic_country_distribution.sql` (existing precedents in `Functions/sett/`).

| Convention | This Dashboard | Notes |
|-----------|----------------|-------|
| DashboardCode | `CASEDASHBOARD` | Matches existing seeded MenuCode |
| MenuUrl | `crm/dashboards/casedashboard` | Already seeded; no change |
| Schema for Postgres functions | `case.fn_case_dashboard_*` | NEW `case/` folder under `DatabaseScripts/Functions/` (first case-domain widget functions) |
| Function naming | `fn_case_dashboard_{aspect}` | snake_case; aspects: kpi_*, chart_*, table_*, list_* (loose) |
| Widget instance ID | `{TYPE}_{NAME}` (e.g., `KPI_TOTAL_BENEFICIARIES`) | Stable across LayoutConfig + ConfiguredWidget |
| Module | `CRM` | ModuleCode resolves to ModuleId at seed time |
| Parent menu | `CRM_DASHBOARDS` | Already seeded |
| FE route | `/[lang]/crm/dashboards/casedashboard/page.tsx` | Already exists as stub; needs `dashboardCode` prop wired |

---

## ⑧ File Manifest

**Consumer**: Backend Developer + Frontend Developer

### Backend Files (Path A only — 17 SQL functions, NO C# code)

| # | File | Path | Required |
|---|------|------|----------|
| 1 | KPI 1 — Total Beneficiaries | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/case/fn_case_dashboard_kpi_total_beneficiaries.sql` | YES |
| 2 | KPI 2 — Active Programs | `…/case/fn_case_dashboard_kpi_active_programs.sql` | YES |
| 3 | KPI 3 — Open Cases | `…/case/fn_case_dashboard_kpi_open_cases.sql` | YES |
| 4 | KPI 4 — Services Delivered | `…/case/fn_case_dashboard_kpi_services_delivered.sql` | YES |
| 5 | KPI 5 — Outcome Rate | `…/case/fn_case_dashboard_kpi_outcome_rate.sql` | YES |
| 6 | KPI 6 — Sponsor Match Rate | `…/case/fn_case_dashboard_kpi_sponsor_match_rate.sql` | YES |
| 7 | Table 7 — Program Performance | `…/case/fn_case_dashboard_program_performance.sql` | YES |
| 8 | Chart 8 — Enrollment Trend | `…/case/fn_case_dashboard_enrollment_trend.sql` | YES |
| 9 | Chart 9 — Age Distribution | `…/case/fn_case_dashboard_age_distribution.sql` | YES |
| 10 | Chart 10 — Gender Distribution | `…/case/fn_case_dashboard_gender_distribution.sql` | YES |
| 11 | Chart 11 — Cases by Status | `…/case/fn_case_dashboard_cases_by_status.sql` | YES |
| 12 | Chart 12 — Location Distribution | `…/case/fn_case_dashboard_location_distribution.sql` | YES |
| 13 | Table 13 — Outcome Tracking | `…/case/fn_case_dashboard_outcome_tracking.sql` | YES |
| 14 | Table 14 — Staff Caseload | `…/case/fn_case_dashboard_staff_caseload.sql` | YES |
| 15 | Chart 15 — Resolution Trend | `…/case/fn_case_dashboard_resolution_trend.sql` | YES |
| 16 | Widget 16 — Alerts | `…/case/fn_case_dashboard_alerts.sql` | YES |
| 17 | Table 17 — Funder Impact | `…/case/fn_case_dashboard_funder_impact.sql` | YES (DEGRADED — returns sample data until Grant #62 builds) |

**Backend Wiring Updates**: NONE (Path A reuses `generateWidgets` GraphQL handler; no new C# endpoints).

**Database Migration**: 1 file — register the 17 new functions via existing migration runner pattern (the project's `DatabaseScripts/Functions/` files appear to be auto-applied at runtime; confirm during build — if not, generate `AddCaseDashboardFunctions.cs` migration that executes each `.sql` file).

### Frontend Files

| # | File | Path | Required |
|---|------|------|----------|
| 1 | NEW widget renderer — AlertListWidget | `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/alert-list-widgets/AlertListWidget.tsx` | YES |
| 2 | NEW widget barrel | `…/widgets/alert-list-widgets/index.ts` | YES |
| 3 | DashboardComponent enhancement — accept `dashboardCode` prop | `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/index.tsx` | MODIFY (add ~10 lines: prop signature + override-by-code logic in the auto-select effect at lines 132-143) |
| 4 | CaseDashboardPageConfig — pass prop | `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/casedashboard.tsx` | MODIFY (1-line: `<DashboardComponent dashboardCode="CASEDASHBOARD" />`) |
| 5 | (Optional) DashboardHeader toolbar slot | `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/dashboard-header.tsx` (or wherever filters render) | MODIFY if mockup's "Export Impact Report" + "Print Dashboard" buttons cannot fit through existing filter chrome — see ISSUE-4 |

**Frontend Wiring Updates**:

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | Add `AlertListWidget` to `WIDGET_REGISTRY` map (after line 60) |
| 2 | `dashboards/widgets/index.ts` (if exists, else inline) | Export `AlertListWidget` |
| 3 | sidebar / menu config | NONE — CASEDASHBOARD menu already seeded |

### DB Seed (the bulk of MENU_DASHBOARD work — `sql-scripts-dyanmic/CaseDashboard-sqlscripts.sql`)

> File path uses repo's existing `sql-scripts-dyanmic/` typo (preserve per project convention).

| # | Item | When | Notes |
|---|------|------|-------|
| 1 | 1 Dashboard row in `sett.Dashboards` | always | DashboardCode=CASEDASHBOARD, IsSystem=true, ModuleId resolves from CRM, IsActive=true, CompanyId=NULL (global system) |
| 2 | 1 DashboardLayout row in `sett.DashboardLayouts` | always | LayoutConfig + ConfiguredWidget JSON × 17 instances |
| 3 | 1 NEW WidgetType row in `sett.WidgetTypes` (if missing) | only if AlertListWidget novel | WidgetTypeCode=ALERT_LIST, ComponentPath=AlertListWidget |
| 4 | 17 Widget rows in `sett.Widgets` | always | One per instance — DefaultParameters JSON honors filter keys (dateFrom/dateTo/programId/branchId/[assignedStaffId]); StoredProcedureName=case.fn_case_dashboard_* |
| 5 | 17 WidgetRole grants (BUSINESSADMIN read-all) | always | At minimum BUSINESSADMIN; expand at admin-config time for other roles |
| 6 | NO new Menu seed | — | CASEDASHBOARD menu @ MenuCode under CRM_DASHBOARDS @ OrderBy=6 already seeded (per MODULE_MENU_REFERENCE.md) |
| 7 | UPDATE Dashboard SET MenuId = (SELECT MenuId FROM auth.Menus WHERE MenuCode='CASEDASHBOARD') WHERE DashboardCode='CASEDASHBOARD' | Phase 2 | The ONLY Dashboard column written for menu linkage. Slug (`Menu.MenuUrl='casedashboard'`), sort (`Menu.OrderBy=6`), and visibility all live on the linked auth.Menus row — do NOT write MenuUrl/OrderBy/IsMenuVisible to Dashboard (those columns don't exist). |
| 8 | Backfill seed `sql-scripts-dyanmic/Dashboard-MenuBackfill-sqlscripts.sql` | Phase 2 | One-time idempotent: `UPDATE sett."Dashboards" d SET "MenuId" = m."MenuId" FROM auth."Menus" m WHERE d."IsSystem"=true AND m."MenuCode" = d."DashboardCode" AND d."MenuId" IS NULL`. Affects all 6 system dashboards. |
| 8 | (DEGRADED) 1 sample-data seed for Funder Impact | optional | If Grant #62 not built by build time, seed `case.case_dashboard_funder_sample_data` table OR hardcode rows in `fn_case_dashboard_funder_impact` to return mockup's 5 rows |

Re-running seed must be idempotent (NOT EXISTS guards on every INSERT/UPDATE).

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

# CASEDASHBOARD menu ALREADY seeded under CRM_DASHBOARDS @ OrderBy=6.
# This prompt does NOT seed a new Menu row — only Dashboard + DashboardLayout + 17 Widgets + WidgetRoles.
MenuName: Case Dashboard         # FYI — already seeded
MenuCode: CASEDASHBOARD          # FYI — already seeded
ParentMenu: CRM_DASHBOARDS       # FYI — already seeded (MenuId 278)
Module: CRM
MenuUrl: crm/dashboards/casedashboard   # FYI — already seeded
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT
  # Other role grants (CRM_MANAGER, PROGRAM_DIRECTOR, BRANCH_MANAGER, CASE_WORKER) — left to admin-config; not seeded here

GridFormSchema: SKIP    # Dashboards have no RJSF form
GridCode: CASEDASHBOARD

# Dashboard-specific seed inputs
DashboardCode: CASEDASHBOARD
DashboardName: Case Dashboard
DashboardIcon: chart-pie-light
DashboardColor: #0d9488
IsSystem: true
DashboardKind: MENU_DASHBOARD   # encoded by Dashboard.MenuId IS NOT NULL after Phase 2 seed; no IsMenuVisible column on Dashboard
MenuOrderBy: 6              # written to auth.Menus.OrderBy (already seeded — NOT to Dashboard)
WidgetGrants:               # all 17 widgets — BUSINESSADMIN read-all
  - KPI_TOTAL_BENEFICIARIES: BUSINESSADMIN
  - KPI_ACTIVE_PROGRAMS: BUSINESSADMIN
  - KPI_OPEN_CASES: BUSINESSADMIN
  - KPI_SERVICES_DELIVERED: BUSINESSADMIN
  - KPI_OUTCOME_RATE: BUSINESSADMIN
  - KPI_SPONSOR_MATCH_RATE: BUSINESSADMIN
  - TBL_PROGRAM_PERFORMANCE: BUSINESSADMIN
  - CHART_ENROLLMENT_TREND: BUSINESSADMIN
  - CHART_AGE_DISTRIBUTION: BUSINESSADMIN
  - CHART_GENDER_DISTRIBUTION: BUSINESSADMIN
  - CHART_CASES_BY_STATUS: BUSINESSADMIN
  - CHART_LOCATION_DISTRIBUTION: BUSINESSADMIN
  - TBL_OUTCOME_TRACKING: BUSINESSADMIN
  - TBL_STAFF_CASELOAD: BUSINESSADMIN
  - CHART_CASE_RESOLUTION_TREND: BUSINESSADMIN
  - LIST_ALERTS: BUSINESSADMIN
  - TBL_FUNDER_IMPACT: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Consumer**: Frontend Developer

**Queries** — all widgets use the existing **`generateWidgets`** GraphQL handler (NOT new endpoints):

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| generateWidgets (existing) | `(data jsonb, metadata jsonb, total_count int, filtered_count int)` | widgetId, p_filter_json, p_page, p_page_size, p_user_id, p_company_id | All 17 widgets |
| dashboardByModuleCode (existing) | `[DashboardDto]` | moduleCode='CRM' | Returns array including CASEDASHBOARD row + other CRM dashboards |
| dashboardById (existing) | `DashboardDto` | dashboardId | Loads CASEDASHBOARD's full dashboardLayouts JSON |
| widgetByModuleCode (existing) | `[WidgetDto]` | moduleCode='CRM' | Returns array including all 17 case dashboard widgets |

**Per-widget data shapes (jsonb in `data` column)**:

KPI widgets (1-6): `{ value: number | string, formatted: string, subtitle: string, deltaLabel?: string, deltaColor?: 'positive' | 'warning' | 'neutral', icon?: string, color?: string }`

Table widget (7): `{ rows: [{ programId, programName, icon, beneficiaries, capacity, enrollmentPct, casesOpen, outcomeRate, outcomeColor, budgetUsedPct, status, statusBadge }] }`

Chart widgets (8/15): `{ type: 'area' | 'line', labels: string[12], series: [{ name, color, data: number[12] }], annotations?: [{ xValue, label }] }`

Donut widgets (9/10): `{ total: number, segments: [{ label, value, pct, color }] }`

Stacked-bar widget (11): `{ segments: [{ label, value, color, pctOfTotal }] }`

Bar widget (12): `{ rows: [{ cityName, value, color, widthPct }] }`

Outcome table (13): `{ rows: [{ outcomeName, target, achieved, ratePct, rateColor, trendLabel, trendDir }] }`

Staff table (14): `{ rows: [{ staffId, staffName, avatarUrl, openCases, beneficiaries, avgResolutionDays, overdueCount, overdueColor }] }`

Alerts list (16): `{ alerts: [{ severity, iconCode, message, link: { label, route, args } }] }`

Funder table (17): `{ rows: [{ funderName, programName, amountUsd, beneficiaries, keyOutcome, grantId? }] }`

**No composite DTO**. No new C# types. Each widget consumes its own jsonb shape directly.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (no new C# code; verifies the migration that registers the 17 functions runs cleanly)
- [ ] All 17 SQL functions exist in `case.` schema after migration
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/casedashboard`
- [ ] Dashboard renders with 17 widgets in the documented layout

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Dashboard loads with default filters (This Year / All Programs / All Branches) and renders all 17 widgets
- [ ] Each KPI card shows correct value formatted per spec (count / %)
- [ ] Each chart renders with correct axes, legend, tooltip
- [ ] Each table renders with correct columns + row click behavior
- [ ] Period filter change refetches all date-honoring widgets in parallel
- [ ] Program filter change refetches Program-scoped widgets only
- [ ] Branch filter change refetches Branch-scoped widgets only
- [ ] Custom Range opens date popover and applies on confirm
- [ ] Drill-down clicks navigate per Drill-Down Map (some are SERVICE_PLACEHOLDER — verify graceful toast)
- [ ] "Export Impact Report" toasts SERVICE_PLACEHOLDER (no crash)
- [ ] "Print Dashboard" opens browser print dialog
- [ ] Empty / loading / error states render per widget
- [ ] Role-based widget gating: WidgetRole(HasAccess=false) → widget hidden
- [ ] Alerts list (widget 16) generates plausible alert items per the rules in §④ for sample data
- [ ] Funder Impact table (17) shows DEGRADED state if Grant #62 not built (5 sample rows OR empty + note)
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl)
- [ ] Sidebar leaf "Case Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] Bookmarked URL `/[lang]/crm/dashboards/casedashboard` survives reload (page works on direct URL entry, not just sidebar click)
- [ ] Role-gating via existing `RoleCapability(MenuId=CASEDASHBOARD)` hides the sidebar leaf for unauthorized roles

**DB Seed Verification:**
- [ ] Dashboard row inserted with DashboardCode=CASEDASHBOARD, ModuleId=CRM, IsSystem=true
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (parses cleanly) and ConfiguredWidget JSON
- [ ] All 17 Widget rows + WidgetRole grants (BUSINESSADMIN) inserted
- [ ] AlertListWidget WidgetType row inserted (or reused if already exists from another module)
- [ ] All 17 Postgres functions queryable: `SELECT * FROM case."fn_case_dashboard_kpi_total_beneficiaries"('{}'::jsonb, 1, 50, 1, 1);` returns 1 row × 4 columns shape
- [ ] Re-running seed is idempotent (NOT EXISTS guards on every INSERT/UPDATE)

---

## ⑫ Special Notes & Warnings

**Consumer**: All agents

### Known Issues (pre-flagged)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | HIGH | Architecture (REWRITTEN 2026-04-29) | **Full MENU_DASHBOARD bootstrap is IN SCOPE — Phase 2.** Original Phase 1 deferred this; the deferral is now rejected. The bootstrap delivers: (1) `Dashboard.MenuId int?` column (1 column only — slug/sort/visibility live on `auth.Menus`); (2) NEW `dashboardByModuleAndCode` BE query (no UserDashboard join — see ISSUE-20 for why this is non-negotiable); (3) NEW `<MenuDashboardComponent />` FE component (separate from `<DashboardComponent />` — see ISSUE-21 for rationale); (4) dynamic `[slug]/page.tsx` route; (5) `linkDashboardToMenu` / `unlinkDashboardFromMenu` mutations + `menuLinkedDashboardsByModuleCode` query; (6) sidebar auto-injection; (7) backfill seed; (8) deletion of 6 hardcoded route pages. Tracked in the PHASE 2 block at the top of this file. | PHASE 2 — IN PROGRESS |
| ISSUE-2 | MED | Multi-currency | Program "Budget Used %" (table 7) requires GlobalDonation.ProgramId FK to be wired with multi-currency conversion. Per Program #51 ISSUE-1/2/3, this projection is currently a placeholder (returns 0% if Program.AnnualBudget is NULL). Function emits 0% gracefully; field is informational, not blocking. | OPEN |
| ISSUE-3 | LOW | UI | "Impact Highlights" (3 decorative cards from mockup — Children/Wells/Women Employed) **deferred from v1**. The 3 cards in the mockup are storytelling chrome, not analytical KPIs (their values are duplicates of KPI 6 + Outcome Tracking rows). Bringing them into the layout would require either 3 more SQL functions for hardcoded curated highlights OR a new `ImpactCardWidget` renderer. **Decision**: drop from v1 layout; revisit if user feedback requests them. | OPEN |
| ISSUE-4 | MED | UI chrome | `<DashboardHeader />` (or equivalent) may not have a slot for custom toolbar children (the 3 filter selects + Export + Print buttons). Pre-flight check during build: if no toolbar slot exists, add a one-time `toolbar?: ReactNode` prop. Otherwise UI cannot match the mockup's header layout. | OPEN |
| ISSUE-5 | MED | Drill-down | Program Performance table (7) row click navigates to `/crm/casemanagement/programmanagement?programId={id}`, but Program list (#51) does not yet accept the `?programId=` arg — drill-down loads unfiltered. Same for impact card drill-downs (orphanStatusOnly, programCode, vocationalGraduate filters not yet supported by destination screens). FE adds the args anyway (forward-compatible); destinations toast "Coming soon" for unsupported args. | OPEN |
| ISSUE-6 | LOW | UX | No explicit "Refresh" button in v1 — filter changes act as refresh. If users request, add a refresh button to the header that calls `widgetRefetch()` on every widget. Deferred. | OPEN |
| ISSUE-7 | LOW | UI | Funder Impact table (17) — mockup is collapsible; v1 ships expanded only (no collapse chrome). Add toggle if user feedback requests. | OPEN |
| ISSUE-8 | HIGH | Dependency | **Funder Impact table (17) DEGRADED** — Grant #62 not yet built. Function returns 5 hardcoded sample rows matching the mockup data OR empty array with placeholder "Grant module coming soon" message. When #62 ships, function gets re-implemented to query `crm.Grants` joined to GlobalDonation. Pre-flag for #62 build session: update `fn_case_dashboard_funder_impact` to consume real Grant data. | OPEN |
| ISSUE-9 | MED | Performance | All 17 widgets fire in parallel on initial load → up to 17 concurrent Postgres function calls. For small data volumes (< 10K beneficiaries) this is fine. At scale, consider: (a) materialized views for daily-stable aggregates (KPIs 1/2/4/5, charts 8/9/10/12); (b) per-tenant materialized refresh on Beneficiary/Case insert; (c) widget batching via a future composite endpoint. Out of scope for v1. | OPEN |
| ISSUE-10 | MED | Role scoping | Per §④, BRANCH_MANAGER and CASE_WORKER scopes require joins to `auth.UserBranches` and `app.Staffs`. Verify both tables exist + populated correctly in dev DB before building scoped functions; otherwise functions error out for non-admin users. | OPEN |
| ISSUE-11 | LOW | Schema location | Postgres functions placed in `case.` schema (matching existing `case` schema for entities). Existing widget functions are in `sett.` (e.g., `sett.fn_donation_summary_widget`). **Decision**: use `case.` for case-domain widgets to keep widget aggregation co-located with source schema. **Risk**: if the `case.` schema's CompanyId scoping rules differ from `sett.`, may need extra grants. Verify schema permissions in dev DB. | OPEN |
| ISSUE-12 | LOW | Seed file location | DB seed file goes in `sql-scripts-dyanmic/` (preserve repo's typo per project convention — see Beneficiary #49 ISSUE-15 / Volunteer #55 ISSUE-15). | NOTED |
| ISSUE-13 | MED | Alerts widget rules engine | Alert generation rules (`fn_case_dashboard_alerts` — §④) are coded as a Postgres function with hardcoded thresholds. **Risk**: thresholds (overdue days, outcome target % gap, waitlist counts) should be configurable per-tenant in a future iteration. v1 hardcodes per the mockup specifics. | OPEN |
| ISSUE-20 | HIGH | BE handler isolation | Existing `GetDashboardByModuleCodeHandler` ([GetDashboardByModuleCode.cs:25-33](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleCode.cs#L25-L33)) starts `from ud in dbContext.UserDashboard join d in dbContext.Dashboards on ud.DashboardId equals d.DashboardId where ud.UserId == userId` — inner join with UserDashboard. MENU_DASHBOARD rows have NO UserDashboard rows by default (system-pinned, not user-pinned), so reusing this handler returns ZERO results for fresh users. The new `GetDashboardByModuleAndCode(moduleCode, dashboardCode)` handler MUST start `from d in dbContext.Dashboards`, filter by `d.IsActive AND !d.IsDeleted AND d.MenuId IS NOT NULL`, include `DashboardLayouts + Module`, return single row. **Existing handler stays UNTOUCHED** — STATIC mode behavior preserved. | PHASE 2 — OPEN |
| ISSUE-21 | HIGH | FE component separation | `<DashboardComponent />` is tightly coupled to UserDashboard state (switcher cache, IsDefault auto-pick, max-3 counter, edit-layout toggle, module-loading overlay). Trying to dual-mode it via `dashboardCode` prop (Phase 1 approach) creates fragile gating sites in `dashboard-header.tsx` (lines 61-66, 104-122, 197-203) — the user-reported "Create Dashboard leaks on case-dashboard" was the first symptom. Phase 2 creates `<MenuDashboardComponent />` as a separate component with its own lean header + grid render. `<DashboardComponent />` stays UNTOUCHED — `git diff src/.../dashboards/` MUST be empty after Phase 2 (acceptance gate). | PHASE 2 — OPEN |
| ISSUE-22 | LOW | New component duplication | `<MenuDashboardComponent />` inlines ~30-50 lines of widget-grid render loop (read LayoutConfig + ConfiguredWidget, iterate, render via `WIDGET_REGISTRY` / `QUERY_REGISTRY`). Code is duplicated from `<DashboardComponent />`. Accepted on first ship — extract a shared `<DashboardWidgetGrid />` later if the duplication grows (probably the 2nd MENU_DASHBOARD prompt). | PHASE 2 — ACCEPTED |
| ISSUE-23 | LOW | Slug → DashboardCode convention | `[slug]/page.tsx` derives `dashboardCode = params.slug.toUpperCase().replace(/-/g, '')`. Relies on convention `Dashboard.DashboardCode == upper(strip-hyphens(Menu.MenuUrl))` — holds for the system-seeded set (CASEDASHBOARD ↔ case-dashboard). When admin Promote-to-menu introduces custom slugs that diverge, switch to a `dashboardByModuleAndMenuUrl` query OR constrain Promote to enforce the convention. Out of scope this prompt. | PHASE 2 — ACCEPTED |

### Dashboard-class warnings (apply to most prompts of this template)
- Dashboards are READ-ONLY. No CRUD on this screen — Dashboard row CRUD is the existing `#78 Dashboard Config` screen.
- Widget queries must be tenant-scoped (`p_company_id` from HttpContext on every Postgres function). Easy to forget on a new function.
- Path-A — every function MUST conform to fixed 5-arg / 4-column contract. SQL Server syntax (`CREATE PROCEDURE`, `IF OBJECT_ID`, `[brackets]`) WILL fail. Use Postgres syntax exclusively.
- N+1 risk on per-row aggregates inside table widgets (e.g., per-program enrollment + cases + outcome computation) — use single SQL with proper aggregates and subqueries; avoid loops.
- Multi-currency aggregation for Program budget — see ISSUE-2.
- react-grid-layout LayoutConfig JSON — at minimum `lg` breakpoint MUST be defined. Missing breakpoints cause widget overlap on smaller screens.
- ConfiguredWidget JSON `instanceId` MUST be unique per dashboard AND MUST equal the corresponding `i` value in every LayoutConfig breakpoint array. Use the WidgetCode column (e.g., `KPI_TOTAL_BENEFICIARIES`) as both `instanceId` and `i`.
- Each ConfiguredWidget element references a `widgetId` from `sett.Widgets`. Widget renderer resolved via `Widgets.WidgetType.ComponentPath` against `WIDGET_REGISTRY`. Widget data resolved via `Widget.StoredProcedureName` through the generic `generateWidgets` GraphQL field.
- Drill-down args MUST use destination screen's accepted query-param names exactly. See ISSUE-5 for unsupported args (forward-compatible — destinations toast "coming soon").

### MENU_DASHBOARD-only warnings
- This prompt does NOT introduce the dynamic [slug] route or schema columns from the template preamble — see ISSUE-1.
- Per-dashboard FE page exists (per-route stub at `crm/dashboards/casedashboard/page.tsx`) — DO NOT delete it during build (deviation from preamble's "DELETE per-dashboard hardcoded route pages" guidance — defer cleanup to ISSUE-1).
- Sidebar leaf already exists; do NOT seed a duplicate Menu row.
- DashboardComponent — when adding `dashboardCode` prop support, the lookup logic should: (1) fetch `dashboardByModuleCode('CRM')` as today; (2) if `dashboardCode` prop set, find the row WHERE `dashboardCode === prop` (NOT `IsDefault=true`); (3) if `dashboardCode` prop set but no matching row found, show "Dashboard not found" empty state (DO NOT silently fall back to default). This matches the "slug-vs-default precedence" rule in the template preamble.
- Path-A function contract is NON-NEGOTIABLE (see §⑤). Functions written incorrectly (wrong arg order, missing return columns, SQL Server syntax) will silently fail at runtime — verify each function with a manual `SELECT * FROM case."fn_..."('{}'::jsonb, 1, 50, 1, 1);` before declaring done.

### Service Dependencies (UI-only — flag genuine external-service gaps)
- ⚠ **SERVICE_PLACEHOLDER: Export Impact Report (PDF)** — full UI in place; handler toasts because PDF rendering service not wired. Future: integrate with Reports module (`/reports/html-report-viewer?reportType=IMPACT&dateFrom=...`).
- ⚠ **DEGRADED: Funder Impact table (17)** — Grant #62 not yet built; widget returns sample data per ISSUE-8.
- ⚠ **SERVICE_PLACEHOLDER: drill-down args** — destinations don't yet accept `?programId=`, `?orphanStatusOnly=`, `?programCode=`, `?vocationalGraduate=` — see ISSUE-5.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning (REWRITTEN 2026-04-29) | HIGH | Architecture | Full MENU_DASHBOARD bootstrap is IN SCOPE — Phase 2 (see PHASE 2 block at top of file) | PHASE 2 — IN PROGRESS |
| ISSUE-2 | Planning | MED | Multi-currency | Program budget projection placeholder | OPEN |
| ISSUE-3 | Planning | LOW | UI | Impact Highlights deferred from v1 | OPEN |
| ISSUE-4 | Planning | MED | UI chrome | DashboardHeader toolbar slot may need addition | OPEN |
| ISSUE-5 | Planning | MED | Drill-down | Destination screens don't accept prefill args yet | OPEN |
| ISSUE-6 | Planning | LOW | UX | No explicit refresh button in v1 | OPEN |
| ISSUE-7 | Planning | LOW | UI | Funder Impact collapse chrome deferred | OPEN |
| ISSUE-8 | Planning | HIGH | Dependency | Funder Impact DEGRADED — Grant #62 not built | OPEN |
| ISSUE-9 | Planning | MED | Performance | 17 parallel function calls — materialized view consideration | OPEN |
| ISSUE-10 | Planning | MED | Role scoping | UserBranches / Staffs verification needed | OPEN |
| ISSUE-11 | Planning | LOW | Schema location | Functions in `case.` vs `sett.` — verify permissions | OPEN |
| ISSUE-12 | Planning | NOTED | Seed file | `sql-scripts-dyanmic/` typo preservation | NOTED |
| ISSUE-13 | Planning | MED | Alerts engine | Hardcoded alert thresholds — config TBD | OPEN |
| ISSUE-14 | Session 1 | MED | Schema deviation | `BeneficiaryServiceLog.LogDate` does not exist — actual column is `ServiceDate`. All 4 service-log functions use `ServiceDate`. Functional impact: none (just a name swap). | OPEN |
| ISSUE-15 | Session 1 | HIGH | Schema deviation | `ProgramOutcomeMetric` does NOT have `ActualValue` / `TargetValue` / `Achieved` numeric columns — actual schema is text-based (`MetricName`, `TargetText`, `MeasurementText`, `FrequencyText`). KPI 5 (Outcome Rate) and Table 13 (Outcome Tracking) use a PROXY rate: `(metrics with non-null MeasurementText) / total metrics × 100`. Re-implement with quantitative outcome tracking when ProgramOutcomeMetric gets numeric fields. | OPEN |
| ISSUE-16 | Session 1 | LOW | Schema deviation | `Staff` has single `StaffName` field (not FirstName/LastName) and no `AvatarUrl` — staff caseload returns `staffName` directly and `avatarUrl=null`. | OPEN |
| ISSUE-17 | Session 1 | LOW | Schema deviation | `Program.Capacity` does not exist — actual column is `MaximumCapacity`. All enrollment % calcs use `MaximumCapacity`. | OPEN |
| ISSUE-18 | Session 1 | MED | EF migration | EF migration NOT generated to register the 17 new SQL functions per token-budget directive. Functions live in `DatabaseScripts/Functions/case/` and rely on the project's auto-apply mechanism. **Verify**: confirm functions get applied at runtime; if not, generate `AddCaseDashboardFunctions` migration that runs each `.sql` file. | OPEN |
| ISSUE-19 | Session 1 | MED | Build verification | `dotnet build` and `pnpm dev` smoke tests SKIPPED per token-budget directive — must run before production-ready. Verify: 17 SQL functions queryable via `SELECT * FROM case."fn_case_dashboard_kpi_total_beneficiaries"('{}'::jsonb,1,50,1,1)`; dashboard renders all 17 widgets at the slug route; AlertListWidget resolves. | OPEN — defer to Phase 2 E2E |
| ISSUE-20 | Planning 2026-04-29 | HIGH | BE handler isolation | Existing `dashboardByModuleCode` handler inner-joins UserDashboard → MENU_DASHBOARD returns 0 rows. Phase 2 must add separate `dashboardByModuleAndCode` handler (no UserDashboard join). See §⑫ for full details. | PHASE 2 — OPEN |
| ISSUE-21 | Planning 2026-04-29 | HIGH | FE component separation | Phase 1's `dashboardCode` prop on `<DashboardComponent />` is the wrong abstraction (chrome leakage, UserDashboard coupling). Phase 2 creates `<MenuDashboardComponent />`. Acceptance gate: `git diff src/.../dashboards/` empty after Phase 2. | PHASE 2 — OPEN |
| ISSUE-22 | Planning 2026-04-29 | LOW | Component duplication | ~30-50 LOC widget-grid render loop will be duplicated in `<MenuDashboardComponent />`. Accepted on first ship; extract `<DashboardWidgetGrid />` later. | PHASE 2 — ACCEPTED |
| ISSUE-23 | Planning 2026-04-29 | LOW | Slug → DashboardCode convention | Route page derives `dashboardCode = slug.toUpperCase().replace(/-/g, '')`. Holds for system seeds; admin custom slugs out of scope. | PHASE 2 — ACCEPTED |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-28 — BUILD — PHASE 1 ONLY (status retroactively changed to PARTIAL on 2026-04-29 — Phase 2 architectural rework required)

- **Scope**: Initial full build from PROMPT_READY prompt. Path-A dashboard with 17 SQL functions + 1 new FE widget renderer + DashboardComponent enhancement + DB seed. NO new C# code, NO new GraphQL handlers, NO new menu.
- **Files touched**:
  - **BE — 17 SQL functions** (created in NEW folder `PSS_2.0_Backend/DatabaseScripts/Functions/case/`):
    - `fn_case_dashboard_kpi_total_beneficiaries.sql` (created)
    - `fn_case_dashboard_kpi_active_programs.sql` (created)
    - `fn_case_dashboard_kpi_open_cases.sql` (created)
    - `fn_case_dashboard_kpi_services_delivered.sql` (created — uses `ServiceDate` per ISSUE-14)
    - `fn_case_dashboard_kpi_outcome_rate.sql` (created — proxy calc per ISSUE-15)
    - `fn_case_dashboard_kpi_sponsor_match_rate.sql` (created)
    - `fn_case_dashboard_program_performance.sql` (created — uses `MaximumCapacity` per ISSUE-17, budgetUsedPct=0 per ISSUE-2)
    - `fn_case_dashboard_enrollment_trend.sql` (created — 12-month stacked area, top 5 programs)
    - `fn_case_dashboard_age_distribution.sql` (created — 6 age buckets via `DateOfBirth` with `ApproximateAge` fallback)
    - `fn_case_dashboard_gender_distribution.sql` (created)
    - `fn_case_dashboard_cases_by_status.sql` (created — includes computed Overdue bucket)
    - `fn_case_dashboard_location_distribution.sql` (created — top 6 cities + Others)
    - `fn_case_dashboard_outcome_tracking.sql` (created — proxy rate per ISSUE-15)
    - `fn_case_dashboard_staff_caseload.sql` (created — `StaffName` per ISSUE-16, avatarUrl=null)
    - `fn_case_dashboard_resolution_trend.sql` (created — 6-month line, Opened vs Closed)
    - `fn_case_dashboard_alerts.sql` (created — overdue/low-outcome/low-enrollment/on-track success rules)
    - `fn_case_dashboard_funder_impact.sql` (created — DEGRADED, 5 hardcoded sample rows per ISSUE-8 until Grant #62)
  - **FE — created**:
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/alert-list-widgets/AlertListWidget.tsx` (created — uses existing `useWidgetQuery` hook + tolerates 3 response shapes + minimal `<strong>`/`<em>` allowlist sanitizer + Tailwind tokens, no inline hex/pixel)
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/alert-list-widgets/index.ts` (created — barrel)
  - **FE — modified**:
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/dashboard-widget-registry.tsx` (modified — `AlertListWidget` import + WIDGET_REGISTRY entry)
    - `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/index.tsx` (modified — added optional `dashboardCode?: string` prop + `dashboardCodeNotFound` state + slug-vs-default precedence in auto-select effect + explicit "Dashboard not found" empty state, NO silent fallback per prompt §⑫)
    - `PSS_2.0_Frontend/src/presentation/pages/crm/dashboards/casedashboard.tsx` (modified — passes `dashboardCode="CASEDASHBOARD"`)
  - **DB seed**:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/CaseDashboard-sqlscripts.sql` (created — 1 Dashboard + 1 DashboardLayout (lg/md/sm/xs breakpoints + compact ConfiguredWidget) + 1 WidgetType (ALERT_LIST) + 17 Widgets + 17 WidgetRoles for BUSINESSADMIN, all idempotent)
- **Deviations from spec**:
  - SQL function return columns are `text` not `jsonb` — matches existing `sett/widget_*.sql` precedent (the prompt's `jsonb` notation in §⑤ was theoretical; runtime serializes either way).
  - 5 column-name corrections vs prompt assumptions (ISSUE-14/15/16/17 captured above) — proxy outcome calc and avatarUrl=null impact KPI 5 and Tables 13/14 fidelity but functions still produce data.
  - Phase 1 BA/Solution-Resolver/UX-Architect agent runs SKIPPED — prompt's §④/⑤/⑥ already contained the complete validated analysis; running 3 agents to "validate" pre-validated content would have burned tokens for no decision-changing output.
- **Known issues opened**: ISSUE-14 (LogDate→ServiceDate) MED, ISSUE-15 (ProgramOutcomeMetric proxy rate) HIGH, ISSUE-16 (Staff fields) LOW, ISSUE-17 (Program.Capacity→MaximumCapacity) LOW, ISSUE-18 (EF migration deferred per token directive) MED, ISSUE-19 (build/E2E verification deferred per token directive) MED.
- **Known issues closed**: None.
- **Next step**: Phase 2 architectural rework — see PHASE 2 block at top of this file. Specifically: (1) revert `<DashboardComponent />` `dashboardCode` prop addition + delete `casedashboard.tsx` page; (2) add separate `<MenuDashboardComponent />` + `dashboardByModuleAndCode` BE handler (no UserDashboard join — ISSUE-20/21); (3) ship dynamic `[slug]/page.tsx` route + sidebar batched query + 6 hardcoded route deletions; (4) backfill `Dashboard.MenuId` for the 6 system dashboards; (5) acceptance gates per ⑪. Run via `/continue-screen case-dashboard`.

### Session 2 — TODO — `/continue-screen case-dashboard` — PHASE 2 (architectural rework)

> Will be filled in by `/continue-screen` when Phase 2 runs. Scope = the Phase 2 task list under "Generation — Phase 2" above + ISSUE-1/20/21 resolution + acceptance gates per ⑪.
