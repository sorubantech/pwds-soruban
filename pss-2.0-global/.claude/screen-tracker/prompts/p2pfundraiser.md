---
screen: P2PFundraiser
registry_id: 135
module: CRM (P2P Fundraising)
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-05-10
completed_date: 2026-05-13
last_session_date: 2026-05-13
session_count: 2
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (3 mockups: `p2p-fundraiser-list.html` is THIS screen; `p2p-fundraiser-form.html` + `p2p-fundraiser-page.html` are owned by EXTERNAL_PAGE #170 P2PCampaignPage)
- [x] Existing code reviewed — `P2PFundraiser` entity + EF config + Schemas already shipped by #170 (DonationModels group); 5 lifecycle commands (Approve/Reject/Pause/Resume/FeatureToggle) already wired in `P2PCampaignPageMutations.cs`; FE route is a 5-line `UnderConstruction` stub at `[lang]/crm/p2pfundraising/p2pfundraiser/page.tsx`
- [x] Drawer-only FLOW pattern selected (Reconciliation #14 precedent — NO `?mode=new/edit/read` view-page; "+ Invite Fundraiser" opens a modal; row-click opens a 520px right-side `<Sheet>` detail panel; "Edit Page" admin-action deep-links to #170 P2PCampaignPage editor — this screen is the **management surface**, not the page editor)
- [x] Business rules + lifecycle re-confirmed (Draft → Pending → Active → Paused → Completed; Reject is terminal; Resume re-opens Paused; admin Invite creates Pending row + tokenized magic-link email via SERVICE_PLACEHOLDER)
- [x] FK targets resolved (paths + GQL queries verified — all FKs already wired from #170 build)
- [x] File manifest computed (3 NEW BE queries + 3 NEW BE commands + extend existing endpoints; full FE build over the stub)
- [x] Approval config pre-filled (MenuCode=`P2PFUNDRAISER`, ParentMenu=`CRM_P2PFUNDRAISING`, URL=`crm/p2pfundraising/p2pfundraiser`)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt is exhaustively pre-analyzed; orchestrator validates against §① §② §④ §⑤ rather than re-running BA agent)
- [x] Solution Resolution complete (FLOW-with-drawer-only confirmed, scope = admin-management-grid only — page-content editing belongs to #170)
- [x] UX Design finalized (Variant B header + 4 KPI widgets + 5 chips + 10-col grid + 520px right-side detail Sheet + Invite Fundraiser modal)
- [x] User Approval received (2026-05-13 — single-session BE+DB+FE in parallel, Reconciliation #14 / Refund #13 precedent)
- [x] Backend code generated          ← 3 queries (GetAllP2PFundraiserList / GetP2PFundraiserSummary / GetP2PFundraiserDetailById — renamed from GetP2PFundraiserById per existing-endpoint collision) + 3 commands (InviteP2PFundraiser / UpdateP2PFundraiserAdmin — renamed / SendMessageToP2PFundraiser) + 6 DTO blocks + 1 inner DTO RecentDonationDto + 1 inner DTO P2PFundraiserSocialShareCountsDto in P2PFundraiserSchemas.cs + Mapster configs added in DonationMappings.cs + extended P2PCampaignPageQueries.cs + P2PCampaignPageMutations.cs
- [x] Backend wiring complete         ← Mapster mappings + 1 EF migration `Add_P2PFundraiser_AdminInviteAudit` (2 nullable cols InvitedBy + InvitationEmailSentAt on fund.P2PFundraisers); NO IDonationDbContext change
- [x] Frontend code generated         ← Variant B index-page + 4 KPI widgets + 5 chips + Invite Fundraiser modal + Reject Reason modal + Send Message modal + Detail Sheet (520px right-side) + Zustand store + DTO + GQL Q/M + page-config + 3 NEW shared cell renderers (fundraiser-cell, progress-cell, fundraiser-status-badge) + currency-amount-bold registry alias
- [x] Frontend wiring complete        ← entity-operations P2PFUNDRAISER block (non-entity aliases) + 3 column-type registries + shared-cell-renderers barrel + pages barrel + page-components barrel + DTO barrel + GQL queries barrel + GQL mutations barrel + route stub OVERWRITTEN
- [x] DB Seed script generated        ← `sql-scripts-dyanmic/P2PFundraiser-sqlscripts.sql` (typo preserved). Idempotent NOT EXISTS gates. Menu @ P2PFUNDRAISER under CRM_P2PFUNDRAISING OrderBy=2. 9 capabilities (READ/WRITE→MODIFY mapped/DELETE/APPROVE/REJECT/PAUSE/RESUME/INVITE/ISMENURENDER — 1 extra vs prompt's 8, per Refund-sqlscripts.sql precedent). BUSINESSADMIN role grants. Grid FLOW + GridFormSchema=NULL + 10 sett.Fields + 10 sett.GridFields. No MasterData, no sample data.
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/{lang}/crm/p2pfundraising/p2pfundraiser` (replaces UnderConstruction stub)
- [ ] Variant B layout renders: ScreenHeader + 4 KPI widgets + DataTableContainer with `showHeader={false}`
- [ ] **4 KPI widgets**: Total Fundraisers (with Active sub-count) / Total Raised by Fundraisers (with Avg per Fundraiser) / Avg Donors per Fundraiser (with Top sub-stat) / Pending Approval (amber tint, "Need attention" sub-stat)
- [ ] **5 status filter chips**: All / Active / Pending Approval / Paused / Completed — counts come from `P2PFundraiserSummary` query, not client-side filter
- [ ] **Search input**: by fundraiser name OR email (server-side via `searchTerm` arg)
- [ ] **Campaign filter select**: ApiSelect populated by existing `p2pCampaignPages` query (cross-tenant for BUSINESSADMIN); All Campaigns is the default
- [ ] **Sort filter select**: 4 options — Most Raised (default) / Most Donors / Most Recent / Alphabetical (server-side via `sortBy` arg)
- [ ] **10-column grid** in pixel-perfect order: Fundraiser (avatar+name+email cell) / Campaign / Goal / Raised (bold) / Progress (%-bar with color tier + 🔥 emoji over 100%) / Donors / Status (badge) / Registered / Page Views / Actions
- [ ] **Pending rows visually tinted amber** (`pending-row` class equivalent — bg `#fffbeb` hover `#fef3c7`)
- [ ] **Team rows** (`FundraiserType=TEAM`) render with rounded-square avatar (not circle) + "5 members" badge + Status badge variant `team` (blue) + Members button instead of Pause button
- [ ] **Per-row inline actions** (right-aligned, click stops propagation):
  - Active: View Page (opens public child URL `/p2p/{parentSlug}/{slug}` in NEW TAB) / Edit (deep-links to #170 setup at `setting/publicpages/p2pcampaignpage?id={P2PCampaignPageId}&tab=fundraisers`) / Send Message (opens Send Message modal) / Pause (PauseP2PFundraiser mutation + toast)
  - Pending: Approve (green; ApproveP2PFundraiser + toast) / Reject (red; opens Reject Reason modal) / Preview (opens public child URL in NEW TAB)
  - Paused: View Page / Resume (green; ResumeP2PFundraiser + toast)
  - Completed: View Page only (other actions disabled)
  - Team: Members (opens future Team Members panel — SERVICE_PLACEHOLDER toast for now: "Team Members panel coming soon")
- [ ] **Row click** (anywhere outside actions cell) → opens 520px right-side detail Sheet
- [ ] **Detail Sheet** (mockup-matching, 6 sections):
  1. Profile — avatar (initials, gradient bg) + name + email + phone + parent campaign chip + RegisteredAt
  2. Page URL — copy-to-clipboard button (`pss2.com/p2p/{parentSlug}/{slug}` from props/env BaseUrl)
  3. Performance — 3 metric tiles (Raised with %; Donors; Page Views) + 2 perf items (Goal; Conversion Rate computed = DonorCount / PageViewCount)
  4. Shares — 4 channel chips (Facebook / WhatsApp / Email / Twitter) — counts from `SocialShareCountsJson` if present, else show "—" placeholder (SERVICE_PLACEHOLDER — share-tracking not wired)
  5. Recent Donors — top-5 donations table (Donor name link OR "Anonymous" / Amount / Date / Message) — projected from `fund.GlobalDonations WHERE P2PFundraiserId={id} ORDER BY CreatedDate DESC LIMIT 5`
  6. Admin Actions — vertical list of 5 buttons (Send Message → modal / Edit Page → deep-link to #170 / Pause Page → PauseP2PFundraiser / Feature on Campaign Page → FeatureP2PFundraiserToggle / View Contact Profile → deep-link to `crm/contact/contact?id={ContactId}`)
- [ ] **Invite Fundraiser modal** (opens from "+ Invite Fundraiser" header button):
  - Fields: Campaign (ApiSelect, required, p2pCampaignPages where Status='Published' or 'Active') / Fundraiser Name (text, required) / Email (text, required, email format) / Phone (text, optional) / Personal Goal (number, required, default = parent's `DefaultPersonalGoal`) / Greeting Message (textarea, optional, default template-text shown as placeholder)
  - On Submit: invokes `InviteP2PFundraiser` command which (1) upserts `crm.Contact` by email, (2) creates `P2PFundraiser` row with Status=`Pending` + auto-generated slug from name + RegisteredAt=NOW, (3) emits SERVICE_PLACEHOLDER for invitation email with magic-link token (toast: "Invitation queued — email sent to {email}")
  - Validation: email must not already have an Active fundraiser on the same campaign (BadRequestException)
- [ ] **Reject Reason modal**: textarea (required, ≥10 chars) + Cancel + Confirm Reject (red); calls `RejectP2PFundraiser(id, reason)`; closes drawer if open; refreshes list + summary
- [ ] **Send Message modal**: Channel toggle (Email / WhatsApp) + Subject (Email only, required) + Body (textarea, required, ≥20 chars) + Send button; calls `SendMessageToP2PFundraiser(id, channel, subject, body)` → SERVICE_PLACEHOLDER toast: "Message queued for delivery"
- [ ] **Per-row Approve action** auto-fires `ApproveP2PFundraiser(id)` with optimistic UI; on success refreshes list + summary; pending row tint clears; status badge flips to Active
- [ ] **Pause / Resume** mutations refresh list + summary; status badge updates immediately
- [ ] **Feature toggle** (drawer admin action) refreshes drawer state — featured fundraisers should sort to top of leaderboard on parent page (BE concern, not UI)
- [ ] **Pagination**: 10/25/50/100 per page; default 10; standard FlowDataTable behavior (cursor or offset both fine — match existing FLOW screens)
- [ ] **Empty state**: when 0 fundraisers across all campaigns → "No fundraisers yet — invite supporters to start raising" + Invite Fundraiser CTA
- [ ] **Filtered empty state**: when chip/search/campaign yields 0 → "No fundraisers match your filters" + Clear Filters button
- [ ] **Loading state**: skeleton rows in grid + skeleton tiles in 4 KPI widgets (NO raw "Loading..." string)
- [ ] **Error state**: red banner + retry button if any of the 3 queries error
- [ ] DB Seed — admin menu visible at `CRM > P2P Fundraising > P2P Fundraisers` (route `crm/p2pfundraising/p2pfundraiser`), grid + chips + actions all functional against the 3 sample fundraisers seeded by #170
- [ ] **5 UI uniformity grep checks PASS**:
  - 0 inline hex in `style={{...}}` outside designated renderers
  - 0 inline px in `style={{...}}` outside designated renderers
  - 0 raw `Loading...` strings (use Skeleton)
  - 0 `fa-*` className refs (use Lucide icons)
  - 0 inline-hex skeleton background

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: P2PFundraiser
Module: CRM (P2P Fundraising sub-module — sibling of P2PCampaign #15, MatchingGift #11, Crowdfunding #16)
Schema: `fund`
Group: DonationModels

Business: This is the **admin cross-campaign management grid** for individual peer-to-peer fundraisers. Where #15 P2PCampaign and #170 P2PCampaignPage manage the parent campaign setup (story / branding / payment methods / approval mode) and shipping the public landing page, this screen #135 lets a BUSINESSADMIN see and act on **every supporter who registered as a fundraiser** across **every active P2P campaign**, in one unified surface. The mockup is a 4-KPI-widget header (Total Fundraisers / Total Raised / Avg Donors / Pending Approval) over a 10-column grid (Fundraiser avatar+name+email / Campaign / Goal / Raised / Progress / Donors / Status / Registered / Page Views / Actions) with 5 status chips (All / Active / Pending / Paused / Completed), search by name/email, campaign filter, sort filter (Most Raised / Most Donors / Most Recent / Alphabetical), and a 520px right-side slide-out detail panel shown on row click. Each row supports inline workflow actions matched to the row's current status: Active → View Page / Edit / Send Message / Pause; Pending → Approve / Reject / Preview; Paused → View Page / Resume; Completed → View Page only; Team rows → Members action instead of Pause. The **+ Invite Fundraiser** header button opens a modal that lets the admin invite a supporter by email to fundraise for a specific campaign — this creates a Pending fundraiser row + sends a magic-link invitation email (SERVICE_PLACEHOLDER until email infra wired). The **Edit** action does NOT load an inline editor; it deep-links to the parent #170 P2PCampaignPage setup screen (`setting/publicpages/p2pcampaignpage?id={P2PCampaignPageId}&tab=fundraisers`) — the page editor lives there, not here. **Lifecycle** (driven by `P2PFundraiser.FundraiserStatus` string enum already in entity): Draft → Pending → Active → Paused → Completed; Reject is terminal (sets Status=Rejected, hides from default list, archives row). Auto-Completed when parent P2PCampaignPage moves to Closed. **What breaks if mis-set**: pending fundraisers stuck forever if admin doesn't monitor queue (mockup shows "Need attention" sub-stat on Pending widget for this reason); fundraiser paused mid-active-campaign without comms triggers donor-confusion (Send Message hook in detail panel covers this); admin manual-edit on a fundraiser-owned page surface (the Edit action) overwriting supporter's own copy; sort by Most Raised mixing currencies if multi-currency (V2 — defer; mockup shows USD-only). Related screens: parent setup #15 P2PCampaign + #170 P2PCampaignPage (both COMPLETED/PARTIAL), public child page render at `/p2p/{parentSlug}/{slug}` (route already shipped by #170), CRM Contact #19 (View Contact Profile deep-link), Email/WhatsApp Templates (#118/#119 — referenced for invitation + comms when those services come online).

**Why this is a FLOW-with-drawer-only (no view-page) variant**: Reconciliation #14 precedent. The grid + drawer + inline actions cover the entire admin workflow; there is no "edit fundraiser page content" UI to build because that surface lives at #170. Building a `?mode=new/edit/read` view-page here would duplicate #170 and create two-source-of-truth ambiguity. The "+Invite" creates a row via modal; "Edit" deep-links out; "View Page" opens the public surface in a new tab.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **THE ENTITY ALREADY EXISTS** — shipped by #170 P2PCampaignPage build (2026-05-09).
> See `Base.Domain/Models/DonationModels/P2PFundraiser.cs` and `Base.Infrastructure/Data/Configurations/DonationConfigurations/P2PFundraiserConfiguration.cs`.
> **DO NOT** redefine the entity, do NOT create a migration, do NOT touch IDonationDbContext / DonationDbContext / DecoratorDonationModules — those are wired.

Table: `fund."P2PFundraisers"` (already migrated)

**Existing fields** (read-only reference for projections — DO NOT modify):

| Field | C# Type | Notes |
|-------|---------|-------|
| P2PFundraiserId | int | PK |
| P2PCampaignPageId | int | FK → fund.P2PCampaignPages |
| CompanyId | int | tenant scope |
| ContactId | int | FK → corg.Contacts (the supporter) |
| FundraiserType | string(20) | "INDIVIDUAL" \| "TEAM" |
| TeamId | int? | FK → fund.P2PFundraiserTeams |
| IsTeamCaptain | bool | true when team-row member is captain |
| PageTitle | string(200) | the fundraiser's page H1 |
| Slug | string(120) | unique within parent (lower-kebab) |
| PersonalGoal | decimal(18,2) | the supporter's personal target |
| GoalCurrencyId | int | FK → com.Currencies |
| IsGoalVisible | bool | toggles goal display on public page |
| PersonalStory | string? | rich text |
| CoverImageUrl / CoverVideoUrl / ProfilePhotoUrl | string? | media |
| FundraiserStatus | string(20) | **Lifecycle enum**: Draft / Pending / Active / Paused / Rejected / Completed |
| PendingReason / RejectionReason | string? | admin-set notes |
| ApprovedAt / RejectedAt / RegisteredAt | DateTime / DateTime? | audit timestamps |
| UseDefaultDonationAmounts | bool | inherits parent if true |
| CustomAmountChipsJson | string? | jsonb decimals[] (max 8) |
| AllowCustomAmount | bool | — |
| EmployerMatchingEnabled / EmployerCompanyName / EmployerMatchRatio | bool / string? / string? | matching gift opt-in |
| AllowOfflineDonations | bool | — |
| UseDefaultThankYouMessage / CustomThankYouMessage | bool / string? | — |
| SocialShareMessagesJson | string? | jsonb {fb/tw/wa} |
| **RaisedAmount / DonorCount / PageViewCount** | decimal / int / int | **Denormalized aggregates** — already maintained by donation-pipeline events (per #170 spec); §⑥ KPIs and grid columns READ THESE DIRECTLY (no SUM rollup at query time) |
| IsFeaturedOnCampaign | bool | featured flag (sorts to top of leaderboard) |

Navigation properties (use these for `.Include()`):
- `Contact` (CRM contact)
- `P2PCampaignPage` (parent — Include to project parent's `CampaignName` from `Campaign` nav, parent's `Slug`)
- `GoalCurrency`
- `Team` (nullable)

**ENTITY DELTA THIS SCREEN NEEDS** (3 new fields — small additive migration; can ride on a follow-up #170 patch OR we add it ourselves):

| Field | C# Type | Notes |
|-------|---------|-------|
| **PhoneNumber** | string?(50) | shown in detail panel; mockup line `+55 11-99876-5432` — sourced from `Contact.PhoneNumber` if present (read-through), but supporter may have entered a different phone in the wizard. Decision: **PROJECT FROM `Contact.PhoneNumber` — DO NOT add to entity**. (No entity change needed.) |
| **InvitedBy** | int? | UserId of admin who sent Invite. NULL for self-registered. **Add via small migration** — value used in audit log only (not displayed in UI MVP). |
| **InvitationEmailSentAt** | DateTime? | when SERVICE_PLACEHOLDER would have sent the magic-link email. Audit only. **Add via small migration**. |

**MIGRATION DECISION**: Yes — generate a new EF migration `Add_P2PFundraiser_AdminInviteAudit` adding `InvitedBy` (nullable int) + `InvitationEmailSentAt` (nullable DateTime) only. Tiny patch. Idempotent.

**No child entity changes** for this screen.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()`) + Frontend Developer (ApiSelect + drawer projections)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|------------------|----------------|---------------|-------------------|
| P2PCampaignPageId | P2PCampaignPage | `Base.Domain/Models/DonationModels/P2PCampaignPage.cs` | `p2pCampaignPages` | `CampaignName` (via `.Campaign.Name`) | `P2PCampaignPageDto[]` (existing) |
| ContactId | Contact | `Base.Domain/Models/CorgModels/Contact.cs` | `contacts` | `FullName` | `ContactDto[]` |
| GoalCurrencyId | Currency | `Base.Domain/Models/CorgModels/Currency.cs` | `currencies` | `Code` | `CurrencyDto[]` |
| TeamId | P2PFundraiserTeam | `Base.Domain/Models/DonationModels/P2PFundraiserTeam.cs` | (no admin select needed — projected via Include) | `TeamName` | — |
| InvitedBy (NEW) | User | `Base.Domain/Models/CorgModels/User.cs` | (audit only — not selected in UI) | — | — |

**Aggregation source** (for KPI widgets):
- `fund.P2PFundraisers` rows themselves (already-denormalized RaisedAmount/DonorCount/PageViewCount — no rollup query against GlobalDonations needed)
- For "Top Donors per Fundraiser=34" sub-stat: `MAX(DonorCount) FROM P2PFundraisers WHERE CompanyId=@tenant`
- For "Avg per Fundraiser=$538" sub-stat: `AVG(RaisedAmount) FROM P2PFundraisers WHERE CompanyId=@tenant AND FundraiserStatus IN ('Active','Completed')`

**Recent-Donors drawer projection source**:
- `fund.GlobalDonations WHERE P2PFundraiserId=@id ORDER BY CreatedDate DESC LIMIT 5`
- Project: ContactName (NULL → "Anonymous" if `IsAnonymous=true`), Amount, CurrencyCode, CreatedDate, DonorMessage

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer + Frontend Developer

### Lifecycle transitions (server-enforced)

| From | To | Command | Rule |
|------|-----|---------|------|
| Pending | Active | `ApproveP2PFundraiser` (already wired) | sets ApprovedAt=NOW; clears PendingReason; emits welcome email SERVICE_PLACEHOLDER |
| Pending | Rejected | `RejectP2PFundraiser` (already wired) | sets RejectedAt=NOW + RejectionReason (required, ≥10 chars); emits rejection email SERVICE_PLACEHOLDER |
| Active | Paused | `PauseP2PFundraiser` (already wired) | does NOT close donations (banner-only); donor sees "this page is temporarily paused" on public child page |
| Paused | Active | `ResumeP2PFundraiser` (already wired) | clears pause banner |
| (any) | Completed | auto on parent P2PCampaignPage Close | NO command — parent's `ClosePage` cascades |
| (any) | (toggle) | `FeatureP2PFundraiserToggle` (already wired) | flips `IsFeaturedOnCampaign` |

### NEW commands this screen requires

1. **InviteP2PFundraiser**:
   - Inputs: `campaignPageId, fundraiserName, email, phone?, personalGoal, greetingMessage?`
   - Validation:
     - email must match standard email regex
     - personalGoal > 0
     - parent campaign must be in lifecycle Published or Active (BadRequest if Draft/Closed/Archived)
     - email must NOT already have an Active or Pending fundraiser on this same `campaignPageId` (BadRequest with conflict-row id in the message)
   - Behavior:
     - Upsert `crm.Contact` by (CompanyId, Email) — same helper used by #170 public start-fundraiser flow
     - Generate slug from `fundraiserName` (lower-kebab), append `-2` `-3` suffix on collision within parent
     - Insert `P2PFundraiser` row with `FundraiserStatus='Pending'`, `FundraiserType='INDIVIDUAL'`, `RegisteredAt=NOW`, `InvitedBy=currentUserId`, `InvitationEmailSentAt=NOW` (set even if SERVICE_PLACEHOLDER), `PageTitle=fundraiserName + "'s fundraiser"`, `IsGoalVisible=true`, `UseDefaultDonationAmounts=true`, `UseDefaultThankYouMessage=true`, `GoalCurrencyId=parent.PrimaryCurrencyId`
     - Emit SERVICE_PLACEHOLDER comm event → invitation email with magic-link token (token spec: same as #170 supporter activation if that exists, else just send a templated email with the public child URL — fundraiser logs in via separate auth flow)
   - Returns: new `P2PFundraiserId`

2. **UpdateP2PFundraiser** (admin override edit — distinct from supporter's own page-content updates which are owned by #170):
   - Inputs: `p2pFundraiserId, personalGoal?, isGoalVisible?, isFeaturedOnCampaign?, pendingReason?, fundraiserStatus?` (status only as a debug/escape-hatch — normal flow is via lifecycle commands)
   - Used by drawer's per-field admin overrides (V2; MVP only exposes `isFeaturedOnCampaign` toggle via existing `FeatureP2PFundraiserToggle` command — KEEP THIS COMMAND BUT RETAIN MINIMAL SURFACE for V2 pivots)
   - **MVP scope**: build the handler skeleton + Schemas DTO but do NOT wire a UI control yet — existing `FeatureP2PFundraiserToggle` covers MVP needs. Document as V2-ready in §⑫.

3. **SendMessageToP2PFundraiser** (SERVICE_PLACEHOLDER):
   - Inputs: `p2pFundraiserId, channel ('EMAIL' | 'WHATSAPP'), subject?, body`
   - Validation: subject required when channel=EMAIL; body required + ≥20 chars; channel=WHATSAPP requires `Contact.PhoneNumber NOT NULL` (else BadRequest "Contact has no phone number on file")
   - Behavior: insert audit row in `notify.AdminMessageLog` if that table exists, ELSE just emit a structured log entry. Toast back: "Message queued for delivery"
   - Returns: `1` (placeholder — V2 returns log row id)

### NEW queries this screen requires

1. **GetAllP2PFundraiserList** (cross-campaign paginated grid):
   - Args: `pageNumber, pageSize, searchTerm?, campaignPageId?, status? (chip filter), sortBy?, sortDirection?`
   - Output DTO `P2PFundraiserListItemDto`:
     ```
     P2PFundraiserId, P2PCampaignPageId, FundraiserType, IsTeamCaptain, TeamId, TeamName?,
     ContactId, FundraiserName (Contact.FullName), FundraiserEmail (Contact.Email), FundraiserInitials (computed),
     CampaignName (P2PCampaignPage.Campaign.Name), CampaignSlug (P2PCampaignPage.Slug),
     Slug, PageTitle, PersonalGoal, GoalCurrencyId, GoalCurrencyCode,
     RaisedAmount, DonorCount, PageViewCount,
     ProgressPercent (computed = RaisedAmount / PersonalGoal * 100, capped at 999),
     FundraiserStatus, IsFeaturedOnCampaign, RegisteredAt, ApprovedAt?, PausedAt? (derived from FundraiserStatus + LastModifiedDate)
     ```
   - Sort options:
     - `MostRaised` (default) → `ORDER BY RaisedAmount DESC`
     - `MostDonors` → `ORDER BY DonorCount DESC`
     - `MostRecent` → `ORDER BY RegisteredAt DESC`
     - `Alphabetical` → `ORDER BY Contact.FullName ASC`
   - Filters:
     - `status='all'` → no status filter
     - `status='active' | 'pending' | 'paused' | 'completed'` → exact match (case-insensitive map to `FundraiserStatus` enum string)
     - `campaignPageId` → exact match on parent
     - `searchTerm` → `Contact.FullName ILIKE '%term%' OR Contact.Email ILIKE '%term%'`
   - Excludes: rows where `FundraiserStatus='Rejected'` and `FundraiserStatus='Draft'` from default list (admin can opt-in via separate "show rejected" V2 toggle — not in MVP)

2. **GetP2PFundraiserSummary** (4 KPI widget aggregates, tenant-scoped):
   - Args: (none — auto tenant from HttpContext)
   - Output DTO `P2PFundraiserSummaryDto`:
     ```
     TotalFundraisers (COUNT WHERE Status NOT IN ('Rejected','Draft')),
     ActiveFundraisers (COUNT WHERE Status='Active'),
     PausedFundraisers (COUNT WHERE Status='Paused'),
     PendingFundraisers (COUNT WHERE Status='Pending'),
     CompletedFundraisers (COUNT WHERE Status='Completed'),
     TotalRaised (SUM RaisedAmount WHERE Status IN ('Active','Paused','Completed')),
     AverageRaisedPerFundraiser (AVG RaisedAmount WHERE Status IN ('Active','Completed')),
     AverageDonorsPerFundraiser (AVG DonorCount WHERE Status IN ('Active','Completed')),
     TopDonorCount (MAX DonorCount WHERE Status NOT IN ('Rejected','Draft'))
     ```

3. **GetP2PFundraiserById** (drawer projection):
   - Args: `p2pFundraiserId`
   - Output DTO `P2PFundraiserDetailDto`:
     ```
     // All P2PFundraiserListItemDto fields PLUS:
     ContactPhone (Contact.PhoneNumber),
     ParentCampaignSlug, ParentCampaignName,
     PublicPageUrl (computed = "{baseUrl}/p2p/{parentSlug}/{slug}"),
     PendingReason, RejectionReason, ApprovedAt, RejectedAt,
     ConversionRate (computed = DonorCount / PageViewCount when PageViewCount > 0; else 0),
     SocialShareCounts (parsed from SocialShareMessagesJson — V2 placeholder, return zeros for MVP),
     RecentDonations (top-5 GlobalDonations rows projected: ContactName/IsAnonymous, Amount, CurrencyCode, CreatedDate, DonorMessage),
     CanPause (true if Status='Active'),
     CanResume (true if Status='Paused'),
     CanApprove (true if Status='Pending'),
     CanReject (true if Status='Pending'),
     CanFeature (true if Status='Active')
     ```

### General rules

- **Tenant scope**: all queries auto-filter by `CompanyId = currentTenant`; no cross-tenant leak.
- **Authorization**: all 3 NEW commands require Capability `WRITE` on `P2PFUNDRAISER`. All 3 NEW queries require Capability `READ` on `P2PFUNDRAISER`.
- **Soft delete**: existing entity has `IsDeleted` (Entity base) — exclude from all queries.
- **Pagination cap**: pageSize max 100 — guard against abuse.
- **Search debounce on FE**: 300ms.

---

## ⑤ Screen Classification & Pattern Selection

| Aspect | Value | Why |
|--------|-------|-----|
| Screen type | **FLOW** | Inline workflow actions (Approve / Reject / Pause / Resume); transactional admin surface; not a simple master grid |
| FLOW sub-pattern | **drawer-only** (NO `?mode=new/edit/read` view-page) | Reconciliation #14 precedent — entity already exists, no record-creation form to build (Invite is a modal not a page); Edit deep-links to #170 |
| Variant | **Variant B** (ScreenHeader + KPI widgets + DataTableContainer with `showHeader={false}`) | Header has 4 KPI widgets above grid → MUST use Variant B per §⑥ stamp |
| Save model | n/a (no form) — Invite modal is `save-now` (single mutation on Confirm); workflow actions are immediate single-mutation |
| Lifecycle | Draft → Pending → Active → Paused → Completed; Rejected is terminal | already enforced by existing #170 commands |
| Layout variant stamp | `widgets-above-grid` | drives Variant B in BE/FE wiring |

**Pattern checklist** (pre-answered):
- [x] Has KPI widgets above grid? **YES** (4 widgets) → Variant B mandatory, ScreenHeader present, DataTableContainer `showHeader={false}`
- [x] Has chip filter strip? **YES** (5 chips: All/Active/Pending/Paused/Completed)
- [x] Has search? **YES** (server-side `searchTerm` arg)
- [x] Has dropdown filters? **YES** (Campaign + Sort)
- [x] Has per-row inline actions? **YES** (status-driven action set)
- [x] Has slide-out detail drawer? **YES** (520px right-side `<Sheet>`)
- [x] Has add/create modal? **YES** (Invite Fundraiser modal — NOT a separate page)
- [x] Has bulk actions? **NO** (V2 — bulk Approve / bulk Reject for Pending queue could ship later)
- [x] Has new/edit/read view-page route? **NO** (drawer-only)
- [x] Has aggregate columns? **YES** (Progress % computed; Raised vs Goal as bar)
- [x] Has navigation deep-links? **YES** (View Page → public new-tab; Edit → #170 setup; View Contact → CRM contact)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Layout variant: `widgets-above-grid` (Variant B)

### Top-level structure (top to bottom)

```
[ScreenHeader]
  Title: "P2P Fundraisers"
  Subtitle: "Manage individual fundraisers across all peer-to-peer campaigns"
  Actions (right):
    - "+ Invite Fundraiser"  (primary, accent background)  → opens InviteFundraiserModal
    - "Export List"          (outline)                     → SERVICE_PLACEHOLDER toast: "Export coming soon"

[KPI Widget Grid — 4 columns @ lg, 2 cols @ md, 1 col @ sm]
  Widget 1: TotalFundraisersWidget          (icon: Users, blue tint)
    label: "Total Fundraisers"
    value: {summary.totalFundraisers}
    subtitle: "Active: {summary.activeFundraisers}"
  Widget 2: TotalRaisedByFundraisersWidget  (icon: HandHoldingDollar, green tint)
    label: "Total Raised by Fundraisers"
    value: {formatCurrency(summary.totalRaised, 'USD')}
    subtitle: "Avg: {formatCurrency(summary.averageRaisedPerFundraiser, 'USD')}"
  Widget 3: AvgDonorsPerFundraiserWidget    (icon: Users, purple tint)
    label: "Avg Donors per Fundraiser"
    value: {summary.averageDonorsPerFundraiser.toFixed(1)}
    subtitle: "Top: {summary.topDonorCount}"
  Widget 4: PendingApprovalWidget           (icon: Clock, amber tint, BG amber if count>0)
    label: "Pending Approval"
    value: {summary.pendingFundraisers}
    subtitle: "Need attention" (when count>0; else "All caught up")
    onClick → activates "Pending Approval" chip filter

[FilterChips strip — 5 chips, horizontal scroll on mobile]
  All ({summary.totalFundraisers})              ← default active
  Active ({summary.activeFundraisers})
  Pending Approval ({summary.pendingFundraisers}) ← amber tint indicator
  Paused ({summary.pausedFundraisers})
  Completed ({summary.completedFundraisers})

[Filter row — search + 2 selects]
  Search input (300ms debounce, server-side):  "Search by fundraiser name, email..."
  Campaign select (ApiSelect, populated by p2pCampaignPages query, "All Campaigns" default)
  Sort select (4 options): Most Raised | Most Donors | Most Recent | Alphabetical

[DataTableContainer with showHeader={false} — Variant B mandatory]
  10-column grid (FlowDataTable):
    1. Fundraiser    → renderer: fundraiser-cell (avatar circle/square + name link + email)
    2. Campaign      → text (parent campaign name)
    3. Goal          → currency-amount (PersonalGoal in GoalCurrencyCode)
    4. Raised        → currency-amount-bold (RaisedAmount, accent color when ≥100% of goal)
    5. Progress      → renderer: progress-cell (130px-min cell with color-tier bar + % text + 🔥 emoji over 100%)
    6. Donors        → number
    7. Status        → renderer: fundraiser-status-badge (Active green / Pending amber / Paused slate / Completed dark-green / Team blue)
    8. Registered    → date short ("Mar 5")
    9. Page Views    → number with thousand separator
    10. Actions      → renderer: fundraiser-actions-cell (status-driven button set, inline, click stops propagation)

  Row interactions:
    - Click anywhere outside Actions cell → openDetailSheet(p2pFundraiserId)
    - Pending rows: amber row tint (bg #fffbeb hover #fef3c7) — apply via row-class-prop on table
    - Team rows: bold first column + "5 members" badge already inside fundraiser-cell renderer

[FlowDataTable footer]
  - Standard pagination: pageSize selector (10/25/50/100), page nav, total count display
```

### Detail Sheet (right-side, 520px, mockup-pixel-match)

```
[Sheet trigger: row click]
[Sheet width: 520px on lg+; 100vw on mobile]
[Sheet position: right]
[Sheet header (sticky): "Fundraiser Details" + close-X button]

[Body sections, scrollable, padding 1.25rem]

  ── Profile Section ──
    Avatar (56px circle, gradient bg, initials)
    Name (1.125rem, bold)
    Email (with envelope icon, secondary text)
    Phone (with phone icon, secondary text — hide if null)
    Campaign chip (with flag icon, accent color)
    Registered date (with calendar icon, secondary text)

  ── Page URL block ──
    pill-style row: link-icon + URL text (accent color, word-break) + copy-to-clipboard button
    URL = `{publicBaseUrl}/p2p/{parentCampaignSlug}/{slug}`
    publicBaseUrl from env: NEXT_PUBLIC_PUBLIC_BASE_URL (or fallback to current origin)

  ── "Performance" section title (with chart-line icon) ──
    [3 metric tiles in grid-cols-3, bg slate-50, rounded]
      Tile 1: Raised value (accent color) + "Raised ({progressPercent}%)" label
      Tile 2: Donors value + "Donors" label
      Tile 3: Page Views value + "Page Views" label
    [2 perf items in grid-cols-2, bg slate-50, rounded, with icon]
      Item 1: bullseye icon + "Goal: {formatCurrency(goal, currencyCode)}"
      Item 2: percent icon + "Conversion Rate: {conversionRate.toFixed(1)}%"

  ── "Shares" section title (with share-alt icon) ──
    4 channel chips (small bg-slate-50 pills):
      Facebook icon (blue) + count
      WhatsApp icon (green) + count
      Email icon (gray) + count
      Twitter icon (sky) + count
    SERVICE_PLACEHOLDER for MVP: show "—" instead of count if SocialShareCounts not tracked

  ── "Recent Donors" section title (with hand-holding-heart icon) ──
    Mini table (panel-table style):
      Cols: Donor / Amount / Date / Message
      Donor cell: "Anonymous" (no link) when IsAnonymous, else clickable link → /crm/contact/contact?id={ContactId}
      Amount cell: bold
      Message: italic, secondary text, ellipsis at 60 chars
    Empty state: "No donations yet"
    Limit 5 rows; "View all donations" link → /crm/donation/globaldonation?p2pFundraiserId={id} (if filter supported, else just navigate)

  ── "Admin Actions" section title (with shield-halved icon) ──
    Vertical stack of 5 large action buttons (full-width, icon + title + subtitle):
      1. envelope icon → "Send Message" / "Email or WhatsApp to fundraiser"  → opens SendMessageModal
      2. pen-to-square icon → "Edit Page" / "Override fundraiser's page content"  → window.open(`/setting/publicpages/p2pcampaignpage?id={P2PCampaignPageId}&tab=fundraisers&fundraiserId={p2pFundraiserId}`, '_blank')
      3. pause-circle icon → "Pause Page" / "Temporarily disable fundraising page"  → conditional: disabled when not Active; calls PauseP2PFundraiser
      4. star icon (gold when featured) → "Feature on Campaign Page" / "Pin to top of leaderboard"  → toggle FeatureP2PFundraiserToggle; reflects current `isFeaturedOnCampaign` state
      5. address-card icon → "View Contact Profile" / "Navigate to CRM contact record"  → router.push(`/crm/contact/contact?id={ContactId}`)
```

### Modals

#### InviteFundraiserModal (size=md, center)

```
Header: "Invite a Fundraiser"
Body:
  Field 1: Campaign (ApiSelect, required)
    placeholder: "Select campaign..."
    query: p2pCampaignPages
    filter: lifecycle IN ('Published', 'Active') only
    label: parent campaign name
    onChange: also reads parent's DefaultPersonalGoal and PrimaryCurrencyId for downstream defaults
  Field 2: Fundraiser Name (text, required)
    minLength 2, maxLength 100
  Field 3: Email (text, required)
    standard email regex, lowercase normalize
  Field 4: Phone (text, optional)
    placeholder: "+1 555 0100"
  Field 5: Personal Goal (number with currency prefix, required)
    default = parent.DefaultPersonalGoal (after Campaign selected)
    min 1, max 10_000_000
    currency code shown as label suffix ({parentCampaign.PrimaryCurrencyCode})
  Field 6: Greeting Message (textarea, optional)
    rows 4
    placeholder: "Hi {name}, [campaign org] would love to have you fundraise for [campaign name]. Click the link to start your page..."
    if blank, BE uses templated default
Footer:
  Cancel (outline) | Send Invitation (primary, accent color)
```

On Submit:
- Disable Submit button + show inline spinner
- Call `inviteP2PFundraiser` mutation
- On 200: close modal, refresh list + summary, toast green "Invitation sent — fundraiser added in Pending status"
- On 400 (email duplicate): inline error under Email field with link to existing fundraiser drawer
- On 400 (campaign closed): inline error at top of modal

#### RejectReasonModal (size=md, center)

```
Header: "Reject Fundraiser"
Body:
  Inline alert (warning): "This action cannot be undone. The fundraiser will be notified by email."
  Textarea: "Rejection reason" (required, ≥10 chars, ≤500 chars)
    placeholder: "e.g., Story content does not align with our cause..."
Footer:
  Cancel | Confirm Reject (red/destructive)
```

#### SendMessageModal (size=md, center)

```
Header: "Send Message to Fundraiser"
Body:
  Tabs: Email | WhatsApp (radio cards)
    WhatsApp tab disabled with tooltip if Contact.PhoneNumber is null
  Email tab fields:
    Subject (text, required)
    Body (textarea rows=8, required, ≥20 chars)
  WhatsApp tab fields:
    Body (textarea rows=6, required, ≥20 chars, max 1024)
Footer:
  Cancel | Send (primary)
```

### NEW shared cell renderers (3)

Register in: `src/presentation/components/data-tables/shared-cell-renderers/`
Wire into: 3 column-type registries (advanced/basic/flow) + barrel

1. **fundraiser-cell** (`fundraiser-cell.tsx`)
   - Props: `{ name, email, initials, gradientFrom, gradientTo, isTeam, teamMemberCount? }`
   - Renders avatar (circle for individual, rounded-square for team) with gradient bg + initials inside; right side shows name (accent color, semibold) and email (xs, secondary). Team variant appends a small "{N} members" badge.
   - Gradient pairs: deterministic-from-name (hash → palette bucket) so the same fundraiser always has same colors

2. **progress-cell** (`progress-cell.tsx`)
   - Props: `{ raisedAmount, goalAmount, percentText? }`
   - Renders 130px-min stacked: 6px height bar track (bg slate-200) + filled bar with color-tier:
     - over 100% → linear-gradient from green to cyan (with 🔥 emoji suffix on % text)
     - 75-99% → green
     - 40-74% → amber
     - 0-39% → danger red
     - 0% → secondary text gray
   - % text: bold xs, color matches bar tier; "640%" + 🔥 when over

3. **fundraiser-status-badge** (`fundraiser-status-badge.tsx`)
   - Props: `{ status: 'Active'|'Pending'|'Paused'|'Completed'|'Team' }`
   - Renders pill: Active green / Pending amber-with-clock-icon / Paused slate-with-pause-icon / Completed dark-green-with-check-icon / Team blue (passed via prop when row is a team)

### Reused / existing renderers (do NOT recreate)
- currency-amount (Refund #13 / Reconciliation #14)
- donor-link (ChequeDonation #6 / Refund #13) — used in Recent Donors mini-table
- date short formatter (existing util)

### Empty / loading / error states
- Empty (zero-data, no filters): centered illustration + "No fundraisers yet — invite supporters to start raising" + "+ Invite Fundraiser" CTA
- Empty (filtered): centered text + "No fundraisers match your filters" + "Clear Filters" link button
- Loading: 4 KPI tile skeletons + 8 row skeletons
- Error: red inline banner above grid + Retry button + reload trigger

---

## ⑦ Substitution Guide

> **Consumer**: All sub-agents (canonical reference: **Reconciliation** #14 for FLOW-with-drawer-only)

| Variable | Value |
|----------|-------|
| `EntityName` | `P2PFundraiser` |
| `entityCamel` | `p2pFundraiser` |
| `entityKebab` | `p2p-fundraiser` |
| `EntityNamePlural` | `P2PFundraisers` |
| `entityCamelPlural` | `p2pFundraisers` |
| `Schema` | `fund` |
| `Group` | `DonationModels` |
| `Module` | `CRM` |
| `ParentMenuCode` | `CRM_P2PFUNDRAISING` |
| `MenuCode` | `P2PFUNDRAISER` |
| `ModuleCode` | `CRM` |
| `MenuUrl` | `crm/p2pfundraising/p2pfundraiser` |
| `feFolder` | `crm/p2pfundraising/p2pfundraiser` |
| `BackendBusinessFolder` | `Business/DonationBusiness/P2PCampaignPages/{Commands,Queries}` (PIGGYBACK on the existing folder — NEW handlers go alongside the 5 lifecycle commands shipped by #170) |
| `MutationsEndpointFile` | `Base.API/EndPoints/Donation/Mutations/P2PCampaignPageMutations.cs` (extend — do NOT create P2PFundraiserMutations.cs) |
| `QueriesEndpointFile` | `Base.API/EndPoints/Donation/Queries/P2PCampaignPageQueries.cs` (extend — do NOT create P2PFundraiserQueries.cs) |
| `SchemasFile` | `Base.Application/Schemas/DonationSchemas/P2PFundraiserSchemas.cs` (extend — already exists) |

---

## ⑧ File Manifest

> **Consumer**: Backend / Frontend Developer
> **NO new entity, NO new EF config, NO new IDonationDbContext registration.** Entity already wired by #170.

### Backend (NEW files = 6, MODIFIED files = 4, MIGRATION = 1)

**NEW** under `Base.Application/Business/DonationBusiness/P2PCampaignPages/`:
1. `Commands/InviteP2PFundraiser.cs` — `InviteP2PFundraiserCommand` + handler + validator
2. `Commands/UpdateP2PFundraiser.cs` — `UpdateP2PFundraiserCommand` + handler + validator (V2-ready, MVP only updates IsFeaturedOnCampaign — but build the full handler skeleton)
3. `Commands/SendMessageToP2PFundraiser.cs` — `SendMessageToP2PFundraiserCommand` + handler + validator (SERVICE_PLACEHOLDER body)
4. `Queries/GetAllP2PFundraiserList.cs` — `GetAllP2PFundraiserListQuery` + handler (paginated, sortable, filterable)
5. `Queries/GetP2PFundraiserSummary.cs` — `GetP2PFundraiserSummaryQuery` + handler (4 KPI aggregates)
6. `Queries/GetP2PFundraiserById.cs` — `GetP2PFundraiserByIdQuery` + handler (drawer projection with Recent Donations)

**MODIFIED**:
1. `Base.Application/Schemas/DonationSchemas/P2PFundraiserSchemas.cs` — append 6 NEW DTOs:
   - `InviteP2PFundraiserInputDto`
   - `UpdateP2PFundraiserInputDto`
   - `SendMessageToP2PFundraiserInputDto`
   - `P2PFundraiserListItemDto`
   - `P2PFundraiserSummaryDto`
   - `P2PFundraiserDetailDto` (with nested `RecentDonationDto[]`)
2. `Base.Application/Common/Mappings/DonationMappings.cs` — append Mapster `TypeAdapterConfig<P2PFundraiser, P2PFundraiserListItemDto>().NewConfig()` and `<P2PFundraiser, P2PFundraiserDetailDto>().NewConfig()` blocks (handle the FullName concat, ProgressPercent computation, ConversionRate)
3. `Base.API/EndPoints/Donation/Mutations/P2PCampaignPageMutations.cs` — append 3 mutations (`InviteP2PFundraiser`, `UpdateP2PFundraiser`, `SendMessageToP2PFundraiser`)
4. `Base.API/EndPoints/Donation/Queries/P2PCampaignPageQueries.cs` — append 3 queries (`p2pFundraisers`, `p2pFundraiserSummary`, `p2pFundraiserById`)

**MIGRATION** (1 small additive):
- `dotnet ef migrations add Add_P2PFundraiser_AdminInviteAudit -c DonationDbContext` adds 2 nullable columns (`InvitedBy int NULL`, `InvitationEmailSentAt timestamp NULL`).
- Update `P2PFundraiserConfiguration.cs` if needed for the column mappings (mostly inferred — only add if migration-by-attribute fails).

**NO CHANGES** to: IDonationDbContext, DonationDbContext, DecoratorDonationModules, GlobalUsings (entity already registered).

### Frontend (NEW files = 18, MODIFIED files = 8)

**NEW** under `src/presentation/components/page-components/crm/p2pfundraising/p2pfundraiser/`:
1. `index-page.tsx` — Variant B layout root (ScreenHeader + 4 widgets + chips + filter row + DataTableContainer with showHeader={false})
2. `p2p-fundraiser-store.ts` — Zustand store (filter chip, search, campaign, sort, pageNumber, pageSize, openInviteModal, openRejectModal/payload, openSendMessageModal/payload, openDetailSheet/payload)
3. `p2p-fundraiser-widgets.tsx` — 4 KPI tile renderers (Total Fundraisers / Total Raised / Avg Donors / Pending Approval)
4. `p2p-fundraiser-filter-chips.tsx` — 5 chip strip with counts from summary
5. `p2p-fundraiser-toolbar.tsx` — search + Campaign select + Sort select row
6. `p2p-fundraiser-actions-cell.tsx` — status-driven row action button group (Active/Pending/Paused/Completed/Team variants)
7. `p2p-fundraiser-detail-sheet.tsx` — 520px right-side `<Sheet>` with 6 sections (Profile / URL / Performance / Shares / Recent Donors / Admin Actions)
8. `p2p-fundraiser-recent-donors-table.tsx` — mini-table inside detail sheet
9. `p2p-fundraiser-admin-actions.tsx` — vertical 5-button list inside detail sheet
10. `invite-fundraiser-modal.tsx` — modal with Campaign/Name/Email/Phone/Goal/Greeting fields
11. `reject-reason-modal.tsx` — modal with rejection reason textarea
12. `send-message-modal.tsx` — modal with Email/WhatsApp tabs and body
13. `index.ts` — barrel

**NEW** under `src/presentation/components/data-tables/shared-cell-renderers/`:
14. `fundraiser-cell.tsx` — avatar+name+email cell renderer (with team variant)
15. `progress-cell.tsx` — color-tier progress bar with % text and 🔥 emoji
16. `fundraiser-status-badge.tsx` — Active/Pending/Paused/Completed/Team badge variants

**NEW** under `src/presentation/pages/crm/p2pfundraising/`:
17. `p2pfundraiser.tsx` — page-config wrapper (entity-operations consumer)

**NEW** under `src/data/dto/Crm/`:
18. `P2PFundraiserDto.ts` — DTOs mirroring BE Schemas

**NEW** under `src/data/services/graphql/`:
- `Donation/queries/p2pFundraiser.ts` — 3 queries (GetAllP2PFundraiserList, GetP2PFundraiserSummary, GetP2PFundraiserById)
- `Donation/mutations/p2pFundraiser.ts` — 3 mutations (InviteP2PFundraiser, UpdateP2PFundraiser, SendMessageToP2PFundraiser)

**MODIFIED**:
1. `src/app/[lang]/crm/p2pfundraising/p2pfundraiser/page.tsx` — overwrite the `UnderConstruction` stub with `<P2PFundraiserPage />` from page-config wrapper
2. `src/data/services/entity-operations/donation-service-entity-operations.ts` — add `P2PFUNDRAISER` block with non-entity aliases (since the menu code is `P2PFUNDRAISER`)
3. `src/data/services/graphql/Donation/queries/index.ts` — barrel re-export
4. `src/data/services/graphql/Donation/mutations/index.ts` — barrel re-export
5. `src/data/dto/Crm/index.ts` — barrel re-export
6. `src/presentation/pages/crm/p2pfundraising/index.ts` — barrel re-export
7. `src/presentation/components/page-components/crm/p2pfundraising/index.ts` — barrel re-export (if exists, else create)
8. `src/presentation/components/data-tables/shared-cell-renderers/index.ts` — register 3 new renderers
9. `src/presentation/components/data-tables/registries/{advanced,basic,flow}-column-type-registry.tsx` — register 3 renderer keys (`fundraiserCell`, `progressCell`, `fundraiserStatusBadge`)

### DB Seed (1 file)

**NEW**: `sql-scripts-dyanmic/P2PFundraiser-sqlscripts.sql` (preserve folder typo per ChequeDonation #6 precedent)
- STEP 0: Diagnostics (existing menu / capability check)
- STEP 1: Insert menu `P2PFUNDRAISER` under parent `CRM_P2PFUNDRAISING` with OrderBy=2 (NOT EXISTS gate)
- STEP 2: Insert 8 capabilities (`READ`, `WRITE`, `DELETE`, `APPROVE`, `REJECT`, `PAUSE`, `RESUME`, `INVITE`) for menu (NOT EXISTS gate per row)
- STEP 3: BUSINESSADMIN role grants for all 8 capabilities (NOT EXISTS gate per row)
- STEP 4: Grid registration: GridType=`FLOW`, GridFormSchema=NULL
- STEP 5: 10 GridField rows in order matching the column spec (Fundraiser, Campaign, Goal, Raised, Progress, Donors, Status, Registered, PageViews, Actions); each with proper rendererKey + width + sort flag
- STEP 6 (skip): No MasterData seed — `FundraiserStatus` is a string enum on entity, not a MasterData lookup
- STEP 7 (skip): No sample-data seed — #170's seed already inserts 3 sample fundraisers (Sarah Active / Khalid Team-Captain Active / Maria Pending)
- All steps **idempotent** with NOT EXISTS gates

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: Backend Developer (DB seed)

```
ModuleCode:        CRM
ParentMenuCode:    CRM_P2PFUNDRAISING
MenuCode:          P2PFUNDRAISER
MenuName:          P2P Fundraisers
MenuUrl:           crm/p2pfundraising/p2pfundraiser
MenuOrderBy:       2 (sibling of P2PCampaign #15 at OrderBy=1, MatchingGift #11 at OrderBy=3, Crowdfunding #16 at OrderBy=4)
GridType:          FLOW
GridFormSchema:    NULL
DefaultRoles:      [BUSINESSADMIN]
Capabilities:      READ, WRITE, DELETE, APPROVE, REJECT, PAUSE, RESUME, INVITE
```

Capability mapping:
- `READ` → grants visibility on menu + GetAll/GetSummary/GetById queries
- `WRITE` → grants Update / Send Message mutations
- `DELETE` → soft-delete fundraiser (V2 — not exposed in MVP UI)
- `APPROVE` → ApproveP2PFundraiser
- `REJECT` → RejectP2PFundraiser
- `PAUSE` → PauseP2PFundraiser
- `RESUME` → ResumeP2PFundraiser
- `INVITE` → InviteP2PFundraiser (NEW)

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer (DTO + GQL types)

### Queries

```graphql
# 1. GetAllP2PFundraiserList — paginated cross-campaign grid
query GetAllP2PFundraiserList(
  $pageNumber: Int!
  $pageSize: Int!
  $searchTerm: String
  $campaignPageId: Int
  $status: String         # 'all' | 'active' | 'pending' | 'paused' | 'completed'
  $sortBy: String         # 'MostRaised' | 'MostDonors' | 'MostRecent' | 'Alphabetical'
) {
  p2pFundraisers(...) {
    items {
      p2PFundraiserId
      p2PCampaignPageId
      campaignName
      campaignSlug
      slug
      pageTitle
      fundraiserType
      isTeamCaptain
      teamId
      teamName
      contactId
      fundraiserName
      fundraiserEmail
      fundraiserInitials
      personalGoal
      goalCurrencyId
      goalCurrencyCode
      raisedAmount
      donorCount
      pageViewCount
      progressPercent
      fundraiserStatus
      isFeaturedOnCampaign
      registeredAt
      approvedAt
    }
    totalCount
    pageNumber
    pageSize
  }
}

# 2. GetP2PFundraiserSummary — 4 KPI widgets
query GetP2PFundraiserSummary {
  p2pFundraiserSummary {
    totalFundraisers
    activeFundraisers
    pausedFundraisers
    pendingFundraisers
    completedFundraisers
    totalRaised
    averageRaisedPerFundraiser
    averageDonorsPerFundraiser
    topDonorCount
  }
}

# 3. GetP2PFundraiserById — drawer projection
query GetP2PFundraiserById($p2PFundraiserId: Int!) {
  p2pFundraiserById(p2PFundraiserId: $p2PFundraiserId) {
    # all listItem fields PLUS
    contactPhone
    parentCampaignSlug
    parentCampaignName
    publicPageUrl
    pendingReason
    rejectionReason
    rejectedAt
    conversionRate
    socialShareCounts { facebook whatsapp email twitter }
    recentDonations {
      globalDonationId
      donorName
      isAnonymous
      contactId
      amount
      currencyCode
      createdDate
      donorMessage
    }
    canPause
    canResume
    canApprove
    canReject
    canFeature
  }
}
```

### Mutations

```graphql
# 1. InviteP2PFundraiser
mutation InviteP2PFundraiser($input: InviteP2PFundraiserInputDtoInput!) {
  inviteP2PFundraiser(input: $input)  # returns: BaseApiResponse<int>  (new P2PFundraiserId)
}
# input fields: campaignPageId, fundraiserName, email, phone?, personalGoal, greetingMessage?

# 2. UpdateP2PFundraiser (V2-ready; MVP only used by Feature toggle but FeatureP2PFundraiserToggle already exists)
mutation UpdateP2PFundraiser($input: UpdateP2PFundraiserInputDtoInput!) {
  updateP2PFundraiser(input: $input)
}
# input: p2pFundraiserId, personalGoal?, isGoalVisible?, pendingReason?, fundraiserStatus?

# 3. SendMessageToP2PFundraiser
mutation SendMessageToP2PFundraiser($input: SendMessageToP2PFundraiserInputDtoInput!) {
  sendMessageToP2PFundraiser(input: $input)
}
# input: p2pFundraiserId, channel ('EMAIL'|'WHATSAPP'), subject?, body
```

### Existing mutations consumed by this screen (already wired by #170)
- `approveP2PFundraiser(p2PFundraiserId: Int!)`
- `rejectP2PFundraiser(p2PFundraiserId: Int!, reason: String!)`
- `pauseP2PFundraiser(p2PFundraiserId: Int!)`
- `resumeP2PFundraiser(p2PFundraiserId: Int!)`
- `featureP2PFundraiserToggle(p2PFundraiserId: Int!, isFeatured: Boolean!)`

---

## ⑪ Acceptance Criteria

(Captured in detail under the Verification checklist at the top of the file. Highlighted critical items here:)

- All 5 UI uniformity grep checks pass
- Variant B layout (ScreenHeader + showHeader=false on DataTableContainer) — no double-header bug
- 4 KPI widgets read from `p2pFundraiserSummary` (single query, not derived from list page)
- 5 chip filters fire server-side (no client-side filter)
- Search debounces 300ms
- Detail Sheet opens with full data on row click; close on Escape
- Pending row tint visible (amber) — verify via screenshot vs mockup
- Inline action set varies per status (Active vs Pending vs Paused vs Completed vs Team)
- Invite Fundraiser modal: Campaign select fires `p2pCampaignPages` query filtered to Active/Published
- Invite modal blocks duplicate (email already on Active or Pending fundraiser for same campaign)
- Reject reason ≥ 10 chars enforced both client- and server-side
- Send Message → Email requires subject; WhatsApp tab disabled when contact has no phone
- View Page action opens public child URL in NEW tab
- Edit action deep-links to `setting/publicpages/p2pcampaignpage?id={parentId}&tab=fundraisers&fundraiserId={id}` (OPEN IN SAME TAB — leaves admin grid behind)
- Recent Donors table inside drawer projects last 5 GlobalDonations linked by P2PFundraiserId
- Conversion Rate computed client-side or BE? — BE (in P2PFundraiserDetailDto.conversionRate)
- Pagination caps at pageSize=100 server-side
- Migration `Add_P2PFundraiser_AdminInviteAudit` applies cleanly

---

## ⑫ Special Notes & Warnings

### IMPORTANT — entity ownership boundary
The `P2PFundraiser` entity is **owned by #170 P2PCampaignPage** (parent-with-children storage pattern). This screen #135 is a **read-and-act** surface over that entity:
- All entity field changes must originate from the public Start-Fundraiser wizard (#170) or supporter's own page-update flow (#170)
- This screen ONLY adds: cross-campaign list, summary, drawer, Invite (admin-initiated row creation), Update (V2-ready stub), Send Message (SERVICE_PLACEHOLDER)
- DO NOT add page-content fields to the Update mutation here — those belong to #170
- DO NOT recreate the entity, configuration, schemas file (extend the existing one)

### SERVICE_PLACEHOLDERS (3 — wire mock handlers, document in build log)
1. **InviteP2PFundraiser email send** — invitation email with magic-link token. MVP: log a structured event + set `InvitationEmailSentAt=NOW`; UI toast says "Invitation queued — email sent to {email}". Real send wires when `notify.EmailQueue` infra is built (out of scope here).
2. **SendMessageToP2PFundraiser** — admin-to-fundraiser ad-hoc email/WhatsApp. MVP: log event; UI toast "Message queued for delivery". Real send when notify infra wires.
3. **Export List** header button — CSV/Excel export of grid contents. MVP: toast "Export coming soon".

### V2 deferrals (document, do NOT build now)
- Bulk Approve / Bulk Reject for Pending queue (mockup doesn't show bulk controls — keep MVP simple)
- "Show Rejected" toggle to surface rejected fundraisers (filtered out of MVP list)
- Native-currency aware Total Raised KPI (MVP sums in USD, ignoring per-fundraiser currency — flag when multi-currency goes live)
- SocialShareCounts drawer chips (MVP shows "—" placeholder; real counts when share-tracking pipeline ships)
- Featured-fundraiser drag-reorder (MVP only allows toggle; ordering is auto by RaisedAmount)
- Team Members panel (mockup row 6 has "Members" button — MVP shows toast "Team Members panel coming soon"; real impl in V2 when team UX is finalized)
- Admin override edit of fundraiser page content (the `UpdateP2PFundraiser` handler is built BUT no UI control exposes the page-content fields — those edits flow through #170)

### Migration risk (LOW)
- 2 nullable columns added; no data backfill needed; no FK constraint added; safe to re-run migration on populated tables.

### Drawer query strategy
- Drawer triggers a SEPARATE `p2pFundraiserById` query on open (NOT projected from list result) — avoids over-fetching Recent Donations on every row of the list. Confirmed acceptable per Reconciliation #14 precedent.

### Sidebar registration
- Menu `P2PFUNDRAISER` should already be visible in the sidebar from a prior P2P sub-module seed. **VERIFY before assuming the menu exists** — if missing, the seed file ships it. If it exists with wrong OrderBy or wrong Url, the seed must `UPDATE` it (not just NOT EXISTS gate).

### Public URL building (drawer + actions)
- `publicBaseUrl` should come from `process.env.NEXT_PUBLIC_PUBLIC_BASE_URL` (set in env), with `window.location.origin` as runtime fallback. BE composes the URL in `P2PFundraiserDetailDto.publicPageUrl` using `IConfiguration["PublicBaseUrl"]` (sibling pattern from #170 — verify the config key name matches).

### Folder typo preservation
- `sql-scripts-dyanmic/` (with the `dyanmic` typo) is the established convention. DO NOT rename to `dynamic`.

### Build agent notes
- Recommended order: BE migration + handlers FIRST, then DB seed, then FE wiring (FE consumes the new GQL endpoints and renderers depend on them).
- Run `dotnet ef migrations add Add_P2PFundraiser_AdminInviteAudit -c DonationDbContext` BEFORE writing the new column references in handlers — otherwise the handlers will reference fields the model doesn't yet have.
- Verify `P2PCampaignPageMutations.cs` extension stays under ~250 lines; if it grows beyond, split into a `P2PFundraiserMutations.cs` file (BE dev judgment call).

---

## ⑬ Build Log

### § Sessions

### Session 1 — 2026-05-13 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Single-session BE + DB seed + FE in parallel (Reconciliation #14 / Refund #13 precedent). Opus BE + Opus FE; BA / Solution Resolver / UX Architect agent spawns skipped (§①–⑫ exhaustive).
- **Files touched**:
  - **BE (6 created)**:
    - `PSS_2.0_Backend/.../Base.Application/Business/DonationBusiness/P2PFundraisers/Commands/InviteP2PFundraiser.cs` (created)
    - `.../Commands/UpdateP2PFundraiserAdmin.cs` (created)
    - `.../Commands/SendMessageToP2PFundraiser.cs` (created)
    - `.../Queries/GetAllP2PFundraiserList.cs` (created)
    - `.../Queries/GetP2PFundraiserSummary.cs` (created)
    - `.../Queries/GetP2PFundraiserDetailById.cs` (created)
  - **BE (6 modified)**:
    - `.../Base.Domain/Models/DonationModels/P2PFundraiser.cs` (modified — +InvitedBy + InvitationEmailSentAt)
    - `.../Base.Infrastructure/Data/Configurations/DonationConfigurations/P2PFundraiserConfiguration.cs` (modified — explicit Property() for new audit cols)
    - `.../Base.Application/Schemas/DonationSchemas/P2PFundraiserSchemas.cs` (modified — +6 DTOs incl. nested RecentDonationDto + P2PFundraiserSocialShareCountsDto)
    - `.../Base.Application/Mappings/DonationMappings.cs` (modified — +Mapster configs for ListItemDto + DetailDto)
    - `.../Base.API/EndPoints/Donation/Mutations/P2PCampaignPageMutations.cs` (modified — +3 mutations)
    - `.../Base.API/EndPoints/Donation/Queries/P2PCampaignPageQueries.cs` (modified — +3 queries)
  - **BE Migration**: `20260513053035_Add_P2PFundraiser_AdminInviteAudit.cs` + `.Designer.cs` + `ApplicationDbContextModelSnapshot.cs` (modified). ALTER TABLE fund."P2PFundraisers" ADD 2 nullable columns. `-c ApplicationDbContext` (local repo uses single ApplicationDbContext, not DonationDbContext as prompt §⑫ said).
  - **FE (18 created)**:
    - `PSS_2.0_Frontend/src/domain/entities/donation-service/P2PFundraiserAdminDto.ts` (created)
    - `src/infrastructure/gql-queries/donation-queries/P2PFundraiserAdminQuery.ts` (created)
    - `src/infrastructure/gql-mutations/donation-mutations/P2PFundraiserAdminMutation.ts` (created)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/fundraiser-cell.tsx` (created)
    - `.../shared-cell-renderers/progress-cell.tsx` (created)
    - `.../shared-cell-renderers/fundraiser-status-badge.tsx` (created)
    - `src/presentation/pages/crm/p2pfundraising/p2pfundraiser.tsx` (created — page-config wrapper)
    - `src/presentation/components/page-components/crm/p2pfundraising/p2pfundraiser/index-page.tsx` (created — Variant B root)
    - `.../p2pfundraiser/p2p-fundraiser-store.ts` (created — Zustand)
    - `.../p2pfundraiser/p2p-fundraiser-widgets.tsx` (created — 4 KPIs)
    - `.../p2pfundraiser/p2p-fundraiser-filter-chips.tsx` (created — 5 chips)
    - `.../p2pfundraiser/p2p-fundraiser-toolbar.tsx` (created — search + Campaign + Sort)
    - `.../p2pfundraiser/p2p-fundraiser-data-table.tsx` (created — plain HTML table, Reconciliation #14 pattern)
    - `.../p2pfundraiser/p2p-fundraiser-actions-cell.tsx` (created — status-driven actions)
    - `.../p2pfundraiser/p2p-fundraiser-detail-sheet.tsx` (created — 520px right-side Sheet, 6 sections)
    - `.../p2pfundraiser/p2p-fundraiser-recent-donors-table.tsx` (created)
    - `.../p2pfundraiser/p2p-fundraiser-admin-actions.tsx` (created)
    - `.../p2pfundraiser/invite-fundraiser-modal.tsx` (created)
    - `.../p2pfundraiser/reject-reason-modal.tsx` (created)
    - `.../p2pfundraiser/send-message-modal.tsx` (created)
    - `.../p2pfundraiser/index.ts` (created — barrel)
  - **FE (10 modified)**:
    - `src/app/[lang]/crm/p2pfundraising/p2pfundraiser/page.tsx` (modified — overwrote UnderConstruction stub)
    - `src/domain/entities/donation-service/index.ts` (modified — barrel re-export)
    - `src/infrastructure/gql-queries/donation-queries/index.ts` (modified — barrel)
    - `src/infrastructure/gql-mutations/donation-mutations/index.ts` (modified — barrel)
    - `src/presentation/pages/crm/p2pfundraising/index.ts` (modified — P2PFundraiserPageConfig export)
    - `src/presentation/components/page-components/crm/p2pfundraising/index.ts` (modified — P2PFundraiserIndexPage export)
    - `.../shared-cell-renderers/index.ts` (modified — 3 renderer barrel exports)
    - `.../data-tables/advanced/data-table-column-types/component-column.tsx` (modified — +4 cases: fundraiserCell / progressCell / fundraiserStatusBadge / currency-amount-bold)
    - `.../data-tables/basic/data-table-column-types/component-column.tsx` (modified — same 4 cases)
    - `.../data-tables/flow/data-table-column-types/component-column.tsx` (modified — same 4 cases)
    - `src/application/configs/data-table-configs/donation-service-entity-operations.ts` (modified — P2PFUNDRAISER block with non-entity aliases, mirrors RECONCILIATION precedent)
  - **DB**: `PSS_2.0_Backend/.../sql-scripts-dyanmic/P2PFundraiser-sqlscripts.sql` (created — idempotent, 7 STEPs; preserve `dyanmic` typo)
- **Deviations from spec**:
  1. **DbContext**: Prompt §⑫ said `-c DonationDbContext`. Repo uses single `ApplicationDbContext`. Migration ran with the local context.
  2. **Naming collisions**: Existing `UpdateP2PFundraiserCommand` (from #170 with `P2PFundraiserRequestDto` arg) prevented same-name reuse; admin-override renamed to `UpdateP2PFundraiserAdminCommand` (GQL: `updateP2PFundraiserAdmin`). Existing `GetP2PFundraiserByIdQuery` (returns `P2PFundraiserResponseDto`) prevented reuse; drawer-detail renamed to `GetP2PFundraiserDetailByIdQuery` (GQL: `getP2PFundraiserDetailById`).
  3. **Handler folder**: Placed under `P2PFundraisers/` (not `P2PCampaignPages/` as prompt §⑦ said) to match local #170 precedent.
  4. **Contact email/phone**: Prompt §③ named `CorgModels.Contact`; actual path is `ContactModels.Contact`. Email/phone live in child tables `ContactEmailAddresses`/`ContactPhoneNumbers`; JOIN-based lookup used (StartP2PFundraiser #170 pattern).
  5. **GoalCurrencyId source**: Prompt said `parent.PrimaryCurrencyId` on `P2PCampaignPage`; that field doesn't exist. Used `parent.Campaign.GoalCurrencyId` instead.
  6. **RecentDonations.IsAnonymous**: `GlobalDonation` entity has no `IsAnonymous` column — heuristic `(IsIndividualDonation ?? false) == false` used. DonorMessage mapped from `GlobalDonation.Note`.
  7. **Seed capability count**: 9 caps not 8 (added `ISMENURENDER` per Refund-sqlscripts.sql precedent; `WRITE` mapped to existing `MODIFY` per PSS standard taxonomy + added APPROVE/REJECT/PAUSE/RESUME/INVITE rows to `auth."Capabilities"` with NOT EXISTS guard before grant).
  8. **FE GQL field paths**: FE agent wrote against prompt's §⑩ names (`p2PFundraisers`, `p2PFundraiserSummary`, `p2PFundraiserAdminById`); BE agent exposed under method-name camelCase (`getAllP2PFundraiserList`, `getP2PFundraiserSummary`, `getP2PFundraiserDetailById`). Main session patched the 3 FE query strings + the data-table consumer (`data` is array, `totalCount` sibling per `PaginatedApiResponse` Refund #13 precedent).
  9. **FE GQL field cleanup**: removed `teamMemberCount` (not on BE DTO); fixed `whatsapp` → `whatsApp` (HotChocolate camelCase of BE property `WhatsApp`).
  10. **FE grid**: plain HTML `<table>` (Reconciliation #14 / P2PCampaign #15 precedent), not `FlowDataTableContainer`. `showHeader={false}` honored by construction (no internal header rendered). Drawer is Zustand-driven, not URL-routed.
- **Known issues opened (new ISSUEs from this session)**:
  - ISSUE-1 (OPEN, LOW) — Drawer state Zustand-driven, not URL-routed. Deep-linking to a specific drawer (e.g. notification CTA) unsupported in MVP. Future: migrate to `?drawer=<id>` (P2PCampaign #15 pattern).
  - ISSUE-2 (OPEN, LOW) — Seed `actions` GridComponentName doesn't resolve in registries; plain-table grid renders `<P2PFundraiserActionsCell>` directly bypass. Wire only if migrated to FlowDataTableContainer.
  - ISSUE-3 (OPEN, MED) — `IsAnonymous` heuristic via `IsIndividualDonation==false`. Needs explicit `IsAnonymous` boolean column on `GlobalDonation` (V2).
  - ISSUE-4 (OPEN, MED) — `InviteP2PFundraiser` creates Contact with `ContactBaseTypeId=0` + `PrimaryCountryId=0` placeholders (StartP2PFundraiser #170 pattern). Real CRM intake rules + ContactSource attribution + default country from tenant in V2.
  - ISSUE-5 (OPEN, LOW) — Conversion rate scaling: handler returns percentage (e.g. `12.50` for 12.5%); FE renderer consumes as-is. Document if downstream expects 0–1 fraction.
  - ISSUE-6 (OPEN, MED) — `inviteP2PFundraiser` email send SERVICE_PLACEHOLDER — logs structured event + sets `InvitationEmailSentAt=NOW`. Real send when `notify.EmailQueue` infra ships.
  - ISSUE-7 (OPEN, MED) — `sendMessageToP2PFundraiser` SERVICE_PLACEHOLDER — logs event only. Real Email/WhatsApp dispatch when notify infra ships.
  - ISSUE-8 (OPEN, LOW) — Export List header button SERVICE_PLACEHOLDER toast.
  - ISSUE-9 (OPEN, LOW) — `socialShareCounts` chips show "—" placeholder; depends on BE share-tracking pipeline (V2).
  - ISSUE-10 (OPEN, LOW) — Team-row "Members" action SERVICE_PLACEHOLDER toast — full Team Members panel deferred to V2.
- **Known issues closed**: None (all 7 prompt-flagged V2 deferrals remain as documented; ISSUE-15 typo-preservation honored, not "closed" in the bug-tracking sense).
- **Next step**: User runs (1) `dotnet ef database update -c ApplicationDbContext` to apply migration; (2) apply `sql-scripts-dyanmic/P2PFundraiser-sqlscripts.sql`; (3) `dotnet build` full solution; (4) `pnpm dev` + full E2E per §⑪ acceptance criteria (4 KPIs / 5 chips / search / Campaign select / Sort select / 10-col grid / pending row tint / per-status inline actions / row-click drawer / Invite / Reject / Send Message modals / Approve+Pause+Resume mutations / Feature toggle / public child URL new tab / Edit deep-link).

### Session 2 — 2026-05-13 — REFACTOR — COMPLETED

- **Scope**: User directive — "use advanced table or flow table". Replaced the hand-rolled HTML `<table>` (Session 1 deviation #10 / ISSUE-2) with the canonical `FlowDataTable` pipeline (Refund #13 precedent). BE query signature reshaped to the shared `GridFeatureRequest` contract; FE GQL field names corrected to HotChocolate strip-Get convention (`allP2PFundraiserList` / `p2PFundraiserSummary` / `p2PFundraiserDetailById`); DB seed adds a synthetic actions GridField row + sets PK `IsPrimary=false` to suppress the standard `ActionColumnBuilder` (which only supports View/Edit/Delete/Toggle and doesn't fit our 5-status / 7-action workflow); shared `component-column.tsx` registry gets a `p2p-fundraiser-actions` case dispatching to the existing `<P2PFundraiserActionsCell>`.
- **Files touched**:
  - **BE (2 modified)**:
    - `PSS_2.0_Backend/.../Base.Application/Business/DonationBusiness/P2PFundraisers/Queries/GetAllP2PFundraiserList.cs` (modified — `GridFeatureRequest` + `CampaignPageId` + `Status` args; handler computes `skip = pageIndex * pageSize`; sort dispatch keyed on FE field names: `raisedAmount` / `donorCount` / `registeredAt` / `fundraiserName` / `personalGoal` / `progressPercent` / `pageViewCount`)
    - `PSS_2.0_Backend/.../Base.API/EndPoints/Donation/Queries/P2PCampaignPageQueries.cs` (modified — `GetAllP2PFundraiserList` now uses `[AsParameters] GridFeatureRequest request` + `campaignPageId` + `status`)
  - **FE (3 modified, 1 deleted)**:
    - `src/infrastructure/gql-queries/donation-queries/P2PFundraiserAdminQuery.ts` (modified — `request: { pageSize / pageIndex / sortDescending / sortColumn / searchTerm / advancedFilter }` wrap; field names `allP2PFundraiserList` / `p2PFundraiserSummary` / `p2PFundraiserDetailById`)
    - `src/presentation/components/custom-components/data-tables/flow/data-table-column-types/component-column.tsx` (modified — added `case "p2p-fundraiser-actions"` rendering `<P2PFundraiserActionsCell />`)
    - `src/presentation/components/page-components/crm/p2pfundraising/p2pfundraiser/index-page.tsx` (modified — full rewrite to `<FlowDataTableStoreProvider gridCode="P2PFUNDRAISER">` + `<FlowDataTableContainer showHeader={false} />`; 4 effect-mirrors push screen-store → flow-store: chip+campaign→extraVariables, search→setSearchTerm, sort→setSorting, refresh→setRefresh)
    - `.../p2pfundraiser/p2p-fundraiser-data-table.tsx` (DELETED — obsolete after FlowDataTable swap)
  - **DB**: `PSS_2.0_Backend/.../sql-scripts-dyanmic/P2PFundraiser-sqlscripts.sql` (modified — added `P2PF_ACTIONS` synthetic Field row + new GridField row at OrderBy=10 with `GridComponentName='p2p-fundraiser-actions'`; PK GridField row toggled to `IsPrimary=false` with idempotent UPDATE for prior-seed rows; `registeredAt` column upgraded from `'date-short'` to `'DateOnlyPreview'` to use an actually-registered renderer)
- **Deviations from spec**: None new — refactor follows Refund #13 precedent which was already a sibling pattern.
- **Known issues opened**:
  - ISSUE-11 (OPEN, LOW) — Campaign + Status filters travel as top-level `campaignPageId` / `status` GQL args via `extraVariables`. Sort travels via `setSorting` (TanStack shape) which `data-table-fetch-data` translates to `sortColumn`/`sortDescending`. Search travels via `setSearchTerm`. The screen-level store still owns the input UI; effects mirror to the FlowDataTable store. Two stores in flight — acceptable per Refund #13 precedent, but documented for future review.
  - ISSUE-12 (OPEN, LOW) — `number` GridComponentName falls through to the default-case renderer (renders raw `cellValue`) — no thousand-separator formatting. Acceptable degradation vs Session 1's `formatInt`; a global `case "number"` renderer would fix this for every screen.
- **Known issues closed**:
  - ISSUE-2 (CLOSED) — `actions` GridComponentName now resolves via `p2p-fundraiser-actions` case in `component-column.tsx`; DB seed updated accordingly.
  - Session 1 deviation #10 — superseded; FE grid IS now the shared FlowDataTable.
- **Next step**: User runs (1) re-apply `sql-scripts-dyanmic/P2PFundraiser-sqlscripts.sql` (idempotent — adds `P2PF_ACTIONS` Field row + new GridField row + flips PK `IsPrimary` to false on prior-seeded rows); (2) `dotnet build` to confirm BE compiles; (3) `pnpm dev` + smoke-test `/[lang]/crm/p2pfundraising/p2pfundraiser` — grid should render via `<FlowDataTableContainer>`, status-conditional action buttons should appear in the rightmost column for each row, chip + campaign + search + sort still filter correctly.
