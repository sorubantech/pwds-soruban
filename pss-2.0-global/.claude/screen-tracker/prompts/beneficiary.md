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
last_session_date: 2026-06-23
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

### Session 0 — 2026-04-24 — BUILD — COMPLETED (retroactive)

- **Scope**: Initial full FLOW build (BE + FE + DB seed) generated via Sonnet per /build-screen → /generate-screen. Retro-entry synthesized by /continue-screen (Build Log was not written at build time per token-budget directive).
- **Files touched**: (retroactive — not recorded in detail; see §⑧ File Manifest for the canonical 21 BE + 20 FE + seed file set)
- **Deviations from spec**: EF migration SKIPPED per user token-budget directive; `dotnet build` + `pnpm dev` smoke + full E2E verification SKIPPED this session (§ Verification checklist left unchecked).
- **Known issues opened**: ISSUE-1 … ISSUE-15 (pre-flagged by /plan-screens — see §⑫).
- **Known issues closed**: None.
- **Next step**: Run full E2E verification + EF migration before production-ready.

### Session 1 — 2026-06-17 — UI — COMPLETED

- **Scope**: Align Beneficiary form & index with Program #51's design — (1) restyle accordion `FormSection` to Program's flat header-bar look (kept expand/collapse), (2) match in-section field grid spacing (gap-3 → gap-4) and body padding (`p-4`), (3) remove duplicate Export button from index ScreenHeader (grid toolbar `enableExport` is the single export), (4) add Program-style bottom-center floating action pill to the form (add + edit) and drop the header's duplicate Save button, (5) replace raw `<textarea>` ×3 and raw consent `<input type=checkbox>` ×2 with canonical `FormTextarea` / `FormCheckbox`, (6) **fix section "merge" look** — the form was wrapped in an overall `bg-card`, so the white section cards blended in; now the form renders on a grey `bg-background` canvas (add: wrapper bg-card→bg-background+p-4; edit: OverviewTab wraps formContent in `-m-4 bg-background p-4` to bleed the white tab panel) with `space-y-4` between sections, so each white section card floats with a visible gap exactly like #51. (7) **Save-button gating** — useForm now `mode:"onChange"`; floating pill Save (+ Register & Add Another) gated by `canSave = isEdit ? isValid && isDirty : isValid` — create needs all required fields valid, edit needs a real change (unchanged values keep Save disabled), matching Program #51's `onCanSubmitChange`. (8) **Consent & Documents** section icon was invalid (`ph:file-signature-duotone` doesn't exist → blank) — replaced with `ph:file-text-duotone`. (9) **DOB date picker** — Date of Birth swapped from `FormDatePicker` to `FormDatePickerDropdown` (year/month/date dropdowns, `previousYears={100}` `nextYears={0}`, `dd/MM/yyyy` display / `yyyy-MM-dd` value) matching the Contact form's DOB field; `parseISO` handles edit pre-fill from full-ISO or date-only, save round-trip unchanged. Other date fields (lastCheckupDate/enrollmentDate) keep the standard `FormDatePicker`. (10) **SHARED z-index bug fix** — `common-components/molecules/Calender` dropdown year/month `SelectContent` was `z-[10001]` while the calendar `PopoverContent` portals to body at inline `zIndex:100000`, so the year/month list opened *behind* the calendar (latent app-wide bug, also affects Contact DOB). Bumped to `z-[100001]`. Pure bug fix — only raises a too-low dropdown; benefits every `captionLayout="dropdown"` date picker. (11) **Age auto-calc from DOB** — `useWatch("dateOfBirth")` + effect derives whole-year age and `setValue("approximateAge", …, {shouldValidate:true})` (recomputes only on DOB change, doesn't mark form dirty); Age field relabeled "Age" + `min={0}` + helperText "Auto-calculated from Date of Birth — you can override it if DOB is unknown" so it stays editable (DOB-unknown path). setValue writes a real number (no Int-coercion regression).
- **Files touched**:
  - BE: None.
  - FE:
    - `…/casemanagement/beneficiarylist/beneficiary/beneficiary-form.tsx` (FormSection restyle + FieldRow gap-4 + root space-y-4 + FormTextarea×3 + FormCheckbox×2; consent section icon fix; DOB → FormDatePickerDropdown; DOB→age auto-calc effect; removed unused `Label`/`register`)
    - `…/common-components/molecules/Calender/index.tsx` ⚠ SHARED — dropdown year/month `SelectContent` z-index `z-[10001]` → `z-[100001]` (was opening behind the calendar popover; app-wide bug fix)
    - `…/casemanagement/beneficiarylist/beneficiary/index-page.tsx` (removed ScreenHeader Export `headerActions` + `handleExport` + unused `Button`/`Icon`/`toast` imports)
    - `…/casemanagement/beneficiarylist/beneficiary/view-page.tsx` (added `BeneficiaryFormActionPill` w/ `canSave` gating; useForm `mode:"onChange"`; add + edit modes use floating pill, header save removed; `pb-24` on scroll bodies; add-mode canvas bg-card→bg-background+p-4)
    - `…/casemanagement/beneficiarylist/beneficiary/detail/tabs/overview-tab.tsx` (edit-mode formContent wrapped in `-m-4 bg-background p-4` grey canvas)
  - DB: None.
- **Deviations from spec**: None — §⑥ Blueprint's "7 accordion sections" and "3 header action buttons" intent preserved; the 3 form actions now live in the floating pill (Cancel / Register & Add Another / Register Beneficiary) mirroring Program #51.
- **Known issues opened**: None.
- **Known issues closed**: None (ISSUE-1…15 are functional/data items, untouched by this UI pass).
- **Verification**: Static consistency check passed (no dangling imports/refs). Full `tsc --noEmit` deferred at user request (slow on this Next app); recommend a `pnpm dev` smoke on `/[lang]/crm/casemanagement/beneficiarylist` (index export single-source + `?mode=new` floating pill + collapsible sections).
- **Next step**: None.

### Session 2 — 2026-06-17 — FIX — COMPLETED

- **Scope**: Fix DOB (and all dropdown-caption) date pickers reopening on **today's** month/year instead of the already-selected date — after picking a DOB, reopening the calendar to change it showed the current month, not the stored value.
- **Root cause**: `FormDatePickerDropdown` passed `selected={selectedDate}` to react-day-picker but no `defaultMonth`. In react-day-picker, `selected` does NOT navigate the displayed month; `defaultMonth` (defaulting to today) controls it. Because the Radix Popover unmounts its content on close, every reopen remounts `Calendar` and re-defaulted to today.
- **Fix**: Added `defaultMonth={selectedDate}` to both `Calendar` instances (RHF + standalone) in `FormDatePickerDropdown`. On reopen the calendar now lands on the selected date's month/year (falls back to today when empty).
- **Files touched**:
  - BE: None.
  - FE:
    - `…/custom-components/form-fields/FormDatePickerDropdown.tsx` ⚠ SHARED — added `defaultMonth={selectedDate}` to both Calendar usages (app-wide bug fix; benefits every dropdown-caption date picker incl. Contact DOB).
  - DB: None.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: Static review — `defaultMonth` is a valid react-day-picker prop already imported via `Calendar`. Recommend `pnpm dev` smoke: pick a DOB, reopen → calendar shows that month/year, not today.

### Session 3 — 2026-06-17 — UI — COMPLETED

- **Scope**: Add staff-facing helper text so case workers understand each field's business purpose — a one-line **description** under every section header (all 7) plus inline `helperText` on the non-obvious fields.
- **Implementation**:
  - Extended the local `FormSection` with an optional `description` prop, rendered as a `text-xs text-muted-foreground` line under the title (icon/chevron given `shrink-0`; title+description stacked in a flex-1 column). Added a business-purpose line to all 7 sections (Personal, Location & Contact, Family/Household, Needs Assessment, Program Enrollment, Consent & Documents, Internal).
  - Added `helperText` to fields whose meaning isn't self-evident: DOB (age driver / leave blank if unknown), National ID (optional — undocumented), Language (case-worker match), GPS (home visits), Alternative Contact (backup channel), Household Size (per-household aid), Orphan Status (reveals guardian fields), Primary Need, Vulnerability Level (auto-suggests Priority), Education Status (reveals grade/school), Assigned Staff, Sponsorship Type (reveals sponsor + amount), Referral Source, Branch, Status, Enrollment Date. Existing helper text on Age and Priority left as-is.
  - Guardian sub-heading gained a muted explanatory line ("Required for orphans and minors…").
- **Files touched**:
  - BE: None.
  - FE:
    - `…/beneficiarylist/beneficiary/beneficiary-form.tsx` — `FormSection` `description` prop + section descriptions + per-field `helperText` (uses the shared form-field components' existing `helperText` support; no shared component changed).
  - DB: None.
- **Deviations from spec**: None — additive UX copy only, no field/schema/flow changes.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: Static review — every form-field component (`FormInput`, `FormSearchableSelect`, `FormDatePicker`, `FormDatePickerDropdown`, `FormTextarea`) already accepts and renders `helperText` (muted line below the control, replaced by error when present). Recommend `pnpm dev` smoke: open New/Edit Beneficiary → each section shows its purpose line and the annotated fields show their helper text.
- **Next step**: None.

### Session 4 — 2026-06-17 — ENHANCE — COMPLETED (⚠ needs BE build + migration by user)

Four review items raised by the user on form data sources. Decisions taken by the agent where delegated.

1. **Relationship fields use the real Relations master, not MasterData (Q1).** `Relationship to Head` and `Guardian Relationship` previously read `MASTERDATAS_QUERY` (typeCode=`RELATION`). The canonical lookup is the shared `com.Relations` table (`RELATIONS_QUERY`, used by Contact). **BE FK repointed** `MasterData → Relation`: `Beneficiary.RelationshipToHead` + `GuardianRelation` navs, FK-validation (`_dbContext.Relations`, `r.RelationId`), and GetById display projections (`.DataName → .RelationName`). FE selects switched to `RELATIONS_QUERY` (valueColumn `relationId`, orderColumn `orderBy`, active filter, `initialOption` from `*Name`).
2. **Household grid loads real lookups + drops dead column (Q2).** Grid Gender was a hardcoded `<select>` (1/2/3) → now `GENDERS_QUERY`; Relationship was free-text → now `RELATIONS_QUERY` bound to the **already-existing** `RelationId`. Per user, **`RelationshipName` column DROPPED entirely** (memberName + relationId suffice; display name comes from the Relation join `RelationName`): removed from domain entity, request DTO, EF config (`HasMaxLength`), Create/Update mappings, FE DTO, both FE request mappers, and the BY_ID GraphQL selection (replaced with `relationName`). HouseholdMember `Relation` nav also repointed `MasterData → Relation`.
3. **"Also Beneficiary?" links a real beneficiary (user follow-up).** Replaced the free-typed BEN-code input with a `FormSearchableSelect` on `BENEFICIARIES_QUERY` → stores **`linkedBeneficiaryId` only**; label shows `code - name` via `labelFormatter`. No `beneficiaryCode` text round-trips (it's a response-only field; removed from request mappers).
4. **Assigned Staff = all active staff (Q3, agent decision).** Org-level case-worker role, assigned at intake before enrollment; added `isActive` filter. (Not scoped to program team — that would block assignment pre-enrollment.)
5. **Sponsorship removed from the beneficiary root form (Q4, agent decision).** Duplicated Program #51's funding model (amount in 3 places) and doesn't fit multi-program enrollment. The dedicated **sponsor-details-modal + sponsorship-tab** already manage it post-creation, so the form block was pure duplication. DTO/BE columns retained (untouched); only the form UI + `_sponsorshipTypeCode` watch + `SPONSOR_TYPE_FILTER`/`CONTACTS_QUERY` imports removed.

- **Files touched**:
  - BE (⚠ user builds): `Beneficiary.cs`, `BeneficiaryHouseholdMember.cs` (nav types + drop RelationshipName); `BeneficiaryConfiguration.cs`, `BeneficiaryHouseholdMemberConfiguration.cs` (comments + drop RelationshipName property map); `BeneficiarySchemas.cs` (drop RelationshipName from request DTO); `CreateBeneficiary.cs`, `UpdateBeneficiary.cs` (FK-validation → Relations; drop RelationshipName map); `GetBeneficiaryById.cs` (`.DataName → .RelationName`).
  - FE: `beneficiary-form.tsx`, `household-members-grid.tsx`, `beneficiary-update-helper.ts`, `view-page.tsx` (create mapper), `BeneficiaryDto.ts`, `BeneficiaryQuery.ts`.
- **Deviations from spec**: This changes BE FK targets + drops a column (Spec-level). Done in-session at user direction rather than via `/plan-screens`.
- **Known issues opened**: None. **Known issues closed**: None.
- **Verification**: FE — static sweeps confirm no dangling `relationshipName`/sponsorship refs; picker query compat checked (`advancedFilter` undefined is ignored; only pageSize/pageIndex required). BE — **user is building**.
- **⚠ MIGRATION REQUIRED (user)**: EF migration must (a) repoint FKs `case.Beneficiaries.RelationshipToHeadId` + `GuardianRelationId` and `case.BeneficiaryHouseholdMembers.RelationId` from `setting.MasterDatas` → `com.Relations` (drop old FK, add new FK), and (b) drop column `case.BeneficiaryHouseholdMembers.RelationshipName`. **Data caveat**: existing relation FK values reference MasterData IDs and will be invalid against com.Relations — clear/re-map them pre-prod.
- **Next step**: After BE build + migration, `pnpm dev` smoke: relation dropdowns populate from Relations; household Gender/Relationship are real dropdowns; "Also Beneficiary" picker shows `code - name` and saves the link; Assigned Staff lists active staff; no sponsorship block on the form.

### Session 5 — 2026-06-17 — ENHANCE — COMPLETED (⚠ needs BE build + seed by user)

Two user items: (a) Beneficiary status should be workflow-driven, not a form field; (b) BeneficiaryCode should auto-generate via the NumberSequence system like ProgramCode (#51).

1. **Status is workflow-controlled, not a form field.** Confirmed the BE already has the lifecycle: BENEFICIARYSTATUS = Draft(DFT)→Active(ACT)→Waitlist(WL)/Graduated(GRD)/Exited(EXT)/Suspended(SUS)/Deceased(DEC), plus a dedicated `UpdateBeneficiaryStatusCommand` (transitions by code, with terminal-state side-effects: Graduated closes enrollments, Deceased soft-deletes household links, ExitDate stamping) — already wired to the grid status action + `beneficiary-status-badge`. **Changes**: removed the `Status` `FormSearchableSelect` from the form (§7 Internal) — Enrollment Date kept; removed unused `STATUS_FILTER`; made `beneficiaryStatusId` zod `.nullable().optional()`. BE `CreateBeneficiary`: dropped the `BeneficiaryStatusId` required + FK validations and now **defaults to Draft (DFT)** server-side (resolves MasterData by `MasterDataType.TypeCode='BENEFICIARYSTATUS' && DataValue='DFT'`). Edit preserves the loaded status (round-trips unchanged); transitions only via `UpdateBeneficiaryStatus`. FE "Save as Draft" button + `draftStatusId` left intact (still explicitly creates Draft).
2. **BeneficiaryCode via NumberSequence (mirrors ProgramCode).** Replaced the fragile `BEN-{MAX(code)+1:D4}` string-sort in `CreateBeneficiary` with `NumberSequenceGenerator.GenerateAsync(db, companyId, "BENEFICIARY", EnrollmentDate, ct)`, wrapped the parent+children save in `CreateExecutionStrategy().ExecuteAsync` + `BeginTransactionAsync`/`Commit` (generator needs an open txn; manual txns illegal under the retrying strategy — see [[reference_npgsql_execution_strategy_transactions]]). Format `BEN-{YYYY}-{SEQ:000000}` (e.g. BEN-2026-000001), YEARLY reset. FE already treats BeneficiaryCode as read-only/auto (display only) — no FE change needed. Seed added to `NumberSequenceEntityType-sqlscripts.sql` (STEP 5/6: register `BENEFICIARY` EntityType + system-default NumberSequenceEntityType), mirroring PROGRAM. Extends [[reference_numbersequence_extend_new_entity]].
- **Files touched**:
  - BE (⚠ user builds): `CreateBeneficiary.cs` (drop status validations, default Draft, NumberSequence code-gen in execution-strategy txn); `sql-scripts-dyanmic/NumberSequenceEntityType-sqlscripts.sql` (BENEFICIARY seed — ⚠ user applies).
  - FE: `beneficiary-form.tsx` (remove Status field + STATUS_FILTER), `view-page.tsx` (zod status optional).
- **Deviations from spec**: None beyond the agreed direction. No EF migration needed (NumberSequence tables already exist; status change is logic-only).
- **Known issues opened/closed**: None.
- **Verification**: FE — sweeps confirm no dangling `STATUS_FILTER`/status-field refs; Save-as-Draft path intact. BE — **user is building**; brace balance verified (23/23), `MasterData.MasterDataType.TypeCode` nav confirmed.
- **⚠ USER STEPS**: (1) build BE; (2) **apply the NumberSequence seed** (`NumberSequenceEntityType-sqlscripts.sql` STEP 5/6) so `GenerateAsync("BENEFICIARY")` returns a code — without it BeneficiaryCode stays empty and could violate uniqueness; (3) ensure `Draft`/`DFT` exists in BENEFICIARYSTATUS master (seed already has it). No migration for this session (the Session 4 migration is still separately pending).
- **Next step**: After BE build + seed, smoke: create a beneficiary → no Status field on form; saved record gets `BEN-2026-000001` and starts in Draft; grid status action moves Draft→Active etc.
- **Next step**: None.

### Session 6 — 2026-06-17 — FIX — COMPLETED (⚠ needs BE build by user)

Four user items.

1. **Bug `"Variable beneficiaryStatusId is required"` (regression from S5).** After removing the Status field, the create/update mutation still declared `$beneficiaryStatusId: Int!`, and the BE request DTO field was non-nullable `int` (→ HC forces `Int!`). **Fix**: FE mutation var → `Int` (Create + Update); BE `BeneficiarySchemas` request DTO `BeneficiaryStatusId` → `int?`. `CreateBeneficiary` already defaults Draft when `<=0`. `UpdateBeneficiary` now **preserves** the existing status across `Adapt` (captures `existing.BeneficiaryStatusId`/`BeneficiaryCode` before, restores after) and its status required+FK validations removed — the main update never changes status (only `UpdateBeneficiaryStatus` does).
2. **Country-specific phone digit validation (#1).** Reused the canonical `application/configs/validation-configs/phone-validation-rules.ts` (`validatePhoneByCountry` / `getPhonePlaceholder`, keyed by country STD code). The form already resolves `countryStdCode` (COUNTRY_BY_ID_QUERY) for address visibility — now also **published to the beneficiary store** (`setCountryStdCode`). Phone fields (`phone`, `alternativePhone`, `guardianPhone`) get dynamic placeholders; `view-page.handleSave` + `handleSaveAndAddAnother` call a new `validatePhones()` that reads `countryStdCode` from the store and `form.setError`s any invalid number before submit (empty/no-rule countries pass through).
3. **Save button had no loading state (#3).** `handleSave` is called directly (not via `form.handleSubmit`), so RHF's `isSubmitting` never flipped → the pill's existing "Saving…" spinner never showed. **Fix**: capture `loading` from both `useMutation` hooks (`creating`/`updating`), `const saving = creating || updating`, and pass `isSubmitting={isSubmitting || saving}` to both action pills. Success/error toasts already existed.
4. **Enrollment Date vs program enrollment (#2).** The Internal `enrollmentDate` is the **beneficiary-level intake/registration date** (BE defaults it to today) — *separate* from per-program `enrolledOn` collected in the Add-to-Program modal (Waitlist/Enroll Now). They are not related; a beneficiary can enroll in multiple programs each with their own date. User delegated the call → **relabeled the form field to "Registration / Intake Date"** (kept as a real editable field so staff can backdate paper registrations — auto-setting would remove that) + clarifying helper text; zod message updated. Field name (`enrollmentDate`) and BE unchanged.

- **Files touched**:
  - BE (⚠ user builds): `BeneficiarySchemas.cs` (`BeneficiaryStatusId` → `int?`); `UpdateBeneficiary.cs` (preserve status across Adapt; drop status validations).
  - FE: `BeneficiaryMutation.ts` (status var `Int`), `beneficiary-store.ts` (`countryStdCode` slice), `beneficiary-form.tsx` (publish std code + dynamic phone placeholders), `view-page.tsx` (`validatePhones`, mutation loading → pill, store std code).
- **Deviations from spec**: None. **Known issues opened/closed**: None.
- **Verification**: FE static — `validatePhones` defined before use; `saving` wired to both pills; phone util reused (not reimplemented). BE — **user builds**; confirmed no non-comment `BeneficiaryStatusId` `<…,int>` validations remain (would mismatch `int?`).
- **Next step**: None. (Pending across sessions: S4 migration + S5 NumberSequence seed, both user-applied.)

### Session 7 — 2026-06-17 — ENHANCE — COMPLETED (⚠ needs BE build by user)

User asked how/where the enrollment status changes and how it ties to case creation, wanting "the case management flow to properly come and status to properly change." Investigated, then wired the orchestration (agent-decided business rules, user delegated).

**Findings (three independent status systems, previously unlinked):** beneficiary status (DFT/ACT… via grid `UpdateBeneficiaryStatus`), program-enrollment status (ENROLLED/WAITLISTED… edited on beneficiary detail → Programs & Services tab via the Enrollment modal, which submits the full `UPDATE_BENEFICIARY`), and case status (CASESTATUS via Case screen). Enrollment status changes on the **Beneficiary screen**, never the Case screen. `EnrollBeneficiaryInProgram` (add-program "Enroll Now"/"Waitlist") always INSERTs; existing-enrollment edits flow through `UpdateBeneficiary`'s `SyncProgramEnrollments`.

**Implemented links:**
1. **Activate enrollment → beneficiary Draft→Active (Link A).** When a beneficiary gains an `ENROLLED` (non-waitlist) enrollment, auto-promote DFT→ACT. Added to BOTH paths: `EnrollBeneficiaryInProgram` (when the new enrollment resolves to ENROLLED) and `UpdateBeneficiary` (after `SyncProgramEnrollments`, if status is DFT and any enrollment is ENROLLED). Waitlisting does NOT promote. Codes: BENEFICIARYSTATUS DFT/ACT, ENROLLMENTSTATUS ENROLLED/WAITLISTED (UPPERCASE DataValue).
2. **Gate case creation on Draft (Link B).** `CreateCase` now throws `BadRequestException` ("…Enrol them in a program to activate the beneficiary before opening a case.") if the beneficiary is still DFT. Placed BEFORE the handler's try so the 400 isn't rewrapped as 500. No auto-create-case (deliberately — too noisy/opinionated).

**Resulting flow:** register → Draft (auto BEN code) → enrol: "Add to Waitlist" keeps Draft / "Enroll Now" (or edit Waitlist→Enrolled on Programs tab) → **beneficiary auto-Active** → now a Case can be opened (blocked while Draft) → Case Open→Closed on Case screen → terminal beneficiary transitions (Graduated closes enrollments etc.) via existing grid status action.
- **Files touched**: BE (⚠ user builds): `EnrollBeneficiaryInProgram.cs`, `UpdateBeneficiary.cs` (auto-promote), `CreateCase.cs` (Draft gate). FE: none.
- **Deviations from spec**: Adds cross-entity workflow rules (beneficiary↔enrollment↔case) not in the original blueprint — done at user direction.
- **Known issues opened**: `EnrollBeneficiaryInProgram` always INSERTs a new enrollment (no update-existing path) — fine for "add", but a "Waitlist→Active" action that routes here (vs the Programs-tab edit) would duplicate. Current FE edit path uses `UpdateBeneficiary` (correct), so not hit today. Left as a note.
- **Verification**: BE — brace balance UpdateBeneficiary 42/42, EnrollBeneficiaryInProgram 12/12, CreateCase 11/11; `BadRequestException`/`InternalServerException` both in `Base.Application.Exceptions` (resolves). **User builds.**
- **Optional follow-up**: filter the Case-form beneficiary picker to exclude Draft beneficiaries (proactive UX vs the current save-time 400).
- **Next step**: None.

### Session 8 — 2026-06-17 — FIX — COMPLETED

- **Scope**: Editing a beneficiary record crashed with `Cannot read properties of null (reading 'map')` in `HouseholdMemberRow`.
- **Root cause**: `useGenericQuery` returns `items` as `null`/`undefined` until the Gender/Relation lookups resolve. The household grid renders existing rows immediately on edit, and `HouseholdMemberRow` called `genders.map(...)` / `relations.map(...)` directly on the still-null value.
- **Fix**: parent passes `genders ?? []` / `relations ?? []` to the row, and the row's two `.map` sites are additionally guarded with `(… ?? [])` for resilience.
- **Files touched**: FE: `household-members-grid.tsx`. BE: none. DB: none.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: static — both `.map` call sites now null-safe; parent prop guarded. User to smoke via `pnpm dev` (open an existing beneficiary → Household Members renders without crash).
- **Next step**: None.

### Session 9 — 2026-06-17 — UI — COMPLETED

- **Scope**: In edit mode the floating "Save Changes" pill showed on **every** detail tab, not just the one that owns the editable form.
- **Context**: `view-page.tsx` is one component switching on URL `mode` (new/edit/read). In `mode=edit` it renders the tabbed `BeneficiaryDetail` (`isEditable`), and the main `BeneficiaryForm` is embedded **only in the Overview tab**. The other tabs (Programs & Services, Cases, Sponsorship, Documents) save via their own inline modals — they don't use the page-level pill. The pill was rendered at page level, so it floated over all tabs and would've saved the Overview form while the user was on an unrelated tab.
- **Fix**: read `activeDetailTab` from `beneficiary-store` in `view-page.tsx` and render the edit-mode `BeneficiaryFormActionPill` only when `activeDetailTab === "overview"`. Add-mode pill unchanged (plain non-tabbed form); read-mode unaffected.
- **Files touched**: FE: `view-page.tsx`. BE: none. DB: none.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: static — pill now gated on the Overview tab; other tabs keep their own save controls. User to smoke via `pnpm dev` (edit a beneficiary → switch tabs → pill only on Overview).
- **Next step**: None.

### Session 10 — 2026-06-17 — FIX — COMPLETED

- **Scope**: On edit, the household member Gender/Relationship dropdowns didn't show the saved selection, and the §5 Program Enrollment cards didn't reflect existing enrollments.
- **Root causes**:
  1. Household grid used raw native `<select>` registered with RHF. The Gender/Relation options come from async lookups (`GENDERS_QUERY`/`RELATIONS_QUERY`); when `reset()` applies the saved id before the options exist, the uncontrolled select can't display it and RHF never re-applies once options arrive → looks empty.
  2. `EligibilityCards` seeded its selection by matching `enrollmentStatusCode` against Pascal options (`Enrolled`/`Waitlisted`), but the BE returns the ENROLLMENTSTATUS `DataValue` **UPPERCASE** (`ENROLLED`/`WAITLISTED`), so the status dropdown showed blank/wrong and the card looked unselected.
- **Fixes**:
  1. `household-members-grid.tsx`: Gender/Relationship selects converted to controlled `Controller` selects (value bound to form state, converts to number/null on change) so they reflect the saved value whenever the lookups resolve.
  2. `eligibility-cards.tsx` (§5 Program Enrollment): the existing enrollment wasn't binding because the cards mirrored `programEnrollments` into local `selections` state via a seed effect + `initializedRef`, which raced the async `reset()` (and also matched the BE's UPPERCASE `WAITLISTED` against Pascal options). **Rewrote it to derive the cards directly from form state**: `useWatch("programEnrollments")` → `enrollmentByProgram` Map; `isChecked`/`status` read from the Map (status normalized case-insensitively); `toggle`/`setStatus` mutate the Map and `setValue` straight back, preserving each original enrollment row (id, enrolledOn, staff, exit data). No seed/sync effects, no `initializedRef` — saved enrollments bind the instant `reset` lands, and edits keep enrollment ids (no delete/recreate churn).
- **Files touched**: FE: `household-members-grid.tsx`, `eligibility-cards.tsx`. BE: none. DB: none.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: static — controlled household selects reflect form state regardless of lookup timing; program cards derive from `programEnrollments` so they bind without an effect race; status normalized to match options; original enrollment object preserved on write-back. User to smoke via `pnpm dev` (edit a beneficiary with household members + enrollments → both pre-fill; save keeps enrollment ids). Note: an enrolled program only shows as a checked card if it's within the first 100 programs returned by `PROGRAMS_QUERY`.
- **Next step**: None.

### Session 11 — 2026-06-17 — FIX — COMPLETED

- **Scope**: Changing a program from Waitlist → Enroll on the Overview form's `EligibilityCards` dropdown didn't flip the beneficiary Draft → Active.
- **Root cause**: the Session-10 refactor preserves the original enrollment row (to keep id/fields). When the status dropdown changed, only `enrollmentStatusCode` was updated; the stale `enrollmentStatusId` (e.g. WAITLISTED `1384`) stayed on the row. BE `SyncProgramEnrollments` prefers `EnrollmentStatusId` when `> 0` over `EnrollmentStatusCode`, so the enrollment never actually became ENROLLED → the `UpdateBeneficiary` auto-promote (Draft→Active when any enrollment is ENROLLED) never triggered.
- **Fix**: `eligibility-cards.tsx` `setStatus` now nulls `enrollmentStatusId` + `enrollmentStatusName` alongside the new `enrollmentStatusCode`, forcing the BE to re-resolve the status from the code (case-insensitive lookup → ENROLLED id). The Programs-tab `EnrollmentModal` path was already correct (it sends the freshly-selected `enrollmentStatusId`).
- **Files touched**: FE: `eligibility-cards.tsx`. BE: none. DB: none.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: static — with id cleared, `SyncProgramEnrollments` falls to the code branch → resolves ENROLLED → enrollment row updates → auto-promote sees an ENROLLED enrollment and sets ACT. **Requires the Session-7 BE auto-promote to be built.** User to smoke: edit beneficiary → switch card to Enroll Now → Save → beneficiary status becomes Active.
- **Next step**: None.

### Session 12 — 2026-06-17 — UI — COMPLETED

- **Scope**: (a) all coloured status badges in the beneficiary edit/view should be SOLID accent background + WHITE text/icon (not light tint + coloured text); (b) the Timeline should show the full case-management lifecycle including cases.
- **Changes**:
  - **Badges → solid + white** (`[[feedback_solid_icon_bg_white_foreground]]`):
    - `detail/detail-shared.tsx` `pillStyle(colorHex)` → `{ backgroundColor: colorHex, color: #fff, borderColor: colorHex }` (covers Cases-tab status + priority pills).
    - `view-page.tsx` `statusPillStyle` (beneficiary status pill in both edit + read headers) → solid colorHex + white.
    - `detail/tabs/programs-services-tab.tsx` enrollment status badge (`bg-emerald-100 text-emerald-700`… → `bg-emerald-600/amber-500/blue-600/red-600 text-white`; live pulse dot → `bg-white`) and milestone status badge (achieved/in-progress → solid + white). Program/service name chips were already solid+white.
    - Left as-is: section-header count chips (`bg-primary/10`) and inline header icons (`text-primary`) — not status badges; and `beneficiary-widgets.tsx` (that's the LIST/KPI page, not edit/view).
  - **Timeline = full lifecycle** (`timeline-tab.tsx`): now fetches `BENEFICIARY_CASES_QUERY` (cases aren't on the beneficiary DTO) and adds **Case opened / Case closed** events, plus **program exit** events (enrollment `exitDate`/`exitReason`) and distinguishes **Waitlisted vs Enrolled** enrolment steps. Existing registration / service-log / milestone / document steps retained. Dots stay solid accent + white icon. Empty-state copy updated.
- **Files touched**: FE: `detail/detail-shared.tsx`, `view-page.tsx`, `detail/tabs/programs-services-tab.tsx`, `timeline-tab.tsx`. BE: none. DB: none.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: static — `pillStyle`/`statusPillStyle` now solid+white; enrollment/milestone badge classes solid; timeline merges cases + exits and sorts desc. Cases query fields (caseCode/caseTitle/statusName/openedDate/closedDate/programName/assignedStaffName) confirmed present. User to smoke via `pnpm dev` (view a beneficiary with a case → Timeline shows the case opened/closed steps; status badges are solid with white text).
- **Next step**: Optional — if the user also wants section-header count chips + header icons restyled to solid chips, extend in a follow-up.

### Session 13 — 2026-06-17 — UI — COMPLETED

- **Scope**: Timeline should show the WHOLE case-management journey including remaining (not-yet-done) steps, with completed steps green-ticked; and the Timeline should be the FIRST tab (UX).
- **Changes**:
  - `timeline-tab.tsx`: added a **Case Management Journey** lifecycle stepper above the activity feed. Fixed canonical steps (Registered → Enrolled in a Program → Beneficiary Activated → Case Opened → Services & Milestones → Graduated/Exited), each computed from beneficiary + cases data. Completed = solid emerald circle + white `ph:check-bold`; current (first incomplete) = amber dashed-free ring + "In progress" chip; pending = dashed grey hollow circle with the step icon. Below it, the prior chronological **Activity History** feed (enrolments/exits/cases/services/milestones/documents) is retained.
  - `beneficiary-detail.tsx`: moved **Timeline to the first tab**. Added `visibleTabs`/`effectiveTab` guard (Timeline is hidden in edit mode → falls back to first visible tab so the panel never renders blank) and synced it to the store.
  - `view-page.tsx`: read mode now lands on **Timeline** (journey overview), edit mode lands on **Overview** (the form), keyed on the record id.
  - `beneficiary-store.ts`: default + reset `activeDetailTab` → `"timeline"` (no read-mode flash). `resetStore` isn't called anywhere, so landing is driven by the view-page mode effect.
- **Files touched**: FE: `timeline-tab.tsx`, `beneficiary-detail.tsx`, `view-page.tsx`, `beneficiary-store.ts`. BE: none. DB: none.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: static — stepper computes done/current/pending from status code + enrolments + cases + services/milestones; tab guard prevents blank edit panel; read lands on Timeline. User to smoke via `pnpm dev`.
- **Next step**: None.

### Session 14 — 2026-06-17 — ENHANCE — COMPLETED (⚠ needs BE build + migration by user)

- **Scope**: Business rule confirmed — Services & Milestones can only be created once the beneficiary has a **case in an open/active (non-closed) status**, and each one **belongs to that case** (Case = the care plan). Decisions: keep the optional Program link (editable); "open/active" = any case whose `closedDate` is null.
- **FE changes** (done):
  - DTOs `BeneficiaryMilestoneDto` / `BeneficiaryServiceLogDto`: added `caseId` + `caseCode`.
  - `BeneficiaryQuery` by-id: select `caseId`/`caseCode` on `milestones` + `serviceLogs`.
  - Payload mappers carry `caseId`: `beneficiary-update-helper.ts` (preserve) + `view-page.tsx` `buildVariables`.
  - `service-log-modal.tsx` + `milestone-modal.tsx`: new **required "Case" selector** (from the beneficiary's open cases, auto-selected when only one), `caseId` in payload, validation blocks save without a case.
  - `programs-services-tab.tsx`: fetches `BENEFICIARY_CASES_QUERY`, computes `openCases` (not closed); **"Add Service Log" / "Add Milestone" disabled** with tooltip *"Open a case … first"* when there are no open cases; passes `openCases` to both modals. ("Add Program" is NOT gated — enrolment precedes the case.)
- **⚠ BE changes required (user builds) — FE will 400 until these land** (the strict GQL input types must accept `caseId`):
  1. Entities `BeneficiaryServiceLog` + `BeneficiaryMilestone`: add `int? CaseId` + `Case? Case` nav (nullable so legacy rows survive).
  2. EF config: FK `CaseId → case.Cases.CaseId` (no cascade).
  3. `BeneficiarySchemas`: add `CaseId` to **request** DTOs `BeneficiaryServiceLogRequestDto` + `BeneficiaryMilestoneRequestDto`; add `CaseId` + `CaseCode` to the **response** DTOs.
  4. `UpdateBeneficiary` `SyncServiceLogs` + `SyncMilestones`: map `CaseId` (create + update branches).
  5. `GetBeneficiaryById`: project `CaseId` + `CaseCode` (join `Case.CaseCode`) for both collections.
  6. Migration: add `CaseId` columns + FKs on `case.BeneficiaryServiceLogs` + `case.BeneficiaryMilestones`.
  7. (Optional) validator: ensure the `CaseId` belongs to the same beneficiary.
- **Files touched**: FE: `BeneficiaryDto.ts`, `BeneficiaryQuery.ts`, `beneficiary-update-helper.ts`, `view-page.tsx`, `service-log-modal.tsx`, `milestone-modal.tsx`, `detail/tabs/programs-services-tab.tsx`. BE: none (user). DB: migration (user).
- **Deviations from spec**: Adds a `CaseId` FK on service-log + milestone (data-model change) — done at user direction; aligns the journey stepper ("Services & Milestones" after "Case Opened").
- **Known issues opened**: FE sends `caseId` on every service-log/milestone save — **must build the BE DTO change first or all saves 400** (HC strict-input rejection).
- **Verification**: static only. User to build BE + migration, then smoke: beneficiary with no case → Add buttons disabled; open a case → buttons enable → modal forces a Case selection → save persists `caseId`.
- **Next step**: User builds BE/migration; then verify end-to-end.

### Session 15 — 2026-06-17 — FIX — COMPLETED (⚠ needs migration by user)

- **Scope**: GetBeneficiaryById GraphQL error (`caseId`/`caseCode` don't exist on the milestone/service-log response types) blocking everything; user asked me to apply the BE fix directly (out of time). Also un-hid the Timeline tab in edit mode.
- **BE changes (agent-applied this time, by request)**:
  - DTOs `BeneficiarySchemas.cs`: `CaseId` on `BeneficiaryMilestoneRequestDto` + `BeneficiaryServiceLogRequestDto`; `CaseCode` on both response DTOs (clears the 4 schema errors).
  - Entities `BeneficiaryMilestone.cs` + `BeneficiaryServiceLog.cs`: `int? CaseId` + `Case? Case` nav.
  - EF configs (both): `HasOne(o => o.Case).WithMany().HasForeignKey(o => o.CaseId).OnDelete(Restrict)` (Restrict avoids a second cascade path alongside the Beneficiary cascade).
  - `GetBeneficiaryById`: `ThenInclude(.Case)` on milestones + service logs; project `mDto.CaseCode`/`sDto.CaseCode` (CaseId auto-maps via Adapt).
  - `UpdateBeneficiary` `SyncMilestones` + `SyncServiceLogs`: map `CaseId` in create + update branches.
- **FE**: `beneficiary-detail.tsx` — `visibleTabs = TABS` (Timeline now shows in edit mode too; effectiveTab guard kept as safety net).
- **⚠ Still required (user)**: run **one migration** adding `CaseId` columns + FKs on `case.BeneficiaryMilestones` + `case.BeneficiaryServiceLogs`, then restart BE. Until the migration runs, GetBeneficiaryById will fail (queries a column that doesn't exist yet).
- **Files touched**: BE: `BeneficiarySchemas.cs`, `BeneficiaryMilestone.cs`, `BeneficiaryServiceLog.cs`, `BeneficiaryMilestoneConfiguration.cs`, `BeneficiaryServiceLogConfiguration.cs`, `GetBeneficiaryById.cs`, `UpdateBeneficiary.cs`. FE: `beneficiary-detail.tsx`.
- **Deviations**: Agent edited BE this session at explicit user request (normally user-owned) — see [[feedback_user_creates_migrations]] (migration still user-run).
- **Verification**: code-level only; user runs migration + restart, then end-to-end.
- **Next step**: User runs the migration.

### Session 16 — 2026-06-17 — FIX — COMPLETED

- **Scope**: After creating a case the Add Service Log / Add Milestone buttons stayed disabled; and Overview (view mode) + Sponsorship tabs had no spacing between their two cards while Programs & Services did.
- **Root cause (buttons)**: the services/milestones gate fetched cases with `isActive: true`, which filters `Case.IsActive == true` — but `CreateCase` never set `IsActive`, so a freshly opened case (IsActive defaults false) was excluded → `openCases` empty → buttons disabled forever.
- **FE fix** `detail/tabs/programs-services-tab.tsx`: dropped `isActive` from the gate query and now gate purely on status — `!closedDate && statusCode ∉ {CLOSED, RESOLVED, CANCELLED}`. This also fixes pre-existing cases (created before the BE fix) without needing new data.
- **BE fix** `CreateCase.cs`: set `caseEntity.IsActive = true` on create (a newly opened case is active). Fixes the Cases tab `isActive: true` filter too. No schema/migration change.
- **Spacing fix**: Overview (`overview-tab.tsx`) + Sponsorship (`sponsorship-tab.tsx`) used Bootstrap `row g-3` / `col-lg-6` which produced no gutter; converted both to Tailwind `grid grid-cols-1 gap-4 lg:grid-cols-2` (+ `h-full` on the cards) to match the Programs tab.
- **Files touched**: BE: `CreateCase.cs`. FE: `detail/tabs/programs-services-tab.tsx`, `detail/tabs/overview-tab.tsx`, `detail/tabs/sponsorship-tab.tsx`.
- **Deviations**: None (CreateCase change is a field default, no migration).
- **Known issues opened/closed**: None.
- **Verification**: code-level; user to confirm — existing open case now enables the Add buttons, and the two tabs show a gap between cards.
- **Next step**: None.

### Session 17 — 2026-06-18 — FIX — COMPLETED

- **Scope**: Draft→Active auto-promotion on program enrolment worked in UpdateBeneficiary but not in CreateBeneficiary — creating a beneficiary already with an ENROLLED program enrolment left them Draft.
- **Root cause**: `UpdateBeneficiary` has an auto-promote block (Draft beneficiary with an active ENROLLED, non-deleted enrolment → ACT); `CreateBeneficiary` had no equivalent, so it always persisted the defaulted Draft (DFT) status regardless of the enrolments sent on create.
- **BE fix** `CreateBeneficiary.cs`: after building the `programEnrollments` list (and before the persist transaction), added the same promotion — if the beneficiary's status is `DFT` and any enrolment has `EnrollmentStatusId == ENROLLED` (and not deleted), set `BeneficiaryStatusId` to `BENEFICIARYSTATUS/ACT`. Mirrors UpdateBeneficiary 1:1.
- **Files touched**: BE: `Beneficiaries/CreateCommand/CreateBeneficiary.cs`. FE: none. DB: none.
- **Deviations**: None (status field default at runtime, no schema/migration change).
- **Known issues opened/closed**: None.
- **Verification**: code-level; user to confirm — creating a beneficiary with an enrolled program now lands them Active; create without enrolment (or waitlist only) still lands Draft.
- **Next step**: None. (Needs BE rebuild/restart — no migration.)

### Session 18 — 2026-06-18 — ENHANCE — COMPLETED

- **Scope**: Enforce the case business rule on the beneficiary detail **Programs & Services** tab — service logs and milestones can only be created against a case that is **actively being worked** (CASESTATUS `INPROGRESS` or `PENDING`). Previously any non-closed case (including `OPEN`) allowed logging.
- **Why**: business flow — `OPEN` = intake/triage (delivery not yet started, no services/money), `IN PROGRESS` = active delivery phase (services rendered, amounts transferred, milestones tracked), `PENDING` = active but waiting, `RESOLVED/CLOSED/CANCELLED` = no more logging. The caseworker manually moves `OPEN → IN PROGRESS` when real delivery begins. (Decision: hard gate on In Progress; Pending also permitted.)
- **FE fix** `detail/tabs/programs-services-tab.tsx`: replaced the closed-status *blocklist* (`CLOSED/RESOLVED/CANCELLED`) with an *allow-list* `LOGGABLE_STATUS = {INPROGRESS, PENDING}`; renamed `openCases` → `loggableCases`; `canLogWork` now true only when ≥1 case is In Progress/Pending. The "Add Service Log" / "Add Milestone" buttons disable on Open with hint *"Move the case to In Progress to start logging services and milestones."* Both modals' case dropdowns now list only loggable cases. (CASESTATUS DataValue `INPROGRESS` has no space — verified against `Case_Seed.sql`.)
- **Files touched**: FE: `beneficiarylist/beneficiary/detail/tabs/programs-services-tab.tsx`. BE/DB: none.
- **Deviations from spec**: tightens the prior gate (was non-closed; now In Progress/Pending only). No schema change.
- **Cross-ref**: enforces a **Case #50** status rule, but the gated UI lives in the Beneficiary #49 detail tab — logged here because #49 owns the file.
- **Known issues opened/closed**: None.
- **Verification**: FE `npx tsc --noEmit` clean on the touched file. Runtime not smoke-tested — recommend: open a beneficiary with an OPEN case → Add buttons disabled w/ hint; move case to In Progress → buttons enable and the case appears in the modal dropdown.
- **Next step**: None.

### Session 19 — 2026-06-18 — FIX+UI — COMPLETED

- **Scope (FIX)**: Draft→Active auto-promotion on program enrolment worked in UpdateBeneficiary but not in CreateBeneficiary — creating a beneficiary already with an ENROLLED program enrolment left them Draft. (Same root cause as Session 17; confirmed the promotion block is present in `CreateBeneficiary.cs` after the `programEnrollments` list build.)
- **Scope (UI)**: Programs & Services tab — render Service History and Milestones & Outcomes as a vertical **timeline** view (was a 2-col card grid + a table), with a scrollable overflow container for responsiveness.
- **FE fix** `detail/tabs/programs-services-tab.tsx` — rewrote Service History + Milestones to match the **canonical Activity-History timeline** in `beneficiary/timeline-tab.tsx` (single absolute vertical line at `left-4`, `space-y-4`, 32px (`h-8 w-8`) colored dot with white icon, title + date inline, meta/description muted line below). **No more nested cards** — flat timeline rows for tighter spacing.
  - **Service History**: dot = program color; title = service description; meta line = `program · provider · amount`; notes as an italic muted sub-line. Edit/delete revealed on row hover next to the date.
  - **Milestones & Outcomes**: dot color/icon by status (Achieved=green check, InProgress=amber hourglass, else grey flag); title = milestone; below = status badge + `Target: x · Achieved: y` inline.
  - **Pagination removed** from both (user request): dropped `logPage`/`milestonePage` state + `logSlice`/`milestoneSlice`, now map the full `logs`/`milestones` arrays. Each timeline wrapped in `max-h-[420px] overflow-y-auto` so long lists scroll in place. `CardPagination`/`PAGE_SIZE` still used by the Enrolled Programs section (left as-is — richer 2-col cards, not a chronological log).
- **Files touched**: BE: `Beneficiaries/CreateCommand/CreateBeneficiary.cs`. FE: `detail/tabs/programs-services-tab.tsx`. DB: none.
- **Deviations**: None. No schema/migration change (CreateBeneficiary status set is a runtime field default).
- **Known issues opened/closed**: None.
- **Verification**: code-level; user to confirm in browser. Needs BE rebuild/restart for the CreateBeneficiary change (no migration).
- **Next step**: None.

### Session 20 — 2026-06-22 — ENHANCE (Spec change — user-authorized) — COMPLETED (⚠ needs BE build + migration + seed by user)

- **Scope**: **Layer-2 service selection** — a beneficiary's program enrollment now records *which* of the program's Layer-1 catalog services (`ProgramService`) they actually receive (not everyone uses every service), with full per-beneficiary detail: named provider, allocated amount + currency, per-service status, notes. Closes the gap the Program-services restructure (#50 S16) deferred to #49. User chose the **full** model (selection + detail) over selection-only.
- **Data model** (new junction): `case."BeneficiaryEnrollmentServices"` — FK `BeneficiaryProgramEnrollmentId` (CASCADE) + `ProgramServiceId` (RESTRICT) + `NamedProvider`(200) + `AllocatedAmount` numeric(18,2) + `CurrencyId` (RESTRICT) + `ServiceStatusId` (RESTRICT, MasterData `ENROLLMENTSERVICESTATUS`) + `Notes`(500) + `OrderBy`. Unique index `(BeneficiaryProgramEnrollmentId, ProgramServiceId)` filtered `IsDeleted=false`. Nav `EnrollmentServices` added to `BeneficiaryProgramEnrollment`.
- **BE files (⚠ user builds)**: NEW `BeneficiaryEnrollmentService.cs` (entity) + `BeneficiaryEnrollmentServiceConfiguration.cs`; `BeneficiaryProgramEnrollment.cs` (nav); `ICaseDbContext.cs` + `CaseDbContext.cs` (DbSet); `BeneficiarySchemas.cs` (new request/response DTOs + `EnrollmentServices` list on enrollment DTOs); `CaseMappings.cs` (join map + ignores; enrollment response maps nested); `CreateBeneficiary.cs` (build nested EnrollmentServices on each enrollment — EF cascade-inserts); `UpdateBeneficiary.cs` (load `.ThenInclude(e => e.EnrollmentServices)` + new `SyncEnrollmentServices` nested diff, called from both branches); `GetBeneficiaryById.cs` (3 grandchild ThenIncludes: ProgramService+ServiceType / Currency / ServiceStatus).
- **DB (⚠ user)**: (1) **migration** creating `case."BeneficiaryEnrollmentServices"` (4 FKs as above) — no backfill; stacks on the still-pending S4 (relation FK repoint) + S14/S15 (CaseId cols) migrations. (2) run NEW `seed_enrollment_service_status_masterdata.sql` (`ENROLLMENTSERVICESTATUS`: ACTIVE/PAUSED/COMPLETED/CANCELLED, UPPERCASE, ColorHex in DataSetting).
- **Mutation UNCHANGED** — HC auto-generates `BeneficiaryEnrollmentServiceRequestDtoInput` from the nested DTO list (same precedent as Program outcome-metrics #50 S20).
- **FE files**: `BeneficiaryDto.ts` (new `BeneficiaryEnrollmentServiceDto` + `enrollmentServices` on enrollment dto); `BeneficiaryQuery.ts` (enrollmentServices selection); `beneficiary-update-helper.ts` + `view-page.tsx` buildVariables (carry enrollmentServices, strip response-only `serviceName`/`serviceTypeName`/`currencyCode`/`serviceStatusName`/`serviceStatusCode`); `eligibility-cards.tsx` (create-form **program selection area** — checked program reveals a lazy-loaded service checklist via `PROGRAM_BY_ID_QUERY`; selection-only here); `detail/enrollment-modal.tsx` (full per-service editor: checkbox + namedProvider/allocatedAmount+currency/status/notes, currency defaults to company base); `detail/tabs/programs-services-tab.tsx` (shows "Services Received" list per enrollment).
- **Deviations from spec**: new junction entity + FK (Spec-level) — done in-session at user direction (same pattern as S4/S7/S14). Free-text `ServicesSummary` retained (now redundant; left as optional notes).
- **Known issues opened**: FE sends `enrollmentServices` on every beneficiary save — **must build BE DTO + run the migration first or saves 400 / GetById fails** (HC strict input + missing table).
- **Verification**: FE `npx tsc --noEmit` clean. BE not built (user builds).

### Session 21 — 2026-06-22 — UI/ENHANCE — COMPLETED

- **Design clarification (important)**: Branch = the **managing office** for a case, an axis orthogonal to program+services+money (which are charity-wide). It is **NOT a geographic catchment** — a charity's branch serves beneficiaries from *any* region (a south-region branch may have north/south/east/west beneficiaries). So branch must **not** be derived from where the beneficiary lives. Confirmed branch-scoped *visibility* is **NOT** enforced today — `GetBeneficiaries` filters by `companyId` only; `branchId` is just an optional manual grid filter. Left as a separate access-control decision, not changed here.
- **First attempt rejected (recorded so it isn't re-tried)**: briefly wired branch auto-suggest from the beneficiary's location (city→district→state match against `app.Branches.cityId/districtId/stateId`). **Reverted** — wrong model per the clarification above. Do not reintroduce location→branch matching.
- **Shipped behaviour** `beneficiary-form.tsx`: `useQuery(BRANCHES_QUERY)` (pageSize 200, cache-first; the resolver is tenant-scoped) + an effect that pre-fills `branchId` **only when the tenant has exactly one branch** (`branches.length === 1`). Multi-tenant fact: every charity has ≥1 branch and many run a single office — so single-branch tenants shouldn't be forced to pick the only option; multi-branch tenants choose manually. Only fills when `branchId` is empty — never overrides a manual or edit-loaded value. Helper text updated to say branch is independent of beneficiary location and defaults to the sole branch when there's one.
- **Files touched**: FE: `beneficiarylist/beneficiary/beneficiary-form.tsx`. BE/DB: none.
- **Deviations from spec**: None. No schema/migration change.
- **Known issues opened/closed**: None.
- **Verification**: FE `npx tsc --noEmit` clean. Runtime not smoke-tested — recommend: single-branch tenant → Branch pre-selects that branch on a new beneficiary; multi-branch tenant → Branch stays empty for manual pick; editing an existing beneficiary → its saved branch is preserved (not overwritten).
- **Next step**: None. (Open decision left to user: whether to *enforce* branch-scoped visibility so a branch's staff see only their own beneficiaries — would be a BE list-query + RBAC change, not done here.)
- **Next step**: user builds BE + runs migration + seed, then smoke: create beneficiary → check a program → its services appear → pick a subset → save; open detail → enrollment modal edits provider/amount/status; Programs tab shows "Services Received".

### Session 22 — 2026-06-22 — ENHANCE (Spec change — user-authorized) — COMPLETED (⚠ needs BE build + migration + seed by user)

- **Scope**: Workstream B of the case-mgmt workflow re-architecture — a **Verification stage** before a beneficiary is case-eligible. New **Verification** tab on the detail page (right after Overview). Staff pick an enrolled program, work its **eligibility criteria** checklist (mark each met, attach a document where `requiresDocument`), Save progress, then **Mark Verified** → beneficiary moves to a NEW `VERIFIED` (`VRF`) status. See [[project_case_workflow_rearchitecture]].
- **Status model decision (user-chosen — "verify gates everything")**: chain is now `DFT` (create) → `DFT` (enroll — **no longer auto-promotes**) → `VRF` (Mark Verified) → `ACT` (first case opened, promoted inside CreateCase). One new status only (`VRF`); no "Pending Verification". Supersedes the old enrollment-auto-promote + Draft-blocks-CreateCase rules in [[project_beneficiary_case_status_orchestration]].
- **BE behavioural changes**: (1) `EnrollBeneficiaryInProgram.cs` — REMOVED the `ENROLLED`→`DFT`→`ACT` auto-promote block. (2) `CreateCase.cs` — guard changed from "block if DFT" → "require `VRF` or `ACT`" + on success promotes `VRF`→`ACT`. (3) `GetBeneficiaries.cs` — new optional `verifiedOnly` arg filtering to `VRF`/`ACT` (default unchanged so the beneficiary list still shows Drafts to verify; only the **case beneficiary-picker** passes `verifiedOnly:true`).
- **Files touched**:
  - BE: NEW entity `BeneficiaryEligibilityVerification.cs` + config (unique idx on Beneficiary+Program+Criterion); `BeneficiarySchemas.cs` (verification view/item/save DTOs); NEW CQRS `Business/CaseBusiness/BeneficiaryVerifications/` (GetBeneficiaryVerification, SaveBeneficiaryVerification, MarkBeneficiaryVerified); NEW GraphQL `Case/Queries/BeneficiaryVerificationQueries.cs` + `Case/Mutations/BeneficiaryVerificationMutations.cs`; `EnrollBeneficiaryInProgram.cs`, `CreateCase.cs`, `GetBeneficiaries.cs`, `BeneficiaryQueries.cs`, `ICaseDbContext.cs`, `CaseDbContext.cs`, `DecoratorProperties.cs`.
  - FE: NEW `detail/tabs/verification-tab.tsx`; `beneficiary-detail.tsx` (tab + render); NEW `gql-queries/case-queries/BeneficiaryVerificationQuery.ts` + `gql-mutations/case-mutations/BeneficiaryVerificationMutation.ts` (+ index exports); `case-queries/BeneficiaryQuery.ts` (`verifiedOnly` var on `BENEFICIARIES_QUERY`); `caselist/case/case-form.tsx` (beneficiary picker → `extraVariables={{ verifiedOnly: true }}`). Shared-component additive change: `FormSearchableSelect.tsx` + `atoms/searchable-select/searchable-select-radix.tsx` gained an `extraVariables` prop (spreads flat GQL vars into the picker's fetch).
  - DB: NONE applied — **user owns migration + seed**.
- **GraphQL ops added**: `beneficiaryVerification(beneficiaryId, programId)`; `saveBeneficiaryVerification(request: …Input!)`; `markBeneficiaryVerified(beneficiaryId, programId)`; `getBeneficiaries` gained `verifiedOnly: Boolean`. `BaseApiResponse<int>` → bare `data`.
- **Deviations from spec**: Verification is per-(beneficiary, program); beneficiary-level status is a single `VRF` — verifying any one enrolled program's criteria flips the beneficiary to Verified (cases are per-program anyway). Multi-program "must verify the case's specific program" is a possible future refinement, not enforced.
- **Known issues opened/closed**: None.
- **Verification**: FE combined `npx tsc --noEmit` clean. BE NOT built (user builds). Runtime pending BE build + migration + seed.
- **Migration + seed the user must apply**: create table `case."BeneficiaryEligibilityVerifications"` (Id PK; FKs BeneficiaryId CASCADE, ProgramId RESTRICT, ProgramEligibilityCriterionId RESTRICT, VerifiedDocumentId→BeneficiaryDocuments nullable RESTRICT, VerifiedByStaffId→Staffs nullable SET NULL; cols IsMet bool, Notes, VerifiedOn, audit/soft-delete; UNIQUE idx Beneficiary+Program+Criterion). **Seed** `BENEFICIARYSTATUS / VRF` ('Verified') MasterData row.
- **Next step**: None for B. The case-mgmt list itself is intentionally unfiltered (staff must see Drafts to verify them); only the case picker is gated.

### Session 23 — 2026-06-22 — ENHANCE (case-only logging follow-up) — COMPLETED

- **Scope**: Completes the "beneficiary becomes rollup" half of the case-only decision (the open follow-up from Session 22 / Case #50 Session 4). On the **Programs & Services** tab, **Service Log** and **Milestones** are now **read-only** — all CRUD lives on the Case (Case → Service Log / Milestones tabs). Per user call, **Sponsorship** tab is also read-only.
- **What changed (FE-only, no BE/DB)**:
  - `programs-services-tab.tsx`: removed Add / Edit / Delete buttons + the `ServiceLogModal` / `MilestoneModal` usages from the Service History and Milestones sections; removed the loggable-cases query + `canLogWork` gating (only existed to gate those Add buttons); each entry now shows a **case badge** (`caseCode`) and the section headers carry a "Recorded on cases" chip. `handleDelete`/`DeleteConfirmDialog` narrowed to enrollment only. **Enrolled Programs CRUD kept** (enrolling is beneficiary-level, not a case action).
  - `sponsorship-tab.tsx`: removed Edit Sponsor button + "Assign a sponsor" link + `SponsorDetailsModal`; now pure read-only. Props slimmed to `{ ben }` (caller in `beneficiary-detail.tsx` updated).
  - **Deleted orphaned modals**: `service-log-modal.tsx`, `milestone-modal.tsx`, `sponsor-details-modal.tsx` (no remaining references anywhere).
- **Files touched**: FE: `detail/tabs/programs-services-tab.tsx`, `detail/tabs/sponsorship-tab.tsx`, `beneficiary-detail.tsx`; deleted `service-log-modal.tsx`, `milestone-modal.tsx`, `sponsor-details-modal.tsx`. BE/DB: none.
- **Deviations from spec**: None. Sponsorship has no Case equivalent, so "move under case" resolved to read-only (user-chosen) — there is now no UI to set/change a sponsor except the beneficiary form / API.
- **Known issues opened/closed**: None.
- **Verification**: FE `npx tsc --noEmit` clean (exit 0).
- **Next step**: None.

### Session 24 — 2026-06-23 — ENHANCE — COMPLETED (⚠ needs BE build by user)

- **Scope**: Two related rules around program enrolment. (1) Confirmed beneficiary creation is NOT gated on program approval — a beneficiary can be created with no program enrolled (program enrolment is optional; `CreateBeneficiary` forces DFT, no approval check; the create form §5 has no required program field; `EnrollBeneficiaryInProgram` validator has no status gate). No code change needed for this — verified only. (2) The program **enrolment pickers now show only enrollable programs**: approved (PROGRAMSTATUS `ACTIVE`) AND still open to intake (PROGRAMTYPE `ONGOING`, OR `EndDate` null/≥ today). Previously they listed every program (incl. Draft/Pending/Rejected and expired fixed-term).
- **What changed**:
  - **BE**: `Programs/GetAllQuery/GetAllPrograms.cs` — added optional `bool? enrollableOnly` param to `GetProgramsQuery`; when true, filters `Status.DataValue == "ACTIVE" && (ProgramType.DataValue == "ONGOING" || EndDate == null || EndDate >= today)` (`EndDate` is `DateOnly?`). `EndPoints/Case/Queries/ProgramQueries.cs` — exposed `enrollableOnly` as a GQL arg, threaded into the query ctor.
  - **FE**: `gql-queries/case-queries/ProgramQuery.ts` — added `$enrollableOnly: Boolean` var + `enrollableOnly: $enrollableOnly` arg to the shared `PROGRAMS_QUERY` (optional → existing grid callers unaffected). Pickers pass the flag: `add-program-modal.tsx` + `detail/enrollment-modal.tsx` via `extraVariables={{ enrollableOnly: true }}` on `FormSearchableSelect`; `eligibility-cards.tsx` via `enrollableOnly: true` in the `useLazyQuery` variables.
- **Files touched**: BE: `GetAllPrograms.cs`, `ProgramQueries.cs`. FE: `ProgramQuery.ts`, `add-program-modal.tsx`, `detail/enrollment-modal.tsx`, `eligibility-cards.tsx`. DB: none.
- **Deviations from spec**: None. Scope limited to the beneficiary enrolment pickers (the `enrollableOnly` BE flag is generic and can be reused by other program pickers — e.g. Case program / service-log — if/when wanted).
- **Known issues opened/closed**: None.
- **Next step**: User builds BE (new GQL arg). No migration/seed required.