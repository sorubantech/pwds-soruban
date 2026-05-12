---
screen: P2PCampaign
registry_id: 15
module: CRM (P2P Fundraising)
status: COMPLETED
scope: FULL
screen_type: FLOW
flow_variant: drawer-only
complexity: Medium
new_module: NO
planned_date: 2026-05-12
completed_date: 2026-05-12
last_session_date: 2026-05-12
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (2 mockups: `p2p-campaign-list.html` = THIS screen; `p2p-campaign-setup.html` = #170 P2PCampaignPage setup, NOT this screen — the setup mockup is owned by #170 which is already COMPLETED. The list mockup is THIS screen's pixel-perfect spec.)
- [x] Existing code reviewed — `P2PCampaignPage` entity + EF config + Schemas + 8 admin queries + 6 admin commands + 4 public queries + 4 public mutations + GraphQL endpoints + EF migration + DB seed ALL ALREADY SHIPPED by #170 on 2026-05-09. FE route is a 5-line `UnderConstruction` stub at `[lang]/crm/p2pfundraising/p2pcampaign/page.tsx`. The existing `GetAllP2PCampaignPageList` query already aggregates totalRaised + totalDonors + totalFundraisers + activeFundraisers + pendingApprovals via batched GROUP BY queries (no N+1) — directly reusable for this screen's grid.
- [x] Drawer-only FLOW pattern selected (Reconciliation #14 + P2PFundraiser #135 precedent — NO `?mode=new/edit/read` view-page; "+ Create P2P Campaign" deep-links to #170 setup screen at `setting/publicpages/p2pcampaignpage?mode=new`; row-click opens a 560px right-side `<Sheet>` detail panel; "Edit" inline action deep-links to #170 setup at `setting/publicpages/p2pcampaignpage?id={P2PCampaignPageId}` — this screen is the **CRM management surface**, not the page setup editor).
- [x] Business rules + lifecycle re-confirmed (already enforced by #170 entity: Draft → Published → Active → Closed → Archived; Always-Active campaigns hide Start/End dates and Goal; status displayed in chips drives the 5-chip filter).
- [x] FK targets resolved (all FKs already wired from #170 build — Campaign, CompanyPaymentGateway, EmailTemplate×6, WhatsAppTemplate, plus implicit FKs to fund.GlobalDonations and fund.P2PFundraisers for aggregation).
- [x] File manifest computed (3 NEW BE files + 2 NEW BE commands + extends existing endpoints; full FE build over the stub; DB seed-only menu addition).
- [x] Approval config pre-filled (MenuCode=`P2PCAMPAIGN`, ParentMenu=`CRM_P2PFUNDRAISING`, URL=`crm/p2pfundraising/p2pcampaign`, OrderBy=1 — sibling of P2PFUNDRAISER #135 OrderBy=2).
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt is exhaustively pre-analyzed; orchestrator validates against §① §② §④ §⑤ rather than re-running BA agent)
- [x] Solution Resolution complete (FLOW-with-drawer-only confirmed, scope = CRM cross-campaign management grid only — page-content editing belongs to #170)
- [x] UX Design finalized (Variant B header + 4 KPI widgets + 5 chips + 10-col grid + 560px right-side detail Sheet + Duplicate confirm modal + Delete confirm modal)
- [x] User Approval received
- [x] Backend code generated          ← 1 NEW query (GetP2PCampaignSummary) + 2 NEW commands (DuplicateP2PCampaignPage / DeleteP2PCampaignPage) + SummaryDto + RecentDonorEntryDto + RecentDonors property on StatsDto (ISSUE-2 fix) + endpoint appends. Clone isolation via .AsNoTracking() + manual property copy (no Mapster ignore-config needed). Permissions.Create used for Duplicate (Permissions.Write doesn't exist in enum). `dotnet build` 0 errors.
- [x] Backend wiring complete         ← No migration, no DbContext change, no new DecoratorProperty (all pre-existing from #170)
- [x] Frontend code generated         ← Variant B index-page + 4 KPI widgets + 5 filter chips + Duplicate/Delete confirm modals + Detail Sheet (6 sections) + Zustand store + DTO + GQL Q/M + page-config + URL router + 2 NEW shared cell renderers (`p2p-campaign-status-badge` / `p2p-progress-cell`); REUSED existing `campaign-name-link` (Screen #30). Grid is plain HTML table (Reconciliation #14 precedent) — double-header bug impossible by construction.
- [x] Frontend wiring complete        ← entity-operations P2PCAMPAIGN block (in `application/configs/data-table-configs/`) + 3 column-type registries (advanced/basic/flow component-column.tsx) + shared-cell-renderers barrel + pages barrel + sidebar via DB seed
- [x] DB Seed script generated (`P2PCampaign-sqlscripts.sql` in `sql-scripts-dyanmic/` — typo preserved. Idempotent. Menu @ P2PCAMPAIGN under CRM_P2PFUNDRAISING OrderBy=1, 6 caps + BUSINESSADMIN grants, Grid FLOW, 10 GridFields, GridFormSchema=NULL. NO MasterData seed, NO sample data seed.)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/{lang}/crm/p2pfundraising/p2pcampaign` (replaces UnderConstruction stub)
- [ ] Variant B layout renders: ScreenHeader + 4 KPI widgets + DataTableContainer with `showHeader={false}` — NO double-header
- [ ] **4 KPI widgets** (mockup-pixel-match):
  - Active Campaigns — value=`activeCount`, subtitle=`Total: {totalCount}`, icon=users (teal tint)
  - Total Fundraisers — value=`totalFundraisers`, subtitle=`Active: {activeFundraisers}`, icon=user-group (blue tint)
  - Total Raised (P2P) — value=`totalRaised` formatted currency, subtitle=`This year`, icon=hand-holding-dollar (green tint)
  - Avg Per Fundraiser — value=`avgPerFundraiser` formatted currency, subtitle=`Top: {topFundraiserAmount}`, icon=chart-line (purple tint)
- [ ] **5 status filter chips** (mockup): All / Active / Completed / Draft / Archived — counts come from `P2PCampaignSummary` query (`allCount / activeCount / completedCount / draftCount / archivedCount`), NOT client-side filter
- [ ] **Search input**: by Campaign Name OR Slug (server-side via `searchTerm` arg of existing `GetAllP2PCampaignPageList`)
- [ ] **10-column grid** in pixel-perfect order: Campaign Name (clickable link, opens drawer — uses `campaign-name-link` renderer) / Status (badge — uses `p2p-campaign-status-badge` renderer with 5 variants: Active=green, Always-Active=blue infinity icon, Completed=dark-green check, Draft=amber, Archived=slate) / Goal (currency or em-dash if Always-Active) / Raised (bold currency) / Progress (uses `p2p-progress-cell` renderer with %-bar in 3 color tiers high/medium/low + 🔥 emoji over 100%, or em-dash if Always-Active or Draft with no donations) / Fundraisers (int) / Donors (int) / Start Date (date or em-dash) / End Date (date or em-dash) / Actions (inline button group, varies per status)
- [ ] **Per-row inline actions** (right-aligned, click stops propagation):
  - Active OR Always-Active → Dashboard (deep-link `/crm/p2pfundraising/p2pfundraiser?campaignPageId={id}` to #135 P2PFundraiser screen filtered to this campaign) + Edit (deep-link `/setting/publicpages/p2pcampaignpage?id={id}` to #170 setup) + View Page (`/p2p/{slug}` in NEW TAB — uses BaseUrl from env)
  - Completed → Dashboard + View Page + Duplicate (opens Duplicate confirm modal)
  - Archived → View Page + Duplicate (Edit hidden; Dashboard hidden)
  - Draft → Edit (deep-link to #170 setup) + Delete (opens Delete confirm modal; deletion only allowed for Draft per business rule)
- [ ] **Row click** (anywhere outside actions cell) → opens 560px right-side detail Sheet
- [ ] **Detail Sheet** (mockup-mirror, 6 sections — DIFFERENT from #170 setup because this is a CRM dashboard view, not page editor):
  1. **Campaign Summary** — Slug (read-only with copy button) + Campaign Type chip (Timed/Occasion/Always-Active) + Status badge + Created/Published dates + Goal + Raised + Progress bar + Days Remaining (if Timed) or "Always Active" / "Completed" / "Archived" caption
  2. **Performance Metrics** — 4-tile grid: Total Donors, Total Fundraisers, Active Fundraisers, Pending Approvals (amber tint if > 0) — uses existing `GetP2PCampaignPageStats` query
  3. **Top Fundraisers** — table of top 5 from existing `GetP2PCampaignPageLeaderboard?topN=5` query (Rank medal / Avatar / Name / Raised / %-of-Goal); footer link "View all {totalFundraisers} fundraisers →" deep-links to #135 filtered to this campaign
  4. **Recent Donors** — top-5 list from `fund.GlobalDonations WHERE P2PCampaignPageId={id} ORDER BY CreatedDate DESC LIMIT 5` (already supported by existing `GetP2PCampaignPageStats` via aggregation — confirm projection includes recentDonors array; if not, ADD to existing query handler under §⑫ note). Each item: Donor avatar (initials or anon icon) + Donor name (or "Anonymous") + Amount + "{N} hours/days ago" relative timestamp + optional message snippet
  5. **Communication Settings preview** — 3-row read-only list: "Confirmation email: {template name or 'Not set'}" / "WhatsApp donation alerts: ON/OFF" / "Goal milestone alerts: ON/OFF" — Edit link routes to #170 setup tab 5
  6. **Quick Actions** — 4 vertical buttons: Edit Campaign Setup (→ #170) / View Dashboard (→ #135 P2PFundraiser filtered) / View Public Page (→ `/p2p/{slug}` in new tab) / Copy Public URL (clipboard with toast)
- [ ] **Duplicate confirm modal** (opens on per-row Duplicate action):
  - Body text: "Create a draft copy of '{campaignName}'? The new campaign will start in Draft status with a new slug like '{slug}-copy-{n}'. Donors and fundraisers will NOT be copied."
  - Buttons: Cancel / Confirm Duplicate
  - On Confirm: invokes `DuplicateP2PCampaignPage(id)` → BE clones the row (new slug, PageStatus='Draft', PublishedAt=NULL, ArchivedAt=NULL, deeply clones jsonb fields, creates new Campaign row with `[Copy of {name}]` prefix, returns new P2PCampaignPageId) → toast: "Campaign duplicated as Draft" → refresh list+summary → does NOT navigate (admin can click new Draft row + Edit to customize)
- [ ] **Delete confirm modal** (opens on per-row Delete action — DRAFT ONLY):
  - Body text: "Delete '{campaignName}'? This Draft has no donations or fundraisers and cannot be recovered."
  - Buttons: Cancel / Confirm Delete (red)
  - On Confirm: invokes `DeleteP2PCampaignPage(id)` → BE guards (Draft only, no associated GlobalDonations rows, no P2PFundraisers rows) → soft-delete via `IsDeleted=true` → toast: "Campaign deleted" → refresh list+summary
  - On guard failure: BE returns BadRequestException → FE shows error toast with reason ("Only Draft campaigns can be deleted; this campaign is Active" / "Cannot delete: campaign has {N} fundraisers attached")
- [ ] **"+ Create P2P Campaign" header button** (top-right next to ScreenHeader actions): deep-links to `/setting/publicpages/p2pcampaignpage?mode=new` — opens the #170 setup screen in Create mode. Admin completes setup tabs there, then returns to this list via #170's breadcrumb-back action (#170 already has this back-link wired).
- [ ] **Pagination**: 10/25/50/100 per page; default 10; standard FlowDataTable behavior
- [ ] **Empty state**: when 0 campaigns total → "No P2P campaigns yet — create your first to enable supporter fundraising" + Create P2P Campaign CTA (same deep-link)
- [ ] **Filtered empty state**: when chip/search yields 0 → "No campaigns match your filters" + Clear Filters button
- [ ] **Loading state**: skeleton rows in grid + skeleton tiles in 4 KPI widgets (NO raw "Loading..." string)
- [ ] **Error state**: red banner + retry button if any of the 3 queries error
- [ ] DB Seed — admin menu visible at `CRM > P2P Fundraising > P2P Campaigns` (route `crm/p2pfundraising/p2pcampaign` OrderBy=1, ABOVE P2P Fundraisers which is OrderBy=2); grid + chips + actions all functional against existing seeded P2PCampaignPage rows from #170
- [ ] **5 UI uniformity grep checks PASS**:
  - 0 inline hex in `style={{...}}` outside designated renderers
  - 0 inline px in `style={{...}}` outside designated renderers
  - 0 raw `Loading...` strings (use Skeleton)
  - 0 `fa-*` className refs (use Lucide / Phosphor icons)
  - 0 inline-hex skeleton background

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: P2PCampaign
Module: CRM (P2P Fundraising sub-module — sibling of P2PFundraiser #135, Crowdfunding #16, MatchingGift #11)
Schema: `fund` (entity already exists; this screen adds ZERO new entities)
Group: DonationModels (existing — established by #170 P2PCampaignPage 2026-05-09)

**Business**: This is the **CRM management grid for all P2P (peer-to-peer) campaigns**. Where #170 P2PCampaignPage is the **page-setup editor** (Tab-1 Basic Info / Tab-2 Fundraiser Settings / Tab-3 Donation Settings / Tab-4 Branding & Page / Tab-5 Communication — under `setting/publicpages/p2pcampaignpage`), this screen #15 is the **CRM operational view** — a BUSINESSADMIN's at-a-glance list of every P2P campaign with its lifecycle, fundraising progress, fundraiser count, and donor count. The mockup is a 4-KPI-widget header (Active Campaigns / Total Fundraisers / Total Raised / Avg Per Fundraiser) over a 10-column grid (Campaign Name / Status / Goal / Raised / Progress / Fundraisers / Donors / Start / End / Actions) with 5 status chips (All / Active / Completed / Draft / Archived) and search by campaign name. Row click opens a 560px right-side slide-out detail panel; per-row inline actions vary by status — Active rows show Dashboard (→ #135 P2PFundraiser drill-down filtered to this campaign) / Edit (→ #170 setup) / View Page (public URL in new tab); Completed rows replace Edit with Duplicate (clone-to-Draft); Archived rows have View Page + Duplicate only; Draft rows have Edit + Delete (the only status where deletion is allowed).

**Who uses it**: BUSINESSADMIN (and any role with `P2PCAMPAIGN.READ`) to monitor campaign health across the portfolio, drill into individual fundraiser performance via #135, or jump to #170 for content edits.

**Why this is FLOW-with-drawer-only (no view-page)**: Reconciliation #14 + P2PFundraiser #135 precedent. The grid + drawer + inline actions cover the entire CRM monitoring workflow; there is no "edit campaign content" UI to build because that surface lives at #170 — building a `?mode=new/edit/read` view-page here would duplicate #170 and create two-source-of-truth ambiguity. The "+Create P2P Campaign" button deep-links out to #170 Create mode; the "Edit" inline action deep-links out to #170 Edit mode; the "View Page" inline action opens the public surface in a new tab.

**Why NOT a duplicate of #170**: The two screens have different consumers, different layouts, and different routes:
- #170 → `setting/publicpages/p2pcampaignpage` — content / branding editor under Settings menu, 5-tab editor matching `p2p-campaign-setup.html` mockup, audience = page admin
- #15  → `crm/p2pfundraising/p2pcampaign` — CRM operational grid under CRM menu, table+drawer matching `p2p-campaign-list.html` mockup, audience = fundraising manager
The shared entity (`fund.P2PCampaignPages`) is the same underlying record set — both screens read+write the same rows, just with different UI lenses. This mirrors the #170/#135 split (page editor vs fundraiser management grid).

**Related screens** (per registry):
- #170 P2PCampaignPage (COMPLETED) — page setup editor; receives deep-links from this screen
- #135 P2PFundraiser (PROMPT_READY) — fundraiser management grid; receives drill-down deep-link from "Dashboard" inline action
- #11 MatchingGift (COMPLETED) — sibling FLOW with embedded grid
- #16 Crowdfunding (PARTIAL — pending plan) — sibling EXTERNAL_PAGE in same sub-module
- #1 GlobalDonation (COMPLETED) — donation source records that aggregate into P2P campaign totals
- #19 Contact (PARTIAL) — fundraiser/donor identity; opens via deep-link from drawer

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **NO new entity** — this screen reads/manages the existing `fund.P2PCampaignPages` table shipped by #170 on 2026-05-09.

**Table**: `fund."P2PCampaignPages"` (already exists)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| P2PCampaignPageId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (HttpContext) |
| CampaignId | int | — | YES | app.Campaigns | Wraps underlying Campaign |
| Slug | string | 100 | YES | — | Unique per tenant; lower-kebab; auto-from-Campaign.CampaignName |
| PageStatus | string | 20 | YES | — | "Draft" \| "Published" \| "Active" \| "Closed" \| "Archived" |
| PublishedAt | DateTime? | — | NO | — | Set on Publish lifecycle command |
| ArchivedAt | DateTime? | — | NO | — | Set on Archive lifecycle command |
| CampaignTypeKind | string | 20 | YES | — | "TIMED" \| "OCCASION" \| "ALWAYS_ACTIVE" |
| AllowPublicRegistration | bool | — | YES | — | Fundraiser self-signup toggle |
| FundraiserApprovalMode | string | 10 | YES | — | "AUTO" \| "MANUAL" |
| DefaultIndividualGoal | decimal(18,2) | — | YES | — | — |
| MinIndividualGoal | decimal(18,2) | — | YES | — | — |
| MaxIndividualGoal | decimal(18,2) | — | YES | — | — |
| AllowTeamFundraising | bool | — | YES | — | — |
| DefaultTeamGoal | decimal(18,2)? | — | NO | — | — |
| MaxTeamSize | int? | — | NO | — | — |
| FundraiserPageOptionsJson | jsonb | — | YES | — | What fundraisers can customize |
| ShowLeaderboard | bool | — | YES | — | — |
| ShowFundraiserCount | bool | — | YES | — | — |
| AchievementBadgesEnabled | bool | — | YES | — | — |
| OverrideDonationSettings | bool | — | YES | — | — |
| AmountChipsJson | jsonb? | — | NO | — | Array of decimals (max 8) |
| AllowCustomAmount | bool | — | YES | — | — |
| MinimumDonationAmount | decimal(18,2) | — | YES | — | — |
| AllowRecurringDonations | bool | — | YES | — | — |
| AllowAnonymousDonations | bool | — | YES | — | — |
| EnabledPaymentMethodsJson | jsonb | — | YES | — | Array of payment method config |
| CompanyPaymentGatewayId | int? | — | NO | fund.CompanyPaymentGateways | — |
| AllowDonorCoverFees | bool | — | YES | — | — |
| MatchingGiftIntegrationEnabled | bool | — | YES | — | — |
| PageTheme | string | 30 | YES | — | "default" \| "dark" \| "colorful" \| "minimal" |
| PrimaryColorHex | string | 9 | YES | — | — |
| SecondaryColorHex | string | 9 | YES | — | — |
| LogoUrl | string? | 500 | NO | — | — |
| HeaderStyle | string | 30 | YES | — | "full-width-hero" \| "split" \| "minimal" |
| ShowOrganizationInfo | bool | — | YES | — | — |
| ShowImpactStats | bool | — | YES | — | — |
| ShowDonorWall | bool | — | YES | — | — |
| CustomCssOverride | string? | — | NO | — | — |
| 6× *EmailTemplateId | int? | — | NO | corg.EmailTemplates | Communication Tab |
| WhatsAppDonationAlertEnabled | bool | — | YES | — | — |
| WhatsAppDonationAlertTemplateId | int? | — | NO | corg.WhatsAppTemplates | — |
| WhatsAppGoalMilestoneAlertsEnabled | bool | — | YES | — | — |
| DefaultShareMessage | string? | 500 | NO | — | — |
| OgImageUrl | string? | 500 | NO | — | — |
| OgTitle | string? | 100 | NO | — | — |
| OgDescription | string? | 200 | NO | — | — |
| RobotsIndexable | bool | — | YES | — | — |

**Aggregated/computed fields** (NOT columns — produced by `GetAllP2PCampaignPageList` handler's batched GROUP BY queries; reused as-is):
- `TotalRaised` (decimal) — SUM(NetAmount) over fund.GlobalDonations WHERE P2PCampaignPageId=row.Id AND IsDeleted=false
- `TotalDonors` (int) — DISTINCT ContactId over the same join
- `TotalFundraisers` (int) — COUNT over fund.P2PFundraisers WHERE P2PCampaignPageId=row.Id AND IsDeleted=false
- `ActiveFundraisers` (int) — COUNT WHERE FundraiserStatus='Active'
- `PendingApprovals` (int) — COUNT WHERE FundraiserStatus='Pending'
- `LastDonationAt` (DateTime?) — MAX(DonationDate)
- `ProgressPercent` (decimal, FE-computed) — TotalRaised / Campaign.GoalAmount * 100 (or NULL for Always-Active)
- `GoalAmount` (decimal) — projected from Campaign.GoalAmount (NULL display for Always-Active)
- `CampaignName` (string) — projected from Campaign.CampaignName
- `StartDate / EndDate` (DateTime?) — projected from Campaign.StartDate/EndDate (NULL for Always-Active)

**Child Entities** (already exist — referenced only for aggregation, NOT modified by this screen):
| Child Entity | Relationship | Used By This Screen |
|-------------|-------------|---------------------|
| P2PFundraiser | 1:Many via P2PCampaignPageId | drawer Top-5 leaderboard + drill-down deep-link to #135 |
| P2PFundraiserTeam | 1:Many via P2PCampaignPageId | drawer aggregate count only |
| P2PFundraiserMilestone | 1:Many via P2PFundraiserId | NOT used |
| GlobalDonation | M:1 via P2PCampaignPageId (FK on donation row) | drawer Recent Donors + TotalRaised aggregate |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for projection Include() chain — already wired by #170) + Frontend Developer (for any ApiSelect dropdowns in modals — Duplicate/Delete modals don't need any, so this is informational)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CampaignId | Campaign | `Base.Domain/Models/ApplicationModels/Campaign.cs` | `getCampaigns` | CampaignName | CampaignListDto |
| CompanyPaymentGatewayId | CompanyPaymentGateway | `Base.Domain/Models/DonationModels/CompanyPaymentGateway.cs` | (not exposed cross-tenant) | DisplayName | — |
| *EmailTemplateId×6 | EmailTemplate | `Base.Domain/Models/CommModels/EmailTemplate.cs` | `getAllEmailTemplateList` | TemplateName | EmailTemplateResponseDto |
| WhatsAppDonationAlertTemplateId | WhatsAppTemplate | `Base.Domain/Models/CommModels/WhatsAppTemplate.cs` | `getAllWhatsAppTemplateList` | TemplateName | WhatsAppTemplateResponseDto |

**Important**: This screen does NOT use any of these FKs as dropdowns — all FK editing happens in #170 setup. The FKs are listed here only for the BE/FE devs to understand the projection paths in the existing `GetAllP2PCampaignPageList` handler that this screen reuses.

**FE GQL nullable-array rule** (per user memory `feedback_fe_query_nullability_must_match_be.md`):
- BE param `string[]? statuses` maps to GraphQL `[String!]` (NOT `[String]`)
- FE must declare the variable as `[String!]` in `query GetAllP2PCampaignPageList(..., $statuses: [String!])` or HotChocolate rejects with `Variable $statuses got invalid value`
- Hot-fix precedent: SMSTemplate #29 ISSUE-6

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (UI guards)

**Inherited from #170 (already enforced — DO NOT re-enforce):**
- Slug uniqueness per tenant (filtered unique index)
- Slug reserved list (admin/api/p/p2p/preview/login/auth/start)
- Lifecycle transitions (Draft→Published, Published→Active, Active→Closed, Active→Archived, Closed→Archived) via dedicated commands
- Publish validation (CampaignName + Slug + Type + Goal + ≥1 payment method + ≥1 amount chip OR AllowCustomAmount + ≥1 communication template — already done by `GetP2PCampaignPagePublishValidation`)
- Fundraiser-cascade behavior (parent Close → child fundraisers auto-Completed)

**NEW rules added by this screen:**

1. **Duplicate Rule** (DuplicateP2PCampaignPage command):
   - Allowed FROM any status (Draft / Published / Active / Closed / Archived)
   - Result: new row with `PageStatus='Draft'`, `PublishedAt=NULL`, `ArchivedAt=NULL`
   - Slug: `{originalSlug}-copy` if available, else `{originalSlug}-copy-2`, ..., `{originalSlug}-copy-N` (incremental loop with uniqueness check; cap at 99 with BadRequestException at 100+)
   - Campaign: creates NEW `app.Campaigns` row with `CampaignName='[Copy of] {originalName}'`, GoalAmount preserved, StartDate/EndDate cleared (NULL — admin must set new dates after Duplicate)
   - Jsonb fields (FundraiserPageOptionsJson, AmountChipsJson, EnabledPaymentMethodsJson) — copied byte-for-byte (no deep-clone needed since they're serialized strings)
   - Aggregates NOT copied: no donations, no fundraisers, no teams (clean Draft)
   - Communication templates copied as-is (template FKs reused — no template duplication)
   - Returns new P2PCampaignPageId in BaseApiResponse

2. **Delete Rule** (DeleteP2PCampaignPage command):
   - Allowed ONLY when `PageStatus='Draft'`
   - Guard 1: throw `BadRequestException` with reason if `PageStatus != 'Draft'` ("Only Draft campaigns can be deleted; this campaign is {Status}")
   - Guard 2: throw `BadRequestException` if any `fund.P2PFundraisers` row exists with this P2PCampaignPageId (regardless of status) ("Cannot delete: campaign has {N} fundraisers attached")
   - Guard 3: throw `BadRequestException` if any `fund.GlobalDonations` row exists with this P2PCampaignPageId AND IsDeleted=false ("Cannot delete: campaign has {N} donations recorded")
   - Soft-delete via `IsDeleted=true` + clear all jsonb fields to NULL (storage cleanup) — DO NOT delete the underlying `app.Campaigns` row (Campaigns may be shared across multiple P2PCampaignPages historically; let admin clean up via Campaign #4 screen if desired)

3. **Summary Aggregation Rule** (GetP2PCampaignSummary query):
   - Tenant-scoped (CompanyId from HttpContext)
   - Returns single P2PCampaignSummaryDto with: `allCount`, `activeCount`, `completedCount`, `draftCount`, `archivedCount`, `totalCount`, `totalFundraisers`, `activeFundraisers`, `totalRaised` (this-year), `avgPerFundraiser`, `topFundraiserAmount`
   - `activeCount`: WHERE PageStatus IN ('Active', 'Published')
   - `completedCount`: WHERE PageStatus IN ('Closed')
   - `archivedCount`: WHERE PageStatus IN ('Archived')
   - `draftCount`: WHERE PageStatus = 'Draft'
   - `totalFundraisers` / `activeFundraisers`: COUNT and COUNT-WHERE-Active over `fund.P2PFundraisers` JOIN P2PCampaignPages WHERE CompanyId=current
   - `totalRaised` (this-year): SUM(NetAmount) over `fund.GlobalDonations WHERE P2PCampaignPageId IS NOT NULL AND DonationDate >= dateTrunc('year', NOW()) AND CompanyId=current` — ISSUE-1: currency mixing if multi-currency (defer to V2, document)
   - `avgPerFundraiser`: `totalRaised / NULLIF(activeFundraisers, 0)` — 0 if no active fundraisers
   - `topFundraiserAmount`: MAX of SUM(NetAmount) GROUP BY P2PFundraiserId across all P2PFundraisers for tenant — uses subquery
   - All counts/sums computed in single round-trip with `Select(new {...})` projection

4. **Status Chip Behavior** (FE):
   - Chip click filters `statuses` arg sent to `GetAllP2PCampaignPageList`
   - "All" → empty `statuses` array (BE returns all)
   - "Active" → `['Active', 'Published']` (both are operationally Active in UI)
   - "Completed" → `['Closed']`
   - "Draft" → `['Draft']`
   - "Archived" → `['Archived']`
   - Mockup says "Always Active" is a sub-state of Active — the chip "Active" includes Always-Active campaigns because they all share PageStatus='Active' regardless of CampaignTypeKind. The "Always-Active" badge variant is driven by `CampaignTypeKind='ALWAYS_ACTIVE'`, not by PageStatus.

5. **Authorization**:
   - All queries: `[CustomAuthorize(DecoratorDonationModules.P2PCampaignPage, Permissions.Read)]` — reuses existing decorator
   - DuplicateP2PCampaignPage: `[CustomAuthorize(DecoratorDonationModules.P2PCampaignPage, Permissions.Write)]` — uses Write permission since it creates a new row
   - DeleteP2PCampaignPage: `[CustomAuthorize(DecoratorDonationModules.P2PCampaignPage, Permissions.Delete)]` — uses Delete permission

**Workflow**: Not applicable — this screen doesn't drive lifecycle transitions; #170 owns lifecycle commands (Publish/Unpublish/Close/Archive). This screen only drives Duplicate and Delete (Delete-Draft-Only).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Variant**: drawer-only (NO view-page, NO `?mode=new/edit/read`)
**Reason**: This is a CRM **monitoring** surface for an existing entity whose content lives at #170. Building a view-page would duplicate #170's editor. The mockup shows a list page that delegates ADD/EDIT to a separate setup screen via deep-links — the canonical Reconciliation #14 + P2PFundraiser #135 pattern.

**Backend Patterns Required:**
- [ ] Standard CRUD (11 files) — NO, all CRUD lives at #170
- [x] Tenant scoping (CompanyId from HttpContext) — reuses existing pattern
- [ ] Nested child creation — NO
- [ ] Multi-FK validation — NO
- [ ] Unique validation — NO (Slug uniqueness already enforced by #170)
- [ ] Workflow commands — NO (already at #170)
- [x] **NEW**: Duplicate command (DuplicateP2PCampaignPage) — creates clone with slug-counter + status reset
- [x] **NEW**: Delete command (DeleteP2PCampaignPage) — soft-delete with 3 guard rules
- [x] **NEW**: Summary query (GetP2PCampaignSummary) — 4-KPI cross-campaign rollup
- [x] **REUSE**: Existing GetAllP2PCampaignPageList + GetP2PCampaignPageById + GetP2PCampaignPageStats + GetP2PCampaignPageLeaderboard — already wired

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — Variant B (ScreenHeader + widgets + DataTableContainer showHeader=false)
- [ ] view-page.tsx with 3 URL modes — NO (drawer-only)
- [ ] React Hook Form — NO (no form on this screen)
- [x] Zustand store (`p2p-campaign-store.ts`) — for selected row, drawer open/close, modal state, filter chip, search term
- [x] Detail Sheet (Sheet from shadcn/ui) — 560px right-side, 6 sections
- [x] Confirm modals — Duplicate confirm + Delete confirm
- [x] Summary cards / 4 KPI widgets — top of page
- [x] 5 status filter chips — counts from summary query
- [x] Grid aggregation columns — Raised, Progress, Fundraisers, Donors (already projected by `GetAllP2PCampaignPageList`)
- [x] 3 NEW shared cell renderers — `campaign-name-link` / `p2p-progress-cell` / `p2p-campaign-status-badge`
- [x] Deep-links to #170 (Edit) and #135 (Dashboard) and public surface (`/p2p/{slug}`)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/fundraising/p2p-campaign-list.html` — this IS the design spec.
> The setup mockup (`p2p-campaign-setup.html`) belongs to #170 — NOT this screen's responsibility.

### Layout Variant

**Grid Layout Variant**: `widgets-above-grid` (mockup shows 4 KPI cards ABOVE the table)
- FE Dev uses **Variant B**: `<ScreenHeader>` + 4 widget components + `<DataTableContainer showHeader={false}>`
- Header rendered once via ScreenHeader; DataTableContainer's internal header suppressed via `showHeader={false}`
- **CRITICAL**: Failure to set `showHeader={false}` produces double-header bug (ContactType #19 precedent — caught by post-build grep check)

### Page Header (ScreenHeader)
- Title: "Peer-to-Peer Campaigns"
- Subtitle: "Enable supporters to fundraise on your behalf"
- Right-side actions: `+ Create P2P Campaign` button (teal/accent solid, plus icon) — deep-links to `/setting/publicpages/p2pcampaignpage?mode=new`

### KPI Widgets (4 cards, equal width, horizontal grid)

| # | Widget Title | Value Source | Subtitle | Icon | Tint |
|---|-------------|-------------|----------|------|------|
| 1 | Active Campaigns | `summary.activeCount` (int) | `Total: {summary.totalCount}` | `Users` (Lucide) | teal |
| 2 | Total Fundraisers | `summary.totalFundraisers` (int, formatted with thousands sep) | `Active: {summary.activeFundraisers}` | `UsersRound` (Lucide) | blue |
| 3 | Total Raised (P2P) | `summary.totalRaised` (currency, USD default — V2 multi-currency) | `This year` | `HandHeart` (Lucide) | green |
| 4 | Avg Per Fundraiser | `summary.avgPerFundraiser` (currency) | `Top: {summary.topFundraiserAmount}` | `TrendingUp` (Lucide) | purple |

**Loading state per widget**: skeleton tile (matches widget dimensions, NO raw "Loading..." string).
**Error state per widget**: red icon + "—" + "Failed to load" caption.

### Filter Bar

**Row 1 — Search input** (left-aligned, max-width 320px):
- Placeholder: "Search campaigns by name, status..."
- Icon: search (Lucide)
- Debounce: 300ms before triggering BE search
- Server-side: passes through to existing `searchTerm` arg of `GetAllP2PCampaignPageList`

**Row 2 — Filter chips** (left-aligned, horizontal flex with gap):
- 5 chips: `All ({allCount})` (default active) / `Active ({activeCount})` / `Completed ({completedCount})` / `Draft ({draftCount})` / `Archived ({archivedCount})`
- Counts from `summary` query — re-fetched every time summary refreshes
- Active chip: solid teal bg, white text
- Inactive: white bg, slate border, slate text, hover teal border + teal text
- Click → updates `statuses` filter in store → re-query grid

### Grid Columns (10 columns in mockup pixel-perfect order)

| # | Column Header | Field Key | Display Type | Width | Sortable | Renderer | Notes |
|---|--------------|-----------|-------------|-------|----------|----------|-------|
| 1 | Campaign Name | `campaignName` | text + link | auto (flex) | YES | `campaign-name-link` | Accent color, bold, click opens drawer |
| 2 | Status | `pageStatus` + `campaignTypeKind` | badge | 130px | YES | `p2p-campaign-status-badge` | 5 visual variants — see below |
| 3 | Goal | `goalAmount` | currency | 100px | YES | inline + currencyFormat | Em-dash when CampaignTypeKind='ALWAYS_ACTIVE' OR goalAmount NULL |
| 4 | Raised | `totalRaised` | currency (bold) | 110px | YES | inline + currencyFormat | Bold weight 600 |
| 5 | Progress | computed `totalRaised / goalAmount` | bar + % | 130px | NO | `p2p-progress-cell` | 3-tier color (high green ≥75% / medium amber 50-74% / low red <50%) + 🔥 if >100% + em-dash if Always-Active or Draft with 0 raised |
| 6 | Fundraisers | `totalFundraisers` | int | 90px | YES | inline | Em-dash if 0 AND Draft |
| 7 | Donors | `totalDonors` | int | 90px | YES | inline | Em-dash if 0 AND Draft |
| 8 | Start Date | `startDate` (from Campaign join) | date | 110px | YES | inline + dateFormat | Em-dash if Always-Active OR NULL |
| 9 | End Date | `endDate` (from Campaign join) | date | 110px | YES | inline + dateFormat | Em-dash if Always-Active OR NULL |
| 10 | Actions | — | button group | 220px | NO | inline JSX | Per-row action set varies by status — see below |

**Search/Filter Fields**: `searchTerm` (BE-side: Slug + Campaign.CampaignName); `statuses[]` (BE-side: PageStatus IN); both already supported.

**Grid Actions** (per-row inline, in order, right-aligned, click stops propagation):

| Status | Visible Actions |
|--------|-----------------|
| Active OR Published (with CampaignTypeKind='TIMED' or 'OCCASION') | Dashboard + Edit + View Page |
| Active OR Published (with CampaignTypeKind='ALWAYS_ACTIVE') | Dashboard + Edit + View Page |
| Completed (PageStatus='Closed') | Dashboard + View Page + Duplicate |
| Archived (PageStatus='Archived') | View Page + Duplicate |
| Draft (PageStatus='Draft') | Edit + Delete |

**Action button visual**: shadcn outline-button variant `xs` size, Lucide icons, 4px gap, hover teal border.

**Row Click** (anywhere outside Actions cell): opens 560px right-side detail Sheet for that row (Sheet from shadcn/ui with side="right").

### Status Badge — 5 Variants (`p2p-campaign-status-badge` renderer)

| PageStatus | CampaignTypeKind | Badge Label | Icon | BG hex | Text hex |
|------------|------------------|-------------|------|--------|----------|
| Active OR Published | TIMED or OCCASION | "Active" | dot (filled circle) | #f0fdf4 | #16a34a |
| Active OR Published | ALWAYS_ACTIVE | "Always Active" | infinity (Lucide) | #eff6ff | #2563eb |
| Closed | (any) | "Completed" | check-circle (Lucide) | #f0fdf4 | #15803d |
| Draft | (any) | "Draft" | pencil-square (Lucide) | #fefce8 | #a16207 |
| Archived | (any) | "Archived" | archive (Lucide) | #f1f5f9 | #64748b |

Renderer location: `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/p2p-campaign-status-badge.tsx`. Hex values constants inside renderer (data-driven exception per UI uniformity directive — same pattern as Reconciliation #14 brand-badge).

### Progress Cell — `p2p-progress-cell` renderer

Inputs (from row): `totalRaised` (decimal), `goalAmount` (decimal?), `campaignTypeKind` (string), `pageStatus` (string).

Display logic:
- If `campaignTypeKind === 'ALWAYS_ACTIVE'` OR `goalAmount IS NULL OR === 0` → render `—` (em-dash, slate text)
- If `pageStatus === 'Draft' AND totalRaised === 0` → render `—`
- Else: compute `pct = totalRaised / goalAmount * 100`, render:
  - Progress bar (height 6px, slate-200 track, rounded)
  - Fill: green #22c55e if pct ≥ 75 / amber #f59e0b if 50 ≤ pct < 75 / red #dc2626 if pct < 50
  - Below bar: `{pct.toFixed(1)}%` (font 0.75rem, weight 600)
  - If pct ≥ 100: prepend 🔥 emoji and tint percent text green (#16a34a)
  - If pct > 999: cap display at "999+%"

Renderer location: `shared-cell-renderers/p2p-progress-cell.tsx`. Hex values in constants inside renderer.

### Campaign Name Link — `campaign-name-link` renderer

Inputs (from row): `campaignName` (string), `slug` (string).
Display: `<a>` tag rendered as accent (teal) bold link with hover underline. Click bubbles to row-click handler (opens drawer). No `href` (drawer is JS-only); use `cursor: pointer`. Truncate at 32 chars with title tooltip.

Renderer location: `shared-cell-renderers/campaign-name-link.tsx`.

### Detail Sheet (Drawer) — 560px right-side, 6 sections

**Component**: `p2p-campaign-detail-sheet.tsx` using shadcn `<Sheet side="right">` with class `w-[560px] sm:max-w-[560px]`.

**Header**: Campaign name (h2, slate-900) + status badge + close button. Below header: slug as muted text + Edit button (deep-link to #170) + View Page button (opens public URL in new tab).

**Data sources**:
- Existing `GetP2PCampaignPageById(p2pCampaignPageId)` — full record projection
- Existing `GetP2PCampaignPageStats(p2pCampaignPageId)` — performance metrics
- Existing `GetP2PCampaignPageLeaderboard(p2pCampaignPageId, topN: 5)` — Top Fundraisers list
- NEW (to ADD inside drawer-only): Recent donors via existing `GetP2PCampaignPageStats` — confirm projection. If NOT projected, ADD to handler per ISSUE-2 (5-line Append, see §⑫)

**6 Sections** (vertical scroll, sticky drawer header):

1. **Campaign Summary card** (border, rounded, padding 16):
   - Slug pill with copy button (clipboard icon, copies `{baseUrl}/p2p/{slug}` — toast on copy)
   - Campaign Type chip (TIMED/OCCASION/ALWAYS_ACTIVE — colored)
   - Created date (relative + absolute on hover)
   - Published date (only if PublishedAt NOT NULL)
   - Archived date (only if ArchivedAt NOT NULL)
   - Goal: `{goalAmount}` or "Always Active — no fixed goal"
   - Raised: `{totalRaised}` (bold)
   - Progress bar (full-width, color-tier same logic as grid renderer)
   - Days Remaining (computed) OR "Always Active" OR "Completed N days ago" OR "Archived"

2. **Performance Metrics — 4-tile grid card**:
   - Total Donors (with avatar dots row of last 5)
   - Total Fundraisers (with link "View all →" → #135 deep-link)
   - Active Fundraisers (sub-caption: "/  {totalFundraisers}")
   - Pending Approvals — amber tint card if > 0, with caption "Action needed — click to review" → opens #135 filtered to pending

3. **Top Fundraisers card** (list, top 5 from leaderboard):
   - Rank medal (🥇🥈🥉 for 1-3, plain "{n}." for 4-5)
   - Avatar (initials gradient bg)
   - Name + email muted underneath
   - Raised amount (bold)
   - %-of-personal-goal (small caption — e.g., "640%")
   - Footer link: "View all {totalFundraisers} fundraisers →"  → `/crm/p2pfundraising/p2pfundraiser?campaignPageId={id}`
   - Empty state: "No fundraisers yet"

4. **Recent Donors card** (list, top 5 from recentDonors projection):
   - Avatar (initials OR anon icon)
   - Name (or "Anonymous")
   - Amount (right-aligned, bold)
   - Time-ago caption (relative — e.g., "2 hours ago")
   - Optional message preview (1-line, truncated, muted)
   - Empty state: "No donations yet"

5. **Communication Settings preview card** (read-only):
   - 3 rows: Confirmation Email / WhatsApp Donation Alerts / Goal Milestone Alerts
   - Each row: label + value-or-OFF + Edit link → `/setting/publicpages/p2pcampaignpage?id={id}&tab=communication`

6. **Quick Actions card** (4 vertical buttons stacked):
   - Edit Campaign Setup → `/setting/publicpages/p2pcampaignpage?id={id}`
   - View Dashboard → `/crm/p2pfundraising/p2pfundraiser?campaignPageId={id}`
   - View Public Page → `{baseUrl}/p2p/{slug}` in new tab
   - Copy Public URL → clipboard with toast

**Drawer empty state** (when GetP2PCampaignPageById returns 404): "Campaign not found. It may have been deleted." + Close button.

**Drawer loading state**: 6 skeleton cards matching layout.

### Duplicate Confirm Modal

**Component**: `duplicate-p2p-campaign-modal.tsx` using shadcn `<Dialog>`.

**Title**: "Duplicate P2P Campaign?"
**Body**: "Create a draft copy of **{campaignName}**? The new campaign will start in Draft status with a new slug like '{slug}-copy'. Donors and fundraisers will NOT be copied — you can re-publish after customizing." (campaign name in bold; slug example shown via JS preview)
**Buttons**: Cancel (outline, slate) / Confirm Duplicate (solid, teal/accent)
**On Confirm**: invokes `duplicateP2PCampaignPage(p2pCampaignPageId)` → BE returns new id → toast: "Campaign duplicated as Draft" → refresh grid + summary → close modal → does NOT auto-navigate (admin clicks new row + Edit if they want to customize)
**Error toast on BE failure**: red toast with BE message (e.g., "Slug counter exceeded 99 copies — please rename original first")

### Delete Confirm Modal

**Component**: `delete-p2p-campaign-modal.tsx` using shadcn `<Dialog>` (red destructive variant).

**Title**: "Delete P2P Campaign?"
**Body**: "Delete **{campaignName}**? This Draft will be permanently removed and cannot be recovered." (campaign name in bold)
**Buttons**: Cancel (outline, slate) / Confirm Delete (solid red `bg-red-600`)
**On Confirm**: invokes `deleteP2PCampaignPage(p2pCampaignPageId)` → BE returns success bool → toast: "Campaign deleted" → refresh grid + summary → close modal
**Error toast on BE failure**: red toast with BE message — most likely "Only Draft campaigns can be deleted; this campaign is {Status}" or "Cannot delete: campaign has {N} fundraisers attached"

### User Interaction Flow

1. Admin loads `/crm/p2pfundraising/p2pcampaign` → sees ScreenHeader + 4 KPI widgets + 5 chips + 10-col grid (paginated)
2. Admin types in search → 300ms debounce → grid filters via `searchTerm` arg
3. Admin clicks chip "Active" → grid filters via `statuses=['Active','Published']`; widget counts DO NOT change (KPIs are global)
4. Admin clicks a grid row (outside Actions) → 560px drawer slides in from right with 6 sections + 3 sub-queries fire (byId, stats, leaderboard)
5. From drawer, admin clicks "Edit Campaign Setup" → navigates to `/setting/publicpages/p2pcampaignpage?id={id}` (#170)
6. From drawer, admin clicks "Copy Public URL" → clipboard copy + toast
7. Admin clicks row Action "Dashboard" → navigates to `/crm/p2pfundraising/p2pfundraiser?campaignPageId={id}` (#135, filtered)
8. Admin clicks row Action "Duplicate" → Duplicate confirm modal → Confirm → BE clone → toast + grid refresh
9. Admin clicks row Action "Delete" (Draft only) → Delete confirm modal → Confirm → BE soft-delete → toast + grid refresh
10. Admin clicks header "+ Create P2P Campaign" → deep-link to `/setting/publicpages/p2pcampaignpage?mode=new` (#170 Create mode)

### Page Widgets Already Stamped Above

**Grid Layout Variant**: `widgets-above-grid` → FE Dev uses **Variant B** (mandatory; see ContactType #19 precedent for double-header bug)

### Grid Aggregation Columns

All projected fields (`totalRaised`, `totalDonors`, `totalFundraisers`, `activeFundraisers`, `pendingApprovals`, `lastDonationAt`) are ALREADY computed by the existing `GetAllP2PCampaignPageList` handler via 2 batched GROUP BY queries (no N+1). No new aggregation logic needed.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Canonical reference for this sub-pattern: **P2PFundraiser #135** (drawer-only FLOW with reused parent entity).

| Concept | This Screen Value | Canonical Reference (#135 P2PFundraiser) |
|---------|-------------------|------------------------------------------|
| Entity name | `P2PCampaignPage` (REUSED — exists) | `P2PFundraiser` (REUSED — exists) |
| Entity file path | `Base.Domain/Models/DonationModels/P2PCampaignPage.cs` (exists) | `Base.Domain/Models/DonationModels/P2PFundraiser.cs` (exists) |
| Entity lower-camel | `p2pCampaignPage` | `p2pFundraiser` |
| Entity kebab | `p2p-campaign-page` | `p2p-fundraiser` |
| Schema | `fund` | `fund` |
| Group / Decorator | `DecoratorDonationModules.P2PCampaignPage` (exists) | `DecoratorDonationModules.P2PFundraiser` (exists) |
| BE module | `DonationModels` | `DonationModels` |
| BE business folder | `Base.Application/Business/DonationBusiness/P2PCampaignPages/` (exists — extend with new queries/commands) | `Base.Application/Business/DonationBusiness/P2PFundraisers/` |
| BE schemas file | `Base.Application/Schemas/DonationSchemas/P2PCampaignPageSchemas.cs` (exists — append SummaryDto) | `Base.Application/Schemas/DonationSchemas/P2PFundraiserSchemas.cs` |
| BE mappings | `DonationMappings.cs` (exists — append clone config) | `DonationMappings.cs` (exists) |
| BE queries endpoint | `Base.API/EndPoints/Donation/Queries/P2PCampaignPageQueries.cs` (exists — append GetP2PCampaignSummary) | same file (#135 appends to it too) |
| BE mutations endpoint | `Base.API/EndPoints/Donation/Mutations/P2PCampaignPageMutations.cs` (exists — append Duplicate/Delete) | same file (#135 appends to it too) |
| FE FOLDER | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/p2pfundraising/p2pcampaign/` (NEW) | `.../crm/p2pfundraising/p2pfundraiser/` (planned, not yet built) |
| FE route | `crm/p2pfundraising/p2pcampaign` | `crm/p2pfundraising/p2pfundraiser` |
| FE entityCamel | `p2pCampaign` (NOT `p2pCampaignPage` — FE-side simplification) | `p2pFundraiser` |
| FE DTO file | `src/dto/donation-domain/P2PCampaignPageDto.ts` (NEW — mirror BE schema) | `src/dto/donation-domain/P2PFundraiserDto.ts` |
| FE GQL Q file | `src/services/graphql/queries/donation/P2PCampaignPageQuery.ts` (NEW) | `src/services/graphql/queries/donation/P2PFundraiserQuery.ts` |
| FE GQL M file | `src/services/graphql/mutations/donation/P2PCampaignPageMutation.ts` (NEW) | `src/services/graphql/mutations/donation/P2PFundraiserMutation.ts` |
| Menu code | `P2PCAMPAIGN` | `P2PFUNDRAISER` |
| Parent menu | `CRM_P2PFUNDRAISING` (MenuId=263) | `CRM_P2PFUNDRAISING` |
| Module code | `CRM` | `CRM` |
| OrderBy in parent | `1` | `2` |
| Page config | `src/page-config/crm/p2pfundraising/p2pcampaign/index.tsx` (NEW) | `.../p2pfundraising/p2pfundraiser/index.tsx` |
| Entity-operations block | `P2PCAMPAIGN` block in `donation-service-entity-operations.ts` (NEW) | `P2PFUNDRAISER` block (planned) |
| GridType | `FLOW` | `FLOW` |
| GridFormSchema | `NULL` (no form on this screen) | `NULL` |
| Sample data | NONE — #170 already seeded sample rows | NONE — #170 already seeded fundraisers |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer + DBA seed-author
> Exact paths — DO NOT guess.

### BACKEND — NEW FILES (4)

| # | File Path | Purpose |
|---|-----------|---------|
| 1 | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/P2PCampaignPages/Queries/GetP2PCampaignSummary.cs` | Cross-campaign KPI rollup for 4 widgets + 5 chip counts |
| 2 | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/P2PCampaignPages/Commands/DuplicateP2PCampaignPage.cs` | Clone command — new Draft with slug-counter |
| 3 | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/P2PCampaignPages/Commands/DeleteP2PCampaignPage.cs` | Soft-delete with 3 guard rules |
| 4 | `PSS_2.0_Backend/sql-scripts-dyanmic/P2PCampaign-sqlscripts.sql` | DB seed (menu + caps + grid + grid fields; NO MasterData; NO sample data) — **preserve `dyanmic` typo** |

### BACKEND — MODIFIED FILES (3)

| # | File Path | Change |
|---|-----------|--------|
| 1 | `PSS_2.0_Backend/.../Schemas/DonationSchemas/P2PCampaignPageSchemas.cs` | APPEND `P2PCampaignSummaryDto` class (11 properties — see §⑩) |
| 2 | `PSS_2.0_Backend/.../EndPoints/Donation/Queries/P2PCampaignPageQueries.cs` | APPEND `GetP2PCampaignSummary` method (4-line wrapper around mediator.Send) |
| 3 | `PSS_2.0_Backend/.../EndPoints/Donation/Mutations/P2PCampaignPageMutations.cs` | APPEND `DuplicateP2PCampaignPage` + `DeleteP2PCampaignPage` methods |

### BACKEND — WIRING NOT NEEDED

- DbContext: `P2PCampaignPages` DbSet already registered by #170
- Mapster: extends existing `DonationMappings.cs` only if Duplicate needs explicit ignore-config (likely NO — Mapster `Adapt<>` defaults will suffice; ADD config block only if FK navigation properties accidentally clone)
- DecoratorProperties: `P2PCampaignPage` already declared
- Migration: **NONE** — entity unchanged

### FRONTEND — NEW FILES (~15)

| # | File Path | Purpose |
|---|-----------|---------|
| 1 | `PSS_2.0_Frontend/src/dto/donation-domain/P2PCampaignPageDto.ts` | TS mirror of BE `P2PCampaignPageResponseDto` + `P2PCampaignSummaryDto` + minimal types |
| 2 | `PSS_2.0_Frontend/src/services/graphql/queries/donation/P2PCampaignPageQuery.ts` | GQL queries — getAllP2PCampaignPageList / getP2PCampaignSummary / getP2PCampaignPageById / getP2PCampaignPageStats / getP2PCampaignPageLeaderboard (re-export of existing or local copy) |
| 3 | `PSS_2.0_Frontend/src/services/graphql/mutations/donation/P2PCampaignPageMutation.ts` | GQL mutations — duplicateP2PCampaignPage / deleteP2PCampaignPage |
| 4 | `PSS_2.0_Frontend/src/page-config/crm/p2pfundraising/p2pcampaign/index.tsx` | Page config exporting `P2PCampaignPageConfig` for ScreenHeader title/icon/breadcrumb |
| 5 | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/p2pfundraising/p2pcampaign/index-page.tsx` | Variant B index-page (ScreenHeader + widgets + 5 chips + DataTableContainer showHeader=false) |
| 6 | `.../crm/p2pfundraising/p2pcampaign/p2p-campaign-widgets.tsx` | 4 KPI widget cards |
| 7 | `.../crm/p2pfundraising/p2pcampaign/p2p-campaign-detail-sheet.tsx` | 560px right-side detail drawer (6 sections) |
| 8 | `.../crm/p2pfundraising/p2pcampaign/duplicate-p2p-campaign-modal.tsx` | Duplicate confirm modal |
| 9 | `.../crm/p2pfundraising/p2pcampaign/delete-p2p-campaign-modal.tsx` | Delete confirm modal |
| 10 | `.../crm/p2pfundraising/p2pcampaign/p2p-campaign-store.ts` | Zustand store (selected id, drawer open, modal open, search, chip) |
| 11 | `.../crm/p2pfundraising/p2pcampaign/index.ts` | Barrel export |
| 12 | `.../custom-components/data-tables/shared-cell-renderers/campaign-name-link.tsx` | NEW renderer |
| 13 | `.../shared-cell-renderers/p2p-progress-cell.tsx` | NEW renderer (similar but distinct from RecurringDonationSchedule recurring-amount) |
| 14 | `.../shared-cell-renderers/p2p-campaign-status-badge.tsx` | NEW renderer with 5 visual variants |
| 15 | `PSS_2.0_Backend/sql-scripts-dyanmic/P2PCampaign-sqlscripts.sql` | (listed above under BE) |

### FRONTEND — MODIFIED FILES (~7)

| # | File Path | Change |
|---|-----------|--------|
| 1 | `src/app/[lang]/crm/p2pfundraising/p2pcampaign/page.tsx` | OVERWRITE 5-line stub → import + render page config |
| 2 | `src/presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` | Export 3 new renderers |
| 3 | `src/presentation/components/custom-components/data-tables/advanced-data-table/registry/advanced-data-table-column-types.tsx` | Register 3 new column type cases |
| 4 | `src/presentation/components/custom-components/data-tables/basic-data-table/registry/basic-data-table-column-types.tsx` | Register 3 new column type cases |
| 5 | `src/presentation/components/custom-components/data-tables/flow-data-table/registry/flow-data-table-column-types.tsx` | Register 3 new column type cases |
| 6 | `src/services/entity-operations/donation-service-entity-operations.ts` | APPEND `P2PCAMPAIGN` block (read+duplicate+delete operations, mirrors RECONCILIATION block from #14) |
| 7 | `src/presentation/components/page-components/crm/p2pfundraising/index.ts` | Append `p2pcampaign` barrel re-export |

### FRONTEND — WIRING NOT NEEDED

- Sidebar: already DB-driven (P2PCAMPAIGN seeded by this screen's SQL, MenuId=263 parent already exists)
- Routes: `crm/p2pfundraising/p2pcampaign/page.tsx` already exists as stub

---

## ⑨ Approval Config (DB Seed)

> **Consumer**: DBA / Seed-author + Project Manager (final review)
> Values pre-filled from MODULE_MENU_REFERENCE.md.

```yaml
MenuCode: P2PCAMPAIGN
MenuName: P2P Campaigns
MenuUrl: crm/p2pfundraising/p2pcampaign
ParentMenuCode: CRM_P2PFUNDRAISING  # MenuId=263 — already exists
ModuleCode: CRM
OrderBy: 1                          # Sibling P2PFUNDRAISER #135 will be OrderBy=2
IsLeastMenu: true
GridType: FLOW
GridFormSchema: NULL                 # No form on this screen — modals & deep-links only
Capabilities:                        # 6 caps (mirror P2PFundraiser #135 + Duplicate + Publish)
  - READ                             # View list, widgets, drawer
  - WRITE                            # Create-link (deep-link to #170 setup); used implicitly via #170
  - DELETE                           # Delete Draft only
  - DUPLICATE                        # Clone-to-Draft
  - PUBLISH                          # Optional — for any future "publish from list" inline action
  - ARCHIVE                          # Optional — for any future "archive from list" inline action
Roles:
  BUSINESSADMIN: [READ, WRITE, DELETE, DUPLICATE, PUBLISH, ARCHIVE]
# Other roles: PROGRAMOFFICER / FINANCEOFFICER / CRMOFFICER / VOLUNTEER / FIELDOFFICER / DONOR
# left ungranted by default per /plan-screens Token Optimization Directive — admin
# adds via Role Capability Setup if needed.
SampleData: NONE — #170 already seeded sample published P2PCampaignPage rows
MasterData: NONE — campaign lifecycle is a string enum on entity, not a MasterData lookup
GridFields: 10 (matches §⑥ grid columns exactly)
```

### GridFields Seed (10 rows)

| OrderBy | GridFieldName | FieldKey | DataType | IsVisible | IsSortable | Width | GridComponentName |
|---------|---------------|----------|----------|-----------|-----------|-------|-------------------|
| 1 | Campaign Name | campaignName | string | true | true | auto | campaign-name-link |
| 2 | Status | pageStatus | string | true | true | 130 | p2p-campaign-status-badge |
| 3 | Goal | goalAmount | decimal | true | true | 100 | (none — inline currencyFormat) |
| 4 | Raised | totalRaised | decimal | true | true | 110 | text-bold |
| 5 | Progress | progressPercent | decimal | true | false | 130 | p2p-progress-cell |
| 6 | Fundraisers | totalFundraisers | int | true | true | 90 | (none) |
| 7 | Donors | totalDonors | int | true | true | 90 | (none) |
| 8 | Start Date | startDate | date | true | true | 110 | DateOnlyPreview |
| 9 | End Date | endDate | date | true | true | 110 | DateOnlyPreview |
| 10 | Actions | — | — | true | false | 220 | — (per-row inline JSX) |

---

## ⑩ BE→FE Contract

> **Consumer**: Frontend Developer (GQL queries/mutations + TS types) + Backend Developer (handler return types)

### Existing GraphQL Fields (REUSE — already wired by #170)

| GQL Field Name | BE Handler | Args | Returns |
|----------------|------------|------|---------|
| `getAllP2PCampaignPageList` | GetAllP2PCampaignPageListHandler | (gridFeatureRequest, statuses: [String!]) | PaginatedApiResponse<P2PCampaignPageResponseDto[]> |
| `getP2PCampaignPageById` | GetP2PCampaignPageByIdHandler | (p2PCampaignPageId: Int!) | BaseApiResponse<P2PCampaignPageResponseDto> |
| `getP2PCampaignPageStats` | GetP2PCampaignPageStatsHandler | (p2PCampaignPageId: Int!) | BaseApiResponse<P2PCampaignPageStatsDto> |
| `getP2PCampaignPageLeaderboard` | GetP2PCampaignPageLeaderboardHandler | (p2PCampaignPageId: Int!, topN: Int!) | BaseApiResponse<LeaderboardEntryDto[]> |

### NEW GraphQL Fields (TO ADD)

| GQL Field Name | BE Handler | Args | Returns |
|----------------|------------|------|---------|
| `getP2PCampaignSummary` | GetP2PCampaignSummaryHandler (NEW) | (none — tenant from HttpContext) | BaseApiResponse<P2PCampaignSummaryDto> |
| `duplicateP2PCampaignPage` | DuplicateP2PCampaignPageHandler (NEW) | (p2PCampaignPageId: Int!) | BaseApiResponse<Int> (returns new id) |
| `deleteP2PCampaignPage` | DeleteP2PCampaignPageHandler (NEW) | (p2PCampaignPageId: Int!) | BaseApiResponse<Boolean> |

### NEW DTOs

**P2PCampaignSummaryDto** (append to `P2PCampaignPageSchemas.cs`):

```csharp
public class P2PCampaignSummaryDto
{
    public int AllCount { get; set; }
    public int ActiveCount { get; set; }
    public int CompletedCount { get; set; }
    public int DraftCount { get; set; }
    public int ArchivedCount { get; set; }
    public int TotalCount { get; set; }            // alias for AllCount; KPI 1 subtitle
    public int TotalFundraisers { get; set; }
    public int ActiveFundraisers { get; set; }
    public decimal TotalRaised { get; set; }       // YTD across all P2P donations
    public decimal AvgPerFundraiser { get; set; }
    public decimal TopFundraiserAmount { get; set; }
}
```

### TS DTO Mirror (`src/dto/donation-domain/P2PCampaignPageDto.ts`)

```typescript
export interface P2PCampaignSummaryDto {
  allCount: number;
  activeCount: number;
  completedCount: number;
  draftCount: number;
  archivedCount: number;
  totalCount: number;
  totalFundraisers: number;
  activeFundraisers: number;
  totalRaised: number;
  avgPerFundraiser: number;
  topFundraiserAmount: number;
}

export interface P2PCampaignPageGridRow {
  p2PCampaignPageId: number;
  campaignId: number;
  campaignName: string;          // from Campaign.CampaignName projection
  slug: string;
  pageStatus: string;            // "Draft" | "Published" | "Active" | "Closed" | "Archived"
  campaignTypeKind: string;      // "TIMED" | "OCCASION" | "ALWAYS_ACTIVE"
  goalAmount: number | null;
  totalRaised: number;
  totalDonors: number;
  totalFundraisers: number;
  activeFundraisers: number;
  pendingApprovals: number;
  startDate: string | null;
  endDate: string | null;
  publishedAt: string | null;
  archivedAt: string | null;
  // Full P2PCampaignPageResponseDto fields available too (drawer projection)
}
```

### Important: GraphQL Nullable-Array Rule

Per user memory `feedback_fe_query_nullability_must_match_be.md`:
- BE `string[]? statuses` → GraphQL nullable input `[String!]` (NOT `[String]`)
- FE query variable MUST be declared `$statuses: [String!]` — if FE declares `[String]`, HotChocolate rejects at runtime
- Apply to: `getAllP2PCampaignPageList` query

---

## ⑪ Acceptance Criteria

> **Consumer**: Testing Agent (validation) + User (final QA)

### Backend
- [ ] `GetP2PCampaignSummary` returns all 11 fields, correctly tenant-scoped, no N+1 (single round-trip via subqueries/projections)
- [ ] `DuplicateP2PCampaignPage` creates new P2PCampaignPage + new Campaign rows with correct PageStatus='Draft', PublishedAt=NULL, ArchivedAt=NULL, slug-counter logic for up to 99 copies, returns new id
- [ ] `DuplicateP2PCampaignPage` does NOT clone P2PFundraisers, GlobalDonations, P2PFundraiserTeams, P2PFundraiserMilestones (clean Draft)
- [ ] `DeleteP2PCampaignPage` rejects non-Draft with BadRequestException + clear message
- [ ] `DeleteP2PCampaignPage` rejects when P2PFundraisers exist + clear message
- [ ] `DeleteP2PCampaignPage` rejects when GlobalDonations exist + clear message
- [ ] `DeleteP2PCampaignPage` soft-deletes (IsDeleted=true) on success, returns true
- [ ] All 3 new BE handlers authorized via `[CustomAuthorize(DecoratorDonationModules.P2PCampaignPage, ...)]` with correct Permission
- [ ] `dotnet build` succeeds with 0 errors in P2PCampaignPages folder

### Frontend
- [ ] Page loads at `/{lang}/crm/p2pfundraising/p2pcampaign`
- [ ] Variant B layout — NO double-header (post-build grep: `<DataTableContainer.*showHeader={false}`)
- [ ] 4 KPI widgets show correct counts from `getP2PCampaignSummary`
- [ ] 5 chips show counts; clicking each filters grid via `statuses` arg
- [ ] Search input debounces 300ms and triggers BE refetch
- [ ] All 10 grid columns render in mockup order; renderers resolve (3 new + reused text-bold + DateOnlyPreview)
- [ ] Per-row inline action button set varies correctly by status (Active/AlwaysActive/Completed/Archived/Draft)
- [ ] Row click opens 560px drawer with all 6 sections populated
- [ ] Drawer Top Fundraisers section fetches from existing `getP2PCampaignPageLeaderboard?topN=5`
- [ ] Drawer "View all fundraisers" link routes to `/crm/p2pfundraising/p2pfundraiser?campaignPageId={id}`
- [ ] Drawer "Edit Campaign Setup" routes to `/setting/publicpages/p2pcampaignpage?id={id}`
- [ ] Drawer "View Public Page" opens `/p2p/{slug}` in NEW TAB
- [ ] Drawer "Copy Public URL" copies to clipboard + toast
- [ ] Duplicate confirm modal calls BE and refreshes list+summary on success
- [ ] Delete confirm modal calls BE and shows BE error message on failure (e.g., non-Draft / has fundraisers / has donations)
- [ ] Pagination 10/25/50/100; default 10
- [ ] Empty state (zero campaigns) shows Create P2P Campaign CTA
- [ ] Filtered empty state shows Clear Filters button
- [ ] Loading state shows skeleton (NO raw "Loading..." string)
- [ ] Error state shows red banner + retry button

### UI Uniformity (post-build grep checks — all 0 matches expected)
- [ ] 0 inline hex in `style={{...}}` under `page-components/crm/p2pfundraising/p2pcampaign/` (allow data-driven status-badge BRAND_MAP constants)
- [ ] 0 inline px in `style={{...}}` (use Tailwind utilities)
- [ ] 0 raw `Loading...` strings (use shadcn Skeleton)
- [ ] 0 `fa-*` className refs (use Lucide / Phosphor icons)
- [ ] 0 inline-hex skeleton background

### DB Seed
- [ ] Menu visible at `CRM > P2P Fundraising > P2P Campaigns` in sidebar (DB-driven)
- [ ] Grid resolves all 10 GridField rows
- [ ] BUSINESSADMIN role has 6 capabilities granted
- [ ] Seed SQL idempotent — re-run inserts ZERO rows on second execution (NOT EXISTS gates)

### Cross-Screen
- [ ] From #15 row Action "Dashboard" → lands on #135 P2PFundraiser grid filtered to current campaign (URL `?campaignPageId={id}`)
- [ ] From #15 row Action "Edit" → lands on #170 P2PCampaignPage setup at correct tab (default Tab 1)
- [ ] From #15 row Action "View Page" → opens public surface `/p2p/{slug}` in new tab (DOES NOT replace current tab)
- [ ] From #15 header "+ Create P2P Campaign" → lands on #170 P2PCampaignPage setup in Create mode (`?mode=new`)
- [ ] After Duplicate: new Draft row appears at top of grid (sorted by CreatedDate DESC default)
- [ ] After Delete: row disappears from grid, summary chip counts update

---

## ⑫ Special Notes & Known Issues

> **Consumer**: PM (review) + Developers (heads-up)

### NEW Module Warning
- NONE — `fund.P2PCampaignPages` already exists; `DonationModels` group, `fund` schema, `DecoratorDonationModules.P2PCampaignPage` all wired

### Pre-Build Issues to Flag

**ISSUE-1 — MED — Multi-currency in TotalRaised**
KPI "Total Raised (P2P) — This year" sums `fund.GlobalDonations.NetAmount` across all currencies without conversion. If tenant uses multi-currency, this number is mathematically incorrect. **Mitigation**: V1 caps at USD-display (mockup uses $ implicitly); add disclaimer tooltip in KPI widget — "Aggregated in default currency; multi-currency conversion in V2." **Fix path**: V2 add per-row ExchangeRate join → BaseAmount column sum, mirrors Donation Dashboard #124 pattern. Document in build-log §12.

**ISSUE-2 — LOW — Recent Donors projection may not exist in GetP2PCampaignPageStats**
Drawer Section 4 requires top-5 recent donors. Existing `GetP2PCampaignPageStatsQuery` may not project a `RecentDonors` array (only aggregates). **Fix**: BE developer to add 5-line projection inside `GetP2PCampaignPageStatsHandler.Handle()` —
```csharp
var recentDonors = await dbContext.GlobalDonations
    .Where(g => g.P2PCampaignPageId == query.P2PCampaignPageId && !g.IsDeleted)
    .OrderByDescending(g => g.CreatedDate).Take(5)
    .Select(g => new { g.ContactId, g.IsAnonymous, g.NetAmount, g.CreatedDate, g.DonorName })
    .ToListAsync(cancellationToken);
```
Then add `RecentDonors` property to `P2PCampaignPageStatsDto`. **Fall-back**: if not implemented, drawer Section 4 shows "Recent donors panel coming soon" — SERVICE_PLACEHOLDER style.

**ISSUE-3 — LOW — Slug counter cap at 99**
DuplicateP2PCampaignPage uses incremental counter (`-copy`, `-copy-2`, ..., `-copy-99`). At 100+, BE throws BadRequestException. **Mitigation**: error message guides admin to rename original. Reality: 100 copies of same campaign is implausible. **Fix path**: switch to short-UUID suffix if real-world usage encounters this — defer to V2.

**ISSUE-4 — LOW — Active+Always-Active count overlap in chip "Active"**
Chip "Active" filter sends `statuses=['Active','Published']` to BE. Always-Active campaigns (CampaignTypeKind='ALWAYS_ACTIVE') share PageStatus='Active', so they appear under the Active chip — correct UX behavior, but admin may expect a separate Always-Active chip. **Decision**: keep mockup spec (4 chips: All/Active/Completed/Draft/Archived) — Always-Active is a visual sub-variant of Active, not a separate filter.

**ISSUE-5 — LOW — Days-Remaining computation locale**
Drawer Section 1 shows "Days Remaining" for Timed campaigns. Computation: `EndDate - NOW()` in days. Server-side preferred (avoids tz drift), but FE computation in user's local timezone is also acceptable since the precision is daily. **Decision**: compute FE-side using `date-fns differenceInCalendarDays` for simplicity; document in build log.

**ISSUE-6 — LOW — Communication Settings preview hard-codes 3 rows out of 8 templates**
Drawer Section 5 shows only 3 representative rows (Confirmation Email / WhatsApp Donation Alerts / Goal Milestone Alerts), not all 8 communication slots. **Rationale**: drawer is for at-a-glance overview, not full communication audit; full settings live at #170 Tab 5 (Edit link in drawer routes there).

**ISSUE-7 — MED — Sidebar menu may already exist if user previously seeded #170's CRM child menu**
Check: `SELECT 1 FROM corg."Menus" WHERE MenuCode = 'P2PCAMPAIGN'`. If exists, seed STEP 1 uses NOT EXISTS gate. **No risk** since seed is idempotent — re-runs are no-op.

**ISSUE-8 — LOW — Duplicate command should bypass Slug filtered-unique constraint via uniqueness loop**
Slug uniqueness is enforced by filtered unique index on `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted`. DuplicateP2PCampaignPage's slug-counter loop must check via `dbContext.P2PCampaignPages.AnyAsync(...)` — DO NOT rely on try/catch on insert (race condition with concurrent duplicates). Pattern: check-then-set inside same transaction, retry up to 99 times, throw BadRequestException at 100+.

**ISSUE-9 — LOW — Campaign duplication may need Campaign.IsActive copying decision**
Underlying `app.Campaigns` row has its own IsActive lifecycle. When duplicating, new Campaign should be IsActive=true (admin can deactivate via Campaign #4 if needed); StartDate/EndDate should be cleared (NULL) so admin sets new dates after Duplicate. **Decision**: clear dates; preserve IsActive=true; copy CampaignName as `[Copy of] {original}`; copy Goal/Description.

**ISSUE-10 — LOW — Dashboard inline action assumes #135 P2PFundraiser implementation supports `campaignPageId` URL filter**
#135 prompt at `prompts/p2pfundraiser.md` declares this filter as part of the campaign-filter ApiSelect. Verify when #135 builds. **Risk**: low — both screens are planned together; FE devs will coordinate via the URL contract.

**ISSUE-11 — LOW — Currency formatting locale**
FE uses Intl.NumberFormat with current locale. Mockup shows USD `$` prefix. If tenant default currency ≠ USD, displayed amount may mismatch admin expectation. **Mitigation**: use tenant's default currency code from session (existing `useCurrentCompany().defaultCurrencyCode`); if absent, fallback USD.

**ISSUE-12 — LOW — Always-Active visual sub-badge nesting in Status renderer**
Status badge renderer must check both `pageStatus` AND `campaignTypeKind`. If `pageStatus IN ('Active','Published') AND campaignTypeKind='ALWAYS_ACTIVE'`, show "Always Active" blue variant; else show "Active" green. Renderer signature: `(row) => JSX.Element` (not just `(value) => JSX`).

**ISSUE-13 — MED — Existing GetAllP2PCampaignPageList does NOT project `campaignName`, `goalAmount`, `startDate`, `endDate` from Campaign join**
Verify: GetP2PCampaignPageByIdHandler.ProjectToResponseDto reads Campaign nav property and projects. The GetAll loop reloads entities WITH Campaign Include. **BUT**: grid display needs these on row. Confirm `P2PCampaignPageResponseDto` exposes `CampaignName / GoalAmount / StartDate / EndDate` fields (it does inherit from RequestDto which has CampaignName/GoalAmount but NOT StartDate/EndDate). **Fix**: APPEND nullable `StartDate` / `EndDate` to ResponseDto + update ProjectToResponseDto in GetP2PCampaignPageByIdHandler to copy them from `entity.Campaign?.StartDate / EndDate`. Confirm during build.

**ISSUE-14 — LOW — DonationMappings.cs may need Mapster ignore-config for Duplicate clone**
When `Adapt<P2PCampaignPage>()` clones, Mapster may attempt to clone navigation properties (P2PFundraisers, P2PFundraiserTeams, etc.) if Include is in scope. **Fix**: load entity via `.AsNoTracking()` without Includes for the clone source; OR add explicit Mapster config `TypeAdapterConfig<P2PCampaignPage, P2PCampaignPage>.NewConfig().Ignore(x => x.P2PFundraisers, x => x.P2PFundraiserTeams, ...)` — confirm during build.

**ISSUE-15 — LOW — Seed folder `sql-scripts-dyanmic/` typo preservation**
Per ChequeDonation #6 ISSUE-15 precedent. Preserve typo. New seed file path: `PSS_2.0_Backend/sql-scripts-dyanmic/P2PCampaign-sqlscripts.sql`.

### Non-Issues / Resolved
- Sidebar menu rendering — DB-driven, no FE config change beyond seed
- View-page rendering — N/A (drawer-only pattern)
- Migration — none needed (entity unchanged)
- Form validation — none (no form on this screen)

### SERVICE_PLACEHOLDERs

None on this screen — all listed UI elements wire to real BE handlers (existing or new). Mockup does NOT show any email/notification/PDF/external-service triggers from this list view; all such actions are deferred to #170 setup or to #135 fundraiser-row actions.

### Scope Discipline Confirmation

Every UI element shown in `p2p-campaign-list.html` is in scope and listed in §⑥/§⑧:
- Page header + "+Create" button — header action
- 4 KPI cards — 4 widgets ⑥/§⑩
- Search input — filter bar ⑥
- 5 filter chips — filter bar ⑥/§⑩
- 10-column table — grid ⑥
- Status badges — `p2p-campaign-status-badge` renderer
- Progress bars + % — `p2p-progress-cell` renderer
- 3 per-row actions × 5 status variants — Actions cell ⑥
- Pagination — FlowDataTable default

The drawer (Sheet) is an *addition* to the mockup — the mockup doesn't show a row-click destination because the mockup's row-click already navigates via the campaign-name link to `p2p-campaign-setup` (which is #170). We add a drawer instead, matching Reconciliation #14 + P2PFundraiser #135 precedent — the campaign-name-link now opens the drawer (informational) while a row Action button "Edit" deep-links to #170 (editing). This is the strongest UX — drawer for monitoring, deep-link for editing.

### Token Optimization Notes for Build Session

- **Skip BA agent spawn** — §①-§⑥ + §⑫ are exhaustive; orchestrator validates against template.
- **Skip Solution Resolver agent** — sub-type stamped (FLOW drawer-only); patterns chosen.
- **Skip UX Architect agent** — §⑥ is the design spec; no new layout decisions needed.
- **BE complexity**: Low (3 new files, 3 modifications; no migration; no new validators)
- **FE complexity**: Medium (Variant B + drawer + 2 modals + 3 renderers — same as P2PFundraiser #135)
- **Parallel BE+FE**: SAFE — no shared contract changes mid-build; DTO is appended on BE then mirrored on FE
- **Total estimated tokens**: ~80-100K for full build (one Opus session)

---

## ⑬ Build Log

### § Sessions

### Session 1 — 2026-05-12 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Backend (sonnet) + Frontend (opus) executed in parallel. Skipped BA / Solution Resolver / UX Architect agent spawns per prompt §⑫ token-optimization directive (prompt was exhaustively pre-analyzed).
- **Files touched**:
  - BE created (4):
    - `Base.Application/Business/DonationBusiness/P2PCampaignPages/Queries/GetP2PCampaignSummary.cs` (created)
    - `Base.Application/Business/DonationBusiness/P2PCampaignPages/Commands/DuplicateP2PCampaignPage.cs` (created)
    - `Base.Application/Business/DonationBusiness/P2PCampaignPages/Commands/DeleteP2PCampaignPage.cs` (created)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/P2PCampaign-sqlscripts.sql` (created — typo `dyanmic` preserved per ChequeDonation #6 precedent)
  - BE modified (4):
    - `Base.Application/Schemas/DonationSchemas/P2PCampaignPageSchemas.cs` (modified — appended `RecentDonorEntryDto`, `RecentDonors` property on `P2PCampaignPageStatsDto`, `P2PCampaignSummaryDto`)
    - `Base.Application/Business/DonationBusiness/P2PCampaignPages/Queries/GetP2PCampaignPageStats.cs` (modified — added top-5 recent donors projection per ISSUE-2)
    - `Base.API/EndPoints/Donation/Queries/P2PCampaignPageQueries.cs` (modified — appended GetP2PCampaignSummary)
    - `Base.API/EndPoints/Donation/Mutations/P2PCampaignPageMutations.cs` (modified — appended DuplicateP2PCampaignPage + DeleteP2PCampaignPage)
  - FE created (13):
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/p2p-campaign-status-badge.tsx` (created)
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/p2p-progress-cell.tsx` (created)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/p2p-campaign-store.ts` (created)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/p2p-campaign-widgets.tsx` (created)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/p2p-campaign-filter-bar.tsx` (created)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/p2p-campaign-grid.tsx` (created)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/p2p-campaign-detail-sheet.tsx` (created)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/duplicate-p2p-campaign-modal.tsx` (created)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/delete-p2p-campaign-modal.tsx` (created)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/index-page.tsx` (created — Variant B)
    - `presentation/components/page-components/crm/p2pfundraising/p2pcampaign/index.tsx` (created — URL router)
    - `presentation/components/page-components/crm/p2pfundraising/index.ts` (created — module barrel)
    - `presentation/pages/crm/p2pfundraising/p2pcampaign.tsx` (created — page-config gatekeeper)
  - FE modified (10):
    - `app/[lang]/crm/p2pfundraising/p2pcampaign/page.tsx` (modified — overwrote UnderConstruction stub)
    - `domain/entities/donation-service/P2PCampaignPageDto.ts` (modified — appended P2PCampaignPageGridRow + P2PCampaignSummaryDto)
    - `infrastructure/gql-queries/donation-queries/P2PCampaignPageQuery.ts` (modified — appended GET_P2P_CAMPAIGN_SUMMARY)
    - `infrastructure/gql-mutations/donation-mutations/P2PCampaignPageMutation.ts` (modified — appended DUPLICATE_P2P_CAMPAIGN_PAGE + DELETE_P2P_CAMPAIGN_PAGE_HARD)
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (modified — exported 2 new renderers)
    - `presentation/components/custom-components/data-tables/advanced/data-table-column-types/component-column.tsx` (modified — registered 2 new cases)
    - `presentation/components/custom-components/data-tables/basic/data-table-column-types/component-column.tsx` (modified — registered 2 new cases)
    - `presentation/components/custom-components/data-tables/flow/data-table-column-types/component-column.tsx` (modified — registered 2 new cases)
    - `presentation/pages/crm/p2pfundraising/index.ts` (modified — appended P2PCampaignPageConfig export)
    - `application/configs/data-table-configs/donation-service-entity-operations.ts` (modified — appended P2PCAMPAIGN block)
  - DB: `PSS_2.0_Backend/sql-scripts-dyanmic/P2PCampaign-sqlscripts.sql` (created)
- **Deviations from spec**:
  - **Grid uses plain HTML table** (not `<FlowDataTable>` / `<DataTableContainer>`) — Reconciliation #14 precedent. Five status-driven Actions sets + em-dash conditional rendering + drawer trigger are awkward inside generic column-config; plain table mirrors Reconciliation's `ReconciliationDetailsTable`. Variant B intent (ScreenHeader + widgets above a single grid block, no nested headers) is preserved; the double-header bug is impossible by construction (no internal grid header to suppress).
  - **2 new renderers instead of 3** — `campaign-name-link` already exists from Screen #30 and is registered in all 3 registries; per `feedback_component_reuse_create.md` (reuse-or-create protocol) it was reused, not duplicated. The grid component renders the name link inline via plain JSX since the page bypasses the registry-driven path; the existing renderer remains available for any future DB-seeded grid that uses `campaign-name-link` as its `GridComponentName`.
  - **`Permissions.Create` used for Duplicate** instead of `Permissions.Write` — `Permissions.Write` does not exist in `DecoratorProperties.cs` (available: Read / Create / Modify / Delete / Toggle). Duplicate creates a new row, so `Create` is the correct semantic.
  - **`Campaign.StartDate` in clone** set to `DateTime.UtcNow` rather than NULL — `Campaign.StartDate` is non-nullable in the entity. Admin resets via #170 Edit after Duplicate.
  - **`RecentDonors.IsAnonymous`** derived as `ContactId == null` — no stored flag on GlobalDonation. Edge case: a donation with a linked Contact whose DisplayName is "Anonymous" will show as non-anonymous. Data-quality matter, not a bug.
  - **`RecentDonors` message source** uses `GlobalDonation.Note` — no dedicated `DonorMessage` field; `Note` is the closest available.
  - **Drawer Edit deep-link Tab routing** — Section 5 sub-link routes to `?tab=communication`; Section 6 Quick Actions "Edit Campaign Setup" routes to default Tab 1. Faithful to §⑥.
  - **Days-Remaining computation** uses native `Date.UTC()` calendar-day math instead of `date-fns differenceInCalendarDays` — avoids adding a dependency; precision is daily per §⑫ ISSUE-5.
  - **KPI currency display** uses `$` prefix — tenant-default currency lookup is V2 per §⑫ ISSUE-11; multi-currency disclaimer tooltip on Total Raised tile.
  - **`DELETE_P2P_CAMPAIGN_PAGE_HARD` constant name** disambiguates from existing `DELETE_P2P_CAMPAIGN_PAGE` (which #170 aliased to soft-archive). New constant is the true hard-delete (Draft only).
- **Known issues opened**:
  - ISSUE-1 (MED) — Multi-currency in TotalRaised / AvgPerFundraiser / TopFundraiserAmount: raw NetAmount aggregation without FX conversion. V2 fix: per-row ExchangeRate join → BaseAmount column sum. Mitigation: UI tooltip discloses approximation. Pre-flagged in prompt.
  - ISSUE-2 (LOW) — Drawer Section 4 currently renders **populated list** (BE fix applied this session) — RESOLVED. Originally flagged as fallback "Recent donors panel coming soon" pre-build; closed by BE session 1.
  - ISSUE-3 (LOW) — Duplicate slug counter capped at 99; BadRequestException at 100+. V2: switch to short-UUID suffix if real-world usage hits it. Pre-flagged.
  - ISSUE-8 (LOW) — Duplicate slug uniqueness uses `LOWER(Slug)` comparison; may not hit #170's filtered unique index `(CompanyId, LOWER(Slug)) WHERE NOT IsDeleted`. Performance acceptable at hundreds-of-pages tenant scale.
  - ISSUE-10 (LOW) — Dashboard inline action assumes #135 P2PFundraiser supports `?campaignPageId=` URL filter. Coordinated via prompt; verify when #135 builds.
  - ISSUE-DUPLICATE-CAPS (NEW LOW) — BE flagged that the DB seed references `DUPLICATE`/`PUBLISH`/`ARCHIVE` capability codes. If `auth.Capabilities` doesn't already have these rows, the menu-capability inserts will fail. Add the 3 rows defensively before running seed (BE provided the INSERT snippet).
  - ISSUE-BE-FE-HANDSHAKE (NEW LOW) — Page will load and render before BE deploys, but `getP2PCampaignSummary` / `duplicateP2PCampaignPage` / `deleteP2PCampaignPage` calls will GraphQL-error until BE is live. UI gracefully degrades (widgets show "—"; modal toasts error). E2E acceptance requires BE deployed.
  - ISSUE-PUBLIC-BASE-URL (NEW LOW) — Public page URLs use `process.env.NEXT_PUBLIC_PUBLIC_PAGE_BASE_URL` with `window.location.origin` fallback. Verify env var is set in deploy configs.
  - ISSUE-TS-PRE-EXISTING (NEW LOW) — 3 pre-existing TS errors in `domain/entities/index.ts` (PageLayoutOption duplicate export) and `crm/communication/emailsendjob/{EmailConfiguration,RecipientFilterDialog}.tsx` (SaveFilterParams mismatch). NOT introduced by this build; flagged so they aren't attributed to #15.
- **Known issues closed**:
  - ISSUE-2 — RecentDonors projection added inline this session (BE).
  - ISSUE-13 — StartDate/EndDate already exposed by #170; verified no work needed.
  - ISSUE-14 — Mapster clone-isolation resolved via `.AsNoTracking()` + manual property copy (no ignore-config required).
  - ISSUE-15 — `sql-scripts-dyanmic/` typo preserved as required.
- **Next step**: User runs (1) seed defensive `auth.Capabilities` INSERTs for DUPLICATE/PUBLISH/ARCHIVE if missing → (2) `psql … -f P2PCampaign-sqlscripts.sql` → (3) `dotnet build` (BE Sonnet session reported 0 errors) → (4) `pnpm dev` and full E2E test per prompt §⑪ (page load + 4 KPIs + 5 chips + 10-col grid + per-row actions × 5 status variants + drawer 6 sections + Duplicate modal happy path + Delete modal guard paths × 3 + deep-links to #170/#135/public page in new tab).

### § Known Issues

| ID | Severity | Description | Status |
|----|----------|-------------|--------|
| ISSUE-1 | MED | Multi-currency in TotalRaised / AvgPerFundraiser / TopFundraiserAmount (raw NetAmount sum without FX conversion) | OPEN (V2) |
| ISSUE-2 | LOW | RecentDonors projection on P2PCampaignPageStatsDto | CLOSED Session 1 |
| ISSUE-3 | LOW | Duplicate slug counter capped at 99 | OPEN (V2) |
| ISSUE-8 | LOW | Duplicate slug check may not hit filtered unique index | OPEN |
| ISSUE-10 | LOW | Dashboard action assumes #135 supports `?campaignPageId=` filter | OPEN (verify when #135 builds) |
| ISSUE-13 | LOW | StartDate/EndDate on ResponseDto | CLOSED (no work needed) |
| ISSUE-14 | LOW | Mapster clone-isolation | CLOSED via .AsNoTracking() |
| ISSUE-15 | LOW | sql-scripts-dyanmic typo preservation | CLOSED |
| ISSUE-DUPLICATE-CAPS | LOW | Seed references DUPLICATE/PUBLISH/ARCHIVE capability codes | OPEN — defensive INSERT before seed |
| ISSUE-BE-FE-HANDSHAKE | LOW | New GQL fields need BE deployment before page is fully functional | OPEN — coordinate deploy |
| ISSUE-PUBLIC-BASE-URL | LOW | Public page URLs depend on NEXT_PUBLIC_PUBLIC_PAGE_BASE_URL env | OPEN — verify deploy config |
| ISSUE-TS-PRE-EXISTING | LOW | 3 pre-existing TS errors in unrelated files | OPEN — not introduced by #15 |

---

## End of Prompt
