---
screen: Crowdfunding
registry_id: 16
module: CRM (P2P Fundraising)
status: COMPLETED
scope: FULL
screen_type: FLOW
flow_variant: drawer-only
complexity: High
new_module: NO
planned_date: 2026-05-12
completed_date: 2026-05-13
last_session_date: 2026-05-13
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — `fundraising/crowdfunding-page.html` (1471 lines) contains 3 views in one file: (a) Admin View = card-grid list with 4 KPI tiles + 4 filter chips + 5 sample campaign cards (THIS screen's pixel-perfect spec); (b) Editor Modal = 6-tab full editor (Basic / Content / Donation Settings / Milestones / Updates / Design) — represents the **full entity schema** but the UI is OUT OF SCOPE for this screen (deferred to a future `setting/publicpages/crowdfundingpage` setup screen); (c) Public Preview = donor-facing campaign page (OUT OF SCOPE — future public route `/crowdfund/{slug}`).
- [x] Existing code reviewed — NO `CrowdFund*.cs` entity exists. NO GraphQL endpoints. NO public route. FE route is a 5-line `UnderConstruction` stub at `src/app/[lang]/crm/p2pfundraising/crowdfunding/page.tsx`. **This is a FULL build that introduces the CrowdFund entity end-to-end.**
- [x] Drawer-only FLOW pattern selected (mirrors **P2P Campaign #15** precedent — CRM management grid that monitors an entity whose detailed editor lives at a separate `setting/publicpages/...` screen). Because the setup screen does NOT exist yet, this prompt **creates the entity + minimal Quick-Create dialog** so admins can ship Drafts immediately; full multi-tab editor is a follow-on screen (see §⑫ SCREEN-FOLLOW-UP).
- [x] Business rules + lifecycle defined (Draft → Published → Active → GoalMet → Closed → Archived; goal-exceeded behavior tri-state: KeepAccepting / AutoClose / ShowStretchGoal).
- [x] FK targets resolved (DonationPurpose, Campaign, OrganizationalUnit, CompanyPaymentGateway, EmailTemplate×4, WhatsAppTemplate×1; all existing — no new FK targets needed).
- [x] File manifest computed (10 NEW BE files + 1 EF migration + 5 BE endpoint additions; full FE build over the stub; DB seed with menu + caps + master-data Crowdfunding statuses).
- [x] Approval config pre-filled (MenuCode=`CROWDFUNDING`, ParentMenu=`CRM_P2PFUNDRAISING`, URL=`crm/p2pfundraising/crowdfunding`, OrderBy=3 — sibling of P2PCAMPAIGN OrderBy=1 and P2PFUNDRAISER OrderBy=2 and MATCHINGGIFT OrderBy=4).
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt is exhaustively pre-analyzed; orchestrator validates against §① §② §④ §⑤ rather than re-running BA agent)
- [x] Solution Resolution complete (FLOW-with-drawer-only confirmed; full editor deferred to follow-up screen)
- [x] UX Design finalized (Variant B header + 4 KPI widgets + 4 chips + cards-grid layout + 560px right-side detail Sheet + Quick Create dialog + lifecycle confirm modals + Duplicate / Delete confirm modals)
- [x] User Approval received
- [x] Backend code generated
- [x] Backend wiring complete (DbContext registration, Mapster mappings, DecoratorProperty `CrowdFund`, EF migration hand-crafted — user must run `dotnet ef migrations add` to regen Designer/Snapshot per ISSUE-19)
- [x] Frontend code generated
- [x] Frontend wiring complete (entity-operations CROWDFUNDING block + 3 column-type registries — only used for shared-cell renderers since grid is plain JSX card layout — + shared-cell-renderers barrel + pages barrel + 3 extra wiring barrels: DTO/Query/Mutation indexes)
- [x] DB Seed script generated (`Crowdfunding-sqlscripts.sql` in `sql-scripts-dyanmic/` — typo preserved. Idempotent. Menu @ CROWDFUNDING under CRM_P2PFUNDRAISING OrderBy=3 + 8 caps READ/WRITE/DELETE/DUPLICATE/PUBLISH/UNPUBLISH/CLOSE/ARCHIVE + BUSINESSADMIN grants + Grid FLOW + GridFormSchema=NULL + NO master-data lookup [CrowdFundStatus is a string enum] + 2 sample Draft campaigns for smoke-test)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (no warnings in CrowdFunds folder)
- [ ] EF migration applied (`dotnet ef database update`) — new table `fund."CrowdFunds"` with filtered unique index on `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted` + 2 jsonb columns + status index
- [ ] `pnpm dev` — page loads at `/{lang}/crm/p2pfundraising/crowdfunding` (replaces UnderConstruction stub)
- [ ] Variant B layout renders: ScreenHeader + 4 KPI widgets + DataTableContainer with `showHeader={false}` — NO double-header
- [ ] **4 KPI widgets** (mockup-pixel-match):
  - Active Campaigns — value=`activeCount`, subtitle=`Total: {totalCount}`, icon=`Megaphone` Lucide, tint=teal
  - Total Raised — value=`totalRaised` formatted currency, subtitle=`Across all campaigns`, icon=`HandCoins` Lucide, tint=green
  - Total Donors — value=`totalDonors` (int with thousands sep), subtitle=`Unique supporters`, icon=`Users` Lucide, tint=blue
  - Goals Met — value=`goalsMetCount`, subtitle=`{completionRate}% completion rate`, icon=`Trophy` Lucide, tint=purple
- [ ] **4 status filter chips**: All / Active / Goal Met / Draft — counts from `CrowdFundSummary` query (`allCount / activeCount / goalMetCount / draftCount`). Server-side filter, NOT client-side.
- [ ] **Search input**: by Campaign Name OR Category (server-side via `searchTerm` arg of `GetAllCrowdFundList`)
- [ ] **Cards grid** (responsive: auto-fill, minmax(320px, 1fr), gap 20px):
  - Each card = hero gradient block (160px height) with category icon centered + status badge floating top-right
  - Body: campaign name (click → opens drawer) + progress bar with %-fill (3-tier color OR `complete` green when 100%) + amounts row (raised bold accent / "of $50,000 (76.8%)" muted) + meta row (donor count + ends-date) + actions row (varies per status)
- [ ] **Per-card inline actions** (status-driven, right-aligned within card footer):
  - Active OR Published → Edit + View Page + Dashboard
  - Goal Met (Closed with raised ≥ goal) → View Page + Dashboard + Close (red-tint outline)
  - Draft → Edit + Preview + Publish (accent-tint outline)
  - Archived → View Page + Duplicate
- [ ] **Card click on name** (or hero — but NOT actions row) → opens 560px right-side detail Sheet
- [ ] **Detail Sheet** (mockup-mirror, 6 sections — CRM dashboard view, NOT page editor):
  1. **Campaign Summary** — Slug (read-only with copy button → copies `{baseUrl}/crowdfund/{slug}`) + Category chip + Status badge + Created/Published dates + Goal + Raised + Progress bar + Days Remaining (if Timed; "Always Active" / "Ended N days ago" otherwise)
  2. **Performance Metrics** — 4-tile grid: Total Donors, Avg Donation, Largest Donation, Donations This Week (week-over-week % delta caption when computable)
  3. **Milestones** — list from `MilestonesJson` (parsed): Reached (green check) / In Progress (blue spinner) / Upcoming (slate flag) + amount + label. Empty state: "No milestones configured."
  4. **Recent Donors** — top-5 from `fund.GlobalDonations WHERE CrowdFundId={id} ORDER BY CreatedDate DESC LIMIT 5` (BE projects in `GetCrowdFundStats`). Each item: avatar (initials or anon-icon) + donor name (or "Anonymous") + amount + relative timestamp + optional 1-line message preview.
  5. **Latest Updates** — top-3 from `UpdatesJson` (parsed): date + title + first 100 chars of content. Footer: "View all {N} updates →" routes to FUTURE setup screen Tab Updates (or shows "in editor screen" when FUTURE path is not yet built).
  6. **Quick Actions** — 4 vertical buttons:
     - Edit Full Setup → SCREEN-FOLLOW-UP deep-link `/setting/publicpages/crowdfundingpage?id={id}` (graceful 404 today; future)
     - View Public Page → `{baseUrl}/crowdfund/{slug}` in new tab (FUTURE — see §⑫ ISSUE-PUBLIC-PAGE)
     - Copy Public URL → clipboard with toast
     - Quick Edit Basic → opens Quick-Edit dialog (8 Basic fields only — same as Quick-Create)
- [ ] **+ Create Campaign Page** header button → opens Quick Create dialog (8 fields from mockup's Basic tab: Campaign Name / Slug auto-from-name with edit / Goal Amount + Currency / Start Date / End Date / Linked Donation Purpose (FK ApiSelectV2) / Campaign Category (string enum dropdown) / Organizational Unit (FK ApiSelectV2)). On submit → creates `Draft` row → toast "Campaign created as Draft" → refresh list + summary + opens new row's drawer.
- [ ] **Per-card status modals**:
  - Publish confirm — "Publish '{name}'? This will make the campaign live at `{baseUrl}/crowdfund/{slug}` and start accepting donations."
  - Close confirm — "Close '{name}'? Donations will no longer be accepted. You can re-publish later if needed."
  - Archive confirm — "Archive '{name}'? Archived campaigns are hidden from the active list but retained for reporting."
  - Duplicate confirm — "Create a draft copy of '{name}'? The new campaign will start in Draft status with a new slug like '{slug}-copy'. Donors and donations will NOT be copied."
  - Delete confirm (Draft only) — "Delete '{name}'? This Draft has no donations and cannot be recovered."
- [ ] **Pagination**: cards grid uses 12/24/48 per-page (default 12); inline pager beneath cards.
- [ ] **Empty state**: when 0 campaigns → "No crowdfunding campaigns yet" + Create Campaign Page CTA
- [ ] **Filtered empty state**: when chip/search yields 0 → "No campaigns match your filters" + Clear Filters button
- [ ] **Loading state**: skeleton cards (matching dimensions) + skeleton KPI tiles
- [ ] **Error state**: red banner + retry button
- [ ] DB Seed — admin menu visible at `CRM > P2P Fundraising > Crowdfunding`; cards-grid + chips + actions all functional against the 2 seeded Draft campaigns
- [ ] **5 UI uniformity grep checks PASS**:
  - 0 inline hex in `style={{...}}` outside designated renderers
  - 0 inline px in `style={{...}}` outside designated renderers (hero gradient inline-style allowed per §⑥ ISSUE)
  - 0 raw `Loading...` strings (use Skeleton)
  - 0 `fa-*` className refs (use Lucide / Phosphor icons)
  - 0 inline-hex skeleton background

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Crowdfunding
Module: CRM (P2P Fundraising sub-module — sibling of P2PCampaign #15, P2PFundraiser #135, MatchingGift #11)
Schema: `fund` (NEW entity `CrowdFund` added by this build)
Group: DonationModels (existing — established by #170 P2PCampaignPage 2026-05-09; this build adds CrowdFund alongside P2PCampaignPage in the same group/schema)

**Business**: This is the **CRM management surface for crowdfunding campaigns** — goal-based, deadline-driven fundraisers with a donor-facing public page (like GoFundMe / Kickstarter for non-profits). Where P2P Campaign #15 lets supporters fundraise on the org's behalf (peer-to-peer), Crowdfunding is **org-led**: the NGO defines a specific need (build a school, emergency relief, mobile clinic), sets a goal + deadline + impact-breakdown + milestones, and donors give directly to the campaign. The org runs multiple concurrent campaigns; this CRM screen is the BUSINESSADMIN's portfolio view.

The mockup (`crowdfunding-page.html`) shows a 4-KPI header (Active Campaigns / Total Raised / Total Donors / Goals Met) over a **responsive cards grid** (NOT a table — each campaign is a visual card with hero gradient, status badge, name, progress bar, raised/goal amounts, donor count, end-date, and 3 action buttons). 4 filter chips (All / Active / Goal Met / Draft) drive server-side status filtering. Card click opens a 560px right-side detail Sheet (6 sections including milestones + recent donors + latest updates).

The mockup also includes a 6-tab editor modal (Basic / Content / Donation Settings / Milestones / Updates / Design) representing the **full entity schema** for content editing — but **that UI is OUT OF SCOPE for this screen**. The editor surface will live at a future `setting/publicpages/crowdfundingpage` screen (mirroring the OnlineDonationPage / P2PCampaignPage pattern). This prompt builds the **entity + summary + Quick-Create + lifecycle actions + drawer**; the rich tabbed editor is a follow-up build.

**Who uses it**: BUSINESSADMIN (and any role with `CROWDFUNDING.READ`) to monitor campaign health, trigger lifecycle transitions (Publish / Close / Archive), and create new Draft campaigns. Donor-facing public page consumption is handled separately by a future public route.

**Why FLOW-with-drawer-only (no view-page on this screen)**: Reconciliation #14 + P2PCampaign #15 + P2PFundraiser #135 precedent. The cards grid + drawer + inline actions cover the CRM monitoring workflow. The "edit campaign content" surface (story, impact, milestones, updates, design) lives at a future setup screen — building a 3-mode view-page here would either (a) duplicate that future screen or (b) ship an inadequate stub. Instead, this screen ships a focused monitoring view with a Quick-Create dialog for the essential 8 fields, and defers rich content editing to the dedicated setup screen.

**Why NOT a duplicate of P2P Campaign #15**: Different business model and UI:
- P2P Campaign #15 — supporters fundraise on org's behalf; primary metric is **fundraisers**; UI is a 10-column data **table**
- Crowdfunding #16 — org runs goal-based campaign directly; primary metric is **goal completion %**; UI is a visual **cards grid**

Same `CRM_P2PFUNDRAISING` parent menu (because both are peer-to-peer-style fundraising surfaces), but different entities, different aggregates, different layouts.

**Related screens** (per registry):
- #15 P2P Campaign (COMPLETED) — sibling under CRM_P2PFUNDRAISING, drawer-only FLOW precedent
- #135 P2P Fundraiser (PROMPT_READY) — sibling fundraiser-level grid
- #11 Matching Gift (COMPLETED) — sibling under CRM_P2PFUNDRAISING
- #1 GlobalDonation (COMPLETED) — donation source records; this build adds nullable FK `CrowdFundId` to `fund.GlobalDonations` so donations attribute to a crowdfund
- #10 OnlineDonationPage (COMPLETED) — canonical EXTERNAL_PAGE precedent for the *future* setup screen (when it gets built)

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **NEW entity** — `CrowdFund` (singular per existing PSS 2.0 convention: P2PCampaignPage, OnlineDonationPage, P2PFundraiser).

**Table**: `fund."CrowdFunds"` (NEW)

**Inheritance**: `Entity` (gets CompanyId / CreatedBy / CreatedDate / ModifiedBy / ModifiedDate / IsDeleted / IsActive).

### Core Fields

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CrowdFundId | int | — | PK | — | Identity column, primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (HttpContext) |
| CampaignName | string | 200 | YES | — | Human title (mockup "Build a School in Kenya") |
| Slug | string | 100 | YES | — | URL slug; lower-kebab; unique per tenant via filtered unique index `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted` |
| PageStatus | string | 20 | YES | — | "Draft" \| "Published" \| "Active" \| "GoalMet" \| "Closed" \| "Archived" |
| PublishedAt | DateTime? | — | NO | — | Set when admin invokes Publish lifecycle command |
| ClosedAt | DateTime? | — | NO | — | Set on Close |
| ArchivedAt | DateTime? | — | NO | — | Set on Archive |
| Currency | string | 3 | YES | — | ISO code (USD/EUR/GBP/INR) — for goal amount display |
| GoalAmount | decimal(18,2) | — | YES | — | Target |
| StartDate | DateTime | — | YES | — | When campaign begins accepting donations |
| EndDate | DateTime | — | YES | — | Soft deadline; goal-exceeded behavior controls what happens after |
| DonationPurposeId | int | — | YES | fund.DonationPurposes | Where collected donations are accounted |
| CampaignCategory | string | 30 | YES | — | String enum: "Education" \| "Healthcare" \| "Emergency" \| "Environment" \| "Community" \| "Other" |
| OrganizationalUnitId | int? | — | NO | corg.OrganizationalUnits | Optional sub-org scope |

### Content (mockup "Content" tab — stored on entity for future setup screen)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| Headline | string? | 200 | NO | Long subtitle ("Help Us Build a School for 500 Children…") |
| HeroImageUrl | string? | 500 | NO | Direct upload URL |
| HeroVideoUrl | string? | 500 | NO | YouTube/Vimeo paste |
| StoryRichText | string? | (text) | NO | Rich text HTML — campaign narrative; no MaxLen, postgres `text` column |
| ImpactBreakdownJson | string? | (jsonb) | NO | JSON array of `{amount: number, description: string}` — "Provides a desk and chair for one student" |
| FaqJson | string? | (jsonb) | NO | JSON array of `{question: string, answer: string}` |

### Donation Settings (mockup "Donation Settings" tab)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AmountChipsJson | string? | (jsonb) | NO | — | JSON array of decimals (max 6 chips) |
| AllowCustomAmount | bool | — | YES | — | Default true |
| MinimumDonationAmount | decimal(18,2) | — | YES | — | Default 5.00 |
| AllowRecurringDonations | bool | — | YES | — | Default true |
| AllowAnonymousDonations | bool | — | YES | — | Default true |
| AllowDonorCoverFees | bool | — | YES | — | "Offer Cover Processing Fees option" toggle |
| EnabledPaymentMethodsJson | string | (jsonb) | YES | — | JSON array of payment method keys; default `["stripe","paypal"]` |
| CompanyPaymentGatewayId | int? | — | NO | fund.CompanyPaymentGateways | Specific gateway override |
| ShowGoalThermometer | bool | — | YES | — | Display toggle, default true |
| ShowDonorCount | bool | — | YES | — | Display toggle, default true |
| ShowDonorWall | bool | — | YES | — | Display toggle, default true |
| GoalExceededBehavior | string | 20 | YES | — | "KeepAccepting" \| "AutoClose" \| "ShowStretchGoal"; default "KeepAccepting" |
| StretchGoalAmount | decimal(18,2)? | — | NO | — | Used only when GoalExceededBehavior='ShowStretchGoal' |

### Milestones & Updates (mockup "Milestones" + "Updates" tabs)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| MilestonesJson | string? | (jsonb) | NO | JSON array of `{name: string, percentage: number, amount: number, status: "Reached"\|"InProgress"\|"Upcoming"}` |
| UpdatesJson | string? | (jsonb) | NO | JSON array of `{updateDate: ISO date, title: string, content: string}` |

### Design (mockup "Design" tab)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| PrimaryColorHex | string | 7 | YES | Default `#0e7490` (teal) |
| AccentColorHex | string | 7 | YES | Default `#06b6d4` (cyan) |
| BackgroundColorHex | string | 7 | YES | Default `#ffffff` |
| LogoUrl | string? | 500 | NO | Organization logo override |
| FontFamily | string | 50 | YES | "System" \| "Georgia" \| "Poppins" \| "OpenSans"; default "System" |
| EnabledSectionsJson | string | (jsonb) | YES | JSON object `{impact: bool, milestones: bool, updates: bool, donorWall: bool, faq: bool, shareButtons: bool, countdown: bool}`; default all true except countdown |

### Communication (mockup not explicit but pattern from #170)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ConfirmationEmailTemplateId | int? | — | NO | corg.EmailTemplates | Donation thank-you email |
| GoalMilestoneEmailTemplateId | int? | — | NO | corg.EmailTemplates | "We hit 50%" alert |
| GoalReachedEmailTemplateId | int? | — | NO | corg.EmailTemplates | "Goal met" celebration |
| AdminNotificationEmailTemplateId | int? | — | NO | corg.EmailTemplates | Internal alert |
| WhatsAppDonationAlertEnabled | bool | — | YES | — | Default false |
| WhatsAppDonationAlertTemplateId | int? | — | NO | corg.WhatsAppTemplates | Required if WhatsAppDonationAlertEnabled=true (validate at Publish) |

### SEO / Sharing

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| OgImageUrl | string? | 500 | NO | Social-share image |
| OgTitle | string? | 100 | NO | Social-share title (defaults to CampaignName if NULL) |
| OgDescription | string? | 200 | NO | Social-share description (defaults to Headline if NULL) |
| DefaultShareMessage | string? | 500 | NO | Pre-filled share text |
| RobotsIndexable | bool | — | YES | Default true |

### Filtered Index + Status Index (mirror P2PCampaignPage)

```csharp
// IX_CrowdFunds_CompanyId_Slug_Active — filtered unique
.HasIndex(x => new { x.CompanyId, x.Slug })
.HasFilter("\"IsDeleted\" = false")
.IsUnique()
.HasDatabaseName("IX_CrowdFunds_CompanyId_Slug_Active");

// IX_CrowdFunds_CompanyId_PageStatus — selective filter
.HasIndex(x => new { x.CompanyId, x.PageStatus })
.HasDatabaseName("IX_CrowdFunds_CompanyId_PageStatus");
```

### Modification to GlobalDonation (for attribution)

Add nullable FK column on `fund.GlobalDonations`:

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| CrowdFundId | int? | NO | fund.CrowdFunds | Set when donor donates via the public crowdfund page; NULL for direct/other donations. Mirrors OnlineDonationPageId + P2PCampaignPageId + P2PFundraiserId precedent. |

Add `IX_GlobalDonations_CrowdFundId` non-unique index for the drawer's RecentDonors query.

### Aggregated/computed fields (NOT columns — produced by `GetAllCrowdFundList` handler)

- `TotalRaised` (decimal) — SUM(NetAmount) over `fund.GlobalDonations WHERE CrowdFundId=row.Id AND IsDeleted=false`
- `TotalDonors` (int) — DISTINCT ContactId
- `DonationCount` (int) — COUNT
- `LastDonationAt` (DateTime?) — MAX(DonationDate)
- `ProgressPercent` (decimal, FE-computed) — `TotalRaised / GoalAmount * 100`
- `DaysRemaining` (int, FE-computed) — `EndDate - NOW()` in calendar days (server can also project)
- `IsGoalMet` (bool, derived) — `TotalRaised >= GoalAmount`

### Child Entities — NONE introduced

All "children" in the mockup (Milestones, Updates, ImpactBreakdown, FAQ) are stored as **jsonb arrays on the entity itself**, not as separate child tables. This matches the OnlineDonationPage pattern where DonorFieldConfigJson is on the page row. Rationale: these arrays are page-local, ordering-sensitive, edited as a unit in the setup screen, and never queried independently. Storing as jsonb avoids 4 extra child tables + 4 extra CRUD handlers + 4 extra Mapster configs. If a future requirement needs per-milestone querying, the schema can be normalized later.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for projection Include() chain in ResponseDto) + Frontend Developer (for Quick-Create dialog ApiSelectV2 controls)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| DonationPurposeId | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` | `getAllDonationPurposeList` | PurposeName | DonationPurposeResponseDto |
| OrganizationalUnitId | OrganizationalUnit | `Base.Domain/Models/CompanyOrgModels/OrganizationalUnit.cs` | `getAllOrganizationalUnitList` | UnitName | OrganizationalUnitResponseDto |
| CompanyPaymentGatewayId | CompanyPaymentGateway | `Base.Domain/Models/DonationModels/CompanyPaymentGateway.cs` | (not exposed cross-tenant; setup-screen-only) | DisplayName | — |
| ConfirmationEmailTemplateId | EmailTemplate | `Base.Domain/Models/CommModels/EmailTemplate.cs` | `getAllEmailTemplateList` | TemplateName | EmailTemplateResponseDto |
| GoalMilestoneEmailTemplateId | EmailTemplate | (same) | (same) | (same) | (same) |
| GoalReachedEmailTemplateId | EmailTemplate | (same) | (same) | (same) | (same) |
| AdminNotificationEmailTemplateId | EmailTemplate | (same) | (same) | (same) | (same) |
| WhatsAppDonationAlertTemplateId | WhatsAppTemplate | `Base.Domain/Models/CommModels/WhatsAppTemplate.cs` | `getAllWhatsAppTemplateList` | TemplateName | WhatsAppTemplateResponseDto |

**Quick-Create dialog uses ONLY**:
- `getAllDonationPurposeList` → DonationPurpose ApiSelectV2
- `getAllOrganizationalUnitList` → OrganizationalUnit ApiSelectV2 (optional field; allow null)
- CampaignCategory → plain `<Select>` with hard-coded enum options (Education / Healthcare / Emergency / Environment / Community / Other)
- Currency → plain `<Select>` with USD / EUR / GBP / INR + the tenant's defaultCurrencyCode from `useCurrentCompany()`

**Email/WhatsApp template FKs**: NOT exposed in Quick-Create dialog or this screen's drawer Quick-Edit. They are managed in the future setup screen Tab Communication. Default to NULL.

**FE GQL nullable-array rule** (per user memory `feedback_fe_query_nullability_must_match_be.md`):
- BE param `string[]? statuses` maps to GraphQL `[String!]` (NOT `[String]`)
- FE must declare the variable as `[String!]` in `query GetAllCrowdFundList(..., $statuses: [String!])` or HotChocolate rejects with `Variable $statuses got invalid value`

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators + handler guards) → Frontend Developer (UI guards)

### Lifecycle State Machine

```
Draft  ──Publish──▶  Published  ──(auto on StartDate)──▶  Active  ──(auto on TotalRaised >= GoalAmount)──▶  GoalMet
                                                            │
                                                            ├──Close──▶  Closed
                                                            ├──Archive──▶  Archived
GoalMet  ──Close──▶  Closed                                 │
Closed   ──Archive──▶  Archived
Draft / Closed / Archived ──Duplicate──▶ new Draft
Draft ──Delete──▶  (soft-delete; only state where delete is allowed)
```

**Transition rules** (BE-enforced in lifecycle commands):

1. **PublishCrowdFund** — allowed FROM `Draft` ONLY:
   - Guard: CampaignName + Slug + GoalAmount > 0 + StartDate ≤ EndDate + DonationPurposeId resolves + ≥1 EnabledPaymentMethods + (AmountChipsJson ≥1 OR AllowCustomAmount=true)
   - Sets PageStatus="Published", PublishedAt=UtcNow
   - If StartDate ≤ UtcNow, AUTO-transition to "Active" in same command

2. **UnpublishCrowdFund** — allowed FROM `Published` ONLY (not Active — once donations flow, must Close instead):
   - Sets PageStatus="Draft", PublishedAt=NULL
   - Guard: COUNT donations with this CrowdFundId AND !IsDeleted = 0

3. **CloseCrowdFund** — allowed FROM `Active` OR `GoalMet`:
   - Sets PageStatus="Closed", ClosedAt=UtcNow
   - Optional reason note (free text) stored in audit log only

4. **ArchiveCrowdFund** — allowed FROM `Closed` OR `Draft` OR `GoalMet`:
   - Sets PageStatus="Archived", ArchivedAt=UtcNow

5. **DuplicateCrowdFund** — allowed FROM any non-deleted status:
   - Creates new row with PageStatus="Draft", PublishedAt=NULL, ClosedAt=NULL, ArchivedAt=NULL
   - Slug: `{originalSlug}-copy`, `{originalSlug}-copy-2`, ..., cap at 99 (BadRequestException at 100+)
   - CampaignName: `"[Copy of] {originalName}"`
   - StartDate/EndDate CLEARED to UtcNow + 7d / +37d defaults (admin must adjust)
   - All jsonb fields (ImpactBreakdownJson, FaqJson, MilestonesJson, UpdatesJson, AmountChipsJson, EnabledPaymentMethodsJson, EnabledSectionsJson) copied byte-for-byte
   - Aggregates NOT copied (clean Draft — no donations attribute to new row)

6. **DeleteCrowdFund** — allowed ONLY when PageStatus="Draft":
   - Guard 1: PageStatus must equal "Draft" (BadRequestException otherwise)
   - Guard 2: NO `fund.GlobalDonations` row with this CrowdFundId AND !IsDeleted exists (BadRequestException with count)
   - Soft-delete: IsDeleted=true; do NOT cascade to GlobalDonation rows (donations stay; FK column becomes orphan but historically valid per audit memory)

7. **Status auto-promotion** (handler-side, NOT a separate command):
   - When `GetAllCrowdFundList` projects rows, compute `IsGoalMet` from aggregated TotalRaised
   - If `PageStatus="Active" AND IsGoalMet=true AND GoalExceededBehavior="AutoClose"` → BG job (or on-demand when admin loads page) transitions to PageStatus="GoalMet"
   - V1: do NOT auto-mutate from the list query. Just *display* "Goal Met" badge when IsGoalMet=true regardless of stored PageStatus. The PageStatus only transitions to "GoalMet" when admin explicitly Closes or via a future scheduled job. Mockup card shows "Goal Met" badge for the Clean Water $25,000-of-$25,000 card — that card's stored PageStatus is irrelevant; the badge is computed.

### Slug Rules

- Auto-generate from CampaignName: lowercase, replace non-alphanum with `-`, trim leading/trailing `-`, collapse multiple `-` to one, max 100 chars
- User-editable in Quick-Create dialog (auto-fills on name blur but admin can override)
- Reserved list: `admin`, `api`, `crowdfund`, `crowdfunding`, `preview`, `login`, `auth`, `start`, `dashboard` — validator rejects these (BadRequestException)
- Format: `^[a-z0-9][a-z0-9-]*[a-z0-9]$` — must start and end with alphanum; hyphens allowed between
- Filtered unique per tenant (DB-enforced via partial index)
- IMMUTABLE once PageStatus transitions to "Active" or beyond (validator + handler guard): once a campaign goes live, the public URL is committed. Slug edit only allowed in Draft.

### Goal & Amount Rules

- GoalAmount > 0, ≤ 100,000,000 (sanity cap)
- StartDate ≤ EndDate (Publish-time validation)
- EndDate must be ≥ today + 1 day at Publish time
- MinimumDonationAmount ≥ 1.00 (typical) but allow ≥ 0.01 for tenant flexibility
- AmountChipsJson: max 6 entries, each > 0, sorted ascending FE-side
- StretchGoalAmount: if GoalExceededBehavior="ShowStretchGoal", required > GoalAmount
- Currency: must match tenant's allowed currency list (V1: accept any 3-char ISO; V2: validate against tenant config)

### Summary Aggregation Rule (GetCrowdFundSummary query)

Tenant-scoped. Returns a single `CrowdFundSummaryDto` with:

- `allCount`: COUNT(\*) WHERE CompanyId=current AND !IsDeleted
- `activeCount`: WHERE PageStatus IN ('Active', 'Published')
- `goalMetCount`: WHERE PageStatus='GoalMet' OR (PageStatus IN ('Active','Closed') AND TotalRaised ≥ GoalAmount) — uses subquery aggregate
- `draftCount`: WHERE PageStatus='Draft'
- `closedCount`: WHERE PageStatus='Closed'
- `archivedCount`: WHERE PageStatus='Archived'
- `totalCount`: alias for allCount (mockup KPI 1 subtitle "Total: 5")
- `totalRaised`: SUM over `fund.GlobalDonations.NetAmount` WHERE CrowdFundId IS NOT NULL AND CompanyId=current AND !IsDeleted — multi-currency mixing flagged as ISSUE-1 V2
- `totalDonors`: DISTINCT ContactId over same join (anonymous donors counted via DonorEmail when ContactId IS NULL)
- `completionRate`: `goalMetCount / NULLIF(allCount, 0) * 100` rounded to int
- All counts/sums in single round-trip (subqueries, no N+1)

### Authorization

- Queries (`GetAllCrowdFundList` / `GetCrowdFundSummary` / `GetCrowdFundById` / `GetCrowdFundStats`): `[CustomAuthorize(DecoratorDonationModules.CrowdFund, Permissions.Read)]`
- `CreateCrowdFund` (Quick-Create): `[CustomAuthorize(DecoratorDonationModules.CrowdFund, Permissions.Create)]`
- `UpdateCrowdFund` (Quick-Edit; full edit handled by future setup screen): `[CustomAuthorize(DecoratorDonationModules.CrowdFund, Permissions.Modify)]`
- `DuplicateCrowdFund`: `Permissions.Create` (creates new row)
- `DeleteCrowdFund`: `Permissions.Delete`
- `PublishCrowdFund` / `UnpublishCrowdFund` / `CloseCrowdFund` / `ArchiveCrowdFund`: `Permissions.Modify`

### Workflow

This screen drives **lifecycle transitions** (Publish / Unpublish / Close / Archive / Duplicate / Delete) via confirm modals. Detailed content edits are NOT in scope — they go to the future setup screen.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED decisions based on mockup + #15 precedent.

**Screen Type**: FLOW
**Variant**: drawer-only (NO view-page route — Quick-Create handled by dialog modal; full editor deferred to future setup screen)
**Reason**: Mirrors P2P Campaign #15 — CRM monitoring surface for an entity whose detailed editor lives at a separate `setting/publicpages/...` screen. Cards-grid layout (NOT table) — the only structural divergence from #15.

**Backend Patterns Required**:
- [x] Standard CRUD (entity + EF config + migration + Create/Update/Delete commands) — YES, this is a NEW entity
- [x] Tenant scoping (CompanyId from HttpContext) — standard pattern
- [ ] Nested child creation — NO (children are jsonb arrays on the entity)
- [x] Multi-FK validation — YES (DonationPurposeId, OrganizationalUnitId, 5× template FKs)
- [x] Unique validation — Slug filtered-unique per tenant
- [x] **NEW**: 4 lifecycle commands (Publish / Unpublish / Close / Archive)
- [x] **NEW**: Duplicate command (slug-counter + status reset)
- [x] **NEW**: Delete command (soft-delete with 2 guard rules)
- [x] **NEW**: Summary query (cross-campaign KPI rollup)
- [x] **NEW**: Stats query (per-campaign drawer projection — performance metrics + recent donors + parsed milestones/updates)
- [x] EF migration (new `fund.CrowdFunds` table + nullable `CrowdFundId` column on `fund.GlobalDonations` + 2 indexes)
- [x] Mapster mapping registration

**Frontend Patterns Required**:
- [x] FlowDataTable / DataTableContainer — used in Variant B header role ONLY; the actual data display is a plain JSX cards grid (mockup-specific) — Reconciliation #14 precedent for plain-JSX layout deviation
- [ ] view-page.tsx with 3 URL modes — NO (drawer-only + Quick-Create dialog)
- [x] React Hook Form — yes, for Quick-Create dialog (8 fields)
- [x] Zustand store (`crowdfund-store.ts`) — selected id, drawer open/close, modal state (Quick-Create, Publish-confirm, Close-confirm, Archive-confirm, Duplicate-confirm, Delete-confirm), filter chip, search term
- [x] Detail Sheet (Sheet from shadcn/ui) — 560px right-side, 6 sections
- [x] Confirm modals — 5 lifecycle confirms + Duplicate + Delete
- [x] Summary cards / 4 KPI widgets
- [x] 4 status filter chips
- [x] 3 NEW shared cell renderers: `crowdfund-status-badge` (4 visual variants) / `crowdfund-progress-bar` (re-usable progress bar with 3-tier color + complete variant) / `crowdfund-card` (the entire campaign card composition — not a cell renderer in the traditional sense but registered as a custom display block)
- [x] Quick-Create dialog (8 fields, RHF + Zod validation)
- [x] Quick-Edit dialog (same 8 fields, pre-filled — invoked from drawer Section 6)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/fundraising/crowdfunding-page.html`. The editor modal in the mockup (lines 581-1034) is OUT OF SCOPE — its UI belongs to a future `setting/publicpages/crowdfundingpage` screen.

### Layout Variant

**Grid Layout Variant**: `widgets-above-grid` (mockup shows 4 KPI cards ABOVE the cards-grid)
- FE Dev uses **Variant B**: `<ScreenHeader>` + 4 KPI widget components + `<DataTableContainer showHeader={false}>` wrapping a plain JSX cards-grid layout
- ScreenHeader renders title + subtitle + right-side `+ Create Campaign Page` button; DataTableContainer's internal header suppressed via `showHeader={false}`
- The actual content area is NOT a `<DataTable>` — it's a custom `<CrowdFundCardsGrid>` component that uses the BE list query but renders cards instead of rows
- **CRITICAL**: Failure to set `showHeader={false}` produces double-header bug (ContactType #19 precedent)

### Page Header (ScreenHeader)

- Title: "Crowdfunding Campaigns"
- Subtitle: "Create and manage public fundraising campaign pages"
- Right-side actions: `+ Create Campaign Page` button (teal/accent solid, plus icon) → opens Quick-Create dialog

### KPI Widgets (4 cards, equal width, horizontal grid)

| # | Widget Title | Value Source | Subtitle | Icon (Lucide) | Tint (SOLID per memory) |
|---|-------------|-------------|----------|---------------|--------------------------|
| 1 | Active Campaigns | `summary.activeCount` (int) | `Total: {summary.totalCount}` | `Megaphone` | bg-teal-600 text-white |
| 2 | Total Raised | `summary.totalRaised` (currency, tenant default — see ISSUE-1) | `Across all campaigns` | `HandCoins` | bg-green-600 text-white |
| 3 | Total Donors | `summary.totalDonors` (int with thousands sep) | `Unique supporters` | `Users` | bg-blue-600 text-white |
| 4 | Goals Met | `summary.goalMetCount` (int) | `{summary.completionRate}% completion rate` | `Trophy` | bg-purple-600 text-white |

**Per memory `feedback_widget_icon_badge_styling.md`**: KPI icon container uses SOLID `bg-X-600` + `text-white`. NEVER `bg-X-50/100` or `text-X-700/800`. Apply to ALL 4 widgets.

**Loading state per widget**: skeleton tile (matching widget dimensions, NO raw "Loading…" string).
**Error state per widget**: red `AlertCircle` icon + `—` + "Failed to load" muted caption.

### Filter Bar

**Row 1 — Search input** (left-aligned, max-width 320px):
- Placeholder: "Search campaigns by name, category..."
- Icon: `Search` (Lucide)
- Debounce: 300ms before triggering BE search
- Server-side: passes through to `searchTerm` arg of `GetAllCrowdFundList` (BE searches CampaignName + CampaignCategory + Slug)

**Row 2 — Filter chips** (left-aligned, horizontal flex with gap):
- 4 chips: `All ({allCount})` (default active) / `Active ({activeCount})` / `Goal Met ({goalMetCount})` / `Draft ({draftCount})`
- Counts from `summary` query — re-fetched every time summary refreshes
- Active chip: solid teal bg (`bg-teal-600 text-white`), inactive: white bg + slate border + slate text, hover teal border + teal text (per memory: SOLID bg, white text, no `bg-X-50`)
- Click → updates `statuses` filter in store → re-query cards-grid

### Cards Grid

**Layout**: `display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 20px; padding: 20px;` (Tailwind: `grid grid-cols-[repeat(auto-fill,minmax(320px,1fr))] gap-5 p-5` — note `[repeat(...)]` uses arbitrary CSS to avoid hard-coded px values in className; alternative: use a CSS module if Tailwind purge complains).

**Per card** (`<CrowdFundCard>` component):

```
┌─────────────────────────────────────┐
│ ░░░ HERO GRADIENT BLOCK (160px) ░░░ │ ← linear-gradient based on CampaignCategory
│                                      │
│        [category icon, 2.5rem]      │ ← Lucide icon mapped from category
│                          [BADGE] ─→ │ ← Status badge floats top-right
├─────────────────────────────────────┤
│ Campaign Name (clickable→drawer)    │ ← bold 16px, slate-900, hover accent
│ ████████████████░░░░░░░  76.8%      │ ← progress bar (height 8px)
│ $38,400         of $50,000 (76.8%)  │ ← raised (bold accent) / goal (muted)
│ 👥 345 donors    📅 Ends Jun 30     │ ← meta row
│                                      │
│ [Edit] [View Page] [Dashboard]      │ ← actions row (status-dependent)
└─────────────────────────────────────┘
```

**Hero gradient mapping** (`crowdfund-card.tsx` constants — data-driven hex exception per UI uniformity directive):

| Category | Gradient |
|----------|----------|
| Education | `linear-gradient(135deg, #0e7490, #06b6d4)` (teal/cyan) |
| Healthcare | `linear-gradient(135deg, #7c3aed, #a855f7)` (violet/purple) |
| Emergency | `linear-gradient(135deg, #dc2626, #f59e0b)` (red/amber) |
| Environment | `linear-gradient(135deg, #0284c7, #22c55e)` (sky/green) |
| Community | `linear-gradient(135deg, #ea580c, #f97316)` (orange) |
| Other | `linear-gradient(135deg, #64748b, #94a3b8)` (slate) |

**Category icon mapping** (Lucide):
- Education → `GraduationCap`
- Healthcare → `Stethoscope`
- Emergency → `LifeBuoy`
- Environment → `Leaf`
- Community → `Users`
- Other → `Globe`

**Status badge** (floats top-right of hero, `crowdfund-status-badge` renderer):

| PageStatus | Badge Label | Icon | Bg | Text |
|------------|-------------|------|-----|------|
| Active OR Published | "Active" | `Circle` (filled small dot) | `#f0fdf4` | `#16a34a` |
| GoalMet (or computed) | "Goal Met" | `CheckCircle2` | `#f0fdf4` | `#15803d` |
| Draft | "Draft" | `PenSquare` | `#fefce8` | `#a16207` |
| Closed | "Closed" | `Lock` | `#f1f5f9` | `#64748b` |
| Archived | "Archived" | `Archive` | `#f1f5f9` | `#64748b` |

**Note**: Status badge uses softer pill colors here (NOT solid 600) because mockup shows pastel pills on cards. This is an explicit deviation from the SOLID-bg memory for **per-card status badges only** — the rationale: SOLID 600 badges floating on a colored gradient hero would be visually overwhelming. Memory `feedback_widget_icon_badge_styling.md` allows mid-saturation for visualization elements (progress fills); we extend that to floating-on-hero badges. KPI tile icons + filter chips still use SOLID 600 per the memory.

**Progress bar** (`crowdfund-progress-bar` renderer; height 8px, slate-200 track, rounded-md):
- pct ≥ 100 → `bg-green-500` solid fill (complete variant) — and prepend 🔥 emoji + tint percentage text `text-green-700` font-bold
- 75 ≤ pct < 100 → `bg-green-500` fill
- 50 ≤ pct < 75 → `bg-amber-500` fill
- pct < 50 → `bg-red-500` fill
- Draft with TotalRaised=0 → render `—` em-dash placeholder (slate text) instead of bar

**Amounts row** (mockup-pixel-match):
- Left: `$38,400` raised — `font-bold text-lg text-accent` (teal-700)
- Right: `of $50,000 (76.8%)` — `text-sm text-muted-foreground`

**Meta row**:
- Donors: `<Users className="w-3.5 h-3.5" />` + `345 donors`
- Date label: `<Calendar className="w-3.5 h-3.5" />` + `Ends Jun 30` (Active) / `Ended Apr 30` (Closed/GoalMet with past EndDate) / `Starts Sep 1` (Draft with future StartDate)

**Actions row** (status-driven; `border-top` separator + `padding-top: 1rem`):

| PageStatus | Action Buttons (in order, left-to-right) |
|------------|------------------------------------------|
| Active OR Published | Edit (→ FUTURE setup, see §⑫) / View Page (public URL new tab) / Dashboard (V2 — placeholder toast) |
| GoalMet OR (Active+IsGoalMet) | View Page / Dashboard / Close (red-tint outline, opens Close confirm) |
| Draft | Edit (Quick-Edit dialog) / Preview (FUTURE — toast "Preview coming soon") / Publish (accent-tint outline, opens Publish confirm) |
| Closed | View Page / Duplicate / Archive (slate-tint outline, opens Archive confirm) |
| Archived | View Page / Duplicate |

**Action button style**: shadcn outline-button variant `xs` size, Lucide icons, 4px gap, hover accent border. Click stops propagation (so card body click → drawer doesn't fire).

### Card Click Behavior

- Click on Campaign Name OR hero block → opens 560px right-side detail Sheet for that row
- Click anywhere on Actions row → fires that specific action (stopPropagation)
- Card uses `cursor: pointer` only on the body region; hero is `cursor: pointer` too

### Detail Sheet (Drawer) — 560px right-side, 6 sections

**Component**: `crowdfund-detail-sheet.tsx` using shadcn `<Sheet side="right">` with class `w-[560px] sm:max-w-[560px]`.

**Header**: Campaign name (h2, slate-900) + status badge + close button. Below header: slug as muted text with copy button + Edit Full Setup button (deep-link to FUTURE) + View Page button (public URL new tab).

**Data sources**:
- `GetCrowdFundById(crowdFundId)` — full record projection
- `GetCrowdFundStats(crowdFundId)` — performance metrics + recent donors (top-5)
- Milestones / Updates from `MilestonesJson` / `UpdatesJson` on the byId record — parsed FE-side

**Section 1 — Campaign Summary card** (border, rounded, padding 16):
- Slug pill with copy button (clipboard icon, copies `{baseUrl}/crowdfund/{slug}`, toast on copy)
- Category chip (uses category color from the mapping above)
- Status badge (same renderer as card)
- Created (relative + absolute on hover)
- Published (only if PublishedAt NOT NULL)
- Closed (only if ClosedAt NOT NULL)
- Goal: `{currency} {goalAmount}` (formatted)
- Raised: `{currency} {totalRaised}` (bold)
- Full-width progress bar (same renderer; color-tier or complete)
- Days Remaining: e.g., "47 days remaining" if Active+future EndDate; "Ended 12 days ago" if past; "Closed on Apr 30" if Closed; "Archived"

**Section 2 — Performance Metrics — 4-tile grid card**:
- Total Donors (with avatar dots row of last 5 from recentDonors)
- Avg Donation (= TotalRaised / DonationCount, formatted; em-dash if 0 donations)
- Largest Donation (= MAX from BE projection)
- Donations This Week (last 7 days, with week-over-week % delta caption when prior week exists; e.g., "12 donations · +25% WoW")

All 4 tiles: SOLID icon container `bg-X-600 text-white` per memory.

**Section 3 — Milestones list card**:
- Iterate `MilestonesJson` (parsed array) — each row:
  - Marker icon: `CheckCircle2` (green) if status="Reached" / `Loader2` (blue, animate-spin) if "InProgress" / `Flag` (slate) if "Upcoming"
  - Name (font-medium)
  - "{percentage}% — {currency} {amount}"
  - Status pill (right-aligned): same color cue
- Empty state: "No milestones configured. Set milestones via the campaign editor →" + link to FUTURE setup Tab Milestones

**Section 4 — Recent Donors list card**:
- Top-5 from `stats.recentDonors`
- Each item: Avatar (initials gradient or `UserCircle` if anon) + Donor name (or "Anonymous") + Amount (right-aligned bold accent) + relative timestamp + 1-line message preview (muted, truncate)
- Empty state: "No donations yet"

**Section 5 — Latest Updates card**:
- Top-3 from parsed `UpdatesJson` (sorted by updateDate desc)
- Each: badge with date (accent-700) + title (font-medium) + first 100 chars of content (muted)
- Footer link: "View all {N} updates →" routes to FUTURE setup Tab Updates
- Empty state: "No updates posted yet"

**Section 6 — Quick Actions card** (4 vertical buttons stacked, full-width):
1. **Edit Full Setup** → FUTURE deep-link `/setting/publicpages/crowdfundingpage?id={id}` (shows "Full editor coming soon" toast if route 404s — graceful fallback)
2. **View Public Page** → `{baseUrl}/crowdfund/{slug}` in new tab (FUTURE public route — see §⑫)
3. **Copy Public URL** → clipboard with toast
4. **Quick Edit Basic** → opens Quick-Edit dialog (same 8 fields as Quick-Create, pre-filled with current values)

**Drawer empty state** (404 from GetCrowdFundById): "Campaign not found. It may have been deleted." + Close button.
**Drawer loading state**: 6 skeleton cards matching layout.

### Quick Create Dialog

**Component**: `crowdfund-quick-create-dialog.tsx` using shadcn `<Dialog>` (max-w-2xl). RHF + Zod schema.

**Fields** (matches mockup's Basic tab — 8 fields):

| Field | Component | Validation |
|-------|-----------|------------|
| Campaign Name | `<Input>` | required, max 200 |
| Slug | `<Input>` (auto-fills from name onBlur; admin can edit; show preview `/crowdfund/{slug}`) | required, regex `^[a-z0-9][a-z0-9-]*[a-z0-9]$`, max 100, reserved-list check |
| Goal Amount | `<Input type=number>` + Currency `<Select>` (USD/EUR/GBP/INR + tenant default) | required, > 0, ≤ 100M |
| Start Date | `<Input type=date>` | required, default today |
| End Date | `<Input type=date>` | required, ≥ today + 1 day |
| Donation Purpose | `<ApiSelectV2 query={getAllDonationPurposeList}>` | required |
| Campaign Category | `<Select>` with 6 enum options | required, default "Other" |
| Organizational Unit | `<ApiSelectV2 query={getAllOrganizationalUnitList}>` | optional |

**Footer**: `Cancel` (outline slate) + `Create Campaign` (solid teal — disabled until `formState.isValid` per memory `feedback_form_create_button_enablement.md`).

**Submit behavior**:
1. Validate locally; on Zod error → highlight fields, NOT a toast
2. Call `createCrowdFund` mutation with payload
3. BE returns `BaseApiResponse<int>` (new CrowdFundId)
4. Toast: "Campaign created as Draft"
5. Refresh list + summary
6. Close dialog + open drawer for the new id (so admin can review)

**Note**: This dialog creates ONLY 8 fields; entity has ~50 columns. Defaults applied BE-side for everything else: PageStatus="Draft", AllowCustomAmount=true, MinimumDonationAmount=5.00, AllowRecurringDonations=true, AllowAnonymousDonations=true, AllowDonorCoverFees=false, EnabledPaymentMethodsJson=`["stripe","paypal"]`, GoalExceededBehavior="KeepAccepting", ShowGoalThermometer=true, ShowDonorCount=true, ShowDonorWall=true, PrimaryColorHex="#0e7490", AccentColorHex="#06b6d4", BackgroundColorHex="#ffffff", FontFamily="System", EnabledSectionsJson=`{"impact":true,"milestones":true,"updates":true,"donorWall":true,"faq":true,"shareButtons":true,"countdown":false}`, RobotsIndexable=true. All other fields NULL.

### Quick Edit Dialog

Same component, label "Edit Campaign Basic", pre-filled with current values, calls `updateCrowdFund` instead.

**Important**: Slug field is DISABLED when PageStatus IN ('Active', 'Published', 'GoalMet', 'Closed', 'Archived') — show muted tooltip "Slug cannot be changed after the campaign goes live."

### Lifecycle Confirm Modals

5 modals — Publish / Unpublish / Close / Archive / Duplicate — all use the same `<LifecycleConfirmModal>` shell (or 5 dedicated tiny files) with status-specific copy:

| Modal | Title | Body (template) | Confirm button |
|-------|-------|-----------------|----------------|
| Publish | Publish Campaign? | "Publish **{name}**? This will make the campaign live at `{baseUrl}/crowdfund/{slug}` and start accepting donations." | Publish (solid teal) |
| Unpublish | Unpublish Campaign? | "Move **{name}** back to Draft? The public page will become unavailable." | Unpublish (solid amber) |
| Close | Close Campaign? | "Close **{name}**? Donations will no longer be accepted. You can re-publish later if needed." | Close Campaign (solid red) |
| Archive | Archive Campaign? | "Archive **{name}**? Archived campaigns are hidden from the active list but retained for reporting." | Archive (solid slate) |
| Duplicate | Duplicate Campaign? | "Create a draft copy of **{name}**? The new campaign will start in Draft status with a new slug like `'{slug}-copy'`. Donors and donations will NOT be copied." | Duplicate (solid teal) |

### Delete Confirm Modal (Draft only)

Title: "Delete Draft Campaign?"
Body: "Delete **{name}**? This Draft has no donations and cannot be recovered."
Buttons: Cancel / Delete (solid red `bg-red-600`)
On BE failure: red toast with reason (e.g., "Only Draft campaigns can be deleted; this campaign is Active" / "Cannot delete: campaign has 12 donations recorded")

### User Interaction Flow

1. Admin loads `/crm/p2pfundraising/crowdfunding` → sees ScreenHeader + 4 KPI widgets + 4 chips + cards-grid (paginated 12/24/48)
2. Admin types in search → 300ms debounce → cards filter via `searchTerm`
3. Admin clicks chip "Active" → cards filter via `statuses=['Active','Published']`; KPI counts DO NOT change (global)
4. Admin clicks card name or hero → 560px drawer slides in with 6 sections + 2 sub-queries (byId, stats)
5. From drawer Section 6 "Quick Edit Basic" → opens Quick-Edit dialog → admin edits → save → drawer + list refresh
6. From drawer Section 6 "Edit Full Setup" → routes to FUTURE setup screen (graceful 404 today)
7. From drawer Section 6 "Copy Public URL" → clipboard + toast
8. Admin clicks card Action "Publish" (Draft only) → Publish confirm → Confirm → BE → toast + refresh; drawer auto-updates badge to Active
9. Admin clicks card Action "Close" (Active/GoalMet only) → Close confirm → Confirm → BE → toast + refresh
10. Admin clicks card Action "Archive" (Closed/Draft/GoalMet) → Archive confirm → similar
11. Admin clicks card Action "Duplicate" (Closed/Archived) → Duplicate confirm → BE clones → toast + new Draft appears at top
12. Admin clicks card Action "Delete" (Draft only — visible from drawer Quick Actions OR via Quick Edit "more" menu) → Delete confirm → BE soft-deletes → toast + card disappears
13. Admin clicks header "+ Create Campaign Page" → Quick-Create dialog → fills 8 fields → Submit → toast + new Draft card appears + drawer auto-opens

### Page Widgets Already Stamped Above

**Grid Layout Variant**: `widgets-above-grid` → FE Dev uses **Variant B** (mandatory)

### Grid Aggregation Columns

All projected fields (`totalRaised`, `totalDonors`, `donationCount`, `lastDonationAt`) computed by BE `GetAllCrowdFundList` via 1 batched GROUP BY query over `fund.GlobalDonations` (no N+1). `progressPercent` and `daysRemaining` computed FE-side from `totalRaised / goalAmount` and `endDate - now()`.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Canonical reference for this sub-pattern: **P2PCampaign #15** (drawer-only FLOW CRM management surface).
> Canonical reference for entity structure: **P2PCampaignPage** (DonationModels group, fund schema, slug-based public page entity).

| Concept | This Screen Value | Canonical Reference (#15 P2PCampaign / P2PCampaignPage entity) |
|---------|-------------------|---------------------------------------------------------------|
| Entity name | `CrowdFund` (NEW) | `P2PCampaignPage` (exists) |
| Entity file path | `Base.Domain/Models/DonationModels/CrowdFund.cs` (NEW) | `Base.Domain/Models/DonationModels/P2PCampaignPage.cs` |
| EF Config file | `Base.Infrastructure/Data/Configurations/DonationConfigurations/CrowdFundConfiguration.cs` (NEW) | `P2PCampaignPageConfiguration.cs` |
| Entity lower-camel | `crowdFund` | `p2pCampaignPage` |
| Entity kebab | `crowd-fund` | `p2p-campaign-page` |
| Schema | `fund` | `fund` |
| Group / Decorator | `DecoratorDonationModules.CrowdFund` (NEW — add to DecoratorProperties.cs) | `DecoratorDonationModules.P2PCampaignPage` |
| BE module | `DonationModels` | `DonationModels` |
| BE business folder | `Base.Application/Business/DonationBusiness/CrowdFunds/` (NEW) | `Base.Application/Business/DonationBusiness/P2PCampaignPages/` |
| BE schemas file | `Base.Application/Schemas/DonationSchemas/CrowdFundSchemas.cs` (NEW) | `P2PCampaignPageSchemas.cs` |
| BE mappings | `DonationMappings.cs` (append CrowdFund block — mirror P2PCampaignPage block at lines 450-501) | same file |
| BE queries endpoint | `Base.API/EndPoints/Donation/Queries/CrowdFundQueries.cs` (NEW) | `P2PCampaignPageQueries.cs` |
| BE mutations endpoint | `Base.API/EndPoints/Donation/Mutations/CrowdFundMutations.cs` (NEW) | `P2PCampaignPageMutations.cs` |
| FE FOLDER | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/p2pfundraising/crowdfunding/` (NEW) | `.../crm/p2pfundraising/p2pcampaign/` |
| FE route | `crm/p2pfundraising/crowdfunding` | `crm/p2pfundraising/p2pcampaign` |
| FE entityCamel | `crowdFund` | `p2pCampaign` |
| FE DTO file | `src/domain/entities/donation-service/CrowdFundDto.ts` (NEW) | `P2PCampaignPageDto.ts` |
| FE GQL Q file | `src/infrastructure/gql-queries/donation-queries/CrowdFundQuery.ts` (NEW) | `P2PCampaignPageQuery.ts` |
| FE GQL M file | `src/infrastructure/gql-mutations/donation-mutations/CrowdFundMutation.ts` (NEW) | `P2PCampaignPageMutation.ts` |
| Menu code | `CROWDFUNDING` | `P2PCAMPAIGN` |
| Parent menu | `CRM_P2PFUNDRAISING` (MenuId=263) | `CRM_P2PFUNDRAISING` |
| Module code | `CRM` | `CRM` |
| OrderBy in parent | `3` | `1` |
| Page config | `src/presentation/pages/crm/p2pfundraising/crowdfunding.tsx` (NEW) | `.../p2pcampaign.tsx` |
| Entity-operations block | `CROWDFUNDING` block in `application/configs/data-table-configs/donation-service-entity-operations.ts` (NEW) | `P2PCAMPAIGN` block |
| GridType | `FLOW` | `FLOW` |
| GridFormSchema | `NULL` (no form-builder schema — Quick-Create uses RHF directly) | `NULL` |
| Sample data | 2 Draft campaigns ("Build a School in Kenya" + "Mobile Health Clinic") seeded for smoke-test | NONE — #170 already seeded |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer + DBA seed-author
> Exact paths — DO NOT guess.

### BACKEND — NEW FILES (10 + 1 migration)

| # | File Path | Purpose |
|---|-----------|---------|
| 1 | `Base.Domain/Models/DonationModels/CrowdFund.cs` | Entity definition (~50 properties + nav properties) |
| 2 | `Base.Infrastructure/Data/Configurations/DonationConfigurations/CrowdFundConfiguration.cs` | EF Fluent config — table name "CrowdFunds" in schema "fund", PK identity, filtered unique index on (CompanyId, LOWER(Slug)), status index, jsonb column registrations, all FK Restrict |
| 3 | `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetAllCrowdFundList.cs` | List query with batched GROUP BY for TotalRaised/TotalDonors/DonationCount/LastDonationAt aggregates; pagination + sort + statuses filter + searchTerm |
| 4 | `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundSummary.cs` | Cross-tenant KPI rollup (allCount/activeCount/goalMetCount/draftCount/totalRaised/totalDonors/completionRate) |
| 5 | `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundById.cs` | Full record projection for drawer + Quick-Edit pre-fill |
| 6 | `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundStats.cs` | Drawer stats — Avg/Largest/ThisWeek + top-5 RecentDonors projection |
| 7 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/CreateCrowdFund.cs` | Quick-Create (8 fields → Draft row with defaults for ~40 others); auto-generates Slug from CampaignName if not provided |
| 8 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/UpdateCrowdFund.cs` | Quick-Edit (8 fields); Slug guard (immutable post-Active); rest deferred to future setup screen |
| 9 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/DuplicateCrowdFund.cs` | Clone with slug-counter + Draft reset + cleared dates |
| 10 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/DeleteCrowdFund.cs` | Soft-delete with 2 guard rules (Draft-only + no donations) |
| 11 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/PublishCrowdFund.cs` | Lifecycle Draft→Published (with optional auto Active if StartDate ≤ now) + publish validation guard |
| 12 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/UnpublishCrowdFund.cs` | Lifecycle Published→Draft (only if zero donations) |
| 13 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/CloseCrowdFund.cs` | Lifecycle Active/GoalMet→Closed |
| 14 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/ArchiveCrowdFund.cs` | Lifecycle Closed/Draft/GoalMet→Archived |
| 15 | `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/CrowdFundEntityHelper.cs` | Slug generation helper (mirror P2PCampaignPageEntityHelper.cs) — slugify + uniqueness loop + reserved-list check |
| 16 | `Base.Application/Validations/CrowdFundSlugValidator.cs` | FluentValidation rule for Slug format + reserved list (mirror P2PCampaignPageSlugValidator.cs) |
| 17 | `Base.Application/Schemas/DonationSchemas/CrowdFundSchemas.cs` | RequestDto + ResponseDto + GridRowDto + SummaryDto + StatsDto + RecentDonorEntryDto + MilestoneEntryDto + UpdateEntryDto + ImpactEntryDto + FaqEntryDto |
| 18 | `Base.API/EndPoints/Donation/Queries/CrowdFundQueries.cs` | GraphQL endpoint — 4 query methods |
| 19 | `Base.API/EndPoints/Donation/Mutations/CrowdFundMutations.cs` | GraphQL endpoint — 8 mutation methods |
| 20 | `sql-scripts-dyanmic/Crowdfunding-sqlscripts.sql` | DB seed — menu + caps + grid + 2 sample Drafts (typo `dyanmic` preserved per #6 precedent) |
| 21 | `Base.Infrastructure/Data/Migrations/{timestamp}_AddCrowdFundTable.cs` | EF migration — creates `fund.CrowdFunds` + 2 indexes + adds `CrowdFundId` nullable FK + index on `fund.GlobalDonations` |

### BACKEND — MODIFIED FILES (7)

| # | File Path | Change |
|---|-----------|--------|
| 1 | `Base.Application/Data/Persistence/IDonationDbContext.cs` | Append `DbSet<CrowdFund> CrowdFunds { get; set; }` |
| 2 | `Base.Infrastructure/Data/Persistence/DonationDbContext.cs` | Same DbSet append + apply CrowdFundConfiguration |
| 3 | `Base.Application/Mappings/DonationMappings.cs` | Append CrowdFund Mapster block — Request/Response DTO mappings, ignore typed List/Dict (Milestones/Updates/Impacts/Faq/AmountChips/EnabledPaymentMethods/EnabledSections) and nav properties on Request, ignore Campaign/templates on Response except projected fields |
| 4 | `Base.Application/DecoratorProperties.cs` | Append `DecoratorDonationModules.CrowdFund = "CrowdFund"` |
| 5 | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | Append nullable `int? CrowdFundId { get; set; }` + nav `CrowdFund? CrowdFund { get; set; }` |
| 6 | `Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalDonationConfiguration.cs` | Append HasOne(CrowdFund).WithMany().HasForeignKey(CrowdFundId).OnDelete(Restrict) + non-unique index on CrowdFundId |
| 7 | `Base.API/Modules/DonationModule.cs` (or wherever DonationBusiness handlers are registered) | If the codebase uses explicit handler registration, register the 8 new CrowdFunds command handlers + 4 query handlers. If reflection-based, NO modification needed — confirm during build. |

### FRONTEND — NEW FILES (~22)

| # | File Path | Purpose |
|---|-----------|---------|
| 1 | `src/domain/entities/donation-service/CrowdFundDto.ts` | TS mirror — CrowdFundResponseDto / GridRow / Summary / Stats / Milestone / Update / Impact / Faq / RecentDonor + QuickCreateRequest / QuickEditRequest |
| 2 | `src/infrastructure/gql-queries/donation-queries/CrowdFundQuery.ts` | 4 GQL queries — GET_ALL_CROWDFUND_LIST / GET_CROWDFUND_SUMMARY / GET_CROWDFUND_BY_ID / GET_CROWDFUND_STATS |
| 3 | `src/infrastructure/gql-mutations/donation-mutations/CrowdFundMutation.ts` | 8 GQL mutations — CREATE / UPDATE / DUPLICATE / DELETE / PUBLISH / UNPUBLISH / CLOSE / ARCHIVE |
| 4 | `src/presentation/pages/crm/p2pfundraising/crowdfunding.tsx` | Page config (ScreenHeader title/icon/breadcrumb + render index-page) |
| 5 | `src/presentation/components/page-components/crm/p2pfundraising/crowdfunding/index-page.tsx` | Variant B index-page (ScreenHeader + KPI widgets + chips + cards-grid + DataTableContainer showHeader=false wrapping the cards-grid) |
| 6 | `.../crm/p2pfundraising/crowdfunding/index.tsx` | URL router (drawer open via `?id=` param) + barrel export from this folder |
| 7 | `.../crm/p2pfundraising/crowdfunding/crowdfund-widgets.tsx` | 4 KPI widget cards (SOLID bg-X-600 + text-white) |
| 8 | `.../crm/p2pfundraising/crowdfunding/crowdfund-filter-bar.tsx` | Search input + 4 chips |
| 9 | `.../crm/p2pfundraising/crowdfunding/crowdfund-cards-grid.tsx` | Plain JSX cards-grid layout (auto-fill minmax 320px) |
| 10 | `.../crm/p2pfundraising/crowdfunding/crowdfund-card.tsx` | Single card composition (hero gradient + status badge + body + actions row) |
| 11 | `.../crm/p2pfundraising/crowdfunding/crowdfund-detail-sheet.tsx` | 560px right-side drawer (6 sections) |
| 12 | `.../crm/p2pfundraising/crowdfunding/crowdfund-quick-create-dialog.tsx` | 8-field RHF dialog |
| 13 | `.../crm/p2pfundraising/crowdfunding/crowdfund-quick-edit-dialog.tsx` | Same shell as quick-create, pre-fill + slug-immutable check |
| 14 | `.../crm/p2pfundraising/crowdfunding/lifecycle-confirm-modal.tsx` | Single shell driving Publish/Unpublish/Close/Archive/Duplicate via type discriminator |
| 15 | `.../crm/p2pfundraising/crowdfunding/delete-crowdfund-modal.tsx` | Delete confirm (Draft only) |
| 16 | `.../crm/p2pfundraising/crowdfunding/crowdfund-store.ts` | Zustand store (selected id, drawer open, modal type+open, search, chip) |
| 17 | `.../crm/p2pfundraising/crowdfunding/crowdfund-zod-schema.ts` | Zod schema for Quick-Create / Quick-Edit (8 fields + reserved-slug check) |
| 18 | `.../crm/p2pfundraising/crowdfunding/index.ts` | Barrel export |
| 19 | `src/presentation/components/custom-components/data-tables/shared-cell-renderers/crowdfund-status-badge.tsx` | Status badge renderer (5 variants) — usable later by DB-seeded grids |
| 20 | `.../shared-cell-renderers/crowdfund-progress-bar.tsx` | Progress bar renderer with 3-tier color + complete variant |
| 21 | `.../shared-cell-renderers/crowdfund-category-chip.tsx` | Category chip renderer (used in drawer Section 1) |
| 22 | `src/presentation/components/skeletons/crowdfund-card-skeleton.tsx` | Loading-state skeleton matching card dimensions |

### FRONTEND — MODIFIED FILES (~8)

| # | File Path | Change |
|---|-----------|--------|
| 1 | `src/app/[lang]/crm/p2pfundraising/crowdfunding/page.tsx` | OVERWRITE 5-line UnderConstruction stub → import + render page config |
| 2 | `src/presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` | Export 3 new renderers |
| 3 | `.../data-tables/advanced/data-table-column-types/component-column.tsx` | Register 3 new column type cases |
| 4 | `.../data-tables/basic/data-table-column-types/component-column.tsx` | Register 3 new column type cases |
| 5 | `.../data-tables/flow/data-table-column-types/component-column.tsx` | Register 3 new column type cases |
| 6 | `src/application/configs/data-table-configs/donation-service-entity-operations.ts` | Append `CROWDFUNDING` block (read+create+update+duplicate+delete+publish+unpublish+close+archive operations) |
| 7 | `src/presentation/pages/crm/p2pfundraising/index.ts` | Append `CrowdFundingPageConfig` export |
| 8 | `src/presentation/components/page-components/crm/p2pfundraising/index.ts` | Append `crowdfunding` barrel re-export |

### FRONTEND — WIRING NOT NEEDED

- Sidebar: DB-driven (CROWDFUNDING seeded by this screen's SQL; MenuId=263 parent already exists)
- Routes: `crm/p2pfundraising/crowdfunding/page.tsx` already exists as stub — overwrite

---

## ⑨ Approval Config (DB Seed)

> **Consumer**: DBA / Seed-author + Project Manager (final review)
> Values pre-filled from MODULE_MENU_REFERENCE.md.

```yaml
MenuCode: CROWDFUNDING
MenuName: Crowdfunding
MenuUrl: crm/p2pfundraising/crowdfunding
ParentMenuCode: CRM_P2PFUNDRAISING  # MenuId=263 — already exists
ModuleCode: CRM
OrderBy: 3                          # P2PCAMPAIGN=1, P2PFUNDRAISER=2, this=3, MATCHINGGIFT=4
IsLeastMenu: true
GridType: FLOW
GridFormSchema: NULL                 # No form-builder schema — Quick-Create uses RHF
Capabilities:
  - READ                             # View list, widgets, drawer
  - WRITE                            # Quick-Create + Quick-Edit
  - DELETE                           # Delete Draft only
  - DUPLICATE                        # Clone-to-Draft
  - PUBLISH                          # Draft → Published lifecycle
  - UNPUBLISH                        # Published → Draft (only if zero donations)
  - CLOSE                            # Active/GoalMet → Closed
  - ARCHIVE                          # Closed/Draft/GoalMet → Archived
Roles:
  BUSINESSADMIN: [READ, WRITE, DELETE, DUPLICATE, PUBLISH, UNPUBLISH, CLOSE, ARCHIVE]
# Other roles: PROGRAMOFFICER / FINANCEOFFICER / CRMOFFICER / VOLUNTEER / FIELDOFFICER / DONOR
# left ungranted by default per /plan-screens Token Optimization Directive — admin
# adds via Role Capability Setup if needed.
SampleData: 2 Draft campaigns inserted for smoke-test:
  - "Build a School in Kenya" / slug "build-a-school-kenya" / Goal $50,000 / Education / no donations
  - "Mobile Health Clinic" / slug "mobile-health-clinic" / Goal $75,000 / Healthcare / no donations
MasterData: NONE — CrowdFundStatus is a string enum on entity (Draft/Published/Active/GoalMet/Closed/Archived); CampaignCategory is also a string enum (6 values).
GridFields: NONE (cards-grid layout — not a column-bound DataTable; the FE renders cards directly from the typed list response). Set `GridFields` table rows to ZERO for CROWDFUNDING. Compare with P2PCAMPAIGN which seeds 10 GridFields because it uses a column grid.

DefensiveCapsInsert:                  # Same pattern as P2PCampaign #15 ISSUE-DUPLICATE-CAPS
  - DUPLICATE                         # Insert into auth.Capabilities IF NOT EXISTS
  - PUBLISH
  - UNPUBLISH
  - CLOSE
  - ARCHIVE
```

**No GridFields seed** — cards-grid is not column-bound. The mockup is a pixel-perfect custom layout, not configurable per column.

---

## ⑩ BE→FE Contract

> **Consumer**: Frontend Developer (GQL queries/mutations + TS types) + Backend Developer (handler return types)

### NEW GraphQL Fields

| GQL Field Name | BE Handler | Args | Returns |
|----------------|------------|------|---------|
| `getAllCrowdFundList` | GetAllCrowdFundListHandler | (gridFeatureRequest, statuses: [String!]) | PaginatedApiResponse<CrowdFundGridRowDto[]> |
| `getCrowdFundSummary` | GetCrowdFundSummaryHandler | (none — tenant from HttpContext) | BaseApiResponse<CrowdFundSummaryDto> |
| `getCrowdFundById` | GetCrowdFundByIdHandler | (crowdFundId: Int!) | BaseApiResponse<CrowdFundResponseDto> |
| `getCrowdFundStats` | GetCrowdFundStatsHandler | (crowdFundId: Int!) | BaseApiResponse<CrowdFundStatsDto> |
| `createCrowdFund` | CreateCrowdFundHandler | (input: CrowdFundQuickCreateRequest!) | BaseApiResponse<Int> (new id) |
| `updateCrowdFund` | UpdateCrowdFundHandler | (input: CrowdFundQuickEditRequest!) | BaseApiResponse<Boolean> |
| `duplicateCrowdFund` | DuplicateCrowdFundHandler | (crowdFundId: Int!) | BaseApiResponse<Int> (new id) |
| `deleteCrowdFund` | DeleteCrowdFundHandler | (crowdFundId: Int!) | BaseApiResponse<Boolean> |
| `publishCrowdFund` | PublishCrowdFundHandler | (crowdFundId: Int!) | BaseApiResponse<Boolean> |
| `unpublishCrowdFund` | UnpublishCrowdFundHandler | (crowdFundId: Int!) | BaseApiResponse<Boolean> |
| `closeCrowdFund` | CloseCrowdFundHandler | (crowdFundId: Int!) | BaseApiResponse<Boolean> |
| `archiveCrowdFund` | ArchiveCrowdFundHandler | (crowdFundId: Int!) | BaseApiResponse<Boolean> |

### NEW DTOs (in `CrowdFundSchemas.cs`)

```csharp
// QUICK CREATE — 8 fields
public class CrowdFundQuickCreateRequest
{
    public string CampaignName { get; set; } = string.Empty;
    public string? Slug { get; set; }                          // optional — auto-gen if null
    public string Currency { get; set; } = "USD";
    public decimal GoalAmount { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public int DonationPurposeId { get; set; }
    public string CampaignCategory { get; set; } = "Other";
    public int? OrganizationalUnitId { get; set; }
}

// QUICK EDIT — same 8 fields + Id (slug guarded for non-Draft)
public class CrowdFundQuickEditRequest : CrowdFundQuickCreateRequest
{
    public int CrowdFundId { get; set; }
}

// SUMMARY — 10 fields
public class CrowdFundSummaryDto
{
    public int AllCount { get; set; }
    public int ActiveCount { get; set; }
    public int GoalMetCount { get; set; }
    public int DraftCount { get; set; }
    public int ClosedCount { get; set; }
    public int ArchivedCount { get; set; }
    public int TotalCount { get; set; }      // alias allCount
    public decimal TotalRaised { get; set; }
    public int TotalDonors { get; set; }
    public int CompletionRate { get; set; }  // 0-100 int %
}

// GRID ROW — projection used by list query
public class CrowdFundGridRowDto
{
    public int CrowdFundId { get; set; }
    public string CampaignName { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public string PageStatus { get; set; } = string.Empty;
    public string CampaignCategory { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
    public decimal GoalAmount { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public DateTime? PublishedAt { get; set; }
    public DateTime? ClosedAt { get; set; }
    public DateTime? ArchivedAt { get; set; }
    // Aggregates
    public decimal TotalRaised { get; set; }
    public int TotalDonors { get; set; }
    public int DonationCount { get; set; }
    public DateTime? LastDonationAt { get; set; }
    public bool IsGoalMet { get; set; }      // computed: TotalRaised >= GoalAmount
}

// STATS — drawer projection (separate query so drawer doesn't pay grid cost)
public class CrowdFundStatsDto
{
    public decimal TotalRaised { get; set; }
    public int TotalDonors { get; set; }
    public int DonationCount { get; set; }
    public decimal AvgDonation { get; set; }
    public decimal LargestDonation { get; set; }
    public int DonationsThisWeek { get; set; }
    public int DonationsPriorWeek { get; set; }   // for WoW % calc FE-side
    public List<RecentDonorEntryDto> RecentDonors { get; set; } = new();
}

public class RecentDonorEntryDto
{
    public int? ContactId { get; set; }
    public string DonorName { get; set; } = string.Empty;
    public bool IsAnonymous { get; set; }
    public decimal NetAmount { get; set; }
    public DateTime CreatedDate { get; set; }
    public string? Message { get; set; }          // from GlobalDonation.Note
}

// FULL RESPONSE — drawer + Quick-Edit
public class CrowdFundResponseDto : CrowdFundQuickCreateRequest
{
    public int CrowdFundId { get; set; }
    public string PageStatus { get; set; } = string.Empty;
    public DateTime? PublishedAt { get; set; }
    public DateTime? ClosedAt { get; set; }
    public DateTime? ArchivedAt { get; set; }
    // Content + Settings + Design + Comm — full schema (parsed from jsonb FE-side)
    public string? Headline { get; set; }
    public string? HeroImageUrl { get; set; }
    public string? HeroVideoUrl { get; set; }
    public string? StoryRichText { get; set; }
    public string? ImpactBreakdownJson { get; set; }
    public string? FaqJson { get; set; }
    public string? AmountChipsJson { get; set; }
    public bool AllowCustomAmount { get; set; }
    public decimal MinimumDonationAmount { get; set; }
    public bool AllowRecurringDonations { get; set; }
    public bool AllowAnonymousDonations { get; set; }
    public bool AllowDonorCoverFees { get; set; }
    public string EnabledPaymentMethodsJson { get; set; } = string.Empty;
    public int? CompanyPaymentGatewayId { get; set; }
    public bool ShowGoalThermometer { get; set; }
    public bool ShowDonorCount { get; set; }
    public bool ShowDonorWall { get; set; }
    public string GoalExceededBehavior { get; set; } = string.Empty;
    public decimal? StretchGoalAmount { get; set; }
    public string? MilestonesJson { get; set; }
    public string? UpdatesJson { get; set; }
    public string PrimaryColorHex { get; set; } = string.Empty;
    public string AccentColorHex { get; set; } = string.Empty;
    public string BackgroundColorHex { get; set; } = string.Empty;
    public string? LogoUrl { get; set; }
    public string FontFamily { get; set; } = string.Empty;
    public string EnabledSectionsJson { get; set; } = string.Empty;
    public int? ConfirmationEmailTemplateId { get; set; }
    public int? GoalMilestoneEmailTemplateId { get; set; }
    public int? GoalReachedEmailTemplateId { get; set; }
    public int? AdminNotificationEmailTemplateId { get; set; }
    public bool WhatsAppDonationAlertEnabled { get; set; }
    public int? WhatsAppDonationAlertTemplateId { get; set; }
    public string? OgImageUrl { get; set; }
    public string? OgTitle { get; set; }
    public string? OgDescription { get; set; }
    public string? DefaultShareMessage { get; set; }
    public bool RobotsIndexable { get; set; }
}
```

### TS DTO Mirror (`src/domain/entities/donation-service/CrowdFundDto.ts`)

```typescript
export type CrowdFundStatus = 'Draft' | 'Published' | 'Active' | 'GoalMet' | 'Closed' | 'Archived';
export type CrowdFundCategory = 'Education' | 'Healthcare' | 'Emergency' | 'Environment' | 'Community' | 'Other';
export type GoalExceededBehavior = 'KeepAccepting' | 'AutoClose' | 'ShowStretchGoal';

export interface CrowdFundQuickCreateRequest {
  campaignName: string;
  slug?: string;
  currency: string;
  goalAmount: number;
  startDate: string; // ISO
  endDate: string;
  donationPurposeId: number;
  campaignCategory: CrowdFundCategory;
  organizationalUnitId?: number | null;
}

export interface CrowdFundQuickEditRequest extends CrowdFundQuickCreateRequest {
  crowdFundId: number;
}

export interface CrowdFundSummaryDto {
  allCount: number;
  activeCount: number;
  goalMetCount: number;
  draftCount: number;
  closedCount: number;
  archivedCount: number;
  totalCount: number;
  totalRaised: number;
  totalDonors: number;
  completionRate: number;
}

export interface CrowdFundGridRowDto {
  crowdFundId: number;
  campaignName: string;
  slug: string;
  pageStatus: CrowdFundStatus;
  campaignCategory: CrowdFundCategory;
  currency: string;
  goalAmount: number;
  startDate: string;
  endDate: string;
  publishedAt: string | null;
  closedAt: string | null;
  archivedAt: string | null;
  totalRaised: number;
  totalDonors: number;
  donationCount: number;
  lastDonationAt: string | null;
  isGoalMet: boolean;
}

export interface RecentDonorEntryDto {
  contactId: number | null;
  donorName: string;
  isAnonymous: boolean;
  netAmount: number;
  createdDate: string;
  message: string | null;
}

export interface CrowdFundStatsDto {
  totalRaised: number;
  totalDonors: number;
  donationCount: number;
  avgDonation: number;
  largestDonation: number;
  donationsThisWeek: number;
  donationsPriorWeek: number;
  recentDonors: RecentDonorEntryDto[];
}

export interface CrowdFundMilestoneEntry {
  name: string;
  percentage: number;
  amount: number;
  status: 'Reached' | 'InProgress' | 'Upcoming';
}

export interface CrowdFundUpdateEntry {
  updateDate: string;
  title: string;
  content: string;
}
```

### Important: GraphQL Nullable-Array Rule

Per user memory `feedback_fe_query_nullability_must_match_be.md`:
- BE `string[]? statuses` → GraphQL nullable input `[String!]` (NOT `[String]`)
- FE query variable MUST be declared `$statuses: [String!]` — if FE declares `[String]`, HotChocolate rejects at runtime
- Apply to `getAllCrowdFundList`

---

## ⑪ Acceptance Criteria

> **Consumer**: Testing Agent (validation) + User (final QA)

### Backend
- [ ] `CrowdFund` entity compiles (~50 properties); EF config registers table `fund."CrowdFunds"` with filtered unique index, status index, jsonb columns
- [ ] Migration adds `fund.CrowdFunds` table + `CrowdFundId` FK on `fund.GlobalDonations` + 2 indexes; applies cleanly to a fresh DB
- [ ] `CreateCrowdFund` defaults the ~40 non-Quick-Create fields correctly; auto-generates Slug when input.Slug is null
- [ ] `UpdateCrowdFund` rejects Slug changes when PageStatus IN ('Active','Published','GoalMet','Closed','Archived') with BadRequestException
- [ ] `DuplicateCrowdFund` slug-counter loop caps at 99 with BadRequestException; clones all jsonb fields byte-for-byte; resets dates + status
- [ ] `DeleteCrowdFund` rejects non-Draft with BadRequestException + clear message
- [ ] `DeleteCrowdFund` rejects when GlobalDonations exist (count > 0) with BadRequestException + clear count message
- [ ] `PublishCrowdFund` validates required fields + ≥1 payment method + (≥1 amount chip OR AllowCustomAmount=true) — BadRequestException with field-level reason
- [ ] `PublishCrowdFund` auto-advances PageStatus to 'Active' in same command if StartDate ≤ UtcNow
- [ ] `UnpublishCrowdFund` rejects when donations exist (any non-deleted)
- [ ] `CloseCrowdFund` allowed from Active OR GoalMet only
- [ ] `ArchiveCrowdFund` allowed from Closed OR Draft OR GoalMet
- [ ] `GetAllCrowdFundList` projects aggregates via batched GROUP BY (no N+1; single round-trip + 1 aggregate query)
- [ ] `GetCrowdFundSummary` returns all 10 fields, tenant-scoped, no N+1
- [ ] `GetCrowdFundStats` returns Avg/Largest/ThisWeek/PriorWeek + top-5 RecentDonors
- [ ] All handlers authorized via `[CustomAuthorize(DecoratorDonationModules.CrowdFund, ...)]` with correct Permission
- [ ] `dotnet build` succeeds with 0 errors in CrowdFunds folder

### Frontend
- [ ] Page loads at `/{lang}/crm/p2pfundraising/crowdfunding`
- [ ] Variant B layout — NO double-header (post-build grep: `<DataTableContainer.*showHeader={false}`)
- [ ] 4 KPI widgets show correct counts from `getCrowdFundSummary`; SOLID `bg-X-600 text-white` per memory
- [ ] 4 chips show counts; clicking each filters cards via `statuses` arg; chip styling SOLID per memory
- [ ] Search input debounces 300ms and triggers BE refetch
- [ ] Cards-grid renders responsive (auto-fill, minmax 320px) with category-based gradient hero + Lucide category icon
- [ ] Status badge floats top-right of hero with correct variant per pageStatus AND IsGoalMet (badge shows "Goal Met" when isGoalMet=true regardless of pageStatus until admin closes)
- [ ] Progress bar shows 3-tier color OR complete-green when 100% with 🔥 prepend
- [ ] Per-card action set varies correctly per status (Active / GoalMet / Draft / Closed / Archived)
- [ ] Card click (name OR hero) opens 560px drawer
- [ ] Drawer renders 6 sections with correct data from `getCrowdFundById` + `getCrowdFundStats`
- [ ] Drawer Milestones section parses `MilestonesJson` and renders 3 status variants
- [ ] Drawer Recent Donors section renders top-5 (anonymous shown as "Anonymous")
- [ ] Drawer Latest Updates section parses `UpdatesJson` and renders top-3
- [ ] Drawer "Edit Full Setup" routes to `/setting/publicpages/crowdfundingpage?id={id}` (graceful — 404 today is acceptable; flag for SCREEN-FOLLOW-UP)
- [ ] Drawer "View Public Page" opens `/crowdfund/{slug}` in NEW TAB (404 today is acceptable per SERVICE_PLACEHOLDER)
- [ ] Drawer "Copy Public URL" copies to clipboard + toast
- [ ] Drawer "Quick Edit Basic" opens Quick-Edit dialog pre-filled
- [ ] Quick-Create dialog: 8 fields with Zod validation; submit creates Draft; refreshes list+summary; opens drawer for new id
- [ ] Quick-Edit dialog: Slug field disabled for non-Draft with tooltip
- [ ] Quick-Create/Edit Create button gated by `formState.isValid` per memory `feedback_form_create_button_enablement.md`
- [ ] All 5 lifecycle confirms (Publish/Unpublish/Close/Archive/Duplicate) invoke correct mutation + refresh
- [ ] Delete confirm guards on BE error (non-Draft / has donations) — error toast shows BE message
- [ ] Pagination 12/24/48; default 12
- [ ] Empty state (zero campaigns) shows Create Campaign Page CTA
- [ ] Filtered empty state shows Clear Filters button
- [ ] Loading state shows card skeletons + KPI skeletons (NO raw "Loading..." string)
- [ ] Error state shows red banner + retry button

### UI Uniformity (post-build grep checks — all 0 matches expected)
- [ ] 0 inline hex in `style={{...}}` under `page-components/crm/p2pfundraising/crowdfunding/` outside `crowdfund-card.tsx` (CATEGORY_GRADIENTS constant allowed — data-driven exception) and `crowdfund-status-badge.tsx` (STATUS_COLORS constant allowed)
- [ ] 0 inline px in `style={{...}}` — use Tailwind utilities; one exception: cards-grid `grid-template-columns` if Tailwind arbitrary `[repeat(...)]` syntax doesn't purge correctly, falls back to inline style (document in build log)
- [ ] 0 raw `Loading...` strings (use shadcn Skeleton)
- [ ] 0 `fa-*` className refs (use Lucide / Phosphor icons)
- [ ] 0 inline-hex skeleton background

### DB Seed
- [ ] Menu visible at `CRM > P2P Fundraising > Crowdfunding` in sidebar (DB-driven)
- [ ] 8 capabilities (READ/WRITE/DELETE/DUPLICATE/PUBLISH/UNPUBLISH/CLOSE/ARCHIVE) granted to BUSINESSADMIN
- [ ] 2 sample Draft campaigns seeded; visible in admin grid on first load
- [ ] Defensive Capability inserts for DUPLICATE/PUBLISH/UNPUBLISH/CLOSE/ARCHIVE (idempotent) — addresses #15's ISSUE-DUPLICATE-CAPS precedent
- [ ] Seed SQL idempotent — re-run inserts ZERO rows on second execution (NOT EXISTS gates)

### Cross-Screen
- [ ] Drawer "Edit Full Setup" deep-link target route `/setting/publicpages/crowdfundingpage?id={id}` shows 404 OR a SCREEN-FOLLOW-UP placeholder card — NOT a hard crash
- [ ] "View Public Page" target `/crowdfund/{slug}` shows 404 OR a "Public page coming soon" placeholder — NOT a hard crash
- [ ] After Duplicate: new Draft card appears at top of cards-grid (sorted by CreatedDate DESC default)
- [ ] After Delete: card disappears from grid; chip counts update
- [ ] After Publish: badge transitions Draft → Active; "Publish" button hidden; "Close" + "Archive" buttons appear

---

## ⑫ Special Notes & Known Issues

> **Consumer**: PM (review) + Developers (heads-up)

### NEW Module Warning

- **NO new DbContext / module** — `fund` schema + `DonationModels` group + `DonationDbContext` + `DonationMappings.cs` + `DecoratorDonationModules` already exist (established by earlier waves). This build only **appends** to those.
- DOES add a new DbSet to existing `DonationDbContext` — verify migration produces the correct table name `"CrowdFunds"` in schema `"fund"` (case-sensitive in postgres).

### SCREEN-FOLLOW-UP (registry-tracked dependency)

This screen builds the entity + summary + Quick-Create + drawer. The **rich tabbed editor** (Basic / Content / Donation Settings / Milestones / Updates / Design — mockup lines 581-1034) is a **separate follow-up screen** that must be planned:

- **Suggested registry ID**: ~#171 (next available in #170-range, mirroring P2PCampaignPage #170 / OnlineDonationPage)
- **Suggested MenuCode**: `CROWDFUNDINGPAGE`
- **Suggested URL**: `setting/publicpages/crowdfundingpage`
- **Suggested ParentMenu**: `SET_PUBLICPAGES` (MenuId=369) — sibling of `ONLINEDONATIONPAGE` + `P2PCAMPAIGNPAGE`
- **Suggested screen_type**: `EXTERNAL_PAGE` / `CROWDFUND` sub-type
- **Scope**: 6-tab editor + public-route `/crowdfund/{slug}` page

Add this to the registry **after** /build-screen completes #16 — flag in completion report. Until then, deep-links from #16 drawer to `setting/publicpages/crowdfundingpage` will 404 (handled gracefully — see Acceptance Criteria).

### Pre-Build Issues to Flag

**ISSUE-1 — MED — Multi-currency in TotalRaised**
KPI "Total Raised" sums `fund.GlobalDonations.NetAmount` across all currencies without FX conversion. If tenant uses multi-currency, this number is mathematically incorrect. **Mitigation**: V1 caps at tenant default currency display (mockup uses $ implicitly); add disclaimer tooltip on KPI widget. **Fix path**: V2 add per-row ExchangeRate join → BaseAmount column sum, mirrors Donation Dashboard #124 pattern + P2PCampaign #15 ISSUE-1 precedent. Direct-pair FX per memory `feedback_fx_direct_pair.md` — no USD-pivot.

**ISSUE-2 — MED — Public crowdfund route does NOT exist yet**
Drawer "View Public Page" + per-card "View Page" actions open `{baseUrl}/crowdfund/{slug}` in a new tab. That route is **NOT built** by this prompt — it's part of the future setup screen's scope (or a separate public-page build). V1 behavior: opening the URL gets a 404 (Next.js default). **Mitigation**: optionally stub a public route at `(public)/crowdfund/[slug]/page.tsx` that shows a "Public page coming soon" placeholder card with an Org Logo and the campaign name — graceful fallback. Decision deferred to build session.

**ISSUE-3 — LOW — Slug counter cap at 99**
DuplicateCrowdFund uses incremental counter (`-copy`, `-copy-2`, ..., `-copy-99`). At 100+, BE throws BadRequestException. Reality: 100 copies of same campaign is implausible. P2PCampaign #15 ISSUE-3 precedent.

**ISSUE-4 — MED — IsGoalMet visual badge vs stored PageStatus divergence**
Mockup card 3 ("Clean Water for 10 Villages") shows status badge "Goal Met" with $25,000-of-$25,000. The stored PageStatus could legitimately be 'Active' (admin hasn't closed yet) — the badge is **computed** from `TotalRaised >= GoalAmount`. This means the "Goal Met" chip filter must include rows where `(PageStatus='GoalMet') OR (PageStatus IN ('Active','Closed') AND TotalRaised >= GoalAmount)`. Implement in `GetCrowdFundSummary.goalMetCount` and `GetAllCrowdFundList` statuses-filter logic. Document carefully in build log.

**ISSUE-5 — LOW — Days-Remaining computation locale**
Drawer Section 1 shows "Days Remaining" / "Ended N days ago". Use `date-fns differenceInCalendarDays` or native `Date.UTC()` calendar-day math. Same as P2PCampaign #15 ISSUE-5.

**ISSUE-6 — LOW — Mockup hero gradients are inline-style hex**
The CATEGORY_GRADIENTS map in `crowdfund-card.tsx` uses hex codes for hero `background: linear-gradient(...)`. Per memory `feedback_ui_uniformity.md`, inline hex is disallowed in `style={{...}}` except in designated renderers. Treat `crowdfund-card.tsx` and `crowdfund-status-badge.tsx` as designated renderers (data-driven exception, same as Reconciliation #14 BRAND_MAP and P2PCampaign #15 status-badge). Add post-build grep exception for these 2 files.

**ISSUE-7 — LOW — Mockup includes editor modal (lines 581-1034) — OUT OF SCOPE**
The 6-tab editor (Basic / Content / Donation Settings / Milestones / Updates / Design), the public preview view, and the device switcher are all visible in `crowdfunding-page.html` but are OUT OF SCOPE for this prompt. They belong to the SCREEN-FOLLOW-UP setup screen. Do NOT build them. Quick-Create + Quick-Edit cover the minimum-viable creation path.

**ISSUE-8 — LOW — DonationMappings.cs jsonb ignore-config**
8 jsonb properties on the entity (ImpactBreakdownJson, FaqJson, AmountChipsJson, EnabledPaymentMethodsJson, MilestonesJson, UpdatesJson, EnabledSectionsJson — and also LogoUrl-free since LogoUrl is plain string). Mapster Request DTO must declare these as `string` (NOT `List<>` or `Dict<>`) so Mapster writes the raw JSON string through unchanged. Same pattern as P2PCampaignPage block in DonationMappings.cs lines 450-501. Confirm during build.

**ISSUE-9 — LOW — Cards grid responsive breakpoint**
Mockup uses `grid-template-columns: repeat(auto-fill, minmax(320px, 1fr))`. Tailwind v3 arbitrary syntax: `grid-cols-[repeat(auto-fill,minmax(320px,1fr))]`. Verify purge doesn't strip; fallback to inline style with `gridTemplateColumns` (single inline-px exception documented in build log).

**ISSUE-10 — LOW — Dashboard action stub**
Per-card "Dashboard" action (for Active/Published/GoalMet cards) — no per-campaign dashboard exists yet. V1: clicking shows toast "Dashboard view coming soon" (SERVICE_PLACEHOLDER). V2: build a per-campaign analytics drawer or dedicated route. Same pattern as drawer Section 6 "View Public Page" graceful-degrade.

**ISSUE-11 — LOW — Currency formatting locale**
FE uses Intl.NumberFormat with tenant's default currency code from `useCurrentCompany()`. Mockup shows USD `$` prefix. If tenant default ≠ USD, displayed amounts will use that currency's symbol. Same as P2PCampaign #15 ISSUE-11.

**ISSUE-12 — LOW — Mapster ignore-config for Duplicate clone**
When `Adapt<CrowdFund>()` clones, Mapster may attempt to clone navigation properties (DonationPurpose, OrganizationalUnit, 5× EmailTemplate, WhatsAppTemplate, CompanyPaymentGateway). **Fix**: load entity via `.AsNoTracking()` without Includes + manual property copy (P2PCampaign #15 ISSUE-14 precedent — that path proved cleaner than Mapster ignore-config).

**ISSUE-13 — LOW — Seed folder `sql-scripts-dyanmic/` typo preservation**
Per ChequeDonation #6 + P2PCampaign #15 ISSUE-15 precedent. Preserve typo. New seed file path: `PSS_2.0_Backend/sql-scripts-dyanmic/Crowdfunding-sqlscripts.sql`.

**ISSUE-14 — LOW — DUPLICATE/PUBLISH/UNPUBLISH/CLOSE/ARCHIVE capability codes may not exist in auth.Capabilities**
P2PCampaign #15 hit this — the seed references `DUPLICATE`/`PUBLISH`/`ARCHIVE` capability codes that didn't yet exist in `auth.Capabilities`. Defensive INSERTs needed. This screen adds UNPUBLISH + CLOSE on top of #15's set. Include defensive INSERT block at top of `Crowdfunding-sqlscripts.sql` for all 8 caps used.

**ISSUE-15 — LOW — DateTime UTC kind**
Per memory `feedback_db_utc_only.md`. All DateTime params at handler entry must have `Kind=Utc`. StartDate / EndDate / PublishedAt / ClosedAt / ArchivedAt / CreatedDate / ModifiedDate — Npgsql throws on `Kind=Unspecified`. CreateCrowdFund handler must normalize wire DTOs.

**ISSUE-16 — LOW — Form Create button enablement**
Per memory `feedback_form_create_button_enablement.md`. Quick-Create dialog Create button gated by RHF `formState.isValid`, NOT by `canCreate`. The "+ Create Campaign Page" entry-point button visibility on the page header IS gated by `canCreate` capability.

**ISSUE-17 — MED — UpdateCrowdFund partial-field strategy**
Quick-Edit dialog sends only 8 fields. UpdateCrowdFund handler must NOT clobber the other ~40 fields (which were set by Create defaults or by future setup screen edits). Strategy: load entity, update 8 fields explicitly, leave rest unchanged. Do NOT use Mapster `Adapt(input, entity)` because that overwrites all properties (treating null/unset as "set to null"). Use explicit assignment block in handler.

**ISSUE-18 — LOW — Amount alignment in cards**
Per memory `feedback_amount_field_alignment.md`. Amount values in cards (Raised + Goal) — left-aligned within their flexbox per mockup (left-side raised, right-side goal). This is "info panel" context, not data-grid cell, so left-flow is acceptable. KPI tile amounts use whatever the widget renders (typically left-aligned label + value).

### Non-Issues / Resolved

- Sidebar menu rendering — DB-driven, no FE config change beyond seed
- New module creation — none (DonationModels group + fund schema exist)
- Form validation — Zod schema in `crowdfund-zod-schema.ts`
- View-page rendering — N/A (drawer-only + dialog pattern)

### SERVICE_PLACEHOLDERs

| # | UI Element | Reason | Behavior |
|---|-----------|--------|----------|
| SP-1 | "View Public Page" action | `(public)/crowdfund/[slug]/page.tsx` not yet built | Opens URL in new tab; 404 today OR placeholder stub if optionally built (see ISSUE-2) |
| SP-2 | "Dashboard" per-card action | No per-campaign analytics route | Toast: "Campaign dashboard coming soon" |
| SP-3 | "Preview" per-card action (Draft only) | No private-preview route | Toast: "Preview coming soon — use the public page after Publish" |
| SP-4 | "Edit Full Setup" drawer button + per-card Edit (non-Draft) | SCREEN-FOLLOW-UP setup screen not built | Routes to `/setting/publicpages/crowdfundingpage?id={id}` → 404 today; flag SCREEN-FOLLOW-UP |
| SP-5 | Drawer Latest Updates "View all" link | Same as SP-4 | Same routing |

### Scope Discipline Confirmation

Every UI element shown in the **admin list view** of `crowdfunding-page.html` is in scope and listed in §⑥/§⑧:
- Page header + "+Create Campaign Page" button → Quick-Create dialog
- 4 KPI stat cards → 4 widget components
- Search input + 4 filter chips → filter bar component
- Cards-grid (5 sample cards) → `<CrowdFundCardsGrid>` + `<CrowdFundCard>` components
- Status badges → `crowdfund-status-badge` renderer
- Progress bars + % → `crowdfund-progress-bar` renderer
- 3 per-card actions × 5 status variants → Actions row in `<CrowdFundCard>`
- Pagination → custom pager (12/24/48; cards-grid uses inline pager beneath grid since FlowDataTable doesn't natively support card layout)

The **editor modal** + **public preview** views in the mockup are explicitly OUT OF SCOPE (ISSUE-7 + SCREEN-FOLLOW-UP).

The drawer (Sheet) is an *addition* to the mockup — mirror of P2PCampaign #15 precedent. The mockup's card click opens the editor modal; our card click opens the drawer instead (monitoring view), and the drawer's Quick Actions deep-link to the future editor screen.

### Token Optimization Notes for Build Session

- **Skip BA agent spawn** — §①-§⑥ + §⑫ are exhaustive; orchestrator validates against template
- **Skip Solution Resolver agent** — sub-type stamped (FLOW drawer-only); patterns chosen
- **Skip UX Architect agent** — §⑥ is the design spec; no new layout decisions needed
- **BE complexity**: Medium-High (16 new files including entity + 12 handlers + 1 migration; 7 modifications; Mapster registration)
- **FE complexity**: High (Variant B + cards-grid + drawer + Quick-Create + Quick-Edit + 5 lifecycle modals + 2 confirm modals + 3 renderers + Zustand store + Zod schema)
- **Parallel BE+FE**: SAFE — contract pre-defined in §⑩; DTO is the synchronization point
- **Total estimated tokens**: ~120-150K for full build (one Opus session OR split into BE-Sonnet + FE-Opus parallel)

---

## ⑬ Build Log

### § Sessions

### Session 1 — 2026-05-13 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. BE + FE dispatched in parallel on Opus (FLOW complexity=High). BA / Solution Resolver / UX Architect agents skipped per §⑫ Token Optimization Notes.
- **Files touched**:
  - BE (20 created):
    - `Base.Domain/Models/DonationModels/CrowdFund.cs` (created)
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/CrowdFundConfiguration.cs` (created)
    - `Base.Application/Schemas/DonationSchemas/CrowdFundSchemas.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/CrowdFundEntityHelper.cs` (created)
    - `Base.Application/Validations/CrowdFundSlugValidator.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetAllCrowdFundList.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundSummary.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundById.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundStats.cs` (created)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/{CreateCrowdFund,UpdateCrowdFund,DuplicateCrowdFund,DeleteCrowdFund,PublishCrowdFund,UnpublishCrowdFund,CloseCrowdFund,ArchiveCrowdFund}.cs` (8 created)
    - `Base.API/EndPoints/Donation/Queries/CrowdFundQueries.cs` (created)
    - `Base.API/EndPoints/Donation/Mutations/CrowdFundMutations.cs` (created)
    - `Base.Infrastructure/Migrations/20260513070928_Add_CrowdFund_Entities.cs` (created — hand-crafted; Designer/Snapshot pending regen per ISSUE-19)
  - BE (6 modified):
    - `Base.Application/Data/Persistence/IDonationDbContext.cs` (modified — DbSet appended)
    - `Base.Infrastructure/Data/Persistence/DonationDbContext.cs` (modified — DbSet appended)
    - `Base.Application/Extensions/DecoratorProperties.cs` (modified — `CrowdFund = "CROWDFUND"`)
    - `Base.Domain/Models/DonationModels/GlobalDonation.cs` (modified — nullable FK + nav)
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalDonationConfiguration.cs` (modified — HasOne + IX + extended CHECK constraint to 3-arg per deviation)
    - `Base.Application/Mappings/DonationMappings.cs` (modified — CrowdFund Mapster block appended)
  - FE (22 created):
    - `src/domain/entities/donation-service/CrowdFundDto.ts` (created)
    - `src/infrastructure/gql-queries/donation-queries/CrowdFundQuery.ts` (created)
    - `src/infrastructure/gql-mutations/donation-mutations/CrowdFundMutation.ts` (created)
    - `src/presentation/pages/crm/p2pfundraising/crowdfunding.tsx` (created)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/{crowdfund-status-badge,crowdfund-progress-bar,crowdfund-category-chip}.tsx` (3 created)
    - `src/presentation/components/page-components/crm/p2pfundraising/crowdfunding/{index,index-page,crowdfund-card,crowdfund-cards-grid,crowdfund-card-skeleton,crowdfund-widgets,crowdfund-filter-bar,crowdfund-detail-sheet,crowdfund-quick-create-dialog,crowdfund-quick-edit-dialog,lifecycle-confirm-modal,delete-crowdfund-modal,crowdfund-store,crowdfund-zod-schema}.{tsx,ts}` (14 created — co-located skeleton + `index.tsx` doubles as URL router + barrel per P2PCampaign #15 precedent)
  - FE (11 modified):
    - `src/app/[lang]/crm/p2pfundraising/crowdfunding/page.tsx` (modified — replaced UnderConstruction stub)
    - `src/domain/entities/donation-service/index.ts` (modified — added CrowdFundDto export)
    - `src/infrastructure/gql-queries/donation-queries/index.ts` (modified — added CrowdFundQuery export)
    - `src/infrastructure/gql-mutations/donation-mutations/index.ts` (modified — added CrowdFundMutation export)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (modified — added 3 renderer exports)
    - `src/presentation/components/custom-components/data-tables/{advanced,basic,flow}/data-table-column-types/component-column.tsx` (3 modified — registered 3 column types)
    - `src/application/configs/data-table-configs/donation-service-entity-operations.ts` (modified — appended CROWDFUNDING block)
    - `src/presentation/pages/crm/p2pfundraising/index.ts` (modified — added CrowdFundingPageConfig export)
    - `src/presentation/components/page-components/crm/p2pfundraising/index.ts` (modified — added crowdfunding barrel re-export)
  - DB seed (1 created): `sql-scripts-dyanmic/Crowdfunding-sqlscripts.sql` (created)
- **Deviations from spec**:
  1. **Variant B containment**: index-page renders `<ScreenHeader>` + `<CrowdFundWidgets>` + `<CrowdFundFilterBar>` + `<CrowdFundCardsGrid>` as direct children — NO `<DataTableContainer>` wrapper used. Acceptable because the layout is a custom plain-JSX cards-grid (not a column-bound DataTable), so there is no internal table header to suppress. No double-header risk. (Strict prompt §⑥ wording said "DataTableContainer showHeader={false} wrapping the cards-grid" — FE agent's interpretation was simpler and equivalent.)
  2. **EF migration Designer + ModelSnapshot intentionally omitted**: BE agent produced only the Up/Down migration `.cs` body. User must run `dotnet ef migrations remove` (to discard the hand-crafted file) then `dotnet ef migrations add Add_CrowdFund_Entities` so EF regenerates Designer + Snapshot. Migration body matches the model exactly.
  3. **GlobalDonation CHECK constraint upgraded to 3-arg**: BE agent extended the existing single-source-page CHECK constraint (was 2-arg: OnlineDonationPageId + P2PCampaignPageId) to 3-arg by adding CrowdFundId. Down-migration restores 2-arg form.
  4. **Goal Met inclusive count uses in-memory filtering**: `GetCrowdFundSummary.goalMetCount` loads candidate {Id, GoalAmount} rows then counts via aggLookup in memory (EF Core 10 + Npgsql couldn't translate the join+aggregate condition cleanly in one round-trip). Still a single small projection — acceptable for V1.
  5. **`toggle` mutation alias**: CROWDFUNDING entity-operations has only 6 slots (getAll/getById/create/update/delete/toggle); FE agent aliased `toggle` to `UNPUBLISH_CROWDFUND` with comment that it's never invoked by this screen's UI. Mirrors P2PCampaign #15 `toggle → duplicate` alias.
  6. **Cards-grid Tailwind arbitrary + inline-style belt-and-suspenders**: per ISSUE-9 the layout uses BOTH `grid-cols-[repeat(auto-fill,minmax(320px,1fr))]` AND `style={{ gridTemplateColumns: "..." }}` fallback. Inline-px in `style={{}}` is the documented ISSUE-9 exception.
- **Known issues opened**: ISSUE-19, ISSUE-20, ISSUE-21 (see § Known Issues)
- **Known issues closed**: None
- **Next step**: User runs `dotnet ef migrations remove` then `dotnet ef migrations add Add_CrowdFund_Entities` (or `--force` to keep current body and regen Designer+Snapshot only) → `dotnet ef database update` → execute `Crowdfunding-sqlscripts.sql` → `pnpm dev` → smoke-test cards-grid + chips + Quick-Create + drawer + Publish flow. After that, run `/build-screen #173` for the Crowdfunding Page (public surface + 6-tab editor) which wraps this entity.

### Session 2 — 2026-05-13 — DESIGN_CHANGE — COMPLETED

- **Scope**: Reverse the CrowdFund ↔ GlobalDonation linkage direction. Per user direction: donations attribute via the existing `DonationType` taxonomy (new `'Crowd Donation'` `MasterData` value) and a many-to-many junction `fund.CrowdFundDonations(CrowdFundId, GlobalDonationId)`. This removes the just-shipped `fund.GlobalDonations.CrowdFundId` direct FK from Session 1.
- **Files touched**:
  - BE:
    - `Base.Domain/Models/DonationModels/GlobalDonation.cs` (modified — removed `int? CrowdFundId` field + `CrowdFund? CrowdFund` nav)
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalDonationConfiguration.cs` (modified — removed `HasOne(CrowdFund)` + `IX_GlobalDonations_CrowdFundId`; restored 2-arg `num_nonnulls` CHECK)
    - `Base.Domain/Models/DonationModels/CrowdFundDonation.cs` (created — junction entity: `CrowdFundDonationId` PK + `CrowdFundId` FK + `GlobalDonationId` FK + nav properties)
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/CrowdFundDonationConfiguration.cs` (created — unique index on `GlobalDonationId`, non-unique on `CrowdFundId`, both FKs `Restrict`)
    - `Base.Domain/Models/DonationModels/CrowdFund.cs` (modified — updated header comment, added `ICollection<CrowdFundDonation> CrowdFundDonations` nav)
    - `Base.Application/Data/Persistence/IDonationDbContext.cs` (modified — appended `DbSet<CrowdFundDonation> CrowdFundDonations`)
    - `Base.Infrastructure/Data/Persistence/DonationDbContext.cs` (modified — appended `CrowdFundDonations => Set<CrowdFundDonation>()`)
    - `Base.Infrastructure/Migrations/20260513070928_Add_CrowdFund_Entities.cs` (modified — removed all `GlobalDonations` changes from Up/Down; added `CrowdFundDonations` table create + 2 indexes; Down drops both tables)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundSummary.cs` (modified — donation aggregate GROUP BY rewritten to join through `CrowdFundDonations` junction)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetAllCrowdFundList.cs` (modified — same)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundById.cs` (modified — same)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundStats.cs` (modified — totals + WoW counts + Top-5 recent donors all rewritten through junction)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/DeleteCrowdFund.cs` (modified — Guard 2 donation-count now reads through junction)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/UnpublishCrowdFund.cs` (modified — same)
    - `Base.Application/Business/DonationBusiness/CrowdFunds/Commands/DuplicateCrowdFund.cs` (modified — doc-only: clarifies clone starts with zero donations because aggregates live on the junction)
  - FE: none (FE only references CrowdFund's own PK; no FE files saw the now-removed `GlobalDonation.CrowdFundId`)
  - DB:
    - `sql-scripts-dyanmic/Crowdfunding-sqlscripts.sql` (modified — STEP 0a inserts `'Crowd Donation' / CROWD_DONATION` row into `app.MasterData` under `MasterDataType.TypeCode = 'DONATIONTYPE'`; idempotent with EXISTS-on-type + NOT-EXISTS-on-row guards; header comment + ISSUE-22 entry updated)
- **Deviations from spec**: None for this session. (Session 1 deviations 1–6 still apply; deviation 3 — "GlobalDonation CHECK constraint upgraded to 3-arg" — is REVERTED as part of this session by design.)
- **Known issues opened**: ISSUE-22 (see § Known Issues)
- **Known issues closed**: None. (Session 1's ISSUE-19/20/21 still apply against the rewritten migration.)
- **Verification**: `dotnet build Base.API.csproj` → Build succeeded, 0 errors, 1 unrelated NPOI license warning.
- **Next step**: User runs `dotnet ef migrations remove` then `dotnet ef migrations add Add_CrowdFund_Entities --force` to regenerate Designer + ModelSnapshot for the new junction-table-only shape → `dotnet ef database update` → execute the updated `Crowdfunding-sqlscripts.sql` (now seeds the `Crowd Donation` MasterData row) → smoke-test. Junction is empty at first; aggregations safely return zeros until the public-page surface (#173) starts inserting GlobalDonations + matching `CrowdFundDonations` rows.

### § Known Issues

| ID | Severity | Status | Title |
|----|----------|--------|-------|
| ISSUE-19 | LOW (DOC) | OPEN | EF migration Designer + ModelSnapshot regeneration required before `dotnet ef database update` |
| ISSUE-20 | LOW | OPEN | Verify `OrganizationalUnits` table actually lives in `app` schema (migration assumes per P2PCampaignPage precedent; if it's `corg`, adjust principalSchema before applying) |
| ISSUE-21 | LOW | OPEN | DB seed sample-data SELECTs use `app."Companies"`; if live DB uses a different schema the 2 sample inserts will silently skip (NOT EXISTS guards) |
| ISSUE-22 | MED | OPEN | Public-page donation flow (#173) must explicitly insert a `fund.CrowdFundDonations` junction row each time it creates a `fund.GlobalDonations` row tagged `DonationType = 'Crowd Donation'`. If the junction insert is skipped, aggregations (RaisedAmount / DonorCount / RecentDonors / Goal-Met) will silently return zero for that campaign. Acceptance criteria for #173 must include this. |

ISSUE-1 (MED multi-currency totalRaised), ISSUE-2 (MED public route — deferred to #173), ISSUE-3 (LOW slug counter cap), ISSUE-4 (MED IsGoalMet badge divergence — handled in goalMetCount), ISSUE-5/6/7/8/9/10/11/12/13/14/15/16/17/18 from prompt §⑫ all remain OPEN / accepted-as-designed per their original status. They are documented in the prompt and not duplicated here.

---
