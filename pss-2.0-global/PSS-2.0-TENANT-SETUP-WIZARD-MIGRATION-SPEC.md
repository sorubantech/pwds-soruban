# PSS 2.0 — Tenant First-Login Setup Wizard · Migration Spec

**Status:** written by the agent, **NOT applied**. You author and run the migration.

**Source of truth — all three already committed to the tree, so `dotnet ef migrations add` picks
this up with no further edits:**

- `Base.Domain/Models/SettingModels/TenantSetupTask.cs` (new entity)
- `Base.Infrastructure/Data/Configurations/SettingConfigurations/TenantSetupTaskConfiguration.cs` (new config)
- `Base.Domain/Models/ApplicationModels/Company.cs` (2 new nullable scalars + 1 navigation)

Wiring already done: `ISettingDbContext.TenantSetupTasks` + `SettingDbContext.TenantSetupTasks`.
Configurations are auto-discovered — `ApplicationDbContext.OnModelCreating` calls
`builder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly())`, so there is no
registration list to edit.

---

## 1. Scope of this migration

Three things, nothing else:

1. **One new table** — `sett."TenantSetupTasks"`.
2. **Two new nullable columns** on `app."Companies"` — `SetupWizardCompletedDate`, `SetupWizardVersion`.
3. **One backfill `UPDATE`** — hand-added to the generated `Up()`, see §4. **This is mandatory.**

Schema `sett` already exists (`OrganizationSettings`, `SettingGroups`, `MasterDatas` live there),
so the migration should not emit `EnsureSchema`.

---

## 2. Verify-before-building

Run this first. If either query returns a row / a non-null regclass, the migration has already been
applied and you should not add a second one.

```sql
-- expect: 0 rows
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'app'
  AND table_name   = 'Companies'
  AND column_name IN ('SetupWizardCompletedDate', 'SetupWizardVersion');

-- expect: NULL
SELECT to_regclass('sett."TenantSetupTasks"');
```

---

## 3. Command to run (yours to execute)

From `PSS_2.0_Backend/PeopleServe/Services/Base/`:

```bash
dotnet ef migrations add Add_TenantSetupWizard \
  --project Base.Infrastructure \
  --startup-project Base.API \
  --context ApplicationDbContext
```

**Review gate before applying.** The generated `Up()` must contain **exactly**:

- one `CreateTable("TenantSetupTasks", schema: "sett", …)`
- two `AddColumn<…>(… table: "Companies", schema: "app" …)` — both `nullable: true`
- two `CreateIndex` calls (one unique, one not)
- one `AddCheckConstraint`

If it also contains `AlterColumn` or `DropColumn` on any other table, the model has drifted from the
database for an unrelated reason — stop and reconcile that separately rather than shipping it inside
this migration.

Then add the §4 backfill, re-read the file, and apply:

```bash
dotnet ef database update --project Base.Infrastructure --startup-project Base.API
```

---

## 4. The backfill — MUST be added by hand to `Up()`

EF will not generate this. Add it **after** the two `AddColumn` calls and **before** the
`CreateTable`, as the last statement touching `app."Companies"`:

```csharp
migrationBuilder.Sql("""
    UPDATE app."Companies"
    SET "SetupWizardCompletedDate" = now(),
        "SetupWizardVersion"       = 1
    WHERE "SetupWizardCompletedDate" IS NULL;
    """);
```

**Why this is not optional.** The post-login gate reads exactly one signal: `SetupWizardCompletedDate
IS NULL` ⇒ show the wizard. Without the backfill, *every existing tenant* — including live ones and
the `__TEMPLATE__` company — is bounced into a first-login wizard the moment this ships. The
`WHERE … IS NULL` makes it idempotent and makes it a no-op on a fresh database.

`now()` is `timestamptz` and the column is `timestamp with time zone`, so this stores a correct UTC
instant with no client-side `DateTime.Kind` hazard.

No corresponding statement is needed in `Down()` — the `DropColumn` removes the backfilled values.

---

## 5. Expected shape of `sett."TenantSetupTasks"`

| Column | Postgres type | Null | Default | Notes |
|---|---|---|---|---|
| `TenantSetupTaskId` | `integer` **GENERATED ALWAYS AS IDENTITY** | no | — | PK. `UseIdentityAlwaysColumn()` |
| `CompanyId` | `integer` | no | — | FK → `app."Companies"("CompanyId")`, `ON DELETE RESTRICT` |
| `TaskCode` | `character varying(60)` | no | — | `ORG_PROFILE_CONFIRM`, `ORG_LOCALE`, `EMAIL_SENDER`, … |
| `Status` | `character varying(20)` | no | — | `PENDING` \| `COMPLETED` \| `SKIPPED` \| `NOT_APPLICABLE` |
| `IsRequired` | `boolean` | no | `false` | exactly one task is required today (`ORG_LOCALE`) |
| `DisplayOrder` | `integer` | no | `0` | |
| `CompletedDate` | `timestamp with time zone` | yes | — | |
| `CompletedByUserId` | `integer` | yes | — | **no FK** — mirrors `Company.AccountManagerUserId` |
| `SkippedDate` | `timestamp with time zone` | yes | — | |
| `IsActive` | `boolean` | yes | — | `Entity` base |
| `IsDeleted` | `boolean` | yes | — | `Entity` base |
| `CreatedBy` / `ModifiedBy` | `integer` | yes | — | `Entity` base |
| `CreatedDate` / `ModifiedDate` | `timestamp with time zone` | yes | — | `Entity` base |

### Indexes and constraints

```
IX_TenantSetupTasks_CompanyId_TaskCode   UNIQUE  ("CompanyId", "TaskCode")     -- no filter
IX_TenantSetupTasks_CompanyId_Status             ("CompanyId", "Status")
CK_TenantSetupTasks_Status   CHECK ("Status" IN ('PENDING','COMPLETED','SKIPPED','NOT_APPLICABLE'))
```

Two deliberate choices worth confirming in review, because both differ from the nearest
neighbouring table (`sett."OrganizationSettings"`):

**The unique index has no `IsDeleted = false` filter.** `OrganizationSettings` filters its unique
index because rows there are soft-deleted and re-created. A setup task is never soft-deleted — it is
*transitioned* between states. Leaving `IsDeleted` out of the key is precisely what makes the
self-heal upsert (`GetTenantSetup` materialising task codes a tenant predates) idempotent: it can
rely on the database to reject a duplicate rather than having to reason about tombstones.

**`Status` is `varchar` + `CHECK`, not a Postgres `enum`.** Adding a state later stays a data change
instead of a `DDL` change that has to be coordinated with a deploy.

---

## 6. Expected shape of the `app."Companies"` additions

| Column | Postgres type | Null | Notes |
|---|---|---|---|
| `SetupWizardCompletedDate` | `timestamp with time zone` | yes | NULL ⇒ wizard not finished. The gate's only signal |
| `SetupWizardVersion` | `integer` | yes | the wizard version the tenant completed; current is `1` |

Both nullable on purpose. `SetupWizardCompletedDate` is per **company**, not per user — the wizard
writes company-wide settings, so the second admin to log in must not be re-asked. `SetupWizardVersion`
exists so a future v2 can re-show the wizard to tenants who only ever finished v1; without it, adding
a step later means either re-running the whole wizard for everyone or never being able to add one.

---

## 7. Seeds

**None.** No `sql-scripts-dyanmic/` file accompanies this migration.

Task rows are not seeded — they are materialised per tenant in application code
(`ProvisionTenant` Step 9, plus self-heal on first read), because which tasks apply depends on the
tenant's plan entitlements (`CHANNEL:EMAIL` / `CHANNEL:WHATSAPP` / `CHANNEL:SMS` decide
`NOT_APPLICABLE`) and that is not knowable from a static script.

No capability seed either: the wizard reuses
`[CustomAuthorize(DecoratorSettingModules.CompanySettings, Permissions.Modify)]`.

---

## 8. Down()

Generated `Down()` is correct as-is: drop the check constraint, drop the two indexes, drop
`sett."TenantSetupTasks"`, drop the two `app."Companies"` columns. Nothing to hand-edit.
