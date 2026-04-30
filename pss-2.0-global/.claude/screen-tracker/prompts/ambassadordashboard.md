---
screen: AmbassadorDashboard
registry_id: 69
module: CRM (Field Collection / Ambassador Operations)
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

> ## ✅ MENU_DASHBOARD INFRA STATUS — ALREADY IN PLACE (verified 2026-04-30)
>
> The MENU_DASHBOARD plumbing is LIVE and reusable (shipped via Case Dashboard #52, extended by Donation Dashboard #124). Ambassador Dashboard is a **pure seed-only build** for the dashboard plumbing, plus 14 new SQL widget functions in the existing `fund` schema folder, plus 12 NEW dedicated FE widget renderers (per the "NEW renderers default" policy below).
>
> **Verified-existing infra** (do NOT recreate):
>
> | Layer | File | Notes |
> |-------|------|-------|
> | BE schema | [Dashboard.MenuId](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/Dashboard.cs) | `int? FK → auth.Menus`. Slug/sort/visibility live on the linked Menu row — do NOT add MenuUrl/OrderBy/IsMenuVisible to Dashboard. |
> | BE query | [GetDashboardByModuleAndCode.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleAndCode.cs) | Single-row, NO UserDashboard join, validates `Dashboard.MenuId IS NOT NULL`. |
> | FE component | [MenuDashboardComponent](../../../PSS_2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx) | Lean — no switcher, no edit chrome. Single `dashboardByModuleAndCode` Apollo fetch + `widgetByModuleCode` for widget catalog. Read-only static `react-grid-layout`. Resolves widget renderers via `<RenderWidget />` from `dashboard-widget-registry.tsx`. |
> | FE gql doc | [MenuDashboardQuery.ts](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/MenuDashboardQuery.ts) | `DASHBOARD_BY_MODULE_AND_CODE_QUERY`. |
> | DB seed precedents | [CaseDashboard-sqlscripts.sql](../../../PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/CaseDashboard-sqlscripts.sql) + [ContactDashboard-sqlscripts.sql](../../../PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/ContactDashboard-sqlscripts.sql) | Canonical 7-step idempotent seed — Ambassador Dashboard mirrors this layout. Preserve `sql-scripts-dyanmic/` folder typo per repo convention. |
> | DB seed (Path-A SQL) precedent | [fn_case_dashboard_kpi_open_cases.sql](../../../PSS_2.0_Backend/DatabaseScripts/Functions/case/fn_case_dashboard_kpi_open_cases.sql) + [fn_donation_dashboard_kpi_total_donations.sql](../../../PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_donation_dashboard_kpi_total_donations.sql) | Returns `(data_json text, metadata_json text, total_count integer, filtered_count integer)` — Ambassador Dashboard's 14 functions match this exact signature. |
> | Sidebar auto-injection | Existing menu-tree composer | Already injects `*_DASHBOARDS` leaves; the seeded `AMBASSADORDASHBOARD` menu (OrderBy=4 under CRM_DASHBOARDS) just needs `Dashboard.MenuId` linked. |
> | Per-route stub | [`[lang]/crm/dashboards/ambassadordashboard/page.tsx`](../../../PSS_2.0_Frontend/src/app/[lang]/crm/dashboards/ambassadordashboard/page.tsx) (currently renders `<DashboardComponent />` STATIC pattern via [`ambassadordashboard.tsx`](../../../PSS_2.0_Frontend/src/presentation/pages/crm/dashboards/ambassadordashboard.tsx)) | **MUST be overwritten** to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="AMBASSADORDASHBOARD" toolbar={…} />` — see ISSUE-1. |
> | DB Functions folder | `PSS_2.0_Backend/DatabaseScripts/Functions/fund/` | EXISTS — currently holds `fn_donation_dashboard_kpi_total_donations.sql`. Ambassador functions live alongside Donation functions in the same `fund` schema folder, prefixed `fn_ambassador_dashboard_*`. NO new folder needed. |

> ## 🎨 NEW WIDGET RENDERERS — DEFAULT POLICY (non-negotiable)
>
> Per the project's [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md) and the updated [_DASHBOARD.md § ⑤ Frontend Patterns](_DASHBOARD.md): **every widget on this dashboard ships a NEW dedicated renderer under `dashboards/widgets/ambassador-dashboard-widgets/`**.
>
> **Legacy renderers are FROZEN for #120 Main Dashboard ONLY** — DO NOT reuse on Ambassador Dashboard:
> - ❌ `StatusWidgetType1` / `StatusWidgetType2`
> - ❌ `MultiChartWidget`
> - ❌ `PieChartWidgetType1` / `BarChartWidgetType1`
> - ❌ `TableWidgetType1` / `NormalTableWidget` / `FilterTableWidget`
> - ❌ `RadialBarWidget`
> - ❌ `HtmlWidgetType1` / `HtmlWidgetType2`
> - ❌ `GeographicHeatmapWidgetType1`
> - ❌ Case Dashboard's `case-dashboard-alerts-widget`, Donation Dashboard's `Donation*Widget` set, Contact Dashboard's `Contact*Widget` set — those are FROZEN to their original dashboards.
>
> **Naming convention**: `Ambassador{Purpose}Widget` (e.g., `AmbassadorHeroKpiWidget`, `AmbassadorLeaderboardWidget`).
> **Folder**: `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/ambassador-dashboard-widgets/`.
> **Each NEW renderer ships 4 files**:
> 1. `{WidgetName}.tsx` — the renderer (consumes `data_json` jsonb shape, renders the widget UI)
> 2. `{WidgetName}.types.ts` — TypeScript shape of the `data_json` payload
> 3. `{WidgetName}.skeleton.tsx` — shape-matched skeleton (KPI tile shape for KPI; donut ring for donut; bar-row shape for bar chart; row-skeletons for tables; alert-row skeletons for alert list — match the renderer's actual layout, not a generic rectangle)
> 4. `index.ts` — barrel export
>
> **Each widget must be VISUALLY UNIQUE — no clone tile grids.** The 6 KPIs are SPLIT across 4 distinct renderers (Hero / Delta / Ratio / Compliance) by visual hierarchy. The 4 charts are 4 different chart shapes (combo bar+line / horizontal bars / donut / vertical bars) — NOT one chart component switching `chartType`. The 2 tables and 1 map are independent renderers. The alert list is its own renderer with severity-colored rows. See § ② widget table for per-renderer visual treatment notes.
>
> **Anti-patterns explicitly forbidden** (per the [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md)):
> - ❌ All 6 KPIs sharing one `AmbassadorKpiCardWidget` with only label/value swapped — split into Hero / Delta / Ratio / Compliance per visual hierarchy
> - ❌ All charts toggling `chartType` on a single component — separate combo / horizontal-bar / donut / vertical-bar renderers
> - ❌ Identical card chrome (border, padding, header layout) across every widget
> - ❌ Single-rectangle shimmer skeleton for every widget — each renderer ships its own shape-matched skeleton
> - ❌ Territory Map and Territory Summary table merged into one widget — they are deliberately separate (different shapes, different drill behavior)
>
> **Cross-instance reuse within a dashboard is the EXCEPTION, NOT the default.** Reuse only when visual treatment is GENUINELY identical (same chrome, same color palette, same trend indicator, same skeleton shape). For Ambassador Dashboard, the only allowed reuses are: `AmbassadorHeroKpiWidget` ×2 (Total Collections + Unique Donors — same gradient-strip + sparkline chrome, accent color is data-driven via `accent` prop) and `AmbassadorDeltaKpiWidget` ×2 (Collection Count + Avg per Ambassador — same dual-value chrome, accent color is data-driven). All other 10 renderers are 1:1.
>
> **Each NEW renderer also gets its own NEW `sett.WidgetTypes` row** — one INSERT per distinct ComponentPath in the seed file's STEP 3. The 14 widget instances reference **12 distinct WidgetType rows** (per § ② widget table). The developer may collapse/split further per the Developer-Decided-Widgets directive below, documenting each split/merge as an ISSUE-N entry.

> ## 🧠 DEVELOPER-DECIDED WIDGETS — read business context first
>
> Per the [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md): the FE/BE developer agents are EXPECTED to read the field-collection-domain business context (the 6 source entities, ambassador/branch/donor-care personas, existing list screens #65 #66 #67, Receipt-book lifecycle, Territory model) and **decide** the final widget set themselves. **§ ② / ③ / ⑥ catalogs in this prompt are a draft, not a contract.** The developer can:
> - **Add** a widget the prompt missed (e.g., a "Top Performing Territories" panel if the team values territory ranking over the per-territory summary table)
> - **Drop** a widget the prompt overspecified (e.g., remove "Day of Week" chart if collection patterns don't vary meaningfully week-to-week in target tenants)
> - **Reshape** a widget (e.g., merge "Receipt Compliance" KPI into the Alerts list if gap detection is rare enough that a dedicated KPI is overkill)
> - **Split** a widget (e.g., separate "Active Ambassadors" into two — "Active count" + "Inactive watchlist" — if inactive ambassadors deserve their own attention surface)
>
> Document every deviation in § ⑫ as an ISSUE-N entry with the rationale ("dropped CHART_BY_DAY_OF_WEEK because target tenants' collections cluster on Sat/Sun in 90%+ of cases — chart adds no signal"). The bar: **useful-at-a-glance > spec-compliant**. The developer is closest to the entities and users; trust their call.
>
> Constraints that DO NOT bend:
> - All 2 header filters (Period / Branch) MUST exist
> - The 6 KPI hero cards MUST exist (the team's daily-glance-of-the-business; remove only with a strong rationale)
> - All drill-downs from clickable widgets MUST land on COMPLETED screens (Field Collection #65, Receipt Book #66, Ambassador #67 are all COMPLETED — verified in REGISTRY.md as of 2026-04-30)
> - All alerts in widget 14 MUST be sourced from real entity rules (not faked) — receipt gap detection, low-stock detection, inactive-ambassador rule, pending-approval count
> - Multi-currency conversion MUST be implemented (USD default + Native + EUR/GBP/AED) — `AmbassadorCollection.CurrencyId` makes this entity multi-currency
> - Path-A function contract is non-negotiable (5-arg, 4-col return)

## Tasks

### Planning (by /plan-screens) — ALL DONE
- [x] HTML mockup analyzed (14 widgets, 2 global filters, 11 drill-down targets identified)
- [x] Variant chosen — **MENU_DASHBOARD** (own sidebar leaf at `crm/dashboards/ambassadordashboard`, MenuCode `AMBASSADORDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=4)
- [x] Source entities resolved (6 fund-schema entities + 3 supporting — see § ②.D / § ③)
- [x] Widget catalog drafted (14 widgets — DRAFT; developer may revise per the directive above)
- [x] react-grid-layout config drafted (lg/md/sm/xs breakpoints, 12 cols `lg`, ~31-row height)
- [x] DashboardLayout JSON shape drafted (LayoutConfig multi-breakpoint + ConfiguredWidget instance map)
- [x] Parent menu code + slug + OrderBy already-seeded (no new menu insert; only `Dashboard.MenuId` link)
- [x] First-time MENU_DASHBOARD setup — N/A (infra already shipped via #52 / #124)
- [x] File manifest computed — see § ⑧
- [x] Approval config pre-filled — see § ⑨
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt §①-④ pre-analyzed; BA agent skipped — domain context is unambiguous)
- [x] Solution Resolution complete (prompt §⑤ pre-stamps DASHBOARD/MENU_DASHBOARD/Path-A; SR agent skipped — no decisions left)
- [x] UX Design finalized (widget grid + chart specs + filter controls — locked in §⑥)
- [x] User Approval received
- [x] **Backend (Path-A only — 14 SQL function files in EXISTING `DatabaseScripts/Functions/fund/` folder)** — NO new C# code; reuses existing `generateWidgets` GraphQL handler
- [x] **Frontend — 12 NEW dedicated widget renderers** under `dashboards/widgets/ambassador-dashboard-widgets/`. Each ships `{Name}.tsx + {Name}.types.ts + {Name}.skeleton.tsx + index.ts`. NO reuse of legacy renderers — see policy callout above and § ② widget table.
- [x] FE wiring: register all 12 new renderers in `dashboard-widget-registry.tsx` `WIDGET_REGISTRY` (key = ComponentPath value, value = the React component)
- [x] FE wiring: overwrite [`presentation/pages/crm/dashboards/ambassadordashboard.tsx`](../../../PSS_2.0_Frontend/src/presentation/pages/crm/dashboards/ambassadordashboard.tsx) to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="AMBASSADORDASHBOARD" toolbar={<AmbassadorDashboardToolbar />} />` — see ISSUE-1
- [x] FE: NEW Toolbar component `ambassador-dashboard-toolbar.tsx` housing 2 filter selects + Export/Print buttons; threads filter state via filter context to widgets
- [x] FE: extend `<MenuDashboardComponent />` with optional `toolbar?: ReactNode` prop if not already added by Donation Dashboard #124 (pre-flight check)
- [x] DB Seed file `sql-scripts-dyanmic/AmbassadorDashboard-sqlscripts.sql` (preserve typo) — 7 steps mirroring CaseDashboard-sqlscripts.sql:
      • STEP 0 — Diagnostics (CRM module + BUSINESSADMIN role + AMBASSADORDASHBOARD Menu row exists; pre-flight that the 12 NEW WidgetType rows do NOT yet exist — clean slate before STEP 3)
      • STEP 1 — Insert Dashboard row (idempotent NOT EXISTS)
      • STEP 2 — Link Dashboard.MenuId to seeded AMBASSADORDASHBOARD Menu (idempotent UPDATE WHERE MenuId IS NULL)
      • STEP 3 — Insert **12 NEW WidgetType rows** (one per distinct ComponentPath — see § ② widget table). Each idempotent NOT EXISTS guard.
      • STEP 4 — Insert 14 Widget rows (one statement per widget, each with NOT EXISTS guard, references the right WidgetType + StoredProcedureName)
      • STEP 5 — Insert WidgetRole grants (BUSINESSADMIN read-all on all 14 widgets)
      • STEP 6 — Insert DashboardLayout row (LayoutConfig + ConfiguredWidget JSON × 14)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] All 14 SQL functions exist in `fund.` schema after migration: `SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='fund' AND p.proname LIKE 'fn_ambassador_dashboard_%';` returns 14 rows
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/ambassadordashboard`
- [ ] Network tab shows EXACTLY ONE GraphQL `dashboardByModuleAndCode` request (no `dashboardByModuleCode` leakage — that handler joins UserDashboard, MENU_DASHBOARD has none)
- [ ] All 14 widgets fetch and render with sample data
- [ ] **No legacy renderer is invoked** — `git grep` for `StatusWidgetType1\|MultiChartWidget\|PieChartWidgetType1\|BarChartWidgetType1\|FilterTableWidget\|NormalTableWidget\|TableWidgetType1\|case-dashboard-alerts-widget\|Donation\(.*\)Widget\|Contact\(.*\)Widget` inside `ambassador-dashboard-widgets/` returns zero matches; the seed's WidgetType rows for the 14 widgets all reference `Ambassador*Widget` ComponentPaths
- [ ] Each KPI card shows correct value formatted per spec (currency / percent / count) using its dedicated NEW renderer (Hero / Delta / Ratio / Compliance)
- [ ] Each chart renders correctly using its NEW renderer (combo bar+line, horizontal bars with inline labels, donut with center total, vertical bars with day labels)
- [ ] Each table renders with correct columns + row click drill-down using its NEW renderer
- [ ] Period filter change refetches all date-honoring widgets in parallel
- [ ] Branch filter change refetches all widgets (every widget honors branch)
- [ ] Drill-down clicks navigate per § ⑥ Drill-Down Map (all destination screens are COMPLETED)
- [ ] "Export Report" toasts SERVICE_PLACEHOLDER (no crash — see ISSUE-2)
- [ ] "Print Dashboard" opens browser print dialog
- [ ] Each widget has its own SHAPE-MATCHED skeleton (NOT a generic rectangle) — verify visually during loading
- [ ] Empty / error states render per widget
- [ ] Role-based widget gating: WidgetRole(HasAccess=false) → widget hidden
- [ ] Alerts list (widget 14) generates plausible alert items per the rules in § ④ for sample data
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl)
- [ ] Sidebar leaf "Ambassador Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] Bookmarked URL `/[lang]/crm/dashboards/ambassadordashboard` survives reload
- [ ] Role-gating via existing `RoleCapability(MenuId=AMBASSADORDASHBOARD)` hides the sidebar leaf for unauthorized roles

---

## ① Screen Identity & Context

**Consumer**: All agents — sets the stage

**Screen**: AmbassadorDashboard
**Module**: CRM → Field Collection (sidebar leaf under CRM_DASHBOARDS)
**Schema**: NONE for the dashboard itself (`sett.Dashboards` + `sett.DashboardLayouts` + `sett.Widgets` already exist). NEW Postgres functions added to the EXISTING `fund` schema function folder (`DatabaseScripts/Functions/fund/`) alongside donation-dashboard functions.
**Group**: NONE (no new C# DTOs / handlers — Path-A throughout)

**Dashboard Variant**: **MENU_DASHBOARD** — own sidebar leaf at `crm/dashboards/ambassadordashboard` (MenuCode `AMBASSADORDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=4). NOT in any dropdown switcher.

**Business**:
The Ambassador Dashboard (titled "Field Collection Dashboard" in the mockup — see ISSUE-7 for the title-vs-menu-name reconciliation) is the **operations + branch-management overview** for the Field Collection module — it answers two questions every fundraising/branch lead asks weekly: "Which ambassadors are performing, and where are the gaps?" and "Are receipts and territories being covered correctly?" It rolls up 6 distinct field-collection surfaces — ambassadors (`fund.Ambassadors`), their territories (`fund.AmbassadorTerritories`), receipt-book assignments (`fund.AmbassadorReceiptBookAssignments`), the receipt books themselves (`fund.ReceiptBooks`), individual collection entries (`fund.AmbassadorCollections`), and target/branch context — into a single board-level summary. **Target audience**: Branch Manager, Fundraising Director, Field Operations Lead, and donor-care staff who triage receipt gaps, replace exhausted books, follow up on inactive ambassadors, and approve back-dated or high-value collections. **Why it exists**: the existing list pages (#65 Field Collection, #66 Receipt Book, #67 Ambassador) serve transactional CRUD but offer no cross-cutting "is field collection healthy this month?" view. The dashboard surfaces total-collections KPIs, ambassador leaderboard, branch comparison, payment-mode mix, day-of-week patterns, territory coverage map, territory-by-territory summary, and an actionable alerts feed in one place. **Why MENU_DASHBOARD (not STATIC)**: deep-linkable from emailed branch reports; role-restricted to fundraising / field-ops staff (not all CRM users); tightly scoped to ambassador operations — no need to share dropdown space with Case / Communication / Donation / Volunteer dashboards. Distinct from #134 Ambassador Performance (per-ambassador deep-dive — different scope, separate dashboard). Sibling design of Donation Dashboard #124 (same MENU_DASHBOARD pattern, emerald accent `#059669` matches mockup `--field-accent`) — but Ambassador Dashboard ships its OWN dedicated FE renderers per the new policy (Donation Dashboard's `Donation*Widget` set is NOT reused).

---

## ② Entity Definition

**Consumer**: BA Agent → Backend Developer

> Dashboard does NOT introduce a new entity. It composes **two seeded rows** (`sett.Dashboards` + `sett.DashboardLayouts`) over **6 existing source entities**.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `AMBASSADORDASHBOARD` | Matches Menu.MenuCode |
| DashboardName | `Ambassador Dashboard` | Matches Menu.MenuName (mockup title says "Field Collection Dashboard" but the seeded menu name is authoritative — see ISSUE-7) |
| DashboardIcon | `chart-line-bold` | Phosphor icon (matches mockup `fa-chart-line` page-header icon; menu row already uses `solar:map-arrow-right-bold` — Dashboard.DashboardIcon is the page-level icon, distinct from the sidebar Menu.MenuIcon) |
| DashboardColor | `#059669` | Emerald accent from mockup `--field-accent` |
| ModuleId | (resolve from `auth.Modules WHERE ModuleCode='CRM'`) | CRM module |
| IsSystem | `true` | System-seeded |
| IsActive | `true` | — |
| CompanyId | NULL | Global system dashboard |
| MenuId | (resolve from `auth.Menus WHERE MenuCode='AMBASSADORDASHBOARD'`) | Set in seed STEP 2; NULL leaves the slug page returning "Dashboard not found" |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | JSON: `{"lg":[…14 layout items…], "md":[…], "sm":[…], "xs":[…]}` | All 4 breakpoints REQUIRED — `<MenuDashboardComponent />` reads each. Do NOT submit only `lg`. |
| ConfiguredWidget | JSON: `[{i, widgetId}, … 14 entries]` | `i` = instance code (e.g., `KPI_TOTAL_COLLECTIONS`); `widgetId` resolves to a `sett.Widgets` row in STEP 4. |

### C. Widget Definitions (`sett.Widgets` + `sett.WidgetTypes`)

> All Path-A — each widget has `StoredProcedureName` set; `DefaultQuery` is NULL.
> **All 12 ComponentPaths below are NEW** (per the renderer policy — no reuse of legacy `WIDGET_REGISTRY` keys). Seed STEP 3 inserts one `sett.WidgetTypes` row per distinct ComponentPath; STEP 4 inserts 14 `sett.Widgets` rows referencing those types.

| # | WidgetCode (=instanceId) | WidgetName | ComponentPath (NEW) | StoredProcedureName | OrderBy |
|---|--------------------------|------------|---------------------|---------------------|---------|
| 1 | KPI_TOTAL_COLLECTIONS | Total Collections | **AmbassadorHeroKpiWidget** *(hero — emerald gradient header strip + 6-mo sparkline + bold currency value, hand-holding-dollar icon)* | fund.fn_ambassador_dashboard_kpi_total_collections | 1 |
| 2 | KPI_COLLECTION_COUNT | Collection Count | **AmbassadorDeltaKpiWidget** *(supporting — teal accent, dual-value: count + % delta vs last month, receipt icon)* | fund.fn_ambassador_dashboard_kpi_collection_count | 2 |
| 3 | KPI_ACTIVE_AMBASSADORS | Active Ambassadors | **AmbassadorRatioKpiWidget** *(distinct — X/Y ratio format with denominator muted, inactive-count danger sub-badge, blue accent, users icon)* | fund.fn_ambassador_dashboard_kpi_active_ambassadors | 3 |
| 4 | KPI_AVG_PER_AMBASSADOR | Avg per Ambassador | AmbassadorDeltaKpiWidget *(2nd delta instance — green accent, dual-value: $ + $ delta, chart-simple icon)* | fund.fn_ambassador_dashboard_kpi_avg_per_ambassador | 4 |
| 5 | KPI_UNIQUE_DONORS | Unique Donors Visited | AmbassadorHeroKpiWidget *(2nd hero instance — purple gradient strip + new-donor sparkline, user-group icon)* | fund.fn_ambassador_dashboard_kpi_unique_donors | 5 |
| 6 | KPI_RECEIPT_COMPLIANCE | Receipt Compliance | **AmbassadorComplianceKpiWidget** *(distinct — orange-tinted card, primary % value + danger gap-count sub-badge, clipboard-check icon, attention treatment)* | fund.fn_ambassador_dashboard_kpi_receipt_compliance | 6 |
| 7 | CHART_COLLECTION_TREND | Collection Trend (Last 6 Months) | **AmbassadorCollectionTrendWidget** *(unique — combo bar+line chart: bars=monthly amount, line=transaction count overlay; emerald-to-mint gradient bars; annotation pin for Ramadan/seasonal spikes)* | fund.fn_ambassador_dashboard_collection_trend | 7 |
| 8 | CHART_BY_BRANCH | Collections by Branch | **AmbassadorBranchBarsWidget** *(unique — horizontal bars with inline value labels, emerald-to-mint linear gradient, "Others" bucket below threshold)* | fund.fn_ambassador_dashboard_by_branch | 8 |
| 9 | TBL_LEADERBOARD | Ambassador Leaderboard | **AmbassadorLeaderboardWidget** *(unique — rank badges 🥇🥈🥉 for top 3, achievement progress bar (over/under target with green/amber color), trend-arrow column, sortable headers, link-style ambassador names)* | fund.fn_ambassador_dashboard_leaderboard | 9 |
| 10 | CHART_PAYMENT_MODE | Collection by Payment Mode | **AmbassadorPaymentModeDonutWidget** *(unique — donut with center total + per-segment legend showing $ + %)* | fund.fn_ambassador_dashboard_payment_mode | 10 |
| 11 | CHART_BY_DAY_OF_WEEK | Collection by Day of Week | **AmbassadorDayOfWeekBarsWidget** *(unique — vertical bars Mon-Sun, emerald gradient, value labels above bars, footer callout for Friday/Saturday peaks)* | fund.fn_ambassador_dashboard_day_of_week | 11 |
| 12 | MAP_TERRITORY_COVERAGE | Territory Coverage | **AmbassadorTerritoryMapWidget** *(unique — placeholder geographic visualization with density legend (high/moderate/low/none), styled as gradient panel; SERVICE_PLACEHOLDER on real-map integration but UI fully built — see ISSUE-3)* | fund.fn_ambassador_dashboard_territory_coverage | 12 |
| 13 | TBL_TERRITORY_SUMMARY | Territory Summary | **AmbassadorTerritorySummaryWidget** *(unique — table with territory / ambassador link / contacts / visited (count + %) / coverage badge (low/medium/high) / collection $ — pill-shaped coverage badges)* | fund.fn_ambassador_dashboard_territory_summary | 13 |
| 14 | LIST_ALERTS | Alerts & Action Items | **AmbassadorAlertsListWidget** *(unique — severity-colored alert rows with circular icon + bold strong text + action button per row; sanitized `<strong>` only; warning/info severities)* | fund.fn_ambassador_dashboard_alerts | 14 |

**Distinct ComponentPaths = 12** → 12 new `sett.WidgetTypes` rows in seed STEP 3:

| # | WidgetTypeCode | WidgetTypeName | ComponentPath | Visual Treatment |
|---|----------------|----------------|---------------|------------------|
| 1 | AMBASSADOR_HERO_KPI | Ambassador Hero KPI | AmbassadorHeroKpiWidget | LARGE card (h=3 cell), 6-mo sparkline, gradient header strip (emerald or purple per instance), bold value + delta arrow, trend microcopy. Used 2× (Total Collections + Unique Donors) — these are the 2 headline stats |
| 2 | AMBASSADOR_DELTA_KPI | Ambassador Delta KPI | AmbassadorDeltaKpiWidget | Mid-size card (h=2), dual-value layout: current + secondary metric (count for Collection Count; $ delta for Avg per Ambassador), trend % with colored arrow, no sparkline. Teal/green accent per instance. Used 2× |
| 3 | AMBASSADOR_RATIO_KPI | Ambassador Ratio KPI | AmbassadorRatioKpiWidget | Compact card (h=2), X/Y ratio format ("34 / 38" with denominator muted gray), inactive-count danger sub-badge in pill style, blue accent, distinct from Hero/Delta. Used 1× (Active Ambassadors) |
| 4 | AMBASSADOR_COMPLIANCE_KPI | Ambassador Compliance KPI | AmbassadorComplianceKpiWidget | Compact card (h=2), orange-tinted background, primary % value + danger gap-count sub-badge in pill style, attention-seeking treatment. Used 1× (Receipt Compliance) |
| 5 | AMBASSADOR_COLLECTION_TREND | Ambassador Collection Trend | AmbassadorCollectionTrendWidget | Combo bar+line chart, 6-month last-6-mo window, bars = monthly currency amount (emerald-to-mint gradient), line = transaction count overlay (purple/blue). Annotation pins for seasonal events (Ramadan). Used 1× |
| 6 | AMBASSADOR_BRANCH_BARS | Ambassador By-Branch Bars | AmbassadorBranchBarsWidget | Top-5 + "Others" horizontal bars, inline value labels, color-graded bars by amount rank (full-width emerald → faded for "Others"). Used 1× |
| 7 | AMBASSADOR_LEADERBOARD | Ambassador Leaderboard | AmbassadorLeaderboardWidget | 10-col table with rank-badge column (🥇🥈🥉 for top 3, gray circle for 4+), avatar/link ambassador name, branch text, collections count, amount $, donors, avg/visit, trend arrow + %, target $, achievement bar with % label (over=green, under=amber). Sortable headers. Used 1× |
| 8 | AMBASSADOR_PAYMENT_MODE_DONUT | Ambassador Payment Mode Donut | AmbassadorPaymentModeDonutWidget | Donut chart with center total ($67.8K + "Total" label), 4-segment legend (Cash / Cheque / Mobile / Bank) showing $ amount + percent. Used 1× |
| 9 | AMBASSADOR_DAY_OF_WEEK_BARS | Ambassador Day-of-Week Bars | AmbassadorDayOfWeekBarsWidget | 7 vertical bars (Mon-Sun), emerald gradient (180deg to mint at top), value labels above, day labels below, footer-row callouts for Friday "Mosque collections" + Saturday "Home visits peak". Used 1× |
| 10 | AMBASSADOR_TERRITORY_MAP | Ambassador Territory Map | AmbassadorTerritoryMapWidget | Placeholder map panel — gradient background + map-pin icon overlay + density legend (4 dot colors: high/moderate/low/none). Designed to be swapped for a real map (Leaflet/Mapbox) when geocoded data is available — see ISSUE-3. Used 1× |
| 11 | AMBASSADOR_TERRITORY_SUMMARY | Ambassador Territory Summary Table | AmbassadorTerritorySummaryWidget | Table — territory name / ambassador (linked) / contacts count / visited count + % parenthetical / coverage badge (pill-shaped: low=red-tint, medium=amber-tint, high=green-tint) / collection amount. Used 1× |
| 12 | AMBASSADOR_ALERTS_LIST | Ambassador Alerts & Action Items | AmbassadorAlertsListWidget | Severity-colored alert rows (warning / info — distinct icon-circle bg + outer border), sanitized `<strong>` only in message, action button per row (outline-emerald style with hover fill). Header right-end shows total-count pill. Used 1× |

### D. Source Entities (read-only — what the widgets aggregate over)

| # | Source Entity | Schema.Table | File Path | Purpose |
|---|--------------|--------------|-----------|---------|
| 1 | Ambassador | `fund.Ambassadors` | [`Base.Domain/Models/FieldCollectionModels/Ambassador.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/Ambassador.cs) | KPI 3 (Active count + inactive sub-badge), KPI 4 denominator (avg per ambassador), Leaderboard rows, Inactive-ambassador alert. Status field gates Active vs Inactive. |
| 2 | AmbassadorTerritory | `fund.AmbassadorTerritories` | [`Base.Domain/Models/FieldCollectionModels/AmbassadorTerritory.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/AmbassadorTerritory.cs) | Territory Summary table rows, Territory Map labels. Joined to Ambassador for the per-territory ambassador name. |
| 3 | AmbassadorReceiptBookAssignment | `fund.AmbassadorReceiptBookAssignments` | [`Base.Domain/Models/FieldCollectionModels/AmbassadorReceiptBookAssignment.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/AmbassadorReceiptBookAssignment.cs) | Receipt-book-low-stock alert (UsedCount/TotalCount > 75%). Links Ambassador to ReceiptBook. |
| 4 | AmbassadorCollection | `fund.AmbassadorCollections` | [`Base.Domain/Models/FieldCollectionModels/AmbassadorCollection.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/AmbassadorCollection.cs) | KPIs 1/2/4/5, Collection Trend (chart 7), By-Branch (chart 8), Leaderboard (table 9), Payment Mode (chart 10), Day-of-Week (chart 11), Territory Summary collection $ (table 13), Pending-approval alert (Status='Pending'), Receipt-gap rule (gaps in ReceiptNumber sequence). Has `DonationAmount`, `CurrencyId`, `PaymentModeId`, `CollectedDate`, `Status`, `ReceiptNumber`, `ReceiptBookId`, `BranchId`, `AmbassadorId`. |
| 5 | ReceiptBook | `fund.ReceiptBooks` | [`Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs) | KPI 6 (Receipt Compliance — gap detection), Receipt-gap alert (RB-XXX gaps), Books-low-stock alert. Has `ReceiptStartNo`, `ReceiptEndNo`, `ReceiptCount`, `BranchId`. Used to compute "expected" receipt sequence vs. used receipts. |
| 6 | Contact | `corg.Contacts` | [`Base.Domain/Models/ContactModels/Contact.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/Contact.cs) | Joined to AmbassadorCollection.ContactId for unique-donor count (KPI 5) and AmbassadorCollection.AmbassadorContactId for ambassador display name in leaderboard. |
| — | Branch | `app.Branches` | [`Base.Domain/Models/ApplicationModels/Branch.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Branch.cs) | Branch filter dropdown source + Collections-by-Branch chart label resolution + per-row branch column in Leaderboard |
| — | PaymentMode | `com.PaymentModes` | [`Base.Domain/Models/SharedModels/PaymentMode.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/PaymentMode.cs) | Payment Mode donut (chart 10) — segment labels (Cash / Cheque / Mobile / Bank). PaymentModeCode used for drill-down filter. |
| — | Currency | `com.Currencies` | [`Base.Domain/Models/SharedModels/Currency.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs) | Currency conversion for multi-currency aggregation (every $-bearing widget); see § ④ Multi-Currency Rules |

---

## ③ Source Entity & Aggregate Query Resolution

**Consumer**: Backend Developer (Postgres function authors) + Frontend Developer (widget binding via `Widget.StoredProcedureName`)

> Path-A across all 14 widgets. Each widget calls `SELECT * FROM fund."{function_name}"(p_filter_json::jsonb, p_page, p_page_size, p_user_id, p_company_id)` via the existing `generateWidgets` GraphQL handler.

| # | Source Entity(s) | Postgres Function | Returns (`data_json` shape — NEW renderer consumes this directly) | Filter Args (in p_filter_json) |
|---|-----------------|-------------------|------|----|
| 1 | AmbassadorCollection (date-range SUM) | `fund.fn_ambassador_dashboard_kpi_total_collections` | `{value: number, formatted: string, deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', subtitle: string, sparkline: { labels: string[6], data: number[6] }, accent: 'emerald'}` | dateFrom, dateTo, branchId, displayCurrency |
| 2 | AmbassadorCollection (date-range COUNT) | `fund.fn_ambassador_dashboard_kpi_collection_count` | `{value: number, formatted: string, secondaryLabel: string, secondaryFormatted: string, deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', accent: 'teal'}` | dateFrom, dateTo, branchId |
| 3 | Ambassador (active vs total + inactive last-N-days) | `fund.fn_ambassador_dashboard_kpi_active_ambassadors` | `{activeCount: int, totalCount: int, ratioFormatted: string ("34 / 38"), inactiveCount: int, inactiveLabel: string ("4 inactive"), severity: 'warning' \| 'danger' \| 'neutral', accent: 'blue'}` | branchId |
| 4 | AmbassadorCollection ÷ Ambassador active count | `fund.fn_ambassador_dashboard_kpi_avg_per_ambassador` | same `{value, formatted, secondaryLabel, secondaryFormatted, deltaLabel, deltaColor, accent: 'green'}` shape — secondaryLabel/Formatted = "$231 vs last month" | dateFrom, dateTo, branchId, displayCurrency |
| 5 | AmbassadorCollection (DISTINCT ContactId) | `fund.fn_ambassador_dashboard_kpi_unique_donors` | `{value: number, formatted: string, deltaLabel: string, deltaColor: 'positive', subtitle: string ("67 new donors (17.2%)"), sparkline: { labels: string[6], data: number[6] }, accent: 'purple'}` | dateFrom, dateTo, branchId |
| 6 | ReceiptBook + AmbassadorCollection (gap detection) | `fund.fn_ambassador_dashboard_kpi_receipt_compliance` | `{value: number (e.g., 98.2), formatted: '98.2%', gapCount: int, gapLabel: string ("3 gaps detected"), severity: 'warning' \| 'danger' \| 'neutral'}` | dateFrom, dateTo, branchId |
| 7 | AmbassadorCollection (group by month, last 6) | `fund.fn_ambassador_dashboard_collection_trend` | `{type: 'combo', labels: string[6] (month names), bars: { name: 'Amount', data: number[6], formattedData: string[6] }, line: { name: 'Transactions', data: number[6] }, annotations?: [{xValue: string, label: string}]}` | branchId, displayCurrency |
| 8 | AmbassadorCollection + Branch (group by BranchId) | `fund.fn_ambassador_dashboard_by_branch` | `{rows: [{branchId: int, branchName: string, value: number, valueFormatted: string, widthPct: int, color: string}]}` — top 5 + "Others" bucket, ORDER BY value DESC | dateFrom, dateTo, displayCurrency |
| 9 | Ambassador + AmbassadorCollection (group by AmbassadorId) | `fund.fn_ambassador_dashboard_leaderboard` | `{rows: [{rank: int, ambassadorId: int, contactId: int, ambassadorName: string, branchName: string, collections: int, amount: number, amountFormatted: string, donors: int, avgPerVisit: number, avgPerVisitFormatted: string, trendPct: number, trendDirection: 'up'\|'down'\|'flat', target: number, targetFormatted: string, achievementPct: number, achievementColor: 'over'\|'under', isStarred: bool}]}` — top 10 by amount DESC | dateFrom, dateTo, branchId, displayCurrency |
| 10 | AmbassadorCollection + PaymentMode (group by PaymentModeId) | `fund.fn_ambassador_dashboard_payment_mode` | `{total: number, totalFormatted: string ('$67.8K'), giftCount: int, segments: [{label: string, paymentModeCode: string, value: number, valueFormatted: string, pct: number, color: string}]}` — typically 4 segments (Cash/Cheque/Mobile/Bank) | dateFrom, dateTo, branchId, displayCurrency |
| 11 | AmbassadorCollection (group by EXTRACT(DOW FROM CollectedDate)) | `fund.fn_ambassador_dashboard_day_of_week` | `{bars: [{day: 'Mon'\|'Tue'\|…, value: number, valueFormatted: string ('$12.3K'), heightPct: int}], peakDay: string, footer: { left: string, right: string }}` — 7 entries (Mon-Sun), heightPct relative to max bar | dateFrom, dateTo, branchId, displayCurrency |
| 12 | AmbassadorTerritory + AmbassadorCollection (per-territory aggregate) | `fund.fn_ambassador_dashboard_territory_coverage` | `{type: 'placeholder-map', territories: [{territoryName: string, lat?: number, lng?: number, density: 'high'\|'moderate'\|'low'\|'none', collectionAmount: number}], legend: [{label: 'High density', color: '#166534'}, {label: 'Moderate', color: '#86efac'}, {label: 'Low activity', color: '#d1d5db'}, {label: 'No coverage', color: '#ffffff', borderColor: '#d1d5db'}]}` — placeholder map; renderer shows gradient panel + density legend | dateFrom, dateTo, branchId |
| 13 | AmbassadorTerritory + Ambassador + AmbassadorCollection + Contact-count | `fund.fn_ambassador_dashboard_territory_summary` | `{rows: [{territoryId: int, territoryName: string, ambassadorId: int, ambassadorName: string, contactsTotal: int, visitedCount: int, visitedPct: number, coverage: 'low'\|'medium'\|'high', collectionAmount: number, collectionAmountFormatted: string}]}` — top territories ORDER BY collectionAmount DESC, hard cap 10 rows | dateFrom, dateTo, branchId, displayCurrency |
| 14 | Cross-source rule engine | `fund.fn_ambassador_dashboard_alerts` | `{alerts: [{severity: 'warning'\|'info'\|'danger', iconCode: 'phosphor-name', message: string (sanitized HTML, `<strong>` only), link: { label: string, route: string, args: object }}], totalCount: int}` — top 10 by severity then recency | dateFrom, dateTo, branchId |

**Strategy**: **Path A — Postgres functions only**. No composite C# DTO; no per-widget GraphQL handler. Each widget binds to one function via `Widget.StoredProcedureName`. The runtime calls the existing `generateWidgets` GraphQL field with the function name + filter context. Matches the established Case Dashboard #52 / Donation Dashboard #124 precedent.

---

## ④ Business Rules & Validation

**Consumer**: BA Agent → Backend Developer (Postgres functions enforce filtering) → Frontend Developer (filter behavior + drill-down args)

### Date Range Defaults
- Default range: **This Month** (1st of current calendar month → today) — matches mockup default
- Allowed presets: This Month / Last Month / This Quarter / Last Quarter / Custom Range
- Custom range max span: **2 years** (FE filter validation; functions cap p_filter_json span if larger)
- Date filter applies to: `AmbassadorCollection.CollectedDate` (KPIs 1/2/4/5/6, charts 7/8/10/11, table 9, table 13, alerts), `AmbassadorReceiptBookAssignment.IssuedDate` + computed `UsedCount` ratio (alert: low-stock books). Active-Ambassador-count (KPI 3) uses Ambassador.Status='Active' (no date filter).

### Role-Scoped Data Access
- **BUSINESSADMIN** → sees ALL companies' data
- **CRM_MANAGER / FUNDRAISING_DIRECTOR** → own company only (`CompanyId = HttpContext.CompanyId`)
- **BRANCH_MANAGER** → additionally filtered by `BranchId IN user's branches` (read from `auth.UserBranches`)
- **DONOR_CARE / FIELD_OPS_USER** → company-scoped; no branch restriction
- All scoping happens in the Postgres function via `p_user_id` + `p_company_id` parameters

### Calculation Rules
- **KPI 1 — Total Collections**: `SUM(AmbassadorCollection.DonationAmount WHERE CollectedDate IN range AND Status IN ('Approved','Pending') AND IsDeleted=false)`. `deltaPct = ((current - sameRangeLastMonth) / sameRangeLastMonth) * 100`. Subtitle: "↑ {deltaPct}% vs last month" (positive=green, negative=red).
- **KPI 2 — Collection Count**: `COUNT(AmbassadorCollection WHERE CollectedDate IN range AND Status IN ('Approved','Pending'))`. `deltaPct` computed same as KPI 1. secondaryLabel="transactions".
- **KPI 3 — Active Ambassadors**: `activeCount = COUNT(Ambassador WHERE Status='Active' AND CompanyId=p_company_id)`; `totalCount = COUNT(Ambassador WHERE CompanyId=p_company_id)`; `inactiveCount = COUNT(Ambassador WHERE Status='Inactive' OR Status='Suspended')`. severity='warning' if inactiveCount >= 3, else 'neutral'.
- **KPI 4 — Avg per Ambassador**: `Total Collections / activeAmbassadorCount`. `deltaAmount = currentAvg - lastMonthAvg`. secondaryFormatted = "$231 vs last month".
- **KPI 5 — Unique Donors Visited**: `COUNT(DISTINCT AmbassadorCollection.ContactId WHERE CollectedDate IN range)`. `newDonorsCount = COUNT(DISTINCT ContactId WHERE first AmbassadorCollection EVER falls in range)`. subtitle = "{newDonorsCount} new donors ({newDonorsCount/value*100}%)".
- **KPI 6 — Receipt Compliance**:
  - `expectedReceipts = SUM(ReceiptCount in books that have AT LEAST ONE collection in date range)`
  - `usedReceipts = COUNT(DISTINCT ReceiptNumber from AmbassadorCollection in range)`
  - `gapCount = expectedReceipts - usedReceipts` per gap-detection logic (gaps in receipt-number sequence within each book — see ISSUE-4)
  - `compliancePct = ((expectedReceipts - gapCount) / expectedReceipts) * 100` (pre-formatted to 1 decimal)
  - severity = 'danger' if gapCount > 0, else 'neutral'
- **Leaderboard achievement (table 9)**:
  - `target` = Ambassador's monthly target (from `Ambassador.MonthlyTarget` if it exists, else uses `Ambassador.Branch.DefaultTarget`, else falls back to median of branch peers — confirm exact column during build, see ISSUE-5)
  - `achievementPct = (collectionAmount / target) * 100`
  - `achievementColor = 'over'` if achievementPct >= 100, else `'under'`
  - `isStarred` = true if achievementPct >= 100 (renders ⭐ next to value)
  - `trendDirection`: compare current period amount to same-range-last-month — "up" if > +5%, "down" if < -5%, "flat" otherwise
- **Payment Mode segments (chart 10)**: group `AmbassadorCollection.PaymentModeId`. Hardcoded color palette per `PaymentMode.PaymentModeCode`:
  - `CASH` → emerald `#059669`
  - `CHEQUE` → blue `#3b82f6`
  - `MOBILE` (or `MPESA`/`MOBILE_MONEY`) → orange `#f97316`
  - `BANK` (or `BANK_TRANSFER`) → purple `#8b5cf6`
  - Other modes → gray `#94a3b8`
  - Confirm exact PaymentModeCode strings during build (see ISSUE-6)
- **Day of Week (chart 11)**: `EXTRACT(DOW FROM CollectedDate)` → 0=Sun..6=Sat. Map to display labels Mon-Sun (Mon first per mockup). `heightPct = round((value / MAX(value)) * 100)` so the tallest bar is 100%. Footer callout — left: "🕌 Fri: Mosque collections" (when Fri value > 60% of peak), right: "🏠 Sat: Home visits peak" (when Sat is the peak).
- **Coverage badge (table 13)**: `visitedPct = (visitedCount / contactsTotal) * 100`. `coverage = 'high'` if visitedPct >= 20, `'medium'` if 10 ≤ visitedPct < 20, `'low'` if visitedPct < 10. Pill color: high=green-tint, medium=amber-tint, low=red-tint.
- **Alert generation rules (widget 14)** — sanitization: only `<strong>` tags allowed; all other HTML escaped:
  - WARNING if `gapCount > 0` → "<strong>{gapCount} receipt gaps detected</strong> &mdash; {top-3 gap codes joined}" → `crm/fieldcollection/collectionlist?gapsOnly=true` (see ISSUE-9 for arg confirmation)
  - WARNING if `count(books WHERE UsedCount/ReceiptCount > 0.75) > 0` → "<strong>{N} ambassadors need new receipt books</strong> &mdash; books >75% used" → `crm/fieldcollection/receiptbooks?lowStock=true`
  - INFO if `count(ambassadors WHERE no AmbassadorCollection in current month) > 0` → "<strong>{N} ambassadors inactive this month</strong> &mdash; {top-3 names joined}" → `crm/fieldcollection/ambassadorlist?inactiveThisMonth=true`
  - INFO if `count(AmbassadorCollection WHERE Status='Pending') > 0` → "<strong>{N} collections pending approval</strong> &mdash; back-dated or high-value" → `crm/fieldcollection/collectionlist?status=Pending`
  - Hard cap of 10 alerts (top 10 by severity then recency)

### Multi-Currency Rules
- **Display Currency** filter (header) — proposed enhancement to mockup. Mockup shows only Period + Branch; the dashboard MUST handle multi-currency since `AmbassadorCollection.CurrencyId` is per-row. **Decision**: ship a 3rd filter "Currency" in the toolbar (default USD Base), matching Donation Dashboard #124 pattern. See ISSUE-8 for the in-scope confirmation.
- **Conversion math**: all currency-bearing values converted to displayCurrency using each row's recorded ExchangeRate (FX at collection time). If a row has no ExchangeRate, fall back to current rate from `com.Currencies.ExchangeRate`. If displayCurrency='Native Currency', skip conversion and aggregate row-currency-by-row-currency — KPIs surface a "Mixed currency totals" tooltip via `metadata.mixedCurrencyFlag=true`.

### Widget-Level Rules
- A widget is RENDERED only if `auth.WidgetRoles(WidgetId, currentRoleId, HasAccess=true)` row exists. No row → widget hidden.
- All 14 widgets seed `WidgetRole(BUSINESSADMIN, HasAccess=true)`. Other roles assigned at admin-config time.
- **Workflow**: None. Read-only. Drill-downs navigate AWAY.

---

## ⑤ Screen Classification & Pattern Selection

**Consumer**: Solution Resolver — these are PRE-ANSWERED.

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Standalone analytical surface deep-linkable from emailed branch reports; role-restricted to fundraising / field-ops / branch-manager staff; tightly scoped to ambassador / field-collection operations. Already has its own sidebar leaf at `/crm/dashboards/ambassadordashboard`.

**Backend Implementation Path** — **Path A across all 14 widgets**:
- [x] **Path A — Postgres function (generic widget)**: Each widget = 1 SQL function in `fund.` schema returning `(data_json text, metadata_json text, total_count integer, filtered_count integer)`. Reuses existing `generateWidgets` GraphQL handler. Seed `Widget.StoredProcedureName='fund.{function_name}'`. NO new C# code; only 14 SQL deliverables. Matches Case Dashboard #52 / Donation Dashboard #124 precedent.
- [ ] Path B — Named GraphQL query (NOT used)
- [ ] Path C — Composite DTO (NOT used)

**Path-A Function Contract (NON-NEGOTIABLE)** — every function MUST:
- Take 5 fixed inputs in this order: `p_filter_json jsonb DEFAULT '{}'::jsonb, p_page integer DEFAULT 0, p_page_size integer DEFAULT 10, p_user_id integer DEFAULT 0, p_company_id integer DEFAULT NULL`
- Return `TABLE(data_json text, metadata_json text, total_count integer, filtered_count integer)` — single row, 4 columns. Match Case/Donation Dashboard's `data_json text` (NOT `data jsonb`); the runtime parses JSON-stringified text.
- Extract every filter from `p_filter_json` using `NULLIF(p_filter_json->>'keyName','')::type`. Filter keys: `dateFrom`, `dateTo`, `branchId`, `displayCurrency` (3-char code: 'USD'/'EUR'/'GBP'/'AED' or 'NATIVE')
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators)
- Live at `PSS_2.0_Backend/DatabaseScripts/Functions/fund/{function_name}.sql` — snake_case names. Folder ALREADY exists (created by Donation Dashboard #124).
- `Widget.DefaultParameters` JSON keys MUST match the keys that the function reads from `p_filter_json` (e.g., `{ "dateFrom": "{dateFrom}", "dateTo": "{dateTo}", "branchId": "{branchId}", "displayCurrency": "{displayCurrency}" }` — placeholders substituted by widget runtime)
- Tenant scoping via `p_company_id` — every function gates with `WHERE CompanyId = p_company_id OR p_company_id IS NULL`
- Currency conversion via CTE: `WITH base AS (SELECT *, DonationAmount * COALESCE(ExchangeRate, fallback_rate) AS amount_in_display_currency FROM ...)`

**Backend Patterns Required:**
- [x] Tenant scoping (CompanyId from HttpContext via p_company_id arg) — every function
- [x] Date-range parameterized queries
- [x] Role-scoped data filtering — joined to `auth.UserBranches` for BRANCH_MANAGER
- [ ] Materialized view / cached aggregate — not for v1; pre-flag ISSUE if any function exceeds 2s p95.

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` (responsive breakpoints) — already in `<MenuDashboardComponent />`
- [x] **NEW renderers per widget shape** — create under `dashboards/widgets/ambassador-dashboard-widgets/` and register each in `WIDGET_REGISTRY` (`dashboard-widget-registry.tsx`). **12 distinct ComponentPaths** per § ② widget table (4 KPI variants + 8 single-use renderers). Each renderer ships `{Name}.tsx + {Name}.types.ts + {Name}.skeleton.tsx + index.ts`.
- [x] **Visual uniqueness across widgets** — each renderer must have a distinct visual signature: different accent color, different icon, different chrome (gradient strip / amber tint / orange tint / blue ratio / pill badges), different skeleton shape. Verify by side-by-side screenshot review during build — if two widgets feel "samey," split them further. The 6 KPIs are SPLIT across 4 renderers (Hero / Delta / Ratio / Compliance) to avoid the "6 identical KPI tiles" anti-pattern.
- [x] **Vary `LayoutConfig` cell heights/widths to signal importance** — Hero KPIs use h=3 cells (taller); supporting KPIs use h=2; full-width tables use w=12; side-by-side comparisons use w=5+7 or w=7+5 (chart vs map vs summary). The grid itself communicates hierarchy before the renderer chrome does.
- [ ] **Reuse legacy `WIDGET_REGISTRY` renderer — DISALLOWED** for this dashboard. `StatusWidgetType1`, `MultiChartWidget`, `PieChartWidgetType1`, `BarChartWidgetType1`, `FilterTableWidget`, `NormalTableWidget`, `case-dashboard-alerts-widget`, `Donation*Widget`, `Contact*Widget` are FROZEN to their original dashboards.
- [ ] **Anti-patterns to actively avoid** (forbidden by feedback memory):
      • One renderer used for ALL KPIs with only label/value swapped — split into Hero / Delta / Ratio / Compliance per visual hierarchy
      • A single chart component toggling `chartType` for all chart widgets — separate combo / horizontal-bar / donut / vertical-bar renderers
      • Identical card chrome (border, padding, header layout) across every widget
      • Generic shimmer-rectangle skeletons — every renderer ships a shape-matched skeleton
      • Territory Map and Territory Summary merged into one widget — they ship as 2 separate renderers per the mockup's two-column layout
- [x] Query registry — NOT extended (Path A uses `generateWidgets` only)
- [x] Period select / Branch select / Currency select / Export Report / Print Dashboard — NEW `ambassador-dashboard-toolbar.tsx` houses these and threads filter state via filter context to widgets
- [x] Skeleton states matching widget shapes — **shape-matched per NEW renderer** (KPI tile skeleton, donut ring skeleton, combo chart skeleton, horizontal-bar table skeleton, vertical-day-bar skeleton, leaderboard 10-row skeleton, map placeholder skeleton, territory 8-row skeleton, alert-row 4-stub skeleton — match the renderer's actual layout, NOT a generic rectangle)
- [x] **MENU_DASHBOARD page** — uses already-existing `<MenuDashboardComponent />`. Existing per-route stub at `[lang]/crm/dashboards/ambassadordashboard/page.tsx` references `ambassadordashboard.tsx` wrapper; the WRAPPER is overwritten to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="AMBASSADORDASHBOARD" toolbar={<AmbassadorDashboardToolbar />} />`. See ISSUE-1.
- [ ] **Toolbar overrides** — `<MenuDashboardComponent />` should already have a `toolbar?: ReactNode` prop after Donation Dashboard #124 (ISSUE-4 in that prompt). Pre-flight check during build: if not yet present, add it.

---

## ⑥ UI/UX Blueprint

**Consumer**: UX Architect → Frontend Developer

> Layout follows the HTML mockup. All widgets render through `<MenuDashboardComponent moduleCode="CRM" dashboardCode="AMBASSADORDASHBOARD" />` → resolves to the seeded Dashboard row → reads LayoutConfig + ConfiguredWidget JSON → maps each instance to its NEW `Ambassador*Widget` renderer + Postgres function.

**Layout Variant**: `widgets-above-grid+side-panel` — widget grid is the dashboard. No CRUD grid. Header has filter controls + action buttons (toolbar slot).

### Page Chrome (MENU_DASHBOARD)

- **Header row** (rendered via `<MenuDashboardComponent />` lean header + `toolbar` prop):
  - Left: page title `Ambassador Dashboard` + icon `chart-line-bold` (emerald) + subtitle `Ambassador performance and collection analytics`
  - Right (toolbar slot — composed by NEW `ambassador-dashboard-toolbar.tsx`): **3 filter selects + 2 buttons + Refresh icon**:
    1. **Period select** — default "This Month"; options: This Month / Last Month / This Quarter / Last Quarter / Custom Range. "Custom Range" opens an inline date-range popover.
    2. **Branch select** — default "All Branches" (or user's branch for BRANCH_MANAGER); dynamic from `app.Branches WHERE IsActive=true` via existing `branches` GQL query.
    3. **Currency select** — default "USD (Base)"; options: USD (Base) / Native Currency / EUR / GBP / AED. (Mockup omits this; included per § ④ multi-currency rules — ISSUE-8.)
    4. **"Export Report"** outline button (emerald) — SERVICE_PLACEHOLDER toast. ISSUE-2.
    5. **"Print Dashboard"** outline button (emerald) — calls `window.print()`. NO placeholder.
    6. **Refresh icon** — existing chrome — kept right-end.

- **No dropdown switcher**, **no Edit Layout chrome** (read-only by default).

### Grid Layout (react-grid-layout — `lg` breakpoint, 12 columns)

> **Visual hierarchy via varied cell sizing** — Hero KPIs occupy taller cells (h=3) than supporting KPIs (h=2) so the grid itself signals importance before the renderer chrome does. Hero and Ratio span Row 0 (h=3); supporting KPIs span Row 3 (h=2).

| i (instanceId) | Widget | Renderer | x | y | w | h | minW | minH | Hierarchy |
|----------------|--------|----------|---|---|---|---|------|------|-----------|
| KPI_TOTAL_COLLECTIONS | Total Collections | AmbassadorHeroKpiWidget | 0 | 0 | 4 | 3 | 3 | 3 | **Hero** — taller, 1/3-width |
| KPI_COLLECTION_COUNT | Collection Count | AmbassadorDeltaKpiWidget | 4 | 0 | 4 | 3 | 3 | 2 | Supporting — top row alongside heroes |
| KPI_ACTIVE_AMBASSADORS | Active Ambassadors | AmbassadorRatioKpiWidget | 8 | 0 | 4 | 3 | 3 | 2 | Distinct — ratio variant top row |
| KPI_AVG_PER_AMBASSADOR | Avg per Ambassador | AmbassadorDeltaKpiWidget | 0 | 3 | 4 | 2 | 3 | 2 | Supporting — quad strip row 2 |
| KPI_UNIQUE_DONORS | Unique Donors Visited | AmbassadorHeroKpiWidget | 4 | 3 | 4 | 2 | 3 | 2 | **Hero** — 2nd hero instance, supporting size |
| KPI_RECEIPT_COMPLIANCE | Receipt Compliance | AmbassadorComplianceKpiWidget | 8 | 3 | 4 | 2 | 3 | 2 | Distinct — compliance/alert variant |
| CHART_COLLECTION_TREND | Collection Trend | AmbassadorCollectionTrendWidget | 0 | 5 | 7 | 5 | 5 | 4 | 7-col combo chart |
| CHART_BY_BRANCH | Collections by Branch | AmbassadorBranchBarsWidget | 7 | 5 | 5 | 5 | 4 | 4 | 5-col horizontal bars |
| TBL_LEADERBOARD | Ambassador Leaderboard | AmbassadorLeaderboardWidget | 0 | 10 | 12 | 7 | 8 | 5 | Full-width table |
| CHART_PAYMENT_MODE | Payment Mode Donut | AmbassadorPaymentModeDonutWidget | 0 | 17 | 5 | 5 | 4 | 4 | 5-col donut |
| CHART_BY_DAY_OF_WEEK | Day of Week Bars | AmbassadorDayOfWeekBarsWidget | 5 | 17 | 7 | 5 | 5 | 4 | 7-col vertical bars |
| MAP_TERRITORY_COVERAGE | Territory Map | AmbassadorTerritoryMapWidget | 0 | 22 | 5 | 5 | 4 | 4 | 5-col map placeholder |
| TBL_TERRITORY_SUMMARY | Territory Summary | AmbassadorTerritorySummaryWidget | 5 | 22 | 7 | 5 | 5 | 4 | 7-col table |
| LIST_ALERTS | Alerts & Action Items | AmbassadorAlertsListWidget | 0 | 27 | 12 | 4 | 8 | 3 | Full-width alerts |

> **Total grid height ≈ 31 row-units**. The 6 KPI cells deliberately differ in size: 3 row-1 cells at 4×3 (Hero / Delta / Ratio) vs. 3 row-2 cells at 4×2 (Delta / Hero-supporting / Compliance). This produces a visible "headline strip" + "compact-strip" structure.

**md (8 cols) / sm (6 cols) / xs (1 col) breakpoints** (the component reads all four):
- **md (8 cols)**: KPIs collapse to 2 per row with h preserved; charts stack full-width; leaderboard scrolls horizontally
- **sm (6 cols)**: KPIs 1-per-row at h=2; donut + bars stack; map + summary stack
- **xs (1 col)**: every widget full-width vertically

### Widget Catalog (instance details)

> All ComponentPaths are NEW `Ambassador*Widget` renderers under `ambassador-dashboard-widgets/` — see § ② for the registry table. Visual treatment notes captured per row.

| # | InstanceId | Title | ComponentPath | Visual Distinguisher | Filters Honored | Drill-Down |
|---|-----------|-------|---------------|----------------------|-----------------|------------|
| 1 | KPI_TOTAL_COLLECTIONS | Total Collections | **AmbassadorHeroKpiWidget** | LARGE card, emerald gradient header strip, 6-mo sparkline, bold value `$67,800`, hand-holding-dollar icon | period, branch, currency | `/crm/fieldcollection/collectionlist?dateFrom=&dateTo=&branchId=` |
| 2 | KPI_COLLECTION_COUNT | Collection Count | **AmbassadorDeltaKpiWidget** | Mid-size, dual-value (count + delta%), teal accent, receipt icon | period, branch | `/crm/fieldcollection/collectionlist?dateFrom=&dateTo=&branchId=` |
| 3 | KPI_ACTIVE_AMBASSADORS | Active Ambassadors | **AmbassadorRatioKpiWidget** | Distinct ratio chrome `34 / 38` with denominator muted, blue accent, danger sub-badge "4 inactive", users icon | branch | `/crm/fieldcollection/ambassadorlist?status=Active&branchId=` |
| 4 | KPI_AVG_PER_AMBASSADOR | Avg per Ambassador | AmbassadorDeltaKpiWidget | Mid-size, dual-value ($ + $ delta), green accent, chart-simple icon | period, branch, currency | `/crm/fieldcollection/ambassadorlist?branchId=` |
| 5 | KPI_UNIQUE_DONORS | Unique Donors Visited | AmbassadorHeroKpiWidget | LARGE card, purple gradient header strip, 6-mo new-donor sparkline, user-group icon, subtitle "67 new donors (17.2%)" | period, branch | `/crm/contact/contact?donatedBetween=&dateFrom=&dateTo=&branchId=` (ISSUE-9 — confirm filter args) |
| 6 | KPI_RECEIPT_COMPLIANCE | Receipt Compliance | **AmbassadorComplianceKpiWidget** | Compact orange-tinted card, primary `98.2%`, danger sub-badge "3 gaps detected", clipboard-check icon | period, branch | `/crm/fieldcollection/collectionlist?gapsOnly=true&dateFrom=&dateTo=&branchId=` (ISSUE-9) |
| 7 | CHART_COLLECTION_TREND | Collection Trend | AmbassadorCollectionTrendWidget | Combo bar+line, 6-month window (e.g., Nov-Apr), bars=amount, line=transaction count, annotation pin "Ramadan" | branch, currency | Bar/series click → `/crm/fieldcollection/collectionlist?dateFrom=monthStart&dateTo=monthEnd&branchId=` |
| 8 | CHART_BY_BRANCH | Collections by Branch | AmbassadorBranchBarsWidget | Top-5 + "Others" horizontal bars with inline value labels | period, currency | Bar click → `/crm/fieldcollection/ambassadorlist?branchId={id}` |
| 9 | TBL_LEADERBOARD | Ambassador Leaderboard | AmbassadorLeaderboardWidget | 10-col table: 🥇🥈🥉 rank badges, ambassador link, branch, collections, amount, donors, avg/visit, trend arrow %, target, achievement bar (over=green/under=amber) + ⭐ for over-achievers | period, branch, currency | Row click → `/crm/fieldcollection/ambassadorlist?mode=read&id={ambassadorId}` |
| 10 | CHART_PAYMENT_MODE | Payment Mode Donut | AmbassadorPaymentModeDonutWidget | Donut with center total `$67.8K` + "Total" label, 4-segment legend with $ + % | period, branch, currency | Slice click → `/crm/fieldcollection/collectionlist?paymentModeCode={code}&dateFrom=&dateTo=&branchId=` |
| 11 | CHART_BY_DAY_OF_WEEK | Day of Week | AmbassadorDayOfWeekBarsWidget | 7 vertical bars Mon-Sun, emerald gradient (180deg → mint), value labels above, day labels below, footer "🕌 Fri: Mosque" / "🏠 Sat: Home visits peak" | period, branch, currency | Bar click → `/crm/fieldcollection/collectionlist?dayOfWeek={1-7}&dateFrom=&dateTo=&branchId=` (ISSUE-9 — may need new arg) |
| 12 | MAP_TERRITORY_COVERAGE | Territory Coverage | AmbassadorTerritoryMapWidget | Placeholder gradient panel + map-pin icon overlay + density legend (4 colored dots: high/moderate/low/none) | period, branch | (none — placeholder; SERVICE_PLACEHOLDER on real-map integration — ISSUE-3) |
| 13 | TBL_TERRITORY_SUMMARY | Territory Summary | AmbassadorTerritorySummaryWidget | Table with territory / ambassador (linked) / contacts / visited (count + %) / coverage badge (low=red-tint / medium=amber-tint / high=green-tint) / collection $ | period, branch, currency | Row click → `/crm/fieldcollection/ambassadorlist?mode=read&id={ambassadorId}` (or territory-specific drill if territory detail exists) |
| 14 | LIST_ALERTS | Alerts & Action Items | AmbassadorAlertsListWidget | Severity-colored alert rows (warning yellow / info blue), distinct icon-circle bg, sanitized `<strong>` only, action button per row, header right-end count pill | period, branch | Per-alert `link.route` + `link.args` |

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Period | Native select + custom range popover | "This Month" | Time-aggregating widgets (KPIs 1/2/4/5/6, charts 7/8/10/11, tables 9/13, alerts) | Presets per § ④ |
| Branch | Single-select — from `app.Branches` | "All Branches" or user's branch (BRANCH_MANAGER) | All widgets (every widget honors branch) | All widgets honor branch |
| Currency | Native select | "USD (Base)" | All currency-bearing widgets (KPIs 1/4, charts 7/8/10/11, tables 9/13) | "Native Currency" surfaces "Mixed currency totals" tooltip via `metadata.mixedCurrencyFlag=true` |

Filter values flow into `<MenuDashboardComponent />` filter context, projected into each widget's `customParameter` JSON via the runtime's `{placeholder}` substitution. Functions read them out of `p_filter_json`.

### Drill-Down / Navigation Map (recap of the per-widget table above)

| From | Click On | Navigates To | Prefill |
|------|----------|--------------|---------|
| KPI Total Collections card | Whole card | `/crm/fieldcollection/collectionlist` | `dateFrom=&dateTo=&branchId=` |
| KPI Collection Count card | Whole card | `/crm/fieldcollection/collectionlist` | `dateFrom=&dateTo=&branchId=` |
| KPI Active Ambassadors card | Whole card | `/crm/fieldcollection/ambassadorlist` | `status=Active&branchId=` |
| KPI Avg per Ambassador card | Whole card | `/crm/fieldcollection/ambassadorlist` | `branchId=` |
| KPI Unique Donors card | Whole card | `/crm/contact/contact` | `donatedBetween=true&dateFrom=&dateTo=&branchId=` (ISSUE-9) |
| KPI Receipt Compliance card | Whole card | `/crm/fieldcollection/collectionlist` | `gapsOnly=true&dateFrom=&dateTo=&branchId=` (ISSUE-9) |
| Trend bar/line | Click on month/series | `/crm/fieldcollection/collectionlist` | `dateFrom=monthStart&dateTo=monthEnd&branchId=` |
| Branch bar | Click on bar | `/crm/fieldcollection/ambassadorlist` | `branchId={id}` |
| Leaderboard row | Whole row (or ambassador name link) | `/crm/fieldcollection/ambassadorlist` | `mode=read&id={ambassadorId}` |
| Payment Mode donut slice | Click on slice | `/crm/fieldcollection/collectionlist` | `paymentModeCode={code}&dateFrom=&dateTo=&branchId=` |
| Day of Week bar | Click on bar | `/crm/fieldcollection/collectionlist` | `dayOfWeek={1-7}&dateFrom=&dateTo=&branchId=` (ISSUE-9 — may require new collectionlist arg) |
| Territory Map | (placeholder — no drill-down in v1) | — | — |
| Territory Summary row | Click on row (or ambassador-name link) | `/crm/fieldcollection/ambassadorlist` | `mode=read&id={ambassadorId}` |
| Alert "Investigate" (gaps) | CTA per row | `/crm/fieldcollection/collectionlist` | `gapsOnly=true` |
| Alert "View List" (low-stock books) | CTA per row | `/crm/fieldcollection/receiptbooks` | `lowStock=true` |
| Alert "Review" (inactive ambassadors) | CTA per row | `/crm/fieldcollection/ambassadorlist` | `inactiveThisMonth=true` (ISSUE-9) |
| Alert "Approve Queue" (pending collections) | CTA per row | `/crm/fieldcollection/collectionlist` | `status=Pending` |
| Toolbar "Export Report" | Button | SERVICE_PLACEHOLDER toast | "Generating field-collection report..." |
| Toolbar "Print Dashboard" | Button | `window.print()` | — |

### User Interaction Flow

1. **Initial load**: User clicks `CRM → Dashboards → Ambassador Dashboard` → URL `/[lang]/crm/dashboards/ambassadordashboard` → page renders `<MenuDashboardComponent moduleCode="CRM" dashboardCode="AMBASSADORDASHBOARD" toolbar={<AmbassadorDashboardToolbar />} />`. Component fires `dashboardByModuleAndCode('CRM','AMBASSADORDASHBOARD')` + `widgetByModuleCode('CRM')` → maps each ConfiguredWidget instance to its NEW `Ambassador*Widget` renderer via `WIDGET_REGISTRY` → renders 14-widget grid → all widgets parallel-fetch via `generateWidgets` with default filters (This Month / All Branches / USD).
2. **Filter change** (Period / Branch / Currency): widgets honoring that filter refetch in parallel; widgets NOT honoring it stay cached.
3. **Drill-down click**: navigates per Drill-Down Map → all destinations are COMPLETED screens (#65 Field Collection, #66 Receipt Book, #67 Ambassador, Contact list).
4. **Back navigation**: returns to dashboard → filters preserved in URL search params where possible.
5. **Export Report** → toast SERVICE_PLACEHOLDER. **Print Dashboard** → `window.print()`.
6. **Refresh icon** — existing chrome — refetches dashboard config + widgets.
7. **No edit-layout / add-widget chrome** in v1.
8. **Empty / loading / error states**: each NEW renderer ships its own SHAPE-MATCHED skeleton. Error → red mini banner + Retry. Empty → muted icon + per-widget empty message.

---

## ⑦ Substitution Guide

**Consumer**: Backend Developer + Frontend Developer

> Sibling of Donation Dashboard #124 — same MENU_DASHBOARD architecture, same `fund` schema for SQL functions, **different FE renderers** (Ambassador Dashboard ships its own `Ambassador*Widget` set per the new policy).

**Canonical Reference**: **Donation Dashboard #124** for BE pattern (`prompts/donation-dashboard.md` § ⑦) — same Path-A function contract, same `<MenuDashboardComponent />` consumer, same seed-step layout, same `fund/` SQL function folder. **Use the existing `fund/fn_donation_dashboard_kpi_total_donations.sql` as the BE reference shape**. **DO NOT** reuse Donation Dashboard's FE renderers — the policy forbids it.

| Convention | Donation Dashboard (#124) | → This Dashboard | Notes |
|-----------|----------------|------------------|-------|
| DashboardCode | `DONATIONDASHBOARD` | `AMBASSADORDASHBOARD` | Matches existing seeded MenuCode |
| MenuName | `Donation Dashboard` | `Ambassador Dashboard` | Already seeded |
| MenuUrl | `crm/dashboards/donationdashboard` | `crm/dashboards/ambassadordashboard` | Already seeded; no change |
| Schema for Postgres functions | `fund.fn_donation_dashboard_*` | `fund.fn_ambassador_dashboard_*` | SAME `fund/` folder under `DatabaseScripts/Functions/` (already exists) |
| Function naming | `fn_donation_dashboard_{aspect}` | `fn_ambassador_dashboard_{aspect}` | snake_case |
| Widget instance ID | `{TYPE}_{NAME}` | Same convention | Stable across LayoutConfig + ConfiguredWidget |
| Module | `CRM` | `CRM` | Same |
| Parent menu | `CRM_DASHBOARDS` | `CRM_DASHBOARDS` | Same |
| Dashboard color | `#059669` (emerald) | `#059669` (emerald) | Same accent — both field-aligned green |
| Dashboard icon | `hand-heart-bold` | `chart-line-bold` | Phosphor name without `ph:` prefix |
| Sidebar Menu icon | (Donation menu) | `solar:map-arrow-right-bold` | Already seeded on Menu row |
| FE renderer folder | `dashboards/widgets/donation-dashboard-widgets/` (Donation-specific renderers FROZEN) | **NEW** `dashboards/widgets/ambassador-dashboard-widgets/` | 12 distinct ComponentPaths, all `Ambassador*Widget` named |
| FE renderer naming | `DonationHeroKpiWidget`, `DonationDeltaKpiWidget`, etc. | `AmbassadorHeroKpiWidget`, `AmbassadorRatioKpiWidget`, etc. | `Ambassador{Purpose}Widget` PascalCase per policy |
| WidgetType seed rows | (15 NEW for Donation) | **12 NEW WidgetType rows** | All ComponentPaths are NEW |
| Per-route page wrapper | `pages/crm/dashboards/donationdashboard.tsx` | `pages/crm/dashboards/ambassadordashboard.tsx` | Both currently render `<DashboardComponent />` (STATIC). Both need overwriting to `<MenuDashboardComponent />`. This prompt fixes Ambassador's wrapper; Donation Dashboard #124 fixes its own. |
| Menu OrderBy | 2 | 4 | Already seeded |

---

## ⑧ File Manifest

**Consumer**: Backend Developer + Frontend Developer

### Backend Files (Path A only — 14 SQL functions, NO C# code)

| # | File | Path |
|---|------|------|
| 1 | KPI 1 — Total Collections | `PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_ambassador_dashboard_kpi_total_collections.sql` |
| 2 | KPI 2 — Collection Count | `…/fund/fn_ambassador_dashboard_kpi_collection_count.sql` |
| 3 | KPI 3 — Active Ambassadors | `…/fund/fn_ambassador_dashboard_kpi_active_ambassadors.sql` |
| 4 | KPI 4 — Avg per Ambassador | `…/fund/fn_ambassador_dashboard_kpi_avg_per_ambassador.sql` |
| 5 | KPI 5 — Unique Donors | `…/fund/fn_ambassador_dashboard_kpi_unique_donors.sql` |
| 6 | KPI 6 — Receipt Compliance | `…/fund/fn_ambassador_dashboard_kpi_receipt_compliance.sql` |
| 7 | Collection Trend (combo) | `…/fund/fn_ambassador_dashboard_collection_trend.sql` |
| 8 | By Branch (horizontal bars) | `…/fund/fn_ambassador_dashboard_by_branch.sql` |
| 9 | Leaderboard (10-col table) | `…/fund/fn_ambassador_dashboard_leaderboard.sql` |
| 10 | Payment Mode (donut) | `…/fund/fn_ambassador_dashboard_payment_mode.sql` |
| 11 | Day of Week (vertical bars) | `…/fund/fn_ambassador_dashboard_day_of_week.sql` |
| 12 | Territory Coverage (placeholder map) | `…/fund/fn_ambassador_dashboard_territory_coverage.sql` |
| 13 | Territory Summary (table) | `…/fund/fn_ambassador_dashboard_territory_summary.sql` |
| 14 | Alerts & Action Items | `…/fund/fn_ambassador_dashboard_alerts.sql` |

**Backend Wiring Updates**: NONE (Path A reuses `generateWidgets` GraphQL handler).

**Database Migration**: 1 file if functions are NOT auto-applied at runtime. Confirm during build by inspecting how the existing `fund/` and `case/` functions get registered. If auto-applied, no migration needed; otherwise generate `AddAmbassadorDashboardFunctions.cs`.

### Frontend Files — 12 NEW renderers under `ambassador-dashboard-widgets/` (4 files each = 48 files + 1 folder barrel + toolbar + page wires)

| # | Renderer | Files (under `dashboards/widgets/ambassador-dashboard-widgets/`) |
|---|----------|---------------------------------------------------------------|
| 1 | AmbassadorHeroKpiWidget *(used 2× — Total Collections + Unique Donors)* | `ambassador-hero-kpi-widget/AmbassadorHeroKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 2 | AmbassadorDeltaKpiWidget *(used 2× — Collection Count + Avg per Ambassador)* | `ambassador-delta-kpi-widget/AmbassadorDeltaKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 3 | AmbassadorRatioKpiWidget *(used 1× — Active Ambassadors)* | `ambassador-ratio-kpi-widget/AmbassadorRatioKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 4 | AmbassadorComplianceKpiWidget *(used 1× — Receipt Compliance)* | `ambassador-compliance-kpi-widget/AmbassadorComplianceKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 5 | AmbassadorCollectionTrendWidget | `ambassador-collection-trend-widget/AmbassadorCollectionTrendWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 6 | AmbassadorBranchBarsWidget | `ambassador-branch-bars-widget/AmbassadorBranchBarsWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 7 | AmbassadorLeaderboardWidget | `ambassador-leaderboard-widget/AmbassadorLeaderboardWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 8 | AmbassadorPaymentModeDonutWidget | `ambassador-payment-mode-donut-widget/AmbassadorPaymentModeDonutWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 9 | AmbassadorDayOfWeekBarsWidget | `ambassador-day-of-week-bars-widget/AmbassadorDayOfWeekBarsWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 10 | AmbassadorTerritoryMapWidget | `ambassador-territory-map-widget/AmbassadorTerritoryMapWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 11 | AmbassadorTerritorySummaryWidget | `ambassador-territory-summary-widget/AmbassadorTerritorySummaryWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 12 | AmbassadorAlertsListWidget | `ambassador-alerts-list-widget/AmbassadorAlertsListWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| — | Folder barrel | `dashboards/widgets/ambassador-dashboard-widgets/index.ts` (re-exports all 12 renderers) |

**Other FE files**:

| # | File | Path | Action |
|---|------|------|--------|
| 13 | Toolbar component | `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/ambassador-dashboard-toolbar.tsx` | NEW — composes 3 filter selects (Period / Branch / Currency) + Export + Print buttons; threads filter changes via callbacks |
| 14 | Page-config wrapper | `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/ambassadordashboard.tsx` | OVERWRITE — replace `<DashboardComponent />` with `<MenuDashboardComponent moduleCode="CRM" dashboardCode="AMBASSADORDASHBOARD" toolbar={<AmbassadorDashboardToolbar />} />` |
| 15 | Per-route page stub | `Pss2.0_Frontend/src/app/[lang]/crm/dashboards/ambassadordashboard/page.tsx` | KEEP — already imports `<AmbassadorDashboardPageConfig />`; verify after wrapper rewrite |
| 16 | `<MenuDashboardComponent />` toolbar prop | `Pss2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx` | VERIFY — should already have optional `toolbar?: ReactNode` prop after Donation Dashboard #124. If missing, add it (render inside the lean header before Refresh icon) |

**Frontend Wiring Updates**:

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | Register all 12 NEW renderers: `'AmbassadorHeroKpiWidget': AmbassadorHeroKpiWidget, 'AmbassadorDeltaKpiWidget': AmbassadorDeltaKpiWidget, 'AmbassadorRatioKpiWidget': AmbassadorRatioKpiWidget, 'AmbassadorComplianceKpiWidget': AmbassadorComplianceKpiWidget, 'AmbassadorCollectionTrendWidget': …, 'AmbassadorBranchBarsWidget': …, 'AmbassadorLeaderboardWidget': …, 'AmbassadorPaymentModeDonutWidget': …, 'AmbassadorDayOfWeekBarsWidget': …, 'AmbassadorTerritoryMapWidget': …, 'AmbassadorTerritorySummaryWidget': …, 'AmbassadorAlertsListWidget': …` — keys must match the `WidgetType.ComponentPath` strings seeded in STEP 3 |
| 2 | `dashboards/widgets/index.ts` (if exists) | Re-export the new folder barrel |
| 3 | Sidebar / menu config | NONE — AMBASSADORDASHBOARD menu already seeded |

### DB Seed (`sql-scripts-dyanmic/AmbassadorDashboard-sqlscripts.sql`)

> Preserve repo's `sql-scripts-dyanmic/` typo. Mirror Case Dashboard #52 / Donation Dashboard #124's 7-step layout for idempotent independent execution.

| # | Item | Notes |
|---|------|-------|
| 1 | STEP 0 — Diagnostics (read-only) | Verify CRM module + BUSINESSADMIN role + AMBASSADORDASHBOARD Menu row exists. Pre-flight: confirm none of the 12 NEW WidgetType rows exist yet (clean slate before STEP 3). |
| 2 | STEP 1 — Insert Dashboard row | DashboardCode=AMBASSADORDASHBOARD, IsSystem=true, ModuleId resolves from CRM, DashboardIcon=`chart-line-bold`, DashboardColor=`#059669`, IsActive=true, CompanyId=NULL |
| 3 | STEP 2 — Link Dashboard.MenuId | Idempotent UPDATE WHERE MenuId IS NULL — same shape as Case Dashboard's STEP 2.5 |
| 4 | STEP 3 — Insert **12 NEW WidgetType rows** | One INSERT per ComponentPath in § ② widget-type table (4 KPI variants + 8 single-use renderers). Idempotent NOT EXISTS guards. |
| 5 | STEP 4 — Insert 14 Widget rows | One INSERT per widget. DefaultParameters JSON honors filter keys (dateFrom/dateTo/branchId/displayCurrency); StoredProcedureName=fund.fn_ambassador_dashboard_*. WidgetTypeId resolves to the matching STEP 3 row. |
| 6 | STEP 5 — Insert 14 WidgetRole grants | BUSINESSADMIN read-all on all 14 widgets |
| 7 | STEP 6 — Insert DashboardLayout row | LayoutConfig (lg/md/sm/xs breakpoints) + ConfiguredWidget JSON × 14 instances. Idempotent NOT EXISTS guard on DashboardId. |

**Re-running seed must be idempotent** (NOT EXISTS guards on every INSERT/UPDATE — match Case/Donation Dashboard precedent).

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

# AMBASSADORDASHBOARD menu ALREADY seeded under CRM_DASHBOARDS @ OrderBy=4.
# This prompt does NOT seed a new Menu row — only Dashboard + DashboardLayout + 14 Widgets + WidgetRoles + 12 NEW WidgetTypes.
MenuName: Ambassador Dashboard       # FYI — already seeded
MenuCode: AMBASSADORDASHBOARD        # FYI — already seeded
ParentMenu: CRM_DASHBOARDS           # FYI — already seeded
Module: CRM
MenuUrl: crm/dashboards/ambassadordashboard   # FYI — already seeded
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT
  # Other role grants (CRM_MANAGER, FUNDRAISING_DIRECTOR, BRANCH_MANAGER, FIELD_OPS_USER, DONOR_CARE) — left to admin-config; not seeded here

GridFormSchema: SKIP    # Dashboards have no RJSF form
GridCode: AMBASSADORDASHBOARD

# Dashboard-specific seed inputs
DashboardCode: AMBASSADORDASHBOARD
DashboardName: Ambassador Dashboard
DashboardIcon: chart-line-bold
DashboardColor: #059669
IsSystem: true
DashboardKind: MENU_DASHBOARD   # encoded by Dashboard.MenuId IS NOT NULL after STEP 2
MenuOrderBy: 4                  # written to auth.Menus.OrderBy (already seeded — NOT to Dashboard)
NewWidgetTypes:                 # 12 NEW WidgetType rows seeded in STEP 3 (4 KPI variants + 8 single-use)
  - AMBASSADOR_HERO_KPI: AmbassadorHeroKpiWidget                    # used 2× — Total Collections + Unique Donors (hero)
  - AMBASSADOR_DELTA_KPI: AmbassadorDeltaKpiWidget                  # used 2× — Collection Count + Avg per Ambassador (delta)
  - AMBASSADOR_RATIO_KPI: AmbassadorRatioKpiWidget                  # used 1× — Active Ambassadors (X/Y ratio)
  - AMBASSADOR_COMPLIANCE_KPI: AmbassadorComplianceKpiWidget        # used 1× — Receipt Compliance (orange-tinted alert)
  - AMBASSADOR_COLLECTION_TREND: AmbassadorCollectionTrendWidget    # combo bar+line
  - AMBASSADOR_BRANCH_BARS: AmbassadorBranchBarsWidget              # horizontal bars
  - AMBASSADOR_LEADERBOARD: AmbassadorLeaderboardWidget             # rank table with achievement bar
  - AMBASSADOR_PAYMENT_MODE_DONUT: AmbassadorPaymentModeDonutWidget # donut
  - AMBASSADOR_DAY_OF_WEEK_BARS: AmbassadorDayOfWeekBarsWidget      # vertical bars Mon-Sun
  - AMBASSADOR_TERRITORY_MAP: AmbassadorTerritoryMapWidget          # placeholder map
  - AMBASSADOR_TERRITORY_SUMMARY: AmbassadorTerritorySummaryWidget  # territory table with coverage badges
  - AMBASSADOR_ALERTS_LIST: AmbassadorAlertsListWidget              # severity-colored alert rows
WidgetGrants:                   # all 14 widgets — BUSINESSADMIN read-all
  - KPI_TOTAL_COLLECTIONS: BUSINESSADMIN
  - KPI_COLLECTION_COUNT: BUSINESSADMIN
  - KPI_ACTIVE_AMBASSADORS: BUSINESSADMIN
  - KPI_AVG_PER_AMBASSADOR: BUSINESSADMIN
  - KPI_UNIQUE_DONORS: BUSINESSADMIN
  - KPI_RECEIPT_COMPLIANCE: BUSINESSADMIN
  - CHART_COLLECTION_TREND: BUSINESSADMIN
  - CHART_BY_BRANCH: BUSINESSADMIN
  - TBL_LEADERBOARD: BUSINESSADMIN
  - CHART_PAYMENT_MODE: BUSINESSADMIN
  - CHART_BY_DAY_OF_WEEK: BUSINESSADMIN
  - MAP_TERRITORY_COVERAGE: BUSINESSADMIN
  - TBL_TERRITORY_SUMMARY: BUSINESSADMIN
  - LIST_ALERTS: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Consumer**: Frontend Developer

**Queries** — all widgets use the existing **`generateWidgets`** GraphQL handler (NOT new endpoints):

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| generateWidgets (existing) | `(data jsonb, metadata jsonb, total_count int, filtered_count int)` (text-typed `data_json` deserialized to jsonb on the client) | widgetId, p_filter_json, p_page, p_page_size, p_user_id, p_company_id | All 14 widgets |
| dashboardByModuleAndCode (existing — verified at [GetDashboardByModuleAndCode.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleAndCode.cs)) | DashboardDto with DashboardLayouts + Module includes | moduleCode='CRM', dashboardCode='AMBASSADORDASHBOARD' | Single-row fetch — `<MenuDashboardComponent />` consumer |
| widgetByModuleCode (existing) | `[WidgetDto]` | moduleCode='CRM' | Module-wide widget catalog — resolves instance code → widgetId → WidgetDto |
| branches (existing) | `[BranchDto]` | dropdown args | Filter dropdown source for "Branch" |
| currencies (existing) | `[CurrencyDto]` | — | Filter dropdown source for "Currency" |

**Per-widget `data_json` shapes** — each NEW renderer's `.types.ts` file declares this exactly. The 4 KPI renderers expose DIFFERENT shapes because they emphasize different data:

| Renderer | `data_json` shape |
|----------|------|
| AmbassadorHeroKpiWidget *(used 2× — Total Collections + Unique Donors)* | `{ value: number, formatted: string, deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', subtitle: string, sparkline: { labels: string[6], data: number[6] }, accent: 'emerald' \| 'purple' }` |
| AmbassadorDeltaKpiWidget *(used 2× — Collection Count + Avg per Ambassador)* | `{ value: number, formatted: string, secondaryLabel: string, secondaryFormatted: string, deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', accent: 'teal' \| 'green' }` (e.g., for Count: secondaryLabel="transactions", secondaryFormatted="↑ 12.3%"; for Avg: secondaryLabel="vs last month", secondaryFormatted="$231") |
| AmbassadorRatioKpiWidget *(used 1× — Active Ambassadors)* | `{ activeCount: number, totalCount: number, ratioFormatted: string ("34 / 38"), inactiveCount: number, inactiveLabel: string ("4 inactive"), severity: 'warning' \| 'danger' \| 'neutral', accent: 'blue' }` |
| AmbassadorComplianceKpiWidget *(used 1× — Receipt Compliance)* | `{ value: number, formatted: string ("98.2%"), gapCount: number, gapLabel: string ("3 gaps detected"), severity: 'warning' \| 'danger' \| 'neutral' }` |
| AmbassadorCollectionTrendWidget | `{ type: 'combo', labels: string[6], bars: { name: 'Amount', data: number[6], formattedData: string[6] }, line: { name: 'Transactions', data: number[6] }, annotations?: [{ xValue: string, label: string }] }` |
| AmbassadorBranchBarsWidget | `{ rows: [{ branchId: number, branchName: string, value: number, valueFormatted: string, widthPct: number, color: string }] }` (top 5 + "Others") |
| AmbassadorLeaderboardWidget | `{ rows: [{ rank: number, ambassadorId: number, contactId: number, ambassadorName: string, branchName: string, collections: number, amount: number, amountFormatted: string, donors: number, avgPerVisit: number, avgPerVisitFormatted: string, trendPct: number, trendDirection: 'up'\|'down'\|'flat', target: number, targetFormatted: string, achievementPct: number, achievementColor: 'over'\|'under', isStarred: boolean }] }` |
| AmbassadorPaymentModeDonutWidget | `{ total: number, totalFormatted: string, giftCount: number, segments: [{ label: string, paymentModeCode: string, value: number, valueFormatted: string, pct: number, color: string }] }` |
| AmbassadorDayOfWeekBarsWidget | `{ bars: [{ day: 'Mon'\|'Tue'\|'Wed'\|'Thu'\|'Fri'\|'Sat'\|'Sun', value: number, valueFormatted: string, heightPct: number }], peakDay: string, footer: { left: string, right: string } }` |
| AmbassadorTerritoryMapWidget | `{ type: 'placeholder-map', territories: [{ territoryName: string, lat?: number, lng?: number, density: 'high'\|'moderate'\|'low'\|'none', collectionAmount: number }], legend: [{ label: string, color: string, borderColor?: string }] }` |
| AmbassadorTerritorySummaryWidget | `{ rows: [{ territoryId: number, territoryName: string, ambassadorId: number, ambassadorName: string, contactsTotal: number, visitedCount: number, visitedPct: number, coverage: 'low'\|'medium'\|'high', collectionAmount: number, collectionAmountFormatted: string }] }` |
| AmbassadorAlertsListWidget | `{ alerts: [{ severity: 'warning'\|'info'\|'danger'\|'success', iconCode: string, message: string (sanitized HTML, `<strong>` only), link: { label: string, route: string, args: object } }], totalCount: number }` |

**No composite DTO**. No new C# types. Each NEW renderer consumes its own jsonb shape directly through the `generateWidgets` runtime. The 4 KPI shapes deliberately diverge so the renderers cannot be accidentally collapsed into one.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] All 14 SQL functions exist in `fund.` schema
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/ambassadordashboard`
- [ ] Network tab shows EXACTLY ONE `dashboardByModuleAndCode` call (no `dashboardByModuleCode` leakage)
- [ ] Dashboard renders with 14 widgets in the documented layout

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Dashboard loads with default filters (This Month / All Branches / USD) and renders all 14 widgets
- [ ] **Renderer policy compliance** (legacy reuse check): `git grep -E "(StatusWidgetType1\|StatusWidgetType2\|MultiChartWidget\|PieChartWidgetType1\|BarChartWidgetType1\|FilterTableWidget\|NormalTableWidget\|TableWidgetType1\|RadialBarWidget\|HtmlWidgetType1\|HtmlWidgetType2\|GeographicHeatmapWidgetType1\|case-dashboard-alerts-widget\|Donation\(.*\)Widget\|Contact\(.*\)Widget)" ambassador-dashboard-widgets/` returns ZERO matches. The 12 seeded WidgetType rows reference only `Ambassador*Widget` ComponentPaths.
- [ ] **Visual-uniqueness compliance** (per the new directive — no clone tile grids):
      • The 4 KPI variants render visibly different chrome — `AmbassadorHeroKpiWidget` (gradient strip + sparkline) ≠ `AmbassadorDeltaKpiWidget` (dual-value layout, no sparkline) ≠ `AmbassadorRatioKpiWidget` (X/Y ratio with muted denominator + inactive sub-badge) ≠ `AmbassadorComplianceKpiWidget` (orange-tinted bg + danger gap-count sub-badge)
      • The 2 hero instances differ by accent — Total Collections (emerald) vs Unique Donors (purple) — gradient strip color is data-driven via `accent` prop
      • The 2 delta instances differ by accent — Collection Count (teal) vs Avg per Ambassador (green)
      • Chart types match data shape — combo bar+line for trends (CHART_COLLECTION_TREND), donut for parts-of-whole (CHART_PAYMENT_MODE), horizontal bars for branch comparison (CHART_BY_BRANCH), vertical bars for day-of-week distribution (CHART_BY_DAY_OF_WEEK). No "one chart component switching `chartType`."
      • Each widget skeleton matches its renderer's actual layout — KPI tile skeleton differs from donut skeleton differs from leaderboard 10-row skeleton differs from territory-summary skeleton differs from alert-row skeleton differs from combo-chart skeleton differs from day-bars 7-bar skeleton. NO single shimmer rectangle on any widget.
      • Side-by-side screenshot of all 14 widgets shows visible visual variety — no two widgets feel "samey"
- [ ] Each KPI card shows correct value formatted per spec via its dedicated renderer (Hero / Delta / Ratio / Compliance)
- [ ] Each chart renders correctly via its NEW renderer (combo axes/legend/tooltip; donut center label; horizontal bar inline labels; day-of-week bar heightPct + footer callouts)
- [ ] Leaderboard rank badges (🥇🥈🥉 for top 3, gray circle for 4-10), achievement bar (over=green/under=amber), trend arrows (↑/↓/→) — all render correctly via NEW renderer
- [ ] Territory Summary coverage badges render with correct color tint (low=red / medium=amber / high=green)
- [ ] Period filter change refetches all date-honoring widgets in parallel
- [ ] Branch filter change refetches all widgets (every widget honors branch)
- [ ] Currency filter change reformats all currency-bearing widgets
- [ ] Custom Range opens date popover and applies on confirm
- [ ] Drill-down clicks navigate per Drill-Down Map (all destinations are COMPLETED screens — #65/#66/#67/Contact)
- [ ] "Export Report" toasts SERVICE_PLACEHOLDER (no crash)
- [ ] "Print Dashboard" opens browser print dialog
- [ ] Empty / error states render per widget
- [ ] Role-based widget gating works
- [ ] Alerts list (widget 14) generates plausible items per § ④ rules; sanitized HTML only allows `<strong>`
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl) — Hero KPIs collapse to full-width stacked on xs/sm; supporting KPIs to 2-per-row on sm; etc.
- [ ] Sidebar leaf "Ambassador Dashboard" visible to BUSINESSADMIN
- [ ] Bookmarked URL survives reload
- [ ] Role-gating via `RoleCapability(MenuId=AMBASSADORDASHBOARD)` hides leaf for unauthorized roles

**DB Seed Verification:**
- [ ] Dashboard row inserted with DashboardCode=AMBASSADORDASHBOARD, ModuleId=CRM, IsSystem=true, MenuId NOT NULL after STEP 2
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (all 4 breakpoints) and ConfiguredWidget JSON
- [ ] All 14 Widget rows + WidgetRole grants (BUSINESSADMIN) inserted
- [ ] **All 12 NEW WidgetType rows inserted** with the exact ComponentPath strings listed in § ② (AmbassadorHeroKpiWidget, AmbassadorDeltaKpiWidget, AmbassadorRatioKpiWidget, AmbassadorComplianceKpiWidget, AmbassadorCollectionTrendWidget, AmbassadorBranchBarsWidget, AmbassadorLeaderboardWidget, AmbassadorPaymentModeDonutWidget, AmbassadorDayOfWeekBarsWidget, AmbassadorTerritoryMapWidget, AmbassadorTerritorySummaryWidget, AmbassadorAlertsListWidget)
- [ ] All 14 Postgres functions queryable: `SELECT * FROM fund."fn_ambassador_dashboard_kpi_total_collections"('{}'::jsonb, 1, 50, 1, 1);` returns 1 row × 4 columns
- [ ] Re-running seed is idempotent

---

## ⑫ Special Notes & Warnings

**Consumer**: All agents

### Known Issues (pre-flagged)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | HIGH | Architecture | The existing per-route stub at `[lang]/crm/dashboards/ambassadordashboard/page.tsx` imports `<AmbassadorDashboardPageConfig />` from `presentation/pages/crm/dashboards/ambassadordashboard.tsx`, which currently renders `<DashboardComponent />` (STATIC pattern — joins UserDashboard, returns zero rows for MENU_DASHBOARD). The WRAPPER MUST be overwritten to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="AMBASSADORDASHBOARD" toolbar={<AmbassadorDashboardToolbar />} />`. Localized fix — project-wide unified `[slug]/page.tsx` dynamic route is a separate task. | OPEN |
| ISSUE-2 | MED | Service dep | "Export Report" PDF — full UI in place; handler toasts because PDF rendering / branch-report service not wired. SERVICE_PLACEHOLDER. | OPEN |
| ISSUE-3 | MED | Service dep | Territory Coverage Map (widget 12) — mockup shows a stylized placeholder with density legend, NOT a real map. v1 ships the placeholder rendered by `AmbassadorTerritoryMapWidget` consuming the territory list + density classification from the function. SERVICE_PLACEHOLDER on real-map integration (Leaflet / Mapbox / Google Maps). The function still emits real territory + density data so when the map service is wired later, the data shape is unchanged. | OPEN |
| ISSUE-4 | MED | Receipt gap detection logic | KPI 6 (Receipt Compliance) requires gap detection within `ReceiptBook.ReceiptStartNo..ReceiptEndNo` ranges. The function must compute "expected receipts in range that have a collection" vs. "actually-used receipt numbers" — gaps = sequential numbers in a book's range that were issued (used count > 0) but skipped. Confirm during build whether `AmbassadorCollection.ReceiptNumber` is a string or numeric — gap detection differs (numeric ranges support `generate_series`; strings need parsing prefixes). Mockup shows gaps like "RB-045 (#4543), RB-067 (#6756, #6757)" → ReceiptNumber is likely a numeric within a book identified by `BookNo`. | OPEN |
| ISSUE-5 | MED | Renderer policy + visual-uniqueness | Two non-negotiable checks: (a) **No legacy reuse** — all 12 ComponentPaths must be NEW under `ambassador-dashboard-widgets/`. (b) **No clone tile grids** — the 6 KPIs MUST split across 4 distinct renderers (Hero / Delta / Ratio / Compliance). DO NOT collapse them back to `AmbassadorKpiCardWidget` "to save time" — that produces the exact "uniform-clone widget grids" anti-pattern called out in [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md). Each split renderer's `.skeleton.tsx` must visibly differ. | OPEN |
| ISSUE-6 | MED | Ambassador target source | Leaderboard achievement (table 9) needs a per-ambassador `target` value. Confirm during build whether `Ambassador` entity has a `MonthlyTarget` column or whether targets live on `Branch.DefaultTarget` or as a MasterDataValue. If no real column exists, fall back to median of branch peers' actual amounts and document the choice. The mockup shows discrete targets like "$4,000", "$3,500", "$3,000", "$2,500" — likely per-ambassador. | OPEN |
| ISSUE-7 | LOW | Title naming | Mockup title says "Field Collection Dashboard" but the seeded MenuName + DashboardName is "Ambassador Dashboard". Decision: keep "Ambassador Dashboard" as both menu name and page title (matches sidebar leaf, MODULE_MENU_REFERENCE.md, and the dashboard's primary subject — ambassador performance). The mockup's broader title is a stylistic choice from the designer; the page is fundamentally an ambassador dashboard. Subtitle "Ambassador performance and collection analytics" matches mockup verbatim. | OPEN (decision documented) |
| ISSUE-8 | LOW | Currency filter scope | Mockup shows only Period + Branch filters in the header. Per § ④ multi-currency rules, the dashboard must handle multi-currency aggregation since `AmbassadorCollection.CurrencyId` is per-row. Decision: ship a 3rd "Currency" select alongside the mockup's two — matches Donation Dashboard #124 pattern. If user feedback rejects this, drop the Currency select and force-default to USD; functions still need CompanyId-default currency conversion. | OPEN |
| ISSUE-9 | MED | Drill-down filter args | Some drill-down args may not be supported by destination screens yet — confirm during build:
  • `/crm/fieldcollection/collectionlist?gapsOnly=true` (Receipt Compliance card → gap filter)
  • `/crm/fieldcollection/collectionlist?dayOfWeek={N}` (Day-of-week bar drill)
  • `/crm/fieldcollection/ambassadorlist?inactiveThisMonth=true` (Alert: inactive ambassadors)
  • `/crm/fieldcollection/receiptbooks?lowStock=true` (Alert: low-stock books)
  • `/crm/contact/contact?donatedBetween=true` (Unique Donors KPI)
  If any are unsupported in the COMPLETED list-screen query handlers (#65/#66/#67/Contact), fall back to the unfiltered list URL and add the missing arg as a small follow-up enhancement. Document in this issue's resolution. | OPEN |
| ISSUE-10 | MED | Renderer reuse boundary | Within-dashboard reuse is the EXCEPTION (per the visual-uniqueness directive), not the default. The two allowed reuses on Ambassador Dashboard: `AmbassadorHeroKpiWidget` ×2 (Total Collections + Unique Donors — same gradient-strip + sparkline chrome, accent color is data-driven via `accent` prop) and `AmbassadorDeltaKpiWidget` ×2 (Collection Count + Avg per Ambassador — same dual-value chrome, accent color is data-driven). All other 10 renderers are 1:1. Across-dashboard reuse is FORBIDDEN: do NOT import `DonationAlertsListWidget` for `LIST_ALERTS` even though the data shape is similar — Ambassador's `AmbassadorAlertsListWidget` is a fresh build. | OPEN |
| ISSUE-11 | MED | Multi-currency aggregation | "Native Currency" filter mode aggregates row-currency-by-row-currency without conversion. KPI cards display only the largest-volume currency's number, with a "Mixed totals" tooltip. Charts (Collection Trend, Branch Bars, Payment Mode, Day of Week) are MOST impacted — by-X amounts will mix currencies in the sums. Decide during build: (a) drop chart-level totals when displayCurrency=NATIVE, OR (b) show per-currency-stacked sub-series. Option (a) is simpler. | OPEN |
| ISSUE-12 | MED | Performance | Per-widget Postgres functions over `AmbassadorCollection` may hit performance ceilings on tenants with > 500K collection rows (and joins to Contact for unique-donor count, Ambassador for leaderboard). Pre-flight: `SELECT COUNT(*) FROM fund."AmbassadorCollections"` in target tenants. If > 200k rows, profile each function under load before declaring shippable. Materialized views deferred to v1.1 if needed. | OPEN |
| ISSUE-13 | LOW | Ambassador status semantics | KPI 3 (Active Ambassadors) and Active-Ambassadors alert depend on `Ambassador.Status` column values. The CompensationType field exists on Ambassador.cs:19, but the Status field's exact string values (`Active` / `Inactive` / `Suspended` etc.) need confirmation during build — likely matches MasterData lookup but Ambassador.Status appears stored as a `string` column. Confirm: `SELECT DISTINCT "Status" FROM fund."Ambassadors";` to enumerate allowed values. | OPEN |
| ISSUE-14 | MED | Skeleton fidelity (per-renderer) | Each of the 12 NEW renderers ships its own `.skeleton.tsx` matching its actual layout. Specifically: `AmbassadorHeroKpiWidget` skeleton = title + large value bar + sparkline strip + delta-pill; `AmbassadorDeltaKpiWidget` = title + dual-value side-by-side + delta-pill (no sparkline); `AmbassadorRatioKpiWidget` = title + ratio "X / Y" stub + danger sub-badge pill; `AmbassadorComplianceKpiWidget` = title + % value + orange gap-badge pill; `AmbassadorCollectionTrendWidget` = horizontal axis labels + 6 bars stub + line overlay stub; `AmbassadorBranchBarsWidget` = 5-6 bar-rows with label-and-track shape; `AmbassadorLeaderboardWidget` = 10 rows of (rank circle + ambassador stripe + 8 cells); `AmbassadorPaymentModeDonutWidget` = donut ring + 4-row legend stubs; `AmbassadorDayOfWeekBarsWidget` = 7 vertical-bar stubs + day labels; `AmbassadorTerritoryMapWidget` = gradient panel + map-pin icon + 4-dot legend stub; `AmbassadorTerritorySummaryWidget` = 6 rows of (territory + ambassador + 3 cells + coverage pill stub); `AmbassadorAlertsListWidget` = 4 alert-row stubs (icon-circle + text + button). **Generic shimmer rectangles are FORBIDDEN** — verify visually during loading state. | OPEN |
| ISSUE-15 | LOW | Day-of-week function | `EXTRACT(DOW FROM CollectedDate)` in Postgres returns 0=Sun..6=Sat. The renderer expects Mon-Sun order (Mon first per mockup). The function must remap (e.g., `(EXTRACT(DOW FROM CollectedDate) + 6) % 7` to make Mon=0..Sun=6) before grouping. Confirm tenant timezone — if `CollectedDate` is stored UTC and target tenants span timezones, day-of-week shifts at UTC boundary. Use tenant's CompanyTimezone for DOW extraction if available; otherwise document UTC assumption. | OPEN |

### Build everything in the mockup (GOLDEN RULE reminder)
Every UI element shown in the HTML mockup is in scope. The 6 KPIs / 4 charts / 2 tables / 1 placeholder map / 1 alert list / 2 filter selects / 2 action buttons are ALL in scope. The only SERVICE_PLACEHOLDERs are "Export Report" PDF generation (ISSUE-2) and Territory Map real-geographic-rendering (ISSUE-3). Everything else is fully buildable end-to-end. The developer is free to revise the widget set per the Developer-Decided-Widgets directive — but additions/drops/reshapes must be documented as new ISSUE-N entries above.

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

### Session 1 — 2026-04-30 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Path-A throughout (NO C# code). MENU_DASHBOARD variant — leverages already-shipped `<MenuDashboardComponent />` + `toolbar` prop.
- **Files touched**:
  - **BE (15 files — all created)**:
    - `PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_ambassador_dashboard_kpi_total_collections.sql` (created)
    - `…/fund/fn_ambassador_dashboard_kpi_collection_count.sql` (created)
    - `…/fund/fn_ambassador_dashboard_kpi_active_ambassadors.sql` (created)
    - `…/fund/fn_ambassador_dashboard_kpi_avg_per_ambassador.sql` (created)
    - `…/fund/fn_ambassador_dashboard_kpi_unique_donors.sql` (created)
    - `…/fund/fn_ambassador_dashboard_kpi_receipt_compliance.sql` (created)
    - `…/fund/fn_ambassador_dashboard_collection_trend.sql` (created)
    - `…/fund/fn_ambassador_dashboard_by_branch.sql` (created)
    - `…/fund/fn_ambassador_dashboard_leaderboard.sql` (created)
    - `…/fund/fn_ambassador_dashboard_payment_mode.sql` (created)
    - `…/fund/fn_ambassador_dashboard_day_of_week.sql` (created)
    - `…/fund/fn_ambassador_dashboard_territory_coverage.sql` (created)
    - `…/fund/fn_ambassador_dashboard_territory_summary.sql` (created)
    - `…/fund/fn_ambassador_dashboard_alerts.sql` (created)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/AmbassadorDashboard-sqlscripts.sql` (created — 7 steps mirroring CaseDashboard-sqlscripts.sql)
  - **FE (53 files — 49 created, 2 modified)**:
    - 12 renderer folders × 4 files = 48 files (created) under `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/ambassador-dashboard-widgets/`:
      - `ambassador-hero-kpi-widget/` (Hero — used 2× emerald + purple, 6-mo CSS sparkline, drill on click)
      - `ambassador-delta-kpi-widget/` (Delta — used 2× teal + green, left rail, dual-value, no sparkline)
      - `ambassador-ratio-kpi-widget/` (Ratio — Active Ambassadors X/Y blue chrome with muted denominator)
      - `ambassador-compliance-kpi-widget/` (Compliance — Receipt Compliance orange-tinted card with gap pill)
      - `ambassador-collection-trend-widget/` (Apex combo column+line, dual y-axis, annotations)
      - `ambassador-branch-bars-widget/` (CSS horizontal bars with gradient fill)
      - `ambassador-leaderboard-widget/` (10-col sortable table with 🥇🥈🥉 + ⭐ + achievement bar)
      - `ambassador-payment-mode-donut-widget/` (Apex donut + 4-row legend)
      - `ambassador-day-of-week-bars-widget/` (CSS 7-bar Mon-Sun + footer callouts)
      - `ambassador-territory-map-widget/` (placeholder gradient panel — ISSUE-3)
      - `ambassador-territory-summary-widget/` (table with coverage pills)
      - `ambassador-alerts-list-widget/` (severity-colored rows with `<strong>`-only sanitizer)
    - `…/ambassador-dashboard-widgets/index.ts` (created — folder barrel)
    - `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/ambassador-dashboard-toolbar.tsx` (created — Period + Branch + Currency selects + Export/Print buttons; threads filter context)
    - `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/ambassadordashboard.tsx` (modified — overwritten from STATIC `<DashboardComponent />` to MENU_DASHBOARD `<MenuDashboardComponent />` + `WidgetFilterContextProvider` per ISSUE-1)
    - `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/dashboard-widget-registry.tsx` (modified — added 12 named imports + 12 `WIDGET_REGISTRY` keys, all matching seed STEP 3 ComponentPath strings exactly)
  - **DB**: `sql-scripts-dyanmic/AmbassadorDashboard-sqlscripts.sql` (created — 7-step idempotent seed)
- **Deviations from spec**:
  - **ISSUE-6 resolution**: `Ambassador.MonthlyTarget` column does NOT exist on the entity. Leaderboard SQL function falls back to `Branch.AnnualTarget / COUNT(active ambassadors in branch)` for per-ambassador monthly target; if `Branch.AnnualTarget` is also NULL, uses `PERCENTILE_CONT(0.5)` median of period amounts. Documented inline as `-- ISSUE-6` SQL comment + emitted in `metadata_json.issue6Note`.
  - **Currency conversion column**: `AmbassadorCollection` has NO per-row `ExchangeRate`. All currency-bearing functions use the current `com."Currencies"."CurrencyRate"` (rate-at-query-time, not rate-at-collection-time). Documented inline.
  - **Currency table column**: `com."Currencies"` exposes the rate as `CurrencyRate`, not `ExchangeRate`. All functions use `"CurrencyRate"`.
  - **Ambassador display name**: Ambassador joins to `app."Staffs"` via `StaffId` (not to `Contacts`). Leaderboard renders `Staff.StaffName` for the ambassador name column.
- **Known issues opened**:
  - ISSUE-16 (NEW — MED): No per-row `ExchangeRate` on `AmbassadorCollection`. Currency conversion uses query-time `Currencies.CurrencyRate` rather than rate-at-collection. Acceptable for v1 board-level reporting; for audit-grade analytics, add a per-row `ExchangeRate` column + backfill from historical Currency snapshots in v1.1.
  - ISSUE-17 (NEW — LOW): No `MonthlyTarget` column on `Ambassador`. Leaderboard achievement % uses Branch.AnnualTarget / branch-active-count fallback. Add a real `MonthlyTarget` column to enable per-ambassador goal management in v1.1.
  - ISSUE-9 drill-down args (`gapsOnly`, `dayOfWeek`, `inactiveThisMonth`, `donatedBetween`, `lowStock`) are passed through best-effort. Destination list screens may ignore unknown query params — follow-up enhancement to wire each on the destination side.
- **Known issues closed**:
  - ISSUE-1 (HIGH) — Wrapper overwrite complete; `ambassadordashboard.tsx` now mounts `<MenuDashboardComponent />` instead of `<DashboardComponent />`.
  - ISSUE-5 (HIGH) — Renderer policy compliance verified: zero legacy renderer references in `ambassador-dashboard-widgets/`, all 12 ComponentPaths NEW, 4 distinct KPI variants (Hero / Delta / Ratio / Compliance) — no clone tile grid.
- **Next step**: (empty — COMPLETED)
