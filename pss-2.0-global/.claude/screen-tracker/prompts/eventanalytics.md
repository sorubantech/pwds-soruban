---
screen: EventAnalytics
registry_id: 47
module: CRM (Event)
status: PROMPT_READY
scope: FULL
screen_type: DASHBOARD
dashboard_variant: MENU_DASHBOARD
complexity: High
new_module: NO
planned_date: 2026-05-12
completed_date:
last_session_date:
---

> ## ⚠ Non-standard MENU_DASHBOARD — event-scoped, parented under CRM_EVENT (not CRM_DASHBOARDS)
>
> This is the 4th MENU_DASHBOARD prompt (after Case #52 / Volunteer #57 / Communication #26 / Email Analytics #4 / Donation Dashboard / Contact Dashboard) but with **two deviations** from the canonical pattern that the FE Developer MUST handle:
>
> 1. **Parent is `CRM_EVENT` (MenuId 271), NOT `CRM_DASHBOARDS`** — the sidebar auto-injection rule (template § D, `MenuCode \w+_DASHBOARDS$`) does NOT fire. The `EVENTANALYTICS` Menu row already exists in `Pss2.0_Global_Menus_List.sql` @ OrderBy=4 under CRM_EVENT (verified in [`MODULE_MENU_REFERENCE.md:138`](../MODULE_MENU_REFERENCE.md#L138)) — it renders via the normal menu mechanism. No new Menu seed needed in this prompt — only an `UPDATE Dashboard.MenuId = (SELECT MenuId FROM auth.Menus WHERE MenuCode='EVENTANALYTICS')` link step.
>
> 2. **Page is event-scoped via `?eventId=N` URL param** — the page is invoked from the Events grid (mockup breadcrumb: "Events > Post-Event Analytics") and lives at `crm/event/eventanalytics?eventId=N`. Every widget aggregates over a single event's data. The existing `<MenuDashboardComponent moduleCode dashboardCode />` does NOT accept arbitrary filter context. **This prompt's FE scope includes a minimal extension to `<MenuDashboardComponent />`** to accept an optional `filterContext: Record<string, string | number>` prop that overlays into each widget's `DefaultParameters` substitution at render time — small ~30-50 LOC change. (Alternative: per-route page wraps a custom orchestrator. Recommend extension — see ISSUE-1.)
>
> 3. **Bootstrap (Phase 2 of #52 Case Dashboard) is already in place** — `Dashboard.MenuId` schema, `dashboardByModuleAndCode` BE query, `<MenuDashboardComponent />` FE component, dynamic `[slug]/page.tsx` route. EventAnalytics does NOT use the dynamic route — it uses the existing per-route stub at `crm/event/eventanalytics/page.tsx` (FE_STUB confirmed: 6-line `<UnderConstruction />`), matching #52 / #57 per-route precedent.
>
> Track these deviations as **ISSUE-1 HIGH** (MenuDashboardComponent filter extension) and **ISSUE-2 LOW** (parent-menu non-standard but no code change needed) below.

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — 14 widgets total: 6 KPIs + 1 hybrid (donut + table) + 1 table + 1 timeline chart + 1 list + 1 composite feedback panel + 1 ROI table + 1 YoY table + 1 event-overview strip
- [x] Variant chosen — **MENU_DASHBOARD** (own sidebar leaf at `crm/event/eventanalytics`, parented under CRM_EVENT @ OrderBy=4; menu row already seeded)
- [x] Source entities identified — **all COMPLETED**: Event #40 (`ApplicationModels/Event.cs`), EventTicket #46 (`ApplicationModels/EventTicket.cs`), EventRegistration #46 (`ApplicationModels/EventRegistration.cs`), EventAuction/AuctionItem/AuctionBid #48 (`ApplicationModels/`), Contact (`ContactModels/Contact.cs`), GlobalDonation (`DonationModels/GlobalDonation.cs`), MasterData (status/type lookups)
- [x] Widget catalog drafted (14 widget instances; 12 NEW WidgetType renderers — overview-bar reuses one of them; visually distinct hierarchy: hero revenue → 5 supporting KPIs → composite hybrid donut+table → attendance grid → timeline chart → engagement list → feedback panel → ROI table → YoY table)
- [x] react-grid-layout config drafted (lg breakpoint 12-col × ~28 rows tall; full responsive layout for md/sm/xs)
- [x] DashboardLayout JSON shape drafted (LayoutConfig + ConfiguredWidget for all 14 instances)
- [x] MENU_DASHBOARD parent menu code resolved — `CRM_EVENT` (MenuId 271, NOT `*_DASHBOARDS`); EVENTANALYTICS Menu row already seeded @ OrderBy=4 — link only, no new Menu seed
- [x] First MENU_DASHBOARD bootstrap NOT in scope — covered by Case Dashboard #52 Phase 2
- [x] Path-A (Postgres functions) chosen for ALL 14 widgets — matches `case.fn_case_dashboard_*` and `app.fn_volunteer_dashboard_*` precedent; no new C# code
- [x] File manifest computed (~13 SQL functions [overview-bar reuses GetEventById] + 12 NEW FE widget renderers + 1 shared helper + 1 barrel + 1 page-config + 1 event-selector + 1 EventOverviewBar component + 1 route-stub overwrite + 1 registry update + `<MenuDashboardComponent />` filter-context extension + 2 wiring barrels + DB seed)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis (likely skipped — prompt fully pre-analyzed per #52/#57 precedent)
- [ ] Solution Resolution (skipped — Path-A across all 14 widgets dictated by §⑤)
- [ ] UX Design (skipped — §⑥ contains complete grid layout)
- [ ] User Approval received
- [ ] **Backend (Path-A only)** — 13 Postgres function files in `PSS_2.0_Backend/.../Base.Application/DatabaseScripts/Functions/app/` (REUSE the `app/` subfolder created for Volunteer Dashboard #57). Each conforms to fixed 5-arg / 4-column contract (`p_filter_json::jsonb, p_page, p_page_size, p_user_id, p_company_id` → `TABLE(data jsonb, metadata jsonb, total_count int, filtered_count int)`). Every function reads `eventId` from `p_filter_json->>'eventId'` (required; NULL → return empty data with metadata-flag `eventIdMissing=true`). NO new C# code (reuses existing `generateWidgets` GraphQL handler).
- [ ] **Frontend** — 12 NEW widget renderer files under `dashboards/widgets/event-analytics-widgets/` + 1 `_shared.tsx` helper (palette / icon resolver / event-context hook / SERVICE_PLACEHOLDER badge / sample-data factories for the 4 degraded widgets) + 1 `index.ts` barrel. Register all 12 in `WIDGET_REGISTRY` (`dashboard-widget-registry.tsx`). Build 1 page-config + 1 event-selector popover + 1 EventOverviewBar strip component. Overwrite route stub `crm/event/eventanalytics/page.tsx`. Extend `<MenuDashboardComponent />` (add optional `filterContext` prop — see ISSUE-1).
- [ ] **DB Seed** — `sql-scripts-dyanmic/EventAnalytics-sqlscripts.sql` (preserve `dyanmic` typo):
      • Dashboard row `EVENTANALYTICS` (DashboardCode, DashboardName, ModuleId=CRM, IsSystem=true, IsActive=true, MenuId resolved via UPDATE)
      • DashboardLayout row (LayoutConfig 4-breakpoint JSON + ConfiguredWidget JSON × 14 instances)
      • 12 NEW WidgetType rows (`EVENT_REVENUE_TOTAL_KPI`, `EVENT_TICKET_REVENUE_KPI`, `EVENT_AUCTION_REVENUE_KPI`, `EVENT_ATTENDANCE_KPI`, `EVENT_NEW_DONORS_KPI`, `EVENT_COST_PER_ATTENDEE_KPI`, `EVENT_REVENUE_BREAKDOWN`, `EVENT_ATTENDANCE_TABLE`, `EVENT_CHECKIN_TIMELINE_CHART`, `EVENT_DONOR_ENGAGEMENT_LIST`, `EVENT_FEEDBACK_PANEL`, `EVENT_ROI_TABLE`, `EVENT_YOY_TABLE`) + ComponentPath matching the FE registry keys
      • 14 Widget rows (StoredProcedureName = schema-qualified Postgres function name; one Widget per renderer except `EventOverviewBarWidget` which is page-level, not a `sett.Widgets` row)
      • 14 WidgetRole grants (BUSINESSADMIN)
      • `UPDATE sett."Dashboards" SET "MenuId" = m."MenuId" FROM auth."Menus" m WHERE m."MenuCode"='EVENTANALYTICS' AND d."DashboardCode"='EVENTANALYTICS' AND d."MenuId" IS NULL` (idempotent)
      • All idempotent (`WHERE NOT EXISTS` / `WHERE IsNull` guards)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E)
- [ ] `dotnet build` passes (no new C# code expected, but generic `generateWidgets` handler resolution + function calls verified by smoke test)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/event/eventanalytics?eventId=N`
- [ ] Without `?eventId` → event-picker empty state renders (prompts user to pick a completed event)
- [ ] With valid `?eventId` → all 14 widgets fetch and render
- [ ] EventOverviewBar shows correct event name + date + venue + status badge
- [ ] 6 KPI cards render distinct visual treatments (no clone grid)
- [ ] Revenue Breakdown renders donut + table side-by-side; row colors match donut slices
- [ ] Attendance table renders inline-progress bars per row + total row
- [ ] Check-in Timeline renders line chart by hour bucket
- [ ] Donor Engagement list renders 5 rows with icons + values + percentages
- [ ] Feedback Panel renders overall rating + 4 category bars + NPS stacked bar + 2 lists (positive + improvement) → **degraded** with sample data + SERVICE_PLACEHOLDER badge
- [ ] ROI table renders 7 rows → **degraded** with sample data + SERVICE_PLACEHOLDER badge
- [ ] YoY table renders 4 metric rows × 4 year columns + trend arrows
- [ ] Event-selector dropdown lists completed events for current Company; clicking switches URL `?eventId=N` and refetches all widgets
- [ ] Header actions: Export Report → toast SERVICE_PLACEHOLDER; Print → window.print(); Share with Board → toast SERVICE_PLACEHOLDER
- [ ] react-grid-layout reflows across breakpoints (xs/sm/md/lg/xl)
- [ ] role-gating: WidgetRole(HasAccess=false) hides widget; RoleCapability on EVENTANALYTICS menu hides sidebar leaf
- [ ] Bookmarked URL `/{lang}/crm/event/eventanalytics?eventId=123` survives reload
- [ ] DB Seed — Dashboard row + DashboardLayout + 12 WidgetType + 14 Widget + 14 WidgetRole rows visible; `Dashboard.MenuId` correctly linked to EVENTANALYTICS Menu
- [ ] Re-running seed is idempotent

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **EventAnalytics**
Module: **CRM** (Event sub-module)
Schema: NONE — dashboard aggregates over existing `app` schema entities (Event, EventTicket, EventRegistration, EventAuction, AuctionItem, AuctionBid) + cross-schema reads (Contact in `corg`, GlobalDonation in `fund`)
Group: ApplicationModels (BE source group); Dashboard metadata lives in `sett` schema (shared)

Dashboard Variant: **MENU_DASHBOARD** — own sidebar leaf at `crm/event/eventanalytics` parented under CRM_EVENT (non-standard parent: NOT `*_DASHBOARDS`). Event-scoped page accepts `?eventId=N` URL param.

Business:
The Post-Event Analytics dashboard is the **fundraising team's debrief and board-reporting surface** after a major fundraising event (Gala, charity dinner, auction night, fundraiser ball). It is invoked from the Events list by clicking "Analytics" on a Completed event row, and gives a single-page comprehensive view of how the event performed against goals: total revenue vs. goal, ticket vs. auction vs. on-site donation breakdown, attendance rate per ticket tier, check-in arrival pattern, donor engagement metrics (first-time vs. returning, donation conversion, new-donor acquisition), attendee feedback (rating, NPS, top compliments + improvement areas), ROI math (revenue/cost/net/cost-per-dollar-raised), and year-over-year trend comparison with prior years of the same event. Target audience: **Executive Director, Board Members, Fundraising Director, Event Coordinator** — used in board meetings to demonstrate event ROI and inform the next year's event planning. It earned its own menu slot (instead of living inside the event detail view) because (a) it is reached via deep-links from board emails ("Click here to view 2026 Gala analytics"), (b) the analytics view is conceptually distinct from the event-setup view, and (c) it is role-restricted to leadership/fundraising roles, hidden from operational staff. The dashboard rolls up data from: Event (goal, dates, venue, status), EventTicket + EventRegistration (#46 Event Ticketing — revenue + attendance), EventAuction + AuctionItem + AuctionBid (#48 Auction Management — auction revenue), Contact (donor history), and **planned future entities** for EventFeedback (post-event survey responses), EventCost (expense tracking) — both currently SERVICE_PLACEHOLDER.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> EventAnalytics introduces **NO new domain entity**. It seeds 1 Dashboard row + 1 DashboardLayout row + 12 WidgetType rows + 14 Widget rows + 14 WidgetRole grants.
> If/when EventFeedback and EventCost entities are built, the SERVICE_PLACEHOLDER widgets can be promoted to real data without changing this dashboard's structure.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `EVENTANALYTICS` | Matches `auth.Menus.MenuCode` for link |
| DashboardName | `Post-Event Analytics` | Fallback when `Menu.MenuName` isn't set |
| DashboardIcon | `ph:chart-line-up` | Or `ph:chart-pie-slice` |
| DashboardColor | `#0e7490` | Cyan-700 (matches mockup `--accent`) |
| ModuleId | (resolve to `CRM`) | MUST equal Menu.ModuleId |
| IsSystem | `true` | — |
| IsActive | `true` | — |
| MenuId | FK → `auth.Menus` (resolved by `UPDATE` step linking to existing `EVENTANALYTICS` Menu row) | NOT NULL on this dashboard (MENU_DASHBOARD) |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK → Dashboard row above | — |
| LayoutConfig | JSON `{ lg, md, sm, xs: [...] }` | All 4 breakpoints filled — see §⑥ Grid Layout |
| ConfiguredWidget | JSON `[{instanceId, widgetId, title?, customQuery?, customParameter?, configOverrides?}]` × 14 | One element per visible widget. `customParameter` overlays `eventId` from URL search params at render time |

### C. WidgetType Rows (`sett.WidgetTypes`) — 12 NEW

| WidgetTypeCode | WidgetTypeName | ComponentPath (FE registry key) |
|----------------|-----------------|----------------------------------|
| `EVENT_REVENUE_TOTAL_KPI` | Event Revenue Total KPI | `EventRevenueTotalKpiWidget` |
| `EVENT_TICKET_REVENUE_KPI` | Event Ticket Revenue KPI | `EventTicketRevenueKpiWidget` |
| `EVENT_AUCTION_REVENUE_KPI` | Event Auction Revenue KPI | `EventAuctionRevenueKpiWidget` |
| `EVENT_ATTENDANCE_KPI` | Event Attendance KPI | `EventAttendanceKpiWidget` |
| `EVENT_NEW_DONORS_KPI` | Event New Donors KPI | `EventNewDonorsKpiWidget` |
| `EVENT_COST_PER_ATTENDEE_KPI` | Event Cost Per Attendee KPI | `EventCostPerAttendeeKpiWidget` |
| `EVENT_REVENUE_BREAKDOWN` | Event Revenue Breakdown (Donut + Table) | `EventRevenueBreakdownWidget` |
| `EVENT_ATTENDANCE_TABLE` | Event Attendance Analysis Table | `EventAttendanceTableWidget` |
| `EVENT_CHECKIN_TIMELINE_CHART` | Event Check-in Timeline | `EventCheckinTimelineChartWidget` |
| `EVENT_DONOR_ENGAGEMENT_LIST` | Event Donor Engagement List | `EventDonorEngagementListWidget` |
| `EVENT_FEEDBACK_PANEL` | Event Feedback & Satisfaction | `EventFeedbackPanelWidget` |
| `EVENT_ROI_TABLE` | Event ROI Analysis | `EventRoiTableWidget` |
| `EVENT_YOY_TABLE` | Event Year-over-Year | `EventYoyTableWidget` |

> **Note**: 13 widget renderers + 1 page-level **EventOverviewBar** strip (not a `sett.Widgets` row — it's rendered above the widget grid by the page-config and fetches via the existing `GetEventById` GraphQL query). Total 12 WidgetType seed rows + 1 hybrid "donut + table" renderer that handles its own internal layout.

### D. Source Entities (read-only)

| Source Entity | File Path (verified by audit) | Aggregate(s) |
|---------------|--------------------------------|--------------|
| `Event` | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Event.cs` | EventName, StartDate, VenueName, VenueAddress, EventCategoryId, EventStatusId, GoalAmount, CompanyId |
| `EventTicket` | `Base.Domain/Models/ApplicationModels/EventTicket.cs` | TicketName, Price, QuantityAvailable, PricingTypeId; group revenue by TicketName |
| `EventRegistration` | `Base.Domain/Models/ApplicationModels/EventRegistration.cs` | TotalAmount, StatusId (CONFIRMED / CHECKEDIN / NOSHOW / CANCELLED), CheckedInDate, EventTicketId, ContactId |
| `EventAuction` | `Base.Domain/Models/ApplicationModels/EventAuction.cs` | EventId 1:1 |
| `AuctionItem` | `Base.Domain/Models/ApplicationModels/AuctionItem.cs` | WinningBidAmount, WinnerContactId, AuctionTypeId (Silent/Live), EventId |
| `AuctionBid` | `Base.Domain/Models/ApplicationModels/AuctionBid.cs` | Bid count for engagement metrics |
| `Contact` | `Base.Domain/Models/ContactModels/Contact.cs` | ContactCreatedDate (for first-time-donor heuristic) |
| `GlobalDonation` | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | DonationAmount, DonationDate, ContactId — ⚠ **NO EventId column** (ISSUE-3 — on-site donations linkage is SERVICE_PLACEHOLDER) |
| `MasterData` | `Base.Domain/Models/SettingModels/MasterData.cs` | EventStatus / EventRegStatus / AuctionType lookup names |

### E. SERVICE_PLACEHOLDER source entities (do NOT exist yet)

- **EventFeedback / EventSurveyResponse** — for Feedback Panel widget (overall rating, category ratings, NPS, top positive / improvement free-text). All 4 sub-sections render with sample data + SERVICE_PLACEHOLDER badge. **Future scope**: separate prompt to add EventFeedback + EventSurvey entities + a survey-link sent to attendees post-event. Track as ISSUE-4.
- **EventCost / EventExpense** — for ROI table (Total Costs, Net Revenue, ROI %, Cost per Dollar Raised, Donor Acquisition Cost). All cost-derived metrics return sample placeholder data. **Future scope**: separate prompt to add EventCost line-items + budget vs. actual reconciliation. Track as ISSUE-5.
- **Event.TotalCost / Event.BudgetAmount column** — short-term workaround for ROI: add a scalar `Event.TotalCostAmount` decimal column via migration (not in this prompt's scope). Track as ISSUE-6 LOW.

---

## ③ Source Entity & Aggregate Query Resolution

> **Consumer**: Backend Developer (Path-A SQL functions)
> One Postgres function per widget (Path A). Function-name convention: `app.fn_event_analytics_{kpi|widget}_{name}`.

| # | Widget | Function (Postgres) | File Path | Reads From | `p_filter_json` Keys |
|---|--------|---------------------|-----------|------------|----------------------|
| 1 | KPI Total Revenue | `app.fn_event_analytics_kpi_total_revenue` | `Base.Application/DatabaseScripts/Functions/app/fn_event_analytics_kpi_total_revenue.sql` | `EventRegistration` (CONFIRMED + CHECKEDIN) + `AuctionItem` (WinnerContactId NOT NULL → WinningBidAmount) — **EXCLUDE** on-site donations until ISSUE-3 resolved | `eventId` (required) |
| 2 | KPI Ticket Revenue | `app.fn_event_analytics_kpi_ticket_revenue` | same folder | `SUM(EventRegistration.TotalAmount WHERE EventId=X AND StatusId IN [CONFIRMED, CHECKEDIN])` | `eventId` |
| 3 | KPI Auction Revenue | `app.fn_event_analytics_kpi_auction_revenue` | same folder | `SUM(AuctionItem.WinningBidAmount WHERE EventId=X AND WinnerContactId IS NOT NULL)`; subtotal Silent vs. Live in metadata | `eventId` |
| 4 | KPI Attendance | `app.fn_event_analytics_kpi_attendance` | same folder | `COUNT(EventRegistration WHERE EventId=X AND CheckedInDate IS NOT NULL) / SUM(EventTicket.QuantityAvailable WHERE EventId=X)` | `eventId` |
| 5 | KPI New Donors | `app.fn_event_analytics_kpi_new_donors` | same folder | **DEGRADED**: `COUNT(DISTINCT ContactId from EventRegistration WHERE EventId=X AND ContactId NOT IN (SELECT ContactId FROM GlobalDonation WHERE DonationDate < Event.StartDate))` — heuristic, returns metadata.note='SERVICE_PLACEHOLDER — accurate count needs GlobalDonation.EventId FK' | `eventId` |
| 6 | KPI Cost Per Attendee | `app.fn_event_analytics_kpi_cost_per_attendee` | same folder | **PLACEHOLDER**: returns hardcoded sample $89 / Total cost $24,700 in metadata.note='SERVICE_PLACEHOLDER — needs Event.TotalCostAmount column or EventCost entity' | `eventId` |
| 7 | Revenue Breakdown (donut + table) | `app.fn_event_analytics_revenue_breakdown` | same folder | UNION of: per-ticket-type SUM from EventRegistration + per-auction-type (Silent / Live) SUM from AuctionItem + placeholder row for On-site Donations (returns 0 until ISSUE-3 resolved). Returns rows `{label, amount, percent, color}` | `eventId` |
| 8 | Attendance Analysis Table | `app.fn_event_analytics_attendance_by_ticket` | same folder | `GROUP BY EventTicket.TicketName`: COUNT(EventRegistration.Registered) / COUNT(Attended via CheckedInDate IS NOT NULL) / COUNT(NoShow via StatusId=NOSHOW) / Rate%. Append Walk-in row (registrations with EventTicketId NULL — if walk-in concept supported). Append Total row. | `eventId` |
| 9 | Check-in Timeline | `app.fn_event_analytics_checkin_timeline` | same folder | `GROUP BY date_trunc('hour', CheckedInDate)`: COUNT per hour bucket WHERE EventId=X AND CheckedInDate IS NOT NULL. Returns `[{hour: '18:00', count: 12}, ...]` for the event's check-in window | `eventId` |
| 10 | Donor Engagement List | `app.fn_event_analytics_donor_engagement` | same folder | 5-row composite — first-time attendees (no prior EventRegistration), returning attendees (≥1 prior), attendees who made donation at event (DEGRADED), new donors acquired (DEGRADED), avg engagement score (DEGRADED — return placeholder 72 + org avg 54) | `eventId` |
| 11 | Feedback Panel | `app.fn_event_analytics_feedback_panel` | same folder | **PLACEHOLDER**: returns hardcoded sample data — overallRating=4.2, responseCount=145, responseRate=52%, category[Venue=4.5, Program=4.3, Food=4.0, Networking=3.8], npsScore=+45, npsPromoters=58, npsPassives=29, npsDetractors=13, topPositive=[3 strings], topImprovement=[3 strings]. metadata.note='SERVICE_PLACEHOLDER — pending EventFeedback entity' | `eventId` |
| 12 | ROI Table | `app.fn_event_analytics_roi` | same folder | **PARTIALLY DEGRADED**: TotalRevenue computed from real KPIs (sum of widgets 1+2+3), TotalCost=PLACEHOLDER $24,700, NetRevenue=Revenue−Cost, ROI%=NetRevenue/Cost×100, CostPerDollarRaised=Cost/Revenue, RevenuePerAttendee=Revenue/AttendedCount, DonorAcquisitionCost=Cost/NewDonorsCount. Cost-derived rows tagged metadata.note='SERVICE_PLACEHOLDER' | `eventId` |
| 13 | Year-over-Year | `app.fn_event_analytics_yoy_comparison` | same folder | Find prior events with same EventCategoryId AND same Company AND CompletedStatus AND name fuzzy-match (LIKE `%{currentEventNameStem}%`) AND StartDate.Year IN (year-2, year-1, year). Aggregate per year: Revenue, Attendees, AuctionRevenue, NPS (placeholder if no Feedback row). Returns 4 metric rows × 4 cols (2024/2025/2026/Trend). DEGRADED if fewer than 3 years of history exist. metadata.note='Best-effort heuristic — assumes recurring annual event with similar name' | `eventId` |

**Composite vs. Per-Widget**: **All Path-A per-widget** (no Path-B/C composite handler). Rationale: matches Case Dashboard #52 / Volunteer Dashboard #57 precedent — 14 parallel SQL function calls via the generic `generateWidgets` GraphQL handler. Filter (`eventId`) is fixed per page-load; no need for composite refresh-on-filter optimization.

**Existing GQL queries reused** (no new C# code):

| GQL Field | Returns | Used For |
|-----------|---------|----------|
| `events` (existing `GetEvents`) | `EventResponseDto[]` paginated | Event-selector dropdown — filter `eventStatusCode='COMPLETED'` client-side |
| `eventById(eventId)` (existing `GetEventById`) | `EventResponseDto` | EventOverviewBar — fetch event name/date/venue/status |
| `generateWidgets(widgetId, parameters)` (existing) | `WidgetData` | All 13 widget data calls — runtime resolves `Widget.StoredProcedureName` and runs the Postgres function with `p_filter_json={eventId}` |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (Path-A function bodies) → Frontend Developer (filter behavior, role-gating)

**Page Scope:**
- Page requires `?eventId=N` URL param. Missing → render "Select an event" empty state with the event-selector active. Do NOT silently load any default.
- Event-selector dropdown only lists events where `EventStatus.MasterDataCode = 'COMPLETED'`. Future-dated and active-status events are excluded — this is post-event analytics.
- Filter for current Company (`Event.CompanyId = current_user.CompanyId`) is enforced by every Path-A function via `p_company_id` argument.

**Role-Scoped Data Access:**
- **BUSINESSADMIN** sees all events for their company — no filter.
- Other roles' access governed by `auth.RoleCapabilities(RoleId, MenuId=EVENTANALYTICS_MenuId, CapabilityId=READ, HasAccess=true)`. Branch-scoping is NOT applied (events are company-wide, not branch-scoped).
- Widget-level gating via `auth.WidgetRoles` — restricted widgets are omitted on render (do not show "Restricted" placeholder for cleaner board-meeting view). Track as a build decision in ISSUE-7.

**Calculation Rules:**
- **Total Revenue** = SUM(EventRegistration.TotalAmount WHERE Status IN ['CONFIRMED','CHECKEDIN']) + SUM(AuctionItem.WinningBidAmount WHERE WinnerContactId NOT NULL). Excludes on-site donations until ISSUE-3 resolved.
- **Goal Progress %** = TotalRevenue / Event.GoalAmount × 100. Subtitle color = success-green if ≥100%, neutral-grey otherwise.
- **Attendance Rate** = COUNT(CheckedIn) / SUM(EventTicket.QuantityAvailable). Cap at 100% (don't exceed even if walk-ins push count past quantity).
- **Per-Ticket Attendance Rate** = COUNT(Attended) / COUNT(Registered). Color thresholds: green ≥90%, amber 80-90%, red <80%.
- **New Donors** = DISTINCT Contacts whose EventRegistration is their first AND who appear in GlobalDonation WHERE DonationDate >= Event.StartDate. **DEGRADED** without `GlobalDonation.EventId` — see ISSUE-3.
- **Donor Acquisition Cost** = Event.TotalCost / NewDonorsCount. **DEGRADED** until cost entity exists.
- **ROI** = (TotalRevenue − TotalCost) / TotalCost × 100. **DEGRADED** until cost entity exists.
- **YoY Trend** computed as `(current_year_value − prior_year_value) / prior_year_value × 100`. Arrow direction: ▲ if positive, ▼ if negative. Color: green if direction is favorable for the metric.

**Multi-Currency Rules:**
- All revenue amounts displayed in `Event.CurrencyId` (per Event setting), defaulting to `Company.DefaultCurrencyId` if event currency is null.
- Cross-event YoY: assume same currency across years; if a prior year used a different currency, mark that year cell with a `⚠` indicator (tooltip explains). Future enhancement: ExchangeRate conversion at row's recorded rate.

**Widget-Level Rules:**
- Each widget is rendered only if `WidgetRole(WidgetId, currentRoleId, HasAccess=true)`. Restricted widgets are OMITTED (per ISSUE-7 decision).
- **Workflow**: None — read-only dashboard.

**Header Actions Behavior:**
- **Export Report** (Primary button, top-right) — SERVICE_PLACEHOLDER. Builds the full multi-page PDF report. Toast: "PDF export pending — server-side rendering service not wired."
- **Print** — invokes `window.print()` with print-stylesheet that hides chrome and renders widgets in linear order.
- **Share with Board** — SERVICE_PLACEHOLDER. Composes an email with a deep-link to this page + an attached PDF. Toast: "Email sharing pending — Communication service integration deferred."

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered per mockup + variant decision.

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD (non-standard parent: CRM_EVENT, NOT *_DASHBOARDS)
**Reason**: Sidebar leaf at `crm/event/eventanalytics`, deep-linkable from board emails, role-restricted to leadership/fundraising. Event-scoped via `?eventId` URL param (similar to Auction Management #48 console pattern).

**Backend Implementation Path**: **Path A across ALL 13 widgets** — Postgres functions returning `TABLE(data jsonb, metadata jsonb, total_count int, filtered_count int)`, conforming to the fixed 5-arg contract. Reuses existing `generateWidgets` GraphQL handler. NO new C# code, NO new BE migrations (other than possibly Event.TotalCostAmount column — out of this prompt's scope, ISSUE-6).

**Path-A Function Contract (NON-NEGOTIABLE):**

Every function MUST:
- Take 5 fixed inputs in this order: `p_filter_json jsonb, p_page integer, p_page_size integer, p_user_id integer, p_company_id integer`
- Return `TABLE(data jsonb, metadata jsonb, total_count integer, filtered_count integer)` — 1 row, 4 columns
- Extract `eventId` from `p_filter_json` via `NULLIF(p_filter_json->>'eventId','')::integer`
- Return empty data + `metadata->>'eventIdMissing'='true'` if eventId is null
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION`, `LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators)
- Live at `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/app/fn_event_analytics_{name}.sql` — snake_case names
- `Widget.DefaultParameters` JSON value: `{ "eventId": "{eventId}" }` — placeholder substituted at render time by FE filter context

**Backend Patterns Required:**
- [x] Tenant scoping — every function joins/filters on `CompanyId = p_company_id`
- [x] eventId scoping — every function filters on `EventId = (p_filter_json->>'eventId')::int`
- [ ] Role-scoped data filtering — N/A (events are company-wide)
- [ ] Materialized view — N/A (post-event data is mostly static; no perf issue expected)
- [ ] Drill-down arg handler — drill-down clicks pass `eventId` to destination screens (Event Ticketing, Auction Management) — confirm those screens accept `?eventId=N` URL param (they do, per #46 / #48)

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` — rendered by `<MenuDashboardComponent />` (EXTENDED with filterContext prop — see ISSUE-1)
- [x] **12 NEW renderers** — under `dashboards/widgets/event-analytics-widgets/` — one per visual treatment. NO reuse of legacy `WIDGET_REGISTRY` entries (`StatusWidgetType1`, etc.). NO reuse of Case-Dashboard / Volunteer-Dashboard renderers (cross-dashboard reuse is forbidden per template § 5).
- [x] Query registry — N/A (Path A reuses `generateWidgets` — no new gql doc to register in `QUERY_REGISTRY`)
- [x] Filter context — page passes `filterContext={{ eventId }}` to `<MenuDashboardComponent />`; component merges into every widget's `DefaultParameters` substitution at runtime
- [x] Skeleton states — shape-matched per renderer (KPI tile / donut+table hybrid / row-table / line-chart / list / multi-section feedback panel / metric-pair ROI table / matrix table)
- [x] Event-selector popover — page-level component (NOT a widget); calls `EVENTS_QUERY` and filters client-side by `eventStatusCode==='COMPLETED'`
- [x] EventOverviewBar strip — page-level component above grid; fetches via `eventById(eventId)` query
- [x] Page chrome — header with back button + breadcrumb + title + 3 action buttons (Export / Print / Share); event-selector below title; EventOverviewBar; then widget grid
- [x] **SERVICE_PLACEHOLDER badge** — 4 widgets render an amber chip in the top-right (KPI 5 New Donors, KPI 6 Cost Per Attendee, Feedback Panel, ROI Table) — clear visual signal that data is degraded

**Code Reference Templates** (loaded automatically by BE/FE developer agents for `screen_type: DASHBOARD`):
- BE: `code-reference-backend.md` § Path-A Recipe Library — KPI / Donut / Multi-row table / Alert recipes
- FE: `code-reference-frontend.md` § Widget Design Quality Standards — KPI visual spec, chart palette/tooltip, table density, skeleton shapes, Phosphor icon catalog

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer

### Page Layout (vertical sequence)

```
┌──────────────────────────────────────────────────────────────────┐
│ PAGE HEADER ─────────────────────────────────────────────────────│
│ [←] Events › Post-Event Analytics                                │
│      Post-Event Analytics                                        │
│      Comprehensive event performance analysis                    │
│      [Event Selector: Fundraising Gala 2026 ▼]                   │
│                                  [Export Report] [Print] [Share]│
│                                                                  │
│ EVENT OVERVIEW BAR ──────────────────────────────────────────────│
│ Fundraising Gala 2026 | 📅 Apr 20, 2026 | 📍 Grand Hyatt Dubai | │
│ ✓ Completed                                                      │
│                                                                  │
│ ┌───── 6 KPI HERO CARDS (2 rows × 3 cols on lg) ─────────────┐   │
│ │ [KPI1 Total Rev] [KPI2 Ticket Rev] [KPI3 Auction Rev]      │   │
│ │ [KPI4 Attendance] [KPI5 New Donors⚠] [KPI6 Cost⚠]          │   │
│ └────────────────────────────────────────────────────────────┘   │
│                                                                  │
│ ┌───── REVENUE BREAKDOWN (full width) ───────────────────────┐   │
│ │ [Donut chart 5-col] [Source amount % table 7-col]          │   │
│ └────────────────────────────────────────────────────────────┘   │
│                                                                  │
│ ┌───── ATTENDANCE ANALYSIS (full width, ticket-type table) ──┐   │
│ │ TicketType | Registered | Attended | NoShow | Rate-bar     │   │
│ └────────────────────────────────────────────────────────────┘   │
│                                                                  │
│ ┌───── CHECK-IN TIMELINE (full width line chart) ────────────┐   │
│ │ 6PM ─────── 7PM ●●●●● 8PM ●● 9PM ● 10PM ─ 11PM             │   │
│ └────────────────────────────────────────────────────────────┘   │
│                                                                  │
│ ┌───── DONOR ENGAGEMENT (5 stat rows list) ──────────────────┐   │
│ │ 👤+ First-time attendees    89 (32%)                       │   │
│ │ 🔄 Returning attendees     189 (68%)                       │   │
│ │ 💝 Donated at event        178 (64%)                       │   │
│ │ ⭐ New donors acquired      34 (12.2%)                     │   │
│ │ 📈 Avg engagement score     72 (vs org avg 54)             │   │
│ └────────────────────────────────────────────────────────────┘   │
│                                                                  │
│ ┌───── FEEDBACK & SATISFACTION ⚠ (composite full-width) ─────┐   │
│ │ [Overall ★4.2/5 + Category Bars (6-col)] [NPS + Lists (6)] │   │
│ └────────────────────────────────────────────────────────────┘   │
│                                                                  │
│ ┌───── ROI ANALYSIS ⚠ (centered metric-pair table) ──────────┐   │
│ │ Total Revenue $128,400 | Total Costs $24,700 (red)         │   │
│ │ Net Revenue $103,700 ⓘ | ROI 420% ⓘ                        │   │
│ │ Cost per $ Raised $0.19 | Revenue per Attendee $462        │   │
│ │ Donor Acquisition Cost $726 (for 34 new donors)            │   │
│ └────────────────────────────────────────────────────────────┘   │
│                                                                  │
│ ┌───── YEAR-OVER-YEAR COMPARISON (4 metric rows × 4 cols) ───┐   │
│ │ Metric    | 2024   | 2025   | 2026   | Trend               │   │
│ │ Revenue   | $78.5K | $95.2K | $128K  | ▲35%                │   │
│ │ Attendees | 180    | 225    | 278    | ▲24%                │   │
│ │ Auction   | $22K   | $32.5K | $45.6K | ▲40%                │   │
│ │ NPS Score | +32    | +38    | +45    | ▲improving          │   │
│ └────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

### Grid Layout (`react-grid-layout` LayoutConfig)

**Breakpoints:**

| Breakpoint | min width | columns |
|------------|-----------|---------|
| xs | 0 | 4 |
| sm | 640 | 6 |
| md | 768 | 8 |
| lg | 1024 | 12 |
| xl | 1280 | 12 |

**Widget placement (lg breakpoint shown; restate in seed for md/sm/xs):**

| i (instanceId) | Widget | x | y | w | h | minW | minH | Notes |
|----------------|--------|---|---|---|---|------|------|-------|
| `kpi-total-revenue` | Total Revenue (hero) | 0 | 0 | 4 | 2 | 3 | 2 | Hero — wider |
| `kpi-ticket-revenue` | Ticket Revenue | 4 | 0 | 4 | 2 | 3 | 2 | Cyan accent |
| `kpi-auction-revenue` | Auction Revenue | 8 | 0 | 4 | 2 | 3 | 2 | Purple events accent |
| `kpi-attendance` | Attendees | 0 | 2 | 4 | 2 | 3 | 2 | Fraction format X/Y |
| `kpi-new-donors` | New Donors ⚠ | 4 | 2 | 4 | 2 | 3 | 2 | Amber placeholder chip |
| `kpi-cost-per-attendee` | Cost per Attendee ⚠ | 8 | 2 | 4 | 2 | 3 | 2 | Amber placeholder chip |
| `revenue-breakdown` | Revenue Breakdown (donut+table) | 0 | 4 | 12 | 6 | 8 | 5 | Full-width composite |
| `attendance-table` | Attendance Analysis | 0 | 10 | 12 | 6 | 8 | 5 | Full-width table w/ inline progress |
| `checkin-timeline` | Check-in Timeline | 0 | 16 | 12 | 4 | 8 | 3 | Full-width line chart |
| `donor-engagement` | Donor Engagement | 0 | 20 | 6 | 4 | 4 | 3 | Half-width list |
| `feedback-panel` | Feedback & Satisfaction ⚠ | 6 | 20 | 6 | 4 | 4 | 3 | Half-width composite |
| `roi-table` | ROI Analysis ⚠ | 0 | 24 | 6 | 4 | 4 | 3 | Half-width centered |
| `yoy-comparison` | YoY Comparison | 6 | 24 | 6 | 4 | 4 | 3 | Half-width matrix table |

**md / sm / xs reflow rules:**
- md (8-col): KPIs reflow to 2×3 (2 wide × 3 tall). Revenue Breakdown stays full width but donut stacks above table. Half-width widgets (engagement / feedback / ROI / YoY) become full-width sequential.
- sm (6-col): KPIs reflow to 1×6 stack. All composite widgets stack full-width.
- xs (4-col): pure single-column linear stack. Hide low-priority widgets? NO — render all linearly. Tables convert to compact density.

### Widget Catalog (one row per instance)

> **WidgetType.ComponentPath** = exact key in `dashboard-widget-registry.tsx` `WIDGET_REGISTRY`
> **Path** = A across all widgets (Postgres functions)
> **Data Source** = function name (Path A)

| # | InstanceId | Title | ComponentPath | Path | Data Source | Filters | Drill-Down |
|---|-----------|-------|---------------|------|-------------|---------|-----------|
| 1 | `kpi-total-revenue` | Total Revenue | `EventRevenueTotalKpiWidget` | A | `app.fn_event_analytics_kpi_total_revenue` | `eventId` | → `crm/donation/globaldonation?eventId=N` (SERVICE_PLACEHOLDER until link exists) |
| 2 | `kpi-ticket-revenue` | Ticket Revenue | `EventTicketRevenueKpiWidget` | A | `app.fn_event_analytics_kpi_ticket_revenue` | `eventId` | → `crm/event/eventticketing?eventId=N` |
| 3 | `kpi-auction-revenue` | Auction Revenue | `EventAuctionRevenueKpiWidget` | A | `app.fn_event_analytics_kpi_auction_revenue` | `eventId` | → `crm/event/auctionmanagement?eventId=N` |
| 4 | `kpi-attendance` | Attendees | `EventAttendanceKpiWidget` | A | `app.fn_event_analytics_kpi_attendance` | `eventId` | → `crm/event/eventticketing?eventId=N&tab=registrants` |
| 5 | `kpi-new-donors` | New Donors | `EventNewDonorsKpiWidget` | A | `app.fn_event_analytics_kpi_new_donors` (DEGRADED) | `eventId` | — (deferred) |
| 6 | `kpi-cost-per-attendee` | Cost per Attendee | `EventCostPerAttendeeKpiWidget` | A | `app.fn_event_analytics_kpi_cost_per_attendee` (PLACEHOLDER) | `eventId` | — (deferred) |
| 7 | `revenue-breakdown` | Revenue Breakdown | `EventRevenueBreakdownWidget` | A | `app.fn_event_analytics_revenue_breakdown` | `eventId` | Per row → corresponding source page |
| 8 | `attendance-table` | Attendance Analysis | `EventAttendanceTableWidget` | A | `app.fn_event_analytics_attendance_by_ticket` | `eventId` | Row → `crm/event/eventticketing?eventId=N&ticketTypeId=M` |
| 9 | `checkin-timeline` | Check-in Timeline | `EventCheckinTimelineChartWidget` | A | `app.fn_event_analytics_checkin_timeline` | `eventId` | — |
| 10 | `donor-engagement` | Donor Engagement | `EventDonorEngagementListWidget` | A | `app.fn_event_analytics_donor_engagement` | `eventId` | — |
| 11 | `feedback-panel` | Feedback & Satisfaction | `EventFeedbackPanelWidget` | A | `app.fn_event_analytics_feedback_panel` (PLACEHOLDER) | `eventId` | — |
| 12 | `roi-table` | ROI Analysis | `EventRoiTableWidget` | A | `app.fn_event_analytics_roi` (DEGRADED) | `eventId` | — |
| 13 | `yoy-comparison` | Year-over-Year | `EventYoyTableWidget` | A | `app.fn_event_analytics_yoy_comparison` | `eventId` | Trend row click → past year's analytics? (deferred — see ISSUE-8) |

### KPI Cards (visual hierarchy — NOT clones)

| # | Title | Value Source | Format | Subtitle | Visual Treatment | Color |
|---|-------|--------------|--------|----------|------------------|-------|
| 1 | Total Revenue | `totalRevenue` | currency, hero size (2.25rem) | "{progressPct}% of {goalAmount} goal" — green if ≥100% | **Hero**: gradient cyan strip on left edge, large icon `ph:trend-up`, accent border-left 4px | `#0e7490` (cyan-700) |
| 2 | Ticket Revenue | `ticketRevenue` | currency, value size (1.5rem) | "From {ticketTypeCount} ticket types" | Icon top-left `ph:ticket`, accent dot row | `#06b6d4` (cyan-500) |
| 3 | Auction Revenue | `auctionRevenue` | currency, value size | "Silent ${silent} + Live ${live}" | Icon top-left `ph:gavel`, **purple** accent (matches events theme) | `#7c3aed` (events-accent) |
| 4 | Attendees | `attendedCount / capacity` | fraction (e.g., "278 / 300") | "{attendanceRate}% attendance" — green if ≥90%, amber 80-89%, red <80% | Icon `ph:users-three`, mini-radial-progress ring around fraction | `#22c55e` if green, `#f59e0b` amber, `#dc2626` red |
| 5 | New Donors ⚠ | `newDonorsCount` | integer | "First-time attendees who donated" + `[Placeholder]` chip | Icon `ph:star`, **amber** SERVICE_PLACEHOLDER chip top-right | `#f59e0b` (amber) |
| 6 | Cost per Attendee ⚠ | `costPerAttendee` | currency | "Total cost: {totalCost}" + `[Placeholder]` chip | Icon `ph:wallet`, **amber** SERVICE_PLACEHOLDER chip top-right | `#64748b` (slate) |

> **Renderer differentiation matrix**: Hero (KPI 1) ≠ icon-left supporting (KPIs 2/3) ≠ icon-with-ring (KPI 4) ≠ amber-placeholder (KPIs 5/6). 4 distinct visual treatments across 6 KPI tiles. Skeleton states match each shape.

### Charts (detail)

| # | Title | Type | X | Y | Source | Filters | Empty State |
|---|-------|------|---|---|--------|---------|-------------|
| 7 | Revenue Breakdown (donut sub) | donut | Source label | Amount % | `revenue-breakdown.rows` | eventId | "No revenue recorded yet" |
| 9 | Check-in Timeline | line / area | Hour bucket (`6PM..11PM` or event-window-derived) | Count per bucket | `checkin-timeline.hourBuckets` | eventId | "No check-ins recorded" — show empty x-axis with event window |

**Chart styling rules (FE):**
- ApexCharts for line chart (`Check-in Timeline`) — area variant, gradient fill, soft cyan
- ApexCharts for donut chart (`Revenue Breakdown`) — 7-color palette matching mockup row dots: `#7c3aed`, `#0e7490`, `#06b6d4`, `#22c55e`, `#f59e0b`, `#ef4444`, `#8b5cf6`. Inner label = total revenue.
- Tooltips use `Company.DefaultCurrency` formatting.
- No legends inside the donut chart (the side table IS the legend).

### Tables (detail)

| # | Title | Shape | Source | Inline Visualizations |
|---|-------|-------|--------|------------------------|
| 7 | Revenue Breakdown table | 3 cols × 7 rows (Source / Amount / %) | `revenue-breakdown.rows` | colored dot per row matching donut slice |
| 8 | Attendance Analysis | 5 cols × N+1 rows (Type / Reg / Att / NoShow / Rate) | `attendance-by-ticket.rows` | inline-progress bar per row + bold Total row |
| 12 | ROI Analysis | 2 cols × 7 rows (Label / Value) | `roi.metrics` | highlight rows: Net Revenue + ROI in accent-bg |
| 13 | YoY Comparison | 5 cols × 4 rows (Metric / 2024 / 2025 / 2026 / Trend) | `yoy.years` | trend cell: `▲35%` green / `▼12%` red |

### Composite Widgets (detail)

**Donor Engagement List** (widget 10):
- 5 stat rows, single column
- Each row: `[icon] label` left-aligned + `value (pct)` right-aligned
- Icons per mockup: `ph:user-plus`, `ph:arrow-clockwise`, `ph:hand-heart`, `ph:star`, `ph:chart-line`

**Feedback Panel ⚠** (widget 11) — 2-column composite:
- LEFT column:
  - Overall rating: large 2.5rem `4.2` + "out of 5.0" + ★★★★½ star row
  - 4 category bars (Venue / Program / Food & Beverage / Networking) with colored h-bar-track and right-aligned value
- RIGHT column:
  - NPS Score: label + large `+45` + 3-segment stacked bar (Promoters 58% green / Passives 29% amber / Detractors 13% red) + legend row
  - Top Positive Feedback: green-uppercase heading + 3 list items with check-circle icons
  - Top Improvement Areas: amber-uppercase heading + 3 list items with exclamation-circle icons
- **SERVICE_PLACEHOLDER amber chip** in header

### Filter Controls

> Page is event-scoped — the only "filter" is the event-selector. No date range (the period IS the event date). No branch filter (events are company-wide).

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Event | dropdown popover (single-select) | URL `?eventId` | ALL widgets | Loads completed events for current Company; on change → push URL `?eventId=N` → MenuDashboardComponent refreshes all widgets |

### Drill-Down / Navigation Map

| From Widget / Element | Click On | Navigates To | Prefill |
|-----------------------|----------|--------------|---------|
| KPI Total Revenue | Card click | `crm/donation/globaldonation?eventId=N` | eventId (SERVICE_PLACEHOLDER — destination doesn't accept eventId yet, see ISSUE-9) |
| KPI Ticket Revenue | Card click | `crm/event/eventticketing?eventId=N` | eventId |
| KPI Auction Revenue | Card click | `crm/event/auctionmanagement?eventId=N` | eventId |
| KPI Attendance | Card click | `crm/event/eventticketing?eventId=N&tab=registrants` | eventId, tab |
| Revenue Breakdown row | Row click | corresponding source page (ticket-types → eventticketing, auction → auctionmanagement) | eventId |
| Attendance Table row | Row click | `crm/event/eventticketing?eventId=N&ticketTypeId=M` | eventId, ticketTypeId |
| Back button (page header) | Button click | `crm/event/event` | — |

### User Interaction Flow

1. **User clicks "Analytics" on a completed event row** in the Events grid (#40) → URL becomes `/{lang}/crm/event/eventanalytics?eventId=123` → page loads.
2. **Page renders shell**: PageHeader + EventSelector + EventOverviewBar (fetches `eventById(123)`) above the widget grid.
3. **`<MenuDashboardComponent />` mounts** with `dashboardCode="EVENTANALYTICS"` and `filterContext={{ eventId: 123 }}` → fires `dashboardByModuleAndCode('CRM', 'EVENTANALYTICS')` → receives Dashboard + DashboardLayout JSON.
4. **All 13 widgets parallel-fetch** via `generateWidgets(widgetId, parameters)` — each gets `{ eventId: 123 }` resolved into its `DefaultParameters`. SQL functions execute, return data.
5. **Widgets render** in their grid cells with shape-matched skeletons during fetch.
6. **User clicks event-selector** → popover lists completed events for current Company → user picks "Charity Dinner 2025" → URL updates to `?eventId=456` → search-param change triggers MenuDashboardComponent re-mount → all widgets refetch with new eventId.
7. **User clicks a drill-down** (e.g., Attendance row) → navigates to `crm/event/eventticketing?eventId=123&ticketTypeId=5` → user lands on filtered registrants list.
8. **Back navigation** → returns to dashboard with `?eventId=123` preserved.
9. **User clicks Export Report** → SERVICE_PLACEHOLDER toast.
10. **User clicks Print** → `window.print()` with print stylesheet that hides chrome.
11. **Empty / loading / error states**: each widget renders its own skeleton during fetch; error → red mini banner + Retry button; empty (eventId missing) → "Select an event to view analytics" with event-selector emphasized.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Volunteer Dashboard #57 is the canonical reference (most recent MENU_DASHBOARD with the same Path-A pattern).

**Canonical Reference**: `#57 Volunteer Dashboard` (built 2026-04-30) — Path-A across all widgets, NEW renderer set, per-route stub pattern.

| Canonical (`#57 VolunteerDashboard`) | → This Dashboard (`EventAnalytics`) | Context |
|---------------------------------------|-------------------------------------|---------|
| VolunteerDashboard | EventAnalytics | screen / page-config name |
| VOLUNTEERDASHBOARD | EVENTANALYTICS | DashboardCode + Menu.MenuCode |
| volunteerdashboard | eventanalytics | route folder + slug |
| crm/dashboards/volunteerdashboard | **crm/event/eventanalytics** | route path (NOTE: parent is `crm/event`, NOT `crm/dashboards`) |
| CRM_DASHBOARDS | **CRM_EVENT** | ParentMenu (deviation — non-standard parent) |
| app (volunteer entities) | **app** (event entities) | source schema (reuses `app/` Functions folder created for #57) |
| volunteer-dashboard-widgets/ | **event-analytics-widgets/** | renderer folder name |
| `Volunteer{Purpose}{Kind}Widget` | `Event{Purpose}{Kind}Widget` | renderer naming convention |
| `app.fn_volunteer_dashboard_*` | **`app.fn_event_analytics_*`** | Postgres function namespace |
| `VolunteerDashboardPageConfig` | `EventAnalyticsPageConfig` | page-config component name |
| Period + Branch filters | **Event filter (single-select, URL-driven)** | filter model (deviation — no Period/Branch) |
| 2 Filters in toolbar | **1 event-selector + 3 header actions (Export/Print/Share)** | toolbar contents |

**MenuDashboardComponent extension** (required for this prompt — see ISSUE-1):
- Add optional `filterContext?: Record<string, string | number>` prop
- At widget-data-fetch time, merge `filterContext` into each widget's resolved `DefaultParameters` (replace `{eventId}` placeholders with the actual value)
- Backward-compatible — existing callers (#52 Case, #57 Volunteer) that don't pass `filterContext` continue to work

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Fewer files than MASTER_GRID/FLOW because no entity CRUD. Bulk of work: 13 Postgres functions + 12 NEW renderers + 1 page-config + 1 seed.

### Backend Files (Path A only — NO new C# code)

| # | File | Path | Required |
|---|------|------|----------|
| 1 | `fn_event_analytics_kpi_total_revenue.sql` | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/app/fn_event_analytics_kpi_total_revenue.sql` | always |
| 2 | `fn_event_analytics_kpi_ticket_revenue.sql` | same folder | always |
| 3 | `fn_event_analytics_kpi_auction_revenue.sql` | same folder | always |
| 4 | `fn_event_analytics_kpi_attendance.sql` | same folder | always |
| 5 | `fn_event_analytics_kpi_new_donors.sql` | same folder | always (DEGRADED) |
| 6 | `fn_event_analytics_kpi_cost_per_attendee.sql` | same folder | always (PLACEHOLDER) |
| 7 | `fn_event_analytics_revenue_breakdown.sql` | same folder | always |
| 8 | `fn_event_analytics_attendance_by_ticket.sql` | same folder | always |
| 9 | `fn_event_analytics_checkin_timeline.sql` | same folder | always |
| 10 | `fn_event_analytics_donor_engagement.sql` | same folder | always |
| 11 | `fn_event_analytics_feedback_panel.sql` | same folder | always (PLACEHOLDER) |
| 12 | `fn_event_analytics_roi.sql` | same folder | always (DEGRADED) |
| 13 | `fn_event_analytics_yoy_comparison.sql` | same folder | always |

> **`app/` folder already exists** — created for Volunteer Dashboard #57. Just add the 13 new files. NO migration needed (functions auto-apply on startup via existing DatabaseScripts loader).

### Backend Wiring

| # | File | Change |
|---|------|--------|
| 1 | (none) | NO new C# code, NO new GraphQL endpoints, NO new Mapster profiles, NO new DbContext changes |

### Frontend Files

| # | File | Path | Required |
|---|------|------|----------|
| 1 | `_shared.tsx` | `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/event-analytics-widgets/_shared.tsx` | always — palette, icon resolver, useEventContext hook (reads filterContext.eventId), SERVICE_PLACEHOLDER badge component, sample-data factories for the 4 placeholder widgets, currency formatter, attendance-rate color cue |
| 2 | `EventRevenueTotalKpiWidget.tsx` | `dashboards/widgets/event-analytics-widgets/` | always |
| 3 | `EventTicketRevenueKpiWidget.tsx` | same folder | always |
| 4 | `EventAuctionRevenueKpiWidget.tsx` | same folder | always |
| 5 | `EventAttendanceKpiWidget.tsx` | same folder | always |
| 6 | `EventNewDonorsKpiWidget.tsx` | same folder | always |
| 7 | `EventCostPerAttendeeKpiWidget.tsx` | same folder | always |
| 8 | `EventRevenueBreakdownWidget.tsx` | same folder | always (composite donut + table renderer) |
| 9 | `EventAttendanceTableWidget.tsx` | same folder | always (table with inline progress) |
| 10 | `EventCheckinTimelineChartWidget.tsx` | same folder | always (ApexCharts area chart) |
| 11 | `EventDonorEngagementListWidget.tsx` | same folder | always (5-row stat list) |
| 12 | `EventFeedbackPanelWidget.tsx` | same folder | always (composite 2-col panel — placeholder-tagged) |
| 13 | `EventRoiTableWidget.tsx` | same folder | always (metric-pair table — degraded-tagged) |
| 14 | `EventYoyTableWidget.tsx` | same folder | always (4-col matrix table) |
| 15 | `index.ts` (barrel) | `dashboards/widgets/event-analytics-widgets/index.ts` | always — re-export all 12 renderers + _shared |
| 16 | `event-analytics-page-config.tsx` | `PSS_2.0_Frontend/src/app/[lang]/crm/event/eventanalytics/event-analytics-page-config.tsx` (or page-config conventions) | always — wires `<MenuDashboardComponent moduleCode="CRM" dashboardCode="EVENTANALYTICS" filterContext={{ eventId }} />` + page chrome (header + EventSelector + EventOverviewBar + action buttons) |
| 17 | `event-selector.tsx` | `dashboards/widgets/event-analytics-widgets/event-selector.tsx` (or page-level location) | always — popover/dropdown listing Completed events, calls existing `EVENTS_QUERY`, updates URL searchParam |
| 18 | `event-overview-bar.tsx` | same folder | always — strip showing event name / date / venue / status, fetches via existing `eventById(eventId)` query |
| 19 | `page.tsx` (overwrite stub) | `PSS_2.0_Frontend/src/app/[lang]/crm/event/eventanalytics/page.tsx` | always — replace 6-line UnderConstruction stub with `<EventAnalyticsPageConfig />` |
| 20 | `<MenuDashboardComponent />` extension | `PSS_2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx` | always (ISSUE-1) — add optional `filterContext?: Record<string, string\|number>` prop; merge into each widget's DefaultParameters at runtime |

### Frontend Wiring

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | extend `WIDGET_REGISTRY` with 12 new entries: `EventRevenueTotalKpiWidget`, `EventTicketRevenueKpiWidget`, ... `EventYoyTableWidget` — each mapping to the imported component |
| 2 | `dashboard-widget-query-registry.tsx` | NO CHANGE — Path A reuses `generateWidgets` handler, no new gql doc |
| 3 | sidebar / menu config | NO CHANGE — Menu row already exists, renders via normal sidebar mechanism (non-`*_DASHBOARDS` parent → no auto-injection logic involved) |

### DB Seed File

`sql-scripts-dyanmic/EventAnalytics-sqlscripts.sql` (preserve repo's `dyanmic` typo):

| # | Item | Notes |
|---|------|-------|
| 1 | INSERT Dashboard row `EVENTANALYTICS` | DashboardCode, DashboardName, DashboardIcon (`ph:chart-line-up`), DashboardColor (`#0e7490`), ModuleId resolved to CRM, IsSystem=true, IsActive=true, CompanyId=NULL (system), MenuId=NULL initially |
| 2 | INSERT 12 WidgetType rows | One per renderer; ComponentPath matches FE registry keys |
| 3 | INSERT 13 Widget rows | StoredProcedureName = schema-qualified function name; DefaultParameters JSON `{ "eventId": "{eventId}" }`; ModuleId=CRM; IsSystem=true |
| 4 | INSERT 1 DashboardLayout row | LayoutConfig JSON (lg/md/sm/xs all populated) + ConfiguredWidget JSON × 13 instances + 1 (EventOverviewBar is NOT a widget row — it's a page-level component, so 13 entries in ConfiguredWidget) |
| 5 | INSERT 13 WidgetRole rows | BUSINESSADMIN granted READ on each Widget |
| 6 | UPDATE Dashboard.MenuId | `UPDATE sett."Dashboards" SET "MenuId" = m."MenuId" FROM auth."Menus" m WHERE m."MenuCode"='EVENTANALYTICS' AND d."DashboardCode"='EVENTANALYTICS' AND d."MenuId" IS NULL` (idempotent) |
| 7 | All inserts wrapped in `WHERE NOT EXISTS` guards | for idempotent re-run |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

MenuName: Event Analytics                 # already seeded in Pss2.0_Global_Menus_List.sql
MenuCode: EVENTANALYTICS                   # already seeded
ParentMenu: CRM_EVENT                      # NON-STANDARD parent (not CRM_DASHBOARDS)
Module: CRM
MenuUrl: crm/event/eventanalytics          # already seeded
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT

GridFormSchema: SKIP                        # dashboards have no RJSF form
GridCode: EVENTANALYTICS

# Dashboard-specific seed inputs
DashboardCode: EVENTANALYTICS
DashboardName: Post-Event Analytics
DashboardIcon: ph:chart-line-up
DashboardColor: #0e7490
IsSystem: true
DashboardKind: MENU_DASHBOARD               # presence of Dashboard.MenuId encodes this
OrderBy: 4                                  # already seeded on auth.Menus row

WidgetGrants:                               # BUSINESSADMIN on all 13
  - EVENT_REVENUE_TOTAL_KPI: BUSINESSADMIN
  - EVENT_TICKET_REVENUE_KPI: BUSINESSADMIN
  - EVENT_AUCTION_REVENUE_KPI: BUSINESSADMIN
  - EVENT_ATTENDANCE_KPI: BUSINESSADMIN
  - EVENT_NEW_DONORS_KPI: BUSINESSADMIN
  - EVENT_COST_PER_ATTENDEE_KPI: BUSINESSADMIN
  - EVENT_REVENUE_BREAKDOWN: BUSINESSADMIN
  - EVENT_ATTENDANCE_TABLE: BUSINESSADMIN
  - EVENT_CHECKIN_TIMELINE_CHART: BUSINESSADMIN
  - EVENT_DONOR_ENGAGEMENT_LIST: BUSINESSADMIN
  - EVENT_FEEDBACK_PANEL: BUSINESSADMIN
  - EVENT_ROI_TABLE: BUSINESSADMIN
  - EVENT_YOY_TABLE: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer
> Path A across all widgets — NO new typed GraphQL handlers. All widget data flows through the existing `generateWidgets(widgetId, parameters)` field.

**Reused existing GQL fields:**

| GQL Field | Returns | Args | Used For |
|-----------|---------|------|----------|
| `events` (existing `GetEvents`) | `EventResponseDto[]` | filter, pagination | Event-selector dropdown — filter completed events client-side |
| `eventById` (existing `GetEventById`) | `EventResponseDto?` | eventId | EventOverviewBar — fetch name/date/venue/status |
| `generateWidgets` (existing — Path A runtime) | `{ data: JSON, metadata: JSON, totalCount: int, filteredCount: int }` | `widgetId: int, parameters: JSON` | All 13 widget data calls |
| `dashboardByModuleAndCode` (existing — built in #52 Phase 2) | `DashboardResponseDto?` w/ DashboardLayouts include | moduleCode='CRM', dashboardCode='EVENTANALYTICS' | MenuDashboardComponent's single query |

**Per-Widget `data jsonb` Shapes** (returned by Path-A functions):

| Widget | `data jsonb` shape |
|--------|---------------------|
| KPI Total Revenue | `{ totalRevenue: number, goalAmount: number, goalProgressPct: number, currencyCode: string }` |
| KPI Ticket Revenue | `{ ticketRevenue: number, ticketTypeCount: int, currencyCode: string }` |
| KPI Auction Revenue | `{ auctionRevenue: number, silentRevenue: number, liveRevenue: number, currencyCode: string }` |
| KPI Attendance | `{ attendedCount: int, capacity: int, attendanceRatePct: number, registeredCount: int }` |
| KPI New Donors | `{ newDonorsCount: int, placeholder: true }` |
| KPI Cost Per Attendee | `{ costPerAttendee: number, totalCost: number, currencyCode: string, placeholder: true }` |
| Revenue Breakdown | `{ totalRevenue: number, rows: [{label, amount, percent, color, sourceType}] }` |
| Attendance Table | `{ rows: [{ticketTypeName, registered, attended, noShow, ratePct, colorCue, isWalkIn}], total: {registered, attended, noShow, ratePct} }` |
| Check-in Timeline | `{ hourBuckets: [{hour: '18:00', count: int}], peakBucket: {hour, count, sharePct} }` |
| Donor Engagement | `{ items: [{ key, label, icon, value, percent }] × 5 }` |
| Feedback Panel | `{ overallRating, ratingDenominator, responseCount, responseRatePct, categories: [{name, score}], nps: {score, promotersPct, passivesPct, detractorsPct}, topPositive: [string×3], topImprovement: [string×3], placeholder: true }` |
| ROI Table | `{ totalRevenue, totalCost, netRevenue, roiPct, costPerDollarRaised, revenuePerAttendee, donorAcquisitionCost, currencyCode, placeholder: true }` |
| YoY Comparison | `{ years: [{year: int, revenue, attendees, auctionRevenue, npsScore, isCurrent: bool}], trends: {revenueTrendPct, attendeesTrendPct, auctionTrendPct, npsTrendNote} }` |

**`metadata jsonb` shape** (every widget): `{ note?: string, eventIdMissing?: bool, generatedAt: timestamp }`.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (no new C# code expected; existing `generateWidgets` handler routes to the new Postgres functions)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/event/eventanalytics?eventId=N`
- [ ] All 13 Postgres functions exist in `app` schema and execute without error (test via direct SQL call)

**Functional Verification (Full E2E):**
- [ ] Without `?eventId` → "Select an event" empty state renders with event-selector
- [ ] With `?eventId=N` of a Completed event → all 14 surfaces render: EventOverviewBar + 6 KPIs + 7 grid widgets
- [ ] Each KPI tile shows correct value with shape-distinct visual treatment (NO clone grid)
- [ ] KPI 1 Total Revenue shows hero-size value + goal progress subtitle (green if ≥100%)
- [ ] KPI 4 Attendance shows "X / Y" fraction format + percent subtitle with color cue
- [ ] KPIs 5 + 6 show amber SERVICE_PLACEHOLDER chip in top-right
- [ ] Revenue Breakdown renders donut + table side-by-side; row colored-dots match donut slices
- [ ] Attendance Analysis table shows all ticket types + bold Total row + inline progress per row with correct color thresholds (green/amber/red)
- [ ] Check-in Timeline renders area chart with hour buckets; peak hour highlighted
- [ ] Donor Engagement renders 5 stat rows with icons + values + percentages
- [ ] Feedback Panel renders overall ★4.2/5 + category bars + NPS stacked + 2 lists; SERVICE_PLACEHOLDER chip visible
- [ ] ROI table renders 7 metric rows with Net Revenue + ROI rows accent-highlighted; SERVICE_PLACEHOLDER chip visible
- [ ] YoY table renders 4 metric × 4 year columns + trend arrows; trend color matches direction
- [ ] Event-selector dropdown lists only Completed events for current Company; clicking switches URL + refetches all widgets
- [ ] Header Export Report → SERVICE_PLACEHOLDER toast
- [ ] Header Print → `window.print()` triggers; chrome hidden via print stylesheet
- [ ] Header Share with Board → SERVICE_PLACEHOLDER toast
- [ ] Back button → navigates to `/crm/event/event`
- [ ] Drill-down clicks navigate to correct destination with correct prefill args (verify each per §⑥ Drill-Down Map)
- [ ] react-grid-layout reflows across breakpoints: 12-col lg → 8-col md → 6-col sm → 4-col xs (verify resize)
- [ ] Role-gating: BUSINESSADMIN sees all; non-BUSINESSADMIN denied → sidebar leaf hidden; widget-level grants enforce visibility
- [ ] Bookmark `/{lang}/crm/event/eventanalytics?eventId=123` survives reload

**DB Seed Verification:**
- [ ] Dashboard row `EVENTANALYTICS` inserted with ModuleId=CRM, IsSystem=true
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (parses cleanly) and 13-instance ConfiguredWidget JSON
- [ ] 12 WidgetType rows inserted with correct ComponentPath values matching FE `WIDGET_REGISTRY` keys
- [ ] 13 Widget rows inserted with `StoredProcedureName='app.fn_event_analytics_*'` and `DefaultParameters='{ "eventId": "{eventId}" }'`
- [ ] 13 WidgetRole rows granted to BUSINESSADMIN
- [ ] `Dashboard.MenuId` UPDATE step correctly links to existing `EVENTANALYTICS` Menu row
- [ ] Re-running seed is idempotent (no duplicate rows)

---

## ⑫ Special Notes & ISSUEs

> **Consumer**: All agents

**Dashboard-class warnings:**
- READ-ONLY dashboard — no CRUD path through this screen
- Tenant scoping: every Postgres function MUST filter on `CompanyId = p_company_id`
- Multi-currency: aggregate amounts in Event.CurrencyId (or Company.DefaultCurrencyId fallback); YoY across years may cross currency boundaries — mark with `⚠` indicator
- react-grid-layout LayoutConfig must include configs for every breakpoint actually used (lg/md/sm/xs) — missing breakpoints cause widget overlap
- ConfiguredWidget `instanceId` MUST equal corresponding LayoutConfig `i` value at every breakpoint (collisions cause widget reuse bugs)
- Path A SQL functions: NO new C# code; reuses `generateWidgets` GraphQL handler. NO migrations needed (functions auto-apply via DatabaseScripts loader)
- Drill-down args use destination screen's accepted query-param names exactly — do NOT invent new param names

**Non-standard MENU_DASHBOARD warnings:**
- Parent menu is **CRM_EVENT (not CRM_DASHBOARDS)** — sidebar auto-injection rule doesn't fire; uses normal menu mechanism (no special composer logic needed)
- Page is event-scoped via `?eventId` URL param — `<MenuDashboardComponent />` extension REQUIRED to accept `filterContext` prop (ISSUE-1)
- Per-route stub pattern (NOT dynamic `[slug]/page.tsx`) — matches #52/#57 precedent. Route at `crm/event/eventanalytics/page.tsx` overwrites existing 6-line UnderConstruction stub

**Pre-flagged ISSUEs:**

| # | Severity | Description |
|---|----------|-------------|
| ISSUE-1 | **HIGH** | `<MenuDashboardComponent />` must be extended with optional `filterContext?: Record<string, string\|number>` prop. At each widget's data-fetch step, merge `filterContext` into the resolved `DefaultParameters` JSON (replace `{eventId}` placeholder with actual value). Backward-compatible — existing #52/#57 callers don't pass this prop and continue to work. Without this extension, the page cannot pass `eventId` to widgets. Estimated 30-50 LOC change. Alternative: page wraps a custom orchestrator (more code) — recommend extension. |
| ISSUE-2 | LOW | Parent menu is `CRM_EVENT` (non-`*_DASHBOARDS`). Sidebar auto-injection isn't triggered — the `EVENTANALYTICS` menu row renders via standard mechanism. No code change needed; document for future reference if other event-scoped dashboards ship. |
| ISSUE-3 | **HIGH** | `GlobalDonation` has NO `EventId` FK column. **On-site donations linkage is SERVICE_PLACEHOLDER** — affects KPI 1 (Total Revenue undercounts on-site donations), Revenue Breakdown (On-site row returns 0), Donor Engagement (donated-at-event count degraded), KPI 5 (New Donors heuristic uses date proximity only). Future scope: separate migration adding `GlobalDonation.EventId int? FK → app.Events`. |
| ISSUE-4 | **HIGH** | No `EventFeedback / EventSurvey` entity exists in the codebase. **Feedback Panel widget is full SERVICE_PLACEHOLDER** — renders sample data (overall=4.2, NPS=+45, etc.) with an amber chip. Future scope: separate prompt to add EventFeedback entity + post-event survey-link flow. |
| ISSUE-5 | **HIGH** | No `EventCost / EventExpense` entity exists. **ROI Table is full SERVICE_PLACEHOLDER** — renders sample $24,700 cost figure + derived ROI math with amber chip. Future scope: separate prompt to add EventCost entity (line-items: venue / catering / staffing / marketing / etc.) and integrate into ROI calc. |
| ISSUE-6 | LOW | Short-term workaround for ISSUE-5: add scalar `Event.TotalCostAmount decimal?` column via migration (5-min change). Then ROI placeholder can read this column instead of hardcoded sample. Out of this prompt's scope but consider before #47 ships to production. |
| ISSUE-7 | MED | Widget-level role-gating behavior: when `WidgetRole(HasAccess=false)` → OMIT widget (cleaner board-meeting view). Decision recorded — Backend Developer encodes this in `generateWidgets` (or FE filters resolution). Alternative: render "Restricted" placeholder (rejected — visual noise for the board). |
| ISSUE-8 | LOW | YoY widget trend cell click → navigate to past year's analytics dashboard? Defer — destination would require URL param model with `eventId` of the prior year. For MVP, trend cells are static text. |
| ISSUE-9 | MED | Drill-down from KPI 1 (Total Revenue) → `crm/donation/globaldonation?eventId=N` won't filter correctly because GlobalDonation has no EventId column (ISSUE-3). For MVP, this drill-down is SERVICE_PLACEHOLDER (toast: "Filter by event coming soon"). Once ISSUE-3 ships, wire the real filter. |
| ISSUE-10 | MED | YoY identifying "same event across years" uses heuristic: same `EventCategoryId` + same `CompanyId` + LIKE-match on EventName stem. Risk: false matches (e.g., "Spring Gala" matches "Spring Brunch" if name stem matching is too loose). For MVP, use full EventName equality stripped of year suffix (`"Fundraising Gala 2026"` → `"Fundraising Gala"`). Future: add `Event.SeriesId int? FK self-ref` to formalize "this event is year-N of series X." |
| ISSUE-11 | MED | "Walk-in" attendance row in Attendance Table — does the `EventRegistration` entity support EventTicketId NULL for walk-ins? Or are walk-ins inserted with a special "walk-in" ticket type? **Backend Developer to verify** during build: check `EventTicketId` nullability + existence of any walk-in convention. If walk-ins aren't currently distinguishable, drop the Walk-in row in MVP and add ISSUE-11-cascade for future schema. |
| ISSUE-12 | LOW | Check-in Timeline hour bucketing: use event-window-derived buckets (e.g., 6PM-11PM per mockup) or fixed 24-hour day view? **Recommend**: derive from Event.StartDate + Event.EndDate (if available) ± 2hr padding. If EndDate is null, fall back to `[StartDate hour - 1, StartDate hour + 5]`. Function returns peak-bucket info in metadata for the FE chart annotation. |
| ISSUE-13 | LOW | "Engagement Score" in Donor Engagement (avg 72 vs org avg 54) — what is this metric's formula? **No existing engagement-score entity**. For MVP, return placeholder 72 + 54 with metadata.note='SERVICE_PLACEHOLDER — formula TBD'. Future: define engagement-score formula (e.g., (donations × 0.4 + event_attendances × 0.3 + email_opens × 0.2 + volunteer_hours × 0.1) normalized 0-100). |
| ISSUE-14 | LOW | Print stylesheet — needs `@media print` rules to hide chrome (page header buttons, event-selector dropdown) and break widgets across pages cleanly. FE Developer to add in renderer files or shared `event-analytics-print.css`. |
| ISSUE-15 | LOW | Export Report (PDF) — SERVICE_PLACEHOLDER. Server-side rendering service not wired. Out of this prompt's scope. Future: PDF generator service (Headless Chrome or similar) renders the dashboard URL as a print-styled PDF. |
| ISSUE-16 | LOW | Share with Board (email) — SERVICE_PLACEHOLDER. Composes email via existing Communication service with deep-link + attached PDF. Defer until Email Send Service (Communication module) supports board-distribution lists. |
| ISSUE-17 | LOW | DB seed file folder typo: `sql-scripts-dyanmic/` (NOT `sql-scripts-dynamic/`). Preserve typo for consistency with existing seed files (per Volunteer Dashboard #57 precedent ISSUE-8). |
| ISSUE-18 | MED | EF migration not generated by Path-A — Postgres functions are auto-applied via DatabaseScripts loader at startup. **Verify auto-apply works** (smoke test: drop function, restart app, confirm function recreated). If auto-apply DOES NOT fire for `Functions/app/*.sql`, generate a no-op migration to trigger DatabaseScripts loader (per Volunteer Dashboard #57 ISSUE-18 precedent). |
| ISSUE-19 | MED | `dotnet build` + `pnpm dev` smoke + full E2E checklist MUST run before production-ready. Do NOT skip per token-budget directive on session 1 (sets bad precedent). If time-constrained, mark as `PARTIALLY_COMPLETED` in registry and resume verification in a second session via `/continue-screen #47`. |
| ISSUE-20 | LOW | Cross-currency YoY years — flag with `⚠` indicator + tooltip. Currently silent if a 2024 event used a different currency than 2026. Future: ExchangeRate conversion at recorded rate. |
| ISSUE-21 | LOW | EventOverviewBar fetches `eventById(eventId)` separately from widget queries — 1 extra round-trip. Acceptable for MVP (event details are small + cacheable). Future: include event details in the page's initial dashboard query as a side-channel. |

**Service Dependencies (UI-only — SERVICE_PLACEHOLDERs):**

| # | Surface | Reason |
|---|---------|--------|
| 1 | KPI 5 New Donors | DEGRADED — heuristic only; needs `GlobalDonation.EventId` (ISSUE-3) |
| 2 | KPI 6 Cost Per Attendee | PLACEHOLDER — needs Event.TotalCostAmount column or EventCost entity (ISSUE-5/6) |
| 3 | Donor Engagement (donated-at-event, new donors, engagement score) | DEGRADED — same root cause as ISSUE-3, ISSUE-13 |
| 4 | Feedback Panel (entire widget) | PLACEHOLDER — needs EventFeedback entity (ISSUE-4) |
| 5 | ROI Table | PARTIALLY DEGRADED — TotalRevenue real, all cost-derived rows placeholder (ISSUE-5) |
| 6 | Header: Export Report | PDF rendering service not wired (ISSUE-15) |
| 7 | Header: Share with Board | Email service integration deferred (ISSUE-16) |
| 8 | KPI 1 drill-down (Total Revenue → GlobalDonation list filtered by event) | GlobalDonation.EventId missing (ISSUE-3/9) |
| 9 | YoY trend cell drill-down (click → prior year's analytics) | Deferred (ISSUE-8) |

**Canonical reference**: #57 Volunteer Dashboard (most recent MENU_DASHBOARD with Path-A across all widgets + new renderer set + per-route stub pattern). Diverges from #57 only in: (a) non-standard parent menu, (b) event-scoped filter via URL param, (c) ~30% of widgets are SERVICE_PLACEHOLDER due to missing source entities (Feedback / Cost / GlobalDonation.EventId).
