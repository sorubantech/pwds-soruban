---
screen: DonationDashboard
registry_id: 124
module: CRM (Fundraising / Donation Operations)
status: PROMPT_READY
scope: FULL
screen_type: DASHBOARD
dashboard_variant: MENU_DASHBOARD
complexity: High
new_module: NO
planned_date: 2026-04-29
completed_date:
last_session_date:
---

> ## ✅ MENU_DASHBOARD INFRA STATUS — ALREADY IN PLACE (verified 2026-04-29)
>
> Unlike Case Dashboard #52 Phase 1 — which had to ship the bootstrap concurrently — the MENU_DASHBOARD plumbing is now LIVE and reusable. Donation Dashboard is a **pure seed-only build** for the dashboard plumbing, plus 17 new SQL widget functions in a NEW `fund` schema folder, plus 10 NEW dedicated FE widget renderers (per the "NEW renderers default" policy below).
>
> **Verified-existing infra** (do NOT recreate):
>
> | Layer | File | Notes |
> |-------|------|-------|
> | BE schema | [Dashboard.MenuId](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/Dashboard.cs) | `int? FK → auth.Menus`. Slug/sort/visibility live on the linked Menu row — do NOT add MenuUrl/OrderBy/IsMenuVisible to Dashboard. |
> | BE query | [GetDashboardByModuleAndCode.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleAndCode.cs) | Single-row, NO UserDashboard join, validates `Dashboard.MenuId IS NOT NULL`. |
> | FE component | [MenuDashboardComponent](../../../PSS_2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx) | Lean — no switcher, no edit chrome. Single `dashboardByModuleAndCode` Apollo fetch + `widgetByModuleCode` for widget catalog. Read-only static `react-grid-layout`. Resolves widget renderers via `<RenderWidget />` from `dashboard-widget-registry.tsx`. |
> | FE gql doc | [MenuDashboardQuery.ts](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/MenuDashboardQuery.ts) | `DASHBOARD_BY_MODULE_AND_CODE_QUERY`. |
> | DB seed precedent | [CaseDashboard-sqlscripts.sql](../../../PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/CaseDashboard-sqlscripts.sql) | Canonical 7-step idempotent seed — Donation Dashboard mirrors this layout. Preserve `sql-scripts-dyanmic/` folder typo per repo convention. |
> | DB seed (Path-A SQL) precedent | [fn_case_dashboard_kpi_open_cases.sql](../../../PSS_2.0_Backend/DatabaseScripts/Functions/case/fn_case_dashboard_kpi_open_cases.sql) | Case-domain functions returning `(data_json text, metadata_json text, total_count integer, filtered_count integer)` — Donation Dashboard's 17 functions match this exact signature. |
> | Sidebar auto-injection | Existing menu-tree composer | Already injects `*_DASHBOARDS` leaves; the seeded `DONATIONDASHBOARD` menu (OrderBy=2 under CRM_DASHBOARDS) just needs `Dashboard.MenuId` linked. |
> | Per-route stub | `[lang]/crm/dashboards/donationdashboard/page.tsx` (currently renders `<DashboardComponent />` STATIC pattern) | **MUST be overwritten** to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="DONATIONDASHBOARD" toolbar={…} />` — see ISSUE-1. |

> ## 🎨 NEW WIDGET RENDERERS — DEFAULT POLICY (non-negotiable)
>
> Per the project's [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md) and the updated [_DASHBOARD.md § ⑤ Frontend Patterns](_DASHBOARD.md): **every widget on this dashboard ships a NEW dedicated renderer under `dashboards/widgets/donation-dashboard-widgets/`**.
>
> **Legacy renderers are FROZEN for #120 Main Dashboard ONLY** — DO NOT reuse on Donation Dashboard:
> - ❌ `StatusWidgetType1` / `StatusWidgetType2`
> - ❌ `MultiChartWidget`
> - ❌ `PieChartWidgetType1`
> - ❌ `BarChartWidgetType1`
> - ❌ `TableWidgetType1` / `NormalTableWidget` / `FilterTableWidget`
> - ❌ `RadialBarWidget`
> - ❌ `HtmlWidgetType1` / `HtmlWidgetType2`
> - ❌ `GeographicHeatmapWidgetType1`
> - ❌ `AlertListWidget` / `case-dashboard-alerts-widget` (Case Dashboard's renderers are FROZEN to that dashboard)
>
> **Naming convention**: `Donation{Purpose}Widget` (e.g., `DonationKpiCardWidget`, `DonationRevenueTrendWidget`).
> **Folder**: `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/donation-dashboard-widgets/`.
> **Each NEW renderer ships 4 files**:
> 1. `{WidgetName}.tsx` — the renderer (consumes `data_json` jsonb shape, renders the widget UI)
> 2. `{WidgetName}.types.ts` — TypeScript shape of the `data_json` payload
> 3. `{WidgetName}.skeleton.tsx` — shape-matched skeleton (KPI tile shape for KPI; donut ring for donut; bar-row shape for bar chart; row-skeletons for tables; alert-row skeletons for alert list — match the renderer's actual layout, not a generic rectangle)
> 4. `index.ts` — barrel export
>
> **Each widget must be VISUALLY UNIQUE — no clone tile grids.** Vary card size, accent color, icon, typography weight, background treatment, trend indicator style, badge style, chart type, row density per widget. Hero KPIs (Total Donations YTD, Active Donors) ≠ supporting KPIs (Avg Gift, Retention, MRR) ≠ alert-bearing KPIs (Outstanding Pledges). Trends use line/area, parts-of-whole use donut/stacked bar, comparisons use grouped-bar — pick chart type per data shape, not "bar chart for everything." Each renderer's `.skeleton.tsx` matches its specific layout, NOT a generic shimmer rectangle.
>
> **Anti-patterns explicitly forbidden** (per the [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md)):
> - ❌ N KPIs sharing ONE renderer with only label/value swapped — "DonationKpiCardWidget × 6" is the canonical anti-pattern
> - ❌ All charts toggling `chartType` on a single component — separate `DonationRevenueTrendWidget` (area), `DonationPaymentMethodDonutWidget` (donut), `DonationCampaignBarsWidget` (horizontal bar)
> - ❌ Identical card chrome (border, padding, header layout) across every widget
> - ❌ Single-rectangle shimmer skeleton for every widget — each renderer ships its own shape-matched skeleton
> - ❌ Recurring/Pledge/Refund "Health" widgets sharing one `HealthGridWidget` — they have different banners, different value-color semantics, different drill-down emphasis; split them
>
> **Cross-instance reuse within a dashboard is the EXCEPTION, NOT the default.** Reuse only when the visual treatment is GENUINELY identical (same chrome, same color palette, same trend indicator, same skeleton shape). When in doubt — split into separate renderers. For Donation Dashboard, the 6 KPIs split into 4 distinct renderers by visual hierarchy (see § ② widget table).
>
> **Vary `LayoutConfig` widget heights/widths so the grid signals importance, not flatness.** Hero KPIs may occupy taller cells (h=3) while supporting KPIs use h=2; full-width charts use w=12 while side-by-side comparisons use w=6+6 — see § ⑥ grid layout for the importance hierarchy.
>
> **Each NEW renderer also gets its own NEW `sett.WidgetTypes` row** — one INSERT per distinct ComponentPath in the seed file's STEP 3. The 17 widget instances reference **15 distinct WidgetType rows** (per § ② widget table) — 4 KPI renderers (Hero / Delta / Pulse / Alert) + 11 single-use renderers. The developer may collapse/split further per the Developer-Decided-Widgets directive below, documenting each split/merge as an ISSUE-N entry.

> ## 🧠 DEVELOPER-DECIDED WIDGETS — read business context first
>
> Per the [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md): the FE/BE developer agents are EXPECTED to read the donation-domain business context (the 9 source entities, fundraising/finance staff personas, existing list screens, the in-flight Refund #13 / PaymentReconciliation #14 patterns) and **decide** the final widget set themselves. **§ ② / ③ / ⑥ catalogs in this prompt are a draft, not a contract.** The developer can:
> - **Add** a widget the prompt missed (e.g., a "Top Donor Acquisition Channels" panel if the team values channel-mix over per-donor view)
> - **Drop** a widget the prompt overspecified (e.g., remove "Recent Donations feed" if alerts already surface actionable activity)
> - **Reshape** a widget (e.g., merge "Refund Watchlist" + "Disputes Open" sub-stat into a single "Refund + Dispute Pipeline" if the data overlaps cleanly)
> - **Split** a widget (e.g., separate "Recurring Health" into "Active vs. Failing Schedules" + "Cancellation Reasons" if the latter justifies its own attention)
>
> Document every deviation in § ⑫ as an ISSUE-N entry with the rationale ("dropped TBL_RECURRING_HEALTH because RecurringDonationSchedule has only 12 active rows in target tenant — not enough signal"). The bar: **useful-at-a-glance > spec-compliant**. The developer is closest to the entities and users; trust their call.
>
> Constraints that DO NOT bend:
> - All 4 header filters (Period / Campaign / Branch / Currency) MUST exist
> - The 6 KPI hero cards MUST exist (the team's daily-glance-of-the-business; remove only with a strong rationale)
> - All drill-downs from clickable widgets MUST land on COMPLETED screens (no broken navigation)
> - All alerts in widget 16 MUST be sourced from real entity rules (not faked)
> - Multi-currency conversion MUST be implemented (USD default + Native + EUR/GBP/AED)
> - Path-A function contract is non-negotiable (5-arg, 4-col return)

## Tasks

### Planning (by /plan-screens) — ALL DONE
- [x] HTML mockup analyzed (17 candidate widgets, 4 global filters, 9 drill-down targets identified)
- [x] Variant chosen — **MENU_DASHBOARD** (own sidebar leaf at `crm/dashboards/donationdashboard`, MenuCode `DONATIONDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=2)
- [x] Source entities resolved (9 fund-schema entities — see § ②.D / § ③)
- [x] Widget catalog drafted (17 widgets — DRAFT; developer may revise per the directive above)
- [x] react-grid-layout config drafted (lg/md/sm/xs breakpoints, 12 cols `lg`, ~41-row height)
- [x] DashboardLayout JSON shape drafted (LayoutConfig multi-breakpoint + ConfiguredWidget instance map)
- [x] Parent menu code + slug + OrderBy already-seeded (no new menu insert; only `Dashboard.MenuId` link)
- [x] First-time MENU_DASHBOARD setup — N/A (infra already shipped via #52 Phase 2 carve-out)
- [x] File manifest computed — see § ⑧
- [x] Approval config pre-filled — see § ⑨
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (widget grid + chart specs + filter controls)
- [ ] User Approval received
- [ ] **Backend (Path-A only — 17 SQL function files in NEW `DatabaseScripts/Functions/fund/` folder)** — NO new C# code; reuses existing `generateWidgets` GraphQL handler
- [ ] **Frontend — 10 NEW dedicated widget renderers** under `dashboards/widgets/donation-dashboard-widgets/`. Each ships `{Name}.tsx + {Name}.types.ts + {Name}.skeleton.tsx + index.ts`. NO reuse of legacy renderers — see policy callout above and § ② widget table.
- [ ] FE wiring: register all 10 new renderers in `dashboard-widget-registry.tsx` `WIDGET_REGISTRY` (key = ComponentPath value, value = the React component)
- [ ] FE wiring: overwrite `[lang]/crm/dashboards/donationdashboard/page.tsx` to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="DONATIONDASHBOARD" toolbar={<DonationDashboardToolbar />} />` — see ISSUE-1
- [ ] FE wiring: overwrite `presentation/pages/crm/dashboards/donationdashboard.tsx` to remove the stale `<DashboardComponent />` import (or delete it and have the route render the menu component directly)
- [ ] FE: NEW Toolbar component `donation-dashboard-toolbar.tsx` housing the 4 filter selects + Export/Print buttons; threads filter state via filter context to widgets
- [ ] FE: extend `<MenuDashboardComponent />` with optional `toolbar?: ReactNode` prop if no slot exists yet (see ISSUE-4)
- [ ] DB Seed file `sql-scripts-dyanmic/DonationDashboard-sqlscripts.sql` (preserve typo) — 7 steps mirroring CaseDashboard-sqlscripts.sql:
      • STEP 0 — Diagnostics (CRM module + BUSINESSADMIN role + pre-flight check that the 10 NEW WidgetType rows do NOT yet exist — confirm clean slate before STEP 3)
      • STEP 1 — Insert Dashboard row (idempotent NOT EXISTS)
      • STEP 2 — Link Dashboard.MenuId to seeded DONATIONDASHBOARD Menu (idempotent UPDATE WHERE MenuId IS NULL)
      • STEP 3 — Insert **10 NEW WidgetType rows** (one per distinct ComponentPath — see § ② widget table). Each idempotent NOT EXISTS guard.
      • STEP 4 — Insert 17 Widget rows (one statement per widget, each with NOT EXISTS guard, references the right WidgetType + StoredProcedureName)
      • STEP 5 — Insert WidgetRole grants (BUSINESSADMIN read-all on all 17 widgets)
      • STEP 6 — Insert DashboardLayout row (LayoutConfig + ConfiguredWidget JSON × 17)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (no new C# code; verifies the migration that registers the 17 functions runs cleanly — or confirm functions are auto-applied at runtime per existing `case/` precedent)
- [ ] All 17 SQL functions exist in `fund.` schema after migration: `SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='fund' AND p.proname LIKE 'fn_donation_dashboard_%';` returns 17 rows
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/donationdashboard`
- [ ] Network tab shows EXACTLY ONE GraphQL `dashboardByModuleAndCode` request (no `dashboardByModuleCode` leakage — that handler joins UserDashboard, MENU_DASHBOARD has none)
- [ ] All 17 widgets fetch and render with sample data
- [ ] **No legacy renderer is invoked** — `git grep` for `StatusWidgetType1\|MultiChartWidget\|PieChartWidgetType1\|BarChartWidgetType1\|FilterTableWidget\|NormalTableWidget\|TableWidgetType1\|AlertListWidget` inside `donation-dashboard-widgets/` returns zero matches; the seed's WidgetType rows for the 17 widgets all reference `Donation*Widget` ComponentPaths
- [ ] Each KPI card shows correct value formatted per spec (currency / percent / count) using the NEW `DonationKpiCardWidget` renderer
- [ ] Each chart renders correctly using its NEW renderer (axes, legends, tooltips, donut total in center, stacked-area annotations)
- [ ] Each table renders with correct columns + row click drill-down using its NEW renderer
- [ ] Period filter change refetches all date-honoring widgets in parallel
- [ ] Campaign filter change refetches Campaign-scoped widgets only
- [ ] Branch filter change refetches Branch-scoped widgets only
- [ ] Currency filter — converts all currency-bearing widgets to selected display currency
- [ ] Drill-down clicks navigate per § ⑥ Drill-Down Map (all destination screens are COMPLETED)
- [ ] "Export Report" toasts SERVICE_PLACEHOLDER (no crash — see ISSUE-2)
- [ ] "Print" opens browser print dialog
- [ ] Each widget has its own SHAPE-MATCHED skeleton (NOT a generic rectangle) — verify visually during loading
- [ ] Empty / error states render per widget
- [ ] Role-based widget gating: WidgetRole(HasAccess=false) → widget hidden
- [ ] Alerts list (widget 16) generates plausible alert items per the rules in § ④ for sample data
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl)
- [ ] Sidebar leaf "Donation Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] Bookmarked URL `/[lang]/crm/dashboards/donationdashboard` survives reload
- [ ] Role-gating via existing `RoleCapability(MenuId=DONATIONDASHBOARD)` hides the sidebar leaf for unauthorized roles

---

## ① Screen Identity & Context

**Consumer**: All agents — sets the stage

**Screen**: DonationDashboard
**Module**: CRM → Fundraising (sidebar leaf under CRM_DASHBOARDS)
**Schema**: NONE for the dashboard itself (`sett.Dashboards` + `sett.DashboardLayouts` + `sett.Widgets` already exist). NEW `fund` Postgres function namespace introduced for widget aggregations (folder `DatabaseScripts/Functions/fund/` does NOT yet exist; create it on this build).
**Group**: NONE (no new C# DTOs / handlers — Path-A throughout)

**Dashboard Variant**: **MENU_DASHBOARD** — own sidebar leaf at `crm/dashboards/donationdashboard` (MenuCode `DONATIONDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=2). NOT in any dropdown switcher.

**Business**:
The Donation Dashboard is the **operations + executive overview** for the Fundraising module — it answers two questions every fundraising lead asks daily: "How much money came in this period and from whom?" and "What needs my attention right now?" It rolls up 9 distinct donation surfaces — direct gifts (GlobalDonation), cheques (ChequeDonation), in-kind (DonationInKind), recurring schedules (RecurringDonationSchedule), receipts (GlobalReceiptDonation), matching gifts (MatchingGift), pledges (Pledge), refunds (Refund), and gateway reconciliation (PaymentTransaction/PaymentSettlement) — into a single board-level summary. **Target audience**: Fundraising Director, Executive Director, Finance team, Branch Managers, and donor-care staff who triage cheque deposits, retry failed recurring charges, chase overdue pledges, and reconcile gateway payouts. **Why it exists**: the existing list pages serve transactional CRUD but offer no cross-cutting "is the campaign healthy?" view. The dashboard surfaces YTD totals, retention KPIs, payment-method mix, cheque pipeline status, recurring health, pledge fulfillment, refund watchlist, and per-campaign progress in one place. **Why MENU_DASHBOARD (not STATIC)**: deep-linkable from emailed donor reports; role-restricted to Fundraising/Finance staff (not all CRM users); tightly scoped to donation operations — no need to share dropdown space with Case / Communication / Volunteer dashboards. Distinct from #17 Fundraising Dashboard (which is a broader campaign-roll-up — different scope, separate dashboard). Sibling design of Case Dashboard #52 (same MENU_DASHBOARD pattern, emerald accent `#059669` vs. teal `#0d9488`) — but Donation Dashboard ships its OWN dedicated FE renderers per the new policy (Case Dashboard's `case-dashboard-alerts-widget` etc. are NOT reused).

---

## ② Entity Definition

**Consumer**: BA Agent → Backend Developer

> Dashboard does NOT introduce a new entity. It composes **two seeded rows** (`sett.Dashboards` + `sett.DashboardLayouts`) over **9 existing source entities**.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `DONATIONDASHBOARD` | Matches Menu.MenuCode |
| DashboardName | `Donation Dashboard` | Matches Menu.MenuName |
| DashboardIcon | `hand-heart-bold` | Phosphor icon name (no `ph:` prefix — `<MenuDashboardComponent />` adds it) |
| DashboardColor | `#059669` | Emerald accent from mockup `--dn-accent` |
| ModuleId | (resolve from `auth.Modules WHERE ModuleCode='CRM'`) | CRM module |
| IsSystem | `true` | System-seeded |
| IsActive | `true` | — |
| CompanyId | NULL | Global system dashboard |
| MenuId | (resolve from `auth.Menus WHERE MenuCode='DONATIONDASHBOARD'`) | Set in seed STEP 2; NULL leaves the slug page returning "Dashboard not found" |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | JSON: `{"lg":[…17 layout items…], "md":[…], "sm":[…], "xs":[…]}` | All 4 breakpoints REQUIRED — `<MenuDashboardComponent />` reads each (line 119-122). Do NOT submit only `lg`. |
| ConfiguredWidget | JSON: `[{i, widgetId}, … 17 entries]` | `i` = instance code (e.g., `KPI_TOTAL_DONATIONS`); `widgetId` resolves to a `sett.Widgets` row in STEP 4. |

### C. Widget Definitions (`sett.Widgets` + `sett.WidgetTypes`)

> All Path-A — each widget has `StoredProcedureName` set; `DefaultQuery` is NULL.
> **All 10 ComponentPaths below are NEW** (per the renderer policy — no reuse of legacy `WIDGET_REGISTRY` keys). Seed STEP 3 inserts one `sett.WidgetTypes` row per distinct ComponentPath; STEP 4 inserts 17 `sett.Widgets` rows referencing those types.

| # | WidgetCode (=instanceId) | WidgetName | ComponentPath (NEW) | StoredProcedureName | OrderBy |
|---|--------------------------|------------|---------------------|---------------------|---------|
| 1 | KPI_TOTAL_DONATIONS | Total Donations YTD | **DonationHeroKpiWidget** *(hero — large w=4 h=3 cell, 12-mo sparkline, emerald gradient header strip)* | fund.fn_donation_dashboard_kpi_total_donations | 1 |
| 2 | KPI_AVG_GIFT | Average Gift | **DonationDeltaKpiWidget** *(supporting — dual-value: current + median, side-by-side; cyan accent)* | fund.fn_donation_dashboard_kpi_avg_gift | 2 |
| 3 | KPI_ACTIVE_DONORS | Active Donors | DonationHeroKpiWidget *(2nd hero instance — count format + new-donor sparkline; indigo gradient strip)* | fund.fn_donation_dashboard_kpi_active_donors | 3 |
| 4 | KPI_DONOR_RETENTION | Donor Retention Rate | DonationDeltaKpiWidget *(2nd delta instance — % current + retained-count below, deep purple accent)* | fund.fn_donation_dashboard_kpi_donor_retention | 4 |
| 5 | KPI_RECURRING_MRR | Recurring MRR | **DonationPulseKpiWidget** *(distinct — animated rotation icon, "/mo" suffix, schedule-count chip below value, orange accent)* | fund.fn_donation_dashboard_kpi_recurring_mrr | 5 |
| 6 | KPI_OUTSTANDING_PLEDGES | Outstanding Pledges | **DonationAlertKpiWidget** *(distinct — amber-tinted card, overdue-count danger sub-badge, attention-seeking treatment)* | fund.fn_donation_dashboard_kpi_outstanding_pledges | 6 |
| 7 | TBL_TOP_DONORS | Top 10 Donors (This Year) | **DonationTopDonorsTableWidget** *(unique — avatar+tier+lifetime-bar)* | fund.fn_donation_dashboard_top_donors | 7 |
| 8 | CHART_REVENUE_TREND | Donation Revenue Trend | **DonationRevenueTrendWidget** *(unique — stacked area, 5-method palette, annotation pins)* | fund.fn_donation_dashboard_revenue_trend | 8 |
| 9 | CHART_PAYMENT_METHOD | By Payment Method | **DonationPaymentMethodDonutWidget** *(unique — donut with center label + legend)* | fund.fn_donation_dashboard_payment_method | 9 |
| 10 | CHART_BY_CAMPAIGN | Donations by Campaign | **DonationCampaignBarsWidget** *(unique — horizontal bars + inline value labels + "Others" bucket)* | fund.fn_donation_dashboard_by_campaign | 10 |
| 11 | TBL_CHEQUE_PIPELINE | Cheque Pipeline | **DonationChequePipelineWidget** *(unique — 4-step funnel, colored top-borders, fixed Received/Deposited/Cleared/Bounced order)* | fund.fn_donation_dashboard_cheque_pipeline | 11 |
| 12 | TBL_RECURRING_HEALTH | Recurring Donation Health | **DonationRecurringHealthWidget** *(distinct — rotation/loop motif, info banner with retry queue, schedule-status emphasis)* | fund.fn_donation_dashboard_recurring_health | 12 |
| 13 | TBL_RECENT_DONATIONS | Recent Donations | **DonationRecentActivityWidget** *(unique — icon-row feed, relative-time chips)* | fund.fn_donation_dashboard_recent_donations | 13 |
| 14 | TBL_PLEDGE_HEALTH | Pledge Fulfillment Health | **DonationPledgeHealthWidget** *(distinct — calendar/clock motif, Fulfilled-YTD success cell, due-date emphasis, NO banner)* | fund.fn_donation_dashboard_pledge_health | 14 |
| 15 | TBL_REFUND_WATCHLIST | Refund & Risk Watchlist | **DonationRefundWatchlistWidget** *(distinct — warning/dispute motif, danger banner with Reconciliation cross-link, status-tinted cells)* | fund.fn_donation_dashboard_refund_watchlist | 15 |
| 16 | LIST_ALERTS | Alerts & Actions | **DonationAlertsListWidget** *(unique — severity-colored rows, sanitized `<strong>` only, CTA per row; does NOT reuse Case Dashboard's `case-dashboard-alerts-widget` or legacy `AlertListWidget`)* | fund.fn_donation_dashboard_alerts | 16 |
| 17 | TBL_CAMPAIGN_GOAL_PROGRESS | Campaign Goal Progress | **DonationCampaignGoalProgressWidget** *(unique — progress-bar table, goal/raised/donors/end-date columns, color-graded bars)* | fund.fn_donation_dashboard_campaign_goal_progress | 17 |

**Distinct ComponentPaths = 15** → 15 new `sett.WidgetTypes` rows in seed STEP 3:

| # | WidgetTypeCode | WidgetTypeName | ComponentPath | Visual Treatment |
|---|----------------|----------------|---------------|------------------|
| 1 | DONATION_HERO_KPI | Donation Hero KPI | DonationHeroKpiWidget | LARGE card (h=3 cell), 12-mo sparkline, gradient header strip (emerald or indigo per instance), bold value + delta arrow, trend microcopy. Used 2× (Total Donations YTD + Active Donors) — these are the 2 headline stats |
| 2 | DONATION_DELTA_KPI | Donation Delta KPI | DonationDeltaKpiWidget | Mid-size card (h=2), dual-value layout: current value + secondary value (median for Avg Gift; retained-count for Retention), trend % with colored arrow, no sparkline. Cyan/purple accent per instance. Used 2× |
| 3 | DONATION_PULSE_KPI | Donation Pulse KPI | DonationPulseKpiWidget | Compact card (h=2), animated rotation icon to convey ongoing-recurring nature, "/mo" suffix on value, schedule-count chip below value, orange accent. Used 1× (Recurring MRR) |
| 4 | DONATION_ALERT_KPI | Donation Alert KPI | DonationAlertKpiWidget | Compact card (h=2), amber-tinted background, primary value + overdue-count danger sub-badge in pill style, attention-seeking treatment. Used 1× (Outstanding Pledges) |
| 5 | DONATION_TOP_DONORS_TABLE | Donation Top Donors Table | DonationTopDonorsTableWidget | 6-col table with avatar circle + tier-badge pill + lifetime-value mini-bar (160px) + relative last-gift label. Used 1× |
| 6 | DONATION_REVENUE_TREND | Donation Revenue Trend Chart | DonationRevenueTrendWidget | 12-month stacked-area chart, 5-method color palette (Online/Cheque/Cash/InKind/Recurring), annotation pins for campaign launches. Used 1× |
| 7 | DONATION_PAYMENT_METHOD_DONUT | Donation Payment Method Donut | DonationPaymentMethodDonutWidget | Donut chart with center total + gift count, segment legend with amount + percent. Used 1× |
| 8 | DONATION_CAMPAIGN_BARS | Donation By-Campaign Bars | DonationCampaignBarsWidget | Top-6 + "Others" horizontal bars, inline value labels, color-graded by amount rank. Used 1× |
| 9 | DONATION_CHEQUE_PIPELINE | Donation Cheque Pipeline Funnel | DonationChequePipelineWidget | 4-step funnel with colored TOP-BORDERS (amber/blue/green/red), fixed-order Received/Deposited/Cleared/Bounced, count + amount per cell. Used 1× |
| 10 | DONATION_RECURRING_HEALTH | Donation Recurring Health | DonationRecurringHealthWidget | 4-cell mini-stat grid + INFO banner ("Retry queue: N failed charges scheduled"), rotation/loop accent icon, schedule-status emphasis (On Track / Behind / Failed / Cancelled-30d). Used 1× |
| 11 | DONATION_PLEDGE_HEALTH | Donation Pledge Health | DonationPledgeHealthWidget | 4-cell mini-stat grid (no banner), calendar/clock accent icon, Fulfilled-YTD cell uses success-green bg distinct from "On Track", due-date emphasis (On Track / Behind / Overdue / Fulfilled-YTD). Used 1× |
| 12 | DONATION_REFUND_WATCHLIST | Donation Refund Watchlist | DonationRefundWatchlistWidget | 4-cell mini-stat grid + DANGER banner with reconciliation cross-link CTA, warning/arrows-rotate accent icon, status-tinted cells (Pending / In Progress / Refunded / Disputes Open). Used 1× |
| 13 | DONATION_RECENT_ACTIVITY | Donation Recent Activity Feed | DonationRecentActivityWidget | Vertical scrolling icon-row feed (max-h 320px), per-method colored icon circle, relative-time chip, anonymous rows italicized muted. Used 1× |
| 14 | DONATION_ALERTS_LIST | Donation Alerts & Actions | DonationAlertsListWidget | Severity-colored alert rows (warning/danger/info/success — distinct bg + border per severity), sanitized `<strong>` only, CTA link per row. Used 1× |
| 15 | DONATION_CAMPAIGN_GOAL_PROGRESS | Donation Campaign Goal Progress | DonationCampaignGoalProgressWidget | Progress-bar table — campaign / goal / raised / donors / 220px progress bar (green/amber/red by progressPct) / end-date. Used 1× |

> The 12 mini-stat-grid widgets (rows 10/11/12 in the WidgetType table) share the SAME 4-cell layout shape but have DIFFERENT chrome treatments per the visual-uniqueness directive: different accent icons (loop / calendar / arrows-rotate), different banner presence/severity (info / none / danger), different success-cell tinting (Fulfilled-YTD in Pledge gets a stronger green than On Track in Recurring). Splitting them into 3 renderers (vs. one shared `DonationHealthGridWidget`) is the explicit policy choice — see ISSUE-3.

### D. Source Entities (read-only — what the widgets aggregate over)

| # | Source Entity | Schema.Table | File Path | Purpose |
|---|--------------|--------------|-----------|---------|
| 1 | GlobalDonation | `fund.GlobalDonations` | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | KPI 1/2/3/4, Top Donors, Revenue Trend, Payment Method, By Campaign, Recent Donations, Anonymous-spike alert |
| 2 | ChequeDonation | `fund.ChequeDonations` | `Base.Domain/Models/DonationModels/ChequeDonation.cs` | Cheque Pipeline funnel, Bounced-cheques alert |
| 3 | DonationInKind | `fund.DonationInKinds` | `Base.Domain/Models/DonationModels/DonationInKind.cs` | Payment-method mix (in-kind segment of donut + revenue trend stack), Recent Donations feed |
| 4 | RecurringDonationSchedule | `fund.RecurringDonationSchedules` | `Base.Domain/Models/DonationModels/RecurringDonationSchedule.cs` | KPI 5 (MRR), Recurring Health mini-grid, Recent Donations (recurring auto-charges), Recurring-failed alert |
| 5 | GlobalReceiptDonation | `fund.GlobalReceiptDonations` | `Base.Domain/Models/DonationModels/GlobalReceiptDonation.cs` | (Optional — informational; may be elided from v1 by the developer per ISSUE-12) |
| 6 | MatchingGift | `fund.MatchingGifts` | `Base.Domain/Models/DonationModels/MatchingGift.cs` | (Optional — collapsed into "Online" payment-method bucket per ④; developer may surface as a dedicated KPI per ISSUE-7) |
| 7 | Pledge | `fund.Pledges` | `Base.Domain/Models/DonationModels/Pledge.cs` | KPI 6 (Outstanding Pledges), Pledge Health mini-grid, Pledges-overdue alert |
| 8 | Refund | `fund.Refunds` | `Base.Domain/Models/DonationModels/Refund.cs` | Refund/Risk Watchlist mini-grid |
| 9 | PaymentTransaction + PaymentSettlement | `fund.PaymentTransactions` + `fund.PaymentSettlements` | `Base.Domain/Models/DonationModels/PaymentTransaction.cs` + `PaymentSettlement.cs` | Refund/Risk Watchlist "Disputes Open" sub-stat + Unmatched-gateway alert |
| 10 | Campaign | `app.Campaigns` | `Base.Domain/Models/ApplicationModels/Campaign.cs` | By Campaign chart, Campaign Goal Progress table, Year-End-campaign success alert, Campaign filter dropdown |
| 11 | Branch | `app.Branches` | `Base.Domain/Models/ApplicationModels/Branch.cs` | Branch filter dropdown only |
| 12 | Currency | `com.Currencies` | `Base.Domain/Models/SharedModels/Currency.cs` | Currency filter dropdown + per-row ExchangeRate lookups for currency conversion |

---

## ③ Source Entity & Aggregate Query Resolution

**Consumer**: Backend Developer (Postgres function authors) + Frontend Developer (widget binding via `Widget.StoredProcedureName`)

> Path-A across all 17 widgets. Each widget calls `SELECT * FROM fund."{function_name}"(p_filter_json::jsonb, p_page, p_page_size, p_user_id, p_company_id)` via the existing `generateWidgets` GraphQL handler.

| # | Source Entity | Postgres Function | Returns (`data_json` shape — NEW renderer consumes this directly) | Filter Args (in p_filter_json) |
|---|--------------|-------------------|------|----|
| 1 | GlobalDonation | `fund.fn_donation_dashboard_kpi_total_donations` | `{value:decimal, formatted:string, deltaLabel:string, deltaColor:'positive'\|'warning'\|'neutral', subtitle:string, icon?:string, color?:string}` | dateFrom, dateTo, campaignId, branchId, displayCurrency |
| 2 | GlobalDonation | `fund.fn_donation_dashboard_kpi_avg_gift` | `{value, formatted, deltaLabel, deltaColor, subtitle, …}` | dateFrom, dateTo, campaignId, branchId, displayCurrency |
| 3 | GlobalDonation (DISTINCT ContactId) | `fund.fn_donation_dashboard_kpi_active_donors` | same KPI shape — `deltaThisYear = COUNT contacts whose first donation falls in YTD` | dateFrom, dateTo, campaignId, branchId |
| 4 | GlobalDonation (cohort intersection) | `fund.fn_donation_dashboard_kpi_donor_retention` | same KPI shape — `(donors_thisYear ∩ donors_lastYear) / donors_lastYear * 100` | dateFrom, dateTo, branchId |
| 5 | RecurringDonationSchedule (Active) | `fund.fn_donation_dashboard_kpi_recurring_mrr` | same KPI shape — value formatted as currency-per-month | branchId, displayCurrency |
| 6 | Pledge (active outstanding) | `fund.fn_donation_dashboard_kpi_outstanding_pledges` | same KPI shape — deltaColor=warning | dateFrom, dateTo, campaignId, branchId, displayCurrency |
| 7 | GlobalDonation + Contact | `fund.fn_donation_dashboard_top_donors` | `{rows:[{contactId, donorName, avatarInitials, tier:'major'\|'regular'\|'new'\|'recurring', tierColorHex, ytdGiven, ytdGivenFormatted, gifts, lastGiftLabel, lifetimeValue, lifetimeValueFormatted, lifetimePctOfMax}], maxLifetime:decimal}` — top 10 by YTD given DESC | dateFrom, dateTo, branchId, displayCurrency |
| 8 | GlobalDonation + DonationInKind + RecurringDonationSchedule | `fund.fn_donation_dashboard_revenue_trend` | `{type:'area', labels:[12 month strings], series:[{name:'Online',color,data:[12]},{name:'Cheque',…},{name:'Cash',…},{name:'In-Kind',…},{name:'Recurring',…}], annotations?:[{xValue,label}]}` | branchId, campaignId, displayCurrency |
| 9 | GlobalDonation (group by PaymentModeId/Code) | `fund.fn_donation_dashboard_payment_method` | `{total:decimal, totalFormatted:'$1.25M', giftCount:int, segments:[{label,value,pct,color}]}` — donut with center label | dateFrom, dateTo, campaignId, branchId, displayCurrency |
| 10 | GlobalDonation + Campaign | `fund.fn_donation_dashboard_by_campaign` | `{rows:[{campaignId, campaignName, value, valueFormatted, widthPct, color}]}` — top 6 + "Others" bucket, ORDER BY value DESC | dateFrom, dateTo, branchId, displayCurrency |
| 11 | ChequeDonation (group by ChequeStatusId) | `fund.fn_donation_dashboard_cheque_pipeline` | `{stats:[{label:'Received',value,amount,amountFormatted,color},{label:'Deposited',…},{label:'Cleared',…},{label:'Bounced',…}]}` — fixed 4-step order | dateFrom, dateTo, branchId, displayCurrency |
| 12 | RecurringDonationSchedule | `fund.fn_donation_dashboard_recurring_health` | `{stats:[{label:'On Track',value,amount,valueColor:'green'},{label:'Behind',…,valueColor:'amber'},{label:'Failed',…,valueColor:'red'},{label:'Cancelled (30d)',…,valueColor:'muted'}], banner?:{kind:'info',message:'<strong>14 failed charges</strong> scheduled for retry within 24 hours.'}}` | branchId, displayCurrency |
| 13 | GlobalDonation (latest 7) + DonationInKind | `fund.fn_donation_dashboard_recent_donations` | `{rows:[{donationId, donorName, campaignName, paymentMethod, methodIconCode, methodIconColor, relativeTimeLabel, amountFormatted, isAnonymous}]}` — 7 most recent | branchId, campaignId, displayCurrency |
| 14 | Pledge (group by PledgeStatusId; due-date math) | `fund.fn_donation_dashboard_pledge_health` | same `{stats[…], banner?}` shape — labels: On Track / Behind / Overdue / Fulfilled (YTD) | dateFrom, dateTo, campaignId, branchId, displayCurrency |
| 15 | Refund + PaymentTransaction (disputes) | `fund.fn_donation_dashboard_refund_watchlist` | same `{stats[…], banner?}` shape — labels: Pending Approval / In Progress / Refunded (YTD) / Disputes Open. Banner: danger "<strong>3 unmatched gateway transactions</strong> need reconciliation review." | dateFrom, dateTo, branchId, displayCurrency |
| 16 | Cross-source rule engine | `fund.fn_donation_dashboard_alerts` | `{alerts:[{severity:'warning'\|'danger'\|'info'\|'success', iconCode:'phosphor-name', message:'<strong>14 recurring charges failed</strong> — queued for retry; 4 require manual update', link:{label:'Resolve', route:'crm/donation/recurringdonationschedule', args:{}}}]}` — top 10 by severity then recency, sanitized HTML (only `<strong>` allowed) | dateFrom, dateTo, campaignId, branchId |
| 17 | Campaign + GlobalDonation per campaign | `fund.fn_donation_dashboard_campaign_goal_progress` | `{rows:[{campaignId, campaignName, goal, goalFormatted, raised, raisedFormatted, donors, progressPct, progressColor:'green'\|'amber'\|'red', endDateLabel}]}` — ACTIVE campaigns, ORDER BY progressPct DESC | dateFrom, dateTo, branchId, displayCurrency |

**Strategy**: **Path A — Postgres functions only**. No composite C# DTO; no per-widget GraphQL handler. Each widget binds to one function via `Widget.StoredProcedureName`. The runtime calls the existing `generateWidgets` GraphQL field with the function name + filter context. Matches the established Case Dashboard #52 precedent (17 functions in `case/`); creates the parallel `fund/` folder.

---

## ④ Business Rules & Validation

**Consumer**: BA Agent → Backend Developer (Postgres functions enforce filtering) → Frontend Developer (filter behavior + drill-down args)

### Date Range Defaults
- Default range: **This Year** (Jan 1 of current calendar year → today)
- Allowed presets: This Year / Last Year / This Quarter / Last Quarter / This Month / Last Month / Custom Range
- Custom range max span: **2 years** (FE filter validation; functions cap p_filter_json span if larger)
- Date filter applies to: `GlobalDonation.DonationDate` (KPIs 1-4, Top Donors YTD, Revenue Trend, Payment Method, By Campaign, Recent Donations), `ChequeDonation.{Received|Deposited|Cleared|Bounced}Date` per status (Cheque Pipeline), `Pledge.PledgeDate` + `Pledge.DueDate` (Outstanding Pledges + Pledge Health), `Refund.RequestedDate` (Refund Watchlist), `Campaign.StartDate`/`EndDate` (Campaign Goal Progress — show campaigns active during range)
- **Cheque Pipeline date semantics** — each step uses its own status-transition date, not the universal donation date

### Role-Scoped Data Access
- **BUSINESSADMIN** → sees ALL companies' data
- **CRM_MANAGER / FUNDRAISING_DIRECTOR** → own company only (`CompanyId = HttpContext.CompanyId`)
- **BRANCH_MANAGER** → additionally filtered by `BranchId IN user's branches` (read from `auth.UserBranches`)
- **DONOR_CARE / FINANCE_USER** → company-scoped; no branch restriction
- All scoping happens in the Postgres function via `p_user_id` + `p_company_id` parameters

### Calculation Rules
- **KPI 1 — Total Donations YTD**: `SUM(GlobalDonation.NetAmount WHERE DonationDate IN range AND IsDeleted=false)`. `deltaPct = ((current - sameRangeLastYear) / sameRangeLastYear) * 100`. Subtitle: "{count} gifts".
- **KPI 2 — Average Gift**: `totalAmount / COUNT(*)`. `medianGift` via `percentile_cont(0.5) WITHIN GROUP (ORDER BY NetAmount)`. Anonymous donations included in count + total (excluded only from KPI 4 retention math).
- **KPI 3 — Active Donors**: `COUNT(DISTINCT ContactId WHERE GlobalDonation.IsAnonymous=false AND DonationDate IN range)`. `deltaThisYear = COUNT(DISTINCT ContactId WHERE first donation EVER falls in YTD)`.
- **KPI 4 — Donor Retention Rate**: `(retainedThisYear / donorsLastYear) * 100`. Anonymous donations excluded from both cohorts.
- **KPI 5 — Recurring MRR**: `SUM(RecurringDonationSchedule.MonthlyAmount WHERE ScheduleStatusId=Active)` converted to displayCurrency.
- **KPI 6 — Outstanding Pledges**: `SUM(Pledge.OutstandingBalance WHERE PledgeStatusId IN (OnTrack, Behind, Overdue))`. Subtitle: "{N} active · {M} overdue" with deltaColor=warning.
- **Top Donor tier badge (table 7)**:
  - `major` if YTD given >= $50,000 (color `#a855f7`)
  - `recurring` if donor has any active RecurringDonationSchedule (color `#3b82f6`)
  - `new` if donor's first donation EVER falls in current YTD (color `#d97706`)
  - `regular` otherwise (color `#059669`)
- **Lifetime Value bar (table 7)**: `lifetimePctOfMax = round((thisDonorLifetime / max(allTopDonorsLifetime)) * 100)` — top donor renders 100%-width bar; others scale relative.
- **Revenue Trend payment-method bucketing (chart 8)**:
  - **Online** = GlobalDonation rows where `PaymentMode.PaymentModeCode IN ('ONLINE','STRIPE','PAYPAL','GATEWAY')`
  - **Cheque** = ChequeDonation rows with `ChequeStatusId='Cleared'`
  - **Cash** = GlobalDonation rows where `PaymentMode.PaymentModeCode = 'CASH'`
  - **In-Kind** = DonationInKind rows where `DIKStatusId=Approved`, valued at `EstimatedValue`
  - **Recurring** = GlobalDonation rows where `IsRecurringCharge=true` (auto-charge from a schedule) — exclude from Online to prevent double-counting
- **Cheque Pipeline (widget 11)**: per ChequeStatusId — Received / Deposited / Cleared / Bounced. Each step uses its own status-transition date column.
- **Recurring Health (widget 12)**: status mapping per RecurringDonationSchedule.ScheduleStatusId MasterData:
  - On Track = ScheduleStatusId='Active' AND last charge succeeded
  - Behind = ScheduleStatusId='Active' AND last charge attempt > 7 days ago without success
  - Failed = ScheduleStatusId='Failed' OR has 1+ failed charge attempt in last 24h
  - Cancelled (30d) = ScheduleStatusId='Cancelled' AND CancelledDate >= NOW() - 30 days
  - Confirm exact MasterDataValue codes during build
- **Pledge Health (widget 14)**: per PledgeStatusId — OnTrack / Behind / Overdue (or PledgeStatusId='OnTrack' AND DueDate < CURRENT_DATE) / Fulfilled YTD
- **Refund Watchlist (widget 15)**: per RefundStatusId — Pending=PEN, In Progress=PRO, Refunded=REF (YTD), Disputes Open = `COUNT(PaymentTransaction WHERE DisputeStatusId IS NOT NULL)`
- **Alert generation rules (widget 16)** — sanitization: only `<strong>` tags allowed; all other HTML escaped:
  - WARNING if `count(failed_recurring_charges_24h) > 0` → "<strong>{N} recurring charges failed</strong> — queued for retry; {M} require manual update (expired cards)" → `crm/donation/recurringdonationschedule`
  - DANGER if `count(overdue_pledges) > 0` → "<strong>{N} pledges overdue</strong> totaling <strong>{$amount}</strong> — oldest {oldestDays} days past due" → `crm/donation/pledge`
  - WARNING if `count(bounced_cheques_30d) > 0` → "<strong>{N} cheques bounced</strong> — oldest {chequeCode} ({daysAgo} days ago, {$amount})" → `crm/donation/chequedonation`
  - INFO if `count(unmatched_gateway_transactions) > 0` → "<strong>{N} unmatched gateway transactions</strong> need manual reconciliation — total {$amount}" → `crm/donation/paymentreconciliation`
  - INFO if `anonymous_donation_count_this_month > anonymous_donation_count_last_month * 1.15` → "<strong>Anonymous donations spiked {pct}%</strong> this month" → `crm/donation/globaldonation?isAnonymous=true`
  - SUCCESS if any `Campaign.RaisedPct >= 75` → "<strong>{CampaignName} at {pct}% of goal</strong> — on track to exceed target by {endDate}" → `crm/organization/campaign`
  - Hard cap of 10 alerts (top 10 by severity then recency)

### Multi-Currency Rules
- **Display Currency** filter (header): user selects USD (default base) / Native Currency / EUR / GBP / AED. Functions read `displayCurrency` from `p_filter_json` and convert all monetary aggregates accordingly.
- **Conversion math**: all currency-bearing values converted to displayCurrency using each row's recorded `ExchangeRate` (FX rate at donation time). If a row has no ExchangeRate, fall back to current rate from `com.Currencies.ExchangeRate`. If displayCurrency='Native Currency', skip conversion and aggregate row-currency-by-row-currency — KPIs surface a "Mixed currency totals" tooltip via `metadata.mixedCurrencyFlag=true` (FE renders the disclaimer).
- **In-Kind valuation**: `DonationInKind.EstimatedValue` converted to displayCurrency. Only `DIKStatusId=Approved` rows count toward revenue.
- **MatchingGift** (entity 6) collapsed into "Online" bucket per § ② note. ISSUE-7 tracks dedicated KPI follow-up.

### Widget-Level Rules
- A widget is RENDERED only if `auth.WidgetRoles(WidgetId, currentRoleId, HasAccess=true)` row exists. No row → widget hidden.
- All 17 widgets seed `WidgetRole(BUSINESSADMIN, HasAccess=true)`. Other roles assigned at admin-config time.
- **Workflow**: None. Read-only. Drill-downs navigate AWAY.

---

## ⑤ Screen Classification & Pattern Selection

**Consumer**: Solution Resolver — these are PRE-ANSWERED.

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Standalone analytical surface deep-linkable from emailed donor reports; role-restricted to fundraising / finance staff; tightly scoped to donation operations. Already has its own sidebar leaf at `/crm/dashboards/donationdashboard`.

**Backend Implementation Path** — **Path A across all 17 widgets**:
- [x] **Path A — Postgres function (generic widget)**: Each widget = 1 SQL function in `fund.` schema returning `(data_json text, metadata_json text, total_count integer, filtered_count integer)`. Reuses existing `generateWidgets` GraphQL handler. Seed `Widget.StoredProcedureName='fund.{function_name}'`. NO new C# code; only 17 SQL deliverables. Matches Case Dashboard #52 precedent.
- [ ] Path B — Named GraphQL query (NOT used)
- [ ] Path C — Composite DTO (NOT used)

**Path-A Function Contract (NON-NEGOTIABLE)** — every function MUST:
- Take 5 fixed inputs in this order: `p_filter_json jsonb DEFAULT '{}'::jsonb, p_page integer DEFAULT 0, p_page_size integer DEFAULT 10, p_user_id integer DEFAULT 0, p_company_id integer DEFAULT NULL`
- Return `TABLE(data_json text, metadata_json text, total_count integer, filtered_count integer)` — single row, 4 columns. **Note**: Case Dashboard precedent uses `data_json text` (NOT `data jsonb`); the runtime parses JSON-stringified text. Match this exactly.
- Extract every filter from `p_filter_json` using `NULLIF(p_filter_json->>'keyName','')::type`. Filter keys: `dateFrom`, `dateTo`, `campaignId`, `branchId`, `displayCurrency` (3-char code: 'USD'/'EUR'/'GBP'/'AED' or 'NATIVE')
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators)
- Live at `PSS_2.0_Backend/DatabaseScripts/Functions/fund/{function_name}.sql` — snake_case names. **NEW `fund/` folder under `DatabaseScripts/Functions/`** (first fund-domain widget functions; the folder must be created with this build).
- `Widget.DefaultParameters` JSON keys MUST match the keys that the function reads from `p_filter_json` (e.g., `{ "dateFrom": "{dateFrom}", "dateTo": "{dateTo}", "campaignId": "{campaignId}", "branchId": "{branchId}", "displayCurrency": "{displayCurrency}" }` — placeholders substituted by widget runtime)
- Tenant scoping via `p_company_id` — every function gates with `WHERE CompanyId = p_company_id OR p_company_id IS NULL`
- Currency conversion via CTE: `WITH base AS (SELECT *, NetAmount * COALESCE(ExchangeRate, fallback_rate) AS amount_in_display_currency FROM ...)`

**Backend Patterns Required:**
- [x] Tenant scoping (CompanyId from HttpContext via p_company_id arg) — every function
- [x] Date-range parameterized queries
- [x] Role-scoped data filtering — joined to `auth.UserBranches` for BRANCH_MANAGER
- [ ] Materialized view / cached aggregate — not for v1; pre-flag ISSUE-6 if any function exceeds 2s p95.

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` (responsive breakpoints) — already in `<MenuDashboardComponent />`
- [x] **NEW renderers per widget shape** — create under `dashboards/widgets/donation-dashboard-widgets/` and register each in `WIDGET_REGISTRY` (`dashboard-widget-registry.tsx`). **15 distinct ComponentPaths** per § ② widget table (4 KPI variants + 11 single-use renderers). Each renderer ships `{Name}.tsx + {Name}.types.ts + {Name}.skeleton.tsx + index.ts`.
- [x] **Visual uniqueness across widgets** — each renderer must have a distinct visual signature: different accent color, different icon, different chrome (gradient strip / amber tint / pulse animation / colored top-borders), different skeleton shape. Verify by side-by-side screenshot review during build — if two widgets feel "samey," split them further. The 6 KPIs are SPLIT across 4 renderers (Hero / Delta / Pulse / Alert) to avoid the "6 identical KPI tiles" anti-pattern.
- [x] **Vary `LayoutConfig` cell heights/widths to signal importance** — Hero KPIs use h=3 cells (taller); supporting KPIs use h=2; full-width charts use w=12; side-by-side comparisons use w=5+7 (donut+bars) or w=6+6 (mini-grids). The grid itself communicates hierarchy before the renderer chrome does.
- [ ] **Reuse legacy `WIDGET_REGISTRY` renderer — DISALLOWED** for this dashboard. `StatusWidgetType1`, `MultiChartWidget`, `PieChartWidgetType1`, `BarChartWidgetType1`, `FilterTableWidget`, `NormalTableWidget`, `AlertListWidget`, `case-dashboard-alerts-widget` are FROZEN to their original dashboards.
- [ ] **Anti-patterns to actively avoid** (forbidden by feedback memory):
      • One renderer used for ALL KPIs with only label/value swapped — split into Hero / Delta / Pulse / Alert per visual hierarchy
      • A single chart component toggling `chartType` for all chart widgets — separate area / donut / bar renderers
      • Identical card chrome (border, padding, header layout) across every widget
      • Generic shimmer-rectangle skeletons — every renderer ships a shape-matched skeleton
      • Recurring/Pledge/Refund "Health" widgets sharing one generic `HealthGridWidget` — split into 3 renderers with distinct icons + banner treatment per the table
- [x] Query registry — NOT extended (Path A uses `generateWidgets` only)
- [x] Date-range picker / Period select / Campaign select / Branch select / Currency select — NEW `donation-dashboard-toolbar.tsx` houses these and threads filter state via filter context to widgets
- [x] Skeleton states matching widget shapes — **shape-matched per NEW renderer** (KPI tile skeleton, donut ring skeleton, stacked-area chart skeleton, table-row skeletons, alert-list skeleton, mini-stat-grid 4-cell skeleton, activity-feed 5-row skeleton — match the renderer's actual layout, NOT a generic rectangle)
- [x] **MENU_DASHBOARD page** — uses already-existing `<MenuDashboardComponent />`. Existing per-route stub at `[lang]/crm/dashboards/donationdashboard/page.tsx` is overwritten to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="DONATIONDASHBOARD" toolbar={<DonationDashboardToolbar />} />`. See ISSUE-1.
- [ ] **Toolbar overrides** — extend `<MenuDashboardComponent />` with optional `toolbar?: ReactNode` prop if no slot exists yet (ISSUE-4). Toolbar component houses 4 filter selects + Export/Print buttons.

---

## ⑥ UI/UX Blueprint

**Consumer**: UX Architect → Frontend Developer

> Layout follows the HTML mockup. All widgets render through `<MenuDashboardComponent moduleCode="CRM" dashboardCode="DONATIONDASHBOARD" />` → resolves to the seeded Dashboard row → reads LayoutConfig + ConfiguredWidget JSON → maps each instance to its NEW `Donation*Widget` renderer + Postgres function.

**Layout Variant**: `widgets-above-grid+side-panel` — widget grid is the dashboard. No CRUD grid. Header has filter controls + action buttons (toolbar slot).

### Page Chrome (MENU_DASHBOARD)

- **Header row** (rendered via `<MenuDashboardComponent />` lean header + new `toolbar` prop):
  - Left: page title `Donation Dashboard` + icon `hand-heart-bold` (emerald) + subtitle `Donations, donors, recurring health, and cheque pipeline at a glance`
  - Right (toolbar slot — composed by NEW `donation-dashboard-toolbar.tsx`): **4 filter selects + 2 buttons + Refresh icon**:
    1. **Period select** — default "This Year"; options: This Year / Last Year / This Quarter / Last Quarter / This Month / Last Month / Custom Range. "Custom Range" opens an inline date-range popover.
    2. **Campaign select** — default "All Campaigns"; dynamic from `app.Campaigns WHERE IsActive=true` via existing `campaigns` GQL query.
    3. **Branch select** — default "All Branches" (or user's branch for BRANCH_MANAGER); dynamic from `app.Branches WHERE IsActive=true` via existing `branches` GQL query.
    4. **Currency select** — default "USD (Base)"; options: USD (Base) / Native Currency / EUR / GBP / AED.
    5. **"Export Report"** primary button (emerald) — SERVICE_PLACEHOLDER. ISSUE-2.
    6. **"Print"** outline button (emerald) — calls `window.print()`. NO placeholder.
    7. **Refresh icon** — existing chrome — kept right-end.

- **No dropdown switcher**, **no Edit Layout chrome** (read-only by default).

### Grid Layout (react-grid-layout — `lg` breakpoint, 12 columns)

> **Visual hierarchy via varied cell sizing** — Hero KPIs occupy taller cells (h=3) than supporting KPIs (h=2) so the grid itself signals importance before the renderer chrome does. Hero KPIs span Row 0; supporting KPIs span Rows 1-2 in a uniform 4-cell strip.

| i (instanceId) | Widget | Renderer | x | y | w | h | minW | minH | Hierarchy |
|----------------|--------|----------|---|---|---|---|------|------|-----------|
| KPI_TOTAL_DONATIONS | Total Donations YTD | DonationHeroKpiWidget | 0 | 0 | 6 | 3 | 4 | 3 | **Hero** — taller, half-width |
| KPI_ACTIVE_DONORS | Active Donors | DonationHeroKpiWidget | 6 | 0 | 6 | 3 | 4 | 3 | **Hero** — taller, half-width |
| KPI_AVG_GIFT | Average Gift | DonationDeltaKpiWidget | 0 | 3 | 3 | 2 | 3 | 2 | Supporting — quad strip row 1 |
| KPI_DONOR_RETENTION | Donor Retention | DonationDeltaKpiWidget | 3 | 3 | 3 | 2 | 3 | 2 | Supporting — quad strip row 1 |
| KPI_RECURRING_MRR | Recurring MRR | DonationPulseKpiWidget | 6 | 3 | 3 | 2 | 3 | 2 | Supporting — quad strip row 1 |
| KPI_OUTSTANDING_PLEDGES | Outstanding Pledges | DonationAlertKpiWidget | 9 | 3 | 3 | 2 | 3 | 2 | Supporting — alert variant |
| TBL_TOP_DONORS | Top 10 Donors | DonationTopDonorsTableWidget | 0 | 5 | 12 | 7 | 8 | 5 | Full-width table |
| CHART_REVENUE_TREND | Revenue Trend | DonationRevenueTrendWidget | 0 | 12 | 12 | 5 | 8 | 4 | Full-width chart |
| CHART_PAYMENT_METHOD | Payment Donut | DonationPaymentMethodDonutWidget | 0 | 17 | 5 | 5 | 4 | 4 | Half-left donut |
| CHART_BY_CAMPAIGN | Campaign Bars | DonationCampaignBarsWidget | 5 | 17 | 7 | 5 | 5 | 4 | 7-col bars |
| TBL_CHEQUE_PIPELINE | Cheque Funnel | DonationChequePipelineWidget | 0 | 22 | 12 | 3 | 8 | 3 | Full-width 4-step funnel |
| TBL_RECURRING_HEALTH | Recurring Health | DonationRecurringHealthWidget | 0 | 25 | 6 | 4 | 4 | 3 | Half-left mini-grid |
| TBL_RECENT_DONATIONS | Recent Activity | DonationRecentActivityWidget | 6 | 25 | 6 | 4 | 4 | 3 | Half-right activity feed |
| TBL_PLEDGE_HEALTH | Pledge Health | DonationPledgeHealthWidget | 0 | 29 | 6 | 4 | 4 | 3 | Half-left mini-grid |
| TBL_REFUND_WATCHLIST | Refund Watchlist | DonationRefundWatchlistWidget | 6 | 29 | 6 | 4 | 4 | 3 | Half-right mini-grid |
| LIST_ALERTS | Alerts | DonationAlertsListWidget | 0 | 33 | 12 | 4 | 8 | 3 | Full-width alerts |
| TBL_CAMPAIGN_GOAL_PROGRESS | Campaign Progress | DonationCampaignGoalProgressWidget | 0 | 37 | 12 | 5 | 8 | 4 | Full-width table |

> **Total grid height ≈ 42 row-units** (was 41 — Hero KPI row is now 3 tall). The 6 KPI cells deliberately differ in size: 2 Hero cells at 6×3 vs. 4 Supporting cells at 3×2. This produces a visible "headline strip" + "compact-strip" structure.

**md / sm / xs breakpoints** (the component reads all four — line 119-122):
- **md (12 cols)**: same as `lg`
- **sm (6 cols)**: KPIs collapse to 2 per row; Donut + Bars stack vertically; mini-grids become full-width stacked
- **xs (1 col)**: every widget full-width vertically

### Widget Catalog (instance details)

> All ComponentPaths are NEW `Donation*Widget` renderers under `donation-dashboard-widgets/` — see § ② for the registry table. Visual treatment notes captured per row.

| # | InstanceId | Title | ComponentPath | Visual Distinguisher | Filters Honored | Drill-Down |
|---|-----------|-------|---------------|----------------------|-----------------|------------|
| 1 | KPI_TOTAL_DONATIONS | Total Donations YTD | **DonationHeroKpiWidget** | LARGE card, emerald gradient header strip, 12-mo sparkline, bold value `$1,245,890` | period, campaign, branch, currency | `/crm/donation/globaldonation?dateFrom=&dateTo=` |
| 2 | KPI_AVG_GIFT | Average Gift | **DonationDeltaKpiWidget** | Mid-size, dual-value (current $285 + median $120), cyan accent, no sparkline | period, campaign, branch, currency | — |
| 3 | KPI_ACTIVE_DONORS | Active Donors | DonationHeroKpiWidget | LARGE card, indigo gradient header strip, 12-mo new-donor sparkline, bold count `2,456` | period, campaign, branch | `/crm/contact/contact?donatedBetween=&dateFrom=&dateTo=` (degrade if not supported) |
| 4 | KPI_DONOR_RETENTION | Donor Retention Rate | DonationDeltaKpiWidget | Mid-size, dual-value (current 68% + retained-count 1,672), purple accent | period, branch | — |
| 5 | KPI_RECURRING_MRR | Recurring MRR | **DonationPulseKpiWidget** | Compact, animated rotation icon, "/mo" suffix, schedule-count chip "487 active", orange accent | branch, currency | `/crm/donation/recurringdonationschedule?statusCode=Active` |
| 6 | KPI_OUTSTANDING_PLEDGES | Outstanding Pledges | **DonationAlertKpiWidget** | Compact amber-tinted card, primary value $185,400, danger pill sub-badge "12 overdue", attention treatment | period, campaign, branch, currency | `/crm/donation/pledge?statusCode=Outstanding` |
| 7 | TBL_TOP_DONORS | Top 10 Donors | DonationTopDonorsTableWidget | Avatar circles + tier-badge pills + 160px lifetime mini-bars + relative last-gift labels | period, branch, currency | Row → `/crm/contact/contact?mode=read&id={contactId}` |
| 8 | CHART_REVENUE_TREND | Revenue Trend | DonationRevenueTrendWidget | 12-month stacked area, 5-method palette, annotation pins for campaign launches | branch, campaign, currency | Series click → `/crm/donation/globaldonation?dateFrom=monthStart&dateTo=monthEnd&paymentModeCode={method}` |
| 9 | CHART_PAYMENT_METHOD | Payment Method Donut | DonationPaymentMethodDonutWidget | Donut with center total + gift count, 5-segment legend with $ amount + percent | period, campaign, branch, currency | Slice click → `/crm/donation/globaldonation?paymentModeCode={code}` |
| 10 | CHART_BY_CAMPAIGN | Donations by Campaign | DonationCampaignBarsWidget | Top-6 + "Others" horizontal bars with inline value labels, color-graded by amount rank | period, branch, currency | Bar click → `/crm/donation/globaldonation?campaignId={id}` |
| 11 | TBL_CHEQUE_PIPELINE | Cheque Pipeline | DonationChequePipelineWidget | 4-step funnel with COLORED TOP-BORDERS (amber/blue/green/red) per status, count + amount per cell | period, branch, currency | Cell click → `/crm/donation/chequedonation?chequeStatusCode={code}` |
| 12 | TBL_RECURRING_HEALTH | Recurring Health | **DonationRecurringHealthWidget** | 4-cell mini-grid + INFO banner ("Retry queue: 14 failed charges scheduled for retry within 24 hours."), rotation/loop accent icon | branch, currency | "View Schedules" → `/crm/donation/recurringdonationschedule` |
| 13 | TBL_RECENT_DONATIONS | Recent Donations | DonationRecentActivityWidget | Vertical scrolling icon-row feed, max-h 320px, per-method colored icon circle, relative-time chips, anonymous rows italicized muted | branch, campaign, currency | "View All" → `/crm/donation/globaldonation` |
| 14 | TBL_PLEDGE_HEALTH | Pledge Health | **DonationPledgeHealthWidget** | 4-cell mini-grid (NO banner), calendar/clock accent icon, Fulfilled-YTD cell uses success-green bg distinct from On Track, due-date emphasis | period, campaign, branch, currency | "View Pledges" → `/crm/donation/pledge` |
| 15 | TBL_REFUND_WATCHLIST | Refund Watchlist | **DonationRefundWatchlistWidget** | 4-cell mini-grid + DANGER banner ("3 unmatched gateway transactions need reconciliation review.") with cross-link CTA, warning/arrows-rotate accent icon | period, branch, currency | "View Refunds" → `/crm/donation/refund`; banner CTA → `/crm/donation/paymentreconciliation?matchStatusCode=UNMATCHED` |
| 16 | LIST_ALERTS | Alerts & Actions | DonationAlertsListWidget | Severity-colored alert rows (4 severity treatments: warning yellow / danger red / info blue / success green — distinct bg + border per severity), sanitized `<strong>` only, CTA link per row | period, campaign, branch | Per-alert `link.route` + `link.args` |
| 17 | TBL_CAMPAIGN_GOAL_PROGRESS | Campaign Goal Progress | DonationCampaignGoalProgressWidget | Progress-bar table — campaign / goal / raised / donors / 220px progress bar (green/amber/red by progressPct) / end-date | period, branch, currency | Row → `/crm/organization/campaign?mode=read&id={campaignId}` |

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Period | Native select + custom range popover | "This Year" | Time-aggregating widgets (KPIs 1-4/6, charts 8/9/10, tables 7/15/17, alerts) | Presets per § ④ |
| Campaign | Single-select (ApiSelectV2) — typeahead from `app.Campaigns` | "All Campaigns" | KPIs 1/2/3/6, charts 8/9/10, tables 7/15/17, alerts | Excludes KPIs 4/5 (retention is portfolio-wide; recurring MRR not campaign-bound) |
| Branch | Single-select — from `app.Branches` | "All Branches" or user's branch (BRANCH_MANAGER) | All widgets | All widgets honor branch |
| Currency | Native select | "USD (Base)" | All currency-bearing widgets | "Native Currency" surfaces "Mixed currency totals" tooltip via `metadata.mixedCurrencyFlag=true` |

Filter values flow into `<MenuDashboardComponent />` filter context, projected into each widget's `customParameter` JSON via the runtime's `{placeholder}` substitution. Functions read them out of `p_filter_json`.

### Drill-Down / Navigation Map (recap of the per-widget table above)

| From | Click On | Navigates To | Prefill |
|------|----------|--------------|---------|
| Top Donor row | Whole row | `/crm/contact/contact?mode=read&id={contactId}` | — |
| Revenue Trend series | Click on month/series | `/crm/donation/globaldonation` | `dateFrom=monthStart&dateTo=monthEnd&paymentModeCode={method}` |
| Payment Donut slice | Click on slice | `/crm/donation/globaldonation` | `paymentModeCode={code}` |
| Campaign Bar | Click on bar | `/crm/donation/globaldonation` | `campaignId={id}` |
| Cheque Pipeline cell | Click on cell | `/crm/donation/chequedonation` | `chequeStatusCode={Received\|Deposited\|Cleared\|Bounced}` |
| Recurring Health link | Card-header link | `/crm/donation/recurringdonationschedule` | — |
| Recent Donations "View All" | Card-header link | `/crm/donation/globaldonation` | — |
| Pledge Health link | Card-header link | `/crm/donation/pledge` | — |
| Refund Watchlist link | Card-header link | `/crm/donation/refund` | — |
| Refund Watchlist banner | Banner CTA | `/crm/donation/paymentreconciliation` | `matchStatusCode=UNMATCHED` |
| Alert link | CTA per row | Per `link.route` from alert data | Per `link.args` |
| Campaign Goal Progress row | Whole row | `/crm/organization/campaign?mode=read&id={campaignId}` | — |
| Toolbar "Export Report" | Button | SERVICE_PLACEHOLDER toast | "Generating donor report..." |
| Toolbar "Print" | Button | `window.print()` | — |

### User Interaction Flow

1. **Initial load**: User clicks `CRM → Dashboards → Donation Dashboard` → URL `/[lang]/crm/dashboards/donationdashboard` → page renders `<MenuDashboardComponent moduleCode="CRM" dashboardCode="DONATIONDASHBOARD" toolbar={<DonationDashboardToolbar />} />`. Component fires `dashboardByModuleAndCode('CRM','DONATIONDASHBOARD')` + `widgetByModuleCode('CRM')` → maps each ConfiguredWidget instance to its NEW `Donation*Widget` renderer via `WIDGET_REGISTRY` → renders 17-widget grid → all widgets parallel-fetch via `generateWidgets` with default filters.
2. **Filter change** (Period / Campaign / Branch / Currency): widgets honoring that filter refetch in parallel; widgets NOT honoring it stay cached.
3. **Drill-down click**: navigates per Drill-Down Map → all destinations are COMPLETED screens.
4. **Back navigation**: returns to dashboard → filters preserved in URL search params where possible.
5. **Export Report** → toast SERVICE_PLACEHOLDER. **Print** → `window.print()`.
6. **Refresh icon** — existing chrome — refetches dashboard config + widgets.
7. **No edit-layout / add-widget chrome** in v1.
8. **Empty / loading / error states**: each NEW renderer ships its own SHAPE-MATCHED skeleton. Error → red mini banner + Retry. Empty → muted icon + per-widget empty message.

---

## ⑦ Substitution Guide

**Consumer**: Backend Developer + Frontend Developer

> Sibling of Case Dashboard #52 — same MENU_DASHBOARD architecture, different schema/scope, **different FE renderers** (Donation Dashboard ships its own `Donation*Widget` set per the new policy).

**Canonical Reference**: **Case Dashboard #52** for BE pattern (`prompts/casedashboard.md` § ⑦) — same Path-A function contract, same `<MenuDashboardComponent />` consumer, same seed-step layout. **Use the existing `case/` SQL functions as the BE reference shape** (especially `fn_case_dashboard_kpi_open_cases.sql` for KPI structure and `fn_case_dashboard_alerts.sql` for the alert rule engine). **DO NOT** reuse Case Dashboard's FE renderers — the policy forbids it.

| Convention | Case Dashboard | → This Dashboard | Notes |
|-----------|----------------|------------------|-------|
| DashboardCode | `CASEDASHBOARD` | `DONATIONDASHBOARD` | Matches existing seeded MenuCode |
| MenuName | `Case Dashboard` | `Donation Dashboard` | Already seeded |
| MenuUrl | `crm/dashboards/casedashboard` | `crm/dashboards/donationdashboard` | Already seeded; no change |
| Schema for Postgres functions | `case.fn_case_dashboard_*` | `fund.fn_donation_dashboard_*` | NEW `fund/` folder under `DatabaseScripts/Functions/` |
| Function naming | `fn_case_dashboard_{aspect}` | `fn_donation_dashboard_{aspect}` | snake_case |
| Widget instance ID | `{TYPE}_{NAME}` | Same convention | Stable across LayoutConfig + ConfiguredWidget |
| Module | `CRM` | `CRM` | Same |
| Parent menu | `CRM_DASHBOARDS` | `CRM_DASHBOARDS` | Same |
| Dashboard color | `#0d9488` (teal) | `#059669` (emerald) | mockup `--dn-accent` |
| Dashboard icon | `chart-pie-light` | `hand-heart-bold` | Phosphor name without `ph:` prefix |
| FE renderer folder | `dashboards/widgets/{various}` (Case-specific renderers FROZEN) | **NEW** `dashboards/widgets/donation-dashboard-widgets/` | 10 distinct ComponentPaths, all `Donation*Widget` named |
| FE renderer naming | `case-dashboard-alerts-widget`, etc. | `DonationKpiCardWidget`, `DonationAlertsListWidget`, etc. | `Donation{Purpose}Widget` PascalCase per policy |
| WidgetType seed rows | (Case-specific 1 NEW + reuse) | **10 NEW WidgetType rows** | All ComponentPaths are NEW |
| Per-route page stub | `[lang]/crm/dashboards/casedashboard/page.tsx` | `[lang]/crm/dashboards/donationdashboard/page.tsx` | Both currently render `<DashboardComponent />` (STATIC). Both need overwriting to `<MenuDashboardComponent />`. This prompt fixes Donation's stub; Case Dashboard #52 fixes its own per its Phase 2. |
| Menu OrderBy | 6 | 2 | Already seeded |

---

## ⑧ File Manifest

**Consumer**: Backend Developer + Frontend Developer

### Backend Files (Path A only — 17 SQL functions, NO C# code)

| # | File | Path |
|---|------|------|
| 1 | KPI 1 — Total Donations | `PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_donation_dashboard_kpi_total_donations.sql` |
| 2 | KPI 2 — Avg Gift | `…/fund/fn_donation_dashboard_kpi_avg_gift.sql` |
| 3 | KPI 3 — Active Donors | `…/fund/fn_donation_dashboard_kpi_active_donors.sql` |
| 4 | KPI 4 — Donor Retention | `…/fund/fn_donation_dashboard_kpi_donor_retention.sql` |
| 5 | KPI 5 — Recurring MRR | `…/fund/fn_donation_dashboard_kpi_recurring_mrr.sql` |
| 6 | KPI 6 — Outstanding Pledges | `…/fund/fn_donation_dashboard_kpi_outstanding_pledges.sql` |
| 7 | Top Donors | `…/fund/fn_donation_dashboard_top_donors.sql` |
| 8 | Revenue Trend | `…/fund/fn_donation_dashboard_revenue_trend.sql` |
| 9 | Payment Method | `…/fund/fn_donation_dashboard_payment_method.sql` |
| 10 | By Campaign | `…/fund/fn_donation_dashboard_by_campaign.sql` |
| 11 | Cheque Pipeline | `…/fund/fn_donation_dashboard_cheque_pipeline.sql` |
| 12 | Recurring Health | `…/fund/fn_donation_dashboard_recurring_health.sql` |
| 13 | Recent Donations | `…/fund/fn_donation_dashboard_recent_donations.sql` |
| 14 | Pledge Health | `…/fund/fn_donation_dashboard_pledge_health.sql` |
| 15 | Refund Watchlist | `…/fund/fn_donation_dashboard_refund_watchlist.sql` |
| 16 | Alerts | `…/fund/fn_donation_dashboard_alerts.sql` |
| 17 | Campaign Goal Progress | `…/fund/fn_donation_dashboard_campaign_goal_progress.sql` |

**Backend Wiring Updates**: NONE (Path A reuses `generateWidgets` GraphQL handler).

**Database Migration**: 1 file if functions are NOT auto-applied at runtime. Confirm during build by inspecting how the existing `case/` functions get registered. If auto-applied, no migration needed; otherwise generate `AddDonationDashboardFunctions.cs`.

### Frontend Files — 15 NEW renderers under `donation-dashboard-widgets/` (4 files each = 60 files + 1 folder barrel + toolbar + page wires)

| # | Renderer | Files (under `dashboards/widgets/donation-dashboard-widgets/`) |
|---|----------|---------------------------------------------------------------|
| 1 | DonationHeroKpiWidget *(used 2× — Total Donations YTD + Active Donors)* | `donation-hero-kpi-widget/DonationHeroKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 2 | DonationDeltaKpiWidget *(used 2× — Avg Gift + Donor Retention)* | `donation-delta-kpi-widget/DonationDeltaKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 3 | DonationPulseKpiWidget *(used 1× — Recurring MRR)* | `donation-pulse-kpi-widget/DonationPulseKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 4 | DonationAlertKpiWidget *(used 1× — Outstanding Pledges)* | `donation-alert-kpi-widget/DonationAlertKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 5 | DonationTopDonorsTableWidget | `donation-top-donors-table-widget/DonationTopDonorsTableWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 6 | DonationRevenueTrendWidget | `donation-revenue-trend-widget/DonationRevenueTrendWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 7 | DonationPaymentMethodDonutWidget | `donation-payment-method-donut-widget/DonationPaymentMethodDonutWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 8 | DonationCampaignBarsWidget | `donation-campaign-bars-widget/DonationCampaignBarsWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 9 | DonationChequePipelineWidget | `donation-cheque-pipeline-widget/DonationChequePipelineWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 10 | DonationRecurringHealthWidget | `donation-recurring-health-widget/DonationRecurringHealthWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 11 | DonationPledgeHealthWidget | `donation-pledge-health-widget/DonationPledgeHealthWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 12 | DonationRefundWatchlistWidget | `donation-refund-watchlist-widget/DonationRefundWatchlistWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 13 | DonationRecentActivityWidget | `donation-recent-activity-widget/DonationRecentActivityWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 14 | DonationAlertsListWidget | `donation-alerts-list-widget/DonationAlertsListWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 15 | DonationCampaignGoalProgressWidget | `donation-campaign-goal-progress-widget/DonationCampaignGoalProgressWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| — | Folder barrel | `dashboards/widgets/donation-dashboard-widgets/index.ts` (re-exports all 15 renderers) |

**Other FE files**:

| # | File | Path | Action |
|---|------|------|--------|
| 11 | Toolbar component | `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/donation-dashboard-toolbar.tsx` | NEW — composes 4 filter selects + Export/Print buttons; threads filter changes via callbacks |
| 12 | Page-config wrapper | `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/donationdashboard.tsx` | OVERWRITE — replace `<DashboardComponent />` with `<MenuDashboardComponent moduleCode="CRM" dashboardCode="DONATIONDASHBOARD" toolbar={<DonationDashboardToolbar />} />` |
| 13 | Per-route page stub | `Pss2.0_Frontend/src/app/[lang]/crm/dashboards/donationdashboard/page.tsx` | KEEP — already imports `<DonationDashboardPageConfig />`; verify after wrapper rewrite |
| 14 | `<MenuDashboardComponent />` toolbar prop | `Pss2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx` | MODIFY — add optional `toolbar?: ReactNode` prop and render inside header before Refresh icon (ISSUE-4); pre-flight skip if already added |

**Frontend Wiring Updates**:

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | Register all 15 NEW renderers: `'DonationHeroKpiWidget': DonationHeroKpiWidget, 'DonationDeltaKpiWidget': DonationDeltaKpiWidget, 'DonationPulseKpiWidget': DonationPulseKpiWidget, 'DonationAlertKpiWidget': DonationAlertKpiWidget, 'DonationTopDonorsTableWidget': …, 'DonationRecurringHealthWidget': …, 'DonationPledgeHealthWidget': …, 'DonationRefundWatchlistWidget': …` etc. — keys must match the `WidgetType.ComponentPath` strings seeded in STEP 3 |
| 2 | `dashboards/widgets/index.ts` (if exists) | Re-export the new folder barrel |
| 3 | Sidebar / menu config | NONE — DONATIONDASHBOARD menu already seeded |

### DB Seed (`sql-scripts-dyanmic/DonationDashboard-sqlscripts.sql`)

> Preserve repo's `sql-scripts-dyanmic/` typo. Mirror Case Dashboard #52's 7-step layout for idempotent independent execution.

| # | Item | Notes |
|---|------|-------|
| 1 | STEP 0 — Diagnostics (read-only) | Verify CRM module + BUSINESSADMIN role + DONATIONDASHBOARD Menu row exists. Pre-flight: confirm none of the 15 NEW WidgetType rows exist yet (clean slate before STEP 3). |
| 2 | STEP 1 — Insert Dashboard row | DashboardCode=DONATIONDASHBOARD, IsSystem=true, ModuleId resolves from CRM, DashboardIcon=`hand-heart-bold`, DashboardColor=`#059669`, IsActive=true, CompanyId=NULL |
| 3 | STEP 2 — Link Dashboard.MenuId | Idempotent UPDATE WHERE MenuId IS NULL — same shape as Case Dashboard's STEP 2.5 |
| 4 | STEP 3 — Insert **15 NEW WidgetType rows** | One INSERT per ComponentPath in § ② widget-type table (4 KPI variants + 11 single-use renderers). Idempotent NOT EXISTS guards. |
| 5 | STEP 4 — Insert 17 Widget rows | One INSERT per widget. DefaultParameters JSON honors filter keys (dateFrom/dateTo/campaignId/branchId/displayCurrency); StoredProcedureName=fund.fn_donation_dashboard_*. WidgetTypeId resolves to the matching STEP 3 row. |
| 6 | STEP 5 — Insert 17 WidgetRole grants | BUSINESSADMIN read-all on all 17 widgets |
| 7 | STEP 6 — Insert DashboardLayout row | LayoutConfig (lg/md/sm/xs breakpoints) + ConfiguredWidget JSON × 17 instances. Idempotent NOT EXISTS guard on DashboardId. |

**Re-running seed must be idempotent** (NOT EXISTS guards on every INSERT/UPDATE — match Case Dashboard precedent).

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

# DONATIONDASHBOARD menu ALREADY seeded under CRM_DASHBOARDS @ OrderBy=2.
# This prompt does NOT seed a new Menu row — only Dashboard + DashboardLayout + 17 Widgets + WidgetRoles + 15 NEW WidgetTypes.
MenuName: Donation Dashboard       # FYI — already seeded
MenuCode: DONATIONDASHBOARD        # FYI — already seeded
ParentMenu: CRM_DASHBOARDS         # FYI — already seeded (MenuId 278)
Module: CRM
MenuUrl: crm/dashboards/donationdashboard   # FYI — already seeded
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT
  # Other role grants (CRM_MANAGER, FUNDRAISING_DIRECTOR, BRANCH_MANAGER, DONOR_CARE, FINANCE_USER) — left to admin-config; not seeded here

GridFormSchema: SKIP    # Dashboards have no RJSF form
GridCode: DONATIONDASHBOARD

# Dashboard-specific seed inputs
DashboardCode: DONATIONDASHBOARD
DashboardName: Donation Dashboard
DashboardIcon: hand-heart-bold
DashboardColor: #059669
IsSystem: true
DashboardKind: MENU_DASHBOARD   # encoded by Dashboard.MenuId IS NOT NULL after STEP 2
MenuOrderBy: 2                  # written to auth.Menus.OrderBy (already seeded — NOT to Dashboard)
NewWidgetTypes:                 # 15 NEW WidgetType rows seeded in STEP 3 (4 KPI variants + 11 single-use)
  - DONATION_HERO_KPI: DonationHeroKpiWidget                        # used 2× — Total Donations YTD + Active Donors (hero)
  - DONATION_DELTA_KPI: DonationDeltaKpiWidget                      # used 2× — Avg Gift + Donor Retention (delta)
  - DONATION_PULSE_KPI: DonationPulseKpiWidget                      # used 1× — Recurring MRR
  - DONATION_ALERT_KPI: DonationAlertKpiWidget                      # used 1× — Outstanding Pledges
  - DONATION_TOP_DONORS_TABLE: DonationTopDonorsTableWidget
  - DONATION_REVENUE_TREND: DonationRevenueTrendWidget
  - DONATION_PAYMENT_METHOD_DONUT: DonationPaymentMethodDonutWidget
  - DONATION_CAMPAIGN_BARS: DonationCampaignBarsWidget
  - DONATION_CHEQUE_PIPELINE: DonationChequePipelineWidget
  - DONATION_RECURRING_HEALTH: DonationRecurringHealthWidget        # split — info banner + loop motif
  - DONATION_PLEDGE_HEALTH: DonationPledgeHealthWidget              # split — calendar motif, no banner
  - DONATION_REFUND_WATCHLIST: DonationRefundWatchlistWidget        # split — danger banner + reconciliation cross-link
  - DONATION_RECENT_ACTIVITY: DonationRecentActivityWidget
  - DONATION_ALERTS_LIST: DonationAlertsListWidget
  - DONATION_CAMPAIGN_GOAL_PROGRESS: DonationCampaignGoalProgressWidget
WidgetGrants:                   # all 17 widgets — BUSINESSADMIN read-all
  - KPI_TOTAL_DONATIONS: BUSINESSADMIN
  - KPI_AVG_GIFT: BUSINESSADMIN
  - KPI_ACTIVE_DONORS: BUSINESSADMIN
  - KPI_DONOR_RETENTION: BUSINESSADMIN
  - KPI_RECURRING_MRR: BUSINESSADMIN
  - KPI_OUTSTANDING_PLEDGES: BUSINESSADMIN
  - TBL_TOP_DONORS: BUSINESSADMIN
  - CHART_REVENUE_TREND: BUSINESSADMIN
  - CHART_PAYMENT_METHOD: BUSINESSADMIN
  - CHART_BY_CAMPAIGN: BUSINESSADMIN
  - TBL_CHEQUE_PIPELINE: BUSINESSADMIN
  - TBL_RECURRING_HEALTH: BUSINESSADMIN
  - TBL_RECENT_DONATIONS: BUSINESSADMIN
  - TBL_PLEDGE_HEALTH: BUSINESSADMIN
  - TBL_REFUND_WATCHLIST: BUSINESSADMIN
  - LIST_ALERTS: BUSINESSADMIN
  - TBL_CAMPAIGN_GOAL_PROGRESS: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Consumer**: Frontend Developer

**Queries** — all widgets use the existing **`generateWidgets`** GraphQL handler (NOT new endpoints):

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| generateWidgets (existing) | `(data jsonb, metadata jsonb, total_count int, filtered_count int)` (text-typed `data_json` deserialized to jsonb on the client) | widgetId, p_filter_json, p_page, p_page_size, p_user_id, p_company_id | All 17 widgets |
| dashboardByModuleAndCode (existing — verified at [GetDashboardByModuleAndCode.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleAndCode.cs)) | DashboardDto with DashboardLayouts + Module includes | moduleCode='CRM', dashboardCode='DONATIONDASHBOARD' | Single-row fetch — `<MenuDashboardComponent />` consumer |
| widgetByModuleCode (existing) | `[WidgetDto]` | moduleCode='CRM' | Module-wide widget catalog — resolves instance code → widgetId → WidgetDto |
| campaigns (existing) | `[CampaignDto]` | dropdown args | Filter dropdown source for "Campaign" |
| branches (existing) | `[BranchDto]` | dropdown args | Filter dropdown source for "Branch" |
| currencies (existing) | `[CurrencyDto]` | — | Filter dropdown source for "Currency" |

**Per-widget `data_json` shapes** — each NEW renderer's `.types.ts` file declares this exactly. The 4 KPI renderers expose DIFFERENT shapes because they emphasize different data:

| Renderer | `data_json` shape |
|----------|------|
| DonationHeroKpiWidget *(used 2× — Total Donations YTD + Active Donors)* | `{ value: number, formatted: string, deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', subtitle: string, sparkline: { labels: string[12], data: number[12] }, accent: 'emerald' \| 'indigo' }` |
| DonationDeltaKpiWidget *(used 2× — Avg Gift + Donor Retention)* | `{ value: number, formatted: string, secondaryLabel: string, secondaryFormatted: string, deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', accent: 'cyan' \| 'purple' }` (e.g., for Avg Gift: secondaryLabel="median", secondaryFormatted="$120"; for Retention: secondaryLabel="retained", secondaryFormatted="1,672") |
| DonationPulseKpiWidget *(used 1× — Recurring MRR)* | `{ value: number, formatted: string, suffix: '/mo', deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', activeScheduleCount: int, activeScheduleLabel: string }` (e.g., "487 active schedules") |
| DonationAlertKpiWidget *(used 1× — Outstanding Pledges)* | `{ value: number, formatted: string, activeCount: int, activeLabel: string, overdueCount: int, overdueLabel: string, severity: 'warning' \| 'danger' }` (overdue sub-badge tint depends on severity; activeCount=185, overdueCount=12 from mockup) |
| DonationTopDonorsTableWidget | `{ rows: [{ contactId, donorName, avatarInitials, tier:'major'\|'regular'\|'new'\|'recurring', tierColorHex, ytdGiven, ytdGivenFormatted, gifts, lastGiftLabel, lifetimeValue, lifetimeValueFormatted, lifetimePctOfMax }], maxLifetime: number }` |
| DonationRevenueTrendWidget | `{ type:'area', labels: string[12], series: [{name, color, data: number[12]}], annotations?: [{xValue, label}] }` |
| DonationPaymentMethodDonutWidget | `{ total: number, totalFormatted: string, giftCount: int, segments: [{label, value, pct, color}] }` |
| DonationCampaignBarsWidget | `{ rows: [{ campaignId, campaignName, value, valueFormatted, widthPct, color }] }` |
| DonationChequePipelineWidget | `{ stats: [{label, value, amount, amountFormatted, color}] }` (4 fixed-order entries: Received/Deposited/Cleared/Bounced — function ALWAYS returns these 4 in order, even if zero count) |
| DonationRecurringHealthWidget | `{ stats: [{label, value, amount, valueColor: 'green'\|'amber'\|'red'\|'muted'}], banner: { kind: 'info', message: string (sanitized HTML, `<strong>` only) } }` (banner ALWAYS present — info-tinted retry-queue notice) |
| DonationPledgeHealthWidget | `{ stats: [{label, value, amount, valueColor: 'green'\|'green-success'\|'amber'\|'red'}] }` (NO banner — function does NOT emit a `banner` field; renderer handles missing banner explicitly. The `green-success` valueColor is used by the Fulfilled-YTD cell to distinguish from the regular "On Track" green) |
| DonationRefundWatchlistWidget | `{ stats: [{label, value, amount, valueColor: 'amber'\|'red'\|'green'\|'muted'}], banner: { kind: 'danger', message: string (sanitized HTML, `<strong>` only), ctaLabel?: string, ctaRoute?: string, ctaArgs?: object } }` (banner has CTA fields the other health widgets don't — used to cross-link to PaymentReconciliation) |
| DonationRecentActivityWidget | `{ rows: [{ donationId, donorName, campaignName, paymentMethod, methodIconCode, methodIconColor, relativeTimeLabel, amountFormatted, isAnonymous }] }` |
| DonationAlertsListWidget | `{ alerts: [{ severity: 'warning'\|'danger'\|'info'\|'success', iconCode, message, link: { label, route, args } }] }` |
| DonationCampaignGoalProgressWidget | `{ rows: [{ campaignId, campaignName, goal, goalFormatted, raised, raisedFormatted, donors, progressPct, progressColor: 'green'\|'amber'\|'red', endDateLabel }] }` |

**No composite DTO**. No new C# types. Each NEW renderer consumes its own jsonb shape directly through the `generateWidgets` runtime. The 3 health-widget shapes deliberately diverge (different banner contracts) so the renderers cannot be accidentally collapsed into one.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] All 17 SQL functions exist in `fund.` schema
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/donationdashboard`
- [ ] Network tab shows EXACTLY ONE `dashboardByModuleAndCode` call (no `dashboardByModuleCode` leakage)
- [ ] Dashboard renders with 17 widgets in the documented layout

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Dashboard loads with default filters (This Year / All Campaigns / All Branches / USD) and renders all 17 widgets
- [ ] **Renderer policy compliance** (legacy reuse check): `git grep` for legacy ComponentPaths (`StatusWidgetType1\|StatusWidgetType2\|MultiChartWidget\|PieChartWidgetType1\|BarChartWidgetType1\|FilterTableWidget\|NormalTableWidget\|TableWidgetType1\|RadialBarWidget\|HtmlWidgetType1\|HtmlWidgetType2\|GeographicHeatmapWidgetType1\|AlertListWidget\|case-dashboard-alerts-widget`) inside `donation-dashboard-widgets/` returns ZERO matches. The 15 seeded WidgetType rows reference only `Donation*Widget` ComponentPaths.
- [ ] **Visual-uniqueness compliance** (per the new directive — no clone tile grids):
      • Hero KPIs (rows 1+3) visually distinct from supporting KPIs (rows 2/4/5/6) — taller h=3 cells, sparklines present, gradient header strip
      • The 4 KPI variants render visibly different chrome — `DonationHeroKpiWidget` (gradient strip + sparkline) ≠ `DonationDeltaKpiWidget` (dual-value layout, no sparkline) ≠ `DonationPulseKpiWidget` (rotation icon + "/mo" suffix) ≠ `DonationAlertKpiWidget` (amber-tinted bg + danger sub-badge)
      • The 3 health widgets render visibly different chrome — `DonationRecurringHealthWidget` (info banner + loop icon) ≠ `DonationPledgeHealthWidget` (no banner + calendar icon + green-success Fulfilled-YTD cell) ≠ `DonationRefundWatchlistWidget` (danger banner with CTA + warning icon)
      • Chart types match data shape — area for trends (CHART_REVENUE_TREND), donut for parts-of-whole (CHART_PAYMENT_METHOD), horizontal bars for comparisons (CHART_BY_CAMPAIGN). No "one chart component switching `chartType`."
      • Each widget skeleton matches its renderer's actual layout — KPI tile skeleton differs from donut skeleton differs from table-row skeleton differs from alert-row skeleton differs from mini-grid 4-cell skeleton. NO single shimmer rectangle on any widget.
      • Side-by-side screenshot of all 17 widgets shows visible visual variety — no two widgets feel "samey"
- [ ] Each KPI card shows correct value formatted per spec via its dedicated renderer (Hero / Delta / Pulse / Alert)
- [ ] Each chart renders correctly via its NEW renderer (axes, legends, tooltips, donut center label, revenue trend annotations)
- [ ] Each table / mini-grid / feed renders with correct columns + row click via NEW renderer
- [ ] Period filter change refetches all date-honoring widgets in parallel
- [ ] Campaign filter change refetches Campaign-scoped widgets only
- [ ] Branch filter change refetches Branch-scoped widgets only
- [ ] Currency filter change reformats all currency-bearing widgets
- [ ] Custom Range opens date popover and applies on confirm
- [ ] Drill-down clicks navigate per Drill-Down Map
- [ ] "Export Report" toasts SERVICE_PLACEHOLDER (no crash)
- [ ] "Print" opens browser print dialog
- [ ] Empty / error states render per widget
- [ ] Role-based widget gating works
- [ ] Alerts list (widget 16) generates plausible items per § ④ rules; sanitized HTML only allows `<strong>`
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl) — Hero KPIs collapse to full-width stacked on xs/sm; supporting KPIs to 2-per-row on sm; etc.
- [ ] Sidebar leaf "Donation Dashboard" visible to BUSINESSADMIN
- [ ] Bookmarked URL survives reload
- [ ] Role-gating via `RoleCapability(MenuId=DONATIONDASHBOARD)` hides leaf for unauthorized roles

**DB Seed Verification:**
- [ ] Dashboard row inserted with DashboardCode=DONATIONDASHBOARD, ModuleId=CRM, IsSystem=true, MenuId NOT NULL after STEP 2
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (all 4 breakpoints) and ConfiguredWidget JSON
- [ ] All 17 Widget rows + WidgetRole grants (BUSINESSADMIN) inserted
- [ ] **All 15 NEW WidgetType rows inserted** with the exact ComponentPath strings listed in § ② (DonationHeroKpiWidget, DonationDeltaKpiWidget, DonationPulseKpiWidget, DonationAlertKpiWidget, DonationTopDonorsTableWidget, DonationRevenueTrendWidget, DonationPaymentMethodDonutWidget, DonationCampaignBarsWidget, DonationChequePipelineWidget, DonationRecurringHealthWidget, DonationPledgeHealthWidget, DonationRefundWatchlistWidget, DonationRecentActivityWidget, DonationAlertsListWidget, DonationCampaignGoalProgressWidget)
- [ ] All 17 Postgres functions queryable: `SELECT * FROM fund."fn_donation_dashboard_kpi_total_donations"('{}'::jsonb, 1, 50, 1, 1);` returns 1 row × 4 columns
- [ ] Re-running seed is idempotent

---

## ⑫ Special Notes & Warnings

**Consumer**: All agents

### Known Issues (pre-flagged)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | HIGH | Architecture | The existing per-route stub at `[lang]/crm/dashboards/donationdashboard/page.tsx` currently renders `<DashboardComponent />` (STATIC pattern — joins UserDashboard, returns zero rows for MENU_DASHBOARD). It MUST be overwritten to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="DONATIONDASHBOARD" toolbar={<DonationDashboardToolbar />} />`. Same fix for `presentation/pages/crm/dashboards/donationdashboard.tsx`. Localized fix — project-wide unified `[slug]/page.tsx` dynamic route is a separate task tracked under Case Dashboard #52 Phase 2. | OPEN |
| ISSUE-2 | MED | Service dep | "Export Report" PDF — full UI in place; handler toasts because PDF rendering / donor-report service not wired. SERVICE_PLACEHOLDER. | OPEN |
| ISSUE-3 | HIGH | Renderer policy + visual-uniqueness | Two non-negotiable checks: (a) **No legacy reuse** — all 15 ComponentPaths must be NEW under `donation-dashboard-widgets/`. `git grep -E "(StatusWidgetType1\|StatusWidgetType2\|MultiChartWidget\|PieChartWidgetType1\|BarChartWidgetType1\|FilterTableWidget\|NormalTableWidget\|TableWidgetType1\|RadialBarWidget\|HtmlWidgetType1\|HtmlWidgetType2\|GeographicHeatmapWidgetType1\|AlertListWidget\|case-dashboard-alerts-widget)" donation-dashboard-widgets/` returns zero. (b) **No clone tile grids** — the 6 KPIs MUST split across 4 distinct renderers (Hero / Delta / Pulse / Alert), the 3 health widgets MUST split across 3 distinct renderers (Recurring / Pledge / Refund). DO NOT collapse them back to `DonationKpiCardWidget` or `DonationHealthGridWidget` "to save time" — that produces the exact "uniform-clone widget grids" anti-pattern called out in [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md). Each split renderer's `.skeleton.tsx` must visibly differ. | OPEN |
| ISSUE-4 | MED | UI chrome | `<MenuDashboardComponent />` may not yet have a `toolbar?: ReactNode` prop. Pre-flight check during build: if no slot exists, add it (render inside the existing lean header before the Refresh icon). The Donation Dashboard requires 4 filter selects + Export + Print buttons in the header. This is shared infrastructure — Case Dashboard #52 Phase 2 will benefit too. | OPEN |
| ISSUE-5 | LOW | UI | Campaign Goal Progress table (17) — mockup is collapsible; v1 ships expanded only (no collapse chrome). Add toggle if user feedback requests. | OPEN |
| ISSUE-6 | MED | Performance | Per-widget Postgres functions over `GlobalDonation` may hit performance ceilings on tenants with > 1M donation rows. Pre-flight: `SELECT COUNT(*) FROM fund."GlobalDonations"` in target tenants. If > 500k rows, profile each function under load before declaring shippable. Materialized views deferred to v1.1 if needed. | OPEN |
| ISSUE-7 | LOW | Scope | MatchingGift (entity 6) is collapsed into the "Online" payment-method bucket for v1 (no dedicated KPI / chart). Per the Developer-Decided-Widgets directive, the developer can elevate MatchingGift to its own KPI if business signal warrants — add a new function `fn_donation_dashboard_kpi_matching_gifts` and a 7th KPI card. Document the decision either way. | OPEN |
| ISSUE-8 | MED | Multi-currency | "Native Currency" filter mode aggregates row-currency-by-row-currency without conversion. KPI cards display only the largest-volume currency's number, with a "Mixed totals" tooltip. Charts (Revenue Trend, Payment Method) are MOST impacted — by-method amounts will mix currencies in the stacked area. Decide during build: (a) drop chart-level totals when displayCurrency=NATIVE, OR (b) show per-currency-stacked sub-series. Option (a) is simpler. | OPEN |
| ISSUE-9 | LOW | Schema match | Anonymous donations alert drills into `/crm/donation/globaldonation?isAnonymous=true`. `GlobalDonation.IsAnonymous` IS the right flag. Confirm during build that the GlobalDonation list page accepts that filter — if not yet supported, add to its query args (1-line change). | OPEN |
| ISSUE-10 | MED | Renderer reuse boundary | Within-dashboard reuse is the EXCEPTION (per the visual-uniqueness directive), not the default. The two allowed reuses on Donation Dashboard: `DonationHeroKpiWidget` ×2 (Total Donations YTD + Active Donors — same gradient-strip + sparkline chrome, accent color is data-driven via `accent` prop) and `DonationDeltaKpiWidget` ×2 (Avg Gift + Donor Retention — same dual-value chrome, accent color is data-driven). All other 11 renderers are 1:1. Across-dashboard reuse is FORBIDDEN: do NOT import `case-dashboard-alerts-widget` for `LIST_ALERTS` even though the data shape is similar — Donation's `DonationAlertsListWidget` is a fresh build. | OPEN |
| ISSUE-11 | MED | Filter coupling | Currency filter — for the Recent Donations feed, individual amounts ARE shown per row. If displayCurrency != row's currency, convert per row in the function. The relative time label format ("just now", "2 hours ago") must be deterministic — function returns it as a pre-formatted string from `now() - DonationDate`. | OPEN |
| ISSUE-12 | LOW | Scope (Receipt) | Source entity #5 (GlobalReceiptDonation) is listed but no widget aggregates over receipts in v1. The mockup is donor / donation focused. Per Developer-Decided-Widgets directive, the developer may add a `fn_donation_dashboard_kpi_pending_receipts` if business demands. Non-blocking. | OPEN |
| ISSUE-13 | LOW | UX (relative time) | Recent Donations feed shows relative times. Computed in the Postgres function via `EXTRACT(EPOCH FROM (NOW() - DonationDate))` and a CASE-WHEN cascade. If FE locales need different phrasing later, add `p_locale` arg — non-blocking. | OPEN |
| ISSUE-14 | MED | Skeleton fidelity (per-renderer) | Each of the 15 NEW renderers ships its own `.skeleton.tsx` matching its actual layout. Specifically: `DonationHeroKpiWidget` skeleton = title + large value bar + sparkline strip + delta-pill; `DonationDeltaKpiWidget` = title + dual-value side-by-side + delta-pill (no sparkline); `DonationPulseKpiWidget` = title + value-with-suffix + schedule-count chip; `DonationAlertKpiWidget` = title + value + amber sub-badge pill; `DonationChequePipelineWidget` = 4 cells with colored top-border bars; `DonationRecurringHealthWidget` = 4-cell grid + info-banner stub below; `DonationPledgeHealthWidget` = 4-cell grid (no banner); `DonationRefundWatchlistWidget` = 4-cell grid + danger-banner stub with CTA pill; `DonationRevenueTrendWidget` = horizontal axis labels + 12 stacked-area bars stub; `DonationPaymentMethodDonutWidget` = donut ring + 5-row legend stubs; `DonationCampaignBarsWidget` = 6 bar-rows with label-and-track shape; `DonationTopDonorsTableWidget` = 10 rows of avatar + columns shape; `DonationRecentActivityWidget` = 5-row icon-row feed shape; `DonationAlertsListWidget` = 4 alert-row stubs; `DonationCampaignGoalProgressWidget` = 6 rows of progress-bar shape. **Generic shimmer rectangles are FORBIDDEN** — verify visually during loading state. | OPEN |

### Build everything in the mockup (GOLDEN RULE reminder)
Every UI element shown in the HTML mockup is in scope. The 6 KPIs / 4 charts / 5 tables-and-feeds / 1 alert list / 1 campaign goal progress table / 4 filter selects / 2 action buttons are ALL in scope. The only SERVICE_PLACEHOLDER is "Export Report" PDF generation (ISSUE-2). Everything else is fully buildable end-to-end. The developer is free to revise the widget set per the Developer-Decided-Widgets directive — but additions/drops/reshapes must be documented as new ISSUE-N entries above.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — pre-flagged ISSUEs above are tracked in § ⑫) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
