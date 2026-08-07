# Public-Page EAV Settings Port — P2P Campaign Page, P2P Fundraiser Page, Crowdfunding Page

**Authored**: 2026-07-20
**Source pattern**: Screen #10 Online Donation Page (ISSUE-39 → ISSUE-41 → ISSUE-42 → ISSUE-44/45/47 → ISSUE-50)
**Target screens**: #170 P2P Campaign Pages (EXTERNAL_PAGE / P2P_FUNDRAISER) · #173 Crowdfunding Page (EXTERNAL_PAGE / CROWDFUND)
**Status**: SPEC — not yet built. Feed this file to `/continue-screen #170` and `/continue-screen #173`.

---

## 0. Scope decision (read first)

The request named three things: *p2p campaign, p2p fundraisers, crowd funding*. In the codebase those are **three public surfaces owned by two registry screens**:

| # | Surface | Registry screen | Public route | Scope key |
|---|---------|-----------------|--------------|-----------|
| A | P2P **Campaign** public page (parent) | #170 | `/[lang]/p2p/[campaignSlug]` | `P2PCampaignPageId` |
| B | P2P **Fundraiser** public page (child) | #170 | `/[lang]/p2p/[campaignSlug]/[fundraiserSlug]` | `P2PFundraiserId` → falls back to parent |
| C | **Crowdfunding** public page | #173 | `/[lang]/crowdfund/[slug]` | `CrowdFundId` |

Registry #135 *P2P Fundraisers* is a **CRM FLOW list screen**, not a public page — it is **OUT OF SCOPE** except that its `fundraiser-page-editor-drawer.tsx` is where the supporter edits their own child-page content, so surface B's admin card lands in that drawer.

**Decision for surface B**: do **NOT** create a third EAV table. The child page inherits all branding/SEO/section copy from its parent (`P2PFundraiser` has no colour/logo/CSS/OG/template columns at all). Surface B reads the **parent's** `P2PCampaignPageSettings` rows. Only the child's already-typed content columns (`PersonalStory`, `CoverImageUrl`, `CustomThankYouMessage`, `SocialShareMessagesJson`) stay where they are. → **Two new tables, not three.**

---

## 1. What "the ODP pattern" actually is

Three separable things were done to #10. Port all three, in this order.

### Part 1 — Thin-core relocation (ISSUE-41 / ISSUE-42)
Cosmetic/presentational **typed columns** were moved off the page entity into a generic per-page EAV table. **The wire DTOs did not change** — Request/Response/Public DTOs keep the same typed fields; only *where they are persisted* moves. Two helpers do the work:

- `BuildRows(pageId, companyId, requestDto)` — Create/Update call this to build the upsert set. Nullable sources that are null/blank are **skipped** (no row → assembler's coded fallback applies on read). Non-nullable bools **always** emit a row.
- `Assemble(rows)` — GetById/GetBySlug call this to re-hydrate the typed fields with the **exact same nullability** the old columns had.
- `ManagedParamCodes[]` — the param codes this family owns, so other writers never collide with them.

Reference: `Base.Application/Business/DonationBusiness/OnlineDonationPages/Helpers/PresentationOnlineDonationPageSettings.cs`.

### Part 2 — Landing Content (ISSUE-39 / ISSUE-44/45/47)
Public-template copy that used to be **hardcoded literals inside the TSX** became admin-editable EAV rows, surfaced as a **"Landing Content"** card in the admin editor with collapsible sub-sections, and consumed by the public template with the old literal as the coded fallback.

- BE: one `Save{Entity}LandingContent` command (diff-only upsert) + `LandingContentDto` assembled into GetById **and** GetBySlug.
- FE admin: a `PARAM_CATALOG` array of `{sectionCode, paramCode, paramName, paramDataType, orderBy, get}`; a 300 ms-debounced effect diffs the current store against `baselineRef` at the param-row level and POSTs **only the changed rows**.
- FE public: `landingContent.X ?? "<the old hardcoded literal>"`.

### Part 3 — ISSUE-50 law (NON-NEGOTIABLE)
> **A diff-only editor must never be paired with an authoritative-payload drop-sweep.**

#10 shipped a handler that soft-deleted every active row absent from the payload. Because the editor posts diffs, editing the hero wiped the previously-saved testimonials and footer. Fix: **no sweep at all.** Clearing a value is expressed by sending that ParamCode with an empty `ParamValue`, which the upsert already handles — the sweep modelled nothing the upsert didn't.

Also port the FE guard: an `EMPTY_LANDING_CONTENT` module-level sentinel used as `page?.landingContent ?? EMPTY_LANDING_CONTENT`; the autosave effect returns early on identity match with it, so a raced/empty refetch can never flush a blanking payload.

Reference: `Commands/SaveOnlineDonationPageLandingContent.cs` (see the `NOTE (ISSUE-50, 2026-07-20)` comment block) and `landing-content-section.tsx`.

---

## 2. New EAV tables (USER-OWNED MIGRATIONS — spec only)

> **Migrations are strictly user-owned.** Do not run `dotnet ef migrations add` / `database update` / `remove`, and do not hand-author a migration or a model snapshot. Build to prove the entity + configuration compile, then hand the user this spec.

Both tables mirror `fund.OnlineDonationPageSettings` exactly, changing only the scope FK.

### 2a. `fund.P2PCampaignPageSettings`

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `P2PCampaignPageSettingId` | int identity ALWAYS | NN | PK |
| `P2PCampaignPageId` | int | NN | FK → `fund.P2PCampaignPages`, RESTRICT |
| `CompanyId` | int | NN | FK → tenant, RESTRICT |
| `SectionCode` | varchar(40) | NN | stored UPPER |
| `ParamCode` | varchar(60) | NN | stored UPPER |
| `ParamName` | varchar(120) | NULL | admin-facing label |
| `ParamDataType` | varchar(20) | NN | `string\|text\|int\|decimal\|bool\|url\|color\|json` |
| `ParamValue` | text | NULL | NULL ⇒ renderer's built-in default |
| `OrderBy` | int | NN | |
| `CreatedBy` / `ModifiedBy` | int | NULL | |
| `CreatedDate` / `ModifiedDate` | **timestamptz** | NULL | `Kind=Utc` — Npgsql throws on `Unspecified` |
| `IsActive` | bool | NN | |
| `IsDeleted` | bool | NN | |

Indexes:
- `IX_P2PCampaignPageSettings_PageId_ParamCode_Active` on (`P2PCampaignPageId`, `ParamCode`) filtered `WHERE "IsDeleted" = false`
- `IX_P2PCampaignPageSettings_PageId_SectionCode_OrderBy` on (`P2PCampaignPageId`, `SectionCode`, `OrderBy`)

### 2b. `fund.CrowdFundSettings`
Identical, with `CrowdFundSettingId` PK and `CrowdFundId` → `fund.CrowdFunds`. Same two indexes with `CrowdFundId` in place of `P2PCampaignPageId`.

### Files to create per table
```
Base.Domain/Models/DonationModels/P2PCampaignPageSetting.cs          (singular entity, plural table — mirror OnlineDonationPageSetting.cs)
Base.Infrastructure/Data/Configurations/DonationConfigurations/P2PCampaignPageSettingConfiguration.cs
IApplicationDbContext + ApplicationDbContext: DbSet<P2PCampaignPageSetting> P2PCampaignPageSettings
```
…and the `CrowdFundSetting` equivalents. Entity carries `[CaseFormat("upper")]` on `SectionCode`/`ParamCode` and the static `Create(...)` factory, exactly as #10 does.

---

## 3. Surface A — P2P Campaign page (#170)

### 3a. Columns to relocate off `P2PCampaignPage` (Part 1)

Helper: `Base.Application/.../P2PCampaignPages/Helpers/PresentationP2PCampaignPageSettings.cs`

| Section | ParamCode | Source column | DataType | Row when null? |
|---------|-----------|---------------|----------|----------------|
| THEME | `PAGE_THEME` | `PageTheme` | string | always (NN) |
| THEME | `PRIMARY_COLOR` | `PrimaryColorHex` | color | always (NN) |
| THEME | `SECONDARY_COLOR` | `SecondaryColorHex` | color | always (NN) |
| THEME | `HEADER_STYLE` | `HeaderStyle` | string | always (NN) |
| THEME | `CUSTOM_CSS` | `CustomCssOverride` | text | skip if blank — **StripScriptTags on write** |
| MEDIA | `LOGO_URL` | `LogoUrl` | url | skip if blank |
| SECTIONS | `SHOW_ORGANIZATION_INFO` | `ShowOrganizationInfo` | bool | always |
| SECTIONS | `SHOW_IMPACT_STATS` | `ShowImpactStats` | bool | always |
| SECTIONS | `SHOW_DONOR_WALL` | `ShowDonorWall` | bool | always |
| SECTIONS | `SHOW_LEADERBOARD` | `ShowLeaderboard` | bool | always |
| SECTIONS | `SHOW_FUNDRAISER_COUNT` | `ShowFundraiserCount` | bool | always |
| SECTIONS | `ACHIEVEMENT_BADGES_ENABLED` | `AchievementBadgesEnabled` | bool | always |
| SOCIAL | `DEFAULT_SHARE_MESSAGE` | `DefaultShareMessage` | text | skip if blank |
| SEO | `OG_TITLE` | `OgTitle` | string | skip if blank |
| SEO | `OG_DESCRIPTION` | `OgDescription` | text | skip if blank |
| SEO | `OG_IMAGE_URL` | `OgImageUrl` | url | skip if blank |
| SEO | `ROBOTS_INDEXABLE` | `RobotsIndexable` | bool | always (default **true** on read) |

**Stays typed on the entity** (business, not cosmetic): `PageTemplateId` (real FK to MasterData — never EAV a FK), slug, status, dates, all goal/team/donation/gateway/email-template/WhatsApp/invitation columns.

Migration step 2 (user-owned, run **after** the backfill in §6): drop the 17 relocated columns from `fund.P2PCampaignPages`.

### 3b. Landing Content catalog (Part 2)

New card **"Landing Content"** in `tabs/branding-page-tab.tsx`, placed after `"Page Sections"`. Each entry's fallback is the literal currently hardcoded in the TSX — keep the literal in the component as `?? "…"` so an unconfigured page renders exactly as it does today.

| Section | ParamCode | Type | Current hardcoded fallback | Rendered by |
|---------|-----------|------|----------------------------|-------------|
| HERO | `HERO_ICON` | string | `ph:flag-banner` | `components/parent-hero.tsx` |
| HERO | `HERO_BYLINE_PREFIX` | string | `by ` | `components/parent-hero.tsx` |
| HERO | `ORG_NAME_FALLBACK` | string | `Our Organization` | `templates/parent-templates.tsx`, `child-fundraiser-page.tsx` |
| HEADER | `HEADER_NAV_LINKS` | json | `[{label:"About",href:"/{lang}/about"},{label:"All Campaigns",href:"/{lang}/p2p"}]` | `components/org-header.tsx` |
| PROGRESS | `PROGRESS_DONORS_LABEL` | string | `donors` | `components/progress-section.tsx` |
| PROGRESS | `PROGRESS_FUNDRAISERS_LABEL` | string | `fundraisers` | ″ |
| PROGRESS | `PROGRESS_DAYS_LEFT_LABEL` | string | `days left` | ″ |
| PROGRESS | `PROGRESS_GOAL_SUFFIX` | string | `of {goal} goal` | ″ |
| PROGRESS | `CTA_DONATE_LABEL` | string | `DONATE NOW` | `progress-section.tsx`, `mobile-donate-bar.tsx` |
| PROGRESS | `CTA_FUNDRAISER_LABEL` | string | `BECOME A FUNDRAISER` | `progress-section.tsx` |
| PROGRESS | `ENDED_MESSAGE` | text | `This campaign has ended.` | ″ |
| PROGRESS | `DONATIONS_UNAVAILABLE_MESSAGE` | text | `Donations are currently unavailable.` | `parent-templates.tsx` |
| STORY | `STORY_TITLE` | string | `Campaign Story` | `parent-templates.tsx` (all 5 variants) |
| LEADERBOARD | `LEADERBOARD_TITLE` | string | `Top Fundraisers` | `components/leaderboard.tsx` |
| LEADERBOARD | `LEADERBOARD_MEDALS` | json | `["🥇","🥈","🥉"]` | ″ |
| LEADERBOARD | `LEADERBOARD_EMPTY` | text | `Be the first to donate to a fundraiser!` | ″ |
| DONOR_WALL | `DONOR_WALL_TITLE` | string | `Recent Donors` | `components/donor-wall.tsx` |
| DONOR_WALL | `DONOR_WALL_EMPTY` | text | `No donations yet — be the first to donate!` | ″ |
| DONOR_WALL | `ANONYMOUS_LABEL` | string | `Anonymous` | ″ |
| IMPACT_STATS | `IMPACT_STATS_TITLE` | string | `Impact` | `components/impact-stats.tsx` |
| IMPACT_STATS | `IMPACT_STATS` | json | **`[{emoji:"🎓",value:"690",label:"Children Funded"},{emoji:"📚",value:"2,300",label:"Textbooks Provided"}]`** | ″ |
| SHARE | `SHARE_TITLE` | string | `Share this fundraiser` | `components/share-buttons.tsx` |
| SHARE | `SHARE_CHANNELS` | json | `["facebook","twitter","whatsapp","linkedin","copy"]` | ″ |
| FOOTER | `FOOTER_TAGLINE` | text | `{orgName} © {year} · Powered by PeopleServe` | `components/public-footer.tsx` |
| FOOTER | `FOOTER_TREE` | json | `[{label:"Privacy",href:"/privacy"},{label:"Terms",href:"/terms"}]` | ″ |
| FOOTER | `FOOTER_CONTACT` | json | *(none today)* | ″ |
| FOOTER | `FOOTER_SOCIALS` | json | *(none today)* | ″ |
| MOBILE_BAR | `MOBILE_RAISED_LABEL` | string | `raised so far` | `components/mobile-donate-bar.tsx` |

> **`IMPACT_STATS` is the highest-priority row in this whole spec.** `impact-stats.tsx` today renders a **fake reference array** (`690 Children Funded`, `2,300 Textbooks Provided`) to every visitor whenever `ShowImpactStats` is true. That is fabricated impact data on a live fundraising page. Until the EAV row exists, the component must render **nothing** rather than the placeholder.

Reuse the ODP footer editor wholesale: `FOOTER_TREE` is the parent→child hierarchy (parent label + optional icon/image/link, N children each with optional icon/image/link) already built for #10 — lift the component, don't redesign it.

### 3c. Surface B (child fundraiser page) additions

No new table. The child page reads the **parent's** rows via the parent nav in `GetP2PFundraiserBySlug.cs`. Two child-only params live in the same parent-scoped table under section `CHILD` because they are campaign-wide policy, not per-supporter copy:

| Section | ParamCode | Type | Fallback | Rendered by |
|---------|-----------|------|----------|-------------|
| CHILD | `CHILD_STORY_TITLE` | string | `My Story` | `components/child-story.tsx` |
| CHILD | `CHILD_UPDATES_TITLE` | string | `Updates` | `components/child-updates.tsx` |
| CHILD | `CHILD_UPDATES_EMPTY` | text | `The fundraiser hasn't posted any updates yet. Check back soon for progress notes and photos.` | ″ |
| CHILD | `CHILD_TEAM_EMPTY` | text | `Team-member roster will appear here when teammates register.` | `components/child-team-section.tsx` |
| CHILD | `CHILD_PROGRESS_DONORS_LABEL` | string | `donors` | `components/child-progress-widget.tsx` |
| CHILD | `CHILD_PROGRESS_VIEWS_LABEL` | string | `views` | ″ |
| CHILD | `CHILD_ANON_NAME` | string | `Anonymous Fundraiser` | `components/child-cover-profile.tsx` |
| CHILD | `CHILD_PARENT_BACK_LABEL` | string | `View Campaign` | `child-fundraiser-page.tsx` |
| CHILD | `CHILD_PAUSED_MESSAGE` | text | `This page is paused. Donations are temporarily unavailable.` | ″ |
| CHILD | `CHILD_ENDED_MESSAGE` | text | `This campaign has ended. Donations are closed.` | ″ |

These render in the parent editor's Landing Content card under a **"Fundraiser Pages"** sub-section — the campaign owner sets them once for every child page. The supporter's own drawer (`fundraiser-page-editor-drawer.tsx`) is **unchanged**; supporters keep editing only their typed columns.

### 3d. Two bugs to fix while in here
- `components/leaderboard.tsx` hardcodes a `₹` currency prefix. Use the campaign's currency, same as `child-progress-widget.tsx`.
- `templates/parent-templates.tsx` FESTIVAL variant hardcodes hexes `#06060d` / `#0b0c14`. Derive from `PAGE_THEME` / `PRIMARY_COLOR`, or move to `CUSTOM_CSS`.

---

## 4. Surface C — Crowdfunding page (#173)

### 4a. Columns to relocate off `CrowdFund` (Part 1)

Helper: `Base.Application/.../CrowdFunds/Helpers/PresentationCrowdFundSettings.cs`

| Section | ParamCode | Source column | DataType | Row when null? |
|---------|-----------|---------------|----------|----------------|
| THEME | `PRIMARY_COLOR` | `PrimaryColorHex` | color | always (NN) |
| THEME | `ACCENT_COLOR` | `AccentColorHex` | color | always (NN) |
| THEME | `BACKGROUND_COLOR` | `BackgroundColorHex` | color | always (NN) |
| THEME | `FONT_FAMILY` | `FontFamily` | string | always (NN) |
| MEDIA | `LOGO_URL` | `LogoUrl` | url | skip if blank |
| MEDIA | `HERO_IMAGE_URL` | `HeroImageUrl` | url | skip if blank |
| MEDIA | `HERO_VIDEO_URL` | `HeroVideoUrl` | url | skip if blank |
| SECTIONS | `ENABLED_SECTIONS` | `EnabledSectionsJson` | json | always (NN) |
| SECTIONS | `SHOW_GOAL_THERMOMETER` | `ShowGoalThermometer` | bool | always |
| SECTIONS | `SHOW_DONOR_COUNT` | `ShowDonorCount` | bool | always |
| SECTIONS | `SHOW_DONOR_WALL` | `ShowDonorWall` | bool | always |
| CONTENT | `HEADLINE` | `Headline` | string | skip if blank |
| CONTENT | `STORY_RICH_TEXT` | `StoryRichText` | text | skip if blank — sanitize on write |
| CONTENT | `IMPACT_BREAKDOWN` | `ImpactBreakdownJson` | json | skip if null/empty |
| CONTENT | `FAQS` | `FaqJson` | json | skip if null/empty |
| CONTENT | `BENEFICIARIES` | `BeneficiariesJson` | json | skip if null/empty |
| CONTENT | `MILESTONES` | `MilestonesJson` | json | skip if null/empty |
| CONTENT | `UPDATES` | `UpdatesJson` | json | skip if null/empty |
| SOCIAL | `DEFAULT_SHARE_MESSAGE` | `DefaultShareMessage` | text | skip if blank |
| SEO | `OG_TITLE` / `OG_DESCRIPTION` / `OG_IMAGE_URL` | same | string/text/url | skip if blank |
| SEO | `ROBOTS_INDEXABLE` | `RobotsIndexable` | bool | always (default **true**) |

**Stays typed**: `PageTemplateId` (FK), `CampaignName`, `Slug`, `PageStatus`, `Currency`, `GoalAmount`, `StretchGoalAmount`, `GoalExceededBehavior`, dates, `DonationPurposeId`, `CampaignCategory`, `OrganizationalUnitId`, all donation/gateway/email/WhatsApp/invitation columns.

> **`ImpactBreakdownJson` / `FaqJson` / `BeneficiariesJson` / `MilestonesJson` / `UpdatesJson` relocate LAST**, after the pure-cosmetic ones are proven green. They are the largest payloads and the ones the public page most depends on. `UpdatesJson` grows unbounded over a campaign's life — if a row exceeds ~64 KB in practice, leave it typed and note the exception.

Migration step 2 (user-owned, after backfill): drop the relocated columns from `fund.CrowdFunds`.

### 4b. Landing Content catalog (Part 2)

New card **"Landing Content"** in `tabs/page-builder-tab.tsx`, region **"Main content"**, after `"Campaign Updates"`.

| Section | ParamCode | Type | Current hardcoded fallback | Rendered by |
|---------|-----------|------|----------------------------|-------------|
| TRUST | `TRUST_BADGES` | json | **`[{icon:"ph:shield-check-duotone",title:"Secure Donation",sub:"100% secure & encrypted"},{icon:"ph:eye-duotone",title:"Transparent Impact",sub:"See where your money goes"},{icon:"ph:heart-duotone",title:"Trusted Organization",sub:"Committed to making change"}]`** | `trust-badges.tsx` |
| HEADINGS | `YOUR_IMPACT_TITLE` | string | `Your Impact` | `your-impact-list.tsx` |
| HEADINGS | `DONUT_TITLE` | string | `Where Your Donation Goes` | `donation-donut.tsx` |
| HEADINGS | `GIFT_IMPACT_TITLE` | string | `What Your Gift Does` | `impact-list.tsx` |
| HEADINGS | `MILESTONES_TITLE` | string | `Milestones` | `milestones-timeline.tsx` |
| HEADINGS | `UPDATES_TITLE` | string | `Campaign Updates` | `updates-feed.tsx` |
| HEADINGS | `DONOR_WALL_TITLE` | string | `Recent Donors` | `donor-wall.tsx` |
| HEADINGS | `FAQ_TITLE` | string | `Frequently Asked Questions` | `faq-accordion.tsx` |
| BENEFICIARIES | `BENEFICIARIES_TITLE` | string | `Meet Our Beneficiaries` | `beneficiaries-showcase.tsx` |
| BENEFICIARIES | `BENEFICIARIES_SUBTEXT` | text | `Real stories from real people whose lives have been changed because of your support.` | ″ |
| STATS_BAR | `STATS_RAISED_LABEL` | string | `Raised` | `impact-stats-bar.tsx` |
| STATS_BAR | `STATS_DONORS_LABEL` | string | `Donors` | ″ |
| STATS_BAR | `STATS_OF_GOAL_LABEL` | string | `Of Goal` | ″ |
| STATS_BAR | `STATS_DAYS_LEFT_LABEL` | string | `Days Left` | ″ |
| STATS_BAR | `STATS_FOOTNOTE` | text | `Across {n} donations — thank you for making a difference.` | ″ |
| PROGRESS | `PROGRESS_FUNDED_LABEL` | string | `funded` | `progress-widget.tsx` |
| PROGRESS | `PROGRESS_ENDED_LABEL` | string | `Campaign ended` | ″ |
| SHARE | `SHARE_TITLE` | string | `Share this campaign` | `share-buttons.tsx` |
| SHARE | `SHARE_CHANNELS` | json | `["facebook","twitter","whatsapp","copy"]` | ″ |
| THANKYOU | `THANKYOU_TITLE` | string | `Thank You!` | `thank-you-state.tsx` |
| THANKYOU | `THANKYOU_BODY` | text | `Your donation has been received. A confirmation email will be sent shortly.` | ″ |
| THANKYOU | `THANKYOU_RECEIPT_LABEL` | string | `View / Download Receipt` | ″ |
| THANKYOU | `THANKYOU_AGAIN_LABEL` | string | `Donate Again` | ″ |
| BANNERS | `BANNER_ARCHIVED` | text | `This campaign has been archived and is no longer accepting donations.` | `edge-banners.tsx` |
| BANNERS | `BANNER_CLOSED` | text | `This campaign is now closed. Thank you to everyone who donated!` | ″ |
| BANNERS | `BANNER_GOAL_MET_CLOSED` | text | `Goal reached! This campaign has closed. Donations are no longer accepted.` | ″ |
| BANNERS | `BANNER_GOAL_MET_OPEN` | text | `Goal reached! Donations are still open — every contribution makes a difference.` | ″ |
| BANNERS | `BANNER_NOT_STARTED` | text | `This campaign has not started yet. Donations will open soon.` | ″ |
| BANNERS | `BANNER_URGENCY` | text | `Only {n} days remaining!` | ″ |
| FOOTER | `FOOTER_TAGLINE` | text | `Campaign organized by {orgName}` | `public-footer.tsx` |
| FOOTER | `FOOTER_TREE` | json | *(none today)* | ″ |
| FOOTER | `FOOTER_CONTACT` | json | *(none today)* | ″ |
| FOOTER | `FOOTER_SOCIALS` | json | *(none today)* | ″ |
| MOBILE_BAR | `MOBILE_RAISED_LABEL` | string | `raised so far` | `mobile-donate-bar.tsx` |
| MOBILE_BAR | `CTA_DONATE_LABEL` | string | `DONATE NOW` | ″ |

**`BANNER_PREVIEW`** (`Preview Mode — this page is not yet public…`) stays hardcoded — it is an admin-only affordance, never seen by a donor.

### 4c. Bugs to fix while in here
- `share-buttons.tsx` SSR placeholder `https://example.com/crowdfund/${slug}` — must resolve from the request host, not a literal.
- `donation-donut.tsx` `PALETTE_TAIL` hexes and `milestones-timeline.tsx` status colours (`#f97316`/`#d1d5db`) — replace with design tokens.
- `<pre>`/`{n} day{s}` pluralisation strings must survive the EAV port with the placeholder tokens intact (`{n}`, `{goal}`, `{orgName}`) — the renderer interpolates, the admin edits the template string.

---

## 5. BE command shape (identical for both screens)

```
Commands/Save{P2PCampaignPage|CrowdFund}LandingContent.cs
```

Copy `SaveOnlineDonationPageLandingContent.cs` verbatim and change the entity/DbSet/scope names. Preserve **all** of:

1. `[CustomAuthorize(DecoratorDonationModules.<Module>, Permissions.Modify)]`.
2. Tenant + ownership check — page must exist under `httpContextAccessor.GetCurrentUserStaffCompanyId()`, else `BadRequestException`.
3. Validator: `SectionCode` ≤40 NN, `ParamCode` ≤60 NN, `ParamName` ≤120, `ParamDataType` ≤20 NN, and `BeValidJsonWhenJsonType` (blank json allowed → renderer falls back).
4. Upsert keyed on `ParamCode.ToUpperInvariant()`; update in place (SectionCode/ParamName/ParamDataType/ParamValue/OrderBy), else `Create(...)`.
5. **NO drop-sweep** — carry the `NOTE (ISSUE-50)` comment across so nobody re-adds one.
6. `catch (DbUpdateException)` → `InternalServerException`; rethrow `BadRequestException`.

`GetById` and the public `GetBySlug` both assemble `LandingContentDto` from the rows and expose it alongside the existing typed fields. For the child fundraiser page, `GetP2PFundraiserBySlug.cs` assembles from the **parent's** `P2PCampaignPageId` rows.

---

## 6. Backfill + migration order (USER-OWNED)

Per screen, **three user-applied steps in this order**. Never collapse them — a single migration that adds the table and drops the columns loses every existing page's branding.

1. **Migration 1** — create the settings table + indexes. Deploy. (Old columns still authoritative.)
2. **Seed script** — `sql-scripts-dyanmic/{screen}-eav-relocation-backfill.sql`: `INSERT … SELECT` one row per relocated column per existing page, skipping NULL/blank sources exactly as `BuildRows` does, `IsDeleted=false`, `CreatedDate = now()` (column is `timestamptz` — plain `now()`, never `now() AT TIME ZONE 'utc'`). Idempotent: guard with `WHERE NOT EXISTS (… AND upper("ParamCode") = …)`. Wrap in `BEGIN; … COMMIT;` with a preview `SELECT` and a `-- ROLLBACK;` escape.
3. **Migration 2** — drop the relocated columns. Only after step 2 is verified on the target DB.

Deploy the BE code that reads from EAV **between** steps 2 and 3.

---

## 7. Acceptance criteria

- [ ] Two new EAV tables exist; **no third table** for the child fundraiser page.
- [ ] `PresentationP2PCampaignPageSettings` and `PresentationCrowdFundSettings` each expose `BuildRows` / `Assemble` / `ManagedParamCodes`, with round-trip nullability identical to the dropped columns.
- [ ] Request/Response/Public DTOs are **unchanged** — no FE consumer of the typed fields breaks.
- [ ] Both `Save…LandingContent` handlers contain **zero** soft-delete sweeps, and carry the ISSUE-50 note.
- [ ] Both admin editors autosave diff-only against a `baselineRef`, with the `EMPTY_LANDING_CONTENT` identity guard.
- [ ] Every public component reads `landingContent.X ?? "<original literal>"` — an unseeded page renders byte-identical to today.
- [ ] `impact-stats.tsx` no longer emits the fabricated `690` / `2,300` reference stats.
- [ ] `trust-badges.tsx` renders from `TRUST_BADGES`, falling back to the three current badges.
- [ ] Child fundraiser page resolves `CHILD_*` params from the **parent's** rows.
- [ ] Leaderboard currency is campaign currency, not hardcoded `₹`.
- [ ] BE compiles (targeted `dotnet build Base.Application`); FE `npx tsc --noEmit` clean of new errors.
- [ ] Both prompt files get a Build Log entry, a Known Issues row per bug opened/closed, and § Sessions capped at 5.
- [ ] **No migration was authored or run by the agent** — only the spec in §2 and the seed in §6.

---

## 8. Suggested session split

| Session | Screen | Scope |
|---------|--------|-------|
| 1 | #170 | Part 1 only — table entity + config + `PresentationP2PCampaignPageSettings` + Create/Update/GetById/GetBySlug wiring + migration spec + backfill seed. No FE change beyond compile. |
| 2 | #170 | Part 2 + 3 — `SaveP2PCampaignPageLandingContent`, `LandingContentDto`, Landing Content admin card, public-template fallbacks, `IMPACT_STATS` + child `CHILD_*` params. |
| 3 | #173 | Part 1 — cosmetic columns only (defer the 5 big JSON content columns). |
| 4 | #173 | Part 1 remainder (JSON content columns) + Parts 2 + 3. |

Do **not** attempt both screens in one session — #10 took ten sessions to reach this shape.
