---
screen: VolunteerShift
registry_id: 54
module: CRM / Volunteer
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO — uses existing `app` schema (revised mid-build like #53 Volunteer)
planned_date: 2026-04-21
completed_date: 2026-04-24
last_session_date: 2026-04-24
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (Calendar + List dual-view + Side Panel Detail + Create Shift Modal)
- [x] Existing code reviewed (FE stub `volunteerscheduling/page.tsx` = `<div>Need to Develop</div>`; no BE)
- [x] Business rules + workflow extracted (status is COMPUTED from assignments, not stored)
- [x] FK targets resolved (Event, Branch — glob + grep confirmed; Volunteer does NOT exist → ISSUE-1)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (used prompt analysis directly — token-budget directive)
- [x] Solution Resolution complete (FLOW + In-Kind precedent confirmed)
- [x] UX Design finalized (Calendar grid + List grid + Create Modal + Side Drawer)
- [x] User Approval received (granted upfront in build args)
- [x] Backend code generated (main entity + 2 child entities + workflow mutations)
- [x] Backend wiring complete (existing `app` schema — IApplicationDbContext + ApplicationDbContext + DecoratorApplicationModules + VolunteerMappings)
- [x] Frontend code generated (index-page with calendar/list toggle + drawer + modal — NO view-page.tsx)
- [x] Frontend wiring complete (entity-operations + barrel exports + page config + route stub overwrite)
- [x] DB Seed script generated (GridFormSchema: SKIP for FLOW; ShiftType MasterData 5 rows)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/crm/volunteer/volunteerscheduling`
- [ ] Calendar view renders weekly grid (7 days × 8AM-6PM) with shift blocks colored by type
- [ ] List view toggle switches to table with columns: Date, Shift, Time, Location, Type, Needed, Assigned, Status, Actions
- [ ] Date navigation (prev/next week) + Day/Week/Month range toggle works
- [ ] "Create Shift" button opens MODAL with 12 fields + tag-input skills + auto-assign toggle
- [ ] Save creates shift → grid refreshes → modal closes
- [ ] Row click (list) / shift-block click (calendar) opens SIDE DRAWER with shift details
- [ ] Drawer shows: Detail rows, Status bar (Needed/Assigned/Confirmed), Assigned Volunteers table, Available Volunteers table
- [ ] Assigned volunteer actions: Remove (deletes assignment), Remind (SERVICE_PLACEHOLDER toast)
- [ ] Available volunteer action: Assign (creates Pending assignment → moves row to Assigned table)
- [ ] "Remind All Pending" + "Notify Available" bulk actions work (SERVICE_PLACEHOLDER toasts)
- [ ] "Auto-Schedule" header button = SERVICE_PLACEHOLDER toast
- [ ] Linked Event dropdown loads via ApiSelectV2 (GetEvents query)
- [ ] Branch dropdown loads via ApiSelectV2 (GetBranches query)
- [ ] Summary widgets (Total Shifts, Understaffed, Fully Staffed, Total Assigned) render above grid
- [ ] Status badges are COMPUTED correctly (server-side subquery: AssignedCount / NeededCount)
- [ ] DB Seed — menu "Scheduling" appears under "Volunteer" in sidebar

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: VolunteerShift
Module: CRM / Volunteer
Schema: vol
Group: VolModels

Business: Volunteer Scheduling is the operational heart of the Volunteer module — it lets admins create time-bounded **shifts** (events, office tasks, field work, remote work, training), specify how many volunteers are needed + which skills, and then assign/manage matched volunteers from the pool. The screen is used daily by Program Coordinators and Volunteer Managers to plan weekly coverage for campaigns, food drives, galas, and community outreach. A visual calendar (week/month) gives at-a-glance staffing health, while a side-drawer reveals per-shift assignment management with skill-match indicators. The Auto-Schedule action (future AI) and Notification/Reminder buttons bridge this screen to Notification Templates (#36) and eventually to an AI matching engine. Sits downstream of #53 Volunteer (assignments require volunteer records) and upstream of #55 Hour Tracking (confirmed assignments become logged hours).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from HTML mockup. Audit columns inherited from Entity base.
> **CompanyId is NOT a field** — FLOW screens get tenant from HttpContext.

### Parent Entity

Table: `vol."VolunteerShifts"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| VolunteerShiftId | int | — | PK | — | Primary key, identity |
| ShiftCode | string | 50 | YES | — | Unique per Company, auto-generated if empty (e.g., `VS-2026-00001`) |
| Title | string | 200 | YES | — | e.g., "Ramadan Food Pack Distribution" |
| ShiftDate | DateTime (date only) | — | YES | — | Mockup date picker |
| StartTime | TimeSpan | — | YES | — | HH:mm |
| EndTime | TimeSpan | — | YES | — | HH:mm; must be > StartTime |
| ShiftTypeId | int | — | YES | MasterData (ShiftType) | 5 seed values: Event, Office, Field, Remote, Training |
| BranchId | int | — | YES | app.Branches | FK |
| Location | string | 300 | NO | — | Free-text (e.g., "Dubai Community Center, Al Quoz") |
| EventId | int? | — | NO | app.Events | Optional — "Linked Event" dropdown in modal |
| VolunteersNeeded | int | — | YES | — | Must be > 0 |
| Description | string | 2000 | NO | — | Textarea |
| AutoAssignOnCreate | bool | — | YES | — | Default false; if true + Create&Assign used, triggers assignment stub |
| IsActive | bool | — | YES | — | Inherited |

**Computed columns** (not stored — returned by GetAll / GetById via LINQ subquery):
| Field | Source | Notes |
|-------|--------|-------|
| AssignedCount | `COUNT(Assignments WHERE Status != 'Cancelled')` | "5/8 vols" display |
| ConfirmedCount | `COUNT(Assignments WHERE Status = 'Confirmed')` | Drawer status bar |
| PendingCount | `COUNT(Assignments WHERE Status = 'Pending')` | Drawer actions |
| ComputedStatus | `AssignedCount == 0 → 'Critical'`; `AssignedCount < Needed → 'Understaffed'`; else `'FullyStaffed'` | Badge color |

### Child Entities

**VolunteerShiftSkill** — required skills list (1:Many)

Table: `vol."VolunteerShiftSkills"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| VolunteerShiftSkillId | int | — | PK | — | Identity |
| VolunteerShiftId | int | — | YES | vol.VolunteerShifts | Cascade delete |
| SkillName | string | 100 | YES | — | Free-text tag (mockup uses tag-input, no master table) |
| IsActive | bool | — | YES | — | Inherited |

**VolunteerShiftAssignment** — volunteer-to-shift assignment (1:Many)

Table: `vol."VolunteerShiftAssignments"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| VolunteerShiftAssignmentId | int | — | PK | — | Identity |
| VolunteerShiftId | int | — | YES | vol.VolunteerShifts | Cascade delete |
| **VolunteerId** | int | — | YES | **vol.Volunteers** | **⚠ Dep on #53** — see ISSUE-1 |
| AssignmentStatus | string | 30 | YES | — | Pending / Confirmed / Cancelled |
| AssignedAt | DateTime | — | YES | — | UTC now on create |
| ConfirmedAt | DateTime? | — | NO | — | Set on confirm mutation |
| ReminderSentAt | DateTime? | — | NO | — | Set on Remind action (SERVICE_PLACEHOLDER) |
| AssignmentNotes | string | 500 | NO | — | Optional |
| IsActive | bool | — | YES | — | Inherited |

**Unique constraint**: `(VolunteerShiftId, VolunteerId)` — cannot assign same volunteer twice to same shift.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (.Include() + nav props) + Frontend Developer (ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| BranchId | Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | `GetBranches` | `BranchName` | `BranchResponseDto` |
| EventId | Event | `Base.Domain/Models/ApplicationModels/Event.cs` | `GetEvents` | `EventName` | `EventResponseDto` |
| ShiftTypeId | MasterData (Type code: `SHIFTTYPE`) | `Base.Domain/Models/AppModels/MasterData.cs` | `GetMasterDataByType` with `typeCode='SHIFTTYPE'` | `MasterDataName` | `MasterDataResponseDto` |
| VolunteerId ⚠ | Volunteer (**NOT YET CREATED** — #53 dep) | `Base.Domain/Models/VolModels/Volunteer.cs` *(expected)* | `GetAllVolunteerList` *(expected)* | `VolunteerName` *(expected)* | `VolunteerResponseDto` *(expected)* |

**Reminder skill master**: None. Skills are free-text strings stored in `VolunteerShiftSkills` child. If a `vol.VolunteerSkills` master table is added later (in #53), migrate to FK at that time.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `ShiftCode` unique per `CompanyId` (auto-gen if empty: `VS-{yyyy}-{0000N}`)
- `(VolunteerShiftId, VolunteerId)` unique on `VolunteerShiftAssignments` (no duplicate assignment)

**Required Field Rules:**
- `Title`, `ShiftDate`, `StartTime`, `EndTime`, `ShiftTypeId`, `BranchId`, `VolunteersNeeded` are mandatory
- Skills list may be empty (no minimum count)

**Conditional Rules:**
- `EndTime` MUST be > `StartTime` (same-day shifts only — cross-midnight not supported in this iteration)
- `VolunteersNeeded` MUST be > 0 (min 1)
- `EventId` nullable — if set, must reference an active, non-cancelled Event on or before `ShiftDate`
- If user clicks **"Create & Assign"** (not just "Create Shift") and `AutoAssignOnCreate = true`, the backend creates the shift + inserts `Pending` assignments for matching volunteers (SERVICE_PLACEHOLDER — stub returns 0 assignments with a toast explaining AI matching isn't wired yet)

**Business Logic:**
- `ComputedStatus` derivation (server-side LINQ subquery, NOT stored):
  - 0 non-cancelled assignments → `'Critical'`
  - AssignedCount < Needed → `'Understaffed'`
  - AssignedCount >= Needed → `'FullyStaffed'`
- `AssignVolunteer` mutation: creates `Pending` assignment. Prevent duplicates; check shift still has capacity (`AssignedCount < VolunteersNeeded`) OR allow overbook with warning (admin discretion — allow with warning).
- `ConfirmAssignment` mutation: transitions `Pending → Confirmed`, stamps `ConfirmedAt`.
- `RemoveAssignment` mutation: **hard delete** the assignment row (mockup Remove button — not soft-delete).
- `RemindAssignment` mutation: stamps `ReminderSentAt = now` and returns a stub "notification queued" response (SERVICE_PLACEHOLDER — no actual SMS/WhatsApp dispatch yet).

**Workflow (Shift lifecycle):**
- States: `Draft → Active` (no explicit draft — shifts are created active)
- Assignment states: `Pending → Confirmed → (Cancelled)` — transitions driven by `AssignVolunteer` → `ConfirmAssignment` → `RemoveAssignment`
- No approval chain.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW (non-standard — modal create/edit + side-drawer detail)
**Type Classification**: Workflow/transactional with parent-child-grandchild nesting (Shift → Assignments → Volunteers)
**Reason**: Transactional workflow with nested child assignments, SERVICE_PLACEHOLDER actions (Auto-Schedule, Remind, Notify), computed status, and a dual-view index (calendar + list). Create/Edit is simple enough for a modal (12 fields), and the detail view is richer than a MASTER_GRID read drawer could carry (assignment tables, status bar, skill-match indicators). Follows the **In-Kind Donation #7 precedent** for non-standard FLOW (grid + side-drawer detail — NO `?mode=read` full page, NO `view-page.tsx`).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) for main entity
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation (VolunteerShiftSkills on Create/Update)
- [x] Multi-FK validation (ValidateForeignKeyRecord for BranchId, EventId, ShiftTypeId, VolunteerId)
- [x] Unique validation — ShiftCode (tenant-scoped), (VolunteerShiftId, VolunteerId) composite
- [x] Workflow commands (AssignVolunteer, ConfirmAssignment, RemoveAssignment, RemindAssignment)
- [x] Custom mutations (AutoScheduleShift — SERVICE_PLACEHOLDER, BulkRemindPending, BulkNotifyAvailable)
- [x] Custom queries (GetVolunteerShiftsByDateRange for calendar view, GetAvailableVolunteersForShift for drawer's available list, GetVolunteerShiftSummary for widgets)
- [ ] File upload — N/A

**Frontend Patterns Required:**
- [x] **Dual-view index**: Calendar grid (custom component) + List grid (FlowDataTable). View toggle in ScreenHeader.
- [x] **NO view-page.tsx** — everything on index-page with modal + drawer siblings (In-Kind precedent)
- [x] **Create/Edit Modal** (RJSF or custom form — recommend React Hook Form custom since modal has tag-input + toggle)
- [x] **Side Drawer** for shift detail (520px right drawer, matches In-Kind pattern)
- [x] Zustand store (`volunteershift-store.ts`) — drawer state, modal state, view mode, date range
- [x] **ApiSelectV2** for Branch + Event + ShiftType dropdowns
- [x] **Tag-input widget** for skills
- [x] **Summary widgets** above grid (4 KPI cards)
- [x] **Grid aggregation columns** (AssignedCount, ComputedStatus — computed server-side, displayed client-side)
- [x] **Service placeholder buttons** with toast (Auto-Schedule, Remind, Notify)
- [x] Calendar navigation (prev/next, Day/Week/Month toggle) — date-range driven query

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **CRITICAL**: This is a non-standard FLOW. See §⑫ for layout deviations from standard `view-page.tsx`.

### Grid/List View — Dual Mode

**Display Mode**: `table` (default for List view) + `custom-calendar` (for Calendar view)
**Grid Layout Variant**: `widgets-above-grid` (4 summary widgets above the view toggle + grid)

**View Toggle** (top-right of ScreenHeader):
- `[Calendar View]` (default, active) | `[List View]`
- Persisted in Zustand (`viewMode: 'calendar' | 'list'`)

---

#### View 1: Calendar Grid (default)

**Layout**: CSS grid `70px + repeat(7, 1fr)` — time labels column + 7 day columns
**Time rows**: 8 AM → 6 PM (11 rows, 60px height each)
**Date range**: Driven by `currentWeekStart` Zustand state (default: today's week)
**Navigation**:
- `[◄]` prev week button, `[Apr 7 – 13, 2026]` label, `[►]` next week button (top-left of calendar card)
- `[Day] [Week] [Month]` toggle (top-right of calendar card) — Week is default

**Shift Block Rendering**:
- A shift occupies its time slots in the matching day column (merged cells via absolute positioning if multi-hour)
- Colored by `shiftTypeCode`:
  - Event → `#dcfce7` bg, `#22c55e` left border
  - Office / Training → `#dbeafe` bg, `#3b82f6` left border
  - Field → `#ffedd5` bg, `#f97316` left border
  - Remote → `#f3e8ff` bg, `#a855f7` left border
- Content: Shift name (ellipsis) + `{AssignedCount}/{VolunteersNeeded} vols` subtext
- Click → opens Side Drawer (Zustand: `openDrawer(shiftId)`)
- Empty cells: click to pre-populate Create Modal with clicked date+time (optional enhancement — mockup shows hover but no click-to-create)

**Color Legend** (bottom of calendar card): Event / Office / Field / Remote

**GQL query**: `GetVolunteerShiftsByDateRange(dateFrom, dateTo, branchId?, typeId?)`

---

#### View 2: List Table

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Date | shiftDate | date (MMM DD) | 100px | YES | — |
| 2 | Shift | title | text-bold | auto | YES | Primary column |
| 3 | Time | — | custom (`{startTime} – {endTime}`) | 130px | NO | Combined display |
| 4 | Location | location | text | 200px | YES | — |
| 5 | Type | shiftTypeName | badge (colored) | 100px | YES | Badge color matches calendar |
| 6 | Needed | volunteersNeeded | number | 80px | YES | — |
| 7 | Assigned | — | custom (`{assignedCount}/{volunteersNeeded}`) | 100px | NO | Computed |
| 8 | Status | computedStatus | badge | 130px | YES | Understaffed/FullyStaffed/Critical |
| 9 | Actions | — | action-button | 100px | NO | [Manage] → opens drawer |

**Search Field**: `title` (text search), debounced 300ms
**Filter**: `shiftType` dropdown (All Types / Event / Office / Field / Remote / Training)
**Toolbar actions**: None additional (Create Shift + Auto-Schedule live in ScreenHeader)

**Row Click**: Opens Side Drawer (Zustand: `openDrawer(shiftId)`) — equivalent to Manage button

---

### Page Widgets & Summary Cards

**Widgets** (4 KPI cards, Variant B — above grid):

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Total Shifts | `summary.totalShifts` | number | Top-left |
| 2 | Understaffed | `summary.understaffedCount` | number (amber) | Top-center-left |
| 3 | Fully Staffed | `summary.fullyStaffedCount` | number (green) | Top-center-right |
| 4 | Total Assigned Volunteers | `summary.totalAssigned` | number | Top-right |

**Summary GQL Query**: `GetVolunteerShiftSummary(dateFrom?, dateTo?, branchId?)` → `VolunteerShiftSummaryDto`

**Detection cue**: Widgets exist → `widgets-above-grid` variant → use `<ScreenHeader>` + widgets + `<FlowDataTableContainer showHeader={false}>`.

### Grid Aggregation Columns (per-row)

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Assigned | `{assignedCount}/{volunteersNeeded}` | COUNT(Assignments WHERE Status != Cancelled) | LINQ subquery in GetAll |
| Status | Computed badge | Derived from AssignedCount vs Needed | LINQ `Select(s => new { ..., ComputedStatus = ... })` |

---

### Create / Edit Modal (replaces ?mode=new and ?mode=edit)

> **Non-standard**: This FLOW uses a **modal** instead of a `?mode=new` / `?mode=edit` full page.
> The modal lives in `index-page.tsx` and is controlled by Zustand (`modalOpen`, `modalRecordId`).
> URL does NOT change — this is a pure modal flow.

**Modal Size**: 560px width, max-height 90vh, scrollable body
**Modal Header**: `[+] Create Shift` or `[✎] Edit Shift: {title}` + close button
**Section Container Type**: Flat form (no sections/accordion — mockup form is compact)

**Form Fields** (in display order):
| # | Field | Type | Widget | Required | Notes |
|---|-------|------|--------|----------|-------|
| 1 | Shift Name | text | Input | YES | "e.g. Ramadan Food Pack Distribution" |
| 2 | Date | date | DatePicker | YES | Default: today |
| 3 | Start Time | time | TimePicker | YES | HH:mm |
| 4 | End Time | time | TimePicker | YES | Must > StartTime |
| 5 | Type | dropdown | ApiSelectV2 (MasterData ShiftType) | YES | 5 seeded options |
| 6 | Branch | dropdown | ApiSelectV2 (GetBranches) | YES | — |
| 7 | Location | text | Input | NO | Free text |
| 8 | Linked Event | dropdown | ApiSelectV2 (GetEvents) | NO | Optional — placeholder "— Select Event —" |
| 9 | Volunteers Needed | number | NumberInput | YES | min 1 |
| 10 | Required Skills | tag-input | TagInputWidget | NO | Multi-value string tags — enter to add, × to remove |
| 11 | Description | textarea | Textarea | NO | min-height 60px, resize-vertical |
| 12 | Auto-Assign matching available volunteers | toggle | ToggleSwitch | NO | Default off |

**Footer Buttons**:
- `[Cancel]` → closes modal, warns if dirty
- `[+ Create & Assign]` → POST CreateVolunteerShift with `autoAssignOnCreate=true` → SERVICE_PLACEHOLDER toast "AI matching coming soon — created 0 pending assignments" + shift still created
- `[✓ Create Shift]` / `[✓ Update]` → POST CreateVolunteerShift or UpdateVolunteerShift with `autoAssignOnCreate=false`

**On Success**: modal closes, grid refreshes, summary widgets refetch.

---

### Detail Side Drawer (replaces ?mode=read)

> **Non-standard**: Read-only detail is a **side drawer** (480px, right-slide) — NOT a `?mode=read` full page.
> Drawer is mounted in `index-page.tsx` as sibling to grid + modal. Driven by Zustand (`drawerOpen`, `drawerShiftId`).
> URL does NOT change when drawer opens — matches In-Kind Donation #7 precedent.

**Drawer Dimensions**: 480px wide on desktop, 100vw on mobile (<992px). Slides from right, 0.3s transition, overlay 30% black behind.

**Drawer Header** (sticky, white bg, z-index 5):
- Left:
  - H3 title: `{shift.title}` (e.g., "Ramadan Food Pack Distribution")
  - Sub-line: `[🔗 Linked: {event.eventName}]` (only if `shift.eventId` is set)
- Right: `[×]` close button (also: overlay click, Escape key)

**Drawer Body Sections** (top to bottom):

#### 1. Detail Rows (key-value pairs)
| Label | Icon | Value |
|-------|------|-------|
| Date | fa-calendar | `Sat, Apr 12, 2026` (formatted) |
| Time | fa-clock | `8:00 AM – 12:00 PM (4 hours)` (computed duration) |
| Location | fa-location-dot | `{shift.location}` |
| Type | fa-tag | `{TypeBadge}` (colored) |

#### 2. Status Bar (3-segment)
| Segment | Color | Label | Value |
|---------|-------|-------|-------|
| Needed | `var(--accent)` #0e7490 | "Needed" | `{shift.volunteersNeeded}` |
| Assigned | `var(--volunteer-accent)` #059669 | "Assigned" | `{shift.assignedCount}` |
| Confirmed | `var(--success-color)` #22c55e | "Confirmed" | `{shift.confirmedCount}` |

Dividers (1px × 32px) between segments.

#### 3. Assigned Volunteers Table
**Heading**: `[👤✓] Assigned Volunteers`

Columns:
| Column | Content |
|--------|---------|
| Volunteer | Link → volunteer detail page (`/crm/volunteer/volunteerlist?mode=read&id={volunteerId}`) — deep link to #53 |
| Status | Badge: `✓ Confirmed` (green) / `📋 Pending` (amber) |
| Skills | Skill tags; `match` class (green) if volunteer has this skill, `no-match` (grey) otherwise |
| Actions | `[Remove]` (red outline) — always; `[Remind]` (amber outline) — only for Pending |

**Below table**: 2 bulk action buttons
- `[🔔 Remind All Pending]` → BulkRemindPending(shiftId) — SERVICE_PLACEHOLDER toast
- `[📤 Notify Available]` → BulkNotifyAvailable(shiftId) — SERVICE_PLACEHOLDER toast

#### 4. Available Volunteers Table
**Heading**: `[👤+] Available Volunteers`

Columns:
| Column | Content |
|--------|---------|
| Volunteer | Name (bold, no link — not yet assigned) |
| Skills | Match indicators (green checkmarks for shift skills the volunteer has) |
| Availability | `✓ Sat available` (green) — computed from volunteer availability |
| Distance | `{distanceKm} km` — computed from volunteer location vs shift location (SERVICE_PLACEHOLDER — use mock distance for now) |
| Actions | `[Assign]` (green outline) → AssignVolunteer mutation → row moves to Assigned table |

**GQL query**: `GetAvailableVolunteersForShift(volunteerShiftId)` → returns top 10 volunteers not yet assigned, ordered by skill-match desc (SERVICE_PLACEHOLDER — for now, return all active volunteers not in the shift's assignment list, sorted alphabetically)

**Drawer Data Fetching**: On drawer open, fire `GetVolunteerShiftById(shiftId)` + `GetAvailableVolunteersForShift(shiftId)` in parallel. Show drawer skeleton during load.

### User Interaction Flow

1. User lands on `/crm/volunteer/volunteerscheduling` → Calendar View (week) loads with this week's shifts colored by type.
2. User sees summary widgets (Total / Understaffed / Fully Staffed / Assigned) above the grid.
3. User clicks `[Calendar View / List View]` toggle → grid swaps without re-fetching (same data).
4. User clicks `[Create Shift]` in ScreenHeader → **Modal opens** (Create mode) → fills form → Save.
   - Create → success → modal closes + grid refreshes + widgets refetch.
   - Create & Assign → success + SERVICE_PLACEHOLDER toast "AI matching not wired — shift created with 0 assignments."
5. User clicks a shift block (calendar) or row (list) → **Side Drawer opens** with shift detail.
   - Drawer header shows title + linked event.
   - Status bar shows Needed/Assigned/Confirmed.
   - Assigned volunteers table: Remove (hard delete assignment), Remind (SERVICE_PLACEHOLDER).
   - Available volunteers table: Assign (creates Pending assignment → row moves up).
   - Bulk actions: Remind All Pending, Notify Available (both SERVICE_PLACEHOLDER).
6. User clicks `[Auto-Schedule]` in ScreenHeader → SERVICE_PLACEHOLDER toast "AI matching coming soon."
7. User navigates week (`◄` / `►`) → calendar + list both refetch with new date range.
8. User closes drawer → overlay dismissed, no URL change.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity (SavedFilter — FLOW + side-drawer) to VolunteerShift.

**Canonical Reference**: SavedFilter (FLOW — standard modes) + InKindDonation (FLOW — side-drawer variant)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | VolunteerShift | Entity/class name |
| savedFilter | volunteerShift | camelCase variable |
| SavedFilterId | VolunteerShiftId | PK field |
| SavedFilters | VolunteerShifts | Table name |
| saved-filter | volunteer-shift | kebab-case (only used in docs; FE folder uses `volunteershift`) |
| savedfilter | volunteershift | FE folder, import paths |
| SAVEDFILTER | VOLUNTEERSHIFT | Grid code (not the menu code — see §⑨) |
| notify | vol | DB schema |
| Notify | Vol | Backend group name prefix |
| NotifyModels | VolModels | Namespace suffix (Base.Domain/Models/VolModels/...) |
| NOTIFICATIONSETUP | CRM_VOLUNTEER | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/volunteer/volunteerscheduling | FE route path |
| notify-service | vol-service | FE service folder |

**FE menu URL segment** (the screen's URL-friendly slug): `volunteerscheduling` (matches existing FE stub folder).
**Menu display name**: `Scheduling` (under Volunteer parent).

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (~22 files — main entity + 2 children + custom queries/mutations)

**VolunteerShift (main) — 11 standard files**

| # | File | Path |
|---|------|------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/VolModels/VolunteerShift.cs` |
| 2 | EF Config | `.../Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerShiftConfiguration.cs` |
| 3 | Schemas (DTOs) | `.../Base.Application/Schemas/VolSchemas/VolunteerShiftSchemas.cs` |
| 4 | Create Command | `.../Base.Application/Business/VolBusiness/VolunteerShifts/CreateCommand/CreateVolunteerShift.cs` |
| 5 | Update Command | `.../Base.Application/Business/VolBusiness/VolunteerShifts/UpdateCommand/UpdateVolunteerShift.cs` |
| 6 | Delete Command | `.../Base.Application/Business/VolBusiness/VolunteerShifts/DeleteCommand/DeleteVolunteerShift.cs` |
| 7 | Toggle Command | `.../Base.Application/Business/VolBusiness/VolunteerShifts/ToggleCommand/ToggleVolunteerShift.cs` |
| 8 | GetAll Query | `.../Base.Application/Business/VolBusiness/VolunteerShifts/GetAllQuery/GetAllVolunteerShift.cs` |
| 9 | GetById Query | `.../Base.Application/Business/VolBusiness/VolunteerShifts/GetByIdQuery/GetVolunteerShiftById.cs` |
| 10 | Mutations endpoint | `.../Base.API/EndPoints/Vol/Mutations/VolunteerShiftMutations.cs` |
| 11 | Queries endpoint | `.../Base.API/EndPoints/Vol/Queries/VolunteerShiftQueries.cs` |

**VolunteerShiftSkill (child) — embedded in parent commands; no separate CRUD**
(Child rows managed via parent Create/Update — no independent endpoints.)

**VolunteerShiftAssignment (child with independent actions) — 7 files**

| # | File | Path |
|---|------|------|
| 12 | Entity | `.../Base.Domain/Models/VolModels/VolunteerShiftAssignment.cs` |
| 13 | EF Config | `.../Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerShiftAssignmentConfiguration.cs` |
| 14 | Schemas | (reuse `VolunteerShiftSchemas.cs` or split into `VolunteerShiftAssignmentSchemas.cs`) |
| 15 | Entity (Child Skill) | `.../Base.Domain/Models/VolModels/VolunteerShiftSkill.cs` |
| 16 | EF Config (Skill) | `.../Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerShiftSkillConfiguration.cs` |

**Custom Commands (assignment workflow) — 4 files**

| # | File | Path |
|---|------|------|
| 17 | AssignVolunteer | `.../Base.Application/Business/VolBusiness/VolunteerShifts/AssignVolunteerCommand/AssignVolunteer.cs` |
| 18 | ConfirmAssignment | `.../Base.Application/Business/VolBusiness/VolunteerShifts/ConfirmAssignmentCommand/ConfirmAssignment.cs` |
| 19 | RemoveAssignment | `.../Base.Application/Business/VolBusiness/VolunteerShifts/RemoveAssignmentCommand/RemoveAssignment.cs` |
| 20 | RemindAssignment (SERVICE_PLACEHOLDER) | `.../Base.Application/Business/VolBusiness/VolunteerShifts/RemindAssignmentCommand/RemindAssignment.cs` |

**Custom Queries — 3 files**

| # | File | Path |
|---|------|------|
| 21 | GetVolunteerShiftsByDateRange | `.../Base.Application/Business/VolBusiness/VolunteerShifts/GetByDateRangeQuery/GetVolunteerShiftsByDateRange.cs` |
| 22 | GetAvailableVolunteersForShift | `.../Base.Application/Business/VolBusiness/VolunteerShifts/GetAvailableVolunteersQuery/GetAvailableVolunteersForShift.cs` |
| 23 | GetVolunteerShiftSummary | `.../Base.Application/Business/VolBusiness/VolunteerShifts/GetSummaryQuery/GetVolunteerShiftSummary.cs` |

### Backend Wiring Updates (vol module is NEW — extra work)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Data/Persistence/IVolDbContext.cs` | **CREATE** new interface with DbSet<VolunteerShift>, DbSet<VolunteerShiftAssignment>, DbSet<VolunteerShiftSkill> (and eventually DbSet<Volunteer>) |
| 2 | `Base.Infrastructure/Data/Persistence/VolDbContext.cs` | **CREATE** new DbContext |
| 3 | `Base.Application/Data/Persistence/IApplicationDbContext.cs` | Add `IVolDbContext` to multiple-inheritance |
| 4 | `Base.Application/Mappings/VolMappings.cs` | **CREATE** Mapster config class with `ConfigureMappings()` method |
| 5 | `Base.Application/DependencyInjection.cs` | Register `VolMappings.ConfigureMappings()` |
| 6 | `Base.Application/DecoratorProperties.cs` | Add `DecoratorVolModules` class |
| 7 | `GlobalUsing.cs` (3 files — API, Application, Infrastructure) | Add `global using Base.Domain.Models.VolModels;` |
| 8 | `VolunteerShiftMutations.cs` + `VolunteerShiftQueries.cs` | Register in `Base.API/Program.cs` via reflection or endpoint map |

### Frontend Files (~12 files — non-standard FLOW: no view-page.tsx, extra drawer + modal + calendar)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/vol-service/VolunteerShiftDto.ts` |
| 2 | GQL Queries | `.../infrastructure/gql-queries/vol-queries/VolunteerShiftQuery.ts` |
| 3 | GQL Mutations | `.../infrastructure/gql-mutations/vol-mutations/VolunteerShiftMutation.ts` |
| 4 | Page Config | `.../presentation/pages/crm/volunteer/volunteerscheduling.tsx` |
| 5 | Index entry | `.../presentation/components/page-components/crm/volunteer/volunteerscheduling/index.tsx` |
| 6 | Index Page (hosts all) | `.../presentation/components/page-components/crm/volunteer/volunteerscheduling/index-page.tsx` |
| 7 | **Calendar View component** | `.../presentation/components/page-components/crm/volunteer/volunteerscheduling/calendar-view.tsx` |
| 8 | **Create/Edit Shift Modal** | `.../presentation/components/page-components/crm/volunteer/volunteerscheduling/shift-form-modal.tsx` |
| 9 | **Side Drawer** | `.../presentation/components/page-components/crm/volunteer/volunteerscheduling/shift-detail-drawer.tsx` |
| 10 | **Zustand Store** | `.../presentation/components/page-components/crm/volunteer/volunteerscheduling/volunteershift-store.ts` |
| 11 | Route Page | `.../app/[lang]/crm/volunteer/volunteerscheduling/page.tsx` *(rewrite existing stub)* |
| 12 | Shared UI bits | Inline in above files — or `.../volunteerscheduling/components/` for: status-bar, skill-tag, assigned-volunteer-row, available-volunteer-row |

**NO `view-page.tsx`** — confirmed deviation from standard FLOW template.
**NO separate `index-page.tsx` + `view-page.tsx`** — `index-page.tsx` hosts calendar/list/modal/drawer.

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `entity-operations.ts` | `VOLUNTEERSHIFT` operations config |
| 2 | `operations-config.ts` | Import + register |
| 3 | Sidebar menu config (seed-driven via DB; no code change if seed is correct) | Menu entry: Scheduling under Volunteer |
| 4 | Route config (Next.js auto-discovers, no change needed) | — |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Scheduling
MenuCode: VOLUNTEERSCHEDULING
ParentMenu: CRM_VOLUNTEER
Module: CRM
MenuUrl: crm/volunteer/volunteerscheduling
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: VOLUNTEERSHIFT

MasterDataSeeds:
  TypeCode: SHIFTTYPE
  TypeName: "Shift Type"
  Values:
    - EVENT: Event
    - OFFICE: Office
    - FIELD: Field
    - REMOTE: Remote
    - TRAINING: Training
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `VolunteerShiftQueries`
- Mutation type: `VolunteerShiftMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `GetAllVolunteerShiftList` | `[VolunteerShiftResponseDto]` | searchText, pageNo, pageSize, sortField, sortDir, isActive, dateFrom, dateTo, shiftTypeId, branchId, status (computed filter) |
| `GetVolunteerShiftById` | `VolunteerShiftResponseDto` | volunteerShiftId |
| `GetVolunteerShiftsByDateRange` | `[VolunteerShiftResponseDto]` | dateFrom, dateTo, branchId?, shiftTypeId? (used by Calendar view — no pagination) |
| `GetAvailableVolunteersForShift` | `[AvailableVolunteerDto]` | volunteerShiftId (returns top 10; SERVICE_PLACEHOLDER for ranking) |
| `GetVolunteerShiftSummary` | `VolunteerShiftSummaryDto` | dateFrom?, dateTo?, branchId? |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `CreateVolunteerShift` | `VolunteerShiftRequestDto` (with skills[] + autoAssignOnCreate) | `int` (new VolunteerShiftId) |
| `UpdateVolunteerShift` | `VolunteerShiftRequestDto` | `int` |
| `DeleteVolunteerShift` | `volunteerShiftId` | `int` |
| `ToggleVolunteerShift` | `volunteerShiftId` | `int` |
| `AssignVolunteer` | `{volunteerShiftId, volunteerId, notes?}` | `int` (new VolunteerShiftAssignmentId) |
| `ConfirmAssignment` | `volunteerShiftAssignmentId` | `int` |
| `RemoveAssignment` | `volunteerShiftAssignmentId` | `int` (hard delete) |
| `RemindAssignment` | `volunteerShiftAssignmentId` | `int` (stamps ReminderSentAt, SERVICE_PLACEHOLDER — no actual dispatch) |
| `BulkRemindPending` | `volunteerShiftId` | `int` (count of reminders stamped, SERVICE_PLACEHOLDER) |
| `BulkNotifyAvailable` | `volunteerShiftId` | `int` (count notified, SERVICE_PLACEHOLDER) |

**Response DTO Fields — VolunteerShiftResponseDto:**
| Field | Type | Notes |
|-------|------|-------|
| volunteerShiftId | number | PK |
| shiftCode | string | Auto-gen |
| title | string | — |
| shiftDate | string (ISO date) | — |
| startTime | string (HH:mm) | — |
| endTime | string (HH:mm) | — |
| shiftTypeId | number | FK |
| shiftTypeName | string | FK display (from MasterData) |
| shiftTypeCode | string | For color mapping: EVENT/OFFICE/FIELD/REMOTE/TRAINING |
| branchId | number | FK |
| branchName | string | FK display |
| location | string \| null | — |
| eventId | number \| null | Optional FK |
| eventName | string \| null | FK display |
| volunteersNeeded | number | — |
| description | string \| null | — |
| autoAssignOnCreate | boolean | — |
| assignedCount | number | Computed |
| confirmedCount | number | Computed |
| pendingCount | number | Computed |
| computedStatus | string | 'Critical' / 'Understaffed' / 'FullyStaffed' |
| skills | `string[]` | From VolunteerShiftSkills |
| assignments | `VolunteerShiftAssignmentDto[]` | Children (only populated on GetById, not GetAll) |
| isActive | boolean | Inherited |

**Response DTO — VolunteerShiftAssignmentDto:**
| Field | Type | Notes |
|-------|------|-------|
| volunteerShiftAssignmentId | number | PK |
| volunteerId | number | FK |
| volunteerName | string | Deep link to #53 volunteer detail |
| volunteerSkills | `string[]` | For skill-match overlay vs shift.skills |
| assignmentStatus | string | 'Pending' / 'Confirmed' / 'Cancelled' |
| assignedAt | string (ISO datetime) | — |
| confirmedAt | string \| null | — |
| reminderSentAt | string \| null | — |

**Response DTO — AvailableVolunteerDto:**
| Field | Type | Notes |
|-------|------|-------|
| volunteerId | number | — |
| volunteerName | string | — |
| skills | `string[]` | For skill-match overlay |
| availability | string | e.g., "Sat available" — SERVICE_PLACEHOLDER (return "Available" if volunteer active) |
| distanceKm | number | SERVICE_PLACEHOLDER (return random 1–15 or 0) |

**Response DTO — VolunteerShiftSummaryDto:**
| Field | Type | Notes |
|-------|------|-------|
| totalShifts | number | Count in date range |
| understaffedCount | number | `WHERE AssignedCount < VolunteersNeeded` |
| fullyStaffedCount | number | `WHERE AssignedCount >= VolunteersNeeded` |
| totalAssigned | number | Sum of AssignedCount across shifts |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (new `vol` schema module compiles)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/volunteer/volunteerscheduling`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Calendar View renders weekly grid (8AM–6PM × 7 days) — default on load
- [ ] Shift blocks render with correct background color by `shiftTypeCode`
- [ ] `{assignedCount}/{volunteersNeeded} vols` text shows on each block
- [ ] Week navigation prev/next works — grid refetches via `GetVolunteerShiftsByDateRange`
- [ ] Day/Week/Month toggle switches date range (Month = 30-day window, Day = single day)
- [ ] List View toggle swaps UI to table with 9 columns
- [ ] Search filters by `title`; Type filter dropdown filters by `shiftTypeId`
- [ ] Status badge colors match mockup (Understaffed = amber, FullyStaffed = green, Critical = red)
- [ ] `[Create Shift]` button opens MODAL with 12 fields; Save creates + closes + refreshes grid + widgets
- [ ] `[Create & Assign]` button — creates shift + shows SERVICE_PLACEHOLDER toast
- [ ] Skills tag-input widget: type-to-add (Enter key), × to remove chip
- [ ] Auto-Assign toggle in modal flips to on — persisted on create
- [ ] Row / block click opens SIDE DRAWER (480px right-slide, overlay darkens grid)
- [ ] Drawer header: title + (optional) "Linked: {eventName}" sub-line
- [ ] Detail rows (Date, Time with duration, Location, Type badge) render correctly
- [ ] Status bar: 3 segments (Needed / Assigned / Confirmed) with dividers
- [ ] Assigned Volunteers table: rows with Confirmed/Pending badges, skill-match chips
- [ ] Volunteer name is deep link to `/crm/volunteer/volunteerlist?mode=read&id={volunteerId}`
- [ ] `[Remove]` action deletes assignment, row disappears, AssignedCount recalcs
- [ ] `[Remind]` on Pending row — SERVICE_PLACEHOLDER toast + stamp ReminderSentAt
- [ ] Available Volunteers table: rows with skills + distance + Assign button
- [ ] `[Assign]` creates Pending assignment, moves row to Assigned table, recalcs counts
- [ ] `[Remind All Pending]` / `[Notify Available]` bulk buttons — SERVICE_PLACEHOLDER toasts
- [ ] Drawer close via X / overlay click / Escape key
- [ ] Summary widgets (4 KPIs) refetch after any mutation
- [ ] `[Auto-Schedule]` ScreenHeader button — SERVICE_PLACEHOLDER toast
- [ ] No URL changes during modal / drawer lifecycle (pure Zustand state)
- [ ] Permissions: role-based (BUSINESSADMIN only in seed)

**DB Seed Verification:**
- [ ] Menu "Scheduling" appears in sidebar under "Volunteer"
- [ ] 5 ShiftType MasterData rows seeded (EVENT/OFFICE/FIELD/REMOTE/TRAINING)
- [ ] GridColumns seeded for list view (9 columns)
- [ ] GridFormSchema: SKIP (FLOW — no form schema)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### ⚠ Dependency Blockers

- **HARD BLOCKER — Volunteer entity (#53) does NOT exist yet** (registry row #53 is PARTIAL). The `VolunteerShiftAssignment.VolunteerId` FK cannot be validated without the `vol.Volunteers` table. **Recommendation: Build #53 Volunteer FIRST**, then #54 Volunteer Schedule. If #54 is built first, the Volunteer entity + vol schema + VolDbContext + VolMappings must be created as part of #54 — and #53 becomes an "extend the vol schema" job. See **ISSUE-1** below.
- **`vol` schema module is NEW** — the first screen to land in `vol` schema must create: `IVolDbContext`, `VolDbContext`, `VolMappings`, `DecoratorVolModules`, 3× GlobalUsing updates, and `IApplicationDbContext` multiple-inheritance update. (Standard new-module playbook — see DEPENDENCY-ORDER.md lines 98–109.)

### ⚠ Non-Standard FLOW Layout

- **NO `view-page.tsx`** — this FLOW uses modal (Create/Edit) + side drawer (Detail). The `?mode=new/edit/read` URL pattern is NOT used. Everything lives on `index-page.tsx`. **Direct precedent: In-Kind Donation #7 — follow that architecture.**
- **Zustand store drives both modal and drawer** — `modalOpen`, `modalRecordId` (null=create, number=edit), `drawerOpen`, `drawerShiftId`, `viewMode ('calendar'|'list')`, `currentWeekStart`, `rangeMode ('day'|'week'|'month')`, `branchFilter`, `typeFilter`.
- **Calendar view is custom** — not a standard DataTable. Build as a CSS-grid component (`calendar-view.tsx`) that accepts shift list + week start and renders blocks in the correct day/time cells.
- **Status is COMPUTED server-side via LINQ subquery** — DO NOT store `Status` on the entity. The GetAll projection must include:
  ```csharp
  AssignedCount = s.Assignments.Count(a => a.AssignmentStatus != "Cancelled"),
  ComputedStatus = AssignedCount == 0 ? "Critical" : AssignedCount < s.VolunteersNeeded ? "Understaffed" : "FullyStaffed"
  ```

### ⚠ Menu URL Alignment

- Existing FE route folder is `volunteerscheduling` (one word, no dash/camelCase) — see `PSS_2.0_Frontend/src/app/[lang]/crm/volunteer/volunteerscheduling/page.tsx`. Use this exact slug in the DB seed MenuUrl to match the existing stub location.
- **Menu display name**: `Scheduling` (short — matches sibling menu items like "Volunteer List", "Hour Tracking" under CRM_VOLUNTEER).

### ⚠ Seeded ShiftType MasterData

- ShiftTypeId is FK to generic `MasterData` table (see `Base.Domain/Models/AppModels/MasterData.cs` + `MasterDataType.cs`). Add 5 seed rows with TypeCode = `SHIFTTYPE`:
  - EVENT (Event)
  - OFFICE (Office)
  - FIELD (Field)
  - REMOTE (Remote)
  - TRAINING (Training)
- The FE uses `ShiftTypeCode` (not Id) for color mapping — include `shiftTypeCode` in the response DTO projection.

### ⚠ Skills Model — Simple Strings For Now

- Skills are stored as free-text strings in `VolunteerShiftSkills` child (no SkillMaster FK). The mockup's tag-input allows arbitrary entries. If #53 Volunteer adds a proper `vol.VolunteerSkills` master table, migrate at that time.
- Skill-match rendering on FE compares `shift.skills` (string[]) vs `volunteer.skills` (string[]) with case-insensitive equality.

### Service Dependencies (UI-only — placeholder handlers)

Full UI must be built for every item below. The handler is wired to a toast; the backend mutation stamps a timestamp or returns a stub count.

- **⚠ SERVICE_PLACEHOLDER: `Auto-Schedule` (ScreenHeader button)** — full UI implemented as a button that opens a confirmation dialog "Auto-assign matching volunteers to all understaffed shifts?". On confirm → toast "AI matching engine coming soon. No assignments created." No backend mutation needed for now (or stub that returns 0).
- **⚠ SERVICE_PLACEHOLDER: `RemindAssignment` mutation** — stamps `ReminderSentAt = now`; FE shows toast "Reminder queued (notification service not wired)". Actual SMS/email dispatch deferred until Notification dispatcher service lands.
- **⚠ SERVICE_PLACEHOLDER: `BulkRemindPending` + `BulkNotifyAvailable`** — same as above, batch version. Stamps timestamps, no dispatch.
- **⚠ SERVICE_PLACEHOLDER: `GetAvailableVolunteersForShift` ranking** — the query returns the list but scoring/ranking (distance, skill-match score, availability) is mocked. Simple `WHERE volunteer.IsActive AND volunteer.id NOT IN shift.assignments` for now, sorted alphabetically. Distance returned as 0 or random small int.
- **⚠ SERVICE_PLACEHOLDER: `Create & Assign` button in modal** — creates shift with `autoAssignOnCreate=true`. The Create handler checks the flag but does not perform actual matching — returns shift ID + toast warning user "AI matching coming soon — assign volunteers manually via side drawer".

Everything else in the mockup — calendar grid, list table, view toggle, modal form, side drawer with 2 volunteer tables, Assign/Remove actions, status badges, skill-match chips, summary widgets, date navigation — is IN SCOPE and must be fully functional end-to-end.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning (2026-04-21) | **BLOCKER** | Dependencies | Volunteer entity (#53) does not exist. `VolunteerShiftAssignment.VolunteerId` FK target missing. Must build #53 first OR create Volunteer entity + vol schema infra as part of #54. | OPEN |
| ISSUE-2 | Planning (2026-04-21) | Medium | Module Infra | `vol` schema + `VolDbContext` + `VolMappings` must be created if #54 is built before #53. Follows the standard new-module playbook (Case/Mem/Grant precedents). | OPEN |
| ISSUE-3 | Planning (2026-04-21) | Medium | UX deviation | Non-standard FLOW: modal create/edit + side drawer detail — NO `view-page.tsx`, NO `?mode=new/edit/read` URLs. Follow In-Kind Donation #7 precedent. | OPEN — intentional design |
| ISSUE-4 | Planning (2026-04-21) | Low | Service | Auto-Schedule AI matching is SERVICE_PLACEHOLDER — button is built, handler toasts, no backend implementation. | OPEN — by design |
| ISSUE-5 | Planning (2026-04-21) | Low | Service | Remind / Notify actions stamp timestamps but do not dispatch notifications. Will activate when notification dispatcher lands. | OPEN — by design |
| ISSUE-6 | Planning (2026-04-21) | Low | Data model | `Status` is COMPUTED (not stored) via LINQ subquery. Do not add Status column to entity. | OPEN — design guideline |
| ISSUE-7 | Planning (2026-04-21) | Low | Data model | Skills are free-text strings in `VolunteerShiftSkills` — no SkillMaster FK yet. Migrate to FK when #53 adds `vol.VolunteerSkills`. | OPEN — future migration |
| ISSUE-8 | Planning (2026-04-21) | Low | UX | Calendar cells support shift-block click (→ drawer). Empty cell click-to-prefill-modal is NOT in mockup — OUT OF SCOPE. | OPEN — out of scope |
| ISSUE-9 | Build Session 1 (2026-04-24) | **HIGH** | Migration | EF migration not generated per token-budget directive. Must run `dotnet ef migrations add AddVolunteerShiftModule -p Base.Infrastructure -s Base.API -c ApplicationDbContext` before deploy. | OPEN |
| ISSUE-10 | Build Session 1 (2026-04-24) | **HIGH** | Verification | Backend `dotnet build` + frontend `pnpm dev` + full E2E acceptance checklist skipped per session directive. Must run before marking production-ready. | OPEN |
| ISSUE-1 | Planning (2026-04-21) | — | Dependencies | Volunteer entity (#53) does not exist. | **CLOSED** 2026-04-24 — #53 built. |
| ISSUE-2 | Planning (2026-04-21) | — | Module Infra | `vol` schema + VolDbContext bootstrap. | **CLOSED** 2026-04-24 — superseded by `app`-schema decision (no new schema needed). |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-24 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Schema revised to existing `app` (mirroring #53) — no new `vol` schema bootstrap.
- **Files touched**:
  - BE (created): VolunteerShift.cs, VolunteerShiftSkill.cs, VolunteerShiftAssignment.cs (entities); 3× EF Configurations under ApplicationConfigurations/; VolunteerShiftSchemas.cs; 8 commands (Create/Update/Delete/Toggle + AssignVolunteer/ConfirmAssignment/RemoveAssignment/RemindAssignment + BulkRemindPending/BulkNotifyAvailable/AutoScheduleShift); 5 queries (GetAll/GetById/GetByDateRange/GetAvailableVolunteers/GetSummary); VolunteerShiftMutations.cs + VolunteerShiftQueries.cs endpoints
  - BE (modified): IApplicationDbContext (3 DbSets), ApplicationDbContext (3 DbSet impls + 3 config applies), DecoratorProperties → DecoratorApplicationModules (3 entries; child Skill renamed to `VolunteerShiftSkillEntity` to avoid existing `VolunteerSkill` name collision), VolunteerMappings (appended VolunteerShift mapster configs)
  - FE (created): VolunteerShiftDto.ts, VolunteerShiftQuery.ts, VolunteerShiftMutation.ts, volunteerscheduling.tsx (page config), volunteerscheduling/{index, index-page, calendar-view, shift-form-modal, shift-detail-drawer, volunteershift-store}.tsx
  - FE (modified): volunteer-service/index.ts barrel, volunteer-queries/index.ts barrel, volunteer-mutations/index.ts barrel, presentation/pages/crm/volunteer/index.ts (export added), volunteer-service-entity-operations.ts (VOLUNTEERSHIFT registered), app/[lang]/crm/volunteer/volunteerscheduling/page.tsx (stub overwritten)
  - DB: sql-scripts-dyanmic/VolunteerSchedule-sqlscripts.sql (created)
- **Deviations from spec**: (a) Schema = `app` (existing) instead of new `vol`, mirroring #53's mid-build revision — eliminates IVolDbContext/VolDbContext/VolMappings/DecoratorVolModules bootstrap. (b) FE folder names = `volunteer-service` / `volunteer-queries` / `volunteer-mutations` (matching #53), not `vol-*`. (c) Decorator constant for child skill renamed to `VolunteerShiftSkillEntity` to avoid collision with existing `VolunteerSkill` constant.
- **Known issues opened**: ISSUE-9 (EF migration not generated per token-budget directive — must run `dotnet ef migrations add AddVolunteerShiftModule` before deploy), ISSUE-10 (BE compilation + full E2E checklist skipped per session directive — must run before production-ready)
- **Known issues closed**: ISSUE-1 (Volunteer #53 dep — now built), ISSUE-2 (`vol` schema bootstrap — superseded by app-schema decision)
- **Next step**: empty for COMPLETED