---
screen: Case
registry_id: 50
module: Case Management
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: YES — `case` schema (first time creation; shares schema with Program #51 and Beneficiary #49)
planned_date: 2026-04-21
completed_date: 2026-04-24
last_session_date: 2026-04-24
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (list + detail pages — NO separate form page; +Add uses a modal)
- [x] Existing code reviewed (FE stub only at `caselist/page.tsx` — "Need to Develop"; NO BE)
- [x] Business rules + workflow extracted (6-status lifecycle + derived Overdue + closure outcomes)
- [x] FK targets resolved (Staff, Branch exist; Beneficiary #49 + Program #51 are hard dependencies)
- [x] File manifest computed (11 BE for Case + 4×child-entity stacks + 4 FE files + 7 MasterData types)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete (confirm FLOW pattern with quick-add modal OR full-page `?mode=new`)
- [ ] UX Design finalized (grid + 4 KPI widgets; DETAIL layout with 5 tabs — Notes, Action Plan, Referrals, Documents, History)
- [ ] User Approval received
- [ ] Backend code generated (Case + 4 child entities = 5 × 11-file stack; 7 MasterData type seeds)
- [ ] Backend wiring complete (IApplicationDbContext + new CaseDbContext / reuse pattern, Mappings, Decorators, Migrations)
- [ ] Frontend code generated (view-page with 3 modes + Zustand store + 5 tab panels + 3 action modals)
- [ ] Frontend wiring complete (entity-operations, sidebar, route)
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW + 7 MasterDataType seeds)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (case schema migration added)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/casemanagement/caselist`
- [ ] Grid loads with 10 columns + row-overdue red-tint styling when FollowUpDate < today
- [ ] 4 KPI widgets show live counts: Open Cases (with priority breakdown), Overdue Follow-ups, Closed This Month (with avg resolution days), Referrals Pending
- [ ] Filter chips (Status, Priority) + filter selects (Program, Staff, Branch, Date) + "My Cases" toggle work
- [ ] Search filters by case code, beneficiary name, title, description
- [ ] `?mode=new` — empty FORM renders with 9 fields + optional referral sub-form
- [ ] `?mode=edit&id=X` — FORM pre-filled, non-null fields populated
- [ ] `?mode=read&id=X` — DETAIL layout renders (Summary card + 5 tabs + header action bar)
- [ ] Tab: Notes & Activity — note feed renders with type badges, avatars, attachments; "Add Note" inline form creates CaseNote
- [ ] Tab: Action Plan — CaseActionItem table loads; "Add Action Item" opens inline form
- [ ] Tab: Referrals — CaseReferral table loads; "New Referral" reveals inline form with consent checkbox
- [ ] Tab: Documents — CaseDocument list loads; "Upload Document" — SERVICE_PLACEHOLDER toast
- [ ] Tab: History — derived audit timeline renders chronologically
- [ ] Header action: "Update Status" → opens modal → transitions Case.StatusId → grid reflects new status
- [ ] Header action: "Reassign" → modal with staff picker → updates AssignedStaffId
- [ ] Header action: "Close Case" → Close modal with Outcome + ClosureSummary (required) + FollowUpAfterClose toggle + LessonsLearned (optional) → transitions Status=Closed + sets ClosedDate + CaseOutcomeId + ClosureSummary
- [ ] Header action: "More" dropdown → Print Case / Export PDF / Share / Archive (all SERVICE_PLACEHOLDER)
- [ ] Beneficiary name link → navigates to `/[lang]/crm/casemanagement/beneficiarylist?mode=read&id={beneficiaryId}` (works once #49 built)
- [ ] Assigned staff link → navigates to staff detail (existing `/organization/staff/staff?mode=read&id={staffId}`)
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] DB Seed — CASELIST menu visible in sidebar under CRM_CASEMANAGEMENT @ OrderBy=3
- [ ] 7 MasterData type seeds (CASEPRIORITY/CASESTATUS/CASECATEGORY/CASENOTETYPE/CASEACTIONSTATUS/CASEREFERRALSTATUS/CASEOUTCOME) populated

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **Cases** — Case Management intake, tracking, and closure tool.
Module: Case Management (Module code: `CRM` → Parent menu `CRM_CASEMANAGEMENT` MenuId 276)
Schema: `case` (NEW — not yet created; `case` schema will be initialized by **Program #51** in Wave 1; Beneficiary #49 and Case #50 both live in it)
Group: `CaseModels` (entity group), `CaseSchemas`, `CaseBusiness`, `Case` (endpoints)

Business: The Cases screen is the core transactional workflow hub of the Case Management module — social workers and case officers use it to intake, track, and close beneficiary interventions (tutoring support, medical referrals, housing aid, job placement assistance, etc.). Every case binds a **Beneficiary** (the person/household receiving help) to a **Program** (the NGO's delivery program — Education / Healthcare / Women Empowerment / Vocational), a **Priority** (Critical → Low), a **Category** (Educational Support / Medical / Housing / Legal / Nutrition / Protection / Psychosocial / Livelihood / Referral / Other), and an **Assigned Staff** member who owns follow-up. The list page shows all active cases with 4 KPI cards (Open, Overdue, Closed This Month, Referrals Pending), row-level overdue-red-tint highlighting when follow-up dates slip, and strong filter/search affordances. The detail page replaces "edit form" with a **richer case-file view** organized into 5 tabs: (1) **Notes & Activity** — chronological feed of case notes, home visits, phone calls, service deliveries, and milestones; (2) **Action Plan** — actionable commitments with responsible staff, target dates, and completion statuses; (3) **Referrals** — external-organization referrals with consent tracking; (4) **Documents** — file attachments (SERVICE_PLACEHOLDER — UI only, no upload infra yet); (5) **History** — derived audit timeline. The "Close Case" modal captures outcome, closure summary, and lessons learned; optionally schedules a post-closure follow-up. This screen operationalizes a lightweight version of HMIS/ETO/Apricot case-management workflows used across social-service NGOs.

Canonical reference: No prior FLOW screen has a 5-tab rich-detail page yet. Closest structural fit is **ChequeDonation #6** (transactional FLOW with status transitions + modals for transitions). Best DETAIL-layout reference is **Family #20** (card-based layout with right-column context panels). Copy the view-page.tsx skeleton from **SavedFilter** (canonical FLOW) but expand the DETAIL mode into a tabbed rich page — this is the first screen in the project with this pattern.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **All new entities** — schema `case` does not yet exist. CompanyId is NOT a field in Case (tenant from HttpContext).

### Main Table: `case."Cases"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CaseId | int | — | PK | — | Primary key |
| CaseCode | string | 30 | YES | — | Unique per Company; auto-generated `CASE-{NNNN}` zero-padded if empty at Create |
| CaseTitle | string | 200 | YES | — | Short title (e.g., "Reading level below grade — needs tutoring") |
| Description | string | 2000 | YES | — | Full case description/background |
| BeneficiaryId | int | — | YES | `case.Beneficiaries` | FK to Beneficiary (**dependency: #49** must be built first) |
| ProgramId | int? | — | NO | `case.Programs` | FK to Program (**dependency: #51** must be built first). Optional — mockup says "auto-suggested" |
| PriorityId | int | — | YES | `sett.MasterDatas` (TypeCode=`CASEPRIORITY`) | Critical/High/Medium/Low |
| CategoryId | int? | — | NO | `sett.MasterDatas` (TypeCode=`CASECATEGORY`) | Educational Support / Medical / Housing / Legal / Nutrition / Protection / Psychosocial / Livelihood / Referral / Other |
| StatusId | int | — | YES | `sett.MasterDatas` (TypeCode=`CASESTATUS`) | Open / InProgress / Pending / Resolved / Closed. **Overdue is DERIVED** — NOT stored (computed from FollowUpDate < today AND Status in Open/InProgress/Pending) |
| AssignedStaffId | int | — | YES | `app.Staffs` | Primary case owner |
| BranchId | int? | — | NO | `app.Branches` | Optional — which branch/field office owns the case |
| OpenedDate | DateTime | — | YES | — | Defaults to today at Create |
| FollowUpDate | DateTime? | — | NO | — | Next follow-up deadline (drives Overdue derivation) |
| IsExternalReferral | bool | — | YES | — | Default false. If true, ReferralTo + ReferralNotes become required |
| ReferralTo | string? | 200 | NO | — | Organization or individual name (conditional on IsExternalReferral=true) |
| ReferralNotes | string? | 1000 | NO | — | Additional referral details (conditional) |
| ClosedDate | DateTime? | — | NO | — | Set on StatusId = Closed transition |
| CaseOutcomeId | int? | — | NO | `sett.MasterDatas` (TypeCode=`CASEOUTCOME`) | Resolved / Partially Resolved / Unresolved / Referred Out / Graduated / Beneficiary Exited — set on close |
| ClosureSummary | string? | 2000 | NO | — | Required when closing (validator enforces when StatusId=Closed) |
| ClosureFollowUpDate | DateTime? | — | NO | — | Optional post-closure follow-up (from Close modal toggle) |
| LessonsLearned | string? | 2000 | NO | — | Optional — from Close modal |

**Inherited from `Entity` base**: Id, IsActive, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, PKReferenceId.

### Child Entities

Case has **4 first-class child entities** (each needs its own 11-file backend stack):

| Child | Table | Relationship | Purpose |
|-------|-------|-------------|---------|
| **CaseNote** | `case."CaseNotes"` | 1:Many via CaseId | Chronological note feed on DETAIL Notes tab |
| **CaseActionItem** | `case."CaseActionItems"` | 1:Many via CaseId | Action Plan tab — commitments/milestones |
| **CaseReferral** | `case."CaseReferrals"` | 1:Many via CaseId | Referrals tab — external-org referrals |
| **CaseDocument** | `case."CaseDocuments"` | 1:Many via CaseId | Documents tab (SERVICE_PLACEHOLDER — metadata only, no upload infra) |

#### `case."CaseNotes"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CaseNoteId | int | — | PK | — | — |
| CaseId | int | — | YES | case.Cases | FK parent |
| NoteTypeId | int | — | YES | sett.MasterDatas (TypeCode=`CASENOTETYPE`) | Case Note / Home Visit / Phone Call / Service Delivered / Referral Update / Milestone / Status Change / Case Opened |
| Content | string | 4000 | YES | — | Note body |
| FollowUpDate | DateTime? | — | NO | — | Optional — author can schedule next follow-up from the note |
| NotifySupervisor | bool | — | YES | — | Default false. SERVICE_PLACEHOLDER — triggers notification (no pipeline yet) |
| AuthorStaffId | int | — | YES | app.Staffs | Auto-set from current user's staff record |
| AttachmentUrl | string? | 1000 | NO | — | SERVICE_PLACEHOLDER — single file path (multi-file support deferred) |
| AttachmentName | string? | 200 | NO | — | Display name for the attachment |

#### `case."CaseActionItems"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CaseActionItemId | int | — | PK | — | — |
| CaseId | int | — | YES | case.Cases | FK parent |
| ActionSequence | int | — | YES | — | Display order (1,2,3 in mockup) |
| ActionDescription | string | 500 | YES | — | e.g. "Arrange bi-weekly tutoring" |
| ResponsibleStaffId | int | — | YES | app.Staffs | Who owns this action |
| TargetDate | DateTime? | — | NO | — | Deadline; nullable for "Recurring" actions |
| IsRecurring | bool | — | YES | — | Default false. If true, TargetDate becomes "Next: {date}" and status auto-stays Recurring |
| ActionStatusId | int | — | YES | sett.MasterDatas (TypeCode=`CASEACTIONSTATUS`) | Done / Recurring / Pending / InProgress / Contingent |
| Notes | string? | 1000 | NO | — | Free-text ("Ravi Kumar assigned as tutor", "Next: May 1", etc.) |

#### `case."CaseReferrals"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CaseReferralId | int | — | PK | — | — |
| CaseId | int | — | YES | case.Cases | FK parent |
| ReferralCode | string | 30 | YES | — | Auto-gen `REF-{NNNN}` |
| ReferTo | string | 200 | YES | — | Org/provider name |
| ContactPerson | string? | 100 | NO | — | Contact name at the referred org |
| ContactPhoneEmail | string? | 100 | NO | — | Phone or email |
| Reason | string | 1000 | YES | — | Why the referral |
| ReferralDate | DateTime | — | YES | — | Defaults today |
| ReferralStatusId | int | — | YES | sett.MasterDatas (TypeCode=`CASEREFERRALSTATUS`) | Pending / Awaiting Response / Accepted / Rejected / Completed |
| Response | string? | 1000 | NO | — | Free-text response received |
| ConsentGiven | bool | — | YES | — | Must be `true` to send (validator enforces) |
| DocumentsSharedUrl | string? | 1000 | NO | — | SERVICE_PLACEHOLDER — single doc ref |

#### `case."CaseDocuments"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CaseDocumentId | int | — | PK | — | — |
| CaseId | int | — | YES | case.Cases | FK parent |
| FileName | string | 200 | YES | — | e.g. `teacher_feedback_apr2026.pdf` |
| FileSizeBytes | long | — | YES | — | — |
| FileMimeType | string | 100 | YES | — | e.g. `application/pdf` |
| FilePathUrl | string | 1000 | YES | — | SERVICE_PLACEHOLDER — storage integration pending |
| UploadedByStaffId | int | — | YES | app.Staffs | Auto-set from current user |
| UploadedDate | DateTime | — | YES | — | Defaults now |
| Description | string? | 500 | NO | — | Optional caption |

### History is DERIVED (no dedicated table)

The "History" tab renders a timeline synthesized at query-time from:
- Case audit columns (CreatedDate, ModifiedDate, ClosedDate)
- CaseNote timestamps + types
- CaseActionItem.ActionStatusId changes (ModifiedDate when status flips)
- Case.StatusId change events

A dedicated `GetCaseHistory` query composes these into a uniform `{date, type, actor, text}` DTO list. No `CaseHistory` table needed for MVP.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelectV2 queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| **BeneficiaryId** | Beneficiary | `Base.Domain/Models/CaseModels/Beneficiary.cs` ⚠ **NOT YET BUILT** (#49 PARTIAL) | `beneficiaries` (GetAllBeneficiariesList) | `beneficiaryName` (id: `beneficiaryId`), plus `beneficiaryCode` (shown as subtitle like BEN-001) | `BeneficiaryResponseDto` |
| **ProgramId** | Program | `Base.Domain/Models/CaseModels/Program.cs` ⚠ **NOT YET BUILT** (#51 PARTIAL) | `programs` (GetAllProgramsList) | `programName` (id: `programId`) | `ProgramResponseDto` |
| AssignedStaffId | Staff | [Staff.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Staff.cs) ✓ EXISTS | `staffs` (GetStaffs) | `staffName` (id: `staffId`) | `StaffResponseDto` |
| BranchId | Branch | [Branch.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Branch.cs) ✓ EXISTS | `branches` (GetBranches) | `branchName` (id: `branchId`) | `BranchResponseDto` |
| PriorityId | MasterData | [MasterData.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/MasterData.cs) ✓ EXISTS | `masterDataListByTypeCode(typeCode: "CASEPRIORITY")` | `dataName` (id: `masterDataId`) | `MasterDataResponseDto` |
| StatusId | MasterData | same | `masterDataListByTypeCode(typeCode: "CASESTATUS")` | `dataName` | `MasterDataResponseDto` |
| CategoryId | MasterData | same | `masterDataListByTypeCode(typeCode: "CASECATEGORY")` | `dataName` | `MasterDataResponseDto` |
| CaseOutcomeId | MasterData | same | `masterDataListByTypeCode(typeCode: "CASEOUTCOME")` | `dataName` | `MasterDataResponseDto` |
| CaseNote.NoteTypeId | MasterData | same | `masterDataListByTypeCode(typeCode: "CASENOTETYPE")` | `dataName` | `MasterDataResponseDto` |
| CaseNote.AuthorStaffId | Staff | same as AssignedStaffId | `staffs` | `staffName` | `StaffResponseDto` |
| CaseActionItem.ResponsibleStaffId | Staff | same | `staffs` | `staffName` | `StaffResponseDto` |
| CaseActionItem.ActionStatusId | MasterData | same | `masterDataListByTypeCode(typeCode: "CASEACTIONSTATUS")` | `dataName` | `MasterDataResponseDto` |
| CaseReferral.ReferralStatusId | MasterData | same | `masterDataListByTypeCode(typeCode: "CASEREFERRALSTATUS")` | `dataName` | `MasterDataResponseDto` |
| CaseDocument.UploadedByStaffId | Staff | same | `staffs` | `staffName` | `StaffResponseDto` |

**⚠ Hard Dependencies**: Build order must be **#51 Program → #49 Beneficiary → #50 Case**. `/build-screen #50` will fail at migration step if `case.Programs` and `case.Beneficiaries` tables don't exist. The `case` schema is expected to be created by Program #51 (the first entity in the schema per Wave 1 of DEPENDENCY-ORDER.md).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

### Workflow (5-status lifecycle + derived Overdue)

```
         Case Creation
              │
              ▼
         ┌─────────┐    Update Status    ┌──────────────┐    Update Status    ┌──────────┐
 +New → │  Open   │ ─────────────────→ │  InProgress  │ ─────────────────→ │ Resolved │
         └─────────┘                     └──────────────┘                     └──────────┘
              │                                 │                                 │
              │ "Pending Referral"              │ "Pending Referral"              │
              ▼                                 ▼                                 │
         ┌─────────┐                     ┌──────────────┐                        │
         │ Pending │                     │   Pending    │                        │
         └────┬────┘                     └──────┬───────┘                        │
              └──── (back to InProgress or forward to Resolved) ───────┘         │
                                                                                 │
                         Close Case modal → StatusId=Closed + CaseOutcomeId      │
                                                       ▼                         │
                                                 ┌──────────┐                    │
                                                 │  Closed  │ ◄─────────────────┘
                                                 └──────────┘
                                                  (terminal)

  DERIVED: Overdue = (StatusId ∈ {Open, InProgress, Pending}) AND FollowUpDate < today
           Rendered as a red-tint row AND the badge swaps to "Overdue" variant
           NOT a stored status — do NOT add it to CASESTATUS MasterData.
```

### Uniqueness Rules
- `CaseCode` unique per Company per IsActive=true (filtered composite unique index)
- `CaseReferral.ReferralCode` unique globally (index; auto-gen format REF-{NNNN})

### Required Field Rules

| Context | Required Fields |
|---------|----------------|
| Create Case | CaseTitle, Description, BeneficiaryId, PriorityId, AssignedStaffId (StatusId auto=Open, OpenedDate=today) |
| Update Case (edit mode, form) | Same as Create (minus StatusId auto-set) |
| Mark external referral | If IsExternalReferral=true → ReferralTo required, ReferralNotes optional |
| Close Case (modal) | CaseOutcomeId, ClosureSummary; ClosureFollowUpDate optional (from toggle); LessonsLearned optional |
| Add CaseNote | NoteTypeId, Content |
| Add CaseActionItem | ActionDescription, ResponsibleStaffId, ActionStatusId, (TargetDate required unless IsRecurring=true) |
| Add CaseReferral | ReferTo, Reason, ReferralStatusId (auto=Pending), ConsentGiven=true |
| Add CaseDocument | FileName, FileSizeBytes, FileMimeType, FilePathUrl (SERVICE_PLACEHOLDER — all filled by upload handler, not user) |

### Conditional Rules
- If `IsExternalReferral` toggle is false → ReferralTo and ReferralNotes are hidden/ignored
- If `StatusId` code = `Closed` → all form fields read-only; only View+Print actions available; no "Update Status" button
- If `CaseActionItem.IsRecurring=true` → TargetDate field hidden; status forced to Recurring on Save
- If `CaseReferral.ConsentGiven=false` → "Send Referral" submit button DISABLED in FE (validator also enforces server-side)
- **Overdue derivation** happens in `GetAllCasesList` via LINQ projection — NOT stored; all grid rows get a `isOverdue: bool` computed flag
- When `NotifySupervisor=true` on a CaseNote → SERVICE_PLACEHOLDER (no-op handler; toast "Supervisor would be notified")

### Business Logic
- **Case close** is an idempotent transition: `CloseCase` command sets StatusId→Closed, ClosedDate=now, requires CaseOutcomeId + ClosureSummary; re-calling CloseCase on a Closed case is a no-op.
- **Case re-open**: allowed via `ReopenCase` command (restores StatusId to `Open`, nulls ClosedDate/CaseOutcomeId/ClosureSummary/LessonsLearned/ClosureFollowUpDate). Does NOT restore CaseNotes/CaseActionItems.
- **Reassign**: dedicated `ReassignCase` command — flips AssignedStaffId and writes a CaseNote of type `Status Change` with content `"Reassigned from {oldStaff} to {newStaff}"`.
- **UpdateStatus**: dedicated `UpdateCaseStatus` command — flips StatusId and writes a CaseNote of type `Status Change` with content `"Status changed from {oldStatus} to {newStatus}"`.
- CaseCode auto-gen: `CASE-{NNNN}` zero-padded 4-digit per Company (sequence query in handler).
- CaseReferralCode auto-gen: `REF-{NNNN}` zero-padded 4-digit per Company.
- **Bulk actions** (from list page): Reassign, Export, Send Reminders — only Reassign and Export have BE implementation; Send Reminders is SERVICE_PLACEHOLDER.

### Derived Counters (for KPI widgets — computed by `GetCaseSummary` query)
- `openCasesCount` = COUNT WHERE StatusId ∈ {Open, InProgress, Pending} AND IsDeleted=false
- `openCriticalCount` / `openHighCount` / `openMediumCount` / `openLowCount` = same + PriorityId filter
- `overdueFollowUpsCount` = COUNT WHERE (StatusId NOT Closed AND NOT Resolved) AND FollowUpDate < today
- `oldestOverdueDays` = MAX(today - FollowUpDate) for the overdue bucket
- `closedThisMonthCount` = COUNT WHERE StatusId=Closed AND ClosedDate BETWEEN start-of-month AND today
- `avgResolutionDays` = AVG(ClosedDate - OpenedDate) for the closedThisMonth bucket
- `referralsPendingCount` = COUNT(CaseReferral) WHERE ReferralStatusId ∈ {Pending, AwaitingResponse} grouped across all active cases

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: `FLOW — rich-detail tabbed view with quick-add modal`
**Reason**: Workflow/transactional — case records have a lifecycle (Open→InProgress→Pending→Resolved→Closed), multiple child entities requiring tab-based organization (Notes, ActionItems, Referrals, Documents, History), and status-transition actions (Update Status, Reassign, Close Case) rendered as modals on the detail page. The DETAIL mode is a **full rich case-file page**, NOT a disabled form. The quick-add modal in the mockup is a simplification — build `view-page.tsx` to support `?mode=new` full-page form as well as a quick-add modal (both invoke the same `CreateCase` mutation).

**Backend Patterns Required:**
- [x] Standard CRUD for Case (11 files)
- [x] Standard CRUD for CaseNote (11 files)
- [x] Standard CRUD for CaseActionItem (11 files)
- [x] Standard CRUD for CaseReferral (11 files)
- [x] Standard CRUD for CaseDocument (11 files — even though upload is SERVICE_PLACEHOLDER, CRUD metadata ops are real)
- [x] Tenant scoping (CompanyId from HttpContext on all 5 entities)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 7+ across Case + children)
- [x] Unique validation — CaseCode, ReferralCode per Company
- [x] **Workflow commands on Case** (distinct from generic Update):
      - `UpdateCaseStatus(caseId, newStatusId)` — transitions with audit CaseNote
      - `ReassignCase(caseId, newStaffId)` — reassign with audit CaseNote
      - `CloseCase(caseId, outcomeId, summary, followUpDate?, lessonsLearned?)` — close with validation
      - `ReopenCase(caseId)` — restore to Open state
- [x] Auto-gen CaseCode in `CreateCase` handler (`CASE-{NNNN}` per Company sequence)
- [x] Auto-gen ReferralCode in `CreateCaseReferral` handler (`REF-{NNNN}` per Company)
- [x] **Summary query**: `GetCaseSummary` — returns CaseSummaryDto for 4 KPI widgets
- [x] **History projection query**: `GetCaseHistory(caseId)` — unifies audit events into timeline
- [ ] File upload command — **NO** (SERVICE_PLACEHOLDER: UI widget renders but upload handler is mock)
- [x] Custom business rule validators:
      - CloseCase requires CaseOutcomeId + ClosureSummary
      - CreateCase → if IsExternalReferral=true then ReferralTo required
      - CreateCaseReferral → ConsentGiven must be true
      - CreateCaseActionItem → TargetDate required unless IsRecurring=true

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) with row-overdue CSS variant
- [x] view-page.tsx with 3 URL modes (new, edit, read) — read mode renders the tabbed detail
- [x] React Hook Form (for FORM layout — new/edit)
- [x] Zustand store (`case-store.ts`) — persists active tab + pending modal state + filter state
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back + Save in form modes; Back + header action bar in read mode)
- [x] **Child grid inside DETAIL tab panels** (4 child entities — each tab has its own inline add-form or "Add X" toggle button)
- [x] **Workflow status badge + header action buttons** (Update Status / Reassign / Close Case / More)
- [x] **3 action modals** on DETAIL: Update Status modal, Reassign modal, Close Case modal (with Outcome + Summary + FollowUp toggle + Lessons)
- [x] File upload widget — SERVICE_PLACEHOLDER (drag-drop zone renders; handler shows toast)
- [x] **Summary cards / count widgets above grid** — 4 KPI cards
- [ ] Grid aggregation columns — not applicable (no per-row computed financial/count values; overdue is a CSS-tint flag, not a column)
- [x] **Tabbed detail page** — new pattern in this project (first FLOW screen with 5 tabs)
- [x] **Row-click navigation** to `?mode=read&id={id}`; Beneficiary-name sub-link navigates to beneficiary detail

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Grid/List View

**Display Mode**: `table` (dense transactional list)

**Grid Columns** (in display order, from `case-list.html` table):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | (checkbox) | (row selection) | checkbox | 36px | — | For bulk actions |
| 2 | Case ID | caseCode | text (strong) | 110px | YES | e.g. "CASE-301" |
| 3 | Beneficiary | beneficiaryName + beneficiaryCode | text + subtitle | 180px | YES | Cyan link → beneficiary detail; BEN-ID as small text below |
| 4 | Title | caseTitle | text (ellipsis) | 240px (max) | YES | title attribute = full text for tooltip |
| 5 | Program | programName | text | 120px | YES | — |
| 6 | Priority | priorityBadge | badge (colored pill) | 100px | YES | critical=red, high=orange, medium=amber, low=green |
| 7 | Opened | openedDate | date (short: "Mar 15") | 90px | YES | — |
| 8 | Due / Follow-up | followUpDate + overdue indicator | date + overdue-red-text + triangle-exclamation icon | 120px | YES | If row.isOverdue → red date + "⚠ Overdue" badge below |
| 9 | Assigned | assignedStaffName | text | 140px | YES | — |
| 10 | Status | statusBadge | badge (colored pill) | 110px | YES | open=green, in-progress=blue, pending=amber, overdue=red (derived), resolved=teal, closed=gray |
| 11 | Actions | — | action cluster | 100px | NO | `[View]` button + 3-dot dropdown: View / Edit / Add Note / Reassign / Escalate / Close Case |

**Row Styling**: if `row.isOverdue === true` → add CSS class `row-overdue` → row bg = `#fef2f2`, hover = `#fee2e2`.

**Search/Filter Fields**:
- Text search: case code, beneficiary name, title, description
- Filter chips (status): All / Open / In Progress / Pending Referral / Follow-up Due / Resolved / Closed
  - Note: "Pending Referral" = StatusId=Pending; "Follow-up Due" = Overdue derivation
- Filter chips (priority): All / Critical / High / Medium / Low
- Select: Program (All Programs + dynamic list via `programs` query)
- Select: Assigned Staff (All Staff + dynamic list via `staffs` query)
- Checkbox: "My Cases" (filters WHERE AssignedStaffId = currentUser.StaffId)
- Select: Branch (All Branches + dynamic list via `branches` query)
- Select: Date range (All Dates / Overdue / Due This Week / Due This Month)
- Link: Clear Filters — resets all filter state

**Grid Actions (3-dot per row)**: View (→ read mode) / Edit (→ edit mode) / Add Note (opens inline add-note modal on detail) / Reassign (opens reassign modal) / Escalate (SERVICE_PLACEHOLDER — toast) / Close Case (opens close-case modal)

**Row Click**: Navigates to `?mode=read&id={caseId}` (DETAIL layout)

**Bulk Actions Bar** (below grid, shown when ≥1 row selected):
- Reassign (opens reassign-modal scoped to selected case IDs — bulk-reassign mutation)
- Export (CSV / Excel / PDF — first two real, PDF is SERVICE_PLACEHOLDER)
- Send Reminders — SERVICE_PLACEHOLDER (notification pipeline not built)

**Pagination**: standard DataTableContainer pagination, page size 20.

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

#### LAYOUT 1: FORM (mode=new & mode=edit)

> The form used when `?mode=new` or `?mode=edit&id=X`. Single-column 2-grid layout (8 fields + optional referral sub-form).
> **Quick-add modal variant**: from the grid, "+New Case" MAY open a modal with the same form fields (per mockup). The modal and full-page form share the same React Hook Form instance + validator + submit handler. Defaults to modal per mockup; implementation can expose `?mode=new` URL as an alternative.

**Page Header (full-page mode)**: `FlowFormPageHeader` with Back button + Save button + unsaved changes dialog.

**Section Container Type**: single card, 2-column grid layout (no tabs, no accordion — simple intake form).

**Form Sections**:

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | `fa-plus` | New Case | 2-column grid | always expanded | Beneficiary, Title, Program, Priority, Description (full-width), Category, Assigned To, Follow-up Date, External Referral checkbox + (conditional) ReferralTo + ReferralNotes |

**Field Widget Mapping**:

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| CaseCode | — | (hidden) | — | auto-generated | Do NOT render — set server-side |
| BeneficiaryId | 1 | ApiSelectV2 | "Search beneficiary..." | required | Query: `beneficiaries`; displays `beneficiaryName` + small-text `beneficiaryCode` |
| CaseTitle | 1 | text (full-width across 2 cols) | "Brief case title" | required, max 200 | — |
| ProgramId | 1 | ApiSelectV2 | "Select program (auto-suggested)" | optional | Query: `programs`; consider auto-suggest via beneficiary's program if applicable |
| PriorityId | 1 | ApiSelectV2 | "Select priority" | required | Query: `masterDataListByTypeCode(typeCode: "CASEPRIORITY")` |
| Description | 1 | textarea rows=3 (full-width) | "Describe the case details, background, and objectives..." | required, max 2000 | — |
| CategoryId | 1 | ApiSelectV2 | "Select category" | optional | Query: `masterDataListByTypeCode(typeCode: "CASECATEGORY")` |
| AssignedStaffId | 1 | ApiSelectV2 | "Select staff member" | required | Query: `staffs` |
| FollowUpDate | 1 | datepicker | "Select date" | optional | — |
| IsExternalReferral | 1 | checkbox | "External referral needed" | — | Toggles visibility of the sub-form below |
| ReferralTo | 1 (sub) | text | "Organization or individual name" | conditional required | Shown only when IsExternalReferral=true |
| ReferralNotes | 1 (sub) | textarea rows=2 | "Additional referral details..." | optional | Shown only when IsExternalReferral=true |

**Conditional Sub-form** (the "referral-fields" panel in mockup):

| Trigger Field | Trigger Value | Sub-form Fields |
|--------------|---------------|-----------------|
| IsExternalReferral | true | ReferralTo (required when shown), ReferralNotes (optional) — rendered inside a shaded panel below the checkbox |

**Inline Mini Display**: (none in create; on Edit mode, consider showing a small badge with current StatusId + OpenedDate for context)

**Child Grids in Form**: (none — child entities are added on the DETAIL page, not during Case creation)

---

#### LAYOUT 2: DETAIL (mode=read) — Rich tabbed case-file page

> The read-only detail page shown when user clicks a grid row (`?mode=read&id=301`).
> NOT a disabled form — a **completely different UI** organized as a Summary card + 5 tabs + a header action bar.

**Page Header Area**:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ Breadcrumb: Cases › CASE-301                                                         │
│ H1: CASE-301: Reading level below grade — needs tutoring                             │
│ Meta row 1: Beneficiary: Yusuf Hassan (BEN-001) [View Profile]                       │
│             Program: 📚 Education                                                    │
│             Priority: [Medium badge]  Status: [Open badge]                           │
│ Meta row 2: Assigned: [Ahmed Salim link]                                             │
│             Opened: Mar 15, 2026                                                     │
│                                                                                       │
│ Action bar (top-right):                                                               │
│   [+ Add Note] [✎ Update Status] [👤 Reassign] [✕ Close Case (red outline)] [⋯ More] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Header Actions**:
- `+ Add Note` — opens inline add-note form in the Notes tab (auto-switches to Notes tab)
- `Update Status` — opens modal: status picker (MasterData CASESTATUS) + optional note content; submits `UpdateCaseStatus` mutation
- `Reassign` — opens modal: staff picker + optional note; submits `ReassignCase` mutation
- `Close Case` (red outlined) — opens **Close Case modal** (see below)
- `More` dropdown:
  - Print Case (SERVICE_PLACEHOLDER — toast)
  - Export PDF (SERVICE_PLACEHOLDER — toast)
  - Share (SERVICE_PLACEHOLDER — toast)
  - Archive (SERVICE_PLACEHOLDER — toast)

**Case Summary Card** (single card below header, 2-column grid):

Left column: Case ID, Beneficiary (name + age if available), Program, Opened
Right column: Priority (badge), Status (badge), Assigned To (link), Follow-up date

Below (full-width, separator above): **Description** — full case description text

---

**Tab Navigation** (5 tabs below summary card): `[Notes & Activity] [Action Plan] [Referrals] [Documents] [History]`

#### Tab 1: Notes & Activity

- Header: (empty — "+ Add Note" button in page-header)
- **Add Note inline form** (collapsed by default, expands on click):
  - NoteTypeId dropdown (7 options — CASENOTETYPE MasterData)
  - FollowUpDate picker
  - NotifySupervisor checkbox
  - Content textarea (rows=5)
  - Attachments drop-zone (SERVICE_PLACEHOLDER)
  - Cancel / Add Note buttons
- **Note Feed**: `CaseNote` list ordered by CreatedDate DESC
  - Each row:
    - Avatar (staff initials, colored background — teal for primary author, accent for others)
    - Header row: `{date} — {authorStaffName}  [NoteType badge]`
    - Content paragraph
    - Attachment chip (if AttachmentUrl present) — click = preview/download (SERVICE_PLACEHOLDER)

#### Tab 2: Action Plan

- `CaseActionItem` table with columns: # (sequence), Action, Responsible (staff link), Target Date, Status (badge), Notes
- Status badges: Done=green, Recurring=blue, Pending=gray, InProgress=blue, Contingent=gray
- Bottom: "`+ Add Action Item`" toggle button → reveals inline form with: ActionDescription, ResponsibleStaffId (ApiSelectV2 staffs), TargetDate, IsRecurring toggle, ActionStatusId, Notes

#### Tab 3: Referrals

- `CaseReferral` table with columns: Referral # (code), Referred To, Reason, Date, Status (badge), Response, Actions (Follow Up button)
- Bottom: "`+ New Referral`" toggle button → reveals inline form with all CaseReferral fields incl. Consent checkbox (submit disabled until checked)

#### Tab 4: Documents

- File list (cards) — each row: icon (pdf/image/doc) + FileName + FileSize + UploadedDate + Download button (SERVICE_PLACEHOLDER)
- Bottom: "`+ Upload Document`" button (SERVICE_PLACEHOLDER — opens drop-zone modal with toast-only handler)

#### Tab 5: History

- Timeline (derived from `GetCaseHistory(caseId)` query):
  - Vertical line with teal dots
  - Each row: date + event text
  - Example rows: "Apr 10 — Note added by Ahmed Salim", "Mar 20 — Action item #1 marked as Done", "Mar 15 — Case opened by Ahmed Salim"

---

### Action Modals on DETAIL

#### Update Status Modal
```
Title: ✎ Update Status
Fields:
  - New Status * (MasterData CASESTATUS dropdown, current value excluded)
  - Note / Reason (textarea, optional)
Footer: [Cancel]  [Update Status (primary)]
Submit → UpdateCaseStatus(caseId, newStatusId, note?)
```

#### Reassign Modal
```
Title: 👤 Reassign
Fields:
  - New Assignee * (ApiSelectV2 staffs; excludes current)
  - Note / Reason (textarea, optional)
Footer: [Cancel]  [Reassign (primary)]
Submit → ReassignCase(caseId, newStaffId, note?)
```

#### Close Case Modal
```
Title: ✕ Close Case (red icon)
Fields:
  - Outcome * (MasterData CASEOUTCOME dropdown — Resolved/Partially Resolved/Unresolved/Referred Out/Graduated/Beneficiary Exited)
  - Closure Summary * (textarea, rows=3)
  - [toggle switch] Follow-up Needed After Closure
     ↳ (if toggled on) ClosureFollowUpDate datepicker
  - Lessons Learned (optional textarea, rows=2)
Footer: [Cancel]  [Confirm Close (red bg)]
Submit → CloseCase(caseId, outcomeId, summary, followUpDate?, lessonsLearned?)
```

---

### Page Widgets & Summary Cards

**Widgets**: 4 KPI cards in a horizontal grid (1-col mobile, 2-col tablet, 4-col desktop).

| # | Widget Title | Value Source | Display Type | Position | Sub-text |
|---|-------------|-------------|-------------|----------|----------|
| 1 | Open Cases | summary.openCasesCount | number (large, teal icon fa-folder-open) | col 1 | "Critical: {n}, High: {n}, Medium: {n}, Low: {n}" |
| 2 | Overdue Follow-ups | summary.overdueFollowUpsCount | number (red icon fa-clock) | col 2 | "Oldest: **{n} days overdue**" (danger red) |
| 3 | Closed This Month | summary.closedThisMonthCount | number (green icon fa-check-circle) | col 3 | "Avg resolution: **{n} days**" (success green) |
| 4 | Referrals Pending | summary.referralsPendingCount | number (orange icon fa-share) | col 4 | "Awaiting external response" |

**Grid Layout Variant**: `widgets-above-grid` → FE Dev MUST use **Variant B**: `<ScreenHeader>` + KPI widgets + `<DataTableContainer showHeader={false}>`. Missing this → double-header UI bug (Contact Type #19 / Auction Management #48 precedent).

**Summary GQL Query**:
- Query name: `GetCaseSummary`
- Returns: `CaseSummaryDto { openCasesCount, openCriticalCount, openHighCount, openMediumCount, openLowCount, overdueFollowUpsCount, oldestOverdueDays, closedThisMonthCount, avgResolutionDays, referralsPendingCount }`
- Added to `CaseQueries.cs` alongside `GetAllCasesList` and `GetCaseById`

### Grid Aggregation Columns

**Aggregation Columns**: NONE. Overdue is a row-level CSS-tint flag (`isOverdue` bool projected by `GetAllCasesList`), not a column.

### User Interaction Flow

1. User sees grid with 4 KPI cards + filter bar → clicks `+ New Case` → **modal opens** (quick-add) OR user navigates to `?mode=new` → FORM LAYOUT loads
2. User fills form → clicks Save → `CreateCase` creates record with StatusId=Open + OpenedDate=today + auto CaseCode
   → URL redirects to `/caselist?mode=read&id={newId}` → DETAIL LAYOUT loads
3. User clicks any grid row → URL: `/caselist?mode=read&id={id}` → DETAIL layout with tabs
4. On DETAIL, user clicks `+ Add Note` → inline add-note form expands in Notes tab → submit creates CaseNote → feed refreshes
5. On DETAIL, user clicks `Update Status` → modal → select new status → submit `UpdateCaseStatus` → grid row badge changes + CaseNote(type=Status Change) appears in feed
6. On DETAIL, user clicks `Close Case` → modal with required Outcome + ClosureSummary → submit `CloseCase` → StatusId=Closed, badge changes, form becomes read-only, appropriate header buttons hide
7. On DETAIL, user clicks Edit (from action menu or maybe from a pencil icon on each field — TBD) → URL: `/caselist?mode=edit&id={id}` → FORM LAYOUT loads pre-filled
8. Edit mode → Save → `UpdateCase` updates record → URL returns to `?mode=read&id={id}`
9. From grid, multi-select + click Bulk Reassign → bulk modal → submit → all selected cases reassigned
10. Back button: `/caselist` (no params) → grid view
11. Unsaved changes dialog triggers on dirty form navigation

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: SavedFilter (FLOW structural skeleton) + ChequeDonation (status transitions + transition modals) + Family (card-based DETAIL panels)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | Case | Entity/class name |
| savedFilter | caseEntity (**NOT** `case` — reserved C# keyword) / caseItem in FE store | Variable/field names — C# uses `caseEntity` or `@case`; FE uses `caseItem` to avoid `case` clash |
| SavedFilterId | CaseId | PK field |
| SavedFilters | Cases | Table name (`case."Cases"`), collection names |
| saved-filter | case | FE route leaf path (but the containing folder is `caselist` per mockup route) |
| savedfilter | case (folder name for FE service imports) | FE service folder |
| SAVEDFILTER | CASE | Grid code; also MasterData prefix (CASEPRIORITY, CASESTATUS, etc.) |
| notify | case | DB schema |
| Notify | Case | Backend group name (CaseModels / CaseSchemas / CaseBusiness) |
| NotifyModels | CaseModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_CASEMANAGEMENT | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/casemanagement/caselist | FE route path |
| notify-service | case-service | FE service folder name |

**C# reserved-keyword note**: `case` is a C# keyword. Use `@case` sparingly (DbContext property name should be `Cases` not `@case`). Entity class is `Case` (title-case, non-reserved). Variable names in handlers: prefer `caseEntity`, `caseRecord`, or `existingCase`. Do NOT use `var case = ...` (parse error).

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files — Case (11 files)

| # | File | Path |
|---|------|------|
| 1 | Entity | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/CaseModels/Case.cs |
| 2 | EF Config | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/CaseConfigurations/CaseConfiguration.cs |
| 3 | Schemas (DTOs) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/CaseSchemas/CaseSchemas.cs |
| 4 | Create Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/CaseBusiness/Cases/CreateCommand/CreateCase.cs |
| 5 | Update Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/CaseBusiness/Cases/UpdateCommand/UpdateCase.cs |
| 6 | Delete Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/CaseBusiness/Cases/DeleteCommand/DeleteCase.cs |
| 7 | Toggle Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/CaseBusiness/Cases/ToggleCommand/ToggleCase.cs |
| 8 | GetAll Query | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/CaseBusiness/Cases/GetAllQuery/GetAllCases.cs |
| 9 | GetById Query | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/CaseBusiness/Cases/GetByIdQuery/GetCaseById.cs |
| 10 | Mutations endpoint | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Case/Mutations/CaseMutations.cs |
| 11 | Queries endpoint | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Case/Queries/CaseQueries.cs |

### Backend Files — Case Workflow Commands (4 additional)

| # | File | Path |
|---|------|------|
| W1 | UpdateCaseStatus | PSS_2.0_Backend/.../CaseBusiness/Cases/UpdateStatusCommand/UpdateCaseStatus.cs |
| W2 | ReassignCase | PSS_2.0_Backend/.../CaseBusiness/Cases/ReassignCommand/ReassignCase.cs |
| W3 | CloseCase | PSS_2.0_Backend/.../CaseBusiness/Cases/CloseCommand/CloseCase.cs |
| W4 | ReopenCase | PSS_2.0_Backend/.../CaseBusiness/Cases/ReopenCommand/ReopenCase.cs |

### Backend Files — Case Summary + History (2 additional queries)

| # | File | Path |
|---|------|------|
| S1 | GetCaseSummary | PSS_2.0_Backend/.../CaseBusiness/Cases/GetSummaryQuery/GetCaseSummary.cs |
| S2 | GetCaseHistory | PSS_2.0_Backend/.../CaseBusiness/Cases/GetHistoryQuery/GetCaseHistory.cs |

### Backend Files — CaseNote (11 files, same pattern as Case)
Path: `PSS_2.0_Backend/.../CaseModels/CaseNote.cs`, `CaseConfigurations/CaseNoteConfiguration.cs`, `CaseSchemas/CaseNoteSchemas.cs`, `CaseBusiness/CaseNotes/…`, `EndPoints/Case/Mutations/CaseNoteMutations.cs`, `EndPoints/Case/Queries/CaseNoteQueries.cs`

### Backend Files — CaseActionItem (11 files, same pattern)
Path: `…/CaseModels/CaseActionItem.cs`, `…/CaseConfigurations/CaseActionItemConfiguration.cs`, `…/CaseSchemas/CaseActionItemSchemas.cs`, `…/CaseBusiness/CaseActionItems/…`, mutations + queries

### Backend Files — CaseReferral (11 files, same pattern)
Path: `…/CaseModels/CaseReferral.cs`, `…/CaseConfigurations/CaseReferralConfiguration.cs`, `…/CaseSchemas/CaseReferralSchemas.cs`, `…/CaseBusiness/CaseReferrals/…`, mutations + queries

### Backend Files — CaseDocument (11 files, same pattern; upload handler is SERVICE_PLACEHOLDER)
Path: `…/CaseModels/CaseDocument.cs`, `…/CaseConfigurations/CaseDocumentConfiguration.cs`, `…/CaseSchemas/CaseDocumentSchemas.cs`, `…/CaseBusiness/CaseDocuments/…`, mutations + queries

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | DbSet<Case>, DbSet<CaseNote>, DbSet<CaseActionItem>, DbSet<CaseReferral>, DbSet<CaseDocument> |
| 2 | (New) CaseDbContext.cs OR extend ApplicationDbContext | DbSets + schema("case").HasDefaultSchema() if per-module DbContext pattern is in use (check how DonationModels / NotifyModels are wired) |
| 3 | DecoratorProperties.cs | `DecoratorCaseModules` entry pointing to CaseBusiness assembly |
| 4 | CaseMappings.cs (NEW) | Mapster mapping configs for Case, CaseNote, CaseActionItem, CaseReferral, CaseDocument |
| 5 | Startup/DI registration | Register Case module schemas + mappings + validators |
| 6 | Migration | Add new `case` schema + 5 tables + FK indexes + filtered unique index on CaseCode (per Company, IsActive=true) |

### Frontend Files — Case (9 files + 3 modal components + 5 tab panels)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/case-service/CaseDto.ts (+ CaseNoteDto, CaseActionItemDto, CaseReferralDto, CaseDocumentDto, CaseSummaryDto, CaseHistoryEventDto) |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/case-queries/CaseQuery.ts (+ child-entity queries) |
| 3 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/case-mutations/CaseMutation.ts (+ workflow mutations: UpdateStatus/Reassign/Close/Reopen + child mutations) |
| 4 | Page Config | PSS_2.0_Frontend/src/presentation/pages/case/caselist/case.tsx |
| 5 | Index Page | PSS_2.0_Frontend/src/presentation/components/page-components/case/caselist/case/index.tsx |
| 6 | Index Page Component | PSS_2.0_Frontend/src/presentation/components/page-components/case/caselist/case/index-page.tsx (Variant B — ScreenHeader + 4 KPI widgets + DataTableContainer showHeader=false) |
| 7 | **View Page (3 modes)** | PSS_2.0_Frontend/src/presentation/components/page-components/case/caselist/case/view-page.tsx |
| 8 | **Zustand Store** | PSS_2.0_Frontend/src/presentation/components/page-components/case/caselist/case/case-store.ts (activeTab + filter state + modal state) |
| 9 | Route Page (exists as stub) | PSS_2.0_Frontend/src/app/[lang]/crm/casemanagement/caselist/page.tsx (**OVERWRITE** the stub "Need to Develop" placeholder) |

### Frontend Sub-components (nested under view-page)

| # | File | Purpose |
|---|------|---------|
| SC1 | `case/case/tabs/notes-tab.tsx` | Notes & Activity feed + inline add-note form |
| SC2 | `case/case/tabs/action-plan-tab.tsx` | CaseActionItem table + add-action-item form |
| SC3 | `case/case/tabs/referrals-tab.tsx` | CaseReferral table + add-referral form with consent |
| SC4 | `case/case/tabs/documents-tab.tsx` | CaseDocument list + upload button (SERVICE_PLACEHOLDER) |
| SC5 | `case/case/tabs/history-tab.tsx` | Timeline from GetCaseHistory |
| SC6 | `case/case/modals/update-status-modal.tsx` | Status transition modal |
| SC7 | `case/case/modals/reassign-modal.tsx` | Reassign-case modal |
| SC8 | `case/case/modals/close-case-modal.tsx` | Close-case modal with Outcome + Summary + Lessons |
| SC9 | `case/case/modals/quick-add-case-modal.tsx` | "+ New Case" quick-add modal (same RHF instance as view-page form) |
| SC10 | `case/case/widgets/case-kpi-widgets.tsx` | 4 KPI card cluster consuming GetCaseSummary |
| SC11 | `case/case/cells/priority-badge.tsx` | Colored priority pill renderer |
| SC12 | `case/case/cells/case-status-badge.tsx` | Colored status pill (incl. derived Overdue variant) |
| SC13 | `case/case/cells/beneficiary-cell.tsx` | Name link + beneficiary-code subtitle |
| SC14 | `case/case/cells/overdue-indicator.tsx` | Date with triangle-exclamation when overdue |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | `CASELIST` operations config (GetAllCasesList, GetCaseById, GetCaseSummary, CreateCase, UpdateCase, DeleteCase, ToggleCase, UpdateCaseStatus, ReassignCase, CloseCase, ReopenCase) + child-entity operations for CaseNote/CaseActionItem/CaseReferral/CaseDocument |
| 2 | operations-config.ts | Import + register all CASELIST operations |
| 3 | Sidebar menu config | CASELIST menu entry under CRM_CASEMANAGEMENT (OrderBy=3) — likely auto-picked from seed but verify |
| 4 | Cell-renderer registry | Register `priority-badge`, `case-status-badge`, `overdue-indicator` in the 3 column-type registries (shared-cell-renderers barrel export) |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Case List
MenuCode: CASELIST
ParentMenu: CRM_CASEMANAGEMENT
Module: CRM
MenuUrl: crm/casemanagement/caselist
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: CASELIST

MasterDataTypes (NEW — seed 7 types):
  - CASEPRIORITY   — 4 rows: CRITICAL(#dc2626)/HIGH(#ea580c)/MEDIUM(#ca8a04)/LOW(#16a34a)
  - CASESTATUS     — 5 rows: OPEN(#16a34a)/INPROGRESS(#2563eb)/PENDING(#d97706)/RESOLVED(#059669)/CLOSED(#64748b)
  - CASECATEGORY   — 10 rows: EDUCATIONALSUPPORT/MEDICAL/HOUSING/LEGAL/NUTRITION/PROTECTION/PSYCHOSOCIAL/LIVELIHOOD/REFERRAL/OTHER
  - CASENOTETYPE   — 8 rows: CASENOTE/HOMEVISIT/PHONECALL/SERVICEDELIVERED/REFERRALUPDATE/MILESTONE/STATUSCHANGE/CASEOPENED
  - CASEACTIONSTATUS — 5 rows: DONE/RECURRING/PENDING/INPROGRESS/CONTINGENT
  - CASEREFERRALSTATUS — 4 rows: PENDING/AWAITINGRESPONSE/ACCEPTED/REJECTED/COMPLETED
  - CASEOUTCOME    — 6 rows: RESOLVED/PARTIALLYRESOLVED/UNRESOLVED/REFERREDOUT/GRADUATED/BENEFICIARYEXITED
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `CaseQueries` (+ `CaseNoteQueries`, `CaseActionItemQueries`, `CaseReferralQueries`, `CaseDocumentQueries`)
- Mutation type: `CaseMutations` (+ child mutations)

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAllCasesList | PaginatedApiResponse<[CaseResponseDto]> | searchText, pageNo, pageSize, sortField, sortDir, isActive, statusId, priorityId, programId, assignedStaffId, branchId, myCasesOnly (bool — filters AssignedStaffId=currentStaff), dateRange (overdue/thisWeek/thisMonth) |
| GetCaseById | BaseApiResponse<CaseResponseDto> | caseId |
| GetCaseSummary | BaseApiResponse<CaseSummaryDto> | — |
| GetCaseHistory | BaseApiResponse<[CaseHistoryEventDto]> | caseId |
| GetAllCaseNotesList | PaginatedApiResponse<[CaseNoteResponseDto]> | caseId, pageNo, pageSize |
| GetAllCaseActionItemsList | PaginatedApiResponse<[CaseActionItemResponseDto]> | caseId |
| GetAllCaseReferralsList | PaginatedApiResponse<[CaseReferralResponseDto]> | caseId |
| GetAllCaseDocumentsList | PaginatedApiResponse<[CaseDocumentResponseDto]> | caseId |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateCase | CaseRequestDto | int (newId) |
| UpdateCase | CaseRequestDto | int |
| DeleteCase | caseId | int |
| ToggleCase | caseId | int |
| UpdateCaseStatus | UpdateCaseStatusRequestDto { caseId, newStatusId, noteContent? } | int |
| ReassignCase | ReassignCaseRequestDto { caseId, newStaffId, noteContent? } | int |
| CloseCase | CloseCaseRequestDto { caseId, outcomeId, closureSummary, closureFollowUpDate?, lessonsLearned? } | int |
| ReopenCase | caseId | int |
| CreateCaseNote | CaseNoteRequestDto | int |
| UpdateCaseNote | CaseNoteRequestDto | int |
| DeleteCaseNote | caseNoteId | int |
| CreateCaseActionItem | CaseActionItemRequestDto | int |
| UpdateCaseActionItem | CaseActionItemRequestDto | int |
| DeleteCaseActionItem | caseActionItemId | int |
| CreateCaseReferral | CaseReferralRequestDto | int |
| UpdateCaseReferral | CaseReferralRequestDto | int |
| DeleteCaseReferral | caseReferralId | int |
| CreateCaseDocument | CaseDocumentRequestDto | int (SERVICE_PLACEHOLDER — handler accepts metadata; real upload deferred) |
| DeleteCaseDocument | caseDocumentId | int |

**Response DTO Fields — CaseResponseDto**:

| Field | Type | Notes |
|-------|------|-------|
| caseId | number | PK |
| caseCode | string | `CASE-NNNN` |
| caseTitle | string | — |
| description | string | — |
| beneficiaryId | number | FK |
| beneficiaryName | string | Projected from Beneficiary |
| beneficiaryCode | string | Projected (e.g., BEN-001) |
| programId | number \| null | — |
| programName | string \| null | Projected |
| priorityId | number | — |
| priorityName | string | Projected from MasterData (CASEPRIORITY) |
| priorityColorHex | string | From MasterData.ColorHex |
| categoryId | number \| null | — |
| categoryName | string \| null | Projected |
| statusId | number | — |
| statusName | string | e.g., "Open" |
| statusColorHex | string | From MasterData.ColorHex |
| isOverdue | boolean | **DERIVED** — computed in query, NOT stored |
| assignedStaffId | number | — |
| assignedStaffName | string | Projected |
| branchId | number \| null | — |
| branchName | string \| null | Projected |
| openedDate | string (ISO date) | — |
| followUpDate | string (ISO date) \| null | — |
| isExternalReferral | boolean | — |
| referralTo | string \| null | — |
| referralNotes | string \| null | — |
| closedDate | string (ISO date) \| null | — |
| caseOutcomeId | number \| null | — |
| caseOutcomeName | string \| null | Projected |
| closureSummary | string \| null | — |
| closureFollowUpDate | string (ISO date) \| null | — |
| lessonsLearned | string \| null | — |
| isActive | boolean | Inherited |

**Response DTO — CaseSummaryDto**:

```ts
{
  openCasesCount: number;
  openCriticalCount: number;
  openHighCount: number;
  openMediumCount: number;
  openLowCount: number;
  overdueFollowUpsCount: number;
  oldestOverdueDays: number;
  closedThisMonthCount: number;
  avgResolutionDays: number;
  referralsPendingCount: number;
}
```

**Response DTO — CaseHistoryEventDto**:

```ts
{
  eventDate: string (ISO date);
  eventType: string; // "note-added" | "status-changed" | "action-done" | "case-opened" | "case-closed" | "reassigned" | etc.
  eventText: string; // ready-to-display sentence ("Note added by Ahmed Salim", "Status changed Open → In Progress")
  actorStaffId: number | null;
  actorStaffName: string | null;
}
```

**Response DTO — CaseNoteResponseDto**:

```ts
{
  caseNoteId, caseId, noteTypeId, noteTypeName, noteTypeColorHex,
  content, followUpDate, notifySupervisor,
  authorStaffId, authorStaffName, authorAvatarInitials,
  attachmentUrl, attachmentName,
  createdDate, isActive
}
```

(similar shape for CaseActionItemResponseDto, CaseReferralResponseDto, CaseDocumentResponseDto — include all entity fields + projected FK display names + author/responsible staff names)

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (new `case` schema + 5 entity configurations + 4 workflow commands + 2 summary queries compile)
- [ ] Migration applies cleanly: `case` schema created + 5 tables + all FKs wired (no orphan FK constraints — Beneficiary #49 + Program #51 must be built first)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/casemanagement/caselist`

**Functional Verification (Full E2E — MANDATORY):**

Grid page:
- [ ] Grid loads with 10 columns + row-overdue red-tint styling when `isOverdue=true`
- [ ] 4 KPI widgets show correct values: openCases (with priority sub-breakdown), overdueFollowUps (with oldest), closedThisMonth (with avg days), referralsPending
- [ ] Filter chips update grid in real-time (Status + Priority — independent filter groups)
- [ ] Program / Staff / Branch / Date selects filter correctly
- [ ] "My Cases" toggle filters to current user's staff record
- [ ] Search by case code, beneficiary name, title, description all work
- [ ] 3-dot row menu: View / Edit / Add Note / Reassign / Escalate / Close Case — each opens correct UI
- [ ] Bulk select + Reassign → updates all selected; Export → CSV/Excel download; Send Reminders → toast (SERVICE_PLACEHOLDER)

Form (new/edit):
- [ ] `?mode=new` — empty FORM renders all 10 fields + conditional referral sub-form
- [ ] External referral checkbox toggles ReferralTo/ReferralNotes visibility
- [ ] Save creates record with StatusId=Open, OpenedDate=today, auto CaseCode → redirects to `?mode=read&id={newId}`
- [ ] `?mode=edit&id=X` — FORM pre-filled correctly
- [ ] Save in edit mode updates record → returns to `?mode=read&id={id}`
- [ ] Validation: required fields flagged; IsExternalReferral=true without ReferralTo blocks submit

Detail page (read):
- [ ] Summary card renders all meta (Case ID, Beneficiary, Program, Priority badge, Status badge, Assigned, Dates)
- [ ] Breadcrumb navigates back to list
- [ ] Beneficiary link → navigates to `/[lang]/crm/casemanagement/beneficiarylist?mode=read&id={beneficiaryId}` (once #49 built)
- [ ] Assigned staff link → navigates to staff detail
- [ ] Tab: Notes — loads CaseNotes chronologically, shows avatars + type badges + attachments; inline add-note form creates note, refreshes feed; NotifySupervisor=true shows toast (SERVICE_PLACEHOLDER)
- [ ] Tab: Action Plan — loads CaseActionItems sorted by ActionSequence; inline add-action-item form creates item; IsRecurring=true hides TargetDate
- [ ] Tab: Referrals — loads CaseReferrals with status badges; inline add-referral form creates referral; Send button disabled until Consent checked
- [ ] Tab: Documents — loads CaseDocuments; Upload button shows SERVICE_PLACEHOLDER toast
- [ ] Tab: History — loads GetCaseHistory timeline correctly
- [ ] Header: Update Status modal transitions StatusId + writes audit CaseNote
- [ ] Header: Reassign modal updates AssignedStaffId + writes audit CaseNote
- [ ] Header: Close Case modal — Outcome + Summary required; ClosureFollowUpDate shows only when toggle on; submit sets StatusId=Closed + ClosedDate + CaseOutcomeId + ClosureSummary
- [ ] Header: More → Print/ExportPDF/Share/Archive all show toast (SERVICE_PLACEHOLDER)

General:
- [ ] FK dropdowns load via ApiSelectV2 (Beneficiary, Program, Staff, Branch, MasterData lookups)
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] Permissions: Edit/Delete buttons respect BUSINESSADMIN capabilities

**DB Seed Verification:**
- [ ] CASELIST menu appears in sidebar under CRM_CASEMANAGEMENT @ OrderBy=3
- [ ] 7 MasterDataType seed rows created (CASEPRIORITY/CASESTATUS/CASECATEGORY/CASENOTETYPE/CASEACTIONSTATUS/CASEREFERRALSTATUS/CASEOUTCOME) with correct codes + colors
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** in Case (or any child entity) — it comes from HttpContext in FLOW screens.
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it. The +Add modal form schema is code-driven via React Hook Form.
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout, read has the tabbed DETAIL layout.
- **DETAIL layout is a separate UI with 5 tabs + action bar**, NOT the form disabled — do NOT wrap the form in fieldset.
- **Layout Variant = widgets-above-grid** → FE Dev MUST use **Variant B** on the index page: `<ScreenHeader>` + 4 KPI widgets + `<DataTableContainer showHeader={false}>` (Contact Type #19 / Auction Management #48 precedent — missing this = duplicate headers bug).

### NEW module warnings

- **`case` schema is NEW** — not yet created in any migration. The schema is expected to be initialized by **Program #51** (Wave 1 Master table). If #51 is not yet built when #50 is built, the migration MUST include `MIGRATION_BUILDER.EnsureSchema("case")` as the first step.
- **Per-module DbContext decision**: Check whether the codebase uses a per-module DbContext (like `DonationDbContext`, `NotifyDbContext`) or a single `ApplicationDbContext`. If per-module → create `CaseDbContext.cs`. If single → just add DbSets to `ApplicationDbContext`. Mirror the DonationModels wiring pattern.
- **CaseModels group** is new — add `DecoratorCaseModules` entry in `DecoratorProperties.cs`, add `CaseMappings.cs` for Mapster configs, register in Startup/Program DI.
- **FE folder**: use `case-service` (singular — matches `notify-service`, `contact-service` convention); the FE route path is `crm/casemanagement/caselist` (compound menu URL — NOT `crm/case/...`).

### Dependency chain (HARD)

Build order for the `case` schema MUST be:
1. **#51 Program** (Wave 1 — creates `case` schema + `Programs` table)
2. **#49 Beneficiary** (Wave 2 — adds `Beneficiaries` table + FK to Programs if applicable)
3. **#50 Case** (this prompt — Wave 3 — adds `Cases` + 4 child tables + FKs to Beneficiaries, Programs)

`/build-screen #50` will fail at migration if Beneficiary or Program is not yet built. Verify COMPLETED status of #49 and #51 before starting build. If user wants to build out-of-order, **stop and ask** — do not stub FK columns as nullable to sidestep the dependency (creates data-integrity risk).

### C# reserved keyword: `case`

- Entity class name is `Case` (title-case, not reserved — valid).
- DbSet property name is `Cases` (plural, not reserved).
- Do NOT use `var case = ...` in handlers — it's a parse error. Use `var caseEntity`, `var caseRecord`, or `var existingCase`.
- Namespace `CaseModels` / `CaseBusiness` / `CaseSchemas` is all fine (no reserved-word issue).

### Overdue is DERIVED (NOT stored)

- Do NOT seed `OVERDUE` as a CASESTATUS value.
- Overdue badge + row-tint comes from: `StatusId IN (Open, InProgress, Pending) AND FollowUpDate < today`.
- The derivation happens in `GetAllCasesList` projection (LINQ) → `isOverdue: bool` on DTO.
- Frontend uses `isOverdue` to apply `row-overdue` CSS class and the "Overdue" badge variant; the underlying StatusId remains whatever it actually is (Open/InProgress/Pending).

### Scope Guidance

- **Build everything in the mockup (GOLDEN RULE)**. All 5 tabs, all 4 KPI widgets, all 3 action modals, all child-entity inline add-forms, all 10 grid columns, filter chips, bulk actions bar, row-overdue styling, beneficiary/staff link navigation — IN SCOPE.
- This is a high-complexity screen — estimate 3-5 build sessions (BE + FE + seed + polish).
- ALIGN does NOT apply here — scope is FULL FE+BE since only a placeholder stub exists.

### Service Dependencies (UI-only — no backend service implementation)

Everything shown in the mockup is in scope. The items below require external services/infrastructure that don't exist in the codebase yet — build the full UI but wire handlers to mock/toast:

- ⚠ **SERVICE_PLACEHOLDER: File uploads (all attachments)** — CaseNote attachments, CaseDocument uploads, CaseReferral documents-shared. UI: drop-zone + file picker + file-list renders. Handler: accepts metadata only (FileName, FileSizeBytes, MimeType, a placeholder FilePathUrl) and shows toast "File storage will be wired when upload service is deployed."
- ⚠ **SERVICE_PLACEHOLDER: NotifySupervisor on CaseNote** — checkbox renders; on submit, handler shows toast "Supervisor notification queued (SMS/email pipeline pending)."
- ⚠ **SERVICE_PLACEHOLDER: Send Reminders (bulk action)** — UI button exists; handler shows toast "Reminder notifications will be sent once notification pipeline is live."
- ⚠ **SERVICE_PLACEHOLDER: Print Case / Export PDF / Share / Archive (header More menu)** — menu entries render; handlers toast "Feature coming soon (PDF generation / sharing pipeline pending)."
- ⚠ **SERVICE_PLACEHOLDER: Escalate (row action)** — UI only; handler toast "Escalation workflow pending."
- ⚠ **SERVICE_PLACEHOLDER: "Follow Up" button on CaseReferral rows** — opens a placeholder modal that renders "Follow up via email/phone — handler pending."

Full UI must be built (buttons, forms, modals, panels, interactions). Only the handler for the external service call is mocked.

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

{No sessions recorded yet — filled in after /build-screen completes.}