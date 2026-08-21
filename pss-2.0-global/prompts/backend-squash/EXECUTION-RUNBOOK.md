# Backend Squash — Execution Runbook

Companion to [`../backend_build_performance_remediation_prompt.md`](../backend_build_performance_remediation_prompt.md).
That document is the **plan**; this one is the **audited, ready-to-run version** with the
figures re-verified on 2026-08-20 and the landmine analysis already done.

**Backend repo root:** `pss-2.0-global/PSS_2.0_Backend` (nested git repo — stage inside it).
**Migration paths below are relative to** `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure`.

---

## A. Pre-flight — status as of 2026-08-20

| Check | Result |
|---|---|
| Backend working tree clean | ✅ clean, branch `module/case`, HEAD `ac1fdd8f` |
| `.HasData(` in `ApplicationDbContextModelSnapshot.cs` | ✅ **0** |
| `.HasData(` anywhere in `Data/` | ✅ **0** |
| Migration count | **195** (plan said 192 — Import added 3) |
| Total lines in `Migrations/` | **6,238,616** (plan said 6,114,623) |
| OLD_HEAD | `20260819070229_Add_CustomField_And_ColumnMappingJson_Donation_Import` |
| `Directory.Build.props` | absent (Phase 3 adds it) |
| Stale `obj/Debug/net8.0` | present in all 5 projects |
| SDK | `10.0.400-preview.0.26322.102` |
| TFM | `net10.0` across all 5 projects |
| `OutputType=Exe` second output tree | `Base.Support` — confirmed, `bin` = 496 MB |
| `bin` total | ~1.8 GB (`Base.API` 1.2 G, `Base.Support` 496 M, `Base.Infrastructure` 105 M) |
| `MigrateAsync()` call site | confirmed `Data/Extensions/DatabaseExtentions.cs:12` |

**Still owed before starting:**

- [ ] Import workstream closed and merged (§1 of the plan)
- [ ] §B DB inventory filled in and every DB confirmed at OLD_HEAD
- [ ] Restore-tested backup of every production and staging DB
- [ ] `git checkout -b chore/squash-migrations`

---

## B. Database inventory

The app is **single-database multi-tenant** (tenants are `CompanyId` rows, not separate DBs),
so this is a short list — one DB per environment, not one per tenant. Confirm and complete:

| Environment | Host / DB | At OLD_HEAD? | Backed up? | Re-stamped? |
|---|---|---|---|---|
| Shared dev | `148.251.86.78:5434` / `Pss2.0_Dev_latest` (from `appsettings.Development.json`) | **YES** — verified read-only 2026-08-20. Head = `20260819070229_…Donation_Import`, 196 history rows, PG 16.13, 418 tables in 20 schemas | | |
| Azure dev (commented out) | `devpsscore.postgres.database.azure.com` / `Pss2.0_Dev_Latest` | **DEAD** — hostname is NXDOMAIN (2026-08-20). Server decommissioned; the commented line in `appsettings.Development.json` can be deleted. Not a re-stamp target | n/a | n/a |
| Local dev (each developer) | | | | |
| Staging | | | | |
| Production | | | | |

Per DB:

```sql
SELECT "MigrationId" FROM public."__BaseServiceEFMigrationsHistory"
 ORDER BY "MigrationId" DESC LIMIT 3;
```

> ⚠️ **The history table is NOT `__EFMigrationsHistory`.** This context overrides the default
> name — it is `public."__BaseServiceEFMigrationsHistory"`. Verified against shared dev
> 2026-08-20; `SELECT … FROM "__EFMigrationsHistory"` fails with *relation does not exist*.
> `restamp-migration-history.sql` and `rollback-restore-migration-history.sql` were written
> against the default name and **have been corrected** — re-check before running.

Top row must be `20260819070229_Add_CustomField_And_ColumnMappingJson_Donation_Import` or later.
**A lagging DB cannot be baselined — apply its pending migrations first.**

---

## C. Landmine audit — DONE, findings below

All 195 migrations were grepped for `migrationBuilder.Sql(`. Five files hit; each was read and classified.

### Must carry forward into the new baseline — 2 items

| Migration | What | Why the snapshot misses it |
|---|---|---|
| `20260516052920_Add_DisplayFields_In_Currency` | `MasterDataTypes` + `MasterDatas` seed rows for the 5 Currency enum fields (`CURRENCYSYMBOLPOSITION`, `CURRENCYTHOUSANDSSEPARATOR`, `CURRENCYDECIMALSEPARATOR`, `CURRENCYRATESOURCE`, `CURRENCYUPDATEFREQUENCY`) | Raw-SQL seed, so the `.HasData( == 0` check did **not** clear it. Not present in `sql-scripts-dyanmic/` either — grep for `CURRENCYSYMBOLPOSITION` returns nothing. Without it the 5 Currency FK columns point at no rows. |
| `20260818062300_Replace_Field_Name_Unique_Index` | `ux_fields_system_name`, `ux_fields_custom_name` on `sett."Fields"` | `lower()` / `COALESCE()` / partial `WHERE` cannot be expressed via `HasIndex()`. Verified: grep for `ux_fields` in the snapshot → **0 hits**. |

> The `.HasData( == 0` precondition in the plan is **necessary but not sufficient** — it does not
> catch raw-SQL seeds. The Currency migration is exactly that case. Re-run the full
> `migrationBuilder.Sql(` grep at execution time if any new migration has landed since.

### Safe to drop — 3 items

| Migration | Why it can go |
|---|---|
| `20260514130705_Add_Staff_Basic_Fields_In_Staff` | Only `DROP INDEX IF EXISTS` cleanup of superseded indexes. The three replacements are in the snapshot (`IX_Staffs_CompanyId_StaffEmail_Active`, `..._StaffEmpId_Active`, `..._StaffMobileNumber_Active`). |
| `20260817091615_Change_Text_To_JsonB_To_CustomFields_In_Contact_Entities` | One-time `text` → `jsonb` `ALTER`. The snapshot already declares those columns `HasColumnType("jsonb")`, so a fresh DB creates them in final shape. |
| `20260817154323_Add_ImportSessionField` | Defensive idempotent `CREATE TABLE` / `ADD COLUMN` / FK / unique index for `import."ImportSessionFields"`. The entity **is** mapped (`Base.Domain.Models.ImportModels.ImportSessionField`) and the snapshot carries the table *and* the unique index `uix_import_session_fields_session_name`. EF regenerates all of it. |

The carry-forward code is pre-written in
[`baseline-carryforward-up.cs.txt`](baseline-carryforward-up.cs.txt) — paste it at the end of the new
baseline's `Up()`, plus the two `DROP INDEX` lines into `Down()`.

---

## D. Phase 1 — squash (EF commands are yours to run, per standing project rule)

```bash
cd "pss-2.0-global/PSS_2.0_Backend/PeopleServe/Services/Base"

# 1. delete the chain (git keeps it; rollback IDs also captured in this folder)
rm Base.Infrastructure/Migrations/*.cs

# 2. regenerate as one baseline
cd Base.Infrastructure
dotnet ef migrations add Baseline_20260820 -s ../Base.API
```

Record the generated ID → **BASELINE**.

### 3. Correctness gate — the snapshot must be model-identical

> The plan's §2.3 `git show` path is missing the `PeopleServe/` prefix. Corrected:

```bash
cd "pss-2.0-global/PSS_2.0_Backend"
git show HEAD:PeopleServe/Services/Base/Base.Infrastructure/Migrations/ApplicationDbContextModelSnapshot.cs \
  > /tmp/old-snapshot.cs
diff /tmp/old-snapshot.cs \
  PeopleServe/Services/Base/Base.Infrastructure/Migrations/ApplicationDbContextModelSnapshot.cs
```

**Expected: only the EF `ProductVersion` attribute line differs.** Any entity / property / index
difference means a migration did something the model no longer describes — stop and investigate.

### 4. Paste the carry-forward block

Append the contents of `baseline-carryforward-up.cs.txt` to `Up()` (after everything EF generated),
and the two `DROP INDEX IF EXISTS` lines to `Down()`.

### 5. Confirm nothing is left to migrate

```bash
dotnet ef migrations add __ShouldBeEmpty -s ../Base.API
# open the generated file — Up() and Down() must both be empty
dotnet ef migrations remove -s ../Base.API
```

### 6. Re-stamp every DB

Run [`restamp-migration-history.sql`](restamp-migration-history.sql) against each DB in §B.
Edit the two values at the top first. It has a guard that aborts if the DB is not at OLD_HEAD.

### 7. Verify the fresh-DB path

Against a **throwaway empty database**:

```bash
dotnet ef database update -s ../Base.API
```

Then confirm the carried-forward artefacts actually landed:

```sql
SELECT indexname FROM pg_indexes
 WHERE schemaname = 'sett'
   AND indexname IN ('ux_fields_system_name', 'ux_fields_custom_name');   -- expect 2 rows

SELECT "TypeCode" FROM sett."MasterDataTypes"
 WHERE "TypeCode" LIKE 'CURRENCY%';                                       -- expect 5 rows

SELECT to_regclass('import."ImportSessionFields"');                       -- expect non-null
```

Then smoke-test tenant provisioning end to end (`ProvisionTenant`).

### 8. Stage

```bash
cd "pss-2.0-global/PSS_2.0_Backend"
git add -A      # you commit
```

---

## E. Phase 2 — Defender exclusions (per dev box, elevated PowerShell)

```powershell
Add-MpPreference -ExclusionPath "d:\Repos\PWDS"
Add-MpPreference -ExclusionProcess "dotnet.exe","MSBuild.exe","csc.exe","VBCSCompiler.exe"
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
```

Justified by the measured I/O: ~233 MB of source read and ~1.8 GB of `bin` written per full build.

---

## F. Phase 3 — build hygiene — ✅ APPLIED 2026-08-20

1. ✅ `Directory.Build.props` placed next to `PeopleServe.sln`
   (`AccelerateBuildsInVisualStudio`, `GenerateDocumentationFile=false`,
   `ProduceReferenceAssembly=true`, `RunAnalyzersDuringBuild=false` in Debug only).
2. ✅ Stale net8 intermediates deleted — `obj/Debug/net8.0` in all five projects
   (~1.4 MB) plus five empty `bin/Debug/net8.0` shells, leftovers from the
   net8 → net10 move.
   The `net8.0` folders that remain under `bin/*/net10.0/runtimes/*/lib/` are
   **legitimate NuGet runtime assets — do not delete them.**
3. Habit change: build the **project**, not the solution —
   `dotnet build Services/Base/Base.API/Base.API.csproj`. Never `clean` / `Rebuild` unless
   something is genuinely broken; a clean forfeits every incremental win.

---

## G. Measurement

Realistic scenario — touch one file in `Base.Application`, then build:

```bash
cd "pss-2.0-global/PSS_2.0_Backend/PeopleServe"
dotnet build Services/Base/Base.API/Base.API.csproj -bl:build-<phase>.binlog
```

Open in the MSBuild Structured Log Viewer and record per-project `CoreCompile` duration.

| Checkpoint | Wall clock | Notes |
|---|---|---|
| **Baseline (before)** | **11 m 25 s** | `build-before.binlog`, 0 errors / 665 warnings |
| **After Phase 3 (props + net8 purge)** | **8 m 22 s** | `build-after-phase3.binlog`, 0 errors / 569 warnings — **−27 %** |
| After Phase 2 (Defender) | | per dev box — user-owned |
| After Phase 1 (squash) | | the 94 % win — user-owned |

### Where the 11 m 25 s goes — from `build-before.binlog`

Replay the binlog without recompiling:

```bash
dotnet msbuild build-before.binlog -noconlog   -flp:logfile=binlog-replay.txt;verbosity=normal;PerformanceSummary
```

Task totals:

| Task | Total | Calls |
|---|---:|---:|
| `Csc` (the actual compile) | **667.8 s** | 7 |
| `ResolveAssemblyReference` | 2.8 s | 5 |
| everything else combined | < 5 s | — |

Per-project totals (**inclusive of project references** — MSBuild nests them,
so these are cumulative down the chain, not additive):

| Project | Total |
|---|---:|
| `Base.Domain` | 13.5 s |
| `Base.Application` | 120.2 s |
| `Base.Support` | 124.8 s |
| `Base.Infrastructure` | **668.7 s** |
| `Base.API` | 684.7 s |

`Base.Infrastructure` inclusive is 668.7 s against a 684.7 s whole-build — and its
own share, net of the 120.2 s it inherits from `Base.Application`, is roughly
**548 s, about 80 % of the entire build.** That is one project, and 93.9 % of its
lines are migration `.Designer.cs` snapshots.

**This is the measured confirmation of the plan's root-cause claim.** Phase 3 and
Phase 2 trim overhead around the edges; only Phase 1 touches the 548 s.

### Phase 3 result — measured 2026-08-20

Same scenario, after a warm-up build to absorb the `Directory.Build.props`
invalidation (a property change dirties every project, so the first build after
placing it is a full rebuild and is **not** the number to quote):

| | Before | After Phase 3 |
|---|---:|---:|
| Wall clock | 11 m 25 s | **8 m 22 s** |
| `Csc` total | 667.8 s | **445.9 s** |
| `Csc` invocations | 7 | **3** |
| Warnings | 665 | 569 |
| Errors | 0 | **0** |

**−27 %, and it cost nothing but a props file.** The warning drop and the
7 → 3 compile-invocation drop are the two settings doing their jobs:
analyzers off in Debug, and reference assemblies letting unchanged public
surface stop the rebuild cascade.

**But `Base.Infrastructure` still recompiled** — its 68 MB assembly was rewritten
during the measured build. The migration bulk is still being fed to the
compiler on every downstream change. Phase 3 shaved the overhead *around* that
compile; it did not touch the compile itself.

> Phase 3 is the cheap win and it is now banked. **The remaining ~8 minutes are
> still overwhelmingly `Base.Infrastructure`'s own compile, and only the Phase 1
> squash removes it.**

---

## H. Files produced by this session

| File | Purpose |
|---|---|
| `baseline-carryforward-up.cs.txt` | The C# to paste into the new baseline's `Up()` / `Down()` |
| `restamp-migration-history.sql` | Guarded `__EFMigrationsHistory` re-stamp, run per DB |
| `rollback-restore-migration-history.sql` | All 195 original migration IDs, captured **before** deletion |
| `PSS_2.0_Backend/PeopleServe/Directory.Build.props` | Phase 3 build settings |
| `PSS_2.0_Backend/PeopleServe/build-before.binlog` | "Before" measurement binlog (11 m 25 s) |
| `PSS_2.0_Backend/PeopleServe/build-after-phase3.binlog` | Post-Phase-3 measurement binlog (8 m 22 s) |

---

## I. Announce before merging

Everyone with a local DB must run `restamp-migration-history.sql` against it, or drop and recreate.
Any in-flight branch carrying a migration built on the old chain must land **before** the squash.

## J. Ongoing hygiene

Re-baseline at every release cutover. Early-warning check:

```bash
find PeopleServe/Services/Base/Base.Infrastructure/Migrations -name '*.cs' \
  -not -path '*/obj/*' -exec cat {} + | wc -l
```

Re-baseline when this exceeds ~1,500,000. It is at **6,238,616** today.

---

## K. Rehearsal results — 2026-08-20 (duplicate repo, branch `rehearsal/squash-migrations`)

Dry run performed in `D:\Repos\PWDS\pwds-soruban\pss-2.0-global` only. Nothing was committed;
no re-stamp SQL was executed against any database. Backend repo branch at the time: `module/case`
(= `origin/module/case`, up to date).

**Verdict: HALTED at the §D-3 correctness gate. Do not run the real Phase 1 yet.**
The squash mechanics work exactly as written — but the gate caught a genuine model/snapshot
drift, which is what it is for.

### K.1 What worked

| Step | Result |
|---|---|
| Delete `Migrations/*.cs` + `dotnet ef migrations add Baseline_20260820` | ✅ Build succeeded, ~7 min. Generated `20260820123846_Baseline_20260820` |
| Size collapse | 392 files → 3. `.cs` 30,342 lines + `.Designer.cs` 41,253 + snapshot 41,250 ≈ **112 k lines, down from ~8 M** |
| Snapshot fidelity gate | ✅ ran, ❌ result — see K.3 |

Note: the `.Designer.cs` / snapshot pair are byte-for-byte the same content EF has always
produced; the win is that there is now **one** of them instead of 195.

### K.2 Blocking finding #1 — the history table is not called `__EFMigrationsHistory`

It is `public."__BaseServiceEFMigrationsHistory"`. `SELECT … FROM "__EFMigrationsHistory"`
fails outright. §B and both SQL scripts have been corrected. **This alone would have made the
real re-stamp fail on the first statement.**

### K.3 Blocking finding #2 — the model has 3 indexes no migration ever created

The §D-3 diff of the pre-squash `ApplicationDbContextModelSnapshot.cs` against the regenerated
one is **not** limited to `ProductVersion` (both say `10.0.0`). It is 12 added lines, all on
`notify."Notifications"`, all declared in
`Base.Infrastructure/Data/Configurations/NotifyConfigurations/NotificationConfiguration.cs`:

* `IX_Notifications_PendingPush` — filtered, `IsDescending(false, true)`
* `UX_Notifications_Recipient_NoTemplate_SourceEntity` — unique, filtered
* `UX_Notifications_Recipient_Template_SourceEntity` — unique, filtered

None exist in shared dev (`pg_indexes` on `Notifications` returns 13 rows, none of these).
So someone added `HasIndex(...)` without generating a migration: **there is a pending,
never-applied model change sitting on the branch.**

Why this blocks the squash: the baseline generated from the model **does** create all three
(`20260820123846_Baseline_20260820.cs:22667/22705/22713`). Fresh DBs would get them; every
existing DB gets re-stamped to that baseline and is then declared "up to date" **without them,
permanently** — EF will never generate them again. Two unique constraints intended to
de-duplicate notifications would silently not exist in dev/staging/prod.

**Fix before the real Phase 1 (owner: Karthick):** on the branch being squashed, run
`dotnet ef migrations add Add_Notification_Dedup_Indexes`, apply it to every DB in §B, confirm
the three indexes exist, and only then start the squash. After that the §D-3 diff should come
back clean, which is the go signal.

### K.4 Finding #3 — one migration file is invisible to EF

`20260505120000_Add_RefundChannelAndFxSnapshot.cs` was hand-authored (its own header says so)
and **has no `.Designer.cs`** — so it carries no `[Migration]` attribute and EF never sees it.
That is why the folder holds 196 migration `.cs` files but `migrations list` reports 195.

Its 11 `fund."Refunds"` columns are **not in the model** (`RefundChannelCode` → 0 hits in the
snapshot and 0 in the generated baseline) and only 2 of them exist in shared dev
(`RefundCurrencyId`, `ManualPaymentModeId`, which came from elsewhere). The file is dead code
that describes a schema nobody has.

The squash deletes it along with everything else, which is the right outcome — but decide
consciously: either the Refund v2 feature is abandoned (delete and move on), or those columns
need to be added to the entity configuration and migrated properly. Do not let the squash make
that decision silently.

### K.5 Finding #4 — shared dev has a migration this repo does not

`20260817110605_Remove_EnabledPaymentMethodsJson_EventRegistrationPagesEntity` is applied on
shared dev, but no ref in the backend clone contains that file
(`git log --all --diff-filter=A` → nothing). Consistent with the schema: shared dev has
**dropped** `EnabledPaymentMethodsJson` from `EventRegistrationPages`, while `module/case`'s
model still declares it — and so does the generated baseline (4 hits).

So the branch model and shared dev genuinely disagree about that column. Pre-existing, not
caused by the squash, but it means **a baseline cut from `module/case` does not describe shared
dev**. Confirm which branch is the real source of truth before squashing, and reconcile.
`rollback-restore-migration-history.sql` has been given this row so a rollback restores shared
dev exactly (196 rows, not 195).

### K.6 Environment facts confirmed

* Shared dev `148.251.86.78:5434 / Pss2.0_Dev_latest` — **at OLD_HEAD**, PostgreSQL **16.13**,
  418 base tables across 20 schemas, 196 history rows, `ProductVersion` `10.0.0`.
  A throwaway verification DB should therefore be **PG 16**, not the local PG 17.
* Azure dev `devpsscore.postgres.database.azure.com` — **NXDOMAIN, genuinely dead.** Not a
  re-stamp target; the commented connection string can be removed.

### K.7 Steps not reached

Because of K.3, the rehearsal stopped before: pasting the carry-forward block into the baseline
(§D-4), the `__ShouldBeEmpty` confirmation (§D-5), the throwaway fresh-DB verification (§D-7),
and the post-squash build timing. Those remain unproven. Re-run this rehearsal after K.3 is
fixed — everything up to the gate is now known to work, so the second pass is quick.
