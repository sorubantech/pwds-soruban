---
screen: Grant
registry_id: 62
module: Grants
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: YES — `grant` schema
planned_date: 2026-04-25
completed_date: 2026-04-26
last_session_date: 2026-04-26
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + FORM layout + DETAIL layout)
- [x] Existing code reviewed (FE stub `crm/grant/grantlist/page.tsx` returns "Need to Develop"; NO BE entity)
- [x] Business rules + workflow extracted (7-stage pipeline)
- [x] FK targets resolved (Contact, Staff, Branch, Currency, MasterData — all EXIST)
- [x] File manifest computed (29 BE + 22 FE)
- [x] Approval config pre-filled (CRM_GRANT parent, GRANTLIST + 2 hidden child menus)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM 7 sections + DETAIL 5-tab + 5 KPIs + 4-state pipeline kanban)
- [ ] User Approval received
- [ ] **NEW MODULE BOOTSTRAP** — `grant` schema (IGrantDbContext + GrantDbContext + GrantMappings + DecoratorGrantModules + IApplicationDbContext inheritance + DependencyInjection register + GlobalUsing × 3)
- [ ] Backend code generated (4 entities + 6 EF configs + Schemas + 9 commands + 4 queries + 2 endpoint files)
- [ ] Backend wiring complete (IGrantDbContext / GrantDbContext / GrantMappings / DecoratorGrantModules)
- [ ] Frontend code generated (view-page 3 modes + Zustand store + 5-tab DETAIL + 7-section FORM + dual-view kanban/table)
- [ ] Frontend wiring complete (entity-operations + 3 column-type registries + sidebar + route OVERWRITE)
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW; 8 MasterDataTypes for stages/types/categories)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/grant/grantlist`
- [ ] Grid/Pipeline dual view: Pipeline kanban (default, 7 columns) + Table list (toggle button)
- [ ] `?mode=new` — empty FORM renders 7 sections (Funder / Grant Details / Proposal / Budget / Milestones / Attachments / Internal)
- [ ] `?mode=edit&id=X` — FORM loads pre-filled
- [ ] `?mode=read&id=X` — DETAIL renders Quick Stats + 5 tabs (Overview / Budget / Reports / Documents / Timeline)
- [ ] Create flow: +Add → fill form → Save as Draft / Submit Application → redirects `?mode=read&id={newId}`
- [ ] Edit flow: detail Edit button → FORM pre-filled → Save → back to detail
- [ ] FK dropdowns load: Funder (contacts filtered to organizations), Branch, Implementing Branches (multi), Currency, Purpose Program, Assigned Staff
- [ ] Summary widgets display 4 KPIs (Active Grants / Pipeline Value / Upcoming Deadlines / Compliance Rate)
- [ ] Budget child grid: add/remove rows + auto-total + admin% warning
- [ ] Milestone child grid: add/remove rows
- [ ] Attachment checklist: 5 required-doc rows + custom upload (SERVICE_PLACEHOLDER if no upload infra)
- [ ] Workflow transitions: Submit Application / Approve / Reject / Activate / Move to Reporting / Close
- [ ] DB Seed — menu visible in sidebar under CRM_GRANT

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Grant
Module: Grants (CRM)
Schema: `grant` (NEW — first entity owns the schema bootstrap)
Group: GrantModels (entities) / GrantBusiness (commands+queries) / GrantSchemas (DTOs) / Grant (endpoints)

Business: Grant tracks the full lifecycle of grant applications and awarded funding from institutional funders (foundations, multilaterals, government agencies). Grants & Compliance officers use it to manage prospects, draft applications, monitor approval, run awarded grants, log expenses against budget, submit funder reports, and close out completed grants. The screen exists because grant funding is one of the largest revenue streams for an NGO and requires multi-month tracking with strict reporting deadlines and compliance audits — losing a deadline can lose six- or seven-figure funding. It relates to Contact (funder = organization-type contact), Staff (assigned grant manager), Branch (managing + implementing offices), Currency (multi-currency funding), and downstream to GrantReport #63 (funder reports) and GrantCalendar #64 (deadline view). The DETAIL view is a workspace — Quick Stats up top show funded/spent/remaining/period/next-report-due, then 5 tabs surface Grant Information + Objectives, Budget Breakdown with progress bars, Funder Reports list with statuses, Documents repository, and a chronological Activity Timeline of every state change and tranche received.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from grant-list.html + grant-form.html + grant-detail.html. Audit columns omitted — inherited from Entity base.
> **CompanyId is NOT a field** — FLOW screens get tenant from HttpContext.

Table: `grant."Grants"` (parent) + 5 child tables in same schema

### Parent: Grant

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| GrantId | int | — | PK | — | Primary key |
| GrantCode | string | 50 | YES | — | Unique per Company. Auto-generated if empty (pattern `GRT-XXX` zero-padded — precedent: CaseCode in Case #50). Maps to mockup "GRT-012". |
| GrantTitle | string | 200 | YES | — | "Clean Water Initiative — East Africa & South Asia" |
| FunderContactId | int | — | YES | `cont.Contacts` | Funder organization. Filter ApiSelect to ContactType = "Organization/Funder" |
| GrantProgram | string | 200 | NO | — | "Global Water Access Program" — funder's named program/call |
| FunderContactPersonName | string | 100 | NO | — | "Jane Smith" — free-text (not a Contact FK; this is the funder's POC) |
| FunderContactEmail | string | 200 | NO | — | "jane@gatesfoundation.org" |
| FunderContactPhone | string | 30 | NO | — | "+1 (555) 000-0000" |
| FunderWebsite | string | 300 | NO | — | URL |
| FunderGrantNumber | string | 100 | NO | — | "BMGF-2025-4567" — funder's reference number (added in awarded state) |
| RequestedAmount | decimal(18,2) | — | YES | — | Amount applied for |
| AwardedAmount | decimal(18,2)? | — | NO | — | Set when status transitions to Approved/Active. Drives Funded amount on detail view. |
| CurrencyId | int | — | YES | `shared.Currencies` | USD/EUR/GBP/AED/INR |
| GrantTypeId | int | — | YES | `sett.MasterDatas` (TypeCode=`GRANTTYPE`) | Project / Operating-General / Capital / Research / Emergency |
| StartDate | DateTime? | — | NO | — | Awarded period start (month-precision in mockup but stored as full date) |
| EndDate | DateTime? | — | NO | — | Awarded period end |
| PurposeProgramId | int? | — | NO | `case.Programs` (if exists) OR free MasterData (`GRANTPURPOSE`) | Mockup shows hard-coded program list; **decision: use MasterData TypeCode=`GRANTPURPOSE`** to avoid coupling to Case schema (Program #51 may not be built). Values: Clean Water / Education / Healthcare / Orphan Care / Food Security / Women Empowerment / Community Development. |
| BranchId | int | — | YES | `app.Branches` | Managing branch (single) |
| StageId | int | — | YES | `sett.MasterDatas` (TypeCode=`GRANTSTAGE`) | Workflow state — Prospect / Application / Under Review / Approved / Active / Reporting / Closed |
| PriorityId | int? | — | NO | `sett.MasterDatas` (TypeCode=`GRANTPRIORITY`) | Low / Medium / High / Critical (defaults to Medium) |
| AssignedStaffId | int? | — | NO | `app.Staffs` | Grant manager |
| SubmissionDeadline | DateTime? | — | NO | — | When user must submit application by |
| SubmittedDate | DateTime? | — | NO | — | Stamped when status moves to Submitted/Application |
| DecisionDate | DateTime? | — | NO | — | Stamped when status moves to Approved/Rejected |
| RejectionReason | string | 500 | NO | — | Captured if Rejected |
| NextReportDueDate | DateTime? | — | NO | — | Computed from milestones + reporting frequency, OR manually set. Drives "Next Report Due" KPI + warning indicator. |
| ReportingFrequencyId | int? | — | NO | `sett.MasterDatas` (TypeCode=`GRANTREPORTINGFREQ`) | Monthly / Quarterly / Semi-Annual / Annual |
| FinancialReportingFrequencyId | int? | — | NO | `sett.MasterDatas` (TypeCode=`GRANTREPORTINGFREQ`) | Same MasterData — separate frequency for financials |
| AuditRequired | bool | — | YES | — | Default false. "Yes, annual audit required" toggle. |
| ExecutiveSummary | string | 4000 | NO | — | Up to 500 words plain text |
| ProblemStatement | string | max | NO | — | Rich text (HTML) |
| ProposedSolution | string | max | NO | — | Rich text (HTML) |
| ExpectedOutcomes | string | max | NO | — | Rich text (HTML) |
| SustainabilityPlan | string | max | NO | — | Rich text (HTML) |
| InternalNotes | string | 2000 | NO | — | Visible only to internal staff |
| TotalSpent | decimal(18,2) | — | NO | — | Computed/cached from sum(GrantExpense.Amount) — refreshed on expense add/remove. Drives Budget tab + KPIs. |
| ComplianceRate | int? | — | NO | — | Computed: (reports submitted on time / reports due) × 100. Refreshed when reports are accepted/late. Drives Compliance Rate KPI. |
| IsActive | bool | — | YES | — | Inherited from Entity base — toggles soft enable |

### Child: GrantBudgetLine (1:Many — atomic create with parent)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| GrantBudgetLineId | int | — | PK | — |
| GrantId | int | — | YES | FK to Grant |
| Category | string | 100 | YES | "Construction" / "Staff" / "Training" / "M&E" / "Travel" / "Admin" |
| BudgetedAmount | decimal(18,2) | — | YES | — |
| Description | string | 300 | NO | "Well construction materials and labor" |
| SortOrder | int | — | YES | Row order in form |
| SpentAmount | decimal(18,2) | — | NO | Cached sum of GrantExpenses.Amount where ExpenseCategory matches this line |
| IsAdminCategory | bool | — | YES | Default false — true for the "Admin" line; drives 10% admin-cap warning |

### Child: GrantMilestone (1:Many — atomic create with parent)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| GrantMilestoneId | int | — | PK | — |
| GrantId | int | — | YES | FK to Grant |
| MilestoneTitle | string | 200 | YES | "Phase 1: Assessment" |
| TargetDate | DateTime | — | YES | Month-precision OK |
| Deliverable | string | 500 | NO | "Needs assessment report" |
| TargetValue | int? | — | NO | "50" (wells), "200" (tests) — used by Objectives & Deliverables tab |
| ProgressValue | int | — | NO | Default 0 — manually updated as work progresses |
| StatusCode | string | 30 | NO | NotStarted / OnTrack / AtRisk / Completed — derived if null (TargetDate vs today) |
| SortOrder | int | — | YES | Row order |

### Child: GrantImplementingBranch (Many:Many junction)

| Field | C# Type | Required | Notes |
|-------|---------|----------|-------|
| GrantImplementingBranchId | int | PK | — |
| GrantId | int | YES | FK |
| BranchId | int | YES | FK to `app.Branches` |
| Composite unique: (GrantId, BranchId) | | | |

### Child: GrantAttachment (1:Many — checklist + custom uploads)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| GrantAttachmentId | int | — | PK | — |
| GrantId | int | — | YES | FK |
| DocumentTypeCode | string | 50 | YES | `ORG_CERT` / `AUDIT_FS` / `BOARD_LIST` / `LETTERS_OF_SUPPORT` / `PRIOR_GRANT_REPORTS` / `CUSTOM` — drives the checklist rendering. Custom = freely-named user upload. |
| DocumentName | string | 200 | YES | "Organization registration certificate" or freely-named for custom |
| FileName | string | 300 | NO | "org-cert-2024.pdf" |
| FileUrl | string | 500 | NO | URL to uploaded file (or null while SERVICE_PLACEHOLDER) |
| FileSizeBytes | long? | — | NO | For "2.4 MB" display |
| MimeType | string | 50 | NO | application/pdf, etc. |
| IsRequired | bool | — | YES | True for the 3 required mockup rows; false for "Optional" + custom |
| IsUploaded | bool | — | YES | Default false. Toggle when file uploaded. |
| UploadedDate | DateTime? | — | NO | — |
| UploadedByStaffId | int? | — | NO | FK to Staff |

### Child: GrantStageHistory (1:Many — drives Activity Timeline tab)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| GrantStageHistoryId | int | — | PK | — |
| GrantId | int | — | YES | FK |
| FromStageId | int? | — | NO | Null on first row (initial stage) |
| ToStageId | int | — | YES | FK to `sett.MasterDatas` (TypeCode=`GRANTSTAGE`) |
| TransitionDate | DateTime | — | YES | Stamped on transition |
| ActorStaffId | int? | — | NO | Who triggered the transition |
| Notes | string | 500 | NO | Free-text e.g. "Submitted via BMGF online portal" |
| AmountReceived | decimal(18,2)? | — | NO | If transition records a tranche disbursement (mockup: "First tranche received — $300,000") |

**Note on additional related entities**:
- **GrantExpense** + **GrantReport** are referenced in the DETAIL view (Budget tab + Reports tab) but belong to **GrantReport #63** (separate registry entry — Funder Reports screen). For #62, render those tabs as **read-only summaries fed by GrantReport #63 queries**, OR if #63 is not built, render empty-state placeholders. See §⑫ ISSUE-1.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelectV2 queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| FunderContactId | Contact | [Contact.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/Contact.cs) ✓ EXISTS | `contacts` (GetContacts) | `contactName` (id: `contactId`) | `ContactResponseDto` |
| BranchId | Branch | [Branch.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Branch.cs) ✓ EXISTS | `branches` (GetBranches) | `branchName` (id: `branchId`) | `BranchResponseDto` |
| GrantImplementingBranch.BranchId | Branch | same as above | `branches` | `branchName` | `BranchResponseDto` |
| CurrencyId | Currency | [Currency.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs) ✓ EXISTS | `currencies` (GetCurrencies) | `currencyCode` (id: `currencyId`); display `currencyCode` + `currencyName` | `CurrencyResponseDto` |
| GrantTypeId | MasterData | [MasterData.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/MasterData.cs) ✓ EXISTS | `masterDataListByTypeCode(typeCode: "GRANTTYPE")` | `dataName` (id: `masterDataId`) | `MasterDataResponseDto` |
| StageId | MasterData | same | `masterDataListByTypeCode(typeCode: "GRANTSTAGE")` | `dataName` (with `colorHex` for badge) | `MasterDataResponseDto` |
| PriorityId | MasterData | same | `masterDataListByTypeCode(typeCode: "GRANTPRIORITY")` | `dataName` | `MasterDataResponseDto` |
| PurposeProgramId | MasterData | same | `masterDataListByTypeCode(typeCode: "GRANTPURPOSE")` | `dataName` | `MasterDataResponseDto` |
| ReportingFrequencyId | MasterData | same | `masterDataListByTypeCode(typeCode: "GRANTREPORTINGFREQ")` | `dataName` | `MasterDataResponseDto` |
| FinancialReportingFrequencyId | MasterData | same | `masterDataListByTypeCode(typeCode: "GRANTREPORTINGFREQ")` | `dataName` | `MasterDataResponseDto` |
| AssignedStaffId | Staff | [Staff.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Staff.cs) ✓ EXISTS | `staffs` (GetStaffs) | `staffName` (id: `staffId`) | `StaffResponseDto` |
| GrantStageHistory.ActorStaffId | Staff | same | `staffs` | `staffName` | `StaffResponseDto` |
| GrantAttachment.UploadedByStaffId | Staff | same | `staffs` | `staffName` | `StaffResponseDto` |

**No hard build-order dependencies** — all FK targets exist. Schema bootstrap is owned by THIS screen (Grant is the first entity in the new `grant` schema).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `GrantCode` must be unique per Company (filtered unique index on `CompanyId + GrantCode`).
- `GrantImplementingBranch` composite unique on `(GrantId, BranchId)`.

**Required Field Rules:**
- `GrantTitle`, `FunderContactId`, `RequestedAmount`, `CurrencyId`, `GrantTypeId`, `BranchId`, `StageId` — mandatory on all stages.
- `ExecutiveSummary` — required when transitioning out of Prospect (i.e., from Application onward).
- `AwardedAmount` — required when StageId moves to Approved or Active.
- `RejectionReason` — required when StageId moves to Rejected.
- `FunderGrantNumber` — required when StageId moves to Active.
- `EndDate >= StartDate` when both are set.

**Conditional Rules:**
- If `AuditRequired = true`, no extra fields, but compliance scoring weighs audit submission.
- If `IsAdminCategory = true` on a budget line → flag if (admin amount / total budget) > 0.10 with warning toast (mockup: "Admin costs at 6% — within typical funder limit of 10%").
- Sum of `GrantBudgetLine.BudgetedAmount` should equal `RequestedAmount` (or `AwardedAmount` once awarded). Show inline diff if mismatch — non-blocking warning.
- `Sum(GrantImplementingBranch)` ≥ 0 — managing branch (BranchId) does NOT need to also be an implementing branch (mockup shows "Dubai (managing), Nairobi (implementing), Dhaka (implementing)").

**Business Logic:**
- `RequestedAmount > 0` and `AwardedAmount > 0` (when set).
- `GrantCode` auto-generated as `GRT-{NextNumber:D3}` per Company if not provided. Use a SERIES helper that scans MAX(GrantCode) and increments.
- `TotalSpent` cached on the Grant — updated by triggers in GrantExpense create/delete (or recomputed nightly if expense entity not yet built — see §⑫ ISSUE-1).
- `ComplianceRate` cached on the Grant — recomputed when GrantReport is marked Submitted/Late/Accepted.
- "Days Remaining" and "Next Report Due" countdowns computed in projection (server-side).

**Workflow** (7-stage state machine — reflects the kanban columns + Internal Notes section):

States and transitions:
```
Prospect ──► Application ──► UnderReview ──► Approved ──► Active ──► Reporting ──► Closed
   │             │                │              │           │           │
   └─►(skip)─────┘                └──► Rejected  └──► OnHold ┴──► Cancelled
```

| Transition | Trigger | Side Effects |
|------------|---------|--------------|
| → Application | "Submit Application" button on form (or Stage select) | Stamp `SubmittedDate`. Append GrantStageHistory row. |
| → UnderReview | Funder acknowledged receipt | Append history. |
| → Approved | "Approve" header action on detail | Stamp `DecisionDate`. Require `AwardedAmount`. Append history. |
| → Rejected | "Reject" header action | Stamp `DecisionDate`. Require `RejectionReason`. Append history with reason. |
| → Active | "Activate Grant" header action | Require `FunderGrantNumber` + `StartDate` + `EndDate`. Append history. |
| → Reporting | Auto when `NextReportDueDate <= now() + 30d` AND status = Active (background job — V1 manual button). Or "Move to Reporting" header action. | Append history. |
| → Closed | "Close Grant" header action | Stamp `EndDate` if null. Append history. Lock most fields. |
| → OnHold (from Active) | "Put On Hold" header action | Append history with notes. |
| → Cancelled (from any pre-Active) | "Cancel" More-dropdown action | Append history. |

**Tranche disbursement** (via header action "Record Tranche"):
- Append `GrantStageHistory` row with `AmountReceived` set, `Notes = "First tranche received — $300,000"` etc. Does NOT change Stage. Drives Timeline tab entries.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: FLOW with parent + 5 child entities, dual list view (kanban + table), detail page with 5 tabs and quick-stats bar, workflow state machine
**Reason**: "+New Grant Application" navigates to `?mode=new` (full page form, not modal); URL changes; clicking a kanban card or table row navigates to `?mode=read&id=X` (full DETAIL with tabs — different UI from form). Transactional workflow with multi-month lifecycle.

**Backend Patterns Required:**
- [x] Standard CRUD (11 base files)
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation (5 child collections persisted atomically: BudgetLines, Milestones, ImplementingBranches, Attachments, StageHistory initial entry)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 9: Funder, Branch×2, Currency, Type, Stage, Priority, Purpose, Staff, ReportingFreq×2)
- [x] Unique validation — `GrantCode` per Company (filtered index)
- [x] Workflow commands (UpdateGrantStage with state-transition guards + 8 specialized commands: SubmitApplication, ApproveGrant, RejectGrant, ActivateGrant, MoveToReporting, CloseGrant, PutOnHold, CancelGrant)
- [x] RecordTranche command (appends GrantStageHistory row without changing stage)
- [ ] File upload command — **SERVICE_PLACEHOLDER** (file infrastructure check pending — see §⑫ ISSUE-2). Persist URL string in V1.
- [x] Custom business rule validators (admin-cap %, AwardedAmount required on Approve, FunderGrantNumber required on Activate, RejectionReason required on Reject, EndDate >= StartDate)
- [x] Summary query (GetGrantSummary — 4 KPIs: ActiveGrantsCount + ActiveGrantsFundedTotal, PipelineValue, UpcomingDeadlinesCount + NextDeadlineLabel, ComplianceRatePct + OverdueReportsCount)
- [x] **NEW MODULE BOOTSTRAP** — `grant` schema first time used. Bootstrap files: `IGrantDbContext` + `GrantDbContext` + `GrantMappings` + `IApplicationDbContext` inheritance + `DependencyInjection.cs` register + `DecoratorGrantModules` + GlobalUsing × 3.

**Frontend Patterns Required:**
- [x] FlowDataTable (table view)
- [x] **DUAL VIEW** — Kanban Pipeline (default) + Table list (toggle). Kanban is custom component (NOT FlowDataTable) — 7 stage columns, drag-to-move-stage planned for later (V1 = click card to navigate).
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form for FORM layout
- [x] Zustand store (`grant-store.ts`)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back, Save as Draft, Submit Application buttons)
- [x] Child grids inside form (Budget table + Milestone table — inline rows with add/remove + auto-total)
- [x] Multi-select FK dropdown (Implementing Branches)
- [x] Workflow status badge + transition action buttons (header actions on DETAIL)
- [x] Rich-text editor placeholder (4 narrative fields — toolbar + contenteditable; SERVICE_PLACEHOLDER for full WYSIWYG, V1 = simple textarea or `react-quill` if already installed)
- [x] File upload widget (SERVICE_PLACEHOLDER — see §⑫ ISSUE-2)
- [x] Summary cards / count widgets above grid (4 KPIs — Active Grants / Pipeline Value / Upcoming Deadlines / Compliance Rate)
- [x] Grid aggregation columns — `progressPct` per row (in table view); kanban cards show progress bar derived from spent/awarded
- [x] **5-tab DETAIL** layout (Overview / Budget / Reports / Documents / Timeline) — same pattern as Case #50 / Beneficiary #49
- [x] Quick-stats bar above tabs (5 cards: Funded / Spent + bar / Remaining / Period / Next Report Due)
- [x] Filter bar with 4 selects (Stage, Funder, Amount Range, Branch)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from grant-list.html + grant-form.html + grant-detail.html.

### Grid/List View

**Display Mode**: `table` (kanban is a parallel custom component, not a card-grid variant). The toggle bar lets the user switch between Kanban Pipeline and Table list — both share the same data source (GET_GRANTS_QUERY).

**Default view**: Kanban Pipeline (mockup default). Persist user choice in `grant-store.ts` (zustand) so it survives navigation.

**Grid Layout Variant**: `widgets-above-grid` → FE Dev uses **Variant B**: `<ScreenHeader>` + KPI widgets row + view-toggle bar + (kanban OR DataTableContainer with `showHeader={false}`). MANDATORY to avoid double-header bug (precedent: ContactType #19).

**Page Header (ScreenHeader)**:
- Title: "Grants"
- Subtitle: "Track grant applications, funding, and compliance"
- Icon: `ph:file-text` (from `fa-file-contract`)
- Right actions: `+ New Grant Application` (primary button — navigates to `?mode=new`), `Export` dropdown (CSV / Excel / PDF — wire CSV via existing export service if present; Excel + PDF = SERVICE_PLACEHOLDER).

#### KPI Widgets (4 cards above view toggle)

| # | Widget Title | Value Source | Display Type | Sub-text |
|---|-------------|-------------|-------------|----------|
| 1 | Active Grants | `summary.activeGrantsCount` | number (large) | "Total funded: $X" (`summary.activeGrantsFundedTotalLabel`) — format with currency |
| 2 | Pipeline Value | `summary.pipelineValueLabel` | currency | "X applications pending" (`summary.pipelineApplicationsCount`) |
| 3 | Upcoming Deadlines | `summary.upcomingDeadlinesCount` | number | "Next: {funder} report {date}" (`summary.nextDeadlineLabel`) |
| 4 | Compliance Rate | `summary.complianceRatePct%` | percentage | "X overdue report(s)" (`summary.overdueReportsCount`) |

Source: `getGrantSummary` query.

#### View Toggle Bar
- Two toggle buttons: `Pipeline` (default, icon `ph:columns`) | `List` (icon `ph:table`)
- Right side: Filter bar (4 selects — Stage / Funder / Amount Range / Branch)

#### Filter Bar
| Filter | Source | GraphQL Arg |
|--------|--------|-------------|
| Stage | `masterDataListByTypeCode("GRANTSTAGE")` + "All Stages" | `stageCode` |
| Funder | `contacts` query (org-type filter) + "All Funders" | `funderContactId` |
| Amount Range | Hard-coded enum: `<50K`, `50K-100K`, `100K-250K`, `250K-500K`, `>500K` | `amountRangeCode` |
| Branch | `branches` + "All Branches" | `branchId` |

#### Kanban Pipeline View (default)

7 columns (one per stage), header bar colored by stage:
| Stage | Header Color | DataValue (MasterData) |
|-------|--------------|------------------------|
| Prospect | indigo (#6366f1) | `PROSPECT` |
| Application | violet (#8b5cf6) | `APPLICATION` |
| Under Review | amber (#f59e0b) | `UNDERREVIEW` |
| Approved | green (#22c55e) | `APPROVED` |
| Active | grants-blue (#0369a1) | `ACTIVE` |
| Reporting | rose (#e11d48) | `REPORTING` |
| Closed | slate (#64748b) | `CLOSED` |

Column header: `<stage name>` left, `<count>` chip right. Body: vertical list of `KanbanCard` components.

**KanbanCard** content (from mockup, lines 636-715):
- Funder name (bold, 0.8125rem)
- Amount (large 1rem bold, accent color)
- Deadline row: clock icon + text (e.g., "LOI due May 1, 2026" / "Submitted Apr 15" / "Decision pending" / "Ongoing — Dec 2026" / "Report due Apr 30" / "Completed")
- Progress mini-bar (4px) — only for Active and Closed (spent% — from `progressPct`)
- Click → `?mode=read&id={grantId}`
- Empty column: "No grants awaiting activation" centered text

#### Table View (toggle)

**Display Mode**: `table` via `<AdvancedDataTable>` / `<FlowDataTable>` (Variant B: `showHeader={false}`).

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Grant ID | `grantCode` | text-link | 110px | YES | Click → `?mode=read&id={id}` (renderer: `link-cell` accent color) |
| 2 | Funder | `funderContactName` | text-bold | auto | YES | FK display |
| 3 | Title | `grantTitle` | text | auto | YES | — |
| 4 | Amount | `amountLabel` | currency | 120px | YES | Right-aligned. Format `${awardedAmount ?? requestedAmount}` |
| 5 | Deadline | `deadlineLabel` | text | 120px | YES | Computed: "Ongoing" if Active no deadline, "Apr 30, 2026" date else "—" |
| 6 | Stage | `stageCode`/`stageName`/`stageColorHex` | badge | 130px | YES | NEW renderer `grant-stage-badge` (color-by-stage, see §⑥ Renderers) |
| 7 | Progress | `progressPct` | progress-bar + text | 140px | YES | NEW renderer `grant-progress-bar` (mini bar + "65% spent") — empty if Stage < Active |
| 8 | Branch | `branchName` | text | 100px | YES | Managing branch |
| 9 | Actions | — | actions | 100px | NO | View button + kebab (Edit / Approve / Reject / Activate / Close / Delete based on stage) |

**Search/Filter Fields**: `grantCode`, `grantTitle`, `funderContactName`. Plus 4 select filters.

**Grid Actions**: View (→ read mode), Edit (→ edit mode), per-row kebab with stage-aware actions (Submit / Approve / Reject / Activate / Move to Reporting / Close / Delete).

**Row Click**: Navigates to `?mode=read&id={grantId}` (DETAIL layout).

**Renderers needed (NEW — register in 3 column-type registries + barrel)**:
1. `grant-stage-badge` — reads `stageColorHex` (or maps stageCode to color), renders pill badge with emoji icon (🟢/🟡/🔵/etc.). Precedent: Tag #22 + DonationCategory #3 (color-by-data renderer).
2. `grant-progress-bar` — mini bar (80px × 6px) + "X% spent" label. Color-graded: ≤80% accent, 81–95% warning, >95% danger.
3. `link-cell` (already exists — verify in shared-cell-renderers) — used for `grantCode` to navigate on click.

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

#### LAYOUT 1: FORM (mode=new & mode=edit)

> The form opened by "+ New Grant Application" (`?mode=new`) or Edit button (`?mode=edit&id={id}`). React Hook Form. Sticky footer with Cancel + Save as Draft + Submit Application.

**Page Header (FlowFormPageHeader)**:
- Back button (arrow-left → grid `/grant/grantlist`)
- Title: "New Grant Application" (or "Edit Grant Application — GRT-XXX" in edit mode)
- Subtitle: "Submit a new grant application or track a prospect"
- Icon: `ph:file-plus` (from `fa-file-circle-plus`)
- Right actions: NONE (sticky footer holds them)

**Section Container Type**: `cards` (each section = white card with rounded border, separated by margin — NOT accordion). Numbered circle badge at section title. Per mockup grant-form.html lines 594-1040.

**Form Sections** (in display order from mockup):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | `ph:building-bank` (fa-building-columns) | Funder Information | 2-column auto-fit | always expanded | FunderName (ApiSelect Contact), GrantProgram (text), FunderContactPersonName (text), FunderContactEmail (email), FunderContactPhone (tel), FunderWebsite (url) |
| 2 | `ph:file-text` (fa-file-contract) | Grant Details | full-width title + 2-col below | always expanded | GrantTitle (full-width), RequestedAmount (number) + Currency (select side-by-side), GrantType (select), StartDate (month picker), EndDate (month picker), Purpose (ApiSelect MasterData), Branch (ApiSelect — managing), ImplementingBranches (multi-select ApiSelect) |
| 3 | `ph:pen-nib` (fa-pen-fancy) | Proposal Narrative | full-width stacked | always expanded | ExecutiveSummary (textarea, 500-word counter), ProblemStatement (rich-text), ProposedSolution (rich-text), ExpectedOutcomes (rich-text), SustainabilityPlan (rich-text) |
| 4 | `ph:coins` (fa-coins) | Budget | child grid | always expanded | BudgetLines child grid (Category / Amount / Description / Remove) + add-row button + total footer + admin-warning banner |
| 5 | `ph:flag-checkered` (fa-flag-checkered) | Milestones & Reporting | child grid + 3-col below | always expanded | Milestones child grid (Milestone / TargetDate / Deliverable / Remove) + add-row button. Below: ReportingFrequency (select), FinancialReportingFrequency (select), AuditRequired (toggle) |
| 6 | `ph:paperclip` (fa-paperclip) | Attachments | checklist | always expanded | 5 required-doc rows (checkbox + name + uploaded-status + Upload button) + custom Add Document button. SERVICE_PLACEHOLDER for actual upload — see §⑫ ISSUE-2. |
| 7 | `ph:lock` (fa-lock) | Internal Notes | 2-col + full-width textarea | always expanded | Stage (select), AssignedStaff (ApiSelect), Priority (select MasterData), SubmissionDeadline (date), InternalNotes (full-width textarea) |

**Field Widget Mapping** (all fields across all sections):

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| FunderContactId | 1 | ApiSelectV2 | "Search or select funder..." | required | Query: `contacts` (filter by ContactType org if such filter exists, else no filter); + "Add New Funder" link below = navigate to `/contact/allcontacts?mode=new&type=organization` |
| GrantProgram | 1 | text | "e.g., Annual Open Call" | max 200 | — |
| FunderContactPersonName | 1 | text | "Contact person name" | max 100 | — |
| FunderContactEmail | 1 | email | "email@example.com" | email format, max 200 | — |
| FunderContactPhone | 1 | tel | "+1 (555) 000-0000" | max 30 | — |
| FunderWebsite | 1 | url | "https://..." | url format, max 300 | — |
| GrantTitle | 2 | text | "Enter grant title" | required, max 200 | full-width |
| RequestedAmount | 2 | number (currency) | "0.00" | required, > 0 | Right-aligned, monospace; format with thousand separators on blur |
| CurrencyId | 2 | ApiSelectV2 | "USD" | required | Query: `currencies`; default USD if user's default not set |
| GrantTypeId | 2 | ApiSelectV2 | "Select grant type" | required | Query: `masterDataListByTypeCode(typeCode: "GRANTTYPE")` |
| StartDate | 2 | month-picker | — | optional | Stored as full DateTime (1st of month) |
| EndDate | 2 | month-picker | — | optional, ≥ StartDate | — |
| PurposeProgramId | 2 | ApiSelectV2 | "Select purpose..." | optional | Query: `masterDataListByTypeCode(typeCode: "GRANTPURPOSE")` |
| BranchId | 2 | ApiSelectV2 | "Select branch..." | required | Query: `branches`. Managing branch (single). |
| ImplementingBranchIds[] | 2 | multi-select ApiSelectV2 | "Select implementing branches" | optional | Query: `branches`; render as chip-list. Persist via GrantImplementingBranch junction. |
| ExecutiveSummary | 3 | textarea (rows=4, char-count to 500 words) | "Brief overview of the proposed project..." | optional, max 4000 chars (~500 words) | Counter under field |
| ProblemStatement | 3 | rich-text editor (placeholder for `react-quill` or simple toolbar contenteditable) | "Describe the problem this grant will address..." | optional | Stored as HTML string. SERVICE_PLACEHOLDER if `react-quill` not installed → fall back to textarea. |
| ProposedSolution | 3 | rich-text | "Describe your proposed approach and methodology..." | optional | Same as above |
| ExpectedOutcomes | 3 | rich-text | "Describe measurable outcomes and impact targets..." | optional | Same as above |
| SustainabilityPlan | 3 | rich-text | "Describe how the project will be sustained beyond the grant period..." | optional | Same as above |
| BudgetLines[] | 4 | child grid (see below) | — | sum should ≈ RequestedAmount (warning) | Inline editable rows + add/remove + auto-total |
| Milestones[] | 5 | child grid (see below) | — | optional | Inline editable rows + add/remove |
| ReportingFrequencyId | 5 | ApiSelectV2 | "Quarterly" | optional | `masterDataListByTypeCode("GRANTREPORTINGFREQ")` |
| FinancialReportingFrequencyId | 5 | ApiSelectV2 | "Quarterly" | optional | Same query |
| AuditRequired | 5 | toggle switch + label | "Yes, annual audit required" | required (boolean) | Default false |
| Attachments[] | 6 | checklist + upload | — | optional | 5 pre-defined `DocumentTypeCode` rows + Custom row generator |
| StageId | 7 | select MasterData | — | required, default `Application` for new | `masterDataListByTypeCode("GRANTSTAGE")` |
| AssignedStaffId | 7 | ApiSelectV2 | "Select staff..." | optional | `staffs` |
| PriorityId | 7 | ApiSelectV2 | "Medium" | optional, default Medium | `masterDataListByTypeCode("GRANTPRIORITY")` |
| SubmissionDeadline | 7 | date-picker | — | optional | — |
| InternalNotes | 7 | textarea (rows=3, full-width) | "Notes visible only to internal staff..." | optional, max 2000 | — |

**Special Form Widgets**:

- **Currency-prefix Amount Input** (Section 2): two-input row — RequestedAmount (flex:1) + CurrencyId (width:100px). Component: `<AmountWithCurrencyInput>` (NEW reusable — escalate to UX/component reuse-or-create per memory; if missing, create as static composite of `<NumberInput>` + `<ApiSelectV2>`).

- **Multi-select with chips** (Implementing Branches): `<ApiSelectV2 isMulti />` if FE registry supports it; else escalate.

- **Rich Text Editor placeholder** (4 narrative fields):
  | Toolbar buttons | Bold / Italic / Underline / Bullet List / Numbered List / Link / Image |
  | Body | min-height 120px, contenteditable |
  - V1 plan: use existing rich-text component if found in FE registry; ELSE fall back to plain `<textarea>` and flag SERVICE_PLACEHOLDER (rich-text formatting not persisted).

- **Child Grid: BudgetLines** (Section 4):
  | Column | Width | Widget | Notes |
  |--------|-------|--------|-------|
  | Category | 30% | text input | Required |
  | Amount | 20% | number input (right-aligned, currency-formatted on blur) | Required, > 0; on input → recompute total + admin warning |
  | Description | 40% | text input | — |
  | Remove | 10% | × icon button | Soft-remove from RHF array |
  - Footer: "Total | $X" (bold, right-aligned, recomputed reactively)
  - Add row button: dashed border full-width "+ Add Budget Line"
  - Admin-warning banner: amber "⚠ Admin costs at X% — within typical funder limit of 10%" (or red if > 10%) — computed from budget lines where `IsAdminCategory = true` (V1 = match category name "Admin" case-insensitive)

- **Child Grid: Milestones** (Section 5):
  | Column | Width | Widget | Notes |
  |--------|-------|--------|-------|
  | Milestone | 30% | text input | Required |
  | Target Date | 20% | month-picker | Required |
  | Deliverable | 40% | text input | Optional |
  | Remove | 10% | × icon button | Soft-remove |
  - Add row button: "+ Add Milestone"

- **Attachment Checklist** (Section 6):
  - 5 pre-rendered rows for required documents (DocumentTypeCode = `ORG_CERT`, `AUDIT_FS`, `BOARD_LIST`, `LETTERS_OF_SUPPORT`, `PRIOR_GRANT_REPORTS`):
    | Element | Behavior |
    |---------|----------|
    | Checkbox | Read-only — auto-checked when `IsUploaded = true` |
    | DocumentName | Static label per row |
    | Status | "filename uploaded" (success) / "Optional — not uploaded" (warning) / "Required — not uploaded" (danger) |
    | Action button | "Upload" (if not uploaded) / "Uploaded ✓" (if uploaded — clicking opens replace dialog) |
  - "+ Add Document" button at bottom — adds custom row with editable name + Upload button

**Sticky Footer** (mockup lines 1042-1049):
- Left: `Cancel` button (navigates to grid)
- Right: `Save as Draft` (primary) + `Submit Application` (outline accent — only enabled if all required fields valid; transitions Stage → Application)

#### LAYOUT 2: DETAIL (mode=read) — DIFFERENT UI from the form

> The read-only detail page when user clicks a kanban card or table row (`?mode=read&id={id}`).

**Page Header (FlowFormPageHeader-styled — see mockup grant-detail.html lines 573-597)**:
- Back button (arrow-left → grid)
- Title row: `<grant-code chip>` (small accent-bg pill) + Grant Title (h1 1.5rem)
- Subtitle row (3 inline items): `🏛️ Funder Name`, status badge (color-by-stage), amount badge (accent color, $500,000)
- Right actions:
  - `Edit` (outline) → `?mode=edit&id={id}`
  - `Add Report` (primary) → navigate to `/crm/grant/grantreporting?mode=new&grantId={id}` (links to Grant Report #63 — SERVICE_PLACEHOLDER if #63 not built; show toast "Grant Reports coming soon")
  - `Add Expense` (outline) → opens `<RecordExpenseModal>` (SERVICE_PLACEHOLDER if GrantExpense entity not built — see §⑫ ISSUE-1; toast "Add Expense coming with #63")
  - `⋮` More dropdown: stage-conditional actions (Submit / Approve / Reject / Activate / Move to Reporting / Put On Hold / Cancel / Close / Delete / Duplicate / Print / Record Tranche)

**Quick Stats Bar (5 cards)** — mockup lines 599-624:
| # | Card Title | Value Source | Format | Sub-text |
|---|-----------|-------------|--------|----------|
| 1 | Funded Amount | `awardedAmount ?? requestedAmount` | currency (large, accent color) | — |
| 2 | Spent | `totalSpent` (X% of funded) | currency + `(progressPct%)` + progress bar | — |
| 3 | Remaining | `awardedAmount - totalSpent` | currency (success color) | — |
| 4 | Period | `startDate ↔ endDate` | "Jan 2025 — Dec 2026" | "X months, Y remaining" |
| 5 | Next Report Due | `nextReportDueDate` | "Apr 30, 2026" (warning color if < 30 days) | "X days remaining" (warning color) |

**Tabs** (5 tabs, horizontal scroll on mobile) — mockup lines 626-633:
| # | Tab Label | Icon | Content |
|---|-----------|------|---------|
| 1 | Overview | `ph:info` | 2 cards: Grant Information (info-grid) + Objectives & Deliverables (table from GrantMilestone) |
| 2 | Budget | `ph:coins` | Budget Breakdown table (per BudgetLine: Category / Budgeted / Spent / Remaining / % Used / Progress bar) + footer total + Add Expense button + Burn-Down chart placeholder |
| 3 | Reports | `ph:file-text` | Funder Reports table (sourced from GrantReport #63 — SERVICE_PLACEHOLDER empty state if #63 not built; row: Report / Type / Due Date / Submitted / Status / Actions Create-or-View) |
| 4 | Documents | `ph:folder-open` | Document list (per GrantAttachment: file-type icon / name / upload-meta / download icon) + Upload Document button (SERVICE_PLACEHOLDER if no upload infra) |
| 5 | Timeline | `ph:clock-counter-clockwise` | Vertical timeline from GrantStageHistory rows + tranche disbursement entries — date / title / detail line. Filled dots for past, hollow dots for future/scheduled. |

**Tab 1 — Overview** content cards:

Card A: "Grant Information" (icon: `ph:file-text`)
- 2-col `info-grid`:
  - Left col: Title / Funder / Funder Contact (with email mailto link) / Grant Number
  - Right col: Amount (bold accent) / Currency / Start Date / End Date
- Below: Purpose row (full-width) / Branches row (full-width — managing + implementing concatenated)

Card B: "Objectives & Deliverables" (icon: `ph:target`)
- Table sourced from GrantMilestone: `#` / `Deliverable` / `Target` (TargetValue) / `Progress` (mini bar + "X (Y%)") / `Due Date` / `Status` (status-pill: On Track / At Risk / Not Started / Completed)
- Status colors: green / amber / slate / blue

**Tab 2 — Budget** content card:

Card: "Budget Breakdown" (icon: `ph:coins`)
- Table sourced from GrantBudgetLine: `Category` (bold) / `Budgeted` / `Spent` / `Remaining` (success) / `% Used` / `Progress` (color-graded bar)
- Footer: Total row
- Bottom: `+ Add Expense` button (primary, SERVICE_PLACEHOLDER → toast)
- Below: Burn-Down chart placeholder card (icon `ph:chart-line`, dashed border, "Visual showing planned vs actual spend over time" — NOT a real chart in V1 unless Recharts or similar already used elsewhere)

**Tab 3 — Reports** content card:

Card: "Funder Reports" (icon: `ph:file-text`)
- Table sourced from GrantReport (entity owned by #63):
  | Column | Notes |
  |--------|-------|
  | Report (bold) | Title |
  | Type | Quarterly / Annual / Audit |
  | Due Date | — |
  | Submitted | "—" if pending |
  | Status | status-pill: Due in X days (amber) / Accepted (green) / Late (red) |
  | Actions | "Create Report" primary button if pending → navigate `/crm/grant/grantreporting?mode=new&grantId={id}`; else "View" |
- If #63 not built: render empty state with message "Grant Reports module not yet enabled" + greyed-out create button.

**Tab 4 — Documents** content card:

Card: "Grant Documents" (icon: `ph:folder-open`)
- List of `<doc-item>` rows (sourced from GrantAttachment + future GrantReport attachments):
  - Icon (color by mime: pdf=red, excel=green, doc=blue, zip=slate)
  - Name (bold) + meta ("Uploaded {date} · {size}")
  - Right: download icon → fetch FileUrl
- Bottom: `+ Upload Document` button (SERVICE_PLACEHOLDER if no upload infra)

**Tab 5 — Timeline** content card:

Card: "Activity Timeline" (icon: `ph:clock-counter-clockwise`)
- Vertical timeline component (CSS pseudo-element line + dots) sourced from `GetGrantTimeline` query (aggregates GrantStageHistory rows):
  - Each row: date (small grey) / title (bold) / detail (grey 1-line)
  - Filled dot if past, hollow dot if scheduled/future
- Order: most recent first
- Examples from mockup:
  - "Grant approved" (Dec 15, 2024) — "Full amount $500,000 approved with 2 tranche disbursement"
  - "First tranche received — $300,000" (Jan 10, 2025) — "Transferred to Dubai operating account"
  - "Q4 2025 Progress Report submitted" (Jan 28, 2026) — "Accepted by funder on Jan 31, 2026" (sourced from GrantReport #63 — degrade gracefully if not built)

### Page Widgets & Summary Cards

**Widgets**: YES — 4 KPIs above grid (defined above in §⑥ Grid section).

**Grid Layout Variant**: `widgets-above-grid` → Variant B mandatory.

**Summary GQL Query**:
- Query name: `getGrantSummary`
- Returns: `GrantSummaryDto`
- Fields: `activeGrantsCount` (int), `activeGrantsFundedTotal` (decimal), `activeGrantsFundedTotalLabel` (string preformatted), `pipelineValue` (decimal), `pipelineValueLabel` (string), `pipelineApplicationsCount` (int), `upcomingDeadlinesCount` (int), `nextDeadlineLabel` (string e.g. "USAID report Apr 20"), `complianceRatePct` (int), `overdueReportsCount` (int)
- Added to `GrantQueries.cs` alongside `GetGrants` and `GetGrantById`

### Grid Aggregation Columns

**Aggregation Columns**:

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Progress (table view + kanban progress mini-bar) | (TotalSpent / AwardedAmount) × 100 — only when stage ≥ Active | Cached `Grant.TotalSpent` (updated by GrantExpense add/remove) | Compute in projection: `progressPct = (g.TotalSpent / Math.Max(1, g.AwardedAmount ?? g.RequestedAmount)) × 100` (return 0 if pre-Active). Renderer color-grades. |
| Days Remaining (Quick Stats #4 sub-text) | EndDate - today (in months for label, days under) | EndDate field | Compute in `GetGrantById` projection. |
| Days to Next Report Due (Quick Stats #5) | NextReportDueDate - today | NextReportDueDate field | Compute in projection; if < 30 days → warning color. |

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts, 7-stage workflow)

1. User lands on `/crm/grant/grantlist` → sees Variant B page: ScreenHeader + 4 KPIs + view-toggle + filter bar + Kanban Pipeline (default).
2. User clicks "+ New Grant Application" → URL: `?mode=new` → FORM LAYOUT (7 sections, sticky footer with Cancel/Draft/Submit).
3. User fills funder + grant details + budget + milestones → clicks **Save as Draft** → API creates Grant with stage=`Prospect` (or current stage value) → redirect to `?mode=read&id={newId}` → DETAIL LAYOUT.
4. Alternatively user clicks **Submit Application** → API validates required-on-submit fields (ExecutiveSummary required, BudgetLines sum check) → transitions Stage to `Application` → stamps `SubmittedDate` → appends GrantStageHistory row → redirect to `?mode=read&id={id}`.
5. From DETAIL → user clicks `Edit` → `?mode=edit&id={id}` → FORM pre-filled. Saves → returns to DETAIL.
6. From DETAIL → user clicks header workflow action (e.g., `Approve`) → modal asks for AwardedAmount + DecisionDate → calls `approveGrant` mutation → Stage transitions Approved → DETAIL refetches.
7. From DETAIL → user clicks `Add Report` → navigate to `/crm/grant/grantreporting?mode=new&grantId={id}` (#63 — SERVICE_PLACEHOLDER toast if not built).
8. From kanban → user clicks card → `?mode=read&id={id}` directly.
9. From table → user clicks Grant ID link or row → `?mode=read&id={id}`.
10. Back: clicks back arrow → `/crm/grant/grantlist` → grid restored at last filter/view.
11. Unsaved changes: dirty form + nav → confirmation dialog (precedent: standard FLOW behavior).

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: SavedFilter (FLOW base) + Case #50 (multi-child entity FLOW + new schema bootstrap precedent)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | Grant | Entity/class name |
| savedFilter | grant | Variable/field names |
| SavedFilterId | GrantId | PK field |
| SavedFilters | Grants | Table name (`grant."Grants"`), DbSet collection name |
| saved-filter | grant | FE folder/file kebab — but use `grant` (no kebab needed; single word) |
| savedfilter | grant | FE folder name (lowercase, no dash) |
| SAVEDFILTER | GRANT | Grid code, base menu code |
| notify | grant | DB schema name |
| Notify | Grant | Backend group base (Models/Schemas/Business folders → `GrantModels` / `GrantSchemas` / `GrantBusiness`) |
| NotifyModels | GrantModels | Namespace suffix for entities |
| NOTIFICATIONSETUP | CRM_GRANT | Parent menu code |
| NOTIFICATION | CRM | Module code (Grant lives under CRM, not its own module) |
| crm/communication/savedfilter | crm/grant/grantlist | FE route base (matches existing stub) |
| notify-service | grant-service | FE service folder name (`Pss2.0_Frontend/src/domain/entities/grant-service/`, `gql-queries/grant-queries/`, `gql-mutations/grant-mutations/`) — NEW folder set, first consumer |

**FE Folder Conventions** (exact, per case-service precedent):
- DTO group: `src/domain/entities/grant-service/` (NEW)
- GQL query group: `src/infrastructure/gql-queries/grant-queries/` (NEW)
- GQL mutation group: `src/infrastructure/gql-mutations/grant-mutations/` (NEW)
- Page-config group: `src/presentation/pages/crm/grant/` (EXISTS as `index.ts`)
- Page-components group: `src/presentation/components/page-components/crm/grant/grantlist/grant/` (NEW — mirrors Case `casemanagement/caselist/case/`)
- Route page: `src/app/[lang]/crm/grant/grantlist/page.tsx` (EXISTS as 5-line stub — OVERWRITE)

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### NEW MODULE BOOTSTRAP — `grant` schema (this screen owns it; first entity)

Per DEPENDENCY-ORDER.md § "For each new module…" — 7 setup files/wirings (precedent: Program #51 owns case schema; MembershipTier #58 owns mem schema).

| # | File | Path | Action |
|---|------|------|--------|
| B1 | IGrantDbContext interface | `Pss2.0_Backend/.../Base.Application/Data/Persistence/IGrantDbContext.cs` | CREATE — DbSet props for all 6 entities |
| B2 | GrantDbContext class | `Pss2.0_Backend/.../Base.Infrastructure/Data/Persistence/GrantDbContext.cs` | CREATE — `HasDefaultSchema("grant")` + `ApplyConfigurationsFromAssembly` filter to GrantConfigurations |
| B3 | GrantMappings | `Pss2.0_Backend/.../Base.Application/Mappings/GrantMappings.cs` | CREATE — Mapster `ConfigureMappings()` + `Register(TypeAdapterConfig)` for all DTO mappings |
| B4 | DecoratorGrantModules constants | append to `Pss2.0_Backend/.../Base.Application/Extensions/DecoratorProperties.cs` (after `DecoratorCaseModules` block, before `Permissions`) | MODIFY — add `public static class DecoratorGrantModules { public const string Grant = "GRANT", GrantBudgetLine = "GRANTBUDGETLINE", GrantMilestone = "GRANTMILESTONE", GrantImplementingBranch = "GRANTIMPLEMENTINGBRANCH", GrantAttachment = "GRANTATTACHMENT", GrantStageHistory = "GRANTSTAGEHISTORY" //DecoratorPropertiesGrantLines ; }` |
| B5 | IApplicationDbContext inheritance | `Pss2.0_Backend/.../Base.Application/Data/Persistence/IApplicationDbContext.cs` | MODIFY — add `: IGrantDbContext` to interface declaration list (precedent: existing `IApplicationDbContext : IContactDbContext, IDonationDbContext, ...`) |
| B6 | DependencyInjection register | `Pss2.0_Backend/.../Base.Infrastructure/DependencyInjection.cs` (or equivalent — check Case precedent for exact file) | MODIFY — register `services.AddScoped<IGrantDbContext>(provider => provider.GetRequiredService<GrantDbContext>())` and `services.AddDbContext<GrantDbContext>(...)` |
| B7 | GlobalUsings | `Pss2.0_Backend/.../Base.Domain/GlobalUsings.cs` + `Base.Application/GlobalUsings.cs` + `Base.Infrastructure/GlobalUsings.cs` | MODIFY — add `global using Base.Domain.Models.GrantModels;` (Domain), `global using Base.Application.Schemas.GrantSchemas;` + `global using Base.Application.Business.GrantBusiness.Grants.*;` (Application — multiple using lines per command/query namespace), `global using Base.Infrastructure.Data.Configurations.GrantConfigurations;` (Infrastructure) |

### Backend Files (4 entities + 6 EF configs + Schemas + 9 commands + 4 queries + 2 endpoint files = 26 files)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Grant entity | `Pss2.0_Backend/.../Base.Domain/Models/GrantModels/Grant.cs` | CREATE |
| 2 | GrantBudgetLine entity | `.../GrantModels/GrantBudgetLine.cs` | CREATE |
| 3 | GrantMilestone entity | `.../GrantModels/GrantMilestone.cs` | CREATE |
| 4 | GrantImplementingBranch entity | `.../GrantModels/GrantImplementingBranch.cs` | CREATE |
| 5 | GrantAttachment entity | `.../GrantModels/GrantAttachment.cs` | CREATE |
| 6 | GrantStageHistory entity | `.../GrantModels/GrantStageHistory.cs` | CREATE |
| 7 | GrantConfiguration | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/GrantConfigurations/GrantConfiguration.cs` | CREATE — composite filtered unique index on `(CompanyId, GrantCode)`; FK indices |
| 8 | GrantBudgetLineConfiguration | `.../GrantConfigurations/GrantBudgetLineConfiguration.cs` | CREATE |
| 9 | GrantMilestoneConfiguration | `.../GrantConfigurations/GrantMilestoneConfiguration.cs` | CREATE |
| 10 | GrantImplementingBranchConfiguration | `.../GrantConfigurations/GrantImplementingBranchConfiguration.cs` | CREATE — composite unique on `(GrantId, BranchId)` |
| 11 | GrantAttachmentConfiguration | `.../GrantConfigurations/GrantAttachmentConfiguration.cs` | CREATE |
| 12 | GrantStageHistoryConfiguration | `.../GrantConfigurations/GrantStageHistoryConfiguration.cs` | CREATE |
| 13 | GrantSchemas (DTOs) | `Pss2.0_Backend/.../Base.Application/Schemas/GrantSchemas/GrantSchemas.cs` | CREATE — `GrantRequestDto`, `GrantResponseDto` (with `funderContactName`, `branchName`, `currencyCode`, `stageCode`, `stageName`, `stageColorHex`, `progressPct`, computed labels), `GrantSummaryDto`, `GrantBudgetLineRequestDto/ResponseDto`, `GrantMilestoneRequestDto/ResponseDto`, `GrantImplementingBranchRequestDto/ResponseDto`, `GrantAttachmentRequestDto/ResponseDto`, `GrantStageHistoryRequestDto/ResponseDto`, `GrantTimelineEntryDto` (timeline tab projection) |
| 14 | CreateGrant command | `Pss2.0_Backend/.../Base.Application/Business/GrantBusiness/Grants/CreateCommand/CreateGrant.cs` | CREATE — atomic create with all 5 child collections; auto-generate GrantCode if empty; append initial GrantStageHistory row |
| 15 | UpdateGrant command | `.../Grants/UpdateCommand/UpdateGrant.cs` | CREATE — diff-persists children (precedent: Contact #18 / Case #50). Stage-aware required-field validation (e.g., AwardedAmount required if Stage=Approved/Active). |
| 16 | DeleteGrant command | `.../Grants/DeleteCommand/DeleteGrant.cs` | CREATE — soft delete cascade to children |
| 17 | ToggleGrant command | `.../Grants/ToggleCommand/ToggleGrant.cs` | CREATE |
| 18 | UpdateGrantStage command (umbrella) | `.../Grants/UpdateCommand/UpdateGrantStage.cs` | CREATE — handles arbitrary stage transitions with side-effect rules (stamps dates, validates required fields per target stage, appends GrantStageHistory) |
| 19 | SubmitGrantApplication command | `.../Grants/UpdateCommand/SubmitGrantApplication.cs` | CREATE — Stage → Application; stamp SubmittedDate; validate ExecutiveSummary + budget |
| 20 | ApproveGrant command | `.../Grants/UpdateCommand/ApproveGrant.cs` | CREATE — Stage → Approved; require AwardedAmount + DecisionDate; append history |
| 21 | RejectGrant command | `.../Grants/UpdateCommand/RejectGrant.cs` | CREATE — Stage → Rejected; require RejectionReason; stamp DecisionDate |
| 22 | ActivateGrant command | `.../Grants/UpdateCommand/ActivateGrant.cs` | CREATE — Stage → Active; require FunderGrantNumber + StartDate + EndDate |
| 23 | RecordGrantTranche command | `.../Grants/UpdateCommand/RecordGrantTranche.cs` | CREATE — append GrantStageHistory row with AmountReceived (no stage change) |
| 24 | GetGrants (GetAll) query | `.../Grants/GetAllQuery/GetGrants.cs` | CREATE — paged + filters (stageCode, funderContactId, branchId, amountRangeCode, searchText, dateFrom, dateTo, isActive); projects all FK display fields + computed `progressPct`, `deadlineLabel`, `amountLabel` |
| 25 | GetGrantById query | `.../Grants/GetByIdQuery/GetGrantById.cs` | CREATE — full graph with all 5 child collections + projections (Quick Stats: `daysRemaining`, `monthsRemaining`, `daysToNextReport`); use `.Include(...).ThenInclude(...)` for nested |
| 26 | GetGrantSummary query | `.../Grants/GetByIdQuery/GetGrantSummary.cs` | CREATE — KPI projection (4 widgets, scoped to current Company) |
| 27 | GetGrantTimeline query | `.../Grants/GetAllQuery/GetGrantTimeline.cs` | CREATE — by GrantId; aggregates GrantStageHistory rows + (if #63 built) GrantReport submitted/accepted events; returns ordered `GrantTimelineEntryDto[]` |
| 28 | GrantMutations | `Pss2.0_Backend/.../Base.API/EndPoints/Grant/Mutations/GrantMutations.cs` | CREATE — 9 mutations (Create / Update / Delete / Toggle / UpdateStage / Submit / Approve / Reject / Activate / RecordTranche). Plus stub mutations for: `closeGrant`, `putGrantOnHold`, `cancelGrant`, `moveGrantToReporting` (delegate to `UpdateGrantStage` with target stage). |
| 29 | GrantQueries | `.../Grant/Queries/GrantQueries.cs` | CREATE — 4 queries (GetGrants / GetGrantById / GetGrantSummary / GetGrantTimeline) |

**Note**: `Base.API/EndPoints/Grant/` directory is NEW — must be created as part of this build (precedent: `Base.API/EndPoints/Case/` was created when Program #51 / Beneficiary #49 were built).

### Backend Wiring Updates (beyond bootstrap)

| # | File | What to Add |
|---|------|-------------|
| 1 | IGrantDbContext.cs | DbSet properties for all 6 entities |
| 2 | GrantDbContext.cs | DbSet properties + `HasDefaultSchema("grant")` + `modelBuilder.ApplyConfigurationsFromAssembly(typeof(GrantConfiguration).Assembly, t => t.Namespace?.Contains("GrantConfigurations") == true)` |
| 3 | GrantMappings.cs | Mapster mapping configs |
| 4 | DecoratorGrantModules (in DecoratorProperties.cs) | 6 constants |
| 5 | IApplicationDbContext.cs | Add `: IGrantDbContext` to interface inheritance |
| 6 | DependencyInjection.cs (Infrastructure) | Register GrantDbContext + IGrantDbContext scope |
| 7 | GlobalUsings (Domain/Application/Infrastructure) | Add `global using Base.Domain.Models.GrantModels;` etc. |

### Frontend Files (22 files — FLOW with kanban dual-view + 5-tab DETAIL + 6 sub-components)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/grant-service/GrantDto.ts` | CREATE — all 6 entity DTOs + SummaryDto + TimelineEntryDto |
| 2 | grant-service barrel | `src/domain/entities/grant-service/index.ts` | CREATE |
| 3 | GQL Query | `src/infrastructure/gql-queries/grant-queries/GrantQuery.ts` | CREATE — `GET_GRANTS_QUERY`, `GET_GRANT_BY_ID_QUERY`, `GET_GRANT_SUMMARY_QUERY`, `GET_GRANT_TIMELINE_QUERY` |
| 4 | grant-queries barrel | `src/infrastructure/gql-queries/grant-queries/index.ts` | CREATE |
| 5 | GQL Mutation | `src/infrastructure/gql-mutations/grant-mutations/GrantMutation.ts` | CREATE — Create/Update/Delete/Toggle/UpdateStage/Submit/Approve/Reject/Activate/RecordTranche mutations |
| 6 | grant-mutations barrel | `src/infrastructure/gql-mutations/grant-mutations/index.ts` | CREATE |
| 7 | Page Config | `src/presentation/pages/crm/grant/grantlist.tsx` | CREATE — page-level config + gridCode + actions registry. Append export to `pages/crm/grant/index.ts`. |
| 8 | Index Router | `src/presentation/components/page-components/crm/grant/grantlist/grant/index.tsx` | CREATE — URL mode dispatcher (new/edit/read → view-page; else index-page) |
| 9 | Index Page | `.../crm/grant/grantlist/grant/index-page.tsx` | CREATE — Variant B: ScreenHeader + 4 KPI widgets + view-toggle (Pipeline ↔ Table) + filter bar + EITHER `<GrantKanbanBoard>` OR `<DataTableContainer showHeader={false}>` |
| 10 | View Page (3 modes) | `.../crm/grant/grantlist/grant/view-page.tsx` | CREATE — FORM layout for new/edit; DETAIL layout for read (renders `<GrantForm>` or `<GrantDetail>` based on mode) |
| 11 | Zustand Store | `.../crm/grant/grantlist/grant/grant-store.ts` | CREATE — `viewMode` (kanban\|table), `stageFilter`, `funderFilter`, `amountRangeFilter`, `branchFilter`, `searchText`, `activeDetailTab`, advanced filter state |
| 12 | Sub-component: Form | `.../crm/grant/grantlist/grant/grant-form.tsx` | CREATE — 7 sections + RHF + nested child grids (BudgetLines, Milestones, Attachments) + sticky footer |
| 13 | Sub-component: Budget Lines Inline Grid | `.../crm/grant/grantlist/grant/budget-lines-grid.tsx` | CREATE — RHF useFieldArray + auto-total + admin-warning |
| 14 | Sub-component: Milestones Inline Grid | `.../crm/grant/grantlist/grant/milestones-grid.tsx` | CREATE — RHF useFieldArray |
| 15 | Sub-component: Attachment Checklist | `.../crm/grant/grantlist/grant/attachment-checklist.tsx` | CREATE — 5 required-doc rows + Custom rows; SERVICE_PLACEHOLDER upload handler |
| 16 | Sub-component: Detail Page | `.../crm/grant/grantlist/grant/grant-detail.tsx` | CREATE — header + 5 Quick Stats + 5 tabs (Overview / Budget / Reports / Documents / Timeline) |
| 17 | Sub-component: Kanban Board | `.../crm/grant/grantlist/grant/grant-kanban-board.tsx` | CREATE — 7 stage columns + KanbanCard per row + click-to-detail |
| 18 | Sub-component: Widgets | `.../crm/grant/grantlist/grant/grant-widgets.tsx` | CREATE — 4 KPI cards consuming `getGrantSummary` |
| 19 | Sub-component: Filter Bar | `.../crm/grant/grantlist/grant/grant-filter-bar.tsx` | CREATE — 4 selects + search input |
| 20 | Sub-component: Workflow Action Modals | `.../crm/grant/grantlist/grant/workflow-modals.tsx` | CREATE — Approve modal (AwardedAmount + DecisionDate), Reject modal (RejectionReason), Activate modal (FunderGrantNumber + StartDate + EndDate), Record Tranche modal (Amount + Notes), Close modal (confirm) |
| 21 | Custom Cell Renderers (2 NEW) | `Pss2.0_Frontend/src/presentation/components/data-table/components/shared-cell-renderers/grant-stage-badge.tsx` and `.../grant-progress-bar.tsx` | CREATE — register in 3 column-type registries (advanced/basic/flow) + shared-cell-renderers barrel |
| 22 | Route Page (OVERWRITE stub) | `Pss2.0_Frontend/src/app/[lang]/crm/grant/grantlist/page.tsx` | OVERWRITE — replace 5-line "Need to Develop" stub with `ClientPageWrapper` + `<Index />` from page-components |

### Frontend Wiring Updates

| # | File | What to Add |
|---|------|-------------|
| 1 | entity-operations.ts | `GRANT` operations config block (READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT) |
| 2 | operations-config.ts | Import + register `grantOperations` |
| 3 | sidebar menu config (likely in page-components shell or generated from menus query) | Menu entry "All Grants" under CRM_GRANT parent (auto-rendered if menu rows are seeded — verify) |
| 4 | route registry (if separate from app-router file system) | Route definition for `/[lang]/crm/grant/grantlist` (existing path — no new route, just verify enabled) |
| 5 | advanced-column-types.ts | Register `grant-stage-badge` + `grant-progress-bar` |
| 6 | basic-column-types.ts | Register both renderers |
| 7 | flow-column-types.ts | Register both renderers |
| 8 | shared-cell-renderers barrel | Export both renderers |
| 9 | grant-service group | NEW folder set across DTOs/queries/mutations + barrel exports |
| 10 | service entity-operations registry | Add `GRANT` block to whichever file maps grid-codes → operations (precedent: Case had `case-service` registration in `contact-service-entity-operations` — verify or create `grant-service-entity-operations.ts`) |

### DB Seed (1 SQL file, idempotent)

Path: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Grant-sqlscripts.sql` (preserve `dyanmic` typo — precedent: ChequeDonation #6, Pledge #12, Refund #13, Beneficiary #49)

Idempotent steps:
1. Insert `GRANTLIST` menu under `CRM_GRANT` parent (MenuId 275) at OrderBy=1, MenuUrl `crm/grant/grantlist`, `IsLeastMenu=1`, `IsMenuRender=1`. (Mockup precedent: GRANTLIST already in MODULE_MENU_REFERENCE.md so this may already exist — check & UPSERT.)
2. Insert `GRANTFORM` hidden child menu under CRM_GRANT (`IsMenuRender=0` — FLOW uses single page).
3. MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER on GRANTLIST.
4. RoleCapabilities: BUSINESSADMIN gets READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT on GRANTLIST.
5. `sett.Grids` row: `GridCode='GRANT'`, `GridType='FLOW'`, `GridFormSchema=NULL` (FLOW does NOT generate form schema).
6. `sett.Fields` rows for grid columns (GrantId / GrantCode / FunderContactName / GrantTitle / Amount / Deadline / Stage / Progress / Branch).
7. `sett.GridFields` link rows (column display order, widths, sortable flags).
8. **8 MasterDataTypes** (with idempotent INSERT … WHERE NOT EXISTS):
   - `GRANTSTAGE` × 7 values: Prospect / Application / UnderReview / Approved / Active / Reporting / Closed (+ Rejected + OnHold + Cancelled = 10 total). With `colorHex` JSON: indigo/violet/amber/green/grants-blue/rose/slate/red/orange/grey.
   - `GRANTTYPE` × 5 values: Project / OperatingGeneral / Capital / Research / Emergency.
   - `GRANTPRIORITY` × 4 values: Low / Medium / High / Critical (with colorHex).
   - `GRANTPURPOSE` × 7 values: CleanWater / Education / Healthcare / OrphanCare / FoodSecurity / WomenEmpowerment / CommunityDevelopment.
   - `GRANTREPORTINGFREQ` × 4 values: Monthly / Quarterly / SemiAnnual / Annual.
9. **No sample Grants seeded** — UI-driven organic testing (precedent: Auction #48).

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: All Grants
MenuCode: GRANTLIST
ParentMenu: CRM_GRANT
Module: CRM
MenuUrl: crm/grant/grantlist
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: GRANT

HiddenChildMenus:
  - MenuCode: GRANTFORM, ParentMenu: CRM_GRANT, IsMenuRender: 0  (FLOW uses single page; GRANTFORM is the form route hidden from sidebar)
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `GrantQueries` (registered as `[ExtendObjectType(OperationTypeNames.Query)]`)
- Mutation type: `GrantMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getGrants` | `PaginatedApiResponse<IEnumerable<GrantResponseDto>>` | `searchText, pageNo, pageSize, sortField, sortDir, isActive, dateFrom, dateTo, stageCode, funderContactId, branchId, amountRangeCode, advancedFilter` |
| `getGrantById` | `ApiResponse<GrantResponseDto>` | `grantId` |
| `getGrantSummary` | `ApiResponse<GrantSummaryDto>` | (none — scoped to Company from HttpContext) |
| `getGrantTimeline` | `ApiResponse<List<GrantTimelineEntryDto>>` | `grantId` |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createGrant` | `GrantRequestDto` | `int` (new GrantId) |
| `updateGrant` | `GrantRequestDto` | `int` |
| `deleteGrant` | `int grantId` | `int` |
| `toggleGrant` | `int grantId` | `int` |
| `updateGrantStage` | `int grantId, int targetStageId, string? notes` | `int` |
| `submitGrantApplication` | `int grantId` | `int` |
| `approveGrant` | `int grantId, decimal awardedAmount, DateTime decisionDate, string? notes` | `int` |
| `rejectGrant` | `int grantId, string rejectionReason, DateTime decisionDate` | `int` |
| `activateGrant` | `int grantId, string funderGrantNumber, DateTime startDate, DateTime endDate` | `int` |
| `recordGrantTranche` | `int grantId, decimal amountReceived, DateTime receivedDate, string? notes` | `int` |

**Response DTO Fields** (`GrantResponseDto`):
| Field | Type | Notes |
|-------|------|-------|
| grantId | number | PK |
| grantCode | string | "GRT-012" |
| grantTitle | string | — |
| funderContactId | number | FK |
| funderContactName | string | FK display |
| grantProgram | string | — |
| funderContactPersonName / Email / Phone / Website | string | — |
| funderGrantNumber | string | — |
| requestedAmount | number | — |
| awardedAmount | number? | nullable |
| amountLabel | string | preformatted "$500,000" (server-side) |
| currencyId | number | FK |
| currencyCode | string | "USD" |
| grantTypeId | number | FK |
| grantTypeName | string | — |
| startDate / endDate / submissionDeadline / submittedDate / decisionDate / nextReportDueDate | string (ISO date) | — |
| purposeProgramId | number? | FK |
| purposeProgramName | string | — |
| branchId | number | FK |
| branchName | string | — |
| implementingBranches | `[GrantImplementingBranchDto]` | nested |
| stageId | number | FK |
| stageCode | string | "ACTIVE" |
| stageName | string | "Active" |
| stageColorHex | string | "#0369a1" |
| priorityId | number? | FK |
| priorityName | string | — |
| assignedStaffId | number? | FK |
| assignedStaffName | string | — |
| reportingFrequencyId / financialReportingFrequencyId | number? | FK |
| reportingFrequencyName / financialReportingFrequencyName | string | — |
| auditRequired | boolean | — |
| executiveSummary / problemStatement / proposedSolution / expectedOutcomes / sustainabilityPlan / internalNotes | string | — |
| totalSpent | number | cached |
| progressPct | number | computed (TotalSpent / Awarded) × 100 |
| deadlineLabel | string | computed display |
| daysRemaining / monthsRemaining / daysToNextReport | number? | computed for Quick Stats |
| complianceRatePct | number? | cached |
| budgetLines | `[GrantBudgetLineResponseDto]` | nested |
| milestones | `[GrantMilestoneResponseDto]` | nested |
| attachments | `[GrantAttachmentResponseDto]` | nested |
| stageHistory | `[GrantStageHistoryResponseDto]` | nested |
| isActive | boolean | inherited |
| createdDate / modifiedDate | string (ISO) | inherited (NOT createdAt/modifiedAt — see verify-properties memory) |

**`GrantSummaryDto`**:
| Field | Type |
|-------|------|
| activeGrantsCount | int |
| activeGrantsFundedTotal | decimal |
| activeGrantsFundedTotalLabel | string |
| pipelineValue | decimal |
| pipelineValueLabel | string |
| pipelineApplicationsCount | int |
| upcomingDeadlinesCount | int |
| nextDeadlineLabel | string |
| complianceRatePct | int |
| overdueReportsCount | int |

**`GrantTimelineEntryDto`**:
| Field | Type | Notes |
|-------|------|-------|
| date | string (ISO date) | — |
| title | string | "Grant approved" |
| detail | string | "Full amount $500,000 approved with 2 tranche disbursement" |
| iconCode | string | `ph:check-circle` / `ph:upload` / `ph:flag` etc. |
| amountReceived | decimal? | for tranche entries |
| isPast | boolean | filled-dot vs hollow-dot |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors. New `grant` schema migration applies cleanly. 6 tables + FKs + composite filtered indices created.
- [ ] `pnpm dev` — page loads at `/[lang]/crm/grant/grantlist`. No console errors.

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Variant B verified — ScreenHeader + 4 widgets + showHeader=false data table (no double header)
- [ ] 4 KPI widgets render with values from `getGrantSummary`
- [ ] View toggle switches between Kanban Pipeline (default) and Table — both share data + filters
- [ ] Kanban Pipeline: 7 columns, color-coded headers, count chips, KanbanCards with funder/amount/deadline/progress; click card → DETAIL
- [ ] Table view: 9 columns including new `grant-stage-badge` and `grant-progress-bar` renderers
- [ ] Filter bar: Stage / Funder / Amount Range / Branch — each filters both views
- [ ] Search filters by: grantCode, grantTitle, funderContactName
- [ ] `?mode=new`: empty FORM renders all 7 sections; sticky footer with Cancel / Save as Draft / Submit Application
- [ ] FK dropdowns load: contacts (funder), branches, currencies, masterDataListByTypeCode for GRANTTYPE/GRANTPURPOSE/GRANTSTAGE/GRANTPRIORITY/GRANTREPORTINGFREQ, staffs
- [ ] Multi-select Implementing Branches works (chip display + persistence via junction)
- [ ] Budget child grid: add row, remove row, auto-total, admin-warning banner (5/10% threshold logic)
- [ ] Milestone child grid: add row, remove row, month-pickers
- [ ] Attachment checklist: 5 required rows render with status; Upload buttons trigger SERVICE_PLACEHOLDER toast (or actual upload if infra exists); custom Add Document row works
- [ ] Save as Draft creates record with current Stage → URL → `?mode=read&id={newId}`
- [ ] Submit Application validates required-on-submit fields → transitions Stage to Application → stamps SubmittedDate → appends GrantStageHistory row
- [ ] `?mode=read&id=X`: DETAIL renders header chip+title+subtitle, 5 Quick Stats cards, 5 tabs
- [ ] Tab 1 Overview: Grant Information info-grid + Objectives & Deliverables table from milestones
- [ ] Tab 2 Budget: Breakdown table with progress bars, totals, Add Expense button (SERVICE_PLACEHOLDER), Burn-Down chart placeholder
- [ ] Tab 3 Reports: Funder Reports table (or empty state if #63 not built); Create Report button SERVICE_PLACEHOLDER
- [ ] Tab 4 Documents: Document list from attachments + Upload Document button SERVICE_PLACEHOLDER
- [ ] Tab 5 Timeline: vertical timeline from `getGrantTimeline` with stage history + tranche entries
- [ ] Header workflow actions modals: Approve (AwardedAmount + DecisionDate) / Reject (RejectionReason) / Activate (FunderGrantNumber + StartDate + EndDate) / Record Tranche (Amount + Notes) / Close → all transitions persist + timeline updates
- [ ] Edit button on detail → `?mode=edit&id=X` → FORM pre-filled (including all child collections + multi-branches + attachments)
- [ ] Save in edit mode updates record + diff-persists children → returns to DETAIL
- [ ] Add Report button on header → routes to `/crm/grant/grantreporting?mode=new&grantId={id}` (or SERVICE_PLACEHOLDER toast)
- [ ] Per-row stage-aware kebab actions in table view work (View / Edit / Submit / Approve / Reject / Activate / Close / Delete)
- [ ] 5 UI uniformity greps zero matches (no hex, no px, Phosphor icons only, shaped Skeletons, empty/error states)
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] Permissions: Edit/Delete/workflow buttons respect BUSINESSADMIN role capabilities

**DB Seed Verification:**
- [ ] Menu "All Grants" appears in sidebar under "Grants" (CRM_GRANT)
- [ ] Grid columns render correctly per `sett.Grids` + `sett.GridFields`
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)
- [ ] All 8 MasterDataTypes seeded (verify ApiSelect dropdowns populate)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** — comes from HttpContext on mutations
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout, read has DETAIL layout with 5 tabs (completely different UI)
- **DETAIL is a separate UI**, not the form disabled — DO NOT wrap form in fieldset
- **THIS IS THE FIRST ENTITY IN THE `grant` SCHEMA** — build-screen MUST execute new-module bootstrap per DEPENDENCY-ORDER.md § "For each new module…" (IGrantDbContext + GrantDbContext + GrantMappings + IApplicationDbContext inheritance + DependencyInjection register + DecoratorGrantModules + GlobalUsing × 3). Precedent: Program #51 (case schema), MembershipTier #58 (mem schema), Beneficiary #49 (added entities to existing case schema).
- **Existing FE route stub** at `[lang]/crm/grant/grantlist/page.tsx` (5 lines `<div>Need to Develop</div>`) — OVERWRITE with real wrapper
- **Existing route folders**: `crm/grant/grantcalendar`, `crm/grant/grantform`, `crm/grant/grantreporting` already have stubs — leave them alone (covered by registry #63 + #64)
- **Hidden legacy menu**: `GRANTFORM` (per MODULE_MENU_REFERENCE.md line 171) — set `IsMenuRender=0` since FLOW uses single page (precedent: Beneficiary #49)
- **FK target groups**: Contact → `ContactModels` (schema `cont`); Staff/Branch → `ApplicationModels` (schema `app`); MasterData → `SettingModels` (schema `sett`); Currency → `SharedModels` (schema `shared`)
- **Filter implementation**: pass chip filter (Stage) as TOP-LEVEL GQL arg `stageCode`, NOT via `advancedFilter` payload — precedent: Family #20 ISSUE-13, Beneficiary #49
- **FE folder name**: `grantlist` (matches existing stub + MenuUrl + MODULE_MENU_REFERENCE.md convention), and entity sub-folder `grant/` inside it (mirrors Case `casemanagement/caselist/case/`)
- **Seed folder typo preservation**: `sql-scripts-dyanmic/` (typo — NOT `dynamic`). Precedent: ChequeDonation #6, Pledge #12, Refund #13, Beneficiary #49
- **Variant B MANDATORY** (mockup shows widgets above grid) — ScreenHeader + widgets + DataTableContainer showHeader=false (or kanban toggle). Precedent: ContactType #19 session-2 fix, DonationInKind #7
- **Stage badge color-by-value**: MasterData `GRANTSTAGE` carries `colorHex` (per-row) — `grant-stage-badge` renderer reads hex and applies inline style rather than CSS class (policy exception, colors ARE data; precedent: Beneficiary #49 program-badge, Tag #22 ISSUE-5, DonationCategory #3)
- **UI uniformity**: use `ph:*` (Phosphor) icon set per UI uniformity memory, NOT `fa-*`. Convert mockup `fa-*` to `ph:*` equivalents in implementation (precedent: Pledge #12 ISSUE-8). Mapping reference:
  - `fa-file-contract` → `ph:file-text`
  - `fa-file-circle-plus` → `ph:file-plus`
  - `fa-building-columns` → `ph:building-bank`
  - `fa-pen-fancy` → `ph:pen-nib`
  - `fa-coins` → `ph:coins`
  - `fa-flag-checkered` → `ph:flag-checkered`
  - `fa-paperclip` → `ph:paperclip`
  - `fa-lock` → `ph:lock`
  - `fa-columns` → `ph:columns`
  - `fa-table` → `ph:table`
  - `fa-info-circle` → `ph:info`
  - `fa-folder-open` → `ph:folder-open`
  - `fa-clock-rotate-left` → `ph:clock-counter-clockwise`
  - `fa-bullseye` → `ph:target`
  - `fa-chart-area` → `ph:chart-line`
- **Component reuse-or-create policy**: FE Dev MUST search registries before creating: rich-text editor (search for `RichText` / `Quill` / `react-quill`), multi-select chip ApiSelect (search for `isMulti` on ApiSelectV2 or `MultiApiSelect`), file upload widget (search for `Uploader` / `FileUpload`), kanban board (likely missing — escalate per MASTER_GRID + FLOW only directive). Reuse if found; create if missing-and-static; ESCALATE if missing-and-complex (kanban qualifies — but it's listed as in-scope; build a simple 7-column flex layout with KanbanCard child).
- **GraphQL field naming**: agent must read backend Schemas before writing GQL queries — never assume `funderName` vs `funderContactName` etc. (verify-properties memory). DTO uses camelCase → exposed by HotChocolate as camelCase fields.
- **ALIGN vs FULL**: This is FULL — no existing BE code to align against; only a 5-line FE stub. Build from scratch using SavedFilter + Case #50 + Beneficiary #49 patterns.
- **Inline rich-text fallback**: if no rich-text editor exists in FE registry, render the 4 narrative fields as plain `<textarea rows=6>` and store as plain text. Flag SERVICE_PLACEHOLDER. The toolbar UI from the mockup is NOT required in V1.

### Known Issues (pre-flagged by /plan-screens)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | **HIGH** | BE (cross-screen dependency) | DETAIL Tab 2 (Budget) and Tab 3 (Reports) reference **GrantExpense** + **GrantReport** entities that belong to **GrantReport #63** (separate registry). #63 is also `PARTIAL` (FE stub only, no BE). Resolution: render Budget tab using only `GrantBudgetLine.SpentAmount` (cached on the line — initialized to 0; remains 0 until #63 wires expense logging). Render Reports tab with empty-state "Grant Reports module not yet enabled" + greyed-out Create Report button. `Add Expense` and `Add Report` header actions become SERVICE_PLACEHOLDER toasts. Burn-Down chart is a placeholder card (no real chart). When #63 is built, Reports tab and Budget Spent column light up automatically (no schema change to Grant). | OPEN |
| ISSUE-2 | **HIGH** | FE/BE (file uploads) | File upload infrastructure check required — Contact #18, Pledge #12, Beneficiary #49 ISSUE-4 use URL-string fallback. Verify whether multipart/form-data pipeline + CDN/S3 storage exists. If absent → SERVICE_PLACEHOLDER handler shows toast "Upload coming soon" + accepts URL input as fallback for the 5 required-doc rows + custom Add Document. Persist `FileUrl` only; leave `FileSizeBytes` and `MimeType` null. Document download similarly degrades to URL navigation. | OPEN |
| ISSUE-3 | MED | FE (rich-text editor) | 4 narrative fields (ProblemStatement / ProposedSolution / ExpectedOutcomes / SustainabilityPlan) need a WYSIWYG editor. Check FE registry for existing `<RichTextEditor>` / `react-quill` / `tiptap`. If missing: SERVICE_PLACEHOLDER → render as plain textarea (rows=6); persist as plain text; flag for follow-up to add Quill or Tiptap as a Wave 4 task. The toolbar buttons in the mockup are NOT required in V1. | OPEN |
| ISSUE-4 | MED | FE (kanban dual-view) | Kanban Pipeline is the default view — NOT a standard FE pattern in this codebase (no precedent). Implementation: build a simple flex layout with 7 column divs + KanbanCard child component. NO drag-drop in V1 (cards are click-to-detail only). Stage transitions happen via DETAIL header actions, not by dragging cards. Flag for V2 follow-up to add `react-dnd` or similar. | OPEN |
| ISSUE-5 | MED | BE (status code consistency) | `GRANTSTAGE` MasterData DataValue codes (`PROSPECT`, `APPLICATION`, `UNDERREVIEW`, `APPROVED`, `ACTIVE`, `REPORTING`, `CLOSED`, `REJECTED`, `ONHOLD`, `CANCELLED`) MUST match the constants used in the workflow command guards. Build a `GrantStageHelper` static class (precedent: AuctionStatusHelper from Auction #48) with `MasterDataResolver(typeCode, dataValue)` method + hard-coded `const string PROSPECT = "PROSPECT"` etc. so commands and seed stay in sync. | OPEN |
| ISSUE-6 | MED | BE (computed fields refresh) | `Grant.TotalSpent` and `Grant.ComplianceRatePct` are CACHED columns. They become stale if expenses are added/removed (when #63 wires expense logging). MVP: Update them transactionally inside `CreateGrantExpense` / `DeleteGrantExpense` commands when #63 is built. Until then, they remain 0 / NULL — which is correct for non-Active grants. Tab 2 Budget shows "Spent: $0" for all grants in V1, which matches the empty Reports tab. | OPEN |
| ISSUE-7 | MED | BE (auto-generate GrantCode) | `GrantCode = "GRT-{NextNumber:D3}"` per Company. Use a `GrantCodeGenerator` helper that scans `MAX(SUBSTRING(GrantCode, 5))` cast-to-int for current Company and increments. Race condition possible under high concurrency — wrap in transaction with `SERIALIZABLE` isolation OR use a per-Company sequence table. MVP: simple MAX+1 query inside `CreateGrant` command; flag for hardening if write contention emerges (precedent: Case #50 CaseCode generator). | OPEN |
| ISSUE-8 | MED | FE (multi-select Implementing Branches) | `<ApiSelectV2 isMulti />` may not exist in the FE component library. Check before assuming. If missing: build a static `<MultiSelectChips>` composite using `<ApiSelectV2>` + manual array state + chip display below. Persist as `int[] implementingBranchIds` in form state, hydrate from `implementingBranches[].branchId` on edit, materialize as junction rows on Save. | OPEN |
| ISSUE-9 | MED | FE (export Excel/PDF) | Export dropdown shows CSV / Excel / PDF. CSV is likely supported via existing FE export utility — wire it. Excel + PDF are SERVICE_PLACEHOLDERs (no infra). Show toast "Excel/PDF export coming soon" on those entries. | OPEN |
| ISSUE-10 | MED | FE (filter "Amount Range") | The Amount Range select is a hard-coded enum (`<50K`, `50K-100K`, etc.). Backend handler must parse this code into min/max bounds inside `GetGrants` query (e.g., `case "<50K": amountFrom=0, amountTo=50000`). Document the codes as constants on both BE and FE so they stay in sync. | OPEN |
| ISSUE-11 | LOW | BE (NextReportDueDate auto-compute) | `NextReportDueDate` should be auto-derived from the next pending GrantReport (when #63 exists) or from milestones. MVP: store as nullable manual field; when #63 is built, expose a `recomputeNextReportDueDate(grantId)` mutation that walks reports + milestones and updates the cached column. | OPEN |
| ISSUE-12 | LOW | FE (Quick Stats #5 warning color) | "Next Report Due" Quick Stat turns warning-color (amber) when daysToNextReport < 30 and danger-color (red) when < 7 OR overdue. Implement via conditional class in `<GrantQuickStats>`. | OPEN |
| ISSUE-13 | LOW | FE (Add New Funder link) | Form Section 1 has "+ Add New Funder" link below FunderContactId select. V1: navigate to `/crm/contact/allcontacts?mode=new&type=organization` (Contact #18 partially-completed — verify route is reachable). If Contact form is not navigable yet, render link as disabled with tooltip "Use Contacts module". | OPEN |
| ISSUE-14 | LOW | FE (currency formatting) | Amount fields should format with thousand-separators on blur and parse-friendly on focus (precedent: Pledge #12, Donation #1). Reuse `<CurrencyInput>` if present in the FE registry. | OPEN |
| ISSUE-15 | LOW | DB | Seed folder typo: `sql-scripts-dyanmic/` (NOT `sql-scripts-dynamic`) — preserve to match precedent. | PRESERVE |
| ISSUE-16 | LOW | BE | `GrantBudgetLine.IsAdminCategory` defaults false. V1 detection: case-insensitive name match on "Admin" / "Administration" / "Overhead". Future: explicit checkbox in form row (skipped for V1 to keep mockup fidelity). | OPEN |

### Service Dependencies (UI-only — no backend service implementation)

> Everything shown in the mockup IS in scope unless listed below. List items here ONLY if they require an external service or infrastructure that doesn't exist in the codebase yet.

- **⚠ SERVICE_PLACEHOLDER: 'Upload Document' / 'Upload' attachment buttons** — full UI implemented (button, file picker dialog UI). Handler shows toast "Upload coming soon" and accepts a URL paste as fallback. Real multipart/CDN upload deferred (ISSUE-2).
- **⚠ SERVICE_PLACEHOLDER: 'Add Expense' button on DETAIL header + Tab 2 Budget** — full button UI. Handler shows toast "Expense logging will be enabled when Grant Reports module (#63) is wired." (ISSUE-1)
- **⚠ SERVICE_PLACEHOLDER: 'Add Report' button on DETAIL header + Tab 3 Reports "Create Report"** — full button UI. Handler navigates to `/crm/grant/grantreporting?mode=new&grantId={id}` if #63 route is set up; else toast "Grant Reports coming soon". (ISSUE-1)
- **⚠ SERVICE_PLACEHOLDER: Excel + PDF export** in header dropdown. CSV export wired via existing utility. (ISSUE-9)
- **⚠ SERVICE_PLACEHOLDER: Burn-Down chart** on Tab 2 Budget — render as dashed-border placeholder card with chart icon + legend text. No real chart unless Recharts already used elsewhere (verify FE registry; if `<LineChart>` exists, build a simple planned-vs-actual line chart from BudgetLines + GrantExpense#63 — likely deferred).
- **⚠ SERVICE_PLACEHOLDER: Rich-text editor for 4 narrative fields** — fall back to textarea if no editor in FE registry. (ISSUE-3)
- **⚠ SERVICE_PLACEHOLDER: Print Cover Sheet / Print Detail** in More dropdown — UI button only; handler shows toast.

Full UI must be built (buttons, forms, modals, tabs, kanban board). Only the handler for the external service call is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning (2026-04-25) | HIGH | BE | GrantReport #63 + GrantExpense not built — Budget Tab 2, Reports Tab 3, Add Expense/Report header actions degrade to SERVICE_PLACEHOLDER until #63 is built | OPEN |
| ISSUE-2 | planning (2026-04-25) | HIGH | FE/BE | File upload infrastructure absent — attachments use URL-string fallback | OPEN |
| ISSUE-3 | planning (2026-04-25) | MED | FE | Rich-text editor missing — 4 narrative fields fall back to textarea | OPEN |
| ISSUE-4 | planning (2026-04-25) | MED | FE | Kanban dual-view custom-built (no drag-drop V1) | OPEN |
| ISSUE-5 | planning (2026-04-25) | MED | BE | GRANTSTAGE codes must match GrantStageHelper constants — verify alignment | OPEN |
| ISSUE-6 | planning (2026-04-25) | MED | BE | Cached TotalSpent/ComplianceRatePct stay 0/NULL until #63 wires expense logging | OPEN |
| ISSUE-7 | planning (2026-04-25) | MED | BE | GrantCode auto-gen: simple MAX+1 with race risk under contention | OPEN |
| ISSUE-8 | planning (2026-04-25) | MED | FE | ApiSelectV2 isMulti may not exist — verify; fallback to MultiSelectChips composite | OPEN |
| ISSUE-9 | planning (2026-04-25) | MED | FE | Excel/PDF export = SERVICE_PLACEHOLDER; CSV via existing util | OPEN |
| ISSUE-10 | planning (2026-04-25) | MED | FE | Amount Range select codes must align between BE handler and FE | OPEN |
| ISSUE-11 | planning (2026-04-25) | LOW | BE | NextReportDueDate auto-compute deferred to post-#63 mutation | OPEN |
| ISSUE-12 | planning (2026-04-25) | LOW | FE | Quick Stats Next Report Due color-coding (warning < 30d, danger < 7d/overdue) | OPEN |
| ISSUE-13 | planning (2026-04-25) | LOW | FE | Add New Funder link routes to Contact form (verify reachability) | OPEN |
| ISSUE-14 | planning (2026-04-25) | LOW | FE | Currency formatting on blur — reuse CurrencyInput if present | OPEN |
| ISSUE-15 | planning (2026-04-25) | LOW | DB | Preserve `sql-scripts-dyanmic/` typo | PRESERVE |
| ISSUE-16 | planning (2026-04-25) | LOW | BE | IsAdminCategory V1 = case-insensitive name match on "Admin"/"Overhead" | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
