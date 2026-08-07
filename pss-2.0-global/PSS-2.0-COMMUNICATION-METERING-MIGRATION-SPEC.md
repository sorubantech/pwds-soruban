# PSS 2.0 — Communication Metering Migration Spec

> **Status:** SPEC ONLY — the migration has **not** been created. Written 2026-08-05.
> **Owner:** the user. Nobody else runs `dotnet ef migrations add` / `remove` / `database update`.
> **Implements:** `PSS-2.0-COMMUNICATION-METERING-BUILD-PROMPT.md` §③.1
> **Migration name:** `Add_EmailProviderOwnership`
> **Must be applied AFTER:** `20260729062510_Add_PlatformCommunicationProvider`

---

## ① What to run

From the backend solution directory, with the API as the startup project:

```
dotnet ef migrations add Add_EmailProviderOwnership
dotnet ef database update
```

The entity property and the EF configuration line are **already written and committed** — see §③.
The scaffolder therefore has everything it needs; nothing in the generated file should be hand-edited.

---

## ② The whole change: one column

**Table:** `notify."CompanyEmailProviders"`

| Column | Type | Null | Default | Meaning |
|---|---|---|---|---|
| `IsPlatformProvider` | `boolean` | NOT NULL | `false` | `true` = this row sends on **our** infrastructure (the platform sender, PROMPT-08). `false` = the tenant's own account (BYO). |

Expected `Up()`:

```csharp
migrationBuilder.AddColumn<bool>(
    name: "IsPlatformProvider",
    schema: "notify",
    table: "CompanyEmailProviders",
    type: "boolean",
    nullable: false,
    defaultValue: false);
```

### Why the column exists

There are two meters, and this flag is the only thing that can tell them apart at send time:

- `EMAILS` — the **value** meter. Every email the tenant sends, BYO or ours. This is what the plan sells.
- `EMAILS_PLATFORM` — the **cost** meter. Only the subset that goes out on our infrastructure, which we pay a provider for.

A platform-sent email increments **both** — as well as, never instead of — so `EMAILS_PLATFORM ≤ EMAILS` holds by construction. Without this column the second meter cannot be measured at all, because at Hook B the sender only knows which `CompanyEmailProvider` row it resolved, not who owns the account behind it.

---

## ③ Code already on disk (do not re-add)

| File | Change |
|---|---|
| `Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs:41` | `public bool IsPlatformProvider { get; set; }` — immediately after `IsDefault` |
| `Base.Infrastructure/…/CompanyEmailProviderConfigurations.cs:57-59` | `builder.Property(x => x.IsPlatformProvider).HasDefaultValue(false);` |

If the scaffolder produces a migration that touches anything **other** than this one column, stop: something unrelated is uncommitted in the model, and it must not ride along in this migration.

---

## ④ Backfill: none

Every existing row is BYO by definition — the platform sender did not exist before PROMPT-08 — so `false` is the correct value for all of them, and the `NOT NULL DEFAULT false` handles it in the same statement. **No data script.**

The one row that *should* be `true` is the platform provider itself, wherever PROMPT-08's own seed created it. Flip that row deliberately, after the migration, once you have confirmed which row it is:

```sql
-- inspect first; do not run blind
SELECT "CompanyEmailProviderId","CompanyId","ProviderName","IsDefault","IsPlatformProvider"
FROM notify."CompanyEmailProviders" ORDER BY "CompanyId";
```

Until that flip happens, platform-sent mail meters as BYO: `EMAILS` is correct, `EMAILS_PLATFORM` under-reports. That is the safe direction to be wrong in — nothing over-blocks — but it is a known gap (prompt §⑨ Q4) and `EMAILS_PLATFORM` figures should not be trusted for COGS until the cutover is done.

---

## ⑤ What is deliberately **not** in this migration

- **No new tables.** `billing."PlanQuotas"` and `billing."UsageCounters"` already exist and are sufficient. The 80%/95% warning's once-per-period dedup flag is a synthetic `UsageCounters` row (`EMAILS#W80`) riding the existing `UNIQUE (CompanyId, MeterCode, PeriodStart)` index — no table, no column.
- **No add-on-pack tables** (`AddOnPackCatalog` / `AddOnPackPrices` / `CompanyAddOnPacks`). Packs are out of scope.
- **No index changes.**
- **No column on `EmailSendJob`.** `IsSystem` already exists (`EmailSendJob.cs:22`).
- **No `billing.PlanEntitlement` change.** This release writes `PlanQuotas` only; `CHANNEL:EMAIL` already gates.

---

## ⑥ Ordering, safety, rollback

Additive, defaulted, non-breaking, and **safe to apply before the code deploys** — old code simply ignores a column it does not know about. There is no window in which the schema and the running binary disagree destructively.

Run order:

1. `dotnet ef migrations add Add_EmailProviderOwnership` + `dotnet ef database update`
2. `sql-scripts-dyanmic/billing-communication-quota-seed.sql` — **required before the code is live.** A missing `PlanQuota` row resolves to `0`, which is a hard block, so deploying the new meter codes without this seed blocks every tenant on any plan that lacks a row.
3. Deploy the code.
4. Flip `IsPlatformProvider = true` on the platform sender row (§④).

Rollback is `DROP COLUMN` — no data loss beyond the flag itself, which is re-derivable from which provider row is the platform sender.
