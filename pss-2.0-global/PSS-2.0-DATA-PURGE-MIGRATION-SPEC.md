# PSS 2.0 — Data Purge · Migration Spec

**Status:** written by the agent, **NOT applied**. You author and run the migration.
**Source of truth:** `Base.Domain/Models/OpsModels/DataPurgeRequest.cs` +
`Base.Infrastructure/Data/Configurations/OpsConfigurations/DataPurgeRequestConfiguration.cs`.
Both are already committed to the tree, so `dotnet ef migrations add` will pick this up with no
further edits.

---

## 1. Scope of this migration

**One new table: `ops.DataPurgeRequests`.** Nothing else.

No column is added to, altered on, or dropped from any existing table.

### Why `Company.Status` is NOT touched

The soft-delete path writes `Company.Status = 'DELETED'`. That needs no schema change:

> `Base.Infrastructure/Data/Configurations/.../CompanyConfiguration.cs:55`
> `builder.Property(c => c.Status).HasMaxLength(20);`

Plain `varchar(20)` — no `CHECK` constraint, no Postgres `enum` type, and `Company.Status` is a
`string?` on the entity. `'DELETED'` (7 chars) fits inside the existing column as-is. Confirmed by
reading the configuration, not assumed.

---

## 2. Command to run (yours to execute)

From `PSS_2.0_Backend/PeopleServe/Services/Base/`:

```bash
dotnet ef migrations add AddDataPurgeRequests \
  --project Base.Infrastructure \
  --startup-project Base.API \
  --context ApplicationDbContext

# review the generated Up()/Down() against §3 below, then:
dotnet ef database update --project Base.Infrastructure --startup-project Base.API
```

**Review gate before applying** — the generated `Up()` must contain **exactly one**
`CreateTable("DataPurgeRequests", schema: "ops", …)` and **two** `CreateIndex` calls. If it also
contains `AddColumn`, `AlterColumn` or `DropColumn` on any other table, the model has drifted from
the database for an unrelated reason; stop and reconcile that separately rather than shipping it
inside this migration.

---

## 3. Expected shape of the generated table

Schema `ops` already exists (`PlatformAuditLogs`, `Leads`, `TenantProvisioningRuns` live there), so
the migration should not emit `EnsureSchema`.

| Column | Postgres type | Null | Notes |
|---|---|---|---|
| `DataPurgeRequestId` | `integer` **GENERATED ALWAYS AS IDENTITY** | no | PK. `UseIdentityAlwaysColumn()` — matches every other `ops` table |
| `TargetType` | `character varying(20)` | no | `LEAD` \| `TENANT` |
| `TargetId` | `integer` | no | `ops.Leads.LeadId` or `app.Companies.CompanyId`. **NO FOREIGN KEY** |
| `TargetName` | `character varying(400)` | no | Snapshot of the name at soft-delete time |
| `Mode` | `character varying(10)` | no | `SOFT` \| `HARD` |
| `Status` | `character varying(20)` | no | `SOFT_DELETED` \| `RESTORED` \| `HARD_DELETED` |
| `CountsJson` | `text` | yes | Serialised `List<PurgeCountDto>` |
| `ManifestJson` | `text` | yes | Serialised manifest — per-table row ids + pre-delete `Company.Status` |
| `ManifestTruncated` | `boolean` | no | `DEFAULT false` |
| `Reason` | `character varying(2000)` | no | |
| `RestoreReason` | `character varying(2000)` | yes | |
| `HardDeleteReason` | `character varying(2000)` | yes | |
| `HardDeleteEligibleOn` | `timestamp with time zone` | no | |
| `RequestedByUserId` | `integer` | yes | |
| `RequestedByUserName` | `character varying(200)` | yes | Snapshot |
| `RequestedOn` | `timestamp with time zone` | no | |
| `RestoredByUserId` | `integer` | yes | |
| `RestoredByUserName` | `character varying(200)` | yes | |
| `RestoredOn` | `timestamp with time zone` | yes | |
| `HardDeletedByUserId` | `integer` | yes | |
| `HardDeletedByUserName` | `character varying(200)` | yes | |
| `HardDeletedOn` | `timestamp with time zone` | yes | |
| `IpAddress` | `character varying(64)` | yes | |
| `CreatedBy` | `integer` | yes | base `Entity` |
| `CreatedDate` | `timestamp with time zone` | yes | base `Entity` |
| `ModifiedBy` | `integer` | yes | base `Entity` |
| `ModifiedDate` | `timestamp with time zone` | yes | base `Entity` |
| `IsActive` | `boolean` | yes | base `Entity` |
| `IsDeleted` | `boolean` | yes | base `Entity` |

### Indexes

| Name | Columns | Serves |
|---|---|---|
| `IX_DataPurgeRequests_TargetType_TargetId` | `(TargetType, TargetId)` | "has this lead/tenant been purged before?" — every preview, both list tabs |
| `IX_DataPurgeRequests_Status_HardDeleteEligibleOn` | `(Status, HardDeleteEligibleOn)` | the *Recently deleted* tab / eligibility scan |

---

## 4. Two things the generated migration must NOT contain

These are the whole design, not preferences. If the generated file has either, the entity or the
configuration has been edited wrongly — fix the C# and regenerate rather than hand-patching the
migration.

1. **No `CompanyId` column.** The global tenant query filter attaches *by convention* to any entity
   that has a `CompanyId` property (`ApplicationDbContext.cs:64` iterates
   `builder.Model.GetEntityTypes()`), and `TenantSaveChangesInterceptor` would stamp it. A purge row
   carrying a `CompanyId` would become invisible to the platform operator who wrote it — and, for a
   tenant purge, invisible precisely because the tenant it names was deleted. Same rule, same reason
   as `ops.PlatformAuditLogs`. Every read of this table therefore uses `IgnoreQueryFilters()` **plus**
   an explicit `IsDeleted != true`.

2. **No foreign key on `TargetId`.** The row exists to outlive its target. An FK would either block
   the hard delete outright or cascade the only surviving evidence of it away. `TargetId` is an
   `int` and stays an `int`; `TargetName` is the human-readable snapshot that replaces the join.

The purge row is **never deleted** — not on restore, not on hard delete.

---

## 5. Rollback

`Down()` drops the table. Because nothing references it and nothing else was altered, rollback is
clean and loses only the purge history itself.

---

## 6. Companion seeds (also user-applied, not run by the agent)

Apply **after** the migration, then **restart the API** — platform settings are cached per request
against a scoped service and the capability/menu cache is warmed at startup.

| File | What it seeds |
|---|---|
| `sql-scripts-dyanmic/platform-purge-retention-seed.sql` | the four `PLATFORM` settings keys — `PURGE_LEAD_STALE_DAYS` (90), `PURGE_TENANT_STALE_DAYS` (30), `PURGE_HARD_DELETE_COOLING_OFF_DAYS` (30), `PURGE_CANDIDATE_LIST_MAX_ROWS` (500) |
| `sql-scripts-dyanmic/platform-data-purge-capability-seed.sql` | capabilities `PLATFORM_DATA_PURGE` + `PLATFORM_DATA_PURGE_HARD`, menu `PLATFORM_DATA_CLEANUP`, granted to `SUPERADMIN` |

Every settings read passes a hard-coded fallback, so the feature degrades rather than throws if the
retention seed has not been applied yet. The **capability** seed has no such fallback: until it is
applied, `/ops/data-cleanup` is invisible and all three mutations reject with an authorization
failure. That is the intended failure mode — a destructive feature must not be reachable by default.

---

## 7. Pre-flight checks (§③.4 of the build prompt)

Run these against the target database before applying, and sanity-check the reflection sweep's
category count against the second one:

```sql
-- the financial hard block reads these; confirm the real table names in this environment
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'billing' ORDER BY 1;

-- how many entities are actually tenant-owned?
SELECT COUNT(*) FROM information_schema.columns
WHERE column_name = 'CompanyId' AND table_schema IN ('app','auth','sett','finance','audit');
```
