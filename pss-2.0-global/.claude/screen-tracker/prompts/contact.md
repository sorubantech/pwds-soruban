---
screen: Contact
registry_id: 18
module: Contacts
status: PARTIALLY_COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-19
completed_date:
last_session_date: 2026-04-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (list + FORM layout + DETAIL layout — all 3 compound files)
- [x] Existing code reviewed (BE mature, FE mature with Zustand + child sub-stores + 6 tabs)
- [x] Business rules + workflow extracted
- [x] FK targets resolved (25 FKs — 14 entities + 11 MasterData TypeCodes)
- [x] File manifest computed (ALIGN — incremental adds + detail-page rebuild)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt Sections ①②③④ already cover entity + FKs + rules comprehensively; no enrichment needed)
- [x] Solution Resolution complete (prompt Section ⑤ pre-classifies FLOW + all BE/FE patterns)
- [x] UX Design finalized (FORM = 8 accordion sections; DETAIL = left sidebar + tabbed right column + engagement score card + org-units footer — all detailed in Section ⑥)
- [x] User Approval received
- [x] Backend code — ALIGN: added `GetContactSummary.cs`; extended `ContactDto`/`ContactResponseDto` with 5 new child collections + 6 list-projection fields (ContactBaseTypeCode, PrimaryEmail, PrimaryPhone, EngagementScore stub=0, LastDonationAmount, ContactTypeList, TagList); extended `CreateContact.cs` + `UpdateContact.cs` to persist/diff-update nested SocialLinks/Relationships/TypeAssignments/Tags/UPIDetails; new `ContactSummaryDto`, `ContactTypePillDto`, `TagPillDto`, `ContactCustomFieldsDto`.
- [x] Backend wiring — `ContactQueries.cs` registers `getContactSummary`; `ContactMappings.cs` extended for 5 new DTOs + pill DTOs.
- [x] Frontend code — DETAIL layout delivered (13 new files: detail-page, contact-sidebar, engagement-score-ring, score-factor-bars, engagement-score-card, 6 tabs, org-units-table); 3 list-page controls (filter-chips-bar, advanced-filter-panel, bulk-actions-bar); 2 form-helpers (contact-type-card-selector, cascading-address-fields); 6 new cell renderers (contact-avatar-name, score-circle, last-donation-date-amount, contact-type-badge-list, tag-badge-list-overflow, pref-icon); ContactDto + ContactQuery + ContactMutation + contact-store extended; legacy `ContactTagQuery.ts` `tagColor → color` fix closes Tag #22 ISSUE-1. **DEFERRED (see ISSUE-11)**: FORM not yet restructured to 8-section accordion — kept existing 5-tab wizard to avoid high-risk refactor of parent-form + 11 sub-components + save-state hook triad in a single pass. FORM is functionally complete with existing wizard.
- [x] Frontend wiring — 6 new renderers registered in all 3 component-column.tsx registries (advanced + flow + basic); shared-cell-renderers/index.ts updated.
- [x] DB Seed script — `Contact-sqlscripts.sql` created (idempotent MENU block + FLOW grid + 9 GridFields matching mockup's 8 visible columns + hidden PK; GridFormSchema=null).
- [x] Registry updated to PARTIALLY_COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/[lang]/crm/contact/allcontacts`
- [ ] Grid loads with 8 columns (Code, Name+Avatar, Type badges, Email, Phone, Score, LastDonation, Tags)
- [ ] Quick filter chips work (All, Donors, Volunteers, Members, Organizations, Inactive)
- [ ] Advanced Filter panel toggles + filters by type/score/tags/country/date-added/last-donation-date
- [ ] Column Configurator shows/hides columns
- [ ] Bulk Actions bar appears on row selection (Send Email, Add Tags, Export Selected, Delete)
- [ ] `?mode=new` — empty FORM: 8 accordion sections render; Sections 1 & 2 expanded by default, 3–8 collapsed
- [ ] Individual/Organization radio toggle shows/hides org-only and individual-only fields
- [ ] Phone/Email/Social Links repeatable rows add/remove correctly; Primary radio exclusive; WhatsApp checkbox per phone
- [ ] Address cascade: Country → State → District → City → Locality → Pincode populates dependent dropdowns
- [ ] Communication Preferences toggles (Do Not Email/Phone/SMS/Postal) save correctly
- [ ] Family section: select existing Family OR expand "Create New Family" inline form
- [ ] Relationships mini-grid: add/remove rows with Related Contact + Relation Type + Start Date
- [ ] Org Unit Assignments: repeatable rows (OrgUnit + Currency + Configured + Pledge)
- [ ] Contact Types card-selector: multi-select visual cards; auto-stamps assigned date
- [ ] Custom Fields (Anniversary, Referred By, Preferred Contact Time, Tax ID) save as JSON blob
- [ ] Save creates contact → URL redirects to `?mode=read&id={newId}`
- [ ] `?mode=read&id=X` — DETAIL layout: left sidebar (sticky, 340px) + right tabbed card + engagement score card + org-units table
- [ ] Left sidebar shows: Profile card (avatar + name + job/org + Engagement ring + 5 score-factor bars), Personal Info card, Tags card, Comm Prefs card, Custom Fields card
- [ ] Right column: Engagement Score banner card at top (with expandable "How is this calculated?" formula panel showing 7 factors + composite calc + quick reference)
- [ ] Right column tabs: Timeline (default) | Donations | Relationships | Communication | Events | Documents
- [ ] Timeline tab: 7 filter chips (All/Donations/Emails/Calls/Events/Notes/Volunteer) + vertical timeline list
- [ ] Donations tab: 6 mini-stat cards + donations table with receipt links
- [ ] Relationships tab: table with Add Relationship button, bi-directional contacts
- [ ] Communication tab: table of email activity (Sent/Opened/Clicked statuses)
- [ ] Events tab: table of event participation
- [ ] Documents tab: table of uploaded docs
- [ ] Org Units table (below tabs, always visible): 5 columns (Unit, Configured, Total Donated, Pledge, Count)
- [ ] Edit button on detail → `?mode=edit&id=X` → FORM pre-filled with existing data
- [ ] Save in edit mode updates record → back to detail layout
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] FK dropdowns load via ApiSelect: Gender, Language, Occupation, Country, ContactSource, Staff (User), MasterData-backed (ContactBaseType, Prefix, Suffix, OrgType, ContactStatus, PreferredCommunication, PhoneType, EmailType, SocialType, AddressType, RelationType)
- [ ] SERVICE_PLACEHOLDERs emit toasts (Engagement score calc, Timeline aggregation, Merge, Import, Export, Print)
- [ ] DB Seed — menu visible under CRM_CONTACT; 8 grid columns render; capabilities applied

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Contact
Module: Contacts (CRM > Contact)
Schema: corg
Group: ContactModels

Business: Contact is the **central master** of the NGO CRM — it represents every person or organization the nonprofit engages with (donors, volunteers, members, prospects, board members, staff, ambassadors, even deceased honorees). A single contact may hold multiple "types" simultaneously (a donor who also volunteers) and is the FK target for donations, pledges, memberships, volunteer hours, grants, case beneficiaries, relationships, tags, segments, campaigns, events, and communications. This screen is the primary operational surface: staff search/filter thousands of contacts, open a rich DETAIL page with timeline + engagement score + donations + relationships + communications history, and edit a comprehensive 8-section form (Basic Info, Contact Info, Addresses, Comm Prefs, Family & Relationships, Org Units, Contact Types, Custom Fields). The detail view conveys **who this person is and how engaged they are** — the engagement score (0–100) and its 7-factor breakdown (Donation Recency/Frequency/Monetary + Email/Event/Communication/Volunteer) is the headline. The Contacts screen is foundational — it's the most heavily used screen in the product and sits upstream of almost every other CRM workflow.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Entity already exists. ALIGN scope — this table documents the CURRENT schema for reference; backend changes are minimal (no migration; additive projection/DTO work only).
> **CompanyId IS already a field** on Contact — pre-dates FLOW convention. Do NOT remove; existing BE code relies on it.

Table: `corg.Contacts` (entity: `Base.Domain.Models.ContactModels.Contact`)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ContactId | int | — | PK | — | Primary key |
| CompanyId | int? | — | YES (runtime) | corg.Companies | Tenant scoping (stays on entity) |
| ContactCode | string? | 50 | Auto | — | e.g., "CON-0001", system-generated if empty |
| ContactBaseTypeId | int | — | YES | set.MasterData (TypeCode=CONTACTBASETYPE) | Individual / Organization / Household |
| PrefixId | int? | — | NO | set.MasterData (PREFIX) | Mr./Mrs./Ms./Dr. — Individual only |
| FirstName | string? | 100 | YES (Indiv) | — | Required when ContactBaseType=Individual |
| MiddleName | string? | 100 | NO | — | |
| LastName | string? | 100 | YES (Indiv) | — | Required when ContactBaseType=Individual |
| SuffixId | int? | — | NO | set.MasterData (SUFFIX) | Jr./Sr./PhD — Individual only |
| Nickname | string? | 200 | NO | — | |
| DisplayName | string? | 200 | Auto | — | Computed from name if empty |
| OrganizationName | string? | 200 | YES (Org) | — | Required when ContactBaseType=Organization |
| OrganizationTypeId | int? | — | NO | set.MasterData (ORGANIZATIONTYPE) | Non-Profit/Church/Foundation/Corporate/Government/Educational — Org only |
| DOB | DateOnly? | — | NO | — | Individual only |
| DOW | DateOnly? | — | NO | — | Wedding date — Individual only |
| GenderId | int? | — | YES (Indiv) | gen.Genders | Individual only |
| StaffUserId | int? | — | NO | auth.Users | Assigned staff member |
| IsDeceased | bool? | — | NO | — | |
| DeceasedDate | DateTime? | — | NO | — | |
| ContactSourceId | int? | — | NO | corg.ContactSources | Website/Referral/Event/Walk-in/Social Media/Campaign/Import/Other |
| ReferralContactId | int? | — | NO | corg.Contacts | Self-ref — who referred this contact |
| LanguageId | int? | — | NO | gen.Languages | Communication language |
| PrimaryCountryId | int | — | YES | gen.Countries | Primary country |
| OccupationId | int? | — | NO | gen.Occupations | |
| JobTitle | string? | 150 | NO | — | |
| EmployerOrganization | string? | 150 | NO | — | Free-text employer name |
| PreferredCommunicationId | int? | — | NO | set.MasterData (PREFERREDCOMMUNICATION) | Email/Phone/SMS/WhatsApp/Postal |
| DoNotEmail | bool? | — | NO | — | Opt-out flag |
| DoNotPhone | bool? | — | NO | — | |
| DoNotSMS | bool? | — | NO | — | |
| DoNotPostal | bool? | — | NO | — | |
| EmailOptInDate | DateTime? | — | NO | — | |
| EmailOptOutDate | DateTime? | — | NO | — | |
| ContactStatusId | int? | — | NO | set.MasterData (CONTACTSTATUS) | Active/Inactive/Deceased |
| ImagePath | string? | 500 | NO | — | Profile photo path |
| Notes | string? | — | NO | — | Free-text notes |
| FamilyId | int? | — | NO | corg.Families | Belongs to family |
| IsFamilyHead | bool | — | YES | — | Head-of-household marker |
| LastDonationDate | DateTime? | — | NO | — | Denormalized for grid display |
| CustomFields | string? | — | NO | — | JSON blob (Anniversary, ReferredBy, PreferredContactTime, TaxId) |

**Audit columns (inherited from `Entity` base)**: CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive, IsDeleted.

**Child Entities** (all exist under `Base.Domain.Models.ContactModels.*`; 1:Many from Contact):

| Child Entity | Relationship | Key Fields |
|--------------|--------------|------------|
| ContactPhoneNumber | 1:Many via ContactId | PhoneTypeId, CountryId (STD), PhoneNumber, IsPrimary, IsWhatsapp, IsVerified |
| ContactEmailAddress | 1:Many via ContactId | EmailTypeId, EmailAddress, IsPrimary, IsVerified |
| ContactAddress | 1:Many via ContactId | AddressTypeId, AddressLine1–4, CountryId, StateId, DistrictId, CityId, PincodeId, LocalityId |
| ContactSocialLink | 1:Many via ContactId | SocialTypeId (MasterData), LinkUrl |
| ContactRelationship | 1:Many via ContactId | RelationContactId, RelationTypeId (MasterData), StartDate, Notes |
| ContactTypeAssignment | 1:Many via ContactId | ContactTypeId (corg.ContactTypes), AssignedDate, AssignedByUserId |
| ContactTag | 1:Many via ContactId | TagId (corg.Tags), AssignedDate, AssignedByUserId |
| ContactUPIDetail | 1:Many via ContactId | UPIProviderId, UPIId, IsVerified |
| ContactDonationPurpose | 1:Many via ContactId | PurposeId + currency + configured/pledge amounts (Org Unit assignment proxy) |

**Known entity-level gap (flag as ISSUE, do not add in this session)**:
- There is **no `ContactOrgUnit` entity**. The mockup's "Organizational Unit Assignment" section (Section 6 of form) maps today to `ContactDonationPurpose` (purpose + currency + configured + pledge amounts) — this is close but not a pure OrgUnit link. Flag as `ISSUE-1` in Section ⑫. Keep existing `ContactDonationPurpose` wiring; surface as "Org Unit Assignment" in UI with a mapping note.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)
> All paths verified by glob + grep on 2026-04-19.

### Direct-FK masters

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|---------------|-------------------|----------------|---------------|-------------------|
| GenderId | Gender | Base.Domain/Models/SharedModels/Gender.cs | GetGenders | GenderName | GenderResponseDto |
| LanguageId | Language | Base.Domain/Models/SharedModels/Language.cs | GetLanguages | LanguageName | LanguageResponseDto |
| OccupationId | Occupation | Base.Domain/Models/SharedModels/Occupation.cs | GetOccupations | OccupationName | OccupationResponseDto |
| PrimaryCountryId | Country | Base.Domain/Models/SharedModels/Country.cs | GetCountries | CountryName | CountryResponseDto |
| StaffUserId | User | Base.Domain/Models/AuthModels/User.cs | GetUsers | UserName | UserResponseDto |
| ContactSourceId | ContactSource | Base.Domain/Models/ContactModels/ContactSource.cs | GetContactSources | ContactSourceName | ContactSourceResponseDto |
| ReferralContactId | Contact (self-ref) | Base.Domain/Models/ContactModels/Contact.cs | GetContacts | DisplayName | ContactResponseDto |
| FamilyId | Family | Base.Domain/Models/ContactModels/Family.cs | GetFamilies | FamilyName | FamilyResponseDto |

### Child-table FKs (used inside form child grids)

| FK Field | Target | Entity File Path | GQL Query | Display | Notes |
|----------|--------|------------------|-----------|---------|-------|
| ContactAddress.StateId | State | Base.Domain/Models/SharedModels/State.cs | GetStates | StateName | Filter by CountryId |
| ContactAddress.DistrictId | District | Base.Domain/Models/SharedModels/District.cs | GetDistricts | DistrictName | Filter by StateId |
| ContactAddress.CityId | City | Base.Domain/Models/SharedModels/City.cs | GetCities | CityName | Filter by DistrictId |
| ContactAddress.LocalityId | Locality | Base.Domain/Models/SharedModels/Locality.cs | GetLocalities | LocalityName | Filter by CityId |
| ContactAddress.PincodeId | Pincode | Base.Domain/Models/SharedModels/Pincode.cs | GetPincodes | PincodeNumber | Filter by LocalityId |
| ContactTypeAssignment.ContactTypeId | ContactType | Base.Domain/Models/ContactModels/ContactType.cs | GetContactTypes | ContactTypeName | Master; company-scoped |
| ContactTag.TagId | Tag | Base.Domain/Models/ContactModels/Tag.cs | GetTags | TagName | From #22 TagsSegmentation |
| ContactRelationship.RelationContactId | Contact | Base.Domain/Models/ContactModels/Contact.cs | GetContacts | DisplayName | Exclude self |

### MasterData-backed FKs (single shared entity, filtered by TypeCode)

Entity: `Base.Domain/Models/SettingModels/MasterData.cs`
GQL: `GetMasterDatas(typeCode: String)` → `MasterDataResponseDto[]` — display field `DataName`

| Field | TypeCode | Sample values |
|-------|----------|---------------|
| ContactBaseTypeId | `CONTACTBASETYPE` | Individual, Organization, Household |
| PrefixId | `PREFIX` | Mr., Mrs., Ms., Dr., Rev., Pastor, Prof. |
| SuffixId | `SUFFIX` | Jr., Sr., PhD |
| OrganizationTypeId | `ORGANIZATIONTYPE` | Non-Profit, Church, Foundation, Corporate, Government, Educational |
| ContactStatusId | `CONTACTSTATUS` | Active, Inactive, Deceased |
| PreferredCommunicationId | `PREFERREDCOMMUNICATION` | Email, Phone, SMS, WhatsApp, Postal |
| ContactPhoneNumber.PhoneTypeId | `PHONETYPE` | Mobile, Home, Work, Fax |
| ContactEmailAddress.EmailTypeId | `EMAILTYPE` | Personal, Work, Other |
| ContactSocialLink.SocialTypeId | `SOCIALTYPE` | Facebook, Twitter/X, LinkedIn, Instagram, YouTube, Website |
| ContactAddress.AddressTypeId | `ADDRESSTYPE` | Home, Work, Mailing, Other |
| ContactRelationship.RelationTypeId | `RELATIONTYPE` | Spouse, Parent, Child, Sibling, Employer, Referrer |

> Build-screen reminder: MasterData rows for these TypeCodes must exist in the DB. Verify `MasterDataType` rows for all 11 TypeCodes before seeding Contact rows. If any TypeCode is missing, seed script must add both the MasterDataType row AND the MasterData rows.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `ContactCode` must be unique per Company. Auto-generated if blank (pattern `CON-NNNN`, zero-padded).
- Primary phone: AT MOST one `IsPrimary=true` per Contact in `ContactPhoneNumbers`.
- Primary email: AT MOST one `IsPrimary=true` per Contact in `ContactEmailAddresses`.

**Required Field Rules (conditional on ContactBaseType):**

| ContactBaseType | Required fields |
|-----------------|-----------------|
| Individual | FirstName, LastName, GenderId, PrimaryCountryId, ContactBaseTypeId |
| Organization | OrganizationName, PrimaryCountryId, ContactBaseTypeId |
| Household | HouseholdName (TBD — DTO-only today; see ⑫ ISSUE-2), PrimaryCountryId, ContactBaseTypeId |

**Conditional Visibility Rules (drive form UI):**
- **Individual-only** fields (hide when Org or Household): Prefix, FirstName, MiddleName, LastName, Suffix, DOB, DOW, Gender, Occupation
- **Organization-only** fields (hide otherwise): OrganizationName, OrganizationType
- Page `<h1>` title follows base-type: "New Contact" (Individual) | "New Organization" | "New Household"

**Business Logic:**
- `DisplayName` auto-generated from `Prefix + FirstName + LastName` (Individual) or `OrganizationName` (Org) if left blank on save.
- `IsDeceased=true` → `DeceasedDate` must be set; `ContactStatus` auto-flips to "Deceased" MasterData row.
- `IsFamilyHead=true` requires `FamilyId` to be set. Only ONE head per Family (validated on server — if flipping a new contact to head, auto-demote the current head).
- `EmailOptInDate` auto-set on first email opt-in; `EmailOptOutDate` auto-set when `DoNotEmail` flips true.
- `CustomFields` JSON stores 4 known keys from the mockup: `anniversaryDate`, `referredBy`, `preferredContactTime`, `taxIdNumber`.

**Child-grid integrity:**
- Phone: `PhoneType + PhoneNumber` combination should be unique per contact (loose; server warns, doesn't block).
- Address cascade: if State is set, Country must match; if District is set, State must match; etc. Enforced client-side by cascading dropdowns; server validates FK chain.
- Relationship: bidirectional mirror recommended but NOT enforced (a → b does NOT auto-create b → a); flag for future.
- ContactTypeAssignment: one (Contact, ContactType) pair per Company (no dupes).

**Workflow**: None (no state machine — contacts don't have Draft/Submitted/Approved transitions).

**Tenant scoping**: `CompanyId` — entity has existing column. List/GetById queries filter by `CompanyId == HttpContext.User.CompanyId`. Do NOT remove field (pre-dates FLOW convention).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED.

**Screen Type**: FLOW
**Type Classification**: Transactional master with 3-mode view-page (new/edit/read); 2 distinct UI layouts (FORM = 8-section accordion; DETAIL = left sidebar + tabbed right column).
**Reason**: Contact is the canonical "rich record" entity — opening a contact opens a full detail page (not a modal). Add/Edit uses a full-page accordion form with 8 sections including repeatable child grids (phones/emails/addresses/social/relationships/org-units), conditional Individual vs Organization field visibility, address cascade, and a visual card-selector for Contact Types. The detail view has a completely different UI (sidebar + tabs) from the form. Existing BE+FE already follow FLOW pattern — this is an ALIGN-scope fidelity pass to the mockup.

**Backend Patterns Required:**
- [x] Standard CRUD (already exists — 11+ files)
- [x] Tenant scoping (CompanyId — pre-existing on entity)
- [x] Nested child creation (ContactPhoneNumber, ContactEmailAddress, ContactAddress — already wired via nested DTO input; extend to SocialLink / Relationship / TypeAssignment / Tag / UPI)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 25)
- [x] Unique validation (ContactCode per Company)
- [x] Summary query — **ADD**: `GetContactSummary` returning `ContactSummaryDto` (Total, Active, Donors, Volunteers, Members, Organizations, Inactive counts — for quick filter chip badges, not widgets)
- [x] File upload command (UpdateContactProfilePhoto — already exists)
- [x] Custom business rule validators — IsFamilyHead uniqueness per Family; Primary flag uniqueness per contact

**Frontend Patterns Required:**
- [x] FlowDataTable (grid — exists; extend with filter chips, advanced filter panel, bulk actions bar, column configurator)
- [x] view-page.tsx with 3 URL modes (exists; rebuild DETAIL layout to match mockup)
- [x] React Hook Form for FORM layout (exists; restructure from 5 tabs to 8 accordion sections)
- [x] Zustand store (`contact-store.ts` — exists, mature, has 6 child sub-stores)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back, Save, Save & Add Another, Cancel)
- [x] Child grids inside form (phones, emails, social links, relationships, org-unit assignments)
- [x] Card selectors (Individual/Organization base-type radio; ContactTypes multi-card visual selector)
- [x] Conditional sub-forms (Individual vs Organization fields)
- [x] Cascading dropdown (Country → State → District → City → Locality → Pincode in Address block)
- [x] File upload widget (profile photo, drag & drop)
- [x] Detail tabs (Timeline / Donations / Relationships / Communication / Events / Documents)
- [x] Engagement score ring + factor bars + expandable formula panel (SERVICE_PLACEHOLDER — see ⑫)
- [ ] Summary widgets above grid — **NONE** per mockup (layout variant: grid-only)
- [ ] Grid aggregation columns — Last Donation (date + amount) is the only per-row computed value, already on entity as `LastDonationDate` + join

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from the 3 HTML mockups — this IS the design spec.
> **CRITICAL for FLOW**: BOTH the FORM layout (new/edit) AND the DETAIL layout (read) are described in full.

### Grid/List View

**Display Mode**: `table` (standard rows — NOT card-grid; confirmed by mockup <table> element)
**Layout Variant**: `grid-only` (NO KPI widgets, NO side panel above/beside the grid)

> FE Dev: Use **Variant A** (`<FlowDataTable>` with internal header). No `<ScreenHeader>`, no widgets. Reason: ContactType #19 precedent was Variant B because it had widgets; Contact-list has NONE. **DO NOT add widgets here** — mockup is clean list-only.

**Page Header (FlowDataTable internal header)**:
- Title: "All Contacts" + subtitle record count ("12,458 contacts")
- Header actions (right-aligned): New Contact (primary), Import (outline), Export (outline)

**Filter Bar (inside list card, above table):**

*Row 1 — Search + controls:*
- Text search: placeholder "Search by name, email, phone, code..." (full-width flex, `fa-search` prefix)
- Advanced Filters toggle button (`fa-sliders`) — expands the advanced panel
- Column Configurator button (`fa-gear`, right-aligned) — floating panel with column show/hide checkboxes

*Row 2 — Quick Filter Chips (pill buttons, single-select):*
| Chip | Default | Filter applied |
|------|---------|----------------|
| All | Active | (no filter) |
| Donors | — | Has ContactType assignment where ContactTypeName="Donor" |
| Volunteers | — | ContactType="Volunteer" |
| Members | — | ContactType="Member" |
| Organizations | — | ContactBaseType="Organization" |
| Inactive | — | IsActive=false |

*Advanced Filter Panel (collapsed by default, 2-row grid, appears on toggle):*
| Field | Widget | Notes |
|-------|--------|-------|
| Contact Type | Multi-select listbox (size=3) | Donor/Volunteer/Member/Organization |
| Engagement Score | Two number inputs (Min/Max) | 0–100 |
| Tags | Multi-select listbox | From Tags #22 |
| Country | Single select | From Country master |
| Date Added | Date range (from/to) | CreatedDate |
| Last Donation Date | Date range (from/to) | LastDonationDate |
| — | Apply Filters (primary) + Clear (outline) | |

**Bulk Actions Bar** (appears when rows selected, above table):
- Selected count label + actions: Send Email (SERVICE_PLACEHOLDER) · Add Tags · Export Selected · Delete (danger)

**Column Configurator** (floating panel via gear icon):
- Checkboxes: Contact Code, Name, Type, Email, Phone, Score, Last Donation, Tags — all default checked

**Grid Columns (in display order):**

| # | Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------|-----------|-------------|-------|----------|-------|
| — | (checkbox) | — | checkbox | 40px | — | Select-all + per-row |
| 1 | Contact Code | contactCode | text-link (accent) | 120px | YES (default sort asc) | Clickable → `?mode=read&id=X` |
| 2 | Name | displayName | avatar + text | auto | YES | 36px avatar circle (initials, colored) + display name bold + subtext (org type if Org) |
| 3 | Type | contactTypeList | badge-list | 140px | YES | Multiple pills: donor (green), volunteer (purple), member (blue), organization (orange) — maps from ContactTypeAssignments + ContactBaseType |
| 4 | Email | primaryEmail | text | auto | YES | From ContactEmailAddresses where IsPrimary=true |
| 5 | Phone | primaryPhone | text | 150px | YES | From ContactPhoneNumbers where IsPrimary=true (format: STD + number) |
| 6 | Score | engagementScore | score-circle | 80px | YES | 36px colored circle: high ≥70 (green), mid 50–69 (yellow), low <50 (red). **SERVICE_PLACEHOLDER** — see ⑫ |
| 7 | Last Donation | lastDonation | date + currency | 160px | YES | "Mar 15 - $500" — date from LastDonationDate, amount from joined latest donation |
| 8 | Tags | tagsList | tag-badge-list | auto | NO | Multiple `.tag-badge` pills + "+N more" overflow |
| — | Actions | — | ellipsis → dropdown | 48px | — | View / Edit / Merge / Send Email / Delete |

**Per-Row Actions (ellipsis dropdown):**
- View (`fa-eye`) → `?mode=read&id=X`
- Edit (`fa-pen`) → `?mode=edit&id=X`
- Merge (`fa-code-merge`) → navigates to Duplicate Detection flow (#21)
- Send Email (`fa-envelope`) → **SERVICE_PLACEHOLDER** (EmailSendJob infra; toast for now)
- Delete (`fa-trash`, danger)

**Row Click**: Click on Contact Code cell or row body → `?mode=read&id={id}`.

**Pagination**: Footer shows "Showing X–Y of Z" + page size select (10/25/50/100) + numbered pagination with Prev/Next.

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

> ```
> URL MODE                                  UI LAYOUT
> /crm/contact/allcontacts?mode=new        →  FORM LAYOUT (empty, 8 accordion sections)
> /crm/contact/allcontacts?mode=edit&id=X  →  FORM LAYOUT (pre-filled, editable)
> /crm/contact/allcontacts?mode=read&id=X  →  DETAIL LAYOUT (sidebar + tabbed right column — DIFFERENT UI)
> ```

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

> 8-section accordion form. Sections 1 & 2 expanded by default; 3–8 collapsed.

**Page Header**: FlowFormPageHeader
- Left: Back arrow → list
- Title: dynamic — "New Contact" / "New Organization" / "New Household" / "Edit Contact — {displayName}"
- Right: Save (primary), Save & Add Another (outline, new-mode only), Cancel (text, red hover)
- Mobile: header actions collapse into sticky bottom bar

**Section Container Type**: accordion cards (each section is a white `.form-card` with clickable header + `fa-chevron-down` toggle)

**Form Sections (in display order):**

| # | Icon | Section Title | Layout | Default State | Fields |
|---|------|--------------|--------|---------------|--------|
| 1 | fa-user | Basic Information | 2-column grid with full-width overrides | EXPANDED | ContactBaseType (radio), OrganizationName, OrganizationType, Prefix, FirstName, MiddleName, LastName, Suffix, Nickname, DisplayName, DOB, DOW, Gender, Language, Occupation, EmployerOrganization, JobTitle, ContactSource, AssignedStaff (StaffUserId), ContactStatus, ProfileImage (upload), Notes (textarea, full-width) |
| 2 | fa-phone | Contact Information | 3 sub-sections (phones / emails / social links) | EXPANDED | Repeatable rows per sub-section |
| 3 | fa-map-marker-alt | Address | Repeatable address blocks (2-col grid each) | COLLAPSED | Per block: AddressType, AddressLine1–4, Country→State→District→City→Locality→Pincode cascade |
| 4 | fa-comment-dots | Communication Preferences | 2-column grid | COLLAPSED | PreferredCommunication, EmailOptInDate, EmailOptOutDate, DoNotEmail / DoNotPhone / DoNotSMS / DoNotPostal (toggle switches row) |
| 5 | fa-people-roof | Family & Relationships | 2-col + inline sub-form + mini-table | COLLAPSED | Family (select), IsFamilyHead (checkbox), "Create New Family" inline form (FamilyCode, FamilyName, Address), Relationships mini-grid (RelatedContact, RelationType, StartDate) |
| 6 | fa-sitemap | Organizational Unit Assignment | Repeatable rows | COLLAPSED | OrgUnit, Currency, ConfiguredAmount, PledgeAmount (see ⑫ ISSUE-1 — maps to ContactDonationPurpose today) |
| 7 | fa-tags | Contact Types | Card-selector flex wrap | COLLAPSED | 7 visual cards — Donor, Volunteer, Member, Prospect, Board Member, Staff, Ambassador — multi-select with auto-assigned date |
| 8 | fa-puzzle-piece | Custom Fields | 2-column grid | COLLAPSED | Anniversary Date, Referred By (text), Preferred Contact Time (select), Tax ID Number (text) |

**Field Widget Mapping — Section 1 (Basic Information):**

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| ContactBaseType | radio-group (inline) | — | required | Triggers show/hide via `useWatch` |
| OrganizationName | text | "e.g., Acme Foundation" | required if Org, max 200 | full-width; hidden if not Org |
| OrganizationType | ApiSelectV2 (MasterData typeCode=ORGANIZATIONTYPE) | "Select org type" | — | hidden if not Org |
| Prefix | ApiSelectV2 (PREFIX) | "Select prefix" | — | Individual-only |
| FirstName | text | "First name" | required if Indiv, max 100 | Individual-only |
| MiddleName | text | "Middle name" | max 100 | Individual-only |
| LastName | text | "Last name" | required if Indiv, max 100 | Individual-only |
| Suffix | ApiSelectV2 (SUFFIX) | "Select suffix" | — | Individual-only |
| Nickname | text | "Nickname" | max 200 | |
| DisplayName | text | "Auto-generated from name" | max 200 | Auto-fill on blur if empty |
| DOB | datepicker | "Select date" | past date | Individual-only |
| DOW | datepicker | "Select date" | past date | Individual-only |
| Gender | ApiSelectV2 (Gender) | "Select gender" | required if Indiv | Individual-only |
| Language | ApiSelectV2 (Language) | "Select language" | — | |
| Occupation | ApiSelectV2 (Occupation) | "Select occupation" | — | |
| EmployerOrganization | text | "Employer name" | max 150 | |
| JobTitle | text | "Job title" | max 150 | |
| ContactSource | ApiSelectV2 (ContactSource) | "Select source" | — | |
| AssignedStaff | ApiSelectV2 (User, filtered by role=Staff) | "Select staff" | — | |
| ContactStatus | ApiSelectV2 (CONTACTSTATUS) | "Select status" | — | Default: Active |
| ProfileImage | file-upload (drag & drop, image/*) | "JPG, PNG up to 5MB" | max 5MB, image | Uses existing UpdateContactProfilePhoto mutation |
| Notes | textarea (full-width, rows=3) | "Any additional notes..." | — | |

**Field Widget Mapping — Section 2 (Contact Information):**

*Sub-section A — Phone Numbers* (`fa-phone`; repeatable row; "+ Add Phone Number" button)
| Per-row field | Widget | Notes |
|--------------|--------|-------|
| PhoneType | ApiSelectV2 (PHONETYPE) | Mobile/Home/Work/Fax |
| Country Code | ApiSelectV2 (Country, show STD code) | e.g., +91, +1, +44 |
| PhoneNumber | text (tel) | max 100 |
| IsPrimary | radio (name="primaryPhone" — exclusive across all rows) | First row pre-checked |
| IsWhatsapp | checkbox | — |
| Remove | icon-button (fa-trash-alt, danger) | Removes row |

*Sub-section B — Email Addresses* (`fa-envelope`; repeatable row; "+ Add Email Address")
| Per-row field | Widget | Notes |
|--------------|--------|-------|
| EmailType | ApiSelectV2 (EMAILTYPE) | Personal/Work/Other |
| EmailAddress | email | max 100, RFC validation |
| IsPrimary | radio (name="primaryEmail", exclusive) | First pre-checked |
| Remove | icon-button | |

*Sub-section C — Social Links* (`fa-share-alt`; repeatable row; "+ Add Social Link")
| Per-row field | Widget | Notes |
|--------------|--------|-------|
| SocialType | ApiSelectV2 (SOCIALTYPE) | FB/X/LinkedIn/IG/YouTube/Website |
| LinkUrl | url (type="url") | max 1000, https validation |
| Remove | icon-button | |

**Field Widget Mapping — Section 3 (Address):**

Repeatable blocks ("Address #1", "Address #2"...) with header + remove button. Each block is a 2-column grid:

| Field | Widget | Notes |
|-------|--------|-------|
| AddressType | ApiSelectV2 (ADDRESSTYPE) | Home/Work/Mailing/Other |
| AddressLine1 | text | required, max 1000 |
| AddressLine2–4 | text | max 1000 each |
| Country | ApiSelectV2 (Country) | required; triggers State reload |
| State | ApiSelectV2 (State, filter by CountryId) | onChange → triggers District |
| District | ApiSelectV2 (District, filter by StateId) | → City |
| City | ApiSelectV2 (City, filter by DistrictId) | → Locality |
| Locality | ApiSelectV2 (Locality, filter by CityId) | → Pincode |
| Pincode | ApiSelectV2 (Pincode, filter by LocalityId) | — |

**Cascade implementation**: each dropdown's `onChange` clears + re-queries downstream dropdowns. Use existing cascading-select pattern if present in codebase, else build a `CascadingAddressFields` sub-component.

**Field Widget Mapping — Section 4 (Communication Preferences):**

| Field | Widget | Notes |
|-------|--------|-------|
| PreferredCommunication | ApiSelectV2 (PREFERREDCOMMUNICATION) | Email/Phone/SMS/WhatsApp/Postal |
| EmailOptInDate | datepicker | — |
| EmailOptOutDate | datepicker | — |
| DoNotEmail / Phone / SMS / Postal | 4× toggle-switch (single row, full-width container) | Labels inline |

**Field Widget Mapping — Section 5 (Family & Relationships):**

Part A — Family:
| Field | Widget | Notes |
|-------|--------|-------|
| Family | ApiSelectV2 (Family) + search | Options: FAM-001, FAM-002... |
| IsFamilyHead | checkbox | Right col |
| — | Button "Create New Family" (dashed) | Toggles inline form |

Inline "Create New Family" (hidden, teal bg):
| Field | Widget |
|-------|--------|
| FamilyCode | text (placeholder "Auto-generated") |
| FamilyName | text |
| Address | text (full-width) |

Part B — Quick Relationship Mini-Grid (repeatable rows):
| Per-row | Widget |
|---------|--------|
| RelatedContact | ApiSelectV2 (Contact, exclude self) + search |
| RelationType | ApiSelectV2 (RELATIONTYPE) |
| StartDate | datepicker |
| Remove | icon-button |

**Field Widget Mapping — Section 6 (Org Unit Assignment):**

Repeatable rows (mapped to `ContactDonationPurpose` today — see ⑫ ISSUE-1):
| Per-row | Widget |
|---------|--------|
| OrgUnit | ApiSelectV2 (OrganizationalUnit) |
| Currency | ApiSelectV2 (Currency, max-width 130px) |
| ConfiguredAmount | number (max-width 140px, step 0.01) |
| PledgeAmount | number (max-width 140px, step 0.01) |
| Remove | icon-button |

**Field Widget Mapping — Section 7 (Contact Types):**

Visual card-selector (custom widget; NOT standard multi-select):
- Layout: flex-wrap of 7 `.contact-type-tag` cards
- Each card contains hidden checkbox; clicking toggles `.selected` class (teal border + bg)
- Selected card shows auto-assigned date ("Assigned: 2026-04-19")
- Binds to `ContactTypeAssignment[]` child collection

Options (seeded): Donor, Volunteer, Member, Prospect, Board Member, Staff, Ambassador.

**Field Widget Mapping — Section 8 (Custom Fields):**

| Field | Widget | JSON key |
|-------|--------|----------|
| Anniversary Date | datepicker | anniversaryDate |
| Referred By | text | referredBy |
| Preferred Contact Time | select (Morning/Afternoon/Evening) | preferredContactTime |
| Tax ID Number | text (placeholder "Tax ID / PAN") | taxIdNumber |

Stored in `Contact.CustomFields` JSON blob.

---

#### LAYOUT 2: DETAIL (mode=read) — DIFFERENT UI from the form

> This is a **completely different UI** from the form. DO NOT render a disabled form.
> 2-column layout: **Left sidebar 340px (sticky)** + **Right content column (flex-1)**.
> Scroll within right column; left sidebar stays fixed on desktop.

**Page Header** (FlowFormPageHeader):
- Back arrow → list
- Title: `{DisplayName}` + inline `{ContactCode}` (smaller, secondary color)
- Under title: contact-type pill badges (donor green, volunteer purple, member blue, organization orange)
- Right actions: Edit (outline, → `?mode=edit&id=X`) · Send Email (primary) · More dropdown (Merge · Delete danger · Export · Print)

**Page Layout:**

| Column | Width | Sticky | Content |
|--------|-------|--------|---------|
| Left | 340px | Yes (sticky top 1.5rem, desktop) | 5 stacked cards |
| Right | flex: 1 | No | Engagement banner + Tabbed card + Org Units table (below tabs) |

---

**LEFT COLUMN CARDS** (in order):

| # | Card Title | Header Icon | Content |
|---|-----------|-------------|---------|
| 1 | — (headerless Profile card) | — | 80px circular avatar (initials, accent teal bg) · Name (centered, bold 1.125rem) · Job+Org line · Title line · DIVIDER · Engagement ring (SVG 100px, score overlay, green stroke) + label "Highly Engaged" · 5 score-factor bars (Recency 95 / Frequency 88 / Monetary 90 / Communication 85 / Events 75) |
| 2 | Personal Information | fa-user | Key-value list: Prefix · DOB+Age · Gender · Language · Occupation · Status (green dot + Active) · Deceased (Yes/No) · Contact Source · Staff Assigned |
| 3 | Tags | fa-tags | Tag pill badges (teal bg) + dashed "+ Add Tag" button inline |
| 4 | Communication Preferences | fa-sliders | Key-value list: Preferred Channel (fa-envelope + Email) · Do Not Email (X green = not opted out) · Do Not Phone (X green) · Do Not SMS (X green) · Do Not Postal (✓ red = opted out) · Email Opt-In date. **NOTE**: inverted color logic — `pref-cross` green = good, `pref-check` red = opted-out |
| 5 | Custom Fields | fa-puzzle-piece | Key-value list: Anniversary Date · Referred By · Notes (small, right-aligned, max 180px) |

---

**RIGHT COLUMN — 3 stacked blocks:**

**Block 1 — Engagement Score Banner Card** (full-width, above tabs)

Header row:
- Left: SVG gauge (90px) with score "96/100" · level badge "Highly Engaged" (green) · percentile "Top 2% of all contacts" · trend "+3 vs last month" (green fa-arrow-up)
- Right: "How is this calculated?" toggle button (fa-info-circle)

**Expandable Formula Panel** (collapsed default, smooth max-height expand):
Three sub-sections:

1. **Factor Breakdown Table** (icon: fa-chart-bar)
   Columns: Factor · Raw Score · Weight · Contribution · How It Works
   7 rows (with progress bar per factor):

   | Factor | Raw | Weight | Contribution | Formula (mono) |
   |--------|-----|--------|-------------|----------------|
   | Donation Recency | 98/100 | 25% | 24.5 pts | max(0, 100 - (days_since_last / 3.65)) |
   | Donation Frequency | 95/100 | 20% | 19.0 pts | min(100, (donations_per_year / 12) × 100) |
   | Donation Monetary | 92/100 | 20% | 18.4 pts | percentile_rank × 100 |
   | Email Engagement | 95/100 | 15% | 14.3 pts | (open × 0.6 + click × 0.4) × 100 |
   | Event Participation | 88/100 | 10% | 8.8 pts | (attended / invited) × 100 |
   | Communication Response | 90/100 | 5% | 4.5 pts | (replied / received) × 100 |
   | Volunteer Activity | 85/100 | 5% | 4.3 pts | min(100, (hours / 48) × 100) |

2. **Composite Calculation Block** (icon: fa-calculator)
   Monospace step-by-step:
   - Weighted Sum = sum(factor × weight) = 93.70
   - Loyalty Bonus = min(5, years × 1) = +3.00
   - Final Score = min(100, round(93.70 + 3.00)) = **96**

3. **Quick Reference Table** (icon: fa-book-open)
   What 100 vs 0 means per factor + Loyalty Bonus explanation + Neutral handling note + "weights are admin-configurable".

**SERVICE_PLACEHOLDER**: All engagement score values shown are stubbed. See ⑫ ISSUE-3.

---

**Block 2 — Tabbed Card** (main content, white card with tab bar at top)

**Tab Bar** (6 tabs, horizontally scrollable):

| # | Tab | Icon | Default |
|---|-----|------|---------|
| 1 | Timeline | fa-stream | ACTIVE |
| 2 | Donations | fa-hand-holding-dollar | — |
| 3 | Relationships | fa-link | — |
| 4 | Communication | fa-envelope | — |
| 5 | Events | fa-calendar | — |
| 6 | Documents | fa-folder-open | — |

**Tab 1 — Timeline (default active):**

Filter chips row above list (single-select): All · Donations · Emails · Calls · Events · Notes · Volunteer

Vertical timeline (`.timeline-list` with left border). Each item:
- Colored dot indicator (left, overlapping line) — color by type
- Date (small, secondary)
- Bold action + details
- Linked IDs (Receipt #, Event name) navigate to their detail pages

Dot colors:
- Donation: green
- Email: blue
- Phone: orange
- Event: purple
- Note: gray
- Tag: teal
- Volunteer: purple

"Load More" button (dashed, full-width) at bottom.

**SERVICE_PLACEHOLDER**: Timeline aggregation requires a cross-entity event stream query (donations + emails + calls + events + notes + tags + volunteer hours). See ⑫ ISSUE-4.

**Tab 2 — Donations:**

Summary mini-stat cards (responsive auto-fit grid, minmax 140px):
| # | Stat | Value type |
|---|------|-----------|
| 1 | Total Given | currency |
| 2 | This Year | currency + "(N donations)" |
| 3 | Avg Donation | currency |
| 4 | First Gift | date |
| 5 | Largest Gift | currency |
| 6 | Recurring | "$X/month" + Active badge |

Table: Date · Amount · Purpose · Mode · Receipt # (link → `/fundraising/donation-detail?id=X`) · Status (badge). Source: existing `GlobalDonations` filtered by `ContactId`.

**Tab 3 — Relationships:**

Header: "+ Add Relationship" button (top-right).
Table: Contact (linked) · Relationship · Since · Status. Source: `ContactRelationships` (both directions unified).

**Tab 4 — Communication:**

Table: Date · Type · Subject/Message · Status (Sent/Delivered/Opened/Clicked/Bounced badges). Source: `EmailSendQueue` + future SMS/WhatsApp logs.

**Tab 5 — Events:**

Table: Event (linked) · Date · Status (Attended/Volunteered/Registered/No-show/Cancelled) · Donation Linked. Source: `EventAttendance` (cross-module).

**Tab 6 — Documents:**

Table: Document · Type · Date · Size. Source: `ContactDocuments` (if exists, else SERVICE_PLACEHOLDER).

---

**Block 3 — Contact Organizational Units table** (below tabbed card, full right-column width, always visible)

Header: fa-sitemap + "Contact Organizational Units"
Table columns: Org Unit · Configured Amount · Total Donated · Pledge · Count
Source: `ContactDonationPurpose` (aggregated from donations). See ⑫ ISSUE-1.

---

### Page Widgets & Summary Cards

**Widgets**: NONE (mockup list page has no KPI cards above grid)

**Grid Layout Variant**: `grid-only` → FE Dev uses **Variant A** (`<FlowDataTable>` with internal header — no `<ScreenHeader>`).

**Summary GQL Query**: ADD `GetContactSummary` for quick-filter chip badges (count per chip: Donors, Volunteers, Members, Organizations, Inactive). Returns `ContactSummaryDto`:
```
{ total: int, active: int, donors: int, volunteers: int, members: int, organizations: int, inactive: int }
```
Used to show counts in filter chip labels ("Donors (1,234)"). Not a widget row.

### Grid Aggregation Columns

| Column | Description | Implementation |
|--------|-------------|----------------|
| Score | Engagement score per row | SERVICE_PLACEHOLDER (stub 0–100 value from denormalized `EngagementScore` field if added; else static) |
| Last Donation | Date + latest amount | LINQ subquery joining latest `GlobalDonation` by `ContactId` |
| Tags | Aggregated tag badges | `ContactTags` → `Tag` join, project as `TagDto[]` |
| Type (multi-badge) | Base type + assigned types | `ContactBaseType.DataName` + `ContactTypeAssignments[].ContactType.ContactTypeName` |
| Primary Email / Phone | From child collections | Subquery: IsPrimary=true |

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User sees FlowDataTable grid → clicks "+New Contact" → URL: `/crm/contact/allcontacts?mode=new`
   → FORM LAYOUT loads with empty 8-section accordion (1 & 2 expanded)
2. User selects ContactBaseType radio → Individual/Organization fields show/hide; `<h1>` retitles
3. User fills form (basic info, phones, addresses, etc.) → clicks Save → API creates record
   → URL redirects to `/crm/contact/allcontacts?mode=read&id={newId}`
   → DETAIL LAYOUT loads (sidebar + tabs — completely different UI)
4. User clicks Edit on detail → URL: `?mode=edit&id=X` → FORM LAYOUT pre-filled
5. User edits → Save → back to DETAIL
6. User clicks Save & Add Another → creates → resets form with same base-type → stays in `?mode=new`
7. User clicks a row in grid → `?mode=read&id=X` → DETAIL LAYOUT
8. Unsaved form → navigation → confirm dialog
9. Quick filter chips (All/Donors/...) update grid filter state (URL: `?filter=donors`)
10. Advanced filters open panel → Apply → filters grid; Clear → resets all
11. Row selection → bulk action bar appears; actions operate on selected IDs

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity (SavedFilter FLOW) to Contact. Plus ALIGN-specific notes.

**Canonical Reference**: SavedFilter (FLOW, completed 2026-04-19). Structurally similar: full-page view, Zustand store, nested child collections. Differences: Contact has 8 form sections vs SavedFilter's 3; Contact has a completely custom DETAIL layout (sidebar + tabs) vs SavedFilter's 2-pane form+preview.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | Contact | Entity/class name |
| savedFilter | contact | Variable/field names |
| SavedFilterId | ContactId | PK field |
| SavedFilters | Contacts | Table name, collection names |
| saved-filter | contact | FE route segment (existing: `allcontacts/`), file-name kebab |
| savedfilter | contact | FE folder, import paths |
| SAVEDFILTER | CONTACT | Grid code, menu code |
| notify | corg | DB schema |
| Notify | Contact | Backend group prefix (Models group = `ContactModels`) |
| NotifyModels | ContactModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_CONTACT | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/contact/allcontacts | FE route path (FULL) |
| notify-service | contact-service | FE service folder (existing) |

**ALIGN overrides**:
- Backend group folder is `ContactBusiness` (not `CorgBusiness`) — all Commands/Queries live under `Base.Application/Business/ContactBusiness/Contacts/`.
- Schemas path: `Base.Application/Schemas/ContactSchemas/ContactSchemas.cs` (existing — extend only).
- Commands subfolder is `Contacts/Commands/` (nested) — existing convention, DO NOT flatten.
- API endpoint namespace: `Base.API.EndPoints.Contact.Mutations/.Queries` (singular, not plural).

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> ALIGN scope — mostly MODIFY existing files + ADD summary query + ADD detail-layout FE components. Not a full rebuild.

### Backend Files — MODIFY (existing)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Contact entity | Pss2.0_Backend/Base.Domain/Models/ContactModels/Contact.cs | No schema changes (no migration) |
| 2 | EF Config | Pss2.0_Backend/Base.Infrastructure/Data/Configurations/ContactConfigurations/ContactConfiguration.cs | Verify indexes on ContactCode, CompanyId, FamilyId, ContactBaseTypeId; no change expected |
| 3 | Schemas | Pss2.0_Backend/Base.Application/Schemas/ContactSchemas/ContactSchemas.cs | **EXTEND** ContactDto: add `contactTags[]`, `contactTypeAssignments[]`, `contactRelationships[]`, `contactSocialLinks[]`, `contactUPIDetails[]`. Add `ContactSummaryDto`. Add list-projection fields: primaryPhone, primaryEmail, engagementScore (stub), tagList, contactTypeList, contactBaseTypeCode |
| 4 | CreateContact | Pss2.0_Backend/Base.Application/Business/ContactBusiness/Contacts/Commands/CreateContact.cs | **MODIFY** — persist new nested children (SocialLink / Relationship / TypeAssignment / Tag / OrgUnitAssignment-via-DonationPurpose / UPI) |
| 5 | UpdateContact | …/UpdateContact.cs | **MODIFY** — sync all nested children (diff-update pattern) |
| 6 | GetContact (List) | Pss2.0_Backend/Base.Application/Business/ContactBusiness/Contacts/Queries/GetContact.cs | **MODIFY** — add projection for primaryPhone/primaryEmail (subquery), contactTypeList (ContactTypeAssignments + ContactBaseType), tagList (ContactTags), engagementScore (stub 0), lastDonationDate+amount |
| 7 | GetContactById | …/Queries/GetContactById.cs | **MODIFY** — include all 5 missing child collections (SocialLinks, TypeAssignments, Relationships, Tags, UPIDetails) |
| 8 | Contact Queries endpoint | Pss2.0_Backend/Base.API/EndPoints/Contact/Queries/ContactQueries.cs | **MODIFY** — register `getContactSummary` field |
| 9 | Contact Mutations endpoint | …/Mutations/ContactMutations.cs | No change |

### Backend Files — CREATE (new)

| # | File | Path |
|---|------|------|
| 1 | GetContactSummary query | Pss2.0_Backend/Base.Application/Business/ContactBusiness/Contacts/Queries/GetContactSummary.cs |
| 2 | Optional: SERVICE_PLACEHOLDER stubs | — (no separate files — placeholder logic lives in existing handlers/FE handlers) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | Already has Contact DbSet — verify no new additions needed |
| 2 | ContactDbContext.cs | Already has Contact DbSet — no change |
| 3 | DecoratorProperties.cs | Already has DecoratorContactModules — no change |
| 4 | ContactMappings.cs | **MODIFY** — extend Mapster configs for 5 new child DTOs + ContactSummaryDto |

### Frontend Files — MODIFY (existing, extend to match mockup)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Contact DTO | Pss2.0_Frontend/src/domain/entities/contact-service/ContactDto.ts | **EXTEND** — add `contactSummaryDto` type, list-projection fields (primaryPhone/Email/engagementScore/tagList/contactTypeList/contactBaseTypeCode), confirm child DTO imports |
| 2 | Contact Query | Pss2.0_Frontend/src/infrastructure/gql-queries/contact-queries/ContactQuery.ts | **EXTEND** — add `GET_CONTACT_SUMMARY_QUERY`; add child collections to `CONTACT_BY_ID_QUERY` (addresses/phones/emails/social/relationships/typeAssignments/tags/upi); add list-projection fields to `CONTACTS_QUERY`; remove duplicate `isFamilyHead` (query cleanup) |
| 3 | Contact Mutation | Pss2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/ContactMutation.ts | **EXTEND** — update mutation inputs to include nested children on create+update (socialLinks, relationships, typeAssignments, tags, orgUnitAssignments) |
| 4 | Page shell | Pss2.0_Frontend/src/presentation/pages/crm/contact/contact.tsx | No change (capability check already correct) |
| 5 | index.tsx (FLOW router) | src/presentation/components/page-components/crm/contact/contact/index.tsx | Verify ?mode routing; no change |
| 6 | index-page.tsx (grid) | …/contact/index-page.tsx | **REBUILD** — match mockup: filter chips row, advanced filter panel (toggle), column configurator, bulk actions bar. Keep `<FlowDataTable gridCode="CONTACT">` as the core. Variant A (no ScreenHeader) |
| 7 | view-page.tsx | …/contact/view-page.tsx | **REBUILD** — switch between FORM (mode=new/edit) and DETAIL (mode=read) layouts. FORM: 8-section accordion (restructure from existing 5 tabs). DETAIL: new 2-column layout with sidebar + tabs |
| 8 | contact-store.ts (Zustand) | src/application/stores/contact-stores/contact-store.ts | **EXTEND** — add state for: quickFilterChip, advancedFilterOpen, advancedFilters object, bulkSelectedIds[], columnConfig (visible columns), activeDetailTab, engagementScoreFormulaOpen. Keep 6 child sub-stores as-is |
| 9 | parent-form.tsx | src/presentation/components/page-components/crm/contact/contact/parent-form.tsx | **REBUILD** to 8-section accordion (from existing tabbed layout); keep form-fields sub-components |
| 10 | entity-operations | src/application/configs/data-table-configs/contact-service-entity-operations.ts | Verify gridCode=CONTACT wiring; add Summary query reference if needed |
| 11 | Child-grid tab components | contact-phonenumber.tsx / -emailaddress.tsx / -address.tsx / -relationship.tsx / -sociallink.tsx | **MODIFY** to match mockup sub-section UIs inside Section 2/3/5 accordions |
| 12 | contact-types-tab.tsx | …/contact-types-tab.tsx | **REBUILD** as card-selector widget (flex-wrap of 7 visual cards with embedded checkboxes) |
| 13 | Form-fields sub-components | …/form-fields/CommonFormFields.tsx, IndividualFormFields.tsx, OrganizationFormFields.tsx, HouseholdFormFields.tsx, CommunicationDetailsSection.tsx | **MODIFY** to match Section 1 field list from mockup |
| 14 | contact-wizard-widget.tsx | …/contact-wizard-widget.tsx | **REMOVE or REPURPOSE** — mockup uses accordion (not wizard); decide if wizard is optional alt UX or deprecate |
| 15 | Route page | src/app/[lang]/crm/contact/allcontacts/page.tsx | No change (already correct) |

### Frontend Files — CREATE (new for mockup alignment)

| # | File | Path |
|---|------|------|
| 1 | detail-page.tsx | src/presentation/components/page-components/crm/contact/contact/detail-page.tsx (render DETAIL layout — sidebar + tabs + engagement card + org-units) |
| 2 | contact-sidebar.tsx | …/contact/detail/contact-sidebar.tsx (profile card + engagement ring + 5 stacked info cards) |
| 3 | engagement-score-card.tsx | …/contact/detail/engagement-score-card.tsx (banner with score + expandable formula panel) |
| 4 | engagement-score-ring.tsx | …/contact/detail/engagement-score-ring.tsx (SVG circular gauge) |
| 5 | score-factor-bars.tsx | …/contact/detail/score-factor-bars.tsx (5-bar breakdown for sidebar) |
| 6 | timeline-tab.tsx | …/contact/detail/tabs/timeline-tab.tsx (filter chips + vertical timeline) |
| 7 | donations-tab.tsx | …/contact/detail/tabs/donations-tab.tsx (6 mini stats + table) |
| 8 | relationships-tab.tsx | …/contact/detail/tabs/relationships-tab.tsx (table + add button) |
| 9 | communication-tab.tsx | …/contact/detail/tabs/communication-tab.tsx (email activity table) |
| 10 | events-tab.tsx | …/contact/detail/tabs/events-tab.tsx |
| 11 | documents-tab.tsx | …/contact/detail/tabs/documents-tab.tsx |
| 12 | org-units-table.tsx | …/contact/detail/org-units-table.tsx (below tabs, full-width) |
| 13 | index-page components: filter-chips-bar.tsx, advanced-filter-panel.tsx, bulk-actions-bar.tsx, column-configurator-panel.tsx | …/contact/list/*.tsx |
| 14 | Form components: accordion-section.tsx (if no shared comp), cascading-address-fields.tsx, contact-type-card-selector.tsx, social-link-row.tsx, inline-new-family-form.tsx, relationship-mini-grid.tsx, org-unit-assignment-row.tsx, custom-fields-section.tsx | …/contact/form/*.tsx |
| 15 | Cell renderers | src/presentation/components/shared/cell-renderers/contact-avatar-name.tsx, score-circle.tsx, last-donation-date-amount.tsx, contact-type-badge-list.tsx, tag-badge-list-overflow.tsx, pref-icon.tsx (green X / red ✓) — verify against registry first |
| 16 | GET_CONTACT_SUMMARY_QUERY | Added inline to ContactQuery.ts (not a new file) |

### Frontend Files — DELETE

> **None.** There are no legacy `contactcreate/`, `contactupdate/`, `contactdetail/` route folders — the FLOW pattern was already adopted. Do not delete the 11 standalone child-table admin routes (contactaddress/contactphonenumber/etc.) — they are separate admin screens for bulk maintenance, out of scope here.

### Frontend Wiring Updates

| # | File | Action |
|---|------|--------|
| 1 | contact-service-entity-operations.ts | Verify CONTACT gridCode mapping; add GET_CONTACT_SUMMARY_QUERY reference if needed |
| 2 | shared-cell-renderers barrel (index.ts) | Export new renderers (contact-avatar-name, score-circle, last-donation-date-amount, contact-type-badge-list, tag-badge-list-overflow, pref-icon) |
| 3 | dgf-column-types (advanced-column / basic-column / flow-column registries) | Register 6 new column-type keys (3 registries × 6 = 18 line additions — follow ContactType #19 precedent pattern) |
| 4 | dgf-widgets index (if any new widget appears) | No changes — no widgets |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase.

```
---CONFIG-START---
Scope: ALIGN

MenuName: All Contacts
MenuCode: CONTACT
ParentMenu: CRM_CONTACT
Module: CRM
MenuUrl: crm/contact/allcontacts
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: CONTACT
---CONFIG-END---
```

> Notes:
> - Menu + Capabilities + Grid are almost certainly already seeded in the DB — build-screen should **verify** (not re-insert) via ON CONFLICT DO NOTHING. If seed script exists for CONTACT grid today, UPDATE its column list to match the 8 columns in Section ⑥.
> - GridFormSchema: SKIP (FLOW). No RJSF schema generated.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query root: `Contact` endpoint group (existing)
- Mutation root: `Contact` endpoint group (existing)

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| getContacts | PaginatedApiResponse<IEnumerable<ContactResponseDto>> | gridFeatureRequest (searchText, pageNo, pageSize, sortField, sortDir, quickFilter, advancedFilters) |
| getContactById | BaseApiResponse<ContactDto> | contactId: Int |
| getContactByCode | BaseApiResponse<ContactDto> | contactCode: String |
| **getContactSummary** (NEW) | BaseApiResponse<ContactSummaryDto> | — (tenant-scoped via HttpContext) |
| exportContacts | — | existing |

**Mutations** (existing — no new ones needed):

| GQL Field | Input | Returns |
|-----------|-------|---------|
| createContact | ContactRequestDto (extended with nested social/relationships/typeAssignments/tags/orgUnits) | BaseApiResponse<ContactRequestDto> |
| updateContact | ContactRequestDto | BaseApiResponse<ContactRequestDto> |
| deleteContact | contactId: Int | BaseApiResponse<ContactRequestDto> |
| activateDeactivateContact | contactId: Int | BaseApiResponse<ContactRequestDto> |
| updateContactProfilePhoto | file upload | BaseApiResponse<ContactProfileDto> |
| createFamilyMember | CreateFamilyMemberRequestDto | BaseApiResponse<CreateFamilyMemberResponseDto> |
| setContactAsFamilyHead | contactId: Int | BaseApiResponse<SetContactAsFamilyHeadResult> |

**Response DTO Fields — `ContactResponseDto` (list projection, extended):**

| Field | Type | Notes |
|-------|------|-------|
| contactId | number | PK |
| contactCode | string | |
| contactBaseTypeId | number | |
| contactBaseTypeCode | string | NEW — "INDIVIDUAL" / "ORGANIZATION" / "HOUSEHOLD" for FE filter |
| displayName | string | |
| organizationName | string? | |
| primaryEmail | string? | NEW — from ContactEmailAddresses IsPrimary=true |
| primaryPhone | string? | NEW — formatted "STD + number" |
| engagementScore | number? | NEW — stub 0–100 (SERVICE_PLACEHOLDER) |
| lastDonationDate | string? (ISO date) | |
| lastDonationAmount | number? | NEW — join latest GlobalDonation by ContactId |
| contactTypeList | [{ id, name, color }] | NEW — base type + ContactTypeAssignments |
| tagList | [{ id, name, color }] | NEW — ContactTags + Tag |
| imagePath | string? | |
| isActive | boolean | |
| primaryCountry | { countryId, countryName } | |
| contactStatus | { id, dataName } | |
| family | { familyId, familyCode, familyName } | |
| isFamilyHead | boolean | (remove duplicate in query) |
| dropdownLabel | string | Existing |

**Response DTO Fields — `ContactDto` (detail, extended):**

Inherits from `ContactResponseDto` + adds (existing): contactAddresses[], contactEmailAddresses[], contactPhoneNumbers[], contactDonationPurposes[].
**EXTEND with:**
- contactSocialLinks[] (new)
- contactTypeAssignments[] (new)
- contactRelationships[] (new)
- contactTags[] (new)
- contactUPIDetails[] (new)
- customFieldsParsed (JSON-decoded `{ anniversaryDate, referredBy, preferredContactTime, taxIdNumber }`)

**Response DTO Fields — `ContactSummaryDto` (NEW):**

| Field | Type | Source |
|-------|------|--------|
| total | number | COUNT(Contacts) where CompanyId + IsDeleted=false |
| active | number | COUNT where IsActive=true |
| inactive | number | COUNT where IsActive=false |
| donors | number | COUNT where ContactTypeAssignments contains "Donor" |
| volunteers | number | COUNT where ContactTypeAssignments contains "Volunteer" |
| members | number | COUNT where ContactTypeAssignments contains "Member" |
| organizations | number | COUNT where ContactBaseType.DataName="Organization" |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors
- [ ] `pnpm dev` — page loads at `/[lang]/crm/contact/allcontacts`
- [ ] `pnpm tsc --noEmit` — 0 new Contact errors (pre-existing errors from Tags #22 or overview may remain)
- [ ] UI uniformity grep (0 matches each): inline hex (`#[0-9a-f]{6}` outside tokens), inline pixel spacing (`[0-9]px`), raw "Loading…" string, `<LoadingSpinner>` component (prefer Skeleton), native `<h1–h6>` (prefer `<ScreenHeader>`/Typography)
- [ ] Variant A confirmed — NO `<ScreenHeader>` in index-page.tsx (widgets would require Variant B, but mockup has none)

**Functional Verification (Full E2E — MANDATORY):**

*Grid:*
- [ ] 8 columns render correctly with data (Code, Name+Avatar, Type badges, Email, Phone, Score, Last Donation, Tags)
- [ ] Default sort: Contact Code asc
- [ ] Search filters by: name, email, phone, code (single input)
- [ ] 6 quick filter chips work (All/Donors/Volunteers/Members/Organizations/Inactive); exactly one active at a time; chip label shows count from `getContactSummary`
- [ ] Advanced Filter Panel toggles open; Apply filters grid; Clear resets
- [ ] Column Configurator shows/hides columns; persists in session state
- [ ] Bulk selection: row checkboxes + select-all; Bulk Actions Bar appears; operates on selected IDs
- [ ] Pagination: 10/25/50/100 page sizes; Prev/Next + numbered pages; "Showing X–Y of Z"

*FORM (mode=new / mode=edit):*
- [ ] Page header: Back, Save, Save & Add Another (new only), Cancel
- [ ] 8 accordion sections render in order; Sections 1 & 2 expanded, 3–8 collapsed by default
- [ ] Section 1: ContactBaseType radio toggles show/hide (Individual vs Organization); page `<h1>` updates accordingly
- [ ] All 20+ fields in Section 1 bind correctly; FK dropdowns load via ApiSelectV2
- [ ] Profile photo upload works (drag & drop + click); max 5MB image validation
- [ ] Section 2: 3 sub-sections (phones/emails/social) — each repeatable with +Add + remove; IsPrimary radio exclusive per phone/email set; first row pre-checked
- [ ] Section 3: Address blocks repeatable (+Add Address); 5-level cascade Country→State→District→City→Locality→Pincode works (each triggers next reload)
- [ ] Section 4: Communication preferences — 4 toggle switches + 2 date pickers + preferred channel select
- [ ] Section 5: Family select OR "Create New Family" inline form toggle; Relationships mini-grid add/remove
- [ ] Section 6: Org Unit Assignments repeatable rows (OrgUnit + Currency + Configured + Pledge) — persists via ContactDonationPurpose
- [ ] Section 7: ContactTypes card-selector — 7 visual cards, multi-select, each shows assigned date when checked
- [ ] Section 8: Custom Fields (4 inputs) — persists as JSON on Contact.CustomFields
- [ ] Save creates contact → URL redirects to `?mode=read&id={newId}`
- [ ] Save & Add Another → creates → resets form → stays in ?mode=new
- [ ] Unsaved-changes dialog triggers on navigate with dirty form

*DETAIL (mode=read):*
- [ ] 2-column layout: left 340px sticky + right flex-1
- [ ] Left sidebar: Profile card (avatar + engagement ring + 5 score-bars), Personal Info, Tags, Comm Prefs, Custom Fields
- [ ] `pref-cross` green X = not opted out; `pref-check` red ✓ = opted out (inverted logic)
- [ ] Right banner: Engagement score card with "How is this calculated?" toggle; expanded panel shows 7-factor table + composite calc + quick ref
- [ ] Tab bar: 6 tabs, Timeline active by default
- [ ] Timeline tab: 7 internal filter chips; vertical timeline list; Load More button
- [ ] Donations tab: 6 mini-stats + table with receipt links; data sourced from GlobalDonations filtered by contactId
- [ ] Relationships tab: table + Add Relationship button
- [ ] Communication tab: email activity table
- [ ] Events tab: event participation table
- [ ] Documents tab: document list (or placeholder if no docs entity)
- [ ] Org Units table (below tabs): 5 columns, always visible
- [ ] Edit button on detail → switches to `?mode=edit&id=X` with FORM pre-filled
- [ ] Header actions: Send Email (placeholder toast), More dropdown (Merge → navigates to #21, Delete, Export, Print — all placeholders except Delete)

*Permissions:*
- [ ] BUSINESSADMIN sees all actions (new, edit, delete, toggle, import, export)
- [ ] Capability check at page level via `useAccessCapability({ menuCode: "CONTACT" })` — READ denies render

**DB Seed Verification:**
- [ ] Menu "All Contacts" visible in CRM sidebar under Contacts group
- [ ] Grid columns match the 8 mockup columns (update seed if mismatch)
- [ ] (FLOW — no GridFormSchema)
- [ ] All 11 MasterData TypeCodes exist with expected rows (CONTACTBASETYPE, PREFIX, SUFFIX, ORGANIZATIONTYPE, CONTACTSTATUS, PREFERREDCOMMUNICATION, PHONETYPE, EMAILTYPE, SOCIALTYPE, ADDRESSTYPE, RELATIONTYPE)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId IS on Contact entity** — pre-dates FLOW convention. DO NOT remove or assume HttpContext-only. Keep current scoping pattern intact.
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it. The existing grid seed likely exists; only update column list.
- **view-page.tsx handles ALL 3 modes** — FORM (new/edit) shares layout, DETAIL (read) is completely different UI.
- **Backend group is `ContactModels` / `ContactBusiness` / `ContactSchemas`** — NOT CorgModels/CorgBusiness. All namespaces use the singular "Contact" prefix.
- **API endpoint group is `Contact`** (singular) — `Base.API/EndPoints/Contact/Mutations/.Queries`.
- **ApiSelectV2 for MasterData** uses `GetMasterDatas(typeCode: "XXX")` — 11 different TypeCodes in this screen. Build a shared `MasterDataSelect typeCode={...}` wrapper to avoid repetition.
- **Address cascade is 5 levels deep** — implement as a reusable component. Existing form-fields components may already have partial cascade; verify before creating new.
- **Do NOT delete** the 11 standalone child-entity routes (`crm/contact/contactaddress/...`, etc.) — they are separate admin screens, out of scope.
- **For ALIGN scope**: only modify existing files where gaps exist. Do NOT regenerate working code. The FE/BE already have mature FLOW structure + Zustand store with 6 child sub-stores.
- **Mockup list is TABLE (not card-grid)** — do NOT stamp `displayMode: card-grid`. Grid-only layout, Variant A (no ScreenHeader).
- **Engagement score is entirely stub data** — see ISSUE-3 below.
- **CustomFields JSON encoding** — Section 8 persists 4 named keys. Use consistent snake_case vs camelCase across BE/FE (recommend camelCase: `anniversaryDate`, `referredBy`, `preferredContactTime`, `taxIdNumber`).
- **Tenant-scoping for Contact self-ref FK** (`ReferralContactId`, relationships, merge) — exclude self + filter by CompanyId.
- **Primary flag exclusivity** — phones and emails. Enforce on server during Create/Update: if a new row has IsPrimary=true, set all other rows of same type to false. FE should mirror this optimistically.

**Known Issues to FLAG as `ISSUE-N` in Section ⑬ (do NOT resolve in initial build):**

- **ISSUE-1** — **Org Unit Assignment is not a pure OrgUnit link**. The mockup's Section 6 shows OrgUnit + Currency + Configured + Pledge amounts. Today this maps to `ContactDonationPurpose` (purpose + currency + amounts) — close but not identical. Decision: (a) map Section 6 to `ContactDonationPurpose` as-is (accept semantic drift) and add an `OrganizationalUnitId` column later, OR (b) create a new `ContactOrgUnit` entity. **Recommend (a) for this session** — surface in UI as "Org Unit Assignment" with a note that data flows through ContactDonationPurpose. Plan (b) as a separate screen alignment.

- **ISSUE-2** — **Household fields are DTO-only**. `HouseholdName`, `HouseholdTypeId`, `NumberOfMembers`, `SpouseName` exist in `ContactRequestDto` but NOT on the `Contact` entity. If Household base-type is a real requirement, these need a migration. **Recommend** for this session: render the Household UI from the DTO fields, store in `CustomFields` JSON OR `Nickname`/etc. proxy, and flag the gap for a follow-up migration session.

- **ISSUE-3** — **Engagement score is unimplemented**. The mockup shows a detailed 7-factor score with formula. There is no aggregation job, no `EngagementScore` column, no ML model. SERVICE_PLACEHOLDER: stub `engagementScore = 0` on projection; show "Not Available" + learn-more tooltip on the UI if score is null. Detail page's expandable formula panel can show the static formula reference but with live values as `—`. Defer full implementation to AI Intelligence module (#90 Engagement Scoring).

- **ISSUE-4** — **Timeline aggregation across entities is complex**. Mockup timeline combines Donations + Emails + Calls + Events + Notes + Tags + Volunteer. No unified event-stream query exists. SERVICE_PLACEHOLDER: build Timeline tab with only the events that ARE queryable today (GlobalDonations by contactId + EmailSendQueue entries). Show placeholder cards for unimplemented types ("Call logging not yet available"). Defer full cross-entity stream to a future session.

- **ISSUE-5** — **"Create New Family" inline form** in Section 5 must call the `createFamilyMember` mutation (different from the main `createContact`). Existing mutation exists. Verify it handles standalone Family creation (not just assigning an existing one).

- **ISSUE-6** — **Merge/Duplicate detection navigation**. Header action "Merge" in detail page navigates to Duplicate Detection screen #21 (ALIGN scope, PARTIAL). #21 is not yet planned. Placeholder: navigate to `crm/maintenance/duplicatecontact?focusContactId=X` with a toast if target page is a stub.

- **ISSUE-7** — **Bulk Send Email**. Requires EmailSendJob + recipient set. Infrastructure exists (#25 Email Campaign), but bulk-send from Contact list is a new flow. SERVICE_PLACEHOLDER: show "Will send to N recipients" confirmation dialog + toast; wire to `sendBulkEmail` endpoint if exists, else toast only.

- **ISSUE-8** — **Advanced Filter: Tags multi-select**. Requires GET_TAGS query filtered to the current user's company. Tag #22 is COMPLETED — GQL exists. Verify `GetTags` signature accepts no args + returns TagResponseDto with `TagName` + `TagColor`.

- **ISSUE-9** — **Import/Export**. Existing `exportContacts` handler stubs 6 fields. Mockup Export button must emit all visible columns. Out of scope for this session? Flag as gap — recommend SERVICE_PLACEHOLDER toast for now and extend ExportContactDto in a follow-up.

- **ISSUE-10** — **Card Grid option**. Mockup uses table, but if users prefer card-grid for Contacts, the `profile` variant (from `.claude/feature-specs/card-grid.md`) is the right path. Build only `table` for this session; the `profile` variant would be a standalone feature-add later (first candidate: Staff #42 or Ambassador #67).

**Service Dependencies** (UI-only — no backend service implementation):

- **⚠ SERVICE_PLACEHOLDER (ISSUE-3)**: Engagement score values, factor breakdown, formula execution — full UI built; score values stub (0 or last-known cached). Handler uses toast + "Not yet available" state.
- **⚠ SERVICE_PLACEHOLDER (ISSUE-4)**: Timeline cross-entity event stream — full UI built; shows only donations + emails from existing queries.
- **⚠ SERVICE_PLACEHOLDER (ISSUE-7)**: Bulk Send Email from Contact list — UI + confirmation built; handler toast-only until bulk-send endpoint confirmed.
- **⚠ SERVICE_PLACEHOLDER**: Print (fa-print) header action — UI only; toast.
- **⚠ SERVICE_PLACEHOLDER**: Import CSV (top-right toolbar) — UI navigates to Contact Import #23 route (PARTIAL); screen is not fully aligned.
- **⚠ SERVICE_PLACEHOLDER (ISSUE-9)**: Export button full-column export — UI; backend extension deferred.
- **⚠ SERVICE_PLACEHOLDER**: Send Email / Phone / WhatsApp icons per-row quick actions (if mockup shows inline) — UI; handler toast.

Full UI must be built (buttons, forms, modals, panels, interactions, 8 sections, 6 tabs, all child grids). Only the handlers for external-service calls are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Plan 2026-04-19 | Med | Data model | OrgUnit Assignment maps to ContactDonationPurpose (semantic drift); new ContactOrgUnit entity pending | OPEN |
| ISSUE-2 | Plan 2026-04-19 | Med | Data model | Household fields (HouseholdName/TypeId/NumberOfMembers/SpouseName) are DTO-only, not on Contact entity | OPEN |
| ISSUE-3 | Plan 2026-04-19 | High | Feature | Engagement score is unimplemented — score, factor breakdown, formula all stubbed | OPEN |
| ISSUE-4 | Plan 2026-04-19 | High | Feature | Timeline cross-entity aggregation missing — build UI showing Donations+Emails only | OPEN |
| ISSUE-5 | Plan 2026-04-19 | Low | Integration | "Create New Family" inline form — verify createFamilyMember mutation works standalone | OPEN |
| ISSUE-6 | Plan 2026-04-19 | Low | Navigation | Merge action navigates to #21 (PARTIAL) — add ?focusContactId param handling | OPEN |
| ISSUE-7 | Plan 2026-04-19 | Med | Feature | Bulk Send Email from list — UI built, handler toast-only until bulk-send endpoint confirmed | OPEN |
| ISSUE-8 | Plan 2026-04-19 | Low | Integration | Advanced Filter Tags multi-select — verify GetTags signature returns TagColor | OPEN |
| ISSUE-9 | Plan 2026-04-19 | Med | Feature | Export button backend extension deferred — ExportContactDto is a 6-field stub | OPEN |
| ISSUE-10 | Plan 2026-04-19 | Info | Design | Card-grid `profile` variant option for Contacts — table for now, profile variant deferred | OPEN |
| ISSUE-11 | Session 1 2026-04-19 | High | UX | FORM layout not restructured to 8-section accordion. Existing 5-tab `ContactWizardWidget` path kept because accordion rewrite required simultaneous refactor of parent-form + 11 child sub-components + 6 Zustand sub-stores + `useSaveButtonState`/`useContactChildStores`/`useUnsavedChangesWarning` hook triad (~1200 LOC). DETAIL layout delivered; new `ContactTypeCardSelector` + `CascadingAddressFields` components already in place for follow-up pass. | OPEN |
| ISSUE-12 | Session 1 2026-04-19 | Med | Integration | List-page filter chips + advanced filter panel state captured in Zustand but NOT yet translated into FlowDataTable `advancedFilter` payload — grid-fetch integration sits in `useFlowDataTableStore`/fetch hook outside Contact screen. UI + state are complete; connection is the next step. | OPEN |
| ISSUE-13 | Session 1 2026-04-19 | Low | Integration | Advanced filter panel uses comma-entry inputs for `contactTypeIds` + `tagIds` multi-select instead of `ApiSelectV2` multi-select. Zustand shape is already canonical `number[]` — trivial swap in a follow-up. | OPEN |
| ISSUE-14 | Session 1 2026-04-19 | Low | Cleanup | Pre-existing duplicate `TagRequestDto/TagResponseDto/TagDto` exports in both `contact-service/ContactDto.ts` AND `contact-service/TagDto.ts` cause 3 TS2308 `namespace re-export` errors. Pre-dates this session. Recommend removing duplicates from `ContactDto.ts`. | OPEN |
| ISSUE-15 | Session 1 2026-04-19 | Low | Contract | `ContactUPIDetailDto.ts` (FE) uses `upiIdentifier` + required `verifiedDate: string`; BE `ContactUPIDetailRequestDto` uses `upiId` (optional) + `isVerified` (optional). Contract mismatch; reconcile in follow-up. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-19 — BUILD — PARTIAL

- **Scope**: Initial full build from PROMPT_READY prompt. ALIGN scope FLOW screen #18 Contact. DETAIL layout + list controls + BE→FE contract delivered; FORM accordion restructure deferred (ISSUE-11); grid filter wiring deferred (ISSUE-12).
- **Files touched**:
  - BE: 7 modified — `Base.Application/Schemas/ContactSchemas/ContactSchemas.cs` (modified), `Base.Application/Mappings/ContactMappings.cs` (modified), `Base.Application/Business/ContactBusiness/Contacts/Commands/CreateContact.cs` (modified), `.../Commands/UpdateContact.cs` (modified), `.../Queries/GetContact.cs` (modified), `.../Queries/GetContactById.cs` (modified), `Base.API/EndPoints/Contact/Queries/ContactQueries.cs` (modified); 1 created — `Base.Application/Business/ContactBusiness/Contacts/Queries/GetContactSummary.cs` (created). `dotnet build` on Base.API green, 0 errors.
  - FE: 11 modified — `infrastructure/gql-queries/contact-queries/ContactTagQuery.ts` (tagColor→color fix), `domain/entities/contact-service/ContactDto.ts`, `infrastructure/gql-queries/contact-queries/ContactQuery.ts`, `infrastructure/gql-mutations/contact-mutations/ContactMutation.ts`, `application/stores/contact-stores/contact-store.ts`, `presentation/components/page-components/crm/contact/contact/index-page.tsx`, `presentation/components/page-components/crm/contact/contact/view-page.tsx`, `presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts`, `presentation/components/custom-components/data-tables/flow/data-table-column-types/component-column.tsx`, `.../advanced/data-table-column-types/component-column.tsx`, `.../basic/data-table-column-types/component-column.tsx`; 20 created — 6 cell renderers under `shared-cell-renderers/` (contact-avatar-name, score-circle, last-donation-date-amount, contact-type-badge-list, tag-badge-list-overflow, pref-icon), 3 list-page controls under `.../contact/contact/list/` (filter-chips-bar, advanced-filter-panel, bulk-actions-bar), 2 form helpers under `.../contact/contact/form/` (contact-type-card-selector, cascading-address-fields), 9 detail files under `.../contact/contact/detail/` (detail-page, contact-sidebar, engagement-score-ring, score-factor-bars, engagement-score-card, org-units-table, tabs/timeline-tab, tabs/donations-tab, tabs/relationships-tab, tabs/communication-tab, tabs/events-tab, tabs/documents-tab). `pnpm tsc --noEmit` on Contact files: 0 errors (3 pre-existing Tag duplicate-export errors + 2 pre-existing unrelated donationinkind errors — noted as ISSUE-14 and pre-existing).
  - DB: 1 created — `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Contact-sqlscripts.sql` (menu + FLOW grid + 9 GridFields for 8 visible columns using FE-registered renderer names; all 7 renderer names verified against all 3 FE column-type registries).
- **Deviations from spec**:
  - FORM accordion restructure NOT done — kept existing 5-tab wizard (ISSUE-11). DETAIL layout is the primary mockup-new UI and is delivered.
  - Grid-filter wiring NOT connected to `FlowDataTable` advancedFilter payload (ISSUE-12).
  - Advanced filter multi-select fields use comma-entry inputs instead of `ApiSelectV2` (ISSUE-13).
  - `CONTACT_BY_ID_QUERY` retained existing `donations` sub-query alongside new child collections (kept for wizard-tab backward compat + new detail-layout consumes it too).
  - List-projection enrichment happens via 5 post-pagination batch queries rather than composed `Select` projection (preserves existing grid-features helper).
  - `EngagementScore` stubbed to literal `0` per ISSUE-3 — all 7 factor values shown as placeholders in detail formula panel.
  - MasterData `DataValue` (not `DataCode`) used for ContactBaseTypeCode throughout — matched actual entity property.
- **Known issues opened**: ISSUE-11 (FORM 8-accordion deferred), ISSUE-12 (grid filter wiring deferred), ISSUE-13 (advanced-filter multi-select UX), ISSUE-14 (pre-existing TagDto duplicate exports — 3 TS2308 errors), ISSUE-15 (ContactUPIDetail DTO name mismatch BE↔FE).
- **Known issues closed**: Tag #22 ISSUE-1 (legacy `ContactTagQuery.ts` `tagColor → color` fix applied).
- **Next step**: Resume with `/continue-screen #18` to tackle (in priority order) (1) ISSUE-11 FORM 8-section accordion restructure — new `ContactTypeCardSelector` + `CascadingAddressFields` components are ready to wire; (2) ISSUE-12 connect Zustand quickFilterChip + advancedFilters to FlowDataTable fetch payload; (3) ISSUE-13 swap comma-entry inputs for `ApiSelectV2` multi-select; (4) ISSUE-14 remove duplicate TagDto exports from `ContactDto.ts`; (5) ISSUE-15 reconcile `ContactUPIDetail` DTO between BE/FE.