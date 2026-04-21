---
screen: Pledge
registry_id: 12
module: Fundraising (CRM)
status: PENDING
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-20
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + 4 KPI widgets + Overdue Alert Banner + modal form → converted to FLOW view-page + 720px side-drawer DETAIL)
- [x] Existing code reviewed (BE: NO Pledge entity; FE: 3-line stub `<div>Need To Develop</div>`)
- [x] Business rules + workflow extracted (auto-generated payment schedule; 5-state status; computed Fulfilled/Balance/Fulfillment%)
- [x] FK targets resolved (Contact + Campaign + DonationPurpose + Currency + PaymentMode + 3 MasterData typeCodes)
- [x] File manifest computed (full greenfield: 2 entities, migration, 14 BE files, 20 FE files, DB seed)
- [x] Approval config pre-filled (PLEDGE menu code under CRM_DONATION at OrderBy=5)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM sections + DETAIL drawer + KPI widgets + Overdue Banner specified)
- [ ] User Approval received
- [ ] Backend code generated (Pledge + PledgePayment entities, 2 migrations)
- [ ] Backend wiring complete (DbContext, Decorator, Mapster, GQL mutations/queries)
- [ ] Frontend code generated (view-page 3 modes + Zustand store + 720px detail drawer + 4 KPI widgets + Overdue alert banner + 4 custom renderers)
- [ ] Frontend wiring complete (entity-operations, component-columns × 3 registries, shared-cell-renderers barrel, sidebar menu)
- [ ] DB Seed script generated (Menu + Grid + 11 FLOW columns; GridFormSchema SKIP; PLEDGESTATUS + PLEDGEFREQUENCY + PLEDGEPAYMENTSTATUS MasterData seeds)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (new Pledge + PledgePayment entities, both migrations applied)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/donation/pledge`
- [ ] 4 KPI widgets render: Active Pledges (count + $totalPledged), Fulfilled This Year ($ + count), Outstanding Balance ($ + count), Overdue Payments (count + $overdue)
- [ ] Overdue Alert Banner renders when `summary.overdueCount > 0` (collapsible, default expanded); shows top 5 overdue pledge payments with per-row Send Reminder button + "Send Bulk Reminders" header button (SERVICE_PLACEHOLDER — both toast)
- [ ] Grid loads with 11 columns; chips (All/Active/Fulfilled/Overdue/Cancelled); advanced filter panel (Campaign/Purpose/Amount Min+Max/Fulfillment%/StartDate From+To)
- [ ] `?mode=new` — empty FORM renders 4 sections (Donor & Purpose, Pledge Details, Payment Schedule, Additional)
- [ ] Frequency dropdown → InstallmentAmount + NumberOfInstallments auto-calculate (client-side derivation shown as read-only hint until user overrides)
- [ ] Save creates Pledge + auto-generates PledgePayments (1 row per installment) → redirect to `?mode=read&id={newId}` → drawer opens (NOT full page)
- [ ] `?mode=edit&id=X` — FORM pre-filled; editing frequency/amount REGENERATES future-dated unpaid PledgePayments (keeps paid ones)
- [ ] Row click → 720px right-side drawer slides in; URL syncs to `?mode=read&id=X`
- [ ] Drawer shows: Pledge Summary (10 items, 2-col), Payment Schedule Timeline (horizontal, color-coded dots), Payment History Table (all PledgePayments with status), Cancel Pledge button → inline reason input
- [ ] Cancel mutation sets status = Cancelled + CancelledAt + CancelledReason; drawer refreshes
- [ ] "Record" grid-row action → navigates to `/[lang]/crm/donation/globaldonation?mode=new&pledgePaymentId={nextUpcomingId}` (deep-link preset; see ⑫ ISSUE-1)
- [ ] "Remind" grid-row action → SERVICE_PLACEHOLDER toast "Reminder sent to {donorName}"
- [ ] Donor link click (grid + drawer + overdue banner) → `/[lang]/crm/contact/allcontacts?mode=read&id={contactId}` (see ⑫ ISSUE-2)
- [ ] Fulfillment progress bar renders with color logic: green 0–74 on-track, teal 100 fulfilled, orange behind, red overdue, gray cancelled
- [ ] FK dropdowns load via ApiSelectV2: Contact, Campaign, DonationPurpose, Currency, PaymentMode (reminder only), Frequency (MasterData)
- [ ] Unsaved changes dialog triggers on dirty FORM navigation
- [ ] DB Seed — menu visible in sidebar under CRM_DONATION at OrderBy=5, three MasterData type groups populated

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Pledge
Module: Fundraising (CRM)
Schema: fund
Group: DonationModels

Business: A **pledge** is a donor's **written commitment to give a specific amount over time**, typically split into an installment schedule (e.g., "$500/month for 24 months = $12,000 total"). Unlike one-off donations (GlobalDonation) or gateway-authorized recurring subscriptions (RecurringDonationSchedule), pledges are **promise-based, non-auto-debited**: the donor signs up but PAYS MANUALLY each period — via bank transfer, cheque, cash, or online form — and the NGO tracks fulfillment progress. Development/major-gift officers use this screen daily to watch capital-campaign fulfillment, flag missed installments, send reminders, and reconcile incoming donations against pledged amounts. The screen sits under `CRM → Donations → Pledges` alongside All Donations / Recurring / Cheque / In-Kind (OrderBy=5). The detail view is a **720px right-side slide-in drawer** that surfaces donor info, full payment timeline (paid/upcoming/overdue/scheduled dots), tabular payment history with donation refs, and a Cancel-Pledge action with mandatory reason. When a donor pays an installment, staff clicks "Record" on the grid → the donation form opens pre-linked to the next `PledgePayment` row, so the resulting GlobalDonation is correctly attributed and fulfillment auto-updates.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **TWO entities**: parent `Pledge` + child `PledgePayment` (1:Many installment schedule).
> Audit columns (CreatedBy, CreatedDate, etc.) inherited from `Entity` base. CompanyId resolved from HttpContext on Create/Update (never sent by FE).

### Parent Table: `fund."Pledges"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| PledgeId | int | — | PK | — | Primary key |
| PledgeCode | string | 50 | YES | — | Auto-gen `PLG-{0001}` (4-digit padded, per-Company sequence) on Create when empty; unique-filtered per Company |
| CompanyId | int | — | YES | app.Companies | Tenant scope (from HttpContext) |
| ContactId | int | — | YES | cont.Contacts | Donor |
| CampaignId | int? | — | NO | app.Campaigns | Optional — "Capital Campaign", "Children's Education" |
| DonationPurposeId | int | — | YES | fund.DonationPurposes | Purpose designation |
| CurrencyId | int | — | YES | shared.Currencies | Currency of pledge |
| TotalPledgedAmount | decimal(18,2) | — | YES | — | Total commitment; > 0 |
| StartDate | DateTime | — | YES | — | Start of commitment (first installment due) |
| EndDate | DateTime? | — | NO | — | Last installment due; derived if null (StartDate + freq × N installments) |
| FrequencyId | int | — | YES | shared.MasterData (PLEDGEFREQUENCY) | Monthly / Quarterly / Semi-Annual / Annual / Custom |
| InstallmentAmount | decimal(18,2) | — | YES | — | Per-installment amount; auto-calc = Total / N but can be manually overridden |
| NumberOfInstallments | int | — | YES | — | Count; auto-calc from Frequency+duration but manually editable |
| PaymentModeId | int? | — | NO | shared.PaymentModes | Optional — expected method (reminder-only, not enforced) |
| PledgeStatusId | int | — | YES | shared.MasterData (PLEDGESTATUS) | OnTrack / Fulfilled / Overdue / Behind / Cancelled — auto-computed on read unless explicitly Cancelled |
| CancelledAt | DateTime? | — | NO | — | Set on Cancel mutation |
| CancelledReason | string | 500 | NO | — | Mandatory when Cancel mutation fires |
| Notes | string | 1000 | NO | — | Free-text admin note |

**Computed/projected fields** (added in BE GetAll + GetById projections — NOT new columns):
- `fulfilledAmount` — SUM(PledgePayments.PaidAmount) WHERE PaymentStatusCode='PAID' for this PledgeId
- `outstandingBalance` — `TotalPledgedAmount − fulfilledAmount`
- `fulfillmentPercent` — `fulfilledAmount / TotalPledgedAmount × 100` (integer, capped 100)
- `nextDueDate` — MIN(PledgePayments.DueDate) WHERE PaymentStatusCode IN ('UPCOMING','OVERDUE') for this PledgeId (nullable when all paid/cancelled)
- `nextDueAmount` — DueAmount of the row matching nextDueDate
- `overdueAmount` — SUM(PledgePayments.DueAmount) WHERE PaymentStatusCode='OVERDUE' for this PledgeId
- `overdueCount` — COUNT(PledgePayments) WHERE PaymentStatusCode='OVERDUE' for this PledgeId
- `computedStatusCode` — derived: if Cancelled → Cancelled; if fulfilledAmount >= TotalPledgedAmount → Fulfilled; if overdueCount > 0 → Overdue; if fulfilledAmount < expected_by_today → Behind; else OnTrack
- `frequencyName`, `frequencySuffix` — derived from Frequency MasterData (dataName="Monthly", dataValue="/mo")
- `donorName`, `donorCode`, `donorAvatarColor` — joined from Contact
- `campaignName`, `donationPurposeName`, `currencyCode`, `paymentModeName` — FK joins

### Child Table: `fund."PledgePayments"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| PledgePaymentId | int | — | PK | — | Primary key |
| PledgeId | int | — | YES | fund.Pledges | Parent — CASCADE DELETE |
| CompanyId | int | — | YES | app.Companies | Tenant scope (denormalized from parent for index scans) |
| InstallmentNumber | int | — | YES | — | 1-based sequential |
| DueDate | DateTime | — | YES | — | Scheduled due date |
| DueAmount | decimal(18,2) | — | YES | — | Scheduled amount (usually = Pledge.InstallmentAmount; may differ for final prorated row) |
| PaidDate | DateTime? | — | NO | — | Set when a donation is recorded against this row |
| PaidAmount | decimal(18,2)? | — | NO | — | Actual amount recorded (may differ from DueAmount) |
| GlobalDonationId | int? | — | NO | fund.GlobalDonations | Set when "Record Payment" creates a GlobalDonation |
| PaymentStatusId | int | — | YES | shared.MasterData (PLEDGEPAYMENTSTATUS) | Paid / Upcoming / Scheduled / Overdue — auto-computed |

**Child computed fields** (projected):
- `paymentStatusCode` — from MasterData dataValue (PAID/UPCOMING/SCHEDULED/OVERDUE)
- `daysUntilDue` — signed int (negative = overdue days); derived at query time
- `donationReceiptCode` — projected from GlobalDonation.ReceiptCode when linked

**Indexes:**
- `Pledges`: `(CompanyId, ContactId)`, `(CompanyId, PledgeStatusId)`, `(CompanyId, StartDate)`; unique-filtered `(CompanyId, PledgeCode) WHERE IsActive=1`
- `PledgePayments`: `(PledgeId, InstallmentNumber)` unique, `(CompanyId, DueDate, PaymentStatusId)` for overdue scans

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and nav properties) + Frontend Developer (for ApiSelectV2 queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `contacts` | `displayName` (+`contactCode`) | `ContactResponseDto` |
| CampaignId | Campaign | `Base.Domain/Models/ApplicationModels/Campaign.cs` | `campaigns` | `campaignName` (fallback `shortDescription`) | `CampaignResponseDto` |
| DonationPurposeId | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` | `donationPurposes` | `donationPurposeName` | `DonationPurposeResponseDto` |
| CurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `currencies` | `currencyCode` (+`currencyName`) | `CurrencyResponseDto` |
| PaymentModeId | PaymentMode | `Base.Domain/Models/SharedModels/PaymentMode.cs` | `paymentModes` | `paymentModeName` | `PaymentModeResponseDto` |
| FrequencyId | MasterData (PLEDGEFREQUENCY) | `Base.Domain/Models/SharedModels/MasterData.cs` | `masterDatas` (staticFilter `typeCode=PLEDGEFREQUENCY`) | `dataName` (+`dataValue`) | `MasterDataResponseDto` |
| PledgeStatusId | MasterData (PLEDGESTATUS) | `Base.Domain/Models/SharedModels/MasterData.cs` | `masterDatas` (staticFilter `typeCode=PLEDGESTATUS`) | `dataName` | `MasterDataResponseDto` |
| PaymentStatusId (child) | MasterData (PLEDGEPAYMENTSTATUS) | `Base.Domain/Models/SharedModels/MasterData.cs` | `masterDatas` (staticFilter `typeCode=PLEDGEPAYMENTSTATUS`) | `dataName` (+`dataValue`) | `MasterDataResponseDto` |
| GlobalDonationId (child) | GlobalDonation | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | `globalDonations` | `receiptCode` | `GlobalDonationResponseDto` |

**MasterData seeds** (see ⑨ CONFIG):
- `PLEDGEFREQUENCY`: MONTHLY (dataValue=30), QUARTERLY (90), SEMIANNUAL (180), ANNUAL (365), CUSTOM (0) — 5 rows
- `PLEDGESTATUS`: ONTRACK, FULFILLED, OVERDUE, BEHIND, CANCELLED — 5 rows with ColorHex (green #166534 / teal #0e7490 / red #991b1b / orange #9a3412 / slate #475569)
- `PLEDGEPAYMENTSTATUS`: PAID (#166534), UPCOMING (#92400e), SCHEDULED (#64748b), OVERDUE (#991b1b) — 4 rows

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `PledgeCode` unique per Company (auto-gen `PLG-{NNNN}` if empty); filtered-unique index on (CompanyId, PledgeCode) WHERE IsActive=1
- `(PledgeId, InstallmentNumber)` unique on PledgePayment

**Required Field Rules:**
- Pledge: ContactId, DonationPurposeId, CurrencyId, TotalPledgedAmount > 0, StartDate, FrequencyId, InstallmentAmount > 0, NumberOfInstallments ≥ 1
- PledgePayment (auto-generated — never manually created by FE): PledgeId, InstallmentNumber, DueDate, DueAmount, PaymentStatusId

**Conditional Rules:**
- If FrequencyId = Custom → NumberOfInstallments is mandatory and InstallmentAmount may be manually set (no auto-calc)
- If FrequencyId ≠ Custom → auto-compute: NumberOfInstallments = CEILING(TotalPledgedAmount / InstallmentAmount); auto-compute EndDate = StartDate + (frequencyDays × (NumberOfInstallments − 1))
- If PledgeStatus = Cancelled → CancelledAt + CancelledReason must be set; further edits blocked except reactivation (out of scope)
- EndDate, if set, must be > StartDate
- Sum of PledgePayment.DueAmount = TotalPledgedAmount (allow ±$0.01 rounding; final row absorbs remainder)

**Business Logic — Payment Schedule Generation** (on Create + on Edit of future-dated rows):
- On **Create**: generate N PledgePayment rows with:
  - InstallmentNumber = 1..N
  - DueDate = StartDate + (frequencyDays × (i − 1))
  - DueAmount = InstallmentAmount (except last row which = TotalPledgedAmount − sum(first N−1 × InstallmentAmount) for rounding)
  - PaymentStatusId = UPCOMING if DueDate = today; OVERDUE if DueDate < today; SCHEDULED if DueDate > today
- On **Update** when TotalPledgedAmount / InstallmentAmount / Frequency / StartDate / EndDate changes:
  - **KEEP** paid rows (PaymentStatusCode='PAID') — these are historical facts
  - **DELETE** unpaid rows (UPCOMING/SCHEDULED/OVERDUE)
  - **REGENERATE** fresh unpaid rows starting from next_due using remaining balance (TotalPledgedAmount − sum of paid)
  - Preserve PledgePaymentId where possible via natural-key match (InstallmentNumber + DueDate)
- On **Cancel**: set Pledge status; mark all unpaid rows as cancelled (soft — leave rows but skip in overdue/summary queries)

**Business Logic — Status Auto-Computation** (on every GetById/GetAll read):
- If Pledge.CancelledAt IS NOT NULL → `computedStatusCode` = `CANCELLED`
- Else if `fulfilledAmount >= TotalPledgedAmount` → `FULFILLED`
- Else if any PledgePayment.PaymentStatusCode = `OVERDUE` → `OVERDUE`
- Else if `fulfilledAmount < expected_by_today` (expected = InstallmentAmount × floor((today − StartDate) / freqDays)) → `BEHIND`
- Else → `ONTRACK`
- This computed code is returned as `computedStatusCode`; the stored `PledgeStatusId` is updated only on Cancel mutation (persist the terminal state).

**Business Logic — Overdue Transition** (background or on-read):
- On every GetAll call, re-evaluate all unpaid PledgePayments where DueDate < today AND PaymentStatusCode='UPCOMING' → flip to OVERDUE. This is a lazy update executed in the query handler (UPDATE ... WHERE) to keep the alert banner accurate.

**Workflow** (Pledge lifecycle):
- States: `OnTrack` / `Behind` / `Overdue` / `Fulfilled` / `Cancelled`
- Automatic transitions (OnTrack ↔ Behind ↔ Overdue ↔ Fulfilled) — computed on read, not persisted
- Manual transition: → `Cancelled` via CancelPledge mutation (requires reason); terminal
- No Reopen / Revert (out of scope)

**Service-dependent actions** (SERVICE_PLACEHOLDER — UI built, handler toasts):
- Send Reminder (single pledge) — will dispatch email/SMS via notification service
- Send Bulk Reminders (from overdue banner) — same service, batch call

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: FLOW with **side-drawer DETAIL** (sibling pattern: DonationInKind #7 + RecurringDonationSchedule #8)
**Reason**: Transactional/workflow screen with: (a) parent-child data model (Pledge + PledgePayment schedule), (b) auto-generated child rows on Create with regeneration logic on Update, (c) 4 KPI widgets above grid (Variant B mandatory), (d) collapsible Overdue Alert Banner between KPIs and grid, (e) 720px right-side slide-in detail drawer (NOT a separate full page route), (f) computed/projected fields (fulfilledAmount, outstandingBalance, fulfillmentPercent, nextDueDate, overdueCount), (g) state machine with one manual transition (Cancel) and four auto-computed states, (h) cross-screen navigation ("Record" → donation form pre-linked to PledgePayment).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files)
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation — PledgePayments (auto-generate on Create; diff-regenerate on Update preserving paid rows)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 8: Contact, Campaign, DonationPurpose, Currency, PaymentMode, Frequency MasterData, PledgeStatus MasterData, PledgePaymentStatus MasterData)
- [x] Unique validation — PledgeCode (filtered per Company)
- [x] Workflow commands — `CancelPledge` (with reason)
- [ ] File upload command — N/A
- [x] Custom business rule validators — installment-sum rule, schedule-regen rule, cancel-immutable-after-cancel guard
- [x] Lazy overdue-flip on GetAll reads (UPDATE inside query handler)
- [x] Summary query — `GetPledgeSummary` for 4 KPI widgets
- [x] Overdue alert query — `GetPledgeOverdueAlert` for top 5 overdue payments in banner
- [x] PledgePayment helper query — `GetNextDuePledgePayment` for "Record Payment" deep-link

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — **Variant B** (ScreenHeader + KPI widgets + DataTableContainer showHeader=false)
- [x] view-page.tsx with 3 URL modes (new, edit, read-as-drawer)
- [x] React Hook Form (for FORM layout in `?mode=new`/`?mode=edit`)
- [x] Zustand store (`pledge-store.ts`) — drawer open state, selectedPledgeId, filterChip, overdueAlertExpanded, cancelConfirmOpen
- [x] Unsaved changes dialog (FORM)
- [x] FlowFormPageHeader (FORM mode — Back, Save buttons)
- [x] **720px right-side slide-in DETAIL drawer** (`pledge-detail-drawer.tsx`) — matches DonationInKind pattern but wider
- [x] Auto-calc hints in FORM — Frequency + StartDate + TotalPledged → suggested InstallmentAmount + NumberOfInstallments (shown as read-only placeholders; user can override)
- [x] Workflow status badge + action buttons — Cancel (terminal) + Record Payment (cross-screen deep-link) + Send Reminder (SERVICE_PLACEHOLDER)
- [x] **Overdue Payments Alert Banner** (collapsible, default expanded, between KPIs and grid)
- [x] **Summary cards / count widgets** above grid — 4 KPIs
- [x] Grid aggregation columns — Fulfilled/Balance/Fulfillment% all via projected fields
- [x] Horizontal Payment Timeline in drawer — color-coded dots per PledgePayment
- [x] Payment History Table in drawer — full PledgePayment list with donation ref linking to GlobalDonation detail

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup (`html_mockup_screens/screens/fundraising/pledge-management.html`) — this IS the design spec.

### Grid/List View

**Display Mode**: `table` (transactional list — NOT card-grid)

**Layout Variant**: `widgets-above-grid+side-panel` — **Variant B mandatory**.
- `<ScreenHeader>` at top: title "Pledge Management", subtitle "Track donor commitments, payment schedules, and fulfillment progress", right-side actions (+New Pledge, Export dropdown with Excel/CSV/PDF — all SERVICE_PLACEHOLDER via toast)
- 4 KPI widgets in `stats-grid` (CSS `grid-template-columns: repeat(auto-fit, minmax(210px, 1fr))`)
- **Overdue Alert Banner** between widgets and grid (collapsible)
- `<DataTableContainer showHeader={false}>` for the grid (prevents duplicate header — see feedback_ui_uniformity memory)

**Grid Columns** (11 columns in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Pledge ID | pledgeCode | text-mono (accent color, monospace) | 110px | YES | Click → open drawer (also via row click); monospace per mockup `pledge-id` class |
| 2 | Donor | donorName | donor-link renderer (NEW) | 180px | YES | Underlined accent; click → contact profile deep-link (see ⑫ ISSUE-2) |
| 3 | Campaign / Purpose | campaignName OR donationPurposeName | text-dual (line1 = campaign, line2 = purpose muted; if no campaign → only purpose) | auto | YES | Mockup shows single value — use campaign if set, else purpose |
| 4 | Total Pledged | totalPledgedAmount + currencyCode | currency-amount renderer (NEW) | 120px | YES | Right-aligned, monospace, bold, with currency symbol (per mockup `currency-amount` class) |
| 5 | Fulfilled | fulfilledAmount + currencyCode | currency-amount | 110px | YES | Same style; green-tinted when = total |
| 6 | Balance | outstandingBalance + currencyCode | currency-amount | 110px | YES | Red-tinted when overdueAmount > 0 |
| 7 | Fulfillment | fulfillmentPercent (+ computedStatusCode) | fulfillment-progress renderer (NEW) | 140px | YES | Horizontal 6px progress bar + % label; color logic: Fulfilled=teal, OnTrack=green, Behind=orange, Overdue=red, Cancelled=gray |
| 8 | Schedule | installmentAmount + currencyCode + frequencySuffix | text (derived "$500/mo", "$5,000/qtr", "$25K/yr") | 110px | NO | Mockup shows compact format; em-dash when Cancelled |
| 9 | Next Due | nextDueDate | DateOnlyPreview (REUSE) | 110px | YES | Renders "—" when null (Fulfilled/Cancelled); red-tinted when < today |
| 10 | Status | computedStatusCode | status-badge (REUSE) | 100px | YES | Color-coded per PLEDGESTATUS MasterData ColorHex |
| 11 | Actions | (action dropdown) | row-action-menu | 100px | NO | View / Record (if unpaid rows exist) / Remind (if overdue) / Edit / Cancel / Delete — status-aware visibility |

**Row Styling** (per mockup):
- Overdue rows: light-red background (`bg-red-50` equivalent token)
- Cancelled rows: 60% opacity (`opacity-60` equivalent token)
- Use table row className logic keyed on `computedStatusCode`

**Search/Filter Fields**: donorName, donorEmail, pledgeCode (searchable via `searchText` arg on `pledges` query)

**Filter Chips** (5 — top of grid, default "All" active):
- All
- Active (= OnTrack + Behind + Overdue — i.e., NOT Fulfilled, NOT Cancelled)
- Fulfilled
- Overdue
- Cancelled

Chip is mapped to `chip` string arg on `pledges` query; BE filter uses `computedStatusCode`.

**Advanced Filter Panel** (collapsible, "Advanced" button):
- Campaign (ApiSelectV2 → `campaigns`)
- Donation Purpose (ApiSelectV2 → `donationPurposes`)
- Amount Min (number, step 0.01)
- Amount Max (number, step 0.01)
- Fulfillment % (dropdown: Any / 0–25% / 25–50% / 50–75% / 75–100% / 100%)
- Start Date From (date)
- Start Date To (date)
- Apply / Clear buttons

Maps to GQL args: `campaignId`, `donationPurposeId`, `amountMin`, `amountMax`, `fulfillmentMin`, `fulfillmentMax`, `startDateFrom`, `startDateTo`.

**Grid Row Actions** (status-aware dropdown):
- **View** (always) — opens drawer, URL syncs `?mode=read&id=X`
- **Record** (when any PledgePayment is UPCOMING or OVERDUE) — cross-screen deep-link to `/[lang]/crm/donation/globaldonation?mode=new&pledgePaymentId={nextDueId}` (see ⑫ ISSUE-1)
- **Remind** (when computedStatusCode = Overdue) — SERVICE_PLACEHOLDER toast
- **Edit** (when NOT Cancelled) — navigate `?mode=edit&id=X`
- **Cancel** (when NOT Cancelled AND NOT Fulfilled) — opens Cancel modal (inline in drawer preferred; also accessible via row action)
- **Delete** (always, but hard-delete only when no PaymentStatusCode='PAID' rows exist; else soft-toggle via IsActive)

**Row Click**: Opens DETAIL DRAWER (slide-in from right, 720px). URL syncs to `?mode=read&id={id}` for back-button + deep-link support; closing drawer clears URL params. **NO navigation to a separate page.**

---

### Page Widgets & Summary Cards (above grid — top-of-page)

**Widgets**: 4 KPI cards in a responsive grid (`auto-fit, minmax(210px, 1fr)`).

| # | Widget Title | Value Source | Display Type | Position | Color/Icon |
|---|-------------|-------------|-------------|----------|-----------|
| 1 | Active Pledges | summary.activePledgesCount | number | left | teal / `ph:handshake` (Phosphor); subtitle "${totalActivePledgedAmount}M total pledged" formatted with K/M suffix |
| 2 | Fulfilled This Year | summary.fulfilledAmountYtd | currency | center-left | green / `ph:check-circle`; subtitle "{fulfilledPledgeCountYtd} pledges completed" |
| 3 | Outstanding Balance | summary.outstandingBalanceTotal | currency | center-right | orange / `ph:hourglass-medium`; subtitle "across {activePledgesCount} pledges" |
| 4 | Overdue Payments | summary.overdueCount | number | right | red / `ph:warning-circle`; subtitle "${overdueAmountTotal} overdue" formatted |

Use `@iconify/react` with Phosphor icons (per feedback_ui_uniformity memory — no emoji, no fa-* in components — however the mockup uses `fa-` for reference; FE must translate to Phosphor equivalents).

**Summary GQL Query**:
- Query name: `pledgeSummary` (returns `PledgeSummaryDto`)
- Fields: `activePledgesCount`, `totalActivePledgedAmount`, `fulfilledAmountYtd`, `fulfilledPledgeCountYtd`, `outstandingBalanceTotal`, `overdueCount`, `overdueAmountTotal`, `currencyCode` (display currency for amounts — Company default)
- Added to `PledgeQueries.cs` alongside `pledges` + `pledgeById`

---

### Overdue Payments Alert Banner (above grid, below KPIs)

Collapsible banner that surfaces overdue pledge payments needing immediate staff action.

**Visibility**: Render when `summary.overdueCount > 0`; default **expanded**; collapses on chevron click; persisted in Zustand `overdueAlertExpanded`.

**Header line** (always visible):
- Icon: `ph:warning` (red)
- Text: `{overdueCount} pledge payments are overdue totaling {overdueAmountTotal formatted}`
- Right-side actions:
  - **"Send Bulk Reminders"** button (SERVICE_PLACEHOLDER — toast "Bulk reminders sent to {N} donors")
  - **"View All Overdue"** button → triggers `setFilterChip('overdue')` on Zustand store
  - Chevron toggle for collapse/expand

**Body table** (when expanded — top 5 overdue pledge payments ordered by `daysOverdue DESC`):
| Column | Source |
|--------|--------|
| Pledge ID | pledgeCode (monospace, muted) |
| Donor | donorName (donor-link) |
| Due Date | pledgePayment.dueDate (formatted "MMM d, yyyy") |
| Amount Due | pledgePayment.dueAmount + currencyCode |
| Days Overdue | computed: `today - dueDate` (red, bold, suffix " days") |
| Action | "Send Reminder" button (SERVICE_PLACEHOLDER — single-donor toast) |

**Data source**: dedicated query `pledgeOverdueAlert` returns `PledgeOverdueAlertDto[]` (top 5 overdue payments). Avoids re-querying full grid.

---

### Grid Aggregation Columns

> Per-row computed values. All via LINQ subqueries on `PledgePayments` — see ② computed fields.

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Fulfilled | Sum of paid amounts | SUM(PledgePayment.PaidAmount) WHERE PaymentStatusCode='PAID' | LINQ subquery in GetAll projection |
| Balance | Total − fulfilled | Pledge.TotalPledgedAmount − SUM(paid) | Calculated in projection |
| Fulfillment | Percent complete | (fulfilled / total) × 100, capped 100 | Calculated in projection |
| Next Due | Earliest unpaid due date | MIN(DueDate) WHERE PaymentStatusCode IN ('UPCOMING','OVERDUE') | LINQ subquery |
| Computed Status | Lifecycle state | See ④ Business Logic — Status Auto-Computation | In projection |

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

> Full-page form. Built with React Hook Form. Must match the HTML mockup modal design — the mockup shows it as a modal but we render it as a full-page `view-page.tsx` per FLOW convention.

**Page Header**: `FlowFormPageHeader` with Back button (navigate to `/[lang]/crm/donation/pledge`), Save button; unsaved-changes dialog triggers on dirty navigation.

**Section Container Type**: **cards** (4 cards stacked, matching the mockup's `form-section-title` sections)

**Form Sections** (in display order from mockup):
| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | `ph:user-circle` | Donor & Purpose | 2-column | expanded | ContactId, CampaignId, DonationPurposeId (full-width row) |
| 2 | `ph:currency-dollar` | Pledge Details | 2-column (+ 1-col for amount) | expanded | CurrencyId, TotalPledgedAmount, StartDate, EndDate |
| 3 | `ph:calendar-check` | Payment Schedule | 3-column | expanded | FrequencyId, InstallmentAmount (auto-calc), NumberOfInstallments (auto-calc), PaymentModeId (6-col) |
| 4 | `ph:note-pencil` | Additional | 1-column (full-width) | expanded | Notes (textarea, 3 rows) |

**Field Widget Mapping** (all fields across all sections):
| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| ContactId | 1 | ApiSelectV2 | "Search donor..." | required | Query: `contacts`; display: `displayName`; shows avatar in option row |
| CampaignId | 1 | ApiSelectV2 | "Select campaign (optional)" | — | Query: `campaigns`; display: `campaignName` |
| DonationPurposeId | 1 | ApiSelectV2 | "Select purpose..." | required | Query: `donationPurposes`; display: `donationPurposeName` |
| CurrencyId | 2 | ApiSelectV2 | "Select currency" | required | Query: `currencies`; display: `currencyCode` (+`currencyName` as subtitle); default = Company.DefaultCurrencyId |
| TotalPledgedAmount | 2 | number | "0.00" | required, > 0 | Step 0.01, right-aligned with currency symbol prefix (derived from CurrencyId) |
| StartDate | 2 | datepicker | "Select date" | required | Default: today |
| EndDate | 2 | datepicker | "Auto-calculated" | — | Read-only placeholder until user overrides; auto-derived from Frequency+N+StartDate |
| FrequencyId | 3 | ApiSelectV2 | "Select frequency" | required | Query: `masterDatas(staticFilter: "PLEDGEFREQUENCY")`; display: `dataName`; default = Monthly |
| InstallmentAmount | 3 | number | "Auto-calculated" | required (when Custom), > 0 | Editable override of auto-calc = TotalPledged / N |
| NumberOfInstallments | 3 | number | "Auto-calculated" | required (when Custom), ≥ 1 | Editable override |
| PaymentModeId | 3 | ApiSelectV2 | "Select method (reminder only)" | — | Query: `paymentModes`; display: `paymentModeName` |
| Notes | 4 | textarea (3 rows) | "Any additional notes about this pledge..." | max 1000 | — |

**Auto-calculation logic** (client-side — runs on field change via `useWatch`):
- On change of `TotalPledgedAmount`, `StartDate`, `EndDate`, `FrequencyId`:
  - If FrequencyId ≠ Custom: compute `frequencyDays` from MasterData.dataValue (30/90/180/365)
  - If EndDate set: `N = floor((EndDate − StartDate) / frequencyDays) + 1`; `InstallmentAmount = TotalPledgedAmount / N`
  - If EndDate NOT set but InstallmentAmount user-entered: `N = ceil(TotalPledgedAmount / InstallmentAmount)`; `EndDate = StartDate + frequencyDays × (N − 1)`
  - If only TotalPledgedAmount + Frequency set: default N=12 (monthly=1yr, quarterly=3yr, etc.) and show suggested `InstallmentAmount` as placeholder
  - When user manually types InstallmentAmount or NumberOfInstallments, stop auto-overwriting that field (track `touchedFields` in RHF)
- On FrequencyId = Custom: show NumberOfInstallments as required, no auto-calc
- Display computed "End Date: {date}" helper text below the Frequency dropdown

**Schedule Preview Panel** (below Payment Schedule section — always-visible preview):
Shows a compact horizontal "dots + dates" preview of the generated schedule (first 6 + "... N more"), so staff can verify before save. Uses the same `pledge-payment-timeline` component as the drawer (read-only, scheduled dots only for new pledges).

**Validation error aggregation** (top-of-form summary on Save attempt): group errors by section for UX clarity (matches donationinkind pattern).

---

#### LAYOUT 2: DETAIL (mode=read) — 720px RIGHT-SIDE SLIDE-IN DRAWER

> The read-only detail UI shown when user clicks a grid row (`?mode=read&id=X`) or clicks **View**.
> This is a **slide-in drawer (720px)** from the right, NOT a separate full-page navigation. Matches the HTML mockup `detail-panel` design exactly.

**Drawer Container**:
- Width: 720px (fixed); mobile: 100%
- Position: fixed right, top 0, bottom 0, z-index 1060
- Overlay: rgba(0,0,0,0.4) at z-1055
- Animation: slide-in from right, 250ms ease
- Close: X button top-right, overlay click, or ESC key → updates URL, clears Zustand `selectedPledgeId`

**Drawer Header** (sticky top):
- Icon + Title: `ph:handshake` + "Pledge Detail — PLG-XXX" (code monospaced)
- **Right-side actions**:
  - **"Record Payment"** primary button (when nextDueId exists) → `/[lang]/crm/donation/globaldonation?mode=new&pledgePaymentId={nextDueId}` (see ⑫ ISSUE-1)
  - **"Send Reminder"** outline button (when status=Overdue) — SERVICE_PLACEHOLDER toast
  - **Edit** outline button (when NOT Cancelled) → navigates `?mode=edit&id=X` (replaces drawer with full-page FORM)
  - Close X

**Drawer Body Sections** (in order, vertical stack):

**Section 1: Pledge Summary** (2-column grid, 10 info-items, matching mockup `.pledge-summary`):
| Row | Left | Right |
|-----|------|-------|
| 1 | Donor — `donor-link` → contact profile | Status — `status-badge` |
| 2 | Campaign / Purpose — "Children's Education" / fallback purpose name | Payment Method — paymentModeName (or "—") |
| 3 | Total Pledged — **large bold** with currency | Total Fulfilled — **large green** |
| 4 | Outstanding Balance — **large orange** | Fulfillment — inline progress bar + % |
| 5 | Schedule — "$500/month · 24 installments" | Period — "Jan 1, 2025 — Dec 1, 2026" (formatted "MMM d, yyyy") |

**Section 2: Payment Schedule Timeline** (horizontal, color-coded dots, matching mockup `.payment-timeline`):
- Title: `ph:timeline` + "Payment Schedule Timeline"
- Horizontal flex row of `timeline-node`s — 1 per PledgePayment (scrollable overflow-x on mobile)
- Each node: colored dot (20px circle) + amount + date label
  - PAID: green dot with checkmark icon (`ph:check`)
  - UPCOMING: orange dot with clock icon (`ph:clock`)
  - OVERDUE: red dot with warning icon (`ph:warning`)
  - SCHEDULED: grey dot (no icon)
- Connectors between dots (3px tall bars): colored same as upstream node
- Responsive: on mobile (<768px), switch to vertical layout (flex-direction column, connector becomes vertical 3px × 20px)

**Section 3: Payment History Table** (full PledgePayment list, matching mockup `.payment-history-table`):
- Title: `ph:clock-counter-clockwise` + "Payment History"
- Columns: #, Due Date, Due Amount, Paid Date, Paid Amount, Donation Ref, Status
- "Donation Ref" column: when `globalDonationId` set, render as `donor-link` → `/[lang]/crm/donation/globaldonation?mode=read&id={globalDonationId}`; else em-dash
- Status column: `payment-status-chip` renderer (NEW) — color-coded per PaymentStatusCode with icon (Paid=check-circle green, Upcoming=clock orange, Scheduled=square gray, Overdue=warning-circle red)
- Rows sorted by InstallmentNumber ASC

**Section 4: Cancel Pledge** (only when status NOT Cancelled AND NOT Fulfilled):
- Separator line
- "Cancel Pledge" button (danger outline, left-aligned)
- On click: reveals inline form:
  - Textarea "Cancellation Reason *" (2 rows, placeholder "Enter reason for cancellation...")
  - Two buttons: "Confirm Cancel" (danger primary) and "Nevermind" (cancel)
- On confirm: fires `cancelPledge` mutation; drawer refreshes with Cancelled status; toast "Pledge cancelled"

**If Pledge.status = Cancelled**: show a prominent info bar at top of drawer body: "This pledge was cancelled on {cancelledAt formatted}. Reason: {cancelledReason}."

---

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User sees grid with KPI widgets + Overdue Alert Banner → clicks "+New Pledge" → URL: `/crm/donation/pledge?mode=new`
   → **FORM LAYOUT** loads (empty form with 4 sections)
2. User fills form (ContactId, Purpose, Total, Frequency, StartDate) → auto-calc populates InstallmentAmount + N + EndDate → user reviews Schedule Preview → clicks Save
   → API Create: inserts Pledge + N PledgePayments → returns newId
   → URL redirects to `/crm/donation/pledge?mode=read&id={newId}` → **DRAWER** slides in over grid
3. User clicks "Edit" button in drawer → URL: `/crm/donation/pledge?mode=edit&id={id}`
   → Drawer closes; FORM LAYOUT loads pre-filled with existing data
4. User edits amount → Save: BE regenerates future-dated PledgePayments (preserves paid rows) → redirects to `?mode=read&id={id}` → drawer re-opens
5. From grid: user clicks a row → URL: `?mode=read&id={id}` → drawer opens
6. User clicks "Record" on a row with unpaid schedule → navigates to `/crm/donation/globaldonation?mode=new&pledgePaymentId={nextDueId}` (cross-screen deep-link; donation form pre-selects donor + purpose + links result to PledgePayment)
7. User on Overdue Alert Banner → clicks "Send Bulk Reminders" → SERVICE_PLACEHOLDER toast; "View All Overdue" → setFilterChip('overdue') applies
8. Back: clicks back button in FORM or closes drawer → returns to grid list (URL: `/crm/donation/pledge`)
9. Unsaved changes: if FORM is dirty and user navigates, show confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: DonationInKind (#7 COMPLETED) for FLOW+drawer pattern; **RecurringDonationSchedule (#8 PROMPT_READY)** for drawer with KPI widgets + alert banner pattern.

| Canonical (DonationInKind) | → This Entity (Pledge) | Context |
|-----------|--------------|---------|
| DonationInKind | Pledge | Entity/class name |
| donationInKind | pledge | Variable/field names |
| DonationInKindId | PledgeId | PK field |
| DonationsInKind | Pledges | Table name, collection names |
| donation-in-kind | pledge | FE route path, file names |
| donationinkind | pledge | FE folder, import paths |
| DONATIONINKIND | PLEDGE | Grid code, menu code |
| fund | fund | DB schema (same) |
| Donation | Donation | Backend group (same — DonationModels) |
| DonationModels | DonationModels | Namespace suffix (same) |
| CRM_DONATION | CRM_DONATION | Parent menu code (same) |
| CRM | CRM | Module code (same) |
| crm/donation/donationinkind | crm/donation/pledge | FE route path |
| donation-service | donation-service | FE service folder name (same) |
| DecoratorDonationModules.DonationInKind | DecoratorDonationModules.Pledge | Permission decorator property (ADD new entry) |

**Child-entity mapping** (parent-child pattern):
| Canonical (RecurringDonationScheduleDistribution) | → This Entity (PledgePayment) |
|-----------|--------------|
| RecurringDonationScheduleDistribution | PledgePayment |
| Distributions | PledgePayments |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> **Scope: FULL** — nothing exists except FE stub page.tsx. Everything below is CREATE except where marked.

### Backend Files — NEW (create)

| # | File | Path |
|---|------|------|
| 1 | Pledge Entity | `Base.Domain/Models/DonationModels/Pledge.cs` |
| 2 | PledgePayment Entity | `Base.Domain/Models/DonationModels/PledgePayment.cs` |
| 3 | Pledge EF Config | `Base.Infrastructure/Data/Configurations/DonationConfigurations/PledgeConfiguration.cs` |
| 4 | PledgePayment EF Config | `Base.Infrastructure/Data/Configurations/DonationConfigurations/PledgePaymentConfiguration.cs` |
| 5 | Schemas (DTOs — all three: Pledge, PledgePayment, PledgeSummary, PledgeOverdueAlert) | `Base.Application/Schemas/DonationSchemas/PledgeSchemas.cs` |
| 6 | Create Command | `Base.Application/Business/DonationBusiness/Pledges/Commands/CreatePledge.cs` |
| 7 | Update Command | `Base.Application/Business/DonationBusiness/Pledges/Commands/UpdatePledge.cs` |
| 8 | Delete Command | `Base.Application/Business/DonationBusiness/Pledges/Commands/DeletePledge.cs` |
| 9 | Toggle Command | `Base.Application/Business/DonationBusiness/Pledges/Commands/TogglePledge.cs` |
| 10 | Cancel Command | `Base.Application/Business/DonationBusiness/Pledges/Commands/CancelPledge.cs` |
| 11 | GetAll Query | `Base.Application/Business/DonationBusiness/Pledges/Queries/GetPledges.cs` |
| 12 | GetById Query | `Base.Application/Business/DonationBusiness/Pledges/Queries/GetPledgeById.cs` |
| 13 | GetSummary Query | `Base.Application/Business/DonationBusiness/Pledges/Queries/GetPledgeSummary.cs` |
| 14 | GetOverdueAlert Query | `Base.Application/Business/DonationBusiness/Pledges/Queries/GetPledgeOverdueAlert.cs` |
| 15 | GetNextDue Query (helper for cross-screen deep-link) | `Base.Application/Business/DonationBusiness/Pledges/Queries/GetNextDuePledgePayment.cs` |
| 16 | Mutations Endpoint | `Base.API/EndPoints/Donation/Mutations/PledgeMutations.cs` |
| 17 | Queries Endpoint | `Base.API/EndPoints/Donation/Queries/PledgeQueries.cs` |
| 18 | EF Migration | `Base.Infrastructure/Data/Migrations/{timestamp}_AddPledgeAndPledgePayment.cs` (add both tables + indexes + FKs) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Data/Persistence/IDonationDbContext.cs` | Add `DbSet<Pledge> Pledges` + `DbSet<PledgePayment> PledgePayments` |
| 2 | `Base.Infrastructure/Data/Persistence/DonationDbContext.cs` | Same DbSet properties; register configurations |
| 3 | `Base.Application/Extensions/DecoratorProperties.cs` | Add `DecoratorDonationModules.Pledge` const (exact string "Pledge" matching EntityName) |
| 4 | `Base.Application/Mappings/DonationMappings.cs` | Mapster configs for: PledgeRequestDto ↔ Pledge, PledgeResponseDto ← Pledge (with projections), PledgePaymentResponseDto ← PledgePayment, PledgeSummaryDto (in-memory), PledgeOverdueAlertDto (in-memory) |
| 5 | `Base.Application/MasterData/*` seed (if exists) | Three new typeCodes — see ⑨ CONFIG |
| 6 | `Base.API/GlobalUsing.cs` (×3 if applicable) | Add new namespace if new sub-folder |

### Frontend Files — MODIFY

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Route stub | `Pss2.0_Frontend/src/app/[lang]/crm/donation/pledge/page.tsx` | **OVERWRITE** (currently 3-line stub) — renders new index.tsx dispatcher |

### Frontend Files — NEW (create)

| # | File | Path |
|---|------|------|
| 2 | DTO Types | `Pss2.0_Frontend/src/domain/entities/donation-service/PledgeDto.ts` (PledgeResponseDto, PledgeRequestDto, PledgePaymentResponseDto, PledgeSummaryDto, PledgeOverdueAlertDto) |
| 3 | GQL Query | `Pss2.0_Frontend/src/infrastructure/gql-queries/donation-queries/PledgeQuery.ts` (PLEDGES_QUERY, PLEDGE_BY_ID_QUERY, PLEDGE_SUMMARY_QUERY, PLEDGE_OVERDUE_ALERT_QUERY, NEXT_DUE_PLEDGE_PAYMENT_QUERY) |
| 4 | GQL Mutation | `Pss2.0_Frontend/src/infrastructure/gql-mutations/donation-mutations/PledgeMutation.ts` (CREATE_PLEDGE_MUTATION, UPDATE_PLEDGE_MUTATION, DELETE_PLEDGE_MUTATION, TOGGLE_PLEDGE_MUTATION, CANCEL_PLEDGE_MUTATION) |
| 5 | Page Config | `Pss2.0_Frontend/src/presentation/pages/crm/donation/pledge.tsx` |
| 6 | Index (URL dispatcher) | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/index.tsx` |
| 7 | Index Page (Variant B) | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/index-page.tsx` |
| 8 | View Page (FORM for new/edit) | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/view-page.tsx` |
| 9 | Pledge Form Body (extracted from view-page for reuse) | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-create-form.tsx` |
| 10 | Zustand Store | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-store.ts` |
| 11 | Detail Drawer (720px) | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-detail-drawer.tsx` |
| 12 | KPI Widgets | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-widgets.tsx` (4 cards, takes summary as prop) |
| 13 | Overdue Alert Banner | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-overdue-alert-banner.tsx` (collapsible) |
| 14 | Filter Chips Bar | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-filter-chips.tsx` (5 chips) |
| 15 | Advanced Filter Panel | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-advanced-filters.tsx` (collapsible, 7 fields) |
| 16 | Payment Timeline (shared by drawer + form preview) | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-payment-timeline.tsx` |
| 17 | Payment History Table (in drawer) | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-payment-history-table.tsx` |
| 18 | Cancel Pledge inline form (in drawer) | `Pss2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-cancel-form.tsx` |
| 19 | Renderer: donor-link | `Pss2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/donor-link.tsx` (NEW — reusable across pledge, recurring, chequedonation) |
| 20 | Renderer: currency-amount | `Pss2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/currency-amount.tsx` (NEW — reusable, right-aligned monospace with currency symbol) |
| 21 | Renderer: fulfillment-progress | `Pss2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/fulfillment-progress.tsx` (NEW — 6px horizontal bar + % label, color by status) |
| 22 | Renderer: payment-status-chip | `Pss2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/payment-status-chip.tsx` (NEW — for Payment History table, color+icon per PaymentStatusCode) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `application/configs/data-table-configs/donation-service-entity-operations.ts` | Add `PLEDGE` block: list-query, byId-query, create/update/delete/toggle/cancel mutations |
| 2 | `application/configs/data-table-configs/operations-config.ts` | Import + register PLEDGE operations |
| 3 | `presentation/components/data-table/component-column.tsx` (advanced) | Register 4 new renderer keys: `donor-link`, `currency-amount`, `fulfillment-progress`, `payment-status-chip` |
| 4 | `presentation/components/data-table/basic/component-column.tsx` | Same 4 keys |
| 5 | `presentation/components/data-table/flow/component-column.tsx` | Same 4 keys |
| 6 | `presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` | Export 4 new renderers |
| 7 | Sidebar menu config | (registered via DB seed) — verify appears under CRM_DONATION at OrderBy=5 |
| 8 | Route definition | (next.js file-based) — `page.tsx` already exists at the correct route; only content changes |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Pledges
MenuCode: PLEDGE
ParentMenu: CRM_DONATION
Module: CRM
MenuUrl: crm/donation/pledge
GridType: FLOW
OrderBy: 5

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: PLEDGE

MasterDataSeeds:
  PLEDGEFREQUENCY:
    - { dataName: "Monthly",      dataValue: "30",  orderBy: 1, isDefault: true }
    - { dataName: "Quarterly",    dataValue: "90",  orderBy: 2 }
    - { dataName: "Semi-Annual",  dataValue: "180", orderBy: 3 }
    - { dataName: "Annual",       dataValue: "365", orderBy: 4 }
    - { dataName: "Custom",       dataValue: "0",   orderBy: 5 }
  PLEDGESTATUS:
    - { dataName: "On Track",   dataValue: "ONTRACK",   colorHex: "#166534", orderBy: 1, isDefault: true }
    - { dataName: "Fulfilled",  dataValue: "FULFILLED", colorHex: "#0e7490", orderBy: 2 }
    - { dataName: "Overdue",    dataValue: "OVERDUE",   colorHex: "#991b1b", orderBy: 3 }
    - { dataName: "Behind",     dataValue: "BEHIND",    colorHex: "#9a3412", orderBy: 4 }
    - { dataName: "Cancelled",  dataValue: "CANCELLED", colorHex: "#475569", orderBy: 5 }
  PLEDGEPAYMENTSTATUS:
    - { dataName: "Paid",       dataValue: "PAID",      colorHex: "#166534", orderBy: 1 }
    - { dataName: "Upcoming",   dataValue: "UPCOMING",  colorHex: "#92400e", orderBy: 2 }
    - { dataName: "Scheduled",  dataValue: "SCHEDULED", colorHex: "#64748b", orderBy: 3, isDefault: true }
    - { dataName: "Overdue",    dataValue: "OVERDUE",   colorHex: "#991b1b", orderBy: 4 }

GridFields (for FLOW grid — 11 columns, NO GridFormSchema):
  1. pledgeCode              | Pledge ID          | text-bold        | 110 | sortable
  2. donorName               | Donor              | donor-link       | 180 | sortable
  3. campaignOrPurposeName   | Campaign / Purpose | text             | auto| sortable
  4. totalPledgedAmount      | Total Pledged      | currency-amount  | 120 | sortable
  5. fulfilledAmount         | Fulfilled          | currency-amount  | 110 | sortable
  6. outstandingBalance      | Balance            | currency-amount  | 110 | sortable
  7. fulfillmentPercent      | Fulfillment        | fulfillment-progress | 140 | sortable
  8. scheduleDisplay         | Schedule           | text             | 110 |
  9. nextDueDate             | Next Due           | DateOnlyPreview  | 110 | sortable
  10. computedStatusCode     | Status             | status-badge     | 100 | sortable
  11. (actions)              | Actions            | row-action-menu  | 100 |
---CONFIG-END---
```

DB seed file location: `sql-scripts-dyanmic/` (preserve repo typo "dyanmic" per #6 ISSUE-15 precedent).

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `PledgeQueries` (class under `Base.API/EndPoints/Donation/Queries`)
- Mutation type: `PledgeMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `pledges` | [PledgeResponseDto] (paginated via existing DataTableRequestDto pattern) | `searchText`, `pageNo`, `pageSize`, `sortField`, `sortDir`, `isActive`, `chip` (all/active/fulfilled/overdue/cancelled), `campaignId`, `donationPurposeId`, `amountMin`, `amountMax`, `fulfillmentMin`, `fulfillmentMax`, `startDateFrom`, `startDateTo` |
| `pledgeById` | PledgeResponseDto (includes `paymentSchedule: [PledgePaymentResponseDto]` inline) | `pledgeId` |
| `pledgeSummary` ⭐ NEW | PledgeSummaryDto | — |
| `pledgeOverdueAlert` ⭐ NEW | [PledgeOverdueAlertDto] (top 5) | — |
| `nextDuePledgePayment` ⭐ NEW (helper for cross-screen deep-link) | PledgePaymentResponseDto \| null | `pledgeId` |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createPledge` | PledgeRequestDto (no paymentSchedule — BE auto-generates) | int (new pledgeId) |
| `updatePledge` | PledgeRequestDto (with pledgeId; BE regenerates unpaid rows) | int |
| `deletePledge` | pledgeId | int |
| `togglePledge` | pledgeId | int |
| `cancelPledge` | pledgeId, cancelledReason (string 500) | int |

**PledgeResponseDto Fields** (what FE receives):
| Field | Type | Notes |
|-------|------|-------|
| pledgeId | number | PK |
| pledgeCode | string | PLG-NNNN |
| contactId | number | FK |
| donorName | string | projected — Contact.DisplayName |
| donorCode | string | projected — Contact.ContactCode |
| donorAvatarColor | string \| null | projected — derived from contactId hash |
| campaignId | number \| null | FK |
| campaignName | string \| null | projected |
| donationPurposeId | number | FK |
| donationPurposeName | string | projected |
| campaignOrPurposeName | string | projected — campaignName ?? donationPurposeName |
| currencyId | number | FK |
| currencyCode | string | projected — "USD" |
| totalPledgedAmount | number | — |
| startDate | string (ISO) | — |
| endDate | string (ISO) \| null | — |
| frequencyId | number | FK |
| frequencyName | string | projected — "Monthly" |
| frequencySuffix | string | projected — "/mo" |
| installmentAmount | number | — |
| numberOfInstallments | number | — |
| paymentModeId | number \| null | FK |
| paymentModeName | string \| null | projected |
| pledgeStatusId | number | FK (stored — typically reflects non-terminal ONTRACK unless Cancelled) |
| computedStatusCode | string | projected — "ONTRACK"/"FULFILLED"/"OVERDUE"/"BEHIND"/"CANCELLED" |
| computedStatusName | string | projected — "On Track"/"Fulfilled"/etc. |
| computedStatusColor | string | projected hex — matches MasterData ColorHex |
| fulfilledAmount | number | projected subquery |
| outstandingBalance | number | projected — total − fulfilled |
| fulfillmentPercent | number | projected 0–100 |
| nextDueDate | string (ISO) \| null | projected — MIN unpaid DueDate |
| nextDueAmount | number \| null | projected |
| nextDuePledgePaymentId | number \| null | projected — for Record Payment deep-link |
| overdueCount | number | projected |
| overdueAmount | number | projected |
| scheduleDisplay | string | projected — "$500/mo" (installmentAmount + currency + freqSuffix) |
| cancelledAt | string (ISO) \| null | — |
| cancelledReason | string \| null | — |
| notes | string \| null | — |
| paymentSchedule | [PledgePaymentResponseDto] | Only populated in `pledgeById` (NOT in `pledges` list) — lazy-loaded in drawer |
| createdBy / createdDate / modifiedBy / modifiedDate | string | inherited audit |
| isActive | boolean | inherited |

**PledgePaymentResponseDto Fields**:
| Field | Type |
|-------|------|
| pledgePaymentId | number |
| pledgeId | number |
| installmentNumber | number |
| dueDate | string (ISO) |
| dueAmount | number |
| paidDate | string (ISO) \| null |
| paidAmount | number \| null |
| globalDonationId | number \| null |
| donationReceiptCode | string \| null |
| paymentStatusId | number |
| paymentStatusCode | string (PAID/UPCOMING/SCHEDULED/OVERDUE) |
| paymentStatusName | string |
| paymentStatusColor | string (hex) |
| daysUntilDue | number (signed — negative = overdue days) |

**PledgeSummaryDto Fields**:
| Field | Type | Notes |
|-------|------|-------|
| activePledgesCount | number | — |
| totalActivePledgedAmount | number | sum of TotalPledgedAmount for non-cancelled, non-fulfilled |
| fulfilledAmountYtd | number | sum of PledgePayment.PaidAmount where PaidDate >= Jan 1 current year |
| fulfilledPledgeCountYtd | number | count of pledges fulfilled this year |
| outstandingBalanceTotal | number | sum of outstandingBalance across active pledges |
| overdueCount | number | count of OVERDUE PledgePayments |
| overdueAmountTotal | number | sum of OVERDUE PledgePayment.DueAmount |
| currencyCode | string | Company.DefaultCurrencyCode — display currency for the KPIs |

**PledgeOverdueAlertDto Fields**:
| Field | Type |
|-------|------|
| pledgePaymentId | number |
| pledgeId | number |
| pledgeCode | string |
| donorName | string |
| contactId | number |
| dueDate | string (ISO) |
| dueAmount | number |
| currencyCode | string |
| daysOverdue | number (positive int) |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (new Pledge + PledgePayment entities, both migrations applied to test DB)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/donation/pledge`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] ScreenHeader renders title + subtitle + +New Pledge + Export dropdown (3 export options — SERVICE_PLACEHOLDER toasts)
- [ ] 4 KPI widgets render with correct values from `pledgeSummary`
- [ ] Overdue Alert Banner appears when `summary.overdueCount > 0`; default expanded; chevron toggles
- [ ] Banner "Send Bulk Reminders" → toast; "View All Overdue" → chip flips to Overdue
- [ ] Banner body shows top 5 overdue with per-row Send Reminder button (SERVICE_PLACEHOLDER)
- [ ] Grid renders 11 columns with correct renderers; overdue rows have red-tinted background; cancelled rows at 60% opacity
- [ ] Filter chips: All/Active/Fulfilled/Overdue/Cancelled — each filters correctly
- [ ] Advanced filters: Campaign, Purpose, Amount Min+Max, Fulfillment %, Start Date From+To — Apply + Clear work
- [ ] Search by donor name / pledge code works
- [ ] `?mode=new`: FORM renders 4 sections (Donor & Purpose, Pledge Details, Payment Schedule, Additional)
- [ ] Changing TotalPledgedAmount + Frequency auto-computes InstallmentAmount + NumberOfInstallments; user can override either
- [ ] Schedule Preview below Payment Schedule section shows first-6 + "… N more" dot timeline
- [ ] Save creates Pledge + N PledgePayments → URL changes to `?mode=read&id={newId}` → drawer opens (720px, right-side slide-in)
- [ ] `?mode=edit&id=X`: FORM pre-filled; editing frequency/amount regenerates future-dated unpaid PledgePayments (paid rows preserved)
- [ ] Row click on grid → drawer opens with URL sync
- [ ] Drawer shows: Summary (10 items 2-col), Payment Schedule Timeline (horizontal color-coded dots), Payment History Table (all PledgePayments), Cancel Pledge action
- [ ] Drawer header: Record Payment (when nextDuePledgePaymentId exists) + Send Reminder (when overdue) + Edit + Close
- [ ] "Record Payment" button → navigates to `/[lang]/crm/donation/globaldonation?mode=new&pledgePaymentId={nextDueId}`
- [ ] Cancel button → inline form → reason textarea → Confirm Cancel fires `cancelPledge` → drawer refreshes with Cancelled status badge + info bar
- [ ] Pledge status auto-computed: OnTrack → Behind (when fulfilled < expected-by-today) → Overdue (when any payment past due) → Fulfilled (when all paid)
- [ ] Grid row "Record" action works same as drawer Record Payment button
- [ ] Grid row "Remind" action (status=Overdue) → SERVICE_PLACEHOLDER toast
- [ ] Grid row "Edit" → `?mode=edit&id=X` → FORM loads pre-filled
- [ ] Grid row "Delete" hard-deletes only when no PAID PledgePayments; else soft-toggles IsActive
- [ ] Unsaved changes dialog triggers on dirty FORM navigation
- [ ] Donor-link click → `/[lang]/crm/contact/allcontacts?mode=read&id={contactId}`
- [ ] Mobile (<768px): drawer full-width; timeline switches to vertical; KPI grid becomes 2×2

**DB Seed Verification:**
- [ ] Menu "Pledges" appears in sidebar under "CRM → Donations" at OrderBy=5
- [ ] Grid renders with 11 FLOW columns mapped to correct renderers (GridFormSchema=NULL for FLOW)
- [ ] PLEDGESTATUS, PLEDGEFREQUENCY, PLEDGEPAYMENTSTATUS MasterData rows exist with correct dataValues + ColorHex
- [ ] Default Frequency = Monthly; default PledgePaymentStatus (inferred from day-of-creation) = Scheduled

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT sent by FE** — on both Pledge and PledgePayment inputs. BE resolves from HttpContext. Denormalized onto PledgePayment for index-scan performance.
- **FLOW screens do NOT generate GridFormSchema** in DB seed — GridFormSchema: SKIP.
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout; read triggers drawer over grid (not a separate page navigation).
- **DETAIL is a 720px right-side slide-in drawer**, NOT a separate full page. URL sync `?mode=read&id=X` is for back-button + deep-linking only.
- **Payment schedule is BE-generated** — FE sends only the Pledge form fields; BE auto-generates PledgePayment rows on Create and regenerates future-dated unpaid rows on Update.
- **Computed status code is NEVER set by FE** — BE computes on every read. Only `pledgeStatusId` is stored (and only updated on Cancel).
- **Two NEW shared renderers** (`donor-link`, `currency-amount`) will be reused by Refund #13, Matching Gift #11 trackers, and future screens — plan naming and props for reuse.
- **GraphQL naming convention**: queries use camelCase plural (e.g., `pledges`, `pledgeById`, `pledgeSummary`) — NOT `GetAllPledgeList`. Matches existing `contacts`, `campaigns`, `donationPurposes` pattern.
- **FK paths verified**: Contact is in `ContactModels` (not CorgModels); Campaign is in `ApplicationModels`; DonationPurpose is in `DonationModels`; PaymentMode + Currency + MasterData are in `SharedModels`. These are the actual folders in the current repo at `PSS_2.0_Backend/.../Base.Domain/Models/`.
- **Route stub overwrite**: `Pss2.0_Frontend/src/app/[lang]/crm/donation/pledge/page.tsx` currently contains 3 lines (`<div>Need To Develop</div>`). FE dev must OVERWRITE with the new dispatcher import.

### § Pre-flagged Issues (for BA + Dev awareness)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | HIGH | Cross-screen integration | "Record Payment" deep-link to GlobalDonation form `?pledgePaymentId=X` assumes the donation form accepts this query param and pre-fills donor + purpose + links the created GlobalDonation back to PledgePayment.GlobalDonationId. **Current GlobalDonation form does NOT handle this param** — FE dev must add query-param handler; BE must add `pledgePaymentId` arg to `createGlobalDonation` mutation OR add a dedicated `linkDonationToPledgePayment` post-create mutation. Prefer the latter for separation of concerns. | OPEN |
| ISSUE-2 | MEDIUM | Cross-screen integration | Donor-link click → `/[lang]/crm/contact/allcontacts?mode=read&id={contactId}` assumes Contact screen supports this URL param (Contact #18 not yet built). Until Contact FLOW is built, donor-link click should either no-op gracefully or open a minimal inline mini-card modal. Prefer: render link but when target screen stub → show toast "Contact detail view coming soon." | OPEN |
| ISSUE-3 | MEDIUM | Data model | Computed status `BEHIND` requires comparing `fulfilledAmount` to `expectedByToday = InstallmentAmount × floor((today − StartDate) / frequencyDays)`. For `FrequencyId = Custom` (no standard days), the computation is ambiguous. Decision needed: for Custom, either (a) require NumberOfInstallments + individual DueDates and compute expected from schedule, or (b) skip BEHIND for Custom (only OnTrack / Overdue / Fulfilled / Cancelled). **Recommendation: (a) — use PledgePayment schedule as source of truth, sum DueAmount where DueDate ≤ today**. BE dev to confirm. | OPEN |
| ISSUE-4 | LOW | UI | Mockup shows "Currency" + "Total Pledged Amount" in 4-col + 8-col layout within one row (row g-3 col-md-4 + col-md-8). FE dev should replicate this precisely for layout fidelity. | OPEN |
| ISSUE-5 | MEDIUM | Data integrity | `updatePledge` regeneration logic must be idempotent and atomic — use a transaction; log which PledgePayment rows were deleted/regenerated for audit. Consider moving to a stored procedure or service method rather than inline LINQ-to-SQL. | OPEN |
| ISSUE-6 | LOW | MasterData | `PLEDGEFREQUENCY.dataValue = "0"` for Custom is a convention used only by BE when detecting "no auto-calc"; FE must handle this flag explicitly (show Custom UI branch). Document in FE dto. | OPEN |
| ISSUE-7 | MEDIUM | BE performance | GetAll with projected `fulfilledAmount`, `outstandingBalance`, `fulfillmentPercent`, `nextDueDate`, `overdueCount`, `overdueAmount` = 6 per-row subqueries. Must verify EF generates single SQL with LATERAL joins or CTEs, not N+1. Add integration perf test if scaling > 5K pledges expected. | OPEN |
| ISSUE-8 | LOW | UI fidelity | Mockup uses Font Awesome icons (`fa-handshake`, `fa-triangle-exclamation`, `fa-timeline`, etc.). Per `feedback_ui_uniformity` memory, FE dev must translate to @iconify/react Phosphor equivalents (`ph:handshake`, `ph:warning`, `ph:timeline`, etc.). Build a quick mapping table at implementation. | OPEN |
| ISSUE-9 | MEDIUM | Schedule regen edge case | When user edits Pledge.StartDate to a past date or EndDate to a future date AFTER some payments were recorded, the regeneration must respect the "last paid installment" as the anchor and restart from installmentNumber = lastPaidInstallmentNumber + 1. Specify test case: start Jan 1 → 2 payments recorded for Jan/Feb → user moves StartDate to Mar 1 → BE should DELETE unpaid rows from installment 3 onward and REGENERATE from installment 3 at the new date. | OPEN |
| ISSUE-10 | LOW | FLOW pattern drift | Registry claim "FE route exists" is technically true (3-line stub returns `<div>`), but fully non-functional. Treat as FULL scope (not ALIGN) — no existing useful FE code to preserve. | RESOLVED — acknowledged in manifest |
| ISSUE-11 | LOW | Renderer sharing | `donor-link` and `currency-amount` are generic names. FE dev should verify no naming collision in existing registries before creating; if any collision, suffix with `-cell` (e.g., `donor-link-cell`). | OPEN |
| ISSUE-12 | LOW | Summary currency mixing | If Company has pledges in multiple currencies (mockup shows USD, AED, INR), summing `totalPledgedAmount` across rows produces nonsense. **Recommendation**: `pledgeSummary` should filter to Company's default currency OR use a currency conversion service (out of scope — SERVICE_PLACEHOLDER). Short-term: display only default-currency pledges in KPIs; add subtitle "(in {defaultCurrencyCode})". | OPEN |
| ISSUE-13 | LOW | URL sync for drawer | Closing the drawer must clear `?mode=read&id=X` from the URL (but preserve chip/search/filter params). Use `router.replace` with preserved URLSearchParams minus `mode` + `id`. Confirm the same pattern used in DonationInKind works here (read that file if needed). | OPEN |
| ISSUE-14 | MEDIUM | Record Payment flow completeness | After a GlobalDonation is created and linked to a PledgePayment, the PledgePayment row must transition to PAID with PaidDate = GlobalDonation.DonationDate and PaidAmount = GlobalDonation.DonationAmount. This is a BE trigger — either inline in `createGlobalDonation` when `pledgePaymentId` is passed, or via a post-save event handler. Specify in BA validation. | OPEN |
| ISSUE-15 | LOW | DB seed path | DB seed file must go in `sql-scripts-dyanmic/` (note repo typo "dyanmic") — do NOT rename the folder. Precedent from #6 ChequeDonation ISSUE-15. | OPEN |

### § Service Dependencies (UI-only — no backend service implementation)

- **⚠ SERVICE_PLACEHOLDER: Send Reminder** (per-pledge + per-overdue-row) — full UI implemented (buttons + hover states + loading spinner). Handler toasts "Reminder sent to {donorName}" because SMS/Email notification service layer isn't wired up yet. Wire-up target: Notification service (Notification Templates #30 + Notification Center #32 when built).
- **⚠ SERVICE_PLACEHOLDER: Send Bulk Reminders** (overdue banner) — full UI. Handler toasts "Bulk reminders sent to {N} donors". Same service dependency as above.
- **⚠ SERVICE_PLACEHOLDER: Export (Excel / CSV / PDF)** — full UI dropdown. Handler toasts. Export service not implemented platform-wide.

Full UI must be built (buttons, overdue banner, cancel form, drawer, timeline, history table, interactions). Only the external-service handlers are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 to ISSUE-15 | planning | — | — | See ⑫ above — pre-flagged during planning; status OPEN except ISSUE-10 RESOLVED | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
