---
screen: Campaign
registry_id: 39
module: Organization
status: PROMPT_READY
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-20
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — 3 files: `campaign-list.html` + `campaign-form.html` + `campaign-dashboard.html`
- [x] Existing BE reviewed — entity + 4 commands + 3 queries + mutations + queries endpoints already present (near-greenfield for new fields/children)
- [x] Existing FE reviewed — 31-line `AdvancedDataTable` stub; no view-page, no store, no form, no detail
- [x] Business rules + 5-state workflow extracted (Draft → Active → Paused → Completed → Cancelled, + auto-complete transition)
- [x] FK targets resolved (9 direct FKs + 3 junction tables)
- [x] File manifest computed (BE: ~32 touched / FE: ~27 new files + ~10 modifications)
- [x] Approval config pre-filled (MenuCode=CAMPAIGN, ParentMenu=CRM_ORGANIZATION, OrderBy=2 per MODULE_MENU_REFERENCE)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM — 4 tabs + DETAIL — dashboard with 8 sections)
- [ ] User Approval received
- [ ] Backend code generated (new columns + 5 child entities + 4 new commands + 3 new queries)
- [ ] Backend wiring complete (DbContext DbSets, Mapster, DecoratorApplicationModules already has `CAMPAIGN`)
- [ ] Frontend code generated (view-page with 3 modes + 4-tab FORM + dashboard-style DETAIL + Zustand store)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW; new MasterData typeCodes)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/[lang]/crm/organization/campaign`
- [ ] Grid loads with 11 columns (Campaign Name, Category emoji-badge, Org Unit, Goal, Raised, Progress bar, Donors, Status, Start, End, Actions)
- [ ] 4 KPI widgets render above grid (Active Campaigns / Total Raised Active / Avg Performance / Donors Reached)
- [ ] Filter chip bar works (All / Active / Upcoming / Completed / Draft / Cancelled with live counts)
- [ ] Filter bar: search, OrgUnit dropdown, Category dropdown, date range — all functional
- [ ] Row action buttons vary by status: Draft→Edit+Delete; Upcoming→Edit+Duplicate+Archive+Cancel; Active→Dashboard+Edit+Duplicate+Archive+Cancel; Completed→Dashboard+View+Duplicate+Archive
- [ ] Row click navigates to `?mode=read&id=X` (DETAIL dashboard layout)
- [ ] `?mode=new` — FORM with 4 tabs renders: Basic Info, Story & Content, Goals & Tracking, Settings
- [ ] Tab 2 (Story) — Rich text editor for Full Story, Impact Metrics child grid add/remove works, file upload fields for banner + testimonial photo
- [ ] Tab 3 (Goals) — Currency inputs, Campaign Period with computed Duration, Milestones child grid, Tracking Metrics checkbox grid
- [ ] Tab 4 (Settings) — Recurring Frequencies (toggle + sub-checkboxes), Tax Deductible + Tax Category, 3 Template dropdowns, Campaign Team multi-select, Custom URL, Social Sharing + live preview card
- [ ] Visibility radio (Public/Internal) persists; Linked Donation Purposes multi-select persists
- [ ] Save as Draft sets status=DRAFT; Save & Publish sets status=ACTIVE
- [ ] `?mode=read&id=X` — DETAIL layout renders 8 sections: Goal Progress Hero + 6-KPI strip + Daily Collection bar chart + Donor Breakdown donut + Org Unit table + Payment Method table + Milestone Tracker + Recent Donations Feed + Top Donors Leaderboard
- [ ] Detail header actions: Edit (→ `?mode=edit`), Share Link (SERVICE_PLACEHOLDER), Export Report (SERVICE_PLACEHOLDER)
- [ ] Row actions (Duplicate, Archive, Cancel) trigger correct mutations with confirmation
- [ ] Auto-complete toggle persists; backend date-job simulation noted (SERVICE_PLACEHOLDER)
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] Permissions: Edit/Delete respect BUSINESSADMIN role capabilities
- [ ] DB Seed — menu visible under CRM > Organization > Campaigns (OrderBy=2); MasterData typeCodes CAMPAIGNCATEGORY/CAMPAIGNSTATUS/CAMPAIGNTAXCATEGORY/CAMPAIGNTRACKINGMETRIC seeded
- [ ] Legacy duplicate route at `/[lang]/organization/organizationsetup/campaign/page.tsx` deleted

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Campaign
Module: Organization (accessed via CRM module sidebar — `crm/organization/campaign`)
Schema: `app` (per entity snapshot — see ⑫ for schema discrepancy warning)
Group: `ApplicationModels`
DbContext: `ContactDbContext` (interface: `IContactDbContext`)
Decorator: `DecoratorApplicationModules.Campaign = "CAMPAIGN"` (already registered)

Business: Campaigns are time-bound fundraising initiatives (Annual Appeals, Emergency Relief, Seasonal Drives, Capital Campaigns, Peer-to-Peer) that aggregate donations, pledges, matching gifts, and events toward a specific goal amount within a start-end window. Each campaign belongs to an Organizational Unit (HQ, region, or branch), has a Category and Type (MasterData), supports multiple linked Donation Purposes (multi-select junction), and moves through a 5-state workflow — Draft → Active → Paused → Completed → Cancelled. The list page shows all campaigns with 4 KPI widgets (Active Campaigns / Total Raised / Avg Performance % / Donors Reached), status filter chips, org-unit/category/date filters, and per-row inline progress bars. The **view-page has 3 URL modes and 2 completely different UIs**: FORM (`?mode=new` / `?mode=edit&id=X`) is a 4-tab form (Basic Info / Story / Goals / Settings) used to create or update a campaign; DETAIL (`?mode=read&id=X`) is a rich analytics dashboard (goal progress hero + 6-KPI strip + daily collection bar chart + donor breakdown donut + by-org-unit/payment-method tables + milestone tracker + recent donations feed + top donors leaderboard). Campaigns are referenced by Donation, Pledge, Event, P2P Campaign, and MatchingGift records (those FKs are not yet wired on the dependent entities — see ⑫). This screen is the central hub for campaign planning, execution, and performance tracking across the NGO's fundraising calendar.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **Scope is ALIGN** — extend the existing `Campaign` entity; do not regenerate from scratch.
> Audit columns (CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive, IsDeleted) omitted — inherited from `Entity` base.
> **CompanyId IS a field** on Campaign (tenant scoping) — set from HttpContext on create (matches SavedFilter/GlobalDonation pattern).

Table: `app."Campaigns"` (existing — see ⑫ for schema `app` vs migration's `corg` discrepancy)

### Existing fields — KEEP AS-IS

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CampaignId | int | — | PK | — | Identity |
| CompanyId | int | — | YES | app.Companies | Tenant scope; set from HttpContext |
| OrganizationalUnitId | int | — | YES | app.OrganizationalUnits | Owning OU (hierarchical) |
| CampaignCategoryId | int | — | YES | sett.MasterData (CAMPAIGNCATEGORY) | FK |
| CampaignTypeId | int | — | YES | sett.MasterData (CAMPAIGNTYPE) | FK |
| CampaignStatusId | int | — | YES | sett.MasterData (CAMPAIGNSTATUS) | FK; workflow state |
| GoalCurrencyId | int? | — | NO | com.Currencies | FK; null if inherited from Company default |
| ShortDescription | string? | 1000 | NO | — | Shown in cards / email subject lines — **promote to REQUIRED per mockup** (200 max) |
| FullDescription | string? | 1000 | NO | — | Free-form; keep as-is |
| CampaignStory | string? | 1000 | NO | — | Rich-text HTML body for public page — **expand maxLen to 8000** |
| GoalAmount | decimal? | — | NO | — | Promote to REQUIRED (decimal(18,2)) |
| GoalDonorCount | int? | — | NO | — | Optional target |
| StartDate | DateTime | — | YES | — | — |
| EndDate | DateTime? | — | NO | — | Promote to REQUIRED for non-Draft statuses |
| MinDonationAmount | decimal? | — | NO | — | Default 10 |
| TotalDonationCount | int? | — | NO | — | Stored counter (updated by donation-write-side; null OK) |
| TotalDonorCount | int? | — | NO | — | Stored counter |
| ProgressPercentage | int? | — | NO | — | Stored value (recomputed on donation events) |
| CampaignUrl | string? | 1000 | NO | — | Legacy field — repurpose as public-facing URL |
| Note | string? | 1000 | NO | — | Keep |

### NEW fields to ADD (required for mockup alignment — migration required)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| **CampaignName** | string | 200 | YES | — | Display name (e.g., "Ramadan Appeal 2026") — **unique per Company (filtered index WHERE IsDeleted=false)** |
| **CampaignCode** | string | 50 | YES | — | Auto-generated `CAMP-{YYYY}-{NNNN}` if empty — unique per Company (filtered index) |
| Visibility | string | 20 | YES (default="Public") | — | Enum: `Public` / `Internal` — simple string (enum-style; not MasterData FK — small fixed set + UI-driven) |
| ShortDescriptionMax | (no column) | — | — | — | Validation: 200 char cap (UI constraint) |
| ImageUrl | string? | 1000 | NO | — | Campaign banner (CDN URL) |
| VideoUrl | string? | 500 | NO | — | Embedded video (YouTube/Vimeo URL) |
| TestimonialQuote | string? | 1000 | NO | — | Beneficiary/donor testimonial |
| TestimonialAuthorPhotoUrl | string? | 1000 | NO | — | CDN URL |
| CustomCampaignUrl | string? | 500 | NO | — | Vanity URL slug (e.g., "ramadan-2026") — unique per Company when NOT NULL (filtered index) |
| CampaignOwnerStaffId | int? | — | NO | app.Staffs | Primary campaign manager |
| IsTaxDeductible | bool | — | YES (default=true) | — | — |
| CampaignTaxCategoryId | int? | — | NO | sett.MasterData (CAMPAIGNTAXCATEGORY) | 501(c)(3) / 80G / Gift Aid / Other |
| AllowRecurring | bool | — | YES (default=true) | — | — |
| AutoCompleteOnEndDate | bool | — | YES (default=true) | — | Transitions status=COMPLETED on EndDate |
| ThankYouEmailTemplateId | int? | — | NO | notify.EmailTemplates | FK |
| ReceiptEmailTemplateId | int? | — | NO | notify.EmailTemplates | FK |
| WhatsAppFollowUpTemplateId | int? | — | NO | notify.WhatsAppTemplates | FK |
| ShareTitle | string? | 200 | NO | — | OG title for social sharing |
| ShareDescription | string? | 200 | NO | — | OG description (max 160 enforced client-side) |
| ShareImageUrl | string? | 1000 | NO | — | OG image (defaults to ImageUrl if null) |
| ProjectedAmount | decimal? | — | NO | — | Computed nightly — dashboard projection line (SERVICE_PLACEHOLDER until pace-projection job exists) |

### Child Entities (NEW — 1:Many from Campaign, cascade on Campaign delete)

| Child Entity | Table | Key Fields | Purpose |
|---|---|---|---|
| **CampaignDonationPurpose** | `app.CampaignDonationPurposes` | CampaignId, DonationPurposeId (composite PK) | Junction → donation purposes this campaign rolls up into (multi-select tag box on form) |
| **CampaignImpactMetric** | `app.CampaignImpactMetrics` | CampaignImpactMetricId (PK), CampaignId, Icon (string 20 — emoji), Label (string 100), Value (int), Unit (string 50), OrderBy (int) | Impact counters shown on public campaign page (e.g., 5000 meals provided to families) |
| **CampaignMilestone** | `app.CampaignMilestones` | CampaignMilestoneId (PK), CampaignId, MilestoneName (string 200), TargetAmount (decimal 18,2), TargetDate (DateTime), AchievedAmount (decimal? — computed), AchievedDate (DateTime?), StatusCode (string 20 — `REACHED`/`IN_PROGRESS`/`UPCOMING`, computed/stored), OrderBy (int) | Phase/milestone tracker for campaign dashboard |
| **CampaignSuggestedAmount** | `app.CampaignSuggestedAmounts` | CampaignSuggestedAmountId (PK), CampaignId, Amount (decimal 18,2), OrderBy (int) | Pre-filled donation button amounts (e.g., $25, $50, $100) |
| **CampaignTeamMember** | `app.CampaignTeamMembers` | CampaignId, StaffId (composite PK), RoleLabel (string 100 — optional display role) | Junction → team staff assignments |
| **CampaignTrackingMetric** | `app.CampaignTrackingMetrics` | CampaignId, TrackingMetricCode (string 40) (composite PK) | Which metrics to track (AMOUNTRAISED, DONORCOUNT, NEWVSRETURNING, AVGDONATION, DAILYTREND, ORGBREAKDOWN, PAYMENTMETHOD) |
| **CampaignRecurringFrequency** | `app.CampaignRecurringFrequencies` | CampaignId, FrequencyCode (string 20) (composite PK) | Which recurring frequencies are allowed (MONTHLY, QUARTERLY, WEEKLY, ANNUAL) |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` + Mapster) + Frontend Developer (ApiSelectV2 queries)
> All paths relative to `PSS_2.0_Backend/PeopleServe/Services/Base/`.

| FK Field | Target Entity | Entity File Path | GQL Query Name (BE handler class) | GQL Field (FE) | Display Field | Response DTO Type |
|---|---|---|---|---|---|---|
| OrganizationalUnitId | OrganizationalUnit | `Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs` | `GetOrganizationalUnitsQuery` → endpoint `GetOrganizationalUnits` | `getOrganizationalUnits` | `UnitName` | `OrganizationalUnitResponseDto` |
| CampaignCategoryId | MasterData (typeCode=CAMPAIGNCATEGORY) | `Base.Domain/Models/SettingModels/MasterData.cs` | `GetMasterDatasQuery` → endpoint `GetMasterDatas` (filter by MasterDataType.TypeCode) | `getMasterDatas` | `DataName` | `MasterDataResponseDto` |
| CampaignTypeId | MasterData (typeCode=CAMPAIGNTYPE) | same | same | `getMasterDatas` | `DataName` | `MasterDataResponseDto` |
| CampaignStatusId | MasterData (typeCode=CAMPAIGNSTATUS) | same | same | `getMasterDatas` | `DataName` | `MasterDataResponseDto` |
| CampaignTaxCategoryId | MasterData (typeCode=CAMPAIGNTAXCATEGORY) | same | same | `getMasterDatas` | `DataName` | `MasterDataResponseDto` |
| GoalCurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `GetCurrenciesQuery` → endpoint `GetCurrencies` | `getCurrencies` | `CurrencyCode` (fallback `CurrencyName`) | `CurrencyResponseDto` |
| CampaignOwnerStaffId | Staff | `Base.Domain/Models/ApplicationModels/Staff.cs` | `GetStaffsQuery` → endpoint `GetStaffs` | `getStaffs` | `FirstName + ' ' + LastName` | `StaffResponseDto` |
| ThankYouEmailTemplateId | EmailTemplate | `Base.Domain/Models/NotifyModels/EmailTemplate.cs` | `GetEmailTemplatesQuery` → endpoint `GetEmailTemplates` | `getEmailTemplates` | `TemplateName` | `EmailTemplateResponseDto` |
| ReceiptEmailTemplateId | EmailTemplate | same | same | same | same | same |
| WhatsAppFollowUpTemplateId | WhatsAppTemplate | `Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs` | `GetWhatsAppTemplatesQuery` → endpoint `GetWhatsAppTemplates` | `getWhatsAppTemplates` | `TemplateName` | `WhatsAppTemplateResponseDto` |
| CampaignDonationPurpose.DonationPurposeId | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` | `GetDonationPurposesQuery` → endpoint `GetDonationPurposes` | `getDonationPurposes` | `PurposeName` | `DonationPurposeResponseDto` |
| CampaignTeamMember.StaffId | Staff | same as CampaignOwnerStaffId | same | same | same | same |

**Child metric enums (not FK — simple string codes validated via MasterData lookup in seed):**
- `CampaignTrackingMetric.TrackingMetricCode` values: `AMOUNTRAISED`, `DONORCOUNT`, `NEWVSRETURNING`, `AVGDONATION`, `DAILYTREND`, `ORGBREAKDOWN`, `PAYMENTMETHOD`
- `CampaignRecurringFrequency.FrequencyCode` values: `MONTHLY`, `QUARTERLY`, `WEEKLY`, `ANNUAL`
- `CampaignMilestone.StatusCode` values: `REACHED`, `IN_PROGRESS`, `UPCOMING` (computed from TargetDate + achieved-amount-vs-target)

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

### Uniqueness Rules
- `CampaignCode` must be unique per Company (filtered unique index: `IsDeleted = false`). Auto-generate as `CAMP-{YYYY}-{NNNN}` if empty on create (use COALESCE(MAX)+1).
- `CampaignName` must be unique per Company (filtered unique index) — enforce case-insensitively at validator level.
- `CustomCampaignUrl` must be unique per Company when NOT NULL (filtered unique index: `IsDeleted = false AND CustomCampaignUrl IS NOT NULL`).
- **REPLACE the existing broken composite unique index** on `{OrgUnit+Category+Type+Currency+Status+IsActive+Company}` — this is semantically wrong and blocks multiple campaigns of the same type within an OU. Drop it in the migration.

### Required Field Rules
- REQUIRED: `CampaignName`, `CampaignCode` (auto-gen if empty), `OrganizationalUnitId`, `CampaignCategoryId`, `CampaignTypeId`, `CampaignStatusId`, `StartDate`, `GoalAmount`, `ShortDescription`, `Visibility`, at least 1 `CampaignDonationPurpose` (junction row)
- REQUIRED for status ≠ DRAFT: `EndDate`, `GoalCurrencyId`, `CampaignStory` (Full Story)

### Conditional Rules
- If `Visibility = Public` → `CustomCampaignUrl` is allowed (optional); UI exposes the field
- If `Visibility = Internal` → `CustomCampaignUrl` must be null (UI hides field; validator strips)
- If `AllowRecurring = true` → at least 1 `CampaignRecurringFrequency` row required
- If `IsTaxDeductible = true` → `CampaignTaxCategoryId` required
- If status `ACTIVE` → `EndDate > StartDate` and `EndDate ≥ Today`
- Duration (computed, readonly): `EndDate - StartDate` in days — displayed only
- For each `CampaignMilestone`: `TargetDate` must fall between `StartDate` and `EndDate`; `TargetAmount > 0`
- For each `CampaignImpactMetric`: `Value > 0`; Label non-empty
- For each `CampaignSuggestedAmount`: `Amount > 0`; no duplicates

### Business Logic
- `GoalAmount > 0`; `MinDonationAmount ≥ 0` (default 10)
- `ShortDescription` max 200 chars (UI character counter); DB column stays at 1000 for safety
- `ShareDescription` max 160 chars (UI counter)
- `ProgressPercentage` = `(TotalDonationAmount / GoalAmount) * 100` — computed by donation-write-side trigger (out-of-scope; for now, stored value written on update; dashboard computes live from donation aggregates where possible)
- `TotalDonationCount`, `TotalDonorCount` — stored counters; recomputed by `RecomputeCampaignCounters` service (SERVICE_PLACEHOLDER until Donation.CampaignId FK lands on dependent entities — see ⑫)
- Milestone `StatusCode` auto-computed on GetById / Dashboard:
  - If `AchievedAmount ≥ TargetAmount` (using live donation aggregate where possible, else stored `ProgressPercentage * GoalAmount`) → `REACHED`
  - Else if `Today > TargetDate` → `IN_PROGRESS` (over-date but not yet reached)
  - Else if `Today < StartDate` or `TargetDate > Today` → `UPCOMING`
  - Else → `IN_PROGRESS`
- Progress-bar color coding (computed on FE, not stored): `≥80%` → green, `50–79%` → amber, `<50%` → red

### Workflow — 5-state machine (CampaignStatus MasterData)

| State | Code | Color | Meaning | Allowed Transitions |
|---|---|---|---|---|
| Draft | `DRAFT` | amber `#a16207` | Saved but not launched | → ACTIVE (Publish), → CANCELLED (Cancel) |
| Active | `ACTIVE` | green `#16a34a` | Accepting donations, visible publicly (if Public visibility) | → PAUSED (Pause), → COMPLETED (Manual complete), → CANCELLED |
| Paused | `PAUSED` | grey | Temporarily stopped accepting donations | → ACTIVE (Resume), → CANCELLED, → COMPLETED |
| Completed | `COMPLETED` | blue `#2563eb` | Reached end date or manually completed | Terminal (→ archive only) |
| Cancelled | `CANCELLED` | red `#dc2626` | Aborted | Terminal |
| (Upcoming) | computed | purple `#7c3aed` | `StartDate > Today AND Status = ACTIVE` | — (pseudo-status for grid display only) |

**Transitions:**
- `PublishCampaign` → sets status to ACTIVE (requires Story, EndDate, GoalCurrency)
- `PauseCampaign` → sets status to PAUSED
- `ResumeCampaign` → sets status back to ACTIVE (from PAUSED)
- `CompleteCampaign` → sets status to COMPLETED (triggers final summary calc)
- `CancelCampaign` → sets status to CANCELLED (requires reason — add `CancellationReason` string? field as FUTURE, noted in ISSUE-5)
- `ArchiveCampaign` → soft delete (Archive button in row/detail menu)
- `AutoCompleteOnEndDate = true` + `EndDate = today` + status `ACTIVE` → auto-transition to COMPLETED (daily job — SERVICE_PLACEHOLDER until cron lands)

**Row action visibility matrix (from mockup):**

| Status | Dashboard btn | Edit/View btn | Delete inline | 3-dot menu |
|---|---|---|---|---|
| Draft | ❌ | Edit | ✅ | Duplicate |
| Upcoming (Active + StartDate>today) | ❌ | Edit | ❌ | Duplicate / Archive / Cancel |
| Active | ✅ Dashboard | Edit | ❌ | Duplicate / Archive / Cancel |
| Paused | ✅ | Edit | ❌ | Duplicate / Archive / Cancel |
| Completed | ✅ | View (read-only) | ❌ | Duplicate / Archive |
| Cancelled | ❌ | View | ❌ | Duplicate |

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Transactional entity with rich multi-tab FORM + multi-section analytics DETAIL dashboard + status workflow + child collections (7 child tables). Canonical reference: `SavedFilter` + `MatchingGift` (blended — SavedFilter for FLOW URL-mode pattern, MatchingGift for child-collection cascade + tabbed form + multiple new MasterData typeCodes + migration).
**Reason**: `+Add` navigates to `?mode=new` (URL mode dispatch), not a modal. Form is multi-tab, detail view is a rich analytics dashboard (different UI from form). Workflow with 5 states + 6 status-transition commands. Multi-FK dropdown + junction tables.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — existing; extend Create/Update/GetAll/GetById
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation + diff-persist (5 child entities + 2 junction tables)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 9)
- [x] Unique validation — `CampaignName`, `CampaignCode`, `CustomCampaignUrl` (all per Company + filtered)
- [x] Workflow commands (Publish, Pause, Resume, Complete, Cancel, Archive — 6 transition commands)
- [x] Summary query — `GetCampaignSummary` (4 KPI cards for list)
- [x] Dashboard query — `GetCampaignDashboard(campaignId)` (8-section analytics)
- [x] Duplicate command — `DuplicateCampaign` (clone + "(Copy)" suffix + children)
- [x] Custom business rule validators — visibility-aware URL, milestone-in-range, recurring-freq-required-when-allow-recurring, delete-blocked-if-donations-exist
- [ ] File upload command — deferred to SERVICE_PLACEHOLDER (see ⑫)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — REPLACE existing `AdvancedDataTable` stub
- [x] **view-page.tsx with 3 URL modes** (new, edit, read)
- [x] React Hook Form (for FORM layout — 4 tabs)
- [x] Zustand store (`campaign-store.ts`)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back + Save/Edit/Publish buttons)
- [x] Child grid inside form — 2 (ImpactMetrics, Milestones)
- [x] Multi-select junction UIs — 3 (DonationPurposes chips, TeamMembers chips, SuggestedAmounts tag-input)
- [x] Checkbox groups — 2 (TrackingMetrics, RecurringFrequencies)
- [x] Card selector — Visibility radio (2 cards: Public/Internal)
- [x] Workflow status badge + action buttons (6 transitions)
- [x] Summary cards / count widgets above grid (4 KPIs — Variant B)
- [x] Filter chip bar (6 chips with live counts)
- [x] **Detail dashboard layout** — 8 analytical sections (hero / KPI strip / 2 charts / 2 tables / tracker / feed / leaderboard)
- [ ] Rich text editor — reuse if exists, else CREATE `rich-text-editor.tsx` (quill/tiptap — check repo)
- [ ] File upload widget — reuse if exists, else SERVICE_PLACEHOLDER button
- [x] Grid aggregation columns — Progress bar (per-row), Raised (live aggregate via subquery or stored counter fallback)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockups — this IS the design spec.
> **Layout Variant**: `widgets-above-grid` → FE Dev uses **Variant B** (ScreenHeader + widgets + DataTableContainer with showHeader=false). MANDATORY to avoid double-header bug (ContactType #19 precedent).

### Grid/List View

**Display Mode**: `table` (standard HTML table — not card-grid. Campaigns have too many columns for a card layout and the progress-bar column needs horizontal real estate.)

**Grid Columns** (11 columns, in display order):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|---|---|---|---|---|---|
| 1 | Campaign Name | `campaignName` | text-link | auto/flex | YES | Click → `?mode=read&id={id}` |
| 2 | Category | `campaignCategoryName` | category-emoji-badge | 180px | YES | e.g., "🌙 Seasonal" — emoji stored in MasterData.DataSetting.icon |
| 3 | Org Unit | `organizationalUnitName` | text | 150px | YES | — |
| 4 | Goal | `goalAmount` | currency | 130px | YES | Right-aligned, currency symbol from `goalCurrencyCode` |
| 5 | Raised | `raisedAmount` | currency-bold | 130px | YES | Em-dash if null (Draft/Upcoming); bold green text |
| 6 | Progress | `progressPercentage` | campaign-progress-bar | 150px (min) | YES | Inline 6px bar + % text below; color-coded (≥80 green / 50–79 amber / <50 red) |
| 7 | Donors | `totalDonorCount` | integer | 100px | YES | Em-dash if 0/null |
| 8 | Status | `campaignStatusCode` | campaign-status-badge | 120px | YES | Dot/icon + label pill; includes computed "Upcoming" state (Active + StartDate>today) |
| 9 | Start | `startDate` | date-short | 100px | YES | "Mar 1" format; em-dash if Draft |
| 10 | End | `endDate` | date-short | 100px | YES | "Apr 30" format; em-dash if Draft |
| 11 | Actions | — | action-buttons + 3-dot | 140px | NO | Status-dependent (see ④ matrix) |

**Grid Cell Renderers (new components — check registries before creating):**
- `campaign-progress-bar` — inline progress bar renderer (6px height, color-coded)
- `category-emoji-badge` — emoji prefix + text (e.g., "🌙 Seasonal") using DataSetting.icon
- `campaign-status-badge` — REUSE existing `status-badge` renderer if possible (stamp via MasterData.DataSetting.colorHex + icon)
- `campaign-name-link` — linked text cell (or reuse existing `text-link` / navigate-on-click)

Register all NEW renderers in all 3 column-type registries (`advanced-component-column.tsx` + `basic-component-column.tsx` + `flow-component-column.tsx`) and export via `shared-cell-renderers` barrel.

**Summary Widgets (Variant B — 4 KPI cards above grid):**

| # | Widget Title | Value Source (GQL field) | Display Type | Icon | Icon Color |
|---|---|---|---|---|---|
| 1 | Active Campaigns | `summary.activeCampaignsCount` + subtitle "Ending this month: {N}" (`endingThisMonthCount`) | integer + subtitle | fa-bullhorn | Teal |
| 2 | Total Raised (Active) | `summary.totalRaisedActive` + subtitle "Goal: {totalGoalActive} ({pct}%)" | currency + subtitle | fa-hand-holding-dollar | Green |
| 3 | Avg. Performance | `summary.avgPerformancePct` (%) + subtitle "Best: {bestCampaignName} ({bestPct}%)" | percentage + subtitle | fa-chart-line | Blue |
| 4 | Donors Reached (Active) | `summary.donorsReachedActive` + subtitle "New donors: {newDonorsCount} ({newDonorsPct}%)" | integer + subtitle | fa-users | Purple |

**Summary GQL Query**: `GetCampaignSummary` → returns `CampaignSummaryDto` — see ⑩.

**Filter Chip Bar** (pill-shaped, below widget row, above filter bar):

| Chip | Count source |
|---|---|
| All | `summary.totalAllCount` |
| Active | `summary.activeCampaignsCount` |
| Upcoming | `summary.upcomingCount` |
| Completed | `summary.completedCount` |
| Draft | `summary.draftCount` |
| Cancelled | `summary.cancelledCount` |

Chip click → sets Zustand filter chip + pushes `statusCode` arg to `GetAllCampaignList` query.

**Filter Bar** (horizontal row):
- **Search** — text, placeholder "Search campaigns..." — searches `campaignName`, `campaignCode`, `shortDescription`, OrgUnit name/code
- **Org Unit** — dropdown (`ApiSelectV2` → `getOrganizationalUnits`) — All Org Units default
- **Category** — dropdown (`ApiSelectV2` → `getMasterDatas` filtered by `CAMPAIGNCATEGORY`) — All Categories default
- **Date Range** — two `<input type="date">` inputs — filters on StartDate/EndDate overlap with range
- **Clear Filters** — button, danger hover

**Grid Actions (row-level, status-dependent)**:
- **Draft**: `Edit` (→ `?mode=edit`) + inline `Delete` button + 3-dot `Duplicate`
- **Upcoming**: `Edit` + 3-dot (`Duplicate`, `Archive`, `Cancel`)
- **Active/Paused**: `Dashboard` (→ `?mode=read`) + `Edit` + 3-dot (`Duplicate`, `Archive`, `Cancel`)
- **Completed/Cancelled**: `Dashboard` + `View` (→ `?mode=read` in disabled form OR detail) + 3-dot (`Duplicate`, `Archive`)

**Bulk Actions**: None in mockup.

**Page Header Actions (list page)**:
- `Export` button (outline accent) → SERVICE_PLACEHOLDER (PDF/CSV export of filtered list)
- `New Campaign` button (filled accent, fa-plus) → navigates to `?mode=new`

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL dashboard) — EXCEPT Draft/Cancelled where it goes to `?mode=edit`.

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

> `view-page.tsx` must handle:
> - `?mode=new` → **FORM LAYOUT** (empty, 4 tabs)
> - `?mode=edit&id=X` → **FORM LAYOUT** (pre-filled, 4 tabs)
> - `?mode=read&id=X` → **DETAIL LAYOUT** (completely different UI: analytics dashboard with 8 sections)
>
> Compose via `<CampaignFormPage>` vs `<CampaignDetailPage>` inner components, branched on `mode`.

---

#### LAYOUT 1: FORM (mode=new & mode=edit) — 4 TABS

**Page Header** (FlowFormPageHeader):
- Left: Back button (→ `/crm/organization/campaign`)
- Middle: Breadcrumb "Campaigns › {Create Campaign | Edit Campaign}" + h1 page title
- Right actions:
  - `Cancel` (text button, danger hover)
  - `Save as Draft` (outline accent, fa-save) → sets status=DRAFT
  - `Save & Publish` (filled accent, fa-paper-plane) → sets status=ACTIVE (if allowed per ④ workflow)
- Sticky footer with same 3 actions
- Unsaved-changes dialog on dirty navigation

**Section Container Type**: `tabs` (4 horizontal tabs, content panels mutually exclusive)

---

**TAB 1 — Basic Info** (icon: fa-info-circle, active by default)

| # | Row Layout | Field | Widget | Placeholder | Validation | Notes |
|---|---|---|---|---|---|---|
| 1 | 2-col | Campaign Name | text | "e.g., Ramadan Appeal 2026" | required, max 200, unique per Company | — |
| 1 | 2-col | Campaign Code | text | "Auto-generated" | optional (auto-gen if empty), max 50 | Editable; hint: "Leave blank for auto-gen (CAMP-YYYY-NNNN)" |
| 2 | 2-col | Category | ApiSelectV2 | "Select category..." | required | Query: `getMasterDatas` typeCode=CAMPAIGNCATEGORY; each option shows emoji + description (via DataSetting.icon + Description) |
| 2 | 2-col | Owning Org Unit | ApiSelectV2 | "Select org unit..." | required | Query: `getOrganizationalUnits`; hierarchical indented tree display (use `parentUnitId`) |
| 3 | full-width | Linked Donation Purposes | multi-select chip box | "Type to search purposes..." | required, min 1 | Query: `getDonationPurposes` — removable chips; suggested-chip quick-add; writes `CampaignDonationPurpose` junction |
| 4 | 2-col | Status | ApiSelectV2 | — | required (default DRAFT) | Query: `getMasterDatas` typeCode=CAMPAIGNSTATUS — 5 options |
| 4 | 2-col | Visibility | card-selector (radio) | — | required (default Public) | 2 cards: `Public 🌐` (with description "Shareable, appears on donation pages") / `Internal 🔒` ("Staff only") |

---

**TAB 2 — Story & Content** (icon: fa-book-open)

| # | Row | Field | Widget | Validation | Notes |
|---|---|---|---|---|---|
| 1 | full-width | Short Description | textarea (2 rows) | required, max 200 (counter shown) | Hint: "Shown in cards, email subject lines, listing pages" |
| 2 | full-width | Full Story / Appeal | **rich-text editor** | optional, min-height 200px | Toolbar: Bold, Italic, Bullet List, Numbered List, Link, Image, Heading, Quote. Reuse existing component if present (check `presentation/components/common/rich-text-editor`); else create `rich-text-editor.tsx` using `react-quill` OR note SERVICE_PLACEHOLDER if none available |
| 3 | 2-col | Campaign Image / Banner | file-upload (drag-drop) | optional, max 5MB | Recommended 1200×630px. SERVICE_PLACEHOLDER if no CDN service — use `image-upload-field.tsx` wrapper with toast mock |
| 3 | 2-col | Campaign Video URL | text (URL type) | optional, URL pattern | Placeholder "https://youtube.com/watch?v=..." |
| 4 | full-width | **Impact Metrics** child-grid | repeatable rows | optional, Value > 0 | 4 inputs per row: Icon (emoji), Label, Value (int), Unit; Remove button per row; "+ Add Impact Metric" button |
| 5 | 2-col | Testimonial Quote | textarea (2 rows) | optional | Placeholder "A beneficiary or donor testimonial..." |
| 5 | 2-col | Testimonial Author Photo | file-upload (compact) | optional | SERVICE_PLACEHOLDER wrapper |

---

**TAB 3 — Goals & Tracking** (icon: fa-bullseye)

| # | Row | Field | Widget | Validation | Notes |
|---|---|---|---|---|---|
| 1 | 3-col | Fundraising Goal | currency input ($ prefix) | required, > 0 | — |
| 1 | 3-col | Goal Currency | ApiSelectV2 | required | Query: `getCurrencies`; options show code (symbol) |
| 1 | 3-col | Minimum Donation | currency input ($ prefix) | optional, ≥ 0, default 10 | — |
| 2 | full-width | Suggested Amounts | tag-input (decimal values) | optional | Pre-filled: 25, 50, 100, 250, 500, 1000 — press Enter to add; removable; writes `CampaignSuggestedAmount` children |
| — | divider "Campaign Period" | — | — | — | — |
| 3 | 4-col | Start Date | datepicker | required | — |
| 3 | 4-col | End Date | datepicker | required (non-DRAFT) | Must be > StartDate |
| 3 | 4-col | Duration | readonly text (computed) | — | e.g., "61 days" — auto-updates from start/end |
| 3 | 4-col | Auto-complete on end date | toggle switch | default ON | Hint: "Status auto-changes to Completed on end date" |
| 4 | full-width | **Milestone Targets** child-grid | repeatable rows | optional, TargetDate in [StartDate, EndDate] | 5 columns per row: Milestone Name, Target Amount, Target Date, Status (readonly — computed REACHED/IN_PROGRESS/UPCOMING from current data), Remove; "+ Add Milestone" button |
| 5 | full-width | Track By (metrics) | checkbox grid (auto-fit 220px min) | — | 7 options: Amount raised (default ✓), Donor count (✓), New vs returning (✓), Average donation (✓), Daily/weekly trend (✓), By org unit (✗), By payment method (✗); writes `CampaignTrackingMetric` rows |

---

**TAB 4 — Settings** (icon: fa-cog)

| # | Section | Field | Widget | Default | Notes |
|---|---|---|---|---|---|
| 1 | Recurring Donations | Allow recurring pledges | toggle | ON | Hint: "Donors can set up automatic recurring donations" |
| 1 | ↳ Frequencies | Frequencies | checkbox row | Monthly ✓, Quarterly ✓, Weekly ✗, Annual ✓ | Only visible if Allow recurring = ON; writes `CampaignRecurringFrequency` rows |
| 2 | Tax Settings | Tax Deductible | toggle | ON | "Shown on receipts" |
| 2 | ↳ Tax Category | Tax Category | ApiSelectV2 (6-col) | "501(c)(3)" | Query: `getMasterDatas` typeCode=CAMPAIGNTAXCATEGORY; required when Tax Deductible=ON |
| 3 | Communication Templates (3-col row) | Thank you email | ApiSelectV2 | "donation_thankyou" | Query: `getEmailTemplates` |
| 3 | | Receipt delivery | ApiSelectV2 | "donation_receipt" | Query: `getEmailTemplates` |
| 3 | | WhatsApp follow-up | ApiSelectV2 | "campaign_appeal" | Query: `getWhatsAppTemplates` |
| 4 | Campaign Team | Team Members | multi-select chip box | — | Query: `getStaffs`; chip format "Name (Role)"; optional `roleLabel` field per chip; writes `CampaignTeamMember` junction |
| 5 | Custom URL | Custom Campaign URL | text | — | Placeholder "donate.hopefoundation.org/ramadan-2026"; only editable when Visibility=Public; unique per Company |
| 6 | Social Sharing (2-col row) | Share Title | text | — | e.g., "Support Our Ramadan Appeal" |
| 6 | Left col | Share Description | text (max 160) | — | Character counter |
| 6 | Left col | Share Image hint | info text | — | "Uses campaign banner by default, or upload separately" + optional upload field |
| 6 | Right col | Social Preview Card | **inline live preview component** | — | Live-updates on Title/Description/Image change; mimics OG card render |

---

**Special Form Widgets (component files to create/reuse):**
- **`rich-text-editor.tsx`** — Full Story (Tab 2). Check `presentation/components/common/` for existing — if none, create with react-quill OR mark SERVICE_PLACEHOLDER.
- **`image-upload-field.tsx`** — Banner + Testimonial Photo + Share Image (Tabs 2, 4). SERVICE_PLACEHOLDER wrapping toast until CDN exists.
- **`impact-metrics-grid.tsx`** — 4-input repeatable rows (Tab 2). React Hook Form `useFieldArray`.
- **`milestones-grid.tsx`** — 5-input repeatable rows (Tab 3) with computed status badge.
- **`suggested-amounts-input.tsx`** — decimal tag-input with Enter-to-add (Tab 3). Pre-fill defaults.
- **`campaign-team-multi-select.tsx`** — staff chip picker with optional role label (Tab 4).
- **`tracking-metrics-checkboxes.tsx`** — 7-checkbox auto-fit grid (Tab 3).
- **`recurring-frequencies-checkboxes.tsx`** — 4-checkbox row with parent toggle (Tab 4).
- **`visibility-card-selector.tsx`** — 2-card radio for Public/Internal (Tab 1).
- **`social-preview-card.tsx`** — inline OG-style live preview card (Tab 4).
- **`category-option-item.tsx`** — dropdown option renderer showing emoji + description (Tab 1 Category field).

---

**Conditional Rules within FORM:**
- Tab 4 "Allow recurring" toggle OFF → hides Frequencies checkbox row
- Tab 4 "Tax Deductible" toggle OFF → hides Tax Category field
- Tab 1 Visibility = Internal → hides Tab 4 Custom URL field
- Tab 3 Auto-complete toggle ON → enables backend daily-job flag (SERVICE_PLACEHOLDER)
- Tab 3 Start/End date change → Duration field auto-updates (readonly)
- Milestone status badge color-coded based on real-time computation (GetById returns live status)

---

**Child Grids in Form** (both use `useFieldArray`):
| Child | Grid Columns | Add Method | Delete | Persistence |
|---|---|---|---|---|
| ImpactMetrics | Icon (emoji) / Label / Value / Unit | "+ Add Impact Metric" button below table | Trash icon per row | Diff-persist on save — ordered by OrderBy |
| Milestones | Milestone / TargetAmount / TargetDate / Status (readonly) / Remove | "+ Add Milestone" button below | Trash icon | Diff-persist; StatusCode computed backend-side |

---

#### LAYOUT 2: DETAIL (mode=read) — Analytics Dashboard (DIFFERENT UI)

> **This is NOT the form with fields disabled.** It's a rich analytics dashboard with 8 distinct sections.
> File: `campaign-detail.tsx` (or inline branch in view-page.tsx).
> Data source: `GetCampaignDashboard(campaignId)` — see ⑩.

**Page Header** (FlowFormPageHeader):
- Left: Back button → `/crm/organization/campaign`
- Middle: Breadcrumb "Campaigns › {CampaignName}" + h1 CampaignName
- Header meta row below h1:
  - Category badge (pill, emoji prefix) — e.g., "🌙 Seasonal"
  - Status badge — e.g., "● Active"
  - Elapsed text — "Mar 1 – Apr 30, 2026 · Day 43 of 61 (70.5% elapsed)" (computed FE-side)
- Right actions:
  - `Edit Campaign` (outline accent, fa-pen) → `?mode=edit&id=X`
  - `Share Link` (outline accent, fa-share-alt) → copies `CustomCampaignUrl` to clipboard (SERVICE_PLACEHOLDER)
  - `Export Report` (outline accent, fa-file-export) → SERVICE_PLACEHOLDER (PDF report)

**Page Layout**: Single-column full-width with nested 2-column splits.

**Section Order** (top to bottom):

1. **Goal Progress Hero Card** (full width)
2. **KPI Strip** (6 cards, responsive auto-fit min 170px)
3. **Charts Row** (col-lg-8 / col-lg-4 split)
4. **Breakdown Tables Row** (col-lg-6 / col-lg-6 split)
5. **Milestone Tracker** (full width)
6. **Recent Donations Feed + Top Donors** (col-lg-7 / col-lg-5 split)

---

**§ Section 1 — Goal Progress Hero** (component: `goal-progress-hero.tsx`)
- Centered hero card
- Large "$471,000" + "raised of $500,000 goal"
- Thick progress bar (20px, gradient teal→light-teal, max-width 700px)
- Large % badge — "94.2%" accent color
- 3 inline stats: fa-bullseye "$29,000 to go" / fa-users "2,345 donors" / fa-calendar-day "18 days left"
- Projection line (green text): "Projected: {projectedAmount} ({projectedPct}%) based on current pace" — SERVICE_PLACEHOLDER (projection calc absent)

---

**§ Section 2 — KPI Strip** (component: `campaign-dashboard-kpi-strip.tsx`, 6 cards)

| # | Label | Value Field | Subtitle |
|---|---|---|---|
| 1 | Total Raised | `dashboard.totalRaised` | "+{todaysAmount} today" (green) |
| 2 | Donors | `dashboard.totalDonors` | "{newDonors} new ({newDonorsPct}%)" |
| 3 | Avg Donation | `dashboard.avgDonation` | "Median: {medianDonation}" |
| 4 | Recurring Pledges | `dashboard.recurringPledgesCount` | "{recurringMonthly}/month" |
| 5 | Largest Gift | `dashboard.largestGiftAmount` | `{largestGiftDonorName}` |
| 6 | Conversion Rate | `dashboard.conversionRatePct` | "Page views → donations" (SERVICE_PLACEHOLDER) |

---

**§ Section 3 — Charts Row** (col-lg-8 / col-lg-4)

**Left (8-col): Daily Collection Trend** (component: `daily-collection-bar-chart.tsx`)
- Card title: "Daily Collection Trend" + fa-chart-bar
- Vertical bar chart (use `recharts` or `apexcharts` — check repo) — data: `dashboard.dailyTrend[]: { date, amount, isSpike }`
- Legend: Daily Collections + Spike (highlight for unusual days)

**Right (4-col): Donor Breakdown Donut** (component: `donor-breakdown-donut.tsx`)
- Card title: "Donor Breakdown" + fa-chart-pie
- Donut chart with center hole (total count)
- 2 segments: Returning / New — data: `dashboard.donorBreakdown: { returningCount, returningPct, newCount, newPct }`

---

**§ Section 4 — Breakdown Tables Row** (col-lg-6 / col-lg-6)

**Left (6-col): By Org Unit Table** (component: `by-orgunit-breakdown-table.tsx`)
- Card title: "By Org Unit" + fa-sitemap
- Columns: Org Unit (linked to OU detail), Raised (currency bold), Donors (int), % of Goal (pct), Trend (colored arrow)
- Data: `dashboard.orgUnitBreakdown[]: { unitName, unitId, raised, donors, goalPct, trendDirection, trendPct }`

**Right (6-col): By Payment Method Table** (component: `by-payment-method-breakdown-table.tsx`)
- Card title: "By Payment Method" + fa-credit-card
- Columns: Method (emoji + name), Amount (currency bold), Count (int), Avg (currency)
- Data: `dashboard.paymentMethodBreakdown[]: { methodName, icon, amount, count, avg }`

---

**§ Section 5 — Milestone Tracker** (component: `milestone-tracker.tsx`)
- Card title: "Milestone Tracker" + fa-flag-checkered
- Horizontal step tracker: dots connected by progress-filled line
- Each milestone shows: dot (colored per state REACHED/IN_PROGRESS/UPCOMING), Milestone Name, Target Amount, detail line (date + actual)
- Data source: `dashboard.milestones[]: { name, targetAmount, targetDate, achievedAmount, achievedDate, statusCode }`

---

**§ Section 6 — Recent Donations Feed + Top Donors** (col-lg-7 / col-lg-5)

**Left (7-col): Recent Donations Feed** (component: `recent-donations-feed.tsx`)
- Card title: "Recent Donations" + fa-stream + "● Live" badge (green pill — SERVICE_PLACEHOLDER for real-time)
- Each feed row: Time (65px) / Avatar (initials) / Donor Name (linked → contact detail) + payment method + purpose sub-line / Amount (right-aligned bold)
- Data: `dashboard.recentDonations[]: { time, donorContactId, donorName, donorAvatarInitials, paymentMethod, purposeName, amount }`
- "View All Donations" link → `/[lang]/crm/donation/globaldonation?campaignId={id}` (SERVICE_PLACEHOLDER filter until GlobalDonation.CampaignId FK lands)

**Right (5-col): Top Donors Leaderboard** (component: `top-donors-leaderboard.tsx`)
- Card title: "Top Donors" + fa-trophy
- Each row: Rank circle (gold 🥇 / silver 🥈 / bronze 🥉 / number), Donor (linked), donation count meta, Total amount (right)
- Data: `dashboard.topDonors[]: { rank, donorContactId, donorName, donationCount, totalAmount }`

---

### Page Widgets & Summary Cards — GridLayoutVariant

**Grid Layout Variant**: `widgets-above-grid` → **Variant B MANDATORY** (ScreenHeader + widgets + `<FlowDataTableContainer showHeader={false}>`). Violating this triggers double-header UI bug (ContactType #19 precedent).

**Summary GQL Query**: `GetCampaignSummary` → `CampaignSummaryDto` — see ⑩.

### Grid Aggregation Columns

| Column | Description | Implementation |
|---|---|---|
| Raised | Sum of confirmed donations for this campaign | Project from `TotalDonationAmount` stored counter in Phase 1. Phase 2 (when GlobalDonation.CampaignId FK lands): LINQ subquery `SUM(Amount) WHERE CampaignId = row.CampaignId AND PaymentStatusCode='PAID'` |
| Progress | `Raised / Goal * 100` | Stored `ProgressPercentage` in Phase 1; live compute post-FK |
| Donors | Distinct donor count | Stored `TotalDonorCount` in Phase 1; live `COUNT(DISTINCT ContactId)` post-FK |

---

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. Grid → `+New Campaign` → `?mode=new` → **FORM LAYOUT** (Tab 1 active, empty)
2. User fills 4 tabs → `Save as Draft` or `Save & Publish` → API creates → URL → `?mode=read&id={newId}` → **DETAIL DASHBOARD**
3. Grid row click (Active/Completed) → `?mode=read&id={id}` → DETAIL DASHBOARD
4. Grid row click (Draft) → `?mode=edit&id={id}` → FORM LAYOUT pre-filled
5. Detail page `Edit` button → `?mode=edit&id={id}` → FORM pre-filled → Save → back to DETAIL
6. 3-dot row action `Duplicate` → calls `duplicateCampaign` mutation → redirects to `?mode=edit&id={newClonedId}` with "(Copy)" suffix
7. 3-dot `Archive` → confirmation modal → `archiveCampaign` mutation → sets IsDeleted=true + IsActive=false
8. 3-dot `Cancel` → confirmation modal → `cancelCampaign` mutation → status=CANCELLED
9. Filter chip click → Zustand updates `statusFilter` → refetches GetAll with statusCode arg
10. Back button → `/crm/organization/campaign` → grid list
11. Unsaved changes dialog on dirty FORM navigate

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: SavedFilter (for FLOW pattern + new MasterData typeCodes) + MatchingGift (for multi-child-collection + migration + tabbed form with status workflow).

| Canonical | → Campaign | Context |
|-----------|-----------|---------|
| SavedFilter | Campaign | Entity name |
| savedFilter | campaign | Variable/camelCase |
| SavedFilterId | CampaignId | PK field |
| SavedFilters | Campaigns | Table name / collection |
| saved-filter | campaign | FE kebab / filename |
| savedfilter | campaign | FE folder slug |
| SAVEDFILTER | CAMPAIGN | Grid code / menu code (already exists in DecoratorApplicationModules) |
| notify | app | DB schema |
| NotifyModels | ApplicationModels | Backend domain group folder |
| NotifyDbContext | ContactDbContext | DbContext (interface: IContactDbContext) |
| NotifyMappings | ContactMappings | Mapster mappings file |
| DecoratorNotifyModules | DecoratorApplicationModules | Decorator class |
| CRM_COMMUNICATION | CRM_ORGANIZATION | Parent menu code |
| CRM | CRM | Module code (same) |
| crm/communication/savedfilter | crm/organization/campaign | FE route path (ALREADY EXISTS — preserve) |
| notify-service | contact-service | FE service folder (preserve — Campaign lives here historically) |
| notify-queries | contact-queries | FE GQL queries folder |
| notify-mutations | contact-mutations | FE GQL mutations folder |

**Key divergences from SavedFilter canonical:**
- Campaign has **5 child entities + 2 junction tables** (vs. SavedFilter's 0). Follow MatchingGift pattern for cascade + diff-persist.
- Campaign form is **tabs** (vs. SavedFilter's split-pane sections).
- Campaign has a **true multi-section analytics DETAIL** layout (vs. SavedFilter's no-separate-detail: "form disabled" approach). Do NOT wrap form in fieldset for Campaign read mode.
- Campaign needs **6 status-transition commands** (vs. SavedFilter's 0).

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Paths rooted at `PSS_2.0_Backend/PeopleServe/Services/Base/` and `PSS_2.0_Frontend/`.

### Backend Files — EXISTING (MODIFY per ALIGN)

| # | File | Path | Action |
|---|---|---|---|
| 1 | Entity | `Base.Domain/Models/ApplicationModels/Campaign.cs` | MODIFY: add 19 new columns, add 7 navigation collections |
| 2 | EF Config | `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/CampaignConfiguration.cs` | MODIFY: drop broken composite unique index; add filtered unique indexes on CampaignName+CompanyId, CampaignCode+CompanyId, CustomCampaignUrl+CompanyId; add new FK constraints; cascade for child collections |
| 3 | Schemas | `Base.Application/Schemas/ApplicationSchemas/CampaignSchemas.cs` | MODIFY: extend CampaignRequestDto/ResponseDto with 19 fields + 7 child collections; add CampaignListDto, CampaignSummaryDto, CampaignDashboardDto (+ nested: CampaignBreakdownRowDto, CampaignMilestoneDto, CampaignRecentDonationDto, CampaignTopDonorDto, etc.) |
| 4 | Create Command | `Base.Application/Business/ApplicationBusiness/Campaigns/Commands/CreateCampaign.cs` | MODIFY: auto-gen CampaignCode, validate unique CampaignName/Code/CustomUrl, persist 7 child collections, add visibility/recurring/tax validators |
| 5 | Update Command | `Base.Application/Business/ApplicationBusiness/Campaigns/Commands/UpdateCampaign.cs` | MODIFY: diff-persist 7 child collections, same validators as Create |
| 6 | Delete Command | `Base.Application/Business/ApplicationBusiness/Campaigns/Commands/DeleteCampaign.cs` | MODIFY: add in-use check (block if any donation/pledge/event/matchingGift references campaign) — stubbed until FKs land on dependents |
| 7 | Toggle Command | `Base.Application/Business/ApplicationBusiness/Campaigns/Commands/ToggleCampaign.cs` | KEEP AS-IS (works) |
| 8 | GetCampaign Query | `Base.Application/Business/ApplicationBusiness/Campaigns/Queries/GetCampaign.cs` | MODIFY: project flat list DTO (campaignName/raised/progress/donors/statusCode/categoryName/orgUnitName); add filters (statusCode, orgUnitId, categoryId, dateFrom, dateTo); fix the `ApplyGridFeatures(baseQuery, …)` bug — pass filtered query |
| 9 | GetCampaignById Query | `Base.Application/Business/ApplicationBusiness/Campaigns/Queries/GetCampaignById.cs` | MODIFY: Include all child collections + owner staff + tax category + email/whatsapp templates + campaignOwnerStaff; compute milestone status codes |
| 10 | GetOrganizationalCampaignById | `Base.Application/Business/ApplicationBusiness/Campaigns/Queries/GetOrganizationalCampaignById.cs` | KEEP (used by OU wizard) |
| 11 | Export Campaign | `Base.Application/Business/ApplicationBusiness/Campaigns/Queries/ExportCampaign.cs` | MODIFY: expose new columns in export mapping |
| 12 | Mutations endpoint | `Base.API/EndPoints/Application/Mutations/CampaignMutations.cs` | MODIFY: register 5 new mutations (Duplicate, Publish, Pause, Resume, Complete, Cancel, Archive) |
| 13 | Queries endpoint | `Base.API/EndPoints/Application/Queries/CampaignQueries.cs` | MODIFY: register 2 new queries (GetCampaignSummary, GetCampaignDashboard) |
| 14 | Mappings | `Base.Application/Mappings/ContactMappings.cs` | MODIFY: remove duplicate `TypeAdapterConfig<Campaign, CampaignDto>`; add explicit maps for new child DTOs; add maps for SummaryDto + DashboardDto |

### Backend Files — NEW (CREATE)

| # | File | Path | Purpose |
|---|---|---|---|
| 15 | Child Entity | `Base.Domain/Models/ApplicationModels/CampaignDonationPurpose.cs` | Junction entity |
| 16 | Child Entity | `Base.Domain/Models/ApplicationModels/CampaignImpactMetric.cs` | 1:M impact metrics |
| 17 | Child Entity | `Base.Domain/Models/ApplicationModels/CampaignMilestone.cs` | 1:M milestones |
| 18 | Child Entity | `Base.Domain/Models/ApplicationModels/CampaignSuggestedAmount.cs` | 1:M suggested amounts |
| 19 | Child Entity | `Base.Domain/Models/ApplicationModels/CampaignTeamMember.cs` | Junction entity |
| 20 | Child Entity | `Base.Domain/Models/ApplicationModels/CampaignTrackingMetric.cs` | 1:M tracking metric codes |
| 21 | Child Entity | `Base.Domain/Models/ApplicationModels/CampaignRecurringFrequency.cs` | 1:M recurring frequency codes |
| 22 | Child EF Config | `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/CampaignDonationPurposeConfiguration.cs` | PK composite + FKs |
| 23 | Child EF Config | `.../CampaignImpactMetricConfiguration.cs` | PK + cascade |
| 24 | Child EF Config | `.../CampaignMilestoneConfiguration.cs` | PK + cascade |
| 25 | Child EF Config | `.../CampaignSuggestedAmountConfiguration.cs` | PK + cascade |
| 26 | Child EF Config | `.../CampaignTeamMemberConfiguration.cs` | PK composite + FKs |
| 27 | Child EF Config | `.../CampaignTrackingMetricConfiguration.cs` | PK composite |
| 28 | Child EF Config | `.../CampaignRecurringFrequencyConfiguration.cs` | PK composite |
| 29 | DuplicateCampaign | `Base.Application/Business/ApplicationBusiness/Campaigns/Commands/DuplicateCampaign.cs` | Clone + "(Copy)" + new code + reset status=DRAFT + copy children |
| 30 | PublishCampaign | `.../PublishCampaign.cs` | status → ACTIVE (validates required fields) |
| 31 | PauseCampaign | `.../PauseCampaign.cs` | status ACTIVE → PAUSED |
| 32 | ResumeCampaign | `.../ResumeCampaign.cs` | status PAUSED → ACTIVE |
| 33 | CompleteCampaign | `.../CompleteCampaign.cs` | status → COMPLETED |
| 34 | CancelCampaign | `.../CancelCampaign.cs` | status → CANCELLED |
| 35 | ArchiveCampaign | `.../ArchiveCampaign.cs` | IsDeleted=true (soft delete + isActive=false) |
| 36 | GetCampaignSummary | `Base.Application/Business/ApplicationBusiness/Campaigns/Queries/GetCampaignSummary.cs` | 4 KPI widgets + 6 chip counts |
| 37 | GetCampaignDashboard | `Base.Application/Business/ApplicationBusiness/Campaigns/Queries/GetCampaignDashboard.cs` | 8-section analytics for detail page |
| 38 | Migration | `Base.Infrastructure/Data/Migrations/{timestamp}_Campaign_AlignWithMockup.cs` | 19 new cols + 7 child tables + index swaps + (verify) schema `app` consistency |
| 39 | DB Seed SQL | `sql-scripts-dyanmic/Campaign-sqlscripts.sql` | Menu upsert + caps + Grid FLOW + 11 fields + MasterData typeCodes (CAMPAIGNCATEGORY, CAMPAIGNSTATUS, CAMPAIGNTAXCATEGORY, CAMPAIGNTRACKINGMETRIC, RECURRINGFREQUENCY) + sample rows |

### Backend Wiring Updates

| # | File | What to Add |
|---|---|---|
| 1 | `Base.Application/Data/Persistence/IContactDbContext.cs` | 7 new DbSet<> for child entities |
| 2 | `Base.Infrastructure/Data/Persistence/ContactDbContext.cs` | 7 new DbSet<> for child entities |
| 3 | `Base.Application/Extensions/DecoratorProperties.cs` | No change (`Campaign = "CAMPAIGN"` already present) |
| 4 | `Base.Application/Mappings/ContactMappings.cs` | Add Mapster maps for 7 child entity pairs + SummaryDto + DashboardDto |

### Frontend Files — EXISTING (MODIFY per ALIGN)

| # | File | Path | Action |
|---|---|---|---|
| 1 | DTO | `src/domain/entities/contact-service/CampaignDto.ts` | MODIFY: extend CampaignRequestDto/ResponseDto + add 7 child DTOs + CampaignSummaryDto + CampaignDashboardDto |
| 2 | GQL Query | `src/infrastructure/gql-queries/contact-queries/CampaignQuery.ts` | MODIFY: add CAMPAIGNS_LIST_QUERY (flat), CAMPAIGN_SUMMARY_QUERY, CAMPAIGN_DASHBOARD_QUERY; extend BY_ID with all child fields |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/contact-mutations/CampaignMutation.ts` | MODIFY: add 7 new mutations (Duplicate + 6 transitions) |
| 4 | Page Config | `src/presentation/pages/crm/organization/campaign.tsx` | MODIFY: render `<CampaignRouter />` (index) instead of `<CampaignDataTable />` |
| 5 | Legacy FE Route | `src/app/[lang]/organization/organizationsetup/campaign/page.tsx` | DELETE (duplicate) |
| 6 | Entity Ops | `src/application/configs/data-table-configs/contact-service-entity-operations.ts` | MODIFY: Campaign already registered; verify/align to new flat list query |
| 7 | Barrel (folder) | `src/presentation/components/page-components/crm/organization/campaign/index.ts` | MODIFY: export new `CampaignRouter`, `CampaignIndexPage`, `CampaignViewPage`, `useCampaignStore` |
| 8 | Legacy data-table | `src/presentation/components/page-components/crm/organization/campaign/data-table.tsx` | DELETE (replaced by index-page) |

### Frontend Files — NEW (CREATE)

**Page-component folder**: `src/presentation/components/page-components/crm/organization/campaign/`

| # | File | Purpose |
|---|---|---|
| 9 | `index.tsx` | `<CampaignRouter />` — URL-mode dispatcher (no id → IndexPage; id+mode=new/edit → FORM view-page; id+mode=read → DETAIL view-page) |
| 10 | `index-page.tsx` | Variant B: `<ScreenHeader>` + `<CampaignWidgets />` + `<CampaignFilterChipBar />` + `<CampaignFilterBar />` + `<DataTableContainer showHeader={false}>` |
| 11 | `view-page.tsx` | 3-mode handler: mode=read → `<CampaignDetailPage />`; mode=new/edit → `<CampaignFormPage />` |
| 12 | `campaign-form-page.tsx` | FORM LAYOUT — FlowFormPageHeader + 4-tab wrapper, unsaved dialog, RHF submit orchestration |
| 13 | `campaign-detail-page.tsx` | DETAIL LAYOUT — header + 8 dashboard sections |
| 14 | `campaign-store.ts` | Zustand: filter-chip state, active-tab state, dashboard section-fold state |
| 15 | `form-tabs/basic-info-tab.tsx` | Tab 1 fields |
| 16 | `form-tabs/story-content-tab.tsx` | Tab 2 fields + child grid (ImpactMetrics) |
| 17 | `form-tabs/goals-tracking-tab.tsx` | Tab 3 fields + child grid (Milestones) + tracking checkboxes |
| 18 | `form-tabs/settings-tab.tsx` | Tab 4 fields |
| 19 | `campaign-widgets.tsx` | 4 KPI cards for list page |
| 20 | `campaign-filter-chip-bar.tsx` | 6 status chips with live counts |
| 21 | `campaign-filter-bar.tsx` | Search + OrgUnit + Category + DateRange + Clear |
| 22 | `detail/goal-progress-hero.tsx` | Hero card with ring + progress bar |
| 23 | `detail/campaign-dashboard-kpi-strip.tsx` | 6-card KPI strip |
| 24 | `detail/daily-collection-bar-chart.tsx` | Bar chart (recharts) |
| 25 | `detail/donor-breakdown-donut.tsx` | Donut chart (recharts) |
| 26 | `detail/by-orgunit-breakdown-table.tsx` | Org-unit breakdown table |
| 27 | `detail/by-payment-method-breakdown-table.tsx` | Payment method breakdown table |
| 28 | `detail/milestone-tracker.tsx` | Horizontal step tracker |
| 29 | `detail/recent-donations-feed.tsx` | Live feed |
| 30 | `detail/top-donors-leaderboard.tsx` | Top 5 donors |
| 31 | `form-widgets/impact-metrics-grid.tsx` | Child grid (Tab 2) |
| 32 | `form-widgets/milestones-grid.tsx` | Child grid (Tab 3) |
| 33 | `form-widgets/suggested-amounts-input.tsx` | Tag input (Tab 3) |
| 34 | `form-widgets/campaign-team-multi-select.tsx` | Staff chip picker (Tab 4) |
| 35 | `form-widgets/tracking-metrics-checkboxes.tsx` | 7-checkbox grid (Tab 3) |
| 36 | `form-widgets/recurring-frequencies-checkboxes.tsx` | 4-checkbox row (Tab 4) |
| 37 | `form-widgets/visibility-card-selector.tsx` | 2-card radio (Tab 1) |
| 38 | `form-widgets/social-preview-card.tsx` | Live OG preview (Tab 4) |
| 39 | `form-widgets/linked-purposes-multi-select.tsx` | DonationPurpose chip multi-select (Tab 1) |
| 40 | Renderer | `src/presentation/components/custom-components/data-table/cell-renderers/campaign-progress-bar.tsx` | 6px progress bar + pct text + color-coding |
| 41 | Renderer | `src/presentation/components/custom-components/data-table/cell-renderers/category-emoji-badge.tsx` | Emoji prefix + category name badge |
| 42 | Renderer | `src/presentation/components/custom-components/data-table/cell-renderers/campaign-status-badge.tsx` | Status pill with dot/icon — may reuse generic `status-badge` |

**If rich-text editor / image upload don't exist in the codebase** — create minimal wrappers:
- `src/presentation/components/common/rich-text-editor.tsx` (or SERVICE_PLACEHOLDER)
- `src/presentation/components/common/image-upload-field.tsx` (SERVICE_PLACEHOLDER — toast only)

### Frontend Wiring Updates

| # | File | Change |
|---|---|---|
| 1 | `contact-service/index.ts` barrel | Ensure `CampaignDto` exports cover new types |
| 2 | `contact-queries/index.ts` barrel | Ensure new queries exported |
| 3 | `contact-mutations/index.ts` barrel | Ensure new mutations exported |
| 4 | `contact-service-entity-operations.ts` | Verify Campaign ops point to new list query name |
| 5 | `custom-components/data-table/column-types/advanced-component-column.tsx` | Register `campaign-progress-bar`, `category-emoji-badge`, `campaign-status-badge` |
| 6 | `custom-components/data-table/column-types/basic-component-column.tsx` | Register same 3 renderers |
| 7 | `custom-components/data-table/column-types/flow-component-column.tsx` | Register same 3 renderers |
| 8 | `custom-components/data-table/cell-renderers/shared-cell-renderers.ts` | Add 3 exports |
| 9 | `crm/organization/index.tsx` (barrel) | Re-export campaign subdirectory |
| 10 | `pages/crm/organization/index.ts` | Already exports `CampaignPageConfig` — verify still works |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens per MODULE_MENU_REFERENCE.md.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Campaigns
MenuCode: CAMPAIGN
ParentMenu: CRM_ORGANIZATION
Module: CRM
MenuUrl: crm/organization/campaign
MenuOrderBy: 2
GridType: FLOW
GridCode: CAMPAIGN

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP

# MasterDataType codes this screen depends on (seed if missing):
MasterDataTypes:
  - CAMPAIGNCATEGORY (6 rows: ANNUALAPPEAL, EMERGENCY, SEASONAL, PROGRAMSPECIFIC, CAPITAL, P2P)
  - CAMPAIGNSTATUS (5 rows: DRAFT, ACTIVE, PAUSED, COMPLETED, CANCELLED) with ColorHex in DataSetting
  - CAMPAIGNTYPE (existing — verify; seed if missing)
  - CAMPAIGNTAXCATEGORY (4 rows: 501C3, 80G, GIFTAID, OTHER)
  - CAMPAIGNTRACKINGMETRIC (7 rows: AMOUNTRAISED, DONORCOUNT, NEWVSRETURNING, AVGDONATION, DAILYTREND, ORGBREAKDOWN, PAYMENTMETHOD)
  - RECURRINGFREQUENCY (existing per RecurringDonationSchedule #8 — verify 4 rows: MONTHLY, QUARTERLY, WEEKLY, ANNUAL; ADD Weekly if missing)
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer
> Follow convention: field names camelCase, GQL field names lowercase-first.

**GraphQL Type Names:**
- Query type: `CampaignQueries`
- Mutation type: `CampaignMutations`

### Queries

| GQL Field | Returns | Key Args | Handler |
|---|---|---|---|
| `getCampaigns` | `PaginatedApiResponse<[CampaignListDto]>` | `gridFilterRequest: GridFeatureRequest!` + filter args: statusCode?, orgUnitId?, categoryId?, dateFrom?, dateTo? | EXISTING — extend |
| `getCampaignById` | `BaseApiResponse<CampaignResponseDto>` (with all child collections) | `campaignId: Int!` | EXISTING — extend |
| `getOrganizationalCampaignById` | `BaseApiResponse<OrganizationalCampaignResponseDto>` | `organizationalUnitId: Int!` | EXISTING — keep |
| `getCampaignSummary` | `BaseApiResponse<CampaignSummaryDto>` | — | NEW |
| `getCampaignDashboard` | `BaseApiResponse<CampaignDashboardDto>` | `campaignId: Int!` | NEW |

### Mutations

| GQL Field | Input | Returns | Action |
|---|---|---|---|
| `createCampaign` | `CampaignRequestDto!` | `BaseApiResponse<CampaignRequestDto>` | EXISTING — extend with children |
| `updateCampaign` | `CampaignRequestDto!` | `BaseApiResponse<CampaignRequestDto>` | EXISTING — extend with children |
| `deleteCampaign` | `campaignId: Int!` | `BaseApiResponse<CampaignRequestDto>` | EXISTING — add in-use check |
| `activateDeactivateCampaign` | `campaignId: Int!` | `BaseApiResponse<CampaignRequestDto>` | EXISTING — keep |
| `duplicateCampaign` | `campaignId: Int!` | `BaseApiResponse<int>` (new cloned ID) | NEW |
| `publishCampaign` | `campaignId: Int!` | `BaseApiResponse<int>` | NEW |
| `pauseCampaign` | `campaignId: Int!` | `BaseApiResponse<int>` | NEW |
| `resumeCampaign` | `campaignId: Int!` | `BaseApiResponse<int>` | NEW |
| `completeCampaign` | `campaignId: Int!` | `BaseApiResponse<int>` | NEW |
| `cancelCampaign` | `campaignId: Int!` + `reason: String?` | `BaseApiResponse<int>` | NEW |
| `archiveCampaign` | `campaignId: Int!` | `BaseApiResponse<int>` | NEW (soft delete + IsActive=false) |

### Response DTO — `CampaignListDto` (flat for grid)

| Field | Type | Notes |
|---|---|---|
| campaignId | number | PK |
| campaignCode | string | — |
| campaignName | string | — |
| campaignCategoryId | number | FK |
| campaignCategoryName | string | Projected |
| campaignCategoryIcon | string? | From DataSetting.icon — e.g., emoji |
| organizationalUnitId | number | FK |
| organizationalUnitName | string | Projected |
| goalAmount | number | — |
| goalCurrencyCode | string? | Projected from Currency — e.g., "USD" |
| goalCurrencySymbol | string? | Projected — e.g., "$" |
| raisedAmount | number? | Stored counter (Phase 1) / live aggregate (Phase 2) |
| progressPercentage | number? | Stored / computed |
| totalDonorCount | number? | — |
| campaignStatusId | number | FK |
| campaignStatusCode | string | e.g., "ACTIVE" |
| campaignStatusName | string | Label |
| campaignStatusColorHex | string? | From DataSetting.colorHex |
| startDate | string (ISO) | — |
| endDate | string? (ISO) | — |
| isActive | boolean | — |
| visibility | string | "Public" / "Internal" |

### Response DTO — `CampaignResponseDto` (full for edit/read forms)

All `CampaignListDto` fields PLUS:
- `shortDescription`, `fullDescription`, `campaignStory` (HTML)
- `imageUrl`, `videoUrl`, `testimonialQuote`, `testimonialAuthorPhotoUrl`
- `customCampaignUrl`, `shareTitle`, `shareDescription`, `shareImageUrl`
- `campaignOwnerStaffId`, `campaignOwnerStaffName` (projected)
- `campaignTaxCategoryId`, `campaignTaxCategoryName`
- `isTaxDeductible`, `allowRecurring`, `autoCompleteOnEndDate`
- `thankYouEmailTemplateId`, `thankYouEmailTemplateName`
- `receiptEmailTemplateId`, `receiptEmailTemplateName`
- `whatsAppFollowUpTemplateId`, `whatsAppFollowUpTemplateName`
- `minDonationAmount`, `goalDonorCount`
- `projectedAmount`
- `totalDonationCount` (stored counter)
- `createdByName`, `createdDate`, `modifiedByName`, `modifiedDate`

**Child collections** (nested arrays):
- `donationPurposes: [{ donationPurposeId, purposeName, purposeCode }]`
- `impactMetrics: [{ campaignImpactMetricId, icon, label, value, unit, orderBy }]`
- `milestones: [{ campaignMilestoneId, milestoneName, targetAmount, targetDate, achievedAmount, achievedDate, statusCode, orderBy }]`
- `suggestedAmounts: [{ campaignSuggestedAmountId, amount, orderBy }]`
- `teamMembers: [{ staffId, staffName, roleLabel }]`
- `trackingMetrics: [{ trackingMetricCode }]`
- `recurringFrequencies: [{ frequencyCode }]`

### `CampaignSummaryDto` (for list widgets — always company-scoped)

```
{
  totalAllCount: int,
  activeCampaignsCount: int,
  upcomingCount: int,
  completedCount: int,
  draftCount: int,
  cancelledCount: int,
  pausedCount: int,
  endingThisMonthCount: int,
  totalRaisedActive: decimal,
  totalGoalActive: decimal,
  totalRaisedPct: decimal,          // (totalRaisedActive / totalGoalActive) * 100
  avgPerformancePct: decimal,       // avg of ProgressPercentage across active campaigns
  bestCampaignId: int?,
  bestCampaignName: string?,
  bestCampaignPct: decimal?,
  donorsReachedActive: int,
  newDonorsCount: int,              // donors unique to these campaigns in last 90 days
  newDonorsPct: decimal
}
```

### `CampaignDashboardDto` (for detail page — campaignId-scoped)

```
{
  campaignId: int,
  campaignName: string,
  totalRaised: decimal,
  goalAmount: decimal,
  progressPct: decimal,
  amountToGo: decimal,
  daysLeft: int,
  totalDonors: int,
  newDonorsCount: int,
  newDonorsPct: decimal,
  todaysAmount: decimal,
  avgDonation: decimal,
  medianDonation: decimal,
  recurringPledgesCount: int,
  recurringMonthly: decimal,
  largestGiftAmount: decimal,
  largestGiftDonorName: string?,
  conversionRatePct: decimal,       // SERVICE_PLACEHOLDER
  projectedAmount: decimal,         // SERVICE_PLACEHOLDER
  projectedPct: decimal,            // SERVICE_PLACEHOLDER
  dailyTrend: [{ date, amount, isSpike }],
  donorBreakdown: { returningCount, returningPct, newCount, newPct },
  orgUnitBreakdown: [{ orgUnitId, unitName, raised, donors, goalPct, trendDirection, trendPct }],
  paymentMethodBreakdown: [{ methodCode, methodName, icon, amount, count, avg }],
  milestones: [{ milestoneId, name, targetAmount, targetDate, achievedAmount, achievedDate, statusCode }],
  recentDonations: [{ time, donorContactId, donorName, donorAvatarInitials, paymentMethod, purposeName, amount }],
  topDonors: [{ rank, donorContactId, donorName, donationCount, totalAmount }]
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors
- [ ] `pnpm tsc --noEmit` — 0 new Campaign errors
- [ ] Migration applies cleanly on empty DB
- [ ] Migration preserves existing Campaign data (no data loss)
- [ ] Migration snapshot regenerated (or user prompted to run `dotnet ef migrations add` locally)

**Functional Verification (Full E2E — MANDATORY):**

### List Page
- [ ] Loads at `/[lang]/crm/organization/campaign`
- [ ] 4 KPI widgets render above grid with live summary counts
- [ ] 6 filter chips render with live counts; clicking updates grid
- [ ] Grid loads with 11 columns; pagination works
- [ ] Search box filters across name/code/description/OU name
- [ ] OrgUnit dropdown filter fires ApiSelectV2; Category dropdown fires ApiSelectV2
- [ ] Date range filter works (StartDate/EndDate overlap)
- [ ] Row click navigates to `?mode=read&id={id}` (except Draft/Cancelled → `?mode=edit`)
- [ ] Row action buttons vary per status per ④ matrix
- [ ] Progress bar column renders correctly with color coding (green/amber/red)
- [ ] Status badge column renders correctly with dot/icon + correct color from MasterData.DataSetting
- [ ] Category emoji badge renders correctly
- [ ] `+New Campaign` button navigates to `?mode=new`

### FORM LAYOUT (mode=new, mode=edit)
- [ ] Page loads with FlowFormPageHeader + 4 tabs; Tab 1 active by default
- [ ] Tab 1 fields all functional: CampaignName, CampaignCode (auto-gen hint), Category (emoji dropdown), Org Unit (hierarchical), DonationPurposes chip multi-select (chips removable), Status, Visibility card selector
- [ ] Tab 2 fields all functional: Short Description (with char counter), Full Story (rich-text editor), Banner upload (SERVICE_PLACEHOLDER toast), Video URL, Impact Metrics child grid (add/remove rows), Testimonial quote + photo
- [ ] Tab 3 fields all functional: Goal Amount, Goal Currency dropdown, Min Donation, Suggested Amounts tag input, Start/End dates, Duration readonly auto-updates, Auto-complete toggle, Milestones child grid with status badges, Tracking Metrics checkbox grid
- [ ] Tab 4 fields all functional: Allow Recurring toggle (conditional frequencies), Tax Deductible toggle (conditional Tax Category), 3 Template dropdowns, Campaign Team chip picker, Custom URL (conditional on Public visibility), Share Title/Description/Image, Social Preview Card live updates
- [ ] Save as Draft sets status=DRAFT and saves
- [ ] Save & Publish sets status=ACTIVE and validates required publish fields (Story, EndDate, GoalCurrency)
- [ ] On save → URL changes to `?mode=read&id={newId}` → DETAIL loads
- [ ] On edit save → URL returns to `?mode=read&id={id}` → DETAIL loads
- [ ] Unsaved changes dialog on dirty navigation
- [ ] Cancel button with confirmation

### DETAIL LAYOUT (mode=read)
- [ ] Header: back, breadcrumb, CampaignName, badges row (category emoji + status dot + elapsed text), 3 action buttons
- [ ] Goal Progress Hero: large raised/goal text + thick progress bar + % + inline stats + projection line
- [ ] KPI Strip: 6 cards with values + subtitles
- [ ] Daily Collection Trend: bar chart renders with spike highlight
- [ ] Donor Breakdown: donut chart with center count + 2-segment legend
- [ ] By Org Unit table: rows with clickable unit names + trend arrows
- [ ] By Payment Method table: rows with emoji + method + amounts
- [ ] Milestone Tracker: horizontal step tracker with colored dots per state
- [ ] Recent Donations Feed: rows with time + avatar + donor name (linked) + amount
- [ ] Top Donors Leaderboard: 5 rows with rank medals/numbers + linked names + totals
- [ ] Edit button → `?mode=edit&id={id}` → FORM pre-filled
- [ ] Share Link button shows SERVICE_PLACEHOLDER toast
- [ ] Export Report button shows SERVICE_PLACEHOLDER toast

### Workflow Actions
- [ ] Duplicate row action: creates copy with "(Copy)" name, new CampaignCode, status=DRAFT, redirects to new record's `?mode=edit`
- [ ] Publish (Save & Publish): sets status=ACTIVE (validator enforces required)
- [ ] Pause button (detail/row): status ACTIVE → PAUSED
- [ ] Resume button: PAUSED → ACTIVE
- [ ] Complete button: → COMPLETED (terminal)
- [ ] Cancel row action: modal with reason → CANCELLED
- [ ] Archive row action: confirmation → IsDeleted=true, IsActive=false (disappears from grid)
- [ ] Delete (Draft only): soft delete with confirmation
- [ ] In-use check: Delete blocks if donations reference (SERVICE_PLACEHOLDER until FK lands)

**DB Seed Verification:**
- [ ] Menu appears in sidebar under CRM > Organization > Campaigns at OrderBy=2
- [ ] MenuCapabilities: READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT/ISMENURENDER all seeded
- [ ] BUSINESSADMIN RoleCapabilities granted for READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT
- [ ] Grid seeded with gridType=FLOW, 11 columns in correct order
- [ ] GridFormSchema NOT seeded (SKIP per FLOW convention)
- [ ] MasterDataTypes CAMPAIGNCATEGORY, CAMPAIGNSTATUS, CAMPAIGNTAXCATEGORY, CAMPAIGNTRACKINGMETRIC, RECURRINGFREQUENCY seeded
- [ ] MasterDatas under each type seeded with correct TypeCode, DataCode, DataName, DataSetting (ColorHex for statuses, icon for categories)
- [ ] Sample campaign rows seeded (3-4) for manual QA
- [ ] Seed SQL is idempotent (ON CONFLICT DO NOTHING or NOT EXISTS guards)

**UI Uniformity (5-check grep — must all return 0 matches):**
- [ ] No inline hex colors in Campaign files except `campaign-status-badge` and `campaign-progress-bar` (data-driven)
- [ ] No inline pixel spacing in Campaign files
- [ ] Variant B confirmed: `<ScreenHeader>` in `index-page.tsx` + `<FlowDataTableContainer showHeader={false}>` in data table
- [ ] No raw "Loading..." strings — use `<Skeleton>` / `<LayoutLoader>`
- [ ] No @iconify classes without Phosphor prefix

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### Schema & Path Conventions
- **CompanyId IS a field** on Campaign (preserved) — set from HttpContext on create (DO NOT pass from FE)
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it
- **Schema is `app` (per snapshot)** — but ISSUE-1 flags a discrepancy where migration created in `corg`. Migration must be explicit about final schema.
- **Group folder is `ApplicationModels`, NOT `OrgModels` or `CampModels`** (Campaigns historically live here with Company/OU/Staff/Branch/Event/Product)
- **DbContext is `ContactDbContext`, NOT `ApplicationDbContext`** — this is the historical grouping for domain entities in schema `app`+`corg`+`fund`+`sett` etc.
- **Mappings file is `ContactMappings.cs`, NOT `ApplicationMappings.cs`**
- **FE folder is `contact-service`, NOT `application-service` or `organization-service`** — historical grouping, preserve for ALIGN scope
- **FE route already exists at `src/app/[lang]/crm/organization/campaign/page.tsx`** — reuse
- **Duplicate FE route at `src/app/[lang]/organization/organizationsetup/campaign/page.tsx`** — DELETE during build to avoid route collision
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout; read has DETAIL dashboard (completely different UI — NOT just form disabled)

### ALIGN Caveats
- ALIGN ≠ do less — every mockup element is in scope (see GOLDEN RULE in SKILL.md)
- Preserve existing BE entity fields + commands + queries; extend, don't recreate
- Preserve existing FE DTO/Query/Mutation file names; extend
- Preserve `OrganizationalCampaignResponseDto` + `GetOrganizationCampaignByIdQuery` + `CAMPAIGN_BY_ORGANIZATIONAL_UNIT_QUERY` — they're used by the Organizational Unit wizard (see embedded form at `page-components/crm/organization/organizationalunit/organizationalcampaign/*`). DO NOT delete.
- Review embedded OU-wizard form (`campaign-form-fields.tsx` + `campaign-tab.tsx` + `campaign-grid-tab.tsx` + `campaign-validation-schema.ts`) and decide whether to refactor for shared DTO or keep inline. Recommended: keep inline for this session; flag ISSUE-6 for future consolidation.

### Campaign Entity Inverse-Navigation Typo Cleanup
Multiple sibling entities declare inverse navigations with a typo (`CompaignCategories`, `CompaignTypes`, `Compaigns`, `CompaignStatuses`). The BE agent should:
1. Rename these inverse nav collections to `CampaignCategories`, `CampaignTypes`, `Campaigns`, `CampaignStatuses` on MasterData.cs and Currency.cs
2. Fix the EF configuration references in `CampaignConfiguration.cs`
3. Update any LINQ projections in other queries that reference the typo'd names
4. This is a small-blast-radius rename but MUST be done — otherwise the model snapshot won't regenerate cleanly

### Downstream FK Additions (out-of-scope for this screen but required for full feature)
- `GlobalDonation.CampaignId` FK — NOT YET ADDED. Without it, the dashboard's `totalRaised`/`totalDonors`/`recentDonations`/`topDonors`/`orgUnitBreakdown`/`paymentMethodBreakdown`/`dailyTrend` all return mock/zero data. Flag as SERVICE_PLACEHOLDER with a clear comment in `GetCampaignDashboard` handler. ADD in a separate future PR (like Branch #41 added Staff.BranchId FK).
- `Event.CampaignId` FK — REMOVED in the 2025-11 migration (was `RelatedCompaignId`). Similarly deferred.
- `Pledge.CampaignId` FK — new entity; add when Pledge #12 is built.
- `MatchingGift.CampaignId` FK — built in MatchingGift #11 (verify before coding — dashboard rollup depends on it).
- `P2PCampaign.ParentCampaignId` FK — out of scope for #39 (build P2P Campaign #15 first).

### Service Dependencies

> Everything shown in the mockup is in scope. The following are UI-only with handler placeholders — full UI is built, only the backend service call is mocked:

- **SERVICE_PLACEHOLDER: Rich-text editor (Full Story)** — if no library exists in repo. Check for `react-quill` / `tiptap` / similar. If absent: use `<textarea>` with basic toolbar-mock + toast explaining "Rich-text editing requires quill/tiptap install — add dependency in next iteration."
- **SERVICE_PLACEHOLDER: Image upload (Banner, Testimonial Photo, Share Image)** — no CDN service exists yet. Full UI: drag-and-drop area, preview thumbnail, remove. Handler: reads File object, stores base64 URL in state, shows toast "Image upload stubbed — will persist to CDN when upload-service exists."
- **SERVICE_PLACEHOLDER: Video URL preview** — ToYouTube/Vimeo embed requires iframe fetch. MVP: show URL as plain text in read mode.
- **SERVICE_PLACEHOLDER: Daily Collection Trend data / Donor Breakdown / Top Donors / Recent Donations** — all 4 dashboard aggregations depend on GlobalDonation having a CampaignId FK (not yet added). Handler returns empty arrays + toast note. UI renders empty-state skeletons gracefully.
- **SERVICE_PLACEHOLDER: Projected Amount** — pace-projection requires historical donation event stream + linear regression. Handler returns `projectedAmount = totalRaised * 1.1` as a placeholder.
- **SERVICE_PLACEHOLDER: Conversion Rate** — requires web analytics integration (page view tracking). Handler returns 0.
- **SERVICE_PLACEHOLDER: Share Link copy** — UI button implemented, clipboard-write handler included, but relies on frontend-only clipboard API (browser-native — actually WORKS). Remove placeholder label if `navigator.clipboard.writeText` is available (it is — modern browsers).
- **SERVICE_PLACEHOLDER: Export Report (PDF)** — PDF generation service absent. Toast mock.
- **SERVICE_PLACEHOLDER: Export List (CSV)** — the existing `ExportController.ExportCampaignData` REST handler exists but the FE button needs to call it; if the service returns empty column list for new fields, BE must align Export Handler. Toast fallback.
- **SERVICE_PLACEHOLDER: Auto-complete on end date (cron job)** — requires scheduled background service. Flag the column + setting, but do not trigger automatically. Manual `CompleteCampaign` command is the only path for now.
- **SERVICE_PLACEHOLDER: Email/WhatsApp template auto-send on donation** — requires message dispatcher. Settings tab stores the chosen template IDs; dispatch is out of scope until communication infra is wired.
- **SERVICE_PLACEHOLDER: Custom URL slug public landing page** — the slug is stored; public page rendering is a separate FE project.

Full UI must be built for ALL items above. Only the handler for the external service is mocked (toast + state update).

### Pre-Flagged Known Issues (will be logged by /build-screen)

| ID | Severity | Area | Description |
|---|---|---|---|
| ISSUE-1 | HIGH | BE | Schema discrepancy — entity snapshot says `app.Campaigns` but migration creates in `corg`. Migration must verify + explicitly set final schema. |
| ISSUE-2 | HIGH | BE | Broken composite unique index on {OrgUnit+Category+Type+Currency+Status+IsActive+Company} blocks legitimate duplicate categories — MUST DROP during migration. |
| ISSUE-3 | MED | BE | `GetCampaign.cs` — `ApplyGridFeatures` bug (passes `baseQuery` not `compaignsQuery`). Fix during handler extension. |
| ISSUE-4 | MED | BE | MasterData inverse-nav typos (`CompaignCategories` etc.) must be renamed — snapshot regeneration fails otherwise. |
| ISSUE-5 | LOW | BE | `CancellationReason` column not in scope for this screen — add as optional future feature. Cancel command accepts `reason` param for FUTURE use. |
| ISSUE-6 | MED | FE | Embedded OU-wizard form (`campaign-form-fields.tsx`) duplicates form logic — keep inline for this session; flag for consolidation in future refactor. |
| ISSUE-7 | HIGH | BE/FE | `GlobalDonation.CampaignId` FK NOT YET ADDED — dashboard aggregations will be stubbed/zero until this FK lands in a future PR. |
| ISSUE-8 | MED | BE | `Event.CampaignId` FK was removed in 2025-11 migration — recent donations feed / org unit breakdown also limited until re-added. |
| ISSUE-9 | MED | FE | Rich-text editor library absent — if detected, fall back to textarea + SERVICE_PLACEHOLDER annotation. |
| ISSUE-10 | MED | FE | Image upload service absent — 3 file upload fields all use placeholder handlers. |
| ISSUE-11 | LOW | BE | `TotalDonationCount` / `TotalDonorCount` / `ProgressPercentage` are stored counters — recomputation trigger is out-of-scope. Manual refresh via future `RefreshCampaignCountersCommand`. |
| ISSUE-12 | LOW | FE | Chart library selection — check repo for recharts/apexcharts/chart.js. Default to whichever is already in use. If none: create minimal SVG fallback for detail page charts. |
| ISSUE-13 | LOW | BE | Seed folder path `sql-scripts-dyanmic` (misspelled `dyanmic`) — preserve repo convention (from EmailTemplate #24 precedent). |
| ISSUE-14 | MED | FE | Campaign form currently uses inline OU-wizard pattern with `CampaignPageConfig` → `<CampaignDataTable>` (read-only). Replacing with full 3-mode router is a significant FE rewrite. Existing file manifest anticipates DELETE of `data-table.tsx`. |
| ISSUE-15 | LOW | BE | `CampaignDto` stub (empty class extending CampaignResponseDto) + duplicate Mapster `<Campaign, CampaignDto>` config — can be removed during Mappings cleanup. |
| ISSUE-16 | MED | FE | Grid row click destination varies by status (Draft → edit, others → read) — implement conditionally in `onRowClick` callback; document in `campaign-store.ts`. |
| ISSUE-17 | LOW | BE | `ExportCampaignData` is REST-only (not GQL) — align new fields in `ExportController` field mapping. Alternatively, add GQL `exportCampaign` for consistency. |
| ISSUE-18 | MED | Seed | Milestone status-code computation is live (not stored) — seed samples should use `StatusCode=NULL` and rely on runtime calc in `GetCampaignDashboard`. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning 2026-04-20 | HIGH | BE | Schema `app` vs migration's `corg` discrepancy — migration must explicitly set schema | OPEN |
| ISSUE-2 | Planning 2026-04-20 | HIGH | BE | Drop broken composite unique index on {OrgUnit+Category+Type+Currency+Status+IsActive+Company} | OPEN |
| ISSUE-3 | Planning 2026-04-20 | MED | BE | `GetCampaign.cs` — `ApplyGridFeatures` bug passes `baseQuery` not filtered query | OPEN |
| ISSUE-4 | Planning 2026-04-20 | MED | BE | MasterData inverse-nav typos (`CompaignCategories`, `CompaignTypes`, `Compaigns`, `CompaignStatuses`) — rename required | OPEN |
| ISSUE-5 | Planning 2026-04-20 | LOW | BE | CancellationReason column not in scope — add as future enhancement | OPEN |
| ISSUE-6 | Planning 2026-04-20 | MED | FE | Embedded OU-wizard Campaign form duplicates form logic — flag for future consolidation | OPEN |
| ISSUE-7 | Planning 2026-04-20 | HIGH | BE/FE | `GlobalDonation.CampaignId` FK NOT YET ADDED — dashboard aggregations stubbed | OPEN |
| ISSUE-8 | Planning 2026-04-20 | MED | BE | `Event.CampaignId` FK removed in 2025-11 migration — re-add in future PR | OPEN |
| ISSUE-9 | Planning 2026-04-20 | MED | FE | Rich-text editor library may be absent — confirm during build | OPEN |
| ISSUE-10 | Planning 2026-04-20 | MED | FE | Image upload service absent — 3 fields use placeholder handlers | OPEN |
| ISSUE-11 | Planning 2026-04-20 | LOW | BE | Stored counters (TotalDonationCount, TotalDonorCount, ProgressPercentage) lack auto-recompute trigger | OPEN |
| ISSUE-12 | Planning 2026-04-20 | LOW | FE | Chart library selection pending repo check | OPEN |
| ISSUE-13 | Planning 2026-04-20 | LOW | BE | Seed folder path `sql-scripts-dyanmic` misspelled — preserve convention | OPEN |
| ISSUE-14 | Planning 2026-04-20 | MED | FE | Existing `data-table.tsx` stub DELETE required during rewrite | OPEN |
| ISSUE-15 | Planning 2026-04-20 | LOW | BE | `CampaignDto` empty stub + duplicate Mapster config — cleanup during Mappings update | OPEN |
| ISSUE-16 | Planning 2026-04-20 | MED | FE | Grid row click destination varies by status — implement conditional onRowClick | OPEN |
| ISSUE-17 | Planning 2026-04-20 | LOW | BE | `ExportCampaignData` REST-only (not GQL) — align new fields in ExportController | OPEN |
| ISSUE-18 | Planning 2026-04-20 | MED | Seed | Milestone StatusCode live-computed — seed samples should use NULL | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}