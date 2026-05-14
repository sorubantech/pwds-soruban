---
screen: GrantCalendar
registry_id: 64
module: CRM (Grants)
status: COMPLETED
scope: FULL
screen_type: DASHBOARD
dashboard_variant: CUSTOM_PAGE        # ← NOT MENU_DASHBOARD — see §⑫ ISSUE-1; calendar is a dedicated page under CRM_GRANT, not a widget-grid dashboard
complexity: High
new_module: NO                        # reuses `grant` schema bootstrapped by #62 Grant
planned_date: 2026-05-14
completed_date: 2026-05-14
last_session_date: 2026-05-14
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (3 view modes + Upcoming Deadlines table + side panel)
- [x] Variant chosen — CUSTOM_PAGE (not MENU_DASHBOARD; menu URL is `crm/grant/grantcalendar` under CRM_GRANT, not under CRM_DASHBOARDS)
- [x] Source entities identified — Grant / GrantReport / GrantMilestone / GrantStageHistory + 1 NEW `GrantCalendarEvent`
- [x] Event-source mapping designed (8 derived event types from 4 entities + 1 ad-hoc)
- [x] Three view layouts (Month / Quarter / Timeline) blueprinted from mockup
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (skipped redundant agent call — prompt §②/③/④ already exhaustive)
- [x] Solution Resolution complete (skipped redundant agent call — prompt §⑤ pre-resolved as CUSTOM_PAGE / Path B)
- [x] UX Design finalized (skipped redundant agent call — prompt §⑥ pre-blueprinted from mockup)
- [x] User Approval received (BE→FE sequential build path approved)
- [x] Backend NEW entity `GrantCalendarEvent` + EF config + migration (`20260514063733_Add_GrantCalendarEvent.cs` generated)
- [x] Backend CRUD for `GrantCalendarEvent` (Create/Update/Delete + Validators for "Add Deadline" button)
- [x] Backend unified query `getGrantCalendarEvents` returning event projection over 5 sources (8-arm Concat, tenant-scoped, UTC-normalized; arm 7 stage filter substituted to `('APPROVED','ACTIVE')` per ISSUE-15 — `DISBURSED` not seeded)
- [x] Backend query `getUpcomingGrantDeadlines` for the always-visible deadlines table (delegates to GetGrantCalendarEvents, computes daysLeft + urgencyTier)
- [x] Backend wiring (Schemas, Mappings, IGrantDbContext + GrantDbContext + DecoratorGrantModules + GrantQueries + GrantMutations extensions)
- [x] FE: dedicated page at `crm/grant/grantcalendar/page.tsx` with view-toggle (route stub OVERWRITTEN — delegates to `GrantCalendarPageConfig`)
- [x] FE: Month calendar component
- [x] FE: Quarter calendar component
- [x] FE: Timeline (Gantt) component
- [x] FE: Upcoming Deadlines table
- [x] FE: Date-click side panel (Sheet drawer)
- [x] FE: Add Deadline modal (RHF + Zod, Save gated by `formState.isValid`)
- [x] FE: Filter dropdowns (Grant / Event Type) wired to URL search params
- [x] FE: Zustand store for calendar UI state (view mode + cursor month/year + filters + side panel + modal toggles)
- [x] DB Seed script: Grid (DASHBOARD type) + 6 caps + BUSINESSADMIN role grants + GRANTCALENDAREVENTTYPE MasterData seeds (Meeting/Review/Custom). Capability code `MODIFY` used (not `UPDATE`) per project convention.
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/{lang}/crm/grant/grantcalendar`
- [ ] Month view renders current month with day cells + correctly placed event chips
- [ ] Quarter view renders 3 mini-month calendars with dot markers
- [ ] Timeline view renders Gantt-style grid (grant rows × 12 months) with bars + markers
- [ ] Switching view mode preserves filter state
- [ ] Calendar nav (Prev / Today / Next) works correctly in all 3 views
- [ ] Date-click opens side panel listing events for that date
- [ ] Side panel action buttons deep-link to grant-form / grant-detail / grant-reporting
- [ ] Event chip click also opens side panel (event.stopPropagation handling)
- [ ] Grant filter dropdown limits events to selected GRT-code
- [ ] Type filter limits events to selected type
- [ ] Upcoming Deadlines table shows 6+ rows ordered by date asc; "days left" computed correctly
- [ ] Urgent (<7 days) and Warning (7-30 days) row tints applied
- [ ] "Add Deadline" button opens form modal; Create persists a GrantCalendarEvent row
- [ ] New ad-hoc event appears on the calendar after Create
- [ ] Export Calendar (.ics) downloads file (SERVICE_PLACEHOLDER → toast if no infra)
- [ ] Sync to Outlook/Google → SERVICE_PLACEHOLDER toast
- [ ] Skeleton renders for each view + table during fetch
- [ ] Empty state renders when no events in selected window
- [ ] Mobile responsive (xs/sm) — day cells shrink, quarter view stacks 1-col, deadline table scrolls horizontally

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: GrantCalendar
Module: CRM (Grants)
Schema: `grant` (reused — bootstrapped by #62 Grant; #63 Grant Report extends; this screen adds ONE small entity)
Group: `GrantModels`
Module Code: CRM
Parent Menu Code: CRM_GRANT
Menu Code: GRANTCALENDAR
Menu URL: `crm/grant/grantcalendar`

Dashboard Variant: **CUSTOM_PAGE** — not a widget-grid MENU_DASHBOARD. This is a dedicated time-axis visualization page under `CRM_GRANT` (not `CRM_DASHBOARDS`). It does NOT use react-grid-layout / WIDGET_REGISTRY. See §⑫ ISSUE-1 for rationale.

Business: NGOs running multiple active grant cycles need a single time-axis view of every funder-imposed deadline — application submissions, decision dates, milestone targets, report due dates, disbursement events, grant start/end markers, plus ad-hoc review meetings entered by the staff manager. The Grant Calendar gives the Grants Manager, Program Director and CFO a "what is hitting this week / month / quarter" view across the whole grant portfolio. Three view modes serve different audiences: **Month** for tactical week-by-week tracking, **Quarter** for the Programme Director's planning horizon, **Timeline** (Gantt-style) for the CFO's portfolio overview of which grants are active in which months. The "Upcoming Deadlines" table sits below all views as the always-visible attention list (urgent / warning / normal tiers). It surfaces events derived from existing grant data (read-only) plus admin-entered ad-hoc deadlines (the only writable surface on this screen, via "Add Deadline"). Drill-downs deep-link back to the Grant detail / Grant form / Grant Report screens. Export-to-ICS and OAuth Outlook/Google sync are explicit SERVICE_PLACEHOLDERs.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **TWO surfaces**:
> - **Read-only event projection** over 4 existing entities (Grant, GrantReport, GrantMilestone, GrantStageHistory) — NO new persistence; computed at query time.
> - **One small NEW entity** `GrantCalendarEvent` for the "Add Deadline" button (ad-hoc deadlines / review meetings entered manually by the grants manager).

### A. NEW Entity — `grant.GrantCalendarEvents`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| GrantCalendarEventId | int PK identity | ✓ | — |
| GrantId | int FK → grant.Grants | ✓ | Cascade-delete on Grant delete |
| EventDate | DateTime (date portion only — store at UTC midnight) | ✓ | The deadline / meeting day |
| EventTypeId | int FK → com.MasterData (TypeCode=`GRANTCALENDAREVENTTYPE`) | ✓ | MEETING / REVIEW / CUSTOM (seeded — see §⑫ ISSUE-3) |
| Title | varchar(200) | ✓ | e.g., "DFID Review Meeting", "Site Visit" |
| Description | varchar(1000) | ✗ | Optional context |
| Location | varchar(200) | ✗ | Optional location for meetings |
| Color | varchar(20) | ✗ | Optional override; default mapped from EventType.DataSetting (see §⑫ ISSUE-4) |
| IsAllDay | bool | ✓ | Default true (date-only event) |
| Time | time | ✗ | Optional clock time when IsAllDay=false (e.g., "14:00:00") |
| ReminderDaysBefore | int? | ✗ | Optional — future feature; surface in detail but no reminder engine in MVP (§⑫ ISSUE-5) |
| CompanyId | int? | ✓ | Standard tenant scoping; nullable to mirror existing project convention |
| (Audit fields inherited from Entity) | | | CreatedBy/Date, ModifiedBy/Date, IsActive, IsDeleted |

**Indexes:**
- `(CompanyId, GrantId, EventDate)` — covers calendar window queries scoped by tenant + grant
- `(CompanyId, EventDate)` — covers full-portfolio month queries

### B. Read-only event projection (NO new persistence)

The calendar UI consumes a flat `GrantCalendarEventDto` projection unified from 5 sources. The BE handler builds this by `UNION ALL`-ing 5 SELECTs:

| # | Source | When | Event Type | Color (legend) | Title format |
|---|--------|------|------------|-----------------|---------------|
| 1 | Grant.SubmissionDeadline | NOT NULL AND no SubmittedDate | `APPLICATION_DEADLINE` | red | `"{FunderName} Application Deadline"` |
| 2 | Grant.DecisionDate | NOT NULL AND Grant.StageId NOT IN (Approved, Rejected) | `DECISION_EXPECTED` | orange | `"{FunderName} Decision Expected"` |
| 3 | Grant.StartDate | NOT NULL | `GRANT_START` | blue | `"{GrantCode} Start"` |
| 4 | Grant.EndDate | NOT NULL | `GRANT_END` | blue | `"{GrantCode} End"` |
| 5 | GrantReport.DueDate | StatusCode IN ('Draft','Submitted','Revision Requested') | `REPORT_DUE` | red | `"{Period} Progress Report — {FunderName}"` |
| 6 | GrantMilestone.TargetDate | StatusCode NOT IN ('Completed','Cancelled') | `MILESTONE` | orange | `"{MilestoneTitle} — {GrantCode}"` |
| 7 | GrantStageHistory.TransitionDate | ToStage.Code IN ('DISBURSED','APPROVED') | `DISBURSEMENT_OR_APPROVAL` | green | `"{StageName} — {GrantCode}"` |
| 8 | GrantCalendarEvent (new entity above) | always | `MEETING` / `REVIEW` / `CUSTOM` | yellow / yellow / blue | `Title` |

Composite DTO field per row:
```ts
GrantCalendarEventDto {
  eventDate: string (ISO date)
  eventType: string (one of 8 codes above)
  color: string (red/yellow/orange/green/blue)
  title: string
  grantId: number
  grantCode: string
  funderName: string
  sourceTable: string ('Grant' | 'GrantReport' | 'GrantMilestone' | 'GrantStageHistory' | 'GrantCalendarEvent')
  sourceRecordId: number   // for drill-down
  drillDownTarget: string   // 'grant-detail' | 'grant-form' | 'grant-reporting' — based on sourceTable + eventType
  description?: string
  location?: string
  status?: string
  iconHint?: string         // FE renders Phosphor icon based on eventType
}
```

**Composite vs. Per-Widget queries** — picked: **Composite single fetch**.
- ONE handler `GetGrantCalendarEvents(fromDate, toDate, grantId?, eventType?)` returns ALL events in window as a flat array. Filter is server-side. Re-fetches when filter / date-cursor changes. Client-side groups by date for Month/Quarter/Timeline rendering.
- ONE separate handler `GetUpcomingGrantDeadlines(asOfDate, maxRows = 20)` for the always-visible Upcoming Deadlines table — same projection but ordered by date asc, capped, scoped to events with date >= today.

### C. Source Entities (read-only — what the projection aggregates over)

| Source Entity | File Path | Used For | Filter Applied |
|---------------|-----------|----------|----------------|
| Grant | Base.Domain/Models/GrantModels/Grant.cs | events 1-4 (SubmissionDeadline / DecisionDate / StartDate / EndDate) | IsActive=true AND IsDeleted=false AND CompanyId=tenant |
| GrantReport | Base.Domain/Models/GrantModels/GrantReport.cs | event 5 (DueDate) | IsActive=true AND IsDeleted=false AND StatusCode IN (Draft, Submitted, Revision Requested) |
| GrantMilestone | Base.Domain/Models/GrantModels/GrantMilestone.cs | event 6 (TargetDate) | IsActive=true AND IsDeleted=false AND StatusCode NOT IN (Completed, Cancelled) |
| GrantStageHistory | Base.Domain/Models/GrantModels/GrantStageHistory.cs | event 7 (TransitionDate) | IsActive=true AND ToStage.Code IN (DISBURSED, APPROVED) |
| GrantCalendarEvent (NEW) | Base.Domain/Models/GrantModels/GrantCalendarEvent.cs | event 8 (EventDate) | IsActive=true AND IsDeleted=false |

---

## ③ Source Entity & Aggregate Query Resolution

> **Consumer**: Backend Developer + Frontend Developer

| Source Entity | Entity File Path | Aggregate Query Handler | GQL Field | Returns | Args |
|---------------|-------------------|-------------------------|-----------|---------|------|
| Grant + GrantReport + GrantMilestone + GrantStageHistory + GrantCalendarEvent (UNION) | Base.Domain/Models/GrantModels/*.cs | `GetGrantCalendarEvents` | `grantCalendarEvents` | `[GrantCalendarEventDto]` | fromDate, toDate, grantId?, eventTypeCode? |
| Same UNION | Same | `GetUpcomingGrantDeadlines` | `upcomingGrantDeadlines` | `[GrantCalendarEventDto]` (+ `daysLeft` int) | asOfDate, maxRows = 20, grantId?, eventTypeCode? |
| GrantCalendarEvent | Base.Domain/Models/GrantModels/GrantCalendarEvent.cs | `GetGrantCalendarEventById` | `grantCalendarEventById` | `GrantCalendarEventResponseDto` | id |
| GrantCalendarEvent | — | `CreateGrantCalendarEvent` (mutation) | `createGrantCalendarEvent` | `int` (new id) | request |
| GrantCalendarEvent | — | `UpdateGrantCalendarEvent` (mutation) | `updateGrantCalendarEvent` | `bool` | id, request |
| GrantCalendarEvent | — | `DeleteGrantCalendarEvent` (mutation) | `deleteGrantCalendarEvent` | `bool` | id |

**FK Resolution** (for `GrantCalendarEvent` only — the new entity):

| FK | Target Entity | Target File Path | Display Field | Existing GQL Query | Response DTO |
|----|---------------|-------------------|----------------|---------------------|---------------|
| GrantId | Grant | Base.Domain/Models/GrantModels/Grant.cs | `GrantTitle` (with `GrantCode` prefix) | `getAllGrantList` | GrantResponseDto |
| EventTypeId | MasterData (TypeCode=GRANTCALENDAREVENTTYPE) | Base.Domain/Models/CorgModels/MasterData.cs | `DataValue` | `getMasterDataByType` | MasterDataResponseDto |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer → Frontend Developer

**Date Range Defaults:**
- Default range: **current month** (1st of cursor month to last day, in tenant's display TZ — see §⑫ ISSUE-7 on UTC handling)
- View mode controls the window:
  - Month view → 1 month
  - Quarter view → 3 months (current + 2 ahead, or current + 1 ahead + 1 prior per UX choice — see §⑫ ISSUE-8)
  - Timeline view → 12 months (Jan–Dec of cursor year)
- Custom range max span: 24 months — to bound query cost

**Role-Scoped Data Access:**
- **BUSINESSADMIN** sees all grants across all branches.
- **GRANT_MANAGER** / **PROGRAM_DIRECTOR**: see only grants in their assigned branch (`Grant.BranchId = user.BranchId`) — backend filters in handler. (See §⑫ ISSUE-9 — confirm role catalog and branch scope before build.)
- Anonymous / public access: blocked at menu level via `MenuCapability.READ` requirement.

**Calculation Rules:**
- **daysLeft** (for Upcoming Deadlines table) = `(EventDate - AsOfDate).Days`. Clamped at 0 (events on today show "Today").
- **Urgency tier** (FE row tinting):
  - `daysLeft < 7` → `urgent` row class (red tint)
  - `7 ≤ daysLeft < 30` → `warning` row class (yellow tint)
  - `daysLeft ≥ 30` → no tint
- **Event Color** — derived in BE projection based on EventType (see §② Table B). FE does NOT compute color from name.
- **Title format** — derived in BE projection. FE renders verbatim. (Single source of truth for display strings.)
- **Past events** (EventDate < today) — included in Month/Quarter/Timeline views (visible context), excluded from Upcoming Deadlines table.
- **Completed events** (e.g., `Grant.SubmittedDate IS NOT NULL` for an Application Deadline event) — excluded from projection entirely (see filters in §②.B).

**Multi-Currency Rules:**
- Calendar is amount-agnostic. No FX needed.

**Validation Rules (GrantCalendarEvent CRUD):**
- `Title`: required, max 200, trim.
- `EventDate`: required, MUST be valid date. Cannot be more than 5 years in past or 10 years in future. (Soft guards — see §⑫ ISSUE-10.)
- `GrantId`: required, must reference active non-deleted Grant in same tenant.
- `EventTypeId`: required, must reference MasterData of TypeCode=GRANTCALENDAREVENTTYPE.
- `Time`: required when `IsAllDay=false`; ignored when `IsAllDay=true`.
- `Location`: optional, max 200.
- `Description`: optional, max 1000.

**Workflow**: None. GrantCalendarEvent is simple CRUD. The 7 derived event types are read-only projections; they are NOT writable on this screen — editing them means going back to the Grant / GrantReport / Milestone screens.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver

**Screen Type**: DASHBOARD (sub-classification: **CUSTOM_PAGE** — dedicated calendar UI, NOT widget-grid)
**Reason**: The mockup shows a time-axis visualization with 3 view modes (Month / Quarter / Timeline) + an always-visible deadlines table + side panel + minor CRUD ("Add Deadline"). It does NOT use react-grid-layout / WIDGET_REGISTRY. The menu URL is `crm/grant/grantcalendar` under `CRM_GRANT` — NOT under `CRM_DASHBOARDS` — so the MENU_DASHBOARD dynamic-route pattern does not apply.

**Backend Implementation Path** — picked: **Path B — Named GraphQL queries (typed handlers)**
- Two new typed CQRS handlers (Path B), NOT Postgres functions (Path A):
  - `GetGrantCalendarEvents` returns `[GrantCalendarEventDto]` (window query)
  - `GetUpcomingGrantDeadlines` returns `[GrantCalendarEventDto]` (table query — with `daysLeft` computed)
- The composite projection is a 5-arm `UNION ALL` built in LINQ-to-SQL using `IGrantDbContext`. Each arm SELECTs the source rows + maps to `GrantCalendarEventDto` with type/color/title baked.
- PLUS standard CRUD handlers for `GrantCalendarEvent` (Create/Update/Delete + GetById).

**Why Path B, not Path A:**
- The UNION over 4+1 tables with mixed filters is awkward in a 5-arg Postgres function contract; cleaner as LINQ.
- The screen is custom UI (NOT widget-grid via `generateWidgets`), so the Path-A integration point isn't available anyway.
- Tenant scoping + role scoping + soft-delete filters are already handled by the entity-level IsActive/IsDeleted/CompanyId predicates in EF-Core land.

**Backend Patterns Required:**
- [x] CRUD handlers for GrantCalendarEvent (Create/Update/Delete/GetById)
- [x] Composite UNION query handler (GetGrantCalendarEvents)
- [x] Helper query for table (GetUpcomingGrantDeadlines — wraps GetGrantCalendarEvents with date-asc ordering + daysLeft computation + maxRows cap)
- [x] Tenant scoping (CompanyId from HttpContext) — every query
- [x] Date-range parameterized queries (fromDate, toDate inclusive bounds)
- [x] Role-scoped data filtering — branch scope per §④ (if user.BranchId is set and role is not BUSINESSADMIN, restrict to Grant.BranchId = user.BranchId)
- [x] EF migration for new entity GrantCalendarEvent
- [ ] No materialized view (queries cheap — under 1000 grants per tenant per year expected)

**Frontend Patterns Required:**
- [x] Custom dedicated page (NOT widget-grid via react-grid-layout)
- [x] View-toggle component (Month / Quarter / Timeline) — Zustand-driven, persisted in URL (`?view=month|quarter|timeline`)
- [x] Calendar nav (Prev / Today / Next) — Zustand-driven, persisted in URL (`?cursor=YYYY-MM`)
- [x] Grant filter + Event Type filter dropdowns — URL synced (`?grantId=X&eventType=Y`)
- [x] Month view component — 7×{5|6} grid with event chips + week-start config (Mon-first per mockup)
- [x] Quarter view component — 3 mini-month calendars with dot markers
- [x] Timeline view component — Gantt grid: 1 header col (grant name) + 12 month cols × N grant rows; bars span month-cells; markers (R/M/!/D) pinpoint events
- [x] Side panel (Sheet, 400px right) on date click — lists events for that day with action buttons
- [x] Upcoming Deadlines table — always visible below calendar; 6-col (Date/Grant/Event/Type/Status/Actions); urgent/warning row tints
- [x] Add Deadline modal — RHF + Zod; fields: GrantId (ApiSelect), EventTypeId (MasterData select), Title, EventDate, IsAllDay/Time, Location, Description, ReminderDaysBefore
- [x] Custom calendar renderers — NOT registered in WIDGET_REGISTRY; live as ordinary page-scoped components under `dashboards/widgets/grantcalendar-widgets/` (mirror Ambassador Dashboard #69 folder convention for consistency, but renderers are imported directly by the page — NOT looked up via registry)
- [x] Skeleton states matching each view's layout (Month grid skeleton, Quarter mini-cal skeleton, Timeline grid skeleton, Table-rows skeleton)
- [x] Empty / error states per view
- [x] Phosphor icons (no fa-*) per UI uniformity directive

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer

### Layout Variant: **widgets-above-grid** (no DataTableContainer)
Stamp: `grid-only=false`. The page is its own composition — no FlowDataTable involved. Single `ScreenHeader` at the top renders title + action buttons; everything below is custom UI.

### Page Chrome

**Top row** (matches mockup `.page-header`):
- Icon `ph:calendar` + "Grant Calendar"
- Subtitle: "Track deadlines, reports, and milestones across all grants"
- Right-side actions:
  - `[+ Add Deadline]` — outline button (Phosphor `ph:plus`) — opens Add Deadline modal
  - `[Export Calendar]` — outline button (`ph:download-simple`) — SERVICE_PLACEHOLDER (toast "ICS export coming soon" OR if simple ICS generation feasible, generate-and-download — see §⑫ ISSUE-12)
  - `[Sync to Outlook/Google]` — outline button (`ph:arrows-clockwise`) — SERVICE_PLACEHOLDER (OAuth provider integration deferred)

**Toolbar row** (matches mockup `.toolbar`):
- Left:
  - View toggle (segmented button group): `[Month]` `[Quarter]` `[Timeline]` — active state uses primary accent
  - Grant filter (Select): "All Grants" + per-Grant options (label format: `{GrantCode} ({FunderName})`). Loaded from `getAllGrantList`.
  - Type filter (Select): "All Types" / "Reports" / "Meetings" / "Deadlines" / "Milestones" / "Decisions"
- Right: empty (the calendar nav lives inside each view's card header)

### View Container 1 — MONTH VIEW (default)

**Card chrome:**
- Header bar with: cal-nav left (Prev / Title / Next) + Today button on the right
- Title format: `{MonthName} {Year}` (e.g., "April 2026")

**Calendar grid:**
- 7 columns × 5-6 rows
- Header row: Mon / Tue / Wed / Thu / Fri / Sat / Sun (Mon-first per mockup)
- Day cells:
  - `min-height: 95px`
  - Day number top-left
  - Event chips stacked below (max 3 visible; "+N more" hint when overflow)
  - States: `.today` (primary tint + bold border), `.other-month` (greyed), `.weekend` (faint bg)
  - Click → open side panel for that date

**Event chip:**
- Inline span with truncate; color = event.color (red / yellow / orange / green / blue) — solid bg/text per memory feedback ([widget icon containers + badges = solid bg + white]); left border accent
- Click → also opens side panel (event.stopPropagation)

**Legend (footer of card):**
- 5 dots: red=Report/Deadline | yellow=Meeting/Review | orange=Decision/Milestone | green=Disbursement/Approval | blue=Grant Start/End

### View Container 2 — QUARTER VIEW

**Card chrome:**
- Header bar with cal-nav (Prev quarter / Title / Next quarter)
- Title format: `Q{N} {Year} ({Mo}-{Mo})` (e.g., "Q2 2026 (Apr - Jun)")

**3-column grid of mini-month calendars:**
- Each mini-cal: month header + 7-col day grid + tiny dots indicating events
- Day cell size ~32×32px; day number centered; dot below
- Today highlighted; other-month days greyed
- Click on day → open side panel

**Legend (same 5 dots as Month).**

### View Container 3 — TIMELINE VIEW

**Card chrome:**
- Header bar with year nav + title `Grant Timeline - {Year}`

**Gantt-style grid:**
- 13-col CSS grid: `180px repeat(12, 1fr)` (1st col = grant name, 12 month cols Jan-Dec)
- Header row: grant-label col + 12 month labels (current month highlighted with primary tint)
- One row per Grant active in window
- **Bar segments** in month cells:
  - `bar.active` (primary accent, 0.8 opacity) — grant is active in that month (StartDate ≤ month-end AND EndDate ≥ month-start)
  - `bar.on-track` (green, 0.7 opacity) — past months of active grant (informational)
  - `bar.upcoming` (warning yellow, 0.7 opacity) — current month with upcoming deadline marker
- **Markers** overlaid on bars (circle with letter):
  - `R` (blue) = Report (R-marker title `"Q{N} Report"` or `"Final Report"`)
  - `M` (orange) = Milestone
  - `!` (red) = Deadline (e.g., Application Deadline)
  - `D` (purple) = Decision Expected
  - `?` (yellow) = Review

Click marker → opens side panel with that event's detail.

**Legend (footer of card):** 7 items — Active bar, On Track bar, Upcoming bar, R, M, !, D.

### Always-Visible — Upcoming Deadlines Table

> Sits BELOW the active view container, always rendered (not gated by view mode).

**Card chrome:**
- Header bar: `ph:clock` icon + "Upcoming Deadlines" + right-side count text `"N upcoming events"`

**Table (6 columns):**
| Col | Field | Render | Notes |
|-----|-------|--------|-------|
| 1 | Date | `<strong>{MMM dd, yyyy}</strong>` | Sortable by date asc default |
| 2 | Grant | `{GrantCode}` as link (`grant-link` style) + `({FunderName})` | Click → grant-detail |
| 3 | Event | event.title (plain text) | — |
| 4 | Type | Pill badge — `type-badge.{application|meeting|decision|report|milestone}` | Color-coded |
| 5 | Status | `{N} days left` or `Today` or `Past`. Urgent icon `ph:warning-circle` for <7d, `ph:clock` for 7-30d. Color: danger/warning/normal | Computed `daysLeft` from BE |
| 6 | Actions | Right-aligned button per event-type: <br>• APPLICATION_DEADLINE → `[View Application]` (→ grant-form) <br>• REPORT_DUE → `[Create Report]` or `[Continue Report]` (→ grant-reporting) <br>• MEETING/REVIEW → `[Prepare]` (→ grant-detail) <br>• DECISION_EXPECTED / MILESTONE / DISBURSEMENT_OR_APPROVAL / GRANT_START / GRANT_END → `[View]` (→ grant-detail) | All deep-links carry `?id=...` |

**Row tinting:**
- `daysLeft < 7` → urgent (light-red bg)
- `7 ≤ daysLeft < 30` → warning (light-yellow bg)
- else → no tint

**Empty state:** muted icon `ph:calendar-blank` + "No upcoming deadlines in the next 30 days."

### Date-Click Side Panel (Sheet, 400px right)

**Header:**
- Title: full date `"April 15, 2026"`
- Close button (`ph:x`)

**Body:**
- For each event on the clicked date, render a `panel-event` card:
  - Icon container (36×36 solid color matching event.color, white icon — per UI uniformity rule)
  - Event title (bold)
  - Grant code + funder name (sub-line, `ph:folder-open` prefix)
  - Action button — same as table Actions column

**Footer:**
- Single `[Close]` button (Sheet handles ESC + overlay-click close natively).

**Empty state:**
- Muted icon `ph:calendar-blank` + "No events scheduled for this date."

### Add Deadline Modal

**Trigger:** `[+ Add Deadline]` in page header.

**Form layout** (2-col on desktop, 1-col on mobile):
- Row 1: Grant (ApiSelect, required) — searchable; default to first option
- Row 2: Event Type (Select from GRANTCALENDAREVENTTYPE MasterData, required) — Meeting / Review / Custom
- Row 3: Title (text, required, max 200)
- Row 4: Event Date (DatePicker, required) | Is All Day (Switch, default ON)
- Row 5: Time (TimePicker, conditional — visible when IsAllDay=false)
- Row 6: Location (text, optional, max 200)
- Row 7: Description (textarea, optional, max 1000, 3 rows)
- Row 8: Reminder Days Before (number, optional, 0-30) — informational only in MVP

**Actions:**
- `[Cancel]` (secondary) — close modal
- `[Save Deadline]` (primary, gated by RHF `formState.isValid` per memory feedback [form-create-button-enablement]) — POST `createGrantCalendarEvent`, on success: toast + close modal + refetch calendar window query

**Edit / Delete:** Available only on `GrantCalendarEvent` rows (ad-hoc events). Triggered from side-panel actions when the event came from `GrantCalendarEvent` source (sourceTable check). Edit reopens the same modal pre-filled; Delete shows confirm dialog.

### Filter / URL Sync

URL search params hold the calendar UI state (deep-linkable):
- `view` = `month` | `quarter` | `timeline` (default `month`)
- `cursor` = `YYYY-MM` for Month/Quarter, `YYYY` for Timeline (default current)
- `grantId` = number or absent (default all)
- `eventType` = `APPLICATION_DEADLINE` | `REPORT_DUE` | `MEETING` | `REVIEW` | `DECISION_EXPECTED` | `MILESTONE` | `DISBURSEMENT_OR_APPROVAL` | `GRANT_START` | `GRANT_END` | `CUSTOM` or absent (default all)

Zustand store mirrors these; navigation updates URL via `useRouter`.

### Drill-Down / Navigation Map

| From | Click On | Navigates To | Prefill |
|------|----------|--------------|---------|
| Day cell | anywhere | Side panel (in-screen, no nav) | date |
| Event chip (Month view) | chip | Side panel | date |
| Marker (Timeline view) | marker | Side panel | date + filter by marker's event |
| Quarter day cell | anywhere | Side panel | date |
| Side panel event card — APPLICATION_DEADLINE | `[View Application]` | `/crm/grant/grantform?mode=read&id={grantId}` | grantId |
| Side panel event card — REPORT_DUE | `[Create Report]` / `[Continue Report]` | `/crm/grant/grantreporting?mode=edit&id={reportId}` (or `?mode=new&grantId={grantId}` if not yet drafted) | reportId or grantId |
| Side panel event card — MEETING/REVIEW/MILESTONE/DECISION/DISBURSEMENT/GRANT_START/GRANT_END | `[Prepare]` or `[View]` | `/crm/grant/grantlist?mode=read&id={grantId}` | grantId |
| Side panel event card — CUSTOM (ad-hoc) | `[Edit]` (only when sourceTable=GrantCalendarEvent) | reopens Add Deadline modal in edit mode | event record |
| Side panel event card — CUSTOM (ad-hoc) | `[Delete]` (only when sourceTable=GrantCalendarEvent) | confirm dialog → DELETE mutation | event id |
| Upcoming Deadlines table — Grant link | `{GrantCode}` | `/crm/grant/grantlist?mode=read&id={grantId}` | grantId |
| Upcoming Deadlines table — Actions | per event-type (same map as side panel) | same as side panel | same |
| Timeline row — Grant name link | name | `/crm/grant/grantlist?mode=read&id={grantId}` | grantId |

### User Interaction Flow

1. **Initial load**: User clicks sidebar "Grant Calendar" → page mounts → reads URL params (defaults applied) → fires 2 queries in parallel:
   - `grantCalendarEvents(fromDate, toDate, grantId?, eventType?)` for the active view's window
   - `upcomingGrantDeadlines(asOfDate=today, maxRows=20, grantId?, eventType?)` for the table
   - Also: `getAllGrantList` (for Grant filter dropdown options) — cached after first call
2. **View toggle**: switches active view container; recomputes window (Month/Quarter/Timeline) → refetches `grantCalendarEvents` with new range; table query is unaffected.
3. **Calendar nav (Prev/Today/Next)**: updates cursor; recomputes window; refetches events query.
4. **Filter change (Grant or Type)**: refetches BOTH queries with new filter args.
5. **Date click**: opens side panel; no new fetch (uses already-loaded events filtered by date in memory).
6. **Add Deadline**: opens modal → submit → POST mutation → refetch events query + table query.
7. **Edit/Delete ad-hoc**: same as Add Deadline.
8. **Drill-down click**: `router.push` to destination screen.
9. **ESC**: closes side panel.
10. **Empty / loading / error**: each view container renders its own skeleton during fetch; error state is page-level red mini banner with Retry; per-widget empty states inline.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> No prior CUSTOM_PAGE calendar precedent. Reference patterns from #14 PaymentReconciliation (custom page with no entity) and #69 AmbassadorDashboard (custom widget folder structure) — but no direct substitution.

| Canonical Reference | → This Screen | Context |
|---------------------|----------------|---------|
| PaymentReconciliation (#14) | GrantCalendar | Custom dedicated page, no entity-driven grid |
| RECONCILIATION | GRANTCALENDAR | GridCode / MenuCode |
| crm/donation/reconciliation | crm/grant/grantcalendar | Page route |
| `dashboards/widgets/ambassador-dashboard-widgets/` (#69) | `dashboards/widgets/grantcalendar-widgets/` | Folder convention for page-scoped custom components |
| `fund` | `grant` | Source schema (existing — bootstrapped by #62) |
| DonationModels | GrantModels | Backend group |
| CRM | CRM | Module code |
| CRM_DONATION | CRM_GRANT | Parent menu code |
| RECONCILIATION (GridType=FLOW) | GRANTCALENDAR (GridType=DASHBOARD) | Grid type stamp |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend — New Entity & EF

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | GrantCalendarEvent.cs | PSS_2.0_Backend/.../Base.Domain/Models/GrantModels/GrantCalendarEvent.cs | NEW entity |
| 2 | GrantCalendarEventConfiguration.cs | PSS_2.0_Backend/.../Base.Application/Configurations/GrantConfigurations/GrantCalendarEventConfiguration.cs | EF config (table name, FK, indexes) |
| 3 | EF migration | PSS_2.0_Backend/.../Base.Infrastructure/Migrations/{ts}_Add_GrantCalendarEvent.cs | Auto-generated by `dotnet ef migrations add` |

### Backend — Schemas

| # | File | Path |
|---|------|------|
| 4 | GrantCalendarSchemas.cs | PSS_2.0_Backend/.../Base.Application/Schemas/GrantSchemas/GrantCalendarSchemas.cs |

Contents: `GrantCalendarEventDto` (projection), `GrantCalendarEventResponseDto` (single CRUD response), `GrantCalendarEventRequestDto` (Create/Update), `UpcomingGrantDeadlineDto` (extends event DTO with `daysLeft`).

### Backend — Query Handlers (Path B)

| # | File | Path |
|---|------|------|
| 5 | GetGrantCalendarEvents.cs | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantCalendar/Queries/GetGrantCalendarEvents.cs |
| 6 | GetUpcomingGrantDeadlines.cs | …/GrantCalendar/Queries/GetUpcomingGrantDeadlines.cs |
| 7 | GetGrantCalendarEventById.cs | …/GrantCalendar/Queries/GetGrantCalendarEventById.cs |

### Backend — Command Handlers (CRUD on new entity)

| # | File | Path |
|---|------|------|
| 8 | CreateGrantCalendarEvent.cs | …/GrantCalendar/Commands/CreateGrantCalendarEvent.cs |
| 9 | UpdateGrantCalendarEvent.cs | …/GrantCalendar/Commands/UpdateGrantCalendarEvent.cs |
| 10 | DeleteGrantCalendarEvent.cs | …/GrantCalendar/Commands/DeleteGrantCalendarEvent.cs |
| 11 | GrantCalendarEventValidators.cs | …/GrantCalendar/Commands/GrantCalendarEventValidators.cs |

### Backend — Endpoints

| # | File | Change |
|---|------|--------|
| 12 | GrantQueries.cs | Add 3 GQL fields: `grantCalendarEvents`, `upcomingGrantDeadlines`, `grantCalendarEventById` |
| 13 | GrantMutations.cs | Add 3 GQL fields: `createGrantCalendarEvent`, `updateGrantCalendarEvent`, `deleteGrantCalendarEvent` |

### Backend — Wiring

| # | File | Change |
|---|------|--------|
| 14 | IGrantDbContext.cs | Add `DbSet<GrantCalendarEvent>` |
| 15 | GrantDbContext.cs | Add `DbSet<GrantCalendarEvent>` |
| 16 | GrantMappings.cs | Add Mapster `TypeAdapterConfig` for `GrantCalendarEvent` → `GrantCalendarEventResponseDto` |
| 17 | DecoratorGrantModules.cs (DecoratorProperties.cs entry) | Register `GrantCalendarEvent` module entry (if needed per #62 precedent) |
| 18 | GlobalUsing.cs (Domain + Application + Infrastructure × 3 if needed) | Add Models.GrantModels namespace if not already present |

### Backend — DB Seed

| # | File | Path |
|---|------|------|
| 19 | GrantCalendar-sqlscripts.sql | `sql-scripts-dyanmic/GrantCalendar-sqlscripts.sql` (preserve repo's `dyanmic` typo per precedent #6/#7/#8) |

Seed contents:
- Idempotent menu insert: `GRANTCALENDAR` under `CRM_GRANT` parent at `OrderBy=3` (verify existing row first — see MODULE_MENU_REFERENCE.md; this menu already exists). If exists, UPDATE only the missing fields.
- 6 MenuCapabilities: READ, CREATE, UPDATE, DELETE, EXPORT, ISMENURENDER (Create/Update/Delete are for the GrantCalendarEvent ad-hoc CRUD)
- 6 RoleCapability grants for BUSINESSADMIN (per memory feedback [build_directives]: BUSINESSADMIN only)
- Grid row: `GridCode=GRANTCALENDAR`, `GridType=DASHBOARD`, `GridFormSchema=NULL` (custom UI; no RJSF)
- MasterDataType `GRANTCALENDAREVENTTYPE` with 3 values (only if not present):
  - `MEETING` — Yellow color (#a16207 / bg #fef9c3) — icon `ph:users-three`
  - `REVIEW` — Yellow color (#a16207 / bg #fef9c3) — icon `ph:eye`
  - `CUSTOM` — Blue color (#1d4ed8 / bg #dbeafe) — icon `ph:calendar-dot`
  - Stored in `DataSetting` as JSON `{"colorHex":"#a16207","bgHex":"#fef9c3","icon":"ph:users-three"}`
- NO sample data rows (let user enter via Add Deadline button).

### Frontend — DTOs

| # | File | Path |
|---|------|------|
| 20 | GrantCalendarEventDto.ts | PSS_2.0_Frontend/src/domain/entities/grants-service/GrantCalendarEventDto.ts |
| 21 | UpcomingGrantDeadlineDto.ts | …/grants-service/UpcomingGrantDeadlineDto.ts |
| 22 | grants-service barrel | …/grants-service/index.ts — re-export new DTOs |

### Frontend — GraphQL

| # | File | Path |
|---|------|------|
| 23 | GrantCalendarQuery.ts | PSS_2.0_Frontend/src/infrastructure/gql-queries/grants-queries/GrantCalendarQuery.ts |
| 24 | GrantCalendarMutation.ts | PSS_2.0_Frontend/src/infrastructure/gql-mutations/grants-mutations/GrantCalendarMutation.ts |
| 25 | grants-queries barrel | re-export GrantCalendarQuery |
| 26 | grants-mutations barrel | re-export GrantCalendarMutation |

### Frontend — Page Components

> Folder: `PSS_2.0_Frontend/src/presentation/components/page-components/crm/grant/grantcalendar/`

| # | File | Purpose |
|---|------|---------|
| 27 | index.tsx | Page entry — composes header + toolbar + view container + table; default export |
| 28 | grantcalendar-page-config.ts | Page metadata (gridCode `GRANTCALENDAR`, capabilities, page title, breadcrumb) |
| 29 | grantcalendar-store.ts | Zustand store: viewMode / cursor / grantId / eventType / sidePanelDate / sidePanelEvents |
| 30 | grantcalendar-toolbar.tsx | Header actions + view toggle + filters |
| 31 | month-view.tsx | 7-col grid; renders day cells + event chips |
| 32 | quarter-view.tsx | 3-col grid of mini-month components |
| 33 | mini-month.tsx | Single mini-month renderer (reused 3× in Quarter view) |
| 34 | timeline-view.tsx | Gantt-style grid: header + grant rows + bars + markers |
| 35 | upcoming-deadlines-table.tsx | 6-col table below views; reads `upcomingGrantDeadlines` query |
| 36 | event-side-panel.tsx | Sheet (400px right) — lists events for clicked date |
| 37 | add-deadline-modal.tsx | RHF + Zod modal for GrantCalendarEvent Create/Update |
| 38 | delete-deadline-modal.tsx | Confirm dialog for ad-hoc event delete |
| 39 | grantcalendar-skeletons.tsx | Shape-matched skeletons for each view + table |

### Frontend — Renderer Folder (page-scoped, NOT registry)

> Folder: `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/grantcalendar-widgets/`

| # | File | Purpose |
|---|------|---------|
| 40 | event-chip.tsx | Inline event chip (red/yellow/orange/green/blue) — used in Month view + Side panel + Quarter dot |
| 41 | timeline-bar.tsx | Single bar segment (active / on-track / upcoming) |
| 42 | timeline-marker.tsx | Single circular marker (R/M/!/D/?) |
| 43 | deadline-status-pill.tsx | "{N} days left" / "Today" / "Past" with semantic color |
| 44 | event-type-badge.tsx | Type pill in deadline table (application/meeting/decision/report/milestone/etc.) |
| 45 | folder barrel | re-export 5 renderers |

(These are imported DIRECTLY by page components — they are NOT registered in `WIDGET_REGISTRY`. See §⑫ ISSUE-2.)

### Frontend — Route Stub

| # | File | Action |
|---|------|--------|
| 46 | app/[lang]/(core)/crm/grant/grantcalendar/page.tsx | OVERWRITE existing UnderConstruction stub → default-export the page-components index |

### Frontend — Wiring

| # | File | Change |
|---|------|--------|
| 47 | pages barrel (if pages/crm/grant exists) | Re-export grantcalendar page |
| 48 | shared-cell-renderers barrel | NO change (page-scoped renderers don't register globally) |
| 49 | sidebar config | NO change (menu already exists in MODULE_MENU_REFERENCE — verify menu row is present in DB via seed) |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: CUSTOM_PAGE          # NOT MENU_DASHBOARD; dedicated page under CRM_GRANT

MenuName: Grant Calendar
MenuCode: GRANTCALENDAR
ParentMenu: CRM_GRANT
Module: CRM
MenuUrl: crm/grant/grantcalendar
OrderBy: 3                              # per MODULE_MENU_REFERENCE.md
GridType: DASHBOARD

MenuCapabilities: READ, CREATE, UPDATE, DELETE, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, UPDATE, DELETE, EXPORT

GridFormSchema: SKIP                    # custom page, no RJSF form
GridCode: GRANTCALENDAR

# No Dashboard row in sett.Dashboards (this is NOT a widget-grid dashboard)
# No DashboardLayout row
# No sett.Widgets / sett.WidgetTypes rows
# No auth.WidgetRoles rows
# Menu row + capabilities are the only seed.
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

### Queries

| GQL Field | Returns | Args | Notes |
|-----------|---------|------|-------|
| `grantCalendarEvents` | `[GrantCalendarEventDto]` | `fromDate: Date!, toDate: Date!, grantId: Int, eventTypeCode: String` | UNION over 5 sources; ordered by EventDate asc |
| `upcomingGrantDeadlines` | `[UpcomingGrantDeadlineDto]` | `asOfDate: Date!, maxRows: Int = 20, grantId: Int, eventTypeCode: String` | Same projection + `daysLeft` int; only future events |
| `grantCalendarEventById` | `GrantCalendarEventResponseDto` | `id: Int!` | For Edit pre-fill |
| `getAllGrantList` (EXISTING — verify) | `[GrantResponseDto]` | minimal | For Grant filter dropdown + Add Deadline form |
| `getMasterDataByType` (EXISTING) | `[MasterDataResponseDto]` | `typeCode: "GRANTCALENDAREVENTTYPE"` | For Event Type filter + Add Deadline form |

### Mutations

| GQL Field | Returns | Args |
|-----------|---------|------|
| `createGrantCalendarEvent` | `Int` (new id) | `request: GrantCalendarEventRequestDto!` |
| `updateGrantCalendarEvent` | `Boolean` | `id: Int!, request: GrantCalendarEventRequestDto!` |
| `deleteGrantCalendarEvent` | `Boolean` | `id: Int!` |

### GrantCalendarEventDto shape

```ts
type GrantCalendarEventDto = {
  eventDate: string;            // ISO date (YYYY-MM-DD)
  eventType: 'APPLICATION_DEADLINE' | 'REPORT_DUE' | 'MEETING' | 'REVIEW' | 'DECISION_EXPECTED' | 'MILESTONE' | 'DISBURSEMENT_OR_APPROVAL' | 'GRANT_START' | 'GRANT_END' | 'CUSTOM';
  color: 'red' | 'yellow' | 'orange' | 'green' | 'blue';
  iconHint: string;             // Phosphor icon name (e.g., 'ph:file-text', 'ph:users-three')
  title: string;                // pre-formatted in BE; FE renders verbatim
  description?: string;
  location?: string;
  grantId: number;
  grantCode: string;            // e.g., 'GRT-008'
  funderName: string;           // e.g., 'USAID'
  sourceTable: 'Grant' | 'GrantReport' | 'GrantMilestone' | 'GrantStageHistory' | 'GrantCalendarEvent';
  sourceRecordId: number;
  drillDownTarget: 'grant-detail' | 'grant-form' | 'grant-reporting';   // BE picks; FE follows
  status?: string;              // e.g., 'Draft', 'Submitted', 'OverDue'
};

type UpcomingGrantDeadlineDto = GrantCalendarEventDto & {
  daysLeft: number;             // computed asOfDate - eventDate
  urgencyTier: 'urgent' | 'warning' | 'normal';   // BE-derived
};

type GrantCalendarEventRequestDto = {
  grantId: number;
  eventTypeId: number;          // FK to MasterData(GRANTCALENDAREVENTTYPE)
  title: string;
  description?: string;
  location?: string;
  eventDate: string;            // ISO date — BE normalizes to UTC midnight
  isAllDay: boolean;
  time?: string;                // HH:mm:ss when isAllDay=false
  reminderDaysBefore?: number;
  color?: string;
};

type GrantCalendarEventResponseDto = GrantCalendarEventRequestDto & {
  grantCalendarEventId: number;
  grantTitle: string;
  grantCode: string;
  eventTypeName: string;
  eventTypeCode: string;
  createdBy: number;
  createdDate: string;
  modifiedBy?: number;
  modifiedDate?: string;
};
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] EF migration applied — `grant.GrantCalendarEvents` table exists with expected indexes
- [ ] `pnpm dev` — page loads at `/{lang}/crm/grant/grantcalendar`
- [ ] No TypeScript errors (`pnpm tsc --noEmit`)
- [ ] No console errors / warnings on initial load

**Functional Verification (Full E2E — MANDATORY):**

Month View:
- [ ] Loads current month with correct day-of-week alignment (Mon-first)
- [ ] Today cell highlighted with primary border
- [ ] Weekend cells faintly tinted
- [ ] Other-month days greyed
- [ ] Event chips render with correct color per event type
- [ ] Chips truncate when day has many events; "+N more" appears when >3
- [ ] Prev / Next nav updates calendar; URL `cursor` param syncs
- [ ] Today button returns to current month
- [ ] Clicking day cell opens side panel; clicking chip also opens (event.stopPropagation works)

Quarter View:
- [ ] 3 mini-months render in current quarter
- [ ] Day dots show under days that have events
- [ ] Today highlighted across all 3 minis
- [ ] Quarter nav (Prev / Next) jumps by quarter, not month
- [ ] Day click opens side panel (same panel as Month view)

Timeline View:
- [ ] 12 month columns (Jan-Dec of cursor year)
- [ ] Current month column highlighted
- [ ] One row per grant active in any month of window
- [ ] Bars span correct months (active / on-track / upcoming)
- [ ] Markers (R / M / ! / D / ?) render at correct positions
- [ ] Marker hover shows title tooltip
- [ ] Marker click opens side panel filtered to that event

Filters:
- [ ] Grant dropdown: All Grants + per-grant options labeled `{GrantCode} ({FunderName})`
- [ ] Selecting a Grant filters all views + table
- [ ] Type dropdown: All / Reports / Meetings / Deadlines / Milestones / Decisions
- [ ] Combined filters work (Grant + Type both applied)
- [ ] URL params sync (`?grantId=X&eventType=Y`)
- [ ] Browser back/forward restore filter state

Upcoming Deadlines Table:
- [ ] Always visible below the active view
- [ ] Default 6+ rows, ordered by date asc
- [ ] daysLeft computed correctly (Today / N days / Past for table excluded)
- [ ] Urgent row tint (<7d) applied
- [ ] Warning row tint (7-30d) applied
- [ ] Type badges render with correct color per event-type
- [ ] Action button label matches event type (View Application / Create Report / etc.)
- [ ] Grant link in row navigates to grant-detail
- [ ] Action button navigates per Drill-Down Map

Side Panel:
- [ ] Opens on date click; closes on ESC / overlay click / X button
- [ ] Header shows full date
- [ ] Each event card shows icon, title, grant code+funder, action button
- [ ] Multiple events on same day stack vertically
- [ ] Action button deep-links correctly per event-type
- [ ] Empty state ("No events scheduled") renders for days without events

Add Deadline Modal:
- [ ] Opens from `[+ Add Deadline]` header button
- [ ] All required fields validated (Grant, EventType, Title, EventDate)
- [ ] Save button disabled until form valid (per memory rule)
- [ ] All-day toggle hides/shows Time field
- [ ] Submit creates GrantCalendarEvent → toast → modal closes → calendar refetches → new event visible
- [ ] Edit (from side panel on CUSTOM source) reopens modal pre-filled
- [ ] Delete confirms then removes event

Drill-Down Navigation:
- [ ] APPLICATION_DEADLINE → grant-form opens in read mode
- [ ] REPORT_DUE — if reportId present → grant-reporting edit; if not → grant-reporting new (prefilled grantId)
- [ ] All other types → grant-list opens with `?mode=read&id={grantId}` (route may vary — see §⑫ ISSUE-13)

Export / Sync:
- [ ] `[Export Calendar]` — toast or ICS download (per ISSUE-12)
- [ ] `[Sync to Outlook/Google]` — toast SERVICE_PLACEHOLDER

UI uniformity (per memory feedback):
- [ ] No inline hex in `style={{}}` (colors via tokens or renderer-local maps)
- [ ] No inline `px` units (use tokens / Tailwind classes)
- [ ] No fa-* icons (Phosphor only via @iconify)
- [ ] No `<div className="...">Loading...</div>` (shape-matched Skeletons only)
- [ ] All status badges + icon containers use solid bg + white text per [widget_icon_badge_styling]

Role-scoping (per §④):
- [ ] BUSINESSADMIN sees all grants
- [ ] (Future role) GRANT_MANAGER sees only their branch — verify when role table is finalized (ISSUE-9)

Responsive:
- [ ] xs (mobile): day cells shrink to 60px height; quarter stacks 1-col; deadline table h-scrolls
- [ ] sm: 2-col quarter
- [ ] md / lg / xl: full layout

Multi-tenant:
- [ ] User in Company A sees only Company A's grants/events
- [ ] Cross-tenant data leak attempts (manual URL id) → 404 / empty

DB Seed verification:
- [ ] Menu `GRANTCALENDAR` exists under `CRM_GRANT` at OrderBy=3
- [ ] 6 MenuCapabilities present
- [ ] 6 BUSINESSADMIN RoleCapability grants present
- [ ] Grid row `GRANTCALENDAR` with GridType=DASHBOARD, GridFormSchema=NULL
- [ ] MasterDataType `GRANTCALENDAREVENTTYPE` with MEETING / REVIEW / CUSTOM rows
- [ ] DataSetting JSON correctly populated with colorHex/bgHex/icon per row

---

## ⑫ Special Notes & Known Issues

### ISSUE-1 — HIGH — CUSTOM_PAGE classification (NOT MENU_DASHBOARD)
**Why**: The mockup is a calendar visualization with 3 view modes, not a widget-grid. The menu URL is `crm/grant/grantcalendar` under `CRM_GRANT` parent, NOT `crm/dashboards/grantcalendar` under `CRM_DASHBOARDS`. The MENU_DASHBOARD dynamic-route pattern (`[lang]/(core)/[module]/dashboards/[slug]/page.tsx`) does not apply.
**Decision**: Build as a dedicated page at `app/[lang]/(core)/crm/grant/grantcalendar/page.tsx` with custom view components. NO Dashboard / DashboardLayout / Widget / WidgetType / WidgetRole rows. NO entry in `WIDGET_REGISTRY` or `QUERY_REGISTRY`.
**Risk**: If a future "dashboards module overhaul" refactors all dashboard surfaces to a unified pattern, this page may need migration. Acceptable — keeps current ship simple.

### ISSUE-2 — MED — Widget folder convention vs registry registration
**Why**: Per the _DASHBOARD.md template, renderer files normally live under `dashboards/widgets/{dashboard-name}-widgets/` AND get registered in `WIDGET_REGISTRY`. For this page-scoped use (no `sett.Widgets` rows, no `ComponentPath` lookup), registration is unnecessary.
**Decision**: Keep the FOLDER convention (consistency with #69 Ambassador Dashboard) but import the renderers directly in the page components (NOT via registry). The 5 renderer files (event-chip / timeline-bar / timeline-marker / deadline-status-pill / event-type-badge) live in the folder but are imported directly.

### ISSUE-3 — MED — `GRANTCALENDAREVENTTYPE` MasterDataType is NEW
**Why**: This type code doesn't exist yet. Seed file must declare both `MasterDataType` row AND 3 value rows (MEETING / REVIEW / CUSTOM). Verify with `SELECT * FROM com.MasterDataTypes WHERE TypeCode='GRANTCALENDAREVENTTYPE'` before insert.
**Action**: Idempotent seed using `NOT EXISTS` pattern (see #1 GlobalDonation seed precedent).

### ISSUE-4 — LOW — Event color: BE projection vs MasterData lookup
**Why**: For the 7 DERIVED event types (APPLICATION_DEADLINE through GRANT_END), color is hardcoded in the BE projection (red/yellow/orange/green/blue) — these are not user-customizable. For the 3 ad-hoc types (MEETING / REVIEW / CUSTOM), color SHOULD come from MasterData.DataSetting (so admins can tweak). The handler must branch: derived → hardcoded color; ad-hoc → read from MasterData.
**Action**: Document constants top-of-handler. Pre-seed MasterData DataSetting with `{colorHex, bgHex, icon}` JSON per row.

### ISSUE-5 — LOW — `ReminderDaysBefore` is field-only in MVP
**Why**: No reminder engine exists in the codebase. The field is captured but no background job fires reminders.
**Action**: Surface field in form + detail. Document in §⑫ as deferred feature; mark with a `// TODO: reminder service` comment in entity.

### ISSUE-6 — LOW — Past events visible in main view, hidden from table
**Why**: Calendar Month/Quarter/Timeline show past + upcoming events (context). Upcoming Deadlines table is FORWARD-ONLY (events with date >= asOfDate).
**Action**: BE query `GetUpcomingGrantDeadlines` filters `EventDate >= @asOfDate`. `GetGrantCalendarEvents` does NOT filter — uses `EventDate BETWEEN fromDate AND toDate`.

### ISSUE-7 — MED — UTC normalization per memory rule [db_utc_only]
**Why**: Postgres columns are `timestamp with time zone`; Npgsql throws on `Kind=Unspecified`. EventDate is conceptually date-only but stored as UTC midnight. FE must send ISO date string; BE must parse to `DateTime.SpecifyKind(date, DateTimeKind.Utc)` at handler entry.
**Action**: Handler entry-points normalize. NO `DateTime.Today` in EF predicates — use `DateTime.UtcNow.Date`.

### ISSUE-8 — LOW — Quarter view cursor: Q-based or month-based?
**Why**: Mockup shows "Q2 2026 (Apr - Jun)" — implies quarter-aligned (Jan-Mar / Apr-Jun / Jul-Sep / Oct-Dec). Cursor could store `YYYY-Q{N}` or just the first month.
**Decision**: Cursor stores `YYYY-MM` (canonical); when in Quarter view, ROUND DOWN to quarter start: `cursorMonth = ((Math.floor((month-1)/3))*3)+1`. Simplest.

### ISSUE-9 — MED — Role catalog for branch-scoping unclear
**Why**: Memory rule says BUSINESSADMIN only for capabilities. But §④ mentions GRANT_MANAGER / PROGRAM_DIRECTOR roles with branch scope. The role table in the codebase may not have these distinct roles yet.
**Action**: BUILD AS BUSINESSADMIN-only first (per memory rule [build_directives]). Document branch-scoping in handler comments as future work. Verify role catalog with user before adding non-BUSINESSADMIN scoping logic.

### ISSUE-10 — LOW — EventDate range validation
**Why**: A 5-years-in-past and 10-years-in-future soft guard prevents accidental "year 1900" or "year 3000" entries from data-entry mistakes. Hard guards (PG check constraints) skipped — validators handle this.
**Action**: FluentValidation rules on Create/Update. Surface friendly error in modal.

### ISSUE-11 — MED — Composite UNION query performance
**Why**: 5-arm UNION over Grant + GrantReport + GrantMilestone + GrantStageHistory + GrantCalendarEvent could be slow if grant count grows past ~5000 per tenant. Current scale (NGO) expected to stay <500 active grants per tenant.
**Action**: Index `(CompanyId, GrantId, EventDate)` on new table; the existing entity indexes likely cover the others. Profile if perf complaints arise; consider materialized view as ⑫ ISSUE follow-up only if measured >2s P95.

### ISSUE-12 — MED — Export Calendar (.ics) — SERVICE_PLACEHOLDER OR real?
**Why**: ICS format is text-only, well-specified, generatable in handler. No third-party dep needed. But "Export Calendar" button has no infrastructure (no API endpoint for binary download in current codebase).
**Decision**: MVP — SERVICE_PLACEHOLDER (toast "ICS export coming soon"). Pre-flagged for V2 — implement as a typed handler returning a base64 string + small FE helper to download. ~half-day effort.

### ISSUE-13 — MED — Grant drill-down route uncertain
**Why**: Mockup actions reference `grants/grant-detail` and `grants/grant-form` and `grants/grant-reporting` as routes, but the actual built #62/#63 routes are `crm/grant/grantlist?mode=read&id=X` (consolidated FLOW view-page pattern). Need to verify what route the FE dev should deep-link to.
**Action**: BE projection sets `drillDownTarget: 'grant-detail' | 'grant-form' | 'grant-reporting'`; FE has a small map:
- `grant-detail` → `/crm/grant/grantlist?mode=read&id={grantId}`
- `grant-form` → `/crm/grant/grantlist?mode=edit&id={grantId}` (or `?mode=new` if no id)
- `grant-reporting` → `/crm/grant/grantreporting?mode={edit|new}&id={reportId or grantId}`

Confirm with #62 + #63 prompt files / built code at build time.

### ISSUE-14 — LOW — Outlook/Google sync — service placeholder
**Why**: OAuth integration with Outlook/Google requires app registration + token storage + scope handling. Out of scope for this prompt.
**Decision**: SERVICE_PLACEHOLDER — button toasts "Calendar sync coming in V2".

### ISSUE-15 — LOW — `Grant.GrantStageHistories` access path
**Why**: The projection arm for `DISBURSEMENT_OR_APPROVAL` reads `GrantStageHistory.ToStage.Code` — requires Include of ToStage MasterData + filter on `Code IN ('DISBURSED','APPROVED')`. Verify MasterData TypeCode `GRANTSTAGE` actually has rows with codes `DISBURSED` and `APPROVED` (or similar) per #62 seed.
**Action**: At build time, check the GRANTSTAGE MasterData seed in `#62 Grant`'s seed file. If codes differ (e.g., `DISB`, `APPR`), adjust the WHERE clause. Document in build log.

### ISSUE-16 — LOW — `Grant.StageId` filter for "DECISION_EXPECTED"
**Why**: Projection arm 2 requires `Grant.StageId NOT IN (Approved, Rejected)` — needs the StageId for those codes. Resolve via subquery or join to MasterData. Cleaner: `WHERE g.Stage.Code NOT IN ('APPROVED','REJECTED')` via Include.
**Action**: Include `Stage` MasterData; filter via `.Code` predicate. Confirm code values against #62 seed.

### ISSUE-17 — LOW — Mockup shows Outlook/Google sync; no infra to support either
**Why**: SERVICE_PLACEHOLDER — already in ISSUE-14. Adding here to ensure FE dev does NOT attempt any OAuth wiring.

### ISSUE-18 — LOW — `sql-scripts-dyanmic/` folder typo
**Why**: Repository folder is misspelled `dyanmic` (not `dynamic`). Preserve per all prior screen precedents.
**Action**: Seed file MUST live at `sql-scripts-dyanmic/GrantCalendar-sqlscripts.sql`. NEVER fix the folder typo.

### ISSUE-19 — LOW — No registry-level DASHBOARD seed (Dashboard/DashboardLayout/Widget/WidgetType rows)
**Why**: This is a custom page, NOT a widget-grid dashboard. The standard MENU_DASHBOARD seed (Dashboard row + DashboardLayout JSON + Widget rows + WidgetRole grants) DOES NOT APPLY.
**Action**: Seed file only contains: Menu + MenuCapability + RoleCapability + Grid (DASHBOARD type) + MasterDataType + MasterData rows. Build agent should NOT generate widget/dashboard seed boilerplate.

### ISSUE-20 — MED — Original registry status was SKIP_DASHBOARD
**Why**: This screen was originally deferred. By planning it now, status moves SKIP_DASHBOARD → PROMPT_READY. Verify user intent: they typed `/plan-screens #64`, so the planning is requested.
**Action**: Registry row updated to `PROMPT_READY`; document in notes.

### SERVICE_PLACEHOLDERs (summary)

| # | Element | Placeholder reason | V2 plan |
|---|---------|--------------------|---------|
| 1 | `[Export Calendar]` | No binary-download infra | ICS generator handler + FE blob-download |
| 2 | `[Sync to Outlook/Google]` | No OAuth provider integration | OAuth app + token storage + sync worker |
| 3 | `ReminderDaysBefore` field | No reminder engine | Background job that emails reminders |

### Source entity dependency check

- ✅ Grant — #62 COMPLETED — entity at `Base.Domain/Models/GrantModels/Grant.cs`
- ✅ GrantReport — #63 COMPLETED — entity at `Base.Domain/Models/GrantModels/GrantReport.cs`
- ✅ GrantMilestone — bootstrapped by #62 — entity at `Base.Domain/Models/GrantModels/GrantMilestone.cs`
- ✅ GrantStageHistory — bootstrapped by #62 — entity at `Base.Domain/Models/GrantModels/GrantStageHistory.cs`
- ✅ `grant` schema, `IGrantDbContext`, `GrantDbContext`, `GrantMappings`, `DecoratorGrantModules` — all bootstrapped by #62. Just extend.
- ✅ MasterData (com schema) — exists. Extend with new TypeCode.

### Build-order note

This screen depends on #62 Grant + #63 Grant Report being COMPLETED. Both are. Safe to build.

### Pre-flight verification checklist for /build-screen

Before BE Developer agent generates code:
1. Verify `Grant.SubmissionDeadline`, `Grant.DecisionDate`, `Grant.StartDate`, `Grant.EndDate`, `Grant.SubmittedDate`, `Grant.StageId` columns all exist on the built Grant entity (per #62 prompt).
2. Verify `GrantReport.DueDate`, `GrantReport.StatusCode`, `GrantReport.SubmittedDate` columns exist (per #63 prompt).
3. Verify `GrantMilestone.TargetDate`, `GrantMilestone.StatusCode` exist.
4. Verify `GrantStageHistory.TransitionDate`, `GrantStageHistory.ToStageId` exist.
5. Verify GRANTSTAGE MasterData seed includes `APPROVED`, `REJECTED`, `DISBURSED` (or codes that need substitution per ISSUE-15/16).
6. Verify `IGrantDbContext` + `GrantDbContext` + `GrantMappings` + `DecoratorGrantModules` exist and are wired (per #62 bootstrap).

If any verification fails, escalate before generating code.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | build (2026-05-14) | LOW | BE | `DISBURSED` MasterData code not seeded (project uses `APPROVED`/`ACTIVE`). Projection arm 7 substituted filter to `ToStage.Code IN ('APPROVED','ACTIVE')` — green markers fire on transitions into either stage. Validated against #62 Grant-sqlscripts.sql GRANTSTAGE seed lines 314-322. | CLOSED (2026-05-14 — substitution applied at build time) |
| ISSUE-2 | build (2026-05-14) | LOW | FE | Route stub already existed at `app/[lang]/crm/grant/grantcalendar/page.tsx` (UnderConstruction stub). OVERWRITTEN, not created. Path under `[lang]/crm/...` (NOT `(core)/crm/...`) — prompt §⑧ row #46 had wrong path; matched #62/#63 actual layout. | CLOSED (2026-05-14 — corrected at build time) |
| ISSUE-3 | build (2026-05-14) | LOW | BE | DB seed uses capability code `MODIFY` instead of `UPDATE` (prompt §⑨ CONFIG block said `UPDATE`). Verified `MODIFY` is the actual `Capabilities.CapabilityCode` value used project-wide. No fix needed; doc note only. | CLOSED (2026-05-14 — convention applied) |
| ISSUE-4 | build (2026-05-14) | LOW | FE | Folder name in §⑧ used `grants-service`/`grants-queries`/`grants-mutations` (plural). Repo actually uses singular (`grant-service`, etc.) per #62/#63 precedent. DTOs/GQL placed in the correct singular folders. | CLOSED (2026-05-14) |
| ISSUE-5 | build (2026-05-14) | LOW | FE | `getMasterDataByType(typeCode)` query doesn't exist as a discrete BE endpoint. Used the existing `MASTERDATAS_QUERY` with `advancedFilter: { masterDataType.typeCode = "GRANTCALENDAREVENTTYPE" }` per #62 grant-form precedent. | CLOSED (2026-05-14) |
| ISSUE-6 | build (2026-05-14) | LOW | FE | `getAllGrantList` query doesn't exist as a discrete BE endpoint. Used existing paginated `GET_GRANTS_QUERY` via `FormSearchableSelect` (server-side pagination — handles all grant counts). | CLOSED (2026-05-14) |
| ISSUE-7 | build (2026-05-14) | MED | BE+FE | `[Export Calendar (.ics)]` button — toast `"ICS export coming soon"`. No binary-download infra. Implement in V2 as base64-returning handler + FE blob-download (~half-day). | OPEN |
| ISSUE-8 | build (2026-05-14) | MED | BE+FE | `[Sync to Outlook/Google]` — toast `"Calendar sync coming in V2"`. OAuth provider integration deferred. | OPEN |
| ISSUE-9 | build (2026-05-14) | LOW | BE | `ReminderDaysBefore` field captured in entity + form + persisted, but no reminder engine. Surfaced in DTOs; no background job fires. | OPEN |
| ISSUE-10 | build (2026-05-14) | LOW | BE | Branch-scoping (GRANT_MANAGER / PROGRAM_DIRECTOR roles seeing only own-branch grants) deferred per ISSUE-9 of original prompt. Built BUSINESSADMIN-only. Add when role catalog finalized. | OPEN |
| ISSUE-11 | build (2026-05-14) | LOW | OPS | EF migration generated (`20260514063733_Add_GrantCalendarEvent.cs`) but DB not migrated yet. User must run `dotnet ef database update` AFTER first running this screen's seed (the seed creates Menu/Grid/MasterData; the migration creates the `grant.GrantCalendarEvents` table). | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-14 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. DASHBOARD/CUSTOM_PAGE — dedicated calendar page under `CRM_GRANT` (NOT widget-grid). 3 view modes (Month / Quarter / Timeline) + always-visible Upcoming Deadlines table + Sheet side panel + Add Deadline modal + URL-synced filters.
- **Files touched**:
  - BE (12 created + 6 modified):
    - Entity: `Base.Domain/Models/GrantModels/GrantCalendarEvent.cs` (created)
    - EF Config: `Base.Infrastructure/Data/Configurations/GrantConfigurations/GrantCalendarEventConfiguration.cs` (created)
    - Migration: `Base.Infrastructure/Migrations/20260514063733_Add_GrantCalendarEvent.cs` + Designer.cs (created)
    - Schemas: `Base.Application/Schemas/GrantSchemas/GrantCalendarSchemas.cs` (created — 4 DTOs)
    - Queries (3): `GetGrantCalendarEvents.cs` (8-arm Concat), `GetUpcomingGrantDeadlines.cs`, `GetGrantCalendarEventById.cs` — all under `Business/GrantBusiness/GrantCalendar/Queries/` (created)
    - Commands (4): `CreateGrantCalendarEvent.cs`, `UpdateGrantCalendarEvent.cs`, `DeleteGrantCalendarEvent.cs`, `GrantCalendarEventValidators.cs` — all under `Business/GrantBusiness/GrantCalendar/Commands/` (created)
    - Wiring (modified): `IGrantDbContext.cs` (+DbSet), `GrantDbContext.cs` (+DbSet), `DecoratorProperties.cs` (+constant in `DecoratorGrantModules`), `GrantMappings.cs` (+4 TypeAdapterConfig pairs), `GrantQueries.cs` (+3 endpoints), `GrantMutations.cs` (+3 endpoints)
  - FE (24 created + 4 modified):
    - DTOs (3 created): `GrantCalendarEventDto.ts`, `UpcomingGrantDeadlineDto.ts`, `GrantCalendarEventCrudDto.ts` — under `domain/entities/grant-service/`
    - GQL (2 created): `GrantCalendarQuery.ts` (3 queries), `GrantCalendarMutation.ts` (3 mutations) — under `infrastructure/gql-queries/grant-queries/` + `infrastructure/gql-mutations/grant-mutations/`
    - Page-scoped renderers (6 created): under `custom-components/dashboards/widgets/grantcalendar-widgets/` — `event-chip.tsx`, `timeline-bar.tsx`, `timeline-marker.tsx`, `deadline-status-pill.tsx`, `event-type-badge.tsx`, `index.ts` (NOT registered in WIDGET_REGISTRY — imported directly per ISSUE-2 of original prompt)
    - Page components (13 created): under `page-components/crm/grant/grantcalendar/` — `index.tsx`, `grantcalendar-page-config.tsx`, `grantcalendar-store.ts` (Zustand), `types.ts`, `drilldown.ts`, `grantcalendar-toolbar.tsx`, `month-view.tsx`, `quarter-view.tsx`, `mini-month.tsx`, `timeline-view.tsx`, `upcoming-deadlines-table.tsx`, `event-side-panel.tsx`, `add-deadline-modal.tsx`, `delete-deadline-modal.tsx`, `grantcalendar-skeletons.tsx` (15 actually — `types.ts` + `drilldown.ts` split out for clarity)
    - Pages barrel + route (2): `presentation/pages/crm/grant/grantcalendar.tsx` (created) + `app/[lang]/crm/grant/grantcalendar/page.tsx` (OVERWRITTEN)
    - Barrel wiring (modified): `grant-service/index.ts`, `grant-queries/index.ts`, `grant-mutations/index.ts`, `pages/crm/grant/index.ts`
  - DB: `PSS_2.0_Backend/.../sql-scripts-dyanmic/GrantCalendar-sqlscripts.sql` (created — Menu + 6 MenuCapabilities + 5 RoleCapabilities for BUSINESSADMIN + Grid (DASHBOARD type, GridFormSchema=NULL) + MasterDataType `GRANTCALENDAREVENTTYPE` + 3 values MEETING/REVIEW/CUSTOM with DataSetting JSON `{colorHex,bgHex,icon}`. NO Dashboard/DashboardLayout/Widget/WidgetType/WidgetRole rows per CUSTOM_PAGE classification.)
- **Build outcome**: `dotnet build` PASS (0 errors, pre-existing warnings unchanged). `pnpm tsc --noEmit` PASS for all 24 new/modified FE files (6 pre-existing errors in unrelated files persist).
- **Deviations from spec**:
  - Projection arm 7 stage filter substituted from `('DISBURSED','APPROVED')` → `('APPROVED','ACTIVE')` — `DISBURSED` not in GRANTSTAGE seed. APPROVED = decision moment, ACTIVE = grant activation (de-facto disbursement). Logged as ISSUE-1 in Build Log.
  - Capability code `MODIFY` used instead of `UPDATE` (project convention). Logged as ISSUE-3.
  - DTO folder is `grant-service` (singular) NOT `grants-service` (plural). Logged as ISSUE-4.
  - MasterData lookup uses `MASTERDATAS_QUERY` with `advancedFilter` (no dedicated `getMasterDataByType` endpoint). Logged as ISSUE-5.
  - Grant filter dropdown uses paginated `GET_GRANTS_QUERY` via `FormSearchableSelect` (no `getAllGrantList` endpoint). Logged as ISSUE-6.
  - File count: 27 FE files total (vs prompt's ~27) — split out `types.ts` + `drilldown.ts` as small helper files for clarity. Same logical scope.
  - File count: 18 BE files total (vs prompt's ~14) — Designer.cs companion + Validators in separate file + EF migration. Same logical scope.
  - Edit-from-side-panel flow: opens modal then async-fetches via `GET_GRANT_CALENDAR_EVENT_BY_ID_QUERY` for full pre-fill (with loading spinner). Spec didn't require this — enhancement for full CRUD field hydration.
- **Known issues opened**: ISSUE-7 (Export ICS placeholder), ISSUE-8 (Outlook/Google sync placeholder), ISSUE-9 (ReminderDaysBefore field-only), ISSUE-10 (branch-scoping deferred), ISSUE-11 (`dotnet ef database update` pending).
- **Known issues closed**: ISSUE-1/-2/-3/-4/-5/-6 — all build-time substitutions applied cleanly and documented in Known Issues table above.
- **Next step**: 
  1. User: `dotnet ef database update` (from `Base.Infrastructure/` or `Base.API/`) to materialize `grant.GrantCalendarEvents` table.
  2. User: execute `GrantCalendar-sqlscripts.sql` against the dev DB to seed Menu/Grid/MasterData.
  3. User: `pnpm dev` and visually verify all 3 view modes + side panel + Add Deadline modal at `/{lang}/crm/grant/grantcalendar`.
  4. Smoke test: Create an ad-hoc deadline → confirm it appears on the calendar + in Upcoming Deadlines table.
  5. (V2) Implement ICS export handler (ISSUE-7) + OAuth Outlook/Google sync (ISSUE-8) + reminder engine (ISSUE-9).