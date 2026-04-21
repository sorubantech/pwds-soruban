---
screen: Refund
registry_id: 13
module: Fundraising
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
- [x] HTML mockup analyzed (3 KPI cards + 10-col grid + New-Refund modal + Approval Confirmation modal)
- [x] Existing code reviewed (BE has NO Refund entity; FE is 5-line stub)
- [x] Business rules + workflow extracted (5-state machine: Pending → Approved → Processing → Refunded | Rejected)
- [x] FK targets resolved (GlobalDonation, Contact via GD, MasterData REFUNDSTATUS+REFUNDREASON, Staff)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM + DETAIL layouts + 2 transition modals specified)
- [ ] User Approval received
- [ ] Backend code generated (FULL: 18 new files — entity + EF + schemas + 4 CRUD + 4 workflow commands + 3 queries + endpoints + migration)
- [ ] Backend wiring complete (IDonationDbContext, DonationDbContext, DecoratorDonationModules, DonationMappings, MasterData seed, GlobalUsing)
- [ ] Frontend code generated (NEW: 21 files — DTO, GQL Q+M, page config, router, index-page Variant B, view-page FORM, Zustand store, detail-drawer/page, approval-modal, rejection-modal, widgets, filter chips, advanced filters, 5 cell renderers)
- [ ] Frontend wiring complete (entity-operations, operations-config, 3 column-type registries, shared-cell-renderers barrel, sidebar, route stub overwrite)
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW + 5 REFUNDSTATUS + 6 REFUNDREASON MasterData rows)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (refund migration applied)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/donation/refund`
- [ ] Grid loads with 10 columns + 3 KPI widgets above (Variant B)
- [ ] `?mode=new` — empty FORM renders 5 sections (Original Donation Picker, Refund Type, Refund Amount, Reason, Notes)
- [ ] `?mode=edit&id=X` — FORM loads pre-filled (only allowed if status=PEN)
- [ ] `?mode=read&id=X` — DETAIL layout renders (Summary card + Original Donation card + Approval Trail + Donor card + Timeline)
- [ ] Approval Confirmation Modal opens from row Approve action; Confirm transitions PEN→APR (then auto APR→PRO if gateway placeholder enabled)
- [ ] Reject Modal opens from row Reject action; rejection reason required; transitions PEN→REJ
- [ ] Donation Picker (in form) searches GlobalDonations by receipt# / donor name; selecting populates donation-preview card with Receipt#, Donor, Amount, Date, Gateway
- [ ] Refund Amount auto-fills with donation amount on Full type; editable on Partial type
- [ ] Validation: Refund Amount ≤ original donation amount AND > 0
- [ ] Filter chips: All / Pending / Approved/Processing / Refunded / Rejected — counts match KPI widgets
- [ ] Workflow guards: Edit disabled if status≠PEN; Delete disabled if status≠PEN; Approve only if PEN; Reject only if PEN
- [ ] Donor name → navigates to `/[lang]/crm/contact/contact?mode=read&id={contactId}`
- [ ] Original Donation receipt# → navigates to `/[lang]/crm/donation/globaldonation?mode=read&id={globalDonationId}`
- [ ] Service placeholder buttons (Process via Gateway / Print Receipt) render with toast
- [ ] DB Seed — REFUND menu visible in sidebar under CRM_DONATION @ OrderBy=8
- [ ] REFUNDSTATUS rows seeded (PEN/APR/PRO/REF/REJ); REFUNDREASON rows seeded (DOR/DUP/FRA/EVT/ACC/OTH)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **Refund Management** (aka "Refund Queue")
Module: Fundraising
Schema: `fund`
Group: `DonationModels` (entity group), `DonationSchemas` (DTOs), `DonationBusiness` (commands/queries), `Donation` (endpoints folder)

Business: This screen is the finance-office reverse-payment workflow tracker. When a donor requests a refund (donor request, duplicate charge, card fraud, accidental, event cancelled), staff capture a Refund row linked to the original `GlobalDonation`. Refunds pass through a **5-state lifecycle** — Pending Approval (just submitted, awaiting finance manager) → Approved (finance approved) → Processing (sent to payment gateway, awaiting confirmation) → Refunded (gateway confirmed, terminal success) | Rejected (denied, terminal alternative). Finance staff use this screen to: (a) submit new refund requests against existing donations, (b) triage the pending-approval queue, (c) approve/reject with audit trail, (d) track in-flight gateway processing, (e) confirm completed refunds and surface them in donor history. This screen's read-mode detail view shows the full reverse-money trail: original donation context, refund details, who approved/rejected, when each transition happened, and the gateway refund transaction id.

Canonical references to copy from:
- **Cheque Donation #6** (`prompts/chequedonation.md`, PROMPT_READY 2026-04-20) — sibling FLOW under same Module/Group/Parent-menu, multi-state workflow with transition modals, KPI widgets via Summary query, 4-state status badges via MasterData. Refund mirrors its workflow-modal architecture (Approve/Reject modals replace Deposit/Clearance modals).
- **In-Kind Donation #7** (`prompts/inkinddonation.md`, COMPLETED 2026-04-19) — for FLOW + Variant B + Zustand + view-page reference patterns, file manifest, GraphQL contract shape.
- **Pledge #12** (`prompts/pledge.md`, PROMPT_READY 2026-04-20) — for full-page form replacing modal pattern (mockup shows modal, code uses full view-page per FLOW convention), drawer detail view with approval trail.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from HTML mockup (3 KPI cards + grid columns + New-Refund modal + Approval Confirmation modal). Audit columns inherited.
> **CompanyId is NOT a field** — comes from HttpContext.

Table: `fund."Refunds"` — **NEW** (create migration `Add_Refund.cs`)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| RefundId | int | — | PK | — | Primary key |
| RefundCode | string | 50 | YES | — | Auto-generated `REF-{NNNN}` per Company; unique filtered index per Company per IsActive=true |
| GlobalDonationId | int | — | YES | fund.GlobalDonations | FK to original donation (donor + amount + currency + payment context live on parent) |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (set from HttpContext) |
| RefundTypeCode | string | 10 | YES | — | Enum string: `FULL` \| `PARTIAL` (no MasterData; small fixed set, badge color drives UI) |
| RefundAmount | decimal(18,2) | — | YES | — | Must be > 0 AND ≤ GlobalDonation.DonationAmount |
| RefundReasonId | int | — | YES | corg.MasterDatas | TypeCode=REFUNDREASON → {DOR, DUP, FRA, EVT, ACC, OTH} (6 seed rows) |
| RefundReasonNote | string? | 500 | NO | — | Free-text "Other reason" detail when RefundReason.DataCode=OTH |
| RefundMethodLabel | string? | 200 | NO | — | Auto-populated from GD payment context, e.g., "Stripe (Visa ****1234) — Original payment". Display-only; not a strict FK to PaymentMode (the actual gateway integration is SERVICE_PLACEHOLDER). |
| RefundStatusId | int | — | YES | corg.MasterDatas | TypeCode=REFUNDSTATUS → {PEN, APR, PRO, REF, REJ}; defaults to PEN on Create. |
| RefundRequestedDate | DateTime | — | YES | — | Defaults to today. Date the refund was logged. |
| ApprovedBy | int? | — | NO | corg.Staffs | Set on PEN→APR transition |
| ApprovedDate | DateTime? | — | NO | — | Set on PEN→APR transition |
| ApprovalNote | string? | 1000 | NO | — | Optional approver note (mockup Approval Confirmation modal "Note" textarea) |
| RejectedBy | int? | — | NO | corg.Staffs | Set on PEN→REJ transition |
| RejectedDate | DateTime? | — | NO | — | Set on PEN→REJ transition |
| RejectionReason | string? | 1000 | YES-on-reject | — | Required when transitioning to REJ; surfaces on detail page |
| ProcessingStartedDate | DateTime? | — | NO | — | Set on APR→PRO transition (gateway call placeholder) |
| RefundedDate | DateTime? | — | NO | — | Set on PRO→REF transition (terminal success) |
| GatewayTransactionRefundId | string? | 200 | NO | — | Refund-side txn id returned by gateway (when SERVICE_PLACEHOLDER is replaced). Until then, allow manual entry on PRO→REF transition. |
| AdditionalNotes | string? | 2000 | NO | — | Form "Additional Notes" textarea — context for the refund |

**Inherited from `Entity` base**: IsActive, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, PKReferenceId.

**No child entities** — single-row aggregate; all status transitions update fields on the row itself. (No RefundLineItem yet — Partial refund is a single amount, not a per-line breakdown.)

**Parent entity `GlobalDonation` fields the screen projects to grid/form/detail** (do NOT duplicate — JOIN-project):

| GD Field | Exposed As | Used Where |
|----------|-----------|------------|
| ReceiptNumber | originalReceiptNumber | grid "Original Donation" link, donation-preview card, detail Original-Donation card |
| ContactId | contactId | detail Donor card link, anonymous-flag derivation |
| Contact.ContactName | contactName | grid "Donor" column, donation-preview card, detail Donor card |
| Contact.ContactCode | contactCode | detail Donor card |
| (derived) IsAnonymous | isAnonymous | grid renderer (when ContactId is null OR Contact has IsAnonymous flag, render as "Anonymous" gray text) |
| DonationAmount | originalDonationAmount | grid "Original Amt" column, donation-preview card, detail Original-Donation card |
| Currency.CurrencyCode | currencyCode | grid (currency formatting), donation-preview card |
| Currency.CurrencySymbol | currencySymbol | grid amount renderer |
| DonationDate | originalDonationDate | donation-preview card, detail Original-Donation card |
| DonationMode.DataName | paymentModeName | donation-preview "Gateway" line ("Stripe", "Cash", "Cheque") |
| (derived from GD payment metadata) | paymentMaskedDetails | donation-preview "Visa ****1234" (best-effort; null if mode is Cash/Cheque) |

> The GD payment-context derivation is approximate. For online card donations linked to a `PaymentTransaction`, surface the gateway+masked-pan. For cash/cheque, leave null and show only `paymentModeName`. See ISSUE-3.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelectV2 queries)

All FK target entities pre-exist. Verified paths:

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| GlobalDonationId | GlobalDonation | [GlobalDonation.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/GlobalDonation.cs) | `globalDonations` (existing in `GlobalDonationQueries.cs`) | DropDownLabel + ContactName + ReceiptNumber composite | `GlobalDonationResponseDto` |
| (via GD) ContactId | Contact | [Contact.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/Contact.cs) | `contacts` / `GetAllContactList` | ContactName | `ContactResponseDto` |
| (via GD) CurrencyId | Currency | [Currency.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/CorgModels/Currency.cs) | `GetAllCurrencyList` / `currencies` | CurrencyCode | `CurrencyResponseDto` |
| RefundReasonId | MasterData | [MasterData.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/CorgModels/MasterData.cs) | `masterDataListByTypeCode(typeCode: "REFUNDREASON")` | DataName | `MasterDataResponseDto` |
| RefundStatusId | MasterData | same as above | `masterDataListByTypeCode(typeCode: "REFUNDSTATUS")` | DataName | `MasterDataResponseDto` |
| ApprovedBy / RejectedBy | Staff | [Staff.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/CorgModels/Staff.cs) | `staffs` / `GetAllStaffList` | StaffName | `StaffResponseDto` |

**Donation Picker UX**: The "Original Donation" field is NOT a plain ApiSelectV2 dropdown. It's a **search-as-you-type combobox** that queries `globalDonations` with searchText filtering on ReceiptNumber + Contact.ContactName + Contact.ContactCode. On selection, the form populates a **Donation Preview Card** below the field with Receipt#, Donor, Amount, Date, Gateway. (See §⑥ Form Layout — special widget "Donation Picker with Preview".)

> **Important — additional GraphQL filter args needed on `globalDonations`**: the Refund form needs to filter out donations that already have a Refund attached (or that are Voided/Rejected upstream). Add `excludeRefunded: bool? = false` arg to `GetAllGlobalDonationHandler` — when true, filters out GDs where any non-deleted Refund exists (subquery NOT EXISTS). See ISSUE-9.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

### Workflow (5-state machine on RefundStatusId MasterData code)

```
                +----------------+   ApproveRefund cmd     +-----------------+
   +Add  →      |   PEN          | ──────────────────────→ |   APR           |
   (auto-PEN)   | (Pending       |                         | (Approved)      |
                |  Approval)     | ──┐                     +--------+--------+
                +-------+--------+   │                              │
                        │            │ RejectRefund cmd             │ ProcessRefund cmd
                        │            │ (rejection reason required)  │ (SERVICE_PLACEHOLDER:
                        │            │                              │  gateway call)
                        │            ▼                              ▼
                        │      +-----------+               +------------------+
                        │      |   REJ     |               |   PRO            |
                        │      |(Rejected) |               | (Processing —    |
                        │      | terminal  |               |  awaiting gateway)|
                        │      +-----------+               +--------+---------+
                        │                                           │
                        │   (Edit / Delete only allowed in PEN)     │ CompleteRefund cmd
                        │                                           │ (gateway confirmed
                        │                                           │  OR manual override)
                        │                                           ▼
                        │                                    +-----------+
                        │                                    |   REF     |
                        │                                    | (Refunded)|
                        │                                    | terminal  |
                        │                                    +-----------+
                        ▼
              (Edit / Delete commands)
```

**States** (MasterData TypeCode=REFUNDSTATUS — must be seeded):
- `PEN` — Pending Approval — newly submitted, awaiting finance approval (yellow/amber badge — `#ca8a04`)
- `APR` — Approved — finance approved, ready to process (purple badge — `#7c3aed`)
- `PRO` — Processing — sent to gateway, awaiting confirmation (blue badge — `#2563eb`)
- `REF` — Refunded — gateway confirmed; terminal success (green badge — `#16a34a`)
- `REJ` — Rejected — denied; terminal alternate (red badge — `#dc2626`)

### Reasons (MasterData TypeCode=REFUNDREASON — must be seeded; matches mockup dropdown)
- `DOR` — Donor Request
- `DUP` — Duplicate Charge
- `FRA` — Card Fraud
- `EVT` — Event Cancelled
- `ACC` — Accidental
- `OTH` — Other (form requires `RefundReasonNote` when this is picked)

### Uniqueness Rules
- `RefundCode` unique per Company per IsActive=true (filtered index — same pattern as ChequeNo)
- **At most ONE non-deleted Refund per GlobalDonationId** — enforced in `CreateRefundValidator` ("Refund already exists for this donation" error). Keeps the GD ↔ Refund relationship 1:0..1.
- **(Future enhancement, NOT in this build)**: support multiple partial refunds against one donation. For now, enforce 1:0..1.

### Required Field Rules (by mode/transition)

| Mode / Transition | Required Fields |
|-------------------|-----------------|
| Create (auto-PEN) | GlobalDonationId, RefundTypeCode, RefundAmount, RefundReasonId, RefundRequestedDate (defaults today), RefundStatusId (auto-set to PEN). RefundReasonNote required IF RefundReason.DataCode=OTH. |
| Update (only if status=PEN) | Same as Create — all fields editable while PEN |
| Approve (PEN→APR) | (no body fields required; ApprovalNote optional). Auto-sets ApprovedBy=current user, ApprovedDate=now. |
| Reject (PEN→REJ) | RejectionReason **required**. Auto-sets RejectedBy=current user, RejectedDate=now. |
| Process (APR→PRO) | (no body fields). Auto-sets ProcessingStartedDate=now. SERVICE_PLACEHOLDER call to gateway — see ISSUE-1. |
| Complete (PRO→REF) | RefundedDate (defaults now), GatewayTransactionRefundId optional but recommended. |

### Conditional Rules
- If RefundType=`FULL` → RefundAmount auto-set to GlobalDonation.DonationAmount AND becomes readonly in form
- If RefundType=`PARTIAL` → RefundAmount editable; validator: > 0 AND ≤ GlobalDonation.DonationAmount AND ≠ DonationAmount (else use FULL)
- If RefundReason.DataCode=`OTH` → RefundReasonNote becomes required (form validation + handler validator)
- ApprovedBy/Date and RejectedBy/Date are mutually exclusive — handler enforces "row cannot have both"
- Edit form: all fields locked when status ≠ PEN (read-only fieldset wrap)
- Delete: only allowed when status = PEN. Else `BadRequestException("Cannot delete a refund that has been approved/rejected/processed.")`

### Business Logic / Side Effects
- On Create: handler resolves PEN MasterData ID by Code lookup; sets RefundStatusId; auto-generates RefundCode = next `REF-{NNNN}` per Company.
- On Create: handler validates "no existing non-deleted Refund for this GlobalDonationId".
- On Approve: status flips PEN→APR; sets ApprovedBy from `IUserContext.UserId`, ApprovedDate=now, ApprovalNote from cmd.
- On Reject: status flips PEN→REJ; sets RejectedBy/Date, RejectionReason; **does NOT** modify the original GlobalDonation (GD remains intact — refund was just denied).
- On Process: status flips APR→PRO; sets ProcessingStartedDate=now. **SERVICE_PLACEHOLDER**: real impl would call PaymentService.RefundAsync(); for now, the handler just flips status (no gateway call).
- On Complete: status flips PRO→REF; sets RefundedDate, GatewayTransactionRefundId. **Important downstream effect**: when REF, the parent GlobalDonation should be flagged as refunded — but the GD entity does NOT have a RefundedAmount/IsRefunded column today. See ISSUE-2.
- All transitions require status to match prior state (return `BadRequestException` if mismatch).
- Auto-progression: After successful Approve, the FE can offer "Process Now" button on the detail page (one-click APR→PRO) — but they remain separate commands so audit is clean.

### Workflow Permissions (informational only — capabilities granted to BUSINESSADMIN role per memory directive)
- All transitions are gated by the `MODIFY` capability on the REFUND menu (no separate Approve/Reject/Process capabilities). Future enhancement: split into APPROVE/REJECT/PROCESS capabilities for finance-vs-staff segregation.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED.

**Screen Type**: FLOW
**Type Classification**: Transactional workflow with FlowDataTable index + 3 KPI widgets + 5-state workflow + 2 transition modals (Approve / Reject) + 3-mode view-page
**Reason**: (a) +Add navigates to full-page form (URL `?mode=new`), per FLOW convention — mockup shows modal but Pledge #12 / ChequeDonation #6 / DonationInKind #7 sibling screens all rebuild as full-page forms; (b) detail view (`?mode=read`) is a multi-card layout DIFFERENT from the form (donor card + original donation card + approval trail + timeline); (c) workflow requires dedicated transition commands not via Update; (d) sibling pattern under same Module/Group/Parent-menu.

**Backend Patterns Required:**
- [x] Standard CRUD (Create/Update/Delete/Toggle — NEW)
- [x] Tenant scoping (CompanyId from HttpContext on all writes/reads)
- [x] Multi-FK validation — GlobalDonation, MasterData × 2, Staff × 2 (ApprovedBy/RejectedBy nullable)
- [x] Unique validation — RefundCode per Company; one Refund per GlobalDonation
- [x] **Workflow commands (NEW — 4 needed)**: `ApproveRefund`, `RejectRefund`, `ProcessRefund`, `CompleteRefund`
- [x] **Summary query (NEW)**: `GetRefundSummary` — 3 count+sum pairs matching mockup KPI widgets (Pending count+amount, Processed-this-month count+amount, Refunded-YTD count+amount)
- [x] **Auto-code generator** for RefundCode (`REF-{NNNN}` per Company — same pattern as PledgeCode in Pledge #12, RecurringDonationScheduleCode in #8)
- [x] Custom business rule validators — Edit-guard (status=PEN), Delete-guard (status=PEN), transition-guards (status must match prior state), one-Refund-per-GD rule, RefundAmount ≤ GD.DonationAmount, OTH-reason note required
- [x] Extension to `GetAllGlobalDonationHandler` — add `excludeRefunded: bool` arg (NOT EXISTS subquery on Refund table) — feeds the form's Donation Picker
- [ ] No nested child creation (Refund is a single-row aggregate)
- [ ] No file upload (no attachments in mockup)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid — Variant B with `<DataTableContainer showHeader={false}>`)
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (FORM layout — 4 sections: Original Donation Picker → Refund Type → Refund Amount/Reason → Method/Notes)
- [x] Zustand store (`refund-store.ts` — viewMode, modals state, filter chips, advanced filters, bulk-select TBD)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back + Save)
- [x] **Approval Confirmation Modal** (Zustand-triggered — `refund-approval-modal.tsx`; mirrors mockup's `#approveRefundModal` with refund summary + Approved By + Note + warning + Confirm Refund)
- [x] **Rejection Modal** (Zustand-triggered — `refund-rejection-modal.tsx`; rejection reason required textarea)
- [x] **Donation Picker with Preview Card** — combobox + auto-populated preview card below
- [x] **Header contextual action bar** on detail page — buttons depend on status (PEN: Approve / Reject; APR: Process Refund [SERVICE_PLACEHOLDER]; PRO: Mark Complete; REF: Print Receipt; REJ: View only)
- [x] Summary cards / count widgets — 3 KPI cards (Pending Approval / Processed This Month / Total Refunded YTD)
- [x] Filter chips: All / Pending / In Progress (APR+PRO grouped) / Refunded / Rejected — 5 chips
- [x] Variant B layout (`<ScreenHeader>` + widgets + `<DataTableContainer showHeader={false}>`)
- [x] **Detail layout = right-side drawer 600px** — sibling to Pledge #12 (720px) and RecurringDonationSchedule #8 (460px). Mockup shows confirmation modal but per Pledge convention, detail page is a slide-in drawer over the grid. Variant: drawer pattern.
  > **Alternative**: a full detail PAGE (not drawer) — see ISSUE-12. Keep drawer as default per Pledge precedent unless solution-resolver flips it.
- [x] No grid aggregation columns (all aggregations are KPI widgets)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from [refund-management.html](html_mockup_screens/screens/fundraising/refund-management.html).
> **This screen has TWO custom modals + ONE custom donation-picker widget** beyond the standard FLOW skeleton. Spec them precisely.

### Grid/List View

**Display Mode**: `table` (no card-grid variant — refunds are dense transactional rows, table is correct)

**Grid Layout Variant**: `widgets-above-grid` → FE Dev uses **Variant B** mandatory. ScreenHeader + 3 KPI widgets + filter chips + `<DataTableContainer showHeader={false}>`.

### Primary Index Page Layout (Variant B)

```
┌────────────────────────────────────────────────────────────────────────┐
│ <ScreenHeader title="Refund Management"                                │
│                subtitle="Process and track donation refunds">          │
│  actions: [Back, "+ New Refund Request" primary]                       │
└────────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────────┐
│ [KPI: Pending Approval (count + sum)]                                  │
│ [KPI: Processed This Month (count + sum)]                              │
│ [KPI: Total Refunded YTD (sum + count)]                                │
└────────────────────────────────────────────────────────────────────────┘
┌─ Filter Chips ──────────────────────────────────────────────────────────┐
│  [All] [Pending] [In Progress] [Refunded] [Rejected]                   │
└────────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────────┐
│  <DataTableContainer showHeader={false}> with 10 columns               │
└────────────────────────────────────────────────────────────────────────┘
```

### KPI Widgets (Section §⑥ — Page Widgets & Summary Cards)

**Widgets**: 3 widgets (per mockup `.stats-grid` cards)

| # | Widget Title | Value Source | Display Type | Sub-line | Position | Tone |
|---|-------------|-------------|--------------|----------|----------|------|
| 1 | Pending Approval | `summary.pendingCount` | number | `summary.pendingTotal` formatted as currency | Col 1 | warning (yellow icon `phosphor:hourglass-medium`) |
| 2 | Processed This Month | `summary.processedThisMonthCount` | number | `summary.processedThisMonthTotal` formatted as currency | Col 2 | success (green icon `phosphor:check`) |
| 3 | Total Refunded (YTD) | `summary.refundedYtdTotal` formatted as currency | currency | `{summary.refundedYtdCount} refunds` | Col 3 | info (blue icon `phosphor:arrow-u-up-left`) |

**Summary GQL Query**: `GetRefundSummary` (NEW — must be created)
- Returns: `RefundSummaryDto` with `pendingCount`, `pendingTotal`, `processedThisMonthCount`, `processedThisMonthTotal`, `refundedYtdCount`, `refundedYtdTotal`. All sums in **base currency converted via GD.BaseCurrencyAmount × refund/donation ratio**. (Multi-currency note in ISSUE-7.)
- Tenant-scoped via HttpContext CompanyId
- "This Month" = current calendar month (server tz); "YTD" = current calendar year
- Counts use `RefundStatus.DataCode` join; exclude IsDeleted rows

### Filter Chips (NEW component for this screen — `refund-filter-chips.tsx`)

| # | Chip Label | Filter Predicate | Count Badge |
|---|-----------|------------------|-------------|
| 1 | All | (no filter) | total non-deleted |
| 2 | Pending | RefundStatus.DataCode = `PEN` | summary.pendingCount |
| 3 | In Progress | RefundStatus.DataCode IN (`APR`, `PRO`) | summary.approvedCount + summary.processingCount |
| 4 | Refunded | RefundStatus.DataCode = `REF` | summary.refundedCount |
| 5 | Rejected | RefundStatus.DataCode = `REJ` | summary.rejectedCount |

> Chip → pushes `refundStatusCode` advanced filter into FlowDataTable advancedFilter payload; chip-1 clears it. Pattern: same as Family #20 ISSUE-13 (top-level GQL arg preferred — see ISSUE-10).

### Grid Columns (in display order — matches mockup table)

| # | Column Header | Field Key | Display Type | Width | Sortable | Renderer | Notes |
|---|--------------|-----------|--------------|-------|----------|----------|-------|
| 1 | Refund ID | refundCode | text-bold | 100px | YES | `text-bold` | Click row → drawer/detail |
| 2 | Original Donation | originalReceiptNumber | link | 130px | YES | `original-donation-link` | NEW renderer — accent-color text-link → `/[lang]/crm/donation/globaldonation?mode=read&id={globalDonationId}` |
| 3 | Donor | contactName | text+link | auto | YES | `donor-link` | REUSE from ChequeDonation #6 (planned) — accent-color text-link → contact detail; renders "Anonymous" gray italic if isAnonymous |
| 4 | Original Amt | originalDonationAmount | currency | 110px | YES | `currency-amount` | REUSE — uses GD.Currency.CurrencyCode for symbol; right-aligned |
| 5 | Refund Amt | refundAmount | currency-emphasized | 110px | YES | `refund-amount-cell` | NEW renderer — bold + status-tinted color: red for Full, amber for Partial; right-aligned |
| 6 | Type | refundTypeCode | badge | 80px | YES | `refund-type-badge` | NEW renderer — `FULL` → red badge "Full", `PARTIAL` → amber badge "Partial" |
| 7 | Reason | refundReasonName | text-tag | 130px | NO | `reason-tag` | NEW renderer — gray pill matching mockup `.reason-tag` |
| 8 | Requested | refundRequestedDate | date-relative | 90px | YES | `DateOnlyPreview` | REUSE; format "Apr 8" for current year, "Apr 8 '25" cross-year |
| 9 | Status | refundStatusCode | badge-with-icon | 170px | YES | `refund-status-badge` | NEW renderer — pill with status-specific color+icon. PEN: yellow + hourglass-half, APR: purple + thumbs-up, PRO: blue + spinner (animated), REF: green + check-circle (with completion date suffix "Refunded (Mar 30)"), REJ: red + x-circle |
| 10 | Actions | — | actions | 220px | NO | Row actions cell | Status-conditional buttons — see below |

**Row Actions Cell** (NEW inline component or per-row composite renderer):
| Status | Buttons |
|--------|---------|
| PEN | `[Approve]` (green outline → opens Approval Modal), `[Reject]` (red outline → opens Rejection Modal), `[View]` (gray → drawer/detail) |
| APR | `[Process]` (blue → ProcessRefund cmd; SERVICE_PLACEHOLDER toast), `[View]` |
| PRO | `[Mark Complete]` (green → opens Complete Modal — see below), `[View]` |
| REF | `[View]` only |
| REJ | `[View]` only |

**Renderers to register** in all 3 column registries (advanced, basic, flow) + `shared-cell-renderers.ts` barrel:
- `original-donation-link` (NEW)
- `donor-link` (NEW or REUSE if ChequeDonation #6 has shipped first)
- `currency-amount` (REUSE if exists; else create — same as ChequeDonation §⑥)
- `refund-amount-cell` (NEW — bold + status-tinted color)
- `refund-type-badge` (NEW)
- `reason-tag` (NEW — simple gray pill)
- `refund-status-badge` (NEW — pill with icon, includes completion date suffix for REF rows)
- `text-bold` (REUSE)
- `DateOnlyPreview` (REUSE)

**Search/Filter Fields** (text search in toolbar): refundCode, originalReceiptNumber, contactName, refundReasonName.
**Advanced Filter Panel** (toolbar `Filter` button → side panel — sibling pattern to Pledge #12):
- refundStatusId (multi-select MasterData REFUNDSTATUS)
- refundReasonId (multi-select MasterData REFUNDREASON)
- refundTypeCode (multi-select Full/Partial)
- refundRequestedDate range (from/to)
- refundedDate range (from/to)
- amountMin / amountMax (refundAmount range)

**Grid Actions** (top toolbar): `+ New Refund Request` (primary, navigates `?mode=new`). No bulk actions in MVP.

**Row Click**: Opens **right-side drawer** at 600px width (DETAIL layout — see below). Per Pledge #12 precedent. Alternative: navigate `?mode=read&id={refundId}` to full detail page — see ISSUE-12.

---

### FLOW View-Page — 3 URL Modes

#### LAYOUT 1: FORM (mode=new & mode=edit)

> Full-page form. Mockup ships a modal (`#newRefundModal`); we rebuild as a full view-page per FLOW convention (Pledge #12 precedent). The form replicates the modal sections + adds an explicit Save flow.

**Page Header**: `<FlowFormPageHeader title="{mode=new ? 'New Refund Request' : 'Edit Refund ' + refundCode}" subtitle="Process and track donation refunds" onBack onSave>` + unsaved changes dialog. Save button label: "Submit Refund Request" (mode=new), "Update Refund" (mode=edit).

**Section Container Type**: cards (not accordion) — 4 sections stacked vertically, each in a `<Card>` with bold title bar. Not collapsible. (Form is short — no accordion needed.)

**Form Sections** (in display order):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|---------------|--------|----------|--------|
| 1 | `phosphor:magnifying-glass` | Original Donation | full-width | expanded | globalDonationId (donation-picker-with-preview), [donation preview card auto-displays below picker once selected] |
| 2 | `phosphor:rotate-left` | Refund Details | 2-column | expanded | refundTypeCode (radio group: Full / Partial), refundAmount (currency input — auto-set+readonly when Full, editable when Partial), refundReasonId (ApiSelectV2), refundReasonNote (textarea — appears only when reason=OTH) |
| 3 | `phosphor:credit-card` | Refund Method | full-width | expanded | refundMethodLabel (readonly text — auto-populated from GD payment context, "Stripe (Visa ****1234) — Original payment", or fallback "Same as original payment method") |
| 4 | `phosphor:notepad` | Additional Notes | full-width | expanded | additionalNotes (textarea, 3 rows) |

**Field Widget Mapping**:

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| globalDonationId | 1 | **Donation Picker (custom)** | "Search by receipt # or donor name..." | required | See "Donation Picker with Preview" below |
| refundTypeCode | 2 | radio-group inline | — | required | 2 options: Full Refund / Partial Refund. Default Full. |
| refundAmount | 2 | number-currency with prefix | "0.00" | required, > 0, ≤ GD.DonationAmount, ≠ GD.DonationAmount when Partial | Monospace, 2-decimal. Auto-set to GD.DonationAmount and readonly when Full. Currency symbol prefix from GD.Currency.CurrencySymbol. Hint text below: "Full donation amount pre-filled. Edit for partial refund." (matches mockup) |
| refundReasonId | 2 | ApiSelectV2 | "Select reason" | required | Query: `masterDataListByTypeCode(typeCode: "REFUNDREASON")`. Display: DataName. |
| refundReasonNote | 2 | textarea (2 rows) | "Specify reason" | required IF reason=OTH | Conditional visibility: only when reason.dataCode = OTH |
| refundMethodLabel | 3 | text (readonly, gray-bg) | (auto-populated) | — | Display-only string built from GD payment context. If unable to derive, default: "Same as original payment method" |
| additionalNotes | 4 | textarea (3 rows) | "Add any context for the refund..." | optional, max 2000 | — |

**Special Form Widget — Donation Picker with Preview** (NEW component `refund-donation-picker.tsx`):

```
┌─────────────────────────────────────────────────────────┐
│ Original Donation *                                     │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [Search by receipt # or donor name...] (combobox)   │ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌─ donation-preview (only when selected) ──────────────┐│
│ │ Receipt #     RCP-2026-0870                          ││
│ │ Donor         David Miller                           ││
│ │ Amount        $200.00 USD                            ││
│ │ Date          Apr 2, 2026                            ││
│ │ Gateway       Stripe (Visa ****1234)                 ││
│ └──────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

- **Combobox**: queries `globalDonations(searchText: $q, excludeRefunded: true, pageSize: 10)`; result rows display `{ReceiptNumber} — {ContactName} ({Currency} {Amount})`.
- **Selection**: writes `globalDonationId` into form; preview-card auto-populates from selected GD's full payload (the query returns `originalDonationDate`, `originalDonationAmount`, `currencyCode`, `paymentModeName`, `paymentMaskedDetails`).
- **Disabled in mode=edit** — once a refund is created, the original donation cannot be reassigned.
- **Card uses `bg-cyan-50` (mockup `.donation-preview` accent-bg)** — accent-tinted background, accent-100 border (`#a5f3fc`).

**Conditional Sub-form Behavior**:

| Trigger Field | Trigger Value | Behavior |
|--------------|---------------|----------|
| refundTypeCode | `FULL` | refundAmount auto-set to GD.DonationAmount; field becomes readonly |
| refundTypeCode | `PARTIAL` | refundAmount becomes editable; default value is GD.DonationAmount × 0.5 (suggested) |
| refundReasonId.dataCode | `OTH` | refundReasonNote field appears; required |
| refundReasonId.dataCode | (any other) | refundReasonNote hidden + cleared |
| globalDonationId | (selected) | refundMethodLabel auto-populated from GD.DonationMode + payment metadata; preview card appears |

**Form Validation Summary** (FE + BE):
- globalDonationId required
- refundTypeCode required (FULL or PARTIAL)
- refundAmount > 0 AND ≤ GD.DonationAmount (BE-side strict check)
- refundReasonId required
- refundReasonNote required when reason=OTH
- (form-level) "Refund already exists for this donation" — caught from BE error and surfaced as toast

---

#### LAYOUT 2: DETAIL (mode=read) — DRAWER (600px right-side, sibling pattern to Pledge #12)

> Read-only detail drawer slides in from right edge over the grid. Width 600px. Mockup shows a modal but per Pledge convention, we use a drawer. (See ISSUE-12 for the alternative full-page approach.)

**Drawer Header**: `<FlowFormPageHeader title="Refund {refundCode}" subtitle="{statusBadge} — {originalReceiptNumber}" onClose>`
**Drawer Header Actions** (status-conditional — buttons appear in header right):

| Status | Header Buttons |
|--------|---------------|
| PEN | `[Approve]` (primary green → opens Approval Modal), `[Reject]` (outline red → opens Rejection Modal), `[Edit]` (outline gray → navigates `?mode=edit&id=X` — closes drawer + opens form), `[Delete]` (outline red icon-only → confirm dialog + DeleteRefund cmd) |
| APR | `[Process Refund]` (primary blue → ProcessRefund cmd; SERVICE_PLACEHOLDER toast on success), `[Print]` (SERVICE_PLACEHOLDER) |
| PRO | `[Mark Complete]` (primary green → opens Complete Modal — captures GatewayTransactionRefundId + RefundedDate), `[Print]` (SERVICE_PLACEHOLDER) |
| REF | `[Print Receipt]` (SERVICE_PLACEHOLDER) |
| REJ | `[Print Receipt]` (SERVICE_PLACEHOLDER) |

**Drawer Body — Section Cards** (stacked vertically, scrollable):

| # | Card Title | Icon | Content |
|---|-----------|------|---------|
| 1 | Refund Summary | `phosphor:rotate-left` | RefundCode (large bold), RefundStatus badge (with icon), RefundType badge, RefundAmount (large red/amber per type), RefundReason (with DataName + Note if OTH), RefundRequestedDate (Apr 8, 2026) |
| 2 | Original Donation | `phosphor:receipt` | Original Receipt # (link → GD detail), Donor (link → Contact detail), Donation Amount, Currency, Donation Date, Payment Method/Gateway |
| 3 | Refund Method | `phosphor:credit-card` | refundMethodLabel (e.g., "Stripe (Visa ****1234) — Original payment") |
| 4 | Approval Trail | `phosphor:check-circle` | Conditional rendering based on status: PEN: "Awaiting approval"; APR: "Approved by {ApprovedBy.StaffName} on {ApprovedDate}" + ApprovalNote; PRO: above + "Processing started {ProcessingStartedDate}"; REF: above + "Refunded on {RefundedDate} via gateway txn {GatewayTransactionRefundId}"; REJ: "Rejected by {RejectedBy.StaffName} on {RejectedDate}: {RejectionReason}" |
| 5 | Donor | `phosphor:user` | Donor avatar (initials or photo), Name (link), Email, Phone, Engagement score (NULL stub per Family/Contact precedents), "View Profile" link → `/[lang]/crm/contact/contact?mode=read&id={contactId}` |
| 6 | Activity Timeline | `phosphor:clock-counter-clockwise` | Timeline list: Created (CreatedDate, CreatedByName), Approved/Rejected (timestamp, who), Processing started, Refunded (timestamp, gateway txn) — derived from row state |
| 7 | Additional Notes | `phosphor:notepad` | additionalNotes textarea content (read-only display); show "No notes" if empty |

**If drawer not chosen — full DETAIL page**: same 7 sections in a 2-column grid (Left col cards 1-3 + 7; Right col cards 4-6).

> If mockup detail/page is preferred over drawer, FE Dev creates `refund-detail-page.tsx` instead of `refund-detail-drawer.tsx`. Both file names referenced in §⑧ — pick ONE based on solution-resolver's call.

---

### Modals (Workflow Transition UIs)

#### Modal A — Approval Confirmation Modal (mockup `#approveRefundModal`)

**File**: `refund-approval-modal.tsx` (Zustand-triggered — `refundStore.approvalModalRowId`)

**Header**: red gradient bar (mockup `.modal-header.danger`), title "Confirm Refund Approval" with `phosphor:shield-check` icon

**Body** (matches mockup exactly):
1. **Refund Summary box** (gray bg, rounded): label-value rows for Refund ID, Original Donation, Donor, Refund Amount (large red), Refund To (= refundMethodLabel), Reason
2. **Approved By** field — readonly text, pre-filled with current user's StaffName (from `IUserContext`)
3. **Note** textarea — optional ApprovalNote (2 rows, placeholder "Optional approval note...")
4. **Warning callout** (red bg + red border + warning icon `phosphor:warning`): "This will refund {amount} to {donor}'s {refundMethodLabel}. **This action cannot be undone.** The refund will be processed immediately through the payment gateway."

**Footer**: `[Cancel]` (light gray), `[Confirm Refund]` (red primary `bg-rose-600` — matches mockup `.btn-danger-confirm`)

**On Confirm**:
1. Fire `ApproveRefund(refundId, approvalNote)` mutation
2. On success: close modal, toast "Refund approved", refetch grid + summary
3. **If gateway placeholder enabled**: optionally chain a ProcessRefund call immediately (per finance flow). For MVP, do NOT auto-chain — leave as APR and surface "Process" button on drawer.

#### Modal B — Rejection Modal (NEW — not in mockup but workflow requires it)

**File**: `refund-rejection-modal.tsx`

**Header**: red bar, title "Reject Refund Request" with `phosphor:x-circle` icon

**Body**:
1. **Refund Summary box** (same as Approval Modal — RefundCode, Donor, Amount)
2. **Rejection Reason** textarea — **required**, min 10 chars (placeholder "Why is this refund being rejected? (visible to internal team)")
3. **Warning callout** (amber bg): "Rejected refunds are terminal — they cannot be re-approved. The donor will not be notified automatically."

**Footer**: `[Cancel]`, `[Confirm Rejection]` (red primary)

**On Confirm**: fire `RejectRefund(refundId, rejectionReason)` → close modal → toast → refetch.

#### Modal C — Mark Complete Modal (NEW — for PRO→REF transition)

**File**: `refund-complete-modal.tsx`

**Header**: green bar, title "Mark Refund as Completed" with `phosphor:check-circle` icon

**Body**:
1. **Refund Summary box** (compact)
2. **Refunded Date** datepicker — defaults today, required
3. **Gateway Transaction ID** text input — optional (placeholder "e.g., re_3MtwBwLkdIwHu7ix1... (from Stripe dashboard)")
4. **Note**: "Use this to manually mark the refund as completed when gateway integration is unavailable."

**Footer**: `[Cancel]`, `[Mark Refunded]` (green primary)

**On Confirm**: fire `CompleteRefund(refundId, refundedDate, gatewayTransactionRefundId)` → close → toast → refetch.

---

### Page Widgets & Summary Cards

> See §⑥ KPI Widgets table above. **Grid Layout Variant**: `widgets-above-grid` (Variant B mandatory).

### Grid Aggregation Columns

> **NONE** — all aggregations are top-of-page KPI widgets, not per-row.

### User Interaction Flow (FLOW — 3 modes, drawer detail, 3 modals)

1. User sees FlowDataTable grid with 3 KPI widgets + 5 chips → clicks `+ New Refund Request` → URL: `/refund?mode=new` → FORM LAYOUT
2. User searches donation in Donation Picker → selects → preview card auto-populates
3. User picks Refund Type (Full default), adjusts amount if Partial, picks Reason, fills note if OTH
4. User clicks Submit → CreateRefund cmd → URL redirects to `/refund?mode=read&id={newId}` → drawer opens with PEN status
5. From grid: user clicks Approve on a PEN row → Approval Modal opens with row context → user confirms → ApproveRefund cmd → row flips to APR → toast → grid refetches
6. User clicks Process button (in drawer or grid) on APR row → ProcessRefund cmd → row flips to PRO (SERVICE_PLACEHOLDER toast: "Refund queued for gateway processing")
7. User clicks Mark Complete on PRO row → Complete Modal opens → user enters RefundedDate + (optional) GatewayTransactionRefundId → CompleteRefund cmd → row flips to REF
8. User clicks Reject on PEN row → Rejection Modal opens → reason required → RejectRefund cmd → row flips to REJ (terminal)
9. Filter chips: clicking a chip filters grid (and preserves selection across refetch); clicking "All" clears filter
10. Row click anywhere except action buttons → opens drawer (`?mode=read&id={id}`)
11. Edit button (drawer or grid menu) on PEN row → URL: `/refund?mode=edit&id={id}` → FORM LAYOUT pre-filled (donation picker locked to selected GD)
12. Save in edit mode → UpdateRefund → URL redirects to drawer
13. Back button (in form): URL → `/refund` (no params) → grid view
14. Unsaved changes: dirty form + back/navigate → confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity. Canonical: **ChequeDonation #6 (PROMPT_READY)** + **InKindDonation #7 (COMPLETED)** under same Module/Group.

| Canonical (ChequeDonation / InKindDonation) | → Refund | Context |
|---------------------------------------------|----------|---------|
| ChequeDonation / DonationInKind | Refund | Entity/class name |
| chequeDonation / donationInKind | refund | Variable/field names (camelCase) |
| ChequeDonationId / DonationInKindId | RefundId | PK field |
| ChequeDonations / DonationInKinds | Refunds | Table name, collection |
| cheque-donation / donation-in-kind | refund | kebab-case |
| chequedonation / donationinkind | refund | FE folder, import paths, file basename |
| CHEQUEDONATION / DONATIONINKIND | REFUND | GridCode, MenuCode |
| fund | fund | DB schema (UNCHANGED) |
| Donation | Donation | Backend group name (UNCHANGED — entity goes in DonationModels, schema in DonationSchemas, business in DonationBusiness, endpoint in Donation folder) |
| DonationModels | DonationModels | Entity namespace (UNCHANGED) |
| DonationSchemas | DonationSchemas | DTO namespace (UNCHANGED) |
| DonationBusiness | DonationBusiness | Command/query namespace (UNCHANGED) |
| CRM_DONATION | CRM_DONATION | Parent menu code (UNCHANGED) |
| CRM | CRM | Module code (UNCHANGED) |
| crm/donation/chequedonation / crm/donation/donationinkind | crm/donation/refund | FE route path |
| donation-service | donation-service | FE service folder (UNCHANGED) |
| donation-queries / donation-mutations | donation-queries / donation-mutations | FE gql folder names (UNCHANGED) |
| ChequeStatusId (CHEQUESTATUS) / DonationInKindStatusId (DIKSTATUS) | RefundStatusId (REFUNDSTATUS) | Workflow MasterData FK |
| (n/a) | RefundReasonId (REFUNDREASON) | Reason MasterData FK (NEW concept) |
| Deposit/Clearance modals (ChequeDonation) | Approval/Rejection/Complete modals | Workflow transition UIs |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Paths follow real repo layout (`PSS_2.0_Backend\PeopleServe\Services\Base\` and `PSS_2.0_Frontend\src\`).

### Backend Files — NEW (18 files: 11 standard CRUD/Query + 4 workflow commands + 1 summary query + 1 EF config + 1 migration)

| # | File | Path |
|---|------|------|
| 1 | Entity | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/Refund.cs |
| 2 | EF Config | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/DonationConfigurations/RefundConfiguration.cs |
| 3 | Schemas (DTOs) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/DonationSchemas/RefundSchemas.cs |
| 4 | Create Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Refunds/CreateCommand/CreateRefund.cs |
| 5 | Update Command | .../DonationBusiness/Refunds/UpdateCommand/UpdateRefund.cs |
| 6 | Delete Command | .../DonationBusiness/Refunds/DeleteCommand/DeleteRefund.cs |
| 7 | Toggle Command | .../DonationBusiness/Refunds/ToggleCommand/ToggleRefund.cs |
| 8 | Approve Command | .../DonationBusiness/Refunds/ApproveCommand/ApproveRefund.cs |
| 9 | Reject Command | .../DonationBusiness/Refunds/RejectCommand/RejectRefund.cs |
| 10 | Process Command | .../DonationBusiness/Refunds/ProcessCommand/ProcessRefund.cs |
| 11 | Complete Command | .../DonationBusiness/Refunds/CompleteCommand/CompleteRefund.cs |
| 12 | GetAll Query | .../DonationBusiness/Refunds/GetAllQuery/GetAllRefund.cs |
| 13 | GetById Query | .../DonationBusiness/Refunds/GetByIdQuery/GetRefundById.cs |
| 14 | Summary Query | .../DonationBusiness/Refunds/GetSummaryQuery/GetRefundSummary.cs |
| 15 | Mutations | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Donation/Mutations/RefundMutations.cs |
| 16 | Queries | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Donation/Queries/RefundQueries.cs |
| 17 | EF Migration | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Migrations/{TS}_Add_Refund.cs (+ Designer.cs + ApplicationDbContextModelSnapshot.cs update) |
| 18 | DB Seed SQL | PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Refund-sqlscripts.sql (preserve repo `dyanmic` typo per Pledge #12 ISSUE-15) |

### Backend Wiring Updates (6 files)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | PSS_2.0_Backend/.../Base.Application/Data/Persistence/IDonationDbContext.cs | `DbSet<Refund> Refunds { get; }` property |
| 2 | PSS_2.0_Backend/.../Base.Infrastructure/Data/Persistence/DonationDbContext.cs | `public DbSet<Refund> Refunds => Set<Refund>();` |
| 3 | PSS_2.0_Backend/.../Base.Application/Common/DecoratorProperties.cs | `DecoratorDonationModules.Refund = "Refund"` (or sibling pattern — check existing `DecoratorDonationModules` enum/class structure used by ChequeDonation/DonationInKind) |
| 4 | PSS_2.0_Backend/.../Base.Application/Mappings/DonationMappings.cs | Mapster mappings: `Refund ↔ RefundRequestDto/RefundResponseDto`; explicit `.Map(...)` for projected GD fields (ContactName/Currency/PaymentMode/etc.) — same pattern as ChequeDonation #6 ISSUE-17 |
| 5 | PSS_2.0_Backend/.../Base.Infrastructure/Data/SeedData/MasterData.cs (or NotifySeedDataExtentions.cs — verify which file holds the seed list) | Append seed for TypeCode=`REFUNDSTATUS` (5 rows) + TypeCode=`REFUNDREASON` (6 rows) |
| 6 | PSS_2.0_Backend/.../GlobalUsing.cs (3 files: Application, Infrastructure, API as per chequedonation precedent) | Add `global using Refund-related namespaces` if missing |

### Backend Modifications to Existing Files (1 file — for Donation Picker filter)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | PSS_2.0_Backend/.../Base.Application/Business/DonationBusiness/GlobalDonations/GetAllQuery/GetAllGlobalDonation.cs (or equivalent — confirm filename) | Add new query arg `bool? excludeRefunded = false`. When true, append predicate `!_db.Refunds.Any(r => r.GlobalDonationId == d.GlobalDonationId && !r.IsDeleted)` to the LINQ. Register the new arg in the `globalDonations` GraphQL endpoint. |

### Frontend Files — NEW (21 files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/donation-service/RefundDto.ts |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/RefundQuery.ts |
| 3 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/donation-mutations/RefundMutation.ts |
| 4 | Page Config | PSS_2.0_Frontend/src/presentation/pages/donation/refund/refund.tsx |
| 5 | Index Router | PSS_2.0_Frontend/src/presentation/components/page-components/donation/refund/refund/index.tsx (URL mode dispatcher: routes between index-page / view-page based on `?mode=`) |
| 6 | Index Page (Variant B) | .../donation/refund/refund/index-page.tsx |
| 7 | View Page (3 modes) | .../donation/refund/refund/view-page.tsx |
| 8 | Refund Create Form | .../donation/refund/refund/refund-create-form.tsx (the React Hook Form body for new+edit) |
| 9 | Refund Form Schemas | .../donation/refund/refund/refund-form-schemas.ts (Zod schemas — base, create, update) |
| 10 | Detail Drawer | .../donation/refund/refund/refund-detail-drawer.tsx (600px right-side drawer — DETAIL layout) |
| 11 | KPI Widgets | .../donation/refund/refund/refund-widgets.tsx (3 KPI cards) |
| 12 | Filter Chips | .../donation/refund/refund/refund-filter-chips.tsx (5 chips: All / Pending / In Progress / Refunded / Rejected) |
| 13 | Advanced Filter Panel | .../donation/refund/refund/refund-advanced-filters.tsx (status / reason / type / amount / dates) |
| 14 | Donation Picker | .../donation/refund/refund/refund-donation-picker.tsx (combobox + preview card) |
| 15 | Approval Modal | .../donation/refund/refund/refund-approval-modal.tsx |
| 16 | Rejection Modal | .../donation/refund/refund/refund-rejection-modal.tsx |
| 17 | Complete Modal | .../donation/refund/refund/refund-complete-modal.tsx |
| 18 | Activity Timeline | .../donation/refund/refund/refund-activity-timeline.tsx (drawer card 6) |
| 19 | Zustand Store | .../donation/refund/refund/refund-store.ts (filter chip state, advanced filter, modal trigger ids, drawer-open id) |
| 20 | Cell Renderer Module | PSS_2.0_Frontend/src/presentation/components/data-table-shared/renderers/refund-cell-renderers.tsx (5 NEW renderers: original-donation-link, refund-amount-cell, refund-type-badge, reason-tag, refund-status-badge — placed in shared so other screens can reuse) |
| 21 | Route Page | PSS_2.0_Frontend/src/app/[lang]/(core)/crm/donation/refund/page.tsx — **OVERWRITE** the 5-line stub at `PSS_2.0_Frontend/src/app/[lang]/crm/donation/refund/page.tsx` (verify locale path — existing stub is at `[lang]/crm/donation/refund` not `[lang]/(core)/crm/...`; preserve existing route layout) |

> **NOTE on file path #21**: Existing stub is at `PSS_2.0_Frontend\src\app\[lang]\crm\donation\refund\page.tsx` (NOT under `(core)`). Preserve the existing folder — overwrite the file content; do NOT recreate under `(core)`. Verify against sibling DonationInKind #7 final route path.

### Frontend Wiring Updates (8 files)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | PSS_2.0_Frontend/src/.../entity-operations.ts | `REFUND` operations config (queries + mutations + entity name) — sibling pattern to DONATIONINKIND |
| 2 | PSS_2.0_Frontend/src/.../operations-config.ts | Import + register Refund operations |
| 3 | PSS_2.0_Frontend/src/.../advanced-data-table/cell-renderers/registry.ts (or equivalent — verify name) | Register 5 new renderers: original-donation-link, refund-amount-cell, refund-type-badge, reason-tag, refund-status-badge |
| 4 | PSS_2.0_Frontend/src/.../basic-data-table/cell-renderers/registry.ts | Same 5 renderers |
| 5 | PSS_2.0_Frontend/src/.../flow-data-table/cell-renderers/registry.ts | Same 5 renderers |
| 6 | PSS_2.0_Frontend/src/.../shared-cell-renderers.ts (barrel) | Re-export 5 renderers |
| 7 | PSS_2.0_Frontend/src/.../sidebar/menu-config.ts (or equivalent) | REFUND menu entry under CRM_DONATION at OrderBy=8 (DB seed should already register this; sidebar may auto-pick up — verify) |
| 8 | PSS_2.0_Frontend/src/presentation/pages/index.ts (pages barrel) | Export `RefundPage` from `pages/donation/refund/refund.tsx` |

### Frontend File Deletions (0 — nothing to delete; just overwrite the 5-line stub)

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Refunds
MenuCode: REFUND
ParentMenu: CRM_DONATION
Module: CRM
MenuUrl: crm/donation/refund
GridType: FLOW
OrderBy: 8

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: REFUND

Icon: phosphor:arrow-u-up-left (or solar:reply-bold-duotone — match sidebar convention)

MasterDataSeed:
  TypeCode: REFUNDSTATUS
    PEN — Pending Approval — yellow #ca8a04 — OrderBy 1 — Description: "Just submitted, awaiting finance approval"
    APR — Approved — purple #7c3aed — OrderBy 2 — Description: "Finance approved, ready to process"
    PRO — Processing — blue #2563eb — OrderBy 3 — Description: "Sent to gateway, awaiting confirmation"
    REF — Refunded — green #16a34a — OrderBy 4 — Description: "Gateway confirmed; terminal success"
    REJ — Rejected — red #dc2626 — OrderBy 5 — Description: "Denied; terminal alternate"
  TypeCode: REFUNDREASON
    DOR — Donor Request — OrderBy 1
    DUP — Duplicate Charge — OrderBy 2
    FRA — Card Fraud — OrderBy 3
    EVT — Event Cancelled — OrderBy 4
    ACC — Accidental — OrderBy 5
    OTH — Other — OrderBy 6 (requires RefundReasonNote on form)
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `RefundQueries`
- Mutation type: `RefundMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAllRefundList` (or `refunds` — match sibling naming) | `[RefundResponseDto]` | searchText, pageNo, pageSize, sortField, sortDir, isActive, refundStatusId, refundReasonId, refundTypeCode, refundRequestedDateFrom, refundRequestedDateTo, refundedDateFrom, refundedDateTo, amountMin, amountMax, refundStatusCode (top-level chip arg) |
| `getRefundById` | `RefundResponseDto` | refundId |
| `getRefundSummary` | `RefundSummaryDto` | (no args — tenant-scoped via HttpContext) |

**Modifications to existing query (for Donation Picker)**:
| GQL Field | New Arg | Behavior |
|-----------|---------|----------|
| `globalDonations` (existing) | `excludeRefunded: Boolean = false` | When true, filters out GDs with any non-deleted Refund |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createRefund` | `RefundRequestDto` | int (new RefundId) |
| `updateRefund` | `RefundRequestDto` (with refundId) | int |
| `deleteRefund` | `refundId: Int!` | int |
| `toggleRefund` | `refundId: Int!` | int |
| `approveRefund` | `refundId: Int!`, `approvalNote: String` | int |
| `rejectRefund` | `refundId: Int!`, `rejectionReason: String!` (required) | int |
| `processRefund` | `refundId: Int!` | int |
| `completeRefund` | `refundId: Int!`, `refundedDate: DateTime`, `gatewayTransactionRefundId: String` | int |

**Response DTO Fields** (`RefundResponseDto` — what FE receives in grid + detail):

| Field | Type | Notes |
|-------|------|-------|
| refundId | number | PK |
| refundCode | string | REF-{NNNN} |
| globalDonationId | number | FK |
| originalReceiptNumber | string | from GD.ReceiptNumber |
| contactId | number? | from GD.ContactId (nullable for anonymous) |
| contactName | string? | from GD.Contact.ContactName |
| contactCode | string? | from GD.Contact.ContactCode |
| isAnonymous | boolean | derived: contactId is null OR Contact.IsAnonymous |
| originalDonationAmount | number | from GD.DonationAmount |
| currencyCode | string | from GD.Currency.CurrencyCode |
| currencySymbol | string? | from GD.Currency.CurrencySymbol |
| originalDonationDate | string (ISO date) | from GD.DonationDate |
| paymentModeName | string? | from GD.DonationMode.DataName |
| paymentMaskedDetails | string? | derived from GD payment metadata (e.g., "Visa ****1234"); null when not derivable |
| refundTypeCode | string | FULL | PARTIAL |
| refundAmount | number | refund amount |
| refundReasonId | number | FK |
| refundReasonName | string | from MasterData.DataName |
| refundReasonCode | string | from MasterData.DataCode (drives OTH note visibility) |
| refundReasonNote | string? | required when reasonCode=OTH |
| refundMethodLabel | string? | display string |
| refundStatusId | number | FK |
| refundStatusName | string | from MasterData.DataName |
| refundStatusCode | string | from MasterData.DataCode (drives badges + workflow buttons) |
| refundRequestedDate | string (ISO date) | — |
| approvedById | number? | FK Staff |
| approvedByName | string? | from Staff.StaffName |
| approvedDate | string? | — |
| approvalNote | string? | — |
| rejectedById | number? | — |
| rejectedByName | string? | — |
| rejectedDate | string? | — |
| rejectionReason | string? | — |
| processingStartedDate | string? | — |
| refundedDate | string? | — |
| gatewayTransactionRefundId | string? | — |
| additionalNotes | string? | — |
| createdByName | string | from Staff lookup on CreatedBy |
| createdDate | string (ISO date) | inherited |
| modifiedByName | string? | from Staff lookup on ModifiedBy |
| modifiedDate | string? | inherited |
| isActive | boolean | inherited |

**RefundSummaryDto fields** (for `getRefundSummary` query):
| Field | Type | Notes |
|-------|------|-------|
| pendingCount | number | count where status=PEN |
| pendingTotal | number | SUM(refundAmount) where status=PEN, in base currency |
| processedThisMonthCount | number | count where status=REF AND refundedDate within current month |
| processedThisMonthTotal | number | SUM where status=REF AND refundedDate within current month |
| refundedYtdCount | number | count where status=REF AND refundedDate within current year |
| refundedYtdTotal | number | SUM where status=REF AND refundedDate within current year |
| approvedCount | number | count where status=APR |
| processingCount | number | count where status=PRO |
| refundedCount | number | total count where status=REF (lifetime) |
| rejectedCount | number | count where status=REJ |

**RefundRequestDto fields** (for create + update mutations):
| Field | Type | Required |
|-------|------|----------|
| refundId | number? | only on update |
| globalDonationId | number | YES |
| refundTypeCode | string | YES (FULL | PARTIAL) |
| refundAmount | number | YES |
| refundReasonId | number | YES |
| refundReasonNote | string? | required when reason=OTH |
| refundMethodLabel | string? | optional (auto-derived if omitted) |
| additionalNotes | string? | optional |
| isActive | boolean | default true |

(Status fields are NOT in RequestDto — they're set by handler/transition commands.)

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors after migration applied (`dotnet ef database update` succeeds)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/donation/refund`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 10 columns: Refund ID, Original Donation, Donor, Original Amt, Refund Amt, Type, Reason, Requested, Status, Actions
- [ ] 3 KPI widgets above grid show non-zero counts when seed data exists (Pending Approval, Processed This Month, Total Refunded YTD)
- [ ] 5 filter chips render with badge counts; clicking a chip filters the grid
- [ ] Advanced filter panel opens via toolbar, filters by status/reason/type/amount/dates
- [ ] Search box filters by refundCode + receipt# + donor name
- [ ] `?mode=new` — empty FORM renders 4 sections (Original Donation, Refund Details, Refund Method, Additional Notes)
- [ ] Donation Picker combobox queries `globalDonations(excludeRefunded:true)` and shows result rows formatted "{ReceiptNumber} — {ContactName} ({Currency} {Amount})"
- [ ] Selecting a donation populates Donation Preview Card with Receipt#, Donor, Amount, Date, Gateway
- [ ] Refund Type radio: Full (default) → refundAmount auto-set to GD.DonationAmount + readonly; Partial → refundAmount editable, validates ≤ GD.DonationAmount
- [ ] Refund Reason: selecting "Other" reveals required Refund Reason Note textarea
- [ ] Refund Method auto-populated readonly text
- [ ] Submit creates row with status=PEN; URL changes to `?mode=read&id={newId}` → drawer opens
- [ ] `?mode=read&id=X` — drawer (or detail page) renders 7 cards: Refund Summary, Original Donation, Refund Method, Approval Trail, Donor, Activity Timeline, Additional Notes
- [ ] Approval Modal opens from row Approve action OR drawer Approve button; shows mockup-matching summary box, Approved-By readonly, Note textarea, red warning callout, Confirm Refund red button
- [ ] Confirm in Approval Modal → ApproveRefund cmd → row flips to APR → toast → grid refetches
- [ ] Rejection Modal: rejection reason required (min 10 chars); RejectRefund cmd → row flips to REJ
- [ ] Process button on APR row (drawer/grid): ProcessRefund cmd → row flips to PRO; toast: "Refund queued for gateway processing (gateway integration pending)"
- [ ] Mark Complete Modal on PRO row: RefundedDate + (optional) GatewayTransactionRefundId → CompleteRefund cmd → row flips to REF
- [ ] Workflow guards verified: Edit/Delete only enabled on PEN; Approve/Reject only on PEN; Process only on APR; Complete only on PRO
- [ ] One-Refund-per-Donation rule: trying to create a 2nd refund for the same GD shows BadRequest toast
- [ ] Donor name link → navigates to contact detail
- [ ] Original receipt link → navigates to GlobalDonation detail
- [ ] Anonymous donations render as "Anonymous" gray italic in Donor column
- [ ] SERVICE_PLACEHOLDER buttons (Process via Gateway, Print Receipt) render with toast — see ⑫
- [ ] Unsaved changes dialog triggers on dirty form back-navigate
- [ ] Permissions: Edit/Delete/Approve/Reject buttons hidden if BUSINESSADMIN role lacks MODIFY/DELETE capability

**DB Seed Verification:**
- [ ] REFUND menu visible in sidebar under CRM_DONATION at OrderBy=8 (after RECONCILIATION at 7)
- [ ] Grid columns render correctly per seed
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)
- [ ] REFUNDSTATUS MasterData populated (5 rows: PEN/APR/PRO/REF/REJ)
- [ ] REFUNDREASON MasterData populated (6 rows: DOR/DUP/FRA/EVT/ACC/OTH)
- [ ] BUSINESSADMIN role granted READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT capabilities on REFUND menu

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** in the form/DTO — it comes from HttpContext on writes/reads
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout, read opens drawer (or full page)
- **Workflow status is set by transition commands**, not via Update — never expose RefundStatusId in RequestDto
- **One Refund per GlobalDonation** rule — strictly enforced in MVP. Multi-partial-refund support deferred (see ISSUE-13)
- **Mockup uses modals for Add and Approve** — we keep Approve as a modal (workflow gating is modal-appropriate) but rebuild Add as a full-page form per FLOW convention (Pledge #12 + ChequeDonation #6 precedent)
- **Donor link nav target**: `/[lang]/crm/contact/contact?mode=read&id={contactId}` — match Contact #18 PARTIALLY_COMPLETED route convention
- **GD link nav target**: `/[lang]/crm/donation/globaldonation?mode=read&id={globalDonationId}` — match GlobalDonation #1 COMPLETED convention
- **Seed file location**: `sql-scripts-dyanmic/` (preserve repo `dyanmic` typo per Pledge #12 ISSUE-15 / ChequeDonation #6 ISSUE-15)
- **Path convention**: real backend path is `PSS_2.0_Backend\PeopleServe\Services\Base\` (NOT `Pss2.0_Backend` as the FLOW template placeholder suggests). Frontend is `PSS_2.0_Frontend\src\`. Use real paths.

### Pre-flagged ISSUES (15 — track in Build Log Known Issues table on first session)

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | BE / Workflow | **ProcessRefund is SERVICE_PLACEHOLDER** — actual gateway refund call (Stripe/PayPal/Razorpay refund API) is not wired. Handler currently just flips status APR→PRO and records ProcessingStartedDate. When gateway integration ships, ProcessRefund handler should call `IPaymentService.RefundAsync(gatewayTxnId, amount)` and capture the returned refund-side txn id. Toast on FE: "Refund queued for gateway processing (gateway integration pending)". |
| ISSUE-2 | MED | BE / Cross-screen | **GlobalDonation has no IsRefunded/RefundedAmount column**. When a Refund flips to REF, the parent GD is not flagged. Implication: GD lists/reports won't show a refund indicator. Options: (a) add `IsRefunded bool` + `RefundedAmount decimal?` to GD entity (requires migration on existing screen — high blast radius), (b) project on read by joining Refund table (cheap but needs each GD query updated). MVP: skip the flag; surface refunds only via this screen. Track for future GD #1 enhancement. |
| ISSUE-3 | MED | BE / Data derivation | **paymentMaskedDetails derivation is approximate**. For Stripe-routed donations, the masked PAN lives in `PaymentTransaction` (sibling table). For cash/cheque donations, no such data exists. Implementation: try `.Include(d => d.PaymentTransactions)` and pick the most recent successful txn's masked card. Fallback to `null` and let FE render "Same as original payment method". |
| ISSUE-4 | MED | BE / Validation | **OTH-reason note enforcement** must be in BOTH validator AND handler — validator checks payload shape; handler re-checks because reason can be changed via Update. Pattern: server-resolves reason MasterData by Id, checks `.DataCode == "OTH"`, throws if note empty. |
| ISSUE-5 | MED | BE / Auto-code | **RefundCode auto-generation** must be tenant-scoped per Company AND lock-free under concurrency. Use a `MAX(RefundCode_numeric_part) + 1` query within a transaction (sibling pattern to ChequeNo / PledgeCode). Cap at 4 digits in display ("REF-0042") but allow overflow to 5+ ("REF-12345"). |
| ISSUE-6 | MED | BE / GD Picker | **`excludeRefunded` arg on `globalDonations`** must use `NOT EXISTS` subquery, not `.Any()` materialization, to keep the query SQL-translatable. Verify the LINQ generates a proper EXISTS predicate (run query log in dev). |
| ISSUE-7 | MED | BE / Multi-currency | **KPI sums in RefundSummaryDto** mix multi-currency rows. Best practice: convert each refundAmount to base currency using GD.ExchangeRate, then SUM. If GD.ExchangeRate is null/zero, fall back to refundAmount × Currency.RateToBase. Document the chosen approach in handler comments. (Inherited multi-currency concern from Pledge #12 ISSUE-12 / ChequeDonation #6 area.) |
| ISSUE-8 | MED | FE / Renderer | **`refund-status-badge` renderer with completion-date suffix**: REF rows show "Refunded (Mar 30)" not just "Refunded". The renderer needs access to the row's `refundedDate` field — either pass it via the cell-renderer's row context OR build a composite badge that takes a `{label, color, suffixDate?}` config. Verify the cell-renderer registry signature supports row context (sibling renderers in shared-cell-renderers do — confirm). |
| ISSUE-9 | LOW | BE / GD Picker | **Donation Picker UX edge case**: if user is editing an existing Refund (`?mode=edit`), the Donation Picker is locked but should still display the linked GD info. The combobox should accept a `lockedSelection={ id, label }` prop and render disabled with the label. |
| ISSUE-10 | MED | FE / Filter chips | **Filter chip wiring**: per Family #20 ISSUE-13 precedent, push chip filters as **top-level GQL args** (`refundStatusCode: "PEN"`) not via the FlowDataTable advancedFilter payload. Otherwise the chip count badges and grid contents will desync. Same fix the Family #20 build still has open. |
| ISSUE-11 | LOW | FE / Renderer reuse | **`donor-link` renderer**: ChequeDonation #6 plans to introduce this renderer. If ChequeDonation #6 ships first, REUSE it (do NOT recreate). If Refund ships first, create here in `shared-cell-renderers` and ChequeDonation will reuse. Coordinate via build order. |
| ISSUE-12 | LOW | FE / Detail UX | **Drawer vs full-page detail**: Pledge #12 uses 720px drawer; RecurringDonationSchedule #8 uses 460px drawer; ChequeDonation #6 uses full-page DETAIL. Refund prompt defaults to **600px drawer** (mid-size — refund detail has 7 cards, more than a sidebar but less than a full audit page). Solution-resolver may flip this to full-page if 7 cards don't fit comfortably. If full-page chosen, rename file `refund-detail-drawer.tsx` → `refund-detail-page.tsx` and adjust router. |
| ISSUE-13 | LOW | Future | **Multi-partial-refund support deferred**. MVP enforces 1 Refund per GlobalDonation. Future enhancement: allow N partial refunds whose sum ≤ GD.DonationAmount (FE adds "Refund History" section to GD detail; BE relaxes the unique-per-GD rule and adds running-sum validation). |
| ISSUE-14 | LOW | FE / Print | **Print Receipt button is SERVICE_PLACEHOLDER** — PDF receipt generation infrastructure isn't wired. Toast: "Receipt PDF generation pending — coming soon." Inherited from DonationInKind #7 ISSUE-1. |
| ISSUE-15 | LOW | DB / Seed | **Seed file path typo `dyanmic`** — preserve. New seed file `Refund-sqlscripts.sql` goes in `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/` (NOT `dynamic`). Inherited from ChequeDonation #6 ISSUE-15 / Pledge #12 ISSUE-15. |

### SERVICE_PLACEHOLDERs (3 — UI-only, mocked handler)

> Everything else in the mockup is in scope. Only items that require external service/infrastructure not in the codebase yet.

- **⚠ SERVICE_PLACEHOLDER #1: Process Refund via Gateway** — Full UI implemented (Process button on APR rows + drawer + grid action; Approval Modal "Confirm Refund" warning text). Handler `ProcessRefund` flips status APR→PRO and records ProcessingStartedDate. Real gateway refund API call not wired (no `IPaymentService.RefundAsync` consumer in this screen). Toast: "Refund queued for gateway processing (gateway integration pending)."
- **⚠ SERVICE_PLACEHOLDER #2: Print Receipt** — Full UI button on REF/REJ rows (drawer header). Handler is a no-op toast: "Receipt PDF generation pending — coming soon." (Inherited platform-wide gap.)
- **⚠ SERVICE_PLACEHOLDER #3: Donor Notification on Status Transition** — Mockup Approval Modal warning says "The refund will be processed immediately". Real impl should email donor on APR + REF (with refund confirmation). For MVP, no email. No UI element to mock — just a missing handler side-effect documented here.

Full UI must be built (buttons, forms, modals, panels, interactions). Only the handler for the external service call is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no build sessions yet; ISSUE-1..15 are pre-flagged in §⑫ and will be migrated here on first build session) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}