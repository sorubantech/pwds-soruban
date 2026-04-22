---
document: Solution Resolver Validation Notes
screen: Pledge
registry_id: 12
sr_author: Solution Resolver (claude-sonnet-4-6)
sr_date: 2026-04-21
source_prompt: pledge.md
siblings_verified: DonationInKind #7, RecurringDonationSchedule #8
---

## Classification

### Verdict: CONFIRMED — FLOW + Variant B + side-drawer DETAIL + KPIs + Alert Banner

The Section ⑤ classification is architecturally sound. Spot-checks of both sibling screens
confirm every structural claim.

**Evidence from recurringdonors/index-page.tsx:**

The Variant B stack is exactly:
  ScreenHeader
  → RecurringWidgets (KPI cards)
  → FailedPaymentsAlertBanner (conditional)
  → RecurringFilterChips
  → RecurringAdvancedFilters
  → FlowDataTableContainer showHeader={false}
  → RecurringScheduleDetailDrawer (mounted once, URL-driven)

Pledge must replicate this structure verbatim with pledge-specific components at each slot.
The `showHeader={false}` flag on FlowDataTableContainer is mandatory — verified in sibling.

**Evidence from donationinkind/dik-detail-drawer.tsx:**

Drawer is implemented via Shadcn `Sheet` / `SheetContent` component with
`side="right"` and `className="w-full sm:max-w-[520px] max-w-[520px]"`.
Pledge specifies 720px instead of 520px — that deviation is intentional and justified by
the richer drawer body (summary grid + timeline + history table vs. DIK's 6 read-only sections).
FE dev: use `sm:max-w-[720px] max-w-[720px]` in SheetContent className.

**Drawer open/close mechanism:**

RecurringDonationSchedule drawer is URL-driven (`?mode=read&id=X`) and mounted once in
index-page — Pledge follows the same contract. DonationInKind drawer is Zustand-state-driven
(`drawerOpen` flag). Both patterns are valid; Pledge chooses URL-driven (matching #8) because
it also needs `?mode=new` and `?mode=edit` URL modes. Zustand store (`pledge-store.ts`) still
required for overlay state, banner collapsed/expanded, cancel-confirm open state.

**Overdue Alert Banner vs Failed Payments Banner:**

RecurringDonationSchedule `FailedPaymentsAlertBanner` receives `(data, summary, loading)` props
from index-page.tsx, with visibility gated on `summary.failedThisMonth > 0`. Pledge's
`pledge-overdue-alert-banner.tsx` must follow identical prop shape:
  `({ data: PledgeOverdueAlertDto[] | null, summary: PledgeSummaryDto | null, loading: boolean })`
Visibility gated on `summary.overdueCount > 0`. Expanded state persisted in Zustand
`overdueAlertExpanded` (mirrors `failedAlertExpanded` in recurringdonationschedule-store.ts).

**KPI query wiring:**

index-page.tsx fires TWO separate Apollo queries in parallel:
  `RECURRINGDONATIONSCHEDULE_SUMMARY_QUERY`   → RecurringWidgets
  `RECURRINGDONATIONSCHEDULE_FAILED_ALERT_QUERY` → FailedPaymentsAlertBanner

Pledge requires the same two-query pattern:
  `PLEDGE_SUMMARY_QUERY`         → pledge-widgets.tsx
  `PLEDGE_OVERDUE_ALERT_QUERY`   → pledge-overdue-alert-banner.tsx

Both are `fetchPolicy: "cache-and-network"`. The `handleAfterMutation` callback passed to
the drawer must call `summaryRefetch()` and `failedAlertRefetch()` (as in #8) so KPIs and
banner update immediately after Cancel or other mutations.

---

## Pattern Selection

### Standard CRUD (11 files): CONFIRMED

Checklist in Section ⑤ is correct. All 17 BE files in the manifest are accounted for.

### Child Row Auto-Generation: CONFIRMED — verified against RecurringDonationSchedule

**How #8 handles child rows on Create:**

In `CreateRecurringDonationScheduleHandler.Handle()`, child Distributions are attached to the
parent entity via the navigation property before `dbContext.SaveChangesAsync()`:

    entity.Distributions = req.Distributions.Select(d => new ...Distribution { ... }).ToList();
    dbContext.RecurringDonationSchedules.Add(entity);
    await dbContext.SaveChangesAsync(cancellationToken);

EF Core resolves the FK insert order automatically (parent first, children second).

**Key difference for Pledge:**

RecurringDonation Distributions are provided BY THE FRONTEND in the request DTO.
Pledge's PledgePayment rows are NOT provided by the FE — they are COMPUTED by the BE
handler from (StartDate, FrequencyId, InstallmentAmount, NumberOfInstallments, TotalPledgedAmount).

The CreatePledge handler must therefore:
1. Receive only the parent Pledge fields in the request DTO.
2. Compute N installment dates/amounts in a private method (schedule generation loop).
3. Attach `entity.PledgePayments = GenerateSchedule(...)` before SaveChangesAsync.

The generation logic mirrors the AddFrequencyInterval helper already in
CreateRecurringDonationScheduleHandler — reuse that pattern directly.

**How Update diff-regeneration should work (no existing example in #8):**

RecurringDonation Update does NOT regenerate children (Distributions are re-sent by FE in full).
Pledge is different: UpdatePledge must:
1. Load existing PledgePayments for this PledgeId.
2. Keep rows where PaymentStatusCode = 'PAID' (historical facts).
3. Delete unpaid rows (UPCOMING / SCHEDULED / OVERDUE) from the context.
4. Regenerate fresh unpaid rows from the next unrecorded installment.
5. Wrap in a transaction (Section ⑫ ISSUE-5 requirement).

This is a NEW pattern in this codebase — no direct sibling example exists. The developer must
implement this in UpdatePledge.cs using a `using var transaction = await dbContext.Database.BeginTransactionAsync()` block.

### Summary Query: CONFIRMED — pattern is established

`GetRecurringDonationScheduleSummaryHandler` demonstrates the canonical pattern:
- Query record with no input args; companyId from HttpContext.
- Multiple `await baseQuery.CountAsync(...)` calls with different predicates.
- Returns a strongly-typed SummaryDto.
- Authorization attribute commented out (consistent with `pledgeSummary` also being comment-auth).

`GetPledgeSummary` must follow the same shape. Key implementation notes from the sibling:
- MRR currency is resolved by detecting the most-frequent CurrencyId among active schedules
  (because Company.DefaultCurrencyId does not exist yet). Pledge summary has ISSUE-12 flagged
  for the same multi-currency problem — use the same workaround pattern.
- Multiple `.ToListAsync()` → in-memory LINQ for derived figures (avgDurationMonths). Pledge
  equivalents (fulfilledAmountYtd, outstandingBalanceTotal) should prefer subqueries in a
  single SQL rather than multiple round trips. EF LINQ subquery approach: use `.Select()` with
  inner `.Sum()` in LINQ expression to let EF translate to LATERAL JOIN.

### Overdue Lazy-Flip: NEW PATTERN — not in #7 or #8

No existing sibling executes an UPDATE statement inside a query handler. This is a deliberate
architectural choice described in Section ④:

> On every GetAll call, re-evaluate all unpaid PledgePayments where DueDate < today AND
> PaymentStatusCode='UPCOMING' → flip to OVERDUE.

This is valid but the developer must be aware of two risks:
1. It couples a write to a read handler — violates CQRS strictly. Acceptable here by
   explicit architectural decision (lazy-flip pattern), but should be noted.
2. If GetAll is called from a non-mutating read (e.g., report), the UPDATE still fires.
   This is acceptable because overdue-flip is idempotent and has no observable side effects
   beyond data accuracy.

Implementation: before the main SELECT in GetPledgesHandler.Handle(), execute:
    await dbContext.PledgePayments
        .Where(p => p.DueDate < today && p.PaymentStatus.DataValue == "UPCOMING"
                    && p.CompanyId == companyId)
        .ExecuteUpdateAsync(s => s.SetProperty(p => p.PaymentStatusId, overdueStatusId), ct);

Use `ExecuteUpdateAsync` (EF 7+) for a single SQL UPDATE without loading entities.
The developer must resolve `overdueStatusId` with a pre-query on MasterData (cached or
fetched once per request). Confirm EF version supports ExecuteUpdateAsync — if on EF 6,
use raw SQL via `dbContext.Database.ExecuteSqlRawAsync(...)`.

### FK Validation (×8): CONFIRMED

Section ⑤ lists 8 FK validations. This is correct per the entity definition. However,
ValidateForeignKeyRecord in the sibling (CreateRecurringDonationScheduleValidator) uses the
pattern:

    ValidateForeignKeyRecord<MasterData, int>(x => x.FrequencyId, _dbContext.MasterDatas, c => c.MasterDataId);

For the three MasterData FKs (FrequencyId, PledgeStatusId, PaymentStatusId), the validator
cannot distinguish which typeCode is intended — ValidateForeignKeyRecord only checks for row
existence, not typeCode membership. This is sufficient for runtime safety (the seed data
ensures valid IDs); no additional typeCode guard is needed.

CampaignId is nullable (int?) — the FK validation must be wrapped with a `.When(x => x.CampaignId.HasValue)` guard. Check that ValidateForeignKeyRecord handles nullable correctly
or add an explicit guard. Similarly PaymentModeId is nullable.

### Unique Validation: CONFIRMED

PledgeCode filtered-unique per Company uses the async MustAsync pattern (same as
GatewaySubscriptionId uniqueness in the #8 validator). Pattern to follow verbatim.

### Cancel Command: CONFIRMED — same pattern as RecurringDonationSchedule Cancel

Verified from recurring-schedule-detail-drawer.tsx lines 19-23:
    ACTIVATE_DEACTIVATE_RECURRINGDONATIONSCHEDULE_MUTATION (for cancel)
    RESUME_RECURRINGDONATIONSCHEDULE_MUTATION

CancelPledge is a separate command file in the manifest
(`Business/DonationBusiness/Pledges/Commands/CancelPledge.cs`). This is correct — do not
embed cancel logic in UpdatePledge.

### GetNextDuePledgePayment Query: CONFIRMED — justified new helper

This query exists to resolve `nextDuePledgePaymentId` for the "Record Payment" cross-screen
deep-link. It is not a pattern seen in siblings, but the use case is well-defined and the
implementation is trivial:
    SELECT TOP 1 FROM PledgePayments WHERE PledgeId = @id AND PaymentStatusCode IN ('UPCOMING','OVERDUE')
    ORDER BY DueDate ASC

Alternatively, `nextDuePledgePaymentId` can be projected inline into the PledgeResponseDto
returned by `pledgeById` — which is already specified in Section ⑩ as `nextDuePledgePaymentId`.
If that projected field is populated, a separate `nextDuePledgePayment` query may be redundant.
DECISION NEEDED: decide whether `nextDuePledgePaymentId` in PledgeResponseDto (GetAll +
GetById) is sufficient, or whether a dedicated per-pledge query is needed. Recommendation:
project `nextDuePledgePaymentId` into both GetAll and GetById rows, and remove the standalone
GetNextDuePledgePayment query to reduce endpoint surface area.

---

## Complexity

### Verdict: High — CONFIRMED

High rating is justified. Contributing factors individually and cumulatively:

1. Two entities (parent Pledge + child PledgePayment) with a EF navigation relationship.
2. Auto-generated child rows on Create (schedule generation algorithm — not UI-driven input).
3. Diff-regenerate on Update — NEW pattern not in any existing sibling; must preserve paid
   rows and delete/regenerate unpaid rows atomically in a transaction.
4. Five projected computed fields per row in GetAll (fulfilledAmount, outstandingBalance,
   fulfillmentPercent, nextDueDate, overdueCount/overdueAmount) — ISSUE-7 flags N+1 risk.
6. Lazy overdue-flip: write operation embedded in a read handler — NEW pattern.
7. State machine with 4 auto-computed states and 1 manual terminal transition (Cancel).
8. Summary query (4 KPI aggregations) + Overdue Alert query (top-5 rows) as separate BE endpoints.
9. Frontend: 3 URL modes in one view-page, Zustand store, unsaved-changes guard,
   auto-calc logic in FORM (useWatch + derived installment/endDate), Schedule Preview panel.
10. 720px drawer with 4 body sections including a horizontal scrollable timeline component
    (brand-new UI component with no existing equivalent in the codebase).
11. Cross-screen deep-link integration (ISSUE-1 — partially OPEN, requires GlobalDonation
    form to be updated).
12. 4 new shared cell renderers (`donor-link`, `currency-amount`, `fulfillment-progress`,
    `payment-status-chip`) — reusable but still net-new components.
13. 3 MasterData type groups to seed (PLEDGEFREQUENCY, PLEDGESTATUS, PLEDGEPAYMENTSTATUS).

Any one of items 2-3 would elevate a screen from Medium to High on its own. All 13 factors
in combination make this one of the more complex screens in the CRM module. High is correct.
Do not downgrade.

---

## Deviations

### Deviation 1: Drawer width 720px vs 460–520px in siblings

DonationInKind drawer: `sm:max-w-[520px]` (confirmed in file).
RecurringDonationSchedule drawer: `sm:max-w-[460px]` (confirmed in file).
Pledge drawer: 720px per Section ⑥.

Justification: VALID. The Pledge drawer contains significantly more content —
2-column 10-item summary grid, horizontal payment timeline (scrollable dots per installment),
full payment history table, and inline cancel form. 520px would truncate the timeline and
the 2-column summary grid. 720px matches the mockup's `.detail-panel` CSS. Accept deviation.

### Deviation 2: Drawer open/close state — URL-driven (not Zustand-driven)

DonationInKind (#7) uses Zustand `drawerOpen` flag exclusively (verified in dik-detail-drawer.tsx).
RecurringDonationSchedule (#8) is URL-driven (`useSearchParams` for mode + id).
Pledge follows #8 (URL-driven) — correct, because it also needs `?mode=new` and `?mode=edit`.

The Zustand `pledge-store.ts` still needed for non-URL state: `overdueAlertExpanded`,
`cancelConfirmOpen`, `filterChip`. The `selectedPledgeId` state can be derived from URL params
rather than stored in Zustand (preferred — avoids desync). SR recommendation: remove
`selectedPledgeId` from Zustand, derive it from `useSearchParams('id')` in the drawer component.

### Deviation 3: PledgePayments are BE-generated (not FE-submitted) in Create

RecurringDonation Create: FE sends Distributions array. Pledge Create: FE sends NO child rows —
BE generates the schedule. This is a deliberate domain difference, not a pattern drift.
The CreatePledge command's `PledgeRequestDto` must NOT include a `PledgePayments` array field
(unlike `RecurringDonationScheduleRequestDto.Distributions`). The prompt is correct on this.

### Deviation 4: Three new MasterData type groups required (not typical for this module)

RecurringDonation used one MasterData typeCode (RECURRINGFREQUENCY + RECURRINGSCHEDULESTATUS +
LASTCHARGESTATUS). Pledge uses three (PLEDGEFREQUENCY, PLEDGESTATUS, PLEDGEPAYMENTSTATUS).
This is data model complexity, not a pattern deviation. DB seed script will be longer than
typical — no architectural concern.

### Deviation 5: `campaignOrPurposeName` projected field

Column 3 in the grid shows `campaignName ?? donationPurposeName` in a single column. This
derived field (`campaignOrPurposeName`) does not exist as a DB column — it is a projected
string in the GetAll LINQ query. The developer must add it to PledgeResponseDto and compute
it inline: `entity.CampaignName ?? entity.DonationPurpose.DonationPurposeName`.

This is an unusual UI choice (collapsing two FKs into one display column). Architecturally
valid — just needs explicit awareness in the BE projection. No pattern conflict.

### Deviation 6: Overdue Banner actions use filter-chip Zustand setter (not drawer-action modal)

In #8, the FailedPaymentsAlertBanner calls `openActionModal(...)` from the recurring store to
trigger Pause/Cancel modals. Pledge's banner instead calls:
  - "Send Bulk Reminders" → SERVICE_PLACEHOLDER toast (no modal)
  - "View All Overdue" → `setFilterChip('overdue')` (Zustand → grid chip filter)
  - "Send Reminder" (per-row) → SERVICE_PLACEHOLDER toast

No action modals needed for pledge banner. Simpler than the sibling pattern. No concern.

### Deviation 7: Schedule Preview Panel (FORM mode)

Section ⑥ specifies a read-only dot timeline preview below the Payment Schedule section in
FORM mode. This component (`pledge-payment-timeline.tsx`) is shared between the FORM preview
and the drawer body (different data: in FORM it shows computed future schedule; in drawer it
shows actual PledgePayment rows). The same React component handles both cases via a prop flag
(e.g., `mode: 'preview' | 'actual'`).

RecurringDonation FORM has no equivalent timeline preview — this is a Pledge-specific UI
addition. It is a new component, not a reuse of any existing timeline component. Justified
by the mockup. No pattern conflict.

---

## Path Corrections

### Correction 1: File system casing — CRITICAL for BE Developer

The prompt throughout uses `Pss2.0_Frontend` and `Pss2.0_Backend` in the File Manifest
(Section ⑧) and other references. The actual directory names on disk are:

  CORRECT:   `PSS_2.0_Backend`  (uppercase PSS)
  CORRECT:   `PSS_2.0_Frontend` (uppercase PSS)
  INCORRECT: `Pss2.0_Backend`   (as used in prompt ⑧)
  INCORRECT: `Pss2.0_Frontend`  (as used in prompt ⑧)

On Windows the casing difference does not cause an error, but on Linux CI/CD (where the
deployment pipeline runs) the path would fail to resolve. All file paths in the developer
prompts and file-creation commands must use the uppercase form. The Section ① Context,
⑦ Substitution Guide, and ⑩ Contract sections correctly omit the root prefix — only
Section ⑧ has the wrong casing in several rows.

Correct absolute root paths:
  BE: `D:/Repos/PWDS/pwds-soruban/pss-2.0-global/PSS_2.0_Backend/PeopleServe/Services/Base/`
  FE: `D:/Repos/PWDS/pwds-soruban/pss-2.0-global/PSS_2.0_Frontend/src/`

### Correction 2: MasterData entity path — CRITICAL for BE Developer

The prompt Section ③ FK Resolution Table lists the MasterData entity path as:
  INCORRECT: `Base.Domain/Models/SharedModels/MasterData.cs`

The actual file path verified on disk:
  CORRECT: `Base.Domain/Models/SettingModels/MasterData.cs`

Evidence:
  D:/Repos/PWDS/pwds-soruban/pss-2.0-global/PSS_2.0_Backend/PeopleServe/Services/Base/
  Base.Domain/Models/SettingModels/MasterData.cs

This is confirmed from both the file system scan and by observing how the sibling
CreateRecurringDonationScheduleValidator references it:
  `ValidateForeignKeyRecord<MasterData, int>(x => x.FrequencyId, _dbContext.MasterDatas, ...)`
The `MasterData` class is resolvable from the global using declarations, so the correct
namespace is already in scope. The wrong path in the prompt is documentation-only error —
it does not affect compilability — but any developer creating a `using` statement or
referring to the model path should use `SettingModels`, not `SharedModels`.

For full correctness, the other three FK paths in Section ③ were verified and are correct:
  Contact   → `Base.Domain/Models/ContactModels/Contact.cs`        CONFIRMED on disk
  Campaign  → `Base.Domain/Models/ApplicationModels/Campaign.cs`   CONFIRMED on disk
  GlobalDonation → `Base.Domain/Models/DonationModels/GlobalDonation.cs` CONFIRMED on disk
  Currency  → SharedModels (not verified individually, but consistent with sibling patterns)
  PaymentMode → SharedModels (same)

### Correction 3: Drawer width in SheetContent className

Section ⑥ specifies 720px. The pattern from both siblings is:
  `className="w-full sm:max-w-[{N}px] max-w-[{N}px] p-0 flex flex-col"`

FE developer must write:
  `className="w-full sm:max-w-[720px] max-w-[720px] p-0 flex flex-col"`

Not 520px (DIK) and not 460px (recurring).

### Correction 4: Route stub path — minor casing only

Section ⑧ Frontend Files MODIFY row #1 states:
  INCORRECT: `Pss2.0_Frontend/src/app/[lang]/crm/donation/pledge/page.tsx`

The verified path on disk (confirmed by Section ⑫ note and codebase structure):
  CORRECT: `PSS_2.0_Frontend/src/app/[lang]/(core)/crm/donation/pledge/page.tsx`

Note the `(core)` route group segment — the parenthetical Next.js route group is present in
the actual folder structure (per sibling routes: recurringdonors is at
`app/[lang]/(core)/crm/donation/recurringdonors/page.tsx`). The prompt omits `(core)` in
Section ⑧ but includes it in Section ⑧ row #7 (`Route: app/[lang]/(core)/{group}/...`).
BE developer is unaffected; FE developer must use the `(core)` path.

---

## Summary Risk Register

| Risk | Severity | Note |
|------|----------|------|
| Lazy overdue-flip: write in read handler | MEDIUM | New pattern; no sibling. Use ExecuteUpdateAsync; wrap in explicit try/catch separate from main query. |
| UpdatePledge diff-regeneration atomicity | HIGH | No sibling example. Must use DB transaction. ISSUE-5 is correct to flag this. |
| GetAll N+1 on 6 per-row subqueries | MEDIUM | ISSUE-7. Developer must verify EF generates efficient SQL. Use `.Select()` with inner subquery in the LINQ expression — do NOT use `.Include()` then in-memory LINQ for these aggregations. |
| nextDuePledgePaymentId: redundant query endpoint | LOW | Recommend projecting inline into PledgeResponseDto (both GetAll and GetById) and removing the standalone GetNextDuePledgePayment query. |
| ISSUE-1 GlobalDonation deep-link | HIGH | Pledges screen is fully blocked from E2E Record Payment test until GlobalDonation form accepts `?pledgePaymentId=X`. This must be resolved before the screen is marked COMPLETED. |
| ISSUE-3 BEHIND state for Custom frequency | MEDIUM | Use PledgePayment schedule as source of truth (option a). Sum DueAmount where DueDate <= today → compare to fulfilledAmount. |
| MasterData path typo in prompt | LOW | Documentation error only; does not affect compilation. Noted here for developer awareness. |
| File path casing (Pss2.0_ vs PSS_2.0_) | LOW | Windows is case-insensitive; Linux CI would fail. All commands must use PSS_2.0_. |
