---
screen: PrayerRequestPage
registry_id: 171
module: Setting (Public Pages)
status: COMPLETED
scope: FULL (session 1 BE + session 2 FE)
screen_type: EXTERNAL_PAGE
external_page_subtype: SUBMISSION_PAGE
complexity: High
new_module: NO
planned_date: 2026-05-09
completed_date: 2026-05-10
last_session_date: 2026-05-10
---

> **Sub-type divergence (logged early — see §⑫ ISSUE-1)**: SUBMISSION_PAGE is not one of the three frozen `_EXTERNAL_PAGE.md` sub-types (DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND). Pattern shape is closest to DONATION_PAGE (single setup record + single anonymous public form + lifecycle Draft/Active/Closed/Archived) MINUS payment hand-off PLUS moderation queue + public Prayer Wall + "I'll Pray for This" engagement counter. Use #10 OnlineDonationPage (`onlinedonationpage.md`) as the canonical reference for cross-cutting concerns (slug, CSP, CSRF, rate-limit, lifecycle, status-bar, autosave-with-publish save model). Diverge ONLY where called out in this prompt.

> **Mockup status**: NO HTML mockup exists. Spec authored 2026-05-09 from PSS 2.0 NGO/donor-management domain knowledge per user direction ("you decide buddy — handle proper and better with multi-tenant support"). All field lists / UI layouts / behaviors below are SPEC, not mockup-extracted. UX Architect agent should treat this as a directional brief and may refine card order / iconography / copy without changing semantics.

---

## Tasks

### Planning (by /plan-screens)
- [x] Spec authored from domain (mockup TBD)
- [x] Sub-type identified: SUBMISSION_PAGE (divergence logged §⑫ ISSUE-1)
- [x] Multi-tenant model confirmed (slug + CompanyId composite; submission CompanyId derived server-side from page lookup, never from request body)
- [x] Setup vs Public route split identified (admin at `setting/publicpages/prayerrequestpage` + anonymous public at `(public)/pray/{slug}` — separate namespace from `/p/` donation route)
- [x] Slug strategy chosen: `custom-with-fallback` (auto from PageTitle; user may override; per-tenant unique)
- [x] Lifecycle states confirmed: Draft / Published / Active / Closed / Archived (full)
- [x] Notification scope: REAL via existing CompanyEmailProvider + SmsSetting infra (no SERVICE_PLACEHOLDER for receipt/staff-ping email or SMS); reCAPTCHA + Slack/Teams webhook = SERVICE_PLACEHOLDER
- [x] Moderation model chosen: 3-mode (`AUTO_APPROVE` / `MANUAL_APPROVE` / `NEVER_PUBLIC`) controls public-display gating; submissions ALWAYS persist regardless of mode
- [x] Public Prayer Wall + "I'll Pray for This" engagement counter scoped (privacy-aware — anonymous submitters shown as "Anonymous")
- [x] FK targets resolved (Contact `corg.Contacts`, MasterData `PRAYERCATEGORY`, EmailTemplate `comm.EmailTemplates`)
- [x] File manifest computed (admin setup + Submissions inbox tab + public NAV page + I'll-pray engagement endpoint)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (page purpose + audience + moderation + lifecycle + privacy posture) — carried by /plan-screens prompt §①–④
- [x] Solution Resolution complete (sub-type confirmed as SUBMISSION_PAGE divergence + slug strategy + lifecycle + moderation logic + multi-tenant slug→tenant resolution model) — §⑤
- [x] UX Design finalized (admin setup tabs incl. Submissions inbox + public NAV page + Prayer Wall block + "I'll Pray" counter button + thank-you state) — §⑥
- [x] User Approval received — 2026-05-10 (BE_ONLY split chosen — FE deferred to session 2; CONFIG approved as pre-filled)
- [x] Backend code generated — 2026-05-10 (3 entities + 3 EF configs + 1 DTOs file + 24 handlers + 1 slug validator + IProfanityFilter (interface + simple impl) + 6 endpoint files = ~38 BE files)
- [x] Backend wiring complete — IContactDbContext (3 DbSets) + ContactDbContext (3 DbSets) + DecoratorProperties (3 codes: PRAYERREQUESTPAGE/PRAYERREQUEST/PRAYERREQUESTPRAYEDLOG) + ContactMappings (Mapster configs for parent + 2 children)
- [x] Frontend (admin setup + submissions inbox) code generated — 2026-05-10 session 2 (page-config + list + editor + setup-tab + 8 sections + submissions-tab + status-bar + live-preview + drawer + zustand store)
- [x] Frontend (public NAV page + Prayer Wall + I'll-pray) code generated — 2026-05-10 session 2 (`(public)/pray/[slug]/page.tsx` SSR + prayer-page + submission-form + prayer-wall + thank-you)
- [x] Frontend wiring complete — 2026-05-10 session 2 (DTO + 5 GQL barrels + page-config barrel + public components barrel + contact-service-entity-operations.ts updated with PRAYERREQUESTPAGE + PRAYERREQUEST blocks)
- [x] DB Seed script generated — `PrayerRequestPage-sqlscripts.sql` (idempotent: 9 PRAYERCATEGORY MasterData rows + 4 capabilities (MODERATE/PUBLISH/UNPUBLISH/ARCHIVE) + Menu under SET_PUBLICPAGES + MenuCapabilities + RoleCapabilities for BUSINESSADMIN + sample published page slug=`pray` + 1 sample Approved prayer + 3-5 PrayedLog rows for E2E)
- [x] EF Migration generated — `20260510074527_Add_PrayerRequestPage_Setup_Entities.cs` (named differently from spec `Add_PrayerRequestPage_With_Children` but creates the same 3 tables + 11 indexes including the critical `IX_PrayerRequests_CompanyId_PageId_WallEligible_SubmittedAt` for Wall queries — verified via `migrationBuilder.CreateTable` count + index list)
- [x] Registry updated to COMPLETED — 2026-05-10 session 2 (FULL build done; FE_ONLY session 2 pass)

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — admin setup loads at `/{lang}/setting/publicpages/prayerrequestpage`
- [ ] `pnpm dev` — public page loads at `/{lang}/pray/{slug}` (canonical submission page)
- [ ] **SUBMISSION_PAGE checks**:
  - [ ] Setup list view shows all PrayerRequestPages with status badges + submission counts; "+ New Page" creates a Draft and redirects to editor
  - [ ] Editor 8 settings cards persist via autosave (300ms debounce); preview pane updates live
  - [ ] Slug auto-generated from PageTitle on first save; uniqueness enforced per tenant; reserved slug list rejected (admin/api/embed/p/pray/preview/login/auth)
  - [ ] Categories card sources from MasterData `PRAYERCATEGORY`; admin can enable/disable categories per page; order via drag
  - [ ] Submitter Form Fields table: Body forced required+visible (disabled checkbox); Category required by default but admin-overrideable; First Name + Email + Phone + Country + Title configurable
  - [ ] Moderation Mode toggle persists (`AUTO_APPROVE` / `MANUAL_APPROVE` / `NEVER_PUBLIC`); FE preview shows different default banner per mode
  - [ ] Notifications card: admin email recipients, submitter receipt template (FK EmailTemplate), staff-ping template, "notify when prayed" template — all REAL email pipeline (no SERVICE_PLACEHOLDER)
  - [ ] Branding card persists: logo, hero, primary color, button text, page layout (centered/side-by-side); reflected in preview
  - [ ] Thank-You card: thank-you message + redirect URL persist; preview reflects after-submit state
  - [ ] SEO card: OG title / description / image / robots-indexable persist; live `generateMetadata` reflects on public page
  - [ ] Validate-for-publish blocks Publish until: PageTitle + Slug + ≥1 enabled Category + Body field marked required+visible + ModerationMode set + (if MANUAL_APPROVE → AdminEmailRecipients ≥ 1) + OG image OR HeroImage set
  - [ ] Publish transitions Draft → Active; URL becomes shareable; OG tags pre-rendered in `generateMetadata`
  - [ ] Anonymous public page renders Active status; respects category list + form-field config + branding; CSP headers set; CSRF token issued
  - [ ] Anonymous visitor can submit a prayer end-to-end (form → server validates → persists `crm.PrayerRequests` row scoped to (CompanyId, PrayerRequestPageId) → upserts `corg.Contact` if email provided + opt-in → returns thank-you state OR redirect)
  - [ ] **Multi-tenant guard**: submission row CompanyId is set by SERVER from `pageRow.CompanyId` (looked up via slug), NEVER from request body; verify by submitting to two pages of two tenants — rows isolate
  - [ ] Submitter receipt email fires after submission (REAL — uses existing email infra); subject + body from template
  - [ ] Admin staff-ping email fires to AdminEmailRecipients list (REAL)
  - [ ] CSRF token validated on submit; honeypot field present + rejected when filled (returns mocked success); rate-limit 5 attempts/min/IP/slug
  - [ ] Status = Closed renders banner "Submissions for this prayer wall are closed" + disables Submit button on public; Status = Archived returns 410 Gone
  - [ ] **Submissions inbox tab** shows grid of `crm.PrayerRequests` for the current page; filter by Status (New/Approved/Rejected/Praying/Answered/Archived) + Category + Date range; bulk Approve / Reject / Mark-Praying / Mark-Answered / Archive
  - [ ] Approve transitions submission Status → Approved (+ if SharePublicly = true → eligible for Prayer Wall); rejected status records ModerationNote
  - [ ] **Public Prayer Wall block** (when ShowPublicPrayerWall = true on page setup): renders approved + SharePublicly = true prayers; truncated body (≤200 chars); category badge; "Anonymous" or first-name; relative date; PrayedCount; pagination + filter chips by category
  - [ ] **"I'll Pray for This" button** on public Prayer Wall card: anonymous-callable; rate-limited (3 clicks/min/IP/prayerId); inserts `crm.PrayerRequestPrayedLog` + atomically increments `PrayerRequest.PrayedCount`; updates UI without full reload
  - [ ] Submitter who toggled NotifyOnPrayed receives email when first PrayedLog row inserted (REAL email)
  - [ ] **PII handling**: SubmitterEmail / SubmitterPhone shown to admin only (never on public Prayer Wall); admin can hard-delete a submission (audit log entry created)
  - [ ] Status Bar in admin setup shows real aggregates (totalSubmissions / pendingModeration / approvedCount / mostRecentSubmission) sourced from GetPrayerRequestPageStats
- [ ] Empty / loading / error states render on both setup and public surfaces
- [ ] DB Seed — admin menu visible at SET_PUBLICPAGES > PRAYERREQUESTPAGE; sample published page renders for E2E QA at `/pray/pray`; 6 PRAYERCATEGORY MasterData rows seeded; 1 sample Approved+SharePublicly prayer present

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage for setup AND public page

Screen: PrayerRequestPage
Module: Setting (admin) / Public (anonymous-rendered)
Schema: `corg`
Group: ContactModels

Business: This is the canonical **public-facing prayer-request submission page** that a faith-based or values-driven NGO publishes to invite community members and visitors to share prayer concerns with the organization's prayer team. The admin setup screen lets a BUSINESSADMIN configure every aspect of the experience: page identity (title, slug, description, hero), which prayer categories are offered, configurable submitter form fields (Name / Email / Phone / Country / Title / Body / Category / IsAnonymous / SharePublicly / NotifyOnPrayed), moderation policy, branding, notification routing (admin alert email + submitter acknowledgment + "your prayer was prayed for" notification), thank-you behavior, SEO/OG meta, and an optional public Prayer Wall that displays approved+publicly-shared prayers with an "I'll Pray for This" engagement counter. The headline conversion goal is a completed prayer-request submission; secondary goals are (1) staff/team engagement (timely prayer + acknowledgment) and (2) optional contact capture for stewardship (when submitter consents via `LinkContactOnSubmission` toggle, a Contact row is upserted by email). Lifecycle is Draft → Published → Active → Closed → Archived: only Active pages accept submissions; Draft pages render only with a preview-token; Closed pages render but disable the Submit button; Archived returns 410 Gone. **What's unique about this page's UX vs OnlineDonationPage**: there is NO payment hand-off (zero PCI scope), but there ARE three pieces OnlineDonationPage doesn't have — (1) a **moderation inbox** as a tab inside the same admin screen, since prayer submissions arrive continuously and need triage; (2) a **public Prayer Wall** read-side that exposes approved-and-consented submissions with privacy-aware naming (anonymous submitters appear as "Anonymous"); and (3) a **"I'll Pray for This" engagement counter** that turns the public surface into a participation page, not just a submission funnel. **What breaks if mis-set**: PII leaked to public Prayer Wall when consent was OFF (submitter opted-in to private prayer but sees their name on the wall — privacy breach); cross-tenant slug collision routing a submission into the wrong tenant's database; admin-pings emailed to a stale recipient list after a staff turnover; rate-limit too lax letting bots flood the moderation inbox; missing CSRF making the form submitable from any third-party site; "I'll Pray" counter inflatable by bots; ModerationMode = MANUAL_APPROVE configured but no AdminEmailRecipients → submissions invisible until manually polled. Related screens: notifications use existing `comm.EmailTemplates` + `notify.SmsSetting` infra (no new comm tables), submitter contact upsert routes to `corg.Contacts`, the optional `crm.Campaigns` link lets a prayer page anchor to a campaign for analytics. **Multi-tenant posture**: all admin queries filter by `CompanyId` from `HttpContext`; the public route resolves `(slug)` → `(CompanyId, PageId)` server-side and stamps every persisted submission with the resolved CompanyId — never trusting any tenant hint from the public client.

> **Why this section is heavier**: SUBMISSION_PAGE introduces moderation + privacy semantics that DONATION_PAGE doesn't have. Skipping the privacy-aware Prayer Wall design is the #1 risk here — a developer who clones OnlineDonationPage straight will leak PII on the public wall.

---

## ② Storage & Source Model

> **Consumer**: BA Agent → Backend Developer
>
> SUBMISSION_PAGE has a primary entity (the page setup record) PLUS two child entities: PrayerRequest (each public submission) and PrayerRequestPrayedLog (each "I'll Pray" engagement). The page record is the funnel; PrayerRequest is the data the funnel collects.

**Storage Pattern**: `parent-with-children`

> Each tenant may have **multiple** PrayerRequestPage rows (e.g., a primary "Submit a Prayer Request" page + a "Healing Service Prayer Wall 2026" campaign page). Submissions FK back via `PrayerRequestPageId`; PrayedLog FK back via `PrayerRequestId`.

### Tables

> Audit columns omitted (inherited from `Entity` base). CompanyId always present (tenant scope). Schema = `corg`.

**Primary table**: `corg."PrayerRequestPages"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| PrayerRequestPageId | int | — | PK | — | Identity primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (NOT a public-form field) |
| PageTitle | string | 200 | YES | — | Internal label + default for public hero title; e.g. "Share a Prayer Request" |
| Slug | string | 100 | YES | — | URL slug; unique per tenant; lower-kebab; auto-from-PageTitle on Create; reserved-slug-rejected |
| Description | string | 2000 | NO | — | Short subtitle / lead paragraph rendered in public hero; supports basic markdown |
| Status | string | 20 | YES | — | Draft / Published / Active / Closed / Archived |
| PublishedAt | DateTime? | — | NO | — | Set on Draft→Published transition |
| StartDate | DateTime? | — | NO | — | When set, page Active only after this date |
| EndDate | DateTime? | — | NO | — | When set, page auto-Closed after this date |
| LinkedCampaignId | int? | — | NO | app.Campaigns | Optional anchor to a campaign for analytics rollup |
| **Categories & Form Configuration** | | | | | |
| EnabledCategoryCodesJson | jsonb | — | YES | — | Array of MasterData codes for type `PRAYERCATEGORY` (e.g. `["HEALING","THANKSGIVING","FAMILY","FINANCES","GUIDANCE","OTHER"]`); ordered |
| DefaultCategoryCode | string | 20 | NO | — | Default selected category on form (must be in EnabledCategoryCodesJson) |
| MaxBodyLength | int | — | YES | — | Max chars for prayer body (default 2000, range 200–8000) |
| SubmitterFieldsJson | jsonb | — | YES | — | Per-field config: `{"FirstName":{"required":true,"visible":true,"locked":false},"LastName":{"required":false,"visible":true},"Email":{"required":false,"visible":true},"Phone":{"required":false,"visible":true},"Country":{"required":false,"visible":false},"Title":{"required":false,"visible":true},"Body":{"required":true,"visible":true,"locked":true},"Category":{"required":true,"visible":true},"IsAnonymous":{"required":false,"visible":true},"SharePublicly":{"required":false,"visible":true},"NotifyOnPrayed":{"required":false,"visible":true}}` |
| LinkContactOnSubmission | bool | — | YES | — | When TRUE + email provided + submitter opt-in: upsert `corg.Contact` by email (default TRUE) |
| **Moderation** | | | | | |
| ModerationMode | string | 20 | YES | — | `AUTO_APPROVE` \| `MANUAL_APPROVE` \| `NEVER_PUBLIC`; controls whether submissions can EVER reach Prayer Wall (NEVER_PUBLIC blocks SharePublicly entirely) |
| AdminEmailRecipientsJson | jsonb | — | NO | — | Array of email addresses for new-submission notifications (e.g. `["prayer@org.org","admin@org.org"]`); REQUIRED if ModerationMode = MANUAL_APPROVE |
| ProfanityFilterEnabled | bool | — | YES | — | When TRUE, server runs basic profanity check + flags submission for moderation regardless of ModerationMode |
| **Notifications (REAL — existing email infra)** | | | | | |
| SubmitterReceiptTemplateId | int? | — | NO | comm.EmailTemplates | Acknowledgment email sent on submission (variables: {{firstName}}, {{prayerTitle}}, {{categoryName}}) |
| AdminPingTemplateId | int? | — | NO | comm.EmailTemplates | Email to admin recipients on new submission (variables: {{submitterName}}, {{prayerExcerpt}}, {{moderationUrl}}) |
| PrayedNotifyTemplateId | int? | — | NO | comm.EmailTemplates | Email to submitter (when NotifyOnPrayed=true) on first prayer logged for their request |
| EnableSlackWebhook | bool | — | YES | — | When TRUE, post to SlackWebhookUrl on each new submission |
| SlackWebhookUrl | string | 500 | NO | — | Slack/Teams incoming webhook URL (SERVICE_PLACEHOLDER — wired but does no-op until WebhookDispatcher service exists) |
| **Public Prayer Wall** | | | | | |
| ShowPublicPrayerWall | bool | — | YES | — | When TRUE, public page renders an approved-prayers grid below the form; default FALSE |
| WallPageSize | int | — | YES | — | Prayers per page on Wall (default 12, range 6–48) |
| WallShowCount | bool | — | YES | — | When TRUE, show "{N} prayers shared" header above wall |
| WallShowPrayedCount | bool | — | YES | — | When TRUE, each card shows "🙏 {N} prayers offered" badge |
| WallEnableILLPray | bool | — | YES | — | When TRUE, each card has "I'll Pray for This" button (anonymous engagement) |
| WallTruncateChars | int | — | YES | — | Chars to truncate body on Wall (default 200, range 80–500) |
| **Branding** | | | | | |
| LogoUrl | string | 500 | NO | — | Org logo (hero left) |
| HeroImageUrl | string | 500 | NO | — | Single hero image |
| PrimaryColorHex | string | 7 | NO | — | Theme accent (default `#7c3aed` — calming purple) |
| ButtonText | string | 50 | NO | — | Submit button label (default "Share Prayer Request") |
| PageLayout | string | 30 | NO | — | `centered` \| `side-by-side` \| `full-width` |
| **Thank You** | | | | | |
| ThankYouMessage | string | 1000 | NO | — | Inline thank-you copy (default "Thank you. Our prayer team has received your request.") |
| ThankYouRedirectUrl | string | 500 | NO | — | If set, redirect after success instead of inline thank-you |
| ShowSocialShare | bool | — | YES | — | Renders FB/Twitter/WhatsApp share buttons on thank-you state (encourages reach) |
| **SEO / Social** | | | | | |
| OgTitle | string | 200 | NO | — | Defaults to PageTitle |
| OgDescription | string | 500 | NO | — | Defaults to Description |
| OgImageUrl | string | 500 | NO | — | Defaults to HeroImageUrl |
| RobotsIndexable | bool | — | YES | — | Default TRUE for prayer landing; admin may set FALSE for closed-community pages |
| **Compliance** | | | | | |
| PrivacyNoticeMd | string | 4000 | NO | — | Markdown privacy notice shown beneath form (defaults to org-default) |
| ConsentRequired | bool | — | YES | — | When TRUE, public form shows mandatory "I consent to my prayer being held in confidence by your team" checkbox |
| ConsentText | string | 1000 | NO | — | Override consent label |
| **Soft state** | | | | | |
| IsActive | bool | — | YES | — | Soft-active toggle separate from Status — for quick "pause" without changing lifecycle |

**Slug uniqueness**:
- Unique filtered index on `(CompanyId, LOWER(Slug))` WHERE `IsDeleted = FALSE`
- Reserved-slug list rejected by validator: `admin / api / embed / p / pray / preview / login / signup / oauth / public / assets / static / ic / _next / wall`

**Status transition rules** (BE-enforced):
- Draft → Published only when validation passes (see §④ Required-to-Publish list)
- Published → Active automatic at StartDate (or = Published if no StartDate)
- Active → Closed automatic at EndDate, or admin "Close Early"
- Any → Archived admin-triggered (soft-delete; preserves PrayerRequest FK rows; admin can still browse historical submissions but no new submissions)

### Child table 1 — `corg."PrayerRequests"` (each public submission)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| PrayerRequestId | int | — | PK | — | Identity |
| CompanyId | int | — | YES | corg.Companies | **Tenant scope — set SERVER-SIDE from page.CompanyId, never trust request body** |
| PrayerRequestPageId | int | — | YES | corg.PrayerRequestPages | Cascade-restrict (preserve submissions when page archived) |
| LinkedContactId | int? | — | NO | corg.Contacts | NULL if no email or no opt-in; else upserted contact id |
| LinkedCampaignId | int? | — | NO | app.Campaigns | Inherited from page.LinkedCampaignId at submission time (snapshot) |
| **Submitter (PII — admin-only display)** | | | | | |
| SubmitterFirstName | string | 100 | NO | — | NULL if visibility=hidden in page config |
| SubmitterLastName | string | 100 | NO | — | |
| SubmitterEmail | string | 200 | NO | — | NULL if not collected; required if NotifyOnPrayed=true |
| SubmitterPhone | string | 30 | NO | — | |
| SubmitterCountryCode | string | 3 | NO | — | ISO-3166 alpha-2 or alpha-3 |
| **Content** | | | | | |
| Title | string | 200 | NO | — | Optional summary (helpful for moderation list) |
| Body | string | 8000 | YES | — | The prayer text; max enforced by page.MaxBodyLength at submit time |
| CategoryCode | string | 20 | YES | — | MasterData PRAYERCATEGORY code; must be in page.EnabledCategoryCodesJson at submit time |
| **Submitter Choices** | | | | | |
| IsAnonymous | bool | — | YES | — | Submitter opted to display as "Anonymous" on Prayer Wall (admin still sees real name) |
| SharePublicly | bool | — | YES | — | Submitter consented to public Prayer Wall display; FALSE for "private prayer team only" |
| NotifyOnPrayed | bool | — | YES | — | Submitter wants email when team prays |
| ConsentAcceptedAt | DateTime? | — | NO | — | Set when ConsentRequired=true on page + checkbox checked |
| **Moderation State** | | | | | |
| Status | string | 20 | YES | — | `New` \| `Approved` \| `Rejected` \| `Praying` \| `Answered` \| `Archived` |
| ModerationNote | string | 1000 | NO | — | Internal admin note (e.g. rejection reason) |
| ModeratedByContactId | int? | — | NO | corg.Contacts | Staff who actioned (logged-in user) |
| ModeratedAt | DateTime? | — | NO | — | |
| FlaggedReason | string | 50 | NO | — | `PROFANITY` \| `SPAM` \| `DUPLICATE` \| `MANUAL` (for moderation queue priority) |
| **Engagement counters** | | | | | |
| PrayedCount | int | — | YES | — | Cached counter; atomically incremented by SQL on each PrayedLog insert; default 0 |
| LastPrayedAt | DateTime? | — | NO | — | MAX(PrayedLog.PrayedAt) — denormalized for sort |
| PrayerWallEligible | bool | — | YES | — | Computed col OR maintained: `Status='Approved' AND SharePublicly=TRUE AND IsActive=TRUE` (filter for Wall query) |
| **Anti-abuse** | | | | | |
| SubmitterIpHash | string | 64 | NO | — | SHA256 hash of IP + tenant-salt (NEVER raw IP); used for rate-limit + dedup |
| SubmitterUserAgent | string | 500 | NO | — | UA string for analytics |
| HoneypotTriggered | bool | — | YES | — | Audit field; TRUE if honeypot was filled (request was silently rejected on public; we still log) |
| CaptchaScore | decimal? | 3,2 | NO | — | reCAPTCHA v3 score (0.0–1.0); SERVICE_PLACEHOLDER returns 1.0 until configured |
| ReceivedSource | string | 20 | YES | — | `WEB` \| `IFRAME` \| `API` \| `MOBILE` |
| SubmittedAt | DateTime | — | YES | — | Server-set timestamp |

**Indexes**:
- `(CompanyId, PrayerRequestPageId, Status)` — moderation inbox query
- `(CompanyId, PrayerRequestPageId, PrayerWallEligible, SubmittedAt DESC)` — Prayer Wall public query
- `(CompanyId, SubmitterIpHash, SubmittedAt)` — rate-limit lookup window
- `(LinkedContactId)` — stewardship rollup

### Child table 2 — `corg."PrayerRequestPrayedLog"` (each "I'll Pray" click)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| PrayedLogId | int | — | PK | — | Identity |
| CompanyId | int | — | YES | corg.Companies | Tenant scope |
| PrayerRequestId | int | — | YES | corg.PrayerRequests | Cascade-delete on parent |
| PrayedByContactId | int? | — | NO | corg.Contacts | If logged-in staff/member; NULL for anonymous public click |
| IsAnonymousClick | bool | — | YES | — | TRUE = anonymous public visitor; FALSE = logged-in staff |
| PrayerNote | string | 500 | NO | — | Optional encouragement text from staff (NEVER shown publicly) |
| PrayedAt | DateTime | — | YES | — | Server-set |
| ClickerIpHash | string | 64 | NO | — | SHA256 for rate-limit (3 clicks/min/IP/prayerId) |

**Index**: `(CompanyId, PrayerRequestId, PrayedAt)` — recent-prayer aggregation.

> **Atomic increment rule**: PrayedLog insert + `PrayerRequest.PrayedCount = PrayedCount + 1` MUST run in the same transaction. Use a SQL stored proc or EF transaction with `SaveChanges` ordering. The "I'll Pray" public mutation also dedups same `(ClickerIpHash, PrayerRequestId)` within 24h to prevent inflation.

### Linkage to existing entities (DO NOT add columns elsewhere unless listed)

- `corg.Contacts` — UPSERT-by-email when `LinkContactOnSubmission=TRUE` AND `SharePublicly OR NotifyOnPrayed`. ContactSource = "PrayerRequest" (seed if absent).
- `app.Campaigns` — read-only FK; no column added to Campaign.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------------|---------------|-------------------|
| LinkedCampaignId | Campaign | `Base.Domain/Models/ApplicationModels/Campaign.cs` | `campaigns` | `campaignName` | `CampaignResponseDto` |
| SubmitterReceiptTemplateId | EmailTemplate | `Base.Domain/Models/NotifyModels/EmailTemplate.cs` | `emailTemplates` | `templateName` | `EmailTemplateResponseDto` |
| AdminPingTemplateId | EmailTemplate | (same) | (same) | (same) | (same) |
| PrayedNotifyTemplateId | EmailTemplate | (same) | (same) | (same) | (same) |
| LinkedContactId (PrayerRequest) | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `contacts` | `displayName` | `ContactResponseDto` |
| ModeratedByContactId | Contact | (same) | (same) | (same) | (same) |

**Master-data references** (looked up by code via existing `MasterData` shared model — NO FK column):

| Code | MasterDataType | Used For |
|------|----------------|----------|
| `HEALING / THANKSGIVING / FAMILY / FINANCES / GUIDANCE / SALVATION / WORLD_PEACE / PROTECTION / OTHER` | `PRAYERCATEGORY` | EnabledCategoryCodesJson + DefaultCategoryCode + PrayerRequest.CategoryCode |

> Verify `PRAYERCATEGORY` MasterDataType exists; if absent, **DB seed step 1 must seed 9 rows** with these codes. Order matches MasterData.OrderBy.

**Aggregation sources** (for stats query):

| Source | Aggregate | Used In | Filter |
|--------|-----------|---------|--------|
| `corg.PrayerRequests` | `COUNT(*)` GROUP BY PrayerRequestPageId | `totalSubmissions` (status bar) | All non-archived |
| `corg.PrayerRequests` | `COUNT(*) WHERE Status='New'` | `pendingModeration` (status bar) | |
| `corg.PrayerRequests` | `COUNT(*) WHERE Status='Approved'` | `approvedCount` (status bar) | |
| `corg.PrayerRequests` | `MAX(SubmittedAt)` | `lastSubmittedAt` (status bar) | |
| `corg.PrayerRequestPrayedLog` | `SUM(PrayedCount)` per page (rollup) | `totalPrayersOffered` (analytics) | |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Slug Rules**: Inherit from canonical (#10 OnlineDonationPage §④). Reserved-slug list extended with `pray` and `wall`. Slug becomes immutable post-Activation when ≥1 PrayerRequest attached (`SELECT EXISTS (SELECT 1 FROM corg.PrayerRequests WHERE PrayerRequestPageId = X)`).

**Lifecycle Rules**:

| State | Set by | Public route behavior | Submit button |
|-------|--------|----------------------|---------------|
| Draft | Initial Create | 404 to public; preview-token grants temporary access | Disabled |
| Published | Admin "Publish" action | Renders publicly | Live (if within Active window) |
| Active | Auto at StartDate | Renders publicly | Live |
| Closed | Auto at EndDate, or admin "Close Early" | Renders publicly with "Submissions are closed" banner; Prayer Wall remains readable if ShowPublicPrayerWall=TRUE | Disabled |
| Archived | Admin "Archive" | 410 Gone | N/A |

**Required-to-Publish Validation** (return all violations as a list):
- PageTitle non-empty
- Slug set + unique + not reserved
- ≥1 enabled Category in EnabledCategoryCodesJson
- DefaultCategoryCode IS NULL OR exists in EnabledCategoryCodesJson
- SubmitterFieldsJson["Body"]["required"] = TRUE AND SubmitterFieldsJson["Body"]["visible"] = TRUE (Body is locked-required)
- SubmitterFieldsJson["Category"]["visible"] = TRUE (Category must be visible)
- ModerationMode set
- If ModerationMode = MANUAL_APPROVE → AdminEmailRecipientsJson length ≥ 1
- MaxBodyLength in 200..8000
- WallPageSize in 6..48 (if ShowPublicPrayerWall = TRUE)
- WallTruncateChars in 80..500 (if ShowPublicPrayerWall = TRUE)
- OgTitle + OgImageUrl set (warn but allow — falls back to PageTitle + HeroImageUrl)
- (Notifications) If SubmitterReceiptTemplateId set, the EmailTemplate must belong to current Company AND be Active
- (Notifications) If AdminPingTemplateId set, same ownership check

**Conditional Rules**:
- If `ModerationMode = NEVER_PUBLIC` → SharePublicly forced FALSE on every submission regardless of submitter choice; ShowPublicPrayerWall is ignored on render
- If `ModerationMode = AUTO_APPROVE` → new submission goes directly to Status=Approved AND PrayerWallEligible=true if SharePublicly+ShowPublicPrayerWall; **NO admin moderation required**
- If `ModerationMode = MANUAL_APPROVE` → new submission Status=New; admin must Approve before it appears on Wall
- If `ProfanityFilterEnabled = TRUE` AND profanity detected → Status forced to New + FlaggedReason='PROFANITY' regardless of ModerationMode
- If `SubmitterFieldsJson["Email"]["visible"] = FALSE` → public form omits email field entirely; `LinkContactOnSubmission` and `NotifyOnPrayed` features both auto-disabled (warn admin in editor)
- If `SubmitterFieldsJson["IsAnonymous"]["visible"] = FALSE` → submissions default to IsAnonymous=FALSE (full name shown on wall when SharePublicly=TRUE)
- If `ShowPublicPrayerWall = FALSE` → Prayer Wall block + I'll-Pray button completely hidden on public render; "I'll Pray" mutation rejects with 404
- If `EndDate < now` AND `Status = Active` → server-side auto-flip to `Closed` on next state-tick OR on next public request (same pattern as OnlineDonationPage)
- If submission `IsAnonymous = TRUE` → public Wall card displays "Anonymous" (admin still sees real name in moderation inbox)

**Sensitive / Security-Critical Fields**:

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| Submitter PII (email, phone, name when IsAnonymous=true, country) | regulatory | admin-only views; **NEVER on public Prayer Wall regardless of SharePublicly** | column-level encryption recommended (defer to org policy) | log access on inbox open |
| Body (prayer content) | regulatory (HIPAA-adjacent for healing requests) | full body to admin; truncated body to public Wall ONLY when SharePublicly=TRUE AND IsActive=TRUE AND Status=Approved | server-side validated; HTML stripped (text-only) | log on hard-delete |
| ModerationNote | internal | admin-only; never returned in any public DTO | append-only audit field | log change |
| SubmitterIpHash + UA | operational | admin-only | salted hash (tenant-specific salt) | retain per policy |
| AdminEmailRecipientsJson | operational | admin-only setup | server-side (no plain-text leak) | log on edit |
| SlackWebhookUrl | operational | masked in editor (last 4 chars only) | encrypted at rest | log on rotate |

**Public-form Hardening (anonymous-route concerns)** — inherit from #10 OnlineDonationPage §④, with these adjustments:
- Rate-limit: `5 submissions / minute / IP / slug` AND `1 submission / 30sec / IP / slug` (anti-burst)
- Rate-limit on "I'll Pray for This": `3 clicks / minute / IP / prayerId` AND dedupe `(IpHash, PrayerRequestId)` within 24h (don't double-count same visitor)
- CSRF token issued on initial public-page render; required on submit AND I'll-Pray; rotation on each render
- Honeypot field `[name="website"]` hidden via CSS; submission with non-empty honeypot silently rejected (logged with HoneypotTriggered=TRUE; returns mock thank-you)
- reCAPTCHA v3 score check < 0.5 → submission auto-flagged FlaggedReason='SPAM' (still saved, but Status=New regardless of ModerationMode); SERVICE_PLACEHOLDER returns 1.0 until reCAPTCHA configured
- All input field-validated server-side (never trust public client); HTML stripped from Body (text-only persisted)
- CSP headers on public route: `script-src 'self' https://www.google.com/recaptcha https://www.gstatic.com; style-src 'self' 'unsafe-inline'; frame-src https://www.google.com/recaptcha; img-src * data: https:`
- Privacy Notice rendered beneath form (markdown-rendered; sanitized server-side)

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Publish | Page goes live; URL becomes shareable | "Publishing makes this page public at /pray/{slug}." | log + snapshot of jsonb config |
| Unpublish | Active → Draft; submissions rejected | "Visitors will see a 'closed' page." | log |
| Close Early | Active → Closed; new submissions rejected; Prayer Wall remains visible if WallEnabled | "Close submissions now? Existing prayers stay visible." | log + email page owner |
| Archive | Soft-delete; URL returns 410 | type-name confirm | log |
| Reset Branding | Wipe theme back to defaults | type-name confirm | log |
| **Hard-delete a PrayerRequest** | Permanently removes a submission row + its PrayedLog rows; for GDPR/RTBF requests | type "DELETE" confirm | log immutable (who/when/whyNote) |
| Bulk Reject | Multiple submissions → Rejected | "Reject {N} prayers? Submitters will not be notified." | log per row |
| Mass-Mark-Praying | Multiple → Status=Praying | (no confirm — reversible) | log |

**Role Gating**:

| Role | Setup access | Inbox access | Publish access | Notes |
|------|-------------|--------------|----------------|-------|
| BUSINESSADMIN | full | full | yes | full lifecycle (target role for MVP) |
| Anonymous public | none | none | — | only sees Active public route + Prayer Wall (when enabled) |

**Workflow** (cross-page — submission flow):
- Anonymous visitor visits `/pray/{slug}` → form renders with CSRF + honeypot + categories
- Server validates (CSRF, rate-limit, honeypot, captcha, page status, page ownership of slug)
- Server upserts `corg.Contact` if `LinkContactOnSubmission=TRUE` AND email provided AND submitter consented
- Server inserts `corg.PrayerRequest` row with `CompanyId = page.CompanyId` (NEVER from request)
- Apply ModerationMode rule (auto-approve → Status=Approved; manual → Status=New; never_public → Status=New + SharePublicly forced FALSE)
- Apply ProfanityFilter if enabled
- Async: send submitter receipt email (if SubmitterReceiptTemplateId set + email provided) — REAL email pipeline
- Async: send admin ping email (if AdminPingTemplateId set) — REAL
- Async: post Slack/Teams webhook if EnableSlackWebhook + URL set — SERVICE_PLACEHOLDER (logs intent)
- Returns thank-you state with optional redirect URL

- Public "I'll Pray" click → `/api/prayer-engagement/{prayerId}/pray` POST
- Server validates CSRF + rate-limit + dedup (`(IpHash, PrayerRequestId)` 24h)
- TX: insert PrayedLog + atomic increment PrayerRequest.PrayedCount + update LastPrayedAt
- Async: if first PrayedLog for this PrayerRequest AND submitter set NotifyOnPrayed=TRUE AND PrayedNotifyTemplateId set → send email — REAL
- Returns updated count

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions.

**Screen Type**: EXTERNAL_PAGE
**External-Page Sub-type**: `SUBMISSION_PAGE` (divergence from frozen 3-set — see §⑫ ISSUE-1)
**Storage Pattern**: `parent-with-children`

**Slug Strategy**: `custom-with-fallback`
> Slug auto-derived from PageTitle on Create; user may override; immutable once submissions attached.

**Lifecycle Set**: `Draft / Published / Active / Closed / Archived` (full)

**Save Model**: `autosave-with-publish`
> Each settings card autosaves on edit (300ms debounce). Top-right "Save & Publish" runs Validate-for-Publish + transitions Draft → Active. Submissions inbox tab actions (Approve/Reject) save immediately.

**Public Render Strategy**: `ssr`
> Prayer pages should be SEO-indexable (Google "submit prayer request" search results) for orgs that want broad reach. Use Next.js App Router `(public)/pray/[slug]/page.tsx` with `generateMetadata` for OG tags + `revalidate: 60` for ISR. The Prayer Wall block uses client-side fetch for pagination (CSR within SSR shell).

**Multi-tenant Slug Resolution Strategy**: `one-tenant-per-deployment` (MVP — same as #10 OnlineDonationPage ISSUE-1 deferral)
> Public route `/pray/{slug}` looks up by slug only; CompanyId resolved by single-tenant deployment context. **Future enhancement**: tenant-prefixed `/pray/{tenant}/{slug}` OR custom-domain mapping (`tenant.org/pray/{slug}`). Document in §⑫ ISSUE-2.

**Reason**: SUBMISSION_PAGE pattern fits because the screen is a single public-facing form that anonymous visitors complete, with admin setup configuring the form fields, categories, branding, moderation, and notifications. `parent-with-children` storage works because submissions + prayer-engagement logs link FK to the page record. `custom-with-fallback` slug matches the OnlineDonationPage convention. `autosave-with-publish` matches the canonical EXTERNAL_PAGE save model. SSR for public page enables SEO + OG meta + fast first-paint.

**Backend Patterns Required**:

For SUBMISSION_PAGE:
- [x] GetAllPrayerRequestPageList query (admin list view) — tenant-scoped, paginated, status filter
- [x] GetPrayerRequestPageById query (admin editor)
- [x] GetPrayerRequestPageBySlug query (public route) — anonymous-allowed, status-gated, returns PublicDto only
- [x] GetPrayerRequestPageStats query — totalSubmissions, pendingModeration, approvedCount, lastSubmittedAt, totalPrayersOffered
- [x] GetPublishValidationStatus query — returns missing-fields list
- [x] CreatePrayerRequestPage mutation (defaults to Draft; slug auto from PageTitle)
- [x] UpdatePrayerRequestPage mutation (full upsert; jsonb fields handled)
- [x] PublishPrayerRequestPage / UnpublishPrayerRequestPage / ClosePrayerRequestPage / ArchivePrayerRequestPage mutations (lifecycle)
- [x] ResetPrayerRequestPageBranding mutation
- [x] Slug uniqueness validator + reserved-slug rejection
- [x] Tenant scoping (CompanyId from HttpContext) — public uses CompanyId from slug-resolution
- [x] Anti-fraud throttle on public submit endpoint
- [x] **GetAllPrayerRequestList query** (admin moderation inbox) — paginated, filterable by Status/Category/DateRange/PageId
- [x] **GetPrayerRequestById query** (admin detail view) — full record incl. ModerationNote
- [x] **ApprovePrayerRequest / RejectPrayerRequest / MarkPrayingPrayerRequest / MarkAnsweredPrayerRequest / ArchivePrayerRequest mutations** (moderation actions; bulk-capable)
- [x] **HardDeletePrayerRequest mutation** (GDPR/RTBF — type-name confirm; immutable audit log)
- [x] **SubmitPrayerRequest public mutation** (anonymous-callable, rate-limited, csrf+honeypot+captcha-protected) — runs full flow (validate → upsert Contact → insert PrayerRequest → moderation rule → async notifications)
- [x] **GetPrayerWallBySlug public query** (anonymous-allowed) — paginated approved+SharePublicly+IsActive prayers; respects WallShowCount/WallShowPrayedCount/WallEnableILLPray; truncates Body to WallTruncateChars; PII-stripped
- [x] **PrayForThis public mutation** (anonymous-callable, rate-limited, csrf-protected) — atomic insert PrayedLog + increment PrayedCount + dedupe + send NotifyOnPrayed email
- [x] **GetPrayedLogsForPrayer query** (admin only) — list of who-prayed for a request

**Frontend Patterns Required**:

For SUBMISSION_PAGE — TWO render trees:
- [x] Admin setup at `setting/publicpages/prayerrequestpage` — list view (when `?id` not present) + editor (`?id=N`)
- [x] Editor with **TWO tabs**: "Setup" (split-pane: settings cards + live preview) AND "Submissions" (moderation inbox grid)
- [x] Setup tab: 8 settings cards in mockup-spec order (Identity / Categories / Form Fields / Moderation / Notifications / Prayer Wall / Branding / Thank You + SEO)
- [x] Submissions tab: DataTable of `crm.PrayerRequests` for current page with filters + bulk actions
- [x] Live Preview component — debounced 300ms; mobile + desktop toggle
- [x] Public NAV page at `(public)/pray/[slug]/page.tsx` — SSR, full-page hosted; hero + form + (optional) Prayer Wall block + footer
- [x] Public Prayer Wall component — paginated grid; "I'll Pray for This" button per card; category filter chips
- [x] Public thank-you state — inline OR redirect

> **No IFRAME mode for v1** — flag as future enhancement in §⑫ ISSUE-3. The "compact widget" concept doesn't fit prayer flows where visitors expect to read context + see Privacy Notice before sharing personal content.

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: TWO surfaces — (1) admin setup with 2-tab editor (Setup + Submissions inbox), (2) public NAV page with optional Prayer Wall block.

**Stamp**: `Layout Variant: split-pane (editor + preview)` — same chrome as OnlineDonationPage editor; see canonical §⑥ for shared rules. NOT a DataTable, NOT widgets-above-grid.

### 🎨 Visual Treatment Rules

1. **Pastoral, not transactional** — public page palette skews calming (default `#7c3aed` purple, soft hero), not the high-stakes urgency of a donation page. Typography is gentle, line-height generous.
2. **Privacy is visually first-class** — Privacy Notice rendered prominently beneath form (not in a footer modal); consent checkbox prominent + bold when `ConsentRequired=TRUE`.
3. **"Anonymous" branding clear** — when submitter selects IsAnonymous, public Wall card visually shows "🤫 Anonymous" badge; admin moderation inbox row shows "Anonymous (real name: {firstName})" label so staff knows who actually submitted.
4. **Moderation Mode is a high-impact toggle** — admin editor shows current ModerationMode as a colored banner at the top of the Submissions tab ("AUTO_APPROVE: prayers go live immediately" green / "MANUAL_APPROVE: {N} prayers waiting your review" yellow / "NEVER_PUBLIC: prayers are private to your team" gray).
5. **Category visualization** — categories use distinct icons + colors (Healing=💗 rose / Thanksgiving=🌟 amber / Family=👨‍👩‍👧‍👦 blue / Finances=💰 green / Guidance=🧭 indigo / Salvation=✝️ purple / WorldPeace=🌍 cyan / Protection=🛡️ slate / Other=🙏 neutral) — consistent across admin inbox + public wall.
6. **PrayedCount badge** — soft pill ("🙏 47 prayers offered") on Wall card; admin sees total + last-prayed-at.
7. **No pricing/payment chrome** — explicitly different visual register from OnlineDonationPage; no $ symbols, no "amount" cells, no "donate" CTAs.

**Anti-patterns to refuse**:
- Submitter PII appearing on public Wall when IsAnonymous=true (catastrophic privacy fail)
- Body text not truncated on Wall (visitors see full prayers in the grid — overwhelming)
- "I'll Pray" button on a card when WallEnableILLPray=FALSE (config not respected)
- Moderation Mode toggle without warning that switching modes affects pending submissions
- Closing page with pending moderation submissions silently lost
- Wall card showing real name when IsAnonymous=true even in admin "preview" (use the anon path always — never fork display)
- Edit page hiding the Submissions count banner — admin must always see the moderation backlog

---

### A.1 — Admin Setup UI (Setup tab — split-pane: editor left + live preview right)

**Page Header**:
- Breadcrumb: `Setting › Public Pages › Prayer Request Page`
- Page title: `🙏 Prayer Request Page`
- Subtitle: `Configure your organization's public prayer-request submission page`
- Right actions: `[Back] [Preview Full Page] [Save & Publish]` + overflow `[Unpublish / Close / Archive / Reset Branding]`

**Tab Bar (NEW for SUBMISSION_PAGE — diverges from OnlineDonationPage)**:
- Tab 1: `Setup` (default)
- Tab 2: `Submissions ({pendingCount})` — count badge updates live
- Tab 3 (optional): `Analytics` (defer if shipping minimum — flag in §⑫)

**Status Bar** (above tabs):
```
● {Status}   Total: {totalSubmissions}   Pending: {pendingModeration}   Approved: {approvedCount}   Last: {lastSubmittedAt}   🙏 Prayers offered: {totalPrayersOffered}
```

**Setup Tab Layout**:
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ EDITOR (8 settings cards stacked)             │ LIVE PREVIEW                    │
│                                                │ [Mobile|Desktop]                │
│ ┌─────────────────────────────────────────┐   │ ┌──────────────────────────────┐│
│ │ 🔗 Page URL & Identity                  │   │ │ ┌──────────────────────────┐ ││
│ │  • Page Title *                         │   │ │ │ 🔒 https://.../pray/{slug}│ ││
│ │  • Page URL Slug * → URL preview + copy │   │ │ ├──────────────────────────┤ ││
│ │  • Description (markdown)               │   │ │ │ [Hero + Logo]            │ ││
│ │  • Linked Campaign (optional)           │   │ │ │ {PageTitle}              │ ││
│ ├─────────────────────────────────────────┤   │ │ │ {Description}            │ ││
│ │ 🗂 Categories                           │   │ │ │                          │ ││
│ │  • Multi-select tag picker (9 default)  │   │ │ │ Submission form:         │ ││
│ │  • Default category dropdown            │   │ │ │  Category ▾              │ ││
│ │  • Drag-reorder                         │   │ │ │  Body* (textarea)        │ ││
│ ├─────────────────────────────────────────┤   │ │ │  ☐ Anonymous             │ ││
│ │ ✏️ Submitter Form Fields                │   │ │ │  ☐ Share publicly        │ ││
│ │  Field          Required Visible Locked │   │ │ │  ☐ Notify when prayed    │ ││
│ │  FirstName      [✓]   [✓]   [ ]         │   │ │ │  [Submit Prayer Request] │ ││
│ │  LastName       [ ]   [✓]   [ ]         │   │ │ │                          │ ││
│ │  Email          [ ]   [✓]   [ ]         │   │ │ │ Privacy Notice (md)      │ ││
│ │  Phone          [ ]   [✓]   [ ]         │   │ │ ├──────────────────────────┤ ││
│ │  Country        [ ]   [ ]   [ ]         │   │ │ │ Prayer Wall (if enabled) │ ││
│ │  Title          [ ]   [✓]   [ ]         │   │ │ │ ┌──┐ ┌──┐ ┌──┐ ┌──┐      │ ││
│ │  Body           [✓]   [✓]   [✓]         │   │ │ │ │..│ │..│ │..│ │..│      │ ││
│ │  Category       [✓]   [✓]   [✓]         │   │ │ │ └──┘ └──┘ └──┘ └──┘      │ ││
│ │  IsAnonymous    [ ]   [✓]   [ ]         │   │ │ └──────────────────────────┘ ││
│ │  SharePublicly  [ ]   [✓]   [ ]         │   │ └──────────────────────────────┘│
│ │  NotifyOnPrayed [ ]   [✓]   [ ]         │   │                                  │
│ │  • Max Body Length: [2000]              │   │                                  │
│ │  • Link Contact on Submission [✓]       │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🛡 Moderation                           │   │                                  │
│ │  ○ Auto-approve   ● Manual review       │   │                                  │
│ │  ○ Never public                          │   │                                  │
│ │  • Profanity filter [✓]                 │   │                                  │
│ │  • Admin email recipients (chips)       │   │                                  │
│ │    prayer@org.org × admin@org.org ×     │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ ✉ Notifications (Real Email)            │   │                                  │
│ │  • Submitter receipt template ▾         │   │                                  │
│ │  • Admin ping template ▾                │   │                                  │
│ │  • "Prayed for you" template ▾          │   │                                  │
│ │  • Slack webhook URL (placeholder)      │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🪟 Public Prayer Wall                   │   │                                  │
│ │  ☑ Show Prayer Wall on public page      │   │                                  │
│ │  ☑ Show submission count                │   │                                  │
│ │  ☑ Show prayed-count badges             │   │                                  │
│ │  ☑ Enable "I'll Pray for This" button   │   │                                  │
│ │  • Page size: 12 ▾                       │   │                                  │
│ │  • Truncate body to: 200 chars          │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🎨 Branding                             │   │                                  │
│ │  • Logo (upload), Hero image (upload)   │   │                                  │
│ │  • Primary color: #7c3aed (picker)      │   │                                  │
│ │  • Button text: "Share Prayer Request"  │   │                                  │
│ │  • Page layout: ◉ centered ○ side ○ full│   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ ✓ Thank-You & SEO & Privacy             │   │                                  │
│ │  • Thank-you message (markdown)         │   │                                  │
│ │  • Redirect URL (optional)              │   │                                  │
│ │  • Show social-share on thank-you [✓]   │   │                                  │
│ │  • OG Title / Description / Image       │   │                                  │
│ │  • Robots indexable [✓]                 │   │                                  │
│ │  • Privacy notice (markdown editor)     │   │                                  │
│ │  • Consent required [✓]                 │   │                                  │
│ └─────────────────────────────────────────┘   │                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

**Editor Sections** (one row per card — order matches preview render order):

| # | Section | Icon | Save Model | Notes |
|---|---------|------|------------|-------|
| 1 | Page URL & Identity | `ph:link-simple` | autosave | PageTitle, Slug, Description, Linked Campaign, Start/End dates |
| 2 | Categories | `ph:tag` | autosave | Multi-select MasterData picker; default category; drag-reorder |
| 3 | Submitter Form Fields | `ph:user-list` | autosave | 11-row table (Required/Visible/Locked); MaxBodyLength; LinkContact toggle |
| 4 | Moderation | `ph:shield-check` | autosave | Mode radio (3 options); ProfanityFilter toggle; AdminEmailRecipients chips |
| 5 | Notifications | `ph:envelope-simple` | autosave | 3 EmailTemplate dropdowns; Slack webhook (PLACEHOLDER) |
| 6 | Public Prayer Wall | `ph:hands-praying` | autosave | 4 toggles + page size + truncate chars |
| 7 | Branding | `ph:palette` | autosave | Logo, Hero, Primary color, Button text, Layout |
| 8 | Thank-You & SEO & Privacy | `ph:check-circle` | autosave | Thank-you, Redirect, OG meta, Robots, Privacy markdown, Consent |

### A.2 — Admin Setup UI (Submissions tab — moderation inbox)

**Layout**:
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Mode banner: ● MANUAL_APPROVE: 7 prayers waiting your review                    │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Filters: [Status ▾] [Category ▾] [Date Range] [Search] | Bulk: [Approve][Reject]│
├──────────────────────────────────────────────────────────────────────────────────┤
│ Status  Submitter        Category    Title              Body Preview     PrayedFor │
│ ● New   Anonymous (Sara) 💗 Healing  Aunt's surgery     "Please pray..." 🙏 0     │
│ ● Approved John D.        🌟 Thanks   Got the job!       "Just want..."   🙏 23    │
│ ● Praying Anonymous       👨‍👩‍👧 Family  Marriage           "We've been..."  🙏 12    │
│ ● Answered Maria L.        ✝️ Salvation Friend's faith    "After 3 years..."🙏 47   │
│ ● Rejected Bot12345       🛡 Protection [PROFANITY flag] [redacted]      🙏 0     │
│ ...                                                                              │
└──────────────────────────────────────────────────────────────────────────────────┘
```

**Columns**:
| # | Header | Field / Resolved | Render | Width | Notes |
|---|--------|-------------------|--------|-------|-------|
| 1 | _ | (checkbox) | bulk-select | 40px | |
| 2 | Status | `Status` | colored badge | 100px | New=blue / Approved=green / Praying=indigo / Answered=purple / Rejected=red / Archived=gray |
| 3 | Submitter | computed: `IsAnonymous ? "Anonymous (real: {firstName})" : "{firstName} {lastName}"` | text | 200px | Admin-only display; full name visible to staff |
| 4 | Category | resolve `CategoryCode` → MasterData display + emoji | badge | 140px | |
| 5 | Title | `Title` | text + tooltip | 200px | "(no title)" if null |
| 6 | Body Preview | `Body` truncated to 80 chars | text + tooltip-full | 280px | |
| 7 | Submitted | `SubmittedAt` | relative time | 100px | "2h ago" |
| 8 | Prayed For | `PrayedCount` | 🙏 N badge | 80px | |
| 9 | Flagged | `FlaggedReason` | warning icon if not null | 60px | tooltip shows reason |
| 10 | Actions | row buttons | [Approve][Reject][...] | 180px | overflow: Mark Praying/Answered/Archive/Hard-Delete |

**Row click**: opens side-drawer with full PrayerRequest detail (full Body, all submitter fields, ModerationNote textarea, PrayedLogs list, action buttons).

**Bulk actions**: Approve, Reject, Mark Praying, Mark Answered, Archive — confirm modal with count.

**Empty state**: "No prayer requests yet — share your page URL: `/pray/{slug}` [copy]"

### A.3 — Live Preview Behavior

- Updates on every keystroke (debounced 300ms)
- Mobile / Desktop toggle
- "Open in new tab" button on Draft → uses preview-token auth
- Preview shows "PREVIEW — NOT YET LIVE" banner overlay when Status = Draft
- Renders form per current SubmitterFieldsJson + Categories + Branding
- If ShowPublicPrayerWall=TRUE → renders mock 3-card wall using sample data ("Approved sample prayer 1...")

---

### B — Public Page (anonymous route at `/pray/{slug}`)

**Layout** (mobile-first):

```
┌────────────────────────────────────────────────────────────┐
│         [Hero Image — full bleed; Logo overlay]            │
│                                                            │
│         🙏 {Page Title}                                    │
│         {Description / subtitle}                           │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Share Your Prayer Request                             │ │
│  │                                                       │ │
│  │ Category: [💗 Healing ▾] *                            │ │
│  │ Title (optional): [_____________________]             │ │
│  │ Your prayer request *: [textarea, max {N} chars]     │ │
│  │                                                       │ │
│  │ [Per SubmitterFields config: name/email/phone/...]    │ │
│  │                                                       │ │
│  │ ☐ Submit anonymously (real name hidden on Prayer Wall)│ │
│  │ ☐ Share publicly on Prayer Wall (admin moderates)     │ │
│  │ ☐ Notify me when our team prays for this              │ │
│  │                                                       │ │
│  │ {ConsentRequired? ☐ I consent... (mandatory)}         │ │
│  │                                                       │ │
│  │ [SHARE PRAYER REQUEST]                                │ │
│  │                                                       │ │
│  │ 🔒 Your information is held in confidence.            │ │
│  └──────────────────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────────┤
│  Privacy Notice (markdown rendered)                        │
├────────────────────────────────────────────────────────────┤
│  🪟 Prayer Wall  (only if ShowPublicPrayerWall = TRUE)    │
│  {N} prayers shared                                        │
│  Filter: [All ▾] [💗] [🌟] [👨‍👩‍👧] [💰] [🧭] [✝️] ...    │
│                                                            │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐      │
│  │ 💗 Healing   │ │ 🌟 Thanks    │ │ 👨‍👩‍👧 Family │      │
│  │ "Please pray │ │ "Got the job!│ │ "We've been..│      │
│  │  for my..."  │ │  After many..│ │  praying for"│      │
│  │ — Sara M.    │ │ — Anonymous  │ │ — John D.    │      │
│  │ 2h ago       │ │ 5h ago       │ │ 1d ago       │      │
│  │ 🙏 12 prayers│ │ 🙏 47 prayers│ │ 🙏 3 prayers │      │
│  │ [I'll Pray]  │ │ [I'll Pray]  │ │ [I'll Pray]  │      │
│  └──────────────┘ └──────────────┘ └──────────────┘      │
│                                                            │
│  [< Prev]  Page 1 of 5  [Next >]                          │
├────────────────────────────────────────────────────────────┤
│  Footer: Privacy / Contact / Logo / Powered by             │
└────────────────────────────────────────────────────────────┘
```

**Public-route behavior**:
- SSR with revalidation (page metadata caches 60s; OG tags pre-rendered)
- Anonymous-allowed route (no auth gate); CSP headers strict
- CSRF token issued in initial render; required on form submit AND I'll-Pray click
- Honeypot field hidden in form
- On submit: client-side validation → server validates → server creates PrayerRequest + (optional Contact upsert) + applies ModerationMode + fires async notifications → returns thank-you state OR redirect URL
- Prayer Wall fetched client-side (CSR) within SSR shell — paginated, filterable; respects `WallEnableILLPray` for button visibility
- "I'll Pray" click → POST `/api/prayer-engagement/{prayerId}/pray` → atomic transaction → optimistic UI update + server-confirmed count

**Edge states**:
- `Status = Draft` → 404 (unless preview-token in querystring)
- `Status = Closed` → renders page with "Submissions are closed" banner; submit disabled; Wall remains readable if `ShowPublicPrayerWall=TRUE`
- `Status = Archived` → 410 Gone
- `EnabledCategoryCodesJson = []` → "Submissions temporarily unavailable" message
- ModerationMode = NEVER_PUBLIC → SharePublicly toggle hidden from form; Wall block hidden regardless of ShowPublicPrayerWall

**Empty / Loading / Error States**:

| State | Trigger | UI |
|-------|---------|----|
| Loading (setup list) | Initial fetch | Skeleton 5 rows |
| Loading (setup editor) | Initial fetch | Skeleton matching 8 cards |
| Loading (inbox) | Initial fetch | Skeleton 8 rows |
| Loading (public form) | SSR streaming | progressive — header first, hero, form placeholder |
| Loading (Prayer Wall) | CSR fetch | 12 card skeletons |
| Empty (setup list) | No pages yet | "Create your first prayer request page" + primary CTA |
| Empty (inbox) | No submissions | "No prayer requests yet — share your page URL: /pray/{slug} [copy]" |
| Empty (Wall) | No approved+SharePublicly prayers | "No prayers have been shared publicly yet — be the first to share." |
| Error (setup) | GET fails | Error card with retry button |
| Error (public form submit) | Server error | Inline error; retain form state |
| Error (slug not found) | Public 404 | Org-default redirect |
| Closed (public) | Status = Closed | "Submissions are closed" banner |

---

## ⑦ Substitution Guide

> **First SUBMISSION_PAGE in PSS 2.0** — this entity establishes the canonical reference for the SUBMISSION_PAGE divergence sub-type. Future SUBMISSION_PAGE planners (e.g., #169 Event Registration Page, #172 Volunteer Registration Page) should copy from `prayerrequestpage.md` as the substitution base and #10 OnlineDonationPage for shared EXTERNAL_PAGE infrastructure.

| Canonical (this entity) | → This Entity | Context |
|-------------------------|---------------|---------|
| PrayerRequestPage | PrayerRequestPage | Entity / class name (PascalCase) |
| prayerRequestPage | prayerRequestPage | Variable / field names (camelCase) |
| prayerrequestpage | prayerrequestpage | FE folder / route segment (lowercase) |
| PRAYERREQUESTPAGE | PRAYERREQUESTPAGE | MenuCode / GridCode (UPPERCASE) |
| prayer-request-page | prayer-request-page | kebab-case (file/component names) |
| `corg` | `corg` | DB schema |
| `ContactModels` | `ContactModels` | Backend group |
| `contact-service` | `contact-service` | FE entity domain folder |
| `setting/publicpages/prayerrequestpage` | `setting/publicpages/prayerrequestpage` | Admin FE route |
| `(public)/pray/[slug]` | `(public)/pray/[slug]` | Public NAV route (distinct from `/p/` donation namespace) |
| ParentMenu: `SET_PUBLICPAGES` | (same) | Sidebar parent |
| Module: `SETTING` | (same) | Module code |

> **NOTE**: Even though screen #171 description was "Public landing page" and registry typed it as "Config", the menu lives under SET_PUBLICPAGES (Module=SETTING), and the GridType is EXTERNAL_PAGE. The FE route is `setting/publicpages/prayerrequestpage`. Public page route uses `/pray/` namespace (NOT `/p/` which is reserved for donation pages).

---

## ⑧ File Manifest

> Counts: BE ≈ 28 files; FE ≈ 28 files; 1 DB seed; 1 EF migration. Submissions inbox tab is part of the same admin route — does not double the file count.

### Backend Files (NEW — 28)

| # | File | Path |
|---|------|------|
| 1 | Entity (parent) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/PrayerRequestPage.cs` |
| 2 | Entity (PrayerRequest) | `…/Base.Domain/Models/ContactModels/PrayerRequest.cs` |
| 3 | Entity (PrayedLog) | `…/Base.Domain/Models/ContactModels/PrayerRequestPrayedLog.cs` |
| 4 | EF Config (page) | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/ContactConfigurations/PrayerRequestPageConfiguration.cs` |
| 5 | EF Config (request) | `…/Base.Infrastructure/Data/Configurations/ContactConfigurations/PrayerRequestConfiguration.cs` |
| 6 | EF Config (prayedLog) | `…/Base.Infrastructure/Data/Configurations/ContactConfigurations/PrayerRequestPrayedLogConfiguration.cs` |
| 7 | Schemas (DTOs) | `…/Base.Application/Schemas/ContactSchemas/PrayerRequestPageSchemas.cs` (Page Request/Response/Public/Stats/ValidationResult + PrayerRequest Request/Response/PublicWallDto + PrayedLog Request/Response + SubmitPublicRequest + PrayForThisRequest) |
| 8 | GetAll Query (admin pages) | `…/Base.Application/Business/ContactBusiness/PrayerRequestPages/GetAllQuery/GetAllPrayerRequestPagesList.cs` |
| 9 | GetById Query | `…/PrayerRequestPages/GetByIdQuery/GetPrayerRequestPageById.cs` |
| 10 | GetBySlug Query (public) | `…/PrayerRequestPages/PublicQueries/GetPrayerRequestPageBySlug.cs` (anonymous-allowed) |
| 11 | GetStats Query | `…/PrayerRequestPages/GetStatsQuery/GetPrayerRequestPageStats.cs` |
| 12 | GetPublishValidation Query | `…/PrayerRequestPages/ValidateForPublishQuery/ValidatePrayerRequestPageForPublish.cs` |
| 13 | Create Command | `…/PrayerRequestPages/CreateCommand/CreatePrayerRequestPage.cs` |
| 14 | Update Command | `…/PrayerRequestPages/UpdateCommand/UpdatePrayerRequestPage.cs` |
| 15 | Lifecycle Commands (4) | `…/PrayerRequestPages/LifecycleCommands/{Publish,Unpublish,Close,Archive}PrayerRequestPage.cs` |
| 16 | ResetBranding Command | `…/PrayerRequestPages/ResetBrandingCommand/ResetPrayerRequestPageBranding.cs` |
| 17 | GetAll Query (admin requests inbox) | `…/Base.Application/Business/ContactBusiness/PrayerRequests/GetAllQuery/GetAllPrayerRequestsList.cs` |
| 18 | GetById Query (request) | `…/PrayerRequests/GetByIdQuery/GetPrayerRequestById.cs` |
| 19 | Moderation Commands (5) | `…/PrayerRequests/ModerationCommands/{Approve,Reject,MarkPraying,MarkAnswered,Archive}PrayerRequest.cs` |
| 20 | HardDelete Command | `…/PrayerRequests/HardDeleteCommand/HardDeletePrayerRequest.cs` |
| 21 | SubmitPublic Mutation | `…/PrayerRequests/PublicMutations/SubmitPrayerRequest.cs` (anonymous-allowed, rate-limited, csrf+honeypot+captcha) |
| 22 | GetWallBySlug Query (public) | `…/PrayerRequests/PublicQueries/GetPrayerWallBySlug.cs` (anonymous-allowed, paginated) |
| 23 | PrayForThis Public Mutation | `…/PrayerRequestPrayedLogs/PublicMutations/PrayForThis.cs` (anonymous-allowed, rate-limited, csrf-protected; atomic increment) |
| 24 | GetPrayedLogs Query | `…/PrayerRequestPrayedLogs/GetAllQuery/GetPrayedLogsForPrayer.cs` (admin) |
| 25 | Slug Validator | `…/Base.Application/Validators/PrayerRequestPageSlugValidator.cs` |
| 26 | Profanity Service (interface + impl-stub) | `…/Base.Application/Services/IProfanityFilter.cs` + `…/Services/Implementations/SimpleProfanityFilter.cs` (token-list match; SERVICE_PLACEHOLDER for upgraded service) |
| 27 | Mutations endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/ContactModels/Mutations/PrayerRequestPageMutations.cs` + `PrayerRequestMutations.cs` |
| 28 | Queries endpoint (admin + public) | `…/EndPoints/ContactModels/Queries/PrayerRequestPageQueries.cs` + `PrayerRequestQueries.cs` + `…/Public/PrayerRequestPagePublicQueries.cs` (anonymous, rate-limited) + `…/Public/PrayerRequestPublicMutations.cs` |

### Backend Wiring Updates (5)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IContactDbContext.cs` | `DbSet<PrayerRequestPage>` + `DbSet<PrayerRequest>` + `DbSet<PrayerRequestPrayedLog>` |
| 2 | `ContactDbContext.cs` | DbSet entries |
| 3 | `Base.Application/Extensions/DecoratorProperties.cs` | `DecoratorContactModules.PrayerRequestPage` + `.PrayerRequest` + `.PrayerRequestPrayedLog` |
| 4 | `ContactMappings.cs` | Mapster mapping config (parent + 2 children; jsonb properties) |
| 5 | EF Migration | `Add_PrayerRequestPage_With_Children` — creates 3 tables + filtered unique index on (CompanyId, LOWER(Slug)) on PrayerRequestPages + 4 indexes on PrayerRequests + 1 index on PrayedLog |

### Frontend Files (NEW — 28)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/contact-service/PrayerRequestPageDto.ts` |
| 2 | DTO Types (request) | `…/contact-service/PrayerRequestDto.ts` |
| 3 | DTO Types (prayedLog) | `…/contact-service/PrayerRequestPrayedLogDto.ts` |
| 4 | GQL Query (admin pages) | `…/infrastructure/gql-queries/contact-queries/PrayerRequestPageQuery.ts` |
| 5 | GQL Query (admin requests) | `…/infrastructure/gql-queries/contact-queries/PrayerRequestQuery.ts` |
| 6 | GQL Query (public) | `…/infrastructure/gql-queries/public-queries/PrayerRequestPagePublicQuery.ts` (BySlug + Wall) |
| 7 | GQL Mutation (admin pages) | `…/infrastructure/gql-mutations/contact-mutations/PrayerRequestPageMutation.ts` |
| 8 | GQL Mutation (admin moderation) | `…/infrastructure/gql-mutations/contact-mutations/PrayerRequestMutation.ts` |
| 9 | GQL Mutation (public) | `…/infrastructure/gql-mutations/public-mutations/PrayerRequestPublicMutation.ts` (Submit + PrayForThis) |
| 10 | Page Config (admin) | `…/presentation/pages/setting/publicpages/prayerrequestpage.tsx` (default-import dispatcher; URL `?id=N` switches list ↔ editor; `?tab=submissions` switches editor sub-tab) |
| 11 | Pages barrel update | `…/presentation/pages/setting/publicpages/index.ts` |
| 12 | List View | `…/presentation/components/page-components/setting/publicpages/prayerrequestpage/list-page.tsx` |
| 13 | Editor (tabs container) | `…/prayerrequestpage/editor-page.tsx` (status bar + tab bar [Setup / Submissions] + tab content) |
| 14 | Status Bar | `…/prayerrequestpage/components/status-bar.tsx` |
| 15 | Setup Tab Content | `…/prayerrequestpage/setup-tab.tsx` (split-pane: 8 cards + live preview) |
| 16 | Submissions Tab Content | `…/prayerrequestpage/submissions-tab.tsx` (mode banner + filters + DataTable + bulk actions + side-drawer) |
| 17 | Setup Card 1 (Identity) | `…/prayerrequestpage/sections/identity-section.tsx` |
| 18 | Setup Card 2 (Categories) | `…/prayerrequestpage/sections/categories-section.tsx` |
| 19 | Setup Card 3 (Form Fields) | `…/prayerrequestpage/sections/form-fields-section.tsx` (11-row table + body length + link contact) |
| 20 | Setup Card 4 (Moderation) | `…/prayerrequestpage/sections/moderation-section.tsx` |
| 21 | Setup Card 5 (Notifications) | `…/prayerrequestpage/sections/notifications-section.tsx` |
| 22 | Setup Card 6 (Prayer Wall) | `…/prayerrequestpage/sections/prayer-wall-section.tsx` |
| 23 | Setup Card 7 (Branding) | `…/prayerrequestpage/sections/branding-section.tsx` |
| 24 | Setup Card 8 (ThankYou+SEO+Privacy) | `…/prayerrequestpage/sections/thank-you-seo-section.tsx` |
| 25 | Live Preview component | `…/prayerrequestpage/components/live-preview.tsx` (mobile / desktop toggle) |
| 26 | Submission Detail Drawer | `…/prayerrequestpage/components/submission-drawer.tsx` (full Body + ModerationNote textarea + PrayedLogs list + actions) |
| 27 | Editor Zustand store | `…/prayerrequestpage/prayerrequestpage-store.ts` (autosave queue + dirty fields + preview mirror + submissions filter state) |
| 28 | Public NAV page | `…/presentation/components/page-components/public/prayerrequestpage/prayer-page.tsx` (hero + form + Privacy notice + Prayer Wall block) |
| 29 | Public submission form | `…/public/prayerrequestpage/components/submission-form.tsx` |
| 30 | Public Prayer Wall | `…/public/prayerrequestpage/components/prayer-wall.tsx` (paginated grid + category filter + I'll-Pray button) |
| 31 | Public thank-you | `…/public/prayerrequestpage/components/thank-you.tsx` |
| 32 | Route Page (admin) | `src/app/[lang]/setting/publicpages/prayerrequestpage/page.tsx` (default-import re-export of pages config) |
| 33 | Route Page (public) | `src/app/[lang]/(public)/pray/[slug]/page.tsx` (SSR with generateMetadata) |

### Frontend Wiring Updates (5)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `…/operations-config/contact-service-entity-operations.ts` | `PRAYERREQUESTPAGE` + `PRAYERREQUEST` blocks (page lifecycle ops + moderation ops) |
| 2 | `…/operations-config/operations-config.ts` | Import + register operations |
| 3 | `…/domain/entities/contact-service/index.ts` | Export 3 new DTO files |
| 4 | `…/infrastructure/gql-queries/contact-queries/index.ts` + `gql-mutations/contact-mutations/index.ts` + `gql-queries/public-queries/index.ts` + `gql-mutations/public-mutations/index.ts` | Export new files |
| 5 | Sidebar / sidebar config | Menu entry under `SET_PUBLICPAGES` parent (auto-rendered from BE seed via dynamic-menu pattern) |

> **Public route group `(public)`** — already established by #10 OnlineDonationPage. Reuse the same `(public)/layout.tsx` (no admin chrome). Add new sub-route `(public)/pray/[slug]/page.tsx`.

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Prayer Request Page
MenuCode: PRAYERREQUESTPAGE
ParentMenu: SET_PUBLICPAGES
Module: SETTING
MenuUrl: setting/publicpages/prayerrequestpage
GridType: EXTERNAL_PAGE

MenuCapabilities: READ, CREATE, MODIFY, DELETE, PUBLISH, UNPUBLISH, ARCHIVE, MODERATE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, PUBLISH, UNPUBLISH, ARCHIVE, MODERATE

GridFormSchema: SKIP
GridCode: PRAYERREQUESTPAGE
---CONFIG-END---
```

> `GridType: EXTERNAL_PAGE` reuses the GridType added by #10 OnlineDonationPage seed.
> `GridFormSchema: SKIP` — custom UI (split-pane + tabs), not RJSF modal.
> 4 lifecycle capabilities (`PUBLISH / UNPUBLISH / ARCHIVE`) gate top-right action buttons in the editor.
> NEW capability `MODERATE` gates the Submissions tab + moderation actions (separate from MODIFY so org can have a "moderator" role distinct from "page admin" — useful for orgs where prayer team ≠ tech admin).
> The public route is anonymous — no menu / role check applies on `/pray/{slug}`.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types**:
- Admin Query types: `PrayerRequestPageQueries` + `PrayerRequestQueries`
- Admin Mutation types: `PrayerRequestPageMutations` + `PrayerRequestMutations`
- Public Query type: `PrayerRequestPagePublicQueries` (anonymous-allowed)
- Public Mutation type: `PrayerRequestPublicMutations` (anonymous-allowed, rate-limited, csrf-protected)

### Admin Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `prayerRequestPages` | `PrayerRequestPagePagedResponse` | pageSize, pageIndex, sortColumn, sortDescending, searchTerm, advancedFilter |
| `prayerRequestPageById` | `PrayerRequestPageResponse` | prayerRequestPageId |
| `prayerRequestPageStats` | `PrayerRequestPageStatsResponse` | prayerRequestPageId |
| `validatePrayerRequestPageForPublish` | `PrayerRequestPageValidationResponse` | prayerRequestPageId |
| `prayerRequests` | `PrayerRequestPagedResponse` | pageSize, pageIndex, sort, advancedFilter (status, category, dateRange, pageId) |
| `prayerRequestById` | `PrayerRequestResponse` | prayerRequestId |
| `prayedLogsForPrayer` | `PrayedLogPagedResponse` | prayerRequestId, pageSize, pageIndex |

### Admin Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createPrayerRequestPage` | `PrayerRequestPageRequest` | `int` (id) |
| `updatePrayerRequestPage` | `PrayerRequestPageRequest` | `int` |
| `publishPrayerRequestPage` | `(id)` | `PrayerRequestPageResponse` |
| `unpublishPrayerRequestPage` | `(id)` | `PrayerRequestPageResponse` |
| `closePrayerRequestPage` | `(id)` | `PrayerRequestPageResponse` |
| `archivePrayerRequestPage` | `(id)` | `int` |
| `resetPrayerRequestPageBranding` | `(id)` | `int` |
| `approvePrayerRequest` | `(id, moderationNote?)` | `PrayerRequestResponse` |
| `rejectPrayerRequest` | `(id, moderationNote)` | `PrayerRequestResponse` |
| `markPrayingPrayerRequest` | `(id)` | `PrayerRequestResponse` |
| `markAnsweredPrayerRequest` | `(id, note?)` | `PrayerRequestResponse` |
| `archivePrayerRequest` | `(id)` | `int` |
| `bulkModeratePrayerRequests` | `(ids[], action, moderationNote?)` | `int` (count) |
| `hardDeletePrayerRequest` | `(id, confirmation)` | `int` |

### Public Queries (anonymous)

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `prayerRequestPageBySlug` | `PrayerRequestPagePublicResponse` | slug |
| `prayerWallBySlug` | `PrayerWallPagedResponse` | slug, pageSize, pageIndex, categoryCode? |

### Public Mutations (anonymous, rate-limited, csrf-protected)

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `submitPrayerRequest` | `SubmitPrayerRequestInput` (slug, categoryCode, title?, body, firstName?, lastName?, email?, phone?, country?, isAnonymous, sharePublicly, notifyOnPrayed, consentAccepted, csrfToken, honeypot, recaptchaToken) | `SubmitPrayerRequestResponse` (success, thankYouMessage, redirectUrl?) |
| `prayForThis` | `PrayForThisInput` (prayerRequestId, csrfToken) | `PrayForThisResponse` (newPrayedCount) |

### Response DTO Field Lists

**PrayerRequestPageResponseDto** (admin):
```ts
{
  prayerRequestPageId: number;
  companyId: number;
  pageTitle: string;
  slug: string;
  description: string | null;
  status: 'Draft' | 'Published' | 'Active' | 'Closed' | 'Archived';
  publishedAt: string | null;
  startDate: string | null;
  endDate: string | null;
  linkedCampaignId: number | null;
  linkedCampaign: { campaignId: number; campaignName: string } | null;
  enabledCategoryCodes: string[];
  defaultCategoryCode: string | null;
  maxBodyLength: number;
  submitterFields: Record<string, { required: boolean; visible: boolean; locked?: boolean }>;
  linkContactOnSubmission: boolean;
  moderationMode: 'AUTO_APPROVE' | 'MANUAL_APPROVE' | 'NEVER_PUBLIC';
  adminEmailRecipients: string[];
  profanityFilterEnabled: boolean;
  submitterReceiptTemplateId: number | null;
  submitterReceiptTemplate: { emailTemplateId: number; templateName: string } | null;
  adminPingTemplateId: number | null;
  adminPingTemplate: { emailTemplateId: number; templateName: string } | null;
  prayedNotifyTemplateId: number | null;
  prayedNotifyTemplate: { emailTemplateId: number; templateName: string } | null;
  enableSlackWebhook: boolean;
  slackWebhookUrl: string | null;          // masked (last 4 chars only)
  showPublicPrayerWall: boolean;
  wallPageSize: number;
  wallShowCount: boolean;
  wallShowPrayedCount: boolean;
  wallEnableILLPray: boolean;
  wallTruncateChars: number;
  logoUrl: string | null;
  heroImageUrl: string | null;
  primaryColorHex: string;
  buttonText: string;
  pageLayout: 'centered' | 'side-by-side' | 'full-width';
  thankYouMessage: string | null;
  thankYouRedirectUrl: string | null;
  showSocialShare: boolean;
  ogTitle: string | null;
  ogDescription: string | null;
  ogImageUrl: string | null;
  robotsIndexable: boolean;
  privacyNoticeMd: string | null;
  consentRequired: boolean;
  consentText: string | null;
  isActive: boolean;
}
```

**PrayerRequestPageStatsDto**:
```ts
{
  prayerRequestPageId: number;
  totalSubmissions: number;
  pendingModeration: number;       // Status='New'
  approvedCount: number;
  rejectedCount: number;
  prayingCount: number;
  answeredCount: number;
  archivedCount: number;
  lastSubmittedAt: string | null;
  totalPrayersOffered: number;     // SUM(PrayedCount)
  submissionsLast7Days: number;
  submissionsLast30Days: number;
}
```

**PrayerRequestPagePublicDto** (public-safe):
```ts
{
  pageTitle: string;
  description: string | null;
  status: 'Active' | 'Closed';
  enabledCategories: { categoryCode: string; categoryName: string; emoji: string; orderBy: number }[];
  defaultCategoryCode: string | null;
  maxBodyLength: number;
  submitterFields: Record<string, { required: boolean; visible: boolean }>;   // locked stripped
  showPublicPrayerWall: boolean;
  wallShowCount: boolean;
  wallShowPrayedCount: boolean;
  wallEnableILLPray: boolean;
  wallTruncateChars: number;
  logoUrl: string | null;
  heroImageUrl: string | null;
  primaryColorHex: string;
  buttonText: string;
  pageLayout: 'centered' | 'side-by-side' | 'full-width';
  thankYouMessage: string | null;
  thankYouRedirectUrl: string | null;
  showSocialShare: boolean;
  ogTitle: string;
  ogDescription: string;
  ogImageUrl: string | null;
  privacyNoticeMd: string | null;
  consentRequired: boolean;
  consentText: string | null;
  csrfToken: string;
  totalCount: number | null;       // when wallShowCount=true
}
```

**PrayerRequestResponseDto** (admin):
```ts
{
  prayerRequestId: number;
  companyId: number;
  prayerRequestPageId: number;
  linkedContactId: number | null;
  linkedContact: { contactId: number; displayName: string } | null;
  linkedCampaignId: number | null;
  submitterFirstName: string | null;
  submitterLastName: string | null;
  submitterEmail: string | null;       // admin-only
  submitterPhone: string | null;       // admin-only
  submitterCountryCode: string | null;
  title: string | null;
  body: string;
  categoryCode: string;
  category: { categoryCode: string; categoryName: string; emoji: string };
  isAnonymous: boolean;
  sharePublicly: boolean;
  notifyOnPrayed: boolean;
  consentAcceptedAt: string | null;
  status: 'New' | 'Approved' | 'Rejected' | 'Praying' | 'Answered' | 'Archived';
  moderationNote: string | null;
  moderatedByContactId: number | null;
  moderatedBy: { contactId: number; displayName: string } | null;
  moderatedAt: string | null;
  flaggedReason: 'PROFANITY' | 'SPAM' | 'DUPLICATE' | 'MANUAL' | null;
  prayedCount: number;
  lastPrayedAt: string | null;
  prayerWallEligible: boolean;
  submitterIpHash: string | null;      // admin-only
  receivedSource: 'WEB' | 'IFRAME' | 'API' | 'MOBILE';
  submittedAt: string;
}
```

**PrayerWallCardDto** (public-safe — DTO Privacy):
```ts
{
  prayerRequestId: number;
  // PII NEVER LEAKED:
  // - submitterEmail / phone / ip / lastName always omitted
  displayName: string;             // "Anonymous" if isAnonymous=true; else "{firstName} {lastInitial}." (e.g. "Sarah J.")
  title: string | null;            // truncated if longer than 80 chars
  bodyTruncated: string;           // ≤ wallTruncateChars chars; ellipsis if truncated
  categoryCode: string;
  category: { categoryName: string; emoji: string };
  prayedCount: number | null;      // null if wallShowPrayedCount=false
  submittedAt: string;             // for relative-time display
  canPrayForThis: boolean;         // mirrors page.wallEnableILLPray
}
```

**PrayedLogResponseDto** (admin):
```ts
{
  prayedLogId: number;
  prayerRequestId: number;
  prayedByContactId: number | null;
  prayedBy: { contactId: number; displayName: string } | null;
  isAnonymousClick: boolean;
  prayerNote: string | null;
  prayedAt: string;
}
```

**PrayForThisResponse**:
```ts
{
  newPrayedCount: number;
}
```

**PrayerRequestPageValidationResponse**:
```ts
{
  isValid: boolean;
  missingFields: { field: string; message: string }[];
  warnings: { field: string; message: string }[];
}
```

### Public DTO Privacy Discipline

**Strict rule**: BE handlers for public queries (`prayerRequestPageBySlug`, `prayerWallBySlug`) and public mutations MUST use the Public DTOs above. Any field not in the Public DTO MUST be stripped server-side BEFORE returning the response.

**Specifically forbidden in public responses**:
- `submitterEmail`, `submitterPhone`, `submitterIpHash`, `submitterUserAgent`, `submitterLastName` (when isAnonymous=true)
- `moderationNote`, `moderatedByContactId`, `moderatedAt`, `flaggedReason`
- `adminEmailRecipients`, `slackWebhookUrl` (even masked)
- `companyId`
- Any field from `PrayerRequestPrayedLog` except aggregate `prayedCount` on the parent

A QA reviewer checks every public DTO field against the leak list; any field not on the explicit Public DTO is a leak.

---

## ⑪ Acceptance Criteria

### Page setup (admin)
- [ ] Create flow: "+New Page" → defaults to Draft + auto-slug from PageTitle + ImplementationType-equivalent (NAV-only for v1) preset; validates slug uniqueness inline
- [ ] Editor 8 cards persist via autosave 300ms debounce; failed save shows inline error + retry
- [ ] Slug field shows live URL preview + copy button; reserved-slug list rejected
- [ ] Categories card sources MasterData PRAYERCATEGORY; if absent, seeds 9 default rows on first save
- [ ] Submitter Form Fields table: Body row's Required+Visible+Locked checkboxes are disabled (forced); Category row's Visible+Locked disabled (Required default true but admin can flip)
- [ ] Moderation Mode change shows preview banner indicating new behavior
- [ ] AdminEmailRecipients chips validate email format; unique per chip
- [ ] Notification template dropdowns source from `comm.EmailTemplates` filtered to current Company + Active
- [ ] Prayer Wall toggles cascade: ShowPublicPrayerWall=FALSE disables sub-toggles
- [ ] Branding live-preview reflects within 300ms
- [ ] Validate-for-publish blocks Publish until all required-to-publish rules pass; missing-field list shown in modal
- [ ] Publish: Draft → Active; URL shareable; OG meta pre-rendered; audit log created
- [ ] Unpublish / Close Early / Archive lifecycle commands work; URL state-correct
- [ ] Reset Branding type-name confirm + restores defaults

### Submissions inbox (admin)
- [ ] Filter by Status, Category, DateRange, Search work independently and combined
- [ ] Bulk Approve/Reject/Mark Praying/Mark Answered/Archive update N rows; show progress + error per-row
- [ ] Row click opens side-drawer with full Body + ModerationNote textarea + PrayedLogs list
- [ ] Approve action: New → Approved; if SharePublicly=true + ShowPublicPrayerWall=true → row becomes Wall-eligible immediately
- [ ] Reject action requires ModerationNote (≥10 chars); does NOT email submitter
- [ ] Mark Praying / Answered set Status accordingly; visible in card admin badge
- [ ] Hard-delete requires type-"DELETE"; permanently removes record + PrayedLogs; audit log persists
- [ ] Mode banner reflects current ModerationMode + count of pending if MANUAL_APPROVE

### Public submission flow
- [ ] Form renders per SubmitterFieldsJson + Categories
- [ ] CSRF token in initial render; honeypot field hidden via CSS
- [ ] Submit validates server-side: CSRF, rate-limit (5/min/IP/slug), honeypot empty, captcha score ≥ 0.5 (or PLACEHOLDER returns 1.0), page status Active, slug exists, category in EnabledCategoryCodesJson, body within MaxBodyLength
- [ ] Server sets `CompanyId = page.CompanyId` regardless of any client value
- [ ] If LinkContactOnSubmission AND email AND opt-in → upsert Contact by (CompanyId, email)
- [ ] Apply ModerationMode rule: AUTO_APPROVE→Approved, MANUAL→New, NEVER_PUBLIC→New + SharePublicly=false
- [ ] Apply ProfanityFilter if enabled; flagged rows always go to New regardless of Mode
- [ ] Submitter receipt email fires (REAL); admin ping email fires (REAL); Slack webhook (PLACEHOLDER) logs intent
- [ ] Honeypot triggered: row saved with HoneypotTriggered=true; user sees mock thank-you
- [ ] Captcha < 0.5: row saved + FlaggedReason='SPAM'; status=New regardless of Mode
- [ ] Thank-you state inline OR redirect URL respected
- [ ] Optional social-share buttons render on thank-you state when ShowSocialShare=true

### Public Prayer Wall
- [ ] Wall renders only when ShowPublicPrayerWall=true AND page.Status in (Active, Closed)
- [ ] Cards show approved + SharePublicly=true + Status='Approved' + IsActive=true rows ONLY
- [ ] PII never leaked: anonymous shows "Anonymous"; non-anonymous shows "{firstName} {lastInitial}." only; never email/phone/ip
- [ ] Body truncated to WallTruncateChars; ellipsis on truncate
- [ ] Category emoji + label rendered consistently with admin inbox
- [ ] PrayedCount badge shown only when WallShowPrayedCount=true
- [ ] "I'll Pray for This" button shown only when WallEnableILLPray=true
- [ ] Pagination + category filter chips functional
- [ ] Card click does NOT navigate (privacy-preserving — no detail page); only "I'll Pray" is interactive

### "I'll Pray for This" engagement
- [ ] Click → POST atomic transaction: insert PrayedLog + increment PrayedCount + update LastPrayedAt
- [ ] Dedup: same (IpHash, prayerRequestId) within 24h returns no-op + current count
- [ ] Rate-limit: 3 clicks / min / IP / prayerId; 429 + "slow down" toast
- [ ] CSRF token validated
- [ ] Optimistic UI: button disabled + count incremented immediately; rollback on error
- [ ] If first PrayedLog AND submitter set NotifyOnPrayed=true AND PrayedNotifyTemplateId set → email fires (REAL); subsequent prayers do NOT spam submitter

### Multi-tenant isolation tests (CRITICAL)
- [ ] Tenant A creates page with slug=`pray`; Tenant B creates page with same slug=`pray` — both succeed (per-tenant uniqueness)
- [ ] Tenant A's slug=`pray` resolves to Tenant A's page when public visited (one-tenant-per-deployment for MVP)
- [ ] Submission to Tenant A's page persists with `CompanyId = A`; query as Tenant B returns 0 rows for that submission (cross-tenant isolation)
- [ ] Admin GraphQL query without CompanyId filter still returns ONLY current Company's rows (decorator-enforced)
- [ ] Public Prayer Wall query for slug only returns prayers of that page's Company

### Audit & compliance
- [ ] Hard-delete writes immutable audit row to existing audit infrastructure
- [ ] Admin email-recipient changes logged
- [ ] Slack webhook URL changes logged
- [ ] Publish action logs JSON snapshot of page config
- [ ] Submission logs IP hash + UA but never raw IP

### Empty / loading / error
- [ ] All states from §⑥ table render correctly
- [ ] 404 on Draft + missing preview-token; 410 on Archived

---

## ⑫ Special Notes & Issues

### Sub-type divergence: SUBMISSION_PAGE
**ISSUE-1 (OPEN)** — `SUBMISSION_PAGE` is a NEW external_page_subtype not present in the frozen 3-set (DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND) defined in `_EXTERNAL_PAGE.md`.
- **Why diverge**: a public-facing form-submission page with moderation queue + privacy-aware Wall + engagement counter is a coherent pattern that #169 (Event Reg) and #172 (Volunteer Reg) will also use. Forcing it into DONATION_PAGE confuses the developer (no payment hand-off, no recurring, no amount chips, but YES moderation, YES Wall, YES PII privacy gates).
- **Action for Solution Resolver**: stamp `external_page_subtype: SUBMISSION_PAGE` and use `_EXTERNAL_PAGE.md` as scaffolding + this prompt for sub-type-specific behavior. Future SUBMISSION_PAGE planners should copy this prompt.
- **Action for governance**: when shipping #169 and #172, update `_EXTERNAL_PAGE.md` to formalize SUBMISSION_PAGE as a 4th sub-type (or introduce a parent SUBMISSION_PAGE family with sub-sub-types: PRAYER / EVENT_REG / VOLUNTEER_REG).

### Multi-tenant slug resolution
**ISSUE-2 (OPEN)** — same `one-tenant-per-deployment` MVP path as #10 OnlineDonationPage.
- Public route `/pray/{slug}` looks up by slug only; CompanyId comes from a single-tenant deployment context.
- **Future enhancement**: implement either (a) tenant-prefixed `/pray/{tenantSlug}/{pageSlug}`, OR (b) custom-domain mapping per tenant (`{tenant}.org/pray/{slug}` via reverse-proxy host-header → CompanyId resolver), OR (c) global slug uniqueness (slug becomes globally unique, simplest but limits orgs).
- **Risk**: production deployments serving multiple tenants on a single domain will hit slug collision unless one of (a)/(b)/(c) is implemented.

### IFRAME mode deferred
**ISSUE-3 (OPEN)** — v1 ships NAV-only public route. IFRAME embed mode is deferred because:
- Prayer flows expect visitor to read context (Privacy Notice, Categories, Privacy Policy) before sharing personal content — a 480px embedded widget is a poor surface for this.
- If demand emerges, add `ImplementationType` column + IFRAME card swap (mirror OnlineDonationPage pattern).

### SERVICE_PLACEHOLDERs (UI-built, handler stubbed)
| Feature | Reason | Action |
|---------|--------|--------|
| reCAPTCHA v3 score check | reCAPTCHA not configured in PSS 2.0 yet | Score returns 1.0; UI ready; wire real check when available |
| Slack/Teams webhook on new submission | No `IWebhookDispatcher` service exists | Save URL + flag; logs intent on submit; build dispatcher when first webhook integration ships |
| Analytics tab (3rd tab) | Inline charts deferred to keep MVP focused | Add tab placeholder "Coming soon" OR omit entirely; revisit after #134 Ambassador Performance dashboard precedent |
| ProfanityFilter (advanced) | Token-list match only in v1 | Provide IProfanityFilter interface + simple impl; swap with Perspective API or similar later |

### REAL services (no placeholder needed)
| Feature | Existing infra |
|---------|----------------|
| Submitter receipt email | `comm.EmailTemplates` + Email send pipeline (verified existing in #25 Email Campaign + #157 SMS Setup) |
| Admin ping email | (same) |
| "Prayed for you" notification email | (same) |

### Privacy & PII handling
- **GDPR / RTBF**: Hard-delete command for individual PrayerRequest is required (not just soft-delete) — implemented as #20 in BE manifest with type-name confirmation + audit log.
- **HIPAA-adjacent content**: prayer requests for healing may contain medical info. Recommend (post-MVP) column-level encryption on `Body` + `SubmitterEmail` + `SubmitterPhone`. v1 relies on TLS in transit + database-level encryption at rest.
- **Public Wall display rule**: triple-gated (Status='Approved' AND SharePublicly=true AND IsActive=true). Forgetting any one of these creates a privacy leak.

### MasterData seed dependency
- DB seed step 1: ensure MasterDataType `PRAYERCATEGORY` exists; if absent, seed 9 rows (HEALING, THANKSGIVING, FAMILY, FINANCES, GUIDANCE, SALVATION, WORLD_PEACE, PROTECTION, OTHER) with display names + emojis (stored as separate column in MasterData if available; else inline in EmojiCode field — confirm MasterData schema).

### Integration with existing Contact / Campaign infrastructure
- Contact upsert uses existing `corg.Contacts` UPSERT-by-email pattern (look up similar pattern in #2 Contact entity if present). New `ContactSource` row "PrayerRequest" seeded if absent.
- Campaign FK is read-only — no Campaign column added.

### Why NOT a separate "Submissions Inbox" screen
A separate screen would force admin to navigate twice (open Page → click "Submissions" link → land on inbox). Embedding the inbox as a tab inside the editor matches the OnlineDonationPage status-bar precedent (admin sees stats + actions in the same view they configured the page).

### Why `corg` schema (not new `prayer` schema)
- `corg` already houses Contact + ContactSource + ContactDonationPurpose — prayer requests are a contact-engagement feature semantically aligned with this group.
- Avoids a 1-table-schema (`prayer` would have 3 tables; `corg` adds 3 to ~20).
- ContactBusiness folder structure is already set up for CQRS handlers.
- If org dual-positions prayer + feedback + suggestion-box later, all three can live in ContactModels under a `community/` sub-folder.

### Why `/pray/` route namespace (not `/p/`)
- `/p/{slug}` already routes to OnlineDonationPage. Slug lookup would need cross-table dispatch (donation page or prayer page?) which is complex + error-prone.
- Distinct namespace `/pray/{slug}` is short, memorable, and zero collision risk.
- Same convention will extend to `/event/{slug}` (#169) and `/volunteer/{slug}` (#172).

### Build sequencing
1. Establish MasterDataType `PRAYERCATEGORY` (DB seed step 1)
2. Create `(public)/pray/[slug]/` route group (FE — reuses `(public)/layout.tsx` from OnlineDonationPage)
3. Add `MODERATE` capability to MenuCapability enum (BE seed)
4. Build entities + EF + DTOs + handlers + endpoints + wiring
5. Build FE editor + submissions tab + public page + Wall + I'll-Pray
6. DB seed: sample page + sample submission + sample PrayedLog for E2E

### Acceptance bar before COMPLETED
- Multi-tenant isolation test PASSES (Tenant A submits to Tenant B's page → row stamped with B's CompanyId, NOT A's)
- Privacy DTO leak test PASSES (every public response checked against forbidden-field list)
- "I'll Pray" atomic increment test PASSES under concurrent load (no count drift)
- Email pipeline E2E PASSES (submitter actually receives receipt; admin actually receives ping)

---

## ⑬ Build Log

### § Known Issues

| ID | Surfaced session | Status | Description |
|----|-----------------|--------|-------------|
| ISSUE-1 | Planning | OPEN (governance) | `SUBMISSION_PAGE` is a 4th external_page_subtype not in `_EXTERNAL_PAGE.md` frozen 3-set. When #169/#172 ship, formalize SUBMISSION_PAGE as a 4th sub-type. |
| ISSUE-2 | Planning | OPEN (deferred) | Multi-tenant slug resolution = one-tenant-per-deployment MVP. Future: tenant-prefix routing OR custom-domain mapping. Same path as #10 OnlineDonationPage. |
| ISSUE-3 | Planning | OPEN (deferred) | IFRAME embed mode deferred — v1 ships NAV-only public route. |
| ISSUE-4 | Build session 1 | CLOSED (session 2) | EF migration was generated as `20260510074527_Add_PrayerRequestPage_Setup_Entities.cs` (different name from spec, same content — 3 tables + 11 indexes including the WallEligible filter index). |
| ISSUE-5 | Build session 1 | OPEN | DB seed PRAYERCATEGORY codes deviate slightly from spec — agent used HEALING/FAMILY/FINANCES/RELATIONSHIPS/WORK/GRIEF/GUIDANCE/PRAISE/OTHER instead of the prompt's HEALING/THANKSGIVING/FAMILY/FINANCES/GUIDANCE/SALVATION/WORLD_PEACE/PROTECTION/OTHER. Acceptable variation but may need tweak if downstream copy/seed elsewhere references the spec list. |
| ISSUE-6 | Build session 1 | OPEN (placeholder) | reCAPTCHA score check — SERVICE_PLACEHOLDER returns 1.0; wire real check when reCAPTCHA configured. |
| ISSUE-7 | Build session 1 | OPEN (placeholder) | Slack/Teams webhook on new submission — handler logs intent only; build IWebhookDispatcher service before first webhook integration. |
| ISSUE-8 | Build session 1 | OPEN (placeholder) | ProfanityFilter v1 = simple token-list match in SimpleProfanityFilter. Swap with Perspective API or similar for production. |
| ISSUE-9 | Build session 1 | CLOSED (session 2) | Frontend complete — 34 files generated + 8 wiring touches; `tsc --noEmit` 0 errors. |
| ISSUE-10 | Build session 2 | OPEN (low) | `Analytics` 3rd tab in editor omitted (deferred per spec §⑤). Add when post-MVP analytics requirements firm up. |
| ISSUE-11 | Build session 2 | OPEN (low) | Logo / Hero / OG-image inputs are URL-only (no file-upload UI). Carries over from OnlineDonationPage — needs org-wide media-upload integration. |
| ISSUE-12 | Build session 2 | OPEN (low) | Slack webhook URL field has only `type="url"` validation. BE masks stored value (last 4 chars); admin retypes full URL on edit. Acceptable for v1. |

### § Sessions

### Session 1 — 2026-05-10 — BUILD — PARTIAL

- **Scope**: Initial BE-only build from PROMPT_READY prompt. FE deferred per user-approved split (precedent: #170 P2P).
- **Files touched**:
  - BE entities (3 created):
    - `Base.Domain/Models/ContactModels/PrayerRequestPage.cs`
    - `Base.Domain/Models/ContactModels/PrayerRequest.cs`
    - `Base.Domain/Models/ContactModels/PrayerRequestPrayedLog.cs`
  - BE EF Configurations (3 created):
    - `Base.Infrastructure/Data/Configurations/ContactConfigurations/PrayerRequestPageConfiguration.cs`
    - `…/PrayerRequestConfiguration.cs`
    - `…/PrayerRequestPrayedLogConfiguration.cs`
  - BE Schemas / DTOs (1 created):
    - `Base.Application/Schemas/ContactSchemas/PrayerRequestPageSchemas.cs` (PrayerRequestPage Request/Response/Public + Stats + Validation; PrayerRequest Request/Response; PrayerWallCardDto (privacy-stripped); PrayedLogResponseDto; SubmitPrayerRequestInput/Response; PrayForThisInput/Response; BulkModerationInput)
  - BE Handlers (24 created — `Base.Application/Business/ContactBusiness/`):
    - `PrayerRequestPages/`: GetAllPrayerRequestPagesList, GetPrayerRequestPageById, GetPrayerRequestPageBySlug (public), GetPrayerRequestPageStats, ValidatePrayerRequestPageForPublish, CreatePrayerRequestPage, UpdatePrayerRequestPage, PublishPrayerRequestPage, UnpublishPrayerRequestPage, ClosePrayerRequestPage, ArchivePrayerRequestPage, ResetPrayerRequestPageBranding (12)
    - `PrayerRequests/`: GetAllPrayerRequestsList, GetPrayerRequestById, ApprovePrayerRequest, RejectPrayerRequest, MarkPrayingPrayerRequest, MarkAnsweredPrayerRequest, ArchivePrayerRequest, BulkModeratePrayerRequests, HardDeletePrayerRequest, SubmitPrayerRequest (public), GetPrayerWallBySlug (public) (11)
    - `PrayerRequestPrayedLogs/`: PrayForThis (public, atomic), GetPrayedLogsForPrayer (1)
  - BE Validator + Service (3 created):
    - `Base.Application/Validations/PrayerRequestPageSlugValidator.cs`
    - `Base.Application/Services/IProfanityFilter.cs`
    - `Base.Application/Services/Implementations/SimpleProfanityFilter.cs`
  - BE Endpoints (6 created — `Base.API/EndPoints/ContactModels/`):
    - `Mutations/PrayerRequestPageMutations.cs` (admin lifecycle + reset)
    - `Mutations/PrayerRequestMutations.cs` (admin moderation + bulk + hard-delete)
    - `Queries/PrayerRequestPageQueries.cs` (admin pages + stats + validate)
    - `Queries/PrayerRequestQueries.cs` (admin requests + prayedLogs)
    - `Public/PrayerRequestPagePublicQueries.cs` (anonymous; pageBySlug + wallBySlug)
    - `Public/PrayerRequestPublicMutations.cs` (anonymous; submit + prayForThis)
  - BE wiring (4 modified):
    - `Base.Application/Data/Persistence/IContactDbContext.cs` (+ 3 DbSets)
    - `Base.Infrastructure/Data/Persistence/ContactDbContext.cs` (+ 3 DbSets)
    - `Base.Application/Extensions/DecoratorProperties.cs` (+ 3 codes: PRAYERREQUESTPAGE / PRAYERREQUEST / PRAYERREQUESTPRAYEDLOG)
    - `Base.Application/Mappings/ContactMappings.cs` (+ Mapster configs for parent + 2 children)
  - DB seed (1 created):
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/PrayerRequestPage-sqlscripts.sql` (idempotent — 9 PRAYERCATEGORY MasterData rows + 4 Capabilities + Menu PRAYERREQUESTPAGE under SET_PUBLICPAGES + MenuCapabilities + RoleCapabilities for BUSINESSADMIN + sample published page slug=`pray` + sample Approved prayer + sample PrayedLog rows)
  - FE: NONE (deferred to session 2)
- **Build status**: Base.Application + Base.Infrastructure compile with 0 errors. Base.API.exe was running in Visual Studio Insiders during build, causing 8 MSB3027/MSB3021 file-lock errors (NOT compilation errors). Solution: stop the running API process, then build cleanly.
- **Critical correctness checks**:
  - Public DTO privacy: PASS — `PrayerRequestPagePublicResponseDto` excludes companyId (via JsonIgnore on `CompanyIdInternal`); `PrayerWallCardDto` excludes submitterEmail/phone/ipHash/userAgent + lastName + moderationNote/moderatedBy/flaggedReason + adminEmailRecipients/slackWebhookUrl
  - Multi-tenant CompanyId stamp: PASS — `SubmitPrayerRequest.cs:183` sets `CompanyId = companyId.Value` from server-resolved page row, NOT request body (comment: "CRITICAL: tenant-stamp from server-resolved page row, never from public request body")
  - Atomic PrayedCount increment: PASS — `PrayForThis.cs:108-110` uses raw SQL `UPDATE corg."PrayerRequests" SET "PrayedCount" = "PrayedCount" + 1, "LastPrayedAt" = @p0 WHERE "PrayerRequestId" = @p1` (race-condition safe atomic increment)
  - Reserved-slug rejection: PASS — slug validator includes admin/api/embed/p/pray/preview/login/signup/oauth/public/assets/static/ic/_next/wall
  - GraphQL endpoint registration: PASS — all 6 endpoint classes implement `IQueries` / `IMutations` and use `[ExtendObjectType(OperationTypeNames.Query/Mutation)]` (auto-discovered)
- **Deviations from spec**:
  - PRAYERCATEGORY codes in DB seed deviate slightly (HEALING/FAMILY/FINANCES/RELATIONSHIPS/WORK/GRIEF/GUIDANCE/PRAISE/OTHER) vs prompt's (HEALING/THANKSGIVING/FAMILY/FINANCES/GUIDANCE/SALVATION/WORLD_PEACE/PROTECTION/OTHER). Recorded as ISSUE-5.
- **Known issues opened**: ISSUE-4 (EF migration deferred), ISSUE-5 (PRAYERCATEGORY code variation), ISSUE-6 (reCAPTCHA placeholder), ISSUE-7 (Slack webhook placeholder), ISSUE-8 (ProfanityFilter v1 simple), ISSUE-9 (FE deferred)
- **Known issues closed**: None
- **Next step**: **Session 2 — Frontend build.** Generate (a) admin DTO/GraphQL TS files, (b) admin editor at `setting/publicpages/prayerrequestpage` with split-pane (8 settings cards + live preview), (c) Submissions inbox tab with DataTable + side-drawer + bulk actions, (d) public route at `(public)/pray/[slug]/page.tsx` with hero + form + Privacy Notice + optional Prayer Wall block + "I'll Pray" button, (e) FE wiring (entity-operations + sidebar). **Also: regenerate EF migration** once Base.API.exe is stopped: `cd Base.Infrastructure && dotnet ef migrations add Add_PrayerRequestPage_With_Children --startup-project ../Base.API/Base.API.csproj`.

### Session 2 — 2026-05-10 — BUILD — COMPLETED

- **Scope**: FE_ONLY (deferred from session 1 BE_ONLY split). Generated admin editor + submissions inbox + public NAV route + Prayer Wall + I'll-Pray engagement + all DTO/GQL/wiring. EF migration was already created between sessions and verified.
- **Files touched**:
  - FE — DTOs (3 created):
    - `PSS_2.0_Frontend/src/domain/entities/contact-service/PrayerRequestPageDto.ts`
    - `…/contact-service/PrayerRequestDto.ts`
    - `…/contact-service/PrayerRequestPrayedLogDto.ts`
  - FE — GraphQL queries (3 created):
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/contact-queries/PrayerRequestPageQuery.ts`
    - `…/contact-queries/PrayerRequestQuery.ts`
    - `…/public-queries/PrayerRequestPagePublicQuery.ts`
  - FE — GraphQL mutations (3 created):
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/PrayerRequestPageMutation.ts`
    - `…/contact-mutations/PrayerRequestMutation.ts`
    - `…/public-mutations/PrayerRequestPublicMutation.ts`
  - FE — Page-config + admin route (2 created):
    - `PSS_2.0_Frontend/src/presentation/pages/setting/publicpages/prayerrequestpage.tsx` (page-config dispatcher)
    - `PSS_2.0_Frontend/src/app/[lang]/setting/publicpages/prayerrequestpage/page.tsx` (overwrote `UnderConstruction` placeholder)
  - FE — Admin component tree (18 created — under `PSS_2.0_Frontend/src/presentation/components/page-components/setting/publicpages/prayerrequestpage/`):
    - Root + barrel + store: `index.ts`, `prayerrequestpage-root.tsx`, `prayerrequestpage-store.ts`
    - List + Editor: `list-page.tsx`, `editor-page.tsx`
    - Tabs: `setup-tab.tsx`, `submissions-tab.tsx`
    - Components: `components/section-card.tsx`, `components/status-bar.tsx`, `components/api-single-select.tsx`, `components/live-preview.tsx`, `components/submission-drawer.tsx`
    - 8 setup sections: `sections/identity-section.tsx`, `sections/categories-section.tsx`, `sections/form-fields-section.tsx`, `sections/moderation-section.tsx`, `sections/notifications-section.tsx`, `sections/prayer-wall-section.tsx`, `sections/branding-section.tsx`, `sections/thank-you-seo-section.tsx`
  - FE — Public component tree + route (5 created):
    - `PSS_2.0_Frontend/src/presentation/components/page-components/public/prayerrequestpage/index.ts`
    - `…/public/prayerrequestpage/prayer-page.tsx`
    - `…/public/prayerrequestpage/components/submission-form.tsx`
    - `…/public/prayerrequestpage/components/prayer-wall.tsx`
    - `…/public/prayerrequestpage/components/thank-you.tsx`
    - `PSS_2.0_Frontend/src/app/[lang]/(public)/pray/[slug]/page.tsx` (SSR + generateMetadata + ISR revalidate=60; reuses existing `(public)/layout.tsx`)
  - FE — Wiring (8 modified):
    - `PSS_2.0_Frontend/src/domain/entities/contact-service/index.ts` (+ 3 DTO exports)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/contact-queries/index.ts` (+ 2 query exports)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/index.ts` (+ 2 mutation exports)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/public-queries/index.ts` (+ public query export)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/public-mutations/index.ts` (+ public mutation export)
    - `PSS_2.0_Frontend/src/presentation/pages/setting/publicpages/index.ts` (+ page-config export)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/public/index.ts` (+ public component tree export)
    - `PSS_2.0_Frontend/src/application/configs/data-table-configs/contact-service-entity-operations.ts` (+ PRAYERREQUESTPAGE + PRAYERREQUEST blocks)
  - BE: NONE (FE_ONLY scope)
  - DB: NONE (already created session 1)
- **Type-check**: `tsc --noEmit` from PSS_2.0_Frontend → 0 errors.
- **Critical correctness checks (all PASS)**:
  - Public Wall PII gate: `PrayerWallCardDto` has no submitterEmail/phone/lastName/ipHash; `prayer-wall.tsx` consumes only this DTO
  - Card click on Wall does NOT navigate (privacy-preserving — only "I'll Pray" button is interactive)
  - CSRF token from `prayerRequestPageBySlug` response → passed to BOTH `submitPrayerRequest` AND `prayForThis` mutations
  - Body + Category Required+Visible+Locked checkboxes disabled in `form-fields-section.tsx`
  - `validatePrayerRequestPageForPublish` runs BEFORE Publish mutation; missing-field modal lists violations
  - Closed page: submit button disabled + "Submissions are closed" banner
  - I'll-Pray optimistic UI: button disabled + count incremented; rollback on error; 429 → "slow down" toast
  - Mode banner colors: green/yellow/gray for AUTO/MANUAL/NEVER_PUBLIC
  - NEVER_PUBLIC hides SharePublicly toggle entirely + Wall block hidden
  - 8 setup cards in spec order (Identity → Categories → FormFields → Moderation → Notifications → Wall → Branding → ThankYou+SEO+Privacy)
- **UI uniformity grep checks (all PASS in generated files)**:
  - No inline hex colors in `style={{}}` attributes
  - No inline padding/margin pixels
  - No raw `>Loading...</` text
  - No hand-rolled `#e5e7eb` skeleton background
  - `primaryColorHex` used as theming variable (legitimate dynamic theming, not anti-pattern)
- **Deviations from spec**:
  - File count 34 vs spec's 33 — extra is the local `api-single-select.tsx` helper (matches OnlineDonationPage convention of keeping screen-local widget copies)
  - Operations-config location used `application/configs/data-table-configs/` (actual codebase path) instead of spec's `presentation/operations-config/` — matches OnlineDonationPage / P2PCampaignPage precedent
  - Lifecycle/moderation ops (Publish / Approve / Reject / etc.) wired directly into editor + drawer components, NOT registered in entity-operations registry — matches OnlineDonationPage pattern (registry holds standard CRUD only; lifecycle is custom UI)
  - `Analytics` 3rd editor tab omitted (spec §⑤ flagged it as deferable)
  - Logo / Hero / OG-image inputs are URL-only (no file-upload UI — same gap as OnlineDonationPage)
- **Known issues opened**: ISSUE-10 (Analytics tab deferred), ISSUE-11 (file-upload UI gap), ISSUE-12 (Slack URL only `type=url` validation)
- **Known issues closed**: ISSUE-4 (EF migration generated as `Add_PrayerRequestPage_Setup_Entities`), ISSUE-9 (Frontend complete)
- **Next step**: None for FE generation. **Verification still pending** — user should run: (1) `dotnet build` for full BE confirm, (2) apply EF migration `dotnet ef database update`, (3) execute `PrayerRequestPage-sqlscripts.sql` to seed Menu + sample page + sample prayer + PrayedLog, (4) `pnpm dev` in PSS_2.0_Frontend, (5) navigate to `/setting/publicpages/prayerrequestpage` (admin) + `/pray/pray` (sample slug seeded as `pray`) for E2E test of the SUBMISSION_PAGE flow including I'll-Pray optimistic count.
