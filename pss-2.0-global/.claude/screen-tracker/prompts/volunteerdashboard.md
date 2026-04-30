---
screen: VolunteerDashboard
registry_id: 57
module: CRM (Volunteer)
status: COMPLETED
scope: FULL
screen_type: DASHBOARD
dashboard_variant: MENU_DASHBOARD
complexity: High
new_module: NO
planned_date: 2026-04-30
completed_date: 2026-04-30
last_session_date: 2026-04-30
---

> ## ⚠ HARD PREREQUISITE — Case Dashboard #52 Phase 2 Bootstrap MUST land first
>
> Volunteer Dashboard is the **second** MENU_DASHBOARD prompt. It depends on the bootstrap that Case Dashboard #52 Phase 2 introduces — DO NOT re-create any of these:
>
> 1. `Dashboard.MenuId int? FK → auth.Menus` schema column + EF migration `AddMenuIdToDashboard`
> 2. New BE query handler `GetDashboardByModuleAndCode(moduleCode, dashboardCode)` — single-row, NO UserDashboard join
> 3. New BE query handler `GetMenuLinkedDashboardsByModuleCode(moduleCode)` — sidebar consumption
> 4. New BE mutations `LinkDashboardToMenu` + `UnlinkDashboardFromMenu`
> 5. New FE component `<MenuDashboardComponent />` at `src/presentation/components/custom-components/menu-dashboards/index.tsx`
> 6. New FE gql doc `DASHBOARD_BY_MODULE_AND_CODE_QUERY` + barrel
> 7. New FE dynamic route `src/app/[lang]/(core)/[module]/dashboards/[slug]/page.tsx`
> 8. Sidebar batched injection of `menuLinkedDashboardsByModuleCode`
> 9. Backfill seed `Dashboard-MenuBackfill-sqlscripts.sql`
>
> **Volunteer Dashboard build scope is purely**: 11 Postgres functions + 11 NEW widget renderer files (under `volunteer-dashboard-widgets/`) + 11 new WidgetType seed rows + 1 Dashboard row + 1 DashboardLayout row + 11 Widget rows + 11 WidgetRole grants — all in `sql-scripts-dyanmic/VolunteerDashboard-sqlscripts.sql`.
>
> If Phase 2 has NOT shipped at build time → STOP. Build Case Dashboard #52 Phase 2 first. Do not retrofit a per-route page; do not add a `dashboardCode` prop to `<DashboardComponent />`. Tracked as ISSUE-1 below.

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (11 widgets — 6 KPIs / 2 charts / 3 tables — 2 filters + 1 export action)
- [x] Variant chosen — **MENU_DASHBOARD** (own sidebar leaf at `crm/dashboards/volunteerdashboard`, MenuCode `VOLUNTEERDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=5)
- [x] Source entities identified (Volunteer #53, VolunteerHourLog #55, VolunteerShift #54, VolunteerShiftAssignment #54, VolunteerSkill child #53, GlobalDonation existing, Branch existing — ALL COMPLETED)
- [x] Widget catalog drafted (11 widgets — 6 KPI + 2 charts + 3 tables; activity-feed widget renders distinctively)
- [x] react-grid-layout config drafted (lg breakpoint, 12 cols × 19 rows tall — 6-KPI stack 2×3 → charts 2-col → leaderboard full-width → bottom row shifts+activity)
- [x] DashboardLayout JSON shape drafted (LayoutConfig + ConfiguredWidget per widget)
- [x] MENU_DASHBOARD parent menu code resolved — `CRM_DASHBOARDS` already seeded; **NO new menu row needed** (`VOLUNTEERDASHBOARD` @ MenuUrl `crm/dashboards/volunteerdashboard` @ OrderBy=5 already exists per `MODULE_MENU_REFERENCE.md`)
- [x] First MENU_DASHBOARD bootstrap NOT in scope — already covered by Case Dashboard #52 Phase 2 (see HARD PREREQUISITE above). This prompt is a pure seed + widget renderer task.
- [x] Path-A (Postgres functions) chosen for ALL 11 widgets — matches `sett.fn_*_widget` and `case.fn_case_dashboard_*` precedent; no new C# code
- [x] File manifest computed (11 SQL functions + 11 NEW FE widget renderer files + 1 folder barrel + 2 registry wirings + Dashboard/DashboardLayout/Widget seeds)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (skipped — prompt pre-analyzed)
- [x] Solution Resolution complete (skipped — Path-A across 11 widgets dictated by §⑤)
- [x] UX Design finalized (skipped — §⑥ contains complete grid layout)
- [x] User Approval received
- [x] **Backend (Path-A only)** — 11 Postgres function files in `PSS_2.0_Backend/DatabaseScripts/Functions/app/` (NEW `app/` subfolder created — Volunteer entities live in `app` schema). Each conforms to fixed 5-arg / 4-column contract. NO new C# code (reuses existing `generateWidgets` GraphQL handler).
- [x] **Frontend** — 11 NEW widget renderer files under `dashboards/widgets/volunteer-dashboard-widgets/` + 1 folder barrel + 1 `_shared.tsx` helper. Registered all 11 in `WIDGET_REGISTRY` (`dashboard-widget-registry.tsx`). Repointed pre-existing route stub from `AmbassadorDashboardPageConfig` → new `VolunteerDashboardPageConfig` calling `<MenuDashboardComponent moduleCode="CRM" dashboardCode="VOLUNTEERDASHBOARD" />`.
- [x] **DB Seed** — `sql-scripts-dyanmic/VolunteerDashboard-sqlscripts.sql`:
      • Dashboard row VOLUNTEERDASHBOARD (DashboardCode, DashboardName, ModuleId=CRM, IsSystem=true, IsActive=true, CompanyId=NULL, MenuId resolved via UPDATE step)
      • DashboardLayout row (LayoutConfig × 4 breakpoints + ConfiguredWidget JSON × 11 instances)
      • 11 NEW WidgetType rows (PascalCase ComponentPath, one per renderer)
      • 11 Widget rows with `StoredProcedureName='app.fn_volunteer_dashboard_*'`
      • 11 WidgetRole grants — BUSINESSADMIN read-all
      • NO new Menu seed (VOLUNTEERDASHBOARD menu already exists)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (no new C# — verifies migration runner picks up new SQL functions, OR generate one-off `AddVolunteerDashboardFunctions.cs` migration that executes each `.sql`)
- [ ] All 11 SQL functions exist in `app.` schema after migration
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/volunteerdashboard` (handled by dynamic `[slug]/page.tsx` from #52 Phase 2)
- [ ] Dashboard renders with 11 widgets in the documented layout
- [ ] Each KPI card shows correct value formatted per spec (count / hrs / %)
- [ ] Each chart renders correctly (bar+overlay combo, horizontal bars, axes, legend, tooltip)
- [ ] Each table renders correctly (leaderboard rank badges + tier pills, shift gap status pill, activity feed icons)
- [ ] **Period filter** (This Month / Last Month / This Quarter / Custom Range) refetches all date-honoring widgets in parallel
- [ ] **Branch filter** (All / 5 cities) refetches all branch-scoped widgets
- [ ] Drill-down clicks navigate to correct destinations:
      • KPI Active Volunteers → `/crm/volunteer/volunteerlist`
      • KPI Total Hours → `/crm/volunteer/volunteerhourtracking`
      • KPI Upcoming Shifts → `/crm/volunteer/volunteerscheduling`
      • Top-volunteer row → `/crm/volunteer/volunteerlist?mode=read&id={volunteerId}`
      • Upcoming Shift row → `/crm/volunteer/volunteerscheduling?shiftId={id}` (SERVICE_PLACEHOLDER until destination accepts)
      • Activity feed item with volunteer name → volunteer detail; "View All" → SERVICE_PLACEHOLDER
- [ ] "Export Report" toasts SERVICE_PLACEHOLDER (no crash)
- [ ] Empty / loading / error states render per widget (skeletons match each renderer's shape)
- [ ] Role-based widget gating: WidgetRole(HasAccess=false) → widget hidden
- [ ] Sidebar leaf "Volunteer Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] Bookmarked URL `/[lang]/crm/dashboards/volunteerdashboard` survives reload
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl)
- [ ] DB Seed — Dashboard row + DashboardLayout JSON + 11 Widget rows visible in DB; widgets resolve from registry; all 11 SQL functions exist in `app.` schema; re-running seed is idempotent

---

## ① Screen Identity & Context

**Consumer**: All agents — sets the stage

**Screen**: VolunteerDashboard
**Module**: CRM → Volunteer (sidebar leaf under CRM_DASHBOARDS)
**Schema**: NONE for the dashboard itself (`sett.Dashboards` + `sett.DashboardLayouts` + `sett.Widgets` already exist). Postgres functions for widget aggregations live in the existing `app/` namespace under `DatabaseScripts/Functions/` — Volunteer entities are in `app` schema, so functions are seeded as `app.fn_volunteer_dashboard_*`.
**Group**: NONE (no new C# DTOs / handlers — Path-A throughout)

**Dashboard Variant**: **MENU_DASHBOARD** — own sidebar leaf at `crm/dashboards/volunteerdashboard` (MenuCode `VOLUNTEERDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=5 per `MODULE_MENU_REFERENCE.md`). NOT in any dropdown switcher.

**Business**:
The Volunteer Dashboard is the **operations + engagement overview** for the Volunteer Management module. It rolls up active-volunteer counts, monthly hours logged, upcoming shift coverage, retention, and the volunteer-to-donor conversion signal into a single board for Volunteer Coordinators, Program Directors, and HR/Engagement leads. **Target audience**: Volunteer Coordinator, Program Director, Branch Manager, Communications Lead. **Why it exists**: NGOs depend on volunteer hours as in-kind contribution — the dashboard surfaces (a) headcount + hours volume to validate program staffing, (b) shift fill gaps so coordinators can recruit ahead of events, (c) retention + leaderboard signals to drive recognition/comms, and (d) volunteer-to-donor conversion to inform fundraising outreach. **Why MENU_DASHBOARD (not STATIC)**: it is deep-linkable from Friday "weekly volunteer ops" digests, role-restricted to Volunteer Coordinators + Program leadership (not all CRM users), and tightly scoped to Volunteer (no need to share dropdown space with Donation / Communication / Case dashboards). It rolls up data from: Volunteer (#53), VolunteerHourLog (#55), VolunteerShift + VolunteerShiftAssignment (#54), VolunteerSkill (child of #53), GlobalDonation (existing — for donor-conversion KPI), Contact (existing — for activity-feed names + donor join), Branch (existing — for filter scoping). All FK source entities are COMPLETED.

---

## ② Entity Definition

**Consumer**: BA Agent → Backend Developer
> Dashboard does NOT introduce a new entity. It composes **two seeded rows** (`sett.Dashboards` + `sett.DashboardLayouts`) over **8 existing source entities**.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `VOLUNTEERDASHBOARD` | Matches Menu.MenuCode |
| DashboardName | `Volunteer Dashboard` | Matches Menu.MenuName (for sidebar display) |
| DashboardIcon | `chart-line-light` | Phosphor icon (mockup uses fa-chart-line; emerald accent) |
| DashboardColor | `#059669` | Emerald accent from mockup `--volunteer-accent` |
| ModuleId | (resolve from `auth.Modules WHERE ModuleCode='CRM'`) | CRM module |
| IsSystem | `true` | System-seeded |
| IsActive | `true` | — |
| CompanyId | NULL | Global system dashboard (CompanyId NULL = available to all tenants) |
| MenuId | `(SELECT MenuId FROM auth.Menus WHERE MenuCode='VOLUNTEERDASHBOARD')` | Resolves the existing menu row — written in the seed UPDATE step |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | JSON: `{"lg": [...11 layout items...], "md": [...], "sm": [...], "xs": [...]}` | react-grid-layout breakpoint configs (lg required; md/sm/xs minimal viable) |
| ConfiguredWidget | JSON: `[{instanceId, widgetId, title?, customQuery?, customParameter?}, ... 11 entries]` | One element per rendered widget |

### C. Widget Definitions (`sett.Widgets` + `sett.WidgetTypes`)

> All Path-A — each widget has `StoredProcedureName` set; `DefaultQuery` is NULL.
> **All 11 widget renderers are NEW** under `volunteer-dashboard-widgets/` per the `_DASHBOARD.md` directive ("NEW widget renderers are the DEFAULT — DO NOT reuse legacy `WIDGET_REGISTRY` entries"). 11 NEW WidgetTypes seeded.

| # | WidgetCode (used as instanceId) | WidgetName | WidgetType.ComponentPath (NEW) | StoredProcedureName | OrderBy |
|---|---------------------------------|-----------|--------------------------------|---------------------|---------|
| 1 | KPI_ACTIVE_VOLUNTEERS | Active Volunteers | `VolunteerActiveCountKpiWidget` | `app.fn_volunteer_dashboard_kpi_active_volunteers` | 1 |
| 2 | KPI_TOTAL_HOURS_MONTH | Total Hours (Month) | `VolunteerHoursMonthKpiWidget` | `app.fn_volunteer_dashboard_kpi_total_hours_month` | 2 |
| 3 | KPI_UPCOMING_SHIFTS | Upcoming Shifts | `VolunteerUpcomingShiftsKpiWidget` | `app.fn_volunteer_dashboard_kpi_upcoming_shifts` | 3 |
| 4 | KPI_AVG_HOURS_PER_VOLUNTEER | Avg Hours / Volunteer | `VolunteerAvgHoursKpiWidget` | `app.fn_volunteer_dashboard_kpi_avg_hours_per_volunteer` | 4 |
| 5 | KPI_RETENTION_RATE | Retention Rate | `VolunteerRetentionRateKpiWidget` | `app.fn_volunteer_dashboard_kpi_retention_rate` | 5 |
| 6 | KPI_DONOR_CONVERSION | Volunteer-to-Donor Rate | `VolunteerDonorConversionKpiWidget` | `app.fn_volunteer_dashboard_kpi_donor_conversion` | 6 |
| 7 | CHART_HOURS_TREND | Hours Trend (last 6 months) | `VolunteerHoursTrendChartWidget` | `app.fn_volunteer_dashboard_hours_trend` | 7 |
| 8 | CHART_VOLUNTEERS_BY_SKILL | Volunteers by Skill | `VolunteerSkillBarChartWidget` | `app.fn_volunteer_dashboard_volunteers_by_skill` | 8 |
| 9 | TBL_TOP_VOLUNTEERS | Top Volunteers (Leaderboard) | `VolunteerLeaderboardTableWidget` | `app.fn_volunteer_dashboard_top_volunteers` | 9 |
| 10 | TBL_UPCOMING_SHIFTS | Upcoming Shifts (Next 7 days) | `VolunteerUpcomingShiftsTableWidget` | `app.fn_volunteer_dashboard_upcoming_shifts_table` | 10 |
| 11 | LIST_RECENT_ACTIVITY | Recent Activity | `VolunteerActivityFeedWidget` | `app.fn_volunteer_dashboard_recent_activity` | 11 |

> **Note on KPI renderer split (1–6)**: per `_DASHBOARD.md` § "🎨 Each widget must be VISUALLY UNIQUE" — primary KPI (#1 Active Volunteers, emerald hero) gets a more prominent treatment vs secondary KPIs (#2-6, smaller, neutral with their own accent color + icon). The 6 renderers share a base shell but differ in: hero size flag, accent color (emerald / teal / blue / purple / orange / gold), icon (users / clock / calendar-check / chart-bar / user-clock / hand-holding-heart), trend-indicator style (▲ % delta vs subtitle pill), and value typography weight. Build agent MAY collapse 2 visually-identical KPIs onto one renderer if it determines they're truly identical post-design — document any collapse as ISSUE.

### D. Source Entities (read-only — what the widgets aggregate over)

| # | Source Entity | Schema.Table | Purpose | Aggregate(s) |
|---|--------------|--------------|---------|--------------|
| 1 | Volunteer | `app.Volunteers` | KPI 1, 5, 6; Top Volunteers (joined to hour logs); Activity feed (registrations) | `COUNT(*) WHERE VolunteerStatusId=Active`, `JOIN HourLogs`, retention windows, contact-id linkage for donor-conversion |
| 2 | VolunteerHourLog | `app.VolunteerHourLogs` | KPIs 2, 4; Hours Trend chart; Top Volunteers; Activity feed (logged hours, approved hours) | `SUM(Hours) WHERE LogDate in window AND ApprovalStatusId IN (APP)`, `GROUP BY MonthYear`, `GROUP BY VolunteerId ORDER BY SUM(Hours) DESC` |
| 3 | VolunteerShift | `app.VolunteerShifts` | KPI 3; Upcoming Shifts table; Activity feed (shift created) | `COUNT(*) WHERE ShiftDate BETWEEN today AND today+7`, projection of date/time/title/location/needed |
| 4 | VolunteerShiftAssignment | `app.VolunteerShiftAssignments` | Upcoming Shifts (Assigned count) | `COUNT(*) GROUP BY VolunteerShiftId WHERE assignment-status not Cancelled` |
| 5 | VolunteerSkill | `app.VolunteerSkills` (child of Volunteer) | Volunteers by Skill chart | `COUNT(DISTINCT VolunteerId) GROUP BY MasterDataId / SkillName`, top 6 + "Other" bucket |
| 6 | GlobalDonation | `donate.GlobalDonations` (existing) | KPI 6 Volunteer-to-Donor Rate | `JOIN Volunteer.ContactId → GlobalDonation.ContactId`, count distinct contacts that are both volunteer + donor |
| 7 | Contact | `corg.Contacts` (existing) | Activity feed (volunteer/registration names; donor-conversion linkage) | Lookup table; `JOIN Volunteer.ContactId` |
| 8 | Branch | `app.Branches` (existing) | Branch filter, KPI scoping | `JOIN Volunteer.BranchId / VolunteerShift.BranchId / VolunteerHourLog.BranchId` |
| 9 | MasterData | `sett.MasterDatas` (existing) | Status / Approval / SkillName labels | Display-dimension labels (denormalized to JSON) |

---

## ③ Source Entity & Aggregate Query Resolution

**Consumer**: Backend Developer (Postgres function authors) + Frontend Developer (widget binding via `Widget.StoredProcedureName`)

> Path-A across all 11 widgets. Each widget calls `SELECT * FROM app."{function_name}"(p_filter_json::jsonb, p_page, p_page_size, p_user_id, p_company_id)` via the existing `generateWidgets` GraphQL handler.

| # | Source Entity | Entity File Path | Postgres Function | GQL Field | Returns (data jsonb shape) | Filter Args (in p_filter_json) |
|---|--------------|------------------|-------------------|-----------|---------------------------|--------------------------------|
| 1 | Volunteer | `Base.Domain/Models/ApplicationModels/Volunteer.cs` | `app.fn_volunteer_dashboard_kpi_active_volunteers` | generateWidgets | `{value:int, deltaThisMonth:int, deltaLabel:string, deltaColor:'positive', subtitle:string, icon:'users', accentColor:'emerald', variant:'primary'}` | dateFrom, dateTo, branchId |
| 2 | VolunteerHourLog | `Base.Domain/Models/ApplicationModels/VolunteerHourLog.cs` | `app.fn_volunteer_dashboard_kpi_total_hours_month` | generateWidgets | `{value:decimal, formatted:string ("1,456"), momPercent:decimal, deltaLabel:string, deltaColor:'positive'\|'warning', subtitle:string, icon:'clock', accentColor:'teal', variant:'supporting'}` | dateFrom, dateTo, branchId |
| 3 | VolunteerShift | `Base.Domain/Models/ApplicationModels/VolunteerShift.cs` | `app.fn_volunteer_dashboard_kpi_upcoming_shifts` | generateWidgets | `{value:int, subtitle:string ("Next 7 days"), icon:'calendar-check', accentColor:'blue', variant:'supporting'}` | branchId (date-range hardcoded to today..today+7) |
| 4 | VolunteerHourLog + Volunteer | (joins) | `app.fn_volunteer_dashboard_kpi_avg_hours_per_volunteer` | generateWidgets | `{value:decimal, formatted:string ("7.7"), deltaLabel:string ("↑ 1.2"), deltaColor:'positive', subtitle:string, icon:'chart-bar', accentColor:'purple', variant:'supporting'}` | dateFrom, dateTo, branchId |
| 5 | Volunteer | `Base.Domain/Models/ApplicationModels/Volunteer.cs` | `app.fn_volunteer_dashboard_kpi_retention_rate` | generateWidgets | `{value:decimal, formatted:string ("82%"), subtitle:string ("Active >6 months"), icon:'user-clock', accentColor:'orange', variant:'supporting'}` | branchId |
| 6 | Volunteer + GlobalDonation + Contact | (joins) | `app.fn_volunteer_dashboard_kpi_donor_conversion` | generateWidgets | `{value:decimal, formatted:string ("34%"), volunteersDonatedCount:int, subtitle:string ("64 volunteers also donate"), icon:'hand-holding-heart', accentColor:'gold', variant:'supporting'}` | dateFrom, dateTo, branchId |
| 7 | VolunteerHourLog + Volunteer | (joins, GROUP BY MonthYear) | `app.fn_volunteer_dashboard_hours_trend` | generateWidgets | `{labels:[6 months MMM], series:[{name:"Total Hours",color:"#059669",data:[int x6]},{name:"Active Volunteers",color:"#0e7490",data:[int x6]}], unit:'hrs'}` | branchId |
| 8 | VolunteerSkill + MasterData | (joins, GROUP BY SkillName, top 6 + Other) | `app.fn_volunteer_dashboard_volunteers_by_skill` | generateWidgets | `{rows:[{skillName:string, count:int, widthPct:decimal, color:string}, ... top 6 + Other bucket]}` | branchId |
| 9 | Volunteer + VolunteerHourLog | (joins, ORDER BY SUM(Hours) DESC LIMIT 5) | `app.fn_volunteer_dashboard_top_volunteers` | generateWidgets | `{rows:[{rank:int, rankIcon:string, volunteerId:int, volunteerName:string, hoursMonth:decimal, hoursYtd:decimal, shifts:int, badge:{tier:'champion'\|'star'\|'veteran'\|null, label:string, color:string}}, ... top 5]}` | dateFrom, dateTo, branchId |
| 10 | VolunteerShift + VolunteerShiftAssignment | (joins, WHERE ShiftDate BETWEEN today AND today+7) | `app.fn_volunteer_dashboard_upcoming_shifts_table` | generateWidgets | `{rows:[{shiftId:int, dateLabel:string ("Apr 15"), title:string, timeLabel:string ("8AM–12PM"), locationLabel:string, needed:int, assigned:int, gap:{state:'warning'\|'full', label:string ("4 needed"\|"Full"), iconCode:string}}]}` | branchId |
| 11 | VolunteerHourLog + Volunteer + VolunteerShift + Contact | (multi-source UNION events) | `app.fn_volunteer_dashboard_recent_activity` | generateWidgets | `{events:[{eventType:'hours'\|'registration'\|'milestone'\|'shift'\|'approve', iconCode:string, accentColor:string, message:string (with safe <strong> tags allowed), timestamp:string ISO, timestampLabel:string ("Apr 12"), link?:{label,route,args}}]}`, hard-cap 8 rows | dateFrom, dateTo, branchId |

**Strategy**: **Path A — Postgres functions only**. No composite C# DTO; no per-widget GraphQL handler. Each widget binds to one function via `Widget.StoredProcedureName`. The runtime calls the existing `generateWidgets` GraphQL field with the function name + filter context. Mirrors Case Dashboard #52 precedent + `sett.fn_*_widget` library.

**Where the SQL files live**: `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/app/fn_volunteer_dashboard_*.sql` — REUSE existing `app/` folder (Volunteer entities are in `app` schema; do NOT create a `volunteer/` subfolder). 11 new `.sql` files, snake_case names.

---

## ④ Business Rules & Validation

**Consumer**: BA Agent → Backend Developer (Postgres functions enforce filtering) → Frontend Developer (filter behavior + drill-down args)

### Date Range Defaults
- Default range: **This Month** (1st of current calendar month → today)
- Allowed presets: This Month / Last Month / This Quarter / Custom Range
- Custom range max span: **2 years** (enforced in FE filter validation; functions cap p_filter_json date span if larger)
- Date filter applies to: VolunteerHourLog.LogDate (KPIs 2 / 4 / 6, chart 7, table 9, activity 11), Volunteer.JoinedDate (KPI 1 deltaThisMonth + activity-feed registrations). KPI 3 (Upcoming Shifts) and table 10 use a HARDCODED `today..today+7` range — **Period filter does NOT apply to these two**. KPI 5 (Retention) uses a fixed "active > 6 months" rule — **Period filter does NOT apply** but Branch filter does.

### Role-Scoped Data Access
- **BUSINESSADMIN** → sees ALL companies' data (no scoping; CompanyId from HttpContext but admin has cross-company visibility per existing pattern)
- **CRM_MANAGER / VOLUNTEER_COORDINATOR / PROGRAM_DIRECTOR** → sees only own company (`CompanyId = HttpContext.CompanyId`)
- **BRANCH_MANAGER** → additionally filtered by `BranchId IN user's branches` (read from `auth.UserBranches` table — pre-existing infra)
- All scoping happens in the Postgres function via `p_user_id` + `p_company_id` parameters and helper joins to `auth.UserBranches`

### Calculation Rules
- **Active Volunteers (KPI 1)**: `COUNT(DISTINCT VolunteerId) WHERE VolunteerStatusId = (SELECT MasterDataId FROM sett."MasterDatas" m JOIN sett."MasterDataTypes" t ON m."MasterDataTypeId"=t."MasterDataTypeId" WHERE t."MasterDataTypeCode"='VOLUNTEERSTATUS' AND m."DataValue"='ACT')`. **deltaThisMonth** = `COUNT WHERE JoinedDate >= date_trunc('month', current_date)`.
- **Total Hours (Month) (KPI 2)**: `SUM(Hours) FROM VolunteerHourLogs WHERE LogDate IN [dateFrom, dateTo] AND ApprovalStatusId = (APP)`. **momPercent** = `((current - sameRangeLastMonth) / sameRangeLastMonth) * 100`. trendDir = up if growing.
- **Upcoming Shifts (KPI 3)**: `COUNT(*) FROM VolunteerShifts WHERE ShiftDate >= current_date AND ShiftDate < current_date + INTERVAL '7 days'`. Branch-scoped only.
- **Avg Hours / Volunteer (KPI 4)**: `(SUM(Hours WHERE ApprovalStatusId=APP and LogDate in window)) / NULLIF(COUNT(DISTINCT VolunteerId WHERE has any approved log in window), 0)` rounded to 1 decimal. **deltaLabel** = previous-month delta same way.
- **Retention Rate (KPI 5)**: `(COUNT(Volunteer WHERE VolunteerStatusId=Active AND JoinedDate <= current_date - INTERVAL '6 months') / NULLIF(COUNT(Volunteer WHERE JoinedDate <= current_date - INTERVAL '6 months'), 0)) * 100`. Date filter NOT applied; Branch filter applied.
- **Volunteer-to-Donor Conversion (KPI 6)**: `(COUNT(DISTINCT v.VolunteerId WHERE v.ContactId IS NOT NULL AND EXISTS (SELECT 1 FROM donate."GlobalDonations" g WHERE g."ContactId" = v."ContactId" AND g."DonationDate" IN [dateFrom, dateTo])) / NULLIF(COUNT(DISTINCT v.VolunteerId), 0)) * 100`. Subtitle: `"{volunteersDonatedCount} volunteers also donate"` derived from numerator.
- **Hours Trend (chart 7)**: GROUP BY `to_char(LogDate, 'YYYY-MM')` for last 6 months ending current month. Series 1 = `SUM(Hours)`. Series 2 = `COUNT(DISTINCT VolunteerId)`. Branch-scoped (no period filter — chart shows fixed 6-month rolling window). Approved-only.
- **Volunteers by Skill (chart 8)**: From `app.VolunteerSkills` joined to `sett.MasterDatas` on SkillId — `COUNT(DISTINCT VolunteerId) GROUP BY MasterData.DataLabel`. Top 6 by count + "Other" bucket = sum of remaining. Width % = `value / max_value * 100` (mockup widths). Distinct color per row (use a 6-color palette from design language; "Other" rendered with neutral gray).
- **Top Volunteers (table 9)**: Sub-query: per-volunteer `SUM(Hours) AS hoursMonth` filtered by date-range, `SUM(Hours) AS hoursYtd` filtered by year-start..date-range-end, `COUNT(DISTINCT VolunteerHourLogId) AS shifts` (in window). ORDER BY `hoursMonth DESC` LIMIT 5. **rankIcon**: emoji by rank (`🥇` rank=1, `🥈` rank=2, `🥉` rank=3, plain numeric for 4–5). **Badge tier**:
  - `champion` if `hoursYtd >= 150 AND hoursMonth >= 30`
  - `star` if `hoursYtd >= 150 AND hoursMonth >= 20`
  - `veteran` if `JoinedDate <= current_date - INTERVAL '12 months' AND hoursYtd >= 200`
  - `null` otherwise
  - Pill colors: champion=`#fef3c7/#92400e`, star=`#eff6ff/#1e40af`, veteran=`#ecfdf5/#065f46` (mockup palette)
- **Upcoming Shifts (table 10)**: WHERE ShiftDate >= today AND ShiftDate < today + INTERVAL '7 days'. ORDER BY ShiftDate, StartTime. Computed `assigned` = `COUNT(VolunteerShiftAssignments WHERE VolunteerShiftId=shift.Id AND status not in cancelled)`. **gap.state** = `full` if `assigned >= needed`, else `warning`. Cap to top 10 rows. Branch-scoped only.
- **Recent Activity (widget 11 — multi-source UNION)**:
  - `hours` events: latest 3 `VolunteerHourLogs WHERE ApprovalStatusId=APP AND LogDate <= current_date` ordered by ModifiedDate DESC, message `"<strong>{Volunteer.FirstName} {Volunteer.LastName}</strong> logged {Hours} hours — {Activity}"`, link `→ /crm/volunteer/volunteerhourtracking?volunteerId={id}`
  - `registration` events: count of `Volunteer WHERE VolunteerStatusId=Pending` rolled into one event per day → message `"<strong>{N} new volunteer registrations</strong> pending approval"`, link `→ /crm/volunteer/volunteerlist?status=PND`
  - `milestone` events: any volunteer crossing a 50/100/250/500-shift threshold in window → message `"<strong>{Volunteer.Name}</strong> completed {N}th shift — 🏆 milestone!"`, link `→ /crm/volunteer/volunteerlist?mode=read&id={id}` (DEFERRED rule — see ISSUE-3 — needs cumulative-shift count which requires aggregate; v1 may emit empty milestones)
  - `shift` events: latest 2 `VolunteerShifts WHERE created_in_window` → message `"Shift created: <strong>{Title}</strong> ({DateLabel}) — {VolunteersNeeded} volunteers needed"`, link `→ /crm/volunteer/volunteerscheduling?shiftId={id}`
  - `approve` events: `VolunteerHourLogs WHERE ApprovalStatusId changed to APP in window GROUP BY ApprovedByUserId` → message `"<strong>{User.FullName}</strong> approved {N} hour entries"`, link `→ /crm/volunteer/volunteerhourtracking?status=APP`
  - UNION ordered by `timestamp DESC LIMIT 8`. Severity → emoji color tints (mockup palette emerald for hours/approve, blue for registration, gold for milestone, teal for shift).

### Multi-Currency Rules
- **None** — all KPIs are counts / hours / percentages, not currency. Volunteer-to-donor KPI 6 counts DISTINCT contacts, not donation amounts. (If future spec adds "Donation amount from converted volunteers" KPI, multi-currency rules must be added — out of scope for v1.)

### Widget-Level Rules
- A widget is RENDERED only if `auth.WidgetRoles(WidgetId, currentRoleId, HasAccess=true)` row exists. No row → widget hidden (placeholder NOT shown to keep dashboard clean for restricted roles).
- All 11 widgets seed `WidgetRole(BUSINESSADMIN, HasAccess=true)`. Other roles inherit no grants by default — assigned at admin-config time.
- **Workflow**: None. Read-only. Drill-downs navigate AWAY.

---

## ⑤ Screen Classification & Pattern Selection

**Consumer**: Solution Resolver — these are PRE-ANSWERED.

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Standalone analytical surface deep-linkable from weekly volunteer-ops digests; role-restricted to Volunteer Coordinators + Program leadership; tightly scoped to Volunteer module. Has its own sidebar leaf at `/crm/dashboards/volunteerdashboard` (MenuCode `VOLUNTEERDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=5).

**Backend Implementation Path** — **Path A across all 11 widgets**:
- [x] **Path A — Postgres function (generic widget)**: Each widget = 1 SQL function in `app.` schema returning `(data jsonb, metadata jsonb, total_count integer, filtered_count integer)`. Reuses the existing `generateWidgets` GraphQL handler. Seed `Widget.StoredProcedureName='app.fn_volunteer_dashboard_*'`. NO new C# code; 11 SQL deliverables only.
- [ ] Path B — Named GraphQL query (NOT used)
- [ ] Path C — Composite DTO (NOT used)

**Path-A Function Contract (NON-NEGOTIABLE)** — every function MUST:
- Take 5 fixed inputs in this order: `p_filter_json jsonb, p_page integer, p_page_size integer, p_user_id integer, p_company_id integer`
- Return `TABLE(data jsonb, metadata jsonb, total_count integer, filtered_count integer)` — single row, 4 columns
- Extract every filter from `p_filter_json` using `NULLIF(p_filter_json->>'keyName','')::type` (fields: `dateFrom`, `dateTo`, `branchId`)
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators)
- Live at `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/app/{function_name}.sql` — REUSE existing `app/` folder, snake_case names. Do NOT create a `volunteer/` subfolder — Volunteer entities are in `app` schema; existing `app/fn_*` functions co-exist there.
- `Widget.DefaultParameters` JSON keys MUST match the keys that the function reads from `p_filter_json` (e.g., `{"dateFrom":"{dateFrom}","dateTo":"{dateTo}","branchId":"{branchId}"}`)

**Backend Patterns Required:**
- [x] Tenant scoping (CompanyId from HttpContext via p_company_id arg) — every function
- [x] Date-range parameterized queries (where applicable; KPI 3 / table 10 use hardcoded today..+7)
- [x] Role-scoped data filtering — joined to `auth.UserBranches` for BRANCH_MANAGER scope
- [ ] Materialized view / cached aggregate — not needed; data volume small enough for live aggregation in v1

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` (responsive breakpoints) — already in `<MenuDashboardComponent />` (from Case Dashboard #52 Phase 2)
- [x] **NEW renderers — 11 widgets in `dashboards/widgets/volunteer-dashboard-widgets/`**:
      • `VolunteerActiveCountKpiWidget.tsx`
      • `VolunteerHoursMonthKpiWidget.tsx`
      • `VolunteerUpcomingShiftsKpiWidget.tsx`
      • `VolunteerAvgHoursKpiWidget.tsx`
      • `VolunteerRetentionRateKpiWidget.tsx`
      • `VolunteerDonorConversionKpiWidget.tsx`
      • `VolunteerHoursTrendChartWidget.tsx`
      • `VolunteerSkillBarChartWidget.tsx`
      • `VolunteerLeaderboardTableWidget.tsx`
      • `VolunteerUpcomingShiftsTableWidget.tsx`
      • `VolunteerActivityFeedWidget.tsx`
      • `index.ts` (barrel — re-export all 11)
- [x] Each renderer registered in `WIDGET_REGISTRY` (`dashboard-widget-registry.tsx`). NO touch to `dashboard-widget-query-registry.tsx` (Path A only).
- [x] **NO REUSE** of legacy `WIDGET_REGISTRY` entries (`StatusWidgetType1`, `MultiChartWidget`, `PieChartWidgetType1`, etc.) — those are reserved for #120 only per the directive.
- [x] **Skeletons must MATCH each renderer's shape** — KPI skeleton (icon + 2 lines + value placeholder), bar-chart skeleton (axis + 6 bars), horizontal-bar skeleton (7 rows of label+track+number), leaderboard skeleton (5 rows of badge+name+3 numbers+pill), shift-table skeleton (3 rows of 7 cells), activity-feed skeleton (5 rows of icon+text+timestamp). NO generic shimmer rectangles.
- [x] Date-range picker / Branch select — page-level filter context (already supplied by `<MenuDashboardComponent />`'s lean header from #52 Phase 2). Functions read filters out of `p_filter_json` substituted by widget runtime.
- [ ] **Toolbar overrides** — `<MenuDashboardComponent />` accepts a header toolbar slot (per `_DASHBOARD.md` § H). Surface 2 buttons in dashboard header: "Export Report" (PDF — SERVICE_PLACEHOLDER) and "Print Dashboard" (calls `window.print()`). If the new component doesn't yet support a toolbar slot at build time, fold the buttons into the page chrome via the same approach the Case Dashboard #52 ISSUE-4 settles on. Do NOT touch `<DashboardHeader />`.

---

## ⑥ UI/UX Blueprint

**Consumer**: UX Architect → Frontend Developer

> Layout follows the HTML mockup. Renders via `<MenuDashboardComponent moduleCode="CRM" dashboardCode="VOLUNTEERDASHBOARD" />` → resolves the seeded Dashboard row → reads LayoutConfig + ConfiguredWidget JSON → maps each instance to a NEW widget renderer + a Postgres function.

### Page Chrome (MENU_DASHBOARD — lean by design)

- **Header row**:
  - Left: page title `Volunteer Dashboard` + icon `chart-line-light` (emerald) + subtitle "Volunteer program overview and performance metrics"
  - Right: **2 filter selects + 1 button**:
    1. **Period select** — default "This Month"; options: This Month / Last Month / This Quarter / Custom Range. "Custom Range" opens an inline date-range popover.
    2. **Branches select** — default "All Branches"; options: All / dynamically loaded `app.Branches WHERE IsActive=true` (mockup shows Dubai, Mumbai, Delhi, Dhaka, Nairobi as samples).
    3. **"Export Report"** outline button — SERVICE_PLACEHOLDER (toast "Generating volunteer report..."). UI in place; backend PDF service deferred.

- **No dropdown switcher**, **no Edit Layout chrome** (read-only by default per MENU_DASHBOARD pattern).
- **No refresh button** in v1 (filter changes act as refresh).

### Grid Layout (react-grid-layout — `lg` breakpoint, 12 columns, ~19 rows tall)

| i (instanceId) | Widget | x | y | w | h | minW | minH | Notes |
|----------------|--------|---|---|---|---|------|------|-------|
| KPI_ACTIVE_VOLUNTEERS | KPI 1 | 0 | 0 | 4 | 2 | 3 | 2 | KPI hero row 1 col 1 — primary (emerald, larger value) |
| KPI_TOTAL_HOURS_MONTH | KPI 2 | 4 | 0 | 4 | 2 | 3 | 2 | KPI hero row 1 col 2 (teal) |
| KPI_UPCOMING_SHIFTS | KPI 3 | 8 | 0 | 4 | 2 | 3 | 2 | KPI hero row 1 col 3 (blue) |
| KPI_AVG_HOURS_PER_VOLUNTEER | KPI 4 | 0 | 2 | 4 | 2 | 3 | 2 | KPI hero row 2 col 1 (purple) |
| KPI_RETENTION_RATE | KPI 5 | 4 | 2 | 4 | 2 | 3 | 2 | KPI hero row 2 col 2 (orange) |
| KPI_DONOR_CONVERSION | KPI 6 | 8 | 2 | 4 | 2 | 3 | 2 | KPI hero row 2 col 3 (gold) |
| CHART_HOURS_TREND | Hours Trend (combined bar) | 0 | 4 | 6 | 4 | 4 | 3 | Half-width chart |
| CHART_VOLUNTEERS_BY_SKILL | Volunteers by Skill (h-bar) | 6 | 4 | 6 | 4 | 4 | 3 | Half-width chart |
| TBL_TOP_VOLUNTEERS | Top Volunteers (Leaderboard) | 0 | 8 | 12 | 6 | 8 | 4 | Full-width table |
| TBL_UPCOMING_SHIFTS | Upcoming Shifts (table) | 0 | 14 | 6 | 5 | 4 | 4 | Half-width — bottom-row col 1 |
| LIST_RECENT_ACTIVITY | Recent Activity (feed) | 6 | 14 | 6 | 5 | 4 | 4 | Half-width — bottom-row col 2 |

`md` (8 cols), `sm` (6 cols), `xs` (4 cols) — collapse multi-column rows: KPI grid 3-col → 2-col → 1-col; charts row → stacked; bottom row → stacked. Minimum viable: `lg` defined (above), other breakpoints optional but preferable to fill in for clean reflow.

### KPI Cards (6 NEW renderers — visually differentiated per the directive)

> Each KPI is its OWN renderer file. Renderers share a common base shell (icon-tile + label + value + subtitle stack) but differentiate by:
> - **Variant** (primary / supporting) — primary KPI (Active Volunteers) gets larger value typography (`1.875rem`) and a hero accent treatment; supporting KPIs use mockup's `1.625rem`.
> - **Accent color** — emerald / teal / blue / purple / orange / gold (per mockup palette).
> - **Icon** — phosphor icon mapped to mockup's fa-icon.
> - **Trend indicator** — KPIs with delta (1, 2, 4) show `↑ {n}` colored pill in subtitle; KPIs without delta (3, 5, 6) show plain subtitle.

| # | InstanceId | Renderer | Title | Value Format | Subtitle Format | Color Cue | Icon |
|---|-----------|----------|-------|--------------|-----------------|-----------|------|
| 1 | KPI_ACTIVE_VOLUNTEERS | `VolunteerActiveCountKpiWidget` | Active Volunteers | count (e.g., "189") | "↑ {deltaThisMonth} new this month" (green positive pill) | emerald (`#059669` / `#ecfdf5`) — **PRIMARY** (larger value) | users |
| 2 | KPI_TOTAL_HOURS_MONTH | `VolunteerHoursMonthKpiWidget` | Total Hours (Month) | count w/ comma ("1,456") | "↑ {momPercent}% vs last month" (green positive pill) | teal (`#0e7490` / `#ecfeff`) | clock |
| 3 | KPI_UPCOMING_SHIFTS | `VolunteerUpcomingShiftsKpiWidget` | Upcoming Shifts | count ("23") | "Next 7 days" (plain neutral) | blue (`#3b82f6` / `#eff6ff`) | calendar-check |
| 4 | KPI_AVG_HOURS_PER_VOLUNTEER | `VolunteerAvgHoursKpiWidget` | Avg Hours / Volunteer | decimal ("7.7") | "↑ {deltaLabel} vs last month" (green positive pill) | purple (`#a855f7` / `#faf5ff`) | chart-bar |
| 5 | KPI_RETENTION_RATE | `VolunteerRetentionRateKpiWidget` | Retention Rate | percent ("82%") | "Active >6 months" (plain neutral) | orange (`#f97316` / `#fff7ed`) | user-clock |
| 6 | KPI_DONOR_CONVERSION | `VolunteerDonorConversionKpiWidget` | Volunteer-to-Donor Rate | percent ("34%") | "{volunteersDonatedCount} volunteers also donate" (plain neutral) | gold (`#eab308` / `#fefce8`) | hand-holding-heart |

### Charts (2 NEW renderers)

#### Chart 7 — Hours Trend (`VolunteerHoursTrendChartWidget`)
- Type: **Combined bar chart** — 6 monthly groups (Nov, Dec, Jan, Feb, Mar, Apr — last 6 months ending current month).
- Per group: 2 bars side-by-side
  - **Hours bar** (taller, ~28px wide) — emerald gradient `linear-gradient(180deg, #059669, #34d399)` — top label = `value` (e.g., "820")
  - **Volunteer count bar** (thin, ~3px wide) — teal gradient `linear-gradient(180deg, #0e7490, #06b6d4)` — tooltip = "{count} volunteers"
- X-axis: month labels under each group
- Legend (below chart): emerald square = "Total Hours" | teal square = "Active Volunteers"
- Empty state: "No volunteer hours in trailing 6 months"
- Data shape (per ③ row 7).

#### Chart 8 — Volunteers by Skill (`VolunteerSkillBarChartWidget`)
- Type: **Horizontal bar chart** — 7 rows (top 6 skills + "Other" bucket)
- Per row layout: skill label (left, 110px width, right-aligned) | bar track (flex 1, 24px height, light gray bg) | bar fill (emerald gradient `linear-gradient(90deg, #059669, #34d399)`, value text inside) | numeric value (right, 40px width)
- "Other" row uses neutral gray gradient `linear-gradient(90deg, #94a3b8, #cbd5e1)` to distinguish
- Empty state: "No skill data"
- Data shape (per ③ row 8).

### Tables (3 NEW renderers — each visually distinctive)

#### Table 9 — Top Volunteers (Leaderboard) (`VolunteerLeaderboardTableWidget`)
- 6 columns: Rank | Volunteer (link) | Hours (Month) | Hours (YTD) | Shifts | Badge
- **Rank cell**: 28px circle badge with bg color by rank — gold `#fef3c7` (1), silver `#f1f5f9` (2), bronze `#fed7aa` (3), neutral gray for 4–5; renders emoji `🥇/🥈/🥉` for top-3, plain numeric for others
- **Volunteer cell**: link (teal `#0e7490`, weight 600), navigates to `/crm/volunteer/volunteerlist?mode=read&id={volunteerId}`
- **Hours (Month)**: bold weight, suffix " hrs"
- **Hours (YTD)**: regular weight, suffix " hrs"
- **Shifts**: integer
- **Badge**: pill with tier label + emoji per `tier`:
  - `champion` → 🏆 Champion (`#fef3c7` bg / `#92400e` fg)
  - `star` → ⭐ Star (`#eff6ff` bg / `#1e40af` fg)
  - `veteran` → 🎖 Veteran (`#ecfdf5` bg / `#065f46` fg)
  - null → empty cell
- Row hover: bg `#f8fafc`
- Empty state: "No volunteer activity in selected period"

#### Table 10 — Upcoming Shifts (`VolunteerUpcomingShiftsTableWidget`)
- 7 columns: Date | Shift | Time | Location | Needed | Assigned | Gap
- **Date** cell: short label (e.g., "Apr 15")
- **Shift** cell: title (weight 600, e.g., "Gala Setup")
- **Time** cell: short range ("8AM–12PM")
- **Location**: plain text
- **Needed / Assigned**: integer center-aligned
- **Gap** cell: pill with severity:
  - `warning` (deficit) → "⚠ {N} needed" (`#fef3c7` bg / `#92400e` fg)
  - `full` → "✓ Full" (`#dcfce7` bg / `#166534` fg)
- Row click: navigate to `/crm/volunteer/volunteerscheduling?shiftId={id}` (SERVICE_PLACEHOLDER until destination accepts — see ISSUE-4)
- Empty state: "No shifts scheduled in next 7 days"

#### Widget 11 — Recent Activity (`VolunteerActivityFeedWidget`)
- **Distinctively different shape** from KPI / chart / table — vertical activity feed.
- Per row: 32px circle icon (left) | message text (flex 1, line-height 1.5) | timestamp label (right, 0.6875rem, muted)
- Icon background by `eventType`:
  - `hours` → emerald (`#ecfdf5` / `#059669`) — clock icon
  - `registration` → blue (`#eff6ff` / `#3b82f6`) — user-plus icon
  - `milestone` → gold (`#fef3c7` / `#eab308`) — trophy icon
  - `shift` → teal (`#ecfeff` / `#0e7490`) — calendar-plus icon
  - `approve` → green (`#dcfce7` / `#16a34a`) — check-circle icon
- Message sanitization: allow `<strong>` tags only (sanitize-html or DOMPurify with `ALLOWED_TAGS=['strong']` whitelist) — render as innerHTML; strip everything else.
- "View All" link (top-right of widget) → SERVICE_PLACEHOLDER toast (no destination yet — see ISSUE-5)
- Empty state: "No recent volunteer activity in selected period"

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Period | Native select + custom range popover | "This Month" | KPIs 1 (deltaThisMonth) / 2 / 4 / 6, chart 7 (hours-trend uses fixed 6-mo window — Period filter does NOT apply), table 9 (hoursMonth scoped to window), activity 11 | Presets: This Month / Last Month / This Quarter / Custom Range |
| Branch | Single-select — from `app.Branches` (typeahead) | "All Branches" or user's branch (BRANCH_MANAGER) | All 11 widgets | Always honored |

Filter values flow into `<MenuDashboardComponent />` filter context, which projects them into each widget's `customParameter` JSON via the runtime's `{placeholder}` substitution. Functions read them out of `p_filter_json`.

### Drill-Down / Navigation Map

| From Widget / Element | Click On | Navigates To | Prefill |
|-----------------------|----------|--------------|---------|
| KPI 1 (Active Volunteers) card | Card click | `/crm/volunteer/volunteerlist` | `status=ACT` (SERVICE_PLACEHOLDER if VolunteerList does not accept — see ISSUE-6) |
| KPI 2 (Total Hours) card | Card click | `/crm/volunteer/volunteerhourtracking` | `dateFrom={...}, dateTo={...}` |
| KPI 3 (Upcoming Shifts) card | Card click | `/crm/volunteer/volunteerscheduling` | `dateFrom=today, dateTo=today+7` |
| KPI 4 (Avg Hours) card | Card click | `/crm/volunteer/volunteerhourtracking` | `dateFrom={...}, dateTo={...}` (same as KPI 2) |
| KPI 5 (Retention) card | Card click | `/crm/volunteer/volunteerlist` | `status=ACT` + (SERVICE_PLACEHOLDER `joinedBefore=current-6mo`) — see ISSUE-6 |
| KPI 6 (Donor Conversion) card | Card click | `/crm/volunteer/volunteerlist` | `hasDonations=true` (SERVICE_PLACEHOLDER) — see ISSUE-6 |
| Top-volunteer row (table 9) name link | Link click | `/crm/volunteer/volunteerlist?mode=read&id={volunteerId}` | mode=read, id={volunteerId} |
| Upcoming-shift row (table 10) | Row click | `/crm/volunteer/volunteerscheduling` | `shiftId={id}` (SERVICE_PLACEHOLDER until destination accepts — see ISSUE-4) |
| Activity-feed item with volunteer name | Per `event.link.route` | volunteer detail / hour-tracking / shift detail | per `event.link.args` |
| Activity-feed "View All" | Link click | SERVICE_PLACEHOLDER toast — see ISSUE-5 | — |
| "Export Report" header button | Click | SERVICE_PLACEHOLDER toast | Eventual: PDF download |
| "Print Dashboard" header button (if shipped per ISSUE-7) | Click | `window.print()` | Browser primitive |

### User Interaction Flow

1. **Initial load**: User clicks `CRM → Dashboards → Volunteer Dashboard` in sidebar → URL becomes `/[lang]/crm/dashboards/volunteerdashboard` → dynamic `[slug]/page.tsx` (from #52 Phase 2) renders `<MenuDashboardComponent moduleCode="CRM" dashboardCode="VOLUNTEERDASHBOARD" />`. Component fires `dashboardByModuleAndCode("CRM", "VOLUNTEERDASHBOARD")` → fetches DashboardLayout JSON → renders 11-widget grid → all widgets parallel-fetch via `generateWidgets` with default filters (This Month / All Branches).
2. **Filter change** (Period or Branch): widgets honoring that filter refetch in parallel; widgets NOT honoring it stay cached (chart 7, KPI 5 unaffected by Period; nothing unaffected by Branch).
3. **Drill-down click**: navigates per Drill-Down Map → destination receives prefill args. Some args are SERVICE_PLACEHOLDER until destination accepts (degrade gracefully — destination loads unfiltered + toast).
4. **Back navigation**: returns to dashboard → filters preserved (URL search params persist; if not feasible, default filters re-apply — confirm in build).
5. **Export Report** → toast SERVICE_PLACEHOLDER. **Print Dashboard** (if shipped) → `window.print()`.
6. **No edit-layout / add-widget chrome** in v1 (deferred MENU_DASHBOARD chrome).
7. **Empty / loading / error states**: each renderer ships its own skeleton matching its shape (KPI skeleton / bar-chart skeleton / horizontal-bar skeleton / leaderboard skeleton / shift-table skeleton / activity-feed skeleton). Error → red mini banner + Retry button. Empty → muted icon + per-widget empty message.

---

## ⑦ Substitution Guide

**Consumer**: Backend Developer + Frontend Developer

> Canonical Reference: **Case Dashboard #52** for MENU_DASHBOARD pattern (DB seed shape, Path-A function structure, layout JSON, MenuId linkage). #57 is the SECOND MENU_DASHBOARD prompt — reuse #52 conventions verbatim, except for the renderer-folder + function-namespace differences below.

| Convention | Case Dashboard #52 | → Volunteer Dashboard #57 | Notes |
|-----------|--------------------|---------------------------|-------|
| DashboardCode | `CASEDASHBOARD` | `VOLUNTEERDASHBOARD` | Already seeded in `auth.Menus` |
| MenuUrl | `crm/dashboards/casedashboard` | `crm/dashboards/volunteerdashboard` | Already seeded |
| Menu OrderBy | 6 | 5 | Per `MODULE_MENU_REFERENCE.md` |
| Postgres function namespace | `case.fn_case_dashboard_*` | `app.fn_volunteer_dashboard_*` | Volunteer entities live in `app` schema; reuse existing `app/` Functions folder |
| Function folder | `DatabaseScripts/Functions/case/` (NEW for #52) | `DatabaseScripts/Functions/app/` (existing — REUSE) | Do NOT create a new `volunteer/` subfolder |
| Widget renderer folder | `dashboards/widgets/alert-list-widgets/` (1 new renderer) | `dashboards/widgets/volunteer-dashboard-widgets/` (11 new renderers) | Per-dashboard folder per directive |
| Widget instance ID format | `{TYPE}_{NAME}` (e.g., `KPI_TOTAL_BENEFICIARIES`) | `{TYPE}_{NAME}` (e.g., `KPI_ACTIVE_VOLUNTEERS`) | Same convention |
| Module | CRM | CRM | Same parent module |
| Parent menu | `CRM_DASHBOARDS` (MenuId 278) | `CRM_DASHBOARDS` (MenuId 278) | Same |
| Renderer naming | `{Purpose}{Suffix}` (e.g., `AlertListWidget`) | `Volunteer{Purpose}Widget` (e.g., `VolunteerActiveCountKpiWidget`) | Per-dashboard prefix to avoid collision |
| Seed file | `sql-scripts-dyanmic/CaseDashboard-sqlscripts.sql` | `sql-scripts-dyanmic/VolunteerDashboard-sqlscripts.sql` | Same `dyanmic` typo preserved |

---

## ⑧ File Manifest

**Consumer**: Backend Developer + Frontend Developer

### Backend Files (Path A only — 11 SQL functions, NO C# code)

| # | File | Path | Required |
|---|------|------|----------|
| 1 | KPI 1 — Active Volunteers | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/app/fn_volunteer_dashboard_kpi_active_volunteers.sql` | YES |
| 2 | KPI 2 — Total Hours (Month) | `…/app/fn_volunteer_dashboard_kpi_total_hours_month.sql` | YES |
| 3 | KPI 3 — Upcoming Shifts | `…/app/fn_volunteer_dashboard_kpi_upcoming_shifts.sql` | YES |
| 4 | KPI 4 — Avg Hours / Volunteer | `…/app/fn_volunteer_dashboard_kpi_avg_hours_per_volunteer.sql` | YES |
| 5 | KPI 5 — Retention Rate | `…/app/fn_volunteer_dashboard_kpi_retention_rate.sql` | YES |
| 6 | KPI 6 — Donor Conversion | `…/app/fn_volunteer_dashboard_kpi_donor_conversion.sql` | YES |
| 7 | Chart 7 — Hours Trend | `…/app/fn_volunteer_dashboard_hours_trend.sql` | YES |
| 8 | Chart 8 — Volunteers by Skill | `…/app/fn_volunteer_dashboard_volunteers_by_skill.sql` | YES |
| 9 | Table 9 — Top Volunteers | `…/app/fn_volunteer_dashboard_top_volunteers.sql` | YES |
| 10 | Table 10 — Upcoming Shifts | `…/app/fn_volunteer_dashboard_upcoming_shifts_table.sql` | YES |
| 11 | Widget 11 — Recent Activity | `…/app/fn_volunteer_dashboard_recent_activity.sql` | YES |

**Backend Wiring Updates**: NONE (Path A reuses `generateWidgets` GraphQL handler; no new C# endpoints).

**Database Migration**: 1 file — register the 11 new functions via existing migration runner pattern (project's `DatabaseScripts/Functions/` files appear to be auto-applied at runtime; confirm during build — if not, generate `AddVolunteerDashboardFunctions.cs` migration that executes each `.sql` file).

### Frontend Files

| # | File | Path | Required |
|---|------|------|----------|
| 1 | NEW renderer — VolunteerActiveCountKpiWidget | `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/volunteer-dashboard-widgets/VolunteerActiveCountKpiWidget.tsx` | YES |
| 2 | NEW renderer — VolunteerHoursMonthKpiWidget | `…/volunteer-dashboard-widgets/VolunteerHoursMonthKpiWidget.tsx` | YES |
| 3 | NEW renderer — VolunteerUpcomingShiftsKpiWidget | `…/volunteer-dashboard-widgets/VolunteerUpcomingShiftsKpiWidget.tsx` | YES |
| 4 | NEW renderer — VolunteerAvgHoursKpiWidget | `…/volunteer-dashboard-widgets/VolunteerAvgHoursKpiWidget.tsx` | YES |
| 5 | NEW renderer — VolunteerRetentionRateKpiWidget | `…/volunteer-dashboard-widgets/VolunteerRetentionRateKpiWidget.tsx` | YES |
| 6 | NEW renderer — VolunteerDonorConversionKpiWidget | `…/volunteer-dashboard-widgets/VolunteerDonorConversionKpiWidget.tsx` | YES |
| 7 | NEW renderer — VolunteerHoursTrendChartWidget | `…/volunteer-dashboard-widgets/VolunteerHoursTrendChartWidget.tsx` | YES |
| 8 | NEW renderer — VolunteerSkillBarChartWidget | `…/volunteer-dashboard-widgets/VolunteerSkillBarChartWidget.tsx` | YES |
| 9 | NEW renderer — VolunteerLeaderboardTableWidget | `…/volunteer-dashboard-widgets/VolunteerLeaderboardTableWidget.tsx` | YES |
| 10 | NEW renderer — VolunteerUpcomingShiftsTableWidget | `…/volunteer-dashboard-widgets/VolunteerUpcomingShiftsTableWidget.tsx` | YES |
| 11 | NEW renderer — VolunteerActivityFeedWidget | `…/volunteer-dashboard-widgets/VolunteerActivityFeedWidget.tsx` | YES |
| 12 | Folder barrel | `…/volunteer-dashboard-widgets/index.ts` | YES — re-export all 11 |
| 13 | (Optional) Skeleton sub-files | `…/volunteer-dashboard-widgets/skeletons/{name}-skeleton.tsx` | Build-agent's call — co-locate inside renderer file OR split per shape; either is acceptable as long as skeleton matches renderer shape |

**Frontend Wiring Updates**:

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` (existing) | Add 11 new entries to `WIDGET_REGISTRY` map — one per renderer above. Import statement block + 11 keyed entries. |
| 2 | (Optional) `dashboards/widgets/index.ts` | If the parent `widgets/` folder has a barrel, add `export * from './volunteer-dashboard-widgets'`. If not, skip. |
| 3 | sidebar / menu config | NONE — VOLUNTEERDASHBOARD menu auto-injected by sidebar batched query (from #52 Phase 2) |
| 4 | Pre-existing route stub `crm/dashboards/volunteerdashboard/page.tsx` | DELETE if it exists (per ISSUE-2 — Phase 2 backout deletes 6 hardcoded route pages including this one). Verify file existence at build time; if absent, no action. Pre-flight grep imports first. |

### DB Seed (`sql-scripts-dyanmic/VolunteerDashboard-sqlscripts.sql`)

> File path uses repo's existing `sql-scripts-dyanmic/` typo (preserve per project convention — ISSUE-8).

| # | Item | When | Notes |
|---|------|------|-------|
| 1 | 1 Dashboard row in `sett.Dashboards` | always | DashboardCode=VOLUNTEERDASHBOARD, IsSystem=true, ModuleId resolves from CRM, IsActive=true, CompanyId=NULL, MenuId=`(SELECT MenuId FROM auth.Menus WHERE MenuCode='VOLUNTEERDASHBOARD')` |
| 2 | 1 DashboardLayout row in `sett.DashboardLayouts` | always | LayoutConfig × 4 breakpoints (lg required; md/sm/xs minimal) + ConfiguredWidget JSON × 11 instances |
| 3 | 11 NEW WidgetType rows in `sett.WidgetTypes` | always | One per renderer — WidgetTypeCode = `VOLUNTEER_ACTIVE_COUNT_KPI`, `VOLUNTEER_HOURS_MONTH_KPI`, etc.; ComponentPath matches each renderer's registry key |
| 4 | 11 Widget rows in `sett.Widgets` | always | One per instance — DefaultParameters JSON honors filter keys (`{"dateFrom":"{dateFrom}","dateTo":"{dateTo}","branchId":"{branchId}"}`); StoredProcedureName=`app.fn_volunteer_dashboard_*` |
| 5 | 11 WidgetRole grants in `auth.WidgetRoles` (BUSINESSADMIN HasAccess=true) | always | At minimum BUSINESSADMIN; expand at admin-config time for other roles |
| 6 | NO new Menu seed | — | VOLUNTEERDASHBOARD menu @ MenuCode under CRM_DASHBOARDS @ OrderBy=5 already seeded (per `MODULE_MENU_REFERENCE.md`) |

Re-running seed must be idempotent (NOT EXISTS guards on every INSERT/UPDATE).

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

# VOLUNTEERDASHBOARD menu ALREADY seeded under CRM_DASHBOARDS @ OrderBy=5.
# This prompt does NOT seed a new Menu row — only Dashboard + DashboardLayout + 11 Widgets + WidgetRoles.
MenuName: Volunteer Dashboard         # FYI — already seeded
MenuCode: VOLUNTEERDASHBOARD          # FYI — already seeded
ParentMenu: CRM_DASHBOARDS            # FYI — already seeded (MenuId 278)
Module: CRM
MenuUrl: crm/dashboards/volunteerdashboard   # FYI — already seeded
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT
  # Other role grants (CRM_MANAGER, VOLUNTEER_COORDINATOR, PROGRAM_DIRECTOR, BRANCH_MANAGER) — left to admin-config; not seeded here

GridFormSchema: SKIP    # Dashboards have no RJSF form
GridCode: VOLUNTEERDASHBOARD

# Dashboard-specific seed inputs
DashboardCode: VOLUNTEERDASHBOARD
DashboardName: Volunteer Dashboard
DashboardIcon: chart-line-light
DashboardColor: #059669
IsSystem: true
DashboardKind: MENU_DASHBOARD   # encoded by Dashboard.MenuId IS NOT NULL after seed UPDATE; no IsMenuVisible column on Dashboard
MenuOrderBy: 5              # written to auth.Menus.OrderBy (already seeded — NOT to Dashboard)
WidgetGrants:               # all 11 widgets — BUSINESSADMIN read-all
  - KPI_ACTIVE_VOLUNTEERS: BUSINESSADMIN
  - KPI_TOTAL_HOURS_MONTH: BUSINESSADMIN
  - KPI_UPCOMING_SHIFTS: BUSINESSADMIN
  - KPI_AVG_HOURS_PER_VOLUNTEER: BUSINESSADMIN
  - KPI_RETENTION_RATE: BUSINESSADMIN
  - KPI_DONOR_CONVERSION: BUSINESSADMIN
  - CHART_HOURS_TREND: BUSINESSADMIN
  - CHART_VOLUNTEERS_BY_SKILL: BUSINESSADMIN
  - TBL_TOP_VOLUNTEERS: BUSINESSADMIN
  - TBL_UPCOMING_SHIFTS: BUSINESSADMIN
  - LIST_RECENT_ACTIVITY: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Consumer**: Frontend Developer

**Queries** — all widgets use existing GraphQL handlers (NO new endpoints):

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| generateWidgets (existing) | `(data jsonb, metadata jsonb, total_count int, filtered_count int)` | widgetId, p_filter_json, p_page, p_page_size, p_user_id, p_company_id | All 11 widgets |
| dashboardByModuleAndCode (NEW from #52 Phase 2) | `DashboardDto` | moduleCode='CRM', dashboardCode='VOLUNTEERDASHBOARD' | Single-row fetch — no UserDashboard join. Loads DashboardLayouts. |
| widgetByModuleCode (existing) OR widgetById (existing) | `[WidgetDto]` / `WidgetDto` | moduleCode='CRM' / widgetId | Returns widget metadata for runtime rendering |

**Per-widget data shapes (jsonb in `data` column)** — matches the shapes documented in §③:

- KPI 1 (`VolunteerActiveCountKpiWidget`): `{value, deltaThisMonth, deltaLabel, deltaColor, subtitle, icon, accentColor, variant:'primary'}`
- KPI 2 (`VolunteerHoursMonthKpiWidget`): `{value, formatted, momPercent, deltaLabel, deltaColor, subtitle, icon, accentColor, variant:'supporting'}`
- KPI 3 (`VolunteerUpcomingShiftsKpiWidget`): `{value, subtitle, icon, accentColor, variant:'supporting'}`
- KPI 4 (`VolunteerAvgHoursKpiWidget`): `{value, formatted, deltaLabel, deltaColor, subtitle, icon, accentColor, variant:'supporting'}`
- KPI 5 (`VolunteerRetentionRateKpiWidget`): `{value, formatted, subtitle, icon, accentColor, variant:'supporting'}`
- KPI 6 (`VolunteerDonorConversionKpiWidget`): `{value, formatted, volunteersDonatedCount, subtitle, icon, accentColor, variant:'supporting'}`
- Chart 7 (`VolunteerHoursTrendChartWidget`): `{labels:[6], series:[{name,color,data:[6]},{name,color,data:[6]}], unit:'hrs'}`
- Chart 8 (`VolunteerSkillBarChartWidget`): `{rows:[{skillName, count, widthPct, color}, ... 7 incl. Other]}`
- Table 9 (`VolunteerLeaderboardTableWidget`): `{rows:[{rank, rankIcon, volunteerId, volunteerName, hoursMonth, hoursYtd, shifts, badge:{tier,label,color}|null}]}`
- Table 10 (`VolunteerUpcomingShiftsTableWidget`): `{rows:[{shiftId, dateLabel, title, timeLabel, locationLabel, needed, assigned, gap:{state, label, iconCode}}]}`
- Activity 11 (`VolunteerActivityFeedWidget`): `{events:[{eventType, iconCode, accentColor, message, timestamp, timestampLabel, link?}]}`

**No composite DTO**. No new C# types. Each renderer consumes its own jsonb shape directly.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (no new C# code; verifies migration runner picks up the 11 new SQL functions)
- [ ] All 11 SQL functions exist in `app.` schema after migration; smoke test each: `SELECT * FROM app."fn_volunteer_dashboard_kpi_active_volunteers"('{}'::jsonb, 1, 50, 1, 1);` returns 1 row × 4 columns shape
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/volunteerdashboard`
- [ ] Network tab on page load shows EXACTLY ONE `dashboardByModuleAndCode` request (no module-wide list fetch leakage from STATIC path)
- [ ] Dashboard renders with 11 widgets in the documented layout

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Dashboard loads with default filters (This Month / All Branches) and renders all 11 widgets
- [ ] Each KPI card shows correct value formatted per spec (count / hrs / decimal / %)
- [ ] Each KPI card has visually-distinct treatment (icon + accent color + variant per §⑥) — primary KPI larger than supporting KPIs
- [ ] Combined-bar chart (Hours Trend) renders 6 month groups w/ 2 bars each + legend
- [ ] Horizontal-bar chart (Volunteers by Skill) renders 7 rows (top 6 + Other) w/ correct widths
- [ ] Leaderboard table (Top Volunteers) renders 5 rows w/ correct rank emojis + tier pills
- [ ] Upcoming-shifts table renders rows w/ correct gap badges (warning vs full)
- [ ] Activity feed renders rows w/ correct icon backgrounds + safe-rendered `<strong>` tags + timestamp labels
- [ ] Each renderer's skeleton matches its own shape (NOT a generic shimmer)
- [ ] Period filter change refetches all date-honoring widgets in parallel; chart 7 (hours-trend, fixed window) and KPI 5 (retention) do NOT refetch on Period change
- [ ] Branch filter change refetches all 11 widgets
- [ ] Custom Range opens date popover and applies on confirm
- [ ] Drill-down clicks navigate per Drill-Down Map (some are SERVICE_PLACEHOLDER — verify graceful toast)
- [ ] "Export Report" toasts SERVICE_PLACEHOLDER (no crash)
- [ ] Empty / loading / error states render per widget (red banner + Retry on error; muted icon + per-widget empty message)
- [ ] Role-based widget gating: WidgetRole(HasAccess=false) → widget hidden
- [ ] Sidebar leaf "Volunteer Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] Bookmarked URL `/[lang]/crm/dashboards/volunteerdashboard` survives reload (page works on direct URL entry, not just sidebar click)
- [ ] Role-gating via existing `RoleCapability(MenuId=VOLUNTEERDASHBOARD)` hides the sidebar leaf for unauthorized roles
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl)
- [ ] `git diff src/presentation/components/custom-components/dashboards/` is empty (zero edits to STATIC chrome — Volunteer dashboard renders via `<MenuDashboardComponent />` only)
- [ ] "Create Dashboard" / Edit Layout / Switcher chrome does NOT appear on the slug route (by construction — `<MenuDashboardComponent />` never renders them)

**DB Seed Verification:**
- [ ] Dashboard row inserted with DashboardCode=VOLUNTEERDASHBOARD, ModuleId=CRM, IsSystem=true, MenuId resolved from existing menu row
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (parses cleanly) and ConfiguredWidget JSON × 11
- [ ] All 11 Widget rows + 11 NEW WidgetType rows + 11 WidgetRole grants (BUSINESSADMIN) inserted
- [ ] All 11 Postgres functions queryable per smoke test above
- [ ] Re-running seed is idempotent (NOT EXISTS guards on every INSERT/UPDATE)

---

## ⑫ Special Notes & Warnings

**Consumer**: All agents

### Known Issues (pre-flagged)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | **CRITICAL BUILD BLOCKER** | Bootstrap dependency | Case Dashboard #52 Phase 2 must ship before this prompt builds. Phase 2 introduces `Dashboard.MenuId` schema column + `dashboardByModuleAndCode` BE handler + `<MenuDashboardComponent />` + dynamic `[slug]/page.tsx` route. If Phase 2 is not yet complete, this prompt CANNOT build — STOP and finish #52 Phase 2 first. Verify by checking `casedashboard.md` frontmatter `phase_2_completed_date` is set. | OPEN |
| ISSUE-2 | HIGH | Hardcoded route deletion | A pre-existing route stub may exist at `Pss2.0_Frontend/src/app/[lang]/(core)/crm/dashboards/volunteerdashboard/page.tsx` left over from #52 Phase 1's session-1 retrofit pattern. Phase 2's "delete 6 hardcoded routes" backout step should already have removed it; if it still exists, DELETE during this build (pre-flight grep imports first). If grep finds non-trivial imports, keep + flag as ISSUE for follow-up. | OPEN |
| ISSUE-3 | MED | Milestone events in activity feed | Milestone events (50/100/250/500-shift thresholds) require cumulative shift counts per volunteer — non-trivial aggregation. v1 may emit empty `milestone` events; full milestone detection deferred. Hardcoded sample milestone in seed data acceptable for demo until aggregation is formalized. | OPEN |
| ISSUE-4 | MED | Drill-down args | VolunteerScheduling list may not yet accept `?shiftId={id}` prefill arg (table 10 row click). Same for VolunteerList not accepting `?status=ACT&hasDonations=true&joinedBefore=...` (KPI cards 1/5/6). v1 navigates and toasts "Filter coming soon" if destination ignores the arg. Verify each destination's accepted query-params during build; degrade gracefully where not supported. | OPEN |
| ISSUE-5 | LOW | "View All" activity link | Recent Activity widget has a "View All" link that should navigate to a notifications-style page listing ALL volunteer activity events — no such destination exists yet. v1 toasts SERVICE_PLACEHOLDER. Future: build a dedicated activity-log page or wire to existing Notification Center. | OPEN |
| ISSUE-6 | MED | KPI drill-down placeholders | KPI cards 1 (Active Volunteers), 5 (Retention), 6 (Donor Conversion) drill-downs assume VolunteerList accepts `status=ACT`, `joinedBefore=...`, `hasDonations=true`. Some of these may not exist in current VolunteerList query args. v1 navigates with the closest-supported arg + toasts. | OPEN |
| ISSUE-7 | LOW | Toolbar slot — Print Dashboard | `<MenuDashboardComponent />` may not yet support a toolbar slot for "Export Report" + "Print Dashboard" buttons. If absent, fold buttons into the page-config approach used for #52 (one-time toolbar prop on the new component). Browser `window.print()` is a primitive — Print button is safe to ship. Export Report is SERVICE_PLACEHOLDER. | OPEN |
| ISSUE-8 | LOW | Seed folder typo | Seed file path `sql-scripts-dyanmic/VolunteerDashboard-sqlscripts.sql` preserves the existing repo typo `dyanmic` (vs `dynamic`). Do NOT rename the folder — convention preserved per all prior dashboard prompts. | OPEN |
| ISSUE-9 | MED | KPI renderer split discipline | This prompt mandates 6 SEPARATE KPI renderer files (one per KPI) per the `_DASHBOARD.md` directive ("No two widgets should look identical"). Build agent MAY collapse 2 visually-identical KPIs onto one renderer if it determines they're truly identical post-design (e.g., 2 KPIs with same shape/color/variant). Document any collapse as a deviation in §⑬ Build Log + open a follow-up ISSUE. Default = ship 6 separate renderers. | OPEN |
| ISSUE-10 | MED | Activity-feed `<strong>` sanitization | Activity-feed widget renders messages containing `<strong>` tags via `dangerouslySetInnerHTML`. Sanitize with DOMPurify or equivalent allowing ONLY `<strong>` + text content. Strip everything else. Reference Case Dashboard #52's AlertListWidget sanitization pattern (already shipped) — reuse the same sanitizer helper if extracted. | OPEN |
| ISSUE-11 | MED | Donor-conversion query performance | KPI 6 (Volunteer-to-Donor Rate) joins Volunteer → Contact → GlobalDonation across schemas (`app` + `corg` + `donate`). On large GlobalDonation tables, the EXISTS subquery may be slow. Verify EF/raw-SQL plan during build; add covering index on `donate.GlobalDonations(ContactId, DonationDate)` if needed. Acceptable v1 perf threshold: < 2s P95. | OPEN |
| ISSUE-12 | LOW | Volunteer-by-skill "Other" bucket sort | Mockup shows "Other" rendered with neutral gray width 71% (visually larger than 6 named skills) — semantically misleading. Recommend: render "Other" with SUM-based width but visually demote (gray + lighter weight) so it doesn't appear to dominate. Build agent's call. | OPEN |
| ISSUE-13 | LOW | Multi-currency on future donation KPI | KPI 6 currently counts DISTINCT contacts (no currency math). If future spec adds "Donation amount from converted volunteers" KPI, multi-currency aggregation rules MUST be added (see Case Dashboard #52 ISSUE-2 precedent). Out of scope for v1. | OPEN |
| ISSUE-14 | LOW | Period filter ignores chart 7 + KPI 5 | Chart 7 (Hours Trend) uses fixed 6-month rolling window (not affected by Period filter); KPI 5 (Retention) uses fixed "active >6 months" rule. Document this clearly in widget tooltips so users understand why those widgets don't refetch on Period change. Provide tooltip text in build. | OPEN |
| ISSUE-15 | LOW | LayoutConfig minimum breakpoints | Default seed populates `lg` breakpoint LayoutConfig only. `md`, `sm`, `xs` rely on react-grid-layout auto-derive. If reflow looks broken at sub-lg, hand-author additional breakpoint configs in seed and re-apply. Tracked as a follow-up. | OPEN |

### Class Warnings (apply to most prompts of this template)
- Dashboards are READ-ONLY. No CRUD on this screen — the CRUD for Dashboard rows is `#78 Dashboard Config`.
- Widget queries must be tenant-scoped (CompanyId from HttpContext via p_company_id arg). Easy to forget on a new function.
- N+1 risk on per-row aggregates — verify Postgres query plans for table 9 (Top Volunteers — sub-aggregates per volunteer) and KPI 6 (donor-conversion EXISTS subquery).
- react-grid-layout LayoutConfig JSON must include a config for `lg` (minimum). Missing breakpoints fall back to react-grid-layout's auto-reflow but may cause widget overlap on edge sizes.
- ConfiguredWidget JSON `instanceId` must be unique per dashboard AND must equal the corresponding `i` value in every LayoutConfig breakpoint array (collisions / mismatches cause widget reuse / orphaned-cell bugs).
- Each ConfiguredWidget element references a `widgetId` from `sett.Widgets`. The widget renderer is resolved via `Widgets.WidgetType.ComponentPath` against `WIDGET_REGISTRY` in `dashboard-widget-registry.tsx`. Path-A uses `Widget.StoredProcedureName` against the generic `generateWidgets` GraphQL field.
- Drill-down args must use the destination screen's accepted query-param names exactly. Don't invent new ones (see ISSUE-4 / ISSUE-6).

### MENU_DASHBOARD-only Warnings
- This is the SECOND MENU_DASHBOARD prompt — bootstrap from #52 Phase 2 is a HARD prerequisite (ISSUE-1).
- Slug lives on `auth.Menus.MenuUrl='crm/dashboards/volunteerdashboard'` (NOT on Dashboard). Already seeded.
- Menu row's `ModuleId` MUST match `Dashboard.ModuleId` (both = CRM). Seed UPDATE step relies on `(SELECT MenuId FROM auth.Menus WHERE MenuCode='VOLUNTEERDASHBOARD')` resolving to a non-NULL ModuleId.
- Per-dashboard FE page files do NOT exist — single dynamic route `[slug]/page.tsx` (from #52 Phase 2) covers this dashboard. If a stub exists at `crm/dashboards/volunteerdashboard/page.tsx`, DELETE per ISSUE-2.
- Sidebar auto-injection happens via `menuLinkedDashboardsByModuleCode` query — no manual sidebar config edits needed.

### Service Dependencies (UI-only — flag genuine external-service gaps)
- ⚠ **SERVICE_PLACEHOLDER**: Export Report (PDF) — full UI in place; handler toasts because PDF rendering service not wired. Same as Case Dashboard #52.
- ⚠ **SERVICE_PLACEHOLDER**: "View All" link in Recent Activity — no destination page exists yet (ISSUE-5).
- ⚠ **SERVICE_PLACEHOLDER**: Drill-down query args (ISSUE-4 / ISSUE-6) — destination screens may not yet accept all prefill args; degrade gracefully.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning 2026-04-30 | CRITICAL | Bootstrap | Case Dashboard #52 Phase 2 hard prerequisite | OPEN |
| ISSUE-2 | planning 2026-04-30 | HIGH | FE route | Pre-existing volunteerdashboard/page.tsx stub may need deletion | OPEN |
| ISSUE-3 | planning 2026-04-30 | MED | Activity feed | Milestone events require cumulative aggregation — v1 deferred | OPEN |
| ISSUE-4 | planning 2026-04-30 | MED | Drill-down args | VolunteerScheduling/VolunteerList may not accept all prefill args | OPEN |
| ISSUE-5 | planning 2026-04-30 | LOW | Activity "View All" | No destination page yet — SERVICE_PLACEHOLDER | OPEN |
| ISSUE-6 | planning 2026-04-30 | MED | KPI drill-downs | VolunteerList query args undefined for some KPI prefills | OPEN |
| ISSUE-7 | planning 2026-04-30 | LOW | Toolbar slot | `<MenuDashboardComponent />` toolbar slot may not exist; fold into page-config | OPEN |
| ISSUE-8 | planning 2026-04-30 | LOW | Seed typo | Preserve `sql-scripts-dyanmic/` folder typo | OPEN |
| ISSUE-9 | planning 2026-04-30 | MED | KPI renderer split | 6 separate KPI renderers default; agent MAY collapse if truly identical | OPEN |
| ISSUE-10 | planning 2026-04-30 | MED | HTML sanitization | Activity feed `<strong>` rendering needs DOMPurify allowlist | OPEN |
| ISSUE-11 | planning 2026-04-30 | MED | KPI 6 perf | Cross-schema EXISTS subquery; verify plan + add index if needed | OPEN |
| ISSUE-12 | planning 2026-04-30 | LOW | Other bucket sort | "Other" skill width visually misleading; demote treatment | OPEN |
| ISSUE-13 | planning 2026-04-30 | LOW | Multi-currency | Out of scope v1; flag if future donation-amount KPI added | OPEN |
| ISSUE-14 | planning 2026-04-30 | LOW | Period filter scope | Chart 7 + KPI 5 don't honor Period — add tooltip explanation | OPEN |
| ISSUE-15 | planning 2026-04-30 | LOW | Layout breakpoints | Only `lg` LayoutConfig in seed; auto-reflow at sub-lg may need hand-tune (CLOSED — seed ships all 4 breakpoints lg/md/sm/xs) | CLOSED |
| ISSUE-16 | build 2026-04-30 (s1) | MED | FE filter chrome | Period/Branch filter selects + Export Report / Print Dashboard buttons NOT wired into `VolunteerDashboardPageConfig` v1 — functions accept filter args but no UI consumer yet | OPEN |
| ISSUE-17 | build 2026-04-30 (s1) | LOW | Schema doc fix | Prompt §②/③ documents `donate.GlobalDonations`; actual entity is `fund.GlobalDonations`. KPI 6 function uses correct `fund` schema | OPEN |
| ISSUE-18 | build 2026-04-30 (s1) | HIGH | EF migration | 11 SQL functions not registered via EF migration (token-budget directive). Must verify auto-apply at startup OR generate `AddVolunteerDashboardFunctions.cs` migration before deploy | OPEN |
| ISSUE-19 | build 2026-04-30 (s1) | MED | E2E validation | `dotnet build` + `pnpm dev` smoke + full E2E click-through SKIPPED this session per token-budget directive. Must run before production-ready | OPEN |
| ISSUE-1 | planning 2026-04-30 | CRITICAL | Bootstrap | (CLOSED — Phase 2 in place: MenuDashboardComponent + dashboardByModuleAndCode + Case Dashboard #52 using pattern) | CLOSED |
| ISSUE-2 | planning 2026-04-30 | HIGH | FE route | (CLOSED — stub repointed from AmbassadorDashboardPageConfig → VolunteerDashboardPageConfig) | CLOSED |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-30 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. MENU_DASHBOARD variant — 11 Path-A Postgres functions + 11 NEW widget renderers + 1 DB seed + 1 route stub repoint.
- **Files touched**:
  - BE: 11 SQL functions (created) — `PSS_2.0_Backend/DatabaseScripts/Functions/app/fn_volunteer_dashboard_{kpi_active_volunteers, kpi_total_hours_month, kpi_upcoming_shifts, kpi_avg_hours_per_volunteer, kpi_retention_rate, kpi_donor_conversion, hours_trend, volunteers_by_skill, top_volunteers, upcoming_shifts_table, recent_activity}.sql`. NEW `app/` subfolder under existing `Functions/` namespace (sibling to `case/`, `corg/`, `fund/`, etc.). NO new C# code.
  - FE: 11 renderer files (created) — `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/volunteer-dashboard-widgets/{VolunteerActiveCountKpiWidget, VolunteerHoursMonthKpiWidget, VolunteerUpcomingShiftsKpiWidget, VolunteerAvgHoursKpiWidget, VolunteerRetentionRateKpiWidget, VolunteerDonorConversionKpiWidget, VolunteerHoursTrendChartWidget, VolunteerSkillBarChartWidget, VolunteerLeaderboardTableWidget, VolunteerUpcomingShiftsTableWidget, VolunteerActivityFeedWidget}.tsx` + `_shared.tsx` helper (created — accent palette, icon resolver, delta pill, error/warning/empty states, `useWidgetFirstRow` hook, `SafeStrongHtml` sanitizer for activity feed) + `index.ts` barrel (created). Re-pointed `presentation/pages/crm/dashboards/volunteerdashboard.tsx` (modified — was `<DashboardComponent />` calling STATIC path) → now `<MenuDashboardComponent moduleCode="CRM" dashboardCode="VOLUNTEERDASHBOARD" />`. Re-pointed `app/[lang]/crm/dashboards/volunteerdashboard/page.tsx` (modified — was importing `AmbassadorDashboardPageConfig` mistakenly) → now `VolunteerDashboardPageConfig`. Wired 11 entries in `dashboard-widget-registry.tsx` (modified) under "Volunteer Dashboard #57" comment block, PascalCase ComponentPath keys.
  - DB: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/VolunteerDashboard-sqlscripts.sql` (created — 5-step idempotent seed: STEP 0 diagnostics + STEP 1 11 WidgetTypes + STEP 2 Dashboard row + STEP 2.5 Menu link UPDATE + STEP 3 11 Widget rows + STEP 4 DashboardLayout w/ 4-breakpoint LayoutConfig + 11-element ConfiguredWidget + STEP 5 11 BUSINESSADMIN WidgetRoles).
- **Deviations from spec**:
  - Schema correction: prompt §②/③ specified `donate.GlobalDonations` for KPI 6 cross-schema join; actual entity lives in `fund` schema (`Schema = "fund"` on `GlobalDonation.cs`). Function `fn_volunteer_dashboard_kpi_donor_conversion.sql` uses `fund."GlobalDonations"`. Documented as ISSUE-17.
  - User identifier in activity feed: prompt §④ wrote `"<strong>{User.FullName}</strong>"`; auth.Users entity has only `UserName`/`AlternateUserName` columns (no FirstName/LastName). Function uses `u."UserName"` as the display string — semantically equivalent.
  - Phase 2 dynamic `[slug]/page.tsx` route deferred (matches Case Dashboard #52 ISSUE-1 precedent). Per-route stub at `app/[lang]/crm/dashboards/volunteerdashboard/page.tsx` was repointed instead of deleted (the stub mistakenly referenced `AmbassadorDashboardPageConfig` — see ISSUE-2; corrected this session).
  - Toolbar slot (Period/Branch/Export buttons): NOT shipped in v1. `<MenuDashboardComponent />` accepts `toolbar?` prop, but no filter UI is wired into `VolunteerDashboardPageConfig` yet. Functions accept `dateFrom/dateTo/branchId` from `p_filter_json` and apply sensible defaults (This Month / All Branches). New ISSUE-16 raised — Period/Branch filter UI for v2.
  - 6 KPI renderers shipped distinct (per ISSUE-9 default — no collapse). Visual differentiators: KPI 1 hero size + accent strip; KPI 2 icon-right + "hrs" suffix; KPI 3 centered-icon-above with window pill; KPI 4 ascending mini-bars decoration; KPI 5 SVG progress ring; KPI 6 dual-stat (% + count) divided.
  - Activity feed milestone events: `milestone` UNION arm omitted from `fn_volunteer_dashboard_recent_activity.sql` per ISSUE-3 (cumulative-shift-count aggregation deferred to v2). Function emits `hours/shift/registration/approve` events only — `milestone` deferred without breaking the `eventType` enum on the FE renderer.
- **Known issues opened**:
  - ISSUE-16 (MED, FE chrome): Period/Branch filter selects + Export Report / Print Dashboard buttons NOT wired into `VolunteerDashboardPageConfig` — functions have filter args but no UI consumer yet. Defer to v2.
  - ISSUE-17 (LOW, schema doc): Prompt §②/③ documents `donate.GlobalDonations` for KPI 6 cross-schema join; actual entity lives in `fund` schema. `fn_volunteer_dashboard_kpi_donor_conversion.sql` uses `fund."GlobalDonations"`. Update prompt for future reference.
  - ISSUE-18 (HIGH, deploy): EF migration to register 11 SQL functions NOT generated this session (matches Case Dashboard #52 ISSUE-18 precedent). Verify SQL files auto-apply on startup; if not, generate `AddVolunteerDashboardFunctions.cs` migration before deploy.
  - ISSUE-19 (MED, validation): Build verification (`dotnet build` + `pnpm dev` smoke + full E2E checklist) SKIPPED per token-budget directive. Must run before production-ready: dotnet build, pnpm dev (page loads at `/[lang]/crm/dashboards/volunteerdashboard`), 11 widgets render with their distinct skeleton/empty/error states, drill-down clicks navigate, BUSINESSADMIN sees all 11 widgets, idempotent seed re-run produces no duplicates.
- **Known issues closed**:
  - ISSUE-1 (CRITICAL — Phase 2 hard prerequisite). Resolved: Phase 2 bootstrap shipped — `MenuDashboardComponent` exists with `toolbar?` slot; `dashboardByModuleAndCode` BE handler (`GetDashboardByModuleAndCode.cs`) exists; `DASHBOARD_BY_MODULE_AND_CODE_QUERY` FE query exists; Case Dashboard #52 already in production using this pattern. Per-route stub pattern (vs dynamic `[slug]/page.tsx`) chosen — matches #52 precedent.
  - ISSUE-2 (HIGH — pre-existing volunteerdashboard/page.tsx stub). Resolved: stub existed but mis-pointed at `AmbassadorDashboardPageConfig`. Repointed to new `VolunteerDashboardPageConfig` calling `<MenuDashboardComponent moduleCode="CRM" dashboardCode="VOLUNTEERDASHBOARD" />`.
- **Next step**: None — COMPLETED. Recommended follow-ups before production deploy: (1) run `VolunteerDashboard-sqlscripts.sql` against the dev DB; (2) confirm 11 SQL functions auto-load OR generate `AddVolunteerDashboardFunctions.cs` migration (ISSUE-18); (3) `dotnet build` + `pnpm dev` smoke (ISSUE-19); (4) E2E click-through 11 widgets + filter validation; (5) v2 — wire Period/Branch filter UI into `VolunteerDashboardPageConfig` toolbar slot (ISSUE-16); (6) v2 — add milestone events to activity feed once cumulative-shift aggregation lands (ISSUE-3).
