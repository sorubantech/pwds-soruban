---
screen: VolunteerHourLog
registry_id: 55
module: Volunteer (CRM)
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: YES — vol schema (FIRST-or-SECOND entity after #53 Volunteer)
planned_date: 2026-04-21
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + 4 KPI widgets + filter bar + bulk-actions + collapsible "Volunteer Hours Summary" aggregate panel + Log Hours modal → converted to FLOW `?mode=new` full page + `?mode=read` side-drawer DETAIL per FLOW convention)
- [x] Existing code reviewed (FE: 5-line stub `<div>Need to Develop</div>` at `crm/volunteer/volunteerhourtracking/page.tsx`; BE: NO Volunteer entity, NO VolunteerHourLog entity, NO `vol` schema → NEW module)
- [x] Business rules + workflow extracted (3-state Pending → Approved | Rejected; Approve/Reject guards Pending-only; bulk ops; LogAndApprove convenience; Date ≤ today; Hours > 0 in 0.5 steps; RejectionReason mandatory)
- [x] FK targets resolved (Volunteer + VolunteerSchedule both pending dependencies; MasterData × 2 new typeCodes; Branch + User exist)
- [x] File manifest computed (~12 BE files + module-bootstrap shared with #53 Volunteer; ~18 FE files; DB seed with 2 new MasterData types + menu + grid)
- [x] Approval config pre-filled (VOLUNTEERHOURTRACKING under CRM_VOLUNTEER at OrderBy=4, MenuUrl=`crm/volunteer/volunteerhourtracking`)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM sections + DETAIL drawer + 4 KPI widgets + aggregate panel + 3 transition mutations specified)
- [ ] User Approval received
- [ ] Backend code generated (VolunteerHourLog entity + Create/Update/Delete/Approve/Reject/BulkApprove/BulkReject/LogAndApprove + GetAll/GetById/GetSummary/GetAggregateByVolunteer queries + migration)
- [ ] Backend wiring complete (IVolDbContext if not already created by #53; VolDbContext; VolMappings; DecoratorVolModules; GlobalUsing × 3; IApplicationDbContext inheritance; DependencyInjection × 2)
- [ ] Frontend code generated (view-page 3 modes + Zustand store + side-drawer DETAIL + 4 KPI widgets + collapsible aggregate-by-volunteer panel + 4 filter dropdowns + 4 status chips + bulk-actions-bar + Log+Approve action in form footer + 3 new cell renderers)
- [ ] Frontend wiring complete (entity-operations, component-column × 3 registries, shared-cell-renderers barrel, sidebar menu, route stub overwrite)
- [ ] DB Seed script generated (Menu + Grid FLOW + 8 FLOW columns; GridFormSchema SKIP; VOLUNTEERACTIVITYTYPE + VOLUNTEERHOURSTATUS MasterData seeds)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (new VolunteerHourLog entity + migration applied — depends on Volunteer entity from #53 being built and applied first)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/volunteer/volunteerhourtracking`
- [ ] 4 KPI widgets render: Total Hours (Period) with volunteer count subtitle; Pending Approval count + total pending hours subtitle; Avg Hours/Volunteer with MoM% delta; Top Contributor name + hours
- [ ] Filter bar renders: Period dropdown (ThisMonth/LastMonth/ThisQuarter/Custom), Volunteer ApiSelect, 4 status chips (All/Pending/Approved/Rejected), Activity Type dropdown, Branch dropdown, Clear Filters link
- [ ] Grid loads with 8 columns: checkbox / Date / Volunteer (link) / Activity / Shift Link / Hours / Approved By / Status / Actions
- [ ] Bulk-actions bar appears when ≥ 1 row selected, shows "{N} selected", Approve Selected + Reject Selected buttons fire mutations
- [ ] Per-row actions render conditionally: Pending → Approve+Reject+Edit; Approved → Edit+More; Rejected → View Reason+More
- [ ] `?mode=new` — empty FORM renders (single card with sections matching mockup fields: Volunteer+Date+Hours top, Activity, Linked Shift, Start/End Time, Activity Type, Notes, Attachments upload)
- [ ] Form footer has 3 buttons: Cancel + Log & Approve (SERVICE_PLACEHOLDER-adjacent: creates + immediately approves) + Log Hours (creates as Pending)
- [ ] Save creates record → redirect to `?mode=read&id={newId}` → drawer opens
- [ ] `?mode=edit&id=X` — FORM pre-filled; Edit only allowed on Pending status (Approved/Rejected → toast "Cannot edit — unlock via admin")
- [ ] Row click → 520px right-side drawer slides in; URL syncs to `?mode=read&id=X`
- [ ] Drawer shows: Hour Log Summary (Date/Volunteer/Activity/Hours/Status badge), Shift Link (if present), Time Details (Start/End), Activity Type, Notes, Attachments list, Approval Trail (Pending OR Approved by+at OR Rejected by+at+reason)
- [ ] Drawer action buttons (conditional on status): Pending → Approve+Reject buttons; Approved → Edit+Delete; Rejected → View Reason prominent
- [ ] Approve mutation sets ApprovalStatusId=APP, ApprovedByUserId, ApprovedAt → drawer refreshes
- [ ] Reject mutation with inline RejectionReason input (mandatory, min 5 chars) sets ApprovalStatusId=REJ, RejectedByUserId, RejectedAt, RejectionReason → drawer refreshes
- [ ] BulkApprove + BulkReject mutations accept list of IDs, return {succeeded, failed, errors} tuple, refresh grid
- [ ] Collapsible "Volunteer Hours Summary" panel renders below main grid with aggregate table: Volunteer / Apr Hours / YTD Hours / Shifts / Avg per Shift / Approval Rate%
- [ ] Approval Rate displays green (≥100), amber (95–99), red (<95); colors via palette token
- [ ] FK dropdowns load via ApiSelectV2: Volunteer (typeahead), VolunteerSchedule (filtered by VolunteerId chosen), ActivityType (MasterData VOLUNTEERACTIVITYTYPE), Branch (static list)
- [ ] Shift Link column renders as link when VolunteerScheduleId present; else "Manual entry" placeholder text
- [ ] Unsaved changes dialog triggers on dirty FORM navigation
- [ ] DB Seed — menu visible in sidebar under CRM_VOLUNTEER at OrderBy=4; two MasterData type groups populated (VOLUNTEERACTIVITYTYPE × 5, VOLUNTEERHOURSTATUS × 3)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: VolunteerHourLog
Module: Volunteer (CRM)
Schema: vol
Group: VolModels

Business: **Hour Tracking** is the daily workbench for **logging, reviewing, and approving volunteer service hours**. Volunteer coordinators and branch managers use it to close the loop on every shift: a volunteer completed work (often after a scheduled `VolunteerSchedule` shift, sometimes ad-hoc), and their hours must be captured, reviewed, and approved before they count toward YTD totals, recognition milestones, and grant-reporting proofs of hours-delivered. Every row represents ONE log entry — a date + volunteer + activity + hours — with a 3-state lifecycle: **Pending → Approved | Rejected**. The screen sits under `CRM → Volunteer → Hour Tracking` alongside Volunteer List (#53), Register Volunteer, Scheduling (#54), and Donor Conversion, and its aggregate output (YTD hours, shifts completed, approval rate per volunteer) feeds the Volunteer Dashboard (#57). Unlike transactional donation screens, Hour Tracking's core UX is the **approval workflow**: coordinators batch-approve a day's shift logs in 2 clicks (multi-select + Approve Selected), inspect outliers (volunteer logged 12 hours?) and reject with a reason, and drill into a volunteer's full history via the collapsible "Volunteer Hours Summary" panel at the bottom of the page. The detail view opens as a 520px right-side drawer (row click → `?mode=read&id=X`) and presents the Approval Trail prominently — who approved/rejected, when, and why — because that trail is the audit evidence funders require for grant outcomes.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> ONE entity: `VolunteerHourLog` — single table, no child collections (attachments deferred as SERVICE_PLACEHOLDER — see ⑫).
> Audit columns (CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive) inherited from `Entity` base. CompanyId resolved from HttpContext on Create/Update (never sent by FE).

### Table: `vol."VolunteerHourLogs"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| VolunteerHourLogId | int | — | PK | — | Primary key |
| VolunteerHourLogCode | string | 50 | YES | — | Auto-gen `HRL-{00001}` (5-digit padded, per-Company sequence) on Create when empty; unique-filtered per Company |
| CompanyId | int | — | YES | app.Companies | Tenant scope (from HttpContext) |
| VolunteerId | int | — | YES | vol.Volunteers | Volunteer whose hours are being logged — HARD dependency on #53 Volunteer (see ⑫ ISSUE-1) |
| VolunteerScheduleId | int? | — | NO | vol.VolunteerSchedules | Optional shift link — HARD dependency on #54 Volunteer Schedule (see ⑫ ISSUE-2); when NULL, grid shows "Manual entry" |
| LogDate | DateOnly | — | YES | — | Date the hours were performed; must be ≤ today |
| Hours | decimal(6,2) | — | YES | — | Hours worked; > 0, increment 0.5, practical cap 24 |
| StartTime | TimeOnly? | — | NO | — | Optional start; if provided without EndTime → validation error |
| EndTime | TimeOnly? | — | NO | — | Optional end; if provided must be > StartTime (same-day assumption; overnight shifts out of scope MVP) |
| Activity | string | 200 | YES | — | Free-text activity label (e.g., "Food Pack Distribution", "Donor calls") |
| ActivityTypeId | int | — | YES | sett.MasterDatas (VOLUNTEERACTIVITYTYPE) | Event / Office / Field / Remote / Training |
| BranchId | int? | — | NO | app.Branches | Optional — usually derived from Volunteer.BranchId but persisted for historical correctness |
| Notes | string | 1000 | NO | — | Free-text note |
| AttachmentUrls | string | 2000 | NO | — | Comma-separated URLs (MVP) — see ⑫ ISSUE-3 file-upload infra gap |
| ApprovalStatusId | int | — | YES | sett.MasterDatas (VOLUNTEERHOURSTATUS) | PEN (Pending) default on Create; APP (Approved) / REJ (Rejected) set by workflow mutations |
| ApprovedByUserId | int? | — | NO | app.Users | Set on Approve mutation (current user) |
| ApprovedAt | DateTime? | — | NO | — | Set on Approve mutation |
| RejectedByUserId | int? | — | NO | app.Users | Set on Reject mutation |
| RejectedAt | DateTime? | — | NO | — | Set on Reject mutation |
| RejectionReason | string | 500 | NO | — | Mandatory when ApprovalStatusId = REJ (validator enforces); shown prominently in "View Reason" action |

**Computed/projected fields** (added in BE GetAll + GetById projections — NOT new columns):
- `volunteerName` — joined from Volunteer→Contact.DisplayName (or Volunteer.VolunteerName if entity exposes it)
- `volunteerCode` — Volunteer.VolunteerCode
- `volunteerAvatarColor` — hash of volunteerId → swatch palette (client-side or server-provided constant)
- `shiftLabel` — VolunteerSchedule join: `"Shift #{ScheduleCode} — {ShiftTitle}"` when ShiftId set; else null (FE renders "Manual entry")
- `activityTypeName`, `activityTypeCode` — MasterData join
- `approvalStatusName`, `approvalStatusCode`, `approvalStatusColorHex` — MasterData join (ColorHex from DataSetting JSON)
- `approvedByName` — User→Staff.StaffName (or User.UserName fallback)
- `rejectedByName` — same
- `branchName` — Branch join
- `durationDisplay` — client-renders `{Hours}h` or `{Hours.toFixed(1)}`

**Child Entities**: NONE in MVP. Attachments are stored as comma-separated URL string (AttachmentUrls) — promote to a child `VolunteerHourLogAttachment` table in a later iteration (see ⑫ ISSUE-3).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| VolunteerId | Volunteer | Base.Domain/Models/VolModels/Volunteer.cs ⚠ **NOT YET CREATED** (blocks build — see ⑫ ISSUE-1) | `getVolunteers` (from #53 VolunteerQueries) | VolunteerName (or Contact.DisplayName) | VolunteerResponseDto |
| VolunteerScheduleId | VolunteerSchedule | Base.Domain/Models/VolModels/VolunteerSchedule.cs ⚠ **NOT YET CREATED** (partial — see ⑫ ISSUE-2) | `getVolunteerSchedules` (from #54) | ShiftCode + ShiftTitle | VolunteerScheduleResponseDto |
| ActivityTypeId | MasterData (VOLUNTEERACTIVITYTYPE) | Base.Domain/Models/SettingModels/MasterData.cs | `getMasterDatas` with `typeCode=VOLUNTEERACTIVITYTYPE` filter | DataName | MasterDataResponseDto |
| ApprovalStatusId | MasterData (VOLUNTEERHOURSTATUS) | Base.Domain/Models/SettingModels/MasterData.cs | `getMasterDatas` with `typeCode=VOLUNTEERHOURSTATUS` filter | DataName (+ ColorHex from DataSetting JSON) | MasterDataResponseDto |
| BranchId | Branch | Base.Domain/Models/ApplicationModels/Branch.cs | `getBranches` | BranchName | BranchResponseDto |
| ApprovedByUserId | User | Base.Domain/Models/ApplicationModels/User.cs (exists) | — (use `getStaffs` with User→Staff join; display StaffName) | StaffName via User | StaffResponseDto |
| RejectedByUserId | User | Base.Domain/Models/ApplicationModels/User.cs (exists) | — (use `getStaffs` as above) | StaffName via User | StaffResponseDto |
| CompanyId | Company | Base.Domain/Models/ApplicationModels/Company.cs | — (from HttpContext, never queried) | — | — |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- VolunteerHourLogCode unique per Company (filtered-unique index)
- Soft duplicate-check: same VolunteerId + LogDate + Activity + StartTime already exists → warn (FE toast, BE does NOT block — see ⑫ ISSUE-4)

**Required Field Rules:**
- VolunteerId, LogDate, Hours, Activity, ActivityTypeId are mandatory on Create/Update
- ApprovalStatusId is always set (defaults to `PEN` on Create — never null)

**Conditional Rules:**
- If StartTime provided → EndTime required (and vice versa)
- If StartTime + EndTime provided → computed duration check: `abs((EndTime-StartTime).TotalHours - Hours) ≤ 1.0` → warn on mismatch (BE does NOT block — see ⑫ ISSUE-5)
- If ApprovalStatusId = `REJ` on any write path → RejectionReason required (min 5 chars)
- If ApprovalStatusId transitioning PEN → APP → ApprovedByUserId + ApprovedAt auto-set (server-side, never from FE)
- If ApprovalStatusId transitioning PEN → REJ → RejectedByUserId + RejectedAt + RejectionReason auto-set
- Edit command allowed only when current ApprovalStatusId = `PEN` (Approved/Rejected require admin unlock — out of MVP scope, see ⑫ ISSUE-6)
- Delete command allowed only when current ApprovalStatusId = `PEN` (hard-block on Approved/Rejected)

**Business Logic:**
- LogDate must be ≤ today (no future-dated logs); allow LogDate up to 90 days in the past (configurable per Company — hard-coded 90 for MVP, see ⑫ ISSUE-7)
- Hours must be > 0 and ≤ 24; step = 0.5 (half-hour increments matching mockup); reject `0`, `negative`, `> 24`
- VolunteerHourLogCode auto-generated `HRL-{NNNNN}` on Create when empty (handler reads MAX code per Company + 1; concurrency via retry-on-dup — same pattern as RefundCode in #13 Refund)
- On Approve: if Volunteer has a YTD-hours cached counter (future) → increment; for MVP, aggregates are computed on-read
- Verify Volunteer.IsActive = true before accepting a new log for that volunteer (validator check; warn-only for Edit if volunteer since deactivated — see ⑫ ISSUE-8)

**Workflow** (3-state):

States:
- `PEN` (Pending) — initial state on Create
- `APP` (Approved) — terminal pass
- `REJ` (Rejected) — terminal fail (but can be re-submitted as a NEW log; the rejected row stays for audit)

Transitions:
- `PEN → APP` via **Approve** command (single) or **BulkApprove** (list of IDs) — callable by users with VOLUNTEERHOURTRACKING:MODIFY capability
- `PEN → REJ` via **Reject** command (single — takes RejectionReason) or **BulkReject** (list + shared reason)
- `PEN → APP` via **LogAndApprove** convenience — creates + immediately approves in one transaction (used when coordinator logs on behalf of a volunteer and knows the hours are good)

Side effects:
- ApprovedByUserId / ApprovedAt set on APP transition
- RejectedByUserId / RejectedAt / RejectionReason set on REJ transition
- Bulk mutations return `{succeededIds: int[], failedIds: int[], errors: {id, reason}[]}` — partial-success tolerated (FE toasts summary)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Transactional workflow with approval state-machine + aggregate panel
**Reason**: Hour Tracking is a log-level transactional screen with per-row actions (Approve/Reject/Edit/Delete), bulk operations, a 3-state lifecycle, and a DETAIL view that shows the Approval Trail. Mockup opens Log Hours as a modal, but the FLOW convention (per Pledge #12, Refund #13, ChequeDonation #6 precedent) rebuilds it as a full `?mode=new` page with the same fields; the DETAIL view (`?mode=read&id=X`) is a **520px right-side drawer** (matching DonationInKind #7 + Pledge #12 drawer pattern, narrower than Pledge's 720px because Hour Tracking has fewer fields).

**Backend Patterns Required:**
- [x] Standard CRUD (Create, Update, Delete + GetAll + GetById — 7 files)
- [x] Tenant scoping (CompanyId from HttpContext; Volunteer.CompanyId enforcement on the FK side)
- [ ] Nested child creation — NO (no child collections in MVP)
- [x] Multi-FK validation (`ValidateForeignKeyRecord` × 5: Volunteer, VolunteerSchedule optional, ActivityType MasterData, Branch optional, ApprovalStatus MasterData)
- [x] Unique validation — VolunteerHourLogCode per Company (filtered-unique index + validator)
- [x] Workflow commands: Approve, Reject, BulkApprove, BulkReject, LogAndApprove — 5 files
- [x] Summary query (Get{Entity}Summary) — 4 KPI aggregates
- [x] Aggregate-by-volunteer query (GetVolunteerHourLogAggregateByVolunteer) — feeds collapsible summary panel
- [ ] File upload command — NO (attachment URL string only — see ⑫ ISSUE-3)
- [x] Custom business rule validators — LogDate ≤ today, Hours range, StartTime/EndTime pairing, RejectionReason conditional

**Frontend Patterns Required:**
- [x] FlowDataTable (grid)
- [x] view-page.tsx with 3 URL modes (new, edit, read — read renders drawer NOT full page, same pattern as DonationInKind #7 ISSUE-9 precedent and Pledge #12)
- [x] React Hook Form (for FORM layout) + Zod schemas
- [x] Zustand store (`volunteerhourlog-store.ts`) — selectedIds, filters, drawerOpen, aggregatePanelExpanded
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (with Back, Save, Save & Approve buttons)
- [ ] Child grid inside form — NO (attachments are a drop zone, not a grid)
- [x] Workflow status badge + action buttons — conditional per-row and drawer-level
- [x] Bulk actions bar — renders when ≥ 1 row checked
- [x] 4 filter chips (All/Pending/Approved/Rejected) — top-level GQL arg (Family #20 precedent, NOT AdvancedFilters JSON)
- [x] 4 filter dropdowns — Period (client-side date range preset), Volunteer (ApiSelectV2), ActivityType (MasterData), Branch
- [x] Collapsible aggregate-by-volunteer panel below main grid
- [x] Summary cards / count widgets above grid — 4 KPIs
- [x] 3 new cell renderers (volunteer-link, shift-link-or-manual, approval-status-badge-with-timestamp)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **Layout Variant**: `widgets-above-grid` → **Variant B MANDATORY**: `<ScreenHeader>` + 4 KPI widgets + filter bar + bulk-actions-bar + `<DataTableContainer showHeader={false}>` + collapsible aggregate panel BELOW the grid.

### Grid/List View

**Display Mode**: `table` (dense transactional list — standard `<AdvancedDataTable>` via `<FlowDataTableStoreProvider>`)

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | ☐ | (bulk checkbox) | checkbox | 36px | — | Row selector; drives bulk-actions-bar |
| 2 | Date | logDate | date | 110px | YES | Format `MMM d` (e.g., "Apr 12") |
| 3 | Volunteer | volunteerName | **volunteer-link** | auto | YES | Custom renderer: click → `/[lang]/crm/volunteer/volunteerlist?mode=read&id={volunteerId}` (see ⑫ ISSUE-9) |
| 4 | Activity | activity | text | auto | NO | Plain text |
| 5 | Shift Link | shiftLabel | **shift-link-or-manual** | 160px | NO | Custom renderer: if `volunteerScheduleId` present → link with chain-icon + `"Shift #{scheduleCode}"`; else muted text "Manual entry" |
| 6 | Hours | hours | number-bold | 80px | YES | Right-aligned, bold, 1-decimal (`4.0`) |
| 7 | Approved By | approvedByName | text-muted | 140px | NO | Plain text; "—" (em-dash muted) when Pending/Rejected |
| 8 | Status | approvalStatusCode | **approval-status-badge-with-timestamp** | 120px | YES | Custom renderer: badge colored per status (PEN=amber, APP=green, REJ=red); rejected variant adds tooltip with RejectionReason preview |
| 9 | Actions | — | actions | 160px | — | Conditional per status (see below) |

**Conditional Row Actions** (rightmost "Actions" column):
- Status = `PEN`: [Approve (green outline)] [Reject (red outline)] [Edit (gray outline)]
- Status = `APP`: [Edit (gray outline)] [⋮ More] — More menu: Delete (Admin only), Unlock (SERVICE_PLACEHOLDER)
- Status = `REJ`: [View Reason (accent outline — opens reason modal)] [⋮ More] — More menu: Delete, Re-submit (creates new PEN log with same fields pre-filled)

**Search/Filter Fields** (filter bar):
| Control | Type | Options | Wiring |
|---------|------|---------|--------|
| Period | select | ThisMonth / LastMonth / ThisQuarter / YTD / Custom (opens date-range picker) | Client-computes `dateFrom` + `dateTo` → top-level GQL args |
| Volunteer | ApiSelectV2 | queries `getVolunteers` paginated | Top-level GQL arg `volunteerId?: int` |
| Status chips | button group | All / Pending / Approved / Rejected | Top-level GQL arg `approvalStatusCode?: string` (Family #20 precedent) |
| Activity Type | select | 5 VOLUNTEERACTIVITYTYPE MasterData + "All Types" | Top-level GQL arg `activityTypeId?: int` |
| Branch | select | all active branches + "All Branches" | Top-level GQL arg `branchId?: int` |
| Clear Filters | link button | — | Resets all filter state in Zustand store |

**Grid Actions** (toolbar — top-right):
- **Log Hours** (primary) → navigates to `?mode=new`
- **Bulk Approve** (outline) → opens confirm modal, calls `BulkApproveVolunteerHourLogs(selectedIds)` with summary toast; disabled when no Pending rows selected
- **Export Report** (outline) → SERVICE_PLACEHOLDER toast

**Bulk-Actions Bar** (appears below filter bar when ≥ 1 row selected):
- Shows "{N} selected" in accent color
- [Approve Selected] — calls BulkApprove, disabled if any selected row ≠ Pending
- [Reject Selected] — opens reason input modal, calls BulkReject
- Sticky header-style styling matching mockup `.bulk-actions` (accent-bg background)

**Row Click**: Navigates to `?mode=read&id={id}` → opens 520px right-side drawer (URL syncs).

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

> NEW and EDIT share the FORM layout. READ uses a **520px right-side drawer** (NOT a full-page detail) — matching DonationInKind #7 + Pledge #12 pattern. This is a FLOW-with-drawer variant, supported by the same `view-page.tsx` component.

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

**Page Header**: `<FlowFormPageHeader>` with Back button + title "Log Hours" (new) / "Edit Hour Log" (edit) + 3 footer buttons: **Cancel** (outline) + **Log & Approve** (outline-accent — only visible in mode=new + disabled in mode=edit because LogAndApprove is a Create-time convenience) + **Log Hours** (primary, label changes to **Save Changes** in mode=edit)

**Section Container Type**: Single card (no accordion; mockup modal is a flat form — we preserve that simplicity).

**Form Sections** (in display order from mockup):
| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | ph:clock (phosphor — replace mockup fa-clock per UI uniformity memory) | Hour Log Details | 2-column | N/A (single card) | Volunteer (full-width row 1), Date + Hours (row 2, 2-col), Activity (full-width row 3), Linked Shift (full-width row 4), Start Time + End Time (row 5, 2-col), Activity Type (full-width row 6), Notes (full-width row 7 — textarea), Attachments (full-width row 8 — drop zone) |

**Field Widget Mapping** (all fields):
| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| VolunteerHourLogCode | 1 (hidden) | — | — | — | Auto-generated server-side; not rendered in form |
| VolunteerId | 1 | ApiSelectV2 | "— Select Volunteer —" | required | Query: `getVolunteers`; display: `volunteerName`; typeahead + paginated |
| LogDate | 1 | DatePicker | "Select date" | required, ≤ today, ≥ today-90d | Default: today |
| Hours | 1 | number | "4.0" | required, > 0, ≤ 24, step 0.5 | Shown bold monospaced |
| Activity | 1 | text | "e.g. Food Pack Distribution" | required, max 200 | Free-text |
| VolunteerScheduleId | 1 | ApiSelectV2 | "— Select Shift (optional) —" | optional | Query: `getVolunteerSchedules` filtered by VolunteerId (needs chained dependency — VolunteerId change invalidates this field; see ⑫ ISSUE-2) |
| StartTime | 1 | TimePicker | "08:00" | optional; requires EndTime if set | — |
| EndTime | 1 | TimePicker | "12:00" | optional; > StartTime | — |
| ActivityTypeId | 1 | ApiSelectV2 | "Select type" | required | Query: `getMasterDatas` with `typeCode=VOLUNTEERACTIVITYTYPE`; display: `dataName` |
| BranchId | 1 (hidden, auto) | — | — | optional | Auto-populated from Volunteer.BranchId on volunteer-change; persisted but not user-editable in MVP |
| Notes | 1 | Textarea | "e.g. Led setup team, coordinated with venue staff" | optional, max 1000 | min-height: 60px |
| AttachmentUrls | 1 | FileDropZone (SERVICE_PLACEHOLDER) | "Drop files here or browse" | optional | **MVP**: UI drop zone renders; on drop → toast "File upload service not yet configured"; AttachmentUrls stays empty string. See ⑫ ISSUE-3 |

**Special Form Widgets**:

- **No card selectors** in this form (mockup has none)
- **No conditional sub-forms** (single flat form)
- **Inline Mini Display (Volunteer Card)** — when VolunteerId is selected, a small readonly card appears above the Linked Shift field showing: avatar (color swatch), VolunteerName, VolunteerCode, Branch, Active status chip. This mirrors the Pledge #12 inline donor card pattern. See ⑫ ISSUE-10.

**Child Grids in Form**: NONE.

---

#### LAYOUT 2: DETAIL (mode=read) — 520px right-side drawer (NOT a full page)

> The read-only detail is a **drawer overlay**, NOT a new page. Row click opens the drawer and syncs URL to `?mode=read&id=X`. Closing the drawer (X button or Escape) navigates back to `?mode=read` without id → which reverts to the grid (no drawer open).
>
> This is the same pattern used by DonationInKind #7 and Pledge #12. The `view-page.tsx` renders the drawer when `mode=read && id` is present, otherwise renders the FORM.

**Drawer Header**: Title "Hour Log #HRL-00123" + status badge + close button (X)

**Drawer Action Bar** (sticky footer inside drawer — conditional on status):
- Status = `PEN`: [Approve (primary-green)] [Reject (outline-red)] [Edit (outline)] [Delete (outline — admin only)]
- Status = `APP`: [Edit (outline — opens unlock confirm — SERVICE_PLACEHOLDER)] [Delete (outline — admin only)]
- Status = `REJ`: [Re-submit (outline — creates new log pre-filled)] [Delete (outline — admin only)]

**Drawer Body Sections** (stacked vertical, each a subtle-bordered card):

| # | Card Title | Content |
|---|-----------|---------|
| 1 | Hour Log Summary | Date (bold), Volunteer (link to Volunteer detail — see ⑫ ISSUE-9), Activity (with activity-type chip), Hours (large monospaced), Status badge with colored background |
| 2 | Shift Link | If `volunteerScheduleId`: chain icon + "Shift #{scheduleCode} — {shiftTitle} ({scheduleDate})" as a link (target: `/[lang]/crm/volunteer/volunteerscheduling?mode=read&id={scheduleId}` — see ⑫ ISSUE-2). Else: muted "Manual entry — no shift linked" |
| 3 | Time Details | StartTime + EndTime side-by-side (empty state "—" when not logged); Branch name below |
| 4 | Notes | Notes field text (empty state "No notes") |
| 5 | Attachments | File list (MVP: comma-split AttachmentUrls → clickable chips) OR empty state "No attachments" |
| 6 | Approval Trail | Conditional: <br>• Pending: "⏳ Awaiting approval" + "Logged by {createdByName} on {createdAt}" <br>• Approved: ✓ Green "Approved by {approvedByName} on {approvedAt}" + logged info <br>• Rejected: ✗ Red "Rejected by {rejectedByName} on {rejectedAt}" + reason in red-bordered box + logged info |

**Reject Modal** (triggered from drawer or per-row Reject action):
- Title: "Reject Hour Log #{code}"
- Body: Read-only summary (Volunteer, Date, Hours, Activity) + RejectionReason textarea (min 5, max 500 chars, required)
- Footer: [Cancel] [Confirm Reject (red primary, disabled until reason ≥ 5 chars)]

**Bulk Reject Modal**:
- Title: "Reject {N} Hour Logs"
- Body: RejectionReason textarea (same constraints, applied to all)
- Footer: [Cancel] [Reject All (red primary)]
- On submit → returns `{succeededIds, failedIds, errors}` → toast summary

---

### Page Widgets & Summary Cards

**Widgets** (4 KPI cards above the grid):
| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Total Hours (Period) | `summary.totalHoursPeriod` (+ subtitle `{summary.activeVolunteersInPeriod} volunteers`) | number-bold (teal icon ph:clock) | col-1 |
| 2 | Pending Approval | `summary.pendingCount` (+ subtitle `{summary.pendingHours} hours awaiting review`) | number-bold (orange icon ph:hourglass) | col-2 |
| 3 | Avg Hours/Volunteer | `summary.avgHoursPerVolunteer` (+ subtitle MoM delta `↑ {delta} vs last month`, colored positive=green/neg=red) | number-bold 1-decimal (blue icon ph:chart-bar) | col-3 |
| 4 | Top Contributor | `summary.topContributorName` (+ subtitle `{summary.topContributorHours} hrs this month`) | text-large (gold icon ph:trophy) | col-4 |

**Grid Layout Variant**: `widgets-above-grid` → **Variant B MANDATORY**:
```tsx
<ScreenHeader title="Hour Tracking" subtitle="Log, review, and approve volunteer service hours" actions={[<Log Hours>, <Bulk Approve>, <Export>]} />
<VolunteerHourLogWidgets />   // 4 KPI cards
<FilterBar />                 // period + volunteer + status chips + activity + branch + clear
<BulkActionsBar />            // visible when selectedIds.length > 0
<FlowDataTableStoreProvider>
  <DataTableContainer showHeader={false} />
</FlowDataTableStoreProvider>
<VolunteerHoursSummaryPanel />  // collapsible aggregate-by-volunteer panel
```

**Summary GQL Query**:
- Query name: `GetVolunteerHourLogSummary`
- Args: `dateFrom?`, `dateTo?`, `branchId?`
- Returns: `VolunteerHourLogSummaryDto` — `{ totalHoursPeriod, activeVolunteersInPeriod, pendingCount, pendingHours, avgHoursPerVolunteer, avgHoursDeltaMoM, topContributorName, topContributorId, topContributorHours, approvedCount, rejectedCount }`

**Aggregate Panel Query** (for collapsible "Volunteer Hours Summary"):
- Query name: `GetVolunteerHourLogAggregateByVolunteer`
- Args: `dateFrom?`, `dateTo?`, `branchId?`, `limit? (default 20)`
- Returns: `List<VolunteerHourLogAggregateByVolunteerDto>` — one row per volunteer with: `volunteerId, volunteerName, periodHours, ytdHours, shiftCount, avgHoursPerShift, approvalRatePercent`

### Grid Aggregation Columns

> The collapsible "Volunteer Hours Summary" below the main grid is a **separate aggregate view** (its own query), not per-row aggregation on the main grid. The main grid has NO aggregation columns — each row is ONE hour log entry.

**Aggregation Columns**: NONE on the main grid.

### User Interaction Flow (FLOW — 3 modes, drawer-based DETAIL)

1. User sees `<ScreenHeader>` + 4 KPI cards + filter bar + grid → clicks **Log Hours** → URL: `?mode=new` → FORM loads (empty)
2. Fills form, picks volunteer (→ inline volunteer card appears, shift dropdown loads filtered list), saves → POST Create → redirect to `?mode=read&id={newId}` → drawer slides in
3. Alternate: clicks **Log & Approve** → POST LogAndApprove (Create + Approve in one tx as current user) → same redirect
4. User clicks a grid row → URL `?mode=read&id=X` → drawer slides in with full detail
5. User clicks **Edit** in drawer → URL `?mode=edit&id=X` → FORM layout loads pre-filled (drawer closes)
6. User clicks **Approve** in drawer (Pending only) → confirm toast → mutation → drawer refetches → status badge updates to APP
7. User clicks **Reject** in drawer → Reject Modal opens → types reason ≥ 5 chars → Confirm → mutation → drawer refetches → status badge updates to REJ
8. User selects 3 rows via checkboxes → bulk-actions-bar appears → clicks **Approve Selected** → confirm modal ("Approve 3 hour logs?") → BulkApprove mutation → summary toast "3 approved, 0 failed" → grid refetches
9. User opens collapsible "Volunteer Hours Summary" panel → aggregate query fires (scoped to current period + branch filters) → table of per-volunteer stats renders
10. User clicks Volunteer name link (in grid OR drawer OR aggregate panel) → navigates to Volunteer detail (#53 target — see ⑫ ISSUE-9)

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Canonical FLOW reference is **SavedFilter** (from `_FLOW.md`), with **Pledge #12** as structural precedent (FLOW + drawer + KPIs + bulk actions + new schema).

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | VolunteerHourLog | Entity/class name |
| savedFilter | volunteerHourLog | Variable/field names |
| SavedFilterId | VolunteerHourLogId | PK field |
| SavedFilters | VolunteerHourLogs | Table name, DbSet name, collection names |
| saved-filter | volunteer-hour-log | kebab-case (doc/variant keys) |
| savedfilter | volunteerhourlog | FE folder + import paths (lowercase, no dash) |
| SAVEDFILTER | VOLUNTEERHOURTRACKING | MenuCode + GridCode (matches MODULE_MENU_REFERENCE.md) |
| notify | vol | DB schema |
| Notify | Vol | Backend group name prefix |
| NotifyModels | VolModels | Namespace: `Base.Domain.Models.VolModels` |
| NotifySchemas | VolSchemas | Namespace: `Base.Application.Schemas.VolSchemas` |
| NotifyBusiness | VolBusiness | Namespace: `Base.Application.Business.VolBusiness` |
| INotifyDbContext | IVolDbContext | Interface in Base.Application/Data/Persistence/ (shared with #53 Volunteer — create during #53 build if not already) |
| NotifyDbContext | VolDbContext | Concrete DbContext in Base.Infrastructure |
| NotifyMappings | VolMappings | Mapster config class |
| DecoratorNotifyModules | DecoratorVolModules | Class in DecoratorProperties.cs |
| NOTIFICATIONSETUP | CRM_VOLUNTEER | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/volunteer/volunteerhourtracking | FE route path (from MODULE_MENU_REFERENCE.md) |
| notify-service | vol-service | FE service folder name under `domain/entities/` |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> If `vol` schema / IVolDbContext is already created by #53 Volunteer, **skip** the bootstrap rows. If not, this screen MUST bootstrap the module first (same pattern as Program #51 bootstrapping `case` schema).

### Backend Files (~17 files — CRUD + 5 workflow cmds + 2 aggregate queries + migration)

| # | File | Path |
|---|------|------|
| 1 | Entity | PSS_2.0_Backend/.../Base.Domain/Models/VolModels/VolunteerHourLog.cs |
| 2 | EF Config | PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerHourLogConfiguration.cs |
| 3 | Schemas (DTOs) | PSS_2.0_Backend/.../Base.Application/Schemas/VolSchemas/VolunteerHourLogSchemas.cs — includes: `VolunteerHourLogRequestDto`, `VolunteerHourLogResponseDto`, `VolunteerHourLogDto` (detail), `VolunteerHourLogSummaryDto`, `VolunteerHourLogAggregateByVolunteerDto`, `RejectVolunteerHourLogRequestDto`, `BulkWorkflowRequestDto`, `BulkWorkflowResultDto` |
| 4 | Create Command | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/CreateCommand/CreateVolunteerHourLog.cs |
| 5 | Update Command | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/UpdateCommand/UpdateVolunteerHourLog.cs |
| 6 | Delete Command | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/DeleteCommand/DeleteVolunteerHourLog.cs |
| 7 | Approve Command | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/ApproveCommand/ApproveVolunteerHourLog.cs |
| 8 | Reject Command | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/RejectCommand/RejectVolunteerHourLog.cs |
| 9 | BulkApprove Command | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/BulkApproveCommand/BulkApproveVolunteerHourLogs.cs |
| 10 | BulkReject Command | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/BulkRejectCommand/BulkRejectVolunteerHourLogs.cs |
| 11 | LogAndApprove Command | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/LogAndApproveCommand/LogAndApproveVolunteerHourLog.cs |
| 12 | GetAll Query | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/GetAllQuery/GetAllVolunteerHourLog.cs |
| 13 | GetById Query | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/GetByIdQuery/GetVolunteerHourLogById.cs |
| 14 | GetSummary Query | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/GetSummaryQuery/GetVolunteerHourLogSummary.cs |
| 15 | GetAggregateByVolunteer Query | PSS_2.0_Backend/.../Base.Application/Business/VolBusiness/VolunteerHourLogs/GetAggregateByVolunteerQuery/GetVolunteerHourLogAggregateByVolunteer.cs |
| 16 | Mutations | PSS_2.0_Backend/.../Base.API/EndPoints/Vol/Mutations/VolunteerHourLogMutations.cs |
| 17 | Queries | PSS_2.0_Backend/.../Base.API/EndPoints/Vol/Queries/VolunteerHourLogQueries.cs |
| 18 | Migration | PSS_2.0_Backend/.../Base.Infrastructure/Migrations/{timestamp}_Add_VolunteerHourLog.cs |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | `DbSet<VolunteerHourLog> VolunteerHourLogs { get; }` (add `IVolDbContext` to inheritance if not already via #53) |
| 2 | IVolDbContext.cs ⚠ **new if not created by #53** | `DbSet<VolunteerHourLog> VolunteerHourLogs { get; }` |
| 3 | VolDbContext.cs ⚠ **new if not created by #53** | `public DbSet<VolunteerHourLog> VolunteerHourLogs { get; set; }` |
| 4 | DecoratorProperties.cs | `DecoratorVolModules` class with `VolunteerHourLog = "vol.VolunteerHourLogs"` entry |
| 5 | VolMappings.cs ⚠ **new if not created by #53** | Mapster config for VolunteerHourLog → DTO projections (incl. `.Map()` for joins: Volunteer, VolunteerSchedule, ActivityType MasterData, ApprovalStatus MasterData, Branch, ApprovedByUser→Staff, RejectedByUser→Staff) |
| 6 | DependencyInjection.cs (Base.Application) | `VolMappings.ConfigureMappings()` registration (if not already) |
| 7 | DependencyInjection.cs (Base.Infrastructure) | VolDbContext registration (if not already) |
| 8 | GlobalUsing.cs × 3 (Domain, Application, Infrastructure) | `global using Base.Domain.Models.VolModels;` etc. |

### Frontend Files (~18 files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/vol-service/VolunteerHourLogDto.ts (includes `VolunteerHourLogDto`, `VolunteerHourLogResponseDto`, `VolunteerHourLogSummaryDto`, `VolunteerHourLogAggregateByVolunteerDto`, `BulkWorkflowResultDto`) |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/vol-queries/VolunteerHourLogQuery.ts — GetAll, GetById, GetSummary, GetAggregateByVolunteer |
| 3 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/vol-mutations/VolunteerHourLogMutation.ts — Create, Update, Delete, Approve, Reject, BulkApprove, BulkReject, LogAndApprove |
| 4 | Page Config | PSS_2.0_Frontend/src/presentation/pages/crm/volunteer/volunteerhourtracking.tsx |
| 5 | Index Router | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/index.tsx (URL dispatcher: renders index-page or view-page based on `searchParams.mode`) |
| 6 | Index Page (Variant B) | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/index-page.tsx (ScreenHeader + widgets + filter-bar + bulk-actions-bar + FlowDataTableContainer + aggregate panel) |
| 7 | View Page (3 modes) | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/view-page.tsx — renders FORM for new/edit, Drawer for read |
| 8 | Create/Edit Form | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/hour-log-form.tsx (RHF + Zod) |
| 9 | Form Zod Schema | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/hour-log-form-schemas.ts |
| 10 | Detail Drawer (520px) | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/hour-log-detail-drawer.tsx |
| 11 | Widgets (4 KPI cards) | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/volunteerhourlog-widgets.tsx |
| 12 | Filter Bar | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/filter-bar.tsx |
| 13 | Bulk Actions Bar | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/bulk-actions-bar.tsx |
| 14 | Reject Modal | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/reject-modal.tsx (single + bulk variants) |
| 15 | Aggregate Panel | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/volunteer-hours-summary-panel.tsx (collapsible) |
| 16 | Inline Volunteer Card | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/inline-volunteer-card.tsx |
| 17 | Zustand Store | PSS_2.0_Frontend/src/presentation/components/page-components/crm/volunteer/volunteerhourlog/volunteerhourlog-store.ts |
| 18 | Cell Renderers (3 new) | PSS_2.0_Frontend/src/presentation/components/shared-cell-renderers/{volunteer-link.tsx, shift-link-or-manual.tsx, approval-status-badge-with-timestamp.tsx} |
| 19 | Route Page (overwrite stub) | PSS_2.0_Frontend/src/app/[lang]/crm/volunteer/volunteerhourtracking/page.tsx |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations (new file or update existing vol-service block) | `VOLUNTEERHOURTRACKING` operations: createOperation, updateOperation, getAllOperation, getByIdOperation, approveOperation, rejectOperation, bulkApproveOperation, bulkRejectOperation, logAndApproveOperation, getSummaryOperation, getAggregateByVolunteerOperation |
| 2 | operations-config.ts | Import + register vol-service operations |
| 3 | shared-cell-renderers/index.ts | Export 3 new renderers |
| 4 | column-type-registry-advanced.tsx | Register `volunteer-link`, `shift-link-or-manual`, `approval-status-badge-with-timestamp` renderer keys |
| 5 | column-type-registry-basic.tsx | Same — register 3 new keys |
| 6 | column-type-registry-flow.tsx | Same — register 3 new keys |
| 7 | sidebar menu config | Already handled via DB seed (menu row in Menus table → driven by backend menu query) |
| 8 | route page.tsx | Overwrite stub `Need to Develop` with `<VolunteerHourLogRouter />` |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens per MODULE_MENU_REFERENCE.md.

```
---CONFIG-START---
Scope: FULL

MenuName: Hour Tracking
MenuCode: VOLUNTEERHOURTRACKING
ParentMenu: CRM_VOLUNTEER
Module: CRM
MenuUrl: crm/volunteer/volunteerhourtracking
GridType: FLOW
OrderBy: 4

MenuCapabilities: READ, CREATE, MODIFY, DELETE, APPROVE, REJECT, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, APPROVE, REJECT, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: VOLUNTEERHOURTRACKING

MasterDataSeeds:
  VOLUNTEERACTIVITYTYPE (new TypeCode):
    - EVT (Event)
    - OFF (Office)
    - FLD (Field)
    - RMT (Remote)
    - TRN (Training)
  VOLUNTEERHOURSTATUS (new TypeCode):
    - PEN (Pending)   ColorHex bg=#fef3c7 fg=#92400e
    - APP (Approved)  ColorHex bg=#dcfce7 fg=#166534
    - REJ (Rejected)  ColorHex bg=#fef2f2 fg=#dc2626

Seed file: PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/VolunteerHourLog-sqlscripts.sql
 (preserve `sql-scripts-dyanmic` folder typo — see ⑫ ISSUE-15)
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `VolunteerHourLogQueries`
- Mutation type: `VolunteerHourLogMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| getVolunteerHourLogs | PaginatedApiResponse<[VolunteerHourLogResponseDto]> | searchText, pageNo, pageSize, sortField, sortDir, dateFrom, dateTo, volunteerId, approvalStatusCode, activityTypeId, branchId |
| getVolunteerHourLogById | BaseApiResponse<VolunteerHourLogDto> | volunteerHourLogId |
| getVolunteerHourLogSummary | BaseApiResponse<VolunteerHourLogSummaryDto> | dateFrom?, dateTo?, branchId? |
| getVolunteerHourLogAggregateByVolunteer | BaseApiResponse<[VolunteerHourLogAggregateByVolunteerDto]> | dateFrom?, dateTo?, branchId?, limit? |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| createVolunteerHourLog | VolunteerHourLogRequestDto | int (new ID) |
| updateVolunteerHourLog | VolunteerHourLogRequestDto (with Id) | int |
| deleteVolunteerHourLog | volunteerHourLogId: int | int |
| approveVolunteerHourLog | volunteerHourLogId: int | int |
| rejectVolunteerHourLog | RejectVolunteerHourLogRequestDto (id, rejectionReason) | int |
| bulkApproveVolunteerHourLogs | BulkWorkflowRequestDto (ids: int[]) | BulkWorkflowResultDto |
| bulkRejectVolunteerHourLogs | BulkWorkflowRequestDto (ids: int[], rejectionReason) | BulkWorkflowResultDto |
| logAndApproveVolunteerHourLog | VolunteerHourLogRequestDto | int (new ID, already APP) |

**Response DTO Fields** — `VolunteerHourLogResponseDto`:
| Field | Type | Notes |
|-------|------|-------|
| volunteerHourLogId | number | PK |
| volunteerHourLogCode | string | `HRL-00123` |
| volunteerId | number | FK |
| volunteerName | string | Projected from Volunteer→Contact.DisplayName |
| volunteerCode | string | — |
| volunteerAvatarColor | string | Derived hex for avatar swatch (or null) |
| volunteerScheduleId | number \| null | FK |
| shiftLabel | string \| null | `"Shift #{code} — {title}"` or null |
| logDate | string (ISO date) | — |
| hours | number | decimal |
| startTime | string \| null | `HH:mm:ss` |
| endTime | string \| null | — |
| activity | string | — |
| activityTypeId | number | FK |
| activityTypeCode | string | EVT / OFF / FLD / RMT / TRN |
| activityTypeName | string | — |
| branchId | number \| null | — |
| branchName | string \| null | — |
| notes | string \| null | — |
| attachmentUrls | string \| null | Comma-separated |
| approvalStatusId | number | — |
| approvalStatusCode | string | PEN / APP / REJ |
| approvalStatusName | string | — |
| approvalStatusColorHex | string \| null | — |
| approvedByUserId | number \| null | — |
| approvedByName | string \| null | Staff name via User join |
| approvedAt | string (ISO) \| null | — |
| rejectedByUserId | number \| null | — |
| rejectedByName | string \| null | — |
| rejectedAt | string (ISO) \| null | — |
| rejectionReason | string \| null | — |
| isActive | boolean | Inherited |
| createdByName | string | Inherited audit |
| createdDate | string | Inherited |

**`VolunteerHourLogSummaryDto`:**
| Field | Type |
|-------|------|
| totalHoursPeriod | number |
| activeVolunteersInPeriod | number |
| pendingCount | number |
| pendingHours | number |
| approvedCount | number |
| rejectedCount | number |
| avgHoursPerVolunteer | number |
| avgHoursDeltaMoM | number (can be negative) |
| topContributorId | number \| null |
| topContributorName | string \| null |
| topContributorHours | number \| null |

**`VolunteerHourLogAggregateByVolunteerDto`:**
| Field | Type |
|-------|------|
| volunteerId | number |
| volunteerName | string |
| periodHours | number |
| ytdHours | number |
| shiftCount | number |
| avgHoursPerShift | number |
| approvalRatePercent | number (0-100) |

**`BulkWorkflowResultDto`:**
| Field | Type |
|-------|------|
| succeededIds | number[] |
| failedIds | number[] |
| errors | `{ id: number, reason: string }[]` |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (requires Volunteer entity from #53 merged to main first — HARD blocker, see ⑫ ISSUE-1)
- [ ] EF migration `Add_VolunteerHourLog` runs cleanly and creates `vol.VolunteerHourLogs` + foreign keys (Volunteers, VolunteerSchedules nullable, Branches nullable, Users nullable × 2, MasterDatas × 2)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/volunteer/volunteerhourtracking` (no console errors)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] ScreenHeader renders "Hour Tracking" + 3 header actions (Log Hours / Bulk Approve / Export Report)
- [ ] 4 KPI widgets render with real backend values (not mocks)
- [ ] Filter bar: Period select changes range (ThisMonth default), Volunteer ApiSelectV2 loads paginated, 4 status chips toggle, ActivityType dropdown loads 5 MasterData values, Branch loads company branches, Clear Filters resets all
- [ ] Grid loads 8 columns in correct order; sorting works on Date/Volunteer/Hours/Status
- [ ] Bulk-actions-bar appears at ≥ 1 selection, disappears at 0; disabled state on "Approve Selected" when any selected row is not Pending
- [ ] Per-row actions render correctly per status (Pending = Approve/Reject/Edit; Approved = Edit/More; Rejected = View Reason/More)
- [ ] Approve action fires mutation → row status updates to APP → approvedByName/approvedAt populate → grid refreshes
- [ ] Reject action opens modal → require reason ≥ 5 chars → fires mutation → row status updates to REJ → rejectedByName/rejectedAt/rejectionReason populate
- [ ] `?mode=new` — empty FORM renders 8 fields in single card
- [ ] Selecting a Volunteer → inline volunteer card renders above Linked Shift field (avatar + name + code + branch + Active chip)
- [ ] Shift dropdown loads filtered by selected Volunteer (empty if no shifts for that volunteer)
- [ ] StartTime without EndTime → validation error; EndTime ≤ StartTime → validation error
- [ ] LogDate > today → blocked; LogDate < today-90d → blocked
- [ ] Hours ≤ 0 or > 24 or not multiple of 0.5 → blocked
- [ ] Log Hours button creates record (status=PEN) → redirects to `?mode=read&id={newId}` → drawer opens
- [ ] Log & Approve button creates record + immediately approves (status=APP, approvedByUserId=current user) in one tx
- [ ] `?mode=read&id=X` → 520px right-side drawer opens with 6 body cards (Summary, Shift Link, Time Details, Notes, Attachments, Approval Trail)
- [ ] Approval Trail card adapts to status: Pending "Awaiting approval", Approved green checkmark + who/when, Rejected red X + who/when + reason box
- [ ] Drawer action bar adapts to status (Pending: Approve/Reject/Edit/Delete; Approved: Edit/Delete; Rejected: Re-submit/Delete)
- [ ] Edit button on drawer (Pending only) → drawer closes + URL → `?mode=edit&id=X` → FORM pre-filled
- [ ] Edit on Approved row → toast "Cannot edit — unlock via admin" (SERVICE_PLACEHOLDER for unlock flow)
- [ ] Save in edit mode updates record → drawer refetches and reopens
- [ ] Row click anywhere on the row (except checkbox cell) opens drawer
- [ ] URL sync: opening drawer updates `?mode=read&id=X`, closing drawer clears those params
- [ ] Bulk Approve (header OR bulk-bar button) → confirm modal → mutation → summary toast "{N} approved, {M} failed"
- [ ] Bulk Reject (bulk-bar button) → Reject Modal with textarea → mutation → summary toast
- [ ] Collapsible "Volunteer Hours Summary" panel below grid: renders aggregate rows, toggles open/closed, respects current filters (dateFrom/dateTo/branch)
- [ ] Approval Rate column in aggregate panel shows color-coded percent (green ≥100, amber 95-99, red <95)
- [ ] Volunteer link click (grid / drawer / aggregate panel) → navigates to Volunteer detail (or toast if #53 not built yet — ISSUE-9)
- [ ] Shift link click → navigates to Volunteer Schedule detail (or toast if #54 not built yet — ISSUE-2)
- [ ] Export Report button → SERVICE_PLACEHOLDER toast
- [ ] Attachments drop zone → SERVICE_PLACEHOLDER toast on file drop; form saves with empty attachmentUrls
- [ ] Unsaved changes dialog triggers on dirty FORM navigation
- [ ] Permissions: Approve/Reject/Delete buttons respect BUSINESSADMIN role caps

**DB Seed Verification:**
- [ ] Menu "Hour Tracking" appears in sidebar under CRM_VOLUNTEER at OrderBy=4
- [ ] Grid VOLUNTEERHOURTRACKING has 8 FLOW columns registered
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed, form is code-driven RHF+Zod)
- [ ] VOLUNTEERACTIVITYTYPE MasterData: 5 rows (EVT, OFF, FLD, RMT, TRN) visible in ActivityType dropdown
- [ ] VOLUNTEERHOURSTATUS MasterData: 3 rows (PEN, APP, REJ) with ColorHex populated in DataSetting JSON

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field in RequestDto** — tenant scope pulled from HttpContext on Create/Update (never trust the client)
- **FLOW screens do NOT generate GridFormSchema** — `GridFormSchema: SKIP` in seed; form is code-driven RHF + Zod
- **view-page.tsx renders drawer for `?mode=read`** — NOT a full page. Matches DonationInKind #7 + Pledge #12 pattern. Drawer is 520px wide (narrower than Pledge's 720px because Hour Tracking has fewer fields).
- **First-or-second entity in `vol` schema** — if IVolDbContext / VolDbContext / VolMappings / DecoratorVolModules not created by #53 Volunteer build, this screen MUST bootstrap the module (same ritual as Program #51 bootstrapping `case` schema). Check before coding; do NOT duplicate bootstrap files.
- **Drawer URL pattern**: `?mode=read&id=X` opens drawer; `?mode=read` without id stays on grid. Closing drawer pushes `?mode=read` (no id).
- **Filter chips use top-level GQL args**, NOT AdvancedFilters JSON payload (Family #20 ISSUE-13 precedent; DuplicateContact #21 ISSUE-5 precedent)
- **Phosphor icons (ph:*), NOT fa-***  — Mockup uses `fa-clock`, `fa-hourglass-half`, `fa-chart-bar`, `fa-trophy`, `fa-check`, `fa-times`, etc. FE dev must replace with Phosphor equivalents (`ph:clock`, `ph:hourglass`, `ph:chart-bar`, `ph:trophy`, `ph:check`, `ph:x`) per UI uniformity memory
- **ColorHex comes from MasterData DataSetting JSON** — seed ColorHex into `DataSetting` as `{"ColorHex":{"bg":"#...","fg":"#..."}}`, not as inline hex in FE (Tag #22 precedent)
- **GridComponentName values in seed MUST resolve** in 3 FE registries (advanced/basic/flow) — if a renderer key is in seed but missing from registries, the cell silently renders as raw JSON. Build-screen's testing-agent enforces this check.

### § Known Issues (pre-flagged at planning time)

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | **CRITICAL — BUILD BLOCKER** | BE dep | `Volunteer` entity (#53) does NOT exist yet. Hour Tracking's VolunteerId FK cannot be created without it. **Action**: build #53 Volunteer FIRST (it also bootstraps `vol` schema + IVolDbContext), then build this screen. If #53 bootstrap is already present at build time, this ISSUE auto-closes. |
| ISSUE-2 | HIGH | BE dep | `VolunteerSchedule` entity (#54) does NOT exist yet. VolunteerScheduleId is nullable, so the build is not blocked, but the Shift Link dropdown + grid column + drawer link will be degraded (empty dropdown, "Manual entry" everywhere) until #54 is built. **Action**: mark VolunteerScheduleId as nullable int with no FK constraint in MVP migration; add FK constraint in a follow-up migration after #54 lands. |
| ISSUE-3 | MED | Attachments | File upload infrastructure (blob storage, upload endpoint, file-service) does not exist in the codebase yet. **MVP**: AttachmentUrls is a comma-separated string column; FE drop zone renders but toasts SERVICE_PLACEHOLDER on drop. Promote to a child `VolunteerHourLogAttachment` table + real upload service in a later iteration. Same placeholder pattern as Contact #18 photos, DonationInKind #7 photos. |
| ISSUE-4 | LOW | Validation | Soft duplicate-check (same Volunteer + Date + Activity + StartTime) is a **warn only**, not a block. Rationale: same volunteer may legitimately log two entries with same activity (e.g., cleaned up after morning and evening shifts) — hard block would be hostile. FE shows toast "Similar log exists — continue?" but save proceeds. |
| ISSUE-5 | LOW | Validation | StartTime/EndTime vs Hours duration mismatch check is **warn only**. Rationale: volunteers might log "start 8:00, end 12:00" but actual worked hours were 3.5 (coffee break). BE does not block; FE toast "Logged hours don't match time window — intentional?" |
| ISSUE-6 | MED | Workflow | Unlock flow for Approved/Rejected rows is **out of MVP scope**. Admin-tier users currently cannot modify an Approved row — only Delete is possible. Promote to a separate "Request Unlock" workflow with supervisor approval in a later iteration. Edit button on Approved row shows SERVICE_PLACEHOLDER toast. |
| ISSUE-7 | LOW | Validation | 90-day past-date cap is **hard-coded**. Should become a Company-level setting (`LateHourLogGracePeriodDays`) driven by OrganizationSetting table. Deferred to post-MVP. |
| ISSUE-8 | LOW | Data integrity | If a Volunteer is **deactivated** after an hour log was created, Edit on that log should still work (historical correctness). Validator warns but does not block. Create, however, blocks — cannot log new hours for a deactivated volunteer. |
| ISSUE-9 | HIGH | Cross-screen | Volunteer link click in grid/drawer/aggregate panel targets `/[lang]/crm/volunteer/volunteerlist?mode=read&id={volunteerId}` — BUT Volunteer #53 is not built yet. FE handler must feature-flag: if #53 route returns 404 / is stub, show toast "Volunteer profile not yet available". Once #53 COMPLETED, remove the flag. |
| ISSUE-10 | LOW | UX | Inline volunteer card in form requires querying `getVolunteerById` on VolunteerId change. If Volunteer GetById query is not exposed by #53 MVP, fallback to the row data already fetched by the ApiSelectV2 option → the selected option should carry enough fields (volunteerName, volunteerCode, branchName, isActive) to render the inline card without an extra query. |
| ISSUE-11 | MED | Aggregate perf | `GetVolunteerHourLogAggregateByVolunteer` SUMs + GROUPs over full VolunteerHourLogs table scoped by company + date range. For a large tenant (1000s of volunteers × 100 logs/year), this can be slow on first call. MVP implementation: straightforward LINQ GROUP BY; add index on `(CompanyId, VolunteerId, LogDate, ApprovalStatusId)` in migration. Cache for 60s in memory if perf issues observed. |
| ISSUE-12 | LOW | Summary MoM | `avgHoursDeltaMoM` requires comparing current period vs previous period — implementer must choose the comparison window carefully (previous full month if period=ThisMonth; previous quarter if period=ThisQuarter; else previous equivalent-length window). Document the choice in the handler. |
| ISSUE-13 | LOW | Bulk results | `BulkWorkflowResultDto` return shape `{succeededIds, failedIds, errors}` — FE must render a summary toast with clickable link to filter grid by `failedIds` so user can inspect. If too many failures, show a detail modal. |
| ISSUE-14 | LOW | Code gen | VolunteerHourLogCode generator (HRL-{NNNNN}) is per-Company. Use the same concurrency-safe generation pattern as `RefundCode` (Refund #13 ISSUE-5) — MAX + retry on unique-constraint violation. |
| ISSUE-15 | LOW | Seed folder | Seed SQL goes into `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/` — **preserve the typo** `dyanmic` (verified exists). This matches ChequeDonation #6, Refund #13, and all other recent FLOW seeds. |

### § Service Dependencies (UI fully built, handler stubbed)

Full UI must be built (buttons, forms, modals, panels, interactions). Only the handler for the external service call is mocked.

- ⚠ **SERVICE_PLACEHOLDER: Attachments upload** — UI drop zone renders; on drop → toast "File upload service not yet configured". Reason: blob-storage service not wired in the codebase. See ISSUE-3.
- ⚠ **SERVICE_PLACEHOLDER: Export Report** — UI button renders in ScreenHeader actions; click → toast "Export not yet implemented". Reason: platform-wide export service not yet implemented (same placeholder used by Pledge #12, Refund #13, RecurringDonationSchedule #8).
- ⚠ **SERVICE_PLACEHOLDER: Unlock Approved row** — UI "Edit" button on an Approved row renders; click → toast "Unlock requires admin request (out of MVP scope)". Reason: Request Unlock workflow not designed yet. See ISSUE-6.
- ⚠ **SERVICE_PLACEHOLDER: Volunteer link navigation** — UI link renders; click → navigates OR (if #53 not built) shows toast. Auto-enables when Volunteer #53 COMPLETED. See ISSUE-9.
- ⚠ **SERVICE_PLACEHOLDER: Shift link navigation** — UI link renders; click → navigates OR (if #54 not built) shows toast. Auto-enables when Volunteer Schedule #54 COMPLETED. See ISSUE-2.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning | CRITICAL | BE dep | Volunteer #53 entity not built — blocks VolunteerId FK | OPEN |
| ISSUE-2 | planning | HIGH | BE dep | VolunteerSchedule #54 entity not built — Shift Link degraded | OPEN |
| ISSUE-3 | planning | MED | Attachments | File upload infra missing — AttachmentUrls string + SERVICE_PLACEHOLDER | OPEN |
| ISSUE-4 | planning | LOW | Validation | Soft duplicate-check warn-only | OPEN |
| ISSUE-5 | planning | LOW | Validation | StartTime/EndTime duration mismatch warn-only | OPEN |
| ISSUE-6 | planning | MED | Workflow | Unlock flow for Approved/Rejected out of MVP | OPEN |
| ISSUE-7 | planning | LOW | Validation | 90-day past-date cap hard-coded | OPEN |
| ISSUE-8 | planning | LOW | Data | Deactivated-volunteer handling on Edit vs Create | OPEN |
| ISSUE-9 | planning | HIGH | Cross-screen | Volunteer link feature-flag pending #53 | OPEN |
| ISSUE-10 | planning | LOW | UX | Inline volunteer card fallback to ApiSelect option data | OPEN |
| ISSUE-11 | planning | MED | Perf | Aggregate-by-volunteer query perf on large tenants | OPEN |
| ISSUE-12 | planning | LOW | Metric | avgHoursDeltaMoM comparison-window choice | OPEN |
| ISSUE-13 | planning | LOW | UX | Bulk results toast vs detail modal threshold | OPEN |
| ISSUE-14 | planning | LOW | Code gen | VolunteerHourLogCode concurrency-safe generator | OPEN |
| ISSUE-15 | planning | LOW | Seed | `sql-scripts-dyanmic` folder typo preservation | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

No sessions recorded yet — filled in after /build-screen completes.