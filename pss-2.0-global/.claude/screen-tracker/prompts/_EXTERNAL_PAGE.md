# Screen Prompt Template — EXTERNAL_PAGE (v1)

> For admin **setup screens that publish a public-facing page** consumed by anonymous visitors
> (donors, supporters, backers) who transact through it.
> Covers online donation pages, peer-to-peer fundraising, and crowdfunding campaigns.
> Canonical reference: **TBD** — first EXTERNAL_PAGE screen sets the convention per sub-type.
>
> Use this when the mockup is one of:
> - A **single online donation page** with amount chips / recurring options / payment connect / donor-field config + public URL — `DONATION_PAGE`
> - A **peer-to-peer parent campaign** where supporters create their own child fundraiser pages
>   (registration / approval / personal goals / team option / leaderboard preview) — `P2P_FUNDRAISER`
> - A **crowdfunding campaign** with goal + deadline + tiered rewards + story + updates posts +
>   backers count + share buttons — `CROWDFUND`
>
> Do NOT use for:
> - Internal admin CRUD lists with no public face (use `_MASTER_GRID.md` / `_FLOW.md`)
> - Internal multi-section configuration with no public output (use `_CONFIG.md`)
> - Email / receipt templates that aren't a hosted page (use `_FLOW.md` if list, `_CONFIG.md` if singleton)
> - Reports of donations collected (use `_REPORT.md`)
>
> ---
>
> ### 🧠 Each EXTERNAL_PAGE screen is UNIQUE — the developer owns the design
>
> **The patterns below are scaffolding, not a frozen spec.** A donation page, a P2P parent
> campaign, and a crowdfunding campaign share infrastructure (slug, branding, payment connect,
> publish lifecycle, OG tags) but diverge sharply in donor flow / supporter onboarding / reward
> mechanics, so:
>
> 1. **Read the business context first** — who is the audience (donors? supporters? backers?),
>    what are they being asked to do, what's the conversion funnel, what's the success metric?
>    The answer shapes the §⑥ blueprint, the public-page composition, and the lifecycle.
> 2. **Pick the sub-type that fits** — `DONATION_PAGE` / `P2P_FUNDRAISER` / `CROWDFUND`. Stamp
>    in §⑤. If the mockup is a hybrid (e.g. a P2P campaign that also has reward tiers), pick the
>    dominant pattern and note the cross-cutting elements in §⑫.
> 3. **Two distinct UIs always** — every EXTERNAL_PAGE has a SETUP UI (admin) and a PUBLIC UI
>    (anonymous visitor). They are different routes, different role gates (BUSINESSADMIN-only vs
>    anonymous), and different render trees. The setup screen is what this prompt builds; the
>    public page is what the setup publishes.
> 4. **Lifecycle matters** — Draft → Published → Active → Closed (and optionally Archived). The
>    UI must reflect each state: only Active pages accept donations; Draft pages are accessible
>    by preview-token only; Closed pages render a "campaign closed" placeholder. The lifecycle
>    is enforced at the BE — never by FE flag.
> 5. **Public-side concerns are first-class** — slug uniqueness within tenant, OG meta tags,
>    canonical URL, CSP / no-tracking compliance, payment-gateway PCI scope, anti-fraud throttle
>    on donate button, GDPR consent. None of these are afterthoughts.
> 6. **Document deviations** — if the developer departs from the prompt's tab list / public-page
>    composition / lifecycle states based on business context, log in §⑫ ISSUE entry with why.

---

## Template

```markdown
---
screen: {EntityName}
registry_id: {#}
module: {Module Name}
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: EXTERNAL_PAGE
external_page_subtype: {DONATION_PAGE | P2P_FUNDRAISER | CROWDFUND}
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND)
- [x] Business context read (audience, conversion intent, lifecycle, payment posture)
- [x] Setup vs Public route split identified (admin setup route + anonymous public route)
- [x] Slug strategy chosen (auto from name / custom / both with uniqueness rule)
- [x] Lifecycle states confirmed (Draft / Published / Active / Closed / Archived)
- [x] Payment gateway integration scope confirmed (existing connect / SERVICE_PLACEHOLDER)
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed (setup files + public files separately)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (page purpose + audience + conversion + lifecycle)
- [ ] Solution Resolution complete (sub-type confirmed, slug strategy, lifecycle, payment scope)
- [ ] UX Design finalized (setup tabs/sections + public-page composition)
- [ ] User Approval received
- [ ] Backend code generated          ← skip if FE_ONLY
- [ ] Backend wiring complete         ← skip if FE_ONLY
- [ ] Frontend (admin setup) code generated         ← skip if BE_ONLY
- [ ] Frontend (public page) code generated         ← skip if BE_ONLY
- [ ] Frontend wiring complete        ← skip if BE_ONLY
- [ ] DB Seed script generated (sample published page for E2E)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — admin setup loads at correct route; public page loads at `/p/{slug}` (or equivalent)
- [ ] **Sub-type-specific checks** (pick the matching block):
  - DONATION_PAGE:
    - [ ] Setup tabs render in order; each tab persists via Save (or autosave)
    - [ ] Slug auto-generated from name; uniqueness enforced per tenant
    - [ ] Amount chips configurable; "custom amount" toggle works
    - [ ] Recurring frequencies togglable; recurring fields validated
    - [ ] Donor-field config (required/optional/hidden) reflected on public page
    - [ ] Payment method list reorderable; at least one method required to publish
    - [ ] Live preview reflects current setup state (mobile + desktop toggle)
    - [ ] Publish transitions Draft → Active; URL becomes live; OG tags present
    - [ ] Anonymous visitor can complete a donation end-to-end (real or SERVICE_PLACEHOLDER gateway)
    - [ ] Email receipt fires after donation (real or SERVICE_PLACEHOLDER)
  - P2P_FUNDRAISER:
    - [ ] Parent campaign setup persists (basic info / fundraiser settings / donation settings / branding / communication tabs)
    - [ ] Fundraiser registration toggle gates the public "Start Fundraiser" CTA
    - [ ] Approval workflow (auto-approve / admin-approve) routes new fundraisers correctly
    - [ ] Team fundraising option creates parent-team relationship
    - [ ] Personal goal default + min/max validated
    - [ ] Public parent page shows leaderboard + active fundraisers + "Start Fundraiser" CTA
    - [ ] Supporter signup creates a child fundraiser page (Draft until approved if approval ON)
    - [ ] Child fundraiser page accepts donations; totals roll up to parent campaign
    - [ ] Communication templates (welcome / approved / rejected / reminder) editable + sendable
  - CROWDFUND:
    - [ ] Goal amount + deadline mandatory; "stretch goal" optional
    - [ ] Reward tiers add/edit/reorder; each tier has minimum amount, perks, inventory limit
    - [ ] Story sections (about / impact / gallery / video) edit and render in public order
    - [ ] Updates post composer (rich text + image) publishes timestamped updates
    - [ ] Backer count + recent-donor list + social proof render on public page
    - [ ] Progress bar + "{N}% funded" + "{X} days left" auto-update
    - [ ] Share buttons (FB / Twitter / WhatsApp / LinkedIn / copy-link) wired with OG meta
    - [ ] Goal-met state and deadline-passed state render correctly on public page
    - [ ] Backer fulfillment list (for inventory-limited rewards) tracks pledges
- [ ] Empty / loading / error states render on both setup and public surfaces
- [ ] DB Seed — admin menu visible at correct parent; public route accessible

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage for setup AND public page

Screen: {EntityName}
Module: {ModuleName}
Schema: {db_schema}
Group: {BackendGroupName}

Business: {Rich description — 6-8 sentences covering:
  - WHAT this external page enables (collect donations to a cause? rally peer fundraisers?
    fund a defined project with rewards?) and the headline conversion goal.
  - WHO sets it up (BUSINESSADMIN / Module admin / Campaign owner) vs WHO consumes it
    (anonymous donors / supporters becoming fundraisers / backers pledging for rewards).
  - WHAT is the LIFECYCLE — when does the page open, when does it close, what triggers
    state transitions (admin click / scheduled date / goal reached).
  - WHAT BREAKS if mis-set — risks include receipts not generated, donors charged but no
    record stored, fundraiser pages going live without admin approval, reward tier inventory
    oversold, expired payment connect leaving "Donate" button dead, missing privacy/consent.
  - HOW it relates to other screens — receipts, donations, contact-creation, dashboard
    aggregations, communication templates, payment gateway config.
  - WHAT'S unique about this page's UX vs. a generic CMS landing page (e.g. P2P needs the
    "Start Fundraiser" flow that creates a child page; crowdfund needs reward inventory
    decrement on backing; donation page needs recurring schedule creation).}

> **Why this section is heavier than other types**: EXTERNAL_PAGE has TWO surfaces (admin
> setup + anonymous public) and a lifecycle that spans both. The richer §① is, the better
> the developer can design §⑥ for both surfaces and the state transitions between them.

---

## ② Storage & Source Model

> **Consumer**: BA Agent → Backend Developer
>
> EXTERNAL_PAGE always has a primary entity (the page record) plus optional child entities
> (reward tiers, fundraisers, posts, supporters). Donations themselves persist via the
> existing donation pipeline — this page is a **source/funnel**, not the donation store.

**Primary Entity** (REQUIRED): the published-page record itself.

| Pattern | Use when | Cardinality |
|---------|----------|-------------|
| `single-page-record` | One row per page (donation page, parent P2P campaign, crowdfund campaign) | N rows × M tenants |
| `parent-with-children` | Parent + child rows (e.g. P2P parent campaign + fundraiser child pages, crowdfund + reward tiers + posts) | 1 parent + many children |

**Stamp**: `{single-page-record | parent-with-children}`

### Tables

> Audit columns omitted (inherited from `Entity` base). CompanyId always present (tenant scope).

**Primary table**: `{schema}."{TableName}"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| {EntityName}Id | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (NOT a public-form field) |
| Name | string | 200 | YES | — | Internal label + default for public title |
| Slug | string | 100 | YES | — | URL slug; unique per tenant; lower-kebab; auto-from-Name on create |
| Status | string | 20 | YES | — | Draft / Published / Active / Closed / Archived |
| PublishedAt | DateTime? | — | NO | — | Set on Draft→Published transition |
| GoalAmount | decimal? | — | (CROWDFUND yes) | — | Funding target |
| StartDate / EndDate | DateTime? | — | (CROWDFUND end yes) | — | Active window |
| HeroImage / LogoImage | string | 500 | NO | — | Public branding URLs |
| ThemeJson | jsonb | — | NO | — | Color / font / layout overrides |
| StoryJson | jsonb | — | NO | — | Rich-text story sections |
| OgTitle / OgDescription / OgImage | string | — | NO | — | Social-share meta |
| ReceiptTemplateId | int? | — | NO | finance.ReceiptTemplates | Link to receipt template |
| PaymentMethodsJson | jsonb | — | YES | — | Ordered list of enabled payment methods |
| DonorFieldsJson | jsonb | — | YES | — | Field config (required/optional/hidden per donor field) |
| MetaJson | jsonb | — | NO | — | Sub-type specific overrides — see below |
| ... | ... | ... | ... | ... | ... |

**Slug uniqueness**:
- Unique index on `(CompanyId, Slug)` — slug must be unique within tenant
- Reserved slug list (`admin`, `api`, `assets`, `auth`) rejected by validator

**Status transition rules** (enforced at BE, not FE):
- Draft → Published only when validation passes (slug set, ≥1 payment method, OG image set, etc.)
- Published → Active automatic at StartDate (or immediate if no StartDate)
- Active → Closed automatic at EndDate (or admin-triggered)
- Any → Archived admin-triggered (soft-delete; preserves donations FK)

**Sub-type-specific child tables** (parent-with-children pattern):

| Sub-type | Child Table | Relationship | Key Fields |
|----------|-------------|--------------|------------|
| P2P_FUNDRAISER | {Schema}.Fundraisers | 1 parent → N child fundraiser pages | FundraiserId, ParentCampaignId, OwnerContactId, PersonalGoal, Status (Draft/Pending/Approved/Rejected) |
| P2P_FUNDRAISER | {Schema}.Teams | 1 parent → N teams | TeamId, ParentCampaignId, TeamName, CaptainContactId |
| CROWDFUND | {Schema}.RewardTiers | 1 parent → N tiers | RewardTierId, CampaignId, MinimumAmount, Perks, InventoryLimit, ClaimedCount, DisplayOrder |
| CROWDFUND | {Schema}.Updates | 1 parent → N posts | UpdateId, CampaignId, Title, Body, PublishedAt |
| CROWDFUND / P2P | {Schema}.PageVisits (optional analytics) | append-only | VisitId, PageId, VisitedAt, ReferrerCode, ConvertedDonationId |

**Donation linkage** (NOT in this table — referenced from `finance.Donations`):
- Donation has FK back to `{EntityName}Id` (and `FundraiserId` / `RewardTierId` if applicable)
- Aggregations (total raised, backer count, leaderboard rank) computed by query — never cached on the page row

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ReceiptTemplateId | ReceiptTemplate | Base.Domain/Models/{Group}Models/ReceiptTemplate.cs | GetAllReceiptTemplateList | TemplateName | ReceiptTemplateResponseDto |
| OwnerContactId (P2P fundraiser) | Contact | Base.Domain/Models/CrmModels/Contact.cs | GetAllContactList | ContactName | ContactResponseDto |
| ... | ... | ... | ... | ... | ... |

**Aggregation sources** (not strictly FK — used for public-page rollups):
| Source | Aggregate | Used In | Filter |
|--------|-----------|---------|--------|
| Donations | SUM(NetAmount) GROUP BY {EntityName}Id | Progress bar, "% funded" | Status = 'Completed' |
| Donations | COUNT(DISTINCT DonorContactId) | "{N} backers" / "{N} supporters" | Status = 'Completed' |
| Donations | TOP 10 ORDER BY NetAmount DESC | Leaderboard (P2P) | Status = 'Completed', GROUP BY FundraiserId |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Slug Rules:**
- Auto-generate from `Name` on create — lowercase, replace whitespace with `-`, strip non-alphanumeric (keep `-`)
- User can override with custom slug; same normalization applied
- Reserved slugs rejected (admin / api / assets / auth / public / preview / login / signup / oauth)
- Uniqueness enforced per tenant — same slug across tenants is OK (slug + CompanyId composite)
- Slug immutable once Status = Active and there are donations attached (link rot prevention)

**Lifecycle Rules:**
| State | Set by | Public route behavior | Donate button |
|-------|--------|----------------------|---------------|
| Draft | Initial create | 404 to public; preview-token grants temporary access | Disabled / not rendered |
| Published | Admin "Publish" action | Renders publicly | Live (if within Active window) |
| Active | Auto at StartDate (or = Published if no StartDate) | Renders publicly | Live |
| Closed | Auto at EndDate, or admin "Close" | Renders publicly with "Campaign closed" banner | Disabled |
| Archived | Admin "Archive" | 410 Gone (or redirect to org default) | N/A |

**Required-to-Publish Validation:**
- Name set (non-empty)
- Slug set + unique
- ≥ 1 payment method enabled
- OG title + OG image set (for share preview)
- (CROWDFUND) Goal amount > 0 + EndDate set
- (P2P_FUNDRAISER) Approval mode selected (auto / manual) + at least 1 communication template
- (DONATION_PAGE) ≥ 1 amount option (chip or "custom" enabled)

**Conditional Rules:**
- If `RecurringEnabled = true`: at least one frequency (monthly/quarterly/annually) must be selected
- If `TeamFundraisingEnabled = true` (P2P): show team-creation UX on public page
- If `RewardTierMaxClaim < ClaimedCount`: tier shown as "Sold out" on public, hidden from new backers
- If `ApprovalMode = manual` (P2P): new fundraiser pages enter `Pending` and trigger admin notification

**Sensitive / Security-Critical Fields:**
| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| Payment gateway API keys | secret | not shown — managed in CONFIG screen, referenced by id only | — (referenced) | log on rotate |
| Donor PII captured on public form | regulatory | server-side only; never logged in plain text | Encrypt at rest where required | log access |
| Anti-fraud markers (IP, user-agent, velocity) | operational | not on public; visible to admin only | append-only | retain per policy |

**Public-form Hardening (anonymous-route concerns):**
- Rate-limit donate-button POST per IP + slug (e.g. 5 attempts / minute)
- CSRF token required on form submit (token issued from public-page render)
- Honeypot field (hidden, must be empty) to deter bots
- Recaptcha v3 score check before payment-gateway hand-off (SERVICE_PLACEHOLDER if not configured)
- All input field-validated server-side (never trust public client)
- CSP headers set on public route (script-src, style-src, frame-src for payment iframe)

**Dangerous Actions** (require confirm + audit):
| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Publish | Page goes live; URL becomes shareable | "Publishing makes this page public. Confirm?" | log "page published" with version snapshot |
| Close Early | Active → Closed before EndDate; new donations rejected | "Close campaign now? Existing donations stay." | log + email campaign owner |
| Archive | Soft-delete; URL returns 410 | "Archived pages cannot be restored. Confirm?" | log |
| Reset Branding | Wipe theme/branding back to defaults | type-name confirm | log |

**Role Gating:**
| Role | Setup access | Publish access | Notes |
|------|-------------|----------------|-------|
| BUSINESSADMIN | full | yes | full lifecycle |
| Campaign owner (e.g. STAFFADMIN with assignment) | edit only own pages | request-publish (admin approves) | optional pattern |
| Anonymous public | no setup access | — | only sees Active public route |

**Workflow** (cross-page when applicable — P2P sub-type):
- Parent campaign Status governs whether public can "Start Fundraiser"
- New fundraiser created (anonymous → contact upserted) → child page Status = `Draft` if auto-approve, `Pending` if manual
- `Pending` → BUSINESSADMIN sees in moderation queue → Approve → child page Status = `Active` + welcome email sent
- Reject → child page Status = `Rejected` + rejection email + reason logged

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: EXTERNAL_PAGE
**External-Page Sub-type**: `{DONATION_PAGE | P2P_FUNDRAISER | CROWDFUND}`
**Storage Pattern**: `{single-page-record | parent-with-children}`
**Slug Strategy** (REQUIRED — stamp one):

| Slug Strategy | When to pick |
|---------------|--------------|
| `auto-from-name` | Slug is always derived from Name; user can't override |
| `custom-with-fallback` | User may set custom slug; falls back to auto-from-Name |
| `tenant-prefixed` | Public URL is `{tenant-slug}/{page-slug}` |

**Lifecycle Set** (REQUIRED — stamp the states this page uses):
- `Draft / Published / Active / Closed` (default)
- `Draft / Published / Active / Closed / Archived` (with archive)
- `Draft / Pending / Active / Closed` (custom — when admin approval gates publish)

**Save Model** (REQUIRED — stamp one):

| Save Model | When to pick |
|------------|--------------|
| `save-per-tab` | Tabbed setup (P2P / Crowdfund) — each tab has its own Save + Discard |
| `autosave-with-publish` | Donation page setup — saves silently as Draft; explicit Publish promotes |
| `save-all` | Simple single-page setup with one footer Save |

**Public Render Strategy** (REQUIRED — stamp one):

| Strategy | When to pick |
|----------|--------------|
| `ssr` | SEO-critical (donation page indexed by Google); Next.js `generateStaticParams` + ISR |
| `ssr-edge` | High-traffic crowdfund — render at edge for low TTFB |
| `csr-after-shell` | Acceptable when SEO not critical; faster setup |

**Reason**: {1-2 sentences — why this sub-type + slug strategy + render strategy fit §①.}

**Backend Patterns Required:**

For **DONATION_PAGE**:
- [x] Get{Entity}ById query (for setup) — tenant-scoped
- [x] GetAll{Entity}List query (for setup list view)
- [x] Get{Entity}BySlug query (for public route) — anonymous, status-gated
- [x] Get{Entity}Stats query — totalRaised, donorCount, recentDonors
- [x] Create{Entity} mutation (defaults to Draft)
- [x] Update{Entity} mutation
- [x] Publish{Entity} / Unpublish{Entity} / Close{Entity} / Archive{Entity} mutations (lifecycle)
- [x] Validate{Entity}ForPublish query — returns missing-fields list
- [x] Slug uniqueness validator
- [x] Tenant scoping (CompanyId from HttpContext) — anonymous public uses CompanyId from slug-resolution
- [x] Anti-fraud throttle on public submit endpoint
- [ ] Donation persistence handled by existing `finance.Donations` pipeline — page setup just configures the funnel

For **P2P_FUNDRAISER** (parent-with-children):
- [x] Get{Entity} / GetAll / GetBySlug / Get{Entity}Stats (parent campaign)
- [x] CRUD on parent campaign with lifecycle commands
- [x] GetAllFundraisersByCampaign query — paginated (paged for public leaderboard)
- [x] CreateFundraiser mutation (anonymous-callable on public route — upserts Contact)
- [x] ApproveFundraiser / RejectFundraiser mutations (admin)
- [x] Get{Entity}Leaderboard query — top-N fundraisers by amount raised
- [x] Communication-template send mutations (welcome / approved / rejected / reminder)
- [x] Team CRUD (if `TeamFundraisingEnabled`)

For **CROWDFUND** (parent-with-children):
- [x] Get{Entity} / GetAll / GetBySlug / Get{Entity}Stats (campaign)
- [x] CRUD on campaign with lifecycle commands
- [x] GetAllRewardTiersByCampaign / Create / Update / Delete / Reorder reward tiers
- [x] GetAllUpdatesByCampaign / Create / Update / Delete update posts
- [x] BackRewardTier mutation (anonymous-callable; decrements inventory atomically)
- [x] Inventory race-condition guard (DB-level decrement with `WHERE ClaimedCount < InventoryLimit`)
- [x] Get{Entity}Backers query — paginated, with privacy filter (anonymous donors hidden)

**Frontend Patterns Required:**

For **all sub-types** — TWO render trees:
- [x] Admin setup page — sectioned/tabbed editor + live preview pane
- [x] Public page — anonymous route under `/p/{slug}` (or tenant-prefixed) using SSR for SEO
- [x] Setup list view (when there are multiple pages of the sub-type) — grid/cards listing existing pages with status badges

For **DONATION_PAGE**:
- [x] Setup: split-pane (editor left + live preview right) with mobile/desktop preview toggle
- [x] Editor sections: Basic Info / Amounts & Recurring / Payment Methods / Donor Fields / Branding / Receipt / SEO
- [x] Public: hero + donation form + amount chips + recurring toggle + payment hand-off + thank-you state

For **P2P_FUNDRAISER**:
- [x] Setup: tabbed (Basic Info / Fundraiser Settings / Donation Settings / Branding & Page / Communication)
- [x] Setup includes leaderboard preview + active fundraisers list
- [x] Public parent: hero + campaign story + leaderboard + active fundraisers grid + "Start Fundraiser" CTA
- [x] Public child fundraiser page: own slug under `/p/{parent}/{fundraiser}` — personal hero + personal goal + donate flow
- [x] Anonymous "Start Fundraiser" wizard — name/email → upsert contact → create child page in Pending/Active

For **CROWDFUND**:
- [x] Setup: tabs (Basic Info / Story / Rewards / Updates / Branding / SEO)
- [x] Reward tier editor with reorder + inventory limit + perks rich-text
- [x] Update post composer (rich text + image)
- [x] Public: hero + progress bar + "% funded / X days left" + story + reward tier list (with claim count) + updates feed + backers list + share buttons

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: Each EXTERNAL_PAGE has TWO surfaces (admin setup + public). Fill in BOTH for the
> matching sub-type block. Delete the non-matching sub-type blocks before writing the screen prompt.

### 🎨 Visual Treatment Rules (apply to ALL sub-types)

> EXTERNAL_PAGE has the highest brand-stakes of any screen type — the public page IS a marketing
> asset that donors / supporters / backers see. Generic templated layouts make the org look low-trust.

1. **Public page is brand-driven, not chrome-driven** — hero image is large and primary, palette
   pulled from tenant branding, typography distinct from admin app. Don't reuse the admin shell.
2. **Admin setup mirrors what the public will see** — every meaningful edit is reflected in the live
   preview pane (no "save and check" round-trips for things like color or amount chips).
3. **Mobile preview is mandatory in setup** — most public visitors are on mobile. Preview toggle
   defaults to mobile width.
4. **Lifecycle state is visually clear** — status badge (Draft / Published / Active / Closed) at
   top-right of setup; banner on public page when Closed; preview-token badge when previewing Draft.
5. **Donate / "Start Fundraiser" / "Back this" CTAs are visually dominant** — primary brand color,
   sized to prompt action, sticky on mobile scroll. Don't lose them in card chrome.
6. **Trust signals are first-class** — security/SSL indicator, payment-method logos, "tax-deductible"
   line, contact info, privacy-policy link. They live in fixed slots (footer + near CTA), not buried.
7. **Empty / pre-publish states are honest** — Draft preview shows the page exactly as donors will
   see it, with a "PREVIEW — NOT YET LIVE" banner overlay. Don't hide pre-publish problems behind
   a stub.
8. **Vary card chrome between sub-types** — donation page, P2P parent, and crowdfund campaign
   look different on the public side. Don't use the same hero / card layout for all three.

**Anti-patterns to refuse**:
- Admin chrome bleeding into public route (sidebar visible to anonymous donors)
- "Save and refresh to preview" — preview must update live with every edit
- Status only shown by a tiny gray label; no banner on Draft preview
- Donate CTA below the fold or styled as a tertiary button
- Public page with admin breadcrumbs / admin dropdowns visible
- Reward tier "Sold out" hidden from new backers (must remain visible but disabled)
- P2P leaderboard where ranks aren't visually distinguished from regular fundraiser cards
- Generic "Lorem ipsum" placeholder content shipped because story sections weren't designed
- Single hero image stretched to full width with no responsive crop

---

### 🅰️ Block A — DONATION_PAGE (fill if sub-type = DONATION_PAGE)

#### A.1 — Admin Setup UI (split-pane: editor left + live preview right)

**Page Layout:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ {Page Name}                              Status: ●Draft  [Preview] [Publish]│
├──────────────────────────────────────────┬──────────────────────────────────┤
│ EDITOR                                   │ LIVE PREVIEW                     │
│                                          │ [Mobile ▼] [Desktop]             │
│  ┌──────────────────────────────────┐   │ ┌──────────────────────────────┐│
│  │ Basic Info                       │   │ │ ┌──────────────────────────┐ ││
│  │  • Name, Slug, Description       │   │ │ │      Hero Image          │ ││
│  │  • Public URL: /p/{slug}  [copy] │   │ │ ├──────────────────────────┤ ││
│  └──────────────────────────────────┘   │ │ │ Title                    │ ││
│  ┌──────────────────────────────────┐   │ │ │ Description              │ ││
│  │ Amounts & Recurring              │   │ │ │                          │ ││
│  │  Chips: [10] [25] [50] [100] [+] │   │ │ │ ◯ $10  ◯ $25  ●$50  ◯Custom││ │
│  │  ☑ Allow custom amount           │   │ │ │ ☐ Make it monthly        │ ││
│  │  ☑ Recurring: [M] [Q] [A]        │   │ │ │ [DONATE NOW]             │ ││
│  └──────────────────────────────────┘   │ │ └──────────────────────────┘ ││
│  ┌──────────────────────────────────┐   │ │                              ││
│  │ Payment Methods (drag to order)  │   │ │ Trust signals:               ││
│  │  ⋮ Card    ⋮ PayPal   ⋮ ACH      │   │ │ 🔒 Secure  💳 Card  ✉ Receipt││
│  └──────────────────────────────────┘   │ └──────────────────────────────┘│
│  ┌──────────────────────────────────┐   │                                  │
│  │ Donor Fields                     │   │                                  │
│  │  Field          Required Hidden  │   │                                  │
│  │  Email           [✓]    [ ]      │   │                                  │
│  │  Name            [✓]    [ ]      │   │                                  │
│  │  Phone           [ ]    [ ]      │   │                                  │
│  └──────────────────────────────────┘   │                                  │
│  ┌──────────────────────────────────┐   │                                  │
│  │ Branding (logo, colors, hero)    │   │                                  │
│  └──────────────────────────────────┘   │                                  │
│  ┌──────────────────────────────────┐   │                                  │
│  │ Receipt & Thank-You              │   │                                  │
│  └──────────────────────────────────┘   │                                  │
│  ┌──────────────────────────────────┐   │                                  │
│  │ SEO & Social Share               │   │                                  │
│  └──────────────────────────────────┘   │                                  │
└──────────────────────────────────────────┴──────────────────────────────────┘
```

**Editor Sections** (one row per section — order matches preview render order):

| # | Section | Icon (Phosphor) | Save Model | Notes |
|---|---------|-----------------|------------|-------|
| 1 | Basic Info | `ph:info` | autosave | Name, Slug (with copy button), Description, Internal label |
| 2 | Amounts & Recurring | `ph:hand-coins` | autosave | Amount chips editor, custom-amount toggle, recurring frequencies |
| 3 | Payment Methods | `ph:credit-card` | autosave | Drag-reorder list of enabled methods; method config (live keys come from CONFIG screen) |
| 4 | Donor Fields | `ph:user` | autosave | Per-field config: required / optional / hidden |
| 5 | Branding | `ph:palette` | autosave | Logo upload, hero image, primary color, secondary color, font family |
| 6 | Receipt & Thank-You | `ph:envelope-simple` | autosave | Receipt template select, thank-you message, redirect URL |
| 7 | SEO & Social | `ph:share-network` | autosave | OG title, OG description, OG image, slug, robots indexable toggle |

**Live Preview Behavior:**
- Updates on every keystroke (debounced 300ms)
- Mobile / Desktop toggle changes preview viewport width
- "Open in new tab" button on Draft → uses preview-token auth
- Preview shows "PREVIEW — NOT YET LIVE" banner overlay when Status = Draft

**Page Actions:**
| Action | Position | Style | Confirmation |
|--------|----------|-------|--------------|
| Publish | top-right | primary | "Publishing makes this page public at /p/{slug}." |
| Unpublish | top-right (when Active) | secondary | "Donors will see a 'campaign closed' page." |
| Close Early | overflow menu | destructive | "Close now? Existing donations stay." |
| Archive | overflow menu | destructive | type-name confirm |
| Test Donation | top-right | tertiary | Opens public page in new tab with `?test=1` flag |

#### A.2 — Public Page (anonymous route at `/p/{slug}`)

**Page Layout** (mobile-first; donate form sticky on mobile):

```
┌────────────────────────────────────────────────────────────┐
│            [Hero Image — full bleed]                       │
│                                                            │
│            {Page Title}                                    │
│            {Subtitle / Description}                        │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Make a Donation                                       │ │
│  │                                                       │ │
│  │ ◯ $10  ◯ $25  ● $50  ◯ $100  ◯ Custom $___          │ │
│  │ ☐ Make this a monthly donation                        │ │
│  │                                                       │ │
│  │ [Donor fields per config]                             │ │
│  │                                                       │ │
│  │ [DONATE NOW $50]                                      │ │
│  │                                                       │ │
│  │ 🔒 Secure   💳 Cards / PayPal   ✉ Receipt by email    │ │
│  └──────────────────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────────┤
│  Story / Impact (rich text from Description / story json)  │
├────────────────────────────────────────────────────────────┤
│  Footer: Privacy / Tax-deductible note / Contact / Logo    │
└────────────────────────────────────────────────────────────┘
```

**Public-route behavior:**
- SSR with revalidation (campaign metadata caches 60s; OG tags pre-rendered)
- Anonymous-allowed route (no auth gate); CSP headers strict
- CSRF token issued in initial render; required on submit
- Honeypot field hidden in form
- On submit: client-side gateway tokenization → server creates donation → redirect to thank-you state
- On gateway failure: inline error, retain form state
- On success: thank-you state inline (or redirect to configured URL); receipt email fires

**Edge states:**
- `Status = Draft` → 404 (unless preview-token in querystring)
- `Status = Closed` → renders page with "This campaign has ended" banner; donate disabled
- `Status = Archived` → 410 Gone
- Within Active window but `PaymentMethodsJson` empty → "Donations temporarily unavailable" message

---

### 🅱️ Block B — P2P_FUNDRAISER (fill if sub-type = P2P_FUNDRAISER)

#### B.1 — Admin Setup (parent campaign — tabbed)

**Tab Layout:**

| # | Tab | Icon | Sections | Save |
|---|-----|------|----------|------|
| 1 | Basic Info | `ph:info` | Name, Slug, Story, Hero, Goal, Dates | save-per-tab |
| 2 | Fundraiser Settings | `ph:user-plus` | Registration toggle, Approval mode (auto/manual), Goal Settings (default/min/max), Team Fundraising toggle | save-per-tab |
| 3 | Donation Settings | `ph:hand-coins` | Amount chips, Recurring, Min donation, Match-gift toggle | save-per-tab |
| 4 | Branding & Page | `ph:palette` | Logo, hero, theme colors, public-page section toggles (Story / Leaderboard / Recent Donations / FAQ) | save-per-tab |
| 5 | Communication | `ph:envelope-simple` | Welcome email / Approved / Rejected / Reminder templates (rich text + variables) | save-per-tab |

**Live preview pane** on every tab — shows public parent page with current settings.

**Active Fundraiser List Section** (separate from setup tabs — admin sees existing children):
- Embedded grid: Fundraiser Name | Owner | Status | Raised | Goal | Approval action
- Bulk actions: Approve / Reject (when ApprovalMode = manual)
- Click → drill to child fundraiser page admin view (read-only setup + donations table)

#### B.2 — Public Parent Page (`/p/{parent-slug}`)

```
┌────────────────────────────────────────────────────────────┐
│   [Hero — Campaign Banner]                                 │
│   {Campaign Name}                                          │
│   {Tagline}                                                │
│                                                            │
│   ████████░░ $76,840 raised of $100,000 (76.8%)            │
│   • 234 fundraisers  • 1,412 donations  • 12 days left     │
│                                                            │
│   [START FUNDRAISER]   [DONATE TO CAMPAIGN]                │
├────────────────────────────────────────────────────────────┤
│   Story (rich text)                                        │
├────────────────────────────────────────────────────────────┤
│   🏆 Top Fundraisers (Leaderboard)                         │
│   1. Sarah J. ─ $5,200 raised ─ {avatar}                   │
│   2. ...                                                   │
├────────────────────────────────────────────────────────────┤
│   Active Fundraisers (grid of cards)                       │
│   [Card] [Card] [Card] [Card]  ...                         │
├────────────────────────────────────────────────────────────┤
│   FAQ / Footer                                             │
└────────────────────────────────────────────────────────────┘
```

**"Start Fundraiser" Wizard** (anonymous-callable):
1. Step 1 — Email + Name (creates / matches Contact)
2. Step 2 — Personal goal (default from parent settings; min/max enforced)
3. Step 3 — Personalize page (own hero, story, optional video URL)
4. Submit → if `ApprovalMode = auto` → child page Active immediately + welcome email + login-link to manage
5. If `ApprovalMode = manual` → child page Pending + admin notified + "your page is under review" message

#### B.3 — Public Child Fundraiser Page (`/p/{parent-slug}/{fundraiser-slug}`)

- Personal hero, personal story, personal goal progress bar
- "Donate to {fundraiser-name}'s page" CTA
- Donations from this page roll up to parent campaign total
- "Created by {fundraiser}" badge linking back to parent
- Fundraiser owns: edit own story / hero (via login link), see own donations, share buttons

**Edge states:**
- Pending → 404 to public; "your page is under review" to fundraiser owner via login link
- Rejected → 404 to public; rejection email sent with reason
- Active parent + Pending child → public sees parent leaderboard but child not listed
- Closed parent → all children become Closed; no new donations on any

---

### 🅲 Block C — CROWDFUND (fill if sub-type = CROWDFUND)

#### C.1 — Admin Setup (campaign — tabbed)

| # | Tab | Icon | Sections | Save |
|---|-----|------|----------|------|
| 1 | Basic Info | `ph:info` | Name, Slug, Tagline, Goal Amount, StretchGoal, Start/End Date, Hero | save-per-tab |
| 2 | Story | `ph:book-open-text` | About (rich text), Impact (with stats), Gallery (multi-image), Video URL | save-per-tab |
| 3 | Rewards | `ph:gift` | Reward tiers (add / edit / reorder / delete) — each with min amount, perks, inventory limit | save-per-tab |
| 4 | Updates | `ph:bell` | Update post composer + list of published updates | (autosave on each post) |
| 5 | Branding | `ph:palette` | Logo, theme, page section toggles | save-per-tab |
| 6 | SEO & Social | `ph:share-network` | OG meta, share copy variants per channel | save-per-tab |

**Reward Tier Editor** (Tab 3 — embedded grid):
| Field | Type | Validation |
|-------|------|------------|
| Title | text | required, ≤80 chars |
| MinAmount | currency | required, > 0, > previous tier (warn if not) |
| Perks | rich text | required |
| InventoryLimit | int? | optional; null = unlimited |
| ImageUrl | upload | optional |
| EstimatedDelivery | date | optional |
| ShippingRequired | bool | default false |

#### C.2 — Public Campaign Page (`/p/{slug}`)

```
┌────────────────────────────────────────────────────────────┐
│   [Hero / Video]                                           │
│   {Campaign Name}                                          │
│   {Tagline}                                                │
│                                                            │
│   ████████░░  $76,840 of $100,000 (76.8%)                  │
│   📅 12 days left   👥 234 backers   ⭐ 1 stretch goal     │
│                                                            │
│   [BACK THIS CAMPAIGN]                                     │
├──────────────────────────┬─────────────────────────────────┤
│  Story / About / Impact  │  Reward Tiers                   │
│  (rich text + media)     │  ┌────────────────────────────┐ │
│                          │  │ $25 — Early Bird           │ │
│                          │  │ Perks ...                  │ │
│                          │  │ 47 of 100 claimed          │ │
│                          │  │ [SELECT]                   │ │
│                          │  └────────────────────────────┘ │
│                          │  ┌────────────────────────────┐ │
│                          │  │ $100 — SOLD OUT (disabled) │ │
│                          │  └────────────────────────────┘ │
├──────────────────────────┴─────────────────────────────────┤
│   📣 Updates (newest first)                                │
│   ─ {date} — Title — Body excerpt — Read more              │
├────────────────────────────────────────────────────────────┤
│   👥 Recent Backers (avatars + amounts; anonymous hidden)  │
├────────────────────────────────────────────────────────────┤
│   Share: [Facebook][Twitter][WhatsApp][LinkedIn][Copy URL] │
└────────────────────────────────────────────────────────────┘
```

**"Back this campaign" Flow:**
1. Click → modal with reward tier picker (or "Back without reward")
2. Amount auto-suggested from picked tier; donor can increase
3. Donor fields (name + email + shipping if `ShippingRequired`)
4. Payment hand-off (gateway iframe)
5. On success → backer card added to "Recent Backers"; tier `ClaimedCount++` (atomic)
6. Update post emails (if "Notify backers" toggled on by admin) optional

**Edge states:**
- Goal met before deadline → progress bar shows "Goal met! Stretch goal: $X" if stretch set; else "Funded — backing still open"
- Deadline passed but goal not met → "Campaign closed — final raised $X" (if "all-or-nothing" mode is intended, refund logic is a SERVICE_PLACEHOLDER unless gateway supports it)
- Reward tier sold out → "Sold out" badge; tier disabled but still rendered
- Update post draft → not visible publicly until published

---

### Shared blocks (apply to all sub-types)

#### Page Header & Breadcrumbs (admin setup)

| Element | Content |
|---------|---------|
| Breadcrumb | {Module} › {ParentMenu} › {Entity Name} |
| Page title | {Entity Name} |
| Subtitle | One-sentence (e.g. "Configure and publish online donation page") |
| Status badge | Draft / Published / Active / Closed / Archived (color-coded) |
| Right actions | [Preview] [Publish/Unpublish] [Overflow: Close / Archive / Test / Help] |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading (setup) | Initial fetch | Skeleton matching tab layout |
| Loading (public) | Initial fetch | Skeleton matching public hero + form |
| Empty (setup list) | No pages yet | "Create your first {sub-type} page" + primary CTA |
| Error (setup) | GET fails | Error card with retry |
| Error (public) | Slug not found | 404 page with org-default redirect |
| Closed (public) | Status = Closed | Banner "This campaign has ended" + raised total |

---

## ⑦ Substitution Guide

> **TBD** — first EXTERNAL_PAGE screen of each sub-type sets the canonical reference. Until then,
> copy from the closest existing screen and adapt:
>
> - DONATION_PAGE → no precedent yet. First builder sets convention.
> - P2P_FUNDRAISER → no precedent yet. First builder sets convention.
> - CROWDFUND → no precedent yet. First builder sets convention.
>
> Maintainer: when the first EXTERNAL_PAGE of each sub-type completes, replace this block with a
> real substitution table mirroring `_MASTER_GRID.md` §⑦.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| {CanonicalName} | {EntityName} | Entity/class name |
| {canonicalCamel} | {entityCamelCase} | Variable/field names |
| {schema} | {schema} | DB schema |
| {Group} | {Group} | Backend group name |
| ... | ... | ... |

---

## ⑧ File Manifest

> Counts vary by sub-type. EXTERNAL_PAGE always has BE setup files + BE public-route files +
> FE admin files + FE public-route files. Pick the matching block.

### Backend Files — DONATION_PAGE (single-page-record)

| # | File | Path |
|---|------|------|
| 1 | Entity | Pss2.0_Backend/.../Base.Domain/Models/{Group}Models/{EntityName}.cs |
| 2 | EF Config | Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/{Group}Configurations/{EntityName}Configuration.cs |
| 3 | Schemas (DTOs) | Pss2.0_Backend/.../Base.Application/Schemas/{Group}Schemas/{EntityName}Schemas.cs |
| 4 | GetById / GetAll Queries | …/{PluralName}/GetByIdQuery/Get{EntityName}ById.cs + GetAll{PluralName}.cs |
| 5 | GetBySlug Query (public) | …/{PluralName}/GetBySlugQuery/Get{EntityName}BySlug.cs (anonymous-allowed) |
| 6 | GetStats Query | …/{PluralName}/GetStatsQuery/Get{EntityName}Stats.cs |
| 7 | ValidateForPublish Query | …/{PluralName}/ValidateForPublishQuery/Validate{EntityName}ForPublish.cs |
| 8 | Create Command | …/{PluralName}/CreateCommand/Create{EntityName}.cs |
| 9 | Update Command | …/{PluralName}/UpdateCommand/Update{EntityName}.cs |
| 10 | Lifecycle Commands | …/{PluralName}/LifecycleCommands/{Publish,Unpublish,Close,Archive}{EntityName}.cs |
| 11 | Slug Validator | …/Validators/{EntityName}SlugValidator.cs |
| 12 | Mutations endpoint | …/EndPoints/{Group}/Mutations/{EntityName}Mutations.cs |
| 13 | Queries endpoint (admin) | …/EndPoints/{Group}/Queries/{EntityName}Queries.cs |
| 14 | Public endpoint | …/EndPoints/{Group}/Public/{EntityName}PublicQueries.cs (anonymous-allowed, rate-limited) |

### Backend Files — P2P_FUNDRAISER (parent-with-children)

| # | File | Path |
|---|------|------|
| 1-14 | Same as DONATION_PAGE (parent campaign) | (same paths) |
| 15 | Fundraiser child entity | …/{Group}Models/{Entity}Fundraiser.cs |
| 16 | Fundraiser EF Config | …/Configurations/{Group}Configurations/{Entity}FundraiserConfiguration.cs |
| 17 | Fundraiser Schemas | …/Schemas/{Group}Schemas/{Entity}FundraiserSchemas.cs |
| 18 | Fundraiser CRUD Commands | Create/Update/Approve/Reject/Delete |
| 19 | GetAllFundraisersByCampaign Query | …/GetFundraisersQuery |
| 20 | GetLeaderboard Query | …/GetLeaderboardQuery |
| 21 | Public CreateFundraiser endpoint | anonymous-allowed, rate-limited |
| 22 | Communication template handlers | Send{Welcome,Approved,Rejected,Reminder} |
| 23 | (Optional) Team entity + CRUD | …/{Entity}Team.cs |

### Backend Files — CROWDFUND (parent-with-children)

| # | File | Path |
|---|------|------|
| 1-14 | Same as DONATION_PAGE (campaign) | (same paths) |
| 15 | RewardTier child entity | …/{Group}Models/{Entity}RewardTier.cs |
| 16 | RewardTier EF Config | …/Configurations/{Group}Configurations/{Entity}RewardTierConfiguration.cs |
| 17 | RewardTier Schemas | …/Schemas/{Group}Schemas/{Entity}RewardTierSchemas.cs |
| 18 | RewardTier CRUD + Reorder Commands | Create/Update/Delete/Reorder |
| 19 | Update post entity + CRUD | …/{Group}Models/{Entity}Update.cs + commands |
| 20 | BackRewardTier mutation (anonymous) | atomic inventory decrement |
| 21 | GetBackers Query | paginated, privacy-filtered |
| 22 | Public BackCampaign endpoint | anonymous-allowed, rate-limited, csrf-protected |

### Backend Wiring Updates (all sub-types)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | DbSet<{EntityName}> + child DbSets |
| 2 | {Group}DbContext.cs | DbSet entries |
| 3 | DecoratorProperties.cs | Decorator{Group}Modules entry |
| 4 | {Group}Mappings.cs | Mapster mapping config (incl. children) |
| 5 | Public route registration | Register `/p/{slug}` GET (and child route patterns) |
| 6 | Anti-fraud middleware | Rate-limit policy on public endpoints |
| 7 | OG meta-tag handler | Pre-render OG tags for `/p/{slug}` SSR response |

### Frontend Files — DONATION_PAGE

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/{group}-service/{EntityName}Dto.ts |
| 2 | GQL Query (admin) | …/gql-queries/{group}-queries/{EntityName}Query.ts |
| 3 | GQL Query (public) | …/gql-queries/public/{EntityName}PublicQuery.ts |
| 4 | GQL Mutation | …/gql-mutations/{group}-mutations/{EntityName}Mutation.ts |
| 5 | Setup List Page | …/page-components/{group}/{feFolder}/{entity-lower}/list-page.tsx |
| 6 | Setup Editor Page | …/{entity-lower}/setup-page.tsx (split-pane editor + preview) |
| 7 | Editor Section components (per section) | …/{entity-lower}/sections/{section-name}-section.tsx |
| 8 | Live Preview component | …/{entity-lower}/components/live-preview.tsx (mobile/desktop toggle) |
| 9 | Public page component | …/page-components/public/{entity-lower}/donation-page.tsx |
| 10 | Public donation form | …/public/{entity-lower}/components/donation-form.tsx |
| 11 | Public thank-you state | …/public/{entity-lower}/components/thank-you.tsx |
| 12 | Page Config (admin) | …/pages/{group}/{feFolder}/{entity-lower}.tsx |
| 13 | Route Page (admin) | src/app/[lang]/(core)/{group}/{feFolder}/{entity-lower}/page.tsx |
| 14 | Route Page (public) | src/app/[lang]/(public)/p/[slug]/page.tsx (SSR) |

### Frontend Files — P2P_FUNDRAISER

| # | File | Path |
|---|------|------|
| 1-4 | DTOs + GQL Query + Mutation (parent + fundraiser child) | (same patterns) |
| 5 | Parent setup page (tabbed) | …/{entity-lower}/setup-page.tsx |
| 6 | Tab components (Basic / Fundraiser / Donation / Branding / Communication) | …/{entity-lower}/tabs/{tab}-tab.tsx |
| 7 | Active fundraiser admin grid | …/{entity-lower}/components/fundraiser-grid.tsx |
| 8 | Approval queue component (when manual approval) | …/{entity-lower}/components/approval-queue.tsx |
| 9 | Public parent page | …/public/{entity-lower}/parent-page.tsx |
| 10 | Public child fundraiser page | …/public/{entity-lower}/fundraiser-page.tsx |
| 11 | "Start Fundraiser" wizard | …/public/{entity-lower}/components/start-fundraiser-wizard.tsx |
| 12 | Leaderboard component | …/public/{entity-lower}/components/leaderboard.tsx |
| 13 | Page Config + Route (admin) | (same as DONATION_PAGE) |
| 14 | Route Page (public parent) | src/app/[lang]/(public)/p/[slug]/page.tsx |
| 15 | Route Page (public child) | src/app/[lang]/(public)/p/[slug]/[fundraiserSlug]/page.tsx |

### Frontend Files — CROWDFUND

| # | File | Path |
|---|------|------|
| 1-4 | DTOs + GQL Query + Mutation (campaign + reward tiers + updates) | (same patterns) |
| 5 | Setup page (tabbed) | …/{entity-lower}/setup-page.tsx |
| 6 | Tab components (Basic / Story / Rewards / Updates / Branding / SEO) | …/{entity-lower}/tabs/{tab}-tab.tsx |
| 7 | Reward tier editor (sub-grid + reorder) | …/{entity-lower}/components/reward-tier-editor.tsx |
| 8 | Update post composer (rich text + image) | …/{entity-lower}/components/update-composer.tsx |
| 9 | Public campaign page | …/public/{entity-lower}/campaign-page.tsx |
| 10 | Public reward tier list | …/public/{entity-lower}/components/reward-tier-list.tsx |
| 11 | "Back this campaign" modal | …/public/{entity-lower}/components/back-modal.tsx |
| 12 | Updates feed | …/public/{entity-lower}/components/updates-feed.tsx |
| 13 | Backers list | …/public/{entity-lower}/components/backers-list.tsx |
| 14 | Page Config + Route (admin + public) | (same patterns) |

### Frontend Wiring Updates (all sub-types)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | {ENTITY_UPPER} operations config |
| 2 | operations-config.ts | Import + register operations |
| 3 | sidebar menu config | Menu entry under {ParentMenu} (typically "Fundraising" or "Campaigns") |
| 4 | Public route layout | `(public)` route group with anonymous layout (no admin chrome) |
| 5 | OG meta-tag generator | `generateMetadata` per public route |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by `/plan-screens`.

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}

MenuName: {Entity Display Name}
MenuCode: {ENTITYUPPER}
ParentMenu: {PARENTMENUCODE — typically a FUNDRAISING / CAMPAIGNS parent}
Module: {MODULECODE}
MenuUrl: {group/feFolder/entitylower}
GridType: EXTERNAL_PAGE

MenuCapabilities: READ, CREATE, MODIFY, DELETE, PUBLISH, ARCHIVE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, PUBLISH, ARCHIVE

GridFormSchema: SKIP
GridCode: {ENTITYUPPER}
---CONFIG-END---
```

> Capabilities by sub-type (additions over the base):
> - DONATION_PAGE: base set is sufficient
> - P2P_FUNDRAISER: add `APPROVE_FUNDRAISER` (gates Approve/Reject moderation queue)
> - CROWDFUND: add `MANAGE_REWARDS` (gates reward tier editor) and `POST_UPDATE` (gates update composer)
>
> `GridFormSchema: SKIP` for all EXTERNAL_PAGE sub-types — these are custom UIs, not RJSF modal forms.
> `GridType: EXTERNAL_PAGE` is a new GridType — register in the GridType enum/seed.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `{EntityName}Queries`
- Mutation type: `{EntityName}Mutations`
- Public Query type: `{EntityName}PublicQueries` (anonymous-allowed)

### Common across sub-types

**Admin Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAll{EntityName}List | [{EntityName}ResponseDto] | pageNo, pageSize, statusFilter |
| Get{EntityName}ById | {EntityName}ResponseDto | id |
| Get{EntityName}Stats | {EntityName}StatsDto | id |
| Validate{EntityName}ForPublish | ValidationResultDto | id |

**Admin Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| Create{EntityName} | {EntityName}RequestDto | int |
| Update{EntityName} | {EntityName}RequestDto | int |
| Publish{EntityName} | id | {EntityName}ResponseDto |
| Unpublish{EntityName} | id | {EntityName}ResponseDto |
| Close{EntityName} | id | {EntityName}ResponseDto |
| Archive{EntityName} | id | int |

**Public Queries (anonymous):**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| Get{EntityName}BySlug | {EntityName}PublicDto (only public-safe fields) | slug, tenantSlug? |
| Get{EntityName}PublicStats | {EntityName}PublicStatsDto | slug |

### DONATION_PAGE — additional

**Public Mutations (anonymous, rate-limited, csrf-protected):**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| InitiateDonation | InitiateDonationDto (slug, amount, recurring?, donorFields, csrfToken, honeypot) | DonationInitDto (paymentSessionId or redirectUrl) |
| ConfirmDonation | gatewayCallbackPayload | DonationConfirmedDto (receiptUrl, thankYouState) |

### P2P_FUNDRAISER — additional

**Admin Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAllFundraisersBy{EntityName} | [{Entity}FundraiserResponseDto] | campaignId, status, pageNo, pageSize |
| Get{EntityName}Leaderboard | [LeaderboardEntryDto] | campaignId, topN |
| GetPendingFundraisers | [{Entity}FundraiserResponseDto] | campaignId |

**Admin Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| ApproveFundraiser | fundraiserId | int |
| RejectFundraiser | fundraiserId, reason | int |

**Public Mutations (anonymous):**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| StartFundraiser | StartFundraiserDto (campaignSlug, email, name, personalGoal, story, csrfToken) | StartFundraiserResultDto (childSlug, status, loginLink) |
| InitiateDonationToFundraiser | (campaignSlug, fundraiserSlug, amount, donorFields, csrfToken) | DonationInitDto |

### CROWDFUND — additional

**Admin Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAllRewardTiersBy{EntityName} | [{Entity}RewardTierResponseDto] | campaignId |
| GetAllUpdatesBy{EntityName} | [{Entity}UpdateResponseDto] | campaignId, pageNo |
| Get{EntityName}Backers | [BackerEntryDto] | campaignId, pageNo, hideAnonymous? |

**Admin Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| Create{Entity}RewardTier / Update / Delete / Reorder{Entity}RewardTiers | DTOs | int |
| Create{Entity}Update / Update / Delete / Publish{Entity}Update | DTOs | int |

**Public Mutations (anonymous):**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| BackCampaign | BackCampaignDto (campaignSlug, rewardTierId?, amount, donorFields, shippingAddress?, csrfToken) | DonationInitDto |

**Public DTO Privacy Discipline:**
| Field | Public DTO | Reason |
|-------|------------|--------|
| Internal donation IDs | omitted | not relevant to anonymous |
| Donor email / phone | omitted | PII never on public stats |
| Donor name on backers list | shown ONLY when donor.IsAnonymous = false | privacy |
| Admin notes / approval reasons | omitted | internal-only |
| Total raised, backer count, tiers, story, updates | included | public-safe |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — admin loads at `/{lang}/{group}/{feFolder}/{entitylower}`
- [ ] `pnpm dev` — public loads at `/{lang}/p/{slug}` (or `/p/{tenant}/{slug}` if tenant-prefixed)

**Functional Verification — pick the sub-type block:**

### DONATION_PAGE
- [ ] Setup list view shows all pages with status badges; search and filter work
- [ ] "Create Page" → defaults to Draft, slug auto-generated, redirects to setup editor
- [ ] Setup editor saves on edit (autosave); preview pane updates live
- [ ] Mobile/Desktop preview toggle changes preview viewport
- [ ] Validate-for-publish shows missing-fields list when validation fails
- [ ] Publish transitions Draft → Active; status badge updates; URL becomes shareable
- [ ] Anonymous public route at `/p/{slug}` renders for Active page
- [ ] Public donate flow completes end-to-end (real or SERVICE_PLACEHOLDER gateway)
- [ ] Receipt email fires after successful donation (real or SERVICE_PLACEHOLDER)
- [ ] CSRF + honeypot + rate-limit enforced on public submit
- [ ] Closed status renders banner + disables donate button on public
- [ ] Archived status returns 410 Gone
- [ ] OG tags rendered in initial SSR HTML; share preview correct on FB/Twitter

### P2P_FUNDRAISER
- [ ] Parent campaign setup tabs each persist
- [ ] Active fundraiser grid shows existing children with status, raised, owner
- [ ] Public parent renders leaderboard + active fundraisers + "Start Fundraiser" CTA
- [ ] Leaderboard ranks by total raised; ties broken by created date
- [ ] "Start Fundraiser" wizard creates Contact + child page
- [ ] ApprovalMode = auto → child page Active immediately + welcome email
- [ ] ApprovalMode = manual → child page Pending; admin sees in moderation queue
- [ ] Approve in admin → child page Active + approved email; appears in public list
- [ ] Reject in admin → child page Rejected + rejection email with reason
- [ ] Public child page accepts donations; rolls up to parent total
- [ ] Closed parent → all children become Closed; donations disabled across all
- [ ] Team Fundraising toggle (when ON) shows team-create option in wizard

### CROWDFUND
- [ ] Setup tabs each persist
- [ ] Reward tier editor: add / edit / reorder / delete; min amount > previous warning
- [ ] Update post composer publishes timestamped updates; show in newest-first order
- [ ] Public campaign page shows progress bar + "% funded" + days-left countdown
- [ ] Reward tier list shows claimed-of-limit; sold-out tiers visually disabled but rendered
- [ ] "Back this" modal lets backer pick tier or back without; amount auto-from-tier; donor enters info; payment hand-off
- [ ] On successful back: ClaimedCount increments atomically (no race / oversell)
- [ ] Recent backers list updates; anonymous donors hidden from public list
- [ ] Goal-met state: progress bar caps; "Goal met!" banner; stretch goal shown if set
- [ ] Deadline-passed state: "Campaign closed — final $X" banner; back button disabled
- [ ] Share buttons (FB/Twitter/WhatsApp/LinkedIn/Copy) wired with correct OG share copy

**DB Seed Verification:**
- [ ] Admin menu appears in sidebar at `{ParentMenu}` (typically Fundraising / Campaigns)
- [ ] Sample published page seeded for sample tenant — public route renders for QA
- [ ] (P2P) Sample parent + 3 child fundraisers + leaderboard data seeded
- [ ] (CROWDFUND) Sample campaign + 3 reward tiers + 2 update posts + 5 backers seeded
- [ ] Status transitions exercised: Draft → Published → Active → Closed each render correctly

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Universal EXTERNAL_PAGE warnings:**

- **TWO render trees** — admin setup AND anonymous public. They live in different route groups
  (`(core)` vs `(public)`), use different layouts (admin shell vs public chrome), and have
  different auth gates (BUSINESSADMIN vs anonymous). Don't render setup chrome on the public route.
- **Slug uniqueness is per-tenant** — `(CompanyId, Slug)` composite unique. Two different tenants
  can have `/p/run-2026` simultaneously. Public route resolution may go through tenant slug or
  custom domain.
- **Lifecycle is BE-enforced** — never trust an FE flag that says "ready to publish". Re-validate
  on the server every time. Status transitions are explicit commands, not field updates.
- **Anonymous-route hardening is non-negotiable** — rate-limit, CSRF, honeypot, recaptcha,
  CSP headers. Skipping any of these is a security defect, not an enhancement.
- **PCI scope must NOT cross the public form** — payment gateway must tokenize at the iframe
  boundary; raw card data never touches our servers. Any setup that puts a card field directly
  in our form is wrong.
- **OG meta tags must be SSR-rendered** — social crawlers don't run JS. Pre-render in
  `generateMetadata` so FB/Twitter previews work.
- **Slug is immutable post-Activation when donations attached** — link rot prevents donor confusion
  and breaks share posts. Renaming slug requires Archive + recreate.
- **Donation persistence is OUT OF SCOPE for this entity** — donations live in
  `finance.Donations` with FK back to this page. Setup configures the funnel; donations are
  recorded by the existing donation pipeline.
- **GridFormSchema = SKIP** — custom UIs, not RJSF modal forms.
- **GridType = EXTERNAL_PAGE** — new GridType; ensure it's registered in the GridType enum + seed.

**Sub-type-specific gotchas:**

| Sub-type | Easy mistakes |
|----------|---------------|
| DONATION_PAGE | Live preview that doesn't actually update live ("save and refresh"); recurring frequencies missing validation; payment methods reordering not persisting; thank-you page not redirecting; OG tags missing |
| P2P_FUNDRAISER | "Start Fundraiser" creating a Contact without dedupe on email; ApprovalMode=manual not gating publish; child slug colliding with parent slug; leaderboard rebuilt on every render (must be cached/aggregated query); team relationship not enforced |
| CROWDFUND | Inventory race condition on BackRewardTier (must be atomic DB decrement); sold-out tier removed instead of disabled (loses social proof); update post draft visible publicly; goal-met state not switching progress bar UX; backer privacy not respected (anonymous donors leaking) |

**Public-route deployment checklist:**
- [ ] Public route group `(public)` exists with no admin chrome
- [ ] Anonymous middleware allows GET on `/p/{slug}` and POST on public mutations only
- [ ] Rate-limit policy registered for public POST endpoints
- [ ] CSRF token issued on public GET render and validated on public POST
- [ ] CSP headers set with payment-gateway iframe origin allowed
- [ ] OG meta-tag pre-render in `generateMetadata`
- [ ] 404 / 410 / closed-banner edge states render correctly

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup is in scope. List items here ONLY if they require an
> external service or infrastructure that doesn't exist in the codebase yet.

{Only list genuine external-service dependencies — leave empty if none.}
- {e.g. "⚠ SERVICE_PLACEHOLDER: 'Payment Gateway' — UI fully implemented (amount chips, recurring, donor fields, submit button). Handler returns mocked success. Real Stripe/PayPal connect lives in payment-gateway CONFIG screen and integration is pending."}
- {e.g. "⚠ SERVICE_PLACEHOLDER: 'Receipt Email' — UI implemented (template select, send-on-success toggle). Handler logs only because email-send service isn't wired yet."}
- {e.g. "⚠ SERVICE_PLACEHOLDER: 'reCAPTCHA v3' — UI placeholder; score check returns 1.0 until service configured."}
- {e.g. "⚠ SERVICE_PLACEHOLDER: 'Social-share OG meta' — basic OG tags rendered; advanced per-channel variants (Twitter card type, FB app-id) deferred."}

Full UI must be built (setup tabs, public render tree, donation flow up to gateway boundary,
admin moderation, edge states). Only the handlers for genuinely missing services are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
```

---

## Section Purpose Summary

| # | Section | Who Reads It | What It Answers |
|---|---------|-------------|-----------------|
| ① | Identity & Context | All agents | "What is this page, who consumes it, what's the conversion goal, what's the lifecycle?" |
| ② | Storage & Source Model | BA → BE Dev | "Single page record vs parent-with-children; donations linked via existing pipeline" |
| ③ | FK Resolution | BE Dev + FE Dev | "WHERE is each FK / aggregation source?" |
| ④ | Business Rules | BA → BE Dev → FE Dev | "Slug, lifecycle, required-to-publish, public-form hardening, dangerous actions, role gating" |
| ⑤ | Classification | Solution Resolver | "Sub-type (DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND), slug strategy, lifecycle set, save model, public render strategy" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "Per sub-type: admin setup UI + public page UI — both surfaces" |
| ⑦ | Substitution Guide | BE Dev + FE Dev | "How to map canonical → this entity (TBD until first per sub-type lands)" |
| ⑧ | File Manifest | BE Dev + FE Dev | "Exact files per sub-type — admin setup + public route, BE + FE" |
| ⑨ | Approval Config | User | "Capabilities differ by sub-type; new GridType EXTERNAL_PAGE; GridFormSchema=SKIP" |
| ⑩ | BE→FE Contract | FE Dev | "Per-sub-type queries + mutations + DTOs; admin vs public privacy split" |
| ⑪ | Acceptance Criteria | Verification | "Sub-type-specific E2E checks + public-route hardening + lifecycle transitions" |
| ⑫ | Special Notes | All agents | "Two render trees, anonymous-route hardening, slug uniqueness, lifecycle BE-enforced, sub-type gotchas" |

---

## Notes for `/plan-screens`

- Detect EXTERNAL_PAGE by: mockup has BOTH an admin setup UI (tabs / sections + Publish action)
  AND a public-facing page (hero / donate-form / shareable URL / OG tags). Status badge
  (Draft / Published / Active / Closed) is a strong signal.
- Distinguish from FLOW: FLOW transacts on internal records (donor enters a donation; admin
  approves a grant). EXTERNAL_PAGE produces a public-facing PAGE that anonymous visitors
  consume; the transaction happens via the page, not on the page-record itself.
- Distinguish from CONFIG: CONFIG configures internal behavior (SMTP, tax rates, role matrix).
  EXTERNAL_PAGE configures and publishes a public page.
- Distinguish from DASHBOARD: DASHBOARD is many widgets for internal admin overview.
  EXTERNAL_PAGE has TWO surfaces — internal setup AND public consumer.
- Stamp `external_page_subtype` in frontmatter — DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND.
- Stamp `slug_strategy` and `lifecycle_set` in §⑤.
- Pre-fill §⑨ Approval Config with new `GridType: EXTERNAL_PAGE`.
- §⑥: include only the relevant sub-type block; delete the others before writing the screen prompt.
- §⑧ File Manifest: always includes BOTH admin setup files AND public route files.
- §⑩ BE→FE: split into Admin Queries + Admin Mutations + Public Queries + Public Mutations,
  with public DTOs strictly limited to public-safe fields.

## Notes on canonical references

When the first DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND completes:

1. Replace §⑦ TBD block with a real substitution table modeled on `_MASTER_GRID.md` §⑦.
2. Update `_COMMON.md` § Substitution Guide table with the new canonical per sub-type.
3. Add a one-line note to this file's header listing the canonical reference.
