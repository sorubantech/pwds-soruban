---
screen: Program
registry_id: 51
module: Case Management
status: COMPLETED
scope: FULL
screen_type: MASTER_GRID
complexity: High
new_module: YES — `case` schema (CaseDbContext, ICaseDbContext, CaseMappings, DecoratorCaseModules)
planned_date: 2026-04-21
completed_date: 2026-04-22
last_session_date: 2026-06-19
---

> **⚠ REDESIGN 2026-06-19 (Session 5) — read before the original spec below.**
> Post-demo flow-connectivity rework. The field set + lifecycle changed; where the original spec and this delta disagree, **this delta wins**.
>
> **Added** to `case."Programs"`: `ProgramTypeId` (FK MasterData `PROGRAMTYPE` — ONGOING / FIXEDTERM; cyclical/cohort = future phase), `TargetBeneficiaries` (int? — goal reach, ≠ MaximumCapacity hard cap), and approval audit: `SubmittedByStaffId`/`SubmittedDate`/`ApprovedByStaffId`/`ApprovedDate`/`RejectionReason`.
> **Deliberately NOT added — Branch.** A program is charity-wide (`CompanyId`); it is NOT owned by one branch. Who handles each beneficiary is per-enrollment (`BeneficiaryProgramEnrollment.AssignedStaffId` + the beneficiary's own branch), so beneficiaries spread across regions are each serviced by their assigned staff — a single program-level branch would be misleading.
> **Removed** (free-text / dead / duplicate): `IsOngoing` (subsumed by ProgramType), `PoolFundingNote`, `FundingSources`, `AutoSuggestEnabled`, `LinkedGrantId`.
> **Lifecycle** — `StatusId` (PROGRAMSTATUS) is now an approval lifecycle owned ONLY by new commands, never by Create/Update: `DRAFT → PENDINGAPPROVAL → ACTIVE → PAUSED → COMPLETED`, plus `REJECTED`. Create forces `DRAFT`; Update preserves status. New commands `SubmitProgramForApproval` / `ApproveProgram` (→ ACTIVE) / `RejectProgram(reason)`; perms `Sendforapproval` (submit) + `ApproveRequest` (approve/reject). **Rule:** funds may be allocated / beneficiaries enrolled only once a program is ACTIVE (approved).
> **EndDate rule** — required only when ProgramType = FIXEDTERM; forced null when ONGOING (replaces the old IsOngoing rule).
> **Seed** — `DatabaseScripts/Seed/seed_program_type_and_lifecycle.sql` (PROGRAMTYPE + new PROGRAMSTATUS lifecycle values, UPPERCASE). FE Status select removed (status is lifecycle-driven); approval banner added to the Program form page.

> **⚠ ELIGIBILITY VERIFICATION 2026-06-19 (Session 6) — extends the criterion model.**
> Eligibility criteria moved from a plain text condition into a **document-backed verification process**. This is **Layer 1 (Program-side configuration)** only — the per-beneficiary verification record + staff-verify screen are **Layer 2**, deferred to the Beneficiary pass (#10/#13).
> **Added** to `case."ProgramEligibilityCriteria"`: `CriterionLabel` (string? 200 — human label), `RequiresDocument` (bool), `RequiredDocumentTypeId` (FK MasterData `ELIGIBILITYCRITERIADOCUMENTTYPE`, nullable — what proof, e.g. Birth Certificate), `VerificationMethodId` (FK MasterData `ELIGIBILITYCRITERIAVERIFICATIONMETHOD`, nullable — DOCUMENT / ATTESTATION / FIELDVISIT / AUTO), `IsMandatory` (bool, default true), `Instructions` (string? 500 — guidance to beneficiary/staff). Both new FKs `OnDelete(Restrict)`.
> **Gating rule (Layer 2, not yet enforced):** mandatory criteria HARD-block enrollment — a beneficiary cannot reach ENROLLED/Active until every `IsMandatory` criterion is Verified. Optional criteria are advisory. Enforcement lands with the Layer-2 `BeneficiaryEligibilityVerification` record.
> **DTO** — `ProgramEligibilityCriterionDto` gained the config fields + response-only joined names/codes (`RequiredDocumentTypeName/Code`, `VerificationMethodName/Code`); request never sends a doc type unless `RequiresDocument`.
> **Seed** — `DatabaseScripts/Seed/seed_eligibility_verification_masterdata.sql` (NEW MasterData types `ELIGIBILITYCRITERIADOCUMENTTYPE` + `ELIGIBILITYCRITERIAVERIFICATIONMETHOD`, UPPERCASE, idempotent). Codes are eligibility-specific (a future Beneficiary document-upload type for #13 is separate).
> **FE** — criteria table rebuilt from a flat 3-col grid into per-criterion **verification cards** (label + rule + mandatory toggle + "requires document" → document/method selects + instructions), reusing FormInput/FormSelect/FormSearchableSelect/FormCheckbox/FormTextarea.

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/case-management/program-management.html`)
- [x] Existing code reviewed (FE stub confirmed 4-line "Need to Develop"; no BE entity; no `case` schema infra)
- [x] Business rules extracted
- [x] FK targets resolved (Staff, MasterData, DonationPurpose verified; Grant deferred to #62)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized
- [x] User Approval received
- [x] **NEW MODULE bootstrap** — `case` schema: `ICaseDbContext`, `CaseDbContext`, `CaseMappings`, `DecoratorCaseModules` created and wired (`IApplicationDbContext` inheritance, `DependencyInjection.ConfigureMappings`, GlobalUsing ×3, `DependencyInjection.AddDbContext` entry)
- [x] Backend code generated (Program + 3 child entities + 1 junction + 11 CRUD files + child-handling)
- [x] Backend wiring complete (DbSet lines, MappingsConfigure, Decorator entry, MasterData seed)
- [x] Frontend code generated (card-grid index + side-drawer form + 3 child grids + staff picker)
- [x] Frontend wiring complete (entity-operations, operations-config, sidebar, route)
- [x] DB Seed script generated (menu + grid + MASTER_GRID card-grid columns + GridFormSchema SKIP + 5 MasterDataType seeds + sample rows)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` — no errors (new `case` schema registered in EF design snapshot)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/casemanagement/programmanagement`
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete including all 3 child collections)
- [ ] Card grid renders all active programs with capacity bar, budget line, stats, dual action buttons
- [ ] Side-drawer (80%) opens on "+New Program" and on card "Manage" click
- [ ] All 7 drawer sections render with correct fields
- [ ] Eligibility Criteria table — add/delete rows, persist on Save
- [ ] Services table — add/delete rows, persist on Save
- [ ] Outcome Metrics table — add/delete rows, persist on Save
- [ ] Staff tags — add Staff via picker, remove with X, ProgramLead dropdown separate
- [ ] "Ongoing" toggle disables End Date input; End Date = NULL when Ongoing=true
- [ ] Category/Status/FundingModel/EnrollmentType dropdowns load MasterData rows filtered by TypeCode
- [ ] Linked Donation Purpose selector loads via `getDonationPurposes` ApiSelectV2
- [ ] `SERVICE_PLACEHOLDER` computed fields (enrolled count, spent %, on-track %) render 0 / gray with tooltip
- [ ] DB Seed — menu `PROGRAMMANAGEMENT` visible in sidebar under `CRM_CASEMANAGEMENT`; 5 MasterDataTypes seeded; 3 sample Programs seeded

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Program
Module: Case Management
Schema: `case` (**NEW — first entity in this schema**)
Group: `Case` (Models=`CaseModels`, Configs=`CaseConfigurations`, Schemas=`CaseSchemas`, Business=`CaseBusiness`, Endpoints=`Case`)

Business:
The Program screen is the root master in the Case Management module. It defines the beneficiary-facing programs an NGO runs (e.g., Orphan Sponsorship, Clean Water, Healthcare Outreach), including eligibility criteria, enrollment capacity, funding model, services delivered, and outcome metrics tracked. Programs are the parent of Beneficiary enrollments (#49) and the cases (#50) that result — so this master must exist before either can be created. Operations managers and program leads use this screen to stand up a new initiative, tune eligibility (the rule engine drives beneficiary matching on the Beneficiary screen), define which services beneficiaries receive, and tag staff who operate the program. The screen also surfaces live operational KPIs per program card (enrollment %, budget spent, on-track %); several of those KPIs depend on downstream entities (Beneficiary, Grant, Donation) that don't exist yet and therefore ship as SERVICE_PLACEHOLDER computed fields returning 0 until those screens land.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> 5 entities total (1 parent + 3 child 1:M + 1 junction M:N). Audit columns inherited from `Entity`.

### Parent Entity — `case."Programs"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ProgramId | int | — | PK | — | Primary key |
| ProgramCode | string | 50 | YES | — | Unique per Company (e.g., `ORPHAN_SPONSOR`) |
| ProgramName | string | 150 | YES | — | Display title |
| Description | string | 1000 | NO | — | Program objectives & scope |
| IconEmoji | string | 10 | NO | — | Single emoji, default 🎯 |
| ColorHex | string | 7 | NO | — | `#RRGGBB`, default `#0d9488` (cm-accent) |
| CategoryId | int | — | YES | `sett.MasterDatas` (TypeCode `PROGRAMCATEGORY`) | Child Welfare / Education / Healthcare / Livelihood / WASH / Protection / Nutrition / Emergency |
| StatusId | int | — | YES | `sett.MasterDatas` (TypeCode `PROGRAMSTATUS`) | Active / Paused / Completed / Planned / Standby |
| StartDate | DateOnly | — | YES | — | Month-granularity in UI; store as 1st-of-month |
| EndDate | DateOnly? | — | NO | — | NULL when IsOngoing=true |
| IsOngoing | bool | — | YES | — | Toggle; when true → EndDate MUST be null |
| FundingModelId | int | — | YES | `sett.MasterDatas` (TypeCode `PROGRAMFUNDINGMODEL`) | Individual / Pool / Grant / Mixed |
| SponsorshipAmount | decimal(18,2)? | — | NO | — | Per-beneficiary monthly amount (visible when FundingModel=Individual/Mixed) |
| SponsorshipCurrencyId | int? | — | NO | `shared.Currencies` | Display currency for SponsorshipAmount |
| SponsorshipFrequencyCode | string | 20 | NO | — | Free enum string: `monthly` / `quarterly` / `annual` |
| PoolFundingNote | string | 500 | NO | — | Free text shown when FundingModel=Pool/Mixed |
| MaximumCapacity | int? | — | NO | — | Enrollment cap (NULL = unlimited/standby) |
| EnrollmentTypeId | int | — | YES | `sett.MasterDatas` (TypeCode `PROGRAMENROLLMENTTYPE`) | Open / Waitlist Only / Closed / By Referral |
| RequiresNeedsAssessment | bool | — | YES | — | Default false |
| RequiresGuardianConsent | bool | — | YES | — | Default false |
| RequiresMedicalClearance | bool | — | YES | — | Default false |
| AutoSuggestEnabled | bool | — | YES | — | Default true — drives Beneficiary auto-match |
| ProgramLeadStaffId | int? | — | NO | `app.Staffs` | Program lead (single Staff) |
| AnnualBudget | decimal(18,2)? | — | NO | — | Yearly budget in BudgetCurrencyId |
| BudgetCurrencyId | int? | — | NO | `shared.Currencies` | Currency for AnnualBudget |
| FundingSources | string | 500 | NO | — | Free text description (e.g., "Individual (70%), Grant (10%)") |
| LinkedDonationPurposeId | int? | — | NO | `fund.DonationPurposes` | Optional link to Donation Purpose |
| LinkedGrantId | int? | — | NO | **SERVICE_PLACEHOLDER** — no FK constraint yet | Grant entity (#62) not built; keep as nullable int with no FK for now. See **ISSUE-4** |
| CompanyId | int? | — | — | `app.Companies` | Tenant scope (HttpContext) |

**Child Entities** (3 × 1:M + 1 junction M:N):

| Child Entity | Relationship | Table | Key Fields |
|--------------|--------------|-------|------------|
| ProgramEligibilityCriterion | 1:Many via ProgramId (cascade) | `case."ProgramEligibilityCriteria"` | Id, ProgramId, CriteriaField (string 100), OperatorCode (string 30 — `isOneOf`/`equals`/`between`/`greaterThan`/`lessThan`/`contains`), CriteriaValue (string 500), OrderBy |
| ProgramService | 1:Many via ProgramId (cascade) | `case."ProgramServices"` | Id, ProgramId, ServiceName (string 150), ServiceTypeId (FK MasterData PROGRAMSERVICETYPE, nullable), ProviderTypeId (FK MasterData PROGRAMSERVICEPROVIDERTYPE, nullable — the *provider TYPE*, not a named org; the named provider is per-beneficiary Layer 2), FundingFlowId (FK MasterData PROGRAMSERVICEFUNDINGFLOW, nullable), CostPerUnit (decimal 18,2 nullable), UnitOfMeasure (string 50 nullable), CurrencyId (FK Currency, nullable, SetNull), OrderBy. **Replaced** old free-text FrequencyText/ProviderText/CostPerUnitText. (Services is a pure Layer-1 catalog — no IsMandatory/Instructions: per-beneficiary service selection is a Layer-2 concern, #49.) |
| ProgramOutcomeMetric | 1:Many via ProgramId (cascade) | `case."ProgramOutcomeMetrics"` | Id, ProgramId, MetricName (string 150), TargetText (string 100), MeasurementText (string 100), FrequencyText (string 50), OrderBy |
| **ProgramStaff** (junction) | Many:Many Program↔Staff (cascade on Program side, restrict on Staff side) | `case."ProgramStaffs"` | Id, ProgramId, StaffId — unique composite index (ProgramId, StaffId) |

**Projected / computed fields on `ProgramResponseDto`** (NOT stored; returned by GetAll/GetById projections):

| Field | Computation | Buildable Now? |
|-------|-------------|----------------|
| staffCount | `ProgramStaffs.Count(ps => ps.ProgramId == p.Id && ps.IsActive)` | ✅ YES |
| categoryName / statusName / fundingModelName / enrollmentTypeName / programLeadName / linkedDonationPurposeName / sponsorshipCurrencyCode / budgetCurrencyCode | nav-property joins | ✅ YES |
| enrolledCount | `Beneficiaries.Count(b => b.ProgramId == p.Id)` | ❌ SERVICE_PLACEHOLDER — Beneficiary (#49) not built. Return `0`. See **ISSUE-1** |
| waitlistCount | from Beneficiary.EnrollmentStatusCode='WAITLIST' | ❌ SERVICE_PLACEHOLDER. Return `0`. |
| capacityPercent | `enrolledCount * 100 / MaximumCapacity` (null-safe) | Partial — returns 0 while enrolledCount is 0 |
| spentBudget / spentPercent | Donation+Grant expenditure aggregation | ❌ SERVICE_PLACEHOLDER. Return `0`. See **ISSUE-2** |
| onTrackPercent | Case outcome-metric attainment | ❌ SERVICE_PLACEHOLDER. Return `null` → UI shows "—". See **ISSUE-3** |
| eligibilityCriteria / services / outcomeMetrics / staffs | inlined child collection projections | ✅ YES (load on GetById; summary on GetAll) |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CategoryId | MasterData (filtered by `MasterDataType.TypeCode='PROGRAMCATEGORY'`) | `PSS_2.0_Backend/.../Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (with `masterDataTypeCode` filter) | DataName | MasterDataResponseDto |
| StatusId | MasterData (`PROGRAMSTATUS`) | same as above | `getMasterDatas` | DataName | MasterDataResponseDto |
| FundingModelId | MasterData (`PROGRAMFUNDINGMODEL`) | same as above | `getMasterDatas` | DataName | MasterDataResponseDto |
| EnrollmentTypeId | MasterData (`PROGRAMENROLLMENTTYPE`) | same as above | `getMasterDatas` | DataName | MasterDataResponseDto |
| SponsorshipCurrencyId | Currency | `PSS_2.0_Backend/.../Base.Domain/Models/SharedModels/Currency.cs` (assumed — verify during build) | `getCurrencies` (verify GQL field name) | CurrencyCode | CurrencyResponseDto |
| BudgetCurrencyId | Currency | same | same | same | same |
| ProgramLeadStaffId | Staff | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Staff.cs` | `getStaffs` (paginated; expose `staffId` + `staffName`) | StaffName | StaffResponseDto |
| ProgramStaff.StaffId | Staff | same | same | same | same |
| LinkedDonationPurposeId | DonationPurpose | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/DonationPurpose.cs` | `getDonationPurposes` | DonationPurposeName | DonationPurposeResponseDto |
| LinkedGrantId | **Grant (not yet built)** | — (no entity file until #62) | **SERVICE_PLACEHOLDER** — render FE as read-only text chip until Grant screen lands | — | — |
| CompanyId | Company | auto via HttpContext / tenant resolver | — | — | — |

**MasterData filter convention**: `getMasterDatas` accepts a filter arg for MasterDataType — see existing usage in SavedFilter #27 or ContactType #19 pattern (`masterDataTypeCode` query-param). If not present as a top-level arg, the FE dropdowns use the generic MasterData query with a `typeCode` filter built into `ApiSelectV2` payload.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `ProgramCode` must be unique per Company (ValidateUniqueWhenCreate + ValidateUniqueWhenUpdate). Soft-delete (IsActive=false) rows must NOT block re-use — follow ContactType pattern.
- `ProgramName` SHOULD be unique per Company (warn but don't block). Confirm with BA during approval.
- `ProgramStaff(ProgramId, StaffId)` composite uniqueness — one staff cannot appear twice on the same program.

**Required Field Rules:**
- Mandatory: `ProgramCode`, `ProgramName`, `CategoryId`, `StatusId`, `FundingModelId`, `EnrollmentTypeId`, `StartDate`, `IsOngoing` (bool), `AutoSuggestEnabled` (bool).
- All boolean `Requires*` flags default to `false`.

**Conditional Rules:**
- If `IsOngoing = true` → `EndDate` MUST be `NULL`.
- If `IsOngoing = false` → `EndDate` is REQUIRED and MUST be ≥ `StartDate`.
- If `FundingModelId` ∈ {Individual, Mixed} → `SponsorshipAmount` and `SponsorshipCurrencyId` SHOULD be populated (soft-warning in FE; not a BE validation error).
- If `FundingModelId` ∈ {Pool, Mixed} → `PoolFundingNote` SHOULD be populated (soft-warning).
- If `StatusId` = Standby → `MaximumCapacity` MAY be null and `EnrollmentTypeId` defaults to Closed.
- If `MaximumCapacity` is NULL or `StatusId` = Standby → FE disables capacity progress bar.

**Business Logic:**
- **Cascade on delete**: Hard-delete a Program → cascade-delete its ProgramEligibilityCriteria, ProgramServices, ProgramOutcomeMetrics, ProgramStaffs junctions. (Soft-delete toggles IsActive only.)
- **Restrict delete** if the program has child Beneficiaries (#49) OR child Cases (#50) once those screens are built. For MVP (neither exists): allow delete. See **ISSUE-5**.
- **Child collection diff-persist**: Create/Update Program accepts inline child arrays. BE handler must diff against the DB state and INSERT new / UPDATE existing (by Id) / DELETE removed rows within a single transaction. This is the same pattern as #20 Family `setFamilyMembers` and #11 MatchingGiftSettings.
- **ProgramStaff junction**: treated as diff-persist child collection — no dedicated AssignStaff/UnassignStaff mutations. Submit the full desired StaffId list in Update.
- **ProgramLeadStaffId** ≠ ProgramStaff membership — the lead does NOT auto-appear in the `ProgramStaffs` junction. If the UX needs the lead to always be in the staff list, that's a FE-level convenience (auto-add on lead selection), not a BE rule.

**Workflow**: None. Status transitions (Active↔Paused↔Completed) are free-form field edits — no state-machine guards or transition commands.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: `MASTER_GRID` (per Registry + DEPENDENCY-ORDER)

**Type Classification**: **Master with inline custom form + 3 child collections + 1 junction** — a **non-canonical MASTER_GRID**:

- List view is **card-grid** (not a table).
- Add/Edit form is a **80%-width right side-drawer with 7 sections and 3 inline editable child tables** — NOT an RJSF modal.
- `GridFormSchema = SKIP` because form is code-driven (RHF + zod), not RJSF-driven.
- Still registered as MASTER_GRID because the URL is a single route — no `?mode=new/edit/read` URL sync (drawer is UI-local state).

**Reason**: The mockup opens the form in a side-drawer overlay (URL does not change) — which behaviorally is a modal, so the primary dispatcher is MASTER_GRID. But the form's complexity (7 sections + 3 child 1:M grids + M:N staff picker) exceeds RJSF's capability, so we hand-code the form in React. This is closer to **ContactType #19 + Campaign #39's child-table pattern** than the canonical simple-modal MASTER_GRID.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files for the parent Program entity)
- [x] **Nested child creation + diff-persist** — 3 child 1:M + 1 junction M:N (ProgramEligibilityCriterion / ProgramService / ProgramOutcomeMetric / ProgramStaff)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 7: Category / Status / FundingModel / EnrollmentType / SponsorshipCurrency? / BudgetCurrency? / ProgramLeadStaff? / LinkedDonationPurpose?)
- [x] Unique validation — `ProgramCode` per Company + `ProgramStaff(ProgramId,StaffId)` composite
- [ ] File upload command — not required (no file fields)
- [x] Conditional validators — IsOngoing ↔ EndDate
- [x] **NEW MODULE bootstrap** — `case` schema / ICaseDbContext / CaseDbContext / CaseMappings / DecoratorCaseModules + IApplicationDbContext inheritance + DependencyInjection registration + GlobalUsing updates (×3)
- [x] MasterData seed — 5 new TypeCodes (PROGRAMCATEGORY × 8, PROGRAMSTATUS × 5 w/ ColorHex, PROGRAMFUNDINGMODEL × 4, PROGRAMENROLLMENTTYPE × 4, OPERATOR × 6)

**Frontend Patterns Required:**
- [x] **CardGrid** via existing `<CardGrid>` infrastructure (built in Wave 2 SMS Template #29) — **adds NEW `program` card variant** (`variants/program-card.tsx` + registry line). See §⑥ Card Config.
- [ ] ~~AdvancedDataTable~~ — NOT used (card-grid replaces it)
- [ ] ~~RJSF Modal Form~~ — NOT used (code-driven form)
- [x] **Custom side-drawer** (80% width, right-anchored, backdrop, ESC-close, body-lock-scroll) — canonical inspiration: #27 SavedFilter field-setting drawer + Beneficiary/Contact detail drawer
- [x] Custom 7-section form with RHF + zod (no RJSF)
- [x] 3 × inline editable child grids (add/delete rows; field-array pattern)
- [x] Multi-select staff picker (tag-style with remove X) + separate Program Lead single-select
- [x] MasterData-filtered ApiSelectV2 dropdowns (4 instances for Category/Status/FundingModel/EnrollmentType)
- [ ] Summary cards / count widgets above grid — NONE (mockup has no top-of-page KPI widgets)
- [x] Grid aggregation columns (per-card computed values: enrollment %, spent %, staff count, on-track %) — several are SERVICE_PLACEHOLDER
- [ ] Info panel / side panel — NONE (the side-drawer IS the form, not a viewing panel)
- [ ] Drag-to-reorder — NONE
- [ ] Click-through filter — NONE (cards have Manage + Dashboard action buttons; Dashboard navigates to `crm/casemanagement/casedashboard`)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `program-management.html` — this IS the design spec.

### Grid/List View — Card Grid

**Display Mode** (REQUIRED): `card-grid`

**Card Variant** (REQUIRED — **NEW variant added by this screen**): `program`

> This screen extends the `<CardGrid>` infrastructure with a **new `program` variant**. It adds ONE variant file (`variants/program-card.tsx`) + ONE skeleton file (`skeletons/program-card-skeleton.tsx`) + ONE registry entry in `card-variant-registry.ts`. Shell is untouched. Follows the extension pattern documented in `.claude/feature-specs/card-grid.md` and used by Email Template #24 when it added the `iframe` variant.

**Card Config** (for `program` variant):

```yaml
cardConfig:
  iconField: "iconEmoji"              # 1.5rem leading emoji
  nameField: "programName"            # bold 0.9375rem
  badgeField: "statusName"            # top-right pill; green when statusCode=ACT, amber for STANDBY, gray otherwise
  standbyMode: (statusCode === 'STANDBY') # applies dashed 2px border + 0.75 opacity
  statsFields:                        # stat-item row with fa-icon leading
    - { icon: "fa-users",              label: "{enrolledCount} beneficiaries" }
    - { icon: "fa-expand-arrows-alt",  label: "Capacity: {maximumCapacity}" }
    - { icon: "fa-user-tie",           label: "Staff: {staffCount}" }
    - { icon: "fa-chart-line",         label: "{onTrackPercent}% on-track", class: "outcomes-badge" }  # omit if null
  budgetLine:
    amountField: "annualBudget"       # rendered "Budget: $300K/yr"
    spentField: "spentBudget"         # rendered "Spent: $245K" (hidden when null — grant-funded)
    spentPercentField: "spentPercent" # green pill "82%" (hidden when null)
    fallbackNote: "(grant-funded)" | "(reserve)"  # shown when spentBudget is null
  capacityBar:
    valueField: "capacityPercent"     # 0-100, 6px height, rounded
    fillClass: "fill-green | fill-amber | fill-teal | fill-red"
    rule: "green if <=60%, teal if 61-75%, amber if 76-90%, red if >90%"
    hiddenWhen: (maximumCapacity === null || statusCode === 'STANDBY')
  footerActions:
    - { label: "Manage",   icon: "fa-cog",        action: "openEditDrawer(programId)" }
    - { label: "Dashboard", icon: "fa-chart-pie",  action: "router.push('/crm/casemanagement/casedashboard?programId=' + programId)" }
```

**Responsive breakpoints**: 1 col (`xs`) → 2 col (`md`+) — matches mockup `grid-template-columns: repeat(2, 1fr)` and `@media (max-width: 768px) → 1fr`. Gap `1rem`, card padding `1.25rem`, radius `12px`.

**Grid Columns — displayed as card facets, but backend still projects them in `GetAll`:**

| # | Field Key | Display In Card | Notes |
|---|-----------|-----------------|-------|
| 1 | programCode | (hidden on card — tooltip on hover) | Unique code |
| 2 | iconEmoji | Leading emoji | Default 🎯 |
| 3 | programName | Card title | Primary |
| 4 | statusName / statusCode / statusColorHex | Badge (top-right) | Status pill |
| 5 | enrolledCount | Stats row line 1 | SERVICE_PLACEHOLDER (0 until Beneficiary) |
| 6 | maximumCapacity | Stats row line 2 | "—" if null |
| 7 | staffCount | Stats row line 3 | COUNT of ProgramStaff |
| 8 | onTrackPercent | Stats row line 4 | SERVICE_PLACEHOLDER (hidden when null) |
| 9 | annualBudget / budgetCurrencyCode | Budget line | "$300K/yr" formatted |
| 10 | spentBudget / spentPercent | Budget line (right) | SERVICE_PLACEHOLDER (hidden when null) |
| 11 | capacityPercent | Capacity bar | computed 0..100 |
| 12 | categoryName | (hidden on card — used for filter chips) | — |

**Search/Filter Fields** (toolbar above card grid):
- `searchText` → ILIKE across `programName`, `programCode`, `description`
- Filter chip / dropdown: by `CategoryId` (multi-select of PROGRAMCATEGORY)
- Filter chip / dropdown: by `StatusId` (multi-select of PROGRAMSTATUS)
- Sort options: Name (asc/desc), Start Date (desc), Capacity %, Enrolled Count

**Grid Actions**: Open Manage Drawer (primary card action), Navigate to Dashboard (secondary card action), Toggle Active (via drawer's footer save flow by changing StatusId), Soft-delete (via drawer menu → TBD; mockup has no delete on card). **ISSUE-6** — clarify where Delete lives (drawer "More" menu? context-menu on card?).

### Custom Side-Drawer Form (80% width, right-anchored)

> This is **NOT** an RJSF modal. It is a hand-built React component with RHF + zod.
> Header background `--cm-accent-bg` (#f0fdfa), header has emoji + programName + close-X.
> Body scroll, footer sticky with Save Program (primary) + View Enrolled Beneficiaries + View Program Dashboard + Cancel (right-aligned).

**Drawer Behavior:**
- Trigger: `+New Program` button → drawer opens empty (mode=new).
- Trigger: Card "Manage" button → drawer opens pre-filled (mode=edit, loads GetProgramById).
- Backdrop click / ESC / "Cancel" closes without save.
- "Save Program" submits → POST/PUT via Create/Update mutation → on success: close drawer + refresh grid + toast.
- URL does NOT change (no `?mode=...` query sync). Drawer state is component-local (useState).
- Body locks scroll while drawer is open (mockup's `document.body.style.overflow = 'hidden'`).

**Form Sections** (in drawer body, top-to-bottom):

| # | Section Title | Icon | Layout | Fields |
|---|---------------|------|--------|--------|
| 1 | Program Info | `fa-info-circle` | 2-col + 1-col description | programName (col-6), programCode (col-6, readonly when edit), description (col-12 textarea r=2), categoryId (col-4), statusId (col-4), startDate (col-4 month-input), endDate (col-4: toggle "Ongoing" + date-input disabled when ongoing), iconEmoji (col-4 emoji-picker or text w/ preview), colorHex (col-4 color-picker + hex label) |
| 2 | Eligibility Criteria | `fa-filter` | table + footer row | Inline table (Criteria field / Operator / Value / delete-btn) with "+Add Criteria" button + "Auto-Suggest" toggle on the right of footer |
| 3 | Capacity & Enrollment | `fa-users-cog` | 2-col + 2-col + 2-col grid | maximumCapacity (col-4 number), currentEnrollment (col-8 read-only computed: "{enrolledCount} ({capacityPercent}%)" + 8px bar), waitlistCount (col-4 read-only "{waitlistCount} beneficiaries"), enrollmentTypeId (col-4 dropdown), "Enrollment Requires" (col-4 checkbox group — requiresNeedsAssessment / requiresGuardianConsent / requiresMedicalClearance) |
| 4 | Sponsorship Model | `fa-hand-holding-usd` | 2-col | fundingModelId (col-6 dropdown), sponsorshipAmount + sponsorshipCurrencyId (col-6 — amount input + currency select — visible when fundingModelCode ∈ {INDIVIDUAL, MIXED}), poolFundingNote (col-12 textarea — visible when fundingModelCode ∈ {POOL, MIXED}) |
| 5 | Services Included | `fa-concierge-bell` | config cards | Per-service **card** (mirrors Eligibility Criteria card): header (ServiceName + remove); classification grid (ServiceType / ProviderType / FundingFlow — all MasterData selects); dashed **Cost Basis** block (CostPerUnit / UnitOfMeasure / Currency) shown only when FundingFlow ≠ In-Kind. "+Add Service" footer button. Pure Layer-1 catalog (no per-service mandatory/notes). |
| 6 | Outcome Metrics | `fa-bullseye` | table | Inline table (MetricName / TargetText / MeasurementText / FrequencyText / delete-btn) + "+Add Metric" footer button |
| 7 | Staff & Budget | `fa-users` | 2-col | programLeadStaffId (col-6 ApiSelectV2 of Staff), programStaffs (col-6 multi-select tag picker — add Staff → chip with remove X), annualBudget + budgetCurrencyId (col-4), fundingSources (col-8 free text), linkedDonationPurposeId (col-6 ApiSelectV2 of DonationPurpose — renders as link-chip with external-link icon in read view), linkedGrantId (col-6 SERVICE_PLACEHOLDER — read-only text chip for now; see **ISSUE-4**) |

**Field Widget Mapping**:

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| programName | text | "Enter program name" | required, 1..150 | — |
| programCode | text (readonly on edit) | "ORPHAN_SPONSOR" | required, 1..50, `^[A-Z][A-Z0-9_]{1,49}$` | uppercase enforcement via zod `.transform(s => s.toUpperCase())` |
| description | textarea rows=2 | "Describe the program objectives and scope..." | max 1000 | — |
| iconEmoji | text + emoji preview (or `<EmojiPickerWidget>` if exists) | "🎯" | max 10 chars | Default 🎯 |
| colorHex | `<input type="color">` + hex label | — | `^#[0-9A-Fa-f]{6}$` | Default `#0d9488` |
| categoryId | `<ApiSelectV2 query=getMasterDatas typeCode=PROGRAMCATEGORY>` | "Select category" | required | — |
| statusId | `<ApiSelectV2 query=getMasterDatas typeCode=PROGRAMSTATUS>` | "Select status" | required | — |
| startDate | `<input type="month">` | — | required, parses to DateOnly (1st of month) | — |
| endDate | `<input type="month">` | — | disabled when isOngoing=true; required when isOngoing=false; ≥ startDate | — |
| isOngoing | toggle switch | — | bool default true | When checked, FE sets endDate to null and disables endDate input |
| maximumCapacity | number | — | int ≥ 0, nullable | `—` label if null |
| enrollmentTypeId | `<ApiSelectV2 query=getMasterDatas typeCode=PROGRAMENROLLMENTTYPE>` | "Select type" | required | — |
| requiresNeedsAssessment / requiresGuardianConsent / requiresMedicalClearance | checkbox | — | bool | labeled "Needs assessment" / "Guardian consent" / "Medical clearance" |
| autoSuggestEnabled | toggle switch (footer of Eligibility Criteria section) | — | bool default true | — |
| fundingModelId | `<ApiSelectV2 query=getMasterDatas typeCode=PROGRAMFUNDINGMODEL>` | "Select funding model" | required | Drives visibility of sponsorshipAmount & poolFundingNote |
| sponsorshipAmount | number (decimal) | — | ≥ 0, nullable | Visible when fundingModelCode ∈ {INDIVIDUAL, MIXED} |
| sponsorshipCurrencyId | `<ApiSelectV2 query=getCurrencies>` | "Select currency" | nullable | Defaults to Company default currency |
| poolFundingNote | textarea rows=2 | "e.g., Remaining beneficiaries funded from general donations" | max 500 | Visible when fundingModelCode ∈ {POOL, MIXED} |
| programLeadStaffId | `<ApiSelectV2 query=getStaffs>` | "Select program lead" | nullable | display=staffName |
| programStaffs | **custom staff multi-picker widget** — search Staff → add chip → chip has remove X | — | unique StaffIds | Consumed by junction |
| annualBudget | number (decimal) | — | ≥ 0, nullable | — |
| budgetCurrencyId | `<ApiSelectV2 query=getCurrencies>` | — | nullable | — |
| fundingSources | text / textarea | "e.g., Individual sponsorships (70%)..." | max 500 | free text |
| linkedDonationPurposeId | `<ApiSelectV2 query=getDonationPurposes>` | "Select donation purpose" | nullable | renders as link-chip in read view |
| linkedGrantId | **disabled text chip** — "No grants available" tooltip | — | null | SERVICE_PLACEHOLDER until Grant (#62) |

**Eligibility Criteria Child-Grid widget spec**:

- Columns: `CriteriaField` (text input), `OperatorCode` (select with 6 options — see below), `CriteriaValue` (text input, placeholder varies by operator), delete-btn.
- "+ Add Criteria" button adds an empty row.
- Operator dropdown options (static FE-level enum — NOT MasterData):
  - `isOneOf` → "is one of"
  - `equals` → "equals"
  - `between` → "between"
  - `greaterThan` → "greater than"
  - `lessThan` → "less than"
  - `contains` → "contains"
- AutoSuggest toggle (footer right) binds to `autoSuggestEnabled`.

**Services Included config-card widget spec** (Layer-1 program template — mirrors the Eligibility Criteria card):

- Each service is a **card**, not a table row. Header: `ServiceName` (text) + remove button.
- Classification grid (3-col): `ServiceTypeId` (MasterData PROGRAMSERVICETYPE), `ProviderTypeId` (MasterData PROGRAMSERVICEPROVIDERTYPE), `FundingFlowId` (MasterData PROGRAMSERVICEFUNDINGFLOW). All `<FormSearchableSelect>` with `advancedFilter` on `masterDataType.typeCode`.
- **ProviderType is the generic *kind*** (Internal Staff / Educational Institution / …), NOT a named provider. The actual named provider (e.g. a specific school) + actual amount are captured **per beneficiary at Layer 2** (#49); the actual money transfer is Layer 3 (funding rework #4–#6). One Program service row → N beneficiaries → N named providers.
- Dashed **Cost Basis** block (`CostPerUnit` decimal / `UnitOfMeasure` text / `CurrencyId` select) is shown **only when the selected FundingFlow code ≠ `INKIND`** (gated via a form-only `fundingFlowCode` mirror set through `onSelectOption`, same pattern as `programTypeCode`). In-kind/free services leave cost blank; FE nulls cost on submit when in-kind.
- "+ Add Service" button. **No** per-service mandatory flag or notes/instructions field — Services is a pure Layer-1 catalog; *which* services a beneficiary receives is decided per-beneficiary at Layer 2 (#49).

**Outcome Metrics Child-Grid widget spec**:

- Columns: `MetricName` (text), `TargetText` (text — e.g., ">90%"), `MeasurementText` (text), `FrequencyText` (text), delete-btn.
- "+ Add Metric" button.

### Page Widgets & Summary Cards

**Widgets**: **NONE** — mockup has no top-of-page KPI/count widgets.

**Layout Variant**: `grid-only` *(no widgets-above-grid, no side-panel)* — **BUT Variant B mandatory** because `<CardGrid>` has no internal page header/toolbar. FE Dev uses `<ScreenHeader>` for page title/subtitle/"+ New Program" action, then `<CardGrid>` below. This mirrors Family #20 and other card-grid consumers. Do NOT use Variant A (AdvancedDataTable-with-internal-header) — it would conflict with the CardGrid render path.

### Grid Aggregation Columns (rendered ON each card)

| Column | Value Description | Source | Implementation |
|--------|-------------------|--------|----------------|
| staffCount | Count of active staff assigned to program | `ProgramStaffs` junction COUNT | LINQ subquery in GetAll projection |
| enrolledCount | Count of beneficiaries enrolled in this program | `Beneficiaries` table COUNT (NOT BUILT YET) | **SERVICE_PLACEHOLDER** — return `0` constant in projection; TODO when Beneficiary #49 lands |
| waitlistCount | Count of beneficiaries on waitlist | `Beneficiaries WHERE EnrollmentStatusCode='WAITLIST'` | **SERVICE_PLACEHOLDER** — return `0` |
| capacityPercent | `enrolledCount * 100 / MaximumCapacity` | derived | computed in projection (null-safe ÷) |
| spentBudget / spentPercent | Sum of donations/grant expenditure tagged to this program | Donation/Grant entities | **SERVICE_PLACEHOLDER** — return `null` for spentBudget, `null` for spentPercent |
| onTrackPercent | Weighted % of outcome metrics attaining target | Case outcome attainment | **SERVICE_PLACEHOLDER** — return `null` |

All placeholder values: the FE renders a gray "—" or hides the element when null. A tooltip reads "Computed when downstream modules are available".

### Side Panels / Info Displays

**Side Panel**: **NONE** — the drawer is the edit form, not a viewer panel.

### User Interaction Flow

1. User lands on `/{lang}/crm/casemanagement/programmanagement` → page renders `<ScreenHeader>` with title "Programs", subtitle "Define and manage beneficiary programs and services", right action "+ New Program".
2. `<CardGrid>` below renders all programs as `program`-variant cards (2-col md+, 1-col xs).
3. User clicks **"+ New Program"** → side-drawer (80% width, right) slides in; title "New Program"; form empty; status/category/etc. default values.
4. User fills Sections 1-7, adds eligibility/service/metric rows, selects staff → clicks **Save Program** → mutation fires → on success toast "Program created", drawer closes, grid refreshes.
5. User clicks a card's **Manage** button → drawer opens pre-filled via `getProgramById(id)`; title updates to "{programName}"; form hydrated.
6. User edits → **Save Program** → mutation fires → same close/refresh.
7. User clicks a card's **Dashboard** button → `router.push('/{lang}/crm/casemanagement/casedashboard?programId={id}')`.
8. In drawer footer: **View Enrolled Beneficiaries** → `router.push('/{lang}/crm/casemanagement/beneficiarylist?programId={id}')`; **View Program Dashboard** → same as Dashboard button.
9. Toggle active/inactive: changing `statusId` in drawer is the primary mechanism. There is NO separate toggle button on cards in the mockup.
10. Delete: **out of mockup** — see **ISSUE-6**. Default: add a "Delete" option to drawer header "⋮" menu or as a secondary footer action (hidden for STANDBY programs and for system/seeded programs).

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to Program. Program has no direct single-entity canonical (no simple MASTER_GRID has child collections this rich) — use **ContactType for CRUD skeleton** + **Campaign #39 child-collection diff-persist pattern**.

**Canonical Reference**: ContactType (MASTER_GRID CRUD skeleton) + Campaign (#39) for child-collection child-grid pattern + SavedFilter #27 / Family #20 for card-grid wiring + NotificationTemplate (#36) for inline child-grid diff-persist.

| Canonical (ContactType) | → Program | Context |
|-------------------------|-----------|---------|
| ContactType | Program | Entity/class name |
| contactType | program | Variable/field names |
| ContactTypeId | ProgramId | PK |
| ContactTypes | Programs | Table name (DbSet, plural) |
| contact-type | program | FE kebab folder (do NOT use `program-management` — FE route is `programmanagement` per MODULE_MENU_REFERENCE) |
| contacttype | program | FE folder / import path |
| CONTACTTYPE | PROGRAM | Grid code, DecoratorCaseModules entry (`DecoratorCaseModules.Program = "PROGRAM"`) |
| corg | case | DB schema (NEW) |
| Corg | Case | Backend group name (NEW) |
| CorgModels | CaseModels | Namespace suffix (NEW) |
| CorgConfigurations | CaseConfigurations | EF configurations folder (NEW) |
| CorgSchemas | CaseSchemas | DTO namespace (NEW) |
| CorgBusiness | CaseBusiness | Commands/Queries root namespace (NEW) |
| CONTACT | CASEMANAGEMENT | Parent menu code (`CRM_CASEMANAGEMENT`) |
| CRM | CRM | Module code (same) |
| crm/contact/contacttype | crm/casemanagement/programmanagement | FE route path |
| contact-service | **case-service** (NEW FE service folder) | FE service folder name |

**Reference patterns**:

| Need | Look at |
|------|---------|
| Basic CRUD 11 files | ContactType (#19) |
| Child 1:M diff-persist in Create/Update handler | Campaign (#39) impactMetrics / milestones, or NotificationTemplate (#36) template children |
| Junction M:N diff-persist (ProgramStaff) | Family (#20) `setFamilyMembers`, or `ContactTag` / `Segment` — **ContactModels junction** pattern |
| CardGrid wiring + new variant | Email Template (#24) — added `iframe` variant; follow the same shell-untouched pattern for `program` variant |
| Side-drawer form (80% width) | SavedFilter (#27) field-setting drawer, or Beneficiary/Contact detail panel |
| NEW module bootstrap (schema + DbContext + Mappings + Decorator) | **No direct precedent in repo** — must read existing Notify/Contact module structure and extrapolate. See Special Notes §⑫ |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Exact files to create, with computed paths. No guessing.

### Backend — New Module Bootstrap (4 created + 5 wiring modifications)

| # | File | Path | Purpose |
|---|------|------|---------|
| B1 | ICaseDbContext.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Data/Persistence/ICaseDbContext.cs` | DbSet signatures for all 5 case entities |
| B2 | CaseDbContext.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Persistence/CaseDbContext.cs` | EF DbContext implementing ICaseDbContext |
| B3 | CaseMappings.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Mappings/CaseMappings.cs` | `public static void ConfigureMappings() { ... }` — Mapster maps |
| B4 | DecoratorCaseModules (add to DecoratorProperties.cs) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Extensions/DecoratorProperties.cs` | Add new class `public static class DecoratorCaseModules { public const string Program = "PROGRAM", ProgramEligibilityCriterion = "PROGRAMELIGIBILITYCRITERION", ProgramService = "PROGRAMSERVICE", ProgramOutcomeMetric = "PROGRAMOUTCOMEMETRIC", ProgramStaff = "PROGRAMSTAFF"; }` |

**Backend Wiring Updates for new module:**

| # | File | Change |
|---|------|--------|
| W1 | IApplicationDbContext.cs | Add `ICaseDbContext` to inheritance list |
| W2 | DependencyInjection.cs (Base.Infrastructure) | Register `CaseDbContext` in `AddDbContext` / register interface mapping |
| W3 | DependencyInjection.cs (Base.Application) | Call `CaseMappings.ConfigureMappings()` |
| W4 | GlobalUsing.cs (Base.Application) | Add `global using Base.Application.Data.Persistence;` if not present; add `global using Base.Domain.Models.CaseModels;` + `global using Base.Application.Schemas.CaseSchemas;` + `global using Base.Application.Business.CaseBusiness.Programs.*` (as needed) |
| W5 | GlobalUsing.cs (Base.Infrastructure) | Add `global using Base.Domain.Models.CaseModels;` |
| W6 | GlobalUsing.cs (Base.API) | Add `global using Base.Application.Schemas.CaseSchemas;` + `global using Base.Application.Business.CaseBusiness.Programs.Queries;` etc. |

### Backend — Entities + EF Configs (5 entities + 5 configs = 10 files)

| # | File | Path |
|---|------|------|
| E1 | Program.cs | `PSS_2.0_Backend/.../Base.Domain/Models/CaseModels/Program.cs` |
| E2 | ProgramEligibilityCriterion.cs | `PSS_2.0_Backend/.../Base.Domain/Models/CaseModels/ProgramEligibilityCriterion.cs` |
| E3 | ProgramService.cs | `PSS_2.0_Backend/.../Base.Domain/Models/CaseModels/ProgramService.cs` |
| E4 | ProgramOutcomeMetric.cs | `PSS_2.0_Backend/.../Base.Domain/Models/CaseModels/ProgramOutcomeMetric.cs` |
| E5 | ProgramStaff.cs | `PSS_2.0_Backend/.../Base.Domain/Models/CaseModels/ProgramStaff.cs` |
| C1 | ProgramConfiguration.cs | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/CaseConfigurations/ProgramConfiguration.cs` |
| C2 | ProgramEligibilityCriterionConfiguration.cs | same folder |
| C3 | ProgramServiceConfiguration.cs | same folder |
| C4 | ProgramOutcomeMetricConfiguration.cs | same folder |
| C5 | ProgramStaffConfiguration.cs | same folder — enforce composite unique (ProgramId, StaffId) |

### Backend — Schemas / DTOs (1 file)

| # | File | Path |
|---|------|------|
| S1 | ProgramSchemas.cs | `PSS_2.0_Backend/.../Base.Application/Schemas/CaseSchemas/ProgramSchemas.cs` |

Contains:
- `ProgramRequestDto` (Create/Update — includes inline child arrays `eligibilityCriteria`, `services`, `outcomeMetrics`, `staffIds`)
- `ProgramResponseDto` (GetAll flat card columns + nested child arrays optional for GetById)
- `ProgramListItemDto` (lightweight for grid — omits child collections, includes computed counts)
- `ProgramCardDto` (if distinct from ListItem)
- `ProgramEligibilityCriterionDto`, `ProgramServiceDto`, `ProgramOutcomeMetricDto`, `ProgramStaffDto`
- `ProgramSummaryDto` — *defer: no top-of-page KPI widgets, so no summary query for MVP* (can add later)

### Backend — Business (Commands + Queries = 6 files)

| # | File | Path |
|---|------|------|
| CQ1 | CreateProgram.cs | `PSS_2.0_Backend/.../Base.Application/Business/CaseBusiness/Programs/CreateCommand/CreateProgram.cs` |
| CQ2 | UpdateProgram.cs | `PSS_2.0_Backend/.../Base.Application/Business/CaseBusiness/Programs/UpdateCommand/UpdateProgram.cs` |
| CQ3 | DeleteProgram.cs | `PSS_2.0_Backend/.../Base.Application/Business/CaseBusiness/Programs/DeleteCommand/DeleteProgram.cs` |
| CQ4 | ToggleProgram.cs | `PSS_2.0_Backend/.../Base.Application/Business/CaseBusiness/Programs/ToggleCommand/ToggleProgram.cs` |
| CQ5 | GetAllPrograms.cs | `PSS_2.0_Backend/.../Base.Application/Business/CaseBusiness/Programs/GetAllQuery/GetAllPrograms.cs` |
| CQ6 | GetProgramById.cs | `PSS_2.0_Backend/.../Base.Application/Business/CaseBusiness/Programs/GetByIdQuery/GetProgramById.cs` |

### Backend — Endpoints (2 files)

| # | File | Path |
|---|------|------|
| EP1 | ProgramMutations.cs | `PSS_2.0_Backend/.../Base.API/EndPoints/Case/Mutations/ProgramMutations.cs` |
| EP2 | ProgramQueries.cs | `PSS_2.0_Backend/.../Base.API/EndPoints/Case/Queries/ProgramQueries.cs` |

**Backend total**: 4 (bootstrap) + 6 (wiring mods) + 10 (entities/configs) + 1 (schemas) + 6 (business) + 2 (endpoints) = **23 created + 6 modified** + **1 EF migration** (`AddCaseModule_Programs_Initial`).

### Frontend — DTO + GQL (3 created)

| # | File | Path |
|---|------|------|
| F1 | ProgramDto.ts | `PSS_2.0_Frontend/src/domain/entities/case-service/ProgramDto.ts` *(NEW service folder `case-service`)* |
| F2 | ProgramQuery.ts | `PSS_2.0_Frontend/src/infrastructure/gql-queries/case-queries/ProgramQuery.ts` *(NEW folder)* |
| F3 | ProgramMutation.ts | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/case-mutations/ProgramMutation.ts` *(NEW folder)* |

### Frontend — Page + Components (9 created + 1 overwritten)

| # | File | Path |
|---|------|------|
| F4 | Page config (exports `<ProgramManagementPage>`) | `PSS_2.0_Frontend/src/presentation/pages/crm/casemanagement/program.tsx` *(check `pages/crm/casemanagement/` existing exports in `index.ts` — may need modification)* |
| F5 | Index page component (Variant B: ScreenHeader + CardGrid) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/index-page.tsx` |
| F6 | Program card variant | `PSS_2.0_Frontend/src/presentation/components/page-components/card-grid/variants/program-card.tsx` |
| F7 | Program card skeleton | `PSS_2.0_Frontend/src/presentation/components/page-components/card-grid/skeletons/program-card-skeleton.tsx` |
| F8 | Program drawer container (80%-right, backdrop, ESC, body-lock) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/program-drawer.tsx` |
| F9 | Program form (7 sections, RHF + zod) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/program-form.tsx` |
| F10 | Form schemas (zod) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/program-form-schemas.ts` |
| F11 | Eligibility criteria child-grid | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/program-eligibility-criteria-table.tsx` |
| F12 | Services child-grid | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/program-services-table.tsx` |
| F13 | Outcome metrics child-grid | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/program-outcome-metrics-table.tsx` |
| F14 | Staff multi-select picker | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/program-staff-picker.tsx` |
| F15 | Route page (OVERWRITE existing stub) | `PSS_2.0_Frontend/src/app/[lang]/crm/casemanagement/programmanagement/page.tsx` *(replace the 4-line "Need to Develop" stub)* |

### Frontend — Wiring Updates (4–6 files modified)

| # | File | What to Add |
|---|------|-------------|
| FW1 | `src/application/configs/data-table-configs/case-service-entity-operations.ts` *(CREATE NEW FILE — first case-service file)* | `CaseServiceEntityOperations` array with `PROGRAM` entry — mirror pattern from `contact-service-entity-operations.ts` |
| FW2 | `src/application/configs/data-table-configs/index.ts` | Import + spread `CaseServiceEntityOperations` into `DataTableOperationConfigs` |
| FW3 | `src/presentation/components/page-components/card-grid/card-variant-registry.ts` | Register `program` variant mapping |
| FW4 | `src/presentation/components/page-components/card-grid/types.ts` *(IF variants are typed-union)* | Add `'program'` to the `CardVariant` union |
| FW5 | `src/presentation/pages/crm/index.ts` or `.../casemanagement/index.ts` | Export `ProgramManagementPage` |
| FW6 | Sidebar menu (if hardcoded) | Menu `PROGRAMMANAGEMENT` typically loaded from DB seed — verify; no FE code change needed if dynamic |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: FULL

MenuName: Program Management
MenuCode: PROGRAMMANAGEMENT
ParentMenu: CRM_CASEMANAGEMENT
Module: CRM
MenuUrl: crm/casemanagement/programmanagement
GridType: MASTER_GRID
OrderBy: 4

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT

GridFormSchema: SKIP    # form is code-driven (RHF + zod), not RJSF
GridCode: PROGRAMMANAGEMENT

GridColumns (FLOW card-grid — 12 fields, no RJSF fieldSchema):
  - iconEmoji | Icon | EmojiPreview | 50px
  - programName | Name | text-bold | auto
  - programCode | Code | text-mono | 120px
  - statusName | Status | status-badge | 110px
  - categoryName | Category | text | 140px
  - maximumCapacity | Capacity | number | 90px
  - enrolledCount | Enrolled | number | 90px
  - staffCount | Staff | number | 80px
  - annualBudget | Budget | currency | 130px
  - spentPercent | Spent % | percent-pill | 90px
  - startDate | Start | DateOnlyPreview | 120px
  - onTrackPercent | On Track | percent-badge | 100px

MasterDataTypes (seed — 5 types):
  - PROGRAMCATEGORY (8 rows): Child Welfare, Education, Healthcare, Livelihood, WASH, Protection, Nutrition, Emergency
  - PROGRAMSTATUS (5 rows w/ ColorHex in DataSetting):
      Active    → #166534 (green)
      Paused    → #b45309 (amber)
      Completed → #0e7490 (teal)
      Planned   → #475569 (slate)
      Standby   → #92400e (brown)
  - PROGRAMFUNDINGMODEL (4 rows): Individual Sponsorship (code=INDIVIDUAL), Pool Funded (code=POOL), Grant Funded (code=GRANT), Mixed (code=MIXED)
  - PROGRAMENROLLMENTTYPE (4 rows): Open, Waitlist Only, Closed, By Referral
  - PROGRAMCRITERIAOPERATOR (6 rows — OPTIONAL: operator codes can live purely as FE enum):
      is one of (code=isOneOf), equals, between, greater than (code=greaterThan), less than (code=lessThan), contains
  (Operator list is rendered client-side; seeding MasterData is optional. RECOMMENDED: seed for consistency with rule-engine patterns.)

SampleRows (seed 3 programs end-to-end for visual verification):
  1. Orphan Sponsorship (ORPHAN_SPONSOR, 🧒, #0d9488, Category=Child Welfare, Status=Active, Capacity=600, Enrolled=0 placeholder, Budget=300000 USD, IsOngoing=true, FundingModel=Mixed, SponsorshipAmount=490, 3 criteria, 7 services, 5 metrics, 4 staff junctions)
  2. Clean Water Initiative (CLEAN_WATER, 💧, #06b6d4, Category=WASH, Status=Active, Capacity=50, Budget=500000 USD grant-funded [spentBudget=null], FundingModel=Grant)
  3. Emergency Relief (EMERGENCY_RELIEF, 🆘, #dc2626, Category=Emergency, Status=Standby, Capacity=null, Budget=50000 USD reserve)

Menu seed: PROGRAMMANAGEMENT at OrderBy=4 under CRM_CASEMANAGEMENT (after BENEFICIARYLIST=1, BENEFICIARYFORM=2, CASELIST=3, PROGRAMMANAGEMENT=4 per MODULE_MENU_REFERENCE.md).

Seed file location: `sql-scripts-dyanmic/` (preserve repo typo — ChequeDonation #6 precedent).
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose before BE is even built.

**GraphQL Types:**
- Query type: `ProgramQueries`
- Mutation type: `ProgramMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getPrograms` | `PaginatedApiResponse<[ProgramListItemDto]>` | `GridFeatureRequest` (searchText, pageNo, pageSize, sortField, sortDir, isActive, categoryId?, statusId?) |
| `getProgramById` | `BaseApiResponse<ProgramResponseDto>` | `programId` |

> **Note**: no `getProgramSummary` query for MVP — mockup has no top-of-page KPI widgets. Add later if needed.

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createProgram` | `ProgramRequestDto` (includes `eligibilityCriteria[]`, `services[]`, `outcomeMetrics[]`, `staffIds[]`) | `int` (new `ProgramId`) |
| `updateProgram` | `ProgramRequestDto` (includes `programId` + all children for diff-persist) | `int` |
| `deleteProgram` | `programId: Int!` | `int` |
| `toggleProgram` | `programId: Int!` | `int` |

**Response DTO Fields — `ProgramResponseDto` (what FE receives on GetById):**

| Field | Type | Notes |
|-------|------|-------|
| programId | number | PK |
| programCode | string | — |
| programName | string | — |
| description | string? | — |
| iconEmoji | string? | Default server-side fallback 🎯 |
| colorHex | string? | Default `#0d9488` |
| categoryId | number | FK |
| categoryName | string | FK display |
| categoryCode | string? | FK code |
| statusId | number | FK |
| statusName | string | FK display |
| statusCode | string | FK code — FE uses for badge color + standby mode detection |
| statusColorHex | string? | FK color from MasterData.DataSetting JSON |
| startDate | string (ISO date) | — |
| endDate | string (ISO date)? | null when IsOngoing=true |
| isOngoing | boolean | — |
| fundingModelId | number | FK |
| fundingModelName | string | — |
| fundingModelCode | string | — |
| sponsorshipAmount | number? | — |
| sponsorshipCurrencyId | number? | — |
| sponsorshipCurrencyCode | string? | e.g., "AED", "USD" |
| sponsorshipFrequencyCode | string? | — |
| poolFundingNote | string? | — |
| maximumCapacity | number? | — |
| enrollmentTypeId | number | FK |
| enrollmentTypeName | string | — |
| enrollmentTypeCode | string | — |
| requiresNeedsAssessment | boolean | — |
| requiresGuardianConsent | boolean | — |
| requiresMedicalClearance | boolean | — |
| autoSuggestEnabled | boolean | — |
| programLeadStaffId | number? | — |
| programLeadStaffName | string? | — |
| annualBudget | number? | — |
| budgetCurrencyId | number? | — |
| budgetCurrencyCode | string? | — |
| fundingSources | string? | — |
| linkedDonationPurposeId | number? | — |
| linkedDonationPurposeName | string? | — |
| linkedGrantId | number? | — **SERVICE_PLACEHOLDER** (string or null for now) |
| linkedGrantName | string? | — SERVICE_PLACEHOLDER |
| isActive | boolean | Inherited from Entity |
| enrolledCount | number | SERVICE_PLACEHOLDER — always 0 for MVP |
| waitlistCount | number | SERVICE_PLACEHOLDER — always 0 |
| capacityPercent | number | Computed: enrolledCount*100/maximumCapacity, null-safe |
| staffCount | number | COUNT of active ProgramStaff — BUILDABLE |
| spentBudget | number? | SERVICE_PLACEHOLDER — null |
| spentPercent | number? | SERVICE_PLACEHOLDER — null |
| onTrackPercent | number? | SERVICE_PLACEHOLDER — null |
| eligibilityCriteria | `ProgramEligibilityCriterionDto[]` | (on GetById) |
| services | `ProgramServiceDto[]` | (on GetById) |
| outcomeMetrics | `ProgramOutcomeMetricDto[]` | (on GetById) |
| staffs | `ProgramStaffDto[]` (each has staffId + staffName) | (on GetById) — for tag chip display |

**Child DTO fields** (ProgramEligibilityCriterionDto): `id`, `programId`, `criteriaField`, `operatorCode`, `criteriaValue`, `orderBy`, `isActive`.
**ProgramServiceDto**: `id`, `programId`, `serviceName`, `serviceTypeId`, `serviceTypeName`/`serviceTypeCode` (response-only joined), `providerTypeId`, `providerTypeName`/`providerTypeCode` (response-only), `fundingFlowId`, `fundingFlowName`/`fundingFlowCode` (response-only), `costPerUnit`, `unitOfMeasure`, `currencyId`, `currencyCode` (response-only), `orderBy`, `isActive`. (Joined names via Mapster `.Map()` in `CaseMappings.cs`.)
**ProgramOutcomeMetricDto**: `id`, `programId`, `metricName`, `targetText`, `measurementText`, `frequencyText`, `orderBy`, `isActive`.
**ProgramStaffDto**: `id`, `programId`, `staffId`, `staffName`, `staffEmpId?`, `isActive`.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (new `case` schema registered; EF design snapshot clean; migration applied)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/casemanagement/programmanagement`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] CardGrid renders seeded programs (3 sample programs visible)
- [ ] Each card shows: emoji, name, status badge, 4 stat lines, budget line, capacity bar, Manage + Dashboard action buttons
- [ ] Standby program (Emergency Relief) renders with dashed border + 0.75 opacity
- [ ] Search filters by `programName`, `programCode`, `description`
- [ ] Category + Status filter chips/dropdowns work
- [ ] Click "+ New Program" → drawer opens (80% width, right) with empty form + backdrop
- [ ] ESC closes drawer; backdrop click closes; Cancel closes
- [ ] Click card Manage → drawer opens pre-filled; title = programName with leading emoji
- [ ] Click card Dashboard → navigates to `/casemanagement/casedashboard?programId=X`
- [ ] Section 1 — all fields render; "Ongoing" toggle disables End Date; month-input accepted; color picker + hex label sync; emoji rendered
- [ ] Section 2 — Eligibility Criteria table loads 3 rows for Orphan Sponsorship; Add Criteria inserts empty row; delete icon removes row; Auto-Suggest toggle persists
- [ ] Section 3 — Capacity input + computed enrollment (0 for MVP); Waitlist shows 0; 3 "Enrollment Requires" checkboxes persist
- [ ] Section 4 — Funding Model dropdown; selecting Individual/Mixed reveals sponsorshipAmount+currency; Pool/Mixed reveals poolFundingNote
- [ ] Section 5 — Services table loads 7 rows for Orphan Sponsorship; Add/Delete works
- [ ] Section 6 — Outcome Metrics table loads 5 rows for Orphan Sponsorship; Add/Delete works
- [ ] Section 7 — Program Lead ApiSelectV2 loads Staffs; Staff picker adds/removes tags; Annual Budget + Currency; Funding Sources free text; Linked Donation Purpose ApiSelectV2 loads DonationPurposes; Linked Grant is disabled chip
- [ ] Save creates Program + all 4 child collections atomically
- [ ] Edit loads all children + existing tags → edit → Save persists diff (add new / update existing / delete removed)
- [ ] Toggle via StatusId change → card badge updates; Standby → dashed border on save
- [ ] Delete (wherever Delete lives per ISSUE-6) → confirm → cascade removes children
- [ ] FK validation — removing a category MasterData row while referenced by a Program is blocked (restrict) — test via DB tool
- [ ] Tenant scope — GetAll returns only current company's programs (HttpContext CompanyId filter)
- [ ] Permissions — BUSINESSADMIN has all capabilities; a user without MODIFY cannot save edits (footer Save disabled)
- [ ] SERVICE_PLACEHOLDER fields render correctly: enrolledCount=0, waitlistCount=0, spentBudget hidden, spentPercent hidden, onTrackPercent hidden or "—"
- [ ] Standby program hides capacity bar and "% on-track"

**DB Seed Verification:**
- [ ] Menu `PROGRAMMANAGEMENT` appears in sidebar under `Case Management` (ParentMenu `CRM_CASEMANAGEMENT`) at OrderBy=4
- [ ] 5 MasterDataTypes + all their rows visible in Settings → Master Data
- [ ] 3 sample programs render in card grid (Orphan Sponsorship / Clean Water / Emergency Relief)
- [ ] Sample program opens in drawer with all child collections populated

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **NEW MODULE — case schema**: This is the **FIRST** entity in the `case` schema. Backend agent MUST create the `ICaseDbContext`, `CaseDbContext`, `CaseMappings`, `DecoratorCaseModules` infrastructure BEFORE generating Program. Follow the existing Notify / Contact / Donation / Field module structure. Sibling screens (Beneficiary #49, Case #50, Case Note, Beneficiary Form) will share this DbContext and will each add DbSets via `//IDbContextLines` marker. Program is the only entity seeded in this session, but design the DbContext so adding future entities is just adding DbSet lines.
- **FK-target module mismatch alert**: Program references entities across 3 other modules — Staff (Application / `app` schema), DonationPurpose (Donation / `fund` schema), MasterData (Setting / `sett` schema), Currency (Shared / `shared` schema). Because `IApplicationDbContext` inherits all the relevant sub-contexts, `CaseDbContext` only needs `ICaseDbContext` — the cross-module navigations work via the top-level App context. Do NOT try to make CaseDbContext inherit ApplicationDbContext.
- **No RJSF / no GridFormSchema**: `GridFormSchema = SKIP`. The drawer form is 100% React code. Do NOT generate an RJSF JSON form schema into the DB seed.
- **CardGrid new variant (`program`)**: This screen EXTENDS existing `<CardGrid>` infra (built in #29 SMS Template). Add ONE variant file + ONE skeleton + ONE registry line. Shell (`card-grid.tsx`, `card-variant-registry.ts`, `types.ts`) is UNTOUCHED except for the registry line and variant-union addition. Reference #24 Email Template's `iframe` variant addition as the pattern.
- **FE `case-service` folder is NEW**: Create `src/domain/entities/case-service/`, `src/infrastructure/gql-queries/case-queries/`, `src/infrastructure/gql-mutations/case-mutations/`, `src/application/configs/data-table-configs/case-service-entity-operations.ts`. Register the new operations file in `data-table-configs/index.ts`.
- **Page route preserves `programmanagement`**: Per MODULE_MENU_REFERENCE.md, MenuUrl = `crm/casemanagement/programmanagement`. DO NOT rename to `program` or `program-management` — the existing stub lives at `app/[lang]/crm/casemanagement/programmanagement/page.tsx` and the DB menu seed will reference that exact URL.
- **Variant B mandatory despite `grid-only` layout**: `<CardGrid>` has no internal page header. Use `<ScreenHeader>` for title/subtitle/+ New action + `<CardGrid>` below. This mirrors Family #20. Variant A will NOT work with card-grid.
- **Eligibility Criteria is a data rule-engine, not an ad-hoc note**: The rows (`field + operator + value`) feed the Beneficiary #49 auto-match logic. For THIS session, only persist the rows + the `autoSuggestEnabled` flag — the matching runtime is out of scope (part of Beneficiary build).
- **ProgramLeadStaffId vs ProgramStaff junction**: The Program Lead is a single FK on Program, NOT a row in the ProgramStaff junction. If UX wants the lead always in the staff list, FE auto-adds. Backend does NOT auto-sync.
- **Operator list — FE enum, NOT MasterData (unless seeding recommended)**: The 6 operators are a fixed client-side list. Seeding as MasterData (TypeCode `PROGRAMCRITERIAOPERATOR`) is OPTIONAL but RECOMMENDED for consistency with other rule engines. If seeded, FE still uses a static list — the seed just documents the enum in the DB.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER: enrolledCount / waitlistCount** — Full UI renders "N beneficiaries" line on each card, 0-default. Backend returns `0` until Beneficiary (#49) is built. Add `TODO(#49)` comment on the projection. Drawer Section 3 "Current Enrollment" displays the computed 0 with a neutral progress bar.
- ⚠ **SERVICE_PLACEHOLDER: spentBudget / spentPercent** — Card budget line renders "Spent: $X  (Y%)" only when not-null. Backend returns `null` until a program→donation attribution link exists (depends on GlobalDonation.ProgramId FK, not yet added; track as cross-screen follow-up when Beneficiary+Case screens land).
- ⚠ **SERVICE_PLACEHOLDER: onTrackPercent** — Hidden when null. Requires case outcome attainment — computed when Case #50 + CaseOutcome entity land.
- ⚠ **SERVICE_PLACEHOLDER: linkedGrantId** — Drawer Section 7 renders disabled chip with "Linked Grant (coming soon)". Field persists as nullable int with NO FK constraint until Grant #62 lands. No DB migration needed when Grant arrives — just add the FK constraint then.
- ⚠ **Emoji picker widget** — if a shared emoji-picker widget doesn't exist in the codebase, FE renders a plain text input with a live emoji preview span. Do not block the build to create a picker; a picker can be a separate enhancement.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Plan 2026-04-21 | MED | BE Projection | `enrolledCount` / `waitlistCount` computed fields require Beneficiary (#49) entity. For MVP, projection returns constant `0`. When Beneficiary lands, replace with `Beneficiaries.Count(...)` subquery. Cross-screen follow-up. | OPEN |
| ISSUE-2 | Plan 2026-04-21 | MED | BE Projection | `spentBudget` / `spentPercent` require GlobalDonation.ProgramId attribution FK (not currently on GlobalDonation) + Grant expenditure. Defer to downstream build when Case Management donations attribution is introduced. Card shows `(grant-funded)` / `(reserve)` / hidden spent line in the meantime. | OPEN |
| ISSUE-3 | Plan 2026-04-21 | MED | BE Projection | `onTrackPercent` requires Case #50 outcome attainment ledger. Hide when null. Cross-screen follow-up. | OPEN |
| ISSUE-4 | Plan 2026-04-21 | MED | Schema | `LinkedGrantId` stored as nullable int with NO FK until Grant (#62). FE renders read-only disabled chip. When Grant lands, a follow-up migration adds the FK constraint and backfills the label join. | OPEN |
| ISSUE-5 | Plan 2026-04-21 | LOW | BE Delete Guard | Delete-guard for programs with enrolled Beneficiaries (#49) / cases (#50) cannot be enforced until those entities exist. For MVP, allow delete (cascade on children). Add the guard as a cross-screen follow-up when #49 lands. | OPEN |
| ISSUE-6 | Plan 2026-04-21 | LOW | UX | Mockup does NOT show a Delete affordance on cards. Default decision: place Delete in drawer header "⋮" overflow menu OR as a secondary footer button (danger-styled). User to confirm during Approval phase. | OPEN |
| ISSUE-7 | Plan 2026-04-21 | LOW | FE | Emoji picker widget presence unknown. Default: plain text input + live preview span. Upgrade to picker later. | OPEN |
| ISSUE-8 | Plan 2026-04-21 | LOW | FE | Dashboard button navigates to `crm/casemanagement/casedashboard` — this screen is `SKIP_DASHBOARD` (#52) and does not exist. Link may 404 or land on a placeholder. Confirm with Case Dashboard plan before go-live. | OPEN |
| ISSUE-9 | Plan 2026-04-21 | LOW | DB Seed | `MasterDataType PROGRAMCRITERIAOPERATOR` seed is OPTIONAL (operator list is FE-static). Recommended to seed for discoverability, but FE does not consume it. | OPEN |
| ISSUE-10 | Plan 2026-04-21 | LOW | BE Schema | `shared.Currencies` FK resolution — verify Currency table schema + GQL query name (`getCurrencies`?) during build. If FK target is different, update Section ③ accordingly. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

> _[18 older session entries trimmed to save tokens — full history in git: `git log -p -- program.md`. Most recent 5 kept below.]_

### Session 16 — 2026-06-19 — ENHANCE — COMPLETED

- **Scope**: Restructured **Services Included** from free-text into a Layer-1 structured template, mirroring the Eligibility-Criteria verification card concept. `ProgramService` free-text `FrequencyText`/`ProviderText`/`CostPerUnitText` **replaced** with: `ServiceTypeId` (PROGRAMSERVICETYPE), `ProviderTypeId` (PROGRAMSERVICEPROVIDERTYPE — the *provider TYPE*, not a named org), `FundingFlowId` (PROGRAMSERVICEFUNDINGFLOW), `CostPerUnit`+`UnitOfMeasure`+`CurrencyId` (cost basis, shown only for a paid funding flow). Picks up the structured-cost item parked in Session 15. **Post-build trim (same session, user review):** dropped the initially-included `IsMandatory` + `Instructions` from services — Services is a pure Layer-1 *catalog*; *which* services a beneficiary receives (all / a subset) is a per-beneficiary Layer-2 (#49) decision, so a program-level mandatory flag was semantically wrong and the notes box was redundant. (Eligibility-criteria `IsMandatory`/`Instructions` are untouched — correct there as a hard-block gate.) **Domain framing** (agreed with user): provider TYPE is generic (e.g. "Educational Institution"); the actual named provider (specific school) + actual amount map to the **beneficiary** at Layer 2 (#49); the actual money transfer is Layer 3 (#4–#6). One Program service row → N beneficiaries → N named providers/payments.
- **Files touched**:
  - BE:
    - `Base.Domain/Models/CaseModels/ProgramService.cs` — replaced free-text props with structured FKs + cost + nav props (ServiceType/ProviderType/FundingFlow/Currency).
    - `Base.Infrastructure/.../CaseConfigurations/ProgramServiceConfiguration.cs` — 4 new FK configs (3× MasterData Restrict, Currency SetNull); `decimal(18,2)` on CostPerUnit.
    - `Base.Application/Schemas/CaseSchemas/ProgramSchemas.cs` — rebuilt `ProgramServiceDto` (FKs + response-only joined name/code fields).
    - `Base.Application/Mappings/CaseMappings.cs` — added `.Map()` joined-name projection for the 4 service FKs + `.Ignore()` of the new nav props on the reverse DTO→entity config.
    - `Programs/GetByIdQuery/GetProgramById.cs` — 4 `ThenInclude` for the new service navs.
    - `Programs/CreateCommand/CreateProgram.cs` + `UpdateCommand/UpdateProgram.cs` — service create/sync now maps all new fields.
    - `DatabaseScripts/Seed/seed_program_service_masterdata.sql` — **NEW**; 3 MasterData types (idempotent, UPPERCASE, ColorHex in DataSetting).
  - FE:
    - `program-services-table.tsx` — rewrote bare `<table>` → config **cards** (mirrors eligibility `CriterionCard`): header (name + Mandatory + remove), 3-col classification selects, dashed Cost-Basis block gated on FundingFlow ≠ INKIND, Notes textarea. Provider-type explainer line.
    - `program-form-schemas.ts` — new `serviceSchema` (FKs + form-only `fundingFlowCode` mirror for cost gating).
    - `gql-queries/case-queries/ProgramQuery.ts` — expanded `services` selection set.
    - `program-form-page.tsx` — `defaultValues.services` map + `handleSubmit` services payload (nulls cost when in-kind; drops form-only `fundingFlowCode`).
- **Latent bug fixed (adjacent)**: `CreateProgram` and `UpdateProgram.SyncEligibilityCriteria` were **dropping the eligibility verification fields** (`CriterionLabel`/`RequiresDocument`/`RequiredDocumentTypeId`/`VerificationMethodId`/`IsMandatory`/`Instructions`) on persist — they only mapped the original 3 rule fields, so the Session-(eligibility) verification config never saved on create/update. Both now map the full field set. Mirror this when touching child-collection sync.
- **Deviations from spec**: This is a Spec change (new fields/FKs + card UI). §④ data-model row, §⑥ Section 5 + Services widget spec, and §⑪ ProgramServiceDto all updated in this file to match.
- **Known issues opened/closed**: None (ISSUE-1…10 unchanged).
- **User manual steps (handed off)**: (1) `dotnet build` BE. (2) Create + apply an EF migration for the `case."ProgramServices"` restructure — DROP FrequencyText/ProviderText/CostPerUnitText; ADD ServiceTypeId/ProviderTypeId/FundingFlowId (nullable FK→sett.MasterDatas), CostPerUnit (numeric 18,2), UnitOfMeasure (varchar 50), CurrencyId (nullable FK→Currency SetNull). (NO IsMandatory/Instructions — trimmed.) (3) Run `seed_program_service_masterdata.sql`.
- **Verification**: FE `npx tsc --noEmit` clean on all touched program files. BE compile handed to user (per standing constraint). Runtime not smoke-tested — open the Program create form, add a service, pick a paid funding flow → cost block appears; pick In-Kind → it hides; save + reopen to confirm round-trip.
- **Next step**: Layer 2 (Beneficiary #49) — per-beneficiary service record holding the *named* provider + actual amount, linked back to the Program service; Layer 3 (#4–#6) the disbursement/payment.

### Session 17 — 2026-06-19 — UI/ENHANCE — COMPLETED (Phase 1 of 2)

- **Scope**: Made the **Funding Model** section model-aware and connected it to the funding tracking that already exists, instead of building new tracking on the program. Codebase mapping (Explore) confirmed the "who funds + how + tracking" the user asked for is **already implemented elsewhere** and only needs linking/surfacing — same Layer-1 discipline as Services (S16): the program holds the funding *policy + link*, not a funder ledger.
  - **Layering** (decided with user — *"you can decide"* on approach; *"Reuse Contact type"* on funder identity): **Layer 1 = Program** (`FundingModelId` INDIVIDUAL/POOL/GRANT/MIXED + sponsorship policy fields + `LinkedDonationPurposeId` bridge). **Layer 2 = actual funders/commitments** — `grant.Grants` (FunderContactId, AwardedAmount, links to program via `Grant.PurposeProgramId`), `fund.Pledges`(+PledgePayment), `fund.RecurringDonationSchedules`, `case.Beneficiaries.SponsorContactId` (per-child). **Layer 3 = money** — `fund.GlobalDonations`, `PledgePayments`, `PaymentTransactions`. Layers 2 & 3 **already exist** — adding a per-program funder sub-table was rejected as duplication.
  - **Funder identity = `Contact.ContactBaseTypeId`** (ORGANIZATION = a company, INDIVIDUAL = a single member) — the user's "company vs single member" distinction is already modelled on Contact; **no new funder-type field**.
- **Files touched**:
  - FE: `program-form.tsx` —
    - Section 5 renamed **"Sponsorship Model" → "Funding Model"** (it covers grant/pool/mixed too, not only sponsorship).
    - **Moved** `linkedDonationPurposeId` out of Section 7 (Staff & Budget) into the Funding section — it is the *bridge* that routes pledges/recurring/pooled donations to the program, not a budget field. Gated to INDIVIDUAL/POOL/MIXED (`showDonationPurpose`); hidden for pure GRANT (grants link the other way via `Grant.PurposeProgramId`). Staff & Budget budget row collapsed 3-col → 2-col.
    - Added `FUNDING_NOTES` per-model explainer line (info icon) stating, per model, WHO funds (Contact: Organization=company / Individual=single member), HOW (grant / pledge / recurring / pooled donation), and WHERE it's tracked (Grant module / Donations). Directly answers the user's "where does the tracking exist" without new schema.
- **Deviations from spec**: Funding section reframed (model-aware fields + relocated bridge). No new BE fields/columns — reuses existing `fundingModelId`/`sponsorship*`/`linkedDonationPurposeId`. §⑥ Section 5 spec should be updated to "Funding Model (model-aware)" on the next spec pass.
- **No BE / no migration this session** — pure FE reorganization of existing fields.
- **Known issues opened/closed**: None.
- **Verification**: JSX/logic-level only; manual smoke pending — open Program form, switch Funding Model: INDIVIDUAL/MIXED show sponsorship fields + donation-purpose + note; POOL shows donation-purpose + note; GRANT shows only the model + grant note (no sponsorship, no purpose).
- **Next step (Phase 2 — proposed, not yet built)**: surface the existing tracking **read-only** on the program view/edit — linked Grants (`grant.Grants WHERE PurposeProgramId`), Pledges/Recurring + funds received (via `LinkedDonationPurposeId` → `fund` donations). Needs a BE rollup query (NO schema change — reads existing `grant.*`/`fund.*`). This is the "see all the tracking on the program" piece.

### Session 18 — 2026-06-19 — ENHANCE (Spec change — user-authorized) — COMPLETED (pending user migration)

- **Scope**: Replaced the single `Program.LinkedDonationPurposeId` FK with a **many-to-many funding-source link table** so a program can be funded by MULTIPLE grants AND/OR MULTIPLE donation purposes. Outcome of a long design interrogation: the user concluded a grant (and a donation purpose) is a **general income source** — a program is just one of the things it can fund — so the relationship is genuinely M:N and the link belongs in a junction, not as an FK on either side. **Key finding that settled it:** `Grant.PurposeProgramId` is a FK to *MasterData* (a program-*category* label), **NOT** a link to a `case.Programs` row — so there was no real grant→program link at all; the junction is the only consistent way to link grants + multiple purposes, both pointing the same direction.
- **Design decision (committed, no amount split)**: junction is a **plain link** (no `AllocatedAmount`) — money totals still come from the existing `grant.*`/`fund.*` records via the Phase-2 rollup, consistent with the Layer-1 "link, don't re-track" discipline. The program keeps only its funding **policy** (FundingModelId, sponsorship policy, budget) + the funding-source links.
- **New table** `case.ProgramFundingSource`: `Id`, `ProgramId` (FK→Program, **Cascade**), `GrantId?` (FK→grant.Grants, **Restrict**), `DonationPurposeId?` (FK→fund.DonationPurposes, **Restrict**), `IsActive`. Exactly one of Grant/Purpose set per row (XOR validator in Create/Update). Joined display fields: `Grant.GrantTitle`, `DonationPurpose.DonationPurposeName`.
- **Files touched**:
  - BE (new): `Base.Domain/Models/CaseModels/ProgramFundingSource.cs`; `Base.Infrastructure/.../CaseConfigurations/ProgramFundingSourceConfiguration.cs`.
  - BE (edit): `Program.cs` (removed `LinkedDonationPurposeId`+nav, added `FundingSources` collection); `ProgramConfiguration.cs` (removed LinkedDonationPurpose FK); `ICaseDbContext.cs`/`CaseDbContext.cs` (DbSet); `ProgramSchemas.cs` (added `ProgramFundingSourceDto`, swapped fields on Request+Response DTOs); `CaseMappings.cs` (Ignore + projection + 2 child configs, null-guarded joins); `CreateProgram.cs` (materialize + XOR validator); `UpdateProgram.cs` (`Include` + `SyncFundingSources` full-replace + XOR validator); `GetProgramById.cs` (**removed dead `.Include(LinkedDonationPurpose)` — would not compile — and added `Include(FundingSources).ThenInclude(Grant/DonationPurpose)`** — agent had missed this query handler).
  - FE (new): `program-grant-picker.tsx`, `program-donation-purpose-picker.tsx` (chip multi-pickers mirroring `program-staff-picker.tsx`; grants via `GET_GRANTS_QUERY`, purposes via `DONATIONPURPOSES_QUERY`).
  - FE (edit): `program-form-schemas.ts` (drop `linkedDonationPurposeId`, add `fundingGrantIds`/`fundingDonationPurposeIds`); `program-form.tsx` (two gated pickers + name caches; grant picker GRANT/MIXED, purpose picker INDIVIDUAL/POOL/MIXED; updated FUNDING_NOTES); `program-form-page.tsx` (defaultValues split from `fundingSources`, preload chip names, handleSubmit rebuilds `fundingSources` array); `ProgramQuery.ts` (`fundingSources { id grantId grantTitle donationPurposeId donationPurposeName }`); `ProgramMutation.ts` (CREATE+UPDATE: `$fundingSources: [ProgramFundingSourceDtoInput!]`).
- **GraphQL contract**: input `ProgramFundingSourceDtoInput { grantId, donationPurposeId }` (keeps `Dto` suffix); output `fundingSources { id grantId grantTitle donationPurposeId donationPurposeName }`.
- **Deviations from spec**: This is a **Spec change** (new table + multi-select UI) normally routed to `/plan-screens`; user explicitly authorized planning + implementing in this session. §⑥ Section 5 + §④ data model need updating on the next spec pass (LinkedDonationPurposeId → ProgramFundingSource junction).
- **⚠️ USER ACTION — migration required (not done; user creates migrations)**: generate an EF migration that (1) creates `case.ProgramFundingSource`, (2) **backfills** existing `case.Programs.LinkedDonationPurposeId` values into `ProgramFundingSource (ProgramId, DonationPurposeId)` BEFORE (3) dropping the `LinkedDonationPurposeId` column. FE typecheck passed; BE not built (user builds). Demo seeds referencing `LinkedDonationPurposeId` (if any) will also need updating — same outstanding-seeds caveat as S16.
- **Known issues opened/closed**: None.
- **Next step**: user runs build + migration; then smoke-test (create/edit a MIXED program → add 2 grants + 2 purposes → save → reopen → chips rehydrate with names). Phase-2 read-only rollup now reads the junction instead of the single FK.

### Session 19 — 2026-06-22 — ENHANCE (Spec change — user-authorized) — COMPLETED (pending user migration)

- **Scope**: Added **per-source fund allocation + transaction-based audit** to the funding model (supersedes S18's "plain link, no AllocatedAmount"). Each funding source (grant/donation purpose) now commits an **allocation** (amount + cadence + period) to the program, and a new **ledger** records allocation/drawdown/adjustment events from which **Allocated / Used / Remaining / #txns** are rolled up. Program-level **annual need** is auto-computed and pre-fills Annual Budget.
- **Why S18's "no amount" was wrong for this requirement**: no money record carries program attribution today (`Grant.AwardedAmount` = whole grant; donations attach to a `DonationPurpose`, not a program; `Grant.PurposeProgramId` is a MasterData label). A pure rollup can't compute used-vs-remaining-for-this-program without stamping `ProgramId+SourceId` across the donation/grant modules — so we use an **explicit ledger** instead. Three numbers kept distinct: **Need** (computed) / **Allocation** (on the junction) / **Usage** (ledger).
- **ProgramType drives cadence**: ONGOING (no fixed close) ⇒ allocation must be recurring (MONTHLY/ANNUAL), ONETIME blocked (BE async validator + FE zod superRefine + cadence dropdown hides One-time); FIXEDTERM may use ONETIME. EndDate nullable (open-ended) for ongoing.
- **Schema added** (⚠️ needs migration — see below):
  - `case.ProgramFundingSource` gains: `AllocatedAmount numeric(18,2)?`, `CurrencyId int?` (FK→com.Currencies, Restrict), `AllocationFrequencyCode varchar(20)?`, `StartDate date?`, `EndDate date?`.
  - **New table** `case.ProgramFundingTransaction`: `Id` (identity), `FundingSourceId` (FK→ProgramFundingSource, **Cascade**), `TransactionType varchar(20)` (ALLOCATION/DRAWDOWN/ADJUSTMENT, plain code — no MasterData FK), `Amount numeric(18,2)`, `CurrencyId int?` (FK→com.Currencies, Restrict), `TransactionDate date?`, `LinkedDonationId int?`/`LinkedGrantExpenseId int?`/`LinkedPaymentTransactionId int?` (**no FK** — cross-module audit refs only), `Notes varchar(1000)?`, `IsActive`, + Entity base audit cols.
- **Files touched**:
  - BE (new): `Base.Domain/Models/CaseModels/ProgramFundingTransaction.cs`; `Base.Infrastructure/.../CaseConfigurations/ProgramFundingTransactionConfiguration.cs`.
  - BE (edit): `ProgramFundingSource.cs` (allocation fields + Currency + Transactions navs); `ProgramFundingSourceConfiguration.cs` (Currency FK + Transactions HasMany Cascade + column types); `ICaseDbContext.cs`/`CaseDbContext.cs` (`ProgramFundingTransactions` DbSet); `ProgramSchemas.cs` (expanded `ProgramFundingSourceDto` w/ allocation+rollups+transactions, new `ProgramFundingTransactionDto`, `ComputedAnnualNeed` on Response); `CaseMappings.cs` (currencyCode + transactions projection + 2 txn child configs); `CreateProgram.cs` (materialize allocation+nested txns; ONGOING-cadence + txn-validity validators); `UpdateProgram.cs` (`ThenInclude(Transactions)`; **`SyncFundingSources` now DIFF-PERSIST not full-replace** so each source row keeps its identity + ledger; new `SyncFundingTransactions`; same validators); `GetProgramById.cs` (Currency+Transactions includes; per-source rollups Allocated=ΣALLOCATION+ADJUSTMENT-or-AllocatedAmount-fallback / Used=ΣDRAWDOWN / Remaining / count; `ComputeAnnualNeed` + `FrequencyToAnnualMultiplier`).
  - FE (new): `program-funding-sources.tsx` (useFieldArray rows; pickers reused as pure adders w/ `selectedGrants={[]}` so no chips; per-row allocation grid + rollup strip + collapsible nested-field-array ledger; cadence dropdown gated by ONGOING).
  - FE (edit): `program-form-schemas.ts` (replaced `fundingGrantIds`/`fundingDonationPurposeIds` with `fundingSources` array-of-objects incl `transactions`; XOR + ONGOING-cadence superRefine); `program-form.tsx` (removed chip pickers + name caches + dead watchers; renders `<ProgramFundingSources>`; `computedAnnualNeed` prop + "Apply" prefill on Annual Budget); `program-form-page.tsx` (defaultValues map full source rows incl txns + ids; handleSubmit sends rows with id + strips response-only fields; passes `computedAnnualNeed`); `ProgramQuery.ts` (expanded `fundingSources` selection + `transactions {…}` + `computedAnnualNeed`). `ProgramMutation.ts` UNCHANGED (variable type `[ProgramFundingSourceDtoInput!]` already covers the richer nested input).
- **GraphQL contract**: input `ProgramFundingSourceDtoInput { id, grantId, donationPurposeId, allocatedAmount, currencyId, allocationFrequencyCode, startDate, endDate, transactions: [ProgramFundingTransactionDtoInput!] }`; `ProgramFundingTransactionDtoInput { id, transactionType, amount, currencyId, transactionDate, linkedDonationId, linkedGrantExpenseId, linkedPaymentTransactionId, notes }`. Response adds allocation fields + `currencyCode`, rollups `totalAllocated/totalUsed/remainingAmount/transactionCount`, nested `transactions`, and program-level `computedAnnualNeed`. Send-side must NOT include response-only display fields (grantTitle/donationPurposeName/currencyCode/rollups) — HC rejects unknown inputs.
- **Deviations from spec**: Spec change (new ledger table + allocation cols + need-calc) normally routed to `/plan-screens`; user explicitly authorized implementing this session. §⑥ Section 5 + §④ data model need a spec pass.
- **⚠️ USER ACTION — migration required (not done; user creates migrations)**: this STACKS ON TOP of S18's un-applied migration (S18's `update-database` died on a design-time `OutOfMemoryException`, not a schema error — retry from a fresh PMC / CLI). The migration must (1) ADD the 5 allocation columns to `case.ProgramFundingSource`, and (2) CREATE `case.ProgramFundingTransaction` (cols above; FK FundingSourceId Cascade, CurrencyId Restrict; LinkedXxxId columns have NO FK). No data backfill needed for S19. FE typecheck passed clean; BE not built (user builds).
- **Known issues opened/closed**: None.
- **Next step**: user runs build + migration; smoke-test: create a MIXED/ONGOING program → add a grant + a purpose → set allocation amount/cadence (confirm One-time is hidden for ongoing) → add an ALLOCATION + DRAWDOWN ledger row → save → reopen → rows rehydrate, rollups show Allocated/Used/Remaining, `computedAnnualNeed` "Apply" fills Annual Budget. Diff-persist check: edit an existing source's amount → its ledger rows survive (not wiped).

#### Session 19 addendum (same day) — DESIGN PIVOT: allocation → separate screen (user decision)

User decided (post-build): **the program create/edit form should link funding sources ONLY**; allocation amounts + cadence + period + the audit ledger move to a **separate, post-creation "Program Fund Allocation" screen** (create defines *what funds it*; operate defines *how much*, gated on the program existing/ACTIVE). The S19 BE schema (allocation cols + `ProgramFundingTransaction` ledger + rollups) is **reused as-is** by that screen — no BE schema rework.
- **Program form is now links-only** (in-scope changes applied this session):
  - FE: `program-funding-sources.tsx` gained a `linksOnly` prop (renders source **chips** + adders, hides allocation grid/ledger/rollups); `program-form.tsx` passes `linksOnly`; `program-form-page.tsx` `handleSubmit` sends `fundingSources` as `{ id, grantId, donationPurposeId }` only. `computedAnnualNeed` "Apply" on Annual Budget **stays** (it's a budget hint, not allocation). FE tsc clean.
  - BE: `CreateProgram` materializes **links only** (allocation null); `UpdateProgram.SyncFundingSources` rewritten to **add/remove links and LEAVE existing rows untouched** (so a program-form save can never wipe an allocation/ledger set by the allocation screen) — removed `SyncFundingTransactions` + the `ThenInclude(Transactions)` include. The ONGOING-cadence + txn-validity validators remain but are inert for the form (no cadence/txns sent) — they'll be reused by the allocation screen's command.
- **NOT built — new screen**: "Program Fund Allocation" (own route/menu, lifecycle-gated, reuses the full `ProgramFundingSources` card UI + new per-source allocation/ledger BE commands). → Goes through **`/plan-screens`** as a NEW screen (entry point TBD: program-grid row action vs program detail tab).

#### Session 19 addendum 2 (same day) — EXPECTED amount back on the form (user decision)

User refined the pivot: pure links-only left management with no view of *how much* each source should provide. So the form is now **link + EXPECTED annual amount** (the planning target), while the separate Fund Allocation screen still owns the **actual** allocation (AllocatedAmount/cadence/dates) + the ledger. Four distinct numbers now: **Need** (computed) → **Expected/source** (form) → **Allocated/source** (alloc screen) → **Used** (ledger).
- BE: `ProgramFundingSource` +`ExpectedAnnualAmount` (numeric(18,2); config + DTO + entity). `CreateProgram` persists `ExpectedAnnualAmount`+`CurrencyId` on each link. `UpdateProgram.SyncFundingSources` now **updates ONLY ExpectedAnnualAmount+CurrencyId on existing rows** (allocation/cadence/dates/ledger still NEVER touched → alloc screen's data stays safe); new links carry their expected target. Mapster auto-maps `ExpectedAnnualAmount` (name match).
- FE: `program-form-schemas.ts` fundingSourceSchema +`expectedAnnualAmount`. `program-funding-sources.tsx` `linksOnly` branch reworked: chips → **rows** (source label + Expected/year input + currency picker + remove) plus a **Need vs Expected total** strip (Fully covered / Short X / Over X). `needTarget` prop = `computedAnnualNeed`. `program-form.tsx` passes `needTarget`; `program-form-page.tsx` defaultValues map `expectedAnnualAmount`, handleSubmit sends `{ id, grantId, donationPurposeId, expectedAnnualAmount, currencyId }`. `ProgramQuery.ts` +`expectedAnnualAmount`. `ProgramMutation.ts` UNCHANGED (`[ProgramFundingSourceDtoInput!]` covers it). FE tsc clean.
- **Migration (user-owned)**: stacks on S18/S19 — adds 1 nullable col `ExpectedAnnualAmount numeric(18,2)` to `case."ProgramFundingSource"`. No backfill.

### Session 20 — 2026-06-22 — ENHANCE (Spec change — user-authorized) — COMPLETED (pending user migration)

- **Scope**: Restructure **Outcome Metrics** from free-text → structured M&E tracking fields, mirroring how eligibility-criteria / services / funding were professionalised (user: "outcomes how to check, with document required or not, that kind of information").
- **Model**: `case."ProgramOutcomeMetrics"` drops `TargetText`/`MeasurementText`/`FrequencyText`; adds `IndicatorTypeId` (OUTCOMEINDICATORTYPE: Output/Outcome/Impact), structured target `BaselineValue`+`TargetOperatorCode`(>=/<=/=/>/<)+`TargetValue`+`UnitOfMeasure`, `MeasurementMethodId` (OUTCOMEMEASUREMENTMETHOD), `MeasurementFrequencyId` (OUTCOMEMEASUREMENTFREQUENCY), evidence config `RequiresEvidence`+`EvidenceDocumentTypeId` (OUTCOMEEVIDENCEDOCUMENTTYPE; mirrors eligibility's RequiresDocument), `Instructions`.
- **Files touched**:
  - BE: `ProgramOutcomeMetric.cs` (entity + 4 MasterData navs), `ProgramOutcomeMetricConfiguration.cs` (props + 4 Restrict FKs), `ProgramSchemas.cs` (`ProgramOutcomeMetricDto` + joined response-only Name/Code), `CaseMappings.cs` (join names + ignore navs), `CreateProgram.cs` + `UpdateProgram.cs` `SyncOutcomeMetrics` (map full set; EvidenceDocumentTypeId gated on RequiresEvidence), `GetProgramById.cs` (4 ThenIncludes). New seed `DatabaseScripts/Seed/seed_outcome_metric_masterdata.sql` (4 types).
  - FE: `program-outcome-metrics-table.tsx` (free-text table → **MetricCard** mirroring eligibility CriterionCard), `program-form-schemas.ts` (`metricSchema` structured + superRefine requiresEvidence⇒evidenceDocumentTypeId), `program-form-page.tsx` (defaultValues + submit maps), `ProgramQuery.ts` (outcomeMetrics selection). `ProgramMutation.ts` UNCHANGED (`[ProgramOutcomeMetricDtoInput!]` auto-covers).
- **Deviations from spec**: None (extends the established Layer-1 restructure pattern).
- **Verify**: FE `npx tsc --noEmit` clean. BE not built (user builds).
- **Migration (user-owned)**: drop 3 text cols + add 4 nullable FK cols on `case."ProgramOutcomeMetrics"`. No backfill. Then run `seed_outcome_metric_masterdata.sql`. Demo seeds inserting old outcome cols will break (same class as the S16 list).
- **Next step**: none — user owns migration + BE build.
