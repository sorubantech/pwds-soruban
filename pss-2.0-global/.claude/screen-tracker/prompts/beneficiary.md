---
screen: Beneficiary
registry_id: 49
module: Case Management (CRM)
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: YES — `case` schema (already bootstrapped by Program #51)
planned_date: 2026-04-21
completed_date: 2026-04-24
last_session_date: 2026-04-24
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — 3 files (beneficiary-list.html / -form.html / -detail.html)
- [x] Existing code reviewed (FE stub `crm/casemanagement/beneficiarylist/page.tsx` = 5-line placeholder; NO BE entity; NO `case` schema)
- [x] Business rules + 7-section form + 6-tab DETAIL extracted
- [x] FK targets resolved (Contact, Staff, Branch + Gender/Nationality/Relation/Language/PriorityLevel/Vulnerability/etc. via MasterData). Program FK build-order dependency flagged (ISSUE-1 — build #51 first)
- [x] File manifest computed (6 entities — 1 parent + 5 children). Case schema bootstrap owned by Program #51 (extend-existing path) OR by Beneficiary (full-bootstrap fallback path).
- [x] Approval config pre-filled (BENEFICIARYLIST @ OrderBy=1 under CRM_CASEMANAGEMENT; BENEFICIARYFORM treated as hidden-child legacy menu)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (pre-analyzed via prompt; no re-analysis — token budget)
- [x] Solution Resolution complete (case schema REUSED from Program #51; 6 new entities added)
- [x] UX Design finalized (FORM 7 accordion sections + DETAIL 6 tabs + 4 KPI widgets + 7 chips + advanced filter panel + bulk bar)
- [x] User Approval received (pre-approved via CONFIG block §⑨ — user directive: no repeated yes/no)
- [x] Backend code generated — Beneficiary parent + 5 child entities (EF migration SKIPPED per user directive)
- [x] Backend wiring complete (ICaseDbContext / CaseDbContext DbSets; CaseMappings; DecoratorCaseModules)
- [x] Frontend code generated (view-page 3 modes + Zustand store + 6 detail tabs + KPI widgets + filter chips + advanced filter panel + bulk bar + 4 custom renderers)
- [x] Frontend wiring complete (entity-operations, component-columns × 3 registries, shared-cell-renderers barrel, sidebar menu, route stub overwritten)
- [x] DB Seed script generated (Beneficiary-sqlscripts.sql — Menu + caps + FLOW Grid + 10 GridFields + 17 MasterData seeds)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (new case schema + 6 entities; migration applies; case.Beneficiaries + 5 child tables + case.Programs exist; FKs indexed)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/casemanagement/beneficiarylist`
- [ ] 4 KPI widgets render: Total Beneficiaries (with Active/Graduated/Inactive sub-breakdown), Programs Active (count + top-3 names), New This Month (count + MoM trend %), Outcomes Achieved (milestones count)
- [ ] Grid loads with 10 columns (checkbox + BenId link + Name-with-avatar-and-subline + Age + Gender + Programs badge-list + Location + Sponsor link OR "Pool funded" italic + Status badge + Enrolled month/year + Actions cluster)
- [ ] 7 filter chips work (All/Active/Waitlist/Graduated/Exited/Suspended/Deceased)
- [ ] Advanced filter panel toggles; filters: Program / AgeGroup / Gender / Location / Branch / AssignedStaff; Apply + Clear buttons
- [ ] Bulk-select checkbox shows bulk bar with Export / Assign Staff / Send Communication (2 SERVICE_PLACEHOLDERs — toast)
- [ ] Actions dropdown per row: View / Edit / Add to Program / Create Case / Add Note / Generate Report / Archive (Create Case navigates to `/[lang]/crm/casemanagement/caselist?mode=new&beneficiaryId={id}` — SERVICE_PLACEHOLDER if Case #50 not built)
- [ ] Waitlist-status row shows inline "Enroll" quick-action button (promotes status → Active on click)
- [ ] `?mode=new` — empty FORM renders 7 accordion sections (all expanded by default); sections: Personal Info → Location & Contact → Family/Household → Needs Assessment → Program Enrollment → Consent & Documents → Internal
- [ ] Family/Household section has inline child-grid for Household Members (Name / Age / Gender / Relationship / AlsoBeneficiary checkbox with BEN-XXX auto-link) + Add Row / Remove Row buttons
- [ ] Program Enrollment section shows auto-suggested eligibility cards (derived client-side from Assessment fields: age / gender / orphan-status / income-level / education-status) with toggle + "Enroll Now" vs "Add to Waitlist" dropdown per card
- [ ] Sponsorship Type = Individual → shows Sponsor Contact picker (ApiSelectV2 `contacts`); Pool Funded / Self-funded → hides picker
- [ ] 3 header action buttons: "Register Beneficiary" (primary Save) / "Register & Add Another" (save + reset form) / "Save as Draft" (status=Draft)
- [ ] Save creates Beneficiary + child collections (household, programs, milestones if any, documents if any) atomically → URL redirects to `?mode=read&id={newId}` → DETAIL layout
- [ ] `?mode=edit&id=X` — FORM pre-filled with existing data across all 7 sections
- [ ] `?mode=read&id=X` — DETAIL layout renders: header (avatar + name + BEN-id + status pill + age + since + location + sponsor link), 5 Quick-Stat cards (Programs / Active Cases / Services Received / Sponsor / Outcome Score), 3 header actions (Edit / Add to Program / More dropdown with Create Case / Generate Report / Export / Print), 6 tabs
- [ ] Tab Overview: 2 side-by-side cards (Personal Info info-list 11 rows + Needs Assessment Summary info-list 7 rows + Tags badge-list)
- [ ] Tab Programs & Services: 3 stacked cards (Enrolled Programs mini-grid, Service History mini-grid, Milestones mini-grid)
- [ ] Tab Cases: 1 card with Cases mini-grid (links to Case #50 — SERVICE_PLACEHOLDER if not built — empty state with "No cases yet")
- [ ] Tab Sponsorship: 2 side-by-side cards (Sponsorship Details + Payment History mini-grid — SERVICE_PLACEHOLDER if sponsorship domain absent)
- [ ] Tab Documents: responsive doc-grid (icon + name + date per tile) + Upload button (SERVICE_PLACEHOLDER if file-upload infra not wired — stores metadata only with URL input)
- [ ] Tab Timeline: vertical timeline aggregating all events (programs, services, cases, documents, payments, milestones) with color-coded dots
- [ ] FK dropdowns load via ApiSelectV2: Contact, Staff, Branch + MasterData typeCodes (Gender/Nationality/Relation/VulnerabilityLevel/IncomeLevel/etc.)
- [ ] Country → State → City → Locality cascade works on Location section (ApiSelectV2 parent-arg filter)
- [ ] Unsaved changes dialog triggers on dirty FORM navigation
- [ ] Permissions: Edit/Delete/Archive respect role capabilities
- [ ] DB Seed — menu "Beneficiary List" visible in sidebar under Case Management at OrderBy=1; MasterData types + values seeded; initial case.Programs seeded if Program co-created

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Beneficiary
Module: Case Management (CRM)
Schema: case (NEW — first entity in this schema)
Group: CaseModels (NEW — first group in this namespace)

Business: A **Beneficiary** is any individual (or family member) enrolled in one or more of the NGO's programs and receiving services — orphans in sponsorship, students in education programs, women in empowerment tracks, families in food-distribution rounds, etc. This screen is the **operational heart of Case Management**: case workers, program officers, and field staff use it every day to register new intakes, assess needs, enroll beneficiaries into eligible programs, track sponsorship linkage, log services delivered, record milestone achievements, and maintain a complete timeline of the person's journey through the NGO. Each beneficiary ties to ZERO-or-ONE sponsor Contact (or is "Pool funded"), belongs to a Branch, has an assigned Staff worker, and participates in MANY Programs via an enrollment junction. The list grid gives leadership a real-time roll-up (active/waitlisted/graduated breakdown, monthly intake trend, outcome achievements), while the detail view aggregates everything the NGO knows about the person across 6 tabs — so staff can answer "how is BEN-001 doing?" without leaving the page. This screen sits at the top of the Case Management module (`crm/casemanagement/beneficiarylist` @ OrderBy=1) and is the parent for Case (#50) — cases are opened ON beneficiaries.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **SIX entities total**: parent `Beneficiary` + 5 children (HouseholdMember / ProgramEnrollment / Milestone / ServiceLog / Document).
> Audit columns (CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive, IsDeleted) inherited from `Entity` base — omitted from tables below.
> **CompanyId is NOT a field** on any entity — resolved from `HttpContext` on Create/Update mutations.

### Parent Table: `case."Beneficiaries"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| BeneficiaryId | int | — | PK | — | Primary key |
| BeneficiaryCode | string | 30 | YES | — | Auto-gen `BEN-{0001}` (4-digit padded, per-Company sequence) on Create when empty; unique-filtered per Company |
| **Personal Information (form §1)** | | | | | |
| FirstName | string | 100 | YES | — | Given name |
| LastName | string | 100 | YES | — | Family/surname |
| DateOfBirth | DateTime? | — | NO | — | Nullable when unknown — see `ApproximateAge` fallback |
| ApproximateAge | int? | — | NO | — | Used when DOB unknown (0–120) |
| GenderId | int | — | YES | shared.MasterData (GENDER) | Male / Female / Other |
| NationalityId | int? | — | NO | shared.MasterData (NATIONALITY) | Somali / Indian / Kenyan / … |
| NationalIdNumber | string | 50 | NO | — | ID number if available |
| Languages | string | 200 | NO | — | CSV display (e.g., "Arabic, Somali, English") |
| PhotoUrl | string | 500 | NO | — | Uploaded photo URL — SERVICE_PLACEHOLDER handler if upload infra absent |
| **Location & Contact (form §2)** | | | | | |
| CountryId | int | — | YES | shared.Countries | — |
| StateId | int? | — | NO | shared.States | Cascading |
| CityId | int? | — | NO | shared.Cities | Cascading |
| LocalityId | int? | — | NO | shared.Localities | Cascading (Area/Neighbourhood) |
| AddressDetails | string | 500 | NO | — | Free-text address lines |
| GpsCoordinates | string | 100 | NO | — | "lat,lng" string (auto-capture or manual) |
| Phone | string | 30 | NO | — | Beneficiary or guardian phone |
| AlternativeContactName | string | 100 | NO | — | — |
| AlternativePhone | string | 30 | NO | — | — |
| **Family / Household (form §3)** | | | | | |
| HouseholdHeadName | string | 200 | NO | — | Free-text (e.g., "Halima Hassan (mother)") |
| RelationshipToHeadId | int? | — | NO | shared.MasterData (RELATION) | Self/Son-Daughter/Spouse/… |
| HouseholdSize | int | — | YES | — | ≥ 1 |
| OrphanStatusId | int? | — | NO | shared.MasterData (ORPHANSTATUS) | NotOrphan / SingleOrphan / DoubleOrphan / Unknown |
| GuardianName | string | 200 | NO | — | Required if beneficiary is minor |
| GuardianRelationId | int? | — | NO | shared.MasterData (RELATION) | Mother/Father/Uncle/… |
| GuardianPhone | string | 30 | NO | — | — |
| **Needs Assessment (form §4)** | | | | | |
| PrimaryNeedCategoryId | int | — | YES | shared.MasterData (PRIMARYNEEDCATEGORY) | Education / Healthcare / Nutrition / Shelter / Livelihood / Protection / CleanWater / Psychosocial / Multiple |
| VulnerabilityLevelId | int | — | YES | shared.MasterData (VULNERABILITYLEVEL) | Critical / High / Medium / Low |
| IncomeLevelId | int? | — | NO | shared.MasterData (INCOMELEVEL) | NoIncome / BelowPoverty / LowIncome / Moderate / Adequate |
| EducationStatusId | int? | — | NO | shared.MasterData (EDUCATIONSTATUS) | NotEnrolled / Enrolled / DroppedOut / Completed / NotApplicable |
| EducationGrade | string | 50 | NO | — | Free-text (e.g., "Grade 2") |
| SchoolName | string | 200 | NO | — | — |
| GeneralHealthId | int? | — | NO | shared.MasterData (GENERALHEALTH) | Good / Fair / Poor / Critical / Unknown |
| Disabilities | string | 300 | NO | — | CSV (None/Physical/Visual/Hearing/Cognitive/Other) — multiselect persisted as CSV |
| ChronicConditions | string | 500 | NO | — | Free-text |
| LastCheckupDate | DateTime? | — | NO | — | — |
| HousingTypeId | int? | — | NO | shared.MasterData (HOUSINGTYPE) | Owned / Rented / Shelter / Homeless / Temporary / Other |
| HousingConditionId | int? | — | NO | shared.MasterData (HOUSINGCONDITION) | Good / Fair / Poor / Unsafe |
| SpecialNeedsNotes | string | 2000 | NO | — | Free-text — Section 4 catch-all |
| **Program Enrollment (form §5) — core assignment fields** | | | | | |
| AssignedStaffId | int? | — | NO | app.Staffs | Primary case worker |
| SponsorshipTypeId | int? | — | NO | shared.MasterData (SPONSORSHIPTYPE) | IndividualSponsor / PoolFunded / SelfFunded |
| SponsorContactId | int? | — | NO | cont.Contacts | Only when SponsorshipType=IndividualSponsor |
| SponsorshipAmount | decimal(18,2)? | — | NO | — | Monthly pledge amount — SERVICE_PLACEHOLDER until recurring linkage wired |
| SponsorshipStartDate | DateTime? | — | NO | — | First pledge date |
| **Consent & Documents (form §6)** | | | | | |
| PhotoConsent | bool | — | YES | — | Default false; stamped on save |
| DataConsent | bool | — | YES | — | Default false; stamped on save |
| ConsentFormUrl | string | 500 | NO | — | URL of signed consent form |
| **Internal (form §7)** | | | | | |
| ReferralSourceId | int? | — | NO | shared.MasterData (REFERRALSOURCE) | CommunityLeader / SelfReferral / GovAgency / OtherNGO / FieldStaff / Other |
| ReferralSourceName | string | 200 | NO | — | Free-text referrer name |
| BranchId | int | — | YES | app.Branches | Required — mandatory in form |
| PriorityId | int? | — | NO | shared.MasterData (VULNERABILITYLEVEL) | Reuses VULNERABILITYLEVEL dataset; auto-suggested from Assessment |
| InternalNotes | string | 2000 | NO | — | Free-text — not visible to sponsors |
| **Status / Workflow** | | | | | |
| BeneficiaryStatusId | int | — | YES | shared.MasterData (BENEFICIARYSTATUS) | Draft / Active / Waitlist / Graduated / Exited / Suspended / Deceased — default Active on final submit, Draft on "Save as Draft" |
| EnrollmentDate | DateTime | — | YES | — | Defaults to `today` on Create; displayed as "Enrolled" column in grid |
| ExitDate | DateTime? | — | NO | — | Set when status transitions to Graduated / Exited / Deceased |
| ExitReason | string | 500 | NO | — | — |
| OutcomeScore | int? | — | NO | — | 0–100 computed score — SERVICE_PLACEHOLDER (stub formula: `milestones_achieved / milestones_total × 100`) |

**Computed/projected fields** (added in BE GetAll + GetById projections — NOT new columns):
- `displayName` — `FirstName + ' ' + LastName`
- `avatarColor` — deterministic hash of `BeneficiaryCode` → 8-color palette (same scheme as Contact)
- `ageYears` — `DOB != null ? floor((today − DOB)/365.25) : ApproximateAge`
- `ageGroupCode` — derived bucket: 0-5 / 6-12 / 13-17 / 18-25 / 26-40 / 41-60 / 60+
- `locationDisplay` — `CityName + ', ' + CountryName` (or State fallback)
- `programNames[]` — array of ProgramName strings from BeneficiaryProgramEnrollment (where EnrollmentStatusCode = Enrolled)
- `programCodes[]` — array of ProgramCode strings (for grid badge rendering with color-by-value)
- `programsCount` — count of active enrollments
- `activeCasesCount` — SUBQUERY COUNT of case.Cases WHERE BeneficiaryId = this.Id AND CaseStatusCode IN ('Open','InProgress') — SERVICE_PLACEHOLDER (Case #50 not built) → returns 0 via guarded projection
- `servicesReceivedThisYear` — SUBQUERY COUNT of BeneficiaryServiceLogs WHERE BeneficiaryId = this.Id AND ServiceDate >= year-start
- `sponsorName`, `sponsorCode` — Contact join (null when SponsorshipType ≠ IndividualSponsor — grid renders "Pool funded" italic fallback)
- `guardianDisplayName` — `GuardianName + ' (' + GuardianRelationName + ')'`
- `branchName`, `assignedStaffName`, `nationalityName`, `genderName` — FK display joins
- `statusCode`, `statusName`, `statusColorHex` — MasterData projection of BeneficiaryStatus (for chip/badge)
- `householdMembers[]` — nested DTO list (Name/Age/Gender/Relation/LinkedBeneficiaryId)
- `programEnrollments[]` — nested DTO list (ProgramId/ProgramName/ProgramCode/EnrolledOn/EnrollmentStatusCode/AssignedStaffId/Services/NextAction)
- `milestones[]` — nested DTO list (MilestoneTitle/Target/Achieved/AchievedDate/EvidenceUrl/StatusCode)
- `serviceLogs[]` — nested DTO list (ServiceDate/ProgramId/Description/Provider/Notes) — top 20 recent
- `documents[]` — nested DTO list (Name/IconCode/UploadedOn/DocumentUrl)
- `tags[]` — derived flags: `Orphan`, `School-age`, `Sponsored`, `{CountryName}`, `{VulnerabilityLevelName}` (computed server-side for Overview tag-list)

### Child Table: `case."BeneficiaryHouseholdMembers"` (1:Many)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| BeneficiaryHouseholdMemberId | int | — | PK | — | — |
| BeneficiaryId | int | — | YES | case.Beneficiaries | CASCADE delete with parent |
| MemberName | string | 200 | YES | — | — |
| Age | int? | — | NO | — | — |
| GenderId | int? | — | NO | shared.MasterData (GENDER) | M/F/Other |
| RelationshipName | string | 100 | NO | — | Free-text (e.g., "Mother", "Sister") |
| RelationId | int? | — | NO | shared.MasterData (RELATION) | Optional picker when free-text is resolved |
| IsAlsoBeneficiary | bool | — | YES | — | If true and LinkedBeneficiaryId is set, UI shows BEN-XXX badge |
| LinkedBeneficiaryId | int? | — | NO | case.Beneficiaries | Self-referencing FK (sibling linkage) |
| DisplayOrder | int | — | YES | — | Sort order within the household |

### Child Table: `case."BeneficiaryProgramEnrollments"` (1:Many)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| BeneficiaryProgramEnrollmentId | int | — | PK | — | — |
| BeneficiaryId | int | — | YES | case.Beneficiaries | CASCADE delete |
| ProgramId | int | — | YES | case.Programs | **CO-DEPENDENCY** — see ISSUE-1 (Program #51 must be co-created in same build) |
| EnrolledOn | DateTime | — | YES | — | Defaults to beneficiary's EnrollmentDate |
| EnrollmentStatusId | int | — | YES | shared.MasterData (ENROLLMENTSTATUS) | Enrolled / Waitlisted / Graduated / Exited / Suspended |
| AssignedStaffId | int? | — | NO | app.Staffs | Program-level case worker (may differ from beneficiary-level) |
| ExitReason | string | 500 | NO | — | — |
| ExitDate | DateTime? | — | NO | — | — |
| NextActionDescription | string | 200 | NO | — | e.g., "Check-in: May 1" |
| NextActionDueDate | DateTime? | — | NO | — | — |
| ServicesSummary | string | 500 | NO | — | Free-text (e.g., "Monthly support, quarterly check") |

Unique: composite index `(BeneficiaryId, ProgramId)` filtered `WHERE IsDeleted = 0` — prevents double-enrollment.

### Child Table: `case."BeneficiaryMilestones"` (1:Many)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| BeneficiaryMilestoneId | int | — | PK | — | — |
| BeneficiaryId | int | — | YES | case.Beneficiaries | CASCADE delete |
| ProgramId | int? | — | NO | case.Programs | Optional — cross-program milestone |
| MilestoneTitle | string | 200 | YES | — | e.g., "School enrollment" |
| TargetValue | string | 100 | NO | — | e.g., "Grade 2", "90%" |
| AchievedValue | string | 100 | NO | — | e.g., "Grade 2", "95%" |
| StatusId | int | — | YES | shared.MasterData (MILESTONESTATUS) | Achieved / InProgress / NotAchieved |
| AchievedDate | DateTime? | — | NO | — | — |
| EvidenceUrl | string | 500 | NO | — | Link to document / external evidence — SERVICE_PLACEHOLDER upload |

### Child Table: `case."BeneficiaryServiceLogs"` (1:Many)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| BeneficiaryServiceLogId | int | — | PK | — | — |
| BeneficiaryId | int | — | YES | case.Beneficiaries | CASCADE delete |
| ProgramId | int? | — | NO | case.Programs | Optional — cross-program service |
| ServiceDate | DateTime | — | YES | — | — |
| ServiceDescription | string | 300 | YES | — | e.g., "Tutoring session (2 hours)", "Monthly support payment (AED 1,800)" |
| ProviderStaffId | int? | — | NO | app.Staffs | Staff who provided service; NULL → "Auto" in display |
| ProviderName | string | 200 | NO | — | Fallback when ProviderStaffId is NULL and provider is external |
| Notes | string | 1000 | NO | — | — |
| AmountCents | long? | — | NO | — | Optional amount in cents (e.g., AED 1800 = 180000) — render only when set |

### Child Table: `case."BeneficiaryDocuments"` (1:Many)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| BeneficiaryDocumentId | int | — | PK | — | — |
| BeneficiaryId | int | — | YES | case.Beneficiaries | CASCADE delete |
| DocumentName | string | 200 | YES | — | e.g., "Q1 2026 Photo", "School Report - Grade 2" |
| DocumentTypeCode | string | 30 | NO | — | `Image` / `MedicalReport` / `SchoolReport` / `Consent` / `IdCopy` / `Other` — drives icon |
| DocumentUrl | string | 500 | YES | — | Storage URL — SERVICE_PLACEHOLDER for file-upload pipe; accept URL input directly for now |
| UploadedOn | DateTime | — | YES | — | Default = now on Create |
| UploadedByStaffId | int? | — | NO | app.Staffs | — |
| Description | string | 500 | NO | — | Optional |

### HARD DEPENDENCY — Program entity (#51 Wave 1)

Program entity MUST exist in the `case` schema before Beneficiary can enrol. As of 2026-04-21, Program #51 is `PROMPT_READY` (prompt at `prompts/program.md`) but NOT yet built. `BeneficiaryProgramEnrollment.ProgramId`, `BeneficiaryMilestone.ProgramId`, and `BeneficiaryServiceLog.ProgramId` all FK to `case.Programs`. **Build order recommendation**: run `/build-screen #51` (Program) BEFORE `/build-screen #49` (Beneficiary). This way:
- Program #51 owns and executes the `case` schema new-module bootstrap (ICaseDbContext, CaseDbContext, CaseMappings, DecoratorCaseModules, IApplicationDbContext inheritance, DependencyInjection register, GlobalUsing × 3) — see Program #51 §⑧.
- Program #51 creates the `Program` entity (rich: IconEmoji, ColorHex, CategoryId, StatusId, FundingModel, MaximumCapacity, etc.) + seeds 3-8 sample program rows.
- Beneficiary #49 then reuses the existing bootstrap and adds 5 new entities (Beneficiary + 4 children) to the existing `CaseDbContext` / `CaseMappings` / `DecoratorCaseModules` — treating them as "add-another-entity-to-existing-module" rather than "bootstrap-new-module".

If sessions must run in reverse order (Beneficiary first), this prompt's build-screen MUST execute the full new-module bootstrap AND stand up a minimal Program stub (ProgramId + ProgramCode + ProgramName + ColorHex + ProgramCategoryCode) — then Program #51's build re-aligns the table with a migration adding the richer columns. **This reverse path is more fragile — prefer building #51 first.**

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` + nav properties) + Frontend Developer (for ApiSelectV2 queries)
> NOTE: codebase uses paginated `XXXs` query fields (NOT `GetAllXxxList`). Columns below carry the **actual** HotChocolate field names.

| FK Field | Target Entity | Entity File Path | GQL Query Field | Display Field | GQL Response Type |
|----------|--------------|-------------------|-----------------|---------------|-------------------|
| SponsorContactId | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `contacts(request)` | `displayName` | `ContactResponseDto` |
| AssignedStaffId / ProviderStaffId / UploadedByStaffId | Staff | `Base.Domain/Models/ApplicationModels/Staff.cs` | `staffs(request)` | `staffName` | `StaffResponseDto` |
| BranchId | Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | `branches(request)` | `branchName` | `BranchResponseDto` |
| CountryId | Country | `Base.Domain/Models/SharedModels/Country.cs` | `countries(request)` | `countryName` | `CountryResponseDto` |
| StateId | State | `Base.Domain/Models/SharedModels/State.cs` | `states(request)` | `stateName` | `StateResponseDto` (cascade filter: `countryId`) |
| CityId | City | `Base.Domain/Models/SharedModels/City.cs` | `cities(request)` | `cityName` | `CityResponseDto` (cascade filter: `stateId`) |
| LocalityId | Locality | `Base.Domain/Models/SharedModels/Locality.cs` | `localities(request)` | `localityName` | `LocalityResponseDto` (cascade filter: `cityId`) |
| GenderId / NationalityId / RelationshipToHeadId / GuardianRelationId / OrphanStatusId / PrimaryNeedCategoryId / VulnerabilityLevelId / IncomeLevelId / EducationStatusId / GeneralHealthId / HousingTypeId / HousingConditionId / SponsorshipTypeId / ReferralSourceId / PriorityId / BeneficiaryStatusId / (child) EnrollmentStatusId / MilestoneStatusId | MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | `masterDatas(request, staticFilter: "{TYPECODE}")` | `dataName` | `MasterDataResponseDto` |
| ProgramId | Program | `Base.Domain/Models/CaseModels/Program.cs` (NEW — owned by Program #51; build #51 FIRST — see ISSUE-1) | `programs(request)` | `programName` | `ProgramResponseDto` (owned by #51) |
| LinkedBeneficiaryId | Beneficiary (self-ref) | `Base.Domain/Models/CaseModels/Beneficiary.cs` | `beneficiaries(request)` | `displayName` | `BeneficiaryResponseDto` |

**MasterData TypeCodes required** (seed in DB setup — see §⑧ seed file):

| TypeCode | Purpose | Minimum Values |
|----------|---------|----------------|
| `GENDER` | Existing — verify seeded | Male, Female, Other |
| `NATIONALITY` | Existing or seed if absent | Somali, Indian, Kenyan, Bangladeshi, Pakistani, Afghan, Yemeni, Syrian, Other |
| `RELATION` | Existing — verify | Self, Son/Daughter, Spouse, Sibling, Grandchild, Mother, Father, Uncle/Aunt, Grandparent, Other |
| `ORPHANSTATUS` | NEW | NotOrphan (NOT), SingleOrphan (SGL), DoubleOrphan (DBL), Unknown (UNK) |
| `PRIMARYNEEDCATEGORY` | NEW | Education (EDU), Healthcare (HEL), Nutrition (NUT), Shelter (SHL), Livelihood (LIV), Protection (PRO), CleanWater (WAT), Psychosocial (PSY), Multiple (MUL) |
| `VULNERABILITYLEVEL` | NEW (reused for Priority field too) | Critical (CRT #dc2626), High (HGH #f59e0b), Medium (MED #fbbf24), Low (LOW #22c55e) — include ColorHex |
| `INCOMELEVEL` | NEW | NoIncome, BelowPoverty, LowIncome, Moderate, Adequate |
| `EDUCATIONSTATUS` | NEW | NotEnrolled, Enrolled, DroppedOut, Completed, NotApplicable |
| `GENERALHEALTH` | NEW | Good, Fair, Poor, Critical, Unknown |
| `HOUSINGTYPE` | NEW | Owned, Rented, Shelter, Homeless, Temporary, Other |
| `HOUSINGCONDITION` | NEW | Good, Fair, Poor, Unsafe |
| `DISABILITYTYPE` | NEW (multiselect — used in CSV column) | None, Physical, Visual, Hearing, Cognitive, Other |
| `REFERRALSOURCE` | NEW | CommunityLeader, SelfReferral, GovAgency, OtherNGO, FieldStaff, Other |
| `SPONSORSHIPTYPE` | NEW | IndividualSponsor, PoolFunded, SelfFunded |
| `BENEFICIARYSTATUS` | NEW | Draft (DFT #64748b), Active (ACT #166534), Waitlist (WL #854d0e), Graduated (GRD #1e40af), Exited (EXT #991b1b), Suspended (SUS #64748b), Deceased (DEC #475569) — include ColorHex |
| `ENROLLMENTSTATUS` | NEW (child table) | Enrolled, Waitlisted, Graduated, Exited, Suspended |
| `MILESTONESTATUS` | NEW (child table) | Achieved, InProgress, NotAchieved |

**FK cascades in FORM Section 2 (Location)**: Country → State → City → Locality — use the same parent-arg pattern as Family #20 / Contact #18 (`states(request: { countryId: X })` etc.).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `BeneficiaryCode` unique per `CompanyId` (auto-gen `BEN-{0001}` on blank create — pattern `BEN-{NNNN}` with Company-scoped concurrency-safe sequence).
- `(BeneficiaryId, ProgramId)` composite unique on `BeneficiaryProgramEnrollments` filtered `WHERE IsDeleted = 0` — a beneficiary cannot enrol in the same program twice (active).

**Required Field Rules:**
- `FirstName`, `LastName`, `GenderId`, `CountryId`, `HouseholdSize`, `PrimaryNeedCategoryId`, `VulnerabilityLevelId`, `BranchId`, `BeneficiaryStatusId` are mandatory.
- Either `DateOfBirth` OR `ApproximateAge` must be provided (one-of required).
- `PhotoConsent` and `DataConsent` must be true to submit as final (Active); NOT required when saving as Draft.
- At least ONE `BeneficiaryProgramEnrollment` row required to transition from Draft → Active (cannot be pure Draft without intent to enrol).

**Conditional Rules:**
- If `SponsorshipTypeId` corresponds to `IndividualSponsor` → `SponsorContactId` is REQUIRED.
- If `OrphanStatusId` IN (`SingleOrphan`, `DoubleOrphan`) → `GuardianName` + `GuardianRelationId` + `GuardianPhone` are REQUIRED.
- If `EducationStatusId` = `Enrolled` → `EducationGrade` + `SchoolName` are REQUIRED.
- If `BeneficiaryStatusId` IN (`Graduated`, `Exited`, `Deceased`) → `ExitDate` is REQUIRED; `ExitReason` recommended.
- If beneficiary is minor (age < 18) and not a Self relation → `GuardianName` is REQUIRED.
- `Disabilities` CSV values MUST each exist in MasterData `DISABILITYTYPE` — validated server-side.

**Business Logic:**
- `EnrollmentDate` defaults to `today` on Create when blank.
- `BeneficiaryStatus` transitions: Draft → Active (on full submit) → Waitlist | Suspended (pause) → Active (resume) → Graduated | Exited | Deceased (terminal). Archive action = soft-delete (`IsDeleted = 1`).
- `OutcomeScore` computed as `ACHIEVED_milestones / TOTAL_milestones × 100` (integer, capped 100, NULL when no milestones) — SERVICE_PLACEHOLDER-adjacent (stub formula; refined in a later enrichment pass).
- On Create, if the intake form includes a row in Household Members with `IsAlsoBeneficiary = true`, the backend does NOT auto-create sibling Beneficiary records — user must register each separately (to preserve consent + assessment per person). `LinkedBeneficiaryId` is populated later when the sibling is registered (manual link on edit).
- Auto-suggested Eligibility Cards in form §5: client-side computation (NO backend rule engine yet) — logic:
  - `Orphan Sponsorship` eligible if `OrphanStatusId IN (SGL, DBL)` AND `age < 18`
  - `Children's Education` eligible if `age BETWEEN 5 AND 18` AND `EducationStatusId = Enrolled`
  - `Healthcare Outreach` eligible if `GeneralHealthId IN (Poor, Critical)` OR `len(ChronicConditions) > 0`
  - `Women Empowerment` eligible if `GenderId = Female` AND `age >= 18`
  - `Food Distribution` eligible if `IncomeLevelId IN (NoIncome, BelowPoverty)` AND `HousingTypeId IN (Shelter, Homeless, Temporary)`
  - `Vocational Training` eligible if `age BETWEEN 16 AND 35` AND `EducationStatusId IN (DroppedOut, Completed)`
  - `Clean Water` eligible if `HousingConditionId IN (Poor, Unsafe)` OR `HousingTypeId IN (Shelter, Temporary)`
  - `Emergency Relief` eligible if `VulnerabilityLevelId = Critical`
- `PriorityId` defaults to the `VulnerabilityLevelId` value on the first save (auto-suggested; user can override).
- Bulk archive (from bulk bar) requires confirm modal with impact count + reason (optional).

**Workflow** (FLOW screen with state machine):
- States: `Draft` → `Active` → `Waitlist` / `Suspended` → `Active` → `Graduated` | `Exited` | `Deceased` (terminal) | Archive (soft-delete, reversible)
- Transitions: any staff with MODIFY capability can drive transitions; Archive requires DELETE capability.
- Side effects: transitioning to any terminal state stamps `ExitDate`; transitioning to Graduated also closes all open `BeneficiaryProgramEnrollments` with `EnrollmentStatusCode = Graduated`; transitioning to Deceased soft-deletes Household linkages to siblings.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Transactional case-management entity with compound form (7 sections + nested child grid + 5 child collections) and rich read-mode detail view (6 tabs, KPIs, timelines).
**Reason**: "+Add" navigates to full page (URL mode change, not modal); DETAIL is a completely different UI (6 tabs with info-cards + mini-grids + timeline) from the form; complex child-collection persistence (household members, program enrollments, milestones, documents, service logs); stateful widgets (filter chips, advanced filter panel, bulk action bar).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files for parent `Beneficiary`)
- [x] Tenant scoping (CompanyId from HttpContext; all GetAll projections filter by CompanyId)
- [x] Nested child creation (diff-persist pattern for 5 child collections on Create + Update — precedent: Contact #18's 9-child-collection handler)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 15+ MasterData lookups + Contact + Staff + Branch + Country/State/City/Locality + Program)
- [x] Unique validation — `BeneficiaryCode` per Company, `(BeneficiaryId, ProgramId)` filtered
- [x] Workflow commands (Archive / Restore / Transition — OR implement via Update with status-guard — prefer single Update + `UpdateBeneficiaryStatus` command for terminal transitions)
- [x] Auto-gen code command (BeneficiaryCode sequence per Company)
- [x] Computed field projections (displayName / ageYears / ageGroupCode / locationDisplay / programNames[] / programCodes[] / activeCasesCount / outcomeScore / tags[])
- [x] Summary query (GetBeneficiarySummary) for 4 KPI widgets
- [x] Advanced filter query args (Program / AgeGroup / Gender / Location / Branch / AssignedStaff + Status chip)
- [x] **NEW MODULE BOOTSTRAP** — see DEPENDENCY-ORDER.md § "For each new module…" — 7 setup files/wirings.

**Frontend Patterns Required:**
- [x] FlowDataTable (grid; displayMode: `table`; 10 columns)
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form with nested field arrays (household members inline grid; program enrollments via eligibility cards)
- [x] Zustand store (`beneficiary-store.ts`: chip filter, advanced filters, bulk selection, active detail tab, expanded sections)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back, Save primary, Register & Add Another, Save as Draft, Cancel)
- [x] Section accordion (7 sections, all expanded by default, click to collapse)
- [x] Inline child grid in form (Household Members with add/remove row)
- [x] Card-selector (Eligibility Cards in form §5 — client-side eligibility computation)
- [x] Conditional sub-form (Sponsor picker only when SponsorshipType=IndividualSponsor)
- [x] Cascading ApiSelect (Country → State → City → Locality)
- [x] Summary cards / KPI widgets above grid (4 widgets)
- [x] Grid aggregation columns (per-row computed programs[], age, locationDisplay, activeCasesCount)
- [x] Custom cell renderers (program-badge-list with color-by-value, sponsor-link-or-pool-funded, beneficiary-status-badge, avatar-name-sub)
- [x] Filter chips bar (7 chips)
- [x] Advanced filter panel (toggle + 6 selects + Apply/Clear)
- [x] Bulk action bar (conditional render when rows selected)
- [x] DETAIL layout: 5 Quick-Stats cards + 6 tabs (Overview / Programs & Services / Cases / Sponsorship / Documents / Timeline) — completely different from FORM layout
- [x] Timeline component (vertical with color-coded dots — see mockup `.timeline-list`)
- [x] File upload zones (photo / consent / documents) — SERVICE_PLACEHOLDER handlers

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **LAYOUT VARIANT STAMP** (mandatory): `widgets-above-grid` → FE Dev MUST use **Variant B** (`<ScreenHeader>` + widgets + `<DataTableContainer showHeader={false}>`). Not grid-only.

### Grid/List View — INDEX PAGE

**Display Mode**: `table` (default dense table via `<FlowDataTable>` — NOT card-grid)

**Grid Layout Variant**: `widgets-above-grid` → **Variant B MANDATORY** (ScreenHeader outside data-table; widgets between header and grid; DataTableContainer with `showHeader={false}`).

**KPI Widgets** (4 cards, `grid-template-columns: repeat(4, 1fr)` responsive):

| # | Widget Title | Icon (fa/ph) | Color | Value Source (from `GetBeneficiarySummary`) | Display | Sub-line |
|---|-------------|-------------|-------|---------------------------------------------|---------|----------|
| 1 | Total Beneficiaries | fa-people-group | teal | `totalCount` | number (formatted) | `Active: {activeCount} · Graduated: {graduatedCount} · Inactive: {inactiveCount}` |
| 2 | Programs Active | fa-hand-holding-heart | blue | `activeProgramsCount` + top-3 names | number | `{name1} ({count1}), {name2} ({count2}), {name3} ({count3})...` |
| 3 | New This Month | fa-user-plus | green | `newThisMonthCount` + `momDeltaPercent` | number | `<span class="up"><i class="fas fa-arrow-up"></i> {momDeltaPercent}%</span> vs last month` (color green if up, red if down) |
| 4 | Outcomes Achieved | fa-chart-line | purple | `outcomesAchievedYtd` | number | `Graduations, goals met, milestones this year` (static label) |

**Filter Chips** (7 chips, single-select — default `All`):
`All` / `Active` / `Waitlist` / `Graduated` / `Exited` / `Suspended` / `Deceased`

Maps to `beneficiaryStatusCode` filter arg on `GetBeneficiaries`. `All` = no filter. Chip state in Zustand store. Chips push via top-level GQL arg (NOT advancedFilter), precedent: Family #20 ISSUE-13 / Refund #13.

**Advanced Filter Panel** (collapsible, toggled by "Advanced Filters" button):

| # | Field | Widget | Query Arg |
|---|-------|--------|-----------|
| 1 | Program | select (static options from `programs(request)`) | `programId` |
| 2 | Age Group | select (0-5 / 6-12 / 13-17 / 18-25 / 26-40 / 41-60 / 60+) | `ageGroupCode` |
| 3 | Gender | select (All / Male / Female / Other) | `genderId` |
| 4 | Location | select (City list from `cities(request)`) | `cityId` |
| 5 | Branch | select from `branches(request)` | `branchId` |
| 6 | Assigned Staff | select from `staffs(request)` | `assignedStaffId` |

Apply button → fires refetch with args. Clear → reset to defaults.

**Bulk Action Bar** (conditionally shown when any row checkbox is selected):
`{N} selected` label + 3 buttons: `Export` (CSV download — reuse platform export if available, else SERVICE_PLACEHOLDER toast) / `Assign Staff` (open modal with staff picker; bulk-update AssignedStaffId) / `Send Communication` (SERVICE_PLACEHOLDER — opens placeholder "coming soon" toast).

**Grid Columns** (in display order, matching mockup):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 0 | — | _rowcheck | checkbox | 36px | NO | Row-select; wires to bulk bar |
| 1 | Ben. ID | beneficiaryCode | link | 120px | YES | Click → navigates to `?mode=read&id={id}` (teal color, hover underline) |
| 2 | Name | displayName + sublineProgramsCsv + avatarColor | **custom renderer** `beneficiary-avatar-name-subline` | auto | YES | Avatar initials (2 letters, colored) + Name bold + subline = programNames[0..2].join(', ') |
| 3 | Age | ageYears | number | 80px | YES | — |
| 4 | Gender | genderCode | text | 80px | NO | `M` / `F` / `Other` |
| 5 | Programs | programCodes[] | **custom renderer** `program-badge-list` | auto | NO | Wraps badges with color-by-value (CSS class mapping `.program-badge.{categoryCode}`) — cap at 3 visible + "+{N} more" overflow pill |
| 6 | Location | locationDisplay | text | auto | YES | "City, Country" |
| 7 | Sponsor | sponsorName / sponsorContactId | **custom renderer** `sponsor-link-or-pool-funded` | auto | NO | If SponsorContactId set → teal link → `?mode=read&id={sponsorContactId}` on Contact #18; else if SponsorshipType=PoolFunded → italic gray "Pool funded"; else em-dash |
| 8 | Status | beneficiaryStatusCode + statusColorHex | **custom renderer** `beneficiary-status-badge` (color-by-value) | 110px | YES | Pill with ColorHex from MasterData |
| 9 | Enrolled | enrollmentDate | date-compact | 100px | YES | "Jan 2024" format (MMM YYYY) |
| 10 | Actions | — | action cluster | 110px | NO | `View` outline button + conditional `Enroll` green button (only when status=Waitlist) + kebab dropdown (View / Edit / Add to Program / Create Case / Add Note / Generate Report / Archive) |

**Sort**: default sort = `beneficiaryCode` ASC.

**Search/Filter Fields** (search bar input): `displayName` / `beneficiaryCode` / `phone` — wildcard contains match.

**Grid Actions (per row)**:
- `View` outline button → `?mode=read&id={id}`
- `Enroll` green outline button (visible only when status = Waitlist) → inline mutation to transition status → Active; refetch
- kebab menu (7 items):
  - View → `?mode=read&id={id}`
  - Edit → `?mode=edit&id={id}`
  - Add to Program → opens modal `AddProgramEnrollmentModal` (program picker + enrolled-on date + assigned staff)
  - Create Case → navigates to `/[lang]/crm/casemanagement/caselist?mode=new&beneficiaryId={id}` (SERVICE_PLACEHOLDER if Case #50 not built — toast "Case module coming soon")
  - Add Note → opens modal `AddBeneficiaryNoteModal` — appends to `InternalNotes` field with timestamp + staff name
  - Generate Report → SERVICE_PLACEHOLDER toast (reports pipeline unbuilt)
  - Archive → confirm modal → soft-delete mutation (`DeleteBeneficiary`)

**Row Click**: navigates to `?mode=read&id={id}` (NOT the full row — only cells EXCEPT the Actions column; checkbox click should NOT navigate).

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

```
URL MODE                                                  UI LAYOUT
────────────────────────────────────────────────          ─────────────────────────────────
/crm/casemanagement/beneficiarylist?mode=new          →   FORM LAYOUT  (empty, 7 sections)
/crm/casemanagement/beneficiarylist?mode=edit&id=X    →   FORM LAYOUT  (pre-filled, 7 sections)
/crm/casemanagement/beneficiarylist?mode=read&id=X    →   DETAIL LAYOUT (5 Quick-Stats + 6 tabs — DIFFERENT UI)
```

NEW and EDIT share the same form layout. READ is a completely different UI — multi-tab detail page with quick-stats, info-cards, mini-grids, and timeline.

---

#### LAYOUT 1: FORM (mode=new & mode=edit) — "Register Beneficiary"

**Page Header** (`FlowFormPageHeader` equivalent — build per mockup):
- Left: Back button (icon only, navigates to index) + title "Register Beneficiary" + subtitle "New beneficiary intake and needs assessment"
- Right: 4 action buttons
  - `Register Beneficiary` (primary teal) — full save, status = Active, redirect to DETAIL
  - `Register & Add Another` (outline teal) — save, keep form open with reset fields, stay in `?mode=new`
  - `Save as Draft` (outline teal) — save, status = Draft, stay in `?mode=edit&id={newId}`
  - `Cancel` (text-only, danger hover) — confirm-if-dirty dialog → navigate to index

**Section Container Type**: accordion (7 cards stacked vertically, each with header + toggle chevron; all expanded by default; click header to collapse/expand)

**Form Sections** (in display order from mockup — all `full-width` page width, 2-column internal grid):

| # | Icon (fa) | Section Title | Layout | Collapse | Fields |
|---|-----------|---------------|--------|----------|--------|
| 1 | fa-user | Personal Information | 2-column | expanded | FirstName*, LastName*, DateOfBirth*, ApproximateAge, GenderId*, NationalityId, NationalIdNumber, Languages, Photo (full-width drag-drop upload) |
| 2 | fa-location-dot | Location & Contact | 2-column | expanded | CountryId*, StateId, CityId*, LocalityId, AddressDetails (full-width textarea), GpsCoordinates, Phone, AlternativeContactName, AlternativePhone |
| 3 | fa-people-roof | Family / Household | 2-column + nested table | expanded | HouseholdHeadName, RelationshipToHeadId, HouseholdSize*, OrphanStatusId, [Household Members inline child grid — see below], GuardianName, GuardianRelationId, GuardianPhone |
| 4 | fa-clipboard-list | Needs Assessment | 2-column + sub-sections | expanded | PrimaryNeedCategoryId*, VulnerabilityLevelId*, IncomeLevelId, — sub-section "Education Status" → EducationStatusId / EducationGrade / SchoolName — sub-section "Health Status" → GeneralHealthId / Disabilities (multi-select) / ChronicConditions / LastCheckupDate — sub-section "Housing" → HousingTypeId / HousingConditionId — full-width SpecialNeedsNotes textarea |
| 5 | fa-hand-holding-heart | Program Enrollment | eligibility-card list + 2-column | expanded | [Auto-suggested Eligibility Cards — see below], AssignedStaffId, SponsorshipTypeId, SponsorContactId (conditional) |
| 6 | fa-file-signature | Consent & Documents | 2-column + full-width checkboxes | expanded | PhotoConsent (checkbox full-width), DataConsent (checkbox full-width), ConsentFormUrl (file upload zone), SupportingDocuments (multi-file upload zone — writes to `BeneficiaryDocuments` child) |
| 7 | fa-lock | Internal | 2-column | expanded | ReferralSourceId, ReferralSourceName, BranchId*, PriorityId (auto-suggested hint below), InternalNotes (full-width textarea) |

(* = required)

**Field Widget Mapping** (all fields across all sections):

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| FirstName | 1 | text | "First name" | required, maxLen 100 | — |
| LastName | 1 | text | "Last name" | required, maxLen 100 | — |
| DateOfBirth | 1 | datepicker | "Select date" | required (or ApproximateAge) | — |
| ApproximateAge | 1 | number | "Age in years" | 0–120, alternative to DOB | — |
| GenderId | 1 | ApiSelectV2 | "Select gender..." | required | Query: `masterDatas(staticFilter: "GENDER")`; display: `dataName` |
| NationalityId | 1 | ApiSelectV2 | "Select nationality..." | — | Query: `masterDatas(staticFilter: "NATIONALITY")` |
| NationalIdNumber | 1 | text | "ID number (if available)" | maxLen 50 | — |
| Languages | 1 | text (CSV-entry) | "e.g. Arabic, Somali, English" | maxLen 200 | Future: tags input |
| PhotoUrl | 1 | drag-drop image upload | "Drag & drop or browse to upload photo" | jpeg/png ≤5MB | **SERVICE_PLACEHOLDER** if upload infra absent — accept URL input field fallback |
| CountryId | 2 | ApiSelectV2 | "Select country..." | required | Query: `countries(request)`; display: `countryName` |
| StateId | 2 | ApiSelectV2 | "Select state..." | cascade-disabled until Country set | Query: `states(request: { countryId })` |
| CityId | 2 | ApiSelectV2 | "City or town name" | required | Query: `cities(request: { stateId })` |
| LocalityId | 2 | ApiSelectV2 | "Area or neighbourhood" | — | Query: `localities(request: { cityId })` |
| AddressDetails | 2 | textarea (full-width) | "Full address details" | maxLen 500 | rows=2 |
| GpsCoordinates | 2 | text | "Lat, Long (auto-capture or manual)" | maxLen 100 | Future: geolocation browser API button |
| Phone | 2 | tel | "+971 50 XXX XXXX" | maxLen 30 | — |
| AlternativeContactName | 2 | text | "Name" | maxLen 100 | — |
| AlternativePhone | 2 | tel | "+971 50 XXX XXXX" | maxLen 30 | — |
| HouseholdHeadName | 3 | text | "e.g. Halima Hassan (mother)" | maxLen 200 | — |
| RelationshipToHeadId | 3 | ApiSelectV2 | "Select..." | — | Query: `masterDatas(staticFilter: "RELATION")` |
| HouseholdSize | 3 | number | "Number of members" | required, ≥1 | — |
| OrphanStatusId | 3 | ApiSelectV2 | "Select..." | — | Query: `masterDatas(staticFilter: "ORPHANSTATUS")` |
| GuardianName | 3 | text | "If orphan or minor" | required conditional (see §④) | — |
| GuardianRelationId | 3 | ApiSelectV2 | "Select..." | required conditional | Query: `masterDatas(staticFilter: "RELATION")` |
| GuardianPhone | 3 | tel | "+971 50 XXX XXXX" | maxLen 30 | — |
| PrimaryNeedCategoryId | 4 | ApiSelectV2 | "Select..." | required | Query: `masterDatas(staticFilter: "PRIMARYNEEDCATEGORY")` |
| VulnerabilityLevelId | 4 | ApiSelectV2 | "Select..." | required | Query: `masterDatas(staticFilter: "VULNERABILITYLEVEL")`; render with color-dot |
| IncomeLevelId | 4 | ApiSelectV2 | "Select..." | — | `masterDatas(staticFilter: "INCOMELEVEL")` |
| EducationStatusId | 4 | ApiSelectV2 | "Select..." | — | `masterDatas(staticFilter: "EDUCATIONSTATUS")` |
| EducationGrade | 4 | select-or-text | "Select..." | required conditional | Free-text OR dropdown (Pre-school / Grade 1-12 / University) |
| SchoolName | 4 | text | "School name" | required conditional | maxLen 200 |
| GeneralHealthId | 4 | ApiSelectV2 | "Select..." | — | `masterDatas(staticFilter: "GENERALHEALTH")` |
| Disabilities | 4 | multi-select | — | — | Multi-select chipified from `masterDatas(staticFilter: "DISABILITYTYPE")`; persisted as CSV of codes |
| ChronicConditions | 4 | text | "List any chronic conditions" | maxLen 500 | Future: multi-select ChronicCondition master |
| LastCheckupDate | 4 | datepicker | — | — | — |
| HousingTypeId | 4 | ApiSelectV2 | "Select..." | — | `masterDatas(staticFilter: "HOUSINGTYPE")` |
| HousingConditionId | 4 | ApiSelectV2 | "Select..." | — | `masterDatas(staticFilter: "HOUSINGCONDITION")` |
| SpecialNeedsNotes | 4 | textarea (full-width) | "Any additional information..." | maxLen 2000 | rows=3 |
| AssignedStaffId | 5 | ApiSelectV2 | "Select staff..." | — | Query: `staffs(request)`; display: `staffName` |
| SponsorshipTypeId | 5 | ApiSelectV2 | "Select..." | — | `masterDatas(staticFilter: "SPONSORSHIPTYPE")`; triggers conditional sub-field |
| SponsorContactId | 5 | ApiSelectV2 | "Search sponsor..." | required conditional | Query: `contacts(request)`; display: `displayName`; visible only when SponsorshipType=IndividualSponsor |
| PhotoConsent | 6 | checkbox (full-width) | — | required for Active | Label: "Guardian consents to photos for reporting/fundraising" |
| DataConsent | 6 | checkbox (full-width) | — | required for Active | Label: "Guardian consents to data collection and storage" |
| ConsentFormUrl | 6 | file upload zone | "Upload signed consent form" | — | SERVICE_PLACEHOLDER fallback: URL input |
| SupportingDocuments | 6 | multi-file upload zone | "Upload ID copies, school reports, medical records, referral letters" | — | Writes rows to `BeneficiaryDocuments` child on save; SERVICE_PLACEHOLDER handler |
| ReferralSourceId | 7 | ApiSelectV2 | "Select..." | — | `masterDatas(staticFilter: "REFERRALSOURCE")` |
| ReferralSourceName | 7 | text | "Name of referrer" | maxLen 200 | — |
| BranchId | 7 | ApiSelectV2 | "Select branch..." | required | Query: `branches(request)`; display: `branchName` |
| PriorityId | 7 | ApiSelectV2 | "Select..." | — | `masterDatas(staticFilter: "VULNERABILITYLEVEL")`; hint "Auto-suggested from assessment" below field (derived from VulnerabilityLevelId default) |
| InternalNotes | 7 | textarea (full-width) | "Internal notes (not visible to sponsors)" | maxLen 2000 | rows=3 |

**Special Form Widgets**:

**1. Household Members inline child grid** (in Section 3 Family/Household):
| Card | Icon | Label | Description | Triggers |
|------|------|-------|-------------|----------|
| — (table, not cards) | fa-users | "Household Members" | inline sub-table with columns: Name / Age / Gender (select) / Relationship (text) / Also a Beneficiary? (checkbox + conditional BEN-XXX badge) / Remove button | "Add Household Member" (dashed-outline button below table) appends a blank row. Checkbox "Also a Beneficiary?" + an assigned `LinkedBeneficiaryId` shows the linked BEN code as a small teal badge. |

**2. Eligibility Cards** (in Section 5 Program Enrollment — auto-suggested based on Assessment answers):
For each of the 8 Programs (ORPHAN / EDUCATION / HEALTHCARE / WOMEN / FOOD / VOCATIONAL / WATER / RELIEF):
| Card Field | Content |
|-----------|---------|
| Checkbox | Default-checked for eligible programs; disabled for ineligible |
| Eligibility Name | Program name (e.g., "Orphan Sponsorship") |
| Eligibility Reason | Green text when eligible (e.g., "Eligible: orphan, minor"); gray when not (e.g., "No current health need") |
| Action dropdown | "Enroll Now" / "Add to Waitlist" — only enabled if card is checked |

Client-side eligibility logic (§④). Checked + "Enroll Now" → appends a row to `beneficiaryProgramEnrollments[]` with `EnrollmentStatusCode = Enrolled`. Checked + "Add to Waitlist" → `EnrollmentStatusCode = Waitlisted`.

**3. Conditional Sub-forms**:
| Trigger Field | Trigger Value | Sub-form Fields |
|--------------|---------------|-----------------|
| SponsorshipTypeId | IndividualSponsor | SponsorContactId (ApiSelectV2 `contacts`) — required when this path |
| OrphanStatusId | SingleOrphan / DoubleOrphan | GuardianName + GuardianRelationId + GuardianPhone required |
| EducationStatusId | Enrolled | EducationGrade + SchoolName required |

**4. Inline Mini Display** — none in FORM (reserve for DETAIL).

**Child Grids in Form**:
| Child | Grid Columns | Add/Edit Method | Delete | Notes |
|-------|-------------|----------------|--------|-------|
| BeneficiaryHouseholdMembers | Name / Age / Gender / Relationship / IsAlsoBeneficiary | Inline row (add button below) | Remove button per row | Max ~10 rows (no hard cap; UX acceptable) |
| BeneficiaryProgramEnrollments | — (via Eligibility Cards UI, not a grid) | Checkbox toggle on card | Uncheck card | Persisted on save from card state |

---

#### LAYOUT 2: DETAIL (mode=read) — COMPLETELY DIFFERENT UI FROM FORM

**Page Header** (mockup "page-header"):
- Left: Back button + ben-header-info block:
  - Avatar (52px circle, accent color, 2-letter initials)
  - Name (large) + BEN-id (small muted inline)
  - Meta row: status pill + Age + Since + Location (fa-location-dot icon) + Sponsor link (or "Pool funded" italic)
- Right: 3 action buttons:
  - `Edit` (outline) → navigate to `?mode=edit&id={id}`
  - `Add to Program` (primary) → opens `AddProgramEnrollmentModal`
  - `More` (secondary with chevron-down) dropdown:
    - Create Case → `?mode=new` on Case #50 (SERVICE_PLACEHOLDER)
    - Generate Report → SERVICE_PLACEHOLDER
    - Export (SERVICE_PLACEHOLDER)
    - Print (window.print() — minimal)

**Quick Stats Row** (5 cards, `grid-template-columns: repeat(5, 1fr)` responsive):

| # | Label | Value | Sub | Source |
|---|-------|-------|-----|--------|
| 1 | Programs | `programsCount` | `programNames[0..1].join(', ')` | BeneficiaryProgramEnrollments |
| 2 | Active Cases | `activeCasesCount` | `activeCasesOverview` (e.g., "Education follow-up") | SUBQUERY case.Cases (SERVICE_PLACEHOLDER if Case #50 not built → returns 0) |
| 3 | Services Received | `servicesReceivedThisYear` | "This year" (static) | COUNT BeneficiaryServiceLogs where ServiceDate >= jan 1 |
| 4 | Sponsor | `sponsorName` (or "Pool funded") | `sponsorshipAmountFormatted + '/month'` (or empty) | Contact join |
| 5 | Outcome Score | `outcomeScore` (with `/100` small suffix) | outcome category label (e.g., "Progressing well", "Behind", "Exceeding") | computed in BE |

**Detail Tabs** (6 tabs, mockup `.detail-tabs`):

1. **Overview** (default active)
2. **Programs & Services**
3. **Cases**
4. **Sponsorship**
5. **Documents**
6. **Timeline**

**TAB 1: Overview** (2-col, `row g-3` → col-lg-6 each):

| # | Card Title (icon) | Content |
|---|-------------------|---------|
| L | Personal Information (fa-user) | info-list (label/value) with 11 rows: Full Name / Beneficiary ID / Date of Birth (+ age) / Gender / Nationality / ID Number / Address / Guardian / Guardian Phone / Household Size / Languages |
| R | Needs Assessment Summary (fa-clipboard-list) | info-list 7 rows: Category (derived: Orphan + year, or PrimaryNeedCategoryName) / Education Level / Health Status (+ last check-up) / Housing / Income Level / Special Needs / Priority (with priority-badge) — Plus Tags badge-list below (derived tags[]) |

**TAB 2: Programs & Services** (3 stacked cards):

| # | Card Title (icon) | Content |
|---|-------------------|---------|
| 1 | Enrolled Programs (fa-hand-holding-heart) | mini-grid with 6 cols: Program (badge) / Enrolled (MMM YYYY) / Status (status-badge) / Staff / Services (summary text) / Next Action |
| 2 | Service History (Recent) (fa-history) | mini-grid with 5 cols: Date / Program (badge) / Service description / Provider / Notes — top 20 recent rows |
| 3 | Milestones & Outcomes (fa-trophy) | mini-grid with 5 cols: Milestone title / Target / Achieved (with milestone-yes/progress/no icon) / Date / Evidence (link) |

**TAB 3: Cases** (1 card):

| # | Card Title (icon) | Content |
|---|-------------------|---------|
| 1 | Cases (fa-folder-open) | mini-grid: Case ID (teal link) / Title / Program (badge) / Opened (MMM YYYY) / Status (status-badge) / Priority (priority-badge) / Assigned / Actions ("View" button) — **SERVICE_PLACEHOLDER if Case #50 not built — show empty-state "No cases yet" with fa-folder-open icon and muted text** |

**TAB 4: Sponsorship** (2-col):

| # | Card Title (icon) | Content |
|---|-------------------|---------|
| L | Sponsorship Details (fa-heart) | info-list 8 rows: Sponsor (teal link) / Sponsorship Type / Amount / Since / Status (status-badge) / Communications / Last Update Sent / Next Update Due — **SERVICE_PLACEHOLDER when sponsorship domain not wired (RecurringDonationSchedule + SponsorCommunications unbuilt) → render placeholder row "Sponsorship integration coming soon"** |
| R | Payment History (fa-credit-card) | mini-grid: Month / Amount / Status — SERVICE_PLACEHOLDER — show last 5 months placeholder or empty state |

**TAB 5: Documents** (1 card):

Responsive doc-grid (`grid-template-columns: repeat(auto-fill, minmax(200px, 1fr))`) of doc tiles:
- Icon (contextual: fa-image / fa-file-lines / fa-file-medical / fa-clipboard-check / fa-id-card)
- Doc name (bold)
- Date (muted small)
- Click → open in new tab (uses `DocumentUrl`)

Upload button in card header (top-right): `Upload Document` (primary) → opens modal with drag-drop zone + name + type select + URL fallback. SERVICE_PLACEHOLDER handler if platform file-upload infra absent.

**TAB 6: Timeline** (1 card, vertical timeline):

Aggregates events (most recent first) from:
- BeneficiaryServiceLogs → green/blue/teal/purple dots based on ServiceType
- BeneficiaryProgramEnrollments (enroll events) → teal dot
- BeneficiaryMilestones (achieved events) → purple dot
- BeneficiaryDocuments (uploaded events) → orange dot
- Beneficiary created / status-change events (from audit or inferred) → green/red dot
- Cases opened/closed (SERVICE_PLACEHOLDER if Case #50 not built) → orange dot

Each item: date (muted small) + title (bold) + description (muted).

### Page Widgets & Summary Cards

**Widgets**: YES — 4 KPI cards (see Grid/List View section above).

**Grid Layout Variant**: `widgets-above-grid` → **Variant B MANDATORY**.

**Summary GQL Query**:
- Query name: `GetBeneficiarySummary`
- Returns: `BeneficiarySummaryDto` — fields: `totalCount`, `activeCount`, `graduatedCount`, `inactiveCount` (= Suspended + Exited + Deceased), `activeProgramsCount`, `topProgramsCsv` (string "name(count), name(count), ..." top 3), `newThisMonthCount`, `momDeltaPercent`, `outcomesAchievedYtd`.
- Added to `BeneficiaryQueries.cs` alongside `GetBeneficiaries` + `GetBeneficiaryById`.

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Programs (badge-list) | Active program codes for this beneficiary | ARRAY(ProgramCode) from BeneficiaryProgramEnrollments WHERE EnrollmentStatusCode='Enrolled' | LINQ projection `SelectMany` with cap at top 3 + overflow |
| Active Cases count (in Quick Stats only, not main grid) | COUNT(case.Cases) | SUBQUERY | LINQ subquery — SERVICE_PLACEHOLDER returning 0 until Case #50 |

### User Interaction Flow

1. User lands on `/[lang]/crm/casemanagement/beneficiarylist` — sees ScreenHeader + 4 KPI widgets + grid with 7 chips + 10-col table
2. User clicks "+ Register Beneficiary" (header button) → URL `?mode=new` → FORM LAYOUT with 7 accordion sections, all expanded
3. User fills Sections 1-4 → Section 5 auto-refreshes eligibility cards based on assessment answers
4. User checks preferred eligibility cards, picks "Enroll Now" / "Add to Waitlist"
5. User clicks "Register Beneficiary" → API Create call → redirects to `?mode=read&id={newId}` → DETAIL LAYOUT with 5 Quick Stats + 6 tabs (Overview active)
6. User clicks kebab → "Edit" → URL `?mode=edit&id={id}` → FORM LAYOUT pre-filled → edits → Save → redirects back to DETAIL
7. From grid, user can filter by chip (Waitlist) → grid refetches → Waitlist rows show "Enroll" inline button → click → quick status-transition mutation → chip auto-updates (Row moves out of Waitlist into Active)
8. Bulk select: user ticks checkboxes → bulk bar appears → "Assign Staff" → modal opens → staff picked → bulk-mutation → refetch + bulk bar dismiss
9. Advanced filter panel toggle → user picks Program=Orphan + City=Dubai → Apply → grid refetches filtered
10. Unsaved changes dialog on dirty navigation

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical FLOW reference entity (SavedFilter) to Beneficiary.

**Canonical Reference**: SavedFilter (FLOW) — but for the new-module bootstrap, **pair with Pledge** (FULL greenfield FLOW precedent, 2-entity parent/child with auto-gen Code). For the detail-tab UX, borrow from **Contact #18** (tabs + info-lists pattern).

| Canonical | → Beneficiary | Context |
|-----------|---------------|---------|
| SavedFilter | Beneficiary | Entity/class name |
| savedFilter | beneficiary | Variable/camelCase |
| SavedFilterId | BeneficiaryId | PK field |
| SavedFilters | Beneficiaries | Table name, collection |
| saved-filter | beneficiary | kebab-case file names |
| savedfilter | beneficiary (folder) / beneficiarylist (FE route — matches existing stub) | FE folder / route path segment |
| SAVEDFILTER | BENEFICIARYLIST | Grid code / menu code |
| notify | case | DB schema |
| Notify | Case | Backend group name (Models/Schemas/Business) |
| NotifyModels | CaseModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_CASEMANAGEMENT | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/casemanagement/beneficiarylist | FE route path |
| notify-service | case-service | FE service folder name |

**Pair with Pledge #12** for:
- Auto-gen `BeneficiaryCode` pattern (copy `PledgeCode = PLG-{NNNN}` → `BeneficiaryCode = BEN-{NNNN}`)
- Child-collection diff-persist on Create+Update (Pledge→PledgePayment → Beneficiary→{Household, ProgramEnrollments, Milestones, ServiceLogs, Documents})
- FLOW KPI widgets + filter chips pattern

**Pair with Contact #18** for:
- DETAIL layout (multi-tab info-cards + sidebar quick-stats)
- Multi-FK projection in GetAll / GetById
- Timeline aggregation from child tables

**Pair with Family #20** for:
- Chip-filter as top-level GQL arg (NOT advancedFilter payload) — ISSUE-13 precedent

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### NEW MODULE BOOTSTRAP (Case schema — owned by Program #51)

**If Program #51 is built first** (recommended): skip the 7 bootstrap files — they already exist. Just MODIFY:
- `ICaseDbContext.cs` — add `DbSet<Beneficiary>`, `DbSet<BeneficiaryHouseholdMember>`, `DbSet<BeneficiaryProgramEnrollment>`, `DbSet<BeneficiaryMilestone>`, `DbSet<BeneficiaryServiceLog>`, `DbSet<BeneficiaryDocument>` alongside the existing `DbSet<Program>` lines.
- `CaseMappings.cs` — append Mapster mapping registrations for the 6 new Beneficiary entities.
- `DecoratorCaseModules` (inside `DecoratorProperties.cs`) — append `Beneficiary`, `HouseholdMember`, `ProgramEnrollment`, `Milestone`, `ServiceLog`, `Document` constants alongside the existing `Program` constant.

**If Beneficiary is built BEFORE Program #51** (fragile, not recommended — see §⑫ ISSUE-1): execute the full 7-file bootstrap from Program #51's §⑧ (ICaseDbContext / CaseDbContext / CaseMappings / IApplicationDbContext inheritance / DependencyInjection register / DecoratorCaseModules / GlobalUsing × 3) PLUS create a minimal `Program` stub entity (ProgramId + ProgramCode + ProgramName + ColorHex + ProgramCategoryCode) — Program #51's later build will re-align the table via migration adding the richer columns.

### Backend Files (Beneficiary parent + 5 children — 6 entities total, Program entity owned by #51)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Beneficiary entity | `Pss2.0_Backend/.../Base.Domain/Models/CaseModels/Beneficiary.cs` | CREATE |
| 2 | BeneficiaryHouseholdMember entity | `Pss2.0_Backend/.../Base.Domain/Models/CaseModels/BeneficiaryHouseholdMember.cs` | CREATE |
| 3 | BeneficiaryProgramEnrollment entity | `Pss2.0_Backend/.../Base.Domain/Models/CaseModels/BeneficiaryProgramEnrollment.cs` | CREATE |
| 4 | BeneficiaryMilestone entity | `Pss2.0_Backend/.../Base.Domain/Models/CaseModels/BeneficiaryMilestone.cs` | CREATE |
| 5 | BeneficiaryServiceLog entity | `Pss2.0_Backend/.../Base.Domain/Models/CaseModels/BeneficiaryServiceLog.cs` | CREATE |
| 6 | BeneficiaryDocument entity | `Pss2.0_Backend/.../Base.Domain/Models/CaseModels/BeneficiaryDocument.cs` | CREATE |
| 7 | EF Configurations (× 6) | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/CaseConfigurations/{Entity}Configuration.cs` | CREATE — one per entity, with composite indices (BeneficiaryId + ProgramId filtered, BeneficiaryCode unique filtered per Company, etc.) |
| 8 | BeneficiarySchemas.cs (DTOs) | `Pss2.0_Backend/.../Base.Application/Schemas/CaseSchemas/BeneficiarySchemas.cs` | CREATE — BeneficiaryRequestDto, BeneficiaryResponseDto, BeneficiarySummaryDto, BeneficiaryHouseholdMemberRequestDto/ResponseDto, BeneficiaryProgramEnrollmentRequestDto/ResponseDto, BeneficiaryMilestoneRequestDto/ResponseDto, BeneficiaryServiceLogRequestDto/ResponseDto, BeneficiaryDocumentRequestDto/ResponseDto |
| 9 | CreateBeneficiary command | `Pss2.0_Backend/.../Base.Application/Business/CaseBusiness/Beneficiaries/CreateCommand/CreateBeneficiary.cs` | CREATE — also persists child collections atomically |
| 10 | UpdateBeneficiary command | `Pss2.0_Backend/.../Base.Application/Business/CaseBusiness/Beneficiaries/UpdateCommand/UpdateBeneficiary.cs` | CREATE — diff-persists children (precedent: Contact #18) |
| 11 | DeleteBeneficiary command (soft-delete = Archive) | `.../Beneficiaries/DeleteCommand/DeleteBeneficiary.cs` | CREATE |
| 12 | ToggleBeneficiary command | `.../Beneficiaries/ToggleCommand/ToggleBeneficiary.cs` | CREATE |
| 13 | UpdateBeneficiaryStatus command (workflow transitions) | `.../Beneficiaries/UpdateCommand/UpdateBeneficiaryStatus.cs` | CREATE — handles terminal state side-effects (ExitDate stamp, program closure) |
| 14 | BulkAssignStaff command | `.../Beneficiaries/UpdateCommand/BulkAssignStaff.cs` | CREATE — for bulk-bar action |
| 15 | EnrollBeneficiaryInProgram command | `.../Beneficiaries/UpdateCommand/EnrollBeneficiaryInProgram.cs` | CREATE — for Add-to-Program modal + Waitlist→Active inline button |
| 16 | GetBeneficiaries (GetAll) query | `.../Beneficiaries/GetAllQuery/GetBeneficiaries.cs` | CREATE — with advanced filter args + chip-status arg + computed projections |
| 17 | GetBeneficiaryById query | `.../Beneficiaries/GetByIdQuery/GetBeneficiaryById.cs` | CREATE — with nested child collections |
| 18 | GetBeneficiarySummary query | `.../Beneficiaries/GetByIdQuery/GetBeneficiarySummary.cs` | CREATE — KPI widgets source |
| 19 | BeneficiaryMutations | `Pss2.0_Backend/.../Base.API/EndPoints/Case/Mutations/BeneficiaryMutations.cs` | CREATE — register all commands |
| 20 | BeneficiaryQueries | `.../Case/Queries/BeneficiaryQueries.cs` | CREATE — register GetAll / GetById / GetSummary |
| 21 | EF Migration | `Pss2.0_Backend/.../Base.Infrastructure/Migrations/{timestamp}_Beneficiary_Initial.cs` | GENERATE — create 6 tables + FKs + composite filtered indices (BeneficiaryCode unique per Company; BeneficiaryId+ProgramId composite). If Program #51 not yet built, this migration must ALSO create the Program table stub (fragile path). |

Note: `ProgramQueries` + `ProgramResponseDto` + Program entity + Program seeds are all OWNED by Program #51's build (see that prompt's §⑧). Beneficiary's `BeneficiaryProgramEnrollment.ProgramId` FK simply references the existing `case.Programs` table.

### Backend Wiring Updates (beyond module bootstrap)

| # | File | What to Add |
|---|------|-------------|
| 1 | ICaseDbContext.cs | DbSet properties for all 7 entities |
| 2 | CaseDbContext.cs | DbSet properties + OnModelCreating with `HasDefaultSchema("case")` + ApplyConfigurationsFromAssembly |
| 3 | CaseMappings.cs | Mapster `ConfigureMappings()` + `Register(TypeAdapterConfig config)` for all DTO mappings |
| 4 | DecoratorCaseModules (in DecoratorProperties.cs) | Constants for 7 module names |

### Frontend Files (12 files — FLOW with 6 detail tabs + 4 KPI widgets + 5 child collections)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/case-service/BeneficiaryDto.ts` | CREATE — all 7 entity DTOs (BeneficiaryDto + 6 child DTOs + SummaryDto + ProgramDto stub) |
| 2 | GQL Query | `Pss2.0_Frontend/src/infrastructure/gql-queries/case-queries/BeneficiaryQuery.ts` | CREATE — GET_BENEFICIARIES_QUERY, GET_BENEFICIARY_BY_ID_QUERY, GET_BENEFICIARY_SUMMARY_QUERY, GET_PROGRAMMES_QUERY |
| 3 | GQL Mutation | `Pss2.0_Frontend/src/infrastructure/gql-mutations/case-mutations/BeneficiaryMutation.ts` | CREATE — CREATE_BENEFICIARY_MUTATION, UPDATE_BENEFICIARY_MUTATION, DELETE_BENEFICIARY_MUTATION, TOGGLE_BENEFICIARY_MUTATION, UPDATE_BENEFICIARY_STATUS_MUTATION, BULK_ASSIGN_STAFF_MUTATION |
| 4 | Page Config | `Pss2.0_Frontend/src/presentation/pages/case/beneficiarylist/beneficiary.tsx` | CREATE — page-level config + gridCode + actions |
| 5 | Index Router | `Pss2.0_Frontend/src/presentation/components/page-components/case/beneficiarylist/beneficiary/index.tsx` | CREATE — URL mode dispatcher (new/edit/read → view-page; else index-page) |
| 6 | Index Page | `.../case/beneficiarylist/beneficiary/index-page.tsx` | CREATE — Variant B: ScreenHeader + 4 KPI widgets + FlowDataTable with showHeader=false + filter chips + advanced filter panel + bulk bar |
| 7 | View Page (3 modes) | `.../case/beneficiarylist/beneficiary/view-page.tsx` | CREATE — FORM layout for new/edit; DETAIL layout for read |
| 8 | Zustand Store | `.../case/beneficiarylist/beneficiary/beneficiary-store.ts` | CREATE — chipFilter, advancedFilters, bulkSelectedIds, activeDetailTab, expandedSections |
| 9 | Sub-component: Create/Update Form | `.../case/beneficiarylist/beneficiary/beneficiary-form.tsx` | CREATE — 7 accordion sections + React Hook Form + nested child fields |
| 10 | Sub-component: Detail Page | `.../case/beneficiarylist/beneficiary/beneficiary-detail.tsx` | CREATE — 5 Quick Stats + 6 tabs (Overview / Programs & Services / Cases / Sponsorship / Documents / Timeline) |
| 11 | Sub-component: Widgets | `.../case/beneficiarylist/beneficiary/beneficiary-widgets.tsx` | CREATE — 4 KPI cards |
| 12 | Sub-component: Filter Chips | `.../case/beneficiarylist/beneficiary/filter-chips-bar.tsx` | CREATE — 7 chips with active state |
| 13 | Sub-component: Advanced Filter Panel | `.../case/beneficiarylist/beneficiary/advanced-filter-panel.tsx` | CREATE — 6 selects + Apply + Clear |
| 14 | Sub-component: Bulk Action Bar | `.../case/beneficiarylist/beneficiary/bulk-action-bar.tsx` | CREATE — conditional render |
| 15 | Sub-component: Household Members inline grid | `.../case/beneficiarylist/beneficiary/household-members-grid.tsx` | CREATE — used inside beneficiary-form.tsx Section 3 |
| 16 | Sub-component: Eligibility Cards | `.../case/beneficiarylist/beneficiary/eligibility-cards.tsx` | CREATE — client-side eligibility computation + card UI |
| 17 | Sub-component: Add to Program modal | `.../case/beneficiarylist/beneficiary/add-program-modal.tsx` | CREATE — reused by Add-to-Program action (grid + detail) |
| 18 | Sub-component: Timeline tab | `.../case/beneficiarylist/beneficiary/timeline-tab.tsx` | CREATE — aggregates events from child tables |
| 19 | Route Page (OVERWRITE stub) | `Pss2.0_Frontend/src/app/[lang]/crm/casemanagement/beneficiarylist/page.tsx` | OVERWRITE — 5-line stub replaced with page.tsx wrapper using ClientPageWrapper + index router |
| 20 | Custom Cell Renderers (4) | `Pss2.0_Frontend/src/presentation/components/data-table/components/shared-cell-renderers/` | CREATE: `beneficiary-avatar-name-subline.tsx`, `program-badge-list.tsx`, `sponsor-link-or-pool-funded.tsx`, `beneficiary-status-badge.tsx` — register in 3 column-type registries (advanced-column-types, basic-column-types, flow-column-types) + shared-cell-renderers barrel |

### Frontend Wiring Updates

| # | File | What to Add |
|---|------|-------------|
| 1 | entity-operations.ts | `BENEFICIARY` operations config block (READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT) |
| 2 | operations-config.ts | Import + register `beneficiaryOperations` |
| 3 | sidebar.ts (or equivalent menu config) | Menu entry "Beneficiary List" under CRM_CASEMANAGEMENT parent |
| 4 | routes config | Route definition for `/[lang]/crm/casemanagement/beneficiarylist` |
| 5 | advanced-column-types.ts | Register 4 new renderers |
| 6 | basic-column-types.ts | Register 4 new renderers |
| 7 | flow-column-types.ts | Register 4 new renderers |
| 8 | shared-cell-renderers barrel | Export 4 new renderers |
| 9 | case-service entity-operations | NEW `case-service` folder (first consumer) — may require creating the folder structure |

### DB Seed (1 SQL file, idempotent)

Path: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Beneficiary-sqlscripts.sql` (preserve `dyanmic` typo)

Contents:
1. **Menu upsert** for `BENEFICIARYLIST` under `CRM_CASEMANAGEMENT` parent @ OrderBy=1 (MenuUrl `crm/casemanagement/beneficiarylist`; MenuName "Beneficiary List"; all 8 capabilities enabled; BUSINESSADMIN role grants READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT). Mark legacy `BENEFICIARYFORM` menu (from MODULE_MENU_REFERENCE.md line 179) as `IsMenuRender=0` (hidden — FLOW screen uses ONE page).
2. **Grid record** `GridCode = BENEFICIARYLIST`, `GridTypeCode = FLOW`, `GridFormSchema = NULL` (FLOW skips schema).
3. **10 GridField rows** matching the 10 grid columns (column header / field code / component name / order / visibility default).
4. **MasterDataType seeds** (17 new TypeCodes):
   - BENEFICIARYSTATUS (7 rows with ColorHex)
   - VULNERABILITYLEVEL (4 rows with ColorHex)
   - PRIMARYNEEDCATEGORY (9 rows)
   - ORPHANSTATUS (4 rows)
   - SPONSORSHIPTYPE (3 rows)
   - ENROLLMENTSTATUS (5 rows)
   - MILESTONESTATUS (3 rows)
   - REFERRALSOURCE (6 rows)
   - EDUCATIONSTATUS (5 rows)
   - GENERALHEALTH (5 rows)
   - HOUSINGTYPE (6 rows)
   - HOUSINGCONDITION (4 rows)
   - INCOMELEVEL (5 rows)
   - DISABILITYTYPE (6 rows)
   - NATIONALITY (9 rows) — only if absent (check existing first)
   - Reuse existing: GENDER, RELATION
5. **Program rows are owned by Program #51's seed** — do NOT duplicate. Beneficiary seed references program codes (`ORPHAN`, `EDUCATION`, `HEALTHCARE`, `WOMEN`, `FOOD`, `VOCATIONAL`, `WATER`, `RELIEF`) that Program #51's seed inserts. If Beneficiary runs BEFORE Program #51, stub in those 8 rows here with the 8 mockup colors (from `.program-badge.{variant}` CSS: `#92400e / #1e40af / #9d174d / #7c3aed / #c2410c / #0d9488 / #0e7490 / #991b1b`) and flag Program #51's seed to reconcile via upsert-by-code.
6. **Optional sample data**: 6 sample Beneficiary rows matching the mockup (Yusuf Hassan / Amira Mohammed / Samuel Ochieng / Fatima Begum / Ahmed Noor / Priya Devi) + child enrollments + household members (so the dev sees populated grid on first load). Idempotent guards via WHERE NOT EXISTS on BeneficiaryCode.

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Beneficiary List
MenuCode: BENEFICIARYLIST
ParentMenu: CRM_CASEMANAGEMENT
Module: CRM
MenuUrl: crm/casemanagement/beneficiarylist
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: BENEFICIARYLIST

# LegacyMenu — hide
MenuCode: BENEFICIARYFORM
ParentMenu: CRM_CASEMANAGEMENT
Action: SET IsMenuRender = 0 (legacy List+Form split not used by FLOW)
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `BeneficiaryQueries` + `ProgramQueries`
- Mutation type: `BeneficiaryMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `beneficiaries(request)` | `PaginatedApiResponse<IEnumerable<BeneficiaryResponseDto>>` | searchText, pageNo, pageSize, sortField, sortDir, isActive, beneficiaryStatusCode (chip), programId, ageGroupCode, genderId, cityId, branchId, assignedStaffId, dateFrom, dateTo |
| `beneficiary(beneficiaryId)` | `BeneficiaryResponseDto` | beneficiaryId (required) |
| `beneficiarySummary()` | `BeneficiarySummaryDto` | — |
| `programs(request)` | `PaginatedApiResponse<IEnumerable<ProgramResponseDto>>` | standard list args |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createBeneficiary` | `BeneficiaryRequestDto` (nested child arrays) | `int` (new ID) |
| `updateBeneficiary` | `BeneficiaryRequestDto` (nested child arrays — diff-persist) | `int` |
| `deleteBeneficiary` | `beneficiaryId: int` | `int` (soft-delete = Archive) |
| `toggleBeneficiary` | `beneficiaryId: int` | `int` (IsActive flip) |
| `updateBeneficiaryStatus` | `{ beneficiaryId, beneficiaryStatusCode, exitDate?, exitReason? }` | `int` — drives terminal-state side-effects |
| `bulkAssignStaff` | `{ beneficiaryIds: int[], assignedStaffId: int }` | `int` (affected-count) |
| `enrollBeneficiaryInProgram` | `{ beneficiaryId, programId, enrollmentStatusCode, assignedStaffId? }` | `int` — used by Add-to-Program modal + grid action |

**Response DTO Fields** (what FE receives in BeneficiaryResponseDto — flattened for grid + nested for detail):

| Field | Type | Notes |
|-------|------|-------|
| beneficiaryId | number | PK |
| beneficiaryCode | string | BEN-XXXX |
| displayName | string | FirstName + ' ' + LastName |
| avatarColor | string | "#hexcode" (deterministic from code) |
| firstName, lastName | string | — |
| dateOfBirth | string \| null | ISO date |
| approximateAge | number \| null | — |
| ageYears | number | Computed |
| ageGroupCode | string | 0-5 / 6-12 / etc. |
| genderId, genderName, genderCode | number/string/string | — |
| nationalityId, nationalityName | number/string | — |
| nationalIdNumber | string | — |
| languages | string | CSV |
| photoUrl | string \| null | — |
| countryId, countryName | number/string | — |
| stateId, stateName | number/string | — |
| cityId, cityName | number/string | — |
| localityId, localityName | number/string | — |
| locationDisplay | string | "City, Country" |
| addressDetails | string | — |
| gpsCoordinates | string | — |
| phone, alternativeContactName, alternativePhone | string | — |
| householdHeadName | string | — |
| relationshipToHeadId, relationshipToHeadName | number/string | — |
| householdSize | number | — |
| orphanStatusId, orphanStatusName, orphanStatusCode | number/string/string | — |
| guardianName, guardianRelationId, guardianRelationName, guardianPhone | — | — |
| primaryNeedCategoryId, primaryNeedCategoryName | number/string | — |
| vulnerabilityLevelId, vulnerabilityLevelName, vulnerabilityLevelCode, vulnerabilityLevelColorHex | — | MasterData projection |
| incomeLevelId, incomeLevelName | number/string | — |
| educationStatusId, educationStatusName, educationGrade, schoolName | — | — |
| generalHealthId, generalHealthName | number/string | — |
| disabilities | string | CSV |
| chronicConditions, lastCheckupDate | — | — |
| housingTypeId, housingTypeName, housingConditionId, housingConditionName | — | — |
| specialNeedsNotes | string | — |
| assignedStaffId, assignedStaffName | number/string | — |
| sponsorshipTypeId, sponsorshipTypeName, sponsorshipTypeCode | — | — |
| sponsorContactId, sponsorName, sponsorCode | — | — |
| sponsorshipAmount, sponsorshipStartDate | — | SERVICE_PLACEHOLDER sourcing |
| photoConsent, dataConsent, consentFormUrl | boolean/string | — |
| referralSourceId, referralSourceName | — | — |
| branchId, branchName | — | — |
| priorityId, priorityName, priorityColorHex | — | — |
| internalNotes | string | — |
| beneficiaryStatusId, beneficiaryStatusName, beneficiaryStatusCode, statusColorHex | — | — |
| enrollmentDate | string | ISO date |
| exitDate, exitReason | — | — |
| outcomeScore | number \| null | 0–100 |
| programNames | string[] | ["Orphan Sponsorship", "Children's Education"] |
| programCodes | string[] | ["ORPHAN", "EDUCATION"] — for badge-list renderer |
| programsCount | number | — |
| activeCasesCount | number | SERVICE_PLACEHOLDER returns 0 until Case #50 |
| servicesReceivedThisYear | number | — |
| guardianDisplayName | string | — |
| tags | string[] | Derived (Overview tab-list) |
| householdMembers | `HouseholdMemberResponseDto[]` | Nested |
| programEnrollments | `ProgramEnrollmentResponseDto[]` | Nested |
| milestones | `MilestoneResponseDto[]` | Nested |
| serviceLogs | `ServiceLogResponseDto[]` | Nested (top 20) |
| documents | `DocumentResponseDto[]` | Nested |
| isActive, createdBy, createdByName, createdDate, modifiedBy, modifiedByName, modifiedDate | inherited | Audit |

**BeneficiarySummaryDto** fields: `totalCount`, `activeCount`, `waitlistCount`, `graduatedCount`, `exitedCount`, `suspendedCount`, `deceasedCount`, `inactiveCount` (derived: suspended+exited+deceased), `activeProgramsCount`, `topProgramsCsv`, `newThisMonthCount`, `momDeltaPercent`, `outcomesAchievedYtd`.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors; case schema migration applies; 7 tables created with FKs and indices
- [ ] `pnpm dev` — no TS errors; page loads at `/[lang]/crm/casemanagement/beneficiarylist`
- [ ] Menu appears in sidebar under Case Management at OrderBy=1

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 10 columns (checkbox / Ben. ID / Name avatar + subline / Age / Gender / Programs badge-list / Location / Sponsor / Status / Enrolled / Actions)
- [ ] 4 KPI widgets render with correct values (Total / Programs Active / New This Month with MoM delta / Outcomes Achieved)
- [ ] 7 filter chips work (All/Active/Waitlist/Graduated/Exited/Suspended/Deceased); active chip has teal bg; click refetches
- [ ] Advanced filter panel toggles; 6 selects apply filter args; Apply fires refetch; Clear resets
- [ ] Search bar filters by name/code/phone
- [ ] Bulk-select checkbox shows bulk bar; Export / Assign Staff / Send Communication work (Assign Staff fires real bulk mutation; other 2 are SERVICE_PLACEHOLDER toast)
- [ ] Actions dropdown per row: 7 items; Create Case navigates with beneficiaryId param (SERVICE_PLACEHOLDER toast if Case #50 unbuilt); Enroll button shown only when status=Waitlist
- [ ] Row click navigates to `?mode=read&id={id}` (checkbox click does NOT navigate)
- [ ] `?mode=new` — empty FORM with 7 accordion sections, all expanded; section toggle works
- [ ] Personal Info (§1) fields; Photo upload zone visible (SERVICE_PLACEHOLDER if infra absent)
- [ ] Location & Contact (§2) cascade works: Country → State → City → Locality
- [ ] Family/Household (§3): HouseholdSize required; inline child grid add/remove row works; Also-a-Beneficiary checkbox toggles BEN badge
- [ ] Needs Assessment (§4): conditional requires (Enrolled → Grade+School required); Disabilities multi-select
- [ ] Program Enrollment (§5): eligibility cards auto-compute from assessment answers; toggle checkbox + dropdown; SponsorshipType=IndividualSponsor reveals Sponsor picker
- [ ] Consent & Documents (§6): consent checkboxes required for Active; file upload zones (SERVICE_PLACEHOLDER)
- [ ] Internal (§7): Branch required; Priority auto-populated from VulnerabilityLevel
- [ ] Save creates Beneficiary + child collections atomically → URL → `?mode=read&id={newId}` → DETAIL layout
- [ ] `?mode=edit&id=X` — FORM pre-filled across all 7 sections including child grids + eligibility cards
- [ ] `?mode=read&id=X` — DETAIL layout with avatar header + status pill + 5 Quick Stats + 6 tabs
- [ ] Tab Overview: Personal Info + Needs Assessment Summary side-by-side; Tags badge-list
- [ ] Tab Programs & Services: 3 stacked cards with mini-grids
- [ ] Tab Cases: mini-grid or empty state (SERVICE_PLACEHOLDER if Case #50 unbuilt)
- [ ] Tab Sponsorship: 2-col with info-list + payment history (SERVICE_PLACEHOLDER)
- [ ] Tab Documents: doc-grid with upload button (SERVICE_PLACEHOLDER for actual file upload)
- [ ] Tab Timeline: aggregates events with color-coded dots
- [ ] Edit from detail → `?mode=edit&id={id}` → Save → back to detail
- [ ] FK dropdowns load via ApiSelectV2 (contacts/staffs/branches/countries/states/cities/localities/masterDatas × N/programs)
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] Permissions: Edit/Delete/Archive respect BUSINESSADMIN role grants

**DB Seed Verification:**
- [ ] Menu "Beneficiary List" visible in sidebar under Case Management
- [ ] Legacy `BENEFICIARYFORM` menu is hidden (IsMenuRender=0)
- [ ] All 17 MasterData TypeCodes + values seeded with correct ColorHex
- [ ] 8 Program rows seeded
- [ ] Grid row for BENEFICIARYLIST exists (GridTypeCode=FLOW, GridFormSchema=NULL)
- [ ] 10 GridField rows exist in correct order
- [ ] (Optional) 6 sample Beneficiary rows visible on fresh seed

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** in any entity — resolved from `HttpContext` on mutations
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout, read has DETAIL layout with 6 tabs (completely different UI)
- **DETAIL is a separate UI**, not the form disabled — DO NOT wrap form in fieldset
- **THIS IS THE FIRST ENTITY IN THE `case` SCHEMA** — build-screen MUST execute new-module bootstrap per DEPENDENCY-ORDER.md § "For each new module…" (ICaseDbContext + CaseDbContext + CaseMappings + IApplicationDbContext inheritance + DependencyInjection register + DecoratorCaseModules + GlobalUsing × 3)
- **Existing FE route stub** at `[lang]/crm/casemanagement/beneficiarylist/page.tsx` (5 lines `<div>Need to Develop</div>`) — OVERWRITE with real index.tsx wrapper
- **Hidden legacy menu**: `BENEFICIARYFORM` (MenuId under CRM_CASEMANAGEMENT per MODULE_MENU_REFERENCE.md line 179) — set `IsMenuRender=0` since FLOW uses single page
- **FK target groups**: Contact → `ContactModels` (schema `cont`); Staff/Branch → `ApplicationModels` (schema `app`); MasterData/Country/State/City/Locality → `SharedModels`/`SettingModels` (schema `shared`); Program → `CaseModels` (schema `case`, NEW)
- **Chip filter implementation**: pass as TOP-LEVEL GQL arg `beneficiaryStatusCode`, NOT via `advancedFilter` payload — precedent: Family #20 ISSUE-13
- **FE folder name**: `beneficiarylist` (matches existing stub + MenuUrl + MODULE_MENU_REFERENCE.md convention), NOT `beneficiary`
- **Seed folder typo preservation**: `sql-scripts-dyanmic/` (typo — NOT `dynamic`). Precedent: ChequeDonation #6, Pledge #12, Refund #13
- **Variant B MANDATORY** (mockup shows widgets above grid) — ScreenHeader + widgets + DataTableContainer showHeader=false. Precedent: ContactType #19 session-2 fix, DonationInKind #7
- **Program badge color-by-value**: Program entity carries `ColorHex` (per-row) — badge renderer reads hex and applies inline style rather than CSS class (policy exception, colors ARE data; precedent: Tag #22 ISSUE-5, DonationCategory #3)
- **UI uniformity**: use `ph:*` (Phosphor) icon set per UI uniformity memory, NOT `fa-*`. Convert mockup `fa-*` to `ph:*` equivalents in the FE implementation (precedent: Pledge #12 ISSUE-8)
- **ALIGN vs FULL**: This is FULL — no existing BE code to align against; only a 5-line FE stub. Build from scratch using SavedFilter + Pledge + Contact patterns.

### Known Issues (pre-flagged by /plan-screens)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | **HIGH** | BE (build-order dependency) | Program entity (registry #51 Wave 1) is `PROMPT_READY` but NOT yet built as of 2026-04-21. `BeneficiaryProgramEnrollment.ProgramId`, `BeneficiaryMilestone.ProgramId`, `BeneficiaryServiceLog.ProgramId` all FK `case.Programs`. **Resolution**: run `/build-screen #51` (Program) BEFORE `/build-screen #49` (Beneficiary) — this is the clean path. If the reverse happens, see §⑧ "If Beneficiary is built BEFORE Program #51" — Beneficiary's build owns the full case-schema bootstrap and stands up a minimal Program stub (to be expanded by Program #51's later migration). The clean path is strongly preferred. | OPEN |
| ISSUE-2 | MED | BE (dependency) | Case entity (#50) does NOT exist. `activeCasesCount` projection must degrade gracefully (return 0 via EF guard rather than crash). Cases detail tab must render empty state with "No cases yet" when query returns nothing. Create-Case action (grid kebab + More dropdown) becomes SERVICE_PLACEHOLDER toast until Case #50 is built. | OPEN |
| ISSUE-3 | MED | BE (sponsorship) | Sponsorship domain not wired — no SponsorshipContract / RecurringSponsorPayment entities. `sponsorshipAmount` / `sponsorshipStartDate` / Payment History tab are SERVICE_PLACEHOLDERs. Future: link to RecurringDonationSchedule #8 where Contact=Sponsor + DonationPurpose=Sponsorship. | OPEN |
| ISSUE-4 | MED | FE/BE | File upload infrastructure check required — Contact #18, Pledge #12, etc. use URL-string storage fallback. Verify whether multipart/form-data pipeline exists for Photo, ConsentForm, Documents tab, SupportingDocuments. If absent → SERVICE_PLACEHOLDER handler shows toast "Upload coming soon" + accept URL input as fallback. | OPEN |
| ISSUE-5 | MED | BE | `NATIONALITY` MasterData may not be pre-seeded. Verify against existing seed before adding (to avoid duplicates). Seed 9 mockup values only if absent. | OPEN |
| ISSUE-6 | MED | FE | Eligibility Cards client-side logic hard-codes 8 Program codes. When Program #51 adds new programs, eligibility rules need an extension hook. MVP: ship with the 8-rule map; flag for follow-up generalization to a BE-driven rule engine or rules stored on the Program record itself. | OPEN |
| ISSUE-7 | MED | FE | Timeline tab event aggregation is client-side (merges 5+ child arrays by date). For beneficiaries with thousands of events, this would be slow. MVP: cap at most-recent 50 per child type; flag for pagination/virtualization later. | OPEN |
| ISSUE-8 | MED | BE | `programCodes[]` + `programNames[]` projections in GetAll require Include + Select on BeneficiaryProgramEnrollments + Program joins. Verify no N+1 — use .Include(x => x.BeneficiaryProgramEnrollments).ThenInclude(e => e.Program) pattern. | OPEN |
| ISSUE-9 | MED | FE | Household-members self-reference (`LinkedBeneficiaryId` when IsAlsoBeneficiary=true) — cannot be populated on initial Create for new siblings who don't exist yet. On Edit, offer a picker showing same-last-name candidates from `contacts` or `beneficiaries`. MVP: allow user to manually paste BEN code + resolve on save. | OPEN |
| ISSUE-10 | LOW | BE | `OutcomeScore` computed score formula stub `ACHIEVED_milestones / TOTAL_milestones × 100` — if a beneficiary has zero milestones, render NULL. Refine formula in Wave 4 (Engagement Scoring / AI Intelligence screen #90). | OPEN |
| ISSUE-11 | LOW | FE | Bulk "Send Communication" SERVICE_PLACEHOLDER — when SMS Campaign #30 / WhatsApp Campaign #32 are wired to accept contact arrays, this can deep-link to those screens with pre-selected beneficiary recipients. | OPEN |
| ISSUE-12 | LOW | DB | Seed folder typo: `sql-scripts-dyanmic/` (NOT `sql-scripts-dynamic`) — preserve to match ChequeDonation #6, Pledge #12, Refund #13 precedent. | PRESERVE |
| ISSUE-13 | LOW | FE | Disabilities multi-select persists as CSV of codes in a single column. Flag for potential normalization (child table `BeneficiaryDisability`) if reporting/queries grow. | OPEN |
| ISSUE-14 | MED | FE | `Add to Program` modal duplicates the eligibility-card UX from FORM §5 but without auto-eligibility check (used post-registration in DETAIL). Ensure `beneficiaryProgramEnrollments[]` is kept in sync when this modal adds a row (cache update or refetch). | OPEN |
| ISSUE-15 | LOW | BE | `BeneficiaryHouseholdMember.LinkedBeneficiaryId` is self-referencing FK within the same schema. EF Core may need explicit `OnDelete(DeleteBehavior.NoAction)` to avoid cycle errors on migration generation. | OPEN |

### Service Dependencies (UI-only — no backend service implementation)

Full UI must be built. Only these specific handlers are mocked:

- ⚠ SERVICE_PLACEHOLDER: **Photo upload** (form §1) — full drag-drop UI implemented. If file-upload pipeline doesn't exist yet, handler shows toast and accepts URL input fallback. Persists as `PhotoUrl` string.
- ⚠ SERVICE_PLACEHOLDER: **Consent Form upload** + **Supporting Documents upload** (form §6) — same as above. Metadata-only persistence via URL string until file pipeline wired.
- ⚠ SERVICE_PLACEHOLDER: **Documents tab Upload button** (detail) — same pattern.
- ⚠ SERVICE_PLACEHOLDER: **Export** (grid top-right + bulk bar) — platform-wide CSV export unimplemented. Handler shows toast.
- ⚠ SERVICE_PLACEHOLDER: **Send Communication** (bulk bar) — SMS/WhatsApp/Email bulk send not wired for Beneficiary recipients. Handler shows toast. Future: deep-link to SMS Campaign #30.
- ⚠ SERVICE_PLACEHOLDER: **Generate Report** (grid kebab + detail More dropdown) — reports pipeline (PowerBI / HtmlReport #96) not wired. Handler shows toast.
- ⚠ SERVICE_PLACEHOLDER: **Create Case** (grid kebab + detail More dropdown + Cases tab empty-state CTA) — Case entity #50 not built. Handler shows toast; when Case #50 completes, replace with `router.push('/[lang]/crm/casemanagement/caselist?mode=new&beneficiaryId={id}')`.
- ⚠ SERVICE_PLACEHOLDER: **Sponsorship Payment History** (Sponsorship tab) — sponsorship domain not wired. Render empty state with copy.
- ⚠ SERVICE_PLACEHOLDER: **Print** (detail More dropdown) — uses `window.print()` against DETAIL DOM as minimal MVP; dedicated print layout deferred.

Everything else (KPI widgets, filter chips, advanced filter panel, bulk-select, grid columns including program badge-list, 7-section form with nested children, eligibility card auto-compute, Sponsor picker conditional, 6-tab detail, timeline aggregation from internal child tables, Add-to-Program modal, Assign Staff bulk mutation, status transitions including Waitlist → Active Enroll button) is FULL build scope — not placeholders.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

See §⑫ table above — ISSUE-1 through ISSUE-15 pre-flagged by /plan-screens.

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}