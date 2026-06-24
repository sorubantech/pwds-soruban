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
last_session_date: 2026-06-23
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

### § Sessions

### Session 1 — 2026-06-23 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FLOW screen, two doors (program card "Funding" action + sidebar leaf) → one lifecycle-gated workbench route. Pure assembly: reused existing schema, DTOs, rollup math, validators, and the `program-funding-sources.tsx` workbench component; only the write path + query + FE page/picker are new. Agents: backend-developer (Sonnet) + frontend-developer (Sonnet), per user cost-conscious default (overrode FLOW Opus escalation; user approved Sonnet).
- **Files touched**:
  - BE:
    - `Base.Application/Schemas/CaseSchemas/ProgramSchemas.cs` (modified — appended `ProgramFundingAllocationDto` header wrapper; existing child DTOs untouched)
    - `Base.Application/Business/CaseBusiness/Programs/ProgramFundingMath.cs` (created — shared `ApplyRollups`/`ComputeAnnualNeed`/`FrequencyToAnnualMultiplier`)
    - `Base.Application/Business/CaseBusiness/Programs/GetByIdQuery/GetProgramById.cs` (modified — refactored to call ProgramFundingMath; behavior identical)
    - `Base.Application/Business/CaseBusiness/Programs/GetFundingAllocationQuery/GetProgramFundingAllocation.cs` (created — query/validator/handler)
    - `Base.Application/Business/CaseBusiness/Programs/SaveFundingAllocationCommand/SaveProgramFundingAllocation.cs` (created — command/validator(5 rules: exists, ACTIVE gate, source-ownership, ONGOING-cadence, txn-validity)/handler with resurrected `SyncFundingTransactions` soft-delete diff-persist)
    - `Base.API/EndPoints/Case/Queries/ProgramQueries.cs` (modified — `programFundingAllocation(programId: Int!)`)
    - `Base.API/EndPoints/Case/Mutations/ProgramMutations.cs` (modified — `saveProgramFundingAllocation(request: ProgramFundingAllocationDtoInput!)` → bare `data: Int!`)
  - FE:
    - `src/infrastructure/gql-queries/case-queries/ProgramFundingAllocationQuery.ts` (created — query + mutation) + `case-queries/index.ts` (barrel)
    - `src/app/[lang]/crm/casemanagement/programfundallocation/page.tsx` (created — route wrapper)
    - `src/presentation/pages/crm/casemanagement/program-fund-allocation.tsx` (created — page config, `menuCode: "PROGRAM"`) + `casemanagement/index.ts` (barrel)
    - `src/presentation/components/page-components/crm/casemanagement/program/program-fund-allocation-page.tsx` (created — smart picker↔workbench branch, lifecycle gate, RHF `{fundingSources}`, toRequest strip + recursive `stripTypename`)
    - `src/presentation/components/page-components/crm/casemanagement/program/program-allocation-picker.tsx` (created — reuses `PROGRAMS_QUERY`, client-filters `statusCode==ACTIVE`)
    - `src/presentation/components/page-components/crm/casemanagement/program/program-funding-sources.tsx` (modified — additive `mode?: "form"|"allocate"` + `allowRemove` on FundingSourceCard; form-mode unchanged)
    - `src/presentation/components/page-components/card-grid/types.ts` (modified — `onAllocate` on ProgramCardConfig)
    - `src/presentation/components/page-components/card-grid/variants/program-card.tsx` (modified — "Funding" footer button, ACTIVE-gated + tooltip)
    - `src/presentation/components/page-components/crm/casemanagement/program/index-page.tsx` (modified — supply `onAllocate` → push to `?programId=X`)
  - DB: `PSS_2.0_Backend/DatabaseScripts/Seed/seed_program_fund_allocation_menu.sql` (created — idempotent Menus + MenuCapabilities[READ/MODIFY/ISMENURENDER] + RoleCapabilities[BUSINESSADMIN]; code-based lookups, WHERE NOT EXISTS guards). NO schema change, NO migration (rides Program #51 S18–S20). No sett.Grids/Fields (card-list picker reuses PROGRAMS_QUERY).
- **Deviations from spec**: None material. Minor: source-ownership validator uses `Programs.SelectMany(p => p.FundingSources…)` because there is no `ProgramFundingSources` DbSet on `IApplicationDbContext`. Picker status-pill fallback color `#059669` is a null-fallback behind the DB-driven `statusColorHex` (data-driven inline color, accepted convention).
- **Known issues opened**: ISSUE-1 (runtime E2E pending BE build).
- **Known issues closed**: None.
- **Next step**: User builds BE + applies Program S18–S20 migration, runs `seed_program_fund_allocation_menu.sql`, then `/test-screen #177` for full CRUD/rehydrate verification.

### Session 2 — 2026-06-23 — FIX + ENHANCE — COMPLETED

- **Scope**: Two runtime fixes found on first open, plus the deferred "Phase 2" actual-money rollup (user-requested: show real Collected / Used / Available per source so allocation is grounded in real funds, not just the manual ledger).
- **Runtime fixes (FE-only, tsc can't catch)**:
  - `ProgramFundingAllocationQuery.ts` — query var `$programId: Int` → `Int!` (HC rejected nullable var in non-null arg location: *"variable is not compatible with the type of the current location"*). See [[feedback_fe_query_nullability_must_match_be]].
  - `program-fund-allocation-page.tsx` — wrapped workbench tree in `<FormProvider {...methods}>` (kept full `useForm` methods object). Canonical `Form*` field components use shadcn `useFormField`→`useFormContext()`, which was null without a provider → *"Cannot destructure property 'getFieldState' of useFormContext(...) as it is null."* Mirrors `program-form.tsx`.
- **Actual-money rollup (read-only, NO schema change)**:
  - BE `GetProgramFundingAllocation.cs` (modified) — after ledger rollups, computes per source: Grant → Collected = Σ `GrantStageHistory.AmountReceived` (received tranches), Used = Σ `GrantExpense.Amount`; Donation Purpose → Collected = Σ `PledgePayment.PaidAmount` (paid, non-cancelled) via `Pledge.DonationPurposeId`, Used = manual DRAWDOWN ledger (`TotalUsed`, no spend table links to a purpose); Available = Collected − Used. Grouped dictionary queries, no transaction (read-only).
  - BE `ProgramSchemas.cs` (modified) — `ProgramFundingSourceDto` gains `CollectedAmount` / `SpentAmount` / `AvailableAmount` (response-only).
  - FE `ProgramFundingAllocationQuery.ts` — select the 3 new fields.
  - FE `program-form-schemas.ts` — add the 3 read-only fields to `fundingSourceSchema`.
  - FE `program-fund-allocation-page.tsx` — map fields in `reset()`, add to `toRequest` discard list (response-only, never sent — see [[feedback_response_only_fields_leak_into_request]]), top strip gains **Total Collected** + **Total Available** (6-tile grid).
  - FE `program-funding-sources.tsx` — `FundingSourceCard` gains `showActualMoney` prop; in allocate mode renders an emerald real-money strip **Collected · Allocated · Used · Available** (ledger strip kept for form mode).
- **Deviations from spec**: "Used" for donation-purpose sources intentionally falls back to the manual ledger — no PSS table links real spend to a DonationPurpose (grants have `GrantExpenses`, purposes don't). User delegated the "Used" definition.
- **Known issues opened**: None.
- **Known issues closed**: None (ISSUE-1 still OPEN — full E2E still pending user BE build; now also covers verifying Collected/Used/Available against seeded grant tranches + pledge payments).
- **Next step**: User builds BE → applies Program S18–S20 migration → runs `seed_program_fund_allocation_menu.sql` → `/test-screen #177`.

### Session 3 — 2026-06-23 — ENHANCE — COMPLETED

- **Scope**: Allocation-health guardrails (user reasoned through the money invariants). Decided semantics: there are THREE distinct "remaining"s — Unallocated (Expected−Allocated), Remaining (Allocated−Used), Available (Collected−Used). User's "Allocated ≤ Available" was reframed: the hard cap belongs on *spend*, not allocation (forward-commitment against awarded funds is legitimate).
- **Rules implemented**:
  - **Over-spend (HARD BLOCK)**: a source's manual DRAWDOWN total may not exceed its **Collected** cash. BE `SaveProgramFundingAllocation.cs` validator rule (f) — resolves source→grant/purpose from DB by Id (GrantId/DonationPurposeId are stripped from request), computes Collected (grant tranches / paid pledge payments), rejects if Σ DRAWDOWN > Collected. FE `program-fund-allocation-page.tsx` mirrors it: `useWatch` over sources → disables Save + footer "{n} sources over-spent" + `handleSave` guard + per-card red error.
  - **Over-allocation (SOFT WARN)**: never blocks. Per-card chips in `program-funding-sources.tsx` (allocate mode): allocation-coverage vs Expected (annualized: MONTHLY×12) — Fully allocated / Under target $X/yr / Over target $X/yr; and amber "$X committed beyond collected" (forward-commitment).
- **Files touched**:
  - BE: `Base.Application/Business/CaseBusiness/Programs/SaveFundingAllocationCommand/SaveProgramFundingAllocation.cs` (modified — validator rule (f); collected-math duplicates the query handler's, watch for drift).
  - FE: `program-funding-sources.tsx` (modified — advisory computations + chips), `program-fund-allocation-page.tsx` (modified — overspend watch, Save disable, footer badge, handleSave guard).
- **Deviations from spec**: "Forward-committed" badge compares raw allocated vs collected (per-period vs cumulative) — intentional soft hint, not annualized, to stay simple. Coverage chip IS annualized.
- **Known issues opened**: None.
- **Known issues closed**: None (ISSUE-1 still OPEN — E2E should now also verify the over-spend block fires + advisories render).
- **Next step**: User builds BE → migration → seed → `/test-screen #177`.

### Session 4 — 2026-06-23 — RE-ARCHITECTURE (Spec change — user-authorized) — COMPLETED (⚠ needs BE build + migration by user)

- **Scope**: Full money-model redesign — the typed ledger (ALLOCATION/DRAWDOWN/ADJUSTMENT) was confusing (recorded spend twice). Replaced per [[project_fund_allocation_payment_log_redesign]]. User decisions: **manual** payment log + **program-level pool**. SUPERSEDES the S2 actual-money rollup and the S3 allocation-health guardrails (drawdown/over-spend/coverage chips all removed).
- **New model**:
  - Per funding source → a **Payment Log**: each row is one incoming payment = `amount` + `PaymentStatus` (**WAITING** / **TRANSFERRED**). `TransferredAmount` = Σ TRANSFERRED (real cash in); `PendingAmount` = Σ WAITING.
  - **Used** = Σ `BeneficiaryServiceLog.AmountCents` (this `ProgramId`) ÷ 100 — real money given to beneficiaries, logged in the Case Service Log, **program-level pool** (read-only here; cannot be edited on this screen).
  - Program totals: `TotalTransferred` (Σ sources), `TotalUsed` (Service Log), `TotalAvailable` = Transferred − Used. Per-source Used/Available removed (pool can't be split).
  - The disburse-cap guardrail moves OFF this screen → belongs on the Service Log save.
- **Files touched**:
  - BE (modified): `Base.Domain/.../ProgramFundingTransaction.cs` (TransactionType→**PaymentStatus**), `Base.Infrastructure/.../ProgramFundingTransactionConfiguration.cs`, `ProgramSchemas.cs` (DTOs: paymentStatus + transferred/pending + program TotalTransferred/Used/Available), `ProgramFundingMath.cs` (ApplyRollups → transferred/pending), `GetProgramFundingAllocation.cs` (dropped grant-tranche/pledge/expense queries; added `BeneficiaryServiceLogs` Used sum), `SaveProgramFundingAllocation.cs` (removed rule f + alloc-derive; rule e → WAITING/TRANSFERRED), `CreateProgram.cs` + `UpdateProgram.cs` (txn validator → WAITING/TRANSFERRED).
  - FE (modified): `ProgramFundingAllocationQuery.ts`, `ProgramQuery.ts` (program GetById funding fields), `program-form-schemas.ts`, `program-funding-sources.tsx` (payment-log UI), `program-fund-allocation-page.tsx` (top strip Expected·Transferred·Used·Available; removed overspend guard + toRequest), `program-form-page.tsx` (reset mapping).
- **Migration (user)**: rename `case.ProgramFundingTransaction.TransactionType` → `PaymentStatus` (string). `ProgramFundingSource.AllocatedAmount` column now unused (left in place — drop later if desired). No new seed (PaymentStatus is a plain string code, not MasterData).
- **Deviations from spec**: Service Log Used is program-level only — Service Log doesn't tag a funding source (per-source attribution = future work if a funder needs restricted-grant reporting). `AllocationFrequencyCode`/Start/End kept as source config (relabeled "Funding Start"); `AllocatedAmount` field dropped from the UI.
- **Known issues opened**: ISSUE-2 (OPEN) — `Used` reads 0 until Service Log has amount-bearing rows for the program; verify against a case with service-log disbursements.
- **Known issues closed**: None. (S2/S3 guardrail behavior intentionally removed — not a regression.)
- **Verification**: FE `npx tsc --noEmit` CLEAN (exit 0, full project). BE not built (user owns build).
- **Next step**: User builds BE → applies the rename migration → reopens `?programId=` → `/test-screen #177` (verify payment log save, Transferred/Pending per source, program Used from a service log with amounts).
