---
document: UX Architect — Final Implementation Spec
screen: Pledge
registry_id: 12
ux_author: UX Architect (claude-opus-4-7)
ux_date: 2026-04-21
source_prompt: pledge.md
ba_source: pledge-ba-notes.md
sr_source: pledge-sr-notes.md
canonical_reference_fe: recurringdonors (index-page.tsx, recurring-widgets.tsx, failed-payments-alert-banner.tsx, recurring-schedule-detail-drawer.tsx)
status: LOCKED — implementation-ready
---

## 0. Layout Variant Stamp (MANDATORY)

- **Variant**: `widgets-above-grid+side-panel` — **Variant B**.
- **Contract**: `<ScreenHeader>` at the top, KPI widgets next, then banner, then chips, then advanced filters, then `<FlowDataTableContainer showHeader={false}>`, then the URL-driven drawer mounted once.
- **Header suppression**: `showHeader={false}` on `FlowDataTableContainer` is non-negotiable — duplicate headers are a UI-uniformity regression.
- **Drawer URL contract**: `?mode=read&id=X` opens; close clears `mode` + `id` only, preserves `chip`/`search`/`filter*` params (ISSUE-13).
- **Three URL modes on the same route** (`/crm/donation/pledge`):
  - no query → grid
  - `?mode=new` → FORM (view-page)
  - `?mode=edit&id=X` → FORM (view-page)
  - `?mode=read&id=X` → grid + drawer overlay

---

## 1. Index-Page Composition (`index-page.tsx`)

### 1.1 Component Tree (byte-for-byte aligned with `recurringdonors/index-page.tsx`)

```tsx
"use client";

// …imports (same shape as recurringdonors/index-page.tsx): stores, Apollo,
// IBreadcrumbItem, ScreenHeader, FlowDataTableContainer, FlowDataTableStoreProvider,
// useFlowInitializeColumns, useFlowInitializeData, Button, Icon, next/navigation

const GRID_CODE = "PLEDGE";

const tablePropertyConfig: TDataTableConfigs = {
  enableAdvanceFilter: true,
  enablePagination: true,
  enableAdd: true,
  enableImport: true,
  enableExport: true,
  enablePrint: true,
  enableFullScreenMode: true,
  enableStickyHeader: true,
  enableActions: {
    enableView: true,
    enableEdit: true,
    enableDelete: true,
    enableToggle: true,
  },
};

export function PledgeIndexPage() {
  return (
    <FlowDataTableStoreProvider
      gridCode={GRID_CODE}
      initialPageSize={10}
      initialPageIndex={0}
      tableConfig={tablePropertyConfig}
    >
      <PledgeIndexContent />
    </FlowDataTableStoreProvider>
  );
}

function PledgeIndexContent() {
  const { error: columnsError } = useFlowInitializeColumns();
  const { error: dataError }    = useFlowInitializeData();

  const gridInfo        = useFlowDataTableStore((s) => s.gridInfo);
  const loading         = useFlowDataTableStore((s) => s.loading);
  const fullScreenMode  = useFlowDataTableStore((s) => s.fullScreenMode);
  const setFullScreen   = useFlowDataTableStore((s) => s.setFullScreenMode);
  const tableConfig     = useFlowDataTableStore((s) => s.tableConfig);

  const moduleName = useGlobalStore((s) => s.moduleName);
  const moduleUrl  = useGlobalStore((s) => s.moduleUrl);
  const menuName   = useGlobalStore((s) => s.menuName);

  const router    = useRouter();
  const pathname  = usePathname();
  const lang      = pathname.split("/")[1] || "en";
  const moduleHref = moduleUrl ? `/${lang}${moduleUrl.startsWith("/") ? moduleUrl : `/${moduleUrl}`}` : undefined;

  // ── Summary KPI query ──
  const {
    data:    summaryData,
    loading: summaryLoading,
    refetch: summaryRefetch,
  } = useQuery<any>(PLEDGE_SUMMARY_QUERY, { fetchPolicy: "cache-and-network" });
  const summary: PledgeSummaryDto | null = summaryData?.result?.data ?? null;

  // ── Overdue alert query ──
  const {
    data:    overdueAlertData,
    loading: overdueAlertLoading,
    refetch: overdueAlertRefetch,
  } = useQuery<any>(PLEDGE_OVERDUE_ALERT_QUERY, { fetchPolicy: "cache-and-network" });
  const overdueAlert: PledgeOverdueAlertDto[] | null = overdueAlertData?.result?.data ?? null;

  // ── Refetch chain (passed to drawer) ──
  const handleAfterMutation = React.useCallback(() => {
    void summaryRefetch();
    void overdueAlertRefetch();
  }, [summaryRefetch, overdueAlertRefetch]);

  // Breadcrumbs: Home → CRM → Pledges (identical shape to recurringdonors)
  const breadcrumbs: IBreadcrumbItem[] = [ /* same as sibling */ ];

  // ESC to exit full-screen (same effect as sibling)
  React.useEffect(() => { /* … */ }, [fullScreenMode, setFullScreen]);

  const handleCreate = React.useCallback(() => {
    router.push(`/${lang}/crm/donation/pledge?mode=new`);
  }, [router, lang]);

  const error = dataError || columnsError;
  if (error) {
    return <div className="rounded-md border border-destructive/40 bg-destructive/5 p-4 text-sm text-destructive">Error: {error.toString()}</div>;
  }

  const headerActions = (
    <div className="flex items-center gap-2">
      <Button size="sm" onClick={handleCreate} className="h-8 gap-1.5">
        <Icon icon="ph:plus-bold" className="h-4 w-4" />
        <span>New Pledge</span>
      </Button>
      {/* Export dropdown — Excel / CSV / PDF → SERVICE_PLACEHOLDER toast */}
      <PledgeExportMenu />
    </div>
  );

  // Subtitle: "{activeCount} active · {currency} {totalPledged} pledged"
  const subtitleText = summary
    ? `${summary.activePledgesCount.toLocaleString()} active · ${summary.currencyCode || ""} ${summary.totalActivePledgedAmount.toLocaleString(undefined, { maximumFractionDigits: 0 })} pledged`
    : gridInfo?.description ||
      "Track donor commitments, payment schedules, and fulfillment progress";

  return (
    <div
      className={cn(
        "flex w-full max-w-full flex-col gap-0 overflow-x-hidden transition-all duration-300 ease-in-out",
        fullScreenMode && "fixed inset-0 z-[100] bg-background overflow-auto p-2 sm:p-4"
      )}
    >
      {/* ═══ ScreenHeader — Variant B ═══ */}
      <ScreenHeader
        title={gridInfo?.gridName || "Pledge Management"}
        description={subtitleText}
        breadcrumbs={breadcrumbs}
        loading={loading}
        enableFullScreenMode={tableConfig?.enableFullScreenMode}
        fullScreenMode={fullScreenMode}
        onFullScreenToggle={() => setFullScreen(!fullScreenMode)}
        icon="ph:handshake-duotone"
        headerActions={headerActions}
      />

      {/* ═══ KPI widgets (4 cards) ═══ */}
      <PledgeWidgets summary={summary} loading={summaryLoading} />

      {/* ═══ Overdue alert banner (conditional) ═══ */}
      <PledgeOverdueAlertBanner
        data={overdueAlert}
        summary={summary}
        loading={overdueAlertLoading}
      />

      {/* ═══ Filter chips ═══ */}
      <PledgeFilterChips summary={summary} />

      {/* ═══ Advanced filters (collapsible) ═══ */}
      <PledgeAdvancedFilters />

      {/* ═══ Grid (Variant B — internal header suppressed) ═══ */}
      <div className="min-h-0 flex-1">
        <FlowDataTableContainer showHeader={false} />
      </div>

      {/* ═══ Side drawer (URL-driven, mounted once) ═══ */}
      <PledgeDetailDrawer onAfterMutation={handleAfterMutation} />
    </div>
  );
}
```

### 1.2 Wiring rules (locked-down)

- **Two queries fire in parallel** on page mount: `PLEDGE_SUMMARY_QUERY` + `PLEDGE_OVERDUE_ALERT_QUERY`. Both `cache-and-network`.
- `handleAfterMutation` re-invokes both. Drawer invokes it after any mutation (cancel, edit redirect, delete, link-donation).
- **Grid and drawer mount in parallel** (no sequencing) — drawer lazy-queries `pledgeById` via `useLazyQuery` when `isOpen` becomes `true`.
- **`selectedPledgeId` is NOT stored in Zustand** — derive from `useSearchParams('id')` (SR deviation 2).
- **Sticky element order**: ScreenHeader is NOT sticky by default; the grid toolbar inherits stickiness via `enableStickyHeader: true`.

---

## 2. View-Page (FORM) Spec — `view-page.tsx` + `pledge-create-form.tsx`

> Used for `?mode=new` and `?mode=edit&id=X`. `view-page.tsx` is the page shell + URL mode dispatcher + RHF form setup; `pledge-create-form.tsx` is the body (4 cards).

### 2.1 Page Shell (view-page.tsx)

```tsx
export function PledgeViewPage() {
  const searchParams = useSearchParams();
  const mode = searchParams.get("mode");                // 'new' | 'edit' | 'read'
  const id   = searchParams.get("id");

  // If mode=read → render index-page + drawer; this component is only invoked for new/edit.
  // In practice, the dispatcher (index.tsx) routes:
  //   mode === 'new' || mode === 'edit'  → <PledgeViewPage />
  //   otherwise                          → <PledgeIndexPage />

  const isEdit = mode === "edit" && !!id;

  // RHF setup with zod resolver — see 2.4
  const form = useForm<PledgeFormInput>({ resolver: zodResolver(pledgeFormSchema), defaultValues });

  // On edit: fetch by id, hydrate form once.
  const [fetchById, { data: existing, loading: fetching }] = useLazyQuery(PLEDGE_BY_ID_QUERY, { fetchPolicy: "network-only" });
  useEffect(() => { if (isEdit && id) fetchById({ variables: { pledgeId: Number(id) } }); }, [isEdit, id]);
  useEffect(() => { if (existing?.result?.data) form.reset(mapDtoToForm(existing.result.data)); }, [existing]);

  // Unsaved-changes guard: reuse shared hook useUnsavedChangesGuard(form.formState.isDirty)

  return (
    <div className="flex w-full flex-col gap-3">
      <FlowFormPageHeader
        title={isEdit ? `Edit Pledge — ${existing?.result?.data?.pledgeCode ?? ""}` : "New Pledge"}
        icon="ph:handshake-duotone"
        onBack={() => router.push(`/${lang}/crm/donation/pledge`)}
        onSave={form.handleSubmit(onSubmit)}
        saving={saving}
        saveDisabled={!form.formState.isDirty || !form.formState.isValid}
      />
      {/* Validation error summary (top-of-form) — grouped by section */}
      {Object.keys(form.formState.errors).length > 0 && <FormErrorSummary errors={form.formState.errors} />}

      <PledgeCreateForm form={form} mode={isEdit ? "edit" : "new"} existing={existing?.result?.data} />
    </div>
  );
}
```

### 2.2 Section Layout (`pledge-create-form.tsx`) — 4 Cards, exact mockup order

Each section is a card: `rounded-lg border border-border bg-card p-4 sm:p-5` with a header row `flex items-center gap-2 border-b border-border pb-2 mb-3` containing an Iconify Phosphor icon + section title (`text-sm font-semibold`) + optional collapse chevron. All sections default **expanded**.

#### CARD 1 — Donor & Purpose (icon `ph:user-circle-duotone`)

| Row | Col span (md ≥ 768) | Field | Widget | Placeholder |
|-----|---------------------|-------|--------|-------------|
| 1 | 6 / 12 | ContactId | ApiSelectV3 (`contacts`, filterColumns `displayName`, `contactCode`) | "Search donor…" |
| 1 | 6 / 12 | CampaignId | ApiSelectV2 (`campaigns`) | "Select campaign (optional)" |
| 2 | 12 / 12 | DonationPurposeId | ApiSelectV2 (`donationPurposes`) | "Select purpose…" |

Grid shell: `grid grid-cols-1 md:grid-cols-12 gap-3`. Field wrappers use `md:col-span-6` / `md:col-span-12`.

#### CARD 2 — Pledge Details (icon `ph:currency-dollar-duotone`)

Mockup row (`col-md-4 + col-md-8`) preserved verbatim per ISSUE-4.

| Row | md col span | Field | Widget | Notes |
|-----|-------------|-------|--------|-------|
| 1 | 4 / 12 | CurrencyId | ApiSelectV2 (`currencies`, default = `company.defaultCurrencyId`) | shows `currencyCode` + `currencyName` subtitle |
| 1 | 8 / 12 | TotalPledgedAmount | `<Input type="number" step="0.01">` with currency-symbol prefix | right-aligned, monospace |
| 2 | 6 / 12 | StartDate | Date picker (`DatePickerField`) | default today |
| 2 | 6 / 12 | EndDate | Date picker | read-only visually until user types; placeholder "Auto-calculated" |

Grid: `grid grid-cols-1 md:grid-cols-12 gap-3`.

#### CARD 3 — Payment Schedule (icon `ph:calendar-check-duotone`)

| Row | md col span | Field | Widget |
|-----|-------------|-------|--------|
| 1 | 4 / 12 | FrequencyId | ApiSelectV2 (`masterDatas`, staticFilter `typeCode=PLEDGEFREQUENCY`) |
| 1 | 4 / 12 | InstallmentAmount | `<Input type="number" step="0.01">` |
| 1 | 4 / 12 | NumberOfInstallments | `<Input type="number" step="1">` |
| 2 | 6 / 12 | PaymentModeId | ApiSelectV2 (`paymentModes`) |
| 2 | 6 / 12 | — | (empty; reserved for frequency-hint helper text) |

Helper-text row below the grid (full-width, `text-xs text-muted-foreground italic`): `"End Date: {computedEndDate} · Schedule: {installmentAmount} × {n} installments ({frequencyName})"` — live-updates via `useWatch`.

**Schedule Preview Panel** — rendered **inside CARD 3** (below the helper text, above the card's bottom padding). A horizontal compact preview using `<PledgePaymentTimeline mode="preview" schedule={computedPreviewRows} maxInlineDots={6} />`. If `computedRows > 6`, show "+ N more" pill at end. Renders `null` when form fields are insufficient (e.g., no TotalPledgedAmount yet) — empty-state: `<div className="text-xs text-muted-foreground">Fill in amount, frequency, and start date to preview the schedule.</div>`.

#### CARD 4 — Additional (icon `ph:note-pencil-duotone`)

| Row | md col span | Field | Widget |
|-----|-------------|-------|--------|
| 1 | 12 / 12 | Notes | `<Textarea rows={3}>` placeholder "Any additional notes about this pledge…", maxLength 1000 with live counter |

### 2.3 Auto-Calc Logic (pseudocode)

Runs client-side via `useWatch` on fields `[TotalPledgedAmount, StartDate, EndDate, FrequencyId, InstallmentAmount, NumberOfInstallments]`. Tracks `touchedFields` via RHF. `frequencyDays` resolution uses the MasterData `dataValue` converted to integer (30 / 90 / 180 / 365 / 0).

```ts
function recompute(watched, touched) {
  const total = Number(watched.TotalPledgedAmount) || 0;
  const freqDays = parseInt(watched.FrequencyId?.dataValue ?? "0", 10);
  const frequencyCode = watched.FrequencyId?.dataValue; // "30" | "90" | … | "0"
  const isCustom = freqDays === 0;

  // CUSTOM branch — no auto-calc for amount/N; both are user-required
  if (isCustom) {
    // Only compute EndDate if both N and startDate known and user hasn't touched EndDate
    if (watched.NumberOfInstallments && watched.StartDate && !touched.EndDate) {
      // For Custom with uniform spacing from StartDate..EndDate, the end is user-driven;
      // leave EndDate blank until user types.
    }
    return;
  }

  // Case A: EndDate set by user → derive N + InstallmentAmount
  if (watched.EndDate && touched.EndDate && watched.StartDate) {
    const daysSpan = diffInDays(watched.EndDate, watched.StartDate);
    const n = Math.floor(daysSpan / freqDays) + 1;
    if (!touched.NumberOfInstallments) form.setValue("NumberOfInstallments", n);
    if (!touched.InstallmentAmount && total > 0)
      form.setValue("InstallmentAmount", roundCurrency(total / n));
    return;
  }

  // Case B: User typed InstallmentAmount → derive N + EndDate
  if (watched.InstallmentAmount && touched.InstallmentAmount && total > 0) {
    const n = Math.ceil(total / Number(watched.InstallmentAmount));
    if (!touched.NumberOfInstallments) form.setValue("NumberOfInstallments", n);
    if (!touched.EndDate && watched.StartDate) {
      form.setValue("EndDate", addDays(watched.StartDate, freqDays * (n - 1)));
    }
    return;
  }

  // Case C: User typed NumberOfInstallments → derive InstallmentAmount + EndDate
  if (watched.NumberOfInstallments && touched.NumberOfInstallments && total > 0) {
    const n = Number(watched.NumberOfInstallments);
    if (!touched.InstallmentAmount) form.setValue("InstallmentAmount", roundCurrency(total / n));
    if (!touched.EndDate && watched.StartDate) {
      form.setValue("EndDate", addDays(watched.StartDate, freqDays * (n - 1)));
    }
    return;
  }

  // Case D: Only total + freq set → suggest (default N=12)
  if (total > 0 && freqDays > 0 && !touched.NumberOfInstallments && !touched.InstallmentAmount) {
    const n = 12;
    form.setValue("NumberOfInstallments", n, { shouldDirty: false });
    form.setValue("InstallmentAmount",   roundCurrency(total / n), { shouldDirty: false });
    if (!touched.EndDate && watched.StartDate) {
      form.setValue("EndDate", addDays(watched.StartDate, freqDays * (n - 1)), { shouldDirty: false });
    }
  }
}
```

> Touched-state semantics match EC-10: EndDate is an anchor only when **touched**; otherwise it recomputes.

### 2.4 Validation (Zod)

```ts
const pledgeFormSchema = z.object({
  ContactId:            z.number().min(1, "Donor is required"),
  CampaignId:           z.number().optional().nullable(),
  DonationPurposeId:    z.number().min(1, "Purpose is required"),
  CurrencyId:           z.number().min(1, "Currency is required"),
  TotalPledgedAmount:   z.number().min(0.01, "Total must be > 0"),
  StartDate:            z.string().min(1, "Start date is required"),
  EndDate:              z.string().optional().nullable(),
  FrequencyId:          z.number().min(1, "Frequency is required"),
  InstallmentAmount:    z.number().min(0.01, "Installment must be > 0"),
  NumberOfInstallments: z.number().int().min(1, "At least 1 installment"),
  PaymentModeId:        z.number().optional().nullable(),
  Notes:                z.string().max(1000).optional().nullable(),
}).refine(
  (v) => !v.EndDate || new Date(v.EndDate) > new Date(v.StartDate),
  { path: ["EndDate"], message: "End date must be after start date" }
).refine(
  (v) => Math.abs(v.TotalPledgedAmount - v.InstallmentAmount * v.NumberOfInstallments) <= 1.00,
  { path: ["InstallmentAmount"], message: "Installment × N must equal total pledged (±$1.00)" }
);
```

### 2.5 Validation error aggregation

On submit attempt, if any errors exist, render a top-of-form `FormErrorSummary`:

```
[!] Please fix 3 errors to continue
    • Donor & Purpose: Donor is required · Purpose is required
    • Payment Schedule: Installment × N must equal total pledged (±$1.00)
```

Errors are grouped by section using a map of `fieldKey → sectionLabel`. Clicking an error scrolls the card into view and focuses the first invalid field. Same UX as `donationinkind` FORM.

### 2.6 Save Flow

- **Create**: `createPledge` mutation → returns new `pledgeId` → `router.replace(?mode=read&id={newId})` → drawer opens on top of grid. Toast "Pledge {PLG-NNNN} created".
- **Update**: `updatePledge` → returns `pledgeId` → `router.replace(?mode=read&id={id})` → drawer re-opens refreshed. Toast "Pledge updated".
- **Dirty navigation**: `useUnsavedChangesGuard` intercepts `router.push/back` when `formState.isDirty` is true → AlertDialog "Discard unsaved changes?" with Keep Editing / Discard buttons.

---

## 3. Detail Drawer Spec — `pledge-detail-drawer.tsx` (720px)

### 3.1 Container

```tsx
<Sheet open={isOpen} onOpenChange={(o) => !o && handleClose()}>
  <SheetContent
    side="right"
    className="w-full sm:max-w-[720px] max-w-[720px] p-0 flex flex-col"
    aria-labelledby="pledge-drawer-title"
  >
    <SheetHeader />   {/* section 3.2 */}
    <div className="flex-1 overflow-y-auto px-5 py-4">
      {loading ? <DrawerSkeleton /> : <DrawerBody /> }
    </div>
    <DrawerFooter />  {/* sticky bottom */}
  </SheetContent>
</Sheet>
```

- `w-full` on mobile (< 640 `sm` breakpoint) → full-viewport drawer.
- `sm:max-w-[720px]` at ≥ 640px.
- **Keyboard**: ESC closes (Shadcn `Sheet` default). **Focus trap**: active (Radix primitive). **Focus restore**: to the row that opened the drawer (Radix auto-manages via `onOpenChange`).

### 3.2 Header (sticky top)

```tsx
<SheetHeader className="border-b border-border px-5 py-3 shrink-0">
  <div className="flex items-start gap-3">
    <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10">
      <Icon icon="ph:handshake-duotone" className="h-5 w-5 text-primary" />
    </div>
    <div className="flex-1 min-w-0">
      <SheetTitle id="pledge-drawer-title" className="text-sm font-semibold">Pledge Detail</SheetTitle>
      <div className="flex items-center gap-2 mt-1 min-w-0">
        <span className="text-xs font-mono text-muted-foreground truncate">{record.pledgeCode}</span>
        <StatusBadge code={record.computedStatusCode} />
      </div>
    </div>
    {/* Action cluster */}
    <div className="flex items-center gap-1 shrink-0">
      {record.nextDuePledgePaymentId && !isCancelled && (
        <Button size="sm" variant="default" onClick={handleRecordPayment} className="h-8 gap-1.5">
          <Icon icon="ph:receipt-duotone" className="h-4 w-4" />Record Payment
        </Button>
      )}
      {isOverdue && (
        <Button size="sm" variant="outline" onClick={handleSendReminder} className="h-8 gap-1.5">
          <Icon icon="ph:bell-ringing-duotone" className="h-4 w-4" />Remind
        </Button>
      )}
      {!isCancelled && (
        <Button size="sm" variant="ghost" onClick={handleEdit} className="h-8 px-2 gap-1">
          <Icon icon="ph:pencil-simple-duotone" className="h-4 w-4" />
          <span className="text-xs">Edit</span>
        </Button>
      )}
    </div>
  </div>
</SheetHeader>
```

### 3.3 Cancelled Banner (top of body, conditional)

When `record.computedStatusCode === "CANCELLED"`, a prominent info bar at the top of the body (inside the scrollable area):

```tsx
<div className="mb-4 rounded-md border border-muted-foreground/30 bg-muted/40 px-3 py-2">
  <div className="flex items-start gap-2">
    <Icon icon="ph:x-circle-duotone" className="h-4 w-4 mt-0.5 text-muted-foreground shrink-0" />
    <div className="text-xs">
      <p className="font-semibold text-foreground">Cancelled on {formatDate(record.cancelledAt)}</p>
      <p className="mt-0.5 text-muted-foreground">Reason: {record.cancelledReason || "—"}</p>
    </div>
  </div>
</div>
```

In Cancelled state: all action buttons in header hidden EXCEPT Close. Section 4 (Cancel inline form) hidden. Timeline + history still render (read-only).

### 3.4 Body — 4 Vertical Sections

#### SECTION 1 — Pledge Summary (2-col grid, 10 info rows)

```tsx
<section>
  <SectionTitle icon="ph:info-duotone" title="Pledge Summary" />
  <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-2">
    <DetailRow label="Donor"              value={<DonorLink contactId={r.contactId} name={r.donorName} code={r.donorCode} avatarColor={r.donorAvatarColor}/>} />
    <DetailRow label="Status"             value={<StatusBadge code={r.computedStatusCode} />} />
    <DetailRow label="Campaign / Purpose" value={r.campaignOrPurposeName} />
    <DetailRow label="Payment Method"     value={r.paymentModeName || "—"} />
    <DetailRow label="Total Pledged"      value={<CurrencyAmount amount={r.totalPledgedAmount} code={r.currencyCode} size="lg" weight="bold" />} />
    <DetailRow label="Total Fulfilled"    value={<CurrencyAmount amount={r.fulfilledAmount} code={r.currencyCode} size="lg" weight="bold" tone="success" />} />
    <DetailRow label="Outstanding Balance" value={<CurrencyAmount amount={r.outstandingBalance} code={r.currencyCode} size="lg" weight="bold" tone={r.overdueCount > 0 ? "danger" : "warning"} />} />
    <DetailRow label="Fulfillment"        value={<FulfillmentProgress percent={r.fulfillmentPercent} statusCode={r.computedStatusCode} inline />} />
    <DetailRow label="Schedule"           value={`${formatMoney(r.installmentAmount, r.currencyCode)} ${frequencySuffixFrom(r.frequencyName)} · ${r.numberOfInstallments} installments`} />
    <DetailRow label="Period"             value={`${formatDate(r.startDate)} — ${r.endDate ? formatDate(r.endDate) : "—"}`} />
  </div>
</section>
```

#### SECTION 2 — Payment Schedule Timeline

```tsx
<section>
  <SectionTitle icon="ph:timer-duotone" title="Payment Schedule Timeline" />
  <PledgePaymentTimeline
    mode="actual"
    schedule={r.paymentSchedule}
    currencyCode={r.currencyCode}
    onNodeClick={(pp) => scrollToHistoryRow(pp.pledgePaymentId)}
  />
</section>
```

#### SECTION 3 — Payment History Table

```tsx
<section>
  <SectionTitle icon="ph:clock-counter-clockwise-duotone" title="Payment History" />
  <PledgePaymentHistoryTable rows={r.paymentSchedule} currencyCode={r.currencyCode} lang={lang} />
</section>
```

Columns: `#`, `Due Date`, `Due Amount`, `Paid Date`, `Paid Amount`, `Donation Ref`, `Status`. Donation Ref cell uses a mini-`DonorLink`-style pattern but for GlobalDonation: clickable `receiptCode` → `/[lang]/crm/donation/globaldonation?mode=read&id={globalDonationId}`; em-dash when null. Status cell uses `<PaymentStatusChip code={row.paymentStatusCode} />`.

#### SECTION 4 — Cancel Pledge (conditional — only when NOT Cancelled AND NOT Fulfilled)

```tsx
{!isCancelled && !isFulfilled && (
  <section className="pt-3 border-t border-border">
    {!cancelFormOpen ? (
      <Button
        type="button"
        size="sm"
        variant="outline"
        className="border-destructive/50 text-destructive hover:bg-destructive/10 gap-1.5"
        onClick={() => setCancelFormOpen(true)}
      >
        <Icon icon="ph:x-circle-duotone" className="h-4 w-4" />
        Cancel Pledge
      </Button>
    ) : (
      <PledgeCancelForm
        onConfirm={handleCancel}                 // fires cancelPledge mutation
        onDismiss={() => setCancelFormOpen(false)}
        submitting={cancelling}
      />
    )}
  </section>
)}
```

`PledgeCancelForm`: textarea `Cancellation Reason *` (rows=2, maxLen=500, live counter) + two buttons (`Confirm Cancel` danger primary, `Nevermind` ghost). Submit disabled when textarea empty.

### 3.5 Footer (sticky bottom)

Minimal — only a Close button aligned right, since primary actions live in the header:

```tsx
<div className="border-t border-border px-5 py-2.5 sticky bottom-0 bg-background shrink-0">
  <div className="flex items-center justify-between gap-2">
    <span className="text-[11px] text-muted-foreground">
      Created {formatDate(r.createdDate)} by {r.createdBy}
    </span>
    <Button size="sm" variant="ghost" onClick={handleClose}>Close</Button>
  </div>
</div>
```

### 3.6 Shared `PledgePaymentTimeline` contract

**Two modes. Same component. Used both in FORM preview and DETAIL drawer.**

```ts
type PledgePaymentTimelineMode = "preview" | "actual";

interface PledgePaymentTimelineProps {
  mode: PledgePaymentTimelineMode;

  // "preview" mode — computed client-side from FORM fields
  //   schedule: Array<{ installmentNumber, dueDate, dueAmount, paymentStatusCode: 'SCHEDULED' }>
  //   no onNodeClick

  // "actual" mode — actual PledgePaymentResponseDto[] from pledgeById
  //   schedule: PledgePaymentResponseDto[]
  //   onNodeClick?: (pp) => void (to sync scroll to history table row)
  schedule: PledgePaymentTimelineNode[];

  currencyCode?: string;
  maxInlineDots?: number;      // preview mode cap (default 6)
  onNodeClick?: (node: PledgePaymentTimelineNode) => void;
}

interface PledgePaymentTimelineNode {
  installmentNumber: number;
  dueDate: string;             // ISO
  dueAmount: number;
  paymentStatusCode: "PAID" | "UPCOMING" | "SCHEDULED" | "OVERDUE";
  pledgePaymentId?: number;    // actual mode only
}
```

Rendering:
- Horizontal flex row (`flex items-start gap-0 overflow-x-auto` with custom thin scrollbar), 1 node per installment.
- Each node: 20px circle dot + tiny icon + amount label + date label beneath.
- Connector bar between nodes: `h-[3px] w-10` colored by the upstream node's status code.
- **Color mapping** (design tokens only — no raw hex):
  - PAID → `bg-emerald-500` + `ph:check-bold`
  - UPCOMING → `bg-amber-500` + `ph:clock-duotone`
  - OVERDUE → `bg-destructive` + `ph:warning-duotone`
  - SCHEDULED → `bg-muted-foreground/60` (no icon)
- **Responsive**: on `<md` (< 768px), switch to vertical stack (`md:flex-row flex-col`), connector becomes `w-[3px] h-6`.
- **Accessibility**: each node is a `<button type="button">` in actual mode (keyboard-focusable) with `aria-label="Installment {n}: {status} — {amount} due {date}"`. In preview mode, nodes are `<div>` (non-interactive).
- **Overflow indicator** (preview mode only): when `schedule.length > maxInlineDots`, render first N dots + a `+ (length - N) more` pill.

---

## 4. KPI Widget Specs — `pledge-widgets.tsx`

### 4.1 Grid container

```tsx
<div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-2 lg:grid-cols-4">
  {/* 4 WidgetCard instances */}
</div>
```

- Mobile (< 640): `grid-cols-2` → **2×2** (per directive). This is a deviation from the recurring screen's `grid-cols-1 sm:grid-cols-2`; Pledge uses `grid-cols-2` on the smallest breakpoint per the 2×2 requirement.
- `sm` (640–1023): `grid-cols-2` (same).
- `lg` (≥ 1024): `grid-cols-4` (1 row).

### 4.2 The 4 cards

Reuse a `WidgetCard` sub-component identical in shape to `recurring-widgets.tsx`'s internal `WidgetCard` (token-only styling, loading skeleton preserves shape: icon square + 3 text lines).

| # | Label | Primary (value) | Secondary (subtitle) | Caption (optional) | Accent | Icon |
|---|-------|-----------------|----------------------|-------------------|--------|------|
| 1 | `ACTIVE PLEDGES` | `summary.activePledgesCount.toLocaleString()` | `${currency} ${formatCompact(summary.totalActivePledgedAmount)} total pledged` | `{currency} only — multi-currency present` when `hasMixedCurrencies === true` | `teal` | `ph:handshake-duotone` |
| 2 | `FULFILLED THIS YEAR` | `${currency} ${summary.fulfilledAmountYtd.toLocaleString(…, maxFractionDigits: 0)}` | `${summary.fulfilledPledgeCountYtd} pledges completed` | — | `emerald` | `ph:check-circle-duotone` |
| 3 | `OUTSTANDING BALANCE` | `${currency} ${summary.outstandingBalanceTotal.toLocaleString(…, maxFractionDigits: 0)}` | `across ${summary.activePledgesCount} pledges` | — | `amber` | `ph:hourglass-medium-duotone` |
| 4 | `OVERDUE PAYMENTS` | `summary.overdueCount.toLocaleString()` | `${currency} ${summary.overdueAmountTotal.toLocaleString(…, maxFractionDigits: 0)} overdue` | — | `destructive` | `ph:warning-circle-duotone` |

**Formatting helper** (shared):
```ts
// Compact $ format for "total pledged" subtitle: 1.2M / 850K / 450
function formatCompact(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1).replace(/\.0$/, "") + "M";
  if (n >= 1_000)     return (n / 1_000).toFixed(1).replace(/\.0$/, "") + "K";
  return n.toLocaleString();
}
```

### 4.3 Accent → Tailwind token map (extend `recurring-widgets` palette)

```ts
const ACCENT_CLASSES = {
  teal:        { iconBg: "bg-teal-100 dark:bg-teal-900/30",       icon: "text-teal-700 dark:text-teal-300" },
  emerald:     { iconBg: "bg-emerald-100 dark:bg-emerald-900/30", icon: "text-emerald-700 dark:text-emerald-300" },
  amber:       { iconBg: "bg-amber-100 dark:bg-amber-900/30",     icon: "text-amber-700 dark:text-amber-300" },
  destructive: { iconBg: "bg-destructive/10",                     icon: "text-destructive" },
};
```

No raw hex anywhere. All colours via Tailwind palette classes or semantic tokens (`destructive`, `primary`, `muted-foreground`, `border`, `card`).

### 4.4 Skeleton shape

When `loading`, each card renders the exact same box size (`rounded-lg border border-border bg-card p-4`) but inside:
- `Skeleton h-9 w-9 rounded-lg` (icon slot)
- `Skeleton h-3 w-24` (label)
- `Skeleton h-6 w-20` (primary value)
- `Skeleton h-3 w-40` (secondary)

No layout shift — skeleton → content is a token/class swap only.

---

## 5. Overdue Alert Banner Spec — `pledge-overdue-alert-banner.tsx`

### 5.1 Visibility rule

```ts
if (loading) return <BannerSkeleton />;
if (!summary || summary.overdueCount === 0) return null;
```

### 5.2 Collapse state persistence

Zustand store `usePledgeStore`:

```ts
interface PledgeStore {
  overdueAlertExpanded: boolean;          // defaults to true
  toggleOverdueAlert: () => void;

  filterChip: "all" | "active" | "fulfilled" | "overdue" | "cancelled";
  setFilterChip: (c: …) => void;

  cancelConfirmOpen: boolean;
  setCancelConfirmOpen: (v: boolean) => void;
  // selectedPledgeId — NOT stored; derived from URL (SR deviation 2)
}
```

Persisted via `zustand/middleware` (`persist({ name: "pledge-store", partialize: (s) => ({ overdueAlertExpanded: s.overdueAlertExpanded, filterChip: s.filterChip }) })`).

### 5.3 Structure

```tsx
<div role={isFirstAnnouncement ? "alert" : undefined} aria-live="polite" className="mb-3 rounded-lg border border-destructive/40 bg-destructive/5">
  {/* Header row (always visible) */}
  <div className="flex items-center justify-between gap-3 px-4 py-2">
    <div className="flex items-start gap-2 min-w-0">
      <Icon icon="ph:warning-octagon-duotone" className="h-5 w-5 text-destructive shrink-0 mt-0.5" />
      <p className="text-sm text-foreground min-w-0">
        <span className="font-semibold text-destructive">{summary.overdueCount}</span>{" "}
        pledge payment{summary.overdueCount === 1 ? " is" : "s are"} overdue totaling{" "}
        <span className="font-semibold text-destructive">
          {summary.currencyCode} {summary.overdueAmountTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </span>.
      </p>
    </div>
    <div className="flex items-center gap-2 shrink-0">
      <Button size="sm" variant="destructive" onClick={handleSendBulkReminders} className="h-7 px-2 text-xs gap-1">
        <Icon icon="ph:bell-ringing-duotone" className="h-3.5 w-3.5" />Send Bulk Reminders
      </Button>
      <Button size="sm" variant="outline" onClick={handleViewAllOverdue} className="h-7 px-2 text-xs gap-1">
        <Icon icon="ph:funnel-duotone" className="h-3.5 w-3.5" />View All Overdue
      </Button>
      <button type="button" onClick={toggleOverdueAlert}
        className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-medium text-foreground hover:bg-destructive/10 transition-colors"
        aria-expanded={overdueAlertExpanded}
        aria-label={overdueAlertExpanded ? "Collapse overdue details" : "Expand overdue details"}
      >
        <span>Details</span>
        <Icon icon="ph:caret-down-bold" className={cn("h-3.5 w-3.5 transition-transform duration-200", overdueAlertExpanded && "rotate-180")} />
      </button>
    </div>
  </div>

  {/* Body table (expanded) */}
  {overdueAlertExpanded && (
    <div className="border-t border-destructive/40 overflow-x-auto">
      <table className="w-full text-xs">
        <thead className="bg-destructive/5">
          <tr className="text-left text-muted-foreground">
            <th className="px-4 py-2 font-medium">Pledge ID</th>
            <th className="px-4 py-2 font-medium">Donor</th>
            <th className="px-4 py-2 font-medium">Due Date</th>
            <th className="px-4 py-2 font-medium">Amount Due</th>
            <th className="px-4 py-2 font-medium">Days Overdue</th>
            <th className="px-4 py-2 font-medium text-right">Action</th>
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr><td colSpan={6} className="px-4 py-4 text-center text-muted-foreground">No overdue payments to show</td></tr>
          ) : rows.map(r => (
            <tr key={r.pledgePaymentId} className="border-t border-destructive/20 hover:bg-destructive/5">
              <td className="px-4 py-2 font-mono text-muted-foreground">{r.pledgeCode}</td>
              <td className="px-4 py-2 font-medium"><DonorLink contactId={r.contactId} name={r.donorName} compact /></td>
              <td className="px-4 py-2">{formatShort(r.dueDate)}</td>
              <td className="px-4 py-2 font-mono"><CurrencyAmount amount={r.dueAmount} code={r.currencyCode} /></td>
              <td className="px-4 py-2"><span className="font-bold text-destructive">{r.daysOverdue}</span> <span className="text-[10px] text-muted-foreground">days</span></td>
              <td className="px-4 py-2">
                <div className="flex items-center justify-end">
                  <Button size="sm" variant="outline" className="h-7 px-2 text-[11px] gap-1"
                    onClick={() => handleSendReminder(r)}
                    aria-label={`Send reminder for ${r.donorName}`}>
                    <Icon icon="ph:bell-duotone" className="h-3.5 w-3.5" />Send Reminder
                  </Button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )}
</div>
```

### 5.4 Action handlers (SERVICE_PLACEHOLDER)

```ts
const handleSendBulkReminders = () => {
  // SERVICE_PLACEHOLDER — notification service not wired
  toast.info(`Bulk reminders queued for ${summary.overdueCount} donor(s) — notification service pending.`);
};

const handleSendReminder = (r: PledgeOverdueAlertDto) => {
  // SERVICE_PLACEHOLDER
  toast.info(`Reminder queued for ${r.donorName} — notification service pending.`);
};

const handleViewAllOverdue = () => {
  setFilterChip("overdue");   // Zustand → drives chip → grid refetch
};
```

### 5.5 Data source

Dedicated `PLEDGE_OVERDUE_ALERT_QUERY` returns `PledgeOverdueAlertDto[]` (top 5, ordered `daysOverdue DESC`). Fires in parallel with summary query; never reuses the full grid query.

---

## 6. Four New Renderers — Contracts

All four renderers live in `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/` and are registered in the three registries:
- `presentation/components/data-table/component-column.tsx` (advanced)
- `presentation/components/data-table/basic/component-column.tsx`
- `presentation/components/data-table/flow/component-column.tsx`

Plus exported from the barrel `shared-cell-renderers/index.ts`.

### 6.1 `donor-link` — Registry key: `"donor-link"`

**Usage**: Grid column 2 (Donor), Drawer summary Donor row, Overdue banner Donor column, Payment history row (not needed — no donor per row there).

```ts
interface DonorLinkProps {
  contactId: number;
  name: string;              // primary display
  code?: string | null;      // e.g. "C-00042" muted subtitle (grid only)
  avatarColor?: string | null; // projected hex from BE or derived from contactId hash
  compact?: boolean;         // banner + drawer mode — no avatar; just link + name
  lang: string;              // for deep-link
}
```

Visual:
- Full mode (grid): `<div className="flex items-center gap-2"><Avatar colorHex={avatarColor} name={name}/><div className="flex flex-col min-w-0"><a className="text-xs font-medium text-primary hover:underline truncate">{name}</a>{code && <span className="text-[10px] text-muted-foreground truncate">{code}</span>}</div></div>`
- Compact mode: just the `<a>` (no avatar, no code).
- **Click**: `router.push("/${lang}/crm/contact/allcontacts?mode=read&id={contactId}")`.
- **Fallback** (ISSUE-2): wrap in a feature-flag check (`FEATURE_CONTACT_VIEW`). If false/stub → `onClick` toasts `"Contact detail view coming soon"`.
- Keyboard: `<a>` is native focusable; no extra ARIA needed beyond `aria-label="View donor profile: {name}"`.
- **Avatar color** is derived FE-side from `contactId` hash (per BA OQ — strip from BE DTO projection if FE computes). Use a fixed palette of 8 token-driven classes.

### 6.2 `currency-amount` — Registry key: `"currency-amount"`

**Usage**: Grid columns 4/5/6 (Total Pledged / Fulfilled / Balance), Drawer summary, Overdue banner Amount Due, Payment history Due Amount / Paid Amount.

```ts
interface CurrencyAmountProps {
  amount: number | null | undefined;
  code?: string | null;         // "USD" / "AED" / "INR"
  size?: "sm" | "md" | "lg";   // sm = xs font, md = sm font, lg = lg font bold
  weight?: "normal" | "bold";
  tone?: "default" | "success" | "warning" | "danger" | "muted";
  align?: "start" | "end";      // default "end" in grid, "start" in details
  showSymbol?: boolean;        // default true
  empty?: React.ReactNode;     // what to render when amount is null (default "—")
}
```

Visual:
- Wrapper: `<span className={cn("font-mono tabular-nums", align === 'end' && "text-right block", sizeClass, weightClass, toneClass)}>`
- Format: `${code} ${amount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` if `code` set and `showSymbol` true; else just the number.
- Tone tokens: `success` → `text-emerald-700 dark:text-emerald-300`; `warning` → `text-amber-700 dark:text-amber-300`; `danger` → `text-destructive`; `muted` → `text-muted-foreground`; `default` → `text-foreground`.
- Null handling: render `empty` (default "—") with muted color.

### 6.3 `fulfillment-progress` — Registry key: `"fulfillment-progress"`

**Usage**: Grid column 7 (Fulfillment), Drawer summary Fulfillment row.

```ts
interface FulfillmentProgressProps {
  percent: number;                // 0..100 (already capped by BE)
  statusCode: "ONTRACK" | "FULFILLED" | "OVERDUE" | "BEHIND" | "CANCELLED";
  inline?: boolean;               // drawer mode = inline (bar + label in same flex line)
  showLabel?: boolean;            // default true
}
```

Visual:
- Outer: `<div className={cn("flex items-center gap-2", inline ? "flex-row" : "flex-col items-stretch")}>`
- Bar: `<div className="h-1.5 flex-1 rounded-full bg-muted overflow-hidden"><div className={cn("h-full transition-all", toneClass)} style={{ width: `${percent}%` }} role="progressbar" aria-valuenow={percent} aria-valuemin={0} aria-valuemax={100} aria-label={"Fulfillment {percent}%"} /></div>`
- Label: `<span className="text-[11px] font-medium text-foreground tabular-nums w-10 text-right">{percent}%</span>`
- **Color by statusCode** (tokens only):
  - FULFILLED → `bg-teal-500`
  - ONTRACK → `bg-emerald-500`
  - BEHIND → `bg-amber-500`
  - OVERDUE → `bg-destructive`
  - CANCELLED → `bg-muted-foreground/40` + label muted, strike-through
- Accessibility: bar has `role="progressbar"` with `aria-valuenow/min/max` and a concise `aria-label`.

### 6.4 `payment-status-chip` — Registry key: `"payment-status-chip"`

**Usage**: Payment history table Status column (drawer). NOT used in grid (grid uses generic `status-badge` for pledge-level status).

```ts
interface PaymentStatusChipProps {
  code: "PAID" | "UPCOMING" | "SCHEDULED" | "OVERDUE";
  /** Falls through to muted chip when unknown. */
}
```

Visual (same shape as `StatusPill` in the sibling drawer, with a different tone map):

```
PAID       → emerald ring + `ph:check-circle-duotone`     → label "Paid"
UPCOMING   → amber   ring + `ph:clock-duotone`            → label "Upcoming"
SCHEDULED  → slate   ring + `ph:calendar-duotone`         → label "Scheduled"
OVERDUE    → destructive ring + `ph:warning-circle-duotone` → label "Overdue"
```

```tsx
<span className={cn(
  "inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-semibold",
  toneClasses.bg, toneClasses.text, toneClasses.border
)}>
  <Icon icon={iconName} className="h-3 w-3" />
  {label}
</span>
```

### 6.5 Registration (wiring)

In each of the three component-column files, add:
```ts
import { DonorLink } from "custom-components/.../donor-link";
import { CurrencyAmount } from ".../currency-amount";
import { FulfillmentProgress } from ".../fulfillment-progress";
import { PaymentStatusChip } from ".../payment-status-chip";

const RENDERERS = {
  // …existing keys
  "donor-link":          DonorLink,
  "currency-amount":     CurrencyAmount,
  "fulfillment-progress": FulfillmentProgress,
  "payment-status-chip": PaymentStatusChip,
};
```

Also export from `shared-cell-renderers/index.ts`:
```ts
export * from "./donor-link";
export * from "./currency-amount";
export * from "./fulfillment-progress";
export * from "./payment-status-chip";
```

> Per ISSUE-11 — verify no pre-existing registry keys named `donor-link` / `currency-amount` before registration. If collision exists, suffix with `-cell`.

---

## 7. Frequency Suffix Resolution (OQ-7 — LOCKED DECISION)

### 7.1 The problem

`MasterData.dataValue` for PLEDGEFREQUENCY stores **integer days** (`"30"`, `"90"`, `"180"`, `"365"`, `"0"`). The FE needs display suffixes like `/mo`, `/qtr`, `/6mo`, `/yr`, `""`.

### 7.2 The resolution — FE-side derivation from `dataValue`

The FE maintains a constant map keyed by the MasterData **dataValue** (not the dataName, to survive i18n):

```ts
// PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/pledge/pledge-constants.ts
export const FREQUENCY_SUFFIX_BY_DAYS: Record<string, string> = {
  "30":  "/mo",
  "90":  "/qtr",
  "180": "/6mo",
  "365": "/yr",
  "0":   "",          // CUSTOM → no suffix
};

export function suffixFromDataValue(dataValue: string | number | null | undefined): string {
  if (dataValue == null) return "";
  const key = String(dataValue);
  return FREQUENCY_SUFFIX_BY_DAYS[key] ?? "";
}
```

### 7.3 Where it is applied

- **Grid column 8 (Schedule)**: `scheduleDisplay` is projected BE-side as `"{currencyCode} {installmentAmount}"`; FE appends ` ${suffixFromDataValue(frequencyDataValue)}`. Requires `frequencyDataValue` in `PledgeResponseDto` (add alongside `frequencyName`).
- **Drawer summary Schedule row**: uses the helper directly.
- **FORM helper text** (Card 3 bottom): uses the helper directly.

### 7.4 BE contract delta (required)

`PledgeResponseDto.frequencyDataValue: string` — add to the projection. Remove the prior `frequencySuffix` field from the DTO (FE-derived). This aligns with OQ-7 recommendation (remove BE coupling to display suffix strings).

### 7.5 Same treatment for MONTHLY/QUARTERLY/… in Card 3 helper

When computing helper text "End Date: …", use the days-based suffix map for the schedule summary string.

---

## 8. Responsive Rules (xs → xl)

### 8.1 Global rules

- No horizontal scroll at any breakpoint on the main page (index-page).
- Drawer and grid both support horizontal overflow via `overflow-x-auto` on their innermost scrolling container; never on the page root.

### 8.2 Per-surface breakpoint behavior

| Surface | xs (<640 `sm`) | sm (640–767) | md (768–1023) | lg (≥1024) |
|---------|---------------|---------------|----------------|-----------|
| **KPI grid** | `grid-cols-2` (2×2) | `grid-cols-2` | `grid-cols-2` | `grid-cols-4` (1 row) |
| **Overdue banner header** | header row stacks to 2 rows: top = text, bottom = buttons; chevron stays in top-right | same | single row | single row |
| **Overdue banner body** | `overflow-x-auto` — horizontally scroll the table; column widths preserved | same | same | fits |
| **Filter chips** | horizontal scroll row (`flex overflow-x-auto no-scrollbar`) | horizontal scroll | wraps / inline | wraps / inline |
| **Advanced filters (panel)** | 1-col stack, all fields full-width | 1-col | `grid-cols-2` | `grid-cols-3` (Apply/Clear right-aligned) |
| **Grid toolbar** | export buttons collapse into an overflow `⋯` menu; +New Pledge button keeps text | same | full | full |
| **Grid rows** | AdvancedDataTable handles horizontal scroll; 3 predefined cols always visible (Pledge ID, Donor, Status) | same | same | no scroll |
| **Drawer** | `w-full` (full viewport) | `w-full` | `sm:max-w-[720px]` | `sm:max-w-[720px]` |
| **Drawer header action cluster** | buttons use icon-only (text hidden `hidden sm:inline`) | icon + short text | full | full |
| **Drawer summary grid** | `grid-cols-1` (stacked) | `grid-cols-1` | `md:grid-cols-2` | `md:grid-cols-2` |
| **Payment timeline** | vertical stack (`flex-col`), connector 3×24px vertical | vertical | horizontal (`md:flex-row`) | horizontal |
| **Payment history table** | `overflow-x-auto` wrapper; Donation Ref column hidden on < md via `hidden md:table-cell` | same | full | full |
| **FORM Card 1** | 1-col stack | 1-col | `md:grid-cols-12` (6/6 + 12) | same |
| **FORM Card 2** | 1-col | 1-col | `md:grid-cols-12` (4/8 + 6/6) | same |
| **FORM Card 3** | 1-col | 1-col | `md:grid-cols-12` (4/4/4 + 6/_) | same |
| **FORM Card 4** | 1-col (Notes always full-width) | 1-col | 1-col | 1-col |
| **Schedule Preview** | vertical (inherits timeline vertical on mobile) | vertical | horizontal | horizontal |

### 8.3 Admin-facing-only portions (kept desktop-capable)

- Grid full-screen mode is desktop-only; no mobile "full-screen" styling.
- Export dropdown remains in header on all breakpoints (just icon on xs — label hidden).

---

## 9. Accessibility Notes

### 9.1 Drawer

- **Focus trap**: Radix `Sheet` provides automatic focus trap. First focusable element on open = the Edit button (when present) or Close button. Focus returns to the triggering grid row on close (Radix auto).
- **ESC closes**: default Radix behavior via `onOpenChange(false)`; no extra wiring needed.
- **`aria-labelledby="pledge-drawer-title"`** on `SheetContent`, matching the `SheetTitle id`.
- **Cancel inline form**: when opened, move focus to the textarea (`useEffect` + `ref.focus()`); on submit, move focus to a toast live region.

### 9.2 Overdue banner

- First render with `summary.overdueCount > 0`: `role="alert"` + `aria-live="polite"` (announces once). Subsequent re-renders drop `role="alert"` (via `announcedRef` guard, mirroring the sibling). This prevents screen reader spam on refetch.
- Collapse chevron: `aria-expanded={overdueAlertExpanded}` + `aria-label` toggles between "Collapse…" / "Expand…".
- Per-row Send Reminder: `aria-label="Send reminder for {donorName}"` (donor name in label).

### 9.3 Filter chips

- Each chip is a `<button role="tab" aria-selected={isActive}>` inside a `<div role="tablist" aria-label="Filter pledges by status">`. Active chip has `aria-selected="true"`. Reuses platform `FilterChipBar` pattern from sibling.

### 9.4 Dropdowns

- ApiSelectV2/V3: already accessible via Radix `Popover` + `Combobox` primitives. Placeholder text is the `aria-label` when no value is selected. FK select options include both `displayName` + `code` for screen-reader context.

### 9.5 Progress bar

- `role="progressbar"` + `aria-valuenow` / `aria-valuemin=0` / `aria-valuemax=100` + `aria-label="Fulfillment: {percent}%"` on every instance.

### 9.6 Timeline

- Each node (actual mode): `<button aria-label="Installment {n}: {statusLabel} — {currency} {amount} due {date}">`. Nodes are keyboard-reachable (`tab`) with `Enter` triggering `onNodeClick`.

### 9.7 Forms

- Every RHF field wraps label + input with `<Label htmlFor="{id}">` + `aria-invalid={!!errors[name]}` + `aria-describedby="{id}-error"` when error present.
- Required fields have a visible `*` + `aria-required="true"`.
- Validation error summary at top of form has `role="alert"` and focuses on first render after a failed submit.

### 9.8 Color-contrast

All tone tokens (`text-destructive`, `text-emerald-700 dark:text-emerald-300`, etc.) are pre-verified AA-compliant in the existing design system. Never pair colored backgrounds with colored foregrounds without a platform token.

---

## 10. Empty / Loading / Error States — Per Surface

### 10.1 Widgets (KPI)

- **Loading**: 4 `WidgetCard` skeletons (icon square + 3 text lines). Layout identical to loaded — zero CLS.
- **Empty (summary null, no error)**: render primary = `—`, secondary = `null` (hidden). No "No data" text.
- **Error**: the outer `index-page` top-level error banner catches; widgets render with `—`.

### 10.2 Overdue banner

- **Loading**: `<div className="mb-3 rounded-lg border border-destructive/40 bg-destructive/5 px-4 py-3"><Skeleton h-4 w-4 rounded /> <Skeleton h-3.5 w-72 /></div>`.
- **Empty (overdueCount === 0)**: returns `null` — no empty banner rendered.
- **Error (query errored, count unknown)**: returns `null` — don't surface an alarming banner for a query failure. The grid itself surfaces errors elsewhere.

### 10.3 Grid

- **Loading**: skeleton rows (AdvancedDataTable built-in).
- **Empty**: use platform `EmptyState` with:
  - Icon `ph:handshake-duotone` (muted)
  - Title "No pledges yet"
  - Subtitle "Create a pledge to start tracking donor commitments and fulfillment progress."
  - CTA button `"+ New Pledge"` (opens `?mode=new`)
- **Filtered-empty** (chips/filters returning zero rows): title "No pledges match your filters", subtitle "Try clearing filters or selecting a different chip.", CTA "Clear filters" → `router.replace(pathname)`.
- **Error**: platform error banner.

### 10.4 Drawer

- **Loading** (while `pledgeById` is in flight): `DrawerSkeleton` replicates 4 sections — each with a title skeleton + 4 row skeletons. Matches real layout for zero CLS.
- **Not found** (`record === null` after query): `<div className="flex flex-col items-center justify-center py-16 text-center"><Icon icon="ph:warning-duotone" className="h-10 w-10 text-muted-foreground/60 mb-2"/><p className="text-sm font-medium text-muted-foreground">Pledge not found or no longer accessible</p><Button variant="ghost" className="mt-3" onClick={handleClose}>Close</Button></div>`.
- **Section 2 (Timeline) empty**: when `paymentSchedule.length === 0` (shouldn't happen — BE always generates ≥ 1) → `<p className="text-xs text-muted-foreground py-2">No schedule generated.</p>`.
- **Section 3 (History) empty**: when no paid rows exist → table still shows all rows with `SCHEDULED`/`UPCOMING` statuses. Never a blank table.

### 10.5 FORM

- **Loading** (edit mode, while `pledgeById` hydrates): each card renders a 3-row skeleton (`space-y-2` of `Skeleton h-9 w-full`). Save button disabled. After hydration, reset form.
- **Error** (hydrate failed): render page-level error banner + Back button.
- **Save error**: `toast.error(errorDetails)` + keep form state as-is.
- **Schedule Preview empty**: text "Fill in amount, frequency, and start date to preview the schedule." (per 2.2 CARD 3).

### 10.6 Action handlers (SERVICE_PLACEHOLDER toasts)

All placeholder toasts use `toast.info(...)` (blue/info variant) — **never** `toast.success(...)` — because the underlying service has not actually run. This avoids training staff to treat placeholders as real.

---

## 11. Open Items Carried Forward

- OQ-1 / ISSUE-1: GlobalDonation form must accept `?pledgePaymentId=X` → out of scope for this UX spec; FE dev must coordinate with Screen #3 team or stub a guard toast.
- OQ-6 / PledgePayment `IsCancelled` column: BE decision — UX assumes child rows still render in Payment History even after pledge cancel, dimmed at `opacity-60` (matches cancelled row styling).
- OQ-7 resolved in §7 above (FE-side suffix derivation from `frequencyDataValue`).

---

## 12. Layout Fidelity — Mockup-to-Blueprint Crosswalk

| Mockup element | Blueprint decision | Fidelity status |
|---------------|-------------------|-----------------|
| Top header strip "Pledge Management" | `ScreenHeader` w/ icon `ph:handshake-duotone` + title + subtitle + action cluster | ✅ preserved |
| `stats-grid` 4 cards `repeat(auto-fit, minmax(210px, 1fr))` | `grid-cols-2 lg:grid-cols-4` (auto-fit equivalent via 2 breakpoints) | ✅ preserved |
| Overdue "warning-box" banner | `pledge-overdue-alert-banner.tsx`; collapsible by default expanded | ✅ preserved |
| Filter chips row | `PledgeFilterChips` component with 5 chips | ✅ preserved |
| Advanced filter drawer trigger | `PledgeAdvancedFilters` collapsible panel (7 fields) | ✅ preserved |
| Data grid 11 cols | FLOW grid columns 1..11 as configured in ⑨ | ✅ preserved |
| Modal "Create Pledge" (mockup) | Rendered as full-page FORM (`view-page.tsx`) per FLOW convention | ✅ intentional deviation (documented) |
| 4 sections in modal body | 4 cards in FORM (same labels + icons + field order) | ✅ preserved |
| Right-side detail panel 720px | `Sheet` `sm:max-w-[720px]` | ✅ preserved |
| Detail panel: summary grid + timeline + history + cancel | 4 sections in body, same order | ✅ preserved |
| Timeline: horizontal color dots | `PledgePaymentTimeline` with Phosphor icons, tokens only | ✅ preserved |
| History table | `PledgePaymentHistoryTable` with 7 cols | ✅ preserved |
| Cancel inline form at panel bottom | Section 4 inline form (hidden until button click) | ✅ preserved |

Mockup Font-Awesome icons (ISSUE-8) are translated to Phosphor (see icon columns throughout this spec).

---

## 13. Icon Crosswalk (FA → Phosphor duotone)

| Mockup (FA) | This spec (Phosphor) |
|------------|---------------------|
| `fa-handshake` | `ph:handshake-duotone` |
| `fa-triangle-exclamation` / `fa-warning` | `ph:warning-octagon-duotone` (banner) / `ph:warning-duotone` (inline) |
| `fa-check-circle` | `ph:check-circle-duotone` |
| `fa-hourglass` | `ph:hourglass-medium-duotone` |
| `fa-circle-exclamation` | `ph:warning-circle-duotone` |
| `fa-user-circle` | `ph:user-circle-duotone` |
| `fa-dollar` / `fa-money-bill` | `ph:currency-dollar-duotone` |
| `fa-calendar-check` | `ph:calendar-check-duotone` |
| `fa-pen` / `fa-pencil` | `ph:pencil-simple-duotone` |
| `fa-bell` | `ph:bell-duotone` / `ph:bell-ringing-duotone` |
| `fa-timeline` / `fa-stream` | `ph:timer-duotone` |
| `fa-clock-rotate-left` / `fa-history` | `ph:clock-counter-clockwise-duotone` |
| `fa-x-circle` / `fa-times-circle` | `ph:x-circle-duotone` |
| `fa-file-invoice-dollar` / `fa-receipt` | `ph:receipt-duotone` |
| `fa-filter` | `ph:funnel-duotone` |
| `fa-caret-down` | `ph:caret-down-bold` |
| `fa-plus` | `ph:plus-bold` |

All icons via `@iconify/react` — never emoji, never raw `<i class="fa ...">`.

---

## 14. Summary of Decisions

1. **Variant B + `showHeader={false}`** — identical wiring to `recurringdonors/index-page.tsx`.
2. **Two parallel queries** on mount: `PLEDGE_SUMMARY_QUERY` + `PLEDGE_OVERDUE_ALERT_QUERY`. Both `cache-and-network`. `handleAfterMutation` refetches both.
3. **Drawer at 720px** via `sm:max-w-[720px] max-w-[720px]`. URL-driven open state; close preserves chip/search/filter query params.
4. **`selectedPledgeId` not in Zustand** — derive from URL params.
5. **4 cards in FORM** matching mockup; `useWatch` with touched-field guards for auto-calc; Zod validation; ±$1.00 installment-sum tolerance.
6. **Schedule Preview** embedded in Card 3 using the **same `PledgePaymentTimeline`** component as the drawer (mode='preview' vs 'actual').
7. **4 new renderers** (`donor-link`, `currency-amount`, `fulfillment-progress`, `payment-status-chip`) with exact registry keys; registered in all 3 component-column registries + exported from barrel.
8. **Frequency suffix is FE-derived** from a days-based map (keys: "30"/"90"/"180"/"365"/"0"). BE DTO gains `frequencyDataValue`; the prior `frequencySuffix` string field is removed.
9. **All icons Phosphor duotone** via `@iconify/react` — zero Font Awesome, zero emoji.
10. **All colours via tokens** (`text-destructive`, `bg-emerald-500`, `text-muted-foreground`, `border-border`, `bg-card`, …) — zero raw hex in the blueprint.
11. **2×2 on mobile / 1×4 on desktop** for KPI grid.
12. **Timeline vertical on < md**, horizontal on ≥ md.
13. **SERVICE_PLACEHOLDER toasts** use `toast.info` only, never `toast.success`.
14. **Donor-link fallback** (ISSUE-2): feature-flag check; toast if Contact screen not yet built.
15. **Error/Empty/Loading states** have explicit shapes for every surface (no CLS); skeletons match final layout.
