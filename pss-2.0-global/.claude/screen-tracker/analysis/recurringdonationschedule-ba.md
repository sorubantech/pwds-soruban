# Business Requirements Document: RecurringDonationSchedule (Screen #8)

> Generated: 2026-04-21 | Source: recurringdonationschedule.md (§①–⑫ + Known Issues)
> This document is the canonical input for Solution Resolver and all downstream agents.

---

## 1. Domain Context

- **Area**: Fundraising / CRM — Recurring Subscription Management
- **Primary Users**: BUSINESSADMIN (single role — no other roles have access)
- **Purpose**: Operational hub for managing recurring donation subscriptions — monitor billing health (MRR, active/paused/failed schedules) and execute state-machine transitions (Pause / Resume / Cancel / Retry)
- **Screen Type**: FLOW — Variant B mandatory (ScreenHeader + KPI widgets + DataTableContainer showHeader=false)
- **FE Folder**: `recurringdonors` (DO NOT rename — menu URL registered)
- **Route**: `/[lang]/crm/donation/recurringdonors`

---

## 2. Entity Analysis

### Primary Entity: RecurringDonationSchedule

- **Schema**: `fund`
- **Table**: `RecurringDonationSchedules`
- **Plural**: RecurringDonationSchedules
- **CamelCase**: recurringDonationSchedule
- **GridCode**: RECURRINGDONOR (existing — DO NOT change)

### Fields

| Field | C# Type | Required | MaxLen | Key | FK Target | Notes |
|-------|---------|----------|--------|-----|-----------|-------|
| RecurringDonationScheduleId | int | YES | — | PK | — | Primary key |
| RecurringDonationScheduleCode | string | YES | 50 | UNIQUE/Company | — | **NEW — migration required**; auto-gen `REC-{NNNN}` |
| CompanyId | int | YES | — | FK | app.Companies | Tenant scope; set from HttpContext, never from FE |
| PaymentMethodTokenId | int | YES | — | FK | fund.PaymentMethodTokens | Cascaded by Donor selection in form |
| PaymentGatewayId | int | YES | — | FK | shared.PaymentGateways | Stripe / PayPal / Razorpay |
| GatewaySubscriptionId | string | YES | 200 | UNIQUE/Company | — | Gateway-side subscription ID |
| GatewayCustomerId | string | YES | 200 | — | — | Gateway-side customer ID |
| GatewayPlanId | string | NO | 100 | — | — | Optional gateway plan ID |
| CurrencyId | int | YES | — | FK | app.Currencies | — |
| Amount | decimal(18,2) | YES | — | — | — | Per-charge amount; must be > 0 |
| FrequencyId | int | YES | — | FK | shared.MasterData (RECURRINGFREQUENCY) | Monthly/Quarterly/Semi-Annual/Annual |
| StartDate | DateTime | YES | — | — | — | Default: today in form |
| EndDate | DateTime? | NO | — | — | — | Null = ongoing; if set must be > StartDate |
| NextBillingDate | DateTime? | NO | — | — | — | NULL when Paused/Cancelled/Expired; computed on Active/Resume |
| LastChargedDate | DateTime? | NO | — | — | — | Last successful or failed charge date |
| LastChargeStatusId | int? | NO | — | FK | shared.MasterData (CHARGESTATUS) | Success / Failed |
| LastGatewayTransactionId | string | NO | 200 | — | — | — |
| LastFailureReason | string | NO | 1000 | — | — | Most recent gateway failure message |
| ConsecutiveFailures | int | YES | — | — | — | Default 0; ≥ 3 auto-transitions to Failed |
| TotalChargedCount | int | YES | — | — | — | Lifetime success charge count |
| TotalChargedAmount | decimal(18,2) | YES | — | — | — | Lifetime success charge sum |
| ScheduleStatusId | int | YES | — | FK | shared.MasterData (RECURRINGSCHEDULESTATUS) | Active/Paused/Cancelled/Failed/Expired |
| PausedReason | string | NO | 500 | — | — | Required when status = Paused |
| CancelledAt | DateTime? | NO | — | — | — | Set when status transitions to Cancelled |
| CancelledReason | string | NO | 500 | — | — | Required when status = Cancelled |
| DonorEmail | string | NO | 200 | — | — | Snapshot at sign-up (email format) |
| Note | string | NO | 1000 | — | — | Admin note |

**Audit columns** (inherited from Entity base — skip in all code): CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive, IsDeleted, PKReferenceId

### Child Entity: RecurringDonationScheduleDistribution

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| RecurringDonationScheduleDistributionId | int | YES | — | PK |
| RecurringDonationScheduleId | int | YES | — | Parent FK (cascade delete) |
| ContactId | int | YES | corg.Contacts | The donor for this distribution row |
| DonationPurposeId | int | YES | fund.DonationPurposes | — |
| ParticipantTypeId | int | YES | shared.MasterData (PARTICIPANTTYPE) | Self / Family / etc. |
| Amount | decimal(18,2) | YES | — | Must sum to parent Amount |

**Constraint**: At least 1 distribution row required. Sum of Distribution.Amount must equal parent Amount exactly.

### Projected Fields (BE projections — NOT new columns)

| Projected Field | Source | Notes |
|----------------|--------|-------|
| paymentMethodDisplay | PaymentMethodToken.CardBrand + Last4Digits + PAYMENTMETHODTYPE | "Visa ••••4242" / "PayPal Balance" / "UPI" |
| frequencySuffix | FrequencyId.dataValue → "/mo" / "/qtr" / "/yr" / "/semi" | Derived in BE projection |
| frequencyName | MasterData.dataName | "Monthly" / "Quarterly" / etc. |
| paymentGatewayName | PaymentGateway.paymentGatewayName | "Stripe" |
| paymentGatewayCode | PaymentGateway.code (lowercased) | "stripe" — for icon mapping |
| currencyCode | Currency.currencyCode | "USD" |
| scheduleStatusName | MasterData.dataName | "Active" / "Paused" / etc. |
| lastChargeStatusName | MasterData.dataName | "Success" / "Failed" |
| donorContactName | Distributions[0].Contact.DisplayName | First distribution's contact |
| donorContactCode | Distributions[0].Contact.ContactCode | For profile link |
| donorAvatarColor | Derived from ContactId hash | UI avatar color consistency |

### Relationships

- **Parent of**: RecurringDonationScheduleDistribution (1:many, cascade delete)
- **Child of**: Company (tenant scope), PaymentGateway, Currency, MasterData (Frequency, ScheduleStatus, LastChargeStatus)
- **Lookups**: Contact (via Distribution), DonationPurpose (via Distribution), MasterData (ParticipantType via Distribution), PaymentMethodToken
- **Related data**: PaymentTransactions (separate entity — linked by recurringScheduleId for charge history; read-only in drawer)

---

## 3. Business Rules

### Required Field Rules (BR-REQ)

- **BR-REQ-1**: Amount must be > 0
- **BR-REQ-2**: FrequencyId, CurrencyId, PaymentGatewayId, PaymentMethodTokenId, GatewaySubscriptionId, GatewayCustomerId, StartDate are mandatory on Create
- **BR-REQ-3**: At least 1 Distribution row is required
- **BR-REQ-4**: Each Distribution row requires ContactId, DonationPurposeId, ParticipantTypeId, and Amount > 0
- **BR-REQ-5**: RecurringDonationScheduleCode must be unique per Company (auto-generated `REC-{NNNN}` if blank on Submit; immutable after creation)

### Conditional Rules (BR-COND)

- **BR-COND-1**: EndDate, if set, must be strictly greater than StartDate
- **BR-COND-2**: If ScheduleStatus = Paused → PausedReason must be set; NextBillingDate must be NULL
- **BR-COND-3**: If ScheduleStatus = Cancelled → CancelledReason must be set; CancelledAt must be set; NextBillingDate must be NULL
- **BR-COND-4**: If ScheduleStatus = Failed → ConsecutiveFailures must be ≥ 3 (system-enforced; not user-settable directly)
- **BR-COND-5**: PaymentMethodTokenId dropdown is disabled on the form until at least one Distribution.ContactId is selected (cascade: token list filtered by first Contact's contactId)
- **BR-COND-6**: Status section (Section 4) is hidden in `?mode=new`; visible as read-only display in `?mode=edit`

### Distribution Validation Rules (BR-DIST)

- **BR-DIST-1**: Sum of all Distribution.Amount values must equal parent Amount exactly (validated on both FE inline and BE validator)
- **BR-DIST-2**: Distribution row removal with data entered requires inline confirm
- **BR-DIST-3**: Running sum mismatch indicator turns red immediately on blur; Save is blocked until resolved

### Uniqueness Rules (BR-UNIQ)

- **BR-UNIQ-1**: `RecurringDonationScheduleCode` unique per Company (filtered unique index)
- **BR-UNIQ-2**: `GatewaySubscriptionId` unique per Company (filtered unique index); note: uniqueness is per-Company, not cross-gateway — two Companies could theoretically share the same gateway sub ID

### Workflow Rules (BR-FLOW)

| From | To | Trigger | Side Effects | Constraints |
|------|----|---------|-------------|-------------|
| Active | Paused | User action (Pause) | NextBillingDate → NULL; PausedReason required | — |
| Active | Cancelled | User action (Cancel) | CancelledAt set; CancelledReason required; NextBillingDate → NULL | Irreversible |
| Active | Failed | System (ConsecutiveFailures ≥ 3) | No user action; auto-transition on charge failure webhook | Cannot be manually set to Failed by user |
| Paused | Active | User action (Resume) | NextBillingDate recomputed from today + Frequency; PausedReason cleared | — |
| Paused | Cancelled | User action (Cancel) | CancelledAt set; CancelledReason required; NextBillingDate → NULL | Irreversible |
| Failed | Active | Successful Retry | ConsecutiveFailures → 0; NextBillingDate recomputed | SERVICE_PLACEHOLDER |
| Failed | Paused | User action (Pause) | NextBillingDate → NULL; PausedReason required | — |
| Failed | Cancelled | User action (Cancel) | CancelledAt set; CancelledReason required | Irreversible |
| Cancelled | (none) | — | Terminal state — no transitions out | Resume button must NOT render for Cancelled |
| Expired | (none) | System (EndDate reached) | NextBillingDate → NULL | Terminal state — read-only |

### Code-Generation Rules (BR-CODE)

- **BR-CODE-1**: `RecurringDonationScheduleCode` auto-generated as `REC-{NNNN}` (4-digit zero-padded per-Company sequence) on Create when field is empty — matches GlobalDonation / DonationInKind code-gen pattern
- **BR-CODE-2**: Code is immutable after creation (read-only in edit form)

---

## 4. Use Cases

### UC-1: List Recurring Schedules with KPI Overview
- Display grid (12 columns) with KPI widgets above, Failed Alert Banner (if failedThisMonth > 0), filter chips, search, and advanced filter panel
- Grid fields: Schedule ID (code), Donor (avatar+name), Amount+freq, Frequency badge, Gateway, Payment Method, Status badge, Next Billing, Last Charged (date+icon), Total Charged (amount+count), Failures count, Actions
- Default view: all schedules, sorted by most recently created
- Paginated; supports sort by sortable columns (see §⑥)
- KPI widgets sourced from `getRecurringDonationScheduleSummary` (separate query — not from grid data)

### UC-2: Filter by Chip + Advanced Filters
- 6 filter chips: All (default), Active, Paused, Cancelled, Failed, Expiring Soon (EndDate within 30 days)
- Active chip synced to Zustand store + URL (`?chip=failed`)
- Advanced filter panel (collapsible): Frequency, Payment Gateway, Amount Min/Max, Currency, Created From/To, Next Billing From/To — 9 filters total
- Advanced filter state synced to URL params for deep-link / refresh support
- Text search across: donor name, donor email, schedule code
- Clear button resets all advanced filters; chip resets independently

### UC-3: Create Manual Schedule
- Full-page FORM (`?mode=new`) with 3 active sections: Schedule Info, Payment Setup, Distribution
- Admin-side manual entry (most schedules originate via gateway webhooks)
- On save: auto-generate RecurringDonationScheduleCode (`REC-{NNNN}`); navigate to `?mode=read&id={newId}`; drawer auto-opens with new record
- Distribution child grid: Add/Remove rows; running sum validator
- PaymentMethodToken dropdown disabled until first Distribution.ContactId selected
- Unsaved-changes dialog on navigation away from dirty form

### UC-4: Edit Existing Schedule
- Full-page FORM (`?mode=edit&id=X`) pre-filled with all existing data including distributions
- Status section (Section 4) visible as read-only display (ScheduleStatusId not directly editable; use workflow actions instead)
- On save: navigate to `?mode=read&id=X`; drawer reopens with updated data
- RecurringDonationScheduleCode rendered as read-only (immutable post-create)
- Distribution diff-persist on Update (add new rows + remove deleted rows in single transaction)

### UC-5: View Detail in Slide-In Drawer
- Row click → 460px right-side drawer slides in; grid stays visible underneath
- URL syncs to `?mode=read&id={id}` (back-button + deep-link support)
- Drawer close (X / Esc / overlay click) → URL clears → drawer slides out
- Drawer sections: Donor mini card (avatar, name-link SERVICE_PLACEHOLDER, email, engagement score), Schedule Info, Payment Method (from PaymentMethodToken nav), Distribution table, Charge History (last 6 from existing `RECURRING_DONOR_TRANSACTIONS_QUERY`), Audit Trail (collapsible)
- Drawer header: Schedule code + status badge; footer: workflow action buttons (conditional by status)

### UC-6: Pause Schedule
- Available when Status = Active or Failed
- Opens confirm modal with optional PausedReason text input
- Mutation: `pauseRecurringDonationSchedule(id, pausedReason)` → status → Paused; NextBillingDate → NULL
- Drawer refetches after mutation; grid row updates inline (no full reload)

### UC-7: Resume Schedule
- Available when Status = Paused only
- Direct mutation (no confirm modal needed): `resumeRecurringDonationSchedule(id)` → status → Active; NextBillingDate recomputed
- PausedReason cleared on resume

### UC-8: Cancel Schedule
- Available when Status ≠ Cancelled (Active, Paused, Failed)
- Opens confirm modal with **required** CancelledReason text input (cannot submit empty)
- Mutation: `cancelRecurringDonationSchedule(id, cancelledReason)` → status → Cancelled; CancelledAt set; NextBillingDate → NULL
- Cancel is irreversible — once Cancelled, no Resume/Retry buttons render
- Both drawer footer and Failed Alert Banner inline actions trigger same handler

### UC-9: Retry Failed Schedule (SERVICE_PLACEHOLDER)
- Available when Status = Failed only
- Opens confirm or fires directly; calls `retryRecurringDonationSchedule(id)` mutation
- Backend mock: ConsecutiveFailures → 0; status → Active; NextBillingDate recomputed; TotalChargedCount++; no real gateway API call
- Toast: "Retry sent — gateway integration pending."
- On success: drawer status updates to Active; Failed Alert Banner row removed

### UC-10: Update Payment Method (SERVICE_PLACEHOLDER)
- Available always (any status)
- Opens modal with PaymentMethodToken picker for the same Contact
- Mutation `updateRecurringDonationSchedulePayment(id, newPaymentMethodTokenId)` persists new token locally
- Toast: "Payment method updated locally — gateway sync pending."
- Real implementation: requires gateway-side subscription update API (Q4 work item)

### UC-11: Edit Amount
- Available always (any status)
- Opens inline modal with Amount number input
- Mutation `editRecurringDonationScheduleAmount(id, newAmount)` → persists; also recomputes NextBillingDate
- Drawer refetches after mutation
- NEEDS CLARIFICATION: Should EditAmount also require distribution amounts to be re-entered? (If parent Amount changes, existing Distribution.Amounts may no longer sum correctly.) Flag for UX: prompt user to re-validate distribution split after amount change.

### UC-12: Contact Donor for Failed Schedules (SERVICE_PLACEHOLDER)
- Available when Status = Failed (drawer footer + Failed Alert Banner inline)
- Navigates to `/crm/communication/emailcampaign?donorId={contactId}&template=recurring-failure-recovery`
- Deep-link handoff to email-campaign-builder; toast: "Email composer opening with donor pre-selected."
- Real implementation: depends on Email Campaign screen (#25 — Campaign deep-link not yet implemented)

### UC-13: Delete Schedule
- Soft delete via `deleteRecurringDonationSchedule(id)` — sets IsDeleted flag
- Pre-delete check: NEEDS CLARIFICATION — should Cancelled or Expired schedules be the only ones eligible for deletion? Active/Paused deletions would bypass state machine. Recommend: restrict delete to Cancelled/Expired only, or at minimum require confirmation with warning for Active/Paused.
- Access controlled by BUSINESSADMIN DELETE capability

### UC-14: Export
- Export button + dropdown: CSV / Excel / PDF
- Wires to existing GlobalExport pipeline if available; else toast: "Export queued."
- SERVICE_PLACEHOLDER — full export pipeline integration TBD (ISSUE-10)

---

## 5. Workflow State Machine

```
                     ┌─────────────────────────────┐
                     │           ACTIVE             │
                     │  NextBillingDate = computed   │
                     └──┬──────┬─────────────────┬──┘
                 Pause  │      │ Cancel            │ ConsecutiveFailures ≥ 3
                        ▼      ▼ (terminal)        ▼
              ┌────────────┐ ┌──────────┐  ┌──────────────┐
              │   PAUSED   │ │CANCELLED │  │    FAILED    │
              │ NBD=null   │ │ terminal │  │ NBD=null     │
              └──┬─────┬───┘ └──────────┘  └──┬───┬───┬──┘
          Resume │     │ Cancel                │   │   │ Cancel
                 ▼     ▼ (terminal)       Retry│   │   ▼ (terminal)
              ACTIVE  CANCELLED         (svc)  │   │  CANCELLED
                                         ▼    │   │
                                       ACTIVE │  Pause
                                              ▼
                                           PAUSED

EXPIRED (terminal): system-set when EndDate reached; no transitions out
```

**Key invariants**:
- Cancelled is always terminal — no path out regardless of triggering user or system
- Expired is always terminal — set by system when EndDate passed
- Failed is NOT terminal — can be retried (→ Active), paused (→ Paused), or cancelled (→ Cancelled)
- ConsecutiveFailures auto-transition to Failed is system-only; not user-triggerable

---

## 6. Edge Cases & Constraints

- **EC-1: Distribution sum mismatch** — If sum(Distribution.Amount) ≠ parent Amount, Save is blocked. FE shows red mismatch indicator inline. BE validator returns 422 with field error. Both layers must enforce independently.
- **EC-2: EndDate ≤ StartDate** — BE validator must reject. FE datepicker should disable past StartDate in EndDate picker.
- **EC-3: Cancelled is terminal** — Resume button must not render for Cancelled records. Cancel mutation must guard against re-cancelling (return 400 if already Cancelled).
- **EC-4: Expired is terminal** — System-set; no workflow buttons should render. Display as read-only.
- **EC-5: Paused requires PausedReason** — BE PauseCommand validator must reject empty PausedReason. FE modal must enforce non-empty before submit.
- **EC-6: Cancel requires CancelledReason** — BE CancelCommand validator must reject empty CancelledReason. FE confirm modal must block submit.
- **EC-7: ConsecutiveFailures ≥ 3 auto-flip** — This transition happens on webhook (not in this screen's scope); the screen must correctly display status=Failed when loaded. Status section in edit form shows it as read-only; no direct user path to set Failed.
- **EC-8: PaymentMethodToken cascade** — PaymentMethodTokenId dropdown must be disabled until at least one Distribution.ContactId is resolved. If user removes all distribution rows, token dropdown must re-disable and clear current selection.
- **EC-9: Multi-currency MRR aggregation** — `monthlyRecurringRevenue` in SummaryDto must be in Company default currency. Schedules in other currencies require FX conversion or simple summing in base currency. NEEDS CLARIFICATION: Does the BE sum raw amounts (inaccurate across currencies) or apply FX rates? If no FX service exists, note that MRR is "approximate (USD-equivalent)" in the KPI subtitle.
- **EC-10: Edit Amount vs Distribution split** — When parent Amount changes via EditAmount modal, existing distribution amounts may no longer sum to the new Amount. The mutation should either: (a) reject if distribution sum ≠ new Amount, or (b) navigate user to edit form to re-validate. NEEDS CLARIFICATION: document chosen behavior.
- **EC-11: Deleting active schedule** — No explicit delete guard documented. Recommend restricting hard-delete to Cancelled/Expired records only; Active/Paused/Failed should require Cancel first.
- **EC-12: Migration safety on RecurringDonationScheduleCode** — Existing rows in production have no Code. Migration must: (1) add nullable column, (2) backfill `REC-{NNNN}` per-Company with ROW_NUMBER(), (3) alter to NOT NULL, (4) add unique-filtered-index. Must be tested on production data copy before merge.
- **EC-13: Expiring Soon chip** — Computed server-side: EndDate IS NOT NULL AND EndDate <= TODAY + 30 days AND ScheduleStatus = Active. Ensure Paused/Cancelled records with EndDate in range are excluded.
- **EC-14: Resume NextBillingDate recomputation** — On Resume, NextBillingDate must be computed from today (not original StartDate), forward by one Frequency interval. If next computed date > EndDate, status should auto-transition to Expired rather than resuming.
- **EC-15: Drawer deep-link on page load** — If user navigates directly to `?mode=read&id=X`, the page must mount grid AND open drawer simultaneously (not wait for grid load first). Use parallel data fetching.
- **EC-16: Failed Alert Banner refetch after action** — After any inline action in the banner (Retry/Pause/Cancel), the banner must refetch `getRecurringDonationScheduleFailedAlert` independently (it is a separate query from the grid). Grid also refetches. Two separate query invalidations required.

---

## 7. Searchable Fields

- `recurringDonationScheduleCode` — human-readable schedule ID displayed in grid; users search by code
- `donorContactName` — projected from first Distribution.Contact.DisplayName; primary donor search
- `donorEmail` — snapshot field directly on entity; secondary donor search
- Advanced filter dimensions (not text search): FrequencyId, PaymentGatewayId, Amount range, CurrencyId, CreatedDate range, NextBillingDate range

---

## 8. UI Contract Summary

### URL Modes

| URL | Layout | Notes |
|-----|--------|-------|
| `/recurringdonors` | GRID (Variant B) | Default; KPI widgets + Failed Banner + filter chips + grid |
| `?mode=new` | FULL-PAGE FORM | 3 sections (Status section hidden) |
| `?mode=edit&id=X` | FULL-PAGE FORM | 4 sections (Status read-only) |
| `?mode=read&id=X` | GRID + 460px DRAWER | Grid stays mounted; drawer slides in from right |
| `?chip=failed` | GRID (filtered) | Chip state in URL; combinable with advanced filters |

### Drawer Footer Action Visibility Matrix

| Button | Active | Paused | Failed | Cancelled | Expired |
|--------|--------|--------|--------|-----------|---------|
| Pause Schedule | YES | NO | YES | NO | NO |
| Resume Schedule | NO | YES | NO | NO | NO |
| Cancel Schedule | YES | YES | YES | NO | NO |
| Retry Now | NO | NO | YES (svc) | NO | NO |
| Update Payment | YES | YES | YES (svc) | YES (svc) | NO |
| Edit Amount | YES | YES | YES | NO | NO |
| Contact Donor | NO | NO | YES (svc) | NO | NO |

### Backend API Summary

**Queries (all in RecurringDonationScheduleQueries.cs):**
- `recurringDonationSchedules` — paginated list + chip + advanced filters
- `recurringDonationScheduleById` — single record with all nav properties
- `recurringDonationScheduleSummary` — 4 KPI metrics (NEW)
- `recurringDonationScheduleFailedAlert` — top 5 failed (NEW)
- `paymentMethodTokensByContact(contactId)` — form cascade helper (NEW)
- `recurringDonorTransactions(recurringScheduleId)` — charge history (EXISTING — keep)

**Mutations (all in RecurringDonationScheduleMutations.cs):**
- `createRecurringDonationSchedule` — NEW
- `updateRecurringDonationSchedule` — NEW
- `deleteRecurringDonationSchedule` — NEW
- `activateDeactivateRecurringDonationSchedule` — EXISTING (keep for IsActive toggle)
- `pauseRecurringDonationSchedule` — NEW
- `resumeRecurringDonationSchedule` — NEW
- `cancelRecurringDonationSchedule` — NEW
- `retryRecurringDonationSchedule` — NEW (SERVICE_PLACEHOLDER)
- `updateRecurringDonationSchedulePayment` — NEW (SERVICE_PLACEHOLDER)
- `editRecurringDonationScheduleAmount` — NEW

---

## 9. Menu Configuration

- **Group**: DonationModels
- **Parent Menu**: CRM_DONATION
- **Module**: CRM
- **MenuCode**: RECURRINGDONOR (existing — DO NOT change)
- **GridCode**: RECURRINGDONOR (existing — DO NOT change)
- **MenuUrl**: crm/donation/recurringdonors (existing — DO NOT change)
- **GridType**: FLOW
- **OrderBy**: 2 (between GLOBALDONATION and CHEQUEDONATION)
- **GridFormSchema**: SKIP / NULL (FLOW screens drive form via view-page.tsx)

### MasterData Seed Gaps (CRITICAL — must be resolved before FE renders correctly)

| TypeCode | Missing Row | dataName | dataValue | Priority |
|----------|------------|----------|-----------|----------|
| RECURRINGSCHEDULESTATUS | Failed | "Failed" | FAIL | HIGH |
| RECURRINGFREQUENCY | Semi-Annual | "Semi-Annual" | 180 | MED |

---

## 10. Open Questions (Flag for UX/BE Resolution)

- **OQ-1** (from EC-10): When `editRecurringDonationScheduleAmount` changes parent Amount, what happens if existing distribution amounts no longer sum to the new amount? Options: (a) reject mutation — require user to edit form first; (b) accept mutation and flag distribution as inconsistent; (c) proportionally rebalance distribution amounts. Recommend option (a) — simplest and safest.
- **OQ-2** (from EC-9): Is `monthlyRecurringRevenue` in SummaryDto summed in raw amounts across currencies, or does the system apply FX conversion? If no FX service exists, MRR figure must display a disclaimer ("amounts shown in submission currency — may not reflect actual USD value").
- **OQ-3** (from UC-13 / EC-11): Should Delete be permitted for schedules in Active or Paused status? Recommend gating Delete to Cancelled/Expired status only and requiring users to Cancel first.
- **OQ-4** (from ISSUE-7): `RECURRING_DONOR_TRANSACTIONS_QUERY` field name `donorAmount` vs FE-rendered `amount` — verify on first BE/FE integration and align. (Existing issue — carry forward.)
- **OQ-5** (from EC-14): On Resume, if next computed NextBillingDate > EndDate, should the system auto-transition to Expired or allow Resume with an immediate expiry warning?
- **OQ-6** (from BR-FLOW): Can a BUSINESSADMIN manually set ScheduleStatus to Failed? Current rules say Failed is system-only (ConsecutiveFailures ≥ 3). Confirm this is not user-settable from the Status section in edit mode.

---

## 11. Carried-Forward Known Issues (All OPEN)

| ID | Severity | Area | Summary |
|----|----------|------|---------|
| ISSUE-1 | HIGH | BE-data-model | RecurringDonationScheduleCode column missing — migration + backfill required |
| ISSUE-2 | HIGH | BE-seed | RECURRINGSCHEDULESTATUS missing "Failed" MasterData row |
| ISSUE-3 | MED | BE-seed | RECURRINGFREQUENCY missing "Semi-Annual" MasterData row |
| ISSUE-4 | MED | FE-old-code | Existing recurring-donor-view.tsx is full-page (not drawer) — verify no sibling imports before deleting |
| ISSUE-5 | MED | BE-projection | paymentMethodDisplay LEFT JOIN query plan — monitor performance; consider snapshot column if pagination suffers |
| ISSUE-6 | LOW | BE-projection | donorContactName N+1 risk — use SubQuery+Select projection in GetAll |
| ISSUE-7 | LOW | FE-charge-history | RECURRING_DONOR_TRANSACTIONS_QUERY field `donorAmount` vs `amount` alignment — verify on first render |
| ISSUE-8 | HIGH | BE-service | RetryNow + UpdatePayment are SERVICE_PLACEHOLDERs — no real gateway integration in codebase |
| ISSUE-9 | LOW | FE-cascade | paymentMethodTokensByContact is a new GQL helper — first consumer; may be reused by screens #10, #12 |
| ISSUE-10 | LOW | FE-export | Export pipeline integration TBD — toast placeholder until GlobalExport confirmed available |
| ISSUE-11 | MED | BE-validator | Distribution sum validator needed in both BE (CreateValidator + UpdateValidator) and FE (RHF inline) |
| ISSUE-12 | LOW | BE-uniqueness | GatewaySubscriptionId uniqueness per-Company (not cross-gateway) — document limitation |
| ISSUE-13 | LOW | FE-store | URL params for ?mode=read&id=X must be source-of-truth (useSearchParams), not Zustand state — avoid hydration mismatch |
| ISSUE-14 | LOW | BE-existing | donation-service-entity-operations.ts line ~313 wires all mutations to ActivateDeactivate placeholder — replace on FE wire-up |

---

## 12. SERVICE_PLACEHOLDER Registry

| Placeholder | Action | Mock Behavior | Real Implementation Requires |
|------------|--------|--------------|------------------------------|
| Retry Now | `retryRecurringDonationSchedule` mutation | ConsecutiveFailures=0, status=Active, TotalChargedCount++ | PaymentGatewayService (Stripe/PayPal/Razorpay charges API) |
| Update Payment | `updateRecurringDonationSchedulePayment` mutation | Persist new PaymentMethodTokenId locally | Gateway-side subscription update API |
| Contact Donor | Navigate to email-campaign-builder | Toast + navigate with query params | Campaign #25 deep-link handler |
| Donor profile link | Contact name in drawer mini card | Link renders; navigates to Contact detail | Contact #18 screen (exists — verify route) |
| Engagement score badge | Contact.engagementScore | Show "N/A" if null | Family #20 engagement score projection (known null) |
| Export | CSV/Excel/PDF | Toast placeholder | GlobalExport pipeline integration |
