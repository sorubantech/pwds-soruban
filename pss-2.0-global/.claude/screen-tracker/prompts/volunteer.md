---
screen: Volunteer
registry_id: 53
module: Volunteer (CRM)
status: PROMPT_READY
scope: FULL
screen_type: FLOW
complexity: High
new_module: YES — `vol` schema (IVolDbContext, VolDbContext, VolMappings, DecoratorVolModules)
planned_date: 2026-04-21
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`volunteer/volunteer-list.html` + `volunteer/volunteer-form.html` + `volunteer/volunteer-detail.html`)
- [x] Existing code reviewed (FE: two 4-line stubs at `volunteerlist/page.tsx` and `registervolunteer/page.tsx`; BE: no Volunteer entity, no `vol` schema infra)
- [x] Business rules + workflow extracted (5-state status w/ Pending→Active approval path; contact-link-or-create radio mode; computed totals from downstream not-yet-built entities)
- [x] FK targets resolved (Contact, Staff, Branch, Country + 7 MasterData typeCodes; all already in backend)
- [x] File manifest computed (new-schema bootstrap + 6 entities + migration + seed + 20 BE files + ~22 FE files)
- [x] Approval config pre-filled (VOLUNTEERLIST menu under CRM_VOLUNTEER at OrderBy=1; legacy VOLUNTEERFORM menu hidden)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM 6-section accordion + 5-tab DETAIL + 4 KPI widgets specified)
- [ ] User Approval received
- [ ] **NEW MODULE bootstrap** — `vol` schema: `IVolDbContext`, `VolDbContext`, `VolMappings`, `DecoratorVolModules` created and wired (IApplicationDbContext inheritance, DependencyInjection × 2, GlobalUsing × 3, AddDbContext registration)
- [ ] Backend code generated (Volunteer parent + 5 child entities + 4 workflow commands + Summary query + migration)
- [ ] Backend wiring complete (DbSets, Mappings, Decorator, MasterData seeds)
- [ ] Frontend code generated (view-page 3 modes + Zustand store + 4 KPI widgets + 5-tab DETAIL + 6-section FORM with contact-link toggle)
- [ ] Frontend wiring complete (entity-operations, component-columns × 3 registries, shared-cell-renderers barrel, sidebar, route stub overwrite)
- [ ] DB Seed script generated (menu + Grid FLOW + 10 GridFields; GridFormSchema SKIP; 7 MasterDataType seeds + hide VOLUNTEERFORM menu)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (new Volunteer + 5 children + `vol` schema registered in EF design snapshot)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/volunteer/volunteerlist`
- [ ] 4 KPI widgets render: Total Volunteers (w/ Active/Inactive/Pending breakdown) / Hours This Month (w/ %-change placeholder) / Upcoming Shifts (placeholder until #54) / Skill Coverage (distinct skills + top skill)
- [ ] Grid loads with 10 columns (checkbox + Volunteer w/ avatar+email + Contact link + Skills tags + Availability + Total Hours + Month Hours + Last Active + Status badge + Actions)
- [ ] 5 filter chips work (All/Active/Inactive/Pending Approval/On Leave) — top-level GQL args
- [ ] Advanced filter panel: Skills (multi), AvailabilityType, Branch, HoursLogged range
- [ ] Bulk actions toolbar appears on row selection (Assign to Shift PLACEHOLDER / Send Message PLACEHOLDER / Activate / Deactivate)
- [ ] Pending rows show "Approve" quick action (fires ApproveVolunteer mutation → Status→Active)
- [ ] `?mode=new` — empty 6-section accordion FORM renders: Contact Link (radio: Search existing / Create new) → Personal Info → Skills & Interests (multi-tag chips + Languages/Certs tag-inputs) → Availability (type/time/days-of-week chips + Max Hours + Start Date + Blackout Dates child grid) → Emergency Contact → Additional
- [ ] Contact-link mode toggle: "Search existing" shows typeahead → picks ContactId; "Create new" hides search and form auto-creates a Contact on Save
- [ ] Skills multi-select: "Other" chip toggles OtherSkills text field
- [ ] Languages + Certifications tag-input widgets add/remove rows as chips
- [ ] Available Days chip grid (Mon-Sun) persists 7 bool columns
- [ ] Blackout Dates child-grid add/remove rows (at least 1 row persists)
- [ ] Save creates Volunteer + nested children in ONE transaction → redirect to `?mode=read&id={newId}`
- [ ] `?mode=edit&id=X` — FORM pre-filled; edits persist via diff-children pattern (insert new / update existing / delete removed)
- [ ] `?mode=read&id=X` — DETAIL layout renders (header w/ avatar+name+status badge+contact link, 5-stat Quick Stats row, 5 Tabs)
- [ ] Tab 1 Overview: 2-col grid w/ 4 cards (Personal Info / Availability w/ day-chip grid + blackouts / Skills&Interests w/ tags / Notes)
- [ ] Tab 2 Schedule: table (SERVICE_PLACEHOLDER until VolunteerSchedule #54; shows empty state w/ "Assign Shift" CTA)
- [ ] Tab 3 Hours Log: table (SERVICE_PLACEHOLDER until HourTracking #55; shows empty state w/ "Log Hours" CTA)
- [ ] Tab 4 Donations: summary banner + recent donations table (buildable — joins GlobalDonation via ContactId)
- [ ] Tab 5 Recognition: badges + certificates + manager comments (SERVICE_PLACEHOLDER — gamification layer not defined)
- [ ] Header actions (Edit → ?mode=edit / Log Hours deep-link to #55 / Assign Shift deep-link to #54 / Send Message PLACEHOLDER / More: Print/Export/Deactivate/Remove)
- [ ] Workflow: Approve (Pending→Active) / Deactivate (Active→Inactive) / Set On Leave (Active→OnLeave) / Reactivate (Inactive|OnLeave→Active) mutations all work
- [ ] FK dropdowns load: Contact (typeahead), Branch (ApiSelectV2), Country (ApiSelectV2), Gender (MasterData GENDER typeCode)
- [ ] Unsaved changes dialog triggers on dirty FORM navigation
- [ ] DB Seed — VOLUNTEERLIST menu visible at OrderBy=1 under CRM_VOLUNTEER; VOLUNTEERFORM legacy menu hidden (IsMenuRender=0); 7 MasterDataTypes populated

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Volunteer
Module: Volunteer (CRM)
Schema: `vol` (**NEW — first entity in this schema**)
Group: `Vol` (Models=`VolModels`, Configs=`VolConfigurations`, Schemas=`VolSchemas`, Business=`VolBusiness`, Endpoints=`Vol`)

Business:
The Volunteer screen is the heart of the NGO's volunteer-management workflow — the roster of every registered helper along with their skills, availability, approval status, and contribution history. Operations and volunteer-coordination staff use it daily to (a) register new volunteers (often linking to an existing Contact record if they are already in the CRM as a donor or lead), (b) approve pending signups after background/interview steps, (c) search for volunteers with specific skill + language + availability combos when staffing events and campaigns, (d) track per-volunteer impact (hours, shifts, donations-also-given), and (e) recognize top contributors. This screen is the parent master for Wave-3 Volunteer Schedule (#54) and Hour Tracking (#55) — both depend on `VolunteerId` as their primary FK. The DETAIL view is a **full-page, 5-tab profile** (NOT a drawer) covering Overview, Schedule, Hours Log, Donations (volunteers who are also donors — common at this NGO), and Recognition (badges, certificates, manager comments). Many of the quantitative stats on both the DETAIL and the KPI widgets (total hours, shifts completed, upcoming shifts, rank) depend on downstream not-yet-built entities and therefore ship as `SERVICE_PLACEHOLDER` computed fields returning `0` / empty until Wave-3 lands.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> 6 entities total (1 parent + 5 child 1:M). Audit columns inherited from `Entity` base. `CompanyId` resolved from HttpContext on Create/Update (never sent by FE).

### Parent Table: `vol."Volunteers"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| VolunteerId | int | — | PK | — | Primary key |
| VolunteerCode | string | 50 | YES | — | Auto-gen `VOL-{0001}` (4-digit padded, per-Company sequence) on Create when empty; unique-filtered per Company |
| CompanyId | int | — | YES | app.Companies | Tenant scope (from HttpContext — NOT in RequestDto) |
| ContactId | int? | — | NO | cont.Contacts | NULL when volunteer is brand-new and not yet a Contact; BE auto-creates a Contact in "Create new contact" mode (see ④ Business Logic) |
| FirstName | string | 100 | YES | — | Mirrored from Contact when linked, editable standalone when no link |
| LastName | string | 100 | YES | — | Same |
| Email | string | 200 | YES | — | Unique per Company; format validated |
| DialCode | string | 5 | YES | — | e.g., `+971` — default from Company |
| PhoneNumber | string | 20 | YES | — | Unique-soft per Company (warn, don't block) |
| DateOfBirth | DateOnly? | — | NO | — | — |
| GenderId | int? | — | NO | sett.MasterDatas (TypeCode `GENDER`) | Existing MasterData — reuse seed |
| Address | string | 300 | NO | — | Street address |
| City | string | 100 | YES | — | Required per mockup |
| CountryId | int | — | YES | shared.Countries | Required per mockup |
| ProfilePhotoUrl | string | 500 | NO | — | SERVICE_PLACEHOLDER — plain text URL field in MVP (no upload infra yet). See ISSUE-3. |
| AvailabilityTypeId | int? | — | NO | sett.MasterDatas (TypeCode `VOLUNTEERAVAILABILITYTYPE`) | Part-time / Full-time / Occasional / Events Only |
| PreferredTimeId | int? | — | NO | sett.MasterDatas (TypeCode `VOLUNTEERPREFERREDTIME`) | Morning / Afternoon / Evening / Flexible |
| IsAvailableMonday | bool | — | YES | — | Default false |
| IsAvailableTuesday | bool | — | YES | — | Default false |
| IsAvailableWednesday | bool | — | YES | — | Default false |
| IsAvailableThursday | bool | — | YES | — | Default false |
| IsAvailableFriday | bool | — | YES | — | Default false |
| IsAvailableSaturday | bool | — | YES | — | Default false |
| IsAvailableSunday | bool | — | YES | — | Default false |
| MaxHoursPerWeek | int? | — | NO | — | 1–60 range; default 12 |
| StartDate | DateOnly? | — | NO | — | When they begin volunteering with the org |
| EmergencyContactName | string | 150 | YES | — | Required per mockup |
| EmergencyContactRelationId | int? | — | NO | sett.MasterDatas (TypeCode `VOLUNTEEREMERGENCYRELATION`) | Spouse / Parent / Sibling / Child / Friend / Other |
| EmergencyContactDialCode | string | 5 | YES | — | — |
| EmergencyContactPhone | string | 20 | YES | — | — |
| HeardAboutSourceId | int? | — | NO | sett.MasterDatas (TypeCode `VOLUNTEERHEARDABOUTSOURCE`) | Social Media / Friend-Family / Event / Website / Other |
| BranchId | int? | — | NO | app.Branches | Branch Assignment |
| PreviousExperience | string | 2000 | NO | — | Free text |
| Motivation | string | 2000 | NO | — | Free text — "why do you volunteer?" |
| InternalNotes | string | 2000 | NO | — | Staff-only |
| AgreedToCodeOfConduct | bool | — | YES | — | Default false; must be true on Save |
| OtherSkills | string | 300 | NO | — | Free-text appended when "Other" skill chip selected |
| VolunteerStatusId | int | — | YES | sett.MasterDatas (TypeCode `VOLUNTEERSTATUS`) | Pending (default on Create) / Active / Inactive / OnLeave |
| JoinedDate | DateTime | — | YES | — | Auto-set on first transition to Active (first Approve). Null until approved. Rename: `ActivatedDate` if clearer — BUILD uses `JoinedDate` for display but column is `ActivatedDate` |
| LastActiveDate | DateTime? | — | NO | — | MAX of VolunteerHourLog.LoggedAt — SERVICE_PLACEHOLDER (set to Entity.ModifiedDate fallback until #55 built). See ISSUE-6. |
| DeactivatedDate | DateTime? | — | NO | — | Set on Deactivate mutation |
| DeactivatedReason | string | 500 | NO | — | Free text on Deactivate (optional) |
| OnLeaveFromDate | DateOnly? | — | NO | — | Set on SetOnLeave mutation |
| OnLeaveToDate | DateOnly? | — | NO | — | — |

### Child Tables (5 × 1:M under `vol` schema)

| Child Entity | Relationship | Table | Key Fields |
|--------------|--------------|-------|------------|
| **VolunteerSkill** | 1:Many via VolunteerId (CASCADE) | `vol."VolunteerSkills"` | Id, VolunteerId, SkillMasterDataId (FK sett.MasterDatas typeCode `VOLUNTEERSKILL`), OrderBy; unique composite (VolunteerId, SkillMasterDataId) |
| **VolunteerInterest** | 1:Many via VolunteerId (CASCADE) | `vol."VolunteerInterests"` | Id, VolunteerId, InterestMasterDataId (FK sett.MasterDatas typeCode `VOLUNTEERINTEREST`), OrderBy; unique composite (VolunteerId, InterestMasterDataId) |
| **VolunteerLanguage** | 1:Many via VolunteerId (CASCADE) | `vol."VolunteerLanguages"` | Id, VolunteerId, LanguageName (string 100), ProficiencyCode (string 20 nullable — `native`/`fluent`/`intermediate`/`basic`), OrderBy |
| **VolunteerCertification** | 1:Many via VolunteerId (CASCADE) | `vol."VolunteerCertifications"` | Id, VolunteerId, CertificationName (string 200), ValidUntilDate (DateOnly?), OrderBy |
| **VolunteerBlackout** | 1:Many via VolunteerId (CASCADE) | `vol."VolunteerBlackouts"` | Id, VolunteerId, FromDate (DateOnly), ToDate (DateOnly), Reason (string 200 nullable); must satisfy FromDate ≤ ToDate |

### Computed / projected fields on `VolunteerResponseDto` (NOT stored)

| Field | Computation | Buildable Now? |
|-------|-------------|----------------|
| fullName | `FirstName + ' ' + LastName` | ✅ YES |
| avatarInitials | first char of First + first char of Last | ✅ YES |
| avatarColor | stable hash → hex from a fixed palette (`Contact #18` donorAvatarColor precedent) | ✅ YES |
| contactName / contactCode / contactEmail / contactPhone | Contact join when ContactId not null | ✅ YES |
| contactDisplayName | `contactName` when linked, else "-- (New)" | ✅ YES |
| genderName / availabilityTypeName / preferredTimeName / emergencyContactRelationName / heardAboutSourceName | MasterData nav joins | ✅ YES |
| volunteerStatusCode / volunteerStatusName / volunteerStatusColorHex | MasterData (VOLUNTEERSTATUS) joins | ✅ YES |
| branchName | Branch join | ✅ YES |
| countryName | Country join | ✅ YES |
| skills[] | projected child collection → `{skillMasterDataId, dataName, dataValue, colorHex}` | ✅ YES |
| interests[] | projected child collection → `{interestMasterDataId, dataName}` | ✅ YES |
| languages[] | projected child collection → `{id, languageName, proficiencyCode}` | ✅ YES |
| certifications[] | projected child collection → `{id, certificationName, validUntilDate}` | ✅ YES |
| blackoutDates[] | projected child collection → `{id, fromDate, toDate, reason}` | ✅ YES |
| availableDaysDisplay | Array of day codes derived from 7 bool cols | ✅ YES |
| totalHours | SUM VolunteerHourLog.Hours — **SERVICE_PLACEHOLDER** return 0 until #55 built. See ISSUE-4. | ❌ |
| hoursThisMonth | SUM filtered by current month — **SERVICE_PLACEHOLDER** 0. See ISSUE-4. | ❌ |
| shiftsCompleted | COUNT VolunteerSchedule WHERE Status=Completed — **SERVICE_PLACEHOLDER** 0 until #54 built. See ISSUE-5. | ❌ |
| upcomingShiftsCount | COUNT VolunteerSchedule WHERE ScheduledDate > today — **SERVICE_PLACEHOLDER** 0. See ISSUE-5. | ❌ |
| eventsCount | DISTINCT Event across VolunteerSchedule — **SERVICE_PLACEHOLDER** 0. See ISSUE-5. | ❌ |
| donationsTotal | SUM GlobalDonation.DonationAmount WHERE ContactId=Volunteer.ContactId (buildable when ContactId not null) | ✅ YES (partial — NULL when ContactId is null) |
| donationsCount | COUNT same scope | ✅ YES (partial) |
| isAlsoDonor | `donationsTotal > 0` | ✅ YES |
| rankByHours | DENSE_RANK over totalHours — **SERVICE_PLACEHOLDER** null until #55 built. See ISSUE-4. | ❌ |
| badgesEarned[] | Gamification layer — **SERVICE_PLACEHOLDER** empty array. See ISSUE-7. | ❌ |
| certificatesIssued[] | Certificate-issuance platform — **SERVICE_PLACEHOLDER** empty array. See ISSUE-8. | ❌ |
| managerComments[] | Free-form comments — **SERVICE_PLACEHOLDER** empty array (new subject — not in scope for MVP). See ISSUE-9. | ❌ |

### Indexes

- `Volunteers`: `(CompanyId, VolunteerStatusId)`, `(CompanyId, ContactId)`, `(CompanyId, Email)` unique-filtered WHERE IsActive=1; `(CompanyId, VolunteerCode)` unique-filtered
- `VolunteerSkills`: `(VolunteerId, SkillMasterDataId)` unique
- `VolunteerInterests`: `(VolunteerId, InterestMasterDataId)` unique
- `VolunteerBlackouts`: `(VolunteerId, FromDate)`

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and nav properties) + Frontend Developer (for ApiSelectV2 queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId | Contact | `PSS_2.0_Backend/.../Base.Domain/Models/ContactModels/Contact.cs` | `getContacts` | `displayName` (+`contactCode`, `email`, `phoneNumber`) | `ContactResponseDto` |
| CountryId | Country | `PSS_2.0_Backend/.../Base.Domain/Models/SharedModels/Country.cs` | `getCountries` | `countryName` | `CountryResponseDto` |
| BranchId | Branch | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Branch.cs` | `getBranches` | `branchName` | `BranchResponseDto` |
| GenderId | MasterData (TypeCode=`GENDER`) | `PSS_2.0_Backend/.../Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (with `masterDataTypeCode` filter) | `dataName` | `MasterDataResponseDto` |
| AvailabilityTypeId | MasterData (TypeCode=`VOLUNTEERAVAILABILITYTYPE`) | same as above | `getMasterDatas` | `dataName` | `MasterDataResponseDto` |
| PreferredTimeId | MasterData (TypeCode=`VOLUNTEERPREFERREDTIME`) | same | `getMasterDatas` | `dataName` | `MasterDataResponseDto` |
| EmergencyContactRelationId | MasterData (TypeCode=`VOLUNTEEREMERGENCYRELATION`) | same | `getMasterDatas` | `dataName` | `MasterDataResponseDto` |
| HeardAboutSourceId | MasterData (TypeCode=`VOLUNTEERHEARDABOUTSOURCE`) | same | `getMasterDatas` | `dataName` | `MasterDataResponseDto` |
| VolunteerStatusId | MasterData (TypeCode=`VOLUNTEERSTATUS`) | same | `getMasterDatas` | `dataName` (+`dataValue`, `colorHex`) | `MasterDataResponseDto` |
| VolunteerSkill.SkillMasterDataId | MasterData (TypeCode=`VOLUNTEERSKILL`) | same | `getMasterDatas` | `dataName` | `MasterDataResponseDto` |
| VolunteerInterest.InterestMasterDataId | MasterData (TypeCode=`VOLUNTEERINTEREST`) | same | `getMasterDatas` | `dataName` | `MasterDataResponseDto` |
| CompanyId | Company | via HttpContext / tenant resolver | — | — | — |

**MasterData filter convention**: `getMasterDatas` accepts a `masterDataTypeCode` filter arg — see Program #51 + SavedFilter #27 usage. FE `ApiSelectV2` passes this as part of the query variables.

**GlobalDonation cross-join for donation stats**: BE projects `donationsTotal` + `donationsCount` from `DonationModels.GlobalDonations` via `.Where(gd => gd.ContactId == v.ContactId && gd.IsActive && gd.PaymentStatusCode == "COMPLETED")`. This is a read-only projection — do NOT add a nav property that EF would cascade.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `VolunteerCode` unique per Company (ValidateUniqueWhenCreate + ValidateUniqueWhenUpdate). Soft-delete rows do NOT block re-use.
- `Email` unique per Company (unique-filtered WHERE IsActive=1). Enforce case-insensitive compare.
- `ContactId` unique per Company (soft — warn don't block: "This contact is already registered as a volunteer"). Confirm with BA during approval; for now BE emits a warning-log but does not block.
- `VolunteerSkill(VolunteerId, SkillMasterDataId)` composite unique — one skill cannot appear twice on same volunteer.
- `VolunteerInterest(VolunteerId, InterestMasterDataId)` composite unique.

**Required Field Rules:**
- Mandatory on Create: `FirstName`, `LastName`, `Email`, `DialCode`, `PhoneNumber`, `City`, `CountryId`, `EmergencyContactName`, `EmergencyContactDialCode`, `EmergencyContactPhone`, `AgreedToCodeOfConduct=true`.
- At least 1 Skill (VolunteerSkill row) must exist — mockup marks Skills with `*`.
- `VolunteerStatusId` defaults to MasterData row with `DataValue='PEN'` (Pending) on Create if not supplied.

**Conditional Rules:**
- **Contact-Link mode** (radio in Section 1 of form — NOT a stored field, just a FE mode):
  - **Search existing** mode → user picks `ContactId`; BE copies Contact's `FirstName`/`LastName`/`Email`/`PhoneNumber` into Volunteer on Create. On Update, Volunteer fields can diverge (the volunteer might update contact info without touching the Contact).
  - **Create new** mode → `ContactId` is NULL in RequestDto; BE **auto-creates a Contact** record during Create handler with `FirstName`/`LastName`/`Email`/`PhoneNumber` from the Volunteer form, then stamps the resulting `ContactId` back on the Volunteer. See ISSUE-1 for the Contact-creation handshake (tenant scope, contact-type defaulting).
- If `Other` skill chip is selected (via a special MasterData row with `DataValue='OTH'` in `VOLUNTEERSKILL` typeCode) → `OtherSkills` text field becomes required.
- `IsAvailable*` booleans (Mon-Sun): at least ONE day should be selected — soft-warning on FE, not enforced on BE.
- `MaxHoursPerWeek` in range 1..60 when not null.
- `Blackout.FromDate ≤ Blackout.ToDate` (BE validation per child row).
- `OnLeaveFromDate ≤ OnLeaveToDate` when both set (SetOnLeave command).
- `CertificationName` is required per child row; `ValidUntilDate` optional.

**Business Logic:**
- **Auto-generate `VolunteerCode`** if FE sends empty: pattern `VOL-{NNNN}` (4-digit padded, per-Company sequence). Concurrency-safe via row-lock over the Volunteer sequence MAX.
- **Child collection diff-persist**: Create/Update Volunteer accepts inline arrays for `skills[]`, `interests[]`, `languages[]`, `certifications[]`, `blackoutDates[]`. BE handler diffs against DB state → INSERT new (Id=0) / UPDATE existing (by Id) / DELETE removed rows — all inside one transaction. Same pattern as Family #20 `setFamilyMembers` and Program #51 child collections.
- **Cascade on hard-delete**: Hard-delete Volunteer cascades all 5 child tables. Soft-delete (Toggle → IsActive=false) does NOT cascade — children remain and become readable again if Volunteer is toggled back. **Restrict hard-delete** if there's any VolunteerHourLog or VolunteerSchedule referencing this VolunteerId — but those entities don't exist yet, so MVP allows unconditional hard-delete. See ISSUE-10.
- **`JoinedDate` auto-set** on first Pending→Active transition via `ApproveVolunteer` command (not at Create). Remains null for volunteers still Pending.
- **`LastActiveDate`** fallback to `Entity.ModifiedDate` until #55 lands — BE projection returns whichever is more recent of (ModifiedDate, downstream-MAX-hour-log) — the downstream part is 0 for MVP. See ISSUE-6.

**Workflow** (5-state — note that `Active` can come from both Pending→Active AND Inactive/OnLeave→Active via ReactivateVolunteer):

```
 Pending ──[Approve]──► Active
                        │ │ │
                        │ │ └─[Deactivate]──► Inactive ──[Reactivate]──► Active
                        │ └───[SetOnLeave]──► OnLeave  ──[Reactivate]──► Active
                        └─────[Deactivate]──► Inactive
```

**Workflow commands (4 total, separate from standard CRUD):**
1. `ApproveVolunteer(volunteerId)` — guard: current status = `PEN`. Side effects: set `VolunteerStatusId` to `ACT`, set `JoinedDate = now()` if null, clear `DeactivatedDate` / `DeactivatedReason` / `OnLeaveFromDate` / `OnLeaveToDate`.
2. `DeactivateVolunteer(volunteerId, reason)` — guard: current status = `ACT` or `LEV`. Side effects: set status to `INA`, set `DeactivatedDate = now()`, set `DeactivatedReason = reason`.
3. `SetOnLeaveVolunteer(volunteerId, fromDate, toDate)` — guard: current status = `ACT`. Side effects: set status to `LEV`, set `OnLeaveFromDate` / `OnLeaveToDate`.
4. `ReactivateVolunteer(volunteerId)` — guard: current status ∈ {`INA`, `LEV`}. Side effects: set status to `ACT`, clear `DeactivatedDate` / `DeactivatedReason` / `OnLeaveFromDate` / `OnLeaveToDate`.

All 4 workflow commands follow the same pattern as ChequeDonation #6 transitions (Deposit/Clear/Bounce).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: **Transactional workflow screen with full-page view-page, 6-section accordion FORM, 5-tab DETAIL layout, and 5 inline child collections** (diff-persist)
**Reason**: The mockup shows a distinct FORM (accordion) vs DETAIL (5-tab profile page) UI — not a modal CRUD. URL drives mode. Multiple workflow transitions (Approve, Deactivate, etc.) on top of CRUD.

**Backend Patterns Required:**
- [x] Standard CRUD (Create/Update/Delete/Toggle/GetAll/GetById — 6 core files)
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation — 5 inline children, diff-persist (Family #20 / Program #51 precedent)
- [x] Multi-FK validation (ValidateForeignKeyRecord × ~9 FK fields)
- [x] Unique validation — VolunteerCode (strict), Email (strict), ContactId (soft)
- [x] **Workflow commands** (4 new commands: Approve / Deactivate / SetOnLeave / Reactivate)
- [x] **Custom business rule validators** — contact-mode handshake, AgreedToCodeOfConduct must be true
- [x] Contact auto-create in "Create new" mode (BE-side handshake)
- [x] Summary query `GetVolunteerSummary` (for KPI widgets)
- [ ] File upload command — NOT this screen (ProfilePhotoUrl is plain text; see ISSUE-3)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid with 10 cols, 5 chips, advanced filter panel)
- [x] **Variant B** (ScreenHeader + 4 KPI widgets + DataTableContainer showHeader=false) — MANDATORY
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form + zod (for FORM layout — NOT RJSF)
- [x] Zustand store (`volunteer-store.ts`)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (with Back, Save buttons)
- [x] **Multi-tab DETAIL view** (5 tabs: Overview, Schedule, Hours, Donations, Recognition)
- [x] **Accordion form** (6 collapsible sections)
- [x] **Contact Link radio+typeahead** (custom component — search-existing mode shows match/no-match states, create-new mode hides search)
- [x] **Multi-tag chip selector** (Skills, Interests — pre-populated MasterData chips with toggle)
- [x] **Tag-input widget** (Languages, Certifications — type & enter)
- [x] **Day-of-week chip grid** (Mon-Sun)
- [x] **Child-grid add/remove** (Blackout Dates — inline From-To rows)
- [x] **Workflow action buttons** (Approve on Pending rows, Deactivate/SetOnLeave in More menu)
- [x] **Bulk actions toolbar** (Assign to Shift PLACEHOLDER / Send Message PLACEHOLDER / Activate / Deactivate)
- [x] **Summary cards / count widgets above grid** (4 KPIs)
- [ ] Grid aggregation columns — NO per-row computed beyond standard MasterData badges

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `volunteer-list.html`, `volunteer-form.html`, `volunteer-detail.html`.

### Grid/List View

**Display Mode**: `table` (standard FlowDataTable, NOT card-grid)

**Grid Layout Variant**: `widgets-above-grid` → **Variant B MANDATORY** (ScreenHeader + 4 KPI widgets + DataTableContainer `showHeader={false}`). Use ChequeDonation #6 / Pledge #12 / Recurring #8 as implementation reference.

### Page Widgets & Summary Cards (Top row — 4 KPI cards)

| # | Widget Title | Icon | Value Source | Display Type | Subtext Source | Position |
|---|-------------|------|-------------|-------------|---------------|----------|
| 1 | Total Volunteers | fa-hands-helping (green) | `summary.totalVolunteers` | count | `Active: {active} · Inactive: {inactive} · Pending: {pending}` | Top row col 1 |
| 2 | Hours This Month | fa-clock (blue) | `summary.hoursThisMonth` (SERVICE_PLACEHOLDER 0 until #55) | count+suffix "hrs" | `↑{pctChange}% vs last month` (SERVICE_PLACEHOLDER — render "— vs last month" when data missing) | Top row col 2 |
| 3 | Upcoming Shifts | fa-calendar-check (orange) | `summary.upcomingShiftsCount` (SERVICE_PLACEHOLDER 0 until #54) | count | `This week · {n} volunteers scheduled` (SERVICE_PLACEHOLDER empty) | Top row col 3 |
| 4 | Skill Coverage | fa-star (purple) | `summary.distinctSkillsCount` | count | `Skills tracked · Top: {topSkillName} ({topSkillVolunteerCount})` | Top row col 4 |

**Summary GQL query**: `GetVolunteerSummary` → returns `VolunteerSummaryDto` with these fields + `topSkillName`, `topSkillVolunteerCount`, `distinctSkillsCount`, `activeCount`, `inactiveCount`, `pendingCount`, `totalVolunteers`, `onLeaveCount`. Use `ph:*` Phosphor icons per UI uniformity memory (fa-* only if Phosphor equivalent missing).

### Filter Bar (under widgets, part of Variant B grid header)

- **Search input** — placeholder: "Search by name, email, skill, or phone..." — server-side `searchText` arg matches across FirstName/LastName/Email/PhoneNumber (+ skill DataName via join)
- **Advanced Filters toggle button**

**Filter Chips** (5 — top-level GQL args on GetAll, per Family #20 precedent):
| Chip Label | GQL Arg Value | Default |
|-----------|---------------|---------|
| All | (no filter) | ACTIVE |
| Active | `volunteerStatusCode=ACT` | — |
| Inactive | `volunteerStatusCode=INA` | — |
| Pending Approval | `volunteerStatusCode=PEN` | — |
| On Leave | `volunteerStatusCode=LEV` | — |

**Advanced Filter Panel** (collapsible, 4 fields + Apply/Clear buttons):
| Field | Type | Source |
|-------|------|--------|
| Skills | multi-select (MasterData VOLUNTEERSKILL) | `skillMasterDataIds[]` arg |
| Availability | single dropdown (MasterData VOLUNTEERAVAILABILITYTYPE) | `availabilityTypeId` arg |
| Branch | single ApiSelectV2 | `branchId` arg |
| Hours Logged | select with buckets "> 100 hrs" / "> 50 hrs" / "> 20 hrs" / "None yet" | `hoursLoggedBucket` string arg (SERVICE_PLACEHOLDER — BE no-op until #55 lands; see ISSUE-4) |

### Bulk Actions Toolbar (appears on row selection)

| Action | Button Style | Handler |
|--------|-------------|---------|
| Assign to Shift | outline | SERVICE_PLACEHOLDER — toast until #54 built |
| Send Message | outline | SERVICE_PLACEHOLDER — toast (SMS/email not wired to this screen) |
| Activate | outline | Loops through selected IDs; for each with status ∈ {Pending, Inactive, OnLeave} calls the appropriate mutation (ApproveVolunteer or ReactivateVolunteer) |
| Deactivate | outline danger | Calls DeactivateVolunteer for each (those already INA skip) |

### Grid Columns (10 — in display order per mockup)

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | (checkbox) | — | row-select | 36px | — | Bulk selection |
| 2 | Volunteer | `fullName` (+ `avatarInitials` + `avatarColor` + `email` subline) | custom renderer `volunteer-avatar-name-subline` | auto | YES | Sort by lastName, fallback firstName |
| 3 | Contact | `contactCode` | link renderer `contact-link-or-new-pill` | 110px | NO | When `contactId` is null → italic "-- (New)" pill; when not null → link to `/[lang]/crm/contact/allcontacts?mode=read&id={contactId}`. See ISSUE-11. |
| 4 | Skills | `skills[]` (max 2 tags + "+N more") | custom renderer `skill-chip-list` | 240px | NO | Chips colored by skill's ColorHex from MasterData; "+{n} more" opens tooltip with full list |
| 5 | Availability | `preferredTimeName` or derived `Weekends` / `Weekdays PM` / `Full-time` / `Flexible` | text | 120px | YES | Compute on BE: if `availabilityTypeName` = Full-time → "Full-time"; else if IsAvailableSat && IsAvailableSun && !Mon-Fri → "Weekends"; else if IsAvailable{Mon-Fri} && preferredTimeName=Afternoon → "Weekdays PM"; else `preferredTimeName`. See ISSUE-12. |
| 6 | Hours (Total) | `totalHours` | `hours-cell` renderer (bold, "hrs" suffix) | 110px | YES (PLACEHOLDER — BE no-op until #55) | Shows `245 hrs`; gray+0 when PLACEHOLDER |
| 7 | Hours (Month) | `hoursThisMonth` | `hours-cell` | 110px | YES (PLACEHOLDER) | Same |
| 8 | Last Active | `lastActiveDate` | `DateOnlyPreview` (standard renderer) | 110px | YES | `Apr 11` format; "--" when null |
| 9 | Status | `volunteerStatusCode`/`volunteerStatusName`/`volunteerStatusColorHex` | custom renderer `volunteer-status-badge` | 120px | YES | Badge with colored dot + name; colors from MasterData ColorHex |
| 10 | Actions | — | built-in actions col | 160px | — | Always visible: View, Edit (→ Approve for Pending rows); More menu: View / Edit / Log Hours (deep-link) / View Schedule (deep-link) / Deactivate / Remove |

**Row Click**: Navigates to `?mode=read&id={volunteerId}` (DETAIL layout).

**Per-row quick action override**: When `volunteerStatusCode='PEN'` → replace "Edit" button with primary-green "Approve" button (calls `ApproveVolunteer` mutation). Keep "View" as secondary. Match mockup Row 6 exactly.

### Pagination / Table Footer

Standard FlowDataTable footer: "Showing X–Y of Z volunteers" + page-size select (10/25/50/100) + pagination chevrons. Default page size 10.

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

#### LAYOUT 1: FORM (mode=new & mode=edit)

**Page Header**: `FlowFormPageHeader` with Back button + page title (`Register Volunteer` for new, `Edit Volunteer: {fullName}` for edit) + subtitle + primary action "Register Volunteer" (or "Save Changes" in edit mode) + secondary "Register & Add Another" (new mode only) + "Cancel" text button. Unsaved-changes guard on navigate.

**Section Container Type**: **Accordion** (6 collapsible cards, all expanded by default; each has fa-icon + title + chevron toggle)

**Form Sections** (in display order):

| # | Icon | Section Title | Layout | Collapse Default | Fields |
|---|------|--------------|--------|------------------|--------|
| 1 | fa-link | Contact Link | full-width | expanded | Mode radio (Search existing / Create new) + Contact typeahead (visible in Search mode) |
| 2 | fa-user | Personal Information | 2-column | expanded | FirstName*, LastName*, Email*, Phone (DialCode+Number)*, DateOfBirth, Gender, Address (full-width), City*, Country*, ProfilePhotoUrl (full-width text URL field — see ISSUE-3) |
| 3 | fa-star | Skills & Interests | full-width | expanded | Skills* (multi-chip), OtherSkills (conditional), Interests (multi-chip), Languages (tag-input, full-width), Certifications (tag-input, full-width) |
| 4 | fa-calendar-alt | Availability | 2-column + full-width blocks | expanded | AvailabilityType, PreferredTime, AvailableDays (Mon-Sun chips — full-width), MaxHoursPerWeek (default 12), StartDate, BlackoutDates child-grid (full-width) |
| 5 | fa-phone-alt | Emergency Contact | 2-column | expanded | Name*, Relationship, Phone (DialCode+Number)* |
| 6 | fa-info-circle | Additional Information | 2-column + full-width blocks | expanded | HeardAboutSource, BranchId, PreviousExperience (full-width textarea), Motivation (full-width textarea), InternalNotes (full-width textarea), AgreedToCodeOfConduct* (checkbox, full-width) |

**Field Widget Mapping** (all fields across all sections):

| Field | Section | Widget | Placeholder / Label | Validation | Notes |
|-------|---------|--------|--------------------|-----------|-------|
| (mode radio) | 1 | radio group 2 opts | "Search existing contact" / "Create new contact" | — | Not stored; FE-only mode flag |
| ContactId | 1 | **contact-typeahead-picker** (custom) | "Search contacts by name, email, phone…" | required when mode=Search | Types into 300ms debounced search over `getContacts({searchText})`; shows match card w/ avatar+name+code+email+phone+"Select" button OR "No contact found — personal details below will create a new contact record" message. Auto-fills FirstName/LastName/Email/Phone from selected Contact. |
| FirstName | 2 | text | "Enter first name" | required, max 100 | Auto-filled from Contact when linked, editable always |
| LastName | 2 | text | "Enter last name" | required, max 100 | Same |
| Email | 2 | email | "email@example.com" | required, email format, max 200 | Unique per Company on save |
| DialCode | 2 | select (+ dropdown w/ common codes) | "+971" | required | 6 options minimum (`+971`, `+1`, `+44`, `+91`, `+966`, `+234`) — reuse existing phone component if any |
| PhoneNumber | 2 | tel | "50 123 4567" | required, numeric, max 20 | — |
| DateOfBirth | 2 | date | — | optional | No age-restriction validation in MVP |
| GenderId | 2 | ApiSelectV2 | "Select..." | optional | Query: `getMasterDatas` with `masterDataTypeCode='GENDER'` |
| Address | 2 | text (full-width) | "Street address" | optional, max 300 | — |
| City | 2 | text | "City" | required, max 100 | — |
| CountryId | 2 | ApiSelectV2 (full-width... well mockup puts it next to City so 2-col) | "Select country..." | required | Query: `getCountries` |
| ProfilePhotoUrl | 2 | image-upload drop-zone (**SERVICE_PLACEHOLDER**) | "Drag & drop a photo here, or browse" | optional | MVP: plain URL text input with helper "Upload coming soon — paste an image URL". See ISSUE-3. |
| (skills multi-chip) | 3 | **multi-tag-chip-selector** (custom) — populated from `getMasterDatas(typeCode=VOLUNTEERSKILL)` | — | at least 1 required | Chip toggle w/ selected-state styling (green bg white check); writes to `skills[]` array |
| OtherSkills | 3 | text | "Specify other skills..." | required when Other skill chip selected | Shown conditionally via `show={skills.some(s=>s.dataValue==='OTH')}` |
| (interests multi-chip) | 3 | same pattern | — | optional | typeCode=VOLUNTEERINTEREST |
| (languages tag-input) | 3 | **tag-input-pill-widget** (custom — type in text, press Enter to add pill; click × to remove) | "Type and press Enter to add..." | optional | Writes to `languages[]` array. Proficiency is NOT in mockup for form; omit in MVP (keep column in DB nullable for later UX). |
| (certifications tag-input) | 3 | same pattern + optional date appendix | "e.g., First Aid (Dec 2026) — press Enter to add..." | optional | Each pill is parsed: if text contains "(date-ish)" treat as ValidUntilDate best-effort; otherwise store as name only. Simple MVP. See ISSUE-14. |
| AvailabilityTypeId | 4 | select | "Part-time" default | optional | MasterData VOLUNTEERAVAILABILITYTYPE (4 options) |
| PreferredTimeId | 4 | select | "Afternoon (12 - 5 PM)" default | optional | MasterData VOLUNTEERPREFERREDTIME (4 options) |
| IsAvailable{Mon..Sun} | 4 | **day-chip-checkbox-row** (full-width) | 7 chips Mon/Tue/.../Sun | at least 1 (soft) | Each chip toggles one bool column |
| MaxHoursPerWeek | 4 | number | default 12, min 1, max 60 | optional | — |
| StartDate | 4 | date | — | optional | — |
| (blackoutDates) | 4 | **inline-child-grid** w/ add-row button | — | optional | Each row: FromDate | "to" separator | ToDate | × remove. "+Add Blackout Period" dashed border btn. Writes to `blackoutDates[]` array. |
| EmergencyContactName | 5 | text | "Emergency contact name" | required, max 150 | — |
| EmergencyContactRelationId | 5 | select | "Select..." default | optional | MasterData VOLUNTEEREMERGENCYRELATION |
| EmergencyContactDialCode + Phone | 5 | 2-part same as primary phone | "+971" + "50 987 6543" | required | — |
| HeardAboutSourceId | 6 | select | "Select..." default | optional | MasterData VOLUNTEERHEARDABOUTSOURCE |
| BranchId | 6 | ApiSelectV2 | "Dubai (HQ)" default | optional | Query: `getBranches` |
| PreviousExperience | 6 | textarea (full-width, min 80px) | "Describe any previous volunteering experience..." | optional, max 2000 | — |
| Motivation | 6 | textarea (full-width) | "Why do you want to volunteer with us?" | optional, max 2000 | — |
| InternalNotes | 6 | textarea (full-width) | "Internal notes about this volunteer..." | optional, max 2000 | Label suffix: "(internal, staff-only)" |
| AgreedToCodeOfConduct | 6 | checkbox + label "I agree to the volunteer code of conduct" | — | required=true on Save | Default false; enforces on submit |

**Special Form Widgets:**

- **Contact Link mode toggle**: Radio (`modeLink` | `modeNew`) writes to FE-only state. In `modeLink` → show typeahead + match card + "Select" CTA. In `modeNew` → hide typeahead entirely; personal-info section fields are standalone. On Save in `modeNew`, BE handler creates a fresh Contact first, then stamps the new ContactId. On Save in `modeLink` with ContactId null → validator error "Please select a contact or switch to 'Create new contact' mode". See ISSUE-1.

- **Multi-tag chip selector** (Skills, Interests): Chips rendered from MasterData source on mount (one query per typeCode, cached per-render). Each chip is `<button>` w/ `.selected` toggle class. Selected chips track `{masterDataId, dataName, dataValue}`. Submitted as `skills[]: [{skillMasterDataId: n}, ...]`. Renderer path: `src/presentation/components/shared/widgets/multi-tag-chip-selector.tsx` (NEW shared widget).

- **Tag-input-pill widget** (Languages, Certifications): Text input auto-wraps pills on Enter. Each pill has × to remove. Shared widget: `src/presentation/components/shared/widgets/tag-input-pill.tsx` (NEW).

- **Day-chip row** (Mon-Sun): 7 chips (day abbrev), each maps to one bool column. Shared widget: `src/presentation/components/shared/widgets/day-chip-row.tsx` (NEW).

- **Blackout child-grid**: Inline table-like list of `<BlackoutRow>` components (FromDate | "to" | ToDate | × button) with `+ Add Blackout Period` dashed btn. Shared widget or page-local — implementer's choice.

- **Inline Mini Display** (Section 1 match-result card): When typeahead returns a match, show a green card with Avatar, Name, ContactCode · Email · Phone, + "Select" button. Styling matches mockup `.contact-search-result` (green bg, green border).

**Conditional Sub-forms:**

| Trigger Field | Trigger Value | Sub-form / Behavior |
|---------------|---------------|---------------------|
| ContactMode | "Search existing" | Show typeahead + match/no-match cards |
| ContactMode | "Create new" | Hide typeahead; on Save BE creates Contact |
| Skills selection | Contains "Other" chip (DataValue=OTH) | Show `OtherSkills` text field (full-width) |

**Child Grids in Form:**

| Child | Grid Columns | Add/Edit Method | Delete | Notes |
|-------|-------------|----------------|--------|-------|
| BlackoutDate | FromDate, "to", ToDate, × | inline row (date pickers) | inline × button | Add via dashed "+Add Blackout Period" button below rows |

---

#### LAYOUT 2: DETAIL (mode=read) — DIFFERENT UI from the form (full-page 5-tab profile)

> NOT a drawer — full-page per mockup `volunteer-detail.html`.

**Page Header** (sticky at top):
- Back button (chevron-left) → navigates to `/[lang]/crm/volunteer/volunteerlist` (grid)
- Avatar (52px circle, colored) w/ initials
- Name (`fullName`) + Status badge (Active/Inactive/Pending/OnLeave — use renderer `volunteer-status-badge`) inline
- Meta line: "Volunteer since: {JoinedDate}" · "Linked Contact: {contactCode} ↗" (external-link icon) — the contact chip links to `/[lang]/crm/contact/allcontacts?mode=read&id={contactId}`

**Header Actions** (right side):
- **Edit** (primary green) → `?mode=edit&id={id}`
- **Log Hours** (outline teal) → deep-link to HourTracking #55: `/[lang]/crm/volunteer/volunteerhourtracking?volunteerId={id}` (SERVICE_PLACEHOLDER until #55 built — show toast "Hour Tracking module coming soon"). See ISSUE-4.
- **Assign Shift** (outline teal) → deep-link to VolunteerSchedule #54: `/[lang]/crm/volunteer/volunteerscheduling?volunteerId={id}` (SERVICE_PLACEHOLDER toast until #54). See ISSUE-5.
- **Send Message** (secondary) → SERVICE_PLACEHOLDER toast (NGO-side SMS/email orchestration not wired to volunteer screen)
- **More** (kebab) dropdown: Print Profile (SERVICE_PLACEHOLDER), Export (SERVICE_PLACEHOLDER), **Deactivate** (danger — opens DeactivateModal with reason textarea), **Remove** (danger — standard delete confirm)

**Quick Stats Row** (5 stat cards, centered text):

| # | Label | Value Source | Subtext |
|---|-------|-------------|---------|
| 1 | Total Hours | `totalHours` | `Rank: #{rankByHours} of {totalVolunteers}` — both SERVICE_PLACEHOLDERs; render "—" when null |
| 2 | This Month | `hoursThisMonth` (+ `hrs` suffix) | `↑{change} vs last month` — SERVICE_PLACEHOLDER |
| 3 | Shifts Completed | `shiftsCompleted` | `{upcomingShiftsCount} upcoming` — SERVICE_PLACEHOLDER |
| 4 | Events Volunteered | `eventsCount` | `Next: {nextEventName} ({nextEventDate})` — SERVICE_PLACEHOLDER |
| 5 | Donations Made | `donationsTotal` (+ currency symbol) | `Also a donor` when `isAlsoDonor` true; "—" otherwise (buildable) |

**Tabs** (5 — horizontal nav bar, active underlined green):

**Tab 1 — Overview** (2-column layout, 4 cards)

| Column | Card | Content |
|--------|------|---------|
| Left | Personal Information | info-list: Name / Email / Phone / Location (City, CountryName) / BranchName / EmergencyContact (Name + Relation) + subline phone |
| Left | Availability | Day-chips row (Mon-Sun, colored green if available, amber "partial" if conditional), info-list: Preferred Times / Max Hours/Week / Blackout Dates (list) |
| Right | Skills & Interests | 4 sub-blocks: Skills (colored tags) / Interests (gray tags) / Languages (teal lang-tags) / Certifications (orange cert-tags w/ optional valid-until date) |
| Right | Notes | note-item cards (italic) — from InternalNotes split by newline OR PreviousExperience/Motivation; keep simple: show InternalNotes as-is in one italic card if present |

**Tab 2 — Schedule** (SERVICE_PLACEHOLDER until #54)
- Card header: "Upcoming Shifts" + calendar legend (Event/Office/Field — colored dots)
- Table: Date | Shift (type badge) | Event/Location | Time | Status (Confirmed/Pending)
- MVP: render empty-state card with icon + "No shifts yet" message + "Assign First Shift" CTA (deep-link to #54)

**Tab 3 — Hours Log** (SERVICE_PLACEHOLDER until #55)
- Card header: "Hours Log" + primary-green "Log Hours" button (deep-link to #55)
- Table: Date | Activity | Hours | ApprovedBy | Notes
- Footer: "Showing N of M entries · Total: X hours" + "View All" button
- MVP: empty-state card + CTA

**Tab 4 — Donations** (BUILDABLE — partial if ContactId not null)
- Summary banner: `$4,200` donation-summary-value (green, large) + label "Total donated over {donationsCount} donations since {firstDonationYear}"
- Recent Donations table (limit 5): Date | Campaign (DonationPurposeName) | Amount (green bold) | Method (PaymentModeName) | Status (Completed badge)
- Footer info box: "This volunteer is also a donor — view full giving history in contact profile" → link to Contact profile
- Source: BE projection joins `fund.GlobalDonations` via `Contact.ContactId = Volunteer.ContactId` WHERE `IsActive` AND `PaymentStatusCode='COMPLETED'` — take TOP 5 by DonationDate desc
- When ContactId is null or donationsCount = 0 → show empty state "No donations linked yet."
- See ISSUE-13 — paymentMethod projection from PaymentTransaction may be best-effort.

**Tab 5 — Recognition** (SERVICE_PLACEHOLDER)
- 2-column:
  - Left: Badges card (fa-award trophy/star/medal — list of earned badges; empty state for MVP)
  - Left: Certificates Issued card (cert-item list with scroll icon + name + issued date; empty state for MVP)
  - Right: Manager Comments card (blockquote-styled comment; empty state for MVP)
- Entire tab is stubs with "Coming soon" copy.

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User sees FlowDataTable grid → clicks "+ Register Volunteer" → URL: `?mode=new` → **FORM** loads (6 sections, all expanded)
2. User selects Contact-Link mode → fills 6 sections → clicks Save → BE creates Volunteer + all 5 children in 1 transaction (plus new Contact if mode=Create new) → URL redirects to `?mode=read&id={newId}` → **DETAIL** loads
3. User clicks row or Actions "View" → URL: `?mode=read&id={id}` → DETAIL loads (5 tabs, Overview active)
4. User clicks "Edit" in DETAIL header → URL: `?mode=edit&id={id}` → FORM loads pre-filled → Save → back to DETAIL
5. User clicks "Approve" on Pending row (grid) → ApproveVolunteer mutation → row status flips to Active → KPI widgets refresh
6. User clicks "Deactivate" from DETAIL More menu → Deactivate modal (reason textarea) → DeactivateVolunteer mutation → stays on DETAIL with updated status
7. Unsaved changes: form dirty + navigate → confirm dialog "Discard changes?"

### Grid Aggregation Columns

**NONE** — no per-row computed values beyond standard nav-property joins (MasterData names, contact info). All hours-related aggregates ship as PLACEHOLDER 0.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: SavedFilter (FLOW pattern) — and for new-schema bootstrap, **Program #51 / Beneficiary #49 / Case #50** (case schema bootstrap precedent) — though `vol` is the first actual schema bootstrap completed end-to-end.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | Volunteer | Entity/class name |
| savedFilter | volunteer | Variable/field names |
| SavedFilterId | VolunteerId | PK field |
| SavedFilters | Volunteers | Table name, collection names |
| saved-filter | volunteer | FE route path, file names |
| savedfilter | volunteer | FE folder, import paths |
| SAVEDFILTER | VOLUNTEER | Entity upper code |
| notify | vol | DB schema |
| Notify | Vol | Backend group name (Models/Schemas/Business — `VolModels`, `VolSchemas`, `VolBusiness`, `VolConfigurations`) |
| NotifyModels | VolModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_VOLUNTEER | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/volunteer/volunteerlist | FE route path (FE feFolder = `volunteer`, leaf=`volunteerlist`) |
| notify-service | volunteer-service | FE service folder name (kebab `volunteer-service`) |

**New-schema bootstrap substitutions** (use Case schema naming precedent from Program #51 — `ICaseDbContext` / `CaseDbContext` / `CaseMappings` / `DecoratorCaseModules`):

| Program-precedent | → This schema |
|-------------------|---------------|
| `ICaseDbContext` | `IVolDbContext` |
| `CaseDbContext` | `VolDbContext` |
| `CaseMappings` | `VolMappings` |
| `DecoratorCaseModules` | `DecoratorVolModules` |
| `case` | `vol` (actual DB schema name; lowercase) |

**MenuCode note**: Registry says `volunteerlist` as leaf route. Per `MODULE_MENU_REFERENCE.md`, CRM_VOLUNTEER has `VOLUNTEERLIST=crm/volunteer/volunteerlist` at OrderBy=1 — this IS the main screen. The sibling `VOLUNTEERFORM=crm/volunteer/registervolunteer` (OrderBy=2) is LEGACY — it will be hidden via `IsMenuRender=0` since FLOW uses `?mode=new` on the VOLUNTEERLIST route. Same precedent as BENEFICIARYFORM hidden under BENEFICIARYLIST (#49 ISSUE-style).

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### NEW MODULE BOOTSTRAP (must be created BEFORE any Volunteer files — precedent: Program #51)

| # | File | Path | Purpose |
|---|------|------|---------|
| B1 | IVolDbContext.cs | `PSS_2.0_Backend/.../Base.Application/Data/Persistence/IVolDbContext.cs` | DbContext interface with all 6 DbSets |
| B2 | VolDbContext.cs | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Persistence/VolDbContext.cs` | DbContext impl inheriting common base, ToTable(..., "vol") |
| B3 | VolMappings.cs | `PSS_2.0_Backend/.../Base.Application/Mappings/VolMappings.cs` | Mapster configurations for Volunteer + 5 children |
| B4 | DecoratorVolModules (entry in DecoratorProperties.cs) | `PSS_2.0_Backend/.../Base.Application/Extensions/DecoratorProperties.cs` | `public const string Volunteer = "VOLUNTEER"` + 5 child consts |
| B5 | Migration folder | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Migrations/{timestamp}_AddVolModule_Volunteers_Initial.cs` | Create vol schema + all 6 tables |

**Wiring updates for new module** (same 7 files as Program #51 bootstrap):
| # | File | Edit |
|---|------|------|
| W1 | `IApplicationDbContext.cs` | Add `IVolDbContext` to inheritance chain |
| W2 | `DependencyInjection.cs` (ConfigureMappings) | Register `VolMappings.ConfigureMappings(config)` |
| W3 | `DependencyInjection.cs` (AddDbContext) | Register `VolDbContext` if separate registration |
| W4 | `GlobalUsing.cs` (Base.Application) | Add `global using Base.Domain.Models.VolModels;` |
| W5 | `GlobalUsing.cs` (Base.Infrastructure) | Same |
| W6 | `GlobalUsing.cs` (Base.API) | Same |
| W7 | `DecoratorProperties.cs` | Add `DecoratorVolModules` static class |

### Backend Files — Entity & Configs (6 entities × 2 = 12 files)

| # | File | Path |
|---|------|------|
| 1 | Volunteer entity | `Base.Domain/Models/VolModels/Volunteer.cs` |
| 2 | VolunteerSkill entity | `Base.Domain/Models/VolModels/VolunteerSkill.cs` |
| 3 | VolunteerInterest entity | `Base.Domain/Models/VolModels/VolunteerInterest.cs` |
| 4 | VolunteerLanguage entity | `Base.Domain/Models/VolModels/VolunteerLanguage.cs` |
| 5 | VolunteerCertification entity | `Base.Domain/Models/VolModels/VolunteerCertification.cs` |
| 6 | VolunteerBlackout entity | `Base.Domain/Models/VolModels/VolunteerBlackout.cs` |
| 7 | Volunteer EF config | `Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerConfiguration.cs` |
| 8 | VolunteerSkill EF config | `Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerSkillConfiguration.cs` |
| 9 | VolunteerInterest EF config | `Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerInterestConfiguration.cs` |
| 10 | VolunteerLanguage EF config | `Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerLanguageConfiguration.cs` |
| 11 | VolunteerCertification EF config | `Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerCertificationConfiguration.cs` |
| 12 | VolunteerBlackout EF config | `Base.Infrastructure/Data/Configurations/VolConfigurations/VolunteerBlackoutConfiguration.cs` |

### Backend Files — Schemas + CRUD + Workflow + Queries (15 files)

| # | File | Path |
|---|------|------|
| 13 | Schemas (all DTOs) | `Base.Application/Schemas/VolSchemas/VolunteerSchemas.cs` |
| 14 | Create Command | `Base.Application/Business/VolBusiness/Volunteers/CreateCommand/CreateVolunteer.cs` |
| 15 | Update Command | `Base.Application/Business/VolBusiness/Volunteers/UpdateCommand/UpdateVolunteer.cs` |
| 16 | Delete Command | `Base.Application/Business/VolBusiness/Volunteers/DeleteCommand/DeleteVolunteer.cs` |
| 17 | Toggle Command | `Base.Application/Business/VolBusiness/Volunteers/ToggleCommand/ToggleVolunteer.cs` |
| 18 | Approve Command | `Base.Application/Business/VolBusiness/Volunteers/ApproveCommand/ApproveVolunteer.cs` |
| 19 | Deactivate Command | `Base.Application/Business/VolBusiness/Volunteers/DeactivateCommand/DeactivateVolunteer.cs` |
| 20 | SetOnLeave Command | `Base.Application/Business/VolBusiness/Volunteers/SetOnLeaveCommand/SetOnLeaveVolunteer.cs` |
| 21 | Reactivate Command | `Base.Application/Business/VolBusiness/Volunteers/ReactivateCommand/ReactivateVolunteer.cs` |
| 22 | GetAll Query | `Base.Application/Business/VolBusiness/Volunteers/GetAllQuery/GetAllVolunteer.cs` |
| 23 | GetById Query | `Base.Application/Business/VolBusiness/Volunteers/GetByIdQuery/GetVolunteerById.cs` |
| 24 | GetSummary Query | `Base.Application/Business/VolBusiness/Volunteers/GetSummaryQuery/GetVolunteerSummary.cs` |
| 25 | VolunteerCodeGenerator | `Base.Application/Business/VolBusiness/Volunteers/Helpers/VolunteerCodeGenerator.cs` (optional helper; inline in CreateHandler acceptable) |
| 26 | Mutations endpoint | `Base.API/EndPoints/Vol/Mutations/VolunteerMutations.cs` |
| 27 | Queries endpoint | `Base.API/EndPoints/Vol/Queries/VolunteerQueries.cs` |

### Backend Wiring Updates (beyond new-module bootstrap)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Program.cs` (Base.API) — GraphQL registration | Add `.AddTypeExtension<VolunteerMutations>()` + `.AddTypeExtension<VolunteerQueries>()` |
| 2 | MasterData seed (if seeded via C# or appsettings) | OR rely on DB seed SQL — see DB seed section |

### Frontend Files (22 files — FLOW + new renderers + new shared widgets)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `src/domain/entities/volunteer-service/VolunteerDto.ts` |
| 2 | GQL Query | `src/infrastructure/gql-queries/volunteer-queries/VolunteerQuery.ts` |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/volunteer-mutations/VolunteerMutation.ts` |
| 4 | Page Config | `src/presentation/pages/crm/volunteer/volunteerlist.tsx` |
| 5 | Index dispatcher | `src/presentation/components/page-components/crm/volunteer/volunteerlist/index.tsx` |
| 6 | Index Page (Variant B) | `src/presentation/components/page-components/crm/volunteer/volunteerlist/index-page.tsx` |
| 7 | View Page (3 modes) | `src/presentation/components/page-components/crm/volunteer/volunteerlist/view-page.tsx` |
| 8 | Zustand Store | `src/presentation/components/page-components/crm/volunteer/volunteerlist/volunteer-store.ts` |
| 9 | Volunteer Create Form | `src/presentation/components/page-components/crm/volunteer/volunteerlist/volunteer-create-form.tsx` |
| 10 | Form Schemas (zod) | `src/presentation/components/page-components/crm/volunteer/volunteerlist/volunteer-form-schemas.ts` |
| 11 | Detail Page (full-page 5-tab) | `src/presentation/components/page-components/crm/volunteer/volunteerlist/volunteer-detail-page.tsx` |
| 12 | Detail Tabs — Overview | `src/presentation/components/page-components/crm/volunteer/volunteerlist/tabs/overview-tab.tsx` |
| 13 | Detail Tabs — Schedule | `src/presentation/components/page-components/crm/volunteer/volunteerlist/tabs/schedule-tab.tsx` |
| 14 | Detail Tabs — Hours | `src/presentation/components/page-components/crm/volunteer/volunteerlist/tabs/hours-tab.tsx` |
| 15 | Detail Tabs — Donations | `src/presentation/components/page-components/crm/volunteer/volunteerlist/tabs/donations-tab.tsx` |
| 16 | Detail Tabs — Recognition | `src/presentation/components/page-components/crm/volunteer/volunteerlist/tabs/recognition-tab.tsx` |
| 17 | KPI Widgets (4 cards) | `src/presentation/components/page-components/crm/volunteer/volunteerlist/volunteer-widgets.tsx` |
| 18 | Advanced Filter Panel | `src/presentation/components/page-components/crm/volunteer/volunteerlist/volunteer-advanced-filters.tsx` |
| 19 | Deactivate Modal | `src/presentation/components/page-components/crm/volunteer/volunteerlist/volunteer-deactivate-modal.tsx` |
| 20 | Set OnLeave Modal | `src/presentation/components/page-components/crm/volunteer/volunteerlist/volunteer-onleave-modal.tsx` |
| 21 | Route Page (OVERWRITE stub) | `src/app/[lang]/crm/volunteer/volunteerlist/page.tsx` |
| 22 | Contact Typeahead Picker | `src/presentation/components/page-components/crm/volunteer/volunteerlist/contact-typeahead-picker.tsx` (or `src/presentation/components/shared/widgets/contact-typeahead-picker.tsx` if worth promoting to shared — see ISSUE-15) |

**New shared widgets** (create at `src/presentation/components/shared/widgets/` — reusable beyond Volunteer):

| # | File | Purpose |
|---|------|---------|
| S1 | `multi-tag-chip-selector.tsx` | Toggleable chip grid for multi-select from MasterData (Skills, Interests, and future reuse) |
| S2 | `tag-input-pill.tsx` | Type-and-enter pill input (Languages, Certifications, and future reuse) |
| S3 | `day-chip-row.tsx` | Mon-Sun checkbox chips writing to 7 bool fields |

### New Cell Renderers (register in 3 component-column registries + shared-cell-renderers barrel)

| # | Renderer Key | File | Used For |
|---|-------------|------|----------|
| R1 | `volunteer-avatar-name-subline` | `src/presentation/components/shared/cell-renderers/volunteer-avatar-name-subline.tsx` | Col 2: avatar + name + email subline |
| R2 | `contact-link-or-new-pill` | `src/presentation/components/shared/cell-renderers/contact-link-or-new-pill.tsx` | Col 3: CON-1245 link or italic "-- (New)" |
| R3 | `skill-chip-list` | `src/presentation/components/shared/cell-renderers/skill-chip-list.tsx` | Col 4: up to 2 colored skill chips + "+N more" |
| R4 | `hours-cell` | `src/presentation/components/shared/cell-renderers/hours-cell.tsx` | Cols 6 & 7: bold number + "hrs" suffix, grayed when 0 |
| R5 | `volunteer-status-badge` | `src/presentation/components/shared/cell-renderers/volunteer-status-badge.tsx` | Col 9: status with dot + color from MasterData ColorHex |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/application/services/volunteer-service-entity-operations.ts` (NEW) | VOLUNTEER block (create/update/delete/toggle/approve/deactivate/setOnLeave/reactivate ops) |
| 2 | `src/application/services/operations-config.ts` | Import + register `volunteer-service-entity-operations` |
| 3 | `src/presentation/components/data-table/column-types/advanced/component-column.tsx` | Add 5 renderer cases |
| 4 | `src/presentation/components/data-table/column-types/basic/component-column.tsx` | Add 5 renderer cases |
| 5 | `src/presentation/components/data-table/column-types/flow/component-column.tsx` | Add 5 renderer cases |
| 6 | `src/presentation/components/shared/cell-renderers/index.ts` (barrel) | Export 5 new renderers |
| 7 | `src/presentation/pages/crm/volunteer/index.ts` | Export `VolunteerListPageConfig` |
| 8 | Sidebar menu config | (Already driven by Menu table seed — no code change) |
| 9 | Legacy `registervolunteer/page.tsx` | **DELETE** the stub file (FLOW uses `?mode=new` on volunteerlist route). DB seed hides VOLUNTEERFORM menu (IsMenuRender=0). See ISSUE-16. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Volunteer List
MenuCode: VOLUNTEERLIST
ParentMenu: CRM_VOLUNTEER
Module: CRM
MenuUrl: crm/volunteer/volunteerlist
OrderBy: 1
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER, APPROVE

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, APPROVE

GridFormSchema: SKIP
GridCode: VOLUNTEER

HideLegacyMenu: VOLUNTEERFORM (IsMenuRender=0 — register-volunteer route deprecated by FLOW ?mode=new)
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `VolunteerQueries`
- Mutation type: `VolunteerMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAllVolunteerList` | `[VolunteerResponseDto]` paged envelope | `searchText`, `pageNo`, `pageSize`, `sortField`, `sortDir`, `isActive`, `volunteerStatusCode` (chip), `skillMasterDataIds[]`, `availabilityTypeId`, `branchId`, `hoursLoggedBucket` |
| `getVolunteerById` | `VolunteerResponseDto` | `volunteerId` |
| `getVolunteerSummary` | `VolunteerSummaryDto` | (none — tenant-scoped) |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createVolunteer` | `VolunteerRequestDto` (with `skills[]`, `interests[]`, `languages[]`, `certifications[]`, `blackoutDates[]` arrays + optional `createNewContact: bool` flag) | `int` (new VolunteerId) |
| `updateVolunteer` | `VolunteerRequestDto` | `int` |
| `deleteVolunteer` | `volunteerId: Int` | `int` |
| `toggleVolunteer` | `volunteerId: Int` | `int` |
| `approveVolunteer` | `volunteerId: Int` | `int` |
| `deactivateVolunteer` | `volunteerId: Int`, `reason: String!` | `int` |
| `setOnLeaveVolunteer` | `volunteerId: Int`, `fromDate: DateOnly!`, `toDate: DateOnly!` | `int` |
| `reactivateVolunteer` | `volunteerId: Int` | `int` |

**`VolunteerResponseDto` Fields** (what FE receives — top-level + nested):

| Field | Type | Notes |
|-------|------|-------|
| volunteerId | number | PK |
| volunteerCode | string | e.g., VOL-0012 |
| contactId | number? | nullable |
| contactCode / contactName / contactEmail / contactPhone / contactDisplayName | string? | projected joins; null when contactId null |
| firstName / lastName / fullName / avatarInitials / avatarColor | string | — |
| email / dialCode / phoneNumber | string | — |
| dateOfBirth | string (ISO date)? | — |
| genderId | number? | — |
| genderName | string? | MasterData name |
| address / city | string? / string | — |
| countryId | number | — |
| countryName | string | — |
| profilePhotoUrl | string? | text URL (MVP) |
| availabilityTypeId / preferredTimeId / emergencyContactRelationId / heardAboutSourceId | number? | — |
| availabilityTypeName / preferredTimeName / emergencyContactRelationName / heardAboutSourceName | string? | MasterData names |
| isAvailableMonday..Sunday | boolean | 7 fields |
| availableDaysDisplay | string[] | derived — e.g., `['Mon','Wed','Sat']` |
| maxHoursPerWeek | number? | — |
| startDate | string (ISO date)? | — |
| emergencyContactName | string | — |
| emergencyContactDialCode / emergencyContactPhone | string | — |
| branchId | number? | — |
| branchName | string? | — |
| previousExperience / motivation / internalNotes / otherSkills | string? | — |
| agreedToCodeOfConduct | boolean | — |
| volunteerStatusId | number | — |
| volunteerStatusCode / volunteerStatusName / volunteerStatusColorHex | string | MasterData projection |
| joinedDate | string (ISO datetime)? | — |
| lastActiveDate | string (ISO datetime)? | — |
| deactivatedDate / deactivatedReason | string? / string? | — |
| onLeaveFromDate / onLeaveToDate | string (ISO date)? | — |
| skills | `VolunteerSkillDto[]` | `{id, volunteerId, skillMasterDataId, dataName, dataValue, colorHex, orderBy}` |
| interests | `VolunteerInterestDto[]` | `{id, volunteerId, interestMasterDataId, dataName, dataValue, orderBy}` |
| languages | `VolunteerLanguageDto[]` | `{id, volunteerId, languageName, proficiencyCode, orderBy}` |
| certifications | `VolunteerCertificationDto[]` | `{id, volunteerId, certificationName, validUntilDate, orderBy}` |
| blackoutDates | `VolunteerBlackoutDto[]` | `{id, volunteerId, fromDate, toDate, reason}` |
| **SERVICE_PLACEHOLDER computed** (all null/0 in MVP): | | |
| totalHours / hoursThisMonth | number | 0 — until #55 |
| shiftsCompleted / upcomingShiftsCount / eventsCount | number | 0 — until #54 |
| rankByHours | number? | null — until #55 |
| badgesEarned | `BadgeDto[]` | empty array |
| certificatesIssued | `CertificateDto[]` | empty array |
| managerComments | `ManagerCommentDto[]` | empty array |
| donationsTotal / donationsCount | number | buildable when contactId not null, else 0 |
| isAlsoDonor | boolean | — |
| isActive | boolean | Inherited |
| createdBy / createdDate / modifiedBy / modifiedDate | audit | Inherited |

**`VolunteerSummaryDto` Fields** (for KPI widgets):

| Field | Type | Notes |
|-------|------|-------|
| totalVolunteers | number | COUNT active |
| activeCount / inactiveCount / pendingCount / onLeaveCount | number | Status breakdown |
| hoursThisMonth | number | SERVICE_PLACEHOLDER 0 |
| hoursLastMonth | number | SERVICE_PLACEHOLDER 0 |
| hoursChangePercent | number? | SERVICE_PLACEHOLDER null |
| upcomingShiftsCount | number | SERVICE_PLACEHOLDER 0 |
| upcomingVolunteerCount | number | SERVICE_PLACEHOLDER 0 |
| distinctSkillsCount | number | COUNT DISTINCT VolunteerSkill.SkillMasterDataId on active volunteers |
| topSkillName | string? | MODE over VolunteerSkill |
| topSkillVolunteerCount | number | count of volunteers with topSkill |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors; `vol` schema migration `AddVolModule_Volunteers_Initial` applies cleanly
- [ ] `pnpm dev` — page loads at `/[lang]/crm/volunteer/volunteerlist`; legacy `/[lang]/crm/volunteer/registervolunteer` returns 404 or silently redirects (acceptable)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] 4 KPI widgets render with correct counts from seed data
- [ ] Grid loads with 10 cols; 5 chips filter by status; advanced panel filters by Skills/Availability/Branch/Hours
- [ ] Bulk actions toolbar shows on row select; Activate handles mixed statuses gracefully
- [ ] Pending rows show "Approve" quick action; clicking it transitions status and refreshes KPIs
- [ ] `?mode=new`: empty 6-section accordion FORM renders
- [ ] Contact-Link radio mode toggle works (Search mode shows typeahead + match/no-match cards; Create-new mode hides search)
- [ ] Typeahead debounced search hits `getContacts` with `searchText`; selecting a match fills FirstName/LastName/Email/Phone and sets `contactId`
- [ ] Skills multi-chip toggle works; "Other" chip triggers OtherSkills text field
- [ ] Languages + Certifications tag-input widgets work (Enter to add, × to remove)
- [ ] Day-of-week chip grid toggles 7 bool fields
- [ ] Blackout Dates child-grid add/remove rows
- [ ] Save in "Create new" mode creates both Contact + Volunteer atomically; contactId is populated in returned DTO
- [ ] Save in "Search existing" mode with pre-selected ContactId creates Volunteer only, using existing Contact's fields as defaults
- [ ] FK dropdowns (Gender, AvailabilityType, PreferredTime, EmergencyContactRelation, HeardAboutSource, Branch, Country) all load via ApiSelectV2
- [ ] `?mode=edit&id=X`: FORM pre-fills ALL sections + all 5 child arrays + 7 day bools
- [ ] Edit save diffs children: new rows inserted, existing updated, removed deleted — all in 1 transaction
- [ ] `?mode=read&id=X`: full-page DETAIL layout with header + 5 Quick Stats + 5 Tabs
- [ ] Tab 1 Overview — 4 cards populated; day-chip grid shows availability; skill/interest/language/cert tags render
- [ ] Tab 2 Schedule — empty state with "Assign First Shift" CTA deep-linking to #54 (toast OK since #54 not built)
- [ ] Tab 3 Hours — empty state with "Log Hours" CTA deep-linking to #55 (toast OK)
- [ ] Tab 4 Donations — when seeded volunteer has a linked Contact with prior donations, summary + top 5 donations render; when not linked or no donations → empty state
- [ ] Tab 5 Recognition — empty placeholder content with "Coming soon" copy
- [ ] Header actions work: Edit navigates; Log Hours / Assign Shift / Send Message toast (SERVICE_PLACEHOLDER OK); Deactivate opens modal; Remove confirms then deletes
- [ ] Workflow modals: Deactivate captures reason; SetOnLeave captures from/to dates; Reactivate no-modal direct mutation
- [ ] Unsaved changes dialog fires on dirty FORM navigation
- [ ] Permissions: actions respect BUSINESSADMIN capabilities (Approve/Deactivate require APPROVE)

**DB Seed Verification:**
- [ ] VOLUNTEERLIST menu visible in sidebar under CRM_VOLUNTEER at OrderBy=1
- [ ] VOLUNTEERFORM menu hidden (IsMenuRender=0)
- [ ] Grid FLOW row in `sett.Grids` with GridCode=VOLUNTEER; 10 GridFields rows
- [ ] 7 MasterDataTypes populated with correct DataValue codes + ColorHex (for STATUS + SKILL)
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **NEW MODULE — `vol` schema**: This is the FIRST entity in `vol` — the backend developer MUST bootstrap `IVolDbContext` / `VolDbContext` / `VolMappings` / `DecoratorVolModules` before any Volunteer file. Reference Program #51 bootstrap precedent (it did the same for `case` schema). If building out-of-order (Schedule #54 or Hours #55 before Volunteer), that session would need to do the bootstrap first — but the expected build order per DEPENDENCY-ORDER.md puts Volunteer in Wave 2 BEFORE the Schedule/Hours Wave 3 screens.
- **CompanyId is NOT a field** in the RequestDto — comes from HttpContext on Create/Update. `Volunteer.CompanyId` column IS stamped on the row, just not accepted from the client.
- **FLOW screens do NOT generate GridFormSchema** — SKIP it in DB seed. GridFormSchema=NULL.
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout; read has a DIFFERENT UI (full-page 5-tab profile, NOT form disabled).
- **Variant B MANDATORY** — ScreenHeader + 4 KPI widgets + `DataTableContainer showHeader={false}`. Use ChequeDonation #6 / Pledge #12 as reference. Double-header bug precedent: ContactType #19.
- **ContactId FK uses ContactModels group** (schema `cont`), NOT AppModels. Confirmed via FK Resolution.
- **Legacy VOLUNTEERFORM menu**: DB seed must hide it (`IsMenuRender=0`) AND the FE must delete the `registervolunteer/page.tsx` stub file. FLOW uses `?mode=new` on the VOLUNTEERLIST route. Precedent: BENEFICIARYFORM hidden under BENEFICIARYLIST (#49).
- **Phosphor icons preferred** — use `ph:*` icons where possible; fa-* fallback only when no Phosphor equivalent. Mockup uses fa-* which must be mapped during FE generation. UI uniformity memory precedent.
- **Preserve `sql-scripts-dyanmic/` folder typo** — seed file goes into that folder per ChequeDonation #6 / RecurringDonationSchedule #8 precedent (ISSUE-15).
- **BUSINESSADMIN-only role config** — do not enumerate all 7 roles in approval config (per feedback memory).
- **Do NOT run full builds during planning** — planning is analysis-only.

**Service Dependencies** (SERVICE_PLACEHOLDER — UI built, handler stubbed):

1. **Hours aggregation fields** (`totalHours`, `hoursThisMonth`, `rankByHours`, `summary.hoursThisMonth`, `summary.hoursLastMonth`, `summary.hoursChangePercent`) — VolunteerHourLog entity does not exist until HourTracking #55 is built. BE returns 0/null; FE renders grayed "0 hrs" or "—". Add BE `TODO` comments at the exact projection sites so #55 build can plug in. See ISSUE-4.
2. **Shift/Schedule fields** (`shiftsCompleted`, `upcomingShiftsCount`, `eventsCount`, `summary.upcomingShiftsCount`, `summary.upcomingVolunteerCount`) — VolunteerSchedule entity does not exist until #54. Same placeholder treatment. See ISSUE-5.
3. **Profile photo upload** — No file-upload infrastructure in codebase yet. Ship as plain text URL input with helper text "Upload coming soon — paste an image URL". Same decision as DonationInKind #7 ISSUE-5 and Pledge #12 scope. See ISSUE-3.
4. **Send Message** — SMS/Email orchestration is scoped to Campaign screens (#30 SMSCampaign etc.). Volunteer-screen "Send Message" button is NOT wired to that flow. Handler → toast "Send messaging coming soon".
5. **Export / Print Profile / Import** — No export framework. Toast placeholders.
6. **Assign to Shift bulk action** — Requires #54. Toast.
7. **Badges / Certificates Issued / Manager Comments tabs** — No gamification / certificate-issuance / comment-thread infrastructure. Empty state placeholders. See ISSUE-7, ISSUE-8, ISSUE-9.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | /plan-screens 2026-04-21 | HIGH | BE — Contact handshake | "Create new contact" mode — BE Create handler must transactionally (a) create a Contact row with tenant=Company, `ContactTypeCode` defaulting to `VOLUNTEER` or `GENERAL` (confirm with BA — may require a new MasterData row if `VOLUNTEER` type doesn't exist on Contact), (b) insert Volunteer with new ContactId, (c) roll back both on any failure. Concurrency: two users registering same Email at same time → ValidateUnique must catch, Contact-create must be wrapped in the same transaction scope. Reference similar cross-tenant-create: Beneficiary #49 Contact auto-create (if implemented). | OPEN |
| ISSUE-2 | /plan-screens 2026-04-21 | MED | BE/FE — Soft duplicate contact check | If a volunteer is registered linking to a ContactId that already has an existing Volunteer record (CompanyId-scoped), BE emits a soft-warning (log + response flag) but does not block. FE should show a non-blocking warning banner "This contact is already registered as a volunteer on {date}". Not in scope for MVP; BE logs only. | OPEN |
| ISSUE-3 | /plan-screens 2026-04-21 | MED | FE — File upload | `ProfilePhotoUrl` ships as plain text URL field (no multipart upload infra in codebase). When upload service lands, change field to file-upload widget + BE file-storage handler. Same placeholder treatment as DonationInKind #7 photos. | OPEN |
| ISSUE-4 | /plan-screens 2026-04-21 | HIGH | BE/FE — Hours aggregation | `totalHours` / `hoursThisMonth` / `rankByHours` + 3 summary fields all return 0/null until HourTracking #55 is built. Add `// TODO: projection for VolunteerHourLog aggregation pending #55` at each projection site. When #55 lands, replace the literal 0 with actual SUM/COUNT subqueries. Acceptance-test this screen CANNOT verify hours data end-to-end until #55 is complete. | OPEN |
| ISSUE-5 | /plan-screens 2026-04-21 | HIGH | BE/FE — Shift aggregation | `shiftsCompleted` / `upcomingShiftsCount` / `eventsCount` + 2 summary fields all 0 until VolunteerSchedule #54 built. Same TODO placeholder strategy. Same test limitation. | OPEN |
| ISSUE-6 | /plan-screens 2026-04-21 | LOW | BE — LastActiveDate fallback | Per § ② entity table, `LastActiveDate` resolves to `Entity.ModifiedDate` in MVP. After #55 lands, it should become `GREATEST(ModifiedDate, MAX(VolunteerHourLog.LoggedAt))`. Document in code. | OPEN |
| ISSUE-7 | /plan-screens 2026-04-21 | LOW | FE/BE — Gamification / badges | "Recognition" tab Badges panel shows empty state. Gamification (hours thresholds, event champion, top N) is a separate product layer — not MVP. Empty state with "Coming soon" copy. | OPEN |
| ISSUE-8 | /plan-screens 2026-04-21 | LOW | FE/BE — Certificates Issued | Certificate-issuance platform is a separate product layer (maybe integrated with CRM_CERTIFICATE menu). Empty state. | OPEN |
| ISSUE-9 | /plan-screens 2026-04-21 | LOW | FE/BE — Manager Comments | No comment-thread infrastructure for volunteer profile. Empty state. Potentially candidate for a Notes-with-threads feature in future. | OPEN |
| ISSUE-10 | /plan-screens 2026-04-21 | MED | BE — Hard-delete guard | Once VolunteerSchedule #54 and HourTracking #55 exist, Delete handler must reject hard-delete when child records exist (or cascade — decide then). MVP allows unconditional hard-delete. | OPEN |
| ISSUE-11 | /plan-screens 2026-04-21 | MED | FE — contact-link route | Contact profile route in mockup is `contacts/contact-detail` — actual FE route is `/[lang]/crm/contact/allcontacts?mode=read&id={id}` per Contact #18 (which is not yet built). Use this path when Contact #18 lands; until then the link target is a non-existent FE route. FE should still render the link (href correct); clicking shows 404 or the existing stub. | OPEN |
| ISSUE-12 | /plan-screens 2026-04-21 | MED | BE — Availability display derivation | The `availabilityDisplay` string in the grid (col 5 "Availability") is derived from combinations of 7 bool days + AvailabilityType + PreferredTime. The derivation rules in § ⑥ grid col table are a first-cut — BA should validate. Simpler alternative: show `availabilityTypeName` only (Part-time / Full-time / Occasional / Events Only) and display detailed day breakdown only in the DETAIL availability card. Decision deferred to UX Architect. | OPEN |
| ISSUE-13 | /plan-screens 2026-04-21 | MED | BE — Donations tab projection | Tab 4 "Donations" queries GlobalDonations WHERE ContactId=Volunteer.ContactId — may have perf cost when fetched per drawer load. Consider: include as nested projection on GetById OR separate query `getVolunteerDonationHistory(volunteerId)` called only when Tab 4 is opened (lazy). Recommend lazy-load — matches tab-gated render pattern. | OPEN |
| ISSUE-14 | /plan-screens 2026-04-21 | LOW | FE — Certification date parsing | Mockup shows certifications as "First Aid (Dec 2026)" — a text pill. MVP stores name only; ValidUntilDate is a separate optional date field exposed only in EDIT mode via an "expand" icon per pill. Simpler alternative: accept free text only, parse later. Keep DB column nullable. | OPEN |
| ISSUE-15 | /plan-screens 2026-04-21 | LOW | FE — Contact typeahead component reuse | `contact-typeahead-picker.tsx` may be useful beyond Volunteer (Pledge donor, Refund requester, etc). Decide during build: keep page-local vs promote to `src/presentation/components/shared/widgets/`. Recommend: build page-local first, promote after 2nd consumer emerges (YAGNI). | OPEN |
| ISSUE-16 | /plan-screens 2026-04-21 | LOW | FE — Legacy route cleanup | `src/app/[lang]/crm/volunteer/registervolunteer/page.tsx` (4-line stub) should be deleted during build — FLOW consolidates add/edit into VOLUNTEERLIST `?mode=new`/`?mode=edit`. Also delete `src/app/[lang]/crm/volunteer/registervolunteer/` directory entirely. DB seed hides the menu; FE must remove the route file (stale 404 otherwise). | OPEN |
| ISSUE-17 | /plan-screens 2026-04-21 | MED | BE — Contact type defaulting in Create-new mode | When BE auto-creates a Contact in "Create new" mode, what ContactTypeId does it get? Reuse an existing ContactType row named "Volunteer" or "Individual" — OR add a new ContactType seed. Deferred to BA during approval. Suggestion: default to ContactType with TypeCode='INDV' (Individual) if it exists, fallback to the first active ContactType row for the Company. | OPEN |
| ISSUE-18 | /plan-screens 2026-04-21 | LOW | BE — Volunteer email vs Contact email divergence | After a Volunteer links to a Contact, the user may edit Volunteer.Email directly. BE does NOT sync the edit back to Contact.Email (different entities, different lifecycles). If sync is desired later, add a post-Update hook. MVP: fields diverge silently. | OPEN |
| ISSUE-19 | /plan-screens 2026-04-21 | LOW | FE — Bulk action permission granularity | Bulk Activate / Deactivate should respect per-row status — a volunteer already Active cannot be "Activated" again. FE client-side skips no-op rows and shows toast "3 activated, 2 skipped". BE workflow mutations are per-row — FE loops. Batch-level mutation is NOT in scope MVP. | OPEN |
| ISSUE-20 | /plan-screens 2026-04-21 | MED | BE/DB — New MasterData type groups | 7 new MasterDataType rows seeded: VOLUNTEERSTATUS, VOLUNTEERSKILL (20 rows), VOLUNTEERINTEREST (8 rows), VOLUNTEERAVAILABILITYTYPE (4 rows), VOLUNTEERPREFERREDTIME (4 rows), VOLUNTEEREMERGENCYRELATION (6 rows), VOLUNTEERHEARDABOUTSOURCE (5 rows). Ensure MasterDataType entries first, then MasterData entries with correct TypeCode FK. Seed must be idempotent. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
