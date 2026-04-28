---
screen: CaseDashboard
registry_id: 52
module: CRM
status: PENDING
scope: FULL
screen_type: DASHBOARD
dashboard_variant: MENU_DASHBOARD
complexity: High
new_module: NO
planned_date: 2026-04-28
completed_date:
last_session_date:
first_menu_dashboard: true   # ⚠ FIRST MENU_DASHBOARD ever shipped — carries one-time infra (template preamble § A–G)
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/case-management/case-dashboard.html`, 1205 lines)
- [x] Variant chosen: MENU_DASHBOARD (already lives as a CRM_DASHBOARDS sidebar leaf, NOT the module overview)
- [x] Source entities identified — Beneficiary, Case, Program, ProgramOutcomeMetric, BeneficiaryProgramEnrollment, BeneficiaryServiceLog, Staff, Grant
- [x] Widget catalog drafted (16 widget instances across KPI / Chart / Table / HTML)
- [x] react-grid-layout config drafted (xs/sm/md/lg breakpoints — 12-col `lg`)
- [x] DashboardLayout JSON shape drafted (LayoutConfig + ConfiguredWidget — see ⑥)
- [x] Parent menu code: `CRM_DASHBOARDS` ; Slug: `case-dashboard` ; OrderBy=6 (preserves existing position)
- [x] First-time MENU_DASHBOARD infra (template preamble § A–G) folded into BE/FE/seed scope
- [x] File manifest computed (BE: 4 created + 2 modified + 1 migration + 1 SP file; FE: 4 created + 3 modified)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized
- [ ] User Approval received
- [ ] **First-time MENU_DASHBOARD BE infra**:
      • +4 columns on `sett.Dashboards` (MenuId / MenuUrl / OrderBy / IsMenuVisible) + filtered unique index `(CompanyId, MenuUrl) WHERE MenuUrl IS NOT NULL AND IsDeleted = false`
      • EF migration `AddMenuLinkColumnsToDashboard`
      • `LinkDashboardToMenu` / `UnlinkDashboardFromMenu` mutations (validators per template § A)
      • `getMenuVisibleDashboardsByModuleCode(moduleCode)` query
      • Extend `dashboardByModuleCode` projection with new fields + computed `menuName` / `menuParentName` / `effectiveSlug`
- [ ] **First-time MENU_DASHBOARD FE infra**:
      • Create dynamic `[lang]/(core)/[module]/dashboards/[slug]/page.tsx` route — resolves slug → renders `<DashboardComponent slugOverride={slug} />`
      • Update `<DashboardComponent />` to honor `slugOverride` (skip `IsDefault` auto-pick, render "not found" empty state if slug not resolved — DO NOT silently fall back to default)
      • Update `<DashboardHeader />` — add toolbar slot for date-range / dropdown filters / Export / Print + add "Promote to menu" / "Hide from menu" kebab actions (admin-only)
      • Update sidebar menu-tree composer to inject `menuVisibleDashboardsByModuleCode` results as leaves under each `*_DASHBOARDS` parent (batched — 1 call per render covering all parents, NOT N+1)
      • DELETE 6 hardcoded dashboard route pages: `crm/dashboards/contactdashboard/page.tsx`, `donationdashboard/page.tsx`, `communicationdashboard/page.tsx`, `ambassadordashboard/page.tsx`, `volunteerdashboard/page.tsx`, `casedashboard/page.tsx` — pre-flight grep for any imports first
- [ ] **Case-Dashboard-specific BE**:
      • 14 Postgres function files (path A) at `Base.Application/DatabaseScripts/Functions/case/case_dashboard_*.sql` and `Base.Application/DatabaseScripts/Functions/grant/case_dashboard_funder_impact.sql` — each conforming to the FIXED 5-arg / 4-column contract (`p_filter_json jsonb, p_page int, p_page_size int, p_user_id int, p_company_id int` → `TABLE(data jsonb, metadata jsonb, total_count int, filtered_count int)`)
      • Path-B handler `GetCaseDashboardEnrollmentTrend` returning typed series array (12-month stacked area)
      • Path-B handler `GetCaseDashboardResolutionTrend` returning two series (Opened vs Closed, last 6 months)
      • Path-B handler `GetCaseDashboardAlerts` returning typed `[{severity, message, drillTo, drillArgs}]`
      • Schemas + Mappings + `CaseDashboardQueries.cs` registering 3 new GQL fields
- [ ] **Case-Dashboard-specific FE**:
      • DTOs for the 3 typed payloads
      • GQL queries for the 3 typed payloads
      • Register 3 new query names in `dashboard-widget-query-registry.tsx` (`GET_CASE_DASHBOARD_ENROLLMENT_TREND`, `GET_CASE_DASHBOARD_RESOLUTION_TREND`, `GET_CASE_DASHBOARD_ALERTS`)
      • NO new renderer files — all existing `WIDGET_REGISTRY` keys cover the mockup (StatusWidgetType1 / MultiChartWidget / PieChartWidgetType1 / BarChartWidgetType1 / TableWidgetType1 / HtmlWidgetType1)
- [ ] **DB Seed** (`sql-scripts-dyanmic/CaseDashboard-sqlscripts.sql`):
      • Verify Module=CRM, Menu=CASEDASHBOARD already exist (yes — preserve OrderBy=6)
      • Update existing `CASEDASHBOARD` Menu row's `MenuUrl` from `crm/dashboards/casedashboard` → `crm/dashboards/case-dashboard` (kebab slug for dynamic [slug] route)
      • Insert/Upsert `Dashboard` row (`CASEDASHBOARD`)
      • Set Dashboard `MenuId` / `MenuUrl` / `OrderBy=6` / `IsMenuVisible=true`
      • Insert `DashboardLayout` row (LayoutConfig JSON for xs/sm/md/lg + ConfiguredWidget JSON with 16 instances)
      • Insert 16 Widget rows + WidgetRole grants (BUSINESSADMIN + CASE_MANAGER + PROGRAM_DIRECTOR per ④)
      • MenuCapability(READ, ISMENURENDER) + RoleCapability for BUSINESSADMIN/CASE_MANAGER/PROGRAM_DIRECTOR
      • **Backfill seed `Dashboard-MenuBackfill-sqlscripts.sql`**: link the 6 system dashboards (CONTACTDASHBOARD/DONATIONDASHBOARD/COMMUNICATIONDASHBOARD/AMBASSADORDASHBOARD/VOLUNTEERDASHBOARD/CASEDASHBOARD) to their matching Menu rows by `DashboardCode = MenuCode`, kebab-case the MenuUrl, set IsMenuVisible=true. Idempotent.
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes with new migration + 3 query handlers
- [ ] `pnpm dev` — page loads at `/{lang}/crm/dashboards/case-dashboard`
- [ ] All 16 widgets fetch and render with sample data; no broken queries
- [ ] Charts render correctly (3 charts: enrollment trend area / resolution trend line / cases by status stacked bar / 2 donuts / 1 horizontal bar)
- [ ] Date-range / Program / Branch toolbar filters update affected widgets in parallel
- [ ] Drill-down clicks navigate to correct destinations (program-management / case-list / beneficiary-list / grant detail)
- [ ] Empty / loading / error states render per widget
- [ ] WidgetRole gating: signing in as a role without a particular widget grant → that widget hidden / "Restricted" placeholder
- [ ] RoleCapability gating: signing in as a role without `MenuCapability(READ)` on `CASEDASHBOARD` → sidebar leaf hidden, direct URL → "no access"
- [ ] react-grid-layout reflows xs/sm/md/lg correctly (single column on xs, 2-col on sm, 3-col on md+)
- [ ] Slug bookmark `/{lang}/crm/dashboards/case-dashboard` survives reload
- [ ] All 5 OTHER backfilled dashboards (Contact/Donation/Communication/Ambassador/Volunteer) still load via dynamic [slug] route
- [ ] Hardcoded route deletion verified — no 404 for any internal navigation that previously hit `casedashboard/page.tsx` etc.
- [ ] Backfill seed re-runnable (no duplicate-row errors on second execution)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: CaseDashboard
Module: CRM
Schema: NONE (aggregates over `case`, `app`, `grant` schemas)
Group: CaseModels (handlers live in `CaseBusiness/Dashboards/Queries/`; schemas in `CaseSchemas/`)

Dashboard Variant: **MENU_DASHBOARD** — appears as its own sidebar leaf under `CRM → Dashboards`. Excluded from the dropdown switcher on the module-level dashboards page.

Business: This dashboard gives Case Management leadership (program directors, case managers, branch managers, executives) a single-screen view of operational health across beneficiaries, cases, programs, services, outcomes, staff caseloads, and funder reporting. It supports decisions like which programs are below capacity, which staff are overdue on follow-ups, which outcomes are tracking behind target, and which funders need impact reporting. Source modules rolled up: Beneficiary registry (`case.Beneficiaries`), Case workflow (`case.Cases`), Program management (`case.Programs` + `case.ProgramOutcomeMetrics` + `case.BeneficiaryProgramEnrollments`), Service delivery (`case.BeneficiaryServiceLogs`), Staff allocation (`app.Staffs`), and Grants (`grant.Grants`). It earned its own menu slot (vs. living in the dropdown) because it is the daily operational dashboard for the Case Management team — frequently accessed, deep-linked from email reports and weekly reviews, and is role-restricted (case workers / program directors only — Fundraising and Communications staff don't see it).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Dashboards do NOT introduce a new entity. This prompt seeds **two rows** (`sett.Dashboards` + `sett.DashboardLayouts`) plus **16 Widget rows** over **existing source entities**.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | CASEDASHBOARD | Already exists (system-seeded) — UPSERT |
| DashboardName | Case & Program Dashboard | Matches mockup `<h1>` |
| DashboardIcon | solar:clipboard-list-bold | Matches existing CASEDASHBOARD menu icon |
| DashboardColor | #0d9488 | Teal accent from mockup `--cm-accent` |
| ModuleId | (resolve from CRM) | — |
| IsSystem | true | — |
| IsActive | true | — |
| **MenuId** | (FK to existing CASEDASHBOARD Menu) | — |
| **MenuUrl** | `case-dashboard` | kebab-case slug — REPLACES legacy `casedashboard` |
| **OrderBy** | 6 | Preserve existing menu OrderBy |
| **IsMenuVisible** | true | MENU_DASHBOARD variant |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK | — |
| LayoutConfig | `{ "lg": [...16 entries], "md": [...], "sm": [...], "xs": [...] }` | See ⑥ "Grid Layout" |
| ConfiguredWidget | `[ {instanceId, widgetId, title?, customQuery?, customParameter?}, ...×16 ]` | One per widget instance — see ⑥ "Widget Catalog" |

### C. Widget Definitions (`sett.Widgets` + `sett.WidgetTypes`)

`sett.WidgetTypes` — ALL required types ALREADY EXIST in the catalog. NO new WidgetType rows needed:

| WidgetTypeCode | ComponentPath | Used by |
|----------------|---------------|---------|
| STATUS_TYPE_1 | StatusWidgetType1 | 6 KPI cards |
| MULTI_CHART | MultiChartWidget | Enrollment trend (area), Cases by Status (stacked bar), Resolution trend (line) |
| PIE_TYPE_1 | PieChartWidgetType1 | Age donut, Gender donut |
| BAR_TYPE_1 | BarChartWidgetType1 | Beneficiaries by Location (horizontal bar) |
| TABLE_TYPE_1 | TableWidgetType1 | Program Performance, Outcome Tracking, Staff Caseload, Funder Impact |
| HTML_TYPE_1 | HtmlWidgetType1 | Impact Highlights (3 hero tiles), Alerts panel |

`sett.Widgets` (16 rows — full inventory in ⑥):

### D. Source Entities

| Source Entity | Purpose | Aggregate(s) |
|---------------|---------|--------------|
| `case.Beneficiaries` | Total Beneficiaries / age donut / gender donut / location bar / sponsor match | COUNT, COUNT(DISTINCT Sponsor), GROUP BY Age bucket / Gender / City |
| `case.Cases` | Open Cases KPI / Cases-by-Status stacked bar / Resolution Trend / Staff Caseload | COUNT, GROUP BY StatusId, GROUP BY OpenedDate month, GROUP BY AssignedStaffId |
| `case.Programs` | Active Programs KPI / Program Performance table | COUNT WHERE Status='Active', JOIN to enrollment + budget metrics |
| `case.ProgramOutcomeMetrics` | Outcome Achievement Rate / Outcome Tracking table | SUM(Achieved)/SUM(Target) |
| `case.BeneficiaryProgramEnrollments` | Program Performance enrollment % / Enrollment Trend area chart | COUNT GROUP BY ProgramId + month |
| `case.BeneficiaryServiceLogs` | Services Delivered KPI | COUNT WHERE ServiceDate IN range |
| `app.Staffs` | Staff Caseload table | JOIN Cases — assigned, overdue, avg resolution days |
| `grant.Grants` | Funder Impact Summary table | LIST WHERE Stage='Awarded' AND PurposeProgramId IN program scope |

---

## ③ Source Entity & Aggregate Query Resolution

> **Consumer**: Backend Developer + Frontend Developer
> Mixed-path dashboard — most widgets path A (SP-driven via `generateWidgets`), 3 widgets path B (typed payload).

All Path-A entries below use the FIXED 5-arg / 4-column Postgres function contract (see `_DASHBOARD.md` § Path-A Function Contract). Filter args (`fromDate`, `toDate`, `programId`/`programIds`, `branchId`, etc.) are passed via `p_filter_json`, NOT as native parameters. Functions live at `Base.Application/DatabaseScripts/Functions/case/{name}.sql`.

| # | Source Entity | Function (path A) / Handler (path B) | GQL field | Returns | Filter keys (in p_filter_json) | Path |
|---|---------------|--------------------------------------|-----------|---------|----------------|------|
| 1 | Beneficiary | `case.case_dashboard_total_beneficiaries_kpi` | `generateWidgets(widgetId)` | jsonb data + metadata | fromDate, toDate, programId, branchId | A |
| 2 | Program | `case.case_dashboard_active_programs_kpi` | `generateWidgets` | jsonb | branchId | A |
| 3 | Case | `case.case_dashboard_open_cases_kpi` | `generateWidgets` | jsonb (count + MoM delta in metadata) | fromDate, toDate, programId, branchId | A |
| 4 | BeneficiaryServiceLog | `case.case_dashboard_services_delivered_kpi` | `generateWidgets` | jsonb (count + YoY delta in metadata) | fromDate, toDate, programId, branchId | A |
| 5 | ProgramOutcomeMetric | `case.case_dashboard_outcome_achievement_kpi` | `generateWidgets` | jsonb (% + QoQ delta in metadata) | fromDate, toDate, programId | A |
| 6 | Beneficiary | `case.case_dashboard_sponsor_match_kpi` | `generateWidgets` | jsonb (% + matched/total in metadata) | branchId | A |
| 7 | Program + Enrollment + Cases + Outcomes | `case.case_dashboard_program_performance_table` | `generateWidgets` | jsonb table | fromDate, toDate, branchId | A |
| 8 | Beneficiary + Enrollment | `GetCaseDashboardEnrollmentTrend` (Path-B handler) | `getCaseDashboardEnrollmentTrend` | `CaseDashboardEnrollmentTrendDto` (12 monthly points × N program series) | dateFrom, dateTo, programIds[], branchId (gql args, not p_filter_json) | B |
| 9 | Beneficiary | `case.case_dashboard_beneficiaries_by_age` | `generateWidgets` | jsonb (6 buckets) | programIds, branchId | A |
| 10 | Beneficiary | `case.case_dashboard_beneficiaries_by_gender` | `generateWidgets` | jsonb (3 buckets) | programIds, branchId | A |
| 11 | Case | `case.case_dashboard_cases_by_status` | `generateWidgets` | jsonb (rows: statusCode, statusName, count, colorHex) | fromDate, toDate, programId, branchId | A |
| 12 | Beneficiary | `case.case_dashboard_beneficiaries_by_location` | `generateWidgets` | jsonb (top-6 cities + Others bucket) | programIds, branchId | A |
| 13 | ProgramOutcomeMetric | `case.case_dashboard_outcome_tracking_table` | `generateWidgets` | jsonb table | fromDate, toDate, programIds, branchId | A |
| 14 | (HTML widget — 3 hero tiles) | `case.case_dashboard_impact_highlights` | `generateWidgets` | jsonb (3 tile rows: icon, number, label, desc, drillTo) | fromDate, toDate, branchId | A |
| 15 | Staff + Case | `case.case_dashboard_staff_caseload` | `generateWidgets` | jsonb table | branchId, programId | A |
| 16 | Case | `GetCaseDashboardResolutionTrend` (Path-B handler) | `getCaseDashboardResolutionTrend` | `CaseDashboardResolutionTrendDto` (6 monthly points, 2 series) | dateFrom, dateTo, programId, branchId (gql args) | B |
| 17 | Case + Program + Beneficiary | `GetCaseDashboardAlerts` (Path-B handler) | `getCaseDashboardAlerts` | `[CaseDashboardAlertDto]` | dateFrom, dateTo, branchId (gql args) | B |
| 18 | Grant | `grant.case_dashboard_funder_impact` | `generateWidgets` | jsonb table (funder, program, amount, currency, beneficiaries, outcome) | fromDate, toDate, programIds | A |

(Widgets numbered 1–18; the visible grid is 16 instances — Impact Highlights treated as 1, alerts as 1, funder summary as 1.)

**Strategy**: hybrid path-A + path-B. KPI/donut/bar/table widgets that map cleanly to a single SQL query → path A (Postgres function). Multi-series chart payloads (enrollment trend, resolution trend) and structured alert lists → path B (typed C# handler). Composite path C is NOT used — toolbar filters refresh widgets at independent cadences (most widgets cache their results by their args; the 3 typed widgets each have a distinct shape).

**Tenant/role scoping inside Path-A functions**: every function MUST include `(p_company_id IS NULL OR x."CompanyId" = p_company_id)` in WHERE clauses. Role-scoped filters (Branch Manager → branchId pinned) are applied by the FE setting `branchId` in `p_filter_json` based on the current user's role; the function does NOT do role lookup itself.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (filter behavior)

**Date Range Defaults:**
- Default range: **This Year** (current FY: Jan 1 → today)
- Allowed presets: This Year / Last Year / This Quarter / Last Quarter / Custom Range
- Custom range max span: 2 years (bound query cost on `BeneficiaryServiceLog` aggregates)

**Role-Scoped Data Access:**
- `BUSINESSADMIN` — sees everything; no scoping filter applied
- `PROGRAM_DIRECTOR` — sees all programs and all branches; full visibility
- `CASE_MANAGER` — sees only their assigned branch's data; backend filters all aggregates by `Branch.BranchId = currentUser.BranchId`
- Roles without `MenuCapability(CASEDASHBOARD, READ)` → sidebar leaf hidden; direct URL → 403 "no access" page

**Calculation Rules:**
- **Total Beneficiaries Served** = `COUNT(*) FROM Beneficiaries WHERE EnrollmentDate <= @DateTo AND (ExitDate IS NULL OR ExitDate >= @DateFrom)` — beneficiaries active during any portion of the date range
- **Active Programs** = `COUNT(*) FROM Programs WHERE Status='Active'` (subtitle: `7 active, 1 standby` derived as same-table breakdown by Status)
- **Open Cases** = `COUNT(*) FROM Cases WHERE Status NOT IN ('Closed','Cancelled') AND OpenedDate <= @DateTo`. Subtitle delta = `(Open this month - Open last month) / Open last month * 100`
- **Services Delivered YTD** = `COUNT(*) FROM BeneficiaryServiceLogs WHERE ServiceDate BETWEEN @YearStart AND @DateTo`. Subtitle YoY = `(YTD this year - YTD last year) / YTD last year * 100`
- **Outcome Achievement Rate** = `SUM(Achieved) / SUM(Target) * 100 FROM ProgramOutcomeMetrics WHERE FY = current` (rounded down to nearest %)
- **Sponsor Match Rate** = `COUNT(*) WHERE SponsorContactId IS NOT NULL / COUNT(*) FROM Beneficiaries WHERE OrphanStatus = 'Orphan' * 100`
- **Program Performance enrollment %** = `COUNT(BeneficiaryProgramEnrollments) / Program.MaxCapacity` per program
- **Program Performance budget %** = `Program.SpentBudget / Program.AllocatedBudget` (both already on Program entity)
- **Program Status** = derived from `Outcome Rate` (`>=85% → 'On Track'`, `70–84% → 'Needs Attention'`, `<70% → 'Below Target'`, `Status='Standby' → 'Standby'`)
- **Staff Caseload Avg Resolution** = `AVG(ClosedDate - OpenedDate) FROM Cases WHERE AssignedStaffId = @StaffId AND ClosedDate >= @DateFrom`. Days only.
- **Staff Overdue** = `COUNT(*) WHERE FollowUpDate < TODAY AND ClosedDate IS NULL` per staff
- **Cases by Status** = single-row stacked bar — counts grouped by `MasterData.MasterDataValue` for `MasterDataTypeCode='CASESTATUS'`
- **Funder Impact `Beneficiaries`** column — sum across grants whose `PurposeProgramId` matches a program in the linked program(s) of that funder
- **Alerts**: 5 deterministic rules — see § Alerts below

**Multi-Currency Rules:**
- Funder Impact Amount column — display in source currency (`Grant.Currency.Code` + amount). Do NOT auto-convert. ⑫ ISSUE will note this if user wants Company-default-currency display.

**Widget-Level Rules:**
- A widget is RENDERED only if `WidgetRole(WidgetId, currentRoleId, HasAccess=true)`. Otherwise → "Restricted" placeholder per `<DashboardComponent />` defaults.
- Workflow: NONE. Read-only.

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Daily operational dashboard for the Case Management team — already in the sidebar at `CRM → Dashboards → Case Dashboard`, role-restricted, frequently bookmarked, and conceptually distinct from the "module overview + dropdown" STATIC pattern.

**Backend Implementation Path** (mixed):
- [x] **Path A — Stored Procedure** for 13 widgets (KPIs, donuts, bar, tables — clean tabular shape)
- [x] **Path B — Named GraphQL query** for 3 widgets (Enrollment Trend, Resolution Trend, Alerts — multi-series / structured payload)
- [ ] Path C — Composite DTO — NOT used; hybrid SP+typed is closer to actual filter cadence

**Backend Patterns Required (paths B for 3 widgets):**
- [x] Aggregate query handlers — 3 typed handlers
- [x] Tenant scoping (CompanyId from HttpContext) — ALL handlers AND ALL SPs
- [x] Date-range parameterized queries — ALL aggregates
- [x] Role-scoped data filtering — Branch Manager `WHERE BranchId = @BranchId` upfront on all aggregates
- [ ] Materialized view — NO (run-time SP/query latency expected acceptable; revisit if any aggregate exceeds 2s P95)
- [x] Drill-down arg handler — destination screens accept existing `dateFrom`/`dateTo`/`programId`/`statusId`/`assignedStaffId` query params already

**Frontend Patterns Required:**
- [x] Reuse renderers in `dashboard-widget-registry.tsx` — `StatusWidgetType1`, `MultiChartWidget`, `PieChartWidgetType1`, `BarChartWidgetType1`, `TableWidgetType1`, `HtmlWidgetType1`
- [ ] New renderer — NOT needed
- [x] Query registry registration — extend `dashboard-widget-query-registry.tsx` with 3 new entries: `GET_CASE_DASHBOARD_ENROLLMENT_TREND` / `GET_CASE_DASHBOARD_RESOLUTION_TREND` / `GET_CASE_DASHBOARD_ALERTS`
- [x] Date-range picker / Program / Branch dropdowns / drill-down handlers / skeletons — wired via the new toolbar slot on `<DashboardHeader />`
- [x] MENU_DASHBOARD-only — dynamic `[slug]/page.tsx` route (created as part of this prompt's first-time infra)

---

## ⑥ UI/UX Blueprint

### Page Chrome (MENU_DASHBOARD with toolbar overrides)

Header row (NOT lean — mockup demands a richer toolbar):
- LEFT: dashboard icon + name "Case & Program Dashboard" + subtitle "Impact metrics, program performance, and beneficiary outcomes"
- RIGHT (toolbar overrides — wired into `<DashboardHeader />` toolbar slot):
  - **Date Range** dropdown (5 presets: This Year/Last Year/This Quarter/Last Quarter/Custom Range)
  - **Program** dropdown (All Programs + 8 program names — multi-select)
  - **Branch** dropdown (All Branches + 5+ branches — single-select)
  - **Export Impact Report** button — SERVICE_PLACEHOLDER (toast; PDF service deferred)
  - **Print Dashboard** button — `window.print()` (browser-native; no SERVICE_PLACEHOLDER)

Body: pure widget grid via `react-grid-layout`, 9 logical sections in document order.

### Grid Layout (react-grid-layout config)

| Breakpoint | min width | columns |
|------------|-----------|---------|
| xs | 0 | 4 |
| sm | 640 | 6 |
| md | 768 | 8 |
| lg | 1024 | 12 |
| xl | 1280 | 12 |

**Widget placement (lg breakpoint — 12 cols):**

| i (instanceId) | Widget | x | y | w | h | minW | minH | Notes |
|----------------|--------|---|---|---|---|------|------|-------|
| kpi-total-beneficiaries | KPI: Total Beneficiaries Served | 0 | 0 | 4 | 2 | 3 | 2 | KPI row 1, col 1 |
| kpi-active-programs | KPI: Active Programs | 4 | 0 | 4 | 2 | 3 | 2 | KPI row 1, col 2 |
| kpi-open-cases | KPI: Open Cases | 8 | 0 | 4 | 2 | 3 | 2 | KPI row 1, col 3 |
| kpi-services-delivered | KPI: Services Delivered YTD | 0 | 2 | 4 | 2 | 3 | 2 | KPI row 2, col 1 |
| kpi-outcome-rate | KPI: Outcome Achievement Rate | 4 | 2 | 4 | 2 | 3 | 2 | KPI row 2, col 2 |
| kpi-sponsor-match | KPI: Sponsor Match Rate | 8 | 2 | 4 | 2 | 3 | 2 | KPI row 2, col 3 |
| table-program-performance | Program Performance Overview (8 cols) | 0 | 4 | 12 | 5 | 8 | 4 | Full-width |
| chart-enrollment-trend | Beneficiary Enrollment Trend (stacked area) | 0 | 9 | 12 | 4 | 8 | 3 | Full-width |
| chart-age-donut | Beneficiaries by Age | 0 | 13 | 6 | 4 | 4 | 3 | Half-width |
| chart-gender-donut | Beneficiaries by Gender | 6 | 13 | 6 | 4 | 4 | 3 | Half-width |
| chart-cases-by-status | Cases by Status (stacked bar) | 0 | 17 | 6 | 3 | 4 | 2 | Half-width, low |
| chart-location-bars | Beneficiaries by Location | 6 | 17 | 6 | 3 | 4 | 2 | Half-width |
| table-outcome-tracking | Outcome Tracking | 0 | 20 | 12 | 4 | 8 | 3 | Full-width |
| html-impact-highlights | Impact Highlights (3 tiles) | 0 | 24 | 12 | 3 | 8 | 2 | Full-width |
| table-staff-caseload | Staff Caseload Distribution | 0 | 27 | 7 | 4 | 5 | 3 | 7-col |
| chart-resolution-trend | Case Resolution Trend (line) | 7 | 27 | 5 | 4 | 4 | 3 | 5-col |
| html-alerts | Alerts & Actions | 0 | 31 | 12 | 3 | 8 | 2 | Full-width |
| table-funder-impact | Funder Impact Summary (collapsible) | 0 | 34 | 12 | 4 | 8 | 3 | Full-width |

**Responsive notes**:
- xs (4 cols): every widget becomes `w=4` (full row); rows stack vertically.
- sm (6 cols): KPIs become 2-up (`w=3`), donuts stack, tables full-width.
- md (8 cols): KPIs 3-up (`w=2.66 → snap to 3`), tables full-width, donuts side-by-side `w=4` each.

### Widget Catalog (16 instances)

> See ③ for the corresponding handler/SP per widget. Drill-down destinations are real existing routes.

| # | InstanceId | Title | WidgetType.ComponentPath | Path | Data Source | Filters Honored | Drill-Down |
|---|-----------|-------|--------------------------|------|-------------|------------------|-----------|
| 1 | kpi-total-beneficiaries | Total Beneficiaries Served | StatusWidgetType1 | A | case.case_dashboard_total_beneficiaries_kpi | dateRange, programIds, branchId | /crm/casemanagement/beneficiarylist |
| 2 | kpi-active-programs | Active Programs | StatusWidgetType1 | A | case.case_dashboard_active_programs_kpi | branchId | /crm/casemanagement/programmanagement |
| 3 | kpi-open-cases | Open Cases | StatusWidgetType1 | A | case.case_dashboard_open_cases_kpi | dateRange, programIds, branchId | /crm/casemanagement/caselist?status=open |
| 4 | kpi-services-delivered | Services Delivered (YTD) | StatusWidgetType1 | A | case.case_dashboard_services_delivered_kpi | dateRange, programIds, branchId | — |
| 5 | kpi-outcome-rate | Outcome Achievement Rate | StatusWidgetType1 | A | case.case_dashboard_outcome_achievement_kpi | dateRange, programIds | — |
| 6 | kpi-sponsor-match | Sponsor Match Rate | StatusWidgetType1 | A | case.case_dashboard_sponsor_match_kpi | branchId | /crm/casemanagement/beneficiarylist?orphanStatus=orphan&sponsorMatched=false |
| 7 | table-program-performance | Program Performance Overview | TableWidgetType1 | A | case.case_dashboard_program_performance_table | dateRange, branchId | /crm/casemanagement/programmanagement?id={programId} |
| 8 | chart-enrollment-trend | Beneficiary Enrollment Trend | MultiChartWidget (area, stacked) | B | GET_CASE_DASHBOARD_ENROLLMENT_TREND | dateRange, programIds, branchId | — |
| 9 | chart-age-donut | Beneficiaries by Age Group | PieChartWidgetType1 | A | case.case_dashboard_beneficiaries_by_age | programIds, branchId | /crm/casemanagement/beneficiarylist?ageBucket={bucket} |
| 10 | chart-gender-donut | Beneficiaries by Gender | PieChartWidgetType1 | A | case.case_dashboard_beneficiaries_by_gender | programIds, branchId | /crm/casemanagement/beneficiarylist?genderId={genderId} |
| 11 | chart-cases-by-status | Cases by Status | MultiChartWidget (stacked bar, single row) | A | case.case_dashboard_cases_by_status | dateRange, programIds, branchId | /crm/casemanagement/caselist?statusId={statusId} |
| 12 | chart-location-bars | Beneficiaries by Location | BarChartWidgetType1 (horizontal) | A | case.case_dashboard_beneficiaries_by_location | programIds, branchId | /crm/casemanagement/beneficiarylist?cityId={cityId} |
| 13 | table-outcome-tracking | Outcome Tracking | TableWidgetType1 | A | case.case_dashboard_outcome_tracking_table | dateRange, programIds, branchId | — |
| 14 | html-impact-highlights | Impact Highlights | HtmlWidgetType1 | A | case.case_dashboard_impact_highlights (3 rows: children/wells/women — values + "View Stories" link) | dateRange, branchId | /crm/casemanagement/beneficiarylist?orphanStatus=orphan / programmanagement?categoryCode=CLEANWATER / beneficiarylist?programCode=VOCATIONAL |
| 15 | table-staff-caseload | Staff Caseload Distribution | TableWidgetType1 | A | case.case_dashboard_staff_caseload | branchId, programIds | /crm/casemanagement/caselist?assignedStaffId={staffId} |
| 16 | chart-resolution-trend | Case Resolution Trend | MultiChartWidget (line, 2 series) | B | GET_CASE_DASHBOARD_RESOLUTION_TREND | dateRange, programIds, branchId | — |
| 17 | html-alerts | Alerts & Actions | HtmlWidgetType1 | B | GET_CASE_DASHBOARD_ALERTS (typed `[{severity, message, drillTo, drillArgs}]`) | dateRange, branchId | per-row drill |
| 18 | table-funder-impact | Funder Impact Summary | TableWidgetType1 | A | grant.case_dashboard_funder_impact | dateRange, programIds | /crm/grant/grant?id={grantId} |

(18 logical entries above; 16 grid instances after combining "Impact Highlights" and "Alerts" each as one widget instance; note row #14 and #17 each render 3-N items inside a single HtmlWidgetType1 frame.)

### KPI Cards (detail per card — feeds Widget seed)

| # | Title | Value Source | Format | Subtitle | Trend? | Color Cue |
|---|-------|--------------|--------|----------|--------|-----------|
| 1 | Total Beneficiaries Served | totalBeneficiaries | int with thousand-sep | "↑ {newThisYear} new this year" | none | teal |
| 2 | Active Programs | activeProgramsCount | int | "{active} active, {standby} standby" | none | blue |
| 3 | Open Cases | openCasesCount | int | "↓ {pctDeltaMoM}% vs last month (improving)" / "↑ ...(needs attention)" | sign-flipped color | green/red |
| 4 | Services Delivered (YTD) | servicesYtd | int with thousand-sep | "↑ {pctYoY}% vs same period last year" | up-arrow | orange |
| 5 | Outcome Achievement Rate | outcomeRatePct | "{n}%" | "↑ {pctDeltaQoQ}% vs last quarter" | up-arrow | purple |
| 6 | Sponsor Match Rate | sponsorMatchPct | "{n}%" | "{matched} of {total} orphans individually sponsored" | none | cyan |

### Charts (detail per chart)

| # | Title | Type | X | Y | Source | Filters Honored | Empty/Tooltip |
|---|-------|------|---|---|--------|------------------|---------------|
| 8 | Beneficiary Enrollment Trend | stacked area | Month (last 12) | Active beneficiaries | enrollmentTrend (path B) — array of `{month, programCode, count}` | dateRange, programIds, branchId | "No enrollments in selected period" |
| 11 | Cases by Status | single horizontal stacked bar | — (one row) | count per status | array of `{statusCode, statusName, count, colorHex}` | dateRange, programIds, branchId | "No cases in range" |
| 12 | Beneficiaries by Location | horizontal bars | count | City label | array of `{cityName, count}` (top 6 + Others bucket) | programIds, branchId | "No beneficiaries in range" |
| 16 | Case Resolution Trend | line (2 series) | Month (last 6) | count opened, count closed | resolutionTrend (path B) — `{month, opened, closed}` | dateRange, programIds, branchId | "No resolutions yet" |

### Donuts (charts 9 & 10)

| # | Title | Center | Slices |
|---|-------|--------|--------|
| 9 | Beneficiaries by Age Group | total count | 0-5 / 6-12 / 13-17 / 18-25 / 26-40 / 40+ — derived from `Beneficiary.DateOfBirth` (or `ApproximateAge` fallback) — each slice has count + % |
| 10 | Beneficiaries by Gender | total count | per `MasterDataTypeCode='GENDER'` rows — count + % |

### Tables (detail per table)

| # | Title | Columns | Row interaction | Notes |
|---|-------|---------|-----------------|-------|
| 7 | Program Performance | Program (icon+name), Beneficiaries (count or "{n} communities"/"{n} families"), Capacity (or "On-demand"), Enrollment (% bar), Cases Open (count), Outcome Rate (color-dot+%), Budget Used (%), Status (colored badge) | Click row → program detail | Status badge derived per ④ rules |
| 13 | Outcome Tracking | Outcome name, Target, Achieved, Rate (% bar with green/yellow/red threshold per ④), Trend (↑/↓/→ arrow + delta) | none | Color-driven rate bar |
| 15 | Staff Caseload | Staff Name (icon+name), Open Cases, Beneficiaries, Avg Resolution (days), Overdue (count w/ severity color: 0=neutral, 1-3=warning, 4+=danger) | Click row → caseload | — |
| 18 | Funder Impact | Funder Name, Program, Amount (Currency.Code + value), Beneficiaries, Key Outcome (free text from `Grant.ExpectedOutcomes` truncated) | Click row → grant detail | Collapsible — collapsed by default |

### Impact Highlights (HTML widget #14)

3 hero tiles rendered inside a single HtmlWidgetType1 frame. Each tile: icon + big number + label + description + "View ..." link.

| Tile | Icon | Number Source | Label | Description | Link Destination |
|------|------|---------------|-------|-------------|------------------|
| 1 | solar:scarecrow-bold (child) | sponsoredOrphansCount | "Children" | "under orphan sponsorship" | /crm/casemanagement/beneficiarylist?orphanStatus=orphan |
| 2 | solar:water-drop-bold | wellsConstructedCount | "Wells Constructed" | "serving {n} communities" | /crm/casemanagement/programmanagement?categoryCode=CLEANWATER |
| 3 | solar:graduate-bold | womenEmployedCount | "Women Employed" | "gained employment after training" | /crm/casemanagement/beneficiarylist?programCode=VOCATIONAL&employmentStatus=employed |

### Alerts (HTML widget #17 — 5 rules)

Alerts are a structured payload from `GET_CASE_DASHBOARD_ALERTS` (path B). The handler runs 5 deterministic rules and returns 0..5 `AlertDto` entries. UI renders each as `{severity-color}-banner + icon + message + action-link`.

| Rule | Severity | Message template | Drill-To |
|------|----------|------------------|----------|
| Overdue follow-ups | warning | "**{n} overdue follow-ups** — Oldest: {oldestCaseCode} ({daysOverdue} days)" | /crm/casemanagement/caselist?overdueOnly=true |
| Outcome below target (per program) | warning | "**{programName}: {outcomeName} below target** ({achievedPct}% vs {targetPct}% target)" | /crm/casemanagement/programmanagement?id={programId} |
| Waitlist for sponsorship | info | "**{n} beneficiaries on waitlist** for Orphan Sponsorship — need {n} more sponsors" | /crm/casemanagement/beneficiarylist?orphanStatus=orphan&sponsorMatched=false |
| Below-capacity program | info | "**{programName} below capacity** — {enrolled} of {capacity} ({pct}%)" | /crm/casemanagement/programmanagement?id={programId} |
| On-track milestone | success | "**{programName} on track** — {achieved} of {target} {unit} completed ({pct}%)" | /crm/casemanagement/programmanagement?id={programId} |

(Rules trigger when their threshold is crossed; suppressed when not. Empty alerts payload → "All systems healthy" muted message.)

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Date Range | preset dropdown + custom range | This Year | Widgets 1, 3, 4, 5, 7, 8, 11, 13, 14, 16, 17, 18 | Custom max 2 yr |
| Program | multi-select (ApiSelectV2 — Program GQL list) | All | Widgets 1, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 16, 17, 18 (NOT 2, 6, 14, 15) | Includes inactive programs in dropdown but tags them "(Inactive)" |
| Branch | single-select (Branch GQL list) | "All Branches" for admin/director, user's branch for Case Manager | All widgets | role-scoped default |

### Drill-Down / Navigation Map

| From Widget / Element | Click On | Navigates To | Prefill |
|-----------------------|----------|--------------|---------|
| KPI Total Beneficiaries | Card click | /crm/casemanagement/beneficiarylist | dateFrom, dateTo, programId, branchId |
| KPI Open Cases | Card click | /crm/casemanagement/caselist | status=open + dateFrom, dateTo, programId, branchId |
| KPI Sponsor Match | Card click | /crm/casemanagement/beneficiarylist | orphanStatus=orphan&sponsorMatched=false |
| Program Performance row | Row click | /crm/casemanagement/programmanagement | id={programId} |
| Age donut slice | Slice click | /crm/casemanagement/beneficiarylist | ageBucket=0-5/6-12/... |
| Gender donut slice | Slice click | /crm/casemanagement/beneficiarylist | genderId={id} |
| Cases by Status segment | Segment click | /crm/casemanagement/caselist | statusId={id} |
| Location bar | Bar click | /crm/casemanagement/beneficiarylist | cityId={id} |
| Staff Caseload row | Row click | /crm/casemanagement/caselist | assignedStaffId={staffId} |
| Impact Highlight tile link | Click "View ..." | per § Impact Highlights table | per tile |
| Alert action link | Click action | per § Alerts table | per rule |
| Funder Impact row | Row click | /crm/grant/grant | id={grantId} |
| Toolbar Export | Click button | (NO navigation — toast SERVICE_PLACEHOLDER) | — |
| Toolbar Print | Click button | (no navigation — `window.print()`) | — |
| Funder section "Generate Full Impact Report" | Click button | /reports/html-report-viewer SERVICE_PLACEHOLDER (toast) | — |

### User Interaction Flow

1. **Initial load**: user clicks `CRM → Dashboards → Case Dashboard` → URL `/{lang}/crm/dashboards/case-dashboard` → dynamic `[slug]/page.tsx` resolves → `<DashboardComponent slugOverride="case-dashboard" />` fetches Dashboard by slug → renders 16-widget grid → all widgets parallel-fetch with default filters (This Year / All Programs / user's branch).
2. **Filter change** (date range / program / branch): widgets honoring that filter refetch in parallel; widgets not honoring it stay cached. (Apollo cache key includes the parameter set.)
3. **Drill-down click**: navigate per Drill-Down Map → destination receives prefill args via query string. Browser back returns to dashboard with filters preserved (URL search params persist for at least date range; program+branch filters persist via context, not URL).
4. **Empty / loading / error states**: each widget renders its own skeleton during fetch (KPIs `h-24`, charts `h-64`, tables row-shape, HTML widgets `h-full`). Error → red mini banner + Retry. Empty → muted icon + per-widget message ("No data in selected range").
5. **Toolbar actions**: Export → toast "Report queued — will email when ready" (PDF service deferred). Print → invokes `window.print()` directly. "Generate Full Impact Report" at bottom → toast (deferred).
6. **Promote/Demote** (admin only — chrome kebab): Promote-to-menu visible only when `IsSystem=false`; Hide-from-menu visible when `IsMenuVisible=true`. NOT relevant to this dashboard since it's IsSystem=true; chrome only applies to user-created dashboards.

---

## ⑦ Substitution Guide

**Canonical Reference**: This is the FIRST DASHBOARD prompt to ship. It establishes the canon for both **DASHBOARD shape** and **MENU_DASHBOARD first-time infra**. Subsequent dashboards (`#17 Fundraising`, `#38 Email Analytics`, `#47 Event Analytics`, `#57 Volunteer`, `#69 Ambassador`, `#98 Donor Retention`) substitute against this prompt.

| Canonical | → This Dashboard | Context |
|-----------|------------------|---------|
| {EntityName} | CaseDashboard | Class/code prefix |
| {ENTITYUPPER} | CASEDASHBOARD | DashboardCode + GridCode (existing) |
| {kebab-slug} | case-dashboard | MenuUrl |
| /{module}/dashboards/{slug} | /crm/dashboards/case-dashboard | route path |
| {Group} | Case | Mappings + Schemas + Business folder name |
| {schema} | case (mostly), grant (funder section) | source schemas |
| {MODULECODE} | CRM | parent module code |
| {MODULECODE}_DASHBOARDS | CRM_DASHBOARDS | ParentMenu (existing) |

---

## ⑧ File Manifest

### Backend Files

**One-time MENU_DASHBOARD infrastructure:**

| # | File | Path | Required When |
|---|------|------|---------------|
| 1 | Dashboard entity update — +4 columns | `Base.Domain/Models/SettingModels/Dashboard.cs` | first MENU_DASHBOARD |
| 2 | DashboardConfiguration update — index + nav | `Base.Infrastructure/Data/Configurations/SettingConfigurations/DashboardConfiguration.cs` | first MENU_DASHBOARD |
| 3 | EF migration | `Base.Infrastructure/Migrations/{ts}_AddMenuLinkColumnsToDashboard.cs` | first MENU_DASHBOARD |
| 4 | DashboardSchemas update — +4 fields + computed `menuName` / `menuParentName` / `effectiveSlug` | `Base.Application/Schemas/SettingSchemas/DashboardSchemas.cs` | first MENU_DASHBOARD |
| 5 | LinkDashboardToMenu command | `Base.Application/Business/SettingBusiness/Dashboards/Commands/LinkDashboardToMenu.cs` | first MENU_DASHBOARD |
| 6 | UnlinkDashboardFromMenu command | `Base.Application/Business/SettingBusiness/Dashboards/Commands/UnlinkDashboardFromMenu.cs` | first MENU_DASHBOARD |
| 7 | GetMenuVisibleDashboardsByModuleCode query | `Base.Application/Business/SettingBusiness/Dashboards/Queries/GetMenuVisibleDashboardsByModuleCode.cs` | first MENU_DASHBOARD |
| 8 | DashboardMutations endpoint update — +2 mutations | `Base.API/EndPoints/Setting/Mutations/DashboardMutations.cs` | first MENU_DASHBOARD |
| 9 | DashboardQueries endpoint update — +1 query | `Base.API/EndPoints/Setting/Queries/DashboardQueries.cs` | first MENU_DASHBOARD |

**Case-Dashboard-specific (path B handlers):**

| # | File | Path |
|---|------|------|
| 10 | CaseDashboardSchemas.cs (3 typed DTOs: EnrollmentTrend, ResolutionTrend, Alert) | `Base.Application/Schemas/CaseSchemas/CaseDashboardSchemas.cs` |
| 11 | GetCaseDashboardEnrollmentTrend.cs | `Base.Application/Business/CaseBusiness/Dashboards/Queries/GetCaseDashboardEnrollmentTrend.cs` |
| 12 | GetCaseDashboardResolutionTrend.cs | `Base.Application/Business/CaseBusiness/Dashboards/Queries/GetCaseDashboardResolutionTrend.cs` |
| 13 | GetCaseDashboardAlerts.cs | `Base.Application/Business/CaseBusiness/Dashboards/Queries/GetCaseDashboardAlerts.cs` |
| 14 | CaseDashboardQueries.cs (register 3 GQL fields) | `Base.API/EndPoints/Case/Queries/CaseDashboardQueries.cs` |
| 15 | CaseMappings.cs update (TypeAdapterConfig for the 3 DTOs) | `Base.Application/Mappings/CaseMappings.cs` |

**SQL deliverable (path A widgets — 14 Postgres functions, one file each):**

| # | File | Path |
|---|------|------|
| 16 | 13 functions in `case` schema + 1 in `grant` schema. Names per ③ table, snake_case. One `.sql` file per function — match the `rep/donation_summary_report.sql` precedent | `Base.Application/DatabaseScripts/Functions/case/case_dashboard_*.sql` (×13) and `Base.Application/DatabaseScripts/Functions/grant/case_dashboard_funder_impact.sql` (×1) |

### Backend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | DashboardConfiguration.cs | filtered unique index + Menu nav prop |
| 2 | DashboardSchemas.cs | +4 fields on response DTO + 3 computed fields |
| 3 | DashboardMutations.cs | register 2 mutations |
| 4 | DashboardQueries.cs | register 1 query |
| 5 | CaseDashboardQueries.cs | new file — register 3 GQL fields |
| 6 | CaseMappings.cs | TypeAdapterConfig × 3 |

### Frontend Files

**One-time MENU_DASHBOARD infrastructure:**

| # | File | Path |
|---|------|------|
| 1 | Dynamic [slug] route page | `src/app/[lang]/(core)/[module]/dashboards/[slug]/page.tsx` |
| 2 | DashboardComponent update — honor `slugOverride` prop | `src/presentation/components/custom-components/dashboards/index.tsx` |
| 3 | DashboardHeader update — toolbar slot + Promote/Hide kebab | `src/presentation/components/custom-components/dashboards/dashboard-header.tsx` |
| 4 | Sidebar menu-tree composer update — inject menuVisibleDashboardsByModuleCode (batched) | `src/presentation/components/menus/sidebar-menu-tree.tsx` (or actual file — grep first) |
| 5 | DELETE 6 hardcoded dashboard pages: `crm/dashboards/contactdashboard/page.tsx`, `donationdashboard/page.tsx`, `communicationdashboard/page.tsx`, `ambassadordashboard/page.tsx`, `volunteerdashboard/page.tsx`, `casedashboard/page.tsx` | `src/app/[lang]/(core)/crm/dashboards/{name}/page.tsx` |

**Case-Dashboard-specific:**

| # | File | Path |
|---|------|------|
| 6 | CaseDashboardDto.ts (3 DTOs) | `src/domain/entities/case-service/CaseDashboardDto.ts` |
| 7 | CaseDashboardQuery.ts (3 gql docs) | `src/infrastructure/gql-queries/case-queries/CaseDashboardQuery.ts` |
| 8 | dashboard-widget-query-registry.tsx update — register 3 names | `src/presentation/components/custom-components/dashboards/dashboard-widget-query-registry.tsx` |
| 9 | gql-queries barrel re-export the 3 new docs | `src/infrastructure/gql-queries/index.ts` |

**No new renderer files** — all 6 ComponentPaths used (`StatusWidgetType1` / `MultiChartWidget` / `PieChartWidgetType1` / `BarChartWidgetType1` / `TableWidgetType1` / `HtmlWidgetType1`) already exist in `dashboard-widget-registry.tsx`.

### Frontend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | dashboard-widget-query-registry.tsx | +3 entries |
| 2 | gql-queries index.ts | re-export 3 new gql docs |
| 3 | sidebar / menu config | NONE — auto-injected from BE seed |

### DB Seed (`sql-scripts-dyanmic/CaseDashboard-sqlscripts.sql`)

| # | Item | Notes |
|---|------|-------|
| 1 | Verify `Module=CRM`, `Menu=CRM_DASHBOARDS`, `Menu=CASEDASHBOARD` exist | Already seeded — assert NOT EXISTS guards still work |
| 2 | UPDATE `auth.Menus` SET `MenuUrl='crm/dashboards/case-dashboard'` WHERE `MenuCode='CASEDASHBOARD'` | kebab slug switch |
| 3 | INSERT/UPSERT `sett.Dashboards` `CASEDASHBOARD` row (DashboardCode, DashboardName, DashboardIcon='solar:clipboard-list-bold', DashboardColor='#0d9488', ModuleId, IsSystem=true, IsActive=true, IsMenuVisible=true, OrderBy=6) | core row |
| 4 | UPDATE Dashboard SET `MenuId=(SELECT MenuId FROM auth.Menus WHERE MenuCode='CASEDASHBOARD')`, `MenuUrl='case-dashboard'` WHERE `DashboardCode='CASEDASHBOARD'` | link to menu |
| 5 | INSERT 16 `sett.Widgets` rows (with DefaultQuery / DefaultParameters / StoredProcedureName per ③ ⑥) | one per instance |
| 6 | INSERT `sett.DashboardLayouts` row — LayoutConfig JSON for xs/sm/md/lg + ConfiguredWidget JSON listing 16 instances with their widgetIds | full layout |
| 7 | INSERT `auth.WidgetRoles` grants — BUSINESSADMIN (all 16) + CASE_MANAGER (all 16) + PROGRAM_DIRECTOR (all 16). Other roles: NONE for now | role-scoped |
| 8 | INSERT `auth.MenuCapabilities` for CASEDASHBOARD — READ + ISMENURENDER | sidebar visible |
| 9 | INSERT `auth.RoleCapabilities` — BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR all granted READ; FUNDRAISING_DIRECTOR / COMMUNICATIONS denied | role gate |

### Backfill Seed (`sql-scripts-dyanmic/Dashboard-MenuBackfill-sqlscripts.sql`)

ONE-TIME: `UPDATE sett.Dashboards SET MenuId = m.MenuId, MenuUrl = LOWER(REPLACE(d.DashboardCode, '_', '-')), IsMenuVisible = true FROM auth.Menus m WHERE d.IsSystem = true AND m.MenuCode = d.DashboardCode AND d.MenuId IS NULL`. Idempotent. Affects Contact / Donation / Communication / Ambassador / Volunteer / Case Dashboard rows. Pre-flight assert: every row resolved (no `MenuId IS NULL` remaining for IsSystem dashboards) — abort with explicit error if any remain.

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

MenuName: Case Dashboard
MenuCode: CASEDASHBOARD
ParentMenu: CRM_DASHBOARDS
Module: CRM
MenuUrl: crm/dashboards/case-dashboard
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT
  CASE_MANAGER: READ
  PROGRAM_DIRECTOR: READ, EXPORT

GridFormSchema: SKIP
GridCode: CASEDASHBOARD

# Dashboard-specific seed inputs
DashboardCode: CASEDASHBOARD
DashboardName: Case & Program Dashboard
DashboardIcon: solar:clipboard-list-bold
DashboardColor: #0d9488
IsSystem: true
IsMenuVisible: true
OrderBy: 6

WidgetGrants:
  - kpi-total-beneficiaries: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - kpi-active-programs: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - kpi-open-cases: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - kpi-services-delivered: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - kpi-outcome-rate: BUSINESSADMIN, PROGRAM_DIRECTOR
  - kpi-sponsor-match: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - table-program-performance: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - chart-enrollment-trend: BUSINESSADMIN, PROGRAM_DIRECTOR
  - chart-age-donut: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - chart-gender-donut: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - chart-cases-by-status: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - chart-location-bars: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - table-outcome-tracking: BUSINESSADMIN, PROGRAM_DIRECTOR
  - html-impact-highlights: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - table-staff-caseload: BUSINESSADMIN, CASE_MANAGER (own branch only via role scope), PROGRAM_DIRECTOR
  - chart-resolution-trend: BUSINESSADMIN, PROGRAM_DIRECTOR
  - html-alerts: BUSINESSADMIN, CASE_MANAGER, PROGRAM_DIRECTOR
  - table-funder-impact: BUSINESSADMIN, PROGRAM_DIRECTOR
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Queries (path B — 3 new typed):**

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| getCaseDashboardEnrollmentTrend | CaseDashboardEnrollmentTrendDto | dateFrom, dateTo, programIds, branchId | typed payload — feeds chart-enrollment-trend |
| getCaseDashboardResolutionTrend | CaseDashboardResolutionTrendDto | dateFrom, dateTo, programId, branchId | typed payload — feeds chart-resolution-trend |
| getCaseDashboardAlerts | [CaseDashboardAlertDto] | dateFrom, dateTo, branchId | typed list — feeds html-alerts |

**Generic widget query (path A — already exists):**

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| generateWidgets | GenerateWidgetResultDto (key/value rows + metadata) | widgetId, parameters (JSON string), pageIndex, pageSize, advancedFilter, searchTerm | runs `Widget.StoredProcedureName` for the given widgetId — used by 13 path-A widgets |

**MENU_DASHBOARD infra queries (one-time):**

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| dashboardByModuleCode (existing — extended) | [DashboardDto with +4 new fields + 3 computed] | moduleCode | dropdown source for STATIC view |
| menuVisibleDashboardsByModuleCode | [DashboardDto] | moduleCode | sidebar batch-injection |
| linkDashboardToMenu | DashboardResponse | dashboardId, menuId, menuUrl, orderBy | admin Promote action |
| unlinkDashboardFromMenu | DashboardResponse | dashboardId | admin Hide action |

**Typed DTOs (path B):**

```ts
// CaseDashboardDto.ts — FE shape; mirrors CaseDashboardSchemas.cs
export interface CaseDashboardEnrollmentTrendDto {
  monthlyPoints: { month: string; programCode: string; programName: string; count: number; }[]; // 12 months × N programs
}
export interface CaseDashboardResolutionTrendDto {
  monthlyPoints: { month: string; openedCount: number; closedCount: number; }[]; // 6 months
}
export interface CaseDashboardAlertDto {
  severity: "warning" | "info" | "success";
  iconCode: string;        // phosphor icon
  message: string;         // pre-formatted with bold tags via {strong} markers
  actionLabel: string;
  drillTo: string;         // e.g., "/crm/casemanagement/caselist"
  drillArgs: Record<string, string>;
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors. New migration applies cleanly.
- [ ] `pnpm dev` — page loads at `/{lang}/crm/dashboards/case-dashboard`
- [ ] OTHER 5 backfilled dashboards still load via dynamic `[slug]/page.tsx` (Contact/Donation/Communication/Ambassador/Volunteer)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Dashboard loads with default `This Year` + `All Programs` + user's branch → all 16 widgets render with sample data
- [ ] All 6 KPIs show correct value formatted per spec (currency-free; int with thousand-sep / %)
- [ ] All 3 charts (enrollment area, resolution line, cases-by-status stacked bar) render with axes + legend + tooltip
- [ ] Both donuts render with 6 / 3 slices and centered totals
- [ ] Horizontal location bar renders top 6 + Others bucket
- [ ] All 4 tables render rows + click-to-drill where mapped
- [ ] Impact Highlights renders 3 hero tiles with click-through links
- [ ] Alerts panel renders 0..5 alerts depending on data; "Healthy" message when empty
- [ ] Funder Impact table renders, expand/collapse toggles correctly
- [ ] Date range change refetches all date-honoring widgets in parallel; non-honoring widgets stay cached
- [ ] Program filter change refetches affected widgets only
- [ ] Branch filter change refetches all widgets (every widget honors branch except where explicitly noted)
- [ ] Drill-down clicks land on correct destination with correct prefill args (verify 5 destinations)
- [ ] Empty state per widget when no data in selected range
- [ ] Loading skeleton per widget during fetch (shape matches widget shape)
- [ ] Error state per widget when query fails (red mini banner + Retry — manual: kill dotnet between dropdown changes)
- [ ] Role-based data scoping: sign in as CASE_MANAGER (Branch=Mumbai) → only Mumbai data appears across all widgets
- [ ] Role-based widget visibility: sign in as a role lacking grants on Outcome Tracking → that widget hidden / "Restricted" placeholder
- [ ] react-grid-layout reflows correctly across xs/sm/md/lg/xl breakpoints (DevTools Responsive)
- [ ] MENU_DASHBOARD: sidebar leaf renders under CRM_DASHBOARDS, OrderBy=6
- [ ] MENU_DASHBOARD: sign in as `FUNDRAISING_DIRECTOR` → leaf hidden + direct URL → 403
- [ ] Toolbar Export → toast SERVICE_PLACEHOLDER message
- [ ] Toolbar Print → opens browser print dialog
- [ ] "Generate Full Impact Report" → toast SERVICE_PLACEHOLDER
- [ ] Bookmarked URL `/{lang}/crm/dashboards/case-dashboard` survives reload + back/forward navigation
- [ ] (Backfill validation) other system dashboards Contact / Donation / Communication / Ambassador / Volunteer all reachable via `/crm/dashboards/{kebab-slug}` URLs

**DB Seed Verification:**
- [ ] Dashboard row exists with correct ModuleId, IsSystem=true, IsMenuVisible=true, OrderBy=6, MenuId set
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (parses cleanly with all 4 breakpoints) + ConfiguredWidget JSON (16 entries each with valid widgetId)
- [ ] 16 Widget rows + WidgetRole grants seeded (BUSINESSADMIN/CASE_MANAGER/PROGRAM_DIRECTOR per ⑨)
- [ ] Menu CASEDASHBOARD MenuUrl updated to `crm/dashboards/case-dashboard`
- [ ] Backfill resolved every IsSystem dashboard's MenuId (no NULL remaining)
- [ ] Re-running CaseDashboard-sqlscripts.sql + Dashboard-MenuBackfill-sqlscripts.sql is idempotent
- [ ] Re-running each Postgres function `.sql` file is idempotent (`DROP FUNCTION IF EXISTS {schema}.{fn}(jsonb, int4, int4, int4, int4)` before each `CREATE OR REPLACE FUNCTION`)
- [ ] Each Path-A function returns the correct shape (`TABLE(data jsonb, metadata jsonb, total_count integer, filtered_count integer)`) — call directly via psql to confirm before wiring widgets

---

## ⑫ Special Notes & Warnings

**Dashboard-class warnings:**
- READ-ONLY screen. No CRUD on this prompt's scope (Dashboard CRUD lives in `#78 Dashboard Config`).
- Tenant-scoping (CompanyId) is a non-negotiable on every SP and every C# handler.
- N+1 risk in Staff Caseload SP (per-staff overdue count) — must be a single `LEFT JOIN ... GROUP BY StaffId` query, not a foreach.
- Multi-currency in Funder Impact: display source-currency only; do NOT auto-convert. ⑫ ISSUE-9 (below) tracks the eventual normalization.
- react-grid-layout LayoutConfig must include xs/sm/md/lg breakpoints (and xl maps lg) — missing breakpoints cause widget overlap.
- ConfiguredWidget `instanceId` must equal each LayoutConfig breakpoint's `i` value across ALL breakpoints. Mismatches → orphaned cells.
- Drill-down query-param names MUST match destination screens' accepted args (case-list accepts `statusId`, `assignedStaffId`, `programId`, etc. — verify each).

**MENU_DASHBOARD-only warnings:**
- This is the FIRST MENU_DASHBOARD prompt — one-time infra (template preamble § A–G) is in scope. NEXT MENU_DASHBOARD prompt can omit this work.
- Slug `case-dashboard` is unique within CRM module (verified — no collisions).
- Per-dashboard FE page must NOT exist for MENU_DASHBOARD. The dynamic `[slug]/page.tsx` covers it.
- Sidebar auto-injection — confirm batch query (1 call covering all `*_DASHBOARDS` parents) — not N+1.
- DELETE 6 hardcoded routes only AFTER pre-flight grep finds zero imports of those page modules in routing/test fixtures.

### § Known Issues (pre-flagged)

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | BE schema | First MENU_DASHBOARD adds 4 columns to `sett.Dashboards` — migration MUST run on existing DB without data-loss; pre-flight EnsureCreated → use `dotnet ef database update`, NOT EnsureCreated |
| ISSUE-2 | HIGH | FE | DELETE of 6 hardcoded route pages is destructive — pre-flight grep ALL imports across routing files, sidebar config, e2e tests; defer if any references found |
| ISSUE-3 | HIGH | Backfill | Backfill mapping relies on `DashboardCode = MenuCode` — pre-flight assert: zero MenuId-still-NULL rows for IsSystem dashboards after backfill. Abort with error if any remain |
| ISSUE-4 | MED | Bookmarks | Old URLs `/crm/dashboards/casedashboard` (no kebab) will 404 after slug switch — decide between `next.config.js` redirects for one release vs. release-note-only |
| ISSUE-5 | MED | Slug reserved list | Validator must block `config`, `new`, `edit`, `read`, `overview` slugs |
| ISSUE-6 | MED | Sidebar perf | menuVisibleDashboardsByModuleCode batched call required — N+1 will degrade sidebar render |
| ISSUE-7 | MED | Toolbar slot | `<DashboardHeader />` likely doesn't expose a toolbar slot today — first MENU_DASHBOARD prompt MUST add one (TS prop signature: `toolbar?: React.ReactNode`) |
| ISSUE-8 | MED | DELETE button visibility | "Generate Full Impact Report" button is SERVICE_PLACEHOLDER until report engine ships — UX shows button always; toast on click |
| ISSUE-9 | MED | Multi-currency | Funder Impact displays source currencies — when auto-conversion ships, this widget needs a "Show in {Company.DefaultCurrency}" toggle |
| ISSUE-10 | LOW | OrderBy collision | First MENU_DASHBOARD uses existing OrderBy from menu seed; future prompts must auto-default to `MAX(OrderBy)+10` on Promote |
| ISSUE-11 | LOW | FK Restrict | Menu delete with linked Dashboards — surface friendly error in menu delete handler listing affected Dashboards |
| ISSUE-12 | LOW | Function folder convention | Path-A functions live at `Base.Application/DatabaseScripts/Functions/{schema}/` (NOT `sql-scripts-dyanmic/` — that folder is for menu/seed scripts only). One `.sql` per function. Match `rep/donation_summary_report.sql` precedent |
| ISSUE-13 | LOW | Beneficiary count "communities/families" | Program Performance table shows "28 communities" / "340 families" for Clean Water / Food Distribution — these are NOT row counts of Beneficiaries; render via per-program `Program.UnitOfMeasure` field if it exists, else hardcode in SP per program category |
| ISSUE-14 | LOW | "Standby" program | Emergency Relief shows Status=Standby with 0 enrollments — handle div/0 gracefully in enrollment % calc |
| ISSUE-15 | LOW | Funder section collapsed default | UX wants collapsed by default; widget params should support `collapsedByDefault: true` in WidgetProperties JSON |

**Service Dependencies:**
- ⚠ SERVICE_PLACEHOLDER: Export Impact Report (PDF) — toolbar button + Funder section button both toast pending PDF service
- ⚠ SERVICE_PLACEHOLDER: Print Dashboard — uses `window.print()` directly (NOT a service gap; just a UX gap if future requires server-side branded PDF)

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.

### § Known Issues

(See ⑫ above. Issues are pre-flagged at planning time; build sessions append to the table below or move ISSUEs to "RESOLVED" status.)

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1..15 | planning | per ⑫ | per ⑫ | (pre-flagged at plan time) | OPEN |

### § Sessions

(no sessions yet — filled in by /build-screen)
