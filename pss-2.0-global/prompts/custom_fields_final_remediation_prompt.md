# Custom fields — closing remediation: tenant scoping, and indexes that actually exist

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. State the migration; the user creates it.
- Do NOT execute SQL against any database. Idempotent scripts, handed off.
- Do NOT probe ports, processes or API liveness. Do not gate any deliverable on environment readiness.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.

**Collision warning — read first.** `import_custom_fields_prompt.md` has **landed** (staged, not
committed). Its output is now the baseline you build on, not a moving target. Part 3 below carries the
five gaps that verification found in it, and Part 3 is the ONLY part licensed to touch
`Base.Infrastructure/Services/Import/**` or the import SQL functions — Parts 1 and 2 still must not.

You will *read* `ImportCustomFieldResolver.cs` — its tenancy predicate is the reference implementation
for Part 1 § C — and you do not change it; it is correct.

**One live collision remains.** `import_code_generation_prompt.md` (staged, not yet run) § A.1 also has
to resolve which of the three contact execute copies is canonical, and then edits it. Part 3 § J below
answers the same question. Whichever runs first records the answer in its report; the second must read
that answer and not re-derive it, and **only one of the two may edit
`ContactImport-fn-execute*.sql`**. If you find that prompt's changes already applied, do § J's
identification and reporting but leave the file alone.

This is the last remediation pass on custom fields. Three parts; do 1 and 2 in order, because Part 2's
index names depend on Part 1's uniqueness outcome. Part 3 is independent of both and may be done first
— G1 is a production-breaking defect and should not wait behind index work.

---

# THE FACT THAT DRIVES BOTH PARTS

**There are no EF global query filters anywhere in this solution.** Zero `HasQueryFilter` calls exist.
Tenant scoping is entirely explicit predicates in each query.

Three separate places in the custom-field code assert the opposite and reason from it:

| File | What it claims |
|---|---|
| `CreateCustomField.cs:76-78` | *"dbContext already applies the tenant query filter"* — so the definition count is left unfiltered |
| `CustomFieldIndexPlanner.cs:30-36` | *"The global query filter emits `(@tenant IS NULL) OR ("CompanyId" = @tenant)`"* — used to reject partial indexes |
| `custom-fields-jsonb-normalise.sql:36` | *"no global tenant query filter"* — correct, stated as a property of that one table |

**Verify this yourself before anything else.** Use PowerShell `Select-String` across both nested repos
and show the exact command in your report — the Grep tool has silently missed nested-repo files in this
codebase before, and everything below depends on the answer. If you find a query filter, STOP and
report; the rest of this prompt is then wrong and must not be applied.

Correct every false claim you touch. Do **not** delete the surrounding comment blocks — they contain
genuinely good reasoning that is worth keeping. Only the tenancy premise is wrong.

**Do not "fix" this by adding a global query filter.** The absence is a codebase-wide architectural
fact; introducing one here would change behaviour far beyond custom fields. Report if you think one
should exist. Do not add it.

---

# PART 1 — Per-tenant custom field names

## The decision

The user has decided:

> **System fields keep a single global name. Custom fields are unique per company.**

`Field.IsSystem` is the discriminator, `Field.CompanyId` is the scope. Both columns already exist on
the entity (`Field.cs:17-18`) — this task does not add them.

Today `CreateCustomFieldValidator` enforces `FieldName` uniqueness **globally across `sett."Fields"`**
(`CreateCustomField.cs:26`), with no `IsSystem` and no `CompanyId` predicate. So tenant A creating
"Region" permanently blocks tenant B from ever creating one. That is the bug.

## A. Facts to establish first

Report each with the file and line you read it from.

1. **`Field.CompanyId` is auto-stamped, not handler-set.** `CreateCustomFieldHandler` never assigns it;
   `TenantSaveChangesInterceptor` stamps it from `GetEffectiveCompanyId() ?? GetCurrentTenantId()`.
   Read that interceptor, confirm the precedence, and confirm `Field` is not on any exclusion list it
   maintains.

2. **What happens when neither is available.** The interceptor leaves `CompanyId` null for a SuperAdmin
   with no `EffectiveCompanyId`. A null-`CompanyId` field is treated by `ImportCustomFieldResolver` and
   `CustomFieldRegistry.GetFilterableKeysAsync` as **a platform-wide declaration every tenant
   inherits**. Confirm that reading. This is the single most important fact in Part 1: it means a field
   created from a SuperAdmin context silently appears in every tenant's schema, import template and
   filterable-key set. State whether that path is reachable through the current `CreateCustomField`
   authorization, and if so, what you did (§ D).

3. **No query filters** — the verification above.

## B. The uniqueness rule

- `IsSystem = true` → `FieldName` unique **globally**. A custom field must not be allowed to collide
  with a system field name: the two share `FieldCode`/`FieldKey` space and a collision would make the
  custom field indistinguishable from a platform one downstream.
- `IsSystem = false` → `FieldName` unique **per `CompanyId`**.

Requirements:

- **Enforce in both places.** The validator produces a clean message; a **unique index** is what
  actually guarantees it under concurrency — a validator-only check loses to two simultaneous requests.
- **Handle `NULL` `CompanyId` deliberately.** In PostgreSQL a plain unique index treats NULLs as
  distinct, so `(CompanyId, FieldName)` enforces *nothing* among platform-scoped rows. Decide and
  justify: `NULLS NOT DISTINCT` (PG15+ — state the version requirement), a `COALESCE(CompanyId, 0)`
  expression index, or two partial indexes split on `IsSystem`.
- Match how `FieldName` is actually stored — it carries `[CaseFormat("title")]`. Read what that
  attribute does before deciding whether a case-insensitive index is needed or redundant.
- **`FieldCode` and `FieldKey` are derived from `FieldName`** (`CreateCustomField.cs:125-140`). If two
  tenants may both hold "Region", both derive `FieldCode = 'REGION'` and `FieldKey = 'region'`. **State
  explicitly whether anything assumes those are globally unique** — grep for lookups by either column
  that do not also filter by company or grid. Any such lookup is a defect this change exposes: fix it
  if small, report it precisely if not. Note that `FieldKey` is the jsonb document key, so two tenants
  sharing a key is expected and fine; a *lookup* that resolves a key to the wrong tenant's `FieldId` is
  not.

**Pre-existing duplicates.** Deliver an idempotent audit query under `sql-scripts-dyanmic/` listing
rows that would violate the new index, grouped into system-vs-system, custom-vs-custom within a
company, and custom-vs-system. The index cannot be created while duplicates exist, so this runs first.
Do **not** write anything that renames or deletes — report the rows, the user decides.

## C. The definition count is currently global

```csharp
var existingCustomFields = await dbContext.Fields
    .CountAsync(f => f.FieldSource == "Custom" && f.IsDeleted == false, cancellationToken);
```

No `CompanyId` predicate, justified by the false query-filter claim. So **one tenant's definitions
consume every other tenant's ceiling**, and it tightens for everyone as the platform grows.

Scope it to the tenant, matching the tenancy predicate `ImportCustomFieldResolver` uses — read it and
follow it rather than inventing a second one, so the ceiling and the import plan agree on who owns a
field. Decide and justify whether null-`CompanyId` (inherited) fields count against a tenant's ceiling.

Keep the surrounding comment block — its explanation of why the per-entity cap belongs in
`AddCustomFieldGridSchema` is correct. Replace only the tenancy paragraph.

Then confirm the per-entity ceiling in `AddCustomFieldGridSchema` is itself tenant-scoped, on the same
reasoning. If it is not, fix it and report it.

## D. The SuperAdmin null-CompanyId path

If § A.2 shows a field can be created with a null `CompanyId` through the normal command path, that is
a live cross-tenant leak. Decide and argue one of:

- **Reject** — `CreateCustomFieldHandler` requires a resolvable tenant and errors clearly otherwise.
  Platform-wide fields, if ever wanted, get a separate deliberate path.
- **Allow, but explicitly** — a platform-wide field must be an intentional flag on the request.

Reject is almost certainly right: a leak that happens by *omission* is the worst shape. Argue whichever
you choose. Do not leave behaviour that depends on whether a context happened to be present.

## E. Frontend

Minimal. If the uniqueness error is surfaced, it must say the name is in use **in this organisation**
rather than implying a global namespace. No other frontend change in Part 1.

---

# PART 2 — The index planner has no caller

`CustomFieldIndexPlanner` is registered at `Base.Infrastructure/DependencyInjection.cs:53` and **called
by nothing** — no endpoint, no query, no startup hook, no command. Its DDL has therefore never been
emitted, so **not one custom-field index exists** and every custom-field filter and sort is a
sequential scan on a 500,000-row table.

This matters more now that plan tiering has shipped: `CUSTOM_FIELDS_FILTERABLE` is sold to tenants as
an *index budget*, priced per plan on the cost of B-tree expression indexes. Today it budgets indexes
that are never created. The meter is honest only once this part is done.

## F. Give it a caller

The class is deliberately an **emitter, not an executor**, and that stays true — read its own reasoning
at the top of the file, which is sound. `CREATE INDEX CONCURRENTLY` cannot run inside a transaction
block, which is exactly why this is not an EF migration.

Build the path that gets the DDL in front of a human. Choose ONE and argue it:

- **Platform-admin endpoint** returning the generated DDL as text/a downloadable `.sql` for review.
  Must be restricted to platform staff, not tenant admins — the output names real schemas and tables.
- **A CLI / startup-flag emit to a file** under `sql-scripts-dyanmic/`, run deliberately, never on
  normal boot.

Whichever you pick: it emits, a human reviews, a human runs it. Nothing in this task executes DDL.

Requirements:

- Cover both `GenerateDdlAsync(entityName, companyId)` and `GenerateAllAsync(companyId)`.
- Authorization is backend-enforced, not route-obscurity. State the capability/policy you used and
  whether it already existed.
- The output must be safe to hand to a DBA unedited: header comment stating it must run outside a
  transaction, statement-per-line, `IF NOT EXISTS` throughout.

## G. Correct the partial-index reasoning

`CustomFieldIndexPlanner.cs:30-36` rejects per-tenant partial indexes because *"the global query filter
emits `(@tenant IS NULL) OR ("CompanyId" = @tenant)`"*. **That filter does not exist.**

The conclusion — a `CompanyId`-leading composite B-tree rather than one partial index per tenant — is
still right, but for different reasons (index count scaling with tenant count, DDL on every tenant
onboard, planner overhead). Re-argue it from what the code actually does: read how a real custom-field
filter query is built in `GridQueryBuilderHelper` / `CustomFieldFilterScopeBuilder`, state the predicate
that actually reaches PostgreSQL, and rewrite the comment to match. If the real predicate turns out to
make partial indexes *viable*, say so plainly rather than preserving the original conclusion.

## H. Prove the indexes are used

`sql-scripts-dyanmic/custom-fields-jsonb-plan-verification.sql` already holds the `EXPLAIN` set. Make
sure it covers the shape this part produces:

- An `ORDER BY` on a custom field → the raw-expression index.
- A case-insensitive `WHERE` → the `lower(...) text_pattern_ops` index.
- A prefix/global search → the same `text_pattern_ops` index.
- A key-existence / containment probe → the `jsonb_path_ops` GIN index.

The failure signature to call out in the file is `Seq Scan` where `Index Scan` was expected, which is
what a structural expression mismatch looks like: no error, no warning, just a slow query. State in
your report which query shapes the verification file does **not** cover, if any.

Do not run these. The user runs them.

## I. Ordering

The emitted DDL depends on `GetFilterableKeysAsync`, which resolves per company. Part 1 may change
which fields a company owns. State the required run order in your report: Part 1 migration → Part 1
audit clean → regenerate DDL → review → run outside a transaction → `EXPLAIN` verification.

---

# PART 3 — Gaps left by the import custom-fields build

`import_custom_fields_prompt.md` delivered 24 backend files and 5 frontend files, and most of it is
sound: the link column, the five tenant-resolved `GenerateFieldsAsync` callers, the collision
assertion, the `import.session_fields` snapshot with its verified fallback to live
`import."ImportGridFields"` for pre-feature sessions, the removal of the raw `CustomFields`
passthrough, the `ContactCustomFieldValueDto` read path, `BULKDONATION` deliberately NULL, the
`ISettingDbContext` read, and `sanitizeCell` on both label and value. None of that needs revisiting.

Four things were left. They are stated below as findings, with file and line, so you verify rather
than trust them — the same rule that produced them.

## J. The stale contact execute copy will fail every row (HIGH)

`corg."Contacts"."CustomFields"` became `jsonb` in migration
`20260817091615_Change_Text_To_JsonB_To_CustomFields_In_Contact_Entities`. PostgreSQL has **no
assignment cast from `text` to `jsonb`**, so any execute function still holding the value in a `TEXT`
variable fails the row INSERT with **SQLSTATE 42804 — on every row, for every tenant.** Not a
degraded import: a total one.

`ContactImport-fn-execute.sql` was fixed (`v_custom_fields JSONB`, reads
`import.build_custom_fields_json`). Two other copies of the same function exist:

- `Base/sql-scripts-dyanmic/ContactImport-fn-execute-current.sql` — still `v_custom_fields TEXT;`
  (line 75), still reads `import.safe_read_staging_field(v_table_name, v_row_id, 'CustomFields')`
  (line 425), still passes it at line 484. **If this is the deployed copy, contact import is broken
  right now.**
- `DatabaseScripts/Functions/import/execute_contact_import.sql` — an older shape entirely, no
  `CustomFields` reference at all.

Do:

1. **Determine which copy the deployed `import.execute_contact_import` came from**, and say how you
   determined it. Do not guess from filenames — `-current` suffixes are not evidence. Compare
   distinguishing bodies, and if the deployed source cannot be established from the repo, write the
   read-only `pg_get_functiondef('import.execute_contact_import'::regproc)` query and say plainly that
   the user must run it before anything here is safe to deploy. Do not run it.
2. If the live copy is `ContactImport-fn-execute.sql`, the defect is latent — but three copies nobody
   can identify is exactly how it becomes live. **Delete the dead copies** (with
   `ContactImport-fn-validate-current.sql`, already slated) and report it.
3. If the live copy is a stale one, fix that one to match `ContactImport-fn-execute.sql` and say so
   loudly in the report.

Respect the `import_code_generation_prompt.md` collision rule at the top of this file.

## K. `ICustomFieldPolicy` is not consulted anywhere in the import path (MEDIUM)

§ J of `import_custom_fields_prompt.md` required the per-tenant custom-field cap to be resolved
through `ICustomFieldPolicy`. A `Select-String` for `ICustomFieldPolicy` across
`Base.Infrastructure/Services/Import/` and `Base.Support/Import/` returns **zero hits**. Verify that
before acting.

The consequence is a governance hole, not a crash: a tenant whose plan cap was lowered — or who is on
FREE with a 10-field ceiling — still gets **every** field they ever defined in the download template,
in the staging table DDL, and in the validation snapshot. The plan tiering that Part 2's out-of-scope
note calls "built and verified" is verified only on the CRUD path.

Do:

- Resolve the tenant's effective cap through `ICustomFieldPolicy` in the field-plan path, where the
  custom fields are appended (`DynamicFieldGeneratorService` STEP 6 / `ImportCustomFieldResolver`).
  **Backend enforcement, in the service — not in the UI, not in the template writer.** Every one of
  the five callers must inherit it without changing its own code.
- Decide and argue **what happens on breach**, then implement it: silently truncating to the cap
  produces a template missing columns with no explanation, which is the failure mode the whole
  feature was built to avoid. State whether you truncate deterministically (and by what ordering, so
  the same fields are dropped every run), or fail the operation, and why. Whichever you choose, it
  must be visible — a logged warning at minimum, surfaced to the user if the path allows it.
- Say explicitly whether inherited null-`CompanyId` fields count against the cap, and keep that answer
  consistent with Part 1 § C's decision on the definition count. Two different answers to the same
  question in two code paths is the defect, not the number itself.

## L. `ImportCommon-fn-validate.sql` was re-encoded (LOW, mechanical)

The staged diff shows a **UTF-8 BOM prepended at line 1**, and every em-dash in the comment blocks
double-encoded (`—` → `â€"`, 10 occurrences). A per-file scan of all 24 staged backend files confirms
this is the only affected file.

Restore it to BOM-less UTF-8 with real em-dashes. Nothing else in the file changes. Then say what
introduced it — a PowerShell `Out-File`/`Set-Content` without `-Encoding utf8` is the usual cause —
because it will recur on the next SQL edit otherwise.

## M. The `CustomFieldGridCode` migration gate (TRACKING)

`ImportGridDefinition.CustomFieldGridCode` (`string?`, max 50, deliberately not an FK) has **no EF
migration** — the user creates it. `ImportCustomFields-seed.sql` guards on the column existing and
`RAISE NOTICE`s a skip when it is absent, so running the seed first is a silent no-op that looks like
success.

State the run order explicitly in your report, and confirm the seed's guard actually behaves that way
by reading it: **migration → `ImportCustomFields-seed.sql` → verify
`SELECT "GridCode","CustomFieldGridCode" FROM import."ImportGridDefinitions";` shows `CONTACT` mapped
and `BULKDONATION` NULL.** Do not run any of it.

## N. `ImportSessionFields` is a hand-scripted table and should be an EF entity

`sql-scripts-dyanmic/ImportSessionFields-create-table.sql` line 71 does
`CREATE TABLE IF NOT EXISTS import."ImportSessionFields"` plus a unique index. There is **no entity,
no `DbSet`, no migration** — `Select-String` for `ImportSessionField` across `*.cs` returns nothing.

That breaks the house pattern set by its own sibling in the same folder:
`ImportExecutionResults-create-table.sql` exists alongside
`Base.Domain/Models/ImportModels/ImportExecutionResult.cs`, a `DbSet` on `IImportDbContext` /
`ImportDbContext`, and a snapshot entry at `ApplicationDbContextModelSnapshot.cs:17552`.

"C# never reads this table" is not a reason to skip it. Only PL/pgSQL touches it, which is a statement
about the access path, not about schema ownership. The migration is what makes the schema deployable
and ordered: without one, a new environment depends on someone remembering to run a loose script
before the functions that need it, and `__EFMigrationsHistory` has no record of whether they did. The
genuinely dynamic object in this subsystem is the per-session **staging** table, whose columns are
computed at parse time — that one cannot be an entity, and that reasoning appears to have been
over-applied here.

Do:

1. Add `Base.Domain/Models/ImportModels/ImportSessionField.cs` mirroring the DDL exactly — including
   `AllowedValuesJson` as `jsonb` (not `text`; see § J for what a text/jsonb mismatch costs),
   `CapturedAt` as `timestamptz` with the `NOW()` default, the FK to `ImportSession` with
   `ON DELETE CASCADE`, and the `("ImportSessionId","FieldName")` unique index. Model it on
   `ImportExecutionResult.cs` and its configuration, not from scratch.
2. Register the `DbSet` on `IImportDbContext` and `ImportDbContext`.
3. **State the migration for the user to create. Do not run `ef migrations add`, do not edit the
   model snapshot.**
4. Reduce the SQL script to the two functions only and rename it accordingly (e.g.
   `ImportSessionFields-fn-snapshot.sql`). Keep it idempotent. The functions stay raw SQL — EF cannot
   own PL/pgSQL.
5. **Deployment ordering matters and must be stated:** the migration creates the table, and only then
   may the function script run. If the table already exists in an environment from the current
   script, the new migration will try to re-create it — say explicitly how that is handled (an
   `IF NOT EXISTS`-guarded `migrationBuilder.Sql()`, or a documented manual step), because DEV/UAT
   have probably already run the script.

Apply the same test to anything else Part 3 touches: a fixed-schema permanent table belongs to EF; a
per-session computed table and every PL/pgSQL function do not. Report any other table you find on the
wrong side of that line — do not fix it here.

## O. Two things verification could not reach

Close these by reading, and report the finding either way.

1. **`ImportCustomFieldNaming` (§ C of the import prompt).** Confirm `BuildFieldName` handles the
   PostgreSQL **63-byte identifier limit** by truncation that cannot collide (the `_{fieldId}` suffix
   must survive truncation, or two long field keys collapse to one column), and that non-ASCII and
   quote characters in a tenant-supplied `FieldKey` cannot produce an identifier that breaks the
   generated DDL. The staging DDL is built by string concatenation; a field key is tenant-controlled
   input. Treat this as an injection surface, not a cosmetic naming question.
2. **The nine negative scenarios (§ I of the import prompt).** They were specified and not evidenced.
   Walk them, state which are structurally impossible now (with the code that makes them so) and which
   are merely untested, and deliver the untested ones as a read-only or rolled-back verification
   script under `sql-scripts-dyanmic/`. Do not run it.

---

## Explicitly out of scope

- Anything under `Base.Infrastructure/Services/Import/**` or the import SQL functions **except the
  four gaps named in Part 3**. Parts 1 and 2 touch none of it.
- Anything `import_code_generation_prompt.md` owns — `ContactCode` / `ReceiptNumber` generation,
  `import.generate_sequence_number`, step 5e. Part 3 § J identifies the canonical execute file; it
  does not implement code generation.
- Any change to `MaxValueLength`, `MaxDocumentBytes`, `MaxDocumentKeys` — engine limits, global by
  design.
- Any change to the **implementation** of `CustomFieldPolicy` / `ICustomFieldPolicy` /
  `CustomFieldPolicyOptions` / `CustomFieldMeterCodes` / `MeterCodes` / `GovernanceMeterCodes`. Plan
  tiering is built and verified. Part 3 § K **consumes** that service from the import path; it does
  not modify it. If you conclude the interface genuinely cannot serve the import path as it stands,
  stop and report rather than changing it.
- The governance quota seed values — the user owns those numbers.
- Adding an EF global query filter.
- Executing any DDL or SQL.

## Output

Stage everything (`git add` in each affected repo). Report:

1. The `Select-String` command proving zero `HasQueryFilter`, and every false tenancy claim you
   corrected, with file and line.
2. The three Part 1 § A facts, each with file and line.
3. The uniqueness rule as implemented, in both validator and index.
4. The NULL-`CompanyId` index approach, why, and its PostgreSQL version requirement.
5. Whether anything assumes `FieldCode` / `FieldKey` is globally unique, and what you did.
6. The exact migration the user must create — index name, columns, expression, partial predicate — and
   the audit script filename that must run before it.
7. The tenant-scoping predicate applied to the definition count, and whether inherited null-`CompanyId`
   fields count against a tenant's ceiling, with reasoning.
8. Whether `AddCustomFieldGridSchema`'s per-entity ceiling was already tenant-scoped.
9. Your decision on the SuperAdmin null-`CompanyId` path, and the argument.
10. The DDL-emission path you chose, why, and the authorization enforcing it.
11. The re-argued partial-index reasoning, based on the predicate that actually reaches PostgreSQL.
12. Which query shapes `custom-fields-jsonb-plan-verification.sql` does not cover.
13. The required run order.
14. Confirmation you edited no migration file and no model snapshot, and nothing outside Parts 1–3.
15. **Part 3 § J** — which contact execute copy is live, how you determined it, whether the 42804
    defect is latent or live, what you fixed, and what you deleted.
16. **Part 3 § K** — the `Select-String` result for `ICustomFieldPolicy` in the import path, where you
    resolved the cap, your breach behaviour with its argument, and the inherited-field answer matched
    against Part 1 § C.
17. **Part 3 § L** — confirmation `ImportCommon-fn-validate.sql` is BOM-less UTF-8 again, and what
    introduced the re-encoding.
18. **Part 3 § M** — the migration the user must create and the migration → seed → verify run order.
19. **Part 3 § N** — the `ImportSessionField` entity and `DbSet`, the migration the user must create,
    how an environment that already ran the create-table script is handled, the reduced function-only
    script's new name, and any other fixed-schema table you found created outside EF.
20. **Part 3 § O** — the 63-byte/quoting/non-ASCII finding for `ImportCustomFieldNaming`, and the
    negative-scenario walk split into structurally-impossible vs merely-untested.
21. Anything you could not complete and why.
