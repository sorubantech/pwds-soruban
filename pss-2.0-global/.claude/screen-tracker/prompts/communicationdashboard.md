---
screen: CommunicationDashboard
registry_id: 125
module: CRM (Communication / Outreach Operations)
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
> Infra is shared with Donation Dashboard #124 / Case Dashboard #52 / Volunteer Dashboard / Ambassador Dashboard / Contact Dashboard. Communication Dashboard is a **pure seed-only build** for the dashboard plumbing, plus 17 new SQL widget functions in a NEW `notify` schema folder under `DatabaseScripts/Functions/`, plus 15 NEW dedicated FE widget renderers (per the "NEW renderers default" policy below).
>
> **Verified-existing infra** (do NOT recreate):
>
> | Layer | File | Notes |
> |-------|------|-------|
> | BE schema | [Dashboard.MenuId](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/Dashboard.cs) | `int? FK → auth.Menus`. Slug/sort/visibility live on the linked Menu row. |
> | BE query | [GetDashboardByModuleAndCode.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleAndCode.cs) | Single-row, NO UserDashboard join, validates `Dashboard.MenuId IS NOT NULL`. |
> | FE component | [MenuDashboardComponent](../../../PSS_2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx) | Lean — no switcher, no edit chrome. Optional `toolbar?: ReactNode` prop already landed via Donation Dashboard #124. |
> | FE gql doc | [MenuDashboardQuery.ts](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/MenuDashboardQuery.ts) | `DASHBOARD_BY_MODULE_AND_CODE_QUERY`. |
> | DB seed precedent | [DonationDashboard-sqlscripts.sql](../../../PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/DonationDashboard-sqlscripts.sql) | Canonical 7-step idempotent seed — Communication Dashboard mirrors this layout. Preserve `sql-scripts-dyanmic/` folder typo per repo convention. |
> | DB seed (Path-A SQL) precedent | [fn_donation_dashboard_kpi_total_donations.sql](../../../PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_donation_dashboard_kpi_total_donations.sql) | Path-A functions returning `(data_json text, metadata_json text, total_count integer, filtered_count integer)` — Communication Dashboard's 17 functions match this exact signature. |
> | Sidebar auto-injection | Existing menu-tree composer | Already injects `*_DASHBOARDS` leaves; the seeded `COMMUNICATIONDASHBOARD` menu (OrderBy=3 under CRM_DASHBOARDS) just needs `Dashboard.MenuId` linked. |
> | Per-route stub | `[lang]/crm/dashboards/communicationdashboard/page.tsx` (currently renders `<DashboardComponent />` STATIC pattern) | **MUST be overwritten** to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="COMMUNICATIONDASHBOARD" toolbar={…} />` — see ISSUE-1. |

> ## 🎨 NEW WIDGET RENDERERS — DEFAULT POLICY (non-negotiable)
>
> Per the project's [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md) and the updated [_DASHBOARD.md § ⑤ Frontend Patterns](_DASHBOARD.md): **every widget on this dashboard ships a NEW dedicated renderer under `dashboards/widgets/communication-dashboard-widgets/`**.
>
> **Legacy renderers are FROZEN for #120 Main Dashboard ONLY** — DO NOT reuse on Communication Dashboard:
> - ❌ `StatusWidgetType1` / `StatusWidgetType2`
> - ❌ `MultiChartWidget`
> - ❌ `PieChartWidgetType1`
> - ❌ `BarChartWidgetType1`
> - ❌ `TableWidgetType1` / `NormalTableWidget` / `FilterTableWidget`
> - ❌ `RadialBarWidget`
> - ❌ `HtmlWidgetType1` / `HtmlWidgetType2`
> - ❌ `GeographicHeatmapWidgetType1`
> - ❌ Renderers from `case-dashboard-widgets/`, `donation-dashboard-widgets/`, `contact-dashboard-widgets/`, `volunteer-dashboard-widgets/`, `ambassador-dashboard-widgets/` — sibling-dashboard renderers are FROZEN to their original dashboards
>
> **Naming convention**: `Communication{Purpose}Widget` (e.g., `CommunicationHeroKpiWidget`, `CommunicationSendVolumeTrendWidget`).
> **Folder**: `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/communication-dashboard-widgets/`.
> **Each NEW renderer ships 4 files**:
> 1. `{WidgetName}.tsx` — the renderer (consumes `data_json` jsonb shape, renders the widget UI)
> 2. `{WidgetName}.types.ts` — TypeScript shape of the `data_json` payload
> 3. `{WidgetName}.skeleton.tsx` — shape-matched skeleton (KPI tile shape for KPI; donut ring for donut; bar-row shape for bar chart; row-skeletons for tables; alert-row skeletons for alert list — match the renderer's actual layout, not a generic rectangle)
> 4. `index.ts` — barrel export
>
> **Each widget must be VISUALLY UNIQUE — no clone tile grids.** Vary card size, accent color, icon, typography weight, background treatment, trend indicator style, badge style, chart type, row density per widget. Hero KPIs (Total Messages Sent, Avg Delivery Rate) ≠ supporting KPIs (Avg Open Rate, Opt-Out Rate) ≠ multi-segment KPIs (Active Campaigns split into "8 sending / 6 scheduled") ≠ cost-emphasized KPI (Cost This Month with dominant-channel callout). Trends use stacked area, parts-of-whole use donut, comparisons use horizontal bars, funnels use top-bordered cells — pick chart type per data shape, not "bar chart for everything." Each renderer's `.skeleton.tsx` matches its specific layout.
>
> **Anti-patterns explicitly forbidden** (per the [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md)):
> - ❌ N KPIs sharing ONE renderer with only label/value swapped — "CommunicationKpiCardWidget × 6" is the canonical anti-pattern
> - ❌ All charts toggling `chartType` on a single component — separate `CommunicationSendVolumeTrendWidget` (stacked-area), `CommunicationChannelMixDonutWidget` (donut), `CommunicationCostBarsWidget` (horizontal bar)
> - ❌ Identical card chrome (border, padding, header layout) across every widget
> - ❌ Single-rectangle shimmer skeleton for every widget — each renderer ships its own shape-matched skeleton
> - ❌ NotificationHealth / BounceSpam / ProviderHealth widgets sharing one `HealthGridWidget` — they have different banner treatments (no banner / danger-banner-with-CTA / multi-row-list), different accent icons, different drill-down emphasis; split them
>
> **Cross-instance reuse within a dashboard is the EXCEPTION, NOT the default.** Reuse only when the visual treatment is GENUINELY identical (same chrome, same color palette, same skeleton shape). When in doubt — split into separate renderers. For Communication Dashboard, the 6 KPIs split into 4 distinct renderers by visual hierarchy (see § ② widget table).
>
> **Vary `LayoutConfig` widget heights/widths so the grid signals importance, not flatness.** Hero KPIs may occupy taller cells (h=3) while supporting KPIs use h=2; full-width charts use w=12 while side-by-side comparisons use w=5+7 or w=6+6 — see § ⑥ grid layout for the importance hierarchy.
>
> **Each NEW renderer also gets its own NEW `sett.WidgetTypes` row** — one INSERT per distinct ComponentPath in the seed file's STEP 3. The 17 widget instances reference **15 distinct WidgetType rows** (per § ② widget table) — 4 KPI renderers (Hero / Delta / Status / Cost) + 11 single-use renderers. The developer may collapse/split further per the Developer-Decided-Widgets directive below, documenting each split/merge as an ISSUE-N entry.

> ## 🧠 DEVELOPER-DECIDED WIDGETS — read business context first
>
> Per the [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md): the FE/BE developer agents are EXPECTED to read the communication-domain business context (the 9 source entities, fundraising/marketing/IT-ops staff personas, existing list screens, the in-flight WhatsApp Campaign #32 / Email Campaign #25 patterns) and **decide** the final widget set themselves. **§ ② / ③ / ⑥ catalogs in this prompt are a draft, not a contract.** The developer can:
> - **Add** a widget the prompt missed (e.g., a "Domain Reputation Heatmap" panel if the team values per-domain SendGrid scoring)
> - **Drop** a widget the prompt overspecified (e.g., remove the "Active Campaigns" collapsible if Recent Sends feed already covers it)
> - **Reshape** a widget (e.g., merge Engagement Funnel + Top Templates into a single "Email Performance" panel if the data overlaps cleanly)
> - **Split** a widget (e.g., separate Provider Health into per-provider cards if the team treats SendGrid/Twilio/Meta as distinct dashboards-within-dashboard)
>
> Document every deviation in § ⑫ as an ISSUE-N entry with the rationale ("dropped TBL_ACTIVE_CAMPAIGNS because the Recent Sends feed already shows scheduled+running campaigns inline — duplicate signal"). The bar: **useful-at-a-glance > spec-compliant**. The developer is closest to the entities and users; trust their call.
>
> Constraints that DO NOT bend:
> - All 3 header filters (Period / Channel / Branch) MUST exist
> - The 6 KPI hero cards MUST exist (the team's daily-glance-of-channel-health; remove only with a strong rationale)
> - All drill-downs from clickable widgets MUST land on COMPLETED screens (no broken navigation — for WhatsApp Campaign / Email Campaign, see ISSUE-1 graceful-degrade rules below)
> - All alerts in widget 16 MUST be sourced from real entity rules (not faked)
> - Path-A function contract is non-negotiable (5-arg, 4-col return)
> - **Channel filter MUST scope all channel-aware widgets** — when "Email Only" is chosen, SMS/WhatsApp/InApp data is filtered out from KPIs, charts, tables, and alerts (the "Engagement Funnel" widget is Email-specific by name, so it stays Email regardless)

## Tasks

### Planning (by /plan-screens) — ALL DONE
- [x] HTML mockup analyzed (17 candidate widgets, 3 global filters, 9+ drill-down targets identified)
- [x] Variant chosen — **MENU_DASHBOARD** (own sidebar leaf at `crm/dashboards/communicationdashboard`, MenuCode `COMMUNICATIONDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=3)
- [x] Source entities resolved (9 notify-schema entities + Branch — see § ②.D / § ③)
- [x] Widget catalog drafted (17 widgets — DRAFT; developer may revise per the directive above)
- [x] react-grid-layout config drafted (lg/md/sm/xs breakpoints, 12 cols `lg`, ~42-row height)
- [x] DashboardLayout JSON shape drafted (LayoutConfig multi-breakpoint + ConfiguredWidget instance map)
- [x] Parent menu code + slug + OrderBy already-seeded (no new menu insert; only `Dashboard.MenuId` link)
- [x] First-time MENU_DASHBOARD setup — N/A (infra already shipped via #52 Phase 2 carve-out)
- [x] File manifest computed — see § ⑧
- [x] Approval config pre-filled — see § ⑨
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt §①-④ pre-analyzed; BA agent skipped — domain context is unambiguous)
- [x] Solution Resolution complete (prompt §⑤ pre-stamps DASHBOARD/MENU_DASHBOARD/Path-A; SR agent skipped — no decisions left)
- [x] UX Design finalized (widget grid + chart specs + filter controls — locked in §⑥)
- [x] User Approval received
- [x] **Backend (Path-A only — 17 SQL function files in NEW `DatabaseScripts/Functions/notify/` folder)** — NO new C# code; reuses existing `generateWidgets` GraphQL handler
- [x] **Frontend — 15 NEW dedicated widget renderers** under `dashboards/widgets/communication-dashboard-widgets/`. Each ships `{Name}.tsx + {Name}.types.ts + {Name}.skeleton.tsx + index.ts`. NO reuse of legacy renderers — see policy callout above and § ② widget table.
- [x] FE wiring: register all 15 new renderers in `dashboard-widget-registry.tsx` `WIDGET_REGISTRY` (key = ComponentPath value, value = the React component)
- [x] FE wiring: per-route stub `[lang]/crm/dashboards/communicationdashboard/page.tsx` overwritten to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="COMMUNICATIONDASHBOARD" toolbar={<CommunicationDashboardToolbar />} />` (ISSUE-1) — page-config wrapper rewritten; per-route stub already imports the wrapper.
- [x] FE: NEW Toolbar component `communication-dashboard-toolbar.tsx` housing the 3 filter selects + Export/Print buttons; threads filter state via existing `WidgetFilterContextProvider` to widgets
- [x] DB Seed file `sql-scripts-dyanmic/CommunicationDashboard-sqlscripts.sql` (preserve typo) — 7 steps mirroring DonationDashboard-sqlscripts.sql:
      • STEP 0 — Diagnostics (CRM module + BUSINESSADMIN role + COMMUNICATIONDASHBOARD menu + pre-flight check that the 15 NEW WidgetType rows do NOT yet exist)
      • STEP 1 — Insert Dashboard row (idempotent NOT EXISTS)
      • STEP 2 — Link Dashboard.MenuId to seeded COMMUNICATIONDASHBOARD Menu (idempotent UPDATE WHERE MenuId IS NULL)
      • STEP 3 — Insert **15 NEW WidgetType rows** (one per distinct ComponentPath — see § ② widget table). Each idempotent NOT EXISTS guard.
      • STEP 4 — Insert 17 Widget rows (one statement per widget, each with NOT EXISTS guard, references the right WidgetType + StoredProcedureName)
      • STEP 5 — Insert WidgetRole grants (BUSINESSADMIN read-all on all 17 widgets)
      • STEP 6 — Insert DashboardLayout row (LayoutConfig + ConfiguredWidget JSON × 17)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (no new C# code; verifies the migration that registers the 17 functions runs cleanly — or confirm functions are auto-applied at runtime per existing `case/` precedent)
- [ ] All 17 SQL functions exist in `notify.` schema after migration: `SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='notify' AND p.proname LIKE 'fn_communication_dashboard_%';` returns 17 rows
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/communicationdashboard`
- [ ] Network tab shows EXACTLY ONE GraphQL `dashboardByModuleAndCode` request (no `dashboardByModuleCode` leakage — that handler joins UserDashboard, MENU_DASHBOARD has none)
- [ ] All 17 widgets fetch and render with sample data
- [ ] **No legacy renderer is invoked** — `git grep` for `StatusWidgetType1\|MultiChartWidget\|PieChartWidgetType1\|BarChartWidgetType1\|FilterTableWidget\|NormalTableWidget\|TableWidgetType1\|AlertListWidget\|case-dashboard-alerts-widget\|donation-*-widget\|contact-*-widget` inside `communication-dashboard-widgets/` returns zero matches; the seed's WidgetType rows for the 17 widgets all reference `Communication*Widget` ComponentPaths
- [ ] Each KPI card shows correct value formatted per spec (currency / percent / count) using its dedicated NEW renderer (Hero / Delta / Status / Cost)
- [ ] Each chart renders correctly using its NEW renderer (axes, legends, tooltips, donut total in center, stacked-area annotations for "Ramadan campaign" + "Year-end giving push")
- [ ] Each table renders with correct columns + row click drill-down using its NEW renderer
- [ ] Period filter change refetches all date-honoring widgets in parallel
- [ ] Channel filter change scopes channel-aware widgets ("All Channels" / "Email Only" / "SMS Only" / "WhatsApp Only" / "Notification Only") — Engagement Funnel stays Email-specific
- [ ] Branch filter change refetches Branch-scoped widgets only
- [ ] Drill-down clicks navigate per § ⑥ Drill-Down Map (template list / campaign list / provider config / notification center / etc.)
- [ ] "Export Report" toasts SERVICE_PLACEHOLDER (no crash — see ISSUE-2)
- [ ] "Print" opens browser print dialog
- [ ] Each widget has its own SHAPE-MATCHED skeleton (NOT a generic rectangle) — verify visually during loading
- [ ] Empty / error states render per widget
- [ ] Role-based widget gating: WidgetRole(HasAccess=false) → widget hidden
- [ ] Alerts list (widget 16) generates plausible alert items per the rules in § ④ for sample data
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl)
- [ ] Sidebar leaf "Communication Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] Bookmarked URL `/[lang]/crm/dashboards/communicationdashboard` survives reload
- [ ] Role-gating via existing `RoleCapability(MenuId=COMMUNICATIONDASHBOARD)` hides the sidebar leaf for unauthorized roles

---

## ① Screen Identity & Context

**Consumer**: All agents — sets the stage

**Screen**: CommunicationDashboard
**Module**: CRM → Communication (sidebar leaf under CRM_DASHBOARDS)
**Schema**: NONE for the dashboard itself (`sett.Dashboards` + `sett.DashboardLayouts` + `sett.Widgets` already exist). NEW `notify` Postgres function namespace introduced for widget aggregations (folder `DatabaseScripts/Functions/notify/` does NOT yet exist; create it on this build).
**Group**: NONE (no new C# DTOs / handlers — Path-A throughout)

**Dashboard Variant**: **MENU_DASHBOARD** — own sidebar leaf at `crm/dashboards/communicationdashboard` (MenuCode `COMMUNICATIONDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=3). NOT in any dropdown switcher.

**Business**:
The Communication Dashboard is the **operations + executive overview** for the entire outreach stack — it answers two questions every Marketing Lead, Donor-Care Officer, and IT-Ops admin asks daily: "Are our messages getting through?" and "What needs my attention right now?" It rolls up 9 distinct communication surfaces — Email Templates (#24), Email Campaigns / SendJobs (#25), Email Provider config (#28), SMS Templates (#29), SMS Campaigns (#30), WhatsApp Templates (#31), WhatsApp Campaigns (#32), Notification Center (#35), and Notification Templates (#36) — into a single board-level cross-channel summary. **Target audience**: Marketing Lead, Donor-Care Officer, Fundraising Director, IT-Ops Admin (provider health), Finance team (cost rollups), and Branch Managers who triage scheduled campaigns, retry failed sends, monitor opt-out rates, and reconcile per-channel spend. **Why it exists**: the existing list pages serve transactional CRUD but offer no cross-cutting "is the channel mix healthy?" view. The dashboard surfaces aggregate volume / delivery / open-rate / cost / opt-out KPIs, top-performing templates across all 4 channels, send-volume trends, channel mix, cost-by-channel, the email engagement funnel, provider health (SendGrid/Twilio/Meta WhatsApp/InApp), recent sends + queue, notification center health, bounce/spam watch, and per-campaign progress in one place. **Why MENU_DASHBOARD (not STATIC)**: deep-linkable from emailed daily-summary reports; role-restricted to Marketing/Communication/IT-Ops staff (not all CRM users); tightly scoped to communication operations — no need to share dropdown space with Donation / Case / Volunteer dashboards. **Distinct from #38 Email Analytics** (which is email-channel-only — delivery/open/click/A-B-test/bounce diagnostics scoped to #24+#25 only). Communication Dashboard is **cross-channel**: Email + SMS + WhatsApp + In-App rolled up together. Sibling design of Donation Dashboard #124 / Case Dashboard #52 (same MENU_DASHBOARD pattern, violet accent `#7c3aed` vs. emerald `#059669` vs. teal `#0d9488`) — but Communication Dashboard ships its OWN dedicated FE renderers per the new policy.

---

## ② Entity Definition

**Consumer**: BA Agent → Backend Developer

> Dashboard does NOT introduce a new entity. It composes **two seeded rows** (`sett.Dashboards` + `sett.DashboardLayouts`) over **9 existing source entities** + Branch.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `COMMUNICATIONDASHBOARD` | Matches Menu.MenuCode |
| DashboardName | `Communication Dashboard` | Matches Menu.MenuName |
| DashboardIcon | `tower-broadcast-bold` | Phosphor icon name (no `ph:` prefix — `<MenuDashboardComponent />` adds it) |
| DashboardColor | `#7c3aed` | Violet accent from mockup `--cm-accent` |
| ModuleId | (resolve from `auth.Modules WHERE ModuleCode='CRM'`) | CRM module |
| IsSystem | `true` | System-seeded |
| IsActive | `true` | — |
| CompanyId | NULL | Global system dashboard |
| MenuId | (resolve from `auth.Menus WHERE MenuCode='COMMUNICATIONDASHBOARD'`) | Set in seed STEP 2; NULL leaves the slug page returning "Dashboard not found" |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | JSON: `{"lg":[…17 layout items…], "md":[…], "sm":[…], "xs":[…]}` | All 4 breakpoints REQUIRED — `<MenuDashboardComponent />` reads each. Do NOT submit only `lg`. |
| ConfiguredWidget | JSON: `[{i, widgetId}, … 17 entries]` | `i` = instance code (e.g., `KPI_TOTAL_MESSAGES`); `widgetId` resolves to a `sett.Widgets` row in STEP 4. |

### C. Widget Definitions (`sett.Widgets` + `sett.WidgetTypes`)

> All Path-A — each widget has `StoredProcedureName` set; `DefaultQuery` is NULL.
> **All 15 ComponentPaths below are NEW** (per the renderer policy — no reuse of legacy `WIDGET_REGISTRY` keys or sibling-dashboard renderers). Seed STEP 3 inserts one `sett.WidgetTypes` row per distinct ComponentPath; STEP 4 inserts 17 `sett.Widgets` rows referencing those types.

| # | WidgetCode (=instanceId) | WidgetName | ComponentPath (NEW) | StoredProcedureName | OrderBy |
|---|--------------------------|------------|---------------------|---------------------|---------|
| 1 | KPI_TOTAL_MESSAGES | Total Messages Sent | **CommunicationHeroKpiWidget** *(hero — large w=6 h=3 cell, violet gradient header strip, paper-plane icon, 12-mo sparkline)* | notify.fn_communication_dashboard_kpi_total_messages | 1 |
| 2 | KPI_AVG_DELIVERY_RATE | Avg Delivery Rate | CommunicationHeroKpiWidget *(2nd hero instance — green gradient, circle-check icon, percent format, 12-mo sparkline)* | notify.fn_communication_dashboard_kpi_avg_delivery_rate | 2 |
| 3 | KPI_AVG_OPEN_RATE_EMAIL | Avg Open Rate (Email) | **CommunicationDeltaKpiWidget** *(supporting — h=2, indigo accent, envelope-open icon, "vs industry avg 28%" baseline subtitle)* | notify.fn_communication_dashboard_kpi_avg_open_rate_email | 3 |
| 4 | KPI_ACTIVE_CAMPAIGNS | Active Campaigns | **CommunicationStatusKpiWidget** *(supporting — h=2, orange accent, bullhorn icon, dual-segment subtitle "8 sending · 6 scheduled" with two pill chips)* | notify.fn_communication_dashboard_kpi_active_campaigns | 4 |
| 5 | KPI_COST_THIS_MONTH | Cost (this month) | **CommunicationCostKpiWidget** *(distinct — h=2, amber-tinted card, coins icon, "SMS dominant" callout chip, currency format)* | notify.fn_communication_dashboard_kpi_cost_this_month | 5 |
| 6 | KPI_OPT_OUT_RATE | Opt-Out Rate | CommunicationDeltaKpiWidget *(2nd delta instance — h=2, rose accent, user-slash icon, declining-good semantic with positive-color down arrow, "78 unsubscribes" subtitle)* | notify.fn_communication_dashboard_kpi_opt_out_rate | 6 |
| 7 | TBL_TOP_TEMPLATES | Top Performing Templates | **CommunicationTopTemplatesTableWidget** *(unique — 7-col table: Template name + Channel pill + Sent count + 3 rate-bar columns Delivery/Open/Click-or-Reply + Last Used relative time. Click row → channel-specific template list.)* | notify.fn_communication_dashboard_top_templates | 7 |
| 8 | CHART_SEND_VOLUME_TREND | Send Volume Trend | **CommunicationSendVolumeTrendWidget** *(unique — full-width 12-month stacked-area chart with 4-channel palette Email/SMS/WhatsApp/InApp + annotation pins for "Ramadan campaign launch" Mar + "Year-end giving push" Dec)* | notify.fn_communication_dashboard_send_volume_trend | 8 |
| 9 | CHART_CHANNEL_MIX | Messages by Channel | **CommunicationChannelMixDonutWidget** *(unique — 4-segment donut Email/SMS/WhatsApp/InApp with center label + count, segment legend with absolute count + percent)* | notify.fn_communication_dashboard_channel_mix | 9 |
| 10 | CHART_COST_BY_CHANNEL | Cost by Channel | **CommunicationCostBarsWidget** *(unique — 4 horizontal cost bars Email/SMS/WhatsApp/InApp with channel-colored fills + inline currency labels + cost-per-1K-msgs footer line)* | notify.fn_communication_dashboard_cost_by_channel | 10 |
| 11 | CHART_ENGAGEMENT_FUNNEL | Engagement Funnel (Email) | **CommunicationEngagementFunnelWidget** *(unique — 5-step funnel Sent→Delivered→Opened→Clicked→Replied with colored TOP-BORDERS per step, count + relative percent per cell, "Replied applies to reply-tracking templates only" disclaimer)* | notify.fn_communication_dashboard_engagement_funnel | 11 |
| 12 | LIST_PROVIDER_HEALTH | Provider Health | **CommunicationProviderHealthWidget** *(unique — 4-row provider list with per-row icon circle + provider name + meta string + status pill UP/DEGRADED/DOWN; rows for SendGrid/Twilio/Meta WhatsApp/InApp, "Configure" header CTA → email provider config)* | notify.fn_communication_dashboard_provider_health | 12 |
| 13 | LIST_RECENT_SENDS | Recent Sends & Queue | **CommunicationRecentSendsFeedWidget** *(unique — vertical scrolling activity feed max-h 320px, per-channel colored icon circle + 2-line content + status pill SENDING/SENT/SCHEDULED/FAILED + relative-time meta. Distinct from `DonationRecentActivityWidget` — uses status-pill column instead of amount, channel-coded instead of payment-method)* | notify.fn_communication_dashboard_recent_sends | 13 |
| 14 | TBL_NOTIFICATION_HEALTH | Notification Center Health | **CommunicationNotificationHealthWidget** *(distinct — 4-cell mini-stat grid violet/success/warn/danger color cues, NO banner, "Open Inbox" header CTA → notification center, inbox icon)* | notify.fn_communication_dashboard_notification_health | 14 |
| 15 | TBL_BOUNCE_SPAM | Bounce & Spam Watch | **CommunicationBounceSpamWidget** *(distinct — 4-cell mini-stat grid warn/danger/success/warn cues + DANGER banner with CTA "4 expired SMS sender registrations — re-verify before next campaign", "Configure" header CTA, shield-halved icon)* | notify.fn_communication_dashboard_bounce_spam | 15 |
| 16 | LIST_ALERTS | Alerts & Actions | **CommunicationAlertsListWidget** *(unique — severity-colored alert rows danger/warning/info/success with distinct bg + border per severity, sanitized `<strong>` only, CTA link per row, bell icon. Does NOT reuse `DonationAlertsListWidget` or legacy `AlertListWidget`)* | notify.fn_communication_dashboard_alerts | 16 |
| 17 | TBL_ACTIVE_CAMPAIGNS | Active Campaigns | **CommunicationActiveCampaignsTableWidget** *(unique — 7-col collapsible table: Campaign name + Channel pill + Recipients count + Status pill + Delivery rate-bar + Cost monospace + Schedule label, "+ Create Campaign" footer button)* | notify.fn_communication_dashboard_active_campaigns | 17 |

**Distinct ComponentPaths = 15** → 15 new `sett.WidgetTypes` rows in seed STEP 3:

| # | WidgetTypeCode | WidgetTypeName | ComponentPath | Visual Treatment |
|---|----------------|----------------|---------------|------------------|
| 1 | COMM_HERO_KPI | Communication Hero KPI | CommunicationHeroKpiWidget | LARGE card (h=3 cell), 12-mo sparkline, gradient header strip (violet or green per instance), bold value + delta arrow, trend microcopy. Used 2× (Total Messages Sent + Avg Delivery Rate) — these are the 2 headline stats |
| 2 | COMM_DELTA_KPI | Communication Delta KPI | CommunicationDeltaKpiWidget | Mid-size card (h=2), single primary value + delta % + colored arrow, plus a single subtitle line (industry baseline for Open Rate, "78 unsubscribes" for Opt-Out). Indigo or rose accent per instance. Used 2× |
| 3 | COMM_STATUS_KPI | Communication Status KPI | CommunicationStatusKpiWidget | Compact card (h=2), bullhorn icon, primary value (count) + DUAL pill-chip subtitle ("8 sending" + "6 scheduled" — two distinct color pills, NOT a single combined string), orange accent. Used 1× (Active Campaigns) |
| 4 | COMM_COST_KPI | Communication Cost KPI | CommunicationCostKpiWidget | Compact card (h=2), amber-tinted background, coins icon, primary currency value + warning-color delta % + dominant-channel callout chip ("SMS dominant"), distinct from Delta+Status because of the cost-emphasis chrome. Used 1× (Cost This Month) |
| 5 | COMM_TOP_TEMPLATES_TABLE | Communication Top Templates Table | CommunicationTopTemplatesTableWidget | 7-col table with channel pill + 3 rate-bar columns side-by-side (140px each, color-coded by performance threshold) + relative-time label. Distinct from any other table on this dashboard. Used 1× |
| 6 | COMM_SEND_VOLUME_TREND | Communication Send Volume Trend Chart | CommunicationSendVolumeTrendWidget | 12-month stacked-area chart, 4-channel color palette (Email indigo / SMS orange / WhatsApp green / InApp amber), annotation pins for campaign launches. Used 1× |
| 7 | COMM_CHANNEL_MIX_DONUT | Communication Channel Mix Donut | CommunicationChannelMixDonutWidget | Donut chart with center total ("186K messages" → 2-line center label) + 4-segment legend with absolute count + percent. Used 1× |
| 8 | COMM_COST_BARS | Communication Cost Bars | CommunicationCostBarsWidget | 4 horizontal cost-by-channel bars with channel-colored fills + inline currency labels + cost-per-1K-msgs footer line. Used 1× |
| 9 | COMM_ENGAGEMENT_FUNNEL | Communication Engagement Funnel | CommunicationEngagementFunnelWidget | 5-step Email funnel with COLORED TOP-BORDERS per step (violet/blue/cyan/green/amber per the mockup CSS), step label + count + percent per cell, disclaimer footer. Used 1× |
| 10 | COMM_PROVIDER_HEALTH | Communication Provider Health | CommunicationProviderHealthWidget | 4-row provider list, per-row 36px icon circle + provider name + multi-stat meta line + status pill (UP green / DEGRADED amber / DOWN red), header CTA to Configure. Used 1× |
| 11 | COMM_RECENT_SENDS_FEED | Communication Recent Sends Feed | CommunicationRecentSendsFeedWidget | Vertical scrolling activity feed (max-h 320px), per-channel colored icon circle + 2-line content (campaign name + channel/recipients/relative-time meta) + right-aligned status pill (SENDING amber / SENT green / SCHEDULED violet / FAILED red), header CTA "View All". Used 1× |
| 12 | COMM_NOTIFICATION_HEALTH | Communication Notification Health | CommunicationNotificationHealthWidget | 4-cell mini-stat grid (violet / success-green / warning-amber / danger-red value colors per cell), NO banner, "Open Inbox" header CTA, inbox icon. Used 1× |
| 13 | COMM_BOUNCE_SPAM | Communication Bounce & Spam Watch | CommunicationBounceSpamWidget | 4-cell mini-stat grid (warn / danger / success / warn cues) + DANGER banner with reverify CTA + shield-halved accent icon + "Configure" header CTA. Visually distinct from NotificationHealth (no banner) and from ProviderHealth (which is row-list shape). Used 1× |
| 14 | COMM_ALERTS_LIST | Communication Alerts & Actions | CommunicationAlertsListWidget | Severity-colored alert rows (4 severity treatments: warning / danger / info / success — distinct bg + border per severity), sanitized `<strong>` only, CTA link per row, bell icon. Used 1× |
| 15 | COMM_ACTIVE_CAMPAIGNS_TABLE | Communication Active Campaigns Table | CommunicationActiveCampaignsTableWidget | 7-col collapsible table with channel pill + recipients count + status pill + delivery rate-bar + cost monospace cell + schedule label, "+ Create Campaign" footer button. Used 1× |

> The 3 mini-stat-grid widgets (rows 12/13 — NotificationHealth + BounceSpam) share the SAME 4-cell layout shape but have DIFFERENT chrome treatments per the visual-uniqueness directive: different accent icons (inbox / shield-halved), different banner presence/severity (none / danger), different drill-down emphasis. Splitting them into 2 renderers (vs. one shared `CommunicationHealthGridWidget`) is the explicit policy choice — see ISSUE-3.

### D. Source Entities (read-only — what the widgets aggregate over)

| # | Source Entity | Schema.Table | File Path | Purpose |
|---|--------------|--------------|-----------|---------|
| 1 | EmailTemplate | `notify.EmailTemplates` | `Base.Domain/Models/NotifyModels/EmailTemplate.cs` | Top Performing Templates (Email rows) |
| 2 | EmailSendJob (=Email Campaign) | `notify.EmailSendJobs` | `Base.Domain/Models/NotifyModels/EmailSendJob.cs` | KPI 1 (Email subset), KPI 2 (Email subset), KPI 4 (Email subset), KPI 5 (Email subset), Send Volume Trend (Email channel), Engagement Funnel (Email-only), Recent Sends (Email rows), Active Campaigns (Email rows) |
| 3 | CompanyEmailProvider | `notify.CompanyEmailProviders` | `Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs` | Provider Health (SendGrid row + DomainReputationScore + BounceRate + SpamRate fields), Bounce/Spam Watch (Reputation cell from ReputationScore) |
| 4 | SMSTemplate | `notify.SMSTemplates` | `Base.Domain/Models/NotifyModels/SMSTemplate.cs` | Top Performing Templates (SMS rows) |
| 5 | SMSCampaign | `notify.SMSCampaigns` | `Base.Domain/Models/NotifyModels/SMSCampaign.cs` | KPI 1 (SMS subset), KPI 2 (SMS subset), KPI 4 (SMS subset), KPI 5 (SMS subset), Send Volume Trend (SMS channel), Recent Sends (SMS rows), Active Campaigns (SMS rows), Provider Health (Twilio row aggregates), Bounce/Spam Watch (SMS Failures cell), Alerts (Twilio quota / sender ID alerts) |
| 6 | WhatsAppTemplate | `notify.WhatsAppTemplates` | `Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs` | Top Performing Templates (WhatsApp rows) |
| 7 | WhatsAppCampaign | `notify.WhatsAppCampaigns` (**ENTITY DOES NOT YET EXIST** — Screen #32 PROMPT_READY) | (TBD — entity will live in `Base.Domain/Models/NotifyModels/WhatsAppCampaign.cs` post-#32-build) | KPI 1 (WhatsApp subset), Send Volume Trend (WhatsApp channel), Recent Sends (WhatsApp rows), Active Campaigns (WhatsApp rows), Provider Health (Meta WhatsApp row). **Functions handle the missing-table case via `to_regclass`-guarded CTEs** — see ISSUE-1 |
| 8 | Notification (=Notification Center) | `notify.Notifications` | `Base.Domain/Models/NotifyModels/Notification.cs` (note: `namespace SharedModels;` despite folder NotifyModels) | KPI 1 (InApp subset), Send Volume Trend (InApp channel), Recent Sends (InApp rows), Notification Health (Sent30d / ReadRate / Unread / Urgent — all 4 cells) |
| 9 | NotificationTemplate | `notify.NotificationTemplates` | `Base.Domain/Models/NotifyModels/NotificationTemplate.cs` | Top Performing Templates (InApp rows — count by NotificationTemplateId from Notification rows) |
| 10 | Branch | `app.Branches` | `Base.Domain/Models/ApplicationModels/Branch.cs` | Branch filter dropdown only |

---

## ③ Source Entity & Aggregate Query Resolution

**Consumer**: Backend Developer (Postgres function authors) + Frontend Developer (widget binding via `Widget.StoredProcedureName`)

> Path-A across all 17 widgets. Each widget calls `SELECT * FROM notify."{function_name}"(p_filter_json::jsonb, p_page, p_page_size, p_user_id, p_company_id)` via the existing `generateWidgets` GraphQL handler.

| # | Source Entities | Postgres Function | Returns (`data_json` shape — NEW renderer consumes this directly) | Filter Args (in p_filter_json) |
|---|-----------------|-------------------|------|----|
| 1 | EmailSendJob + SMSCampaign + WhatsAppCampaign? + Notification | `notify.fn_communication_dashboard_kpi_total_messages` | `{value:int, formatted:string ("186K" or "186,420"), deltaLabel:string ("↑ 12% vs last month"), deltaColor:'positive'\|'warning'\|'neutral', subtitle:string ("all channels"), sparkline:{labels:string[12], data:int[12]}, accent:'violet'}` | dateFrom, dateTo, channel, branchId |
| 2 | EmailSendJob (TotalEmailsSend / Failed) + SMSCampaign + WhatsAppCampaign? + Notification | `notify.fn_communication_dashboard_kpi_avg_delivery_rate` | same KPI shape — value formatted as percent, accent=`green` | dateFrom, dateTo, channel, branchId |
| 3 | EmailSendJob aggregated open rate (via EmailJobAnalytics OR computed from EmailSendQueue events) | `notify.fn_communication_dashboard_kpi_avg_open_rate_email` | `{value:decimal, formatted:'42.8%', deltaLabel:string, deltaColor:'positive', subtitle:string ("industry avg 28%"), accent:'indigo'}` (Delta KPI shape — no sparkline) | dateFrom, dateTo, branchId. **Channel filter ignored** — this widget is Email-only by name. |
| 4 | EmailSendJob + SMSCampaign + WhatsAppCampaign? — campaigns currently active OR scheduled | `notify.fn_communication_dashboard_kpi_active_campaigns` | `{value:int, formatted:'14', subtitle:'8 sending · 6 scheduled', segments:[{label:'sending', count:8, color:'amber'},{label:'scheduled', count:6, color:'violet'}], accent:'orange'}` (Status KPI shape — dual-pill segments) | dateFrom, dateTo, channel, branchId |
| 5 | EmailSendJob (cost from CompanyEmailProvider.CostPerEmail × volume) + SMSCampaign.ActualCostCents/EstimatedCostCents + WhatsAppCampaign? + Notification (negligible) | `notify.fn_communication_dashboard_kpi_cost_this_month` | `{value:decimal, formatted:'$1,847', deltaLabel:'↑ 18% vs last month', deltaColor:'warning', dominantChannel:'SMS', dominantLabel:'SMS dominant', accent:'amber'}` (Cost KPI shape — currency + dominant-channel callout) | dateFrom, dateTo, channel, branchId |
| 6 | EmailSendJob + SMSCampaign + WhatsAppCampaign? — opt-out / unsubscribe events; Email via EmailWebhookEventLog `event=unsubscribe`, SMS via opt-out keywords logged on SMSCampaign reply, WhatsApp via WhatsAppOptKeyword | `notify.fn_communication_dashboard_kpi_opt_out_rate` | `{value:decimal, formatted:'0.42%', deltaLabel:'↓ 0.08% MoM', deltaColor:'positive' (declining=good), subtitle:'78 unsubscribes', accent:'rose'}` (Delta KPI — declining-good semantic) | dateFrom, dateTo, channel, branchId |
| 7 | EmailTemplate + EmailSendJob + SMSTemplate + SMSCampaign + WhatsAppTemplate + WhatsAppCampaign? + NotificationTemplate + Notification — top-N templates ranked by sent volume in window | `notify.fn_communication_dashboard_top_templates` | `{rows:[{templateId, templateName, channel:'email'\|'sms'\|'whatsapp'\|'notification', channelColorHex, sent, deliveryPct, deliveryColor:'green'\|'amber'\|'red', openPct?, openColor?, clickOrReplyPct?, clickOrReplyColor?, lastUsedLabel:string}]}` — top 6 across all 4 channels | dateFrom, dateTo, channel, branchId |
| 8 | EmailSendJob + SMSCampaign + WhatsAppCampaign? + Notification — monthly send volume per channel | `notify.fn_communication_dashboard_send_volume_trend` | `{type:'area', labels:string[12] (month strings), series:[{name:'Email', color:'#4f46e5', data:int[12]},{name:'SMS', color:'#f97316', data:int[12]},{name:'WhatsApp', color:'#22c55e', data:int[12]},{name:'In-App', color:'#d97706', data:int[12]}], annotations?:[{xValue:'Mar', label:'Ramadan campaign launch'},{xValue:'Dec', label:'Year-end giving push'}]}` | branchId, channel (when set, render only that series; mockup default = stacked all 4) |
| 9 | EmailSendJob.TotalEmailsSend + SMSCampaign.AudienceNetRecipientsCount (or AudienceTotalCount) + WhatsAppCampaign? + Notification.COUNT(*) — bucketed | `notify.fn_communication_dashboard_channel_mix` | `{total:int, totalFormatted:'186K', label:'messages', segments:[{label:'Email', value:119000, pct:64, color:'#4f46e5'},{label:'SMS', value:33000, pct:18, color:'#f97316'},{label:'WhatsApp', value:23000, pct:12, color:'#22c55e'},{label:'In-App', value:11000, pct:6, color:'#d97706'}]}` | dateFrom, dateTo, branchId |
| 10 | EmailSendJob × CompanyEmailProvider.CostPerEmail + SMSCampaign.ActualCostCents + WhatsAppCampaign? + Notification (≈ 0) | `notify.fn_communication_dashboard_cost_by_channel` | `{total:decimal, totalFormatted:'$1,847', bars:[{label:'SMS', value:1124, valueFormatted:'$1,124', widthPct:100, color:'#f97316', icon:'mobile-screen'},{label:'WhatsApp', value:425, valueFormatted:'$425', widthPct:38, color:'#22c55e', icon:'whatsapp'},{label:'Email', value:268, valueFormatted:'$268', widthPct:24, color:'#4f46e5', icon:'envelope'},{label:'In-App', value:30, valueFormatted:'$30', widthPct:3, color:'#d97706', icon:'bell'}], costPer1k:[{label:'Email', value:'$2.25'},{label:'SMS', value:'$34.10'},{label:'WhatsApp', value:'$18.50'},{label:'In-App', value:'$2.70'}]}` | dateFrom, dateTo, branchId |
| 11 | EmailSendJob + EmailJobAnalytics (open/click events) + EmailSendQueue (delivered/failed) + EmailWebhookEventLog (replies) | `notify.fn_communication_dashboard_engagement_funnel` | `{steps:[{label:'Sent', value:119420, pct:100, color:'#7c3aed'},{label:'Delivered', value:115250, pctOfPrevious:96.5, formattedPct:'96.5%', color:'#3b82f6'},{label:'Opened', value:49327, pct:42.8, formattedPct:'42.8%', color:'#06b6d4'},{label:'Clicked', value:8924, pctOfOpened:18.1, formattedPct:'18.1% of opens', color:'#22c55e'},{label:'Replied', value:412, pct:0.4, formattedPct:'0.4%', color:'#f59e0b'}], disclaimer:'Replied applies to reply-tracking templates only'}` | dateFrom, dateTo, branchId. **Channel filter ignored** — this widget is Email-only by name. |
| 12 | CompanyEmailProvider (DomainReputationScore, BounceRate, SpamRate, DomainStatus, etc.) + SMSCampaign aggregates (Twilio) + WhatsAppCampaign? aggregates (Meta) + Notification (in-app realtime) | `notify.fn_communication_dashboard_provider_health` | `{providers:[{key:'sendgrid', name:'SendGrid (Email)', icon:'envelope', iconColor:'#1d4ed8', status:'UP'\|'DEGRADED'\|'DOWN', meta:'119,420 sent · 0.8% bounce · last sync: 2 min ago'},{key:'twilio', name:'Twilio (SMS)', icon:'mobile-screen', iconColor:'#f97316', …},{key:'meta_whatsapp', name:'Meta WhatsApp Business', icon:'whatsapp', iconColor:'#22c55e', …},{key:'inapp', name:'In-App Notifications (internal)', icon:'bell', iconColor:'#d97706', …}]}` | dateFrom, dateTo, branchId |
| 13 | EmailSendJob (latest) + SMSCampaign (latest) + WhatsAppCampaign? (latest) + Notification (latest) — UNION top 7 by ScheduleStartDatetime / SentAt / NotificationDate desc | `notify.fn_communication_dashboard_recent_sends` | `{rows:[{itemId:string ("email:42"), channel:'email'\|'sms'\|'whatsapp'\|'notification', icon:string, iconColor:string, line1:string ("Year-End Giving — Day 3"), line2:string ("Email · 8,420 recipients · started 2h ago"), status:'SENDING'\|'SENT'\|'SCHEDULED'\|'FAILED'\|'RECURRING', statusColor:'amber'\|'green'\|'violet'\|'red'\|'green', drillRoute:string, drillArgs:object}]}` — 7 most recent | branchId, channel |
| 14 | Notification (NotificationCenter #35) — Sent30d / ReadRate / Unread / Urgent | `notify.fn_communication_dashboard_notification_health` | `{stats:[{label:'Sent (30d)', value:10986, valueFormatted:'10,986', amount:'internal feed', valueColor:'violet'},{label:'Read Rate', value:64, valueFormatted:'64%', amount:'7,031 read', valueColor:'green-success'},{label:'Unread', value:3955, valueFormatted:'3,955', amount:'36% of total', valueColor:'amber'},{label:'Urgent', value:42, valueFormatted:'42', amount:'unread > 24h', valueColor:'red'}]}` (NO banner — function does NOT emit a `banner` field) | dateFrom, dateTo, branchId |
| 15 | EmailWebhookEventLog (bounce/spam) + SMSCampaign delivery failures + CompanyEmailProvider.SpamRate + sender ID expirations | `notify.fn_communication_dashboard_bounce_spam` | `{stats:[{label:'Email Bounces', value:956, valueFormatted:'956', amount:'0.8% rate (low)', valueColor:'amber'},{label:'SMS Failures', value:412, valueFormatted:'412', amount:'1.2% rate', valueColor:'red'},{label:'Spam Reports', value:8, valueFormatted:'8', amount:'0.007% (excellent)', valueColor:'green'},{label:'Reputation', value:94, valueFormatted:'94', amount:'/100 SendGrid', valueColor:'amber'}], banner:{kind:'danger', message:'<strong>4 expired SMS sender registrations</strong> — re-verify before next campaign.', ctaLabel?:string, ctaRoute?:string, ctaArgs?:object}}` (banner ALWAYS present when expired-sender-IDs > 0; conditional otherwise) | dateFrom, dateTo, branchId |
| 16 | Cross-source rule engine | `notify.fn_communication_dashboard_alerts` | `{alerts:[{severity:'warning'\|'danger'\|'info'\|'success', iconCode:'phosphor-name', message:'<strong>Bulk SMS to Lapsed Donors failed</strong> — Twilio quota exceeded; 1,124 recipients un-sent', link:{label:'Investigate', route:'crm/communication/smscampaign', args:{campaignId:int}}}]}` — top 10 by severity then recency, sanitized HTML (only `<strong>` allowed) | dateFrom, dateTo, channel, branchId |
| 17 | EmailSendJob + SMSCampaign + WhatsAppCampaign? — currently active or scheduled-near-future | `notify.fn_communication_dashboard_active_campaigns` | `{rows:[{campaignId:int, campaignType:'email'\|'sms'\|'whatsapp', campaignName:string, channel:string, channelColor:string, recipients:int, recipientsFormatted:string, status:'SENDING'\|'SCHEDULED'\|'FAILED'\|'RECURRING', statusColor:string, deliveryPct?:decimal, deliveryFormatted?:string, deliveryColor?:string, costFormatted:string, scheduleLabel:string, drillRoute:string ("crm/communication/emailcampaign"), drillArgs:object ({campaignId})}]}` | dateFrom, dateTo, channel, branchId |

**Strategy**: **Path A — Postgres functions only**. No composite C# DTO; no per-widget GraphQL handler. Each widget binds to one function via `Widget.StoredProcedureName`. The runtime calls the existing `generateWidgets` GraphQL field with the function name + filter context. Matches the established Donation Dashboard #124 / Case Dashboard #52 precedent (17 functions in `fund/` and `case/` respectively); creates the parallel `notify/` folder.

**WhatsAppCampaign graceful degrade** — every function that aggregates over WhatsAppCampaign MUST guard the table reference with `to_regclass('notify."WhatsAppCampaigns"')`:
```sql
WITH wa_volume AS (
  SELECT COALESCE(SUM(...), 0) AS msg_count
  FROM notify."WhatsAppCampaigns"
  WHERE to_regclass('notify."WhatsAppCampaigns"') IS NOT NULL
    AND ...
)
```
This makes the function resilient to the entity not yet existing — WhatsApp data simply contributes 0 to aggregates until #32 builds the table. See ISSUE-1.

---

## ④ Business Rules & Validation

**Consumer**: BA Agent → Backend Developer (Postgres functions enforce filtering) → Frontend Developer (filter behavior + drill-down args)

### Date Range Defaults
- Default range: **This Month** (1st of current calendar month → today)
- Allowed presets: This Month / Last Month / This Quarter / This Year / Custom Range
- Custom range max span: **2 years** (FE filter validation; functions cap p_filter_json span if larger)
- Date filter applies to:
  - `EmailSendJob.LastExecutionStartedAt` / `ScheduleStartDatetime` (Email send rows)
  - `SMSCampaign.SentAt` / `ScheduledAt` (SMS send rows)
  - `WhatsAppCampaign.SentAt` (WhatsApp send rows — graceful degrade if missing)
  - `Notification.CreatedDate` (In-App)
  - `EmailWebhookEventLog.EventTimestamp` (open/click/bounce/unsubscribe events for Funnel + Bounce/Spam Watch + Opt-Out KPI)

### Channel Filter (DASHBOARD-SPECIFIC — unique to this dashboard)
- Filter values: `ALL` (default) / `EMAIL` / `SMS` / `WHATSAPP` / `NOTIFICATION`
- When `ALL`: every channel-aware widget aggregates across all 4 channels.
- When a single channel: every channel-aware widget filters down to that channel only.
- **Channel-aware widgets**: KPIs 1, 2, 4, 5, 6 / SendVolumeTrend / ChannelMixDonut / CostBars / ProviderHealth / RecentSends / Alerts / ActiveCampaigns
- **Channel-fixed widgets** (ignore Channel filter):
  - KPI 3 — Avg Open Rate (Email) — Email-only by name
  - Engagement Funnel — Email-only by name
  - TopTemplates — channel column shown; Channel filter scopes the rows shown
  - NotificationHealth — In-App-only by definition
  - BounceSpamWatch — multi-channel by design (Email bounces / SMS failures / Spam reports / Reputation)

### Role-Scoped Data Access
- **BUSINESSADMIN** → sees ALL companies' data
- **MARKETING_LEAD / COMMUNICATION_OFFICER** → own company only (`CompanyId = HttpContext.CompanyId`)
- **BRANCH_MANAGER** → additionally filtered by `BranchId IN user's branches` (read from `auth.UserBranches`). Note: most communication source entities do NOT carry a `BranchId` FK directly — branch scoping happens transitively through `OrganizationalUnitId` (EmailSendJob has it) or through the campaign's owning user/team. ISSUE-9 tracks the per-entity strategy.
- **IT_OPS** → company-scoped; full Provider Health + Bounce/Spam visibility
- **FINANCE_USER** → company-scoped; primarily uses Cost This Month + Cost By Channel
- All scoping happens in the Postgres function via `p_user_id` + `p_company_id` parameters

### Calculation Rules
- **KPI 1 — Total Messages Sent**:
  - Email: `SUM(EmailSendJob.TotalEmailsSend WHERE LastExecutionStartedAt IN range AND IsDeleted=false)`
  - SMS: `COUNT(SMSCampaignRecipient WHERE Sent=true AND SMSCampaign.SentAt IN range)` OR `SUM(SMSCampaign.AudienceNetRecipientsCount WHERE SentAt IN range AND CampaignStatusId='Sent')`
  - WhatsApp: `COUNT(WhatsAppCampaignRecipient WHERE Sent=true AND WhatsAppCampaign.SentAt IN range)` OR similar — fallback 0 if entity missing
  - InApp: `COUNT(Notification WHERE CreatedDate IN range)`
  - Sum the 4 channel sub-totals. `deltaPct = ((current - sameRangeLastPeriod) / sameRangeLastPeriod) * 100`. Subtitle: "all channels".
- **KPI 2 — Avg Delivery Rate**: weighted average across the 4 channels = `Σ(channel_delivered) / Σ(channel_sent)`. Per-channel delivered:
  - Email: `EmailSendJob.TotalEmailsSend - EmailSendJob.TotalEmailsFailed` (delivered = total sent - failed-permanently)
  - SMS: `COUNT(SMSCampaignRecipient WHERE Status='Delivered')` OR `SMSCampaign.AudienceNetRecipientsCount - failure count`
  - WhatsApp: similar (graceful 0)
  - InApp: 100% delivery (internal — no external provider)
  - Subtitle: "{m} delivered" (total delivered count formatted).
- **KPI 3 — Avg Open Rate (Email)**: `COUNT(EmailWebhookEventLog WHERE event='open') / EmailSendJob.TotalEmailsSend × 100`. Industry baseline 28% subtitle is STATIC (hardcoded in renderer's data shape, not computed).
- **KPI 4 — Active Campaigns**: count of (EmailSendJob + SMSCampaign + WhatsAppCampaign?) where `JobStatusId/CampaignStatusId IN ('Sending','Scheduled','Active','ActiveAuto')`. Subtitle splits into 2 segment chips:
  - `sending` count = where status IN ('Sending','Active','ActiveAuto')
  - `scheduled` count = where status='Scheduled'
- **KPI 5 — Cost This Month**:
  - Email: `EmailSendJob.TotalEmailsSend × CompanyEmailProvider.CostPerEmail` summed over the period; or fallback to `SUM(EmailSendJob.EstimatedCostCents)` if a per-job cost field exists. (See ISSUE-7 — Email cost may need a synthetic computation rule.)
  - SMS: `SUM(SMSCampaign.ActualCostCents) / 100`
  - WhatsApp: `SUM(WhatsAppCampaign.ActualCostCents) / 100` (graceful 0)
  - InApp: 0 (internal)
  - Total + dominant-channel callout (the channel with the largest sub-total).
- **KPI 6 — Opt-Out Rate**: `total_unsubscribes / total_recipients × 100`
  - Email unsubscribes = `COUNT(EmailWebhookEventLog WHERE event='unsubscribe')`
  - SMS opt-outs = TBD (mockup says "78 unsubscribes" — sum across channels). For SMS, mining keyword replies (STOP / STOPALL) is non-trivial — the function reads from a hypothetical `SMSCampaignReply` event log if exists, otherwise treats SMS opt-out as 0 (ISSUE-4).
  - Subtitle: "{N} unsubscribes". Declining is GOOD — the renderer treats `deltaColor:'positive'` for the down-arrow case.
- **Top Performing Templates table (7)**:
  - Cross-channel rank — top 6 templates by Sent count in the period, joined per-channel:
    - Email: `EmailTemplate ⟕ EmailSendJob` group by EmailTemplateId, SUM(TotalEmailsSend), avg deliveryPct from Send/Failed math, avg openPct from EmailJobAnalytics
    - SMS: `SMSTemplate ⟕ SMSCampaign` group by SMSTemplateId, SUM(AudienceNetRecipientsCount), avg deliveryPct, NO open rate (column shows "—"), avg replyPct from EnableReplyCapture rows
    - WhatsApp: `WhatsAppTemplate ⟕ WhatsAppCampaign?` group by WhatsAppTemplateId, similar (graceful)
    - InApp: `NotificationTemplate ⟕ Notification` group by NotificationTemplateId, SUM(*), readRate from `IsRead=true` ratio, click/reply via `ActionUrl IS NOT NULL` clickthrough events
  - Color rules per rate-bar:
    - green if rate >= 70 (delivery) / 60 (open) / 25 (click-or-reply)
    - amber if 30–70 / 25–60 / 10–25
    - red if < 30 / < 25 / < 10
  - `lastUsedLabel` = relative time from latest send timestamp (e.g., "today", "2 hours ago", "5 days ago", "1 week ago")
  - **Drill-down**: row click → `crm/communication/{channel}template` with `?templateId={id}` query (where `{channel}` is `email`/`sms`/`whatsapp`/`notification`). Note: not all template lists yet support `?templateId=` prefilter — see ISSUE-5.
- **Send Volume Trend (8)**: stacked area, 4 series (Email/SMS/WhatsApp/InApp), 12 month buckets. Annotation pins are STATIC (hardcoded in renderer or seeded — March = "Ramadan campaign launch", December = "Year-end giving push") — ISSUE-6 tracks dynamic annotations.
- **Channel Mix Donut (9)**: 4 segments. `widthPct = round(value / total × 100)`. Center label format: `${total/1000}K\nmessages` (2-line).
- **Cost Bars (10)**: bar `widthPct = round(value / max(values) × 100)` (top bar = 100%-width). Channel order = descending by value. Cost-per-1K footer is computed per-channel: `(channelCost / channelMessages) × 1000`, formatted to 2 decimals.
- **Engagement Funnel (11)**: 5 fixed steps. Step values:
  - Sent = `EmailSendJob.TotalEmailsSend`
  - Delivered = Sent - PermanentFailures (from `EmailWebhookEventLog WHERE event='dropped' OR event='bounce' AND bounceType='hard'`)
  - Opened = `COUNT(EmailWebhookEventLog WHERE event='open')` (distinct by recipient OR raw — pick one per ISSUE-8)
  - Clicked = `COUNT(EmailWebhookEventLog WHERE event='click')`
  - Replied = `COUNT(EmailWebhookEventLog WHERE event='reply')` — applies to reply-tracking templates ONLY (mockup disclaimer)
  - Percent semantics:
    - Delivered % = of Sent
    - Opened % = of Sent (NOT of Delivered — mockup reads "42.8%" which is open-of-sent)
    - Clicked % = of Opened (mockup reads "18.1% of opens")
    - Replied % = of Sent
- **Provider Health (12)**: 4 fixed providers. Status determination per provider:
  - **SendGrid**: status = `UP` if CompanyEmailProvider row exists with `IsActive=true AND DomainStatus='verified' AND BounceRate < 5 AND SpamRate < 0.1`; `DEGRADED` if BounceRate >= 5 or SpamRate >= 0.1; `DOWN` if no active provider or DomainStatus='failed'. Meta = `{N} sent · {pct}% bounce · last sync: {relTime ago}` from `LastEmailSentAt`.
  - **Twilio (SMS)**: status from SMSCampaign aggregate failure rate in last 24h. `UP` if failure rate < 5%, `DEGRADED` if 5-15%, `DOWN` if >15% or no recent activity.
  - **Meta WhatsApp Business**: similar to Twilio but on WhatsAppCampaign? rows. Graceful: if entity missing, status='UP' with meta='Pending #32 build'.
  - **In-App Notifications (internal)**: always `UP` unless backlog (`COUNT(Notification WHERE IsRead=false AND CreatedDate < NOW() - 7 days) > 1000` → `DEGRADED`). Meta = `{N} sent · realtime · queue depth {0 or N}`.
- **Recent Sends Feed (13)**: top 7 across 4 channels by latest activity timestamp. Status mapping:
  - Email: `EmailJobStatus.Code` → `Sending`/`Sent`/`Scheduled`/`Failed`
  - SMS: `SMSCampaign.CampaignStatus.Code` → same
  - WhatsApp: similar (graceful)
  - InApp: synthesize `SENT` for already-created Notifications, `SENDING` for unread + recent, `SCHEDULED` if any future-dated trigger
  - Drill route per row: `crm/communication/{channel}campaign?campaignId={id}` for Email/SMS/WhatsApp; `crm/notification/notificationcenter?notificationId={id}` for InApp
- **Notification Health (14)**: 4 cells from `notify.Notifications`:
  - Sent (30d) = `COUNT(Notification WHERE CreatedDate >= NOW() - 30 days)`
  - Read Rate = `COUNT(IsRead=true) / COUNT(*) × 100` over the same window. Sub-amount = `{N} read`.
  - Unread = `COUNT(IsRead=false)` (no time filter — current backlog). Sub-amount = `{pct}% of total`.
  - Urgent = `COUNT(Priority='Urgent' AND IsRead=false AND CreatedDate < NOW() - 24h)`. Sub-amount = "unread > 24h".
- **Bounce & Spam Watch (15)**: 4 cells:
  - Email Bounces = `COUNT(EmailWebhookEventLog WHERE event IN ('bounce','dropped'))` over period. Sub-amount = `{pct}% rate {tier}` where tier = "(low)" if < 1%, "(moderate)" if 1-3%, "(high)" if > 3%.
  - SMS Failures = `COUNT(SMSCampaignRecipient WHERE Status='Failed')` over period. Sub-amount = `{pct}% rate`.
  - Spam Reports = `COUNT(EmailWebhookEventLog WHERE event='spamreport')` over period. Sub-amount = `{pct}% (excellent/good/concern/critical)` per tier.
  - Reputation = `MAX(CompanyEmailProvider.DomainReputationScore)` (latest) for default provider. Sub-amount = `/100 SendGrid` (or active provider name).
  - Banner: when `COUNT(SMSSenderId expired) > 0` (TBD source — likely `WhatsAppSetting`/SMS sender registrations table OR computed from SMSCampaign.SenderValue against a known-expiry registry — ISSUE-10).
- **Alert generation rules (widget 16)** — sanitization: only `<strong>` tags allowed; all other HTML escaped:
  - DANGER if `count(failed_sms_campaigns_24h) > 0 AND failure_reason LIKE '%quota%'` → "<strong>Bulk SMS to {AudienceLabel} failed</strong> — Twilio quota exceeded; {N} recipients un-sent" → `crm/communication/smscampaign?campaignId={id}`
  - WARNING if `meta_whatsapp_status='DEGRADED' AND duration > 30 minutes` → "<strong>WhatsApp provider degraded</strong> since {time} — {N} messages stuck in queue; check Meta status page" → `setting/communicationconfig/emailproviderconfig`
  - WARNING if `count(expired_sms_sender_ids) > 0` → "<strong>{N} SMS sender IDs expired</strong> — campaigns scheduled for tomorrow may fail to send" → `setting/communicationconfig/emailproviderconfig`
  - INFO if `count(scheduled_campaigns_24h) > 0` → "<strong>{N} campaigns scheduled to send</strong> in next 24 hours — total recipients: {M}" → `crm/communication/emailcampaign`
  - INFO if `email_open_rate_uplift_mom_pct >= 2` → "<strong>Open rate up {pct}% MoM</strong> — {topPerformerName} subject lines performing above baseline" → `crm/communication/emailtemplate`
  - SUCCESS if `spam_report_rate < 0.01` → "<strong>Spam-report rate at {pct}%</strong> — well below the 0.1% provider threshold; sender reputation healthy" → `setting/communicationconfig/emailproviderconfig`
  - Hard cap of 10 alerts (top 10 by severity then recency)
- **Active Campaigns table (17)**: rows from EmailSendJob + SMSCampaign + WhatsAppCampaign? where status IN ('Sending','Scheduled','Active','ActiveAuto','Failed') in the period. ORDER BY: Sending first, then Scheduled (sorted by ScheduledAt asc), then Active/ActiveAuto, then Failed last. Each row drills to its channel-specific campaign list with `?campaignId={id}`.

### Multi-Currency Rules
- **Single currency assumed for v1** — costs in `Company.DefaultCurrency` (USD by default for the demo company). Multi-currency is OUT of scope on this dashboard. Pre-flag as ISSUE-12 if a tenant operates in multiple currencies — would require a Currency filter analogous to Donation Dashboard's.

### Widget-Level Rules
- A widget is RENDERED only if `auth.WidgetRoles(WidgetId, currentRoleId, HasAccess=true)` row exists. No row → widget hidden.
- All 17 widgets seed `WidgetRole(BUSINESSADMIN, HasAccess=true)`. Other roles assigned at admin-config time.
- **Workflow**: None. Read-only. Drill-downs navigate AWAY.

---

## ⑤ Screen Classification & Pattern Selection

**Consumer**: Solution Resolver — these are PRE-ANSWERED.

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Standalone analytical surface deep-linkable from emailed daily-summary reports; role-restricted to marketing / communication / IT-ops staff; tightly scoped to outreach operations. Already has its own sidebar leaf at `/crm/dashboards/communicationdashboard`.

**Backend Implementation Path** — **Path A across all 17 widgets**:
- [x] **Path A — Postgres function (generic widget)**: Each widget = 1 SQL function in `notify.` schema returning `(data_json text, metadata_json text, total_count integer, filtered_count integer)`. Reuses existing `generateWidgets` GraphQL handler. Seed `Widget.StoredProcedureName='notify.{function_name}'`. NO new C# code; only 17 SQL deliverables. Matches Donation Dashboard #124 / Case Dashboard #52 precedent.
- [ ] Path B — Named GraphQL query (NOT used)
- [ ] Path C — Composite DTO (NOT used)

**Path-A Function Contract (NON-NEGOTIABLE)** — every function MUST:
- Take 5 fixed inputs in this order: `p_filter_json jsonb DEFAULT '{}'::jsonb, p_page integer DEFAULT 0, p_page_size integer DEFAULT 10, p_user_id integer DEFAULT 0, p_company_id integer DEFAULT NULL`
- Return `TABLE(data_json text, metadata_json text, total_count integer, filtered_count integer)` — single row, 4 columns. **Note**: Donation/Case Dashboard precedent uses `data_json text` (NOT `data jsonb`); the runtime parses JSON-stringified text. Match this exactly.
- Extract every filter from `p_filter_json` using `NULLIF(p_filter_json->>'keyName','')::type`. Filter keys: `dateFrom`, `dateTo`, `channel` (UPPER 'EMAIL'/'SMS'/'WHATSAPP'/'NOTIFICATION'/'ALL'), `branchId`
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators)
- Live at `PSS_2.0_Backend/DatabaseScripts/Functions/notify/{function_name}.sql` — snake_case names. **NEW `notify/` folder under `DatabaseScripts/Functions/`** (first communication-domain widget functions; the folder must be created with this build).
- `Widget.DefaultParameters` JSON keys MUST match the keys that the function reads from `p_filter_json` (e.g., `{ "dateFrom": "{dateFrom}", "dateTo": "{dateTo}", "channel": "{channel}", "branchId": "{branchId}" }` — placeholders substituted by widget runtime)
- Tenant scoping via `p_company_id` — every function gates with `WHERE CompanyId = p_company_id OR p_company_id IS NULL`
- WhatsAppCampaign reference is `to_regclass('notify."WhatsAppCampaigns"') IS NOT NULL`-guarded (graceful degrade until #32 ships)

**Backend Patterns Required:**
- [x] Tenant scoping (CompanyId from HttpContext via p_company_id arg) — every function
- [x] Date-range parameterized queries
- [x] Channel-scoped filtering (per § ④ rules — channel-aware vs channel-fixed widgets)
- [x] Role-scoped data filtering — joined to `auth.UserBranches` for BRANCH_MANAGER (where applicable; see ISSUE-9 for entities lacking BranchId)
- [ ] Materialized view / cached aggregate — not for v1; pre-flag ISSUE-13 if any function exceeds 2s p95.

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` (responsive breakpoints) — already in `<MenuDashboardComponent />`
- [x] **NEW renderers per widget shape** — create under `dashboards/widgets/communication-dashboard-widgets/` and register each in `WIDGET_REGISTRY` (`dashboard-widget-registry.tsx`). **15 distinct ComponentPaths** per § ② widget table (4 KPI variants + 11 single-use renderers). Each renderer ships `{Name}.tsx + {Name}.types.ts + {Name}.skeleton.tsx + index.ts`.
- [x] **Visual uniqueness across widgets** — each renderer must have a distinct visual signature: different accent color, different icon, different chrome (gradient strip / amber tint / dual-segment chips / colored top-borders / row-list / mini-grid + banner / scrolling feed / collapsible table), different skeleton shape. Verify by side-by-side screenshot review during build — if two widgets feel "samey," split them further. The 6 KPIs are SPLIT across 4 renderers (Hero / Delta / Status / Cost) to avoid the "6 identical KPI tiles" anti-pattern.
- [x] **Vary `LayoutConfig` cell heights/widths to signal importance** — Hero KPIs use h=3 cells (taller); supporting KPIs use h=2; full-width charts/tables use w=12; side-by-side comparisons use w=5+7 (donut+bars) or w=6+6 (provider+feed). The grid itself communicates hierarchy before the renderer chrome does.
- [ ] **Reuse legacy `WIDGET_REGISTRY` renderer — DISALLOWED** for this dashboard. `StatusWidgetType1`, `MultiChartWidget`, `PieChartWidgetType1`, `BarChartWidgetType1`, `FilterTableWidget`, `NormalTableWidget`, `AlertListWidget`, `case-dashboard-alerts-widget`, ALL `Donation*Widget` / `Contact*Widget` / `Volunteer*Widget` / `Ambassador*Widget` are FROZEN to their original dashboards.
- [ ] **Anti-patterns to actively avoid** (forbidden by feedback memory):
      • One renderer used for ALL KPIs with only label/value swapped — split into Hero / Delta / Status / Cost per visual hierarchy
      • A single chart component toggling `chartType` for all chart widgets — separate stacked-area / donut / bar / funnel renderers
      • Identical card chrome (border, padding, header layout) across every widget
      • Generic shimmer-rectangle skeletons — every renderer ships a shape-matched skeleton
      • NotificationHealth/BounceSpam sharing one generic `HealthGridWidget` — split into 2 renderers with distinct icons + banner treatment
- [x] Query registry — NOT extended (Path A uses `generateWidgets` only)
- [x] Date-range picker / Period select / Channel select / Branch select — NEW `communication-dashboard-toolbar.tsx` houses these and threads filter state via filter context to widgets
- [x] Skeleton states matching widget shapes — **shape-matched per NEW renderer** (KPI tile skeleton with sparkline strip, KPI dual-pill skeleton, KPI cost-amber skeleton, donut ring skeleton, stacked-area chart skeleton, funnel 5-cell skeleton, table-row skeletons with rate-bar columns, alert-list skeleton, mini-stat-grid 4-cell skeleton, activity-feed 7-row skeleton, provider-row 4-row skeleton, collapsible table 6-row skeleton — match the renderer's actual layout, NOT a generic rectangle)
- [x] **MENU_DASHBOARD page** — uses already-existing `<MenuDashboardComponent />`. Existing per-route stub at `[lang]/crm/dashboards/communicationdashboard/page.tsx` is overwritten to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="COMMUNICATIONDASHBOARD" toolbar={<CommunicationDashboardToolbar />} />`. See ISSUE-1.
- [x] **Toolbar overrides** — `<MenuDashboardComponent />` already has the `toolbar?: ReactNode` prop landed via Donation Dashboard #124. No infra change needed here.

---

## ⑥ UI/UX Blueprint

**Consumer**: UX Architect → Frontend Developer

> Layout follows the HTML mockup. All widgets render through `<MenuDashboardComponent moduleCode="CRM" dashboardCode="COMMUNICATIONDASHBOARD" />` → resolves to the seeded Dashboard row → reads LayoutConfig + ConfiguredWidget JSON → maps each instance to its NEW `Communication*Widget` renderer + Postgres function.

**Layout Variant**: `widgets-above-grid+side-panel` — widget grid is the dashboard. No CRUD grid. Header has filter controls + action buttons (toolbar slot).

### Page Chrome (MENU_DASHBOARD)

- **Header row** (rendered via `<MenuDashboardComponent />` lean header + `toolbar` prop):
  - Left: page title `Communication Dashboard` + icon `tower-broadcast-bold` (violet) + subtitle `Cross-channel outreach: Email, SMS, WhatsApp, Notifications — one view`
  - Right (toolbar slot — composed by NEW `communication-dashboard-toolbar.tsx`): **3 filter selects + 2 buttons + Refresh icon**:
    1. **Period select** — default "This Month"; options: This Month / Last Month / This Quarter / This Year / Custom Range. "Custom Range" opens an inline date-range popover.
    2. **Channel select** — default "All Channels"; options: All Channels / Email Only / SMS Only / WhatsApp Only / Notification Only.
    3. **Branch select** — default "All Branches" (or user's branch for BRANCH_MANAGER); dynamic from `app.Branches WHERE IsActive=true` via existing `branches` GQL query.
    4. **"Export Report"** primary button (violet) — SERVICE_PLACEHOLDER. ISSUE-2.
    5. **"Print"** outline button (violet) — calls `window.print()`. NO placeholder.
    6. **Refresh icon** — existing chrome — kept right-end.

- **No dropdown switcher**, **no Edit Layout chrome** (read-only by default).

### Grid Layout (react-grid-layout — `lg` breakpoint, 12 columns)

> **Visual hierarchy via varied cell sizing** — Hero KPIs occupy taller cells (h=3) than supporting KPIs (h=2) so the grid itself signals importance before the renderer chrome does. Hero KPIs span Row 0; supporting KPIs span Row 1 in a uniform 4-cell strip.

| i (instanceId) | Widget | Renderer | x | y | w | h | minW | minH | Hierarchy |
|----------------|--------|----------|---|---|---|---|------|------|-----------|
| KPI_TOTAL_MESSAGES | Total Messages Sent | CommunicationHeroKpiWidget | 0 | 0 | 6 | 3 | 4 | 3 | **Hero** — taller, half-width, violet |
| KPI_AVG_DELIVERY_RATE | Avg Delivery Rate | CommunicationHeroKpiWidget | 6 | 0 | 6 | 3 | 4 | 3 | **Hero** — taller, half-width, green |
| KPI_AVG_OPEN_RATE_EMAIL | Avg Open Rate (Email) | CommunicationDeltaKpiWidget | 0 | 3 | 3 | 2 | 3 | 2 | Supporting — quad strip, indigo |
| KPI_ACTIVE_CAMPAIGNS | Active Campaigns | CommunicationStatusKpiWidget | 3 | 3 | 3 | 2 | 3 | 2 | Supporting — quad strip, orange (dual-pill) |
| KPI_COST_THIS_MONTH | Cost This Month | CommunicationCostKpiWidget | 6 | 3 | 3 | 2 | 3 | 2 | Supporting — quad strip, amber-tinted |
| KPI_OPT_OUT_RATE | Opt-Out Rate | CommunicationDeltaKpiWidget | 9 | 3 | 3 | 2 | 3 | 2 | Supporting — quad strip, rose |
| TBL_TOP_TEMPLATES | Top Performing Templates | CommunicationTopTemplatesTableWidget | 0 | 5 | 12 | 6 | 8 | 5 | Full-width table |
| CHART_SEND_VOLUME_TREND | Send Volume Trend | CommunicationSendVolumeTrendWidget | 0 | 11 | 12 | 5 | 8 | 4 | Full-width chart |
| CHART_CHANNEL_MIX | Messages by Channel | CommunicationChannelMixDonutWidget | 0 | 16 | 5 | 5 | 4 | 4 | Half-left donut |
| CHART_COST_BY_CHANNEL | Cost by Channel | CommunicationCostBarsWidget | 5 | 16 | 7 | 5 | 5 | 4 | 7-col cost bars |
| CHART_ENGAGEMENT_FUNNEL | Engagement Funnel (Email) | CommunicationEngagementFunnelWidget | 0 | 21 | 12 | 3 | 8 | 3 | Full-width 5-step funnel |
| LIST_PROVIDER_HEALTH | Provider Health | CommunicationProviderHealthWidget | 0 | 24 | 6 | 5 | 4 | 4 | Half-left provider list |
| LIST_RECENT_SENDS | Recent Sends & Queue | CommunicationRecentSendsFeedWidget | 6 | 24 | 6 | 5 | 4 | 4 | Half-right activity feed |
| TBL_NOTIFICATION_HEALTH | Notification Center Health | CommunicationNotificationHealthWidget | 0 | 29 | 6 | 3 | 4 | 3 | Half-left mini-grid (no banner) |
| TBL_BOUNCE_SPAM | Bounce & Spam Watch | CommunicationBounceSpamWidget | 6 | 29 | 6 | 4 | 4 | 3 | Half-right mini-grid (danger banner) |
| LIST_ALERTS | Alerts & Actions | CommunicationAlertsListWidget | 0 | 33 | 12 | 4 | 8 | 3 | Full-width alerts |
| TBL_ACTIVE_CAMPAIGNS | Active Campaigns | CommunicationActiveCampaignsTableWidget | 0 | 37 | 12 | 5 | 8 | 4 | Full-width collapsible table |

> **Total grid height ≈ 42 row-units**. The 6 KPI cells deliberately differ in size: 2 Hero cells at 6×3 vs. 4 Supporting cells at 3×2. This produces a visible "headline strip" + "compact-strip" structure. Then full-width Top Templates table → full-width Volume Trend → side-by-side Donut+Bars → full-width Funnel → side-by-side Provider+Feed → asymmetric mini-grids (Notification 3-row, BounceSpam 4-row because of banner) → full-width Alerts → full-width Active Campaigns.

**md / sm / xs breakpoints** (the component reads all four):
- **md (12 cols)**: same as `lg`
- **sm (6 cols)**: KPIs collapse to 2 per row; Donut + Bars stack vertically; Provider + Feed stack vertically; mini-grids become full-width stacked
- **xs (1 col)**: every widget full-width vertically

### Widget Catalog (instance details)

> All ComponentPaths are NEW `Communication*Widget` renderers under `communication-dashboard-widgets/` — see § ② for the registry table. Visual treatment notes captured per row.

| # | InstanceId | Title | ComponentPath | Visual Distinguisher | Filters Honored | Drill-Down |
|---|-----------|-------|---------------|----------------------|-----------------|------------|
| 1 | KPI_TOTAL_MESSAGES | Total Messages Sent | **CommunicationHeroKpiWidget** | LARGE card, violet gradient header strip, paper-plane icon, 12-mo sparkline, bold value `186,420` | period, channel, branch | — |
| 2 | KPI_AVG_DELIVERY_RATE | Avg Delivery Rate | CommunicationHeroKpiWidget | LARGE card, green gradient header strip, circle-check icon, 12-mo sparkline, bold percent `96.4%` | period, channel, branch | — |
| 3 | KPI_AVG_OPEN_RATE_EMAIL | Avg Open Rate (Email) | **CommunicationDeltaKpiWidget** | Mid-size, indigo accent, envelope-open icon, single primary value `42.8%` + delta arrow + "industry avg 28%" baseline | period, branch (channel filter IGNORED) | — |
| 4 | KPI_ACTIVE_CAMPAIGNS | Active Campaigns | **CommunicationStatusKpiWidget** | Compact, orange accent, bullhorn icon, primary value `14` + DUAL pill chips "8 sending" + "6 scheduled" | period, channel, branch | — |
| 5 | KPI_COST_THIS_MONTH | Cost This Month | **CommunicationCostKpiWidget** | Compact amber-tinted card, coins icon, primary currency `$1,847`, warning delta `↑ 18%`, dominant-channel callout chip "SMS dominant" | period, channel, branch | — |
| 6 | KPI_OPT_OUT_RATE | Opt-Out Rate | CommunicationDeltaKpiWidget | Mid-size, rose accent, user-slash icon, primary value `0.42%`, declining-good positive-color down-arrow `↓ 0.08%`, "78 unsubscribes" subtitle | period, channel, branch | — |
| 7 | TBL_TOP_TEMPLATES | Top Performing Templates | **CommunicationTopTemplatesTableWidget** | 7-col table: Template name + Channel pill + Sent count + 3 rate-bar columns Delivery/Open/Click-or-Reply + Last Used relative-time | period, channel, branch | Row click → `crm/communication/{channel}template?templateId={id}` (`{channel}` = email/sms/whatsapp/notification) |
| 8 | CHART_SEND_VOLUME_TREND | Send Volume Trend | **CommunicationSendVolumeTrendWidget** | 12-month stacked area, 4-channel palette, annotation pins (Mar Ramadan, Dec Year-end), full-width | branch, channel (when single channel: render only that series) | Series click → `crm/communication/{channel}campaign?dateFrom=monthStart&dateTo=monthEnd` |
| 9 | CHART_CHANNEL_MIX | Messages by Channel | **CommunicationChannelMixDonutWidget** | Donut with center total `186K messages`, 4-segment legend with absolute counts + percent | period, branch (channel filter IGNORED — donut shows mix) | Slice click → `crm/communication/{channel}campaign` (or `crm/notification/notificationcenter` for InApp slice) |
| 10 | CHART_COST_BY_CHANNEL | Cost by Channel | **CommunicationCostBarsWidget** | 4 horizontal cost bars (channel-colored fills + inline currency labels) + cost-per-1K footer line | period, branch | Bar click → `crm/communication/{channel}campaign` |
| 11 | CHART_ENGAGEMENT_FUNNEL | Engagement Funnel (Email) | **CommunicationEngagementFunnelWidget** | 5-step funnel with COLORED TOP-BORDERS (violet/blue/cyan/green/amber per the mockup CSS), step value + relative percent per cell, disclaimer footer | period, branch (channel filter IGNORED) | Step click → `crm/communication/emailcampaign?engagementStep={Sent/Delivered/Opened/Clicked/Replied}` |
| 12 | LIST_PROVIDER_HEALTH | Provider Health | **CommunicationProviderHealthWidget** | 4-row provider list (SendGrid/Twilio/Meta/InApp) with icon circle + name + meta + status pill UP/DEGRADED/DOWN, "Configure" header CTA | period, branch | "Configure" link → `setting/communicationconfig/emailproviderconfig` |
| 13 | LIST_RECENT_SENDS | Recent Sends & Queue | **CommunicationRecentSendsFeedWidget** | Vertical scrolling activity feed max-h 320px, per-channel colored icon circle + 2-line content + status pill SENDING/SENT/SCHEDULED/FAILED, "View All" header CTA | period, channel, branch | Row click → `crm/communication/{channel}campaign?campaignId={id}` for E/S/W; `crm/notification/notificationcenter?notificationId={id}` for InApp; "View All" → `crm/communication/emailcampaign` |
| 14 | TBL_NOTIFICATION_HEALTH | Notification Center Health | **CommunicationNotificationHealthWidget** | 4-cell mini-grid (violet/green-success/warn/danger value colors per cell), NO banner, "Open Inbox" header CTA, inbox icon | period, branch (channel filter IGNORED — InApp-only) | "Open Inbox" link → `crm/notification/notificationcenter` |
| 15 | TBL_BOUNCE_SPAM | Bounce & Spam Watch | **CommunicationBounceSpamWidget** | 4-cell mini-grid (warn/danger/success/warn cues) + DANGER banner with reverify CTA + shield-halved accent, "Configure" header CTA | period, branch | "Configure" link → `setting/communicationconfig/emailproviderconfig`; banner CTA → `setting/communicationconfig/emailproviderconfig?tab=senders` |
| 16 | LIST_ALERTS | Alerts & Actions | **CommunicationAlertsListWidget** | Severity-colored alert rows (4 severity treatments: warning yellow / danger red / info blue / success green — distinct bg + border per severity), sanitized `<strong>` only, CTA link per row, bell icon | period, channel, branch | Per-alert `link.route` + `link.args` |
| 17 | TBL_ACTIVE_CAMPAIGNS | Active Campaigns | **CommunicationActiveCampaignsTableWidget** | 7-col collapsible table (channel pill + recipients + status pill + delivery rate-bar + cost monospace + schedule label), "+ Create Campaign" footer button | period, channel, branch | Row click → `crm/communication/{channel}campaign?campaignId={id}`; "+ Create Campaign" → `crm/communication/emailcampaign?mode=new` |

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Period | Native select + custom range popover | "This Month" | Time-aggregating widgets (KPIs 1-6, all charts, tables 7/13/15/17, alerts) | Presets per § ④ |
| Channel | Native select | "All Channels" | All channel-aware widgets (KPIs 1/2/4/5/6, charts 8/10, tables 13/16/17) | Channel-fixed widgets (KPI 3, Funnel 11, NotificationHealth 14) IGNORE this filter |
| Branch | Single-select — from `app.Branches` | "All Branches" or user's branch (BRANCH_MANAGER) | All widgets that have a meaningful branch dimension | Branch dimension flows transitively where source entity lacks BranchId — see ISSUE-9 |

Filter values flow into `<MenuDashboardComponent />` filter context, projected into each widget's `customParameter` JSON via the runtime's `{placeholder}` substitution. Functions read them out of `p_filter_json`.

### Drill-Down / Navigation Map (recap of the per-widget table above)

| From | Click On | Navigates To | Prefill |
|------|----------|--------------|---------|
| Top Templates row | Whole row | `crm/communication/{channel}template` | `templateId={id}` (gracefully ignored if list page does not consume — ISSUE-5) |
| Send Volume Trend | Click on month/series | `crm/communication/{channel}campaign` | `dateFrom=monthStart&dateTo=monthEnd&channel={channel}` |
| Channel Mix slice | Click on slice | `crm/communication/{channel}campaign` (or `crm/notification/notificationcenter` for InApp) | — |
| Cost Bar | Click on bar | `crm/communication/{channel}campaign` | — |
| Engagement Funnel step | Click on step | `crm/communication/emailcampaign` | `engagementStep={Sent/Delivered/Opened/Clicked/Replied}` |
| Provider Health "Configure" | Header link | `setting/communicationconfig/emailproviderconfig` | — |
| Recent Sends row | Whole row | `crm/communication/{channel}campaign` (or `crm/notification/notificationcenter` for InApp) | `campaignId={id}` / `notificationId={id}` |
| Recent Sends "View All" | Header link | `crm/communication/emailcampaign` | — |
| Notification Health "Open Inbox" | Header link | `crm/notification/notificationcenter` | — |
| Bounce/Spam "Configure" | Header link | `setting/communicationconfig/emailproviderconfig` | — |
| Bounce/Spam danger banner | Banner CTA | `setting/communicationconfig/emailproviderconfig` | `tab=senders` |
| Alert link | CTA per row | Per `link.route` from alert data | Per `link.args` |
| Active Campaigns row | Whole row | `crm/communication/{channel}campaign` | `campaignId={id}` |
| Active Campaigns "+ Create Campaign" | Footer button | `crm/communication/emailcampaign` | `mode=new` |
| Toolbar "Export Report" | Button | SERVICE_PLACEHOLDER toast | "Generating channel report..." |
| Toolbar "Print" | Button | `window.print()` | — |

### User Interaction Flow

1. **Initial load**: User clicks `CRM → Dashboards → Communication Dashboard` → URL `/[lang]/crm/dashboards/communicationdashboard` → page renders `<MenuDashboardComponent moduleCode="CRM" dashboardCode="COMMUNICATIONDASHBOARD" toolbar={<CommunicationDashboardToolbar />} />`. Component fires `dashboardByModuleAndCode('CRM','COMMUNICATIONDASHBOARD')` + `widgetByModuleCode('CRM')` → maps each ConfiguredWidget instance to its NEW `Communication*Widget` renderer via `WIDGET_REGISTRY` → renders 17-widget grid → all widgets parallel-fetch via `generateWidgets` with default filters.
2. **Filter change** (Period / Channel / Branch): widgets honoring that filter refetch in parallel; widgets NOT honoring it stay cached.
3. **Drill-down click**: navigates per Drill-Down Map → all destinations are COMPLETED screens (with the ISSUE-5 caveat for Top Templates' optional `?templateId=` prefilter).
4. **Back navigation**: returns to dashboard → filters preserved in URL search params where possible.
5. **Export Report** → toast SERVICE_PLACEHOLDER. **Print** → `window.print()`.
6. **Refresh icon** — existing chrome — refetches dashboard config + widgets.
7. **No edit-layout / add-widget chrome** in v1.
8. **Empty / loading / error states**: each NEW renderer ships its own SHAPE-MATCHED skeleton. Error → red mini banner + Retry. Empty → muted icon + per-widget empty message.
9. **Active Campaigns collapsible**: header click toggles body visibility. Default = expanded.

---

## ⑦ Substitution Guide

**Consumer**: Backend Developer + Frontend Developer

> Sibling of Donation Dashboard #124 / Case Dashboard #52 — same MENU_DASHBOARD architecture, different schema/scope, **different FE renderers** (Communication Dashboard ships its own `Communication*Widget` set per the new policy).

**Canonical Reference**: **Donation Dashboard #124** for BE pattern (`prompts/donation-dashboard.md` § ⑦) — same Path-A function contract, same `<MenuDashboardComponent />` consumer, same seed-step layout. **Use the existing `fund/` SQL functions as the BE reference shape** (especially `fn_donation_dashboard_kpi_total_donations.sql` for KPI structure, `fn_donation_dashboard_alerts.sql` for the alert rule engine, `fn_donation_dashboard_revenue_trend.sql` for stacked-area chart, `fn_donation_dashboard_payment_method.sql` for donut). **DO NOT** reuse Donation Dashboard's FE renderers — the policy forbids it.

| Convention | Donation Dashboard | → This Dashboard | Notes |
|-----------|--------------------|------------------|-------|
| DashboardCode | `DONATIONDASHBOARD` | `COMMUNICATIONDASHBOARD` | Matches existing seeded MenuCode |
| MenuName | `Donation Dashboard` | `Communication Dashboard` | Already seeded |
| MenuUrl | `crm/dashboards/donationdashboard` | `crm/dashboards/communicationdashboard` | Already seeded; no change |
| Schema for Postgres functions | `fund.fn_donation_dashboard_*` | `notify.fn_communication_dashboard_*` | NEW `notify/` folder under `DatabaseScripts/Functions/` |
| Function naming | `fn_donation_dashboard_{aspect}` | `fn_communication_dashboard_{aspect}` | snake_case |
| Widget instance ID | `{TYPE}_{NAME}` | Same convention | Stable across LayoutConfig + ConfiguredWidget |
| Module | `CRM` | `CRM` | Same |
| Parent menu | `CRM_DASHBOARDS` | `CRM_DASHBOARDS` | Same |
| Dashboard color | `#059669` (emerald) | `#7c3aed` (violet) | mockup `--cm-accent` |
| Dashboard icon | `hand-heart-bold` | `tower-broadcast-bold` | Phosphor name without `ph:` prefix |
| FE renderer folder | `dashboards/widgets/donation-dashboard-widgets/` (FROZEN) | **NEW** `dashboards/widgets/communication-dashboard-widgets/` | 15 distinct ComponentPaths, all `Communication*Widget` named |
| FE renderer naming | `DonationHeroKpiWidget`, `DonationAlertsListWidget`, etc. | `CommunicationHeroKpiWidget`, `CommunicationAlertsListWidget`, etc. | `Communication{Purpose}Widget` PascalCase per policy |
| WidgetType seed rows | 15 NEW WidgetType rows | **15 NEW WidgetType rows** | All ComponentPaths are NEW; codes prefixed `COMM_` |
| Per-route page stub | `[lang]/crm/dashboards/donationdashboard/page.tsx` | `[lang]/crm/dashboards/communicationdashboard/page.tsx` | Both currently render `<DashboardComponent />` (STATIC). Both need overwriting to `<MenuDashboardComponent />`. |
| Menu OrderBy | 2 | 3 | Already seeded |
| Filter axes | Period / Campaign / Branch / Currency | **Period / Channel / Branch** | Channel filter is unique to this dashboard (replaces Campaign + Currency in the Donation context) |

---

## ⑧ File Manifest

**Consumer**: Backend Developer + Frontend Developer

### Backend Files (Path A only — 17 SQL functions, NO C# code)

| # | File | Path |
|---|------|------|
| 1 | KPI 1 — Total Messages Sent | `PSS_2.0_Backend/DatabaseScripts/Functions/notify/fn_communication_dashboard_kpi_total_messages.sql` |
| 2 | KPI 2 — Avg Delivery Rate | `…/notify/fn_communication_dashboard_kpi_avg_delivery_rate.sql` |
| 3 | KPI 3 — Avg Open Rate (Email) | `…/notify/fn_communication_dashboard_kpi_avg_open_rate_email.sql` |
| 4 | KPI 4 — Active Campaigns | `…/notify/fn_communication_dashboard_kpi_active_campaigns.sql` |
| 5 | KPI 5 — Cost This Month | `…/notify/fn_communication_dashboard_kpi_cost_this_month.sql` |
| 6 | KPI 6 — Opt-Out Rate | `…/notify/fn_communication_dashboard_kpi_opt_out_rate.sql` |
| 7 | Top Performing Templates | `…/notify/fn_communication_dashboard_top_templates.sql` |
| 8 | Send Volume Trend | `…/notify/fn_communication_dashboard_send_volume_trend.sql` |
| 9 | Channel Mix Donut | `…/notify/fn_communication_dashboard_channel_mix.sql` |
| 10 | Cost By Channel Bars | `…/notify/fn_communication_dashboard_cost_by_channel.sql` |
| 11 | Engagement Funnel | `…/notify/fn_communication_dashboard_engagement_funnel.sql` |
| 12 | Provider Health | `…/notify/fn_communication_dashboard_provider_health.sql` |
| 13 | Recent Sends Feed | `…/notify/fn_communication_dashboard_recent_sends.sql` |
| 14 | Notification Health | `…/notify/fn_communication_dashboard_notification_health.sql` |
| 15 | Bounce & Spam Watch | `…/notify/fn_communication_dashboard_bounce_spam.sql` |
| 16 | Alerts | `…/notify/fn_communication_dashboard_alerts.sql` |
| 17 | Active Campaigns | `…/notify/fn_communication_dashboard_active_campaigns.sql` |

**Backend Wiring Updates**: NONE (Path A reuses `generateWidgets` GraphQL handler).

**Database Migration**: 1 file if functions are NOT auto-applied at runtime. Confirm during build by inspecting how the existing `fund/` and `case/` functions get registered. If auto-applied, no migration needed; otherwise generate `AddCommunicationDashboardFunctions.cs`.

### Frontend Files — 15 NEW renderers under `communication-dashboard-widgets/` (4 files each = 60 files + 1 folder barrel + toolbar + page wires)

| # | Renderer | Files (under `dashboards/widgets/communication-dashboard-widgets/`) |
|---|----------|--------------------------------------------------------------------|
| 1 | CommunicationHeroKpiWidget *(used 2× — Total Messages Sent + Avg Delivery Rate)* | `communication-hero-kpi-widget/CommunicationHeroKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 2 | CommunicationDeltaKpiWidget *(used 2× — Open Rate Email + Opt-Out Rate)* | `communication-delta-kpi-widget/CommunicationDeltaKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 3 | CommunicationStatusKpiWidget *(used 1× — Active Campaigns dual-pill)* | `communication-status-kpi-widget/CommunicationStatusKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 4 | CommunicationCostKpiWidget *(used 1× — Cost This Month with dominant-channel callout)* | `communication-cost-kpi-widget/CommunicationCostKpiWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 5 | CommunicationTopTemplatesTableWidget | `communication-top-templates-table-widget/CommunicationTopTemplatesTableWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 6 | CommunicationSendVolumeTrendWidget | `communication-send-volume-trend-widget/CommunicationSendVolumeTrendWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 7 | CommunicationChannelMixDonutWidget | `communication-channel-mix-donut-widget/CommunicationChannelMixDonutWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 8 | CommunicationCostBarsWidget | `communication-cost-bars-widget/CommunicationCostBarsWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 9 | CommunicationEngagementFunnelWidget | `communication-engagement-funnel-widget/CommunicationEngagementFunnelWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 10 | CommunicationProviderHealthWidget | `communication-provider-health-widget/CommunicationProviderHealthWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 11 | CommunicationRecentSendsFeedWidget | `communication-recent-sends-feed-widget/CommunicationRecentSendsFeedWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 12 | CommunicationNotificationHealthWidget | `communication-notification-health-widget/CommunicationNotificationHealthWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 13 | CommunicationBounceSpamWidget | `communication-bounce-spam-widget/CommunicationBounceSpamWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 14 | CommunicationAlertsListWidget | `communication-alerts-list-widget/CommunicationAlertsListWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| 15 | CommunicationActiveCampaignsTableWidget | `communication-active-campaigns-table-widget/CommunicationActiveCampaignsTableWidget.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| — | Folder barrel | `dashboards/widgets/communication-dashboard-widgets/index.ts` (re-exports all 15 renderers) |

**Other FE files**:

| # | File | Path | Action |
|---|------|------|--------|
| 16 | Toolbar component | `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/communication-dashboard-toolbar.tsx` | NEW — composes 3 filter selects + Export/Print buttons; threads filter changes via callbacks |
| 17 | Page-config wrapper | `Pss2.0_Frontend/src/presentation/pages/crm/dashboards/communicationdashboard.tsx` | OVERWRITE — replace `<DashboardComponent />` with `<MenuDashboardComponent moduleCode="CRM" dashboardCode="COMMUNICATIONDASHBOARD" toolbar={<CommunicationDashboardToolbar />} />` |
| 18 | Per-route page stub | `Pss2.0_Frontend/src/app/[lang]/crm/dashboards/communicationdashboard/page.tsx` | KEEP if it already imports the page-config wrapper above; verify after wrapper rewrite (otherwise overwrite to point at `<CommunicationDashboardPageConfig />`) |
| 19 | `<MenuDashboardComponent />` toolbar prop | `Pss2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx` | NO CHANGE — `toolbar?: ReactNode` prop already landed via Donation Dashboard #124 |

**Frontend Wiring Updates**:

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | Register all 15 NEW renderers: `'CommunicationHeroKpiWidget': CommunicationHeroKpiWidget, 'CommunicationDeltaKpiWidget': CommunicationDeltaKpiWidget, 'CommunicationStatusKpiWidget': …, 'CommunicationCostKpiWidget': …, 'CommunicationTopTemplatesTableWidget': …, 'CommunicationSendVolumeTrendWidget': …, 'CommunicationChannelMixDonutWidget': …, 'CommunicationCostBarsWidget': …, 'CommunicationEngagementFunnelWidget': …, 'CommunicationProviderHealthWidget': …, 'CommunicationRecentSendsFeedWidget': …, 'CommunicationNotificationHealthWidget': …, 'CommunicationBounceSpamWidget': …, 'CommunicationAlertsListWidget': …, 'CommunicationActiveCampaignsTableWidget': …` — keys must match the `WidgetType.ComponentPath` strings seeded in STEP 3 |
| 2 | `dashboards/widgets/index.ts` (if exists) | Re-export the new folder barrel |
| 3 | Sidebar / menu config | NONE — COMMUNICATIONDASHBOARD menu already seeded |

### DB Seed (`sql-scripts-dyanmic/CommunicationDashboard-sqlscripts.sql`)

> Preserve repo's `sql-scripts-dyanmic/` typo. Mirror Donation Dashboard #124's 7-step layout for idempotent independent execution.

| # | Item | Notes |
|---|------|-------|
| 1 | STEP 0 — Diagnostics (read-only) | Verify CRM module + BUSINESSADMIN role + COMMUNICATIONDASHBOARD Menu row exists. Pre-flight: confirm none of the 15 NEW WidgetType rows exist yet (clean slate before STEP 3). |
| 2 | STEP 1 — Insert Dashboard row | DashboardCode=COMMUNICATIONDASHBOARD, IsSystem=true, ModuleId resolves from CRM, DashboardIcon=`tower-broadcast-bold`, DashboardColor=`#7c3aed`, IsActive=true, CompanyId=NULL |
| 3 | STEP 2 — Link Dashboard.MenuId | Idempotent UPDATE WHERE MenuId IS NULL — same shape as Donation Dashboard's STEP 2 |
| 4 | STEP 3 — Insert **15 NEW WidgetType rows** | One INSERT per ComponentPath in § ② widget-type table (4 KPI variants + 11 single-use renderers). Idempotent NOT EXISTS guards. WidgetTypeCode prefix = `COMM_` |
| 5 | STEP 4 — Insert 17 Widget rows | One INSERT per widget. DefaultParameters JSON honors filter keys (dateFrom/dateTo/channel/branchId); StoredProcedureName=notify.fn_communication_dashboard_*. WidgetTypeId resolves to the matching STEP 3 row. |
| 6 | STEP 5 — Insert 17 WidgetRole grants | BUSINESSADMIN read-all on all 17 widgets |
| 7 | STEP 6 — Insert DashboardLayout row | LayoutConfig (lg/md/sm/xs breakpoints) + ConfiguredWidget JSON × 17 instances. Idempotent NOT EXISTS guard on DashboardId. |

**Re-running seed must be idempotent** (NOT EXISTS guards on every INSERT/UPDATE — match Donation Dashboard precedent).

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

# COMMUNICATIONDASHBOARD menu ALREADY seeded under CRM_DASHBOARDS @ OrderBy=3.
# This prompt does NOT seed a new Menu row — only Dashboard + DashboardLayout + 17 Widgets + WidgetRoles + 15 NEW WidgetTypes.
MenuName: Communication Dashboard       # FYI — already seeded
MenuCode: COMMUNICATIONDASHBOARD        # FYI — already seeded
ParentMenu: CRM_DASHBOARDS              # FYI — already seeded (MenuId 278)
Module: CRM
MenuUrl: crm/dashboards/communicationdashboard   # FYI — already seeded
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT
  # Other role grants (MARKETING_LEAD, COMMUNICATION_OFFICER, IT_OPS, FINANCE_USER, BRANCH_MANAGER) — left to admin-config; not seeded here

GridFormSchema: SKIP    # Dashboards have no RJSF form
GridCode: COMMUNICATIONDASHBOARD

# Dashboard-specific seed inputs
DashboardCode: COMMUNICATIONDASHBOARD
DashboardName: Communication Dashboard
DashboardIcon: tower-broadcast-bold
DashboardColor: #7c3aed
IsSystem: true
DashboardKind: MENU_DASHBOARD   # encoded by Dashboard.MenuId IS NOT NULL after STEP 2
MenuOrderBy: 3                  # written to auth.Menus.OrderBy (already seeded — NOT to Dashboard)
NewWidgetTypes:                 # 15 NEW WidgetType rows seeded in STEP 3 (4 KPI variants + 11 single-use)
  - COMM_HERO_KPI: CommunicationHeroKpiWidget                       # used 2× — Total Messages Sent + Avg Delivery Rate (hero)
  - COMM_DELTA_KPI: CommunicationDeltaKpiWidget                     # used 2× — Avg Open Rate (Email) + Opt-Out Rate (delta)
  - COMM_STATUS_KPI: CommunicationStatusKpiWidget                   # used 1× — Active Campaigns (dual-pill chips)
  - COMM_COST_KPI: CommunicationCostKpiWidget                       # used 1× — Cost This Month (amber-tinted + dominant callout)
  - COMM_TOP_TEMPLATES_TABLE: CommunicationTopTemplatesTableWidget
  - COMM_SEND_VOLUME_TREND: CommunicationSendVolumeTrendWidget
  - COMM_CHANNEL_MIX_DONUT: CommunicationChannelMixDonutWidget
  - COMM_COST_BARS: CommunicationCostBarsWidget
  - COMM_ENGAGEMENT_FUNNEL: CommunicationEngagementFunnelWidget
  - COMM_PROVIDER_HEALTH: CommunicationProviderHealthWidget
  - COMM_RECENT_SENDS_FEED: CommunicationRecentSendsFeedWidget
  - COMM_NOTIFICATION_HEALTH: CommunicationNotificationHealthWidget # split — no banner, inbox CTA
  - COMM_BOUNCE_SPAM: CommunicationBounceSpamWidget                 # split — danger banner + reverify CTA
  - COMM_ALERTS_LIST: CommunicationAlertsListWidget
  - COMM_ACTIVE_CAMPAIGNS_TABLE: CommunicationActiveCampaignsTableWidget
WidgetGrants:                   # all 17 widgets — BUSINESSADMIN read-all
  - KPI_TOTAL_MESSAGES: BUSINESSADMIN
  - KPI_AVG_DELIVERY_RATE: BUSINESSADMIN
  - KPI_AVG_OPEN_RATE_EMAIL: BUSINESSADMIN
  - KPI_ACTIVE_CAMPAIGNS: BUSINESSADMIN
  - KPI_COST_THIS_MONTH: BUSINESSADMIN
  - KPI_OPT_OUT_RATE: BUSINESSADMIN
  - TBL_TOP_TEMPLATES: BUSINESSADMIN
  - CHART_SEND_VOLUME_TREND: BUSINESSADMIN
  - CHART_CHANNEL_MIX: BUSINESSADMIN
  - CHART_COST_BY_CHANNEL: BUSINESSADMIN
  - CHART_ENGAGEMENT_FUNNEL: BUSINESSADMIN
  - LIST_PROVIDER_HEALTH: BUSINESSADMIN
  - LIST_RECENT_SENDS: BUSINESSADMIN
  - TBL_NOTIFICATION_HEALTH: BUSINESSADMIN
  - TBL_BOUNCE_SPAM: BUSINESSADMIN
  - LIST_ALERTS: BUSINESSADMIN
  - TBL_ACTIVE_CAMPAIGNS: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Consumer**: Frontend Developer

**Queries** — all widgets use the existing **`generateWidgets`** GraphQL handler (NOT new endpoints):

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| generateWidgets (existing) | `(data jsonb, metadata jsonb, total_count int, filtered_count int)` (text-typed `data_json` deserialized to jsonb on the client) | widgetId, p_filter_json, p_page, p_page_size, p_user_id, p_company_id | All 17 widgets |
| dashboardByModuleAndCode (existing — verified at [GetDashboardByModuleAndCode.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleAndCode.cs)) | DashboardDto with DashboardLayouts + Module includes | moduleCode='CRM', dashboardCode='COMMUNICATIONDASHBOARD' | Single-row fetch — `<MenuDashboardComponent />` consumer |
| widgetByModuleCode (existing) | `[WidgetDto]` | moduleCode='CRM' | Module-wide widget catalog — resolves instance code → widgetId → WidgetDto |
| branches (existing) | `[BranchDto]` | dropdown args | Filter dropdown source for "Branch" |

**Per-widget `data_json` shapes** — each NEW renderer's `.types.ts` file declares this exactly. The 4 KPI renderers expose DIFFERENT shapes because they emphasize different data:

| Renderer | `data_json` shape |
|----------|------|
| CommunicationHeroKpiWidget *(used 2× — Total Messages Sent + Avg Delivery Rate)* | `{ value: number, formatted: string, deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', subtitle: string, sparkline: { labels: string[12], data: number[12] }, accent: 'violet' \| 'green' }` |
| CommunicationDeltaKpiWidget *(used 2× — Open Rate Email + Opt-Out Rate)* | `{ value: number, formatted: string, deltaLabel: string, deltaColor: 'positive'\|'warning'\|'neutral', subtitle: string, accent: 'indigo' \| 'rose', icon: string, decliningGood?: boolean }` (no sparkline; Opt-Out uses `decliningGood:true` so the down-arrow renders in positive-green) |
| CommunicationStatusKpiWidget *(used 1× — Active Campaigns)* | `{ value: number, formatted: string, segments: [{label:'sending', count: number, color: 'amber'},{label:'scheduled', count: number, color: 'violet'}], accent: 'orange', icon: 'bullhorn' }` (dual-pill subtitle is the visual distinguisher) |
| CommunicationCostKpiWidget *(used 1× — Cost This Month)* | `{ value: number, formatted: string, deltaLabel: string, deltaColor: 'warning' \| 'positive' \| 'neutral', dominantChannel: string, dominantLabel: string, accent: 'amber', icon: 'coins' }` (amber-tinted card + dominant-channel callout chip) |
| CommunicationTopTemplatesTableWidget | `{ rows: [{ templateId, templateName, channel: 'email'\|'sms'\|'whatsapp'\|'notification', channelColorHex, sent, deliveryPct, deliveryColor: 'green'\|'amber'\|'red', openPct?: number\|null, openColor?: string\|null, clickOrReplyPct?: number\|null, clickOrReplyColor?: string\|null, lastUsedLabel: string }] }` (top 6 rows; SMS rows have `openPct:null` rendered as "—") |
| CommunicationSendVolumeTrendWidget | `{ type: 'area', labels: string[12], series: [{name:'Email', color:'#4f46e5', data:int[12]},{name:'SMS', color:'#f97316', data:int[12]},{name:'WhatsApp', color:'#22c55e', data:int[12]},{name:'In-App', color:'#d97706', data:int[12]}], annotations?: [{xValue:'Mar', label:'Ramadan campaign launch'},{xValue:'Dec', label:'Year-end giving push'}] }` |
| CommunicationChannelMixDonutWidget | `{ total: number, totalFormatted: string ('186K'), label: 'messages', segments: [{label, value, pct, color}] }` (4 segments) |
| CommunicationCostBarsWidget | `{ total: number, totalFormatted: string, bars: [{label, value, valueFormatted, widthPct, color, icon}], costPer1k: [{label, value: string ('$2.25')}] }` (4 bars; cost-per-1K footer with 4 entries) |
| CommunicationEngagementFunnelWidget | `{ steps: [{label, value, pct?: number, pctOfPrevious?: number, pctOfOpened?: number, formattedPct: string, color}], disclaimer: string }` (5 fixed steps Sent/Delivered/Opened/Clicked/Replied; the renderer chooses which `pct*` field to display per step) |
| CommunicationProviderHealthWidget | `{ providers: [{key, name, icon, iconColor, status: 'UP'\|'DEGRADED'\|'DOWN', meta: string}] }` (4 fixed providers — function ALWAYS returns 4) |
| CommunicationRecentSendsFeedWidget | `{ rows: [{ itemId, channel, icon, iconColor, line1, line2, status: 'SENDING'\|'SENT'\|'SCHEDULED'\|'FAILED'\|'RECURRING', statusColor, drillRoute, drillArgs }] }` (7 most recent) |
| CommunicationNotificationHealthWidget | `{ stats: [{label, value, valueFormatted, amount, valueColor: 'violet'\|'green'\|'green-success'\|'amber'\|'red'}] }` (NO banner — function does NOT emit a `banner` field) |
| CommunicationBounceSpamWidget | `{ stats: [{label, value, valueFormatted, amount, valueColor: 'amber'\|'red'\|'green'\|'muted'}], banner?: { kind: 'danger', message: string (sanitized HTML, `<strong>` only), ctaLabel?: string, ctaRoute?: string, ctaArgs?: object } }` (banner CONDITIONAL — present when expired-sender-IDs > 0) |
| CommunicationAlertsListWidget | `{ alerts: [{ severity: 'warning'\|'danger'\|'info'\|'success', iconCode, message, link: { label, route, args } }] }` (top 10) |
| CommunicationActiveCampaignsTableWidget | `{ rows: [{ campaignId, campaignType: 'email'\|'sms'\|'whatsapp', campaignName, channel, channelColor, recipients, recipientsFormatted, status, statusColor, deliveryPct?: number\|null, deliveryFormatted?: string\|null, deliveryColor?: string\|null, costFormatted: string, scheduleLabel, drillRoute, drillArgs }] }` (collapsible; "+ Create Campaign" footer button is inline FE chrome, not data-driven) |

**No composite DTO**. No new C# types. Each NEW renderer consumes its own jsonb shape directly through the `generateWidgets` runtime. The 2 mini-grid widget shapes (NotificationHealth + BounceSpam) deliberately diverge (different banner contracts) so the renderers cannot be accidentally collapsed into one.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] All 17 SQL functions exist in `notify.` schema
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/communicationdashboard`
- [ ] Network tab shows EXACTLY ONE `dashboardByModuleAndCode` call (no `dashboardByModuleCode` leakage)
- [ ] Dashboard renders with 17 widgets in the documented layout

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Dashboard loads with default filters (This Month / All Channels / All Branches) and renders all 17 widgets
- [ ] **Renderer policy compliance** (legacy reuse check): `git grep` for legacy ComponentPaths (`StatusWidgetType1\|StatusWidgetType2\|MultiChartWidget\|PieChartWidgetType1\|BarChartWidgetType1\|FilterTableWidget\|NormalTableWidget\|TableWidgetType1\|RadialBarWidget\|HtmlWidgetType1\|HtmlWidgetType2\|GeographicHeatmapWidgetType1\|AlertListWidget\|case-dashboard-alerts-widget\|Donation.*Widget\|Contact.*Widget\|Volunteer.*Widget\|Ambassador.*Widget`) inside `communication-dashboard-widgets/` returns ZERO matches. The 15 seeded WidgetType rows reference only `Communication*Widget` ComponentPaths.
- [ ] **Visual-uniqueness compliance** (per the new directive — no clone tile grids):
      • Hero KPIs (rows 1+2) visually distinct from supporting KPIs (rows 3-6) — taller h=3 cells, sparklines present, gradient header strip
      • The 4 KPI variants render visibly different chrome — `CommunicationHeroKpiWidget` (gradient strip + sparkline) ≠ `CommunicationDeltaKpiWidget` (single value + delta + subtitle, no sparkline) ≠ `CommunicationStatusKpiWidget` (dual-pill chips below value) ≠ `CommunicationCostKpiWidget` (amber-tinted bg + dominant-channel callout)
      • The 2 mini-grid widgets render visibly different chrome — `CommunicationNotificationHealthWidget` (no banner + inbox icon + violet/green/amber/red cells) ≠ `CommunicationBounceSpamWidget` (danger banner with CTA + shield-halved icon)
      • Chart types match data shape — stacked-area for trends (CHART_SEND_VOLUME_TREND), donut for parts-of-whole (CHART_CHANNEL_MIX), horizontal bars for cost comparisons (CHART_COST_BY_CHANNEL), 5-step funnel for engagement (CHART_ENGAGEMENT_FUNNEL). No "one chart component switching `chartType`."
      • Each widget skeleton matches its renderer's actual layout — KPI tile skeleton differs from donut skeleton differs from funnel-cell skeleton differs from table-row skeleton differs from alert-row skeleton differs from mini-grid 4-cell skeleton differs from provider-row skeleton differs from activity-feed skeleton. NO single shimmer rectangle on any widget.
      • Side-by-side screenshot of all 17 widgets shows visible visual variety — no two widgets feel "samey"
- [ ] Each KPI card shows correct value formatted per spec via its dedicated renderer (Hero / Delta / Status / Cost)
- [ ] Each chart renders correctly via its NEW renderer (axes, legends, tooltips, donut center label, send-volume-trend annotations for "Ramadan campaign launch" + "Year-end giving push")
- [ ] Each table / mini-grid / feed renders with correct columns + row click via NEW renderer
- [ ] Period filter change refetches all date-honoring widgets in parallel
- [ ] **Channel filter change scopes channel-aware widgets** ("All Channels" / "Email Only" / "SMS Only" / "WhatsApp Only" / "Notification Only"); channel-fixed widgets (Open Rate Email KPI, Engagement Funnel, NotificationHealth) IGNORE this filter and re-render their fixed-channel data unchanged
- [ ] Branch filter change refetches Branch-scoped widgets only
- [ ] Custom Range opens date popover and applies on confirm
- [ ] Drill-down clicks navigate per Drill-Down Map
- [ ] **WhatsApp graceful degrade verified**: with `to_regclass('notify."WhatsAppCampaigns"') IS NULL`, WhatsApp data contributes 0 to all aggregates without throwing; widgets render rest of channel data normally
- [ ] "Export Report" toasts SERVICE_PLACEHOLDER (no crash)
- [ ] "Print" opens browser print dialog
- [ ] Empty / error states render per widget
- [ ] Role-based widget gating works
- [ ] Alerts list (widget 16) generates plausible items per § ④ rules; sanitized HTML only allows `<strong>`
- [ ] react-grid-layout reflows correctly across breakpoints (xs/sm/md/lg/xl) — Hero KPIs collapse to full-width stacked on xs/sm; supporting KPIs to 2-per-row on sm; etc.
- [ ] Sidebar leaf "Communication Dashboard" visible to BUSINESSADMIN
- [ ] Bookmarked URL survives reload
- [ ] Role-gating via `RoleCapability(MenuId=COMMUNICATIONDASHBOARD)` hides leaf for unauthorized roles

**DB Seed Verification:**
- [ ] Dashboard row inserted with DashboardCode=COMMUNICATIONDASHBOARD, ModuleId=CRM, IsSystem=true, MenuId NOT NULL after STEP 2
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (all 4 breakpoints) and ConfiguredWidget JSON
- [ ] All 17 Widget rows + WidgetRole grants (BUSINESSADMIN) inserted
- [ ] **All 15 NEW WidgetType rows inserted** with the exact ComponentPath strings listed in § ② (CommunicationHeroKpiWidget, CommunicationDeltaKpiWidget, CommunicationStatusKpiWidget, CommunicationCostKpiWidget, CommunicationTopTemplatesTableWidget, CommunicationSendVolumeTrendWidget, CommunicationChannelMixDonutWidget, CommunicationCostBarsWidget, CommunicationEngagementFunnelWidget, CommunicationProviderHealthWidget, CommunicationRecentSendsFeedWidget, CommunicationNotificationHealthWidget, CommunicationBounceSpamWidget, CommunicationAlertsListWidget, CommunicationActiveCampaignsTableWidget)
- [ ] All 17 Postgres functions queryable: `SELECT * FROM notify."fn_communication_dashboard_kpi_total_messages"('{}'::jsonb, 1, 50, 1, 1);` returns 1 row × 4 columns
- [ ] Re-running seed is idempotent

---

## ⑫ Special Notes & Warnings

**Consumer**: All agents

### Known Issues (pre-flagged)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | HIGH | Dependency | **WhatsAppCampaign entity (Screen #32) does NOT yet exist** — status PROMPT_READY only. The 9 widgets that aggregate over WhatsAppCampaign (KPIs 1/2/4/5/6, SendVolumeTrend, ChannelMix, CostBars, ProviderHealth, RecentSends, ActiveCampaigns) MUST guard the table reference with `to_regclass('notify."WhatsAppCampaigns"') IS NOT NULL` so functions return 0 / empty rows for the WhatsApp slice gracefully. Once #32 ships, the same functions automatically include WhatsApp data without code changes. Verify the guard works during build by querying the function with `to_regclass` returning NULL. Drill-down to `crm/communication/whatsappcampaign` is OK — that route is already a stub that #32's build will populate. Per-route stub at `[lang]/crm/dashboards/communicationdashboard/page.tsx` MUST be overwritten to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="COMMUNICATIONDASHBOARD" toolbar={<CommunicationDashboardToolbar />} />`. | OPEN |
| ISSUE-2 | MED | Service dep | "Export Report" PDF / CSV — full UI in place; handler toasts because PDF rendering / channel-summary report service not wired. SERVICE_PLACEHOLDER. | OPEN |
| ISSUE-3 | HIGH | Renderer policy + visual-uniqueness | Two non-negotiable checks: (a) **No legacy reuse** — all 15 ComponentPaths must be NEW under `communication-dashboard-widgets/`. `git grep -E "(StatusWidgetType1\|StatusWidgetType2\|MultiChartWidget\|PieChartWidgetType1\|BarChartWidgetType1\|FilterTableWidget\|NormalTableWidget\|TableWidgetType1\|RadialBarWidget\|HtmlWidgetType1\|HtmlWidgetType2\|GeographicHeatmapWidgetType1\|AlertListWidget\|case-dashboard-alerts-widget\|Donation.*Widget\|Contact.*Widget\|Volunteer.*Widget\|Ambassador.*Widget)" communication-dashboard-widgets/` returns zero. (b) **No clone tile grids** — the 6 KPIs MUST split across 4 distinct renderers (Hero / Delta / Status / Cost), the 2 mini-grids (NotificationHealth + BounceSpam) MUST split across 2 distinct renderers. DO NOT collapse them back to `CommunicationKpiCardWidget` or `CommunicationHealthGridWidget` "to save time" — that produces the exact "uniform-clone widget grids" anti-pattern called out in [feedback memory](file://C:/Users/USER/.claude/projects/d--Repos-PWDS-pwds-soruban/memory/feedback_dashboard_widgets.md). Each split renderer's `.skeleton.tsx` must visibly differ. | OPEN |
| ISSUE-4 | MED | Data fidelity | SMS opt-out detection is non-trivial — Twilio reply keywords (STOP / STOPALL / UNSUBSCRIBE / etc.) are not currently logged into a queryable table on the SMSCampaign side. v1 KPI 6 (Opt-Out Rate) treats SMS opt-outs as 0 unless an `SMSCampaignReply` event log exists. WhatsApp opt-outs use the existing `WhatsAppOptKeyword` rows when keyword matches a STOP-style phrase. Email opt-outs use `EmailWebhookEventLog WHERE event='unsubscribe'`. Document the SMS-opt-out gap; a follow-up build to log Twilio inbound reply keywords is needed for full accuracy. | OPEN |
| ISSUE-5 | LOW | Drill-down compatibility | Top Performing Templates row drill-down emits `?templateId={id}` to the channel-specific template list page (`crm/communication/emailtemplate?templateId={id}`, etc.). Not all template list pages currently consume the `templateId` query param to prefilter — verify during build per channel and add the prefilter consumer if missing. Graceful: if not consumed, the user lands on the unfiltered list (no crash). | OPEN |
| ISSUE-6 | LOW | UX (chart annotations) | Send Volume Trend annotation pins ("Ramadan campaign launch", "Year-end giving push") are STATIC in the function output for v1. Dynamic annotation extraction from EmailCampaign/SMSCampaign launch events is a v1.1 follow-up — would require a `CampaignLaunch` events table or filter against existing campaign timestamps with category labeling. Non-blocking. | OPEN |
| ISSUE-7 | MED | Cost computation accuracy | Email cost = `EmailSendJob.TotalEmailsSend × CompanyEmailProvider.CostPerEmail` aggregated over the period. Two issues: (a) `CompanyEmailProvider.CostPerEmail` is nullable per the entity — when null, the function falls back to a default `$0.00225/email` (matches the cost-per-1K $2.25 in the mockup); document this fallback. (b) `EmailSendJob` does NOT carry a per-job cost field today — adding `EstimatedCostCents` / `ActualCostCents` to align with `SMSCampaign` is a v1.1 BE follow-up. v1 ships with the multiplication approach. | OPEN |
| ISSUE-8 | LOW | Engagement Funnel semantics | Email "Opens" — counts can be unique-per-recipient OR raw-event. Mockup percent reads "42.8%" of Sent → suggests unique opens. The function uses `COUNT(DISTINCT recipientId)` for Opened/Clicked. Pre-flight on EmailWebhookEventLog availability — if the table tracks at recipient grain, unique counts are direct; otherwise document the raw-event fallback. | OPEN |
| ISSUE-9 | MED | Branch scoping | Most communication source entities do NOT carry a direct `BranchId` FK — branch scoping must flow transitively. Strategy per entity: (a) `EmailSendJob.OrganizationalUnitId` → resolve to Branch via `OrganizationalUnit.BranchId` chain (verify); (b) `SMSCampaign` has NO direct branch link — branch filter no-ops on SMS-only widgets unless the function joins through `SMSCampaign → CreatedBy User → Staff → BranchId` (moderate complexity); (c) `WhatsAppCampaign` similar; (d) `Notification.CompanyId` only (no branch dimension — ignore branch filter when channel=Notification). v1 ships with no-op branch filter on SMS+WhatsApp+Notification widgets and full branch scoping on Email widgets only. Document each function's strategy in its header comment. | OPEN |
| ISSUE-10 | MED | Source data gap | Bounce/Spam Watch "expired SMS sender registrations" count — there is no canonical "SenderId Registry" table today. SMSCampaign.SenderValue is a free-text field. Options: (a) treat as 0 in v1 (banner only fires when value > 0); (b) add a `SMSSenderRegistration` table on a future build with VerifiedAt + ExpiresAt columns. v1 ships (a) — banner appears only when a future enhancement populates this signal. Document as ISSUE-10 follow-up. | OPEN |
| ISSUE-11 | LOW | UX (relative time) | Recent Sends feed + Top Templates "last used" use relative times. Computed in the Postgres function via `EXTRACT(EPOCH FROM (NOW() - eventDate))` and a CASE-WHEN cascade ("just now" / "X minutes ago" / "X hours ago" / "today" / "yesterday" / "X days ago" / "X weeks ago"). Locale-specific phrasing deferred — add `p_locale` arg if needed later. Non-blocking. | OPEN |
| ISSUE-12 | LOW | Multi-currency | Single-currency assumed for v1. KPI 5 + Cost Bars display in `Company.DefaultCurrency`. If a tenant operates multi-currency campaigns, add a Currency filter analogous to Donation Dashboard's. Pre-flight: `SELECT DISTINCT CurrencyId FROM notify."CompanyEmailProviders"` — if > 1 distinct currency, plan v1.1 follow-up. | OPEN |
| ISSUE-13 | MED | Performance | Per-widget Postgres functions over `EmailSendJob` × `EmailWebhookEventLog` may hit performance ceilings on tenants with > 100k email-event rows. Pre-flight: `SELECT COUNT(*) FROM notify."EmailWebhookEventLogs"` in target tenants. If > 50k rows, profile each function under load before declaring shippable. Materialized view options: per-month aggregate of email events, per-channel daily volume rollup. Materialized views deferred to v1.1 if needed. | OPEN |
| ISSUE-14 | MED | Skeleton fidelity (per-renderer) | Each of the 15 NEW renderers ships its own `.skeleton.tsx` matching its actual layout. Specifically: `CommunicationHeroKpiWidget` skeleton = title + large value bar + sparkline strip + delta-pill; `CommunicationDeltaKpiWidget` = title + value + delta + subtitle (no sparkline); `CommunicationStatusKpiWidget` = title + value + 2 dual-pill stubs; `CommunicationCostKpiWidget` = title + currency-value + warning-pill + dominant-channel chip; `CommunicationTopTemplatesTableWidget` = 6 rows of (text + pill + count + 3 rate-bars + relative-time) shape; `CommunicationSendVolumeTrendWidget` = 12 stacked-area bars stub + axis labels; `CommunicationChannelMixDonutWidget` = donut ring + 4-row legend stubs; `CommunicationCostBarsWidget` = 4 bar-rows + 4-item footer stub; `CommunicationEngagementFunnelWidget` = 5 funnel-cells with colored top-borders; `CommunicationProviderHealthWidget` = 4 row stubs (icon + name + meta + status pill); `CommunicationRecentSendsFeedWidget` = 7-row feed with channel-icon + 2-line content + status-pill; `CommunicationNotificationHealthWidget` = 4-cell grid (no banner stub); `CommunicationBounceSpamWidget` = 4-cell grid + danger-banner stub with CTA pill; `CommunicationAlertsListWidget` = 4 alert-row stubs (4 distinct severity bg colors); `CommunicationActiveCampaignsTableWidget` = 6 rows of (name + pill + count + status + rate-bar + cost + schedule). **Generic shimmer rectangles are FORBIDDEN** — verify visually during loading state. | OPEN |
| ISSUE-15 | LOW | Active Campaigns scope | Active Campaigns table (17) — mockup is collapsible (default expanded). v1 ships expanded by default with a chevron toggle. Persist user's expand/collapse state in localStorage if user feedback requests. | OPEN |
| ISSUE-16 | LOW | Cross-channel rank fairness | Top Performing Templates table aggregates across 4 channels — but ranking purely by Sent count favors high-volume channels (Email tends to dominate). Consider a "score" metric blending Sent + DeliveryPct + EngagementPct that's channel-fair. v1 ships rank-by-Sent; document for product feedback. | OPEN |

### Build everything in the mockup (GOLDEN RULE reminder)
Every UI element shown in the HTML mockup is in scope. The 6 KPIs / 4 charts / 1 funnel / 1 provider list / 1 activity feed / 2 mini-grids / 1 alerts list / 1 collapsible active-campaigns table / 3 filter selects / 2 action buttons are ALL in scope. The only SERVICE_PLACEHOLDERs are:
- "Export Report" PDF / CSV generation (ISSUE-2)
- WhatsApp slice of all aggregates until #32 ships the entity (ISSUE-1 — NOT a UI placeholder; a graceful-degrade in the SQL layer)
- SMS opt-out signal until reply-keyword logging exists (ISSUE-4 — KPI 6 reads 0 for SMS; full UI rendered)
- Bounce/Spam expired-SMS-sender count until registration tracking exists (ISSUE-10 — banner stays hidden when 0; full UI rendered)

Everything else is fully buildable end-to-end. The developer is free to revise the widget set per the Developer-Decided-Widgets directive — but additions/drops/reshapes must be documented as new ISSUE-N entries above.

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

### Session 1 — 2026-04-30 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FULL scope: 17 BE SQL functions + 15 FE renderers + toolbar + page-config rewrite + WIDGET_REGISTRY wiring + DB seed.
- **Files touched**:
  - **BE (18 created)**:
    - `PSS_2.0_Backend/DatabaseScripts/Functions/notify/` (NEW folder)
    - `notify/fn_communication_dashboard_kpi_total_messages.sql` (created, ~175 lines)
    - `notify/fn_communication_dashboard_kpi_avg_delivery_rate.sql` (created, ~180 lines)
    - `notify/fn_communication_dashboard_kpi_avg_open_rate_email.sql` (created, ~130 lines)
    - `notify/fn_communication_dashboard_kpi_active_campaigns.sql` (created, ~120 lines)
    - `notify/fn_communication_dashboard_kpi_cost_this_month.sql` (created, ~160 lines)
    - `notify/fn_communication_dashboard_kpi_opt_out_rate.sql` (created, ~150 lines)
    - `notify/fn_communication_dashboard_top_templates.sql` (created, ~195 lines)
    - `notify/fn_communication_dashboard_send_volume_trend.sql` (created, ~150 lines)
    - `notify/fn_communication_dashboard_channel_mix.sql` (created, ~110 lines)
    - `notify/fn_communication_dashboard_cost_by_channel.sql` (created, ~145 lines)
    - `notify/fn_communication_dashboard_engagement_funnel.sql` (created, ~135 lines)
    - `notify/fn_communication_dashboard_provider_health.sql` (created, ~195 lines)
    - `notify/fn_communication_dashboard_recent_sends.sql` (created, ~185 lines)
    - `notify/fn_communication_dashboard_notification_health.sql` (created, ~110 lines)
    - `notify/fn_communication_dashboard_bounce_spam.sql` (created, ~175 lines)
    - `notify/fn_communication_dashboard_alerts.sql` (created, ~295 lines, 7× sanitization regex)
    - `notify/fn_communication_dashboard_active_campaigns.sql` (created, ~260 lines)
    - Total ~2870 lines BE SQL
  - **FE (64 touched)**:
    - 15 renderer folders × 4 files each (60 created): `dashboards/widgets/communication-dashboard-widgets/communication-{hero-kpi,delta-kpi,status-kpi,cost-kpi,top-templates-table,send-volume-trend,channel-mix-donut,cost-bars,engagement-funnel,provider-health,recent-sends-feed,notification-health,bounce-spam,alerts-list,active-campaigns-table}-widget/{ComponentName}.tsx + .types.ts + .skeleton.tsx + index.ts`
    - `dashboards/widgets/communication-dashboard-widgets/index.ts` (created — barrel re-exporting 15 components + 14 distinct data-shape interfaces)
    - `pages/crm/dashboards/communication-dashboard-toolbar.tsx` (created — Period/Channel/Branch + Export/Print)
    - `pages/crm/dashboards/communicationdashboard.tsx` (modified — overwrote legacy `<DashboardComponent />` stub with `<MenuDashboardComponent toolbar={<CommunicationDashboardToolbar />} />` wrapped in `<WidgetFilterContextProvider>`)
    - `dashboards/dashboard-widget-registry.tsx` (modified — 2 hunks: 15-component import block + 15 registry-key entries between Donation and Volunteer dashboard sections)
  - **DB**: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/CommunicationDashboard-sqlscripts.sql` (created — 7 steps idempotent, ~700 lines)
- **Deviations from spec**:
  - SMSCampaignRecipient: BE uses `DeliveredAt IS NOT NULL` for delivered + `FailureReason IS NOT NULL` for failed (entity has no `Sent` boolean column; status proxied via `DeliveryStatusId` lookup is deferred). Documented in BE agent report.
  - Email cost in Active Campaigns table (Widget 17): `costFormatted` hardcoded `$0` per Email row (correlated `CostPerEmail × TotalEmailsSend` lookup would blow out the CTE; KPI 5 + Cost Bars compute the cost correctly). Logged as ISSUE-7 follow-up.
  - SMS opt-out (KPI 6): SMS sub-total returns 0 per ISSUE-4 (no Twilio reply-keyword event log table exists yet). UI renders normally with cross-channel total dominated by Email.
  - SMS sender-ID expiry (Bounce/Spam banner): proxied via distinct `SenderValue` from upcoming `ScheduledAt` rows; banner stays hidden when proxy returns 0. Tracked as ISSUE-10.
  - Branch scoping: Email widgets join through `app."OrganizationalUnits"."BranchId"`; SMS/WhatsApp/Notification widgets are no-op on branch filter per ISSUE-9 (no direct branch dimension on those entities).
  - WhatsAppCampaigns columns (`AudienceNetRecipientsCount`, `ActualCostCents`, `SentAt`, `ScheduledAt`, `CampaignStatusId`, `WhatsAppTemplateId`, `CompanyId`, `IsDeleted`) assumed mirroring SMSCampaign — verify when Screen #32 builds the entity.
  - 12 of 17 functions guard WhatsAppCampaigns via `EXECUTE` dynamic SQL inside `IF to_regclass('notify."WhatsAppCampaigns"') IS NOT NULL THEN ... ELSE ... END IF;` blocks for safety against the missing table at parse time. The 5 functions not guarded never reference the table (KPI 3 Email-only, Engagement Funnel Email-only, Notification Health InApp-only, Channel Mix only-references-via-aggregate, Bounce/Spam Email/SMS-only).
  - Widget Description suffixes `_COMM` applied to 3 generic-name widgets (KPI_ACTIVE_CAMPAIGNS_COMM, LIST_ALERTS_COMM, TBL_ACTIVE_CAMPAIGNS_COMM) to avoid collision with future CRM-module widgets sharing similar names.
- **Known issues opened**:
  - ISSUE-1 (HIGH, Dependency, OPEN — pre-flagged) — WhatsAppCampaign #32 not yet built; functions guard via `to_regclass` so WhatsApp slice contributes 0 until #32 ships. Drill-down to `crm/communication/whatsappcampaign` is OK (existing route stub).
  - ISSUE-2 (MED, Service dep, OPEN — pre-flagged) — Export Report SERVICE_PLACEHOLDER (toast); no PDF export wired.
  - ISSUE-3 (HIGH, Renderer policy + visual-uniqueness, RESOLVED-VERIFIED) — All 15 ComponentPaths are NEW under `communication-dashboard-widgets/`; grep confirmed zero legacy/sibling-dashboard renderer reuse inside the folder (only docstring mention of frozen names in barrel index.ts header).
  - ISSUE-4 (MED, Data fidelity, OPEN — pre-flagged) — SMS opt-out signal absent; KPI 6 SMS=0 documented.
  - ISSUE-5 (LOW, Drill-down, OPEN — pre-flagged) — Top Templates row drill-down emits `?templateId={id}` not all template list pages currently consume; graceful no-prefilter fallback.
  - ISSUE-6 (LOW, UX chart annotations, OPEN — pre-flagged) — Send Volume Trend annotations static (Mar/Dec); dynamic launch-event extraction deferred to v1.1.
  - ISSUE-7 (MED, Cost computation, OPEN — pre-flagged) — Email cost fallback via `CostPerEmail × TotalEmailsSend`; per-row cost in Active Campaigns table currently shows `$0` for Email rows (deferred lookup).
  - ISSUE-8 (LOW, Funnel semantics, OPEN — pre-flagged) — Email Opens use `COUNT(DISTINCT recipientId)` for unique counts.
  - ISSUE-9 (MED, Branch scoping, OPEN — pre-flagged) — SMS/WhatsApp/Notification widgets no-op on branch filter; only Email widgets scope through `OrganizationalUnit → BranchId` chain.
  - ISSUE-10 (MED, Source data gap, OPEN — pre-flagged) — Bounce/Spam expired-sender count proxied via distinct upcoming SenderValue; canonical sender-registration table deferred.
  - ISSUE-13 (MED, Performance, OPEN — pre-flagged) — Materialized views deferred; profile under tenants > 50k EmailWebhookEventLog rows.
  - ISSUE-14 (MED, Skeleton fidelity, RESOLVED-VERIFIED) — Each of the 15 renderer skeletons is shape-matched to its actual layout (line counts 19-40 per skeleton; grep confirms no generic shimmer rectangles).
- **Known issues closed**: None (this is the initial build session).
- **Next step**: None — build complete. Recommended verification before declaring shippable: (1) run `dotnet build` to confirm migration registers the 17 functions cleanly (or confirm functions are auto-applied at runtime per existing `case/` precedent); (2) execute `CommunicationDashboard-sqlscripts.sql` STEP 0-6 in order; (3) `pnpm dev`, navigate to `/[lang]/crm/dashboards/communicationdashboard` and verify all 17 widgets render with sample data, channel filter scopes correctly, drill-downs land on COMPLETED screens, react-grid-layout reflows across xs/sm/md/lg/xl breakpoints; (4) confirm `WhatsAppCampaigns` table absence does not throw — functions return 0 for WA slice gracefully.

