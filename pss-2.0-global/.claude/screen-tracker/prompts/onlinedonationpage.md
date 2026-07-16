---
screen: OnlineDonationPage
registry_id: 10
module: Setting (Public Pages)
status: COMPLETED
scope: FULL
screen_type: EXTERNAL_PAGE
external_page_subtype: DONATION_PAGE
complexity: High
new_module: NO
planned_date: 2026-05-08
completed_date: 2026-05-08
last_session_date: 2026-07-16
last_session: 55
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: DONATION_PAGE — single donate page)
- [x] Business context read (audience = anonymous donors; conversion goal = completed donation; lifecycle = Draft → Published → Active → Closed → Archived)
- [x] Setup vs Public route split identified (admin at `setting/publicpages/onlinedonationpage` + anonymous public at `(public)/p/{slug}` for NAV mode and `(public)/embed/{slug}` for IFRAME mode)
- [x] Slug strategy chosen: `custom-with-fallback` (auto-from-Name; user may override; per-tenant unique)
- [x] Lifecycle states confirmed: Draft / Published / Active / Closed / Archived (full)
- [x] Payment gateway integration scope: SERVICE_PLACEHOLDER (real Stripe/PayPal/Razorpay handshake deferred — UI complete + handler returns mock confirmation)
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed (admin setup files + public page files separately + iframe widget route)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (page purpose + audience + conversion + lifecycle + ImplementationType branch) — pass-through (prompt §① + ④ + ⑤ already contain BA-grade analysis)
- [x] Solution Resolution complete (sub-type confirmed, slug strategy, lifecycle, payment scope, NAV vs IFRAME persistence model) — pass-through (prompt §⑤ pre-answered all classifications)
- [x] UX Design finalized (10 setup cards + live preview pane with ImplementationType-aware render + 4 preview variants nav/iframe × desktop/mobile) — pass-through (prompt §⑥ contains full ASCII mockups for admin + NAV public + IFRAME widget)
- [x] User Approval received — 2026-05-08: FULL scope, one-tenant-per-deployment public route resolution (ISSUE-1 MVP path), full hardening per §④
- [x] Backend code generated — 26 files (incl. EntityHelper + Toggle command added during QA fix); paths use `Business/DonationBusiness/OnlineDonationPages/Commands/` and `Queries/` flat layout (matches Pledges/Refunds convention)
- [x] Backend wiring complete — IDonationDbContext + DonationDbContext + DecoratorProperties + DonationMappings + GlobalDonation entity & EF config (FK column added)
- [x] Frontend (admin setup) code generated — 16 files: list-page + editor (split-pane) + status-bar + impl-type-switcher + live-preview + 9 sections + Zustand store + section-card + api-single-select
- [x] Frontend (public NAV page) code generated — donation-page.tsx + shared donation-form.tsx + thank-you.tsx + (public)/p/[slug]/page.tsx with generateMetadata SSR
- [x] Frontend (public IFRAME widget) code generated — iframe-widget.tsx + (public)/embed/[slug]/page.tsx CSR + widget.js JS-snippet loader at public/widget.js
- [x] Frontend wiring complete — DTO barrel + GQL barrels (donation + public) + operations-config + setting/publicpages/index export + (public) route group layout scaffolded
- [x] DB Seed script generated — `online-donation-page-sqlscripts.sql` ~270 lines, all idempotent NOT EXISTS guards: GridType EXTERNAL_PAGE + PAYMENTMETHOD MasterData + sample CompanyPaymentGateway + Menu under SET_PUBLICPAGES + 8 caps + BUSINESSADMIN grants + Grid + sample published page slug=give + purpose junctions
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — admin setup loads at `/{lang}/setting/publicpages/onlinedonationpage`
- [ ] `pnpm dev` — public NAV page loads at `/{lang}/p/{slug}` (canonical donation page)
- [ ] `pnpm dev` — public IFRAME widget loads at `/{lang}/embed/{slug}` (compact widget)
- [ ] **DONATION_PAGE checks**:
  - [ ] Setup list view shows all pages with status badges; "+ New Page" creates a Draft and redirects to editor
  - [ ] Editor 10 settings cards persist via autosave (300ms debounce); preview pane updates live without round-trip
  - [ ] Implementation Type switcher toggles between NAV and IFRAME — Branding card swaps between "Page Branding" (carousel/colors/layout) and "iFrame Configuration" (accent/header/footer/embed code)
  - [ ] Slug auto-generated from Name on first save; uniqueness enforced per tenant; reserved slug list rejected (admin/api/embed/p/preview/login/auth)
  - [ ] Donation Purposes multi-select sources from `fund.DonationPurposes`; default purpose dropdown filters to only selected ones; junction table `fund.OnlineDonationPagePurposes` reflects selection
  - [ ] Amount chips configurable; "Other / custom amount" toggle controls public Other chip visibility; min amount validated
  - [ ] Recurring frequencies togglable (Weekly/Monthly/Quarterly/Semi-Annual/Annual chips); default frequency dropdown shows only enabled freqs; default-to-recurring toggle reflected on public form
  - [ ] Payment Gateway dropdown sources from `fund.CompanyPaymentGateways` (only enabled rows); enabled methods checkbox list driven by gateway support
  - [ ] Donor Form Fields table: First/Last/Email forced required+visible (disabled checkboxes); other 6 fields editable; saved JSON reflects on public form
  - [ ] (NAV) Carousel slides: add/edit/remove image OR YouTube video; reorderable; reflected on hero carousel
  - [ ] (NAV) Primary color + button text + page layout (centered/side-by-side/full-width) reflected in preview
  - [ ] (IFRAME) Embed code + JS widget snippet displayed correctly with current slug; copy buttons work
  - [ ] Thank-you message + redirect URL + goal amount + end date + donor count toggle + social share toggle + tax receipt note all persist
  - [ ] Live preview reflects current setup state (NAV-desktop / NAV-mobile / IFRAME-desktop / IFRAME-mobile — 4 variants per device-switcher)
  - [ ] Validate-for-publish blocks Publish until: Name + Slug + ≥1 enabled payment method + (NAV) ≥1 carousel slide OR hero image + ≥1 amount chip; missing-field list shown in modal
  - [ ] Publish transitions Draft → Active; URL becomes shareable; OG tags pre-rendered in `generateMetadata`
  - [ ] Anonymous public page renders Active status; respects PaymentMethodsJson order; CSP headers set
  - [ ] Anonymous donor can complete donation end-to-end through gateway-tokenization SERVICE_PLACEHOLDER (form → mocked gateway → server creates GlobalDonation + GlobalOnlineDonation rows linked to OnlineDonationPageId)
  - [ ] Receipt email fires after donation (SERVICE_PLACEHOLDER if email infra missing — handler logs)
  - [ ] CSRF token issued on public render + validated on submit; honeypot field present + rejected when filled; rate-limit 5 attempts/min/IP
  - [ ] Status = Closed renders banner "This campaign has ended" + disables donate button on public; Status = Archived returns 410 Gone
  - [ ] Status Bar in admin setup shows real aggregates (totalRaised / totalDonors / conversionRate / lastDonationAt) sourced from GetOnlineDonationPageStats
- [ ] Empty / loading / error states render on both setup and public surfaces
- [ ] DB Seed — admin menu visible at SET_PUBLICPAGES > ONLINEDONATIONPAGE; sample published page renders for E2E QA at `/p/give`

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage for setup AND public page

Screen: OnlineDonationPage
Module: Setting (admin) / Public (anonymous-rendered)
Schema: `fund`
Group: DonationModels

Business: This is the canonical **public-facing donation page** an NGO publishes to collect donations from anonymous internet visitors — the conversion-funnel page that turns interested visitors into donors. The admin setup screen lets a BUSINESSADMIN configure every aspect of the experience: page identity (title, slug, description), which donation purposes are offered, suggested amount chips, recurring options, payment gateway + enabled methods, donor form fields, page branding (or embed snippet for iframe mode), thank-you behavior, and goal/deadline progress display. The headline conversion goal is a completed donation; the secondary goal is donor capture (Contact upsert) for future stewardship. Lifecycle is Draft → Published → Active → Closed → Archived: only Active pages accept donations; Draft pages render only with a preview-token; Closed pages render but disable the Donate button; Archived returns 410 Gone. **What breaks if mis-set**: donors charged but no record stored (gateway webhook missing), expired payment-gateway connect leaving "Donate" button dead, missing CSRF/honeypot enabling bot/spam donations, slug rename after donations attached → link rot on shared social posts, OG meta missing → bad share previews → low conversion. Related screens: receipts settle through the existing GlobalDonation / GlobalOnlineDonation pipeline (this page is a SOURCE, not a donation store); recurring donations create rows in fund.RecurringDonationSchedules; donor records upsert into crm.Contacts; payment gateway credentials live in `setting/paymentconfig/companypaymentgateway` (referenced by id); the Receipt template (when configured) lives in `setting/document/certificatetemplateconfig`. **What's unique about this page's UX vs a generic CMS landing page**: it has TWO publish modes — (1) a fully-hosted Navigation page at `/p/{slug}` with carousel hero + impact stats + testimonials + custom layout, OR (2) a compact iFrame widget at `/embed/{slug}` plus a JS-snippet widget that an org embeds into their own website's HTML. Both modes share the same form/payment plumbing but render entirely different chrome — the ImplementationType field (`NAV` | `IFRAME`) governs which Branding card is shown in setup, which Preview is shown in setup, and which public route is the canonical link.

> **Why this section is heavier**: ImplementationType branching is the defining characteristic — a developer that misses this will build only the NAV path and ship a half-product. Two render trees, one entity, one BE — design accordingly.

---

## ② Storage & Source Model

> **Consumer**: BA Agent → Backend Developer

**Storage Pattern**: `single-page-record`

> Each tenant may have **multiple** OnlineDonationPage rows — e.g. a primary "Donate" page + a "Christmas Appeal 2026" page + a "Disaster Relief" page. The mockup shows ONE page setup at a time; the list view (above the editor) lists all pages of this tenant. Donations link back via FK; aggregates roll up per page.

### Tables

> Audit columns omitted (inherited from `Entity` base). CompanyId always present (tenant scope). Schema = `fund`.

**Primary table**: `fund."OnlineDonationPages"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| OnlineDonationPageId | int | — | PK | — | Identity primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (NOT a public-form field) |
| PageTitle | string | 200 | YES | — | Internal label + default for public hero title; e.g. "Support Hope Foundation" |
| Slug | string | 100 | YES | — | URL slug; unique per tenant; lower-kebab; auto-from-PageTitle on Create; reserved-slug-rejected |
| Description | string | 1000 | NO | — | Short subtitle / lead paragraph rendered in public hero |
| ImplementationType | string | 20 | YES | — | `NAV` \| `IFRAME` — drives which Branding card + which public route is canonical |
| Status | string | 20 | YES | — | Draft / Published / Active / Closed / Archived |
| PublishedAt | DateTime? | — | NO | — | Set on Draft→Published transition |
| StartDate | DateTime? | — | NO | — | When set, page Active only after this date |
| EndDate | DateTime? | — | NO | — | When set, page auto-Closed after this date |
| GoalAmount | decimal? | 12,2 | NO | — | Funding target; renders progress bar on public when set |
| DefaultDonationPurposeId | int? | — | NO | fund.DonationPurposes | Default selected on public form |
| MinimumAmount | decimal | 10,2 | YES | — | Default 5; floor for custom-amount input |
| PrimaryCurrencyId | int | — | YES | shared.Currencies | Default currency for the page |
| EnableMultiCurrency | bool | — | YES | — | When TRUE, donor sees a currency switcher (FX rate looked up via existing service) |
| AllowRecurring | bool | — | YES | — | Master toggle for recurring section |
| AvailableFrequenciesJson | jsonb | — | NO | — | `["Weekly","Monthly","Quarterly","SemiAnnual","Annual"]` (subset of master MasterDataType `RECURRINGFREQUENCY`) |
| DefaultToRecurring | bool | — | YES | — | If TRUE, recurring toggle pre-checked on public |
| DefaultFrequencyCode | string | 20 | NO | — | One of master RECURRINGFREQUENCY codes; only valid if in AvailableFrequenciesJson |
| CompanyPaymentGatewayId | int | — | YES | fund.CompanyPaymentGateways | Which gateway profile is used for this page |
| EnabledPaymentMethodsJson | jsonb | — | YES | — | Array of `MasterData` codes for type `PAYMENTMETHOD` (e.g. `["CARD","PAYPAL","WALLET"]`); ordered |
| AmountChipsJson | jsonb | — | YES | — | Array of decimals e.g. `[25,50,100,250,500]`; max 8 |
| AllowCustomAmount | bool | — | YES | — | When TRUE, public form shows "Other" chip → input |
| DonorFieldsJson | jsonb | — | YES | — | Per-field config: `{"FirstName":{"required":true,"visible":true,"locked":true},"Phone":{"required":false,"visible":true},...}` for 9 fields total |
| LogoUrl | string | 500 | NO | — | Org logo (NAV mode hero left) |
| HeroImageUrl | string | 500 | NO | — | (NAV) Single hero override when CarouselSlidesJson empty |
| CarouselSlidesJson | jsonb | — | NO | — | (NAV) Array of `{type:image\|video, url, title, order}`; max 5 |
| PrimaryColorHex | string | 7 | NO | — | Theme accent (default `#0e7490`) |
| ButtonText | string | 50 | NO | — | Donate button label (default "Donate Now") |
| PageLayout | string | 30 | NO | — | (NAV) `centered` \| `side-by-side` \| `full-width` |
| CustomCssOverride | string | 8000 | NO | — | (NAV) Optional CSS pasted by admin |
| IframeShowHeader | bool | — | NO | — | (IFRAME) Show widget title/desc bar |
| IframeShowFooter | bool | — | NO | — | (IFRAME) Show "Powered by" footer |
| ThankYouMessage | string | 1000 | NO | — | Inline thank-you copy |
| ThankYouRedirectUrl | string | 500 | NO | — | If set, redirect after success instead of inline thank-you |
| ShowDonorCount | bool | — | YES | — | Renders "{N} donors have contributed" on public |
| ShowSocialShare | bool | — | YES | — | Renders FB/Twitter/WhatsApp share buttons |
| TaxReceiptNote | string | 500 | NO | — | Compliance line shown near Donate button |
| OgTitle | string | 200 | NO | — | Defaults to PageTitle |
| OgDescription | string | 500 | NO | — | Defaults to Description |
| OgImageUrl | string | 500 | NO | — | Defaults to first carousel slide image OR HeroImageUrl |
| RobotsIndexable | bool | — | YES | — | Default TRUE (donation pages should be indexed by Google) |
| IsActive | bool | — | YES | — | Soft-active toggle separate from Status — for quick "pause" without changing lifecycle |

**Slug uniqueness**:
- Unique filtered index on `(CompanyId, LOWER(Slug))` WHERE `IsDeleted = FALSE`
- Reserved-slug list rejected by validator: `admin / api / embed / p / preview / login / signup / oauth / public / assets / static`

**Status transition rules** (BE-enforced):
- Draft → Published only when validation passes (see §④ Required-to-Publish list)
- Published → Active automatic at StartDate (or = Published if no StartDate)
- Active → Closed automatic at EndDate, or admin "Close Early"
- Any → Archived admin-triggered (soft-delete; preserves donation FK rows)

### Child / Junction Table

**Junction `fund."OnlineDonationPagePurposes"`** (M:N OnlineDonationPage ↔ DonationPurpose)

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| OnlineDonationPagePurposeId | int | PK | — | Identity |
| OnlineDonationPageId | int | YES | fund.OnlineDonationPages | Cascade-delete on parent |
| DonationPurposeId | int | YES | fund.DonationPurposes | Restrict-delete (purpose can't be deleted if attached) |
| OrderBy | int | YES | — | Display order in donor's purpose dropdown |

Composite unique index on `(OnlineDonationPageId, DonationPurposeId)`.

### Generic Config Table — `fund."OnlineDonationPageSettings"` (STANDARD-template landing content)

> **Added 2026-07-16 (spec revision).** The STANDARD (Aurora) template renders a full landing page — hero benefit cards, a "Why Your Donation Matters" grid, impact stats, mission copy, and a rich footer (contact + socials + useful links). **None of these are page columns.** Instead of adding ~10 nullable columns × future config sections, they live in ONE generic key-value table, modeled on `sett.SettingGroups` + `sett.OrganizationSettings` (the tenant-settings EAV pattern) but **scoped to the page**.
>
> **Why not reuse `sett.OrganizationSettings` directly?** That table is keyed by `CompanyId` (tenant-wide) only. A tenant runs **multiple** donation pages, and landing content is per-page (like `PageTitle`/`LogoUrl`). We keep the *same shape and `ParamDataType`-driven idea*, but add the `OnlineDonationPageId` scope dimension.
>
> **Why not a jsonb column on the page?** A single blob works but is page-specific and not row-queryable. This generic table is reusable by **any future external-page config section** — add rows, never new tables/columns. That is the stated design goal.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| OnlineDonationPageSettingId | int | — | PK | — | Identity |
| OnlineDonationPageId | int | — | YES | fund.OnlineDonationPages | **Scope dimension.** Cascade-delete on parent |
| CompanyId | int | — | YES | corg.Companies | Denormalized tenant scope — fast security filter + defense-in-depth (mirrors `OrganizationSetting.CompanyId`) |
| SectionCode | string | 40 | YES | — | UPPER. Groups params like `SettingGroup.SettingGroupCode`. Catalog below |
| ParamCode | string | 60 | YES | — | UPPER. Unique per page. e.g. `BENEFIT_CARDS`, `MISSION_BODY` |
| ParamName | string | 120 | NO | — | Human label for the admin editor row |
| ParamDataType | string | 20 | YES | — | `string` \| `text` \| `int` \| `decimal` \| `bool` \| `url` \| `color` \| `json`. Drives the admin input widget AND how the FE parses `ParamValue`. This is the "data-type-based generic store" the design calls for |
| ParamValue | string (text/unbounded) | — | NO | — | The value. For `json` type, a serialized array/object — repeating structured lists (cards/stats/links) live here as ONE row each. NULL = renderer uses its built-in default |
| OrderBy | int | — | YES | — | Display order within the section |

**Indexes**:
- Unique filtered index on `(OnlineDonationPageId, ParamCode)` WHERE `IsDeleted = FALSE`.
- Non-unique index on `(OnlineDonationPageId, SectionCode, OrderBy)` for ordered section reads.

**Section / Param catalog** (maps the reference landing image → rows; all `json` values are arrays of small objects):

| SectionCode | ParamCode | DataType | Shape / Default meaning |
|-------------|-----------|----------|-------------------------|
| `HERO_BENEFITS` | `BENEFIT_CARDS` | json | `[{icon,title,desc}]` ×3 — the three benefit cards under the hero |
| `WHY_DONATE` | `WHY_DONATE_TITLE` | string | Section heading (default "Why Your Donation Matters") |
| `WHY_DONATE` | `WHY_DONATE_ITEMS` | json | `[{icon,title,desc}]` ×4 — the 4-up reasons grid |
| `IMPACT_STATS` | `IMPACT_STATS` | json | `[{value,label}]` ×N — the impact-number strip |
| `MISSION` | `MISSION_TITLE` | string | e.g. "Together We Can Change Lives" |
| `MISSION` | `MISSION_BODY` | text | Mission paragraph |
| `FOOTER` | `FOOTER_CONTACT` | json | `{address,phone,email}` |
| `FOOTER` | `FOOTER_SOCIALS` | json | `[{platform,url}]` (facebook/x/instagram/youtube…) |
| `FOOTER` | `FOOTER_LINKS` | json | `[{label,url}]` — useful links |

**Seeding**: on page **Create**, seed the default rows above (idempotent `NOT EXISTS` per `(OnlineDonationPageId, ParamCode)`) so a brand-new STANDARD page renders the full layout out-of-the-box. Admin edits only overwrite `ParamValue`. Renderer treats a missing/NULL row as "use the template's built-in default" — so old pages created before this revision still render (backfill optional, not required).

**Relocated presentation/cosmetic params (ISSUE-41 + ISSUE-42, session 53–54).** The 18 cosmetic/media/SEO columns that used to live on `fund.OnlineDonationPages` now live as rows here (storage-only, **wire-stable**: the DTOs still expose the typed fields — `PresentationOnlineDonationPageSettings.Assemble(rows)` re-hydrates them on read, so FE/templates/dispatcher/GraphQL are untouched). Reset-Branding + Publish-validation read from the assembled `pres.*`. Catalog:

| SectionCode | ParamCode | DataType | OrderBy | Source column (dropped) |
|-------------|-----------|----------|---------|-------------------------|
| `THEME` | `PRIMARY_COLOR` | color | 1 | PrimaryColorHex (default `#0e7490`) |
| `THEME` | `DONATE_BUTTON_TEXT` | string | 2 | ButtonText (default "Donate Now") |
| `THEME` | `PAGE_LAYOUT` | string | 3 | PageLayout (default "side-by-side") |
| `THEME` | `CUSTOM_CSS` | text | 4 | CustomCssOverride |
| `IFRAME` | `IFRAME_SHOW_HEADER` | bool | 1 | IframeShowHeader |
| `IFRAME` | `IFRAME_SHOW_FOOTER` | bool | 2 | IframeShowFooter |
| `THANKYOU` | `THANKYOU_MESSAGE` | text | 1 | ThankYouMessage |
| `THANKYOU` | `THANKYOU_REDIRECT_URL` | url | 2 | ThankYouRedirectUrl |
| `THANKYOU` | `TAX_RECEIPT_NOTE` | text | 3 | TaxReceiptNote |
| `SOCIAL` | `SHOW_DONOR_COUNT` | bool | 1 | ShowDonorCount |
| `SOCIAL` | `SHOW_SOCIAL_SHARE` | bool | 2 | ShowSocialShare |
| `SEO` | `OG_TITLE` | string | 1 | OgTitle |
| `SEO` | `OG_DESCRIPTION` | text | 2 | OgDescription |
| `SEO` | `OG_IMAGE_URL` | url | 3 | OgImageUrl |
| `SEO` | `ROBOTS_INDEXABLE` | bool | 4 | RobotsIndexable |
| `MEDIA` | `LOGO_URL` | url | 1 | LogoUrl |
| `MEDIA` | `HERO_IMAGE_URL` | url | 2 | HeroImageUrl |
| `MEDIA` | `CAROUSEL_SLIDES` | json | 3 | CarouselSlidesJson (truncated to first 5 by OrderBy on assemble) |

> **KEPT typed** (form config, not template content): `AmountChipsJson`, `AvailableFrequenciesJson`, `AllowCustomAmount` — payment-form behavior. Also structural/lifecycle/FK/aggregation columns stay typed. `SEO`/`MEDIA` feed the SSR `<head>`/OG path → they migrate + verify **LAST**. ParamCode constants live in `Helpers.PresentationOnlineDonationPageSettings`.

> **DO NOT** add benefit/why/impact/footer columns to `OnlineDonationPages`, and **DO NOT** create a separate table per section. One generic `OnlineDonationPageSettings` table serves every current and future landing-content section.

### Donation Linkage (DO NOT add donation columns here — link from existing entity)

**Modify** `fund."GlobalDonations"` to add:
| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| OnlineDonationPageId | int? | NO | fund.OnlineDonationPages | NULL for non-online donations; SET for any donation captured through this funnel |

This single nullable FK enables aggregating donations per page (totalRaised, donorCount, lastDonationAt). Migration: `ALTER TABLE fund."GlobalDonations" ADD COLUMN "OnlineDonationPageId" int NULL` + filtered FK constraint. Existing rows stay NULL.

> **DO NOT** add a separate "OnlineDonationPageDonation" table — single nullable FK on GlobalDonation is the leanest, queryable approach.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------------|---------------|-------------------|
| DefaultDonationPurposeId | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` | `donationPurposes` | `donationPurposeName` | `DonationPurposeResponseDto` |
| (junction) DonationPurposeId | DonationPurpose | (same) | (same) | (same) | (same) |
| PrimaryCurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `currencies` | `currencyCode` (display) + `currencyName` | `CurrencyResponseDto` |
| CompanyPaymentGatewayId | CompanyPaymentGateway | `Base.Domain/Models/DonationModels/CompanyPaymentGateway.cs` | `companyPaymentGateways` | join `paymentGateway.gatewayName` | `CompanyPaymentGatewayResponseDto` |

**Master-data references** (looked up by code via existing `MasterData` shared model — NO FK column on entity):
| Code | MasterDataType | Used For |
|------|----------------|----------|
| `WK / MO / QT / SA / AN` | `RECURRINGFREQUENCY` | AvailableFrequenciesJson + DefaultFrequencyCode |
| `CARD / PAYPAL / UPI / BANK / WALLET` | `PAYMENTMETHOD` | EnabledPaymentMethodsJson |

> Verify `PAYMENTMETHOD` MasterDataType exists; if absent, seed it (5 rows above) in step 1 of DB seed script.

**Aggregation sources** (not strictly FK — used for stats query):

| Source | Aggregate | Used In | Filter |
|--------|-----------|---------|--------|
| `fund.GlobalDonations` | `SUM(DonationAmount)` GROUP BY OnlineDonationPageId | `totalRaised` (status bar + public progress bar) | Active donations only |
| `fund.GlobalDonations` | `COUNT(DISTINCT ContactId)` GROUP BY OnlineDonationPageId | `totalDonors` (status bar + "{N} donors") | Active donations only |
| `fund.GlobalDonations` | `MAX(DonationDate)` GROUP BY OnlineDonationPageId | `lastDonationAt` (status bar) | Active donations only |
| Page visit log (NEW table OR analytics service) | `COUNT() / donationCount` | `conversionRate` (status bar) | Last 30d window |

> **conversionRate is SERVICE_PLACEHOLDER** — no page-visit logging infrastructure exists. Status bar shows "—" until visit-log table or analytics service is added (ISSUE-X).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Slug Rules**:
- Auto-generate from `PageTitle` on Create — lowercase, replace whitespace with `-`, strip non-alphanumeric (keep `-`), collapse multiple `-`
- User can override via Slug field; same normalization applied; show "URL preview" inline
- Reserved-slug list rejected (case-insensitive): `admin, api, embed, p, preview, login, signup, oauth, public, assets, static, ic, _next`
- Uniqueness enforced per tenant — composite (CompanyId, LOWER(Slug)) — same slug across tenants OK
- Slug **immutable post-Activation when ≥1 donation attached** (`SELECT EXISTS (SELECT 1 FROM fund.GlobalDonations WHERE OnlineDonationPageId = X)`)
- Validator returns 422 with `{field:"slug", code:"SLUG_RESERVED|SLUG_TAKEN|SLUG_LOCKED_AFTER_DONATIONS"}`

**Lifecycle Rules**:

| State | Set by | Public route behavior | Donate button |
|-------|--------|----------------------|---------------|
| Draft | Initial Create | 404 to public; preview-token grants temporary access | Disabled / not rendered |
| Published | Admin "Publish" action | Renders publicly | Live (if within Active window) |
| Active | Auto at StartDate (or = Published if no StartDate) | Renders publicly | Live |
| Closed | Auto at EndDate, or admin "Close Early" | Renders publicly with "This campaign has ended" banner | Disabled |
| Archived | Admin "Archive" | 410 Gone (admin can configure redirect to org default) | N/A |

**Required-to-Publish Validation** (return all violations as a list — don't stop at first):
- PageTitle non-empty
- Slug set + unique + not reserved
- ImplementationType set
- ≥1 enabled payment method (EnabledPaymentMethodsJson length ≥ 1)
- ≥1 amount chip OR AllowCustomAmount = TRUE
- ≥1 DonationPurpose attached
- DefaultDonationPurposeId IS NULL OR exists in attached purposes
- (NAV) ≥1 carousel slide OR HeroImageUrl set OR LogoUrl set (must have ANY hero asset)
- (IFRAME) PrimaryColorHex valid hex
- (Recurring) AllowRecurring=FALSE OR AvailableFrequenciesJson length ≥ 1
- OgTitle + OgImageUrl set (warn but allow — OG falls back to PageTitle + first hero image)
- (Currency) PrimaryCurrencyId valid Currency row
- CompanyPaymentGatewayId valid CompanyPaymentGateway row owned by current Company

**Conditional Rules**:
- If `AllowRecurring = FALSE` → AvailableFrequenciesJson + DefaultToRecurring + DefaultFrequencyCode all ignored on public
- If `EnableMultiCurrency = FALSE` → PrimaryCurrencyId is the only currency shown on public
- If `AmountChipsJson = []` AND `AllowCustomAmount = FALSE` → Validate-for-publish FAILS (no way to set amount)
- If `DonorFieldsJson["Anonymous"]["visible"] = FALSE` → public form omits anonymous-toggle entirely (donor name always shown on receipt)
- If `ImplementationType = IFRAME` → CarouselSlidesJson, PageLayout, CustomCssOverride are ignored on render (kept as soft-deleted state in DB, preserved if user toggles back to NAV)
- If `ImplementationType = NAV` → IframeShowHeader, IframeShowFooter are ignored
- If `GoalAmount IS NULL` → public progress bar hidden; status bar shows "Total Raised" but no goal context
- If `EndDate < now` AND `Status = Active` → server-side auto-flip to `Closed` on next state-tick OR on next public request

**Sensitive / Security-Critical Fields**:

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| CompanyPaymentGatewayId reference | secret-by-link | display gateway name, never API keys | referenced; never duplicated | log on rotate (in CompanyPaymentGateway screen) |
| CustomCssOverride | injection-risk | enforce CSP — disallow inline `<script>` patterns server-side | sanitize-strip `<script>` blocks; max 8000 chars | log on save |
| Donor PII captured on public form | regulatory | server-side only; never logged in plain text | encrypt-at-rest at column level if regulation requires | log access |
| Anti-fraud markers (IP, UA, velocity) | operational | not on public; visible to admin only via audit | append-only | retain per policy |

**Public-form Hardening (anonymous-route concerns)**:
- Rate-limit donate-button POST: **5 attempts / minute / IP / slug** combined (use `RateLimiterPolicy("DonationSubmit")`)
- CSRF token issued on initial public-page render; required on submit; rotation on each render
- Honeypot field `[name="website"]` hidden via CSS; submission with non-empty honeypot silently rejected (return mocked success to bot)
- reCAPTCHA v3 score check before payment-gateway hand-off — `SERVICE_PLACEHOLDER` until reCAPTCHA configured (returns score=1.0)
- All donor-input fields validated server-side (never trust public client)
- CSP headers on public route: `script-src 'self' https://js.stripe.com https://www.paypal.com; frame-src https://js.stripe.com https://www.paypal.com; style-src 'self' 'unsafe-inline'; img-src * data: https:`
- IFRAME-mode public route adds `X-Frame-Options: ALLOW-FROM *` (or `frame-ancestors *` via CSP) — explicitly allows iframe embedding by 3rd-party sites; NAV-mode keeps `frame-ancestors 'none'`

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Publish | Page goes live; URL becomes shareable | "Publishing makes this page public at /p/{slug}. Confirm?" | log "page published" with snapshot of jsonb config |
| Unpublish | Active → Draft; donations rejected | "Donors will see a 'campaign closed' page. Continue?" | log |
| Close Early | Active → Closed before EndDate; new donations rejected | "Close campaign now? Existing donations stay. {totalRaised} raised so far." | log + email page owner |
| Archive | Soft-delete; URL returns 410 | type-name confirm ("type {pageTitle} to archive") | log |
| Reset Branding | Wipe theme/branding back to defaults (logo, hero, colors, layout, custom CSS) | type-name confirm | log |
| Change ImplementationType post-Active | Re-publishes under different render mode; embed code changes | "Switching mode will break existing embed code on partner sites." | log + warn-banner displayed for 7 days |

**Role Gating**:

| Role | Setup access | Publish access | Notes |
|------|-------------|----------------|-------|
| BUSINESSADMIN | full | yes | full lifecycle (target role for MVP) |
| Anonymous public | no setup access | — | only sees Active public route |

**Workflow** (cross-page — donation flow):
- Anonymous donor visits `/p/{slug}` → fills form → submits with CSRF token
- Server validates → calls gateway tokenize (SERVICE_PLACEHOLDER returns mock token)
- Server creates `fund.GlobalDonation` (with `OnlineDonationPageId = X`) + `fund.GlobalOnlineDonation` (gateway tx record); for recurring, also creates `fund.RecurringDonationSchedule`
- Server upserts `crm.Contact` by email (anonymous toggle hides name in receipt but Contact still created for stewardship)
- Returns redirect URL or thank-you state
- Async: receipt email fires (SERVICE_PLACEHOLDER if email infra missing)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: EXTERNAL_PAGE
**External-Page Sub-type**: `DONATION_PAGE`
**Storage Pattern**: `single-page-record`

**Slug Strategy**: `custom-with-fallback`
> Slug auto-derived from PageTitle on Create; user may override; auto re-applied on each new save when slug field is cleared. Slug becomes immutable once donations attached (link rot guard).

**Lifecycle Set**: `Draft / Published / Active / Closed / Archived` (full)

**Save Model**: `autosave-with-publish`
> Each settings card autosaves on edit (300ms debounce). The top-right "Save & Publish" button explicitly transitions Draft → Active after Validate-for-Publish passes. No "Save" button — implicit autosave + explicit Publish.

**Public Render Strategy**: `ssr`
> Donation pages must be SEO-indexable (Google donate-search results). Use Next.js App Router `(public)/p/[slug]/page.tsx` with `generateMetadata` for OG tags + `revalidate: 60` for ISR. iFrame widget at `/embed/[slug]/page.tsx` uses CSR (no SEO need; embeds already-known site).

**ImplementationType decision** (this screen's defining branch — stamp in §⑥):

| Value | Public Route | Render | Use Case |
|-------|-------------|--------|----------|
| `NAV` | `/p/{slug}` | full hosted page (SSR) — header / hero carousel / impact stats / two-column body / footer | Org doesn't have own website; or wants a campaign-specific landing page |
| `IFRAME` | `/embed/{slug}` | compact widget (CSR, mobile-optimized 480px max) — header / form / footer; PLUS `/widget.js` JS-snippet alternative | Org has own website; wants donate widget embedded in their existing pages |

**Reason**: DONATION_PAGE sub-type fits because the mockup shows a single online donation page with amount chips / recurring options / payment connect / donor-field config / public URL. `single-page-record` storage works because each tenant may have multiple pages and donations link via FK. `custom-with-fallback` slug matches the mockup's editable slug field with URL preview. `autosave-with-publish` matches the mockup's per-card edits + top-right "Save & Publish" button (no per-card Save button shown). SSR for NAV is critical for OG meta + organic-search indexing; CSR for IFRAME is acceptable since embed sites already have SEO.

**Backend Patterns Required**:

For DONATION_PAGE:
- [x] GetAllOnlineDonationPageList query (admin list view) — tenant-scoped, paginated, status filter
- [x] GetOnlineDonationPageById query (admin editor)
- [x] GetOnlineDonationPageBySlug query (public route) — anonymous-allowed, status-gated
- [x] GetOnlineDonationPageStats query — totalRaised, totalDonors, lastDonationAt, conversionRate-PLACEHOLDER
- [x] GetPublishValidationStatus query — returns missing-fields list for the editor
- [x] GetEmbedCode query — returns iframe + JS widget snippets with current slug + accent color
- [x] CreateOnlineDonationPage mutation (defaults to Draft, slug auto, ImplementationType from caller)
- [x] UpdateOnlineDonationPage mutation (full upsert; partial-update via separate mutations for jsonb arrays — see below)
- [x] UpdateOnlineDonationPagePurposes mutation (junction-table batch set)
- [x] PublishOnlineDonationPage mutation — runs ValidateForPublish + transitions Draft → Active
- [x] UnpublishOnlineDonationPage mutation — Active → Draft
- [x] CloseOnlineDonationPage mutation — Active → Closed
- [x] ArchiveOnlineDonationPage mutation — soft-delete (IsDeleted=TRUE) + 410 Gone afterwards
- [x] ResetBrandingOnlineDonationPage mutation — wipe Logo/Hero/Carousel/Colors/Layout/CustomCss
- [x] Slug uniqueness validator + reserved-slug rejection
- [x] Tenant scoping (CompanyId from HttpContext) — anonymous public uses CompanyId resolved from `(slug)` lookup
- [x] Anti-fraud throttle on public submit endpoint (rate-limit attribute)
- [x] InitiateDonation public mutation (anonymous) — creates GlobalDonation+GlobalOnlineDonation rows, returns gateway hand-off URL (SERVICE_PLACEHOLDER returns mock)
- [x] ConfirmDonation public mutation (anonymous gateway-callback) — finalizes status, fires receipt email
- [ ] Real Stripe/PayPal/Razorpay integration → SERVICE_PLACEHOLDER until gateway connect implemented in CompanyPaymentGateway screen

**Frontend Patterns Required**:

For DONATION_PAGE — TWO render trees:
- [x] Admin setup at `setting/publicpages/onlinedonationpage` — list view (when `?id` not present) + editor (`?id=N`)
- [x] Editor: split-pane (settings cards left + live preview right) — 10 settings cards in mockup order
- [x] Implementation Type Switcher — 2 selectable cards above settings; toggling swaps Branding card + Preview render
- [x] Live Preview component — debounced 300ms; 4 variants (NAV/IFRAME × Desktop/Mobile) via device-switcher
- [x] Public NAV page at `(public)/p/[slug]/page.tsx` — SSR, full-page hosted; hero carousel + impact stats + testimonials + two-column body (info+form) + footer
- [x] Public IFRAME widget at `(public)/embed/[slug]/page.tsx` — CSR, 480px max; header + form + footer
- [x] Public JS snippet at `/widget.js` — appends iframe to host site's `<div id="hf-donate-widget">`
- [x] Anonymous donate-form component — shared between NAV + IFRAME; respects DonorFieldsJson + AmountChipsJson + EnabledPaymentMethodsJson
- [x] Thank-you state — inline (within form region) OR redirect to ThankYouRedirectUrl

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: TWO surfaces — (1) admin setup with split-pane editor + 4-variant preview, (2) public render tree with NAV mode + IFRAME mode. Both must match the mockup exactly.

### 🎨 Visual Treatment Rules (apply to all surfaces)

1. **Public page is brand-driven** — hero, carousel, primary color all from tenant's PrimaryColorHex / Logo / Hero. Don't re-use the admin shell.
2. **Admin setup mirrors what the public will see** — every meaningful edit reflected in live preview pane within 300ms (no "save and refresh").
3. **Mobile preview is mandatory** — most donors are on mobile. Preview defaults to Desktop in mockup but Mobile must be a single-click toggle.
4. **Lifecycle state is visually clear** — Status Bar at top of admin setup shows current Status as colored dot + label (Active=green / Draft=gray / Closed=orange / Archived=red). Banner on public Draft preview ("PREVIEW — NOT YET LIVE").
5. **Donate CTA is dominant** — primary `PrimaryColorHex` background, sized to prompt action, sticky on mobile scroll.
6. **Trust signals first-class** — 🔒 Secure / 💳 Cards / ✉ Receipt-by-email visible near button; tax-deductible note + privacy/footer always visible.
7. **Implementation Type switcher must visually distinguish active mode** — selected `impl-card` has accent border + accent background + checkmark; unselected has gray border + empty circle. Both visible side-by-side at all times.
8. **Settings cards consistent chrome** — white card + 12px radius + 1px border + header with phosphor icon + body. Same chrome for all 10 cards.

**Anti-patterns to refuse**:
- Admin chrome bleeding into public route (sidebar visible to anonymous donors)
- "Save and refresh to preview"
- Implementation Type switcher hidden behind a tab — must be visible above settings
- Public form with admin breadcrumbs / dropdowns
- Single hero image stretched without responsive crop
- Branding card showing both NAV + IFRAME fields simultaneously (must swap based on ImplementationType)
- Donate button rendered in inactive Draft preview (must be disabled with "PREVIEW" badge)

---

### A.1 — Admin Setup UI (split-pane: editor left + live preview right)

**Stamp**: `Layout Variant: split-pane (editor + preview)` — NOT a DataTable, NOT FlowDataTable, NOT widgets-above-grid. EXTERNAL_PAGE has its own layout (no FlowDataTableContainer / no ScreenHeader+showHeader=false pattern).

**Page Layout**:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ [🌐 Online Donation Page]                      [← Back] [↗ Preview] [🚀 Save & Publish]│
│ Configure your organization's public donation page                                │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ● Active   Total Raised: $41,450   Total Donors: 221   Conv: 4.8%   Last: 2h ago│  ← Status Bar (real aggregates)
├──────────────────────────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────┐ ┌────────────────────────────────┐           │
│ │ ●Navigation-Based Page  [✓]   │ │ ○ iFrame-Based Form     [○]    │   ← Implementation Type Switcher
│ │ Fully hosted standalone page   │ │ Compact donation form widget   │   (mutually exclusive cards)
│ └────────────────────────────────┘ └────────────────────────────────┘           │
├────────────────────────────────────────────────┬─────────────────────────────────┤
│ EDITOR (10 settings cards stacked)             │ LIVE PREVIEW                    │
│                                                │ Nav Page Preview │ [Desktop|Mobile]│
│ ┌─────────────────────────────────────────┐   │ ┌──────────────────────────────┐│
│ │ 🔗 Page URL & Identity                  │   │ │ ┌──────────────────────────┐ ││
│ │  • Page Title *                         │   │ │ │ 🔒 https://donate.../give│ ││
│ │  • Page URL Slug * → URL preview + copy │   │ │ ├──────────────────────────┤ ││
│ │  • Description                          │   │ │ │ [Web header + nav]       │ ││
│ │  • Page Status toggle                   │   │ │ │ [Hero carousel]          │ ││
│ ├─────────────────────────────────────────┤   │ │ │ [Two-col: info + form]   │ ││
│ │ 🗂 Donation Purposes                    │   │ │ │ [Web footer]             │ ││
│ │  • Multi-select tag picker (5 default)  │   │ │ └──────────────────────────┘ ││
│ │  • Default purpose dropdown             │   │ └──────────────────────────────┘│
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 💲 Amounts & Currency                   │   │ (Re-renders within 300ms on     │
│ │  • Suggested amount chips + add/remove  │   │  any settings-card edit)         │
│ │  • Minimum amount + Primary currency    │   │                                  │
│ │  • Multi-currency toggle                │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🔁 Recurring Donations                  │   │                                  │
│ │  • Allow toggle                         │   │                                  │
│ │  • Frequency chips (W/M/Q/SA/A)         │   │                                  │
│ │  • Default-to-recurring + default freq  │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 💳 Payment Methods                      │   │                                  │
│ │  • Gateway dropdown                     │   │                                  │
│ │  • Method checkbox list                 │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 👤 Donor Form Fields (table 9 fields)   │   │                                  │
│ │  Field   Required Visible               │   │                                  │
│ │  First*    [✓ disabled] [✓ disabled]    │   │                                  │
│ │  Last*     [✓ disabled] [✓ disabled]    │   │                                  │
│ │  Email*    [✓ disabled] [✓ disabled]    │   │                                  │
│ │  Phone     [✓]   [✓]                    │   │                                  │
│ │  Address   [ ]   [ ]                    │   │                                  │
│ │  Org       [ ]   [ ]                    │   │                                  │
│ │  Message   [ ]   [✓]                    │   │                                  │
│ │  Anonymous [ ]   [✓]                    │   │                                  │
│ │  Dedicate  [ ]   [✓]                    │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ 🎨 Page Branding [NAV BADGE]            │   │  (Card swaps between NAV/IFRAME │
│ │  • Logo upload                          │   │   based on switcher above)       │
│ │  • Carousel slides (image OR video)     │   │                                  │
│ │  • Primary color + Button text          │   │                                  │
│ │  • Page Layout select                   │   │                                  │
│ │  • Custom CSS textarea                  │   │                                  │
│ │ ──── OR (when IFRAME selected) ────     │   │                                  │
│ │ </> iFrame Configuration [IFRAME BADGE] │   │                                  │
│ │  • Form Accent Color                    │   │                                  │
│ │  • Button Text                          │   │                                  │
│ │  • Show form header toggle              │   │                                  │
│ │  • Show powered-by footer toggle        │   │                                  │
│ │  • Embed Code (read-only) + copy        │   │                                  │
│ │  • JS Widget snippet + copy             │   │                                  │
│ ├─────────────────────────────────────────┤   │                                  │
│ │ ⚙ Thank You & Advanced                  │   │                                  │
│ │  • Thank-you message + Redirect URL     │   │                                  │
│ │  • Goal Amount + End Date               │   │                                  │
│ │  • Donor count + Social share toggles   │   │                                  │
│ │  • Tax receipt note                     │   │                                  │
│ └─────────────────────────────────────────┘   │                                  │
└────────────────────────────────────────────────┴─────────────────────────────────┘
```

**Settings Cards** (10 — order matches mockup; matches public render order top-to-bottom):

| # | Card | Icon (phosphor) | Save Model | Notes |
|---|------|-----------------|------------|-------|
| 1 | Page URL & Identity | `ph:link` | autosave | PageTitle + Slug (with URL preview + copy) + Description + Page Status toggle |
| 2 | Donation Purposes | `ph:stack` | autosave | Multi-select tag picker sourced from `donationPurposes` GQL (filter by tenant) + default-purpose dropdown filtered to selected ones; saves to junction table on each change |
| 3 | Amounts & Currency | `ph:currency-dollar` | autosave | Amount chips (chip-editor add/remove, max 8) + Minimum + Primary currency dropdown (`currencies` GQL) + Multi-currency toggle |
| 4 | Recurring Donations | `ph:arrows-clockwise` | autosave | Allow-recurring toggle (gates inner block) + 5 frequency chips W/M/Q/SA/A (toggle = active) + Default-to-recurring + Default freq dropdown (filtered to active chips) |
| 5 | Payment Methods | `ph:credit-card` | autosave | Gateway dropdown (`companyPaymentGateways` filtered to current tenant) + Methods checkbox list (5 methods: Card/PayPal/UPI/Bank/Wallet) |
| 6 | Donor Form Fields | `ph:user` | autosave | 9-row table; First/Last/Email locked-required-visible (disabled checkboxes); Phone/Address/Organization/Message/Anonymous/Dedicate editable; saves to DonorFieldsJson |
| 7a | Page Branding (NAV mode only) | `ph:palette` | autosave | Logo upload + Carousel slides config (max 5; image OR YouTube embed; reorderable) + Primary color picker + Button text + Page Layout select (centered/side-by-side/full-width) + Custom CSS textarea |
| 7b | iFrame Configuration (IFRAME mode only) | `ph:code` | autosave + read-only embed | Accent color + Button text + Show form header toggle + Show powered-by footer toggle + Embed Code (read-only with copy) + JS Widget snippet (read-only with copy) |
| 8 | Thank You & Advanced | `ph:gear` | autosave | Thank-you message textarea + Redirect URL + Goal Amount + End Date + Donor count toggle + Social share toggle + Tax receipt note textarea |
| 9 | Landing Content (NAV / STANDARD only) | `ph:layout` | autosave (diff-only upsert) | **Added 2026-07-16.** Edits the generic `OnlineDonationPageSettings` rows that back the STANDARD (Aurora) landing sections. One collapsible sub-panel per `SectionCode` — see table below. Repeating lists (benefit cards, why-donate items, impact stats, socials, useful links) use a **row-repeater** editor (add/remove/reorder), each persisted as a single `json`-typed row. Scalars (mission title/body, section headings) persist as `string`/`text` rows. Hidden when ImplementationType = IFRAME (widget has no landing sections). Empty a row → renderer falls back to the template default |

**Card 9 — Landing Content sub-panels** (each maps to `OnlineDonationPageSettings` rows from §②'s catalog; the admin widget is chosen by `ParamDataType`):

| Sub-panel (SectionCode) | Editor widget | Persists as |
|-------------------------|---------------|-------------|
| Hero Benefits (`HERO_BENEFITS`) | Row-repeater ×3: icon-picker + title + short desc | `BENEFIT_CARDS` (json) |
| Why Donate (`WHY_DONATE`) | Heading text field + row-repeater ×4: icon + title + desc | `WHY_DONATE_TITLE` (string) + `WHY_DONATE_ITEMS` (json) |
| Impact Stats (`IMPACT_STATS`) | Row-repeater ×N: big value + label | `IMPACT_STATS` (json) |
| Mission (`MISSION`) | Title field + body textarea | `MISSION_TITLE` (string) + `MISSION_BODY` (text) |
| Footer (`FOOTER`) | Contact group (address/phone/email) + socials repeater (platform-picker + url) + useful-links repeater (label + url) | `FOOTER_CONTACT` (json) + `FOOTER_SOCIALS` (json) + `FOOTER_LINKS` (json) |

> Icon-picker values are `@iconify` Phosphor names (e.g. `ph:heart`, `ph:hand-heart`, `ph:users-three`); the renderer resolves them via `<Icon icon={...} />`. Store the string name, never markup.

**Implementation Type Switcher** (between Status Bar and settings cards):

| Element | Behavior |
|---------|----------|
| 2 cards side-by-side | Click toggles ImplementationType between `NAV` and `IFRAME` |
| Selected card | accent border + accent background + checkmark icon top-right |
| Unselected card | gray border + empty circle top-right |
| Confirmation when changing post-Active | Modal "Switching mode will break existing embed code on partner sites. Continue?" — only when Status = Active AND ≥1 donation attached |

**Live Preview Behavior**:
- Updates on every settings-card edit (debounced 300ms; client-side state, NOT round-trip to server)
- Mobile / Desktop toggle in preview-toolbar changes preview viewport width (375px phone-frame for Mobile; full-width browser-chrome for Desktop)
- 4 preview variants: `nav-desktop` / `nav-mobile` / `iframe-desktop` / `iframe-mobile` — selected by `ImplementationType × device`
- `iframe-desktop` shows IFRAME widget rendered INSIDE a third-party host-site mockup (gray header + content blocks + sidebar where the iframe lives)
- `iframe-mobile` shows IFRAME widget rendered INSIDE a phone-frame'd host site
- "Open in new tab" button on Draft → uses preview-token query param

**Page Actions** (top-right):

| Action | Position | Style | Confirmation |
|--------|----------|-------|--------------|
| Back | top-right | outline-accent | navigates to setup list view |
| Preview Full Page | top-right | outline-accent | opens public route in new tab with preview-token if Draft |
| Save & Publish | top-right | primary-accent | runs Validate-for-Publish; if pass → "Publishing makes this page public at /p/{slug}." → transitions Draft → Active; if fail → modal lists missing fields |
| Unpublish | overflow menu (when Active) | secondary | "Donors will see a 'campaign closed' page." |
| Close Early | overflow menu (when Active) | destructive | "Close now? Existing donations stay. {totalRaised} raised." |
| Archive | overflow menu | destructive | type-name confirm |
| Reset Branding | overflow menu | destructive | type-name confirm |

**Setup List View** (when `?id` not present in URL):

- Grid layout — 1 row per OnlineDonationPage (this tenant)
- Columns: PageTitle / Slug (linked) / ImplementationType badge / Status badge / TotalRaised / TotalDonors / LastDonationAt / Actions (Edit/Open Public/Archive)
- "+ New Page" button top-right → creates Draft + redirects to editor
- Empty state: "Create your first donation page to start accepting donations online." + primary CTA

### A.2 — Public NAV Page (anonymous route at `(public)/p/[slug]/page.tsx`)

**Page Layout** (SSR; mobile-first; donate form sticky on mobile):

```
┌────────────────────────────────────────────────────────────┐
│ [Web Header — Org logo + nav links — gradient bg]          │
│ Hope Foundation         Home  About Us  Programs  Donate ◊ │
├────────────────────────────────────────────────────────────┤
│ [Hero Carousel — full bleed, 160-400px, image+video slides]│
│ Together We Change Lives                                   │
│ Your generosity empowers communities                       │
│                                              ●○○ (3 dots)  │
├──────────────────────┬─────────────────────────────────────┤
│ INFO COLUMN (45%)    │ FORM COLUMN (55%)                   │
│ Our Mission ...      │ ▶ Choose a Cause [select]           │
│ ┌──────┬──────┐      │ ▶ $41,450 of $50,000 (83%)          │
│ │ 2M+  │ 40   │      │   221 donors have contributed       │
│ │ Lives│ Cnts │      │ ▶ Select Amount                     │
│ └──────┴──────┘      │   $25 [$50] $100 $250 $500 Other    │
│ ┌──────┬──────┐      │ ▶ ☑ Make this recurring             │
│ │ $12M │ 98%  │      │     Weekly [Monthly] Quarterly Annual│
│ │Raised│Prgm  │      │ ▶ Your Information                  │
│ └──────┴──────┘      │   First Name * Last Name *          │
│ ┌─ Watch Impact ──┐  │   Email * Phone                     │
│ │ ▶ Video         │  │   ☐ Anonymous donation              │
│ └─────────────────┘  │   ☐ Dedicate this gift              │
│ ┌─ Testimonial ──┐   │ ▶ Payment Method                    │
│ │ "Thanks ..."   │   │   [Card] PayPal Wallet              │
│ │ — Maria S.     │   │ [DONATE NOW $50]                    │
│ └────────────────┘   │ Tax-deductible 501(c)(3)            │
│                      │ [f] [t] [w] (social share)          │
├──────────────────────┴─────────────────────────────────────┤
│ Hope Foundation © 2026 • Privacy • Terms                   │
└────────────────────────────────────────────────────────────┘
```

**Layout Variants** based on `PageLayout` field:

| PageLayout | Render |
|------------|--------|
| `centered` | Hero on top, form-only column below (info section pushed below form) |
| `side-by-side` | Default mockup layout — info-left + form-right two-column |
| `full-width` | Hero full-bleed; form floats as overlay card centered on hero |

**STANDARD (Aurora) landing sections — data-driven from `landingContent` (added 2026-07-16)**:

The INFO COLUMN and page chrome sketched above are **no longer hard-coded**. The STANDARD template renders these sections from the `publicData.landingContent` projection (§⑩), which the BE assembles from the page's `OnlineDonationPageSettings` rows. Each section renders ONLY if its setting is present and non-empty; otherwise the template's built-in default renders (so pre-revision pages still look complete). Order top-to-bottom:

| Section | Source (landingContent key) | Fallback when null/empty |
|---------|-----------------------------|--------------------------|
| Hero benefit cards (3-up under hero) | `heroBenefits[]` `{icon,title,desc}` | 3 generic trust cards |
| "Why Your Donation Matters" (heading + 4-up grid) | `whyDonateTitle` + `whyDonate[]` `{icon,title,desc}` | Section hidden |
| Impact stats strip | `impactStats[]` `{value,label}` | Uses live aggregates (totalRaised/donorCount) only |
| Mission block (title + body) | `missionTitle` + `missionBody` | Section hidden |
| Footer (contact + socials + useful links) | `footerContact{address,phone,email}` + `footerSocials[]` + `footerLinks[]` | Minimal `© {orgName}` footer |

- Everything is **DATA (dynamic, tenant-editable); the Aurora layout/spacing/section order is STATIC** — the design principle for this revision. The template never invents copy beyond the coded fallbacks.
- The FORM COLUMN, hero carousel, goal strip, amount chips, recurring, donor fields, payment methods are unchanged (existing page columns / junction), NOT part of `landingContent`.
- Icons are `@iconify` Phosphor names resolved at render (`<Icon icon={c.icon} />`). URLs in footer/social/links are rendered as `rel="noopener noreferrer"` external anchors.

**Template renderer registry — `pageTypeCode` → template component (ISSUE-42, session 54)**:

The public renderer `donation-page.tsx` is a **dispatcher** (already built — do NOT rebuild). It resolves `PageTypeId` → MasterData `DataValue` (`pageTypeCode`) and switches to the matching template in `public/onlinedonationpage/templates/` (two parallel switches: page view + thank-you view). Unknown/missing codes degrade to Aurora (STANDARD). New template variant = **1 MasterData row (`TypeCode=ONLINEDONATIONPAGETYPE`)** + settings catalog rows (MEDIA/§②) + **ONE renderer component** — no schema change. Media/content is fed from the assembled EAV channel (`carouselSlides`, `heroImageUrl`, `logoUrl`), never from typed columns.

| `pageTypeCode` (DataValue) | Page template | Thank-you template |
|----------------------------|---------------|--------------------|
| `STANDARD` (+ unknown fallback) | `template-aurora.tsx` | `thank-you-aurora.tsx` |
| `IMAGE` / `VIDEO` / `CAROUSEL` / image-position variants | existing per-variant templates | matching thank-you variant |
| `CAROUSEL_VIDEO` **(new)** | `template-gallery-video.tsx` (image carousel + video hero panel) | `thank-you-gallery-video.tsx` |
| `CAROUSEL_IMAGE` **(new)** | `template-gallery-image.tsx` (carousel + full-bleed hero image) | `thank-you-gallery-image.tsx` |

> Combo templates reuse shared primitives (DonateFormSection, GoalProgressStrip, ClosedBanner, CustomCssInjector, FineFooter, SuccessCheck, SocialShareButtons) unmodified. Carousel filters `carouselSlides` to `type==="image"`; the video panel takes the first `type==="video"` slide; graceful fallbacks when a media channel is empty.

**Public-route behavior**:
- SSR with `revalidate: 60` (page metadata caches 60s; OG tags pre-rendered)
- Anonymous-allowed (no auth gate); CSP headers strict (see §④)
- CSRF token issued in initial render; required on submit
- Honeypot field hidden via CSS
- On submit: client-side gateway tokenization (SERVICE_PLACEHOLDER → mock token) → server creates GlobalDonation → redirect to thank-you
- On gateway failure: inline error, retain form state
- On success: ThankYouMessage shown inline OR redirect to ThankYouRedirectUrl

**Edge states**:
- `Status = Draft` → 404 (unless `?previewToken=` in querystring)
- `Status = Closed` → renders page with "This campaign has ended" banner; donate disabled
- `Status = Archived` → 410 Gone
- Within Active window but `EnabledPaymentMethodsJson` empty → "Donations temporarily unavailable" inline message
- Goal met → progress bar caps at 100% with "Goal met!" badge; donations still accepted (no all-or-nothing)
- EndDate passed but Status not yet auto-flipped → server-side flip on next request

### A.3 — Public IFRAME Widget (`(public)/embed/[slug]/page.tsx` + `/widget.js` snippet)

**Widget Layout** (max-width 480px; CSR-rendered; inside any host site iframe):

```
┌──────────────────────────────────┐
│ [Header — when IframeShowHeader]│
│ Support Hope Foundation          │
│ Choose a cause and donate ...    │
├──────────────────────────────────┤
│ Donation Purpose [select]        │
│ Amount: $25 [$50] $100 $250 Other│
│ ☐ Recurring                      │
│   Weekly [Monthly] Quarterly Annual│
│ First Name * Last Name *         │
│ Email * Phone                    │
│ ☐ Anonymous                      │
│ Payment: [Card] PayPal Wallet    │
│ [DONATE NOW]                     │
│ Tax-deductible                   │
├──────────────────────────────────┤
│ Powered by PeopleServe 2.0       │  (when IframeShowFooter)
└──────────────────────────────────┘
```

**Embed Snippets** (rendered into IFRAME-mode setup card; admin copies):

```html
<!-- IFRAME embed -->
<iframe
  src="https://{tenant-domain}/embed/{slug}"
  width="100%" height="800" frameborder="0"
  style="border:none; max-width:480px;"
  allow="payment"></iframe>

<!-- JS widget alternative -->
<div id="hf-donate-widget"></div>
<script src="https://{tenant-domain}/widget.js"
  data-org="{tenant-slug}"
  data-color="{primaryColorHex}"></script>
```

**`/widget.js`** — small JS that finds `#hf-donate-widget` (or any `[data-pps-donate]` div) and injects an iframe pointing at `/embed/{slug}`. Keeps iframe-tokenization PCI-scope contained.

**Public-route behavior (IFRAME)**:
- CSR (no SEO need; embed sites already indexed)
- `X-Frame-Options: ALLOW-FROM *` (or CSP `frame-ancestors *`)
- CSRF + rate-limit + honeypot identical to NAV
- Form submit posts to same `/api/public/initiate-donation` as NAV

**Edge states (IFRAME)**:
- Same as NAV (Draft 404, Closed banner, Archived 410)
- Sold-out / unavailable message renders inside the 480px widget — host site sees a small status card

---

### Page Header & Breadcrumbs (admin setup)

| Element | Content |
|---------|---------|
| Breadcrumb | Setting › Public Pages › Online Donation Page |
| Page title | 🌐 Online Donation Page |
| Subtitle | Configure your organization's public donation page |
| Status badge | Draft / Published / Active / Closed / Archived (color-coded) |
| Right actions | [Back] [Preview Full Page] [Save & Publish] + overflow menu (Unpublish/Close/Archive/Reset Branding) |

### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading (setup list) | Initial fetch | Skeleton 5 rows |
| Loading (setup editor) | Initial fetch | Skeleton matching 10 cards layout |
| Loading (public NAV) | SSR streaming | progressive — header first, hero placeholder, form placeholder |
| Loading (public IFRAME) | CSR | skeleton inside 480px widget |
| Empty (setup list) | No pages yet | "Create your first donation page" + primary CTA |
| Error (setup) | GET fails | Error card with retry button |
| Error (public) | Slug not found | 404 page with org-default redirect link |
| Closed (public) | Status = Closed | Banner "This campaign has ended" + final raised amount |

---

## ⑦ Substitution Guide

> **First DONATION_PAGE EXTERNAL_PAGE in PSS 2.0** — this entity establishes the canonical reference. Future DONATION_PAGE planners should copy from `onlinedonationpage.md` (this file) as their substitution base.

| Canonical (this entity) | → This Entity | Context |
|-------------------------|---------------|---------|
| OnlineDonationPage | OnlineDonationPage | Entity / class name (PascalCase) |
| onlineDonationPage | onlineDonationPage | Variable / field names (camelCase) |
| onlinedonationpage | onlinedonationpage | FE folder / route segment (lowercase) |
| ONLINEDONATIONPAGE | ONLINEDONATIONPAGE | MenuCode / GridCode (UPPERCASE) |
| online-donation-page | online-donation-page | kebab-case (file/component names) |
| `fund` | `fund` | DB schema |
| `DonationModels` | `DonationModels` | Backend group |
| `donation-service` | `donation-service` | FE entity domain folder |
| `setting/publicpages/onlinedonationpage` | `setting/publicpages/onlinedonationpage` | Admin FE route |
| `(public)/p/[slug]` | `(public)/p/[slug]` | Public NAV route |
| `(public)/embed/[slug]` | `(public)/embed/[slug]` | Public IFRAME route |
| ParentMenu: `SET_PUBLICPAGES` | (same) | Sidebar parent |
| Module: `SETTING` | (same) | Module code |

> **NOTE**: Even though screen #10 is registered under "FUNDRAISING MODULE" section (because the mockup file is at `html_mockup_screens/screens/fundraising/`), the MENU lives under SET_PUBLICPAGES (Module=SETTING). The FE route is `setting/publicpages/onlinedonationpage`. Do NOT try to create FE files under `crm/donation/`.

---

## ⑧ File Manifest

> Counts: BE ≈ 22 files; FE ≈ 26 files; 1 DB seed; ≥1 EF migration. ImplementationType branching does NOT double the file count — same entity, same forms, different render trees.

### Backend Files (NEW — 22)

| # | File | Path |
|---|------|------|
| 1 | Entity | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/OnlineDonationPage.cs` |
| 2 | Junction Entity | `Pss2.0_Backend/.../Base.Domain/Models/DonationModels/OnlineDonationPagePurpose.cs` |
| 3 | EF Config (parent) | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/DonationConfigurations/OnlineDonationPageConfiguration.cs` |
| 4 | EF Config (junction) | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/DonationConfigurations/OnlineDonationPagePurposeConfiguration.cs` |
| 5 | Schemas (DTOs) | `Pss2.0_Backend/.../Base.Application/Schemas/DonationSchemas/OnlineDonationPageSchemas.cs` (RequestDto / ResponseDto / PublicDto / StatsDto / ValidationResultDto / EmbedCodeDto / DonorFieldConfig / etc.) |
| 6 | GetAll Query | `Pss2.0_Backend/.../Base.Application/Donations/OnlineDonationPages/GetAllQuery/GetAllOnlineDonationPagesList.cs` |
| 7 | GetById Query | `…/OnlineDonationPages/GetByIdQuery/GetOnlineDonationPageById.cs` |
| 8 | GetBySlug Query (public) | `…/OnlineDonationPages/PublicQueries/GetOnlineDonationPageBySlug.cs` (anonymous-allowed) |
| 9 | GetStats Query | `…/OnlineDonationPages/GetStatsQuery/GetOnlineDonationPageStats.cs` |
| 10 | GetEmbedCode Query | `…/OnlineDonationPages/GetEmbedCodeQuery/GetOnlineDonationPageEmbedCode.cs` |
| 11 | GetPublishValidation Query | `…/OnlineDonationPages/ValidateForPublishQuery/ValidateOnlineDonationPageForPublish.cs` |
| 12 | Create Command | `…/OnlineDonationPages/CreateCommand/CreateOnlineDonationPage.cs` |
| 13 | Update Command | `…/OnlineDonationPages/UpdateCommand/UpdateOnlineDonationPage.cs` |
| 14 | UpdatePurposes Command | `…/OnlineDonationPages/UpdatePurposesCommand/UpdateOnlineDonationPagePurposes.cs` (junction batch set) |
| 15 | Lifecycle Commands (4) | `…/OnlineDonationPages/LifecycleCommands/{Publish,Unpublish,Close,Archive}OnlineDonationPage.cs` |
| 16 | ResetBranding Command | `…/OnlineDonationPages/ResetBrandingCommand/ResetOnlineDonationPageBranding.cs` |
| 17 | InitiateDonation Public Mutation | `…/OnlineDonationPages/PublicMutations/InitiateOnlineDonation.cs` (anonymous-allowed, rate-limited) |
| 18 | ConfirmDonation Public Mutation | `…/OnlineDonationPages/PublicMutations/ConfirmOnlineDonation.cs` (anonymous gateway-callback) |
| 19 | Slug Validator | `…/Base.Application/Validators/OnlineDonationPageSlugValidator.cs` |
| 20 | Mutations endpoint | `Pss2.0_Backend/.../Base.API/EndPoints/DonationModels/Mutations/OnlineDonationPageMutations.cs` |
| 21 | Queries endpoint (admin) | `…/EndPoints/DonationModels/Queries/OnlineDonationPageQueries.cs` |
| 22 | Public endpoint | `…/EndPoints/DonationModels/Public/OnlineDonationPagePublicQueries.cs` (anonymous-allowed, rate-limited, csrf-validated) |
| 23 | **Settings Entity (generic)** | `Pss2.0_Backend/.../Base.Domain/Models/DonationModels/OnlineDonationPageSetting.cs` — added 2026-07-16. Page-scoped EAV row (§②) |
| 24 | **Settings EF Config** | `…/Data/Configurations/DonationConfigurations/OnlineDonationPageSettingConfiguration.cs` — filtered unique `(OnlineDonationPageId, ParamCode)` + `(OnlineDonationPageId, SectionCode, OrderBy)` index |
| 25 | **SaveLandingContent Command** | `…/OnlineDonationPages/SaveLandingContentCommand/SaveOnlineDonationPageLandingContent.cs` — diff-only upsert of settings rows; JSON-parse validation for `json` types |
| 26 | **DefaultLandingContent seeder helper** | `…/OnlineDonationPages/Helpers/DefaultOnlineDonationPageSettings.cs` — the STANDARD-template default rows seeded on Create (idempotent `NOT EXISTS`). Also assembles `LandingContentDto` from rows (reused by GetById + GetBySlug) |

### Backend Wiring Updates (5)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IDonationDbContext.cs` | `DbSet<OnlineDonationPage>` + `DbSet<OnlineDonationPagePurpose>` + `DbSet<OnlineDonationPageSetting>` |
| 2 | `DonationDbContext.cs` | DbSet entries (incl. `OnlineDonationPageSettings`) |
| 3 | `Base.Application/Extensions/DecoratorProperties.cs` | `DecoratorDonationModules.OnlineDonationPage` + `.OnlineDonationPagePurpose` + `.OnlineDonationPageSetting` |
| 4 | `DonationMappings.cs` | Mapster mapping config (parent + junction; jsonb properties via `IgnoreUnmappedMember` or explicit `Map`) |
| 5 | EF Migration | `Add_OnlineDonationPage_And_Junction_Plus_FK_On_GlobalDonations` — creates both tables + filtered unique index on (CompanyId, LOWER(Slug)) + adds `OnlineDonationPageId int NULL FK` to `fund.GlobalDonations`. **Second migration** `Add_OnlineDonationPageSettings` (added 2026-07-16) — creates `fund.OnlineDonationPageSettings` + its two indexes. **SPEC ONLY — user authors & runs both migrations** ([[feedback-migrations-strictly-user-owned]]) |

### Frontend Files (NEW — 26)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/donation-service/OnlineDonationPageDto.ts` (RequestDto / ResponseDto / PublicDto / StatsDto / ValidationResultDto / EmbedCodeDto / DonorFieldsConfig / CarouselSlide / etc.) |
| 2 | GQL Query (admin) | `…/infrastructure/gql-queries/donation-queries/OnlineDonationPageQuery.ts` |
| 3 | GQL Query (public) | `…/infrastructure/gql-queries/public-queries/OnlineDonationPagePublicQuery.ts` |
| 4 | GQL Mutation | `…/infrastructure/gql-mutations/donation-mutations/OnlineDonationPageMutation.ts` |
| 5 | GQL Mutation (public) | `…/infrastructure/gql-mutations/public-mutations/OnlineDonationPagePublicMutation.ts` |
| 6 | Page Config (admin) | `…/presentation/pages/setting/publicpages/onlinedonationpage.tsx` (default-import dispatcher; URL `?id=N` switches list ↔ editor) |
| 7 | Pages barrel update | `…/presentation/pages/setting/publicpages/index.ts` |
| 8 | List View | `…/presentation/components/page-components/setting/publicpages/onlinedonationpage/list-page.tsx` |
| 9 | Editor (split-pane) | `…/onlinedonationpage/editor-page.tsx` (status bar + impl-switcher + 10-card editor + live preview pane) |
| 10 | Status Bar | `…/onlinedonationpage/components/status-bar.tsx` (Active dot + 4 stat items + dividers) |
| 11 | Impl Type Switcher | `…/onlinedonationpage/components/impl-type-switcher.tsx` (2 selectable cards) |
| 12 | Settings Card 1 (Identity) | `…/onlinedonationpage/sections/identity-section.tsx` |
| 13 | Settings Card 2 (Purposes) | `…/onlinedonationpage/sections/purposes-section.tsx` (multi-select tag picker) |
| 14 | Settings Card 3 (Amounts) | `…/onlinedonationpage/sections/amounts-section.tsx` (chip editor) |
| 15 | Settings Card 4 (Recurring) | `…/onlinedonationpage/sections/recurring-section.tsx` (frequency chips) |
| 16 | Settings Card 5 (Payment) | `…/onlinedonationpage/sections/payment-methods-section.tsx` |
| 17 | Settings Card 6 (Donor Fields) | `…/onlinedonationpage/sections/donor-fields-section.tsx` (9-row table) |
| 18 | Settings Card 7a (NAV Branding) | `…/onlinedonationpage/sections/nav-branding-section.tsx` (logo + carousel + colors + layout + CSS) |
| 19 | Settings Card 7b (IFRAME Config) | `…/onlinedonationpage/sections/iframe-config-section.tsx` (accent + toggles + embed code + JS snippet) |
| 20 | Settings Card 8 (Thank You) | `…/onlinedonationpage/sections/thank-you-section.tsx` |
| 21 | Live Preview component | `…/onlinedonationpage/components/live-preview.tsx` (4-variant render: nav-desktop / nav-mobile / iframe-desktop / iframe-mobile) |
| 22 | Editor Zustand store | `…/onlinedonationpage/onlinedonationpage-store.ts` (autosave debounce queue + dirty-fields tracking + preview state mirror) |
| 23 | Public NAV page | `…/presentation/components/page-components/public/onlinedonationpage/donation-page.tsx` (full-page hosted) |
| 24 | Public donation form | `…/public/onlinedonationpage/components/donation-form.tsx` (shared between NAV + IFRAME) |
| 25 | Public IFRAME widget | `…/public/onlinedonationpage/components/iframe-widget.tsx` (480px max-width compact form) |
| 26 | Public thank-you | `…/public/onlinedonationpage/components/thank-you.tsx` |
| 27 | Route Page (admin) | `src/app/[lang]/setting/publicpages/onlinedonationpage/page.tsx` (overwrite existing under-construction stub with default-import re-export of pages config) |
| 28 | Route Page (public NAV) | `src/app/[lang]/(public)/p/[slug]/page.tsx` (SSR with generateMetadata) |
| 29 | Route Page (public IFRAME) | `src/app/[lang]/(public)/embed/[slug]/page.tsx` (CSR) |
| 30 | JS widget snippet | `public/widget.js` (small loader appending iframe to host's `#hf-donate-widget`) |
| 31 | **Settings Card 9 (Landing Content)** | `…/onlinedonationpage/sections/landing-content-section.tsx` — added 2026-07-16. 5 collapsible sub-panels + row-repeaters (§⑥ Card 9); reads/writes `landingContent`; NAV-mode only |
| 32 | **Row-repeater primitive** | `…/onlinedonationpage/components/landing-repeater.tsx` — add/remove/reorder rows for benefit cards / why-donate / stats / socials / links; each maps to one json setting |
| 33 | **Aurora template upgrade** | `…/public/onlinedonationpage/templates/template-aurora.tsx` — **MODIFY (not new).** STANDARD template renders hero-benefits / why-donate / impact-stats / mission / rich-footer from `publicData.landingContent` with coded fallbacks (§⑥ A.2). Layout STATIC; content DYNAMIC |
| 34 | **Aurora landing sections** | `…/public/onlinedonationpage/templates/aurora/{HeroBenefits,WhyDonate,ImpactStats,MissionBlock,RichFooter}.tsx` — small presentational sub-components consumed by template-aurora; each takes its slice of `landingContent` + `accent` |

> DTO file (#1) also gains `LandingContentDto` + `landingContent` on ResponseDto/PublicDto; admin GQL query/mutation (#2/#4) add the `landingContent` selection + `saveOnlineDonationPageLandingContent`; public GQL query (#3) adds the `landingContent` selection.

### Frontend Wiring Updates (5)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `…/operations-config/donation-service-entity-operations.ts` (or new `setting-service-entity-operations.ts` if absent) | `ONLINEDONATIONPAGE` block with create / update / delete / publish / unpublish / archive ops |
| 2 | `…/operations-config/operations-config.ts` | Import + register operations |
| 3 | `…/domain/entities/donation-service/index.ts` | Export `OnlineDonationPageDto` |
| 4 | `…/infrastructure/gql-queries/donation-queries/index.ts` + `…/gql-mutations/donation-mutations/index.ts` | Export new query/mutation files |
| 5 | Sidebar / sidebar config | Menu entry under `SET_PUBLICPAGES` parent (auto-rendered from BE seed if dynamic-menu pattern is used; otherwise static config update) |

> **Public route group `(public)`** — confirm the `[lang]/(public)/` route group exists. If not, create the route group with a minimal `layout.tsx` that does NOT load admin chrome (no sidebar, no admin header, no auth gate). Provide a slim public layout with just `<html>` shell + `<main>` slot.

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Online Donation Page
MenuCode: ONLINEDONATIONPAGE
ParentMenu: SET_PUBLICPAGES
Module: SETTING
MenuUrl: setting/publicpages/onlinedonationpage
GridType: EXTERNAL_PAGE

MenuCapabilities: READ, CREATE, MODIFY, DELETE, PUBLISH, UNPUBLISH, ARCHIVE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, PUBLISH, UNPUBLISH, ARCHIVE

GridFormSchema: SKIP
GridCode: ONLINEDONATIONPAGE
---CONFIG-END---
```

> `GridType: EXTERNAL_PAGE` is a NEW GridType — register it in the GridType enum + seed (this prompt's seed script must add the GridType row if not present).
> `GridFormSchema: SKIP` — custom UI (split-pane editor + 10 settings cards), not RJSF modal.
> 4 lifecycle capabilities (`PUBLISH / UNPUBLISH / ARCHIVE`) gate top-right action buttons in the editor.
> The public route is anonymous — no menu / role check applies on `/p/{slug}` or `/embed/{slug}`.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types**:
- Admin Query type: `OnlineDonationPageQueries`
- Admin Mutation type: `OnlineDonationPageMutations`
- Public Query type: `OnlineDonationPagePublicQueries` (anonymous-allowed)
- Public Mutation type: `OnlineDonationPagePublicMutations` (anonymous-allowed, rate-limited, csrf-protected)

### Admin Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `onlineDonationPages` | `OnlineDonationPagePagedResponse` | pageSize, pageIndex, sortColumn, sortDescending, searchTerm, advancedFilter |
| `onlineDonationPageById` | `OnlineDonationPageResponse` | onlineDonationPageId |
| `onlineDonationPageStats` | `OnlineDonationPageStatsResponse` | onlineDonationPageId |
| `onlineDonationPageEmbedCode` | `OnlineDonationPageEmbedCodeResponse` | onlineDonationPageId |
| `validateOnlineDonationPageForPublish` | `OnlineDonationPageValidationResponse` (success + missingFields[]) | onlineDonationPageId |

### Admin Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createOnlineDonationPage` | `OnlineDonationPageRequest` (PageTitle, ImplementationType, …minimal Draft fields) | `int` (id) |
| `updateOnlineDonationPage` | `OnlineDonationPageRequest` (full or partial via separate mutations on jsonb) | `int` |
| `updateOnlineDonationPagePurposes` | `(onlineDonationPageId, purposeIds[])` | `int` |
| `publishOnlineDonationPage` | `(onlineDonationPageId)` | `OnlineDonationPageResponse` |
| `unpublishOnlineDonationPage` | `(onlineDonationPageId)` | `OnlineDonationPageResponse` |
| `closeOnlineDonationPage` | `(onlineDonationPageId)` | `OnlineDonationPageResponse` |
| `archiveOnlineDonationPage` | `(onlineDonationPageId)` | `int` |
| `resetOnlineDonationPageBranding` | `(onlineDonationPageId)` | `int` |
| `saveOnlineDonationPageLandingContent` | `(onlineDonationPageId, sections: [{ sectionCode, paramCode, paramName?, paramDataType, paramValue, orderBy }])` | `int` — **added 2026-07-16.** Diff-only upsert into `OnlineDonationPageSettings` (insert new `ParamCode`, update changed `ParamValue`, soft-delete rows the payload drops). Tenant/page ownership enforced server-side; `paramValue` for `json` types validated as parseable JSON before write |

> The generic landing-content rows can also ride inside `updateOnlineDonationPage` if the build agent prefers one save path — but a **dedicated diff-only mutation is recommended** (matches the MATRIX_CONFIG diff-only convention and keeps the row set queryable). Do NOT put landing content on the page's jsonb columns.

### Public Queries (anonymous)

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `onlineDonationPageBySlug` | `OnlineDonationPagePublicResponse` (only public-safe fields — see DTO Privacy) | slug, tenantSlug? |
| `onlineDonationPagePublicStats` | `OnlineDonationPagePublicStatsResponse` (totalRaised, donorCount only) | slug |

### Public Mutations (anonymous, rate-limited, csrf-protected)

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `initiateOnlineDonation` | `InitiateOnlineDonationRequest` (slug, donationPurposeId, amount, currencyCode, isRecurring, frequencyCode, donorFields[], paymentMethodCode, isAnonymous, dedicateNote, csrfToken, honeypot, recaptchaToken) | `OnlineDonationInitiateResponse` (paymentSessionId, gatewayHandoffUrl) |
| `confirmOnlineDonation` | `ConfirmOnlineDonationRequest` (paymentSessionId, gatewayCallbackPayload) | `OnlineDonationConfirmedResponse` (success, receiptUrl, thankYouMessage, redirectUrl?) |

### Response DTO Field Lists

**LandingContentDto** (shared by admin Response + public — added 2026-07-16):
```ts
// Server-assembled from OnlineDonationPageSettings rows (§②). Each field is the
// PARSED value of its ParamCode row: `json` rows → arrays/objects, scalars → primitives.
// Any field null/absent when its setting row is missing → FE renderer uses its coded fallback.
// The admin editor (Card 9) round-trips the SAME shape it reads here.
interface LandingContentDto {
  heroBenefits: { icon: string; title: string; desc: string }[];   // HERO_BENEFITS
  whyDonateTitle: string | null;                                    // WHY_DONATE_TITLE
  whyDonate: { icon: string; title: string; desc: string }[];       // WHY_DONATE_ITEMS
  impactStats: { value: string; label: string }[];                  // IMPACT_STATS
  missionTitle: string | null;                                      // MISSION_TITLE
  missionBody: string | null;                                       // MISSION_BODY
  footerContact: { address: string | null; phone: string | null; email: string | null } | null;  // FOOTER_CONTACT
  footerSocials: { platform: string; url: string }[];               // FOOTER_SOCIALS
  footerLinks: { label: string; url: string }[];                    // FOOTER_LINKS
}
```

**OnlineDonationPageResponseDto** (admin):
```ts
{
  onlineDonationPageId: number;
  companyId: number;
  pageTitle: string;
  slug: string;
  description: string | null;
  implementationType: 'NAV' | 'IFRAME';
  status: 'Draft' | 'Published' | 'Active' | 'Closed' | 'Archived';
  publishedAt: string | null;
  startDate: string | null;
  endDate: string | null;
  goalAmount: number | null;
  defaultDonationPurposeId: number | null;
  donationPurposes: { donationPurposeId: number; donationPurposeName: string; orderBy: number }[];
  minimumAmount: number;
  primaryCurrencyId: number;
  primaryCurrency: { currencyId: number; currencyCode: string; currencyName: string };
  enableMultiCurrency: boolean;
  allowRecurring: boolean;
  availableFrequencies: string[];                                  // jsonb → array
  defaultToRecurring: boolean;
  defaultFrequencyCode: string | null;
  companyPaymentGatewayId: number;
  companyPaymentGateway: { companyPaymentGatewayId: number; gatewayName: string; environment: string };
  enabledPaymentMethods: string[];                                  // jsonb → array
  amountChips: number[];                                            // jsonb → array
  allowCustomAmount: boolean;
  donorFields: Record<string, { required: boolean; visible: boolean; locked?: boolean }>;  // jsonb
  logoUrl: string | null;
  heroImageUrl: string | null;
  carouselSlides: { type: 'image' | 'video'; url: string; title: string; order: number }[];  // jsonb
  primaryColorHex: string;
  buttonText: string;
  pageLayout: 'centered' | 'side-by-side' | 'full-width';
  customCssOverride: string | null;
  iframeShowHeader: boolean;
  iframeShowFooter: boolean;
  thankYouMessage: string | null;
  thankYouRedirectUrl: string | null;
  showDonorCount: boolean;
  showSocialShare: boolean;
  taxReceiptNote: string | null;
  ogTitle: string | null;
  ogDescription: string | null;
  ogImageUrl: string | null;
  robotsIndexable: boolean;
  isActive: boolean;
  landingContent: LandingContentDto;   // added 2026-07-16 — STANDARD-template sections (Card 9 editor round-trips this)
}
```

**OnlineDonationPageStatsDto**:
```ts
{
  onlineDonationPageId: number;
  totalRaised: number;          // SUM(GlobalDonations.DonationAmount)
  totalDonors: number;          // COUNT(DISTINCT ContactId)
  conversionRate: number | null; // SERVICE_PLACEHOLDER until visit-log infra
  lastDonationAt: string | null; // MAX(DonationDate)
  goalAmount: number | null;
  goalProgressPercent: number | null;  // computed (totalRaised / goalAmount)
}
```

**OnlineDonationPagePublicDto** (public-safe — DTO Privacy):
```ts
{
  pageTitle: string;
  description: string | null;
  implementationType: 'NAV' | 'IFRAME';
  status: 'Active' | 'Closed';   // Draft / Archived not exposed publicly
  goalAmount: number | null;
  totalRaised: number | null;
  donorCount: number | null;
  endDate: string | null;
  donationPurposes: { donationPurposeId: number; donationPurposeName: string; orderBy: number }[];
  defaultDonationPurposeId: number | null;
  minimumAmount: number;
  primaryCurrencyCode: string;     // resolved code, NOT id
  enableMultiCurrency: boolean;
  allowRecurring: boolean;
  availableFrequencies: string[];
  defaultToRecurring: boolean;
  defaultFrequencyCode: string | null;
  enabledPaymentMethods: string[];
  amountChips: number[];
  allowCustomAmount: boolean;
  donorFields: Record<string, { required: boolean; visible: boolean }>;
  logoUrl: string | null;
  heroImageUrl: string | null;
  carouselSlides: { type: 'image' | 'video'; url: string; title: string; order: number }[];
  primaryColorHex: string;
  buttonText: string;
  pageLayout: 'centered' | 'side-by-side' | 'full-width';
  customCssOverride: string | null;
  iframeShowHeader: boolean;
  iframeShowFooter: boolean;
  thankYouMessage: string | null;
  thankYouRedirectUrl: string | null;
  showDonorCount: boolean;
  showSocialShare: boolean;
  taxReceiptNote: string | null;
  ogTitle: string;
  ogDescription: string;
  ogImageUrl: string | null;
  csrfToken: string;               // issued on render
  landingContent: LandingContentDto;   // added 2026-07-16 — only STANDARD template consumes; other variants ignore
}
```

**OnlineDonationPageEmbedCodeDto**:
```ts
{
  iframeSnippet: string;          // pre-formatted with current slug, tenant domain, max-width
  jsWidgetSnippet: string;         // pre-formatted with data-org / data-color
}
```

**OnlineDonationPageValidationResponse**:
```ts
{
  isValid: boolean;
  missingFields: { field: string; message: string }[];
  warnings: { field: string; message: string }[];
}
```

### Public DTO Privacy Discipline

| Field | Public DTO | Reason |
|-------|------------|--------|
| Internal IDs (CompanyId, PaymentGatewayId, ReceiptTemplateId) | omitted | not relevant to anonymous |
| Donor email / phone in stats | omitted | PII |
| Admin notes / audit history | omitted | internal-only |
| Total raised, donor count, purposes, theme, OG meta | included | public-safe |

---

## ⑪ Acceptance Criteria

> See "Verification" tasks at top — full E2E required. Highlights:

**Build Verification**:
- [ ] `dotnet build` from `Pss2.0_Backend/PeopleServe/` → 0 errors (warnings OK)
- [ ] `pnpm tsc --noEmit` from `Pss2.0_Frontend/` → 0 errors
- [ ] `pnpm dev` runs without runtime crash on admin route + both public routes

**DB Seed Verification**:
- [ ] `OnlineDonationPage-sqlscripts.sql` applied → tables created + indexes set
- [ ] EF migration created and `dotnet ef database update` succeeds (or generated SQL applied)
- [ ] GridType `EXTERNAL_PAGE` row added to GridTypes table (if not present)
- [ ] Sample seeded page renders publicly at `/p/give` and admin sees it in setup list

**Functional Verification — DONATION_PAGE checks**: see "Verification" tasks at top — exhaustive list (24 items).

**Public-route deployment checklist**:
- [ ] `(public)` route group exists with no admin chrome
- [ ] Anonymous middleware allows GET on `/p/{slug}` + `/embed/{slug}` and POST on public mutations only
- [ ] Rate-limit policy registered for `initiateOnlineDonation` and `confirmOnlineDonation`
- [ ] CSRF token issued on public render and validated on POST
- [ ] CSP headers set (with payment-gateway origins allowlisted)
- [ ] OG meta-tag pre-render in `generateMetadata` (NAV route only)
- [ ] 404 / 410 / closed-banner edge states render correctly

---

## ⑫ Special Notes & Warnings

**Universal EXTERNAL_PAGE warnings** (apply to all sub-types):

1. **TWO render trees** — admin setup at `setting/publicpages/onlinedonationpage` AND anonymous public at `(public)/p/{slug}` + `(public)/embed/{slug}`. Different route groups, different layouts (admin shell vs minimal public chrome), different auth gates (BUSINESSADMIN vs anonymous). Don't render setup chrome on the public route.
2. **Slug uniqueness is per-tenant** — `(CompanyId, LOWER(Slug))` composite unique. Two different tenants can have `/p/give` simultaneously. Public route resolution: tenant identified by request domain or subdomain or `tenantSlug` querystring (TBD by hosting strategy — see ISSUE-1).
3. **Lifecycle is BE-enforced** — never trust an FE flag. Re-validate on the server every time. Status transitions are explicit commands, not field updates.
4. **Anonymous-route hardening is non-negotiable** — rate-limit, CSRF, honeypot, reCAPTCHA, CSP headers. Skipping any is a security defect, not an enhancement.
5. **PCI scope must NOT cross the public form** — payment gateway must tokenize at the iframe boundary; raw card data never touches our servers. The donation form has placeholder card fields ONLY when SERVICE_PLACEHOLDER is mock; real integration replaces with gateway iframe.
6. **OG meta tags must be SSR-rendered** — social crawlers don't run JS. Pre-render in `generateMetadata` for the NAV route.
7. **Slug is immutable post-Activation when donations attached** — link rot. Renaming requires Archive + recreate. Validator gates this.
8. **Donation persistence is OUT OF SCOPE for this entity** — donations live in `fund.GlobalDonations` + `fund.GlobalOnlineDonations` with new FK back to `OnlineDonationPageId`. Setup configures the funnel; donations are recorded by the existing donation pipeline (extended with the FK).
9. **GridType = EXTERNAL_PAGE** — first instance; ensure registered in the GridType enum + seed.
10. **GridFormSchema = SKIP** — custom UIs, not RJSF modal forms.

**Screen-specific gotchas**:
- **Implementation Type switcher is the defining feature** — building only the NAV path ships a half-product. Tests must cover both modes including the embed-code copy + iframe widget render.
- **Live preview is client-state-only** — must NOT round-trip to server for every keystroke. Settings-card edits update Zustand → Live Preview reads Zustand directly. Save (autosave) is independent.
- **Donor Form Fields locked rows** — First Name / Last Name / Email checkboxes must be `disabled` AND visually clear they're forced. Tooltip "Required for donations to function" on hover.
- **Carousel slides** (NAV) — image OR YouTube embed; reorderable; max 5; the live preview rotates them with dot indicators.
- **Custom CSS Override** (NAV) — server-side strip `<script>` blocks BEFORE save (defense-in-depth even with CSP).
- **Status Bar conversionRate** — SERVICE_PLACEHOLDER until visit-log infrastructure or analytics service exists. Show "—" with tooltip explaining.
- **The mockup folder placement is misleading** — file is in `html_mockup_screens/screens/fundraising/` but the menu lives under `SET_PUBLICPAGES` (Module=SETTING). The FE route is `setting/publicpages/onlinedonationpage`, NOT `crm/donation/...`.
- **GlobalDonation FK migration** — the migration adds a NEW nullable column `OnlineDonationPageId` to `fund.GlobalDonations`. Existing rows stay NULL (no backfill). The FK constraint should be filtered to allow NULL values. Aggregations in `GetOnlineDonationPageStats` filter to `WHERE OnlineDonationPageId IS NOT NULL`.
- **iFrame mode `frame-ancestors`** — in IFRAME mode the public route MUST allow embedding by 3rd-party domains (CSP `frame-ancestors *` or per-tenant allow-list). NAV mode keeps `frame-ancestors 'none'`.
- **Sidebar menu placement** — menu lives under `SET_PUBLICPAGES` parent. Verify SET_PUBLICPAGES is wired in the sidebar dynamic-menu pipeline (it should be per MODULE_MENU_REFERENCE.md, MenuId 369).

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER: Payment Gateway tokenization** — UI fully implemented (gateway dropdown, methods checkbox list, donor form, submit). Public submit flow goes through `initiateOnlineDonation` → handler creates GlobalDonation+GlobalOnlineDonation rows and returns a MOCK gateway-handoff URL. Real Stripe/PayPal/Razorpay integration deferred until CompanyPaymentGateway screen ships gateway-connect flow.
- ⚠ **SERVICE_PLACEHOLDER: Receipt Email** — UI implemented (template select hint, send-on-success). Handler logs the would-be email but does not send (no email infra wired yet for transactional sends).
- ⚠ **SERVICE_PLACEHOLDER: reCAPTCHA v3** — UI placeholder (hidden field captures token); BE score check returns 1.0 always until reCAPTCHA configured.
- ⚠ **SERVICE_PLACEHOLDER: Conversion Rate analytics** — Status Bar shows `conversionRate` field as "—" until page-visit log table OR external analytics service exists. (UI shows the stat with tooltip "—" rather than hiding the slot.)
- ⚠ **SERVICE_PLACEHOLDER: Multi-currency FX** — `EnableMultiCurrency` toggle UI works; backend currency-conversion uses static cached rates (latest CurrencyConversion row); no live FX feed.
- ⚠ **SERVICE_PLACEHOLDER: Image upload** — Logo/Hero/Carousel image fields use URL-text inputs in MVP (no shared image-upload service). Admin pastes a public CDN URL. Replace with proper upload widget when image upload service exists (cross-cutting infra).

Full UI must be built (10 settings cards, Implementation Type switcher, 4-variant live preview, public NAV page, public IFRAME widget, donation flow up to gateway boundary, edge states). Only the handlers for genuinely missing services are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues (pre-flagged from planning)

| ID | Raised | Severity | Area | Description | Status |
|----|--------|----------|------|-------------|--------|
| ISSUE-1 | planning 2026-05-08 | HIGH | Hosting | Tenant resolution on public route — `/p/{slug}` with same slug across 2 tenants needs tenant identification (subdomain `{tenant}.donate.app`, custom-domain map, OR `tenantSlug` querystring). Decision deferred; MVP assumes one-tenant-per-deployment domain. | OPEN |
| ISSUE-2 | planning 2026-05-08 | HIGH | Payment | SERVICE_PLACEHOLDER for gateway tokenization — InitiateDonation handler returns mock; real Stripe/PayPal/Razorpay integration depends on CompanyPaymentGateway screen shipping gateway-connect flow. | PARTIAL (session 33 — Braintree + Razorpay + PayU India one-time card donations end-to-end; PayU SI recurring registers mandate only [ISSUE-36]; Stripe / PayPal / PayU Global still deferred) |
| ISSUE-3 | planning 2026-05-08 | HIGH | Email | SERVICE_PLACEHOLDER for receipt email — handler logs but doesn't send (no email infra). Receipt PDF generation also pending (separate service). | CLOSED (session 55 — `DonationReceiptService` renders an A4 print-CSS tax receipt via `IPdfService.GeneratePdfBytesAsync` (reuses `GlobalDonation.ReceiptNumber`); `ConfirmOnlineDonation.cs` now attaches it to the confirmation email via `SendComposedEmailForCompanyAsync` (3 placeholder logs removed); anonymous token-gated `GET api/ReceiptDownload/{sessionToken}` (rate-limited, NotFound-on-miss) + FE `DownloadReceiptButton` on all 9 thank-you templates. New OrgSettings ParamCode `TAX_EXEMPTION_NUMBER` (EAV seed, user-owned). User compiles + applies seed. **Session 56 jurisdiction-safety amendment**: PSS is a GLOBAL product, so the receipt must NOT assert India 80G on every tenant. Tax block is now self-gating — renders ONLY when the tenant explicitly enters a real `TAX_EXEMPTION_NUMBER`; removed the `Company.TaxId` fallback (a registration number ≠ an exemption certificate); blanked the `TAX_SECTION` new-tenant default (`80G`→`""`). India tenants set number + 80G and still get the full statement; everyone else gets a clean receipt.) |
| ISSUE-4 | planning 2026-05-08 | MED | Analytics | conversionRate Status-Bar stat is SERVICE_PLACEHOLDER — no page-visit log table exists. Show "—". | OPEN |
| ISSUE-5 | planning 2026-05-08 | MED | Migration | GlobalDonations migration must add `OnlineDonationPageId` nullable FK without breaking existing rows. Backfill = no-op (stays NULL); FK constraint filtered. EF migration name suggestion: `Add_OnlineDonationPage_And_FK_On_GlobalDonations`. | OPEN |
| ISSUE-6 | planning 2026-05-08 | MED | Image | Logo/Hero/Carousel use URL-text inputs in MVP — no shared image-upload service. Admin pastes CDN URLs. Cross-cutting infra missing (matches DonationInKind #7 ISSUE-5 + ChequeDonation #6 ISSUE-27). | OPEN |
| ISSUE-7 | planning 2026-05-08 | MED | Public route | `(public)` route group must exist with minimal layout (no admin chrome). If absent, scaffold it. | OPEN |
| ISSUE-8 | planning 2026-05-08 | MED | CSP | IFRAME-mode public route needs CSP `frame-ancestors *` to allow embedding by 3rd-party. Per-tenant allow-list (only allow embedding from tenant-registered domains) is a hardening follow-up. | ✅ CLOSED (session 43 — `next.config.mjs headers()`: NAV `/:lang/p/:slug*` → `frame-ancestors 'none'` + `X-Frame-Options: DENY`; IFRAME `/:lang/embed/:slug*` → `frame-ancestors *`. Per-tenant embed allow-list still a hardening follow-up.) |
| ISSUE-9 | planning 2026-05-08 | MED | reCAPTCHA | UI placeholder; BE score returns 1.0 until reCAPTCHA configured. | OPEN |
| ISSUE-10 | planning 2026-05-08 | LOW | GridType | `EXTERNAL_PAGE` is a NEW GridType — register in GridTypes seed table (idempotent NOT EXISTS gate). | OPEN |
| ISSUE-11 | planning 2026-05-08 | LOW | Slug | Reserved-slug list lives in BE validator constants — keep in sync with FE preview hint. | OPEN |
| ISSUE-12 | planning 2026-05-08 | LOW | Multi-currency | EnableMultiCurrency uses cached CurrencyConversion rates; no live FX feed. | OPEN |
| ISSUE-13 | planning 2026-05-08 | LOW | Switcher | Changing ImplementationType post-Active warns about embed-code-break; soft-warning only — does NOT prevent the change. | OPEN |
| ISSUE-14 | planning 2026-05-08 | LOW | Custom CSS | Server-side `<script>` strip on save AND CSP at runtime (defense-in-depth). | OPEN |
| ISSUE-15 | planning 2026-05-08 | LOW | Seed folder | Preserve `sql-scripts-dyanmic/` folder typo per existing convention (ChequeDonation #6 / Pledge #12 / Refund #13 ISSUE-15). | OPEN |
| ISSUE-16 | planning 2026-05-08 | LOW | jsonb mapping | Mapster + EF Core jsonb columns: ensure `JsonValueComparer` configured; ServiceCollection registers System.Text.Json serializer. | OPEN |
| ISSUE-17 | planning 2026-05-08 | LOW | Sidebar | If sidebar menu rendering for `SET_PUBLICPAGES` is broken (other screens show under-construction stubs), verify SET_PUBLICPAGES parent has live BE menu rows. | OPEN |
| ISSUE-18 | planning 2026-05-08 | LOW | Aggregation | totalRaised / totalDonors / lastDonationAt computed via 3-subquery LEFT JOIN on GlobalDonations — verify no N+1 in setup list view (project as a batch single-pass per page). | OPEN |
| ISSUE-19 | planning 2026-05-08 | LOW | Anonymous public route | Anonymous public mutations route past CSRF middleware which normally requires session — public route group needs CSRF policy that issues + validates without session. | OPEN |
| ISSUE-20 | planning 2026-05-08 | LOW | OG image fallback | When OgImageUrl null AND CarouselSlides empty AND HeroImageUrl null AND LogoUrl null → fall back to org-default OG image (configured at tenant CompanySettings level) — coordinate with CompanySettings #75. | OPEN |
| ISSUE-21 | session-1 2026-05-08 | LOW | EF Migration | ModelSnapshot stale — hand-coded migration is valid but snapshot does not contain new entities. Run `dotnet ef migrations add Sync_Snapshot --no-build` before next migration. | OPEN |
| ISSUE-22 | session-1 2026-05-08 | LOW | GQL reuse | `companyPaymentGateways` GQL query is inline in `payment-methods-section.tsx` — move to shared `donation-queries/CompanyPaymentGatewayQuery.ts` when CompanyPaymentGateway screen ships its own GQL file. | CLOSED (session 23 — replaced inline query with shared `COMPANYPAYMENTGATEWAYS_QUERY`; `rowMapper` flattens nested `paymentGateway.paymentGatewayName` → `gatewayName` for the selector) |
| ISSUE-23 | session-1 2026-05-08 | LOW | Index drift | EF `HasIndex.HasFilter("\"IsDeleted\" = false")` and migration's raw-SQL `LOWER(Slug)` filtered index are slightly inconsistent. Will regenerate the plain index on next `dotnet ef migrations add` unless reconciled. | OPEN |
| ISSUE-24 | session-13 2026-05-25 | LOW | Crypto config | `PaymentWebhookController.cs:236` (TEST endpoint) reads `_configuration["PaymentGateway:CredentialEncryptionKey"]` while the production webhook + the new Initiate/Confirm handlers read `_configuration["PaymentGateway:EncryptionKey"]`. The TEST endpoint will fail to decrypt if only the production key is configured. Canonicalize on `EncryptionKey` (or document the alias). | CLOSED (session 14 — canonicalized on `CredentialEncryptionKey` to match `appsettings.json` + the CompanyPaymentGateway CRUD encrypt key. Updated InitiateOnlineDonation, ConfirmOnlineDonation, PaymentWebhookController:61. Verified via `dotnet build` → 0 errors) |
| ISSUE-25 | session-13 2026-05-25 | LOW | Abandoned intents | InitiateOnlineDonation persists a PENDING `fund.GlobalDonation` + `fund.GlobalOnlineDonation` BEFORE the donor enters card details. If the donor clicks "Change details" or abandons the tab, those rows stay PENDING forever. Needs a periodic cleanup job (sweep PENDING rows older than N hours where `GatewayTransactionId IS NULL`). Audit-friendly but creates db noise. | OPEN |
| ISSUE-26 | session-13 2026-05-25 | LOW | Tenant creds drift | The legacy AUTH-gated `GetBraintreeClientToken` query (`BraintreePaymentQueries.cs`) still reads creds from `appsettings.json` via the singleton `BraintreeService`, whereas the new public Initiate/Confirm handlers read decrypted tenant creds from `fund.CompanyPaymentGateway`. Two code paths, two cred sources — unify both onto tenant creds when CompanyPaymentGateway admin CRUD ships. | OPEN |
| ISSUE-27 | session-13 2026-05-25 | MED | Recurring | Braintree recurring (subscription_charged_successfully webhook lane already wired in `PaymentWebhookController`) is NOT yet exercised on submit — InitiateOnlineDonation rejects `isRecurring=true` with `RECURRING_NOT_YET_AVAILABLE`. To finish: BE creates Braintree Customer + PaymentMethod + Subscription on Confirm, inserts `fund.RecurringDonationSchedule` with `GatewaySubscriptionId`, FE renders a frequency disclosure on the Pay button. | OPEN |
| ISSUE-28 | session-13 2026-05-25 | MED | MasterData seeds | The new payment flow looks up MasterData by `(TypeCode, DataValue)` for: `DONATIONMODE/(ONLINE\|ONLINE_DONATION)`, `DONATIONTYPE/(GENERAL\|ONLINE\|OFFERING\|DONATION)`, `PAYMENTMETHOD/{code}`, `PAYMENTSTATUS/(PENDING\|COMPLETED\|FAILED)`, `CONTACTBASETYPE/(INDIVIDUAL\|PERSON)`, `EMAILTYPE/(PERSONAL\|PRIMARY)`, `CONTACTSTATUS/ACTIVE`. If any of these are missing for the tenant, donations error out with `MASTERDATA_MISSING: <list>`. Add a one-shot seed gate to the dynamic SQL folder OR document the tenant-bootstrap requirement. | PARTIAL (session 36 — donation-path rows folded into the idempotent `online-donation-page-sqlscripts.sql`: `PAYMENTMETHOD/PENDING` + `DONATIONMODE/OD` + `DONATIONTYPE/{ONETIMEDONATION,RECURRINGDONATION}` + `PAYMENTSTATUS/{PENDING,COMPLETED,FAILED}` + `RECURRINGFREQUENCY/{MO,QT,SA,AN}`. Inbox-promotion rows CONTACTBASETYPE/EMAILTYPE/CONTACTSTATUS owned by #175, still pending) |
| ISSUE-29 | session-14 2026-05-25 | MED | Save toast | `handleSave` in `editor-page.tsx` previously picked the FIRST non-null `message` between the two parallel mutations. BE `BaseApiResponse.Error()` sets `Message=""` + `ErrorDetails=<actual reason>` (PutSuccess sets `Message="Updated successfully."`). When one mutation succeeded and the other failed, the toast showed the SUCCESS message in red. Fixed in session 14 (now picks `errorDetails` then `message` of the actually-failed envelope). Root-cause of WHY `updateOnlineDonationPagePurposes` ever returns success=false remains undiagnosed — surfacing the right detail will help find it on next repro. | PARTIAL (session 14 — toast picks the failed envelope; underlying purposes-mutation failure path still to be observed in BE logs) |
| ISSUE-30 | session-14 2026-05-25 | MED | DonorFields casing | HC `AnyType` over `Dictionary<string, DonorFieldConfig>` can ship the wire payload with mixed key/value casing. The live-preview also hardcoded only FirstName/LastName/Email/Phone with a default-true fallback, ignoring Address/Organization/Message/Anonymous/Dedicate. Fix in session 14: shared `normalizeDonorFields()` helper coerces wire shape to canonical `{ PascalCase keys, lowercase value props, First/Last/Email always required+visible+locked }`. Applied at editor save (`toRequest`), admin section read, live-preview render, and public donation-form intake. Public form's request payload now reads case-insensitively. Underlying HC binding is not "fixed" — just shielded from drift. | CLOSED (session 14 — normalizer + iteration rewrite) |
| ISSUE-31 | session-14 2026-05-25 | MED | Preview CSRF | Admin "Preview Full Page" route (`(public)/preview/onlinedonationpage/[id]/page.tsx::toPublicDto`) set `csrfToken: "preview"` (7 chars). BE Initiate validator requires `≥16` chars, so clicking Donate Now in the preview tab errored with `CSRF_INVALID: Missing or malformed CSRF token.` even though the amber banner promised "Donations disabled here". Fix in session 14: thread `previewMode` from preview route → `DonationPage` → `DonationForm`; in preview mode the submit handler short-circuits with a "Donations disabled in preview" inline error before any GraphQL call, and the Donate Now button renders disabled with that copy. Reversed in same session after user requested ability to test Drop-in widget from preview: stub replaced with `makePreviewCsrfToken()` (32-char crypto-random hex), `previewMode` prop removed, submit re-enabled. | CLOSED (session 14 — switched to real-format token, submit re-enabled) |
| ISSUE-32 | session-14 2026-05-25 | HIGH | Tenant resolution | `InitiateOnlineDonation` handler hard-coded tenant resolution to `dbContext.Companies.OrderBy(CompanyId).First()` (the ISSUE-1 single-tenant placeholder). On multi-tenant DBs where the admin's company isn't the lowest CompanyId, the slug lookup failed with `"Donation page '<slug>' not found."` even when the page existed under the admin's tenant. Fixed in session 14 by adding a shared `OnlineDonationPageTenantResolver` helper and giving Initiate a dual-mode resolution: (a) prefer `httpContextAccessor.GetCurrentUserStaffCompanyId()` when a Bearer token is on the request (admin preview tab — Initiate is anonymous but auth middleware still populates claims); (b) fall back to hostname-based CustomDomain → Subdomain → first-active resolution for genuine public donors at `/p/{slug}`. The hostname is read from `x-forwarded-host` (Azure Front Door) or `Host` header via `IHttpContextAccessor`. Note: this fix targets the bug, not ISSUE-1 — production tenant routing still depends on Azure Front Door setting `x-forwarded-host` correctly; in local dev, anonymous flow falls through to first-active. GetOnlineDonationPageBySlug handler still has its own inline resolution (refactor to share the helper deferred). | CLOSED (session 14 — dual-mode resolver) |
| ISSUE-33 | session-14 2026-05-25 | HIGH | MasterData code drift | `InitiateOnlineDonation.cs` looked up DONATIONMODE with `{ "ONLINE", "ONLINE_DONATION" }` and DONATIONTYPE with `{ "GENERAL", "ONLINE", "OFFERING", "DONATION" }` — values that don't exist in the seeded MasterData table. Every Initiate call failed with `MASTERDATA_MISSING: MasterData[DONATIONMODE/(ONLINE\|ONLINE_DONATION)], MasterData[DONATIONTYPE/(GENERAL\|ONLINE\|OFFERING\|DONATION)]`. The actual seeded DataValues are `DONATIONMODE/OD` (Online) and `DONATIONTYPE/ONETIMEDONATION` (One-Time). Source-of-truth was already in the codebase: `RunAutoReconciliation.cs:62` looks up `DONATIONMODE / DataValue == "OD"` and works correctly. The values in Initiate were placeholders from initial Session 1 scaffolding that nobody validated against the seed because end-to-end Initiate wasn't exercised until Session 13. Fixed in Session 14 by replacing the multi-value fallback arrays with the single canonical codes and updating the error-message strings accordingly. Confirm handler's `{ COMPLETED, SUCCESS }` lookup left untouched — `COMPLETED` is the validated canonical value (cf. RealizeInKindDonation, UpdateGlobalDonationWithChildren), so the ordered fallback selects it first. | CLOSED (session 14 — canonical codes) |
| ISSUE-34 | session-14 2026-05-25 | HIGH | MasterData IsDeleted NULL filter | `InitiateOnlineDonation.GetMasterDataIdFirstOf` (and Confirm's copy) filtered MasterData with `m.IsDeleted == false`. `IsDeleted` on `Entity` base is `bool?` (nullable); seed scripts commonly insert MasterData with `IsDeleted=NULL` (column default not set). EF Core translates `== false` to PostgreSQL `WHERE "IsDeleted" = false`, which **excludes NULL rows** — so every seeded MasterData lookup that should have matched returned 0 rows instead. User repro: `MASTERDATA_MISSING: MasterData[PAYMENTMETHOD/CARD]` even though the row visibly exists in `sett."MasterDatas"` with `TypeCode='PAYMENTMETHOD'` and `DataValue='CARD'`. Sibling handlers `RunAutoReconciliation.cs:62`, `CreateChequeDonation.cs:128`, `RealizeInKindDonation.cs:103`, `CompleteRefund.cs:192` ALL omit the IsDeleted filter on MasterData precisely because of this — the convention is "don't filter IsDeleted on MasterData, it's seed data". My helper inherited the filter from boilerplate copy-paste of `IsDeleted == false` patterns that apply to *transactional* entities (OnlineDonationPages, Contacts, etc.) where IsDeleted is always set. Fixed in Session 14 by dropping the `IsDeleted == false` filter in BOTH Initiate's helper AND Confirm's helper. | CLOSED (session 14 — filter dropped to match sibling convention) |
| ISSUE-35 | session-16 2026-05-26 | MED | Multi-currency wiring | The Amounts card's `EnableMultiCurrency` toggle is persisted but has NO effect on the public form. Donor cannot pick currency; Braintree always captures in the company base. To wire properly (recommended global-platform behaviour): (a) public form renders a small currency switcher next to the amount input when `enableMultiCurrency=true`; (b) **switcher options = base currency + rows in `sett.CompanyConfigurationCurrencies` for the tenant** (admin-curated allow-list, already managed by CompanySettings #75 — supersedes the original CurrencyConversion-based proposal because admin intent is explicit, soft-delete + audit are preserved, and FK integrity stays at the row level); (c) donor's chosen CurrencyId flows through Initiate → staging row → Braintree `currencyIsoCode`; (d) BE Initiate accepts donor CurrencyId only when `OnlineDonationPage.EnableMultiCurrency=true` AND the currency is in the tenant's `CompanyConfigurationCurrencies` list (or is the base), else rejects with `CURRENCY_NOT_SUPPORTED`; (e) admin live preview also shows the switcher. Dependencies: per-tenant Braintree merchant-account presentment-currency config (real gating constraint), CurrencyConversion seed rows from base → each target for any client-side display equivalents (ISSUE-12 lane). | OPEN |
| ISSUE-36 | session-33 2026-06-01 | MED | Recurring (PayU SI) | PayU India recurring is wired as Standing-Instruction (SI) mandate REGISTRATION only (`si=1` + `si_details` on the `_payment` request; `mihpayid` stored as `GatewaySubscriptionId`). Subsequent auto-debits are scaffolded with an explicit `// TODO(PayU-SI)` in `PayUIndiaProvider.CreateSubscriptionAsync` — the real recurring charge uses PayU `command=si_transaction` and requires **SI activation on the merchant account**. Cancel uses `command=cancel_si` (also needs SI-enabled account). Until activated, one-time PayU donations work end-to-end but recurring registers intent without confirmed downstream charges. | PARTIAL (session 34 — merchant-side SI auto-debit engine shipped: daily Hangfire cron `payu-si-recurring-charges` → `PayURecurringChargeService` → `IPaymentFlowService.ChargeRecurringCycleAsync` → `PayUIndiaProvider.RetrySubscriptionChargeAsync` now does a real `command=si_transaction` POST; successful cycles record a full `fund.GlobalDonation` (DonationType RECURRINGDONATION) + `GlobalOnlineDonation` + `PaymentTransaction` and advance the schedule, idempotent per day. Compiles 0-errors. **Still runtime-blocked on PayU SI activation** — the `si_transaction` `var1` field names are marked `// VERIFY against your PayU SI account` and the first SI-enabled run pins them via the logged raw response. Also fixed a latent hardcoded-Braintree dispatch bug in the manual-retry bridge.) |
| ISSUE-37 | session-33 2026-06-01 | LOW | PayU return-URL | The FE supplies `returnUrl` (surl/furl base) at Initiate and the BE trusts it verbatim. Should validate the host against the tenant's registered CustomDomain/Subdomain (same resolver as ISSUE-32) to prevent an attacker pointing surl/furl at a foreign origin and capturing the PayU response (open-redirect / hash-leak). Hardening follow-up. | CLOSED (session 55 — `OnlineDonationPageTenantResolver.IsReturnUrlAllowed(returnUrl, requestHost, CustomDomain, Subdomain, env)` gates `req.ReturnUrl` in the PayU branch of `InitiateOnlineDonation` before it becomes surl/furl; requires absolute http/https (https-only outside Dev), host must match request-host ∪ CustomDomain ∪ Subdomain (localhost only in Dev), else `RETURN_URL_INVALID`. Build 0-errors.) |
| ISSUE-38 | session-33 2026-06-01 | INFO | PayU creds bootstrap | PayU credentials are NOT seeded (AES-encrypted per tenant). The seed only adds the `com."PaymentGateways"` `PAYU` provider row. Admin must add a `CompanyPaymentGateway` PAYU row with **merchant key + salt** via the admin screen before donations route to PayU. India public sandbox test creds: key=`gtKFFx`, salt=`eCwWELxi` against `test.payu.in` (test card `5123 4567 8901 2346`, CVV `123`, any future expiry, OTP `123456`). | OPEN |
| ISSUE-39 | spec-rev 2026-07-16 | MED | Generic settings table | STANDARD-template landing content moves to a NEW generic per-page EAV table `fund.OnlineDonationPageSettings` (§②), modeled on `sett.OrganizationSettings` but scoped by `OnlineDonationPageId`. Requires: entity + EF config + `SaveLandingContent` diff-only command + `LandingContentDto` assembler + default-rows seeder on Create + a SECOND user-owned migration `Add_OnlineDonationPageSettings`. Not yet built. | ✅ CLOSED (session 51 — built: entity `OnlineDonationPageSetting` + EF config (filtered-unique `(PageId,ParamCode)`, cascade FK), `SaveOnlineDonationPageLandingContent` diff-only command, `DefaultOnlineDonationPageSettings` seeder+assembler, DbSet ×2 wiring, `LandingContentDto` on ResponseDto+PublicDto, seed-on-Create, assemble in GetById/GetBySlug, `saveOnlineDonationPageLandingContent` mutation; FE Card 9 editor + `LandingRepeater` + 5 Aurora sub-sections + template-aurora MODIFY + DTO/GQL/editor wiring. Migration SPEC `onlinedonationpage-ISSUE39-MIGRATION-SPEC.md` user-owned; no build/migration run this session.) |
| ISSUE-40 | spec-rev 2026-07-16 | LOW | Backfill for old pages | Pages created BEFORE ISSUE-39 have no settings rows → `LandingContentDto` fields come back null and the Aurora template renders its coded fallbacks (page still complete). Optional one-shot backfill can seed default rows into existing pages if tenants want them editable immediately. Renderer must never assume a row exists. | OPEN |
| ISSUE-41 | session-52 2026-07-16 | MED | Thin-core relocation | **PLANNED for next session** (reverses the 2026-07-16 "ship as-is" decision — user opted to proceed). Relocate the cosmetic/presentational typed columns OUT of `fund.OnlineDonationPages` INTO the generic `fund.OnlineDonationPageSettings` EAV table, then DROP them from the parent. **Candidate columns** (~15, confirm against `OnlineDonationPage.cs` at build time): `PrimaryColorHex`, `ButtonText`, `PageLayout`, `CustomCssOverride`, `IframeShowHeader`, `IframeShowFooter`, `ThankYouMessage`, `ThankYouRedirectUrl`, `ShowDonorCount`, `ShowSocialShare`, `TaxReceiptNote`, `OgTitle`, `OgDescription`, `OgImageUrl`, `RobotsIndexable`. **KEEP as typed columns** (structural/validated/FK/lifecycle/aggregation-join): identity+slug, ImplementationType/Status/PageTypeId, dates, amounts, currency, gateway FK, all `*Json` form config, media URLs. **Build-time caution** — the `Og*`/`RobotsIndexable` set feeds the SSR OG-meta / SEO path; a bad move breaks link previews + search indexing on a live-money page → migrate + assemble those LAST and verify SSR head output before dropping the columns. **Migration is TWO user-owned steps** (per policy): (1) additive — backfill each page's existing column values into settings rows via a data migration/seed; (2) destructive — DROP the columns only AFTER backfill verified. Do NOT drop-and-relocate in one shot. FE: remove the relocated fields from `OnlineDonationPageRequestDto`/typed reads, route them through the `landingContent`/settings channel. **BE done (session 53); MIGRATION DEFERRED** — the additive backfill + destructive DROP are NOT run separately. They are folded into ISSUE-42's SINGLE combined migration (user decision, session 53) so the live `fund.OnlineDonationPages` table is altered only ONCE. | CLOSED (session 53) |
| ISSUE-42 | session-53 2026-07-16 | MED | Template-variant content system | **PLANNED — needs `/plan-screens #10` spec revision.** Template types will proliferate (Image / Video / Carousel / Carousel+Video / Carousel+Image / …). Handle as: `PageTypeId` (MasterData `TypeCode=ONLINEDONATIONPAGETYPE`) stays the typed **selector** — new type = 1 MasterData row, no schema change; template-specific **CONTENT** goes in `fund.OnlineDonationPageSettings` (EAV), **NEVER** per-variant typed columns (avoids sparse-wide table + per-variant migrations). Renderer reads `PageTypeId` → which `SectionCode`s to pull → assembles from settings. New template = MasterData row + settings catalog + **ONE renderer component** (real code, not zero-cost). **This pass ALSO relocates the template-presentation media columns** (`CarouselSlidesJson`, `HeroImageUrl`, `LogoUrl`) into the settings template model (finalize exact set in the plan pass). **KEEP typed** the donation-FORM config (`AmountChipsJson`, `AvailableFrequenciesJson`, `AllowCustomAmount`) — these are payment-form behavior, not template content. **SINGLE COMBINED MIGRATION** (user-owned): after 41's BE + 42's build are both in, ONE backfill (41's 15 cosmetic cols + 42's media cols → settings rows) → verify → ONE `DROP COLUMN` for all of them. The live table is altered exactly once. Full design: `bug-reports/onlinedonationpage-ISSUE42-TEMPLATE-VARIANT-DESIGN.md`. | ✅ CLOSED (session 54 — §⑥ revised (dispatcher NOT rebuilt); 2 combo MasterData rows seeded (`CAROUSEL_VIDEO`/`CAROUSEL_IMAGE`, `online-donation-page-sqlscripts.sql` Session 54 block); 4 FE templates built (`template-gallery-{video,image}.tsx` + `thank-you-gallery-{video,image}.tsx`) + dispatcher wired (both switches, no existing case altered); 3 media cols (`CarouselSlidesJson`/`HeroImageUrl`/`LogoUrl`) relocated to `MEDIA` EAV wire-stable (BE session 53); ONE combined 18-col migration SPEC `onlinedonationpage-COMBINED-MIGRATION-SPEC.md` (backfill 41's 15 + 42's 3 → verify typed reads + SSR/OG LAST → single DROP; live table altered once). Form config `AmountChipsJson`/`AvailableFrequenciesJson`/`AllowCustomAmount` kept typed. 0 type errors in touched files. Migration user-owned — not run.) |

#### ISSUE-41 — Column → Settings-row mapping (pre-derived from `OnlineDonationPage.cs`, ready to execute)

> Backfill catalog for step (1) of the ISSUE-41 migration. For **each** page, insert one
> `fund.OnlineDonationPageSettings` row per column below, copying the column's current value into
> `ParamValue`. `(OnlineDonationPageId, ParamCode)` is the filtered-unique key — ParamCodes are
> globally unique per page (safe across sections). `ParamDataType` values come from the allowed set
> `string|text|int|decimal|bool|url|color|json`. **NULL-source rule**: if a page's column value is
> `NULL` (nullable columns: `IframeShowHeader/Footer`, `PrimaryColorHex`, `ButtonText`, `PageLayout`,
> `CustomCssOverride`, `ThankYouMessage`, `ThankYouRedirectUrl`, `TaxReceiptNote`, `Og*`), **skip the
> row** — the renderer falls back to its coded default (ISSUE-40 guarantee). Non-nullable bools
> (`ShowDonorCount`, `ShowSocialShare`, `RobotsIndexable`) always get a row.

| # | Source column (`OnlineDonationPages`) | CLR type | SectionCode | ParamCode | ParamDataType | ParamName (admin label) | OrderBy |
|---|---------------------------------------|----------|-------------|-----------|---------------|-------------------------|---------|
| 1  | `PrimaryColorHex`     | `string?` | `THEME`    | `PRIMARY_COLOR`         | `color`  | Primary Colour          | 1 |
| 2  | `ButtonText`          | `string?` | `THEME`    | `DONATE_BUTTON_TEXT`    | `string` | Donate Button Text      | 2 |
| 3  | `PageLayout`          | `string?` | `THEME`    | `PAGE_LAYOUT`           | `string` | Page Layout             | 3 |
| 4  | `CustomCssOverride`   | `string?` | `THEME`    | `CUSTOM_CSS`            | `text`   | Custom CSS Override     | 4 |
| 5  | `IframeShowHeader`    | `bool?`   | `EMBED`    | `IFRAME_SHOW_HEADER`    | `bool`   | Show Header (Iframe)    | 1 |
| 6  | `IframeShowFooter`    | `bool?`   | `EMBED`    | `IFRAME_SHOW_FOOTER`    | `bool`   | Show Footer (Iframe)    | 2 |
| 7  | `ThankYouMessage`     | `string?` | `THANKYOU` | `THANKYOU_MESSAGE`      | `text`   | Thank-You Message       | 1 |
| 8  | `ThankYouRedirectUrl` | `string?` | `THANKYOU` | `THANKYOU_REDIRECT_URL` | `url`    | Thank-You Redirect URL  | 2 |
| 9  | `ShowDonorCount`      | `bool`    | `SOCIAL`   | `SHOW_DONOR_COUNT`      | `bool`   | Show Donor Count        | 1 |
| 10 | `ShowSocialShare`     | `bool`    | `SOCIAL`   | `SHOW_SOCIAL_SHARE`     | `bool`   | Show Social Share       | 2 |
| 11 | `TaxReceiptNote`      | `string?` | `RECEIPT`  | `TAX_RECEIPT_NOTE`      | `text`   | Tax Receipt Note        | 1 |
| 12 | `OgTitle`             | `string?` | `SEO`      | `OG_TITLE`              | `string` | OG Title                | 1 |
| 13 | `OgDescription`       | `string?` | `SEO`      | `OG_DESCRIPTION`        | `text`   | OG Description          | 2 |
| 14 | `OgImageUrl`          | `string?` | `SEO`      | `OG_IMAGE_URL`          | `url`    | OG Image URL            | 3 |
| 15 | `RobotsIndexable`     | `bool`    | `SEO`      | `ROBOTS_INDEXABLE`      | `bool`   | Search-Engine Indexable | 4 |

**bool serialization**: store `ParamValue` as lower-case `"true"`/`"false"` (matches the existing
settings reader). **Section render order** for the admin editor: `THEME → EMBED → THANKYOU → SOCIAL →
RECEIPT → SEO`. **Execution order reminder**: assemble + verify the `SEO` section LAST and confirm the
public SSR `<head>` (`og:title`/`og:description`/`og:image`/`robots`) still renders from settings
BEFORE running step (2) destructive `DROP COLUMN`.

### § Sessions

<!-- Each /build-screen session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

> _[45 older session entries trimmed to save tokens — full history in git: `git log -p -- onlinedonationpage.md`. Most recent 5 kept below.]_

### Session 56 — 2026-07-16 — FIX — COMPLETED — ISSUE-3 jurisdiction-safety (global product must not assert India 80G on every tenant)
- **Trigger**: /continue-screen #10. User flagged that the session-55 receipt applied Indian tax-exemption text (80G) to ALL tenants — but tax exemption is jurisdiction-specific (India 80G / US 501c3 / UK Gift Aid) and PSS is a GLOBAL product. Audited the delivered code (not the completion report). **Concern CONFIRMED**: a non-India tenant's downloadable/emailed receipt PDF would falsely assert an 80G exemption — a real compliance defect on a donor-facing artefact.
- **Root cause (3 compounding defaults)**: (a) `TAX_SECTION` new-tenant default hard-coded to `"80G"`; (b) `SHOW_TAX_INFO_ON_RECEIPT` default `true`; (c) `TAX_EXEMPTION_NUMBER` read fell back to generic `Company.TaxId` (a tax *registration* number is NOT an exemption certificate); (d) render gate was an OR (`TaxSection` **OR** `TaxExemptionNumber`), so the 80G default alone printed the block even with no exemption number.
- **Fix (minimal, NO schema change — self-gating)**: tax block now renders ONLY when the tenant has explicitly entered a real `TAX_EXEMPTION_NUMBER`.
  - `DonationReceiptService.cs`: removed the `fallback: company.TaxId` on the `TAX_EXEMPTION_NUMBER` read; render condition changed from OR to `ShowTaxInfo && !IsNullOrWhiteSpace(TaxExemptionNumber)`.
  - `OrgSettingsDefaultSeeder.cs`: blanked the `TAX_SECTION` new-tenant default (`"80G"` → `""`); description now lists India 80G / US 501c3 / UK Gift Aid as examples. Only affects NEW tenants — existing `CurrentValue` untouched.
  - India tenants (who set both a number + 80G) still get the full statement; every other tenant gets a clean receipt with no tax claim.
- **Files touched**:
  - BE: `Base.Application/Services/DonationReceipt/DonationReceiptService.cs`; `Base.Infrastructure/Seeders/OrgSettingsDefaultSeeder.cs`
  - FE: none
  - DB: none (seed SQL `orgsettings-tax-exemption-number-seed.sql` unchanged — CurrentValue already NULL, correct)
- **Verify**: both changed projects compiled individually to a scratch output (`--no-dependencies`) → **0 errors**. Full-solution build was blocked only by VS-Insiders file locks on the output DLLs (MSB3027/MSB3021 copy locks, zero CS-errors), not compiler failures.
- **Deviations from spec**: None — tightens jurisdiction correctness within the existing DOCUMENT-subtype receipt contract.
- **Known issues opened**: None.
- **Known issues closed**: None (ISSUE-3 already CLOSED session 55; row note amended with the jurisdiction fix).
- **Next step (USER-OWNED)**: (1) release the VS-Insiders lock (or restart the running app) and compile the full BE; (2) apply `sql-scripts-dyanmic/orgsettings-tax-exemption-number-seed.sql`; (3) for each India tenant set `TAX_EXEMPTION_NUMBER` + `TAX_SECTION='80G'`; (4) exercise a confirmed donation → verify the email attaches the PDF and the Download Receipt button works, and that a non-India tenant's receipt shows NO tax claim.

### Session 55 — 2026-07-16 — ISSUE-3 donation tax-receipt PDF (service + email attach + anonymous download + FE button) — COMPLETED
- **Trigger**: /continue-screen #10 "Build ISSUE-3 — a receipt-PDF service feeding BOTH the confirmation-email attachment AND a Download Receipt button on the thank-you page." Classified FIX/ENHANCE (in-scope; replaces the SERVICE_PLACEHOLDER email + adds the missing OUR-receipt artefact). BE Sonnet + FE Sonnet (both agents; §①–§⑫ detailed).
- **Approach**: OUR tax receipt (not the gateway's payment confirmation). Reuses existing `GlobalDonation.ReceiptNumber` (no new numbering) and existing `IPdfService.GeneratePdfBytesAsync` (PuppeteerSharp print-to-PDF, print-CSS/`PreferCSSPageSize` — DOCUMENT-subtype rule, NOT html-screenshot). Lookup chain for the anonymous download: `PaymentSessionId` (session/confirmation token the success page holds) → `OnlineDonationStaging.PromotedGlobalDonationId` → `GlobalDonation`; donor falls back to staging `Provided*` fields when `ContactId` is null. Endpoint is token-gated (cannot be enumerated by donationId), `NotFound()` on miss (no PII), rate-limited.
- **Files touched**:
  - BE (created): `Base.Application/Services/DonationReceipt/IDonationReceiptService.cs` (`GenerateReceiptPdfAsync(int)` + `GenerateReceiptPdfBySessionAsync(string)`, both `Task<byte[]?>`); `.../DonationReceipt/DonationReceiptService.cs` (A4 print-CSS receipt HTML → `IPdfService.GeneratePdfBytesAsync`; resolves org identity/donor/currency/org-settings/payment-method); `Base.API/Controller/ReceiptDownloadController.cs` (anonymous `GET api/ReceiptDownload/{sessionToken}` → PDF or `NotFound()`, generic filename, `[EnableRateLimiting("ReceiptDownload")]`).
  - BE (modified): `Base.Application/DependencyInjection.cs` (`AddScoped<IDonationReceiptService, DonationReceiptService>()`); `Base.API/DependencyInjection.cs` (new `"ReceiptDownload"` fixed-window policy, 10/min/IP); `.../OnlineDonationPages/PublicMutations/ConfirmOnlineDonation.cs` (inject `IDonationReceiptService` + `IEmailTemplateService`; `IssueReceiptEmailAsync` helper — temp-file PDF attachment via `SendComposedEmailForCompanyAsync`, best-effort try/catch, `File.Delete` in finally; wired into `PromoteCapturedDonationAsync`; **replaced all 3 SERVICE_PLACEHOLDER email-send log lines**); `Base.Infrastructure/Seeders/OrgSettingsDefaultSeeder.cs` (`TAX_EXEMPTION_NUMBER` in RECEIPTS group).
  - FE (created): shared primitive `DownloadReceiptButton` in `public/onlinedonationpage/templates/shared.tsx` (fetch→blob→`URL.createObjectURL` download; prefers mutation `receiptUrl`, falls back to `${BASE_SERVICE_API_ENDPOINT}/receiptdownload/${paymentSessionId}`; renders nothing if neither exists; idle/loading/error states, `Skeleton` while fetching, solid-`accent` button + white `ph:download-simple` icon).
  - FE (modified): `templates/types.ts` (`ThankYouResult` +`receiptNumber`/`receiptUrl`/`paymentSessionId`); `components/donation-form.tsx` (`onSuccess` payload + both call sites now pass `receiptUrl` + `paymentSessionId`); all 9 `templates/thank-you-*.tsx` (drop the button near `SocialShareButtons`). `donation-page.tsx` needed no edit (generic typing already propagates the widened result).
  - DB (SPEC/seed — user-owned): `sql-scripts-dyanmic/orgsettings-tax-exemption-number-seed.sql` (idempotent per-tenant `TAX_EXEMPTION_NUMBER` seed, `NOT EXISTS`-guarded, `BEGIN/COMMIT`).
- **Contract note**: FE download URL = `api/receiptdownload/{paymentSessionId}` — matches BE `api/ReceiptDownload/{sessionToken}` (ASP.NET routing case-insensitive; `sessionToken`≡`PaymentSessionId`). BE did NOT populate the confirm response's `ReceiptUrl` field — unnecessary since the FE builds the token URL from `paymentSessionId` it already holds; change surface kept minimal.
- **Deviations from spec**: Used `IPdfService.GeneratePdfBytesAsync` (in-memory bytes) over the disk-path variant (bytes serve both email temp-file + download response, no redundant disk round-trip). Rate-limit partition is IP-only (`receipt-download-{ip}`) — sufficient for an anonymous read-only endpoint. Receipt amount = `GlobalDonation.DonationAmount` (no distinct NetAmount field). Added new OrgSettings ParamCode `TAX_EXEMPTION_NUMBER` (fallback to `Company.TaxId`) — no real 80G certificate-number field existed; delivered as EAV seed, NOT a migration.
- **Build verification**: **NONE run — per user directive ("avoid BE build - i will build").** BE self-checked by reading real source: all domain-model props (`GlobalDonation`/`Company`/`Currency`/`GlobalOnlineDonation`/`OnlineDonationStaging`/`ContactEmailAddress`), service signatures (`IPdfService`/`IEmailTemplateService`/`IOrgSettingsService`), DbSets, DI + rate-limit blocks verified exact — no outstanding uncertainties. FE `tsc --noEmit` → clean for all 12 edited files (3 pre-existing unrelated `landingContent` errors untouched, out of scope).
- **Known issues opened**: None. **Known issues closed**: ISSUE-3 (receipt email placeholder replaced + PDF service + anonymous token-gated download + FE button).
- **Next step**: User compiles BE + applies `orgsettings-tax-exemption-number-seed.sql`, sets each tenant's `TAX_EXEMPTION_NUMBER` (80G/exemption cert no.), then exercises: confirm a donation → email carries the PDF + Download Receipt button fetches the same PDF on the thank-you page. Screen's other OPEN issues (ISSUE-4/35/38/40 etc.) unchanged.

### Session 54 — 2026-07-16 — ISSUE-42 template-variant content system + ISSUE-41 combined migration — COMPLETED
- **Scope**: Executed ISSUE-42 (template-variant content) and finalized ISSUE-41 into ONE combined migration. Phase 1: revised §⑥ (dispatcher `donation-page.tsx` already exists — NOT rebuilt; added renderer registry + §② MEDIA/relocated-cols catalog). Phase 2: (a) 2 new PageType combo variants; (b) 3 media cols relocated to `MEDIA` EAV wire-stable. Phase 3: ONE user-owned combined migration SPEC.
- **Files touched**:
  - DB (seed): `sql-scripts-dyanmic/online-donation-page-sqlscripts.sql` — "Session 54 migration D" block seeds `CAROUSEL_VIDEO` + `CAROUSEL_IMAGE` MasterData rows (`ONLINEDONATIONPAGETYPE`, idempotent `NOT EXISTS`); updated STEP 0c renderer DataValue comment.
  - FE (created): `public/onlinedonationpage/templates/template-gallery-video.tsx`, `template-gallery-image.tsx`, `thank-you-gallery-video.tsx`, `thank-you-gallery-image.tsx`.
  - FE (modified): `public/onlinedonationpage/donation-page.tsx` — 4 imports + `CAROUSEL_VIDEO`/`CAROUSEL_IMAGE` cases in BOTH switches + header comment; no existing case altered.
  - BE (session 53, confirmed): media relocation in `OnlineDonationPage.cs`, `ResetOnlineDonationPageBranding.cs`, `ValidateOnlineDonationPageForPublish.cs` read from assembled `pres.*`.
  - SPEC: `bug-reports/onlinedonationpage-COMBINED-MIGRATION-SPEC.md` (supersedes ISSUE-41-only spec); backfill via committed `online-donation-page-issue41-backfill-sqlscripts.sql` (all 18 params).
  - Docs: §② relocated-cols/MEDIA catalog, §⑥ renderer registry, Known Issues ISSUE-42 CLOSED.
- **Deviations from spec**: None. Form config (`AmountChipsJson`/`AvailableFrequenciesJson`/`AllowCustomAmount`) kept typed per directive; media fed from EAV-assembled DTO channel.
- **Known issues opened**: None. **Known issues closed**: ISSUE-42 (ISSUE-41 already closed session 53).
- **Build verification**: FE `pnpm exec tsc --noEmit` → 0 errors in the 5 touched files (pre-existing unrelated `landingContent`/`dompurify` project errors untouched, out of scope).
- **Next step**: User applies the ONE combined migration (SPEC file): run committed backfill → verify typed reads + Reset-Branding + Publish validation + SSR/OG (SEO LAST) → single `DROP COLUMN` for all 18. Live `fund.OnlineDonationPages` altered exactly once. Also apply the Session 54 seed block for the 2 combo MasterData rows.

### Session 53 — 2026-07-16 — ISSUE-41 thin-core column relocation EXECUTED (BE + migration specs) — COMPLETED
- **Trigger**: /continue-screen #10 "execute ISSUE-41 — thin-core column relocation per the mapping table in §⑬". User scope: **complete ISSUE-41 only (BE + migration specs), no new FE** (user built the BE; Claude verified + authored the migration specs).
- **Approach**: Option A "storage-only, wire stable" — the 15 cosmetic/presentational typed columns are removed from the EF entity and now persist as EAV rows in `fund."OnlineDonationPageSettings"`. Wire DTOs UNCHANGED (15 typed fields stay); **FE cards + GraphQL UNTOUCHED — BE-only**. Create/Update UPSERT the rows; GetById/GetBySlug RE-ASSEMBLE them into the same typed fields; public SSR OG-meta reads assembled fields.
- **Files touched**:
  - BE: `Helpers/PresentationOnlineDonationPageSettings.cs` (NEW — 15-code writer `BuildRows` + assembler `Assemble` + `ManagedParamCodes`; bool → lowercase `'true'`/`'false'`; nullable NULL/blank → skip; 3 non-nullable bools always emit; `StripScriptTags` relocated here from EntityHelper); `Models/DonationModels/OnlineDonationPage.cs` (15 columns removed, relocation comment); `Data/Configurations/.../OnlineDonationPageConfiguration.cs` (relocated-column `HasMaxLength` removed); `Commands/OnlineDonationPageEntityHelper.cs` (15 field assignments + StripScriptTags removed); `Commands/CreateOnlineDonationPage.cs` (seed presentation rows post-insert, idempotent NOT-EXISTS); `Commands/UpdateOnlineDonationPage.cs` (diff-only upsert; cleared nullable → `ParamValue = null`, not soft-deleted); `Queries/GetOnlineDonationPageById.cs` (re-assemble 15 fields from already-loaded rows); `PublicQueries/GetOnlineDonationPageBySlug.cs` (assemble 15 fields, OG fallback chain preserved); `Commands/SaveOnlineDonationPageLandingContent.cs` (soft-delete sweep now excludes the 15 managed presentation ParamCodes — collision guard).
  - DB (SPEC/seed — user-owned to apply): `sql-scripts-dyanmic/online-donation-page-issue41-backfill-sqlscripts.sql` (STEP 1 additive backfill, idempotent); `.claude/screen-tracker/bug-reports/onlinedonationpage-ISSUE41-MIGRATION-SPEC.md` (2-step deploy ordering + STEP 2 DROP COLUMN ×15).
  - FE: **None** (per user scope).
- **Build verification**: `dotnet build` (Base.API → transitively Domain/Application/Infrastructure) → **Build succeeded. 3 Warning(s) 0 Error(s)**.
- **Migration (TWO user-owned steps, in order)**: (1) deploy new build + apply backfill seed while columns still exist (EF ignores unmapped columns) → **verify** GetById/GetBySlug re-hydrate + public SSR `<head>` renders `og:*`/`robots` from settings; (2) ONLY THEN author + run the destructive `DROP COLUMN ×15` migration. SEO/OG assembled + verified LAST before drop. Claude did NOT run any `dotnet ef` command or hand-author migration/snapshot (policy).
- **Deviations from spec**: None. Wire contract intentionally preserved (Option A); FE deferred by explicit user scope.
- **Known issues opened**: None. **Known issues closed**: ISSUE-41 (thin-core relocation).
- **Next step**: user applies the 2-step migration (backfill → verify SSR OG head → drop). No BE/FE code work remains for ISSUE-41. Screen's other OPEN issues (P0 live-money gate etc.) remain.

### Session 52 — 2026-07-16 — migration applied + thin-core relocation PLANNED (FIX / PLANNING)
- **Trigger**: /continue-screen #10 — user applied the ISSUE-39 migration, hit a `23505` failure, then decided to reverse "ship as-is" and plan the thin-core column cleanup for next session.
- **Migration outcome**: User ran `Add_OnlineDonationPageSetting`. It failed on an UNRELATED, previously un-migrated model delta bundled into the same migration — the ODP-B5 idempotency partial-unique index `UX_GlobalOnlineDonations_Company_GatewayTxn` on `fund.GlobalOnlineDonations (CompanyId, GatewayTransactionId) WHERE GatewayTransactionId IS NOT NULL AND IsDeleted=false` (defined in `GlobalOnlineDonationConfiguration.cs:80`). Postgres `23505: could not create unique index` = existing duplicate rows (empty-string / repeated test `GatewayTransactionId`). Postgres DDL is transactional so the WHOLE migration rolled back (new table not created either). **Resolved**: user de-duped `GlobalOnlineDonations` (NULL empty-string txn ids / soft-delete genuine dupes), re-ran `dotnet ef database update` → both the idempotency index AND `fund.OnlineDonationPageSettings` landed. Table now live.
- **Decision reversed**: The 2026-07-16 "ship as-is" (keep the ~19 typed columns) is **superseded** — user chose to proceed with the thin-core relocation, but as **next-session** work. Logged as **ISSUE-41 (OPEN, MED, PLANNED)** with candidate column list, keep-list, SSR/SEO build-time caution, and the two-step (additive backfill → verified drop) user-owned migration plan.
- **Change** (this session): prompt-file only — ISSUE-41 added to §⑬ Known Issues; frontmatter `status: COMPLETED → NEEDS_FIX`. No BE/FE/DB code touched.
- **Deviations from spec**: None (planning + status transition only).
- **Known issues opened**: ISSUE-41 (thin-core relocation, PLANNED). **Known issues closed**: None (ISSUE-39 already closed session 51).
- **Build verification**: N/A — no code built this session. Migration verification owned by user (confirmed applied).
- **Next step**: `/continue-screen #10` next session to execute ISSUE-41 — Sonnet BE (settings-row backfill assembler + reads re-pointed to settings channel + migration SPEC step 1 additive, step 2 drop) then FE (drop relocated fields from typed DTO, route via `landingContent`/settings). Migrate + verify SSR OG-meta BEFORE the destructive column drop.
