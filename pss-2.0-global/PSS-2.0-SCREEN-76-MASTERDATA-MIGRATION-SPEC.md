# Migration Spec — Screen #76 Master Data (combined with #162 Master Data Type)

**Status:** code written and compiling; migration **NOT** generated. You author, run and commit it.
**Context:** `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure`
**Affected tables:** `sett."MasterDataTypes"`, `sett."MasterDatas"`
**Suggested migration name:** `Add_MasterData_Abbreviation_And_Lookup_Behaviour_Flags`

---

## ⚠️ PRE-FLIGHT — READ BEFORE GENERATING

Two **unique** indexes are introduced. Existing production/staging rows may violate them, in which case
`database update` fails half-way through the migration. Run the two duplicate probes in §4 **first** and
clean up what they return. There is no way for the migration itself to resolve a duplicate — it is a data
decision (which row wins, which gets renamed or soft-deleted).

The old index `IX_MasterDatas_MasterDataTypeId_ParentMasterDataId_IsActive` is **dropped**. It was
functionally broken: being unique over `(TypeId, ParentId, IsActive)` it allowed exactly **one active value
per type**, which is the opposite of what a lookup list needs. Nothing depends on it.

---

## 1. Entity changes already in code

`Base.Domain/Models/SettingModels/MasterDataType.cs`

```csharp
// Screen #76: consumers of this type may pick more than one value (multi-select lookup)
public bool AllowMultipleSelection { get; set; }
// Screen #76: consumers of this type may type a free-text value not present in the list
public bool AllowUserInput { get; set; }
```

`Base.Domain/Models/SettingModels/MasterData.cs`

```csharp
// Screen #76: short form shown in dense grids / chips (e.g. "Mr", "TN", "USD")
public string? Abbreviation { get; set; }
```

`IsSystem` already existed on **both** entities (it is in the current model snapshot) — it is *not* part of
this migration. It matters only because `ApplicationDbContext.ApplyTenantFilters` widens the global query
filter to `CompanyId == tenant || IsSystem == true` for any entity that has it.

## 2. EF configuration changes already in code

`Base.Infrastructure/Data/Configurations/SettingConfigurations/MasterDataConfigurations.cs`

```csharp
builder.Property(c => c.Abbreviation).HasMaxLength(50);                       // line 28

// REPLACES the old (MasterDataTypeId, ParentMasterDataId, IsActive) unique index
builder.HasIndex(o => new { o.MasterDataTypeId, o.DataValue, o.CompanyId })   // line 45
       .IsUnique()
       .HasFilter("\"IsDeleted\" = false");
```

`…/MasterDataTypeConfigurations.cs`

```csharp
builder.HasIndex(o => new { o.TypeCode, o.CompanyId })                        // line 28
       .IsUnique()
       .HasFilter("\"IsDeleted\" = false");
```

## 3. Expected DDL

This is what the generated migration should contain. Use it to review EF's output, not as a hand-written
replacement for it.

```sql
-- MasterDataTypes: two behaviour flags
ALTER TABLE sett."MasterDataTypes"
    ADD COLUMN "AllowMultipleSelection" boolean NOT NULL DEFAULT false;
ALTER TABLE sett."MasterDataTypes"
    ADD COLUMN "AllowUserInput"         boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX "IX_MasterDataTypes_TypeCode_CompanyId"
    ON sett."MasterDataTypes" ("TypeCode", "CompanyId")
    WHERE "IsDeleted" = false;

-- MasterDatas: short display form
ALTER TABLE sett."MasterDatas"
    ADD COLUMN "Abbreviation" character varying(50) NULL;

DROP INDEX sett."IX_MasterDatas_MasterDataTypeId_ParentMasterDataId_IsActive";

CREATE UNIQUE INDEX "IX_MasterDatas_MasterDataTypeId_DataValue_CompanyId"
    ON sett."MasterDatas" ("MasterDataTypeId", "DataValue", "CompanyId")
    WHERE "IsDeleted" = false;
```

Notes on EF's rendering:

- `bool` (non-nullable) → EF emits `defaultValue: false`; existing rows backfill to `false`, which is the
  correct default for both flags (single-select, no free text).
- The filtered indexes come out as `.Annotation("Npgsql:IndexFilter", …)` / `filter: "\"IsDeleted\" = false"`.
- `IsDeleted` is `boolean NULL` in this model. The filter `"IsDeleted" = false` therefore excludes rows
  where `IsDeleted IS NULL`. That is deliberate for soft-deleted rows, but see §4 — rows created before the
  soft-delete column was populated may carry `NULL` and will **not** be constrained. If you want them
  constrained, normalise `NULL` → `false` first (§4, query 3).

## 4. Duplicate probes — run these BEFORE `database update`

```sql
-- 1. Duplicate type codes per company (blocks IX_MasterDataTypes_TypeCode_CompanyId)
SELECT "CompanyId", "TypeCode", COUNT(*) AS dupes,
       array_agg("MasterDataTypeId" ORDER BY "MasterDataTypeId") AS ids
FROM   sett."MasterDataTypes"
WHERE  "IsDeleted" = false
GROUP  BY "CompanyId", "TypeCode"
HAVING COUNT(*) > 1;

-- 2. Duplicate data values within a type per company (blocks IX_MasterDatas_…_DataValue_…)
SELECT "CompanyId", "MasterDataTypeId", "DataValue", COUNT(*) AS dupes,
       array_agg("MasterDataId" ORDER BY "MasterDataId") AS ids
FROM   sett."MasterDatas"
WHERE  "IsDeleted" = false
GROUP  BY "CompanyId", "MasterDataTypeId", "DataValue"
HAVING COUNT(*) > 1;

-- 3. OPTIONAL — rows the partial-index filter will skip because IsDeleted IS NULL
SELECT COUNT(*) FILTER (WHERE "IsDeleted" IS NULL) AS null_isdeleted_types
FROM   sett."MasterDataTypes";
SELECT COUNT(*) FILTER (WHERE "IsDeleted" IS NULL) AS null_isdeleted_values
FROM   sett."MasterDatas";
-- If you want those rows covered by the unique index:
-- UPDATE sett."MasterDataTypes" SET "IsDeleted" = false WHERE "IsDeleted" IS NULL;
-- UPDATE sett."MasterDatas"     SET "IsDeleted" = false WHERE "IsDeleted" IS NULL;
-- Re-run probes 1 and 2 afterwards — normalising NULLs can surface new duplicates.
```

**Resolving a duplicate:** keep the row that other tables actually reference (check the FK back-references —
`MasterData` is pointed at by ~60 columns across contact/donation/campaign/report models), then either
soft-delete the loser (`"IsDeleted" = true`) or give it a distinct `DataValue`. Do **not** hard-delete: the
FKs are `DeleteBehavior.Restrict` and a hard delete will fail or orphan data.

## 5. Runbook

1. Run §4 probes; resolve any rows returned.
2. `dotnet ef migrations add Add_MasterData_Abbreviation_And_Lookup_Behaviour_Flags` (from the Base.API
   startup project, as usual for this repo).
3. Diff the generated `Up()` against §3 — in particular confirm the `DROP INDEX` is present and no unrelated
   pending model drift got swept in.
4. `dotnet ef database update`.
5. Apply the seed script `sql-scripts-dyanmic/masterdata-combined-menu-seed.sql` (menu + capability rows).
6. Commit migration + snapshot.

## 6. Rollback

`Down()` re-creates the old `(MasterDataTypeId, ParentMasterDataId, IsActive)` unique index. If any type has
gained a second active value since the migration ran, that recreation **will fail**. Deactivate or
soft-delete the surplus rows first, or drop the `Down()` recreation of that index and accept it as gone —
it was broken and nothing queries by it.
