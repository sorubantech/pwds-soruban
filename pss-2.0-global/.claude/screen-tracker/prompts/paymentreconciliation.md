---
screen: PaymentReconciliation
registry_id: 14
module: Fundraising
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-20
completed_date: 2026-04-21
last_session_date: 2026-05-11
last_session_n: 16
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (KPIs + Reconciliation Table + Unmatched Panel + Settlement Summary)
- [x] Existing code reviewed (PaymentTransaction/PaymentSettlement/PaymentGateway entities + GlobalOnlineDonation link + FE stub)
- [x] Business rules + workflow extracted (match / dispute / settlement)
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (SKIPPED — prompt §①–⑫ pre-analyzed; precedent: Family #20, ChequeDonation #6)
- [x] Solution Resolution complete (SKIPPED — same precedent)
- [x] UX Design finalized (SKIPPED — prompt §⑥ exhaustive)
- [x] User Approval received (IMPLICIT — user invoked with full permissions grant)
- [x] Backend code generated (5 queries + 4 mutations, NO entity create — projection over existing)
- [x] Backend wiring complete (Mapster + EndPoint registration)
- [x] Frontend code generated (index-page Variant B + 3 section components + drawer + 2 modals + Zustand store)
- [x] Frontend wiring complete (operations-config + barrels + 3 column-type registries + page route stub)
- [x] DB Seed script generated (menu + caps + NEW MasterData TypeCodes + SettlementStatus/TransactionStatus/PaymentGateway rows + 10 sample PT + 4 sample PS)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/donation/reconciliation`
- [ ] 4 KPI widgets show totals matched against seeded data
- [ ] Reconciliation details table loads with Transaction ID / Gateway / Date / Amount / Currency / Donor / Donation Ref / Match Status / Settlement / Actions
- [ ] Match Status badges color-code correctly (Matched=green / Unmatched=amber / Disputed=red)
- [ ] Date-range selector re-queries with new range
- [ ] Unmatched Transactions panel collapses/expands and shows auto-match suggestions
- [ ] Match Manually modal opens → select GlobalDonation → Match → row disappears from unmatched + appears Matched in main table
- [ ] Create Donation from Unmatched opens pre-filled form → save → creates GlobalDonation + GlobalOnlineDonation link
- [ ] Respond to Dispute modal opens → submit → DisputeStatusId updates
- [ ] Run Reconciliation button triggers auto-match mutation → success toast → grid refresh
- [ ] Settlement Summary table loads with Gateway / Period / Gross / Fees / Net / Transactions / Status / Settlement Date
- [ ] `?mode=read&id={paymentTransactionId}` opens detail view with gateway, match, dispute, and settlement panels
- [ ] Donor link → navigates to `/[lang]/crm/contact/contact?mode=read&id={contactId}`
- [ ] Donation Ref link → navigates to `/[lang]/crm/donation/globaldonation?mode=read&id={globalDonationId}`
- [ ] Export Report button triggers SERVICE_PLACEHOLDER toast
- [ ] DB Seed — menu RECONCILIATION appears in sidebar under CRM_DONATION at OrderBy=7

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: PaymentReconciliation
Module: Fundraising (CRM)
Schema: fund
Group: DonationModels

Business: This is a **finance-operations workbench** that reconciles external payment-gateway transactions (Stripe / PayPal / Razorpay / etc.) with the NGO's recorded `GlobalDonation` records. When a donor pays online, two parallel data flows occur: (1) the gateway webhook lands a `PaymentTransaction` row with the gateway-side truth (charge ID, fee, settlement, dispute), and (2) the application records a `GlobalDonation` row with the organization-side context (purpose, donor, receipt). The screen shows both sides aligned — matched pairs, unmatched gateway transactions (webhook received but donation not found), and disputed charges (chargebacks requiring response). Used by **finance admins and the executive director** at month-end close and during daily webhook review. The screen is the final control gate before accounting export — every un-reconciled transaction represents a potential revenue leak or donor-service issue. Related screens: GlobalDonation (#1 — donation source of truth), Refund (#13 — drills refund transactions), ChequeDonation (#6 — offline equivalent), PaymentGateway settings (SET_PAYMENTCONFIG). Read-mode drill-in shows the full webhook payload + dispute timeline + settlement batch for audit purposes.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **IMPORTANT**: NO new entity is created for this screen. The screen is a **projection** over three existing entities:
> 1. `PaymentTransaction` (fund.PaymentTransactions) — gateway-side transaction
> 2. `PaymentSettlement` (fund.PaymentSettlements) — settlement batches by gateway+date
> 3. `GlobalOnlineDonation` (fund.GlobalOnlineDonations) — LINK TABLE between `GlobalDonation` and gateway (contains `GatewayTransactionId`)
>
> Matching rule: a `PaymentTransaction` is "Matched" iff a `GlobalOnlineDonation` row exists with the **same CompanyId + PaymentGatewayId + GatewayTransactionId**.

### Existing tables (NO changes required to entity columns)

**fund."PaymentTransactions"** — gateway transaction (already populated by webhook):

| Field | C# Type | Notes |
|-------|---------|-------|
| PaymentTransactionId | int | PK |
| CompanyId | int | Tenant |
| ContactId | int? | Donor (nullable — may be anonymous) |
| IdempotencyKey | string | — |
| TransactionTypeId | int | FK MasterData TRANSACTIONTYPE (OneTime/Recurring/Refund) |
| GatewayTransactionId | string? | Stripe `pi_…`, PayPal `ORDER-…`, Razorpay `pay_…` — THE MATCH KEY |
| GatewayOrderId | string? | — |
| PaymentGatewayId | int | FK SharedModels.PaymentGateway |
| PaymentMethodTypeId | int? | FK MasterData PAYMENTMETHODTYPE |
| DonorCurrencyId | int | FK Currency |
| DonorAmount | decimal(18,2) | — |
| SettlementCurrencyId | int? | — |
| SettlementAmount | decimal? | — |
| ExchangeRate | decimal? | — |
| GatewayFee | decimal? | — |
| ProcessingFee | decimal? | — |
| NetAmount | decimal? | — |
| RefundedAmount | decimal? | — |
| TransactionStatusId | int | FK MasterData TRANSACTIONSTATUS (Initiated/Captured/PartialRefund/Settled/Disputed) |
| DisputeStatusId | int? | FK MasterData DISPUTESTATUS — when NOT NULL, transaction is "Disputed" |
| DisputeReason | string? | — |
| DisputeOpenedAt | DateTime? | — |
| DisputeResolvedAt | DateTime? | — |
| SettledAt | DateTime? | — |
| ReceiptNumber | string? | — |
| IPAddress, UserAgent, DonorCountryCode | string? | fraud/debug only |

**fund."PaymentSettlements"** — daily settlement batches (NO changes):

| Field | C# Type | Notes |
|-------|---------|-------|
| PaymentSettlementId | int | PK |
| CompanyId | int | — |
| PaymentGatewayId | int | FK |
| GatewaySettlementId | string | Stripe `po_…`, etc. |
| SettlementDate | DateTime | — |
| CurrencyId | int | FK |
| GrossAmount, TotalFees, NetAmount | decimal | — |
| TransactionCount | int | — |
| SettlementStatusId | int | FK MasterData SETTLEMENTSTATUS |
| BankReference | string? | — |

**fund."GlobalOnlineDonations"** — EXISTING LINK (used for match detection — NO changes):

| Field | C# Type | Notes |
|-------|---------|-------|
| GlobalOnlineDonationId | int | PK |
| GlobalDonationId | int | FK to GlobalDonation |
| PaymentGatewayId | int | — |
| GatewayTransactionId | string | JOIN KEY for match detection |

### NEW DTOs (projections only — no table)

| DTO | Purpose |
|-----|---------|
| `ReconciliationTransactionDto` | Flat projection of PaymentTransaction + matchStatus + linked GlobalDonation info for main grid |
| `UnmatchedTransactionDto` | Subset of ReconciliationTransactionDto with `autoMatchSuggestion` appended |
| `SettlementSummaryDto` | Flat projection of PaymentSettlement with gateway brand/color hints |
| `ReconciliationSummaryDto` | 4 KPI counts + amounts (Total / Matched / Unmatched / Disputed) |
| `AutoMatchSuggestionDto` | Candidate GlobalDonation for a given PaymentTransaction (score + reason) |

### Child Entities (for detail drill-in only — no FE write)
| Child | Relationship | Key Fields |
|-------|-------------|------------|
| GlobalOnlineDonation | 1:0-1 via GatewayTransactionId match | GlobalDonationId, Fees |
| PaymentSettlement | N:1 via PaymentGatewayId + SettledAt→SettlementDate window | SettlementDate, NetAmount |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and joins) + Frontend Developer (for ApiSelect & link navigation)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| PaymentGatewayId | PaymentGateway | `Base.Domain/Models/SharedModels/PaymentGateway.cs` | `paymentGateways` (PAYMENTGATEWAYS_QUERY) | PaymentGatewayName | PaymentGatewayResponseDto |
| ContactId | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `contacts` (CONTACTS_QUERY) | ContactName (computed `${firstName} ${lastName}`) | ContactResponseDto |
| DonorCurrencyId / SettlementCurrencyId / CurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `currencies` (CURRENCIES_QUERY) | CurrencyCode | CurrencyResponseDto |
| GlobalDonationId | GlobalDonation | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | `globalDonations` (GLOBAL_DONATIONS_QUERY) | ReceiptNumber | GlobalDonationResponseDto |
| TransactionStatusId / DisputeStatusId / SettlementStatusId / PaymentMethodTypeId / FailureCategoryId / TransactionTypeId | MasterData | `Base.Domain/Models/SettingsModels/MasterData.cs` | `masterDatas` (MASTERDATAS_QUERY) filtered by TypeCode | DataName | MasterDataResponseDto |

**Match-detection JOIN (non-FK, critical for reconciliation logic):**
```sql
LEFT JOIN fund."GlobalOnlineDonations" god
  ON god."CompanyId"          = pt."CompanyId"
 AND god."PaymentGatewayId"   = pt."PaymentGatewayId"
 AND god."GatewayTransactionId" = pt."GatewayTransactionId"
LEFT JOIN fund."GlobalDonations" gd
  ON gd."GlobalDonationId" = god."GlobalDonationId"
```

**Settlement-batch JOIN (non-FK, for main grid's Settlement column):**
```sql
LEFT JOIN fund."PaymentSettlements" ps
  ON ps."CompanyId"        = pt."CompanyId"
 AND ps."PaymentGatewayId" = pt."PaymentGatewayId"
 AND ps."SettlementDate"   = DATE(pt."SettledAt")
```

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation + error toasts)

### Match-Status Derivation (computed in BE projection — NOT a persisted column)
- **Disputed** — IF `PaymentTransaction.DisputeStatusId IS NOT NULL` AND the related MasterData.DataValue ≠ `NONE` → `matchStatusCode = DISPUTED`. Highest precedence (overrides Matched/Unmatched).
- **Matched** — IF a `GlobalOnlineDonation` row exists for (CompanyId, PaymentGatewayId, GatewayTransactionId) → `matchStatusCode = MATCHED`.
- **Unmatched** — otherwise → `matchStatusCode = UNMATCHED`.

### Settlement-Status Derivation (for main grid's Settlement column)
- Lookup `PaymentSettlement` by (CompanyId, PaymentGatewayId, DATE(pt.SettledAt)). If found → return `PaymentSettlement.SettlementStatus.DataName` + `DataValue`. If `pt.SettledAt IS NULL` → return `Pending` (blue). If `pt.DisputeStatusId IS NOT NULL AND pt.DisputeResolvedAt IS NULL` → return `Open` (red).

### Uniqueness Rules
- `PaymentTransaction.IdempotencyKey` unique per company (already enforced).
- `GlobalOnlineDonation.(CompanyId, PaymentGatewayId, GatewayTransactionId)` MUST be unique — one gateway transaction can match AT MOST ONE donation (enforce at Match mutation time).

### Tenant Scoping
- ALL queries MUST filter by `CompanyId = HttpContext.User.CompanyId`. This is a finance screen — cross-tenant leak is a hard blocker.

### Action Business Rules
- **Match** (link PaymentTransaction → GlobalDonation):
  - PT must NOT already have a GlobalOnlineDonation row.
  - Target GlobalDonation must NOT already be linked to another PT.
  - PT.DonorAmount must match GlobalDonation.DonationAmount (±0.01 tolerance); if mismatch, require explicit override flag `allowAmountMismatch=true`.
  - PT.CompanyId must equal GlobalDonation.CompanyId (enforced by tenant scope).
  - Creates a new `GlobalOnlineDonation` row with:
    `GlobalDonationId = target.GlobalDonationId`, `PaymentGatewayId = pt.PaymentGatewayId`, `GatewayTransactionId = pt.GatewayTransactionId`, `GatewayFee = pt.GatewayFee`, `PlatformFee = 0`, `TotalFee = pt.GatewayFee + pt.ProcessingFee`.
- **Unmatch**:
  - Soft delete the GlobalOnlineDonation row (set IsDeleted=true). Preserves audit trail.
  - Only allowed if the linked GlobalDonation has no issued Receipt (if Receipt exists, require explicit `--force` + audit note).
- **Respond to Dispute**:
  - Only enabled if `DisputeStatusId.DataValue IN ('OPEN', 'UNDERREVIEW')`.
  - Inputs: decision (`WON` | `LOST` | `ACCEPTED`), response text, optional evidence attachment (SERVICE_PLACEHOLDER for file upload).
  - Sets `DisputeStatusId` = new status, `DisputeResolvedAt = now()`, appends `DisputeReason` (existing reason + "\n---\nResponse: " + new text).
- **Create Donation from Unmatched**:
  - Opens a pre-filled GlobalDonation create form with `DonationAmount = pt.DonorAmount`, `CurrencyId = pt.DonorCurrencyId`, `DonationDate = pt.CreatedDate`, `ContactId = pt.ContactId` (if present), `DonationModeId = ONLINE` (resolve at runtime), `PaymentStatusId = SUCCESS`.
  - On save, creates `GlobalDonation` + `GlobalOnlineDonation` link atomically in a single transaction. Auto-redirects to the new donation's detail view.
  - The source PaymentTransaction's `GatewayTransactionId` is written into the new GlobalOnlineDonation so the match becomes immediate.
- **Run Auto-Reconciliation** (bulk match):
  - Candidate pairs: PT.DonorAmount == GD.DonationAmount ± 0.01 AND DATE(PT.CreatedDate) within GD.DonationDate ± 1 day AND PT.ContactId == GD.ContactId (where both non-null).
  - Confidence score: Amount-exact + Date-exact + Contact-exact = 100. Scale down for fuzz.
  - Only auto-links pairs with score ≥ 90 (conservative). Returns a report `{autoMatched: N, candidates: [...], unresolved: N}`.
  - Log each auto-match in `GlobalOnlineDonation` with `CreatedBy = SystemUser` for audit.

### Validation
- Date-range selector: max 1 year span (prevent runaway queries).
- Auto-match suggestion query: limit to 5 candidates per transaction.

### Workflow (dispute transitions only — no create/delete of PT)
- DISPUTESTATUS transitions: `NONE → OPEN → UNDERREVIEW → (WON | LOST | ACCEPTED)`. `WON` / `LOST` / `ACCEPTED` are terminal.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered decisions.

**Screen Type**: FLOW
**Type Classification**: Custom read-mostly FLOW workbench (sibling of **DuplicateDetection #21** — modals instead of new/edit view-pages). NOT a canonical new/edit/read FLOW because gateway transactions are webhook-created, never user-created.

**Reason**: The mockup has NO "+Add" button. There is no user flow to "create a new payment transaction" — that's the gateway's job. Instead, the screen provides **action modals** (Match, Create Donation from Unmatched, Respond to Dispute) + an optional **read-detail page** (`?mode=read&id=X`) for a single transaction's deep audit view. Closest sibling: DuplicateDetection #21 (Zustand-triggered modals, no classic new/edit).

**Backend Patterns Required:**
- [ ] Standard CRUD (11 files) — **NO**, we do NOT create/update/delete PaymentTransaction via UI.
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] 5 new read queries (Reconciliation list / Unmatched / Settlement summary / Widget summary / AutoMatch suggestion)
- [x] 5 new action mutations (Match, Unmatch, RespondToDispute, CreateDonationFromTransaction, RunAutoReconciliation)
- [x] Multi-FK validation (ValidateForeignKeyRecord for Match target donation)
- [x] Cross-entity transactional writes (Match and CreateDonationFromTransaction both insert GlobalOnlineDonation — wrap in explicit SaveChanges scope)
- [ ] Workflow commands (Submit/Approve/Reject) — **NO** (only Dispute response is workflow-like)
- [ ] File upload command — DEFERRED (SERVICE_PLACEHOLDER for dispute-evidence)

**Frontend Patterns Required:**
- [x] Custom dashboard-style index page (NOT `FlowDataTable` for main grid — use plain `<Table>` + 3 sections, see ⑥)
- [x] view-page.tsx with **only** `?mode=read` (no new, no edit — transactions are not user-created)
- [x] Zustand store (`reconciliation-store.ts`) — holds date-range, active modal id + target row, filter state
- [x] Modal overlays (Match / Create Donation / Respond to Dispute) — Zustand-triggered, NOT URL-driven
- [x] Collapsible panel (Unmatched Transactions)
- [x] Summary cards / KPI widgets above grid (4 widgets)
- [x] Variant B layout (ScreenHeader + widgets + 3 stacked section-cards)
- [x] Grid aggregation columns — NO (per-row values come from BE projection, not subquery)
- [x] Service placeholder buttons — Export Report + Dispute Evidence Upload

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup `html_mockup_screens/screens/fundraising/payment-reconciliation.html`.

### Layout Variant

**Grid Layout Variant**: `widgets-above-grid`
→ FE Dev uses **Variant B**: `<ScreenHeader>` + 4 widget cards + 3 stacked section-cards.
MANDATORY — omitting this stamp reproduces the ContactType #19 double-header bug.

---

### Page Structure (top to bottom, per mockup)

```
┌──────────────────────────────────────────────────────────────────┐
│  Breadcrumb: Fundraising › Payment Reconciliation                │
├──────────────────────────────────────────────────────────────────┤
│  <ScreenHeader>                                                  │
│    Title:    Payment Reconciliation                              │
│    Subtitle: Match gateway transactions with recorded donations  │
│    Actions:  [Date Range Select ▾] [Run Reconciliation] [Export] │
├──────────────────────────────────────────────────────────────────┤
│  4-KPI Widget Grid  (auto-fit minmax(210px, 1fr))                │
│    • Total Transactions (blue)  • Matched (green, pct)           │
│    • Unmatched (orange, pct)    • Disputes (red, pct)            │
├──────────────────────────────────────────────────────────────────┤
│  Section Card: "Reconciliation Details"                          │
│    (plain <table> — 10 columns, NOT FlowDataTable — see below)   │
├──────────────────────────────────────────────────────────────────┤
│  Section Card: "Unmatched Transactions (N)"  [collapsible]       │
│    (stacked rows with inline auto-match suggestion + 2 buttons)  │
├──────────────────────────────────────────────────────────────────┤
│  Section Card: "Settlement Summary"                              │
│    (plain <table> — 8 columns, read-only aggregates)             │
└──────────────────────────────────────────────────────────────────┘
```

Note on "plain `<table>` vs `<FlowDataTable>`": the mockup shows dense tables styled inline with no per-column sort headers, no pagination controls, no advanced filter panel — they are **read-only result tables** refreshed by the top-level date-range selector. Use `<SimpleDataTable>` (or raw `<table>` using Tailwind tokens) rather than `<FlowDataTable>`. This matches the mockup semantics and avoids overloading the user with filter chrome. Pagination happens at the BE query (`GetReconciliationList` returns `PaginatedApiResponse` — FE can add "Load more" if row count exceeds page size).

---

### 4 KPI Widgets

| # | Title | Icon | Color | Value Source | Sub-line |
|---|-------|------|-------|-------------|----------|
| 1 | Total Transactions | `ph:arrows-left-right` | blue-50 / blue-500 | `reconciliationSummary.totalCount` | `reconciliationSummary.totalAmount` currency |
| 2 | Matched | `ph:check-circle` | green-50 / green-500 | `reconciliationSummary.matchedCount` + pct | `reconciliationSummary.matchedAmount` |
| 3 | Unmatched | `ph:question` | orange-50 / orange-500 | `reconciliationSummary.unmatchedCount` + pct | `reconciliationSummary.unmatchedAmount` |
| 4 | Disputes | `ph:gavel` | red-50 / red-500 | `reconciliationSummary.disputedCount` + pct | `reconciliationSummary.disputedAmount` |

Widget source: `GetReconciliationSummary(dateFrom, dateTo)` — returns ONE `ReconciliationSummaryDto`.

**Do NOT use fa-* icons** — replace all `fa-arrows-rotate`, `fa-file-export`, `fa-arrows-left-right`, `fa-check-double`, `fa-question`, `fa-gavel`, `fa-check-circle`, `fa-question-circle`, `fa-exclamation-triangle`, `fa-chevron-down`, `fa-table`, `fa-landmark`, `fa-clock`, `fa-circle-exclamation`, `fa-lightbulb`, `fa-stripe-s`, `fa-paypal`, `fa-bolt`, `fa-check` with Phosphor equivalents per UI uniformity memory.

---

### Section 1: "Reconciliation Details" Table (10 columns)

| # | Column Header | Field Key | Display Type | Width | Notes |
|---|--------------|-----------|-------------|-------|-------|
| 1 | Transaction ID | `gatewayTransactionId` | monospace pill (`.txn-code`) | 150 | Tooltip = full ID if truncated |
| 2 | Gateway | `paymentGatewayName` + `paymentGatewayCode` | gateway-brand-badge renderer (Stripe violet, PayPal navy, Razorpay dark-blue + brand icon) | 140 | — |
| 3 | Date | `createdDate` | MMM DD (e.g., "Apr 10") | 90 | `DateOnlyPreview` renderer |
| 4 | Amount | `donorAmount` + `donorCurrencyCode` | bold + right-align with currency symbol | 120 | `currency-amount-cell` renderer (handles USD/INR/EUR symbols) |
| 5 | Currency | `donorCurrencyCode` | 3-letter uppercase | 80 | Plain text |
| 6 | Donor | `contactId` + `contactName` | donor-link renderer (clickable → `/[lang]/crm/contact/contact?mode=read&id={contactId}`); shows `—` if null | auto | When null (anonymous), grey dash |
| 7 | Donation Ref | `globalDonationId` + `receiptNumber` | ref-link renderer (clickable → `/[lang]/crm/donation/globaldonation?mode=read&id={globalDonationId}`); shows `—` if unmatched | 140 | ReceiptNumber format: `RCP-YYYY-####` |
| 8 | Match Status | `matchStatusCode` | match-status-badge renderer (Matched=green-50/16a34a, Unmatched=orange-50/d97706, Disputed=red-50/dc2626 — with icon check/question/triangle) | 120 | ROW BG TINT: Unmatched row → bg-amber-50; Disputed row → bg-red-50 |
| 9 | Settlement | `settlementStatusCode` | settlement-status-badge renderer (Settled=green-50/16a34a, Pending=blue-50/3b82f6, Open=red-50/dc2626) | 110 | — |
| 10 | Actions | — | action-button-group | 160 | See below |

**Action Button Variations** (context-dependent per row):

| Match Status | Buttons Rendered |
|--------------|------------------|
| Matched | [View] → opens `?mode=read&id={paymentTransactionId}` |
| Unmatched | [Match] (amber outline, opens Match modal) · [Investigate] → opens `?mode=read&id={pt.Id}` |
| Disputed | [Respond] (red outline, opens Respond modal) · [View] → opens read |

**Empty state**: "No transactions match the selected date range" with `ph:funnel` icon.

**Row click behavior**: anywhere outside the Actions column → navigate to `?mode=read&id={paymentTransactionId}`.

---

### Section 2: "Unmatched Transactions (N)" — Collapsible Panel

Header: `ph:question-circle` amber icon + "Unmatched Transactions" text + pill badge `N` (orange-50 / orange-600). Click header → toggle content.

**Each row structure** (mockup `.unmatched-item` — grid-like but is a `<div>` flex row):

| Zone | Content |
|------|---------|
| Left | `.txn-id`: monospace `gatewayTransactionId` · gateway name · amount+currency · date<br/>`.txn-info` (small muted): card-last-4 / IP / payment-method hint (from `pt.UserAgent`, `pt.IPAddress`, `pt.PaymentMethodType.DataName`) |
| Middle (amber pill) | `ph:lightbulb` + "Possible match: RCP-XXXX ($XX, Donor, Apr N)" — OR — "No auto-match suggestions" |
| Right | [Match Manually] (amber outline) · [Create Donation] (green outline) |

Auto-match suggestion source: `GetAutoMatchSuggestion(paymentTransactionId)` — returns top-1 `AutoMatchSuggestionDto` (score ≥ 70 threshold for display). Prefetch suggestions for all visible rows in one bulk query `GetAutoMatchSuggestions([ids])` (avoid N+1).

**Actions per row:**
- [Match Manually] → opens `<MatchTransactionModal>` with auto-suggestion pre-selected if present.
- [Create Donation] → navigates to `/[lang]/crm/donation/globaldonation?mode=new&prefill_pt={paymentTransactionId}` OR opens in-page `<CreateDonationFromTxnModal>` (designer's call — if GlobalDonation form is a FLOW view-page with 4 sections, prefer the navigation approach; if it's a simple modal, open inline).

---

### Section 3: "Settlement Summary" Table (8 columns)

| # | Column Header | Field Key | Display Type | Notes |
|---|--------------|-----------|-------------|-------|
| 1 | Gateway | `paymentGatewayName` | gateway-brand-badge renderer | — |
| 2 | Period | `periodLabel` (server-computed: "Apr 1-7") | text | From min/max SettlementDate in batch group |
| 3 | Gross | `grossAmount` + currency | positive-currency-cell (green-600, bold) | right-align |
| 4 | Fees | `totalFees` + currency | fee-currency-cell (red-600, small) | right-align; prefix "−" |
| 5 | Net | `netAmount` + currency | net-currency-cell (slate-900, bold 700) | right-align |
| 6 | Transactions | `transactionCount` | number | — |
| 7 | Status | `settlementStatusCode` | settlement-status-badge renderer (same as Section 1 col 9) | — |
| 8 | Settlement Date | `settlementDate` | date OR `—` if null | `DateOnlyPreview` |

Source: `GetSettlementSummaryList(dateFrom, dateTo)` — flat projection of `PaymentSettlement` rows in range, ordered by SettlementDate desc. No pagination (typically <50 rows/month).

---

### FLOW View-Page — Modified 3-Mode Behavior

> **DEVIATION from canonical FLOW**: only `?mode=read` is wired. `?mode=new` and `?mode=edit` are **intentionally absent** (webhook-created records, not user-editable).

```
URL MODE                                              UI LAYOUT
───────────────────────────────────────────────────   ──────────────────────────
/reconciliation                                    →   INDEX  (dashboard)
/reconciliation?mode=read&id=243                   →   DETAIL (single PT audit)
```

#### LAYOUT 1 (absent): FORM — N/A for this screen

#### LAYOUT 2: DETAIL (mode=read) — Single PaymentTransaction audit view

> Not in the mockup explicitly (mockup shows index only), but FLOW convention requires a read-detail for row-click. Design by analogy to DonationInKind #7 detail drawer — **use a right-side drawer (560px wide)** over the index page, NOT a full page, so finance users can quickly inspect multiple transactions without losing grid context.

**Implementation**: When URL has `?mode=read&id=X`, the index page remains visible and overlays `<ReconciliationDetailDrawer>` on the right (similar to DonationInKind's dik-detail-drawer but 560px).

**Drawer Header**:
- Title: `gatewayTransactionId` (monospace large)
- Subtitle: `{paymentGatewayName}` · `{MMM D, YYYY HH:mm}`
- Actions: `[Close]` (X), `[Match]` (if unmatched), `[Respond]` (if disputed)

**Drawer Body — 6 stacked sections**:

| # | Section | Content |
|---|--------|---------|
| 1 | Transaction Info | IdempotencyKey, TransactionTypeName, TransactionStatusName (badge), GatewayOrderId, CreatedDate |
| 2 | Amounts | DonorAmount+DonorCurrency (large), ExchangeRate, SettlementAmount+SettlementCurrency, GatewayFee, ProcessingFee, NetAmount, RefundedAmount |
| 3 | Donor (if ContactId) | Avatar, ContactName, ContactCode, Email, Phone, "View Profile" link → `/[lang]/crm/contact/contact?mode=read&id={contactId}`. If anonymous → "Anonymous Donor" card with IPCountryCode + DonorCountryCode |
| 4 | Match & Donation (if matched) | MatchStatus badge, GlobalDonation.ReceiptNumber link, DonationPurpose name, DonationMode name, PaymentStatus, [Unmatch] button (danger outline, only if Receipt not issued) |
| 5 | Dispute (only if DisputeStatusId NOT NULL) | DisputeStatus (badge), DisputeReason (multi-line), DisputeOpenedAt, DisputeResolvedAt, [Respond to Dispute] button (if not yet resolved) |
| 6 | Settlement (if SettledAt NOT NULL) | SettlementStatus (badge), SettlementDate, BankReference, GatewaySettlementId, Gross/Fee/Net breakdown from joined PaymentSettlement |

**Drawer Footer**: audit timeline — CreatedDate, ModifiedDate, WebhookReceivedAt.

---

### Page Widgets & Summary Cards

**Widgets**: 4 KPI widgets as specified above.

**Summary GQL Query**:
- Query name: `GetReconciliationSummary(dateFrom: Date, dateTo: Date)`
- Returns: `ReconciliationSummaryDto`
- Fields: `totalCount: int, totalAmount: decimal, matchedCount: int, matchedAmount: decimal, unmatchedCount: int, unmatchedAmount: decimal, disputedCount: int, disputedAmount: decimal`
- Added to `ReconciliationQueries.cs` alongside the other 4 reconciliation queries.

### Grid Aggregation Columns

**Aggregation Columns**: NONE (all per-row computed values are part of the BE projection — see ②/④).

### User Interaction Flow (modified for reconciliation)

1. User lands at `/reconciliation` — index renders: KPIs, Reconciliation Details table (past 30 days default), Unmatched panel (collapsed count), Settlement Summary.
2. Date-range selector change → Zustand store updates `dateFrom / dateTo` → all 4 queries re-execute (widgets + 3 tables) via one dispatched refetch.
3. [Run Reconciliation] button → opens confirmation dialog ("Run auto-match for selected date range? This will match transactions with confidence ≥ 90%.") → on confirm, fires `RunAutoReconciliation(dateFrom, dateTo)` mutation → success toast with "{N} matched automatically, {M} left for manual review" → refetch all 4 queries.
4. User clicks row in main table → URL: `?mode=read&id=X` → DETAIL drawer opens over index (no navigation away).
5. User clicks [Close] on drawer → URL: `/reconciliation` (no params) → drawer closes.
6. In Unmatched panel, user clicks [Match Manually] → Zustand state `{ modal: 'match', targetPtId: X }` → `<MatchTransactionModal>` renders → user selects GlobalDonation (via ApiSelect searching recent unmatched donations) → Match button fires `MatchPaymentTransaction(paymentTransactionId, globalDonationId, allowAmountMismatch?)` → success toast → modal closes → refetch unmatched list + main table + KPIs.
7. User clicks [Create Donation] on unmatched row → navigates to `/[lang]/crm/donation/globaldonation?mode=new&prefill_pt={paymentTransactionId}` (GlobalDonation screen reads the `prefill_pt` query-param and pre-fills its form). (Decision: navigation-based, since GlobalDonation is a full-page FLOW with 4 sections.)
8. User clicks [Respond] on disputed row → Zustand `{ modal: 'respond', targetPtId: X }` → `<RespondToDisputeModal>` opens → user enters decision + response text → submit fires `RespondToDispute(...)` → success toast → modal closes → refetch main table.
9. User clicks [Export Report] → SERVICE_PLACEHOLDER toast ("Export queued — you'll be emailed when ready.").
10. Donor-link click in grid → navigates away to Contact detail.
11. DonationRef-link click in grid → navigates away to GlobalDonation detail.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: `DuplicateContact` (FLOW #21 — custom workbench with modals; the closest sibling). Secondary reference for 4-KPI widget layout: `DonationInKind` #7.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| DuplicateContact | PaymentReconciliation | Screen / feature name (no single entity — projection) |
| duplicateContact | paymentReconciliation | Variable / field names |
| — (no primary entity) | — | No PK field (we operate on existing PaymentTransaction.Id) |
| DuplicateContacts | Reconciliation | Service-layer plural name (for folder: `Reconciliation/`) |
| duplicate-contact | payment-reconciliation | FE route path kebab-case |
| duplicatecontact | reconciliation | FE folder + URL slug (matches MenuUrl `crm/donation/reconciliation`) |
| DUPLICATECONTACT | RECONCILIATION | Grid code / menu code |
| corg | fund | DB schema |
| Contact | Donation | Backend group name (Models/Schemas/Business = `DonationModels/DonationSchemas/DonationBusiness`) |
| ContactModels | DonationModels | Namespace suffix |
| CRM_MAINTENANCE | CRM_DONATION | Parent menu code |
| CRM | CRM | Module code |
| crm/maintenance/duplicatecontact | crm/donation/reconciliation | FE route path |
| contact-service | donation-service | FE service folder name (DTO/GQL go under donation-queries / donation-mutations) |

**New file naming convention** (since this is a non-entity feature):
- All new BE code lives under `Base.Application/Business/DonationBusiness/Reconciliation/` (NOT `PaymentTransactions/` — avoid confusion with existing PT read queries).
- All new FE code lives under `src/presentation/components/page-components/crm/donation/reconciliation/`.
- DTOs live in `DonationSchemas/ReconciliationSchemas.cs` (one file — 5 DTOs).
- GQL operations registered on existing `PaymentTransactionQueries` endpoint class (add methods) OR a new `ReconciliationQueries` class (prefer new class — clean separation).

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (10 new + 4 modified — NO new entity, NO migration)

**New BE files:**

| # | File | Path |
|---|------|------|
| 1 | DTOs (5 classes in one file) | `Base.Application/Schemas/DonationSchemas/ReconciliationSchemas.cs` |
| 2 | GetReconciliationList Query | `Base.Application/Business/DonationBusiness/Reconciliation/GetReconciliationListQuery/GetReconciliationList.cs` |
| 3 | GetUnmatchedTransactionList Query | `Base.Application/Business/DonationBusiness/Reconciliation/GetUnmatchedTransactionListQuery/GetUnmatchedTransactionList.cs` |
| 4 | GetSettlementSummaryList Query | `Base.Application/Business/DonationBusiness/Reconciliation/GetSettlementSummaryListQuery/GetSettlementSummaryList.cs` |
| 5 | GetReconciliationSummary Query | `Base.Application/Business/DonationBusiness/Reconciliation/GetReconciliationSummaryQuery/GetReconciliationSummary.cs` |
| 6 | GetAutoMatchSuggestions Query | `Base.Application/Business/DonationBusiness/Reconciliation/GetAutoMatchSuggestionsQuery/GetAutoMatchSuggestions.cs` |
| 7 | MatchPaymentTransaction Command | `Base.Application/Business/DonationBusiness/Reconciliation/MatchCommand/MatchPaymentTransaction.cs` |
| 8 | UnmatchPaymentTransaction Command | `Base.Application/Business/DonationBusiness/Reconciliation/UnmatchCommand/UnmatchPaymentTransaction.cs` |
| 9 | RespondToDispute Command | `Base.Application/Business/DonationBusiness/Reconciliation/RespondToDisputeCommand/RespondToDispute.cs` |
| 10 | RunAutoReconciliation Command | `Base.Application/Business/DonationBusiness/Reconciliation/RunAutoReconciliationCommand/RunAutoReconciliation.cs` |
| 11 | ReconciliationQueries endpoint | `Base.API/EndPoints/Donation/Queries/ReconciliationQueries.cs` |
| 12 | ReconciliationMutations endpoint | `Base.API/EndPoints/Donation/Mutations/ReconciliationMutations.cs` |

Note: `CreateDonationFromTransaction` is NOT a new command — the FE navigates to the existing GlobalDonation create flow with `prefill_pt={id}` query param. The existing `CreateGlobalDonation` command handles the atomic GD + GlobalOnlineDonation insert (already works per current code). If the existing CreateGlobalDonation command does NOT accept a `SourcePaymentTransactionId` for the link, that is ISSUE-10 below.

**Backend Wiring Updates:**

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `DonationMappings.cs` | 5 Mapster mappings: PaymentTransaction→ReconciliationTransactionDto, PaymentTransaction→UnmatchedTransactionDto, PaymentSettlement→SettlementSummaryDto + explicit `.Map(...)` for nav-property flattening (paymentGatewayName, contactName, donorCurrencyCode, etc.). |
| 2 | — | NO `IDonationDbContext.cs` change (no new entity). |
| 3 | — | NO `DonationDbContext.cs` change. |
| 4 | — | NO `DecoratorProperties.cs` change (no new entity). |
| 5 | `GlobalUsing.cs` (Application + API) | Add `global using Base.Application.Business.DonationBusiness.Reconciliation.*;` if needed for endpoint registration. |

No migration required. No new table. No new FK.

### Frontend Files (14 new + 5 modified — overwriting stub)

**New FE files** (all under `src/presentation/components/page-components/crm/donation/reconciliation/` unless noted):

| # | File | Purpose |
|---|------|---------|
| 1 | `src/domain/entities/donation-service/ReconciliationDto.ts` | 5 DTO types mirroring BE schemas |
| 2 | `src/infrastructure/gql-queries/donation-queries/ReconciliationQuery.ts` | 5 GQL queries (list, unmatched, settlement, summary, suggestions) |
| 3 | `src/infrastructure/gql-mutations/donation-mutations/ReconciliationMutation.ts` | 4 GQL mutations (match, unmatch, respond, run-auto) |
| 4 | `src/presentation/pages/donation/reconciliation/reconciliation.tsx` | Page config (sidebar wiring) |
| 5 | `.../reconciliation/index.tsx` | Router — dispatches to index-page OR opens detail drawer based on `?mode=read&id=X` |
| 6 | `.../reconciliation/index-page.tsx` | Variant B — ScreenHeader + 4 widgets + 3 section cards |
| 7 | `.../reconciliation/reconciliation-widgets.tsx` | 4 KPI cards |
| 8 | `.../reconciliation/reconciliation-toolbar.tsx` | Date-range select + Run Reconciliation + Export (goes INTO ScreenHeader actions slot) |
| 9 | `.../reconciliation/reconciliation-details-table.tsx` | Section 1 — main 10-col table |
| 10 | `.../reconciliation/unmatched-transactions-panel.tsx` | Section 2 — collapsible panel + rows |
| 11 | `.../reconciliation/unmatched-transaction-item.tsx` | Single unmatched row (with auto-suggestion) |
| 12 | `.../reconciliation/settlement-summary-table.tsx` | Section 3 — settlement table |
| 13 | `.../reconciliation/reconciliation-detail-drawer.tsx` | Right-side 560px drawer for `?mode=read&id=X` |
| 14 | `.../reconciliation/match-transaction-modal.tsx` | Action modal — select GlobalDonation to link |
| 15 | `.../reconciliation/respond-to-dispute-modal.tsx` | Action modal — dispute response form |
| 16 | `.../reconciliation/reconciliation-store.ts` | Zustand — dateRange / activeModal / targetPtId / drawerOpen |

**New renderers** (4 new, registered in 3 column-type registries: advanced / basic / flow + shared-cell-renderers barrel):

| # | Renderer | File | Registers As |
|---|---------|------|--------------|
| R1 | `gateway-brand-badge` | `src/presentation/components/shared/cell-renderers/GatewayBrandBadgeRenderer.tsx` | `gateway-brand-badge` |
| R2 | `match-status-badge` | `src/presentation/components/shared/cell-renderers/MatchStatusBadgeRenderer.tsx` | `match-status-badge` |
| R3 | `settlement-status-badge` | `src/presentation/components/shared/cell-renderers/SettlementStatusBadgeRenderer.tsx` | `settlement-status-badge` |
| R4 | `currency-amount-cell` | `src/presentation/components/shared/cell-renderers/CurrencyAmountCellRenderer.tsx` | `currency-amount` |

REUSE existing: `donor-link` (from Pledge #12 — if built), `txn-code` (monospace pill from ChequeDonation #6 — if built), `DateOnlyPreview`, `status-badge`.

**Frontend Wiring Updates:**

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/app/[lang]/crm/donation/reconciliation/page.tsx` | OVERWRITE stub with `<ReconciliationIndex />` re-export |
| 2 | `src/application/configs/data-table-configs/donation-service-entity-operations.ts` | Add `gridCode: "RECONCILIATION"` entry with all 4 new queries + 4 new mutations |
| 3 | `src/infrastructure/gql-queries/donation-queries/index.ts` (barrel) | Export new `RECONCILIATION_*_QUERY` constants |
| 4 | `src/infrastructure/gql-mutations/donation-mutations/index.ts` (barrel) | Export new mutations |
| 5 | `src/domain/entities/donation-service/index.ts` (barrel) | Export new DTO types |
| 6 | `src/presentation/pages/donation/index.ts` (barrel) | Export reconciliation page config |
| 7 | `src/presentation/components/shared/cell-renderers/index.ts` (barrel) | Export 4 new renderers |
| 8 | Advanced + Basic + Flow column-type registries | Register 4 new cell types |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Reconciliation
MenuCode: RECONCILIATION
ParentMenu: CRM_DONATION
Module: CRM
MenuUrl: crm/donation/reconciliation
OrderBy: 7
GridType: FLOW

MenuCapabilities: READ, MODIFY, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY, EXPORT

GridFormSchema: SKIP
GridCode: RECONCILIATION
---CONFIG-END---
```

**Capability notes:**
- No CREATE / DELETE / TOGGLE / IMPORT (transactions are webhook-created, never user-CRUD'd).
- MODIFY covers the Match / Unmatch / RespondToDispute mutations.
- EXPORT for SERVICE_PLACEHOLDER Export Report button.

**Grid fields** (for the main Reconciliation table seed — 10 columns, GridFormSchema=SKIP):
1. gatewayTransactionId (Transaction ID)
2. paymentGatewayName (Gateway)
3. createdDate (Date)
4. donorAmount (Amount)
5. donorCurrencyCode (Currency)
6. contactName (Donor)
7. receiptNumber (Donation Ref)
8. matchStatusCode (Match Status)
9. settlementStatusCode (Settlement)
10. (actions — inline, not a grid field)

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type extensions: `ReconciliationQueries` (new class)
- Mutation type extensions: `ReconciliationMutations` (new class)

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetReconciliationList | PaginatedApiResponse<ReconciliationTransactionDto[]> | dateFrom: Date, dateTo: Date, paymentGatewayId?: int, matchStatus?: string (MATCHED/UNMATCHED/DISPUTED), request: GridFeatureRequest |
| GetUnmatchedTransactionList | PaginatedApiResponse<UnmatchedTransactionDto[]> | dateFrom: Date, dateTo: Date, request: GridFeatureRequest |
| GetSettlementSummaryList | BaseApiResponse<SettlementSummaryDto[]> | dateFrom: Date, dateTo: Date |
| GetReconciliationSummary | BaseApiResponse<ReconciliationSummaryDto> | dateFrom: Date, dateTo: Date |
| GetAutoMatchSuggestions | BaseApiResponse<AutoMatchSuggestionDto[]> | paymentTransactionIds: int[] (bulk — prevents N+1) |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| MatchPaymentTransaction | { paymentTransactionId: int, globalDonationId: int, allowAmountMismatch?: bool } | int (new GlobalOnlineDonationId) |
| UnmatchPaymentTransaction | { paymentTransactionId: int, reason?: string, force?: bool } | int |
| RespondToDispute | { paymentTransactionId: int, newDisputeStatusId: int, responseText: string } | int |
| RunAutoReconciliation | { dateFrom: Date, dateTo: Date } | RunReconciliationResult { autoMatched: int, unresolved: int, failed: int } |

**Response DTO Fields:**

`ReconciliationTransactionDto` (main grid):
| Field | Type | Notes |
|-------|------|-------|
| paymentTransactionId | number | PK |
| gatewayTransactionId | string | THE MATCH KEY |
| paymentGatewayId | number | — |
| paymentGatewayName | string | FK flat |
| paymentGatewayCode | string | FK flat (used by gateway-brand-badge for brand icon) |
| contactId | number \| null | — |
| contactName | string \| null | Flat `firstName + lastName` |
| donorAmount | number | — |
| donorCurrencyCode | string | — |
| donorCurrencyId | number | — |
| createdDate | string (ISO) | — |
| settledAt | string (ISO) \| null | — |
| transactionStatusCode | string | From MasterData (CAPTURED / SETTLED / etc.) |
| transactionStatusName | string | — |
| disputeStatusId | number \| null | — |
| disputeStatusCode | string \| null | NONE / OPEN / UNDERREVIEW / WON / LOST / ACCEPTED |
| globalDonationId | number \| null | — |
| receiptNumber | string \| null | RCP-YYYY-#### from linked GD |
| matchStatusCode | string | COMPUTED: MATCHED / UNMATCHED / DISPUTED |
| settlementStatusCode | string | COMPUTED: SETTLED / PENDING / OPEN |
| settlementStatusName | string | — |
| gatewayFee | number \| null | — |
| netAmount | number \| null | — |
| isActive | boolean | inherited |

`UnmatchedTransactionDto` extends ReconciliationTransactionDto:
| Field | Type | Notes |
|-------|------|-------|
| ...all ReconciliationTransactionDto fields | | |
| paymentMethodTypeName | string \| null | e.g., "Card", "UPI" |
| lastFourDigits | string \| null | Parsed from gateway metadata (if available) — else null |
| ipCountryCode | string \| null | — |
| autoMatchSuggestion | AutoMatchSuggestionDto \| null | Top-1 candidate |

`AutoMatchSuggestionDto`:
| Field | Type | Notes |
|-------|------|-------|
| paymentTransactionId | number | — |
| globalDonationId | number | Candidate target |
| receiptNumber | string | — |
| donationAmount | number | — |
| donationCurrencyCode | string | — |
| donationDate | string (ISO) | — |
| donorName | string \| null | — |
| confidenceScore | number | 0-100 |
| matchReason | string | Human-readable: "Exact amount + same contact + same day" |

`SettlementSummaryDto`:
| Field | Type | Notes |
|-------|------|-------|
| paymentSettlementId | number | PK |
| paymentGatewayId | number | — |
| paymentGatewayName | string | Flat |
| paymentGatewayCode | string | Flat |
| periodLabel | string | Server-computed: "Apr 1-7" from SettlementDate cluster |
| settlementDate | string (ISO) \| null | — |
| currencyId | number | — |
| currencyCode | string | Flat |
| grossAmount | number | — |
| totalFees | number | — |
| netAmount | number | — |
| transactionCount | number | — |
| settlementStatusCode | string | SETTLED / PENDING / INTRANSIT |
| settlementStatusName | string | — |
| bankReference | string \| null | — |

`ReconciliationSummaryDto`:
| Field | Type |
|-------|------|
| totalCount | number |
| totalAmount | number |
| matchedCount | number |
| matchedAmount | number |
| matchedPct | number (0-100) |
| unmatchedCount | number |
| unmatchedAmount | number |
| unmatchedPct | number |
| disputedCount | number |
| disputedAmount | number |
| disputedPct | number |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/[lang]/crm/donation/reconciliation`
- [ ] Zero new tsc errors (baseline snapshot before changes)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] 4 KPI widgets render with correct counts + amounts for default date range (This Month)
- [ ] KPI percentages compute correctly (matched/total, unmatched/total, disputed/total)
- [ ] Reconciliation Details table loads 10 columns with seed data
- [ ] Date-range selector re-queries all 4 sections in a single user action
- [ ] Match Status badge color-coding works: Matched=green, Unmatched=amber, Disputed=red
- [ ] Unmatched row has amber background tint; Disputed row has red background tint
- [ ] Row click (outside Actions column) opens detail drawer via `?mode=read&id=X`
- [ ] Donor column link navigates to Contact detail
- [ ] Donation Ref column link navigates to GlobalDonation detail
- [ ] Action buttons render by match status: Matched→[View]; Unmatched→[Match][Investigate]; Disputed→[Respond][View]
- [ ] Unmatched Transactions panel collapses/expands on header click
- [ ] Unmatched panel shows auto-match suggestion when available (amber pill with ph:lightbulb)
- [ ] "Match Manually" modal: ApiSelect searches GlobalDonations, pre-selects auto-suggestion if any, submits `MatchPaymentTransaction`
- [ ] After successful Match: row disappears from Unmatched + appears as Matched in main table + KPIs refresh
- [ ] Amount-mismatch dialog: when PT.amount ≠ GD.amount (>0.01), confirmation prompt requires explicit "Match anyway" before proceeding
- [ ] "Create Donation" button from unmatched row → navigates to `/[lang]/crm/donation/globaldonation?mode=new&prefill_pt={id}` with form pre-filled
- [ ] "Respond to Dispute" modal: dropdown of Won/Lost/Accepted; response text required; submit updates DisputeStatusId + DisputeResolvedAt
- [ ] Disputed row's Respond button disabled if DisputeStatus already terminal (Won/Lost/Accepted)
- [ ] "Run Reconciliation" button triggers `RunAutoReconciliation`: confirmation dialog first, then toast with `{autoMatched, unresolved, failed}` counts, then refetch
- [ ] Detail drawer (560px right-side) opens on `?mode=read&id=X` with 6 sections populated by GetPaymentTransactionById (existing query — extend projection if needed)
- [ ] Drawer header shows [Match]/[Respond] buttons contextually
- [ ] Drawer section 5 (Dispute) visible ONLY if DisputeStatusId NOT NULL
- [ ] Drawer section 4 (Match & Donation) shows [Unmatch] button only if GlobalDonation has no Receipt issued
- [ ] Close drawer returns URL to `/reconciliation` without losing table state
- [ ] Settlement Summary shows all 8 columns; Gross=green, Fees=red with `−` prefix, Net=bold black
- [ ] Export Report button triggers SERVICE_PLACEHOLDER toast
- [ ] Upload Dispute Evidence → SERVICE_PLACEHOLDER toast
- [ ] No N+1 query in Unmatched panel (GetAutoMatchSuggestions is bulk)
- [ ] Tenant scoping: spoofing a different CompanyId returns 0 rows
- [ ] Permissions: Respond/Match buttons hidden for roles without MODIFY capability
- [ ] Phosphor icons (not FontAwesome) — `rg "fa-"` inside new files returns 0 hits
- [ ] Token colors (not hex) — `rg "#[0-9a-f]{6}"` in new files returns 0 hits (exception: renderer color mappings per issue-15)

**DB Seed Verification:**
- [ ] RECONCILIATION menu appears in sidebar under CRM_DONATION at OrderBy=7
- [ ] 5 role-capabilities inserted (BUSINESSADMIN READ/MODIFY/EXPORT)
- [ ] Grid row inserted for RECONCILIATION with GridType=FLOW
- [ ] 9 GridField rows inserted for the 9 data columns
- [ ] GridFormSchema is NULL (SKIP — no modal form)
- [ ] New MasterDataType `RECONCILIATIONMATCHSTATUS` inserted with 3 values (MATCHED=#16a34a, UNMATCHED=#d97706, DISPUTED=#dc2626) and ColorHex populated
- [ ] SETTLEMENTSTATUS MasterData expanded with SETTLED=#16a34a, PENDING=#3b82f6, OPEN=#dc2626 rows (appended to existing INTRANSIT row)
- [ ] TRANSACTIONSTATUS MasterDataType declaration added to STEP 1 of PaymentGateway-MasterData-seed.sql (resolves pre-existing drift)
- [ ] 3 sample `PaymentGateway` rows seeded (Stripe / PayPal / Razorpay) if absent
- [ ] 10 sample `PaymentTransaction` rows seeded (mix of matched + unmatched + disputed across 3 gateways) for E2E testing
- [ ] 4 sample `PaymentSettlement` rows seeded for Settlement Summary section

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### Architectural deviations from canonical FLOW

1. **NO new entity** — the screen is a projection over `PaymentTransaction` + `PaymentSettlement` + `GlobalOnlineDonation`. Do NOT scaffold a `Reconciliation.cs` entity, EF Configuration, or migration. The 11-file FLOW template's Entity/EF/Delete/Toggle/GetById/GetAll are replaced by 5 custom queries + 4 custom mutations.

2. **NO ?mode=new or ?mode=edit** — the only FLOW URL modes wired are index (no params) and `?mode=read&id=X`. The "new" analogue is handled by navigating to the existing GlobalDonation FLOW with `prefill_pt={id}`.

3. **Detail is a DRAWER, not a page** — `?mode=read&id=X` opens a 560px right-side drawer overlay (not a navigated page). This preserves index state across drill-ins. Precedent: DonationInKind #7 dik-detail-drawer (420px) — here we use 560px because the detail has 6 richer sections.

4. **Main grid is a plain table, NOT FlowDataTable** — the mockup shows a result table (no per-column filters/sort/column-drag). Use `<SimpleDataTable>` or raw `<table>` + Tailwind tokens. Date range + gateway filter live in the TOOLBAR (ScreenHeader actions), not per-column. This keeps the finance-ops UX tight.

5. **3 stacked section-cards** — Reconciliation Details / Unmatched / Settlement Summary are independent queries stacked vertically. They share the date-range filter but each has its own query + loading state + empty state.

### Gotchas

6. **Match detection via GatewayTransactionId** — the match predicate is `PaymentTransaction.GatewayTransactionId` = `GlobalOnlineDonation.GatewayTransactionId` (plus company + gateway). ContactId is not part of the match key — a donor may have multiple transactions.

7. **Match computed — NOT persisted** — `matchStatusCode` on the DTO is derived in the LINQ projection (`LEFT JOIN GlobalOnlineDonation + DisputeStatusId check`). There is no `match_status` column on PaymentTransaction.

8. **Dispute precedence** — if DisputeStatusId is NOT NULL AND DataValue ≠ `NONE`, the transaction is "Disputed" regardless of whether a matching GlobalOnlineDonation exists. A disputed matched transaction is still Disputed in the UI.

9. **Cross-currency summing** — the 4 KPI widgets sum `donorAmount` in DonorCurrency. For multi-currency tenants, this is misleading. The correct aggregation is `BaseCurrencyAmount` (convert via `ExchangeRate`). If BaseCurrencyAmount is absent on PaymentTransaction (it is — not on entity), this is ISSUE-12 below.

10. **Tenant scope is load-bearing** — the GetReconciliationList query MUST filter by `CompanyId = HttpContext.User.CompanyId`. A cross-tenant leak in a finance-ops screen is a critical data-protection failure. Include this in the test checklist.

11. **Webhook idempotency** — if a webhook replays a transaction that's already Matched, the Match mutation MUST fail loud (not silently no-op) — use `throw new DuplicateRecordException("GatewayTransactionId already linked...")`.

12. **Seed-data drift resolution** — the existing `PaymentGateway-MasterData-seed.sql` has **TRANSACTIONSTATUS** and **SETTLEMENTSTATUS** MasterData INSERTs but is MISSING their MasterDataType declarations in STEP 1. The build agent MUST add those declarations to prevent FK failures. Also the SETTLEMENTSTATUS table only has `INTRANSIT` seeded — ADD `SETTLED`, `PENDING`, `OPEN` rows. This seed file is in `sql-scripts-dyanmic/` — **preserve the repo typo** per ChequeDonation #6 ISSUE-15 precedent.

13. **PaymentGateway seed data** — check whether `com.PaymentGateways` is already seeded with Stripe / PayPal / Razorpay rows. If absent, add them with `PaymentGatewayCode IN ('STRIPE', 'PAYPAL', 'RAZORPAY')` — the FE `gateway-brand-badge` renderer depends on these codes to pick the brand icon + color.

14. **Renderer color hex allowed** — per UI uniformity memory, inline hex is forbidden EXCEPT for data-driven colors (status badges, brand colors). The 4 new renderers (gateway-brand, match-status, settlement-status, currency-amount) are allowed to use hex for brand/status mappings. This matches the Tag #22 ISSUE-5 / ChequeDonation #6 precedent.

15. **Phosphor icon mapping (fa-* → ph:*)**:
    - `fa-arrows-rotate` → `ph:arrows-clockwise`
    - `fa-file-export` → `ph:export`
    - `fa-arrows-left-right` → `ph:arrows-left-right`
    - `fa-check-double` → `ph:checks`
    - `fa-question` → `ph:question`
    - `fa-gavel` → `ph:gavel`
    - `fa-check-circle` → `ph:check-circle`
    - `fa-question-circle` → `ph:question`
    - `fa-exclamation-triangle` → `ph:warning`
    - `fa-chevron-down` → `ph:caret-down`
    - `fa-table` → `ph:table`
    - `fa-landmark` → `ph:bank`
    - `fa-clock` → `ph:clock`
    - `fa-circle-exclamation` → `ph:warning-circle`
    - `fa-lightbulb` → `ph:lightbulb`
    - `fab fa-stripe-s` → `ph:credit-card` (generic — brand icon is set via `paymentGatewayCode`)
    - `fab fa-paypal` → `ph:credit-card` (generic — brand icon via code)
    - `fa-bolt` → `ph:lightning`
    - `fa-check` → `ph:check`

16. **Brand color mapping** (renderer-local constants):
    - STRIPE: `#635bff` text + `ph:credit-card`
    - PAYPAL: `#003087` text + `ph:credit-card`
    - RAZORPAY: `#072654` text + `ph:lightning`
    - Default: `slate-700` + `ph:credit-card`

17. **GlobalDonation #1 already COMPLETED** — the FE can safely link-navigate `globaldonation?mode=read&id=X`. The prefill_pt extension (ISSUE-10) requires coordination with GlobalDonation's create form — it may not yet accept `prefill_pt` as a URL param.

### ISSUEs pre-flagged (opened during planning)

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | CRITICAL | BE seed | PaymentGateway-MasterData-seed.sql STEP 1 is missing TRANSACTIONSTATUS + SETTLEMENTSTATUS MasterDataType declarations; STEP 2 references them. Build agent must add declarations + ensure seed is re-runnable. |
| ISSUE-2 | HIGH | BE seed | SETTLEMENTSTATUS has only INTRANSIT seeded; the reconciliation UI needs SETTLED/PENDING/OPEN with ColorHex. Must ADD these rows to the seed. |
| ISSUE-3 | HIGH | BE | PaymentGateway seed may be missing Stripe/PayPal/Razorpay master rows; gateway-brand-badge renderer depends on `paymentGatewayCode` matching these. Verify `com.PaymentGateways` before testing; seed if absent. |
| ISSUE-4 | HIGH | BE | MatchPaymentTransaction amount-mismatch tolerance (±0.01) may be too strict for cross-currency matches where the PT is in one currency and the GD is in another. Current plan: require both currencies equal. Multi-currency match deferred. |
| ISSUE-5 | MED | BE | Auto-match confidence threshold (≥90) is a tunable constant. Should it be a MasterData/setting value? Current plan: hardcoded constant in handler with a code comment. |
| ISSUE-6 | MED | BE | RunAutoReconciliation over a 1-year date range could match thousands of pairs — handler must commit in batches of 100 to avoid transaction-log bloat. Current plan: chunk in BE handler. |
| ISSUE-7 | MED | BE | GlobalOnlineDonation.IsDeleted on Unmatch — verify the EF configuration supports soft-delete, OR physically delete the row if preserved audit is elsewhere. Current plan: soft-delete; if not supported, ISSUE reclassed to CRITICAL. |
| ISSUE-8 | MED | FE | Detail drawer sections depend on `GetPaymentTransactionById` returning the joined GlobalOnlineDonation + GlobalDonation + PaymentSettlement data. Existing query (PaymentTransactionQueries.GetPaymentTransactionById) may not project these — extend the existing handler to include them. |
| ISSUE-9 | MED | BE+FE | `GetAutoMatchSuggestions(paymentTransactionIds: int[])` is a bulk query to avoid N+1. Handler must validate max 50 IDs per call; FE chunk in pages of 50. |
| ISSUE-10 | HIGH | FE+BE cross-screen | `prefill_pt={id}` query-param handler for GlobalDonation's create form does NOT yet exist. FE team must coordinate with GlobalDonation #1 follow-up: read `prefill_pt`, fetch the PaymentTransaction, pre-fill amount/currency/contact/date/mode, and on save create the GlobalOnlineDonation link. Blocker for the "Create Donation" action flow — if not ready, SERVICE_PLACEHOLDER toast. |
| ISSUE-11 | MED | FE | Tailwind bg tint for Unmatched / Disputed rows (`bg-amber-50` / `bg-red-50`) may clash with `FlowDataTable`'s built-in zebra-striping if reused later. Current plan uses SimpleDataTable so no conflict — if switched to FlowDataTable, revisit. |
| ISSUE-12 | MED | BE | KPI widgets sum DonorAmount in DonorCurrency — correct aggregation should use BaseCurrencyAmount + ExchangeRate. PaymentTransaction does NOT store BaseCurrencyAmount. Current plan: filter summary to the tenant's base currency only; show a disclaimer tooltip for multi-currency tenants. |
| ISSUE-13 | LOW | FE | "Last 7 days" / "This Quarter" / "Custom Range" options in date-range selector need a DateRangePickerPopover for "Custom Range". Current plan: use existing `DateRangePicker` from shared components; if absent, build a simple `from/to` input pair. |
| ISSUE-14 | LOW | FE | Export Report — format (PDF/CSV/XLSX) + what columns + server-generated vs client-generated. SERVICE_PLACEHOLDER — defer to Wave 4. |
| ISSUE-15 | LOW | FE | Dispute evidence upload (response_evidence) — SERVICE_PLACEHOLDER (file-upload infra is not wired in this codebase per ChequeDonation #6 ISSUE-4). |

### Service Dependencies (UI-only placeholders — no backend service yet)

- **Export Report** — full UI implemented (button + toast). Handler stubs with `toast.info('Export queued — you will be notified when ready.')`. No server-side report generation.
- **Dispute Evidence Upload** — modal field placeholder renders a disabled file-input with "Upload service unavailable" note. Respond mutation still works without the evidence attachment.
- **Email notification on Match/Resolve** — no automatic notification sent to finance team. Toast-only confirmation.

Full UI must be built (buttons, modals, tables, drawer, badges, empty states). Only the Export Report and Dispute Evidence file upload are mocked to toasts.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | PLANNING | CRITICAL | BE seed | PaymentGateway-MasterData-seed.sql STEP 1 missing TRANSACTIONSTATUS + SETTLEMENTSTATUS MasterDataType declarations | CLOSED (session 1) |
| ISSUE-2 | PLANNING | HIGH | BE seed | SETTLEMENTSTATUS only has INTRANSIT; need SETTLED/PENDING/OPEN rows with ColorHex | CLOSED (session 1) |
| ISSUE-3 | PLANNING | HIGH | BE | PaymentGateway master rows for Stripe/PayPal/Razorpay may be absent | CLOSED (session 1) |
| ISSUE-4 | PLANNING | HIGH | BE | Cross-currency Match requires same currency; multi-currency deferred | CLOSED (session 1 — same-currency enforced in handler) |
| ISSUE-5 | PLANNING | MED | BE | Auto-match confidence threshold (≥90) is hardcoded — should be a tunable | OPEN |
| ISSUE-6 | PLANNING | MED | BE | RunAutoReconciliation batch size — chunk in 100s to avoid txn-log bloat | CLOSED (session 1) |
| ISSUE-7 | PLANNING | MED | BE | GlobalOnlineDonation soft-delete on Unmatch — verify EF support | CLOSED (session 1) |
| ISSUE-8 | PLANNING | MED | FE+BE | GetPaymentTransactionById projection extension for drawer sections 4-6 | CLOSED (session 7 — `reconciliationTransactionById` query + `ReconciliationDetailDto` shipped) |
| ISSUE-9 | PLANNING | MED | BE+FE | GetAutoMatchSuggestions bulk size cap 50 | CLOSED (session 1 — 50-cap enforced both sides) |
| ISSUE-10 | PLANNING | HIGH | cross-screen | prefill_pt param handler on GlobalDonation create form not yet wired | OPEN |
| ISSUE-11 | PLANNING | MED | FE | Row bg-tint for Unmatched/Disputed — plain table now, FlowDataTable later may clash | OPEN |
| ISSUE-12 | PLANNING | MED | BE | KPI widgets sum DonorAmount in native currency — multi-currency correctness | OPEN |
| ISSUE-13 | PLANNING | LOW | FE | Custom Range picker availability | OPEN |
| ISSUE-14 | PLANNING | LOW | FE | Export Report format spec | OPEN |
| ISSUE-15 | PLANNING | LOW | FE | Dispute evidence upload SERVICE_PLACEHOLDER | OPEN |

| ISSUE-16 | SESSION-1 | HIGH | FE | Drawer uses new `reconciliationTransactionById` GQL field — BE query does NOT yet expose this. Drawer renders "Record not found" empty-state until BE projection is extended. Pair with ISSUE-8. | CLOSED (session 7 — paired with ISSUE-8) |
| ISSUE-17 | SESSION-1 | LOW | BE | `RunAutoReconciliation` `CreatedBy` falls back to `0` when no HTTP context (commented `SystemUser` placeholder) — replace with real system-user id when available. | OPEN |
| ISSUE-18 | SESSION-1 | LOW | FE | 4th cell renderer named `reconciliation-currency-amount` (not spec's `currency-amount-cell`) to avoid shadowing an existing `currency-amount` renderer for donation rows. DB seed must reference `reconciliation-currency-amount` for the Amount column. | OPEN |
| ISSUE-19 | SESSION-2 | HIGH | FE | All 4 reconciliation reads (`reconciliationList`, `reconciliationSummary`, `unmatchedTransactionList`, `settlementSummaryList`) + `runAutoReconciliation` failed with HotChocolate `DateTime cannot parse the given literal of type StringValueNode` because the store emitted bare `YYYY-MM-DD` strings and the BE/HotChocolate `DateTime!` scalar requires a full ISO-8601 datetime with offset. | CLOSED (session 2) |
| ISSUE-20 | SESSION-3 | CRITICAL | BE+DB | `RunAutoReconciliation` raised `PostgresException 23503: FK_GlobalOnlineDonations_MasterDatas_PaymentMethodId`. Root cause: PT seed inserted demo rows with `PaymentMethodTypeId = NULL` because the master-data lookup returned NULL; handler then passed `0` to the required FK. Two-layer fix: handler now defensively skips NULL-method PTs (counts into `Failed`), and `PaymentReconciliation-fix-paymentmethodtype.sql` back-fills the demo rows. | CLOSED (session 4) |
| ISSUE-21 | SESSION-5 | MED | BE+DB | Repo-wide TypeCode inconsistency: `PaymentGateway-MasterData-seed.sql`, `PaymentReconciliation-sqlscripts.sql` (L488), and `Base.API/PaymentFlow/PaymentFlowService.cs` (L217, L318) all reference `PAYMENTMETHODTYPE`, but the canonical global TypeCode is `PAYMENTMETHOD` (12 entries: CARD, BANKTRANSFER, CREDITCARD, DEBITCARD, UPI, NETBANKING, WALLET, ACH, APPLEPAY, GOOGLEPAY, PAYPAL, SEPA). A fresh DB that ran only the legacy seed will end up with the wrong type and a runtime NULL on gateway-callback method resolution. Fix is a 1-line typecode rename in each + an optional data migration to merge any orphaned `PAYMENTMETHODTYPE` rows. | OPEN |
| ISSUE-22 | SESSION-6 | HIGH | BE | `RunAutoReconciliation` candidate query did not filter by `DonationMode`, so CASH / CHEQUEDD / BANKTRANSFER / RECEIPTBOOK / DIK GlobalDonations were eligible candidates. Two problems: (a) wasted scan over all offline donations on a tenant with many records, and (b) mis-pair risk — an offline cash donation sharing amount/date/contact with a real PT could win the score-90 race. Restrict candidate pool to `DonationModeId = 'OD'` (canonical online mode). | CLOSED (session 6) |
| ISSUE-23 | SESSION-6 | MED | DB | `PaymentReconciliation-runreconciliation-samples.sql` looked up DonationMode by `DataValue='ONLINE'` (wrong — canonical is `'OD'`). The OrderBy fallback then silently picked the first DonationMode row (e.g., RECEIPTBOOK), masking the bug. Demo GDs landed under the wrong mode and only matched because the old handler did not filter by mode. Fixed lookup; removed silent fallback so the seed now fails loudly if 'OD' is missing. Back-fill UPDATE added to the fix script. | CLOSED (session 6) |
| ISSUE-24 | SESSION-10 | CRITICAL | BE | `GetAutoMatchSuggestions`, `MatchPaymentTransaction`, and `RunAutoReconciliation` treated "GOD row exists for this GD" as "already linked to a PT". But the GD-Create handler inserts a placeholder GOD row at donation creation time when DonationMode=OD, with `GatewayTransactionId` NULL/empty (per entity comment: "populated AFTER gateway response"). Result: manually-created online donations never appeared as suggestion candidates and could not be matched (mutation refused with "already linked"). Tightened "linked" filter in all three handlers to require GOD.GatewayTransactionId non-empty. Also taught both match paths (manual + bulk) to UPDATE the placeholder GOD in-place rather than insert a duplicate row, since there is no unique constraint on (CompanyId, GlobalDonationId). | CLOSED (session 10) |
| ISSUE-25 | SESSION-11 | HIGH | BE | Manual Match modal "Search Donations" only matched ReceiptNumber / ReceiptSentTo / Note — user expected donor-name search ("229" → "User_229") which returned no results. The shared `GetGlobalDonations` handler's `searchTerm` predicate omitted `Contact.DisplayName`. Added Contact.DisplayName to the OR predicate; Contact is already Included so no new query overhead. | CLOSED (session 11) |
| ISSUE-26 | SESSION-11 | MED | FE | Auto-suggestion pill in the Unmatched panel had no direct action — to accept the BE's high-confidence suggestion the user had to open the Match modal, see the pre-selection, and click Match. Redesigned the suggestion card: pill flipped from amber to emerald (positive "go" signal vs. amber's "heads-up" semantic), added a white-on-emerald "Map to this donation" CTA inside the card that one-click calls `MatchPaymentTransaction` with the suggestion's GD id and refreshes the lists on success. Manual-match and Create-Donation buttons remain on the right as fallback paths. | CLOSED (session 11) |
| ISSUE-27 | SESSION-12 | HIGH | BE+FE | Match modal's donation picker called the shared `globalDonations` endpoint with no "exclude reconciled" filter, so already-mapped donations appeared in the search list. Clicking one would either fail at the BE guard ("already linked") or — in edge cases (different gateway, manual override) — accidentally re-map an already-reconciled donation to a different PT. Followed the Refund-screen precedent: added optional `excludeReconciled` arg to `GetGlobalDonationsQuery` + endpoint, filter in handler excludes GDs that have any active GOD with non-empty GatewayTransactionId, and created a dedicated `GLOBAL_DONATIONS_FOR_MATCH_PICKER_QUERY` for the modal that passes `excludeReconciled: true`. Helper text + empty-state updated to explain why some donations are hidden. | CLOSED (session 12) |
| ISSUE-28 | SESSION-13 | MED | BE | Original Session-10 "linked" definition was: GOD has non-empty `GatewayTransactionId`. User reported that setting GTI to a junk value (e.g. `"random-string"`) via SQL — which does NOT correspond to any real PaymentTransaction — still blocked the GD from suggestions. Tightened the definition across all four reconciliation handlers: a GOD counts as "linked" only when it has a non-empty GTI AND there exists a `PaymentTransaction` with the same `(CompanyId, PaymentGatewayId, GatewayTransactionId)`. Junk/orphan GODs are now treated the same as NULL/empty placeholders — they leave the GD eligible for matching and let the Match handler UPDATE the orphan in place rather than insert a duplicate. | CLOSED (session 13) |
| ISSUE-29 | SESSION-14 | HIGH | FE | `RespondToDisputeModal`'s `MASTERDATAS_QUERY` `advancedFilter` was missing the required `id` field on the outer filter AND on each rule — BE rejected the request with `"The required input field 'id' is missing."`, so the Decision dropdown never populated. Added `id: "0"` on the filter object and `id: "0"` on each rule, matching the canonical contact-create-modal advancedFilter shape. | CLOSED (session 14) |
| ISSUE-30 | SESSION-14 | MED | FE | Reconciliation modals (`RespondToDisputeModal`, `MatchTransactionModal`) used plain `DialogContent` + bare `DialogHeader` + default `DialogFooter` — inconsistent with the project's uniform modal pattern (gradient header with primary bg + icon container + title/subtitle, scrollable body with `flex-1 min-h-0 overflow-y-auto`, muted custom footer with outline Cancel + primary Submit). Refactored both modals to match `ContactCreateModal`'s contract: `DialogContent size="lg"` (dispute) / `size="2xl"` (match), icon-in-bordered-container header, title + descriptive subtitle, scrollable body, custom footer with sized action buttons (`h-8 sm:h-9`, `text-[11px] sm:text-xs`, primary shadow, `lucide:circle-x` Cancel icon, contextual primary icon). | CLOSED (session 14) |
| ISSUE-31 | SESSION-15 | MED | FE | `RespondToDisputeModal`'s Decision dropdown used the bare `Select` primitive (Radix portal at default `z-50`). Because the Dialog content sits at `z-9900+` via `BASE_DIALOG_Z_INDEX`, the option list rendered behind the modal and was unclickable. Replaced the bare `Select` with the project's canonical `FormSearchableSelect` (standalone mode — no RHF `control` prop) which delegates to `SearchableSelectRadix` → `PopoverContent` (`z-[10000]`), guaranteeing the options panel stacks above any modal level. Also moved the terminal-status filter (WON / LOST / ACCEPTED) from client-side JS post-filter to a server-side `advancedFilter` rule (`dataValue in "WON,LOST,ACCEPTED"`) so non-terminal statuses never reach the wire. | CLOSED (session 15) |
| ISSUE-32 | SESSION-16 | HIGH | FE | After successfully opening the dispute modal, Submit returned `"Transaction has no active dispute to respond to."` Root cause was NOT the new SearchableSelect — it was the drawer's dispute-section gate. The seed (`PaymentReconciliation-sqlscripts.sql:527`) and real gateway webhooks populate `DisputeStatusId` with the **"NONE"** MasterData row (not NULL) for non-disputed PTs. The drawer used `showDisputeSection = record?.disputeStatusId != null`, which was true for EVERY PT — so the secondary inner "Respond to Dispute" button at `reconciliation-detail-drawer.tsx:511` rendered on non-disputed transactions (gated only by `!disputeResolvedAt`, which is null for never-disputed PTs). Clicking it triggered the BE handler's first guard (`pt.DisputeStatus.DataValue == "NONE"`). Tightened the FE gate to mirror the BE's `isDisputed` rule: `disputeStatusId != null && disputeStatusCode !== "NONE"`. Now the dispute section / inner Respond button only appear when the transaction actually has an active or resolved dispute. | CLOSED (session 16) |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

> _[11 older session entries trimmed to save tokens — full history in git: `git log -p -- paymentreconciliation.md`. Most recent 5 kept below.]_

### Session 12 — 2026-05-11 — FIX — COMPLETED

- **Scope**: ISSUE-27 — Match modal's donation picker offered already-
  reconciled donations in its search results. User concern: clicking
  one would unexpectedly attempt to re-map a donation that's already
  linked to a different PT, either failing loud at the BE guard or, in
  pathological edge cases, mis-routing the link.

  Fix is purely a filter — donations already linked to a PT (any active
  GOD row with non-empty GatewayTransactionId) are now hidden from the
  picker. Followed the Screen #13 Refund precedent that ships
  `excludeRefunded` for the same reason on the same endpoint.

- **Files touched**:
  - BE: 2 modified —
    - `DonationBusiness/GlobalDonations/Queries/GetGlobalDonations.cs`
      — added optional `bool? excludeReconciled = false` param to the
      query record; handler appends a NOT EXISTS predicate that excludes
      GDs with any active GOD whose `GatewayTransactionId` is non-empty
      (same "linked" definition as Session 10 ISSUE-24).
    - `Base.API/EndPoints/Donation/Queries/GlobalDonationQueries.cs` —
      threaded the new arg through the `globalDonations` resolver. Param
      order: `excludeRefunded` first, `excludeReconciled` second.
  - FE: 2 modified —
    - `infrastructure/gql-queries/donation-queries/ReconciliationQuery.ts`
      — added new `GLOBAL_DONATIONS_FOR_MATCH_PICKER_QUERY` co-located
      with the other reconciliation queries. Mirrors the Refund picker
      pattern: minimal projection + screen-owned filter arg.
    - `page-components/crm/donation/reconciliation/match-transaction-modal.tsx`
      — swapped import from `GLOBALDONATIONS_QUERY` (shared, full
      projection, no filter) to the new local picker query with
      `excludeReconciled: true`. Updated the field-list helper text
      ("receipt #, donor name, note" — matching the BE searchable cols)
      and the empty-state copy to explain why donations may be hidden.
  - DB: None.

- **Deviations from spec**: None. The Spec §⑥ said the picker should
  show "candidate donations" — the current implementation is the
  unambiguous reading.

- **Known issues opened**: None.
- **Known issues closed**: ISSUE-27.
- **Still OPEN (10)**: ISSUE-5, 10, 11, 12, 13, 14, 15, 17, 18, 21.

- **Verification**: `dotnet build PeopleServe.sln` → 0 errors, 448
  warnings (all pre-existing — no new warnings introduced by this fix).
  Functional check deferred to user — (a) open Match modal on any PT,
  search by any term that matches both a reconciled GD and an unmatched
  GD → only the unmatched one should appear; (b) clear search → list
  should show only unmatched donations sorted by donation date desc.

- **Next step**: User retest the modal. If a power-user override is
  needed to map a PT onto an already-linked GD (e.g., dispute reassignment),
  raise a follow-up — current scope is the safe default.

### Session 13 — 2026-05-11 — FIX — COMPLETED

- **Scope**: ISSUE-28 — Session 10 introduced the rule "GOD with
  non-empty `GatewayTransactionId` = linked to a PT". The user reported
  that this rule was too loose: setting GTI to a junk value
  (e.g. `"random-string"`) via SQL — a value that does NOT correspond
  to any real PaymentTransaction — still blocked the GD from appearing
  as a suggestion. The intent was always "linked to a REAL payment",
  not "claims to be linked." Tightened the definition across every
  reconciliation handler:

  **A GOD counts as "linked" only when:**
  1. It is not soft-deleted, AND
  2. Its `GatewayTransactionId` is non-empty, AND
  3. There exists a `PaymentTransaction` with the same
     `(CompanyId, PaymentGatewayId, GatewayTransactionId)`.

  This makes junk/orphan GODs equivalent to NULL/empty placeholders —
  they leave the GD eligible for matching, and the Match handler
  UPDATEs the orphan in place rather than inserting a duplicate.

- **Files touched**:
  - BE: 4 modified —
    - `DonationBusiness/Reconciliation/GetAutoMatchSuggestionsQuery/GetAutoMatchSuggestions.cs`
      — added nested PT-EXISTS subquery to the candidate-GD filter.
    - `DonationBusiness/Reconciliation/MatchCommand/MatchPaymentTransaction.cs`
      — same tightening on the pre-match "already linked" guard AND on
      the placeholder-update lookup (so junk-GTI GODs are updated in
      place rather than refused).
    - `DonationBusiness/Reconciliation/RunAutoReconciliationCommand/RunAutoReconciliation.cs`
      — same tightening on the candidate-GD filter AND on the
      `placeholderGods` dictionary lookup.
    - `DonationBusiness/GlobalDonations/Queries/GetGlobalDonations.cs`
      — same tightening on the `excludeReconciled` filter so the Match
      modal picker also surfaces GDs whose GOD is junk/orphan.
  - FE: None.
  - DB: None.

- **Deviations from spec**: None — Spec §⑥ requires excluding
  already-matched donations from suggestions; "already matched" was
  always intended to mean "linked to a real PT", not "claims a link".
  This brings the implementation in line with the spec intent.

- **Performance note**: Each predicate now contains a nested EXISTS
  subquery (`PaymentTransactions` lookup keyed by `(PaymentGatewayId,
  GatewayTransactionId)`). On Postgres, the existing FK index on
  `PaymentTransactions.PaymentGatewayId` covers gateway filtering; the
  `(PaymentGatewayId, GatewayTransactionId)` pair is unique by webhook
  contract, so the subquery is bounded by O(1) per outer row. No new
  index needed for the demo dataset size; revisit if PT count grows
  beyond ~1M per tenant.

- **Known issues opened**: None.
- **Known issues closed**: ISSUE-28.
- **Still OPEN (10)**: ISSUE-5, 10, 11, 12, 13, 14, 15, 17, 18, 21.

### Session 14 — 2026-05-11 — FIX + UI — COMPLETED

- **Scope**: Two changes against the dispute / match modal flow:
  1. **ISSUE-29 (FIX)** — `Respond to Dispute` modal was firing the
     `MASTERDATAS_QUERY` for `DISPUTESTATUS` options without the
     required `id` field on the `advancedFilter` envelope or any of
     its rules. HotChocolate's request validator returned
     `"The required input field 'id' is missing."` and the Decision
     dropdown stayed empty. Added `id: "0"` to the outer filter object
     and `id: "0"` to the single `masterDataType.typeCode` rule —
     matching the canonical advancedFilter shape used across the
     `contact-create-modal` and every other modal that queries
     MasterDatas.
  2. **ISSUE-30 (UI)** — Reconciliation modals (`RespondToDisputeModal`,
     `MatchTransactionModal`) were using the bare `DialogHeader` +
     default `DialogFooter` shape — visually inconsistent with the
     reference `ContactCreateModal`. Refactored both to the uniform
     modal pattern:
     - `DialogContent size="lg"` (dispute, ~536px) /
       `size="2xl"` (match, ~720px — wider for the donation picker).
     - Header: gradient primary bg (default `DialogHeader`), icon
       container `w-7 h-7 rounded-md bg-white/15 border border-white/25`
       with a `DynamicIcon` (`ph:gavel` / `ph:link-bold`), title on
       top + descriptive subtitle below in
       `text-primary-foreground/70`.
     - Body: scrollable wrapper
       `flex-1 min-h-0 overflow-y-auto` containing
       `p-4 sm:p-6 space-y-4`.
     - Footer: custom div
       `shrink-0 px-4 sm:px-6 py-2.5 border-t border-border/50
       bg-muted/10 flex items-center justify-end gap-2`
       with sized action buttons (`h-8 sm:h-9`,
       `text-[11px] sm:text-xs`, primary shadow on submit,
       `lucide:circle-x` Cancel icon, `lucide:loader-2` spinner during
       save, contextual `ph:check-circle` / `ph:link-bold` Submit
       icon).

- **Files touched**:
  - BE: None.
  - FE: 2 modified —
    - `presentation/components/page-components/crm/donation/reconciliation/respond-to-dispute-modal.tsx`
      — advancedFilter `id` fix + uniform modal layout (header / body /
      footer) + DynamicIcon adoption + dropped now-unused
      `DialogDescription` / `DialogFooter` imports.
    - `presentation/components/page-components/crm/donation/reconciliation/match-transaction-modal.tsx`
      — uniform modal layout only (same header / body / footer shape)
      + DynamicIcon adoption + dropped now-unused
      `DialogDescription` / `DialogFooter` imports. No filter changes
      here (no advancedFilter on this modal's queries).
  - DB: None.

- **Deviations from spec**: None. Spec §⑥ never prescribed a specific
  modal chrome; this change just brings reconciliation modals in line
  with the rest of the app.

- **Notes**:
  - The `DialogHeader` component already paints the primary gradient
    + watermark pattern when `showGradient` is left at its default
    `true`. `DialogTitle` and `DialogDescription` already render in
    `text-primary-foreground` / `text-primary-foreground/70`, so the
    subtitle inside the title block uses those tokens directly.
  - Inline `Icon` from `@iconify/react` is still used for one-off
    content icons (`ph:upload` placeholder in dispute, `ph:funnel` /
    `ph:check-circle` / `ph:circle` / `ph:warning` inside the match
    picker rows) — they live inside body content, not chrome, so
    swapping to `DynamicIcon` was not necessary for the uniformity
    contract.

- **Known issues opened**: None.
- **Known issues closed**: ISSUE-29, ISSUE-30.
- **Still OPEN (10)**: ISSUE-5, 10, 11, 12, 13, 14, 15, 17, 18, 21.
- **Next step**: User retest — open Reconciliation screen, click
  **Respond to Dispute** on a disputed PT row, confirm Decision
  dropdown populates with WON/LOST/ACCEPTED, confirm header is the
  primary-gradient style with icon + subtitle and footer is the muted
  bg with styled Cancel/Submit. Then open **Match Transaction**, check
  the same chrome.

- **Verification**: `dotnet build Base.Application.csproj` → 0 errors,
  397 warnings (all pre-existing — none in the four modified files).
  Functional check deferred to user — repeat the SQL test from
  ISSUE-28: set `GatewayTransactionId` to a random non-empty string on
  the GOD row, refresh the screen / click Run Reconciliation → the PT
  should now appear as unmatched AND the suggestion pill should
  reappear with Score 100 (or whatever the original score was). The
  Match modal picker should also surface this GD in its search results.

- **Next step**: User retest the random-GTI SQL scenario. If passing,
  Screen #14 holds the canonical reconciliation semantics; future
  screens that consume GlobalOnlineDonation can use the same
  three-part "linked" definition.

### Session 15 — 2026-05-11 — FIX — COMPLETED

- **Scope**: ISSUE-31 — User reported the **Decision** dropdown in
  `RespondToDisputeModal` was rendering its options panel BEHIND the
  modal (unclickable). Root cause: the bare `Select` primitive from
  `common-components` uses Radix's default portal at `z-50`, but the
  Dialog content stack starts at `BASE_DIALOG_Z_INDEX = 9900` (level 1
  ≈ z-9900). `z-50` = literally `z-index: 50`, which is far below the
  modal — so the dropdown rendered underneath. User asked to swap to
  the canonical "common dropdown with searchable" component (which
  uses a `PopoverContent` at `z-[10000]`, designed to stack above any
  Dialog level).

  Replaced the bare `Select` with `FormSearchableSelect` (the
  same component used throughout `ContactCreateModal` and 30+ other
  forms), in **standalone mode** — i.e. no `control` prop, just
  `value` / `onChange` — because the dispute modal does not use
  react-hook-form. `FormSearchableSelect` internally renders
  `SearchableSelectRadix` → `PopoverContent` with
  `z-[10000]`, which correctly stacks above any modal in the project's
  dialog level system.

  While swapping, also moved the terminal-status filter from a
  client-side JS `Array.filter` post-step to a **server-side
  advancedFilter rule** so non-terminal statuses are never sent over
  the wire:

  ```
  advancedFilter: {
    id: "0",
    combinator: "and",
    rules: [
      { id: "0", field: "masterDataType.typeCode",
        operator: "=", value: "DISPUTESTATUS", dataType: "String" },
      { id: "1", field: "dataValue",
        operator: "in", value: "WON,LOST,ACCEPTED",
        dataType: "String" },
    ],
  }
  ```

  The `in` operator on advancedFilter is already supported and used
  in `api-multi-select` and the FlowDataTable filter builders, so this
  is a known-good shape.

- **Files touched**:
  - BE: None.
  - FE: 1 modified —
    - `presentation/components/page-components/crm/donation/reconciliation/respond-to-dispute-modal.tsx`
      — swapped the bare `Select` + manual `useQuery(MASTERDATAS_QUERY)`
      + client-side `TERMINAL_DISPUTE_VALUES` filter for a single
      `FormSearchableSelect` (standalone mode) with the server-side
      `in` filter shown above. Dropped unused imports
      (`Select*`, `useQuery`, `useMemo`). File-header doc-comment
      updated — "filtered client-side" line removed because filtering
      is now BE-only.
  - DB: None.

- **Deviations from spec**: None.

- **Notes**:
  - The submit handler still posts `newDisputeStatusId: decisionId`
    (a `masterDataId: number`), same wire shape as before — the only
    change is how the user picks that id. BE contract unchanged.
  - `MatchTransactionModal`'s donation picker is custom (it shows
    amount + receipt + donor in a 3-line row, with selection
    indicator), not a single-value dropdown, so it stays as the
    hand-built list. No equivalent z-index issue there because the
    list lives inside the modal body, not in a portal.
  - The `pageSize` default on `FormSearchableSelect` is 50, which is
    fine — there are only 3 terminal DISPUTESTATUS rows so one page
    covers it. Search is debounced (500ms, min 3 chars), but the user
    will rarely need to search 3 options.

- **Known issues opened**: None.
- **Known issues closed**: ISSUE-31.
- **Still OPEN (10)**: ISSUE-5, 10, 11, 12, 13, 14, 15, 17, 18, 21.
- **Next step**: User retest — open **Respond to Dispute** modal, click
  the Decision dropdown, confirm the options panel appears ABOVE the
  modal and lists exactly WON / LOST / ACCEPTED (in `orderBy` order).
  Select one, confirm `decisionId` populates and Submit is enabled
  once Response Text reaches 10 chars.

### Session 16 — 2026-05-11 — FIX — COMPLETED

- **Scope**: ISSUE-32 — User submitted the dispute response form and
  the BE returned `"Transaction has no active dispute to respond to."`
  At first glance this looked like a regression from the SearchableSelect
  swap in Session 15, but the failure is independent: the dropdown
  populated correctly and `newDisputeStatusId` was a real WON/LOST/ACCEPTED
  MasterDataId. The handler rejected because the **PT itself** had no
  active dispute.

  Root cause is in the drawer, not the modal:
  - `PaymentReconciliation-sqlscripts.sql:527` seeds non-disputed PTs
    with `DisputeStatusId = v_dispute_none_id` (pointing to the "NONE"
    MasterData row), NOT `NULL`. This matches how real gateways send
    webhooks — they always include a dispute-status enum, with NONE
    being the "no dispute" sentinel.
  - The drawer's gate was `showDisputeSection = record?.disputeStatusId
    != null`, which is true for EVERY PT in the system.
  - That meant the dispute section rendered on every transaction, and
    its inner "Respond to Dispute" button (`reconciliation-detail-drawer.tsx:511`,
    gated only by `!record.disputeResolvedAt`) appeared on never-disputed
    PTs too. Clicking it routed straight to the BE handler's first
    guard (`pt.DisputeStatus.DataValue == "NONE"`), which correctly
    rejected with the error the user saw.

  The fix is a one-liner: tighten the FE gate to mirror the BE's
  `isDisputed` rule.

  ```diff
  - const showDisputeSection = record?.disputeStatusId != null;
  + const showDisputeSection =
  +   record?.disputeStatusId != null &&
  +   record?.disputeStatusCode !== "NONE";
  ```

  After the fix:
  - Non-disputed PT (DataValue = NONE) → section hidden, button hidden,
    can't trigger the BE error.
  - Active dispute (DataValue = OPEN / UNDERREVIEW) → section shown,
    Respond button shown (because `disputeResolvedAt` is null).
  - Resolved dispute (DataValue = WON / LOST / ACCEPTED) → section
    still shown (history), Respond button hidden because the second
    inner gate is `!disputeResolvedAt`. The BE's second guard already
    blocks re-resolution.

- **Files touched**:
  - BE: None.
  - FE: 1 modified —
    - `presentation/components/page-components/crm/donation/reconciliation/reconciliation-detail-drawer.tsx`
      — tightened `showDisputeSection` (line ~158) to require
      `disputeStatusCode !== "NONE"`. `disputeStatusCode` is already
      part of the GraphQL projection (`ReconciliationQuery.ts:266`)
      and the FE DTO (`ReconciliationDto.ts`), so no other plumbing
      changes were needed.
  - DB: None.

- **Deviations from spec**: None. Spec §④ stipulates "dispute
  precedence" only when there's an actual dispute (DataValue !=
  NONE). The seed's choice to populate NONE rather than NULL is a
  storage decision; the screen contract was always "show dispute UI
  when there is a dispute."

- **Cross-references**: The same `disputeStatusCode !== "NONE"` rule
  is already used in `reconciliation-details-table.tsx:186` via
  `matchStatusCode === "DISPUTED"`, which is derived BE-side from the
  same rule. The drawer was the only place still using the looser
  `!= null` gate.

- **Known issues opened**: None.
- **Known issues closed**: ISSUE-32.
- **Still OPEN (10)**: ISSUE-5, 10, 11, 12, 13, 14, 15, 17, 18, 21.
- **Next step**: User retest — open the drawer on a non-disputed PT,
  confirm the Dispute section is no longer visible. Then open the
  drawer on a row whose `matchStatusCode === "DISPUTED"`, click
  **Respond to Dispute** in either the header or the dispute section,
  pick a Decision from the dropdown, fill 10+ chars of response, and
  Submit. Should now succeed with the toast `"Dispute response
  submitted"` instead of the BE rejection.
