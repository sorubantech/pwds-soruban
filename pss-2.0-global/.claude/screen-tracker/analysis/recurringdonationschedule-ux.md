# UX Architecture Blueprint: RecurringDonationSchedule (Screen #8)

> **Date**: 2026-04-21
> **Type**: FLOW with 460px right-side slide-in DETAIL drawer
> **Layout**: Variant B mandatory (`widgets-above-grid+side-panel`)
> **Sibling clone source**: DonationInKind #7 (`donationinkind/`)
> **FE folder**: `recurringdonors` (DO NOT rename)

This blueprint operationalizes the §⑥ UI/UX Blueprint, the §⑩ BE→FE Contract, the BA validation, and the architect's reuse map into a deterministic build plan for the Frontend Developer agent.

---

## A. Component Tree (file-by-file)

The 19 NEW FE files in §⑧ items 8–26 are specified below. Each entry lists Props, Children, State, GQL, and special UX behavior. Paths are abbreviated from the FE root `PSS_2.0_Frontend/src/`.

### A.1 — `presentation/pages/crm/donation/recurringdonationschedule.tsx` (Page Config — item 8)
**Purpose**: Page-config wrapper used by the legacy `pages/` registry. Mostly a re-export of `index.tsx` plus any menu/role guards.
**Props**: none.
**Children**: `<RecurringDonationSchedulePage />` from `page-components/.../recurringdonors/index.tsx`.
**State**: none.
**GQL**: none.
**UX**: page-config glue only — no visual contribution.

---

### A.2 — `page-components/crm/donation/recurringdonors/index.tsx` (URL Dispatcher — item 9)

**Purpose**: Top-level URL switch (clone of DIK `index.tsx`). Reads `?mode=…&id=…` from `useSearchParams` and decides whether to mount the index Variant B page or the FORM view-page. **Unlike DIK**, this screen also accepts `?mode=read&id=X` — but for `read` it still mounts `IndexPage` (the drawer is part of IndexPage).

**Props**: none.

**Component signature**:
```typescript
export default function RecurringDonationSchedulePage(): JSX.Element
```

**Children**:
- `<RecurringDonationScheduleViewPage key={viewKey}/>` when `mode === "new" | "edit"`
- `<RecurringDonationScheduleIndexPage />` otherwise (default + `mode=read`).

**Key state variables**:
- URL params (source of truth): `mode`, `id`, `chip`, `freq`, `gateway`, `amountMin`, `amountMax`, `currency`, `createdFrom`, `createdTo`, `nbFrom`, `nbTo`.
- `useFlowDataTableStore` — `crudMode`, `recordId` (set from URL params for grid-context consumers).
- `useGlobalStore` — `setMenuName("Recurring Donations")`, `setIsMenuRendering`, `setModuleLoading`.
- A `prevRecordIdRef` to detect record-switching while on `?mode=read` (kept open across record switches; only reset on full mode change).

**GQL**: none directly — children own queries.

**Special UX**:
- On `?mode=read&id=X` cold load (deep-link), the dispatcher must NOT defer drawer mount — the IndexPage owns the drawer and reads the URL param itself, so both grid query and drawer query fire in parallel. (Resolves EC-15 / orchestrator ruling on cold-load.)
- `viewKey = ${mode}-${recordId}` ensures `<ViewPage>` remounts on ID change (avoids stale RHF state).

---

### A.3 — `page-components/crm/donation/recurringdonors/index-page.tsx` (Variant B — item 10)

**Purpose**: Variant B composition for the GRID layout — header + KPIs + Failed Alert Banner + filter chips + advanced filter panel + grid + drawer.

**Props**: none.

**Children** (top-to-bottom):
```
<FlowDataTableStoreProvider gridCode="RECURRINGDONOR" tableConfig={…}>
  <ScreenHeader … headerActions={<ExportMenu/> + <Button>+ New Schedule</Button>} />
  <RecurringWidgets summary={summary} loading={summaryLoading}/>          {/* item 14 */}
  <FailedPaymentsAlertBanner data={failedAlert} loading={failedLoading}/> {/* item 15 — conditional */}
  <RecurringFilterChips />                                                  {/* item 16 */}
  <RecurringAdvancedFilters />                                              {/* item 17 */}
  <FlowDataTableContainer showHeader={false}/>                              {/* shared */}
  <RecurringScheduleDetailDrawer />                                         {/* item 13 — always mounted */}
</FlowDataTableStoreProvider>
```

**Key state variables**:
- `useGlobalStore` for breadcrumb context.
- `useFlowDataTableStore` for `gridInfo`, `loading`, `fullScreenMode`, `tableConfig`.
- URL params via `useSearchParams` for chip + advanced filter values (read on render, written via `router.push` in child components).
- React Query / Apollo for two cards-above-grid queries: `recurringDonationScheduleSummary` + `recurringDonationScheduleFailedAlert`.

**GQL**:
- `RECURRING_DONATION_SCHEDULE_SUMMARY_QUERY` (cache-and-network).
- `RECURRING_DONATION_SCHEDULE_FAILED_ALERT_QUERY` (cache-and-network; only render banner when `summary.failedThisMonth > 0`).

**Special UX**:
- `headerActions` = `<ExportMenu>` (dropdown CSV/Excel/PDF — toast placeholder per ISSUE-10) + primary CTA `[+ New Schedule]` (icon `ph:plus-bold`) → `router.push('?mode=new')`.
- Subtitle string in header reflects KPI summary — pattern: `"{activeCount} active · MRR {currency} {monthlyRecurringRevenue}"`.
- Esc key closes fullscreen mode (existing `setFullScreenMode(false)` pattern).
- On URL change to `?mode=read&id=X` from a row click, the drawer self-mounts (via the URL hook in A.6); IndexPage does not need to react.

---

### A.4 — `page-components/crm/donation/recurringdonors/view-page.tsx` (FORM, 2 modes — item 11)

**Purpose**: Full-page FORM for `mode=new` and `mode=edit`. RHF + Zod. 4 sections (Section 4 hidden in `new`).

**Props**: none (reads `mode`/`id` from `useFlowDataTableStore` + `useSearchParams`).

**Children**:
- `<FlowFormPageHeader title=… onBack=… onSave=…/>`
- `<FormSection title="Schedule Info" icon="ph:info-duotone">` — fields: code (RO), startDate, endDate, frequencyId, currencyId, amount, note.
- `<FormSection title="Payment Setup" icon="ph:credit-card-duotone">` — fields: paymentGatewayId, paymentMethodTokenId (cascaded), gatewaySubscriptionId, gatewayCustomerId, gatewayPlanId, donorEmail.
- `<DistributionFieldArray />` (item 18) — wrapped in `<FormSection title="Distribution" icon="ph:users-three-duotone">`.
- `<FormSection title="Status" icon="ph:clock-duotone">` — visible only when `mode === "edit"`; read-only display of scheduleStatus + conditional reasons.
- `<UnsavedChangesDialog open=… onConfirm=…/>` (AlertDialog).

**Key state variables**:
- React Hook Form with Zod resolver — schema in §B.3.
- Local state: `submitLoading`, `nextRoute` (for unsaved-changes interception).
- `useWatch` on `distributions.0.contactId` to drive payment-method cascade.
- `useWatch` on `amount` and `distributions[*].amount` to drive running-sum widget in distribution section.

**GQL**:
- Lazy `RECURRING_DONATION_SCHEDULE_BY_ID_QUERY` for prefill on mount when `mode=edit`.
- `CREATE_RECURRING_DONATION_SCHEDULE_MUTATION` on save in `mode=new`.
- `UPDATE_RECURRING_DONATION_SCHEDULE_MUTATION` on save in `mode=edit`.
- ApiSelectV2-driven queries (rendered inside select fields, not view-page directly): `currencies`, `paymentGateways`, `masterDatas` (for FREQUENCY/PARTICIPANTTYPE), `paymentMethodTokensByContact` (cascade), `contacts`, `donationPurposes`.

**Special UX**:
- After successful Save in `mode=new` → `router.push('?mode=read&id={newId}')` so the drawer auto-opens on the just-created record (sibling pattern).
- After successful Save in `mode=edit` → `router.push('?mode=read&id={id}')` (drawer reopens with fresh data).
- Unsaved-changes dialog blocks Back, header link clicks, and beforeunload.
- Auto-focus first invalid field on submit failure.
- Scroll-into-view on first error.

---

### A.5 — `page-components/crm/donation/recurringdonors/recurringdonationschedule-store.ts` (Zustand — item 12)

**Purpose**: Shared client state. URL is source of truth for `selectedScheduleId` (per ISSUE-13) — store holds only ephemeral UI state (animation, modal open flags, banner expanded toggle, action-context buffer).

**Store shape** (full TypeScript signature in §B.2 below).

**Key behaviors**:
- `openActionModal(kind, scheduleId, payload?)` — sets the right modal-open flag and stores `selectedScheduleIdForAction` so child confirm modals know which record to act on (URL-id alone is unreliable when the action originates from the Failed Alert Banner row, which may differ from the drawer-open row).
- `closeAllActionModals()` — used after successful mutation OR after any escape-route.
- `setFailedAlertExpanded` persists to `localStorage` (key: `pss.recurring.failedAlert.expanded`) so per-user preference survives reloads.
- `resetStore()` called when `index.tsx` detects mode change away from grid.

---

### A.6 — `page-components/crm/donation/recurringdonors/recurring-schedule-detail-drawer.tsx` (460px Drawer — item 13)

**Purpose**: Slide-in DETAIL view at 460px. Mounted once in IndexPage; reads `?mode=read&id=X` from `useSearchParams` to decide open/closed.

**Props**: none (URL-driven).

**Component signature**:
```typescript
export function RecurringScheduleDetailDrawer(): JSX.Element
```

**Children** (within `<Sheet open={isOpen} onOpenChange={…}>`):
- `<SheetContent side="right" className="w-[460px] sm:max-w-[460px] p-0 flex flex-col">`
  - **Header** (`<SheetHeader>`): `ph:repeat-duotone` icon (accent), `REC-XXXX` code (semibold), `<StatusBadge>`, top-right `<SheetClose>` (X icon).
  - **Body** (`<div className="flex-1 overflow-y-auto px-4 py-3 space-y-4">`):
    - Section 1: `<DonorMiniCard contact=… engagementScore=…>` — uses existing `EngagementScoreBadge`.
    - Section 2: `<ScheduleInfoSection record=…/>` — DetailRow grid.
    - Section 3: `<PaymentMethodSection token=…/>` — card icon + `paymentMethodDisplay` + expiry + token status pill.
    - Section 4: `<DistributionTable rows=…/>` — compact 2-col table (Purpose | Amount).
    - Section 5: `<ChargeHistorySection scheduleId=…/>` — last-6 table from `RECURRING_DONOR_TRANSACTIONS_QUERY`.
    - Section 6: `<AuditTrailSection record=… defaultCollapsed/>`.
  - **Footer** (`<div className="border-t px-4 py-3 flex flex-wrap gap-2 sticky bottom-0 bg-background">`): conditional action buttons per matrix in §E.

**Key state variables**:
- URL: `searchParams.get('id')` → `selectedId` → `isOpen = !!selectedId && mode === 'read'`.
- Zustand: `pauseModalOpen`, `cancelModalOpen`, `editAmountModalOpen`, `updatePaymentModalOpen` open flags + `selectedScheduleIdForAction`.
- Lazy GQL: fires when `selectedId` changes and drawer opens.

**GQL**:
- `RECURRING_DONATION_SCHEDULE_BY_ID_QUERY` (`useLazyQuery`, `fetchPolicy: "network-only"`) — fetches drawer record.
- `RECURRING_DONOR_TRANSACTIONS_QUERY` (existing — for Section 5; field-name verification per ISSUE-7).

**Special UX behaviors**:
- **Slide animation**: 220ms ease-out (Sheet default; verify className matches design token).
- **Backdrop**: 40% black overlay (Sheet default). Overlay-click closes (closes via Sheet built-in).
- **Esc closes** (Sheet built-in).
- **Focus trap**: Sheet/Radix built-in.
- **Focus return**: focus returns to triggering grid row (Sheet/Radix built-in via `data-state` source). For deep-link cold load, focus goes to the drawer header.
- **Close handler**: `onOpenChange(false)` → `router.push(pathname)` (clears all params except language slug).
- **Edit button** in header: `router.push('?mode=edit&id={id}')` — closes drawer and opens FORM.
- **Refetch after action**: each action mutation completion triggers (a) `refetch()` of the by-id query, (b) `setRefresh()` on `useFlowDataTableStore` (grid invalidate), (c) `summaryRefetch()`, (d) `failedAlertRefetch()`. EC-16 dual-invalidation honored.
- **Multi-currency MRR caption**: drawer renders no MRR — caption is owned by the KPI card (item 14).

---

### A.7 — `page-components/crm/donation/recurringdonors/recurring-widgets.tsx` (4 KPI cards — item 14)

**Purpose**: 4 KPI cards in a CSS grid (`grid-cols-1 sm:grid-cols-2 lg:grid-cols-4`).

**Props**:
```typescript
interface RecurringWidgetsProps {
  summary: RecurringDonationScheduleSummaryDto | null;
  loading: boolean;
  hasMixedCurrencies?: boolean; // resolved by IndexPage; drives MRR caption
}
```

**Children**: 4× `<WidgetCard>` (internal — token-based, mirrors DIK pattern).

**State**: pure-prop component.

**GQL**: none (fed by parent).

**Special UX**:
- Card 1 — Active Schedules: icon `ph:repeat-duotone` (emerald), value=`activeCount`, delta-pill `+{activeCountDelta} this month` (green when positive, red when negative).
- Card 2 — MRR: icon `ph:currency-dollar-duotone` (teal), value=`{currencyCode} {monthlyRecurringRevenue}`, subtitle `{mrrDeltaPercent}% vs last month` + small caption `(USD only — multi-currency present)` rendered as `text-[10px] text-muted-foreground italic` when `hasMixedCurrencies` is true.
- Card 3 — Failed This Month: icon `ph:warning-duotone` (red/destructive), value=`failedThisMonth`, subtitle `{retriedThisMonth} retried, {recoveredThisMonth} recovered`.
- Card 4 — Avg Duration: icon `ph:calendar-duotone` (blue), value=`{avgDurationMonths} months`, subtitle `Across all active schedules`.
- Skeleton variant when `loading` (Skeleton bars matching primary/secondary heights).

---

### A.8 — `page-components/crm/donation/recurringdonors/failed-payments-alert-banner.tsx` (Failed Alert — item 15)

**Purpose**: Collapsible alert banner showing top 5 failed schedules.

**Props**:
```typescript
interface FailedPaymentsAlertBannerProps {
  data: RecurringDonationScheduleFailedAlertDto[] | null;
  summary: { failedThisMonth: number; retriedThisMonth: number;
             recoveredThisMonth: number; needsAttentionCount: number; } | null;
  loading: boolean;
  onRefetch: () => void;  // bubbled to parent so action handlers can refresh
}
```

**Children**:
- `<div role={firstRender ? "alert" : undefined} aria-live="polite" className="border border-destructive/40 bg-destructive/5 rounded-lg">`
  - **Header line** (always visible): icon `ph:warning-octagon-duotone` (red), summary text, right-side chevron+`Details` toggle.
  - **Body table** (conditional on `failedAlertExpanded` from store): table with 6 columns (Donor, Amount, Last Attempt, Failures, Reason, Actions).
  - Action cell renders 4 small `<Button size="xs" variant="…">`: Contact Donor / Retry / Cancel / Pause (Pause when `consecutiveFailures < 3`; Cancel when `≥ 3`).

**Key state variables**:
- Zustand: `failedAlertExpanded`, `setFailedAlertExpanded`.
- Local: `firstRender` boolean ref so `role="alert"` only fires once for screen-reader announcement.

**GQL**: none directly — uses passed handlers.

**Special UX**:
- Chevron rotates 180° on toggle (Tailwind `transition-transform duration-200` + conditional `rotate-180`).
- Tooltip on truncated reason (full reason in `aria-label` and `title`).
- Action buttons reuse the same modal triggers as drawer footer (DRY) — they call `useStore.openActionModal()`.

---

### A.9 — `page-components/crm/donation/recurringdonors/recurring-filter-chips.tsx` (Chips — item 16)

**Purpose**: 6 filter chips above the grid; URL-synced.

**Props**: none.

**Children**: `<button>` × 6 (Toggle/Pill).

**Key state variables**:
- URL: `chip` param (`all` default).
- Zustand mirror: `activeChip` for cross-component reads (e.g., the failed-banner-row Pause button might pre-set chip context — though not currently used).
- `useFlowDataTableStore.setRefresh()` on chip change to refetch grid with new arg.

**GQL**: none directly — chip value is consumed by the grid query (`useFlowInitializeData`'s arg builder must read `chip` from URL).

**Special UX**:
- Active chip variant: `bg-primary text-primary-foreground` + count badge.
- Inactive: `bg-muted text-muted-foreground hover:bg-muted/80` + count badge.
- Counts beside label: `Active (47)`, `Paused (12)`, `Cancelled (3)`, `Failed (8)`, `Expiring Soon (5)`, `All (75)`. Counts derived from `summary` prop (must be passed in or read from a Zustand-cached summary). The All count is `activeCount + paused + cancelled + failed + expired` if the summary doesn't expose totalCount — fall back to a separate `totalCount` field in SummaryDto if provided; otherwise show no count for All.
- Keyboard: arrow-left/right navigates between chips; Enter activates.

---

### A.10 — `page-components/crm/donation/recurringdonors/recurring-advanced-filters.tsx` (Advanced filter — item 17)

**Purpose**: Collapsible card with 9 filter inputs in 3-column grid.

**Props**: none.

**Children**:
- Header: `[Advanced Filters]` (chevron) + clear/applied count badge.
- Body: `<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">` containing:
  - FrequencyId — `<FormSearchableSelect>` driven by `masterDatas` (typeCode=RECURRINGFREQUENCY).
  - PaymentGatewayId — `<FormSearchableSelect>` driven by `paymentGateways`.
  - AmountMin — `<Input type="number">` (allow decimals).
  - AmountMax — `<Input type="number">`.
  - CurrencyId — `<FormSearchableSelect>` driven by `currencies`.
  - CreatedFrom — `<FormDatePicker>`.
  - CreatedTo — `<FormDatePicker>`.
  - NextBillingFrom — `<FormDatePicker>`.
  - NextBillingTo — `<FormDatePicker>`.
- Footer (right-aligned): `<Button variant="ghost">Clear</Button>` `<Button>Apply</Button>`.

**Key state variables**:
- Local RHF instance for the 9 fields (no Zustand — URL is source of truth on Apply).
- Local `expanded` boolean (defaults to `false` — only opens on click).

**GQL**: none directly — Apply flushes filter values to URL; grid query consumes URL on `setRefresh()`.

**Special UX**:
- "Apply" → write all 9 params to URL via `router.push(?...)` and call `setRefresh()`.
- "Clear" → reset RHF + remove all 9 params from URL + `setRefresh()`.
- Applied count badge in header: count of non-empty filter values.
- Auto-collapse on Apply (UX nicety — keeps grid maximally visible).
- Date-range validators: `createdTo >= createdFrom`, `nbTo >= nbFrom` (inline, RHF refine).
- Amount-range validator: `amountMax >= amountMin` (inline).

---

### A.11 — `page-components/crm/donation/recurringdonors/distribution-field-array.tsx` (Distribution — item 18)

**Purpose**: RHF `useFieldArray` row-renderer for the Distribution section in FORM.

**Props**:
```typescript
interface DistributionFieldArrayProps {
  control: Control<RecurringScheduleFormValues>;
  parentAmount: number; // watched in parent; passed for running-sum compare
}
```

**Children**: row sub-card per distribution + sticky `[+ Add Distribution]` button + running-sum widget pinned bottom-right.

**Row layout** (per row, single line on `lg+`, stacked on `sm`):
```
[Contact ApiSelectV3 — 40% | grow-2]
[Purpose ApiSelectV2 — 25% | grow-1.25]
[ParticipantType ApiSelectV2 — 20% | grow-1]
[Amount Input — 15% | grow-0.75]
[Trash icon button — 32px fixed]
```

**Key state variables**:
- `useFieldArray({ name: "distributions" })` → `fields, append, remove`.
- `useWatch({ name: "distributions" })` → derives `runningSum` for the widget.
- Local `confirmRemoveIdx` (state) → drives an inline `<AlertDialog>` when removing a row that has any non-default values (BR-DIST-2).

**GQL**: none directly — inner Selects own their queries.

**Special UX**:
- "Add Distribution" button: `append({ contactId: 0, donationPurposeId: 0, participantTypeId: 0, amount: 0 })`.
- Trash icon: if row has any non-empty value, open `<AlertDialog>` "Remove this distribution? Entered values will be lost." — Confirm/Cancel.
- Running-sum widget (sticky bottom-right of the section card):
  ```
  Total: $475.00 / $500.00     ← red bg + warning icon when mismatch
  Total: $500.00 / $500.00     ← green tick when match
  ```
  - Background: `bg-destructive/10 border-destructive/40` when mismatched, `bg-emerald-50 dark:bg-emerald-950/30 border-emerald-200` when matched.
  - `aria-live="polite"` so screen readers announce sum changes.
- Empty state (no rows): "Add at least one distribution row" message + `<Button>+ Add Distribution</Button>`.
- Cascade: `firstContactId = useWatch({name: "distributions.0.contactId"})` is exposed via a callback prop or by parent reading control directly — so the parent's PaymentMethodToken select can react.

---

### A.12 — `page-components/crm/donation/recurringdonors/schedule-action-modals.tsx` (3 named exports — item 19)

**Purpose**: Pause / Cancel / EditAmount modals — single file, three named exports.

#### A.12.a — `PauseScheduleModal`

**Props**:
```typescript
interface PauseScheduleModalProps {
  open: boolean;
  onClose: () => void;
  scheduleId: number;
  scheduleCode: string;
  onSuccess: () => void; // bubble for query invalidation
}
```

**Children**: `<Dialog>` containing header ("Pause schedule {scheduleCode}?"), `<Textarea name="pausedReason" placeholder="Reason for pausing (optional but recommended)">`, footer with `[Cancel]` `[Pause schedule]` (warning variant).

**State**: local RHF for `pausedReason` (Zod: maxLength 500).
**GQL**: `PAUSE_RECURRING_DONATION_SCHEDULE_MUTATION`.

#### A.12.b — `CancelScheduleModal`

**Props**: same as Pause + `onSuccess`.
**Children**: Dialog with required `<Textarea name="cancelledReason" required>`, warning copy "Cancellation is permanent — this schedule cannot be resumed.", footer `[Cancel]` `[Cancel schedule]` (destructive variant).
**State**: local RHF; Zod requires non-empty string.
**GQL**: `CANCEL_RECURRING_DONATION_SCHEDULE_MUTATION`.

#### A.12.c — `EditAmountModal`

**Props**: same as Pause + `currentAmount`, `currencyCode`, `distributionsSum`, `distributionCount`.
**Children**: Dialog with `<Input type="number" name="newAmount">`, **running-sum mismatch warning** (per orchestrator ruling): show "Distribution sum: {distributionsSum} {currencyCode} ({distributionCount} rows)" beside the amount input — when `newAmount !== distributionsSum`, render an inline alert "Update distributions via Edit screen" + `[Open Edit]` link button (closes modal + navigates to `?mode=edit&id=X`). The Save button is **disabled** while mismatched.
**State**: local RHF for `newAmount`; Zod `.min(0.01)`.
**GQL**: `EDIT_RECURRING_DONATION_SCHEDULE_AMOUNT_MUTATION`.

#### A.12.d — `UpdatePaymentModal` (also lives in this file for cohesion)

**Props**: same as Pause + `contactId` (drives the cascade).
**Children**: Dialog with `<ApiSelectV2 query={paymentMethodTokensByContact} contactId={contactId}>` + advisory text "Local update only — gateway sync pending."
**State**: local RHF for `newPaymentMethodTokenId`.
**GQL**: `UPDATE_RECURRING_DONATION_SCHEDULE_PAYMENT_MUTATION` (SERVICE_PLACEHOLDER).

---

### A.13 to A.19 — Cell Renderers (items 20–26)

All 7 renderers go to `presentation/components/data-table/shared-cell-renderers/` (per architect §4.6).

| File | Switch key | Props (`ColumnRendererProps`) | Visual |
|------|-----------|-------------------------------|--------|
| `recurring-amount-cell.tsx` | `recurring-amount` | `row.original` → `{amount, currencyCode, frequencySuffix}` | Monospace `{currencyCode} {amount}`, `text-xs text-muted-foreground` suffix `{frequencySuffix}` (e.g., `/mo`) |
| `freq-badge-cell.tsx` | `freq-badge` | `value` (frequencyName: string) | Pill: Monthly→`bg-blue-100 text-blue-800`, Quarterly→`bg-purple-100 text-purple-800`, Annual→`bg-emerald-100 text-emerald-800`, Semi-Annual→`bg-amber-100 text-amber-800` (dark-mode tokens equiv) |
| `gateway-cell.tsx` | `gateway-cell` | `row.original` → `{paymentGatewayName, paymentGatewayCode}` | Letter-circle (S/P/R) in colored bg + name; STRIPE→violet, PAYPAL→navy, RAZORPAY→navy |
| `payment-method-cell.tsx` | `payment-method-cell` | `value` (paymentMethodDisplay: string) | `ph:credit-card-duotone` icon + value text; switch icon based on prefix: "Visa "→`fa-cc-visa`, "Master"→`fa-cc-mastercard`, "Amex"→`fa-cc-amex`, "UPI"→`ph:wallet-duotone`, "PayPal"→`ph:paypal-logo-duotone`, else generic |
| `last-charged-cell.tsx` | `last-charged-cell` | `row.original` → `{lastChargedDate, lastChargeStatusName}` | Date (short) + green-check icon if `Success`, red-X icon if `Failed`; `—` when null |
| `total-charged-cell.tsx` | `total-charged-cell` | `row.original` → `{totalChargedAmount, totalChargedCount, currencyCode}` | Monospace `{currencyCode} {totalChargedAmount}` + small `({totalChargedCount})` muted subtitle |
| `failure-count-cell.tsx` | `failure-count` | `value` (consecutiveFailures: number) | Bold; `text-destructive` when ≥1; `text-muted-foreground` `—` when 0 |

Each renderer is exported from `shared-cell-renderers/index.ts` AND added as a switch case in **all four** `component-column.tsx` files (advanced/basic/flow/report — per NEW-16).

---

## B. State Architecture

### B.1 — URL Params (source of truth)

| Param | Type | Effect | Default |
|-------|------|--------|---------|
| `mode` | `"new" \| "edit" \| "read"` | Controls top-level layout switch | absent → grid |
| `id` | int | Record ID for edit/read | absent |
| `chip` | `"all" \| "active" \| "paused" \| "cancelled" \| "failed" \| "expiringSoon"` | Filter chip | `"all"` (or absent) |
| `freq` | int (FrequencyId) | Advanced filter | absent |
| `gateway` | int (PaymentGatewayId) | Advanced filter | absent |
| `amountMin` | number | Advanced filter | absent |
| `amountMax` | number | Advanced filter | absent |
| `currency` | int (CurrencyId) | Advanced filter | absent |
| `createdFrom` | YYYY-MM-DD | Advanced filter | absent |
| `createdTo` | YYYY-MM-DD | Advanced filter | absent |
| `nbFrom` | YYYY-MM-DD | NextBilling From | absent |
| `nbTo` | YYYY-MM-DD | NextBilling To | absent |

**Cold-load behavior**: `?mode=read&id=X` mounts IndexPage → drawer reads URL → fires by-id query in parallel with grid query. No serialization gating.

### B.2 — Zustand Store Shape

```typescript
// recurringdonationschedule-store.ts
import { create } from "zustand";

export type ChipKey =
  | "all" | "active" | "paused" | "cancelled" | "failed" | "expiringSoon";
export type ActionKind =
  | "pause" | "cancel" | "editAmount" | "updatePayment";

interface ActionContext {
  scheduleId: number;
  scheduleCode: string;
  scheduleStatus: string;
  contactId?: number;
  currentAmount?: number;
  currencyCode?: string;
  distributionsSum?: number;
  distributionCount?: number;
}

export interface RecurringDonationScheduleStore {
  // Drawer animation state (URL is source of truth for selectedId)
  isDrawerAnimatingOpen: boolean;
  setDrawerAnimating: (v: boolean) => void;

  // Filter state mirror (URL is source of truth)
  activeChip: ChipKey;
  setActiveChip: (chip: ChipKey) => void;

  // Advanced filter expanded
  advancedFilterExpanded: boolean;
  setAdvancedFilterExpanded: (v: boolean) => void;

  // Failed alert banner
  failedAlertExpanded: boolean;            // persisted to localStorage
  setFailedAlertExpanded: (v: boolean) => void;

  // Action modal flags + context
  pauseModalOpen: boolean;
  cancelModalOpen: boolean;
  editAmountModalOpen: boolean;
  updatePaymentModalOpen: boolean;
  selectedScheduleIdForAction: number | null;
  actionContext: ActionContext | null;

  openActionModal: (kind: ActionKind, ctx: ActionContext) => void;
  closeAllActionModals: () => void;

  resetStore: () => void;
}
```

### B.3 — RHF + Zod Schemas

**Top-level FORM schema** (in `view-page.tsx`):

```typescript
const distributionRowSchema = z.object({
  recurringDonationScheduleDistributionId: z.number().optional(),  // present in edit
  contactId: z.number().int().min(1, "Donor is required"),
  donationPurposeId: z.number().int().min(1, "Purpose is required"),
  participantTypeId: z.number().int().min(1, "Participant type is required"),
  amount: z.number().min(0.01, "Amount must be > 0"),
});

const recurringScheduleFormSchema = z.object({
  recurringDonationScheduleId: z.number().optional(),
  recurringDonationScheduleCode: z.string().optional(),  // RO; auto-gen
  startDate: z.string().min(1, "Start date is required"),
  endDate: z.string().nullable().optional(),
  frequencyId: z.number().int().min(1, "Frequency is required"),
  currencyId: z.number().int().min(1, "Currency is required"),
  amount: z.number().min(0.01, "Amount must be > 0"),
  note: z.string().max(1000).nullable().optional(),
  paymentGatewayId: z.number().int().min(1, "Gateway is required"),
  paymentMethodTokenId: z.number().int().min(1, "Payment method is required"),
  gatewaySubscriptionId: z.string().min(1, "Gateway subscription ID is required").max(200),
  gatewayCustomerId: z.string().min(1, "Gateway customer ID is required").max(200),
  gatewayPlanId: z.string().max(100).nullable().optional(),
  donorEmail: z.string().email().max(200).nullable().optional().or(z.literal("")),
  distributions: z.array(distributionRowSchema).min(1, "Add at least one distribution row"),
})
.refine(d => !d.endDate || new Date(d.endDate) > new Date(d.startDate),
  { message: "End date must be after start date", path: ["endDate"] })
.refine(
  d => Math.round(d.distributions.reduce((s, r) => s + r.amount, 0) * 100) ===
       Math.round(d.amount * 100),
  { message: "Distribution amounts must sum to the schedule amount", path: ["distributions"] }
);
```

**Action modal Zod schemas**:
- `PauseSchema = z.object({ pausedReason: z.string().max(500).optional() })`
- `CancelSchema = z.object({ cancelledReason: z.string().min(1, "Reason is required").max(500) })`
- `EditAmountSchema = z.object({ newAmount: z.number().min(0.01) })` + cross-field validation in component logic against `distributionsSum`.
- `UpdatePaymentSchema = z.object({ newPaymentMethodTokenId: z.number().int().min(1) })`

### B.4 — React Query / Apollo Keys

(Apollo's automatic cache keys are `(query, variables)` tuples; recommended invalidation pattern via `refetchQueries` and `setRefresh()`.)

| Logical name | Query | Variables |
|--------------|-------|-----------|
| List | `RECURRING_DONATION_SCHEDULES_QUERY` | `{ chip, freq, gateway, amountMin, amountMax, currency, createdFrom, createdTo, nbFrom, nbTo, searchText, pageNo, pageSize, sortField, sortDir, isActive }` |
| ById | `RECURRING_DONATION_SCHEDULE_BY_ID_QUERY` | `{ recurringDonationScheduleId }` |
| Summary | `RECURRING_DONATION_SCHEDULE_SUMMARY_QUERY` | `{}` |
| FailedAlert | `RECURRING_DONATION_SCHEDULE_FAILED_ALERT_QUERY` | `{}` |
| TokensByContact | `PAYMENT_METHOD_TOKENS_BY_CONTACT_QUERY` | `{ contactId }` |
| ChargeHistory | `RECURRING_DONOR_TRANSACTIONS_QUERY` (existing) | `{ recurringScheduleId }` |

### B.5 — Invalidation matrix (after each mutation)

| Mutation | refetch ById? | grid `setRefresh()`? | summary refetch? | failedAlert refetch? | charge-history refetch? |
|----------|---------------|----------------------|------------------|----------------------|-------------------------|
| `createRecurringDonationSchedule` | n/a → drawer reopens via redirect | YES | YES | YES (counts may move) | n/a |
| `updateRecurringDonationSchedule` | YES (after redirect) | YES | YES | YES | YES |
| `deleteRecurringDonationSchedule` | n/a (drawer closes) | YES | YES | YES | n/a |
| `pauseRecurringDonationSchedule` | YES | YES | YES | YES | NO |
| `resumeRecurringDonationSchedule` | YES | YES | YES | YES (status may shift) | NO |
| `cancelRecurringDonationSchedule` | YES | YES | YES | YES | NO |
| `retryRecurringDonationSchedule` | YES | YES | YES | YES | YES (new attempt) |
| `updateRecurringDonationSchedulePayment` | YES | YES | NO | NO | NO |
| `editRecurringDonationScheduleAmount` | YES | YES | YES (MRR shifts) | NO | NO |

A reusable helper `invalidateAfterAction(actionKey)` in the drawer file owns this matrix.

---

## C. Visual Specs

### C.1 — Drawer

| Spec | Value |
|------|-------|
| Width | `460px` (className `w-[460px] sm:max-w-[460px]`) |
| Side | `right` |
| Backdrop | Sheet default (40% black overlay) |
| Slide animation | 220ms ease-out (Sheet/Radix default `data-state` keyframes) |
| Close triggers | X button, Esc key, overlay click — all converge on `onOpenChange(false)` → `router.push(pathname)` |
| Focus trap | Sheet/Radix built-in |
| Focus return | Sheet/Radix built-in (returns to row trigger) |
| Section dividers | `border-b border-border pb-1.5 mb-2` between sections |
| Body padding | `px-4 py-3 space-y-4` |
| Footer | `border-t px-4 py-3 sticky bottom-0 bg-background flex flex-wrap gap-2` |

### C.2 — KPI Cards

| Spec | Value |
|------|-------|
| Container grid | `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-3` |
| Card | `rounded-lg border border-border bg-card p-4 transition-colors hover:bg-accent/40` |
| Icon container | `h-9 w-9 rounded-lg flex items-center justify-center` + accent bg (token classes per accent — no inline hex) |
| Primary value | `text-xl font-bold text-foreground truncate` |
| Subtitle | `text-xs text-muted-foreground truncate` |
| Skeleton heights | icon `h-9 w-9`, label `h-3 w-24`, primary `h-6 w-20`, secondary `h-3 w-40` |

Accent token map (clones DIK convention):
- `emerald` (Card 1 Active), `teal` (Card 2 MRR), `red`/`destructive` (Card 3 Failed), `blue` (Card 4 Avg Duration).

### C.3 — Failed Alert Banner

| Spec | Value |
|------|-------|
| Container | `rounded-lg border border-destructive/40 bg-destructive/5 mb-3` |
| Header | `flex items-center justify-between px-4 py-2` |
| Header text | `text-sm text-foreground` with `font-semibold text-destructive` for the red counts |
| Chevron | `ph:caret-down-bold` rotates 180° via `transition-transform duration-200 rotate-180?` |
| Body table | `w-full text-xs` with `border-t border-destructive/40` separator |
| Action button group | `flex gap-1` of `<Button size="xs" variant="…">` |

### C.4 — Filter Chips

| Spec | Value |
|------|-------|
| Container | `flex flex-wrap gap-2 mb-3` |
| Chip | `inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium transition-colors` |
| Active variant | `bg-primary text-primary-foreground` |
| Inactive variant | `bg-muted text-muted-foreground hover:bg-muted/80` |
| Count badge | `inline-flex items-center justify-center rounded-full bg-background/30 px-1.5 py-0.5 text-[10px] font-semibold` (active variant inherits text color) |

### C.5 — Advanced Filter Panel

| Spec | Value |
|------|-------|
| Container | `rounded-lg border border-border bg-card mb-3` |
| Header | `flex items-center justify-between px-4 py-2 cursor-pointer hover:bg-accent/40` |
| Body | `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 p-4 border-t border-border` |
| Footer | `flex items-center justify-end gap-2 px-4 py-2 border-t border-border` |
| Applied count badge | `inline-flex items-center justify-center h-5 min-w-5 rounded-full bg-primary text-primary-foreground text-[10px] font-semibold px-1.5 ml-2` |

### C.6 — FORM Page Header

`<FlowFormPageHeader>` (shared component) — back arrow + title left-aligned; right-aligned: `[Cancel]` outline + `[Save]` primary.

### C.7 — Distribution Field Array

| Spec | Value |
|------|-------|
| Section card | reuses `<FormSection variant="primary" collapsible defaultExpanded>` |
| Row | `grid grid-cols-12 gap-2 items-start py-2 border-b border-border last:border-0` |
| Contact col | `col-span-12 lg:col-span-5` |
| Purpose col | `col-span-12 lg:col-span-3` |
| ParticipantType col | `col-span-6 lg:col-span-2` |
| Amount col | `col-span-5 lg:col-span-1` |
| Trash btn | `col-span-1 flex items-start justify-center pt-2` |
| Add button | `flex items-center gap-1.5 mt-2 text-primary hover:underline text-sm` |
| Sum widget (matched) | `inline-flex items-center gap-2 rounded-md border border-emerald-200 bg-emerald-50 dark:bg-emerald-950/30 px-3 py-1.5 text-sm font-medium text-emerald-700 dark:text-emerald-200` |
| Sum widget (mismatch) | `inline-flex items-center gap-2 rounded-md border border-destructive/40 bg-destructive/10 px-3 py-1.5 text-sm font-medium text-destructive` |

### C.8 — Iconography (Phosphor via `@iconify/react`)

| Where | Icon |
|-------|------|
| Drawer header | `ph:repeat-duotone` |
| Section: Schedule Info | `ph:info-duotone` |
| Section: Payment Setup | `ph:credit-card-duotone` |
| Section: Distribution | `ph:users-three-duotone` |
| Section: Status | `ph:clock-duotone` |
| Drawer Section 1 Donor | `ph:user-circle-duotone` |
| Drawer Section 5 Charge History | `ph:list-bullets-duotone` |
| Drawer Section 6 Audit | `ph:file-text-duotone` |
| KPI 1 Active | `ph:repeat-duotone` |
| KPI 2 MRR | `ph:currency-dollar-duotone` |
| KPI 3 Failed | `ph:warning-duotone` |
| KPI 4 Avg Duration | `ph:calendar-duotone` |
| Failed Alert Banner | `ph:warning-octagon-duotone` |
| Action: Pause | `ph:pause-duotone` |
| Action: Resume | `ph:play-duotone` |
| Action: Cancel | `ph:x-circle-duotone` |
| Action: Retry | `ph:arrow-clockwise-duotone` |
| Action: Edit Amount | `ph:pencil-simple-duotone` |
| Action: Update Payment | `ph:credit-card-duotone` |
| Action: Contact Donor | `ph:envelope-duotone` |
| Add CTA | `ph:plus-bold` |
| Trash | `ph:trash-duotone` |
| Chevron | `ph:caret-down-bold` |

### C.9 — Responsive Plan

| Breakpoint | Adaptations |
|-----------|-------------|
| `xs` (< 640) | KPI grid → 1 col. Advanced-filter grid → 1 col. Distribution row → fully stacked. Drawer occupies full screen width (`w-screen sm:w-[460px]`) on mobile. Filter chips horizontally scrollable (`overflow-x-auto`). Failed alert table horizontally scrollable. Action toolbar (Export, +New) collapses into overflow `[…]` menu. |
| `sm` (≥ 640) | KPI grid → 2 cols. Advanced filter → 2 cols. Drawer fixed 460px. Distribution row partially stacked (Contact full-width, others in row). |
| `md` (≥ 768) | Distribution row mostly inline. Failed alert table fits. |
| `lg` (≥ 1024) | KPI grid → 4 cols. Advanced filter → 3 cols. Distribution row 100% inline. |
| `xl` (≥ 1280) | Same as `lg` but with extra max-width breathing room (use `max-w-screen-2xl mx-auto` on outermost container if needed). |

This screen is admin-facing. Mobile is supported but not the primary target — drawer-on-mobile fills the screen because 460px would be too cramped on a phone.

---

## D. Interaction Map

The 12 user-flow steps in §⑥ "User Interaction Flow" mapped to state + URL + GQL.

| # | User action | State transition | URL change | GQL fired |
|---|-------------|------------------|-----------|-----------|
| 1 | Lands on `/recurringdonors` | `crudMode=index`; `activeChip=all`; `failedAlertExpanded` from localStorage | `/recurringdonors` (no params) | List + Summary + FailedAlert (parallel) |
| 2 | Row click | `selectedId = clickedId` (URL); drawer mounts | push `?mode=read&id={id}` | ById (drawer fetch) |
| 3 | Closes drawer (X / Esc / overlay) | drawer unmounts | push `pathname` (clears params) | none |
| 4 | Click "+ New Schedule" | `crudMode=add` | push `?mode=new` | none on entry |
| 5 | Fills FORM → Save | RHF submit success | push `?mode=read&id={newId}` | Create mutation → ById (drawer) → invalidations |
| 6a | Click "Edit" in drawer header | drawer closes; `crudMode=edit` | push `?mode=edit&id={id}` | ById (prefill FORM) |
| 6b | Click "Edit Amount" footer | open EditAmountModal | none | none until submit |
| 7 | Drawer footer Pause/Resume/Cancel/Retry | open respective modal OR direct mutation (Resume = direct) | none | mutation → ById refetch + grid refresh + summary refetch + alert refetch |
| 8 | Failed Alert inline action | open same modal as drawer | none | same as #7 |
| 9 | Filter chip click | `activeChip=clicked`; URL sync | push `?chip={key}` | List refetch |
| 10 | Advanced Apply | URL sync 9 params | push `?freq=…&gateway=…&…` | List refetch |
| 11 | Click Back button | URL clears; `crudMode=index` | back → `/recurringdonors` | none |
| 12 | Dirty FORM + navigate away | UnsavedChangesDialog opens | navigation deferred until confirmed | none |

**Special interaction notes**:
- Resume past EndDate: BE auto-flips to Expired. Drawer mutation success handler reads `result.data.scheduleStatusName` from refetched ById; if it equals `"Expired"` AND user attempted Resume, fire `toast.warning("Schedule end date passed — marked Expired")`.
- EditAmount with mismatch: Save button disabled while `newAmount !== distributionsSum`; mismatch caption replaces the helper text. If user clicks `[Open Edit]` link button → close modal → push `?mode=edit&id={id}`.
- Delete from drawer footer or row menu: only rendered when `scheduleStatus ∈ {Cancelled, Expired}` (per orchestrator ruling). Confirm dialog → mutation → drawer closes → grid refresh + summary refetch.

---

## E. Drawer Footer Action Visibility Matrix (5 statuses × 7 buttons + Delete)

| Button | Active | Paused | Failed | Cancelled | Expired |
|--------|--------|--------|--------|-----------|---------|
| Pause Schedule | YES | NO | YES | NO | NO |
| Resume Schedule | NO | YES | NO | NO | NO |
| Cancel Schedule | YES | YES | YES | NO | NO |
| Retry Now | NO | NO | YES (svc) | NO | NO |
| Update Payment | YES | YES | YES (svc) | YES (svc) | NO |
| Edit Amount | YES | YES | YES | NO | NO |
| Contact Donor | NO | NO | YES (svc) | NO | NO |
| **Delete** (orchestrator-added) | NO | NO | NO | YES | YES |

Button variants:
- Pause / Retry → `variant="outline"` with warning text color (amber).
- Resume → `variant="default"` (primary).
- Cancel → `variant="destructive"`.
- Delete → `variant="destructive"`.
- Update Payment → `variant="default"`.
- Edit Amount → `variant="outline"`.
- Contact Donor → `variant="outline"`.

When more than 4 buttons would render, group secondary actions into an overflow `[More…]` menu (only happens for **Failed** which has 6 visible — Pause, Cancel, Retry, Update Payment, Edit Amount, Contact Donor — collapse Update Payment + Edit Amount + Contact Donor into the overflow on `< md` widths).

---

## F. Empty / Loading / Error States

### F.1 — Loading

| Element | Skeleton |
|---------|----------|
| Grid | `<FlowDataTable>` already provides built-in skeleton — no override |
| KPI cards | 4× internal skeleton variant of `<WidgetCard>` (icon `h-9 w-9` + 3 bars) |
| Failed Alert | header line skeleton (single bar) — body collapsed during load |
| Drawer body | per-section skeletons: Donor — avatar circle + 2 bars; ScheduleInfo — 6× DetailRow placeholder bars; PaymentMethod — icon + 2 bars; Distribution — 3× row placeholder; ChargeHistory — 6× row placeholder; Audit — collapsed header only |
| FORM | Section cards render full layout immediately; individual ApiSelect components show their internal "Loading…" placeholder |

### F.2 — Empty

| Context | Display |
|---------|---------|
| Grid (no records) | Centered `<div>` with `ph:repeat-duotone` icon (large, muted), title "No recurring schedules yet", subtitle "Donors who set up recurring donations on the public page appear here." + secondary CTA `[+ Create manually]` |
| Failed Alert | banner not rendered when `failedThisMonth === 0` |
| Distribution field array | helper text "Add at least one distribution row" + visible `[+ Add Distribution]` button |
| Charge History (drawer Section 5) | "No charge attempts yet — schedule starts on {nextBillingDate}." |

### F.3 — Error

| Context | Display |
|---------|---------|
| Any query/mutation error | `toast.error(message)` from sonner |
| Grid load failure | inline destructive banner above grid `<div className="rounded-md border border-destructive/40 bg-destructive/5 p-4 text-sm text-destructive">` with `[Retry]` button (calls `refetch()`) |
| Drawer ById failure | inline destructive banner inside drawer body + `[Retry]` button; do NOT auto-close drawer |
| FORM save failure | inline destructive banner above Save button + scroll-into-view; do NOT clear form data |

---

## G. Accessibility

### G.1 — Drawer

- `<SheetContent role="dialog" aria-modal="true" aria-labelledby="rds-drawer-title">`
- `<SheetTitle id="rds-drawer-title">{scheduleCode} — {scheduleStatusName}</SheetTitle>`
- Focus trap inside drawer (Radix built-in).
- Focus return to triggering grid row on close (Radix built-in).
- Esc key closes (Radix built-in).
- All footer buttons have `aria-label` containing both action and schedule code (e.g., `aria-label="Pause schedule REC-0042"`).

### G.2 — Status badges

`<StatusBadge>` renderer must include `aria-label="Status: Active"` etc. (full status text, not just visual color).

### G.3 — Failed Alert Banner

- Container has `role="alert"` AND `aria-live="polite"` only on **first render** when `failedThisMonth > 0` (track via local ref so subsequent re-renders don't re-announce).
- Each row's action buttons have `aria-label="Pause schedule for {donorContactName}"` etc.

### G.4 — Distribution running-sum

`<div aria-live="polite" aria-atomic="true" role="status">Total: {sum} / {parent}</div>` — screen readers announce changes.

### G.5 — Filter chips

- Each chip is a `<button>` (not `<a>`) with `aria-pressed={activeChip === key}`.
- Chip group has `role="group" aria-label="Filter schedules by status"`.

### G.6 — Forms

- Every input has a visible `<Label htmlFor="...">`.
- Required indicator is both visual (`*`) and `aria-required="true"`.
- Error messages associated via `aria-describedby`.

### G.7 — Keyboard shortcuts

- `Esc` — closes drawer / closes any modal / exits fullscreen.
- `/` (forward slash) — focuses grid search (if grid container provides this).
- Arrow-Left / Arrow-Right within filter chip group — moves focus.

---

## H. Per-File Build Order

The 19 NEW FE files in dependency-respecting order (each step is a discrete commit). FE Developer should build top-to-bottom.

| # | File | Item from §⑧ | Depends on |
|---|------|--------------|------------|
| 1 | `RecurringDonationScheduleDto.ts` (DTO ext) | (existing modify) | none |
| 2 | `RecurringDonationScheduleQuery.ts` (GQL queries) | (existing modify) | DTO |
| 3 | `RecurringDonationScheduleMutation.ts` (GQL mutations) | (existing modify) | DTO |
| 4 | `recurring-amount-cell.tsx` | 20 | DTO |
| 5 | `freq-badge-cell.tsx` | 21 | none |
| 6 | `gateway-cell.tsx` | 22 | none |
| 7 | `payment-method-cell.tsx` | 23 | none |
| 8 | `last-charged-cell.tsx` | 24 | none |
| 9 | `total-charged-cell.tsx` | 25 | DTO |
| 10 | `failure-count-cell.tsx` | 26 | none |
| 11 | `shared-cell-renderers/index.ts` (export 7 renderers) | wiring | items 4–10 |
| 12 | `component-column.tsx` ×4 (advanced/basic/flow/report — switch cases) | wiring | item 11 |
| 13 | `recurringdonationschedule-store.ts` (Zustand) | 12 | none |
| 14 | `recurring-widgets.tsx` | 14 | DTO + store |
| 15 | `failed-payments-alert-banner.tsx` | 15 | DTO + store |
| 16 | `recurring-filter-chips.tsx` | 16 | store |
| 17 | `recurring-advanced-filters.tsx` | 17 | DTO |
| 18 | `distribution-field-array.tsx` | 18 | DTO |
| 19 | `schedule-action-modals.tsx` (Pause / Cancel / EditAmount / UpdatePayment) | 19 | mutations + store |
| 20 | `recurring-schedule-detail-drawer.tsx` (460px) | 13 | store + mutations + queries + action-modals + ChargeHistory query |
| 21 | `view-page.tsx` (FORM 4 sections, 2 modes) | 11 | DTO + mutations + queries + distribution-field-array |
| 22 | `index-page.tsx` (Variant B) | 10 | widgets + alert-banner + chips + advanced-filters + drawer + queries |
| 23 | `index.tsx` (URL dispatcher) | 9 | view-page + index-page |
| 24 | `recurringdonationschedule.tsx` (page-config) | 8 | index.tsx |
| 25 | `app/[lang]/crm/donation/recurringdonors/page.tsx` (route stub OVERWRITE) | (existing modify item 7) | page-config |
| 26 | `donation-service-entity-operations.ts` (mutation wiring per ISSUE-14) | wiring | mutations |

**Cleanup steps** (perform LAST after the new files compile):
- Verify no sibling imports for `RecurringDonorView` (ISSUE-4); if clean, DELETE `view/recurring-donor-view.tsx` + `view/index.ts`.
- DELETE `data-table.tsx` (its only consumer was the deleted view).
- DELETE existing `index.ts` barrel (replaced by new `index.tsx` URL dispatcher).

**Integration smoke test** after step 25:
1. `pnpm dev` → navigate to `/en/crm/donation/recurringdonors` → grid renders with 12 cols + KPIs + chips.
2. Click row → drawer slides in at 460px.
3. Click `[+ New Schedule]` → FORM renders with 3 sections.
4. Cold-load `?mode=read&id=1` → grid + drawer mount in parallel.
