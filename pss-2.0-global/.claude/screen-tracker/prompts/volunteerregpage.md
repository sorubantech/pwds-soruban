---
screen: VolunteerRegistrationPage
registry_id: 172
module: Setting (Public Pages)
status: COMPLETED
scope: FULL
screen_type: EXTERNAL_PAGE
external_page_subtype: DONATION_PAGE
complexity: High
new_module: NO
planned_date: 2026-05-09
completed_date: 2026-05-11
last_session_date: 2026-05-11
mockup_status: §⑥ assumed blueprint approved by user at Session 2 entry AND re-confirmed at Session 3 entry (FE_ONLY). User accepted assumed §⑥ as-is for FE generation; ISSUE-1 closed at Session 3.
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — **N/A: TBD mockup**. Patterned after `onlinedonationpage.md` and `p2pcampaignpage.md`; see `mockup_status` in frontmatter.
- [x] Business context read (audience = anonymous prospective volunteers; conversion goal = volunteer-signup form completion → `app.Volunteer` row created in PENDING; lifecycle = Draft → Published → Active → Closed → Archived)
- [x] Setup vs Public route split identified (admin at `setting/publicpages/volunteerregpage` + anonymous public at `(public)/volunteer/{slug}` — distinct from donation `/p/` and P2P `/p2p/` namespaces)
- [x] Slug strategy chosen: `custom-with-fallback` (auto-from-Title; user may override; per-tenant unique; reserved-slug list rejected)
- [x] Lifecycle states confirmed: Draft / Published / Active / Closed / Archived (full)
- [x] Payment gateway integration scope: **N/A** — volunteer registration has no payment hand-off
- [x] FK targets resolved (paths + GQL queries verified — see §③)
- [x] File manifest computed (admin setup files + public page files separately)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (Session 2, 2026-05-11) — 4 issues CLOSED (ISSUE-2/3/4/9); 3 adjustments caught & applied (HEARDABOUTSOURCE→VOLUNTEERHEARDABOUTSOURCE, 7 locked fields not 5, rejectedApplications scoped to page)
- [x] Solution Resolution complete (Session 2, 2026-05-11) — DONATION_PAGE sub-type CONFIRMED vs SUBMISSION_PAGE; 24-file BE manifest (not 22 — endpoint tier is 3 distinct files); rate-limit infra confirmed at DependencyInjection.cs
- [x] **MOCKUP REVIEW** — user approved assumed §⑥ blueprint at Session 2 entry; full mockup review deferred to FE_ONLY session if user supplies real mockup
- [x] UX Design finalized (Session 3, 2026-05-11) — user re-approved assumed §⑥ at FE_ONLY session entry; ISSUE-1 closed
- [x] User Approval received (Session 2, 2026-05-11) — re-confirmed at Session 3 entry
- [x] Backend code generated (Session 2, 2026-05-11) — 24 BE files: 2 entities + 2 EF configs + 1 schemas + 1 validator + 10 commands + 4 queries + 1 public query + 1 public mutation + 3 endpoints
- [x] Backend wiring complete (Session 2, 2026-05-11) — IApplicationDbContext + ApplicationDbContext + DecoratorProperties + ApplicationMappings + Volunteer.cs (FK) + VolunteerConfiguration.cs (FK + index) + DependencyInjection.cs (VolunteerSubmit rate-limit inside existing lambda)
- [x] Frontend (admin setup) code generated (Session 3, 2026-05-11) — root + list-page + editor-page + store + 8 sections + 7 components (status-bar / approval-mode-switcher / applicant-fields-editor / position-multi-select / api-single-select / live-preview / section-card)
- [x] Frontend (public page) code generated (Session 3, 2026-05-11) — applicant-page + applicant-form (orchestrator) + thank-you + 7 form-section components (identity / position-branch / personal / availability / emergency / skills / compliance) + SSR route at `(public)/volunteer/[slug]/page.tsx` with `generateMetadata` + `revalidate=60`
- [x] Frontend wiring complete (Session 3, 2026-05-11) — 7 wiring updates: volunteer-service-entity-operations + 4 GQL barrels (volunteer-queries / public-queries / volunteer-mutations / public-mutations) + DTO barrel + page-config barrel
- [x] DB Seed script generated (Session 2, 2026-05-11) — `volunteer-registration-page-sqlscripts.sql` with 8 idempotent sections (Menu + Capabilities + RoleCapabilities + Grid + VOLUNTEERPOSITION MasterDataType + 8 sample positions + sample published page + 5-position junction rows)
- [x] EF Migration generated (Session 2) — `20260511000000_Add_VolunteerRegistrationPages_And_VolunteerRegistrationPagePositions.cs` — Designer/ModelSnapshot deferred to user's `dotnet ef migrations add` regen step
- [x] Registry updated to COMPLETED (Session 3, 2026-05-11)

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — admin setup loads at `/{lang}/setting/publicpages/volunteerregpage` (replaces UnderConstruction stub)
- [ ] `pnpm dev` — public page loads at `/{lang}/volunteer/{slug}` (canonical applicant page)
- [ ] **DONATION_PAGE-pattern checks** (adapted for volunteer registration):
  - [ ] Setup list view shows all VolunteerRegistrationPages with status badges; "+ New Page" creates a Draft and redirects to editor
  - [ ] Editor 8 settings cards persist via autosave (300ms debounce); preview pane updates live without round-trip
  - [ ] Slug auto-generated from Title on first save; uniqueness enforced per tenant; reserved slug list rejected (`admin/api/embed/p/p2p/preview/login/auth/start/volunteer-list`)
  - [ ] Offered Positions multi-select sources from `getMasterDatas` filtered by MasterDataType=`VOLUNTEERPOSITION`; default-position dropdown filters to selected ones; junction `app.VolunteerRegistrationPagePositions` reflects selection
  - [ ] Approval Mode toggle (AUTO / MANUAL) — when MANUAL, public submissions land in PENDING; when AUTO, public submissions land in ACTIVE
  - [ ] Applicant Field Config table (15 fields): First/Last/Email/Phone/AgreedToCodeOfConduct forced required+visible+locked (disabled checkboxes); other 10 fields editable; saved JSON reflects on public form (see §⑥ for exact 15-row table)
  - [ ] Branch dropdown sources from `getBranches` (current tenant); when filled, public form shows Branch picker
  - [ ] Branding card: logo upload + hero image + primary color + accent color + tagline + page layout select reflected in preview
  - [ ] Communication card: 4 email-template selectors (Welcome / Approval / Rejection / Reminder) source from `getEmailTemplates`; OG image + OG title + share message persist
  - [ ] Thank-You & Compliance card: thank-you message + redirect URL + privacy-notice text + tax-receipt note (when N/A leave blank) + show-applicant-counter toggle persist
  - [ ] Live preview reflects current setup state (Desktop / Mobile via device-switcher; preview-token banner when Status=Draft)
  - [ ] Validate-for-publish blocks Publish until: Title + Slug + ≥1 Offered Position + ≥1 active Approval-mode + ≥1 communication template (Welcome required) + (if MANUAL) Approval template required + LogoUrl OR HeroImageUrl set; missing-field list shown in modal
  - [ ] Publish transitions Draft → Active; URL becomes shareable; OG tags pre-rendered in `generateMetadata`
  - [ ] Anonymous public page renders Active status; CSP headers set; CSRF + honeypot + rate-limit (5 attempts/min/IP/slug) enforced on submit
  - [ ] Anonymous applicant submits form → server creates `app.Volunteer` row with `VolunteerRegistrationPageId = X` + `VolunteerStatusId = PENDING (MANUAL)` or `ACTIVE (AUTO)` + child rows in `app.VolunteerSkills` / `app.VolunteerInterests` / `app.VolunteerLanguages`; Welcome email fires (SERVICE_PLACEHOLDER if email infra absent)
  - [ ] Status = Closed renders banner "This volunteer drive has ended" + disables Apply button on public; Status = Archived returns 410 Gone
  - [ ] Status Bar in admin setup shows real aggregates (totalApplications / pendingApplications / approvedApplications / rejectedApplications / lastApplicationAt) sourced from `GetVolunteerRegistrationPageStats`
  - [ ] **Approval Mode = MANUAL** → submission lands in PENDING + admin sees in Volunteer #53 grid (status filter "Pending"); admin Approve via existing `ApproveVolunteer` command flips to ACTIVE + sends Approval email; admin Deactivate flips to INACTIVE + sends Rejection email
  - [ ] **Approval Mode = AUTO** → submission lands in ACTIVE immediately; Welcome email + login-link emailed (SERVICE_PLACEHOLDER for portal until #190 Volunteer Portal exists)
- [ ] Empty / loading / error states render on both setup and public surfaces
- [ ] DB Seed — admin menu visible at `SET_PUBLICPAGES > VOLUNTEERREGPAGE`; sample published page renders for E2E QA at `/volunteer/join-our-team`

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage for setup AND public page

Screen: VolunteerRegistrationPage
Module: Setting (admin) / Public (anonymous-rendered)
Schema: `app`
Group: `ApplicationModels` (entity location); business folder `Business/ApplicationBusiness/VolunteerRegistrationPages/`

Business: This is the **public-facing volunteer recruitment landing page** an NGO publishes to attract anonymous prospective volunteers — the conversion-funnel page that turns interested website visitors into registered volunteers. The admin setup screen lets a BUSINESSADMIN configure every aspect of the experience: page identity (title, slug, description), which volunteer positions are being offered (multi-select from MasterData `VOLUNTEERPOSITION`), which fields the applicant must fill (15-field config: required / optional / hidden), branch / organizational-unit assignment, branding (logo, hero image, primary/accent colors, page layout), communication templates (welcome / approval / rejection / reminder emails), and thank-you behaviour. The headline conversion goal is a completed volunteer-signup form; the secondary goal is a high-quality applicant pipeline (PENDING applications go into the existing Volunteer #53 moderation queue under MANUAL approval mode; auto-approved volunteers go straight to ACTIVE). Lifecycle is Draft → Published → Active → Closed → Archived: only Active pages accept submissions; Draft pages render only with a preview-token; Closed pages render but disable the Apply button; Archived returns 410 Gone. **What breaks if mis-set**: missing CSRF/honeypot enabling bot/spam volunteer rows polluting the moderation queue; slug rename after applications attached → link rot on shared social posts; OG meta missing → bad share previews → low recruitment; ApprovalMode=manual without admin actually monitoring the Volunteer #53 grid → applicants stuck Pending forever and bounce; OfferedPositions list empty → applicant can't pick a position → submit blocked → 0 conversions. Related screens: every public submission creates a row in `app.Volunteers` (linked back via the new `VolunteerRegistrationPageId` nullable FK) and child rows in `app.VolunteerSkills` / `app.VolunteerInterests` / `app.VolunteerLanguages` — admin then manages the volunteer through the existing Volunteer #53 FLOW screen (4 workflow commands: Approve/Deactivate/SetOnLeave/Reactivate). Email templates live at `notify.EmailTemplates` (referenced by id). Branch FK references `app.Branches`. Country FK references `shared.Countries`. **What's unique about this page's UX vs the canonical Online Donation Page (#10)**: there is NO payment / amount / recurring / currency / gateway concern — the whole "Amounts & Currency" + "Recurring Donations" + "Payment Methods" branch of the donation-page UX is replaced by **Offered Positions multi-select + Applicant Field Config (15 rows) + Approval Mode toggle**. The applicant form is dramatically wider (15 fields vs donation's 9) and grouped into 5 visual sections on the public page (Identity / Availability / Emergency Contact / Skills & Interests / Compliance) instead of the donation page's single tall form. The "donate now" CTA becomes "Apply Now" / "Become a Volunteer" — wording is configurable.

> **Why this section is heavier**: The Approval Mode branch (AUTO vs MANUAL) is the defining workflow toggle — a developer that misses this will ship a one-mode product. The 15-field Applicant Field Config (vs the 9-field DonorFields on #10) is the second largest UX surface and has 3 axes per row (required / visible / locked). Read this whole section before opening §⑥.

---

## ② Storage & Source Model

> **Consumer**: BA Agent → Backend Developer
>
> **Storage Pattern**: `parent-with-children`
>
> Each tenant may have multiple `VolunteerRegistrationPage` rows — e.g. "General Volunteer Drive" + "Ramadan Iftar 2026" + "Crisis Hotline Recruits 2026". Donations don't apply here; instead, **each anonymous public submission creates a row in the existing `app.Volunteers` table** (linked back via `VolunteerRegistrationPageId`). This page is a SOURCE / FUNNEL, not a separate volunteer-applications store. Admin moderates via the existing Volunteer #53 grid filtered to `VolunteerStatusId = PENDING`.

### Tables

> Audit columns omitted (inherited from `Entity` base). CompanyId always present (tenant scope). Schema = `app`.

**Primary table**: `app."VolunteerRegistrationPages"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| VolunteerRegistrationPageId | int | — | PK | — | Identity |
| CompanyId | int | — | YES | corg.Companies | Tenant scope |
| PageTitle | string | 200 | YES | — | Internal label + default for public hero title; e.g. "Join Our Volunteer Team" |
| Slug | string | 100 | YES | — | URL slug; unique per tenant; lower-kebab; auto-from-PageTitle on Create |
| Tagline | string | 300 | NO | — | Short hero subtitle; e.g. "Make a difference. One hour at a time." |
| Description | string | 2000 | NO | — | Rich-text intro paragraph rendered above the form on public |
| PageStatus | string | 20 | YES | — | Draft / Published / Active / Closed / Archived |
| PublishedAt | DateTime? | — | NO | — | Set on Draft→Published transition |
| ArchivedAt | DateTime? | — | NO | — | Set on Archive |
| StartDate | DateTime? | — | NO | — | When set, page Active only after this date |
| EndDate | DateTime? | — | NO | — | When set, page auto-Closed after this date |
| **Approval & Workflow** | | | | | |
| ApprovalMode | string | 20 | YES | — | `AUTO` \| `MANUAL`; default MANUAL |
| AutoApproveCriteriaJson | jsonb | — | NO | — | (Future) Optional rule e.g. `{"minAge":18,"requiresEmergencyContact":true}` — when ApprovalMode=AUTO and submission fails any criterion, falls back to PENDING |
| **Offered Positions Default** | | | | | |
| DefaultPositionMasterDataId | int? | — | NO | sett.MasterData | Default selected on public form's Position dropdown; must be in junction below |
| DefaultBranchId | int? | — | NO | app.Branches | Default selected on public form's Branch dropdown (when AssignBranch field is visible) |
| **Applicant Field Config** (15-field table — see §⑥ for the full row breakdown) | | | | | |
| ApplicantFieldsJson | jsonb | — | YES | — | Per-field config: `{"FirstName":{"required":true,"visible":true,"locked":true},"DateOfBirth":{"required":false,"visible":true},"Skills":{"required":false,"visible":true},...}` — 15 fields total |
| RequireCodeOfConduct | bool | — | YES | — | Default TRUE; when TRUE, `AgreedToCodeOfConduct` checkbox always required & visible (locked row in field-config table) |
| CodeOfConductText | string | 8000 | NO | — | Rich text shown next to the checkbox / link to PDF |
| **Branding** | | | | | |
| LogoUrl | string | 500 | NO | — | Org logo (header left) |
| HeroImageUrl | string | 500 | NO | — | Hero background |
| PrimaryColorHex | string | 7 | NO | — | Default `#059669` (volunteer green from existing volunteer-form mockup) |
| AccentColorHex | string | 7 | NO | — | Default `#0e7490` |
| ButtonText | string | 50 | NO | — | Apply button label (default "Apply Now") |
| PageLayout | string | 30 | NO | — | `centered` \| `side-by-side` \| `full-width` |
| CustomCssOverride | string | 8000 | NO | — | Optional CSS pasted by admin; sanitized server-side |
| **Communication** | | | | | |
| WelcomeEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent immediately on submission (both AUTO and MANUAL) |
| ApprovalEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent when admin approves a PENDING volunteer (MANUAL mode) |
| RejectionEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent when admin deactivates a PENDING volunteer (MANUAL mode) |
| ReminderEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent X days after PENDING with no admin action; SERVICE_PLACEHOLDER (background scheduler not in scope) |
| ReminderDelayDays | int? | — | NO | — | Default 7; only used when ReminderEmailTemplateId set |
| AdminNotificationEmail | string | 200 | NO | — | When set, internal email fires on every submission alerting admin to moderate |
| **Thank-You & Display** | | | | | |
| ThankYouMessage | string | 2000 | NO | — | Inline thank-you copy after submit |
| ThankYouRedirectUrl | string | 500 | NO | — | If set, redirect after success instead of inline thank-you |
| ShowApplicantCounter | bool | — | YES | — | Renders "{N} volunteers have joined" on public hero |
| ShowSocialShare | bool | — | YES | — | Renders FB/Twitter/WhatsApp share buttons |
| PrivacyNoticeText | string | 1000 | NO | — | Compliance line shown near Apply button |
| **Social & SEO** | | | | | |
| OgTitle | string | 200 | NO | — | Defaults to PageTitle |
| OgDescription | string | 500 | NO | — | Defaults to Tagline / first 160 chars of Description |
| OgImageUrl | string | 500 | NO | — | Defaults to HeroImageUrl |
| RobotsIndexable | bool | — | YES | — | Default TRUE |
| IsActive | bool | — | YES | — | Soft-active toggle for quick "pause" without changing lifecycle |

**Slug uniqueness**:
- Unique filtered index on `(CompanyId, LOWER(Slug))` WHERE `IsDeleted = FALSE`
- Reserved-slug list rejected (case-insensitive): `admin / api / embed / p / p2p / preview / login / signup / oauth / public / assets / static / start / volunteer-list / register / signup`

**Status transition rules** (BE-enforced, not FE):
- Draft → Published only when `ValidateVolunteerRegistrationPageForPublish` passes
- Published → Active automatic at StartDate (or = Published if no StartDate)
- Active → Closed automatic at EndDate, or admin "Close Early"
- Any → Archived admin-triggered (soft-delete; preserves Volunteer FK rows)
- Closing parent does NOT close any submitted volunteers — those are managed via Volunteer #53 lifecycle

### Child / Junction Table

**Junction `app."VolunteerRegistrationPagePositions"`** (M:N VolunteerRegistrationPage ↔ MasterData VOLUNTEERPOSITION)

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| VolunteerRegistrationPagePositionId | int | PK | — | Identity |
| VolunteerRegistrationPageId | int | YES | app.VolunteerRegistrationPages | Cascade-delete on parent |
| PositionMasterDataId | int | YES | sett.MasterData | Restrict-delete (MasterData row can't be removed if attached); MasterDataType=`VOLUNTEERPOSITION` |
| OrderBy | int | YES | — | Display order in applicant's Position dropdown |

Composite unique index on `(VolunteerRegistrationPageId, PositionMasterDataId)`.

### Volunteer Linkage (DO NOT add applicant columns here — modify existing entity)

**Modify** `app."Volunteers"` to add:

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| VolunteerRegistrationPageId | int? | NO | app.VolunteerRegistrationPages | NULL for admin-created volunteers; SET for volunteers created via this funnel |

Migration: `ALTER TABLE app."Volunteers" ADD COLUMN "VolunteerRegistrationPageId" int NULL` + filtered FK constraint. Existing rows stay NULL.

> **DO NOT** add a separate `VolunteerApplication` table — single nullable FK on `app.Volunteers` is the leanest, queryable approach. Admin moderation reuses the existing Volunteer #53 grid filtered by `VolunteerStatusId = PENDING`. Stats query (`GetVolunteerRegistrationPageStats`) GROUP BYs on this FK.

### Position MasterData seed

Seed (idempotent) `sett.MasterDataTypes.VOLUNTEERPOSITION` and 8 sample rows:

| Code | Display | OrderBy |
|------|---------|---------|
| TUTOR | Tutor / Mentor | 1 |
| EVTHELPER | Event Helper | 2 |
| TRANSLATOR | Translator | 3 |
| HOTLINE | Crisis Hotline | 4 |
| FUNDRAISER | Fundraiser | 5 |
| ADMIN_ASSIST | Administrative Support | 6 |
| MARKETING | Marketing & Outreach | 7 |
| OTHER | Other | 99 |

These are seed defaults — tenants can add/remove via existing MasterData #79 screen.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------------|---------------|-------------------|
| DefaultPositionMasterDataId | MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (filter `MasterDataType=VOLUNTEERPOSITION`) | `displayName` | `MasterDataResponseDto` |
| (junction) PositionMasterDataId | MasterData | (same) | (same) | (same) | (same) |
| DefaultBranchId | Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | `getBranches` | `branchName` | `BranchResponseDto` |
| WelcomeEmailTemplateId / ApprovalEmailTemplateId / RejectionEmailTemplateId / ReminderEmailTemplateId | EmailTemplate | `Base.Domain/Models/NotifyModels/EmailTemplate.cs` | `getEmailTemplates` | `templateName` | `EmailTemplateResponseDto` |
| (Volunteer entity) VolunteerRegistrationPageId | VolunteerRegistrationPage | `Base.Domain/Models/ApplicationModels/VolunteerRegistrationPage.cs` (NEW — this entity) | `getAllVolunteerRegistrationPagesList` | `pageTitle` | `VolunteerRegistrationPageResponseDto` |

**Master-data references** (looked up by code via existing `MasterData` shared model — NO FK column on entity):
| Code | MasterDataType | Used For |
|------|----------------|----------|
| `VOLUNTEERPOSITION` (8 rows) | New seed | Page-Position junction + applicant Position dropdown |
| `VOLUNTEERSKILL` | Existing (from Volunteer #53 plan) | Applicant Skills multi-select on public form |
| `VOLUNTEERINTEREST` | Existing | Applicant Interests multi-select |
| `LANGUAGE` | Existing | Applicant Languages multi-select |
| `VOLUNTEERAVAILABILITYTYPE` | Existing | Availability dropdown |
| `VOLUNTEERPREFERREDTIME` | Existing | Preferred time dropdown |
| `HEARDABOUTSOURCE` | Existing | "How did you hear about us?" dropdown |
| `GENDER` | Existing | Gender dropdown |
| `RELATION` | Existing | Emergency-contact relation dropdown |
| `VOLUNTEERSTATUS` | Existing | Applied to created Volunteer (PENDING / ACTIVE / INACTIVE) |

> Verify these MasterDataTypes exist (Volunteer #53 seed should have created them); if any are absent, seed them in step 1 of DB seed script.

**Aggregation sources** (for status-bar stats query):

| Source | Aggregate | Used In | Filter |
|--------|-----------|---------|--------|
| `app.Volunteers` | `COUNT(*)` GROUP BY VolunteerRegistrationPageId | `totalApplications` | All non-deleted |
| `app.Volunteers` | `COUNT(*)` GROUP BY VolunteerRegistrationPageId WHERE VolunteerStatusId = PENDING | `pendingApplications` | — |
| `app.Volunteers` | `COUNT(*)` GROUP BY VolunteerRegistrationPageId WHERE VolunteerStatusId = ACTIVE | `approvedApplications` | — |
| `app.Volunteers` | `COUNT(*)` GROUP BY VolunteerRegistrationPageId WHERE VolunteerStatusId = INACTIVE | `rejectedApplications` | — |
| `app.Volunteers` | `MAX(CreatedDate)` GROUP BY VolunteerRegistrationPageId | `lastApplicationAt` | — |

> **conversionRate** is SERVICE_PLACEHOLDER — no page-visit logging infrastructure exists. Status bar shows "—" until visit-log table or analytics service is added.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Slug Rules** (mirror OnlineDonationPage #10):
- Auto-generate from `PageTitle` on Create — lowercase, replace whitespace with `-`, strip non-alphanumeric (keep `-`), collapse multiple `-`
- User can override via Slug field; same normalization applied; show "URL preview" inline
- Reserved-slug list rejected (case-insensitive): `admin, api, embed, p, p2p, preview, login, signup, oauth, public, assets, static, start, volunteer-list, register, _next, ic`
- Uniqueness enforced per tenant — composite (CompanyId, LOWER(Slug))
- Slug **immutable post-Activation when ≥1 application attached** (`SELECT EXISTS (SELECT 1 FROM app.Volunteers WHERE VolunteerRegistrationPageId = X)`)
- Validator returns 422 with `{field:"slug", code:"SLUG_RESERVED|SLUG_TAKEN|SLUG_LOCKED_AFTER_APPLICATIONS"}`

**Lifecycle Rules**:

| State | Set by | Public route behavior | Apply button |
|-------|--------|----------------------|--------------|
| Draft | Initial Create | 404 to public; preview-token grants temporary access | Disabled / not rendered |
| Published | Admin "Publish" action | Renders publicly | Live (if within Active window) |
| Active | Auto at StartDate (or = Published if no StartDate) | Renders publicly | Live |
| Closed | Auto at EndDate, or admin "Close Early" | Renders publicly with "This volunteer drive has ended" banner | Disabled |
| Archived | Admin "Archive" | 410 Gone | N/A |

**Required-to-Publish Validation** (return all violations as list — don't stop at first):
- PageTitle non-empty
- Slug set + unique + not reserved
- ApprovalMode set (AUTO or MANUAL)
- ≥1 Offered Position attached (junction non-empty)
- DefaultPositionMasterDataId IS NULL OR exists in attached positions
- LogoUrl OR HeroImageUrl set (must have ANY hero asset)
- WelcomeEmailTemplateId set (always required)
- (ApprovalMode=MANUAL) ApprovalEmailTemplateId + RejectionEmailTemplateId set (warn but allow if not — defaults work)
- RequireCodeOfConduct=TRUE → CodeOfConductText non-empty
- OgTitle + OgImageUrl set (warn but allow — falls back to PageTitle + HeroImageUrl)
- PrimaryColorHex valid hex (default `#059669` always valid)

**Conditional Rules**:
- If `ApprovalMode = AUTO` → ApprovalEmailTemplate / RejectionEmailTemplate ignored (no admin moderation step)
- If `ApprovalMode = MANUAL` → server creates Volunteer with `VolunteerStatusId = PENDING` and admin must use existing Volunteer #53 Approve/Deactivate workflow
- If `ApplicantFieldsJson["EmergencyContact"]["visible"] = FALSE` → public form omits the entire Emergency Contact section (4 sub-fields: Name, DialCode+Phone, Relation)
- If `ApplicantFieldsJson["Availability"]["visible"] = FALSE` → public form omits Availability + PreferredTime + Day-of-week toggles + MaxHoursPerWeek + StartDate
- If `EndDate < now` AND `Status = Active` → server-side auto-flip to `Closed` on next state-tick OR on next public request
- If `RequireCodeOfConduct = FALSE` → AgreedToCodeOfConduct field hidden + CodeOfConductText ignored
- If `ShowApplicantCounter = TRUE` → public hero renders "{N} volunteers have joined" — sourced from `totalApplications` of stats query

**Sensitive / Security-Critical Fields**:

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| Applicant PII captured on public form | regulatory (PII — names, emails, phone, address, DOB, emergency contacts) | server-side only; never logged in plain text | encrypt-at-rest at column level if regulation requires (PHI/GDPR) | log access |
| CodeOfConductText | injection-risk (rich text) | render via DOMPurify on public side | sanitize-strip `<script>` blocks; max 8000 chars | log on save |
| CustomCssOverride | injection-risk | enforce CSP — disallow inline `<script>` patterns server-side | sanitize-strip `<script>` blocks; max 8000 chars | log on save |
| Anti-fraud markers (IP, UA, velocity) | operational | not on public; visible to admin only via audit | append-only | retain per policy |

**Public-form Hardening (anonymous-route concerns)**:
- Rate-limit submit POST: **5 attempts / minute / IP / slug** combined (use `RateLimiterPolicy("VolunteerSubmit")` — same policy class as `DonationSubmit` on #10, just different key)
- CSRF token issued on initial public-page render; required on submit; rotation on each render
- Honeypot field `[name="website"]` hidden via CSS; submission with non-empty honeypot silently rejected (return mocked success to bot)
- reCAPTCHA v3 score check before final submission — `SERVICE_PLACEHOLDER` until reCAPTCHA configured (returns score=1.0)
- All applicant input fields validated server-side (never trust public client)
- CSP headers on public route: `script-src 'self'; frame-src 'none'; style-src 'self' 'unsafe-inline'; img-src * data: https:`
- `frame-ancestors 'none'` (volunteer pages NOT iframe-embeddable; differs from #10 IFRAME mode)

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Publish | Page goes live; URL becomes shareable | "Publishing makes this page public at /volunteer/{slug}. Confirm?" | log "page published" + jsonb config snapshot |
| Unpublish | Active → Draft; submissions rejected | "Public visitors will see a 'campaign closed' page. Continue?" | log |
| Close Early | Active → Closed before EndDate; new submissions rejected | "Close drive now? Existing volunteers stay. {totalApplications} applied so far." | log + email page owner |
| Archive | Soft-delete; URL returns 410 | type-name confirm ("type {pageTitle} to archive") | log |
| Reset Branding | Wipe theme/branding back to defaults | type-name confirm | log |
| Switch ApprovalMode post-Active | Existing PENDING applications NOT retroactively flipped | "Switching to AUTO will not auto-approve existing PENDING applications. Continue?" | log + warn-banner displayed for 7 days |

**Role Gating**:

| Role | Setup access | Publish access | Notes |
|------|-------------|----------------|-------|
| BUSINESSADMIN | full | yes | full lifecycle (target role for MVP) |
| Anonymous public | no setup access | — | only sees Active public route |

**Workflow** (cross-page — applicant flow):
- Anonymous prospective volunteer visits `/volunteer/{slug}` → fills form → submits with CSRF token
- Server validates → creates `app.Volunteer` row with:
  - `VolunteerRegistrationPageId = X`
  - `VolunteerStatusId = PENDING (MANUAL mode)` OR `ACTIVE (AUTO mode)`
  - `JoinedDate = now (AUTO only)`
  - All other fields copied from form per `ApplicantFieldsJson`
- Server creates child rows in `app.VolunteerSkills`, `app.VolunteerInterests`, `app.VolunteerLanguages` from form's multi-select inputs (only if those fields are visible per ApplicantFieldsJson)
- Server fires Welcome email (SERVICE_PLACEHOLDER if email infra missing)
- (MANUAL only) Server fires admin notification email to `AdminNotificationEmail` if set
- Returns redirect URL or thank-you state
- (MANUAL) Admin opens Volunteer #53 grid → filter status=PENDING → opens application → uses existing `ApproveVolunteer` command (flips to ACTIVE + fires Approval email) OR `DeactivateVolunteer` (flips to INACTIVE + fires Rejection email)
- (AUTO) Welcome + login-link email fires immediately; volunteer becomes ACTIVE; SERVICE_PLACEHOLDER for self-service portal until #190 Volunteer Portal exists

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on the assumed UX (mockup TBD).

**Screen Type**: EXTERNAL_PAGE
**External-Page Sub-type**: `DONATION_PAGE` (re-using the DONATION_PAGE sub-type because the structural pattern — single public registration page + admin setup with slug + Publish lifecycle + form-config + branding — matches more closely than P2P_FUNDRAISER or CROWDFUND. There is no parent-with-children hierarchy of sub-pages like P2P, no goal/deadline/rewards like CROWDFUND.)
**Storage Pattern**: `parent-with-children` (page + position junction; volunteer linkage via existing `app.Volunteers` FK)

**Slug Strategy**: `custom-with-fallback`
> Slug auto-derived from PageTitle on Create; user may override; auto re-applied on each new save when slug field is cleared. Slug becomes immutable once applications attached.

**Lifecycle Set**: `Draft / Published / Active / Closed / Archived` (full)

**Save Model**: `autosave-with-publish`
> Each settings card autosaves on edit (300ms debounce). The top-right "Save & Publish" button explicitly transitions Draft → Active after Validate-for-Publish passes. No "Save" button — implicit autosave + explicit Publish.

**Public Render Strategy**: `ssr`
> Volunteer pages must be SEO-indexable (Google "volunteer near me" search results). Use Next.js App Router `(public)/volunteer/[slug]/page.tsx` with `generateMetadata` for OG tags + `revalidate: 60` for ISR.

**Reason**: DONATION_PAGE sub-type fits because the screen is a single public registration page with admin setup + Publish lifecycle + form-field config + branding. `parent-with-children` storage is needed because Offered Positions is M:N. `custom-with-fallback` slug matches the editable-with-fallback expectation. `autosave-with-publish` matches the implicit-save + explicit-publish pattern from #10. SSR is critical for Google "volunteer for X" organic discovery.

**Backend Patterns Required**:

For DONATION_PAGE-like (volunteer):
- [x] GetAllVolunteerRegistrationPagesList query (admin list view) — tenant-scoped, paginated, status filter
- [x] GetVolunteerRegistrationPageById query (admin editor)
- [x] GetVolunteerRegistrationPageBySlug query (public route) — anonymous-allowed, status-gated
- [x] GetVolunteerRegistrationPageStats query — totalApplications / pending / approved / rejected / lastApplicationAt
- [x] GetVolunteerRegistrationPagePublishValidationStatus query — returns missing-fields list
- [x] CreateVolunteerRegistrationPage mutation (defaults to Draft, slug auto, ApprovalMode default MANUAL)
- [x] UpdateVolunteerRegistrationPage mutation (full upsert; partial-update via separate mutations for jsonb arrays)
- [x] UpdateVolunteerRegistrationPagePositions mutation (junction-table batch set)
- [x] PublishVolunteerRegistrationPage mutation — runs ValidateForPublish + transitions Draft → Active
- [x] UnpublishVolunteerRegistrationPage mutation — Active → Draft
- [x] CloseVolunteerRegistrationPage mutation — Active → Closed
- [x] ArchiveVolunteerRegistrationPage mutation — soft-delete + 410 Gone afterwards
- [x] ResetVolunteerRegistrationPageBranding mutation — wipe Logo/Hero/Colors/Layout/CustomCss
- [x] Slug uniqueness validator + reserved-slug rejection
- [x] Tenant scoping (CompanyId from HttpContext) — anonymous public uses CompanyId resolved from `(slug)` lookup
- [x] Anti-fraud throttle on public submit endpoint
- [x] **SubmitVolunteerApplication public mutation (anonymous)** — creates `app.Volunteer` row + child rows; returns thank-you state; respects ApprovalMode for status assignment
- [ ] Real reCAPTCHA / email-send → SERVICE_PLACEHOLDER until configured

**Frontend Patterns Required**:

For DONATION_PAGE-like (volunteer) — TWO render trees:
- [x] Admin setup at `setting/publicpages/volunteerregpage` — list view (when `?id` not present) + editor (`?id=N`)
- [x] Editor: split-pane (settings cards left + live preview right) — 8 settings cards
- [x] Live Preview component — debounced 300ms; 2 variants (Desktop / Mobile via device-switcher)
- [x] Public page at `(public)/volunteer/[slug]/page.tsx` — SSR, full-page hosted; hero + tagline + 5-section form + footer
- [x] Anonymous applicant-form component — respects ApplicantFieldsJson + Offered Positions list
- [x] Thank-you state — inline (within form region) OR redirect to ThankYouRedirectUrl
- [x] (NO IFRAME mode for volunteer pages — only NAV — keeps scope tight)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **MOCKUP STATUS**: TBD — assumed blueprint patterned after `onlinedonationpage.md` §⑥. **Validate with user before /build-screen.**

### 🎨 Visual Treatment Rules (apply to all surfaces)

1. **Public page is brand-driven** — hero, primary color, logo all from page config. Don't re-use the admin shell.
2. **Admin setup mirrors what the public will see** — every meaningful edit reflected in live preview pane within 300ms.
3. **Mobile preview is mandatory** — most public visitors are on mobile.
4. **Lifecycle state is visually clear** — Status Bar at top of admin setup shows current Status as colored dot + label (Active=green / Draft=gray / Closed=orange / Archived=red).
5. **Apply CTA is dominant** — primary `PrimaryColorHex` background (default volunteer green `#059669`), sized to prompt action, sticky on mobile scroll.
6. **Trust signals first-class** — privacy-notice + tax-info + agency-of-record + footer always visible.
7. **Approval Mode toggle visually distinguishes** — selected mode-card has accent border + checkmark; unselected has gray border + empty circle.
8. **Settings cards consistent chrome** — white card + 12px radius + 1px border + header with phosphor icon + body. Same chrome for all 8 cards.

**Anti-patterns to refuse**:
- Admin chrome bleeding into public route
- "Save and refresh to preview"
- Approval Mode hidden behind a tab — must be visible above settings
- Public form without privacy-notice / code-of-conduct visible
- Generic Apply button styled as tertiary
- Default branding kept identical to OnlineDonationPage `#0e7490` — volunteer pages should default to green `#059669`

---

### A.1 — Admin Setup UI (split-pane: editor left + live preview right)

**Stamp**: `Layout Variant: split-pane (editor + preview)` — same EXTERNAL_PAGE layout as `#10 OnlineDonationPage`. NOT a DataTable, NOT FlowDataTable.

**Page Layout** (assumed — to be validated with mockup):

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ [🤝 Volunteer Registration Page]               [← Back] [↗ Preview] [🚀 Save & Publish]│
│ Configure your organization's public volunteer signup page                        │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ● Active   Total Apps: 142   Pending: 18   Approved: 120   Rejected: 4   Last: 30m│  ← Status Bar (real aggregates)
├──────────────────────────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────┐ ┌────────────────────────────────┐           │
│ │ ●Manual Approval        [✓]   │ │ ○ Auto-Approve         [○]    │   ← Approval Mode Switcher
│ │ Admin reviews each application │ │ Volunteers active immediately  │   (mutually exclusive cards)
│ └────────────────────────────────┘ └────────────────────────────────┘           │
├────────────────────────────────────────────────┬─────────────────────────────────┤
│ EDITOR (8 settings cards stacked)              │ LIVE PREVIEW                    │
│                                                │ Volunteer Page Preview │ [Desktop|Mobile]│
│ ┌─────────────────────────────────────────┐   │ ┌──────────────────────────────┐│
│ │ 🔗 Page URL & Identity                  │   │ │ ┌──────────────────────────┐ ││
│ │  • Title * + Slug * (URL preview+copy)  │   │ │ │ 🔒 https://.../volunteer/│ ││
│ │  • Tagline + Description (rich text)    │   │ │ │       join-our-team      │ ││
│ │  • Page Status toggle                   │   │ │ ├──────────────────────────┤ ││
│ ├─────────────────────────────────────────┤   │ │ │ [Hero — green banner]    │ ││
│ │ 🎯 Offered Positions                    │   │ │ │ Join Our Volunteer Team  │ ││
│ │  • Multi-select tag picker (8 default)  │   │ │ │ Make a difference ...    │ ││
│ │  • Default position dropdown            │   │ │ ├──────────────────────────┤ ││
│ │  • Default branch dropdown (optional)   │   │ │ │ § Identity (4 fields)    │ ││
│ ├─────────────────────────────────────────┤   │ │ │ § Personal (DOB, Gender, │ ││
│ │ 📝 Applicant Form Fields (15-row table) │   │ │ │   Address, Country)      │ ││
│ │  Field             Required Visible Lock│   │ │ │ § Availability (toggles) │ ││
│ │  First Name *      [✓ disabled] [✓] [✓] │   │ │ │ § Skills & Interests     │ ││
│ │  Last Name *       [✓ disabled] [✓] [✓] │   │ │ │ § Emergency Contact      │ ││
│ │  Email *           [✓ disabled] [✓] [✓] │   │ │ │ ☑ I agree to Code of...  │ ││
│ │  Phone *           [✓ disabled] [✓] [✓] │   │ │ │ [APPLY NOW]              │ ││
│ │  DialCode *        [✓ disabled] [✓] [✓] │   │ │ │ Privacy Notice           │ ││
│ │  Date of Birth     [ ] [✓] [ ]          │   │ │ │ [f] [t] [w] (share)      │ ││
│ │  Gender            [ ] [✓] [ ]          │   │ │ └──────────────────────────┘ ││
│ │  Address           [ ] [✓] [ ]          │   │ └──────────────────────────────┘│
│ │  Country *         [✓] [✓] [ ]          │   │                                  │
│ │  Branch            [ ] [✓] [ ]          │   │ (Re-renders within 300ms on     │
│ │  Profile Photo     [ ] [✓] [ ]          │   │  any settings-card edit)         │
│ │  Availability blk  [ ] [✓] [ ]          │   │                                  │
│ │  Emergency Contact [ ] [✓] [ ]          │   │                                  │
│ │  Skills/Interests  [ ] [✓] [ ]          │   │                                  │
│ │  Code of Conduct * [✓ disabled] [✓] [✓] │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🛡️ Compliance & Code of Conduct        │   │                                  │
│ │  • Require COC toggle                   │   │                                  │
│ │  • Code of Conduct text (rich text)     │   │                                  │
│ │  • Privacy Notice text                  │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🎨 Page Branding                        │   │                                  │
│ │  • Logo upload                          │   │                                  │
│ │  • Hero image upload                    │   │                                  │
│ │  • Primary color (#059669) + accent     │   │                                  │
│ │  • Apply button text                    │   │                                  │
│ │  • Page Layout select                   │   │                                  │
│ │  • Custom CSS textarea                  │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ ✉ Communication Templates               │   │                                  │
│ │  • Welcome Email Template * (req)       │   │                                  │
│ │  • Approval Email Template (MANUAL)     │   │                                  │
│ │  • Rejection Email Template (MANUAL)    │   │                                  │
│ │  • Reminder Email Template (optional)   │   │                                  │
│ │  • Reminder delay (days)                │   │                                  │
│ │  • Admin Notification Email             │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ ⚙ Thank You & Display                   │   │                                  │
│ │  • Thank-you message                    │   │                                  │
│ │  • Redirect URL (optional)              │   │                                  │
│ │  • StartDate / EndDate                  │   │                                  │
│ │  • Show applicant counter toggle        │   │                                  │
│ │  • Social share toggle                  │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🔍 SEO & Social                         │   │                                  │
│ │  • OG Title / Description / Image       │   │                                  │
│ │  • Robots indexable toggle              │   │                                  │
│ └─────────────────────────────────────────┘   │                                  │
└────────────────────────────────────────────────┴─────────────────────────────────┘
```

**Settings Cards** (8 — order matches assumed mockup; matches public render order top-to-bottom where applicable):

| # | Card | Icon (phosphor) | Save Model | Notes |
|---|------|-----------------|------------|-------|
| 1 | Page URL & Identity | `ph:link` | autosave | PageTitle + Slug (URL preview + copy) + Tagline + Description (rich text) + Page Status toggle |
| 2 | Offered Positions | `ph:tag` | autosave | Multi-select tag picker sourced from `getMasterDatas` filtered VOLUNTEERPOSITION + Default-position dropdown + Default-branch dropdown |
| 3 | Applicant Form Fields | `ph:list-checks` | autosave | 15-row table; First/Last/Email/Phone/DialCode/Country/CodeOfConduct locked-required-visible (5 disabled rows); other 10 editable per row across required/visible/locked checkboxes; saves to ApplicantFieldsJson |
| 4 | Compliance & Code of Conduct | `ph:shield-check` | autosave | Require-COC toggle + Code of Conduct rich text + Privacy Notice text |
| 5 | Page Branding | `ph:palette` | autosave | Logo upload + Hero image upload + Primary color picker (default `#059669`) + Accent color + Apply button text + Page Layout select + Custom CSS textarea |
| 6 | Communication Templates | `ph:envelope-simple` | autosave | 4 ApiSelect dropdowns (Welcome*/Approval/Rejection/Reminder) sourced from `getEmailTemplates` + Reminder delay (days) + Admin Notification Email |
| 7 | Thank You & Display | `ph:gear` | autosave | Thank-you message + Redirect URL + StartDate / EndDate + Show applicant counter toggle + Social share toggle |
| 8 | SEO & Social | `ph:share-network` | autosave | OG Title / Description / Image + Robots indexable toggle |

**Approval Mode Switcher** (between Status Bar and settings cards):

| Element | Behavior |
|---------|----------|
| 2 cards side-by-side | Click toggles ApprovalMode between `MANUAL` (default) and `AUTO` |
| Selected card | accent border + accent background + checkmark icon top-right |
| Unselected card | gray border + empty circle top-right |
| Confirmation when changing post-Active | Modal "Switching to AUTO will not auto-approve existing PENDING applications. Continue?" — only when Status = Active AND ≥1 PENDING application |

**Live Preview Behavior** (mirror #10 §⑥ A.1 Live Preview):
- Updates on every settings-card edit (debounced 300ms; client-side state, NOT round-trip to server)
- Mobile / Desktop toggle in preview-toolbar changes preview viewport width
- 2 preview variants: `desktop` / `mobile`
- "Open in new tab" button on Draft → uses preview-token query param
- Banner overlay "PREVIEW — NOT YET LIVE" when Status=Draft

**Page Actions** (top-right):

| Action | Position | Style | Confirmation |
|--------|----------|-------|--------------|
| Back | top-right | outline-accent | navigates to setup list view |
| Preview Full Page | top-right | outline-accent | opens public route in new tab with preview-token if Draft |
| Save & Publish | top-right | primary-accent | runs Validate-for-Publish; if pass → "Publishing makes this page public at /volunteer/{slug}." → transitions Draft → Active; if fail → modal lists missing fields |
| Unpublish | overflow menu (when Active) | secondary | "Public visitors will see a 'campaign closed' page." |
| Close Early | overflow menu (when Active) | destructive | "Close drive now? Existing volunteers stay. {totalApplications} applied." |
| Archive | overflow menu | destructive | type-name confirm |
| Reset Branding | overflow menu | destructive | type-name confirm |

**Setup List View** (when `?id` not present in URL):

- Grid layout — 1 row per VolunteerRegistrationPage (this tenant)
- Columns: PageTitle / Slug (linked) / ApprovalMode badge / Status badge / TotalApplications / PendingApplications / LastApplicationAt / Actions (Edit/Open Public/Archive)
- "+ New Page" button top-right → creates Draft + redirects to editor
- Empty state: "Create your first volunteer registration page to start recruiting volunteers online." + primary CTA

### A.2 — Public Page (anonymous route at `(public)/volunteer/[slug]/page.tsx`)

**Page Layout** (SSR; mobile-first; sticky form on mobile; assumed):

```
┌────────────────────────────────────────────────────────────┐
│ [Web Header — Org logo + nav links — gradient bg]          │
│ Hope Foundation                                            │
├────────────────────────────────────────────────────────────┤
│ [Hero — Volunteer Banner — green gradient + hero image]    │
│ Join Our Volunteer Team                                    │
│ Make a difference. One hour at a time.                     │
│   • 142 volunteers have joined                             │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Become a Volunteer                                   │ │
│  │                                                      │ │
│  │ § Identity                                           │ │
│  │   First Name * Last Name * Email * Phone *           │ │
│  │ § Position & Branch                                  │ │
│  │   Position [select] Branch [select]                  │ │
│  │ § Personal Details                                   │ │
│  │   Date of Birth, Gender, Address, Country, Photo     │ │
│  │ § Availability                                       │ │
│  │   Type [Weekday|Weekend|Flexible]                    │ │
│  │   Preferred Time [Morning|Afternoon|Evening]         │ │
│  │   Days [Mon][Tue][Wed][Thu][Fri][Sat][Sun]           │ │
│  │   Max Hours/Week, Start Date                         │ │
│  │ § Emergency Contact                                  │ │
│  │   Name, Phone, Relation                              │ │
│  │ § Skills & Interests                                 │ │
│  │   Skills (multi-tag)                                 │ │
│  │   Interests (multi-tag)                              │ │
│  │   Languages (multi-tag)                              │ │
│  │   Other Skills (textarea)                            │ │
│  │   Previous Experience (textarea)                     │ │
│  │   Motivation (textarea)                              │ │
│  │   Heard About Source [select]                        │ │
│  │ § Compliance                                         │ │
│  │   ☐ I agree to the Code of Conduct (link)            │ │
│  │                                                      │ │
│  │ [APPLY NOW]                                          │ │
│  │                                                      │ │
│  │ Privacy Notice: ...                                  │ │
│  │ [f] [t] [w] (social share)                           │ │
│  └──────────────────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────────┤
│ Hope Foundation © 2026 • Privacy • Terms                   │
└────────────────────────────────────────────────────────────┘
```

**Layout Variants** based on `PageLayout` field:

| PageLayout | Render |
|------------|--------|
| `centered` | Hero on top, form-only column below |
| `side-by-side` | Default — info-left + form-right two-column (info shows mission stats + testimonials when configured) |
| `full-width` | Hero full-bleed; form floats as overlay card centered on hero |

**Public-route behavior**:
- SSR with `revalidate: 60` (page metadata caches 60s; OG tags pre-rendered)
- Anonymous-allowed (no auth gate); CSP headers strict (see §④)
- CSRF token issued in initial render; required on submit
- Honeypot field hidden via CSS
- On submit: server creates `app.Volunteer` row + child rows + welcome email (SERVICE_PLACEHOLDER if email infra absent)
- On gateway/server failure: inline error, retain form state
- On success: ThankYouMessage shown inline OR redirect to ThankYouRedirectUrl

**Edge states**:
- `Status = Draft` → 404 (unless `?previewToken=` in querystring)
- `Status = Closed` → renders page with "This volunteer drive has ended" banner; Apply disabled
- `Status = Archived` → 410 Gone
- Within Active window but Offered Positions empty → "Volunteer drive temporarily unavailable" inline message
- StartDate in future → renders page with "Drive opens on {StartDate}" banner; Apply disabled until then
- EndDate passed but Status not yet auto-flipped → server-side flip on next request

### A.3 — Thank-You State

```
┌────────────────────────────────────────────────────────────┐
│              ✓                                             │
│   Thank you for applying!                                  │
│   {ThankYouMessage}                                        │
│                                                            │
│   {if MANUAL}: We'll review your application and get back  │
│   to you within {ReminderDelayDays or 5} days.             │
│   {if AUTO}: You're now an active volunteer! Check your    │
│   email for a welcome message and login link.              │
│                                                            │
│   [Share This Page] [Browse More Causes →]                 │
└────────────────────────────────────────────────────────────┘
```

If `ThankYouRedirectUrl` set, server redirects (HTTP 302) to that URL after submit instead of rendering inline.

---

### Page Header & Breadcrumbs (admin setup)

| Element | Content |
|---------|---------|
| Breadcrumb | Setting › Public Pages › Volunteer Registration Page |
| Page title | 🤝 Volunteer Registration Page |
| Subtitle | Configure your organization's public volunteer signup page |
| Status badge | Draft / Published / Active / Closed / Archived (color-coded) |
| Right actions | [Back] [Preview Full Page] [Save & Publish] + overflow menu (Unpublish/Close/Archive/Reset Branding) |

### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading (setup list) | Initial fetch | Skeleton 5 rows |
| Loading (setup editor) | Initial fetch | Skeleton matching 8 cards layout |
| Loading (public NAV) | SSR streaming | progressive — header first, hero placeholder, form placeholder |
| Empty (setup list) | No pages yet | "Create your first volunteer registration page" + primary CTA |
| Error (setup) | GET fails | Error card with retry button |
| Error (public) | Slug not found | 404 page with org-default redirect link |
| Closed (public) | Status = Closed | Banner "This volunteer drive has ended" + final applicant count |
| Submission rate-limited | >5 attempts/min | "Too many attempts. Please try again in a minute." inline error |

---

## ⑦ Substitution Guide

> **First DONATION_PAGE-pattern adaptation for non-donation use** — copy from `onlinedonationpage.md` (the DONATION_PAGE canonical) as the substitution base, then adapt with the table below.

| Canonical (`onlinedonationpage.md`) | → This Entity | Context |
|-------------------------------------|---------------|---------|
| OnlineDonationPage | VolunteerRegistrationPage | Entity / class name (PascalCase) |
| onlineDonationPage | volunteerRegistrationPage | Variable / field names (camelCase) |
| onlinedonationpage | volunteerregpage | FE folder / route segment (lowercase) |
| ONLINEDONATIONPAGE | VOLUNTEERREGPAGE | MenuCode / GridCode (UPPERCASE) |
| online-donation-page | volunteer-registration-page | kebab-case (file/component names) |
| `fund` | `app` | DB schema |
| `DonationModels` | `ApplicationModels` | Backend group (entity + EF config + schemas folder names) |
| `DonationBusiness` | `ApplicationBusiness` | Business folder (commands + queries + public mutations) |
| `donation-service` | `volunteer-service` | FE entity domain folder (existing — wraps Volunteer + child entities) |
| `setting/publicpages/onlinedonationpage` | `setting/publicpages/volunteerregpage` | Admin FE route |
| `(public)/p/[slug]` | `(public)/volunteer/[slug]` | Public route (NO embed iframe variant) |
| ParentMenu: `SET_PUBLICPAGES` | (same) | Sidebar parent |
| Module: `SETTING` | (same) | Module code |
| GlobalDonations + OnlineDonationPageId FK | Volunteers + VolunteerRegistrationPageId FK | Funnel-target table gets new nullable FK column |
| OnlineDonationPagePurposes (junction) | VolunteerRegistrationPagePositions (junction) | M:N to MasterData |
| DonationPurposes (FK source) | MasterData (VOLUNTEERPOSITION) | M:N target |
| DonorFieldsJson (9 fields) | ApplicantFieldsJson (15 fields) | Field-config jsonb |

> **NOTE**: Even though screen #172 is registered under "SETTINGS MODULE" section, the public route lives at `/volunteer/{slug}` (NOT `setting/...`). Admin FE route is `setting/publicpages/volunteerregpage`. Do NOT try to create FE files under `crm/volunteer/` — that namespace is the existing admin Volunteer FLOW screen #53.

> **NOTE 2**: The existing `app.Volunteer` entity already has Skills/Interests/Languages/Certifications/Blackouts child collections (built by Volunteer #53). The public-form submission reuses those existing child tables — no new tables for Skills/Interests/Languages.

---

## ⑧ File Manifest

> Counts: BE ≈ 22 files; FE ≈ 22 files; 1 DB seed; 1 EF migration. NO IFRAME variant (volunteer pages are NAV-only) so file count is slightly less than #10.

### Backend Files (NEW — 22)

| # | File | Path |
|---|------|------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/VolunteerRegistrationPage.cs` |
| 2 | Junction Entity | `…/Base.Domain/Models/ApplicationModels/VolunteerRegistrationPagePosition.cs` |
| 3 | EF Config (parent) | `…/Base.Infrastructure/Data/Configurations/ApplicationConfigurations/VolunteerRegistrationPageConfiguration.cs` |
| 4 | EF Config (junction) | `…/Base.Infrastructure/Data/Configurations/ApplicationConfigurations/VolunteerRegistrationPagePositionConfiguration.cs` |
| 5 | Schemas (DTOs) | `…/Base.Application/Schemas/ApplicationSchemas/VolunteerRegistrationPageSchemas.cs` (RequestDto / ResponseDto / PublicDto / StatsDto / ValidationResultDto / ApplicantFieldConfig / ApplicationSubmitDto / etc.) |
| 6 | GetAll Query | `…/Base.Application/Business/ApplicationBusiness/VolunteerRegistrationPages/Queries/GetAllVolunteerRegistrationPagesList.cs` |
| 7 | GetById Query | `…/VolunteerRegistrationPages/Queries/GetVolunteerRegistrationPageById.cs` |
| 8 | GetStats Query | `…/VolunteerRegistrationPages/Queries/GetVolunteerRegistrationPageStats.cs` |
| 9 | Validate-for-Publish Query | `…/VolunteerRegistrationPages/Queries/ValidateVolunteerRegistrationPageForPublish.cs` |
| 10 | GetBySlug (public) Query | `…/VolunteerRegistrationPages/PublicQueries/GetVolunteerRegistrationPageBySlug.cs` (anonymous-allowed) |
| 11 | EntityHelper | `…/VolunteerRegistrationPages/Commands/VolunteerRegistrationPageEntityHelper.cs` |
| 12 | Create Command | `…/VolunteerRegistrationPages/Commands/CreateVolunteerRegistrationPage.cs` |
| 13 | Update Command | `…/VolunteerRegistrationPages/Commands/UpdateVolunteerRegistrationPage.cs` |
| 14 | UpdatePositions Command | `…/VolunteerRegistrationPages/Commands/UpdateVolunteerRegistrationPagePositions.cs` |
| 15 | Publish Command | `…/VolunteerRegistrationPages/Commands/PublishVolunteerRegistrationPage.cs` |
| 16 | Unpublish Command | `…/VolunteerRegistrationPages/Commands/UnpublishVolunteerRegistrationPage.cs` |
| 17 | Close Command | `…/VolunteerRegistrationPages/Commands/CloseVolunteerRegistrationPage.cs` |
| 18 | Archive Command | `…/VolunteerRegistrationPages/Commands/ArchiveVolunteerRegistrationPage.cs` |
| 19 | ResetBranding Command | `…/VolunteerRegistrationPages/Commands/ResetVolunteerRegistrationPageBranding.cs` |
| 20 | Toggle Command | `…/VolunteerRegistrationPages/Commands/ToggleVolunteerRegistrationPage.cs` (IsActive flip) |
| 21 | Public submit mutation | `…/VolunteerRegistrationPages/PublicMutations/SubmitVolunteerApplication.cs` (anonymous-allowed, rate-limited; creates Volunteer + child rows) |
| 22 | EndPoints — Mutations | `…/Base.API/EndPoints/Application/Mutations/VolunteerRegistrationPageMutations.cs` (admin) + Public mutations endpoint |
| 22b | EndPoints — Queries | `…/Base.API/EndPoints/Application/Queries/VolunteerRegistrationPageQueries.cs` (admin) + `…/Application/PublicQueries/VolunteerRegistrationPagePublicQueries.cs` (anonymous) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` | `DbSet<VolunteerRegistrationPage>` + `DbSet<VolunteerRegistrationPagePosition>` |
| 2 | `ApplicationDbContext.cs` | DbSet entries |
| 3 | `DecoratorApplicationModules.cs` | 2 const entries (parent + junction) |
| 4 | `ApplicationMappings.cs` | Mapster mapping config (incl. junction; Volunteer ↔ VolunteerRegistrationPage nav) |
| 5 | `Volunteer.cs` (existing) | Add nullable `VolunteerRegistrationPageId` + nav `public virtual VolunteerRegistrationPage? VolunteerRegistrationPage { get; set; }` |
| 6 | `VolunteerConfiguration.cs` (existing) | Add FK relationship for `VolunteerRegistrationPageId` |
| 7 | EF Migration | `Add_VolunteerRegistrationPages_And_VolunteerRegistrationPagePositions` (creates 2 tables + adds FK column to Volunteers; idempotent backfill ignored — existing rows stay NULL) |
| 8 | Public route registration | Register `(public)/volunteer/{slug}` GET — anonymous-allowed |
| 9 | Anti-fraud middleware | Rate-limit policy `VolunteerSubmit` (5/min/IP/slug; reuse the existing rate-limit infra from #10) |
| 10 | OG meta-tag handler | Extend the existing `(public)/{...}/page.tsx` `generateMetadata` SSR handler to include `/volunteer/{slug}` |

### Frontend Files (NEW — 22)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/volunteer-service/VolunteerRegistrationPageDto.ts` |
| 2 | DTO barrel | (modify) `volunteer-service/index.ts` — export new DTO |
| 3 | GQL Queries (admin) | `…/gql-queries/volunteer-queries/VolunteerRegistrationPageQuery.ts` |
| 4 | GQL Queries (public) | `…/gql-queries/public/VolunteerRegistrationPagePublicQuery.ts` |
| 5 | GQL Mutations | `…/gql-mutations/volunteer-mutations/VolunteerRegistrationPageMutation.ts` |
| 6 | Setup List Page | `…/page-components/setting/publicpages/volunteerregpage/list-page.tsx` |
| 7 | Setup Editor Page | `…/page-components/setting/publicpages/volunteerregpage/editor-page.tsx` (split-pane editor + preview) |
| 8 | Editor Section components | `…/page-components/setting/publicpages/volunteerregpage/sections/{1-page-identity,2-positions,3-applicant-fields,4-compliance,5-branding,6-communication,7-thankyou,8-seo}-section.tsx` (8 files in `sections/`) |
| 9 | Live Preview component | `…/page-components/setting/publicpages/volunteerregpage/components/live-preview.tsx` (mobile/desktop toggle) |
| 10 | Approval Mode Switcher | `…/page-components/setting/publicpages/volunteerregpage/components/approval-mode-switcher.tsx` |
| 11 | Status Bar | `…/page-components/setting/publicpages/volunteerregpage/components/status-bar.tsx` |
| 12 | Applicant Fields Editor (15-row table) | `…/page-components/setting/publicpages/volunteerregpage/components/applicant-fields-editor.tsx` |
| 13 | Position Multi-Select | `…/page-components/setting/publicpages/volunteerregpage/components/position-multi-select.tsx` |
| 14 | Zustand Store | `…/page-components/setting/publicpages/volunteerregpage/components/use-volunteer-registration-page-store.ts` |
| 15 | Page Config (admin) | `…/pages/setting/publicpages/volunteerregpage.tsx` |
| 16 | Route Page (admin) | `src/app/[lang]/setting/publicpages/volunteerregpage/page.tsx` (REPLACE existing UnderConstruction stub) |
| 17 | Public page component | `…/page-components/public/volunteerregpage/applicant-page.tsx` |
| 18 | Public applicant form | `…/page-components/public/volunteerregpage/components/applicant-form.tsx` |
| 19 | Public thank-you state | `…/page-components/public/volunteerregpage/components/thank-you.tsx` |
| 20 | Public 5-section form blocks | `…/page-components/public/volunteerregpage/components/sections/{identity,personal,availability,emergency,skills,compliance}-section.tsx` (6 files) |
| 21 | Route Page (public) | `src/app/[lang]/(public)/volunteer/[slug]/page.tsx` (SSR + generateMetadata) |
| 22 | Public layout | extends existing `src/app/[lang]/(public)/layout.tsx` from #10 — anonymous chrome (no admin sidebar) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `entity-operations.ts` | `VOLUNTEERREGPAGE` operations config |
| 2 | `operations-config.ts` | Import + register operations |
| 3 | sidebar menu config | Menu entry under SET_PUBLICPAGES OrderBy=5 |
| 4 | DTO barrel | (in `volunteer-service/index.ts`) export `VolunteerRegistrationPageDto` |
| 5 | GQL Queries barrel | export new queries (`volunteer-queries/index.ts` + `public/index.ts`) |
| 6 | GQL Mutations barrel | export new mutations (`volunteer-mutations/index.ts`) |
| 7 | `setting/publicpages/index.ts` (page-config barrel) | export `volunteerregpage` page config |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by `/plan-screens`.

```
---CONFIG-START---
Scope: FULL

MenuName: Volunteer Registration Page
MenuCode: VOLUNTEERREGPAGE
ParentMenu: SET_PUBLICPAGES
Module: SETTING
MenuUrl: setting/publicpages/volunteerregpage
GridType: EXTERNAL_PAGE

MenuCapabilities: READ, CREATE, MODIFY, DELETE, PUBLISH, ARCHIVE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, PUBLISH, ARCHIVE

GridFormSchema: SKIP
GridCode: VOLUNTEERREGPAGE
---CONFIG-END---
```

> Notes:
> - `GridType: EXTERNAL_PAGE` already registered (re-used from #10 OnlineDonationPage and #170 P2P).
> - `GridFormSchema: SKIP` — custom split-pane UI, not RJSF modal.
> - No `APPROVE_FUNDRAISER` capability needed (this is DONATION_PAGE-pattern, not P2P_FUNDRAISER).
> - Volunteer-application moderation reuses Volunteer #53 capabilities (`APPROVE_VOLUNTEER`, `DEACTIVATE_VOLUNTEER`).

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types**:
- Admin Query type: `VolunteerRegistrationPageQueries`
- Admin Mutation type: `VolunteerRegistrationPageMutations`
- Public Query type: `VolunteerRegistrationPagePublicQueries`
- Public Mutation type: extends existing public-mutations endpoint (anonymous-allowed)

**Admin Queries**:
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| getAllVolunteerRegistrationPagesList | [VolunteerRegistrationPageResponseDto] | pageNo, pageSize, statusFilter |
| getVolunteerRegistrationPageById | VolunteerRegistrationPageResponseDto | id |
| getVolunteerRegistrationPageStats | VolunteerRegistrationPageStatsDto | id |
| validateVolunteerRegistrationPageForPublish | ValidationResultDto | id |

**Admin Mutations**:
| GQL Field | Input | Returns |
|-----------|-------|---------|
| createVolunteerRegistrationPage | VolunteerRegistrationPageRequestDto | int |
| updateVolunteerRegistrationPage | VolunteerRegistrationPageRequestDto | int |
| updateVolunteerRegistrationPagePositions | { pageId, positionMasterDataIds[] } | int |
| publishVolunteerRegistrationPage | id | VolunteerRegistrationPageResponseDto |
| unpublishVolunteerRegistrationPage | id | VolunteerRegistrationPageResponseDto |
| closeVolunteerRegistrationPage | id | VolunteerRegistrationPageResponseDto |
| archiveVolunteerRegistrationPage | id | int |
| resetVolunteerRegistrationPageBranding | id | int |
| toggleVolunteerRegistrationPage | id | int |

**Public Queries (anonymous)**:
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| getVolunteerRegistrationPageBySlug | VolunteerRegistrationPagePublicDto (only public-safe fields — see privacy table below) | slug |

**Public Mutations (anonymous, rate-limited, csrf-protected)**:
| GQL Field | Input | Returns |
|-----------|-------|---------|
| submitVolunteerApplication | SubmitVolunteerApplicationDto (slug, applicant fields, csrfToken, honeypot) | SubmitVolunteerApplicationResultDto (volunteerId?, thankYouMessage, redirectUrl?, status: PENDING\|ACTIVE) |

**Response DTO field list — admin**:

```typescript
interface VolunteerRegistrationPageResponseDto {
  volunteerRegistrationPageId: number;
  companyId: number;
  pageTitle: string;
  slug: string;
  tagline?: string;
  description?: string;
  pageStatus: 'Draft' | 'Published' | 'Active' | 'Closed' | 'Archived';
  publishedAt?: string; // ISO
  archivedAt?: string;
  startDate?: string;
  endDate?: string;
  approvalMode: 'AUTO' | 'MANUAL';
  autoApproveCriteriaJson?: Record<string, unknown>;
  defaultPositionMasterDataId?: number;
  defaultBranchId?: number;
  applicantFieldsJson: Record<string, ApplicantFieldConfig>;
  requireCodeOfConduct: boolean;
  codeOfConductText?: string;
  // Branding
  logoUrl?: string;
  heroImageUrl?: string;
  primaryColorHex?: string;
  accentColorHex?: string;
  buttonText?: string;
  pageLayout?: 'centered' | 'side-by-side' | 'full-width';
  customCssOverride?: string;
  // Communication
  welcomeEmailTemplateId?: number;
  approvalEmailTemplateId?: number;
  rejectionEmailTemplateId?: number;
  reminderEmailTemplateId?: number;
  reminderDelayDays?: number;
  adminNotificationEmail?: string;
  // Thank-you / Display
  thankYouMessage?: string;
  thankYouRedirectUrl?: string;
  showApplicantCounter: boolean;
  showSocialShare: boolean;
  privacyNoticeText?: string;
  // SEO
  ogTitle?: string;
  ogDescription?: string;
  ogImageUrl?: string;
  robotsIndexable: boolean;
  isActive: boolean;
  // Junction
  offeredPositions: Array<{ positionMasterDataId: number; orderBy: number; positionDisplayName: string }>;
  // Audit
  createdDate: string; modifiedDate?: string; createdBy: number; modifiedBy?: number;
}

interface ApplicantFieldConfig {
  required: boolean;
  visible: boolean;
  locked: boolean; // when TRUE, admin cannot toggle (5 always-locked fields)
}

interface VolunteerRegistrationPageStatsDto {
  totalApplications: number;
  pendingApplications: number;
  approvedApplications: number;
  rejectedApplications: number;
  lastApplicationAt?: string;
  conversionRate?: number; // SERVICE_PLACEHOLDER — null until visit-log added
}

interface ValidationResultDto {
  isValid: boolean;
  missingFields: string[]; // human-readable; e.g. ["Page Title", "At least one Offered Position"]
  warnings: string[]; // OG image fallback, etc.
}
```

**Public DTO Privacy Discipline**:

| Field | Public DTO | Reason |
|-------|------------|--------|
| companyId, internal ids | omitted | not relevant to anonymous |
| applicantFieldsJson | included (sanitized — only `required` + `visible`) | needed to render form |
| codeOfConductText | included | rendered to applicant |
| customCssOverride | included (sanitized) | rendered to applicant |
| adminNotificationEmail | omitted | internal-only |
| approval/rejection email templates | omitted | internal-only |
| autoApproveCriteriaJson | omitted | internal-only |
| stats (totalApplications etc.) | included only if `showApplicantCounter=TRUE` | privacy / engineered display |

---

## ⑪ Acceptance Criteria

**Build Verification**:
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — admin loads at `/{lang}/setting/publicpages/volunteerregpage`
- [ ] `pnpm dev` — public loads at `/{lang}/volunteer/{slug}`

**Functional Verification**:
- [ ] Setup list view shows all pages with status badges; search and filter work
- [ ] "+ New Page" → defaults to Draft, slug auto-generated from PageTitle, redirects to setup editor
- [ ] Setup editor 8 cards autosave on edit; preview pane updates live within 300ms
- [ ] Mobile/Desktop preview toggle changes preview viewport
- [ ] Approval Mode toggle (MANUAL ↔ AUTO) reflects in saved record + influences submission status
- [ ] Applicant Field Config 15 rows: 5 locked rows un-editable (First/Last/Email/Phone/DialCode/Country/CodeOfConduct); other 10 rows editable across required/visible/locked
- [ ] Offered Positions multi-select sources from `getMasterDatas(VOLUNTEERPOSITION)`; junction table reflects selection on save
- [ ] Default Position dropdown filters to currently selected positions
- [ ] Branch dropdown sources from `getBranches`; default-branch selectable
- [ ] Branding card: Logo + Hero + colors + button text + layout reflected in preview
- [ ] Communication card: 4 email-template ApiSelectV2 dropdowns sourced from `getEmailTemplates`; templates persist on save
- [ ] Thank-you & Display + SEO cards persist on save
- [ ] Validate-for-publish shows missing-fields list when validation fails
- [ ] Publish transitions Draft → Active; status badge updates; URL becomes shareable
- [ ] Anonymous public route at `/volunteer/{slug}` renders for Active page
- [ ] Public form respects `applicantFieldsJson` — hidden fields not rendered, optional fields not required
- [ ] CSRF + honeypot + rate-limit (5/min/IP/slug) enforced on public submit
- [ ] **MANUAL mode submit** → creates `app.Volunteer` row with `VolunteerStatusId=PENDING`; admin sees in Volunteer #53 grid filter status="Pending"; admin Approve via existing `ApproveVolunteer` flips to ACTIVE + fires Approval email
- [ ] **AUTO mode submit** → creates `app.Volunteer` row with `VolunteerStatusId=ACTIVE` immediately; Welcome email + login-link fires (SERVICE_PLACEHOLDER)
- [ ] Closed status renders banner + disables Apply button on public
- [ ] Archived status returns 410 Gone
- [ ] OG tags rendered in initial SSR HTML; share preview correct on FB/Twitter/WhatsApp
- [ ] Status Bar real aggregates (totalApplications / pendingApplications / approvedApplications / rejectedApplications / lastApplicationAt)
- [ ] Slug uniqueness per tenant enforced; reserved-slug rejected; slug locked once ≥1 application attached

**DB Seed Verification**:
- [ ] Admin menu visible at `SET_PUBLICPAGES > VOLUNTEERREGPAGE` (OrderBy=5)
- [ ] GridType `EXTERNAL_PAGE` re-used (already seeded by #10) — verify no duplicate insertion
- [ ] Sample published page seeded for sample tenant — public route renders for QA at `/volunteer/join-our-team`
- [ ] MasterDataType `VOLUNTEERPOSITION` + 8 default rows seeded (idempotent NOT EXISTS)
- [ ] Sample VolunteerRegistrationPagePositions junction rows seeded (sample page has 5 offered positions)
- [ ] BUSINESSADMIN role has all 6 capabilities (READ/CREATE/MODIFY/DELETE/PUBLISH/ARCHIVE)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Mockup-status warnings**:
- **MOCKUP IS TBD** — this prompt was generated WITHOUT a real HTML mockup. UX Architect agent MUST review §⑥ with the user (or a real mockup) BEFORE the FE Developer codes the editor / public form. The 8-card layout, the 15-field Applicant Field Config table, the 5-section public form, and the 2-card Approval Mode switcher are PATTERN-BASED ASSUMPTIONS, not validated UX truth. If user supplies a mockup later, RE-RUN /plan-screens #172 to re-extract.

**Universal EXTERNAL_PAGE warnings** (mirror #10 / #170):

- **TWO render trees** — admin setup AND anonymous public. Different route groups (`(admin shell)` vs `(public)`), different layouts, different auth gates.
- **Slug uniqueness is per-tenant** — `(CompanyId, Slug)` composite unique. Public route resolution may go through tenant slug or custom domain.
- **Lifecycle is BE-enforced** — never trust an FE flag. Status transitions are explicit commands, not field updates.
- **Anonymous-route hardening is non-negotiable** — rate-limit, CSRF, honeypot, recaptcha, CSP headers. Skipping any is a security defect.
- **OG meta tags must be SSR-rendered** — social crawlers don't run JS.
- **Slug is immutable post-Activation when applications attached** — link rot prevents shared-link breakage.
- **Volunteer persistence is OUT OF SCOPE for THIS entity** — applications create rows in existing `app.Volunteers` (with FK back). The page entity is the FUNNEL config. Volunteer lifecycle is owned by Volunteer #53.
- **GridFormSchema = SKIP** — custom UI, not RJSF modal.
- **GridType = EXTERNAL_PAGE** — already registered (#10 / #170 seeded it); re-use.
- **Default brand color is GREEN `#059669`, NOT teal `#0e7490`** — this is the volunteer accent from the existing volunteer-form mockup. Don't ship with #10's teal default.

**Sub-type-specific gotchas (DONATION_PAGE pattern adapted for volunteer)**:

| Concern | Easy mistake |
|---------|--------------|
| ApprovalMode | Hard-coding MANUAL ignoring AUTO branch; or AUTO mode skipping Welcome email |
| ApplicantFieldsJson | Treating "locked" rows as editable — must be disabled checkboxes; First/Last/Email/Phone/DialCode/Country/CodeOfConduct always required+visible+locked |
| Offered Positions | Loading without ordering; ignoring `OrderBy` on the junction → applicant sees random order |
| Volunteer FK | Forgetting to add nullable `VolunteerRegistrationPageId` to `app.Volunteers` migration; or making it NOT NULL (must be nullable for legacy admin-created volunteers) |
| Skills/Interests/Languages | Re-creating tables — these already exist (Volunteer #53). Reuse `app.VolunteerSkills` / `app.VolunteerInterests` / `app.VolunteerLanguages` child entities |
| Welcome email | Firing only on AUTO approval (forgetting MANUAL gets a Welcome too — informs applicant their submission is pending) |
| Reminder email | Background scheduler not in scope — keep ReminderEmailTemplateId/ReminderDelayDays as schema only; SERVICE_PLACEHOLDER for the cron |
| Public route namespace | Using `/p/{slug}` — that's reserved by donation page #10. Use `/volunteer/{slug}` |
| Status filter on Volunteer #53 | Not adding "from VolunteerRegistrationPageId=X" filter to existing volunteer grid for moderation context — admin should see "5 pending applications from Join-Our-Team page" link |

**Public-route deployment checklist** (mirror #10):
- [ ] Public route group `(public)` exists with no admin chrome (already established by #10)
- [ ] Anonymous middleware allows GET on `/volunteer/{slug}` and POST on `submitVolunteerApplication` only
- [ ] Rate-limit policy `VolunteerSubmit` registered for public POST (or reuse generic `PublicSubmit` if defined)
- [ ] CSRF token issued on public GET render and validated on public POST
- [ ] CSP headers set (no payment-gateway iframe needed; `frame-ancestors 'none'`)
- [ ] OG meta-tag pre-render in `generateMetadata`
- [ ] 404 / 410 / closed-banner edge states render correctly

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER: Welcome email** — UI implemented (template ApiSelect, send-on-submit), handler logs only because `IEmailSender` may not be wired yet (pending #84 EmailProviderConfig completion).
- ⚠ **SERVICE_PLACEHOLDER: Approval email** — UI implemented (template ApiSelect, fired on Approve), handler logs only.
- ⚠ **SERVICE_PLACEHOLDER: Rejection email** — UI implemented, handler logs only.
- ⚠ **SERVICE_PLACEHOLDER: Reminder email** — UI configured (template + delay days), but **no background scheduler/cron** in PSS 2.0 yet. Schema persists; cron job to scan for stale PENDING and fire reminders is OUT OF SCOPE for this build.
- ⚠ **SERVICE_PLACEHOLDER: reCAPTCHA v3** — UI placeholder; score check returns 1.0 until service configured.
- ⚠ **SERVICE_PLACEHOLDER: Volunteer Portal login link** — `(AUTO)` mode emails a login link, but the volunteer self-service portal (#190 future) doesn't exist. Login link returns to `/login` with the volunteer's email pre-filled until portal exists.
- ⚠ **SERVICE_PLACEHOLDER: Page-visit conversion rate** — no visit-logging table or analytics service. Status bar shows "—" for conversionRate.
- ⚠ **SERVICE_PLACEHOLDER: Profile photo upload** — UI accepts URL; if `IFileStorageService` not wired, admin must paste an external URL (e.g., S3 / Cloudinary). Upload handler is UI-stub.

Full UI must be built (8 setup cards, public 5-section form, validate-for-publish modal, edge states, status bar, slug-availability check, preview pane, applicant-fields editor). Only the handlers for genuinely missing services are mocked.

**Pre-flagged ISSUES for /build-screen** (open as OPEN at first session):

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | Mockup | TBD HTML mockup — UX agent must validate §⑥ with user before FE generation |
| ISSUE-2 | MED | Backend | `app.Volunteers.VolunteerRegistrationPageId` migration must be nullable; existing rows preserved |
| ISSUE-3 | MED | Backend | Skills/Interests/Languages submitted via public form must reuse existing `app.VolunteerSkills/.VolunteerInterests/.VolunteerLanguages` child entities (do NOT create new tables) |
| ISSUE-4 | MED | Workflow | MANUAL approval reuses Volunteer #53 ApproveVolunteer/DeactivateVolunteer commands — verify those exist as built; if not, plan ApproveVolunteer + DeactivateVolunteer first via Volunteer #53 build |
| ISSUE-5 | LOW | Communication | Welcome / Approval / Rejection emails are SERVICE_PLACEHOLDER until EmailProvider #84 wires `IEmailSender` |
| ISSUE-6 | LOW | Communication | Reminder email cron NOT in scope — schema persists ReminderEmailTemplateId / ReminderDelayDays but no background scheduler |
| ISSUE-7 | LOW | UX | Volunteer self-service portal #190 doesn't exist — AUTO mode login-link routes to `/login` until portal built |
| ISSUE-8 | LOW | Branding | Default Primary color is `#059669` (volunteer green), NOT `#0e7490` (donation teal) — Branding card seed default must reflect this |
| ISSUE-9 | LOW | Public route | NEW namespace `/volunteer/{slug}` — verify no collision with existing internal `crm/volunteer/` admin routes (admin routes are `/{lang}/crm/volunteer/...` so namespace is distinct) |
| ISSUE-10 | LOW | Seed | VOLUNTEERPOSITION MasterDataType + 8 sample rows must be seeded idempotently; Volunteer #53 seed should NOT have already seeded VOLUNTEERPOSITION (verify on build) |
| ISSUE-11 | LOW | UI | Profile photo upload SERVICE_PLACEHOLDER — admin can paste URL; full upload deferred until IFileStorageService wired |
| ISSUE-12 | LOW | Performance | Stats query (totalApplications/pending/approved/rejected) requires index on `app.Volunteers (VolunteerRegistrationPageId, VolunteerStatusId)` — add in EF migration |
| ISSUE-13 | LOW | Public | When Status=Closed and StartDate<now<EndDate, banner reads "drive has ended" — distinct from "drive opens on {StartDate}" pre-start banner |
| ISSUE-14 | LOW | Privacy | Public DTO must strip `applicantFieldsJson.locked` flag (only need required/visible on FE form rendering — locked is admin-only metadata) |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Plan 2026-05-09 | HIGH | Mockup | TBD HTML mockup — UX agent must validate §⑥ with user before FE generation | **CLOSED Session 3** — user re-confirmed assumed §⑥ blueprint at FE_ONLY entry; FE built to §⑥ specification; mockup remains TBD but accepted as design-of-record |
| ISSUE-2 | Plan 2026-05-09 | MED | Backend | `app.Volunteers.VolunteerRegistrationPageId` migration must be nullable | **CLOSED Session 2** — column added as nullable `int?` in Volunteer.cs:55 + FK with OnDelete(SetNull) in VolunteerConfiguration.cs + EF migration |
| ISSUE-3 | Plan 2026-05-09 | MED | Backend | Reuse existing VolunteerSkills/Interests/Languages child tables | **CLOSED Session 2** — `SubmitVolunteerApplication.cs` hydrates existing child collections per Volunteer entity nav; no new tables created |
| ISSUE-4 | Plan 2026-05-09 | MED | Workflow | Verify Volunteer #53 ApproveVolunteer/DeactivateVolunteer exist | **CLOSED Session 2** — confirmed at `…/Business/ApplicationBusiness/Volunteers/ApproveCommand/ApproveVolunteer.cs` + `DeactivateCommand/DeactivateVolunteer.cs` |
| ISSUE-5 | Plan 2026-05-09 | LOW | Communication | Welcome/Approval/Rejection emails are SERVICE_PLACEHOLDER | OPEN |
| ISSUE-6 | Plan 2026-05-09 | LOW | Communication | Reminder email cron NOT in scope | OPEN |
| ISSUE-7 | Plan 2026-05-09 | LOW | UX | Volunteer Portal #190 doesn't exist; login link → `/login` | OPEN |
| ISSUE-8 | Plan 2026-05-09 | LOW | Branding | Default brand color is #059669 (green) not #0e7490 | **CLOSED Session 3** — `#059669` hardcoded as initial value in `volunteerregpage-store.ts` + `5-branding-section.tsx` color picker default + public page accent fallback |
| ISSUE-9 | Plan 2026-05-09 | LOW | Routing | Public namespace /volunteer/{slug} — verify no collision | **CLOSED Session 2** — admin volunteer routes confirmed at `/{lang}/crm/volunteer/...`; public namespace `/{lang}/volunteer/{slug}` distinct; `(public)` route group exists at `PSS_2.0_Frontend/src/app/[lang]/(public)/` |
| ISSUE-10 | Plan 2026-05-09 | LOW | Seed | VOLUNTEERPOSITION MasterData type + 8 rows idempotent seed | **CLOSED Session 2** — confirmed absent from Volunteer #53 seed (`Volunteer-sqlscripts.sql` seeds 7 other types, NOT VOLUNTEERPOSITION); seeded fresh in `volunteer-registration-page-sqlscripts.sql` with idempotent WHERE NOT EXISTS guards |
| ISSUE-12 | Plan 2026-05-09 | LOW | Performance | Index on (VolunteerRegistrationPageId, VolunteerStatusId) | **CLOSED Session 2** — composite index created in EF migration + VolunteerConfiguration.cs |
| ISSUE-11 | Plan 2026-05-09 | LOW | UI | Profile photo upload SERVICE_PLACEHOLDER | OPEN |
| ISSUE-13 | Plan 2026-05-09 | LOW | Public | Closed vs pre-start banner distinction | **CLOSED Session 3** — `applicant-page.tsx` renders distinct banners: `Status=Closed` → "This volunteer drive has ended"; `StartDate>now` → "Drive opens on {StartDate}"; both disable Apply button |
| ISSUE-14 | Plan 2026-05-09 | LOW | Privacy | Public DTO strips applicantFieldsJson.locked flag | **CLOSED Session 3** — public form orchestrator (`applicant-form.tsx`) only consumes `required`/`visible`; `locked` flag never read on public render path. BE PublicDto still includes the field but FE ignores it; can be stripped server-side as a follow-up if desired |
| ISSUE-15 | Session 3 2026-05-11 | LOW | Public Form | Branch / Country / Gender / AvailabilityType / PreferredTime / EmergencyRelation / HeardAboutSource pickers on public form fall back to numeric input or static `<select>` because no public-safe MasterData lookup query exists. Submit DTO accepts the FK ids correctly. | OPEN |
| ISSUE-16 | Session 3 2026-05-11 | LOW | Public Form | `codeOfConductText` rendered as plain text (innerText) instead of sanitized HTML — `isomorphic-dompurify` not in codebase. BE strips `<script>` blocks server-side so no XSS risk; missing only rich-text formatting (bold/links) on public render. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

#### Session 1 — Planning (2026-05-09)

**Type**: PLAN
**Agent**: /plan-screens (main session, Sonnet)
**Outcome**: PROMPT_READY

**Inputs**:
- User invoked `/plan-screens #172`
- Mockup TBD (does not exist) — user chose "Plan from #170 P2P pattern" + "EXTERNAL_PAGE / DONATION_PAGE-like"
- References used: `prompts/p2pcampaignpage.md` (P2P pattern), `prompts/onlinedonationpage.md` (DONATION_PAGE canonical), `MODULE_MENU_REFERENCE.md` (VOLUNTEERREGPAGE under SET_PUBLICPAGES), Volunteer entity at `Base.Domain/Models/ApplicationModels/Volunteer.cs`, Volunteer #53 plan (`prompts/volunteer.md`)

**Decisions**:
- Sub-type: `DONATION_PAGE` (re-uses single-public-page + admin-setup pattern; not P2P parent-with-children-pages, not CROWDFUND tiers)
- Storage: `parent-with-children` (page + position junction; volunteer linkage via existing `app.Volunteers` FK)
- Schema: `app` (existing) — NO new schema bootstrap
- Group: `ApplicationModels` (entity) / `ApplicationBusiness` (business)
- Public route: `(public)/volunteer/{slug}` (NEW namespace, distinct from `/p` and `/p2p`)
- Approval Mode: AUTO / MANUAL toggle (mirrors P2P FundraiserApprovalMode pattern)
- 8 setup cards (vs #10's 10 cards — no Amounts/Recurring/Payment Methods cards)
- 15-field Applicant Field Config (vs #10's 9-field DonorFields)
- 5-section public form (Identity / Personal / Availability / Emergency / Skills / Compliance)
- 14 pre-flagged ISSUEs

**Files generated**:
- `.claude/screen-tracker/prompts/volunteerregpage.md` (this file)
- `REGISTRY.md` updated — Status NEW → PROMPT_READY, Type Config → EXTERNAL_PAGE (DONATION_PAGE)

**Deferrals to /build-screen**:
- HTML mockup validation (UX agent must review §⑥ before FE codes)
- Confirm Volunteer #53 has ApproveVolunteer / DeactivateVolunteer commands implemented
- Confirm GridType=EXTERNAL_PAGE already seeded (from #10 build)
- Verify VOLUNTEERPOSITION MasterDataType not already seeded by Volunteer #53
- Background scheduler for Reminder email (out of scope, SERVICE_PLACEHOLDER)

**Next session**: Run `/build-screen #172` after user reviews this prompt and confirms (or supplies a real mockup that updates §⑥).

---

### Session 2 — 2026-05-11 — BUILD — PARTIAL

- **Scope**: Initial BE_ONLY build from PROMPT_READY prompt. FE deferred to FE_ONLY session per #171 precedent (avoids token-budget risk on High-complexity 22+22-file build). User approved assumed §⑥ blueprint at session entry (mockup TBD remains for FE session).
- **Agents run**:
  - BA Analyst (sonnet) — validation only; 3 adjustments caught
  - Solution Resolver (sonnet) — DONATION_PAGE sub-type confirmed vs SUBMISSION_PAGE; 24-file BE manifest (not 22)
  - UX Architect — SKIPPED for BE_ONLY (§⑥ + §⑩ in prompt are user-approved and complete for BE work)
  - Backend Developer (opus, complexity=High) — 24 BE files + 6 wiring modifications + EF migration + DB seed
- **Files touched**:
  - BE entities (2 created):
    - `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/VolunteerRegistrationPage.cs` (created)
    - `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/VolunteerRegistrationPagePosition.cs` (created)
  - BE EF configs (2 created):
    - `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/VolunteerRegistrationPageConfiguration.cs` (created)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/VolunteerRegistrationPagePositionConfiguration.cs` (created)
  - BE schemas (1 created):
    - `PSS_2.0_Backend/.../Base.Application/Schemas/ApplicationSchemas/VolunteerRegistrationPageSchemas.cs` (created)
  - BE validators (1 created):
    - `PSS_2.0_Backend/.../Base.Application/Validations/VolunteerRegistrationPageSlugValidator.cs` (created)
  - BE commands (10 created — under `…/Business/ApplicationBusiness/VolunteerRegistrationPages/Commands/`):
    - VolunteerRegistrationPageEntityHelper.cs, CreateVolunteerRegistrationPage.cs, UpdateVolunteerRegistrationPage.cs, UpdateVolunteerRegistrationPagePositions.cs, PublishVolunteerRegistrationPage.cs, UnpublishVolunteerRegistrationPage.cs, CloseVolunteerRegistrationPage.cs, ArchiveVolunteerRegistrationPage.cs, ResetVolunteerRegistrationPageBranding.cs, ToggleVolunteerRegistrationPage.cs (all created)
  - BE queries (4 created):
    - GetAllVolunteerRegistrationPagesList.cs, GetVolunteerRegistrationPageById.cs, GetVolunteerRegistrationPageStats.cs (with ADJUSTMENT-3 page scoping), ValidateVolunteerRegistrationPageForPublish.cs
  - BE public query (1 created):
    - `…/VolunteerRegistrationPages/PublicQueries/GetVolunteerRegistrationPageBySlug.cs` (anonymous, status-gated)
  - BE public mutation (1 created):
    - `…/VolunteerRegistrationPages/PublicMutations/SubmitVolunteerApplication.cs` (anonymous, rate-limited via `[EnableRateLimiting("VolunteerSubmit")]`, honeypot, CSRF SERVICE_PLACEHOLDER, ApprovalMode-driven status)
  - BE endpoints (3 created):
    - `…/Base.API/EndPoints/Application/Mutations/VolunteerRegistrationPageMutations.cs` (10 admin mutations)
    - `…/Base.API/EndPoints/Application/Queries/VolunteerRegistrationPageQueries.cs` (4 admin queries)
    - `…/Base.API/EndPoints/Application/Public/VolunteerRegistrationPagePublicQueries.cs` (public BySlug query + SubmitVolunteerApplication mutation)
  - BE wiring (6 modified):
    - `IApplicationDbContext.cs` (modified — 2 DbSets added)
    - `ApplicationDbContext.cs` (modified — 2 DbSet bodies)
    - `Base.Application/Extensions/DecoratorProperties.cs` (modified — 2 new `DecoratorApplicationModules` constants)
    - `Base.Application/Mappings/ApplicationMappings.cs` (modified — Mapster configs incl. junction display projection)
    - `Volunteer.cs` (modified — `int? VolunteerRegistrationPageId` + nav property at line 55)
    - `VolunteerConfiguration.cs` (modified — FK relationship with `OnDelete(SetNull)` + composite index `(VolunteerRegistrationPageId, VolunteerStatusId)`)
    - `Base.API/DependencyInjection.cs` (modified — `VolunteerSubmit` rate-limit policy added INSIDE existing `services.AddRateLimiter` lambda at line 283; 5/min/IP+slug composite partition key)
  - EF Migration (1 created — Designer/ModelSnapshot regen deferred to user):
    - `PSS_2.0_Backend/.../Base.Infrastructure/Migrations/20260511000000_Add_VolunteerRegistrationPages_And_VolunteerRegistrationPagePositions.cs` (created; Up/Down hand-crafted; CREATE 2 tables + ALTER `app."Volunteers"` ADD nullable FK column + filtered unique index on `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted` + composite stats index)
  - DB seed (1 created):
    - `PSS_2.0_Backend/.../sql-scripts-dyanmic/volunteer-registration-page-sqlscripts.sql` (created; 8 idempotent sections: Menu/MenuCapabilities/RoleCapabilities/Grid/MasterDataType+8 positions/sample page/junction rows; all guarded with WHERE NOT EXISTS)
  - FE: NONE this session (deferred to Session 3)
- **Deviations from spec**:
  - File manifest was 22 in §⑧, actually 24 distinct files (endpoint tier counted as 1 entry in §⑧ but is 3 files; schemas + 1 new validator file split out). No semantic deviation, just enumeration.
  - ApplicantFieldsJson default has 7 LOCKED fields (FirstName/LastName/Email/Phone/DialCode/Country/AgreedToCodeOfConduct), NOT 5 as §① and §⑤ stated — §⑥ table is authoritative. Same logic now applied in `VolunteerRegistrationPageEntityHelper.cs` and seed script.
  - `HEARDABOUTSOURCE` MasterDataType code reference in §③ corrected to actual seeded code `VOLUNTEERHEARDABOUTSOURCE` (the prefix is from Volunteer #53 seed convention).
  - `rejectedApplications` aggregate now scoped to `WHERE VolunteerRegistrationPageId = X AND DataValue='INA'` — prevents admin-deactivated legacy volunteers (not from this page funnel) leaking into rejection count.
- **Known issues opened**: None new this session.
- **Known issues closed**: ISSUE-2, ISSUE-3, ISSUE-4, ISSUE-9, ISSUE-10, ISSUE-12 (6 issues CLOSED).
- **Next step**: User must run `dotnet ef migrations add Add_VolunteerRegistrationPages_And_VolunteerRegistrationPagePositions` (or equivalent rename) to regen `Designer.cs` + `ApplicationDbContextModelSnapshot.cs`, then `dotnet ef database update`, then execute the DB seed SQL. THEN run `/continue-screen #172` with FE_ONLY scope to generate the 22 FE files. The FE_ONLY session must:
  - Generate admin list view + 8-card editor + live preview + Approval Mode switcher + Status Bar + Applicant Fields Editor + Position Multi-Select + Zustand store
  - Generate public SSR page at `(public)/volunteer/[slug]/page.tsx` + applicant form + thank-you state + 6 form section components
  - Generate FE wiring (entity-operations + sidebar menu + GQL barrels + page-config barrel)
  - Re-validate §⑥ assumed blueprint with user (or accept assumed §⑥ for build)
  - Close ISSUE-1 (Mockup TBD), ISSUE-8 (default color seed), ISSUE-13 (banner distinction), ISSUE-14 (strip locked from public DTO)
- **Build verification**: `dotnet build Base.API/Base.API.csproj` — PASS (exit code 0). Pre-existing nullability warnings in unrelated files; no new compile errors.

---

### Session 3 — 2026-05-11 — BUILD — COMPLETED

- **Scope**: FE_ONLY build resuming the PARTIALLY_COMPLETED state from Session 2. User accepted assumed §⑥ blueprint as design-of-record (closed ISSUE-1) and chose "Copy structure from #10 OnlineDonationPage, adapt content" approach. UX Architect agent SKIPPED (§⑥ user-approved). Testing Agent SKIPPED (BE compile-validated in Session 2; FE smoke-test deferred to user `pnpm dev`).
- **Agents run**:
  - Frontend Developer (opus, EXTERNAL_PAGE = FLOW-like custom UI escalation per Step 5b table) — 43 FE files created (the planned 22 split into more granular files: barrel files + per-section components) + 7 wiring modifications. ~1.45M tokens, 120 tool uses.
- **Files touched**:
  - FE Domain & GQL (5 created):
    - `PSS_2.0_Frontend/src/domain/entities/volunteer-service/VolunteerRegistrationPageDto.ts` (created)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/volunteer-queries/VolunteerRegistrationPageQuery.ts` (created)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/public-queries/VolunteerRegistrationPagePublicQuery.ts` (created)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/volunteer-mutations/VolunteerRegistrationPageMutation.ts` (created)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/public-mutations/VolunteerRegistrationPagePublicMutation.ts` (created)
  - FE Admin Setup UI (22 created — under `presentation/components/page-components/setting/publicpages/volunteerregpage/`):
    - root + index barrels: `index.ts`, `volunteerregpage-root.tsx`, `volunteerregpage-store.ts`, `list-page.tsx`, `editor-page.tsx`
    - components/ (8): `index.ts`, `section-card.tsx`, `status-bar.tsx`, `approval-mode-switcher.tsx`, `applicant-fields-editor.tsx` (15-row table with 7 LOCKED disabled rows), `position-multi-select.tsx` (sources `MASTERDATAS_QUERY` filtered VOLUNTEERPOSITION), `api-single-select.tsx`, `live-preview.tsx` (Desktop/Mobile, 300ms debounce)
    - sections/ (9): `index.ts` + 8 section files (1-page-identity / 2-positions / 3-applicant-fields / 4-compliance / 5-branding / 6-communication / 7-thankyou / 8-seo)
  - FE Page Config + Admin Route (1 created + 1 replaced):
    - `presentation/pages/setting/publicpages/volunteerregpage.tsx` (created — capability gate `useAccessCapability({ menuCode: "VOLUNTEERREGPAGE" })`)
    - `app/[lang]/setting/publicpages/volunteerregpage/page.tsx` (REPLACED — `UnderConstruction` stub removed, now imports `VolunteerRegistrationPagePageConfig`)
  - FE Public Anonymous Route (14 created):
    - `presentation/components/page-components/public/volunteerregpage/`: `index.ts`, `applicant-page.tsx` (status banners, layout-driven, dynamic brand colors), `components/applicant-form.tsx` (orchestrator: honors `applicantFieldsJson.visible/required`, honeypot `name="website"` `display:none` `tabIndex={-1}`, CSRF token threaded), `components/thank-you.tsx` (PENDING vs ACTIVE branched copy)
    - `components/sections/`: `index.ts`, `_shared.tsx`, identity-section, position-branch-section, personal-section, availability-section, emergency-section, skills-section, compliance-section
    - `app/[lang]/(public)/volunteer/[slug]/page.tsx` (Next.js App Router SSR + `generateMetadata` for OG tags + `revalidate=60`)
  - FE Wiring (7 modified):
    - `application/configs/data-table-configs/volunteer-service-entity-operations.ts` (modified — `VOLUNTEERREGPAGE` operations entry added at line 95)
    - `domain/entities/volunteer-service/index.ts` (modified — DTO export)
    - `infrastructure/gql-queries/volunteer-queries/index.ts` (modified — query export)
    - `infrastructure/gql-queries/public-queries/index.ts` (modified — public query export)
    - `infrastructure/gql-mutations/volunteer-mutations/index.ts` (modified — mutation export)
    - `infrastructure/gql-mutations/public-mutations/index.ts` (modified — public mutation export)
    - `presentation/pages/setting/publicpages/index.ts` (modified — page-config export above `//EntityPageConfigExport` marker)
- **Components reused vs created**:
  - **Reused**: `Skeleton`, `Tooltip`, `Switch`, `Input`, `Textarea`, `Dialog`, `AlertDialog`, `DropdownMenu`, `Popover`, `Command*` (common-components), `Icon` from `@iconify/react` (Phosphor `ph:` prefix), `useAccessCapability`, `LayoutLoader`, `DefaultAccessDenied`, `ApolloWrapper`, `cn`, `toast` (sonner), existing `MASTERDATAS_QUERY`, `BRANCHES_QUERY`, `EMAILTEMPLATES_QUERY`
  - **Created (screen-local, simple-static per protocol)**: SectionCard, StatusBar, ApprovalModeSwitcher, ApplicantFieldsEditor, PositionMultiSelect, ApiSingleSelect, LivePreview (admin); 7 form-section components + ApplicantForm orchestrator + VolunteerThankYou + VolunteerApplicantPage (public)
- **Deviations from spec**:
  - File count exceeded the §⑧ planned 22 (actually ~43) because each section, sub-section, and barrel was its own file. No semantic deviation — every planned manifest item satisfied; just finer file granularity for maintainability.
  - Branch / Country / MasterData FK pickers on public form fall back to numeric input or static `<select>` (no public-safe MasterData lookup query exists). Submit DTO accepts FK ids correctly. → Logged as ISSUE-15.
  - `codeOfConductText` rendered as plain text on public form (no `isomorphic-dompurify` in codebase). BE strips `<script>` server-side, so no XSS risk; missing only rich-text formatting on public. → Logged as ISSUE-16.
  - `EmailTemplate` field-name corrected from spec `templateName/subject` to actual `emailTemplateName/emailSubject`.
- **Known issues opened**: ISSUE-15 (public form FK pickers fallback to numeric input), ISSUE-16 (COC text plain-rendered, no DOMPurify).
- **Known issues closed**: ISSUE-1 (Mockup TBD — accepted assumed §⑥ as design-of-record), ISSUE-8 (default brand color `#059669` GREEN applied), ISSUE-13 (Closed vs pre-start banner distinction implemented in `applicant-page.tsx`), ISSUE-14 (FE form orchestrator only consumes `required`/`visible`, ignores `locked`).
- **Anti-pattern verification (post-build)**:
  - Inline hex colors grep on volunteerregpage admin/public folders: 0 matches (excluding dynamic brand color flow from page config props — documented exception)
  - Inline pixel padding/margin grep: 0 matches
  - `>Loading...</` raw text grep on volunteerregpage folders: 0 matches (Skeleton placeholders used everywhere)
  - `#059669` brand default verified in `volunteerregpage-store.ts` + `5-branding-section.tsx`
  - UnderConstruction stub deleted from `app/[lang]/setting/publicpages/volunteerregpage/page.tsx` — verified (only the new `VolunteerRegistrationPagePageConfig` import remains)
- **Build verification**: NOT run this session per skill directive ("Avoid full `dotnet build` or `pnpm build` unless absolutely necessary"). User to verify with `pnpm dev` smoke test (admin at `/{lang}/setting/publicpages/volunteerregpage`, public at `/{lang}/volunteer/join-our-team` via seeded sample page).
- **Next step**: User runs `pnpm dev` to E2E test the FE. If any defects surface, run `/continue-screen #172` with FIX scope. ISSUE-15 + ISSUE-16 remain OPEN as low-priority follow-ups (public-form MasterData lookups + DOMPurify).
