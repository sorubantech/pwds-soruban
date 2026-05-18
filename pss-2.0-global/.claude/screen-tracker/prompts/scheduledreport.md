---
screen: ScheduledReport
registry_id: 101
module: Report & Audit
status: COMPLETED
scope: FULL
screen_type: MASTER_GRID
complexity: High
new_module: NO — `rep` schema fully wired (IReportDbContext exists, ReportModels/ReportConfigurations folders populated)
planned_date: 2026-05-15
completed_date: 2026-05-15
last_session_date: 2026-05-15
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed (FE stub at `app/[lang]/reportaudit/reports/scheduledreport/page.tsx` → `UnderConstruction`; no BE files)
- [x] Business rules extracted
- [x] FK targets resolved (Report, Branch, DonationPurpose — all paginated GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled (MenuCode=SCHEDULEDREPORT already seeded under RA_REPORTS)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized
- [x] User Approval received
- [x] Backend code generated
- [x] Backend wiring complete
- [x] Frontend code generated
- [x] Frontend wiring complete
- [x] DB Seed script generated (including GridFormSchema)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [x] dotnet build passes (0 errors, 1 unrelated NPOI license warning)
- [x] pnpm tsc --noEmit — 0 errors in new ScheduledReport FE files
- [ ] pnpm dev — page loads at `/{lang}/reportaudit/reports/scheduledreport` (replace UnderConstruction stub) — **user runtime verification pending after migration + seed apply**
- [ ] CRUD flow tested (Create → Read → Update → Toggle (Pause/Resume) → Delete) — user runtime verification
- [ ] Grid columns render correctly with search/filter (Report Name, Type badge, Frequency, Next Run, Recipients, Last Run, Status) — user runtime verification
- [ ] Create modal renders all sections (Report select, Parameters, Schedule, Output, Delivery, Options) — conditional Day field switches with Frequency — user runtime verification
- [ ] FK dropdowns load: Report (groups Standard/Custom/HTML via ReportType), Branch, DonationPurpose — user runtime verification
- [ ] Email recipient chips: add/remove/validate-on-blur — user runtime verification
- [ ] Summary widgets display correct values (active count, delivered-this-month, unique-recipients) — user runtime verification
- [ ] Run-Now action: stub call returns toast + appends a ScheduledReportRun row — user runtime verification
- [ ] Pause/Resume/Duplicate row actions update ScheduleStatus / clone row — user runtime verification
- [ ] View History expansion panel: renders ScheduledReportRun rows for the selected schedule with Status/Duration/FileSize/Recipients — user runtime verification
- [ ] DB Seed — menu visible under RA_REPORTS (already seeded), grid + form schema render — user runtime verification after seed apply

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

**Screen**: Scheduled Reports
**Module**: Report & Audit
**Schema**: `rep`
**Group**: `ReportModels` (entity), `ReportConfigurations` (EF), `ReportSchemas` (DTO), `ReportBusiness` (commands/queries), `Report` (API EndPoints folder), `DecoratorReportModules` (decorator class)

**Business**: Scheduled Reports lets an NGO admin pre-configure recurring delivery of any catalog report (Standard, Custom, or HTML) to a list of recipients on a fixed cadence (Daily / Weekly / Monthly / Quarterly / Yearly). The admin picks a report, pins its parameters (date range, branch, purpose), chooses a frequency + time + timezone, decides the output format (PDF/Excel/CSV/HTML), and configures delivery channels (email recipients with templated subject, shared-drive save, in-app notification). The system tracks every run in a Run History sub-grid so the admin can audit delivery success and re-send / re-run on demand. This screen is the operational complement of the Generate Report engine (#154) and Report Catalog (#99) — the Schedule modal in #99 currently shows a SERVICE_PLACEHOLDER pointing here. Heavy users are finance/audit teams that need consistent month-end packages and fundraising/ops teams that want weekly digest emails without manual export. Hangfire (or equivalent recurring-job infra) is NOT yet in the codebase — see §⑫ for the placeholder strategy.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Audit columns (CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive, IsDeleted, CompanyId base) inherited from `Entity` base class.

### Parent: `rep.ScheduledReports`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ScheduledReportId | int | — | PK | — | Primary key, identity |
| ReportId | int | — | YES | `rep.Reports` | The catalog report to run. Drives form's Report select. |
| ScheduleName | string | 200 | NO | — | Optional override label; falls back to `Report.ReportName` for display. |
| Frequency | string | 20 | YES | — | Enum-string: `DAILY`, `WEEKLY`, `MONTHLY`, `QUARTERLY`, `YEARLY`. |
| DayOfMonth | int? | — | NO | — | 1–31 OR `-1` sentinel for "Last day". Used for MONTHLY/QUARTERLY/YEARLY. |
| DayOfWeek | int? | — | NO | — | 0=Sun … 6=Sat. Used for WEEKLY. |
| MonthOfYear | int? | — | NO | — | 1–12. Used for YEARLY. |
| ScheduleTime | TimeOnly | — | YES | — | Local time in `Timezone`. Stored as Postgres `time` (no date). |
| Timezone | string | 50 | YES | — | IANA tz id, e.g. `Asia/Dubai`. Mockup shows display labels; BE stores IANA. |
| CronExpression | string | 100 | NO | — | Server-derived from Frequency/Day/Time on save. Cached for Hangfire wiring later. |
| OutputFormat | string | 10 | YES | — | Enum-string: `PDF`, `EXCEL`, `CSV`, `HTML`. |
| DateRangePreset | string | 20 | YES | — | Enum-string: `LAST_WEEK`, `LAST_MONTH`, `LAST_QUARTER`, `LAST_YEAR`, `CUSTOM`. |
| CustomFromDate | DateTime? | — | NO | — | Required if `DateRangePreset = CUSTOM`. Kind=Utc. |
| CustomToDate | DateTime? | — | NO | — | Same as above. |
| BranchId | int? | — | NO | `app.Branches` | NULL = "All branches". |
| DonationPurposeId | int? | — | NO | `don.DonationPurposes` | NULL = "All purposes". |
| ParametersJson | string? | 4000 | NO | — | jsonb in Postgres. Extensible bag for per-report extra params. |
| DeliverByEmail | bool | — | YES | — | Default `true`. Gates EmailRecipients/Subject/Body. |
| EmailRecipients | string? | 2000 | NO | — | Comma-separated list. Required when `DeliverByEmail = true`. Validation: each token must be a valid email. |
| EmailSubject | string? | 200 | NO | — | Supports `{month}` / `{year}` / `{reportName}` placeholders. |
| EmailBody | string? | 1000 | NO | — | Plain text. Same placeholders supported. |
| DeliverToSharedDrive | bool | — | YES | — | Default `false`. |
| SharedDrivePath | string? | 500 | NO | — | Required when `DeliverToSharedDrive = true`. |
| DeliverInApp | bool | — | YES | — | Default `false`. |
| SkipIfEmpty | bool | — | YES | — | Default `false` — "Don't send if no data". |
| IncludeComparison | bool | — | YES | — | Default `true` — "Include comparison with previous period". |
| PasswordProtect | bool | — | YES | — | Default `false` — "Password-protect attachment". |
| ScheduleStatus | string | 20 | YES | — | Server-managed enum: `ACTIVE`, `PAUSED`, `ERROR`. Default `ACTIVE` on create. |
| LastRunDate | DateTime? | — | NO | — | Kind=Utc. Updated on every run. |
| LastRunStatus | string? | 20 | NO | — | `DELIVERED`, `FAILED`, `RUNNING`. |
| LastRunError | string? | 1000 | NO | — | Captured when LastRunStatus=`FAILED`. |
| NextRunDate | DateTime? | — | NO | — | Kind=Utc. Server-computed from cron after each run / on create. |
| CompanyId | int | — | YES | `app.Companies` | Tenant scoping (audit base inherits this on most entities but ScheduledReport must be tenant-scoped explicitly). |

### Child: `rep.ScheduledReportRuns`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ScheduledReportRunId | int | — | PK | — | Primary key |
| ScheduledReportId | int | — | YES | `rep.ScheduledReports` | Cascade delete with parent. |
| RunDate | DateTime | — | YES | — | Kind=Utc. When the run started. |
| Status | string | 20 | YES | — | `DELIVERED`, `FAILED`, `RUNNING`. |
| DurationSeconds | int? | — | NO | — | Wall-clock duration of the generation+delivery. |
| FileSizeBytes | long? | — | NO | — | Size of generated file. |
| FileUrl | string? | 500 | NO | — | Persisted location of generated artifact (for re-download). |
| RecipientsSent | int? | — | NO | — | Count of email recipients successfully reached. |
| ErrorMessage | string? | 1000 | NO | — | Populated when Status=`FAILED`. |

**Child Entity Summary**:
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| ScheduledReportRun | 1:Many via ScheduledReportId | RunDate, Status, FileSizeBytes, RecipientsSent |

**Computed properties (BE projection only, not stored):**
- `NextRunDisplay`, `LastRunDisplay` — formatted strings used by grid + history panel.
- `ReportName` — flattened via `.Include(s => s.Report)` for grid column.
- `ReportTypeCode` — flattened from `Report.ReportType.MasterDataCode` → drives grid badge color (`STANDARD` / `CUSTOM` / `HTML`).
- `RecipientCount` — count of EmailRecipients tokens, for grid display.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` + navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ReportId | Report | `PSS_2.0_Backend/.../Base.Domain/Models/ReportModels/Report.cs` | `GetReports` (paginated) | `ReportName` | `ReportResponseDto` |
| BranchId | Branch | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Branch.cs` | `GetBranches` (paginated) | `BranchName` | `BranchResponseDto` |
| DonationPurposeId | DonationPurpose | `PSS_2.0_Backend/.../Base.Domain/Models/DonationModels/DonationPurpose.cs` | `GetDonationPurposes` (paginated) | `DonationPurposeName` | `DonationPurposeResponseDto` |
| CompanyId | Company | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Company.cs` | (server-injected from claims — not user-selected) | — | — |

**Notes on the Report dropdown**:
- The Report FK select in the modal is **grouped by `ReportType.MasterDataCode`** — Standard / Custom / HTML. UX must render an `<optgroup>` or grouped ApiSelectV2 variant.
- The list filters server-side to only reports the user has access to (i.e. `ReportRoles` where `MasterRoleId IN (user.roles)`).
- FE may need a small client-side group transform on the GetReports response, OR a new BE query `GetReportsGroupedByType` (recommended — see §⑩).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- No hard uniqueness — same Report can have multiple schedules (e.g., weekly + monthly cadence).
- Soft warning (FE-only) if a `(ReportId, Frequency, ScheduleTime)` combo already exists for the same Company.

**Required Field Rules:**
- `ReportId`, `Frequency`, `ScheduleTime`, `Timezone`, `OutputFormat`, `DateRangePreset` are always mandatory.
- `DayOfMonth` required when `Frequency IN (MONTHLY, QUARTERLY, YEARLY)`.
- `DayOfWeek` required when `Frequency = WEEKLY`.
- `MonthOfYear` required when `Frequency = YEARLY`.
- `CustomFromDate` + `CustomToDate` required when `DateRangePreset = CUSTOM`; `CustomToDate >= CustomFromDate`.
- At least one delivery channel must be enabled: `DeliverByEmail OR DeliverToSharedDrive OR DeliverInApp`.
- `EmailRecipients` required when `DeliverByEmail = true`; every comma-separated token must match `^[^\s@]+@[^\s@]+\.[^\s@]+$`.
- `SharedDrivePath` required when `DeliverToSharedDrive = true`.

**Conditional Rules:**
- Day-of-month value `-1` represents "Last day" — BE cron generator handles this as `L`.
- `IncludeComparison` only meaningful for `Frequency != DAILY`; FE may grey-out for Daily but BE accepts any value.
- `PasswordProtect` requires `OutputFormat IN (PDF, EXCEL)` — FE disables for CSV/HTML; BE validator enforces.

**Business Logic:**
- On Create: server derives `CronExpression` from Frequency/Day/Time/Timezone and computes `NextRunDate`. Sets `ScheduleStatus = ACTIVE`.
- On Update: same recomputation if any timing field changes.
- On Toggle (Pause/Resume): switches `ScheduleStatus` between `ACTIVE` ↔ `PAUSED`; does NOT alter `IsActive` (soft-delete flag).
- On Delete: cascade-deletes `ScheduledReportRun` rows.
- "Run Now" command: enqueues a one-off run (SERVICE_PLACEHOLDER until Hangfire wired) + inserts a `ScheduledReportRun(Status=RUNNING)` row, then returns a toast.
- "Duplicate" command: clones row with `ScheduleName = "{original} (copy)"` and `ScheduleStatus = PAUSED` so the user can edit safely.
- "Fix" action (when Status=ERROR): opens the Edit modal pre-filled — no separate flow, just reuses Edit.
- Tenant scoping: every query/mutation filters `CompanyId = currentUser.CompanyId`.

**Workflow**: None — schedule status is a server-managed flag, not a multi-stage approval lifecycle.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: `MASTER_GRID`
**Type Classification**: **Type 2** (entity with FKs + child collection + custom row actions). Not a FLOW because the create/edit form is a MODAL POPUP (not a `?mode=new/edit/read` route). The child `ScheduledReportRun` collection is read-only — written only by Run-Now and the (future) recurring job — so it does not need an inline editable child grid inside the form.

**Reason**: Mockup shows: grid + summary widgets + "+ New Schedule" button opening a modal → standard MASTER_GRID pattern. The history sub-grid is a separate read-only collapsible panel below the main grid (not a form-embedded child).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — for ScheduledReport
- [x] Child entity (3 files — entity + EF config + DTO) for ScheduledReportRun. NO CRUD endpoints (read-only via GetById's `.Include`).
- [x] Multi-FK validation (ValidateForeignKeyRecord × 3: Report, Branch, DonationPurpose)
- [x] Custom business-rule validators (conditional required fields by Frequency, custom date range, delivery-channel min-one, password-protect compatibility)
- [x] Toggle command — but extended to switch ScheduleStatus (`ACTIVE`↔`PAUSED`) NOT IsActive
- [x] Two custom commands beyond CRUD:
  - `RunScheduledReportNow` (SERVICE_PLACEHOLDER — inserts Run row + returns toast)
  - `DuplicateScheduledReport` (clones row with PAUSED status)
- [x] Summary query — `GetScheduledReportSummary` returns the 3 KPI values
- [x] Run history query — `GetScheduledReportRuns(scheduledReportId)` returns child rows for history panel
- [x] Cron expression helper — pure C# utility under `Base.Application.Helpers.CronHelper.cs` (new file)

**Frontend Patterns Required:**
- [x] AdvancedDataTable (Variant B — see Layout Variant in §⑥)
- [x] **Custom-built modal form** (NOT pure RJSF — see §⑫). Reason: conditional Day field, email-chip widget, nested toggle blocks, optgroup-grouped Report select exceed what GridFormSchema can express. The modal still uses standard `<Modal>` + react-hook-form + Zod schema.
- [x] Summary cards / count widgets — 3 KPI tiles above grid
- [x] Grid aggregation columns — `LastRunDisplay`, `NextRunDisplay`, `RecipientCount` server-projected
- [x] Inline expansion panel (Run History) below grid — toggled by row's "View History" dropdown action
- [x] Custom row-action buttons: Edit, Run Now, View History, Duplicate, Pause/Resume, Delete, Fix (when status=ERROR)
- [x] Email-chip input (multi-token entry with backspace-delete + validation per token)
- [x] Optgroup-rendering ApiSelectV2 variant for Report select
- [x] Timezone picker — start with a curated 5-option list (UTC+0/UTC+4/UTC+5:30/UTC+6/UTC+3) shown in mockup; expandable later to full IANA list
- [x] Status badge with three states: Active (green), Paused (amber), Error (red)
- [x] Report-type badge column (Standard / Custom / HTML — colored per mockup)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/reports/scheduled-reports.html` — this IS the design spec.

### Grid/List View

**Display Mode**: `table` (default — admin CRUD with 9 columns; cards would be wasteful)

**Layout Variant** (REQUIRED): **`widgets-above-grid+side-panel`**
- 3 summary stat cards stacked horizontally ABOVE the grid (mockup lines 689–714).
- A "Run History" panel toggled OPEN below the grid when user clicks the row's "View History" dropdown item (mockup lines 992–1059). Although the mockup renders it below (not beside), it behaves as a side-panel-like detail surface: it's secondary content tied to one selected row, scrolls into view on toggle, and has its own close button. FE Dev MUST use Variant B (`<ScreenHeader>` + widget components + `<DataTableContainer showHeader={false}>`) to avoid the double-header anti-pattern.

**Grid Columns** (in display order — matches mockup table head):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | # | (row index) | text | 50px | NO | Static row number |
| 2 | Report Name | reportName | text | auto | YES | Bold purple text, clickable → opens Edit modal |
| 3 | Type | reportTypeCode | badge | 100px | YES | Standard=blue, Custom=orange, HTML=purple |
| 4 | Frequency | frequencyDisplay | text | 130px | YES | Server-formatted: "Monthly (1st)", "Weekly (Mon)", "Daily", "Quarterly (1st)", "Yearly (Jan 15)" |
| 5 | Next Run | nextRunDisplay | text | 130px | YES | Server-formatted: "May 1, 8:00 AM" — "—" when Paused |
| 6 | Recipients | emailRecipients | text-truncate | 200px | NO | Truncated CSV: "board@ghf.org, cfo@ghf.org" |
| 7 | Last Run | lastRunDisplay | text+icon | 110px | YES | Date + green ✔ (Delivered) or red ✘ (Failed) |
| 8 | Status | scheduleStatus | badge | 90px | YES | Active=green / Paused=amber / Error=red |
| 9 | Actions | (custom) | action-cell | 220px | NO | See "Grid Actions" below |

**Search/Filter Fields**: `reportName` (text), `frequencyDisplay` (chip filter), `scheduleStatus` (chip filter), `reportTypeCode` (chip filter).

**Grid Actions** (per row — order matters):
- Always visible: **Edit** (opens modal in edit mode)
- Conditional visible:
  - When `scheduleStatus = ACTIVE`: **Run Now** (primary purple) + 3-dot dropdown
  - When `scheduleStatus = PAUSED`: **Resume** (green) + Edit + 3-dot
  - When `scheduleStatus = ERROR`: **Fix** (red — opens Edit modal) + Edit + 3-dot
- 3-dot dropdown items (always): **View History**, **Duplicate**, **Pause** (or omit if already paused), **Delete** (danger)

### Custom Modal Form (NOT pure RJSF — see §⑫)

> Custom React form with react-hook-form + Zod. Modal width 640px, max-height 85vh, scrollable body.

**Form Sections** (in order):
| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | (no title) | 1-col full-width | Report select (with optgroup), help-text under select |
| 2 | Report Parameters | 3-col grid | DateRangePreset, BranchId, DonationPurposeId |
| 2a | (if CUSTOM date range) | 2-col grid | CustomFromDate, CustomToDate |
| 3 | Schedule | 2-col grid | Frequency, conditional Day field (DayOfMonth / DayOfWeek / MonthOfYear) |
| 3a | (continued) | 2-col grid | ScheduleTime, Timezone |
| 4 | (no title) | 1-col full-width | OutputFormat select |
| 5 | Delivery | 1-col full-width | Three checkbox-with-sub-form rows: Email / Save to shared drive / In-app notification |
| 6 | Options | 1-col full-width | Three toggle-switch rows: SkipIfEmpty / IncludeComparison / PasswordProtect |

**Field Widget Mapping**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| ReportId | ApiSelectV2 **with optgroup** | "Select report" | required | Query: `GetReports` paginated; group rows by `reportTypeCode` (Standard / Custom / HTML). Below the select, show `Report.Description` as `help-text`. |
| DateRangePreset | select | — | required | Options: Last Week / Last Month / Last Quarter / Last Year / Custom |
| CustomFromDate | date | — | required if preset=CUSTOM | |
| CustomToDate | date | — | required if preset=CUSTOM, >= CustomFromDate | |
| BranchId | ApiSelectV2 | "All" (null) | optional | Query: `GetBranches` paginated. First option = "All branches" (sentinel null). |
| DonationPurposeId | ApiSelectV2 | "All" (null) | optional | Query: `GetDonationPurposes` paginated. First option = "All purposes" (sentinel null). |
| Frequency | select | — | required | Daily / Weekly / Monthly / Quarterly / Yearly |
| DayOfMonth | select | — | conditional | Visible when Frequency ∈ {Monthly, Quarterly, Yearly}. Options: 1st / 5th / 10th / 15th / 20th / Last day. Value=-1 for "Last day". |
| DayOfWeek | select | — | conditional | Visible when Frequency=Weekly. Options: Sun..Sat (0..6) |
| MonthOfYear | select | — | conditional | Visible when Frequency=Yearly. Options: Jan..Dec (1..12) — combine with DayOfMonth field for full date. |
| ScheduleTime | select | — | required | Options: 06:00 AM, 07:00 AM, 08:00 AM (default), 09:00 AM, 12:00 PM, 06:00 PM. Stored as `TimeOnly`. |
| Timezone | select | — | required | Options: UTC+0 London, UTC+4 Dubai (default), UTC+5:30 Mumbai, UTC+6 Dhaka, UTC+3 Nairobi. BE maps display→IANA. |
| OutputFormat | select | — | required | PDF (default) / Excel / CSV / HTML |
| DeliverByEmail | checkbox | — | toggles sub-form | Default checked. Sub-form contains EmailRecipients chips + EmailSubject + EmailBody. |
| EmailRecipients | **email-chip input** | "Add email..." | required when DeliverByEmail=true | Multi-token entry; backspace deletes last chip; comma/enter commits; per-token email regex. |
| EmailSubject | text | "Monthly Donation Summary - {month} {year}" | max 200 | Supports `{month}`, `{year}`, `{reportName}` placeholders. |
| EmailBody | textarea (2 rows) | "Please find attached the monthly donation summary report." | max 1000 | Same placeholders. |
| DeliverToSharedDrive | checkbox | — | toggles sub-form | Default unchecked. Sub-form: SharedDrivePath text input (required when checked). |
| DeliverInApp | checkbox | — | — | Default unchecked. No sub-form. |
| SkipIfEmpty | toggle-switch | — | — | Default OFF. Label: "Don't send if no data (skip empty reports)". |
| IncludeComparison | toggle-switch | — | — | Default ON (matches mockup checked state). Label: "Include comparison with previous period". |
| PasswordProtect | toggle-switch | — | — | Default OFF. Label: "Password-protect attachment". Disabled when OutputFormat ∈ {CSV, HTML}. |

**Modal Footer Actions**: Cancel (closes modal) / Save Schedule (purple primary).

### Page Widgets & Summary Cards

**Widgets**: 3 stat cards above grid (mockup lines 689–714).

| # | Widget Title | Value Source | Display Type | Position | Icon | Color |
|---|-------------|-------------|-------------|----------|------|-------|
| 1 | Active Schedules | `summary.activeCount` | count | Top-left | clock | Purple (`bg-purple-600` icon container, `text-white`) |
| 2 | Reports Delivered (This Month) | `summary.deliveredThisMonth` | count | Top-middle | paper-plane | Green (`bg-green-600` icon container, `text-white`) |
| 3 | Recipients | `summary.uniqueRecipientCount` | count | Top-right | users | Blue (`bg-blue-600` icon container, `text-white`) |

Subtitles (per [[feedback-widget-icon-badge-styling]]):
- Widget 1: "Next run: {nextRunFriendly}" (e.g., "Today, 8:00 PM") — driven by `summary.nextRunFriendly`.
- Widget 2: "{successRate}% success rate" — driven by `summary.successRatePct`.
- Widget 3: "{uniqueEmails} unique emails · {sharedDriveCount} shared drives" — driven by `summary.uniqueEmails` + `summary.sharedDriveCount`.

**Summary GQL Query**:
- Query name: `GetScheduledReportSummary`
- Returns: `ScheduledReportSummaryDto`
- Fields: `activeCount`, `deliveredThisMonth`, `successRatePct`, `uniqueRecipientCount`, `uniqueEmails`, `sharedDriveCount`, `nextRunFriendly`
- Added to `ScheduledReportQueries.cs` alongside `GetScheduledReports`/`GetScheduledReportById`.

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Frequency | Human-readable cadence string | Computed from Frequency + DayOfMonth / DayOfWeek / MonthOfYear | C# helper in `GetAll` projection: `CronHelper.FormatFrequency(...)` |
| Next Run | "May 1, 8:00 AM" or "—" | `NextRunDate` formatted in `Timezone` | LINQ projection: `s.NextRunDate.HasValue ? ToTzString(s.NextRunDate.Value, s.Timezone) : "—"` |
| Last Run | "Apr 1" + status icon | `LastRunDate` + `LastRunStatus` | Same projection pattern |
| Recipients (truncate display) | Truncated CSV string | `EmailRecipients` | FE-side truncate at 40 chars with title tooltip |

### Side Panels / Info Displays — Run History Panel

**Side Panel**: YES — Run History expansion panel (mockup lines 992–1059).

| Panel Section | Fields / Content | Trigger |
|--------------|------------------|---------|
| Run History header | "Run History: {Report Name}" + Close (×) button | Clicking 3-dot → "View History" on a row |
| Run History table | RunDate, Status, Duration, FileSize, Recipients sent, Actions (Download / Resend / Retry / View Error) | Auto-loaded on panel open via `GetScheduledReportRuns(scheduledReportId)` |

**Panel behavior**:
- One panel instance — opening on a new row replaces content.
- Empty state: "No runs yet — this schedule hasn't fired."
- Per-row actions:
  - **Download** — opens `FileUrl` in new tab (SERVICE_PLACEHOLDER if FileUrl null → toast).
  - **Resend** — re-sends emails (SERVICE_PLACEHOLDER).
  - **Retry** (visible when Status=FAILED) — re-runs (SERVICE_PLACEHOLDER).
  - **View Error** — toast with full `ErrorMessage` text.

### User Interaction Flow

1. **Page load** → header + 3 summary widgets + grid load in parallel (3 GQL queries: `GetScheduledReports`, `GetScheduledReportSummary`, plus FK lookups when modal opens).
2. **+ New Schedule** → modal opens with empty form, Frequency=Monthly preset.
3. **Fill form → Save Schedule** → BE validates conditional rules → server derives Cron + NextRunDate → grid refreshes → toast.
4. **Edit row** → click row name OR row's Edit button → modal opens pre-filled.
5. **Run Now** → confirm dialog → BE inserts ScheduledReportRun(RUNNING) + (SERVICE_PLACEHOLDER toast saying "Run queued — Hangfire wiring pending"). Grid LastRun column reflects within 30s.
6. **Pause** → confirm dialog → toggle ScheduleStatus → badge updates → Resume button replaces Pause for that row.
7. **Resume** → confirm dialog → toggle ScheduleStatus back to ACTIVE → NextRunDate recomputed.
8. **Duplicate** → row appears with `ScheduleName="{original} (copy)"` + Status=PAUSED → toast suggests "Edit duplicated schedule before resuming".
9. **Delete** → confirm dialog → soft-delete + cascade-soft-delete runs → row disappears.
10. **View History** → expansion panel opens below grid → loads child runs → user can Download / Resend / Retry / View Error per run.
11. **Fix (Error state)** → opens Edit modal pre-filled (same as Edit) — user adjusts and Save.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity. Use when copying from code-reference files.

**Canonical Reference**: ContactType (MASTER_GRID) for the standard CRUD scaffold + DocumentType for the 3-FK pattern. **Sibling reference**: ReportFavorite (#99) — same `rep` schema + `Report` group naming.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | ScheduledReport | Entity/class name |
| contactType | scheduledReport | Variable/field names |
| ContactTypeId | ScheduledReportId | PK field |
| ContactTypes | ScheduledReports | Table name, collection names |
| contact-type | scheduled-report | (folder/import readable) |
| contacttype | scheduledreport | FE folder, route segment, file names |
| CONTACTTYPE | SCHEDULEDREPORT | Grid code, menu code, decorator constant |
| corg | rep | DB schema |
| Corg | Report | Backend group prefix |
| CorgModels | ReportModels | Entity namespace folder |
| CorgConfigurations | ReportConfigurations | EF config folder |
| CorgSchemas | ReportSchemas | DTO namespace folder |
| CorgBusiness | ReportBusiness | Business folder |
| Corg (EndPoints folder) | Report | API EndPoints folder |
| DecoratorCorgModules | DecoratorReportModules | Decorator class name |
| CONTACT | RA_REPORTS | Parent menu code |
| CRM | REPORTAUDIT | Module code |
| crm/contact/contacttype | reportaudit/reports/scheduledreport | FE route path |
| corg-service | report-service | FE service folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Exact files to create, with computed paths. No guessing.

### Backend Files (Parent: 11 files; Child: 3 files; Custom: 5 files)

| # | File | Path |
|---|------|------|
| 1 | Entity (parent) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ReportModels/ScheduledReport.cs` |
| 2 | Entity (child) | `PSS_2.0_Backend/.../Base.Domain/Models/ReportModels/ScheduledReportRun.cs` |
| 3 | EF Config (parent) | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/ReportConfigurations/ScheduledReportConfiguration.cs` |
| 4 | EF Config (child) | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/ReportConfigurations/ScheduledReportRunConfiguration.cs` |
| 5 | Schemas/DTOs | `PSS_2.0_Backend/.../Base.Application/Schemas/ReportSchemas/ScheduledReportSchemas.cs` (contains `ScheduledReportRequestDto`, `ScheduledReportResponseDto`, `ScheduledReportRunResponseDto`, `ScheduledReportSummaryDto`, `RunNowRequestDto`, `DuplicateScheduledReportRequestDto`) |
| 6 | Create Command | `PSS_2.0_Backend/.../Base.Application/Business/ReportBusiness/ScheduledReports/CreateCommand/CreateScheduledReport.cs` |
| 7 | Update Command | `.../ScheduledReports/UpdateCommand/UpdateScheduledReport.cs` |
| 8 | Delete Command | `.../ScheduledReports/DeleteCommand/DeleteScheduledReport.cs` |
| 9 | Toggle Command | `.../ScheduledReports/ToggleCommand/ToggleScheduledReportStatus.cs` (switches ScheduleStatus ACTIVE↔PAUSED — NOT IsActive) |
| 10 | RunNow Command | `.../ScheduledReports/RunNowCommand/RunScheduledReportNow.cs` (SERVICE_PLACEHOLDER) |
| 11 | Duplicate Command | `.../ScheduledReports/DuplicateCommand/DuplicateScheduledReport.cs` |
| 12 | GetAll Query | `.../ScheduledReports/GetAllQuery/GetScheduledReports.cs` (paginated) |
| 13 | GetById Query | `.../ScheduledReports/GetByIdQuery/GetScheduledReportById.cs` (Includes Report, Branch, DonationPurpose, Runs ordered DESC limit 50) |
| 14 | Summary Query | `.../ScheduledReports/GetSummaryQuery/GetScheduledReportSummary.cs` |
| 15 | Runs Query | `.../ScheduledReports/GetRunsQuery/GetScheduledReportRuns.cs` |
| 16 | Mutations endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/Report/Mutations/ScheduledReportMutations.cs` |
| 17 | Queries endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/Report/Queries/ScheduledReportQueries.cs` |
| 18 | Cron helper (new file) | `PSS_2.0_Backend/.../Base.Application/Helpers/CronHelper.cs` — pure static helpers: `BuildCron(Frequency, DayOfMonth, DayOfWeek, MonthOfYear, ScheduleTime)`, `ComputeNextRun(cron, timezone, fromUtc)`, `FormatFrequency(...)`, `MapTimezoneDisplayToIana(...)`. |
| 19 | EF migration | (run by user) `dotnet ef migrations add Add_ScheduledReport_Table --project Base.Infrastructure --startup-project Base.API --context ApplicationDbContext` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Data/Persistence/IReportDbContext.cs` | `DbSet<ScheduledReport> ScheduledReports`, `DbSet<ScheduledReportRun> ScheduledReportRuns` |
| 2 | `Base.Infrastructure/Data/Persistence/ReportDbContext.cs` | Same two DbSets + entity configurations applied |
| 3 | `Base.Application/Extensions/DecoratorProperties.cs` | `, ScheduledReport = "SCHEDULEDREPORT"` + `, ScheduledReportRun = "SCHEDULEDREPORTRUN"` to `DecoratorReportModules` |
| 4 | `Base.Application/Mappings/ReportMappings.cs` | Mapster mappings for ScheduledReport, ScheduledReportRun, all DTOs (Request→Entity + Entity→Response + Summary projection) |

### Frontend Files (8 files — 6 base MASTER_GRID + 2 extras for child grid + custom modal)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/report-service/ScheduledReportDto.ts` |
| 2 | GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/report-queries/ScheduledReportQuery.ts` (`GetScheduledReports`, `GetScheduledReportById`, `GetScheduledReportSummary`, `GetScheduledReportRuns`) |
| 3 | GQL Mutation | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/report-mutations/ScheduledReportMutation.ts` (Create, Update, Delete, ToggleStatus, RunNow, Duplicate) |
| 4 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/reportaudit/reports/scheduledreport.tsx` |
| 5 | Index Page Component | `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/scheduledreport/index-page.tsx` |
| 6 | Custom Modal Form | `.../scheduledreport/schedule-modal.tsx` (NOT RJSF — react-hook-form + Zod) |
| 7 | Run History Panel | `.../scheduledreport/run-history-panel.tsx` |
| 8 | Email-Chip Widget | `.../scheduledreport/email-chip-input.tsx` (reusable component — check `presentation/components/custom-components/` first, only create if not already there) |
| 9 | Route Page | `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/scheduledreport/page.tsx` (**REPLACE** existing UnderConstruction stub) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `presentation/pages/reportaudit/reports/index.ts` | Re-export `ScheduledReportPageConfig` (mirror #154 GenerateReport pattern) |
| 2 | Entity operations registry | Add `SCHEDULEDREPORT` operations config |
| 3 | Operations config index | Import + register operations |
| 4 | Component column / cell-renderer registry | Verify `badge` renderer handles 3 colors (Active=green, Paused=amber, Error=red) + type-badge 3 colors (Standard=blue, Custom=orange, HTML=purple). If renderer needs new entries, add them. |
| 5 | (Sidebar menu) — **SKIP**: `SCHEDULEDREPORT` is already seeded under `RA_REPORTS` per MODULE_MENU_REFERENCE.md line 351. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: FULL

MenuName: Scheduled Reports
MenuCode: SCHEDULEDREPORT
ParentMenu: RA_REPORTS
Module: REPORTAUDIT
MenuUrl: reportaudit/reports/scheduledreport
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT

GridFormSchema: GENERATE
GridCode: SCHEDULEDREPORT

# Note: MenuCode SCHEDULEDREPORT is already seeded under RA_REPORTS (MenuId 380, OrderBy 7).
# DB seed should be IDEMPOTENT — WHERE NOT EXISTS guards on Menu / MenuCapability / RoleCapability rows.
# Add Grid + GridFormSchema + MenuCapability rows for the new capabilities not already present.
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose before BE is even built.

**GraphQL Types:**
- Query type: `ScheduledReportQueries`
- Mutation type: `ScheduledReportMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `GetScheduledReports` | `PaginatedApiResponse<IEnumerable<ScheduledReportResponseDto>>` | searchText, pageNo, pageSize, sortField, sortDir, scheduleStatus, frequency, reportTypeCode |
| `GetScheduledReportById` | `BaseApiResponse<ScheduledReportResponseDto>` | scheduledReportId |
| `GetScheduledReportSummary` | `BaseApiResponse<ScheduledReportSummaryDto>` | (none — current user/company implicit) |
| `GetScheduledReportRuns` | `PaginatedApiResponse<IEnumerable<ScheduledReportRunResponseDto>>` | scheduledReportId, pageNo, pageSize |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `CreateScheduledReport` | `ScheduledReportRequestDto` | `int` (new ID) |
| `UpdateScheduledReport` | `ScheduledReportRequestDto` (with scheduledReportId) | `int` |
| `DeleteScheduledReport` | `scheduledReportId` | `int` |
| `ToggleScheduledReportStatus` | `scheduledReportId` | `int` (returns new status code) |
| `RunScheduledReportNow` | `RunNowRequestDto { scheduledReportId }` | `int` (new ScheduledReportRunId) |
| `DuplicateScheduledReport` | `DuplicateScheduledReportRequestDto { scheduledReportId }` | `int` (new ScheduledReportId) |

**Response DTO Fields** (what FE receives — `ScheduledReportResponseDto`):
| Field | Type | Notes |
|-------|------|-------|
| scheduledReportId | number | PK |
| reportId | number | FK |
| reportName | string | Flattened from Report.ReportName |
| reportTypeCode | string | Flattened from Report.ReportType.MasterDataCode (STANDARD/CUSTOM/HTML) |
| scheduleName | string \| null | Optional override |
| frequency | string | Enum-string |
| frequencyDisplay | string | Server-formatted: "Monthly (1st)" etc |
| dayOfMonth | number \| null | |
| dayOfWeek | number \| null | |
| monthOfYear | number \| null | |
| scheduleTime | string | ISO "HH:mm" |
| timezone | string | IANA |
| timezoneDisplay | string | "UTC+4 Dubai" |
| cronExpression | string | Server-derived |
| outputFormat | string | |
| dateRangePreset | string | |
| customFromDate | string \| null | ISO |
| customToDate | string \| null | ISO |
| branchId | number \| null | |
| branchName | string \| null | Flattened |
| donationPurposeId | number \| null | |
| donationPurposeName | string \| null | Flattened |
| parametersJson | string \| null | |
| deliverByEmail | boolean | |
| emailRecipients | string \| null | CSV |
| recipientCount | number | Derived count |
| emailSubject | string \| null | |
| emailBody | string \| null | |
| deliverToSharedDrive | boolean | |
| sharedDrivePath | string \| null | |
| deliverInApp | boolean | |
| skipIfEmpty | boolean | |
| includeComparison | boolean | |
| passwordProtect | boolean | |
| scheduleStatus | string | ACTIVE / PAUSED / ERROR |
| lastRunDate | string \| null | ISO |
| lastRunStatus | string \| null | |
| lastRunError | string \| null | |
| lastRunDisplay | string \| null | "Apr 1" |
| nextRunDate | string \| null | ISO |
| nextRunDisplay | string \| null | "May 1, 8:00 AM" or "—" |
| isActive | boolean | Inherited |
| createdDate | string | Inherited |
| modifiedDate | string \| null | Inherited |

**ScheduledReportRunResponseDto fields**: `scheduledReportRunId`, `scheduledReportId`, `runDate` (ISO), `status`, `durationSeconds`, `fileSizeBytes`, `fileSizeDisplay` ("245 KB"), `fileUrl`, `recipientsSent`, `errorMessage`, `runDateDisplay` ("Apr 1, 2026, 8:00 AM").

**ScheduledReportSummaryDto fields**: `activeCount`, `deliveredThisMonth`, `successRatePct`, `uniqueRecipientCount`, `uniqueEmails`, `sharedDriveCount`, `nextRunFriendly`.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reports/scheduledreport` (replaces UnderConstruction stub)
- [ ] `pnpm tsc --noEmit` — no errors in new files
- [ ] EF migration generates with no warnings; `psql` smoke-applies the migration

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 9 columns and the seeded grid configuration
- [ ] Summary widgets show 3 KPI tiles with correct colors + subtitles per [[feedback-widget-icon-badge-styling]]
- [ ] Search/filter chips: Frequency, Status, Report Type work
- [ ] **+ New Schedule** opens modal; conditional Day field swaps as Frequency changes (Monthly→DayOfMonth, Weekly→DayOfWeek, Yearly→MonthOfYear+DayOfMonth)
- [ ] Report select renders OPTGROUPs (Standard / Custom / HTML)
- [ ] Email chip input: type + comma → chip, backspace → remove last, paste comma-list → bulk add, invalid token rejected on commit
- [ ] CUSTOM date-range preset reveals CustomFromDate/CustomToDate row
- [ ] At-least-one delivery channel client-side + server-side validation fires
- [ ] PasswordProtect toggle disabled when OutputFormat ∈ {CSV, HTML}
- [ ] Save Schedule → BE writes row → grid refreshes → toast → modal closes
- [ ] Edit pre-fills all sections correctly
- [ ] **Toggle (Pause)** → badge changes amber → Resume button replaces Run Now
- [ ] **Resume** → badge changes green → NextRunDate recomputed
- [ ] **Run Now** → confirm → toast says "Run queued — Hangfire wiring pending" → child run row inserted RUNNING
- [ ] **Duplicate** → row appears `(copy)` PAUSED → toast prompts user to edit
- [ ] **Delete** → soft-delete cascades to child runs → row disappears
- [ ] **View History** → expansion panel opens → child runs render Download / Resend / Retry / View Error actions
- [ ] Right-aligned: nothing relevant (no amount fields per [[feedback-amount-field-alignment]] guidance)
- [ ] All dates: stored UTC, rendered in user's timezone per [[feedback-db-utc-only]]
- [ ] Date columns in PG are `timestamp with time zone`; no `Kind=Unspecified` errors
- [ ] Permissions: BUSINESSADMIN role can do all actions

**DB Seed Verification:**
- [ ] Menu `SCHEDULEDREPORT` still appears in sidebar under RA_REPORTS (already seeded — verify no duplicate row written)
- [ ] Seed adds NEW MenuCapability rows (READ/CREATE/MODIFY/DELETE/TOGGLE/EXPORT/ISMENURENDER) idempotently
- [ ] RoleCapability for BUSINESSADMIN seeded with full grants
- [ ] Grid row + GridFormSchema generated (even though form is custom-built, seed the GridFormSchema for fallback / future RJSF migration)
- [ ] All seed rows guarded by `WHERE NOT EXISTS`

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### Architectural

- **First MASTER_GRID under `rep` schema** — sets the pattern. Follow the namespace/folder conventions of ReportFavorite (which is also under `rep` but is a leaf utility entity, not a full screen). Group prefix is **`Report`** (e.g., `ReportModels`, `ReportConfigurations`, `ReportSchemas`, `ReportBusiness`, EndPoints folder `Report`, decorator class `DecoratorReportModules`). DO NOT use `Rep` as the group prefix.
- **MenuCode SCHEDULEDREPORT is ALREADY SEEDED** under RA_REPORTS (MenuId 380, OrderBy 7 per `MODULE_MENU_REFERENCE.md` line 351). Do NOT insert a duplicate Menu row. Seed only MenuCapabilities + RoleCapabilities + Grid + GridFormSchema (with WHERE NOT EXISTS guards).
- **Status flag distinction**: This screen has TWO flags that look similar but mean different things:
  - `IsActive` (inherited soft-delete flag) — only the Delete action touches it.
  - `ScheduleStatus` (domain-specific) — Active / Paused / Error. The Toggle and Run-Now flows manipulate this.
  - The Toggle command must NOT modify IsActive — it switches ScheduleStatus.
- **Tenant scoping**: Although `Entity` base provides CompanyId via audit fields, ScheduledReport stores its own explicit CompanyId column AND every query must filter on the current user's company. Same pattern as ReportFavorite per `ReportCatalogQuery` precedent.

### Form Design — NOT pure RJSF

- **The modal form is CUSTOM-BUILT (react-hook-form + Zod)**, NOT RJSF rendered from GridFormSchema. Reasons:
  1. Conditional Day field (Monthly/Weekly/Yearly) requires programmatic schema switching that GridFormSchema can't express cleanly.
  2. Email-chip multi-token input has no GridFormSchema widget equivalent.
  3. Nested checkbox-with-sub-form blocks for delivery channels don't map to GridFormSchema.
  4. OPTGROUP-grouped Report select (Standard/Custom/HTML) needs custom ApiSelectV2 variant.
- We STILL seed GridFormSchema=GENERATE in DB seed for grid metadata consistency + future RJSF migration if the codebase adds the missing widgets.
- The FE Developer should reference the SavedFilter Run modal (#27, used by Report Catalog #99) for the dynamic-form-with-conditional-fields precedent — different schema mechanism but same pattern of "modal with conditional fields driven by client state."

### Date/Time Handling

- `ScheduleTime` stored as PG `time` (TimeOnly in C#) — bare time, no date component.
- `Timezone` stored as IANA id (e.g., `Asia/Dubai`). The 5 display labels in the mockup map to: London=`Europe/London`, Dubai=`Asia/Dubai`, Mumbai=`Asia/Kolkata`, Dhaka=`Asia/Dhaka`, Nairobi=`Africa/Nairobi`. Helper method `CronHelper.MapTimezoneDisplayToIana(string)` does the mapping; the reverse map for display is also there.
- `NextRunDate`, `LastRunDate`, `RunDate`, `CustomFromDate`, `CustomToDate` — all `DateTime` with `Kind=Utc` per [[feedback-db-utc-only]]. NEVER pass `DateTime.Today` into any EF predicate. Server computes `NextRunDate` by `CronHelper.ComputeNextRun(cron, timezone, DateTime.UtcNow)`.

### Cron Expression Generation

- Cron generated server-side from form fields:
  - DAILY → `0 m h * * *` (where h = ScheduleTime hour, m = minute)
  - WEEKLY → `0 m h * * d` (d = DayOfWeek)
  - MONTHLY → `0 m h dom * *` (dom = DayOfMonth, or `L` for last-day sentinel `-1`)
  - QUARTERLY → `0 m h dom 1,4,7,10 *`
  - YEARLY → `0 m h dom moy *` (moy = MonthOfYear)
- Cron is timezone-anchored: the BE stores the cron in the user's timezone AND the IANA tz. Hangfire (when wired) accepts both.
- For V1 (Hangfire NOT wired), the cron column is informational only — populated for future use.

### Service Dependencies (UI-only — no backend service implementation)

> Everything shown in the mockup is in scope. The items below are full UI implementations whose handler is a mock toast / no-op, because the backing service does not exist yet.

- ⚠ **SERVICE_PLACEHOLDER — Recurring job scheduler**: There is NO Hangfire or alternative recurring-job infrastructure in the codebase (verified via grep — zero Hangfire references, no `IBackgroundJobClient`, no NuGet ref). The Create/Update/Toggle/Delete handlers persist the schedule row + cron expression, but no job is actually registered to fire. Acceptance criterion is "schedule row written correctly"; actual firing is deferred to a future infrastructure ticket.
- ⚠ **SERVICE_PLACEHOLDER — Report generation engine**: While Generate Report (#154) is COMPLETED, its current implementation runs interactively. There is no headless renderer that can be invoked server-side without a browser. The Run-Now mutation inserts a `ScheduledReportRun(RUNNING)` row + returns a mocked FileUrl in the toast.
- ⚠ **SERVICE_PLACEHOLDER — Email delivery (SMTP)**: EmailProviderConfig (#88-ish) presumably persists provider creds, but no `ISmtpClient` / `IEmailDelivery` service is wired. EmailRecipients/Subject/Body persist; actual sending is mocked.
- ⚠ **SERVICE_PLACEHOLDER — Shared-drive upload**: No `IFileStorage` / S3 / SharePoint adapter is in the codebase. SharedDrivePath persists; actual upload is mocked.
- ⚠ **SERVICE_PLACEHOLDER — In-app notification**: Notification infra exists (Notification entity) but there's no automated emitter on report completion. Flag persists; actual notification is mocked.
- ⚠ **SERVICE_PLACEHOLDER — Output file generation (PDF/Excel/CSV/HTML)**: PDF/Excel renderers don't exist for the catalog reports. The Run-Now handler returns a mock FileUrl.
- ⚠ **SERVICE_PLACEHOLDER — Password-protected attachments**: Requires the file renderer above + zip-with-password. Flag persists; no actual encryption.
- ⚠ **SERVICE_PLACEHOLDER — Download/Resend/Retry per run**: All three Run History panel actions return toasts.

**Full UI must be built** (buttons, side panels, forms, modals, interactions, validation). ONLY the handlers for the external-service calls are mocked. Persistence (every form field → DB column) IS in scope and tested.

### Sibling-Screen Coordination

- **Report Catalog (#99) — Schedule modal**: After this screen is built, update #99's Schedule modal to navigate to `/reportaudit/reports/scheduledreport?reportId={reportId}` (pre-fill the Report select). That cross-link is OUT OF SCOPE for this build but should be a NEXT-STEP note in the build summary.
- **Run History query reuse**: The `GetScheduledReportRuns` query may later be extended to power a global "All Runs" audit view (#???). Keep its DTO shape stable.

### Naming Caveats — Verify Before Use ([[feedback-verify-properties]])

- Display field on Report is `ReportName` (verified — NOT `Name`).
- Display field on Branch is `BranchName` (verified).
- Display field on DonationPurpose is `DonationPurposeName` (verified).
- Audit timestamp fields are `CreatedDate` / `ModifiedDate` (NOT `CreatedAt`/`ModifiedAt`).
- GraphQL paginated query names are `GetReports` / `GetBranches` / `GetDonationPurposes` — NOT `GetAllReportList` etc. The naming convention shifted in newer modules.

### Style Compliance ([[feedback-ui-uniformity]] + [[feedback-widget-icon-badge-styling]])

- Use Tailwind design tokens — no hex / px inline styles.
- Widget icon containers: solid `bg-{purple,green,blue}-600` + `text-white`. Subtitles in `text-muted-foreground` is OK for the small-text subtitle (it's not a chip/badge).
- Status badges (Active/Paused/Error) and Type badges (Standard/Custom/HTML) — solid `bg-X-600` + `text-white` (per the widget styling memory, badges follow the same rule).
- Skeleton sized to match real content during query loads — match the grid row height + the 3 KPI tile heights.
- Form Save button gated on `formState.isValid` per [[feedback-form-create-button-enablement]].

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Session 1 | MED | BE/Helpers | `CronHelper.ComputeNextRun` returns a simplified offset-based approximation (daily +1, weekly +7, monthly/quarterly/yearly +30). Cronos NuGet is available but unused — replace with `CronExpression.Parse(cron).GetNextOccurrence(fromUtc, tz)` when Hangfire is wired. NextRunDate column is informational for V1. | OPEN |
| ISSUE-2 | Session 1 | LOW | BE/Mapster | `<ScheduledReport, ScheduledReportResponseDto>` Mapster config has its computed-field `.Map()` calls ignored to avoid Mapster type-inference ambiguity; computed columns (frequencyDisplay, nextRunDisplay, lastRunDisplay, fileSizeDisplay, recipientCount, timezoneDisplay) are populated via in-handler LINQ `.Select(...)` projections instead. Matches sibling `GetHtmlReportTemplatesQuery` / `GetReportCatalog` pattern. | OPEN |
| ISSUE-3 | Session 1 | LOW | BE/Queries | `GetScheduledReportSummary` computes `uniqueRecipientCount` and `nextRunFriendly` in-memory (after `.ToListAsync`) rather than as SQL aggregates — required for correct CSV-token parsing and timezone-aware ordering. Acceptable for admin-only screen with low row count. | OPEN |
| ISSUE-4 | Session 1 | LOW | FE/ApiSelectV2 | No optgroup variant of `ApiSelectV2` exists. Report select is a custom native `<select>` with client-side optgroup grouping (Standard/Custom/HTML) after fetching `GetReports`. Upgrade to optgroup-capable `ApiSelectV2` if/when added. | OPEN |
| ISSUE-5 | Session 1 | LOW | FE/Grid Actions | Run Now / Duplicate per-row actions go via the entity-operations registry + grid `action-cell` infrastructure, not via a hand-crafted custom row-actions cell. View History opens the panel via the grid's row-select event. Confirm runtime behavior matches mockup expectations during user E2E test. | OPEN |
| ISSUE-6 | Session 1 | LOW | XLink | Report Catalog (#99) Schedule modal is currently SERVICE_PLACEHOLDER. Update it to navigate to `/{lang}/reportaudit/reports/scheduledreport?reportId={reportId}` to pre-fill the Report select. NEXT-STEP, out-of-scope for this build. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-15 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt — first MASTER_GRID screen under `rep` schema. Replaces UnderConstruction stub at `app/[lang]/reportaudit/reports/scheduledreport/page.tsx`.
- **Files touched**:
  - BE (19 created):
    - `Base.Domain/Models/ReportModels/ScheduledReport.cs` (created)
    - `Base.Domain/Models/ReportModels/ScheduledReportRun.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/ScheduledReportConfiguration.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/ScheduledReportRunConfiguration.cs` (created)
    - `Base.Application/Schemas/ReportSchemas/ScheduledReportSchemas.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/CreateCommand/CreateScheduledReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/UpdateCommand/UpdateScheduledReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/DeleteCommand/DeleteScheduledReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/ToggleCommand/ToggleScheduledReportStatus.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/RunNowCommand/RunScheduledReportNow.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/DuplicateCommand/DuplicateScheduledReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/GetAllQuery/GetScheduledReports.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/GetByIdQuery/GetScheduledReportById.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/GetSummaryQuery/GetScheduledReportSummary.cs` (created)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/GetRunsQuery/GetScheduledReportRuns.cs` (created)
    - `Base.Application/Helpers/CronHelper.cs` (created)
    - `Base.API/EndPoints/Report/Mutations/ScheduledReportMutations.cs` (created)
    - `Base.API/EndPoints/Report/Queries/ScheduledReportQueries.cs` (created)
  - BE wiring (4 modified):
    - `Base.Application/Data/Persistence/IReportDbContext.cs` (modified — added ScheduledReports + ScheduledReportRuns DbSets)
    - `Base.Infrastructure/Data/Persistence/ReportDbContext.cs` (modified — same)
    - `Base.Application/Extensions/DecoratorProperties.cs` (modified — added ScheduledReport + ScheduledReportRun constants)
    - `Base.Application/Mappings/ReportMappings.cs` (modified — Mapster configs)
  - FE (12 created):
    - `domain/entities/report-service/ScheduledReportDto.ts` (created)
    - `infrastructure/gql-queries/report-queries/ScheduledReportQuery.ts` (created)
    - `infrastructure/gql-mutations/report-mutations/ScheduledReportMutation.ts` (created)
    - `presentation/pages/reportaudit/reports/scheduledreport.tsx` (created)
    - `presentation/components/page-components/reportaudit/reports/scheduledreport/index-page.tsx` (created)
    - `presentation/components/page-components/reportaudit/reports/scheduledreport/scheduled-report-widgets.tsx` (created)
    - `presentation/components/page-components/reportaudit/reports/scheduledreport/schedule-modal.tsx` (created)
    - `presentation/components/page-components/reportaudit/reports/scheduledreport/run-history-panel.tsx` (created)
    - `presentation/components/page-components/reportaudit/reports/scheduledreport/email-chip-input.tsx` (created)
    - `presentation/components/page-components/reportaudit/reports/scheduledreport/index.ts` (created)
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/schedule-status-badge.tsx` (created)
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/report-type-code-badge.tsx` (created)
  - FE wiring (9 modified):
    - `domain/entities/report-service/index.ts` (modified — re-export)
    - `infrastructure/gql-queries/report-queries/index.ts` (modified — re-export)
    - `infrastructure/gql-mutations/report-mutations/index.ts` (modified — re-export)
    - `presentation/pages/reportaudit/reports/index.ts` (modified — re-export ScheduledReportPageConfig)
    - `application/configs/data-table-configs/report-service-entity-operations.ts` (modified — added SCHEDULEDREPORT entity ops)
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (modified — re-export badges)
    - `presentation/components/custom-components/data-tables/advanced/data-table-column-types/component-column.tsx` (modified — import + 2 case handlers)
    - `presentation/components/custom-components/data-tables/basic/data-table-column-types/component-column.tsx` (modified — same)
    - `presentation/components/custom-components/data-tables/flow/data-table-column-types/component-column.tsx` (modified — same)
    - `app/[lang]/reportaudit/reports/scheduledreport/page.tsx` (modified — replaced UnderConstruction with ScheduledReportPageConfig)
  - DB seed:
    - `Base.Infrastructure/sql-scripts-dyanmic/ScheduledReport-sqlscripts.sql` (created — 6 STEPs idempotent; MenuCapabilities + RoleCapabilities + Grid + Fields + GridFields + GridFormSchema; orchestrator updated columns 3 and 8 to use `report-type-code-badge` and `schedule-status-badge` renderers after FE confirmed registration in all 3 grid registries)
- **Deviations from spec**:
  - BE swapped `MasterDataCode` → `DataValue` because the actual `MasterData` entity exposes `DataValue` (not `MasterDataCode`). FE badge components uppercase the input so STANDARD/CUSTOM/HTML resolves regardless of casing.
  - Mapster computed-field mappings replaced with in-handler LINQ `.Select(...)` projections (see ISSUE-2) — matches sibling `GetReportCatalog` precedent.
  - `CronHelper.ComputeNextRun` is a simplified offset stub pending Hangfire wiring (see ISSUE-1).
  - Report select implemented as native `<select>` with client-side optgroup grouping (no ApiSelectV2 optgroup variant exists — see ISSUE-4).
  - DB seed grid columns 3 (reportTypeCode) and 8 (scheduleStatus) initially seeded with `'text'` by BE for safety; orchestrator updated to `report-type-code-badge` / `schedule-status-badge` after confirming registration in advanced/basic/flow grid registries.
- **Known issues opened**: ISSUE-1 through ISSUE-6 (see table above).
- **Known issues closed**: None.
- **Next step**: (none — COMPLETED). User must run `dotnet ef migrations add Add_ScheduledReport_Table --project Base.Infrastructure --startup-project Base.API --context ApplicationDbContext`, then `dotnet ef database update`, then apply `sql-scripts-dyanmic/ScheduledReport-sqlscripts.sql`, then `pnpm dev` and runtime-verify CRUD + Toggle + RunNow + Duplicate + View History. After this screen ships, update Report Catalog (#99) Schedule modal cross-link (ISSUE-6).

### Session 2 — 2026-05-15 — ENHANCE — COMPLETED

- **Scope**: FK refactor — convert 9 enum-like string fields to `sett.MasterDatas` lookups (user-requested after initial build). Adds 7 new MasterDataTypes (REPORTFREQUENCY, DAYOFWEEK, MONTHOFYEAR, REPORTOUTPUTFORMAT, REPORTDATERANGEPRESET, REPORTSCHEDULESTATUS, REPORTRUNSTATUS) + ~43 MasterData rows. Reuses existing TIMEZONE TypeCode. `DayOfMonth` (int 1–31) stays primitive per design discussion.
- **Files touched**:
  - BE (5 modified, 1 created):
    - `Base.Domain/Models/ReportModels/ScheduledReport.cs` (modified — 8 new FK ids + nav properties: FrequencyId, DayOfWeekId, MonthOfYearId, TimezoneId, OutputFormatId, DateRangePresetId, ScheduleStatusId, LastRunStatusId)
    - `Base.Domain/Models/ReportModels/ScheduledReportRun.cs` (modified — StatusId FK replaces string Status)
    - `Base.Domain/Models/SettingModels/MasterData.cs` (modified — 9 new back-nav ICollection properties)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/ScheduledReportConfiguration.cs` (modified — 8 new HasOne...WithMany...HasForeignKey relationships + indices)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/ScheduledReportRunConfiguration.cs` (modified — StatusId relationship)
    - `Base.Application/Schemas/ReportSchemas/ScheduledReportSchemas.cs` (modified — Request takes FK ids; Response carries Id + Code + Name triplets for each FK)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/CreateCommand/CreateScheduledReport.cs` (modified — resolves DataValues via MasterDataLookupHelper, applies conditional validation in handler, looks up ACTIVE MasterDataId for default ScheduleStatus)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/UpdateCommand/UpdateScheduledReport.cs` (modified — same pattern; preserves ScheduleStatusId/LastRunStatusId)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/ToggleCommand/ToggleScheduledReportStatus.cs` (modified — loads ScheduleStatus + Timezone navs, looks up target MasterDataId by code)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/RunNowCommand/RunScheduledReportNow.cs` (modified — looks up RUNNING MasterDataId)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/DuplicateCommand/DuplicateScheduledReport.cs` (modified — looks up PAUSED MasterDataId; clones FK ids)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/GetAllQuery/GetScheduledReports.cs` (modified — projects FK Code+Name via EF JOIN; computes display fields client-side post-`ApplyGridFeatures`)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/GetByIdQuery/GetScheduledReportById.cs` (modified — Include all FK navs; project Code+Name; compute display fields)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/GetRunsQuery/GetScheduledReportRuns.cs` (modified — projects Status.DataValue/DataName)
    - `Base.Application/Business/ReportBusiness/ScheduledReports/GetSummaryQuery/GetScheduledReportSummary.cs` (modified — filters by ScheduleStatus.DataValue/Run.Status.DataValue; success-rate now keyed on REPORTRUNSTATUS=SUCCESS, not legacy "DELIVERED")
    - `Base.Application/Helpers/CronHelper.cs` (modified — BuildCron/FormatFrequency take string codes; internal maps for DAYOFWEEK/MONTHOFYEAR int↔code conversion)
    - `Base.Application/Helpers/MasterDataLookupHelper.cs` (created — `GetIdByCodeAsync(typeCode, dataValue)` + `GetCodeByIdAsync(masterDataId)` helpers)
    - `Base.Application/Mappings/ReportMappings.cs` (modified — Mapster Ignores expanded to cover new Code+Name fields)
  - FE (4 modified):
    - `domain/entities/report-service/ScheduledReportDto.ts` (modified — Request/Response now use FK ids + Code+Name fields; Run DTO uses StatusId/Code/Name)
    - `infrastructure/gql-queries/report-queries/ScheduledReportQuery.ts` (modified — query selects all new FK Id+Code+Name fields)
    - `infrastructure/gql-mutations/report-mutations/ScheduledReportMutation.ts` (modified — Create/Update mutations take FK Int! variables)
    - `presentation/components/page-components/reportaudit/reports/scheduledreport/schedule-modal.tsx` (modified — replaced 6 hardcoded option arrays with `useMasterDataByTypeCode(typeCode)` hook backed by `masterDatasByTypeCode` GQL query; form fields switched to FK ids; reusable `MasterDataSelect` component; conditional logic keyed on codeById lookup map; virtual `_frequencyCode`/`_outputFormatCode`/`_dateRangePresetCode` fields drive Zod superRefine)
    - `presentation/components/page-components/reportaudit/reports/scheduledreport/run-history-panel.tsx` (modified — StatusBadge uses statusCode; SUCCESS/FAILED/RUNNING colors; Resend visibility keyed on SUCCESS not legacy DELIVERED)
  - DB seed (1 modified):
    - `sql-scripts-dyanmic/ScheduledReport-sqlscripts.sql` (modified — new STEP 0 prepends 7 MasterDataType inserts + 43 MasterData rows: 6 frequencies, 7 days-of-week, 12 months, 4 output formats, 8 date-range presets, 3 schedule statuses, 3 run statuses. All guarded with WHERE NOT EXISTS on (TypeCode, DataValue))
- **Deviations from spec**:
  - Added `MasterDataLookupHelper` (new shared helper) instead of duplicating the volunteer-page pattern inline in 6 handlers. Same lookup semantics.
  - Conditional validations (DayOfMonth required for MONTHLY/QUARTERLY/YEARLY, DayOfWeekId required for WEEKLY, etc.) moved from FluentValidation rules INTO handler bodies as `BadRequestException` throws — necessary because the DTO no longer carries the string Frequency code; only the FK id. Handler must resolve DataValue first.
  - Run status code unified: BE summary handler now filters by `Status.DataValue == "SUCCESS"` (not legacy "DELIVERED"). FE run-history-panel surfaces SUCCESS as the Resend-eligible state. Migration note: any pre-existing ScheduledReportRun rows with legacy string status will need data migration when EF migration runs (none exist in green-field DB).
  - Schedule modal: virtual form fields (`_frequencyCode` etc.) introduced inside Zod schema solely to keep `superRefine` conditional logic readable — these are stripped before mutation submission.
- **Known issues opened**: None new. ISSUE-1/2/3/4/5/6 from Session 1 remain OPEN.
- **Known issues closed**: None.
- **Next step**: (none — COMPLETED). User must re-run EF migration: `dotnet ef migrations add Add_ScheduledReport_MasterDataFKs --project Base.Infrastructure --startup-project Base.API --context ApplicationDbContext`. Migration generator will produce ALTER TABLE statements adding 9 FK columns (8 on ScheduledReports, 1 on ScheduledReportRuns) + indices + FK constraints. Then `dotnet ef database update`. Re-apply seed SQL (idempotent — only new STEP 0 inserts will fire). Runtime-verify schedule-modal dropdowns load from MasterData (7 lookups) + Create / Update / Toggle / RunNow / Duplicate end-to-end.
