# PSS 2.0 — Backend Build Performance Remediation Plan

**Status:** PLANNED — do not start until the Import workstream is closed out.
**Created:** 2026-08-18
**Owner:** Karthick
**Repo:** `PSS_2.0_Backend/PeopleServe` (nested git repo — stage inside it, not at pss-2.0-global root)

---

## 0. Problem statement

A single-line change in `Base.Application` takes **20–30 minutes** to build.

### Measured evidence (2026-08-18)

| Project | .cs files | lines |
|---|---:|---:|
| Base.API | 522 | 57,027 |
| Base.Application | 2,597 | 277,340 |
| Base.Domain | 436 | 16,487 |
| Base.Support | 106 | 14,476 |
| **Base.Infrastructure** | **858** | **6,149,230** |

Base.Infrastructure breakdown:

| Folder | files | lines |
|---|---:|---:|
| `Data/` | 400 | 21,654 |
| `Services/` | 44 | 8,708 |
| `Repositories/` | 19 | 2,930 |
| **`Migrations/`** | **386** | **6,114,623** (233 MB) |

**`Migrations/` is 93.9% of every line of C# in the backend.**

### Why

- 192 migrations, each with a `.Designer.cs` holding a **complete model snapshot of all 822 entities**.
- Each snapshot is now ~1.64 MB / ~41,000 lines, and they are near-identical copies of each other.
- Cost grows as `migrations × entities` — quadratic. Growth curve:

| Migration | Designer size |
|---|---:|
| `20260420130359_Add_Initial_Migration` | 619 KB |
| `20260601101717_Add_IsSystemApproval...` | 1.36 MB |
| `20260701082736_Add_FundraisingFields...` | 1.42 MB |
| `20260817154323_Add_ImportSessionField` (latest) | 1.64 MB |

- C# compiles **per assembly**, not per file. The reference chain is serial:
  `Base.Domain → Base.Application → Base.Infrastructure → Base.API` (with `Base.Support` alongside).
- `Base.Infrastructure` sits **downstream** of `Base.Application`. Any edit in Application invalidates its
  reference assembly and forces a **full CoreCompile of all 6.11M lines** of Infrastructure, then API.
  MSBuild cannot parallelize a serial chain.

**822 entities is NOT itself the problem** — `Base.Domain` is 16,487 lines and compiles instantly. The
entity count only hurts because it is multiplied into all 192 snapshots.

### Aggravating factors

1. Windows Defender real-time protection ON, exclusions unverified (reading them needs admin). Each build
   reads 233 MB of source and writes ~1.1 GB of output (`Base.API/bin/Debug` = 603 MB,
   `Base.Support/bin` = 496 MB).
2. `Base.Support` is `OutputType=Exe` → a second full dependency-copy output tree.
3. Hardware: i5-13420H (4P + 4E cores), 24 GB RAM. Roslyn holds all syntax trees and symbols in memory.
4. No `Directory.Build.props` — analyzers and doc generation run on Debug builds.
5. Stale `obj/Debug/net8.0` and `obj/Release/net8.0` folders left from the net8 → net10 move.
6. SDK is a preview build: `10.0.400-preview.0.26322.102`.

### Target

Migrations `6,114,623 → ~80,000` lines. Total backend compile input down ~94%.
**Expected build time: 1–3 minutes.**

---

## 1. Pre-flight gate — DO NOT SKIP

Run every check before touching anything. If any fails, stop.

- [ ] **Import workstream is closed** and its migrations are committed and merged.
- [ ] **No pending EF migration** — `git status` inside `PSS_2.0_Backend` is clean.
- [ ] **Inventory every database that must survive.** At minimum: local dev, shared dev, staging, and
      every live tenant DB. Write the list into §7 before starting.
- [ ] **Every one of those DBs is at the latest migration.** For each:
      ```sql
      SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY "MigrationId" DESC LIMIT 3;
      ```
      The top row must be `20260817154323_Add_ImportSessionField` **or later** (re-confirm the true latest
      ID at execution time — the Import work may add more).
      **If any DB lags, apply its pending migrations FIRST. A lagging DB cannot be baselined.**
- [ ] **Full backup / snapshot of every production and staging DB taken and restore-tested.**
- [ ] Working branch cut: `git checkout -b chore/squash-migrations`

### Verified safe-to-squash precondition

`.HasData(` occurrences: **0** in `ApplicationDbContextModelSnapshot.cs`, **0** in `Data/`.
(The 151 apparent hits found during analysis were all `HasDatabaseName`.)
No EF seed data means the squash carries no seed-diff risk. **Re-verify at execution time:**

```bash
cd "PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure"
grep -rc '\.HasData(' Migrations/ApplicationDbContextModelSnapshot.cs Data/
```

Both must be `0`. If not, STOP and re-plan — seeded rows change the procedure.

---

## 2. Phase 1 — Squash migrations to a single baseline (the 94% win)

All 386 files are tracked in git, so the old migrations stay recoverable from history.

### 2.1 Record the current head

```bash
cd "PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations"
ls *.Designer.cs | tail -1     # record this ID → call it OLD_HEAD
```

### 2.2 Delete and regenerate

```bash
cd "PSS_2.0_Backend/PeopleServe/Services/Base"
rm Base.Infrastructure/Migrations/*.cs

cd Base.Infrastructure
dotnet ef migrations add Baseline_20260818 -s ../Base.API
```

Record the generated ID → `BASELINE` (e.g. `20260818XXXXXX_Baseline_20260818`).

### 2.3 Verify the baseline is faithful

This is the critical correctness gate. The regenerated snapshot must be **model-identical** to the old one.

```bash
cd "PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure"
git show HEAD:Services/Base/Base.Infrastructure/Migrations/ApplicationDbContextModelSnapshot.cs \
  > /tmp/old-snapshot.cs
diff /tmp/old-snapshot.cs Migrations/ApplicationDbContextModelSnapshot.cs
```

**Expected: no differences other than the EF `ProductVersion` attribute line.**
Any entity / property / index difference means some migration in history did something the model no longer
describes (hand-edited `Up()`, raw `migrationBuilder.Sql()` expression index, etc.). Investigate before
proceeding — see §6 Known landmines.

Then confirm nothing is left to migrate:

```bash
dotnet ef migrations add __ShouldBeEmpty -s ../Base.API
# open the generated file — Up() and Down() must both be empty
dotnet ef migrations remove -s ../Base.API
```

### 2.4 Re-stamp the migration history on every existing database

For **each** DB in the §7 inventory, run inside a transaction:

```sql
BEGIN;
  -- sanity: confirm this DB is at the old head before wiping
  SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY "MigrationId" DESC LIMIT 1;
  -- must return OLD_HEAD. If not, ROLLBACK and fix that DB first.

  DELETE FROM "__EFMigrationsHistory";
  INSERT INTO "__EFMigrationsHistory" ("MigrationId","ProductVersion")
  VALUES ('<BASELINE>', '10.0.0');
COMMIT;
```

> `MigrateAsync()` is called at startup from
> `Base.Infrastructure/Data/Extensions/DatabaseExtentions.cs:12`. If the history is not re-stamped, the app
> will try to run the baseline `Up()` against a populated DB and fail on the first `CREATE TABLE`. It fails
> safe (no data loss), but the service will not start.

### 2.5 Fresh / new tenant databases

No action needed. New DBs run the baseline `Up()` and get the full schema in one shot. Verify against a
throwaway empty database:

```bash
dotnet ef database update -s ../Base.API
```

Then smoke-test tenant provisioning end to end (`ProvisionTenant` command).

### 2.6 Stage

Inside `PSS_2.0_Backend` (nested repo — stage only, Karthick commits):

```bash
cd "PSS_2.0_Backend"
git add -A
```

---

## 3. Phase 2 — Defender exclusions (typically another 20–40%)

Elevated PowerShell:

```powershell
Add-MpPreference -ExclusionPath "d:\Repos\PWDS"
Add-MpPreference -ExclusionProcess "dotnet.exe","MSBuild.exe","csc.exe","VBCSCompiler.exe"
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath   # verify
```

This is a machine-level change on the dev box, not a repo change. Every dev needs it applied locally.

---

## 4. Phase 3 — Build configuration hygiene

### 4.1 `Directory.Build.props`

New file next to `PeopleServe.sln`:

```xml
<Project>
  <PropertyGroup>
    <AccelerateBuildsInVisualStudio>true</AccelerateBuildsInVisualStudio>
    <GenerateDocumentationFile>false</GenerateDocumentationFile>
    <ProduceReferenceAssembly>true</ProduceReferenceAssembly>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)'=='Debug'">
    <RunAnalyzersDuringBuild>false</RunAnalyzersDuringBuild>
  </PropertyGroup>
</Project>
```

`ProduceReferenceAssembly` is already the SDK default; it is stated explicitly so it cannot silently
regress. It is what lets a method-body-only change in `Base.Application` skip the downstream rebuild.

### 4.2 Clear stale intermediates

```bash
cd "PSS_2.0_Backend/PeopleServe/Services/Base"
rm -rf */obj/Debug/net8.0 */obj/Release/net8.0
```

### 4.3 Change the daily build habit

- Build the **project**, not the solution: `dotnet build Services/Base/Base.API/Base.API.csproj`
- **Never** `clean` / `Rebuild` unless something is genuinely broken. Clean forfeits every incremental win.

### 4.4 (Optional, evaluate later) SDK

Move off `10.0.400-preview.0.26322.102` to a released 10.0.x SDK. Do this **separately**, after Phase 1 is
verified green — do not confound two variables.

---

## 5. Measurement protocol

Capture a binlog **before** Phase 1 and after each phase, so the win is provable:

```bash
cd "PSS_2.0_Backend/PeopleServe"
dotnet build Services/Base/Base.API/Base.API.csproj -bl:build-<phase>.binlog
```

Open in the MSBuild Structured Log Viewer and record the **per-project `CoreCompile` duration**.

| Checkpoint | Wall clock | Base.Infrastructure CoreCompile |
|---|---|---|
| Baseline (before) | | |
| After Phase 1 (squash) | | |
| After Phase 2 (Defender) | | |
| After Phase 3 (props) | | |

Measure the realistic scenario, not a cold full build: touch one file in `Base.Application` (add and remove
a blank line), then build.

---

## 6. Known landmines

- **Expression indexes / raw SQL migrations.** Per project convention, expression indexes are created via
  `migrationBuilder.Sql()`. Those are **not** represented in the model snapshot, so the regenerated
  baseline `Up()` **will not recreate them**. Existing DBs are unaffected (they already have them and get
  re-stamped), but a **fresh DB built from the baseline will be missing them**.
  **Action:** before deleting, grep the old migrations and carry the SQL forward:
  ```bash
  cd "PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations"
  grep -ln 'migrationBuilder.Sql(' *.cs | grep -v Designer
  ```
  Collect every such statement into the new baseline migration's `Up()` (appended at the end), or into a
  dedicated follow-up migration.
  **This is the single most likely way to break fresh-tenant provisioning.**
- **Hand-edited `Up()`/`Down()` bodies** (data backfills, column-type conversions such as the text → jsonb
  custom-fields change). Same treatment: these are one-time transforms that existing DBs already ran. A
  fresh DB creates the column in its final shape directly, so backfills are correctly dropped — but confirm
  each one is genuinely a transform and not a schema or seed step.
- **Other developers / other machines.** After the squash lands, anyone with a local DB must run the §2.4
  re-stamp against it, or drop and recreate their local DB. Announce this before merging.
- **In-flight branches** containing new migrations created against the old chain will conflict. Merge or
  land them **before** the squash. This is precisely why the squash waits for Import to finish.
- **User creates EF migrations, not the agent** (standing project rule). The `dotnet ef migrations add`
  steps in §2.2 are for Karthick to run.

---

## 7. Database inventory (fill in before execution)

| Environment | Host / DB | At latest migration? | Backed up? | Re-stamped? |
|---|---|---|---|---|
| Local dev | | | | |
| Shared dev | | | | |
| Staging | | | | |
| Tenant: | | | | |
| Tenant: | | | | |

---

## 8. Rollback

Phase 1 is fully reversible as long as the DB backups exist.

```bash
cd "PSS_2.0_Backend"
git checkout HEAD~1 -- PeopleServe/Services/Base/Base.Infrastructure/Migrations
```

Then restore each DB's `__EFMigrationsHistory` — either from backup, or by re-inserting the original 192
migration IDs (recoverable from the restored `Migrations/` folder filenames):

```sql
DELETE FROM "__EFMigrationsHistory";
-- re-insert each of the 192 (MigrationId, '10.0.0') rows
```

Phases 2 and 3 are trivially reversible (`Remove-MpPreference`, delete `Directory.Build.props`).

---

## 9. Ongoing hygiene — this WILL come back

At ~41k lines per snapshot with 822 entities, the build degrades to multi-minute again after roughly
**40–50 new migrations**. Apr–Aug 2026 produced 192, so that is about 1–1.5 months of work.

**Standing rule: re-baseline the migrations at every release cutover**, using this same document. Do not let
migrations accumulate for another four months.

Cheap early-warning check:

```bash
find PeopleServe/Services/Base/Base.Infrastructure/Migrations -name '*.cs' \
  -not -path '*/obj/*' -exec cat {} + | wc -l
```

Re-baseline when this exceeds ~1,500,000.

---

## 10. Execution order summary

1. Gate: Import workstream closed, all DBs current, backups taken, §7 inventory filled in (§1, §7)
2. Measure: capture the "before" binlog (§5)
3. Grep for `migrationBuilder.Sql(` and hand-edited `Up()` bodies; collect them (§6)
4. Squash and verify the snapshot diff is clean (§2.1–2.3)
5. Re-stamp `__EFMigrationsHistory` on every DB (§2.4)
6. Verify the fresh-DB path and tenant provisioning (§2.5)
7. Measure and stage (§2.6, §5)
8. Defender exclusions, measure (§3, §5)
9. `Directory.Build.props` + clear stale obj, measure (§4, §5)
10. Announce to the team: everyone re-stamps or recreates their local DB (§6)
11. Optional, separately: move off the preview SDK (§4.4)
