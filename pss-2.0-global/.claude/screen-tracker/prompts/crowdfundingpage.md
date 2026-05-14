---
screen: CrowdFundingPage
registry_id: 173
module: Setting (Public Pages)
status: COMPLETED
scope: FULL
screen_type: EXTERNAL_PAGE
external_page_subtype: CROWDFUND
complexity: High
new_module: NO
planned_date: 2026-05-13
completed_date: 2026-05-13
last_session_date: 2026-05-13
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — `fundraising/crowdfunding-page.html` (1471 lines) contains TWO surfaces: ADMIN setup (Campaign Cards list view + 6-tab Editor Modal: Basic / Content / Donation Settings / Milestones / Updates / Design) AND PUBLIC PREVIEW (donor-facing campaign page at `/crowdfund/{slug}` with hero + 2-col story+sidebar). Sub-type identified: **CROWDFUND** (goal + deadline + tiered impact + milestones timeline + updates feed + reward-style impact breakdown + share buttons + sticky donate widget).
- [x] Business context read (audience = anonymous donors visiting `/crowdfund/{slug}`; admin = BUSINESSADMIN configuring story + milestones + design; lifecycle = Draft → Published → Active → GoalMet → Closed → Archived; payment hand-off via existing `fund.CompanyPaymentGateways`).
- [x] Setup vs Public route split identified (admin at `setting/publicpages/crowdfundingpage` + anonymous public at `(public)/crowdfund/{slug}`).
- [x] Slug strategy chosen: `custom-with-fallback` (auto-from-CampaignName on Create; admin can override; per-tenant unique; immutable once Status ≥ Active).
- [x] Lifecycle states confirmed (Draft / Published / Active / GoalMet / Closed / Archived — same as #16 CrowdFund entity).
- [x] Payment gateway integration scope confirmed (existing `fund.CompanyPaymentGateways` lookup for gateway selection; real Stripe/PayPal hand-off is SERVICE_PLACEHOLDER until gateway connect implemented).
- [x] FK targets resolved (paths + GQL queries verified — all FK targets already in code from #16's planned BE).
- [x] File manifest computed (admin setup files + public route files separately; **wraps existing CrowdFund entity from #16** — no new entity, just additional handlers + 2 endpoints + FE setup shell + public SSR page).
- [x] Approval config pre-filled (MenuCode=`CROWDFUNDINGPAGE`, ParentMenu=`SET_PUBLICPAGES`, MenuUrl=`setting/publicpages/crowdfundingpage`, OrderBy=7 — sibling of ONLINEDONATIONPAGE/P2PCAMPAIGNPAGE/PRAYERREQUESTPAGE/MEMBERPORTAL/VOLUNTEERREGPAGE/EVENTREGPAGE).
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt exhaustively pre-analyzed; orchestrator validated against §① §② §④ §⑤ — no BA agent spawned)
- [x] Solution Resolution complete (sub-type CROWDFUND, slug `custom-with-fallback`, `save-all` model, SSR public render)
- [x] UX Design finalized (6-tab editor + live-preview pane + public 2-col layout per mockup §⑥)
- [x] User Approval received (Session 1 BUILD scope=BE_ONLY confirmed; CONFIG block approved as-is)
- [x] Backend code generated (Session 1 BUILD 2026-05-13 — 11 NEW files + 4 MODIFY files + 1 wiring (DependencyInjection rate-limit policy) — `dotnet build` PASS 0 errors)
- [x] Backend wiring complete (CrowdFundDonationSubmit rate-limit policy registered; admin GQL fields appended to CrowdFundQueries/CrowdFundMutations; public endpoints created in Donation/Public/ folder; cache key conventions documented)
- [x] Frontend (admin setup) code generated (Session 2 FE_ONLY 2026-05-13 — 17 admin files: root + store + schemas + list-page + editor-page + 6 tabs + 13 components)
- [x] Frontend (public page) code generated (Session 2 FE_ONLY 2026-05-13 — 15 public components + 2 routes (admin + SSR public with `generateMetadata`) + 5 GQL/DTO files)
- [x] Frontend wiring complete (Session 2 — entity-operations CROWDFUNDINGPAGE block appended using `UPDATE_CROWDFUND_PAGE` per ISSUE-16; DTO + GQL barrel exports added; pages barrel updated)
- [x] DB Seed script generated (`Crowdfundingpage-sqlscripts.sql` — Menu @ CROWDFUNDINGPAGE under SET_PUBLICPAGES OrderBy=7 + 9 MenuCapabilities (incl. ISMENURENDER) + BUSINESSADMIN role grants for 8 functional caps + Grid `CROWDFUNDINGPAGE` GridType=`EXTERNAL_PAGE` GridFormSchema=NULL + UPDATE-with-guard promotes existing #16 `build-a-school-kenya` Draft → Active with rich Content/Milestones/Updates/Impact/FAQ payloads for E2E QA at `/crowdfund/build-a-school-kenya`)
- [x] Registry updated to COMPLETED (Session 2 — 2026-05-13)

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — admin setup loads at `/{lang}/setting/publicpages/crowdfundingpage` (replaces UnderConstruction stub or fresh route)
- [ ] `pnpm dev` — public page loads at `/{lang}/crowdfund/{slug}` (e.g. `/{lang}/crowdfund/build-a-school-kenya`)
- [ ] **CROWDFUND sub-type checks**:
  - [ ] Setup list view shows all CrowdFund pages with status badges; "+ Create Campaign Page" creates a Draft + redirects to setup editor
  - [ ] All 6 setup tabs persist (Basic / Content / Donation Settings / Milestones / Updates / Design)
  - [ ] **Tab 1 — Basic**: Campaign Name + Slug (auto-from-name with `/campaign/` prefix display; copyable) + Goal Amount + Currency dropdown (USD/EUR/GBP/INR) + Start Date + End Date + Linked Donation Purpose (FK ApiSelectV2) + Campaign Category (string enum dropdown: Education/Healthcare/Emergency/Environment/Community/Other) + Organizational Unit (FK ApiSelectV2)
  - [ ] **Tab 2 — Content**: Headline + Hero Image/Video upload-area (1200x630 image OR YouTube URL paste) + Campaign Story rich text editor (B/I/U / list-ul/ol / link/image toolbar) + Impact Breakdown editor (rows of `{amount, description}` with add/remove; "+ Add Impact Level") + FAQ Section editor (rows of `{question, answer}`; "+ Add FAQ")
  - [ ] **Tab 3 — Donation Settings**: Suggested Donation Amounts chip-editor ($50/$100/$250/$500/$1000 + Custom toggle-as-chip) + Donation Options toggles (Allow Recurring / Allow Anonymous / Cover Processing Fees) + Payment Methods checkboxes (Stripe / PayPal — backed by `fund.CompanyPaymentGateways`) + Display Options toggles (Show Goal Thermometer / Show Donor Count / Show Donor Wall) + Goal Exceeded Behavior radio group (Keep Accepting / Auto-Close / Show Stretch Goal — Stretch Goal Amount field conditional)
  - [ ] **Tab 4 — Milestones**: list editor of `{name, percentage, amount, status: Reached/InProgress/Upcoming}` with marker icon per status + percent-of-goal computed + Edit pen + "+ Add Milestone" button at bottom; status field is editable enum (admin can override auto-computed); auto-compute on save when admin doesn't override
  - [ ] **Tab 5 — Updates**: table of `{updateDate, title, content}` posted updates with Edit/Delete actions + "+ Post Update" button → modal with date + title + rich-text content
  - [ ] **Tab 6 — Design**: Theme Colors (Primary / Accent / Background color pickers) + Logo upload-area + Font Family dropdown (System Default / Georgia / Poppins / Open Sans) + Custom Sections checkboxes (Impact Breakdown / Milestone Timeline / Updates Feed / Donor Wall / FAQ Section / Share Buttons / Countdown Timer — toggle which sections appear on public page; saves to `EnabledSectionsJson`)
  - [ ] **Live Preview** pane on every tab (NOT a separate tab) — split-pane: editor left + preview right (480px wide, sticky on scroll). Preview toolbar: device-switcher (Desktop / Mobile). Desktop = browser-chrome mockup with URL bar `pss2.com/crowdfund/{slug}`. Mobile = phone-frame. Renders the actual public composition (hero + 2-col body) with current settings applied. Updates within 300ms of edit (debounce). Mobile collapses to single-column.
  - [ ] **Save Draft / Publish** at form footer (persistent across tabs). "Save Draft" persists across all 6 tabs as Draft. "Publish" runs `ValidateCrowdFundForPublish` and shows missing-fields modal on validation failure; success → transitions Draft → Active (or Published if scheduled).
  - [ ] **Status Bar** in admin setup shows real aggregates (totalRaised / totalDonors / donationCount / lastDonationAt) when editing existing
  - [ ] **Public parent page** at `/crowdfund/{campaignSlug}` renders: org-header navbar (using Hero Foundation branding) + hero gradient with category icon + 2-col layout (left: headline + org-tag + category-tag + story rich text + Impact Breakdown rows + Milestones Timeline + Campaign Updates feed + Recent Supporters donor wall + FAQ accordion / right: sticky progress widget — raised/goal/progress bar/donor count/days-left + donate form — amount grid 3×2 incl. Custom + Make-it-monthly toggle + Cover-Processing-Fees toggle + Donate Now button + share buttons row [Facebook/Twitter/WhatsApp/LinkedIn/Copy Link]) + Public Footer
  - [ ] **Public donate flow**: CSRF + honeypot + rate-limit (5/min/IP/slug); submit creates `fund.GlobalDonation` linked to `CrowdFundId`; for Goal-Exceeded behavior=AutoClose, server-side checks and flips status; for behavior=ShowStretchGoal, displays "Goal met! Stretch goal: ${stretchAmount}" banner; for behavior=KeepAccepting, continues normally
  - [ ] **Slug uniqueness**: parent slug unique per tenant; auto-from-CampaignName; reserved slug list rejected (`admin/api/crowdfund/crowdfunding/preview/login/auth/start/dashboard`); IMMUTABLE once PageStatus ≥ Active
  - [ ] **Validate-for-publish** blocks Publish until: CampaignName + Slug + GoalAmount > 0 + StartDate ≤ EndDate + EndDate ≥ today + 1 + DonationPurposeId resolved + CampaignCategory selected + ≥1 EnabledPaymentMethods + (AmountChipsJson ≥1 OR AllowCustomAmount=true) + (if GoalExceededBehavior='ShowStretchGoal' then StretchGoalAmount > GoalAmount) + (if WhatsAppDonationAlertEnabled then WhatsAppDonationAlertTemplateId set)
  - [ ] **OG tags** rendered in initial SSR HTML for public route; share preview correct on FB/Twitter/WhatsApp; OG image falls back to Hero Image when OgImageUrl is NULL
  - [ ] **Closed campaign** → public renders "This campaign has ended" banner + final raised total; donate button disabled. **Archived** → 410 Gone. **Draft** → 404 (unless preview-token).
  - [ ] **Goal-Met state** (TotalRaised ≥ GoalAmount): progress bar shows "🎉 Goal met!" message; if `GoalExceededBehavior=ShowStretchGoal` AND StretchGoalAmount set → renders secondary progress bar for stretch goal; if `=AutoClose` → status auto-flips on next admin load; if `=KeepAccepting` → continues normally
  - [ ] Empty / loading / error states render on both setup and public surfaces
- [ ] DB Seed — admin menu visible at `Setting > Public Pages > Crowdfunding Page`; sample published CrowdFund renders for E2E QA at `/crowdfund/build-a-school-kenya`

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage for setup AND public page

Screen: CrowdFundingPage
Module: Setting (admin) / Public (anonymous-rendered)
Schema: `fund`
Group: DonationModels (existing — established by #10 OnlineDonationPage + #170 P2PCampaignPage)

**Business**: This is the **public-facing crowdfunding setup screen** an NGO publishes to recruit anonymous donors for a goal-based, deadline-driven campaign (e.g. "Build a School in Kenya", "Emergency Earthquake Relief", "Clean Water for 10 Villages"). Where the existing `CrowdFund` entity from #16 serves as the **CRM management surface** (cards-grid monitoring view with Quick-Create for the 8 essential Basic fields), THIS screen is the **rich content editor + public storefront** — the full 6-tab editor (Basic / Content / Donation Settings / Milestones / Updates / Design) that lets admins write campaign stories, define impact breakdowns, configure milestones, post updates, and brand the public page; plus the SSR-rendered public route at `/crowdfund/{slug}` that donors visit to learn about the cause and give.

The mockup (`crowdfunding-page.html`) shows: (a) an admin LIST view with 4 KPI tiles (Active Campaigns / Total Raised / Total Donors / Goals Met) + 4 filter chips + 5 sample campaign cards — **this is the SAME list as #16 owns** (CRM monitoring); (b) an admin EDITOR MODAL with 6 tabs (Basic / Content / Donation Settings / Milestones / Updates / Design) — **this is what THIS screen builds** (the rich tabbed editor); (c) a public PREVIEW pane showing the donor-facing campaign page with org-header / hero / 2-col body (story + impact + milestones + updates + donors + FAQ on left, progress + donate form + share on right) — **this is the public surface THIS screen publishes**.

**Lifecycle**: Draft → Published → Active → GoalMet → Closed → Archived (matches CrowdFund entity from #16; only Active/GoalMet pages accept donations; Draft/Pending render only with preview-token; Closed renders banner "This campaign has ended" and disables Donate; Archived returns 410 Gone). Status auto-promotes Active → GoalMet when TotalRaised ≥ GoalAmount AND `GoalExceededBehavior='AutoClose'`. Status transitions are BE-enforced explicit commands (PublishCrowdFund / UnpublishCrowdFund / CloseCrowdFund / ArchiveCrowdFund), never FE flags.

**What breaks if mis-set**: donors charged but no record stored (gateway webhook missing), expired payment-gateway connect leaving "Donate Now" button dead, missing CSRF/honeypot enabling bot/spam submissions, slug rename after donations attached → link rot on shared social posts and SEO loss, OG meta missing → bad share previews → low conversion, GoalExceededBehavior misconfig → either auto-close while donors are mid-checkout (race) or keep accepting past intended cap, stretch goal not displayed because StretchGoalAmount left NULL, milestones marked "Reached" before actual TotalRaised passes threshold (admin override drift).

**Related screens**:
- #16 Crowdfunding (PROMPT_READY → must be built first) — CRM management surface (cards-grid + drawer + Quick-Create). Together with this screen, they cover the full Crowdfunding feature: #16 = monitoring; #173 = setup + storefront.
- #10 OnlineDonationPage (COMPLETED) — first EXTERNAL_PAGE / DONATION_PAGE; established GridType `EXTERNAL_PAGE` + (public) route group pattern
- #170 P2PCampaignPage (COMPLETED) — sibling EXTERNAL_PAGE / P2P_FUNDRAISER under SET_PUBLICPAGES; canonical tabbed-editor + live-preview + 5-tab settings UX
- #171 PrayerRequestPage (PARTIALLY_COMPLETED) + #172 VolunteerRegistrationPage (COMPLETED) — other EXTERNAL_PAGE siblings
- #1 GlobalDonation (COMPLETED) — donation source records; #16 already adds nullable FK `CrowdFundId` to `fund.GlobalDonations`
- #11 MatchingGift (COMPLETED) — sibling under CRM_P2PFUNDRAISING for the management side

**What's unique about this page's UX vs P2PCampaignPage**: Crowdfunding is a SINGLE public surface (one parent page per CrowdFund — no child fundraiser pages, no team option, no leaderboard, no "Start Fundraiser" wizard). Visual emphasis is on the IMPACT BREAKDOWN (concrete tiered outcomes per dollar — "$50 provides a desk and chair") and the MILESTONES TIMELINE (visual progress through a multi-stage construction/aid mission). Donor flow is a single sticky right-sidebar donate form — not a multi-page wizard. Goal-met state has 3 explicit behaviors (Keep Accepting / Auto-Close / Show Stretch Goal) configurable per campaign.

> **Why this section is heavier than other types**: TWO render trees (admin tabbed editor / public 2-col page) PLUS a 6-tab content surface PLUS jsonb child collections (Milestones / Updates / ImpactBreakdown / FAQ) PLUS a goal-met state machine PLUS public-route hardening (CSRF / honeypot / rate-limit / CSP) PLUS SSR OG meta. A developer that misses any of these will ship a broken half-product. Read this whole section before opening §⑥.

---

## ② Storage & Source Model

> **Consumer**: BA Agent → Backend Developer
>
> **Storage Pattern**: `single-page-record` (one row per crowdfund campaign; multi-row per tenant; e.g. one tenant runs "Build a School in Kenya" + "Emergency Earthquake Relief" + "Mobile Health Clinic" simultaneously).
>
> **PREREQUISITE — Entity already defined by #16**: The `CrowdFund` entity (~50 properties) is built by #16's BE generation. THIS screen wraps and extends that entity — it does NOT create a new entity. If #16 has not been built yet, this screen's `/build-screen` should fail-fast with an error message and queue #16 first.

**Existing primary table** (from #16): `fund."CrowdFunds"`

### Field reuse from #16 entity

THIS screen uses the **entire CrowdFund entity schema** unchanged:

| Field Group | Tab Mapping | Notes |
|-------------|-------------|-------|
| Core (CampaignName / Slug / PageStatus / Currency / GoalAmount / StartDate / EndDate / DonationPurposeId / CampaignCategory / OrganizationalUnitId) | Tab 1 — Basic | Mockup Basic tab maps 1:1 to #16's core fields |
| Content (Headline / HeroImageUrl / HeroVideoUrl / StoryRichText / ImpactBreakdownJson / FaqJson) | Tab 2 — Content | All editable via this screen; ImpactBreakdownJson + FaqJson edited as jsonb arrays |
| Donation (AmountChipsJson / AllowCustomAmount / MinimumDonationAmount / AllowRecurringDonations / AllowAnonymousDonations / AllowDonorCoverFees / EnabledPaymentMethodsJson / CompanyPaymentGatewayId / ShowGoalThermometer / ShowDonorCount / ShowDonorWall / GoalExceededBehavior / StretchGoalAmount) | Tab 3 — Donation Settings | All editable; CompanyPaymentGatewayId is FK ApiSelectV2 |
| Milestones (MilestonesJson) | Tab 4 — Milestones | jsonb array of `{name, percentage, amount, status}`; UI auto-computes amount from percentage × GoalAmount but admin can override |
| Updates (UpdatesJson) | Tab 5 — Updates | jsonb array of `{updateDate, title, content}`; sorted desc by updateDate on render |
| Design (PrimaryColorHex / AccentColorHex / BackgroundColorHex / LogoUrl / FontFamily / EnabledSectionsJson) | Tab 6 — Design | All editable; EnabledSectionsJson toggles which public-page sections render |
| Communication (5 template FKs + WhatsApp toggle/FK) | (not in mockup tabs — pattern from #170; deferred to V2 or hidden behind a Communication sub-tab in Design tab) | OPTIONAL — see §⑫ ISSUE-COMM-DEFERRED |
| SEO (OgImageUrl / OgTitle / OgDescription / DefaultShareMessage / RobotsIndexable) | (not in mockup tabs; pattern from #170; SEO sub-section at bottom of Design tab) | OPTIONAL — see §⑫ ISSUE-SEO-PARTIAL |

### Slug uniqueness (already enforced by #16)

- Filtered unique index on `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted` — set up by #16's migration
- Reserved-slug list rejected: `admin, api, crowdfund, crowdfunding, preview, login, signup, oauth, public, assets, static, start, fundraise, embed, dashboard, _next, ic`
- Slug auto-derived from CampaignName on Create; admin can override
- Slug IMMUTABLE once PageStatus IN ('Active', 'GoalMet', 'Closed') AND ≥1 donation attached (already enforced by #16's UpdateCrowdFund handler; this screen's UpdateCrowdFundPage handler must check the same guard)

### Status transitions (already implemented by #16 — reuse)

- PublishCrowdFund (Draft → Published; auto-Active if StartDate ≤ UtcNow)
- UnpublishCrowdFund (Published → Draft; only if zero donations)
- CloseCrowdFund (Active/GoalMet → Closed)
- ArchiveCrowdFund (Closed/Draft/GoalMet → Archived)
- DuplicateCrowdFund / DeleteCrowdFund (already implemented by #16)

### NEW handlers added by THIS screen (not in #16)

| Handler | Purpose | Visibility |
|---------|---------|------------|
| `GetCrowdFundBySlug` query | Public route resolves slug → status-gated entity projection (only public-safe fields; PageStatus IN ('Active','GoalMet','Closed') OR preview-token) | **public anonymous** |
| `ValidateCrowdFundForPublish` query | Pre-publish validation — returns list of missing/invalid fields (admin Publish click uses this to show modal on failure) | admin |
| `GetCrowdFundEmbedCode` query | Returns shareable embed `<iframe>` snippet for "share as widget" (mockup has 5 share buttons but optional widget-embed for V2) | admin |
| `InitiateCrowdFundDonation` public mutation | Anonymous-callable; creates donation intent (returns paymentSessionId or redirectUrl); rate-limited 5/min/IP/slug; CSRF-protected | **public anonymous** |
| `ConfirmCrowdFundDonation` public mutation | Gateway callback handler; finalizes `fund.GlobalDonation` with CrowdFundId set; updates milestone status if cross-threshold | **public anonymous (gateway-signed)** |

### Modification to existing #16 UpdateCrowdFund handler

The current `UpdateCrowdFund` (#16) is built for **Quick-Edit** (8 Basic fields only). THIS screen needs **per-tab partial save** — when admin saves Tab 2 (Content), the handler must accept only Content fields without requiring Basic fields to be re-sent. Modify `UpdateCrowdFund` to support partial-field patch (use `null`-means-no-change semantics OR add a `fieldMask` param). See §⑫ ISSUE-UPDATE-PARTIAL.

### Donation linkage (already in #16's plan)

`fund.GlobalDonations` already has nullable FK `CrowdFundId` added by #16's migration. Public donation flow on THIS screen creates a `GlobalDonation` row with `CrowdFundId` set; aggregates roll up via existing GetCrowdFundStats subqueries.

> **DO NOT** create a separate donation table — single nullable FK on GlobalDonation is consistent with OnlineDonationPage + P2PCampaignPage + P2PFundraiser pattern.

> **Coexistence**: A donation may be linked to ONLY ONE source page — the existing CHECK constraint `NUM_NONNULLS(OnlineDonationPageId, P2PCampaignPageId, P2PFundraiserId) <= 1` on GlobalDonations must be EXTENDED to include `CrowdFundId`. See §⑫ ISSUE-DONATION-CHECK-CONSTRAINT.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------------|---------------|-------------------|
| DonationPurposeId | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` (schema `fund`) | `getAllDonationPurposeList` | `donationPurposeName` | `DonationPurposeResponseDto` |
| OrganizationalUnitId | OrganizationalUnit | `Base.Domain/Models/CompanyOrgModels/OrganizationalUnit.cs` (schema `corg`) | `getAllOrganizationalUnitList` | `organizationalUnitName` | `OrganizationalUnitResponseDto` |
| CompanyPaymentGatewayId | CompanyPaymentGateway | `Base.Domain/Models/DonationModels/CompanyPaymentGateway.cs` (schema `fund`) | `getAllCompanyPaymentGatewayList` | join `paymentGateway.gatewayName` | `CompanyPaymentGatewayResponseDto` |
| ConfirmationEmailTemplateId / GoalMilestoneEmailTemplateId / GoalReachedEmailTemplateId / AdminNotificationEmailTemplateId | EmailTemplate | `Base.Domain/Models/CommModels/EmailTemplate.cs` (or `corg.EmailTemplates` — verify on build) | `getAllEmailTemplateList` | `templateName` | `EmailTemplateResponseDto` |
| WhatsAppDonationAlertTemplateId | WhatsAppTemplate | `Base.Domain/Models/CommModels/WhatsAppTemplate.cs` (or `corg.WhatsAppTemplates` — verify on build) | `getAllWhatsAppTemplateList` | `templateName` | `WhatsAppTemplateResponseDto` |
| CompanyId | Company | `Base.Domain/Models/CompanyOrgModels/Company.cs` | (tenant-scoped via HttpContext) | (system) | — |
| CrowdFundId on GlobalDonation (aggregation source) | GlobalDonation | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | (server-side join only; not exposed as FE FK) | — | — |

**Master-data references** (looked up by code via existing `MasterData` shared model — NO FK column on entity):

| Code | MasterDataType | Used For |
|------|----------------|----------|
| `Stripe / PayPal / ApplePay / BankTransfer` | `PAYMENTMETHOD` (verify already seeded by #10/#170) | EnabledPaymentMethodsJson |
| `Education / Healthcare / Emergency / Environment / Community / Other` | (hard-coded string enum in entity; NO MasterDataType needed) | CampaignCategory dropdown — 6 fixed options |
| `Reached / InProgress / Upcoming` | (hard-coded string enum in MilestonesJson element) | Milestone status field |
| `KeepAccepting / AutoClose / ShowStretchGoal` | (hard-coded string enum) | GoalExceededBehavior radio group |

**Aggregation sources** (not strictly FK — used for stats / public-page progress):

| Source | Aggregate | Used In | Filter |
|--------|-----------|---------|--------|
| `fund.GlobalDonations` | `SUM(NetAmount)` GROUP BY CrowdFundId | totalRaised (status bar + public progress widget) | Status='Completed' |
| `fund.GlobalDonations` | `COUNT(DISTINCT ContactId)` GROUP BY CrowdFundId | totalDonors (KPI + "{N} donors" caption) | Status='Completed' |
| `fund.GlobalDonations` | `COUNT(*)` GROUP BY CrowdFundId | donationCount | Status='Completed' |
| `fund.GlobalDonations` | `MAX(DonationDate)` GROUP BY CrowdFundId | lastDonationAt | Status='Completed' |
| `fund.GlobalDonations` | TOP 10 ORDER BY CreatedDate DESC, project Contact name+amount+message+createdDate | Recent Supporters donor wall | Status='Completed' |
| `fund.GlobalDonations` | `AVG(NetAmount)` GROUP BY CrowdFundId | avgDonation (drawer KPI) | Status='Completed' |
| `fund.GlobalDonations` | `MAX(NetAmount)` GROUP BY CrowdFundId | largestDonation (drawer KPI) | Status='Completed' |
| `fund.GlobalDonations` | `COUNT(*)` GROUP BY CrowdFundId WHERE DonationDate >= now()-7d | donationsThisWeek (with week-over-week % delta) | Status='Completed' |

> Donor-wall query cached server-side 60s — never compute on every public-page render.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Slug Rules** (parent applies — child entities not in scope):

- Auto-generate from CampaignName on Create — lowercase, replace whitespace with `-`, strip non-alphanumeric (keep `-`), collapse multiple `-`
- User can override via Slug field; same normalization applied; show "URL preview" inline `/campaign/{slug}` (mockup shows `/campaign/` prefix; CONFIRM with build: per registry note row 536 the public route is `/crowdfund/{slug}` not `/campaign/{slug}` — mockup is illustrative; build uses `/crowdfund/{slug}`)
- Reserved-slug list rejected (case-insensitive): `admin, api, crowdfund, crowdfunding, preview, login, signup, oauth, public, assets, static, start, fundraise, embed, dashboard, _next, ic`
- Uniqueness enforced per tenant — composite `(CompanyId, LOWER(Slug))` filtered unique index
- Slug **immutable post-Activation when ≥1 donation attached** — already enforced by #16 UpdateCrowdFund handler
- Validator returns 422 with `{field:"slug", code:"SLUG_RESERVED | SLUG_TAKEN | SLUG_LOCKED_AFTER_DONATIONS"}`

**Lifecycle Rules** (BE-enforced — reuse #16 commands):

| State | Set by | Public route behavior | "Donate Now" CTA |
|-------|--------|----------------------|-------------------|
| Draft | Initial Create | 404 to public; preview-token grants temporary access | Hidden |
| Published | Admin "Publish" action | Renders publicly | Live (if StartDate ≤ now) |
| Active | Auto at StartDate (or = Published if StartDate ≤ now at Publish) | Renders publicly | Live |
| GoalMet | Auto when TotalRaised ≥ GoalAmount AND GoalExceededBehavior='AutoClose' (or admin-triggered) | Renders publicly with "🎉 Goal met!" banner; if ShowStretchGoal, renders stretch-goal progress bar | Disabled (AutoClose) / Live (KeepAccepting + ShowStretchGoal) |
| Closed | Auto at EndDate (if no Stretch Goal); admin "Close Early" | Renders publicly with "This campaign has ended" banner | Disabled |
| Archived | Admin "Archive" | 410 Gone (admin can configure redirect to org default) | N/A |

**Required-to-Publish Validation** (return all violations as a list):

- CampaignName non-empty
- Slug set + unique + not reserved
- GoalAmount > 0
- StartDate ≤ EndDate
- EndDate ≥ today + 1 day at Publish time
- DonationPurposeId resolved (FK valid)
- CampaignCategory selected (one of 6 enum values)
- ≥1 EnabledPaymentMethods (length ≥ 1)
- AmountChipsJson length ≥ 1 OR AllowCustomAmount=TRUE
- (if `GoalExceededBehavior='ShowStretchGoal'`) StretchGoalAmount > GoalAmount
- (if `WhatsAppDonationAlertEnabled=true`) WhatsAppDonationAlertTemplateId set
- HeroImageUrl OR HeroVideoUrl present (warn but allow — falls back to category gradient on public page)
- StoryRichText non-empty (length ≥ 100 chars recommended; warn but allow)
- (if ImpactBreakdownJson populated) every row has both amount > 0 AND description non-empty
- (if MilestonesJson populated) every row has name + percentage 0-100 + amount > 0 + status valid enum
- OG title/description present (warn but allow — falls back to CampaignName / Headline)

**Conditional Rules**:

- If `GoalExceededBehavior='ShowStretchGoal'` → StretchGoalAmount field becomes required and must be > GoalAmount
- If `GoalExceededBehavior='AutoClose'` → when TotalRaised ≥ GoalAmount on donation success, server-side flip PageStatus to GoalMet immediately
- If `WhatsAppDonationAlertEnabled=true` → WhatsAppDonationAlertTemplateId required
- If `EnabledSectionsJson.countdown=false` → public page hides countdown ribbon (default = false; admin must opt-in)
- If `RobotsIndexable=false` → public page renders `<meta name="robots" content="noindex">` (preview/internal campaigns)
- If `AllowCustomAmount=false` AND `AmountChipsJson.length=0` → block Publish (donor has nothing to click)
- If PageStatus goes `Closed` or `Archived` → all sub-handlers reject donation init/confirm with 410

**Sensitive / Security-Critical Fields**:

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| CompanyPaymentGatewayId reference | secret-by-link | display gateway name, never API keys | referenced; never duplicated | log on rotate |
| StoryRichText / FaqJson | injection-risk | sanitize HTML server-side (allow `b/i/u/p/h1-h6/ul/ol/li/a/img/blockquote`; strip `script/iframe/style/onerror/onclick`) | sanitize on Save; reject on validate | log on save |
| Donor PII captured on public form | regulatory | server-side only; never logged in plain text | encrypt-at-rest at column level if regulation requires | log access |
| Anti-fraud markers (IP, UA, velocity) | operational | not on public; admin-only via audit | append-only | retain per policy |
| Custom CSS (if added in design tab — currently not in mockup but may add per #170 precedent) | injection-risk | sanitize-strip `<script>` blocks; max 8000 chars | sanitize server-side | log on save |

**Public-form Hardening (anonymous-route concerns)**:

- Rate-limit donate-button POST: **5 attempts / minute / IP / slug**
- CSRF token issued on initial public-page render; required on submit; rotation on each render
- Honeypot field `[name="website"]` hidden via CSS; submission with non-empty honeypot silently rejected (return mocked success to bot)
- reCAPTCHA v3 score check before payment-gateway hand-off — `SERVICE_PLACEHOLDER` until reCAPTCHA configured (returns score=1.0)
- All input validated server-side (never trust public client)
- CSP headers on public route: `script-src 'self' https://js.stripe.com https://www.paypal.com https://www.google.com/recaptcha; frame-src https://js.stripe.com https://www.paypal.com https://www.google.com/recaptcha; style-src 'self' 'unsafe-inline'; img-src * data: https:; frame-ancestors 'none'`
- Email-based duplicate-Contact dedupe: if donor email matches existing Contact, link donation to existing ContactId rather than creating duplicate
- Idempotency: InitiateCrowdFundDonation POST has `idempotencyKey` (client-generated UUID) — re-posting same key returns same donation-intent response

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Publish | Page goes live; URL becomes shareable | "Publishing makes this page public at /crowdfund/{slug}." | log "crowdfund page published" with snapshot |
| Unpublish | Active/Published → Draft; only if zero donations | "Donors will see a closed page." | log |
| Close Early | Active/GoalMet → Closed before EndDate; new donations rejected | "Close campaign now? {totalRaised} raised so far." | log |
| Archive | Soft-delete; URL returns 410 | type-name confirm ("type {campaignName} to archive") | log |
| Edit Slug (Draft only) | Changes public URL | "Slug changes break any existing shares of the preview link." | log |

**Role Gating**:

| Role | Setup access | Publish access | Notes |
|------|-------------|----------------|-------|
| BUSINESSADMIN | full | yes | full lifecycle (target role for MVP) |
| Anonymous public | no setup access | — | sees Active/GoalMet/Closed public route only |

**Workflow** (donation flow on public page):

- Anonymous donor visits `/crowdfund/{slug}` → fills donate form (amount + monthly toggle + cover fees toggle)
- Submits with CSRF token + idempotencyKey
- Server validates → calls gateway tokenize (SERVICE_PLACEHOLDER returns mock token)
- Server creates `fund.GlobalDonation` with `CrowdFundId = X` (other source-page FKs NULL)
- Server upserts `crm.Contact` by email (anonymous toggle hides name in receipt; Contact still created for stewardship)
- Returns redirect URL or thank-you state
- Async: receipt email fires (using ConfirmationEmailTemplateId); admin alert fires (AdminNotificationEmailTemplateId); WhatsApp alert fires if WhatsAppDonationAlertEnabled
- Async: server checks if TotalRaised crossed milestone threshold → flips milestone status from Upcoming/InProgress to Reached → sends GoalMilestoneEmailTemplateId
- Async: server checks if TotalRaised ≥ GoalAmount → if `GoalExceededBehavior='AutoClose'` → flips PageStatus to GoalMet; sends GoalReachedEmailTemplateId

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: EXTERNAL_PAGE
**External-Page Sub-type**: `CROWDFUND`
**Storage Pattern**: `single-page-record` (entity already defined by #16)

**Slug Strategy**: `custom-with-fallback`
> Slug auto-derived from CampaignName on Create; admin can override; per-tenant unique. Slug becomes immutable once PageStatus ≥ Active AND ≥1 donation attached.

**Lifecycle Set**: `Draft / Published / Active / GoalMet / Closed / Archived` (matches #16 CrowdFund entity exactly)

**Save Model**: `save-all`
> Mockup shows explicit "Save Changes" button at each tab footer + "Cancel" + (when Draft) "Publish" button. NO autosave shown. Each tab edit is held in form state; "Save Changes" persists across all 6 tabs as Draft; "Publish" runs Validate-for-Publish then transitions Draft→Active.
> Frontend implementation: Single page-level form-state Zustand store; tab switches don't lose unsaved edits; "Cancel" reverts to last-saved.

**Public Render Strategy**: `ssr`
> Crowdfund campaigns must be SEO-indexable (Google "{cause} crowdfunding" + share-preview on FB/Twitter/WhatsApp). Use Next.js App Router `(public)/crowdfund/[slug]/page.tsx` with `generateMetadata` for OG tags + `revalidate: 60` for ISR. Hero image / video lazy-loaded.

**Reason**: CROWDFUND sub-type fits because mockup shows a single page-per-campaign + impact breakdown + milestones timeline + updates feed + donor wall + share buttons + goal-based progress with goal-exceeded behaviors. Not P2P_FUNDRAISER (no supporter child pages). Not DONATION_PAGE (much richer content with story + milestones + updates — DONATION_PAGE is for the simple online donation widget). `single-page-record` storage works because each crowdfund is one row owning its content via jsonb arrays. `custom-with-fallback` slug matches the mockup's slug field with `/campaign/` prefix display. `save-all` matches the mockup's explicit Save Changes + Publish buttons (no autosave UX shown). SSR for public page is critical for OG meta + organic-search.

**Backend Patterns Required**:

For CROWDFUND (single-page-record — entity already exists from #16):

- [x] **EXISTING from #16** (no rebuild — reuse):
  - GetAllCrowdFundList (admin list — already powers #16's cards grid)
  - GetCrowdFundById (admin editor)
  - GetCrowdFundSummary (admin KPI tiles)
  - GetCrowdFundStats (admin drawer projection — reuse for setup-screen status bar)
  - CreateCrowdFund (Quick-Create — reuse for "+ Create Campaign Page" if #173 routes to this screen instead of opening Quick-Create dialog)
  - UpdateCrowdFund (will be MODIFIED — see below)
  - DuplicateCrowdFund / DeleteCrowdFund
  - PublishCrowdFund / UnpublishCrowdFund / CloseCrowdFund / ArchiveCrowdFund

- [x] **NEW handlers added by THIS screen**:
  - GetCrowdFundBySlug query (public anonymous-allowed, status-gated)
  - ValidateCrowdFundForPublish query (admin — returns missing-fields list)
  - GetCrowdFundEmbedCode query (admin — share-as-widget; optional V2)
  - InitiateCrowdFundDonation public mutation (anonymous, rate-limited, csrf-protected)
  - ConfirmCrowdFundDonation public mutation (gateway callback handler)

- [x] **MODIFIED handler**:
  - UpdateCrowdFund — extend to support per-tab partial save (fieldMask or null-means-no-change). Backward compatible — Quick-Edit from #16 still works.

- [x] Slug uniqueness validator + reserved-slug rejection (already from #16)
- [x] Tenant scoping (CompanyId from HttpContext for admin; CompanyId resolved from slug for public)
- [x] Anti-fraud throttle on public submit endpoints (NEW)
- [ ] Donation persistence handled by existing `fund.GlobalDonations` pipeline — this page configures the funnel + accepts donate-button submit; donations are recorded by existing pipeline

**Frontend Patterns Required**:

For CROWDFUND — TWO render trees:

- [x] Admin setup at `setting/publicpages/crowdfundingpage` — list view (when `?id` not present) + tabbed editor with live preview (`?id=N`)
- [x] Editor: 6-tab layout (Basic / Content / Donation Settings / Milestones / Updates / Design)
- [x] Live Preview pane on every tab (split-pane: editor left + preview right with desktop/mobile device-switcher)
- [x] Public anonymous route at `(public)/crowdfund/[slug]/page.tsx` — SSR; 2-col body (story+impact+milestones+updates+donors+FAQ / progress+donate+share)
- [x] Public donate form — single-submit anonymous flow with CSRF + honeypot + rate-limit (NO multi-step wizard — single page)
- [x] OG meta-tag generation via `generateMetadata` per public route
- [ ] No child wizard (no "Start Fundraiser" equivalent — CROWDFUND has only one page level)
- [ ] No leaderboard (no per-fundraiser ranking — TOP donors via donor-wall only)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: TWO surfaces — admin setup (6-tab editor + live preview) and public donor-facing page. Each must match the corresponding mockup exactly.

### 🎨 Visual Treatment Rules (apply to all surfaces)

1. **Public surface is brand-driven** — use tenant `PrimaryColorHex` (`--accent`) + `AccentColorHex` (`--accent-light`) + `BackgroundColorHex` + Logo + Hero Image. Do NOT re-use admin shell chrome.
2. **Admin setup mirrors live preview** — preview pane updates within 300ms of edit; never "save and refresh".
3. **Mobile preview is mandatory** — most donors are mobile. Device-switcher (Desktop / Mobile) toggles preview viewport.
4. **Lifecycle state is visually clear** — Status badge in admin header (color-coded per #16 statuses), banner on public Closed preview, "PREVIEW — NOT YET LIVE" overlay on Draft preview.
5. **Donate CTA is dominant** — `PrimaryColorHex` background, sized to prompt action; sticky on mobile public.
6. **Trust signals first-class** — 🔒 Secure / 💳 Cards / ✉ Receipt / Privacy footer / "Powered by {org}" always visible.
7. **Settings cards consistent chrome** — bordered card + 12px radius + 1px border-color border + section title with Lucide icon + body. Same chrome across all 6 tabs.
8. **Tabs are NOT the tab+content card pattern from MASTER_GRID** — tab nav rounds top corners; settings card rounds bottom corners; they visually attach as one element.
9. **Tokens (not hex/px)** — per memory `feedback_ui_uniformity.md` — KPI tile / status badge / chip uses SOLID `bg-X-600 text-white`; no `bg-X-50/100` or `text-X-700/800`; no inline px (use tokens like `gap-2`, `p-4`).

**Anti-patterns to refuse**:
- Admin chrome bleeding into public route (sidebar visible to anonymous donors)
- "Save and refresh to preview" on any tab
- Public page rendering admin breadcrumbs
- Single hero image stretched without responsive crop
- Donor wall rebuilt on every public render (must be cached 60s)
- Goal-met state hidden — must show "🎉 Goal met!" prominently
- Milestones marked "Reached" without server-side TotalRaised verification (admin override drift)
- Stretch goal field visible when GoalExceededBehavior ≠ 'ShowStretchGoal'
- Donate button live when PageStatus = Closed
- Inline hex / px in `style={{...}}` outside designated brand/category-gradient renderers

---

### 🅰️ Admin Setup UI

**Stamp**: `Layout Variant: tabbed-with-preview` (6 tabs; every tab has split-pane editor + live preview pane). The editor list-view (when no `?id`) is `widgets-above-grid` (4 KPI summary cards above campaign list — **SAME LIST AS #16's cards-grid; this screen REUSES #16's list view component when in list mode**). Use Variant B (ScreenHeader + showHeader=false) — same FlowDataTableContainer pattern as #170 P2PCampaignPage — to avoid double-header bug.

#### A.1 — Admin List View (when no `?id` query param)

> **REUSE #16**: This view is functionally identical to #16's cards-grid. Implementation strategy: import #16's `<CrowdFundCardsGrid>` and `<CrowdFundKpiWidgets>` components and render them under THIS screen's ScreenHeader + route. Click on a card name OR Edit action → routes to THIS screen's `?id=N` setup editor (NOT #16's drawer). The drawer on #16's view stays as the lightweight monitoring detail panel.

**Page Layout**:

```
┌──────────────────────────────────────────────────────────────────────┐
│ [Crowdfunding Page Editor]            [+ Create Campaign Page]        │
│ Configure and publish public crowdfunding campaign pages              │
├──────────────────────────────────────────────────────────────────────┤
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                 │
│ │📢 Active │ │💰 Total  │ │👥 Total  │ │🏆 Goals │                  │
│ │Campaigns │ │Raised    │ │Donors    │ │Met       │                  │
│ │    3     │ │$163,300  │ │ 1,880    │ │    1     │                  │
│ │Total: 5  │ │Across all│ │Unique    │ │20% comp. │                  │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘                 │
├──────────────────────────────────────────────────────────────────────┤
│ [🔍 Search campaigns...]   [All(5)] [Active(3)] [Goal Met(1)] [Draft(1)] │
├──────────────────────────────────────────────────────────────────────┤
│ {Cards-grid — REUSE from #16 — auto-fill minmax(320px,1fr)}          │
└──────────────────────────────────────────────────────────────────────┘
```

**Page Header**:
- H1: "Crowdfunding Page Editor"
- Subtitle: "Configure and publish public crowdfunding campaign pages"
- Header Action: `[+ Create Campaign Page]` primary button → opens a quick-create modal (8 fields — same as #16's Quick-Create dialog) → on submit creates Draft + redirects to setup form `?id={newId}`

**KPI Widgets** (4 cards — REUSE from #16):

| # | Icon | Color | Label | Value | Subtitle |
|---|------|-------|-------|-------|----------|
| 1 | `Megaphone` Lucide | teal | Active Campaigns | summary.activeCount | Total: summary.totalCount |
| 2 | `HandCoins` Lucide | green | Total Raised | summary.totalRaised (currency) | Across all campaigns |
| 3 | `Users` Lucide | blue | Total Donors | summary.totalDonors (int) | Unique supporters |
| 4 | `Trophy` Lucide | purple | Goals Met | summary.goalMetCount | {summary.completionRate}% completion rate |

Per memory `feedback_widget_icon_badge_styling.md`: SOLID `bg-X-600 text-white`. NEVER `bg-X-50/100`.

**Filter Bar**:
- Left: `[🔍 Search campaigns by name, category...]` text input
- Right: 4 filter chips: `All (count)` (default active) / `Active (count)` / `Goal Met (count)` / `Draft (count)`

**Cards Grid** (REUSE from #16's `<CrowdFundCardsGrid>`):
- `display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1.25rem;`
- Per card: hero gradient (160px height, category-color) + status badge floating top-right + name (clickable → `?id={id}` to enter this editor — NOT #16's drawer) + progress bar + raised/goal/% + meta row (donor count + ends-date) + actions row (Edit / View Page / Dashboard or status-dependent variants)

**Empty / Loading / Error states**: same as #16's list view.

#### A.2 — Admin Setup Editor (when `?id=N`)

**Page Layout** (mockup-pixel-match):

```
┌──────────────────────────────────────────────────────────────────────┐
│ [← Back to list]  [Edit: Build a School in Kenya]   [Cancel] [Save Draft] [🚀 Publish] │
│ Configure all aspects of your public crowdfunding campaign page       │
├──────────────────────────────────────────────────────────────────────┤
│ ●Active   Raised: $38,400   Donors: 345   Days Left: 52   Last Don: 2h ago │  ← Status Bar (only when editing existing)
├──────────────────────────────────────────────────────────────────────┤
│ [ℹ Basic | 📝 Content | 💲 Donation Settings | 🚩 Milestones | 📢 Updates | 🎨 Design ] │  ← Tab Nav (6 tabs)
├──────────────────────────────────────┬───────────────────────────────┤
│ EDITOR (left, ~58%)                  │ LIVE PREVIEW (right, ~42%)    │
│ {Active tab content}                 │ [Desktop ▼] [Mobile]          │
│ ...                                  │ ┌─────────────────────────┐   │
│                                      │ │ {Browser chrome mockup} │   │
│                                      │ │  ─ pss2.com/crowdfund/  │   │
│                                      │ │    build-a-school-kenya │   │
│                                      │ │ {Public page render     │   │
│                                      │ │  with current settings} │   │
│                                      │ └─────────────────────────┘   │
├──────────────────────────────────────┴───────────────────────────────┤
│ [Cancel] [Save Draft] [Preview Page] [🚀 Publish]                     │  ← Form Footer (persistent)
└──────────────────────────────────────────────────────────────────────┘
```

**Header Actions** (top right):

| Action | Style | Icon | Visibility |
|--------|-------|------|------------|
| Cancel | outline-secondary | `X` | always — navigates back to list, prompts on unsaved changes |
| Save Draft | outline-accent | `Save` | always |
| Publish | primary-accent | `Rocket` | always — runs Validate-for-Publish on click; shows missing-fields modal if invalid |

**Status Bar** (only when editing existing — not on `?id=new`): horizontal bar with current PageStatus dot + label + 4 aggregate stats (Raised / Donors / Days Left or Always Active / Last Donation timestamp). Days Left turns amber when < 7, red when < 2.

**Tab Nav** (6 tabs, horizontal scrollable on mobile):

| # | Tab | Icon (Lucide) | Tab ID |
|---|-----|---------------|--------|
| 1 | Basic | `Info` | `tab-basic` |
| 2 | Content | `FileText` | `tab-content` |
| 3 | Donation Settings | `HandCoins` | `tab-donation` |
| 4 | Milestones | `Flag` | `tab-milestones` |
| 5 | Updates | `Newspaper` | `tab-updates` |
| 6 | Design | `Palette` | `tab-design` |

**TAB 1 — Basic** (single full-width settings-card, 4-3-3 col grid on desktop, stacks on mobile):

| # | Field | Type | Required | Default / Options | Persists to |
|---|-------|------|----------|-------------------|-------------|
| 1 | Campaign Name | text (col-md-8) | YES | — | CrowdFund.CampaignName |
| 2 | Slug | composite (col-md-4): readonly base `/crowdfund/` + editable slug + copy button | YES | auto-from-name | CrowdFund.Slug |
| 3 | Goal Amount + Currency | currency input-group (col-md-4): Currency select (USD/EUR/GBP/INR) + amount text | YES | USD, 50000 | CrowdFund.Currency + CrowdFund.GoalAmount |
| 4 | Start Date | date (col-md-4) | YES | — | CrowdFund.StartDate |
| 5 | End Date | date (col-md-4) | YES | — (validate > Start) | CrowdFund.EndDate |
| 6 | Linked Donation Purpose | ApiSelect (col-md-4) | YES | options from `getAllDonationPurposeList` | CrowdFund.DonationPurposeId |
| 7 | Campaign Category | plain `<Select>` (col-md-4) | YES | 6 enum options (Education/Healthcare/Emergency/Environment/Community/Other) | CrowdFund.CampaignCategory |
| 8 | Organizational Unit | ApiSelect (col-md-4) | NO | options from `getAllOrganizationalUnitList` | CrowdFund.OrganizationalUnitId |

**Footer**: `[Cancel] [Save Changes]` (saves Tab 1 fields only; partial update)

**TAB 2 — Content** (sectioned card, mostly full-width 12-col rows):

> All fields persist to CrowdFund.* — Content tab is a deep editor for the storytelling layer.

| Field | Type | Persists to |
|-------|------|-------------|
| Headline | text input (full-width) | CrowdFund.Headline |
| Hero Image / Video | upload-area (1200x630 image OR YouTube URL paste) — drag-drop + click-to-select; preview thumb after upload | CrowdFund.HeroImageUrl (if uploaded) OR CrowdFund.HeroVideoUrl (if URL) |
| Campaign Story | rich-text editor (toolbar: B/I/U / list-ul/ol / link/image), min-h 150px | CrowdFund.StoryRichText |
| **Impact Breakdown** | bordered list editor with `+ Add Impact Level` dashed button — each row `{amount input | description input | remove ×}` | CrowdFund.ImpactBreakdownJson (jsonb array) |
| **FAQ Section** | bordered list editor with `+ Add FAQ` button — each row `{question input | answer textarea | remove ×}` | CrowdFund.FaqJson (jsonb array) |

**Impact Breakdown Editor** (mockup lines 707-737):
```
┌───────────────────────────────────────────────────────────┐
│ $50    [Provides a desk and chair for one student]   [×]  │
│ $100   [Funds a teacher's salary for one month]      [×]  │
│ $500   [Builds one section of exterior wall]         [×]  │
│ $1,000 [Completes one full classroom]                [×]  │
│ $5,000 [Builds the school library]                   [×]  │
│        [+ Add Impact Level]                                │
└───────────────────────────────────────────────────────────┘
```
- Each row: amount input (currency, min-w 80px) + description text input (flex 1) + remove × icon (slate hover red)
- Reorder via drag handle on left of each row (V2 — for V1, order is insertion order)
- Validation: amount > 0 + description non-empty (block Save if violated)

**FAQ Editor** (mockup lines 738-756):
- Each row: question text input (full-width bold) + answer textarea (3 rows) + remove × icon
- "+ Add FAQ" dashed button at bottom

**TAB 3 — Donation Settings** (sectioned card with sub-sections):

**Section: Suggested Donation Amounts** (icon `DollarSign`)

| Field | Type | Notes |
|-------|------|-------|
| Suggested Amounts | chip-editor — pre-filled chips ($50/$100/$250/$500/$1,000/Custom) with × remove + `+ Add` text input + button | Max 6 chips; "Custom" chip is special (stored as flag, not value) |

```
[$50 ×] [$100 ×] [$250 ×] [$500 ×] [$1,000 ×] [Custom (accent-tinted) ×]
[Add amount...] [+ Add]
```
- Custom chip toggles `AllowCustomAmount` flag (NOT in chip array)
- Numeric chips array (max 6) stored in `AmountChipsJson`

**Section: Donation Options** (icon `Settings2`) — toggle list:

| Toggle | Default | Persists to |
|--------|---------|-------------|
| Allow Recurring Donations | ON | AllowRecurringDonations |
| Allow Anonymous Donations | ON | AllowAnonymousDonations |
| Offer "Cover Processing Fees" Option | ON | AllowDonorCoverFees |

**Section: Payment Methods** (icon `CreditCard`, col-md-6) — checkbox list of available gateways:

| Method | Icon | Default | Persists to |
|--------|------|---------|-------------|
| Stripe | brand color #635bff | ON | EnabledPaymentMethodsJson += "stripe" |
| PayPal | brand color #003087 | ON | EnabledPaymentMethodsJson += "paypal" |
| Apple Pay / Google Pay | (future — show but disabled if gateway not configured) | OFF | EnabledPaymentMethodsJson += "applepay" |
| Bank Transfer | (future) | OFF | EnabledPaymentMethodsJson += "banktransfer" |

> Methods sourced from existing `fund.CompanyPaymentGateways` for tenant. If gateway not configured, checkbox is disabled with tooltip "Configure in Payment Gateways setup".

**Section: Display Options** (icon `Eye`, col-md-6) — toggle list:

| Toggle | Default | Persists to |
|--------|---------|-------------|
| Show Goal Thermometer | ON | ShowGoalThermometer |
| Show Donor Count | ON | ShowDonorCount |
| Show Donor Wall | ON | ShowDonorWall |

**Section: When Goal is Exceeded** (full-width radio group):

| Option | Default | Persists to |
|--------|---------|-------------|
| Keep accepting donations | selected | GoalExceededBehavior='KeepAccepting' |
| Auto-close campaign | — | GoalExceededBehavior='AutoClose' |
| Show stretch goal | — (when selected, reveals StretchGoalAmount input below) | GoalExceededBehavior='ShowStretchGoal' + StretchGoalAmount field |

**Conditional**: When `ShowStretchGoal` selected, show currency input "Stretch Goal Amount" (validation: must be > GoalAmount).

**TAB 4 — Milestones** (sectioned card):

**Header**: "Define campaign milestones to show donors the progress and impact of their contributions."

**Milestones List** (bordered card; each row = one milestone):

```
┌─────────────────────────────────────────────────────────────┐
│ ✓  Foundation Laid                                          │
│    25% — $12,500                              [Reached]  [✏] │
├─────────────────────────────────────────────────────────────┤
│ ✓  Walls Up                                                 │
│    50% — $25,000                              [Reached]  [✏] │
├─────────────────────────────────────────────────────────────┤
│ ⟳  Roof & Interiors                                         │
│    75% — $37,500                          [In Progress] [✏] │
├─────────────────────────────────────────────────────────────┤
│ ⚑  Grand Opening                                            │
│    100% — $50,000                            [Upcoming] [✏] │
└─────────────────────────────────────────────────────────────┘
      [+ Add Milestone]
```

| Component | Type | Notes |
|-----------|------|-------|
| Marker icon | status-driven (Reached=green check / InProgress=blue spinner / Upcoming=slate flag) | 32px circle |
| Name | text input (inline edit on ✏ click) | required |
| Percentage | int input (0-100) | required |
| Amount | computed display `percentage / 100 × GoalAmount` (read-only) | server-recomputes on Save |
| Status | dropdown: Reached / InProgress / Upcoming | admin can override; default auto-computed by handler based on actual TotalRaised vs threshold |
| Edit | ✏ icon → inline edit mode (or modal for richer fields) | — |
| Delete | × icon (with confirm) | block delete if status=Reached and donations crossed threshold (warn) |

**"+ Add Milestone"** dashed button at bottom → adds new row in edit mode with empty fields. Persists to `MilestonesJson`.

**Validation**: name non-empty, percentage 0-100, status valid enum.

**TAB 5 — Updates** (sectioned card):

**Header**: "Keep donors informed with progress updates on the campaign."

**Updates Table**:

| Date | Title | Content (excerpt) | Actions |
|------|-------|--------------------|---------|
| Apr 10, 2026 | **Foundation Complete!** | We are thrilled to announce that the school foundation... | [Edit] [Delete] |
| Mar 25, 2026 | **Construction Begins** | Ground was broken on March 20th... | [Edit] [Delete] |
| Mar 1, 2026 | **Campaign Launch** | Thank you for supporting our mission!... | [Edit] [Delete] |

**"+ Post Update"** button → opens modal with:
- Update Date (date picker, defaults to today)
- Title (text input)
- Content (rich-text editor, min-h 200px, B/I/list/link/image toolbar)
- [Cancel] [Save Update] buttons

Persists to `UpdatesJson` (jsonb array). Sorted desc by Date on render.

Edit → opens modal pre-filled. Delete → confirm "Delete this update? Donors who received it via email will still have it in their inbox."

**TAB 6 — Design**:

**Section: Theme Colors** (col-md-6, icon `Palette`):

| Field | Type | Default | Persists to |
|-------|------|---------|-------------|
| Primary Color | color-picker + hex text | `#0e7490` | PrimaryColorHex |
| Accent Color | color-picker + hex text | `#06b6d4` | AccentColorHex |
| Background Color | color-picker + hex text | `#ffffff` | BackgroundColorHex |

**Section: Logo / Branding** (col-md-6):

| Field | Type | Persists to |
|-------|------|-------------|
| Organization Logo | compact upload-area (drag-drop image, 150x50 recommended) | LogoUrl |
| Font Family | plain `<Select>`: System Default (Inter/Segoe UI) / Georgia (Serif) / Poppins / Open Sans | FontFamily |

**Section: Custom Sections** (full-width — col-12, icon `Eye`):

> "Toggle which sections appear on the public campaign page"

7 checkboxes in 2-col grid:

| Checkbox | Default | Persists to |
|----------|---------|-------------|
| Impact Breakdown | ON | EnabledSectionsJson.impact |
| Milestone Timeline | ON | EnabledSectionsJson.milestones |
| Updates Feed | ON | EnabledSectionsJson.updates |
| Donor Wall | ON | EnabledSectionsJson.donorWall |
| FAQ Section | ON | EnabledSectionsJson.faq |
| Share Buttons | ON | EnabledSectionsJson.shareButtons |
| Countdown Timer | OFF | EnabledSectionsJson.countdown |

**Optional sub-section: SEO & Social Sharing** (collapsible, hidden by default — admin expands):

| Field | Type | Persists to |
|-------|------|-------------|
| OG Title | text input (defaults to CampaignName) | OgTitle |
| OG Description | textarea (defaults to Headline) | OgDescription |
| OG Image | compact upload-area (1200x630) | OgImageUrl |
| Default Share Message | textarea | DefaultShareMessage |
| Robots Indexable | toggle (default ON) | RobotsIndexable |

#### A.3 — Live Preview Pane (sticky right-side, ~480px wide)

**Preview Toolbar**:
- Label: "Live Preview" + icon `Eye`
- Device-switcher toggle group: `[💻 Desktop]` (default selected) / `[📱 Mobile]`
- "Open in new tab" button (top right) → opens public preview in new tab with preview-token

**Desktop variant**: `<BrowserChrome>` mockup
- Red/yellow/green dots (browser-topbar)
- URL bar showing `pss2.com/crowdfund/{slug}` with green lock icon
- Scrollable body max-h 780px

**Mobile variant**: `<PhoneFrame>`
- Notch + 1.75rem rounded inner
- Scrollable phone-screen max-h 650px
- Renders 2-col body stacked vertically (single column)

**Preview content**: renders the actual public-page composition with current settings applied — debounced 300ms on edit.

**Form Footer** (persistent across all 6 tabs, full-width below settings card):

| Button | Style | Icon |
|--------|-------|------|
| Cancel | outline-secondary | — |
| Save Draft | outline-accent | `Save` |
| Preview Campaign Page | outline-accent | `Eye` (opens public preview in new tab) |
| 🚀 Publish Campaign | primary-accent | `Rocket` |

---

### 🅱️ Public Campaign Page (`/crowdfund/{slug}`)

**Page Layout** (full-width hosted; SSR; renders only when PageStatus IN ('Published', 'Active', 'GoalMet', 'Closed'); 404 for Draft (unless preview-token); 410 for Archived):

```
┌────────────────────────────────────────────────────────────────────┐
│ {Org Header Navbar — gradient brand bar}                            │
│ [💗 {Org Name}]                  [Home] [About] [Campaigns] [Contact]│
├────────────────────────────────────────────────────────────────────┤
│ {Hero — gradient banner with category icon}                         │
│                                                                     │
│                        🏫                                           │
│                                                                     │
├──────────────────────────────────┬──────────────────────────────────┤
│ LEFT (~60%)                       │ RIGHT (~40%, STICKY)             │
│                                   │                                  │
│ Help Us Build a School for 500    │ $38,400                          │
│ Children in Rural Kenya           │ raised of $50,000 goal           │
│                                   │ ██████████░░░░ 76.8%             │
│ [Hope Foundation] [Education]     │ 345 donors · 52 days left        │
│                                   │                                  │
│ Story rich text...                │ ┌─────── Donate Form ────────┐  │
│                                   │ │ Choose an Amount           │  │
│ ─── Your Impact ───               │ │ [$50] [$100●] [$250]       │  │
│ 🪑 $50    Desk and chair          │ │ [$500] [$1K] [Custom]      │  │
│ 👨‍🏫 $100 Teacher salary           │ │ ☑ Make it monthly          │  │
│ 🧱 $500   Wall section            │ │ ☑ Cover processing fees    │  │
│ 🚪 $1,000 Full classroom          │ │                            │  │
│ 📚 $5,000 School library          │ │ [❤ DONATE NOW]             │  │
│                                   │ │ 🔒 Secure via Stripe/PayPal │  │
│ ─── Campaign Milestones ───       │ └────────────────────────────┘  │
│ (Timeline)                        │                                  │
│ ✓ Foundation Laid 25% — Reached   │ Share This Campaign              │
│ ✓ Walls Up 50% — Reached          │ [FB][X][WA][LI][Copy]            │
│ ⟳ Roof & Interiors 75% — Progress │                                  │
│ ⚑ Grand Opening 100% — Upcoming   │                                  │
│                                   │                                  │
│ ─── Campaign Updates ───          │                                  │
│ Apr 10 — Foundation Complete!     │                                  │
│ Mar 25 — Construction Begins      │                                  │
│ Mar 1  — Campaign Launch          │                                  │
│                                   │                                  │
│ ─── Recent Supporters ───         │                                  │
│ {avatar} James M. — $1,000        │                                  │
│   "Education changes everything"  │                                  │
│ {avatar} Sarah R. — $250          │                                  │
│ {avatar} Anonymous — $500         │                                  │
│ {avatar} David L. — $100          │                                  │
│                                   │                                  │
│ ─── FAQ (accordion) ───           │                                  │
│ ▾ Where will the school be built? │                                  │
│   In Makueni County...            │                                  │
│ ▸ How will funds be used?         │                                  │
│ ▸ When will school be completed?  │                                  │
├──────────────────────────────────┴──────────────────────────────────┤
│ {Footer: Org © 2026 · Privacy · Terms · Contact}                    │
└────────────────────────────────────────────────────────────────────┘
```

#### B.1 — Org Header Navbar (full-width gradient bar)

- Linear-gradient(135deg, PrimaryColorHex, AccentColorHex) background
- Left: Logo + org name (white text, font-weight 700)
- Right: nav links (Home / About Us / Campaigns / Contact) — opacity-80 white, hover white

#### B.2 — Hero (240px height, full-width gradient)

- Linear-gradient(135deg, rgba(PrimaryColorHex, 0.85), rgba(AccentColorHex, 0.65)) over solid bg
- Category icon centered (e.g. `GraduationCap` for Education, `HeartPulse` for Healthcare, `HousePulse` for Emergency, `Droplets` for Environment, `Users` for Community)
- If HeroImageUrl set, hero shows the image with gradient overlay; if HeroVideoUrl set, hero shows lazy-loaded YouTube/Vimeo embed; if neither, hero shows category icon over gradient (mockup default)

#### B.3 — Two-Column Content (flex; min-height 500px)

**Left Column** (`flex: 6; padding: 1.5rem; border-right: 1px solid border-color`):

**Headline**: `font-size: 1.375rem; font-weight: 800; line-height: 1.3;` (full campaign headline from Content.Headline)

**Org & Category Tags**:
- Org tag: pill with org name + Heart icon, bg = `--accent-bg`, color = `--accent`
- Category tag: pill with category name + category icon, bg = green-50, color = green-700

**Story** (`pub-story`): rich-text rendered from `StoryRichText` with proper paragraph spacing (`line-height: 1.7; color: text-secondary;`)

**Your Impact Section** (when `EnabledSectionsJson.impact = true`):
- Section title: "Your Impact" + `HandHeart` icon (accent-tinted)
- Rows from `ImpactBreakdownJson`:
  - Icon (36px circle, accent-bg + accent-color, contextual icon: Chair/Chalkboard/Bricks/DoorOpen/BookOpen mapped from description keywords OR fallback DollarSign)
  - Amount (bold accent, min-w 50px, `$X`)
  - Description (slate-900)
  - Hover state: `bg: --accent-bg`
- Empty state: "Impact breakdown not yet defined."

**Campaign Milestones Section** (when `EnabledSectionsJson.milestones = true`):
- Section title: "Campaign Milestones" + `FlagCheckered` icon (accent-tinted)
- Vertical timeline with 2px slate-200 line on left
- Rows from `MilestonesJson` (sorted by percentage asc):
  - 28px dot (left -2rem, status-colored: reached=green-100/green-600 bordered green-500, in-progress=blue-100/blue-600 bordered blue-500, upcoming=slate-100/slate-400 bordered slate-200)
  - Status-driven inner icon: Check / Spinner / Flag
  - Title (bold slate-900)
  - Meta line: `{percentage}% — ${amount} • Status` (status colored: reached=green-600 bold / in-progress=blue-600 bold / upcoming=slate-500)
- Empty state: "Milestones not yet defined."

**Campaign Updates Section** (when `EnabledSectionsJson.updates = true`):
- Section title: "Campaign Updates" + `Newspaper` icon (accent-tinted)
- Rows from `UpdatesJson` (sorted desc by Date):
  - Date (small accent bold)
  - Title (slate-900 semi-bold)
  - Text excerpt (first 200 chars + "Read more" expand)
- Empty state: "No updates posted yet."

**Recent Supporters Section** (when `EnabledSectionsJson.donorWall = true`):
- Section title: "Recent Supporters" + `Users` icon (accent-tinted)
- Top-10 rows from `getCrowdFundStats.recentDonors` query (server-cached 60s):
  - 36px circle avatar with initials (colored bg per donor: rotating teal/pink/green/amber based on name hash) OR "AN" with slate bg when anonymous
  - Donor name (bold slate-900) OR "Anonymous"
  - Amount (bold accent)
  - Message preview (italic slate-500, line-clamp-1) — optional from donation.Note
  - Time ago (slate-400 small) — `formatRelative(donation.CreatedDate)`
- Empty state: "Be the first to support this campaign!"

**FAQ Accordion Section** (when `EnabledSectionsJson.faq = true`):
- Section title: "Frequently Asked Questions" + `CircleHelp` icon (accent-tinted)
- Bordered card containing accordion rows from `FaqJson`:
  - Question (slate-900 bold) + ChevronDown indicator (rotates on open)
  - Answer (slate-500, line-height 1.6) — hidden until expanded; first row expanded by default
- Empty state: hide section entirely

**Right Column** (`flex: 4; padding: 1.5rem; background: slate-50; position: sticky; top: 0`):

**Progress Widget**:
- `pw-raised` ($38,400) — 2rem bold accent
- `pw-goal` ("raised of $50,000 goal") — slate-500
- Progress bar (12px height, slate-200 track, gradient fill from PrimaryColor→AccentColor)
  - When TotalRaised ≥ GoalAmount: fill green-600→green-500 + show "🎉 Goal met!" label
  - When GoalExceededBehavior='ShowStretchGoal' AND goal met: render secondary progress bar for stretch goal, label "Stretch goal: ${stretchAmount}"
- Stats row: "{donors} donors · {daysLeft} days left" (daysLeft turns red when <2)
  - When Closed: "Ended {N} days ago" / "Ended today"
  - When GoalExceededBehavior='AutoClose' AND TotalRaised ≥ GoalAmount: "Goal met — no longer accepting donations"

**Donate Form** (bordered card):
- Heading: "Choose an Amount" (font-weight 700)
- Amount grid (3×2):
  - Each chip: 0.625rem padding, 2px slate-200 border, white bg, slate-900 bold; hover/selected = 2px accent border + accent-bg + accent text
  - Last chip is "Custom" (smaller font 0.75rem) → on click reveals number input below
- "Make it monthly" toggle row (light slate-50 bg, 0.5rem gap): checkbox + label "Make it monthly ({selectedAmount}/month)" — only visible when `AllowRecurringDonations=true`
- "Cover processing fees" toggle row: checkbox + label "Cover processing fees so 100% goes to the cause (+$2.90)" — fee calculated dynamically based on amount × 2.9% + $0.30 — only visible when `AllowDonorCoverFees=true`
- "Anonymous donation" toggle — only visible when `AllowAnonymousDonations=true` (defaults OFF on form)
- Donor name + email inputs (collapsible — required unless Anonymous toggle ON)
- [Donate Now] button: full-width, primary-accent bg, white text, font-weight 700, 0.875rem padding, with Heart icon
  - On submit: client-side validate → POST `initiateCrowdFundDonation` mutation with `{slug, amount, isMonthly, coverFees, donorEmail, donorName?, isAnonymous, csrfToken, honeypot, idempotencyKey}` → redirect to gateway / show in-form gateway iframe → on success show thank-you state
- Below button: "🔒 Secure payment via Stripe & PayPal" (tiny slate-500)

**Share This Campaign Section** (when `EnabledSectionsJson.shareButtons = true`):
- Heading: "Share This Campaign" (font-weight 700)
- 5 share buttons (36px circle, white icon, brand-color bg):
  - Facebook (#1877f2)
  - X / Twitter (#1da1f2)
  - WhatsApp (#25d366)
  - LinkedIn (#0a66c2)
  - Copy Link (#64748b) — on click copies `{baseUrl}/crowdfund/{slug}` to clipboard with toast
- Hover: opacity 0.85

#### B.4 — Public Footer

- 1px slate-200 border-top
- slate-50 bg
- Centered: "{Org} © {year} — Privacy Policy · Terms of Service · Contact Us"
- Links accent-colored

#### B.5 — Public-route behavior

- SSR with `revalidate: 60` (campaign metadata caches 60s; OG tags pre-rendered)
- Anonymous-allowed route (no auth gate); CSP headers strict
- CSRF token issued in initial render via cookie; required on submit
- Honeypot field hidden in form
- On submit: client-side gateway tokenize → server creates donation intent → redirect to thank-you state
- On gateway failure: inline error banner, retain form state
- On success: thank-you state inline (full-page success card with "Thank You, {name}!" + receipt-incoming message + share buttons) OR redirect to configured URL; receipt email fires async

#### B.6 — Edge states

| State | Trigger | UI |
|-------|---------|----|
| `Status = Draft` | unknown viewer | 404 (unless preview-token in query string) |
| `Status = Draft` + preview-token | admin "Open in new tab" | Renders full page with "PREVIEW — NOT YET LIVE" amber banner overlay at top |
| `Status = Closed` | EndDate passed OR admin Close | Renders page with "This campaign has ended" banner under hero; donate form hidden/disabled; show final raised |
| `Status = GoalMet + GoalExceededBehavior=AutoClose` | TotalRaised ≥ GoalAmount + auto-close | Renders with "🎉 Goal met!" banner; donate disabled; "Thank you for your support" |
| `Status = GoalMet + GoalExceededBehavior=ShowStretchGoal` | TotalRaised ≥ GoalAmount + stretch | Renders with stretch goal progress bar; donate still live; "Help us reach our stretch goal of ${X}" |
| `Status = GoalMet + GoalExceededBehavior=KeepAccepting` | TotalRaised ≥ GoalAmount + keep | Renders normally with "🎉 Goal met!" cheerful label; donate still live |
| `Status = Archived` | admin Archive | 410 Gone |
| `PageStatus IN ('Active','GoalMet') AND EnabledPaymentMethodsJson empty` | misconfigured | "Donations temporarily unavailable — please contact the organization" |
| `now() < StartDate` | scheduled future | Renders page with "Campaign starts {StartDate}" banner; donate hidden |

---

## ⑦ Substitution Guide

> Canonical reference for EXTERNAL_PAGE / CROWDFUND: **none yet established** — THIS is the first CROWDFUND sub-type build. Closest sibling for substitution: **P2PCampaignPage #170** (EXTERNAL_PAGE / P2P_FUNDRAISER) — copy patterns for: live-preview pane, save-all model, OG meta SSR, public-route hardening, slug-immutability. Diverge from P2P for: single-page-record (NOT parent-with-children), 6-tab editor (NOT 5-tab), no "Start Fundraiser" wizard, no leaderboard, sticky-sidebar donate form (NOT separate donate page), Goal-Exceeded behavior radio group.

| Canonical (P2PCampaignPage) | → This Entity (CrowdFundingPage) | Context |
|------------------------------|----------------------------------|---------|
| P2PCampaignPage | CrowdFundingPage | Entity / FE folder concept name (note: BE entity is `CrowdFund` from #16; this screen's BE addition is named `*CrowdFundPage*` for the public/setup-specific handlers) |
| p2pCampaignPage | crowdFundingPage | camelCase / variable |
| p2pcampaignpage | crowdfundingpage | kebab / route folder |
| P2PCAMPAIGNPAGE | CROWDFUNDINGPAGE | MenuCode / UPPER |
| fund (schema) | fund (schema) | Same schema |
| DonationModels (group) | DonationModels (group) | Same group |
| P2P_FUNDRAISER (sub-type) | CROWDFUND (sub-type) | external_page_subtype frontmatter |
| `/p2p/{slug}` (public) | `/crowdfund/{slug}` (public) | Public route |
| `setting/publicpages/p2pcampaignpage` (admin) | `setting/publicpages/crowdfundingpage` (admin) | Admin route |
| 5 tabs (Basic Info / Fundraiser Settings / Donation Settings / Branding & Page / Communication) | 6 tabs (Basic / Content / Donation Settings / Milestones / Updates / Design) | Tab list |
| parent-with-children (P2PCampaignPage + P2PFundraiser + Team + Milestone + Update) | single-page-record (CrowdFund only; jsonb children) | Storage pattern |
| Layered lifecycle (parent + child) | Single lifecycle (parent only) | Lifecycle scope |
| Tab 4 split-pane live preview only | Every tab split-pane live preview | Live preview scope |

---

## ⑧ File Manifest

> **PREREQUISITE**: #16 CrowdFund entity must be built first (entity + EF config + migration + Schemas + base CRUD + lifecycle commands + Mapster + DecoratorProperty). This screen extends those files; does NOT recreate the entity.

### Backend Files — CROWDFUND (single-page-record — extends existing #16 BE)

**REUSE from #16 (no rebuild — already in code post-#16 build):**

| File | Path | Status |
|------|------|--------|
| Entity | `Pss2.0_Backend/.../Base.Domain/Models/DonationModels/CrowdFund.cs` | from #16 |
| EF Config | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/DonationConfigurations/CrowdFundConfiguration.cs` | from #16 |
| Schemas (DTOs) | `Pss2.0_Backend/.../Base.Application/Schemas/DonationSchemas/CrowdFundSchemas.cs` | from #16 |
| GetAllCrowdFundList query | `…/CrowdFunds/GetAllQuery/GetAllCrowdFunds.cs` | from #16 |
| GetCrowdFundById query | `…/CrowdFunds/GetByIdQuery/GetCrowdFundById.cs` | from #16 |
| GetCrowdFundSummary query | `…/CrowdFunds/GetSummaryQuery/GetCrowdFundSummary.cs` | from #16 |
| GetCrowdFundStats query | `…/CrowdFunds/GetStatsQuery/GetCrowdFundStats.cs` | from #16 |
| CreateCrowdFund command | `…/CrowdFunds/CreateCommand/CreateCrowdFund.cs` | from #16 |
| UpdateCrowdFund command | `…/CrowdFunds/UpdateCommand/UpdateCrowdFund.cs` | **MODIFY** (see below) |
| DeleteCrowdFund / DuplicateCrowdFund | `…/CrowdFunds/{Delete,Duplicate}Command/` | from #16 |
| PublishCrowdFund / UnpublishCrowdFund / CloseCrowdFund / ArchiveCrowdFund | `…/CrowdFunds/LifecycleCommands/` | from #16 |
| CrowdFundQueries endpoint | `…/EndPoints/DonationServiceEndpoints/Queries/CrowdFundQueries.cs` | from #16 (admin) |
| CrowdFundMutations endpoint | `…/EndPoints/DonationServiceEndpoints/Mutations/CrowdFundMutations.cs` | from #16 (admin) |
| DonationMappings | `…/Mappings/DonationMappings.cs` | from #16 (modify to add new DTOs) |

**NEW files added by THIS screen:**

| # | File | Path |
|---|------|------|
| 1 | GetCrowdFundBySlug query (public) | `Pss2.0_Backend/.../Base.Application/CommandQueryHandlers/CrowdFunds/GetBySlugQuery/GetCrowdFundBySlug.cs` |
| 2 | ValidateCrowdFundForPublish query | `…/CrowdFunds/ValidateForPublishQuery/ValidateCrowdFundForPublish.cs` |
| 3 | GetCrowdFundEmbedCode query (optional V2) | `…/CrowdFunds/GetEmbedCodeQuery/GetCrowdFundEmbedCode.cs` |
| 4 | InitiateCrowdFundDonation public mutation | `…/CrowdFunds/PublicMutations/InitiateCrowdFundDonation.cs` |
| 5 | ConfirmCrowdFundDonation public mutation | `…/CrowdFunds/PublicMutations/ConfirmCrowdFundDonation.cs` |
| 6 | CrowdFundSchemas.cs — APPEND DTOs | `…/Base.Application/Schemas/DonationSchemas/CrowdFundSchemas.cs` (append `CrowdFundPublicDto`, `CrowdFundPublicStatsDto`, `ValidationResultDto`, `EmbedCodeDto`, `InitiateDonationDto`, `DonationInitResultDto`, `ConfirmDonationDto`) |
| 7 | CrowdFundPublicQueries endpoint | `…/EndPoints/DonationServiceEndpoints/Public/CrowdFundPublicQueries.cs` (NEW — anonymous-allowed, rate-limited) |
| 8 | CrowdFundPublicMutations endpoint | `…/EndPoints/DonationServiceEndpoints/Public/CrowdFundPublicMutations.cs` (NEW — anonymous-allowed, csrf-protected) |

**Backend MODIFY (single file)**:

| # | File | Change |
|---|------|--------|
| 1 | UpdateCrowdFund.cs | Extend command to support per-tab partial save — accept null fields as "no change" semantics. Add `tabContext: string` param (informational, audit log). Backward-compatible — Quick-Edit from #16 (sends full 8-field payload) still works because all 8 fields are non-null. See §⑫ ISSUE-UPDATE-PARTIAL. |
| 2 | DonationMappings.cs | Add Mapster config for new DTOs (CrowdFund → CrowdFundPublicDto omits sensitive fields; CrowdFundStatsDto → CrowdFundPublicStatsDto omits internal IDs) |
| 3 | CrowdFundQueries.cs | Add `ValidateCrowdFundForPublish` + `GetCrowdFundEmbedCode` GQL field registrations |
| 4 | CrowdFundMutations.cs | (no change — only new public mutations go in PublicMutations endpoint) |
| 5 | `fund.GlobalDonations` CHECK constraint | Modify existing CHECK constraint to add CrowdFundId: `CHECK (NUM_NONNULLS(OnlineDonationPageId, P2PCampaignPageId, P2PFundraiserId, CrowdFundId) <= 1)` — see §⑫ ISSUE-DONATION-CHECK-CONSTRAINT |
| 6 | Rate-limit policy registration (Program.cs or RateLimit config) | Add `CrowdFundDonationSubmit` policy (5/min/IP/slug) |

### Backend Wiring Updates (one-time)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | (existing from #16) IDonationDbContext / DonationDbContext / DecoratorProperties / DonationMappings | No changes — already wired |
| 2 | Program.cs / Startup public route registration | Register anonymous `/crowdfund/{slug}` route + middleware policies |
| 3 | IMemoryCache (existing) | Cache key `crowdfund:bySlug:{tenantId}:{slug}` (60s TTL) + `crowdfund:recentDonors:{crowdFundId}` (60s TTL) |
| 4 | Anti-fraud middleware (existing per #10/#170) | Apply rate-limit on public POST endpoints |
| 5 | OG meta-tag handler in SSR public route | Pre-render OG tags from CrowdFundPublicDto in `generateMetadata` |

### Frontend Files — CROWDFUND

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/donation-service/CrowdFundingPageDto.ts` (composite DTOs; may extend existing `CrowdFundDto.ts` from #16) |
| 2 | GQL Query (admin) | `Pss2.0_Frontend/src/domain/gql-queries/donation-queries/CrowdFundingPageQuery.ts` (admin queries — may import #16's existing) |
| 3 | GQL Query (public) | `Pss2.0_Frontend/src/domain/gql-queries/public-queries/CrowdFundPublicQuery.ts` (anonymous queries) |
| 4 | GQL Mutation (admin) | `Pss2.0_Frontend/src/domain/gql-mutations/donation-mutations/CrowdFundingPageMutation.ts` (extends #16's mutations + new ValidateForPublish + EmbedCode) |
| 5 | GQL Mutation (public) | `Pss2.0_Frontend/src/domain/gql-mutations/public-mutations/CrowdFundPublicMutation.ts` (InitiateCrowdFundDonation + ConfirmCrowdFundDonation) |
| 6 | Page Config (admin) | `Pss2.0_Frontend/src/page-config/pages/setting/publicpages/crowdfundingpage.tsx` (re-exports default; routes index dispatcher) |
| 7 | Setup List View Page (when no `?id`) | `Pss2.0_Frontend/src/page-config/page-components/setting/publicpages/crowdfundingpage/list-page.tsx` (reuses #16's `<CrowdFundCardsGrid>` + `<CrowdFundKpiWidgets>`) |
| 8 | Setup Editor Page | `Pss2.0_Frontend/src/page-config/page-components/setting/publicpages/crowdfundingpage/editor-page.tsx` (tabbed-with-preview layout; split-pane) |
| 9 | Tab nav component | `…/crowdfundingpage/components/tab-nav.tsx` |
| 10 | Status Bar component | `…/crowdfundingpage/components/status-bar.tsx` (only when editing existing) |
| 11 | Tab 1 — Basic | `…/crowdfundingpage/tabs/basic-tab.tsx` |
| 12 | Tab 2 — Content | `…/crowdfundingpage/tabs/content-tab.tsx` |
| 13 | Tab 3 — Donation Settings | `…/crowdfundingpage/tabs/donation-settings-tab.tsx` |
| 14 | Tab 4 — Milestones | `…/crowdfundingpage/tabs/milestones-tab.tsx` |
| 15 | Tab 5 — Updates | `…/crowdfundingpage/tabs/updates-tab.tsx` |
| 16 | Tab 6 — Design | `…/crowdfundingpage/tabs/design-tab.tsx` |
| 17 | Live Preview pane | `…/crowdfundingpage/components/live-preview.tsx` (device-switcher + browser-chrome / phone-frame) |
| 18 | Impact Breakdown editor | `…/crowdfundingpage/components/impact-breakdown-editor.tsx` (jsonb list editor) |
| 19 | FAQ editor | `…/crowdfundingpage/components/faq-editor.tsx` |
| 20 | Milestones list editor | `…/crowdfundingpage/components/milestones-list-editor.tsx` |
| 21 | Updates table editor + post modal | `…/crowdfundingpage/components/updates-editor.tsx` + `update-post-modal.tsx` |
| 22 | Amount chips editor | `…/crowdfundingpage/components/amount-chips-editor.tsx` |
| 23 | Color picker row | `…/crowdfundingpage/components/color-picker-row.tsx` (reuse from #170 if exists) |
| 24 | Section toggles | `…/crowdfundingpage/components/section-toggles.tsx` |
| 25 | Quick-Create modal (8 fields — header "+ Create Campaign Page") | `…/crowdfundingpage/components/quick-create-modal.tsx` (reuse from #16 if shared component, otherwise local copy) |
| 26 | Publish-validation missing-fields modal | `…/crowdfundingpage/components/publish-validation-modal.tsx` |
| 27 | Lifecycle confirm modals (Publish / Unpublish / Close / Archive) | `…/crowdfundingpage/components/lifecycle-modals.tsx` |
| 28 | Zustand store | `…/crowdfundingpage/store/crowdfundingpage-store.ts` (form state across 6 tabs + active tab + modal state + preview device mode + save-all model) |
| 29 | Zod schemas | `…/crowdfundingpage/schemas/crowdfundingpage-schemas.ts` (per-tab + composite for Publish-validation) |
| 30 | Public page component | `Pss2.0_Frontend/src/page-config/page-components/public/crowdfund/[slug]/page-content.tsx` (the 2-col layout) |
| 31 | Public — Org header | `…/public/crowdfund/[slug]/components/org-header.tsx` |
| 32 | Public — Hero | `…/public/crowdfund/[slug]/components/hero.tsx` |
| 33 | Public — Progress widget | `…/public/crowdfund/[slug]/components/progress-widget.tsx` (sticky right sidebar) |
| 34 | Public — Donate form | `…/public/crowdfund/[slug]/components/donate-form.tsx` (CSRF + honeypot + idempotencyKey) |
| 35 | Public — Impact list | `…/public/crowdfund/[slug]/components/impact-list.tsx` |
| 36 | Public — Milestones timeline | `…/public/crowdfund/[slug]/components/milestones-timeline.tsx` |
| 37 | Public — Updates feed | `…/public/crowdfund/[slug]/components/updates-feed.tsx` |
| 38 | Public — Donor wall | `…/public/crowdfund/[slug]/components/donor-wall.tsx` |
| 39 | Public — FAQ accordion | `…/public/crowdfund/[slug]/components/faq-accordion.tsx` |
| 40 | Public — Share buttons | `…/public/crowdfund/[slug]/components/share-buttons.tsx` |
| 41 | Public — Footer | `…/public/crowdfund/[slug]/components/public-footer.tsx` |
| 42 | Public — Thank-you state | `…/public/crowdfund/[slug]/components/thank-you-state.tsx` |
| 43 | Public — Edge banners (Closed/GoalMet/Preview/Scheduled) | `…/public/crowdfund/[slug]/components/edge-banners.tsx` |
| 44 | Admin Route Page | `Pss2.0_Frontend/src/app/[lang]/setting/publicpages/crowdfundingpage/page.tsx` (OVERWRITE existing UnderConstruction stub) |
| 45 | Public Route Page | `Pss2.0_Frontend/src/app/[lang]/(public)/crowdfund/[slug]/page.tsx` (NEW — SSR with `generateMetadata`) |
| 46 | DTO barrel | `Pss2.0_Frontend/src/domain/entities/donation-service/index.ts` (export CrowdFundingPageDto types) |
| 47 | GQL barrels | export `CrowdFundingPageQuery` + `CrowdFundingPageMutation` + `CrowdFundPublicQuery` + `CrowdFundPublicMutation` |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | Append `CROWDFUNDINGPAGE` block (mirrors `P2PCAMPAIGNPAGE` from #170) |
| 2 | operations-config.ts | Import + register `CROWDFUNDINGPAGE` operations |
| 3 | Sidebar menu config | (DB-seeded by Session 1; no FE config change needed) |
| 4 | (public) layout group | (already exists from #10/#170; no change needed) |
| 5 | shared-cell-renderers barrel | (no new renderers introduced unless during build — reuse from #16) |
| 6 | pages barrel | Export `setting/publicpages/crowdfundingpage` |

### Backend File Count Summary

- **NEW**: 8 BE files (5 handlers + 3 schema/endpoint additions counted as file appends/creations)
- **MODIFY**: 6 BE files (UpdateCrowdFund, DonationMappings, CrowdFundQueries, GlobalDonations CHECK, rate-limit policy, OG meta)
- **WIRING**: 5 files (Program.cs / public route registration / IMemoryCache key registration etc. — most already exist post-#10/#170)

### Frontend File Count Summary

- **NEW**: ~45 FE files (split between admin setup ~28 and public route ~14 + DTOs + GQL barrels)
- **OVERWRITE**: 1 file (admin route page stub)
- **WIRING**: 2 files (entity-operations + operations-config; DB seed handles sidebar)

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by `/plan-screens`.

```
---CONFIG-START---
Scope: FULL

MenuName: Crowdfunding Page
MenuCode: CROWDFUNDINGPAGE
ParentMenu: SET_PUBLICPAGES
Module: SETTING
MenuUrl: setting/publicpages/crowdfundingpage
OrderBy: 7
GridType: EXTERNAL_PAGE
GridCode: CROWDFUNDINGPAGE

MenuCapabilities: READ, CREATE, MODIFY, DELETE, PUBLISH, UNPUBLISH, CLOSE, ARCHIVE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, PUBLISH, UNPUBLISH, CLOSE, ARCHIVE

GridFormSchema: SKIP
---CONFIG-END---
```

**Notes**:
- `GridType: EXTERNAL_PAGE` is ALREADY registered by #10 OnlineDonationPage — no GridType enum change needed.
- `GridFormSchema: SKIP` because this is a custom 6-tab UI, NOT an RJSF modal form.
- ParentMenu `SET_PUBLICPAGES` already exists (MenuId 369); this is the 7th leaf under it (after `EVENTREGPAGE` OrderBy=6).
- `MenuUrl` MUST match the FE route `setting/publicpages/crowdfundingpage` exactly.
- Capabilities `PUBLISH/UNPUBLISH/CLOSE/ARCHIVE` are 4 distinct caps (matching #16 caps) — BUSINESSADMIN gets all.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type (admin): existing `CrowdFundQueries` (extended)
- Mutation type (admin): existing `CrowdFundMutations` (no new admin mutations needed — UpdateCrowdFund modified in place)
- Query type (public): NEW `CrowdFundPublicQueries` (anonymous-allowed)
- Mutation type (public): NEW `CrowdFundPublicMutations` (anonymous-allowed)

### Admin queries (existing — reuse from #16)

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| getAllCrowdFundList | `[CrowdFundResponseDto]` | pageNo, pageSize, searchTerm, statuses |
| getCrowdFundById | `CrowdFundResponseDto` | id |
| getCrowdFundSummary | `CrowdFundSummaryDto` | (tenant from ctx) |
| getCrowdFundStats | `CrowdFundStatsDto` | id |

### Admin queries (NEW from this screen)

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| validateCrowdFundForPublish | `ValidationResultDto` | id |
| getCrowdFundEmbedCode | `EmbedCodeDto` | id |

**ValidationResultDto fields**:
- `isValid: boolean`
- `violations: ValidationViolationDto[]`
  - `field: string` (e.g. "Slug", "GoalAmount", "DonationPurposeId")
  - `code: string` (e.g. "SLUG_RESERVED", "GOAL_REQUIRED", "PAYMENT_METHODS_MIN_ONE")
  - `message: string` (human-readable)
  - `severity: 'ERROR' | 'WARNING'` (warnings don't block but show in modal)

**EmbedCodeDto fields**:
- `iframeSnippet: string` (the `<iframe src="..." />` HTML)
- `jsSnippet: string` (alternative widget.js loader)
- `publicUrl: string` (canonical `/crowdfund/{slug}`)

### Admin mutations (existing — reuse from #16, with one modification)

| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| createCrowdFund | `CrowdFundRequestDto` | int | from #16 |
| updateCrowdFund | `CrowdFundRequestDto` (partial-field support) | int | **MODIFIED** to support per-tab partial — null = no change |
| duplicateCrowdFund | id | int | from #16 |
| deleteCrowdFund | id | int | from #16 |
| publishCrowdFund | id | `CrowdFundResponseDto` | from #16 |
| unpublishCrowdFund | id | `CrowdFundResponseDto` | from #16 |
| closeCrowdFund | id | `CrowdFundResponseDto` | from #16 |
| archiveCrowdFund | id | int | from #16 |

### Public queries (NEW — anonymous-allowed)

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| getCrowdFundBySlug | `CrowdFundPublicDto` (only public-safe fields; status-gated) | slug |
| getCrowdFundPublicStats | `CrowdFundPublicStatsDto` (recentDonors list + aggregates) | slug |

**CrowdFundPublicDto fields** (omit sensitive admin-only fields):
- Identity: campaignName, slug, headline, pageStatus
- Content: heroImageUrl, heroVideoUrl, storyRichText (already sanitized), impactBreakdownJson, faqJson
- Donation config: amountChipsJson, allowCustomAmount, minimumDonationAmount, allowRecurringDonations, allowAnonymousDonations, allowDonorCoverFees, enabledPaymentMethodsJson, goalExceededBehavior, stretchGoalAmount
- Display: showGoalThermometer, showDonorCount, showDonorWall, enabledSectionsJson
- Milestones/Updates: milestonesJson (with server-recomputed status), updatesJson (sorted desc by date, top-N)
- Design: primaryColorHex, accentColorHex, backgroundColorHex, logoUrl, fontFamily
- SEO/Sharing: ogTitle, ogDescription, ogImageUrl, defaultShareMessage
- Goal display: goalAmount, currency, totalRaised, totalDonors, donationCount, daysRemaining, isGoalMet
- Branding: orgName (joined from Company), orgLogoUrl

**OMITTED from public DTO**:
- Internal IDs (CrowdFundId, CompanyId, DonationPurposeId, OrganizationalUnitId, FK template ids)
- Admin notes / audit fields (CreatedBy / ModifiedBy / etc.)
- Lifecycle timestamps (PublishedAt / ClosedAt / ArchivedAt) — except when needed for "Ended X days ago" caption
- Internal flag fields (RobotsIndexable — handled at SSR level, not exposed)

**CrowdFundPublicStatsDto fields** (donor wall + aggregates):
- totalRaised, totalDonors, donationCount, lastDonationAt, daysRemaining, isGoalMet
- recentDonors: `[ { displayName: string, amount: decimal, message?: string, createdDate: DateTime, isAnonymous: bool } ]` (top-10; isAnonymous=true displays as "Anonymous" with no name)

### Public mutations (NEW — anonymous, rate-limited, csrf-protected)

| GQL Field | Input | Returns |
|-----------|-------|---------|
| initiateCrowdFundDonation | `InitiateCrowdFundDonationDto` (slug, amount, currency?, isMonthly, coverFees, donorName?, donorEmail, isAnonymous, message?, csrfToken, honeypot, idempotencyKey) | `DonationInitResultDto` (paymentSessionId, redirectUrl?, gatewayCode) |
| confirmCrowdFundDonation | `ConfirmCrowdFundDonationDto` (gatewayCallbackPayload, signature) | `DonationConfirmedDto` (donationId, receiptUrl?, thankYouMessage, milestoneCrossed?: { name, percentage }) |

**Public DTO Privacy Discipline**:

| Field | Public DTO | Reason |
|-------|------------|--------|
| Internal CrowdFundId | omitted | not relevant to anonymous |
| Donor email / phone | omitted from public stats | PII never on public |
| Donor name on donor wall | shown ONLY when isAnonymous=false | donor privacy |
| Admin notes / lifecycle dates | omitted | internal-only |
| totalRaised, donorCount, milestones, story, updates | included | public-safe |
| Recent donors (paginated, max 10) | included with privacy filter | for social proof |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — admin loads at `/{lang}/setting/publicpages/crowdfundingpage`
- [ ] `pnpm dev` — public loads at `/{lang}/crowdfund/{slug}`

**Functional Verification — CROWDFUND**:
- [ ] Setup list view shows all CrowdFund pages with status badges, KPI tiles, filter chips (reuses #16's cards-grid + KPI components verbatim)
- [ ] "+ Create Campaign Page" opens Quick-Create modal (8 fields) → submit creates Draft → redirects to setup editor `?id={newId}`
- [ ] Setup editor renders with 6-tab nav + Status Bar (when editing existing)
- [ ] All 6 tabs persist on Save Draft (Basic / Content / Donation Settings / Milestones / Updates / Design)
- [ ] Live Preview pane shows public-page composition with current settings — updates within 300ms of edit
- [ ] Mobile/Desktop preview toggle changes preview viewport (mobile = phone-frame, desktop = browser-chrome)
- [ ] "Open in new tab" preview button uses preview-token for Draft pages
- [ ] Validate-for-publish shows missing-fields modal when validation fails (list of violations, ERROR/WARNING separation)
- [ ] Publish transitions Draft → Active (or Published if scheduled); status badge updates; URL becomes shareable
- [ ] Anonymous public route at `/crowdfund/{slug}` renders for Active/GoalMet/Closed pages
- [ ] Public donate flow completes end-to-end: amount selection → monthly/cover-fees toggles → form submit → gateway hand-off (SERVICE_PLACEHOLDER) → thank-you state
- [ ] Receipt email fires after successful donation (SERVICE_PLACEHOLDER)
- [ ] CSRF + honeypot + rate-limit (5/min/IP/slug) enforced on public submit
- [ ] Milestone status auto-updates on cross-threshold (TotalRaised crosses milestone.amount → status flips Upcoming/InProgress → Reached)
- [ ] Goal-Met state per GoalExceededBehavior:
  - [ ] `KeepAccepting` → donate stays live, banner "🎉 Goal met!"
  - [ ] `AutoClose` → PageStatus flips to GoalMet, donate disabled
  - [ ] `ShowStretchGoal` → secondary progress bar, donate stays live until stretch met
- [ ] Closed status renders banner + disables donate button
- [ ] Archived status returns 410 Gone
- [ ] Draft + preview-token renders with "PREVIEW — NOT YET LIVE" banner overlay
- [ ] OG tags rendered in initial SSR HTML; share preview correct on FB/Twitter/WhatsApp
- [ ] Impact Breakdown, Milestones Timeline, Updates Feed, Donor Wall, FAQ Accordion all render in correct order per `EnabledSectionsJson` toggles
- [ ] Share buttons (FB/X/WhatsApp/LinkedIn/Copy Link) emit correct share URLs + OG meta
- [ ] Slug immutable warning when admin tries to edit slug post-Active
- [ ] Drawer at #16 still works (this screen extension does not break #16's monitoring view)

**DB Seed Verification:**
- [ ] Admin menu visible at `Setting > Public Pages > Crowdfunding Page` in sidebar
- [ ] 1 sample published CrowdFund seeded (`build-a-school-kenya`) — public route renders at `/crowdfund/build-a-school-kenya` for QA
- [ ] Sample has populated MilestonesJson (4 milestones), UpdatesJson (3 updates), ImpactBreakdownJson (5 levels), FaqJson (3 questions), 5 sample donations for donor-wall demo
- [ ] Status transitions exercised in test seed (one Active + one GoalMet + one Closed + one Draft each render correctly)
- [ ] sql-scripts-dyanmic/ typo preserved per ChequeDonation #6 ISSUE-15 precedent

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### Universal EXTERNAL_PAGE warnings (inherited from _EXTERNAL_PAGE.md)

- TWO render trees — admin setup AND anonymous public — different `(core)` vs `(public)` route groups, different auth gates, different layouts
- Slug uniqueness per-tenant: `(CompanyId, Slug)` composite unique
- Lifecycle BE-enforced — never trust FE flag for "ready to publish"
- Anonymous-route hardening is non-negotiable (rate-limit / CSRF / honeypot / reCAPTCHA / CSP)
- PCI scope MUST stay at gateway iframe boundary — raw card data never touches our servers
- OG meta tags MUST be SSR-rendered (social crawlers don't run JS)
- Slug immutable post-Activation when donations attached
- Donation persistence is OUT OF SCOPE — donations live in `fund.GlobalDonations` with FK back to `CrowdFundId`; setup configures the funnel only
- `GridFormSchema: SKIP` — custom UI not RJSF
- `GridType: EXTERNAL_PAGE` — already registered by #10

### CROWDFUND-specific gotchas

- **Inventory race condition is NOT applicable** — Crowdfund is NOT like Kickstarter reward tiers. No inventory limits per impact level — Impact Breakdown is informational only (shows donors what their $X can achieve, not a claim-and-decrement reward tier). If V2 adds reward tier inventory, that becomes a new child entity. Don't add inventory math to V1.
- **Goal-met state has 3 explicit behaviors** — admin chooses one at Publish time. Failing to honor the choice ships a UX bug. Specifically: `AutoClose` MUST flip PageStatus to GoalMet on the donation that crosses threshold (atomic in transaction with the donation INSERT, not a deferred job).
- **Milestone status admin-overrideable** — admin can mark "Walls Up" as Reached even if TotalRaised hasn't hit $25,000 yet (manual progress recognition). Don't auto-override admin status with computed status. BUT — when admin DOESN'T override AND TotalRaised crosses threshold, server-side flip from Upcoming → Reached (this is the auto-promotion logic).
- **Slug "/campaign/" vs "/crowdfund/"** — mockup shows `/campaign/{slug}` prefix but registry note specifies `/crowdfund/{slug}`. Use `/crowdfund/{slug}` per registry. Update mockup-rendered URL preview accordingly.
- **Live preview perf** — 6 tabs each triggering a 300ms-debounced preview render across 7+ public-page components. Use React.memo + Zustand selectors to avoid re-rendering preview when unrelated tabs edit. Avoid full GraphQL refetch on every keystroke — preview should use form state, not server state.
- **Story rich text sanitization** — server-side sanitize on Save AND on render (defense in depth). Allow `b/i/u/p/h1-h6/ul/ol/li/a/img/blockquote` but NOT `script/iframe/style/onerror/onclick`. Validate URLs in `<a href>` (http/https/mailto only).
- **Donor wall caching** — server-cache `crowdfund:recentDonors:{id}` 60s. NEVER query GlobalDonations on every public render.

### Pre-flagged ISSUEs (15 — to address during build)

| ISSUE | Severity | Description |
|-------|----------|-------------|
| ISSUE-1 — PREREQUISITE-16 | HIGH | #16 CrowdFund entity MUST be built before this screen. If `fund.CrowdFunds` table absent → `/build-screen #173` should fail-fast with clear message + suggest `/build-screen #16` first. |
| ISSUE-2 — UPDATE-PARTIAL | HIGH | UpdateCrowdFund modification to support per-tab partial save — null = no change semantics. Backward-compatible with #16's full-payload Quick-Edit. Test both code paths during build. |
| ISSUE-3 — DONATION-CHECK-CONSTRAINT | HIGH | Existing CHECK on `fund.GlobalDonations` (`NUM_NONNULLS(OnlineDonationPageId, P2PCampaignPageId, P2PFundraiserId) <= 1`) must be EXTENDED to include CrowdFundId. Migration: drop + recreate constraint with new column. |
| ISSUE-4 — SLUG-IMMUTABILITY | MED | Validator + handler must enforce slug immutability post-Active when donations attached. Already enforced by #16 — verify on build that THIS screen's UpdateCrowdFund honors the rule. |
| ISSUE-5 — MILESTONE-AUTO-PROMOTE | MED | On donation success, server-side scan MilestonesJson + flip status of any milestone whose amount ≤ new TotalRaised AND current status='Upcoming' → 'Reached'. Admin-overridden 'Reached' stays. Status='InProgress' is admin-only (never auto-set). |
| ISSUE-6 — GOAL-EXCEEDED-AUTOCLOSE | MED | Atomic transaction: donation INSERT + status flip to GoalMet must be ONE transaction when `GoalExceededBehavior='AutoClose'` AND new TotalRaised ≥ GoalAmount. Otherwise race condition where two near-simultaneous donations both succeed but only one flips status. |
| ISSUE-7 — STRETCH-GOAL-VALIDATION | MED | StretchGoalAmount > GoalAmount validated at Publish. If admin later edits GoalAmount upward past StretchGoalAmount, flag warning (not block) on Save. |
| ISSUE-8 — MULTI-CURRENCY-V2 | MED | totalRaised aggregates donations regardless of currency — multi-currency mixing is mathematically incorrect for V1. V1 displays mix without conversion; V2 must normalize to campaign Currency via existing FX direct-pair service (per memory `feedback_fx_direct_pair.md`). |
| ISSUE-9 — RICH-TEXT-SANITIZATION | MED | StoryRichText, FAQ answers, Update content all rich-text. Server-side sanitize on Save + render. Allow-list tags + reject script/iframe/style/onerror/onclick. Validate href URLs. |
| ISSUE-10 — RESERVED-SLUG-LIST | LOW | Centralize reserved-slug list in shared constant — same as #10 / #170. Don't duplicate per screen. |
| ISSUE-11 — DONOR-WALL-CACHE | LOW | Cache key `crowdfund:recentDonors:{crowdFundId}` 60s TTL — invalidate on donation INSERT. |
| ISSUE-12 — OG-IMAGE-FALLBACK | LOW | When OgImageUrl is NULL, fall back to HeroImageUrl. When both NULL, render category-icon-on-gradient SVG (server-rendered, 1200x630 fixed dimensions) — V2 may switch to generated dynamic OG image. |
| ISSUE-13 — COMM-TAB-DEFERRED | LOW | Mockup doesn't show a Communication tab but entity has 5 template FKs. Defer template selection UI to V2 (or hide behind Design Tab > "Advanced > Communication" sub-section). Templates default to NULL → falls back to global tenant defaults. |
| ISSUE-14 — SEED-FOLDER-TYPO | LOW | Use `sql-scripts-dyanmic/` folder (preserve typo per ChequeDonation #6 ISSUE-15 precedent). |
| ISSUE-15 — EMBED-CODE-V2 | LOW | GetCrowdFundEmbedCode query + iframe widget feature deferred to V2 (mockup shows 5 share buttons but not an embed widget). V1 ships only the query (returns publicUrl) without rendering the embed UI. |

### Service Dependencies (UI-only — no backend service implementation)

> Everything shown in the mockup is in scope. The following require external services not yet wired in the codebase — UI must be built fully; handlers return mocked results.

- **⚠ SERVICE_PLACEHOLDER: Payment Gateway** — UI fully implemented (amount chips, monthly toggle, cover-fees toggle, donate button). Handler `initiateCrowdFundDonation` returns mocked `paymentSessionId` + thank-you redirect. Real Stripe/PayPal connect lives in `setting/paymentconfig/companypaymentgateway` and integration is pending.
- **⚠ SERVICE_PLACEHOLDER: Receipt Email** — UI implemented (ConfirmationEmailTemplateId FK + send-on-success path). Handler logs only because email-send service isn't wired yet.
- **⚠ SERVICE_PLACEHOLDER: WhatsApp Donation Alert** — UI implemented (WhatsAppDonationAlertEnabled toggle + template select in Tab 6 advanced or via #16 entity defaults). Send-handler is no-op.
- **⚠ SERVICE_PLACEHOLDER: reCAPTCHA v3** — UI placeholder; score check returns 1.0 until service configured.
- **⚠ SERVICE_PLACEHOLDER: Image Upload** — Hero Image / Logo / OG Image upload-area UI fully implemented (drag-drop + click-to-select + preview thumb). Handler stores URL only (assumes external upload service or returns a placeholder URL). Real upload pipeline (S3 / Azure Blob) is org-wide infra pending.
- **⚠ SERVICE_PLACEHOLDER: Multi-currency FX** — when donor amount currency differs from campaign Currency, no live-conversion. V2 wires `IFxRateService.GetRateAsync` direct-pair lookup.
- **⚠ SERVICE_PLACEHOLDER: Generated OG Image** — when both OgImageUrl and HeroImageUrl are NULL, V1 falls back to a static category-icon-on-gradient SVG. V2 generates a dynamic OG image per campaign (campaign name + progress + brand color).

Full UI must be built (setup tabs, public render tree, donation flow up to gateway boundary, lifecycle transitions, edge states, validate-for-publish modal). Only the handlers for genuinely missing services are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-16 | Session 1 BUILD | LOW | BE | Agent chose to create NEW `UpdateCrowdFundPage` command (separate from #16's `UpdateCrowdFund`) rather than modify the existing handler. Cleaner isolation — but FE must call `updateCrowdFundPage` for tab saves and call existing `updateCrowdFund` only when invoking the #16 Quick-Edit-shaped payload. Document the two-handler contract for FE Developer in Session 2. | CLOSED (session 2) — editor-page.tsx imports `UPDATE_CROWDFUND_PAGE` for per-tab partial saves; entity-operations CROWDFUNDINGPAGE block wires `update` → `UPDATE_CROWDFUND_PAGE`; `UPDATE_CROWDFUND` reserved for #16 Quick-Edit only |
| ISSUE-17 | Session 1 BUILD | LOW | BE | DTO name collision: `DonationConfirmedDto` already exists in `P2PFundraiserSchemas.cs` (same namespace `Base.Application.Schemas.DonationSchemas`). Resolved by renaming the new DTO to `CrowdFundDonationConfirmedDto`. FE must use the renamed DTO name on `confirmCrowdFundDonation` response. | CLOSED |
| ISSUE-18 | Session 1 BUILD | LOW | BE | EF migration #14 from the plan turned out UNNECESSARY: #16 Session 2 (2026-05-13) removed `fund.GlobalDonations.CrowdFundId` + the 3-arg CHECK constraint in favor of the `fund.CrowdFundDonations` junction table. The CHECK-extension migration was dropped. ISSUE-3 from §⑫ is therefore CLOSED. | CLOSED |
| ISSUE-19 | Session 1 BUILD | MED | BE | Donation persistence path: `confirmCrowdFundDonation` must INSERT both a `fund.GlobalDonations` row tagged `DonationType='Crowd Donation'` AND a `fund.CrowdFundDonations` junction row in the SAME transaction (per #16 Session 2 design + #16 ISSUE-22). Agent's implementation honors this — verify atomicity behavior under load in V2. | OPEN |
| ISSUE-20 | Session 1 BUILD | LOW | BE | Public GraphQL field name discrepancy in agent's contract summary: agent reported `getBySlug(...)` but actual GraphQL field name is `getCrowdFundBySlug` (matches the C# method name `GetCrowdFundBySlug`). FE Developer must use `getCrowdFundBySlug` — not the abbreviated form. | CLOSED (session 2) — `CrowdFundPublicQuery.ts` declares `GET_CROWDFUND_BY_SLUG` aliasing `getCrowdFundBySlug` (full name) and `GET_CROWDFUND_PUBLIC_STATS` aliasing `getCrowdFundPublicStats` |
| ISSUE-21 | Session 1 BUILD | LOW | SEED | Sample-data seed uses an UPDATE-with-guard (`WHERE PageStatus='Draft'`) on the existing #16 `build-a-school-kenya` row to promote it to `Active` + add rich content. If a fresh tenant runs #173's seed WITHOUT first running #16's seed, the UPDATE will silently no-op (no sample CrowdFund exists). Document execution order in deployment notes: run `Crowdfunding-sqlscripts.sql` (#16) BEFORE `Crowdfundingpage-sqlscripts.sql` (#173). | OPEN |
| ISSUE-22 | Session 2 FE_ONLY | LOW | FE | FE agent generated component exports as `CrowdFundingPageTabNav` + `CrowdFundingPageStatusBar` but editor-page imported them as short names `TabNav` + `StatusBar`. Resolved post-generation via `import { CrowdFundingPageTabNav as TabNav } from ...` aliases. Cosmetic cleanup option: rename exports to short forms in a future polish pass. | CLOSED (session 2) |
| ISSUE-23 | Session 2 FE_ONLY | LOW | FE | FE agent's `status-bar.tsx` referenced `stats.lastDonationAt` but the admin `CrowdFundStatsDto` exposes `avgDonation` / `largestDonation` / weekly-trend fields — not `lastDonationAt`. `lastDonationAt` lives on `CrowdFundPublicStatsDto` (public-stats DTO) and on `CrowdFundResponseDto` (full response). Resolved post-generation by swapping the "Last donation" tile for a "Largest" tile using the field that IS available on `CrowdFundStatsDto`. | CLOSED (session 2) |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-13 — BUILD — PARTIAL

- **Scope**: Initial BE-only build from PROMPT_READY prompt. FE deferred to FE_ONLY Session 2 per #171/#172 EXTERNAL_PAGE precedent (large dual-surface + 45-file FE scope > token budget for one session).
- **Files touched**:
  - BE:
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundBySlug.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundPublicStats.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/ValidateCrowdFundForPublish.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundEmbedCode.cs` (created — V1 returns publicUrl only per ISSUE-15)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/InitiateCrowdFundDonation.cs` (created — SERVICE_PLACEHOLDER mock paymentSessionId)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/ConfirmCrowdFundDonation.cs` (created — atomic GlobalDonations + CrowdFundDonations junction INSERT; milestone auto-promote; GoalMet auto-flip on AutoClose)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/UpdateCrowdFundPage.cs` (created — NEW separate command; null-means-no-change semantics; backward-compatible with #16's UpdateCrowdFund — see ISSUE-16)
    - `Base.API/EndPoints/Donation/Public/CrowdFundPublicQueries.cs` (created — anonymous-allowed)
    - `Base.API/EndPoints/Donation/Public/CrowdFundPublicMutations.cs` (created — anonymous-allowed, rate-limited via `CrowdFundDonationSubmit`)
    - `Base.Application/Schemas/DonationSchemas/CrowdFundSchemas.cs` (modified — appended 7 DTOs incl. renamed `CrowdFundDonationConfirmedDto` per ISSUE-17)
    - `Base.Application/Mappings/DonationMappings.cs` (modified — appended Mapster configs for new DTOs)
    - `Base.API/EndPoints/Donation/Queries/CrowdFundQueries.cs` (modified — appended `ValidateCrowdFundForPublish` + `GetCrowdFundEmbedCode` admin GQL fields)
    - `Base.API/EndPoints/Donation/Mutations/CrowdFundMutations.cs` (modified — appended `UpdateCrowdFundPage` admin GQL mutation)
    - `Base.API/DependencyInjection.cs` (modified — `CrowdFundDonationSubmit` rate-limit policy 5/min/IP+slug added inside existing AddRateLimiter lambda)
  - FE: NONE (deferred to Session 2)
  - DB: `sql-scripts-dyanmic/Crowdfundingpage-sqlscripts.sql` (created — STEP 0 GridType defensive + STEP 0a defensive Capability inserts + STEP 1 Menu CROWDFUNDINGPAGE + STEP 2 9 MenuCapabilities + STEP 3 BUSINESSADMIN RoleCapabilities + STEP 4 Grid CROWDFUNDINGPAGE GridType=EXTERNAL_PAGE + STEP 5 UPDATE-with-guard promoting #16's build-a-school-kenya Draft → Active with rich Content/Milestones/Updates/Impact/FAQ JSON)
- **Deviations from spec**:
  - Plan called for MODIFYING `UpdateCrowdFund.cs` to support per-tab partial save; agent chose the cleaner path of CREATING a separate `UpdateCrowdFundPage` command. #16's `UpdateCrowdFund` remains untouched (no risk of breaking the Quick-Edit code path). See ISSUE-16.
  - Plan called for an EF migration extending the `fund.GlobalDonations` 3-arg CHECK constraint; turned out UNNECESSARY because #16's Session 2 redesign already replaced that column with the `fund.CrowdFundDonations` junction. ISSUE-3 from §⑫ → CLOSED via ISSUE-18.
  - DTO `DonationConfirmedDto` renamed to `CrowdFundDonationConfirmedDto` to avoid namespace collision with P2PFundraiserSchemas (ISSUE-17 — CLOSED).
- **Known issues opened**: ISSUE-16 (UpdatePage two-handler contract for FE), ISSUE-17 (CLOSED), ISSUE-18 (CLOSED), ISSUE-19 (atomicity verify in V2), ISSUE-20 (FE must use full `getCrowdFundBySlug` field name), ISSUE-21 (seed execution order — #16 before #173)
- **Known issues closed**: ISSUE-3 from §⑫ (CHECK constraint extension — superseded by junction design); ISSUE-17 (collision resolved); ISSUE-18 (migration unnecessary)
- **Build verification**: `dotnet build` PASS — 0 errors, 476 pre-existing warnings (none introduced by Screen #173).
- **Next step**: User runs the DB seed (`Crowdfundingpage-sqlscripts.sql`) AFTER `Crowdfunding-sqlscripts.sql` (#16) — execution order matters per ISSUE-21. No EF migration needed this session (ISSUE-18 closed it). Then `/continue-screen #173 --scope FE_ONLY` to generate ~45 FE files: admin 6-tab editor + live preview pane + public SSR route at `(public)/crowdfund/[slug]/page.tsx` + 13 public components + Zustand store + Zod schemas + entity-operations CROWDFUNDINGPAGE wiring block. FE Developer (Opus) must honor:
  - ISSUE-16: call `updateCrowdFundPage` (NEW handler) for per-tab partial saves; call existing `updateCrowdFund` only if reusing #16's Quick-Edit dialog component verbatim.
  - ISSUE-17: confirmation DTO is `CrowdFundDonationConfirmedDto` not `DonationConfirmedDto`.
  - ISSUE-20: GraphQL field is `getCrowdFundBySlug` (full name).
  - Layout Variant `tabbed-with-preview` for the editor page (Variant B: ScreenHeader + showHeader=false on data-table containers).
  - Reuse `<CrowdFundCardsGrid>` + `<CrowdFundKpiWidgets>` from #16 for the admin list view (when no `?id`).

### Session 2 — 2026-05-13 — FE_ONLY BUILD — COMPLETED

- **Scope**: Generate the full FE surface (admin 6-tab editor + public SSR storefront) deferred from Session 1. Triggered via `/continue-screen #173 --scope FE_ONLY`. Followed the #170/#171/#172 EXTERNAL_PAGE FE precedent.
- **Files touched**:
  - BE: NONE (FE-only session — BE Session 1 already complete and `dotnet build` re-verified PASS at session start).
  - FE (admin setup — 17 files, all NEW under `PSS_2.0_Frontend/src/presentation/components/page-components/setting/publicpages/crowdfundingpage/`):
    - `crowdfundingpage-root.tsx` (root dispatcher — reads `?id` → editor vs list)
    - `crowdfundingpage-store.ts` (Zustand — per-tab form state + activeTab + dirty flag + modal state + preview device mode + diff-based saveAll)
    - `crowdfundingpage-schemas.ts` (Zod schemas per tab + composite publish-validation schema)
    - `index.ts` (barrel)
    - `list-page.tsx` (Variant B ScreenHeader; reuses #16's `crowdfund-cards-grid` + `crowdfund-widgets` + `crowdfund-filter-bar`; "+ Create Campaign Page" → local `QuickCreateModal`; card click → `?id=N` navigation)
    - `editor-page.tsx` (header + StatusBar + 6-tab nav + tab content + sticky dirty footer + lifecycle modals; calls `UPDATE_CROWDFUND_PAGE` per ISSUE-16)
    - `tabs/basic-tab.tsx`, `content-tab.tsx`, `donation-settings-tab.tsx`, `milestones-tab.tsx`, `updates-tab.tsx`, `design-tab.tsx`
    - `components/tab-nav.tsx`, `status-bar.tsx`, `live-preview.tsx` (300ms-debounced split-pane preview with Desktop/Mobile device-switcher; uses `React.memo` per spec §⑫), `lifecycle-modals.tsx` (Publish/Unpublish/Close/Archive confirm), `publish-validation-modal.tsx` (ERROR/WARNING separation), `quick-create-modal.tsx` (8 fields, gated by RHF `formState.isValid`), `section-toggles.tsx`, `color-picker-row.tsx`, `amount-chips-editor.tsx`, `impact-breakdown-editor.tsx`, `faq-editor.tsx`, `milestones-list-editor.tsx`, `updates-editor.tsx` (post-update modal merged inline)
  - FE (public route — 15 files, all NEW under `PSS_2.0_Frontend/src/presentation/components/page-components/public/crowdfundingpage/`):
    - `page-content.tsx` (2-col layout — left: headline/story/impact/milestones/updates/donor-wall/FAQ; right: sticky progress + donate-widget + share)
    - `org-header.tsx`, `hero.tsx`, `progress-widget.tsx`, `donate-form.tsx` (CSRF + honeypot + idempotencyKey), `impact-list.tsx`, `milestones-timeline.tsx`, `updates-feed.tsx`, `donor-wall.tsx`, `faq-accordion.tsx`, `share-buttons.tsx` (FB/X/WhatsApp/LinkedIn/Copy Link), `public-footer.tsx`, `thank-you-state.tsx`, `edge-banners.tsx` (Draft preview / Closed / GoalMet × 3 behaviors), `index.tsx` (barrel)
  - FE (route shells — 2 files, NEW):
    - `app/[lang]/setting/publicpages/crowdfundingpage/page.tsx` (re-export of page-config; folder DID NOT previously exist — created)
    - `app/[lang]/(public)/crowdfund/[slug]/page.tsx` (SSR with `generateMetadata` + ISR `revalidate=60` + OG fallback chain `ogImage → heroImage → orgLogo` + status gating `Archived → notFound`, `Draft && !previewToken → notFound`)
  - FE (DTO / GQL — 5 NEW files):
    - `domain/entities/donation-service/CrowdFundingPageDto.ts` (composite DTOs incl. `CrowdFundPublicDto`, `CrowdFundPublicStatsDto`, `ValidationResultDto`, `EmbedCodeDto`, `InitiateCrowdFundDonationDto`, `DonationInitResultDto`, `ConfirmCrowdFundDonationDto`, `CrowdFundDonationConfirmedDto`, `CrowdFundPageUpdateRequest`)
    - `infrastructure/gql-queries/donation-queries/CrowdFundingPageQuery.ts` (`VALIDATE_CROWDFUND_FOR_PUBLISH`, `GET_CROWDFUND_EMBED_CODE`)
    - `infrastructure/gql-queries/public-queries/CrowdFundPublicQuery.ts` (`GET_CROWDFUND_BY_SLUG`, `GET_CROWDFUND_PUBLIC_STATS` — full names per ISSUE-20)
    - `infrastructure/gql-mutations/donation-mutations/CrowdFundingPageMutation.ts` (`UPDATE_CROWDFUND_PAGE` — null-means-no-change per ISSUE-16)
    - `infrastructure/gql-mutations/public-mutations/CrowdFundPublicMutation.ts` (`INITIATE_CROWDFUND_DONATION`, `CONFIRM_CROWDFUND_DONATION`)
  - FE (page-config — 1 NEW file):
    - `presentation/pages/setting/publicpages/crowdfundingpage.tsx` (capability gate via `useAccessCapability({ menuCode: "CROWDFUNDINGPAGE" })`)
  - FE (wiring — 5 MODIFY):
    - `application/configs/data-table-configs/donation-service-entity-operations.ts` — appended `CROWDFUNDINGPAGE` block (mirrors `P2PCAMPAIGNPAGE` from #170); `update` → `UPDATE_CROWDFUND_PAGE` (ISSUE-16) with DTO `CrowdFundPageUpdateRequest`
    - `domain/entities/donation-service/index.ts` — re-export `CrowdFundingPageDto`
    - `infrastructure/gql-queries/donation-queries/index.ts` + `public-queries/index.ts` — re-export new query modules
    - `infrastructure/gql-mutations/donation-mutations/index.ts` + `public-mutations/index.ts` — re-export new mutation modules
    - `presentation/pages/setting/publicpages/index.ts` — re-export `crowdfundingpage`
  - DB: NONE (`Crowdfundingpage-sqlscripts.sql` already created in Session 1; user must execute #16 SQL BEFORE #173 SQL per ISSUE-21)
- **Deviations from spec**:
  - `crowdfundingpage-store.ts` + `crowdfundingpage-schemas.ts` live at the component root (NOT in `store/` or `schemas/` subdirectories as §⑧ suggested). Matches the actual #170/#171/#172 sibling convention (`p2pcampaignpage-store.ts` lives at root, no `store/` subdir).
  - `update-post-modal.tsx` merged inline into `updates-editor.tsx` (tight coupling; single component handles both list view and the post-modal). All other §⑧ components emitted as separate files.
  - Public components folder named `public/crowdfundingpage/` (matching the screen name) rather than `public/crowdfund/[slug]/` (the URL path) — consistent with the `public/p2pcampaignpage/` and `public/onlinedonationpage/` neighbour pattern.
  - Embed-widget UI deferred to V2 per ISSUE-15 — `GET_CROWDFUND_EMBED_CODE` query wired, but UI surfaces only `publicUrl` as a copyable textarea. No iframe-renderer.
  - Communication template-FK selects (`confirmationEmailTemplateId`, `whatsAppDonationAlertTemplateId`, etc.) NOT surfaced in any tab — fields exist on DTO; full UI deferred to V2 per ISSUE-13. Tabs stay at exactly 6.
  - Admin route page existed in `app/[lang]/setting/publicpages/crowdfundingpage/page.tsx`: §⑧ said "OVERWRITE existing UnderConstruction stub" but no stub existed — the file was created fresh. Outcome identical.
- **Known issues opened**: ISSUE-22 (export-name mismatch fixup applied via `as` aliases) + ISSUE-23 (status-bar `lastDonationAt` field doesn't exist on admin `CrowdFundStatsDto` — swapped to `largestDonation`). Both **CLOSED in this session** via post-generation Edits.
- **Known issues closed**: ISSUE-16 (FE wired to `UPDATE_CROWDFUND_PAGE` everywhere it matters), ISSUE-20 (FE wired to full `getCrowdFundBySlug` / `getCrowdFundPublicStats` field names), ISSUE-22 (fixup applied), ISSUE-23 (fixup applied).
- **Still OPEN** (carry-over): ISSUE-19 (atomicity verification under load — V2 BE concern), ISSUE-21 (seed execution order — deployment note only).
- **Pre-flagged §⑫ deferrals (V2 work, no FE action this session)**: ISSUE-8 (multi-currency FX), ISSUE-13 (Communication template UI), ISSUE-15 (live embed widget).
- **Build verification**:
  - `dotnet build` PASS (BE Session 1 outputs still compile, 0 errors).
  - `npx tsc --noEmit` on FE: **5 errors remain — ALL pre-existing in unrelated files** (`event-overview-bar.tsx`, `event-selector.tsx`, `EmailConfiguration.tsx`, `RecipientFilterDialog.tsx`, `domain/entities/index.ts` `PageLayoutOption` ambiguity from `OnlineDonationPageDto.ts` exports). **Zero #173-introduced errors after the 2 post-generation fixes (ISSUE-22/23).**
- **Next step**: Screen #173 is COMPLETED. User actions before E2E QA:
  1. Run `Crowdfunding-sqlscripts.sql` (#16) IF not yet run.
  2. Run `Crowdfundingpage-sqlscripts.sql` (#173) — promotes `build-a-school-kenya` Draft → Active with rich content for QA.
  3. `pnpm dev` and visit `/{lang}/setting/publicpages/crowdfundingpage` (admin) + `/{lang}/crowdfund/build-a-school-kenya` (public).
  4. Exercise: Quick-Create → editor 6 tabs → Save Draft → Publish (validate-for-publish modal on missing fields) → public route renders → donate flow up to SERVICE_PLACEHOLDER gateway boundary → thank-you state with `milestoneCrossed` if threshold crossed.
  - All 7 SERVICE_PLACEHOLDERs from §⑫ require UI built fully (Payment Gateway / Receipt Email / WhatsApp Alert / reCAPTCHA / Image Upload / Multi-currency FX / Generated OG Image).