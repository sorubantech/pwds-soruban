# Migration Spec — Add_Grant_And_ProgramTransaction_FxColumns

Owner: USER (per project policy, migrations are strictly user-owned — this agent does NOT run
`dotnet ef migrations add` / `database update` / `remove`, and did NOT hand-author a migration
file or edit the ModelSnapshot).

## Why

WI-3 (Grant module bugfix pass) — grant financial rollups (`GetGrantFinancialSummary`,
`GetGrantUtilization`, `GetGrantFundingRequests`, `CreateGrantExpense`,
`AllocateGrantToFundingSource`) sum raw `Amount` across `GrantFundReceipt` and
`ProgramFundingTransaction`, both of which can carry a `CurrencyId` different from the owning
`Grant.CurrencyId`. That silently mixes currencies in a single SUM. The fix snapshots a
converted-to-grant-currency amount at WRITE time (mirroring the existing
`GlobalDonation.BaseCurrencyAmount` precedent) and sums the snapshot column (falling back to raw
`Amount` via `COALESCE`/`??` when the snapshot is null — same-currency rows, or an FX-rate miss).

## Columns to add

### 1. `grant."GrantFundReceipts"`

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `ExchangeRate` | `numeric(18,6)` | YES | Direct-pair rate from the receipt's `CurrencyId` code to the grant's `CurrencyId` code, as of `ReceivedDate`. NULL when same-currency or FX rate unavailable. |
| `GrantCurrencyAmount` | `numeric(18,2)` | YES | `Amount * ExchangeRate`, rounded to 2dp. NULL under the same conditions as `ExchangeRate`. |

Entity: `Base.Domain/Models/GrantModels/GrantFundReceipt.cs`
EF config: `Base.Infrastructure/Data/Configurations/GrantConfigurations/GrantFundReceiptConfiguration.cs`

### 2. `case."ProgramFundingTransaction"`

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `ExchangeRate` | `numeric(18,6)` | YES | Direct-pair rate from the transaction's `CurrencyId` code to the owning Grant's `CurrencyId` code (via `FundingSource.GrantId`), as of `TransactionDate`. NULL when same-currency or FX rate unavailable. |
| `GrantCurrencyAmount` | `numeric(18,2)` | YES | `Amount * ExchangeRate`, rounded to 2dp. NULL under the same conditions as `ExchangeRate`. |

Entity: `Base.Domain/Models/CaseModels/ProgramFundingTransaction.cs`
EF config: `Base.Infrastructure/Data/Configurations/CaseConfigurations/ProgramFundingTransactionConfiguration.cs`

Both columns on both tables are **nullable** — no backfill is required. Existing rows will simply
read as NULL and rollups fall back to raw `Amount` (`x.GrantCurrencyAmount ?? x.Amount`), which is
correct for same-currency historical data and a documented no-worse-than-today state for
historical cross-currency rows (they predate this fix and were already being summed unconverted).

## Suggested migration name

```
AddGrantAndProgramTransactionFxColumns
```

## Commands for the user to run

From the `Base.Infrastructure` (or wherever migrations are currently added from — check existing
migration folder) project directory, with `Base.API` as the startup project (adjust paths/project
names to match how prior Grant migrations were generated in this repo):

```bash
dotnet ef migrations add AddGrantAndProgramTransactionFxColumns \
  --project Base.Infrastructure \
  --startup-project Base.API \
  --context <YourApplicationDbContextName>

dotnet ef database update \
  --project Base.Infrastructure \
  --startup-project Base.API \
  --context <YourApplicationDbContextName>
```

Verify the generated migration only adds the 4 nullable columns listed above (2 per table) with
no unexpected drops/renames from unrelated model drift before applying.

## Post-migration seed / backfill

None required — both new columns are nullable and all consuming LINQ (`GetGrantFinancialSummary`,
`GetGrantUtilization`, `GetGrantFundingRequests`, `CreateGrantExpense`,
`AllocateGrantToFundingSource`, `RecordProgramFundingTransfer`) already coalesce to the raw
`Amount` column, so existing data keeps behaving exactly as it does today until new
cross-currency rows are written.

## Known gap (not in scope for this pass)

`UpdateGrantFundReceipt.cs` / `VoidGrantFundReceipt.cs` do not re-snapshot `ExchangeRate` /
`GrantCurrencyAmount` if a receipt's `Amount` or `CurrencyId` is edited after creation — only the
Create path (`CreateGrantFundReceipt.cs`) and the transfer-record path
(`RecordProgramFundingTransfer.cs`) snapshot. If Update ever allows changing Amount/CurrencyId on
an existing receipt, a follow-up should re-run the snapshot there too. Flagging this rather than
silently expanding WI-3's scope.
