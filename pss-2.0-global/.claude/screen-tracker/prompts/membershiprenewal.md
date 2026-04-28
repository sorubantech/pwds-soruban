---
screen: MembershipRenewal
registry_id: 60
module: Membership
status: COMPLETED
scope: FULL
screen_type: MASTER_GRID
complexity: High
new_module: NO (bootstrapped by #58 MembershipTier — `mem` schema, `IMemDbContext`, `MemMappings`, `DecoratorMemModules`). This screen only adds 2 new entities into the existing `mem` infra.
planned_date: 2026-04-24
completed_date: 2026-04-26
last_session_date: 2026-04-26
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/membership/membership-renewals.html`)
- [x] Existing code reviewed (FE stub only — `crm/membership/membershiprenewal/page.tsx` = "Need to Develop")
- [x] Business rules extracted
- [x] FK targets resolved — **2 FKs depend on #58 & #59 prompts (PROMPT_READY, must build first)**. See §⑫.
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (skipped per session directive — prompt already contains rich analysis)
- [x] Solution Resolution complete (pre-stamped in prompt §⑤)
- [x] UX Design finalized (pre-stamped in prompt §⑥)
- [x] User Approval received (granted upfront by user via /build-screen args)
- [x] Backend code generated (reuses `mem` schema infra created by #58)
- [x] Backend wiring complete
- [x] Frontend code generated
- [x] Frontend wiring complete
- [x] DB Seed script generated (MasterData types + default config row)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/crm/membership/membershiprenewal`
- [ ] Grid renders 9 columns with 5 filter tabs (All Upcoming / Due This Month / Overdue / Auto-Renew Failures / Recently Renewed)
- [ ] 4 KPI cards show correct values (Due This Month / Overdue / Auto-Renew Enabled ratio / Renewal Rate YTD)
- [ ] Per-row "Renew" button opens bespoke modal with member summary + upgrade tier + payment method + auto-renew toggle
- [ ] "Process Renewal" creates a MembershipRenewal row, bumps MemberEnrollment.EndDate, optionally upgrades tier
- [ ] Per-row "Retry" (visible only on AutoRenewFailed status) fires RetryFailedAutoRenewal command
- [ ] Per-row "Remind" button fires individual reminder (SERVICE_PLACEHOLDER toast)
- [ ] Header "Send Renewal Reminders" bulk action (SERVICE_PLACEHOLDER toast)
- [ ] Header "Process All Auto-Renewals" bulk action (SERVICE_PLACEHOLDER toast)
- [ ] Header "Export" downloads CSV of current filter view
- [ ] Auto-Renewal Settings collapsible panel loads/saves MembershipRenewalConfig row (company-scoped upsert)
- [ ] Member name click → navigates to `/crm/membership/memberlist?id={memberEnrollmentId}` (#59 detail)
- [ ] DB Seed — menu visible in sidebar under CRM → Membership → Renewals (OrderBy=4)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: MembershipRenewal
Module: Membership (CRM)
Schema: `mem`
Group: Mem (namespace: `Base.Domain.Models.MemModels`; business folder: `MemBusiness`; schemas folder: `MemSchemas`; EF-config folder: `MemConfigurations`)

Business: Membership Renewals is the ops screen NGO membership coordinators use to chase and process expiring member subscriptions. It surfaces every `MemberEnrollment` approaching its `EndDate` (upcoming / expiring-soon / overdue), every auto-renewal that failed, and every renewal that recently completed — with per-row actions to process a renewal, retry a failed auto-charge, or fire a reminder. A collapsible company-level Auto-Renewal Settings panel at the bottom lets admins tune retry policy (attempts, interval, grace period) and the reminder schedule (60/30/7-day pre-expiry + expiry + grace notices across Email/SMS/WhatsApp channels). It is a **workflow grid over MemberEnrollment**: rows are generated from the enrollment ledger (not added manually), and the "Renew" modal writes a new `MembershipRenewal` transaction row while bumping the `MemberEnrollment.EndDate` forward. Sits between `MemberEnrollment` (#59 — the subscription contract) and `MembershipTier` (#58 — the price book); tier upgrades from this screen mutate `MemberEnrollment.MembershipTierId`.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Two new entities: `MembershipRenewal` (transaction ledger) + `MembershipRenewalConfig` (per-company settings singleton).

### Table 1: `mem."MembershipRenewals"` (transaction ledger — one row per processed renewal event)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MembershipRenewalId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | (IndependentRoot) | Multi-tenant scope |
| MemberEnrollmentId | int | — | YES | `mem.MemberEnrollments` | Parent subscription (CASCADE) |
| PreviousTierId | int | — | YES | `mem.MembershipTiers` | Tier at renewal time |
| NewTierId | int? | — | NO | `mem.MembershipTiers` | Only set if upgrade applied |
| RenewalAmount | decimal(18,2) | — | YES | — | Amount charged (reflects upgrade delta if any) |
| CurrencyId | int? | — | NO | `shr.Currencies` | Defaults to enrollment.CurrencyId |
| PaymentModeId | int? | — | NO | `sett.MasterDatas` (TypeCode `PAYMENTMODE`) | Stored as MasterDataId — same pattern as #59 |
| PaymentTransactionId | int? | — | NO | `don.PaymentTransactions` | Linked gateway txn (for online payments) |
| PreviousEndDate | DateTime | — | YES | — | Enrollment end before renewal |
| NewEndDate | DateTime? | — | NO | — | Enrollment end after renewal (null until processed) |
| RenewalDate | DateTime? | — | NO | — | When processed; null until processed |
| StatusId | int | — | YES | `sett.MasterDatas` (TypeCode `RENEWALSTATUS`) | Upcoming / ExpiringSoon / Overdue / AutoRenewFailed / Renewed — follow #59 StatusId-as-MasterDataId pattern |
| IsAutoRenewal | bool | — | YES | — | Was this row processed by the auto-renew job? |
| AutoRenewAtTimeOfRenewal | bool | — | YES | — | Mirror of MemberEnrollment.AutoRenew at row creation |
| RemindersSentCount | int | — | YES | — | Default 0 |
| LastReminderDate | DateTime? | — | NO | — | Most recent reminder timestamp |
| LastReminderChannels | string? | 100 | NO | — | CSV: "Email,SMS" — channels used on last reminder |
| FailureReason | string? | 500 | NO | — | Populated when Status=AutoRenewFailed |
| RetryCount | int | — | YES | — | Default 0 |
| Notes | string? | 1000 | NO | — | Free-text |

**Computed (NotMapped) fields** populated by GetAll query handler:

| NotMapped Field | C# Type | Source |
|-----------------|---------|--------|
| MemberName | string | `MemberEnrollment.Contact.FirstName + " " + Contact.LastName` |
| MemberCode | string | `MemberEnrollment.MemberCode` (e.g., `MEM-0023`) |
| CurrentTierName | string | `PreviousTier.TierName` |
| CurrentTierAnnualFee | decimal | `PreviousTier.AnnualFee` |
| NewTierName | string? | `NewTier.TierName` |
| PaymentModeName | string? | `MasterData.DataName` (PAYMENTMODE row) |
| StatusName | string | `MasterData.DataName` (RENEWALSTATUS row) — e.g., "Upcoming" |
| DaysLeft | int | `(PreviousEndDate - DateTime.UtcNow.Date).Days` — negative = overdue |

### Table 2: `mem."MembershipRenewalConfigs"` (per-company settings singleton)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MembershipRenewalConfigId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | (IndependentRoot) | UNIQUE per company |
| RetryAttempts | int | — | YES | — | Default 3 (range 1-5) |
| RetryIntervalDays | int | — | YES | — | Default 3 (range 1-7) |
| GracePeriodDays | int | — | YES | — | Default 30 (range 0-60) — company-wide default; overridden per-tier by `MembershipTier.GracePeriodDays` |
| ReminderScheduleJson | string | 2000 | YES | — | JSON array of reminder rows (see below) |

**ReminderScheduleJson shape** (stored as JSON, edited via settings panel):
```json
[
  { "timing": "60_DAYS_BEFORE", "label": "60 days before", "email": true, "sms": false, "whatsapp": false },
  { "timing": "30_DAYS_BEFORE", "label": "30 days before", "email": true, "sms": true, "whatsapp": false },
  { "timing": "7_DAYS_BEFORE",  "label": "7 days before",  "email": true, "sms": true, "whatsapp": true },
  { "timing": "ON_EXPIRY",      "label": "On expiry",      "email": true, "sms": false, "whatsapp": false },
  { "timing": "GRACE_15_DAYS",  "label": "Grace period (15 days)", "finalNotice": true }
]
```

**Child Entities**: None.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)
> Both `MemberEnrollment` and `MembershipTier` entity files are defined in PROMPT_READY prompts (#58, #59) that must build to COMPLETED before this screen can compile.

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| MemberEnrollmentId | MemberEnrollment | `Base.Domain/Models/MemModels/MemberEnrollment.cs` (built by #59) | `getMemberEnrollments` | `MemberCode + Contact.FirstName + Contact.LastName` | `MemberEnrollmentResponseDto` |
| PreviousTierId / NewTierId | MembershipTier | `Base.Domain/Models/MemModels/MembershipTier.cs` (built by #58) | `getMembershipTiers` | `TierName` | `MembershipTierResponseDto` |
| PaymentModeId | MasterData (TypeCode=`PAYMENTMODE`) | `Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (filter `masterDataTypeCode=PAYMENTMODE`) | `DataName` | `MasterDataResponseDto` |
| StatusId | MasterData (TypeCode=`RENEWALSTATUS`) | `Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (filter `masterDataTypeCode=RENEWALSTATUS`) | `DataName` | `MasterDataResponseDto` |
| PaymentTransactionId | PaymentTransaction | `Base.Domain/Models/DonationModels/PaymentTransaction.cs` | (not user-facing — created internally by ProcessRenewal) | — | — |
| CurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `getCurrencies` | `CurrencyCode` | `CurrencyResponseDto` |

**Dropdown usage**:
- MemberEnrollment / MembershipTier — **not** free-choice dropdowns in the modal; the row context supplies these. Exception: **Upgrade Tier** selector in modal calls `getMembershipTiers` and filters client-side to `tier.AnnualFee > currentTier.AnnualFee` (or `SortOrder > currentTier.SortOrder`).
- PaymentMode — modal dropdown via `getMasterDatas({ masterDataTypeCode: "PAYMENTMODE" })`.
- RenewalStatus — not in form; badge in grid only.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules**:
- `MembershipRenewalConfig.CompanyId` — UNIQUE (one config row per company; upsert semantics)
- `(MemberEnrollmentId, PreviousEndDate)` — logical uniqueness: only one processed renewal per enrollment-cycle (enforced by ProcessRenewal handler check, not a DB constraint — a failed auto-renewal retry creates no new row)

**Required Field Rules**:
- MemberEnrollmentId, PreviousTierId, RenewalAmount, PreviousEndDate, StatusId are mandatory
- On Status=Renewed: RenewalDate, NewEndDate, PaymentModeId MUST be populated
- On Status=AutoRenewFailed: FailureReason MUST be populated

**Conditional Rules**:
- If `NewTierId IS NOT NULL` → `RenewalAmount` must equal `NewTier.AnnualFee` (validated against MembershipTier)
- If `NewTierId IS NULL` → `RenewalAmount` must equal `PreviousTier.AnnualFee`
- `NewEndDate` default = `PreviousEndDate + 1 year` (annual cycle). If `PreviousTier.PricingModelCode == "FIXED_MONTHLY"`, use `+1 month`. For Lifetime tiers, `NewEndDate` remains NULL (renewal is a no-op and the row should not appear in the grid).
- Auto-renew config: `RetryAttempts ∈ [1,5]`, `RetryIntervalDays ∈ [1,7]`, `GracePeriodDays ∈ [0,60]`

**Grace-period precedence**:
- Per-tier `MembershipTier.GracePeriodDays` overrides the company-level `MembershipRenewalConfig.GracePeriodDays` whenever both are set. Implementation: `effectiveGrace = tier.GracePeriodDays ?? config.GracePeriodDays`.

**Business Logic**:
- **Grid population**: the renewal list is a UNION of
  - (a) real rows in `mem.MembershipRenewals`, AND
  - (b) synthesized "upcoming" rows derived server-side from `mem.MemberEnrollments WHERE StatusId IN (Active) AND EndDate IS NOT NULL AND EndDate ≤ NOW + 90 days AND NOT EXISTS (MembershipRenewal for this cycle)`
  Synthesized rows carry `membershipRenewalId = 0` so FE can distinguish them. Server computes StatusId at query time for synthesized rows per the table below.
- **Synthesized row Status derivation** (computed at query time):
  - `Upcoming` — EndDate in [31, 90] days
  - `ExpiringSoon` — EndDate in [1, 30] days
  - `Overdue` — EndDate in past AND within `effectiveGrace` days
  - `AutoRenewFailed` — last MembershipRenewal for this enrollment has RetryCount > 0 and Status != Renewed (real row, not synthesized)
  - `Renewed` — real row with Status=Renewed, RenewalDate within last 60 days (for "Recently Renewed" tab)
- **Process Renewal** atomic transaction: insert MembershipRenewal → update `MemberEnrollment.EndDate = NewEndDate` → if tier upgrade, update `MemberEnrollment.MembershipTierId = newTierId` → if online payment mode, create PaymentTransaction link (SERVICE_PLACEHOLDER — no real gateway call in V1) → if `enableAutoRenew` differs from current, update `MemberEnrollment.AutoRenew`.
- **Retry Auto-Renewal**: finds the existing AutoRenewFailed row, increments RetryCount, re-invokes payment gateway (SERVICE_PLACEHOLDER) — caps at `MembershipRenewalConfig.RetryAttempts`. On success, flips StatusId → Renewed and bumps the enrollment EndDate.

**Workflow**: State machine on `StatusId`:

```
Upcoming → ExpiringSoon → Overdue → (AutoRenewFailed OR Renewed)
                                ↓
                            Renewed (manual via modal)
AutoRenewFailed → Renewed (via Retry or manual Renew)
```

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver

**Screen Type**: MASTER_GRID (grid + **modal form** — primary row action `Renew` opens a `<Modal>`, not a `?mode=new` page)
**Type Classification**: MASTER_GRID **with widgets-above-grid + settings-panel-below** (non-standard — follow AuctionItem #48 precedent)
**Reason**: The "+Add" is replaced by per-row "Renew" modals (not a new-page flow), the mockup has a heavy KPI strip and 5 filter tabs above the grid, and a collapsible per-company config card below. Same render topology as ContactType (grid + modal) but with richer chrome. No `?mode=new/edit/read` URL transitions — all writes happen via modals.

**Backend Patterns Required**:
- [x] Standard CRUD (11 files) — for MembershipRenewal (with extra command/query surface — see §⑧)
- [x] Upsert pattern (no Delete/Toggle) — for MembershipRenewalConfig
- [ ] Nested child creation — n/a
- [x] Multi-FK validation (`ValidateForeignKeyRecord` × 4) — MemberEnrollment, PreviousTier, NewTier (if upgrade), PaymentMode MasterData, Status MasterData
- [x] Unique validation — MembershipRenewalConfig.CompanyId (upsert guard)
- [ ] File upload command — n/a
- [x] Custom business rule validators — tier-amount match, date math for NewEndDate, grace-period precedence
- [x] Additional commands beyond CRUD:
  - `ProcessRenewal` — atomic (insert + bump + optional upgrade)
  - `RetryFailedAutoRenewal` — for rows with Status=AutoRenewFailed
  - `SendRenewalReminder` (single-row, SERVICE_PLACEHOLDER)
  - `SendBulkRenewalReminders` (header bulk, SERVICE_PLACEHOLDER)
  - `ProcessAllAutoRenewals` (header bulk, SERVICE_PLACEHOLDER)
  - `UpsertMembershipRenewalConfig`
  - `ExportMembershipRenewals` (CSV)
- [x] Additional queries beyond CRUD:
  - `getMembershipRenewals` (list — paged + filter-tab param + UNION of synthesized upcoming + real rows)
  - `getMembershipRenewalById`
  - `getMembershipRenewalSummary` (4 KPIs)
  - `getMembershipRenewalConfigByCompany` (singleton fetch for settings panel)

**Frontend Patterns Required**:
- [x] AdvancedDataTable (bespoke grid — query shape has a `filterTab` enum arg)
- [x] **NO RJSF** — use bespoke modal (per AuctionItem #48 precedent — renewal modal has a member-summary header card, upgrade-tier ApiSelectV2 with conditional price diff, and an auto-renew toggle)
- [x] Summary cards / count widgets — 4 KPI cards (Variant B — `widgets-above-grid`)
- [x] Grid aggregation columns — DaysLeft (computed server-side, color-coded client-side)
- [x] Filter tabs above grid — 5 tabs that drive a `filterTab` arg to `getMembershipRenewals`
- [x] Settings panel (collapsible) — bottom card with Retry/Grace inputs + Reminder Schedule table
- [x] Click-through navigation — member name → member list/detail route (#59)
- [x] Service placeholder buttons — Send Reminders, Process All Auto-Renewals, Retry, individual Remind
- [ ] Drag-to-reorder — n/a
- [ ] Side panel — n/a (settings panel is below grid, not side)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer

### Grid/List View

**Display Mode**: `table`

**Layout Variant**: `widgets-above-grid` → FE Dev uses **Variant B**: `<ScreenHeader>` + 4 KPI widgets + filter-tabs bar + `<DataTableContainer showHeader={false}>` + settings-panel card below.

**Page Header** (top strip):
- Title: "Membership Renewals" with refresh icon (`ph:arrows-clockwise`, color token `--accent-amber` / `#d97706` — membership module accent)
- Subtitle: "Track and manage upcoming, due, and overdue renewals"
- Header actions (right-aligned):
  1. `[Send Renewal Reminders]` (primary accent; `ph:paper-plane-tilt`) — bulk, SERVICE_PLACEHOLDER
  2. `[Process All Auto-Renewals]` (outline accent; `ph:arrows-clockwise`) — bulk, SERVICE_PLACEHOLDER
  3. `[Export]` (outline accent; `ph:download-simple`) — CSV export of current filter view

**Grid Columns** (in display order):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|--------------|-------|----------|-------|
| 1 | Member | memberName | link-cell | auto | YES | Click → `/{lang}/crm/membership/memberlist?id={memberEnrollmentId}` (#59) |
| 2 | Tier | currentTierName | tier-badge | 120px | YES | Emoji prefix per tier (🥉 Bronze / 🥈 Silver / 🥇 Gold / 💎 Platinum / ⭐ Lifetime) — seeded colorHex per #58 |
| 3 | Expires | previousEndDate | date (`MMM dd`) | 100px | YES | — |
| 4 | Days Left | daysLeft | days-left-cell | 100px | YES | Color-coded: normal / `text-amber-600` (< 7) / `text-red-600` (< 0). "—" when Status=Renewed. |
| 5 | Amount | renewalAmount | currency | 100px | YES | Bold |
| 6 | Auto-Renew | autoRenewAtTimeOfRenewal | auto-renew-badge | 120px | NO | "Auto" (green ✓) vs "Manual" (grey ☐) |
| 7 | Reminders Sent | remindersSentCount + lastReminderDate | reminder-info-cell | 160px | NO | "0" / "2 (Mar 15, Apr 1)" / red "Failed Apr 1" / green "Auto-processed" |
| 8 | Status | statusName | renewal-status-badge | 160px | YES | Badge color per RENEWALSTATUS MasterData value |
| 9 | Actions | — | action-buttons-cell | 200px | NO | Renew (primary) / Remind / Retry (only on AutoRenewFailed) / View (only on Renewed) / kebab |

**Filter Tabs** (above grid, drives `filterTab` query arg — C# enum):
1. `AllUpcoming` (default) — Status IN (Upcoming, ExpiringSoon, Overdue, AutoRenewFailed)
2. `DueThisMonth` — PreviousEndDate within current calendar month
3. `Overdue` — Status=Overdue
4. `AutoRenewFailures` — Status=AutoRenewFailed
5. `RecentlyRenewed` — Status=Renewed AND RenewalDate within last 60 days

**Search Fields**: `memberName` (Contact FirstName/LastName), `memberCode`, `currentTierName`

**Grid Actions** (per-row): Renew (opens modal), Remind (SERVICE_PLACEHOLDER toast), Retry (only on AutoRenewFailed — opens confirm dialog → calls RetryFailedAutoRenewal), kebab (View Member, Cancel Renewal, Mark Lapsed — SERVICE_PLACEHOLDER).

### Renewal Modal (bespoke — NOT RJSF)

**Trigger**: per-row `[Renew]` button.
**Modal size**: 520px width, max-height 90vh, scrollable body.

**Header** (sticky):
- Icon: `ph:arrows-clockwise` color `--accent-amber`
- Title: "Process Renewal"
- Close button (×)

**Body**:
1. **Member Summary Card** (readonly banner — grey background, rounded):
   - Avatar circle (initials from Contact.FirstName + Contact.LastName; gradient `--accent` → `--accent-light`)
   - Member name (bold)
   - `{MemberCode} • Current: {CurrentTierName} (${CurrentTierAnnualFee}/year)` subtitle

2. **Upgrade Tier?** (dropdown — ApiSelectV2)
   - Query: `getMembershipTiers` with `isActive=true`
   - First option: "Keep {CurrentTierName} — ${CurrentTierAnnualFee}/year" (selected by default — represents no upgrade; maps to `newTierId=null`)
   - Additional options: each MembershipTier where `AnnualFee > CurrentTierAnnualFee`, labeled `{TierName} — ${AnnualFee}/year (+${diff})`
   - onChange → updates the Amount displayed below
   - Client-side filter only — no BE filtering

3. **Amount + New Period** (2-col row, readonly):
   - Amount: `${renewalAmount}` (large text, color `--accent-amber`)
   - New Period: `{PreviousEndDate + 1 year}` range shown as `MMM dd, yyyy – MMM dd, yyyy`

4. **Payment Method** (dropdown — ApiSelectV2)
   - Query: `getMasterDatas({ masterDataTypeCode: "PAYMENTMODE" })`
   - Prepend synthetic first option "Previous card ••••{last4}" IF member has a saved card (`MemberEnrollment.CardSavedForAutoRenew=true` — pull from enrollment detail) — on select, this internally maps to the original PAYMENTMODE=CARD
   - Maps to PaymentModeId (MasterData row ID)
   - Online methods (CARD): SERVICE_PLACEHOLDER gateway call (see §⑫)
   - Offline methods (BANK / CASH / CHEQUE): handler marks paid immediately, no PaymentTransaction row

5. **Enable Auto-Renew** toggle (switch)
   - Writes to `MemberEnrollment.AutoRenew` on submit
   - Default: current value of `MemberEnrollment.AutoRenew`

**Footer**:
- `[Cancel]` (outline)
- `[Process Renewal]` (primary) — fires ProcessRenewal mutation → on success: close modal, refresh grid + summary, toast "Renewal processed · new period {date} – {date}"

### Page Widgets & Summary Cards

**Widgets** (4 KPI cards, 4-column grid, collapse to 2-col ≤992px, 1-col ≤576px):

| # | Widget Title | Value Source | Display Type | Position | Icon + Color |
|---|-------------|-------------|--------------|----------|--------------|
| 1 | Due This Month | `dueThisMonthCount` + `dueThisMonthAmount` | count + secondary $ label | Col 1 | `ph:calendar` / `--accent-teal` |
| 2 | Overdue | `overdueCount` + `overdueGraceAmount` | count + secondary $ label | Col 2 | `ph:warning-circle` / `--danger` |
| 3 | Auto-Renew Enabled | `autoRenewEnabledCount / activeMembersCount` + `autoRenewEnabledPercent` | ratio + % sub | Col 3 | `ph:arrows-clockwise` / `--success` |
| 4 | Renewal Rate (YTD) | `renewalRateYtdPercent` + `renewalRateYoYDelta` | % + trend arrow | Col 4 | `ph:chart-line-up` / `--accent-amber` |

**Summary GQL Query**:
- Query name: `getMembershipRenewalSummary`
- Returns: `MembershipRenewalSummaryDto` (see §⑩)

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Days Left | `(PreviousEndDate - NOW).Days` | derived in query handler | LINQ projection → populate `[NotMapped] DaysLeft` |

### Settings Panel (Collapsible — below grid)

> Bespoke `<Card>` — NOT a modal, NOT RJSF. Gets its own FE component `RenewalConfigPanel`.

**Header**: gear icon + "Auto-Renewal Settings" + chevron (rotates on expand, default expanded).

**Body — Top row** (3-col grid, collapse to 1-col on mobile):
- `Retry Failed Payments` — `<select>` with options `1 attempt / 2 attempts / 3 attempts (default) / 5 attempts`
- `Retry Interval` — `<select>` with options `1 day / 3 days (default) / 5 days / 7 days`
- `Grace Period` — `<select>` with options `0 days / 7 days / 14 days / 30 days (default) / 60 days`

**Body — Reminder Schedule** (sub-card with grey background, labeled "Reminder Schedule"):
Table of 5 fixed rows (timing label is read-only; checkboxes are editable):

| Timing (readonly label) | Channels (checkbox group) |
|-------------------------|---------------------------|
| 60 days before | ☐ Email ☐ SMS ☐ WhatsApp |
| 30 days before | ☐ Email ☐ SMS ☐ WhatsApp |
| 7 days before | ☐ Email ☐ SMS ☐ WhatsApp |
| On expiry | ☐ Email ☐ SMS ☐ WhatsApp |
| Grace period (15 days) | ☐ Final notice (single checkbox) |

**Footer**: `[Save Settings]` button (primary accent, right-aligned) — calls `upsertMembershipRenewalConfig` → toast on success.

**Data binding**: on mount, FE calls `getMembershipRenewalConfigByCompany` → prefills form. On save, fires `upsertMembershipRenewalConfig` with serialized `reminderScheduleJson`.

### User Interaction Flow

1. Page loads → `getMembershipRenewalSummary` + `getMembershipRenewals` fire in parallel → KPIs + grid populate; Config panel loads its own `getMembershipRenewalConfigByCompany`.
2. User clicks filter tab → grid refetches with new `filterTab` arg.
3. User clicks `[Renew]` on a row → modal opens with pre-filled member + amount.
4. User (optionally) selects upgrade tier → Amount recalculates to new tier's AnnualFee.
5. User picks payment method → toggles auto-renew → clicks Process Renewal.
6. Success → modal closes, grid + KPI refetch, toast "Renewal processed · new period {date} – {date}".
7. User clicks `[Retry]` on AutoRenewFailed row → confirm "Retry auto-renewal for {member}?" → fires `retryFailedAutoRenewal` → SERVICE_PLACEHOLDER toast.
8. User clicks `[Remind]` → SERVICE_PLACEHOLDER toast "Reminder sent (SMS/Email stub)".
9. User clicks member name cell → `router.push('/{lang}/crm/membership/memberlist?id=X')` to screen #59.
10. User edits Settings panel → clicks Save Settings → `upsertMembershipRenewalConfig` → toast.
11. Header `[Send Renewal Reminders]` → SERVICE_PLACEHOLDER confirm modal listing count-of-eligible → toast stub.
12. Header `[Process All Auto-Renewals]` → SERVICE_PLACEHOLDER confirm modal listing eligible count + total $ → toast stub.
13. Header `[Export]` → calls `exportMembershipRenewals` mutation (returns CSV download URL).

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Canonical reference: **AuctionItem** (MASTER_GRID with modals + KPIs + SERVICE_PLACEHOLDERs + filter-tab grid — closest precedent, completed 2026-04-21).

| Canonical (AuctionItem) | → This Entity | Context |
|-------------------------|--------------|---------|
| AuctionItem | MembershipRenewal | Entity/class name |
| auctionItem | membershipRenewal | Variable/field names |
| AuctionItemId | MembershipRenewalId | PK field |
| AuctionItems | MembershipRenewals | Table name, collection names |
| auction-item | membership-renewal | FE kebab name |
| auctionitem | membershiprenewal | FE folder, no-dash |
| AUCTIONITEM | MEMBERSHIPRENEWAL | Grid code, menu code |
| corg / ApplicationModels | mem / MemModels | DB schema / BE namespace suffix |
| Application | Mem | BE group name (business/schemas/configurations folder stems) |
| AUCTIONMANAGEMENT | MEMBERSHIPRENEWAL | Menu code |
| CRM_EVENT | CRM_MEMBERSHIP | Parent menu code |
| CRM | CRM | Module code (same) |
| crm/event/auctionmanagement | crm/membership/membershiprenewal | FE route base |
| application-service | mem-service | FE `domain/entities` service folder |
| application-queries / application-mutations | mem-queries / mem-mutations | FE GQL folder |
| AUCTIONITEMSTATUS | RENEWALSTATUS | MasterData type code |

**Note**: #58 and #59 are the real first `Mem*` builds — if their naming diverges from the AuctionItem template (it mostly doesn't), follow their precedent. Specifically: `IMemDbContext`, `MemDbContext`, `MemMappings`, `DecoratorMemModules` are already defined there.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> **Assumes `mem` schema infra already exists** (created by #58 MembershipTier). Do NOT re-create.

### Backend Files — MembershipRenewal (14 files)

| # | File | Path |
|---|------|------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MembershipRenewal.cs` |
| 2 | EF Config | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/MemConfigurations/MembershipRenewalConfiguration.cs` |
| 3 | Schemas (DTOs) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/MemSchemas/MembershipRenewalSchemas.cs` (includes `MembershipRenewalSummaryDto`) |
| 4 | Create Command | `Base.Application/Business/MemBusiness/MembershipRenewals/CreateCommand/CreateMembershipRenewal.cs` |
| 5 | Update Command | `.../MembershipRenewals/UpdateCommand/UpdateMembershipRenewal.cs` |
| 6 | Delete Command | `.../MembershipRenewals/DeleteCommand/DeleteMembershipRenewal.cs` |
| 7 | ProcessRenewal Command | `.../MembershipRenewals/Commands/ProcessRenewal.cs` (atomic — insert + bump enrollment + optional upgrade) |
| 8 | RetryFailedAutoRenewal Command | `.../MembershipRenewals/Commands/RetryFailedAutoRenewal.cs` |
| 9 | SendRenewalReminder Command | `.../MembershipRenewals/Commands/SendRenewalReminder.cs` (SERVICE_PLACEHOLDER) |
| 10 | SendBulkRenewalReminders Command | `.../MembershipRenewals/Commands/SendBulkRenewalReminders.cs` (SERVICE_PLACEHOLDER) |
| 11 | ProcessAllAutoRenewals Command | `.../MembershipRenewals/Commands/ProcessAllAutoRenewals.cs` (SERVICE_PLACEHOLDER) |
| 12 | ExportMembershipRenewals Command | `.../MembershipRenewals/Commands/ExportMembershipRenewals.cs` (CSV; reuses project's CSV writer per AuctionItem precedent) |
| 13 | GetAll Query | `.../MembershipRenewals/GetAllQuery/GetAllMembershipRenewals.cs` (paged + `filterTab` enum + UNION of real rows + synthesized) |
| 14 | GetById Query | `.../MembershipRenewals/GetByIdQuery/GetMembershipRenewalById.cs` |
| 15 | Summary Query | `.../MembershipRenewals/Queries/GetMembershipRenewalSummary.cs` |
| 16 | Mutations endpoint | `Base.API/EndPoints/Mem/Mutations/MembershipRenewalMutations.cs` |
| 17 | Queries endpoint | `Base.API/EndPoints/Mem/Queries/MembershipRenewalQueries.cs` |

### Backend Files — MembershipRenewalConfig (singleton — 5 files)

| # | File | Path |
|---|------|------|
| C1 | Entity | `Base.Domain/Models/MemModels/MembershipRenewalConfig.cs` |
| C2 | EF Config | `Base.Infrastructure/Data/Configurations/MemConfigurations/MembershipRenewalConfigConfiguration.cs` |
| C3 | Schemas | `Base.Application/Schemas/MemSchemas/MembershipRenewalConfigSchemas.cs` |
| C4 | Upsert Command | `Base.Application/Business/MemBusiness/MembershipRenewalConfigs/Commands/UpsertMembershipRenewalConfig.cs` |
| C5 | GetByCompany Query | `Base.Application/Business/MemBusiness/MembershipRenewalConfigs/Queries/GetMembershipRenewalConfigByCompany.cs` |

Config Mutations/Queries are **appended** to `MembershipRenewalMutations.cs` and `MembershipRenewalQueries.cs` (no separate endpoint file).

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IMemDbContext.cs` (created by #58) | `DbSet<MembershipRenewal>`, `DbSet<MembershipRenewalConfig>` properties |
| 2 | `MemDbContext.cs` (created by #58) | `DbSet<MembershipRenewal>`, `DbSet<MembershipRenewalConfig>` properties |
| 3 | `DecoratorProperties.cs` → `DecoratorMemModules` (created by #58) | Append `MembershipRenewal = "MembershipRenewal"`, `MembershipRenewalConfig = "MembershipRenewalConfig"` |
| 4 | `MemMappings.cs` (created by #58) | Append Mapster mapping config for MembershipRenewal → ResponseDto (include nav: MemberEnrollment.Contact, PreviousTier, NewTier, PaymentMode MasterData, Status MasterData) + MembershipRenewalConfig mapping |

No changes to IApplicationDbContext, MemDbContext inheritance, DependencyInjection, or GlobalUsing — those are handled by #58.

### Frontend Files (18 files — bespoke page despite screen_type=MASTER_GRID)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/mem-service/MembershipRenewalDto.ts` (+ `MembershipRenewalSummaryDto`, `MembershipRenewalConfigDto`, `ReminderScheduleRow` types) |
| 2 | GQL Queries | `PSS_2.0_Frontend/src/infrastructure/gql-queries/mem-queries/MembershipRenewalQuery.ts` (GetAll, GetById, GetSummary, GetConfig) |
| 3 | GQL Mutations | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/mem-mutations/MembershipRenewalMutation.ts` (Process, Retry, Remind, Bulk × 2, UpsertConfig, Export) |
| 4 | Zustand store | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/membershiprenewal-store.ts` |
| 5 | Zod schemas | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/renewal-schemas.ts` |
| 6 | Index page | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/index-page.tsx` (Variant B: ScreenHeader + KPIs + filter tabs + DataTableContainer + settings panel) |
| 7 | KPI widgets | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/renewal-widgets.tsx` |
| 8 | Filter tabs bar | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/renewal-filter-tabs.tsx` |
| 9 | Grid wrapper | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/renewal-grid.tsx` |
| 10 | Process Renewal modal | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/process-renewal-modal.tsx` |
| 11 | Retry confirm modal | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/retry-renewal-modal.tsx` |
| 12 | Settings panel | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/renewal-config-panel.tsx` |
| 13a | tier-badge renderer | `PSS_2.0_Frontend/src/presentation/components/ui/column-types/tier-badge-cell.tsx` |
| 13b | days-left renderer | `.../column-types/days-left-cell.tsx` |
| 13c | auto-renew-badge renderer | `.../column-types/auto-renew-badge-cell.tsx` |
| 13d | renewal-status-badge renderer | `.../column-types/renewal-status-badge.tsx` |
| 13e | reminder-info renderer | `.../column-types/reminder-info-cell.tsx` |
| 14 | Feature barrel | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiprenewal/index.ts` |
| 15 | Page config | `PSS_2.0_Frontend/src/presentation/pages/crm/membership/membershiprenewal.tsx` |
| 16 | Route page | `PSS_2.0_Frontend/src/app/[lang]/crm/membership/membershiprenewal/page.tsx` — **OVERWRITE** existing "Need to Develop" stub |
| 17 | membership/index.ts barrel | `PSS_2.0_Frontend/src/presentation/pages/crm/membership/index.ts` — append `MembershipRenewalPageConfig` export |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/domain/entities/mem-service/entity-operations.ts` (created by #58 or #59) | Append `MEMBERSHIPRENEWAL` operations block (list → `getMembershipRenewals`, create → `processRenewal`, summary → `getMembershipRenewalSummary`, config mutations) |
| 2 | `src/domain/entities/operations-config.ts` | Confirm `memEntityOperations` is registered (should already be done by #58/#59) |
| 3 | `src/domain/entities/mem-service/index.ts` barrel | Append export for MembershipRenewalDto + summary/config DTOs |
| 4 | Column-type registries (3 files — advanced / basic / flow) | Register `tier-badge`, `days-left`, `auto-renew-badge`, `renewal-status-badge`, `reminder-info` renderers (5 imports + 5 cases each) |
| 5 | `shared-cell-renderers.ts` barrel | Export all 5 new renderers |
| 6 | `gql-queries/index.ts` barrel | Export `MembershipRenewalQuery` |
| 7 | `gql-mutations/index.ts` barrel | Export `MembershipRenewalMutation` |
| 8 | Sidebar menu | No code change — driven by DB seed Menu→Caps→RoleCaps rows |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase

```
---CONFIG-START---
Scope: FULL

MenuName: Renewals
MenuCode: MEMBERSHIPRENEWAL
ParentMenu: CRM_MEMBERSHIP
Module: CRM
MenuUrl: crm/membership/membershiprenewal
GridType: MASTER_GRID
OrderBy: 4

MenuCapabilities: READ, CREATE, MODIFY, DELETE, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, EXPORT

GridFormSchema: SKIP
# Rationale: Renewal modal is bespoke (member-summary header card + conditional upgrade-tier pricing + toggle).
# Settings panel is bespoke (reminder schedule table). RJSF cannot render either. FE generates both directly.

GridCode: MEMBERSHIPRENEWAL

MasterDataTypes:
  - Code: RENEWALSTATUS
    Values:
      - Upcoming (color: #0e7490, icon: ph:hourglass-medium, label: "Upcoming")
      - ExpiringSoon (color: #92400e, icon: ph:warning-circle, label: "Expiring Soon")
      - Overdue (color: #991b1b, icon: ph:circle-wavy-warning, label: "Overdue (Grace)")
      - AutoRenewFailed (color: #dc2626, icon: ph:x-circle, label: "Auto-Renew Failed")
      - Renewed (color: #166534, icon: ph:check-circle, label: "Renewed")
  - Code: RENEWALREMINDERTIMING
    Values:
      - 60_DAYS_BEFORE (label: "60 days before")
      - 30_DAYS_BEFORE (label: "30 days before")
      - 7_DAYS_BEFORE (label: "7 days before")
      - ON_EXPIRY (label: "On expiry")
      - GRACE_15_DAYS (label: "Grace period (15 days)")

SeedConfigRow: YES
# Insert a default MembershipRenewalConfig row per company in the seed script:
# RetryAttempts=3, RetryIntervalDays=3, GracePeriodDays=30, default ReminderScheduleJson (see §② table 2)
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types**:
- Query type: `MembershipRenewalQueries` (renewal + config queries)
- Mutation type: `MembershipRenewalMutations` (renewal + config mutations)

**Queries** (follow #58/#59 naming convention: `getEntities` / `getEntityById` lowercase-plural):

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getMembershipRenewals` | `PaginatedApiResponse<MembershipRenewalResponseDto>` | `GridFeatureRequest` (searchText, pageNo, pageSize, sortField, sortDir) + `filterTab: MembershipRenewalFilterTab` (enum) + optional `membershipTierId?`, `isAutoRenewal?` |
| `getMembershipRenewalById` | `MembershipRenewalResponseDto` | `membershipRenewalId: int` |
| `getMembershipRenewalSummary` | `MembershipRenewalSummaryDto` | (none — company-scoped via HttpContext) |
| `getMembershipRenewalConfigByCompany` | `MembershipRenewalConfigResponseDto` | (none — company-scoped) |

**Mutations**:

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `processRenewal` | `ProcessRenewalRequestDto { memberEnrollmentId, newTierId?, paymentModeId, enableAutoRenew, notes? }` | `int` (new renewal ID) |
| `retryFailedAutoRenewal` | `membershipRenewalId: int` | `int` |
| `sendRenewalReminder` | `membershipRenewalId: int, channels: string[]` | `int` (SERVICE_PLACEHOLDER) |
| `sendBulkRenewalReminders` | `filterTab: MembershipRenewalFilterTab, channels: string[]` | `int` (count queued — SERVICE_PLACEHOLDER) |
| `processAllAutoRenewals` | (none) | `int` (count triggered — SERVICE_PLACEHOLDER) |
| `upsertMembershipRenewalConfig` | `MembershipRenewalConfigRequestDto { retryAttempts, retryIntervalDays, gracePeriodDays, reminderScheduleJson }` | `int` |
| `exportMembershipRenewals` | `filterTab: MembershipRenewalFilterTab` | `string` (CSV download URL) |

**Response DTO Fields — `MembershipRenewalResponseDto`**:

| Field | Type | Notes |
|-------|------|-------|
| membershipRenewalId | number | 0 for synthesized upcoming rows |
| memberEnrollmentId | number | FK |
| memberName | string | From Contact.FirstName + " " + Contact.LastName |
| memberCode | string | MemberEnrollment.MemberCode (e.g., `MEM-0023`) |
| previousTierId | number | FK |
| currentTierName | string | PreviousTier.TierName |
| currentTierAnnualFee | number | PreviousTier.AnnualFee (for modal display) |
| newTierId | number \| null | FK |
| newTierName | string \| null | NewTier.TierName |
| renewalAmount | number | decimal(18,2) |
| paymentModeId | number \| null | FK to MasterData (PAYMENTMODE) |
| paymentModeName | string \| null | MasterData.DataName |
| paymentTransactionId | number \| null | FK |
| previousEndDate | string (ISO) | — |
| newEndDate | string (ISO) \| null | — |
| renewalDate | string (ISO) \| null | — |
| daysLeft | number | computed server-side |
| statusId | number | FK to MasterData (RENEWALSTATUS) |
| statusName | string | MasterData.DataName (Upcoming / ExpiringSoon / Overdue / AutoRenewFailed / Renewed) |
| isAutoRenewal | boolean | — |
| autoRenewAtTimeOfRenewal | boolean | Mirror of MemberEnrollment.AutoRenew at row creation |
| remindersSentCount | number | — |
| lastReminderDate | string (ISO) \| null | — |
| lastReminderChannels | string \| null | CSV |
| failureReason | string \| null | — |
| retryCount | number | — |
| notes | string \| null | — |

**Response DTO Fields — `MembershipRenewalSummaryDto`**:

| Field | Type | Notes |
|-------|------|-------|
| dueThisMonthCount | number | KPI 1 primary |
| dueThisMonthAmount | number | KPI 1 secondary |
| overdueCount | number | KPI 2 primary |
| overdueGraceAmount | number | KPI 2 secondary |
| autoRenewEnabledCount | number | KPI 3 numerator |
| activeMembersCount | number | KPI 3 denominator |
| autoRenewEnabledPercent | number | KPI 3 sub |
| renewalRateYtdPercent | number | KPI 4 primary |
| renewalRateYoYDelta | number | KPI 4 sub (trend arrow) |

**Response DTO Fields — `MembershipRenewalConfigResponseDto`**:

| Field | Type | Notes |
|-------|------|-------|
| membershipRenewalConfigId | number | — |
| retryAttempts | number | 1-5 |
| retryIntervalDays | number | 1-7 |
| gracePeriodDays | number | 0-60 |
| reminderScheduleJson | string | JSON array — FE parses to `ReminderScheduleRow[]` |

---

## ⑪ Acceptance Criteria

**Build Verification**:
- [ ] `dotnet build` — no errors
- [ ] `pnpm build` / `pnpm dev` — page loads at `/{lang}/crm/membership/membershiprenewal`

**Functional Verification (Full E2E — MANDATORY)**:
- [ ] Page renders ScreenHeader (no double-header — Variant B verified)
- [ ] 4 KPI cards render with correct labels, icons, and values from `getMembershipRenewalSummary`
- [ ] 5 filter tabs render; clicking each re-issues `getMembershipRenewals` with correct `filterTab` enum arg
- [ ] Grid shows all 9 columns with correct renderers (tier-badge with emoji+colorHex, days-left color-coded, auto-renew-badge, reminder-info, renewal-status-badge)
- [ ] Search filters by memberName / memberCode / currentTierName
- [ ] `[Renew]` per-row opens ProcessRenewalModal with correct member summary (MemberCode + CurrentTierName + $AnnualFee)
- [ ] Upgrade tier dropdown populates from `getMembershipTiers` (client-side filtered to tiers with AnnualFee > current); selecting one updates Amount + New Period labels
- [ ] Payment method dropdown populates from `getMasterDatas({ masterDataTypeCode: "PAYMENTMODE" })`
- [ ] Auto-renew toggle initial state mirrors MemberEnrollment.AutoRenew
- [ ] `[Process Renewal]` submits → creates MembershipRenewal row, bumps MemberEnrollment.EndDate, optionally updates MembershipTierId + AutoRenew → modal closes + grid/KPI refresh + toast
- [ ] `[Retry]` (only visible on AutoRenewFailed rows) fires `retryFailedAutoRenewal` → toast (SERVICE_PLACEHOLDER)
- [ ] `[Remind]` fires `sendRenewalReminder` → toast (SERVICE_PLACEHOLDER)
- [ ] Member name link navigates to `/crm/membership/memberlist?id={memberEnrollmentId}`
- [ ] Settings panel loads `getMembershipRenewalConfigByCompany` on mount → prefills retry/interval/grace dropdowns and all 5 reminder rows
- [ ] Editing settings + clicking `[Save Settings]` fires `upsertMembershipRenewalConfig` → toast
- [ ] Header `[Send Renewal Reminders]` opens confirm → fires `sendBulkRenewalReminders` → toast (SERVICE_PLACEHOLDER)
- [ ] Header `[Process All Auto-Renewals]` opens confirm → fires `processAllAutoRenewals` → toast (SERVICE_PLACEHOLDER)
- [ ] Header `[Export]` downloads CSV of current filter view
- [ ] Permissions: BUSINESSADMIN sees all actions (project memory: BUSINESSADMIN-only RoleCap seed)

**DB Seed Verification**:
- [ ] Menu `MEMBERSHIPRENEWAL` appears in sidebar under CRM → Membership (OrderBy=4, after Tiers@3)
- [ ] Default MembershipRenewalConfig row seeded per company
- [ ] Master-data types `RENEWALSTATUS` (5 values) and `RENEWALREMINDERTIMING` (5 values) seeded
- [ ] MenuCapabilities + RoleCapabilities rows correct for BUSINESSADMIN

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — hard-blockers and gotchas

### Build-order gates (PROMPT_READY deps — must build to COMPLETED first)

1. **⚠⚠⚠ #58 MembershipTier must be COMPLETED before /build-screen #60.** Prompt exists (`prompts/membershiptier.md`) but entity is not yet generated. This screen relies on:
   - `Base.Domain/Models/MemModels/MembershipTier.cs` for PreviousTierId / NewTierId FKs
   - `mem` schema infra: `IMemDbContext`, `MemDbContext`, `MemMappings`, `DecoratorMemModules` (all created by #58)
   - `getMembershipTiers` GQL query for the upgrade-tier dropdown
   - Tier fields used: `TierName`, `AnnualFee`, `GracePeriodDays`, `SortOrder`, `PricingModelCode`

2. **⚠⚠⚠ #59 MemberEnrollment must be COMPLETED before /build-screen #60.** Prompt exists (`prompts/memberenrollment.md`) but entity is not yet generated. This screen relies on:
   - `Base.Domain/Models/MemModels/MemberEnrollment.cs` for MemberEnrollmentId FK
   - Enrollment fields used: `MemberCode`, `ContactId`, `MembershipTierId`, `StartDate`, `EndDate`, `AutoRenew`, `CardSavedForAutoRenew`, `CurrencyId`, `StatusId`
   - `getMemberEnrollments` GQL query (not directly called here but underpins the grid's UNION synthesized-row query)

   **Verify before /build-screen #60**: files at both paths above exist and the `mem` DbContext / mappings are registered. If `/build-screen #58` + `/build-screen #59` have already run to COMPLETED, this is satisfied automatically.

### Non-blocking notes

3. **Existing FE stub**: `PSS_2.0_Frontend/src/app/[lang]/crm/membership/membershiprenewal/page.tsx` contains `<div>Need to Develop</div>`. OVERWRITE with the new route page — do not create a sibling file.

4. **FE barrel** `PSS_2.0_Frontend/src/presentation/pages/crm/membership/index.ts` is empty apart from a marker comment — append `MembershipRenewalPageConfig` export (along with the entries #58 and #59 will add).

5. **Screen type nuance**: Classified as MASTER_GRID (modal-based row action), but `GridFormSchema: SKIP`. The renewal modal and settings panel are bespoke — RJSF cannot render the member-summary card, conditional upgrade-price deltas, or the reminder-schedule grid. Follow AuctionItem (#48) precedent: bespoke modals wired by the FE directly, NOT FlowDataTable / NOT RJSF.

6. **Grid query returns a UNION**: real rows from `mem.MembershipRenewals` UNION synthesized rows from `mem.MemberEnrollments WHERE EndDate IS RELEVANT`. Handler merges + computes `daysLeft` + derives `StatusId` for synthesized rows (StatusId resolves to the MasterData RENEWALSTATUS row at query time — do NOT persist synthesized rows). Sorting/filtering must work across both sets. `membershipRenewalId = 0` for synthesized rows so FE can tell them apart (affects which actions show).

7. **Process Renewal atomicity**: the ProcessRenewal command MUST run within a single transaction — failure at any step (payment txn creation, enrollment bump, tier upgrade) rolls back the MembershipRenewal insert. Precedent: AuctionBid.PlaceBid (#48) transactional handler.

8. **`filterTab` as C# enum**: expose `MembershipRenewalFilterTab` (AllUpcoming / DueThisMonth / Overdue / AutoRenewFailures / RecentlyRenewed) as a GraphQL enum rather than free-string. Reduces BE validation churn and gives FE type-safety.

9. **MembershipRenewalConfig upsert**: `CompanyId` is the logical unique key. Upsert query checks for existing row per CompanyId; creates if absent, updates if present. Must NOT create a duplicate row.

10. **DateTime semantics**: Keep all date math in UTC. `DaysLeft` computed server-side using `DateTime.UtcNow.Date` and `PreviousEndDate.Date` to avoid timezone drift.

11. **PaymentMode is MasterData, NOT `shr.PaymentModes`**: Per #59 precedent, `PaymentModeId` is an FK into `sett.MasterDatas` filtered by `TypeCode=PAYMENTMODE`. Do NOT use `Base.Domain/Models/SharedModels/PaymentMode.cs` — that's a different (unused) entity in this context.

12. **Grace-period precedence**: `MembershipTier.GracePeriodDays` overrides `MembershipRenewalConfig.GracePeriodDays` per tier. The Overdue-status derivation query must read both values and pick tier-level when present. Otherwise, an Elite/Lifetime tier with 90-day grace would be incorrectly marked Overdue at day 31.

13. **Tier upgrade filtering**: In the modal, the upgrade dropdown shows tiers where `AnnualFee > current.AnnualFee`. Client-side filter because `getMembershipTiers` already returns all active tiers with `benefits[]` inlined (per #58 prompt). No BE change needed.

14. **Saved-card synthetic dropdown option**: "Previous card ••••{last4}" appears ONLY if `MemberEnrollment.CardSavedForAutoRenew=true`. Inspect the enrollment payload (fetched via the grid row or a secondary `getMemberEnrollmentById` call) to decide whether to show this synthetic first option. Internally, selecting it maps to the MasterData row where `DataValue=CARD` — it does NOT create a new PaymentMode.

### Service Dependencies (UI fully built; handler mocked)

> Full UI implemented (buttons, dialogs, payloads). Only the external-service call at the backend boundary is mocked with a toast / Serilog line. Future external integration plugs in without FE changes.

- **⚠ SERVICE_PLACEHOLDER — `sendRenewalReminder` + `sendBulkRenewalReminders`**: Handler logs what would be sent and returns success. Full UI (per-row Remind button, header bulk action with channel-selection modal) is implemented. Missing layer: the multi-channel notification dispatcher (no such shared service exists in the codebase yet).
- **⚠ SERVICE_PLACEHOLDER — `processAllAutoRenewals`**: Handler iterates eligible rows and returns a count, but does not call a payment gateway or write PaymentTransaction rows. Full UI (header button, confirm modal with eligible-count + total-$ preview) is implemented. Missing layer: scheduled batch-payment job with gateway integration.
- **⚠ SERVICE_PLACEHOLDER — `retryFailedAutoRenewal`**: Handler increments RetryCount, flips StatusId back to Upcoming if RetryCount < config.RetryAttempts, returns success — but does not actually re-charge the gateway. Full UI implemented. Missing layer: gateway retry integration.
- **⚠ SERVICE_PLACEHOLDER — `processRenewal` with online payment methods** (PaymentMode.DataValue=`CARD`): Handler creates MembershipRenewal + bumps MemberEnrollment, but does NOT tokenize a card or call the payment gateway — `PaymentTransactionId` remains NULL for online methods in V1. Offline methods (BANK / CASH / CHEQUE) work end-to-end. Full UI renders. Missing layer: card tokenization + gateway charge (shared with existing Donation flow — if Donation module has a PaymentGatewayService, plumb through; otherwise stub).

No other items are placeholders — everything else in the mockup (KPIs, filter tabs, grid rendering, modals, settings panel, export) is in build scope.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | /plan-screens 2026-04-24 | HIGH (BUILD GATE) | BE | FK target `MembershipTier` (#58) is PROMPT_READY but not COMPLETED. `/build-screen #58` must run to COMPLETED before /build-screen #60 — that build creates `mem` schema infra (IMemDbContext, MemDbContext, MemMappings, DecoratorMemModules) + MembershipTier entity. | OPEN |
| ISSUE-2 | /plan-screens 2026-04-24 | HIGH (BUILD GATE) | BE | FK target `MemberEnrollment` (#59) is PROMPT_READY but not COMPLETED. `/build-screen #59` must run to COMPLETED before /build-screen #60 — required for MemberEnrollmentId FK, MemberCode / EndDate / AutoRenew / CardSavedForAutoRenew field access. | OPEN |
| ISSUE-3 | /plan-screens 2026-04-24 | LOW | SPEC | `NewEndDate` calculation defaults to `PreviousEndDate + 1 year`. If #58's `MembershipTier` ships with a `DurationMonths` field (not currently in the prompt), the handler should prefer tier-level duration. Document decision when #58 completes. | OPEN |
| ISSUE-4 | /plan-screens 2026-04-24 | LOW | SPEC | Saved-card detection assumes `MemberEnrollment.CardSavedForAutoRenew` is exposed in the row payload. If #59 does not include that field in its list DTO, an extra `getMemberEnrollmentById` call is needed when the modal opens. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-26 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Per session directive: skipped `dotnet build`, EF migration file creation, and verbose summary.
- **Files touched**:
  - BE: 22 created (2 entities, 2 EF configs, 2 schema files, 11 business handlers/commands/queries for MembershipRenewal, 5 for MembershipRenewalConfig appended to renewal endpoint files, 2 endpoint files in `Base.API/EndPoints/Mem/`) + 4 modified wiring (`IMemDbContext.cs`, `MemDbContext.cs`, `DecoratorProperties.cs` (DecoratorMemModules), `MemMappings.cs`)
  - FE: 14 created (DTO, GQL queries/mutations, store, schemas, 4 widgets/tabs/grid/index-page, process/retry modals, config panel, feature barrel, page config, 5 cell renderers in `shared-cell-renderers/`) + 9 modified wiring (route page.tsx overwrite, mem-service `entity-operations.ts`, mem-service `index.ts`, gql-queries `index.ts`, gql-mutations `index.ts`, 3 column-type registries (advanced/basic/flow), `pages/crm/membership/index.ts`)
  - DB: `MembershipRenewal-sqlscripts.sql` (created — Menu, MenuCapabilities, RoleCapabilities for BUSINESSADMIN, RENEWALSTATUS + RENEWALREMINDERTIMING MasterData, Grid, Fields, GridFields, default per-company MembershipRenewalConfig row)
- **Deviations from spec**: Cell renderers placed in `presentation/components/custom-components/data-tables/shared-cell-renderers/` (project's actual convention) instead of `presentation/components/ui/column-types/` mentioned in §⑧. GridComponentName values registered in all 3 column-type registries with the names: `tier-badge`, `days-left`, `auto-renew-badge`, `renewal-status-badge`, `reminder-info`. Backend Mutations/Queries for MembershipRenewalConfig appended into `MembershipRenewalMutations.cs` / `MembershipRenewalQueries.cs` per §⑧.
- **Known issues opened**: None new. ISSUE-1 / ISSUE-2 are now satisfied (#58 + #59 are COMPLETED). ISSUE-3 / ISSUE-4 remain advisory until tier-level DurationMonths or CardSavedForAutoRenew payload behavior is confirmed during functional testing.
- **Known issues closed**: ISSUE-1, ISSUE-2 (build-gate dependencies #58 + #59 are COMPLETED).
- **Next step**: None for build session. User to run EF migration locally (`dotnet ef migrations add AddMemModule_MembershipRenewals_Initial`) + `dotnet build` + run the seed SQL + functional E2E test of CRUD/modal/settings panel.