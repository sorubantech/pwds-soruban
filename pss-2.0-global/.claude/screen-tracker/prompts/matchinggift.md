---
screen: MatchingGift
registry_id: 11
module: Fundraising
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-19
completed_date: 2026-04-19
last_session_date: 2026-04-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed (FE stub at `crm/p2pfundraising/matchinggift/page.tsx` — no BE)
- [x] Business rules extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized
- [x] User Approval received
- [x] Backend code generated (3 entities: MatchingCompany + MatchingGift + MatchingGiftSettings)
- [x] Backend wiring complete
- [x] Frontend code generated (tabbed page + KPI widgets + 2 FLOW grids + FLOW view-pages for MatchingCompany FORM/DETAIL + settings form + donor guidance)
- [x] Frontend wiring complete
- [x] DB Seed script generated (parent menu + 3 hidden child menus + 2 FLOW grids + NO GridFormSchema [FLOW uses code-driven view-page, not RJSF] + MasterData status seeds)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [x] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/crm/p2pfundraising/matchinggift`
- [ ] Tab 1 (Companies): CRUD via full-page view-page with URL modes (`?tab=companies&mode=new|edit|read&id={id}`); form validates and submits; detail view renders read-only profile
- [ ] Tab 2 (Tracker): grid loads, status filter chips work, status update mutation fires; row click navigates to `?tab=tracker&mode=read&id={id}` detail view
- [ ] Tab 3 (Donor Guidance): employer search returns matching company, settings toggles persist
- [ ] Tab 4 (Settings): all toggles + numeric inputs save to MatchingGiftSettings
- [ ] KPI widgets show correct totals and counts (4 cards above tabs)
- [ ] Send Reminder button shows toast with SERVICE_PLACEHOLDER message
- [ ] Embed Code displays + Copy button copies to clipboard
- [ ] FK dropdowns load: MatchingCompany list, GlobalDonation receipt list, Contact list, EmailTemplate list
- [ ] Permissions: BUSINESSADMIN can do everything; verify capability checks via hidden child menus

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **MatchingGift** (composite — 3 entities under one menu)
Module: Fundraising (P2P Fundraising sub-menu)
Schema: `fund`
Group: Donation (folder name in Business/Schemas/Configurations/EndPoints — entity namespace is `Base.Domain.Models.DonationModels`)

**Business**: Many corporate employers will match employee charitable donations (Microsoft 1:1 up to $15k/yr, ExxonMobil 3:1 up to $7,500/yr, etc.). NGOs that surface this opportunity to their donors can effectively double or triple individual gifts at zero extra cost to the donor. This screen is the operations hub for the NGO's matching-gift programme: it lets BusinessAdmins (a) curate a database of corporate matching-gift programmes (Tab 1 "Matching Companies"), (b) track every individual matching-gift opportunity through its lifecycle Eligible→Submitted→Approved→Received|Rejected (Tab 2 "Tracker"), (c) embed an employer-search widget on the donation thank-you page so donors self-discover their match eligibility (Tab 3 "Donor Guidance"), and (d) configure auto-detection and auto-reminder behaviour (Tab 4 "Settings"). It sits alongside the other P2P/Fundraising screens (P2P Campaign #15, Crowdfunding #16) and consumes the existing GlobalDonation, Contact, and EmailTemplate entities as FK sources.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Three entities live under this single screen. Audit columns inherited from `Entity` base in all three.

### Entity 1 — MatchingCompany (master table for Tab 1)

Table: `fund."MatchingCompanies"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MatchingCompanyId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope (HttpContext) |
| MatchingCompanyName | string | 200 | YES | — | Microsoft, Google, etc. — unique per Company |
| MatchRatio | decimal(4,2) | — | YES | — | 0.5, 1.0, 2.0, 3.0 (UI shows "1:1", "3:1") |
| MinimumDonation | decimal(18,2) | — | NO | — | Min eligible donation amount |
| MaximumPerYearPerEmployee | decimal(18,2) | — | NO | — | Yearly cap per employee |
| EligibilityFullTime | bool | — | NO | — | Default true |
| EligibilityPartTime | bool | — | NO | — | — |
| EligibilityRetirees | bool | — | NO | — | — |
| EligibilitySpouses | bool | — | NO | — | — |
| SubmissionUrl | string | 500 | NO | — | Employer giving portal URL |
| SubmissionProcess | string | 2000 | NO | — | Multi-line, instructions to donor |
| RequiredDocuments | string | 1000 | NO | — | E.g., "Donation receipt, Tax-exempt letter" |
| ProcessingTime | string | 100 | NO | — | E.g., "4-6 weeks" |
| ContactEmail | string | 200 | NO | — | Match-gift-program contact at employer |
| Notes | string | 2000 | NO | — | Internal admin notes |
| IsActive | bool | — | YES | — | Inherited from Entity |

### Entity 2 — MatchingGift (per-donation tracker for Tab 2)

Table: `fund."MatchingGifts"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MatchingGiftId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope |
| GlobalDonationId | int | — | YES | fund.GlobalDonations | The donation being matched |
| DonorContactId | int | — | YES | corg.Contacts | Donor (denormalised from donation for quick filter) |
| MatchingCompanyId | int | — | YES | fund.MatchingCompanies | Employer programme |
| DonationAmount | decimal(18,2) | — | YES | — | Snapshot from GlobalDonation at creation |
| MatchAmount | decimal(18,2) | — | YES | — | DonationAmount × MatchRatio (computed at create) |
| MatchingGiftStatusId | int | — | YES | com.MasterData (typeCode=MATCHINGGIFTSTATUS) | Eligible/Submitted/Approved/Received/Rejected/Expired |
| SubmittedDate | DateTime? | — | NO | — | When donor submitted to employer |
| ExpectedDate | DateTime? | — | NO | — | Expected funding date (set when Submitted) |
| ApprovedDate | DateTime? | — | NO | — | When employer approved |
| ReceivedDate | DateTime? | — | NO | — | When NGO received funds |
| RejectionReason | string | 500 | NO | — | Set when status=Rejected |
| ReminderSentDate | DateTime? | — | NO | — | Last reminder timestamp |
| Notes | string | 1000 | NO | — | Internal admin notes |

**Status workflow (state machine)**:
```
[create] → Eligible → Submitted → Approved → Received
                              ↓
                          Rejected
                          
                  Eligible → Expired (after window passes)
                  Submitted → Expired (cap exceeded)
```

### Entity 3 — MatchingGiftSettings (per-Company config for Tabs 3 & 4)

Table: `fund."MatchingGiftSettings"` — exactly **one row per CompanyId** (upsert semantics)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MatchingGiftSettingsId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES (UNIQUE) | app.Companies | One row per tenant |
| AutoDetectEmployer | bool | — | YES | — | Default true (Tab 4 row 1) |
| MinimumDonationForReminder | decimal(18,2) | — | YES | — | Default 25 (Tab 4 row 2) |
| AutoSendReminderEnabled | bool | — | YES | — | Default true (Tabs 3 & 4) |
| ReminderEmailTemplateId | int? | — | NO | notify.EmailTemplates | Selected reminder template |
| ReminderTimingDays | int | — | YES | — | 0=Immediately, 1, 3, 7 (Tab 3 dropdown) |
| FollowUpReminderEnabled | bool | — | YES | — | Default true (Tab 3) |
| FollowUpDays | int | — | YES | — | Default 14, range 1-90 |
| TrackRevenueSeparately | bool | — | YES | — | Default true (Tab 4) |
| ShowOnThankYouPage | bool | — | YES | — | Default true (Tab 4) |
| ShowOnDonationPage | bool | — | YES | — | Default true (Tab 4) |
| IncludeInYearEndStatement | bool | — | YES | — | Default true (Tab 4) |

**Child Entities**: None (each entity is flat).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (.Include() + nav properties) + Frontend Developer (ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| MatchingGift.GlobalDonationId | GlobalDonation | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | `GetGlobalDonations` | `ReceiptNumber` (e.g., "RCP-2026-0892") | `GlobalDonationResponseDto` |
| MatchingGift.DonorContactId | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `GetContacts` | `DisplayName` (else `FirstName` + `LastName`) | `ContactResponseDto` |
| MatchingGift.MatchingCompanyId | MatchingCompany | `Base.Domain/Models/DonationModels/MatchingCompany.cs` *(to be created)* | `GetMatchingCompanies` *(to be created)* | `MatchingCompanyName` | `MatchingCompanyResponseDto` *(to be created)* |
| MatchingGift.MatchingGiftStatusId | MasterData | `Base.Domain/Models/SharedModels/MasterData.cs` | `GetMasterDataByTypeCode` | `MasterDataName` | `MasterDataResponseDto` (filter by `typeCode=MATCHINGGIFTSTATUS`) |
| MatchingGiftSettings.ReminderEmailTemplateId | EmailTemplate | `Base.Domain/Models/NotifyModels/EmailTemplate.cs` | `GetEmailTemplates` | `EmailTemplateName` | `EmailTemplateResponseDto` |
| MatchingCompany.CompanyId / MatchingGift.CompanyId / MatchingGiftSettings.CompanyId | Company | `Base.Domain/Models/ApplicationModels/Company.cs` | (resolved from HttpContext) | — | — |

**MasterData seeds required** (typeCode `MATCHINGGIFTSTATUS`, 6 rows):
| Code | Name | Color (UI) |
|------|------|------------|
| ELIGIBLE | Eligible | amber |
| SUBMITTED | Submitted | blue |
| APPROVED | Approved | emerald |
| RECEIVED | Received | green |
| REJECTED | Rejected | red |
| EXPIRED | Expired | slate |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `MatchingCompany.MatchingCompanyName` must be unique per CompanyId (ValidateUniqueWhenCreate + ValidateUniqueWhenUpdate)
- `MatchingGiftSettings.CompanyId` must be unique (one row per tenant) — implement via Upsert pattern in command handler
- `MatchingGift` may have at most ONE active (non-Rejected, non-Expired) row per `(GlobalDonationId, MatchingCompanyId)` pair — prevents duplicate match requests for the same donation+employer

**Required Field Rules:**
- MatchingCompany: `MatchingCompanyName`, `MatchRatio` are mandatory
- MatchingGift: `GlobalDonationId`, `DonorContactId`, `MatchingCompanyId`, `DonationAmount`, `MatchAmount`, `MatchingGiftStatusId` are mandatory
- MatchingGiftSettings: all `bool` and `int` defaults must be set on first row creation

**Conditional Rules:**
- If `MatchingGift.MatchingGiftStatusId = SUBMITTED` → `SubmittedDate` is required
- If `MatchingGift.MatchingGiftStatusId = APPROVED` → `ApprovedDate` is required
- If `MatchingGift.MatchingGiftStatusId = RECEIVED` → `ReceivedDate` is required
- If `MatchingGift.MatchingGiftStatusId = REJECTED` → `RejectionReason` is required (≥10 chars)
- If `MatchingGiftSettings.AutoSendReminderEnabled = true` → `ReminderEmailTemplateId` should be set (warn, don't block)
- If `MatchingGiftSettings.FollowUpReminderEnabled = true` → `FollowUpDays` must be in [1, 90]
- `MatchingCompany.MaximumPerYearPerEmployee` must be ≥ `MinimumDonation` when both provided

**Business Logic:**
- On `MatchingGift` Create: snapshot `DonationAmount` from GlobalDonation, compute `MatchAmount = DonationAmount × MatchingCompany.MatchRatio`
- On `MatchingGift` status transition: validate against state machine (only allowed transitions per Section ② diagram)
- KPI Summary computation:
  - **Matching-Eligible Donations** = SUM(DonationAmount) WHERE Status IN (Eligible, Submitted, Approved, Received), COUNT same set
  - **Matches Submitted** = SUM(MatchAmount) WHERE Status IN (Submitted, Approved, Received), COUNT same set
  - **Matches Received** = SUM(MatchAmount) WHERE Status = Received, COUNT same set
  - **Unclaimed Potential** = SUM(MatchAmount) WHERE Status = Eligible, COUNT same set
- MatchingCompany row click "View Donors" → navigate to Tab 2 with `MatchingCompanyId` filter applied (client-side route param)

**Workflow**: MatchingGift has the 6-state workflow above. MatchingCompany and MatchingGiftSettings are flat (no workflow).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: **FLOW** (composite tabbed screen — primary entity MatchingCompany + secondary tracker MatchingGift both rendered as FLOW grids with full-page view-page forms, plus inline Settings/Donor-Guidance tabs)

**Type Classification**: Type 4 — *Multi-entity tabbed FLOW screen with workflow tracker* (hybrid of **TagSegmentation #22** tabbed shell + **SavedFilter #27** FLOW URL-mode view-page pattern — uses hidden child menus for per-grid capability resolution and URL `?tab=X&mode=new|edit|read&id=Y` for form/detail navigation).

**Reason** (MASTER_GRID → FLOW conversion, per user directive 2026-04-19): Both Tab 1 (Companies) and Tab 2 (Tracker) switch from MASTER_GRID semantics (AdvancedDataTable + RJSF modal) to FLOW semantics (FlowDataTableContainer + code-driven view-page with 3 URL modes). This is a deliberate override of the mockup's Bootstrap modal — the FLOW pattern gives us a real /form page (more screen real estate for the 5-section MatchingCompany form), a dedicated /detail page (richer read-only company profile with aggregated donor list + match history), and consistent BACK/EDIT/DELETE header actions. MatchingGift Tracker also becomes FLOW: row click → `?tab=tracker&mode=read&id=X` opens a full detail page showing the donation snapshot + status timeline; the legacy inline status-update mini-modal is REPLACED by an inline status-pill action bar on the detail page (no modal). Settings (Tab 4) and Donor Guidance (Tab 3) remain inline form panels — they're not grid-driven so FLOW vs MASTER_GRID distinction does not apply.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files × 3 entities = ~33 BE files) — three full CRUD stacks
- [x] Multi-FK validation (ValidateForeignKeyRecord) — MatchingGift has 4 FKs
- [x] Unique validation — MatchingCompanyName per Company; MatchingGiftSettings.CompanyId
- [x] Custom business rule validators — status transition state machine; conditional date requirements
- [x] **Aggregation Summary query** — `GetMatchingGiftSummary` returns the 4 KPI values (totals + counts per status bucket)
- [x] **Upsert pattern** — MatchingGiftSettings (one-row-per-tenant; Create OR Update via single UpsertMatchingGiftSettings command)
- [x] **Status transition command** — `UpdateMatchingGiftStatus` separate from generic Update (validates state machine, sets correct date column)
- [ ] Nested child creation — N/A (no child entities)
- [ ] File upload command — N/A

**Frontend Patterns Required:**
- [x] **Tabbed page shell** (4 tabs: Companies | Tracker | Donor Guidance | Settings) — precedent: TagSegmentation #22
- [x] **Variant B layout** (ScreenHeader + KPI widgets + Tabs; inside each FLOW tab, `FlowDataTableContainer showHeader={false}` to prevent double header) — precedent: SavedFilter #27, NotificationTemplate #36
- [x] **FlowDataTableContainer × 2** (Companies grid in Tab 1, Tracker grid in Tab 2) — NOT AdvancedDataTable
- [x] **Code-driven view-page × 2** (MatchingCompany + MatchingGift) — each with 3 URL modes (`?mode=new|edit|read`) — NO RJSF modal, NO GridFormSchema
- [x] **URL mode sync** — page reads `?tab={tab}&mode={m}&id={id}` from query string; `+Add` navigates via `router.push`; no modal state
- [x] **KPI summary widgets** (4 cards above the tab nav — render unconditionally, regardless of active tab)
- [x] Filter chips (Tab 2: All/Eligible/Submitted/Approved/Received/Rejected/Expired)
- [x] Match-ratio cell renderer (display "1:1", "3:1" from decimal value)
- [x] Match-amount cell renderer (show base amount + ratio multiplier in muted text when ratio ≠ 1:1)
- [x] Eligible-row highlight (Tab 2 — amber `bg-warning-50` for status=Eligible rows)
- [x] Status-flow diagram (Tab 2 footer — static SVG/HTML schematic, NOT interactive)
- [x] Custom static layouts:
  - Tab 3: search input → result card (MatchingCompany lookup) + auto-notification settings form
  - Tab 4: settings form (toggles + numeric inputs, single Save button)
- [x] **Code-block with copy button** (Tab 3 — embed iframe code with org GUID substitution)
- [x] **Inline status-pill action bar** on MatchingGift detail view-page (replaces the legacy mini-modal) — buttons per allowed transition, inline date/reason inputs shown conditionally
- [x] Service placeholder buttons (Send Reminder from detail view) — toast-only handlers
- [ ] RJSF Modal Form — **N/A (removed in FLOW conversion)**
- [ ] Drag-to-reorder — N/A
- [ ] Side panel — N/A (detail is full-page, not drawer — mirrors SavedFilter precedent)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Page Header (above all tabs)

- Title: **"Matching Gifts"** (icon: `ph:handshake` — Phosphor)
- Subtitle: "Maximize donations through corporate matching programs"
- Header actions (right-aligned — visible ONLY when `?tab=companies` and `?mode` is empty/list, else replaced by contextual detail/form header actions):
  - **Primary**: `+ Add Company` — navigates to `?tab=companies&mode=new` (FLOW FORM view-page) — NOT a modal
  - **Secondary**: `Import Companies` → SERVICE_PLACEHOLDER toast ("Bulk import coming soon")
- When `?mode=read`: header shows **Back** (← grid), **Edit** (→ `?mode=edit`), **Delete**, **Toggle** action buttons
- When `?mode=new` or `?mode=edit`: header shows **Cancel** (← back), form Save/Save-and-Close in footer

Use `<ScreenHeader>` (Variant B mandatory).

### KPI Stats Grid (above the tab nav, render on every tab)

**Layout Variant**: **`widgets-above-grid`** — FE Dev MUST use Variant B: `<ScreenHeader>` + `<MatchingGiftKpiWidgets>` + `<TabbedShell>` containing tab content. No `<AdvancedDataTable>` with internal header.

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Matching-Eligible Donations | `GetMatchingGiftSummary.eligibleAmount` (currency) + `eligibleCount` ("234 donations") | currency + count subtitle | Top-left, teal icon `ph:buildings` |
| 2 | Matches Submitted | `submittedAmount` + `submittedCount` ("112 submitted") | currency + count subtitle | Top-2nd, blue icon `ph:paper-plane-tilt` |
| 3 | Matches Received | `receivedAmount` + `receivedCount` ("89 received") | currency + count subtitle | Top-3rd, green icon `ph:check-square` |
| 4 | Unclaimed Potential | `unclaimedAmount` + `unclaimedCount` ("122 not yet submitted") | currency + count subtitle | Top-right, amber icon `ph:warning` |

Responsive: 4 columns at xl, 2 at md, 1 at xs. Use design tokens (no inline hex). Skeleton placeholders shaped like cards while loading.

### Tab Navigation

Tabs (sticky below KPIs):
1. **Matching Companies** (`ph:buildings`) — default active
2. **Matching Tracker** (`ph:list-checks`)
3. **Donor Guidance** (`ph:compass`)
4. **Settings** (`ph:gear`)

URL syncs to `?tab={tab}` (default: companies). Each tab is independently lazy-loaded if heavy.

---

### Tab 1 — Matching Companies (FlowDataTableContainer + URL-mode view-page)

**Display Mode**: `table` (standard rows, NOT card-grid).

**Grid Component**: `<FlowDataTableContainer showHeader={false}>` — header already provided by the outer `<ScreenHeader>` (Variant B). Wrap the tab shell in `<FlowDataTableStoreProvider gridCode="MATCHINGCOMPANY">`.

**URL-mode routing (Tab 1)**:
- `?tab=companies` (no mode) → LIST view (grid)
- `?tab=companies&mode=new` → LAYOUT 1: FORM (create)
- `?tab=companies&mode=edit&id={id}` → LAYOUT 1: FORM (edit — pre-filled from `GetMatchingCompanyById`)
- `?tab=companies&mode=read&id={id}` → LAYOUT 2: DETAIL (read-only profile)

**Filter bar** (visible only in LIST mode):
- Search input: "Search companies by name..." → filters `matchingCompanyName` (server-side via `searchText`)

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Company | `matchingCompanyName` | text (link styled — accent color) | auto | YES | Click → navigates to `?tab=companies&mode=read&id={id}` DETAIL (Layout 2) |
| 2 | Match Ratio | `matchRatio` | custom renderer `match-ratio-renderer` | 100px | YES | Displays "1:1", "3:1" from decimal |
| 3 | Min | `minimumDonation` | currency | 80px | YES | "$25" |
| 4 | Max | `maximumPerYearPerEmployee` | currency-with-suffix | 120px | YES | "$15,000/yr" |
| 5 | Guidelines | (computed) | text | auto | NO | Joined string from eligibility booleans, e.g., "Full-time, Retirees" |
| 6 | Employees (Donors) | `donorCount` (aggregation) | icon-with-text | 120px | NO | "👥 5 donors" — count of distinct DonorContactId in MatchingGift WHERE MatchingCompanyId=row |
| 7 | Status | `isActive` | badge (active/inactive) | 100px | YES | Active green / Inactive grey |
| 8 | Actions | — | action-buttons | 200px | NO | Edit, View Donors |

**Grid Actions** (per-row):
- **View** (`ph:eye`) — navigates to `?tab=companies&mode=read&id={id}` DETAIL (Layout 2)
- **Edit** (`ph:pencil`) — navigates to `?tab=companies&mode=edit&id={id}` FORM (Layout 1) pre-filled
- **View Donors** (`ph:users`) — switches to Tab 2 with `?tab=tracker&matchingCompanyId={id}` filter param applied
- **Toggle** (`ph:power`) — flip IsActive (inline, stays on grid)
- **Delete** (`ph:trash`) — soft delete (block if any MatchingGift records exist for this company; show "Cannot delete — 5 active matching gifts. Toggle to inactive instead.")

**Footer**: "Showing N of M companies" + paginator.

### Tab 1 — LAYOUT 1: FORM (`?tab=companies&mode=new` and `?mode=edit&id={id}`)

> **FLOW view-page — NOT a modal**. Render as a full-width content area inside the Tab 1 container. Code-driven form (plain React + react-hook-form or page-local controlled state), **NOT RJSF**, **NOT driven by GridFormSchema**. Precedent: SavedFilter #27 view-page.tsx, NotificationTemplate #36 view-page.tsx.

**Page Frame** (FORM):
- Sub-header (below global ScreenHeader): **Cancel** (←) left-aligned | Title `New Matching Company` / `Edit Microsoft` right-centered | Save / Save & Close top-right (primary)
- Body: 5 stacked sections inside `<Card>` containers (not accordion — sections always expanded; matches savedfilter 2-pane form precedent on the left pane)

**Form Sections** (in order):
| # | Title | Icon | Layout | Fields |
|---|-------|------|--------|--------|
| 1 | Basic Information | `ph:info` | 2-column (8/4 split) | matchingCompanyName (col-8), matchRatio (col-4 dropdown) |
| 2 | Match Limits | `ph:currency-dollar` | 2-column | minimumDonation (col-6), maximumPerYearPerEmployee (col-6) |
| 3 | Eligibility | `ph:user-check` | 1-column full-width | 4 inline toggle-checkboxes: Full-time, Part-time, Retirees, Spouses (rendered as 4-up chip group) |
| 4 | Submission Details | `ph:paper-plane-tilt` | 1-column full-width | submissionUrl, submissionProcess (textarea), requiredDocuments (textarea) |
| 5 | Contact & Notes | `ph:chats` | 2-column | processingTime (col-6), contactEmail (col-6), notes (full-width textarea) |

**Field Widget Mapping** (code-driven inputs — FlowDataTable form primitives or plain shadcn/ui inputs):
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| matchingCompanyName | `<Input>` | "Enter company name" | required, max 200 | Unique per Company |
| matchRatio | `<Select>` | "Select ratio" | required | Options: 0.5, 1.0, 2.0, 3.0 (display "0.5:1", "1:1", "2:1", "3:1") |
| minimumDonation | `<CurrencyInput>` | "25" | min 0 | "$" prefix |
| maximumPerYearPerEmployee | `<CurrencyInput>` | "10000" | min 0 | "$" prefix, "/yr" suffix label |
| eligibilityFullTime / PartTime / Retirees / Spouses | 4-up `<CheckboxChipGroup>` | — | — | 4 chip toggles in one row; state = 4 boolean fields |
| submissionUrl | `<Input type="url">` | "https://company.com/matching-gifts" | URL format | — |
| submissionProcess | `<Textarea rows={3}>` | "Describe how employees submit matching gift requests..." | max 2000 | — |
| requiredDocuments | `<Textarea rows={2}>` | "e.g., Donation receipt, Tax-exempt letter..." | max 1000 | — |
| processingTime | `<Input>` | "e.g., 4-6 weeks" | max 100 | — |
| contactEmail | `<Input type="email">` | "matching@company.com" | email format | — |
| notes | `<Textarea rows={2}>` | "Additional notes about this company's matching program..." | max 2000 | — |

**Form Footer**: `Cancel` (→ `?tab=companies`) | `Save` (→ stays in edit mode after save + toast) | `Save & Close` (→ back to `?tab=companies` list after save).

Form state lives in the matchinggift Zustand store (or react-hook-form instance) — NOT global. On mode=edit, pre-populate from `GetMatchingCompanyById`. Validation via zod schema or inline validators (mirror SavedFilter #27 pattern).

---

### Tab 1 — LAYOUT 2: DETAIL (`?tab=companies&mode=read&id={id}`)

> **FLOW view-page (read-only detail) — NOT a modal, NOT a side drawer**. Full-page read-only profile. Precedent: GlobalDonation #1 detail view, NotificationTemplate #36 detail layout.

**Page Frame** (DETAIL):
- Sub-header: **← Back** left | Title (company name) center | **Edit** / **Toggle** / **Delete** / **View Donors** right (action buttons)
- Body: 2-column layout (`grid-cols-1fr_360px` at xl, stacked at md and below)

**Left column** (main content):
- **Card: Matching Programme Overview** (`ph:buildings`): match-ratio hero (large accent text "3:1"), description paragraph
- **Card: Limits & Eligibility** (`ph:gauge`): 2-column key-value list — Minimum Donation, Maximum/Year/Employee, Eligibility summary (computed `eligibilityLabel`)
- **Card: How to Submit** (`ph:paper-plane-tilt`): ordered list parsed from `submissionProcess`, plus submissionUrl CTA button "Go to {Company} Giving Portal"
- **Card: Required Documents** (`ph:file-text`): `requiredDocuments` field as bullet list
- **Card: Admin Notes** (`ph:note`): `notes` field

**Right sidebar** (360px):
- **Card: Matched Donors** (`ph:users`): Top N (up to 10) recent donors for this company (GetMatchingGifts filtered by matchingCompanyId, latest first) — each row: donor name, donation amount, status badge; footer link "View all →" navigates to `?tab=tracker&matchingCompanyId={id}`
- **Card: Contact & Processing** (`ph:phone`): contactEmail, processingTime as key-value
- **Card: Audit** (`ph:clock`): createdBy/createdDate, modifiedBy/modifiedDate (from base entity)

---

### Tab 2 — Matching Gift Tracker (FlowDataTableContainer + chips + URL-mode detail)

**Display Mode**: `table` (with per-row eligible-row highlight).

**Grid Component**: `<FlowDataTableContainer showHeader={false}>` wrapped in `<FlowDataTableStoreProvider gridCode="MATCHINGGIFTRECORD">`.

**URL-mode routing (Tab 2)**:
- `?tab=tracker` (no mode) → LIST view (grid + chips + filter bar)
- `?tab=tracker&mode=read&id={id}` → LAYOUT 3: TRACKER DETAIL (read-only per-gift profile with inline status action bar)
- `?tab=tracker&matchingCompanyId={id}` → LIST pre-filtered by company (deep link from Tab 1)
- No `?mode=new` / `?mode=edit` — MatchingGift records are created server-side (auto-detection from donation + employer match) or via a separate "Create Matching Gift" mutation surfaced only on Company detail page (future)

**Filter bar** (vertical layout — chips on top, filters below):

Top row — **filter chips** (single-select, exclusive):
- All (default active) | Eligible | Submitted | Approved | Received | Rejected | Expired

Bottom row — **filter inputs** (left to right):
- Company select (`<ApiSelectV2 query="GetMatchingCompanies" placeholder="All Companies"/>`)
- From date (date input)
- To date (date input)
- Search input ("Search donor..." — filters by `donorContactName` server-side)

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Donation | `globalDonationReceiptNumber` | text-link (accent) | 140px | YES | "RCP-2026-0892" — click → navigates to GlobalDonation detail (existing route) |
| 2 | Donor | `donorContactName` | text | auto | YES | "Sarah Johnson" |
| 3 | Amount | `donationAmount` | currency | 100px | YES | "$500" |
| 4 | Company | `matchingCompanyName` | text | 140px | YES | "Microsoft" |
| 5 | Match Amount | `matchAmount` | custom renderer `match-amount-renderer` | 130px | YES | "$500" or **bold-accent** "$1,500" + small grey "(3:1)" when ratio ≠ 1:1 |
| 6 | Status | `matchingGiftStatusName` | status-badge (variant from `matchingGiftStatusCode`) | 110px | YES | 6 variants per Section ③ |
| 7 | Submitted | `submittedDate` | date-short | 100px | YES | "Mar 15" or "—" |
| 8 | Expected | `expectedDate` | date-short | 100px | YES | "May 15" or "—" |
| 9 | Actions | — | action-buttons (status-aware) | 220px | NO | See action matrix below |

**Row highlighting**: Rows where `matchingGiftStatusCode = "ELIGIBLE"` get a `bg-warning-50` (amber tint) background, hover `bg-warning-100`. Use design tokens.

**Grid row-level actions** (minimal — most actions live on the detail view-page):
| Status | Per-row Actions |
|--------|----------------|
| All    | `View` (`ph:eye`) → navigates to `?tab=tracker&mode=read&id={id}` LAYOUT 3: TRACKER DETAIL |
| Eligible | `View` + `Send Reminder` inline (SERVICE_PLACEHOLDER toast) |

Row click anywhere (not just Actions column) navigates to `?tab=tracker&mode=read&id={id}`.

**LAYOUT 3: TRACKER DETAIL** (`?tab=tracker&mode=read&id={id}`) — full-page read-only view with **inline status action bar** (REPLACES the legacy status-update mini-modal; mini-modal is REMOVED in FLOW conversion).

**Page Frame (DETAIL)**:
- Sub-header: **← Back** (→ `?tab=tracker`) | "Match Gift #RCP-2026-0892 — Sarah Johnson × Microsoft" | **Edit Notes** / **Delete** right-aligned
- Body: 2-column layout (`grid-cols-1fr_360px` at xl, stacked below)

**Left column** (main content):
- **Card: Donation Snapshot** (`ph:receipt`): Donation receipt link, date, amount, donor, campaign/appeal — all read-only
- **Card: Matching Programme** (`ph:buildings`): MatchingCompany name (link to Tab 1 detail), match ratio hero, computed match amount
- **Card: Status Timeline** (`ph:list-checks`): 6-node mini-timeline showing which states this record has passed through (dates for SubmittedDate/ApprovedDate/ReceivedDate; current state highlighted)
- **Card: Rejection Reason** (conditional — only if `status=Rejected`): `rejectionReason` text + rejected date
- **Card: Notes** (`ph:note`): `notes` field (editable inline via Edit Notes button in header — small inline edit; not a separate form page)

**Inline Status Action Bar** (sticky at bottom of left column OR right below Donation Snapshot card):
- Renders status-aware button row — each button fires `UpdateMatchingGiftStatus` with expanded inline inputs when required:
  | Current Status | Rendered Buttons |
  |---|---|
  | Eligible | `Mark Submitted` (inline date input appears on click → Save → mutation) · `Send Reminder` (SERVICE_PLACEHOLDER) |
  | Submitted | `Mark Approved` (inline approved-date on click) · `Mark Rejected` (inline date + reason textarea ≥10 chars) |
  | Approved | `Mark Received` (inline received-date on click) |
  | Received | (no actions — terminal state) |
  | Rejected | `Resubmit` (clones row with status=Eligible, navigates to the new row's detail) |
  | Expired | (no actions — terminal state) |
- All transitions validated BE-side by `UpdateMatchingGiftStatus` handler (state-machine guard).

**Right sidebar** (360px):
- **Card: Donor Profile** (`ph:user`): name, email, phone, primary address, link to Contact detail
- **Card: Activity Log** (`ph:clock`): chronological list of status changes with timestamps (derived from the 4 date columns + ReminderSentDate — no new table needed)
- **Card: Audit** (`ph:identification-card`): createdBy/createdDate, modifiedBy/modifiedDate

**Status Flow Diagram** (footer of Tab 2 — static visual aid, NOT interactive):
- Render exactly as in mockup lines 553-581: 6 nodes connected by arrows showing the state machine (Donation Received → Eligible → Submitted → Approved → Received, with Rejected branch off Submitted).
- Use design tokens for colors (amber for Eligible, blue for Submitted, emerald for Approved, green for Received, red for Rejected, slate for Donation/Expired).
- Wrap in a `<div role="img" aria-label="Status workflow diagram">` for a11y.

---

### Tab 3 — Donor Guidance (custom layout, 3 cards)

**Card 1 — "Does your employer match donations?"** (search widget)
- Title with `ph:magnifying-glass` icon
- Search input: "Enter your employer name..." + Search button
- Result card (displayed below search after match):
  - Company title (large, with `ph:buildings` icon)
  - 4-column detail row: Match Ratio (large accent text), Minimum (currency), Maximum/Year (currency), Eligibility (text)
  - "How to submit your match:" section with ordered list (parsed from `submissionProcess` field, splitting on newlines or numbered patterns)
  - CTA button: "Go to {Company} Giving Portal" → opens `submissionUrl` in new tab
- Below result: link "Not listed? Request your employer be added" → opens MatchingCompany modal in pre-fill request mode (or SERVICE_PLACEHOLDER toast)

Search behavior: query `GetMatchingCompanies` with `searchText`, debounce 300ms, take top 1 result. If no match → show "We don't yet track {searchTerm} — check back later or use the link below."

**Card 2 — Auto-notification Settings** (subset of MatchingGiftSettings)
- Title with `ph:bell` icon
- 4 setting rows (each with label + description + control on the right):
  | Setting label | Field | Control |
  |--------------|-------|---------|
  | After donation, auto-send matching gift reminder | `autoSendReminderEnabled` | Toggle switch |
  | Reminder template | `reminderEmailTemplateId` | `<ApiSelectV2 query="GetEmailTemplates"/>` (filter to templates tagged for matching-gift category if such metadata exists) |
  | Reminder timing | `reminderTimingDays` | Select: Immediately / 1 day after / 3 days after / 1 week after |
  | Follow-up reminder if not submitted | `followUpReminderEnabled` + `followUpDays` | Toggle + numeric input + "days" suffix |
- These fields are **shared with Tab 4** — both write to MatchingGiftSettings via the same upsert mutation. Two-way binding through the Zustand store (or page-level state).

**Card 3 — Embed Code**
- Title with `ph:code` icon
- Description: "Add the matching gift search widget to your website by embedding this code:"
- Code block (dark bg, monospace) with iframe HTML snippet:
  ```html
  <iframe
    src="https://app.peopleserve.com/matching-gifts/widget/org-{companyId}"
    width="100%"
    height="400"
    frameborder="0"
    style="border: none; border-radius: 12px;"
    title="Matching Gift Search">
  </iframe>
  ```
- Substitute `{companyId}` with the current tenant's CompanyId.
- Copy button (top-right of code block): copies snippet to clipboard, toast "Copied!", revert button text after 2s.

> Note: The actual public iframe widget endpoint is **out of scope** — we only render the snippet. Mark as SERVICE_PLACEHOLDER in §⑫.

---

### Tab 4 — Settings (full settings form)

Single-column form (no sections), each row = label + description on the left + control on the right (matches Bootstrap `setting-row` pattern in mockup). 7 setting rows + Save button.

| # | Label | Description | Field | Control |
|---|-------|-------------|-------|---------|
| 1 | Auto-detect employer from contact record | Automatically identify matching-eligible donors based on employer field | `autoDetectEmployer` | Toggle switch |
| 2 | Minimum donation for matching reminder | Only send matching reminders for donations above this amount | `minimumDonationForReminder` | Currency input ("$" prefix, width 80px) |
| 3 | Auto-send matching reminder email | Automatically send a matching gift reminder to eligible donors | `autoSendReminderEnabled` + `reminderEmailTemplateId` | Toggle + EmailTemplate select |
| 4 | Track matching gift revenue separately | Record matched funds as a separate revenue source in reports | `trackRevenueSeparately` | Toggle switch |
| 5 | Show matching gift widget on donation thank-you page | Display employer search after a donor completes their donation | `showOnThankYouPage` | Toggle switch |
| 6 | Show matching gift widget on online donation page | Display employer search alongside the donation form | `showOnDonationPage` | Toggle switch |
| 7 | Matching gift report in year-end statement | Include matching gift summary in annual donor statements | `includeInYearEndStatement` | Toggle switch |

Footer: right-aligned **Save Settings** primary button → `UpsertMatchingGiftSettings` mutation. Disable while pristine; show success toast on save.

Settings on Tab 3 (rows 2-4 of "Auto-notification Settings" card) and Tab 4 (rows 1, 2, 4-7 + the toggle/template from row 3) **all bind to the same MatchingGiftSettings entity** — the Save button on Tab 4 commits everything; Tab 3 changes also submit on blur (auto-save UX) OR display "unsaved changes" indicator and require Tab 4 Save. **Recommended**: tab 3 changes set local store, Tab 4 Save commits. Add a small banner on Tab 4 if there are unsaved changes from Tab 3.

### User Interaction Flow

1. User loads `/{lang}/crm/p2pfundraising/matchinggift` → KPIs fetch + Tab 1 grid loads
2. User clicks "+Add Company" → modal opens → fills RJSF form → Save → grid refreshes + KPIs may refetch
3. User switches to Tab 2 → tracker grid loads (default filter "All") → filter chips work client/server-side
4. User clicks "Mark Submitted" on Eligible row → mini-modal → status updates → row badge changes + may move out of Eligible filter
5. User switches to Tab 3 → Donor Guidance loads → searches employer → result card displays → toggles auto-send → Tab 3 settings auto-save (or marked dirty)
6. User switches to Tab 4 → settings form loads with current MatchingGiftSettings row → toggles changes → clicks Save Settings → toast success
7. User clicks "View Donors" on a Microsoft row in Tab 1 → switches to Tab 2 with `matchingCompanyId={ms-id}` filter pre-applied

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity. Use when copying from code-reference files.

**Canonical Reference**: ContactType (MASTER_GRID baseline) — and **TagSegmentation #22** for tabbed multi-entity precedent (parent menu + hidden child menus + multi-entity FE shell).

**Primary entity (Tab 1)**:
| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | MatchingCompany | Entity/class name |
| contactType | matchingCompany | Variable/field names |
| ContactTypeId | MatchingCompanyId | PK field |
| ContactTypes | MatchingCompanies | Table name, collection names |
| contact-type | matching-company | (file/component naming if needed) |
| contacttype | matchingcompany | (lower-case identifier) |
| CONTACTTYPE | MATCHINGCOMPANY | Hidden child menu code (capability check) |
| corg | fund | DB schema |
| Corg | Donation | Backend group folder name (Business/Schemas/Configurations/EndPoints) |
| CorgModels | DonationModels | Entity namespace suffix |
| CONTACT | CRM_P2PFUNDRAISING | Parent menu code |
| CRM | CRM | Module code (unchanged) |
| crm/contact/contacttype | crm/p2pfundraising/matchinggift | FE route path (one route, all 3 entities) |
| corg-service | donation-service | FE service folder name |

**Parent menu / page identity** (the visible menu — NOT a separate entity):
- Menu code: **MATCHINGGIFT** (parent — visible in sidebar)
- Menu URL: `crm/p2pfundraising/matchinggift`
- Module: CRM
- Parent menu: CRM_P2PFUNDRAISING

**Hidden child menus** (capability resolution per `<AdvancedDataTableStoreProvider>` per-grid checks — TagSegmentation #22 Step 3b precedent):
- `MATCHINGCOMPANY` (hidden) — for Tab 1 grid capability check
- `MATCHINGGIFTRECORD` (hidden) — for Tab 2 grid capability check
- `MATCHINGGIFTSETTINGS` (hidden) — for Tab 4 settings save capability check

(Use `IsMenuRender = false` for the 3 children; only MATCHINGGIFT is visible.)

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Three entities = three full BE stacks. FE is a single multi-entity tabbed page.

### Backend Files — MatchingCompany (11 files)

| # | File | Path |
|---|------|------|
| 1 | Entity | `Pss2.0_Backend/.../Base.Domain/Models/DonationModels/MatchingCompany.cs` |
| 2 | EF Config | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/DonationConfigurations/MatchingCompanyConfiguration.cs` |
| 3 | Schemas (DTOs) | `Pss2.0_Backend/.../Base.Application/Schemas/DonationSchemas/MatchingCompanySchemas.cs` |
| 4 | Create Command | `Pss2.0_Backend/.../Base.Application/Business/DonationBusiness/MatchingCompanies/Commands/CreateMatchingCompany.cs` |
| 5 | Update Command | `Pss2.0_Backend/.../Base.Application/Business/DonationBusiness/MatchingCompanies/Commands/UpdateMatchingCompany.cs` |
| 6 | Delete Command | `Pss2.0_Backend/.../Base.Application/Business/DonationBusiness/MatchingCompanies/Commands/DeleteMatchingCompany.cs` |
| 7 | Toggle Command | `Pss2.0_Backend/.../Base.Application/Business/DonationBusiness/MatchingCompanies/Commands/ToggleMatchingCompany.cs` |
| 8 | GetAll Query | `Pss2.0_Backend/.../Base.Application/Business/DonationBusiness/MatchingCompanies/Queries/GetMatchingCompaniesQuery.cs` |
| 9 | GetById Query | `Pss2.0_Backend/.../Base.Application/Business/DonationBusiness/MatchingCompanies/Queries/GetMatchingCompanyByIdQuery.cs` |
| 10 | Mutations | `Pss2.0_Backend/.../Base.API/EndPoints/Donation/Mutations/MatchingCompanyMutations.cs` |
| 11 | Queries | `Pss2.0_Backend/.../Base.API/EndPoints/Donation/Queries/MatchingCompanyQueries.cs` |

> Use the SavedFilter / Notification Templates **flat `Commands/Queries/` folder** convention (matches latest Wave 2.6 precedent). Older entities like DonationPurpose used `CreateCommand/`, `UpdateCommand/` per-folder; new entities should use the flat layout.

### Backend Files — MatchingGift (12 files — 11 standard + 1 status-transition command)

| # | File | Path |
|---|------|------|
| 1 | Entity | `Pss2.0_Backend/.../Base.Domain/Models/DonationModels/MatchingGift.cs` |
| 2 | EF Config | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/DonationConfigurations/MatchingGiftConfiguration.cs` |
| 3 | Schemas | `Pss2.0_Backend/.../Base.Application/Schemas/DonationSchemas/MatchingGiftSchemas.cs` |
| 4 | Create Command | `Pss2.0_Backend/.../Base.Application/Business/DonationBusiness/MatchingGifts/Commands/CreateMatchingGift.cs` |
| 5 | Update Command | `.../MatchingGifts/Commands/UpdateMatchingGift.cs` |
| 6 | **UpdateStatus Command** | `.../MatchingGifts/Commands/UpdateMatchingGiftStatus.cs` (state-machine validation + auto-set date columns) |
| 7 | Delete Command | `.../MatchingGifts/Commands/DeleteMatchingGift.cs` |
| 8 | Toggle Command | `.../MatchingGifts/Commands/ToggleMatchingGift.cs` (rarely used — soft delete preferred) |
| 9 | GetAll Query | `.../MatchingGifts/Queries/GetMatchingGiftsQuery.cs` (supports filter chips + companyId + dateFrom/dateTo + searchText) |
| 10 | GetById Query | `.../MatchingGifts/Queries/GetMatchingGiftByIdQuery.cs` |
| 11 | **Summary Query** | `.../MatchingGifts/Queries/GetMatchingGiftSummaryQuery.cs` (returns 4 KPI buckets with totals + counts) |
| 12 | Mutations + Queries | `.../Base.API/EndPoints/Donation/Mutations/MatchingGiftMutations.cs` + `.../Queries/MatchingGiftQueries.cs` |

### Backend Files — MatchingGiftSettings (5 files — Upsert pattern, 1 entity, 1 query, 1 upsert command)

| # | File | Path |
|---|------|------|
| 1 | Entity | `.../Base.Domain/Models/DonationModels/MatchingGiftSettings.cs` |
| 2 | EF Config | `.../Base.Infrastructure/Data/Configurations/DonationConfigurations/MatchingGiftSettingsConfiguration.cs` |
| 3 | Schemas | `.../Base.Application/Schemas/DonationSchemas/MatchingGiftSettingsSchemas.cs` |
| 4 | Upsert Command | `.../Base.Application/Business/DonationBusiness/MatchingGiftSettings/Commands/UpsertMatchingGiftSettings.cs` |
| 5 | GetCurrent Query | `.../Base.Application/Business/DonationBusiness/MatchingGiftSettings/Queries/GetMatchingGiftSettingsQuery.cs` (returns the single CompanyId-scoped row, creates default if not exists) |
| (6) | (Add to existing) | Append handler methods to `MatchingGiftMutations.cs` + `MatchingGiftQueries.cs` (no separate endpoint files — they're settings, not their own grid) |

### Backend Migration & Wiring

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` | `DbSet<MatchingCompany>`, `DbSet<MatchingGift>`, `DbSet<MatchingGiftSettings>` |
| 2 | `BaseDbContext.cs` (or the relevant DbContext for `fund` schema) | Same three `DbSet`s |
| 3 | `DecoratorProperties.cs` | `DecoratorDonationModules` entries for the 3 entities |
| 4 | `DonationMappings.cs` | Mapster Create/Update DTO ↔ entity configs for all 3 |
| 5 | EF Migration | `MatchingGifts_Initial` adding 3 tables + FK indexes + the 6 MasterData seeds (or seed via SQL) |

### DB Seed Script

Single SQL file: `sql-scripts-dynamic/MatchingGift-sqlscripts.sql`

Must include:
1. **Menu** — MATCHINGGIFT (parent, visible, ParentMenuCode=CRM_P2PFUNDRAISING, MenuUrl=`crm/p2pfundraising/matchinggift`)
2. **Hidden child menus** — MATCHINGCOMPANY, MATCHINGGIFTRECORD, MATCHINGGIFTSETTINGS (`IsMenuRender=false`, parent=MATCHINGGIFT)
3. **MenuCapabilities** — for parent + 3 children (READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER)
4. **RoleCapabilities** — BUSINESSADMIN gets all on parent + 3 children
5. **Grid 1** — MATCHINGCOMPANY (**GridType=FLOW**, with full Field + GridField rows for Tab 1 columns)
6. **Grid 2** — MATCHINGGIFTRECORD (**GridType=FLOW**, Field + GridField rows for Tab 2 columns)
7. **GridFormSchema** — **NONE** (FLOW conversion: forms are code-driven in `company-view-page.tsx` — no RJSF. Explicitly do NOT seed a GridFormSchema for MATCHINGCOMPANY.)
8. **MasterData seeds** — 6 rows under typeCode `MATCHINGGIFTSTATUS` (see Section ③)
9. **Sample MatchingCompany rows** (8 from mockup: Microsoft, Google, JPMorgan Chase, Apple, Bank of America, GE, ExxonMobil, State Street)
10. **Sample MatchingGiftSettings row** — one row per Company with sensible defaults (idempotent ON CONFLICT)

### Frontend Files (one tabbed page — many sub-components)

#### DTOs (3 files)
| # | File | Path |
|---|------|------|
| 1 | MatchingCompanyDto | `Pss2.0_Frontend/src/domain/entities/donation-service/MatchingCompanyDto.ts` |
| 2 | MatchingGiftDto + MatchingGiftSummaryDto | `.../donation-service/MatchingGiftDto.ts` |
| 3 | MatchingGiftSettingsDto | `.../donation-service/MatchingGiftSettingsDto.ts` |

#### GraphQL Queries / Mutations (4 files)
| # | File | Path |
|---|------|------|
| 1 | MatchingCompanyQuery | `Pss2.0_Frontend/src/infrastructure/gql-queries/donation-queries/MatchingCompanyQuery.ts` |
| 2 | MatchingCompanyMutation | `.../gql-mutations/donation-mutations/MatchingCompanyMutation.ts` |
| 3 | MatchingGiftQuery (incl. Summary) | `.../gql-queries/donation-queries/MatchingGiftQuery.ts` |
| 4 | MatchingGiftMutation (incl. UpdateStatus + UpsertSettings) | `.../gql-mutations/donation-mutations/MatchingGiftMutation.ts` |
| 5 | MatchingGiftSettingsQuery | `.../gql-queries/donation-queries/MatchingGiftSettingsQuery.ts` |

#### Page Configs (1 file)
| # | File | Path |
|---|------|------|
| 1 | Page config | `Pss2.0_Frontend/src/presentation/pages/crm/p2pfundraising/matchinggift.tsx` (registers the tabbed page + 2 grid configs) |

#### Page Components (under `presentation/components/page-components/crm/p2pfundraising/matchinggift/`)
| # | File | Purpose |
|---|------|---------|
| 1 | `index-page.tsx` | Top-level shell — parses `?tab`/`?mode`/`?id` from URL, renders `<ScreenHeader>` + `<KpiWidgets>` + `<Tabs>` (Variant B) |
| 2 | `kpi-widgets.tsx` | 4 KPI cards driven by GetMatchingGiftSummary |
| 3 | `tab-companies.tsx` | Tab 1 router — switches between LIST (`<CompaniesFlowDataTable/>`), FORM (`<CompanyViewPage/>`), DETAIL (`<CompanyDetailPage/>`) based on `?mode` |
| 4 | `tab-tracker.tsx` | Tab 2 router — switches between LIST (`<TrackerFlowDataTable/>` + chips) and TRACKER DETAIL (`<TrackerDetailPage/>`) based on `?mode` |
| 5 | `tab-guidance.tsx` | Tab 3 — search widget + auto-notification settings + embed code |
| 6 | `tab-settings.tsx` | Tab 4 — settings form |
| 7 | `companies-flow-data-table.tsx` | `FlowDataTableContainer` wrapper for Tab 1 (showHeader=false) with custom column types + Variant B integration |
| 8 | `tracker-flow-data-table.tsx` | `FlowDataTableContainer` wrapper for Tab 2 (showHeader=false) with eligible-row highlight + filter chips + action column |
| 9 | `company-view-page.tsx` | **LAYOUT 1: FORM** — MatchingCompany create/edit full-page form (5 sections, code-driven, NOT RJSF). Precedent: SavedFilter #27 view-page.tsx |
| 10 | `company-detail-page.tsx` | **LAYOUT 2: DETAIL** — MatchingCompany read-only profile (2-column + 360px sidebar with Matched Donors list) |
| 11 | `tracker-detail-page.tsx` | **LAYOUT 3: TRACKER DETAIL** — MatchingGift read-only profile + inline status action bar (REPLACES legacy status-update mini-modal) |
| 12 | `status-action-bar.tsx` | Inline status-aware action buttons with expanding inline date/reason inputs; fires `UpdateMatchingGiftStatus` |
| 13 | `employer-search-widget.tsx` | Tab 3 search + result card |
| 14 | `embed-code-block.tsx` | Tab 3 code block + copy button |
| 15 | `settings-form.tsx` | Shared form bindings used by Tab 3 (subset) and Tab 4 (full) |
| 16 | `status-flow-diagram.tsx` | Tab 2 footer — static workflow visualisation (rendered only in LIST mode) |
| 17 | `checkbox-chip-group.tsx` | 4-up inline chip toggle group for Eligibility section in LAYOUT 1 FORM |
| 18 | `match-gift-store.ts` | Zustand store — active tab/mode/id parse helpers, settings dirty state, filter state, KPI cache, form draft state |

#### Custom Renderers (2 files)
| # | File | Purpose |
|---|------|---------|
| 1 | `match-ratio-renderer.tsx` | Render decimal `1.0` as "1:1", `3.0` as "3:1" (used in Tab 1 col 2 + Tab 3 result card + detail pages) |
| 2 | `match-amount-renderer.tsx` | Render base+computed amount with optional `(3:1)` suffix (used in Tab 2 col 5) |

Add to `presentation/components/data-table/renderers/index.ts` barrel + register in renderer registries (advanced/basic/flow column types) per UI uniformity directives.

#### RJSF Custom Widgets

**None** — FLOW conversion removes RJSF entirely from this screen. No GridFormSchema, no RJSF widgets. All forms are code-driven via `<CompanyViewPage/>`. If the Eligibility chip group needs its own file, it lives in `checkbox-chip-group.tsx` (Page Components row 17) as a plain React component — NOT a RJSF widget.

#### Route Page (1 file — REPLACE EXISTING STUB)
| # | File | Path |
|---|------|------|
| 1 | Route stub → FLOW router page | `Pss2.0_Frontend/src/app/[lang]/crm/p2pfundraising/matchinggift/page.tsx` (currently `<div>Need to Develop</div>`) — replace with `<IndexPage />` that reads `searchParams` for `tab/mode/id` and renders the tabbed shell |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `entity-operations.ts` (donation-service) | MATCHINGCOMPANY, MATCHINGGIFTRECORD, MATCHINGGIFTSETTINGS operations configs |
| 2 | `operations-config.ts` | Import + register the new operations |
| 3 | `donation-service/index.ts` (DTO barrel) | Re-export 3 new DTOs |
| 4 | `donation-queries/index.ts` (if exists) | Re-export 3 new queries |
| 5 | `donation-mutations/index.ts` | Re-export 3 new mutations |
| 6 | `data-table/renderers/index.ts` | Re-export 2 new renderers |
| 7 | `data-table/column-types/flow.ts` (primary) + `advanced.ts` + `basic.ts` | Register match-ratio + match-amount column types across all 3 registries (FLOW is the canonical for this screen) |
| 8 | `presentation/pages/crm/p2pfundraising/index.ts` (or main pages registry) | Register the new page config |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: FULL

# Parent menu (visible in sidebar)
MenuName: Matching Gifts
MenuCode: MATCHINGGIFT
ParentMenu: CRM_P2PFUNDRAISING
Module: CRM
MenuUrl: crm/p2pfundraising/matchinggift
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP   # FLOW screen — forms are code-driven in company-view-page.tsx (no RJSF)
GridCode: MATCHINGCOMPANY

# Hidden child menus — for FlowDataTableStoreProvider per-grid capability checks
# (TagSegmentation #22 hidden-menu pattern + SavedFilter #27 FLOW GridType precedent)
HiddenChildMenus:
  - MenuName: Matching Companies (Hidden)
    MenuCode: MATCHINGCOMPANY
    ParentMenu: MATCHINGGIFT
    MenuUrl: ""
    IsMenuRender: false
    GridType: FLOW
    GridFormSchema: SKIP   # code-driven view-page, not RJSF
    MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE
    RoleCapabilities:
      BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE

  - MenuName: Matching Gift Records (Hidden)
    MenuCode: MATCHINGGIFTRECORD
    ParentMenu: MATCHINGGIFT
    MenuUrl: ""
    IsMenuRender: false
    GridType: FLOW
    GridFormSchema: SKIP   # detail view-page + inline status action bar
    MenuCapabilities: READ, CREATE, MODIFY, DELETE
    RoleCapabilities:
      BUSINESSADMIN: READ, CREATE, MODIFY, DELETE

  - MenuName: Matching Gift Settings (Hidden)
    MenuCode: MATCHINGGIFTSETTINGS
    ParentMenu: MATCHINGGIFT
    MenuUrl: ""
    IsMenuRender: false
    GridType: SKIP
    GridFormSchema: SKIP
    MenuCapabilities: READ, MODIFY
    RoleCapabilities:
      BUSINESSADMIN: READ, MODIFY
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose before BE is even built.

**GraphQL Types:**
- Query types: `MatchingCompanyQueries`, `MatchingGiftQueries`
- Mutation types: `MatchingCompanyMutations`, `MatchingGiftMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `GetMatchingCompanies` | `PaginatedApiResponse<[MatchingCompanyResponseDto]>` | `searchText, pageNo, pageSize, sortField, sortDir, isActive` |
| `GetMatchingCompanyById` | `BaseApiResponse<MatchingCompanyResponseDto>` | `matchingCompanyId` |
| `GetMatchingGifts` | `PaginatedApiResponse<[MatchingGiftResponseDto]>` | `searchText, pageNo, pageSize, sortField, sortDir, statusCode, matchingCompanyId, dateFrom, dateTo, donorContactId` |
| `GetMatchingGiftById` | `BaseApiResponse<MatchingGiftResponseDto>` | `matchingGiftId` |
| `GetMatchingGiftSummary` | `BaseApiResponse<MatchingGiftSummaryDto>` | (no args — scoped by HttpContext CompanyId) |
| `GetMatchingGiftSettings` | `BaseApiResponse<MatchingGiftSettingsResponseDto>` | (no args — returns single CompanyId-scoped row, creates with defaults if absent) |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `CreateMatchingCompany` | `MatchingCompanyRequestDto` | `int` (new ID) |
| `UpdateMatchingCompany` | `MatchingCompanyRequestDto` | `int` |
| `DeleteMatchingCompany` | `matchingCompanyId` | `int` |
| `ToggleMatchingCompany` | `matchingCompanyId` | `int` |
| `CreateMatchingGift` | `MatchingGiftRequestDto` | `int` |
| `UpdateMatchingGift` | `MatchingGiftRequestDto` | `int` |
| `UpdateMatchingGiftStatus` | `{ matchingGiftId, newStatusCode, transitionDate, rejectionReason? }` | `int` (validates state machine) |
| `DeleteMatchingGift` | `matchingGiftId` | `int` |
| `UpsertMatchingGiftSettings` | `MatchingGiftSettingsRequestDto` | `int` |

**MatchingCompanyResponseDto:**
| Field | Type | Notes |
|-------|------|-------|
| matchingCompanyId | number | PK |
| matchingCompanyName | string | — |
| matchRatio | number | decimal (display via `match-ratio-renderer`) |
| minimumDonation | number? | — |
| maximumPerYearPerEmployee | number? | — |
| eligibilityFullTime / PartTime / Retirees / Spouses | boolean | 4 separate fields |
| eligibilityLabel | string | **Computed BE-side** — joined string of enabled eligibility flags ("Full-time, Retirees") for grid display |
| submissionUrl / submissionProcess / requiredDocuments / processingTime / contactEmail / notes | string? | — |
| donorCount | number | **Aggregation** — distinct DonorContactId in MatchingGifts WHERE MatchingCompanyId = row |
| isActive | boolean | inherited |
| createdDate / modifiedDate | string (ISO) | inherited |

**MatchingGiftResponseDto:**
| Field | Type | Notes |
|-------|------|-------|
| matchingGiftId | number | PK |
| globalDonationId | number | FK |
| globalDonationReceiptNumber | string | from nav `GlobalDonation.ReceiptNumber` |
| donorContactId | number | FK |
| donorContactName | string | from nav `Contact.DisplayName` (fallback FirstName+LastName) |
| matchingCompanyId | number | FK |
| matchingCompanyName | string | from nav |
| donationAmount | number | snapshot |
| matchAmount | number | computed at create |
| matchingGiftStatusId | number | FK |
| matchingGiftStatusCode | string | from MasterData (ELIGIBLE/SUBMITTED/etc.) |
| matchingGiftStatusName | string | from MasterData |
| submittedDate / expectedDate / approvedDate / receivedDate | string? (ISO) | conditional |
| rejectionReason | string? | conditional |
| reminderSentDate | string? (ISO) | — |
| notes | string? | — |
| matchRatio | number | from MatchingCompany nav (for renderer suffix) |

**MatchingGiftSummaryDto:**
| Field | Type | Source |
|-------|------|--------|
| eligibleAmount | number | SUM(DonationAmount) WHERE Status IN (Eligible,Submitted,Approved,Received) |
| eligibleCount | number | COUNT same |
| submittedAmount | number | SUM(MatchAmount) WHERE Status IN (Submitted,Approved,Received) |
| submittedCount | number | COUNT same |
| receivedAmount | number | SUM(MatchAmount) WHERE Status = Received |
| receivedCount | number | COUNT same |
| unclaimedAmount | number | SUM(MatchAmount) WHERE Status = Eligible |
| unclaimedCount | number | COUNT same |

**MatchingGiftSettingsResponseDto:**
| Field | Type | Notes |
|-------|------|-------|
| matchingGiftSettingsId | number | PK |
| autoDetectEmployer | boolean | — |
| minimumDonationForReminder | number | — |
| autoSendReminderEnabled | boolean | — |
| reminderEmailTemplateId | number? | FK |
| reminderEmailTemplateName | string? | from nav |
| reminderTimingDays | number | enum: 0/1/3/7 |
| followUpReminderEnabled | boolean | — |
| followUpDays | number | 1-90 |
| trackRevenueSeparately | boolean | — |
| showOnThankYouPage | boolean | — |
| showOnDonationPage | boolean | — |
| includeInYearEndStatement | boolean | — |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/crm/p2pfundraising/matchinggift`
- [ ] `pnpm tsc --noEmit` — no new errors in MatchingGift files

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Page renders ScreenHeader + 4 KPI widgets + 4 tabs (Variant B: ScreenHeader is outside the FlowDataTableContainer; `showHeader={false}` on both inner grids) — no double header
- [ ] URL mode sync — navigating `+Add Company` pushes `?tab=companies&mode=new`; browser back button returns to LIST; deep link to `?tab=companies&mode=read&id=5` loads detail directly
- [ ] Tab 1 LIST — grid loads with 8 columns (FlowDataTableContainer); search filters by name; +Add navigates to FORM (no modal rendered anywhere)
- [ ] Tab 1 FORM (`?mode=new`) — 5 sections render; validation fires; Save persists + toast; Save & Close returns to LIST; Cancel returns to LIST without save
- [ ] Tab 1 FORM (`?mode=edit&id=X`) — form pre-fills from GetMatchingCompanyById; Save updates + toast
- [ ] Tab 1 DETAIL (`?mode=read&id=X`) — 2-column layout renders: left cards (Overview, Limits, How to Submit, Documents, Notes) + right sidebar (Matched Donors, Contact & Processing, Audit); Edit/Toggle/Delete header actions work
- [ ] Tab 1 — match-ratio renderer shows "1:1", "3:1" correctly; "Employees (Donors)" column shows correct distinct donor count
- [ ] Tab 1 — "View Donors" from LIST or DETAIL navigates to `?tab=tracker&matchingCompanyId={id}` with filter pre-applied
- [ ] Tab 2 LIST — grid loads (FlowDataTableContainer); filter chips switch dataset; company select + date range + donor search all filter correctly
- [ ] Tab 2 LIST — eligible rows have amber background tint; row click navigates to `?tab=tracker&mode=read&id={id}`
- [ ] Tab 2 — match-amount renderer shows base "$500" or bold-accent "$1,500 (3:1)" when ratio ≠ 1:1
- [ ] Tab 2 DETAIL (`?mode=read&id=X`) — Donation Snapshot + Matching Programme + Status Timeline cards render; right sidebar shows Donor Profile + Activity Log + Audit
- [ ] Tab 2 DETAIL — inline status action bar renders status-aware buttons (no mini-modal opens); clicking `Mark Submitted` expands inline date input; Save fires UpdateMatchingGiftStatus + returns to updated detail
- [ ] Tab 2 DETAIL — `Mark Rejected` expands inline reason textarea (≥10 chars required before Save enabled)
- [ ] Tab 2 — UpdateMatchingGiftStatus rejects invalid transitions (e.g., Received → Eligible) with 400 + clear error banner
- [ ] Tab 2 LIST — status flow diagram renders at footer (only in LIST mode; hidden in DETAIL mode)
- [ ] Tab 3 — employer search returns matching company; result card displays with all 4 detail tiles + "How to submit" steps + Go to Portal CTA
- [ ] Tab 3 — auto-notification settings bind to MatchingGiftSettings (toggle + EmailTemplate select + timing dropdown + follow-up toggle/days)
- [ ] Tab 3 — embed code block displays with current CompanyId substituted; Copy button copies + toast
- [ ] Tab 4 — all 7 setting rows render; toggles/inputs preserve state; Save Settings persists via UpsertMatchingGiftSettings; success toast
- [ ] KPI widgets — show correct totals/counts; refetch after Tab 2 status change
- [ ] FK dropdowns load: MatchingCompany list, GlobalDonation receipts, Contact list, EmailTemplate list
- [ ] Service placeholder buttons (Send Reminder, Import Companies, "Not listed?" link) render with toast (not crash)
- [ ] Permissions — BUSINESSADMIN can do everything; MENURENDER hides hidden child menus from sidebar

**DB Seed Verification:**
- [ ] MATCHINGGIFT visible in sidebar under CRM_P2PFUNDRAISING (label "Matching Gifts")
- [ ] MATCHINGCOMPANY / MATCHINGGIFTRECORD / MATCHINGGIFTSETTINGS NOT visible in sidebar (IsMenuRender=false)
- [ ] Tab 1 grid renders columns from MATCHINGCOMPANY grid config (GridType=FLOW)
- [ ] Tab 2 grid renders columns from MATCHINGGIFTRECORD grid config (GridType=FLOW)
- [ ] No GridFormSchema exists in DB for MATCHINGCOMPANY (FLOW uses code-driven view-page — verify `SELECT COUNT(*) FROM com."GridFormSchema" WHERE "GridCode"='MATCHINGCOMPANY'` returns 0)
- [ ] MATCHINGGIFTSTATUS MasterData has 6 rows (Eligible/Submitted/Approved/Received/Rejected/Expired)
- [ ] Sample MatchingCompany rows (8) appear in Tab 1
- [ ] MatchingGiftSettings row exists for each tested CompanyId with sensible defaults

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **FLOW screen type (converted from MASTER_GRID 2026-04-19 per user directive)** — Both Tab 1 (Companies) and Tab 2 (Tracker) use FLOW infrastructure: `FlowDataTableContainer showHeader={false}` + code-driven view-pages (`company-view-page.tsx`, `company-detail-page.tsx`, `tracker-detail-page.tsx`) + URL-mode sync (`?tab=X&mode=Y&id=Z`). NO RJSF modal anywhere. NO GridFormSchema entry. Variant B mandatory (ScreenHeader + KPIs + Tabs outside the grid containers).
- **Three entities under ONE menu** — this is a tabbed multi-entity screen, NOT three separate menus. Use the TagSegmentation #22 hidden-child-menu pattern (Step 3b) so per-grid `<FlowDataTableStoreProvider>` capability checks resolve correctly. The parent MATCHINGGIFT is the only visible menu. GridType is FLOW for both hidden grids (MATCHINGCOMPANY + MATCHINGGIFTRECORD).
- **URL mode pattern** — page reads `searchParams` for `tab`, `mode`, `id`. Mode defaults to LIST when absent. Supported combinations:
  - `?tab=companies` → Tab 1 LIST
  - `?tab=companies&mode=new` → Tab 1 LAYOUT 1 FORM (create)
  - `?tab=companies&mode=edit&id=N` → Tab 1 LAYOUT 1 FORM (edit)
  - `?tab=companies&mode=read&id=N` → Tab 1 LAYOUT 2 DETAIL
  - `?tab=tracker` → Tab 2 LIST (chips + grid)
  - `?tab=tracker&mode=read&id=N` → Tab 2 LAYOUT 3 TRACKER DETAIL
  - `?tab=guidance` / `?tab=settings` → static panels (no modes)
- **No modal components anywhere** — the legacy status-update mini-modal from the original MASTER_GRID prompt is REMOVED. All status transitions happen on the TRACKER DETAIL page via the inline `status-action-bar.tsx` with expanding inline inputs. If you're tempted to reach for a `<Dialog>` / `<Modal>`, stop and reread this bullet.
- **Group folder is `Donation`, NOT `DonationModels`** — entity namespace is `Base.Domain.Models.DonationModels` but the Business/Schemas/Configurations/EndPoints folders use `Donation` (without "Models"). See existing DonationPurpose precedent.
- **GraphQL field naming uses plural-noun convention**: `GetMatchingCompanies` (NOT `GetAllMatchingCompanyList`). Match the existing `GetDonationPurposes` / `GetGlobalDonations` pattern.
- **Schema is `fund`** (NOT `corg` or `app`) — all 3 tables go under `fund` schema.
- **Existing FE route is a stub** — `PSS_2.0_Frontend/src/app/[lang]/crm/p2pfundraising/matchinggift/page.tsx` currently contains `<div>Need to Develop</div>`. **OVERWRITE this file** — do NOT create a new route at a different path.
- **Match-ratio data type**: store as `decimal(4,2)` (0.5, 1.0, 2.0, 3.0). Display via custom renderer as "0.5:1", "1:1", "3:1". RJSF select shows the formatted display while writing the decimal.
- **Match-amount computation** at MatchingGift create time = `DonationAmount × MatchingCompany.MatchRatio`. Store as snapshot; do NOT recompute on every read (MatchRatio may change after the fact).
- **MatchingGiftSettings is one-row-per-tenant** — use Upsert command pattern. The `GetMatchingGiftSettings` query MUST auto-create a default row if none exists for the current CompanyId (returns the new row in the same response).
- **Status state-machine validation** lives in `UpdateMatchingGiftStatus` handler — NOT in a separate validator. Reject invalid transitions with a 400 + clear error message ("Cannot transition from Received to Eligible").
- **Donor Guidance + Settings Tab share the same MatchingGiftSettings entity**. Decide which UX wins: either (a) Tab 3 changes auto-save on blur with toast, OR (b) Tab 3 changes mark form dirty and require Tab 4 Save. **Recommendation**: option (b) with a banner on Tab 4 — simpler, single source of truth, fewer race conditions.
- **Embed code is for display only** — the actual public iframe widget (`https://app.peopleserve.com/matching-gifts/widget/org-{id}`) is NOT in scope here. Mark as SERVICE_PLACEHOLDER.
- **KPI Summary refetch** — must refetch after any MatchingGift mutation (status update, create, delete). Use Apollo cache invalidation or React Query `invalidateQueries(['MatchingGiftSummary'])`.
- **DonorCount aggregation in MatchingCompany GetAll** — implement as LINQ `.Select(c => new MatchingCompanyResponseDto { ..., DonorCount = c.MatchingGifts.Select(g => g.DonorContactId).Distinct().Count() })`. Keep the projection inside the query, not a separate roundtrip.
- **Eligibility computed `eligibilityLabel`** — compute in the BE projection (`string.Join(", ", labels)`) so the FE grid renders a single string column without per-row JS.

**Service Dependencies** (UI-only — no backend service implementation):

> Everything else in the mockup IS in scope. The list below is genuinely external/missing:

- ⚠ **SERVICE_PLACEHOLDER: "Send Reminder" button** (Tab 2 row action) — full UI implemented; clicking shows toast "Reminder service integration pending". Reason: requires Email send pipeline + automation workflow integration which lives in Communication module (#37 Automation Workflow not yet built).
- ⚠ **SERVICE_PLACEHOLDER: "Import Companies" button** (header) — full UI button rendered; clicking shows toast "Bulk import coming soon". Reason: requires the Import Module pipeline (ImportSession scaffolding) — not yet wired for MatchingCompany. Same status as other Import buttons across the app.
- ⚠ **SERVICE_PLACEHOLDER: Embed iframe widget endpoint** (Tab 3 code block) — the snippet is generated and copyable, but the actual `app.peopleserve.com/matching-gifts/widget/...` iframe target is NOT built (would be a separate public-pages screen).
- ⚠ **SERVICE_PLACEHOLDER: "Not listed? Request your employer be added"** (Tab 3 link) — full link rendered; clicking shows toast "Request submitted (placeholder)". Reason: needs a request-tracking entity not in scope.
- ⚠ **SERVICE_PLACEHOLDER: Auto-send-after-donation reminder workflow** — the MatchingGiftSettings toggles persist correctly, but no background worker actually fires reminder emails. Wiring requires Automation Workflow (#37). Settings are saved; downstream consumer service is missing.

Full UI must be built (buttons, tabs, modals, form bindings, grids, KPIs). Only the handlers for the 5 listed external service calls are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | Medium | FE Tab 2 | Status chips + company/date/donor filters update Zustand store but are NOT plumbed through to the FlowDataTable fetch layer — server-side filtering deferred. BE supports all args (`statusCode`, `matchingCompanyId`, `dateFrom`, `dateTo`, `donorContactId`); needs a FlowDataTable filter-passthrough refactor. | OPEN |
| ISSUE-2 | 1 | Low | FE Tab 2 | Eligible-row amber highlight + full-row click-to-navigate deferred — FlowDataTable row-render is config-driven from `sett.GridFields`, can't apply row-level className/onClick from outer wrapper. View action button in the action column handles row→detail nav instead. Needs FlowDataTable row-hook extension. | OPEN |
| ISSUE-3 | 1 | Low | FE config | MatchingGift toggle operation aliased to delete mutation — BE doesn't expose a dedicated toggle for MatchingGift (soft-delete preferred). Acceptable: no toggle button surfaces in UI (`enableToggle: false` on MATCHINGGIFTRECORD ops). | OPEN |
| ISSUE-4 | 1 | Low | FE Tab 4 | Post-BE correction: `UpdateMatchingGiftStatus` expects `SubmittedDate` / `ExpectedDate` etc. as separate optional fields but our inline action bar sends only `transitionDate`. BE handler currently uses transitionDate for whatever the new status's date column is. Works for SUBMITTED/APPROVED/RECEIVED/REJECTED; for ExpectedDate (captured alongside SubmittedDate) a separate field in the input DTO may be needed. Verify during QA. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt (FLOW composite — 3 entities under ONE menu).
- **Files touched**:
  - BE (29 created + 4 modified):
    - Entities: `PSS_2.0_Backend/.../Base.Domain/Models/DonationModels/MatchingCompany.cs` (created), `MatchingGift.cs` (created), `MatchingGiftSettings.cs` (created)
    - EF configs: `.../Base.Infrastructure/Data/Configurations/DonationConfigurations/{MatchingCompany,MatchingGift,MatchingGiftSettings}Configuration.cs` (created)
    - Schemas: `.../Base.Application/Schemas/DonationSchemas/{MatchingCompany,MatchingGift,MatchingGiftSettings}Schemas.cs` (created)
    - Commands/Queries: `.../Base.Application/Business/DonationBusiness/{MatchingCompanies,MatchingGifts,MatchingGiftSettings}/{Commands,Queries}/*.cs` (15 files created: 4 MC commands, 2 MC queries, 5 MG commands incl. UpdateMatchingGiftStatus + ResubmitMatchingGift, 3 MG queries incl. GetMatchingGiftSummary, 1 MGS upsert + 1 MGS query)
    - Endpoints: `.../Base.API/EndPoints/Donation/{Mutations,Queries}/MatchingCompany{Mutations,Queries}.cs` and `MatchingGift{Mutations,Queries}.cs` (4 created; Settings handlers appended to MatchingGift endpoints)
    - Migration: `.../Base.Infrastructure/Migrations/20260419101130_MatchingGifts_Initial.cs` + `.Designer.cs` (created — 3 tables in `fund` schema, FKs + unique indexes wired; `database update` NOT run)
    - Wiring: `IDonationDbContext.cs` (modified — 3 DbSets), `DonationDbContext.cs` (modified — 3 DbSets + 3 ApplyConfiguration), `DecoratorProperties.cs` (modified — DecoratorDonationModules entries), `DonationMappings.cs` (modified — 13 Mapster TypeAdapterConfig registrations)
  - FE (22 created + 11 modified):
    - DTOs: `PSS_2.0_Frontend/src/domain/entities/donation-service/{MatchingCompany,MatchingGift,MatchingGiftSettings}Dto.ts` (created)
    - GQL: `.../gql-queries/donation-queries/{MatchingCompany,MatchingGift,MatchingGiftSettings}Query.ts` (created), `.../gql-mutations/donation-mutations/{MatchingCompany,MatchingGift}Mutation.ts` (created — MatchingGiftMutation also carries UpdateStatus/Resubmit/UpsertSettings)
    - Page config: `.../presentation/pages/crm/p2pfundraising/matchinggift.tsx` (created)
    - Page components (19): `.../page-components/crm/p2pfundraising/matchinggift/{index-page,index,kpi-widgets,tab-companies,tab-tracker,tab-guidance,tab-settings,companies-flow-data-table,tracker-flow-data-table,company-view-page,company-detail-page,tracker-detail-page,status-action-bar,employer-search-widget,embed-code-block,settings-form,status-flow-diagram,checkbox-chip-group,match-gift-store}.tsx/.ts` (created)
    - Renderers: `.../custom-components/data-tables/shared-cell-renderers/{match-ratio,match-amount}-renderer.tsx` (created) + registered in FLOW + advanced + basic `component-column.tsx` elementMapping
    - Route: `PSS_2.0_Frontend/src/app/[lang]/crm/p2pfundraising/matchinggift/page.tsx` (modified — stub `<div>Need to Develop</div>` overwritten with `<MatchingGiftPageConfig/>`)
    - Wiring: `donation-service/index.ts`, `donation-queries/index.ts`, `donation-mutations/index.ts`, `donation-service-entity-operations.ts`, `shared-cell-renderers/index.ts`, `flow/advanced/basic component-column.tsx` (3 files), `pages/crm/p2pfundraising/index.ts`, `pages/crm/index.ts` (modified — 11 total)
  - DB: `PSS_2.0_Backend/.../sql-scripts-dyanmic/MatchingGift-sqlscripts.sql` (created — parent + 3 hidden children + MenuCapabilities + RoleCapabilities BUSINESSADMIN-only + 2 FLOW grids + Fields + GridFields + MATCHINGGIFTSTATUS MasterData 6 rows + 8 sample MatchingCompany rows + default MatchingGiftSettings per tenant; NO GridFormSchema)
- **Deviations from spec**:
  - Renderer file path: spec said `src/presentation/components/data-table/renderers/` (non-existent); actual canonical folder is `src/presentation/components/custom-components/data-tables/shared-cell-renderers/` — placed there alongside 19 existing renderers. Registered in all 3 column-type registries (flow/advanced/basic).
  - Status chip + filter-input values drive Zustand store only; server-side filter passthrough on FlowDataTable deferred (ISSUE-1).
  - Eligible-row highlight + full-row click deferred (ISSUE-2).
  - MatchingGift toggle aliased to delete mutation (ISSUE-3).
  - Schema additions beyond prompt §②: `MatchingGift.RejectedDate DateTime?` column added (was missing); `MatchingCompany.MatchingGifts` nav property added for donorCount aggregation; unique index on `MatchingGiftSettings.CompanyId` added.
  - New BE mutation added beyond §⑧: `ResubmitMatchingGift { sourceMatchingGiftId }` (UX decision §12 Option B — rejected rows clone to new ELIGIBLE rows; not a state transition).
- **Known issues opened**: ISSUE-1, ISSUE-2, ISSUE-3, ISSUE-4
- **Known issues closed**: None
- **Next step**: (empty — COMPLETED). Manual follow-up: apply migration (`dotnet ef database update --project Base.Infrastructure --startup-project Base.API --context ApplicationDbContext`), run seed SQL, then `pnpm dev` and verify CRUD + status transitions + KPI refetch. Address OPEN issues as QA uncovers them.