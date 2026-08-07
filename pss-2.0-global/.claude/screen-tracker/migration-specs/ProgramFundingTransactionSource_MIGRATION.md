# Migration spec — `case.ProgramFundingTransactionSource` (§⑮ R2 transfer source-tracking)

**Owner:** you (I never run `dotnet ef` / hand-author snapshots). I've built the entity + EF config + DbSet so
the model compiles (Base.API build: 0 errors); this is the migration to generate & apply.

## What changed in code
- NEW entity `Base.Domain.Models.CaseModels.ProgramFundingTransactionSource` (per-channel split of one transfer).
- NEW EF config `ProgramFundingTransactionSourceConfiguration` (auto-applied via `ApplyConfigurationsFromAssembly`).
- NEW nav on `ProgramFundingTransaction`: `ICollection<ProgramFundingTransactionSource>? Sources` (no column).
- DbSet `ProgramFundingTransactionSources` on `ICaseDbContext` + `ApplicationDbContext` (via `CaseDbContext`).

**Only ONE new table. No column added/removed on any existing table.**

## Generate
```
dotnet ef migrations add Add_ProgramFundingTransactionSource \
  -p <Base.Infrastructure csproj> -s <Base.API csproj>
```

## Expected shape (verify the generated `Up()` matches)
Table `case."ProgramFundingTransactionSource"`:

| Column                        | Type            | Notes                                           |
|-------------------------------|-----------------|-------------------------------------------------|
| `Id`                          | int identity    | PK (`UseIdentityAlwaysColumn`)                  |
| `ProgramFundingTransactionId` | int NOT NULL    | FK → `case."ProgramFundingTransaction"."Id"`, **ON DELETE CASCADE** |
| `SourceChannel`               | varchar(20)     | plain code: PLEDGE / ONLINE / CROWDFUND / GENERAL |
| `Amount`                      | numeric(18,2)   |                                                 |
| `CreatedBy`                   | int NULL        | Entity base                                     |
| `CreatedDate`                 | timestamptz NULL| Entity base                                     |
| `ModifiedBy`                  | int NULL        | Entity base                                     |
| `ModifiedDate`                | timestamptz NULL| Entity base                                     |
| `IsActive`                    | bool NULL       | Entity base                                     |
| `IsDeleted`                   | bool NULL       | Entity base                                     |

Index: `IX_ProgramFundingTransactionSource_ProgramFundingTransactionId`.

The migration should contain **only** this `CreateTable` + FK + index — nothing touching other tables.
If EF tries to alter unrelated tables, stop and tell me (model drift to reconcile first).

## Apply
```
dotnet ef database update -p <Base.Infrastructure csproj> -s <Base.API csproj>
```

## No seed required
Source channels are plain codes hard-coded in `TransferSourceChannel` (BE) + `CHANNELS` (FE modal) — no MasterData
seed, mirroring `ProgramFundingTransaction.PaymentStatus`. (The §⑮ ISSUE-9 `UNITTYPE=DONATIONPURPOSE` seed +
node backfill is still separately required for the allocation loop itself — unrelated to this table.)
