---
screen: P2PCampaignPage
registry_id: 170
module: Setting (Public Pages)
status: COMPLETED
scope: FULL
screen_type: EXTERNAL_PAGE
external_page_subtype: P2P_FUNDRAISER
complexity: High
new_module: NO
planned_date: 2026-05-08
completed_date: 2026-05-10
last_session_date: 2026-05-10
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: P2P_FUNDRAISER — parent campaign + supporter child pages)
- [x] Business context read (audience = anonymous donors AND supporters who become fundraisers; parent campaign has its own public landing; each fundraiser has their own public child page; lifecycle = Draft → Published → Active → Closed → Archived)
- [x] Setup vs Public route split identified (admin at `setting/publicpages/p2pcampaignpage` + anonymous public parent at `(public)/p2p/{campaignSlug}` + anonymous public child at `(public)/p2p/{campaignSlug}/{fundraiserSlug}` + anonymous public "Start Fundraiser" wizard at `(public)/p2p/{campaignSlug}/start`)
- [x] Slug strategy chosen: `custom-with-fallback` (auto-from-CampaignName for parent; auto-from-FundraiserName for child; per-tenant unique for parent; unique-within-parent for child)
- [x] Lifecycle states confirmed (parent: Draft / Published / Active / Closed / Archived. Child fundraiser: Draft / Pending / Active / Paused / Rejected / Completed)
- [x] Payment gateway integration scope confirmed (existing `fund.CompanyPaymentGateways` lookup; real Stripe/PayPal/ApplePay/BankTransfer hand-off is SERVICE_PLACEHOLDER until gateway connect implemented)
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed (admin setup files + public parent route files + public child route files + public Start-Fundraiser wizard files separately)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt is exhaustively pre-analyzed — orchestrator validated against §① §② §④ §⑤ rather than re-running BA agent)
- [x] Solution Resolution complete (sub-type confirmed P2P_FUNDRAISER, Campaign-linkage via FK, custom-with-fallback slug, MANUAL approval seeded, save-all model, SERVICE_PLACEHOLDER payment scope)
- [x] UX Design finalized (Session 2 — FE Build Brief stamped Layout Variants per surface, state-management strategy, file manifest with reuse/wrapper/custom decisions, edge states, FA→Phosphor icon mapping)
- [x] User Approval received (BE + DB-seed scope split approved 2026-05-09; FE_ONLY full-in-one-run + reuse session-1 config approved 2026-05-10)
- [x] Backend code generated          ← 5 entities (parent + 4 children) + 15 commands + 9 queries + 4 public mutations + 4 public queries + 8 communication handlers + slug validator + helper + GlobalDonation modification with CHECK constraint
- [x] Backend wiring complete         ← IDonationDbContext + DonationDbContext + DecoratorProperties + DonationMappings + IMemoryCache + rate-limit policies (P2PStartFundraiser 3/min/IP, P2PDonationSubmit 5/min/IP) + GraphQL endpoints (admin + public, queries + mutations)
- [x] Frontend (admin setup) code generated         ← list-page (KPI cards + filterable table) + 5-tab editor + active-fundraiser embedded grid + approval queue + slide-out detail panel + reject/send-message modals + status-bar + tab-nav + 5 tab components + live-preview (inline, debounced 300ms) + 9 form-control components (section-card, api-single-select, upload-area, amount-chips, radio-cards, color-picker, rich-text-editor) + Zustand store (save-all model, no autosave)
- [x] Frontend (public parent page) code generated         ← `(public)/p2p/[campaignSlug]/page.tsx` SSR + `generateMetadata` for OG tags + `revalidate=60` + parent-landing-page composition (org-header / parent-hero / progress-section / leaderboard / donor-wall / impact-stats / public-footer) + Closed banner edge state
- [x] Frontend (public child fundraiser page) code generated         ← `(public)/p2p/[campaignSlug]/[fundraiserSlug]/page.tsx` SSR + `generateMetadata` + 60/40 two-col layout (child-cover-profile / child-story / child-updates / child-team-section / child-progress-widget / donate-form / share-buttons / mobile-donate-bar) + Paused/Closed banner edge states + notFound() for non-Active states
- [x] Frontend (public Start-Fundraiser wizard) code generated         ← `(public)/p2p/[campaignSlug]/start/page.tsx` CSR + 4-step stepper + Zustand wizard store (idempotencyKey via sessionStorage) + step-1-identity (email-dedupe + Individual/Team radio) + step-2-page-setup (slug availability check) + step-3-donation-settings + step-4-review + success-screen
- [x] Frontend wiring complete        ← entity-operations.ts (P2PCAMPAIGNPAGE block appended; mirrors ONLINEDONATIONPAGE pattern) + sidebar menu (DB-seeded by Session 1; no FE config change needed) + (public) layout group (already exists) + generateMetadata exports on both public-parent and public-child routes
- [x] DB Seed script generated (sample published parent + 1 team + 3 child fundraisers (Sarah Active, Khalid Team-Captain Active, Maria Pending) + 9 milestones + new P2PCAMPAIGNTYPE MasterData; GridType `EXTERNAL_PAGE` already registered by OnlineDonationPage; menu + role capabilities included)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — admin setup loads at `/{lang}/setting/publicpages/p2pcampaignpage` (replaces UnderConstruction stub)
- [ ] `pnpm dev` — public parent loads at `/{lang}/p2p/{campaignSlug}`
- [ ] `pnpm dev` — public child fundraiser loads at `/{lang}/p2p/{campaignSlug}/{fundraiserSlug}`
- [ ] `pnpm dev` — public Start-Fundraiser wizard loads at `/{lang}/p2p/{campaignSlug}/start`
- [ ] **P2P_FUNDRAISER checks**:
  - [ ] Setup list view shows all P2P pages with status badges; "+ Create P2P Campaign" creates a Draft and redirects to setup form
  - [ ] All 5 setup tabs persist (Basic Info / Fundraiser Settings / Donation Settings / Branding & Page / Communication)
  - [ ] **Tab 1 — Basic Info**: Campaign Name + Slug (auto-from-name with copy button) + Campaign Type radio cards (Timed/Occasion/Always Active) + Start/End dates (conditional on Timed) + Goal + Linked Donation Purpose + Description + Story (rich text) + Hero Image upload + Campaign Video URL + Organizational Unit dropdown
  - [ ] **Tab 2 — Fundraiser Settings**: Allow Public Registration toggle + Fundraiser Approval toggle (auto vs manual) + Default/Min/Max Goal + Allow Team Fundraising toggle (gates Default Team Goal + Max Team Size) + Fundraiser Page Options checklist (profile photo / personal story / personal goal / cover image / custom video / milestones) + Gamification toggles (leaderboard / fundraiser count / achievement badges) + Achievement badges read-only list (First Donation / 50% Goal / Goal Reached / Top Fundraiser)
  - [ ] **Tab 3 — Donation Settings**: Suggested amount chips + Allow Custom Amount + Min Donation + Allow Recurring Donations + Allow Anonymous Donations + Payment Methods (4 methods: Card / PayPal / ApplePay / BankTransfer with toggle each) + Allow Donor Cover Fees + Matching Gift Integration toggle
  - [ ] **Tab 4 — Branding & Page** (split-pane editor + live preview): Page Theme select + Primary/Secondary color pickers + Logo upload + Header Style radio cards (Full-width Hero / Split / Minimal) + Page Sections toggles (Org Info / Impact Stats / Donor Wall / Leaderboard) + Custom CSS textarea + Live Preview pane with Desktop/Mobile device-switcher (preview shows actual public parent page render with current settings)
  - [ ] **Tab 5 — Communication**: 6 email-trigger template selectors (Registration / DonationToFundraiser / DonationToDonor / GoalReached / WeeklyProgress / CampaignEndSummary) + WhatsApp 2 trigger toggles (DonationAlert with template select / GoalMilestoneAlerts toggle-only) + Default Share Message textarea + OG Image upload + Share Buttons display reference
  - [ ] **Active Fundraiser Embedded Grid** (separate from setup tabs — shown when editing existing P2P page): list of child fundraisers with name + email + campaign + goal + raised + progress + donors + status + registered date + page views + actions; status filter chips (All / Active / Pending / Paused / Completed); search by fundraiser name/email; sort by Most Raised / Most Donors / Most Recent / Alphabetical; campaign-filter select
  - [ ] **Approval Queue** (when FundraiserApprovalMode = MANUAL): pending rows show amber row tint; per-row Approve / Reject / Preview actions; bulk Approve/Reject in toolbar; Reject opens reason textarea modal
  - [ ] **Slide-out detail panel** (click any fundraiser row): profile + page URL + performance metrics + share stats + recent donors table + admin actions (Send Message / Edit Page / Pause Page / Feature on Campaign / View Contact Profile)
  - [ ] **Public parent page** at `/p2p/{campaignSlug}` renders: org-header navbar + hero with campaign name + progress bar with raised/goal + donor count + fundraiser count + days-left countdown + "Become a Fundraiser" + "Donate Now" CTAs + Campaign Story + Top Fundraisers leaderboard + Recent Donors wall + Impact Stats grid + Footer
  - [ ] **Public child fundraiser page** at `/p2p/{campaignSlug}/{fundraiserSlug}` renders: org-header navbar + cover photo + 2-col layout (left: profile + tagline + parent-campaign back-link + My Story + Recent Donors + Updates + Team section if team fundraising / right: progress widget + donate form + share buttons + parent-campaign card-link) + sticky mobile donate bar + footer
  - [ ] **Public Start-Fundraiser Wizard** at `/p2p/{campaignSlug}/start` — 4 steps with stepper (Campaign & Identity → Page Setup → Donation Settings → Review & Activate); step 1 (anonymous-or-existing-contact lookup by email + new-fundraiser fields + Individual/Team radio + team sub-fields); step 2 (page title + personal goal + URL slug with availability check + personal story rich text + cover photo + milestones table); step 3 (use-campaign-defaults vs custom amounts + employer matching toggle + offline donations toggle + custom thank-you message + social share message templates per platform); step 4 (summary table + mini preview + activation status select + welcome-email/toolkit/notify-manager checkboxes); success screen with copy URL + share buttons after submit
  - [ ] **FundraiserApprovalMode = AUTO** → Start-Fundraiser submission immediately Active + welcome email queued + login-link URL emailed for owner to manage own page
  - [ ] **FundraiserApprovalMode = MANUAL** → Start-Fundraiser submission becomes Pending + admin notified + "page is under review" message shown to fundraiser; admin Approve flips to Active + sends approved email; admin Reject flips to Rejected + sends rejection email with reason
  - [ ] **Allow Team Fundraising = TRUE** → Wizard shows Team option; team registration creates `P2PFundraiserTeam` row + sets `TeamId` on `P2PFundraiser`; public child page renders Team section
  - [ ] **Closed parent campaign** → all child fundraiser donate buttons disabled + "campaign closed" banner; Archived parent → 410 Gone for parent + all children
  - [ ] **Slug uniqueness**: parent slug unique per tenant; child slug unique within parent (path is hierarchical); slug auto-from-name; reserved slug list rejected (admin/api/p/p2p/preview/login/auth/start)
  - [ ] **Validate-for-publish** blocks parent Publish until: CampaignName + Slug + Campaign Type + Goal + Linked Donation Purpose + Description + (if Timed) Start/End Date + ≥1 enabled payment method + ≥1 amount chip OR AllowCustomAmount + ≥1 communication-tab template selected (defaults work) + (if AllowTeamFundraising) Default Team Goal + Max Team Size set
  - [ ] **Anonymous donate flow** (parent + child) → CSRF + honeypot + rate-limit (5/min/IP/slug); submit creates `fund.GlobalDonation` linked to `P2PCampaignPageId` AND optional `P2PFundraiserId`; for child donations, totals roll up to parent campaign aggregates
  - [ ] **Anonymous Start-Fundraiser flow** → CSRF + honeypot + rate-limit (3/min/IP/campaignSlug); upserts `crm.Contact` by email; creates `P2PFundraiser` row; creates `P2PFundraiserMilestone` rows from wizard step 2; sends welcome email (SERVICE_PLACEHOLDER if email infra missing)
  - [ ] **Leaderboard query** ranks fundraisers by SUM(donation.NetAmount) GROUP BY P2PFundraiserId; top-10 by default; ties broken by RegisteredAt; cached 60s server-side
  - [ ] **OG tags** rendered in initial SSR HTML for both parent and child routes; share preview correct on FB/Twitter/WhatsApp
  - [ ] Status Bar in admin setup shows real aggregates (totalRaised / totalFundraisers / totalDonors / pendingApprovals / activeFundraisers)
- [ ] Empty / loading / error states render on both setup and public surfaces
- [ ] DB Seed — admin menu visible at `SET_PUBLICPAGES > P2PCAMPAIGNPAGE`; sample published parent + 3 child fundraisers (1 individual + 1 team + 1 pending) renders for E2E QA at `/p2p/run-for-education-2026`

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage for setup AND public page

Screen: P2PCampaignPage
Module: Setting (admin) / Public (anonymous-rendered)
Schema: `fund`
Group: DonationModels

Business: This is the **public-facing peer-to-peer (P2P) campaign landing page** an NGO publishes to recruit supporters who fundraise on the org's behalf — a multi-page fundraising structure where one parent campaign hosts many supporter-owned child fundraiser pages. The admin setup screen lets a BUSINESSADMIN configure every aspect of the experience across 5 tabs: page identity (name, slug, campaign type — timed / occasion-based / always-active, goal, linked donation purpose, description, story, hero image, video, organizational unit), fundraiser settings (public registration toggle, approval mode auto/manual, individual goal min/default/max, team fundraising toggle with team goal + max size, fundraiser-page-customization permissions, gamification toggles for leaderboard / fundraiser-count / achievement-badges), donation settings (suggested amount chips, custom amount, recurring + anonymous toggles, 4 payment methods, donor-cover-fees, matching-gift integration), branding & page (theme preset, primary/secondary color, logo, header style, page-section-visibility toggles, custom CSS — with live preview pane in desktop+mobile mode), and communication (6 email-trigger templates + 2 WhatsApp triggers + default share message + OG image). The headline conversion goal is **two-sided**: (1) recruit supporters who become fundraisers (each creating their own child page), and (2) collect donations through both the parent landing AND every active child fundraiser page. **Lifecycle for the parent**: Draft → Published → Active → Closed → Archived; only Active pages accept supporter signup and donations; Draft renders only with preview-token; Closed renders banner "This campaign has ended" and disables both Become-a-Fundraiser and Donate buttons; Archived returns 410 Gone. **Lifecycle for child fundraiser pages**: Draft → Pending (when ApprovalMode=manual) → Active → Paused (admin-triggered) / Rejected (admin-triggered) → Completed (auto on parent Closed). **What breaks if mis-set**: donors charged but no record stored (gateway webhook missing), expired payment-gateway connect leaving "Donate" button dead, missing CSRF/honeypot enabling bot/spam fundraiser registrations, slug rename after donations attached → link rot on shared social posts, OG meta missing → bad share previews → low recruitment, ApprovalMode=manual without admin actually monitoring queue → fundraisers stuck Pending forever and bounce, child slug colliding with parent slug → 404, leaderboard rebuilt on every render → DB load. Related screens: receipts settle through the existing `fund.GlobalDonation` pipeline (this page is a SOURCE, not a donation store) — donations get `P2PCampaignPageId` AND optional `P2PFundraiserId` set on `fund.GlobalDonations`; recurring creates `fund.RecurringDonationSchedule`; donor records upsert into `crm.Contacts`; payment gateway credentials live at `setting/paymentconfig/companypaymentgateway` (referenced by id); the underlying generic Campaign entity at `app.Campaigns` already exists and is **referenced by FK from this page** (CampaignId — every P2PCampaignPage wraps exactly one Campaign, reusing its Story / Goal / Donation Purposes / Suggested Amounts / Milestones / Team Members / Recurring Frequencies / Impact Metrics children); email/WhatsApp templates live at `notify.EmailTemplates` / `notify.WhatsAppTemplates` (referenced by id). **What's unique about this page's UX vs a simple donation page**: it has **two layered public surfaces** — the **parent campaign landing** at `/p2p/{campaignSlug}` (banner, progress, leaderboard, "Become a Fundraiser" + "Donate Now" CTAs), and **per-fundraiser child pages** at `/p2p/{campaignSlug}/{fundraiserSlug}` (personal cover, story, donation form scoped to fundraiser, share buttons, optional team section). Every donation through a child page rolls up to the parent total. The parent admin sees an embedded grid of child fundraisers with approval queue when ApprovalMode=manual. The "Start Fundraiser" 4-step wizard is anonymous-callable but creates / matches a CRM Contact and may require admin approval before going live.

> **Why this section is heavier than other types**: Three render trees (admin / public parent / public child / public start-wizard) PLUS a parent-with-children data model PLUS a two-tier lifecycle PLUS an approval workflow PLUS a leaderboard aggregation. A developer that misses any of these will ship a broken half-product. Read this whole section before opening §⑥.

---

## ② Storage & Source Model

> **Consumer**: BA Agent → Backend Developer
>
> **Storage Pattern**: `parent-with-children`
>
> Each tenant may have multiple `P2PCampaignPage` rows — e.g. "Run for Education 2026" + "Ramadan Marathon 2026" + "Walk of Hope — Spring 2026". Each parent row owns many child `P2PFundraiser` rows (each = one supporter's personal fundraising page). Optional grandchildren: `P2PFundraiserTeam` (when AllowTeamFundraising), `P2PFundraiserMilestone` (per-fundraiser custom milestones).
>
> **Important architectural decision — link to existing Campaign entity**:
> The existing `app.Campaigns` entity already covers most of the Tab 1 fields (CampaignName, CampaignCode, GoalAmount, GoalCurrencyId, StartDate, EndDate, ShortDescription, FullDescription, CampaignStory, ImageUrl, VideoUrl, AllowRecurring, MinDonationAmount, OrganizationalUnitId, CampaignTypeId, CampaignCategoryId, ThankYouEmailTemplateId, ReceiptEmailTemplateId, WhatsAppFollowUpTemplateId, ShareTitle/Description/Image, IsTaxDeductible, etc.) AND has child collections for CampaignDonationPurpose, CampaignSuggestedAmount, CampaignMilestone, CampaignTeamMember, CampaignRecurringFrequency, CampaignImpactMetric, CampaignTrackingMetric. **Do NOT duplicate these fields on `P2PCampaignPage`** — instead, `P2PCampaignPage` holds a required FK to `Campaign` and only stores the **P2P-page-specific extras** (slug, lifecycle, ImplementationType, fundraiser-settings, gamification, branding, custom CSS, communication-tab toggles for triggers Campaign doesn't already cover, OG meta). Tab 1 fields write through to the Campaign row (creating it if needed on first save). This keeps the schema lean and reuses Campaign's existing children seamlessly.
>
> **Alternative considered & rejected**: Embedding all Campaign fields directly on `P2PCampaignPage`. Rejected because Campaign is reused by other campaign types (regular fundraising campaigns) and centralizing data on Campaign keeps cross-campaign reporting consistent.

### Tables

> Audit columns omitted (inherited from `Entity` base). CompanyId always present (tenant scope). Schema = `fund`.

**Primary table**: `fund."P2PCampaignPages"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| P2PCampaignPageId | int | — | PK | — | Identity primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope |
| CampaignId | int | — | YES | app.Campaigns | The underlying Campaign — created/updated on save; cascade-restrict |
| Slug | string | 100 | YES | — | URL slug; unique per tenant; lower-kebab; auto-from-Campaign.CampaignName on create |
| PageStatus | string | 20 | YES | — | Draft / Published / Active / Closed / Archived (lifecycle distinct from Campaign.CampaignStatusId) |
| PublishedAt | DateTime? | — | NO | — | Set on Draft→Published transition |
| ArchivedAt | DateTime? | — | NO | — | Set on Archive |
| CampaignTypeKind | string | 20 | YES | — | `TIMED` \| `OCCASION` \| `ALWAYS_ACTIVE` (P2P-specific flavour; drives StartDate/EndDate visibility) |
| **Fundraiser Settings** | | | | | |
| AllowPublicRegistration | bool | — | YES | — | Default TRUE; gates public "Start Fundraiser" CTA |
| FundraiserApprovalMode | string | 20 | YES | — | `AUTO` \| `MANUAL`; default AUTO |
| DefaultIndividualGoal | decimal | 12,2 | YES | — | Default 500 |
| MinIndividualGoal | decimal | 12,2 | YES | — | Default 100 |
| MaxIndividualGoal | decimal | 12,2 | YES | — | Default 10000 |
| AllowTeamFundraising | bool | — | YES | — | Default FALSE; gates team fields |
| DefaultTeamGoal | decimal? | 12,2 | NO | — | Default 5000 (visible only if AllowTeamFundraising) |
| MaxTeamSize | int? | — | NO | — | Default 20 (visible only if AllowTeamFundraising) |
| FundraiserPageOptionsJson | jsonb | — | YES | — | `{"profilePhoto":true,"personalStory":true,"personalGoal":true,"coverImage":true,"customVideo":false,"milestones":false}` — per-option toggles for what fundraisers may customize |
| **Gamification** | | | | | |
| ShowLeaderboard | bool | — | YES | — | Default TRUE |
| ShowFundraiserCount | bool | — | YES | — | Default TRUE |
| AchievementBadgesEnabled | bool | — | YES | — | Default FALSE |
| **Donation Settings** (P2P-specific overrides — Campaign suggested amounts already exist via CampaignSuggestedAmount; this page may override with its own chips) | | | | | |
| OverrideDonationSettings | bool | — | YES | — | When TRUE, chips/min/recurring/anon below are used; when FALSE, use Campaign defaults |
| AmountChipsJson | jsonb | — | NO | — | `[25,50,100,250]` array of decimals; max 8 |
| AllowCustomAmount | bool | — | YES | — | Default TRUE |
| MinimumDonationAmount | decimal | 10,2 | YES | — | Default 5 |
| AllowRecurringDonations | bool | — | YES | — | Default TRUE |
| AllowAnonymousDonations | bool | — | YES | — | Default TRUE |
| EnabledPaymentMethodsJson | jsonb | — | YES | — | `[{"code":"CARD","enabled":true,"order":1},...]` — 4 methods (Card / PayPal / ApplePay / BankTransfer) with toggle |
| CompanyPaymentGatewayId | int? | — | NO | fund.CompanyPaymentGateways | Inherited from Campaign if NULL |
| AllowDonorCoverFees | bool | — | YES | — | Default TRUE |
| MatchingGiftIntegrationEnabled | bool | — | YES | — | Default FALSE |
| **Branding & Page** | | | | | |
| PageTheme | string | 20 | YES | — | `default` \| `dark` \| `colorful` \| `minimal` |
| PrimaryColorHex | string | 7 | YES | — | Default `#0e7490` |
| SecondaryColorHex | string | 7 | YES | — | Default `#06b6d4` |
| LogoUrl | string | 500 | NO | — | Org logo override (when NULL falls back to tenant default) |
| HeaderStyle | string | 20 | YES | — | `full-width-hero` \| `split` \| `minimal` |
| ShowOrganizationInfo | bool | — | YES | — | Default TRUE |
| ShowImpactStats | bool | — | YES | — | Default TRUE |
| ShowDonorWall | bool | — | YES | — | Default TRUE |
| CustomCssOverride | string | 8000 | NO | — | Optional CSS pasted by admin; sanitized server-side |
| **Communication** (template ids on Campaign cover the existing Thank-You / Receipt / WhatsApp follow-up; the additional triggers below are P2P-specific) | | | | | |
| RegistrationConfirmationEmailTemplateId | int? | — | NO | notify.EmailTemplates | "P2P Welcome" trigger |
| DonationToFundraiserEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent to fundraiser when their page receives a donation |
| DonationToDonorEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent to donor after donating to a child page (overrides Campaign.ReceiptEmailTemplate when set) |
| GoalReachedEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent to fundraiser when their personal goal hits 100% |
| WeeklyProgressEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent to fundraisers each week summarizing their progress |
| CampaignEndSummaryEmailTemplateId | int? | — | NO | notify.EmailTemplates | Sent at parent-campaign close to all fundraisers |
| WhatsAppDonationAlertEnabled | bool | — | YES | — | Default TRUE |
| WhatsAppDonationAlertTemplateId | int? | — | NO | notify.WhatsAppTemplates | — |
| WhatsAppGoalMilestoneAlertsEnabled | bool | — | YES | — | Default TRUE; fires at 25/50/75/100% (no template select — uses inline message) |
| **Social & SEO** | | | | | |
| DefaultShareMessage | string | 500 | NO | — | Pre-filled social-share text |
| OgImageUrl | string | 500 | NO | — | Override Campaign.ShareImageUrl (1200x630) |
| OgTitle | string | 200 | NO | — | Defaults to Campaign.ShareTitle / CampaignName |
| OgDescription | string | 500 | NO | — | Defaults to Campaign.ShareDescription / Campaign.ShortDescription |
| RobotsIndexable | bool | — | YES | — | Default TRUE |

**Slug uniqueness**:
- Unique filtered index on `(CompanyId, LOWER(Slug))` WHERE `IsDeleted = FALSE`
- Reserved-slug list rejected (case-insensitive): `admin / api / p / p2p / preview / login / signup / oauth / public / assets / static / start / fundraise / embed / _next / ic`

**Status transition rules** (BE-enforced):
- Draft → Published only when `ValidateP2PCampaignPageForPublish` passes
- Published → Active automatic at Campaign.StartDate (or = Published if no StartDate)
- Active → Closed automatic at Campaign.EndDate, or admin "Close Early"
- Any → Archived admin-triggered (soft-delete; preserves donation FK rows)
- Closing parent flips ALL child P2PFundraisers to `Completed`

### Child Tables

**Child 1 — `fund."P2PFundraisers"`** (per-supporter child page)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| P2PFundraiserId | int | — | PK | — | Identity |
| P2PCampaignPageId | int | — | YES | fund.P2PCampaignPages | Cascade-delete on parent archive |
| CompanyId | int | — | YES | corg.Companies | Tenant scope |
| ContactId | int | — | YES | corg.Contacts | The supporter; upserted on Start-Fundraiser submit |
| FundraiserType | string | 20 | YES | — | `INDIVIDUAL` \| `TEAM` |
| TeamId | int? | — | NO | fund.P2PFundraiserTeams | Set when FundraiserType=TEAM (team captain fundraiser is the one with `IsTeamCaptain=true` on team row) |
| IsTeamCaptain | bool | — | YES | — | Default FALSE; TRUE for the supporter who created the team |
| PageTitle | string | 200 | YES | — | "Khalid's Marathon for Orphan Care" |
| Slug | string | 100 | YES | — | Unique within `(P2PCampaignPageId, Slug)`; auto-from-fundraiser-name; admin/fundraiser editable |
| PersonalGoal | decimal | 12,2 | YES | — | Bounded by parent's Min/Max IndividualGoal |
| GoalCurrencyId | int | — | YES | com.Currencies | Default = Campaign.GoalCurrencyId |
| IsGoalVisible | bool | — | YES | — | Default TRUE |
| PersonalStory | string | 8000 | NO | — | Rich text |
| CoverImageUrl | string | 500 | NO | — | 1200x630 |
| CoverVideoUrl | string | 500 | NO | — | YouTube/Vimeo embed URL |
| ProfilePhotoUrl | string | 500 | NO | — | Defaults from Contact record |
| FundraiserStatus | string | 20 | YES | — | `Draft` \| `Pending` \| `Active` \| `Paused` \| `Rejected` \| `Completed` |
| PendingReason | string | 500 | NO | — | Auto-set when ApprovalMode=manual ("Awaiting admin approval") |
| RejectionReason | string | 1000 | NO | — | Set when admin rejects |
| ApprovedAt | DateTime? | — | NO | — | — |
| RejectedAt | DateTime? | — | NO | — | — |
| RegisteredAt | DateTime | — | YES | — | Default = now |
| **Donation overrides** | | | | | |
| UseDefaultDonationAmounts | bool | — | YES | — | Default TRUE; when FALSE uses CustomAmountChipsJson |
| CustomAmountChipsJson | jsonb | — | NO | — | `[50,100,250,500]` |
| AllowCustomAmount | bool | — | YES | — | Default TRUE |
| **Matching gift** | | | | | |
| EmployerMatchingEnabled | bool | — | YES | — | Default FALSE |
| EmployerCompanyName | string | 200 | NO | — | When EmployerMatchingEnabled |
| EmployerMatchRatio | string | 5 | NO | — | `1:1` \| `2:1` \| `3:1` |
| **Offline donations** | | | | | |
| AllowOfflineDonations | bool | — | YES | — | Default TRUE |
| **Thank-you & sharing** | | | | | |
| UseDefaultThankYouMessage | bool | — | YES | — | Default TRUE |
| CustomThankYouMessage | string | 1000 | NO | — | Used when UseDefaultThankYouMessage=FALSE |
| SocialShareMessagesJson | jsonb | — | NO | — | `{"facebook":"...","twitter":"...","whatsapp":"..."}` |
| **Aggregates** (denormalized for fast reads — recomputed by donation-pipeline events) | | | | | |
| RaisedAmount | decimal | 14,2 | YES | — | Default 0 |
| DonorCount | int | — | YES | — | Default 0 |
| PageViewCount | int | — | YES | — | Default 0 |
| **Admin flags** | | | | | |
| IsFeaturedOnCampaign | bool | — | YES | — | Default FALSE — admin pin to top of leaderboard |

**Slug uniqueness for child**: Unique filtered index on `(P2PCampaignPageId, LOWER(Slug))` WHERE `IsDeleted = FALSE`.

**Child 2 — `fund."P2PFundraiserTeams"`** (when AllowTeamFundraising)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| P2PFundraiserTeamId | int | — | PK | — | Identity |
| P2PCampaignPageId | int | — | YES | fund.P2PCampaignPages | Cascade-delete |
| CompanyId | int | — | YES | corg.Companies | Tenant scope |
| TeamName | string | 200 | YES | — | "Dubai Runners Club" |
| TeamSlug | string | 100 | YES | — | Auto from TeamName; unique within `(P2PCampaignPageId, TeamSlug)` |
| TeamSize | int | — | YES | — | Max members allowed |
| CaptainContactId | int | — | YES | corg.Contacts | Team creator |
| SharedGoal | decimal | 12,2 | YES | — | Bounded by parent's Min/Max IndividualGoal × TeamSize (advisory) |
| GoalCurrencyId | int | — | YES | com.Currencies | — |
| LogoUrl | string | 500 | NO | — | Optional team logo |
| RaisedAmount | decimal | 14,2 | YES | — | Aggregated from child P2PFundraisers where TeamId = this |
| MemberCount | int | — | YES | — | Computed from P2PFundraisers count where TeamId = this |

**Child 3 — `fund."P2PFundraiserMilestones"`** (per-fundraiser custom milestones, only when parent FundraiserPageOptionsJson.milestones=TRUE AND fundraiser opted to customize)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| P2PFundraiserMilestoneId | int | — | PK | — | Identity |
| P2PFundraiserId | int | — | YES | fund.P2PFundraisers | Cascade-delete |
| Amount | decimal | 12,2 | YES | — | E.g. $500 |
| MilestoneMessage | string | 500 | YES | — | E.g. "First milestone! 10% of my goal!" |
| OrderBy | int | — | YES | — | Display order |
| IsAchieved | bool | — | YES | — | Default FALSE; flips TRUE when RaisedAmount >= Amount |
| AchievedAt | DateTime? | — | NO | — | — |

**Child 4 (analytics, optional) — `fund."P2PFundraiserUpdates"`** (fundraiser-posted updates shown on child page — covers the "Updates" section of the public child layout)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| P2PFundraiserUpdateId | int | — | PK | — | Identity |
| P2PFundraiserId | int | — | YES | fund.P2PFundraisers | Cascade-delete |
| UpdateText | string | 2000 | YES | — | E.g. "Hit 500%! You all are incredible! 🎉" |
| PublishedAt | DateTime | — | YES | — | Default = now |

> If timeline is tight, `P2PFundraiserUpdates` may be deferred to a future enhancement — note ISSUE entry in §⑫ rather than dropping silently.

### Donation Linkage (DO NOT add donation columns here — extend existing entity)

**Modify** `fund."GlobalDonations"` to add:

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| P2PCampaignPageId | int? | NO | fund.P2PCampaignPages | NULL for non-P2P donations; SET for any donation through a P2P parent or child |
| P2PFundraiserId | int? | NO | fund.P2PFundraisers | NULL for parent-direct donations; SET for child-page donations |

These two nullable FKs enable aggregating donations:
- **Per parent campaign**: `WHERE P2PCampaignPageId = X` (sums both parent-direct + all child donations)
- **Per fundraiser**: `WHERE P2PFundraiserId = Y` (just that fundraiser's donations)
- **Per team**: `WHERE P2PFundraiserId IN (SELECT P2PFundraiserId FROM P2PFundraisers WHERE TeamId = Z)`

Migration: `ALTER TABLE fund."GlobalDonations" ADD COLUMN "P2PCampaignPageId" int NULL, ADD COLUMN "P2PFundraiserId" int NULL` + filtered FK constraints. Existing rows stay NULL.

> **DO NOT** add a separate "P2PCampaignDonation" table — two nullable FKs on GlobalDonation is the cleanest queryable approach. Note: this is the SAME pattern OnlineDonationPage uses (single nullable FK there) — extends naturally.

> **Coexistence with OnlineDonationPage**: A donation may be linked to ONLY ONE source page — the GlobalDonation row will have either `OnlineDonationPageId` OR `P2PCampaignPageId` set, never both. Add a CHECK constraint: `CHECK (NUM_NONNULLS(OnlineDonationPageId, P2PCampaignPageId) <= 1)`.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------------|---------------|-------------------|
| CampaignId | Campaign | `Base.Domain/Models/ApplicationModels/Campaign.cs` (schema `app`) | `getAllCampaignList` | `campaignName` | `CampaignResponseDto` |
| ContactId (P2PFundraiser) | Contact | `Base.Domain/Models/ContactModels/Contact.cs` (schema `corg`) | `getAllContactList` | concat(`firstName` + " " + `lastName`) | `ContactResponseDto` |
| GoalCurrencyId / CurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` (schema `com`) | `getAllCurrencyList` | `currencyCode` (display) + `currencyName` | `CurrencyResponseDto` |
| Linked Donation Purpose (via Campaign.DonationPurposes) | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` (schema `fund`) | `getAllDonationPurposeList` | `donationPurposeName` | `DonationPurposeResponseDto` |
| CompanyPaymentGatewayId | CompanyPaymentGateway | `Base.Domain/Models/DonationModels/CompanyPaymentGateway.cs` (schema `fund`) | `getAllCompanyPaymentGatewayList` | join `paymentGateway.gatewayName` | `CompanyPaymentGatewayResponseDto` |
| OrganizationalUnitId (via Campaign) | OrganizationalUnit | `Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs` (schema `app`) | `getAllOrganizationalUnitList` | `organizationalUnitName` | `OrganizationalUnitResponseDto` |
| RegistrationConfirmationEmailTemplateId / DonationToFundraiserEmailTemplateId / DonationToDonorEmailTemplateId / GoalReachedEmailTemplateId / WeeklyProgressEmailTemplateId / CampaignEndSummaryEmailTemplateId | EmailTemplate | `Base.Domain/Models/NotifyModels/EmailTemplate.cs` (schema `notify`) | `getAllEmailTemplateList` | `templateName` | `EmailTemplateResponseDto` |
| WhatsAppDonationAlertTemplateId | WhatsAppTemplate | `Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs` (schema `notify`) | `getAllWhatsAppTemplateList` | `templateName` | `WhatsAppTemplateResponseDto` |

**Master-data references** (looked up by code via existing `MasterData` shared model — NO FK column on entity):

| Code | MasterDataType | Used For |
|------|----------------|----------|
| `WK / MO / QT / SA / AN` | `RECURRINGFREQUENCY` | Inherited from Campaign.RecurringFrequencies (no override needed) |
| `CARD / PAYPAL / APPLEPAY / BANKTRANSFER` | `PAYMENTMETHOD` | EnabledPaymentMethodsJson |
| `TIMED / OCCASION / ALWAYS_ACTIVE` | `P2PCAMPAIGNTYPE` | CampaignTypeKind (NEW MasterDataType — seed in step 1 of DB seed script) |

> Verify `PAYMENTMETHOD` MasterDataType exists (likely seeded by OnlineDonationPage prerequisite); if absent, seed it (`CARD/PAYPAL/APPLEPAY/BANKTRANSFER`) in DB seed script step 1.
> Seed new `P2PCAMPAIGNTYPE` MasterDataType with 3 rows (`TIMED`/`OCCASION`/`ALWAYS_ACTIVE`).

**Aggregation sources** (not strictly FK — used for stats / leaderboard queries):

| Source | Aggregate | Used In | Filter |
|--------|-----------|---------|--------|
| `fund.GlobalDonations` | `SUM(NetAmount)` GROUP BY P2PCampaignPageId | parent totalRaised (status bar + parent-page progress bar) | Status='Completed' |
| `fund.GlobalDonations` | `COUNT(DISTINCT ContactId)` GROUP BY P2PCampaignPageId | parent totalDonors (status bar + "{N} donors") | Status='Completed' |
| `fund.GlobalDonations` | `COUNT(*)` GROUP BY P2PCampaignPageId | parent totalDonations | Status='Completed' |
| `fund.P2PFundraisers` | `COUNT(*)` GROUP BY P2PCampaignPageId | parent totalFundraisers / activeFundraisers (FundraiserStatus filter) | — |
| `fund.P2PFundraisers` | `COUNT(*)` WHERE FundraiserStatus='Pending' | pendingApprovals KPI card | — |
| `fund.GlobalDonations` | `SUM(NetAmount)` GROUP BY P2PFundraiserId, ORDER BY SUM DESC LIMIT N | leaderboard (top-N) | Status='Completed', GROUP BY P2PFundraiserId |
| `fund.GlobalDonations` | `SUM(NetAmount)` GROUP BY P2PFundraiserId | child-page RaisedAmount (denormalized after each donation event; or computed on render) | Status='Completed' |
| `fund.GlobalDonations` | `MAX(DonationDate)` GROUP BY P2PCampaignPageId | parent lastDonationAt | Status='Completed' |

> Leaderboard is cached server-side 60s — never compute on every public request.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Slug Rules** (parent + child both apply):

- Auto-generate from CampaignName (parent) / FundraiserName (child) on Create — lowercase, replace whitespace with `-`, strip non-alphanumeric (keep `-`), collapse multiple `-`
- User can override via Slug field; same normalization applied; show "URL preview" inline in admin and "Available / Taken" indicator in public Start-Fundraiser wizard
- Reserved-slug list rejected (case-insensitive): `admin, api, p, p2p, preview, login, signup, oauth, public, assets, static, start, fundraise, embed, _next, ic`
- Parent uniqueness enforced per tenant — composite (CompanyId, LOWER(Slug))
- Child uniqueness enforced per parent — composite (P2PCampaignPageId, LOWER(Slug))
- Parent slug **immutable post-Activation when ≥1 donation attached**
- Child slug **immutable post-Activation when ≥1 donation attached**
- Validator returns 422 with `{field:"slug", code:"SLUG_RESERVED|SLUG_TAKEN|SLUG_LOCKED_AFTER_DONATIONS"}`

**Lifecycle Rules — Parent**:

| State | Set by | Public route behavior | "Become a Fundraiser" CTA | "Donate Now" CTA |
|-------|--------|----------------------|---------------------------|-------------------|
| Draft | Initial Create | 404 to public; preview-token grants temporary access | Hidden | Hidden |
| Published | Admin "Publish" action | Renders publicly | Live (if AllowPublicRegistration) | Live |
| Active | Auto at Campaign.StartDate (or = Published if no StartDate) | Renders publicly | Live (if AllowPublicRegistration) | Live |
| Closed | Auto at Campaign.EndDate, or admin "Close Early" | Renders publicly with "This campaign has ended" banner | Hidden | Disabled |
| Archived | Admin "Archive" | 410 Gone (admin can configure redirect to org default) | N/A | N/A |

**Lifecycle Rules — Child Fundraiser**:

| State | Set by | Public child route behavior | Donate CTA |
|-------|--------|------------------------------|------------|
| Draft | Initial creation by admin (without going through wizard) | 404 to public | Disabled |
| Pending | Created via wizard when ApprovalMode=MANUAL | 404 to public; "your page is under review" message via login link | Disabled |
| Active | Auto on creation when ApprovalMode=AUTO; admin Approve flips Pending→Active | Renders publicly | Live (if parent Active) |
| Paused | Admin manual pause | Renders with "Page paused" banner | Disabled |
| Rejected | Admin Reject in queue | 404 to public; rejection email sent | Disabled |
| Completed | Auto when parent Closed | Renders read-only with "Campaign closed" banner | Disabled |

**Required-to-Publish Validation — Parent** (return all violations as a list):

- CampaignName (Campaign.CampaignName) non-empty
- Slug set + unique + not reserved
- CampaignTypeKind set
- (CampaignTypeKind=TIMED) Campaign.StartDate AND Campaign.EndDate set + EndDate > StartDate
- Campaign.GoalAmount > 0
- ≥1 Campaign.DonationPurposes attached
- Campaign.ShortDescription non-empty
- Campaign.CampaignStory non-empty (length ≥ 100 chars recommended)
- ≥1 enabled payment method (EnabledPaymentMethodsJson length ≥ 1) OR Campaign-inherited methods
- ≥1 amount chip OR AllowCustomAmount=TRUE
- (AllowTeamFundraising=TRUE) DefaultTeamGoal > 0 + MaxTeamSize ≥ 2
- DefaultIndividualGoal between MinIndividualGoal and MaxIndividualGoal
- OG image present (warn but allow — falls back to Campaign.ShareImageUrl / ImageUrl)

**Required-to-Activate Validation — Child Fundraiser** (anonymous wizard submit):

- ContactId resolved (existing match or successful upsert)
- PageTitle non-empty
- PersonalGoal between parent.MinIndividualGoal and parent.MaxIndividualGoal
- (FundraiserType=TEAM) TeamId resolved (existing team join OR new team created with TeamName + TeamSize)
- Slug auto-generated unique within parent
- PersonalStory non-empty (warn but allow blank)

**Conditional Rules**:

- If `CampaignTypeKind = ALWAYS_ACTIVE` → Campaign.StartDate / Campaign.EndDate ignored on render; auto-Active immediately on Publish; no Closed-by-date transition
- If `CampaignTypeKind = OCCASION` → no end-date enforcement either; admin manually closes
- If `AllowPublicRegistration = FALSE` → public "Become a Fundraiser" CTA hidden; admin can still create child fundraisers via embedded grid
- If `FundraiserApprovalMode = AUTO` → wizard submission flips child to Active immediately
- If `FundraiserApprovalMode = MANUAL` → wizard submission flips child to Pending; admin sees in queue
- If `AllowTeamFundraising = FALSE` → wizard hides Team radio option; only Individual allowed
- If `AchievementBadgesEnabled = FALSE` → badges section not rendered on public child page even if milestones achieved
- If `OverrideDonationSettings = FALSE` → Campaign-level chips/min/recurring used; field overrides ignored
- If parent goes `Closed` → all child P2PFundraisers auto-flip to `Completed`; donate buttons disabled cross-tree

**Sensitive / Security-Critical Fields**:

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| CompanyPaymentGatewayId reference | secret-by-link | display gateway name, never API keys | referenced; never duplicated | log on rotate |
| CustomCssOverride | injection-risk | enforce CSP — disallow inline `<script>` patterns server-side | sanitize-strip `<script>` blocks; max 8000 chars | log on save |
| Donor PII captured on public form | regulatory | server-side only; never logged in plain text | encrypt-at-rest at column level if regulation requires | log access |
| Fundraiser Contact PII (during wizard) | regulatory | server-side only; CRM Contact upsert by email | bcrypt password if password set; otherwise login-link mode | log access |
| Anti-fraud markers (IP, UA, velocity) | operational | not on public; admin-only via audit | append-only | retain per policy |
| RejectionReason | operational | shown to fundraiser via login link only; admin-only otherwise | plain text | log |

**Public-form Hardening (anonymous-route concerns)**:

- Rate-limit donate-button POST: **5 attempts / minute / IP / slug** (parent or child)
- Rate-limit Start-Fundraiser POST: **3 attempts / minute / IP / parent-slug**
- CSRF token issued on initial public-page render; required on submit; rotation on each render
- Honeypot field `[name="website"]` hidden via CSS; submission with non-empty honeypot silently rejected (return mocked success to bot)
- reCAPTCHA v3 score check on Start-Fundraiser before payment-gateway hand-off — `SERVICE_PLACEHOLDER` until reCAPTCHA configured (returns score=1.0)
- All input validated server-side (never trust public client)
- CSP headers on public route: `script-src 'self' https://js.stripe.com https://www.paypal.com https://www.google.com/recaptcha; frame-src https://js.stripe.com https://www.paypal.com https://www.google.com/recaptcha; style-src 'self' 'unsafe-inline'; img-src * data: https:; frame-ancestors 'none'`
- Email-based duplicate-Contact dedupe: if email matches existing Contact, link wizard-created P2PFundraiser to existing ContactId rather than creating duplicate
- Idempotency: Start-Fundraiser POST has `idempotencyKey` (client-generated UUID) — re-posting same key returns same fundraiser response

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Publish Parent | Page goes live; URL becomes shareable | "Publishing makes this page public at /p2p/{slug}." | log "p2p page published" with snapshot |
| Unpublish Parent | Active → Draft; donations rejected; child pages stay accessible only via direct link until Repub | "Donors will see a closed page. Existing fundraisers will lose discoverability." | log |
| Close Early Parent | Active → Closed before EndDate; ALL child fundraisers → Completed; new donations rejected | "Close campaign now? {totalRaised} raised so far across {totalFundraisers} fundraisers." | log + email all fundraisers (CampaignEndSummary template) |
| Archive Parent | Soft-delete; URL returns 410 | type-name confirm ("type {campaignName} to archive") | log |
| Approve Child Fundraiser | Pending → Active; welcome email | none (admin click) | log |
| Reject Child Fundraiser | Pending → Rejected; rejection email with reason | "Reject {fundraiserName}? They'll be notified." + reason textarea (required) | log |
| Pause Child Fundraiser | Active → Paused; donate disabled | "Pause {fundraiserName}'s page? Donations will be disabled." | log |
| Edit Content (admin override) | Admin overwrites fundraiser's page content | "Override {fundraiserName}'s page? They'll be notified of the change." | log |
| Feature on Campaign | Pin to top of leaderboard | none (admin click toggle) | log |

**Role Gating**:

| Role | Setup access | Publish access | Approval queue | Notes |
|------|-------------|----------------|----------------|-------|
| BUSINESSADMIN | full | yes | yes | full lifecycle (target role for MVP) |
| Anonymous public | no setup access | — | — | sees Active parent + Active child + Start-Fundraiser wizard |
| Fundraiser owner (anonymous-with-login-link) | edit own child page only | — | — | login link emailed at registration; sees own page + own donations + own updates |

**Workflow** (cross-page — Start-Fundraiser flow):

- Anonymous supporter visits `/p2p/{campaignSlug}` → clicks "Become a Fundraiser" → routes to `/p2p/{campaignSlug}/start`
- Step 1: enters email + name → server upserts `crm.Contact` (dedupe by email) → if Individual, proceed to Step 2; if Team selected, captures team info
- Step 2: page title + slug + personal goal + story + cover photo + milestones (if parent allows custom milestones)
- Step 3: donation amount config + employer matching + offline donations + thank-you message + social share messages
- Step 4: review + activate option (Activate Now / Save as Draft / Schedule Activation) + notification checkboxes
- Submit:
  - If `ApprovalMode=AUTO` → P2PFundraiser created `Active` + welcome email + login-link (success screen renders)
  - If `ApprovalMode=MANUAL` → P2PFundraiser created `Pending` + admin notification email + "your page is under review" message
  - If "Save as Draft" → P2PFundraiser `Draft` (admin and fundraiser-via-login can edit)
  - If "Schedule Activation" → P2PFundraiser `Draft` + ScheduledActivationAt set; cron flips to Active at that time

**Donation Workflow (parent-direct or child-page)**:

- Anonymous donor visits `/p2p/{campaignSlug}` (parent) OR `/p2p/{campaignSlug}/{fundraiserSlug}` (child) → fills donate form
- Submits with CSRF token
- Server validates → calls gateway tokenize (SERVICE_PLACEHOLDER returns mock token)
- Server creates `fund.GlobalDonation` with `P2PCampaignPageId = X` AND `P2PFundraiserId = Y` (NULL if parent-direct)
- Server upserts `crm.Contact` by email (anonymous toggle hides name in receipt; Contact still created for stewardship)
- Returns redirect URL or thank-you state
- Async: receipt email fires (using DonationToDonorEmailTemplateId or Campaign.ReceiptEmailTemplate); fundraiser-alert email fires (DonationToFundraiserEmailTemplateId, child donations only); WhatsApp alert fires if WhatsAppDonationAlertEnabled
- Async: parent and (if applicable) child denormalized aggregates updated; milestone-achieved-event fires if RaisedAmount crosses a threshold (sends GoalReachedEmailTemplate at 100%)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: EXTERNAL_PAGE
**External-Page Sub-type**: `P2P_FUNDRAISER`
**Storage Pattern**: `parent-with-children`

**Slug Strategy**: `custom-with-fallback`
> Parent slug auto-derived from Campaign.CampaignName on Create; child slug auto-derived from FundraiserName on Start-Fundraiser submit. User may override either; auto re-applied on each save when slug field is cleared. Slug becomes immutable once donations attached (link rot guard). Path is hierarchical: `/p2p/{parentSlug}/{childSlug}`.

**Lifecycle Set — Parent**: `Draft / Published / Active / Closed / Archived` (full)
**Lifecycle Set — Child Fundraiser**: `Draft / Pending / Active / Paused / Rejected / Completed`

**Save Model**: `save-all`
> The mockup shows a manual Save Draft + Publish flow at both header and footer (no per-tab autosave shown; no per-card Save buttons). Each tab edit is held in form state; Save Draft persists across all tabs as Draft; Publish runs Validate-for-Publish then transitions Draft→Active.
> Frontend implementation note: Use a single page-level form-state Zustand store; tab switches don't lose unsaved edits; "Discard" button (in overflow) reverts to last-saved.

**Public Render Strategy**: `ssr`
> P2P parent pages must be SEO-indexable (Google "{org} P2P fundraiser" search). Use Next.js App Router `(public)/p2p/[campaignSlug]/page.tsx` with `generateMetadata` for OG tags + `revalidate: 60` for ISR. Child pages also `ssr` for OG tags on shared social posts. Start-Fundraiser wizard at `(public)/p2p/[campaignSlug]/start/page.tsx` uses `csr-after-shell` (interactive form, no SEO need).

**Reason**: P2P_FUNDRAISER sub-type fits because mockup shows parent campaign + supporter-owned child fundraiser pages with admin moderation queue, leaderboard, team fundraising, and approval workflow. `parent-with-children` storage works because each parent owns N child fundraisers (and optionally N teams) that share donation aggregation. `custom-with-fallback` slug matches both the parent slug-with-copy field and the wizard-step-2 child slug with availability indicator. `save-all` matches the mockup's explicit Save Draft + Publish buttons (no autosave UX shown). SSR for parent + child is critical for OG meta + organic-search; CSR for wizard is acceptable since form-only.

**Backend Patterns Required**:

For P2P_FUNDRAISER (parent-with-children):

- [x] GetAllP2PCampaignPageList query (admin list view) — tenant-scoped, paginated, status filter; returns include child counts (totalFundraisers, pendingApprovals, totalRaised)
- [x] GetP2PCampaignPageById query (admin editor)
- [x] GetP2PCampaignPageBySlug query (public parent route) — anonymous-allowed, status-gated
- [x] GetP2PCampaignPageStats query (admin) — totalRaised, totalDonors, totalFundraisers, activeFundraisers, pendingApprovals, lastDonationAt, conversionRate-PLACEHOLDER
- [x] GetP2PCampaignPagePublishValidation query — returns missing-fields list for editor
- [x] CreateP2PCampaignPage mutation (creates Campaign-row first if needed, then P2P page row, defaults to Draft)
- [x] UpdateP2PCampaignPage mutation (updates BOTH Campaign and P2P fields atomically)
- [x] PublishP2PCampaignPage / UnpublishP2PCampaignPage / CloseP2PCampaignPage / ArchiveP2PCampaignPage mutations
- [x] Slug uniqueness validator + reserved-slug rejection (parent + child)

- [x] GetAllFundraisersByP2PCampaignPage query — paginated; sort by Most Raised / Most Donors / Most Recent / Alphabetical; status filter (All / Active / Pending / Paused / Completed); search by fundraiser name/email
- [x] GetP2PFundraiserById query (admin detail panel)
- [x] GetP2PFundraiserBySlug query (public child route) — anonymous-allowed, status-gated
- [x] GetP2PFundraiserStats query — raisedAmount, donorCount, pageViewCount, conversionRate, share counts per platform
- [x] GetP2PCampaignPageLeaderboard query — top-N by SUM(donation), tie-break by RegisteredAt; cached 60s
- [x] GetP2PCampaignPagePendingFundraisers query — for approval queue
- [x] CreateP2PFundraiser mutation (admin direct-create — bypasses wizard)
- [x] UpdateP2PFundraiser mutation (admin override OR fundraiser-via-login-link)
- [x] ApproveP2PFundraiser mutation (admin) — flips Pending→Active + welcome email
- [x] RejectP2PFundraiser mutation (admin, with reason) — flips Pending→Rejected + rejection email
- [x] PauseP2PFundraiser / ResumeP2PFundraiser mutations
- [x] FeatureOnCampaignToggle mutation (admin pin to top)

- [x] CreateP2PFundraiserTeam mutation (when AllowTeamFundraising)
- [x] JoinP2PFundraiserTeam mutation (during wizard when supporter selects existing team)
- [x] DeleteP2PFundraiserTeam mutation (admin only)
- [x] ReorderP2PFundraiserMilestones mutation
- [x] CreateP2PFundraiserMilestone / Update / Delete mutations

- [x] **Public mutations** (anonymous, rate-limited, csrf-protected):
  - StartP2PFundraiser (creates Contact + P2PFundraiser + optional team)
  - InitiateP2PDonation (parent-direct OR child-routed)
  - ConfirmP2PDonation (gateway-callback)
- [x] Slug normalization + reserved-slug rejection
- [x] Tenant scoping (CompanyId from HttpContext for admin; CompanyId from slug-resolution for public)
- [x] Anti-fraud throttle on public submit endpoints

**Frontend Patterns Required**:

For P2P_FUNDRAISER — FOUR render trees:

- [x] Admin setup at `setting/publicpages/p2pcampaignpage` — list view (when `?id` not present) + tabbed editor (`?id=N`)
- [x] Editor: 5-tab layout (Basic Info / Fundraiser Settings / Donation Settings / Branding & Page / Communication)
- [x] Tab 4 (Branding & Page) uses split-pane (settings left + live preview right with desktop/mobile toggle)
- [x] Embedded **Active Fundraisers Grid** below the tabs (or as separate route at `?id=N&view=fundraisers`) — list of child fundraisers with status filter chips, search, sort, pagination, slide-out detail panel
- [x] **Approval Queue** subview of fundraisers grid (filtered to Pending status; bulk Approve/Reject; reject-reason modal)
- [x] Public parent at `(public)/p2p/[campaignSlug]/page.tsx` — SSR; org-header navbar + hero + progress + CTAs + story + leaderboard + donor wall + impact stats + footer
- [x] Public child fundraiser at `(public)/p2p/[campaignSlug]/[fundraiserSlug]/page.tsx` — SSR; cover photo + 2-col layout (profile + story + donors + updates + team / progress widget + donate form + share + parent-card-link) + sticky mobile donate bar
- [x] Public Start-Fundraiser wizard at `(public)/p2p/[campaignSlug]/start/page.tsx` — CSR; 4 steps; success screen
- [x] Public donate form (parent-direct + child-page variants) — shared component, respects donation settings
- [x] Login-link page at `(public)/p2p/[campaignSlug]/[fundraiserSlug]/manage?token=X` — fundraiser-owner edit mode (token-authenticated, time-limited)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: FOUR surfaces — admin setup, public parent, public child, public Start-Fundraiser wizard. Each must match the corresponding mockup exactly.

### 🎨 Visual Treatment Rules (apply to all surfaces)

1. **Public surfaces are brand-driven** — use tenant `PrimaryColorHex` (`--accent`) + `SecondaryColorHex` (`--accent-light`) + Logo + Hero Image. Do NOT re-use admin shell chrome.
2. **Admin setup mirrors live preview** — Tab 4 preview pane updates within 300ms of edit; never "save and refresh".
3. **Mobile preview is mandatory** — most donors are mobile. Tab 4 has device-switcher (Desktop / Mobile). Public child page has a sticky mobile donate bar at viewport bottom.
4. **Lifecycle state is visually clear** — Status badge in admin header (color-coded), banner on public Closed/Draft preview, amber row tint on Pending child fundraisers in admin grid.
5. **CTAs are dominant** — Primary `PrimaryColorHex` background, sized to prompt action. "Become a Fundraiser" + "Donate Now" both visible on parent above-the-fold; Donate sticky on mobile child.
6. **Trust signals first-class** — 🔒 Secure / 💳 Cards / ✉ Receipt / Privacy footer / "Powered by {org}" always visible.
7. **Settings cards consistent chrome** — white card + 12px radius + 1px border + section title with FA icon + body. Same chrome across all 5 tabs.
8. **Tabs are NOT the tab+content card pattern from MASTER_GRID** — tab nav rounds top corners; settings card rounds bottom corners; they visually attach as one element.
9. **Approval queue prominence** — when ApprovalMode=MANUAL and pendingCount > 0, status bar shows amber pill "{N} pending" linking directly to filtered grid.

**Anti-patterns to refuse**:
- Admin chrome bleeding into public route (sidebar visible to anonymous donors / supporters)
- "Save and refresh to preview" on Tab 4
- Tab 4 settings without live preview
- Public child page rendering admin breadcrumbs
- Single hero image stretched without responsive crop
- Leaderboard rebuilt on every public render (must be cached)
- Approval queue hidden behind a tab — must be visible from setup home
- Wizard step 1 creating duplicate Contacts on email collision (must dedupe)
- "Start Fundraiser" CTA visible when parent is Closed
- Child page donate button live when parent is Closed
- Admin override of fundraiser page silent (must notify fundraiser)

---

### 🅱️ Admin Setup UI

**Stamp**: `Layout Variant: tabbed-with-preview` (5 tabs; Tab 4 has split-pane editor + live preview pane). The editor list-view (when no `?id`) is `widgets-above-grid` (4 KPI summary cards above campaign list). Use Variant B (ScreenHeader + showHeader=false) — same FlowDataTableContainer pattern as other tabbed screens — to avoid double-header bug. Like OnlineDonationPage, this is NOT a DataTable, NOT a stock FlowDataTableContainer; the editor is a CUSTOM tabbed-with-preview layout.

#### B.1 — Admin List View (when no `?id` query param)

**Page Layout**:

```
┌──────────────────────────────────────────────────────────────────────┐
│ [Peer-to-Peer Campaigns]              [+ Create P2P Campaign]        │
│ Enable supporters to fundraise on your behalf                         │
├──────────────────────────────────────────────────────────────────────┤
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                 │
│ │👥 Active │ │👥 Total  │ │💰 Total  │ │📈 Avg /  │                 │
│ │Campaigns │ │Fundrais. │ │Raised    │ │Fundrais. │                 │
│ │   3      │ │   234    │ │$125,670  │ │  $538    │                 │
│ │Total: 8  │ │Active:189│ │This year │ │Top:$3,200│                 │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘                 │
├──────────────────────────────────────────────────────────────────────┤
│ [🔍 Search campaigns...]   [All(8)] [Active(4)] [Completed(2)] [Draft(1)] [Archived(1)] │
├──────────────────────────────────────────────────────────────────────┤
│ Name | Status | Goal | Raised | Progress | Fundraisers | Donors | Start | End | Actions │
│ ...                                                                   │
└──────────────────────────────────────────────────────────────────────┘
```

**Page Header**:
- H1: "Peer-to-Peer Campaigns"
- Subtitle: "Enable supporters to fundraise on your behalf"
- Header Action: `[+ Create P2P Campaign]` primary button → routes to setup form (no `?id`)

**KPI Summary Cards** (4 cards, `grid-template-columns: repeat(auto-fit, minmax(210px,1fr))`, `widgets-above-grid` variant):

| # | Icon (FA) | Color | Label | Value (sample) | Subtitle |
|---|-----------|-------|-------|----------------|----------|
| 1 | `fa-users` | teal | Active Campaigns | 3 | Total: 8 |
| 2 | `fa-user-group` | blue | Total Fundraisers | 234 | Active: 189 |
| 3 | `fa-hand-holding-dollar` | green | Total Raised (P2P) | $125,670 | This year |
| 4 | `fa-chart-line` | purple | Avg Per Fundraiser | $538 | Top: $3,200 |

> Phosphor equivalents (FE may use phosphor or remix): `ph:users`, `ph:users-three`, `ph:hand-coins`, `ph:chart-line-up`.

**Filter Bar**:
- Left: `[🔍 Search campaigns by name, status...]` text input
- Right: 5 filter chips: `All (count)` (default active) / `Active (count)` / `Completed (count)` / `Draft (count)` / `Archived (count)`

**Grid Columns** (display order — `widgets-above-grid`):

| # | Header | Type | Notes |
|---|--------|------|-------|
| 1 | Campaign Name | accent-link | Click → setup edit (`?id=N`) |
| 2 | Status | status-badge pill | colors per §G.1 |
| 3 | Goal | currency | Dash for Always Active |
| 4 | Raised | currency bold | Dash for Draft |
| 5 | Progress | mini progress bar + % | green/amber/red by threshold; Dash for Always Active or Draft |
| 6 | Fundraisers | int | Dash for Draft |
| 7 | Donors | int | Dash for Draft |
| 8 | Start Date | date | Dash for Always Active |
| 9 | End Date | date | Dash for Always Active |
| 10 | Actions | icon group | context-sensitive |

**Per-row Actions** (context-sensitive):

| Status | Actions |
|--------|---------|
| Active / Always Active | Dashboard (`fa-gauge-high` → `?id=N&view=fundraisers`), Edit (`fa-pen` → setup), View Page (`fa-eye` → public parent in new tab) |
| Completed | Dashboard, View Page, Duplicate (`fa-copy`) |
| Archived | View Page, Duplicate |
| Draft | Edit, Delete (`fa-trash`, danger hover) |

**Pagination**: prev / page-numbers / next; "Showing 1-N of total campaigns".

#### B.2 — Admin Setup Editor (when `?id=N` OR `?id=new`)

**Page Layout**:

```
┌──────────────────────────────────────────────────────────────────────┐
│ [Create P2P Campaign | Edit: {Campaign Name}]   [Cancel][Save Draft][🚀 Publish] │
│ Set up a new peer-to-peer fundraising campaign                        │
├──────────────────────────────────────────────────────────────────────┤
│ ●Active   Total Raised: $X   Fundraisers: Y   Donors: Z   Pending: P  │  ← Status Bar (only when editing existing)
├──────────────────────────────────────────────────────────────────────┤
│ [ℹ Basic Info | 👥 Fundraiser Settings | 💲 Donation Settings | 🎨 Branding & Page | ✉ Communication ] │  ← Tab Nav (5 tabs)
├──────────────────────────────────────────────────────────────────────┤
│ {Active tab content}                                                  │
│ ...                                                                   │
├──────────────────────────────────────────────────────────────────────┤
│ [Save Draft] [Preview Campaign Page] [🚀 Publish Campaign]            │  ← Form Footer (persistent across tabs)
└──────────────────────────────────────────────────────────────────────┘

(When editing existing AND status >= Published)
┌──────────────────────────────────────────────────────────────────────┐
│ Active Fundraisers ({totalFundraisers})    [Approval Queue ({pendingCount})] [Bulk Actions ▼] │
├──────────────────────────────────────────────────────────────────────┤
│ {Embedded fundraiser grid — same layout as B.3 below}                 │
└──────────────────────────────────────────────────────────────────────┘
```

**Header Actions** (top right):

| Action | Style | Icon | Visibility |
|--------|-------|------|------------|
| Cancel | outline-secondary | `fa-times` | always — navigates back to list, prompts on unsaved changes |
| Save Draft | outline-accent | `fa-save` | always |
| Publish | primary-accent | `fa-rocket` | always — runs Validate-for-Publish on click; shows missing-fields modal if invalid |

**Status Bar** (only when editing existing — not on `?id=new`): horizontal bar with current PageStatus dot + label + 4 aggregate stats (totalRaised / totalFundraisers / totalDonors / pendingApprovals — color-coded amber if >0).

**Tab Nav** (5 tabs, horizontal scrollable on mobile):

| # | Tab | Icon | Tab ID |
|---|-----|------|--------|
| 1 | Basic Info | `fa-info-circle` | `tab-basic-info` |
| 2 | Fundraiser Settings | `fa-users` | `tab-fundraiser-settings` |
| 3 | Donation Settings | `fa-hand-holding-dollar` | `tab-donation-settings` |
| 4 | Branding & Page | `fa-palette` | `tab-branding-page` |
| 5 | Communication | `fa-envelope` | `tab-communication` |

**TAB 1 — Basic Info** (single full-width settings-card):

| # | Field | Type | Required | Default / Options | Persists to |
|---|-------|------|----------|-------------------|-------------|
| 1 | Campaign Name | text | YES | placeholder "Run for Education 2026" | Campaign.CampaignName |
| 2 | Campaign Slug | url-display composite (read-only base + editable slug + copy button) | YES | base `donate.{tenant}.org/p2p/`; slug auto-from-name | P2PCampaignPage.Slug |
| 3 | Campaign Type | radio-card group (3 options) | YES | Selected: Timed Campaign | P2PCampaignPage.CampaignTypeKind. Options: TIMED (🏃 "Has start/end date — marathon, challenge, giving day"), OCCASION (🎄 "Ongoing — birthdays, memorials, milestones"), ALWAYS_ACTIVE (🔄 "Evergreen P2P fundraising page") |
| 4 | Start Date | date | conditional (TIMED) | placeholder | Campaign.StartDate |
| 5 | End Date | date | conditional (TIMED) | placeholder | Campaign.EndDate (validate > Start) |
| 6 | Campaign Goal | currency input-group (prefix "USD $") | YES | placeholder 50000 | Campaign.GoalAmount |
| 7 | Linked Donation Purpose | select | NO | options from `getAllDonationPurposeList` filtered to tenant | Campaign.DonationPurposes (single via junction CampaignDonationPurpose with order=0) |
| 8 | Campaign Description | rich-text editor (toolbar: B/I/U / list-ul/ol / link/image) | YES | — | Campaign.ShortDescription |
| 9 | Campaign Story | rich-text editor (toolbar: B/I/H / list-ul/quote / link/image/video) min-h 140px | NO | — | Campaign.CampaignStory |
| 10 | Hero Image | upload-area (1200x600 JPG/PNG max 5MB) | NO | — | Campaign.ImageUrl |
| 11 | Campaign Video | url input (YouTube/Vimeo embed URL) | NO | — | Campaign.VideoUrl |
| 12 | Organizational Unit | select | NO | options from `getAllOrganizationalUnitList` | Campaign.OrganizationalUnitId |

**TAB 2 — Fundraiser Settings**:

> Sectioned card with sub-section titles separated by border-bottom.

**Section: Registration** (icon `fa-user-plus`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| Allow public registration | toggle | ON | "Anyone can create a fundraiser page" |
| Fundraiser Approval | toggle | OFF | "Fundraiser pages need admin approval before going live" |

**Section: Goal Settings** (icon `fa-bullseye`) — 3 cols

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| Default Individual Goal | currency input (prefix `$`) | 500 | "Fundraiser can customize" |
| Minimum Goal | currency input | 100 | — |
| Maximum Goal | currency input | 10000 | Validate Default ∈ [Min, Max] |

**Section: Team Fundraising** (icon `fa-people-group`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| Allow Team Fundraising | toggle | ON | "Fundraisers can form teams with a shared goal" |
| Default Team Goal | currency input | 5000 | conditional, 2-col |
| Max Team Size | number input | 20 | conditional, 2-col |

**Section: Fundraiser Page Options** (icon `fa-sliders`) — sub-label "What fundraisers can customize on their page:"

6 checkboxes (saves to FundraiserPageOptionsJson):

| Checkbox | Default |
|----------|---------|
| Profile photo | checked |
| Personal story / why I'm fundraising | checked |
| Personal goal amount | checked |
| Cover image | checked |
| Custom video | unchecked |
| Milestones | unchecked |

**Section: Gamification** (icon `fa-trophy`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| Show leaderboard | toggle | ON | "Rank fundraisers by amount raised" |
| Show fundraiser count | toggle | ON | "Display total number of fundraisers publicly" |
| Achievement badges | toggle | OFF | "Award badges for milestones" |

Read-only badge list (display reference; actual badge logic backend-driven):

| Badge | Icon | Color |
|-------|------|-------|
| First Donation | `fa-star` | warning amber |
| 50% Goal | `fa-fire` | warning amber |
| Goal Reached | `fa-trophy` | warning amber |
| Top Fundraiser | `fa-crown` | warning amber |

**TAB 3 — Donation Settings**:

**Section: Donation Amounts** (icon `fa-dollar-sign`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| Suggested Amounts | chip-editor (`amount-chips` with `fa-times` remove + `+ Add Amount` dashed button) | $25, $50, $100, $250 | Max 8 chips |
| Allow Custom Amount | toggle | ON | — |
| Minimum Donation | currency input (max-w 200px, prefix $) | 5 | — |

**Section: Recurring & Anonymous** (icon `fa-repeat`)

| Field | Type | Default |
|-------|------|---------|
| Allow Recurring Donations | toggle | ON |
| Allow Anonymous Donations | toggle | ON |

**Section: Payment Methods** (icon `fa-credit-card`) — 4 rows of `payment-method-item` (icon + name + desc + toggle)

| # | Method | Icon | Description | Default |
|---|--------|------|-------------|---------|
| 1 | Credit/Debit Card (Stripe) | `fa-credit-card` (blue) | "Visa, Mastercard, Amex via Stripe" | ON |
| 2 | PayPal | `fab fa-paypal` (blue PayPal) | "PayPal checkout integration" | ON |
| 3 | Apple Pay / Google Pay | `fab fa-apple-pay` (green) | "Mobile wallet payments" | OFF |
| 4 | Bank Transfer | `fa-building-columns` (purple) | "Direct bank transfer / ACH" | OFF |

**Section: Additional Options** (icon `fa-gear`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| Allow donor to cover processing fees | toggle | ON | "Donors can optionally add processing fee to their donation" |
| Matching Gift Integration | toggle | OFF | "Link to matching-gifts configuration for corporate matching" |

**TAB 4 — Branding & Page** (split-pane: left settings + right live preview)

**Left panel — Card "Campaign Page Builder"** (icon `fa-palette`):

| Field | Type | Default / Options | Notes |
|-------|------|-------------------|-------|
| Page Theme | select | Default (selected) / Dark / Colorful / Minimal | — |
| Primary Color | color-picker + hex text input | `#0e7490` | 2-col |
| Secondary Color | color-picker + hex text input | `#06b6d4` | 2-col |
| Logo | compact upload-area (row layout) | empty; "Upload logo or use organization logo" | — |
| Header Style | radio-card group (3 options compact) | "Full-width Hero" selected | Options: Full-width Hero / Split (Image + Text) / Minimal |

**Sub-section Page Sections** (icon `fa-eye`):

| Field | Type | Default |
|-------|------|---------|
| Show Organization Info | toggle | ON |
| Show Impact Stats | toggle | ON |
| Show Donor Wall | toggle | ON |
| Show Fundraiser Leaderboard | toggle | ON |

| Field | Type | Notes |
|-------|------|-------|
| Custom CSS | code-block textarea (monospace dark bg, pre-wrap) | Optional. Placeholder shows `.campaign-hero { background-blend-mode: overlay; }` |

**Right panel — Live Preview Pane** (480px wide, sticky):

- Preview toolbar: "Live Preview" label (icon `fa-eye`) + device-switcher toggle group (Desktop / Mobile)
- Desktop: `browser-chrome` mockup with red/yellow/green dots, URL bar showing the public parent URL with green `fa-lock`, scrollable body max-h 600px
- Mobile: `phone-frame` with notch, scrollable phone-screen max-h 650px
- Renders the actual public parent page composition (hero + progress + CTAs + story + leaderboard + donor wall + impact stats + footer) with current settings applied
- Updates within 300ms debounce on any settings change

**TAB 5 — Communication**:

**Section: Auto-emails for Campaign** (icon `fa-envelope`) — 6 template-row items each with label + select dropdown sourced from `getAllEmailTemplateList`

| # | Trigger | Default selected option |
|---|---------|------------------------|
| 1 | Fundraiser Registration Confirmation | "P2P Welcome - Default" |
| 2 | Donation Received (to fundraiser) | "P2P Donation Alert - Default" |
| 3 | Donation Received (to donor) | "P2P Donor Thank You - Default" |
| 4 | Goal Reached Celebration | "P2P Goal Reached - Default" |
| 5 | Weekly Progress Update (to fundraisers) | "P2P Weekly Summary - Default" |
| 6 | Campaign End Summary | "P2P Campaign Wrap-up - Default" |

Each select includes "Create New Template..." option which navigates to template editor (`crm/communication/emailtemplate?action=new`).

**Section: WhatsApp Notifications** (icon `fab fa-whatsapp`, color `#25D366`)

| Trigger | Sub-label | Template select | Toggle Default |
|---------|-----------|----------------|----------------|
| New donation alert to fundraiser | — | "WA P2P Donation Alert" (from `getAllWhatsAppTemplateList`) | ON |
| Goal milestone alerts | "At 25%, 50%, 75%, 100%" | (no select — uses inline message templates) | ON |

**Section: Social Sharing** (icon `fa-share-nodes`)

| Field | Type | Default |
|-------|------|---------|
| Default Share Message | textarea (rows=2, resize vertical) | "I'm fundraising for {Org}! Help me reach my goal." |
| Open Graph Image | compact upload-area (1200x630) | — |
| Share Buttons | display-only social button row (Facebook / Twitter/X / LinkedIn / WhatsApp / Copy Link) | Reference for what fundraisers see on their page |

**Form Footer** (persistent across tabs, full-width below settings card):

| Button | Style | Icon |
|--------|-------|------|
| Save Draft | outline-secondary | `fa-save` |
| Preview Campaign Page | outline-accent | `fa-eye` (opens public preview in new tab with preview-token) |
| Publish Campaign | primary-accent | `fa-rocket` |

#### B.3 — Active Fundraisers Embedded Grid (when editing existing parent, status >= Published)

**Header** (above grid):
- "Active Fundraisers ({totalCount})"
- `[Approval Queue ({pendingCount})]` chip-link → filters grid to pending-only with prominent amber styling
- `[Bulk Actions ▼]` dropdown (when rows selected): Bulk Approve / Bulk Reject / Bulk Pause / Bulk Send Email

**Filter Bar** (row 1: search + 2 selects; row 2: status filter chips):

- Row 1:
  - `[🔍 Search by fundraiser name, email...]` text input
  - Campaign filter select: `[All Campaigns ▼]` (when editing parent X, locked to X)
  - Sort filter select: `[Sort: Most Raised ▼]` (Most Raised / Most Donors / Most Recent / Alphabetical)
- Row 2 (status filter chips):

| Chip | Default active |
|------|----------------|
| All ({totalCount}) | YES (unless via Approval Queue link) |
| Active ({activeCount}) | — |
| Pending Approval ({pendingCount}) | — (active when arriving via "Approval Queue" link) |
| Paused ({pausedCount}) | — |
| Completed ({completedCount}) | — |

**Grid Columns** (display order):

| # | Header | Type | Notes |
|---|--------|------|-------|
| 1 | Fundraiser | composite cell | gradient avatar (34px circle, initials) + name (accent-link) + email (muted small). Team rows: square avatar with `fa-people-group` + team-badge "{N} members" |
| 2 | Campaign | text | locked when editing single parent |
| 3 | Goal | currency | — |
| 4 | Raised | currency bold | — |
| 5 | Progress | mini progress bar + percentage | "over" class (green→teal gradient with 🔥) when ≥100% |
| 6 | Donors | int | — |
| 7 | Status | status-badge pill | color per §G.1 |
| 8 | Registered | date | — |
| 9 | Page Views | int | — |
| 10 | Actions | icon group | context-sensitive |

Pending rows: `background: #fffbeb` (amber tint), hover `#fef3c7`.
Team rows: bold first-cell font.
Entire row clickable → opens slide-out detail panel (button actions use `event.stopPropagation()`).

**Per-row Actions**:

| Status | Actions |
|--------|---------|
| Active | View Page (`fa-eye`), Edit (`fa-pen`), Send Email (`fa-envelope`), Pause (`fa-pause`) |
| Pending | Approve (`fa-check`, success), Reject (`fa-times`, danger), Preview (`fa-eye`) |
| Paused | View Page, Resume (`fa-play`, success) |
| Completed | View Page only |
| Team (Active) | View Page, Edit, Members (`fa-users`) |

**Slide-out Detail Panel** (clicked row): width 520px (or 100vw mobile), dark overlay; sticky header "Fundraiser Details" + close (`fa-times`).

Body sections (in order):
1. **Profile** (border-bottom): 56px gradient avatar + bold name + email (`fa-envelope`) + phone (`fa-phone`) + campaign (`fa-flag`, accent) + registered (`fa-calendar`, muted)
2. **Page URL** card (bg `#f8fafc`): `fa-link` icon + URL (accent bold) + copy button (`fa-copy`)
3. **Performance**: 3-col grid (Raised + percentage / Donors / Page Views) + 2-col grid (Goal `fa-bullseye` / Conversion Rate `fa-percent`)
4. **Shares**: flex-wrap (Facebook count / WhatsApp count / Email count / Twitter count)
5. **Recent Donors** table (Donor / Amount / Date / Message)
6. **Admin Actions** (flex column buttons):
   - Send Message (`fa-envelope`) — "Email or WhatsApp to fundraiser" → opens send-message modal
   - Edit Page (`fa-pen-to-square`) — "Override fundraiser's page content" → opens fundraiser-edit form (admin-mode)
   - Pause Page (`fa-pause-circle`) — "Temporarily disable fundraising page" → confirm + status flip
   - Feature on Campaign Page (`fa-star`) — "Pin to top of leaderboard" → toggle IsFeaturedOnCampaign
   - View Contact Profile (`fa-address-card`) — "Navigate to CRM contact record" → `crm/contact/allcontacts?id={ContactId}`

---

### 🅲 Public Parent Campaign Page (`/p2p/{campaignSlug}`)

**Page Layout** (full-width hosted; SSR; renders only when PageStatus IN (Published, Active, Closed); 404 for Draft (unless preview-token); 410 for Archived):

```
┌────────────────────────────────────────────────────────────────────┐
│ {Org Header Navbar — gradient brand bar}                            │
│ [🤲 {Org Name}]                              [About] [All Campaigns]│
├────────────────────────────────────────────────────────────────────┤
│ {Hero — gradient banner with campaign emoji + name + org}           │
│   🏃                                                                │
│   RUN FOR EDUCATION 2026                                            │
│   by Hope Foundation                                                │
├────────────────────────────────────────────────────────────────────┤
│ Campaign Body (padding 1.25rem):                                    │
│   $34,560 raised                                of $50,000 goal     │
│   ████████░░░░░░ 69.1%                                              │
│   456 donors · 89 fundraisers                                       │
│                                                                     │
│   [BECOME A FUNDRAISER]   [DONATE NOW]                              │
├────────────────────────────────────────────────────────────────────┤
│   Campaign Story (rich text)                                        │
├────────────────────────────────────────────────────────────────────┤
│   Top Fundraisers (Leaderboard)                                     │
│   🥇 Sarah Chen       $5,200 raised  (104%)                         │
│   🥈 Khalid Al-Mansouri $3,200 raised  (64%)                        │
│   🥉 Maria Lopez      $2,890 raised  (58%)                          │
│   ... see all 89 fundraisers                                        │
├────────────────────────────────────────────────────────────────────┤
│   Recent Donors (Donor Wall)                                        │
│   {avatar} John D.        — $50 · 2h ago                            │
│   {avatar} Anonymous      — $100 · 4h ago                           │
│   ...                                                               │
├────────────────────────────────────────────────────────────────────┤
│   Impact Stats (2-col)                                              │
│   🎓 690      📚 2,300                                              │
│   Children    Textbooks                                             │
│   Funded      Provided                                              │
├────────────────────────────────────────────────────────────────────┤
│ {Footer — accent bg}                                                │
│ Hope Foundation © 2026 · Powered by PeopleServe                     │
└────────────────────────────────────────────────────────────────────┘
```

**Sections** (top to bottom; some toggleable via `ShowOrganizationInfo` / `ShowImpactStats` / `ShowDonorWall` / `ShowLeaderboard`):

1. **Org Header Navbar** — accent gradient; brand mark with `fa-hand-holding-heart` + org name; right nav links "About" / "All Campaigns" (links to `(public)/p2p` — list of public campaigns)
2. **Hero** — full-width gradient banner (`linear-gradient(135deg, accent 0.9, accent-light 0.7)`); campaign emoji icon (large) + campaign name (H2 all-caps bold) + org name (small muted)
3. **Progress Section**:
   - Raised amount (accent color, bold, large) + "of {goal} goal" right-aligned
   - Progress bar (8px height, gradient fill accent → accent-light, dynamic width)
   - Sub-stats row: "{donorCount} donors · {fundraiserCount} fundraisers · {daysLeft} days left" (TIMED only)
4. **CTAs** (2-button row, gap 0.5rem; mobile-stacked):
   - Primary: `[BECOME A FUNDRAISER]` (accent fill, white text) → routes to `/p2p/{slug}/start` (only when AllowPublicRegistration=TRUE AND PageStatus IN (Published, Active))
   - Secondary: `[DONATE NOW]` (white fill, accent border + text) → opens parent-direct donate form (modal or same-page section)
5. **Campaign Story** (when not empty) — full rich-text Campaign.CampaignStory
6. **Top Fundraisers (Leaderboard)** — when ShowLeaderboard=TRUE; top-10 from cached leaderboard query; medal emoji 🥇🥈🥉 for ranks 1–3; numeric rank for 4–10; name + raised + percentage of personal goal; "see all {N} fundraisers" link
7. **Recent Donors (Donor Wall)** — when ShowDonorWall=TRUE; latest 10 donations; avatar (initials or `fa-user-secret` for anonymous) + donor name + "— ${amount} · {timeAgo}"
8. **Impact Stats** — when ShowImpactStats=TRUE; sourced from Campaign.ImpactMetrics children; emoji + number + label cells in 2-col grid
9. **Footer** — accent bg, white 80% opacity; "{OrgName} © {year} · Powered by PeopleServe" + Privacy / Terms links

**Donate Form** (parent-direct):
- Amount grid (3-col): chips from AmountChipsJson + Custom (when AllowCustomAmount)
- Frequency toggle: One-time / Monthly (when AllowRecurringDonations)
- Donor fields (always required: name + email; optional: phone / address / message based on configuration)
- Anonymous toggle (when AllowAnonymousDonations)
- "Cover processing fees" checkbox (when AllowDonorCoverFees)
- Donate Now CTA (full-width, accent bg, with `fa-heart` icon)
- Trust signals row (cards/PayPal/wallet icons + Receipt by email mention)

**SSR / SEO**:
- Pre-render `<title>`, `<meta name="description">`, OG tags from `OgTitle`/`OgDescription`/`OgImageUrl` (fall back to Campaign defaults)
- Canonical URL = `https://{tenant-domain}/p2p/{slug}`
- `revalidate: 60` for ISR

**Edge States**:
- `PageStatus = Draft` → 404 (unless `?preview={token}`)
- `PageStatus = Closed` → renders with banner "This campaign has ended" + raised/goal still shown; CTAs hidden
- `PageStatus = Archived` → 410 Gone; admin can configure redirect to org default
- `AllowPublicRegistration = FALSE` → "Become a Fundraiser" CTA hidden
- `EnabledPaymentMethodsJson = []` → "Donate Now" hidden + "Donations temporarily unavailable" message

---

### 🅳 Public Child Fundraiser Page (`/p2p/{campaignSlug}/{fundraiserSlug}`)

**Admin Controls Bar** (visible only when admin authenticated AND viewing via admin entry-point — NOT shown on actual public route):
- Left: device-switcher (Desktop/Mobile) + URL bar (with copy)
- Right: action buttons:
  - `[✓ Approve Page]` (primary, when status = Pending)
  - `[✏ Edit Content]` (outline, admin override)
  - `[⭐ Feature on Campaign]` (icon, toggles IsFeaturedOnCampaign)
  - `[🔗 Share Link]` (icon, copies to clipboard)
  - `[← Back to List]` (icon, → `?id=N&view=fundraisers`)

**Public Page Layout**:

```
┌────────────────────────────────────────────────────────────────────┐
│ {Org Header Navbar — same as parent}                                │
├────────────────────────────────────────────────────────────────────┤
│ [Cover Photo — 200px desktop / 140px mobile]                        │
├──────────────────────────────────┬─────────────────────────────────┤
│ Left Column (60%)                │ Right Column (40%)              │
│ ┌───────────────────────────┐   │ ┌─────────────────────────────┐ │
│ │ {Avatar 64px} Khalid M.   │   │ │ Progress Widget             │ │
│ │ "Running 26.2 mi for ed!" │   │ │ $3,200                      │ │
│ │ Part of: Run for Edu 2026 │   │ │ raised of $500 goal         │ │
│ │ by Hope Foundation        │   │ │ ████████ (640%)             │ │
│ └───────────────────────────┘   │ │ 34 donors · 1,234 views     │ │
│                                  │ └─────────────────────────────┘ │
│ My Story                         │                                  │
│ {rich-text personal story}       │ Donate Form                     │
│                                  │ ┌─────────────────────────────┐ │
│ Recent Donors                    │ │ [25][50][100][250][Custom]  │ │
│ {avatar} John D.  $50            │ │ One-time | Monthly          │ │
│ {avatar} Anonym.  $100           │ │ ☐ Cover fees +$2.50         │ │
│ ...                              │ │ [DONATE NOW]                │ │
│ "see all 34 donors"              │ │ Cards/PayPal/Wallet logos   │ │
│                                  │ └─────────────────────────────┘ │
│ Updates                          │                                  │
│ Apr 10 — "Hit 500%! 🎉"         │ Share                           │
│ Apr 2 — "Halfway! Thanks all"    │ [FB][Twitter][WA][LI][Copy][@] │
│                                  │                                  │
│ Team (when team-fundraising)     │ {Campaign Card — back-link}     │
│ Team Sunrise: $4,300/$5,000     │ "CAMPAIGN"                      │
│ ████████ team-bar                │ Run for Education 2026          │
│ {avatar} Khalid    $3,200        │ $34,560 / $50,000               │
│ {avatar} Sarah     $1,100        │ 89 fundraisers                  │
│                                  │ [View Campaign]                  │
└──────────────────────────────────┴─────────────────────────────────┘
{Footer — accent bg}
{Mobile sticky donate bar — visible only on mobile, position: sticky bottom: 0}
```

**Right Column Donation Form** (child-page-scoped):
- Donations get `P2PFundraiserId = {child}` AND `P2PCampaignPageId = {parent}` set on `fund.GlobalDonation`
- Amount chips from CustomAmountChipsJson (when UseDefaultDonationAmounts=FALSE) OR parent's AmountChipsJson
- Personal message field (donor-to-fundraiser optional message stored on donation row)
- Donate Now CTA → tokenize → server creates donation linked to fundraiser

**Mobile Sticky Donate Bar** (`mobile-donate-bar`, `display: none` desktop):
- Position sticky bottom 0; bg white; border-top + box-shadow
- Left: raised amount (bold accent)
- Right: `[DONATE NOW]` button (accent bg, white text)
- Tapping scrolls to/opens the Donate Form section

**SSR / SEO**:
- Pre-render OG tags using fundraiser's PageTitle, PersonalStory excerpt, CoverImageUrl (fall back to parent's)
- Canonical = `https://{tenant-domain}/p2p/{parentSlug}/{childSlug}`

**Edge States**:
- `FundraiserStatus IN (Draft, Pending, Rejected)` → 404 (Pending shows "page is under review" via login link)
- `FundraiserStatus = Paused` → renders with "Page paused" banner; donate disabled
- `FundraiserStatus = Completed` (parent closed) → renders read-only with "Campaign closed — final $X raised" banner
- Parent `Archived` → 410 Gone for both child and parent

---

### 🅴 Public Start-Fundraiser Wizard (`/p2p/{campaignSlug}/start`)

**Layout** (CSR; renders only when parent PageStatus IN (Published, Active) AND AllowPublicRegistration=TRUE; otherwise 404):

```
┌────────────────────────────────────────────────────────────────────┐
│ {Breadcrumb: P2P Campaigns › {Campaign Name} › Register Fundraiser} │
├────────────────────────────────────────────────────────────────────┤
│ [👤 Register Fundraiser]                                            │
│ Set up a fundraising page for a supporter                           │
├────────────────────────────────────────────────────────────────────┤
│ ●─────●─────●─────○                                                 │
│ Campaign  Page  Donation Review                                     │
│ & Identity Setup Settings & Activate                                │
├────────────────────────────────────────────────────────────────────┤
│ {Active step content}                                               │
├────────────────────────────────────────────────────────────────────┤
│ [← Back]                            [Save as Draft] [Next →]        │
└────────────────────────────────────────────────────────────────────┘
```

**Stepper Bar**: 4 steps with circle indicators connected by 2px-tall lines. Active step purple `#7c3aed`; completed step green with `fa-check`; future step white outline. On mobile only numbered circles + connectors visible.

**STEP 1 — Campaign & Identity**:

- **Card "Select Campaign"** (`fa-bullhorn`): single select pre-filled with current campaign (locked when arriving via `/p2p/{slug}/start`)
- **Campaign Info Bar** (purple-tinted): Goal | Active fundraisers count | Ends date (icons)
- **Card "Link to Contact"** (`fa-address-book`): search-existing-contacts text input (`fa-search`); shows result card (avatar + name + contact ID + lifetime amount + tier badge + view-contact link); `[+ New Contact]` button revealing fundraiser-details fields
- **Card "Fundraiser Details"** (`fa-id-card`):
  - First Name (text, REQUIRED)
  - Last Name (text, REQUIRED)
  - Email (email, REQUIRED — backend dedupes against Contact)
  - Phone (tel, OPTIONAL)
  - Profile Photo (upload-area or upload-preview; pre-filled from contact)
- **Card "Fundraiser Type"** (`fa-users-cog`): 2 radio-cards
  - Individual (`fa-user`, default)
  - Team (`fa-people-group`)
- **Team sub-fields** (purple-tinted, conditional on Team selected):
  - Team Name (text, REQUIRED)
  - Team Size (number, OPTIONAL, min 2)
  - Team Captain (text, disabled, auto-filled with current fundraiser name)

Step footer: `[Next →]` only.

**STEP 2 — Page Setup**:

- **Card "Page Title & Goal"** (`fa-heading`):
  - Page Title (text, REQUIRED, placeholder)
  - Personal Goal (currency input-group with currency select inline; help "Campaign minimum: ${min} | suggested: ${suggested}")
  - Currency (select inline, max-w 90px) — Options: USD/AED/GBP/EUR (filtered by tenant)
  - Make goal visible on page (checkbox, default checked)
- **Card "Custom URL Slug"** (`fa-link`):
  - URL slug (inline-editable within composite display showing base `{tenant}/p2p/{parentSlug}/`)
  - Real-time availability indicator: green `fa-check-circle` "Available" or red unavailable
- **Card "Personal Story"** (`fa-pen-fancy`): rich-text editor (Bold/Italic/Underline / list-ul/ol / link); min-h 140px; word count "200-500 words recommended" + actual count
- **Card "Cover Photo / Video"** (`fa-image`):
  - Upload Cover Image (upload-preview, recommended 1200x630)
  - OR Video URL (url input, YouTube/Vimeo)
- **Card "Milestones"** (`fa-trophy`, sub-label "optional — gamification"):
  - Use campaign default milestones (checkbox, default unchecked unless parent FundraiserPageOptionsJson.milestones=FALSE)
  - Milestone table (when not using default): editable rows of (Amount input 100px / Message text input / Remove `fa-trash-alt`); `[+ Add Milestone]` button
  - Default milestone seed: $500 "First milestone! 10% of my goal!", $2,500 "Halfway there!", $5,000 "Goal reached!"

Step footer: `[← Back]` + `[Next →]`.

**STEP 3 — Donation Settings**:

- **Card "Suggested Donation Amounts"** (`fa-hand-holding-usd`):
  - Use campaign defaults (radio, default — shows read-only chip display from parent)
  - Custom amounts (radio — shows editable chips, max 8)
  - Allow custom/other amount (checkbox, default checked)
- **Card "Matching"** (`fa-handshake`):
  - Employer matching enabled (toggle, default OFF — gates next 2 fields)
  - Company Name (text, conditional)
  - Match Ratio (select 1:1 / 2:1 / 3:1, conditional)
- **Card "Offline Donations"** (`fa-money-bill-wave`):
  - Allow offline/cash donations toggle (default ON when parent allows)
- **Card "Thank You Message"** (`fa-heart`):
  - Use campaign default thank-you message (checkbox, default unchecked)
  - Custom Message (textarea, conditional)
- **Card "Social Sharing"** (`fa-share-alt`): 3 textareas
  - Facebook / LinkedIn (long message with URL)
  - Twitter / X (short tweet with hashtag)
  - WhatsApp / SMS (conversational message with URL)
  - All textareas full-width, min-h 60px, resizable

Step footer: `[← Back]` + `[Next →]`.

**STEP 4 — Review & Activate**:

- **Card "Summary"** (`fa-clipboard-check`): summary table with 9 rows (Campaign / Fundraiser / Type / Goal / Page URL / Story status / Cover Photo status / Milestones count / Thank-you mode)
- **Card "Page Preview"** (`fa-eye`): mini-preview card (max-w 440px) — gradient cover + title + "by {fundraiser name}" + progress bar (24% sample) + Donate Now button (non-interactive) + story excerpt + "Recent Donors will appear here after launch"
- **Card "Activation Options"** (`fa-rocket`):
  - Status (select): Activate Now (default) / Save as Draft / Schedule Activation
  - Go Live Date (date input, conditional on Schedule Activation)
- **Sub-section Notifications** (`fa-bell`): 3 checkboxes:
  - Send welcome email to fundraiser with page link and tips (default checked)
  - Send fundraiser toolkit (images, sample messages, social graphics) (default checked)
  - Notify campaign manager (default unchecked)

Step footer: `[← Back]` + `[Save as Draft]` + `[🚀 Activate Fundraiser Page]` (primary).

**Success Screen** (post-submit, replaces wizard):
- Center card (max-w 560px); 72px green circle with `fa-check`
- H2: "Fundraiser Page Created!"
- Subtitle: "{Name}'s {Page Title} is now live!" (or "...is under review" when ApprovalMode=MANUAL)
- URL box: inline-flex, page URL in purple + copy button
- Primary actions: `[Open Page]` (`fa-external-link-alt`) + `[Copy Link]` (`fa-link`)
- Share row: Facebook, Twitter, WhatsApp, Email
- Secondary actions (below border): `[View in Fundraiser List]` (admin only) + `[Register Another Fundraiser]`

---

### Shared blocks

#### Page Header & Breadcrumbs (admin setup)

| Element | Content |
|---------|---------|
| Breadcrumb (admin only) | Settings › Public Pages › P2P Campaign Pages › {Campaign Name OR "Create P2P Campaign"} |
| Page title | "Create P2P Campaign" / "Edit: {Campaign Name}" |
| Subtitle | "Set up a new peer-to-peer fundraising campaign" |
| Status badge | Draft / Published / Active / Closed / Archived (color-coded per §G.1) — only when editing existing |
| Right actions | [Cancel] [Save Draft] [🚀 Publish] |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading (admin list) | Initial fetch | Skeleton: 4 KPI card placeholders + table skeleton (5 rows) |
| Loading (admin editor) | Initial fetch | Skeleton matching 5-tab layout |
| Loading (public parent) | Initial SSR pending | Skeleton: hero + progress + CTAs |
| Loading (public child) | Initial SSR pending | Skeleton: cover + 2-col layout |
| Loading (wizard) | Initial render | Spinner with "Loading campaign details..." |
| Empty (admin list) | No campaigns yet | "No P2P campaigns yet. Create your first one." + primary CTA |
| Empty (active fundraisers grid) | No fundraisers yet | "No fundraisers have signed up yet. Share your campaign link to recruit supporters." + share-link copy button |
| Empty (approval queue) | No pending | "All caught up! No fundraisers awaiting approval." with green checkmark |
| Empty (leaderboard) | No completed donations | "Be the first to donate!" + donate CTA |
| Empty (recent donors) | No donations | "No donations yet. Donate first to start the wall!" |
| Error (admin GET) | API failure | Error card with retry + error code |
| Error (public slug not found) | Slug doesn't exist | 404 page with org-default redirect |
| Error (closed banner) | PageStatus = Closed | Banner "This campaign has ended on {date} — final raised ${total}" |
| Error (paused banner) | FundraiserStatus = Paused | Banner "This page is paused. Donations temporarily unavailable." |

---

## ⑦ Substitution Guide

> **First P2P_FUNDRAISER screen — sets the canonical convention.**
> When this screen is COMPLETED, replace the §⑦ TBD block in `_EXTERNAL_PAGE.md` with this entity as the canonical reference for future P2P_FUNDRAISER screens.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| OnlineDonationPage | P2PCampaignPage | Sibling EXTERNAL_PAGE entity (different sub-type) — copy infrastructure (slug validator, tenant scope, public-route registration, anti-fraud middleware, OG meta SSR) |
| onlineDonationPage | p2pCampaignPage | camelCase variable / field names |
| online-donation-page | p2p-campaign-page | kebab-case for FE folder |
| ONLINEDONATIONPAGE | P2PCAMPAIGNPAGE | UPPER for menu code / GridCode |
| fund (schema) | fund | Same schema — DonationModels group |
| DonationModels (group) | DonationModels | Same group |
| onlinedonationpage (FE folder) | p2pcampaignpage | FE folder under `setting/publicpages/` |
| OnlineDonationPagePurposes (junction) | P2PFundraisers (child) + P2PFundraiserTeams (child) + P2PFundraiserMilestones (grandchild) + P2PFundraiserUpdates (grandchild) | Different children pattern: parent-with-children (multi-level) vs single-page-record + junction |
| GlobalDonations.OnlineDonationPageId (FK) | GlobalDonations.P2PCampaignPageId + GlobalDonations.P2PFundraiserId (2 FKs) | Linkage from existing donation pipeline |

Field-level mapping (admin setup):

| OnlineDonationPage field | P2PCampaignPage field | Notes |
|-------------------------|------------------------|-------|
| PageTitle | Campaign.CampaignName (FK-linked) | Fields write through to Campaign |
| Slug | Slug | Same |
| Status | PageStatus | Renamed for parent-level disambiguation from FundraiserStatus |
| ImplementationType | (no direct equivalent — single render mode) | — |
| AvailableFrequenciesJson | Campaign.RecurringFrequencies (FK-linked) | Inherited |
| EnabledPaymentMethodsJson | EnabledPaymentMethodsJson | Same |
| DonorFieldsJson | (no direct equivalent — handled via wizard) | — |

---

## ⑧ File Manifest

### Backend Files — P2P_FUNDRAISER (parent-with-children)

| # | File | Path |
|---|------|------|
| 1 | Parent Entity | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/P2PCampaignPage.cs` |
| 2 | Parent EF Config | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/DonationConfigurations/P2PCampaignPageConfiguration.cs` |
| 3 | Parent Schemas (DTOs: Request / Response / Public / Stats) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/DonationSchemas/P2PCampaignPageSchemas.cs` |
| 4 | Child Entity — P2PFundraiser | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/P2PFundraiser.cs` |
| 5 | Child EF Config — P2PFundraiser | `…/Configurations/DonationConfigurations/P2PFundraiserConfiguration.cs` |
| 6 | Child Schemas — P2PFundraiser | `…/Schemas/DonationSchemas/P2PFundraiserSchemas.cs` |
| 7 | Child Entity — P2PFundraiserTeam | `…/Models/DonationModels/P2PFundraiserTeam.cs` |
| 8 | Child EF Config — P2PFundraiserTeam | `…/Configurations/DonationConfigurations/P2PFundraiserTeamConfiguration.cs` |
| 9 | Child Schemas — P2PFundraiserTeam | `…/Schemas/DonationSchemas/P2PFundraiserTeamSchemas.cs` |
| 10 | Grandchild Entity — P2PFundraiserMilestone | `…/Models/DonationModels/P2PFundraiserMilestone.cs` |
| 11 | Grandchild EF Config — P2PFundraiserMilestone | `…/Configurations/DonationConfigurations/P2PFundraiserMilestoneConfiguration.cs` |
| 12 | Grandchild Schemas — P2PFundraiserMilestone | `…/Schemas/DonationSchemas/P2PFundraiserMilestoneSchemas.cs` |
| 13 | Grandchild Entity — P2PFundraiserUpdate | `…/Models/DonationModels/P2PFundraiserUpdate.cs` |
| 14 | Grandchild EF Config / Schemas | (paired files) |
| 15 | Modify GlobalDonation entity (add P2PCampaignPageId, P2PFundraiserId) | `…/Models/DonationModels/GlobalDonation.cs` (existing — modify) |
| 16 | Modify GlobalDonation EF Config (add FKs + CHECK constraint) | `…/DonationConfigurations/GlobalDonationConfiguration.cs` (existing — modify) |
| 17 | GetById query — Parent | `…/Application/Donations/P2PCampaignPages/GetByIdQuery/GetP2PCampaignPageById.cs` |
| 18 | GetAll query — Parent | `…/P2PCampaignPages/GetAllQuery/GetAllP2PCampaignPageList.cs` |
| 19 | GetBySlug query — Parent (public, anonymous) | `…/P2PCampaignPages/GetBySlugQuery/GetP2PCampaignPageBySlug.cs` |
| 20 | GetStats query — Parent | `…/P2PCampaignPages/GetStatsQuery/GetP2PCampaignPageStats.cs` |
| 21 | GetPublishValidation query | `…/P2PCampaignPages/GetPublishValidationQuery/GetP2PCampaignPagePublishValidation.cs` |
| 22 | GetLeaderboard query | `…/P2PCampaignPages/GetLeaderboardQuery/GetP2PCampaignPageLeaderboard.cs` |
| 23 | GetPendingFundraisers query | `…/P2PCampaignPages/GetPendingFundraisersQuery/GetP2PCampaignPagePendingFundraisers.cs` |
| 24 | GetAllFundraisersByCampaign query | `…/P2PFundraisers/GetAllByCampaignQuery/GetAllFundraisersByP2PCampaignPage.cs` |
| 25 | GetById query — Fundraiser | `…/P2PFundraisers/GetByIdQuery/GetP2PFundraiserById.cs` |
| 26 | GetBySlug query — Fundraiser (public, anonymous) | `…/P2PFundraisers/GetBySlugQuery/GetP2PFundraiserBySlug.cs` |
| 27 | GetStats query — Fundraiser | `…/P2PFundraisers/GetStatsQuery/GetP2PFundraiserStats.cs` |
| 28 | Create command — Parent | `…/P2PCampaignPages/CreateCommand/CreateP2PCampaignPage.cs` |
| 29 | Update command — Parent | `…/P2PCampaignPages/UpdateCommand/UpdateP2PCampaignPage.cs` |
| 30 | Lifecycle commands — Parent | `…/P2PCampaignPages/LifecycleCommands/{Publish,Unpublish,Close,Archive}P2PCampaignPage.cs` (4 files) |
| 31 | Create command — Fundraiser (admin) | `…/P2PFundraisers/CreateCommand/CreateP2PFundraiser.cs` |
| 32 | Update command — Fundraiser | `…/P2PFundraisers/UpdateCommand/UpdateP2PFundraiser.cs` |
| 33 | Approve / Reject / Pause / Resume / FeatureToggle commands | `…/P2PFundraisers/ApprovalCommands/{Approve,Reject,Pause,Resume,Feature}P2PFundraiser.cs` (5 files) |
| 34 | Create / Update / Delete commands — Team | `…/P2PFundraiserTeams/CrudCommands/...` (3 files) |
| 35 | Milestone CRUD commands | `…/P2PFundraiserMilestones/CrudCommands/...` (4 files: Create/Update/Delete/Reorder) |
| 36 | Update CRUD commands | `…/P2PFundraiserUpdates/CrudCommands/...` (3 files: Create/Update/Delete) |
| 37 | Public commands — StartP2PFundraiser (anonymous, rate-limited, csrf) | `…/Public/StartFundraiserCommand/StartP2PFundraiser.cs` |
| 38 | Public commands — InitiateP2PDonation (anonymous) | `…/Public/InitiateDonationCommand/InitiateP2PDonation.cs` |
| 39 | Public commands — ConfirmP2PDonation (gateway-callback, anonymous) | `…/Public/ConfirmDonationCommand/ConfirmP2PDonation.cs` |
| 40 | Communication-template send handlers | `…/P2PCampaignPages/CommunicationHandlers/Send{Welcome,Approved,Rejected,DonationToFundraiser,DonationToDonor,GoalReached,Weekly,EndSummary}.cs` (8 handlers; SERVICE_PLACEHOLDER for actual SMTP) |
| 41 | Slug validator | `…/Application/Validators/P2PCampaignPageSlugValidator.cs` |
| 42 | Mutations endpoint (admin) | `Pss2.0_Backend/.../EndPoints/Donation/Mutations/P2PCampaignPageMutations.cs` (parent + fundraiser + team + milestone + update mutations grouped) |
| 43 | Queries endpoint (admin) | `Pss2.0_Backend/.../EndPoints/Donation/Queries/P2PCampaignPageQueries.cs` |
| 44 | Public Queries endpoint | `Pss2.0_Backend/.../EndPoints/Donation/Public/P2PCampaignPagePublicQueries.cs` (anonymous-allowed, rate-limited) |
| 45 | Public Mutations endpoint | `Pss2.0_Backend/.../EndPoints/Donation/Public/P2PCampaignPagePublicMutations.cs` (anonymous-allowed, rate-limited, csrf-protected) |

**Backend Wiring Updates**:

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | DbSet<P2PCampaignPage> + DbSet<P2PFundraiser> + DbSet<P2PFundraiserTeam> + DbSet<P2PFundraiserMilestone> + DbSet<P2PFundraiserUpdate> |
| 2 | DonationDbContext.cs | DbSet entries |
| 3 | DecoratorProperties.cs | DecoratorDonationModules entry for all 5 entities |
| 4 | DonationMappings.cs | Mapster mapping config (parent + 4 children + GlobalDonation extension) |
| 5 | Public route registration in Program.cs / endpoint config | Register `/p2p/{slug}`, `/p2p/{slug}/{fundraiserSlug}`, `/p2p/{slug}/start` GETs + POSTs |
| 6 | Anti-fraud middleware config | Register rate-limit policies "P2PDonationSubmit", "P2PStartFundraiser" |
| 7 | OG meta-tag handler | Pre-render OG tags for `/p2p/{slug}` and `/p2p/{slug}/{fundraiserSlug}` SSR responses |
| 8 | DB migration | New tables P2PCampaignPages, P2PFundraisers, P2PFundraiserTeams, P2PFundraiserMilestones, P2PFundraiserUpdates + ALTER GlobalDonations ADD COLUMN P2PCampaignPageId, P2PFundraiserId + CHECK constraint |
| 9 | DB seed for module-menu | Insert/upsert MenuList row for `P2PCAMPAIGNPAGE` under `SET_PUBLICPAGES` parent + RoleMenuMapping for BUSINESSADMIN |
| 10 | DB seed for GridType registration | Confirm `EXTERNAL_PAGE` GridType exists (created by OnlineDonationPage prerequisite) — if not, insert |
| 11 | DB seed for new MasterData | `P2PCAMPAIGNTYPE` MasterDataType + 3 rows (TIMED/OCCASION/ALWAYS_ACTIVE); confirm `PAYMENTMETHOD` rows exist |

### Frontend Files — P2P_FUNDRAISER

| # | File | Path |
|---|------|------|
| 1 | DTO Types (parent + children + public + stats) | `PSS_2.0_Frontend/src/domain/entities/donation-service/P2PCampaignPageDto.ts` (consolidated; ~600 LOC) |
| 2 | GQL Query (admin) | `PSS_2.0_Frontend/src/domain/gql-queries/donation-queries/P2PCampaignPageQuery.ts` |
| 3 | GQL Query (public) | `PSS_2.0_Frontend/src/domain/gql-queries/public/P2PCampaignPagePublicQuery.ts` |
| 4 | GQL Mutation (admin) | `PSS_2.0_Frontend/src/domain/gql-mutations/donation-mutations/P2PCampaignPageMutation.ts` |
| 5 | GQL Mutation (public) | `PSS_2.0_Frontend/src/domain/gql-mutations/public/P2PCampaignPagePublicMutation.ts` |
| 6 | Setup List Page | `PSS_2.0_Frontend/src/page-components/setting/publicpages/p2pcampaignpage/list-page.tsx` |
| 7 | Setup Editor Page (5-tab layout) | `…/p2pcampaignpage/setup-page.tsx` |
| 8 | Tab Component — Basic Info | `…/p2pcampaignpage/tabs/basic-info-tab.tsx` |
| 9 | Tab Component — Fundraiser Settings | `…/p2pcampaignpage/tabs/fundraiser-settings-tab.tsx` |
| 10 | Tab Component — Donation Settings | `…/p2pcampaignpage/tabs/donation-settings-tab.tsx` |
| 11 | Tab Component — Branding & Page (split-pane) | `…/p2pcampaignpage/tabs/branding-page-tab.tsx` |
| 12 | Tab Component — Communication | `…/p2pcampaignpage/tabs/communication-tab.tsx` |
| 13 | Live Preview Component | `…/p2pcampaignpage/components/live-preview.tsx` (mobile/desktop toggle) |
| 14 | Active Fundraisers Grid (embedded) | `…/p2pcampaignpage/components/fundraiser-grid.tsx` |
| 15 | Approval Queue subview | `…/p2pcampaignpage/components/approval-queue.tsx` |
| 16 | Slide-out Detail Panel | `…/p2pcampaignpage/components/fundraiser-detail-panel.tsx` |
| 17 | Reject Reason Modal | `…/p2pcampaignpage/components/reject-reason-modal.tsx` |
| 18 | Send Message Modal | `…/p2pcampaignpage/components/send-message-modal.tsx` |
| 19 | Page Config (admin) | `…/pages/setting/publicpages/p2pcampaignpage.tsx` |
| 20 | Route Page (admin) | `PSS_2.0_Frontend/src/app/[lang]/setting/publicpages/p2pcampaignpage/page.tsx` (REPLACES existing UnderConstruction stub) |
| 21 | Public Layout (route group) | `PSS_2.0_Frontend/src/app/[lang]/(public)/layout.tsx` (NEW route group — bare layout, no admin chrome) |
| 22 | Public Parent Page | `PSS_2.0_Frontend/src/app/[lang]/(public)/p2p/[campaignSlug]/page.tsx` (SSR, generateMetadata) |
| 23 | Public Child Fundraiser Page | `…/(public)/p2p/[campaignSlug]/[fundraiserSlug]/page.tsx` (SSR, generateMetadata) |
| 24 | Public Start-Fundraiser Wizard | `…/(public)/p2p/[campaignSlug]/start/page.tsx` (CSR) |
| 25 | Wizard Step 1 — Campaign & Identity | `…/p2p/[campaignSlug]/start/components/step-1-identity.tsx` |
| 26 | Wizard Step 2 — Page Setup | `…/start/components/step-2-page-setup.tsx` |
| 27 | Wizard Step 3 — Donation Settings | `…/start/components/step-3-donation-settings.tsx` |
| 28 | Wizard Step 4 — Review & Activate | `…/start/components/step-4-review.tsx` |
| 29 | Wizard Success Screen | `…/start/components/success-screen.tsx` |
| 30 | Public Donate Form (parent + child variants) | `PSS_2.0_Frontend/src/page-components/public/p2pcampaignpage/components/donate-form.tsx` (shared) |
| 31 | Public Hero (parent) | `…/public/p2pcampaignpage/components/parent-hero.tsx` |
| 32 | Public Progress Section | `…/public/p2pcampaignpage/components/progress-section.tsx` |
| 33 | Public Leaderboard | `…/public/p2pcampaignpage/components/leaderboard.tsx` |
| 34 | Public Donor Wall | `…/public/p2pcampaignpage/components/donor-wall.tsx` |
| 35 | Public Impact Stats | `…/public/p2pcampaignpage/components/impact-stats.tsx` |
| 36 | Public Child Cover Photo + Profile | `…/public/p2pcampaignpage/components/child-cover-profile.tsx` |
| 37 | Public Child Story | `…/public/p2pcampaignpage/components/child-story.tsx` |
| 38 | Public Child Updates Feed | `…/public/p2pcampaignpage/components/child-updates.tsx` |
| 39 | Public Child Team Section | `…/public/p2pcampaignpage/components/child-team-section.tsx` |
| 40 | Public Child Progress Widget | `…/public/p2pcampaignpage/components/child-progress-widget.tsx` |
| 41 | Public Share Buttons | `…/public/p2pcampaignpage/components/share-buttons.tsx` |
| 42 | Public Mobile Donate Bar | `…/public/p2pcampaignpage/components/mobile-donate-bar.tsx` |
| 43 | Public Org Header Navbar | `…/public/p2pcampaignpage/components/org-header.tsx` |
| 44 | Public Footer | `…/public/p2pcampaignpage/components/public-footer.tsx` |
| 45 | Login-link manage page | `…/(public)/p2p/[campaignSlug]/[fundraiserSlug]/manage/page.tsx` (token-auth) |

**Frontend Wiring Updates**:

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | `P2PCAMPAIGNPAGE` operations config + `P2PFUNDRAISER` sub-operations |
| 2 | operations-config.ts | Import + register operations |
| 3 | sidebar menu config (`module-menu-config.ts`) | Menu entry under SET_PUBLICPAGES (already exists at line 265 of MODULE_MENU_REFERENCE.md — confirm route + icon) |
| 4 | Apollo client public-route config | Public GraphQL endpoint for anonymous queries (omits Authorization header) |
| 5 | OG meta-tag generators | `generateMetadata` exports per `(public)/p2p/...` route |
| 6 | Sentry / error reporting | Tag public-route errors with anonymous-context flag |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by `/plan-screens`.

```
---CONFIG-START---
Scope: FULL

MenuName: P2P Campaign Pages
MenuCode: P2PCAMPAIGNPAGE
ParentMenu: SET_PUBLICPAGES
Module: SETTING
MenuUrl: setting/publicpages/p2pcampaignpage
GridType: EXTERNAL_PAGE

MenuCapabilities: READ, CREATE, MODIFY, DELETE, PUBLISH, ARCHIVE, APPROVE_FUNDRAISER, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, PUBLISH, ARCHIVE, APPROVE_FUNDRAISER

GridFormSchema: SKIP
GridCode: P2PCAMPAIGNPAGE
---CONFIG-END---
```

> Notes:
> - `GridType: EXTERNAL_PAGE` — already registered by OnlineDonationPage build prerequisite. If not yet seeded, register it here.
> - `GridFormSchema: SKIP` — custom UI, not RJSF modal form.
> - `APPROVE_FUNDRAISER` is a P2P_FUNDRAISER-specific capability that gates the Approval Queue bulk-approve / reject / approve / reject actions on individual fundraiser rows. Reuse the same capability code for Reject/Pause/Resume (these are admin moderation actions; treating as one capability is the simplest gate).
> - The MenuList entry already exists in MODULE_MENU_REFERENCE.md (line 265) — no NEW menu seed needed; only confirm RoleMenuMapping for BUSINESSADMIN with the capabilities above.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types**:
- Query type (admin): `P2PCampaignPageQueries`
- Mutation type (admin): `P2PCampaignPageMutations`
- Public Query type (anonymous): `P2PCampaignPagePublicQueries`
- Public Mutation type (anonymous): `P2PCampaignPagePublicMutations`

### Admin Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAllP2PCampaignPageList` | [P2PCampaignPageResponseDto] | pageNo, pageSize, statusFilter, searchTerm |
| `getP2PCampaignPageById` | P2PCampaignPageResponseDto | id |
| `getP2PCampaignPageStats` | P2PCampaignPageStatsDto | id |
| `getP2PCampaignPagePublishValidation` | ValidationResultDto | id |
| `getP2PCampaignPageLeaderboard` | [LeaderboardEntryDto] | id, topN |
| `getP2PCampaignPagePendingFundraisers` | [P2PFundraiserResponseDto] | id |
| `getAllFundraisersByP2PCampaignPage` | [P2PFundraiserResponseDto] | campaignPageId, statusFilter, searchTerm, sortBy, pageNo, pageSize |
| `getP2PFundraiserById` | P2PFundraiserResponseDto | id |
| `getP2PFundraiserStats` | P2PFundraiserStatsDto | id |

### Admin Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createP2PCampaignPage` | P2PCampaignPageRequestDto | int |
| `updateP2PCampaignPage` | P2PCampaignPageRequestDto | int |
| `publishP2PCampaignPage` | id | P2PCampaignPageResponseDto |
| `unpublishP2PCampaignPage` | id | P2PCampaignPageResponseDto |
| `closeP2PCampaignPage` | id | P2PCampaignPageResponseDto |
| `archiveP2PCampaignPage` | id | int |
| `createP2PFundraiser` | P2PFundraiserRequestDto | int |
| `updateP2PFundraiser` | P2PFundraiserRequestDto | int |
| `approveP2PFundraiser` | id | int |
| `rejectP2PFundraiser` | id, reason | int |
| `pauseP2PFundraiser` | id | int |
| `resumeP2PFundraiser` | id | int |
| `featureP2PFundraiserToggle` | id, isFeatured | int |
| `createP2PFundraiserTeam` | P2PFundraiserTeamRequestDto | int |
| `updateP2PFundraiserTeam` | P2PFundraiserTeamRequestDto | int |
| `deleteP2PFundraiserTeam` | id | int |
| `createP2PFundraiserMilestone` / `updateP2PFundraiserMilestone` / `deleteP2PFundraiserMilestone` / `reorderP2PFundraiserMilestones` | DTOs / id / id / [{id, orderBy}] | int |
| `createP2PFundraiserUpdate` / `updateP2PFundraiserUpdate` / `deleteP2PFundraiserUpdate` | DTOs / id | int |

### Public Queries (anonymous)

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getP2PCampaignPageBySlug` | P2PCampaignPagePublicDto (only public-safe fields) | slug, tenantSlug? |
| `getP2PCampaignPagePublicStats` | P2PCampaignPagePublicStatsDto | slug |
| `getP2PCampaignPagePublicLeaderboard` | [LeaderboardEntryPublicDto] | slug, topN |
| `getP2PCampaignPageRecentDonors` | [PublicDonorEntryDto] | slug, limit (anonymous donors hidden) |
| `getP2PFundraiserBySlug` | P2PFundraiserPublicDto | campaignSlug, fundraiserSlug |
| `getP2PFundraiserPublicStats` | P2PFundraiserPublicStatsDto | campaignSlug, fundraiserSlug |
| `getP2PFundraiserRecentDonors` | [PublicDonorEntryDto] | campaignSlug, fundraiserSlug, limit |

### Public Mutations (anonymous, rate-limited, csrf-protected)

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `startP2PFundraiser` | StartP2PFundraiserDto (campaignSlug, email, firstName, lastName, phone?, fundraiserType, teamInfo?, pageTitle, slug, personalGoal, story, coverImageUrl?, milestones[], donationOverrides?, employerMatching?, customThankYouMessage?, socialShareMessages?, activationStatus, csrfToken, honeypot, idempotencyKey) | StartP2PFundraiserResultDto (fundraiserSlug, status, loginLink) |
| `initiateP2PDonation` | InitiateP2PDonationDto (campaignSlug, fundraiserSlug?, amount, currencyCode, frequency, donorFields, paymentMethodCode, csrfToken, honeypot, idempotencyKey) | DonationInitDto (paymentSessionId or redirectUrl) |
| `confirmP2PDonation` | gatewayCallbackPayload | DonationConfirmedDto (receiptUrl, thankYouState) |
| `incrementP2PFundraiserViewCount` | campaignSlug, fundraiserSlug | int (anti-bot throttled; debounced server-side) |

**DTO Field Lists** (key fields — full lists in BA-Solution Resolver phase):

`P2PCampaignPageRequestDto`: campaignName, slug, campaignTypeKind, startDate?, endDate?, goalAmount, linkedDonationPurposeId?, description, story?, heroImageUrl?, videoUrl?, organizationalUnitId?, allowPublicRegistration, fundraiserApprovalMode, defaultIndividualGoal, minIndividualGoal, maxIndividualGoal, allowTeamFundraising, defaultTeamGoal?, maxTeamSize?, fundraiserPageOptionsJson, showLeaderboard, showFundraiserCount, achievementBadgesEnabled, overrideDonationSettings, amountChipsJson?, allowCustomAmount, minimumDonationAmount, allowRecurringDonations, allowAnonymousDonations, enabledPaymentMethodsJson, companyPaymentGatewayId?, allowDonorCoverFees, matchingGiftIntegrationEnabled, pageTheme, primaryColorHex, secondaryColorHex, logoUrl?, headerStyle, showOrganizationInfo, showImpactStats, showDonorWall, customCssOverride?, registrationConfirmationEmailTemplateId?, donationToFundraiserEmailTemplateId?, donationToDonorEmailTemplateId?, goalReachedEmailTemplateId?, weeklyProgressEmailTemplateId?, campaignEndSummaryEmailTemplateId?, whatsAppDonationAlertEnabled, whatsAppDonationAlertTemplateId?, whatsAppGoalMilestoneAlertsEnabled, defaultShareMessage?, ogImageUrl?, ogTitle?, ogDescription?, robotsIndexable, isActive

`P2PCampaignPageResponseDto`: all of the above + p2PCampaignPageId, campaignId, pageStatus, publishedAt, archivedAt, campaign (nested CampaignResponseDto), createdBy, createdDate, modifiedBy, modifiedDate

`P2PCampaignPagePublicDto` (anonymous-safe — strict allowlist): pageTitle (= campaign.campaignName), slug, story, heroImageUrl, videoUrl, goalAmount, currencyCode, startDate, endDate, status, allowPublicRegistration, primaryColorHex, secondaryColorHex, logoUrl, headerStyle, showOrganizationInfo, showImpactStats, showDonorWall, showLeaderboard, defaultShareMessage, ogTitle, ogDescription, ogImageUrl, organizationalUnit (name only), donationPurpose (name only), suggestedAmounts (chip values only), recurringFrequencies (codes only), donorFieldsConfig (visible/required toggles only — no internal logic), enabledPaymentMethodsCodes (codes only — no gateway IDs), paymentMethodLogos (CDN URLs only), achievementBadges (display refs only)

`P2PFundraiserPublicDto`: pageTitle, slug, fundraiserType, personalStory, coverImageUrl, coverVideoUrl, profilePhotoUrl, personalGoal, isGoalVisible, goalCurrencyCode, status, fundraiserName (= concat of contact firstName+lastName ONLY when not anonymous), tagline, teamId?, teamName?, teamSize?, sharedTeamGoal?, suggestedAmounts, allowCustomAmount, customThankYouMessage, socialShareMessages

`P2PCampaignPageStatsDto` (admin only): totalRaised, totalDonors, totalFundraisers, activeFundraisers, pendingApprovals, lastDonationAt, conversionRate (PLACEHOLDER), avgPerFundraiser, topFundraiserAmount

**Public DTO Privacy Discipline**:

| Field | Public DTO | Reason |
|-------|------------|--------|
| Internal IDs (P2PCampaignPageId, P2PFundraiserId, ContactId) | omitted | not relevant to anonymous |
| Donor email / phone | omitted | PII never on public stats |
| Donor name on donor wall | shown ONLY when donation.IsAnonymous = FALSE | privacy |
| Fundraiser email / phone | omitted | only fundraiser name + tagline shown publicly |
| Admin notes / approval reasons (RejectionReason, AdminFeaturedOnCampaign) | omitted | internal-only (RejectionReason shown to fundraiser owner via login-link only) |
| RaisedAmount, DonorCount, FundraiserCount, leaderboard | included | public-safe |
| Pending fundraiser pages | omitted from public listing | only Active visible publicly |
| OG meta fields | included | needed for share previews |
| Internal CRM tier badges | omitted from public; included in admin slide-out | internal-only |
| EmployerCompanyName | optional public toggle (admin can hide); omitted by default | privacy |

---

## ⑪ Acceptance Criteria

**Build Verification**:

- [ ] `dotnet build` — no errors; all 5 entities + 4 EF configs + 4 schemas + 24+ commands/queries compile
- [ ] EF migration generated successfully; tables P2PCampaignPages / P2PFundraisers / P2PFundraiserTeams / P2PFundraiserMilestones / P2PFundraiserUpdates created; GlobalDonations ALTERed
- [ ] `pnpm dev` — admin loads at `/{lang}/setting/publicpages/p2pcampaignpage` (replaces UnderConstruction stub)
- [ ] `pnpm dev` — public parent loads at `/{lang}/p2p/{campaignSlug}` (404 for non-existent slug; 410 for archived)
- [ ] `pnpm dev` — public child loads at `/{lang}/p2p/{campaignSlug}/{fundraiserSlug}` (404 for non-Active states unless preview-token / login-link)
- [ ] `pnpm dev` — public Start-Fundraiser wizard loads at `/{lang}/p2p/{campaignSlug}/start`
- [ ] OG tags rendered in initial HTML for parent and child routes (SSR confirmed)

**Functional Verification — P2P_FUNDRAISER**:

(see Verification block in Tasks section above — all checklist items must pass)

**DB Seed Verification**:

- [ ] Admin menu appears in sidebar at `Settings > Public Pages > P2P Campaign Pages`
- [ ] Sample published parent campaign seeded (e.g., "Run for Education 2026") + 3 child fundraisers seeded:
  1. Sarah Chen — Individual — $5,200 raised — Active
  2. Khalid Al-Mansouri — Team Captain ("Dubai Runners Club") — $3,200 raised — Active
  3. Maria Lopez — Individual — Pending (when ApprovalMode=MANUAL on seeded parent for QA)
- [ ] Sample donations seeded across both parent-direct and child-routed (P2PCampaignPageId / P2PFundraiserId set)
- [ ] Public parent route `/p2p/run-for-education-2026` renders with leaderboard showing 3 fundraisers
- [ ] Public child route `/p2p/run-for-education-2026/sarah-chen` renders with personal hero + progress + donate form
- [ ] Public Start-Fundraiser wizard `/p2p/run-for-education-2026/start` renders with campaign auto-selected
- [ ] Status transitions exercised in seed: Draft → Published → Active each render correctly
- [ ] Leaderboard cache TTL = 60s validated
- [ ] CHECK constraint on GlobalDonations (NUM_NONNULLS(OnlineDonationPageId, P2PCampaignPageId) <= 1) enforced

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Universal EXTERNAL_PAGE warnings**:

- **FOUR render trees** — admin setup AND anonymous public parent AND anonymous public child AND anonymous Start-Fundraiser wizard. Different route groups (`(core)` vs `(public)`), different layouts, different auth gates.
- **Slug uniqueness is per-tenant for parent and per-parent for child** — two-level uniqueness; `(CompanyId, Slug)` for parent, `(P2PCampaignPageId, Slug)` for child. Path is hierarchical: `/p2p/{parentSlug}/{childSlug}`.
- **Lifecycle is BE-enforced** — never trust an FE flag. Status transitions are explicit commands.
- **Anonymous-route hardening is non-negotiable** — rate-limit + CSRF + honeypot + recaptcha + CSP headers on all 4 public routes.
- **PCI scope must NOT cross the public form** — payment gateway tokenizes at iframe boundary; raw card data never touches our servers.
- **OG meta tags must be SSR-rendered** for parent + child routes (social crawlers don't run JS). Wizard route is CSR — no OG needed.
- **Slug is immutable post-Activation when donations attached** — link rot prevention.
- **Donation persistence is OUT OF SCOPE for this entity** — donations live in `fund.GlobalDonations` with two new nullable FKs. The page is a SOURCE/FUNNEL.
- **GridFormSchema = SKIP** — custom UI, not RJSF modal form.
- **GridType = EXTERNAL_PAGE** — already registered by OnlineDonationPage prerequisite. Confirm; do not duplicate.

**P2P_FUNDRAISER-specific warnings**:

- **Campaign FK is required** — every P2PCampaignPage wraps a Campaign row in `app.Campaigns`. Tab 1 fields persist to Campaign, not P2PCampaignPage. Update mutation must update both atomically.
- **Approval queue must be visible from setup home** — when ApprovalMode=MANUAL and pendingCount > 0, status bar shows amber pill linking directly to filtered grid. Hiding this behind a tab means fundraisers stuck Pending forever.
- **Start-Fundraiser must dedupe Contact by email** — calling startP2PFundraiser with an email that matches an existing Contact must NOT create a duplicate; instead link the new P2PFundraiser to the existing ContactId.
- **Child slug collision check** — child slug auto-generation runs through reserved-list AND parent's existing children check. Wizard step 2 shows real-time availability indicator.
- **Leaderboard must be cached server-side** — never query GROUP BY P2PFundraiserId on every public render. 60s cache TTL + invalidate on donation event.
- **Team relationship enforcement** — TeamId on P2PFundraiser must reference a P2PFundraiserTeam row that belongs to the same P2PCampaignPageId. EF config validates.
- **Closed parent cascades** — when parent flips to Closed, ALL children flip to Completed; donate buttons disabled across the entire tree (parent + every child).
- **Login-link manage page** — fundraiser-owner edit mode at `/p2p/{slug}/{childSlug}/manage?token=X` uses time-limited JWT (24h validity); allows editing own page (story / cover / personal goal) without admin login. Token stored on contact record.
- **Two-FK CHECK on GlobalDonations** — exactly one of (OnlineDonationPageId, P2PCampaignPageId) is set; never both. CHECK constraint enforces.
- **SSR with revalidation** — both parent and child use `revalidate: 60`; aggregations recompute server-side on each ISR rebuild.
- **Anonymous donor wall** — donor name shown only when donation.IsAnonymous=FALSE; otherwise show "Anonymous" with `fa-user-secret` avatar.
- **Wizard idempotency** — submit must accept `idempotencyKey` (client-generated UUID); same key returns same fundraiser response within 24h window. Prevents duplicate fundraiser pages on user refresh-after-submit.

**ALIGN-scope caveat (FE_STUB existing)**:

- An UnderConstruction stub exists at `PSS_2.0_Frontend/src/app/[lang]/setting/publicpages/p2pcampaignpage/page.tsx`. The build will REPLACE this stub with the real list-page component. No data preserved; safe to overwrite.

**Public-route deployment checklist**:

- [ ] Public route group `(public)` exists with no admin chrome
- [ ] Anonymous middleware allows GET on `/p2p/{slug}` and `/p2p/{slug}/{childSlug}` and `/p2p/{slug}/start`; POST on public mutations only
- [ ] Rate-limit policies "P2PDonationSubmit" (5/min/IP/slug) and "P2PStartFundraiser" (3/min/IP/parent-slug) registered
- [ ] CSRF token issued on public GET render and validated on public POST
- [ ] CSP headers set with payment-gateway iframe origin allowed; recaptcha origin allowed
- [ ] OG meta-tag pre-render in `generateMetadata` for parent + child
- [ ] 404 / 410 / closed-banner / paused-banner edge states render correctly
- [ ] Login-link JWT secret separate from admin JWT secret

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER**: 'Payment Gateway' — UI fully implemented (amount chips, recurring, donor fields, payment method selection, submit button). Handler returns mocked success token. Real Stripe / PayPal / ApplePay / BankTransfer integration lives in payment-gateway CONFIG screen and is pending.
- ⚠ **SERVICE_PLACEHOLDER**: 'Email Send' — UI implemented (template selectors in Tab 5; welcome / approve / reject / donation-alert / goal-reached / weekly / end-summary triggers). Handlers log to console + persist a NotifyOutbox row but do not actually send because email-send service isn't wired yet. Verifies once SMTP/SES integration lands.
- ⚠ **SERVICE_PLACEHOLDER**: 'WhatsApp Send' — UI implemented (template selector + 2 toggles in Tab 5). Handlers log only; real WhatsApp Business API integration deferred.
- ⚠ **SERVICE_PLACEHOLDER**: 'reCAPTCHA v3' — UI placeholder; score check returns 1.0 until reCAPTCHA configured. Public Start-Fundraiser and donate POSTs run without reCAPTCHA validation in the meantime (still rate-limited + honeypot + CSRF protected).
- ⚠ **SERVICE_PLACEHOLDER**: 'Image Upload' — UI implemented (upload-area for hero / logo / cover / OG / profile photo). Handler stores to local-disk placeholder OR existing CDN service; if no CDN configured, uses temporary `/uploads/` server endpoint with size validation.
- ⚠ **SERVICE_PLACEHOLDER**: 'YouTube/Vimeo Embed Validation' — URL accepted as-is; basic regex validation only; no metadata fetch (title / thumbnail) until enrichment service added.
- ⚠ **SERVICE_PLACEHOLDER**: 'Conversion Rate metric' — Status Bar `conversionRate` shows "—" because no page-visit logging table exists. Future enhancement: add `fund.P2PPageVisits` append-only log + nightly aggregate.
- ⚠ **SERVICE_PLACEHOLDER**: 'Achievement Badge events' — UI shows the 4 reference badges (First Donation / 50% Goal / Goal Reached / Top Fundraiser). Backend awards badges based on aggregated donation events; if badge-awarding service not wired, badges show as static reference list without per-fundraiser earned-state.

Full UI must be built (5 setup tabs, 4 public render trees including wizard, donation flow up to gateway boundary, admin moderation queue + slide-out detail panel + edit-content override, communication template selectors, lifecycle commands, edge states). Only the handlers for genuinely missing services are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | LOW | BE / Public | `ConfirmP2PDonation` returns mock success and does NOT persist `fund.GlobalDonation` — SERVICE_PLACEHOLDER. Real handler will read `PaymentTransaction`, flip status, bump aggregates. Mirrors OnlineDonationPage's existing pattern. Wire when payment-gateway connect lands. | OPEN |
| ISSUE-2 | 1 | LOW | BE / Public | `StartP2PFundraiser` Contact upsert is minimal — `ContactBaseTypeId=0` and `PrimaryCountryId=0` placeholders. Real CRM intake (proper resolution + ContactEmailAddress row + dedupe-rule pipeline) deferred. | OPEN |
| ISSUE-3 | 1 | LOW | BE / Public | `DonorEntryDto.IsAnonymous` is heuristic-based (no display name = anonymous) because `GlobalDonation` has no `IsAnonymous` column yet. Swap to real flag when added. | OPEN |
| ISSUE-4 | 1 | LOW | BE | `P2PFundraiserUpdates` GraphQL queries not added — child Updates have CRUD commands and EF-mapped collection on `P2PFundraiser`, but no dedicated `GetUpdatesForFundraiser` query. Extend `GetP2PFundraiserById` or add a new query when FE needs it. | OPEN |
| ISSUE-5 | 1 | MEDIUM | BE / Infra | Leaderboard cache (`IMemoryCache.Remove`) is process-local. In multi-instance deployment, leaderboard invalidation needs Redis/distributed cache. Acceptable for MVP single-instance; flag for production hardening. | OPEN |
| ISSUE-6 | 1 | LOW | BE / Public | CSRF token validation is length-only (≥16 chars). Real cookie+header double-submit middleware (`[ValidateCsrfToken]`) lives at API endpoint layer; body-token format check is MVP guard. | OPEN |
| ISSUE-7 | 1 | LOW | BE / Seed | `Sett.Grids` row seeded but `GridFields` / `GridFieldFilters` mappings deliberately omitted because `GridFormSchema: SKIP` (custom UI, not stock DataTable). Confirm FE doesn't rely on grid-field metadata for the admin list. | OPEN |
| ISSUE-8 | 2 | LOW | FE / Public | Login-link manage page (`(public)/p2p/[campaignSlug]/[fundraiserSlug]/manage/page.tsx`) deferred. Token-auth fundraiser-owner edit shell not generated — depends on JWT issuance + validation (SERVICE_PLACEHOLDER). When token-auth lands, create the manage page reusing `<ChildFundraiserPage>` in an editable variant for story / cover / personal-goal / milestones. | OPEN |
| ISSUE-9 | 13 | MEDIUM | BE/FE contract | §⑯ publish escape-hatch: FE "Publish without sending" persistently flips `sendInvitationOnPublish` OFF (a one-time publish choice mutates the campaign's master flag for all future republishes). BE owner to decide: (A) accept as-is (spec-conformant, no BE change) or (B) add nullable one-time override `PublishP2PCampaignPage(id, bool? sendInvitationOverride)` + rewire FE `publishWithFlag` to pass it without persisting. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-09 — BUILD — PARTIAL

- **Scope**: Initial Backend + DB Seed build from PROMPT_READY prompt (split-strategy session 1 of 2; FE deferred to session 2).
- **Files touched**:
  - BE (created — 51):
    - Entities: `P2PCampaignPage.cs`, `P2PFundraiser.cs`, `P2PFundraiserTeam.cs`, `P2PFundraiserMilestone.cs`, `P2PFundraiserUpdate.cs` (created)
    - EF Configs: `P2PCampaignPageConfiguration.cs`, `P2PFundraiserConfiguration.cs`, `P2PFundraiserTeamConfiguration.cs`, `P2PFundraiserMilestoneConfiguration.cs`, `P2PFundraiserUpdateConfiguration.cs` (created)
    - DTOs: `P2PCampaignPageSchemas.cs`, `P2PFundraiserSchemas.cs`, `P2PFundraiserTeamSchemas.cs`, `P2PFundraiserMilestoneSchemas.cs`, `P2PFundraiserUpdateSchemas.cs` (created)
    - Validator: `P2PCampaignPageSlugValidator.cs` (created)
    - Helper: `P2PCampaignPageEntityHelper.cs` (created)
    - Admin Queries (8): `GetP2PCampaignPageById/List/Stats/PublishValidation/Leaderboard/PendingFundraisers.cs` + `GetP2PFundraiserById/Stats.cs` + `GetAllFundraisersByP2PCampaignPage.cs` (created)
    - Admin Commands (15): Create/Update + 4 Lifecycle (Publish/Unpublish/Close/Archive) for parent; Create/Update + 5 Approval (Approve/Reject/Pause/Resume/Feature) for fundraiser; Team CRUD (3); Milestone CRUD+Reorder (4); Update CRUD (3) (created)
    - Public Queries (4): `GetP2PCampaignPageBySlug.cs`, `GetP2PCampaignPagePublicLeaderboard.cs`, `GetP2PCampaignPageRecentDonors.cs`, `GetP2PFundraiserBySlug.cs` (created)
    - Public Mutations (4): `StartP2PFundraiser.cs`, `InitiateP2PDonation.cs`, `ConfirmP2PDonation.cs`, `IncrementP2PFundraiserViewCount` (created)
    - Communication Handlers: `P2PCommunicationHandlers.cs` (8 stubs in one file) (created)
    - GraphQL Endpoints: `P2PCampaignPageQueries.cs`, `P2PCampaignPageMutations.cs`, `P2PCampaignPagePublicQueries.cs`, `P2PCampaignPagePublicMutations.cs` (created)
    - Migration: `20260509115557_Add_P2PCampaignPage_Schema.cs` + Designer (created)
  - BE (modified — 7):
    - `GlobalDonation.cs` (added `P2PCampaignPageId?`, `P2PFundraiserId?` + 2 nav props)
    - `GlobalDonationConfiguration.cs` (added 2 FK rels Restrict + 2 indexes + `CK_GlobalDonations_OnePageSource` CHECK constraint)
    - `IDonationDbContext.cs` (5 new DbSet declarations)
    - `DonationDbContext.cs` (5 new DbSet implementations)
    - `DecoratorProperties.cs` (5 new entity decorator constants under `DecoratorDonationModules`)
    - `DonationMappings.cs` (5 Mapster `TypeAdapterConfig` entries)
    - `DependencyInjection.cs` (registered `AddMemoryCache`, rate-limit policies `P2PStartFundraiser` 3/min/IP and `P2PDonationSubmit` 5/min/IP, added `UseRateLimiter`)
  - DB:
    - `sql-scripts-dyanmic/p2pcampaignpage-sqlscripts.sql` (created — 426 lines, 11 idempotent steps; sample Campaign "Run for Education 2026" + P2PCampaignPage Active + Team "Dubai Runners Club" + 3 Fundraisers (Sarah Active, Khalid Team-Captain Active, Maria Pending) + 9 Milestones + P2PCAMPAIGNTYPE MasterData + Menu + Capabilities + RoleMenuMapping for BUSINESSADMIN)
- **Build status**: `dotnet build PeopleServe.sln` succeeded (no errors, only pre-existing warnings unrelated to P2P).
- **Migration status**: `20260509115557_Add_P2PCampaignPage_Schema` generated cleanly. Includes 5 CreateTable + 7 FK constraints + filtered unique indexes + ALTER fund.GlobalDonations + `CK_GlobalDonations_OnePageSource` CHECK constraint via raw SQL.
- **Deviations from spec**: All SERVICE_PLACEHOLDERs implemented as scoped per §⑫ (see Known Issues). No deviations from primary entity / DTO / endpoint contracts.
- **Known issues opened**: ISSUE-1 through ISSUE-7 (see Known Issues table above).
- **Known issues closed**: None.
- **Next step**: All FE files (admin list + 5-tab editor + grid/queue + 3 public routes + start wizard + supporting components + entity-operations + module-menu wiring + Apollo public-route client + generateMetadata exports). Run `/build-screen #170 --scope FE_ONLY` (or `/continue-screen p2pcampaignpage`) in a fresh session.

### Session 2 — 2026-05-10 — BUILD — COMPLETED

- **Scope**: FE_ONLY (continuation of split-strategy build). Full FE generated in one run per user approval. UX Architect (opus) → FE Build Brief → Frontend Developer (opus) → static validation.
- **Files touched**:
  - FE (created — 61):
    - DTO (1): `domain/entities/donation-service/P2PCampaignPageDto.ts` (~600 LOC; all parent + child + public + stats DTOs + literal types)
    - GQL constants (4): `gql-queries/donation-queries/P2PCampaignPageQuery.ts` (9 admin queries), `gql-queries/public-queries/P2PCampaignPagePublicQuery.ts` (7 public queries), `gql-mutations/donation-mutations/P2PCampaignPageMutation.ts` (22 admin mutations), `gql-mutations/public-mutations/P2PCampaignPagePublicMutation.ts` (4 public mutations)
    - Admin setup (28): `setting/publicpages/p2pcampaignpage/{p2pcampaignpage-root, p2pcampaignpage-store, list-page, editor-page, index}.tsx/.ts` + `tabs/{basic-info, fundraiser-settings, donation-settings, branding-page, communication}-tab.tsx` (5 tabs) + `components/{tab-nav, status-bar, section-card, api-single-select, live-preview, fundraiser-grid, approval-queue, fundraiser-detail-panel, reject-reason-modal, send-message-modal, upload-area, amount-chips, radio-cards, color-picker, rich-text-editor, index}.tsx/.ts` (16 components)
    - Page-config (1): `presentation/pages/setting/publicpages/p2pcampaignpage.tsx`
    - Admin route wrapper (1): `app/[lang]/setting/publicpages/p2pcampaignpage/page.tsx` (REPLACED UnderConstruction stub)
    - Public root pages (3): `app/[lang]/(public)/p2p/[campaignSlug]/{page, [fundraiserSlug]/page, start/page}.tsx`
    - Public components (24): `public/p2pcampaignpage/{parent-landing-page, child-fundraiser-page, start-fundraiser-wizard, p2p-wizard-store, index}.tsx/.ts` + `components/{org-header, parent-hero, progress-section, leaderboard, donor-wall, impact-stats, child-cover-profile, child-story, child-updates, child-team-section, child-progress-widget, donate-form, share-buttons, mobile-donate-bar, public-footer}.tsx` + `wizard/{step-1-identity, step-2-page-setup, step-3-donation-settings, step-4-review, success-screen}.tsx` (5 wizard step components)
  - FE (modified — 1):
    - `application/configs/data-table-configs/donation-service-entity-operations.ts` — appended `P2PCAMPAIGNPAGE` block (mirrors ONLINEDONATIONPAGE pattern; 5 operation slots wired to admin queries/mutations; toggle aliases publish/unpublish; delete aliases archive)
- **Build status**:
  - `tsc --noEmit` (full-FE typecheck) — PASSED with 0 errors after generation
  - Anti-pattern grep checks (per build-screen Step 5b) — ALL ZERO matches:
    - inline hex colors (`style={{...#hex}}`): 0
    - inline pixel padding/margin (`style={{...padding/margin: \d+}}`): 0
    - bootstrap card chrome (`className="card..."`): 0
    - raw "Loading..." text: 0
  - GQL field-naming convention: confirmed HotChocolate camelCase mapping `P2PCampaignPageId → p2PCampaignPageId` (matches BE schema)
  - Wiring symbol resolution: confirmed exports for `GET_P2P_CAMPAIGN_PAGE_LIST`, `GET_P2P_CAMPAIGN_PAGE_BY_ID`, `CREATE/UPDATE/DELETE/ACTIVATE_DEACTIVATE_P2P_CAMPAIGN_PAGE` mutations, `P2PCampaignPageDto` and `P2PCampaignPageRequestDto` interfaces — all present
- **Layout Variant compliance**:
  - Admin list: custom plain HTML table + 4 KPI cards above (mirrors OnlineDonationPage list-page.tsx; not FlowDataTableContainer/AdvancedDataTable; no ScreenHeader needed since not data-table-container based)
  - Admin editor: custom 5-tab layout with sticky header/footer/status-bar; Active Fundraisers Grid below tabs when `pageStatus >= Published`; Tab 4 split-pane with inline live-preview (NOT iframe), debounced 300ms
  - Public surfaces: bare layout (no admin chrome) under existing `(public)/layout.tsx`; tenant brand-driven via `primaryColorHex` / `secondaryColorHex` from public DTO
- **Deviations from spec**:
  - Login-link manage page (`(public)/p2p/[campaignSlug]/[fundraiserSlug]/manage/page.tsx`) DEFERRED — Tier 3, depends on token-auth service which is SERVICE_PLACEHOLDER. ISSUE-8 raised below.
- **Known issues opened**:
  - ISSUE-8 (LOW, FE / Public): Login-link manage page deferred. Token-auth fundraiser-owner edit shell at `/p2p/{slug}/{childSlug}/manage?token=X` not generated this session — depends on JWT issuance + validation (SERVICE_PLACEHOLDER). When token-auth lands, create the manage page using the same `<ChildFundraiserPage>` composition wrapped in editable mode for story / cover / personal-goal / milestones.
- **Known issues closed**: None (ISSUE-1..ISSUE-7 from Session 1 all remain OPEN — they are SERVICE_PLACEHOLDER-scope and not in scope for the FE build).
- **Next step**: Run `pnpm dev` to smoke-test the 4 routes:
  1. `/{lang}/setting/publicpages/p2pcampaignpage` — admin list
  2. `/{lang}/p2p/run-for-education-2026` — public parent (seeded sample)
  3. `/{lang}/p2p/run-for-education-2026/sarah-chen` — public child (seeded sample)
  4. `/{lang}/p2p/run-for-education-2026/start` — public Start-Fundraiser wizard
  Confirm sidebar menu appears under Settings → Public Pages → P2P Campaign Pages, KPI cards render, table loads, "+ Create P2P Campaign" creates Draft → editor opens, all 5 tabs render with seeded values, Active Fundraisers Grid shows 3 seeded fundraisers (1 Pending tinted amber), public parent renders with hero + progress + leaderboard + donor wall, public child renders 60/40 layout with sticky mobile donate bar, wizard renders 4-step stepper with slug-availability check.

### Session 3 — 2026-05-10 — FIX — COMPLETED

- **Scope**: Hotfix during user smoke-test of Session 2 build. `getAllFundraisersByP2PCampaignPage` admin query failed with `Field "socialShareMessages" of type "[KeyValuePairOfStringAndString!]" must have a selection of subfields` — same shape applied to public child query and fundraiser stats query.
- **Root cause**: BE schemas declare `Dictionary<string, string>? SocialShareMessages` (P2PFundraiserSchemas.cs lines 40, 107, 195) and `Dictionary<string, int> SharesByPlatform` (line 139). HotChocolate exposes `Dictionary<TKey,TValue>` as a list of `[KeyValuePairOf{K}And{V}]` objects requiring `{ key value }` subfield selection. The Session 2 GQL queries treated these as scalar fields.
- **Files touched**:
  - FE (modified — 3):
    - `domain/entities/donation-service/P2PCampaignPageDto.ts` — added `KeyValuePair<V>` type alias + `recordToKvPairs` / `kvPairsToRecord` helper functions; changed 3 `socialShareMessages` field types and 1 `sharesByPlatform` field type from `Record<string, V>` to `KeyValuePair<V>[] | null`.
    - `infrastructure/gql-queries/donation-queries/P2PCampaignPageQuery.ts` — line 302 `socialShareMessages` → `socialShareMessages { key value }` (in fundraiser fields fragment used by `getAllFundraisersByP2PCampaignPage` + `getP2PFundraiserById`); line 386 `sharesByPlatform` → `sharesByPlatform { key value }` (in `getP2PFundraiserStats`).
    - `infrastructure/gql-queries/public-queries/P2PCampaignPagePublicQuery.ts` — line 139 `socialShareMessages` → `socialShareMessages { key value }` (in `getP2PFundraiserBySlug`).
    - `presentation/components/page-components/public/p2pcampaignpage/start-fundraiser-wizard.tsx` — wizard submit transforms internal `Record<string,string>` form-state to `KeyValuePair<string>[]` via `recordToKvPairs(store.socialShareMessages)` before passing to `startP2PFundraiser` mutation (BE input type `[KeyValuePairOfStringAndStringInput!]`).
- **Build status**: `tsc --noEmit` PASSED (0 errors).
- **Deviations from spec**: None — this is a contract-correction hotfix. The DTO surface still keeps Record-shaped state internally in the wizard store; only the wire-protocol DTO uses array-of-pairs.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User retests `getAllFundraisersByP2PCampaignPage` admin query (expected to succeed); also retests `getP2PFundraiserStats` and the public child query if exercised.

### Session 4 — 2026-06-30 — ENHANCE — COMPLETED (BE build pending)

- **Scope**: Port the CrowdFunding (#173) editor "structure" onto this combined #15/#170 P2P campaign-page screen — 3-step publish lifecycle + edit-lock, accurate dirty-count, Public-page-URL bar, and a persistent split-pane live preview. (#15 is the main entry; #170 is the page editor.)
- **Files touched**:
  - BE (2 NEW + 2 MODIFY — **user must `dotnet build`**):
    - `…/DonationBusiness/P2PCampaignPages/LifecycleCommands/MarkP2PCampaignPageReadyToPublish.cs` (NEW) — Draft → ReadyToPublish.
    - `…/LifecycleCommands/RevertP2PCampaignPageToDraft.cs` (NEW) — ReadyToPublish → Draft.
    - `…/LifecycleCommands/PublishP2PCampaignPage.cs` — now accepts source status Draft **or** ReadyToPublish (guard added before validation).
    - `…/EndPoints/Donation/Mutations/P2PCampaignPageMutations.cs` — registered `markP2PCampaignPageReadyToPublish` + `revertP2PCampaignPageToDraft` endpoints. `PageStatus` is a free-text string column, so **no enum / no migration / no seed**.
  - FE (modified — 6, NEW — 1):
    - `…/p2pcampaignpage/p2pcampaignpage-store.ts` — `setField`/`patch` now clear the dirty flag when a value reverts to `lastSaved` (port of CrowdFund `isSameAsSaved`); fixes the "count stuck at 1 after editing back" bug.
    - `…/p2pcampaignpage/components/public-page-url-bar.tsx` (NEW) — Copy/Open bar for `/{lang}/p2p/{slug}`, reads slug live from store; rendered OUTSIDE the lock fieldset.
    - `…/p2pcampaignpage/editor-page.tsx` — 3-step publish pill (Draft → **Mark as Ready to Publish**; ReadyToPublish → **Cancel Ready to Publish** + **Publish**); `isLocked = !isNew && !isDraft` wraps tab content in `<fieldset disabled>`; Draft helper + amber lock banners; Save button shows `Save Draft (N)`; Configuration tab now a split-pane `[editor | LivePreview]` (preview outside the lock); URL bar above tabs on both tabs.
    - `…/p2pcampaignpage/components/status-bar.tsx` — added `ReadyToPublish` chip (amber).
    - `…/p2pcampaignpage/components/live-preview.tsx` — now actually rendered (was orphaned).
    - `domain/entities/donation-service/P2PCampaignPageDto.ts` — `P2PCampaignPageStatus` union gains `"ReadyToPublish"`.
    - `infrastructure/gql-mutations/donation-mutations/P2PCampaignPageMutation.ts` — `MARK_P2P_CAMPAIGN_PAGE_READY_TO_PUBLISH` + `REVERT_P2P_CAMPAIGN_PAGE_TO_DRAFT`.
- **Build status**: FE `tsc --noEmit` PASSED (0 errors for the P2P area). BE NOT yet built (user builds BE).
- **Deviations from spec**: P2P Publish does **not** auto-advance Published→Active (CrowdFund does) — dates live on the wrapped Campaign, not the page entity, so the auto-advance was skipped to avoid a Campaign join. Live states (Published/Active) are both treated as "locked" by the editor regardless.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step (not done this pass)**: (E) broader uniform-section / canonical-form-field / currency-formatter polish across the Configuration tab (status-bar still uses `Intl.NumberFormat(undefined)`); (F) align the #15 CRM list/flow grid row-actions with the CrowdFunding list. Confirm priority with user.

### Session 5 — 2026-06-30 — ENHANCE/AUDIT — COMPLETED

- **Scope**: Close out the Session-4 "next step" items (E uniform-section/currency, F #15 grid row-actions). One concrete fix + two audit confirmations.
- **Files touched**:
  - FE: `…/p2pcampaignpage/components/status-bar.tsx` — replaced the inline `Intl.NumberFormat(undefined, …)` currency helper with the app-wide tenant-aware canonical `formatCurrency` from `@/presentation/utils/companySettingsFormatters` (honors org number-format / separators / symbol placement; matches the KPI widgets which already use `formatCompactCurrency`). Call sites unchanged (`formatCurrency(value, code)`).
  - BE/DB: None.
- **Audit findings (no change needed)**:
  - **(E) Uniform sections** — already at parity: all 5 Configuration sub-tabs (`fundraiser-settings`, `donation-settings`, `branding-page`, `communication`, `basic-info`) already render through the canonical `SectionCard`/`SubSection` chrome. Nothing to refactor.
  - **(F) #15 CRM grid row-actions** — already at/above CrowdFunding parity. `P2PCampaignActionsCell` is fully wired (registered in all three grid column dispatchers: basic/advanced/flow, case `"p2p-campaign-actions"`) and is *richer* than CrowdFunding's plain native View/Edit/Delete — it renders status-conditional Dashboard / Edit / View / Duplicate / Delete. The remaining cosmetic gap vs CrowdFunding (status chips lack count badges) needs new per-status summary count fields on the BE `P2PCampaignSummaryDto` (currently only `activeCount` / `totalCount`) — deferred, not built (would require a BE change + user build).
- **Deviations from spec**: P2P status-bar now uses the canonical tenant-aware formatter while CrowdFunding's own status-bar still uses `Intl.NumberFormat(undefined)` — deliberate (canonical-reuse outranks mirroring the inferior inline formatter). CrowdFunding's status-bar could get the same one-line upgrade later; left untouched to keep this session scoped to #170 and avoid parallel-session churn.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: (Optional) add per-status count badges to the #15 chips — requires BE `P2PCampaignSummaryDto` count fields (completed/draft/archived). (Optional) port the same canonical-currency one-liner into CrowdFunding's `status-bar.tsx` for cross-screen uniformity.

---

### Session 6 — 2026-06-30 — UI — COMPLETED

- **Scope**: Three user-reported polish items on the editor — (1) currency still not symbol-aware in the top bar + goal-range + minimum-donation fields, (2) Configuration sections not ordered header→content→footer, (3) color picker lacked preset swatches like CrowdFunding.
- **Files touched**:
  - FE (new): `…/p2pcampaignpage/use-editor-currency.ts` — shared `useEditorCurrency()` hook resolving the campaign currency CODE + the tenant currency SYMBOL (₹/$) via `useCompanyCurrency` (CURRENCY_BY_ID lookup), returning `{ code, symbol, prefix }`. Single source of truth for the editor's display currency; symbol only borrowed when campaign code === org base code, else falls back to the code.
  - FE: `components/status-bar.tsx` — new optional `currencySymbol` prop threaded into the canonical `formatCurrency` (`currencySymbol` option) so the top bar renders the symbol instead of the bare ISO code.
  - FE: `editor-page.tsx` — calls `useEditorCurrency()`, passes `currencyCode={currency.code}` + `currencySymbol={currency.symbol}` to `StatusBar` (replaces the hard-coded `page.goalCurrencyCode ?? "USD"`).
  - FE: `tabs/basic-info-tab.tsx`, `tabs/fundraiser-settings-tab.tsx`, `tabs/donation-settings-tab.tsx` — every money adornment (Campaign Goal, goal-range trio, Default Team Goal, Minimum Donation, amount-chips) now uses `cur.prefix` from the hook instead of `page.goalCurrencyCode ?? "USD"`.
  - FE: `components/live-preview.tsx` — progress widget currency now uses `cur.prefix` (was `snapshot.goalCurrencyCode ?? "$"`), keeping the preview consistent with the form.
  - FE: `tabs/configuration-tab.tsx` — reordered to mirror the public page (CrowdFunding parity): **Public Page (BrandingPageTab)** at the top → **Campaign Setup (Fundraiser + Donation settings)** in the center → **Communications (CommunicationTab)** last, each under a `RegionHeading` divider (icon + uppercase title + subtitle + rule). Was: Fundraiser, Donation, Branding, Communication.
  - FE: `tabs/branding-page-tab.tsx` — swapped the bespoke hex-only `../components/color-picker` for the canonical preset-aware `setting/publicpages/onlinedonationpage/components/color-picker` (preset swatches + WCAG contrast hint), added the 12-swatch `P2P_COLOR_PRESETS` palette, and wrapped Primary/Secondary pickers with their own label + description (canonical picker has no `label`/`description` props).
  - BE/DB: None.
- **Deviations from spec**: None. The bespoke `components/color-picker.tsx` is now orphaned (only branding-page-tab used it) — left in place to keep the change surface minimal; safe to delete later.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: None (chip count-badges item from Session 5 still open, BE-dependent). Typecheck clean in `src/` (only the pre-existing stale `.next` types artifact for the old `setting/publicpages/p2pcampaignpage` route remains, unrelated).

---

### Session 7 — 2026-07-01 — UI — COMPLETED (DB re-seed pending)

- **Scope**: On the #15 P2PCampaign **index grid**, switch the per-row actions from the bespoke status-conditional button cluster (custom `P2PCampaignActionsCell`: Dashboard / Edit / View-page / Duplicate / Delete) to the **standard FlowDataTable action column** (View / Edit / Delete icons), mirroring CrowdFunding.
- **Root cause**: The grid deliberately seeded the PK GridField `IsPrimary=false` to suppress the standard `ActionColumnBuilder`, and injected a custom component-column (`GridComponentName='p2p-campaign-actions'`) instead. The default action column only renders when a GridField has `IsPrimary=true` (populates `primaryColumn` → `ActionColumnBuilder`) AND capability grants read/update/delete.
- **Files touched**:
  - DB: `sql-scripts-dyanmic/P2PCampaign-sqlscripts.sql` — (a) PK GridField `P2PCAMPAIGNPAGEID` flipped `IsPrimary=false → true` (both the INSERT for fresh DBs and the idempotent re-point UPDATE for already-seeded DBs); (b) the custom actions column (#10, `P2PC_ACTIONS` / `p2p-campaign-actions`) INSERT replaced with a soft-delete UPDATE (`IsActive=false, IsDeleted=true`) so it doesn't double up with the standard column.
  - FE: `p2pcampaign/index-page.tsx` — `enableActions` flipped to `{ enableView: true, enableEdit: true, enableDelete: true, enableToggle: false }`. Also enabled the toolbar's **advanced filter** (`enableAdvanceFilter: true` — CrowdFunding parity; columns already seeded `IsFilterable=true`) and the **column chooser** (`enableSelectField: true` — show/hide/reorder). Sorting was already on (`enableSorting: true`). These were previously all `false`, which is why the filter + columns toolbar buttons weren't showing.
  - FE: `p2pcampaign/index.tsx` (URL dispatcher) — now catches `?mode=read` (the standard View eye action's deep-link) alongside `?mode=edit`, opening the editor. View behaviour chosen by the user (editor has no separate read-only surface).
- **Standard actions wiring** (already in place, no change): Edit → `?mode=edit&id` → editor; Delete → `DataTableOperationConfigs['P2PCAMPAIGN'].delete` = `DELETE_P2P_CAMPAIGN_PAGE_HARD` (Draft-only guards enforced at the GQL layer, so the standard confirm dialog is safe); PK resolves from the now-`IsPrimary=true` GridField.
- **Deviations from spec**: View (eye) opens the editor rather than a read-only detail drawer — CrowdFunding uses a `?mode=read` drawer, but P2P has none and the editor has no read-only mode; per user decision, View reuses the editor. The custom `p2p-campaign-actions-cell.tsx`, its 3 `component-column.tsx` registrations, and the `Duplicate`/`Delete` P2P modals mounted in `index-page.tsx` are now orphaned (GridField deactivated → never rendered) — left in place to keep the change surface minimal and avoid touching shared wiring files; safe to remove later.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User re-runs `P2PCampaign-sqlscripts.sql` against the DB (the `IsPrimary` flip + custom-column soft-delete are idempotent UPDATEs), then hard-refresh the grid. FE typecheck clean in `src/` (only the pre-existing stale `.next` artifact remains). No BE/build change this session.

---

### Session 8 — 2026-07-01 — FIX/UI — COMPLETED (BE build pending)

Five reviewer items on the #170 editor + public donate form, CrowdFunding as reference.

- **Item 1 — Save Draft button (count)**: Draft-branch button in `editor-page.tsx` re-labelled to CrowdFunding parity — ADD mode shows plain `Save Draft` (nothing to count yet), EDIT mode shows `Save Draft (N)` when dirty else `Saved`. Dropped the always-on pulsing dot (the count IS the signal) and added a saving spinner. Disabled-when-clean already held (`canSave = isDirty` in edit mode).
- **Item 2 — Currency default**: new campaigns now inherit the **company base currency**. Added a `useCompanyCurrency()` seeding effect in `editor-page.tsx` that, once the company currency resolves and only while `goalCurrencyId` is still empty, patches `{ goalCurrencyId, goalCurrencyCode }` — so every money field (goal, minimum, chips) shows the right symbol from the start. Picker stays editable (CrowdFunding parity; user decision).
- **Item 3 — Field order**: in `donation-settings-tab.tsx` the **Payment Gateway** select now sits **above** the payment-method list (gateway is the parent choice, methods are what it accepts).
- **Item 4 — Donor identity (contact code OR name+email)**: user decision = **donor chooses either at donate time**. Public `donate-form.tsx` gained a segmented toggle ("New donor" = first/last/email · "I have a contact code" = single code input); `canSubmit` + submit payload switch on the mode and send only the chosen path (other side null). BE `InitiateP2PDonationDto` (in `P2PFundraiserSchemas.cs`) — `FirstName/LastName/Email` made nullable + new `ContactCode`; validator now conditionally requires name+email only when `ContactCode` is empty; handler logs a unified `donor=` ref (email or `contactCode:…`) and documents the deferred contact-by-code resolution (still SERVICE_PLACEHOLDER — no persistence yet). Admin builder (`donation-form-fields.tsx`) got a note that its toggle now only sets which path shows first.
- **Item 5 — Missing asterisks**: backend publish-validation requires Campaign **Story**, Campaign **Type**, ≥1 **Payment Method**, ≥1 **Amount chip (or custom)** — none showed a `*`. Added `required?` support to `SubSection` (`section-card.tsx`) and marked Campaign Type + Campaign Story (`basic-info-tab.tsx`), Payment Methods + Donation Amounts (`donation-settings-tab.tsx`, incl. an "add one amount or enable custom" hint). Description already had its `*`. Validation itself was correct — this was purely the missing UX affordance.
- **Files touched**:
  - FE: `p2pcampaignpage/editor-page.tsx` (items 1, 2), `tabs/donation-settings-tab.tsx` (items 3, 5), `tabs/basic-info-tab.tsx` (item 5), `components/section-card.tsx` (item 5 — `SubSection required?`), `components/donation-form-fields.tsx` (item 4 note), `public/p2pcampaignpage/components/donate-form.tsx` (item 4).
  - BE (compiling, **user builds**): `Base.Application/Schemas/DonationSchemas/P2PFundraiserSchemas.cs` (DTO), `Base.Application/Business/DonationBusiness/Public/PublicMutations/InitiateP2PDonation.cs` (validator + handler log).
- **Deviations from spec**: item 4 changes the donor DTO from name-required to either-path; existing name-path callers are unaffected (fields kept, just nullable). The admin `donationFormFields.mode` remains stored but the public form always offers both paths (it was never consumed by the public form anyway).
- **Known issues opened**: Contact-by-code resolution is still SERVICE_PLACEHOLDER — the handler validates/relays the code but does not yet look up `crm.Contact` or persist the donation (blocked on the real payment-gateway connect, same as the name path).
- **Known issues closed**: None (these were fresh reviewer items, not tracked rows).
- **Next step**: user builds the BE (DTO + validator changes to `InitiateP2PDonation`) so the public form's `contactCode` field is accepted by the GraphQL schema; FE ships on next dev reload. FE typecheck clean in `src/` (only the pre-existing stale `.next` artifacts remain).

### Session 9 — 2026-07-01 — FIX — COMPLETED (BE build pending)

Donation Purpose made a required field on #170, matching CrowdFunding.

- **Finding**: a campaign is always run for **one specific donation purpose**, so the field must be required — but only CrowdFunding enforced it. CrowdFunding (`basic-tab.tsx`) already marks Donation Purpose `required` and gates draft-create via zod (`crowdFundQuickFormSchema` → `donationPurposeId: z.number().min(1)`). P2P (`basic-info-tab.tsx`) rendered "Linked Donation Purpose" as **optional** (`clearable`, no `*`), and the BE publish-validation (`GetP2PCampaignPagePublishValidation.cs`) did **not** check it — despite the doc comment claiming "≥1 DonationPurposes attached". Gap in P2P only.
- **Fix (FE)**: `basic-info-tab.tsx` — added `required` to the Donation Purpose `ApiSingleSelect` (renders the `*`), dropped `clearable` (mandatory now), added a helper description. Mirrors the P2P publish-gating + asterisk pattern from Session 8 item 5.
- **Fix (BE, compiling, user builds)**: `GetP2PCampaignPagePublishValidation.cs` — added a `DonationPurposeId` check (null/≤0 → MissingField `donationPurposeId` "Donation purpose is required.") right after the GoalAmount block, so publish is now actually blocked without a purpose and the doc-comment claim becomes true. `DonationPurposeId` is a scalar already loaded on the entity — no extra Include needed.
- **CrowdFunding**: verified already-correct (required in UI + zod). No change.
- **Files touched**:
  - FE: `p2pcampaignpage/tabs/basic-info-tab.tsx`.
  - BE (compiling, **user builds**): `Base.Application/.../P2PCampaignPages/Queries/GetP2PCampaignPagePublishValidation.cs`.
- **Deviations from spec**: none — this closes the doc-comment/behavior gap.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: user builds the BE so the publish-validation blocks on missing donation purpose. FE asterisk ships on next dev reload.

### Session 10 — 2026-07-01 — UI — COMPLETED

Configuration (Tab 2) section chrome aligned to the CrowdFunding Configuration tab.

- **Finding**: CrowdFunding's config tab (`crowdfundingpage/tabs/page-builder-tab.tsx`) wraps every section in the canonical `FormSectionCard` (event `form-tabs/fields.tsx`) — a **SOLID primary header bar** with a white icon chip (`bg-white/15`) + white title/description. The P2P editor's shared `SectionCard` (`p2pcampaignpage/components/section-card.tsx`) used a **muted** header (`bg-muted/50`, inline primary icon, foreground text), so P2P's Configuration tab sections looked different from CrowdFunding's.
- **Fix (FE)**: restyled the P2P `SectionCard` header to mirror `FormSectionCard` — `bg-primary px-3.5 py-2.5`, white icon in a `bg-white/15` chip, white title (`text-white`) + `text-white/80` truncated description; body padding matched to `space-y-4 p-3.5 sm:p-4`. Kept the `badge` prop API (unused across all call-sites — verified) but re-toned it (`bg-white/20 text-white`, amber variant) to stay legible on the primary bar. Consistent with the standing [[solid-icon-bg-white-foreground]] preference.
- **Scope note**: `SectionCard` is the shared card used by **all** P2P editor tabs (Basic Info + every Configuration sub-tab: Branding, Fundraiser, Donation, Communication), so this one change brings the whole editor into uniform parity with CrowdFunding — not just Tab 2. `RegionHeading` dividers already matched. Config sub-tab call-sites unchanged.
- **Files touched**:
  - FE: `p2pcampaignpage/components/section-card.tsx` (header/body chrome only; API unchanged).
- **Deviations from spec**: none — visual alignment only.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: none — FE-only, ships on next dev reload.

### Session 11 — 2026-07-01 — FIX — COMPLETED

`UpdateP2PCampaignPage` silently failed to persist Configuration-tab edits (amount chips, allow-custom-amount, team goal/size) — the **entire** mutation was 400-rejected.

- **Symptom**: user set `amountChips`, `allowCustomAmount`, `maxTeamSize`, saved — nothing persisted. GraphQL error: `The field '__typename' does not exist on the type 'P2PEnabledPaymentMethodInput'.` at `page.enabledPaymentMethods[0]`.
- **Root cause**: Apollo tags every cached object with `__typename`. HotChocolate rejects an input object carrying any field its Input type doesn't declare, so a single stray `__typename` fails the WHOLE mutation (not just that field) → **no** field saved. `toRequest()` in `editor-page.tsx` stripped `__typename` only at the top level + `fundraiserPageOptions` + `donationFormFields.fields` — it **missed the `enabledPaymentMethods[]` array items**. Classic shallow-strip gap ([[apollo-typename-strip-on-round-trip]] / `feedback_apollo_typename_strip_on_round_trip`). BE write-mapping + read-projection + FE GET selection were all already correct — the payload just never reached the handler.
- **Fix (FE)**: added a **recursive** `stripTypename()` helper and applied it to the whole `toRequest()` output, so `__typename` is dropped from every nested object/array (payment methods, page options, form fields, and any future nested shape). Replaced the piecemeal per-field strips. `toCreateRequest()` calls `toRequest()`, so Create inherits the fix too.
- **Files touched**:
  - FE: `p2pcampaignpage/editor-page.tsx` (`toRequest` + new `stripTypename`).
- **Deviations from spec**: none.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: none — FE-only, ships on next dev reload. (No BE build needed — BE was never the problem.)

### Session 12 — 2026-07-01 — FIX — COMPLETED (BE build pending)

Publish redirect to the public page (`/p2p/{slug}`) 404'd on localhost — public GetBySlug used first-active-tenant only. Mirrored the CrowdFunding #173 hostname/login-company tenant resolution.

- **Symptom**: after publishing, `/en/p2p/build-school` → 404. The page owned by the logged-in admin's tenant wasn't found because the public resolver only ever looked under the *first* active company.
- **Root cause**: `GetP2PCampaignPageBySlug` hard-coded `companyId = first active company` (the old MVP hack) — no hostname resolution and no Development login-company fallback. On localhost (no subdomain) a page owned by any non-first tenant misses the company-scoped lookup → null → 404. CrowdFunding already solved this ([[public-by-slug-tenant-resolution]] / `feedback_public_by_slug_tenant_resolution`).
- **Fix (BE, compiling, user builds)**:
  - `GetP2PCampaignPageBySlug.cs` — query record arg `tenantSlug` → `hostname`; handler now injects `IHostEnvironment` + `IHttpContextAccessor` and resolves the tenant via `OnlineDonationPageTenantResolver.ResolveByHostnameAsync` (CustomDomain → Subdomain → `?_tenant=` dev override → first-active fallback). Added the Development-only fallback: if the slug misses under the resolved tenant, re-scope to the logged-in user's company, then a slug-only lookup — so an admin opening their just-published page resolves the right tenant. Production stays strict hostname-scoped.
  - `P2PCampaignPagePublicQueries.cs` — endpoint arg `tenantSlug` → `hostname`, passed through. (Stats endpoint keeps `hostname: null`; the Dev login-company fallback still resolves it locally.)
- **Fix (FE)**:
  - `P2PCampaignPagePublicQuery.ts` — `GET_P2P_CAMPAIGN_PAGE_BY_SLUG` var `$tenantSlug` → `$hostname` (`hostname: $hostname`).
  - All three public campaign routes (`[campaignSlug]/page.tsx`, `.../start/page.tsx`, `.../[fundraiserSlug]/page.tsx`) now resolve a `hostname` from `x-forwarded-host`/`host` (+ `?_tenant=` dev override) and pass it, and switched the campaign fetch to `cache: "no-store"` so a just-published page resolves immediately (no stale-404 from the 60s ISR window).
- **Files touched**:
  - BE (compiling, **user builds**): `.../Public/PublicQueries/GetP2PCampaignPageBySlug.cs`, `.../Base.API/EndPoints/Donation/Public/P2PCampaignPagePublicQueries.cs`.
  - FE: `.../public-queries/P2PCampaignPagePublicQuery.ts`, `(public)/p2p/[campaignSlug]/page.tsx`, `.../start/page.tsx`, `.../[fundraiserSlug]/page.tsx`.
- **Deviations from spec**: none.
- **Known issues opened**: the **fundraiser** child handler `GetP2PFundraiserBySlug` still uses first-active-tenant resolution (same class of bug) — the child page's fundraiser lookup can still 404 on localhost for a non-first tenant. Not fixed here (separate handler, not part of the reported publish flow). Apply the same resolver when that flow is exercised.
- **Known issues closed**: None.
- **Next step**: user builds the BE. FE ships on next dev reload.

### Session 13 — 2026-07-02 — ENHANCE — COMPLETED (FE only; BE built in parallel by user)

- **Scope**: §⑯ CAMPAIGN INVITATION — Send/Resend actions, publish-time opt-in guard, five email-ops guardrails, and auditable send history on screen #170 P2PCampaignPage. Split build: **user owns BE** (`.cs` + migration), **this session owns FE** (`.ts`/`.tsx`). §⑯.3 contract frozen so both halves compile against the same GraphQL names. Single-fundraiser invite stream (`P2PF-{id}-INVITE`, screen #135) left UNTOUCHED — only the campaign donor blast (`P2PC-{id}-INVITE`) is in scope.
- **Files touched**:
  - BE: none (user builds BE in parallel — `PublishP2PCampaignPage.cs`, `P2PFundraiserEmailService.cs`, `P2PCampaignPage.cs` + column, `P2PCampaignPageEntityHelper.cs`, `GetP2PCampaignPageById.cs`, migration).
  - FE (modified — 6):
    - `domain/entities/donation-service/P2PCampaignPageDto.ts` — `sendInvitationOnPublish: boolean` on `P2PCampaignPageRequestDto`; new `P2PCampaignInvitationAudienceCountDto`, `P2PCampaignInvitationHistoryRowDto`, `P2PCampaignInvitationRecipientRowDto`.
    - `infrastructure/gql-queries/donation-queries/P2PCampaignPageQuery.ts` — `sendInvitationOnPublish` in `PAGE_FIELDS`; `GET_P2P_CAMPAIGN_INVITATION_AUDIENCE_COUNT`, `_HISTORY`, `_RECIPIENTS`.
    - `infrastructure/gql-mutations/donation-mutations/P2PCampaignPageMutation.ts` — `SEND_P2P_CAMPAIGN_INVITATION`, `RESEND_P2P_CAMPAIGN_INVITATION`, `SEND_P2P_CAMPAIGN_INVITATION_TEST`.
    - `.../p2pcampaignpage/p2pcampaignpage-store.ts` — `sendInvitationOnPublish: false` in `initNew()` blank + `buildDefaultRequest()`.
    - `.../p2pcampaignpage/tabs/communication-tab.tsx` — master-flag Switch, debounced (~500ms) live audience count (Skeleton + opted-out copy), "Send test to me" button, `<InvitationHistoryPanel>` replacing the old single "Last invitation sent" row.
    - `.../p2pcampaignpage/editor-page.tsx` — audience-aware 3-branch Publish Dialog; Send/Resend floating pills (amber Resend) + History shortcut in Published/Active branches; Manual Send modal (disabled + hint at M=0); Manual Resend modal (cooldown line if `invitationSentAt` < 24h); large-blast (>1,000) type-to-confirm on Publish&Send / Send / Resend.
  - FE (created — 1): `.../p2pcampaignpage/components/invitation-history-panel.tsx` — history table (When · Triggered by · Type · Sent · Failed · Status; numeric cols right-aligned; shaped Skeletons; empty/error states) + row-click per-recipient drill-in Dialog via `GET_P2P_CAMPAIGN_INVITATION_RECIPIENTS`.
  - FE (barrel — 1): `.../p2pcampaignpage/components/index.ts` — export `invitation-history-panel`.
- **Wired GraphQL contract (BE must match exactly)**: mutations `sendP2PCampaignInvitation` / `resendP2PCampaignInvitation` / `sendP2PCampaignInvitationTest`, all `(p2PCampaignPageId: Int!)`; queries `p2PCampaignInvitationAudienceCount(p2PCampaignPageId: Int!, savedFilterId: Int, filterJson: String)` → `{ totalAudience, alreadyInvited, notYetInvited }`, `p2PCampaignInvitationHistory(p2PCampaignPageId: Int!)`, `p2PCampaignInvitationRecipients(emailSendJobId: Int!)`; `sendInvitationOnPublish` on the byId response DTO.
- **Verification**: `tsc --noEmit` clean in all §⑯-touched files. One pre-existing unrelated error remains (`PaymentMethodCode` duplicate export between `P2PCampaignPageDto.ts` and `CrowdFundingPageDto.ts`) — predates this session, not introduced here.
- **Deviations from spec**: FE implements BOTH "Publish without sending" (flag ON) and "Turn on & send" (flag OFF) by mutating the **persistent** `sendInvitationOnPublish` flag → `save()` → plain `publishP2PCampaignPage` (no new publish arg). Side effect: "Publish without sending" persistently turns the master flag OFF for all future republishes. **OPEN contract decision** for the BE owner: accept as-is (spec-conformant, zero BE surface) OR add a nullable one-time override arg to `PublishP2PCampaignPage(id, bool? sendInvitationOverride)` and rewire FE `publishWithFlag` to pass it without persisting. See ISSUE-9.
- **Known issues opened**: ISSUE-9 (publish escape-hatch mutates persistent flag — pending BE-owner decision).
- **Known issues closed**: None.
- **Next step**: user lands BE (column + migration OFF-for-all backfill + 3 mutations + 3 queries + per-run EmailSendJob counters). Then resolve ISSUE-9 A/B, run full-flow E2E, and flip #170 status back to COMPLETED.

---

## ⑭ SOURCE-2 FUNDING INTEGRATION & SETTINGS→CRM RELOCATION (planned 2026-06-29 — design only, do NOT build this pass)

**Source-2 context:** "Fundraising Campaigns" is one of the two MAIN Case-Management funding sources (with Grant). Menu reorg applied 2026-06-29 in `Pss2.0_Global_Menus_List.sql`: parent renamed **"P2P Fundraising" → "Fundraising Campaigns"** (code `CRM_P2PFUNDRAISING` unchanged), now CRM top-level order 8; children = Campaigns · **Campaign Pages (THIS screen)** · P2P Fundraisers · Crowdfunding · Crowdfunding Page. (Matching Gifts moved out to the Donation/Source-3 parent.)

**How Source-2 money funds a program (Option-A, locked):** campaign → linked **DonationPurpose** (already on this screen — field 7 "Linked Donation Purpose", stored via `Campaign.DonationPurposes` junction) → that purpose is added as a **ProgramFundingSource** (`DonationPurposeId`) on a Case-Mgmt Program → public donations roll up to the program's **Collected**. No new funding field needed here; the linked purpose IS the program bridge.

**⚠ G9 gap (design-only — do NOT build yet):** `fund.GlobalDonations` has no `DonationPurposeId` and `case.ProgramFundingTransaction` (the Collected ledger) has no `GlobalDonationId` — money raised through this page does NOT auto-roll-up into program Collected. Bridge = the §5 fork in memory `project_case_fund_accounting_redesign` (A: seed matched demo rows · B: real reconciliation roll-up). Decide before building.

**THIS SCREEN PHYSICALLY RELOCATES — Settings → CRM (planned, NOT executed this pass):**
- Admin setup route: `setting/publicpages/p2pcampaignpage` → **`crm/p2pfundraising/p2pcampaignpage`**. Public anonymous routes `(public)/p2p/{campaignSlug}`, `(public)/p2p/{campaignSlug}/{fundraiserSlug}`, `(public)/p2p/{campaignSlug}/start` are **UNCHANGED**.
- FE move (when executed): `app/[lang]/setting/publicpages/p2pcampaignpage/` → `app/[lang]/crm/p2pfundraising/p2pcampaignpage/`; `page-components/setting/publicpages/p2pcampaignpage/` → `page-components/crm/p2pfundraising/p2pcampaignpage/`; `presentation/pages/setting/publicpages/p2pcampaignpage.tsx` → `.../crm/p2pfundraising/p2pcampaignpage.tsx`; fix every internal import path.
- Update menu seed `MenuUrl` `setting/publicpages/p2pcampaignpage` → `crm/p2pfundraising/p2pcampaignpage` (currently kept as `setting/...` in the seed pending this move; menu parent already on `CRM_P2PFUNDRAISING`).
- **Inbound deep-links to update** (other screens that link here): `p2pcampaign.md` #15 (~10 refs: header "+ Create", drawer "Edit Campaign Setup", per-row Edit, communication-row Edit) and `p2pfundraiser.md` #135 (2 refs: row Edit + "Edit Page" override) — all currently target `setting/publicpages/p2pcampaignpage?...` and must change to `crm/p2pfundraising/p2pcampaignpage?...`.
- **Approval config update:** ParentMenu `SET_PUBLICPAGES` → `CRM_P2PFUNDRAISING`; ModuleCode `SETTING` → `CRM`; MenuUrl as above.

---

## ⑮ FUNDRAISER PAGE TEMPLATES + CHILD LIVE PREVIEW (planned 2026-07-02 — design only, do NOT build this pass)

**Goal.** The parent editor already lets an admin pick a **campaign-landing** page template (`PageTemplateId` → MasterData `P2PCAMPAIGNPAGETEMPLATE`; codes STANDARD/IMAGE_FOCUS/VIDEO_FOCUS/MINIMAL/FESTIVAL) and see it in the right-pane live preview via `ParentTemplateRenderer`. The **child fundraiser page** (`/p2p/{slug}/{fundraiserSlug}`) has NO equivalent — it is a single fixed 60/40 layout (`child-fundraiser-page.tsx`) that only inherits parent colours via `ThemeWrap`. This feature gives the child page its own template set, **configured on the PARENT** (parent owns child-page appearance; child inherits), plus a **fundraiser-surface live preview** so the admin can see the child layout while editing.

**Decision (locked 2026-07-02):** use a **NEW dedicated fundraiser template set** — MasterData `TypeCode='P2PFUNDRAISERPAGETEMPLATE'` — NOT a reuse of the campaign set (the campaign codes assume a hero/leaderboard landing; a personal fundraiser page has different needs: avatar/story/progress/donate). The template applies to **ALL child pages under the campaign**; a per-fundraiser override on `P2PFundraiser` (#135) is explicitly OUT OF SCOPE for this pass (future: `P2PFundraiser.FundraiserPageTemplateId` nullable override that falls back to the parent's).

### ⑮.1 Data model (mirror the existing `PageTemplateId` wiring exactly)
- **Entity** `P2PCampaignPage.cs`: add `public int? FundraiserPageTemplateId { get; set; }` (place beside `PageTemplateId`, Branding block) + nav `public virtual MasterData? FundraiserPageTemplate { get; set; }`.
- **EF config** `P2PCampaignPageConfiguration.cs`: `builder.HasOne(o => o.FundraiserPageTemplate).WithMany().HasForeignKey(o => o.FundraiserPageTemplateId).OnDelete(DeleteBehavior.Restrict);` (clone of the `PageTemplate` FK, lines 104–107).
- **Migration**: one new migration — add `FundraiserPageTemplateId integer NULL` + index + FK to `masterdatas`. (No date columns; UTC rule n/a.)
- **Seed** (new SQL): register MasterDataType `P2PFUNDRAISERPAGETEMPLATE` + rows. Proposed codes (`DataValue` / `DataName`):
  - `CLASSIC` / "Classic" — the EXISTING 60/40 story-left, progress+donate-right layout. **Default** (existing `child-fundraiser-page.tsx` becomes this variant → zero regression).
  - `SPOTLIGHT` / "Spotlight" — full-bleed cover hero, avatar overlap, progress bar under hero, donate CTA immediately below; story lower.
  - `STORY_FIRST` / "Story First" — single centered column, story leads, progress+donate as a sticky desktop rail.
  - `COMPACT` / "Compact" — progress + donate above the fold, story collapsed/"read more"; best for shared-on-mobile links.

### ⑮.2 Backend contract
- **RequestDto** (+1): `FundraiserPageTemplateId int?`.
- **ResponseDto** (+3): `FundraiserPageTemplateId int?`, `FundraiserPageTemplateCode string?` (= MasterData.DataValue — drives the renderer), `FundraiserPageTemplateName string?`.
- **EntityHelper.ApplyToP2PCampaignPage** (+1): write-through `FundraiserPageTemplateId`.
- **GetP2PCampaignPageById projection** (+3): resolve code+name from the MasterData batch (mirror how `PageTemplateCode`/`PageTemplateName` are resolved for `PageTemplateId`).
- **Public child query** (the handler feeding `/p2p/{slug}/{fundraiserSlug}` — `P2PCampaignPagePublicDto`): add `FundraiserPageTemplateCode` so the public dispatcher can pick a layout. Default `CLASSIC` when null.

### ⑮.3 Frontend
1. **Picker** — new `components/fundraiser-page-type-picker.tsx` (clone of `page-type-picker.tsx`): MasterData `TypeCode='P2PFUNDRAISERPAGETEMPLATE'`, static fallback const `P2P_FUNDRAISER_PAGE_TYPE_OPTIONS`; `LayoutSketch` variants tuned to the 4 child codes; writes `fundraiserPageTemplateId` + `fundraiserPageTemplateCode` to the store. Add as a new `SubSection title="Fundraiser Page Template" icon="ph:identification-card"` inside `branding-page-tab.tsx` (below "Page Type").
2. **DTO/GQL** — `P2PCampaignPageDto.ts`: add the 3 admin fields + `fundraiserPageTemplateCode` on `…PublicDto` + the new fallback options const. Add fields to the admin byId selection AND the public child selection. Mutation needs NO change (single typed input variable — new fields flow automatically, same as the invitation-field pass).
3. **Child template renderer** — NEW `public/p2pcampaignpage/templates/child-templates.tsx` exporting `ChildTemplateRenderer({ parent, fundraiser, tenantHostname })` that switches on `parent.fundraiserPageTemplateCode` (default `CLASSIC`). CLASSIC = the current `child-fundraiser-page.tsx` body. SPOTLIGHT/STORY_FIRST/COMPACT are new wrapper compositions that **REUSE the existing child-* sub-components** (`child-cover-profile`, `child-story`, `child-updates`, `child-team-section`, `child-progress-widget`, `donate-form`, `donor-wall`, `share-buttons`, `mobile-donate-bar`) — only the layout shells are new. Public route `app/(public)/p2p/[campaignSlug]/[fundraiserSlug]/page.tsx` renders `ChildTemplateRenderer` instead of `ChildFundraiserPage` directly.
4. **Fundraiser live preview** — extend `components/live-preview.tsx`: add a **Parent / Fundraiser** segmented toggle (store `previewSurface: 'parent' | 'fundraiser'`, default `'parent'`). When `'fundraiser'`, render `ChildTemplateRenderer` fed by a **synthetic sample fundraiser** DTO fabricated from editor state (name "Sample Fundraiser", demo story, demo raised/goal/donors/cover) — NO server round-trip, same 300ms debounce, same `zoom` + `pointer-events:none` framing. The template badge shows the fundraiser code when on that surface.

### ⑮.4 Gotchas / guardrails
- **Zero-regression rule:** `CLASSIC` MUST render byte-identical to today's child page; only extract, don't restyle it.
- **Reuse-or-create:** the 3 new layouts reuse every `child-*` sub-component; escalate only if a genuinely new shared block is needed. Tokens only (no hex/px), `ph:*` icons, shaped Skeletons, per repo UI-uniformity rules.
- **Preview needs a fabricated `P2PFundraiserPublicDto`** (no real fundraiser exists at edit time) — synthesize deterministically from editor state; never fetch.
- **Fallback chain:** renderer + BE default to `CLASSIC` when `FundraiserPageTemplateId`/code is null, so existing campaigns keep working with no data backfill.
- **Out of scope this pass:** per-fundraiser template override (#135), and any new child sub-components beyond the 4 layout shells.

### ⑮.5 Planned file manifest
- **BE:** `P2PCampaignPage.cs` · `P2PCampaignPageConfiguration.cs` · new Migration · `P2PCampaignPageSchemas.cs` · `P2PCampaignPageEntityHelper.cs` · `GetP2PCampaignPageById.cs` · public child query handler · new MasterData seed SQL.
- **FE:** `P2PCampaignPageDto.ts` · byId + public GQL queries · `components/fundraiser-page-type-picker.tsx` (NEW) · `tabs/branding-page-tab.tsx` · `public/p2pcampaignpage/templates/child-templates.tsx` (NEW) · `public/p2pcampaignpage/child-fundraiser-page.tsx` (→ CLASSIC) · `app/(public)/p2p/[campaignSlug]/[fundraiserSlug]/page.tsx` · `components/live-preview.tsx` · `p2pcampaignpage-store.ts` (`previewSurface`).

**Build trigger:** `/build-screen #170` (this Spec section is the blueprint). Do NOT build via `/continue-screen` — it adds a new FK + MasterData type + renderer variants (Spec change).

---

## ⑯ CAMPAIGN INVITATION — SEND/RESEND ACTIONS, PUBLISH GUARD & SEND HISTORY (planned 2026-07-02 — design only, do NOT build this pass)

> **Goal.** Turn the invisible "auto-blast on every publish" into a controlled donor-communication feature: a publish-time opt-in guard, two explicit manual actions (Send / Resend), full email-ops safeguards, and an auditable send history. Built on the EXISTING engine — this section adds control, visibility, and one column; it does NOT rebuild the send pipeline.

### ⑯.0 Current reality (verified 2026-07-02 — the starting point)
The bulk donor-invitation engine **already exists and works** — the earlier build-log note (#15 ISSUE-21 "dispatch UNBUILT") is **STALE**:
- [PublishP2PCampaignPage.cs:77-81](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/P2PCampaignPages/LifecycleCommands/PublishP2PCampaignPage.cs) — on publish, ALWAYS `backgroundJobClient.Enqueue<IP2PFundraiserEmailService>(s => s.SendCampaignInvitationAsync(id, …, true))`.
- `P2PFundraiserEmailService.SendCampaignInvitationAsync` (lines 95-230) — resolves donor audience via `EventDonorAudienceQuery.ResolveAsync(InvitationSavedFilterId, InvitationFilterJson)` (saved filter → inline JSON → all donors), DELTA-excludes already-invited contacts (rolling parent `JobCode = "P2PC-{id}-INVITE"`), sends `P2P_CAMPAIGN_INVITATION` (or campaign override), stamps `InvitationSentAt`.
- Editor already has an "Invitations" SubSection in [communication-tab.tsx:151-202](../../PSS_2.0_Frontend/src/presentation/components/page-components/crm/p2pfundraising/p2pcampaignpage/tabs/communication-tab.tsx): 2 template pickers, saved-filter picker, raw audience-JSON textarea, read-only "Last invitation sent".

**Two problems this section fixes:** (1) publish silently blasts — staff can't publish-to-test without spamming donors; (2) there is no manual trigger, no audience visibility, and no send history.

**Do NOT confuse with the single-fundraiser invite.** `SendInvitationEmailAsync` (template `P2P_FUNDRAISER_INVITE`, rolling code `P2PF-{id}-INVITE`, called from `InviteP2PFundraiser.cs` on screen #135) is a targeted one-person invite — OUT OF SCOPE, leave untouched. This section is only the **campaign donor blast** (`P2P_CAMPAIGN_INVITATION`, `P2PC-{id}-INVITE`).

### ⑯.1 Locked decisions (from user, 2026-07-02)
1. **Publish ≠ announce.** Decouple going-live from notifying donors.
2. **New master flag `SendInvitationOnPublish` (bool, NOT NULL, DEFAULT FALSE).** Governs ONLY the publish-time auto-blast. Manual Send/Resend are always available on a live page regardless of the flag. Default **OFF** (safe — an accidental blast is irreversible; a missed one is recoverable via manual Send).
3. **Two manual actions** (Published/Active only):
   - **Send** = delta — email only donors NOT yet invited (existing behavior).
   - **Resend** = force — email ALL donors in the audience again, including already-invited (new `forceResend` path that skips the dedup exclusion).
4. **Publish modal is audience-aware and offers an escape hatch** (see ⑯.4).
5. **All five email-ops guardrails included:** live audience count, send-test-to-myself, resend cooldown warning, large-blast type-to-confirm, and **send history** (who triggered · sent · failed · per-recipient drill-in).

### ⑯.2 Data model
- **NEW column** on `P2PCampaignPage`: `public bool SendInvitationOnPublish { get; set; }` — NOT NULL, default `false`. EF: `Property(p => p.SendInvitationOnPublish).HasDefaultValue(false)`. Migration adds the column with server default `false` (existing rows backfill to OFF → publishing them silently stops auto-blasting; that is the intended safer behavior, and it is a deliberate, documented change from today's always-send).
- **CONFIRMED (2026-07-02): backfill OFF for ALL existing campaigns — do NOT grandfather any to ON.** Rationale: every already-published campaign already fired its invite at first publish (`InvitationSentAt` is set), so under the old always-send behavior a republish would still skip those donors via delta dedup — i.e. OFF-for-all costs existing campaigns no real reach while removing the silent-blast hazard the whole feature exists to eliminate. The build MUST NOT add any per-row ON backfill.
- **No other new columns.** Audience (`InvitationSavedFilterId` / `InvitationFilterJson`), template (`InvitationEmailTemplateId`), and `InvitationSentAt` already exist.
- **Send-history storage = existing `notify.EmailSendJob` + `EmailSendQueue`** (no new tables). See ⑯.6 for the required job-model change (rolling-parent → one-job-per-run).

### ⑯.3 Backend contract
- **Entity/DTO:** add `SendInvitationOnPublish` to RequestDto + ResponseDto; write-through in `P2PCampaignPageEntityHelper.cs`; project in `GetP2PCampaignPageById.cs`.
- **Publish handler change** (`PublishP2PCampaignPage.cs`): the auto-enqueue at lines 77-81 becomes **conditional** — `if (entity.SendInvitationOnPublish) backgroundJobClient.Enqueue(... SendCampaignInvitationAsync(id, …, isSystem:true, forceResend:false))`. When the flag is off, publish stays silent. (Publish still succeeds regardless; the blast is best-effort as today.)
- **Service change** (`P2PFundraiserEmailService.SendCampaignInvitationAsync`): add `bool forceResend = false`. When `true`, SKIP the `alreadySentContactIds` exclusion (send to the full resolved audience). Everything else (template resolve, tracking, `InvitationSentAt` stamp) unchanged. See ⑯.6 for the per-run job change that rides along.
- **NEW mutations** (both `[CustomAuthorize(P2PCampaignPage, Modify)]`, gated to PageStatus ∈ {Published, Active}):
  - `SendP2PCampaignInvitation(int p2PCampaignPageId)` → enqueues `SendCampaignInvitationAsync(id, …, isSystem:false, forceResend:false)`.
  - `ResendP2PCampaignInvitation(int p2PCampaignPageId)` → enqueues `… forceResend:true`.
  - Both stamp `CreatedBy` = current staff onto the run's `EmailSendJob` (see ⑯.6) so history records "who triggered".
- **NEW query** `GetP2PCampaignInvitationAudienceCount(int p2PCampaignPageId, int? savedFilterId, string? filterJson)` → returns `{ totalAudience, alreadyInvited, notYetInvited }`. Uses the SAME `EventDonorAudienceQuery` resolver + the cross-run delta set (⑯.6) so **preview == actual**. Read permission. Powers both the live editor count and the confirmation modals. (Accepts the in-editor unsaved filter values so the count reflects what the admin is currently editing, mirroring `GetEventAnnouncementAudienceCount`.)
- **NEW query** `GetP2PCampaignInvitationHistory(int p2PCampaignPageId)` → list of run summaries from `EmailSendJob` where `JobCode == "P2PC-{id}-INVITE"`, newest first: `{ emailSendJobId, jobName (Send/Resend/Auto-on-publish), triggeredByName (CreatedBy → staff), triggeredAt (CreatedDate), totalEmailsSend, totalEmailsFailed, totalEmailsQueued, jobStatus }`.
- **(Optional, scope-flag) drill-in query** `GetP2PCampaignInvitationRecipients(int emailSendJobId)` → child `EmailSendQueue` rows: `{ toEmail, toName, status, skipReason, isBounced, isOpened, deliveredAt }` — leverages existing per-recipient webhook telemetry.
- **NEW mutation (guardrail)** `SendP2PCampaignInvitationTest(int p2PCampaignPageId)` → sends the resolved invitation template to the CURRENT staff user's email ONLY (no audience resolve, no tracking-as-blast, no `InvitationSentAt` stamp). Placeholder values are sample/preview data.

### ⑯.4 Frontend — confirmation matrix (the UX core)
All copy below is the contract; exact wording can be polished at build. Buttons in **bold** are primary.

**A. On Publish** (replaces the current generic publish `AlertDialog` at [editor-page.tsx:887-903](../../PSS_2.0_Frontend/src/presentation/components/page-components/crm/p2pfundraising/p2pcampaignpage/editor-page.tsx)). After publish-validation passes, resolve the audience count first, then branch:
- **Flag ON, notYetInvited N > 0** → "Publish & notify — about **N donors** will be emailed the moment this goes live. This can't be undone." → **Publish & Send** / *Publish without sending* / Cancel.
- **Flag ON, N = 0** (filter matches nobody / no primary emails) → "Publish — no eligible recipients. Your audience matches 0 donors with an email, so no invitation is sent." → **Publish** / Cancel. (Never imply a send that won't fire.)
- **Flag OFF** → "Publish quietly — *Email my audience* is OFF, so donors will **not** be notified. You can send the invitation manually anytime from this page." → **Publish quietly** / *Turn on & send* (flips the flag, saves, then publishes-and-sends) / Cancel. ← the "are you sure donors won't receive it?" guard.

**B. Manual Send** (floating pill, Published/Active): 
- notYetInvited M > 0 → "Send invitation — about **M** donors who haven't been invited yet. Already-invited donors are skipped." → **Send to M donors** / Cancel.
- M = 0 → Send button DISABLED with hint "All N donors already invited — use Resend to email them again."

**C. Manual Resend** (floating pill): amber/heavier styling — "Resend to everyone — emails **all N donors** again, including the M already invited. Use sparingly to avoid spam complaints." → **Resend to N donors** / Cancel. Subject to cooldown + large-blast guards below.

### ⑯.5 Frontend — guardrails & placement
- **Master flag switch** in `communication-tab.tsx` "Invitations" SubSection: "Email my donor audience when I publish" + helper. Bound to `page.sendInvitationOnPublish` via `setField`.
- **Live audience count** under the audience picker: "≈ 1,240 donors · 300 not yet invited" — debounced (~500ms) `GetP2PCampaignInvitationAudienceCount`, mirroring the event `announcement-audience-section.tsx` pattern. Note "opted-out donors are excluded automatically" (resolver already filters `DoNotEmail`).
- **Send-test button** in the SubSection: "Send test to me" → `SendP2PCampaignInvitationTest`, toast confirm.
- **Send / Resend buttons** in the floating action pill, in the `Published`/`Active` branches ([editor-page.tsx:797-817](../../PSS_2.0_Frontend/src/presentation/components/page-components/crm/p2pfundraising/p2pcampaignpage/editor-page.tsx)) alongside Unpublish/Preview.
- **Resend cooldown**: if `invitationSentAt` < 24h ago, Resend modal shows a friction line "You sent this N hours ago; resending may annoy donors." (warn, not block).
- **Large-blast type-to-confirm**: when the target count exceeds a threshold (e.g. 1,000), require typing the count (reuse the Archive dialog's type-to-confirm pattern already in `editor-page.tsx`) before the action fires. Applies to Publish&Send, Send, and Resend.
- **Send history panel** in the "Invitations" SubSection (or a drawer): table from `GetP2PCampaignInvitationHistory` — columns **When · Triggered by · Type · Sent · Failed · Status**; row click opens per-recipient drill-in (`GetP2PCampaignInvitationRecipients`) showing delivered/bounced/opened/failed. Empty state "No invitations sent yet". Replaces the single read-only "Last invitation sent" row with a real audit trail.

### ⑯.6 Job-model change (REQUIRED for history — the one non-trivial refactor)
Today `GetOrCreateRollingParentJobAsync` returns ONE reusable `EmailSendJob` per campaign (`JobCode = P2PC-{id}-INVITE`), and the counters (`TotalEmailsSend/Failed`) are never written — so distinct blasts are indistinguishable and un-auditable. Change **only the campaign-invitation stream** to **one `EmailSendJob` per invocation**:
- Each `SendCampaignInvitationAsync` run INSERTS a fresh `EmailSendJob` (do not get-or-create) with a STABLE `JobCode = "P2PC-{id}-INVITE"` (multiple rows share it — it is not unique-constrained; get-or-create is what made it singular), `JobName` = "Auto on publish" | "Send (delta)" | "Resend (all)", `IsSystem` = (auto ? true : false), `CreatedBy` = triggering staff (or page owner for the system/Hangfire auto path), `SavedFilterId` + `SavedFilterSnapshot` frozen, `EmailTemplateId` resolved, `SendJobTypeId` = TRIGGERED, `JobStatusId` = IN_PROGRESS → COMPLETED.
- After the send loop, WRITE the aggregate counters on that run's job: `TotalEmailsQueued`, `TotalEmailsSend`, `TotalEmailsFailed`, `LastExecutionStartedAt/EndedAt`, final `JobStatusId`.
- Children `EmailSendQueue` rows attach to THIS run's job (per-recipient status, `SkipReason`, bounce/open columns already exist).
- **Delta set** (`alreadySentContactIds`) = distinct `ContactId` from `EmailSendQueue` joined to ALL `EmailSendJob` rows where `JobCode == "P2PC-{id}-INVITE"` and status = SENT (union across runs), NOT just one parent. **Resend (`forceResend`) skips this entirely.**
- Leave `SendInvitationEmailAsync` (fundraiser single-invite, `P2PF-{id}-INVITE`) on its existing rolling-parent model — do not touch.

### ⑯.7 Gotchas & rules
- **Zero silent double-send**: if flag ON fires the auto-blast AND staff also click Send, the cross-run delta prevents re-sending to the same contacts. Verify after the job-model change.
- **`InvitationSentAt` stays the delta anchor + cooldown source** — still stamped per run (last write wins).
- **Anonymous / no-ContactId recipients** are NOT deduped (ContactId null) — same limitation as the event feature; acceptable (donor audience are known contacts).
- **DoNotEmail + no-primary-email donors** already excluded by `EventDonorAudienceQuery.Build` — surface this in the count copy so staff trust the number.
- **Malformed filter JSON = fail-OPEN (sends to all)** in the current resolver. Because default flag is OFF and the publish modal shows the resolved count before sending, this is acceptable; do NOT change resolver semantics here.
- **Tenant principal**: manual Send/Resend enqueue on Hangfire → `EstablishJobPrincipal` must run in-frame (already handled in the service). Pass the triggering `CreatedBy` through so history attributes correctly even under the synthetic principal.
- **UI-uniformity**: tokens only (no hex/px — amber for Resend via existing amber utility classes already used in this editor), `ph:*` icons (`ph:paper-plane-tilt` send, `ph:arrow-clockwise` resend, `ph:clock-counter-clockwise` history), shaped Skeletons for the count + history table, empty/error states.
- **Capability vs form-state**: manual Send/Resend visibility follows `capability` + PageStatus; they are ACTIONS (not the form Create/Save button), so the `formState.isValid` rule does not apply to them.

### ⑯.8 Planned file manifest
- **BE:** `P2PCampaignPage.cs` (+`SendInvitationOnPublish`) · `P2PCampaignPageConfiguration.cs` · new Migration · `P2PCampaignPageSchemas.cs` · `P2PCampaignPageEntityHelper.cs` · `GetP2PCampaignPageById.cs` · `PublishP2PCampaignPage.cs` (conditional enqueue) · `P2PFundraiserEmailService.cs` (+`forceResend`, per-run job model, counter writes) · NEW `SendP2PCampaignInvitation.cs` / `ResendP2PCampaignInvitation.cs` / `SendP2PCampaignInvitationTest.cs` commands · NEW `GetP2PCampaignInvitationAudienceCount.cs` / `GetP2PCampaignInvitationHistory.cs` (+ optional `…Recipients.cs`) queries · `P2PCampaignPageMutations.cs` + `P2PCampaignPageQueries.cs` (GraphQL registration).
- **FE:** `P2PCampaignPageDto.ts` (+`sendInvitationOnPublish`, history/count types) · donation GQL mutations + queries files · `tabs/communication-tab.tsx` (flag switch, live count, send-test, history panel) · `editor-page.tsx` (audience-aware publish modal, Send/Resend buttons + their modals, cooldown + type-to-confirm) · `p2pcampaignpage-store.ts` (new field) · optional `components/invitation-history-panel.tsx` (NEW) + `components/send-invitation-modal.tsx` (NEW).
- **Docs:** close #15 ISSUE-21 (mark the dispatch engine BUILT); this section supersedes it.

**Build trigger:** `/build-screen #170` (this Spec section is the blueprint). Do NOT build via `/continue-screen` — it adds a new column + mutations + queries + a workflow-gate + a job-model change (Spec change).
