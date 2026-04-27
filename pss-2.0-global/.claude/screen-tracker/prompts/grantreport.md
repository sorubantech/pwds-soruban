---
screen: GrantReport
registry_id: 63
module: Grants
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO — `grant` schema is bootstrapped by #62 Grant (this screen reuses)
planned_date: 2026-04-25
completed_date: 2026-04-26
last_session_date: 2026-04-26
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + KPI widgets + FORM editor + DETAIL view)
- [x] Existing code reviewed (FE stub at `crm/grant/grantreporting/page.tsx` returns "Need to Develop"; NO BE entity)
- [x] Business rules + workflow extracted (Draft → Submitted → Accepted | Revision Requested workflow)
- [x] FK targets resolved (Grant — depends on #62; MasterData — exists)
- [x] File manifest computed (15 BE + 9 FE)
- [x] Approval config pre-filled (CRM_GRANT parent, GRANTREPORTING menu)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized (FORM 7 sections + DETAIL meta-grid + 6 read sections + 4 KPI widgets + filter bar + workflow state machine)
- [x] User Approval received
- [x] **DEPENDENCY GATE** — verified Grant (#62) is COMPLETED (2026-04-26). All grant schema infrastructure in place.
- [x] Backend code generated (4 entities — parent + 3 children + 8 commands + 4 queries + 2 endpoint files = 19 BE files)
- [x] Backend wiring complete (IGrantDbContext / GrantDbContext / DecoratorGrantModules / GrantMappings — APPENDED 4 DbSets + 1 const + 7 Mapster configs)
- [x] Frontend code generated (view-page 3 modes + Zustand store + DETAIL layout + 7-section FORM + KPI widgets + filter bar = 31 FE files)
- [x] Frontend wiring complete (entity-operations + DTO/GQL barrels + 3 cell renderers registered in 3 elementMapping files + route OVERWRITE of stub)
- [x] DB Seed script generated (GridFormSchema: SKIP for FLOW; 1 MasterDataType `GRANTREPORTTYPE` with 5 values; `GRANTREPORTSTATUS` skipped per FLAG-4 — using GrantReportStatusConstants.cs)
- [x] Registry updated to COMPLETED + Grant (#62) Tab 2 wiring follow-up logged as ISSUE-5 OPEN (separate task)

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/grant/grantreporting`
- [ ] Grid loads with columns: Grant, Report, Type, Due Date, Submitted, Status, Actions
- [ ] 4 KPI widgets render correct counts (Total / Overdue / Accepted / Revision Requested)
- [ ] Filter bar: Grant dropdown, type chips (All/Quarterly/Annual/Final/Financial/Audit), Status select, Date filter, Clear button
- [ ] Status badges color-coded (amber=Due, blue=Draft, green=Accepted, red=Revision Requested/Overdue)
- [ ] `?mode=new` — empty FORM renders 7 sections (Report Info / Executive Summary / Deliverable Progress / Financial Summary / Challenges & Risks / Impact Stories / Attachments)
- [ ] `?mode=edit&id=X` — FORM loads pre-filled
- [ ] `?mode=read&id=X` — DETAIL renders meta-grid (6 cards) + 6 narrative sections + Financial table + Attachments list
- [ ] Create flow: +Add → fill form → Save Draft → grid refresh; Submit to Funder → status=Submitted → redirect to read mode
- [ ] Edit flow: Edit (Draft / Revision Requested) → form pre-filled → Save → back to grid; "Re-open for Editing" on accepted reverts to Draft (with warning)
- [ ] Action buttons per status: Draft → Edit + Submit; Submitted/Accepted → View; Revision Requested → Edit + View Feedback
- [ ] FK dropdowns load: Grant (filtered to active grants for this Company), Report Type (MasterData), Reporting Frequency (inherited from grant)
- [ ] Deliverable child grid: add/remove rows, auto-compute progress % + color, narrative textarea per row
- [ ] Financial child grid: add/remove rows, auto-compute Total row + Variance icon, "Attach Financial Statements" button (SERVICE_PLACEHOLDER)
- [ ] Rich-text fields render Bold/Italic/Underline/Bullet/Numbered/Link toolbar (Executive Summary / Challenges / Impact)
- [ ] Attachment upload: drag-drop area renders + "Upload Attachment" button (SERVICE_PLACEHOLDER for storage layer; metadata persisted)
- [ ] Workflow transitions: SubmitToFunder, AcceptReport, RequestRevision, ReopenForEditing — guards enforced (no edit when Accepted unless reopened)
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] DB Seed — menu visible in sidebar under CRM_GRANT > Funder Reports (GRANTREPORTING)
- [ ] Grant (#62) Tab 2 (Reports) wired to live data — SERVICE_PLACEHOLDER removed

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: GrantReport
Module: Grants (CRM)
Schema: `grant` (REUSED — bootstrapped by #62 Grant; do NOT recreate IGrantDbContext/GrantDbContext/GrantMappings)
Group: GrantModels (entities) / GrantBusiness (commands+queries) / GrantSchemas (DTOs) / Grant (endpoints) — all reused from #62

Business: GrantReport captures the funder progress reports an NGO must submit at scheduled intervals against an awarded grant — quarterly/annual narrative reports, financial reports, final close-out reports, and audit reports. The Grants & Compliance team uses it to draft a report against a specific grant (pre-filled with grant context, milestones, and budget categories), narrate progress on each deliverable, attach supporting documents, save iteratively, and submit to the funder. Once submitted, the funder either accepts the report (closing it out for that period) or requests revisions (re-opening it for the user to amend and re-submit). The screen exists because missing or rejected reports are the most common reason for grant funding being suspended or withdrawn — a single late funder report can lose the next tranche of a six- or seven-figure grant. It relates upstream to Grant #62 (parent — every report is against one grant), reuses the same `grant` schema bootstrap, and is consumed downstream by GrantCalendar #64 (deadline view) and the Grants Dashboard. The DETAIL view renders a publication-style read-only document (meta-grid of report metadata, then narrative sections, financial table, and attachments) so funder-facing PDFs can be generated identically — distinct from the FORM, which is an editing workspace with rich-text toolbars, auto-computing child grids, and a sticky action footer.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from grant-reporting.html. Audit columns omitted — inherited from Entity base.
> **CompanyId is NOT a field** — FLOW screens get tenant from HttpContext.

Table: `grant."GrantReports"` (parent) + 3 child tables in same schema

### Parent: GrantReport

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| GrantReportId | int | — | PK | — | Primary key |
| GrantReportCode | string | 50 | YES | — | Unique per Company. Auto-generated `GR-XXXX` if empty (precedent: GrantCode in #62) |
| GrantId | int | — | YES | `grant.Grants` | Parent grant — set on create, immutable thereafter. Filter ApiSelect to grants where Stage IN (Active, Reporting). |
| ReportTitle | string | 200 | YES | — | "Q1 2026 Progress Report", "Final Report", "Financial Q4 2025" |
| ReportTypeId | int | — | YES | `sett.MasterDatas` (TypeCode=`GRANTREPORTTYPE`) | Quarterly / Annual / Final / Financial / Audit |
| ReportingPeriodStart | DateTime | — | YES | — | "Jan 1, 2026" — start of period this report covers |
| ReportingPeriodEnd | DateTime | — | YES | — | "Mar 31, 2026" — end of period this report covers |
| DueDate | DateTime | — | YES | — | When the report is due to the funder. Drives "Due in N days" / "Overdue" badge in grid. |
| SubmittedDate | DateTime? | — | NO | — | Stamped when status transitions to Submitted |
| AcceptedDate | DateTime? | — | NO | — | Stamped when status transitions to Accepted |
| StatusCode | string | 30 | YES | — | Workflow state — `Draft` / `Submitted` / `Accepted` / `RevisionRequested`. Stored as code (not FK) for fast filter; display label resolved via constants. Default `Draft`. |
| FunderFeedback | string | 4000 | NO | — | Captured when funder transitions report to `RevisionRequested`. Surfaced in "View Feedback" action and inline banner when user re-opens for edit. |
| ExecutiveSummary | string | max | NO | — | Rich text (HTML). "Provide a high-level overview…" |
| ChallengesAndRisks | string | max | NO | — | Rich text (HTML). "Describe any challenges, risks, or delays…" |
| ImpactStories | string | max | NO | — | Rich text (HTML). "Share 1-2 stories of impact…" |
| TotalBudget | decimal(18,2)? | — | NO | — | Pulled from Grant.AwardedAmount on create — cached for report-time snapshot (so historical reports survive grant amendments) |
| TotalSpentCumulative | decimal(18,2) | — | NO | — | Computed/cached: SUM(GrantReportFinancialLine.SpentCumulative) |
| TotalSpentThisPeriod | decimal(18,2) | — | NO | — | Computed/cached: SUM(GrantReportFinancialLine.SpentThisPeriod) |
| TotalRemaining | decimal(18,2) | — | NO | — | Computed: TotalBudget - TotalSpentCumulative |
| IsActive | bool | — | YES | — | Inherited from Entity base — soft toggle |

### Child 1: GrantReportDeliverable

> Mockup Section 3 — Deliverable Progress table. One row per deliverable item.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| GrantReportDeliverableId | int | — | PK | — | — |
| GrantReportId | int | — | YES | `grant.GrantReports` | Parent (cascade delete) |
| DeliverableName | string | 200 | YES | — | "Wells constructed", "Communities served" |
| TargetValue | decimal(18,2) | — | YES | — | "50" |
| PreviousValue | decimal(18,2) | — | NO | — | "25" — pre-filled from prior accepted report against same grant + deliverable name |
| CurrentValue | decimal(18,2) | — | YES | — | "32" — cumulative as of this period end |
| ProgressPercent | decimal(5,2) | — | NO | — | Computed: (CurrentValue / TargetValue) * 100. Persisted on save for fast list rendering. |
| Narrative | string | 2000 | NO | — | Per-row free text textarea ("7 wells completed in Q1…") |
| OrderIndex | int | — | YES | — | Display order within report (0-based) |

### Child 2: GrantReportFinancialLine

> Mockup Section 4 — Financial Summary table. One row per budget category.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| GrantReportFinancialLineId | int | — | PK | — | — |
| GrantReportId | int | — | YES | `grant.GrantReports` | Parent (cascade delete) |
| Category | string | 100 | YES | — | "Construction", "Staff", "Training", "M&E", "Travel", "Admin". Free text — not a MasterData FK; budget categories are grant-defined. |
| BudgetAmount | decimal(18,2) | — | YES | — | "$250,000" |
| SpentCumulative | decimal(18,2) | — | YES | — | "$178,000" — total spent on this category since grant start |
| SpentThisPeriod | decimal(18,2) | — | YES | — | "$43,000" — spent during this report's period |
| Remaining | decimal(18,2) | — | NO | — | Computed: BudgetAmount - SpentCumulative. Persisted for fast list rendering. |
| VarianceStatus | string | 20 | YES | — | `OK` / `Warning` / `Critical`. Computed: OK if Remaining ≥ 10% of Budget; Warning 0-10%; Critical < 0. Persisted. |
| OrderIndex | int | — | YES | — | Display order |

### Child 3: GrantReportAttachment

> Mockup Section 7 — Attachments. PDF/DOCX/XLSX/JPG/PNG up to 25 MB.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| GrantReportAttachmentId | int | — | PK | — | — |
| GrantReportId | int | — | YES | `grant.GrantReports` | Parent (cascade delete) |
| FileName | string | 300 | YES | — | "Q1_2026_Supporting_Documents.pdf" |
| FileSize | long | — | YES | — | Bytes — display formatted ("2.4 MB") |
| FileType | string | 50 | YES | — | MIME type or extension |
| StorageKey | string | 500 | NO | — | Object-storage key. **SERVICE_PLACEHOLDER**: capture metadata; storage upload mocked until file-storage service exists. |
| AttachmentCategory | string | 30 | NO | — | `Financial` / `Supporting` / `ImpactPhoto` — drives icon (PDF/Excel/image). For mockup section "Attach Financial Statements" / "Add Story with Photo" / generic upload. |
| OrderIndex | int | — | YES | — | Display order |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| GrantId | Grant | PSS_2.0_Backend/.../Base.Domain/Models/GrantModels/Grant.cs (created by #62) | GetGrants | GrantTitle (combined with GrantCode for display: `{GrantCode} — {GrantTitle}`) | GrantResponseDto |
| ReportTypeId | MasterData | PSS_2.0_Backend/.../Base.Domain/Models/SettingModels/MasterData.cs | GetMasterDatas (filter by TypeCode=`GRANTREPORTTYPE`) | MasterDataValue | MasterDataResponseDto |

> **Note**: StatusCode is a string column (not FK) — workflow constants live in `GrantReportStatusConstants.cs` (precedent: SavedFilter status). Reduces a join on every list query.
>
> **CRITICAL FK GATE**: GrantId targets `grant.Grants` which is created by Grant #62. Build phase MUST verify #62 is COMPLETED first. If #62 only PROMPT_READY, the GrantModels group / `grant` schema / IGrantDbContext do not yet exist — BlackList all GrantReport BE files.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- GrantReportCode unique per Company
- One Draft report per (GrantId, ReportTypeId, ReportingPeriodStart, ReportingPeriodEnd) — prevents duplicates. Override allowed if prior report is Accepted/RevisionRequested for that period (revision cycle).

**Required Field Rules:**
- GrantId, ReportTitle, ReportTypeId, ReportingPeriodStart, ReportingPeriodEnd, DueDate are mandatory at creation
- Executive Summary is required when transitioning Draft → Submitted (cannot submit empty)
- At least one Deliverable row required for Quarterly / Annual / Final report types when submitting
- Financial Summary rows required (sum = TotalBudget snapshot) when ReportType is Financial OR Final
- Reporting period must satisfy: Start < End AND End ≤ today (cannot report on future periods)
- Reporting period must fall within Grant.StartDate / Grant.EndDate (with 30-day grace at end)

**Conditional Rules:**
- If StatusCode = `Submitted`, all narrative + financial fields become read-only at API level (immutable post-submission)
- If StatusCode = `RevisionRequested`, fields become editable again — but FunderFeedback is read-only (set by funder via Accept/Request endpoints)
- If StatusCode = `Accepted`, requires explicit ReopenForEditing command (with warning + audit trail) before any edit
- If ReportType = `Audit`, allow attachments only — narrative sections collapsed
- DueDate ≥ ReportingPeriodEnd (cannot be due before period ends — typical funder grace ~30 days)

**Business Logic:**
- ProgressPercent on each deliverable computed server-side on save — also re-computed in DTO on read for safety
- VarianceStatus on each financial line computed server-side: `OK` if Remaining ≥ 10% of Budget; `Warning` if 0-10%; `Critical` if Remaining < 0 (overspent)
- Total* fields on parent computed by aggregating children on every save / after each child mutation
- TotalBudget snapshotted from Grant.AwardedAmount on first save — survives subsequent grant amendments (immutable)
- "Due in N days" / "Overdue" badge computed in grid query (not stored): `(DueDate - today).Days` — green if N≥30, amber if 0<N<30, red if N≤0 and StatusCode=Draft
- Pre-fill on +New: when GrantId selected, auto-populate Reporting Period from Grant.NextReportDueDate window, prior-period CumulativeSpent from prior accepted report
- "Re-open for Editing" reverts StatusCode `Accepted → Draft` with audit trail entry — restricted to BUSINESSADMIN

**Workflow** (state machine):
- States: `Draft → Submitted → (Accepted | RevisionRequested) → Draft (if RevisionRequested resubmits)`
- Transitions:
  - `SubmitToFunder` (Draft → Submitted) — author or BUSINESSADMIN; sets SubmittedDate
  - `AcceptReport` (Submitted → Accepted) — BUSINESSADMIN only (records funder decision); sets AcceptedDate
  - `RequestRevision` (Submitted → RevisionRequested) — BUSINESSADMIN only; requires FunderFeedback non-empty
  - `ResubmitReport` (RevisionRequested → Submitted) — same as initial submit; clears FunderFeedback display banner but retains feedback in audit
  - `ReopenForEditing` (Accepted → Draft) — BUSINESSADMIN only; warns "this voids the funder acceptance"
- Side effects:
  - On Submit: lock all narrative + financial fields; on Accept: lock harder (requires reopen); on Request: unlock + display feedback banner

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Transactional/Workflow CRUD with multi-section form, child grids, rich text, file uploads, and 4-state workflow
**Reason**: "+New Report" opens a full-page form (overlay in mockup → `?mode=new` route in app); record has its own publication-style read-only DETAIL view (overlay in mockup → `?mode=read` route); form has 7 sections + 3 child collections + state machine — too rich for modal MASTER_GRID pattern

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — for parent
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] **Nested child creation** — Deliverables, FinancialLines, Attachments (3 child collections via single Create/Update payload)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 2 — Grant, ReportType)
- [x] Unique validation — GrantReportCode + composite (GrantId, ReportTypeId, period) for Draft duplicates
- [x] **Workflow commands** — SubmitToFunder, AcceptReport, RequestRevision, ReopenForEditing (4 separate commands)
- [x] **File upload command** — UploadGrantReportAttachment (SERVICE_PLACEHOLDER until storage exists; persists metadata + mock storage key)
- [x] Custom business rule validators — submit-time validation (executive summary required, deliverables required for narrative types, financials required for Financial/Final)
- [x] Computed-field recomputation on save (ProgressPercent, VarianceStatus, Total*)
- [x] Pre-fill query — `GetGrantReportPrefillData(grantId, reportTypeId)` returns budget snapshot + prior-period deliverable values + reporting frequency
- [x] Summary query — `GetGrantReportSummary` returns 4 KPI counts (Total, Overdue, Accepted, RevisionRequested)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid)
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (for FORM layout)
- [x] Zustand store (`grantreport-store.ts`)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (with Back, Save Draft, Submit to Funder buttons)
- [x] **Child grid inside form × 3** — Deliverables, FinancialLines, Attachments
- [x] **Workflow status badge + action buttons** — Edit/Submit/View/View Feedback per status
- [x] **File upload widget** — drag-drop area + metadata-only persist (SERVICE_PLACEHOLDER on upload)
- [x] **Rich-text editor × 3** — Executive Summary, Challenges & Risks, Impact Stories (Bold/Italic/Underline/Bullet/Numbered/Link toolbar)
- [x] **Summary cards / count widgets above grid** — 4 KPI cards
- [x] Filter chips bar (report type filter)
- [x] Custom DETAIL layout — meta-grid (6 cards) + narrative sections + read-only financial table + attachments list (NOT the form disabled)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from grant-reporting.html — this IS the design spec.

### Grid/List View

**Display Mode**: `table` (default — transactional list, mockup uses dense table rows; no card gallery layout)

**Grid Layout Variant**: `widgets-above-grid` (4 KPI stat cards above the grid → MANDATORY: FE Dev uses Variant B with `<ScreenHeader>` + widget components + `<DataTableContainer showHeader={false}>` to avoid duplicate-header bug — ContactType #19 precedent)

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Grant | grantCode + grantTitle | composite text | 200px | YES | Two-line cell: GrantCode link (→ Grant detail page `?mode=read&id=grantId`) on top; FunderName + ProgramName as muted sub-text below |
| 2 | Report | reportTitle | text | auto | YES | "Q1 2026 Progress" — links to `?mode=read&id={id}` |
| 3 | Type | reportTypeName | text | 100px | YES | "Quarterly", "Final", "Financial" |
| 4 | Due Date | dueDate | date | 120px | YES | "Apr 30, 2026" |
| 5 | Submitted | submittedDate | date | 120px | YES | em-dash if null |
| 6 | Status | statusBadge (computed) | badge | 180px | YES | Color-coded: amber "Due in N days" (Draft + N≥0); red "Overdue" (Draft + N<0); blue "Draft" (Draft + N≥30); blue "Submitted"; green "Accepted"; red "Revision Requested" |
| 7 | Actions | — | action buttons | 200px | NO | Status-conditional: Draft → "Edit" + "Submit"; Submitted/Accepted → "View"; RevisionRequested → "Edit" + "View Feedback" — for "Create" use case (no draft yet, only deadline known) the row may not exist; +New button creates from scratch |

**Search/Filter Fields**:
- Grant select (single — All Grants / specific grant from active grants list — ApiSelect with `GetGrants` filtered to Stage IN (Active, Reporting))
- Report Type filter chips (multi-toggle): All / Quarterly / Annual / Final / Financial / Audit (matches MasterData `GRANTREPORTTYPE`)
- Status select (single): All Statuses / Draft / Submitted / Accepted / Revision Requested
- Date filter (single — server-side computed): All Dates / Overdue / Due This Month / Due Next 30 Days
- Free-text search (header) — by ReportTitle, GrantCode, GrantTitle
- Clear Filters button (right-aligned) — resets all filters

**Grid Actions**:
- Row click → Navigates to `?mode=read&id={id}` (DETAIL layout) — except for empty rows (deadlines without drafts)
- Per-row action buttons (status-conditional):
  - **Create** (when row is a deadline without a draft) → opens `?mode=new&grantId=X&reportTypeId=Y&dueDate=Z` (pre-filled)
  - **Edit** (Draft / RevisionRequested) → `?mode=edit&id={id}`
  - **Submit** (Draft only) → inline confirmation → POST `SubmitToFunder` mutation; refresh grid
  - **View** (Submitted / Accepted) → `?mode=read&id={id}`
  - **View Feedback** (RevisionRequested) → opens DETAIL view with feedback banner highlighted at top

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL layout)

### Page Widgets & Summary Cards

**Widgets** (4 KPI cards above the grid — uniform `.stat-card` layout: icon left, value+label+sub right; one card per metric):

| # | Widget Title | Value Source | Display Type | Position | Sub-text |
|---|-------------|-------------|-------------|----------|----------|
| 1 | Total Reports | `summary.totalReports` | count + icon `ph:file-text` (blue tint) | Top-left | "{pendingThisQuarter} pending this quarter" |
| 2 | Overdue | `summary.overdue` | count + icon `ph:clock` (amber tint) | Top-2nd | "Requires immediate attention" (static) |
| 3 | Accepted | `summary.accepted` | count + icon `ph:check-circle` (green tint) | Top-3rd | "All requirements met" (static) |
| 4 | Revision Requested | `summary.revisionRequested` | count + icon `ph:warning-circle` (red tint) | Top-right | dynamic: most recent revision request — "{ReportTitle}" (e.g., "DFID Q4 2025 narrative") |

**Detection cue → variant**: 4 widgets present → `widgets-above-grid` (Variant B, `<ScreenHeader>` + `showHeader={false}`).

**Summary GQL Query**:
- Query name: `GetGrantReportSummary`
- Returns: `GrantReportSummaryDto` with fields:
  ```
  totalReports: int
  pendingThisQuarter: int  // Draft within current quarter
  overdue: int             // Draft + DueDate < today
  accepted: int
  revisionRequested: int
  latestRevisionRequestTitle: string?  // for sub-text on card 4
  ```
- Added to `GrantReportQueries.cs` alongside `GetGrantReports` and `GetGrantReportById`

### Grid Aggregation Columns

**Aggregation Columns**: NONE — per-row metrics already snapshotted on the parent (TotalSpentCumulative etc.). Grid stays lean.

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

> One component (`view-page.tsx`) renders **3 URL modes** with **2 completely different UI layouts**:
>
> ```
> URL MODE                                    UI LAYOUT
> ───────────────────────────────────────     ──────────────────────────────────────
> /grantreporting?mode=new                →   FORM LAYOUT  (empty form — 7 sections)
> /grantreporting?mode=edit&id=243        →   FORM LAYOUT  (pre-filled, editable)
> /grantreporting?mode=read&id=243        →   DETAIL LAYOUT (publication-style read view)
> ```

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

> Built with React Hook Form. Must match the editor overlay design in grant-reporting.html exactly.

**Page Header**: FlowFormPageHeader. Title: "Report: {ReportTitle}"; Subtitle: "{GrantCode} ({FunderName} — {ProgramName})"; Back arrow + Sticky-footer actions (see below). Unsaved changes dialog on dirty navigation.

**Section Container Type**: cards (each section is a `.editor-section` white card with shadow + 1px border + 12px radius — flat list, NOT accordion / NOT tabs)

**Form Sections** (in display order from mockup):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | fa-info-circle (`ph:info`) | Report Info | 2-column (.col-md-6) for first row, 3-column (.col-md-4) for second row | always expanded | Grant (readonly), ReportTitle, ReportType (readonly when set from deadline pre-fill), ReportingPeriod (StartDate + EndDate or single text), DueDate (readonly when system-derived) |
| 2 | fa-align-left (`ph:text-align-left`) | Executive Summary | full-width | always expanded | ExecutiveSummary (rich-text) |
| 3 | fa-tasks (`ph:list-checks`) | Deliverable Progress | full-width child grid | always expanded | Deliverable child rows (see Child Grids below) |
| 4 | fa-dollar-sign (`ph:currency-dollar`) | Financial Summary | full-width child grid + footer button | always expanded | FinancialLine child rows (see Child Grids) + "Attach Financial Statements" SERVICE_PLACEHOLDER button |
| 5 | fa-exclamation-triangle (`ph:warning`) | Challenges & Risks | full-width | always expanded | ChallengesAndRisks (rich-text — Bold/Italic/Bullet only — narrower toolbar than section 2) |
| 6 | fa-heart (`ph:heart`) | Impact Stories | full-width | always expanded | ImpactStories (rich-text — Bold/Italic/Bullet) + "Add Story with Photo" SERVICE_PLACEHOLDER button |
| 7 | fa-paperclip (`ph:paperclip`) | Attachments | full-width drag-drop zone + file list | always expanded | Attachment child rows (see Child Grids) |

**Field Widget Mapping** (parent-only fields — child grids covered below):

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| GrantId | 1 | ApiSelectV2 | "Select grant" | required | Query: `GetGrants` filtered to Stage IN (Active, Reporting); display `{grantCode} — {grantTitle}`; **readonly when editing** (immutable FK) |
| ReportTitle | 1 | text | "Q1 2026 Progress Report" | required, max 200 | — |
| ReportTypeId | 1 | ApiSelectV2 | "Select type" | required | Query: `GetMasterDatas` filtered to TypeCode=`GRANTREPORTTYPE`; readonly when pre-filled from deadline |
| ReportingPeriodStart | 1 | datepicker | "Period start" | required, < End | Default: derived from grant + frequency |
| ReportingPeriodEnd | 1 | datepicker | "Period end" | required, > Start, ≤ today | Default: derived |
| DueDate | 1 | datepicker | "Due date" | required, ≥ End | Readonly when system-derived from grant milestones |
| ExecutiveSummary | 2 | RichTextEditor | "Provide a high-level overview of progress during this reporting period." | required for submit (HTML non-empty) | Toolbar: Bold, Italic, Underline, Bullet, Numbered, Link. Min height 120px, vertical resize. |
| ChallengesAndRisks | 5 | RichTextEditor | "Describe any challenges, risks, or delays encountered." | optional | Toolbar: Bold, Italic, Bullet (narrower). Min height 120px. |
| ImpactStories | 6 | RichTextEditor | "Share 1-2 stories of impact from this period." | optional | Toolbar: Bold, Italic, Bullet. Min height 120px. |

**Special Form Widgets**:

- **Rich-text Editor** (× 3 — Sections 2, 5, 6):
  - Toolbar above textarea (`.rich-toolbar` styling: light grey bar, icon-only buttons)
  - Section 2 toolbar: Bold, Italic, Underline, BulletList, NumberedList, Link (full set)
  - Sections 5 & 6 toolbar: Bold, Italic, BulletList (narrow set)
  - Body persists as HTML string in DTO; FE renders via sanitized `dangerouslySetInnerHTML` in DETAIL view
  - Reuse existing rich-text editor infra if present (FE dev: search for `RichTextEditor` / `tiptap` / `quill` / `lexical` registries before creating)

- **Conditional Sub-forms**: NONE — all sections always render. Workflow handles read/write toggling at section level (entire form goes read-only when StatusCode != Draft && != RevisionRequested).

- **Inline Mini Display** (Grant context card):
  - Triggered: when GrantId selected on `?mode=new`
  - Position: above Section 1 OR inline header subtitle
  - Content: GrantCode badge + GrantTitle + Funder name + AwardedAmount + Period (StartDate – EndDate). Pulled via existing `GetGrantById` query (or embedded in `GetGrantReportPrefillData` response).

**Child Grids in Form** (3 — Sections 3, 4, 7):

| Child | Section | Grid Columns | Add/Edit Method | Delete | Notes |
|-------|---------|-------------|----------------|--------|-------|
| GrantReportDeliverable | 3 | DeliverableName (text input) \| Target (number, center) \| Previous (number, center, readonly — pre-filled) \| Current (number, center) \| Progress (computed bar + label, color: green ≥60%, amber 30-60%, red <30%) \| Narrative (textarea, min 50px) | Inline row (always-on Add Row button below grid) | Per-row trash button | Min 1 row required for Quarterly/Annual/Final; pre-filled from grant milestones on +New |
| GrantReportFinancialLine | 4 | Category (text input) \| Budget (currency, right-aligned) \| Spent Cumulative (currency, right) \| Spent This Period (currency, right) \| Remaining (computed, right, readonly) \| Variance (icon: green check / amber alert / red exclaim, computed from Remaining%) | Inline row | Per-row trash button | Pre-filled from Grant.BudgetLines on +New; auto-Total row at footer (computed sum, bold, top-border); "Attach Financial Statements" button below grid (SERVICE_PLACEHOLDER) |
| GrantReportAttachment | 7 | (file upload card list — not a tabular grid) | Drag-drop zone + "Upload Attachment" button (full-width, dashed border, cloud-upload icon, "PDF, DOCX, XLSX, JPG, PNG up to 25 MB" sub-text) | Per-file × button | Each attached file rendered as `.attached-file` row: icon (PDF/Excel by mime), filename, size, remove button. **Upload SERVICE_PLACEHOLDER**: capture metadata; mock storageKey; toast "File reference saved (storage upload pending integration)" |

**Sticky Action Footer** (mockup `.editor-footer`):

| Button | Style | Action | Visible When |
|--------|-------|--------|-------------|
| Cancel | btn-text | Discard changes (with unsaved-changes dialog) → back to grid | Always |
| Preview as PDF | btn-outline-accent | SERVICE_PLACEHOLDER toast "PDF preview pending integration" | Always |
| Save Draft | btn-outline-accent | POST CreateGrantReport / UpdateGrantReport (StatusCode=Draft); stay on form | StatusCode = Draft \| RevisionRequested |
| Submit to Funder | btn-primary-accent | Validate submit rules → POST SubmitToFunder mutation → redirect to `?mode=read&id={id}` | StatusCode = Draft \| RevisionRequested |

---

#### LAYOUT 2: DETAIL (mode=read) — DIFFERENT UI from the form

> The publication-style read-only document shown when user clicks a grid row, "View" action, or "View Feedback" action. NOT the form with fields disabled — this is a centered max-width 900px white card that mimics the funder-facing PDF layout.

**Page Header**: FlowFormPageHeader. Title: "{ReportTitle}"; Subtitle: "{GrantCode} — {FunderName}, {GrantProgram}"; Back arrow + status badge inline.

**Header Actions** (top action row above the document, not in FlowFormPageHeader — flat row of buttons):
- **Close** (btn-primary-accent, with × icon) → back to grid
- **Download PDF** (btn-outline-accent) — SERVICE_PLACEHOLDER toast
- **Re-open for Editing** (btn-outline-accent) — visible only when StatusCode = Accepted; confirms with warning dialog "This will void the funder acceptance and revert to Draft"; calls `ReopenForEditing` mutation
- **Edit** (btn-outline-accent) — visible only when StatusCode = Draft / RevisionRequested → navigates to `?mode=edit&id={id}`
- **More dropdown**: Duplicate (creates new Draft from this report's content for next period), Delete (Draft only)

**Page Layout**: Single column, centered, max-width 900px, white card with shadow + border + 32px padding.

**Banner** (top of card, only when StatusCode = RevisionRequested):
- Red-tinted alert banner with `fa-exclamation-circle` icon, title "Revision Requested by Funder", body = FunderFeedback content (rendered HTML safe)

**Document Sections** (in order — render only if content present, except Meta which is always rendered):

| # | Section Heading | Style | Content |
|---|----------------|-------|---------|
| 1 | (no heading — top metadata) | `.report-meta-grid` 6-cell grid (auto-fit minmax(180px, 1fr), light-grey background, 0.5rem padding) | Cell 1: Report Type → label + value; Cell 2: Reporting Period → "Oct 1 – Dec 31, 2025"; Cell 3: Due Date; Cell 4: Submitted (date or em-dash); Cell 5: Status (color-coded text); Cell 6: Accepted On (date or em-dash) |
| 2 | "Executive Summary" | h4 with grants-accent bottom-border | ExecutiveSummary (HTML, sanitized render) |
| 3 | "Financial Summary" | h4 + financial-table | All FinancialLine rows + Total footer row. Columns: Category \| Budget \| Spent (Cumulative) \| Spent ({Period label, e.g., "Q4 2025"}) \| Remaining. **No Variance column in DETAIL** (publication style — clean) |
| 4 | "Deliverable Progress" | h4 + paragraph (rendered as narrative — NOT a table) | Auto-generated sentence per deliverable: "{Current} of {Target} {DeliverableName} have been completed ({ProgressPercent}%). {Narrative}" — joined into flowing prose. (Mockup precedent: "32 of 50 wells have been constructed (64%). 28 of 50 target communities are now being served (56%)…") |
| 5 | "Challenges & Risks" | h4 | ChallengesAndRisks (HTML, sanitized) |
| 6 | "Impact Stories" | h4 | ImpactStories (HTML, sanitized) |
| 7 | "Attachments" | h4 + `.attached-file` list (no upload zone, no remove button) | Each attachment: icon (PDF/Excel/image by mime), filename, size, download link (SERVICE_PLACEHOLDER → toast "Download pending storage integration") |

> **State**: This DETAIL layout is the documentation-style read view from the mockup's `.report-view-content`. It is DEFINITELY NOT the form wrapped in `<fieldset disabled>` — the FE dev MUST build it as a separate component (`detail-view.tsx`) inside `view-page.tsx` and switch on `mode === 'read'`.

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User lands at `/crm/grant/grantreporting` → grid + 4 KPI widgets render
2. User filters by Grant + Type chip + Status dropdown → grid refreshes server-side
3. User clicks "+New Report" → URL: `?mode=new` → empty FORM LAYOUT (7 sections)
4. User selects Grant → mini Grant context card appears + Reporting Period + Deliverables + Financial categories pre-filled from `GetGrantReportPrefillData`
5. User fills sections → clicks "Save Draft" → POST CreateGrantReport (Status=Draft) → URL: `?mode=edit&id={newId}` → form stays in edit mode (allows further save)
6. User clicks "Submit to Funder" → submit-validation runs → POST SubmitToFunder → URL: `?mode=read&id={id}` → DETAIL LAYOUT renders
7. From grid: row click → URL: `?mode=read&id={id}` → DETAIL layout (with status-appropriate banner)
8. RevisionRequested report: user clicks "Edit" or "View Feedback" action → DETAIL view with red banner; user clicks Edit button → `?mode=edit&id={id}` → FORM unlocked + feedback shown above Section 1
9. Accepted report: user clicks "Re-open for Editing" → confirmation modal → ReopenForEditing mutation → StatusCode reverts to Draft → URL `?mode=edit&id={id}`
10. Back: arrow click → URL `/crm/grant/grantreporting` → grid
11. Unsaved changes: dirty-form navigation → confirm dialog "Discard unsaved changes?"

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: SavedFilter (FLOW)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | GrantReport | Entity/class name |
| savedFilter | grantReport | Variable/field names |
| SavedFilterId | GrantReportId | PK field |
| SavedFilters | GrantReports | Table name, collection names |
| saved-filter | grant-report | kebab-case (FE service path uses dashed; route uses no-dash) |
| savedfilter | grantreport | FE folder for page-components, DTO file, GQL files |
| SAVEDFILTER | GRANTREPORTING | Grid code, Menu code (note: menu code matches MODULE_MENU_REFERENCE — `GRANTREPORTING` not `GRANTREPORT`) |
| notify | grant | DB schema |
| Notify | Grant | Backend group name (Models / Schemas / Business) |
| NotifyModels | GrantModels | Namespace suffix for entity |
| NotifyBusiness | GrantBusiness | Namespace suffix for commands/queries |
| NotifySchemas | GrantSchemas | Namespace suffix for DTOs |
| NOTIFICATIONSETUP | CRM_GRANT | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/grant/grantreporting | FE route path (note: folder is `grantreporting` to match existing stub + MODULE_MENU URL) |
| notify-service | grant-service | FE service folder name (DTO + GQL imports) |
| notify-queries | grant-queries | FE GQL queries folder |
| notify-mutations | grant-mutations | FE GQL mutations folder |

> **Naming inconsistency note**: The route folder is `grantreporting` (matches existing FE stub + MODULE_MENU_REFERENCE URL). The entity is `GrantReport` (singular, no "ing"). All entity-internal naming uses `grantReport` / `GrantReports` / `GrantReportDto` etc. — only the route folder, page config filename, and menu code carry the `grantreporting` suffix.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Paths use the actual repo layout: backend = `PSS_2.0_Backend/PeopleServe/Services/Base/`, frontend = `PSS_2.0_Frontend/`. The grant schema/module bootstrap (IGrantDbContext, GrantDbContext, GrantMappings, DecoratorGrantModules) is REUSED from #62 — do NOT recreate.

### Backend Files (15 files — parent + 3 children + 4 workflow commands + 2 endpoint files)

| # | File | Path |
|---|------|------|
| 1 | Parent Entity | PSS_2.0_Backend/.../Base.Domain/Models/GrantModels/GrantReport.cs |
| 2 | Child Entity 1 | PSS_2.0_Backend/.../Base.Domain/Models/GrantModels/GrantReportDeliverable.cs |
| 3 | Child Entity 2 | PSS_2.0_Backend/.../Base.Domain/Models/GrantModels/GrantReportFinancialLine.cs |
| 4 | Child Entity 3 | PSS_2.0_Backend/.../Base.Domain/Models/GrantModels/GrantReportAttachment.cs |
| 5 | EF Config (parent + cascade-delete children) | PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/GrantConfigurations/GrantReportConfiguration.cs (+ GrantReportDeliverableConfiguration.cs, GrantReportFinancialLineConfiguration.cs, GrantReportAttachmentConfiguration.cs in same folder) |
| 6 | Schemas (DTOs) | PSS_2.0_Backend/.../Base.Application/Schemas/GrantSchemas/GrantReportSchemas.cs (RequestDto + ResponseDto + DeliverableDto + FinancialLineDto + AttachmentDto + SummaryDto + PrefillDto + StatusConstants) |
| 7 | Create Command | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantReports/CreateCommand/CreateGrantReport.cs (handles parent + 3 children in one transaction) |
| 8 | Update Command | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantReports/UpdateCommand/UpdateGrantReport.cs (diffs children — add/update/remove) |
| 9 | Delete Command | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantReports/DeleteCommand/DeleteGrantReport.cs (soft via IsActive; restricted to Draft) |
| 10 | Toggle Command | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantReports/ToggleCommand/ToggleGrantReport.cs |
| 11 | Workflow: Submit | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantReports/Commands/SubmitToFunderGrantReport.cs |
| 12 | Workflow: Accept + RequestRevision + Reopen | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantReports/Commands/AcceptGrantReport.cs, RequestRevisionGrantReport.cs, ReopenGrantReport.cs (3 separate files in Commands/) |
| 13 | GetAll Query | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantReports/GetAllQuery/GetGrantReports.cs (with filter args: grantId?, reportTypeIds[], status?, dateFilterMode?, search) |
| 14 | GetById Query + Summary + Prefill | PSS_2.0_Backend/.../Base.Application/Business/GrantBusiness/GrantReports/Queries/GetGrantReportById.cs, GetGrantReportSummary.cs, GetGrantReportPrefillData.cs (3 separate files) |
| 15 | Mutations + Queries Endpoints | PSS_2.0_Backend/.../Base.API/EndPoints/Grant/Mutations/GrantReportMutations.cs + PSS_2.0_Backend/.../Base.API/EndPoints/Grant/Queries/GrantReportQueries.cs |

### Backend Wiring Updates (REUSE existing — created by #62)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs (already inheriting IGrantDbContext from #62) | NO change — IGrantDbContext modification handles it |
| 2 | IGrantDbContext.cs (created by #62) | Add `DbSet<GrantReport>`, `DbSet<GrantReportDeliverable>`, `DbSet<GrantReportFinancialLine>`, `DbSet<GrantReportAttachment>` |
| 3 | GrantDbContext.cs (created by #62) | Add same 4 DbSet properties + ApplyConfigurationsFromAssembly already wires the Configuration files |
| 4 | DecoratorProperties.cs → DecoratorGrantModules class (created by #62) | Add 4 entries (parent + 3 children) for the audit decorator |
| 5 | GrantMappings.cs (created by #62) | Add Mapster mapping config: GrantReport ↔ GrantReportRequestDto / GrantReportResponseDto + 3 child mappings |

### Frontend Files (9 files — FLOW pattern with view-page + Zustand store; route folder is `grantreporting`)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/grant-service/GrantReportDto.ts |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/grant-queries/GrantReportQuery.ts |
| 3 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/grant-mutations/GrantReportMutation.ts (includes 4 workflow mutations + create/update/delete/toggle) |
| 4 | Page Config | PSS_2.0_Frontend/src/presentation/pages/crm/grant/grantreporting.tsx (entity-operations import + grid columns + filters + ScreenHeader + widgets variant B) |
| 5 | Index Page | PSS_2.0_Frontend/src/presentation/components/page-components/crm/grant/grantreporting/index.tsx |
| 6 | Index Page Component | PSS_2.0_Frontend/src/presentation/components/page-components/crm/grant/grantreporting/index-page.tsx (4 KPI cards + grid) |
| 7 | **View Page (3 modes)** | PSS_2.0_Frontend/src/presentation/components/page-components/crm/grant/grantreporting/view-page.tsx (mode switch: form-view.tsx, detail-view.tsx — recommend extracting to children for clarity) |
| 8 | **Zustand Store** | PSS_2.0_Frontend/src/presentation/components/page-components/crm/grant/grantreporting/grantreport-store.ts (form state, dirty flag, child arrays, mode, selected ID) |
| 9 | Route Page (OVERWRITE existing stub) | PSS_2.0_Frontend/src/app/[lang]/crm/grant/grantreporting/page.tsx — current content `<div>Need to Develop</div>` is REPLACED |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | `GRANTREPORTING` operations config (CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, READ) |
| 2 | operations-config.ts | Import + register `GRANTREPORTING` operations |
| 3 | sidebar menu config (likely `menu-config.ts` or DB-driven via #62 menu seeds) | NO change if menu is DB-driven (seed inserts the row); FE just needs the route |
| 4 | route config (if using static route map) | NO change if route file-based via app-router stub |
| 5 | Grant (#62) FE prompt — Tab 2 wiring | After GrantReport COMPLETED, return to grant.md and remove Tab 2 SERVICE_PLACEHOLDER → wire to `GetGrantReports` filtered by `grantId` |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Funder Reports
MenuCode: GRANTREPORTING
ParentMenu: CRM_GRANT
Module: CRM
MenuUrl: crm/grant/grantreporting
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: GRANTREPORTING
---CONFIG-END---
```

**MasterDataType seed required (2 new types):**

```
MasterDataType: GRANTREPORTTYPE
  Values: Quarterly, Annual, Final, Financial, Audit

MasterDataType: GRANTREPORTSTATUS  (optional — driven by string constants instead; include only if MasterData-driven workflow tooling needs it)
  Values: Draft, Submitted, Accepted, RevisionRequested
```

> **Recommended**: skip the GRANTREPORTSTATUS MasterData and use a `GrantReportStatusConstants.cs` static class (precedent: SavedFilter status). Reduces a join on every list query and matches the existing FLOW pattern.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `GrantReportQueries`
- Mutation type: `GrantReportMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetGrantReports | PaginatedApiResponse<IEnumerable<GrantReportResponseDto>> | searchText, pageNo, pageSize, sortField, sortDir, isActive, grantId?, reportTypeIds[], statusCode?, dateFilterMode? (overdue / dueThisMonth / dueNext30 / all) |
| GetGrantReportById | BaseApiResponse<GrantReportResponseDto> | grantReportId (response includes parent + 3 child collections) |
| GetGrantReportSummary | BaseApiResponse<GrantReportSummaryDto> | (no args — scoped to current Company) |
| GetGrantReportPrefillData | BaseApiResponse<GrantReportPrefillDto> | grantId, reportTypeId — returns budget categories + prior-period deliverables + reporting frequency + suggested period |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateGrantReport | GrantReportRequestDto (parent + 3 child arrays) | int (new GrantReportId) |
| UpdateGrantReport | GrantReportRequestDto (with grantReportId) | int |
| DeleteGrantReport | grantReportId | int (Draft only — guard) |
| ToggleGrantReport | grantReportId | int |
| SubmitToFunder | grantReportId | int (Draft → Submitted; sets SubmittedDate) |
| AcceptGrantReport | grantReportId, acceptedDate? | int (Submitted → Accepted; sets AcceptedDate) |
| RequestRevisionGrantReport | grantReportId, funderFeedback (required, min 10 chars) | int (Submitted → RevisionRequested; sets FunderFeedback) |
| ReopenGrantReport | grantReportId, reason? | int (Accepted → Draft; clears AcceptedDate; restricted to BUSINESSADMIN) |

**Response DTO Fields** (`GrantReportResponseDto`):

| Field | Type | Notes |
|-------|------|-------|
| grantReportId | number | PK |
| grantReportCode | string | "GR-0001" |
| grantId | number | FK |
| grantCode | string | from join — e.g., "GRT-012" |
| grantTitle | string | from join |
| funderName | string | from join — Contact.ContactName via Grant.FunderContactId |
| grantProgram | string? | from join — Grant.GrantProgram |
| reportTitle | string | — |
| reportTypeId | number | FK |
| reportTypeName | string | from MasterData join |
| reportingPeriodStart | string (ISO date) | — |
| reportingPeriodEnd | string (ISO date) | — |
| dueDate | string (ISO date) | — |
| submittedDate | string (ISO date)? | — |
| acceptedDate | string (ISO date)? | — |
| statusCode | string | "Draft" / "Submitted" / "Accepted" / "RevisionRequested" |
| statusBadge | { label: string; tone: "blue" \| "amber" \| "green" \| "red"; iconCode: string } | computed server-side: includes "Due in N days" / "Overdue" derivations |
| funderFeedback | string? | — |
| executiveSummary | string? | HTML |
| challengesAndRisks | string? | HTML |
| impactStories | string? | HTML |
| totalBudget | number? | — |
| totalSpentCumulative | number | — |
| totalSpentThisPeriod | number | — |
| totalRemaining | number | — |
| deliverables | GrantReportDeliverableDto[] | child array |
| financialLines | GrantReportFinancialLineDto[] | child array |
| attachments | GrantReportAttachmentDto[] | child array |
| isActive | boolean | inherited |
| createdDate | string (ISO date) | inherited (audit) |
| modifiedDate | string (ISO date)? | inherited (audit) |

**Child DTOs**:

```
GrantReportDeliverableDto: {
  grantReportDeliverableId: number; deliverableName: string; targetValue: number;
  previousValue: number?; currentValue: number; progressPercent: number;
  narrative: string?; orderIndex: number;
}

GrantReportFinancialLineDto: {
  grantReportFinancialLineId: number; category: string; budgetAmount: number;
  spentCumulative: number; spentThisPeriod: number; remaining: number;
  varianceStatus: "OK" | "Warning" | "Critical"; orderIndex: number;
}

GrantReportAttachmentDto: {
  grantReportAttachmentId: number; fileName: string; fileSize: number;
  fileType: string; storageKey: string?; attachmentCategory: string?;
  orderIndex: number;
}
```

**Summary DTO** (`GrantReportSummaryDto`):
```
{
  totalReports: number;
  pendingThisQuarter: number;
  overdue: number;
  accepted: number;
  revisionRequested: number;
  latestRevisionRequestTitle: string?;
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/crm/grant/grantreporting`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 7 columns (Grant, Report, Type, Due Date, Submitted, Status, Actions)
- [ ] 4 KPI widgets render with live counts from `GetGrantReportSummary`
- [ ] Search filters by ReportTitle / GrantCode / GrantTitle
- [ ] Grant select dropdown filters grid (only active+reporting grants shown in dropdown)
- [ ] Type chips multi-toggle and "All" mutual-exclusivity work correctly
- [ ] Status select filters: All / Draft / Submitted / Accepted / Revision Requested
- [ ] Date filter (server-computed): Overdue / Due This Month / Due Next 30 Days
- [ ] Status badges color-coded per status (amber/blue/green/red)
- [ ] Action buttons render per status (Draft → Edit+Submit; Submitted/Accepted → View; Revision → Edit + View Feedback)
- [ ] `?mode=new`: empty FORM renders 7 sections in correct order with correct icons
- [ ] Selecting a Grant pre-fills Reporting Period + Deliverables + Financial categories from `GetGrantReportPrefillData`
- [ ] Mini Grant context card appears with Grant details inline above Section 1
- [ ] Rich-text editors in Sections 2/5/6 — toolbar buttons functional (Bold/Italic/etc.)
- [ ] Section 3 child grid: Add/Remove rows + auto-compute Progress% + colored bar
- [ ] Section 4 child grid: Add/Remove rows + auto-compute Total row + Variance icon
- [ ] Section 7: drag-drop file zone renders + "Upload Attachment" button + attached file list with remove
- [ ] Save Draft creates record (Status=Draft) → URL changes to `?mode=edit&id={newId}`
- [ ] Submit to Funder runs validation (Executive Summary required for narrative types; Financials required for Financial/Final) → POST SubmitToFunder → URL `?mode=read&id={id}`
- [ ] `?mode=read&id=X`: DETAIL layout renders meta-grid (6 cells) + 6 narrative sections + Financial table (NO Variance column) + Attachments list — NOT the form disabled
- [ ] RevisionRequested report shows red banner with FunderFeedback at top of DETAIL
- [ ] Edit button on detail (Draft / RevisionRequested) → `?mode=edit&id=X` → FORM pre-filled
- [ ] Re-open for Editing button (Accepted) → confirmation dialog → reverts to Draft → URL `?mode=edit&id=X`
- [ ] Save in edit mode updates record → back to detail layout
- [ ] FK dropdowns load: Grant filtered to active+reporting; ReportType from MasterData GRANTREPORTTYPE
- [ ] Submit-time guards: cannot submit empty Exec Summary; cannot submit Financial type with empty financial lines; cannot submit Quarterly/Annual/Final with no deliverables
- [ ] Workflow buttons enforce role: AcceptReport / RequestRevision / ReopenForEditing only for BUSINESSADMIN
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] Permissions: Edit/Delete buttons respect role capabilities

**Service-Placeholder Verification:**
- [ ] "Preview as PDF" footer button → toast "PDF preview pending integration"
- [ ] "Download PDF" detail action → toast
- [ ] "Export All" header action → toast
- [ ] File upload (drag-drop + Upload Attachment + Attach Financial Statements + Add Story with Photo): metadata saved to backend; storageKey mocked; toast "File reference saved (storage upload pending integration)"
- [ ] Attachment download in DETAIL → toast

**DB Seed Verification:**
- [ ] Menu "Funder Reports" appears in sidebar under CRM > Grants
- [ ] Grid columns render correctly per seed
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)
- [ ] MasterData type GRANTREPORTTYPE seeded with 5 values

**Cross-Screen Verification:**
- [ ] Grant (#62) Tab 2 (Reports) wired to `GetGrantReports` filtered by `grantId={current grant}` — SERVICE_PLACEHOLDER removed from grant.md prompt
- [ ] Clicking a report from Grant detail navigates to `/crm/grant/grantreporting?mode=read&id={reportId}` (cross-page deep link)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** in any of the 4 tables — comes from HttpContext in FLOW screens
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout, read has DETAIL layout
- **DETAIL layout is a publication-style document**, NOT the form disabled — must build a separate component (`detail-view.tsx`) inside `view-page.tsx`. Mockup precedent: `.report-view-content` is centered max-width 900px white card with h4 section headings (grants-accent bottom-border), report-meta-grid (6 cells), and rendered HTML for narrative sections — completely different visual treatment from the form's `.editor-section` cards stacked at full width with toolbars and child grids.
- **Schema reuse** — this screen REUSES the `grant` schema bootstrapped by #62. Do NOT recreate IGrantDbContext / GrantDbContext / GrantMappings / DecoratorGrantModules. ONLY add DbSet entries + Mapster configs to the existing files.
- **GrantId FK readonly on edit** — selecting a different grant on an existing report would invalidate the financial snapshot and prior-period deliverable values. Lock the field at API + UI level once saved.
- **Status as string constant** (not MasterData FK) — precedent: SavedFilter. Constants live in `GrantReportStatusConstants.cs` to avoid a join on every list query.
- **TotalBudget snapshot** — captured from Grant.AwardedAmount on first save; does NOT update if Grant.AwardedAmount changes later. This protects historical reports against grant amendments. Document this in DTO comments.
- **Pre-fill on +New** — `GetGrantReportPrefillData` should return: budget categories from Grant.BudgetLines, prior-period deliverable values from the most recent `Accepted` GrantReport for the same (GrantId, ReportTypeId), reporting frequency from Grant.ReportingFrequencyId, suggested period derived from Grant.NextReportDueDate. If no prior accepted report exists, deliverables come from Grant milestones (if Grant entity has them) or empty array.
- **Route folder naming** — folder is `grantreporting` (matches existing FE stub at `PSS_2.0_Frontend/src/app/[lang]/crm/grant/grantreporting/page.tsx` and the MODULE_MENU_REFERENCE URL). Entity-internal naming uses `grantReport` / `GrantReports` everywhere else. The naming inconsistency is INTENTIONAL — do not "fix" it.
- **Existing FE stub at `crm/grant/grantreporting/page.tsx`** — currently `<div>Need to Develop</div>`. The FE dev MUST overwrite it (the build is FULL scope, not ALIGN). After overwrite, the page must `import` and render the page-components/crm/grant/grantreporting index.

### Build-Order Dependencies (CRITICAL)

⚠ **Grant (#62) is the FK target for GrantId — must be COMPLETED before GrantReport BE phase.**

- #62 Grant is currently `PROMPT_READY` (not built). The `grant` schema, IGrantDbContext, GrantModels group, and `Grant` entity all DO NOT EXIST yet.
- If GrantReport BE phase runs while #62 is unbuilt, it will fail at:
  - Entity reference: `[ForeignKey(nameof(GrantId))] public Grant Grant { get; set; }`  → cannot resolve `Grant`
  - DbContext reference: `IGrantDbContext.GrantReports` → IGrantDbContext does not exist
  - Mappings: `GrantMappings.cs` → file does not exist
- Recommended sequence: BUILD #62 → BUILD #63 → return to #62 to wire Reports tab live.
- The Grant prompt (#62) explicitly notes: "Tab 2/3 degrade SERVICE_PLACEHOLDER until #63 GrantReport built." So the chain works: #62 ships with mocked tabs → #63 builds → #62 enhanced to wire Reports tab.

### Service Dependencies (UI-only — handler is mocked)

> All UI in this list is built end-to-end. Only the handler call to the missing external service is replaced with a toast / mock.

- ⚠ **SERVICE_PLACEHOLDER: File Storage** — drag-drop upload, "Upload Attachment", "Attach Financial Statements", "Add Story with Photo". UI fully built (drag-drop zone, file list with icons + sizes, remove buttons, mime-type icon mapping). Handler captures filename + size + type and persists to GrantReportAttachment with mocked `storageKey` (e.g., GUID); toast "File reference saved (storage upload pending integration)". The actual binary upload is deferred until a file-storage service (S3/Azure Blob/local FS abstraction) exists in the codebase.
- ⚠ **SERVICE_PLACEHOLDER: PDF Export** — "Preview as PDF" footer button + "Download PDF" detail action + "Export All" header action. UI rendered (buttons styled, click handler bound); toast "PDF generation pending integration".
- ⚠ **SERVICE_PLACEHOLDER: Email/Notification on Submit** — "Submit to Funder" mutation only updates the database (StatusCode=Submitted, SubmittedDate=now). It does NOT actually email the funder. Note this on the Submit confirmation dialog: "Status updated. Funder notification pending integration." Do not block submission on the missing notification — the workflow state must transition.

Full UI must be built (buttons, drag-drop zones, modals, banners, badges, toolbars, child grids). Only the handler for the external service call is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning (2026-04-25) | HIGH (build gate) | BE | Grant (#62) is PROMPT_READY but not built. GrantId FK, `grant` schema, IGrantDbContext, GrantModels group all DO NOT EXIST yet. Building GrantReport BE before #62 will fail at compile-time. **Resolution**: gate Backend phase on #62 status check; if PROMPT_READY, halt and prompt user to build #62 first. | CLOSED (2026-04-26 — #62 was built before #63; dependency gate verified clean) |
| ISSUE-2 | planning (2026-04-25) | MEDIUM | BE+FE | File storage layer does not exist. All attachment uploads are SERVICE_PLACEHOLDER (metadata-only persist + mocked storageKey + toast). Same for "Attach Financial Statements" / "Add Story with Photo". UI must be fully built; handler mocked. | OPEN |
| ISSUE-3 | planning (2026-04-25) | LOW | BE | PDF generation infrastructure does not exist. Three actions ("Preview as PDF", "Download PDF", "Export All") are SERVICE_PLACEHOLDER (toast only). UI rendered; handler mocked. | OPEN |
| ISSUE-4 | planning (2026-04-25) | LOW | BE | Funder notification on Submit is SERVICE_PLACEHOLDER. SubmitToFunder mutation only updates database state; does not email/notify the funder. The workflow transition still happens; note added to Submit confirmation dialog. | OPEN |
| ISSUE-5 | planning (2026-04-25) | LOW | Cross-screen | After GrantReport COMPLETED, the Grant (#62) prompt's Tab 2 (Reports) SERVICE_PLACEHOLDER must be removed and wired to live `GetGrantReports?grantId=X`. This is a follow-up edit on grant.md — not a code change in #63. | OPEN |
| ISSUE-6 | planning (2026-04-25) | LOW | UX | Rich-text editor library is unspecified. FE Dev must search registry first (`grep -r RichTextEditor src/`) and reuse if found; else escalate (per component reuse-or-create memory: MASTER_GRID + FLOW only escalate when missing-and-complex — rich text qualifies). Decision pending FE Dev research. | CLOSED (2026-04-26 — REUSED `minimal-tiptap-editor` already installed in repo; wrapped in `RHFRichText`) |
| ISSUE-7 | planning (2026-04-25) | LOW | UX | "Deliverable Progress" rendering in DETAIL view is described as auto-generated narrative sentences (mockup precedent), but FE Dev may find a flat read-only table renders better. Decision deferred to UX Architect at Step 3. | CLOSED (2026-04-26 — flat read-only table chosen for cleaner glance + no fragile templating; matches funder PDF norms) |
| ISSUE-8 | build (2026-04-26) | LOW | FE | `isomorphic-dompurify` package added to package.json but not yet installed. User must run `pnpm install` (or `pnpm add isomorphic-dompurify @types/dompurify`) in PSS_2.0_Frontend/ before dev server compiles. Bash install was sandboxed during agent session. | OPEN |
| ISSUE-9 | build (2026-04-26) | LOW | BE | EF migration not generated this session (token-budget directive). User should run `dotnet ef migrations add AddGrantModule_GrantReports_Initial -p Base.Infrastructure -s Base.API` locally to materialize the 4 new tables in `grant` schema. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-26 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FLOW screen with High complexity. 3-mode view-page (new/edit/read), 2 distinct UI layouts (FORM + DETAIL), 4-state workflow (Draft → Submitted → Accepted/RevisionRequested with Reopen).
- **Files touched**:
  - BE (23 created + 4 modified):
    - Entities: GrantReport.cs, GrantReportDeliverable.cs, GrantReportFinancialLine.cs, GrantReportAttachment.cs (created)
    - EF Configs (in `GrantConfigurations/`): GrantReportConfiguration.cs + 3 child configs (created)
    - Schemas: GrantReportSchemas.cs (created — all DTOs + StatusConstants + TypeConstants + StatusBadge)
    - Commands (8): CreateGrantReport.cs, UpdateGrantReport.cs, DeleteGrantReport.cs, ToggleGrantReport.cs, SubmitToFunderGrantReport.cs, AcceptGrantReport.cs, RequestRevisionGrantReport.cs, ReopenGrantReport.cs (all created)
    - Queries (4): GetGrantReports.cs, GetGrantReportById.cs, GetGrantReportSummary.cs, GetGrantReportPrefillData.cs (all created)
    - Endpoints: GrantReportMutations.cs + GrantReportQueries.cs (created)
    - Wiring (modified): IGrantDbContext.cs (4 DbSets), GrantDbContext.cs (4 DbSets), DecoratorProperties.cs (4 constants in DecoratorGrantModules), GrantMappings.cs (7 Mapster configs)
  - FE (31 created + 8 modified):
    - DTOs/GQL: GrantReportDto.ts, GrantReportQuery.ts, GrantReportMutation.ts (created)
    - Page config + route: pages/crm/grant/grantreporting.tsx (created); app/[lang]/crm/grant/grantreporting/page.tsx (modified — overwrote stub)
    - Page components (8): index.tsx, index-page.tsx (Variant B), view-page.tsx (mode dispatcher), form-view.tsx, detail-view.tsx, grantreport-store.ts (Zustand), grantreport-widgets.tsx (4 KPIs), grantreport-filter-bar.tsx
    - Form widgets (7): editor-section, grant-context-card, rhf-rich-text (wraps MinimalTiptapEditor), deliverable-rows-editor, financial-lines-editor, attachment-drop-zone, form-action-footer
    - Detail widgets (7): detail-header-actions, revision-banner, report-meta-grid, detail-section, financial-read-table, deliverable-read-table (flat table — ISSUE-7 closed), attachment-read-list
    - Cell renderers (3 NEW): grant-context-link, grant-report-status-badge, grant-report-row-actions — registered in flow + advanced + basic component-column.tsx elementMappings
    - Utility: utils/sanitize.ts (DOMPurify wrapper)
    - Wiring (modified): grant-service/index.ts, gql-queries/grant-queries/index.ts, gql-mutations/grant-mutations/index.ts, grant-service-entity-operations.ts (GRANTREPORTING block), pages/crm/grant/index.ts, shared-cell-renderers/index.ts, 3× component-column.tsx (flow/advanced/basic), package.json (added `isomorphic-dompurify`)
  - DB: PSS_2.0_Backend/.../sql-scripts-dyanmic/GrantReport-sqlscripts.sql (created — Menu, MenuCapabilities, RoleCapabilities, Grid, Fields, GridFields, MasterDataType GRANTREPORTTYPE + 5 values)
- **Deviations from spec**:
  - File count: 19 BE files (vs prompt's "15") — Solution Resolver upgraded to file-per-concern (4 EF configs split, queries split into separate files). Same logical scope, cleaner organization.
  - File count: 31 FE files (vs prompt's "9") — UX Architect extracted form widgets (7) + detail widgets (7) + 3 cell renderers + utils to keep view-page.tsx readable. Same logical scope, better separation.
  - DETAIL view Section 4 (Deliverable Progress): chose flat read-only table over auto-generated narrative prose (ISSUE-7 closed by UX Architect — easier to scan, no templating fragility).
  - Skipped GRANTREPORTSTATUS MasterDataType — using GrantReportStatusConstants.cs static class (FLAG-4, precedent: SavedFilter).
  - Single SubmitToFunderGrantReport command handles both Draft→Submitted AND RevisionRequested→Submitted (FLAG-3 — no separate ResubmitReport command).
  - ReopenGrantReport handler clears AcceptedDate (FLAG-2).
- **Known issues opened**: ISSUE-8 (DOMPurify install pending — user must `pnpm install`); ISSUE-9 (EF migration not generated this session — user runs locally per token directive).
- **Known issues closed**: ISSUE-1 (#62 dependency gate verified), ISSUE-6 (TipTap reused), ISSUE-7 (flat table chosen for DETAIL Section 4).
- **Next step**: 
  1. User: `pnpm install` in PSS_2.0_Frontend/ to materialize isomorphic-dompurify
  2. User: `dotnet ef migrations add AddGrantModule_GrantReports_Initial -p Base.Infrastructure -s Base.API` to generate migration
  3. User: run `GrantReport-sqlscripts.sql` to seed Menu/Grid/MasterDataType
  4. User: `dotnet build` + `pnpm dev` for end-to-end verification
  5. Follow-up (separate task — ISSUE-5): wire Grant #62 Tab 2 (Reports) to `GetGrantReports?grantId=X` — currently SERVICE_PLACEHOLDER on grant.md prompt
