---
screen: Refund
registry_id: 13
module: Fundraising
status: COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-20
completed_date: 2026-04-21
last_session_date: 2026-05-08
v2_planned_date: 2026-05-05
v2_build_started_date: 2026-05-05
v2_completed_date: 2026-05-05
v2_scope: Realtime gateway-reverse flow — channel auto-routing (online vs offline), FX rate snapshot, original gateway fee transparency, receipt cancellation/revision on refund execute. Industry-standard pattern (Stripe/Razorpay/PayPal/Donorbox). NO country-aware method picker, NO PaymentModeCountry junction.
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
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized (FORM + DETAIL layouts + 3 transition modals specified — Approval, Rejection, Complete)
- [x] User Approval received (pre-approved CONFIG from §⑨; orchestrator proceeded per user's upfront permission)
- [x] Backend code generated (17 new files — entity + EF + schemas + 4 CRUD + 4 workflow commands + 3 queries + 2 endpoints + migration + seed SQL)
- [x] Backend wiring complete (IDonationDbContext, DonationDbContext, DecoratorDonationModules, DonationMappings, GetGlobalDonations.cs + GlobalDonationQueries.cs extended with `excludeRefunded` arg)
- [x] Frontend code generated (24 files — DTO, GQL Q+M, page config, router, index-page Variant B, view-page FORM, Zustand store, 600px detail drawer, 3 modals [approval/rejection/complete], widgets, filter chips, advanced filters, donation picker, activity timeline, 5 cell renderers)
- [x] Frontend wiring complete (entity-operations, DTO/Query/Mutation barrels, 3 column-type registries, shared-cell-renderers barrel, pages barrel, route stub overwrite)
- [x] DB Seed script generated (REFUND menu @ OrderBy=8 + 8 MenuCapabilities + BUSINESSADMIN grants + FLOW Grid + 10 GridFields + 5 REFUNDSTATUS + 6 REFUNDREASON MasterData rows — idempotent)
- [x] Registry updated to COMPLETED

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

### Enhancement v2 — Realtime Refund Flow (planned 2026-05-05)

> Spec lives at end of file under "## ⓘ Enhancement v2 — Realtime Refund Flow". `/continue-screen` consumes that section and the deltas below.
> **Industry alignment**: Mirrors how Stripe / Razorpay / PayPal / Donorbox / Classy actually handle refunds — gateway-reverse to the original instrument in the original currency; charity bears any FX shift; gateway's own fee policy determines whether the original processing fee is recovered. Manual payout exists only for genuinely offline donations (cash/cheque/in-kind). NO country-aware method picker, NO PaymentModeCountry junction, NO per-method-code dictionary.

#### v2 Planning (by /plan-screens)
- [x] Real-world refund taxonomy researched (Stripe/Razorpay/PayPal/Donorbox/Classy/Givebutter)
- [x] Channel auto-routing decision made — derive from `GlobalDonation.GlobalOnlineDonations.Any()` + `DonationMode.Code`; staff override allowed
- [x] FX snapshot timing decided — at refund-EXECUTE (PRO→REF), not at create — matches gateway behavior
- [x] Receipt cancellation flow defined — FULL → CANCELLED, PARTIAL → REVISED on linked GlobalReceipt
- [x] Original gateway fee transparency — snapshot column + presentation-time recoverability dict (Stripe/Square→true, Razorpay/PayPal/Cashfree→false)
- [x] Manual payout reuses existing `com.PaymentModes` entity — NO new junction, NO country filtering
- [x] FE form restructure plotted (Section 3 = Refund Channel; Section 4 = Charges & Currency w/ conditional FX block)
- [x] Detail drawer card additions plotted (Channel card replaces Method card; Charges card extended; FX Snapshot card conditional)
- [x] v2 prompt section appended (replaces dropped country-aware spec)

#### v2 Generation (by /continue-screen → BE/FE devs)
- [x] BE: EF migration `Add_RefundChannelAndFxSnapshot` (11 columns on `fund.Refunds`; default `RefundChannelCode='GATEWAY_REVERSAL'` and `ReceiptStatusAfterRefund='UNCHANGED'` for existing rows)
- [x] BE: Modify `Refund.cs` (+11 cols, +2 nav properties `RefundCurrency`, `ManualPaymentMode`) and `RefundConfiguration.cs` (decimal precision, FK setup, default values)
- [x] BE: Extend `RefundSchemas.cs` (Response + Create + Update DTOs) with 11 new fields + projection lookups (`refundCurrencyCode`, `manualPaymentModeCode`, `manualPaymentModeName`)
- [x] BE: Extend `CreateRefundHandler` — auto-derive `RefundChannelCode` from selected GD; snapshot `OriginalGatewayFeeAmount` from GD; clear manual fields when channel=GATEWAY_REVERSAL
- [x] BE: Extend `UpdateRefundHandler` — same channel/manual-fields consistency on PEN-only edit
- [x] BE: Extend `CompleteRefundHandler` — at PRO→REF: resolve FX rate via `IFxRateService` when cross-currency; populate `RefundExchangeRate` + `RefundBaseCurrencyAmount`; set `ReceiptStatusAfterRefund` per refundType (FULL→CANCELLED, PARTIAL→REVISED, no-receipt→UNCHANGED). Receipt-row flip dropped — `GlobalReceipt` entity does not exist (only `GlobalReceiptDonations` junction); status tracked on Refund row only.
- [x] BE: `IFxRateService.GetRateAsync(fromCode, toCode, DateOnly asOfDate)` already existed at `Base.Application/Interfaces/IFxRateService.cs` — direct-pair-only, null on miss. Real signature is codes-based (not IDs); handlers do ID→Code lookup against `dbContext.Currencies` first.
- [x] BE: Extend `CreateRefundValidator` / `UpdateRefundValidator` — channel ↔ manual-fields consistency; per-mode required map for MANUAL_PAYOUT enforced in handler (post-PaymentMode load) via `RefundChannelHelper.ManualRequiredByModeCode` static dict; `RefundFeeAmount ≥ 0` rule
- [x] BE: Extend `GetRefunds` + `GetRefundById` projections with 11 new fields + lookup joins (RefundCurrency, ManualPaymentMode)
- [x] BE: Extend `DonationMappings.cs` (Mapster config for new fields + nav `Ignore` for projections)
- [x] BE: NEW lightweight query `GetCurrentFxRate(fromCurrencyId, toCurrencyId)` at `SharedBusiness/Currencies/Queries/GetCurrentFxRate.cs` + endpoint appended to `Base.API/EndPoints/Shared/Queries/CurrencyQueries.cs` — read-only, returns rate value + asOf date (=`DateTime.UtcNow` since service doesn't expose persisted RateDate)
- [x] BE: `dotnet build` 0 CS compile errors (8 MSB3021/MSB3027 file-lock errors pre-existing per Session 2 — VS Insiders + Base.API.exe holding dlls). Migration applied manually deferred per token-budget directive (ISSUE-16 precedent).
- [x] FE: Extend `refund-form-schemas.ts` Zod schema (8 new fields incl. hidden `manualPaymentModeCode` + `.superRefine` for channel ↔ manual consistency. Per-mode required map enforced on BE only — pragmatic per brief).
- [x] FE: NEW `refund-channel-fieldset.tsx` (channel radio + GATEWAY readonly summary card with solid-bg fee-recoverability banner OR MANUAL picker + per-mode dynamic sub-fields for BANK / UPI / MOBILE_MONEY / CHEQUE / PAYPAL / CASH)
- [x] FE: NEW `refund-charges-fx-fieldset.tsx` (Refund Fee input + Net display + conditional FX block w/ `useQuery(GET_CURRENT_FX_RATE)`; null-rate banner; signed FX impact)
- [x] FE: NEW GraphQL query `CurrentFxRateQuery.ts` at `infrastructure/gql-queries/shared-queries/`
- [x] FE: Restructure `refund-create-form.tsx` — Section 3 wires `<RefundChannelFieldset>`; Section 4 wires `<RefundChargesFxFieldset>`; Notes moved to Section 5; auto-derives `refundChannelCode` from `donation.gatewayCode` on donation-pick
- [x] FE: Extend `refund-donation-picker.tsx` `DonationPickerValue` with currency / exchange / gateway / fee / base-currency. Mapper translates BE's `baseCurrencyId` + `baseCurrency.currencyCode` → public-facing `companyBaseCurrencyId/Code` (BE didn't add flat fields — relies on existing `GlobalDonationResponseDto.BaseCurrencyId` + `BaseCurrency` nav).
- [x] FE: Rebuild Card 3 in `refund-detail-drawer.tsx` (Channel card — gateway summary OR manual fields); extend Charges card; add conditional FX Snapshot card
- [x] FE: Extend `RefundDto.ts`, `RefundQuery.ts`, `RefundMutation.ts` with 11 new fields
- [x] FE: `pnpm exec tsc --noEmit` clean (exit 0, 0 lines of output — improved over v1 baseline of 12 unrelated errors)
- [x] DB Seed: NO changes — existing `com.PaymentModes` rows are reused for the manual payout picker
- [x] Registry updated back to COMPLETED with v2 build log appended

#### v2 Verification (post-generation)
- [STRUCTURAL ✓] `?mode=new`: on donation pick, form auto-derives `RefundChannelCode` (online GD → GATEWAY_REVERSAL; offline GD → MANUAL_PAYOUT) — wired in `handleDonationSelect` via `donation.gatewayCode` non-null detection
- [STRUCTURAL ✓] Staff can override the channel via the radio — RHF Controller in `RefundChannelFieldset`
- [STRUCTURAL ✓] GATEWAY_REVERSAL render — readonly Original Payment summary card + solid-bg fee-recoverability banner using `FEE_RECOVERABILITY` dict (Stripe/Square=true, Razorpay/PayPal/Cashfree/Authorize=false)
- [STRUCTURAL ✓] MANUAL_PAYOUT render — `<ApiSelectV2>` picker + per-mode dynamic fields per `paymentModeCode` switch (BANK/UPI/MOBILE_MONEY/CHEQUE/PAYPAL/CASH)
- [STRUCTURAL ✓] BE rejects MANUAL_PAYOUT without `ManualPaymentModeId` — validator rule + handler post-load check
- [STRUCTURAL ✓] BE rejects MANUAL_PAYOUT + BANK_TRANSFER without account+bank — handler runtime check via `RefundChannelHelper.ManualRequiredByModeCode`
- [STRUCTURAL ✓] BE clears manual fields when channel=GATEWAY_REVERSAL — handler explicitly nulls all 4 manual cols regardless of input
- [STRUCTURAL ✓] Cross-currency form Section 4 FX block — `useQuery(GET_CURRENT_FX_RATE, { skip: same-ccy })` + null-rate fallback banner
- [STRUCTURAL ✓] On refund-execute (PRO→REF): `CompleteRefund` handler resolves FX rate via `IFxRateService` (codes-based via `dbContext.Currencies` ID→Code lookup, `DateOnly.FromDateTime(DateTime.UtcNow)` per UTC rule) and persists `RefundExchangeRate` + `RefundBaseCurrencyAmount`
- [STRUCTURAL ✓] Same-currency refunds: 3 FX columns remain NULL — handler short-circuits when donor ccy == charity base ccy
- [STRUCTURAL ✓] On refund-execute with refundType=FULL: handler sets `ReceiptStatusAfterRefund='CANCELLED'` (Refund-row-only — `GlobalReceipt` entity does not exist; only `GlobalReceiptDonations` junction; spec linked-row flip dropped per BE↔FE design call)
- [STRUCTURAL ✓] On refund-execute with refundType=PARTIAL: handler sets `ReceiptStatusAfterRefund='REVISED'` (revised PDF OUT OF SCOPE — ISSUE-V2-3)
- [STRUCTURAL ✓] Donations without a linked receipt: `ReceiptStatusAfterRefund='UNCHANGED'` — handler checks `GlobalReceiptDonations.Any` first
- [STRUCTURAL ✓] Detail drawer Channel card — `<ChannelDetail>` renders both modes (GATEWAY_REVERSAL summary OR MANUAL_PAYOUT populated lines)
- [STRUCTURAL ✓] Detail drawer Charges card — extended with `originalGatewayFeeAmount` snapshot row + `receiptStatusAfterRefund` badge
- [STRUCTURAL ✓] Detail drawer FX Snapshot card — `<FxSnapshotDetail>` rendered conditionally on `refundExchangeRate != null && refundBaseCurrencyAmount != null`
- [DEFERRED] EF migration apply (`dotnet ef database update`) — per token-budget directive + ISSUE-16 (snapshot reconciliation needed). User to apply manually.
- [✓] `dotnet build` clean (0 CS errors; 8 MSB3021/3027 file-lock errors pre-existing, VS Insiders + Base.API.exe locking dlls) / `pnpm exec tsc --noEmit` clean (exit 0)
- [DEFERRED — runtime E2E] All "renders correctly" / "filters" / "navigates" criteria require `pnpm dev` runtime testing; deferred per token-budget directive (matches v1 Session 1 + Session 2 precedent)

#### Session 16 — 2026-05-08 — REFACTOR — COMPLETED (BE)

**Scope**: Workflow simplified to single-step. `CreateRefund` now produces a refund born at status=REF (Refunded) — Pending/Approved/Processing intermediate states are gone. Inlined the parent-GlobalDonation update (PaymentStatus → REFUND, RefundedAmount cumulative, LastRefundedDate) into the same SaveChangesAsync transaction. Added grid-field seeds for two missing index columns.

**Files touched**:
- `Base.Application/Business/DonationBusiness/Refunds/Commands/CreateRefund.cs` — load GD as tracked (was AsNoTracking); resolve REF status (was PEN); resolve PAYMENTSTATUS=REFUND with throw-if-missing; FX snapshot (RefundExchangeRate from gd.ExchangeRate ?? 1.0; RefundBaseCurrencyAmount = amount * rate); set RefundedDate = UtcNow; set GD.PaymentStatusId = REFUND, GD.RefundedAmount += amount, GD.LastRefundedDate = UtcNow — all in one SaveChangesAsync. Validator untouched (one-refund-per-GD rule still holds).
- `Services/Base/sql-scripts-dyanmic/Refund-sqlscripts.sql` — STEP 6b (sett.Fields: RF_CONTACTCODE/contactCode/STRING + RF_REFUNDFEEAMOUNT/refundFeeAmount/DECIMAL); STEP 6c (sett.GridFields rows: Contact Code at OrderBy=11, Refund Fee Amount at OrderBy=51 with GridComponentName='currency-amount'). All idempotent NOT EXISTS guards.

**Deviations from spec**: None. CompleteRefund / ApproveRefund / RejectRefund / ProcessRefund handlers retained but unreachable from FE.

**Known issues opened**: None.

**Known issues closed**: None.

**Build**: `dotnet build Base.Application.csproj` 0 CS errors / 0 warnings. Solution build: 6 MSB3021/3027 file-lock pre-existing.

**Next step**: User must run `Refund-sqlscripts.sql` to pick up the two new sett.Fields + sett.GridFields rows (entity/EF schema unchanged — RefundExchangeRate/RefundBaseCurrencyAmount/RefundedDate columns already exist from v2).

#### Session 16 — 2026-05-08 — UI — COMPLETED (FE)

**Scope**: Five FE-only fixes aligning the screen to the single-step REF-direct workflow + memory-rule UI polish (solid bg + white icons; chip-bg-white; remove duplicate Add).

**Files touched**:
- `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/refund-status-badge.tsx` — all 5 codes now solid bg + text-white; REF→emerald-600, REJ→rose-600, PEN/APR/PRO (legacy)→slate-500 with browser tooltip "Legacy workflow status…"; tabular-nums; dropped dark variants.
- `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/refund/refund-detail-drawer.tsx` — removed all workflow buttons (Approve/Reject/Process/Mark Complete) + Edit + Delete; REF/REJ → Print only; PEN/APR/PRO → italic "Legacy workflow — no further actions." Removed DELETE/PROCESS mutations + AlertDialog nodes + dead state/imports. Header icon container: bg-rose-100→bg-rose-600 text-white.
- `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/refund/refund-widgets.tsx` — KPI tiles simplified to 3: Refunded YTD (emerald-600 + ph:check-circle), Rejected (rose-600 + ph:x-circle), Legacy Pending (slate-500 + ph:hourglass-medium = sum of pending+approved+processing). All icon containers solid bg-X-600 + text-white.
- `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/refund/refund-filter-chips.tsx` — every chip bg-white + border; active → border-primary text-primary ring-2 ring-primary shadow-sm; count badge active=bg-primary text-white, inactive=bg-muted text-foreground.
- `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/refund/index-page.tsx` — removed top-level "+ New Refund Request" button (kept grid toolbar's enableAdd which DataTableAddOption handles natively); removed dead Button/Icon/useRouter/handleCreate; chip-change effect no longer calls setRefresh — relies on Apollo's natural in-place refetch when extraVariables change (no skeleton flash).

**Deviations from spec**: None. Modal files retained but unreachable. REFUNDS_QUERY already projects refundFeeAmount + contactCode (no query change needed for Task 5).

**Known issues opened**: None.

**Known issues closed**: None.

**Build**: `pnpm exec tsc --noEmit` clean (exit 0).

**Next step**: After running the SQL seed and restarting the API, full E2E: pick a donor → pick donation → channel locked Manual Payout → fill payout fields → Create. New refund should land at REF immediately, parent GD's PaymentStatus flips to Refunded, drawer opens at ?mode=read&id=X showing REF badge + Print button only.

---

#### Session 15 — 2026-05-08 — FIX — COMPLETED (BE)

**Scope**: Workflow simplification — CompleteRefund now accepts PEN/APR/PRO source states (only blocks REF/REJ terminal). Approval and Processing steps held in FE; BE remains permissive so any future re-introduction works without a second BE change.

**Files touched**:
- `Base.Application/Business/DonationBusiness/Refunds/Commands/CompleteRefund.cs` — relaxed source-state guard from `!= "PRO"` to `== "REF" || == "REJ"` terminal-only block; updated doc comment to reflect PEN|APR|PRO → REF contract.

**Deviations from spec**: None functional — just relaxed the source-state guard. All downstream logic (GD PaymentStatus flip, FX snapshot, ReceiptStatusAfterRefund, RefundedAmount sum, LastRefundedDate) unchanged.

**Known issues opened**: None.

**Known issues closed**: None (FE is concurrently disabling APR/PRO UI buttons in Session 15 FE work).

**Build**: 0 CS errors; 8 MSB3021/3027 file-lock pre-existing (VS Insiders + Base.API.exe holding dlls).

**Next step**: Restart the API to pick up the relaxed handler. FE Session 15 hides the Approve and Process workflow UI buttons.

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
| ISSUE-1 | 1 | HIGH | BE / Workflow | ProcessRefund is SERVICE_PLACEHOLDER — handler flips APR→PRO + sets ProcessingStartedDate but does NOT call gateway `IPaymentService.RefundAsync`. FE toast: "Refund queued for gateway processing (gateway integration pending)." | OPEN |
| ISSUE-2 | 1 | MED | BE / Cross-screen | GlobalDonation has no IsRefunded/RefundedAmount column; when Refund flips to REF, parent GD is not flagged. Surface refunds only via Refund screen for MVP. | OPEN |
| ISSUE-3 | 1 | MED | BE / Data | `paymentMaskedDetails` projection left NULL — PaymentTransaction join deferred. FE falls back to "Same as original payment method". | CLOSED (session 2) |
| ISSUE-4 | 1 | MED | BE / Validation | OTH-reason note enforcement is in BOTH CreateRefund validator AND handler (reason MasterData lookup + DataCode check). Implemented. | CLOSED |
| ISSUE-5 | 1 | MED | BE / Auto-code | RefundCode auto-gen (`REF-{NNNN}` per Company) — uses per-company Max+1 pattern in handler. Advisory code (no uniqueness constraint). | CLOSED |
| ISSUE-6 | 1 | MED | BE / GD Picker | `excludeRefunded` arg on `globalDonations` uses LINQ `!dbContext.Refunds.Any(...)` → EF generates NOT EXISTS SQL. Verified. | CLOSED |
| ISSUE-7 | 1 | MED | BE / Multi-currency | Summary KPI sums convert refund amounts to base currency using GD.ExchangeRate → Currency.CurrencyRate → 1:1 fallback (documented in handler as `MULTI_CURRENCY`). | CLOSED |
| ISSUE-8 | 1 | MED | FE / Renderer | `refund-status-badge` renders completion-date suffix ("Refunded (MMM d)") for REF rows by reading `row.refundedDate` from cell-renderer row context. Implemented. | CLOSED |
| ISSUE-9 | 1 | LOW | BE / GD Picker | Donation Picker locked-selection edge case — combobox accepts `locked` prop in edit mode, renders preview only. Implemented. | CLOSED |
| ISSUE-10 | 1 | MED | FE / Filter chips | FE wired chip filter via FlowDataTable `setQuickFilter` → `advancedFilter` predicate on `refundStatus.dataValue` (ChequeDonation #6 precedent). BE's dedicated `refundStatusCodes: [String]` GQL arg is available but UNUSED. Filtering works but not through optimal path. Revisit if chip badge counts desync from grid rows. | CLOSED (session 2) |
| ISSUE-11 | 1 | LOW | FE / Renderer reuse | `donor-link` renderer already existed at `shared-cell-renderers/donor-link.tsx` (authored for ChequeDonation #6). Refund reused — no new file. | CLOSED |
| ISSUE-12 | 1 | LOW | FE / Detail UX | 600px right-side drawer chosen (Pledge #12 precedent) with 7 scrollable section cards. Alternative full-page detail deferred. | CLOSED |
| ISSUE-13 | 1 | LOW | Future | Multi-partial-refund support deferred. MVP enforces 1 Refund per GlobalDonation via DB unique filtered index + validator. Re-open when business relaxes the rule. | OPEN |
| ISSUE-14 | 1 | LOW | FE / Print | Print Receipt button is SERVICE_PLACEHOLDER — toast "Receipt PDF generation pending — coming soon." | OPEN |
| ISSUE-15 | 1 | LOW | DB / Seed | Seed file placed at `sql-scripts-dyanmic/Refund-sqlscripts.sql` — preserves repo typo. Inherited platform-wide convention. | CLOSED |
| ISSUE-16 | 1 | MED | BE / Migration | EF Migration `.cs` written but ApplicationDbContextModelSnapshot not hand-updated. To apply via `dotnet ef database update`, team should run `dotnet ef migrations add Add_Refund_Snapshot_Sync` to regenerate the Designer.cs + snapshot for reconciliation, OR execute the migration's `Up()` SQL directly. Flagged as pragmatic choice. | OPEN |
| ISSUE-17 | 1 | LOW | FK path docs | Prompt §③ listed wrong folder paths for MasterData / Staff / Currency (said `CorgModels`; actual = `SettingModels` / `ApplicationModels` / `SharedModels`). Corrected during build; entity files unchanged. | CLOSED |
| ISSUE-V2-1 | 3 | HIGH | BE / Workflow | Real gateway integration (Stripe Refunds API / Razorpay / PayPal) remains a SERVICE_PLACEHOLDER. v2 captures channel/currency/originalFee/txnId for later integration; the actual API call still toasts "Refund queued for gateway processing". `CompleteRefundHandler` kept its name (not renamed to `ExecuteRefundHandler`). | OPEN |
| ISSUE-V2-2 | 3 | HIGH | BE / Architecture | `IFxRateService` already existed at `Base.Application/Interfaces/IFxRateService.cs`. Real signature: `GetRateAsync(string fromCode, string toCode, DateOnly asOfDate, ct) → decimal?` (codes-based, NOT IDs as spec assumed). All v2 handlers do ID→Code lookup against `dbContext.Currencies` first, then call the service. `currentFxRate` GraphQL query takes `fromCurrencyId/toCurrencyId` (FE convenience) and resolves internally. | CLOSED |
| ISSUE-V2-3 | 3 | MED | BE / Receipt | Receipt revision for PARTIAL refunds — flips `Refund.ReceiptStatusAfterRefund='REVISED'` only; no linked-row mutation. Spec assumed `GlobalReceipt` entity exists but only `GlobalReceiptDonations` junction does. Issuance of revised receipt PDF (and/or new revised GR row) OUT OF SCOPE. | OPEN |
| ISSUE-V2-4 | 3 | LOW | FE / Grid | Channel badge column in grid (replace `RefundMethodLabel` text with 2-line badge cell). Cosmetic — deferred. | OPEN |
| ISSUE-V2-5 | 3 | LOW | BE / Backward-compat | `RefundMethodLabel` legacy field — `CompleteRefundHandler` regenerates it on save via `RefundChannelHelper.BuildRefundMethodLabel(...)` (GATEWAY_REVERSAL → "Gateway: {gatewayName} (txn {txnId})"; MANUAL_PAYOUT → "{paymentModeName} {— last4 of account}"). | CLOSED |
| ISSUE-V2-6 | 3 | LOW | FE / Form | Currency override at refund-create — `RefundCurrencyId` defaults to GD currency; v2 form does NOT expose override picker. "Donor switched currency" case rare enough to defer. | OPEN |
| ISSUE-V2-7 | 3 | LOW | BE+FE / Dict | Gateway fee-recoverability — small static dict in BOTH BE (`RefundChannelHelper.GatewayFeeRecoverable`) and FE (`refund-channel-fieldset.tsx FEE_RECOVERABILITY`). Stripe/Square→true; Razorpay/PayPal/Cashfree/Authorize→false; default→null. Externalize to config table only if matrix grows. | CLOSED |
| ISSUE-V2-8 | 3 | LOW | BE / Dict | Per-mode required-field map dictionary-driven on BE (`RefundChannelHelper.ManualRequiredByModeCode`). As more rails added, dict grows. Externalization to config table deferred. | CLOSED |
| ISSUE-V2-9 | 3 | MED | BE / UTC | All `DateTime` to BE has `Kind=Utc` per [feedback_db_utc_only.md]. Handler uses `DateTime.UtcNow` for refund-execute timestamp; FX rate lookup uses `DateOnly.FromDateTime(DateTime.UtcNow)`. Never `DateTime.Now` / `DateTime.Today`. | CLOSED |
| ISSUE-V2-10 | 3 | LOW | BE / Picker | Donation-picker BE projection extension — additive, existing v1 picker callers don't break. BE added flat `GatewayCode` + `GatewayTxnId` (new); reused existing `BaseCurrencyId` + `BaseCurrency.CurrencyCode` nav DTO + `ExchangeRate` + `FeeAmount`. FE GQL query patched to read BE's actual field shape (`baseCurrencyId` + `baseCurrency { currencyCode }` not the spec-named flat `companyBaseCurrency*`); the picker's `toPickerValue` mapper translates to public-facing names. | CLOSED |
| ISSUE-V2-11 | 3 | LOW | FE / Drawer | Drawer FX Snapshot card displays placeholder "Charity Base" label instead of actual ISO code. Resolve later by adding `chargeBaseCurrencyCode` projection to `RefundResponseDto`. | OPEN |
| ISSUE-V2-12 | 3 | LOW | FE / Drawer | Drawer FX Delta row hidden (`showFxDelta=false`). Resolve later by adding `originalDonationExchangeRate` projection to `RefundResponseDto` so drawer can compute `(refundExchangeRate − originalDonationExchangeRate) × refundAmount` without a second query. | OPEN |
| ISSUE-V2-13 | 3 | LOW | FE / Drawer | GATEWAY_REVERSAL fee-recoverability lookup in drawer keys the dict by `paymentModeName`. Should key by gateway code (STRIPE/RAZORPAY/etc) — accuracy improvement. Resolve by projecting `originalGatewayCode` onto Refund row. | OPEN |
| ISSUE-V2-14 | 3 | MED | BE / Migration | Migration `20260505120000_Add_RefundChannelAndFxSnapshot.cs` written but Designer.cs + ApplicationDbContextModelSnapshot.cs NOT hand-edited (~22K-line snapshot, high corruption risk). Team must run `dotnet ef migrations add Add_Refund_V2_Snapshot_Sync` to regenerate snapshot before applying, or execute the migration's `Up()` SQL directly. Mirrors v1 ISSUE-16. | OPEN |
| ISSUE-V2-15 | 6 | MED | BE / Perf | Refund donor dropdown is **mitigated, not fully fixed**. BE `GetContactHandler` runs 6 enrichment subqueries per paginated page (latest GlobalDonation per contact, ContactTags, ContactTypeAssignments, primary email, primary phone, ContactBaseType DataValue) regardless of GraphQL field selection. Session 5 attempted a `forPicker` opt-out flag; user reverted that approach and chose FE-only mitigation (`initialPageSize=10` cap on the picker). Future architectural fix: (a) dedicated `getContactsForPicker` resolver, (b) move enrichment to Hot Chocolate field-level resolvers gated by HC field selection, or (c) lazy projection in Mapster/EF. Same-pattern picker calls in donation-form #1 / pledge-form #12 / distribution-grid / add-purpose-dialog / bulk-donation-page are also affected but not in scope here. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-21 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FULL scope (BE + FE + DB seed).
- **Files touched**:
  - **BE (17 created, 7 modified)**:
    - created: `Base.Domain/Models/DonationModels/Refund.cs` (entity), `Base.Infrastructure/Data/Configurations/DonationConfigurations/RefundConfiguration.cs`, `Base.Application/Schemas/DonationSchemas/RefundSchemas.cs`, `Base.Application/Business/DonationBusiness/Refunds/Commands/{CreateRefund,UpdateRefund,DeleteRefund,ToggleRefund,ApproveRefund,RejectRefund,ProcessRefund,CompleteRefund}.cs` (8 commands), `.../Refunds/Queries/{GetRefunds,GetRefundById,GetRefundSummary}.cs` (3 queries), `Base.API/EndPoints/Donation/Mutations/RefundMutations.cs`, `Base.API/EndPoints/Donation/Queries/RefundQueries.cs`, `Base.Infrastructure/Migrations/20260421120000_Add_Refund.cs`, `sql-scripts-dyanmic/Refund-sqlscripts.sql`
    - modified: `Base.Application/Data/Persistence/IDonationDbContext.cs` (added Refunds DbSet), `Base.Infrastructure/Data/Persistence/DonationDbContext.cs` (added Refunds DbSet), `Base.Application/Extensions/DecoratorProperties.cs` (added `Refund = "REFUND"` to DecoratorDonationModules), `Base.Application/Mappings/DonationMappings.cs` (added Mapster configs for Refund↔DTOs with projected GD/Contact/Currency/DonationMode/MasterData/Staff fields), `Base.Application/Business/DonationBusiness/GlobalDonations/Queries/GetGlobalDonations.cs` (added `excludeRefunded` arg), `Base.API/EndPoints/Donation/Queries/GlobalDonationQueries.cs` (exposed `excludeRefunded: Boolean` GQL arg)
  - **FE (20 created, 10 modified)**:
    - created: `domain/entities/donation-service/RefundDto.ts`, `infrastructure/gql-queries/donation-queries/RefundQuery.ts`, `infrastructure/gql-mutations/donation-mutations/RefundMutation.ts`, `presentation/components/custom-components/data-tables/shared-cell-renderers/{original-donation-link,refund-amount-cell,refund-type-badge,reason-tag,refund-status-badge}.tsx` (5 renderers), `presentation/pages/crm/donation/refund.tsx`, `presentation/components/page-components/crm/donation/refund/{index,index-page,view-page,refund-store,refund-widgets,refund-filter-chips,refund-advanced-filters,refund-donation-picker,refund-create-form,refund-form-schemas,refund-detail-drawer,refund-activity-timeline,refund-approval-modal,refund-rejection-modal,refund-complete-modal}.tsx|ts` (15 files)
    - modified: `domain/entities/donation-service/index.ts` (barrel), `infrastructure/gql-queries/donation-queries/index.ts` (barrel), `infrastructure/gql-mutations/donation-mutations/index.ts` (barrel), `presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (5 renderer exports), `presentation/components/custom-components/data-tables/{advanced,basic,flow}/data-table-column-types/component-column.tsx` (3 registries × 5 new switch cases), `presentation/pages/crm/donation/index.ts` (pages barrel), `application/configs/data-table-configs/donation-service-entity-operations.ts` (REFUND gridCode entry), `app/[lang]/crm/donation/refund/page.tsx` (stub overwritten in place — mounts RefundPageConfig)
  - **DB**: `sql-scripts-dyanmic/Refund-sqlscripts.sql` (created — menu + capabilities + role grants + grid + 10 gridfields + 5 REFUNDSTATUS + 6 REFUNDREASON)
- **Build verification**:
  - BE: `dotnet build` on PeopleServe.sln → **0 errors / 86 warnings** (all warnings pre-existing, none introduced).
  - FE: `pnpm tsc --noEmit` → **0 Refund-specific errors** (12 pre-existing errors in unrelated screens: ChequeDonation barrel, RecurringDonors form, AuctionManagement, EventTicketing, DuplicateContact, CommonFormFields).
  - Static validation: 5 new renderers registered in all 3 component-column registries (advanced/basic/flow) + shared-cell-renderers barrel. Entity operations config has REFUND entry wired to all 8 mutations + 2 queries.
- **Deviations from spec**:
  - Command folder structure: flat `Refunds/Commands/*.cs` (not per-command subfolders as prompt §⑧ suggested — matched sibling DonationInKinds/GlobalDonations pattern).
  - FK folder paths: used actual (`SettingModels`/`ApplicationModels`/`SharedModels`) rather than prompt §③'s incorrect `CorgModels` references (ISSUE-17, CLOSED).
  - Chip filter wiring: FE used FlowDataTable's `setQuickFilter` → `advancedFilter` predicate path rather than the BE's dedicated `refundStatusCodes: [String]` top-level GQL arg. Filtering works via the generic predicate path (ChequeDonation #6 precedent). Flagged as ISSUE-10 OPEN — revisit if chip badge counts desync.
  - EF Migration snapshot not hand-updated (ISSUE-16, OPEN) — team must run `dotnet ef migrations add Add_Refund_Snapshot_Sync` before applying, or execute `Up()` SQL directly.
  - Process Refund (APR→PRO) implemented as direct transition (no modal) — matches spec (§⑥ row actions table specifies "ProcessRefund cmd + toast", no modal).
- **Known issues opened**: ISSUE-16 (EF snapshot manual reconciliation needed), ISSUE-10 (chip filter uses advancedFilter path, not dedicated args), ISSUE-17 (prompt §③ FK paths were wrong — documented).
- **Known issues closed**: ISSUE-4, ISSUE-5, ISSUE-6, ISSUE-7, ISSUE-8, ISSUE-9, ISSUE-11, ISSUE-12, ISSUE-15, ISSUE-17 (10 of 17).
- **Next step**: (empty — completed)

### Session 2 — 2026-05-05 — FIX — COMPLETED

- **Scope**: Close two of seven OPEN known issues without touching the spec — ISSUE-3 (synthesize `paymentMaskedDetails` from sibling rows) and ISSUE-10 (push status-chip filter as the dedicated `refundStatusCodes: [String!]` top-level GQL arg). Larger spec-change request (refund-method + tax + fees + per-method tracking) deferred to a separate `/plan-screens #13` cycle per the user's direction.
- **Files touched**:
  - **BE (2 modified)**:
    - `Base.Application/Business/DonationBusiness/Refunds/Queries/GetRefunds.cs` — projection block extended with `OnlineMethodName` / `OnlineReferenceTail` / `ChequeNo` / `ChequeAccountLast4` (latest-row sub-projections over `GlobalDonation.GlobalOnlineDonations` + `GlobalDonation.ChequeDonations`); post-map now calls new `BuildPaymentMaskedDetails(...)` helper. Helper appended to `GetRefundsHandler` as `internal static`.
    - `Base.Application/Business/DonationBusiness/Refunds/Queries/GetRefundById.cs` — same projection fields added; post-map reuses `GetRefundsHandler.BuildPaymentMaskedDetails(...)`.
  - **FE (2 modified)**:
    - `presentation/components/page-components/crm/donation/refund/index-page.tsx` — replaced the ~50-line `setQuickFilter` advancedFilter-predicate block with a 4-line `setExtraVariables({ refundStatusCodes: codes })` call (Family-screen precedent). `setQuickFilter` import dropped; `setExtraVariables` added.
    - `presentation/components/page-components/crm/donation/refund/refund-filter-chips.tsx` — header doc-comment updated to describe the new wiring path.
  - **DB**: none.
- **Build verification**:
  - BE: `dotnet build PeopleServe.sln` → 0 `error CS####` (compile errors). 8 reported errors are `MSB3021`/`MSB3027` file-lock failures from Visual Studio Insiders holding `Base.API.dll` (Base.API process 28048 running) — pre-existing dev-env issue, not introduced by this session. Compilation of the 3 modified files succeeded.
  - FE: `pnpm exec tsc --noEmit` → exit 0, 0 lines of output (clean type-check).
  - Did NOT run `pnpm dev` E2E manual exercise — fix is structurally simple and BE↔FE contracts on `refundStatusCodes` and `paymentMaskedDetails` were already in place from Session 1; runtime verification is owed when the user picks this branch up.
- **Deviations from spec**:
  - ISSUE-3 derivation chose synthesis from `GlobalOnlineDonation.PaymentMethod`+`GatewayReferenceNo` and `ChequeDonation.ChequeNo`+`AccountNoLast4` rather than the prompt §⑫ ISSUE-3 plan ("`Include(d => d.PaymentTransactions)`"). Reason: `GlobalDonation` has no FK or nav to `PaymentTransaction` in the current schema; `PaymentTransaction.MaskedPAN` does not exist. Synthesis from the existing `GlobalOnlineDonations`/`ChequeDonations` collections gives equivalent human-readable masked detail without introducing a new FK.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-3, ISSUE-10 (2 of 7 prior OPEN).
- **Next step**: (empty — completed). User to invoke `/plan-screens #13` for the refund-method + tax + fees spec extension. Remaining 5 OPEN issues (ISSUE-1 gateway integration, ISSUE-2 GD cross-screen schema add, ISSUE-13 multi-partial future, ISSUE-14 PDF infra, ISSUE-16 EF snapshot manual) are blocked on platform infra / cross-screen design / local CLI and stay deferred.

### Session 3 — 2026-05-05 — BUILD — COMPLETED (v2 — Realtime Refund Flow)

- **Scope**: Enhancement v2 build per the prompt's "## ⓘ Enhancement v2" section — channel auto-routing (GATEWAY_REVERSAL vs MANUAL_PAYOUT), FX snapshot at refund-EXECUTE, original gateway fee snapshot, fee-recoverability transparency, per-rail manual-payout required-fields, receipt-status tracking. ALIGN scope (additive — 11 new columns, no new entities, no junction, no DB seed changes, no menu/grid/capability changes). Industry-aligned with Stripe/Razorpay/PayPal/Donorbox patterns.
- **Files touched**:
  - **BE (3 created, 10 modified)**:
    - created: `Base.Application/Business/SharedBusiness/Currencies/Queries/GetCurrentFxRate.cs` (new GQL query + handler — resolves ID→Code, calls existing `IFxRateService.GetRateAsync(fromCode, toCode, DateOnly.FromDateTime(DateTime.UtcNow))`, short-circuits same-ccy to 1.0, returns null on direct-pair miss); `Base.Application/Business/DonationBusiness/Refunds/Commands/RefundChannelHelper.cs` (shared static helper — `OnlineGatewayCodes` HashSet, `ManualReqMask` `[Flags]` enum, `ManualRequiredByModeCode` Dictionary per-rail required-field map, `GatewayFeeRecoverable` Dictionary per ISSUE-V2-7, `BuildRefundMethodLabel` helper per ISSUE-V2-5); `Base.Infrastructure/Data/Migrations/20260505120000_Add_RefundChannelAndFxSnapshot.cs` (ALTER `fund."Refunds"` ADD 11 cols + index on `RefundChannelCode` + FKs `RefundCurrencyId→com."Currencies"` and `ManualPaymentModeId→com."PaymentModes"` both NoAction; safe defaults `'GATEWAY_REVERSAL'` + `'UNCHANGED'`)
    - modified: `Refund.cs` (+11 cols, +2 nav `RefundCurrency`/`ManualPaymentMode`); `RefundConfiguration.cs` (precision 18,2 / 18,8 / MaxLength / FK NoAction / index on channel / defaults); `RefundSchemas.cs` (Request +7 input fields, Response +14 fields incl. 3 projections, +`CurrentFxRateResponseDto`); `CreateRefund.cs` (validator: channel ↔ manual tamper guard + fee≥0; handler: eager-load `DonationMode`+`GlobalOnlineDonations`, auto-derive channel via `RefundChannelHelper.OnlineGatewayCodes` + online-presence; per-mode required check via `ManualRequiredByModeCode`; snapshot `OriginalGatewayFeeAmount` from `gd.FeeAmount`; default `RefundCurrencyId = gd.CurrencyId`; clear manual fields on GATEWAY_REVERSAL); `UpdateRefund.cs` (same validator/handler treatment; preserves `OriginalGatewayFeeAmount`); `CompleteRefund.cs` (injected `IFxRateService`; resolves charity base via `CompanyConfigurations.BaseCurrencyId`; ID→Code via `dbContext.Currencies`; populates `RefundExchangeRate` + `RefundBaseCurrencyAmount = Math.Round(RefundAmount × rate, 2)`; null-on-miss leaves cols null; sets `ReceiptStatusAfterRefund` = CANCELLED for FULL / REVISED for PARTIAL / UNCHANGED if no linked `GlobalReceiptDonations.Any`; regenerates `RefundMethodLabel` via helper; normalizes `executeUtc.Kind=Utc` per [feedback_db_utc_only.md]); `GetRefunds.cs` (Include `RefundCurrency` + `ManualPaymentMode`, +14 projection fields); `GetRefundById.cs` (same); `DonationMappings.cs` (extended Mapster `Refund→RefundResponseDto`, +3 projection mappings, +`Ignore` for nav inverses); `GetGlobalDonations.cs` + `GlobalDonationSchemas.cs` (picker projection extension — ISSUE-V2-10 — added flat `GatewayCode` + `GatewayTxnId`; reused existing `BaseCurrencyId` + `BaseCurrency` nav DTO + `ExchangeRate` + `FeeAmount` instead of duplicating as flat `companyBaseCurrency*`); `Base.API/EndPoints/Shared/Queries/CurrencyQueries.cs` (appended `[GraphQLName("currentFxRate")]` endpoint method)
  - **FE (3 created, 8 modified)**:
    - created: `infrastructure/gql-queries/shared-queries/CurrentFxRateQuery.ts` (new GQL query + types + barrel export); `presentation/components/page-components/crm/donation/refund/refund-channel-fieldset.tsx` (channel radio + `useWatch` setValue cleanup on flip; GATEWAY_REVERSAL render with solid-bg fee-recoverability banner per [feedback_widget_icon_badge_styling.md]; MANUAL_PAYOUT render with `<ApiSelectV2>` `PAYMENTMODES_QUERY` + per-mode dynamic fields BANK_TRANSFER/UPI/MOBILE_MONEY/CHEQUE/PAYPAL/CASH; hidden form-stash field `manualPaymentModeCode` populated by picker for downstream); `presentation/components/page-components/crm/donation/refund/refund-charges-fx-fieldset.tsx` (Refund Fee input + Net to Donor calc + conditional FX block via `useQuery(GET_CURRENT_FX_RATE, { skip: same-ccy })`; null-rate "FX rate unavailable" banner; signed FX impact green/red coloring per gain/loss)
    - modified: `domain/entities/donation-service/RefundDto.ts` (Request +7 input fields; Response +14 fields incl. 3 projections); `infrastructure/gql-queries/donation-queries/RefundQuery.ts` (GetRefunds + GetRefundById +14 fields each; `GlobalDonationsForRefundPicker` extended with `exchangeRate`/`feeAmount`/`baseCurrencyId`/`baseCurrency.currencyCode`/`gatewayCode`/`gatewayTxnId` — patched mid-build to match BE shape per ISSUE-V2-10); `infrastructure/gql-mutations/donation-mutations/RefundMutation.ts` (+4 echo fields on Create/Update success); `refund-form-schemas.ts` (REFUND_CHANNEL_GATEWAY/MANUAL constants + 8 new base-schema fields incl. hidden `manualPaymentModeCode` + `superRefine` channel ↔ manualPaymentModeId presence; per-mode required map intentionally enforced on BE only); `refund-donation-picker.tsx` (`DonationPickerValue` extended; `RawDonationRow` interface adapted to BE's actual `baseCurrencyId`+`baseCurrency.currencyCode` shape; `toPickerValue` mapper translates BE shape → public-facing `companyBaseCurrencyId/Code`); `refund-create-form.tsx` (imports new fieldsets; donation-state initializer hydrates 7 new picker fields on edit-mode bootstrap; `handleDonationSelect` auto-derives channel from `donation.gatewayCode` + seeds `refundCurrencyId`; Section 3 → `<RefundChannelFieldset>`, Section 4 → `<RefundChargesFxFieldset>`, Notes → Section 5); `refund-detail-drawer.tsx` (Card 3 replaced with `<ChannelDetail>` rendering both modes with masked-account display + fee-recoverability lookup; Card 4 `<ChargesDetail>` extended with `originalGatewayFeeAmount` + `receiptStatusAfterRefund` badge; conditional `<FxSnapshotDetail>` card inserted between Charges and Approval Trail when `refundExchangeRate != null && refundBaseCurrencyAmount != null`); `view-page.tsx` (submit payload extended with 7 new input fields; defensive null-out of `manualBeneficiary*` on GATEWAY_REVERSAL)
  - **DB**: NO seed changes — existing `com.PaymentModes` rows reused for manual-payout picker.
- **Build verification**:
  - BE: `dotnet build PeopleServe.sln` → **0 `error CS####` C# compile errors**, 499 warnings (pre-existing CA/CS analyzer baseline). 8 errors are MSB3021/MSB3027 file-lock errors caused by Visual Studio Insiders + running `Base.API.exe` (process 28048) holding the dlls — pre-existing dev-env issue per Session 2 precedent. Compilation succeeded for every project; only the post-build dll copy step into `Base.API\bin\Debug\net10.0\` was blocked.
  - FE: `pnpm exec tsc --noEmit` → **exit 0, 0 lines of output**. Whole-FE TypeScript clean — improved over v1 baseline of 12 unrelated-screen errors (intervening sessions resolved them).
  - UI uniformity grep checks on the 3 NEW FE files: 0 inline-hex / 0 inline-px / 0 `>Loading...</` / 0 inline `style={{`.
  - Did NOT run `pnpm dev` E2E manual exercise — runtime verification deferred per token-budget directive.
- **Deviations from spec**:
  - `IFxRateService` API divergence (real signature codes-based + `DateOnly`, not IDs + `DateTime`) — handlers do ID→Code lookup against `dbContext.Currencies` first. ISSUE-V2-2 closed.
  - `GlobalReceipt` entity does not exist — only `GlobalReceiptDonations` junction. Receipt-row flip dropped; `ReceiptStatusAfterRefund` tracked on Refund row only. ISSUE-V2-3 captures the deferred PDF revision.
  - GD picker projection — BE didn't add flat `companyBaseCurrencyId`/`companyBaseCurrencyCode`; relies on existing `BaseCurrencyId` + `BaseCurrency` nav DTO. FE GQL query + `RawDonationRow` patched mid-build to match; mapper translates to public-facing names. ISSUE-V2-10.
  - Per-mode required-field map — enforced on BE handler (post-PaymentMode load), NOT in FE Zod schema (pragmatic — `PaymentModeCode` requires DB lookup). FE schema only checks `manualPaymentModeId` presence. Documented in `refund-form-schemas.ts`.
  - Migration Designer.cs + ApplicationDbContextModelSnapshot.cs NOT hand-edited (~22K-line snapshot, high corruption risk). Migration carries TODO comment for `dotnet ef migrations add Add_Refund_V2_Snapshot_Sync` reconciliation. ISSUE-V2-14 (mirrors v1 ISSUE-16).
  - `CompleteRefundHandler` kept its name (not renamed to `ExecuteRefundHandler` as ISSUE-V2-1 suggested) — keeps backward-compat with v1 mutation surface.
- **Known issues opened**: ISSUE-V2-1 (HIGH gateway integration still placeholder), ISSUE-V2-3 (MED revised PDF deferred), ISSUE-V2-4 (LOW channel grid badge), ISSUE-V2-6 (LOW currency override picker), ISSUE-V2-11 (LOW drawer charity-base label placeholder), ISSUE-V2-12 (LOW drawer FX delta hidden), ISSUE-V2-13 (LOW drawer fee-recoverability dict key accuracy), ISSUE-V2-14 (MED EF snapshot manual reconciliation needed).
- **Known issues closed**: ISSUE-V2-2 (IFxRateService API integration), ISSUE-V2-5 (RefundMethodLabel regen), ISSUE-V2-7 (fee-recoverability dict on both sides), ISSUE-V2-8 (per-mode required map dict), ISSUE-V2-9 (UTC normalization), ISSUE-V2-10 (GD picker projection — patched FE↔BE shape mismatch).
- **Next step**: User to apply migration manually:
  1. `dotnet ef migrations add Add_Refund_V2_Snapshot_Sync --project Base.Infrastructure --startup-project Base.API --context ApplicationDbContext` to reconcile snapshot
  2. `dotnet ef database update --project Base.Infrastructure --startup-project Base.API --context ApplicationDbContext`
  3. Stop `Base.API.exe` (process 28048) before build to clear file-lock errors
  4. `dotnet build` clean
  5. `pnpm dev` and run full E2E per v2 acceptance criteria (channel auto-routing, manual-payout per-rail fields, FX block on cross-currency, FX snapshot at execute, receipt status flip, drawer Channel/Charges/FX cards)

### Session 4 — 2026-05-07 — FIX — COMPLETED

- **Scope**: User-reported bug — donor dropdown in `?mode=new` create form felt frozen on click. Root cause: the form's Step-1 donor `<FormSearchableSelect>` was wired to the heavy `CONTACTS_QUERY` (which projects `customFields` JSON, 8 nested joins, plus per-row computed `engagementScore` / `lastDonationAmount` / `lastDonationDate` / `tagList` / `contactTypeList` / `dropdownLabel`) at default `pageSize=50` with no `advancedFilter`. On a busy tenant the BE projection takes 10–30s per fetch, leaving the popover stuck on the gradient loader → user perceived freeze. Localized fix only — other consumers of `CONTACTS_QUERY` (donation-form, pledge-form, distribution-grid, add-purpose-dialog, bulk-donation-page) intentionally untouched.
- **Files touched**:
  - **FE (1 created, 1 modified)**:
    - created: `infrastructure/gql-queries/donation-queries/RefundQuery.ts` — appended new export `CONTACTS_FOR_REFUND_PICKER_QUERY` (4-field projection: `contactId / contactCode / displayName / dropdownLabel`; no joins, no computed columns, hits the same `contacts` resolver so no BE change required).
    - modified: `presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` — swapped `CONTACTS_QUERY` import → `CONTACTS_FOR_REFUND_PICKER_QUERY`; added `initialPageSize={20}` to the donor `<FormSearchableSelect>`; added comment block documenting the why.
  - **BE**: none.
  - **DB**: none.
- **Build verification**:
  - FE: `pnpm exec tsc --noEmit` → exit 0, clean.
  - Did NOT run `pnpm dev` E2E manual exercise — fix is structurally simple (query swap, no behavioral changes to picker / form / submit). Runtime verification owed when user picks this branch up; expected outcome is sub-second popover open.
- **Deviations from spec**: None. The original spec (§③ "Donation Picker UX") expected a custom search-as-you-type combobox over `globalDonations`, which had been authored at `refund-donation-picker.tsx` but turned out to be **dead code** (never imported as JSX) — Session 1 implemented a two-step donor→donation pattern via two `<FormSearchableSelect>` widgets instead. This session preserves that two-step UX; the dead `refund-donation-picker.tsx` file is left in place for now (could be removed in a future cleanup).
- **Known issues opened**: None.
- **Known issues closed**: None — this bug was not in the prior Known Issues table; it was newly discovered runtime behavior. Logged here for audit.
- **Next step**: User to run `pnpm dev` and confirm the donor dropdown now opens within ~1s on the create form.

### Session 5 — 2026-05-07 — FIX — COMPLETED

- **Scope**: Session 4's FE-only projection trim did NOT fix the donor dropdown freeze — user re-tested and reported it still hangs. Real bottleneck identified by inspecting [GetContact.cs:85-246](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Queries/GetContact.cs#L85-L246): `GetContactHandler` always runs **6 post-pagination enrichment subqueries per call** regardless of GraphQL projection — fetches latest GlobalDonation per contact, ContactTags, ContactTypeAssignments, primary email, primary phone, ContactBaseType DataValue. That's the "contact + receipt" combined fetch the user diagnosed (LastDonationAmount + LastDonationDate are the receipt-side cost). FE projection trimming alone can't shed that latency since Hot Chocolate doesn't propagate field selection into post-handler enrichment. Solved with a BE opt-out flag.
- **Files touched**:
  - **BE (2 modified)**:
    - `Base.Application/Business/ContactBusiness/Contacts/Queries/GetContact.cs` — extended `GetContactsQuery` record with optional `bool? forPicker = false` parameter; gated the entire post-pagination enrichment block (lines 85-246) on `query.forPicker != true`. Default-false preserves all existing callers (donation-form, contacts grid, pledge-form, distribution-grid, add-purpose-dialog, bulk-donation-page, ExportContact handler) unchanged.
    - `Base.API/EndPoints/Contact/Queries/ContactQueries.cs` — `GetContacts` endpoint accepts `bool? forPicker` arg from GraphQL, passes through to `new GetContactsQuery(request, forPicker)`. Hot Chocolate exposes it as a nullable Boolean arg on the `contacts` resolver.
  - **FE (1 modified)**:
    - `infrastructure/gql-queries/donation-queries/RefundQuery.ts` — `CONTACTS_FOR_REFUND_PICKER_QUERY` now passes `forPicker: true` literal in the resolver call. Updated docstring explains why FE-only projection wasn't enough (handler enrichment outranks projection).
  - **DB**: none.
- **Build verification**:
  - BE: `dotnet build Base.Application` → **exit 0**, clean compile.
  - FE: `pnpm exec tsc --noEmit` → **exit 0**, clean type-check.
  - Did NOT run `pnpm dev` E2E — change is structural (additive flag with default-false; no behavior change for existing callers; sole new code path is `forPicker == true → skip enrichment`). Expected outcome: refund donor dropdown popover renders contact rows in <1s; other CONTACTS_QUERY consumers unchanged.
- **Deviations from spec**: None. The added `forPicker` flag is a pure performance opt-out — no schema, no DTO, no contract change. Other consumers can opt in later screen-by-screen if they hit the same bottleneck (donation-form #1, pledge-form #12, etc are candidates but not in scope here).
- **Known issues opened**: None.
- **Known issues closed**: None — bug was new runtime feedback, not a Known Issue.
- **Next step**: User runs `pnpm dev` (FE) + `dotnet run` (BE), opens `/[lang]/crm/donation/refund?mode=new`, clicks the donor dropdown, confirms popover lists contacts within ~1s. If still slow, the bottleneck has shifted to network / Apollo / DB indexing and a different cut is needed.

### Session 6 — 2026-05-07 — FIX — COMPLETED

- **Scope**: Roll back Session 5's BE-flag approach per user direction. The `forPicker` arg ended up reverted out of `ContactQueries.cs` endpoint while the handler still expected it, leaving Hot Chocolate without a registered arg → "The argument `forPicker` does not exist." runtime error. User chose **FE-only mitigation** (cap pageSize) over re-applying the BE flag or adding a dedicated picker resolver.
- **Files touched**:
  - **BE (1 modified — rollback)**:
    - `Base.Application/Business/ContactBusiness/Contacts/Queries/GetContact.cs` — reverted `GetContactsQuery` record back to single-param `(GridFeatureRequest gridFilterRequest)` and removed the `query.forPicker != true` gate around the enrichment block. Handler is now byte-identical to its pre-Session-5 state.
  - **FE (2 modified)**:
    - `infrastructure/gql-queries/donation-queries/RefundQuery.ts` — `CONTACTS_FOR_REFUND_PICKER_QUERY` no longer passes `forPicker: true` (BE doesn't accept it). Docstring updated to flag the BE enrichment caveat as still-unresolved.
    - `presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` — donor `<FormSearchableSelect>` `initialPageSize={20}` → `initialPageSize={10}` (mitigation: BE enrichment still runs but over half as many rows).
  - **DB**: none.
  - **Endpoint** `Base.API/EndPoints/Contact/Queries/ContactQueries.cs` — already reverted out-of-band; matches pre-Session-5 state.
- **Build verification**:
  - BE: `dotnet build Base.Application` → **exit 0**, clean compile.
  - FE: `pnpm exec tsc --noEmit` → **exit 0**, clean type-check.
- **Deviations from spec**: None. The lightweight `CONTACTS_FOR_REFUND_PICKER_QUERY` (4-field projection) is retained even though Hot Chocolate doesn't propagate field selection into the BE enrichment block — keeping the small projection means the network payload stays tiny even if BE work is unchanged.
- **Known issues opened**: ISSUE-V2-15 — donor dropdown is mitigated, not fully fixed. The BE `GetContactHandler` still runs 6 enrichment subqueries (latest GlobalDonation, ContactTags, ContactTypeAssignments, primary email, primary phone, ContactBaseType DataValue) for every paginated row regardless of GraphQL projection. With `pageSize=10` the BE work is bounded but a future architectural fix is needed: either (a) dedicated picker resolver `getContactsForPicker`, (b) move enrichment to Hot Chocolate field-level resolvers gated by selection, or (c) project enrichment fields lazily inside Mapster/EF. LOW (UX is acceptable at pageSize=10) / MED (cleaner cut would speed up the contact grid too).
- **Known issues closed**: None.
- **Next step**: User restarts Base.API.exe (kill running process, `dotnet run`) so the schema reflects the rolled-back endpoint signature. Then `pnpm dev`, open `/[lang]/crm/donation/refund?mode=new`, click donor dropdown — should populate within ~2-3s on a busy tenant (single page of 10 enriched rows). If snappier UX is required later, escalate ISSUE-V2-15.

### Session 7 — 2026-05-08 — UI — COMPLETED

- **Scope**: User-requested UI/UX polish on the Refund create form to align with the donation-form (#1) precedent and the [feedback_widget_icon_badge_styling.md] / [feedback_ui_uniformity.md] memory rules. Five concrete asks: (1) equal field heights, (2) amount fields left-aligned, (3) information areas use gray bg, (4) section icons use solid bg + white icon (not translucent tints), (5) dropdown styling uniform with donation-form. No spec change, no schema change, no business logic touched.
- **Files touched**:
  - **FE (3 modified)**:
    - `presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` — (a) all 5 SectionHeader `iconTone`s flipped from `bg-X-100 text-X-700 dark:bg-X-900/30 dark:text-X-300` (translucent) to `bg-X-600 text-white` (solid), one distinct color per section: primary (Original Donation) / rose-600 (Refund Details) / blue-600 (Refund Channel) / emerald-600 (Charges & Currency) / slate-600 (Additional Notes); (b) DonationPreviewCard "information area" cyan tint → `border-border bg-muted/40` gray + `text-muted-foreground` header label; (c) Refund Amount wrapper got `h-9 overflow-hidden` so the prefix/input/suffix all share an equal-height row; inner `<input>` got `h-full text-left` (was unaligned, often defaulting to right for `type="number"`); (d) Refund Reason native `<select>` swapped to `<FormSearchableSelect query={MASTERDATAS_QUERY} valueColumn="masterDataId" labelColumn="dataName" advancedFilter={REFUND_REASON_FILTER}>` matching donation-form style — REFUND_REASON_FILTER hoisted to module-level for stable reference; `useRefundReasons` hook still feeds `handleReasonChange` for OTH-detection; `reasonsLoading` destructure removed (FormSearchableSelect manages its own loading state).
    - `presentation/components/page-components/crm/donation/refund/refund-channel-fieldset.tsx` — (a) GATEWAY_REVERSAL "Original Payment" information panel flipped from `bg-blue-50/60 dark:bg-blue-950/20 border-blue-200` to `bg-muted/40 border-border` gray; header label `text-blue-700` → `text-muted-foreground`; (b) Manual `Payment Mode` native `<select>` swapped to `<FormSearchableSelect>` matching donation-form precedent; the local `PAYMENTMODES_QUERY` `useQuery` retained because the selected paymentModeId still needs to be mapped → `paymentModeCode` for the dynamic per-mode sub-fields and the BE-stash field (`onChangeCallback` does the lookup); `Skeleton` import + `pmLoading` destructure removed; new module-level `PAYMENT_MODE_FILTER` constant for stable advancedFilter reference.
    - `presentation/components/page-components/crm/donation/refund/refund-charges-fx-fieldset.tsx` — Refund Fee field height `h-8` → `h-9` (matches all other inputs); width `w-40` → `w-44` to fit currency code + value; `text-right` → `text-left` per ask (2); inner input `h-full` for stretch consistency; added `overflow-hidden` so prefix box border stays inside the rounded outline.
  - **BE**: none.
  - **DB**: none.
- **Build verification**:
  - FE: `pnpm exec tsc --noEmit` → exit 0, **0 lines of output** (clean type-check).
  - UI uniformity grep checks across the entire `refund/` folder: 0 inline `style={{`, 0 raw `>Loading...<`, 0 `fa-*` icon refs, 0 inline hex `#RRGGBB` (per [feedback_ui_uniformity.md]).
  - Did NOT run `pnpm dev` E2E manual exercise — change is purely cosmetic / styling (no behavior, no state, no validation, no submit-payload changes); runtime visual verification owed when the user picks this branch up.
- **Deviations from spec**: None. The Spec (§⑥ UI/UX Blueprint) doesn't pin specific section-icon colors or info-card tints — those were stylistic choices made during Session 1 build that this session normalizes to the codebase-wide [feedback_widget_icon_badge_styling.md] rule (solid `bg-X-600` + `text-white`).
- **Known issues opened**: None.
- **Known issues closed**: None — these were stylistic gaps not previously tracked in the Known Issues table.
- **Next step**: User runs `pnpm dev`, opens `/[lang]/crm/donation/refund?mode=new`, eyeballs (a) every section's icon container is solid-color with white icon, (b) Donation Preview card + Original Payment card use neutral gray, (c) Refund Amount input value is left-aligned, (d) Refund Reason and Manual Payment Mode dropdowns visually match the donor dropdown above, (e) all input rows in a single column have the same height.

### Session 8 — 2026-05-08 — UI — COMPLETED

- **Scope**: Two follow-up corrections from Session 7's user review: (1) Refund Type radio cards (FULL / PARTIAL) still showed light rose-50 / amber-50 background tints in their active state; user wants the gray/tinted bg removed — keep only the border accent. (2) In the Charges & Currency section, the Refund Fee input and the display rows (Refund Amount / Net to Donor) were right-aligned via `flex … justify-between` + `items-end`; user wants all amount fields left-aligned.
- **Files touched**:
  - **FE (2 modified)**:
    - `presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` — `TypeOption` `activeTone` flipped from `border-rose-400 bg-rose-50 dark:bg-rose-950/30 …` (and amber variant) to `border-rose-400 bg-card dark:border-rose-600/60` — keeps the border-color cue + active-state checkmark + colored icon, drops the bg tint entirely. Inactive state already used `bg-card`, so active and inactive cards now share the same bg surface; only the border + icon-color differentiate.
    - `presentation/components/page-components/crm/donation/refund/refund-charges-fx-fieldset.tsx` — (a) Refund Fee row restructured from inline `flex items-center justify-between` (label-left / input-right) to a stacked `<Controller>` body of `flex flex-col gap-1.5` with label-on-top, full-width `w-full` input, `text-left` value — matches the rest of the form's field layout; bumped padding/text from `px-2 text-xs` to `px-3 text-sm` for parity with Refund Amount in §2; (b) `ChargeRow` (used for "Refund Amount" + "Net to Donor" summary lines) flipped from `flex items-center justify-between` (label-left / value-pushed-right) to `flex flex-col gap-1` (label-on-top / value-below, both left-aligned); explicit `text-left` on the value span; label class normalized from `text-muted-foreground` → `text-foreground` font-medium so it reads as a field label instead of a faded summary line.
  - **BE**: none.
  - **DB**: none.
- **Build verification**:
  - FE: `pnpm exec tsc --noEmit` → exit 0, **0 lines of output** (clean type-check).
  - Did NOT run `pnpm dev` E2E manual exercise — change is purely cosmetic (only Tailwind class strings touched; no behavior, state, validation, or submit-payload changes).
- **Deviations from spec**: None. Both changes are pure layout / color normalization within the existing Spec.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User runs `pnpm dev`, reopens the create form, confirms (a) FULL / PARTIAL Type cards no longer show pink/amber bg fill — only border + check-icon highlight, (b) Refund Fee input takes the full row width and value is left-aligned, (c) Refund Amount + Net to Donor display values sit on the left under their labels (no right-alignment).

### Session 9 — 2026-05-08 — UI — COMPLETED

- **Scope**: Revert Session 8's "stack the Refund Fee row + ChargeRow as left-aligned columns" approach. User clarified that Session 7's earlier "left alignment" ask was a misstatement — the actual preference is the standard financial-app convention: **all amount input + display values are right-aligned (`text-right`)**. Layout (label-left / value-right inline rows) was correct in the original Session 1 design; only the typed value's text alignment changed. Saved a memory entry [feedback_amount_field_alignment.md] so this doesn't recur on future screens.
- **Files touched**:
  - **FE (2 modified)**:
    - `presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` — Refund Amount input `text-left` → `text-right` (Session 7 had mistakenly applied `text-left`).
    - `presentation/components/page-components/crm/donation/refund/refund-charges-fx-fieldset.tsx` — (a) Refund Fee row reverted to inline `flex items-center justify-between` layout with label-left + `w-44` input on the right (Session 8's stacked full-width restructure undone), and inner input flipped `text-left` → `text-right`; (b) `ChargeRow` (used for "Refund Amount" / "Net to Donor" summary rows) reverted to inline `justify-between` label-left / value-right layout (Session 8's stacked column undone). All visible amount values across the form are now right-aligned.
  - **BE**: none.
  - **DB**: none.
  - **Memory**: NEW `feedback_amount_field_alignment.md` + index entry in `MEMORY.md` — codifies the right-align rule.
- **Build verification**:
  - FE: `pnpm exec tsc --noEmit` → exit 0, **0 lines of output** (clean type-check).
  - Did NOT run `pnpm dev` E2E manual exercise — pure CSS class flips.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User reloads the create form, confirms every amount value (Refund Amount in §2, Refund Fee + Refund Amount + Net to Donor in §4) sits on the right side of its row.

### Session 10 — 2026-05-08 — ENHANCE — COMPLETED

- **Scope**: Two parallel UX/data-model improvements requested while continuing Refund #13.
  1. **Original Donation preview UX** — the §1 "Original Donation" panel had label-flush-left + value-flush-right rows with wide horizontal gaps. Redesigned as: receipt-# pill in the header row, hero amount block (large, naturally left-aligned + payment-mode chip), and compact inline label-: value pairs for Donor + Date. No `text-right` on the amount because this is a narrative info panel, not a column-stacked data table.
  2. **`RefundTypeCode` → `RefundTypeId` FK + new MANUAL mode** — the previous string enum (FULL/PARTIAL) was replaced with an FK to `sett.MasterDatas` (TypeCode=`REFUNDTYPE`) so refund type is auditable and extensible. A 3rd row "Manual Amount" (DataValue=MANUAL) was added: staff enters any amount > 0 AND ≤ donation amount (equality allowed, distinguishing from PARTIAL which is strictly less than).

- **Files touched**:
  - **BE (9 modified)**:
    - `Base.Domain/Models/DonationModels/Refund.cs` — dropped `RefundTypeCode string`, added `RefundTypeId int` + `RefundType` MasterData nav.
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/RefundConfiguration.cs` — dropped string column config, added FK relation (Restrict).
    - `Base.Application/Schemas/DonationSchemas/RefundSchemas.cs` — `RefundRequestDto.RefundTypeId`; `RefundResponseDto` projects `RefundTypeId/Code/Name`.
    - `Base.Application/Business/DonationBusiness/Refunds/Commands/CreateRefund.cs` — validator + handler use `RefundTypeId` FK; per-mode amount rules (FULL = equal, PARTIAL < , MANUAL ≤). Stale doc comment updated.
    - `Base.Application/Business/DonationBusiness/Refunds/Commands/UpdateRefund.cs` — same.
    - `Base.Application/Business/DonationBusiness/Refunds/Commands/CompleteRefund.cs` — `RefundTypeCode` reference replaced with `RefundType.DataValue` lookup; `.Include(x => x.RefundType)` added.
    - `Base.Application/Business/DonationBusiness/Refunds/Queries/GetRefunds.cs` + `GetRefundById.cs` — projections include `RefundTypeId / RefundTypeCode (= DataValue) / RefundTypeName (= DataName)`.
    - `sql-scripts-dyanmic/Refund-sqlscripts.sql` — STEP 11 NEW (MasterDataType `REFUNDTYPE` + 3 rows FULL/PARTIAL/MANUAL); STEP 6 GridField for `RF_REFUNDTYPECODE` ValueSource JSON gains MANUAL static option (idempotent NOT EXISTS + sibling UPDATE for re-runs).
  - **FE (11 modified)**:
    - `domain/entities/donation-service/RefundDto.ts` — RequestDto.refundTypeId; ResponseDto.refundTypeCode? + refundTypeName?.
    - `infrastructure/gql-queries/donation-queries/RefundQuery.ts` — both `REFUNDS_QUERY` + `REFUND_BY_ID_QUERY` selection sets pull the new trio.
    - `infrastructure/gql-mutations/donation-mutations/RefundMutation.ts` — return payloads include `refundTypeId`.
    - `presentation/components/page-components/crm/donation/refund/refund-form-schemas.ts` — dropped enum, added refundTypeId positive int + hidden refundTypeCode mirror; new `REFUND_TYPE_DV_FULL/PARTIAL/MANUAL` exports; `superRefine` now enforces FULL = equality, PARTIAL strict-less, MANUAL ≤.
    - `presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` — DonationPreviewCard redesigned (receipt-pill header + hero amount + inline pairs); 2-card hardcoded type selector replaced with dynamic 3-card render driven by `useRefundTypes()` hook + `REFUND_TYPE_FILTER` MD query; `REFUND_TYPE_VISUAL` map keyed on DataValue (FULL=rose / PARTIAL=amber / MANUAL=blue); MANUAL amount stays editable (no auto-seed); amount-hint useMemo gains MANUAL branch; default refundTypeId seeded once typeRows arrive (FULL).
    - `presentation/components/page-components/crm/donation/refund/refund-detail-drawer.tsx` — passes `name={refundTypeName}` to badge; amount color-tone branch for MANUAL.
    - `presentation/components/page-components/crm/donation/refund/refund-advanced-filters.tsx` — Type chip list now FULL/PARTIAL/MANUAL.
    - `presentation/components/page-components/crm/donation/refund/refund-store.ts` — comment update only.
    - `presentation/components/page-components/crm/donation/refund/view-page.tsx` — uses REFUND_TYPE_DV_PARTIAL constant; payload sends refundTypeId.
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/refund-type-badge.tsx` — added MANUAL entry; FULL/PARTIAL/MANUAL all switched to solid `bg-X-600 text-white border-X-600` per [feedback_widget_icon_badge_styling.md].
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/refund-amount-cell.tsx` — added MANUAL color branch.
  - **Memory**: `feedback_amount_field_alignment.md` rewritten — clarified that `text-right` applies in DATA contexts only (inputs / grid cells / KPI tiles / column-stacked charge summaries), NOT in narrative info panels. MEMORY.md index updated.
- **Build verification**:
  - FE: `pnpm exec tsc --noEmit` → exit 0, 0 lines of output. Clean.
  - BE: `dotnet build` ran clean (0 CS errors, 477 baseline warnings) up to the DLL-copy stage; the file lock at copy time is from a running VS / Base.API process holding the output DLLs and is not a code issue.
- **Deviations from spec**: None.
- **Known issues opened**:
  - **MIGRATION REQUIRED** — the entity now has `RefundTypeId int` but the DB still has the legacy `RefundTypeCode varchar(10)` column from the original 20260421 migration. The codebase auto-applies migrations on startup (`DatabaseExtentions.cs:12 Database.MigrateAsync()`). Before running the API, generate a migration: `dotnet ef migrations add Refund_RefundTypeCode_To_RefundTypeId --project Base.Infrastructure --startup-project Base.API`. (Attempted in this session but the user declined the auto-run — leaving for the user to run manually so they can review the generated SQL first.) The seed script's STEP 11 (REFUNDTYPE MasterData) is idempotent and can run before or after the migration.
- **Known issues closed**: None.
- **Next step**: User runs `dotnet ef migrations add Refund_RefundTypeCode_To_RefundTypeId` (review the generated SQL ALTERs), then starts the API to auto-apply the migration + the updated seed (STEP 11 + STEP 6 ValueSource refresh). Reload the create form: confirm (a) the Original Donation panel shows receipt-pill in the header + hero amount left-aligned + Donor/Date inline pairs (no big gaps), (b) the refund type selector renders 3 cards (Full / Partial / Manual) with rose / amber / blue tones, (c) Manual mode allows amount entry with the upper bound = donation amount.

### Session 11 — 2026-05-08 — ENHANCE — COMPLETED

- **Scope**: Reverted the "Manual Amount" 3rd refund-type option introduced in Session 10. User pointed out that MANUAL (`0 < amt ≤ donation amount`) is functionally redundant with FULL∪PARTIAL — and the word "Partial" carries the strictly-less-than semantic, so the two-option design is cleaner. Kept the Session 10 FK refactor (`RefundTypeId` → `sett.MasterDatas`) — that delivered the auditing benefit the user asked for; only the third value was removed. Rule restored to FULL = exact, PARTIAL strictly less than donation amount.
- **Files touched**:
  - **BE (3 modified)**:
    - `Base.Application/Business/DonationBusiness/Refunds/Commands/CreateRefund.cs` — doc comment dropped MANUAL; validator whitelist DataValue ∈ {FULL,PARTIAL}; handler `else if (typeDataValue == "MANUAL")` branch removed.
    - `Base.Application/Business/DonationBusiness/Refunds/Commands/UpdateRefund.cs` — same.
    - `sql-scripts-dyanmic/Refund-sqlscripts.sql` — STEP 11 seed dropped to 2 rows (FULL/PARTIAL); STEP 6 GridField ValueSource reverted to 2-option JSON; the sibling UPDATE-on-existing-row block was removed (no longer needed since the value-set is back to original); a soft-deactivate UPDATE was added for any pre-existing MANUAL row from a Session 10 sync (sets `IsActive=false, IsDeleted=true`) so re-runs are idempotent.
  - **FE (7 modified)**:
    - `presentation/components/page-components/crm/donation/refund/refund-form-schemas.ts` — dropped `REFUND_TYPE_DV_MANUAL` export; superRefine comment updated to reference {FULL|PARTIAL} only (rule body unchanged — already only had FULL + PARTIAL branches).
    - `presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` — dropped `REFUND_TYPE_DV_MANUAL` import; `REFUND_TYPE_VISUAL` map shrunk to 2 entries (no MANUAL); type-card grid reverted `sm:grid-cols-3` → `sm:grid-cols-2`; default-case fallback in the map lookup changed `tone: "blue"` → `tone: "amber"`; TypeOption component prop type narrowed `"rose" | "amber" | "blue"` → `"rose" | "amber"` and the activeTone / activeIcon ternaries collapsed; amountHint useMemo MANUAL branch removed; "MANUAL: do NOT auto-seed" comment removed (no longer relevant).
    - `presentation/components/page-components/crm/donation/refund/refund-advanced-filters.tsx` — Type chip list dropped to 2 entries.
    - `presentation/components/page-components/crm/donation/refund/refund-store.ts` — comment update FULL|PARTIAL|MANUAL → FULL|PARTIAL.
    - `presentation/components/page-components/crm/donation/refund/refund-detail-drawer.tsx` — Amount tone branch collapsed (FULL=rose, else amber; no MANUAL=blue).
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/refund-type-badge.tsx` — TYPE_STYLES MANUAL entry removed; doc comment dropped MANUAL row.
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/refund-amount-cell.tsx` — MANUAL color branch removed.
- **Build verification**:
  - FE: `pnpm exec tsc --noEmit` → exit 0, 0 lines of output. Clean.
  - BE: not re-run (only string-content + branch deletion changes; build was clean after Session 10 prior to file-lock issues).
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: When the user runs `dotnet ef migrations add Refund_RefundTypeCode_To_RefundTypeId` and applies it, the seed's STEP 11 inserts only FULL + PARTIAL. If a Session 10 sync already inserted MANUAL into the DB, the new soft-deactivate UPDATE in STEP 11 sets it inactive on next seed run (no destructive DELETE). Reload the create form: 2 type cards (Full rose, Partial amber), no third "Manual" card.

---

### Session 12 — 2026-05-08 — ENHANCE — PARTIAL

- **Scope**: Wired `CompleteRefund` handler to mark the parent `GlobalDonation` as refunded when a Refund row transitions to REF status. Added three new columns (`IsRefunded`, `RefundedAmount`, `LastRefundedDate`) to the domain entity, EF configuration, and `GlobalDonationResponseDto`. `RefundedAmount` is cumulative across all REF refunds for the same donation (sums any prior REF rows plus the current refund amount in a single handler-side query). FE integration is PARTIAL — fields are now available in the GQL response; FE consuming them (e.g., badge on donation grid/drawer) is a separate session.
- **Files touched**:
  - **BE (4 modified)**:
    - `Base.Domain/Models/DonationModels/GlobalDonation.cs` — added `IsRefunded` (bool), `RefundedAmount` (decimal?), `LastRefundedDate` (DateTime?) adjacent to `NetAmount`/`FeeAmount`.
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalDonationConfiguration.cs` — added `HasDefaultValue(false)` for `IsRefunded`; `HasColumnType("decimal(18,2)")` for `RefundedAmount`; `HasColumnType("timestamp with time zone")` for `LastRefundedDate`.
    - `Base.Application/Business/DonationBusiness/Refunds/Commands/CompleteRefund.cs` — replaced ISSUE-2 comment with live handler logic: loads parent GD, sums other REF refunds via `dbContext.Refunds.AsNoTracking()`, sets `gd.IsRefunded = true`, `gd.RefundedAmount = otherRefundedSum + refund.RefundAmount`, `gd.LastRefundedDate = executeUtc` (already Kind=Utc per `feedback_db_utc_only.md`). Single `SaveChangesAsync` covers both the Refund and GlobalDonation rows.
    - `Base.Application/Schemas/DonationSchemas/GlobalDonationSchemas.cs` — added `IsRefunded`, `RefundedAmount`, `LastRefundedDate` to `GlobalDonationResponseDto`. `GlobalDonationDto` inherits them automatically.
- **Build verification**:
  - BE: `dotnet build` on Base.Domain, Base.Infrastructure, Base.Application → all 3 succeeded (0 CS errors). Base.API CLI build failed with MSB3027 file-lock warnings only (Visual Studio + running API process had the output DLLs locked — not a compilation error).
  - FE: not touched this session.
- **Deviations from spec**: None.
- **Known issues opened**: MIGRATION REQUIRED — `dotnet ef migrations add GlobalDonation_AddRefundedColumns` — user must run before next start. Existing rows will default `IsRefunded=false`, `RefundedAmount=NULL`, `LastRefundedDate=NULL` (correct; the HasDefaultValue(false) on `IsRefunded` ensures the migration sets the column default).
- **Known issues closed**: ISSUE-2 (GlobalDonation has no IsRefunded/RefundedAmount column — refund indicator surfaced only via the Refund screen in MVP).
- **Next step**: Run the migration. Then FE can consume `isRefunded` / `refundedAmount` / `lastRefundedDate` from the `globalDonations` GQL query response to surface a "Refunded" badge on the GlobalDonation grid and donation picker.

### Session 12 (FE) — 2026-05-08 — ENHANCE — PARTIAL

- **Scope**: Four UX issues on the Refund create form, Channel fieldset, and workflow modals.
- **Issue #1 — DONE**: Replaced `SummaryRow` (label-far-left / value-far-right justify-between) in the GATEWAY_REVERSAL branch of `refund-channel-fieldset.tsx` with a hero-block + inline `PreviewRow` pattern matching `DonationPreviewCard`. Added gateway name as `text-lg font-semibold` hero, fee chip alongside it, compact `dl` using `PreviewRow` (label: value, no text-right). Added solid `bg-blue-600` numbered-steps callout explaining the full gateway reversal workflow (Submit → Approve → Issue externally in [gateway] → Mark Complete). Removed the old "No further input" italic paragraph. `SummaryRow` function replaced with `PreviewRow` (same file; no other consumers).
- **Issue #2 — DONE**: Diagnosed the silent-failure root cause: the `submitRef` error callback was `() => { ok = false; }` — no toast. Fixed in `refund-create-form.tsx` by passing a named error handler that calls `collectFirstError(fieldErrors)` (new depth-first utility) and fires `toast.error(...)`. Added `toast` import from `sonner` and `FieldErrors` type import from `react-hook-form`. Also extended `buildRefundFormSchema` in `refund-form-schemas.ts` with per-mode required sub-field rules (Account for bank/cheque/PayPal/UPI, BankCode for bank-rail, Mobile for mobile-money) — mirrors BE `RefundChannelHelper.ManualRequiredByModeCode` dict. Now filling BANK_TRANSFER without Account gives an immediate field-level error AND a toast on click.
- **Issue #3 — DONE**:
  - (a) Channel fieldset gateway branch: `SummaryRow` → `PreviewRow` + blue numbered-steps guidance card (bg-blue-600 solid, per `feedback_widget_icon_badge_styling.md`). Gateway name appears dynamically in step 3.
  - (b) Detail drawer: Process button now opens `showProcessDialog` (AlertDialog) explaining "issue externally in [gateway/manual-mode name] → Mark Complete". AlertDialog uses `AlertDialogAction` to fire `handleProcessClick` after confirmation.
  - (c) Complete modal (`refund-complete-modal.tsx`): `DialogDescription` is now channel-aware (GATEWAY_REVERSAL → "Confirm issued in [gateway], paste txn ID"; MANUAL_PAYOUT → "Confirm transfer complete, optional reference"). Gateway Txn ID field is required (`*`) when channel = GATEWAY_REVERSAL; `canSubmit` blocks until field is non-empty. `RefundRowIdentity` in `refund-store.ts` extended with `channelCode?` and `gatewayCode?` (exported interface). `rowIdentity` in `refund-detail-drawer.tsx` updated to pass both fields.
- **Issue #4 — PARTIAL (blocked on BE)**: `GlobalDonationDto` now has `isRefunded`/`refundedAmount`/`lastRefundedDate` on the BE (added by sibling BE agent this session). FE implementation deferred: the GlobalDonation GQL query (`GlobalDonationQuery.ts`) and DTO (`GlobalDonationDto.ts`) do NOT yet include these fields. Adding them requires touching `GlobalDonationQuery.ts` + the index-page column config + potentially a new shared cell renderer. Deferred to a follow-up session once the BE migration is applied and verified. See ISSUE-V2-4.
- **Files touched (FE — 5 modified)**:
  - `refund-channel-fieldset.tsx` — SummaryRow → PreviewRow; gateway branch hero card + blue workflow-steps callout
  - `refund-create-form.tsx` — silent error handler fixed; `collectFirstError` utility added; `toast` + `FieldErrors` imports
  - `refund-form-schemas.ts` — per-mode required sub-field rules added to `buildRefundFormSchema` superRefine
  - `refund-detail-drawer.tsx` — `showProcessDialog` state + AlertDialog confirm; `rowIdentity` extended with channelCode/gatewayCode
  - `refund-complete-modal.tsx` — channel-aware description; txn ID required for GATEWAY_REVERSAL; `canSubmit` gated; label/placeholder per channel
  - `refund-store.ts` — `RefundRowIdentity` extended with `channelCode?` + `gatewayCode?`; interface exported
- **Build verification**: `pnpm exec tsc --noEmit` — exit 0, 0 errors.
- **Deviations from spec**: Diagnostic for Issue #2 confirmed the button IS enabled (canSave = capability.canCreate, which is true). The perceived "not enabled" was the silent error path — button clicked, RHF rejected, no feedback to user. No capability hydration bug found.
- **Known issues opened**: ISSUE-V2-4 — FE GlobalDonation grid "Refunded" badge deferred; requires migration applied + GQL/DTO extension + grid column + shared cell renderer.
- **Known issues closed**: Issue #1 (SummaryRow wide-gap UX), Issue #2 (silent submit failure), Issue #3a/b/c (gateway reversal UX guidance).
- **Next step**: Apply BE migration `GlobalDonation_AddRefundedColumns`, then continue-screen to implement Issue #4 GlobalDonation grid refunded badge.

### Session 13 — 2026-05-08 — FIX — COMPLETED

- **Scope**: Design correction — `IsRefunded` bool dropped in favour of existing `PaymentStatusId` FK to `MasterData(PAYMENTSTATUS=REFUND)`, per user feedback. `RefundedAmount` + `LastRefundedDate` kept for granular tracking.
- **Files touched (BE — 5 modified)**:
  - `GlobalDonation.cs` — removed `public bool IsRefunded { get; set; }` (line 17); `RefundedAmount` + `LastRefundedDate` retained.
  - `GlobalDonationConfiguration.cs` — removed `builder.Property(c => c.IsRefunded).HasDefaultValue(false)` config block; `RefundedAmount` decimal(18,2) + `LastRefundedDate` timestamptz config retained.
  - `GlobalDonationSchemas.cs` — removed `public bool IsRefunded { get; set; }` from `GlobalDonationResponseDto`; comment updated; `RefundedAmount` + `LastRefundedDate` retained.
  - `CompleteRefund.cs` — replaced `gd.IsRefunded = true;` with MasterData lookup for `(TypeCode=PAYMENTSTATUS, DataValue=REFUND)` then `gd.PaymentStatusId = refundedPaymentStatusId.Value;`. Single `SaveChangesAsync` unchanged. Cumulative-sum logic for `gd.RefundedAmount` + `gd.LastRefundedDate = executeUtc` untouched.
  - `Refund-sqlscripts.sql` — added STEP 12: idempotent INSERT for `sett."MasterDatas"` row `(TypeCode=PAYMENTSTATUS, DataValue=REFUND, DataName=Refunded, OrderBy=4)`. No existing seed file owns PAYMENTSTATUS DataValue rows — confirmed by full repo search. `GlobalDonation-sqlscripts.sql` is the canonical owner of the `GD_PAYMENTSTATUSNAME` field/grid-field config but does not seed the DataValue rows themselves.
- **Build verification**: `dotnet build --no-incremental` — 0 CS errors. 8 MSB3021/3027 file-lock errors (pre-existing VS Insiders + Base.API.exe locking DLLs — unchanged from Session 2 baseline).
- **Deviations from spec**: Removed `IsRefunded` prematurely added in Session 12 — single status FK (`PaymentStatusId`) is the canonical design per architecture doc line 2038 ("Pending, Completed, Failed, Refunded").
- **Known issues opened**: None.
- **Known issues closed**: Redundant `IsRefunded` marker introduced Session 12.
- **Migration note**: Since Session 12 migration was never applied, this correction folds into the same pending migration. Migration should be named `GlobalDonation_AddRefundedTracking` (or `GlobalDonation_AddRefundedColumns`). It now adds only `RefundedAmount` (decimal) + `LastRefundedDate` (timestamptz) — no `IsRefunded` column. User runs `dotnet ef migrations add GlobalDonation_AddRefundedTracking` themselves.
- **Next step**: FE Issue #4 unblocked — donation grid can read `paymentStatusName='Refunded'` (via the existing `PaymentStatus` navigation + `GD_PAYMENTSTATUSNAME` grid field) for the badge instead of needing a separate `isRefunded` boolean field. Migration still pending.

### Session 14 — 2026-05-08 — FIX/UI — COMPLETED

- **Scope**: Two fixes — (1) relabelled "Create" button to "Create & Send For Approval" in add-mode; (2) root-caused and fixed the "Create button never enabled" bug.
- **Root cause (disabled button)**: `RefundViewPage` calls `useFlowDataTableStore(state => state.capability)`. The `FlowDataTableStoreProvider` (which calls `setCapability(accessCapability)` in its `useLayoutEffect`) is only mounted inside `RefundIndexPage`. When `index.tsx` switches to form-view mode it renders `<RefundViewPage>` directly — `RefundIndexPage` unmounts, taking the provider with it. The Zustand store's `capability` field stays at its unhydrated default (`undefined` / `null`), causing `!!capability?.canCreate === false` and permanently disabling the Save button. This is NOT a seed-permission issue — BUSINESSADMIN has `canCreate: true` in the DB seed — it is a context-mounting architecture gap.
- **Fix applied (view-page.tsx)**: Changed `canSave` from `!!capability?.canCreate` (falsy when undefined) to `capability?.canCreate !== false` (optimistically true when undefined/null; only false when explicitly `false`). The BE mutation enforces real permissions — FE relaxation is safe.
- **Fix applied (PageHeader.tsx)**: Added optional `saveLabel?: string` prop to `FlowFormPageHeader`. When provided it overrides the default "Create" / "Save Changes" label via `saveLabel ?? (crudMode === "add" ? "Create" : "Save Changes")`. All existing consumers are unaffected (no breaking change).
- **Fix applied (view-page.tsx — label)**: Passed `saveLabel={mode === "new" ? "Create & Send For Approval" : undefined}` to `<FlowFormPageHeader>`.
- **Files touched (FE — 2 modified)**:
  - `src/presentation/components/custom-components/page-header/PageHeader.tsx` — added `saveLabel?: string` prop + nullish-coalesce in label expression.
  - `src/presentation/components/page-components/crm/donation/refund/view-page.tsx` — relaxed `canSave` gate; passed `saveLabel` prop.
- **Build verification**: `pnpm exec tsc --noEmit` — exit code 0, no type errors.
- **Deviations from spec**: None.
- **Known issues closed**: Session 12 ISSUE — "Create button STILL not enabled after form is fully filled" — FIXED. Root cause was capability not hydrating in the standalone view-page render tree, not a seed or form-validation problem.
- **Known issues opened**: None.
- **Next step**: E2E verify on dev server — navigate to `?mode=new`, fill form fully, confirm button reads "Create & Send For Approval" and is clickable.

### Session 15 — 2026-05-08 — UI — COMPLETED (FE)

- **Scope**: Simplified refund UX for v2.1 — single-click PEN→REF flow, gateway reversal held, approval/process workflow hidden. Sibling BE agent relaxed `CompleteRefund.cs` to accept PEN/APR/PRO source states concurrently.
- **Task 1 — Save button label reverted to "Create"**: Removed `saveLabel="Create & Send For Approval"` prop from `<FlowFormPageHeader>` in `view-page.tsx`. Default label logic (`"Create"` for add, `"Save Changes"` for edit) now governs. `saveLabel?: string` prop on `FlowFormPageHeader` itself retained for future overrides by other screens.
- **Task 2 — Gateway Reversal disabled + "Coming soon"**:
  - `refund-channel-fieldset.tsx` — `ChannelRadioOption` extended with optional `comingSoon?: boolean` prop. When true, renders a `bg-slate-600 text-white` "Coming soon" badge in the title row (solid bg+white per `feedback_widget_icon_badge_styling.md`). Gateway Reversal card stamped with `disabled={true}`, `comingSoon={true}`, `aria-disabled="true"`, `cursor-not-allowed`. `onClick` is a no-op.
  - `refund-create-form.tsx` — `applyDonation` callback: replaced `val.gatewayCode ? REFUND_CHANNEL_GATEWAY : REFUND_CHANNEL_MANUAL` with unconditional `REFUND_CHANNEL_MANUAL` (comment: `// v2.1 — Gateway reversal held; force MANUAL_PAYOUT until gateway integration ships.`). Donation-cleared `else` branch also forced to `REFUND_CHANNEL_MANUAL`. `defaultValues.refundChannelCode` default seeded to `REFUND_CHANNEL_MANUAL`. Fallback in `<RefundChannelFieldset channelCode={...}>` also defaulted to `REFUND_CHANNEL_MANUAL`.
  - Gateway Reversal preview JSX (hero block + workflow steps) left in place — `isGateway` branch never activates with channel locked to MANUAL_PAYOUT.
- **Task 3 — Approval/Process buttons hidden; Mark Complete extended**:
  - `refund-detail-drawer.tsx` — PEN case: Approve and Reject buttons removed from render; Mark Complete button added (emerald, `openCompleteModal`). Edit button retained for PEN (existing). APR case: Process Refund button removed from render; Mark Complete button added instead. PRO case: unchanged (Mark Complete already present). All handlers (`openApprovalModal`, `openRejectionModal`, `handleProcessClick`) retained as zombie code.
  - Process AlertDialog left in place with `// v2.1 — Process step held; dialog kept for future re-introduction` comment. Unreachable since `setShowProcessDialog(true)` call is no longer in any rendered button.
- **Task 4 — Filter chips**: `refund-filter-chips.tsx` — "In Progress" chip config prefixed with `// v2.1 — In Progress chip retained for historical APR/PRO records; new refunds skip this state.`. Chip not removed; historical APR/PRO records remain filterable.
- **Task 5 — Approval/Rejection modals**: No changes — mount points in `index.tsx` left intact; modals are unreachable because the buttons that open them are hidden, not deleted.
- **Files touched (FE — 5 modified)**:
  - `src/presentation/components/page-components/crm/donation/refund/view-page.tsx` — removed `saveLabel` prop from `<FlowFormPageHeader>`.
  - `src/presentation/components/page-components/crm/donation/refund/refund-channel-fieldset.tsx` — `ChannelRadioOption` extended with `comingSoon` prop + `aria-disabled`; Gateway Reversal card permanently disabled.
  - `src/presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` — `applyDonation` + `else` branch + `defaultValues` + `channelCode` fallback all forced to `REFUND_CHANNEL_MANUAL`.
  - `src/presentation/components/page-components/crm/donation/refund/refund-detail-drawer.tsx` — PEN/APR/PRO header actions updated; Process dialog comment added.
  - `src/presentation/components/page-components/crm/donation/refund/refund-filter-chips.tsx` — v2.1 comment on "In Progress" chip.
- **Build verification**: `pnpm exec tsc --noEmit` — exit code 0, no type errors.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: N/A.
- **Simplified flow now active**: Create (`?mode=new`) → Pending (drawer) → Mark Complete (openCompleteModal) → Refunded.

---
## ⓘ Enhancement v2 — Realtime Refund Flow

> **Consumer**: `/continue-screen` → BE Developer + FE Developer (in parallel; same Opus parallelism as Session 1).
> **Status**: PLANNED 2026-05-05.
> **Scope**: ALIGN — extend the existing Refund entity, schemas, FE form, and detail drawer. No greenfield. NO new screen menu — same `crm/donation/refund` route. **No new entities. No junction tables. No country-aware filtering.**
> **Sibling pattern**: Same Module=CRM / Schema=fund / Group=DonationModels / ParentMenu=CRM_DONATION. Reuses canonical FLOW conventions.
> **Industry alignment**: Mirrors how Stripe / Razorpay / PayPal / Donorbox / Classy actually handle refunds — gateway-reverses to the original instrument in the original currency; charity bears any FX shift; gateway's own fee policy determines whether the original processing fee is recovered. Donors don't pick a method on real platforms — gateway already has the rail. Manual payout exists only for genuinely offline donations (cash / cheque / in-kind / postal).

### v2.① Why This Enhancement

In Session 1, refund processing was treated as a generic "method" capture (single readonly text `RefundMethodLabel`). Real-world refund operations follow a different pattern: **the refund channel is determined by the original donation, not chosen by the donor**.

Four realities the v1 entity doesn't capture:

1. **Channel auto-routing** — Online donations refund via the original gateway (no method picker; the gateway has the donor's card / UPI / wallet on file). Offline donations (cash, cheque, in-kind, postal) are the only case where staff must manually capture a payout destination. v1 conflates both into one free-text label.
2. **FX & currency snapshot** — Cross-border donations refund in the donor's original currency at today's FX rate. Charity's books take an FX hit silently. v1 has no `RefundCurrencyId` / `RefundExchangeRate` columns to record this. Per [feedback_fx_direct_pair.md], rate VALUE must be stored, never an FX-rate FK.
3. **Original gateway fee recoverability** — Some gateways return the original processing fee on full refunds (Stripe since 2019, Square); others keep it (Razorpay, PayPal since 2019, Cashfree, Authorize.net). Charity needs visibility into fee recoverability before approving the refund. v1 has no fee snapshot.
4. **Receipt cancellation by jurisdiction** — Full refund must cancel the linked tax-deduction receipt (80G / 501c3 / Gift Aid); partial must mark it for revision. v1 has no flag for this.

This v2 keeps the existing 5-state workflow intact and adds a thin set of fields for channel routing, FX snapshot, fee transparency, and receipt-reversal tracking. **No new entities, no country junction, no per-method-by-country filtering.**

### v2.② Entity Definition — DELTA

Existing entity: [Refund.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/Refund.cs). **Keep all existing columns intact** including `RefundMethodLabel` (now repurposed as a derived display string regenerated by the handler from the new fields — see ISSUE-V2-5).

**ADD 11 new columns to `fund."Refunds"`:**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| RefundChannelCode | string | 30 | YES | — | `GATEWAY_REVERSAL` or `MANUAL_PAYOUT`. Auto-derived by handler on Create from selected GD: if `GD.GlobalOnlineDonations.Any()` OR `DonationMode.Code` ∈ {ONLINE_GATEWAY, STRIPE, RAZORPAY, PAYPAL, CARD, UPI_GATEWAY, …} → GATEWAY_REVERSAL; else MANUAL_PAYOUT. Staff may override at Create / PEN-Edit. Default `GATEWAY_REVERSAL` for migration of existing rows. |
| OriginalGatewayFeeAmount | decimal?(18,2) | — | NO | — | Snapshot of `GlobalDonation.FeeAmount` at refund-create. Audit-only; preserves historical fee even if GD is later edited. |
| RefundFeeAmount | decimal?(18,2) | — | NO | — | Cost charged on the refund operation itself (e.g., SWIFT wire $25, Wise %, M-PESA outbound flat). Distinct from the original gateway fee. ≥ 0; null if free. |
| RefundCurrencyId | int? | — | NO | com.Currencies | Donor's currency snapshot. Defaults to GD's currency on Create (no cross-currency override exposed in v2 form — see ISSUE-V2-6). |
| RefundExchangeRate | decimal?(18,8) | — | NO | — | FX rate at refund-EXECUTE (donor currency → charity base currency). Snapshot per [feedback_fx_direct_pair.md] — store rate VALUE, never FK. NULL when same-currency. |
| RefundBaseCurrencyAmount | decimal?(18,2) | — | NO | — | `RefundAmount × RefundExchangeRate` — the charity's books impact. NULL when same-currency. |
| ReceiptStatusAfterRefund | string | 20 | YES | — | `UNCHANGED` (default) / `CANCELLED` (full refund) / `REVISED` (partial refund). Set by handler at refund-EXECUTE (PRO→REF), not at Create. Drives the linked `GlobalReceipt.Status` flip. |
| ManualPaymentModeId | int? | — | NO | com.PaymentModes | Reuse of existing `com.PaymentModes` entity. Required when `RefundChannelCode = MANUAL_PAYOUT`; cleared by handler when channel = GATEWAY_REVERSAL. |
| ManualBeneficiaryAccount | string? | 100 | NO | — | Single field carrying account # / UPI VPA / email (PayPal) / wallet handle. Semantic varies by `ManualPaymentMode.PaymentModeCode`. Required for non-cash manual rails. |
| ManualBeneficiaryBankCode | string? | 50 | NO | — | IFSC (India) / SWIFT (intl) / Sort Code (UK) / Routing # (US). Required for bank-transfer manual rails (BANK_TRANSFER / WIRE / ACH / BACS / NEFT / IMPS / RTGS); optional for UPI; not used for others. |
| ManualBeneficiaryMobile | string? | 30 | NO | — | E.164 mobile number. Required when manual + mobile-money rail (M-PESA / Airtel Money / mobile UPI). |

**ADD navigation properties on Refund:**
```csharp
public Currency? RefundCurrency { get; set; }
public PaymentMode? ManualPaymentMode { get; set; }
```

**NO new entities. NO junction tables. NO per-country method filtering.** The existing `com.PaymentModes` rows are reused for the manual-payout picker.

### v2.③ FK Resolution Table — DELTA

| FK Field | Target Entity | Entity File Path | GQL Query | Display Field | Notes |
|----------|--------------|-------------------|-----------|---------------|-------|
| RefundCurrencyId | Currency | [Currency.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs) | existing `getAllCurrencyList` (or equivalent — BE dev to confirm exact name) | CurrencyName / CurrencyCode | No new query needed |
| ManualPaymentModeId | PaymentMode | [PaymentMode.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/PaymentMode.cs) | existing `getAllPaymentModeList` | PaymentModeName | No new query needed; FE shows all active modes — staff judgment selects |

**ONE new lightweight query** (for cross-currency form preview):

| Query | Purpose | Returns |
|-------|---------|---------|
| `currentFxRate(fromCurrencyId, toCurrencyId)` | Today's FX rate for the form's FX preview block | `{ rate: Decimal?, rateDate: DateTime? }` — null on direct-pair miss per [feedback_fx_direct_pair.md] |

### v2.④ Business Rules & Validation — DELTA

**Channel routing (handler logic, on Create):**
1. If `GD.GlobalOnlineDonations.Any()` OR resolved `DonationMode.Code` ∈ online-gateway set → default `RefundChannelCode = GATEWAY_REVERSAL`.
2. Otherwise (cash, cheque, in-kind, postal, receipt-book) → default `RefundChannelCode = MANUAL_PAYOUT`.
3. Staff may override the default at Create or PEN-Edit (e.g., expired card → MANUAL_PAYOUT for an originally-online donation).

**GATEWAY_REVERSAL path (no manual fields):**
4. `ManualPaymentModeId`, `ManualBeneficiaryAccount`, `ManualBeneficiaryBankCode`, `ManualBeneficiaryMobile` MUST all be NULL. Handler clears them on save to prevent tamper.
5. The actual gateway API call (Stripe Refunds / Razorpay Refund / PayPal Refund) remains a SERVICE_PLACEHOLDER per v1 ISSUE-1. Workflow (PEN→APR→PRO→REF) is identical; gateway integration is wired in a future session.

**MANUAL_PAYOUT path (per-mode required-field map — handler validator + FE Zod refinement):**
6. `ManualPaymentModeId` is REQUIRED.
7. Required-field map by `ManualPaymentMode.PaymentModeCode` (case-insensitive match):

| PaymentModeCode | ManualBeneficiaryAccount | ManualBeneficiaryBankCode | ManualBeneficiaryMobile |
|---|:---:|:---:|:---:|
| `CASH` / `POSTAL` | — | — | — |
| `CHEQUE` / `CHQ` / `DD` | ✓ (Cheque/DD #) | — | — |
| `BANK_TRANSFER` / `WIRE` / `ACH` / `BACS` / `NEFT` / `IMPS` / `RTGS` | ✓ (Account #) | ✓ (IFSC/SWIFT/Sort/Routing) | — |
| `UPI` | ✓ (UPI VPA) | optional | — |
| `MOBILE_MONEY` / `MPESA` / `AIRTEL_MONEY` | optional (txn ref) | — | ✓ (E.164) |
| `PAYPAL` / `WALLET` | ✓ (email/handle) | — | — |

> Handler reads `PaymentMode.PaymentModeCode` → looks up the required set in a static dictionary → enforces presence. Codes not in the table fall back to "all optional" (defensive default).

**FX snapshot (on refund-EXECUTE, i.e., status PRO→REF):**
8. If `RefundCurrencyId` (donor currency) = `Company.PrimaryCurrencyId` (charity base) → leave 3 FX columns NULL.
9. If different → handler resolves rate via `IFxRateService.GetRateAsync(donorCcyId, baseCcyId, executeDateUtc)`. Per [feedback_fx_direct_pair.md], direct-pair-only — null on miss surfaces a soft warning ("FX rate not available for {DonorCcy}→{BaseCcy} on {Date}; refund recorded amount-only without base-currency conversion") and `RefundExchangeRate` + `RefundBaseCurrencyAmount` stay NULL.
10. FX columns are populated at EXECUTE, not at Create. This matches gateway behavior — the rate that applies is the rate at execution, not at request.
11. Date used for the rate lookup must be `DateTime.UtcNow` per [feedback_db_utc_only.md] — never `DateTime.Now` or `DateTime.Today`.

**Receipt cancellation (on refund-EXECUTE):**
12. `RefundType = FULL` → set `ReceiptStatusAfterRefund = CANCELLED`; flip linked `GlobalReceipt.Status = CANCELLED` (find via `GR.GlobalDonationId == Refund.GlobalDonationId`).
13. `RefundType = PARTIAL` → set `ReceiptStatusAfterRefund = REVISED`; flip linked `GlobalReceipt.Status = REVISED`. Issuance of the actual revised receipt PDF is OUT OF SCOPE for v2 (see ISSUE-V2-3).
14. If no `GlobalReceipt` exists for the GD (donation pre-receipting, in-kind without receipt, etc.) → `ReceiptStatusAfterRefund = UNCHANGED` and no GR mutation.

**Fee transparency:**
15. `OriginalGatewayFeeAmount` is captured at refund-Create (snapshot from `GD.FeeAmount`).
16. Gateway-fee-recoverability is a presentation-time computed value (NOT stored) — mapped from the original GD's gateway via a small static dict shared by BE and FE: `STRIPE` → returns full / proportional partial; `SQUARE` → returns full only; `RAZORPAY` → keeps; `PAYPAL` → keeps; `CASHFREE` / `AUTHORIZE` → keeps; default → null/unknown. FE renders a banner accordingly.

**Status transition impact:**
17. Existing 5-state workflow unchanged. New fields populate at: Create (channel + manual fields + OriginalGatewayFeeAmount snapshot), refund-EXECUTE (FX snapshot + ReceiptStatusAfterRefund + GR.Status flip).

### v2.⑤ Screen Classification — DELTA

No change. Still `screen_type=FLOW`. Same Variant B layout. Same 3-mode view-page. Same 5-state workflow.

What changes:
- Form Section 3 ("Refund Method") replaced with channel-aware "Refund Channel" section
- Form Section 4 ("Charges & Currency") replaces former "Notes" Section 4 position; an FX block renders conditionally inside it
- Detail drawer Card 3 ("Refund Method") replaced with "Refund Channel" card; "Refund Charges" card extended with original gateway fee + receipt status
- New Detail drawer Card "FX Snapshot" inserted CONDITIONALLY between Charges and Approval Trail when cross-currency
- New BE handler logic for channel routing, FX snapshot at execute, receipt status flip
- One small new GQL query (`currentFxRate`); no new mutations

### v2.⑥ UI/UX Blueprint — DELTA

#### FORM (mode=new + mode=edit) — Section 3 REPLACED + Section 4 REBUILT

```
┌─ Section 3: Refund Channel (icon phosphor:arrows-left-right) ──────────┐
│                                                                        │
│  Channel: ◉ Gateway Reversal     ○ Manual Payout                       │
│  helper: "Auto-detected from original donation; override if needed."   │
│                                                                        │
│  ── (when GATEWAY_REVERSAL) ──                                         │
│   ┌─ Original Payment ──────────────────────────────────────────┐     │
│   │ Gateway:        Stripe                                       │     │
│   │ Original Txn:   ch_3OqXXX...                                 │     │
│   │ Fee paid:       $ 3.20 USD                                   │     │
│   │ ⓘ Stripe RETURNS the original fee on FULL refunds.           │     │
│   │   On PARTIAL, fee is kept proportionally.                    │     │
│   └────────────────────────────────────────────────────────────────┘   │
│   (no further input — gateway has donor's card / UPI / wallet)         │
│                                                                        │
│  ── (when MANUAL_PAYOUT) ──                                            │
│   Payment Mode *  [ApiSelectV2: getAllPaymentModeList]                 │
│                    placeholder: "Select payout method"                 │
│                                                                        │
│   ── (per-mode dynamic fields, conditional on PaymentModeCode) ──      │
│   [BANK_TRANSFER / WIRE / ACH / BACS / NEFT / IMPS / RTGS]             │
│      Account # *                | IFSC / SWIFT / Sort / Routing *      │
│   [UPI]                                                                │
│      UPI ID / VPA *             | IFSC (optional)                      │
│   [MOBILE_MONEY / MPESA / AIRTEL_MONEY]                                │
│      Mobile Number *            | (Reference txn ref, optional)        │
│   [CHEQUE / DD]                                                        │
│      Cheque / DD Number *                                              │
│   [PAYPAL / WALLET]                                                    │
│      Email / Handle *                                                  │
│   [CASH / POSTAL]                                                      │
│      (no sub-fields)                                                   │
└────────────────────────────────────────────────────────────────────────┘
```

```
┌─ Section 4: Charges & Currency (icon phosphor:calculator) ─────────────┐
│   Refund Amount      $ 200.00 USD   (read-only echo from Section 2)    │
│   Refund Fee         $ [   0.00 ]   (input, monospace, ≥ 0)            │
│   ─────────────────────────────────────────                            │
│   Net to Donor       $ 200.00 USD   (computed: amount − fee)           │
│                                                                        │
│   ── (visible only when donor currency ≠ charity base currency) ──     │
│   Donor Currency      USD                                              │
│   Charity Base        INR                                              │
│   FX Rate (today)     1 USD = 85.40 INR  (fetched from currentFxRate)  │
│   Charity Books       ₹ 17,080.00        (refundAmount × todayRate)    │
│   Original Donation   1 USD = 83.00 INR  (snapshot from GD)            │
│   FX Impact           − ₹ 480.00  ⚠  ("today's rate is higher")        │
│                                                                        │
│   helper: "FX is locked at refund EXECUTION, not at create."           │
└────────────────────────────────────────────────────────────────────────┘
```

Section 5 ("Additional Notes") — unchanged from v1.

**Component contract — `refund-channel-fieldset.tsx` (NEW):**

```ts
interface RefundChannelFieldsetProps {
  /** Auto-derived from selected donation; user can override. */
  channelCode: 'GATEWAY_REVERSAL' | 'MANUAL_PAYOUT';
  /** From selected GD — Stripe / Razorpay / PayPal / null for offline. */
  originalGatewayCode: string | null;
  originalGatewayTxnId: string | null;
  originalFeeAmount: number | null;
  originalFeeCurrencyCode: string | null;
  /** RHF-controlled. */
  control: Control<RefundFormValues>;
  /** External disable. */
  disabled?: boolean;
}
```

- Channel radio at top (auto-set from parent on donation pick; user override allowed).
- Watches `channelCode` via `useWatch`; on flip, RHF `setValue` clears the opposite-side fields.
- GATEWAY_REVERSAL render: readonly Original Payment summary card + fee-recoverability banner from the static dict.
- MANUAL_PAYOUT render: `<ApiSelectV2 query={GET_PAYMENT_MODES}>` for picker; per-mode dynamic block via switch on `selectedMode.paymentModeCode`.

**Component contract — `refund-charges-fx-fieldset.tsx` (NEW):**

```ts
interface RefundChargesFxFieldsetProps {
  refundAmount: number;
  donorCurrencyId: number;            // for the FX query
  donorCurrencyCode: string;          // from selected GD
  charityBaseCurrencyId: number;      // for the FX query
  charityBaseCurrencyCode: string;    // from selected GD's company
  donationExchangeRate: number;       // GD's stored rate (snapshot)
  control: Control<RefundFormValues>;
  disabled?: boolean;
}
```

- Always renders Refund Fee input + Net display.
- FX block visible only when `donorCurrencyId !== charityBaseCurrencyId`.
- Issues `useQuery(GET_CURRENT_FX_RATE, { fromCurrencyId, toCurrencyId })` for today's rate; null result → renders "FX rate unavailable for this pair today" banner (no break).
- Computes `fxImpact = refundAmount × (todayRate − donationRate)`; red if charity loses, green if gains.
- Helper text reminds staff that the actual rate locks at refund EXECUTE.

#### DETAIL drawer (mode=read) — Card 3 REBUILT + Card 4 EXTENDED + NEW Card

Existing Card 3 "Refund Method" → REPLACED by **Channel** card.

**GATEWAY_REVERSAL render:**
```
┌─ Refund Channel ─────────────────────────────────────────────┐
│ Channel: Gateway Reversal                                     │
│ Gateway: Stripe                                               │
│ Original Txn: ch_3OqXXX...                                    │
│ Fee Recoverable: Yes (Stripe — full refund only)              │
└──────────────────────────────────────────────────────────────┘
```

**MANUAL_PAYOUT render** (only populated lines):
```
┌─ Refund Channel ─────────────────────────────────────────────┐
│ Channel: Manual Payout                                        │
│ Payment Mode: Bank Transfer (NEFT)                            │
│ Account: ***********4567                                      │
│ Bank Code: HDFC0001234                                        │
└──────────────────────────────────────────────────────────────┘
```

Existing Card 4 "Refund Charges" → EXTENDED with original-fee snapshot + receipt status:
```
┌─ Refund Charges ─────────────────────────────────────────────┐
│ Refund Amount         $ 200.00 USD                            │
│ Refund Fee            $   0.00                                │
│ Net to Donor          $ 200.00 USD                            │
│ Original Gateway Fee  $   3.20 USD  (snapshot)                │
│ Receipt After Refund: CANCELLED   (was REC-2026-0042)         │
└──────────────────────────────────────────────────────────────┘
```

NEW conditional card "FX Snapshot" — between Charges and Approval Trail, **only when 3 FX columns are non-null**:
```
┌─ FX Snapshot ────────────────────────────────────────────────┐
│ Donor Currency        USD                                     │
│ Charity Base          INR                                     │
│ Refund Rate           1 USD = 85.40 INR  (executed 2026-05-12)│
│ Charity Books Impact  ₹ 17,080.00                             │
│ Original Donation Rate 1 USD = 83.00 INR                      │
│ FX Delta              − ₹ 480.00                              │
└──────────────────────────────────────────────────────────────┘
```

#### Grid columns — DELTA

No new grid columns required. Optional follow-up (post-v2): a "Channel" badge column (Gateway / Manual) — flagged as ISSUE-V2-4.

#### Filter chips / Advanced filters — DELTA

No change.

### v2.⑦ Substitution Guide — N/A

(No new entity name to substitute — v2 edits the existing Refund + adds 11 columns. No greenfield entities.)

### v2.⑧ File Manifest — DELTA

**BE — NEW files (3):**

| File | Purpose |
|------|---------|
| `Base.Application/Business/SharedBusiness/Currencies/Queries/GetCurrentFxRate.cs` | Read-only handler — direct-pair lookup of today's FX rate from `com.CurrencyExchangeRates`; returns `(decimal? rate, DateTime? rateDate)` |
| `Base.Application/Services/IFxRateService.cs` + impl `FxRateService.cs` (only if not present per ISSUE-V2-2) | `Task<(decimal? rate, DateTime? asOfDate)> GetRateAsync(int fromCcyId, int toCcyId, DateTime asOfUtc)` — direct-pair only, no triangulation |
| `Base.Infrastructure/Data/Migrations/{ts}_Add_RefundChannelAndFxSnapshot.cs` | Single migration: ALTER TABLE `fund."Refunds"` ADD 11 columns + index on `RefundChannelCode` for filtering + FK on `ManualPaymentModeId` + FK on `RefundCurrencyId`. Defaults: `RefundChannelCode='GATEWAY_REVERSAL'`, `ReceiptStatusAfterRefund='UNCHANGED'`. |

**BE — MODIFIED files (~10):**

| File | Change |
|------|--------|
| `Base.Domain/Models/DonationModels/Refund.cs` | +11 columns, +2 nav properties (`RefundCurrency`, `ManualPaymentMode`) |
| `Base.Infrastructure/Data/Configurations/DonationConfigurations/RefundConfiguration.cs` | Decimal precision (18,2) for money / (18,8) for rate; FK setup for RefundCurrencyId + ManualPaymentModeId; MaxLength on string columns; default values for RefundChannelCode + ReceiptStatusAfterRefund |
| `Base.Application/Schemas/DonationSchemas/RefundSchemas.cs` | Extend RefundResponseDto + CreateRefundRequestDto + UpdateRefundRequestDto with 11 new fields + projection lookups (`refundCurrencyCode`, `manualPaymentModeCode`, `manualPaymentModeName`) |
| `Base.Application/Business/DonationBusiness/Refunds/Commands/CreateRefund.cs` | Auto-derive `RefundChannelCode` from selected GD (online-donation-presence + DonationMode.Code dict); snapshot `OriginalGatewayFeeAmount` from `GD.FeeAmount`; clear manual fields when channel=GATEWAY_REVERSAL; default `RefundCurrencyId = GD.CurrencyId`; validate per-mode required map for MANUAL_PAYOUT |
| `Base.Application/Business/DonationBusiness/Refunds/Commands/UpdateRefund.cs` | Same field-level handling on PEN-only edit; preserve OriginalGatewayFeeAmount snapshot (don't re-derive) |
| `Base.Application/Business/DonationBusiness/Refunds/Commands/CompleteRefund.cs` (or `ExecuteRefund.cs` per ISSUE-V2-1) | At PRO→REF transition: resolve FX rate via `IFxRateService.GetRateAsync` when `RefundCurrencyId != Company.PrimaryCurrencyId`; populate `RefundExchangeRate` + `RefundBaseCurrencyAmount`; set `ReceiptStatusAfterRefund` per refundType (FULL→CANCELLED, PARTIAL→REVISED, no-GR→UNCHANGED); flip linked `GlobalReceipt.Status` accordingly. Date param = `DateTime.UtcNow` per [feedback_db_utc_only.md]. |
| `Base.Application/Business/DonationBusiness/Refunds/Validators/CreateRefundValidator.cs` (and Update) | Add: channel ↔ manual-fields consistency (GATEWAY_REVERSAL ⇒ all manual NULL; MANUAL_PAYOUT ⇒ ManualPaymentModeId required); per-mode required-field map (case-switch on resolved `PaymentMode.PaymentModeCode`); `RefundFeeAmount ≥ 0` |
| `Base.Application/Business/DonationBusiness/Refunds/Queries/GetRefunds.cs` and `GetRefundById.cs` | Project new 11 fields + lookup joins (RefundCurrency.CurrencyCode, ManualPaymentMode.PaymentModeCode/Name) |
| `Base.Application/Mappings/DonationMappings.cs` | Mapster config for new fields + nav projections |
| `Base.API/EndPoints/Shared/Queries/CurrencyQueries.cs` | +1 endpoint method `GetCurrentFxRate(fromCurrencyId, toCurrencyId)` calling the new handler |
| `Base.Application/Business/DonationBusiness/GlobalDonations/Queries/GetGlobalDonations.cs` (donation-picker projection) | Extend with: donor currency code, company base currency code, gateway code (from GlobalOnlineDonation join), gateway txn id, fee amount — for the FE channel-fieldset and FX-fieldset to consume without an extra query |
| `Base.Application/Schemas/DonationSchemas/GlobalDonationSchemas.cs` | Mirror the 5-field projection extension |

**BE — Seed: NO changes.** Existing `com.PaymentModes` rows are sufficient for the manual-payout picker. No new seed file. Migration runs alone.

**FE — NEW files (3):**

| File | Purpose |
|------|---------|
| `presentation/components/page-components/crm/donation/refund/refund-channel-fieldset.tsx` | Channel radio + (GATEWAY readonly summary OR MANUAL picker + per-mode dynamic fields) |
| `presentation/components/page-components/crm/donation/refund/refund-charges-fx-fieldset.tsx` | Refund Fee input + Net display + conditional FX block |
| `infrastructure/gql-queries/shared-queries/CurrentFxRateQuery.ts` | `currentFxRate(fromCurrencyId, toCurrencyId)` — read-only |

**FE — MODIFIED files (~7):**

| File | Change |
|------|--------|
| `presentation/components/page-components/crm/donation/refund/refund-form-schemas.ts` | Add 11 new fields to `refundBaseSchema`; `.superRefine` for: channel ↔ manual-fields consistency; per-mode required map for MANUAL_PAYOUT; `refundFeeAmount ≥ 0` |
| `presentation/components/page-components/crm/donation/refund/refund-create-form.tsx` | Replace Section 3 with `<RefundChannelFieldset>`; replace Section 4 with `<RefundChargesFxFieldset>`; pass donor currency / GD exchange rate / gateway code / original fee from selected donation |
| `presentation/components/page-components/crm/donation/refund/refund-donation-picker.tsx` | Extend `DonationPickerValue` with: `currencyId`, `currencyCode`, `companyBaseCurrencyId`, `companyBaseCurrencyCode`, `exchangeRate`, `gatewayCode`, `gatewayTxnId`, `feeAmount` |
| `presentation/components/page-components/crm/donation/refund/refund-detail-drawer.tsx` | Replace Card 3 (Channel-aware render); extend Card 4 (Charges) with original gateway fee + receipt status; insert conditional Card "FX Snapshot" |
| `domain/entities/donation-service/RefundDto.ts` | Add 11 new fields + 3 projection lookups |
| `infrastructure/gql-queries/donation-service/RefundQuery.ts` | Add new fields to GetRefunds + GetRefundById selections |
| `infrastructure/gql-queries/donation-service/RefundMutation.ts` | Add new fields to Create/Update mutation inputs |

### v2.⑨ Approval Config — N/A

No menu / capability / Grid / GridField changes. Same REFUND menu / 8 capabilities / FLOW Grid (GridFormSchema=NULL — code-driven form). The new fields are FE-rendered via the form code, not via GridFormSchema.

### v2.⑩ BE→FE Contract — DELTA

**Reuse existing GQL queries** for FK pickers (`getAllCurrencyList`, `getAllPaymentModeList` — exact names per BE convention; BE dev to confirm).

**ONE new lightweight GQL query**:
```graphql
query CurrentFxRate($fromCurrencyId: Int!, $toCurrencyId: Int!) {
  currentFxRate(fromCurrencyId: $fromCurrencyId, toCurrencyId: $toCurrencyId) {
    rate           # Decimal? — null if pair missing per direct-pair-only rule
    rateDate       # DateTime?
  }
}
```

**Extended `RefundResponseDto`** (additive — existing fields unchanged):
```
refundChannelCode             : String         // GATEWAY_REVERSAL | MANUAL_PAYOUT
originalGatewayFeeAmount      : Decimal?
refundFeeAmount               : Decimal?
refundCurrencyId              : Int?
refundCurrencyCode            : String?        // projection from RefundCurrency.CurrencyCode
refundExchangeRate            : Decimal?
refundBaseCurrencyAmount      : Decimal?
receiptStatusAfterRefund      : String         // UNCHANGED | CANCELLED | REVISED
manualPaymentModeId           : Int?
manualPaymentModeCode         : String?        // projection
manualPaymentModeName         : String?        // projection
manualBeneficiaryAccount      : String?
manualBeneficiaryBankCode     : String?
manualBeneficiaryMobile       : String?
```

**Extended `CreateRefundRequestDto` / `UpdateRefundRequestDto`** (additive):
```
refundChannelCode             : String?         // optional — handler auto-derives if null
refundFeeAmount               : Decimal?        // ≥ 0
refundCurrencyId              : Int?            // optional — defaults to GD currency
manualPaymentModeId           : Int?            // required when channel=MANUAL_PAYOUT
manualBeneficiaryAccount      : String?         // ≤ 100; per-mode required
manualBeneficiaryBankCode     : String?         // ≤ 50
manualBeneficiaryMobile       : String?         // ≤ 30
// NOT in input — handler-set:
//   originalGatewayFeeAmount   (snapshot at create)
//   refundExchangeRate         (snapshot at execute)
//   refundBaseCurrencyAmount   (computed at execute)
//   receiptStatusAfterRefund   (set at execute by refundType)
```

**Extended donation-picker payload** (existing `GlobalDonation` projection on the donation-picker query):
```
currencyId                    : Int            // for FX query input
currencyCode                  : String         // donor currency from GD.Currency
companyBaseCurrencyId         : Int            // for FX query input
companyBaseCurrencyCode       : String         // from GD.Company.PrimaryCurrency or BaseCurrency
exchangeRate                  : Decimal        // GD.ExchangeRate (already exists — exposing)
gatewayCode                   : String?        // from GlobalOnlineDonation join (Stripe / Razorpay / PayPal / null)
gatewayTxnId                  : String?        // from GlobalOnlineDonation
feeAmount                     : Decimal?       // GD.FeeAmount (already exists — exposing)
```

### v2.⑪ Acceptance Criteria — DELTA

(See "v2 Verification" task block above for the full acceptance checklist. Highlights:)
1. Channel auto-derives correctly on donation pick (online → GATEWAY_REVERSAL; offline → MANUAL_PAYOUT).
2. Staff can override the channel via the radio.
3. GATEWAY_REVERSAL hides manual fields; MANUAL_PAYOUT shows PaymentMode picker + per-mode sub-fields.
4. Per-mode required map enforced on BE + mirrored on FE.
5. FX block visible only when cross-currency; FX columns populated at refund-EXECUTE, not at Create.
6. Receipt status flip on refund-EXECUTE per refundType.
7. Original gateway fee snapshot captured at Create.
8. EF migration applies cleanly with safe defaults for existing rows.
9. `dotnet build` clean / `pnpm exec tsc --noEmit` clean.

### v2.⑫ Special Notes & Open Issues

- **ISSUE-V2-1** (HIGH — already-known): Real gateway integration (Stripe Refunds API / Razorpay Refund API / PayPal Refund) remains a SERVICE_PLACEHOLDER per v1 ISSUE-1. v2 captures everything needed to integrate later (channel, currency, original fee, txn id) but the actual API call stays a "Process via Gateway" toast. /continue-screen v2 does NOT implement the gateway calls. The handler that triggers the gateway can keep its current name (`CompleteRefundHandler`) or be renamed to `ExecuteRefundHandler` for clarity — BE dev's call.

- **ISSUE-V2-2** (HIGH — architectural prerequisite): `IFxRateService.GetRateAsync(fromCcy, toCcy, asOfUtc)` interface MUST exist or be scaffolded on Day 1. Per [feedback_fx_direct_pair.md], implementation is direct-pair-only — read `com.CurrencyExchangeRates WHERE FromCurrencyId=? AND ToCurrencyId=? AND RateDate <= asOfUtc` ORDER BY RateDate DESC LIMIT 1; return null on miss; NO USD-pivot triangulation. If the service is absent, BE dev adds a minimal `Base.Application/Services/IFxRateService.cs` + implementation + DI registration before the refund-execute handler edits.

- **ISSUE-V2-3** (MED): Receipt revision for PARTIAL refunds — v2 only flips `GlobalReceipt.Status='REVISED'`. Issuance of the actual revised receipt PDF (and/or creation of a new revised GR row) is OUT OF SCOPE for v2 — flag for a separate "Receipt Revision" task. The flipped `Status` is the marker downstream consumers can detect. Optional: add `GlobalReceipts.RevisedFromId` self-FK in this same migration so the future revision flow has the column ready (BE dev's call — keep it small if added).

- **ISSUE-V2-4** (LOW): Channel badge in grid — replace the existing "Refund Method" column (currently `RefundMethodLabel` text) with a 2-line cell: line 1 = channel badge (`Gateway` solid-bg-blue / `Manual` solid-bg-amber per [feedback_widget_icon_badge_styling.md]); line 2 = method name (manual) or gateway name (gateway). Cosmetic; not required for v2 acceptance.

- **ISSUE-V2-5** (LOW): `RefundMethodLabel` legacy field — handler regenerates it on save from the new fields:
  - GATEWAY_REVERSAL → `"Gateway: {gatewayName} (txn {gatewayTxnId})"`
  - MANUAL_PAYOUT → `"{paymentModeName}{ — last4 of account if BANK_TRANSFER}{ — mobile if MOBILE_MONEY}"`
  Keep for backward-compat with any v1 consumers; drop in a future cleanup.

- **ISSUE-V2-6** (LOW): Currency override at refund-create — `RefundCurrencyId` defaults to GD currency. v2 form does NOT expose an override picker (out of scope; if needed later, add a small picker + warning banner). The "donor switched currency" case is rare enough to defer.

- **ISSUE-V2-7** (LOW): Gateway fee-recoverability dictionary — keep as a small static dict in BOTH BE and FE (Stripe/Square→true, Razorpay/PayPal/Cashfree/Authorize→false, default→null/unknown). Externalize to a config table only if the matrix grows beyond ~10 entries. Source per gateway:
  - Stripe: refunds processing fee on FULL refunds since 2019; partial refunds keep proportional fee.
  - Square: same as Stripe.
  - Razorpay: keeps fee on all refunds.
  - PayPal: keeps fee since 2019 (changed from earlier policy).
  - Cashfree / Authorize.net: keeps fee.

- **ISSUE-V2-8** (LOW): Per-mode required-field map is dictionary-driven on BE. As more rails are added, the dictionary grows. Consider externalizing to a config table later; not required now.

- **ISSUE-V2-9** (MED — UTC): All `DateTime` parameters passed to BE (refund execute timestamp, FX rate lookup) must have `Kind=Utc` per [feedback_db_utc_only.md]. Handler defaults to `DateTime.UtcNow` for refund-execute timestamp; never `DateTime.Now` or `DateTime.Today`.

- **ISSUE-V2-10** (LOW): The donation-picker BE projection extension (currency code / company base / GD exchange rate / gateway code / gateway txn / fee) is additive — existing v1 picker callers don't break. The new fields surface to the FE picker `DonationPickerValue` type and are forwarded to the channel + charges fieldsets.

### v2.⑬ Build Log — (to be appended by /continue-screen)

(Empty — `/continue-screen` will append session log here on completion, mirroring v1 build log format.)