# BA Validation Notes — Pledge (Registry #12)

**Produced by**: BA Agent (validation pass)
**Date**: 2026-04-21
**Source prompt**: `.claude/screen-tracker/prompts/pledge.md`
**Status**: VALIDATED WITH OPEN ITEMS

---

## Validation Status

### Entity Design (Section ②)

**CONFIRMED — Two-Entity Design is correct.**

Pledge (parent, fund.Pledges) + PledgePayment (child, fund.PledgePayments, 1:Many via PledgeId) matches the business model accurately. The design correctly separates:
- Pledge: the promise record and its terms
- PledgePayment: the auto-generated installment schedule rows

**EF Constraints — CONFIRMED with one note:**
- Unique-filtered index on `(CompanyId, PledgeCode) WHERE IsActive=1` — correct; ensures per-tenant code uniqueness while allowing IsActive=0 rows to co-exist without constraint violation.
- Unique index on `(PledgeId, InstallmentNumber)` — correct; prevents duplicate installment rows during regen.
- `CompanyId` denormalized on PledgePayment — correct; confirmed for index-scan performance, especially on the overdue query `(CompanyId, DueDate, PaymentStatusId)`.
- NOTE FOR BACKEND DEV: The unique-filtered index for PledgeCode only works on SQL Server with filtered indexes. If the DB is PostgreSQL (likely given `CREATE TABLE "schema"."Table"` syntax in other prompts), the correct syntax is a partial unique index: `CREATE UNIQUE INDEX ... WHERE "IsActive" = true`. Confirm DB engine and adapt accordingly.

**Field-level validation — CONFIRMED:**
- All audit fields (CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive, IsDeleted, PKReferenceId) correctly omitted from the field table — inherited from Entity base.
- `CompanyId` on PledgePayment: correctly noted as denormalized from parent (not a separate user input).
- `CancelledReason` MaxLen=500 and `Notes` MaxLen=1000 are reasonable. No issues.
- `TotalPledgedAmount` and `InstallmentAmount` are `decimal(18,2)` — correct precision for currency.
- `EndDate` nullable on Pledge is correct — can be derived.

**Missing field — FLAG:**
- The `PledgePayment` child table has no `CancelledAt` or `IsCancelled` column, yet Section ④ states "On Cancel: mark all unpaid rows as cancelled (soft — leave rows but skip in overdue/summary queries)." This cancellation state must be tracked somewhere on the child row. Two options exist:
  - Add a boolean `IsCancelled` column to PledgePayment (cleaner), OR
  - Rely on parent Pledge.CancelledAt IS NOT NULL as the sentinel, filtering child rows by joining to parent (no child column change needed, but heavier queries).
  - RECOMMENDATION: Add `IsCancelled bool NOT NULL DEFAULT false` to PledgePayment. This avoids joins in the overdue and summary queries and enables clean WHERE clauses. BACKEND DEV must decide and apply consistently. If the join approach is chosen, `GetPledgeOverdueAlert` and `GetPledgeSummary` queries must always join back to Pledge to check CancelledAt.

### FK Resolution (Section ③)

**CONFIRMED — all 9 FK targets are resolvable:**
- Contact, Campaign, DonationPurpose, Currency, PaymentMode — all in expected entity file paths.
- MasterData (3 typeCode groups: PLEDGEFREQUENCY, PLEDGESTATUS, PLEDGEPAYMENTSTATUS) — path confirmed as `Base.Domain/Models/SettingModels/MasterData.cs` (see Path Correction Flag below — the prompt incorrectly states `SharedModels`).
- GlobalDonation (child FK, optional) — in `Base.Domain/Models/DonationModels/GlobalDonation.cs`.

**PATH CORRECTION FLAG (see Section below for full list):**
- Section ③ table lists MasterData path as `Base.Domain/Models/SharedModels/MasterData.cs`.
- Currency.cs and PaymentMode.cs are also listed under `SharedModels/`.
- Actual paths are `Base.Domain/Models/SettingModels/MasterData.cs`, `Base.Domain/Models/SettingModels/Currency.cs`, `Base.Domain/Models/SettingModels/PaymentMode.cs`. Backend Dev must use SettingModels, not SharedModels.

**CONFIRMED — MasterData seeds match the three typeCode groups defined:**
- PLEDGEFREQUENCY: 5 rows, dataValue as integer days (30/90/180/365/0) — correct. CUSTOM=0 is the sentinel for "no auto-calc" — flagged in ISSUE-6.
- PLEDGESTATUS: 5 rows, dataValue as string codes (ONTRACK/FULFILLED/OVERDUE/BEHIND/CANCELLED) + ColorHex — correct.
- PLEDGEPAYMENTSTATUS: 4 rows, dataValue as string codes (PAID/UPCOMING/SCHEDULED/OVERDUE) + ColorHex — correct.

**Note on PLEDGESTATUS isDefault:** The seed marks `ONTRACK` as `isDefault: true`. This is used when creating a new Pledge before the first computed-status evaluation. That is acceptable — new pledges start as OnTrack.

**Note on PLEDGEPAYMENTSTATUS isDefault:** `SCHEDULED` is marked `isDefault: true`. This aligns with the business logic: newly generated PledgePayment rows whose DueDate is in the future default to SCHEDULED. The regen logic in Section ④ overrides this with UPCOMING (DueDate = today) or OVERDUE (DueDate < today) — correct.

### Business Rules (Section ④)

**CONFIRMED — the following rules are correctly captured:**
- Auto-gen PledgeCode (`PLG-{NNNN}` padded 4-digit, per-Company sequence, only when empty on Create).
- Payment schedule generation on Create (N rows, DueDate = StartDate + freqDays × (i-1), status logic by date comparison).
- Regen-preserve-paid-rows on Update (delete UPCOMING/SCHEDULED/OVERDUE, keep PAID, regenerate from remaining balance).
- Status auto-compute on every read (5-state priority chain: Cancelled > Fulfilled > Overdue > Behind > OnTrack).
- Overdue lazy-flip on GetAll (UPDATE PledgePayments WHERE DueDate < today AND status=UPCOMING → flip to OVERDUE).
- Installment-sum rule (±$0.01 rounding tolerance; final row absorbs remainder).
- Cancel-with-reason (CancelledAt + CancelledReason mandatory; further edits blocked post-cancel).

**MISSING RULE — FLAG:**
- The prompt does not explicitly state what happens when `cancelPledge` is called on an already-Fulfilled pledge. Section ⑥ shows the Cancel action hidden when status=Fulfilled, which is correct UI-side. But the BE mutation must also guard against this: `cancelPledge` on a Fulfilled pledge should return a validation error (not silently succeed). Add this guard to the `CancelPledge` command handler.

**AMBIGUOUS RULE — FLAG (ISSUE-3, already pre-flagged):**
- BEHIND status computation for Custom frequency is ambiguous. The recommended approach (use PledgePayment.DueDate schedule rows as source of truth: `expectedByToday = SUM(DueAmount) WHERE DueDate <= today`) is correct and should be the implementation. Backend Dev must apply this for Custom; for standard frequencies the existing formula `InstallmentAmount × floor((today − StartDate) / freqDays)` remains valid.

**MISSING VALIDATION — FLAG:**
- No rule covers the case where `NumberOfInstallments` input causes `InstallmentAmount × N` to materially exceed `TotalPledgedAmount` (by more than the ±$0.01 rounding tolerance). The final row would absorb a large residual, producing a misleading last installment. Add a BE validation: `|TotalPledgedAmount − (InstallmentAmount × NumberOfInstallments)| <= 1.00` (allow $1.00 tolerance for user-overridden scenarios). If exceeded, return a validation error prompting user to adjust.

**CONFIRMED — Cancel guard on edit:**
- Rule "If PledgeStatus = Cancelled → further edits blocked" is stated. Backend Dev must enforce this in the `UpdatePledge` command (not just the Cancel command) by checking CancelledAt IS NOT NULL.

---

## Edge Cases

**EC-1 — Currency mismatch between Pledge currency and GlobalDonation currency on Record Payment:**
When staff records a payment via the GlobalDonation form deep-link, the resulting GlobalDonation may use a different currency than the Pledge (e.g., Pledge is in USD, but donor pays via INR cheque). The current model does not handle FX conversion: `PledgePayment.PaidAmount` is set from `GlobalDonation.DonationAmount` without currency-aware conversion. This means `fulfilledAmount` (sum of PaidAmounts) could be in mixed currencies, producing nonsense. RECOMMENDATION: When linking a GlobalDonation to a PledgePayment, validate that `GlobalDonation.CurrencyId == Pledge.CurrencyId`. If they differ, either (a) block the link with an error, or (b) apply a conversion rate (out of scope for now — SERVICE_PLACEHOLDER). Short-term: add a BE validation in `createGlobalDonation` (or `linkDonationToPledgePayment`) that checks currency match and returns a warning (not hard error, to allow override).

**EC-2 — Time-zone handling of StartDate / DueDate:**
The model stores `StartDate` and `DueDate` as `DateTime` (not `DateTimeOffset`). The overdue lazy-flip on GetAll compares `DueDate < today (UTC)`. If the NGO is operating in a UTC+X timezone, a payment due on "today" (local midnight) may be incorrectly flipped to OVERDUE before local end-of-day. RECOMMENDATION: Store `DueDate` as `DateOnly` (C# DateOnly or Date-only column) since installment due dates have no meaningful time component, OR always compare using the Company's configured timezone. Alternatively, flip only when `DueDate < today.Date` in UTC is outside a 24-hour window. Flag for Backend Dev to clarify with the team.

**EC-3 — DST boundary shifts in "+30 days" frequency math:**
The frequency math uses `DueDate = StartDate + frequencyDays × (i-1)` with integer day offsets (30, 90, 180, 365). Across DST transitions, adding 30 days in UTC can land on a different wall-clock day in the local timezone. For most NGO use cases this is minor (1-day drift), but if exact day-of-month matters (e.g., pledge due on the 1st of every month), pure day-math will drift. RECOMMENDATION: For MONTHLY frequency, consider using `StartDate.AddMonths(i-1)` instead of `StartDate.AddDays(30 × (i-1))` to guarantee calendar-month alignment. Flag for Backend Dev — this is especially important if donors receive statements on a calendar-month basis.

**EC-4 — Custom frequency with non-uniform installment dates:**
Section ④ covers Custom frequency as "no auto-calc — user sets NumberOfInstallments + InstallmentAmount." But it does not address non-uniform due dates (e.g., donor pays Feb 1, Apr 15, Sep 30 — none 30/90 days apart). The current model generates DueDates uniformly as `StartDate + freqDays × (i-1)`. For Custom (freqDays=0), there is no DueDate generation formula. The prompt does not specify how DueDates are set for Custom — only that auto-calc is skipped. RECOMMENDATION: For Custom frequency, either (a) require the user to manually enter DueDates per row (more complex FE), or (b) default DueDates to even spacing using NumberOfInstallments and EndDate (if provided). Option (b) is simpler and should be the implementation. NEEDS CLARIFICATION from product owner on whether true arbitrary dates are needed for Custom pledges.

**EC-5 — Soft-delete vs hard-delete precedence when paid rows exist:**
Section ⑥ states: "Delete — hard-delete only when no PaymentStatusCode='PAID' rows exist; else soft-toggle via IsActive." This is correct. However, there is a gap: if a Pledge is soft-deleted (IsActive=0), it disappears from the grid (standard IsActive filter). But the PledgePayment rows remain and may still be linked to GlobalDonation records via `GlobalDonationId`. Soft-deleting the Pledge without soft-deleting child PledgePayment rows means the GlobalDonation-to-PledgePayment link is orphaned. RECOMMENDATION: When soft-deleting (toggling IsActive=0) a Pledge, also set PledgePayment.IsActive=0 (if the column exists) or IsCancelled=true on unpaid rows. Paid rows should remain active for audit trail. The `TogglePledge` command handler must cascade this.

**EC-6 — Race condition: overdue-flip running concurrently with a new payment being recorded:**
The lazy overdue-flip in `GetAll` executes a bulk UPDATE `WHERE DueDate < today AND status=UPCOMING → OVERDUE`. If, simultaneously, a staff member is recording a payment against a PledgePayment row (transitioning it to PAID), the two operations may conflict:
- GetAll reads PledgePayment rows, identifies overdue candidates, starts UPDATE.
- createGlobalDonation also updates the same PledgePayment row (PaidDate, PaidAmount, PaymentStatusId=PAID).
- Depending on isolation level, the overdue-flip UPDATE could overwrite the PAID status with OVERDUE, or the PAID update could be lost.
RECOMMENDATION: Use `UPDATE PledgePayments SET PaymentStatusId=OVERDUE WHERE DueDate < today AND PaymentStatusId=UPCOMING AND CompanyId=X AND IsCancelled=0` with row-level locking. Wrap the `linkDonationToPledgePayment` update in a transaction with optimistic concurrency (check that PaymentStatusId was not already OVERDUE before setting PAID, or use a rowversion/timestamp column). At minimum, document this as a known concurrency risk.

**EC-7 — Pledge with zero paid installments deleted (no hard-delete guard):**
The hard-delete condition checks for no PAID rows. A brand-new Pledge with all SCHEDULED rows and no PAID rows can be hard-deleted. This cascades to DELETE all PledgePayment rows (CASCADE DELETE on FK). This is intentional and acceptable, but the BE `DeletePledge` command must explicitly verify no PAID rows before proceeding (do not rely on DB cascade alone, which will fail if the FK has RESTRICT; confirm the FK is CASCADE DELETE as stated).

**EC-8 — PledgeSummary KPI multi-currency mixing (ISSUE-12, already pre-flagged):**
Confirmed that `totalActivePledgedAmount` and `outstandingBalanceTotal` will produce incorrect sums if pledges span multiple currencies. The short-term recommendation (filter to Company default currency, add subtitle "(in {defaultCurrencyCode})") is pragmatic. Backend Dev must add a `WHERE CurrencyId = Company.DefaultCurrencyId` filter to the summary query and document the limitation. This must also appear in the KPI widget subtitle to avoid confusing staff.

**EC-9 — fulfillmentPercent capped at 100 but PaidAmount may exceed TotalPledgedAmount:**
If a donor overpays (PaidAmount > DueAmount in one or more installments), `fulfilledAmount` can exceed `TotalPledgedAmount`, making `outstandingBalance` negative and `fulfillmentPercent` > 100. The prompt caps `fulfillmentPercent` at 100, which is correct for display. But `outstandingBalance` being negative may confuse staff. RECOMMENDATION: Cap `outstandingBalance` at 0 in the projection (never return negative), and show overpayment separately if needed (out of scope for now). Also ensure the FULFILLED status trigger (`fulfilledAmount >= TotalPledgedAmount`) fires correctly on overpayment — this is already covered by `>=`.

**EC-10 — EndDate derivation conflict with explicitly set EndDate:**
If a user sets `EndDate` manually and then changes `FrequencyId` or `TotalPledgedAmount`, the client-side auto-calc may override the manually set EndDate. The prompt notes that `useWatch` should stop overwriting a `touchedField`, but EndDate has dual semantics: (a) auto-derived from N+Frequency, (b) user-set to derive N. If the user manually entered EndDate and then changes Frequency, the behavior is ambiguous: should N be recomputed from the (fixed) EndDate, or should EndDate be recomputed from the (unchanged) N? RECOMMENDATION: When EndDate is `touched`, treat it as the anchor and recompute N on Frequency change. When EndDate is NOT touched, treat N as the anchor and recompute EndDate. The current prompt logic (section ⑥ auto-calc block) covers this, but FE dev must ensure the `touched` state is correctly tracked per field and not cleared on other field changes.

**EC-11 — nextDuePledgePaymentId in PledgeResponseDto from the list query:**
Section ⑩ includes `nextDuePledgePaymentId` in `PledgeResponseDto`. This requires a per-row subquery on the list query, in addition to the 5 other per-row subqueries already flagged in ISSUE-7 (N+1 risk). This is the 6th subquery. Backend Dev should combine all subqueries into a single CTE or LEFT JOIN LATERAL per pledge row. If using EF LINQ, verify the generated SQL with `ToQueryString()` before committing.

---

## Contract Validation (Section ⑩)

**Queries — CONFIRMED:**

All 5 queries are derivable from the entity + FK data:
- `pledges` (list): all projected fields (`donorName`, `campaignName`, `frequencyName`, `computedStatusCode`, etc.) are derivable via JOIN to Contact, Campaign, DonationPurpose, Currency, PaymentMode, MasterData. Subquery projections (fulfilledAmount, outstandingBalance, etc.) derivable from PledgePayments collection. No cross-entity state needed beyond what the model captures.
- `pledgeById`: includes `paymentSchedule: [PledgePaymentResponseDto]` — derivable from PledgePayments child rows with MasterData join for status details.
- `pledgeSummary`: derivable from Pledges + PledgePayments with date filtering. Note: `fulfilledPledgeCountYtd` requires a correlated subquery to identify pledges whose `fulfilledAmount >= TotalPledgedAmount` AND at least one `PaidDate` falls within the current year — this is slightly more complex than counting distinct pledges by year. Backend Dev must be precise: a pledge fulfilled in a prior year but with a payment in the current year should not double-count. RECOMMENDATION: Count pledges where `CancelledAt IS NULL AND SUM(PaidAmount) >= TotalPledgedAmount AND MAX(PaidDate) >= Jan 1 of current year`.
- `pledgeOverdueAlert` (top 5 overdue payments): `daysOverdue` field is derivable as `DATEDIFF(day, DueDate, GETDATE())` at query time — no stored column needed.
- `nextDuePledgePayment`: returns a single `PledgePaymentResponseDto` — fully derivable.

**Mutations — CONFIRMED:**

- `createPledge` / `updatePledge`: input is `PledgeRequestDto` without paymentSchedule — correct; BE generates schedule. Return type `int` (new pledgeId) is consistent with platform patterns.
- `cancelPledge`: input is `pledgeId + cancelledReason (string 500)`. The MaxLen constraint matches the entity field. Correct.
- `deletePledge` / `togglePledge`: standard pattern. Correct.

**PledgeResponseDto — CONFIRMED with one flag:**

All listed fields are derivable from entity + FK data:
- `donorAvatarColor` — listed as "derived from contactId hash." This is a FE-side or BE-side color derivation, not a stored column. If computed BE-side, it should be a deterministic hash of ContactId (e.g., `contactId % N` → pick from a fixed palette). If computed FE-side from a returned `contactId`, no BE change needed. RECOMMENDATION: Compute FE-side to avoid BE coupling. FE utility function takes `contactId` and returns a hex from a fixed palette. Remove from `PledgeResponseDto` if FE-computed (simplifies BE projection).
- `frequencySuffix` — must come from `MasterData.dataValue` for the Frequency row. However, the MasterData seed defines `dataValue` as the number of days (30/90/180/365/0), not a suffix string like "/mo". There is a mismatch: the DTO expects `frequencySuffix = "/mo"` but the seed's `dataValue` is `"30"`. RECOMMENDATION: Add a separate `suffixValue` field to the MasterData seed rows, OR use a separate `MasterData.dataLabel` or `dataValue2` column (if the platform supports it), OR hard-code the suffix mapping in the BE projection based on typeCode+dataValue. NEEDS CLARIFICATION — check if MasterData has a spare column for this. If not, the BE must derive the suffix from the frequency name (Monthly→/mo, Quarterly→/qtr, etc.) using a switch expression.
- `campaignOrPurposeName` — projected as `campaignName ?? donationPurposeName`. Derivable. Correct.
- `scheduleDisplay` — projected as `"$500/mo"` (installmentAmount + currency symbol + freqSuffix). Needs `frequencySuffix` to be resolved first (see above). Correct derivation once suffix is resolved.
- `computedStatusColor` — projected from MasterData ColorHex matching the `computedStatusCode`. Derivable via a lookup from the PLEDGESTATUS seed rows. Correct.

**PledgePaymentResponseDto — CONFIRMED:**
- `daysUntilDue` (signed int, negative = overdue): derivable at query time from `DueDate - today`. No stored column needed. Correct.
- `donationReceiptCode`: derivable from `GlobalDonation.ReceiptCode` when `GlobalDonationId IS NOT NULL`. Requires a LEFT JOIN to GlobalDonations in `pledgeById` query. Correct.

**PledgeSummaryDto — FLAG (already noted in EC-8):**
- `currencyCode` field: described as "Company default currency code." This requires a JOIN to the Company entity to retrieve `DefaultCurrencyId` → `Currencies.CurrencyCode`. The Company entity and its FK to Currencies must be accessible in the Pledge query context. Confirm the `DonationDbContext` includes access to Company + Currency. If not, a cross-context call is needed.

**PledgeOverdueAlertDto — CONFIRMED:**
- All 9 fields are derivable from PledgePayments + Pledge + Contact + Currency joins. No missing state.
- `daysOverdue` (positive int) = `DATEDIFF(day, DueDate, today)` — derivable. Correct.

---

## Open Questions

**OQ-1 (HIGH — ISSUE-1):** GlobalDonation form does not currently accept `pledgePaymentId` query param. Must be resolved before the Record Payment deep-link can function end-to-end. Preferred approach: add a `linkDonationToPledgePayment(donationId, pledgePaymentId)` mutation post-create, called automatically when the donation form is submitted with `pledgePaymentId` in the URL. This keeps `createGlobalDonation` unchanged. Assign to Backend Dev + Frontend Dev (GlobalDonation screen) as a dependency.

**OQ-2 (HIGH — ISSUE-14):** When a GlobalDonation is linked to a PledgePayment, the PledgePayment row must transition to PAID (set `PaidDate = GlobalDonation.DonationDate`, `PaidAmount = GlobalDonation.DonationAmount`, `PaymentStatusId = PAID`). This is a state transition that must happen atomically with the donation creation (or in the `linkDonationToPledgePayment` mutation). Confirm implementation location with Backend Dev. This is a critical business rule not to miss.

**OQ-3 (MEDIUM — ISSUE-3):** BEHIND status for Custom frequency — implement using PledgePayment.DueDate schedule as source of truth (sum DueAmount WHERE DueDate <= today). Backend Dev to confirm.

**OQ-4 (MEDIUM — ISSUE-5):** UpdatePledge schedule regen must be atomic (transaction). Consider a dedicated service method `ScheduleRegenerationService.Regenerate(pledgeId, command)` rather than inline logic in the command handler. This makes testing and future auditing easier.

**OQ-5 (MEDIUM — ISSUE-9):** StartDate edit after payments recorded — the regen anchor must be `lastPaidInstallmentNumber + 1`, not `StartDate`. Backend Dev must implement: fetch MAX(InstallmentNumber) WHERE PaymentStatusCode='PAID', regenerate from that installment + 1, preserving the original InstallmentNumber sequence. Test case: 24-installment pledge, 2 paid, StartDate changed → regenerate installments 3–24 with recalculated DueDates anchored from StartDate or from last paid DueDate + freqDays.

**OQ-6 (MEDIUM):** `IsCancelled` column on PledgePayment — decision needed. See Entity Design flag above. If the join approach is chosen (no new column), all overdue/summary queries must JOIN Pledges to filter out cancelled parent rows. If `IsCancelled` column is added, a migration is simpler and queries are cleaner. Recommend adding the column.

**OQ-7 (MEDIUM):** `frequencySuffix` derivation — confirm whether MasterData has a spare text column to store display suffixes (/mo, /qtr, /yr, /semi-yr, custom). If not, the BE projection must use a hard-coded switch. FE dev needs clarity before building the `scheduleDisplay` renderer and the Schedule section auto-calc hint text.

**OQ-8 (LOW — ISSUE-2):** Donor-link to Contact screen — Contact screen (#18) not yet built. Per ISSUE-2 recommendation, render the link but show a toast "Contact detail view coming soon." This requires a graceful fallback check in the `donor-link` renderer (detect whether the target route exists or use a feature flag).

**OQ-9 (LOW — ISSUE-12):** Multi-currency KPI summary — confirm Company default currency is accessible from `DonationDbContext`. If not, the summary query needs a cross-context lookup or a Company.DefaultCurrencyCode column cached on the Pledge level. Short-term: filter summary to `CurrencyId = Company.DefaultCurrencyId` and add "(in {code})" subtitle.

**OQ-10 (LOW — Custom frequency DueDates, EC-4):** For Custom frequency, confirm whether uniform spacing from StartDate + EndDate is acceptable, or whether staff need to enter individual DueDates per installment. If individual dates are needed, the FE form requires a dynamic row-input UI not described in the current prompt. NEEDS CLARIFICATION from product owner.

---

## Path Correction Flag

The following path corrections must be communicated to the Backend Developer:

| What the prompt says | Actual correct path | Applies to |
|---------------------|--------------------|-----------:|
| `Base.Domain/Models/SharedModels/MasterData.cs` | `Base.Domain/Models/SettingModels/MasterData.cs` | Sections ③, ⑧ |
| `Base.Domain/Models/SharedModels/Currency.cs` | `Base.Domain/Models/SettingModels/Currency.cs` | Section ③ FK table |
| `Base.Domain/Models/SharedModels/PaymentMode.cs` | `Base.Domain/Models/SettingModels/PaymentMode.cs` | Section ③ FK table |
| `Pss2.0_Frontend/...` | `PSS_2.0_Frontend/...` | All FE file paths in ⑧ |
| `Pss2.0_Backend/...` (implied by folder casing) | `PSS_2.0_Backend/...` | All BE file paths in ⑧ |

NOTE: The folder name `sql-scripts-dyanmic/` is a known repo typo (not a correction — preserve as-is per ISSUE-15 precedent).

---

## Actors + Roles Confirmation

**CONFIRMED — BUSINESSADMIN-only is acceptable and correct.**

Per user directive (feedback_build_directives.md) and the pre-filled approval config in Section ⑨:
```
RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
```

This is the standard role assignment for all fundraising/CRM management screens. No additional roles are needed. The `ISMENURENDER` capability is set at the menu level, not per-role, which is correct.

No re-prompting for permissions is needed during build (per build directive memory: "no permission re-prompting").

---

## Summary Assessment

The pledge.md prompt is comprehensive and well-structured. The main build risks are:

1. **CRITICAL**: IsCancelled/cancellation state on PledgePayment child rows — missing from the entity design (OQ-6).
2. **CRITICAL**: Record Payment → PledgePayment PAID transition (ISSUE-14 / OQ-2) — cross-screen BE dependency that must not be left for a later sprint.
3. **HIGH**: GlobalDonation form does not accept pledgePaymentId param (ISSUE-1 / OQ-1) — the entire "Record Payment" UX flow is blocked until this is resolved.
4. **MEDIUM**: frequencySuffix derivation mismatch (OQ-7) — MasterData.dataValue stores days (integer), not suffix strings. Projection will fail unless resolved.
5. **MEDIUM**: N+1 risk on GetAll with 6 per-row subqueries (ISSUE-7 / EC-11) — must verify EF-generated SQL.
6. **MEDIUM**: Path corrections (SettingModels not SharedModels, PSS_2.0 not Pss2.0 casing).

All other rules, contracts, and patterns are validated and ready for build.
