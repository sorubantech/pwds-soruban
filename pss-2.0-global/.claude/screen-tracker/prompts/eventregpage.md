---
screen: EventRegistrationPage
registry_id: 169
module: Setting (Public Pages)
status: IN_PROGRESS
scope: FULL
screen_type: EXTERNAL_PAGE
external_page_subtype: DONATION_PAGE
complexity: High
new_module: NO
planned_date: 2026-05-13
completed_date: 2026-06-08
last_session_date: 2026-06-11
revision: "Wave 4 (re-planned 2026-06-11) — Registrant Field-Model Redesign + ContactCode persistence (resolves ISSUE-38). Fixes 4 breakages (B1 seed only FULLNAME+EMAIL; B2 GQL fieldName:fieldLabel feeds label not code; B3 canonical-code drift; B4 handler drops 6 system fields + ContactCode). 9 canonical PascalCase codes (FULLNAME→FirstName+LastName); seed all 9 on create + idempotent backfill SQL; both queries select fieldCode+fieldLabel; +10 Provided* columns on app.EventRegistrations (ODP OnlineDonationStaging parity) incl ProvidedContactCode; Card 5 keys off fieldCode; Custom Questions → Coming Soon. NO new tables. User-owned migration. See §⓪″ REVISION block (authoritative delta). Status COMPLETED→PROMPT_READY for the Wave-4 build. ───── Wave 3 (re-planned 2026-06-08) — Event Email Communication subsystem: (1) donor announcement on Publish [bulk EmailSendJob pipeline, AnnouncementSentAt guard], (2) per-registration payment-success + tickets emails [fire-on-action, SendEmailByTemplateKeyAsync], (3) post-event feedback + reminders via ONE daily Hangfire RecurringJob 'event-communication-dispatcher' [ReminderSentAt/FeedbackSentAt guards]. EventCommunicationTrigger becomes the live policy gate. +4 cols on app.EventRegistrationPages (AnnouncementSentAt/ReminderSentAt/FeedbackSentAt/FeedbackUrl). See §⓪′ REVISION block (authoritative delta). Status reset COMPLETED→PROMPT_READY for the Wave-3 build. ───── Wave 2 (re-planned 2026-06-04) — payment-gateway config + page-template FK + ODP-link Donate button + Speakers/Gallery CRUD + Coming-Soon toggles. See §⓪ REVISION block."
mockup_status: TBD — §⑥ blueprint derived from sibling prompts (#172 volunteerregpage + #173 crowdfundingpage) and the existing `organization/event-form.html` (Registration tab + Settings tab) + `organization/event-ticketing.html`. **Validate §⑥ with user before /build-screen.**
consolidation_note: "2026-06-10 — The #169 ADMIN EDITOR (`EventRegistrationPageEditorPage`, already `eventId`-prop-driven) is being EMBEDDED as TAB 4 of the #40 Event host screen (see prompts/event.md §⓪ CONSOLIDATION REVISION — AUTHORITATIVE). It ABSORBS the old Event 'Content & Speakers' concerns (banner/agenda/speakers/gallery — #169 already owns Branding/Speakers/Gallery cards; +`detailedAgendaHtml` added). Editor gains an `embedded?` prop (hide back/chrome, suppress beforeunload, inline Save). Standalone EVENTREGPAGE menu → IsLeastMenu=false; route `setting/publicpages/eventregpage` redirects into `crm/event/event?…&tab=4`. The PUBLIC page `(public)/event/[slug]` is UNAFFECTED (stays standalone). Build via /build-screen #40, NOT #169. This screen's editor files stay on disk (imported by the host tab)."
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — **N/A: Mockup TBD**. Patterned after `volunteerregpage.md` (SUBMISSION_PAGE pattern → re-stamped as DONATION_PAGE per sibling convention) and `crowdfundingpage.md` (wraps existing entity pattern). Event-specific UI sourced from existing `organization/event-form.html` Registration + Settings tabs and `organization/event-ticketing.html`.
- [x] Business context read (audience = anonymous prospective attendees; conversion goal = completed event-registration form → `app.EventRegistrations` row created; lifecycle = Draft → Published → Active → Closed → Archived)
- [x] Setup vs Public route split identified (admin at `setting/publicpages/eventregpage` + anonymous public at `(public)/event/{slug}` — distinct from donation `/p/`, P2P `/p2p/`, crowdfund `/crowdfund/`, volunteer `/volunteer/`, prayer `/pray/` namespaces)
- [x] Slug strategy chosen: `custom-with-fallback` (auto-from-EventName; admin can override; per-tenant unique; reserved-slug list rejected)
- [x] Lifecycle states confirmed: Draft / Published / Active / Closed / Archived (PAGE lifecycle — orthogonal to existing EventStatusId which governs the EVENT lifecycle Upcoming/Live/Completed/Cancelled/Postponed)
- [x] Payment gateway integration scope: paid-ticket flow uses existing `fund.CompanyPaymentGateways` (same plumbing as #173 CrowdFund); free-ticket path bypasses gateway; real Stripe/PayPal hand-off is SERVICE_PLACEHOLDER until gateway connect implemented
- [x] FK targets resolved (paths + GQL queries verified — see §③ — all FK targets already in code from #23/#40 Event ALIGN + #137 EventTicketing)
- [x] File manifest computed — **wraps existing Event entity from #23/#40** + reuses existing `EventTicketType`, `EventRegistrationFormField`, `EventCustomQuestion`, `EventSuggestedAmount`, `EventCommunicationTrigger`, `EventGalleryPhoto`, `EventSpeaker`, `EventRegistration` child entities. NO new entity files for children; small additive Event field set + new handlers + new endpoints + admin setup shell + public SSR page.
- [x] Approval config pre-filled (MenuCode=`EVENTREGPAGE`, ParentMenu=`SET_PUBLICPAGES`, MenuUrl=`setting/publicpages/eventregpage`, OrderBy=6 — between VOLUNTEERREGPAGE OrderBy=5 and CROWDFUNDINGPAGE OrderBy=7)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (audience + conversion + lifecycle + page-vs-event-status duality) — Session 1 (Prompt §① §② §④ deemed authoritative; no separate BA validation pass needed.)
- [x] Solution Resolution complete (sub-type DONATION_PAGE — single page + admin setup + slug + publish lifecycle + form-config + branding; storage = wrap existing Event with additive page-lifecycle fields)
- [x] **MOCKUP REVIEW** — Session 1 entry decision: proceed with §⑥ blueprint (user opted to "Refer crowdfunding screen #173" as structural reference). Actual HTML mockup at `html_mockup_screens/screens/settings/event-reg-page.html` still TBD for Session 2 FE work.
- [x] UX Design finalized — defer detailed UX architect pass to Session 2 FE_ONLY (Session 1 was BE_ONLY; §⑥ blueprint stands).
- [x] User Approval received (2026-05-13 — scope=BE_ONLY this session, FE_ONLY next; icon `ph:ticket`; ISSUE-11 = V1 primary-only; reference pattern = #173 CrowdfundingPage)
- [x] Backend code generated (Session 1 — 20 NEW + 4 MODIFY files)
- [x] Backend wiring complete (Session 1 — `Base.API/DependencyInjection.cs` rate-limit policy added; HotChocolate `[ExtendObjectType]` auto-registers endpoint types)
- [x] Frontend (admin setup) code generated         ← Session 2 FE_ONLY (2026-05-13)
- [x] Frontend (public page) code generated         ← Session 2 FE_ONLY (2026-05-13)
- [x] Frontend wiring complete                       ← Session 2 FE_ONLY (2026-05-13)
- [x] DB Seed script generated (Session 1 — `Services/Base/sql-scripts-dyanmic/event-reg-page-sqlscripts.sql`; Menu + 9 Capabilities + BUSINESSADMIN role grants + Grid + EVENTREGISTRATIONSTATUS MasterData + sample-Event-promote DO block)
- [x] EF Migration generated (Session 1 — `Base.Infrastructure/Migrations/20260513120000_Add_EventRegistrationPage_Fields.cs`; hand-crafted, idempotent Slug backfill + de-dup + NOT NULL + filtered unique index — user must `dotnet ef database update` to apply)
- [x] Registry updated to COMPLETED                  ← Session 2 (2026-05-13)

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — admin setup loads at `/{lang}/setting/publicpages/eventregpage` (replaces UnderConstruction stub OR fresh route)
- [ ] `pnpm dev` — public page loads at `/{lang}/event/{slug}` (e.g. sample `/event/annual-gala-2026`)
- [ ] **DONATION_PAGE-pattern checks** (adapted for event registration):
  - [ ] Setup list view shows all Events with `PublicEventPage = true` as cards with PageStatus badges + event date + registrations-count chip; "+ New Page" routes to existing #40 Event create form (since Event creation owns event fields); a publish-ready Event becomes a Page row in this list
  - [ ] Editor 8 settings cards persist via autosave (300ms debounce); preview pane updates live without round-trip
  - [ ] Slug auto-generated from EventName on first Page save; uniqueness enforced per tenant; reserved slug list rejected (`admin/api/embed/p/p2p/preview/login/auth/start/event-list/events/dashboard/_next`)
  - [ ] Ticket Types card sources from existing `getAllEventTicketTypeList` (per-event) — admin can add/edit/delete via existing handlers + drag-reorder + early-bird-price column + capacity column + available toggle
  - [ ] Registration Form Fields card edits `app.EventRegistrationFormFields` rows — Full Name / Email forced required+visible+locked (disabled checkboxes); other 6 system fields editable per row; "+ Add Custom Field" creates an `app.EventCustomQuestions` row
  - [ ] Donation-on-Page card toggles `AcceptDonations` + `LinkedDonationPurposeId` (FK ApiSelectV2) + `SuggestedAmounts` chip-editor (sources `EventSuggestedAmount` rows) + `ShowFundraisingGoal` + `GoalAmount`
  - [ ] Communication card: ConfirmationTemplate dropdown (FK NotificationTemplate) + SendReminder toggle + ReminderTimingCode + 3 channel toggles (Email/WhatsApp/SMS) — saves to existing Event fields + `EventCommunicationTrigger` table
  - [ ] Branding & SEO card: BannerImageUrl upload + PrimaryColorHex + AccentColorHex + RegistrationPageLayout select + ShareTitle + ShareDescription + ShareImageUrl + RobotsIndexable toggle
  - [ ] QR Check-in toggle (`QrCheckinEnabled`) + Post-event Survey toggle (`PostEventSurveyEnabled`) — saves to existing Event fields
  - [ ] Live preview reflects current setup state (Desktop / Mobile via device-switcher; preview-token banner when PageStatus=Draft)
  - [ ] Validate-for-publish blocks Publish until: EventName + Slug + StartDate + (Capacity > 0 OR ≥1 TicketType with Available=true) + RegistrationOpenDate ≤ RegistrationEndDate + (≥1 TicketType OR Capacity > 0) + BannerImageUrl OR ShareImageUrl set + EventStatusId IN (Upcoming, Live) + ConfirmationTemplateId set if SendConfirmationEmail=true
  - [ ] Publish transitions PageStatus Draft → Active; URL becomes shareable; OG tags pre-rendered in `generateMetadata`; sets `PagePublishedAt = utcNow`
  - [ ] Anonymous public page renders Active status; CSP headers set; CSRF + honeypot + rate-limit (5 attempts/min/IP/slug) enforced on submit
  - [ ] Anonymous registrant submits form → server creates `app.EventRegistrations` row(s) (1 per ticket quantity) with `EventRegistrationCode` auto-generated + `QRCodeToken` if `QrCheckinEnabled` + status=Confirmed (free ticket) OR PendingPayment (paid ticket awaiting gateway confirm); confirmation email fires (SERVICE_PLACEHOLDER if email infra absent)
  - [ ] Paid-ticket flow → InitiateEventRegistration returns paymentSessionId (SERVICE_PLACEHOLDER mock); ConfirmEventRegistration (gateway callback) flips PendingPayment→Confirmed + emits QR code email
  - [ ] PageStatus = Closed renders banner "Registration is closed for this event" + disables Register button on public; RegistrationEndDate < now auto-flips PageStatus → Closed on next public load OR scheduler tick
  - [ ] Capacity-met state: when SUM(Quantity) of Confirmed registrations ≥ Event.Capacity → renders "Event is full — join waitlist" CTA if `WaitlistEnabled=true` AND waitlist still has capacity, OR "Event is full" banner with Register disabled
  - [ ] Status Bar in admin setup shows real aggregates (totalRegistrations / confirmedCount / pendingPaymentCount / waitlistCount / capacityUsedPct / lastRegistrationAt) sourced from `GetEventRegistrationPageStats`
  - [ ] PageStatus = Archived returns 410 Gone
- [ ] Empty / loading / error states render on both setup and public surfaces
- [ ] DB Seed — admin menu visible at `SET_PUBLICPAGES > EVENTREGPAGE` OrderBy=6; sample published page renders for E2E QA at `/event/annual-gala-2026`

---

## ⓪ REVISION — Build Wave 2 (re-planned 2026-06-04) — AUTHORITATIVE DELTA

> **This block OVERRIDES the older §②/③/⑥/⑧/⑩/⑪ wherever they conflict.** Sessions 1–3 (§⑬) built the screen on the original "inline donation + EventTicketType + EventSuggestedAmount" design; that design is now superseded. Build agents: treat §⓪ as the source of truth for the storage model, FK targets, cards, and contract. Where §⓪ is silent, the older sections still apply.
>
> **Scope of this wave**: FULL (BE + FE). User-approved decisions (this session) are listed verbatim below. **User runs all EF migrations manually** ([[feedback-user-creates-migrations]]) — make only compiling entity/config/code changes.

### ⓪.1 Entities in play (use ONLY these)

- **`app.EventRegistrationPage`** (1:1 with Event) — the page-config table. ALL new config columns land here. Event stays clean (identity/schedule/venue/content only).
- **`app.EventTicket`** (#46/#137) — ticket source (read-only display in this editor; ticket CRUD lives on the Event Ticketing screen).
- **`app.EventSpeaker`** (existing) — Name / TitleRole / ShortBio / PhotoUrl / SortOrder, FK→Event.
- **`app.EventGalleryPhoto`** (existing) — PhotoUrl / Caption / SortOrder, FK→Event.
- **DROPPED concepts — do NOT use**: `EventTicketType`, `EventSuggestedAmount`, the legacy "Event settings" inline columns.

### ⓪.2 Storage delta on `app.EventRegistrationPage`

**ADD columns** (mirror `fund.OnlineDonationPage` #10 patterns):

| Column | Type | EF mapping (mirror ODP) | Purpose |
|---|---|---|---|
| `CompanyPaymentGatewayId` | `int?` (nullable — free events skip it) | `HasOne(CompanyPaymentGateway).WithMany().HasForeignKey().OnDelete(Restrict)` | Paid-ticket charging gateway. FK → `fund.CompanyPaymentGateways` (#167). |
| `EnabledPaymentMethodsJson` | `string?` | `.HasColumnType("jsonb")` (nullable; required only when paid tickets exist) | jsonb array of `PAYMENTMETHOD` MasterData DataValue codes. Round-trip via System.Text.Json in handler (mirror ODP `EnabledPaymentMethodsJson`). |
| `PageTemplateId` | `int?` | `HasOne(PageTemplate).WithMany().HasForeignKey().OnDelete(Restrict)` — use plain `.WithMany()` (do NOT add an inverse collection to MasterData) | FK → `sett.MasterDatas` TypeCode=`EVENTREGPAGETEMPLATE`. Drives public template variant. Nullable → renderer falls back to STANDARD. **REPLACES `RegistrationPageLayout`** (drop that string column + migrate any value). |
| `EnableDonation` | `bool?` | default false | Show/hide the Donate button on the public page + every template. |
| `OnlineDonationPageId` | `int?` | `HasOne(OnlineDonationPage).WithMany().HasForeignKey().OnDelete(Restrict)` | FK → `fund.OnlineDonationPages` (#10). The Donate button URL = the selected ODP's public URL `/p/{slug}`. |
| `EnableAttendance` | `bool?` | default false | **Coming Soon** umbrella feature (attendance tracking / check-in). **SUPERSEDES `QrCheckinEnabled`** — drop QrCheckinEnabled. |
| `EnableVolunteerService` | `bool?` | default false | **Coming Soon** — let registrants opt into volunteering. NEW. |
| `EnableFeedbackCollection` | `bool?` | default false | **Coming Soon** — post-event feedback survey. **SUPERSEDES `PostEventSurveyEnabled`** — drop PostEventSurveyEnabled. |

**DROP columns** (migration; remove from entity + EF config + DTOs + FE):
- `AcceptDonations`, `LinkedDonationPurposeId`, `ShowFundraisingGoal`, `GoalAmount` (old inline-donation model — replaced by `EnableDonation` + `OnlineDonationPageId`).
- `RegistrationPageLayout` (replaced by `PageTemplateId`).
- `QrCheckinEnabled` (superseded by `EnableAttendance`), `PostEventSurveyEnabled` (superseded by `EnableFeedbackCollection`).
- **KEEP**: `ShowCountdown` stays a LIVE toggle (registrant-experience). The `LinkedDonationPurpose` nav + `EnableMultiCurrency` etc. are NOT on this table — ignore.

**Overlap reconciliation rationale (locked)**: QR check-in and post-event survey were partial/placeholder V1 toggles. Folding them into the broader Coming-Soon `EnableAttendance` / `EnableFeedbackCollection` flags avoids two columns meaning the same thing. The future Attendance feature will own QR check-in as an implementation detail.

### ⓪.3 New MasterData type — `EVENTREGPAGETEMPLATE`

Seed a new `sett.MasterDataTypes` row TypeCode=`EVENTREGPAGETEMPLATE` + `sett.MasterDatas` DataValues (UPPERCASE, mirror `ONLINEDONATIONPAGETYPE`): `STANDARD` / `IMAGE_FOCUS` / `VIDEO_FOCUS` / `MINIMAL` (+ optional `CAROUSEL_FOCUS`). Idempotent PostgreSQL seed (`WHERE NOT EXISTS`, `now()`, double-quoted identifiers) in the existing `sql-scripts-dyanmic/EventRegistrationPage-table-backfill.sql` (or a sibling). Mirror the ODP page-type seed block exactly — **grep the ODP seed for the canonical INSERT shape; do not guess column names** ([[feedback-masterdata-lookup-mirror-sibling]]). Backfill existing rows: set `PageTemplateId` from the old `RegistrationPageLayout` string (`centered`→STANDARD, etc.) before dropping the column.

### ⓪.4 FK Resolution additions (verified this session)

| FK | Target entity | Path | Reuse query for the dropdown |
|---|---|---|---|
| `CompanyPaymentGatewayId` | `CompanyPaymentGateway` (#167) | `fund.CompanyPaymentGateways` | `GetAllPaymentGatewayList` → `GetAllPaymentGatewayListQuery()` (returns `List<PaymentGatewayResponseDto>`), at `Base.API/EndPoints/Shared/Queries/PaymentGatewayQueries.cs`. Verify the DTO id/label fields against the file before wiring. |
| `OnlineDonationPageId` | `OnlineDonationPage` (#10) | `fund.OnlineDonationPages` | `GetAllOnlineDonationPagesList` → `GetAllOnlineDonationPagesListQuery(request, statuses, implementationTypes)` at `Base.API/EndPoints/Donation/Queries/OnlineDonationPageQueries.cs`. **Pass `statuses = ["Active","Published"]`** so only live pages appear. Donate-button URL derives from the chosen page's `Slug` + `ImplementationType` (NAV → `/p/{slug}`). |
| `PageTemplateId` | `MasterData` (TypeCode=`EVENTREGPAGETEMPLATE`) | `sett.MasterDatas` | Standard MasterData-by-type lookup — mirror an existing sibling handler (do NOT guess DataValue strings; [[feedback-masterdata-lookup-mirror-sibling]]). |

### ⓪.5 Editor cards delta (the new card set)

Rework the §⑥ "8 settings cards" into this set (autosave 300ms + live preview unchanged):

| # | Card | Change | Detail |
|---|---|---|---|
| 1 | Page Identity | **CHANGED** | Slug + URL preview unchanged. **Add the Page-Template selector** (visual card chooser like ODP page-type: STANDARD/IMAGE_FOCUS/VIDEO_FOCUS/MINIMAL) → `PageTemplateId`. Remove the old `RegistrationPageLayout` select from card 8. |
| 2 | Event Snapshot (read-only) | unchanged | Links to #40 Event form. |
| 3 | Ticket Types | **CHANGED** | Read-only display sourced from **`EventTicket`** (not EventTicketType) via existing `getAllEventTicketTypeList`/EventTicket list query — "Manage tickets →" links to the Event Ticketing screen. No inline CRUD. |
| 4 | Registration Window | unchanged | |
| 5 | Registrant Experience | **CHANGED** | (a) Form Fields table (FirstName/Email locked) + Custom Questions — unchanged. (b) `ShowCountdown` LIVE toggle. (c) **Remove** QrCheckin / Post-event-survey toggles (moved to the Coming-Soon card). |
| 6 | Donation | **REPLACED** | Drop AcceptDonations / LinkedDonationPurpose / SuggestedAmounts / ShowFundraisingGoal / GoalAmount. New: **`EnableDonation` toggle** + **OnlineDonationPage dropdown** (Active/Published only) + live preview of the resulting Donate-button URL (`/p/{slug}`). Button hidden on public page when `EnableDonation=false`. |
| 7 | Communications | unchanged | |
| 8 | Branding & SEO | **CHANGED** | Banner + colors + button text + Share*/robots unchanged. **Remove** the RegistrationPageLayout select (now the template selector in card 1). |
| 9 | **Payment Gateway** | **NEW** | Mirror ODP payment card. `CompanyPaymentGatewayId` dropdown (`GetAllPaymentGatewayList`) + `EnabledPaymentMethodsJson` multi-select of PAYMENTMETHOD codes. Show only relevant when paid tickets exist; otherwise an info note "Free event — no gateway needed." |
| 10 | **Speakers** | **NEW** | CRUD card over `EventSpeaker` (Name / TitleRole / ShortBio / PhotoUrl upload / SortOrder drag-reorder). Add/edit/delete rows. Shown pre-event on the public page ("Who's presenting"). |
| 11 | **Gallery** | **NEW** | CRUD card over `EventGalleryPhoto` (PhotoUrl upload / Caption / SortOrder drag-reorder). **Pre-event teaser** — promotional / past-event highlight photos, always visible on the reg page. No temporal flag. |
| 12 | **Coming Soon** | **NEW** | Three DISABLED toggles with a "Coming Soon" badge: `EnableAttendance`, `EnableVolunteerService`, `EnableFeedbackCollection`. Columns persist but the toggles are visually disabled (no autosave write while disabled). |

Public page (`/event/{slug}`): render the selected **PageTemplate** variant; add **Speakers** + **Gallery** sections; render the **Donate button** (→ ODP `/p/{slug}`) only when `EnableDonation=true`. Image-upload remains SERVICE_PLACEHOLDER (no upload service wired — same as siblings).

### ⓪.6 BE → FE contract delta

- `EventRegistrationPageSetupDto`: drop `acceptDonations`/`linkedDonationPurposeId`/`showFundraisingGoal`/`goalAmount`/`registrationPageLayout`/`qrCheckinEnabled`/`postEventSurveyEnabled`/`suggestedAmounts`; add `companyPaymentGatewayId`, `enabledPaymentMethods` (string[] — deserialized from jsonb), `pageTemplateId` + `pageTemplateCode` (derived, read-only), `enableDonation`, `onlineDonationPageId` + `onlineDonationPageSlug` + `onlineDonationPageUrl` (derived for button preview), `enableAttendance`, `enableVolunteerService`, `enableFeedbackCollection`.
- `EventRegistrationPageSetupInput`: same add/drop on the write side (jsonb sent as `enabledPaymentMethods: [String!]` — declare list nullability to match BE per [[feedback-fe-query-nullability-must-match-be]]).
- Public DTO: add `speakers` + `galleryPhotos` (already projected) + `pageTemplateCode` + `enableDonation` + `donateButtonUrl`; drop the old donation fields.
- Speakers/Gallery CRUD need mutations (Add/Update/Delete/Reorder) on `EventSpeaker` + `EventGalleryPhoto` if not already present — grep first; reuse existing Event child-entity handlers if they exist.

### ⓪.7 File-manifest delta (additions over §⑧)

- **BE**: `EventRegistrationPage.cs` (+8 props, −7 props), `EventRegistrationPageConfiguration.cs` (new FKs + jsonb + drop index/cols), `EventRegistrationPageSchemas.cs` (DTO add/drop), `GetEventRegistrationPageById.cs` + `…BySlug` (project new fields + ODP-url derivation), `UpdateEventRegistrationPageSetup.cs` (handle new fields + jsonb round-trip), speaker/gallery CRUD handlers + endpoints (if missing), seed SQL (EVENTREGPAGETEMPLATE master data + backfill). **No migration file authored by agent** — user runs it.
- **FE**: `EventRegistrationPageDto.ts` (contract delta), the two GQL query files + mutation file (new fields + speaker/gallery mutations), cards 1/3/5/6/8 edits + new cards 9/10/11/12, `live-preview.tsx` (template variants + speakers/gallery/donate-button), public `event-page.tsx` + section components (speakers, gallery, donate-button).

### ⓪.8 Acceptance criteria delta

- Payment Gateway card shows the tenant's configured gateways; saving persists `CompanyPaymentGatewayId` + `EnabledPaymentMethodsJson`.
- Page-Template selector persists `PageTemplateId`; public page renders the chosen variant; null → STANDARD.
- Donation card: toggling `EnableDonation` + picking an Active/Published ODP persists; public page shows a Donate button linking to `/p/{odp-slug}`; button hidden when `EnableDonation=false`; dropdown lists ONLY Active/Published ODPs.
- Speakers/Gallery: add/edit/delete/reorder rows; public page renders Speakers ("who's presenting") + Gallery (pre-event teaser).
- Coming-Soon trio renders as disabled toggles with a badge; columns exist; no write while disabled.
- Old inline-donation UI + RegistrationPageLayout select + QrCheckin/Post-survey toggles are GONE.

---

## ⓪′ REVISION — Build Wave 3 (re-planned 2026-06-08) — Event Email Communication Subsystem — AUTHORITATIVE DELTA

> **This block is ADDITIVE — it does NOT supersede Wave-2 §⓪.** Wave 2 (Sessions 4–22) is built and live. Wave 3 adds an **email-communication subsystem** on top: three email flows orchestrated by Hangfire. Build agents treat §⓪′ as the source of truth for everything email/job-related; where §⓪′ is silent, §⓪ (Wave 2) then the older sections apply.
>
> **Scope of this wave**: FULL (BE-heavy + small FE: one new page field, a Communications-card rework, and a "Resend announcement" admin button). **User runs the EF migration manually** ([[feedback-user-creates-migrations]]) — agent makes only compiling entity/config/code changes, NO migration file, NO `dotnet ef` runs ([[feedback-user-creates-migrations]]).
>
> **All architecture decisions below were locked with the user (2026-06-08) — do NOT re-litigate.** Full decision record: memory `project_event_email_comms_design`.

### ⓪′.1 The three email flows (authoritative)

| # | Flow | Audience | When | Mechanism | Dedup guard |
|---|------|----------|------|-----------|-------------|
| **1** | **Donor announcement** | All **donors** (Contacts) | On **page Publish** | Fire-and-forget `Enqueue` → BULK via `EmailSendJob`/`IEmailExecutorService` pipeline | `AnnouncementSentAt` (only fire+stamp if null; admin "Resend" button is the sole override) |
| **2a** | **Payment-success email** | The **registrant** | On paid registration **confirm** | Fire-and-forget `Enqueue` from `ConfirmEventRegistration` → transactional `SendEmailByTemplateKeyAsync` | natural (one confirm = one send) |
| **2b** | **Tickets email** (HTML summary, no PDF yet) | The **registrant** | Paid → on confirm; **Free → on initiate** (immediately Confirmed) | same fire-and-forget job (sends both for paid; tickets-only for free) | natural |
| **2c** | **Reminder** *(optional, reuses existing SendReminder/ReminderTimingCode)* | Confirmed registrants | StartDate − offset(`ReminderTimingCode`) reached | the **daily dispatcher** sweep | `ReminderSentAt` |
| **3** | **Post-event feedback** | Confirmed registrants | After `Event.EndDate` passes (+`EnableFeedbackCollection`) | the **daily dispatcher** sweep | `FeedbackSentAt` |

**Flow-2 send matrix (exact):**
- **Free ticket** (`InitiateEventRegistration`, `targetStatusName == "Confirmed"`): send **TICKETS** only (no payment occurred). The tickets email doubles as the registration confirmation.
- **Paid ticket** (`InitiateEventRegistration`, `PendingPayment`): send **nothing** here — wait for confirm.
- **Paid confirmed** (`ConfirmEventRegistration`, status → Confirmed): send **PAYMENT_SUCCESS + TICKETS** (two separate emails).

**v1 tickets email = HTML summary** (event name / date / venue / ticket-type / quantity / registration code). **NO PDF/QR attachment** — no per-registration ticket artifact exists yet (QR generation disabled; PDF deferred, tied to #137 EventTicketing). `SendGridProvider` already supports `byte[]` attachments via `EmailAttachment` for when the artifact is built — see NEW-ISSUE-28.

### ⓪′.2 Storage delta on `app.EventRegistrationPage` (4 new columns)

Entity `Base.Domain/Models/ApplicationModels/EventRegistrationPage.cs` (`[Table("EventRegistrationPages", Schema = "app")]`); config `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventRegistrationPageConfiguration.cs`. Append after `EnableFeedbackCollection`:

| Column | Type | EF mapping | Purpose |
|---|---|---|---|
| `AnnouncementSentAt` | `DateTime?` | plain (EF infers `timestamptz`; mirror `PagePublishedAt` — no `HasColumnType`) | Flow-1 dedup marker. Publish stamps it once; republish skips. |
| `ReminderSentAt` | `DateTime?` | plain | Flow-2c dedup marker (page-level — see tradeoff note). |
| `FeedbackSentAt` | `DateTime?` | plain | Flow-3 dedup marker (page-level). |
| `FeedbackUrl` | `string?` | `.HasMaxLength(1000)` (mirror `ShareImageUrl`) | External survey link (Google Form / Typeform). Flow-3 email links here. Native feedback form is DEFERRED (NEW-ISSUE-29). |

**Page-level marker tradeoff (LOCKED, NEW-ISSUE-30)**: `ReminderSentAt`/`FeedbackSentAt` are per-PAGE, not per-registration. Acceptable because feedback fires post-event (no new registrants arrive) and reminders fire at a single window. A registrant who registers *after* the marker is stamped won't get that reminder. A per-registration marker would be more precise but heavier — chosen page-level for v1.

> **2nd migration target**: Wave 3 also adds **`notify.EmailSendJobs.IsSystem`** (`bool`, default `false`) for job tracking/visibility — see **⓪′.8b**. So the user-owned Wave-3 migration touches TWO tables: 4 cols on `app.EventRegistrationPages` + 1 col on `notify.EmailSendJobs`.

### ⓪′.3 New `EmailTemplate` seed rows (4 codes) — DB seed

Seed 4 rows into `notify."EmailTemplates"` (idempotent `WHERE NOT EXISTS`, `now()`, double-quoted identifiers — [[project_postgresql_db]]). **Mirror the existing `USER_WELCOME_INVITE` INSERT in `sql-scripts-dyanmic/UserManagement-sqlscripts.sql`** for the exact NOT-NULL column set; do NOT guess columns ([[feedback_masterdata_lookup_mirror_sibling]]).

| `EmailTemplateCode` | Subject (with `#KEY#` placeholders) | Body placeholders |
|---|---|---|
| `EVENT_ANNOUNCEMENT` | `You're invited: #EVENT_NAME#` | `#DONOR_NAME# #EVENT_NAME# #EVENT_DATE# #VENUE# #REGISTER_URL#` |
| `REGISTRATION_PAYMENT_SUCCESS` | `Payment received for #EVENT_NAME#` | `#REGISTRANT_NAME# #EVENT_NAME# #AMOUNT# #REGISTRATION_CODE#` |
| `REGISTRATION_TICKETS` | `Your tickets for #EVENT_NAME#` | `#REGISTRANT_NAME# #EVENT_NAME# #EVENT_DATE# #VENUE# #TICKET_TYPE# #QUANTITY# #REGISTRATION_CODE#` |
| `POST_EVENT_FEEDBACK` | `How was #EVENT_NAME#? Share your feedback` | `#REGISTRANT_NAME# #EVENT_NAME# #FEEDBACK_URL#` |

**Seed rules (verified this session):**
- **Placeholder syntax is `#KEY#`** (the `ReplacePlaceholders` regex only matches `#…#`). Do **NOT** use `{{…}}` even though one legacy seed row contains it — that row is a latent bug and won't substitute.
- `ModuleId` → `(SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'CRM')` (events belong to **CRM** module).
- `EmailCategoryId` → resolve via subquery to the EMAIL-category MasterData used by the reference seed (grep `UserManagement-sqlscripts.sql` for the exact category id/value — do NOT hardcode the literal `172`, it's environment-specific).
- `CompanyId` NOT NULL: send-time lookup is **`EmailTemplateCode` + `ModuleId` + `IsActive` ONLY — NOT tenant-scoped**, so a single global row per code (mirror the reference seed's `CompanyId`) serves all tenants. Per-tenant template overrides are a future follow-up.
- `CreatedBy=2`, `CreatedDate=now()`, `IsActive=true`, `IsDeleted=false`.

**Also seed in the same file:** 1 new `SendJobType` MasterData value **`TRIGGERED`** (for the auto-fired system job rows — see ⓪′.8b). Mirror the existing `SENDNOW`/`SCHEDULED`/`RECURRING` rows of that MasterData type — grep their seed for the exact TypeCode/DataValue; do NOT guess.

### ⓪′.4 The two Hangfire mechanisms (exact patterns — verified this session)

**Mechanism A — fire-on-action `Enqueue` (Flows 1, 2a/2b).** Use **injected `IBackgroundJobClient`** (NOT static `BackgroundJob`) — canonical: `CreateEmailSendJobHandler`, `OnlineDonationMapJobDispatcher`.

**Mechanism B — ONE daily `RecurringJob` "Event Communication Dispatcher" (Flows 2c, 3 + announcement safety-net).** **NEVER register a recurring job per event.** Model verbatim on `PayURecurringChargeService` + `PayURecurringChargeRegistrationExtension` + its `Program.cs` wiring:

- **Service** `Base.Application/Services/EventCommunications/EventCommunicationDispatcher.cs` (+ `IEventCommunicationDispatcher`). Primary ctor `(IApplicationDbContext dbContext, IHttpContextAccessor httpContextAccessor, IEventCommunicationEmailService emailService, ILogger<…> logger)`. Method `[AutomaticRetry(Attempts = 0)] Task ProcessDueEventCommunicationsAsync(CancellationToken ct)`.
- **Cross-tenant scan with NULL principal first** (HttpContext null ⇒ global tenant filter OFF ⇒ query sees ALL companies — intentional), then **per-page `EstablishJobPrincipal(page.CompanyId, systemUserId)` BEFORE the send + marker stamp** so SaveChanges/audit see the right tenant. Copy `EstablishJobPrincipal` **verbatim** from `PayURecurringChargeService` (claims: `ClaimTypes.Name="System"`, `UserId`, `CurrentCompanyId`, `IsSuperAdmin="false"`, `CurrentCompanyRoles="[]"`, `AccessibleCompanyIds=JsonSerializer.Serialize(new[]{companyId})`; `new ClaimsIdentity(claims,"HangfireJob")`; `httpContextAccessor.HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(identity) }`).
- **Scan logic** (each guarded by its marker):
  - *Feedback-due*: pages where `EnableFeedbackCollection==true && FeedbackUrl != null && FeedbackSentAt == null` AND `Event.EndDate < nowUtc` → for each **Confirmed** `EventRegistration` of the event, send `POST_EVENT_FEEDBACK` → stamp `FeedbackSentAt`.
  - *Reminder-due*: pages where `SendReminder==true && ReminderSentAt == null` AND now ≥ `Event.StartDate − offset(ReminderTimingCode)` AND now < `Event.StartDate` → for each Confirmed registration send the reminder → stamp `ReminderSentAt`. (`ReminderTimingCode` already exists; map code→TimeSpan, e.g. `1DAY`/`1WEEK`/`1HOUR`.)
  - *Announcement safety-net*: pages Published/Active with `AnnouncementSentAt == null` → re-run Flow-1 + stamp (covers a failed publish-time enqueue).
- **Registration extension** `Base.API/Extensions/EventCommunicationDispatcherRegistrationExtension.cs` — `recurringJobManager.AddOrUpdate<IEventCommunicationDispatcher>("event-communication-dispatcher", svc => svc.ProcessDueEventCommunicationsAsync(CancellationToken.None), "0 3 * * *", new RecurringJobOptions { TimeZone = TimeZoneInfo.Utc })`. **Wire the call in `Program.cs`** right beside the existing `app.Services.RegisterPayURecurringChargeJob();` (line ~70). **DI**: `services.AddScoped<IEventCommunicationDispatcher, EventCommunicationDispatcher>();` in `Base.Application/DependencyInjection.cs` (beside the PayU registration, line ~58).

### ⓪′.5 The shared email service + the three hook-site edits

**NEW service** `Base.Application/Services/EventCommunications/EventCommunicationEmailService.cs` (+ `IEventCommunicationEmailService`, `AddScoped` in `Base.Application/DependencyInjection.cs`). It does the actual render+send and is invokable BOTH inline-from-handler AND as a Hangfire job target. Inject `IEmailTemplateService` (`Base.Application.Data.Services`, registered `Base.Infrastructure/DependencyInjection.cs:67`), `IApplicationDbContext`, `IHttpContextAccessor`, `ILogger`. Methods:
- `Task SendDonorAnnouncementAsync(int eventRegistrationPageId, CancellationToken ct)` — Flow 1 (see ⓪′.6 for recipient resolution + bulk-vs-loop decision).
- `Task SendRegistrationEmailsAsync(int eventRegistrationId, bool includePaymentSuccess, CancellationToken ct)` — Flow 2. Loads registration + page + event + ticket; **establishes the synthetic principal from `registration.CompanyId` first** (jobs run without HTTP context — copy `EstablishJobPrincipal`); checks the `EventCommunicationTrigger` policy (⓪′.7); renders `#KEY#` placeholders; calls `SendEmailByTemplateKeyAsync(emailDto, placeholders, code, crmModuleId)` — once for `REGISTRATION_TICKETS`, and additionally for `REGISTRATION_PAYMENT_SUCCESS` when `includePaymentSuccess`.

**Transactional send signature (verbatim):** `Task<bool> SendEmailByTemplateKeyAsync(EmailDto emailDto, Dictionary<string,string> placeholderValues, string emailTemplateKey, Guid ModuleId, bool skipOnMissingPlaceholders = true)`. `EmailDto { string ToEmail; string? FromEmail; string? EmailContent; string? AttachmentPath; string? AttachmentContentType; }` (`ToEmail` is the only required field — leave the rest null; subject/body come from the DB template). Resolve `ModuleId` once via `dbContext.Modules.First(m => m.ModuleCode == "CRM").ModuleId`. **Do NOT** use the standalone `EmailSendQueue` `EmailSendJobId=0` insert (the prayer-request pattern) — **it has no drainer and never sends** (NEW-ISSUE-31).

**Hook-site edits (exact anchors verified this session):**

| Hook | File | Anchor | Edit |
|---|---|---|---|
| **Flow 1** | `EventRegistrationPages/Commands/PublishEventRegistrationPage.cs` | after `page.PagePublishedAt ??= nowUtc; page.PublicEventPage = true;` (≈ lines 91–101), before `SaveChangesAsync` | add `IBackgroundJobClient` to the handler's primary ctor; `if (page.AnnouncementSentAt == null) { page.AnnouncementSentAt = nowUtc; backgroundJobClient.Enqueue<IEventCommunicationEmailService>(s => s.SendDonorAnnouncementAsync(page.EventRegistrationPageId, CancellationToken.None)); }` |
| **Flow 2 (paid)** | `EventRegistrationPages/PublicMutations/ConfirmEventRegistration.cs` | the `[SERVICE_PLACEHOLDER] confirmation email` block (≈ lines 165–171). In scope: `registrationCode`, `rows` (List<EventRegistration>, `rows.First().EventRegistrationId/RegistrantEmail/EventId`), `pageEvent` | replace the `LogInformation` with: add `IBackgroundJobClient`; `backgroundJobClient.Enqueue<IEventCommunicationEmailService>(s => s.SendRegistrationEmailsAsync(rows.First().EventRegistrationId, /*includePaymentSuccess*/ true, CancellationToken.None));` |
| **Flow 2 (free)** | `EventRegistrationPages/PublicMutations/InitiateEventRegistration.cs` | the `[SERVICE_PLACEHOLDER] Confirmation email` block (≈ lines 378–389), inside the `strategy.ExecuteAsync` after `tx.CommitAsync`. In scope: `registration`, `regPage`, `req.Email`, `registrationCode`, `targetStatusName`, `totalAmount` | replace the `LogInformation` with: add `IBackgroundJobClient`; `if (targetStatusName == "Confirmed") backgroundJobClient.Enqueue<IEventCommunicationEmailService>(s => s.SendRegistrationEmailsAsync(registration.EventRegistrationId, /*includePaymentSuccess*/ false, CancellationToken.None));` (free → tickets only). Leave the reminder placeholder removed — reminders are now the dispatcher's job. |

### ⓪′.6 `EventCommunicationTrigger` → live policy layer + Flow-1 recipients

**`EventCommunicationTrigger` is DEAD CONFIG today** (entity at `Base.Domain/Models/ApplicationModels/EventCommunicationTrigger.cs`: `TriggerCode`(≤30), `ChannelEmail/ChannelWhatsApp/ChannelSms`, `TimingCode`(≤30), `TemplateId?`, `EventId`, `CompanyId?`, nav `Template`; upserted only via `UpdateEvent.cs` `UpsertCommunicationTriggers` line ≈439; **no runtime consumer**). Wave 3 makes it the **live policy gate**: before each send, the email service looks up the event's trigger row by `TriggerCode` (`EVENT_ANNOUNCEMENT` / `REGISTRATION_PAYMENT_SUCCESS` / `REGISTRATION_TICKETS` / `POST_EVENT_FEEDBACK`); if a row exists and `ChannelEmail == false`, **skip** that send (admin opted out). **Absence of a row ⇒ default ON** (so existing events keep working). Channels other than email (WhatsApp/SMS) stay SERVICE_PLACEHOLDER. The admin **Communications card** (§⑥ card 7) is extended to manage one toggle row per trigger code.

**Flow-1 donor recipients.** Donor = Contact (`corg."Contacts"`) with ContactType `DONOR` **OR** ≥1 `fund.GlobalDonation`; primary email via `corg."ContactEmailAddresses"."Email"` where `IsPrimary` ([[reference_contacts_schema_corg]]); **honor `Contact.DoNotEmail == false`**.
- **PRIMARY path (preferred — reuses tracking + opt-out + parallelism):** build/seed a reusable **"Event Donors" `Segment`/`SavedFilter`**, then create an `EmailSendJob` (SENDNOW, template `EVENT_ANNOUNCEMENT`, that segment) and `backgroundJobClient.Enqueue<IEmailExecutorService>(x => x.ProcessBulkEmailJobAsync(jobId, CancellationToken.None))` — mirror `CreateEmailSendJobHandler`. **Resolver task**: grep an existing `Segment` seed + `BulkEmailDataFetcher` to learn the `RulesJson` shape before committing.
- **FALLBACK (if dynamic segment composition proves heavy):** the announcement service queries donor recipients directly and loops `SendEmailByTemplateKeyAsync(EVENT_ANNOUNCEMENT)` per donor (skipping `DoNotEmail`). Self-contained; loses campaign analytics only. **NEW-ISSUE-32** tracks the choice — Solution Resolver picks one and records it.

### ⓪′.7 BE → FE contract delta (small)

- `EventRegistrationPageSetupDto` + `…Input`: add `feedbackUrl` (string). The 3 `…SentAt` markers are **server-owned** — expose `announcementSentAt` read-only on the DTO (drives the Resend-button state), do NOT accept them on input.
- **Card 7 (Communications)**: extend to manage per-trigger email toggles (4 rows: announcement / payment-success / tickets / feedback) + the **`FeedbackUrl`** text field (shown when `EnableFeedbackCollection` is on; note it's the Coming-Soon flag from Wave 2 — for Wave 3 the feedback *email* is live even though the native form is deferred). 
- **Card 1 (Page Identity)** OR a header action: add a **"Resend announcement"** button → calls a new lightweight mutation `ResendEventAnnouncement(eventRegistrationPageId)` that clears+re-stamps `AnnouncementSentAt` and re-enqueues Flow 1 (the ONLY way to re-send). Disable the button when `announcementSentAt == null` (never published) — show "Sent {date}" otherwise.
- FE nullability: any new list var must match BE list nullability ([[feedback_fe_query_nullability_must_match_be]]); strip `__typename` on round-trip ([[feedback_apollo_typename_strip_on_round_trip]]).

### ⓪′.8 File-manifest delta (additions over §⑧ / §⓪.7)

- **BE NEW**: `Services/EventCommunications/IEventCommunicationEmailService.cs` + `EventCommunicationEmailService.cs`; `Services/EventCommunications/IEventCommunicationDispatcher.cs` + `EventCommunicationDispatcher.cs`; `Base.API/Extensions/EventCommunicationDispatcherRegistrationExtension.cs`; `ResendEventAnnouncement` command + endpoint; seed `sql-scripts-dyanmic/EventRegistrationPage-email-templates.sql` (4 EmailTemplate rows + optional Event-Donors segment).
- **BE MODIFY**: `EventRegistrationPage.cs` (+4 props), `EventRegistrationPageConfiguration.cs` (FeedbackUrl maxlength), `EventRegistrationPageSchemas.cs` (feedbackUrl + announcementSentAt), `PublishEventRegistrationPage.cs` (Flow-1 hook), `ConfirmEventRegistration.cs` + `InitiateEventRegistration.cs` (Flow-2 hooks), `UpdateEventRegistrationPageSetup.cs` (persist FeedbackUrl + trigger toggles), `GetEventRegistrationPageById.cs` (project feedbackUrl + announcementSentAt), `Program.cs` (register dispatcher cron), `Base.Application/DependencyInjection.cs` (3 AddScoped). **Job-tracking (⓪′.8b)**: `NotifyModels/EmailSendJob.cs` (+`IsSystem` prop) + its EF config (+ unique index on `JobCode` if absent); the email service + dispatcher **get-or-create rolling parent `EmailSendJob` rows by deterministic `JobCode`** (`SendJobTypeId=TRIGGERED`, `IsSystem=true`) and add child `EmailSendQueue` rows per recipient; Flow-1 sets `IsSystem=true`+`SENDNOW` on its existing job. **No migration file** — user runs it (touches 2 tables: `app.EventRegistrationPages` +4 cols, `notify.EmailSendJobs` +`IsSystem` [+`JobCode` unique index]).
- **DB SEED (add to ⓪′.3 seed file)**: 1 new `SendJobType` MasterData value **`TRIGGERED`** (mirror the existing `SENDNOW`/`SCHEDULED`/`RECURRING` rows — grep their seed for the exact TypeCode/DataValue shape; do NOT guess).
- **FE MODIFY**: `EventRegistrationPageDto.ts` (feedbackUrl + announcementSentAt), the GQL query + mutation barrels, `cards/7-communications-card.tsx` (trigger toggles + FeedbackUrl + Resend button), wire `ResendEventAnnouncement` mutation. Reuse canonical form fields/grids ([[feedback_reuse_canonical_form_fields]], [[feedback_reuse_existing_grids]]).

### ⓪′.8b Job tracking & visibility — `notify.EmailSendJobs.IsSystem`

**Decision (user, 2026-06-08):** every event-communication send is **tracked as a row in `notify.EmailSendJobs`**, flagged **`IsSystem = true`** for automated/system-originated sends (Flow-1 auto-announcement, Flow-2 transactional, Flow-3 dispatcher) vs **`IsSystem = false`** for an admin **manual "Resend"**. A FUTURE **role-based "Jobs" screen** (NOT built in this wave) will render these — tenant jobs (`IsSystem=false`) + system jobs (`IsSystem=true`) — gated by role. This wave only writes the tracking rows + the flag; no Jobs screen UI.

**Schema add (the 2nd migration target, user-owned):** `notify.EmailSendJobs.IsSystem` (`bool NOT NULL DEFAULT false`) on the `EmailSendJob` entity (`Base.Domain/Models/NotifyModels/EmailSendJob.cs`) + its EF config. Default `false` keeps every existing campaign row a "tenant job."

**How each flow records its tracking row:**
- **Flow 1 (bulk announcement)** — the `EmailSendJob` it *already* creates: just set `IsSystem = true`, `CompanyId = page.CompanyId`. Recipients still flow to `EmailSendQueues` via the existing executor. No extra insert.
- **Flow 2 (transactional, AUTO-fired per registration)** — fired automatically by the system the instant a payment succeeds (`ConfirmEventRegistration`, paid) or a free registration completes (`InitiateEventRegistration`) — **no staff**. The **send stays `SendEmailByTemplateKeyAsync`** (the segment-based executor can't target an arbitrary `RegistrantEmail` who may not be a Contact). **Tracking — do NOT create a parent `EmailSendJob` per registration** (1000 registrations would = 1000 parent rows — WRONG). Instead **get-or-create ONE rolling parent `EmailSendJob` per event + trigger**, identified by a **deterministic `JobCode`** (e.g. `EVT-{eventId}-REGISTRATION_PAYMENT_SUCCESS` / `EVT-{eventId}-REGISTRATION_TICKETS`) so **no new `EventId`/`TriggerCode` columns are needed** on `EmailSendJob` — only the `IsSystem` column. Write each registrant's email as a **child `EmailSendQueue` row** (`Status=Sent`) under that parent. So **1000 paid registrations → 2 parent rows + ~2000 child rows** (same "few parents / many children" shape as Flows 1 & 3, not 1000 parents). Parent fields: `JobCode` = the deterministic code, `JobName` = friendly label, `SendJobTypeId = TRIGGERED` (NEW — see below), `IsSystem=true`, `CompanyId=registration.CompanyId`, status stays **active/open** (NOT force-Completed — registrants keep arriving while registration is open). Implementation: (a) **unique index on `JobCode`** (verify it exists / add it) so the get-or-create is race-safe under concurrent registrations; (b) the future Jobs screen **counts children on read** (`COUNT(EmailSendQueue) WHERE EmailSendJobId = parent`) rather than incrementing a live counter on the shared parent — avoids hot-row write contention.
- **Flow 3 (dispatcher, AUTO-fired nightly)** — per event processed per nightly batch, **get-or-create ONE parent `EmailSendJob`** by the same deterministic `JobCode` scheme (e.g. `EVT-{eventId}-POST_EVENT_FEEDBACK`) stamped with **that event's `CompanyId`** (so it surfaces under the correct tenant as a system job), `SendJobTypeId = TRIGGERED`, `IsSystem=true`, with each Confirmed attendee's email a **child `EmailSendQueue` row**. (One parent per event-batch — already "few parents / many children".) The dispatcher writes these *after* `EstablishJobPrincipal(page.CompanyId)`, so tenant stamping/audit is correct.

> **NEW job type `TRIGGERED` (seed 1 MasterData value).** Add a `TRIGGERED` (a.k.a. system/transactional) value to the existing `SendJobType` MasterData set (mirror the existing `SENDNOW`/`SCHEDULED`/`RECURRING` rows — grep their seed, don't guess the TypeCode/DataValue). It labels **auto-fired system streams** (Flows 2 & 3) so the future role-based Jobs screen can distinguish them from staff-launched campaigns (`SENDNOW`/`SCHEDULED`) and recurring campaigns (`RECURRING`). **Flow 1 announcement stays `SENDNOW`** (it's a discrete immediate bulk campaign run through the real executor); the manual **Resend** is `SENDNOW` + `IsSystem=false`. Safe because **inserting an `EmailSendJob` row never auto-sends** — the executor only runs when explicitly enqueued, which Flows 2/3 never do (they already sent via `SendEmailByTemplateKeyAsync`); the row is a pure label/receipt.

> **Hangfire job volume is fine — do NOT inline the send.** Flow-2's per-payment `BackgroundJob.Enqueue(...)` creates ONE Hangfire job per payment (1000 payments = 1000 Hangfire jobs in the `hangfire` schema). This is correct and idiomatic: Hangfire jobs are **ephemeral** — they run on the worker pool then **auto-expire** (`JobExpirationTimeout`, default ~24h), so they self-clean and never accumulate. Do **NOT** "optimize" by sending the email inline in `ConfirmEventRegistration` — that would block the payment callback on SendGrid latency and lose automatic retries. (Ephemeral Hangfire execution units ≠ the permanent `notify.EmailSendJobs` rows — many of the former is fine; many parent rows of the latter is the thing the rolling parent avoids.)

**Why a tracking-row instead of routing transactional sends through the executor:** `IEmailExecutorService` resolves recipients from a `SavedFilter`/`Segment`/Contact provider; event registrants are arbitrary emails (not always Contacts) → they don't fit that recipient model. A completed tracking row gives the future Jobs screen full visibility while keeping the reliable transactional send. **Secondary option (NEW-ISSUE-35)**: extend the executor with an explicit-recipient provider so the `EmailSendJob` row *is* the send uniformly — Solution Resolver may adopt it if a clean ad-hoc-recipient path (nullable `ContactId` on the queue) exists; otherwise use the tracking-row approach above.

> **⚠️ `SendJobTypeId` GUARD — NEVER `RECURRING` for any of our flows.** Job-type mapping: **Flow 1 = `SENDNOW`** (discrete immediate bulk campaign via the real executor); **Flows 2 & 3 = `TRIGGERED`** (new value — auto-fired system streams, rolling parent per event+trigger); **manual Resend = `SENDNOW` + `IsSystem=false`**. **Never `RECURRING`:** `SendJobTypeId` describes when the *campaign engine* re-sends a campaign to a segment — it is NOT how Flow-3 recurs. Flow-3's recurrence is the hand-registered **`event-communication-dispatcher` cron in the `hangfire` schema** (⓪′.4), which is **NOT** an `EmailSendJob` row. Setting `SendJobTypeId=RECURRING` would make the campaign engine register its OWN duplicate recurring job (`RecurringCronExpression`/`HangfireRecurringJobId`) and re-blast recipients — wrong. `RECURRING` is reserved for user-created recurring campaigns (e.g. a newsletter) — none of our flows. `SendJobTypeId` (when/how fired) and `IsSystem` (who owns) are orthogonal: all auto-fired event rows = `TRIGGERED` (or `SENDNOW` for the announcement) + `IsSystem=true`.

### ⓪′.9 Acceptance criteria delta

- Publishing a page enqueues ONE donor announcement; unpublish+republish does **not** re-send (`AnnouncementSentAt` guard); "Resend announcement" is the only re-trigger.
- A **free** registration → registrant gets the TICKETS email. A **paid** registration, after gateway confirm → registrant gets PAYMENT_SUCCESS **and** TICKETS (two emails). All via `SendEmailByTemplateKeyAsync` (actually delivered, not just logged).
- The daily `event-communication-dispatcher` cron sends post-event feedback (after EndDate, `FeedbackUrl` set) and reminders (at the timing window) to Confirmed registrants exactly once per page (markers); it is cross-tenant with per-page synthetic principal; no per-event cron jobs exist.
- Disabling a trigger's email channel on the Communications card suppresses that flow's send; absence of a trigger row = default ON.
- **Job tracking (⓪′.8b)**: every send is recorded in `notify.EmailSendJobs` — `IsSystem=true` for automated (announcement/transactional/dispatcher), `IsSystem=false` for a manual Resend; each row carries the originating event's `CompanyId`. **1000 paid registrations produce only ~2 parent rows per event (rolling, keyed by deterministic `JobCode`, `SendJobTypeId=TRIGGERED`) + ~2000 child `EmailSendQueue` rows — NOT 1000 parents.** Flow-1 announcement parent = `SENDNOW`. The `TRIGGERED` MasterData value is seeded. (The role-based Jobs *screen* is future work — verify only the rows + flag + rolling-parent behavior.)
- `dotnet build` Base.Application + Base.Infrastructure = 0 errors; `npx tsc --noEmit` = exit 0. (Mail delivery itself requires the user's SendGrid config + API restart + the 2-table migration.)

### ⓪′.10 New ISSUEs opened by this re-plan

- **NEW-ISSUE-28** — Tickets email is an HTML summary; PDF/QR ticket attachment deferred (depends on #137 EventTicketing; `EmailAttachment byte[]` ready).
- **NEW-ISSUE-29** — Native `EventFeedback` form/entity deferred; Flow-3 links to a configurable external `FeedbackUrl`.
- **NEW-ISSUE-30** — `ReminderSentAt`/`FeedbackSentAt` are page-level (not per-registration); late registrants miss that cycle.
- **NEW-ISSUE-31** — Standalone `EmailSendQueue` (`EmailSendJobId=0`, prayer-request pattern) has **no drainer**; transactional mail MUST use `SendEmailByTemplateKeyAsync`. (Pre-existing platform gap; flagged so build agents don't copy the prayer pattern.)
- **NEW-ISSUE-32** — Flow-1 bulk-pipeline vs per-recipient-loop: Solution Resolver picks based on the `Segment.RulesJson` capability and records the choice.
- **NEW-ISSUE-33** — WhatsApp/SMS channels on `EventCommunicationTrigger` remain SERVICE_PLACEHOLDER (providers not wired); only `ChannelEmail` is live.
- **NEW-ISSUE-34** — EmailTemplates are global (lookup ignores `CompanyId`); per-tenant template overrides are a future follow-up.
- **NEW-ISSUE-35** — Job tracking (⓪′.8b): transactional Flows 2/3 write a *completed* `EmailSendJob` tracking row but SEND via `SendEmailByTemplateKeyAsync` (the executor's recipient providers don't fit arbitrary non-Contact registrant emails). Secondary option: extend the executor with an explicit-recipient provider so the `EmailSendJob` row IS the send uniformly — Solution Resolver decides; record the choice in the Session entry.
- **NEW-ISSUE-36** — Future **role-based "Jobs" screen** (tenant jobs `IsSystem=false` + system jobs `IsSystem=true`) is NOT built in this wave — only the `IsSystem` flag + tracking rows are produced. The screen + its role-gating are separate planned work.

---

## ⓪″ REVISION — Build Wave 4 (re-planned 2026-06-11) — Registrant Field-Model Redesign + ContactCode persistence — AUTHORITATIVE DELTA

> **This block is ADDITIVE — it does NOT supersede Waves 2/3 (§⓪, §⓪′).** It resolves **ISSUE-38**: the public registrant form-field model is broken end-to-end so that today only First/Last/Email render and only Name/Email/Phone persist. Build agents treat §⓪″ as the source of truth for everything registrant-form-field related; where silent, §⓪′ then §⓪ then the base sections apply.
>
> **Scope of this wave**: FOCUSED FE+BE (1 seed rewrite, 1 GQL-alias fix in 2 queries, 1 entity +10 cols, 1 handler write-block, ~3 FE files, 1 admin-card declutter). **NO new tables, NO custom-answer entity.** **User runs the EF migration manually** ([[feedback_user_creates_migrations]]) — agent makes only compiling entity/config/code changes + a user-run backfill SQL.
>
> **All decisions below were locked with the user (2026-06-11) — do NOT re-litigate.** Canonical pattern mirrored from **ODP OnlineDonationPage #10** (`OnlineDonationStaging.Provided*` columns) per the user's explicit "ODP parity" choice. ContactCode itself was already built in **Session 27** (validator + handler resolution + FE input); Wave 4 completes the field model **around** it and adds the `Provided*` persistence columns.

### ⓪″.1 The four breakages (root cause — verified this session)

| # | Layer | Defect | Fix |
|---|-------|--------|-----|
| **B1** | Seed (`CreateEvent.cs:138-169`) | Only `FULLNAME` + `EMAIL` rows are ever created; the other 7 never exist, so admin Card 5 + the public form have nothing to show. | Seed **all 9 canonical rows** on event create (§⓪″.2) + backfill existing events (§⓪″.6). |
| **B2** | GQL (both queries) | `registrationFormFields { fieldName: fieldLabel }` feeds the FE the human **label** ("Full Name") where every FE consumer matches a stable **code**. Multi-word labels never match → field hidden. | Select **`fieldCode` + `fieldLabel`** (drop the misleading `fieldName: fieldLabel` alias); FE keys logic off `fieldCode`, displays `fieldLabel` (§⓪″.4). |
| **B3** | Canonical codes | FE speaks **PascalCase** (`FirstName`/`LastName`/`Organization`…); DB seeds **UPPERCASE** (`FULLNAME`/`EMAIL`); `FULLNAME` has no FE equivalent at all. | Standardize on **PascalCase 9** (§⓪″.2); `FULLNAME` → split into `FirstName` + `LastName`. |
| **B4** | Persist (`InitiateEventRegistration.cs:352-373`) | Handler writes only `RegistrantName/RegistrantEmail/RegistrantPhone`. `Organization/Dietary/Accessibility/Tshirt/Emergency` + `ContactCode` are on the request DTO but **dropped** (no columns). `CustomAnswers[]` likewise dropped. | Add **10 `Provided*` columns** (ODP parity) + populate them in the handler (§⓪″.3, §⓪″.5). Custom answers → **Coming Soon** (§⓪″.7). |

> **What is ALREADY correct (do not touch):** the `InitiateEventRegistrationRequestDto` already carries `ContactCode, FirstName, LastName, Email, Phone, Organization, DietaryRequirements, AccessibilityNeeds, TshirtSize, EmergencyContact, CustomAnswers[]` (Session 27 + base). The public `registrant-fields.tsx` already renders the 9 fields by `FIELD_ORDER` and matches server config **case-insensitively** (`fieldKey.toLowerCase()` vs `fieldName.toLowerCase()`), and `registration-form.tsx` already sends them + `contactCode`. So once B2 feeds the **code** instead of the label, the public form lights up the optional fields with **zero further FE form changes**. The FE work is the DTO/query rename + Card 5 declutter only.

### ⓪″.2 Canonical registrant field set (the 9 — PascalCase `FieldCode`)

Seed these 9 `app.EventRegistrationFormFields` rows on every event create (replace the 2-row `FULLNAME`/`EMAIL` block). `EventRegistrationFormField` columns: `FieldCode, FieldLabel, IsEnabled, IsRequired, IsSystem, SortOrder, CompanyId` (no schema change to this table).

| Sort | `FieldCode` | `FieldLabel` | `IsSystem` | `IsEnabled` (default) | `IsRequired` (default) | Locked in Card 5? |
|------|-------------|--------------|------------|-----------------------|------------------------|-------------------|
| 1 | `FirstName` | First Name | **true** | true | true | **YES** (req+vis disabled-on) |
| 2 | `LastName` | Last Name | **true** | true | true | **YES** |
| 3 | `Email` | Email | **true** | true | true | **YES** |
| 4 | `Phone` | Phone | false | false | false | no (admin toggles) |
| 5 | `Organization` | Organization / Company | false | false | false | no |
| 6 | `DietaryRequirements` | Dietary Requirements | false | false | false | no |
| 7 | `AccessibilityNeeds` | Accessibility Needs | false | false | false | no |
| 8 | `TshirtSize` | T-shirt Size | false | false | false | no |
| 9 | `EmergencyContact` | Emergency Contact | false | false | false | no |

**`IsSystem` = the lock signal (LOCKED, important):** only the 3 identity fields are `IsSystem=true`. The existing GQL alias `isLocked: isSystem` (Session 3) then keeps Card 5's lock logic correct (only First/Last/Email get disabled checkboxes). The 6 optional fields are `IsSystem=false` so the admin can freely toggle Visible/Required. **Do NOT** set `IsSystem=true` on the 6 optional rows — that would lock them and defeat the toggle. ContactCode is **NOT** a form-field row (it's the always-on leading input built in Session 27).

### ⓪″.3 Storage delta on `app.EventRegistrations` (10 new `Provided*` columns — ODP parity)

Entity `Base.Domain/Models/ApplicationModels/EventRegistration.cs`; config `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventRegistrationConfiguration.cs` (verify exact path on build; mirror the sibling config in that folder). Append after `RegistrantPhone`. **Mirror `OnlineDonationStaging.Provided*` exactly** ([[feedback_mirror_sibling_table_fk_columns]] — copy the sibling, don't overthink):

> **⚠ SUPERSEDED by Session 30 (ISSUE-41 fix):** the 4 name/email/phone rows below (`ProvidedFirstName/LastName/Email/Phone`) were **removed** — they duplicated `RegistrantName` (= FirstName + LastName) / `RegistrantEmail` / `RegistrantPhone`. Only **6** columns ship: `ProvidedContactCode`, `ProvidedOrganization`, `ProvidedDietaryRequirements`, `ProvidedAccessibilityNeeds`, `ProvidedTshirtSize`, `ProvidedEmergencyContact`. The handler sets `RegistrantName = $"{FirstName} {LastName}".Trim()`, `RegistrantEmail = Email`, `RegistrantPhone = Phone`.

| Column | Type | EF mapping | Source (`req.*`) |
|--------|------|-----------|------------------|
| `ProvidedContactCode` | `string?` | `.HasMaxLength(50)` | `ContactCode` (the code the registrant typed — NULL when blank) |
| ~~`ProvidedFirstName`~~ | — | removed (S30) | → `RegistrantName` |
| ~~`ProvidedLastName`~~ | — | removed (S30) | → `RegistrantName` |
| ~~`ProvidedEmail`~~ | — | removed (S30) | → `RegistrantEmail` |
| ~~`ProvidedPhone`~~ | — | removed (S30) | → `RegistrantPhone` |
| `ProvidedOrganization` | `string?` | `.HasMaxLength(200)` | `Organization` |
| `ProvidedDietaryRequirements` | `string?` | `.HasMaxLength(500)` | `DietaryRequirements` |
| `ProvidedAccessibilityNeeds` | `string?` | `.HasMaxLength(500)` | `AccessibilityNeeds` |
| `ProvidedTshirtSize` | `string?` | `.HasMaxLength(20)` | `TshirtSize` |
| `ProvidedEmergencyContact` | `string?` | `.HasMaxLength(200)` | `EmergencyContact` |

> **Keep the existing `RegistrantName/RegistrantEmail/RegistrantPhone` columns** — they're the denormalized display used by the admin grid, the Wave-3 emails, and the registration code. `RegistrantName` stays the concatenation `"{FirstName} {LastName}".Trim()`. The `Provided*` columns are the granular capture alongside it (ODP keeps only `Provided*` because it has no `RegistrantName`; events established `RegistrantName` first, so we keep both). **No FK columns** in this delta — these are plain string captures.

### ⓪″.4 GQL alias fix (B2) — both queries + DTO + 2 consumers

- **`infrastructure/gql-queries/public-queries/EventRegistrationPagePublicQuery.ts`** (~line 72-76) and **`infrastructure/gql-queries/application-queries/EventRegistrationPageQuery.ts`** (~line 156-162): change the `registrationFormFields` selection from `fieldName: fieldLabel` to select **both** `fieldCode` and `fieldLabel` (keep `isRequired`, `isVisible: isEnabled`, `isLocked: isSystem`, `sortOrder`). The BE `EventRegistrationFormFieldResponseDto` already exposes `fieldCode` + `fieldLabel` (Session 3) — no BE query change.
- **`domain/entities/application-service/EventRegistrationPageDto.ts`** `ErpRegistrationFormFieldDto` (line 136): replace `fieldName: string` with `fieldCode: string` + `fieldLabel?: string`.
- **`cards/5-registrant-experience-card.tsx`**: `LOCKED_FIELDS.has(f.fieldName)` → `…has(f.fieldCode)`; display `{f.fieldLabel ?? FIELD_DISPLAY[f.fieldCode] ?? f.fieldCode}` (prefer the admin-saved label, fall back to the friendly map). `FIELD_DISPLAY` keys are already PascalCase codes — keep them.
- **`public/eventregpage/components/registrant-fields.tsx`**: the `visibleFieldNames`/`requiredFieldNames` sets are built from `f.fieldName.toLowerCase()` → change to `f.fieldCode.toLowerCase()`. The `RegistrantFieldValues`/`FIELD_ORDER` keys stay camelCase (case-insensitive match already handles `Organization`↔`organization`). **No other registrant-form change** (Session 27 logic stands).
- **`components/live-preview.tsx`** (if it reads `fieldName`): same `fieldName`→`fieldCode` rename. Grep before editing.
- tsc-invisible defect class — verify by **runtime**, not just `tsc` ([[feedback_reuse_canonical_gql_query]]): after the fix, enabling "Organization" in Card 5 must make it appear on the public form.

### ⓪″.5 Handler write-block (B4) — `InitiateEventRegistration.cs`

In the `new EventRegistration { … }` initializer (≈ lines 352-373), **after** `RegistrantPhone = req.Phone,`, add the 10 `Provided*` assignments from `req.*` (the **effective** values — i.e. after the ContactCode override block at lines 149-189 has run, so `ProvidedFirstName/LastName/Email` carry the resolved Contact identity; `ProvidedContactCode = req.ContactCode`). No other handler logic changes; the ContactCode resolution, capacity tx, payment row, and Wave-3 email enqueue all stay as-is.

### ⓪″.6 Existing-event backfill (user-owned — schema migration + data SQL)

Two user-run artifacts (agent writes them; agent does NOT run `dotnet ef` — [[feedback_user_creates_migrations]], [[project_postgresql_db]]):

1. **EF migration** (user-generated): the 10 `Provided*` columns on `app.EventRegistrations` (all nullable — additive, no default backfill needed since historical registrations legitimately have NULL granular fields).
2. **Idempotent backfill SQL** `sql-scripts-dyanmic/EventRegistrationPage-formfields-backfill.sql` (mirror an existing dynamic seed's idempotent `WHERE NOT EXISTS` + `now()` + double-quoted identifiers): for **every existing `app."Events"`**, ensure the 9 canonical `EventRegistrationFormFields` rows exist (insert each missing row by `FieldCode`, mirroring §⓪″.2 defaults + the event's `CompanyId`). Then **soft-disable the legacy `FULLNAME` row** (`UPDATE … SET "IsEnabled"=false, "IsDeleted"=true WHERE "FieldCode"='FULLNAME'`) so it stops rendering — its identity role is now `FirstName`+`LastName`. Leave a legacy `EMAIL` row alone only if no `Email` row exists; otherwise soft-disable the duplicate. **This SQL is required** — without it, already-created events keep their broken 2-row config.

### ⓪″.7 Custom Questions → Coming Soon (user decision 2026-06-11)

The entire **custom-question** sub-feature (admin "+ Add Custom Field" config in Card 5 **and** the dropped `CustomAnswers[]` capture) moves to **Coming Soon** — same treatment QR Check-in / Post-Event Survey already got (Card 12 `12-coming-soon-card.tsx`).

- **`cards/5-registrant-experience-card.tsx`**: remove the "Custom Questions" list + "+ Add Custom Field" editor block (lines ~159-255). Card 5 becomes Form-Fields-table + the Show-Countdown toggle only.
- **`cards/12-coming-soon-card.tsx`**: add a "Custom Registration Questions" row to the Coming-Soon list (disabled/teaser, consistent with the existing QR/Survey rows).
- **No DB change**: keep the `EventCustomQuestion` entity + its GQL (dead config, like `EventCommunicationTrigger` was pre-Wave-3). Do **NOT** create an `EventRegistrationCustomAnswers` table — custom-answer persistence is explicitly deferred.
- The public form already does not collect custom answers, so no public change. `req.CustomAnswers` stays accepted-but-unpersisted (harmless; documented).

### ⓪″.8 Admin surfacing — DEFERRED (NEW-ISSUE-40)

The newly-captured `Provided*` fields are **stored** this wave (the firm requirement) but **not surfaced** in the admin registrations grid/detail — that surface lives in #46 EventTicketing / #137's registration list (a different screen's territory), and adding columns there is out of this screen's scope. Tracked as **NEW-ISSUE-40**. (Decision delegated to agent by the user 2026-06-11; chose store-now / surface-later to respect screen boundaries.)

### ⓪″.9 File-manifest delta (additions over §⑧ / §⓪.7 / §⓪′.8)

- **BE MODIFY**: `Events/Commands/CreateEvent.cs` (replace the 2-row seed helper with the 9-row set — extract a small `private static IEnumerable<EventRegistrationFormField> BuildDefaultFormFields(int companyId)` mirroring §⓪″.2); `EventRegistration.cs` (+10 `Provided*` props); `EventRegistrationConfiguration.cs` (10 `.HasMaxLength` lines); `EventRegistrationPages/PublicMutations/InitiateEventRegistration.cs` (10 `Provided*` assignments in the initializer). **No** EF migration file (user-run).
- **DB (user-run)**: 1 EF migration (10 cols on `app.EventRegistrations`); 1 backfill SQL `sql-scripts-dyanmic/EventRegistrationPage-formfields-backfill.sql` (§⓪″.6).
- **FE MODIFY**: `EventRegistrationPageDto.ts` (`fieldCode`+`fieldLabel`); `public-queries/EventRegistrationPagePublicQuery.ts` + `application-queries/EventRegistrationPageQuery.ts` (alias fix); `cards/5-registrant-experience-card.tsx` (fieldCode rename + Custom-Questions removal); `cards/12-coming-soon-card.tsx` (add teaser row); `public/eventregpage/components/registrant-fields.tsx` (fieldCode match); `components/live-preview.tsx` (fieldCode, if referenced). Reuse canonical form fields/grids ([[feedback_reuse_canonical_form_fields]], [[feedback_reuse_existing_grids]]); strip `__typename` on any round-trip the setup save touches ([[feedback_apollo_typename_strip_on_round_trip]]).

### ⓪″.10 Acceptance criteria delta

- A **new** event create seeds **9** `EventRegistrationFormFields` rows (First/Last/Email enabled+required+system-locked; Phone/Organization/Dietary/Accessibility/Tshirt/Emergency present, disabled by default, toggleable).
- Existing events, after the backfill SQL, also have the 9 rows; the legacy `FULLNAME` row is soft-disabled.
- Admin Card 5 shows all 9 by friendly label, locks only First/Last/Email, lets the admin toggle Visible/Required on the other 6; Custom-Questions config is gone from Card 5 and appears as a Coming-Soon teaser in Card 12.
- Enabling "Organization" (and any optional field) in Card 5 makes it **render on the public form** (B2 fix proven at runtime, not just tsc).
- A public registration persists every supplied field into the matching `app.EventRegistrations.Provided*` column, including `ProvidedContactCode`. ContactCode path stores the **resolved** identity in `ProvidedFirstName/LastName/Email` + the typed code in `ProvidedContactCode` + sets `ContactId` (Session 27 behavior intact).
- `dotnet build` Base.Application + Base.Infrastructure = 0 errors; `npx tsc --noEmit` = exit 0. (Persistence itself requires the user's migration + the backfill SQL + API restart.)

### ⓪″.11 New ISSUEs opened by this re-plan

- **NEW-ISSUE-39** — Custom-question config + `CustomAnswers[]` capture moved to **Coming Soon**; `EventCustomQuestion` stays dead config, no `EventRegistrationCustomAnswers` table built. Revisit when the custom-question sub-feature is scheduled.
- **NEW-ISSUE-40** — Admin surfacing of the new `Provided*` registrant fields (grid/detail/export) is **deferred** — belongs to #46/#137's registration list, not this screen. Data is stored + query-ready.
- **NEW-ISSUE-41** — `RegistrantName` (concat) + `ProvidedFirstName/LastName` are now **dual-stored**; if a future cleanup wants a single source, collapse `RegistrantName` into a computed projection. Low priority (back-compat with Wave-3 emails + grid).

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage for setup AND public page

Screen: EventRegistrationPage
Module: Setting (admin) / Public (anonymous-rendered)
Schema: `app` (existing — Event entity lives here)
Group: `ApplicationModels` (entity location); business folder `Business/ApplicationBusiness/EventRegistrationPages/` (NEW — co-located with existing `Events/` business folder)

**Business**: This is the **public-facing event registration landing page** an NGO publishes to attract anonymous prospective attendees — the conversion-funnel surface that turns interested website visitors into registered event attendees. Where the existing `Event` entity (#23/#40 COMPLETED ALIGN) serves as the **internal event-management surface** (FLOW screen — CRUD on event date / venue / mode / status / agenda + ticket-type definitions + speakers + custom questions), THIS screen is the **public-page setup + public storefront** — a focused 8-card admin editor that lets a BUSINESSADMIN configure the page identity (title, slug, page-lifecycle status), the publicly visible content (banner, story, branding, OG meta), and the registration funnel (which ticket types to expose, which form fields to ask, donation-on-page toggle, communication triggers); plus the SSR-rendered public route at `/event/{slug}` that anonymous visitors hit to learn about the event and register.

The lifecycle is **deliberately orthogonal to the event lifecycle**: `EventStatusId` (existing — Upcoming / Live / Completed / Cancelled / Postponed) governs the EVENT itself; the new `PageStatus` field (Draft / Published / Active / Closed / Archived) governs ONLY the public registration page. An Event that is `Upcoming` may have its page in `Draft` (admin still preparing copy), `Active` (page live, registrations open), or `Closed` (registration cap hit, but event hasn't started). After the event runs, `EventStatusId` flips to `Completed` while `PageStatus` is usually `Closed` (the public page still renders an archive view showing what happened, with Register disabled). This duality is the #1 gotcha for a developer building this screen — see §④ for the full state-cross-product table.

**Lifecycle**: PageStatus Draft → Published → Active → Closed → Archived. Status auto-transitions: Published → Active when RegistrationOpenDate ≤ now AND EventStatusId IN (Upcoming, Live); Active → Closed when `(SUM(EventRegistration.Quantity WHERE StatusId=Confirmed) ≥ Event.Capacity AND NOT WaitlistEnabled)` OR `RegistrationEndDate < now` OR admin "Close Early". Draft renders 404 to public (preview-token grants temporary access). Closed renders the public page with "Registration is closed" banner + Register button disabled. Archived returns 410 Gone.

**What breaks if mis-set**: (1) Slug rename after registrations attached → link rot on shared social posts. (2) OG meta missing → bad share previews → low organic registrations. (3) PageStatus stays Draft after event date passed → public page never opens; admin discovers on event-day. (4) Capacity misconfig (Capacity field on Event vs. SUM of TicketType capacities) → overbooking or under-fill. (5) RegistrationEndDate not enforced on submit → registrations accepted past cutoff. (6) Paid ticket flow without gateway connect → registrants stuck in PendingPayment forever. (7) Free-ticket flow path bypasses gateway but still expects `paymentSessionId` → submit fails for free events. (8) ConfirmationEmailTemplate ID NULL but `SendConfirmationEmail=true` → registrations succeed but registrants receive no confirmation → admin-side support tickets. (9) `QrCheckinEnabled=true` but no QR generation infra → email arrives without QR. (10) Linked donation + paid ticket on same submit → two charges to one card → refund nightmare.

**Related screens**:
- #23 / #40 Event (COMPLETED ALIGN) — internal event-management FLOW (CRUD on event details + tickets + speakers + form fields + custom questions). #169 ADDS the public-page surface; #23/#40 keeps its FLOW pattern unchanged.
- #137 Event Ticketing (PARTIALLY / TBD — verify status at build time) — admin ticketing-management surface (manage `EventTicket` instances + check-in scanning); together #137 and #169 form the registration pipeline: #169 is the funnel (configure + accept submissions), #137 is the operational view (check in / refund / void).
- #144 Event Analytics — KPI/dashboard view across all events; consumes `EventRegistration` rows that this page creates.
- #10 OnlineDonationPage (COMPLETED) — first canonical EXTERNAL_PAGE / DONATION_PAGE; established the `(public)` route group + `GridType=EXTERNAL_PAGE` + SSR pattern.
- #170 P2PCampaignPage (PROMPT_READY) + #171 PrayerRequestPage (COMPLETED) + #172 VolunteerRegistrationPage (PARTIALLY_COMPLETED) + #173 CrowdfundingPage (PARTIALLY_COMPLETED) — sibling EXTERNAL_PAGE screens under SET_PUBLICPAGES.
- #1 GlobalDonation (PARTIALLY_COMPLETED) — when a registrant adds a donation on the page (`AcceptDonations=true`), a `fund.GlobalDonations` row is created in addition to the `EventRegistration` row.

**What's unique about this page's UX vs the canonical Online Donation Page (#10)**:
- The conversion goal is a **registration**, not a donation. Donation is an optional secondary CTA tied to `AcceptDonations`.
- The public form is **ticket-aware** — registrant picks a Ticket Type (Standard / VIP / Student / Corporate Table) BEFORE filling personal details; selected TicketType drives the quantity selector and the on-page Price.
- The form structure is **wider but shallower** than donation (no recurring frequency, no donor-vs-organization toggle, no payment-method picker per submission). Always 1 logical section: Identity + Quantity + per-attendee details (if quantity > 1).
- **No Approval-Mode toggle** — event registrations are always either auto-confirmed (free) or pending-payment (paid). Manual admin approval is a per-registration concern handled in #137 EventTicketing.
- **Capacity / waitlist semantics** are first-class — every public-page render must include current capacity state; submit must check capacity atomically.
- **QR-Code-on-confirm** is the post-success deliverable (vs donation page's "thank you for your gift" message). QR token generation + email is the success-state trigger.

> **Why this section is heavier than other types**: TWO surfaces (admin setup + anonymous public) PLUS a Page-vs-Event status duality PLUS a ticket-quantity-capacity loop PLUS optional donation hand-off PLUS public-route hardening (CSRF / honeypot / rate-limit / CSP) PLUS SSR OG meta PLUS QR token generation on success. A developer that misses the Page-vs-Event status duality will ship a broken state machine. A developer that misses atomic capacity decrement will ship overbookings. Read this whole section before opening §⑥.

---

## ② Storage & Source Model

> **Consumer**: BA Agent → Backend Developer
>
> **Storage Pattern**: `single-page-record` extended via existing child collections (no new child entities introduced by THIS screen).
>
> Each tenant has N rows in `app.Events` — every Event with `PublicEventPage = true` becomes a Page row in this screen's setup list. Page lifecycle fields live ON the Event row itself (column-level, not a separate table). Sub-resources reuse the existing Event children: `EventTicketType`, `EventRegistrationFormField`, `EventCustomQuestion`, `EventSuggestedAmount`, `EventCommunicationTrigger`, `EventGalleryPhoto`, `EventSpeaker`. Public submissions create rows in the existing `app.EventRegistrations` table (linked back via `EventId` — no new FK needed because the link is already in code from #23/#40).
>
> **PREREQUISITE — Entity already defined by #23/#40**: The `Event` entity (~70 properties — see [`Event.cs`](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Event.cs)) is built. THIS screen adds 6 new fields and a unique index. If #23/#40 Event has not been built (status `PARTIAL` or `PROMPT_READY`), this screen's `/build-screen` should fail-fast with a dependency error.

### Modifications to existing `app."Events"` table

**Add 6 new columns** (single migration):

| Field | C# Type | MaxLen | Required | Default | Notes |
|-------|---------|--------|----------|---------|-------|
| PageStatus | string | 20 | YES | `'Draft'` | Draft / Published / Active / Closed / Archived — page-lifecycle, **distinct** from EventStatusId |
| PagePublishedAt | DateTime? | — | NO | NULL | Set on Draft → Published transition |
| PageArchivedAt | DateTime? | — | NO | NULL | Set on Archive |
| Slug | string | 100 | YES | (derived) | URL slug; unique per tenant; lower-kebab; auto-from-EventName on Create-as-page; formalized superset of existing `CustomUrl` |
| PrimaryColorHex | string | 7 | NO | `'#2563eb'` | Public page primary CTA / accent (default event blue) |
| AccentColorHex | string | 7 | NO | `'#1d4ed8'` | Public page secondary accent |
| RegistrationPageLayout | string | 30 | NO | `'centered'` | `centered` \| `side-by-side` \| `full-width` |
| RegistrationPageRobotsIndexable | bool | — | YES | `TRUE` | Renders `<meta name="robots" content="noindex">` when FALSE |

> 8 columns total (6 lifecycle/branding + Slug + Robots). Migration is additive — no breaking change to #23/#40.

**Field reuse from existing Event entity** (no schema change — admin setup edits these existing fields via this screen):

| Existing Event Field | Used By Tab | Notes |
|----------------------|-------------|-------|
| EventName / EventCode | Tab 1 — Page Identity | Title source + default for Slug |
| EventCategoryId / EventModeId / EventTypeId | Tab 2 — Event Snapshot (read-only) | Edited via #23/#40 Event form, displayed here |
| StartDate / EndDate / TimezoneId | Tab 2 — Event Snapshot (read-only) | — |
| VenueName / VenueAddress / VenueCity / PincodeId / CountryId / MapLink / ParkingInfo / DressCode | Tab 2 — Event Snapshot (read-only) | — |
| VirtualPlatform / VirtualMeetingUrl / DialInNumbers | Tab 2 — Event Snapshot (read-only) | — |
| RegistrationRequired / RegistrationOpenDate / RegistrationEndDate / Capacity / WaitlistEnabled / WaitlistCapacity / EarlyBirdDeadline | Tab 3 — Registration Window | Editable |
| BannerImageUrl / DetailedAgendaHtml / EventHighlights | Tab 4 — Page Content | Editable; BannerImageUrl is the hero; DetailedAgendaHtml is the "About this event" rich-text |
| AcceptDonations / ShowFundraisingGoal / GoalAmount / LinkedDonationPurposeId | Tab 6 — Donation On Page | Editable; LinkedDonationPurposeId is FK ApiSelectV2 |
| QrCheckinEnabled / PostEventSurveyEnabled / ShowCountdown | Tab 5 — Registrant Experience | Editable |
| SendConfirmationEmail / ConfirmationTemplateId | Tab 7 — Communications | Editable |
| SendReminder / ReminderTimingCode / ReminderChannelEmail / ReminderChannelWhatsApp / ReminderChannelSms | Tab 7 — Communications | Editable |
| SendLinkTimingCode | Tab 7 — Communications | Editable (when EventModeId = Online/Hybrid) |
| ShareTitle / ShareDescription / ShareImageUrl | Tab 8 — SEO & Social | Editable |
| CancellationReason / PostponedToDate | Tab 2 — Event Snapshot (read-only) | Displayed if non-null; edited via #23/#40 |

### Slug uniqueness (NEW)

- Filtered unique index on `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted` — set up by THIS screen's migration
- Reserved-slug list rejected (case-insensitive): `admin, api, embed, p, p2p, preview, login, signup, oauth, public, assets, static, start, event-list, events, dashboard, _next, ic, register, signup, crowdfund, crowdfunding, volunteer, pray, donate`
- Slug auto-derived from EventName on first Page save; admin can override; same normalization applied (lowercase, replace whitespace with `-`, strip non-alphanumeric except `-`, collapse multiple `-`)
- Slug **immutable post-Activation when ≥1 EventRegistration attached** (`SELECT EXISTS (SELECT 1 FROM app.EventRegistrations WHERE EventId = X)`)
- Validator returns 422 with `{field:"slug", code:"SLUG_RESERVED|SLUG_TAKEN|SLUG_LOCKED_AFTER_REGISTRATIONS"}`

### PageStatus transitions (BE-enforced, NOT FE flag)

- Draft → Published only when `ValidateEventRegistrationPageForPublish` passes
- Published → Active automatic when `RegistrationOpenDate ≤ utcNow AND EventStatusId IN (Upcoming, Live)`
- Active → Closed automatic when any of:
  - `SUM(EventRegistration.Quantity WHERE StatusId=Confirmed) ≥ Event.Capacity` AND `WaitlistEnabled=false`
  - `RegistrationEndDate < utcNow`
  - `EventStatusId IN (Cancelled, Completed)` (event ended or was cancelled — page auto-closes registration)
  - Admin "Close Early"
- Any → Archived: admin-triggered (soft-delete; preserves `EventRegistration` FK rows; sets `PageArchivedAt`)

> **DO NOT** modify existing `EventStatusId` field semantics. The two status fields are orthogonal; cross-product table in §④.

### Child / Junction Tables (REUSE — no new tables introduced)

| Existing Table | Reused By | Modification |
|----------------|-----------|--------------|
| `app.EventTicketTypes` | Tab 3 — Ticket Types card | None — existing CRUD via `EventTicketTypeMutations` |
| `app.EventRegistrationFormFields` | Tab 5 — Registrant Experience (Form Fields sub-table) | None — existing CRUD |
| `app.EventCustomQuestions` | Tab 5 — Registrant Experience (Custom Questions sub-table) | None — existing CRUD |
| `app.EventSuggestedAmounts` | Tab 6 — Donation On Page | None — existing CRUD |
| `app.EventCommunicationTriggers` | Tab 7 — Communications (trigger table) | None — existing CRUD |
| `app.EventSpeakers` | Tab 4 — Page Content (Speakers sub-section) | None — existing CRUD; **DISPLAY-ONLY here**, full edit via #23/#40 |
| `app.EventGalleryPhotos` | Tab 4 — Page Content (Gallery) | None — existing CRUD |

### EventRegistration linkage (REUSE — no FK changes)

`app.EventRegistrations` already has `EventId` FK. Anonymous public submit on THIS page creates an `EventRegistration` row with:
- `EventId = X` (page's underlying event)
- `EventTicketId = Y` (resolved from `EventTicketTypeId` user picked — a row in `app.EventTickets` is created per-registrant if quantity > 1)
- `ContactId = NULL` initially; server upserts `crm.Contact` by RegistrantEmail; updates `ContactId` post-upsert
- `RegistrantName / RegistrantEmail / RegistrantPhone` — captured from public form
- `Quantity` — from public form (1 row per submission; ticket-instance rows created per quantity in `app.EventTickets`)
- `TotalAmount` — computed server-side from `TicketType.Price × Quantity − EarlyBird adjust + optional donation`
- `EventRegistrationCode` — auto-generated (format `EVT-{YEAR}-{6-digit-random}`)
- `QRCodeToken` — generated if `QrCheckinEnabled=true` (cryptographic random hex; SERVICE_PLACEHOLDER for QR-image generation library — token storage is in scope, image rendering deferred)
- `StatusId` — MasterData `EVENTREGISTRATIONSTATUS`: `Confirmed` (free ticket OR paid + gateway success) / `PendingPayment` (paid ticket awaiting gateway confirm) / `Cancelled` / `Refunded` / `Waitlisted`
- `RegisteredDate = utcNow`
- `CheckedIn = false`

> **DO NOT** create a separate `EventRegistrationPage` table. The Page lifecycle fields live on `Event` (single source of truth). This mirrors #173 CrowdfundingPage wrapping `CrowdFund`.

### MasterData seeds (verify before build — most should exist)

| Code | MasterDataType | Used For | Existing? |
|------|----------------|----------|-----------|
| `Confirmed / PendingPayment / Cancelled / Refunded / Waitlisted` | `EVENTREGISTRATIONSTATUS` | EventRegistration.StatusId | Verify with #137 EventTicketing build state — seed if absent |
| (Existing) `Upcoming / Live / Completed / Cancelled / Postponed` | `EVENTSTATUS` | Event.EventStatusId | Existing |
| (Existing) `InPerson / Online / Hybrid` | `EVENTMODE` | Event.EventModeId | Existing |
| (Existing) `Conference / Workshop / Gala / Walkathon / Webinar / ...` | `EVENTCATEGORY` | Event.EventCategoryId | Existing |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------------|---------------|-------------------|
| EventCategoryId | MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (filter `MasterDataType=EVENTCATEGORY`) | `displayName` | `MasterDataResponseDto` |
| EventModeId | MasterData | (same) | `getMasterDatas` (filter `EVENTMODE`) | (same) | (same) |
| EventStatusId | MasterData | (same) | `getMasterDatas` (filter `EVENTSTATUS`) | (same) | (same) |
| TimezoneId | MasterData | (same) | `getMasterDatas` (filter `TIMEZONE`) | (same) | (same) |
| OrganizationalUnitId | OrganizationalUnit | `Base.Domain/Models/CompanyOrgModels/OrganizationalUnit.cs` | `getAllOrganizationalUnitList` | `organizationalUnitName` | `OrganizationalUnitResponseDto` |
| CountryId | Country | `Base.Domain/Models/SharedModels/Country.cs` | `getCountries` | `countryName` | `CountryResponseDto` |
| PincodeId | Pincode | `Base.Domain/Models/SharedModels/Pincode.cs` | `getPincodes` (paginated) | `pincodeCode` | `PincodeResponseDto` |
| RelatedCampaignId | Campaign | `Base.Domain/Models/DonationModels/Campaign.cs` (`fund` schema) | `getAllCampaignList` | `campaignName` | `CampaignResponseDto` |
| LinkedDonationPurposeId | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` (`fund` schema) | `getAllDonationPurposeList` | `donationPurposeName` | `DonationPurposeResponseDto` |
| ConfirmationTemplateId | NotificationTemplate | `Base.Domain/Models/NotifyModels/NotificationTemplate.cs` (or `EmailTemplate.cs` — verify on build via Grep) | `getAllNotificationTemplateList` (or `getAllEmailTemplateList`) | `templateName` | `NotificationTemplateResponseDto` (or `EmailTemplateResponseDto`) |
| (child) EventTicketType.* | EventTicketType | `Base.Domain/Models/ApplicationModels/EventTicketType.cs` | `getAllEventTicketTypeList` (filter by `EventId`) | `ticketName` | `EventTicketTypeResponseDto` |
| (child) EventRegistrationFormField.* | EventRegistrationFormField | `Base.Domain/Models/ApplicationModels/EventRegistrationFormField.cs` | `getAllEventRegistrationFormFieldList` (filter by `EventId`) | `fieldLabel` | `EventRegistrationFormFieldResponseDto` |
| (child) EventCustomQuestion.* | EventCustomQuestion | `Base.Domain/Models/ApplicationModels/EventCustomQuestion.cs` | `getAllEventCustomQuestionList` (filter by `EventId`) | `questionText` | `EventCustomQuestionResponseDto` |
| (child) EventSuggestedAmount.* | EventSuggestedAmount | `Base.Domain/Models/ApplicationModels/EventSuggestedAmount.cs` | `getAllEventSuggestedAmountList` (filter by `EventId`) | `amount` | `EventSuggestedAmountResponseDto` |
| (child) EventCommunicationTrigger.* | EventCommunicationTrigger | `Base.Domain/Models/ApplicationModels/EventCommunicationTrigger.cs` | `getAllEventCommunicationTriggerList` (filter by `EventId`) | `triggerName` | `EventCommunicationTriggerResponseDto` |
| (child) EventSpeaker.* | EventSpeaker | `Base.Domain/Models/ApplicationModels/EventSpeaker.cs` | `getAllEventSpeakerList` (filter by `EventId`) | `speakerName` | `EventSpeakerResponseDto` |
| (child) EventGalleryPhoto.* | EventGalleryPhoto | `Base.Domain/Models/ApplicationModels/EventGalleryPhoto.cs` | `getAllEventGalleryPhotoList` (filter by `EventId`) | (image url) | `EventGalleryPhotoResponseDto` |

> **At build time**: verify `NotificationTemplate` vs `EmailTemplate` naming via Grep `class EmailTemplate` or `class NotificationTemplate` under `Base.Domain/Models/NotifyModels/`. Both names appear across the codebase; pick whichever the existing `ConfirmationTemplateId` FK on Event references.

**Master-data references** (looked up by code via existing `MasterData` model — NO FK column on entity):

| Code | MasterDataType | Used For |
|------|----------------|----------|
| `Confirmed / PendingPayment / Cancelled / Refunded / Waitlisted` | `EVENTREGISTRATIONSTATUS` (verify with #137 build state) | EventRegistration.StatusId — server applies on submit |

**Aggregation sources** (for status-bar stats + public-page progress):

| Source | Aggregate | Used In | Filter |
|--------|-----------|---------|--------|
| `app.EventRegistrations` | `COUNT(*)` GROUP BY EventId | `totalRegistrations` (status bar) | All non-deleted |
| `app.EventRegistrations` | `SUM(Quantity)` GROUP BY EventId WHERE StatusId=Confirmed | `confirmedCount` (status bar + capacity progress) | — |
| `app.EventRegistrations` | `COUNT(*)` GROUP BY EventId WHERE StatusId=PendingPayment | `pendingPaymentCount` | — |
| `app.EventRegistrations` | `COUNT(*)` GROUP BY EventId WHERE StatusId=Waitlisted | `waitlistCount` | — |
| `app.EventRegistrations` | `SUM(TotalAmount)` GROUP BY EventId WHERE StatusId=Confirmed | `totalRevenue` (status bar) | — |
| `app.EventRegistrations` | `MAX(RegisteredDate)` GROUP BY EventId | `lastRegistrationAt` | — |
| `app.EventRegistrations` | TOP 10 ORDER BY RegisteredDate DESC, project (RegistrantName + Quantity + RegisteredDate) | Recent Registrations widget (admin) | — |
| `app.EventRegistrations` | `(SUM(Quantity WHERE StatusId=Confirmed) × 100.0 / NULLIF(Event.Capacity, 0))` | `capacityUsedPct` (public progress bar) | — |
| `fund.GlobalDonations` | `SUM(NetAmount)` GROUP BY EventId | `totalDonations` (when AcceptDonations=true) | Status='Completed' |

> Status-bar query (`GetEventRegistrationPageStats`) cached server-side 30s. Donor-wall + recent-registrations widgets cached 60s.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Slug Rules**:

- Auto-generate from `EventName` on first Page save — lowercase, replace whitespace with `-`, strip non-alphanumeric (keep `-`), collapse multiple `-`. If existing `CustomUrl` is already a kebab-case slug, migrate it into `Slug` on first save; otherwise re-derive.
- User can override via Slug field; same normalization applied; show "URL preview" inline `/event/{slug}` with copy button
- Reserved-slug list rejected (case-insensitive): `admin, api, embed, p, p2p, preview, login, signup, oauth, public, assets, static, start, event-list, events, dashboard, _next, ic, register, crowdfund, crowdfunding, volunteer, pray, donate, fundraise`
- Uniqueness enforced per tenant — composite filtered unique `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted`
- Slug **immutable post-Activation when ≥1 EventRegistration attached** (`SELECT EXISTS (SELECT 1 FROM app.EventRegistrations WHERE EventId = X)`)
- Validator returns 422 with `{field:"slug", code:"SLUG_RESERVED|SLUG_TAKEN|SLUG_LOCKED_AFTER_REGISTRATIONS"}`

**Page-vs-Event Status Cross-Product** (CRITICAL — most-missed rule):

| EventStatusId ↓  /  PageStatus → | Draft | Published | Active | Closed | Archived |
|-----------------------------------|-------|-----------|--------|--------|----------|
| Upcoming | normal (admin setting up) | scheduled-pre-open | LIVE — accepts registrations | normal (cap hit or RegEndDate passed) | tombstoned |
| Live (event in progress) | rare — admin forgot to publish | rare — same | LIVE — accepts walk-up registrations if cap allows | normal | tombstoned |
| Completed (event ended) | rare | rare | INVALID — must auto-flip to Closed | normal (post-event archive view) | tombstoned |
| Cancelled | invalid — Page should be Archived | invalid | INVALID — must auto-flip to Closed + banner "Event cancelled" | "Event cancelled" banner | tombstoned |
| Postponed | normal (waiting for new date) | normal | LIVE — public shows "Postponed to: {PostponedToDate}" banner above CTA | normal | tombstoned |

**Invalid combinations** → BE rejects with explicit error message on lifecycle command:
- EventStatusId=Completed AND PageStatus=Active → auto-flip PageStatus to Closed on next state-tick
- EventStatusId=Cancelled AND PageStatus IN (Active, Published) → auto-flip PageStatus to Closed AND set CancellationReason banner

**Lifecycle Rules**:

| State | Set by | Public route behavior | Register button |
|-------|--------|----------------------|-----------------|
| Draft | Initial Create | 404 to public; preview-token grants temporary access | Disabled / not rendered |
| Published | Admin "Publish" action (pre-RegistrationOpenDate) | Renders publicly with "Registration opens {RegOpenDate}" banner | Disabled |
| Active | Auto-flip when RegistrationOpenDate ≤ now AND EventStatusId IN (Upcoming, Live) | Renders publicly | Live (with capacity / waitlist semantics) |
| Closed | Auto at (cap-met OR RegEndDate-passed OR event-Cancelled/Completed); admin "Close Early" | Renders publicly with "Registration is closed for this event" banner | Disabled |
| Archived | Admin "Archive" | 410 Gone (admin can configure redirect to org default) | N/A |

**Required-to-Publish Validation** (return all violations as a list — don't stop at first):

- EventName non-empty (already enforced by #23/#40)
- Slug set + unique + not reserved
- EventStatusId IN (Upcoming, Live) — cannot publish a Cancelled/Completed event's page
- StartDate set + StartDate ≥ today (warn if past — page renders post-event archive view)
- RegistrationOpenDate set (default = today) + RegistrationEndDate set + RegistrationOpenDate ≤ RegistrationEndDate
- (Capacity > 0) OR (≥1 EventTicketType with Available=true) — must have a cap-or-tickets to fill
- BannerImageUrl OR ShareImageUrl set (warn but allow — falls back to category gradient on public page)
- ≥1 active EventRegistrationFormField (FirstName + Email forced enabled — guarded by validator)
- (if `SendConfirmationEmail=true`) ConfirmationTemplateId set
- (if `SendReminder=true`) ReminderTimingCode set + ≥1 reminder channel enabled (Email / WhatsApp / SMS)
- (if `AcceptDonations=true`) LinkedDonationPurposeId set + (≥1 EventSuggestedAmount OR AllowCustomAmount enabled — defer AllowCustomAmount field if not on Event yet; warn for now)
- (if `ShowFundraisingGoal=true`) GoalAmount > 0
- (if EventModeId=Online OR Hybrid) VirtualMeetingUrl set OR DialInNumbers set (admin warns; pre-event email sends link per `SendLinkTimingCode`)
- ShareTitle + ShareImageUrl set for OG preview (warn — falls back to EventName + BannerImageUrl)
- PrimaryColorHex valid hex (default `#2563eb` always valid)

**Conditional Rules**:

- If `AcceptDonations = FALSE` → SuggestedAmounts / GoalAmount / LinkedDonationPurpose fields hidden on public form
- If `QrCheckinEnabled = TRUE` → server generates `QRCodeToken` on Confirmed transition + emails QR
- If `WaitlistEnabled = TRUE` AND capacity-met → public Register button switches to "Join Waitlist"; `WaitlistCapacity` enforced
- If `ShowCountdown = TRUE` → public hero renders countdown timer to StartDate
- If `RegistrationEndDate < now` AND `PageStatus = Active` → auto-flip PageStatus to Closed on next state-tick OR on next public request
- If `EventStatusId = Cancelled` → public page renders prominent banner "Event cancelled: {CancellationReason}" + Register disabled (regardless of PageStatus)
- If `EventStatusId = Postponed` → public page renders banner "Postponed to {PostponedToDate}" + Register STILL allowed (registrations carry forward)
- If `EventModeId = Online` → drops physical-venue fields from public hero; emphasizes VirtualPlatform + meeting-join CTA (sent in confirmation email per `SendLinkTimingCode`)
- If a registered ticket type's Capacity is reached → that ticket type renders as "Sold out" badge on public form (disabled selection); other ticket types remain available

**Sensitive / Security-Critical Fields**:

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| Registrant PII (RegistrantName, Email, Phone, custom-question answers) | regulatory (PII) | server-side only; never logged in plain text | encrypt-at-rest at column level if regulation requires (GDPR/PHI) | log access |
| QRCodeToken | secret per registration | one-time render in confirmation email; never re-displayable | random hex, store hashed if used for check-in security; never expose via list query | log on regen |
| Virtual meeting URL / password | secret (event access) | NOT on public page pre-event; emailed `SendLinkTimingCode` minutes before | encrypted at rest | log on send |
| DetailedAgendaHtml / EventHighlights | injection-risk (rich text) | sanitize via DOMPurify on public side | sanitize-strip `<script/iframe/style/onerror/onclick>` server-side; max 16000 chars | log on save |
| Anti-fraud markers (IP, UA, velocity) | operational | not on public; admin-only via audit | append-only; retain per policy | — |

**Public-form Hardening (anonymous-route concerns)**:

- Rate-limit submit POST: **5 attempts / minute / IP / slug** (new `EventRegistrationSubmit` policy class — mirror existing `DonationSubmit / VolunteerSubmit / CrowdFundDonationSubmit`)
- CSRF token issued on initial public-page render; required on submit; rotation on each render
- Honeypot field `[name="website"]` hidden via CSS; submission with non-empty honeypot silently rejected (return mocked success to bot)
- reCAPTCHA v3 score check before final submission — `SERVICE_PLACEHOLDER` until reCAPTCHA configured (returns score=1.0)
- All registrant input field-validated server-side (never trust public client) — type/length/regex per field config
- CSP headers on public route: `script-src 'self' https://js.stripe.com https://www.paypal.com https://www.google.com/recaptcha; frame-src https://js.stripe.com https://www.paypal.com https://www.google.com/recaptcha; style-src 'self' 'unsafe-inline'; img-src * data: https:; frame-ancestors 'none'`
- Idempotency: `InitiateEventRegistration` POST has `idempotencyKey` (client UUID) — re-posting same key returns same intent response (prevents double-submit on flaky network)

**Atomic capacity check** (CRITICAL — overbooking guard):

- `ConfirmEventRegistration` (and the synchronous free-ticket submit path) MUST execute inside a transaction:
  1. `SELECT Capacity, (SELECT SUM(Quantity) FROM EventRegistrations WHERE EventId=X AND StatusId=Confirmed) AS confirmed FOR UPDATE` (lock the Event row)
  2. If `confirmed + requestedQty > Capacity` AND `NOT WaitlistEnabled` → REJECT with 409 `{code:"CAPACITY_REACHED"}`
  3. If `confirmed + requestedQty > Capacity` AND `WaitlistEnabled` AND `(SELECT COUNT(*) FROM EventRegistrations WHERE EventId=X AND StatusId=Waitlisted) + requestedQty > WaitlistCapacity` → REJECT with 409 `{code:"WAITLIST_FULL"}`
  4. Else INSERT EventRegistration row(s) with appropriate Status (Confirmed if within Capacity; Waitlisted if Capacity met but waitlist available)
  5. COMMIT

- Same guard applies per-TicketType: each TicketType has its own `Capacity` and own `SUM(Quantity)` — atomic per-ticket check before parent-event-capacity check.

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Publish | Page goes live; URL becomes shareable | "Publishing makes this page public at /event/{slug}. Confirm?" | log "page published" + jsonb config snapshot |
| Unpublish | Active → Draft; submissions rejected | "Public visitors will see a 'registration closed' page. Confirm?" | log |
| Close Early | Active → Closed before RegEndDate; new submissions rejected | "Close registration now? {confirmedCount} confirmed so far." | log + email event owner |
| Archive | Soft-delete; URL returns 410 | type-name confirm ("type {eventName} to archive") | log |
| Reset Branding | Wipe theme/branding back to defaults | type-name confirm | log |
| Edit Slug (Draft only) | Changes public URL | "Slug changes break any preview-link shares." | log |

**Role Gating**:

| Role | Setup access | Publish access | Notes |
|------|-------------|----------------|-------|
| BUSINESSADMIN | full | yes | full lifecycle (target role for MVP) |
| Anonymous public | no setup access | — | only sees Active/Closed public route |

**Workflow** (cross-page — registrant flow):

1. Anonymous visitor lands on `/event/{slug}` → server resolves slug → Event row (status-gated)
2. Public page renders: hero (banner / event name / date / venue) → ticket-type picker (with capacity/sold-out indicators) → quantity selector → registrant form (per EventRegistrationFormFields + EventCustomQuestions) → optional donation block (if AcceptDonations=true) → CTA button (label depends on free vs paid)
3. Visitor submits form with CSRF token + idempotencyKey:
   - **Free ticket flow**: server calls `InitiateEventRegistration` → atomic capacity check → INSERT EventRegistration row(s) with StatusId=Confirmed + generate EventRegistrationCode + (if QrCheckinEnabled) generate QRCodeToken → fire confirmation email (SERVICE_PLACEHOLDER) → return thank-you state with QR / E-ticket
   - **Paid ticket flow**: server calls `InitiateEventRegistration` → atomic capacity reserve with StatusId=PendingPayment + EventRegistrationCode + paymentSessionId (SERVICE_PLACEHOLDER mock) → return `{paymentSessionId, redirectUrl}` → FE redirects to gateway iframe / hosted page → gateway callback → server calls `ConfirmEventRegistration` → flip Status PendingPayment→Confirmed + (if QrCheckinEnabled) generate QRCodeToken + fire confirmation email
4. (If donation block present) Donation creates parallel `fund.GlobalDonation` row linked to `EventId` (same gateway hand-off if paid; bundles in same payment intent for paid-ticket-plus-donation)
5. Server upserts `crm.Contact` by RegistrantEmail; links `EventRegistration.ContactId`
6. Async: send reminder email per ReminderTimingCode + ReminderChannel* toggles
7. Event-day: registrant arrives → admin scans QR via #137 EventTicketing → flips CheckedIn=true + CheckedInDate=now

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on the assumed UX (mockup TBD).

**Screen Type**: EXTERNAL_PAGE
**External-Page Sub-type**: `DONATION_PAGE`
> Re-using the DONATION_PAGE sub-type because the structural pattern — single public registration page + admin setup with slug + Publish lifecycle + form-config + branding + optional payment hand-off — matches more closely than P2P_FUNDRAISER (no parent-with-children hierarchy of sub-pages) or CROWDFUND (no goal/deadline-driven reward tiers). Same sub-type used by #172 VolunteerRegistrationPage. The "donation" in DONATION_PAGE here means "the funnel converts a visitor into a recorded transaction" — for events, the transaction is a registration not a donation.

**Storage Pattern**: `single-page-record` (wraps existing Event entity; reuses existing child collections; no new child entities)

**Slug Strategy**: `custom-with-fallback`
> Slug auto-derived from EventName on first Page save; admin may override; auto re-applied when slug field is cleared. Slug becomes immutable once registrations attached.

**Lifecycle Set**: `Draft / Published / Active / Closed / Archived` (full; orthogonal to existing EventStatusId)

**Save Model**: `autosave-with-publish`
> Each settings card autosaves on edit (300ms debounce). The top-right "Save & Publish" button explicitly transitions Draft → Active after Validate-for-Publish passes. No "Save" button — implicit autosave + explicit Publish.

**Public Render Strategy**: `ssr`
> Event pages must be SEO-indexable (Google "{event name} {city}" + "events near me"). Use Next.js App Router `(public)/event/[slug]/page.tsx` with `generateMetadata` for OG tags + `revalidate: 60` for ISR. Banner image / video lazy-loaded.

**Reason**: DONATION_PAGE sub-type fits because the screen is a single public registration page with admin setup + Publish lifecycle + form-field config + branding + ticket-aware paid/free dual-flow. `single-page-record` storage works because page-lifecycle fields live on the Event row itself; child entities reuse existing tables. `custom-with-fallback` slug matches the editable-with-fallback expectation. `autosave-with-publish` matches the implicit-save + explicit-publish pattern from #10/#172. SSR is critical for organic-search discovery + correct OG previews.

**Backend Patterns Required**:

For DONATION_PAGE-like (event registration) — most CRUD reused from #23/#40 Event:

- [x] **REUSE from #23/#40** (no rebuild):
  - GetAllEventList / GetEventById / GetEventDashboardById / GetEventSummary
  - CreateEvent / UpdateEvent / DeleteEvent / DuplicateEvent / ToggleEvent / CancelEvent / CompleteEvent / PublishEvent (event-lifecycle)
  - All child entity CRUD: EventTicketType, EventRegistrationFormField, EventCustomQuestion, EventSuggestedAmount, EventCommunicationTrigger, EventSpeaker, EventGalleryPhoto

- [x] **NEW handlers added by THIS screen** (under `Business/ApplicationBusiness/EventRegistrationPages/`):
  - GetAllEventRegistrationPagesList query (admin list — filters Events where `PublicEventPage=true OR PageStatus IS NOT NULL`) — tenant-scoped, paginated, page-status filter
  - GetEventRegistrationPageById query (admin editor — projects page-relevant fields + child collections)
  - GetEventRegistrationPageBySlug query (public route) — anonymous-allowed, status-gated; projects only public-safe fields
  - GetEventRegistrationPageStats query — totalRegistrations / confirmedCount / pendingPaymentCount / waitlistCount / totalRevenue / capacityUsedPct / lastRegistrationAt / recentRegistrations[10]
  - GetEventRegistrationPagePublishValidationStatus query — returns missing-fields list
  - UpdateEventRegistrationPageSetup mutation (partial save of page-lifecycle + branding + page-only fields; backwards-compatible with #23/#40 UpdateEvent)
  - PublishEventRegistrationPage mutation — runs ValidateForPublish + transitions PageStatus Draft → Active (or Published if RegistrationOpenDate is future) + sets PagePublishedAt
  - UnpublishEventRegistrationPage mutation — Active/Published → Draft
  - CloseEventRegistrationPage mutation — Active → Closed
  - ArchiveEventRegistrationPage mutation — soft-delete + 410 Gone afterwards + sets PageArchivedAt
  - ResetEventRegistrationPageBranding mutation — wipe BannerImageUrl / PrimaryColorHex / AccentColorHex / RegistrationPageLayout / ShareTitle / ShareDescription / ShareImageUrl to defaults
  - InitiateEventRegistration **public mutation** (anonymous) — atomic capacity check + creates EventRegistration row(s) with appropriate Status; for paid flow returns paymentSessionId (SERVICE_PLACEHOLDER); for free flow returns thank-you state + QR token + EventRegistrationCode
  - ConfirmEventRegistration **public mutation** (gateway callback handler) — finalizes PendingPayment → Confirmed; emits QR + confirmation email
  - Slug uniqueness validator + reserved-slug rejection (new `EventRegistrationPageSlugValidator`)
  - Tenant scoping (CompanyId from HttpContext) — anonymous public uses CompanyId resolved from `(slug)` lookup
  - Anti-fraud throttle on public submit endpoint (new rate-limit policy `EventRegistrationSubmit` registered in `Base.API/DependencyInjection.cs`)

- [ ] Real reCAPTCHA / email-send / QR-image-generation → SERVICE_PLACEHOLDER until configured

**Frontend Patterns Required**:

For DONATION_PAGE-like (event registration) — TWO render trees:

- [x] Admin setup at `setting/publicpages/eventregpage` — list view (when `?id` not present) + editor (`?id=N`)
- [x] Editor: split-pane (settings cards left + live preview right) — 8 settings cards
- [x] Live Preview component — debounced 300ms; 2 variants (Desktop / Mobile via device-switcher)
- [x] Public page at `(public)/event/[slug]/page.tsx` — SSR; hero (banner + event name + date + venue/online) + ticket picker + registrant form + optional donation block + footer
- [x] Anonymous registrant-form component — respects EventRegistrationFormFields + EventCustomQuestions + selected TicketType pricing
- [x] Capacity / sold-out indicators per ticket type
- [x] Waitlist CTA when capacity met
- [x] Thank-you state — inline (within form region) with QR token / EventRegistrationCode rendered OR redirect to a configurable URL
- [x] Payment-gateway hand-off iframe (SERVICE_PLACEHOLDER until gateway connect implemented)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **MOCKUP STATUS**: TBD — assumed blueprint patterned after `volunteerregpage.md` §⑥ (8-card autosave + live preview) and `event-form.html` Registration + Settings tabs for event-specific UI cues. **Validate with user before /build-screen.**

### 🎨 Visual Treatment Rules (apply to all surfaces)

1. **Public page is brand-driven** — banner image full-bleed, primary CTA color = `PrimaryColorHex` (default `#2563eb` event blue), logo from tenant settings. Don't re-use admin shell chrome.
2. **Admin setup mirrors what the public will see** — every meaningful edit reflected in live preview pane within 300ms.
3. **Mobile preview is mandatory** — most public visitors are on mobile. Device-switcher (Desktop / Mobile) toggles preview viewport.
4. **Page-status visually clear** — Status Bar at top of admin setup shows current PageStatus as colored dot + label (Active=green / Draft=gray / Published=blue / Closed=orange / Archived=red).
5. **Event-status badge separate** — under the page-status bar, a smaller event-status badge shows EventStatusId (Upcoming/Live/Completed/Cancelled/Postponed) with link to #23/#40 Event form.
6. **Register CTA is dominant** — `PrimaryColorHex` background, sized to prompt action, sticky on mobile scroll.
7. **Capacity indicator first-class** — public hero shows "X of Y spots filled" progress bar (when ShowCountdown enabled also shows time-to-event countdown).
8. **Trust signals first-class** — secure-payment lock icon (when paid) + privacy line + organizer contact in footer.
9. **Settings cards consistent chrome** — bordered card + 12px radius + 1px border + header with Phosphor icon + body. Same chrome for all 8 cards.
10. **Tokens (not hex/px)** — per memory `feedback_ui_uniformity.md` — KPI tile / status badge / chip uses SOLID `bg-X-600 text-white`; no `bg-X-50/100` or `text-X-700/800`. Inline hex permitted only inside designated brand-renderer (live preview).
11. **Amount alignments** — Ticket Type Price column right-aligned (per memory `feedback_amount_field_alignment.md`); ticket-picker prices on public form right-aligned within each row.

**Anti-patterns to refuse**:
- Admin chrome bleeding into public route (sidebar visible to anonymous visitors)
- "Save and refresh to preview"
- Page-status mixed with event-status in one badge (must be visually distinct)
- Public form without privacy / cancellation-policy / contact-organizer footer
- Generic Register button styled as tertiary
- Default branding identical to OnlineDonationPage — event pages default to `#2563eb` event blue
- Sold-out ticket type hidden — must remain visible with "Sold out" badge
- Capacity progress bar without absolute numbers ("X% full" alone is opaque; show "120 / 400")
- Form Create button enablement gated on `canCreate` — per memory `feedback_form_create_button_enablement.md`, Save & Publish is gated only by RHF `formState.isValid`

---

### A.1 — Admin Setup UI (split-pane: editor left + live preview right)

**Stamp**: `Layout Variant: split-pane (editor + preview)` — same EXTERNAL_PAGE layout as `#172 VolunteerRegistrationPage` and `#10 OnlineDonationPage`. NOT a DataTable, NOT FlowDataTable. Use Variant B (ScreenHeader + `showHeader=false`) to avoid double-header bug.

**Page Layout** (assumed — to be validated with mockup):

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ [🎟  Event Registration Page]         [← Back] [↗ Preview] [🚀 Save & Publish]    │
│ Configure the public registration page for {EventName}                            │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ● Active  Registrations: 142  Confirmed: 120  Pending: 18  Waitlist: 4  Last: 30m │  ← Page Status Bar (real aggregates)
│ ● Event Status: Upcoming  ●Edit Event details →                                  │  ← Event Status row (read-only link to #23/#40)
├──────────────────────────────────────────────────────────────────────────────────┤
│ EDITOR (8 settings cards stacked)              │ LIVE PREVIEW                    │
│                                                │ Event Page Preview │ [Desktop|Mobile]│
│ ┌─────────────────────────────────────────┐   │ ┌──────────────────────────────┐│
│ │ 🔗 Page Identity                        │   │ │ ┌──────────────────────────┐ ││
│ │  • Page Title (from EventName) — RO     │   │ │ │ 🔒 https://.../event/    │ ││
│ │  • Slug * + URL preview + copy          │   │ │ │       annual-gala-2026   │ ││
│ │  • Tagline / Page subtitle              │   │ │ ├──────────────────────────┤ ││
│ │  • Page Status (read-only display)      │   │ │ │ [Banner — full-bleed]    │ ││
│ ├─────────────────────────────────────────┤   │ │ │ Annual Charity Gala 2026 │ ││
│ │ 📅 Event Snapshot (READ-ONLY)           │   │ │ │ 📅 Apr 27 · 7pm           │ ││
│ │  Date | Venue | Mode | Category | Status│   │ │ │ 📍 Hotel Grandeur,Dubai  │ ││
│ │  [Edit Event details →] (links to #40)  │   │ │ │ ⏱  Countdown timer       │ ││
│ ├─────────────────────────────────────────┤   │ │ ├──────────────────────────┤ ││
│ │ 🎫 Ticket Types                         │   │ │ │ ●Standard $250  120/300  │ ││
│ │  Type            Price   Cap  EarlyBird │   │ │ │ ◯VIP $500       12/80    │ ││
│ │  Standard        $250    300  $200      │   │ │ │ ◯Student $100   45/50    │ ││
│ │  VIP             $500     80  $400      │   │ │ │ ◯Corporate $4000  3/5    │ ││
│ │  Student         $100     50  $75       │   │ │ │ [Sold out] Free Vol      │ ││
│ │  [+ Add Ticket Type]                    │   │ │ ├──────────────────────────┤ ││
│ ├─────────────────────────────────────────┤   │ │ │ Quantity: [- 1 +]        │ ││
│ │ 📅 Registration Window                  │   │ │ │ First Name *  Last Name *│ ││
│ │  • Registration Required toggle         │   │ │ │ Email *       Phone      │ ││
│ │  • Registration Opens                   │   │ │ │ Org / Company            │ ││
│ │  • Registration Closes                  │   │ │ │ Dietary, T-shirt size... │ ││
│ │  • Early Bird Deadline                  │   │ │ │ ☐ Donate alongside       │ ││
│ │  • Capacity *                           │   │ │ │ [REGISTER NOW $250]      │ ││
│ │  • Waitlist toggle + Waitlist capacity  │   │ │ │ 🔒 Secure  ✉ Receipt     │ ││
│ ├─────────────────────────────────────────┤   │ │ │ Privacy · Contact organizer│ │
│ │ 📝 Registrant Experience                │   │ │ └──────────────────────────┘ ││
│ │  Form Fields (8-row table):             │   │ └──────────────────────────────┘│
│ │  Full Name *      [✓ disabled] [✓ disabled]│ │ (Re-renders within 300ms on   │
│ │  Email *          [✓ disabled] [✓ disabled]│ │  any settings-card edit)       │
│ │  Phone            [✓] [✓]                │   │                                  │
│ │  Organization     [ ] [✓]                │   │                                  │
│ │  Dietary Req      [ ] [✓]                │   │                                  │
│ │  Accessibility    [ ] [✓]                │   │                                  │
│ │  T-shirt Size     [ ] [ ]                │   │                                  │
│ │  Emergency Contact[ ] [ ]                │   │                                  │
│ │  [+ Add Custom Field] → EventCustomQuestion│ │                                  │
│ │  Custom Questions (table — title/type/req)│ │                                  │
│ │  • Show Countdown toggle                 │   │                                  │
│ │  • QR Code Check-in toggle               │   │                                  │
│ │  • Post-event Survey toggle              │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 💝 Donation On Page                     │   │                                  │
│ │  • Accept Donations toggle              │   │                                  │
│ │  • Linked Donation Purpose dropdown     │   │                                  │
│ │  • Suggested Amounts chip-editor        │   │                                  │
│ │  • Show Fundraising Goal toggle         │   │                                  │
│ │  • Goal Amount                          │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ ✉ Communications                        │   │                                  │
│ │  • Send Confirmation Email toggle       │   │                                  │
│ │  • Confirmation Template dropdown *     │   │                                  │
│ │  • Send Reminder toggle                 │   │                                  │
│ │  • Reminder timing (24hr/1hr/both)      │   │                                  │
│ │  • Channels (Email/WhatsApp/SMS)        │   │                                  │
│ │  • Send Link Timing (Online events)     │   │                                  │
│ │  • Communication Triggers table         │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🎨 Branding                             │   │                                  │
│ │  • Banner Image upload                  │   │                                  │
│ │  • Primary color (#2563eb)              │   │                                  │
│ │  • Accent color (#1d4ed8)               │   │                                  │
│ │  • Register button text (default        │   │                                  │
│ │     "Register Now" — auto-suffixes      │   │                                  │
│ │     price if paid)                      │   │                                  │
│ │  • Page Layout (centered/side-by-side/  │   │                                  │
│ │     full-width)                         │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🔍 SEO & Social                         │   │                                  │
│ │  • Share Title (max 70)                 │   │                                  │
│ │  • Share Description (max 160 +chars)   │   │                                  │
│ │  • Share Image (uses Banner by default) │   │                                  │
│ │  • Robots indexable toggle              │   │                                  │
│ │  • Social Preview Card (FB/Twitter)     │   │                                  │
│ └─────────────────────────────────────────┘   │                                  │
└────────────────────────────────────────────────┴─────────────────────────────────┘
```

**Settings Cards** (8 — order matches assumed UX; matches public render order top-to-bottom where applicable):

| # | Card | Icon (phosphor) | Save Model | Notes |
|---|------|-----------------|------------|-------|
| 1 | Page Identity | `ph:link` | autosave | EventName (read-only display, links to #40) + Slug * (URL preview + copy) + Tagline + Description (rich) + PageStatus (read-only badge — managed via top-right buttons) |
| 2 | Event Snapshot (read-only) | `ph:calendar` | (no-save) | StartDate / EndDate / VenueName+Address (or Virtual platform) / EventModeId / EventCategoryId / EventStatusId — all read-only with **[Edit Event details →]** link to `#40 Event form` |
| 3 | Ticket Types | `ph:ticket` | autosave (per row) | Table editor for `EventTicketType` rows — TicketName / Price / Capacity / EarlyBirdPrice / Available toggle / SortOrder drag-handle. "+ Add Ticket Type" appends row. Delete row with confirm if Available=true (warn "{N} tickets already sold — refund tracking applies"). |
| 4 | Registration Window | `ph:calendar-blank` | autosave | RegistrationRequired toggle + RegistrationOpenDate + RegistrationEndDate + EarlyBirdDeadline + Capacity * + WaitlistEnabled toggle + WaitlistCapacity (visible when toggle ON) |
| 5 | Registrant Experience | `ph:list-checks` | autosave | (a) Form Fields 8-row table — FirstName/Email forced required+visible+locked (2 disabled rows); other 6 system fields (Phone/Organization/Dietary/Accessibility/Tshirt/Emergency) editable per row with Required+Visible checkboxes. (b) "+ Add Custom Field" creates `EventCustomQuestion` row → modal with QuestionText / QuestionType (Text/Number/Date/Dropdown/Checkbox) / IsRequired / Options. (c) ShowCountdown / QrCheckinEnabled / PostEventSurveyEnabled toggles. |
| 6 | Donation On Page | `ph:hand-coins` | autosave | AcceptDonations toggle + LinkedDonationPurposeId ApiSelectV2 + SuggestedAmounts tag-input chip-editor (saves to `EventSuggestedAmount` rows) + ShowFundraisingGoal toggle + GoalAmount |
| 7 | Communications | `ph:envelope-simple` | autosave | SendConfirmationEmail + ConfirmationTemplateId * ApiSelect + SendReminder + ReminderTimingCode (24hr/1hr/both) + 3 channel toggles + SendLinkTimingCode (online events only) + CommunicationTriggers table (Trigger / Channel / Timing — manages `EventCommunicationTrigger` rows) |
| 8 | Branding & SEO | `ph:palette` + `ph:share-network` | autosave | (a) BannerImageUrl upload + PrimaryColorHex color-picker (default `#2563eb`) + AccentColorHex (`#1d4ed8`) + Register button text + RegistrationPageLayout select (centered/side-by-side/full-width). (b) ShareTitle (max 70) + ShareDescription (max 160) + ShareImageUrl (defaults to BannerImageUrl) + RobotsIndexable toggle + Social-preview card showing FB/Twitter share appearance. |

**Live Preview Behavior**:
- Updates on every settings-card edit (debounced 300ms; client-side state, NOT round-trip to server)
- Mobile / Desktop toggle changes preview viewport width
- 2 preview variants: `desktop` / `mobile`
- "Open in new tab" button on Draft → uses preview-token query param
- Banner overlay "PREVIEW — NOT YET LIVE" when PageStatus=Draft
- Banner overlay "PUBLISHED — NOT YET OPEN" when PageStatus=Published AND RegistrationOpenDate > now

**Page Actions** (top-right):

| Action | Position | Style | Confirmation |
|--------|----------|-------|--------------|
| Back | top-right | outline-accent | navigates to setup list view |
| Preview Full Page | top-right | outline-accent | opens public route in new tab with preview-token if Draft |
| Save & Publish (Draft state) | top-right | primary-accent | runs Validate-for-Publish; if pass → "Publishing makes this page public at /event/{slug}." → transitions Draft → Published (or Active if RegOpenDate ≤ now); if fail → modal lists missing fields |
| Unpublish (Active state) | top-right | outline-warning | "Public visitors will see a 'registration closed' page." |
| Close Early (Active state — overflow) | top-right overflow | outline-destructive | "Close registration now? {confirmedCount} confirmed so far." |
| Archive (any state — overflow) | top-right overflow | destructive | type-name confirm |
| Reset Branding (overflow) | top-right overflow | outline-destructive | type-name confirm |

### A.2 — Admin List View (when no `?id` query param)

> **Surface**: Cards-grid view (not a flat table). Each card = one Event with `PageStatus` flag. Implementation strategy: reuse #23/#40's existing `EventCardsGrid` component (if present) OR build a fresh card grid here filtered to Events that have `PublicEventPage=true OR Slug IS NOT NULL`.

**Page Layout**:

```
┌──────────────────────────────────────────────────────────────────────┐
│ Event Registration Pages                  [+ Configure New Page]      │
│ Manage public registration pages for upcoming events                  │
├──────────────────────────────────────────────────────────────────────┤
│ KPI Tiles                                                             │
│ [Active Pages: 6] [Total Registrations: 384] [Capacity Used 64%] [Revenue $87K]│
├──────────────────────────────────────────────────────────────────────┤
│ Filters                                                               │
│ [Status ▼] [Event Status ▼] [Date Range] [Search...]                  │
├──────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐       │
│ │ [Banner thumb]   │ │ [Banner thumb]   │ │ [Banner thumb]   │       │
│ │ Annual Gala 2026 │ │ Walkathon May    │ │ Speaker Series   │       │
│ │ Apr 27 · Hotel.. │ │ May 11 · Park    │ │ Jun 2 · Online   │       │
│ │ ●Active   ●Upcom │ │ ●Active   ●Upcom │ │ ●Draft    ●Upcom │       │
│ │ 142/450 regs     │ │ 67/200 regs      │ │ 0/100 regs       │       │
│ │ Revenue $87K     │ │ Revenue $13K     │ │ —                │       │
│ │ [Edit][Preview]  │ │ [Edit][Preview]  │ │ [Edit][Preview]  │       │
│ └──────────────────┘ └──────────────────┘ └──────────────────┘       │
└──────────────────────────────────────────────────────────────────────┘
```

**Empty state** (no Events with `PublicEventPage=true`):
- Centered illustration + heading "No event pages yet"
- Body "Publish a registration page for an upcoming event to start collecting registrations."
- Two CTAs: `[Create New Event →]` (links to #40) + `[Configure existing event →]` (opens picker modal of Events where `PublicEventPage=false`)

### A.3 — Public Page (anonymous route at `/event/{slug}`)

**Page Layout** (mobile-first; register CTA sticky on mobile):

```
┌────────────────────────────────────────────────────────────┐
│   {Tenant Logo}        Event   Speakers   Venue   FAQ      │  ← thin nav (optional)
├────────────────────────────────────────────────────────────┤
│            [Banner Image — full bleed]                     │
│                                                            │
│            Annual Charity Gala 2026                        │
│            April 27, 2026 · 7:00 PM                        │
│            Hotel Grandeur, Dubai                           │
│            ⏱  72 days · 4 hr · 12 min  (if ShowCountdown)  │
│                                                            │
│            [REGISTER NOW]   (sticky on mobile scroll)      │
├────────────────────────────────────────────────────────────┤
│   About this Event                                         │
│   {DetailedAgendaHtml rendered}                            │
├────────────────────────────────────────────────────────────┤
│   Speakers / Special Guests  (if any EventSpeakers)        │
│   [Card] [Card] [Card]                                     │
├────────────────────────────────────────────────────────────┤
│   📍 Venue / 🌐 Online                                     │
│   {VenueName / Address / MapLink}                          │
│   {Parking Info / Dress Code}                              │
├────────────────────────────────────────────────────────────┤
│   🎫 Register                                              │
│   ┌──────────────────────────────────────────────────────┐ │
│   │ ●Standard       $250 (early bird $200)  120 / 300    │ │
│   │ ◯VIP            $500 (early bird $400)   12 /  80    │ │
│   │ ◯Student/Youth  $100 (early bird $75)    45 /  50    │ │
│   │ ◯Corp Table     $4000                     3 /   5    │ │
│   │ [Sold out] Free (Volunteers/Staff)         0 /   0    │ │
│   ├──────────────────────────────────────────────────────┤ │
│   │ Quantity:  [-]  1  [+]    Subtotal: $250             │ │
│   ├──────────────────────────────────────────────────────┤ │
│   │ First Name *      Last Name *                         │ │
│   │ Email *           Phone                               │ │
│   │ Organization / Company                                │ │
│   │ Dietary Requirements                                  │ │
│   │ T-shirt Size                                          │ │
│   │ Emergency Contact                                     │ │
│   │ [+ Custom Question 1: ...]                            │ │
│   │ [+ Custom Question 2: ...]                            │ │
│   ├──────────────────────────────────────────────────────┤ │
│   │ ☐ Make an optional donation alongside                 │ │
│   │   (expanded → SuggestedAmounts chips + custom)        │ │
│   ├──────────────────────────────────────────────────────┤ │
│   │ [REGISTER NOW $250]                                   │ │
│   │ 🔒 Secure payment · ✉ Receipt by email                │ │
│   └──────────────────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────────┤
│   FAQ (if AcceptDonations / agenda highlights / etc)       │
├────────────────────────────────────────────────────────────┤
│   Footer: Privacy / Cancellation Policy / Contact Organizer│
│   © {tenant} · Powered by {brand}                          │
└────────────────────────────────────────────────────────────┘
```

**Public-route behavior**:
- SSR with `revalidate=60` (slug → Event projection cached 60s; status-gated)
- `generateMetadata` returns `{title:ShareTitle ?? EventName, description:ShareDescription, openGraph:{title, description, images:[ShareImageUrl ?? BannerImageUrl]}, robots:{index:RobotsIndexable, follow:true}}`
- Anonymous-allowed route (no auth gate); CSP headers strict
- CSRF token issued in initial render; required on submit
- Honeypot field hidden in form
- On submit: server-side atomic capacity check → INSERT EventRegistration → (free) thank-you state with QR token + EventRegistrationCode; (paid) redirect to gateway iframe → on callback, ConfirmEventRegistration → thank-you state
- On gateway failure: inline error, retain form state
- On success: thank-you state inline (or redirect to configured URL); confirmation email fires; QR code attached if QrCheckinEnabled

**Edge states**:
- `PageStatus = Draft` → 404 (unless preview-token in querystring)
- `PageStatus = Published` AND `RegistrationOpenDate > now` → renders page with "Registration opens {RegistrationOpenDate}" banner; CTA disabled
- `PageStatus = Active` AND `EventStatusId = Cancelled` → renders page with red banner "Event cancelled: {CancellationReason}"; CTA disabled
- `PageStatus = Active` AND `EventStatusId = Postponed` → renders page with amber banner "Postponed to {PostponedToDate}"; CTA STILL allowed (registrations carry forward)
- `PageStatus = Active` AND capacity met AND `WaitlistEnabled=true` → CTA reads "Join Waitlist" → submits to same endpoint with intended Status=Waitlisted
- `PageStatus = Active` AND capacity met AND `WaitlistEnabled=false` → "Event is full" banner; CTA disabled
- `PageStatus = Closed` → renders page with "Registration is closed for this event" banner; CTA disabled; past-event archive view (read-only agenda + speakers)
- `PageStatus = Archived` → 410 Gone
- Within Active window but no enabled TicketTypes → "Tickets temporarily unavailable" message

---

### Shared blocks (apply to admin setup)

#### Page Header & Breadcrumbs (admin setup editor)

| Element | Content |
|---------|---------|
| Breadcrumb | Setting › Public Pages › Event Registration Pages › {EventName} |
| Page title | {EventName} — Event Registration Page |
| Subtitle | One-sentence (e.g. "Configure the public registration page for this event") |
| Status badge row | (large) PageStatus colored dot + label / (small) Event Status badge linking to #40 |
| Right actions | [Back] [Preview Full Page] [Save & Publish OR Unpublish] [Overflow: Close Early / Archive / Reset Branding / Test Registration / Help] |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading (setup editor) | Initial fetch | Skeleton matching 8-card layout |
| Loading (public) | Initial SSR | (n/a — SSR returns HTML directly) |
| Empty (setup list — no public events) | No Events with PublicEventPage=true | Empty-state illustration + 2 CTAs (Create New Event / Configure Existing Event) |
| Error (setup) | GET fails | Error card with retry |
| Error (public) | Slug not found | 404 page with org-default redirect |
| Closed (public) | PageStatus=Closed | Banner "Registration is closed" + greyed Register button + past-event archive view |
| Capacity met (public) | confirmed >= Capacity AND NOT WaitlistEnabled | "Event is full" banner + disabled Register |
| Waitlist available (public) | confirmed >= Capacity AND WaitlistEnabled AND waitlistConfirmed < WaitlistCapacity | "Join the Waitlist" CTA replaces Register |

---

## ⑦ Substitution Guide

> Adapt the closest sibling (#172 VolunteerRegistrationPage or #173 CrowdfundingPage). Use VolunteerRegistrationPage for ROUTING/FOLDER patterns and CrowdfundingPage for WRAPPING-EXISTING-ENTITY patterns.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| **VolunteerRegistrationPage** | EventRegistrationPage | Setup-screen + public-page convention (8 cards, autosave-with-publish, custom-with-fallback slug, SSR public route) |
| **CrowdFundingPage** | EventRegistrationPage | Wraps existing entity convention (Page-lifecycle fields ADDED to existing primary entity; child entities REUSED; new handlers added under sibling business folder) |
| volunteerRegistrationPage (camel) | eventRegistrationPage | Variable / GQL field names |
| `volunteerregpage` (kebab) | `eventregpage` | URL slug |
| `setting/publicpages/volunteerregpage` | `setting/publicpages/eventregpage` | Admin route |
| `(public)/volunteer/[slug]` | `(public)/event/[slug]` | Public route |
| `VolunteerRegistrationPages` (plural) | `EventRegistrationPages` (plural — for handler folder name) | Business folder |
| schema `app` | schema `app` | Same schema |
| Group `ApplicationModels` | Group `ApplicationModels` | Same group |
| MenuCode `VOLUNTEERREGPAGE` (OrderBy=5) | MenuCode `EVENTREGPAGE` (OrderBy=6) | Sibling under SET_PUBLICPAGES |
| Parent entity `Volunteer` (#53) | Parent entity `Event` (#23/#40) | Submissions create rows in this entity |
| Anonymous submit creates `app.Volunteers` row | Anonymous submit creates `app.EventRegistrations` row(s) | Submission sink |
| `SubmitVolunteerApplication` public mutation | `InitiateEventRegistration` + `ConfirmEventRegistration` (paid flow split) public mutations | Public submit |
| Rate-limit policy `VolunteerSubmit` | New rate-limit policy `EventRegistrationSubmit` | Add inside existing `AddRateLimiter` lambda in `Base.API/DependencyInjection.cs` |
| OG meta via `ShareTitle/Description/Image` fields (volunteer-specific) | OG meta via existing `ShareTitle/ShareDescription/ShareImageUrl` on Event entity | Reuse existing fields |
| Page-lifecycle separate from parent | Page-lifecycle (`PageStatus`) **deliberately separate** from Event-lifecycle (`EventStatusId`) | Cross-product table in §④ |

---

## ⑧ File Manifest

> Wraps existing Event entity — admin setup + public route + new handlers (no new child entities).

### Backend Files — NEW

| # | File | Path |
|---|------|------|
| 1 | EventRegistrationPage Schemas (DTOs) | `Pss2.0_Backend/.../Base.Application/Schemas/ApplicationSchemas/EventRegistrationPageSchemas.cs` (NEW) — `EventRegistrationPageSetupDto`, `EventRegistrationPageListItemDto`, `EventRegistrationPagePublicDto`, `EventRegistrationPageStatsDto`, `EventRegistrationPagePublishValidationDto`, `InitiateEventRegistrationRequestDto`, `InitiateEventRegistrationResponseDto`, `ConfirmEventRegistrationRequestDto`, `EventRegistrationCreatedDto`, `EventRegistrationPageSummaryDto` |
| 2 | GetAllEventRegistrationPagesList | `.../Base.Application/Business/ApplicationBusiness/EventRegistrationPages/Queries/GetAllEventRegistrationPages.cs` |
| 3 | GetEventRegistrationPageById | `.../EventRegistrationPages/Queries/GetEventRegistrationPageById.cs` |
| 4 | GetEventRegistrationPageBySlug (public) | `.../EventRegistrationPages/Queries/GetEventRegistrationPageBySlug.cs` (anonymous-allowed, status-gated) |
| 5 | GetEventRegistrationPageStats | `.../EventRegistrationPages/Queries/GetEventRegistrationPageStats.cs` |
| 6 | GetEventRegistrationPagePublishValidationStatus | `.../EventRegistrationPages/Queries/GetEventRegistrationPagePublishValidationStatus.cs` |
| 7 | UpdateEventRegistrationPageSetup | `.../EventRegistrationPages/Commands/UpdateEventRegistrationPageSetup.cs` |
| 8 | PublishEventRegistrationPage | `.../EventRegistrationPages/Commands/PublishEventRegistrationPage.cs` |
| 9 | UnpublishEventRegistrationPage | `.../EventRegistrationPages/Commands/UnpublishEventRegistrationPage.cs` |
| 10 | CloseEventRegistrationPage | `.../EventRegistrationPages/Commands/CloseEventRegistrationPage.cs` |
| 11 | ArchiveEventRegistrationPage | `.../EventRegistrationPages/Commands/ArchiveEventRegistrationPage.cs` |
| 12 | ResetEventRegistrationPageBranding | `.../EventRegistrationPages/Commands/ResetEventRegistrationPageBranding.cs` |
| 13 | InitiateEventRegistration (public) | `.../EventRegistrationPages/Commands/InitiateEventRegistration.cs` (anonymous-allowed, rate-limited, atomic capacity check) |
| 14 | ConfirmEventRegistration (public) | `.../EventRegistrationPages/Commands/ConfirmEventRegistration.cs` (gateway callback handler) |
| 15 | Slug Validator | `.../EventRegistrationPages/Validators/EventRegistrationPageSlugValidator.cs` |
| 16 | Admin Queries Endpoint | `Base.API/EndPoints/Application/Queries/EventRegistrationPageQueries.cs` (NEW) |
| 17 | Admin Mutations Endpoint | `Base.API/EndPoints/Application/Mutations/EventRegistrationPageMutations.cs` (NEW) |
| 18 | Public Queries Endpoint | `Base.API/EndPoints/Application/Public/EventRegistrationPagePublicQueries.cs` (NEW — anonymous-allowed) |
| 19 | Public Mutations Endpoint | `Base.API/EndPoints/Application/Public/EventRegistrationPagePublicMutations.cs` (NEW — anonymous-allowed, rate-limited) |
| 20 | EF Migration | `Pss2.0_Backend/.../Base.Infrastructure/Data/Migrations/{timestamp}_Add_EventRegistrationPage_Fields.cs` (hand-crafted; user regen Designer/Snapshot via `dotnet ef migrations add`) |

### Backend Files — MODIFY (additive only)

| # | File | What to Add |
|---|------|-------------|
| 1 | `Base.Domain/Models/ApplicationModels/Event.cs` | Add 8 new properties (PageStatus, PagePublishedAt, PageArchivedAt, Slug, PrimaryColorHex, AccentColorHex, RegistrationPageLayout, RegistrationPageRobotsIndexable). DO NOT remove or modify existing properties. |
| 2 | `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventConfiguration.cs` | Add: column length config for new strings; filtered unique index `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted` (use `HasFilter`); default values for PageStatus=`'Draft'`, RobotsIndexable=true, PrimaryColorHex=`'#2563eb'`, AccentColorHex=`'#1d4ed8'`, RegistrationPageLayout=`'centered'` |
| 3 | `Base.Application/Mappings/ApplicationMappings.cs` | Add Mapster mapping for `EventRegistrationPageSetupDto ↔ Event` (page-relevant fields only) + `EventRegistrationPagePublicDto ↔ Event` (public-safe fields only) |
| 4 | `Base.API/EndPoints/Application/Queries/EventQueries.cs` | (Optional) Add convenience GQL field `eventRegistrationPageById` if not deferred to new endpoint file |
| 5 | `Base.API/DependencyInjection.cs` | Add `EventRegistrationSubmit` rate-limit policy inside existing `AddRateLimiter` lambda (5 requests / minute / IP+slug key); register new public endpoint group `MapEventRegistrationPagePublicQueries / MapEventRegistrationPagePublicMutations` |
| 6 | `Base.API/Program.cs` (or equivalent endpoint wiring file) | Register the 4 new endpoint files (Queries / Mutations / PublicQueries / PublicMutations) |

### Backend Wiring (no changes needed)

- `IApplicationDbContext.cs` — `DbSet<Event>` already exists from #23/#40; no new DbSet needed
- `ApplicationDbContext.cs` — same; no change
- `DecoratorProperties.cs` — entity already in `DecoratorApplicationModules`; no change
- `ApplicationMappings.cs` — additive append only (see MODIFY table)

### Frontend Files — NEW

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/application-service/EventRegistrationPageDto.ts` (NEW — mirrors backend schemas: SetupDto / PublicDto / StatsDto / PublishValidationDto / Initiate Request+Response / Confirm Request+Response / CreatedDto / SummaryDto + child collection slices) |
| 2 | GraphQL Queries (admin) | `Pss2.0_Frontend/src/domain/grql/application-service/event-registration-page-queries.ts` (NEW — getAllEventRegistrationPagesList / getEventRegistrationPageById / getEventRegistrationPageStats / getEventRegistrationPagePublishValidationStatus) |
| 3 | GraphQL Queries (public) | `Pss2.0_Frontend/src/domain/grql/application-service/event-registration-page-public-queries.ts` (NEW — getEventRegistrationPageBySlug) |
| 4 | GraphQL Mutations (admin) | `Pss2.0_Frontend/src/domain/grql/application-service/event-registration-page-mutations.ts` (NEW — updateEventRegistrationPageSetup / publishEventRegistrationPage / unpublishEventRegistrationPage / closeEventRegistrationPage / archiveEventRegistrationPage / resetEventRegistrationPageBranding) |
| 5 | GraphQL Mutations (public) | `Pss2.0_Frontend/src/domain/grql/application-service/event-registration-page-public-mutations.ts` (NEW — initiateEventRegistration / confirmEventRegistration) |
| 6 | Zustand Store | `Pss2.0_Frontend/src/store/event-registration-page-store.ts` (NEW — form state for the 8 settings cards; autosave debounce; publish-validation cache; preview-toggle device state) |
| 7 | Page Config | `Pss2.0_Frontend/src/configs/page-configs/event-registration-page.config.ts` (NEW — table columns for list view + KPI tile definitions) |
| 8 | Admin Setup Route — list | `Pss2.0_Frontend/src/app/[lang]/(core)/setting/publicpages/eventregpage/page.tsx` (NEW) — replaces UnderConstruction stub if present; renders list view (Cards) when no `?id` |
| 9 | Admin Setup Route — editor | `Pss2.0_Frontend/src/app/[lang]/(core)/setting/publicpages/eventregpage/[id]/page.tsx` (NEW) — renders 8-card editor + Live Preview when `?id=N` |
| 10 | Editor: PageHeader / StatusBar | `Pss2.0_Frontend/src/features/event-registration-page/components/page-header.tsx` (NEW) — Page Status badge + Event Status link + actions |
| 11 | Editor: Card 1 PageIdentity | `Pss2.0_Frontend/src/features/event-registration-page/components/cards/page-identity-card.tsx` (NEW) |
| 12 | Editor: Card 2 EventSnapshot | `.../cards/event-snapshot-card.tsx` (NEW — read-only display + edit link to #40) |
| 13 | Editor: Card 3 TicketTypes | `.../cards/ticket-types-card.tsx` (NEW — table editor + drag reorder + early-bird column) |
| 14 | Editor: Card 4 RegistrationWindow | `.../cards/registration-window-card.tsx` (NEW) |
| 15 | Editor: Card 5 RegistrantExperience | `.../cards/registrant-experience-card.tsx` (NEW — form-fields table + custom-questions table + 3 toggles) |
| 16 | Editor: Card 6 DonationOnPage | `.../cards/donation-on-page-card.tsx` (NEW — conditional fields when AcceptDonations on) |
| 17 | Editor: Card 7 Communications | `.../cards/communications-card.tsx` (NEW — confirmation + reminder + channels + triggers table) |
| 18 | Editor: Card 8 BrandingSeo | `.../cards/branding-seo-card.tsx` (NEW — branding + SEO + social preview) |
| 19 | Editor: LivePreview pane | `.../components/live-preview.tsx` (NEW — debounced 300ms render of public composition with device-switcher) |
| 20 | Public Route — page.tsx | `Pss2.0_Frontend/src/app/[lang]/(public)/event/[slug]/page.tsx` (NEW — SSR + generateMetadata + revalidate:60) |
| 21 | Public — Hero | `Pss2.0_Frontend/src/features/event-registration-page/public/hero.tsx` (NEW) |
| 22 | Public — AboutSection | `.../public/about-section.tsx` (NEW — renders DetailedAgendaHtml sanitized) |
| 23 | Public — SpeakersSection | `.../public/speakers-section.tsx` (NEW) |
| 24 | Public — VenueSection | `.../public/venue-section.tsx` (NEW — physical OR virtual variants) |
| 25 | Public — RegistrationForm orchestrator | `.../public/registration-form.tsx` (NEW — composes TicketPicker + Quantity + RegistrantFields + CustomQuestions + DonationBlock + Submit) |
| 26 | Public — TicketPicker | `.../public/ticket-picker.tsx` (NEW — capacity / sold-out indicators per ticket type) |
| 27 | Public — RegistrantFields | `.../public/registrant-fields.tsx` (NEW — respects EventRegistrationFormFields) |
| 28 | Public — CustomQuestions | `.../public/custom-questions.tsx` (NEW — respects EventCustomQuestion rows) |
| 29 | Public — DonationBlock | `.../public/donation-block.tsx` (NEW — conditional on AcceptDonations) |
| 30 | Public — ThankYou | `.../public/thank-you.tsx` (NEW — QR token / EventRegistrationCode rendered; receipt-by-email note) |
| 31 | Public — Footer | `.../public/footer.tsx` (NEW — privacy / cancellation / contact-organizer) |

### Frontend Wiring (modify)

| # | File | What to Add |
|---|------|-------------|
| 1 | `src/domain/entities/application-service/index.ts` | Re-export EventRegistrationPageDto types |
| 2 | `src/domain/grql/application-service/index.ts` | Re-export new query / mutation barrels (admin + public) |
| 3 | `src/domain/grql/application-service/entity-operations.ts` (or equivalent registry) | Register `EVENTREGPAGE` operations block — list / byId / stats / publish / unpublish / close / archive / reset / initiate / confirm |
| 4 | `src/configs/page-configs/index.ts` | Re-export `event-registration-page.config` |
| 5 | (none other) | No global menu wiring — sidebar reads from menu seed |

### DB Seed (NEW SQL file)

| # | File | What to Seed |
|---|------|--------------|
| 1 | `DatabaseScripts/.claude-screen-tracker-prompts/event-reg-page-sqlscripts.sql` (NEW) | (a) Menu `EVENTREGPAGE` under `SET_PUBLICPAGES` OrderBy=6 + 9 MenuCapabilities (READ/CREATE/MODIFY/DELETE/PUBLISH/UNPUBLISH/CLOSE/ARCHIVE/ISMENURENDER) + BUSINESSADMIN role grants. (b) Grid `EVENTREGPAGE` GridType=`EXTERNAL_PAGE` GridFormSchema=NULL. (c) MasterDataType `EVENTREGISTRATIONSTATUS` + 5 rows (Confirmed / PendingPayment / Cancelled / Refunded / Waitlisted) IF NOT EXISTS. (d) UPDATE existing E2E sample Event (e.g. "Annual Charity Gala 2026") setting `PublicEventPage=true`, `Slug='annual-gala-2026'`, `PageStatus='Active'`, `PagePublishedAt=now`, `PrimaryColorHex='#2563eb'` for E2E QA. |

### EF Migration

| # | File | Operations |
|---|------|------------|
| 1 | `{timestamp}_Add_EventRegistrationPage_Fields.cs` | ADD COLUMN PageStatus VARCHAR(20) NOT NULL DEFAULT 'Draft' / PagePublishedAt TIMESTAMPTZ NULL / PageArchivedAt TIMESTAMPTZ NULL / Slug VARCHAR(100) NULL (then UPDATE Slug = LOWER(REPLACE(EventName,' ','-')) WHERE Slug IS NULL AND PublicEventPage=true; ALTER COLUMN Slug SET NOT NULL after backfill) / PrimaryColorHex VARCHAR(7) NULL / AccentColorHex VARCHAR(7) NULL / RegistrationPageLayout VARCHAR(30) NULL / RegistrationPageRobotsIndexable BOOL NOT NULL DEFAULT TRUE. Create filtered unique index `IX_Events_CompanyId_Slug` ON `app.Events (CompanyId, LOWER(Slug)) WHERE NOT IsDeleted`. Down() reverses. |

---

## ⑨ Approval Config

> Pre-filled from `MODULE_MENU_REFERENCE.md` SET_PUBLICPAGES section (MenuId 369, OrderBy=6).

```yaml
menu:
  MenuCode: EVENTREGPAGE
  MenuName: Event Registration Page
  MenuUrl: setting/publicpages/eventregpage
  ParentMenuCode: SET_PUBLICPAGES
  ModuleCode: SETTING
  OrderBy: 6
  IsLeastMenu: true
  IconClass: 'ph:ticket'  # or 'ph:calendar-plus' — UX architect to confirm

capabilities:
  - { CapabilityCode: READ,        CapabilityName: 'View Event Registration Page' }
  - { CapabilityCode: CREATE,      CapabilityName: 'Configure new Event Page' }
  - { CapabilityCode: MODIFY,      CapabilityName: 'Edit Event Registration Page' }
  - { CapabilityCode: DELETE,      CapabilityName: 'Delete Event Page' }
  - { CapabilityCode: PUBLISH,     CapabilityName: 'Publish Event Registration Page' }
  - { CapabilityCode: UNPUBLISH,   CapabilityName: 'Unpublish Event Registration Page' }
  - { CapabilityCode: CLOSE,       CapabilityName: 'Close Event Registration Early' }
  - { CapabilityCode: ARCHIVE,     CapabilityName: 'Archive Event Registration Page' }
  - { CapabilityCode: ISMENURENDER, CapabilityName: 'Show in sidebar' }

role_grants:
  BUSINESSADMIN:
    - READ
    - CREATE
    - MODIFY
    - DELETE
    - PUBLISH
    - UNPUBLISH
    - CLOSE
    - ARCHIVE
    - ISMENURENDER

grid:
  GridCode: EVENTREGPAGE
  GridName: Event Registration Pages
  GridType: EXTERNAL_PAGE        # NOT MASTER_GRID / FLOW
  GridFormSchema: NULL           # SKIP — EXTERNAL_PAGE owns its own UI; no RJSF generation
```

> No re-prompting required — `BUSINESSADMIN` only (per memory `feedback_build_directives.md`).

---

## ⑩ BE → FE Contract

> Pre-defined GraphQL types & DTO fields — FE Dev must match exactly.

### GraphQL Queries

| GQL Field | Args | Response Type | Visibility |
|-----------|------|---------------|------------|
| `getAllEventRegistrationPagesList` | `Filter` (status?, eventStatus?, dateRange?), `Pagination`, `Sort` | `EventRegistrationPageListResponseDto` (items[], totalCount) | admin |
| `getEventRegistrationPageById` | `id: ID!` | `EventRegistrationPageSetupDto` | admin |
| `getEventRegistrationPageBySlug` | `slug: String!` | `EventRegistrationPagePublicDto` | **public anonymous** |
| `getEventRegistrationPageStats` | `eventId: ID!` | `EventRegistrationPageStatsDto` | admin |
| `getEventRegistrationPagePublishValidationStatus` | `eventId: ID!` | `EventRegistrationPagePublishValidationDto` | admin |
| `getEventRegistrationPageSummary` | (none) | `EventRegistrationPageSummaryDto` (totals across tenant — KPI tiles) | admin |

### GraphQL Mutations

| GQL Field | Args | Response Type | Visibility |
|-----------|------|---------------|------------|
| `updateEventRegistrationPageSetup` | `id: ID!, input: EventRegistrationPageSetupInput!` | `Boolean` | admin |
| `publishEventRegistrationPage` | `id: ID!` | `EventRegistrationPagePublishResultDto` (success / missingFields[]) | admin |
| `unpublishEventRegistrationPage` | `id: ID!` | `Boolean` | admin |
| `closeEventRegistrationPage` | `id: ID!, reason: String?` | `Boolean` | admin |
| `archiveEventRegistrationPage` | `id: ID!` | `Boolean` | admin |
| `resetEventRegistrationPageBranding` | `id: ID!` | `Boolean` | admin |
| `initiateEventRegistration` | `input: InitiateEventRegistrationInput!` | `InitiateEventRegistrationResponseDto` (registrationCode, paymentSessionId?, redirectUrl?, qrToken?, status) | **public anonymous, rate-limited** |
| `confirmEventRegistration` | `input: ConfirmEventRegistrationInput!` | `EventRegistrationConfirmedDto` (registrationCode, qrToken, status) | **public anonymous (gateway-signed)** |

### Key DTO field lists

#### `EventRegistrationPageSetupDto` (admin editor — what `getEventRegistrationPageById` returns)

```ts
type EventRegistrationPageSetupDto = {
  eventId: number;
  eventName: string;                  // read-only display (from Event.EventName)
  eventCode: string;                  // read-only
  pageStatus: 'Draft' | 'Published' | 'Active' | 'Closed' | 'Archived';
  pagePublishedAt: string | null;     // ISO UTC
  pageArchivedAt: string | null;
  slug: string;
  // Event-snapshot read-only fields:
  startDate: string;
  endDate: string | null;
  timezoneId: number | null;
  eventModeId: number;
  eventCategoryId: number;
  eventStatusId: number;              // (separate from pageStatus — see §④)
  venueName: string | null;
  venueAddress: string | null;
  virtualPlatform: string | null;
  cancellationReason: string | null;
  postponedToDate: string | null;
  // Registration window:
  registrationRequired: boolean | null;
  registrationOpenDate: string | null;
  registrationEndDate: string | null;
  earlyBirdDeadline: string | null;
  capacity: number | null;
  waitlistEnabled: boolean | null;
  waitlistCapacity: number | null;
  // Page content:
  bannerImageUrl: string | null;
  detailedAgendaHtml: string | null;
  eventHighlights: string | null;
  // Registrant experience:
  showCountdown: boolean | null;
  qrCheckinEnabled: boolean | null;
  postEventSurveyEnabled: boolean | null;
  // Donation on page:
  acceptDonations: boolean | null;
  linkedDonationPurposeId: number | null;
  showFundraisingGoal: boolean | null;
  goalAmount: number | null;
  // Communications:
  sendConfirmationEmail: boolean | null;
  confirmationTemplateId: number | null;
  sendReminder: boolean | null;
  reminderTimingCode: string | null;
  reminderChannelEmail: boolean | null;
  reminderChannelWhatsApp: boolean | null;
  reminderChannelSms: boolean | null;
  sendLinkTimingCode: string | null;
  // Branding & SEO:
  primaryColorHex: string;            // default '#2563eb'
  accentColorHex: string;             // default '#1d4ed8'
  registrationPageLayout: string;     // 'centered' | 'side-by-side' | 'full-width'
  shareTitle: string | null;
  shareDescription: string | null;
  shareImageUrl: string | null;
  registrationPageRobotsIndexable: boolean;
  // Child collections (projected with parent):
  ticketTypes: EventTicketTypeDto[];
  registrationFormFields: EventRegistrationFormFieldDto[];
  customQuestions: EventCustomQuestionDto[];
  suggestedAmounts: EventSuggestedAmountDto[];
  communicationTriggers: EventCommunicationTriggerDto[];
  speakers: EventSpeakerDto[];
  galleryPhotos: EventGalleryPhotoDto[];
};
```

#### `EventRegistrationPagePublicDto` (public route — what `getEventRegistrationPageBySlug` returns)

> **Same as Setup DTO MINUS sensitive/internal fields** — never expose: VirtualMeetingId, VirtualMeetingPassword, ConfirmationTemplateId, AdminNotificationEmail, anti-fraud markers. Add computed fields:

```ts
type EventRegistrationPagePublicDto = EventRegistrationPageSetupDto & {
  capacityUsed: number;               // SUM(Quantity) WHERE StatusId=Confirmed
  capacityUsedPct: number;
  waitlistUsed: number;
  isCapacityMet: boolean;
  isWaitlistAvailable: boolean;
  ticketTypesWithAvailability: Array<EventTicketTypeDto & { soldCount: number; isSoldOut: boolean }>;
  isRegistrationOpen: boolean;        // computed: PageStatus=Active AND now BETWEEN RegOpenDate AND RegEndDate
  effectiveStatus: 'Live' | 'PreOpen' | 'Closed' | 'CancelledEvent' | 'PostponedEvent' | 'WaitlistOnly' | 'Full';
};
```

#### `EventRegistrationPageStatsDto`

```ts
type EventRegistrationPageStatsDto = {
  totalRegistrations: number;
  confirmedCount: number;
  pendingPaymentCount: number;
  waitlistCount: number;
  cancelledCount: number;
  totalRevenue: number;
  totalDonations: number;             // from fund.GlobalDonations linked by EventId
  capacityUsedPct: number;
  lastRegistrationAt: string | null;
  recentRegistrations: Array<{ name: string; quantity: number; ticketType: string; registeredAt: string }>;
};
```

#### `EventRegistrationPagePublishValidationDto`

```ts
type EventRegistrationPagePublishValidationDto = {
  canPublish: boolean;
  missingFields: Array<{ field: string; code: string; message: string }>;
  warnings: Array<{ field: string; code: string; message: string }>;
};
```

#### `InitiateEventRegistrationInput` (public anonymous)

```ts
type InitiateEventRegistrationInput = {
  slug: string;
  ticketTypeId: number;
  quantity: number;
  // Per EventRegistrationFormFields config:
  firstName: string;
  lastName: string;
  email: string;
  phone?: string;
  organization?: string;
  dietaryRequirements?: string;
  accessibilityNeeds?: string;
  tshirtSize?: string;
  emergencyContact?: string;
  // Custom-question answers:
  customAnswers?: Array<{ questionId: number; answer: string }>;
  // Optional donation:
  donationAmount?: number;
  donationPurposeId?: number;
  // Anti-fraud + idempotency:
  csrfToken: string;
  honeypot?: string;
  idempotencyKey: string;
  recaptchaToken?: string;
};
```

#### `InitiateEventRegistrationResponseDto`

```ts
type InitiateEventRegistrationResponseDto = {
  registrationCode: string;            // e.g. 'EVT-2026-A4B8X2'
  // For free flow:
  status: 'Confirmed' | 'PendingPayment' | 'Waitlisted';
  qrToken?: string;                    // present if QrCheckinEnabled and Confirmed
  thankYouMessage?: string;
  // For paid flow:
  paymentSessionId?: string;           // SERVICE_PLACEHOLDER mock until gateway connect
  redirectUrl?: string;
  totalAmount: number;
};
```

---

## ⑪ Acceptance Criteria

> Generated from field list + business rules + lifecycle. Build-Test agent should map each line to a test.

### Schema / Storage

- [ ] Event.PageStatus column exists, NOT NULL, default `'Draft'`, length 20, enum-checked at app layer
- [ ] Event.PagePublishedAt / PageArchivedAt columns nullable TIMESTAMPTZ
- [ ] Event.Slug column NOT NULL, length 100, populated for all existing rows where `PublicEventPage=true` via backfill in migration Up()
- [ ] Event.PrimaryColorHex / AccentColorHex columns length 7 with defaults applied
- [ ] Event.RegistrationPageLayout column length 30, default `'centered'`
- [ ] Event.RegistrationPageRobotsIndexable column NOT NULL, default TRUE
- [ ] Filtered unique index `IX_Events_CompanyId_Slug` on `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted` exists
- [ ] EF Migration Down() reverses cleanly (drop index + columns)

### Admin Setup — list

- [ ] `/setting/publicpages/eventregpage` renders KPI tiles (Active Pages / Total Registrations / Capacity Used % / Revenue) sourced from `getEventRegistrationPageSummary`
- [ ] Card grid filters Events to `PublicEventPage=true OR Slug IS NOT NULL`
- [ ] Each card shows banner thumb + EventName + StartDate + Venue + PageStatus badge + EventStatusId badge + `{confirmedCount}/{capacity} regs` + totalRevenue chip
- [ ] Filters: PageStatus dropdown / EventStatusId dropdown / Date range / Search
- [ ] Click card → routes to `/setting/publicpages/eventregpage/{id}`
- [ ] "+ Configure New Page" → modal picker of Events with `PublicEventPage=false` to enable, OR redirects to #40 Event create form
- [ ] Empty state renders when no events have a page

### Admin Setup — editor (8 cards)

- [ ] Initial fetch loads `getEventRegistrationPageById` + `getEventRegistrationPageStats`; Skeleton during load
- [ ] Page Status Bar shows colored dot + label per PageStatus; Event Status badge below
- [ ] Card 1 — Page Identity: EventName read-only; Slug editable with auto-from-EventName button + URL preview + copy
- [ ] Card 2 — Event Snapshot: all fields read-only; "Edit Event details →" link navigates to #40
- [ ] Card 3 — Ticket Types: table editor with add / edit / delete / drag-reorder; Price column right-aligned
- [ ] Card 4 — Registration Window: WaitlistCapacity visible only when WaitlistEnabled=true
- [ ] Card 5 — Registrant Experience: FirstName + Email rows disabled (required+visible+locked); "+ Add Custom Field" opens EventCustomQuestion modal
- [ ] Card 6 — Donation On Page: SuggestedAmounts / GoalAmount visible only when AcceptDonations=true; ShowFundraisingGoal toggle gates GoalAmount visibility
- [ ] Card 7 — Communications: ConfirmationTemplate dropdown required when SendConfirmationEmail=true; channel toggles visible only when SendReminder=true; SendLinkTimingCode visible only when EventModeId=Online/Hybrid
- [ ] Card 8 — Branding & SEO: BannerImageUrl upload; color pickers default to brand blue; social-preview card live-updates
- [ ] Autosave on edit (300ms debounce); inline "Saved" indicator
- [ ] Live Preview pane updates within 300ms of edit
- [ ] Device-switcher (Desktop / Mobile) changes preview viewport
- [ ] Preview-token banner renders on Draft preview
- [ ] "Save & Publish" runs `getEventRegistrationPagePublishValidationStatus`; on `canPublish=false` shows modal with missingFields list; on success calls `publishEventRegistrationPage` and transitions PageStatus
- [ ] Unpublish / Close Early / Archive / Reset Branding actions present per state with appropriate confirmations

### Public Page

- [ ] `(public)/event/[slug]/page.tsx` resolves slug → Event via `getEventRegistrationPageBySlug`; 404 if not found
- [ ] `generateMetadata` returns correct OG title / description / image / robots tags
- [ ] PageStatus=Draft (no preview-token) → 404
- [ ] PageStatus=Published (pre-RegOpenDate) → banner "Registration opens {date}" + CTA disabled
- [ ] PageStatus=Active + EventStatusId=Cancelled → red banner + CTA disabled
- [ ] PageStatus=Active + EventStatusId=Postponed → amber banner + CTA active
- [ ] PageStatus=Active + capacity met + WaitlistEnabled → CTA reads "Join Waitlist"
- [ ] PageStatus=Active + capacity met + NOT WaitlistEnabled → "Event is full" banner + CTA disabled
- [ ] PageStatus=Closed → "Registration is closed" banner + CTA disabled + read-only archive view
- [ ] PageStatus=Archived → 410 Gone HTTP response
- [ ] Hero shows banner image full-bleed (or category gradient if missing) + EventName + date + venue + optional countdown
- [ ] Speakers / Venue / About / Custom-Questions sections render in defined order
- [ ] Ticket picker shows each EventTicketType with price + early-bird (if before deadline) + capacity / sold-out badge
- [ ] Quantity selector enforces 1..(remaining capacity for selected ticket)
- [ ] Registrant fields respect EventRegistrationFormField config (visible / required)
- [ ] Custom questions respect EventCustomQuestion config
- [ ] Donation block shows only when AcceptDonations=true; toggle expands chip-editor + custom amount
- [ ] CTA button label: "Register Now" (free) or "Register Now ${totalAmount}" (paid)
- [ ] CTA color = PrimaryColorHex
- [ ] Footer: privacy / cancellation / contact-organizer / "© tenant" / "Powered by..."
- [ ] CSP headers set on response
- [ ] CSRF token issued + required on submit
- [ ] Honeypot field hidden in form
- [ ] Rate-limit policy `EventRegistrationSubmit` enforces 5/min/IP+slug

### Public Submit Flow

- [ ] Free ticket → `initiateEventRegistration` creates EventRegistration row with StatusId=Confirmed + EventRegistrationCode + (if QrCheckinEnabled) QRCodeToken; thank-you state renders with QR token (or text code) + receipt email fires
- [ ] Paid ticket → `initiateEventRegistration` creates EventRegistration row with StatusId=PendingPayment + paymentSessionId returned; FE redirects to gateway iframe (SERVICE_PLACEHOLDER mock)
- [ ] Gateway callback → `confirmEventRegistration` flips Status PendingPayment→Confirmed; emits QR + email
- [ ] Atomic capacity check: 2 concurrent submits attempting the same last seat → exactly 1 succeeds (Confirmed) and 1 gets Waitlisted (if waitlist) or 409 CAPACITY_REACHED (if not)
- [ ] Per-ticket-type capacity enforced independently from event-level capacity
- [ ] Idempotency: re-posting same idempotencyKey returns same intent response without creating duplicate row
- [ ] Honeypot non-empty → silent mock-success
- [ ] Rate-limit triggered → 429 with retry-after
- [ ] Cross-tenant slug isolation: same slug across two tenants returns each tenant's own page; no cross-leak

### DB Seed

- [ ] Menu `EVENTREGPAGE` seeded under `SET_PUBLICPAGES` OrderBy=6
- [ ] 9 capabilities seeded; BUSINESSADMIN role granted all
- [ ] Grid `EVENTREGPAGE` GridType=`EXTERNAL_PAGE` seeded
- [ ] MasterDataType `EVENTREGISTRATIONSTATUS` + 5 rows seeded IF NOT EXISTS
- [ ] Sample Event updated with `PublicEventPage=true / Slug='annual-gala-2026' / PageStatus='Active'` for E2E QA at `/event/annual-gala-2026`
- [ ] Seed is idempotent (re-runnable without errors)

### Stats & Aggregation

- [ ] `getEventRegistrationPageStats` returns correct counts in <100ms for an event with 1000 registrations
- [ ] Recent-registrations widget cached server-side 60s
- [ ] capacityUsedPct correctly derived as `confirmed × 100 / capacity` (handles divide-by-zero when Capacity=0)

### Build / Type Safety

- [ ] `dotnet build` passes 0 errors, 0 NEW warnings
- [ ] `pnpm tsc` passes 0 errors
- [ ] FE generated GQL types match BE DTOs (verify with `pnpm generate-graphql-types`)

---

## ⑫ Special Notes & Open Issues

### General

- **DEPENDENCY**: Requires #23 / #40 Event (COMPLETED ALIGN) to be intact. Migration ADDS columns — never modifies existing column types. If #23/#40 is reverted/refactored, this screen's migration may conflict.
- **ORTHOGONAL STATUSES**: PageStatus (new) and EventStatusId (existing) are independent state machines. Treat as such. State-cross-product table in §④ is authoritative.
- **SERVICE_PLACEHOLDER inventory** (8 items):
  1. Payment-gateway hand-off for paid tickets — `paymentSessionId` is mocked until `fund.CompanyPaymentGateways` connect is wired
  2. QR code IMAGE generation — token storage is real; PNG/SVG rendering is placeholder (existing library `QRCoder` or similar may already be available; verify at build)
  3. Confirmation email send (SendConfirmationEmail flow) — depends on the notify email pipeline
  4. Reminder email scheduling — pre-event reminder scheduler not in scope
  5. SMS reminder dispatch — depends on SMS Setup #157 connect
  6. WhatsApp reminder dispatch — depends on WhatsApp Setup
  7. reCAPTCHA v3 score check
  8. Post-event survey send — relies on survey infrastructure not yet built

### ISSUES (capture during build for `/continue-screen` resolution)

- **ISSUE-1**: Mockup TBD — §⑥ blueprint assumed from siblings + `event-form.html` Registration + Settings tabs. **Must validate with user at /build-screen entry.** Likely candidate for user to supply actual HTML mockup at `html_mockup_screens/screens/settings/event-reg-page.html` before BUILD scope=FULL.
- **ISSUE-2**: Slug migration of existing `CustomUrl` values into new `Slug` column needs careful handling — `CustomUrl` may contain a full URL (e.g. `events.hopefoundation.org/gala-2026`) not just a slug. Migration Up() should: (a) attempt to extract slug from CustomUrl by taking everything after the last `/`; (b) fall back to LOWER(REPLACE(EventName, ' ', '-')); (c) deduplicate where collisions occur within a tenant by appending `-2`, `-3`, etc. Test with sample data before running prod migration.
- **ISSUE-3**: NotificationTemplate vs EmailTemplate — `ConfirmationTemplateId` FK on existing Event currently points to one of these — verify at build via Grep before generating ApiSelect query name.
- **ISSUE-4**: EventRegistrationStatus MasterDataType — verify whether #137 EventTicketing build has already seeded this. If not, seed in step (c) of DB seed script.
- **ISSUE-5**: Capacity check at parent-event level vs per-TicketType level — both must be enforced. Decide BE-side: per-TicketType counter columns OR query on each submit. Recommend per-TicketType `SoldCount` column update inside the transaction (denormalized for read performance) with periodic reconciliation.
- **ISSUE-6**: Donation-on-page parallel charge — if registrant adds donation to paid ticket submit, must we charge ONCE (bundled in gateway intent) or TWICE (separate transactions)? Recommend ONCE for UX; flag for gateway-integration session. SERVICE_PLACEHOLDER may bundle by simply summing into TotalAmount on the registration; real gateway flow needs an explicit InitiateBundledTransaction.
- **ISSUE-7**: PageStatus auto-flip scheduler — Active→Closed when RegistrationEndDate passes requires either a background scheduler or just-in-time check on every public-page render. Recommend just-in-time (check on every `getEventRegistrationPageBySlug`); avoids scheduler dependency.
- **ISSUE-8**: PreviewToken implementation — Draft-state preview-token query param needs a server-side signed JWT or simple HMAC; reuse pattern from #172 / #173 if implemented there; otherwise add a small `PreviewTokenService` shared utility.
- **ISSUE-9**: Sidebar menu icon — `ph:ticket` vs `ph:calendar-plus` — UX architect to confirm at /build-screen entry. Sibling #170 P2PCampaignPage uses `ph:users-three`, #172 uses `ph:hand-heart`, #173 uses `ph:rocket-launch`.
- **ISSUE-10**: Cancellation policy / refund flow — out of scope for #169 (handled in #137 EventTicketing); but the public page footer MUST link to a Cancellation Policy URL. Add a `CancellationPolicyUrl` to Event entity? Defer — for now show static org-default policy.
- **ISSUE-11**: Multi-attendee submit (Quantity > 1) — current InitiateEventRegistrationInput captures single-registrant details. For Quantity > 1, the public form needs additional per-attendee field collection (Name/Email per ticket beyond the primary registrant). Decide at build time: (a) primary-only model (one set of fields, Quantity is just a count, no per-attendee data — simplest but loses per-attendee tracking) vs (b) per-attendee fields (form expands to show N field-sets, each with at minimum Name/Email). Recommend (a) for V1 with note for V2.
- **ISSUE-12**: Hybrid event mode — physical + online attendees may need different ticket types or different form fields. Defer; for V1 admin can create separate ticket types like "In-Person VIP" and "Virtual VIP" and use a "Attendance Mode" custom question. V2 could add a first-class attendance-mode picker.

### ALIGN scope (when re-running on existing code)

This screen is `NEW` scope by default (no existing FE / no existing handlers). However, when re-run later in `ALIGN` scope:
- Read existing Event entity for any new fields added since this plan
- Read existing EventCustomQuestion + EventTicketType configurations for any drift
- Diff §⑥ blueprint vs actual rendered UI; log gaps as ISSUEs
- Do NOT re-create files; only modify what diverges from mockup

### Cross-screen dependencies (FK / shared infra)

- `app.Events` (existing — #23/#40 COMPLETED)
- `app.EventTicketTypes`, `EventRegistrationFormFields`, `EventCustomQuestions`, `EventSuggestedAmounts`, `EventCommunicationTriggers`, `EventSpeakers`, `EventGalleryPhotos` (existing — #23/#40)
- `app.EventRegistrations` (existing — receives public submits)
- `fund.GlobalDonations` (existing — receives donation-on-page rows when AcceptDonations=true)
- `notify.NotificationTemplates` / `EmailTemplates` (existing)
- `sett.MasterData` (existing — EVENTREGISTRATIONSTATUS, EVENTSTATUS, EVENTMODE, EVENTCATEGORY)
- `corg.OrganizationalUnits`, `crm.Contacts` (existing)
- Rate-limit middleware in `Base.API/DependencyInjection.cs` (existing — append new policy)

### Build hints (for /build-screen)

- Recommended scope split: **Session 1 BE_ONLY** (BE handlers + endpoints + migration + seed + dotnet build PASS) → **Session 2 FE_ONLY** (admin shell + public SSR + GQL wiring + pnpm tsc PASS). Mirrors #172 + #173 precedents.
- BE complexity: Medium-High — 14 new handler files + 4 endpoint files + migration with backfill + 8 new entity fields + 1 unique index. Standard cap 1.0h dev / 1.5h test applies.
- FE complexity: High — 23 new components + 5 GQL barrel files + 8-card editor + Live Preview + Public SSR with hardening (CSRF/honeypot/rate-limit awareness in client) + ticket-aware capacity rendering. **Risk of exceeding standard 1.0h/1.5h cap** — flag to user at Session 2 entry; consider sub-batch by surface (admin first, public next) if running long.

---

## ⑬ Build Log

> Portable handoff record. Every `/build-screen` or `/continue-screen` session appends ONE `### Session N` entry below. `/continue-screen` reads this section to resume in a fresh chat. Never edit prior sessions' entries — only append.

### § Known Issues table

| ID | Status | Description | Opened (session) | Closed (session) |
|---|---|---|---|---|
| ISSUE-1 | OPEN | Mockup TBD — §⑥ blueprint derived from #172 + event-form.html. Session 1 proceeded under user direction to reference #173 instead. Validate FE layout against §⑥ at Session 2 entry OR supply actual mockup. | plan | — |
| ISSUE-2 | OPEN | `CustomUrl` → `Slug` migration backfill: Session 1 migration uses `EventName`-derived slug (not `CustomUrl` extract). Existing `CustomUrl` values are preserved (unmodified). If `CustomUrl` contained slug-shaped values we want to migrate, run a one-off backfill SQL post-deploy. | plan | — |
| ISSUE-3 | CLOSED | NotificationTemplate vs EmailTemplate — `Event.ConfirmationTemplate` navigation confirmed as `NotificationTemplate` (Event.cs line 102). | plan | 1 |
| ISSUE-4 | CLOSED | EVENTREGISTRATIONSTATUS MasterDataType — seeded by Session 1 DB seed (5 rows: Confirmed / PendingPayment / Cancelled / Refunded / Waitlisted, idempotent guards). | plan | 1 |
| ISSUE-5 | OPEN | Per-TicketType capacity enforcement — Session 1's InitiateEventRegistration enforces parent-event capacity. Per-TicketType `SoldCount` returns 0 (see NEW-ISSUE-13). | plan | — |
| ISSUE-6 | OPEN | Donation-on-page parallel charge — V1 SERVICE_PLACEHOLDER (log only); real gateway bundling deferred. | plan | — |
| ISSUE-7 | CLOSED | PageStatus auto-flip scheduler — Session 1 implemented just-in-time effective-status flip inside `GetEventRegistrationPageBySlug` (`effectiveStatus='Closed'` when Active+RegEndDate<utcNow, no stored mutation). | plan | 1 |
| ISSUE-8 | OPEN | PreviewToken implementation — Session 1 accepts any non-empty token (SERVICE_PLACEHOLDER); proper signed-JWT / HMAC deferred. | plan | — |
| ISSUE-9 | CLOSED | Sidebar icon — `ph:ticket` chosen by user (Phase 2 approval). Applied in DB seed Menu row + prompt frontmatter. | plan | 1 |
| ISSUE-10 | OPEN | Cancellation policy / refund flow — out of scope for #169; FE footer should link to a Cancellation Policy URL (deferred to FE Session 2). | plan | — |
| ISSUE-11 | CLOSED | Quantity > 1 form UX — V1 primary-only chosen by user (Phase 2 approval). Server creates N EventRegistration rows sharing single registrant block. `// TODO V2: per-attendee fields` marker placed in InitiateEventRegistration row-creation loop. | plan | 1 |
| ISSUE-12 | OPEN | Hybrid event mode (physical + online) — deferred to V2. | plan | — |
| ISSUE-13 | OPEN | Per-TicketType `SoldCount` requires `EventRegistration → EventTicket → EventTicketType` linkage; V1 returns 0 (SERVICE_PLACEHOLDER in `GetEventRegistrationPageBySlug` + `InitiateEventRegistration` uses sentinel `EventTicketId=0`). Future fix: denormalised `EventTicketTypeId` column on `EventRegistration` OR EventTicket-per-registrant creation in #137 EventTicketing path. | 1 | — |
| ISSUE-14 | OPEN | `fund.GlobalDonation` has no `EventId` FK → `totalDonations` aggregate returns 0 with SERVICE_PLACEHOLDER. Future fix: denormalised `EventId` on `GlobalDonation` OR junction `app.EventDonations` (parallel to `fund.CrowdFundDonations`). | 1 | — |
| ISSUE-15 | OPEN | EF Migration `20260513120000_Add_EventRegistrationPage_Fields.cs` is hand-crafted — user must run `dotnet ef migrations add Add_EventRegistrationPage_Fields --project Base.Infrastructure --startup-project Base.API` to regen Designer/Snapshot, OR keep as-is and run `dotnet ef database update` directly to apply. | 1 | — |
| ISSUE-16 | OPEN | FE Child-collection DTO type names in `EventRegistrationPageDto.ts` were prefixed `Erp*` (`ErpTicketTypeDto`, `ErpRegistrationFormFieldDto`, `ErpCustomQuestionDto`, `ErpSuggestedAmountDto`, `ErpCommunicationTriggerDto`, `ErpSpeakerDto`, `ErpGalleryPhotoDto`, `ErpTicketTypeWithAvailabilityDto`) to resolve TS2308 namespace collisions with structurally-different identically-named types in `contact-service/EventDto.ts`. Functional behaviour unchanged; the prefix is purely TS naming hygiene. | 2 | — |
| ISSUE-17 | OPEN | FE path deviation from §⑧ — components were placed under `src/presentation/components/page-components/setting/publicpages/eventregpage/` + `…public/eventregpage/` (matching sibling repo convention) instead of §⑧'s `src/features/event-registration-page/` (the `features/` folder doesn't exist in this repo). GQL barrels live in `src/infrastructure/gql-queries/` and `src/infrastructure/gql-mutations/` (matching sibling convention) instead of §⑧'s `src/domain/grql/application-service/`. Admin route is `src/app/[lang]/setting/publicpages/eventregpage/page.tsx` (single file dispatching list-vs-editor based on `?id` query param) instead of §⑧'s separate `(core)/.../[id]/page.tsx` (no `(core)` group exists in this repo). All deviations match #172 + #173 sibling precedent. | 2 | — |
| ISSUE-18 | OPEN | FE Cancellation Policy footer link hardcoded to `/cancellation-policy` with V2 TODO comment (per ISSUE-10 deferral). Should become org-configurable via tenant settings in V2. | 2 | — |
| ISSUE-19 | OPEN | Custom-question type badge shows blank for persisted questions. Session 3 aliased FE `questionType` → BE `questionTypeCode`, but the `GetEventRegistrationPageById` / `…BySlug` handlers load `EventCustomQuestions` without `.Include(q => q.QuestionType)`, and Mapster doesn't flatten `QuestionType.DataValue` → `QuestionTypeCode`. So the code is null until the BE projection is enhanced to populate it (cosmetic only; custom questions are read-only in this editor and don't round-trip via `toSetupInput`). | 3 | — |
| ISSUE-20 | OPEN | FE child-DTO contract drift was never tsc-catchable. `EventRegistrationPageDto.ts` declares `ErpCommunicationTriggerDto.channel: string`, but the BE `EventCommunicationTriggerResponseDto` has no single `channel` field (only `channelEmail`/`channelWhatsApp`/`channelSms` booleans). Session 3 dropped the unused `channel` selection from the admin query. If a future card needs per-channel display, select the three booleans (and update the FE DTO). | 3 | — |
| ISSUE-21 | OPEN | **Wave-2 re-plan (§⓪).** Overlap reconciliation LOCKED: `EnableAttendance` supersedes `QrCheckinEnabled`; `EnableFeedbackCollection` supersedes `PostEventSurveyEnabled` (both dropped). If product later wants QR check-in live before the full Attendance feature ships, re-introduce a narrow `QrCheckinEnabled` rather than un-gating the Coming-Soon flag. | re-plan | — |
| ISSUE-22 | OPEN | **Wave-2 re-plan (§⓪).** Dropping `AcceptDonations`/`LinkedDonationPurposeId`/`ShowFundraisingGoal`/`GoalAmount`/`RegistrationPageLayout`/`QrCheckinEnabled`/`PostEventSurveyEnabled` requires an EF migration + data backfill (RegistrationPageLayout→PageTemplateId) BEFORE the column drops. User runs the migration manually ([[feedback-user-creates-migrations]]). Backfill SQL must run after CreateColumn(PageTemplateId), before DropColumn(RegistrationPageLayout). | re-plan | — |
| ISSUE-23 | CLOSED (S4) | **Wave-2 re-plan (§⓪).** Donate-button URL derivation assumes ODP `ImplementationType=NAV` → `/p/{slug}`. **RESOLVED**: user locked NAV-only — editor dropdown filters to status∈{Active,Published}∧implementationType=NAV; BE derives `DonateButtonUrl="/p/{slug}"` server-side. IFRAME-mode ODPs are intentionally not offered. | re-plan→S4 | 4 |
| ISSUE-24 | CLOSED (S4) | **Wave-2 re-plan (§⓪).** Speakers/Gallery CRUD. **RESOLVED**: no standalone mutations — `Speakers`/`GalleryPhotos` arrays added to `EventRegistrationPageSetupInput`; `UpdateEventRegistrationPageSetup` reuses the `UpsertSpeakers`/`UpsertGalleryPhotos` diff-upsert from `UpdateEvent.cs`. Single global Save persists children. | re-plan→S4 | 4 |
| ISSUE-26 | OPEN | **(S7).** `datetime-local` registration-window inputs (`cards/4-registration-window-card.tsx`) are not org-timezone-aware — display uses UTC wall-clock (`toISOString().slice(0,16)`), parse interprets browser-local. Left as-is because the sibling Event form (`venue-schedule-tab.tsx`) that owns the same dates behaves identically; a fix needs a shared zoned datetime-local helper (`fromZonedTime`/`formatInTimeZone`) applied to BOTH screens to avoid divergence. | 7 | — |
| ISSUE-27 | OPEN | **(S7).** Admin currency displays render the org **ISO code** (e.g. `USD 1,234`) rather than a currency symbol — `formatCurrency` defaults to the code because the CompanySettings session store carries no symbol. Symbol display would require wiring the `useCompanyCurrency()` GraphQL hook (fetches symbol via `CURRENCY_BY_ID_QUERY`) at each money call site. Matches the established admin convention (`donation-summary.tsx`). | 7 | — |
| ISSUE-25 | OPEN | **Wave-2 (S4).** Code + entity are ahead of the DB: the add-8/drop-7-column migration is USER-owned and unrun ([[feedback-user-creates-migrations]]). Until run, the app will fail at runtime (missing columns). Migration must: AddColumn the 8 new (+3 FKs, `EnabledPaymentMethodsJson` jsonb), backfill `PageTemplateId` from old `RegistrationPageLayout` (`centered`→STANDARD), THEN DropColumn the 7 legacy. Run `EventRegistrationPage-wave2-delta.sql` for the EVENTREGPAGETEMPLATE master data first. | 4 | — |
| ISSUE-28 | OPEN | **Wave-3 (§⓪′).** Tickets email (Flow 2b) is an HTML summary — NO PDF/QR attachment. No per-registration ticket artifact exists (QR disabled). Deferred follow-up tied to #137 EventTicketing; `EmailAttachment byte[]` is ready for when the artifact is built. | re-plan(W3) | — |
| ISSUE-29 | OPEN | **Wave-3 (§⓪′).** Native `EventFeedback` form/entity DEFERRED. Flow-3 feedback email links to a configurable external `FeedbackUrl` (Google Form / Typeform). Building the native form + analytics is separate future work. | re-plan(W3) | — |
| ISSUE-30 | OPEN | **Wave-3 (§⓪′).** `ReminderSentAt`/`FeedbackSentAt` are PAGE-level dedup markers, not per-registration. A registrant who registers after the marker is stamped misses that cycle. Acceptable for v1 (feedback is post-event; reminder is a single window). Per-registration markers = future precision upgrade. | re-plan(W3) | — |
| ISSUE-31 | OPEN | **Wave-3 (§⓪′).** Pre-existing platform gap: standalone `EmailSendQueue` (`EmailSendJobId=0`, the SubmitPrayerRequest pattern) has NO DRAINER — those rows never send. Transactional event mail MUST use `IEmailTemplateService.SendEmailByTemplateKeyAsync`. Flagged so build agents don't copy the prayer pattern. (Prayer-request emails may themselves be silently undelivered — out of scope for #169.) | re-plan(W3) | — |
| ISSUE-32 | OPEN | **Wave-3 (§⓪′).** Flow-1 donor announcement: bulk `EmailSendJob`/`Segment` pipeline (preferred — tracking+opt-out) vs per-recipient `SendEmailByTemplateKeyAsync` loop (fallback — self-contained). Solution Resolver picks based on whether `Segment.RulesJson` can express donor-selection, and records the choice in the Session entry. | re-plan(W3) | — |
| ISSUE-33 | OPEN | **Wave-3 (§⓪′).** `EventCommunicationTrigger.ChannelWhatsApp`/`ChannelSms` remain SERVICE_PLACEHOLDER — only `ChannelEmail` is wired (no WhatsApp/SMS providers in codebase). | re-plan(W3) | — |
| ISSUE-34 | OPEN | **Wave-3 (§⓪′).** EmailTemplates resolve by `EmailTemplateCode`+`ModuleId`+`IsActive` ONLY — NOT tenant-scoped. One global row per code serves all tenants. Per-tenant template overrides = future follow-up. | re-plan(W3) | — |
| ISSUE-35 | OPEN | **Wave-3 (§⓪′.8b).** Job tracking: transactional Flows 2/3 SEND via `SendEmailByTemplateKeyAsync` + write a *completed* `EmailSendJob` tracking row (`IsSystem=true`); they do NOT route through `IEmailExecutorService` (its recipient providers need Contacts/Segments, registrants are arbitrary emails). Secondary option = explicit-recipient provider so the EmailSendJob row IS the send. Resolver decides + records. | re-plan(W3) | — |
| ISSUE-36 | OPEN | **Wave-3 (§⓪′.8b).** Role-based **Jobs screen** (tenant jobs `IsSystem=false` + system jobs `IsSystem=true`) is FUTURE work — this wave only adds the `notify.EmailSendJobs.IsSystem` column + writes tracking rows. The screen + role-gating are planned separately. | re-plan(W3) | — |
| ISSUE-38 | CLOSED (session 29) | **(S27) ROUTED → (S28 plan) DESIGNED → (S29) BUILT per §⓪″ Wave 4.** Registrant form-field model broken end-to-end (only first/last/email render; only Name/Email/Phone persist). Four breakages: B1 seed only `FULLNAME`+`EMAIL`; B2 GQL `fieldName: fieldLabel` feeds label where FE matches code; B3 canonical-code drift (FE PascalCase vs DB UPPERCASE; no `FULLNAME` FE equiv); B4 handler drops Organization/Dietary/Accessibility/Tshirt/Emergency + ContactCode (no columns). **Design (locked 2026-06-11):** 9 canonical PascalCase codes (`FULLNAME`→`FirstName`+`LastName`); seed all 9 on create + backfill SQL; select `fieldCode`+`fieldLabel` in both queries; add 10 `Provided*` columns to `app.EventRegistrations` (ODP `OnlineDonationStaging` parity) incl `ProvidedContactCode`; Card 5 keys off `fieldCode`; Custom Questions → Coming Soon (NEW-ISSUE-39); admin surfacing deferred (NEW-ISSUE-40). Full blueprint: §⓪″.1-.11. User-owned migration. | 27 | — |
| ISSUE-39 | OPEN (Coming Soon) | Custom-question config + `CustomAnswers[]` capture deferred to Coming Soon (Card 12). `EventCustomQuestion` stays dead config; no `EventRegistrationCustomAnswers` table. See §⓪″.7. | 28 | — |
| ISSUE-40 | OPEN | Admin surfacing of new `Provided*` registrant fields (grid/detail/export) deferred — belongs to #46/#137 registration list, not this screen. Data stored + query-ready. See §⓪″.8. | 28 | — |
| ISSUE-41 | CLOSED (session 30) | **Resolved by removing the dual-store.** Dropped the redundant `ProvidedFirstName/LastName/Email/Phone` columns — `RegistrantName` (= FirstName + LastName) / `RegistrantEmail` / `RegistrantPhone` are now the single source for name/email/phone. Only the 6 extra capture columns (`ProvidedContactCode`/`Organization`/`DietaryRequirements`/`AccessibilityNeeds`/`TshirtSize`/`EmergencyContact`) remain. | 28 | 30 |
| ISSUE-37 | OPEN | **Wave-3 (§⓪′.8b, S24).** `EmailSendQueue.ContactId` is **NOT NULL with an FK constraint**, so the child tracking-row write for a registrant who is NOT a linked Contact (arbitrary `RegistrantEmail`) fails the FK. Flow-2/3 wrap the tracking write in try/catch → the row is silently skipped but **the actual email still sends** (via `SendEmailByTemplateKeyAsync`). Net effect: rolling-parent `EmailSendJob` rows are created, but non-Contact registrants get no child receipt row (the future Jobs screen undercounts them). This is the anticipated NEW-ISSUE-35 "nullable `ContactId` on the queue" refinement — fix = make `EmailSendQueue.ContactId` nullable (user-owned migration) so every send writes a receipt uniformly. | 24 | — |

> **PLANNING NOTE (2026-06-04)**: Screen re-planned to Wave 2 via `/plan-screens #169`. Status reset COMPLETED→PROMPT_READY. The authoritative delta is **§⓪ REVISION** at the top of this file — build agents read §⓪ as the source of truth over the older §②/③/⑥/⑧/⑩/⑪. Next: `/build-screen #169` to implement Wave 2. The next build session appends "Session 4" below.
>
> **PLANNING NOTE (2026-06-08)**: Screen re-planned to **Wave 3 — Event Email Communication subsystem** via `/plan-screens #169`. Status reset COMPLETED→PROMPT_READY. The authoritative delta is **§⓪′ REVISION** (additive over §⓪). Three flows: (1) donor announcement on Publish [bulk `EmailSendJob` pipeline + `AnnouncementSentAt` guard], (2) per-registration payment-success + tickets [fire-on-action `SendEmailByTemplateKeyAsync`], (3) post-event feedback + reminders via ONE daily Hangfire `RecurringJob` `event-communication-dispatcher` [`ReminderSentAt`/`FeedbackSentAt` guards, model on `PayURecurringChargeService`]. `EventCommunicationTrigger` becomes the live policy gate. +4 cols on `app.EventRegistrationPages` (user-owned migration). Opened ISSUE-28…34. Full decision record: memory `project_event_email_comms_design`. Next: `/build-screen #169` to implement Wave 3 (the next build session appends "Session 23" below).

### § Sessions

> _[27 older session entries trimmed to save tokens — full history in git: `git log -p -- eventregpage.md`. Most recent 5 kept below.]_

### Session 28 — 2026-06-11 — PLAN (`/plan-screens`) — COMPLETED

- **Scope**: Designed the registrant field-model redesign (ISSUE-38) → authoritative **§⓪″ Build Wave 4** delta. No code written (planning only).
- **Deep analysis done**: read `EventRegistration.cs`, `EventRegistrationFormField.cs`, `EventCustomQuestion.cs`, `CreateEvent.cs` (seed), `InitiateEventRegistration.cs` (handler + request DTO), both event GQL queries, Card 5, `registrant-fields.tsx`, and the **ODP canonical mirror** `OnlineDonationStaging.cs` (the `Provided*` column pattern the user chose).
- **Root cause nailed (4 breakages)**: B1 seed only `FULLNAME`+`EMAIL`; B2 GQL `fieldName: fieldLabel` feeds the human label where every FE consumer matches a stable code; B3 canonical-code drift (FE PascalCase vs DB UPPERCASE, no `FULLNAME` FE equiv); B4 handler drops the 6 extra system fields + ContactCode (no columns) — though the **request DTO already carries them all** (the gap is purely seed + alias + persistence, NOT the request contract).
- **Decisions locked with user (2026-06-11)**:
  - Custom-question config + `CustomAnswers[]` capture → **Coming Soon** (Card 12); NO `EventRegistrationCustomAnswers` table (NEW-ISSUE-39).
  - Capture **+ store** the 9 system fields + ContactCode (firm requirement); admin surfacing **deferred** to #46/#137 (NEW-ISSUE-40, agent-decided per user delegation).
  - Persistence = **ODP `Provided*` parity** (10 string columns on `app.EventRegistrations`, incl `ProvidedContactCode`); keep `RegistrantName/Email/Phone` (NEW-ISSUE-41 dual-store note).
  - 9 canonical **PascalCase** codes; `FULLNAME`→`FirstName`+`LastName`; only First/Last/Email `IsSystem=true` (locked).
- **Files touched**: `.claude/screen-tracker/prompts/eventregpage.md` (added §⓪″.1-.11 authoritative delta; ISSUE-38 → DESIGNED; +ISSUE-39/40/41; frontmatter `status` COMPLETED→PROMPT_READY + Wave-4 `revision`). `REGISTRY.md` (status + note).
- **Known issues opened**: NEW-ISSUE-39, NEW-ISSUE-40, NEW-ISSUE-41. **Closed**: None (ISSUE-38 → DESIGNED, not yet built).
- **Next step**: Run **`/build-screen #169`** (or `/continue-screen #169`) to execute §⓪″ Wave 4. Build order: (1) BE seed rewrite + entity +10 `Provided*` cols + config + handler write-block; (2) FE DTO/query alias fix + Card 5 fieldCode rename & Custom-Questions removal + Card 12 teaser; (3) user runs the EF migration + the `EventRegistrationPage-formfields-backfill.sql`. Verify at **runtime** (enable "Organization" in Card 5 → it must render on the public form; register → `Provided*` columns populate).

### Session 29 — 2026-06-11 — BUILD — COMPLETED

- **Scope**: Executed §⓪″ Build Wave 4 (registrant field-model redesign + ContactCode persistence — resolves ISSUE-38). Fixed all 4 breakages (B1 seed / B2 GQL alias / B3 canonical codes / B4 handler persist) plus the Custom-Questions → Coming-Soon move. Surgical FE+BE delta — edited directly (not via agents) given the locked, precise spec.
- **Files touched**:
  - BE: `Base.Domain/.../ApplicationModels/EventRegistration.cs` (modified — +10 `Provided*` props after `RegistrantPhone`); `Base.Infrastructure/.../ApplicationConfigurations/EventRegistrationConfiguration.cs` (modified — 10 `.HasMaxLength` lines mirroring ODP lengths); `Base.Application/.../Events/Commands/CreateEvent.cs` (modified — B1: replaced the 2-row `FULLNAME`/`EMAIL` seed with a 9-row loop over new `private static BuildDefaultFormFields(int companyId)` helper, caller-supplied fields still win by FieldCode); `Base.Application/.../EventRegistrationPages/PublicMutations/InitiateEventRegistration.cs` (modified — B4: 10 `Provided*` assignments from the effective `req.*` after the ContactCode override).
  - FE: `domain/entities/application-service/EventRegistrationPageDto.ts` (modified — `ErpRegistrationFormFieldDto`: `fieldName` → `fieldCode` + `fieldLabel?`); `infrastructure/gql-queries/public-queries/EventRegistrationPagePublicQuery.ts` + `infrastructure/gql-queries/application-queries/EventRegistrationPageQuery.ts` (modified — B2: select `fieldCode` + `fieldLabel`, dropped the `fieldName: fieldLabel` alias); `crm/event/eventregpage/cards/5-registrant-experience-card.tsx` (rewritten — keys off `fieldCode`, displays `fieldLabel ?? FIELD_DISPLAY[fieldCode]`, removed the entire Custom-Questions editor + now-unused imports/state); `crm/event/eventregpage/cards/12-coming-soon-card.tsx` (modified — added "Custom Registration Questions" teaser row); `public/eventregpage/components/registrant-fields.tsx` (modified — `visible/requiredFieldNames` now built from `f.fieldCode.toLowerCase()`); `public/eventregpage/components/registration-form.tsx` (modified — required-field validation keys off `fieldCode`, message uses `fieldLabel`). `live-preview.tsx` — no change (does not reference `fieldName`).
  - DB (user-run): `sql-scripts-dyanmic/EventRegistrationPage-formfields-backfill.sql` (created — idempotent: inserts missing canonical rows per existing event via CROSS JOIN VALUES + `WHERE NOT EXISTS` case-insensitive on FieldCode; soft-disables legacy `FULLNAME`; keeps legacy `EMAIL` which satisfies canonical `Email` case-insensitively). **EF migration NOT authored** — user generates + runs it for the 10 `Provided*` columns on `app."EventRegistrations"` ([[feedback_user_creates_migrations]]).
- **Verification**: `dotnet build Base.Application` (transitively Domain + Infrastructure) = **0 errors** (555 pre-existing warnings). `npx tsc --noEmit` (full FE) = **exit 0**, no eventregpage/registrant errors. Request DTO field names confirmed to match the handler assignments (ContactCode/FirstName/LastName/Email/Phone/Organization/DietaryRequirements/AccessibilityNeeds/TshirtSize/EmergencyContact). **Persistence + runtime field-render require the user's EF migration + the backfill SQL + API restart** (tsc-invisible defect class per [[feedback_reuse_canonical_gql_query]] — runtime-verify B2: enable "Organization" in Card 5 → must render on the public form).
- **Deviations from spec**: None. (Bonus over §⓪″.4: also fixed the same `fieldName`→`fieldCode` consumer in `registration-form.tsx`'s required-field validation, which the delta's "grep before editing" note implies but didn't enumerate — without it the required-field check matched on label and tsc would break.)
- **Known issues opened**: None new (ISSUE-39/40/41 already opened S28 stay OPEN — deferred by design).
- **Known issues closed**: **ISSUE-38** (built per §⓪″ Wave 4).
- **Next step (user)**: (1) `dotnet ef migrations add Add_EventRegistration_ProvidedFields` + `dotnet ef database update` for the 10 nullable `Provided*` columns; (2) run `EventRegistrationPage-formfields-backfill.sql` against existing events; (3) restart API + `pnpm dev`; (4) runtime-verify: enable "Organization" in admin Card 5 → renders on the public `/event/{slug}` form; submit a registration → `app."EventRegistrations".Provided*` columns populate (incl `ProvidedContactCode`); ContactCode path stores resolved identity in `ProvidedFirstName/LastName/Email` + sets `ContactId`.
  > **Superseded by Session 30** — the migration is now for only **6** `Provided*` columns (the 4 name/email/phone duplicates were dropped) and there is no longer an `EarlyBirdDeadline` column. See S30 for the corrected migration + verification steps.

### Session 30 — 2026-06-11 — FIX — COMPLETED

- **Scope**: Two user-requested cleanups on the registrant + page-setup model. (a) Removed the 4 redundant `Provided*` columns added in S29 — `ProvidedFirstName/LastName/Email/Phone` duplicated `RegistrantName` (= FirstName + LastName) / `RegistrantEmail` / `RegistrantPhone`, which already hold those values; kept only the 6 genuinely-new capture columns. (b) Removed the unused `EarlyBirdDeadline` field from the registration-page-setup entity and its full BE+FE plumbing (no early-bird *pricing* feature was ever wired; `EventTicketType.EarlyBirdPrice` is a separate ticketing field and was left intact). Surgical, edited directly — no migration run ([[feedback_user_creates_migrations]]). Zero-cost because the S29 `Provided*` migration had not yet been run.
- **Files touched**:
  - BE (Provided* dedup): `Base.Domain/.../EventRegistration.cs` (−4 props); `Base.Infrastructure/.../EventRegistrationConfiguration.cs` (−4 `.HasMaxLength`); `Base.Application/.../EventRegistrationPages/PublicMutations/InitiateEventRegistration.cs` (−4 assignments; `RegistrantName/Email/Phone` already carried name/email/phone).
  - BE (EarlyBirdDeadline removal): `Base.Domain/.../EventRegistrationPage.cs` (−1 prop); `Base.Application/Schemas/ApplicationSchemas/EventRegistrationPageSchemas.cs` (−3 DTO props) + `EventSchemas.cs` (−1); `Base.Application/Mappings/ApplicationMappings.cs` (−1 Mapster `.Map`); `Events/Commands/CreateEvent.cs`, `UpdateEvent.cs`, `DuplicateEvent.cs` (−1 each); `EventRegistrationPages/Queries/GetEventRegistrationPageById.cs`, `PublicQueries/GetEventRegistrationPageBySlug.cs`, `Commands/UpdateEventRegistrationPageSetup.cs` (−1 each); `sql-scripts-dyanmic/EventRegistrationPage-table-backfill.sql` (−`EarlyBirdDeadline` from the INSERT col-list + SELECT).
  - FE (EarlyBirdDeadline removal): `domain/entities/application-service/EventRegistrationPageDto.ts` (−3 fields), `domain/entities/contact-service/EventDto.ts` (−1); `infrastructure/gql-queries/{public-queries/EventRegistrationPagePublicQuery.ts, application-queries/EventRegistrationPageQuery.ts, contact-queries/EventQuery.ts}` (−1 selection each); `crm/event/eventregpage/cards/4-registration-window-card.tsx` (removed the "Early Bird Deadline" date picker + comment); `crm/event/event/form-tabs/types.ts` (−type field + initial); `crm/event/event/event-form-page.tsx` (−load mapping + −save payload); `crm/event/eventregpage/editor-page.tsx` + `components/live-preview.tsx` (−1 each).
- **Verification**: `dotnet build Base.Application` (transitively Domain + Infrastructure) = **0 errors** (555 pre-existing warnings). `npx tsc --noEmit` (full FE) = **exit 0**, no event/eventregpage errors. Source greps confirm zero remaining `EarlyBirdDeadline`/`earlyBirdDeadline` and zero stray `ProvidedFirstName/LastName/Email/Phone` outside EF migration history and the unrelated `fund.OnlineDonationStaging` table.
- **Deviations from spec**: Supersedes the S29 ODP-`Provided*`-parity decision for name/email/phone — at the user's direction those 3 fields reuse the existing `Registrant*` columns instead of being mirrored. The remaining 6 `Provided*` columns are unchanged.
- **Known issues opened**: None.
- **Known issues closed**: **ISSUE-41** (dual-store removed).
- **Next step (user)**: (1) `dotnet ef migrations add Cleanup_EventRegistration_ProvidedFields_And_EarlyBirdDeadline` then `dotnet ef database update` — the migration now (a) adds only the **6** `Provided*` columns on `app."EventRegistrations"` (`ProvidedContactCode`/`ProvidedOrganization`/`ProvidedDietaryRequirements`/`ProvidedAccessibilityNeeds`/`ProvidedTshirtSize`/`ProvidedEmergencyContact`) and (b) **drops** `app."EventRegistrationPages"."EarlyBirdDeadline"`. (If S29's migration was already generated but not applied, delete it and regenerate so the snapshot reflects the 6-column shape.) (2) run `EventRegistrationPage-formfields-backfill.sql`; (3) restart API + `pnpm dev`; (4) runtime-verify as in S29 — `Provided*` populate (incl `ProvidedContactCode`); the Registration-Window card no longer shows an Early Bird Deadline input.

### Session 31 — 2026-06-11 — ENHANCE — Lock-when-live (host Event Unpublish) — COMPLETED

- **Scope**: Cross-screen with #40 Event (primary Build Log entry: `event.md` Session 12). The host Event gained an **Unpublish** action (PUBLISHED → DRAFT, cascading this page Published/Active → **ReadyToPublish**). This session's #169-owned change: `crm/event/eventregpage/editor-page.tsx` now locks ALL page fields while the page is **live** (Published/Active), not only ReadyToPublish.
- **Files touched**:
  - FE: `crm/event/eventregpage/editor-page.tsx` — `locked = isReadyToPublish || liveLocked` (`liveLocked = isPublished || isActive`); the existing `<fieldset disabled={locked}>` now also greys out fields when live; embedded Save gained `|| locked`; split the frozen banner into the violet ReadyToPublish "Unlock" variant + a new emerald **"This page is live — unpublish the event to edit"** variant (no unlock button, since Unlock only accepts ReadyToPublish; **bg fill removed per user — border + text only**). Operational actions (Preview / Resend / Close Early / Archive / Reset Branding) stay live.
  - BE: none in this file's scope (the Unpublish command + cascade live on the Event side — see `event.md` S12 / `Events/Commands/UnpublishEvent.cs`).
- **Deviations from spec**: None. **Known issues opened/closed**: None.
- **Verification**: FE `npx tsc --noEmit` → **0 errors**. BE `dotnet build Base.API` (Event-side) → **0 errors**. Runtime lock-when-live pending user `pnpm dev`.
- **Next step**: COMPLETED.

### Session 32 — 2026-06-11 — FIX — COMPLETED

- **Scope**: Runtime error `The field 'unlockEventRegistrationPage' does not exist on the type 'Mutation'` (also affected `markEventRegistrationPageReadyToPublish`). Root cause: the consolidation #40 command **handlers** (`UnlockEventRegistrationPageCommand`, `MarkEventRegistrationPageReadyToPublishCommand`) existed in `Base.Application` but were never exposed as GraphQL endpoints in `Base.API`, so HotChocolate had no such Mutation fields. FE was already correct.
- **Files touched**:
  - BE: `Base.API/EndPoints/Application/Mutations/EventRegistrationPageMutations.cs` (modified) — registered `MarkEventRegistrationPageReadyToPublish` (→ `BaseApiResponse<EventRegistrationPagePublishResultDto>`, mirrors Publish) and `UnlockEventRegistrationPage` (→ `BaseApiResponse<bool>`, mirrors Unpublish); class-doc updated 6→8 methods.
  - FE: none (mutation defs + handlers in `editor-page.tsx` / `EventRegistrationPageMutation.ts` were already correct).
- **Deviations from spec**: None. **Known issues opened/closed**: None.
- **Verification**: BE build deferred to user (their request). FE unchanged.
- **Next step**: User builds BE → Unlock / Mark-Ready resolve.
