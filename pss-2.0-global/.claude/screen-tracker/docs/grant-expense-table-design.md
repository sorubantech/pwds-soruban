# Grant Expense — Table Design & Change Specification

> **Companion to**: [grant-expense-feature-plan.md](grant-expense-feature-plan.md)
> **Screen**: Grant (#62) · Schema: `grant` (reuse — no new module bootstrap)
> **DB**: PostgreSQL (Npgsql). Identifiers double-quoted, schema-qualified.
> **Audience**: the developer building the Grant Expense sub-feature. Everything below is concrete enough to implement from.

---

## 1. New table — `grant.GrantExpenses`

One row = one expense/disbursement logged against a grant, optionally allocated to a budget line.

### 1.1 Column design

| Column | Type | Null | Default | Notes |
|--------|------|------|---------|-------|
| `GrantExpenseId` | `int` (identity, always) | NO | identity | PK |
| `GrantId` | `int` | NO | — | **FK → `grant.Grants.GrantId`**, ON DELETE **CASCADE** (expense dies with its grant) |
| `GrantBudgetLineId` | `int` | YES | NULL | **FK → `grant.GrantBudgetLines.GrantBudgetLineId`**, ON DELETE **SET NULL** (un-allocate if the line is removed). NULL = unallocated expense (still counts toward `Grant.TotalSpent`). |
| `ExpenseDate` | `timestamp` | NO | — | When the expense was incurred |
| `Amount` | `numeric(18,2)` | NO | — | Must be `> 0` (validator) |
| `Description` | `varchar(300)` | NO | — | What it was for |
| `Vendor` | `varchar(200)` | YES | NULL | Payee / supplier |
| `ReferenceNumber` | `varchar(100)` | YES | NULL | Invoice / voucher / PO number |
| `ReceiptUrl` | `varchar(500)` | YES | NULL | **SERVICE_PLACEHOLDER** — pasted URL only (no upload, ISSUE-2) |
| `Notes` | `varchar(500)` | YES | NULL | Free text |
| `CompanyId` | `int` | YES | NULL | Tenant (from `HttpContext`, **not** a form field) |
| `CreatedBy` | `int` | YES | NULL | audit (from `Entity` base) |
| `CreatedDate` | `timestamp` | YES | `now()` | audit |
| `ModifiedBy` | `int` | YES | NULL | audit |
| `ModifiedDate` | `timestamp` | YES | NULL | audit |
| `IsActive` | `bool` | YES | `true` | audit |
| `IsDeleted` | `bool` | YES | `false` | soft delete |

> Audit + `IsActive`/`IsDeleted` come automatically from `Base.Domain.Abstractions.Entity` — do **not** redeclare them on the entity class.

### 1.2 Relationships

```
grant.Grants (1) ─────< (N) grant.GrantExpenses        [GrantId, CASCADE]
grant.GrantBudgetLines (1) ──< (0..N) grant.GrantExpenses   [GrantBudgetLineId, SET NULL, nullable]
app.Companies (1) ──< (N) grant.GrantExpenses          [CompanyId]
```

### 1.3 Indexes

| Index | Columns | Purpose |
|-------|---------|---------|
| PK | `GrantExpenseId` | identity |
| IX_GrantExpenses_GrantId | `GrantId` | load a grant's expenses |
| IX_GrantExpenses_GrantBudgetLineId | `GrantBudgetLineId` | per-line roll-up |
| IX_GrantExpenses_CompanyId | `CompanyId` | tenant scoping |

### 1.4 Entity class (mirror of sibling `GrantBudgetLine` / `GrantReportFinancialLine`)

`Pss2.0_Backend/.../Base.Domain/Models/GrantModels/GrantExpense.cs`

```csharp
namespace Base.Domain.Models.GrantModels;

[Table("GrantExpenses", Schema = "grant")]
public class GrantExpense : Entity
{
    public int GrantExpenseId { get; set; }
    public int GrantId { get; set; }
    public int? GrantBudgetLineId { get; set; }

    public DateTime ExpenseDate { get; set; }
    public decimal Amount { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? Vendor { get; set; }
    public string? ReferenceNumber { get; set; }
    public string? ReceiptUrl { get; set; }   // SERVICE_PLACEHOLDER — URL paste only
    public string? Notes { get; set; }

    public int? CompanyId { get; set; }

    // FK navigation
    public virtual Grant? Grant { get; set; }
    public virtual GrantBudgetLine? GrantBudgetLine { get; set; }
    public virtual Company? Company { get; set; }
}
```

### 1.5 EF configuration (mirror `GrantBudgetLineConfiguration`)

`Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/GrantConfigurations/GrantExpenseConfiguration.cs`

```csharp
namespace Base.Infrastructure.Data.Configurations.GrantConfigurations;

public class GrantExpenseConfiguration : IEntityTypeConfiguration<GrantExpense>
{
    public void Configure(EntityTypeBuilder<GrantExpense> builder)
    {
        builder.HasKey(c => c.GrantExpenseId);
        builder.Property(c => c.GrantExpenseId).UseIdentityAlwaysColumn().ValueGeneratedOnAdd();

        builder.Property(c => c.Amount).HasColumnType("numeric(18,2)");
        builder.Property(c => c.Description).HasMaxLength(300).IsRequired();
        builder.Property(c => c.Vendor).HasMaxLength(200);
        builder.Property(c => c.ReferenceNumber).HasMaxLength(100);
        builder.Property(c => c.ReceiptUrl).HasMaxLength(500);
        builder.Property(c => c.Notes).HasMaxLength(500);

        // FK: Grant (parent — CASCADE)
        builder.HasOne(o => o.Grant)
            .WithMany() // or add ICollection<GrantExpense> Expenses to Grant + .WithMany(g => g.Expenses)
            .HasForeignKey(o => o.GrantId)
            .OnDelete(DeleteBehavior.Cascade);

        // FK: GrantBudgetLine (allocation — SET NULL, nullable)
        builder.HasOne(o => o.GrantBudgetLine)
            .WithMany()
            .HasForeignKey(o => o.GrantBudgetLineId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(o => o.GrantId);
        builder.HasIndex(o => o.GrantBudgetLineId);
        builder.HasIndex(o => o.CompanyId);
    }
}
```

> Recommended: add `public virtual ICollection<GrantExpense>? Expenses { get; set; }` to `Grant.cs` so `GetGrantById` can `.Include(g => g.Expenses)` for the Budget tab, and use `.WithMany(g => g.Expenses)` above.

---

## 2. Existing columns this feature finally activates

No schema change to these — they already exist and are currently always 0:

| Column | File | Maintained by |
|--------|------|---------------|
| `Grant.TotalSpent` `decimal` | [Grant.cs:49](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/GrantModels/Grant.cs) | Create/Delete expense commands (+= / -= Amount) |
| `GrantBudgetLine.SpentAmount` `decimal` | [GrantBudgetLine.cs:12](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/GrantModels/GrantBudgetLine.cs) | Create/Delete commands when `GrantBudgetLineId` is set |

> `Grant.ComplianceRate` is **NOT** touched here (reporting metric, owned by #63).

---

## 3. Roll-up logic (must be transactional)

### CreateGrantExpense
```
1. Insert GrantExpense (CompanyId from HttpContext).
2. Grant.TotalSpent += Amount.
3. if GrantBudgetLineId != null: budgetLine.SpentAmount += Amount.
4. SaveChanges.
```

### DeleteGrantExpense (soft)
```
1. Load expense (tenant-scoped, not already deleted).
2. Grant.TotalSpent -= Amount.
3. if GrantBudgetLineId != null: budgetLine.SpentAmount -= Amount.
4. expense.IsDeleted = true.
5. SaveChanges.
```

⚠ **PostgreSQL / Npgsql retrying execution strategy**: if you open an explicit transaction around steps 1–4, you MUST wrap it:
```csharp
var strategy = _db.Database.CreateExecutionStrategy();
await strategy.ExecuteAsync(async () =>
{
    await using var tx = await _db.Database.BeginTransactionAsync(ct);
    // ... mutations ...
    await _db.SaveChangesAsync(ct);
    await tx.CommitAsync(ct);
});
```
(A single `SaveChangesAsync` is already atomic, so an explicit transaction is only needed if you split the work — but the wrapper rule applies whenever you call `BeginTransactionAsync`. See project memory `reference_npgsql_execution_strategy_transactions`.)

---

## 4. DTOs (append to existing `Base.Application/Schemas/GrantSchemas/GrantSchemas.cs`)

```csharp
public class GrantExpenseRequestDto
{
    public int GrantExpenseId { get; set; }       // 0 on create
    public int GrantId { get; set; }
    public int? GrantBudgetLineId { get; set; }
    public DateTime ExpenseDate { get; set; }
    public decimal Amount { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? Vendor { get; set; }
    public string? ReferenceNumber { get; set; }
    public string? ReceiptUrl { get; set; }
    public string? Notes { get; set; }
}

public class GrantExpenseResponseDto
{
    public int GrantExpenseId { get; set; }
    public int GrantId { get; set; }
    public int? GrantBudgetLineId { get; set; }
    public string? BudgetLineCategory { get; set; }   // joined from GrantBudgetLine.Category for display
    public DateTime ExpenseDate { get; set; }
    public decimal Amount { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? Vendor { get; set; }
    public string? ReferenceNumber { get; set; }
    public string? ReceiptUrl { get; set; }
    public string? Notes { get; set; }
}
```
Add `public List<GrantExpenseResponseDto>? Expenses { get; set; }` to **`GrantResponseDto`** so the Budget tab gets them from `GetGrantById`. Add Mapster configs in `GrantMappings.cs` (mirror the `GrantBudgetLine` block — `Ignore(dest => dest.Grant!)` / `dest.GrantBudgetLine!` on the request→entity map).

---

## 5. GraphQL contract

### Mutations (append to `Base.API/EndPoints/Grant/Mutations/GrantMutations.cs`)

| Mutation | Arg | Returns | Authorize |
|----------|-----|---------|-----------|
| `createGrantExpense` | `GrantExpenseRequestDto input` | `BaseApiResponse<int>` (new id) | `DecoratorGrantModules.Grant` + Modify |
| `deleteGrantExpense` | `int grantExpenseId` | `BaseApiResponse<bool>` | `DecoratorGrantModules.Grant` + Modify |

> HotChocolate naming: method `CreateGrantExpense(GrantExpenseRequestDto input)` → GQL field `createGrantExpense(input: …)`. `BaseApiResponse<int>` exposes a **bare `data: Int!`** — FE selects `data`, not `data { … }` (project memory `feedback_baseapiresponse_int_scalar_data`). Input type name keeps the `Dto` suffix: `GrantExpenseRequestDtoInput!`.

### Query change
Extend the existing `GET_GRANT_BY_ID_QUERY` to select the new child collection:
```graphql
expenses {
  grantExpenseId
  grantBudgetLineId
  budgetLineCategory
  expenseDate
  amount
  description
  vendor
  referenceNumber
  receiptUrl
}
```
No new query endpoint in V1 (decision D3 in the plan).

---

## 6. Backend file change list

| Action | File |
|--------|------|
| CREATE | `Base.Domain/Models/GrantModels/GrantExpense.cs` |
| CREATE | `Base.Infrastructure/Data/Configurations/GrantConfigurations/GrantExpenseConfiguration.cs` |
| CREATE | `Base.Application/Business/GrantBusiness/Grants/CreateCommand/CreateGrantExpense.cs` (+ validator) |
| CREATE | `Base.Application/Business/GrantBusiness/Grants/DeleteCommand/DeleteGrantExpense.cs` (+ validator) |
| MODIFY | `Base.Application/Schemas/GrantSchemas/GrantSchemas.cs` — 2 DTOs + `Expenses` on `GrantResponseDto` |
| MODIFY | `Base.Application/Mappings/GrantMappings.cs` — GrantExpense Mapster configs |
| MODIFY | `Base.Domain/Models/GrantModels/Grant.cs` — add `ICollection<GrantExpense>? Expenses` nav |
| MODIFY | `Base.Application/Data/Persistence/IGrantDbContext.cs` — `DbSet<GrantExpense> GrantExpenses` (at `//IGrantDbContextLines` marker) |
| MODIFY | `Base.Infrastructure/Data/Persistence/GrantDbContext.cs` — `DbSet<GrantExpense> GrantExpenses => Set<GrantExpense>();` |
| MODIFY | `Base.Application/Extensions/DecoratorProperties.cs` — add `GrantExpense = "GRANTEXPENSE"` to `DecoratorGrantModules` |
| MODIFY | `Base.API/EndPoints/Grant/Mutations/GrantMutations.cs` — `createGrantExpense` + `deleteGrantExpense` |
| MODIFY | `Base.Application/Business/GrantBusiness/.../GetByIdQuery/GetGrantById.cs` — `.Include(g => g.Expenses).ThenInclude(e => e.GrantBudgetLine)` + project to DTO |
| MODIFY | GlobalUsings (Application) — add `global using …GrantBusiness.Grants.CreateCommand;`/`.DeleteCommand;` if a new namespace is introduced |
| MANUAL | `dotnet ef migrations add Add_GrantExpense` — **developer runs this**, not the agent |

---

## 7. Frontend file change list

| Action | File |
|--------|------|
| MODIFY | `src/domain/entities/grant-service/GrantDto.ts` — `GrantExpenseDto`, `GrantExpenseRequest`, add `expenses?: GrantExpenseDto[]` to the grant graph type |
| MODIFY | `src/infrastructure/gql-mutations/grant-mutations/GrantMutation.ts` — `CREATE_GRANT_EXPENSE`, `DELETE_GRANT_EXPENSE` |
| MODIFY | `src/infrastructure/gql-queries/grant-queries/GrantQuery.ts` — add `expenses { … }` to `GET_GRANT_BY_ID_QUERY` |
| CREATE | `.../crm/grant/grantlist/grant/add-expense-modal.tsx` — RHF + Zod (Amount, ExpenseDate, BudgetLine select, Vendor, Description, ReceiptUrl, Notes) |
| MODIFY | `.../crm/grant/grantlist/grant/grant-detail.tsx` — wire **both** Add Expense buttons (~line 167 header, ~line 748 Budget tab) to open the modal; remove the misleading toast; render an **expense list** under the Budget Breakdown table with Delete |

> FE form fields must use the canonical `FormInput` / `FormSelect` / `FormDatePicker` (project memory `feedback_reuse_canonical_form_fields`). The budget-line `<select>` is populated from the grant graph's `budgetLines` already in context — no extra fetch.

---

## 8. DB seed (`sql-scripts-dyanmic/Grant-sqlscripts.sql`)

V1 needs **no** new menu and **no** new MasterDataType (allocation replaces a category taxonomy). The only optional addition is a permission code **if** you want expense actions gated separately from grant edit:

```sql
-- OPTIONAL — only if expense gets its own permission instead of riding GRANT/MODIFY.
-- Otherwise: no seed change required for this feature.
```

Keep the file **idempotent** (`WHERE NOT EXISTS`) and preserve the `sql-scripts-dyanmic` folder typo.

---

## 9. Test checklist (post-build)

- [ ] `dotnet build` clean; migration applies; `grant."GrantExpenses"` table exists with the 4 indexes.
- [ ] Create expense allocated to a budget line → that line's Spent ↑, Remaining ↓, progress bar moves; Total row + `Grant.TotalSpent` update on refetch.
- [ ] Create unallocated expense → `Grant.TotalSpent` ↑, no line's Spent changes.
- [ ] Delete expense → all roll-ups reverse exactly.
- [ ] Both Add Expense buttons open the modal; old toast gone.
- [ ] Receipt URL persists; no upload attempted.
- [ ] Tenant isolation: a second company can't see/delete the first's expenses.
- [ ] `pnpm tsc --noEmit` clean on changed FE files.
