# Grant Expense Logging — Feature Plan (Change Request)

> **Screen**: Grant (#62) — `grant` schema, CRM module
> **Type of change**: NEW sub-feature + NEW entity (schema change) — this is a **Spec change**, not a `/continue-screen` fix.
> **Author**: handoff doc for the developer who built #62/#63.
> **Date raised**: 2026-06-12
> **Companion doc**: [grant-expense-table-design.md](grant-expense-table-design.md) — full table design + per-file change list + GraphQL contract.
> **Closes**: ISSUE-1 (Add Expense placeholder), ISSUE-6 (cached `TotalSpent` stays 0).

---

## 1. Problem / Why

On the Grant **DETAIL** view, the **"Add Expense"** button currently does nothing real — it fires a static toast:

```tsx
// grant-detail.tsx — TWO occurrences (line ~167 header, line ~748 Budget tab footer)
onClick={() => toast.info("Expense logging will be enabled when Grant Reports module (#63) is wired")}
```

Two problems:

1. **The message is misleading.** Expense logging was never actually gated on GrantReport (#63). #63 *is* built. The real blocker is that the **`GrantExpense` table was never created** — it was mentioned in #62 planning (ISSUE-1/6) but deferred and never picked up.
2. **The Budget tab is dead.** [grant-detail.tsx:660-744](../../..//PSS_2.0_Frontend/src/presentation/components/page-components/crm/grant/grantlist/grant/grant-detail.tsx) already renders a full **Budget Breakdown** table with per-line **Spent / Remaining / % Used / progress bar**, reading `budgetLine.spentAmount`. But nothing ever writes to `GrantBudgetLine.SpentAmount`, so every grant shows **Spent: $0**. Likewise `Grant.TotalSpent` (cached column, already in the entity) is always 0.

The schema was built **expecting** expenses — the cached columns already exist and are unused:

| Existing column | File | Today | After this feature |
|---|---|---|---|
| `Grant.TotalSpent` (`decimal`) | [Grant.cs:49](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/GrantModels/Grant.cs) | always `0` | sum of grant's expenses |
| `GrantBudgetLine.SpentAmount` (`decimal`) | [GrantBudgetLine.cs:12](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/GrantModels/GrantBudgetLine.cs) | always `0` | sum of expenses allocated to that line |

So this feature is **additive and low-risk**: build the missing write-path; the read/display UI mostly already exists.

---

## 2. Scope

### In scope
- New entity **`grant.GrantExpenses`** (one expense = one line item logged against a grant, optionally allocated to a budget line).
- BE CQRS: **Create** + **Delete** expense commands (each transactionally maintains the cached `SpentAmount` / `TotalSpent` roll-ups), plus expense rows surfaced through the existing **GetGrantById** graph for the Budget tab.
- FE **Add Expense modal** (amount, date, budget-line picker, vendor, description) wired into the two existing buttons; an **expense list** under the Budget Breakdown table; live Spent/Remaining now populated from real data.
- DB seed: register the new entity's menu-decorator/permission only if a sub-permission is desired (otherwise it rides the Grant MODIFY permission — see §5). No new menu row.

### Out of scope (explicitly deferred)
- **Receipt file upload** — file-upload infra is still absent (ISSUE-2). The modal accepts a **URL paste** into `ReceiptUrl` as a fallback; no multipart/CDN. Keep as SERVICE_PLACEHOLDER.
- **`Grant.ComplianceRate`** — this is a *reporting-timeliness* metric owned by GrantReport (#63), **not** an expense metric. Do **not** touch it here. (Keeps ISSUE-6 scoped to `TotalSpent` only.)
- **Edit-expense** — V1 is Create + Delete only (delete then re-add to correct a mistake). Mirrors how budget lines were scoped.
- **Burn-Down chart** on the Budget tab stays a placeholder (separate ISSUE — needs charting lib decision).
- **Expense approval workflow** — expenses are logged, not routed for approval. Future.

---

## 3. Key design decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Expense **allocates to a budget line** (`GrantBudgetLineId`, nullable) rather than carrying its own category string | The Budget tab is organized by budget line; allocating lets `SpentAmount` roll up per line with zero new category taxonomy. Nullable so an unallocated expense still counts toward `Grant.TotalSpent`. |
| D2 | Cached roll-ups (`SpentAmount`, `TotalSpent`) maintained **transactionally inside Create/Delete commands** | Matches ISSUE-6 MVP guidance and the existing pattern; avoids triggers. **PostgreSQL + Npgsql retrying strategy**: any explicit transaction must be wrapped in `CreateExecutionStrategy().ExecuteAsync(...)` — see project memory `reference_npgsql_execution_strategy_transactions`. |
| D3 | **No `GrantExpense` GraphQL query of its own** in V1 | Expenses are returned as a child collection inside the existing `GetGrantById` graph (Budget tab already fetches the full grant). One fewer endpoint to wire. Add a dedicated paged query later if volume demands. |
| D4 | Receipt = **URL string only** | File-upload infra absent (ISSUE-2). Same fallback as Attachments. |
| D5 | Soft delete (`IsDeleted`) like every other entity | `Entity` base class provides it; Delete command reverses the roll-up before flagging. |
| D6 | New `DecoratorGrantModules.GrantExpense = "GRANTEXPENSE"` constant added | Consistency with the 9 existing grant decorators; used by mutation `[CustomAuthorize]`. |

---

## 4. Work breakdown (summary — see companion doc for the per-file detail)

**Backend** (`grant` schema reuse — NO new bootstrap):
- 1 new entity `GrantExpense.cs` + 1 EF config `GrantExpenseConfiguration.cs`
- 2 commands: `CreateGrantExpense`, `DeleteGrantExpense` (+ validators)
- DTOs: `GrantExpenseRequestDto` / `GrantExpenseResponseDto` (in existing `GrantSchemas.cs`)
- Surface expense list inside `GetGrantById` projection (add `Expenses` collection to `GrantResponseDto`)
- 2 endpoints appended to existing `GrantMutations.cs` (`createGrantExpense`, `deleteGrantExpense`)
- Wiring: `IGrantDbContext` DbSet (at `//IGrantDbContextLines` marker), `GrantDbContext` DbSet, `GrantMappings`, `DecoratorGrantModules` constant, GlobalUsings for the new command namespaces
- **Migration**: developer runs `dotnet ef migrations add Add_GrantExpense` manually (per project rule — agents never run migrations)

**Frontend**:
- DTO additions in `GrantDto.ts` (`GrantExpenseDto`, request type, `expenses` on the grant graph)
- GQL: `CREATE_GRANT_EXPENSE` + `DELETE_GRANT_EXPENSE` mutations in `GrantMutation.ts`; add `expenses { … }` to `GET_GRANT_BY_ID_QUERY`
- New `add-expense-modal.tsx` (RHF + Zod): Amount, ExpenseDate, BudgetLine select, Vendor, Description, ReceiptUrl
- Wire both Add Expense buttons (`grant-detail.tsx` ~167, ~748) to open the modal
- Render an **expense list** below the Budget Breakdown table (date / category / vendor / amount / delete)
- The per-line Spent/Remaining and `Grant.TotalSpent` light up automatically once data flows

**DB seed** (`Grant-sqlscripts.sql`, append idempotently):
- (Optional) `MenuCapabilities` / `RoleCapabilities` row only if expense gets its own permission code; otherwise rides `GRANT` MODIFY.
- No new menu, no new MasterDataType required (allocation replaces a category taxonomy — see D1).

---

## 5. Permissions

V1: expense Create/Delete ride the existing **`GRANT` / MODIFY** permission (logging an expense is editing the grant). The mutations decorate with the Grant module's Modify permission — no new menu row, no new RoleCapability. If finance-team segregation is needed later, add a dedicated `GRANTEXPENSE` capability then.

---

## 6. Acceptance criteria

- [ ] On DETAIL → Budget tab, **Add Expense** opens a modal (both header + footer buttons).
- [ ] Saving an expense allocated to a budget line increases that line's **Spent** and reduces **Remaining**; the progress bar moves; the **Total** row and the grant's `TotalSpent` update after refetch.
- [ ] An expense list appears under Budget Breakdown with a working **Delete** (reverses the roll-up).
- [ ] An **unallocated** expense (no budget line) still counts toward `Grant.TotalSpent` but no single line's Spent.
- [ ] The misleading toast is **gone** (both occurrences).
- [ ] Receipt accepts a pasted URL; no upload attempted (SERVICE_PLACEHOLDER preserved).
- [ ] `dotnet build` passes; migration applies; `pnpm tsc --noEmit` passes on new FE files.

---

## 7. Risks / notes

- **Npgsql retrying strategy** forbids manual `BeginTransactionAsync` — wrap the roll-up update in `db.Database.CreateExecutionStrategy().ExecuteAsync(...)`. (Project memory: this exact class of bug already bit #48.)
- **Concurrent expenses on the same budget line** could race the cached `SpentAmount`. MVP: accept it (low write contention, same posture as `GrantCode` gen / ISSUE-7). Harden with a re-read-and-recompute inside the execution strategy if contention emerges.
- **Stale roll-ups from legacy data**: none — there are no expenses today, so all roll-ups start correct at 0.
- This change **edits shared wiring files** (`GrantMutations.cs`, `IGrantDbContext.cs`, `GrantDbContext.cs`, `GrantMappings.cs`, `DecoratorProperties.cs`, GlobalUsings, `GrantDto.ts`, `GrantMutation.ts`, `GrantQuery.ts`). Coordinate so a parallel grant session doesn't collide.

---

## 8. How to proceed

This is a Spec change, so the canonical path is:

1. `/plan-screens #62` — fold the GrantExpense entity into the prompt's Section ② (entities), ⑥ (Budget tab UX), ⑧ (file manifest), and the FK table; this companion design doc is the input.
2. `/build-screen #62` — build the additive surface (no re-build of the existing screen; targeted add).
3. Developer runs the EF migration manually.

The two docs in this folder are the shareable handoff for that work.
