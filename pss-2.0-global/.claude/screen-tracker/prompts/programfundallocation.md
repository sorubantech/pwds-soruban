---
screen_id: 177
screen_name: Program Fund Allocation
module: Case Management (CRM)
screen_type: FLOW
scope: FULL
status: COMPLETED
complexity: Medium-High
companion_of: 51 (Program), 50 (Case)
planned_date: 2026-06-23
completed_date: 2026-06-23
last_session_date: 2026-07-08
---

# Program Fund Allocation — Screen Prompt (#177)

> **One-line:** A post-creation, lifecycle-gated workbench where a manager opens an **ACTIVE** program and, per linked funding source (grant / donation purpose), records the **actual allocation** (amount + cadence + period) and maintains an **audit ledger** (ALLOCATION / DRAWDOWN / ADJUSTMENT) from which **Allocated / Used / Remaining / #txns** are rolled up.
>
> **Division of labour (settled in Program #51 S18→S20):** the Program create/edit form defines *what funds a program* (links grants/purposes) and *the expected annual amount* per source (the planning target). **This screen defines *how much* is actually allocated and tracks *what's been used*.** "Create defines what funds it; operate defines how much."

---

## ⓪ CRITICAL CONTEXT — READ FIRST

This is **NOT a greenfield screen.** The entire data model and the entire workbench UI **already exist** — built and (pending user migration) shipped under Program #51 Sessions 19–20. This screen is the **missing front door + write path**:

1. **BE schema — EXISTS, reuse as-is, NO schema change:**
   - `case.ProgramFundingSource` (already has `ExpectedAnnualAmount`, `AllocatedAmount`, `CurrencyId`, `AllocationFrequencyCode`, `StartDate`, `EndDate`).
   - `case.ProgramFundingTransaction` ledger (`TransactionType` ALLOCATION/DRAWDOWN/ADJUSTMENT, `Amount`, `CurrencyId`, `TransactionDate`, `LinkedDonationId`/`LinkedGrantExpenseId`/`LinkedPaymentTransactionId` (no FK), `Notes`).
   - `Base.Domain/Models/CaseModels/ProgramFundingSource.cs`, `ProgramFundingTransaction.cs` + their `…Configuration.cs`.
2. **BE rollup + need logic — EXISTS in `GetProgramById.cs`** (per-source `TotalAllocated`/`TotalUsed`/`RemainingAmount`/`TransactionCount`, `ComputeAnnualNeed`, `FrequencyToAnnualMultiplier`). The new query **must reuse the identical logic** (extract to a shared helper, or copy verbatim).
3. **FE workbench UI — EXISTS** as the **non-`linksOnly` branch** of `program-funding-sources.tsx`: `FundingSourceCard` renders the per-source allocation grid (amount + currency + cadence + start/end), the rollup strip, and the collapsible nested-field-array ledger with Add Ledger Entry. **This screen mounts that exact component with `linksOnly={false}`.**
4. **BE write path — DOES NOT EXIST YET.** Program #51 S19-addendum rewrote `UpdateProgram.SyncFundingSources` to touch **only links + `ExpectedAnnualAmount`** and to **NEVER** write allocation/cadence/dates/ledger (so a program-form save can't wipe what this screen sets). The ONGOING-cadence + txn-validity validators "remain but are inert for the form — they'll be reused by the allocation screen's command." **Building that command is the core BE deliverable here.**

**Golden rule for this screen:** never touch the links (GrantId/DonationPurposeId), never create/remove funding-source rows, never touch `ExpectedAnnualAmount`. Those belong to the program form. This screen writes only `AllocatedAmount`/`CurrencyId`/`AllocationFrequencyCode`/`StartDate`/`EndDate` on existing rows + the ledger.

---

## ① Identity & Context

| Field | Value |
|-------|-------|
| Screen | Program Fund Allocation |
| Registry # | 177 |
| Module | CRM → Case Management |
| Type | FLOW (active-program picker → full-page allocation workbench) |
| Scope | FULL (FE screen + 1 new BE query + 1 new BE command; reuses existing schema & FE component) |
| Companion of | Program #51 (owns links + expected amounts), Case #50 |
| Lifecycle gate | Only **ACTIVE** programs are allocatable. DRAFT / SUSPENDED / CLOSED → not allocatable. |

**Business framing (NGO funding model, settled in Program S17–S20):** A program is funded by any number of grants and/or donation purposes (M:N, via `case.ProgramFundingSource`). Four distinct money numbers are kept apart on purpose:

1. **Need** (`computedAnnualNeed`) — auto-computed planning estimate (capacity × per-beneficiary cost / sponsorship).
2. **Expected / source** (`ExpectedAnnualAmount`) — set on the **program form** (the planning split).
3. **Allocated / source** (`AllocatedAmount` + ledger ALLOCATION rows) — **set HERE** (the actual commitment).
4. **Used** (ledger DRAWDOWN rows) — **tracked HERE** (real spend).

This screen owns numbers **3 and 4**.

---

## ② Entity Definition

**No new entity. No schema change. No migration for this screen.** Operates on the existing:

- `case.ProgramFundingSource` — writes `AllocatedAmount`, `CurrencyId`, `AllocationFrequencyCode`, `StartDate`, `EndDate` on rows that already exist (created by the program form).
- `case.ProgramFundingTransaction` — full CRUD on ledger rows (diff-persist: add / update / soft-delete by `IsDeleted`).

(Full column lists are in §⓪ and Program #51 S19. Do not re-add columns.)

---

## ③ FK / Reference Resolution

All targets already exist and are already wired in `ProgramFundingSourceConfiguration.cs` / `ProgramFundingTransactionConfiguration.cs`:

| Ref | Target | Path | Notes |
|-----|--------|------|-------|
| ProgramId | `case.Programs` | `Base.Domain/Models/CaseModels/Program.cs` | scope every read/write to this program |
| GrantId | `grant.Grants` | `Base.Domain/Models/GrantModels/Grant.cs` | display `GrantTitle` (read-only here) |
| DonationPurposeId | `fund.DonationPurposes` | `Base.Domain/Models/DonationModels/DonationPurpose.cs` | display `DonationPurposeName` (read-only here) |
| CurrencyId | `com.Currencies` | `Currency.cs` | FE `CURRENCIES_QUERY`, value `currencyId`, label `currencyCode` |

**MasterData:** none needed for allocation. `AllocationFrequencyCode` and `TransactionType` are **plain codes** (no MasterData FK) — exact enums below.

- `AllocationFrequencyCode`: `ONETIME` / `MONTHLY` / `ANNUAL` (ONGOING programs: hide ONETIME).
- `TransactionType`: `ALLOCATION` / `DRAWDOWN` / `ADJUSTMENT`.
- `ProgramTypeCode` (drives cadence rules): `ONGOING` / `ONETIME` / `FIXEDTERM`.
- `StatusCode` (lifecycle gate): allocatable only when `ACTIVE`.

---

## ④ Business Rules

1. **Lifecycle gate (hard):** allocation is allowed only for programs whose `StatusCode == "ACTIVE"`. Non-active → picker shows the program but the Allocate action is disabled (tooltip: "Funds can be allocated once the program is Active"); a direct URL to a non-active program renders a gated empty-state, not the workbench. **Enforce on BE too** (command rejects non-active programs).
2. **Cadence vs ProgramType (reuse existing validators):**
   - `ONGOING` ⇒ allocation must use a recurring cadence (`MONTHLY` / `ANNUAL`); `ONETIME` is invalid and hidden in the dropdown.
   - `FIXEDTERM` / `ONETIME` may use `ONETIME`.
   - EndDate may be null (open-ended) for ONGOING.
3. **Txn validity (reuse existing validator):** `TransactionType` ∈ {ALLOCATION, DRAWDOWN, ADJUSTMENT}; `Amount` required (ADJUSTMENT may be negative; ALLOCATION/DRAWDOWN ≥ 0).
4. **Source set is immutable here:** rows are matched by `Id` and must belong to `programId`. The command **must not** create new sources, delete sources, change GrantId/DonationPurposeId, or change `ExpectedAnnualAmount`. (If a source `Id` in the request doesn't belong to the program → reject.)
5. **Diff-persist the ledger:** transactions present with an `Id` → update; without `Id` → insert; previously-persisted rows absent from the request → soft-delete (`IsDeleted = true`). Mirror `UpdateProgram`'s prior `SyncFundingTransactions` (removed from the form path, resurrected here).
6. **Rollups are never stored** — always computed from live ledger rows (identical to `GetProgramById`): `TotalAllocated = Σ ALLOCATION + Σ ADJUSTMENT` (fallback to `AllocatedAmount` when no ledger rows), `TotalUsed = Σ DRAWDOWN`, `RemainingAmount = TotalAllocated − TotalUsed`, `TransactionCount = ledger row count`.
7. **Currency default:** new ledger/allocation rows default `CurrencyId` to the company base currency (FE `useCompanySettingsSession(...).baseCurrencyId`) — same as the existing component.

---

## ⑤ Classification (pre-answered for Solution Resolver)

- **screen_type:** FLOW. Grid (active-program picker) → full-page workbench keyed by `?programId=X` (no modal, no drawer).
- **Not MASTER_GRID** (no list-of-N modal CRUD on a single entity), **not DASHBOARD** (it writes), **not CONFIG** (program-scoped, reached per-record).
- **Pattern reuse:** parallels the Event consolidation tabs gated on "entity exists" and the program card-grid `onManage` navigation. The workbench body **is** the existing `ProgramFundingSources` component.
- **Layout variant:** `widgets-above-grid` is N/A for the picker (plain card/list). The workbench is a single full-page form (ScreenHeader + program summary strip + funding-source cards). Use `showHeader={false}` on any reused grid container to avoid the double-header bug.

---

## ⑥ UI/UX Blueprint

### Entry points (two doors, one route)

- **Route:** `crm/casemanagement/programfundallocation` (sidebar leaf **PROGRAMFUNDALLOCATION**, OrderBy 5 under CRM_CASEMANAGEMENT).
- **Door A — program card action (primary):** add a third footer button **"Funding"** (icon `ph:hand-coins`) to `program-card.tsx`, wired through a new `onAllocate(programId)` on `ProgramCardConfig`. Enabled only when the card's program is `ACTIVE` (else disabled + tooltip). Routes to `…/programfundallocation?programId=X`.
- **Door B — sidebar leaf (secondary, discoverability):** bare route (no `programId`) renders an **active-program picker**.

### LAYOUT 1 — Picker (no `programId`)

- `ScreenHeader` title "Fund Allocation", subtitle "Allocate funds to active programs and track usage", breadcrumbs Home → Case Management → Fund Allocation.
- A searchable list of **ACTIVE** programs only. **Reuse the existing programs list query** (`GRID_CODE = "PROGRAM"` data / the programs GraphQL list) filtered to `StatusCode == ACTIVE`. Render as compact cards or a simple table: icon/color, ProgramName, ProgramCode, FundingModelCode badge, #funding-sources, and a primary **"Allocate Funds →"** action that routes to `?programId=X`.
- Empty state when no active programs: "No active programs yet. Activate a program to allocate funds."

### LAYOUT 2 — Workbench (`?programId=X`)

1. **Back link** → returns to the picker (or to Program Management).
2. **Program summary strip** (read-only): icon + ProgramName + ProgramCode, FundingModelCode + ProgramTypeCode badges, StatusCode badge (solid pill per the solid-bg/white-fg convention), and a **need vs allocated** mini-rollup: Annual Need (`computedAnnualNeed`) · Total Expected (Σ `ExpectedAnnualAmount`) · Total Allocated (Σ source `TotalAllocated`) · Total Used (Σ source `TotalUsed`). All money in the program's base/budget currency via `formatCurrency`.
3. **Gated empty-state** if program not ACTIVE: a centered notice "Funds can be allocated once the program is Active" + back link. No workbench.
4. **No funding sources linked yet:** notice "This program has no funding sources. Add grants or donation purposes on the Program form first." + a link/button to open the program edit form (`crm/casemanagement/programmanagement?mode=edit&id=X`). **No adders here** — linking is the program form's job.
5. **Funding-source workbench:** mount `<ProgramFundingSources control={...} linksOnly={false} programTypeCode={programTypeCode} showGrantPicker={false} showDonationPurposePicker={false} />`.
   - **IMPORTANT reuse note:** today the component renders the grant/purpose **adders** whenever `showGrantPicker`/`showDonationPurposePicker` are true. For this screen the source set is fixed, so pass both `false` (the component already guards the adder blocks on those flags) — the `fundingSources` field array still renders each existing row as a `FundingSourceCard`. Confirm the empty-array branch text still reads sensibly; if needed, thread a tiny `mode="allocate"` prop to swap the empty-state copy. Keep the change additive — do not fork the component.
6. **Save bar (sticky footer):** "Save Allocations" (primary) + "Cancel". Save calls the new mutation with only this program's funding sources (allocation fields + transactions), strips response-only fields (grantTitle / donationPurposeName / currencyCode / rollups / expectedAnnualAmount), and refetches.

### Reused workbench card (already built — for reference)

Per `FundingSourceCard`: header (source icon + label + Grant/Purpose tag), allocation grid (Allocated Amount / Currency / Cadence), Start/End dates, rollup strip (Allocated / Used / Remaining / #txns), collapsible **Audit ledger** (per-row Type / Amount / Date / Notes + remove, plus **Add Ledger Entry**). Cadence dropdown hides ONETIME for ONGOING. **No UI to build — mount it.**

---

## ⑦ Substitution Guide

| Token | Value |
|-------|-------|
| Entity (logical) | ProgramFundingAllocation (no table — operates on ProgramFundingSource) |
| PascalCase | ProgramFundingAllocation |
| camelCase | programFundingAllocation |
| kebab | program-fund-allocation |
| Schema | case |
| Module / Parent menu | CRM / CRM_CASEMANAGEMENT |
| MenuCode | PROGRAMFUNDALLOCATION |
| MenuUrl | crm/casemanagement/programfundallocation |
| FE route folder | `src/app/[lang]/crm/casemanagement/programfundallocation/` |
| FE component folder | `src/presentation/components/page-components/crm/casemanagement/program/` (co-locate with program) |
| Canonical FE reference | `program-form-page.tsx` (load + map + submit pattern), `program-funding-sources.tsx` (workbench body) |
| Canonical BE reference | `GetProgramById.cs` (rollup + need), `UpdateProgram.cs` (`SyncFundingTransactions` diff-persist + validators) |

---

## ⑧ File Manifest

### Backend (new + small edits)

**NEW — Query**
- `Base.Application/Business/CaseBusiness/Programs/.../GetProgramFundingAllocation.cs` (or under a new `ProgramFundingAllocation` folder)
  - `GetProgramFundingAllocationQuery(int programId) : IQuery<…>`, `[CustomAuthorize(DecoratorCaseModules.Program, Permissions.Read)]`.
  - Loads the program + `FundingSources` (with Grant/DonationPurpose/Currency/Transactions includes — copy the includes block from `GetProgramById`).
  - Returns `ProgramFundingAllocationDto` (see §⑩). **Reuse the exact rollup + `ComputeAnnualNeed`/`FrequencyToAnnualMultiplier`** from `GetProgramById` — extract them to a shared internal static (preferred) or copy verbatim.

**NEW — Command**
- `Base.Application/Business/CaseBusiness/Programs/.../SaveProgramFundingAllocation.cs`
  - `SaveProgramFundingAllocationCommand` (programId + `List<ProgramFundingSourceDto>` — allocation fields + transactions only), `[CustomAuthorize(DecoratorCaseModules.Program, Permissions.Update)]`.
  - Validator: program exists + is **ACTIVE**; every source `Id` belongs to `programId`; reuse the **ONGOING-cadence** + **txn-validity** validators (lift from `CreateProgram`/`UpdateProgram` — they were left in place for exactly this).
  - Handler: load `program.FundingSources.ThenInclude(Transactions)`; for each request source matched by `Id`, set `AllocatedAmount/CurrencyId/AllocationFrequencyCode/StartDate/EndDate` and `SyncFundingTransactions(...)` (add/update/soft-delete). **Never** touch GrantId/DonationPurposeId/ExpectedAnnualAmount or add/remove sources. Wrap writes per the Npgsql execution-strategy rule if a transaction is opened.

**NEW — Schema DTO**
- Add `ProgramFundingAllocationDto` to `Base.Application/Schemas/CaseSchemas/ProgramSchemas.cs` (header fields + `List<ProgramFundingSourceDto> FundingSources`). Reuse existing `ProgramFundingSourceDto` / `ProgramFundingTransactionDto` (no new child DTOs).

**EDIT — GraphQL endpoints**
- `Base.API/EndPoints/Case/Mutations/ProgramMutations.cs` — add `saveProgramFundingAllocation` mutation (mirror existing program mutations; HC strips `Save…`? — verify: method name → GQL field; use `request:` arg wrapper consistent with siblings).
- Program **Queries** endpoint (find the file exposing `programById` — same folder pattern under `EndPoints/Case/Queries`) — add `programFundingAllocation(programId: Int!)`.

### Frontend (new + small edits)

**NEW — route + screen**
- `src/app/[lang]/crm/casemanagement/programfundallocation/page.tsx` (thin wrapper → page config, mirror `programmanagement/page.tsx`).
- `src/presentation/pages/crm/casemanagement/program-fund-allocation.tsx` (page config export) + barrel update.
- `…/program/program-fund-allocation-page.tsx` (the smart component: reads `?programId`, branches picker vs workbench, RHF form scoped to `{ fundingSources }`, load via new query, submit via new mutation). Reuse `program-form-page.tsx` load/map/submit scaffolding (defaultValues map source rows incl `transactions` + ids; `toRequest` strips response-only + recursively strips `__typename`).
- `…/program/program-allocation-picker.tsx` (active-program list; reuse programs list query filtered to ACTIVE).

**NEW — GraphQL**
- `infrastructure/gql-queries/.../ProgramFundingAllocationQuery.ts` (query `programFundingAllocation` — select header + `fundingSources { id grantId grantTitle donationPurposeId donationPurposeName expectedAnnualAmount allocatedAmount currencyId currencyCode allocationFrequencyCode startDate endDate totalAllocated totalUsed remainingAmount transactionCount transactions { id transactionType amount currencyId currencyCode transactionDate linkedDonationId linkedGrantExpenseId linkedPaymentTransactionId notes } }`).
- Mutation `SaveProgramFundingAllocationMutation` (variable type reuses `ProgramFundingSourceDtoInput` — already covers the nested shape).

**EDIT — card entry point**
- `…/card-grid/types.ts` — add `onAllocate: (programId: number) => void` to `ProgramCardConfig`.
- `…/card-grid/variants/program-card.tsx` — add the "Funding" footer button (gated to ACTIVE).
- `…/program/index-page.tsx` — supply `onAllocate` in `cardConfig` → `router.push(\`/${lang}/crm/casemanagement/programfundallocation?programId=${id}\`)`.

**REUSE (no edit, or tiny additive prop)**
- `program-funding-sources.tsx` (mount `linksOnly={false}`, adders off). Add at most a small empty-state copy prop if needed — additive only.
- `program-form-schemas.ts` — reuse `fundingSourceSchema`/`metricSchema` types for the RHF shape (the screen can define a slim `allocationSchema` referencing the same `fundingSources` array-of-objects + `transactions`).

### Wiring (serialize — warn user)
- Sidebar/menu seed for `PROGRAMFUNDALLOCATION` (MenuCode, parent CRM_CASEMANAGEMENT, MenuUrl, OrderBy 5, capabilities). **User-applied seed** (per project convention).
- Route registration follows the app's `[lang]` folder convention (file-based — no central Routes.tsx edit expected; verify).

---

## ⑨ Approval Config (pre-filled — user reviews)

| Key | Value |
|-----|-------|
| MenuCode | PROGRAMFUNDALLOCATION |
| MenuName | Fund Allocation |
| ParentMenuCode | CRM_CASEMANAGEMENT |
| ModuleCode | CRM |
| MenuUrl | crm/casemanagement/programfundallocation |
| OrderBy | 5 |
| GridType | — (FLOW; picker reuses PROGRAM grid/list) |
| GridFormSchema | SKIP (FLOW) |
| Role | BUSINESSADMIN (read + update/allocate) |
| Permission decorator | `DecoratorCaseModules.Program` — Read (query) + Update (save). Add a dedicated capability only if RBAC must separate "allocate" from "edit program"; default = reuse Program/Update. |

---

## ⑩ BE → FE Contract

**Query:** `programFundingAllocation(programId: Int!)` → `ProgramFundingAllocationDto`:

```
ProgramFundingAllocationDto {
  programId: int
  programCode, programName: string
  iconEmoji, colorHex: string?
  programTypeCode: string         // ONGOING / ONETIME / FIXEDTERM (drives cadence)
  fundingModelCode: string        // INDIVIDUAL / POOL / GRANT / MIXED
  statusCode: string              // gate: ACTIVE
  budgetCurrencyCode: string?
  computedAnnualNeed: decimal?     // reuse GetProgramById.ComputeAnnualNeed
  totalExpected: decimal?          // Σ ExpectedAnnualAmount (convenience; FE can also sum)
  fundingSources: [ProgramFundingSourceDto]   // existing DTO, with allocation fields + rollups + transactions
}
```

**Mutation:** `saveProgramFundingAllocation(request: { programId, fundingSources: [ProgramFundingSourceDtoInput!] })` → `BaseApiResponse<int>` (bare `data: Int!` — affected count or programId; select bare `data`, no subfields).

**Send-side discipline (HC strict input):** the FE `toRequest` must send per source only `{ id, allocatedAmount, currencyId, allocationFrequencyCode, startDate, endDate, transactions: [{ id, transactionType, amount, currencyId, transactionDate, linkedDonationId, linkedGrantExpenseId, linkedPaymentTransactionId, notes }] }`. **Strip** `grantId`/`donationPurposeId`/`grantTitle`/`donationPurposeName`/`expectedAnnualAmount`/`currencyCode`/rollups + recursively strip `__typename`. (Input type name keeps the `Dto` suffix: `ProgramFundingSourceDtoInput`.)

---

## ⑪ Acceptance Criteria

1. Program card on an ACTIVE program shows a "Funding" action → opens `…/programfundallocation?programId=X`; on a non-ACTIVE program the action is disabled with a tooltip.
2. Sidebar "Fund Allocation" → picker lists only ACTIVE programs; selecting one opens the workbench.
3. Workbench shows the program summary strip with Need / Expected / Allocated / Used in the program currency.
4. Each existing funding source renders as an allocation card (the reused `FundingSourceCard`); the source set cannot be added to or removed from here.
5. Setting Allocated Amount + cadence + dates and adding ALLOCATION/DRAWDOWN ledger rows, then Save → reopen → values + ledger rehydrate; rollups show Allocated/Used/Remaining; #txns increments.
6. ONGOING program: cadence dropdown hides ONETIME; BE rejects ONETIME for ONGOING.
7. Saving the allocation screen does **not** alter the program's links or `ExpectedAnnualAmount`; saving the **program form** does **not** wipe allocation/ledger (regression guard — already implemented in `UpdateProgram`, re-verify).
8. Direct URL to a non-ACTIVE program shows the gated empty-state, not the workbench; BE command also rejects it.
9. A program with zero funding sources shows the "link sources on the program form first" notice with a deep link.
10. FE `npx tsc --noEmit` clean; HC accepts the save input (no `__typename` / response-only-field rejection).

---

## ⑫ Special Notes & Warnings

- **NO schema change, NO migration for #177.** It rides Program #51 S18–S20 schema (those user-owned migrations must be applied first — see program.md S18/S19 ⚠️ blocks; S18's `update-database` previously died on a design-time OOM, not a schema error → retry from a clean CLI).
- **Reuse, don't fork:** the workbench body is `program-funding-sources.tsx` (`linksOnly={false}`); the rollup/need logic is `GetProgramById`'s. Extract shared BE helpers rather than duplicating drift-prone math.
- **The write path is the only genuinely new logic.** `UpdateProgram.SyncFundingSources` deliberately stopped writing allocation/ledger so this screen can own it safely — resurrect the removed `SyncFundingTransactions` here.
- **Validators already exist** (ONGOING-cadence + txn-validity) — lift, don't reinvent.
- **MasterData / codes are plain strings** (`AllocationFrequencyCode`, `TransactionType`) — no MasterData lookups. Program `StatusCode`/`ProgramTypeCode`/`FundingModelCode` are UPPERCASE (PROGRAMSTATUS etc.).
- **Npgsql:** if the save opens a transaction, wrap in `CreateExecutionStrategy().ExecuteAsync(...)` (retrying strategy forbids manual `BeginTransactionAsync`).
- **User builds BE + creates migrations.** No `dotnet build`, no `dotnet ef migrations add` from the agent.
- **Entry-point UX decided 2026-06-23:** two doors (program card "Funding" action + sidebar leaf), one route, lifecycle-gated. (User delegated: "you can decide buddy with proper ux".)

---

## ⑬ Build Log

### Known Issues
| ID | Description | Status |
|----|-------------|--------|
| ISSUE-1 | Runtime E2E (BE build + CRUD round-trip: set allocation + ledger → save → reopen → rehydrate) not yet executed — BE is user-built per project convention, FE verified via `tsc --noEmit` only. Run `/test-screen #177` after the user builds BE + applies the Program S18–S20 migration. | OPEN |
| ISSUE-3 | FE delta 4 — grant-funded sources on the workbench didn't reflect the grantor's decision: a self-Approve button showed on grant-funded PENDING sources (BE rejects it → error toast), and the "Committed" figure used `ExpectedAnnualAmount` (the ask) instead of the grant's committed `AllocatedAmount`. | CLOSED (session 7) |
| ISSUE-4 | Save Allocation fails: `"The required input field 'canApprove' is missing."` — the shared `ProgramFundingSourceDto` declares the response-only gates `CanApprove`/`CanClose`/`CanLogPayment` as non-nullable `bool`, so HotChocolate makes them **required** on `ProgramFundingSourceDtoInput`, but the FE `toRequest` allow-list correctly omits them (the save handler never reads them). Fixed by making the three gates `bool?` → optional on input. No migration. | CLOSED (session 9) |
| ISSUE-5 | Grant Fund Position strip showed "Available to Allocate" = award reservation (awarded − committed), so a grant awarded 100k with only 25k received still showed 100k. Business-wrong: you can only give a program cash the funder actually sent. Fixed — strip now shows Awarded / Received / Available where Available = cash-on-hand (received − direct expenses − program transfers). | CLOSED (session 9) |
| ISSUE-6 | Session 12 added payment-mode/reference/from-account columns via two generate-only migrations (`Add_ProgramFundingTransaction_PaymentDetails`, `Add_GrantExpense_PaymentDetails`). They must be applied (`dotnet ef database update`) before the new fields persist; until then Save will fail against the old schema. Code compiles clean; DB apply is the user's step per project convention. | OPEN |

### § Sessions

> _[8 older session entries trimmed to save tokens — full history in git: `git log -p -- programfundallocation.md`. Most recent 5 kept below.]_

### Session 9 — 2026-07-08 — FIX (ISSUE-4 save bug) + FIX (ISSUE-5 available = received cash) — COMPLETED (BE built directly by agent, no migration)

- **Scope**: User asked to fix pending issues and correct the Grant Fund Position "Available" figure. Both BE + FE changed directly this session (user authorized "fix what are issue pending"; all changes code-only, **no new migration**). Reached via `/continue-screen #177`.
- **ISSUE-4 (save bug) — FIXED**: `ProgramSchemas.cs` — `ProgramFundingSourceDto.CanApprove/CanClose/CanLogPayment` changed from `bool` → `bool?`. HotChocolate now emits them OPTIONAL on `ProgramFundingSourceDtoInput`, so the FE `toRequest` (which correctly omits these computed gates) passes validation. Query still assigns them via implicit `bool`→`bool?` (`GetProgramFundingAllocation.cs:139-141`); FE already reads `?? false`. Verified: no BE consumer reads them as non-nullable `bool`.
- **ISSUE-5 (available = received cash) — FIXED**: the strip previously showed the award-reservation ceiling (awarded − committed); user reported award 100k / received 25k still showed 100k. Now shows the CASH ceiling.
  - BE: `GrantFundingRequestHeaderDto` (`GrantSchemas.cs`) — new `decimal ReceivedAmount` + `decimal AvailableCash`. `GetGrantFundingRequests.cs` — computes `totalReceived` (Σ non-voided GrantFundReceipts, excl BOUNCED/CANCELLED), `directExpenses` (Σ GrantExpenses), `availableCash = totalReceived − directExpenses − programTransferred` (mirrors `GetGrantFinancialSummary.CashOnHand`); added `using …GrantFundReceipts;`. `AvailableToAllocate` left untouched (still used by the grant-side allocate modal — reservation semantics preserved there).
  - FE: `GrantQuery.ts` — select `receivedAmount` + `availableCash` on the header. `program-funding-sources.tsx` `GrantFundPositionStrip` — now renders **Awarded / Received / Available** (Available = `availableCash`, emerald when > 0).
- **Files touched**:
  - BE: `Base.Application/Schemas/CaseSchemas/ProgramSchemas.cs`; `Base.Application/Schemas/GrantSchemas/GrantSchemas.cs`; `Base.Application/Business/GrantBusiness/Grants/GetFundingRequestsQuery/GetGrantFundingRequests.cs`.
  - FE: `src/infrastructure/gql-queries/grant-queries/GrantQuery.ts`; `.../program/program-funding-sources.tsx`.
  - DB: none.
- **Deviations from spec**: BE built directly by agent this session (prior sessions had user building BE) — user explicitly asked to fix pending issues; all changes are code-only with no new migration.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-4, ISSUE-5.
- **Verification**: BE `dotnet build Base.Application` exit 0 (clean). FE `npx tsc --noEmit` CLEAN except the known pre-existing unrelated `donation-service` duplicate `PaymentMethodCode` export.
- **Next step**: user runs the API host + applies the `20260708061730` migration if not yet applied, then live E2E — save a grant-funded source now succeeds; the strip shows Received/Available reflecting actual fund receipts (award 100k, receipts 25k → Available 25k).

### Session 10 — 2026-07-08 — UI (grant-appropriate status wording) — COMPLETED (FE-only, no BE change)

- **Scope**: After a grant-funded source is saved, its status chip should speak the grantor's language — "Waiting for Allocation" while the grant hasn't committed, "Allocated" once it has — on BOTH the Program Fund Allocation workbench and the Grant "Fund Requests" tab. Confirmed the grant screen already lists saved grant-funded sources with a status column + Allocate button (no new listing needed); only the wording was generic ("Pending"/"Approved"). Reached via `/continue-screen #177`.
- **Change**: status codes unchanged (PENDING/APPROVED/CLOSED). Only the display label + icon are now context-aware:
  - `program-funding-sources.tsx` — replaced the static `SOURCE_STATUS_STYLES` map with a `sourceStatusChip(statusCode, isGrantFunded)` helper. Grant-funded → "Waiting for Allocation" (hourglass) / "Allocated" (seal-check) / "Closed"; self-funded (donation purpose / sponsor) keeps "Pending" (pencil) / "Approved" / "Closed". Badge render switched to `statusChip`.
  - `grant-fund-requests-tab.tsx` — every row is grant-funded, so `FundSourceStatusBadge` now reads "Waiting for Allocation" / "Allocated" / "Closed"; the header count chip reads "{n} awaiting allocation" (was "{n} pending").
- **Files touched**:
  - FE: `.../program/program-funding-sources.tsx`; `.../crm/grant/grantlist/grant/grant-fund-requests-tab.tsx`.
  - BE: none. DB: none.
- **Deviations from spec**: None (pure display wording; underlying status semantics unchanged).
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: FE `npx tsc --noEmit` CLEAN except the known pre-existing unrelated `donation-service` duplicate `PaymentMethodCode` export.
- **Next step**: none — display-only. Covered by the same E2E run as Session 9.

### Session 11 — 2026-07-08 — FIX (allocate modal ceiling = cash received, not award) — COMPLETED (BE built directly, no migration)

- **Scope**: Grant → Fund Requests tab → **Allocate modal** showed "Available to Allocate" = the award (100k) when the funder had only sent 25k. The grantor can only allocate cash actually received, so both the displayed figure AND the server guard must be cash-based. Same cash-vs-award correction as ISSUE-5, now applied to the allocate path. Reached via `/continue-screen #177`.
- **Model**: allocation ceiling = `(receivedAmount − directExpenses) − Σ commitments to OTHER sources`. Distinct from `AvailableCash` (Session 9, program strip) which nets TRANSFERS; this nets RESERVATIONS so two programs can't be promised the same received cash. Award-reservation guard kept as an additional upper bound (tightest of the two binds).
- **Files touched**:
  - BE: `GrantSchemas.cs` — `GrantFundingRequestHeaderDto.AvailableCashToAllocate` (new). `GetGrantFundingRequests.cs` — compute `availableCashToAllocate = (totalReceived − directExpenses) − totalCommitted`, set on header. `AllocateGrantToFundingSource.cs` — new guard (4b): allocation may not exceed `(received − expenses) − otherCommitted`; added `using …GrantFundReceipts;`. Existing award guard (4) retained.
  - FE: `GrantDto.ts` — typed `receivedAmount` / `availableCash` / `availableCashToAllocate` on the header interface (were previously read via `any`). `GrantQuery.ts` — select `availableCashToAllocate`. `grant-fund-requests-tab.tsx` — "Available to Allocate" KPI tile now uses `availableCashToAllocate`; modal receives `availableToAllocate={availableCashToAllocate}` + `receivedAmount`. `grant-allocate-modal.tsx` — added `receivedAmount` prop + "Fund Received" summary line; "Available to Allocate" now emerald + cash-driven; ceiling docstring updated.
  - DB: none.
- **Deviations from spec**: BE built directly by agent (consistent with Sessions 9). No new migration (uses existing GrantFundReceipts / GrantExpenses).
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Verification**: BE `dotnet build Base.Application` exit 0 (0 errors). FE `npx tsc --noEmit` CLEAN except the known unrelated `donation-service` duplicate export.
- **Next step**: user rebuilds/runs the API; live E2E — with award 100k and one 25k receipt, the allocate modal caps at 25k and shows Fund Received 25k / Available to Allocate 25k; attempting to allocate >25k is rejected server-side.

### Session 12 — 2026-07-08 — ENHANCE (payment-mode + reference + source-bank-account on money-out) — COMPLETED (BE built directly, migrations generated NOT applied)

- **Scope**: The transfer log recorded only amount/status/date/notes — it did not capture **how** the money moved. Confirmed with the user that the model already supports **both** money-out flows (charity → program → beneficiary via the transfer log; charity → vendor directly via `GrantExpense`), so payment-detail capture was added to **both**. When a program payment is marked *Transferred*, the grant-managing person now records **Payment Mode** (Bank Transfer / Cheque / Cash), a **Reference** (cheque no. / bank txn ref / cash voucher no.), and the **From Account** (the charity bank account the cash left). Same fields (mode optional) added to direct grant expenses. Reached via `/continue-screen #177`; user granted full read/write on case + grant files.
- **Model**: mirror the money-IN pattern already on `GrantFundReceipt` (`PaymentMethodId`→`com.PaymentMode`, `ReferenceNumber`, `ReceivingAccountId`→`app.OrganizationBankAccount`). Money-OUT now symmetric. Transfer log **requires** `PaymentModeId` when `PaymentStatus == TRANSFERRED` (server + FE); direct expense keeps it optional (may be logged before the mode is known). Cross-screen: this session also modified Grant #62's `GrantExpense` — logged there too.
- **Files touched**:
  - BE (Flow A — transfer log): `ProgramFundingTransaction.cs` (+`PaymentModeId`/`ReferenceNumber`/`FromBankAccountId` + nav props), `ProgramFundingTransactionConfiguration.cs` (2 optional Restrict FKs, ref len 100), `ProgramSchemas.cs` (`ProgramFundingTransactionDto` +5 fields incl. display names), `SaveProgramFundingAllocation.cs` (`SyncFundingTransactions` maps 3 writable fields both branches; validator: TRANSFERRED ⇒ PaymentModeId required), `GetProgramFundingAllocation.cs` (Include + project display names), `CaseMappings.cs` (Mapster parity). Migration `20260708100505_Add_ProgramFundingTransaction_PaymentDetails` (generate-only).
  - BE (Flow B — direct expense, Grant #62): `GrantExpense.cs` (+`PaymentModeId`/`FromBankAccountId` + nav props), `GrantExpenseConfiguration.cs` (2 optional Restrict FKs), `GrantSchemas.cs` (request +2 writable, response +2 display names), `GrantMappings.cs`, `GetGrantById.cs` (Include PaymentMode + FromBankAccount on expenses). Migration `20260708101323_Add_GrantExpense_PaymentDetails` (generate-only). No Update command exists for GrantExpense (Create-only).
  - FE (Flow A): `case-queries/ProgramFundingAllocationQuery.ts` (+5 fields on transactions), `program-form-schemas.ts` (`fundingTransactionSchema` +fields + superRefine mode-required-on-TRANSFERRED), `program-fund-allocation-page.tsx` (toRequest/reset mapping), `program-funding-sources.tsx` (loads PaymentMode + OrgBankAccount options once; per payment row, TRANSFERRED reveals Payment Mode + dynamic-labelled Reference + From Account).
  - FE (Flow B): `add-expense-modal.tsx` (Payment Mode + From Account optional selects + schema + mutation vars), `grant-detail.tsx` (`ExpenseRow` surfaces mode/account/reference), `grant-queries/GrantQuery.ts` (expenses +4 fields), `grant-service/GrantDto.ts` (+fields on request/response DTOs).
  - DB: two migrations generated, **NOT applied** (no `database update`), per project convention.
- **Deviations from spec**: reuses existing `PaymentModeQuery` / `OrganizationBankAccountQuery` FE endpoints (no new endpoints). Cross-screen edit into Grant #62 (`GrantExpense`) — noted in Grant Build Log too. `OrganizationBankAccount` displayed via `AccountName` (unmasked; masked variant available if wanted later).
- **Known issues opened**: ISSUE-6 (below) — the two new migrations must be applied by the user before this works live.
- **Known issues closed**: None.
- **Verification**: BE `dotnet build` Base.Application + Base.Infrastructure — 0 errors (both flows). FE `npx tsc --noEmit` — CLEAN except the known unrelated `donation-service` duplicate export.
- **Next step**: user applies both migrations (`Add_ProgramFundingTransaction_PaymentDetails`, `Add_GrantExpense_PaymentDetails`) + the still-pending `Add_ProgramFundingSource_AllocatedAmount`, then live E2E: mark a program payment Transferred → mode is required, reference label follows the mode, From Account lists charity bank accounts; log a direct grant expense → mode/account optional and shown on the expense row.

### Session 13 — 2026-07-09 — PLANNED (delta only; build lives on Donation Purpose #2 §⑮) — REVISION_PLANNED

- **Scope**: Extend the fund-allocation loop to **Donation Purpose** (the deferred ISSUE-20, sibling of the grant §⑭ build). Authoritative blueprint = `prompts/donationpurpose.md` §⑮ (R2). This entry records the matching deltas that land on the #177 surface — build them alongside #2 §⑮, not standalone.
- **#177-side deltas (see donationpurpose.md §⑮.5c/5d + §⑮.7)**:
  1. `SaveProgramFundingAllocation.cs` `SyncFundingTransactions` — extend the grant-only TRANSFERRED cap (`Σ ≤ AllocatedAmount`, block payment before allocation) to **purpose-funded** sources (`DonationPurposeId != null`). Sponsor keeps `≤ ExpectedAnnualAmount`.
  2. `GetProgramFundingAllocation.cs` — `committed = (GrantId != null || DonationPurposeId != null) ? CommittedAmount : ExpectedAnnualAmount`; `CanApprove = PENDING && programActive && GrantId == null && DonationPurposeId == null` (purpose now routes through the purpose-owner allocate command, not program self-approve).
  3. `program-funding-sources.tsx` — purpose-funded cards get the "Awaiting allocation" treatment + a new `DonationPurposeFundPositionStrip` (Raised · Committed · Available) fed by `DONATION_PURPOSE_FUNDING_REQUESTS_QUERY`. Mirror of the grant `GrantFundPositionStrip` branch. Cash-only pool (no Awarded/Received tiles).
- **Model**: CASH-ONLY ceiling — `AvailableToAllocate(purpose) = RaisedAmount − Σ AllocatedAmount`; `TargetAmount` informational. No schema change / no migration (unlike grant, `AllocatedAmount` already exists). **Prerequisite**: R1 `UNITTYPE=DONATIONPURPOSE` seed + node backfill (see #2 §⑮.1).
- **Known issues opened**: none new here (tracked as ISSUE-8/9/10 on #2 §⑮).
- **Next step**: build together with Donation Purpose #2 §⑮ (`/build-screen #2` or `/continue-screen #2`, BE first). After build, add a matching FIX/ENHANCE entry here.
