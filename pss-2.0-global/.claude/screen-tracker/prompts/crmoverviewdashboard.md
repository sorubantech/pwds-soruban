---
screen: CrmOverviewDashboard
registry_id: 120
module: CRM
status: PENDING
scope: ALIGN
screen_type: DASHBOARD
dashboard_variant: STATIC_DASHBOARD
complexity: Medium
new_module: NO
planned_date: 2026-05-19
completed_date:
last_session_date:
---

> ## Scope of this prompt — what "ALIGN" means for screen #120
>
> The chrome (`<DashboardComponent />`, `<DashboardHeader />` with switcher + Edit Layout + Refresh, dropdown, Apollo wiring) is **already shipped** and verified by the existing menu-promoted dashboards (Contact #123, Donation #124, etc.). The 6 module-overview route pages (`/[lang]/{module}/dashboards/overview/page.tsx`) **already exist** and already render `<DashboardComponent />`.
>
> What's MISSING that this prompt fills:
> 1. There is **no seeded `sett.Dashboards` row** for the CRM module's overview surface — meaning when a user lands on `/crm/dashboards/overview`, `DashboardComponent` fetches `dashboardByModuleCode('CRM')` and currently returns only the menu-promoted dashboards (Contact, Donation, Communication, Volunteer, Ambassador, Case). The dropdown filter rule `MenuId IS NULL` returns **zero rows** — so no default dashboard ever renders. The page loads an empty grid.
> 2. The mockup ([html_mockup_screens/dashboard.html](../../../html_mockup_screens/dashboard.html)) is the **target visual** for the CRM module overview. It defines 9 widgets across 4 logical rows.
> 3. **Per template preamble § "🆕 NEW widget renderers are the DEFAULT"** — `#120 Main Dashboard` (this screen and its 5 future siblings for the other 5 modules) is the **only documented exception** allowed to reuse legacy renderers. This prompt EXERCISES that exception: the 4 KPI cards reuse `StatusWidgetType1`; the 5 compound/list widgets need NEW renderers (no legacy renderer fits their shape).
> 4. This prompt covers **CRM only** (per user scope decision 2026-05-19). The other 5 module overviews (Organization, AccessControl, General, Setting, ReportAudit) will be planned as separate prompts that reuse this prompt's widget renderers + add their own module-scoped Postgres functions where data sources differ.
>
> What this prompt **does NOT** touch (preserve carefully):
> - `<DashboardComponent />`, `<DashboardHeader />`, `useDashboardStore`, IsDefault resolution path, Edit Layout / Save Layout / Reset Layout / Switcher chrome — **frozen**.
> - The 8 legacy renderers in `WIDGET_REGISTRY` (`StatusWidgetType1/2`, `MultiChartWidget`, `BarChartWidgetType1/2`, `ColumnChartWidgetType1`, `PieChartWidgetType1/2`, `RadialBarChartWidgetType1`, `NegativeLineChartWidget`, `TableWidgetType1`, `NormalTableWidget`, `FilterTableWidget`, `HtmlWidgetType1/2`, `GeographicHeatmapWidgetType1`, `ProfileWidgetType1`, `MeetingScheduleWidgetType1`) — **frozen**.
> - The 9 module-specific dashboard widget folders that already exist under `widgets/{name}-dashboard-widgets/` — **frozen**.
> - The `crm/dashboards/overview/page.tsx` file — already a 1-line wrapper for `<DashboardComponent />`; do not modify.

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (9 widgets across 4 logical sections: KPI strip → Retention card → Activity+QuickActions row → Approvals → Fundraising Progress)
- [x] Variant chosen — **STATIC_DASHBOARD** (lives at `/crm/dashboards/overview` via existing `DashboardComponent`; `MenuId IS NULL` → appears in module dropdown; selected by `UserDashboard.IsDefault=true` rule)
- [x] Source entities identified — Contact (corg.Contacts), GlobalDonation (corg.GlobalDonations), Campaign (corg.Campaigns), ContactEngagement (corg.ContactEngagementScores OR computed on-the-fly), Pledge, Refund, VolunteerHourLog, ImportSession, DuplicateContact — **all exist**
- [x] Widget catalog drafted (9 widgets: 4 KPI + 1 retention compound + 1 activity feed + 1 quick actions + 1 approvals table + 1 fundraising progress)
- [x] react-grid-layout config drafted (lg / md / sm / xs)
- [x] DashboardLayout JSON shape drafted (LayoutConfig + ConfiguredWidget per widget)
- [x] STATIC_DASHBOARD — no menu row needed (`Dashboard.MenuId = NULL`; surfaces via `dashboardByModuleCode('CRM')` dropdown)
- [x] Path-A (Postgres functions) chosen for 7 of 9 widgets — matches existing `corg.fn_contact_dashboard_*` / `corg.fn_donation_dashboard_*` pattern. Quick Actions widget has NO data source (action list baked into renderer).
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (mostly skip — §①–⑫ are pre-analyzed; precedent: Contact Dashboard #123)
- [ ] Solution Resolution complete (skip — Path-A across 7 widgets + 1 no-data Quick Actions widget dictated by §⑤)
- [ ] UX Design finalized (skip — §⑥ contains complete grid + widget detail)
- [ ] User Approval received
- [ ] Backend (Path-A): 7 Postgres functions in `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/corg/`:
      • `fn_crm_overview_kpi_total_contacts.sql`
      • `fn_crm_overview_kpi_donations_this_month.sql`
      • `fn_crm_overview_kpi_active_campaigns.sql`
      • `fn_crm_overview_kpi_avg_engagement_score.sql`
      • `fn_crm_overview_donor_retention.sql`
      • `fn_crm_overview_recent_activity.sql`
      • `fn_crm_overview_pending_approvals.sql`
      • `fn_crm_overview_fundraising_by_purpose.sql`
      (All conform to the 5-arg / 4-column Path-A contract — see §⑤). NO new C# code.
- [ ] FE renderers: REUSE `StatusWidgetType1` for the 4 KPI cards. CREATE **5 NEW renderers** under `widgets/main-dashboard-widgets/` (new folder — bespoke to this dashboard family):
      • `MainDashboardRetentionWidget.tsx` (big % + LYBUNT/SYBUNT side panel + 6-month bar trend in one compound card)
      • `MainDashboardActivityFeedWidget.tsx` (icon-coloured vertical timeline list, scrollable max-height)
      • `MainDashboardQuickActionsWidget.tsx` (2×4 button grid; static action list baked in; routes to existing screens)
      • `MainDashboardApprovalsWidget.tsx` (task + module-color-badge + priority pill + due date + action button column — `FilterTableWidget` can't render an action-column with route prefill)
      • `MainDashboardFundraisingProgressWidget.tsx` (horizontal stacked-color progress bars per purpose row)
- [ ] FE page-level: NO new page file. `/crm/dashboards/overview/page.tsx` stays as-is — it already renders `<DashboardComponent />`. Verify the page now picks up the seeded CRMOVERVIEW row.
- [ ] DB seed `sql-scripts-dyanmic/CrmOverviewDashboard-sqlscripts.sql`:
      • Dashboard row (DashboardCode=`CRMOVERVIEW`, DashboardName=`Overview`, ModuleId=(CRM), DashboardIcon=`ph:gauge`, IsSystem=true, IsActive=true, CompanyId=NULL, MenuId=NULL)
      • DashboardLayout row (LayoutConfig JSON × 4 breakpoints lg/md/sm/xs + ConfiguredWidget × 9)
      • Widget rows × 9 with appropriate `StoredProcedureName` (8) or NULL (1 — Quick Actions)
      • WidgetType rows × **5 NEW** (`MAINDASHBOARD_RETENTION`, `MAINDASHBOARD_ACTIVITY_FEED`, `MAINDASHBOARD_QUICK_ACTIONS`, `MAINDASHBOARD_APPROVALS`, `MAINDASHBOARD_FUNDRAISING_PROGRESS`)
      • WidgetRole grants × 9 (BUSINESSADMIN)
      • UserDashboard seed: for each existing BUSINESSADMIN user on CRM, INSERT a UserDashboard(UserId, DashboardId, IsDefault=true) so the dashboard auto-loads on first visit (matches existing seed pattern)
      • NO `auth.Menus` insert (STATIC_DASHBOARD — Dashboard.MenuId stays NULL)
- [ ] Registry updated to COMPLETED — REGISTRY row #120 Status → COMPLETED + Prompt → `prompts/crmoverviewdashboard.md`

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (no new C# changes; verify nothing breaks)
- [ ] `pnpm dev` — `/[lang]/crm/dashboards/overview` loads; widget grid renders 9 widgets (not the empty "no dashboards configured" state)
- [ ] Network tab shows expected GraphQL pattern: `dashboardByModuleCode(moduleCode:"CRM")` returns ≥1 row including CRMOVERVIEW; `generateWidgets(widgetId:..., parameters:...)` fires once per Path-A widget (8 total)
- [ ] Each KPI card (4) shows correct value formatted per spec (count / currency / count / score-out-of-100)
- [ ] Retention card renders 67.3% big number + 6-bar mini-chart + LYBUNT/SYBUNT counts in side panel + benchmark hint line
- [ ] Activity Feed renders 8 recent events with type-specific icons (donation / email / contact-add / refund-fail / volunteer-log / campaign-progress / grant-submission) and relative timestamps
- [ ] Quick Actions renders 8 buttons in 2×4 grid; each button navigates to the correct existing route on click (verify routes resolve)
- [ ] Pending Approvals table renders 5 sample rows with module-color badges (CRM/Collection/Fundraising/Volunteer/Grants), priority pills (High red / Medium amber / Low gray), due date strings, and action button routing to the correct destination screen
- [ ] Fundraising by Purpose renders top 5 purposes with colored horizontal progress bars + raised/goal amounts + percentage labels
- [ ] Dashboard switcher dropdown lists `Overview` + the 5 menu-promoted CRM dashboards filtered out (the rule is `MenuId IS NULL` → switcher includes Overview; menu-promoted ones don't show in switcher)
- [ ] role-based widget gating: deleting BUSINESSADMIN row from `auth.WidgetRoles` for a single widget hides that slot in the grid
- [ ] react-grid-layout reflow at xs / sm / md / lg / xl — widgets stack vertically on mobile, side-by-side on desktop
- [ ] DB seed is idempotent — re-running the script after Dashboard row exists does NOT INSERT a second row

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: CrmOverviewDashboard
Module: CRM
Schema: NONE (aggregates across `corg.*`, `sett.*`, `auth.*`)
Group: SettingModels (Dashboard seed lives in `sett.*`; aggregate functions live in `corg.*` namespace — matches Contact Dashboard precedent)

Dashboard Variant: STATIC_DASHBOARD — lives at the CRM module's main `/crm/dashboards/overview` route, rendered by the existing `<DashboardComponent />`. `MenuId IS NULL` → appears in the dashboard switcher dropdown alongside any user-created CRM dashboards. Auto-selected on first visit via `UserDashboard.IsDefault=true` rule.

Business: This is the landing screen every CRM user sees when they click the CRM module in the sidebar. The mockup defines the visual quality bar for the "home / module overview" pattern across all 6 modules — a glanceable cross-functional summary card pulling from the most-trafficked operational entities (Contacts, Donations, Campaigns, Engagement) on the top row; a single retention KPI compound card highlighting donor health; a recent-events feed surfacing the live operational pulse; a quick-actions deck for the 8 most common one-click jumps; a pending-approvals task queue concentrating cross-module action items in one place; and a fundraising-progress band showing campaign-purpose-level goal attainment for the current quarter. Target audience: every BUSINESSADMIN / Director-tier user who lands in CRM. Why it exists in the NGO workflow: NGO admins manage donations, contacts, campaigns, volunteers, grants, and field-collection batches simultaneously — the overview compresses 6 modules of state into a one-glance triage surface so they know what to look at next.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Dashboards do NOT introduce a new entity. They compose two seeded rows over existing entities.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `CRMOVERVIEW` | Unique within Company |
| DashboardName | `Overview` | Shown in switcher dropdown |
| DashboardIcon | `ph:gauge` | Phosphor icon — module overview gauge |
| DashboardColor | NULL | No accent — default chrome |
| ModuleId | (resolve `auth.Modules.ModuleId WHERE ModuleCode='CRM'`) | — |
| IsSystem | true | System-seeded |
| IsActive | true | — |
| MenuId | NULL | STATIC_DASHBOARD — NOT a menu-promoted leaf |
| CompanyId | NULL | Platform-wide template; per-tenant rows seeded via UserDashboard rather than per-company Dashboard rows (matches Contact Dashboard precedent) |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

One row per Dashboard. `LayoutConfig` and `ConfiguredWidget` JSON shapes defined in §⑥ Grid Layout. 9 widget instances total.

### C. Widget Definitions

5 NEW `sett.WidgetTypes` rows (no existing renderers fit the compound layouts):

| WidgetTypeCode | WidgetTypeName | ComponentPath | Description |
|----------------|----------------|---------------|-------------|
| `MAINDASHBOARD_RETENTION` | Main Dashboard — Retention | `MainDashboardRetentionWidget` | Compound: big % + 6-month bar trend + LYBUNT/SYBUNT counts |
| `MAINDASHBOARD_ACTIVITY_FEED` | Main Dashboard — Activity Feed | `MainDashboardActivityFeedWidget` | Icon-coloured timeline list (8 events, scrollable) |
| `MAINDASHBOARD_QUICK_ACTIONS` | Main Dashboard — Quick Actions | `MainDashboardQuickActionsWidget` | 2×4 button grid (static action catalog) |
| `MAINDASHBOARD_APPROVALS` | Main Dashboard — Approvals | `MainDashboardApprovalsWidget` | Task table with module badge + priority pill + due + action button column |
| `MAINDASHBOARD_FUNDRAISING_PROGRESS` | Main Dashboard — Fundraising Progress | `MainDashboardFundraisingProgressWidget` | Horizontal progress bars list (top 5 purposes) |

Plus 1 EXISTING `WidgetType` reused for the 4 KPI cards: `StatusWidgetType1`.

`sett.Widgets` — 9 rows (one per dashboard tile):

| WidgetName | WidgetTypeCode | StoredProcedureName | OrderBy |
|------------|----------------|---------------------|---------|
| Total Contacts | StatusWidgetType1 | `corg.fn_crm_overview_kpi_total_contacts` | 1 |
| Donations This Month | StatusWidgetType1 | `corg.fn_crm_overview_kpi_donations_this_month` | 2 |
| Active Campaigns | StatusWidgetType1 | `corg.fn_crm_overview_kpi_active_campaigns` | 3 |
| Avg Engagement Score | StatusWidgetType1 | `corg.fn_crm_overview_kpi_avg_engagement_score` | 4 |
| Donor Retention Rate | MAINDASHBOARD_RETENTION | `corg.fn_crm_overview_donor_retention` | 5 |
| Recent Activity | MAINDASHBOARD_ACTIVITY_FEED | `corg.fn_crm_overview_recent_activity` | 6 |
| Quick Actions | MAINDASHBOARD_QUICK_ACTIONS | NULL | 7 |
| Pending Approvals | MAINDASHBOARD_APPROVALS | `corg.fn_crm_overview_pending_approvals` | 8 |
| Fundraising by Purpose | MAINDASHBOARD_FUNDRAISING_PROGRESS | `corg.fn_crm_overview_fundraising_by_purpose` | 9 |

### D. Source Entities (read-only — what the widgets aggregate over)

| Source Entity | Used By Widget(s) | Aggregate(s) |
|---------------|-------------------|--------------|
| `corg.Contacts` | KPI Total Contacts | COUNT(*) WHERE IsActive AND CompanyId=tenant; delta = COUNT this month - COUNT prior month |
| `corg.GlobalDonations` | KPI Donations This Month + Retention + Fundraising Progress | SUM(DonationAmount) by date window / by DonationPurposeId; donor identity = ContactId; year-over-year SET intersection for retention |
| `corg.Campaigns` | KPI Active Campaigns + Fundraising Progress goal lookup | COUNT WHERE Status='Active'; SUM(GoalAmount) per purpose join |
| `corg.ContactEngagementScores` (or computed via `corg.Contacts.EngagementScore`) | KPI Avg Engagement | AVG(EngagementScore) |
| `corg.DonationPurposes` | Fundraising Progress | JOIN GlobalDonation → DonationPurpose for purpose-level rollup; ORDER BY raised DESC LIMIT 5 |
| `corg.Refunds` (or `corg.GlobalDonations.RefundStatus`) | Activity Feed + Pending Approvals | Failed transactions + pending refund items |
| `corg.GlobalDonationDistributions` | Activity Feed | Field-collection batch events (`DonationOriginType = 'FieldCollection'`) |
| `vol.VolunteerHourLogs` | Activity Feed + Pending Approvals | Recent hour-log entries + unapproved submissions |
| `crm.ImportSessions` | Activity Feed | Recent contact import completions |
| `corg.DuplicateContacts` (or `corg.PotentialDuplicates`) | Pending Approvals | Unreviewed duplicate pairs |
| `grant.GrantReports` | Pending Approvals + Activity Feed | Submitted / due grant reports |
| `audit.RecentActivityView` (if exists; ELSE composed UNION ALL) | Activity Feed | Mixed-source recent-event stream |

---

## ③ Source Entity & Aggregate Query Resolution

> **Consumer**: Backend Developer + Frontend Developer
> Replaces the FK Resolution Table from MASTER_GRID/FLOW. Path-A widgets do not have GQL handlers — they use the generic `generateWidgets` handler. Below are the Postgres function ↔ source-entity bindings.

| Widget | Function | Source Tables | Args (via p_filter_json) | Returns (data jsonb shape) |
|--------|----------|---------------|--------------------------|----------------------------|
| KPI Total Contacts | `corg.fn_crm_overview_kpi_total_contacts` | corg.Contacts | (none — tenant only) | `{ "value": 12458, "delta": 234, "deltaLabel": "+234 this month", "deltaColor": "success" }` |
| KPI Donations This Month | `corg.fn_crm_overview_kpi_donations_this_month` | corg.GlobalDonations | (none — derives current month from CURRENT_DATE) | `{ "value": 45230, "format": "currency", "delta": 18.7, "deltaLabel": "vs $38,100 last month (+18.7%)", "deltaColor": "success" }` |
| KPI Active Campaigns | `corg.fn_crm_overview_kpi_active_campaigns` | corg.Campaigns | (none) | `{ "value": 8, "subtitle": "3 ending this week", "subtitleColor": "neutral" }` |
| KPI Avg Engagement Score | `corg.fn_crm_overview_kpi_avg_engagement_score` | corg.Contacts (EngagementScore col) | (none) | `{ "value": 72, "max": 100, "delta": 4, "deltaLabel": "Up from 68 last month", "deltaColor": "success" }` |
| Donor Retention Rate | `corg.fn_crm_overview_donor_retention` | corg.GlobalDonations, corg.Contacts | (none) | `{ "currentPct": 67.3, "benchmarkPct": 45.5, "trend": [{ "month": "Jan", "pct": 62 }, …6 entries], "lybuntCount": 1234, "sybuntCount": 456 }` |
| Recent Activity | `corg.fn_crm_overview_recent_activity` | UNION ALL: GlobalDonations + EmailCampaigns + Contacts + GlobalDonationDistributions + Campaigns (goal events) + Refunds + VolunteerHourLogs + GrantReports | `limit` (default 8) | `{ "events": [{ "iconCode": "donation", "iconColor": "green", "text": "Sarah Johnson donated **$500** to Children's Education Fund", "timeAgo": "2 hours ago", "occurredAtUtc": "..." }, …] }` |
| Pending Approvals | `corg.fn_crm_overview_pending_approvals` | UNION ALL: DuplicateContacts + GlobalDonationDistributions (Pending) + Refunds + VolunteerHourLogs (Unapproved) + GrantReports (Due) | `limit` (default 5) | `{ "items": [{ "task": "Review duplicate contacts (12 pairs)", "moduleCode": "CRM", "moduleLabel": "CRM", "priority": "Medium", "dueDate": "Today", "actionLabel": "Review", "actionRoute": "/crm/contact/duplicate" }, …], "totalCount": 5 }` |
| Fundraising by Purpose | `corg.fn_crm_overview_fundraising_by_purpose` | corg.GlobalDonations JOIN corg.DonationPurposes; goal from corg.Campaigns (if linked) OR DonationPurposes.QuarterGoal field | (none — quarter inferred from CURRENT_DATE) | `{ "items": [{ "name": "Children's Education", "raised": 18500, "goal": 25000, "pct": 74, "color": "teal" }, … top 5] }` |
| Quick Actions | — (no function) | — | — | (renderer ships static catalog) |

**Composite vs. Per-Widget**: **Per-widget Path-A** (matches Contact/Donation Dashboard precedent). 8 round-trips on first load — acceptable because they fire in parallel via `generateWidgets`. Composite handler not warranted — filters are dashboard-global (none currently; future date-range can be added without composite migration).

---

## ④ Business Rules & Validation

**Date Range Defaults:**
- KPI "Donations This Month" and "Active Campaigns" — **current calendar month** (no filter UI on this dashboard; the time scope is hard-coded into each function)
- Retention — **rolling 12-month window** ending current month
- Activity Feed — **last 7 days**, top 8 events
- Pending Approvals — **all open** items (no date filter)
- Fundraising by Purpose — **current calendar quarter**

**No filter UI on this dashboard.** Filter controls are deliberately omitted — this is a "home overview" surface, not an analytical drill-down dashboard. Module-specific dashboards (Contact, Donation, Communication) carry the filter controls.

**Role-Scoped Data Access:**
- **Branch scoping**: if `User.BranchId IS NOT NULL`, all queries filter to that branch via JOIN to `Contact.BranchId` / `Campaign.BranchId` (matches existing Contact Dashboard pattern). If `User.BranchId IS NULL` (admin/director), full tenant view.
- **CompanyId scoping**: every function takes `p_company_id` and filters every source table on `CompanyId = p_company_id`. Non-negotiable.

**Calculation Rules:**
- **Donor Retention Rate** = `COUNT(DISTINCT donors who donated in BOTH current-12mo AND prior-12mo windows) / COUNT(DISTINCT donors who donated in prior-12mo window) * 100`
- **LYBUNT** ("Last Year But Unfortunately Not This") = `COUNT(DISTINCT donors who donated in prior-12mo window AND did NOT donate in current-12mo window)`
- **SYBUNT** ("Some Years But Unfortunately Not This") = `COUNT(DISTINCT donors who donated in ANY year prior to last AND did NOT donate in current-12mo window)`
- **Avg Engagement** = `AVG(corg.Contacts.EngagementScore WHERE EngagementScore IS NOT NULL)` — null-aware; nulls excluded
- **Active Campaign count** = `COUNT WHERE Status='Active' AND EndDate >= CURRENT_DATE` (excludes ended-but-not-archived campaigns)
- **Active Campaign "ending this week"** = `COUNT WHERE Status='Active' AND EndDate BETWEEN CURRENT_DATE AND CURRENT_DATE + 7`
- **Pending Approvals priority**: HIGH if dueDate ≤ today, MEDIUM if ≤ 3 days, LOW otherwise (computed in function — DB is the priority source, not the FE)

**Multi-Currency Rules:**
- KPI "Donations This Month" and Fundraising Progress report in `Company.DefaultCurrency`. Foreign-currency rows convert at row's recorded `ExchangeRate` (matches Donation Dashboard #124 pattern).
- If no `ExchangeRate` recorded, fall back to row's raw `DonationAmount` and tag the widget tooltip with "* mixed-currency totals" — flag as ⑫ ISSUE-1.

**Widget-Level Rules:**
- A widget renders only if `auth.WidgetRoles(WidgetId, currentUser.RoleId, HasAccess=true)` row exists. Otherwise widget slot is omitted (no "Restricted" placeholder — matches existing precedent).
- **Workflow**: None. Read-only dashboard. Drill-down clicks navigate AWAY from this screen.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED based on mockup + chosen variant.

**Screen Type**: DASHBOARD
**Variant**: STATIC_DASHBOARD
**Reason**: Module-level overview surface rendered at `/crm/dashboards/overview` via the existing `<DashboardComponent />`. Surfaces in module dashboard switcher dropdown (`MenuId IS NULL` rule). Auto-loads via `UserDashboard.IsDefault=true`.

**Backend Implementation Path**:
- [x] **Path A — Postgres function (generic widget)** for 8 of 9 widgets — see §⑥ table. Reuses generic `generateWidgets` GraphQL field. No new C# code.
- [ ] Path B / Path C — not used. Keeps surface consistent with existing Contact / Donation dashboards.
- [N/A] 1 widget (Quick Actions) has NO data fetch — `Widget.StoredProcedureName = NULL`. Renderer ships a hard-coded action catalog.

**Path-A Function Contract** — all 7 functions MUST conform to the fixed 5-arg / 4-column contract:
- Inputs (order): `p_filter_json jsonb, p_page integer, p_page_size integer, p_user_id integer, p_company_id integer`
- Output: `TABLE(data jsonb, metadata jsonb, total_count integer, filtered_count integer)` — 1 row, 4 columns
- All filter args extracted from `p_filter_json` via `NULLIF(p_filter_json->>'key','')::type` idiom (most functions on this dashboard read NOTHING from p_filter_json — there are no FE filters)
- Postgres syntax: `CREATE OR REPLACE FUNCTION`, `LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators
- File path: `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/corg/{snake_case_name}.sql`

**Backend Patterns Required:**
- [x] Tenant scoping (`CompanyId = p_company_id`) on every source-table reference — non-negotiable
- [x] Branch scoping where `User.BranchId IS NOT NULL` (resolve user.BranchId from `auth.Users` inside each function using `p_user_id`)
- [ ] Date-range parameterized queries — N/A (no filter UI; date windows hard-coded)
- [ ] Materialized view — none; widget queries < 200ms expected on tenant of ≤500k contacts
- [x] Drill-down arg compatibility — each Activity Feed event and Pending Approval row emits an `actionRoute` already URL-formatted (e.g., `/crm/contact/duplicate`, `/crm/donation/globaldonation?mode=read&id={id}`). FE renderer just passes through to `router.push`.

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` — handled by existing `<DashboardComponent />`
- [x] **Legacy renderer reuse** (per #120 exception in template preamble § 6) — `StatusWidgetType1` for 4 KPI cards. NO modification to legacy renderer source.
- [x] **5 NEW bespoke renderers** under `widgets/main-dashboard-widgets/` folder. Each registered in `WIDGET_REGISTRY` (`dashboard-widget-registry.tsx`). One folder per dashboard family (this folder will be reused by the other 5 module-overview dashboards in future prompts).
- [x] Query registry — NO changes to `QUERY_REGISTRY` in `dashboard-widget-query-registry.tsx` (all Path-A; uses generic `GENERATE_WIDGETS_QUERY`)
- [ ] Date-range picker / filter chips — N/A (no filters on this dashboard)
- [x] Skeleton states — each NEW renderer ships a shape-matched skeleton (KPI tile reuses existing StatusWidgetType1 skeleton; the 5 compound widgets each need their own skeleton)
- [x] STATIC_DASHBOARD — existing chrome (Refresh / Switcher / Edit Layout / Add Widget / Reset Layout / Edit Title) is reused as-is

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer

### Page Chrome (STATIC_DASHBOARD — existing, render via `<DashboardComponent />`)

Already rendered by the existing component — no changes needed:
- Header: dashboard name "Overview" + icon (`ph:gauge`) | Refresh | Dashboard Switcher dropdown | Settings gear (Edit Layout / Edit Title / Reset Layout)
- Dropdown filter rule: `dashboards.filter(d => d.menuId == null)` — picks up Overview + any user-created CRM dashboards; excludes menu-promoted (Contact, Donation, Communication, Volunteer, Ambassador, Case)
- Max 3 user-created dashboards per user per module — existing rule, unchanged

### Grid Layout (react-grid-layout config)

**Breakpoints** (matches Contact Dashboard precedent):
| Breakpoint | min width | columns |
|------------|-----------|---------|
| xs | 0 | 4 |
| sm | 640 | 6 |
| md | 768 | 8 |
| lg | 1024 | 12 |
| xl | 1280 | 12 |

**Widget placement at `lg` (12-col):**

| i (instanceId) | Widget | x | y | w | h | minW | minH | Notes |
|----------------|--------|---|---|---|---|------|------|-------|
| kpi-total-contacts | Total Contacts | 0 | 0 | 3 | 2 | 2 | 2 | KPI tile (StatusWidgetType1) |
| kpi-donations-this-month | Donations This Month | 3 | 0 | 3 | 2 | 2 | 2 | KPI tile (StatusWidgetType1) |
| kpi-active-campaigns | Active Campaigns | 6 | 0 | 3 | 2 | 2 | 2 | KPI tile (StatusWidgetType1) |
| kpi-avg-engagement | Avg Engagement Score | 9 | 0 | 3 | 2 | 2 | 2 | KPI tile (StatusWidgetType1) |
| retention-compound | Donor Retention Rate | 0 | 2 | 12 | 4 | 8 | 3 | Compound: full-width row (3-section: big % \| trend bars \| LYBUNT/SYBUNT) |
| activity-feed | Recent Activity | 0 | 6 | 7 | 6 | 5 | 4 | Scrollable list, last 7d |
| quick-actions | Quick Actions | 7 | 6 | 5 | 6 | 4 | 4 | 2×4 button grid |
| pending-approvals | Pending Approvals | 0 | 12 | 12 | 4 | 8 | 3 | Full-width action table |
| fundraising-progress | Fundraising by Purpose | 0 | 16 | 12 | 4 | 8 | 3 | Full-width horizontal progress bars |

**At `md` (8-col)**: KPIs become 2×2 (4 col each row); Retention stays 12-col-equivalent (full width); Activity/Quick-Actions side-by-side at 4+4; Approvals/Fundraising full-width.

**At `sm` (6-col) / `xs` (4-col)**: every widget collapses to full-width single-column stack. Heights remain.

### Widget Catalog

| # | InstanceId | Title | WidgetType.ComponentPath | Path | Data Source | Filters Honored | Drill-Down |
|---|-----------|-------|--------------------------|------|-------------|------------------|-----------|
| 1 | kpi-total-contacts | Total Contacts | `StatusWidgetType1` | A | `corg.fn_crm_overview_kpi_total_contacts` | (none) | `/crm/contact/contact` |
| 2 | kpi-donations-this-month | Donations This Month | `StatusWidgetType1` | A | `corg.fn_crm_overview_kpi_donations_this_month` | (none) | `/crm/donation/globaldonation?dateRange=thisMonth` |
| 3 | kpi-active-campaigns | Active Campaigns | `StatusWidgetType1` | A | `corg.fn_crm_overview_kpi_active_campaigns` | (none) | `/crm/campaign/campaign?status=Active` |
| 4 | kpi-avg-engagement | Avg Engagement Score | `StatusWidgetType1` | A | `corg.fn_crm_overview_kpi_avg_engagement_score` | (none) | `/crm/contact/contact?sort=engagementScore:desc` |
| 5 | retention-compound | Donor Retention Rate | `MainDashboardRetentionWidget` | A | `corg.fn_crm_overview_donor_retention` | (none) | LYBUNT link → `/crm/contact/contact?segment=LYBUNT`; SYBUNT → `?segment=SYBUNT` |
| 6 | activity-feed | Recent Activity | `MainDashboardActivityFeedWidget` | A | `corg.fn_crm_overview_recent_activity` | (none) | Per-event `route` field → varies by event type |
| 7 | quick-actions | Quick Actions | `MainDashboardQuickActionsWidget` | — | (none — static) | (none) | 8 hard-coded routes (see Quick Actions Catalog below) |
| 8 | pending-approvals | Pending Approvals | `MainDashboardApprovalsWidget` | A | `corg.fn_crm_overview_pending_approvals` | (none) | Per-row `actionRoute` field |
| 9 | fundraising-progress | Fundraising by Purpose | `MainDashboardFundraisingProgressWidget` | A | `corg.fn_crm_overview_fundraising_by_purpose` | (none) | Per-row click → `/crm/donation/globaldonation?purposeId={id}` |

### KPI Cards (StatusWidgetType1 — value/delta/subtitle props)

| # | Title | Value Source | Format | Subtitle | Icon | Color Cue |
|---|-------|--------------|--------|----------|------|-----------|
| 1 | Total Contacts | data.value | count (comma-separated) | data.deltaLabel ("+234 this month") | `fa-address-book` blue tint | blue |
| 2 | Donations This Month | data.value | currency (Company.DefaultCurrency) | data.deltaLabel ("vs $38,100 last month (+18.7%)") | `fa-hand-holding-dollar` green tint | green |
| 3 | Active Campaigns | data.value | count | data.subtitle ("3 ending this week") | `fa-bullseye` orange tint | orange |
| 4 | Avg Engagement Score | data.value + "/" + data.max | score (72/100) | data.deltaLabel ("Up from 68 last month") | `fa-brain` teal tint | teal |

### Donor Retention Compound Widget (`MainDashboardRetentionWidget`)

Layout: 3-column flex row inside the card body
- **Left third (col-md-4)**: big number 67.3% (3rem font, amber color = warning hue) + benchmark hint line ("Industry benchmark: 45.5% — You're above average") with check-circle icon
- **Middle 5/12 (col-md-5)**: header label "6-MONTH TREND" + 6 vertical bars (Jan→Jun) with value labels on top and month labels on bottom; current month bar gets amber gradient, prior 5 get teal-to-cyan gradient
- **Right 3/12 (col-md-3)**: stacked LYBUNT (1,234) + SYBUNT (456) with metric-label + metric-value + tiny explanation text; vertical divider on left

Props shape (matches `data jsonb` from §③):
```ts
interface MainDashboardRetentionData {
  currentPct: number;        // 67.3
  benchmarkPct: number;      // 45.5
  trend: { month: string; pct: number }[];  // 6 entries
  lybuntCount: number;
  sybuntCount: number;
}
```

### Activity Feed Widget (`MainDashboardActivityFeedWidget`)

Layout: scrollable vertical list (max-height 400px), 8 items in mockup
- Each row: 32×32 round icon (color tinted per event type) + text (bold inline emphasis for key values like amounts/names) + relative timestamp (right-aligned)
- Icon color map per event `iconCode`:
  - `donation` → green (heart icon)
  - `email` → blue (envelope)
  - `contact-add` → teal (user-plus)
  - `field-collection` → green (money-bill)
  - `campaign-progress` → orange (bullseye)
  - `refund-fail` → red (exclamation-triangle)
  - `volunteer-log` → purple (clock)
  - `grant-submit` → blue (file)
- Last 7 days header subtitle on the card header

Props shape:
```ts
interface MainDashboardActivityData {
  events: {
    iconCode: 'donation' | 'email' | 'contact-add' | 'field-collection' | 'campaign-progress' | 'refund-fail' | 'volunteer-log' | 'grant-submit';
    iconColor: 'green' | 'blue' | 'teal' | 'orange' | 'red' | 'purple';
    text: string;             // markdown-bolded inline (sanitize on render)
    timeAgo: string;          // pre-formatted "2 hours ago" / "Yesterday" / "3 days ago"
    occurredAtUtc: string;    // ISO — used for sort, optional tooltip
    route?: string;           // optional click target (drill-down)
  }[];
}
```

### Quick Actions Widget (`MainDashboardQuickActionsWidget` — static, no data fetch)

Layout: 2-column × 4-row button grid (8 buttons). Each button = icon (teal) + label.
**Action Catalog (hard-coded in renderer):**

| Button | Icon | Route |
|--------|------|-------|
| New Donation | `fa-plus-circle` | `/crm/donation/globaldonation?mode=new` |
| New Contact | `fa-user-plus` | `/crm/contact/contact?mode=new` |
| Send Email | `fa-paper-plane` | `/communication/emailcampaign?mode=new` (verify exists — flag SERVICE_PLACEHOLDER if route missing) |
| New Campaign | `/organization/event/campaign?mode=new` (verify exact route) | `fa-flag` |
| Import Data | `fa-file-import` | `/crm/contact/contactimport` |
| View Reports | `fa-chart-bar` | `/reportaudit/reports/reportcatalog` |
| Log Collection | `fa-money-bill-wave` | `/crm/fieldcollection/collection?mode=new` (verify route) |
| Add Volunteer | `fa-hands-helping` | `/crm/volunteer/volunteer?mode=new` |

**Build-time check**: before shipping, the FE developer agent grep-verifies each route exists in the FE app tree. Missing routes get flagged as ISSUE entries with the closest existing route substituted.

### Pending Approvals Widget (`MainDashboardApprovalsWidget`)

Layout: table with 5 columns — Task | Type | Priority | Due Date | Action. Header row uses uppercase-ish small label styling (matches mockup).
- **Type badge**: colored pill per `moduleCode` (CRM blue / Collection orange / Fundraising green / Volunteer purple / Grants teal)
- **Priority pill**: red bold (High) / amber bold (Medium) / gray (Low) — color derived from `priority` enum
- **Due Date**: free-text string from BE (`"Today"`, `"Tomorrow"`, `"This week"`, `"Apr 15"`) — formatted server-side to handle relative-vs-absolute decision
- **Action**: ghost button with module-accent border, label from BE (`actionLabel`), click navigates to `actionRoute`
- Card header shows red badge with `totalCount` next to the title

Props shape:
```ts
interface MainDashboardApprovalsData {
  items: {
    task: string;
    moduleCode: 'CRM' | 'COLLECTION' | 'FUNDRAISING' | 'VOLUNTEER' | 'GRANTS' | string;
    moduleLabel: string;       // display label
    priority: 'High' | 'Medium' | 'Low';
    dueDate: string;           // pre-formatted display
    actionLabel: string;
    actionRoute: string;
  }[];
  totalCount: number;          // badge in header
}
```

### Fundraising Progress Widget (`MainDashboardFundraisingProgressWidget`)

Layout: vertical list of progress rows. Each row:
- Top line: purpose name (left, bold) + raised/goal amount (right, muted)
- Middle: 10px-tall track bar with gradient fill matching purpose's color (teal / blue / green / orange / gray rotated based on row index OR sourced from `corg.DonationPurposes.ColorHex` if available)
- Bottom: right-aligned percentage label

Props shape:
```ts
interface MainDashboardFundraisingData {
  items: {
    name: string;
    raised: number;
    goal: number;
    pct: number;
    color: 'teal' | 'blue' | 'green' | 'orange' | 'gray' | string;  // optional; else cycle
    purposeId?: number;        // drill-down
  }[];
}
```

### Filter Controls

**None.** This dashboard has zero filter UI by design. The home/overview surface answers "what's happening right now?" — module-specific dashboards (Contact #123, Donation #124) carry the analytical filters.

### Drill-Down / Navigation Map

| From Widget | Click Target | Navigates To | Prefill |
|-------------|--------------|--------------|---------|
| KPI Total Contacts | Card click | `/crm/contact/contact` | — |
| KPI Donations This Month | Card click | `/crm/donation/globaldonation` | `dateRange=thisMonth` (FE picker preset) |
| KPI Active Campaigns | Card click | `/crm/campaign/campaign` | `status=Active` (FE filter chip) |
| KPI Avg Engagement | Card click | `/crm/contact/contact` | `sort=engagementScore:desc` |
| Retention LYBUNT count | Number click | `/crm/contact/contact` | `segment=LYBUNT` |
| Retention SYBUNT count | Number click | `/crm/contact/contact` | `segment=SYBUNT` |
| Activity event | Row click | per-event `route` from BE | varies |
| Quick Actions button | Button click | (8 routes — see Catalog above) | `mode=new` for create actions |
| Pending Approval row | Action button | per-row `actionRoute` from BE | depends on task type |
| Fundraising row | Bar/row click | `/crm/donation/globaldonation` | `purposeId={id}` |

### User Interaction Flow

1. **Initial load**: user clicks CRM module → lands on `/crm/dashboards/overview` → `<DashboardComponent />` fetches `dashboardByModuleCode('CRM')` → filters `MenuId IS NULL` → picks the row marked `UserDashboard.IsDefault=true` (this dashboard, after seed) → renders 9-widget grid → all 8 Path-A widgets fire `generateWidgets(widgetId)` in parallel → Quick Actions renderer paints immediately (no data fetch).
2. **Refresh** (header button): re-fires all 8 Path-A queries; Quick Actions unaffected.
3. **Switch dashboard** (dropdown): user picks another dashboard from switcher → `<DashboardComponent />` reloads its LayoutConfig → widgets refetch.
4. **Drill-down click**: navigates per Drill-Down Map → destination screen receives prefill args via URL.
5. **Edit Layout** (admin gear menu, owner only): toggles drag/resize mode; user reorders widgets; Save persists new LayoutConfig JSON; Cancel reverts.
6. **Empty / loading / error states**: each widget paints its own shape-matched skeleton during fetch; error → red mini banner + Retry button; empty (e.g., no donations this month) → muted icon + "No activity in selected period" message.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference (Contact Dashboard #123 — closest precedent, Path-A only) to this dashboard.

**Canonical Reference**: [Contact Dashboard #123](contactdashboard.md) — Path-A across all widgets, NEW renderers under `contact-dashboard-widgets/`, no FE filter controls on the dashboard surface; same chrome pattern.

| Canonical (Contact #123) | → This Dashboard (#120) | Context |
|--------------------------|-------------------------|---------|
| ContactDashboard | CrmOverviewDashboard | Dashboard class/code name |
| CONTACTDASHBOARD | CRMOVERVIEW | DashboardCode + GridCode |
| contactdashboard | crmoverviewdashboard | prompt file slug |
| crm/dashboards/contactdashboard | crm/dashboards/overview | route path (overview already exists; do not change) |
| corg | corg | source schema |
| CRM | CRM | parent module code |
| corg/fn_contact_dashboard_*.sql | corg/fn_crm_overview_*.sql | function naming convention |
| contact-dashboard-widgets/ | main-dashboard-widgets/ | renderer folder (shared across all 6 future module-overview dashboards) |
| MENU_DASHBOARD | STATIC_DASHBOARD | variant — Contact #123 has its own menu leaf; #120 does NOT (lives at module's overview route via dropdown) |
| `<MenuDashboardComponent />` | `<DashboardComponent />` | rendering component (existing, untouched) |

---

## ⑧ File Manifest

### Backend Files

| # | File | Path | Required When |
|---|------|------|---------------|
| 1 | KPI Total Contacts function | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/corg/fn_crm_overview_kpi_total_contacts.sql` | always |
| 2 | KPI Donations function | `…/Functions/corg/fn_crm_overview_kpi_donations_this_month.sql` | always |
| 3 | KPI Campaigns function | `…/Functions/corg/fn_crm_overview_kpi_active_campaigns.sql` | always |
| 4 | KPI Engagement function | `…/Functions/corg/fn_crm_overview_kpi_avg_engagement_score.sql` | always |
| 5 | Retention function | `…/Functions/corg/fn_crm_overview_donor_retention.sql` | always |
| 6 | Activity Feed function | `…/Functions/corg/fn_crm_overview_recent_activity.sql` | always |
| 7 | Pending Approvals function | `…/Functions/corg/fn_crm_overview_pending_approvals.sql` | always |
| 8 | Fundraising Progress function | `…/Functions/corg/fn_crm_overview_fundraising_by_purpose.sql` | always |

### Backend Wiring Updates

**None.** All widgets use the existing `generateWidgets` GraphQL field via `Widget.StoredProcedureName`. No new C# code, no Schemas changes, no Mappings changes, no Queries endpoint changes.

### Frontend Files

| # | File | Path | Required When |
|---|------|------|---------------|
| 1 | Retention widget renderer | `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/main-dashboard-widgets/MainDashboardRetentionWidget.tsx` | always — NEW |
| 2 | Activity Feed widget renderer | `…/main-dashboard-widgets/MainDashboardActivityFeedWidget.tsx` | always — NEW |
| 3 | Quick Actions widget renderer | `…/main-dashboard-widgets/MainDashboardQuickActionsWidget.tsx` | always — NEW |
| 4 | Approvals widget renderer | `…/main-dashboard-widgets/MainDashboardApprovalsWidget.tsx` | always — NEW |
| 5 | Fundraising Progress widget renderer | `…/main-dashboard-widgets/MainDashboardFundraisingProgressWidget.tsx` | always — NEW |
| 6 | Folder barrel | `…/main-dashboard-widgets/index.ts` | always — re-exports all 5 renderers |
| 7 | Skeleton stubs (one per new renderer) | `…/main-dashboard-widgets/skeletons/*.tsx` | always — shape-matched skeleton per renderer |
| 8 | Route page (existing — verify only) | `PSS_2.0_Frontend/src/app/[lang]/crm/dashboards/overview/page.tsx` | NO changes — already renders `<DashboardComponent />` |

### Frontend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | Add 5 new entries to `WIDGET_REGISTRY`: `MainDashboardRetentionWidget`, `MainDashboardActivityFeedWidget`, `MainDashboardQuickActionsWidget`, `MainDashboardApprovalsWidget`, `MainDashboardFundraisingProgressWidget` — each mapped to imported component from `widgets/main-dashboard-widgets/`. DO NOT touch any of the ~50 existing registry entries. |
| 2 | `dashboard-widget-query-registry.tsx` | **No changes** — all Path-A; uses existing generic `GENERATE_WIDGETS_QUERY`. |
| 3 | sidebar / menu config | **No changes** — STATIC_DASHBOARD lives at existing module overview route. |

### DB Seed

File: `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/sql-scripts-dyanmic/CrmOverviewDashboard-sqlscripts.sql` (preserve repo's `dyanmic` typo)

| # | Item | When |
|---|------|------|
| 1 | Dashboard row in `sett.Dashboards` (DashboardCode=`CRMOVERVIEW`, ModuleId=CRM, IsSystem=true, IsActive=true, CompanyId=NULL, MenuId=NULL) | always — guarded `WHERE NOT EXISTS` on DashboardCode + ModuleId |
| 2 | DashboardLayout row in `sett.DashboardLayouts` (LayoutConfig JSON × 4 breakpoints lg/md/sm/xs + ConfiguredWidget × 9) | always |
| 3 | 5 NEW WidgetType rows in `sett.WidgetTypes` | always — guard on `WidgetTypeCode` |
| 4 | 9 Widget rows in `sett.Widgets` (StoredProcedureName set for 8; NULL for Quick Actions) | always — guard on `WidgetCode` (use `CRMOVERVIEW_{N}` convention) |
| 5 | 9 WidgetRole grants in `auth.WidgetRoles` for `BUSINESSADMIN` | always |
| 6 | UserDashboard seed for each BUSINESSADMIN user (IsDefault=true) | always — INSERT ... SELECT WHERE NOT EXISTS |
| 7 | NO `auth.Menus` insert | NEVER — STATIC_DASHBOARD |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN
DashboardVariant: STATIC_DASHBOARD

# STATIC_DASHBOARD — NO new menu row. Dashboard surfaces via the module's existing overview route.

MenuName: —
MenuCode: —
ParentMenu: —
Module: CRM
MenuUrl: —                    # NOT applicable (no Menu row)
GridType: DASHBOARD

MenuCapabilities: —           # not applicable
RoleCapabilities:
  BUSINESSADMIN: READ         # via WidgetRole grants only (Dashboard has no MenuId for RoleCapability to attach to)

GridFormSchema: SKIP          # dashboards have no RJSF form
GridCode: CRMOVERVIEW

# Dashboard-specific seed inputs
DashboardCode: CRMOVERVIEW
DashboardName: Overview
DashboardIcon: ph:gauge
DashboardColor: null
IsSystem: true
DashboardKind: STATIC_DASHBOARD       # encoded by Dashboard.MenuId IS NULL at seed time, not a column
OrderBy: —                            # not applicable (STATIC; no Menu.OrderBy)
WidgetGrants:
  - CRMOVERVIEW_KPI_TOTALCONTACTS: BUSINESSADMIN
  - CRMOVERVIEW_KPI_DONATIONS_THIS_MONTH: BUSINESSADMIN
  - CRMOVERVIEW_KPI_ACTIVE_CAMPAIGNS: BUSINESSADMIN
  - CRMOVERVIEW_KPI_AVG_ENGAGEMENT: BUSINESSADMIN
  - CRMOVERVIEW_RETENTION: BUSINESSADMIN
  - CRMOVERVIEW_ACTIVITY_FEED: BUSINESSADMIN
  - CRMOVERVIEW_QUICK_ACTIONS: BUSINESSADMIN
  - CRMOVERVIEW_PENDING_APPROVALS: BUSINESSADMIN
  - CRMOVERVIEW_FUNDRAISING_PROGRESS: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**Queries:** **No new GraphQL queries.** All 8 Path-A widgets call the existing `generateWidgets(widgetId, parameters)` field. The FE renderer receives `data jsonb` and projects it into its props.

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| `generateWidgets` (EXISTING) | `{ data: any, metadata: any, totalCount, filteredCount }` | `widgetId`, optional `parameters` (jsonb) | Per-widget data fetch |
| `dashboardByModuleCode` (EXISTING) | `[DashboardDto]` | `moduleCode: "CRM"` | Switcher dropdown source — must now include the new CRMOVERVIEW row |

**Per-widget `data jsonb` shapes** — see §⑥ Props shape blocks under each NEW renderer description. Backend Path-A functions MUST emit `data` matching these shapes exactly. Mismatch = silent rendering failure.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (no new C# code; verify nothing breaks)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/overview`
- [ ] No new TypeScript errors from the 5 new renderer files
- [ ] No new lint warnings

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Dashboard auto-loads (not the empty "no dashboards configured" state)
- [ ] 4 KPI cards render with correct values, deltas, subtitles, icons (StatusWidgetType1 renderer reused)
- [ ] Retention compound widget renders 3-section row: big % + 6-bar trend + LYBUNT/SYBUNT panel with divider
- [ ] Activity Feed renders 8 events with type-specific icons + relative timestamps + scrollbar when overflow
- [ ] Quick Actions renders 8 buttons in 2×4 grid; each click navigates correctly (no console errors on unresolved routes)
- [ ] Pending Approvals table renders 5 sample rows with correct module-badge colors, priority pills, due dates, action buttons
- [ ] Fundraising Progress renders top 5 purposes with horizontal progress bars + correct percentages
- [ ] Dashboard switcher includes "Overview" (this dashboard) AT THE TOP; menu-promoted dashboards do NOT appear in switcher
- [ ] Refresh button refires all 8 Path-A queries simultaneously
- [ ] Edit Layout enters drag mode; widgets can be reordered; Save persists new layout; Reset reverts
- [ ] WidgetRole gating: deleting `auth.WidgetRoles` row for one widget hides that slot on next reload
- [ ] react-grid-layout reflow at xs / sm / md — widgets stack on mobile, side-by-side on desktop
- [ ] Drill-down clicks work for KPI cards (4), Retention LYBUNT/SYBUNT links (2), Activity rows (per-event), Quick Actions (8), Approval action buttons (5), Fundraising rows (5)

**DB Seed Verification:**
- [ ] `sett.Dashboards` row exists with `DashboardCode='CRMOVERVIEW'`, `ModuleId=(CRM)`, `IsSystem=true`, `IsActive=true`, `MenuId IS NULL`
- [ ] `sett.DashboardLayouts` row exists; `LayoutConfig` JSON parses cleanly and contains breakpoints `lg`, `md`, `sm`, `xs`; `ConfiguredWidget` has 9 entries each with unique `instanceId` matching some `i` value across breakpoints
- [ ] 5 new `sett.WidgetTypes` rows seeded; existing 50+ untouched
- [ ] 9 `sett.Widgets` rows seeded with correct `StoredProcedureName` values (8 set, 1 NULL for Quick Actions)
- [ ] 9 `auth.WidgetRoles` rows for BUSINESSADMIN seeded
- [ ] `UserDashboard` seed inserts an `IsDefault=true` row for each existing BUSINESSADMIN user (idempotent via INSERT … WHERE NOT EXISTS)
- [ ] Re-running the seed is idempotent — Dashboard, DashboardLayout, WidgetType, Widget, WidgetRole, UserDashboard rows are NOT duplicated

**Function Contract Verification:**
- [ ] Each of the 7 Postgres functions matches the 5-arg / 4-column Path-A contract
- [ ] Each function tenant-scopes via `p_company_id` on every source table reference (grep should find zero unscoped FROM clauses)
- [ ] Each function branch-scopes when `User.BranchId IS NOT NULL` (lookup via `p_user_id`)
- [ ] Date windows hard-coded to the rules in §④ (current month / last 7 days / current quarter / rolling 12-month)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents

**STATIC_DASHBOARD-specific reminders:**
- Do NOT create a sidebar menu item for this dashboard. STATIC_DASHBOARD lives at the module's `/crm/dashboards/overview` route, surfaces via the existing dropdown switcher.
- Do NOT modify `<DashboardComponent />`, `<DashboardHeader />`, `useDashboardStore`, `dashboardByModuleCode` handler, or the IsDefault resolution path. They are frozen.
- Dropdown filter rule (`d.menuId == null`) must continue to keep this dashboard visible AND keep menu-promoted dashboards (Contact, Donation, Communication, Volunteer, Ambassador, Case) excluded — verify after seed.

**Per-module future expansion**:
- This prompt covers ONE of 6 module-overview dashboards. The same pattern (and the same 5 NEW renderers under `main-dashboard-widgets/`) will be reused by future prompts for Organization, AccessControl, General, Setting, ReportAudit. Those prompts will only need new Postgres functions + new Dashboard / Widget / WidgetRole seed rows — no new renderers. The folder name `main-dashboard-widgets/` is intentional: it's the shared family of overview renderers across all 6 module homes.

**Path-A reminders:**
- All 7 functions go under `corg/` folder (matches Contact Dashboard precedent — even though some functions touch tables in other schemas like `vol.VolunteerHourLogs` and `grant.GrantReports`, the function ownership stays in `corg/` because the dashboard's primary domain is CRM. Joins across schemas are fine.)
- Postgres syntax only. SQL Server syntax (`CREATE PROCEDURE`, `[brackets]`, `IF OBJECT_ID`) will fail.
- 5-arg / 4-column contract is NON-NEGOTIABLE. Extra optional params must have DEFAULTs and come BEFORE `p_company_id`.

**Widget-data shape coupling:**
- The 5 NEW renderers expect specific `data jsonb` shapes (see §⑥ Props shape blocks). The Postgres functions MUST emit those shapes verbatim. Any field rename = silent broken widget.
- The Activity Feed function returns `iconCode` AS A LITERAL ENUM STRING (`'donation' | 'email' | …`) so the FE can map to icons without a separate registry. Don't return ad-hoc strings.
- The Pending Approvals function returns `priority` as `'High' | 'Medium' | 'Low'` (string), not as a numeric enum. The FE pill color is derived from this string.
- The Pending Approvals function returns `dueDate` PRE-FORMATTED (`'Today' | 'Tomorrow' | 'This week' | 'Apr 15'`). The FE does NOT do date math — the BE owns the relative-vs-absolute decision because it knows the system clock + tenant timezone.

**Quick Actions route verification:**
- The 8 hard-coded routes in `MainDashboardQuickActionsWidget` MUST be grep-verified at build time. If any route doesn't resolve in the current FE app tree, flag in ⑫ ISSUE and either substitute the closest existing route OR mark that button as `disabled` with a SERVICE_PLACEHOLDER tooltip until the destination screen ships.

**Existing-seed alignment**:
- 3 placeholder dashboards (EXEC, OPS, FIELD) already exist in `DashboardConfig-sqlscripts.sql` with empty layouts under the SETTING module. They are unrelated to this prompt. Do NOT modify them.
- The 6 menu-promoted CRM dashboards (Contact, Donation, Communication, Volunteer, Ambassador, Case) have their own seeds. Do NOT touch them. They must continue to appear as sidebar leaves AND must NOT appear in the switcher dropdown (rule: `Dashboard.MenuId IS NOT NULL`).

**Pre-flagged ISSUEs (open during build):**

| Severity | Description |
|---------|-------------|
| ISSUE-1 (MED) | Multi-currency aggregation in `Donations This Month` and `Fundraising by Purpose` — if any `GlobalDonation` row in the window has a non-default currency without `ExchangeRate`, the SUM falls back to raw amounts. Decide: (a) skip non-converted rows, (b) convert via Company.DefaultExchangeRate, or (c) tag widget tooltip with "* mixed-currency totals". Default: (c) plus skip-and-log. |
| ISSUE-2 (MED) | `corg.ContactEngagementScores` may not exist as a separate table — engagement may live on `corg.Contacts.EngagementScore`. The function `fn_crm_overview_kpi_avg_engagement_score` must detect at build time and use whichever source exists. If neither exists, return `null` and the renderer shows "—". |
| ISSUE-3 (LOW) | Recent Activity Feed function unions across 8+ source tables. EXPLAIN ANALYZE before shipping; if > 200ms on a 500k-contact tenant, narrow the time window to last 3 days OR limit each source to its top-3-by-recency before UNION. |
| ISSUE-4 (LOW) | `corg.DonationPurposes` may not have a `QuarterGoal` column — the goal for the Fundraising Progress widget may need to come from `corg.Campaigns.GoalAmount` joined via `DonationPurpose.CampaignId`. The function must detect at build time and join accordingly. If no goal source exists, show "—" instead of "$X / $Y" and a flat-color bar (no % calc). |
| ISSUE-5 (LOW) | Quick Actions route `/communication/emailcampaign?mode=new` — verify Email Campaign screen exists (Email Builder may not be shipped yet). If missing, mark that button as SERVICE_PLACEHOLDER (disabled with tooltip) until #25 or wherever it lands. |
| ISSUE-6 (LOW) | Pending Approvals aggregates from `vol.VolunteerHourLogs`, `corg.Refunds`, `grant.GrantReports`, and `corg.DuplicateContacts` — each must exist in the schema OR the corresponding UNION branch is skipped (not errored). Function must use `to_regclass()` guards if any table may be absent in early environments. |

**Service Dependencies** (UI-only — flag genuine external-service gaps):
- Quick Actions button "Send Email" — see ISSUE-5 above.
- No PDF / SMS / WhatsApp / payment-gateway dependencies on this dashboard.
