---
screen: EmailAnalytics
registry_id: 38
module: CRM (Communication sub-module)
status: IN_PROGRESS
scope: FULL
screen_type: DASHBOARD
dashboard_variant: MENU_DASHBOARD
complexity: High
new_module: NO
planned_date: 2026-05-12
completed_date:
last_session_date: 2026-05-12
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (widgets, charts, filters, drill-downs identified — TWO render modes: Overview + Campaign Detail)
- [x] Variant chosen — `MENU_DASHBOARD` (own sidebar leaf at `crm/communication/emailanalytics`, parented under `CRM_COMMUNICATION` not `CRM_DASHBOARDS` — exception noted in §⑫)
- [x] Source entities identified (`notify.EmailSendJob`, `notify.EmailSendQueue`, `notify.EmailClickTracking`, `notify.EmailJobAnalytics`, `notify.EmailTemplate`)
- [x] Widget catalog drafted (10 Overview widgets + 7 Detail widgets = 17 NEW renderers)
- [x] react-grid-layout config drafted (Overview lg breakpoint — 12 cols, 6 rows; Detail mode is custom page layout, not react-grid-layout)
- [x] DashboardLayout JSON drafted for Overview mode only (Detail mode is code-driven in page.tsx)
- [x] Parent menu code (`CRM_COMMUNICATION`) + slug (`emailanalytics`) + OrderBy (3) — MENU ALREADY SEEDED in `Pss2.0_Global_Menus_List.sql:308`
- [x] Per-route-stub FE pattern selected (matches all 6 prior MENU_DASHBOARDS — Case #52, Volunteer #57, Ambassador #69, Contact #123, Donation #124, Communication #125)
- [x] First-time infra NOT folded in — infra is functionally complete via per-route-stub pattern; dynamic `[slug]` route + `linkDashboardToMenu` + backfill seed remain deferred (Case #52 ISSUE-1 precedent)
- [x] File manifest computed (4 BE files + ~22 FE files + 1 SQL seed)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete (confirm composite-DTO strategy vs per-widget; resolve "conversion" metric scope; resolve `bestSendTime`/`bestSubjectLine` derivation rules)
- [ ] UX Design finalized (toolbar layout, mode-switch UX, Detail mode page layout, skeleton shapes per widget)
- [ ] User Approval received
- [ ] Backend: `EmailAnalyticsSchemas.cs` created (3 composite DTOs + 6 sub-DTOs)
- [ ] Backend: `GetEmailAnalyticsOverview` composite query handler (Path C) — aggregates `EmailJobAnalytics` + `EmailSendQueue` + `EmailSendJob` for the date window with optional campaign filter
- [ ] Backend: `GetEmailAnalyticsCampaignDetail` per-campaign query handler — single `EmailSendJobId` returns Funnel + Engagement + Delivery + ClickMap + Heatmap aggregates
- [ ] Backend: `GetEmailAnalyticsRecipientActivity` paginated handler — per-recipient table with filter pill (ALL/OPENED/CLICKED/NOT_OPENED/BOUNCED/UNSUBSCRIBED) + Export query
- [ ] Backend: `ResendToNonOpeners` mutation — SERVICE_PLACEHOLDER stub (deep-links to email-campaign-builder)
- [ ] Backend wiring: `EmailAnalyticsQueries.cs` + `EmailAnalyticsMutations.cs` endpoints, Mapster configs in `NotifyMappings.cs`, register GQL fields
- [ ] Frontend: 10 NEW Overview widget renderers under `dashboards/widgets/email-analytics-dashboard-widgets/`
- [ ] Frontend: 7 NEW Detail widget components under same folder (registered in WIDGET_REGISTRY for consistency even though rendered code-driven, not via DashboardLayout)
- [ ] Frontend: custom page `[lang]/crm/communication/emailanalytics/page.tsx` overwrites UnderConstruction stub — implements URL-state mode switching (`?campaignId=X` → Detail, default → Overview)
- [ ] Frontend wiring: `dashboard-widget-registry.tsx` extended with 17 new keys, `dashboard-widget-query-registry.tsx` extended with 3 new queries, DTO barrel, GQL barrels
- [ ] DB Seed `EmailAnalytics-sqlscripts.sql` generated (in `sql-scripts-dyanmic/` — preserve typo):
      • Dashboard row `EMAILANALYTICS` (ModuleId=CRM, IsSystem=true)
      • DashboardLayout row for OVERVIEW MODE ONLY (10 widget instances, lg breakpoint with optional md/sm)
      • 17 WidgetType rows (one per renderer key)
      • 10 Widget rows for Overview (Detail widgets are NOT seeded — code-driven only)
      • WidgetRole grants for BUSINESSADMIN (+ MARKETING_LEAD / FUNDRAISING_DIRECTOR if those roles exist)
      • UPDATE `sett.Dashboards SET MenuId = (SELECT MenuId FROM auth.Menus WHERE MenuCode='EMAILANALYTICS')` — established raw-SQL-UPDATE pattern (matches 6 prior dashboards)
      • MenuCapability(EMAILANALYTICS, READ) + RoleCapability(BUSINESSADMIN, READ) — only if missing
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm tsc --noEmit` passes
- [ ] `pnpm dev` — page loads at `/[lang]/crm/communication/emailanalytics` with default 30-day range and Overview mode
- [ ] All 6 KPI cards render with correct values (Total Sent / Delivery / Open / Click / Bounce / Unsub rates) + delta indicators
- [ ] Email Funnel renders 5-stage horizontal bar (Sent → Delivered → Opened → Clicked → Converted) with gradient fills and percent labels
- [ ] Campaign Performance Table renders sortable rows with color-coded rate cells (green ≥30%, yellow 15-30%, red <15% for OpenRate; analogous for ClickRate)
- [ ] Rate Trends chart renders dual-line series (Open Rate teal + Click Rate purple) over selected date range
- [ ] Best Performing Content card row renders Best Subject Line + Best Send Time + Best Campaign Type
- [ ] Date range chips (7d/30d/90d/YTD/Custom) refetch all widgets in parallel
- [ ] Campaign dropdown filter — selecting a campaign in the dropdown navigates to Detail mode (`?campaignId=X`)
- [ ] Clicking a campaign row name in the Performance Table navigates to Detail mode (`?campaignId=X`)
- [ ] Detail mode renders: Campaign Header Card + Campaign Funnel (4-stage) + 4-card Engagement Metrics + Click Map table with distribution bars + Delivery Breakdown 3-tile + Recipient Activity table with filter pills + 7×24 Open Time Heatmap
- [ ] Recipient Activity filter pills (All / Opened / Clicked / Not Opened / Bounced / Unsubscribed) refetch table only — chart/funnel/heatmap stay cached
- [ ] Export CSV button on Recipient Activity opens Export query result (SERVICE_PLACEHOLDER if export-infra unwired)
- [ ] Recipient row name click navigates to `/crm/contact/contact?mode=read&id={contactId}`
- [ ] Funnel stage clicks (Detail mode) filter Recipient Activity table by status (Opened → filter=OPENED, etc.)
- [ ] "Resend to Non-Openers" button toasts SERVICE_PLACEHOLDER message + deep-links to email-campaign-builder with `srcJobId={id}&audience=non-openers`
- [ ] Back link in Detail mode returns to Overview (clears `?campaignId` from URL)
- [ ] react-grid-layout reflows correctly across xs/sm/md/lg/xl breakpoints in Overview mode
- [ ] Skeleton states render during fetch (shape-matched per widget — KPI skeleton, chart skeleton, table skeleton, heatmap skeleton, funnel skeleton)
- [ ] Empty state renders for widgets with no data in selected range
- [ ] Error state renders for failed queries (red mini banner + Retry)
- [ ] Role gating: WidgetRole(HasAccess=false) hides widget with Restricted placeholder
- [ ] DB Seed re-runs idempotently (NOT EXISTS guards on every INSERT/UPDATE)

---

## ① Screen Identity & Context

Screen: EmailAnalytics
Module: CRM (Communication sub-module)
Schema: NONE — aggregates over existing `notify` schema entities
Group: Notify (backend group containing email entities)

Dashboard Variant: **MENU_DASHBOARD** — own sidebar leaf at `crm/communication/emailanalytics` under `CRM_COMMUNICATION` parent menu (OrderBy=3). Not in any dashboard dropdown.

Business: Email Analytics is a **channel-specific drill-down dashboard** focused exclusively on the Email sending channel. It exists alongside (and is intentionally distinct from) #125 Communication Dashboard, which is the cross-channel rollup (Email + SMS + WhatsApp + Notification). This screen is consumed primarily by Marketing Leads, Fundraising Directors, and Communication Managers who need to assess email-campaign health, A/B test outcomes, deliverability, engagement-funnel drop-off, best-performing content, and per-recipient engagement. It rolls up data from `notify.EmailSendJob` (campaigns), `notify.EmailJobAnalytics` (pre-aggregated daily/hourly rollups), `notify.EmailSendQueue` (per-recipient events: opens/clicks/bounces/unsubs/complaints), and `notify.EmailClickTracking` (per-click link map with geo/device).

The screen has **TWO render modes** controlled by a `?campaignId={EmailSendJobId}` URL search param:
- **Overview Mode** (default — no `campaignId`): aggregate KPIs + 5-stage funnel + cross-campaign performance table + dual-line rate trend + best-performing content. Drives "how is our email channel performing this period?"
- **Detail Mode** (`?campaignId=X`): single-campaign drill-in with header metadata, 4-stage funnel, 4 engagement-cards, top-clicked-links map, 3-tile delivery breakdown (Delivered/Soft/Hard Bounce), paginated recipient activity table with status pills + filter pills + export, and 7×24 open-time heatmap. Drives "why did this specific campaign perform the way it did, and who do I follow up with?"

It earned its own menu slot because: (a) email-specific deliverability/engagement diagnostics are deep enough to need a dedicated surface that the cross-channel #125 cannot show without crowding, (b) it is deep-linkable from a campaign list / email report toast, (c) marketing teams typically pin it as a daily-check page distinct from the executive cross-channel rollup.

---

## ② Entity Definition

> Dashboards do NOT introduce a new entity. Seed two rows (`sett.Dashboards` + `sett.DashboardLayouts`) over the **existing** `notify`-schema entities.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `EMAILANALYTICS` | Mirrors `Menu.MenuCode` (link-via-SQL-UPDATE pattern — see § Seed step 2) |
| DashboardName | `Email Analytics` | Fallback label when `Menu.MenuName` is null |
| DashboardIcon | `solar:chart-bold` | Matches the seeded `Menu.MenuIcon` in `Pss2.0_Global_Menus_List.sql:308` |
| DashboardColor | NULL | No accent — neutral cyan/teal palette throughout via per-widget renderers |
| ModuleId | (resolved from `CRM`) | MUST equal `Menu.ModuleId` of `EMAILANALYTICS` |
| IsSystem | `true` | System-seeded |
| IsActive | `true` | — |
| MenuId | FK to `auth.Menus` row where `MenuCode='EMAILANALYTICS'` | Set via SQL UPDATE in seed step 2 (same pattern as Case #52 / Volunteer #57 / Donation #124 / Communication #125) |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

> One row per Dashboard. Stores OVERVIEW mode layout only. Detail mode is code-driven in `page.tsx`.

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | JSON: `{ "lg": [{i,x,y,w,h,minW,minH}, ...], "md": [...], "sm": [...] }` | See § ⑥ Grid Layout for 10-widget Overview placement |
| ConfiguredWidget | JSON: `[{instanceId, widgetId, title?, customParameter?}, ...]` | 10 instances for Overview (1 per Overview widget) |

### C. Widget Definitions (`sett.Widgets` + `sett.WidgetTypes`)

> 17 NEW WidgetType rows total: 10 for Overview (seeded as Dashboard widgets) + 7 for Detail (registered in `WIDGET_REGISTRY` for code-driven mounting, NOT seeded as Dashboard widgets).
> Only the 10 Overview widgets get corresponding `sett.Widgets` rows. Detail widgets are mounted directly by `page.tsx` in Detail mode.

**Overview WidgetTypes (seeded, 10):**

| WidgetTypeCode | ComponentPath (FE `WIDGET_REGISTRY` key) | Description |
|----------------|------------------------------------------|-------------|
| `EA_KPI_SENT` | `EmailAnalyticsKpiSentWidget` | Total Emails Sent KPI tile (large blue, paper-plane icon, delta) |
| `EA_KPI_DELIVERY_RATE` | `EmailAnalyticsKpiDeliveryRateWidget` | Delivery Rate KPI tile (green check, "X delivered" subtitle) |
| `EA_KPI_OPEN_RATE` | `EmailAnalyticsKpiOpenRateWidget` | Open Rate KPI tile (teal envelope-open, "X opens" subtitle, delta arrow) |
| `EA_KPI_CLICK_RATE` | `EmailAnalyticsKpiClickRateWidget` | Click Rate KPI tile (purple mouse-pointer, "X clicks" subtitle) |
| `EA_KPI_BOUNCE_RATE` | `EmailAnalyticsKpiBounceRateWidget` | Bounce Rate KPI tile (orange alert-triangle, "X bounced", reverse-delta — down is good) |
| `EA_KPI_UNSUB_RATE` | `EmailAnalyticsKpiUnsubRateWidget` | Unsubscribe Rate KPI tile (red user-minus, "X unsubscribed") |
| `EA_FUNNEL` | `EmailAnalyticsFunnelWidget` | 5-stage horizontal funnel (Sent → Delivered → Opened → Clicked → Converted) with gradient bars + percent labels |
| `EA_CAMPAIGN_PERF_TABLE` | `EmailAnalyticsCampaignPerformanceTableWidget` | Sortable cross-campaign table with rate-color-coded cells (green/yellow/red pills); row click → Detail mode |
| `EA_RATE_TRENDS_CHART` | `EmailAnalyticsRateTrendsChartWidget` | Dual-line area chart — Open Rate (teal #0e7490) + Click Rate (purple #8b5cf6); recharts |
| `EA_BEST_CONTENT` | `EmailAnalyticsBestContentWidget` | 3-card grid — Best Subject Line / Best Send Time / Best Campaign Type with success-green metric labels |

**Detail-mode WidgetTypes (registered in WIDGET_REGISTRY for visual consistency, NOT seeded as `sett.Widgets`, 7):**

| WidgetTypeCode (informational) | ComponentPath (FE `WIDGET_REGISTRY` key) | Description |
|---------------------------------|------------------------------------------|-------------|
| `EA_CAMPAIGN_HEADER_CARD` | `EmailAnalyticsCampaignHeaderCardWidget` | Campaign meta card — title, status pill, sent date/from/subject/recipients/template + "Resend to Non-Openers" CTA |
| `EA_CAMPAIGN_FUNNEL` | `EmailAnalyticsCampaignFunnelWidget` | 4-stage funnel scoped to one campaign (Sent → Delivered → Opened → Clicked) |
| `EA_ENGAGEMENT_METRICS` | `EmailAnalyticsEngagementMetricsWidget` | 4-card row — Unique Opens / Total Opens / Unique Clicks / Total Clicks with per-opener/per-clicker ratios |
| `EA_CLICK_MAP_TABLE` | `EmailAnalyticsClickMapTableWidget` | Top-clicked-links table with distribution bar gauges; rows tinted differently for CTA/FOOTER/SOCIAL/UNSUBSCRIBE categories |
| `EA_DELIVERY_BREAKDOWN` | `EmailAnalyticsDeliveryBreakdownWidget` | 3-tile colored breakdown (Delivered green / Soft Bounce yellow / Hard Bounce red) with description text |
| `EA_RECIPIENT_ACTIVITY_TABLE` | `EmailAnalyticsRecipientActivityTableWidget` | Paginated recipient list with status pills (Opened+Clicked / Opened / Delivered / Bounced / Unsubscribed) + filter pills + Export CSV |
| `EA_OPEN_TIME_HEATMAP` | `EmailAnalyticsOpenTimeHeatmapWidget` | 7-day × 24-hour grid with 5 intensity levels (level-0..level-4); peak callout label |

### D. Source Entities (read-only — what the widgets aggregate over)

| Source Entity | Path | Purpose | Aggregate(s) |
|---------------|------|---------|--------------|
| `EmailSendJob` | `Base.Domain/Models/NotifyModels/EmailSendJob.cs` | Campaign list, jobName, sendAt, subject, status, template | Filter scope; campaign-performance row keys; `TotalEmailsSend` for top-line "sent" denominator |
| `EmailJobAnalytics` | `Base.Domain/Models/NotifyModels/EmailJobAnalytics.cs` | **Pre-aggregated** daily+hourly rollups per job (`TotalSent`, `TotalDelivered`, `TotalOpens`, `UniqueOpens`, `TotalClicks`, `UniqueClicks`, `TotalBounced`, `TotalUnsubscribes`, computed `DeliveryRate`/`OpenRate`/`ClickRate`/`BounceRate`/`UnsubscribeRate`, hourly buckets for heatmap, `ProviderMetrics` jsonb) | KPI numerators/denominators; trend series; heatmap cells |
| `EmailSendQueue` | `Base.Domain/Models/NotifyModels/EmailSendQueue.cs` | Per-recipient event log: `IsOpened`/`IsClicked`/`IsBounced`/`IsUnsubscribed`/`OpenCount`/`ClickCount`/`FirstOpenedAt`/`BounceType`/`BounceReason`/`UnsubscribedAt` etc. | Recipient activity table; filter-pill counts; deliverability breakdown (soft vs hard bounce); engagement per-opener/per-clicker ratios |
| `EmailClickTracking` | `Base.Domain/Models/NotifyModels/EmailClickTracking.cs` | Per-click events with `LinkUrl`, `LinkCategory` (CTA/FOOTER/SOCIAL/UNSUBSCRIBE), device, geo | Click Map table — GROUP BY LinkUrl with COUNT, percent-of-total |
| `EmailTemplate` | `Base.Domain/Models/NotifyModels/EmailTemplate.cs` | Template metadata for header card | `templateName` projection in detail header |
| `Contact` | `Base.Domain/Models/CorgModels/Contact.cs` | Recipient identity (FullName, Code, Email) for Recipient Activity table; drill-down target | Project `contactName` for each `EmailSendQueue` row; drill-down: `?mode=read&id={contactId}` |

---

## ③ Source Entity & Aggregate Query Resolution

| Source Entity | Entity File Path | Aggregate Query Handler | GQL Field | Returns | Args (typical) |
|---------------|------------------|-------------------------|-----------|---------|----------------|
| `EmailSendJob` + `EmailJobAnalytics` + `EmailSendQueue` | per § ② D | `GetEmailAnalyticsOverview` (NEW — composite, Path C) | `getEmailAnalyticsOverview` | `EmailAnalyticsOverviewDto` | `dateFrom: DateTime?, dateTo: DateTime?, campaignIds: [int!]?` |
| `EmailSendJob` + `EmailJobAnalytics` + `EmailSendQueue` + `EmailClickTracking` + `EmailTemplate` | per § ② D | `GetEmailAnalyticsCampaignDetail` (NEW — per-campaign, Path B) | `getEmailAnalyticsCampaignDetail` | `EmailAnalyticsCampaignDetailDto` | `emailSendJobId: Int!` |
| `EmailSendQueue` + `Contact` | per § ② D | `GetEmailAnalyticsRecipientActivity` (NEW — paginated, Path B) | `getEmailAnalyticsRecipientActivity` | `PaginatedResponseOfRecipientActivityRowDto` | `emailSendJobId: Int!, filter: RecipientActivityFilterEnum (ALL/OPENED/CLICKED/NOT_OPENED/BOUNCED/UNSUBSCRIBED), pageInput: { page, pageSize }` |
| `EmailSendQueue` + `Contact` | per § ② D | `ExportEmailAnalyticsRecipientActivity` (NEW — CSV path) | `exportEmailAnalyticsRecipientActivity` | `byte[]` or `String` (base64) | `emailSendJobId: Int!, filter: RecipientActivityFilterEnum` |
| (none — drill-down only) | — | (existing) `ResendToNonOpenersPlaceholder` | `resendToNonOpeners` (Mutation) | `Boolean` | `emailSendJobId: Int!` — SERVICE_PLACEHOLDER: returns `true` + emits domain event; UI navigates to email-campaign-builder with prefill query params |

**Composite vs. Per-Widget strategy:**
- [x] **Composite for Overview** (Path C): ONE handler `GetEmailAnalyticsOverview` returns a fat DTO with all 10 Overview widget data fields. Best because all 10 widgets share the same date-range + campaign filter and refetch together when chips change.
- [x] **Per-widget for Detail mode** (Path B × 3): `GetEmailAnalyticsCampaignDetail` (singleton heavy fetch — Funnel + Engagement + Delivery + ClickMap + Heatmap), `GetEmailAnalyticsRecipientActivity` (paginated separately because table-pagination cadence is independent), `ExportEmailAnalyticsRecipientActivity` (separate to avoid coupling pagination payload to export payload).
- [ ] Hybrid not needed — Overview's composite stays composite; Detail's three handlers cover their independent cadences.

---

## ④ Business Rules & Validation

**Date Range Defaults:**
- Default range: **Last 30 days** (matches mockup `30 Days` chip active by default)
- Allowed presets: **7 Days / 30 Days / 90 Days / YTD / Custom**
- Custom range max span: **2 years** — to bound query cost; show inline error if exceeded

**Role-Scoped Data Access:**
- BUSINESSADMIN (and Communication Manager / Marketing Lead if roles exist): see all email jobs across all branches
- Branch-restricted roles: filter by `EmailSendJob.CompanyId = HttpContext.CompanyId` AND `EmailSendJob.BranchId IN (user's accessible branches)` if a BranchId column exists on EmailSendJob (verify in BA step — if column is absent, scope by `CompanyId` only and log as ⑫ ISSUE)
- All queries enforce **tenant scoping via `CompanyId` from HttpContext** (NEVER trust client-supplied CompanyId)

**Calculation Rules:**
- **Total Sent** = `SUM(EmailJobAnalytics.TotalSent)` over date window, scoped by job's company (and optional campaignIds filter)
- **Delivery Rate** = `SUM(TotalDelivered) / NULLIF(SUM(TotalSent), 0) × 100`
- **Open Rate** = `SUM(UniqueOpens) / NULLIF(SUM(TotalDelivered), 0) × 100` — denominator is DELIVERED, not SENT (industry standard for unique-open-rate)
- **Click Rate** = `SUM(UniqueClicks) / NULLIF(SUM(TotalDelivered), 0) × 100` — same denominator (CTR vs CTOR convention to disclose in widget tooltip)
- **Bounce Rate** = `SUM(TotalBounced) / NULLIF(SUM(TotalSent), 0) × 100`
- **Unsubscribe Rate** = `SUM(TotalUnsubscribes) / NULLIF(SUM(TotalDelivered), 0) × 100`
- **Conversion** = donations attributed to email — formula: `SUM(GlobalDonation.DonationAmount WHERE GlobalDonation.SourceCode = 'EMAIL_CAMPAIGN' AND … in window)` — **MAY BE DEFERRED**: if no `Source` column / attribution junction exists, render `0` with tooltip "Attribution wiring pending" and log as ISSUE-3 (HIGH)
- **Delta percent** (period over period) = `(current_value − previous_value) / NULLIF(previous_value, 0) × 100`; previous window = same duration immediately preceding current. Reverse-color for negative metrics: Bounce Rate ↓ is good (green), Open Rate ↑ is good
- **Best Subject Line** = top `EmailSendJob.EmailSubject` ranked by per-job `UniqueOpens / TotalDelivered` (min job-sample-size 100 sent — guards against tiny-sample noise)
- **Best Send Time** = `EmailJobAnalytics` GROUP BY (`EXTRACT(DOW from AnalyticsDate)`, `AnalyticsHour`) ORDER BY AVG(`OpenRate`) DESC LIMIT 1 — format as `"Tuesday 10:00 AM"`
- **Best Campaign Type** = comparison aggregate — for V1 derive from `SendJobTypeId` MasterData (e.g., AUTOMATED vs MANUAL vs SCHEDULED) — emit human label + comparator percent

**Multi-Currency Rules:** N/A — Email Analytics has no currency aggregations (Conversion may need it once attribution is wired; defer per ISSUE-3).

**Widget-Level Rules:**
- A widget is RENDERED only if `WidgetRole(WidgetId, currentRoleId, HasAccess=true)` row exists. Default: BUSINESSADMIN gets all 10 Overview widgets.
- **Workflow**: None — read-only dashboard.

**Detail-Mode Filter Pill Rules (Recipient Activity table):**
- `ALL` — no filter
- `OPENED` — `IsOpened = true`
- `CLICKED` — `IsClicked = true`
- `NOT_OPENED` — `IsDelivered = true AND IsOpened = false AND IsBounced = false AND IsUnsubscribed = false`
- `BOUNCED` — `IsBounced = true`
- `UNSUBSCRIBED` — `IsUnsubscribed = true`

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Owns its own sidebar leaf at `crm/communication/emailanalytics` under CRM_COMMUNICATION (OrderBy=3). Marketing leads pin and deep-link this page; it is not part of any dashboard dropdown. **Exception note**: this dashboard's parent menu is `CRM_COMMUNICATION` (a feature module parent), not `CRM_DASHBOARDS` (the usual MENU_DASHBOARD parent). The dashboard infra does NOT require parent-must-be-`_DASHBOARDS` — sidebar auto-injection only kicks in for `*_DASHBOARDS` parents, but EMAILANALYTICS is already hard-seeded in `Pss2.0_Global_Menus_List.sql:308`, so auto-injection is irrelevant. See §⑫ ISSUE-1.

**Backend Implementation Path** — pick per widget:
- [ ] Path A (Postgres function via `generateWidgets`) — **NOT USED** for any widget here (composite GQL is cleaner for the Overview shape; Detail handlers need shape-bound projection)
- [x] **Path C — Composite GQL** for ALL 10 Overview widgets via `getEmailAnalyticsOverview` (one round trip on filter change)
- [x] **Path B — Per-widget GQL** for Detail mode: `getEmailAnalyticsCampaignDetail` (single fetch when entering Detail), `getEmailAnalyticsRecipientActivity` (paginated, independent cadence), `exportEmailAnalyticsRecipientActivity` (CSV)

**Backend Patterns Required (paths B/C):**
- [x] Aggregate query handlers — 1 composite for Overview + 3 per-widget for Detail
- [x] Tenant scoping (CompanyId from HttpContext) — every handler
- [x] Date-range parameterized queries (`dateFrom`, `dateTo` clamped to a max 2-year span)
- [x] Role-scoped data filtering — if `EmailSendJob.BranchId` column exists, apply branch scoping for non-admin roles
- [ ] Materialized view / cached aggregate — NOT NEEDED for V1 (`EmailJobAnalytics` is already a pre-aggregated rollup table; queries will be fast)
- [x] Drill-down arg handler — `resendToNonOpeners` mutation (SERVICE_PLACEHOLDER) returns success + FE deep-links to email-campaign-builder with `?srcJobId={id}&audience=non-openers`

**Frontend Patterns Required:**
- [x] Custom page at `[lang]/crm/communication/emailanalytics/page.tsx` (overwrites UnderConstruction stub) — implements URL-state mode switching via `useSearchParams().get('campaignId')`
- [x] **NEW renderers** per widget under `dashboards/widgets/email-analytics-dashboard-widgets/` (17 files total: 10 Overview + 7 Detail; each in its own subfolder following Donation/Communication dashboard precedent OR one folder with all 17 — match #125 Communication Dashboard's existing folder style for consistency)
- [x] All 17 renderer keys registered in `dashboard-widget-registry.tsx` `WIDGET_REGISTRY` (even Detail keys — they're code-mounted but registry presence keeps the pattern uniform and enables future migration to layout-driven Detail)
- [x] Query registry registration: 3 new GQL docs added to `dashboard-widget-query-registry.tsx` `QUERY_REGISTRY` keyed `GET_EMAIL_ANALYTICS_OVERVIEW`, `GET_EMAIL_ANALYTICS_CAMPAIGN_DETAIL`, `GET_EMAIL_ANALYTICS_RECIPIENT_ACTIVITY`
- [x] Toolbar with date-range chip group + Campaign dropdown (uses ApiSelectV2 against `getAllEmailSendJobList` — verify existing query) implemented in the custom page chrome, NOT via `<MenuDashboardComponent />` (we do NOT use the standard menu-dashboard wrapper because mode-switching diverges)
- [x] Skeleton states matching widget shapes per renderer (no generic shimmer rectangles)
- [x] MENU_DASHBOARD-only chrome:
      • NO `<DashboardHeader />` (Create/Switcher/Edit chrome is irrelevant here)
      • Lean header: title (`Email Analytics` + chart-bar icon) + date-range chips + Campaign dropdown + Refresh icon
      • Detail mode replaces the chrome with: Back link + Campaign Header Card

**Why we do NOT use `<MenuDashboardComponent />` for this dashboard:**
- The standard menu-dashboard component renders a single fixed widget grid from `DashboardLayout.LayoutConfig`. This screen needs **mode-switching** between Overview's widget grid and Detail's code-driven layout, which the standard component does not support and we should not force.
- The custom page directly mounts widget renderers from `WIDGET_REGISTRY` for Overview mode (preserving the visual conventions and skeleton standards) AND directly mounts Detail widget components for Detail mode.
- This is a documented divergence — log as ⑫ ISSUE-2 (MED) so future "extract shared mode-switch helper" refactor is on the radar.

---

## ⑥ UI/UX Blueprint

### Page Chrome — Overview Mode

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 📊 Email Analytics          [7d] [30d✓] [90d] [YTD] [Custom]  [▼ All Campaigns]  │
├─────────────────────────────────────────────────────────────────────────────────┤
│  [KPI: Sent]    [KPI: Delivery]   [KPI: Open]                                    │
│  [KPI: Click]   [KPI: Bounce]     [KPI: Unsub]                                   │
│                                                                                  │
│  ┌─ Email Funnel ────────────────────────────────────────────────────────────┐  │
│  │  [Sent ▮▮▮▮▮▮] → [Delivered ▮▮▮▮▮] → [Opened ▮▮▮] → [Clicked ▮] → [Conv]  │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌─ Campaign Performance ──────────────── (click name → Detail mode) ─────────┐ │
│  │  Campaign | Sent | Delivered | Opened | OpenRate | Clicked | ClickRate | …  │ │
│  │  …sortable rows with green/yellow/red rate pills…                            │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  ┌─ Open & Click Rate Trends ────────────────────────────────────────────────┐  │
│  │  ──── teal Open Rate line ────                                              │ │
│  │  ──── purple Click Rate line ──                                             │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  [Best Subject Line]      [Best Send Time]      [Best Campaign Type]            │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Page Chrome — Detail Mode (`?campaignId=X`)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ ← Back to Overview                                                               │
│                                                                                  │
│ ┌─ Campaign Header Card ───────────────────────────────────────────────────┐    │
│ │  Monthly Newsletter #4                       [Sent ✓]  [↻ Resend Non-Openers]│
│ │  Sent: Apr 10, 10:00 AM   From: Hope Foundation   Recipients: 8,234           │
│ │  Subject: "Your April Impact Report — 3 Amazing Stories"                      │
│ └──────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│ ┌─ Campaign Funnel ───────────────────────────────────────────────────────┐    │
│ │   Sent (8,234) → Delivered (8,102 / 98.4%) → Opened (3,095 / 38.2%) → Clicked (494 / 6.1%) │
│ └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│ [Unique Opens]   [Total Opens]   [Unique Clicks]   [Total Clicks]               │
│  3,095 (38.2%)    4,521           494 (6.1%)        721                          │
│                                                                                  │
│ ┌─ Click Map — Top Links ──────────────────────────────────────────────────┐    │
│ │  Link                            | Clicks | % of Total | Distribution      │   │
│ │  💰 "Donate Now" button          | 234    | 32.5%      | ████████████████  │   │
│ │  …                                                                          │   │
│ └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│ ┌─ Delivery Breakdown ────────────────────────────────────────────────────┐    │
│ │  [Delivered 8,102 ✓ green]   [Soft Bounce 87 ⚠ yellow]   [Hard Bounce 45 ⛔ red]  │
│ └──────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│ ┌─ Recipient Activity ─────────────────────── [⬇ Export CSV] ──────────────┐    │
│ │  [All✓] [Opened] [Clicked] [Not Opened] [Bounced] [Unsubscribed]            │   │
│ │  Recipient        | Email           | Status              | Opened | …       │   │
│ │  (Sarah Johnson)  | sarah.j@...     | [Opened + Clicked]  | Yes    | …       │   │
│ │  …                                                                            │   │
│ └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│ ┌─ Open Time Heatmap  (Peak: Tuesday 10–12 AM)  ───────────────────────────┐    │
│ │      0  1  2  3  4 …  10 11 12 …                                            │   │
│ │  Mon ░  ░  ░  ░  ░ … ▓▓ ▓▓ ▓▓ …                                              │   │
│ │  Tue ░  ░  ░  ░  ░ … ██ ██ ██ …                                              │   │
│ │  …                                                                           │   │
│ └──────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Grid Layout — react-grid-layout config (OVERVIEW MODE ONLY)

> Detail mode is code-driven, NOT react-grid-layout. The seed's LayoutConfig contains ONLY the Overview placements below.

**Breakpoints:**
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
| `kpi-sent` | EA_KPI_SENT | 0 | 0 | 4 | 2 | 3 | 2 | KPI card (blue, larger weight — primary volume metric) |
| `kpi-delivery-rate` | EA_KPI_DELIVERY_RATE | 4 | 0 | 4 | 2 | 3 | 2 | KPI card (green) |
| `kpi-open-rate` | EA_KPI_OPEN_RATE | 8 | 0 | 4 | 2 | 3 | 2 | KPI card (teal — most-watched metric) |
| `kpi-click-rate` | EA_KPI_CLICK_RATE | 0 | 2 | 4 | 2 | 3 | 2 | KPI card (purple) |
| `kpi-bounce-rate` | EA_KPI_BOUNCE_RATE | 4 | 2 | 4 | 2 | 3 | 2 | KPI card (orange) — reverse delta |
| `kpi-unsub-rate` | EA_KPI_UNSUB_RATE | 8 | 2 | 4 | 2 | 3 | 2 | KPI card (red) |
| `funnel` | EA_FUNNEL | 0 | 4 | 12 | 3 | 8 | 3 | 5-stage horizontal funnel — full width |
| `campaign-perf` | EA_CAMPAIGN_PERF_TABLE | 0 | 7 | 12 | 5 | 8 | 4 | Sortable cross-campaign table — full width |
| `rate-trends` | EA_RATE_TRENDS_CHART | 0 | 12 | 8 | 4 | 6 | 3 | Dual-line chart — 8 col |
| `best-content` | EA_BEST_CONTENT | 8 | 12 | 4 | 4 | 4 | 3 | 3-card stack — 4 col (sits next to chart on lg; stacks on md/sm) |

**Widget placement at `md` (8-col):** KPI tiles become 4-cols wide × 2 rows × 3 cols; funnel 8×3; table 8×5; chart 8×4; best-content 8×3 (below chart).

**Widget placement at `sm` (6-col):** KPIs become 3-cols wide × 4 rows; chart full-width.

### Widget Catalog — Overview Mode

| # | InstanceId | Title | WidgetType.ComponentPath | Path | Data Source | Filters Honored | Drill-Down |
|---|-----------|-------|--------------------------|------|-------------|------------------|-----------|
| 1 | `kpi-sent` | Total Emails Sent | `EmailAnalyticsKpiSentWidget` | C | `GET_EMAIL_ANALYTICS_OVERVIEW → totalSent` | dateRange, campaignIds | — |
| 2 | `kpi-delivery-rate` | Delivery Rate | `EmailAnalyticsKpiDeliveryRateWidget` | C | `… → deliveryRate, totalDelivered` | dateRange, campaignIds | — |
| 3 | `kpi-open-rate` | Open Rate | `EmailAnalyticsKpiOpenRateWidget` | C | `… → openRate, uniqueOpens` | dateRange, campaignIds | — |
| 4 | `kpi-click-rate` | Click Rate | `EmailAnalyticsKpiClickRateWidget` | C | `… → clickRate, uniqueClicks` | dateRange, campaignIds | — |
| 5 | `kpi-bounce-rate` | Bounce Rate | `EmailAnalyticsKpiBounceRateWidget` | C | `… → bounceRate, totalBounced` | dateRange, campaignIds | — |
| 6 | `kpi-unsub-rate` | Unsubscribe Rate | `EmailAnalyticsKpiUnsubRateWidget` | C | `… → unsubscribeRate, totalUnsubscribed` | dateRange, campaignIds | — |
| 7 | `funnel` | Email Funnel | `EmailAnalyticsFunnelWidget` | C | `… → funnel { sent, delivered, opened, clicked, converted }` | dateRange, campaignIds | — (stages not clickable in Overview — they are clickable in Detail mode) |
| 8 | `campaign-perf` | Campaign Performance | `EmailAnalyticsCampaignPerformanceTableWidget` | C | `… → campaignPerformance[]` | dateRange | Row name click → `?campaignId={emailSendJobId}` (Detail mode) |
| 9 | `rate-trends` | Open & Click Rate Trends | `EmailAnalyticsRateTrendsChartWidget` | C | `… → trends[] { date, openRate, clickRate }` | dateRange, campaignIds | — |
| 10 | `best-content` | Best Performing Content | `EmailAnalyticsBestContentWidget` | C | `… → bestSubjectLine, bestSendTime, bestCampaignType` | dateRange | — (V2: click best subject → filter campaign table by similar subjects) |

### Widget Catalog — Detail Mode (code-mounted, NOT in DashboardLayout)

| # | Component | Data Source | Filters Honored | Drill-Down |
|---|-----------|-------------|------------------|-----------|
| 1 | `EmailAnalyticsCampaignHeaderCardWidget` | `getEmailAnalyticsCampaignDetail → jobMeta` | none (campaignId only) | "Resend to Non-Openers" → email-campaign-builder with `?srcJobId={id}&audience=non-openers` (SERVICE_PLACEHOLDER) |
| 2 | `EmailAnalyticsCampaignFunnelWidget` | `… → funnel` | none | Stage click → filter Recipient Activity table by status (Opened → filter=OPENED, etc.) |
| 3 | `EmailAnalyticsEngagementMetricsWidget` | `… → engagement` | none | — |
| 4 | `EmailAnalyticsClickMapTableWidget` | `… → clickMap[]` | none | Link row click → opens link in new tab |
| 5 | `EmailAnalyticsDeliveryBreakdownWidget` | `… → delivery` | none | Click tile → filter Recipient Activity by status (Bounced → filter=BOUNCED) |
| 6 | `EmailAnalyticsRecipientActivityTableWidget` | `getEmailAnalyticsRecipientActivity` (paginated) + `exportEmailAnalyticsRecipientActivity` | filter pill (ALL/OPENED/CLICKED/NOT_OPENED/BOUNCED/UNSUBSCRIBED) | Recipient name → `/crm/contact/contact?mode=read&id={contactId}` |
| 7 | `EmailAnalyticsOpenTimeHeatmapWidget` | `… → openTimeHeatmap[]` (7 days × 24 hours) | none | Cell hover → tooltip ("Tue 10 AM — 187 opens") |

### KPI Cards (detail per card)

| # | Title | Value Source | Format | Subtitle | Delta Indicator | Color Cue |
|---|-------|--------------|--------|----------|------------------|-----------|
| 1 | Total Emails Sent | `totalSent` | integer + thousand-separator | `"This period {deltaPct≥0 ? '+' : ''}{deltaPct}%"` | inline arrow + colored % (green up / red down) | blue (#3b82f6) icon paper-plane |
| 2 | Delivery Rate | `deliveryRate` | percent (1 decimal) | `"{totalDelivered:n0} delivered"` + delta | "Stable" if abs(delta)<0.5%, else colored arrow | green (#22c55e) icon check-circle |
| 3 | Open Rate | `openRate` | percent (1 decimal) | `"{uniqueOpens:n0} opens"` + delta | green up arrow / red down arrow | teal (#0e7490) icon envelope-open |
| 4 | Click Rate | `clickRate` | percent (1 decimal) | `"{uniqueClicks:n0} clicks"` + delta | green up / red down | purple (#a855f7) icon mouse-pointer |
| 5 | Bounce Rate | `bounceRate` | percent (1 decimal) | `"{totalBounced:n0} bounced"` + delta | **REVERSE**: green DOWN arrow (better) / red UP arrow (worse) | orange (#f97316) icon alert-triangle |
| 6 | Unsubscribe Rate | `unsubscribeRate` | percent (1 decimal) | `"{totalUnsubscribed:n0} unsubscribed"` + delta | **REVERSE**: green DOWN / red UP | red (#ef4444) icon user-minus |

### Charts (detail per chart)

| # | Title | Type | X | Y | Source | Filters Honored | Empty/Tooltip |
|---|-------|------|---|---|--------|------------------|---------------|
| 1 | Email Funnel (Overview) | horizontal-funnel | stage label (Sent / Delivered / Opened / Clicked / Converted) | absolute count | `funnel { sent, delivered, opened, clicked, converted }` | dateRange, campaignIds | Empty: "No email activity in selected range"; Tooltip per stage: count + percent of Sent |
| 2 | Rate Trends | dual-line (recharts `<LineChart>` with `<Area>` shading) | date (last N days from range) | percent 0–50 | `trends[] { date, openRate, clickRate }` | dateRange, campaignIds | Empty: "No trend data — select a wider date range"; Tooltip: date + openRate + clickRate |
| 3 | Campaign Funnel (Detail) | horizontal-funnel (4-stage) | Sent / Delivered / Opened / Clicked | absolute count | `getEmailAnalyticsCampaignDetail.funnel` | none (campaignId only) | Click stage → filter Recipient table |
| 4 | Open Time Heatmap (Detail) | 7×24 grid | hour (0–23) × day (Mon–Sun) | open count → level 0–4 (`f1f5f9 → ccfbf1 → 5eead4 → 14b8a6 → 0e7490`) | `openTimeHeatmap[]` | none | Empty: "No open data for this campaign"; Tooltip per cell: day + hour + opens count |

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Date Range | chip group (7d/30d✓/90d/YTD/Custom) | 30 Days | All Overview widgets (Detail widgets are campaign-scoped, not date-scoped) | Custom opens date-range picker dialog (cap 2 years) |
| Campaign | ApiSelectV2 single-select dropdown | "All Campaigns" | Overview KPIs/Funnel/Trends (NOT Performance Table — table shows all campaigns; NOT Best Content — derived cross-campaign) | When selection != "All", **navigates to Detail mode** (`?campaignId={emailSendJobId}`). When in Detail mode, dropdown reflects current campaign — selecting "All Campaigns" returns to Overview |
| Recipient Status (Detail only) | filter pill group (ALL✓/OPENED/CLICKED/NOT_OPENED/BOUNCED/UNSUBSCRIBED) | All | Recipient Activity table only | Click pill → refetch table with new filter; counts shown next to each pill (V2 — V1 may omit counts to ship faster, log as ⑫ ISSUE-4) |

### Drill-Down / Navigation Map

| From Widget / Element | Click On | Navigates To | Prefill |
|-----------------------|----------|--------------|---------|
| Campaign Performance Table | Campaign name link | Detail mode (same page) | `?campaignId={emailSendJobId}` |
| Campaign dropdown (Overview header) | non-"All" option | Detail mode | `?campaignId={emailSendJobId}` |
| Recipient Activity (Detail) | Recipient name | `/crm/contact/contact?mode=read&id={contactId}` | — (existing contact route) |
| Campaign Funnel stage (Detail) | Stage bar | Recipient Activity filter pill | URL hash `#recipients` + scroll + activate filter pill |
| Delivery Breakdown tile (Detail) | Soft/Hard Bounce tile | Recipient Activity filter pill | filter=BOUNCED + scroll |
| Click Map row (Detail) | Link URL | opens in new tab | rel="noopener" |
| Header "Resend to Non-Openers" (Detail) | Button | `/crm/communication/emailcampaign?mode=new&srcJobId={id}&audience=non-openers` | SERVICE_PLACEHOLDER — toasts "Email Campaign Builder integration pending" if route lacks `srcJobId` handler |
| Back link (Detail) | Arrow | Overview mode | clears `?campaignId` |

### User Interaction Flow

1. **Initial load** (no `campaignId`):
   - User clicks sidebar "Communication → Email Analytics" → URL becomes `/[lang]/crm/communication/emailanalytics`.
   - Page reads URL → no campaignId → renders OVERVIEW mode chrome.
   - Apollo fires `getEmailAnalyticsOverview({ dateFrom: now-30d, dateTo: now })`.
   - 10 widgets render skeleton states matching their shapes.
   - On data arrival → all 10 widgets render simultaneously.
2. **Date chip change**: chip click → URL search param `?range=7d|30d|90d|ytd|custom` (or no param for default) → query refetches with new window → all widgets re-render.
3. **Campaign dropdown change** to a specific campaign: navigates to `?campaignId=X` → mode-switch.
4. **Campaign name click in Performance Table**: navigates to `?campaignId=X` → mode-switch.
5. **Detail mode load**:
   - Page reads `?campaignId=X` → renders DETAIL mode chrome.
   - Fires `getEmailAnalyticsCampaignDetail(emailSendJobId: X)` → singleton fetch returns Funnel + Engagement + Delivery + ClickMap + Heatmap.
   - Fires `getEmailAnalyticsRecipientActivity(emailSendJobId: X, filter: ALL, page: 1, pageSize: 25)` separately.
   - Renders 7 widgets in fixed code-driven layout.
6. **Recipient filter pill click** (Detail): refetches `getEmailAnalyticsRecipientActivity` with new filter; table widget re-renders skeleton + new data.
7. **Export CSV click** (Detail): fires `exportEmailAnalyticsRecipientActivity` → if returns base64/csv → trigger browser download; if SERVICE_PLACEHOLDER → toast "Export integration pending" + log to console.
8. **Back link click** (Detail): clears `?campaignId` → mode-switch to Overview.
9. **Drill-down click**: navigates per Drill-Down Map.
10. **Empty / loading / error states**: each widget renders its own skeleton during fetch; error → red mini banner + Retry; empty → muted icon + "No data in selected range" message.

---

## ⑦ Substitution Guide

**Canonical Reference**: `#125 Communication Dashboard` (most similar — also under Communication, also MENU_DASHBOARD, COMPLETED 2026-05-xx)

| Canonical (#125 CommunicationDashboard) | → This Dashboard (EmailAnalytics) | Context |
|------------------------------------------|------------------------------------|---------|
| `CommunicationDashboard` | `EmailAnalyticsDashboard` (or `EmailAnalytics` — pick consistent naming) | Class/code root |
| `COMMUNICATIONDASHBOARD` | `EMAILANALYTICS` | DashboardCode + Menu.MenuCode |
| `communication-dashboard-widgets/` | `email-analytics-dashboard-widgets/` | FE widget folder |
| `CommunicationHeroKpiWidget`, `CommunicationDeltaKpiWidget`, etc. | `EmailAnalyticsKpiSentWidget`, `EmailAnalyticsKpiOpenRateWidget`, etc. | Widget component class names + `WIDGET_REGISTRY` keys |
| `/crm/dashboards/communicationdashboard` | `/crm/communication/emailanalytics` | Route path (DIFFERENT parent — Email Analytics lives in Communication module sidebar, not Dashboards parent) |
| `notify` | `notify` | Source schema (SAME — both pull email data) |
| `CRM` | `CRM` | Parent module code (SAME) |
| `CRM_DASHBOARDS` | `CRM_COMMUNICATION` | ParentMenu (DIFFERENT — this is the EXCEPTION; #38's parent is Communication-module not Dashboards) |
| `GetCommunicationDashboardData` | `GetEmailAnalyticsOverview` + `GetEmailAnalyticsCampaignDetail` + `GetEmailAnalyticsRecipientActivity` | BE composite + Detail handlers |

---

## ⑧ File Manifest

### Backend Files

| # | File | Path | Required When |
|---|------|------|---------------|
| 1 | EmailAnalyticsSchemas | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/NotifySchemas/EmailAnalyticsSchemas.cs` | always |
| 2 | GetEmailAnalyticsOverview (composite Path C query handler) | `Base.Application/Business/NotifyBusiness/EmailAnalytics/Queries/GetEmailAnalyticsOverview.cs` | always |
| 3 | GetEmailAnalyticsCampaignDetail (per-campaign Path B query handler) | `Base.Application/Business/NotifyBusiness/EmailAnalytics/Queries/GetEmailAnalyticsCampaignDetail.cs` | always |
| 4 | GetEmailAnalyticsRecipientActivity (paginated Path B query handler) | `Base.Application/Business/NotifyBusiness/EmailAnalytics/Queries/GetEmailAnalyticsRecipientActivity.cs` | always |
| 5 | ExportEmailAnalyticsRecipientActivity (export query handler) | `Base.Application/Business/NotifyBusiness/EmailAnalytics/Queries/ExportEmailAnalyticsRecipientActivity.cs` | always (SERVICE_PLACEHOLDER body if CSV-export infra missing) |
| 6 | ResendToNonOpeners (mutation handler — SERVICE_PLACEHOLDER) | `Base.Application/Business/NotifyBusiness/EmailAnalytics/Commands/ResendToNonOpeners.cs` | always (placeholder body; FE deep-links to email-campaign-builder regardless) |
| 7 | EmailAnalyticsQueries endpoint | `Base.API/EndPoints/Notify/Queries/EmailAnalyticsQueries.cs` | always |
| 8 | EmailAnalyticsMutations endpoint | `Base.API/EndPoints/Notify/Mutations/EmailAnalyticsMutations.cs` | always |

### Backend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | NotifyMappings.cs | TypeAdapterConfig for new DTOs (EmailAnalyticsOverviewDto, EmailAnalyticsCampaignDetailDto, RecipientActivityRowDto, etc.) |
| 2 | DependencyInjection.cs (Notify or main Base.Application) | register new endpoint classes if reflection-discovery isn't sufficient — verify existing pattern |
| 3 | GraphQL schema (HotChocolate) | register `EmailAnalyticsQueries` + `EmailAnalyticsMutations` types — verify how #125 registered |

### Frontend Files

| # | File | Path | Required When |
|---|------|------|---------------|
| 1 | EmailAnalyticsDto types | `Pss2.0_Frontend/src/domain/entities/notify-service/EmailAnalyticsDto.ts` | always |
| 2 | GQL queries | `Pss2.0_Frontend/src/infrastructure/gql-queries/notify-queries/EmailAnalyticsQuery.ts` (3 queries + 1 mutation) | always |
| 3 | 10 Overview widget renderers | `src/presentation/components/custom-components/dashboards/widgets/email-analytics-dashboard-widgets/{Kebab-Name}.tsx` | always |
| 4 | 7 Detail widget components | `src/presentation/components/custom-components/dashboards/widgets/email-analytics-dashboard-widgets/{Kebab-Name}.tsx` | always |
| 5 | Skeleton components (one per widget shape) | `src/presentation/components/custom-components/dashboards/widgets/email-analytics-dashboard-widgets/skeletons/{Kebab-Name}-Skeleton.tsx` | always — match #125 pattern; may colocate as sub-files instead of separate folder |
| 6 | Widget folder barrel | `src/presentation/components/custom-components/dashboards/widgets/email-analytics-dashboard-widgets/index.ts` | always |
| 7 | Custom page (overwrites UnderConstruction stub) | `src/app/[lang]/crm/communication/emailanalytics/page.tsx` | always — implements URL-state mode switching |
| 8 | EmailAnalytics shared components | `src/presentation/components/custom-components/dashboards/widgets/email-analytics-dashboard-widgets/shared/{date-range-chips,campaign-select-toolbar,best-content-card,rate-cell,status-badge}.tsx` (consolidate per #125 precedent) | always |
| 9 | Mode-switch helper (if extracted) | `src/presentation/components/custom-components/dashboards/widgets/email-analytics-dashboard-widgets/email-analytics-page.tsx` | optional — keep page.tsx slim by extracting client-component logic |

### Frontend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | extend `WIDGET_REGISTRY` with 17 new entries (10 Overview + 7 Detail) |
| 2 | `dashboard-widget-query-registry.tsx` | extend `QUERY_REGISTRY` with 3 new entries (`GET_EMAIL_ANALYTICS_OVERVIEW`, `GET_EMAIL_ANALYTICS_CAMPAIGN_DETAIL`, `GET_EMAIL_ANALYTICS_RECIPIENT_ACTIVITY`) |
| 3 | DTO barrel `src/domain/entities/notify-service/index.ts` | re-export `EmailAnalyticsDto` types |
| 4 | GQL barrel `src/infrastructure/gql-queries/notify-queries/index.ts` | re-export `EmailAnalyticsQuery` doc |
| 5 | sidebar / menu config | NO CHANGE — `EMAILANALYTICS` menu already seeded at `Pss2.0_Global_Menus_List.sql:308` |

### DB Seed

`Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/EmailAnalytics-sqlscripts.sql` (preserve `dyanmic` typo per repo convention):

| Step | Item | Idempotency |
|------|------|-------------|
| 1 | `INSERT INTO sett."WidgetTypes" (WidgetTypeName, WidgetTypeCode, ComponentPath, ...)` × 17 rows (10 Overview + 7 Detail, IsSystem=true) | `WHERE NOT EXISTS (SELECT 1 FROM sett."WidgetTypes" WHERE "WidgetTypeCode" = '…')` |
| 2 | `INSERT INTO sett."Dashboards" (DashboardCode, DashboardName, DashboardIcon, ModuleId, IsSystem, IsActive, CompanyId)` × 1 row (DashboardCode='EMAILANALYTICS', icon='solar:chart-bold') | NOT EXISTS on DashboardCode |
| 3 | `INSERT INTO sett."Widgets" (WidgetName, WidgetTypeId, DefaultQuery, DefaultParameters, ModuleId, MinHeight, MinWidth, OrderBy, IsSystem, CompanyId)` × 10 rows (Overview widgets only; DefaultQuery=`GET_EMAIL_ANALYTICS_OVERVIEW` for each; DefaultParameters JSON with dateFrom/dateTo placeholders) | NOT EXISTS on (WidgetName, CompanyId) |
| 4 | `INSERT INTO sett."DashboardLayouts" (DashboardId, LayoutConfig, ConfiguredWidget)` × 1 row — JSON values for Overview's 10 instances at lg/md/sm breakpoints | NOT EXISTS via correlated subquery on DashboardId |
| 5 | `INSERT INTO auth."WidgetRoles" (WidgetId, RoleId, HasAccess)` for BUSINESSADMIN × 10 rows (one per Overview widget) | NOT EXISTS on (WidgetId, RoleId) |
| 6 | `UPDATE sett."Dashboards" SET "MenuId" = (SELECT MenuId FROM auth."Menus" WHERE "MenuCode" = 'EMAILANALYTICS' AND IsActive=true LIMIT 1) WHERE "DashboardCode" = 'EMAILANALYTICS' AND "MenuId" IS NULL` | guarded by `MenuId IS NULL` |
| 7 | `INSERT INTO auth."MenuCapabilities" (MenuId, CapabilityId)` for READ/EXPORT/ISMENURENDER on the EMAILANALYTICS menu | NOT EXISTS on (MenuId, CapabilityId) |
| 8 | `INSERT INTO auth."RoleCapabilities" (RoleId, MenuId, CapabilityId, HasAccess)` for BUSINESSADMIN × READ + EXPORT + ISMENURENDER on EMAILANALYTICS menu | NOT EXISTS on (RoleId, MenuId, CapabilityId) |
| 9 | (NO sample/fixture data — production emails seed `EmailJobAnalytics` automatically; for QA, ship a separate dev-only fixture file) | — |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

MenuName: Email Analytics                # ALREADY SEEDED in Pss2.0_Global_Menus_List.sql:308 — do NOT re-insert
MenuCode: EMAILANALYTICS                  # already seeded
ParentMenu: CRM_COMMUNICATION             # EXCEPTION — not CRM_DASHBOARDS; this dashboard lives in the Communication module sidebar
Module: CRM
MenuUrl: crm/communication/emailanalytics # already seeded
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT, ISMENURENDER

GridFormSchema: SKIP                       # dashboards have no RJSF form
GridCode: EMAILANALYTICS

# Dashboard-specific seed inputs
DashboardCode: EMAILANALYTICS
DashboardName: Email Analytics
DashboardIcon: solar:chart-bold            # matches Menu.MenuIcon already seeded
DashboardColor: null
IsSystem: true
DashboardKind: MENU_DASHBOARD              # Dashboard.MenuId set via SQL UPDATE in seed step 6 (raw-SQL-UPDATE established pattern — `linkDashboardToMenu` mutation NOT BUILT yet per audit)
OrderBy: 3                                 # already on Menu.OrderBy — do NOT re-insert; for reference only
WidgetGrants:                              # 10 Overview widgets — Detail widgets are not seeded
  - EA_KPI_SENT: BUSINESSADMIN
  - EA_KPI_DELIVERY_RATE: BUSINESSADMIN
  - EA_KPI_OPEN_RATE: BUSINESSADMIN
  - EA_KPI_CLICK_RATE: BUSINESSADMIN
  - EA_KPI_BOUNCE_RATE: BUSINESSADMIN
  - EA_KPI_UNSUB_RATE: BUSINESSADMIN
  - EA_FUNNEL: BUSINESSADMIN
  - EA_CAMPAIGN_PERF_TABLE: BUSINESSADMIN
  - EA_RATE_TRENDS_CHART: BUSINESSADMIN
  - EA_BEST_CONTENT: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

### Queries

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| `getEmailAnalyticsOverview` | `EmailAnalyticsOverviewDto` | `dateFrom: DateTime?, dateTo: DateTime?, campaignIds: [Int!]?` | composite — drives all 10 Overview widgets |
| `getEmailAnalyticsCampaignDetail` | `EmailAnalyticsCampaignDetailDto` | `emailSendJobId: Int!` | singleton — drives 6 Detail widgets (header/funnel/engagement/delivery/clickmap/heatmap) |
| `getEmailAnalyticsRecipientActivity` | `PaginatedResponseOfRecipientActivityRowDto` | `emailSendJobId: Int!, filter: RecipientActivityFilterEnum, pageInput: { page, pageSize }` | paginated — drives Recipient Activity table only |
| `exportEmailAnalyticsRecipientActivity` | `String` (base64 CSV) OR `Boolean` (placeholder) | `emailSendJobId: Int!, filter: RecipientActivityFilterEnum` | CSV export — SERVICE_PLACEHOLDER if CSV-export infra missing (toast + console) |
| `getAllEmailSendJobList` (EXISTING) | list of EmailSendJob rows | (none/scope filters) | populates Campaign dropdown — VERIFY existing handler matches expected projection |

### Mutations

| GQL Field | Returns | Key Args | Notes |
|-----------|---------|----------|-------|
| `resendToNonOpeners` | `Boolean` | `emailSendJobId: Int!` | SERVICE_PLACEHOLDER — returns `true`; FE shows toast + deep-links to email-campaign-builder with `?srcJobId=…&audience=non-openers` |

### `EmailAnalyticsOverviewDto` (composite)

| Field | Type | Backing Aggregate | Notes |
|-------|------|-------------------|-------|
| `totalSent` | `int` | `SUM(EmailJobAnalytics.TotalSent)` in window | KPI 1 |
| `totalSentDeltaPct` | `decimal?` | period over period | KPI 1 delta |
| `totalDelivered` | `int` | `SUM(TotalDelivered)` | KPI 2 numerator |
| `deliveryRate` | `decimal` | `totalDelivered / NULLIF(totalSent,0) × 100` | KPI 2 |
| `deliveryRateDeltaPct` | `decimal?` | period over period | KPI 2 delta |
| `uniqueOpens` | `int` | `SUM(UniqueOpens)` | KPI 3 numerator |
| `openRate` | `decimal` | `uniqueOpens / NULLIF(totalDelivered,0) × 100` | KPI 3 |
| `openRateDeltaPct` | `decimal?` | period over period | KPI 3 delta |
| `uniqueClicks` | `int` | `SUM(UniqueClicks)` | KPI 4 numerator |
| `clickRate` | `decimal` | `uniqueClicks / NULLIF(totalDelivered,0) × 100` | KPI 4 |
| `clickRateDeltaPct` | `decimal?` | period over period | KPI 4 delta |
| `totalBounced` | `int` | `SUM(TotalBounced)` | KPI 5 numerator |
| `bounceRate` | `decimal` | `totalBounced / NULLIF(totalSent,0) × 100` | KPI 5 |
| `bounceRateDeltaPct` | `decimal?` | period over period | KPI 5 delta — display reverse-colored |
| `totalUnsubscribed` | `int` | `SUM(TotalUnsubscribes)` | KPI 6 numerator |
| `unsubscribeRate` | `decimal` | `totalUnsubscribed / NULLIF(totalDelivered,0) × 100` | KPI 6 |
| `unsubscribeRateDeltaPct` | `decimal?` | period over period | KPI 6 delta — reverse-colored |
| `funnel` | `EmailFunnelDto` | composite | Widget 7 — `{ sent, delivered, opened, clicked, converted, sentPct (=100), deliveredPct, openedPct, clickedPct, convertedPct }` |
| `campaignPerformance` | `EmailCampaignPerformanceRowDto[]` | per-job aggregation | Widget 8 — `{ emailSendJobId, emailSendJobName, subject, sent, delivered, opened, openRate, clicked, clickRate, bounced, unsubscribed }` |
| `trends` | `EmailRateTrendPointDto[]` | grouped by date over window | Widget 9 — `{ date, openRate, clickRate }`; one point per day; gaps filled with zeros |
| `bestSubjectLine` | `BestSubjectLineDto?` | top job by openRate (min 100 sent) | Widget 10a — `{ subject, openRate, emailSendJobId }`; null if no qualifying jobs |
| `bestSendTime` | `BestSendTimeDto?` | (dayOfWeek, hour) GROUP BY across `EmailJobAnalytics` | Widget 10b — `{ dayOfWeek, hour, avgOpenRate, label }` (label like "Tuesday 10:00 AM") |
| `bestCampaignType` | `BestCampaignTypeDto?` | grouped by `EmailSendJob.SendJobTypeId` | Widget 10c — `{ typeLabel, avgOpenRate, comparisonLabel }` (label like "Automated Emails", comparison like "65% avg open rate vs 36% for campaigns") |

### `EmailAnalyticsCampaignDetailDto`

| Field | Type | Backing | Notes |
|-------|------|---------|-------|
| `jobMeta` | `CampaignMetaDto` | `EmailSendJob` + `EmailTemplate` JOIN | `{ emailSendJobId, jobName, subject, fromName, fromEmail, sendAt, totalRecipients, templateId, templateName, statusCode, statusName }` |
| `funnel` | `CampaignFunnelDto` | aggregated `EmailJobAnalytics` for this job | `{ sent, delivered, opened, clicked, deliveryRate, openRate, clickRate }` (4-stage — no converted in detail) |
| `engagement` | `EngagementMetricsDto` | `EmailSendQueue` aggregation | `{ uniqueOpens, totalOpens, opensPerOpener, uniqueClicks, totalClicks, clicksPerClicker }` |
| `delivery` | `DeliveryBreakdownDto` | `EmailSendQueue` GROUP BY `BounceType` | `{ delivered, deliveredPct, softBounce, softBouncePct, hardBounce, hardBouncePct }` |
| `clickMap` | `ClickMapRowDto[]` | `EmailClickTracking` GROUP BY `LinkUrl` ORDER BY clicks DESC LIMIT 10 | `{ linkUrl, linkCategory, clicks, percentOfTotal }` |
| `openTimeHeatmap` | `HeatmapCellDto[]` | `EmailSendQueue` GROUP BY `EXTRACT(DOW from FirstOpenedAt), EXTRACT(HOUR from FirstOpenedAt)` | up to 168 cells `{ dayOfWeek (0=Mon..6=Sun), hour (0-23), opens }` |
| `peakLabel` | `string?` | derived from heatmap max | e.g., "Peak: Tuesday 10 AM – 12 PM" |

### `RecipientActivityRowDto`

| Field | Type | Backing | Notes |
|-------|------|---------|-------|
| `emailSendQueueId` | `int` | `EmailSendQueue.EmailSendQueueId` | row identifier |
| `contactId` | `int?` | `EmailSendQueue.ContactId` | drill-down key (nullable for anonymous) |
| `recipientName` | `string` | `Contact.FullName` (join) | display |
| `email` | `string` | `EmailSendQueue.ToEmail` | display |
| `statusCode` | `string` | derived: `IsOpened+IsClicked` → `OPENED_CLICKED`, `IsOpened` → `OPENED`, `IsBounced` → `BOUNCED`, `IsUnsubscribed` → `UNSUBSCRIBED`, `IsDelivered` → `DELIVERED`, else `PENDING` | status pill |
| `statusLabel` | `string` | human label derived from statusCode | display |
| `isOpened` | `bool` | — | |
| `firstOpenedAt` | `DateTime?` | — | display in "Open Time" column |
| `isClicked` | `bool` | — | |
| `clickedLinks` | `string[]` | comma-joined from `EmailClickTracking.LinkUrl` for this queue row | "Donate Now, Read Story" |
| `bounceReason` | `string?` | only when `IsBounced=true` | e.g., "Hard bounce: invalid" |

### `RecipientActivityFilterEnum`

`ALL` | `OPENED` | `CLICKED` | `NOT_OPENED` | `BOUNCED` | `UNSUBSCRIBED`

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm tsc --noEmit` — no errors
- [ ] `pnpm dev` — page loads at `/[lang]/crm/communication/emailanalytics`

**Functional Verification — Overview Mode (Full E2E):**
- [ ] Default load (no campaignId) → 30-day range active; 10 widgets render
- [ ] Each KPI card shows correct value with appropriate format, subtitle, delta indicator, and color cue
- [ ] Email Funnel renders 5 stages with gradient bars; widths approximate percent; tooltip per stage shows count + percent
- [ ] Campaign Performance Table renders rows with rate cells color-coded (green ≥30% / yellow 15-30% / red <15% for OpenRate; analogous for ClickRate); sort works on every column
- [ ] Rate Trends chart renders dual-line series (teal Open + purple Click); x-axis dates inside selected range; tooltip on hover
- [ ] Best Performing Content card row shows Best Subject Line / Best Send Time / Best Campaign Type with metric labels
- [ ] Date chip click (`7d / 30d / 90d / YTD`) refetches `getEmailAnalyticsOverview` with new window
- [ ] Custom chip opens date-range picker dialog with 2-year cap warning
- [ ] Campaign dropdown shows all `EmailSendJob` campaigns; selecting a campaign navigates to Detail mode (`?campaignId=X`)
- [ ] Campaign name link click in Performance Table navigates to Detail mode
- [ ] Each widget has shape-matched skeleton during fetch
- [ ] Empty state per widget if no data in selected window
- [ ] Error state per widget on query failure

**Functional Verification — Detail Mode (Full E2E):**
- [ ] Detail mode loads when `?campaignId=X` is present; back-link button appears
- [ ] Campaign Header Card renders job metadata + Status pill + "Resend to Non-Openers" CTA
- [ ] "Resend to Non-Openers" click → toast SERVICE_PLACEHOLDER + deep-link to `/crm/communication/emailcampaign?mode=new&srcJobId=X&audience=non-openers`
- [ ] Campaign Funnel (4-stage) renders with bars; stage click filters Recipient table
- [ ] Engagement Metrics 4-card row renders Unique/Total Opens + Unique/Total Clicks + per-opener/clicker ratios
- [ ] Click Map table renders top links with category icons + distribution bar gauges; click row → opens link in new tab
- [ ] Delivery Breakdown renders 3 colored tiles (green/yellow/red); click tile filters Recipient table by status
- [ ] Recipient Activity table renders paginated rows with status pills (Opened+Clicked green / Opened blue / Delivered grey / Bounced red / Unsubscribed purple)
- [ ] Filter pills (All/Opened/Clicked/Not Opened/Bounced/Unsubscribed) refetch table only
- [ ] Recipient name click navigates to `/crm/contact/contact?mode=read&id={contactId}`
- [ ] Export CSV button triggers download (or toast SERVICE_PLACEHOLDER)
- [ ] Open Time Heatmap renders 7×24 grid with 5 intensity levels; cell tooltip shows day + hour + opens count
- [ ] Back link click clears `?campaignId` and returns to Overview

**Performance / Tenant / Role Verification:**
- [ ] All queries tenant-scoped (CompanyId from HttpContext, verified by changing tenant in JWT)
- [ ] Role gating: removing BUSINESSADMIN's `WidgetRole(HasAccess=true)` for `EA_KPI_OPEN_RATE` → that KPI widget renders "Restricted" placeholder (or hides; document choice)
- [ ] Removing `RoleCapability(BUSINESSADMIN, EMAILANALYTICS menuId, READ)` → sidebar leaf hidden for that role
- [ ] react-grid-layout reflows at xs/sm/md/lg breakpoints in Overview mode
- [ ] Bookmarked URL `/[lang]/crm/communication/emailanalytics?campaignId=42` survives reload + opens Detail mode for that campaign

**DB Seed Verification:**
- [ ] Dashboard row `EMAILANALYTICS` inserted with `MenuId IS NOT NULL`
- [ ] DashboardLayout row inserted; `LayoutConfig` JSON parses cleanly; `ConfiguredWidget` has 10 instances
- [ ] 17 WidgetType rows inserted with `IsSystem=true`
- [ ] 10 Widget rows inserted with `DefaultQuery='GET_EMAIL_ANALYTICS_OVERVIEW'` and valid `DefaultParameters` JSON
- [ ] WidgetRole rows for BUSINESSADMIN × 10
- [ ] MenuCapability + RoleCapability rows for BUSINESSADMIN
- [ ] Re-running seed is idempotent (every INSERT/UPDATE guarded)

---

## ⑫ Special Notes & Warnings

**Module-level warnings:**
- The parent menu `EMAILANALYTICS` is under `CRM_COMMUNICATION` (a feature-module parent), **NOT** `CRM_DASHBOARDS` — this is the established placement in `Pss2.0_Global_Menus_List.sql`. The sidebar auto-injection logic (which fires only for `*_DASHBOARDS` parents) is irrelevant here because the menu is hard-seeded. Do NOT move the menu to `CRM_DASHBOARDS`.
- The route lives at `/[lang]/crm/communication/emailanalytics` (NOT `/[lang]/crm/dashboards/emailanalytics`). The existing `page.tsx` stub at this path renders `<UnderConstruction />` — OVERWRITE this file with the custom mode-switching page.
- Email entities live in the `notify` schema (NOT `comm` or `email`). All source data: `notify.EmailSendJob`, `notify.EmailSendQueue`, `notify.EmailClickTracking`, `notify.EmailJobAnalytics`, `notify.EmailTemplate`.

**MENU_DASHBOARD infra status (per pre-planning audit):**
- `Dashboard.MenuId` entity property + EF config EXIST (`Base.Domain/Models/SettingModels/Dashboard.cs:14-17`). The `ALTER TABLE sett.Dashboards ADD COLUMN MenuId` migration is UNGENERATED (deferred per Case #52 ISSUE-1 / Volunteer #57 ISSUE-21 — re-flag here as ISSUE-5 LOW).
- `<MenuDashboardComponent />` EXISTS at `src/presentation/components/custom-components/menu-dashboards/index.tsx` — but **this prompt does NOT use it** (mode-switching needs custom page logic; ⑫ ISSUE-2).
- `GetDashboardByModuleAndCode` BE query EXISTS — not consumed by this prompt (custom page bypasses dashboard wrapper).
- `linkDashboardToMenu` / `unlinkDashboardFromMenu` mutations DO NOT EXIST — irrelevant; this prompt sets `Dashboard.MenuId` via raw SQL UPDATE in seed step 6 (the established pattern used by all 6 prior dashboards).
- Dynamic `[slug]/page.tsx` route DOES NOT EXIST — irrelevant; per-route-stub pattern continues to be the working convention.

**Dashboard-class warnings:**
- Dashboards are READ-ONLY. No CRUD on this screen — Dashboard CRUD is `#78 Dashboard Config`.
- Widget queries MUST be tenant-scoped (CompanyId from HttpContext on every aggregate handler).
- N+1 risk on `RecipientActivityTableWidget` if Contact JOIN is lazy — ensure `.Include(q => q.Contact)` or `.Select` projection in EF.
- Multi-currency aggregation: N/A for email metrics (only Conversion field would need it — pre-flagged as ISSUE-3 deferred).
- `LayoutConfig` JSON must include lg/md/sm breakpoint configs at minimum (xs/xl optional). Missing breakpoints cause widget overlap.
- `ConfiguredWidget.instanceId` MUST equal each `LayoutConfig.{breakpoint}[].i` value — collisions cause widget-reuse bugs.
- Drill-down args (e.g., `?campaignId=X`, `?audience=non-openers`) must use the destination route's expected query-param names — verify `crm/communication/emailcampaign` accepts `srcJobId` + `audience` (FE Dev step — if it does NOT, log new ISSUE).

**Service Dependencies (UI-only — flag genuine external-service gaps):**
- ⚠ **SERVICE_PLACEHOLDER: ResendToNonOpeners** — full UI in place (Detail mode header CTA), BE mutation returns `true`, FE navigates to email-campaign-builder with prefill. The email-campaign-builder route accepting `srcJobId` + `audience=non-openers` is a separate integration item (the builder may need to read those params to populate audience selector).
- ⚠ **SERVICE_PLACEHOLDER: Export CSV** — full UI button in place (Detail mode Recipient Activity), but if the CSV-export infra is not wired in `notify` group, the handler returns a placeholder + UI toasts "Export integration pending."
- ⚠ **DATA GAP: Conversion attribution** — Email Funnel's 5th stage ("Converted") needs `GlobalDonation.SourceCode = 'EMAIL_CAMPAIGN'` attribution OR a `Donation × EmailSendQueue` junction. If the attribution path doesn't exist, render `Converted=0` with widget tooltip "Donation attribution wiring pending" — pre-flagged as ISSUE-3 (HIGH).

**Pre-flagged Known Issues (copy these into §⑬ on /build-screen):**

| ID | Severity | Description |
|----|---------|-------------|
| ISSUE-1 | LOW | Menu parent is `CRM_COMMUNICATION` not `CRM_DASHBOARDS`. Sidebar auto-injection won't fire — menu is hard-seeded so this is fine, but document so a future "rationalize MENU_DASHBOARD placement" refactor knows about it. |
| ISSUE-2 | MED | Custom page bypasses `<MenuDashboardComponent />` because of mode-switching. Acceptable divergence; if a second mode-switching dashboard ships later, extract a shared helper. |
| ISSUE-3 | HIGH | Email Funnel "Converted" stage depends on Donation→Email attribution which may not be wired. V1: render `0` + tooltip "Donation attribution wiring pending". Verify schema in BA step — if `GlobalDonation.SourceCode` or a `DonationCampaignAttribution` junction exists, wire it; otherwise leave deferred. |
| ISSUE-4 | LOW | Filter pill counts (e.g., "Opened (3,095)") on Detail mode Recipient Activity require an extra grouped count query. V1 may show pills WITHOUT counts to ship faster; V2 add `recipientFilterCounts` to `CampaignDetailDto`. |
| ISSUE-5 | LOW | `Dashboard.MenuId` DB column ALTER TABLE migration was never generated (Case #52 / Volunteer #57 inherited). Seed step 6 will still work because the column exists in the entity definition and EF expects it — but if a fresh DB is provisioned via `dotnet ef database update` against the ModelSnapshot rather than via the seed, the column may be missing. Document in build log + verify before applying seed. |
| ISSUE-6 | MED | `getAllEmailSendJobList` (existing) — verify projection includes `EmailSendJobId`, `EmailSendJobName`, `Subject`. If it doesn't, either modify the existing query or add a lightweight `getEmailCampaignsForDropdown` query for the toolbar dropdown. |
| ISSUE-7 | MED | `EmailSendJob` may not have `BranchId` — verify in BA step. If absent, role scoping uses CompanyId only (V1 acceptable; revisit if branch-scoped reporting is later required). |
| ISSUE-8 | LOW | `Best Send Time` aggregation across `EmailJobAnalytics` GROUP BY `(EXTRACT(DOW from AnalyticsDate), AnalyticsHour)` can be expensive on very large datasets. Add covering index `(CompanyId, AnalyticsDate, AnalyticsHour)` if performance audit shows >2s P95. |
| ISSUE-9 | LOW | `RecipientActivityRowDto.statusCode` derivation logic — confirm precedence: bounced trumps opened? unsubscribed trumps clicked? Document the precedence in handler header comment for future readers. Suggested precedence: BOUNCED > UNSUBSCRIBED > OPENED_CLICKED > OPENED > DELIVERED > PENDING. |
| ISSUE-10 | LOW | Cross-row click linking — clicking "Donate Now, Read Story" cell text in Recipient Activity table should ideally show a popover/expander with full URL list (per-recipient may click many). V1 may comma-join up to 3 + "+N more"; full popover deferred. |
| ISSUE-11 | LOW | Heatmap empty cells — for campaigns with low opens (< 50 total), the heatmap will be mostly level-0 grey. Add empty-state text "Limited engagement data — heatmap requires ≥ 50 opens." Otherwise looks broken. |
| ISSUE-12 | MED | `EmailSendQueueSchemas.cs` currently does NOT project webhook-tracking columns (`IsOpened`, `IsClicked`, `IsUnsubscribed`, etc.) — confirmed during entity audit. The new `RecipientActivityRowDto` will read these directly from EF (not via existing schema), so this is not a regression — but if future screens need them in `EmailSendQueueResponseDto`, that's a follow-up. |
| ISSUE-13 | LOW | The repo's seed-script folder is mis-named `sql-scripts-dyanmic/` (`dyanmic` typo). Preserve the typo — multiple downstream tools depend on the exact path. |
| ISSUE-14 | LOW | If a campaign has `TotalSent=0` (e.g., scheduled but never executed), all rate denominators evaluate to NULL via `NULLIF`. Render "—" in the KPI cards instead of "NaN%" / "0%". Confirm formatter handles NULL gracefully. |
| ISSUE-15 | LOW | Date-range picker "Custom" must enforce 2-year max span (per ④). If user enters > 2 years, show inline error + disable Apply button. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning | LOW | menu | Parent menu is `CRM_COMMUNICATION` not `CRM_DASHBOARDS` (intentional, hard-seeded) | OPEN |
| ISSUE-2 | planning | MED | FE arch | Custom page bypasses `<MenuDashboardComponent />` due to mode-switching | OPEN |
| ISSUE-3 | planning | HIGH | data | Email Funnel "Converted" stage needs Donation→Email attribution path | OPEN |
| ISSUE-4 | planning | LOW | FE | Filter pill counts in Detail mode Recipient Activity deferred to V2 | OPEN |
| ISSUE-5 | planning | LOW | BE | `Dashboard.MenuId` DB-column migration inherited as ungenerated | OPEN |
| ISSUE-6 | planning | MED | BE | Verify `getAllEmailSendJobList` projection covers toolbar dropdown needs | OPEN |
| ISSUE-7 | planning | MED | BE | `EmailSendJob.BranchId` absence may limit role scoping to CompanyId only | OPEN |
| ISSUE-8 | planning | LOW | perf | `Best Send Time` index may be needed if P95 > 2s | OPEN |
| ISSUE-9 | planning | LOW | BE | Recipient statusCode derivation precedence to be documented in handler | OPEN |
| ISSUE-10 | planning | LOW | FE | Clicked-links cell may need popover for high-click recipients | OPEN |
| ISSUE-11 | planning | LOW | FE | Heatmap empty-state copy for low-engagement campaigns | OPEN |
| ISSUE-12 | planning | MED | BE | `EmailSendQueueResponseDto` doesn't project webhook columns — new RecipientActivityRowDto reads via EF directly | OPEN |
| ISSUE-13 | planning | LOW | infra | Preserve `sql-scripts-dyanmic/` folder typo | OPEN |
| ISSUE-14 | planning | LOW | FE | Format "—" for divide-by-zero KPIs | OPEN |
| ISSUE-15 | planning | LOW | FE | Custom date-range picker must enforce 2-year max span | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}