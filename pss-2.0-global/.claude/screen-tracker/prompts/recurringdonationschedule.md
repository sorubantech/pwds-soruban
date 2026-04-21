---
screen: RecurringDonationSchedule
registry_id: 8
module: Fundraising (CRM)
status: PENDING
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
- [x] HTML mockup analyzed (grid + KPI widgets + Failed Alert Banner + 460px detail slide-in panel + advanced filters)
- [x] Existing code reviewed (BE: entity + 1 toggle + 2 queries; FE: old read-only data-table + full-page view, NOT a FLOW view-page)
- [x] Business rules + workflow extracted (Active → Paused → Active → Cancelled; Active → Failed via consecutive failures)
- [x] FK targets resolved (Contact + PaymentGateway + Currency + 5 MasterData typeCodes + DonationPurpose)
- [x] File manifest computed (~22 BE create/modify + ~20 FE create/modify, large ALIGN)
- [x] Approval config pre-filled (RECURRINGDONOR menu code, OrderBy=2 under CRM_DONATION)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM + DETAIL drawer specified)
- [ ] User Approval received
- [ ] Backend code generated
- [ ] Backend wiring complete
- [ ] Frontend code generated (view-page with 3 modes + Zustand store + 460px detail drawer)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW; +5 MasterData seed gaps)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at /[lang]/crm/donation/recurringdonors
- [ ] Grid loads with 12 columns, 6 filter chips (All/Active/Paused/Cancelled/Failed/Expiring Soon), advanced filter panel
- [ ] 4 KPI widgets render with values from `getRecurringDonationScheduleSummary`
- [ ] Failed Payments Alert Banner renders when `failedThisMonth > 0`, expands/collapses
- [ ] Failed Alert inline actions work: Contact Donor, Retry, Pause, Cancel
- [ ] `?mode=new`: empty FORM renders (Donor + Schedule + Payment + Distribution sections)
- [ ] `?mode=edit&id=X`: FORM pre-filled
- [ ] Row click → 460px right-side detail drawer slides in (NOT navigate)
- [ ] Drawer shows: Donor mini card, Schedule Info, Payment Method, Distribution table, Charge History (last 6)
- [ ] Drawer footer actions: Pause, Cancel, Update Payment, Edit Amount
- [ ] Pause/Resume mutation toggles status + clears NextBillingDate
- [ ] Cancel mutation sets status + CancelledAt + CancelledReason
- [ ] Retry mutation creates a charge attempt (SERVICE_PLACEHOLDER) and resets ConsecutiveFailures on success
- [ ] DB Seed — menu visible under CRM_DONATION, OrderBy=2, "Failed" + "Semi-Annual" MasterData rows added

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: RecurringDonationSchedule
Module: Fundraising (CRM)
Schema: fund
Group: DonationModels

Business: This screen is the **operational hub for managing recurring donation subscriptions** — donors who have authorized periodic charges (monthly / quarterly / semi-annual / annual) against a stored payment method. NGO finance/admin staff use it daily to monitor billing health: how much MRR (Monthly Recurring Revenue) the org is collecting, how many schedules are active vs paused vs cancelled, and — critically — which charges failed and need recovery action (contact donor, retry, update card, or cancel). Each schedule belongs to a Contact (donor), is tied to a PaymentGateway (Stripe / PayPal / Razorpay) with a stored payment-method token, and distributes the donation across one or more DonationPurposes. The screen sits beside All Donations / Cheque / In-Kind / Pledge under the CRM_DONATION menu — but unlike those one-off donation screens, RecurringDonation is **subscription-shaped**: most records originate from gateway webhooks (when a donor opts into recurring on the public donation page), and admin actions are mostly state-machine transitions (Pause / Resume / Cancel / Retry) rather than free-form data entry. The detail view is a **460px right-side slide-in drawer** (not a separate page) that surfaces donor info, schedule terms, payment method on file, distribution allocation, and the last 6 charge attempts with success/failure flags.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Existing entity is `RecurringDonationSchedule` (NOT `RecurringDonation`) at `Base.Domain/Models/DonationModels/RecurringDonationSchedule.cs`. Audit columns inherited from base.
> **CompanyId IS persisted** on this entity (existing) — but FE never sends it; resolved from HttpContext on Create/Update.

Table: `fund."RecurringDonationSchedules"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| RecurringDonationScheduleId | int | — | PK | — | Primary key |
| **RecurringDonationScheduleCode** ⭐ NEW | string | 50 | YES | — | Auto-gen `REC-{NNNN}` if empty. **Currently MISSING from entity — must add column + migration** |
| CompanyId | int | — | YES | app.Companies | Tenant scope (existing) |
| PaymentMethodTokenId | int | — | YES | fund.PaymentMethodTokens | Stored card/UPI token (existing) |
| PaymentGatewayId | int | — | YES | shared.PaymentGateways | Stripe / PayPal / Razorpay (existing) |
| GatewaySubscriptionId | string | 200 | YES | — | Gateway-side sub ID (e.g., `sub_1NqKr2LkdIwHu7`) (existing) |
| GatewayCustomerId | string | 200 | YES | — | Gateway-side customer ID (existing) |
| GatewayPlanId | string | 100 | NO | — | Optional plan ID (existing) |
| CurrencyId | int | — | YES | app.Currencies | (existing) |
| Amount | decimal(18,2) | — | YES | — | Per-charge amount (existing) |
| FrequencyId | int | — | YES | shared.MasterData (RECURRINGFREQUENCY) | (existing) |
| StartDate | DateTime | — | YES | — | (existing) |
| EndDate | DateTime? | — | NO | — | Null = ongoing (existing) |
| NextBillingDate | DateTime? | — | NO | — | Null when Paused/Cancelled (existing) |
| LastChargedDate | DateTime? | — | NO | — | (existing) |
| LastChargeStatusId | int? | — | NO | shared.MasterData (CHARGESTATUS) | Success / Failed (existing) |
| LastGatewayTransactionId | string | 200 | NO | — | (existing) |
| LastFailureReason | string | 1000 | NO | — | (existing) |
| ConsecutiveFailures | int | — | YES | — | Default 0; ≥3 → status auto-flips to Failed (existing) |
| TotalChargedCount | int | — | YES | — | Lifetime success count (existing) |
| TotalChargedAmount | decimal(18,2) | — | YES | — | Lifetime success sum (existing) |
| ScheduleStatusId | int | — | YES | shared.MasterData (RECURRINGSCHEDULESTATUS) | Active/Paused/Cancelled/Failed/Expired (existing) |
| PausedReason | string | 500 | NO | — | (existing) |
| CancelledAt | DateTime? | — | NO | — | (existing) |
| CancelledReason | string | 500 | NO | — | (existing) |
| DonorEmail | string | 200 | NO | — | Snapshot at sign-up (existing) |
| Note | string | 1000 | NO | — | Admin note (existing) |

**Child Entity** (already exists — no changes):

| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| RecurringDonationScheduleDistribution | 1:Many via RecurringDonationScheduleId, cascade delete | ContactId, DonationPurposeId, ParticipantTypeId, Amount |

**Computed/projected fields** (added in BE projections — NOT new columns):
- `paymentMethodDisplay` — "Visa ••••4242" / "PayPal Balance" / "UPI" — projected by joining PaymentMethodToken (CardBrand + Last4Digits) and PAYMENTMETHODTYPE MasterData
- `frequencySuffix` — "/mo" / "/qtr" / "/yr" — derived in projection from Frequency.dataValue

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and nav properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId (via Distribution) | Contact | Base.Domain/Models/CorgModels/Contact.cs | contacts | displayName / contactCode | ContactResponseDto |
| PaymentGatewayId | PaymentGateway | Base.Domain/Models/SharedModels/PaymentGateway.cs | paymentGateways | paymentGatewayName | PaymentGatewayResponseDto |
| PaymentMethodTokenId | PaymentMethodToken | Base.Domain/Models/DonationModels/PaymentMethodToken.cs | paymentMethodTokensByContact (NEW — see ⑫) | cardBrand+last4Digits | PaymentMethodTokenResponseDto |
| CurrencyId | Currency | Base.Domain/Models/AppModels/Currency.cs | currencies | currencyName / currencyCode | CurrencyResponseDto |
| FrequencyId | MasterData (RECURRINGFREQUENCY) | Base.Domain/Models/SharedModels/MasterData.cs | masterDatas (staticFilter typeCode=RECURRINGFREQUENCY) | dataName | MasterDataResponseDto |
| ScheduleStatusId | MasterData (RECURRINGSCHEDULESTATUS) | Base.Domain/Models/SharedModels/MasterData.cs | masterDatas (staticFilter typeCode=RECURRINGSCHEDULESTATUS) | dataName | MasterDataResponseDto |
| LastChargeStatusId | MasterData (CHARGESTATUS) | Base.Domain/Models/SharedModels/MasterData.cs | masterDatas (staticFilter typeCode=CHARGESTATUS) | dataName | MasterDataResponseDto |
| ParticipantTypeId (Distribution) | MasterData (PARTICIPANTTYPE) | Base.Domain/Models/SharedModels/MasterData.cs | masterDatas (staticFilter typeCode=PARTICIPANTTYPE) | dataName | MasterDataResponseDto |
| DonationPurposeId (Distribution) | DonationPurpose | Base.Domain/Models/FundModels/DonationPurpose.cs | donationPurposes | donationPurposeName | DonationPurposeResponseDto |

**Charge History sub-data**: `PaymentTransaction` filtered by `recurringScheduleId` is fetched via existing `RECURRING_DONOR_TRANSACTIONS_QUERY` — keep this query, re-use in detail drawer.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `RecurringDonationScheduleCode` unique per Company (auto-gen `REC-{NNNN}` if empty)
- `GatewaySubscriptionId` should be unique per Company (gateway-side IDs collision-safe; enforce DB unique-filtered index)

**Required Field Rules:**
- ContactId (in at least one distribution row), Amount > 0, FrequencyId, CurrencyId, PaymentGatewayId, PaymentMethodTokenId, GatewaySubscriptionId, GatewayCustomerId, StartDate are mandatory
- At least 1 Distribution row required; sum of Distribution.Amount must equal Amount

**Conditional Rules:**
- If ScheduleStatus = Paused → NextBillingDate must be NULL; PausedReason must be set
- If ScheduleStatus = Cancelled → CancelledAt + CancelledReason must be set; NextBillingDate must be NULL
- If ScheduleStatus = Failed → ConsecutiveFailures ≥ 3
- EndDate, if set, must be > StartDate

**Business Logic / Workflow** (FLOW state machine):

| State | Transitions Allowed | Side Effects |
|-------|--------------------|--------------|
| Active | → Paused (Pause), → Cancelled (Cancel), → Failed (auto, when ConsecutiveFailures ≥ 3) | NextBillingDate computed from StartDate + Frequency |
| Paused | → Active (Resume), → Cancelled (Cancel) | NextBillingDate cleared on pause; recomputed on resume |
| Failed | → Active (after successful Retry), → Paused (manual), → Cancelled (Cancel) | Retry attempts gateway charge; on success → ConsecutiveFailures=0, status=Active |
| Cancelled | (terminal — no further transitions; no resume) | CancelledAt set; immutable |
| Expired | (terminal — when EndDate reached) | NextBillingDate cleared |

**Code generation:**
- `RecurringDonationScheduleCode` auto-gen pattern: `REC-{0001}` (4-digit padded, per-Company sequence) on Create when empty
- Match existing GlobalDonation / DonationInKind code-gen pattern

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: FLOW with side-drawer DETAIL (sibling pattern: DonationInKind #7)
**Reason**: Transactional/workflow screen with state machine (Active/Paused/Cancelled/Failed), child distribution rows, KPI widgets above grid, custom workflow actions (Pause/Resume/Cancel/Retry), and a 460px right-side slide-in detail drawer (NOT a separate full page route). FORM is a full-page view-page (`?mode=new` and `?mode=edit&id=X`); DETAIL is the side drawer triggered by row click on grid (no URL change OR `?mode=read&id=X` synced).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — partly missing: only Toggle + 2 queries exist; need Create, Update, Delete, GetSummary, Pause, Resume, Cancel, Retry
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation — RecurringDonationScheduleDistributions (diff-persist on Create + Update)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 9: Contact, PaymentGateway, PaymentMethodToken, Currency, Frequency, ScheduleStatus, LastChargeStatus, DonationPurpose, ParticipantType)
- [x] Unique validation — RecurringDonationScheduleCode + GatewaySubscriptionId (filtered unique per Company)
- [x] Workflow commands — `PauseRecurringDonationSchedule`, `ResumeRecurringDonationSchedule`, `CancelRecurringDonationSchedule`, `RetryRecurringDonationSchedule` (Retry is SERVICE_PLACEHOLDER — see ⑫)
- [ ] File upload command — N/A
- [x] Custom business rule validators — distribution-sum, status-transition guard, code-immutable-after-create, system-cancel-immutable

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — Variant B (ScreenHeader + KPI widgets + DataTableContainer showHeader=false)
- [x] view-page.tsx with 3 URL modes (new, edit, read-as-drawer)
- [x] React Hook Form (for FORM layout in `?mode=new`/`?mode=edit`)
- [x] Zustand store (`recurringdonationschedule-store.ts`) — drawer open state, selectedScheduleId, filterChip, failedAlertExpanded, action modal states
- [x] Unsaved changes dialog (FORM)
- [x] FlowFormPageHeader (FORM mode — Back, Save buttons)
- [x] **460px right-side slide-in DETAIL drawer** (component reuse from DonationInKind #7 pattern: `dik-detail-drawer` / 520px → here: `recurring-schedule-detail-drawer` / 460px)
- [x] Child grid inside form — Distribution rows (Contact + Purpose + ParticipantType + Amount, inline add/remove with running sum vs Amount)
- [x] Workflow status badge + action buttons — Pause/Resume/Cancel + Failed-only Retry/Update Payment/Contact Donor
- [x] **Failed Payments Alert Banner** (collapsible, expanded by default, table of failed schedules with inline action buttons)
- [x] **Summary cards / count widgets** above grid — 4 KPIs: Active Schedules, MRR, Failed This Month, Avg Duration
- [x] Grid aggregation columns — Total Charged ($600 + count subtitle), Failures count

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup (`html_mockup_screens/screens/fundraising/recurring-donations.html`) — this IS the design spec.

### Grid/List View

**Display Mode**: `table` (default — transactional list, NOT card-grid)

**Layout Variant**: `widgets-above-grid+side-panel` — Variant B mandatory.
- ScreenHeader at top (title + subtitle + actions: Back to Donations, Export, +New Schedule)
- 4 KPI widgets in `stats-grid` (auto-fit, minmax 210px)
- **Failed Payments Alert Banner** between widgets and grid (collapsible)
- `<DataTableContainer showHeader={false}>` for the grid

**Grid Columns** (12 columns in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Schedule ID | recurringDonationScheduleCode | text-bold + accent color | 110px | YES | Click → opens drawer |
| 2 | Donor | donorContactName + donorAvatar | contact-avatar-name renderer | 200px | YES | Avatar (initials, color) + name link → contact profile (SERVICE_PLACEHOLDER) |
| 3 | Amount | amount + currencyCode + frequencySuffix | recurring-amount renderer (NEW) | 120px | YES | Monospace; "$50.00 /mo" |
| 4 | Frequency | frequencyName | freq-badge renderer (NEW) | 100px | YES | Color-coded pill: Monthly=blue, Quarterly=purple, Annual=green, Semi-Annual=orange |
| 5 | Gateway | paymentGatewayName + gatewayCode | gateway-cell renderer (NEW) | 110px | NO | Stripe(violet S)/PayPal(navy P)/Razorpay(navy R) icon + text |
| 6 | Payment Method | paymentMethodDisplay | payment-method-cell renderer (NEW) | 140px | NO | Card icon (Visa/MC/Amex via fa-cc-*) + "•••• last4" OR "UPI" / "PayPal Balance" / "Bank Debit" |
| 7 | Status | scheduleStatusName | status-badge renderer (REUSE) | 90px | YES | Active=green, Paused=yellow, Cancelled=grey, Failed=red |
| 8 | Next Billing | nextBillingDate | DateOnlyPreview (REUSE) | 110px | YES | Renders "—" when null |
| 9 | Last Charged | lastChargedDate + lastChargeStatusName | last-charged-cell renderer (NEW) | 120px | NO | "Apr 1 ✓" green-check OR "Apr 1 ✗" red-x |
| 10 | Total Charged | totalChargedAmount + totalChargedCount + currencyCode | total-charged-cell renderer (NEW) | 110px | YES | Monospace amount + "(12)" subtitle |
| 11 | Failures | consecutiveFailures | failure-count renderer (NEW) | 70px | YES | Bold number; red when ≥1 |
| 12 | Actions | (action menu) | row-action-menu | 60px | NO | View Details / Pause/Resume / Update Payment / Cancel; Failed rows also: Retry Now / Contact Donor |

**Search/Filter Fields**: Donor name, donor email, Schedule ID

**Filter Chips** (6 — top of grid):
- All (default active)
- Active
- Paused
- Cancelled
- Failed
- Expiring Soon (computed: EndDate within next 30 days)

**Advanced Filter Panel** (collapsible, "Advanced" button):
- Frequency (dropdown: All / Monthly / Quarterly / Semi-Annual / Annual)
- Payment Gateway (dropdown: All / Stripe / PayPal / Razorpay)
- Amount Min (number)
- Amount Max (number)
- Currency (dropdown: All / USD / AED / INR / NGN / MAD / BRL / JPY)
- Created From (date)
- Created To (date)
- Next Billing From (date)
- Next Billing To (date)
- Apply / Clear buttons

**Grid Actions**: View Details (→ open drawer), Pause / Resume (status-aware), Update Payment (SERVICE_PLACEHOLDER), Cancel; **Failed-row only**: Retry Now (SERVICE_PLACEHOLDER), Contact Donor (SERVICE_PLACEHOLDER)

**Row Click**: Opens DETAIL DRAWER (slide-in from right, 460px). URL syncs to `?mode=read&id={id}` for back-button + deep-link support; closing drawer clears URL params. **NO navigation to a separate page.**

---

### Page Widgets & Summary Cards (above grid — top-of-page)

**Widgets**: 4 KPI cards in a responsive grid (`auto-fit, minmax(210px, 1fr)`).

| # | Widget Title | Value Source | Display Type | Position | Color/Icon |
|---|-------------|-------------|-------------|----------|-----------|
| 1 | Active Schedules | summary.activeCount | number + delta | left | green / `fa-repeat`; subtitle "+34 this month" (delta = currentMonth − previousMonth) |
| 2 | Monthly Recurring Revenue | summary.monthlyRecurringRevenue | currency | center-left | teal / `fa-dollar-sign`; subtitle "+8.2% vs last month" (% delta) |
| 3 | Failed This Month | summary.failedThisMonth | number | center-right | red / `fa-exclamation-triangle`; subtitle "12 retried, 8 recovered" (retriedCount + recoveredCount) |
| 4 | Avg Duration | summary.avgDurationMonths | number + "months" suffix | right | blue / `fa-calendar`; subtitle "Across all active schedules" |

**Summary GQL Query**:
- Query name: `getRecurringDonationScheduleSummary` (returns `RecurringDonationScheduleSummaryDto`)
- Fields: `activeCount`, `activeCountDelta`, `monthlyRecurringRevenue`, `mrrDeltaPercent`, `failedThisMonth`, `retriedThisMonth`, `recoveredThisMonth`, `avgDurationMonths`, `currencyCode` (display currency for MRR — Company default)
- Added to `RecurringDonationScheduleQueries.cs` alongside existing GetAll + GetById

---

### Failed Payments Alert Banner (above grid, below KPIs)

Collapsible banner that surfaces failed schedules needing attention.

**Visibility**: Render when `summary.failedThisMonth > 0`; default **expanded**; collapses on chevron click; persisted in Zustand `failedAlertExpanded`.

**Header line** (always visible):
- Icon: `fa-triangle-exclamation` (red)
- Text: `{failedThisMonth} recurring payments failed this month. {retriedThisMonth} auto-retried, {recoveredThisMonth} recovered, **{needsAttentionCount} need attention.**`
- Right side: chevron toggle + "Details"

**Body table** (when expanded — top 5 failed schedules ordered by ConsecutiveFailures DESC, LastChargedDate DESC):
| Column | Source |
|--------|--------|
| Donor | first Distribution.Contact.DisplayName |
| Amount | "$100/mo" (amount + currencyCode + frequencySuffix) |
| Last Attempt | LastChargedDate (formatted "Apr 1") |
| Failures | ConsecutiveFailures (red, bold; suffix "consecutive" if ≥3) |
| Reason | LastFailureReason (truncate at 30 chars + tooltip) |
| Actions | Contact Donor / Retry / Cancel / Pause (Pause when failures < 3; Cancel when ≥3) |

**Data source**: dedicated query `getRecurringDonationScheduleFailedAlert` returns `RecurringDonationScheduleFailedAlertDto[]` (top 5 failed in current month). Avoids re-querying full grid.

---

### Grid Aggregation Columns

**Aggregation Columns** (per-row computed values — already on entity, no new aggregation needed):
| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Total Charged | Lifetime success sum + count | `totalChargedAmount` + `totalChargedCount` columns | direct projection (already on entity) |
| Failures | Consecutive failures since last success | `consecutiveFailures` column | direct projection (already on entity) |

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

> **Mode mapping for this screen** (deviation from default FLOW pattern):
>
> ```
> URL MODE                              UI LAYOUT
> ─────────────────────────────────     ──────────────────────────
> /recurringdonors                  →   GRID (default)
> /recurringdonors?mode=new         →   FORM LAYOUT (new schedule, full page)
> /recurringdonors?mode=edit&id=X   →   FORM LAYOUT (pre-filled, full page)
> /recurringdonors?mode=read&id=X   →   GRID + DETAIL DRAWER (slide-in 460px right)
>                                       ── NOT a separate page route ──
> ```
>
> The DETAIL is a slide-in drawer (sibling pattern: DonationInKind #7 `dik-detail-drawer` 520px). Closing the drawer (X / Esc / overlay click) navigates back to `/recurringdonors` (no params).

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

> Full-page form for manually creating an admin-side recurring schedule (most schedules originate via gateway webhooks; this is the manual fallback).
> Built with React Hook Form. Sectioned cards.

**Page Header**: FlowFormPageHeader with Back (→ `/recurringdonors`), Save buttons + unsaved-changes dialog

**Section Container Type**: cards (vertical stack, 4 sections)

**Form Sections** (in display order):
| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | fa-info-circle | Schedule Info | 2-column | expanded | RecurringDonationScheduleCode (auto, readonly), StartDate, EndDate (optional), FrequencyId, CurrencyId, Amount, Note |
| 2 | fa-credit-card | Payment Setup | 2-column | expanded | PaymentGatewayId, PaymentMethodTokenId (cascaded by Donor selection), GatewaySubscriptionId, GatewayCustomerId, GatewayPlanId (optional), DonorEmail |
| 3 | fa-people-group | Distribution | full-width | expanded | **Inline child grid** — rows of (ContactId, DonationPurposeId, ParticipantTypeId, Amount); add/remove buttons; running sum vs Amount with red highlight when mismatched |
| 4 | fa-clock | Status (edit-mode only) | 2-column | collapsed | ScheduleStatusId (read-only display), PausedReason / CancelledReason / LastFailureReason (conditional based on status) |

**Field Widget Mapping**:
| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| RecurringDonationScheduleCode | 1 | text (readonly) | "Auto-generated" | max 50 | Auto-gen REC-{NNNN} on save |
| StartDate | 1 | datepicker | "Select start date" | required | Default: today |
| EndDate | 1 | datepicker | "Optional — leave blank for ongoing" | > StartDate | — |
| FrequencyId | 1 | ApiSelectV2 | "Select frequency" | required | Query: `masterDatas` typeCode=RECURRINGFREQUENCY |
| CurrencyId | 1 | ApiSelectV2 | "Select currency" | required | Query: `currencies` |
| Amount | 1 | number (large, monospace) | "0.00" | required, > 0, decimal(2) | — |
| Note | 1 | textarea | "Optional admin note" | max 1000 | — |
| PaymentGatewayId | 2 | ApiSelectV2 | "Select gateway" | required | Query: `paymentGateways` |
| PaymentMethodTokenId | 2 | ApiSelectV2 | "Select payment method" | required | Query: `paymentMethodTokensByContact` (NEW BE — see ⑫); cascaded by donor — disabled until at least one Distribution.Contact selected |
| GatewaySubscriptionId | 2 | text | "sub_xxx" | required, max 200 | Required because we don't actually create a real gateway sub here (manual entry) |
| GatewayCustomerId | 2 | text | "cus_xxx" | required, max 200 | — |
| GatewayPlanId | 2 | text | "Optional plan ID" | max 100 | — |
| DonorEmail | 2 | email | "donor@example.com" | email format, max 200 | Snapshot at sign-up |
| ContactId (per row) | 3 | ApiSelectV2 | "Search donor" | required | Query: `contacts`; first row's contact drives PaymentMethodToken cascade |
| DonationPurposeId (per row) | 3 | ApiSelectV2 | "Select purpose" | required | Query: `donationPurposes` |
| ParticipantTypeId (per row) | 3 | ApiSelectV2 | "Self / Family / etc." | required | Query: `masterDatas` typeCode=PARTICIPANTTYPE |
| Distribution.Amount (per row) | 3 | number | "0.00" | > 0; sum must equal parent.Amount | Inline; validates on blur and on parent.Amount change |

**Special Form Widgets**:

- **Conditional Sub-forms** (status section, edit-mode only):
  | Trigger Field | Trigger Value | Sub-form Fields (read-only display) |
  |--------------|---------------|-----------------|
  | ScheduleStatus | Paused | PausedReason |
  | ScheduleStatus | Cancelled | CancelledAt, CancelledReason |
  | ScheduleStatus | Failed | LastFailureReason, ConsecutiveFailures |

- **Inline Mini Display** — no donor card surfaces in FORM (donor is per-distribution-row; no global donor card)

**Child Grids in Form**:
| Child | Grid Columns | Add/Edit Method | Delete | Notes |
|-------|-------------|----------------|--------|-------|
| RecurringDonationScheduleDistribution | Contact, Purpose, ParticipantType, Amount | Inline row (RHF `useFieldArray`) | Remove row icon (with confirm if data entered) | "Add Distribution" button at bottom; running sum vs Amount with red badge when mismatched |

---

#### LAYOUT 2: DETAIL (mode=read) — 460px Right-Side Slide-In Drawer

> NOT a full-page route — a drawer that slides in from the right when user clicks a row in the grid.
> Component name: `recurring-schedule-detail-drawer.tsx` (mirrors DonationInKind `dik-detail-drawer.tsx` pattern, narrower 460px).
> URL syncs to `?mode=read&id=X` (for back-button + deep-link support).

**Drawer Header**:
- Icon: `fa-repeat` (accent color)
- Schedule code: `REC-0001`
- Status badge (right-aligned within title block)
- Close button (X, top-right) — also closes on Esc / overlay click

**Drawer Body** (scrollable, 6 sections):

| # | Section Title | Content |
|---|--------------|---------|
| 1 | Donor | Mini card — avatar (initials, color), name (link to contact profile — SERVICE_PLACEHOLDER), email, donor score badge (engagement-score-badge — REUSE from Family #20) |
| 2 | Schedule Info | Detail rows (label : value): Schedule ID, Status (badge), Created Date, Gateway Sub ID (monospace), Amount (with currency suffix), Frequency, Start Date, End Date ("Not set (ongoing)" when null) |
| 3 | Payment Method | Card (icon + "Visa ••••4242"), Expiry ("12/2028"), Token Status (Active/Expired/Revoked/Failed — colored) — sourced from PaymentMethodToken nav |
| 4 | Distribution | Compact 2-column table — Purpose, Amount (right-aligned, bold) |
| 5 | Charge History (Last 6) | Table — Date, Amount, Status (icon + text + retry-arrow indicator if retried-after-fail), TransactionId (monospace, small), Failure Reason (small text) — sourced via existing `RECURRING_DONOR_TRANSACTIONS_QUERY` (PaymentTransactions filtered by recurringScheduleId, top 6 ordered by Date DESC) |
| 6 | Audit Trail (collapsible, default collapsed) | Created By + Date, Modified By + Date, status-change timeline (placeholder if no audit-log table) |

**Drawer Footer Actions** (sticky, bottom):
- **Pause Schedule** (warning button — visible when Status = Active) — opens confirm modal with optional PausedReason input
- **Resume Schedule** (primary button — visible when Status = Paused) — direct mutation
- **Cancel Schedule** (danger button — visible when Status ≠ Cancelled) — opens confirm modal with required CancelledReason input
- **Update Payment** (primary button — always visible) — opens modal "Update payment method" (SERVICE_PLACEHOLDER — wires to toast)
- **Edit Amount** (outline button — always visible) — opens inline modal to edit Amount; recomputes future NextBillingDate
- **Retry Now** (warning button — visible when Status = Failed) — calls `retryRecurringDonationSchedule` mutation (SERVICE_PLACEHOLDER)
- **Contact Donor** (outline button — visible when Status = Failed) — navigates to email-campaign-builder with donor pre-selected (SERVICE_PLACEHOLDER)

---

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User lands on `/recurringdonors` → **GRID** loads with KPI widgets, Failed Alert Banner (if any), 6 filter chips, advanced filter button, search bar
2. User clicks a row → URL: `?mode=read&id=243` → **DETAIL DRAWER** slides in (460px from right); grid stays visible behind overlay
3. User closes drawer (X / Esc / overlay click) → URL: `/recurringdonors` (no params) → drawer slides out
4. User clicks "+New Schedule" → URL: `?mode=new` → **FORM LAYOUT** (full page, replaces grid)
5. User fills FORM → Save → API creates record → URL: `?mode=read&id={newId}` → returns to GRID with DETAIL DRAWER auto-opened on the new record
6. User clicks "Edit" inside drawer header (or "Edit Amount" footer for partial edit) → URL: `?mode=edit&id=243` → **FORM LAYOUT** pre-filled
7. From drawer footer: Pause/Cancel/Resume/Retry → confirm modal → mutation → drawer refetches & shows new status; grid row updates inline
8. From Failed Alert Banner: inline action buttons (Contact / Retry / Cancel / Pause) — same handlers as drawer footer
9. Filter chip click → grid refetches with `chip` param; URL: `?chip=failed` etc. (chip state in Zustand + URL sync)
10. Advanced filter Apply → URL: `?freq=monthly&gateway=stripe&amountMin=100&...` → grid refetches
11. Back: clicks back button → URL: `/recurringdonors` (no params) → returns to default grid view
12. Unsaved changes: dirty FORM + navigate → confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: DonationInKind (FLOW with side drawer — Wave 1.7, completed 2026-04-19)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| DonationInKind | RecurringDonationSchedule | Entity/class name |
| donationInKind | recurringDonationSchedule | Variable/field names |
| DonationInKindId | RecurringDonationScheduleId | PK field |
| DonationInKinds | RecurringDonationSchedules | Table name, collection names |
| donation-in-kind | recurring-donation-schedule | (kebab-case — used sparingly) |
| donationinkind | recurringdonationschedule | (FE folder candidate — but use existing `recurringdonors`) |
| DONATIONINKIND | RECURRINGDONOR | Grid code, menu code (existing — DO NOT change) |
| fund | fund | DB schema (same) |
| Donation | Donation | Backend group name (Models/Schemas/Business — same) |
| DonationModels | DonationModels | Namespace suffix (same) |
| CRM_DONATION | CRM_DONATION | Parent menu code (same) |
| CRM | CRM | Module code (same) |
| crm/donation/donationinkind | crm/donation/recurringdonors | FE route path |
| donation-service | donation-service | FE service folder name (same) |
| dik-detail-drawer | recurring-schedule-detail-drawer | Detail drawer component name |

> **NOTE on FE folder name**: existing FE folder is `recurringdonors` (plural, no entity suffix). Keep this — menu URL already registered as `crm/donation/recurringdonors` and changing it would orphan the menu seed. The Zustand store and components live under this folder.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files — Existing (audit + modify)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/RecurringDonationSchedule.cs` | MODIFY: add `RecurringDonationScheduleCode` (string 50, unique-per-Company); migration |
| 2 | EF Config | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/DonationConfigurations/RecurringDonationScheduleConfiguration.cs` | MODIFY: add unique-filtered-index on `RecurringDonationScheduleCode` per Company; add filtered unique on `GatewaySubscriptionId` per Company |
| 3 | Schemas (DTOs) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/DonationSchemas/RecurringDonationScheduleSchemas.cs` | MODIFY: add `RecurringDonationScheduleCode` to RequestDto + ResponseDto; add projected fields to ResponseDto: `paymentMethodDisplay`, `frequencySuffix`, `donorContactName`, `donorContactCode`, `donorAvatarColor`, `frequencyName`, `paymentGatewayName`, `paymentGatewayCode`, `currencyCode`, `scheduleStatusName`, `lastChargeStatusName`; add `RecurringDonationScheduleSummaryDto`; add `RecurringDonationScheduleFailedAlertDto` |
| 4 | Toggle Command | `.../DonationBusiness/RecurringDonationSchedules/Commands/ToggleRecurringDonationSchedule.cs` | KEEP (works for IsActive flag); rename GQL field if needed for FE clarity |
| 5 | GetAll Query | `.../DonationBusiness/RecurringDonationSchedules/Queries/GetRecurringDonationSchedule.cs` | MODIFY: add chip filter args (`chip` enum or scheduleStatusCode), advanced-filter args (frequencyId, paymentGatewayId, amountMin, amountMax, currencyId, createdFrom/To, nextBillingFrom/To), Include PaymentMethodToken + projected fields, add expiringSoon computation |
| 6 | GetById Query | `.../DonationBusiness/RecurringDonationSchedules/Queries/GetRecurringDonationScheduleById.cs` | MODIFY: include PaymentMethodToken nav, project all 11 new fields |

### Backend Files — NEW (create)

| # | File | Path |
|---|------|------|
| 7 | Create Command | `.../DonationBusiness/RecurringDonationSchedules/Commands/CreateRecurringDonationSchedule.cs` |
| 8 | Update Command | `.../DonationBusiness/RecurringDonationSchedules/Commands/UpdateRecurringDonationSchedule.cs` |
| 9 | Delete Command | `.../DonationBusiness/RecurringDonationSchedules/Commands/DeleteRecurringDonationSchedule.cs` |
| 10 | Pause Command | `.../DonationBusiness/RecurringDonationSchedules/Commands/PauseRecurringDonationSchedule.cs` |
| 11 | Resume Command | `.../DonationBusiness/RecurringDonationSchedules/Commands/ResumeRecurringDonationSchedule.cs` |
| 12 | Cancel Command | `.../DonationBusiness/RecurringDonationSchedules/Commands/CancelRecurringDonationSchedule.cs` |
| 13 | Retry Command (SERVICE_PLACEHOLDER) | `.../DonationBusiness/RecurringDonationSchedules/Commands/RetryRecurringDonationSchedule.cs` |
| 14 | UpdatePayment Command (SERVICE_PLACEHOLDER) | `.../DonationBusiness/RecurringDonationSchedules/Commands/UpdateRecurringDonationSchedulePayment.cs` |
| 15 | EditAmount Command | `.../DonationBusiness/RecurringDonationSchedules/Commands/EditRecurringDonationScheduleAmount.cs` |
| 16 | GetSummary Query | `.../DonationBusiness/RecurringDonationSchedules/Queries/GetRecurringDonationScheduleSummary.cs` |
| 17 | GetFailedAlert Query | `.../DonationBusiness/RecurringDonationSchedules/Queries/GetRecurringDonationScheduleFailedAlert.cs` |
| 18 | GetPaymentMethodTokens (helper) | `.../DonationBusiness/PaymentMethodTokens/Queries/GetPaymentMethodTokensByContact.cs` |
| 19 | EF Migration | `.../Base.Infrastructure/Data/Migrations/{timestamp}_AddRecurringDonationScheduleCode.cs` |

### Backend Endpoints — Existing (modify)

| # | File | Path | Action |
|---|------|------|--------|
| 20 | Mutations | `Base.API/EndPoints/Donation/Mutations/RecurringDonationScheduleMutations.cs` | ADD: createRecurringDonationSchedule, updateRecurringDonationSchedule, deleteRecurringDonationSchedule, pauseRecurringDonationSchedule, resumeRecurringDonationSchedule, cancelRecurringDonationSchedule, retryRecurringDonationSchedule, updateRecurringDonationSchedulePayment, editRecurringDonationScheduleAmount |
| 21 | Queries | `Base.API/EndPoints/Donation/Queries/RecurringDonationScheduleQueries.cs` | ADD: getRecurringDonationScheduleSummary, getRecurringDonationScheduleFailedAlert, paymentMethodTokensByContact |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IDonationDbContext.cs | (already has DbSet — verify) |
| 2 | DonationDbContext.cs | (already has DbSet — verify) |
| 3 | DecoratorProperties.cs | Verify `DecoratorDonationModules.RecurringDonationSchedule` registered |
| 4 | DonationMappings.cs | Add Mapster configs for: ResponseDto + DistributionResponseDto + new SummaryDto + FailedAlertDto |
| 5 | NotifyMappings.cs | (no changes — Donation lives in Donation group) |

### Frontend Files — Existing (audit + replace)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO | `Pss2.0_Frontend/src/domain/entities/donation-service/RecurringDonationScheduleDto.ts` | MODIFY: add 11 projected ResponseDto fields + Code field + SummaryDto + FailedAlertDto |
| 2 | GQL Query | `Pss2.0_Frontend/src/infrastructure/gql-queries/donation-queries/RecurringDonationScheduleQuery.ts` | MODIFY: add `recurringDonationScheduleCode` + 11 projected fields to LIST query; add SUMMARY_QUERY and FAILED_ALERT_QUERY; add chip + advanced-filter args |
| 3 | Recurring Donor Transactions Query | `.../donation-queries/RecurringDonorViewQuery.ts` | KEEP as-is (used by drawer Charge History) — verify field name `donorAmount` aligns with FE rendering |
| 4 | GQL Mutation | `Pss2.0_Frontend/src/infrastructure/gql-mutations/donation-mutations/RecurringDonationScheduleMutation.ts` | MODIFY: add CREATE, UPDATE, DELETE, PAUSE, RESUME, CANCEL, RETRY, UPDATE_PAYMENT, EDIT_AMOUNT mutations |
| 5 | Existing data-table | `.../page-components/crm/donation/recurringdonors/data-table.tsx` | DELETE (replaced by index-page Variant B) |
| 6 | Existing recurring-donor-view | `.../page-components/crm/donation/recurringdonors/view/recurring-donor-view.tsx` | DELETE (replaced by drawer); preserve any shared sub-components used elsewhere (verify before delete) |
| 7 | Route stub | `Pss2.0_Frontend/src/app/[lang]/crm/donation/recurringdonors/page.tsx` | OVERWRITE (renders new index-page) |

### Frontend Files — NEW (create)

| # | File | Path |
|---|------|------|
| 8 | Page Config | `.../presentation/pages/crm/donation/recurringdonationschedule.tsx` (or rename existing page-config) |
| 9 | Index Page (entry) | `.../page-components/crm/donation/recurringdonors/index.tsx` |
| 10 | Index Page Variant B | `.../page-components/crm/donation/recurringdonors/index-page.tsx` |
| 11 | View Page (FORM, 3 modes) | `.../page-components/crm/donation/recurringdonors/view-page.tsx` |
| 12 | Zustand Store | `.../page-components/crm/donation/recurringdonors/recurringdonationschedule-store.ts` |
| 13 | Detail Drawer (460px) | `.../page-components/crm/donation/recurringdonors/recurring-schedule-detail-drawer.tsx` |
| 14 | KPI Widgets | `.../page-components/crm/donation/recurringdonors/recurring-widgets.tsx` (4 cards, takes summary as prop) |
| 15 | Failed Alert Banner | `.../page-components/crm/donation/recurringdonors/failed-payments-alert-banner.tsx` (collapsible, takes failedAlert query result as prop) |
| 16 | Filter Chips Bar | `.../page-components/crm/donation/recurringdonors/recurring-filter-chips.tsx` (6 chips) |
| 17 | Advanced Filter Panel | `.../page-components/crm/donation/recurringdonors/recurring-advanced-filters.tsx` (collapsible, 9 fields) |
| 18 | Distribution Field Array | `.../page-components/crm/donation/recurringdonors/distribution-field-array.tsx` (RHF useFieldArray, running sum) |
| 19 | Pause/Cancel modals | `.../page-components/crm/donation/recurringdonors/schedule-action-modals.tsx` (PauseModal, CancelModal, EditAmountModal — single file with 3 named exports) |
| 20 | Renderer: recurring-amount | `.../components/data-table/shared-cell-renderers/recurring-amount-cell.tsx` (amount + currency + freqSuffix) — registered in advanced/basic/flow column-type registries |
| 21 | Renderer: freq-badge | `.../components/data-table/shared-cell-renderers/freq-badge-cell.tsx` (Monthly=blue, Quarterly=purple, Annual=green, Semi-Annual=orange) |
| 22 | Renderer: gateway-cell | `.../components/data-table/shared-cell-renderers/gateway-cell.tsx` (Stripe/PayPal/Razorpay icon + name) |
| 23 | Renderer: payment-method-cell | `.../components/data-table/shared-cell-renderers/payment-method-cell.tsx` (card brand icon + last4 OR UPI/Bank icon) |
| 24 | Renderer: last-charged-cell | `.../components/data-table/shared-cell-renderers/last-charged-cell.tsx` (date + success/failed icon) |
| 25 | Renderer: total-charged-cell | `.../components/data-table/shared-cell-renderers/total-charged-cell.tsx` (amount + count subtitle) |
| 26 | Renderer: failure-count-cell | `.../components/data-table/shared-cell-renderers/failure-count-cell.tsx` (number, red when ≥1) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `application/configs/data-table-configs/donation-service-entity-operations.ts` | EXTEND existing `RECURRINGDONATIONSCHEDULE` block — wire create/update/delete/pause/resume/cancel/retry/updatePayment/editAmount mutations (currently all wired to ActivateDeactivate placeholder) |
| 2 | `application/configs/data-table-configs/operations-config.ts` | (verify already imports RECURRINGDONATIONSCHEDULE) |
| 3 | `presentation/components/data-table/component-column.tsx` (advanced) | Register 7 new renderer keys: recurring-amount, freq-badge, gateway-cell, payment-method-cell, last-charged-cell, total-charged-cell, failure-count |
| 4 | `presentation/components/data-table/basic/component-column.tsx` | Same 7 keys |
| 5 | `presentation/components/data-table/flow/component-column.tsx` | Same 7 keys |
| 6 | `presentation/components/data-table/shared-cell-renderers/index.ts` | Export 7 new renderers |
| 7 | sidebar menu config | (already registered via DB seed — verify menu item shows under CRM_DONATION at OrderBy=2) |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Recurring Donations
MenuCode: RECURRINGDONOR
ParentMenu: CRM_DONATION
Module: CRM
MenuUrl: crm/donation/recurringdonors
GridType: FLOW
OrderBy: 2

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: RECURRINGDONOR

MasterDataSeedGaps:
  RECURRINGFREQUENCY: ADD "Semi-Annual" (dataValue=180, dataName="Semi-Annual") — currently only Monthly/Quarterly/Annually exist
  RECURRINGSCHEDULESTATUS: ADD "Failed" (dataName="Failed", dataValue=FAIL) — currently only Active/PastDue/Paused/Cancelled/Expired
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `RecurringDonationScheduleQueries`
- Mutation type: `RecurringDonationScheduleMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `recurringDonationSchedules` | [RecurringDonationScheduleResponseDto] (paginated) | searchText, pageNo, pageSize, sortField, sortDir, isActive, **chip** (string: all/active/paused/cancelled/failed/expiringSoon), **frequencyId**, **paymentGatewayId**, **amountMin**, **amountMax**, **currencyId**, createdFrom, createdTo, **nextBillingFrom**, **nextBillingTo** |
| `recurringDonationScheduleById` | RecurringDonationScheduleResponseDto | recurringDonationScheduleId |
| **`recurringDonationScheduleSummary`** ⭐ NEW | RecurringDonationScheduleSummaryDto | — |
| **`recurringDonationScheduleFailedAlert`** ⭐ NEW | [RecurringDonationScheduleFailedAlertDto] (top 5) | — |
| **`paymentMethodTokensByContact`** ⭐ NEW (helper for FORM cascade) | [PaymentMethodTokenResponseDto] | contactId |
| `recurringDonorTransactions` | [PaymentTransactionResponseDto] (existing — drawer Charge History) | recurringScheduleId |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| **`createRecurringDonationSchedule`** ⭐ NEW | RecurringDonationScheduleRequestDto (with Distributions) | int (new ID) |
| **`updateRecurringDonationSchedule`** ⭐ NEW | RecurringDonationScheduleRequestDto | int |
| **`deleteRecurringDonationSchedule`** ⭐ NEW | recurringDonationScheduleId | int |
| `activateDeactivateRecurringDonationSchedule` (existing — KEEP) | recurringDonationScheduleId | int |
| **`pauseRecurringDonationSchedule`** ⭐ NEW | recurringDonationScheduleId, pausedReason | int |
| **`resumeRecurringDonationSchedule`** ⭐ NEW | recurringDonationScheduleId | int |
| **`cancelRecurringDonationSchedule`** ⭐ NEW | recurringDonationScheduleId, cancelledReason | int |
| **`retryRecurringDonationSchedule`** ⭐ NEW (SERVICE_PLACEHOLDER) | recurringDonationScheduleId | int |
| **`updateRecurringDonationSchedulePayment`** ⭐ NEW (SERVICE_PLACEHOLDER) | recurringDonationScheduleId, newPaymentMethodTokenId | int |
| **`editRecurringDonationScheduleAmount`** ⭐ NEW | recurringDonationScheduleId, newAmount | int |

**Response DTO Fields** (what FE receives — RecurringDonationScheduleResponseDto):
| Field | Type | Notes |
|-------|------|-------|
| recurringDonationScheduleId | number | PK |
| recurringDonationScheduleCode | string | NEW — REC-{NNNN} |
| amount | number | per-charge amount |
| currencyId | number | FK |
| currencyCode | string | NEW projected — "USD" |
| frequencyId | number | FK |
| frequencyName | string | NEW projected — "Monthly" |
| frequencySuffix | string | NEW projected — "/mo" |
| startDate | string (ISO) | — |
| endDate | string (ISO) \| null | — |
| nextBillingDate | string (ISO) \| null | — |
| lastChargedDate | string (ISO) \| null | — |
| lastChargeStatusId | number \| null | FK |
| lastChargeStatusName | string \| null | NEW projected |
| lastFailureReason | string \| null | — |
| consecutiveFailures | number | — |
| totalChargedCount | number | — |
| totalChargedAmount | number | — |
| scheduleStatusId | number | FK |
| scheduleStatusName | string | NEW projected |
| paymentGatewayId | number | FK |
| paymentGatewayName | string | NEW projected — "Stripe" |
| paymentGatewayCode | string | NEW projected — "STRIPE" (lowercased for icon mapping) |
| paymentMethodTokenId | number | FK |
| paymentMethodDisplay | string | NEW projected — "Visa ••••4242" |
| gatewaySubscriptionId | string | — |
| gatewayCustomerId | string | — |
| gatewayPlanId | string \| null | — |
| pausedReason | string \| null | — |
| cancelledAt | string (ISO) \| null | — |
| cancelledReason | string \| null | — |
| donorEmail | string \| null | — |
| note | string \| null | — |
| donorContactName | string | NEW projected — first distribution's Contact.DisplayName |
| donorContactCode | string | NEW projected — first distribution's Contact.ContactCode |
| donorAvatarColor | string \| null | NEW projected — derived from contact ID hash for UI consistency |
| distributions | [DistributionResponseDto] | child rows (existing) |
| createdBy / createdDate / modifiedBy / modifiedDate | string | inherited audit |
| isActive | boolean | inherited |

**SummaryDto Fields**:
| Field | Type |
|-------|------|
| activeCount | number |
| activeCountDelta | number (delta vs previous month) |
| monthlyRecurringRevenue | number |
| mrrDeltaPercent | number (% delta) |
| failedThisMonth | number |
| retriedThisMonth | number |
| recoveredThisMonth | number |
| needsAttentionCount | number |
| avgDurationMonths | number |
| currencyCode | string (display currency for MRR — Company default) |

**FailedAlertDto Fields**:
| Field | Type |
|-------|------|
| recurringDonationScheduleId | number |
| recurringDonationScheduleCode | string |
| donorContactName | string |
| amount | number |
| currencyCode | string |
| frequencySuffix | string |
| lastChargedDate | string (ISO) |
| consecutiveFailures | number |
| lastFailureReason | string |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (especially Mapster `.NewConfig()` for new DTOs)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/donation/recurringdonors`
- [ ] EF migration applies cleanly: `dotnet ef database update` adds `RecurringDonationScheduleCode` column

**Functional Verification (Full E2E — MANDATORY):**

*Grid + KPIs + Filters:*
- [ ] Grid loads with 12 columns: Schedule ID, Donor, Amount+freq, Frequency badge, Gateway, Payment Method, Status, Next Billing, Last Charged, Total Charged, Failures, Actions
- [ ] 4 KPI widgets render correct values from `recurringDonationScheduleSummary` query
- [ ] Failed Payments Alert Banner renders when `failedThisMonth > 0`; collapses on chevron click; expanded state persists in Zustand
- [ ] 6 filter chips work (All / Active / Paused / Cancelled / Failed / Expiring Soon) — each refetches grid with `chip` arg
- [ ] Advanced filter panel: 9 filters apply correctly; URL syncs; Clear button resets state
- [ ] Search filters by donor name, email, schedule ID
- [ ] Export dropdown shows CSV / Excel / PDF (export wires to existing export pipeline)

*FORM mode (`?mode=new`):*
- [ ] Empty FORM renders 3 sections (Schedule Info, Payment Setup, Distribution); section 4 (Status) hidden in new mode
- [ ] PaymentMethodTokenId dropdown disabled until at least one Distribution.Contact selected; cascades on first Contact pick
- [ ] Distribution field array: Add Distribution adds row; Remove icon removes; running sum vs Amount turns red on mismatch
- [ ] FrequencyId dropdown shows Monthly/Quarterly/**Semi-Annual**/Annual (verify Semi-Annual seeded)
- [ ] Save creates record → URL changes to `?mode=read&id={newId}` → drawer auto-opens with new record
- [ ] Auto-gen `RecurringDonationScheduleCode` populates as `REC-{NNNN}` after save

*FORM mode (`?mode=edit&id=X`):*
- [ ] FORM pre-filled with existing data including all distributions
- [ ] Status section visible; Paused/Cancelled/Failed reasons display when applicable
- [ ] Save updates record → URL: `?mode=read&id=X` → drawer reopens with updated data

*DETAIL drawer (`?mode=read&id=X`):*
- [ ] Drawer slides in from right (460px); grid stays visible behind overlay
- [ ] Drawer shows 6 sections: Donor mini card, Schedule Info, Payment Method, Distribution, Charge History (last 6), Audit Trail
- [ ] Charge History uses existing `RECURRING_DONOR_TRANSACTIONS_QUERY` and renders Date/Amount/Status icon/TransactionId/Failure Reason
- [ ] Footer actions render conditionally based on Status: Pause shows when Active; Resume when Paused; Cancel when ≠Cancelled; Retry+Contact Donor when Failed
- [ ] Drawer closes on X / Esc / overlay click → URL clears params

*Workflow actions:*
- [ ] Pause: confirm modal with PausedReason → mutation → status flips to Paused; NextBillingDate cleared; drawer refetches; row in grid updates inline
- [ ] Resume: direct mutation → status flips to Active; NextBillingDate recomputed
- [ ] Cancel: confirm modal with required CancelledReason → mutation → status flips to Cancelled; CancelledAt set
- [ ] Retry (Failed only): mutation fires (SERVICE_PLACEHOLDER toast: "Charge attempt sent to gateway"); on success, status flips back to Active and ConsecutiveFailures=0
- [ ] Update Payment (SERVICE_PLACEHOLDER): toast: "Payment update flow not yet integrated"
- [ ] Contact Donor (SERVICE_PLACEHOLDER): navigates to email-campaign-builder with donor pre-selected
- [ ] Edit Amount: inline modal → mutation → drawer refetches with new amount

*Failed Alert Banner inline actions:*
- [ ] Contact Donor / Retry / Cancel / Pause buttons reuse same handlers as drawer footer
- [ ] After action, banner refetches and updates row (or removes row if status changed out of Failed)

*Permissions:*
- [ ] Edit/Delete/Cancel buttons respect role capabilities
- [ ] BUSINESSADMIN sees all action buttons

*MasterData seed gaps (CRITICAL):*
- [ ] RECURRINGFREQUENCY has "Semi-Annual" row
- [ ] RECURRINGSCHEDULESTATUS has "Failed" row

**DB Seed Verification:**
- [ ] Menu visible in sidebar under CRM_DONATION at OrderBy=2 (between GLOBALDONATION and CHEQUEDONATION)
- [ ] Grid + 12 GridFields seeded; GridFormSchema is NULL (FLOW)
- [ ] BUSINESSADMIN role has all RECURRINGDONOR menu capabilities

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Architectural notes:**
- **Entity name is `RecurringDonationSchedule`, NOT `RecurringDonation`** — DO NOT rename. The "Schedule" suffix exists because each row is a recurring *subscription* (the parent), and individual charge attempts are tracked in PaymentTransactions (a separate entity).
- **FE folder is `recurringdonors` (plural, no entity suffix)** — DO NOT rename. Menu URL `crm/donation/recurringdonors` is registered in MODULE_MENU_REFERENCE.md and renaming would orphan the menu seed. Keep the folder; the Zustand store name and component file names follow the entity convention `recurringdonationschedule-*`.
- **CompanyId IS persisted** on this entity (existing column) — but FE never sends it; resolved from HttpContext on Create/Update. Existing pattern; preserve.
- **DETAIL is a slide-in drawer (460px), NOT a full-page route.** This matches DonationInKind #7 (520px). URL syncs to `?mode=read&id=X` for back-button + deep-link, but the GRID stays mounted underneath; closing the drawer just clears URL params. Do NOT generate a separate page route for `?mode=read`.
- **GridFormSchema must be SKIP/NULL** in DB seed — FLOW screens drive their FORM via view-page.tsx.
- **Variant B mandatory** — ScreenHeader at page root, FlowDataTable inside `<DataTableContainer showHeader={false}>`. Failed Alert Banner sits between widgets and grid container.
- **Existing GQL field names use camelCase param convention** (`recurringDonationSchedules`, `recurringDonationScheduleById`, `activateDeactivateRecurringDonationSchedule`) — preserve. NEW mutations follow same convention.
- **Charge History sub-query is already wired** — keep `RECURRING_DONOR_TRANSACTIONS_QUERY`. Verify the existing GQL field name used (`donorAmount` vs `amount`) and align FE rendering accordingly. (Documented as ISSUE-3.)

**ALIGN scope reality check:**
This is labeled ALIGN but the gap is large — BE has only 1 toggle + 2 queries; needs +9 commands +2 queries +1 helper query. FE has only an old read-only data-table + standalone full-page view component (NOT a FLOW view-page or drawer); needs near-greenfield page-component rebuild. Treat as ALIGN for scope-tag purposes (entity + child entity exist; FK plumbing exists; menu URL registered) but expect Build Log to reflect "rebuild" volume.

**Migration safety:**
- Adding `RecurringDonationScheduleCode` (string 50, nullable initially) requires a backfill step before applying NOT NULL + unique-filtered-index. Migration must:
  1. Add nullable column
  2. Backfill existing rows: `REC-{0001+ROW_NUMBER()}` per Company
  3. Alter to NOT NULL
  4. Add unique-filtered-index per Company
- Test migration on a copy of prod data before merging.

**Service Dependencies** (UI-only — no backend service implementation):

The mockup shows several actions that depend on payment-gateway integration that doesn't exist in this codebase yet. Build the full UI; wire handlers to mock implementations + toast.

- **⚠ SERVICE_PLACEHOLDER: "Retry Now"** — full UI implemented (button, confirm modal, mutation pipeline). Backend handler simulates gateway charge retry: increments TotalChargedCount, sets ConsecutiveFailures=0, status→Active, returns success without actually calling Stripe/PayPal/Razorpay APIs. Real implementation requires PaymentGatewayService abstraction (Stripe Charges API, PayPal Subscriptions API, Razorpay Subscription Charges API). Toast: "Retry sent — gateway integration pending."
- **⚠ SERVICE_PLACEHOLDER: "Update Payment"** — full UI implemented (button, modal opens with PaymentMethodToken picker for the same Contact). Mutation persists `PaymentMethodTokenId` change. Real implementation requires gateway-side subscription-update API call to point the existing gateway subscription at the new card. Toast: "Payment method updated locally — gateway sync pending."
- **⚠ SERVICE_PLACEHOLDER: "Contact Donor"** — full UI implemented (button + dropdown action). Click navigates to `/crm/communication/emailcampaign?donorId={contactId}&template=recurring-failure-recovery` (the email-campaign-builder route exists; query-string handoff is a SERVICE_PLACEHOLDER until Campaign #25 implements deep-link handling). Toast meanwhile: "Email composer opening with donor pre-selected."
- **⚠ SERVICE_PLACEHOLDER: "Donor profile link"** (drawer Donor mini card → name link) — Contact #18 detail page exists but `?engagementScore` projected field is currently null (Family #20 known issue). UI link works; engagement-score badge shows "N/A" if null.
- **⚠ SERVICE_PLACEHOLDER: "Export"** — Export button + dropdown render; CSV / Excel / PDF wires to existing GlobalExport pipeline if available, else toast: "Export queued."

The CREATE / UPDATE / DELETE / PAUSE / RESUME / CANCEL / EDIT_AMOUNT mutations are NOT placeholders — they persist data normally. Only the gateway-side network calls are mocked.

**Testing reminders:**
- Verify "Failed" status row added to RECURRINGSCHEDULESTATUS MasterData — without it, ScheduleStatusId=Failed lookups will return null and the badge will render blank.
- Verify "Semi-Annual" row added to RECURRINGFREQUENCY — mockup shows it as a frequency option.
- Test the cascade: PaymentMethodToken queryArg `contactId` — without first selecting a Distribution.Contact, the dropdown should be disabled with placeholder "Select a donor first."
- Test the distribution-sum validator: form should refuse Save when sum(Distribution.Amount) ≠ Amount.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning | HIGH | BE-data-model | Entity is missing `RecurringDonationScheduleCode` column — mockup shows REC-0001 codes but no backing field exists. Migration required to add the column + backfill existing rows + add unique-filtered-index per Company. | OPEN |
| ISSUE-2 | planning | HIGH | BE-seed | RECURRINGSCHEDULESTATUS MasterData missing "Failed" row (only Active/PastDue/Paused/Cancelled/Expired exist). Without it, the mockup-required Failed status cannot be set. | OPEN |
| ISSUE-3 | planning | MED | BE-seed | RECURRINGFREQUENCY MasterData missing "Semi-Annual" row (only Monthly/Quarterly/Annually exist). Mockup advanced filter shows Semi-Annual as a frequency option. | OPEN |
| ISSUE-4 | planning | MED | FE-old-code | Existing `recurring-donor-view.tsx` is a full-page view (not a drawer). Must verify whether any sibling screen imports it before deletion — if yes, retain as legacy + create new drawer alongside. | OPEN |
| ISSUE-5 | planning | MED | BE-projection | `paymentMethodDisplay` projection requires LEFT JOIN to PaymentMethodToken + MasterData (PAYMENTMETHODTYPE) — verify EF query plan stays under acceptable cost. Consider cached snapshot column if pagination performance suffers. | OPEN |
| ISSUE-6 | planning | LOW | BE-projection | `donorContactName` projects from `Distributions.OrderBy(Id).First().Contact.DisplayName` — N+1 risk. Use SubQuery + Select projection in GetAll to keep single round-trip. | OPEN |
| ISSUE-7 | planning | LOW | FE-charge-history | `RECURRING_DONOR_TRANSACTIONS_QUERY` field name `donorAmount` may differ from FE-rendered `amount` — verify on first FE render and align (rename FE alias OR add BE projection). | OPEN |
| ISSUE-8 | planning | HIGH | BE-service | `RetryRecurringDonationSchedule` and `UpdateRecurringDonationSchedulePayment` are SERVICE_PLACEHOLDERs — real gateway integration (Stripe/PayPal/Razorpay) does not exist in codebase. Mock mutations return success; real Q4 work item. | OPEN |
| ISSUE-9 | planning | LOW | FE-cascade | PaymentMethodTokenId dropdown requires `paymentMethodTokensByContact` GQL helper — first BE consumer of this query. Subsequent screens (Pledge #12, OnlineDonation #10) may reuse. | OPEN |
| ISSUE-10 | planning | LOW | FE-export | Export CSV/Excel/PDF buttons render but Export pipeline integration TBD — wire to GlobalExport if available, else toast placeholder. | OPEN |
| ISSUE-11 | planning | MED | BE-validator | "Distribution sum must equal parent Amount" — implement as both BE validator (CreateRecurringDonationScheduleValidator + UpdateRecurringDonationScheduleValidator) AND FE inline RHF validation. Avoid drift by sharing the rule constant. | OPEN |
| ISSUE-12 | planning | LOW | BE-uniqueness | `GatewaySubscriptionId` unique-filtered-index per Company — verify gateway IDs are truly unique per gateway+company (collisions if same Stripe sub_id used across PayPal too?). Probably safe but document. | OPEN |
| ISSUE-13 | planning | LOW | FE-store | Zustand store should NOT bind URL params to itself for `?mode=read&id=X` — let URL be the source of truth (read via useSearchParams). Store only holds drawer animation state (`isAnimatingOpen`). Avoids hydration mismatch. | OPEN |
| ISSUE-14 | planning | LOW | BE-existing | Existing `donation-service-entity-operations.ts` line 313 wires create/update/delete/toggle ALL to `ActivateDeactivate` mutation (placeholder from before this screen was scoped). Replace with real mutations on FE wire-up; do not remove the file, only the placeholder lines. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
