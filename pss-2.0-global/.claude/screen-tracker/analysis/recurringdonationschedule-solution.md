# Technical Architecture Document: RecurringDonationSchedule (Screen #8)

**Status**: CONFIRMED — ready for code generation
**Date**: 2026-04-21
**Complexity**: HIGH
**Scope tag**: ALIGN (large gap — treat as near-greenfield rebuild)

---

## 1. Classification Confirmation

| Attribute | Value |
|-----------|-------|
| Screen Type | FLOW with side-drawer DETAIL |
| Layout Variant | Variant B mandatory (`widgets-above-grid+side-panel`) |
| Sibling Reference | DonationInKind #7 (`dik-detail-drawer.tsx` 520px → adapt to 460px) |
| Module / Group | CRM / Donation (no new module) |
| Schema | `fund` |
| Backend Complexity | HIGH — 9 new command handlers, 3 new query handlers, 1 helper query, EF migration |
| Frontend Complexity | HIGH — near-greenfield rebuild of existing read-only data-table into Variant B FLOW view |
| GridFormSchema | SKIP (FLOW screen — form is driven by `view-page.tsx`) |

**CONFIRMED. No disagreements with pre-answered classification.**

---

## 2. Codebase Audit Findings

### 2.1 Backend — Current State

The entity `RecurringDonationSchedule.cs` is confirmed at:
`PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/RecurringDonationSchedule.cs`

Confirmed missing: `RecurringDonationScheduleCode` property — migration required.

Existing handlers confirmed:
- `ToggleRecurringDonationSchedule.cs` — exists, keep
- `GetRecurringDonationSchedule.cs` — exists, MODIFY (add chip + advanced filters + `RecurringDonationScheduleCode` search + `PaymentMethodToken` Include + projected fields)
- `GetRecurringDonationScheduleById.cs` — exists, MODIFY

Existing schemas confirmed (`RecurringDonationScheduleSchemas.cs`):
- `RequestDto` currently exposes `CompanyId` directly — **RISK**: FE must NOT send CompanyId; BE Create/Update handler must strip it and resolve from HttpContext. RequestDto should remove `CompanyId` or mark it ignored.
- `ResponseDto` extends `RequestDto` — the current nested-nav-object pattern (`PaymentGateway`, `Currency`, `Frequency`, `ScheduleStatus`) differs from the flat projected-field pattern specified in §⑩. **Decision**: ADD flat projected fields alongside nav objects for FE compatibility; do not remove nav objects (used by existing consumers).

Existing endpoints confirmed:
- `RecurringDonationScheduleMutations.cs` — has only `ActivateDeactivateRecurringDonationSchedule`; all new mutations to be appended.
- `RecurringDonationScheduleQueries.cs` — has only `GetRecurringDonationSchedules` + `GetRecurringDonationScheduleById`; new queries to be appended.

EF Config (`RecurringDonationScheduleConfiguration.cs`) confirmed:
- No `RecurringDonationScheduleCode` column or index. Both unique-filtered-indexes missing.
- No Include for `PaymentMethodToken` navigation in existing GetAll query — confirmed N+1 risk for `paymentMethodDisplay` projection (ISSUE-5).

### 2.2 Frontend — Current State

Existing files under `recurringdonors/`:
- `data-table.tsx` — read-only `AdvancedDataTable` wrapper with `gridCode="RECURRINGDONATIONSCHEDULE"` and a conditional that renders `RecurringDonorView` when `?mode=read&id`. DELETE this file.
- `view/recurring-donor-view.tsx` — full-page view (not a drawer). Verify no imports from sibling screens before deleting (ISSUE-4 — still OPEN; check before delete).
- `index.ts` — barrel; overwrite.
- `view/index.ts` — barrel; delete alongside view component.

Confirmed: `component-column.tsx` in flow/advanced/basic tables uses a `switch` pattern with kebab-case keys. All 7 new renderers must add cases to all three files and be exported from `shared-cell-renderers/index.ts`.

Confirmed: `status-badge` and `DateOnlyPreview` already registered — reuse, do not re-create.

Confirmed: `engagement-score-badge` exists in `shared-cell-renderers/` — reuse in drawer Donor mini card.

Confirmed: `contact-avatar-name` renderer exists — reuse for Donor column in grid.

---

## 3. Confirmed Backend Patterns

### 3.1 CQRS Commands (9 new + modifications)

| Handler | Pattern | Key Behavior |
|---------|---------|-------------|
| `CreateRecurringDonationScheduleCommand` | Standard Create + code-gen | Auto-generate `RecurringDonationScheduleCode` = `REC-{NNNN}` (max existing per Company + 1, zero-padded 4 digits) when field is empty or null. Follow GlobalDonation / DonationInKind code-gen pattern. Diff-persist child Distributions on create (insert all). CompanyId from HttpContext, NOT from request DTO. |
| `UpdateRecurringDonationScheduleCommand` | Standard Update + diff-persist | Diff-persist Distributions: match by DistributionId — insert new, update existing, delete removed. Validate `RecurringDonationScheduleCode` immutable after first set. |
| `DeleteRecurringDonationScheduleCommand` | Soft delete | Set `IsDeleted=true`; guard: cannot delete if ScheduleStatus = Active. |
| `PauseRecurringDonationScheduleCommand` | Status transition | Guard: status must be Active. Set status→Paused, clear `NextBillingDate`, set `PausedReason` (required). |
| `ResumeRecurringDonationScheduleCommand` | Status transition | Guard: status must be Paused. Set status→Active, recompute `NextBillingDate` from `StartDate + Frequency` using helper method `ComputeNextBillingDate(startDate, frequencyDataValue, lastChargedDate)`. Clear `PausedReason`. |
| `CancelRecurringDonationScheduleCommand` | Status transition (terminal) | Guard: status must not be Cancelled. Set status→Cancelled, set `CancelledAt=UtcNow`, set `CancelledReason` (required), clear `NextBillingDate`. Immutable after cancel. |
| `RetryRecurringDonationScheduleCommand` | SERVICE_PLACEHOLDER | Guard: status must be Failed. Simulate success: set `ConsecutiveFailures=0`, status→Active, recompute `NextBillingDate`. Real gateway call deferred. Return success with advisory message "Retry sent — gateway integration pending." |
| `UpdateRecurringDonationSchedulePaymentCommand` | SERVICE_PLACEHOLDER | Persist new `PaymentMethodTokenId` locally. Real gateway subscription-update deferred. Return advisory message. |
| `EditRecurringDonationScheduleAmountCommand` | Partial update | Update `Amount` only. Recompute child Distribution amounts proportionally if single-row distribution (if multi-row, validate sum matches new amount — reject otherwise with clear error). Recompute `NextBillingDate` if status = Active. |

### 3.2 Queries (3 new)

| Handler | Returns | Key Logic |
|---------|---------|----------|
| `GetRecurringDonationScheduleSummaryQuery` | `RecurringDonationScheduleSummaryDto` | Tenant-scoped (CompanyId from HttpContext via `IHttpContextAccessor`). Counts active schedules; computes MRR by converting non-monthly frequencies to monthly equivalent; counts failed in current calendar month; computes avg duration for active schedules. Single round-trip — group-by aggregation in EF. |
| `GetRecurringDonationScheduleFailedAlertQuery` | `RecurringDonationScheduleFailedAlertDto[]` (top 5) | Where ScheduleStatus=Failed AND current month. OrderBy ConsecutiveFailures DESC, LastChargedDate DESC. Take 5. Project flat DTO. |
| `GetPaymentMethodTokensByContactQuery` | `PaymentMethodTokenResponseDto[]` (helper) | Filter by ContactId (passed as arg). Returns active tokens only. This is the first BE consumer of this helper query — place in `DonationBusiness/PaymentMethodTokens/Queries/`. |

### 3.3 Modifications to Existing Queries

`GetRecurringDonationSchedulesQuery` handler receives these new args via extended `GridFeatureRequest` or a derived request record:
- `chip` (string: all/active/paused/cancelled/failed/expiringSoon)
- `frequencyId` (int?)
- `paymentGatewayId` (int?)
- `amountMin` (decimal?)
- `amountMax` (decimal?)
- `currencyId` (int?)
- `createdFrom` / `createdTo` (DateTime?)
- `nextBillingFrom` / `nextBillingTo` (DateTime?)

Search must also match `RecurringDonationScheduleCode` (add to existing `Where` clause alongside DisplayName + DonorEmail).

`expiringSoon` chip: `EndDate != null AND EndDate <= UtcNow.AddDays(30)`.

`GetRecurringDonationScheduleByIdQuery`: add `.Include(r => r.PaymentMethodToken)` and project flat fields for drawer display.

### 3.4 FluentValidation Strategy

| Field | Validators |
|-------|-----------|
| `RecurringDonationScheduleCode` | MaxLength(50); `ValidateUniqueWhenCreate` per Company; immutable-after-create guard in UpdateValidator |
| `GatewaySubscriptionId` | Required, MaxLength(200); `ValidateUniqueWhenCreate` per Company; `ValidateUniqueWhenUpdate` per Company |
| `GatewayCustomerId` | Required, MaxLength(200) |
| `GatewayPlanId` | MaxLength(100) |
| `Amount` | Required; GreaterThan(0); decimal precision |
| `FrequencyId` | Required; `ValidateForeignKeyRecord<MasterData>` (typeCode=RECURRINGFREQUENCY) |
| `CurrencyId` | Required; `ValidateForeignKeyRecord<Currency>` |
| `PaymentGatewayId` | Required; `ValidateForeignKeyRecord<PaymentGateway>` |
| `PaymentMethodTokenId` | Required; `ValidateForeignKeyRecord<PaymentMethodToken>` |
| `ScheduleStatusId` | Required; `ValidateForeignKeyRecord<MasterData>` (typeCode=RECURRINGSCHEDULESTATUS) |
| `LastChargeStatusId` | Optional; when set: `ValidateForeignKeyRecord<MasterData>` (typeCode=CHARGESTATUS) |
| `StartDate` | Required |
| `EndDate` | When set: Must be > StartDate |
| `PausedReason` | Required when Pause command; MaxLength(500) |
| `CancelledReason` | Required when Cancel command; MaxLength(500) |
| `Distributions` | NotEmpty (at least 1 row); each row: ContactId required (`ValidateForeignKeyRecord<Contact>`); DonationPurposeId required (`ValidateForeignKeyRecord<DonationPurpose>`); ParticipantTypeId required (`ValidateForeignKeyRecord<MasterData>` typeCode=PARTICIPANTTYPE); Amount > 0 |
| Distribution sum | Custom Must() validator: `Distributions.Sum(d => d.Amount) == Amount` — implement as named constant `DistributionSumRule` shared between CreateValidator and UpdateValidator (ISSUE-11) |
| Status transition (Pause/Resume/Cancel) | Guard validators in respective command validators; use `Must()` with DB lookup for current status |

### 3.5 Mapster Projections (add to DonationMappings.cs)

Five new `TypeAdapterConfig` pairs:
1. `RecurringDonationSchedule` → `RecurringDonationScheduleResponseDto` (flat projected fields: `frequencyName`, `frequencySuffix`, `paymentGatewayName`, `paymentGatewayCode`, `currencyCode`, `scheduleStatusName`, `lastChargeStatusName`, `paymentMethodDisplay`, `donorContactName`, `donorContactCode`, `donorAvatarColor`)
2. `RecurringDonationScheduleDistribution` → `RecurringDonationScheduleDistributionResponseDto`
3. `RecurringDonationScheduleSummaryDto` (projection from aggregate query result — anonymous type → DTO)
4. `RecurringDonationScheduleFailedAlertDto` (projection from query result)
5. `PaymentMethodToken` → `PaymentMethodTokenResponseDto` (if not already present)

**`paymentMethodDisplay` projection logic** (implement as private static method in mapping config):
- If `PaymentMethodToken.PaymentMethodTypeCode == "CARD"` → `"{CardBrand} ••••{Last4Digits}"`
- If `PaymentMethodToken.PaymentMethodTypeCode == "UPI"` → `"UPI"`
- If `PaymentMethodToken.PaymentMethodTypeCode == "PAYPAL"` → `"PayPal Balance"`
- Else → `"Bank Debit"`

**`frequencySuffix` projection logic**:
- `dataValue == "MONTHLY"` → `/mo`; `QUARTERLY` → `/qtr`; `ANNUAL" or "ANNUALLY"` → `/yr`; `SEMI_ANNUAL` → `/6mo`

**`donorAvatarColor` projection**: deterministic color from `Contact.ContactId % 8` mapped to a palette array (match existing ContactAvatarName renderer's color generation for consistency).

### 3.6 Migration Plan

Migration name: `AddRecurringDonationScheduleCode`

Steps (all in one migration file, ordered):
1. `AddColumn("fund", "RecurringDonationSchedules", "RecurringDonationScheduleCode", nullable: true, maxLength: 50)`
2. `Sql("UPDATE fund.\"RecurringDonationSchedules\" SET \"RecurringDonationScheduleCode\" = 'REC-' || LPAD((ROW_NUMBER() OVER (PARTITION BY \"CompanyId\" ORDER BY \"RecurringDonationScheduleId\"))::text, 4, '0') FROM ...")`  — PostgreSQL window function backfill
3. `AlterColumn("fund", "RecurringDonationSchedules", "RecurringDonationScheduleCode", nullable: false)`
4. `CreateIndex("IX_RecurringDonationSchedules_Code_Company", "fund", "RecurringDonationSchedules", ["RecurringDonationScheduleCode", "CompanyId"], unique: true, filter: "\"IsDeleted\" = false")`
5. `CreateIndex("IX_RecurringDonationSchedules_GatewaySubId_Company", "fund", "RecurringDonationSchedules", ["GatewaySubscriptionId", "CompanyId"], unique: true, filter: "\"IsDeleted\" = false")`

### 3.7 Wiring Updates

| File | Action |
|------|--------|
| `IDonationDbContext.cs` | Verify `DbSet<RecurringDonationSchedule>` and `DbSet<RecurringDonationScheduleDistribution>` exist; also verify `DbSet<PaymentMethodToken>` for helper query |
| `DonationDbContext.cs` | Same verification |
| `DecoratorProperties.cs` | Verify `DecoratorDonationModules.RecurringDonationSchedule` registered |
| `DonationMappings.cs` | Add 5 TypeAdapterConfig pairs (above) |

---

## 4. Confirmed Frontend Patterns

### 4.1 Variant B Layout Structure

```
/recurringdonors (view-page.tsx controls mode)
├── mode=null/default → index-page.tsx
│   ├── ScreenHeader (title, subtitle, actions: Back, Export, +New Schedule)
│   ├── recurring-widgets.tsx (4 KPI cards — query: recurringDonationScheduleSummary)
│   ├── failed-payments-alert-banner.tsx (conditional — query: recurringDonationScheduleFailedAlert)
│   ├── recurring-filter-chips.tsx (6 chips — Zustand filterChip + URL sync)
│   ├── recurring-advanced-filters.tsx (collapsible, 9 fields — URL sync)
│   └── DataTableContainer showHeader={false}
│       └── FlowDataTable gridCode="RECURRINGDONOR"
│
├── mode=new → view-page.tsx FORM layout (full page)
│   ├── FlowFormPageHeader (Back, Save + unsaved-changes dialog)
│   └── 4 card sections (Schedule Info, Payment Setup, Distribution, Status[edit-only])
│       └── Distribution section: distribution-field-array.tsx (RHF useFieldArray)
│
├── mode=edit&id=X → view-page.tsx FORM layout (pre-filled)
│   └── (same structure as mode=new + Status section visible)
│
└── mode=read&id=X → index-page.tsx stays mounted + drawer
    └── recurring-schedule-detail-drawer.tsx (460px Sheet, slides from right)
        ├── 6 body sections (Donor, Schedule Info, Payment Method, Distribution, Charge History, Audit)
        └── sticky footer actions (status-conditional buttons)
```

### 4.2 Zustand Store Shape (`recurringdonationschedule-store.ts`)

```typescript
interface RecurringDonationScheduleStore {
  // Drawer state — URL is source of truth for selectedId; store holds animation state only
  isDrawerAnimatingOpen: boolean;
  setDrawerAnimating: (v: boolean) => void;

  // Failed alert banner
  failedAlertExpanded: boolean;
  setFailedAlertExpanded: (v: boolean) => void;

  // Filter chip (also synced to URL ?chip=)
  activeChip: 'all' | 'active' | 'paused' | 'cancelled' | 'failed' | 'expiringSoon';
  setActiveChip: (chip: string) => void;

  // Action modal states
  pauseModalOpen: boolean;
  cancelModalOpen: boolean;
  editAmountModalOpen: boolean;
  setPauseModalOpen: (v: boolean) => void;
  setCancelModalOpen: (v: boolean) => void;
  setEditAmountModalOpen: (v: boolean) => void;
}
```

Note (ISSUE-13 confirmed): `selectedScheduleId` is NOT stored in Zustand — read via `useSearchParams().get('id')`. This avoids hydration mismatch on SSR.

### 4.3 React Hook Form + Zod Schema

Top-level schema fields: all non-computed fields from the entity. Child schema for Distribution rows. Key Zod refinements:
- `.refine(data => data.distributions.reduce((s, r) => s + r.amount, 0) === data.amount, { message: "Distribution amounts must sum to the schedule amount", path: ["distributions"] })` — align message text with BE validator constant (ISSUE-11).
- `.refine(data => !data.endDate || data.endDate > data.startDate, { message: "End date must be after start date", path: ["endDate"] })`

`useFieldArray` for `distributions` array — provides `fields`, `append`, `remove`. Running sum displayed as `distributions.reduce((s, f) => s + (Number(f.amount) || 0), 0)`.

### 4.4 ApiSelectV2 Cascade

`PaymentMethodTokenId` dropdown disabled until at least one Distribution row has a ContactId selected. Driver logic:
```typescript
const firstContactId = useWatch({ name: 'distributions.0.contactId' });
// PaymentMethodTokenId ApiSelectV2: disabled={!firstContactId}
// queryVariables: { contactId: firstContactId }
// placeholder: firstContactId ? "Select payment method" : "Select a donor first"
```

### 4.5 Detail Drawer (`recurring-schedule-detail-drawer.tsx`)

Clone from `dik-detail-drawer.tsx`. Key adaptations:
- Width: 460px (vs 520px in DIK) — set on `SheetContent` className
- Use `RECURRING_DONATION_SCHEDULE_BY_ID_QUERY` (not DIK query)
- Use `recurringdonationschedule-store` (not donationinkind-store)
- Replace "Complete Valuation" sub-form with Pause/Resume/Cancel/Retry/UpdatePayment/EditAmount footer actions
- Section 5 (Charge History): use existing `RECURRING_DONOR_TRANSACTIONS_QUERY` — verify field `donorAmount` vs `amount` alias before rendering (ISSUE-7)
- Section 6 (Audit Trail): CreatedBy/Date + ModifiedBy/Date rows; status-change timeline is placeholder
- Drawer closes → `router.push(pathname)` (clears search params)

### 4.6 New Cell Renderers (7)

All 7 files go to:
`PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/`

| Key (switch case) | File | Props | Notes |
|------------------|------|-------|-------|
| `recurring-amount` | `recurring-amount-cell.tsx` | `row.original` (amount + currencyCode + frequencySuffix) | Monospace font; format: "$50.00 /mo" |
| `freq-badge` | `freq-badge-cell.tsx` | `value` (frequencyName string) | Pills: Monthly=blue, Quarterly=purple, Annual=green, Semi-Annual=orange |
| `gateway-cell` | `gateway-cell.tsx` | `row.original` (paymentGatewayName + paymentGatewayCode) | Icon letter in colored circle + name; code-to-color map: STRIPE=violet, PAYPAL=navy, RAZORPAY=navy |
| `payment-method-cell` | `payment-method-cell.tsx` | `value` (paymentMethodDisplay string) | fa-cc-visa / fa-cc-mastercard / fa-cc-amex for cards; generic for UPI/Bank/PayPal |
| `last-charged-cell` | `last-charged-cell.tsx` | `row.original` (lastChargedDate + lastChargeStatusName) | Date + green check or red X icon |
| `total-charged-cell` | `total-charged-cell.tsx` | `row.original` (totalChargedAmount + totalChargedCount + currencyCode) | Amount monospace + "(12)" subtitle |
| `failure-count` | `failure-count-cell.tsx` | `value` (number) | Bold; red text when ≥ 1; "—" when 0 |

Each renderer must be:
1. Exported from `shared-cell-renderers/index.ts`
2. Imported and added as a `case` in `flow/component-column.tsx`
3. Imported and added as a `case` in `advanced/component-column.tsx`
4. Imported and added as a `case` in `basic/component-column.tsx`

Note: `report/component-column.tsx` also exists — add cases there too for completeness.

### 4.7 Files to DELETE (confirm before delete — ISSUE-4)

Before deleting `recurring-donor-view.tsx`, grep the entire FE codebase for imports of `RecurringDonorView` and `recurring-donor-view`. If no other consumers, delete both `view/recurring-donor-view.tsx` and `view/index.ts`.

`data-table.tsx` can be deleted unconditionally — its only import is `RecurringDonorView` from the local `./view` barrel, which is also being deleted.

### 4.8 Wiring Updates (FE)

| File | Action |
|------|--------|
| `donation-service-entity-operations.ts` | Replace the `RECURRINGDONATIONSCHEDULE` block placeholder: wire all 9 mutations (create, update, delete, pause, resume, cancel, retry, updatePayment, editAmount) to their actual mutation constants (ISSUE-14) |
| `operations-config.ts` | Verify import exists; add if missing |
| `component-column.tsx` (advanced/basic/flow/report) | Add 7 new renderer cases |
| `shared-cell-renderers/index.ts` | Export 7 new renderers |
| DTO barrel | Export `RecurringDonationScheduleDto.ts` |
| Mutation barrel | Export `RecurringDonationScheduleMutation.ts` |
| Query barrel | Export `RecurringDonationScheduleQuery.ts` |

---

## 5. Component Reuse Map

| Component | Source | Usage in This Screen |
|-----------|--------|---------------------|
| `ScreenHeader` | Shared | Grid layout top bar |
| `DataTableContainer` (showHeader=false) | Shared | Wraps FlowDataTable in Variant B |
| `FlowDataTable` | Shared | Main grid |
| `FlowFormPageHeader` | Shared | FORM mode header (Back + Save) |
| `StatusBadge` | `shared-cell-renderers/status-badge.tsx` | Col 7: Schedule Status |
| `DateOnlyPreviewComponent` | flow/component-column-types | Col 8: Next Billing Date |
| `ContactAvatarName` | `shared-cell-renderers/contact-avatar-name.tsx` | Col 2: Donor column |
| `EngagementScoreBadge` | `shared-cell-renderers/engagement-score-badge.tsx` | Drawer Donor mini card |
| `RECURRING_DONOR_TRANSACTIONS_QUERY` | `donation-queries/RecurringDonorViewQuery.ts` | Drawer Charge History (Section 5) |
| `dik-detail-drawer.tsx` | DonationInKind #7 — CLONE AND ADAPT | Base for `recurring-schedule-detail-drawer.tsx` |

---

## 6. Build Sequence

**Recommended: Parallel (BE + FE simultaneously) against the §⑩ contract.**

The §⑩ contract in the prompt is complete and authoritative. FE developers can build against the defined GQL types and field shapes without waiting for BE to be deployed. When both are done, integration testing verifies contract alignment.

Suggested parallel tracks:
- **Track A (BE)**: Migration → Entity + Config → Schemas → Commands (Create, Update, Delete) → Commands (Pause, Resume, Cancel, Retry, UpdatePayment, EditAmount) → Queries (GetAll modify, GetById modify, GetSummary, GetFailedAlert, GetPaymentMethodTokensByContact) → Endpoints → Mappings → Wiring
- **Track B (FE)**: DTOs → GQL Mutations/Queries → Zustand store → Cell renderers (7) → index-page + widgets + alert banner + filter chips + advanced filters → view-page (FORM) → detail drawer → action modals → wiring updates

**Integration checkpoint**: after both tracks complete individually, run `dotnet build` + `pnpm dev` together.

---

## 7. DB Seed Plan

| Item | Value |
|------|-------|
| MenuCode | `RECURRINGDONOR` (existing — do not change) |
| MenuUrl | `crm/donation/recurringdonors` (existing) |
| ParentMenu | `CRM_DONATION` |
| OrderBy | 2 |
| GridCode | `RECURRINGDONOR` |
| GridType | FLOW |
| GridFormSchema | NULL (SKIP) |
| Field count | 12 grid fields |
| Capabilities (Admin) | READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER |

MasterData gaps to seed (CRITICAL — acceptance criteria block on these):
- `RECURRINGSCHEDULESTATUS`: ADD row `dataName="Failed"`, `dataValue="FAIL"` (ISSUE-2)
- `RECURRINGFREQUENCY`: ADD row `dataName="Semi-Annual"`, `dataValue="SEMI_ANNUAL"` (ISSUE-3)

---

## 8. Risk Register

Issues carried forward from planning (14 OPEN) — no new risks identified by architecture review except the following clarifications:

| ID | Severity | Finding |
|----|----------|---------|
| ISSUE-1 | HIGH | Migration backfill confirmed safe for staging. For production, test on data copy before merge. The backfill SQL uses `ROW_NUMBER() OVER (PARTITION BY CompanyId ORDER BY RecurringDonationScheduleId)` which is deterministic and idempotent if re-run on empty-Code rows only. |
| ISSUE-5 | MED | `paymentMethodDisplay` projection — confirmed: existing GetAll does NOT include `PaymentMethodToken` nav. Must add `.Include(r => r.PaymentMethodToken)` to GetAll handler. Monitor query plan; if pagination cost rises, add a `PaymentMethodDisplay` computed column snapshot as fallback. |
| ISSUE-6 | LOW | `donorContactName` N+1 risk — confirmed: existing GetAll already includes Distributions→Contact. Use `.Select()` projection in Mapster (not lazy nav) to avoid N+1. |
| ISSUE-9 | LOW | `GetPaymentMethodTokensByContact` is the first BE consumer. Design the GQL arg as `paymentMethodTokensByContact(contactId: Int!)` — Pledge #12 and OnlineDonation #10 will reuse this exact signature. |
| NEW-15 | MED | **RequestDto exposes `CompanyId`** (current schema) — FE must not send it; BE handlers must always override from HttpContext. Recommend removing `CompanyId` from `RecurringDonationScheduleRequestDto` and adding `[GraphQLIgnore]` or stripping it in handler before persistence. Otherwise a malicious caller could scope to a different company. |
| NEW-16 | LOW | **`report/component-column.tsx` exists** alongside advanced/basic/flow — the prompt's §⑧ wiring table lists only 3 registries. The report component-column must also receive the 7 new renderer cases, or report-mode grid views will render blank cells for these columns. Add to build instructions. |

---

## 9. Per-Agent Model Assignments

| Agent | Model | Reason |
|-------|-------|--------|
| BA Analyst | sonnet | Pre-answered in prompt; validation only |
| Solution Resolver | sonnet | This document (classification + architecture) |
| UX Architect | opus | Complex Variant B layout + 3 mode switching + drawer spec |
| Backend Developer | opus | HIGH complexity: 9 commands, 3 queries, migration, 9 FK validators, distribution-sum rule, status machine guards, Mapster projections |
| Frontend Developer | opus | Near-greenfield rebuild: Zustand store, 7 renderers, Variant B layout, useFieldArray, cascade dropdown, drawer clone |
| DB Seed | sonnet | Standard seed script from pre-filled config |

---

## 10. Pre-Generation Checklist

Before any agent begins code generation, confirm:

- [ ] User has approved the §⑨ config block (already pre-filled; no changes needed)
- [ ] DECISION confirmed: `CompanyId` stripped from `RecurringDonationScheduleRequestDto` (NEW-15) — or document accepted risk
- [ ] DECISION confirmed: `report/component-column.tsx` is in scope for renderer registration (NEW-16)
- [ ] ISSUE-4 resolved: check for imports of `RecurringDonorView` / `recurring-donor-view` in sibling files before FE developer deletes the view component
- [ ] ISSUE-7 resolved: confirm `RECURRING_DONOR_TRANSACTIONS_QUERY` field name (`donorAmount` vs `amount`) so drawer Charge History renders correctly on first run
- [ ] Migration tested against staging data copy (ops sign-off)
