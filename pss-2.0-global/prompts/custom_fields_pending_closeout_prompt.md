# Custom fields — pending close-out: the unique index, the migration gate, and the gated deletions

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT execute SQL against any database. Do NOT run any `.sql` file. Idempotent scripts, handed off.
- Do NOT probe ports, processes or API liveness. Do not gate any deliverable on environment readiness.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.

**Migrations: the standing "user creates migrations" rule is LIFTED for this session, once.** You will
create migrations here, under the constraints in § A. It is lifted for this task only and does not
carry to anything else.

---

## What is already done — do not redo it

`prompts/custom_fields_final_remediation_prompt.md` ran and landed as commit `9a2284ef`
(`PSS_2.0_Backend`). Verified at code level: the per-tenant validator, the tenant-scoped definition
count, the SuperAdmin null-`CompanyId` rejection, the corrected query-filter comments in all three
places, `GetCustomFieldIndexDdl` as the index planner's first caller, the re-argued partial-index
reasoning, `ICustomFieldPolicy` consumed in `ImportCustomFieldResolver`, `ImportCommon-fn-validate.sql`
restored to BOM-less UTF-8, the `ImportSessionField` entity + configuration + `DbSet` on both
`ImportDbContext` and `IImportDbContext`, the script reduced to functions and renamed
`ImportSessionFields-fn-snapshot.sql`, and the 63-byte identifier budget in `ImportCustomFieldNaming`.

None of that needs revisiting. Read it as the baseline. If you believe any of it is wrong, report —
do not rewrite it.

Four things remain. They are stated below as findings, with file and line, so you verify rather than
trust them.

---

# A. Migration constraints

These apply to every migration in this prompt.

- **Do not hand-author a migration file from nothing.** Use `dotnet ef migrations add <Name>` from the
  correct startup project so the `Designer.cs` and `ApplicationDbContextModelSnapshot.cs` are generated
  consistently. A hand-written migration with a stale snapshot corrupts every migration after it.
- Migrations live in `PSS_2.0_Backend/.../Base.Infrastructure/Migrations/` — **not** `Data/Migrations/`,
  which exists but is empty. Confirm before you generate.
- **Then edit the generated `Up`/`Down` by hand** where this prompt says so. Expression indexes and
  partial indexes cannot be expressed through `HasIndex()` and must be `migrationBuilder.Sql()`.
- **Do not edit `ApplicationDbContextModelSnapshot.cs` by hand.** Whatever the tool generated stands.
- Every migration must have a working `Down`. State it.
- Report the exact `dotnet ef` command you ran and its output.

---

# B. The old unique index defeats the whole of Part 1 (HIGH)

`Base.Infrastructure/Data/Configurations/SettingConfigurations/FieldConfiguration.cs:17`:

```csharp
builder.HasIndex(o => new { o.FieldName, o.FieldCode, o.FieldKey, o.IsActive }).IsUnique();
```

Present in the model snapshot at `ApplicationDbContextModelSnapshot.cs:27499-27502`. That index was
not touched by `9a2284ef` — the file is absent from the commit. It is a **global** unique constraint
on the name triple, so tenant B creating "Region" now passes `CreateCustomFieldValidator` (which was
correctly rescoped) and then fails in PostgreSQL with 23505. The user-visible result is worse than
before the remediation: the same block, but surfaced as an opaque database error instead of the clean
"already exists in this organisation" message.

`FieldCode` and `FieldKey` are derived from `FieldName`, so the triple adds no discriminating power
over `FieldName` alone — two tenants with "Region" collide on all three columns identically.
`IsActive` does not save it either: both rows are active.

Do:

1. **Remove that `HasIndex` line** from `FieldConfiguration.cs`. Leave the `HasMaxLength` and
   `IsRequired()` on `FieldName` alone. Keep any other index on the entity that is not this one —
   read the whole file before deleting anything.
2. **Confirm nothing depended on it.** Grep for the index name and for any code that catches 23505 /
   `PostgresException` around field creation and relies on the DB to enforce the name rule. If
   something does, it must move to the validator's rule or be re-pointed at the new indexes.
3. **Create the migration.** It must do three things in `Up`, in this order:
   - drop the old index (the tool will generate this from step 1 — verify it did, and that it names
     the right index; EF's generated name for that `HasIndex` is derived from the column list)
   - `migrationBuilder.Sql()` creating `ux_fields_system_name`
   - `migrationBuilder.Sql()` creating `ux_fields_custom_name`

   The two index definitions are specified in full — expression, partial predicate and the
   `COALESCE("CompanyId", 0)` reasoning (it avoids `NULLS NOT DISTINCT`, which needs PostgreSQL 15) —
   in `sql-scripts-dyanmic/custom-fields-00-RUN-ORDER.sql` track A2, and again in the header of
   `sql-scripts-dyanmic/custom-fields-name-uniqueness-audit.sql`. **Read them and copy them exactly;
   do not re-derive them.** If you think either is wrong, report before changing it.

   `Down` restores the old index and drops the two new ones.

   Note `CREATE UNIQUE INDEX` here is deliberately **not** `CONCURRENTLY` — a migration runs inside a
   transaction and `CONCURRENTLY` cannot. That is correct for these two; state that you checked.

4. **The migration must not be applied before the audit is clean, and it cannot enforce that itself.**
   `custom-fields-name-uniqueness-audit.sql` sections 1 and 2 list the rows that make the
   `CREATE UNIQUE INDEX` fail with 23505. Put a comment at the top of the generated migration saying
   so, naming the audit file. State the same in your report.

5. **Update `custom-fields-00-RUN-ORDER.sql` track A2** to include the drop. Today A2 describes
   creating the two indexes and says nothing about the incumbent, which is how this was missed. That
   file is the checklist a human follows at 2am; an incomplete step there is the defect.

**Argue, do not assume:** the two new indexes deliberately do not enforce the cross-partition rule (a
custom field may not reuse a system field's name) — that spans both partial indexes and lives only in
the validator. The run-order file already states this as a known and accepted limit. Confirm you have
not changed that trade-off, and say so.

---

# C. The `ImportSessionField` migration contradicts its own deployment note (HIGH)

`Base.Infrastructure/Migrations/20260817154323_Add_ImportSessionField.cs` exists and carries both the
`ImportSessionFields` table and the `ImportGridDefinitions.CustomFieldGridCode` column — so tracks C0
and C1 are one migration, not two. That part is fine and must not be split.

But it creates the table with `migrationBuilder.CreateTable`. `custom-fields-00-RUN-ORDER.sql` track C0
says, of this exact migration:

> DEV and UAT have probably already run the old script, so the table exists there. The migration must
> therefore be written with IF NOT EXISTS-guarded `migrationBuilder.Sql()`, NOT
> `migrationBuilder.CreateTable`

The retired `ImportSessionFields-create-table.sql` did `CREATE TABLE IF NOT EXISTS
import."ImportSessionFields"`. If any environment ran it, this migration throws **42P07 duplicate
table** and the whole migration rolls back — including the `CustomFieldGridCode` column, which is not
otherwise blocked. One unrelated failure takes out both halves.

Do:

1. **Establish whether the migration has already been applied anywhere.** You cannot query the
   database. Write the read-only check the user must run, covering both facts that matter, and say
   plainly that it must be run before this migration is deployed:
   - is `20260817154323_Add_ImportSessionField` in `__EFMigrationsHistory`
   - does `import."ImportSessionFields"` exist (`to_regclass`)

   The four combinations are not equally safe and you must state what each one means and what to do:
   applied+exists (nothing to do), not-applied+not-exists (current file would work as-is),
   **not-applied+exists** (the failure case this section is about), applied+not-exists (a rolled-back
   or hand-edited history — stop and report).

2. **Rewrite the table creation as an `IF NOT EXISTS`-guarded `migrationBuilder.Sql()`**, matching the
   generated `CreateTable` column-for-column — the DDL must produce the identical schema, including
   the identity column strategy, every default, the `jsonb` on `AllowedValuesJson`, the
   `timestamp with time zone` + `NOW()` on `CapturedAt`, the cascade FK to `ImportSessions`, the
   unique index on `("ImportSessionId","FieldName")`, and the four audit columns. Guard the index and
   the FK the same way — a table that already exists may already have them.

   This is the one place in this prompt where you edit an existing migration file rather than
   generating one. Do not regenerate it and do not renumber it; it may already be applied somewhere.
   Do not touch the snapshot — the model is unchanged, only the DDL that reaches PostgreSQL.

3. **State whether the `AddColumn` for `CustomFieldGridCode` needs the same guard.** Decide by reading
   whether anything other than this migration ever created that column. Argue it; do not guard
   reflexively.

4. `Down` must stay correct after your edit.

---

# D. The gated deletions — three copies of one function (HIGH, blocked)

`ContactImport-fn-execute-IDENTIFY.sql` was written and **has not been run**. Until it is, nobody
knows which of these is installed as `import.execute_contact_import`:

- `sql-scripts-dyanmic/ContactImport-fn-execute.sql` — `v_custom_fields JSONB` (line 121), reads
  `import.build_custom_fields_json`. Correct.
- `sql-scripts-dyanmic/ContactImport-fn-execute-current.sql` — `v_custom_fields TEXT` (line 75), reads
  `import.safe_read_staging_field(...)` (line 425). **If this is the deployed copy, every contact
  import fails every row with SQLSTATE 42804**, because `corg."Contacts"."CustomFields"` became
  `jsonb` in migration `20260817091615_Change_Text_To_JsonB_To_CustomFields_In_Contact_Entities` and
  PostgreSQL has no assignment cast from `text` to `jsonb`.
- `DatabaseScripts/Functions/import/execute_contact_import.sql` — older shape, no `CustomFields` at all.

You cannot run the identify script. Do NOT delete anything on a guess — `-current` in a filename is
not evidence of deployment.

Do:

1. **Try to settle it from the repository instead**, and report either way. Git history is evidence
   the identify script cannot give you: which copy was last modified, by which commit, and whether any
   deployment script, Dockerfile, CI step, README or runbook in either repo references one of the
   three paths. `grep -rn` for each filename across both repos. If a deploy step names one of them,
   that is the answer and you should say so with the file and line.
2. If the repository settles it, **fix or delete accordingly** — if the live copy is a stale one, fix
   that one to match `ContactImport-fn-execute.sql` and say so loudly; if the live copy is the correct
   one, delete the dead copies together with `ContactImport-fn-validate-current.sql`, already slated.
3. If it does not settle it, **change nothing** and hand back the exact identify-script invocation plus
   the one-line `pg_get_functiondef('import.execute_contact_import'::regproc)` query, stating that
   contact import must not be trusted until it is run.

**Collision rule.** `prompts/import_code_generation_prompt.md` (staged, not yet run) § A.1 answers the
same question and then edits the same file. Only one of the two may edit
`ContactImport-fn-execute*.sql`. If you find that prompt's changes already applied, do the
identification and reporting and leave the file alone.

---

# E. Verify what the previous pass could not

Read-only. Report the finding either way; fix only what is small and clearly wrong.

1. **The frontend uniqueness message.** `flb-custom-field-manager.tsx:81-82` carries the § E comment
   about surfacing "already exists in this organisation". Confirm the component actually renders the
   backend's message rather than substituting a generic one, and that no other create-custom-field
   surface (grid config, reference sheet, form layout builder) hardcodes a "name already exists"
   string implying a global namespace. Frontend only — the rule is enforced in the backend and stays
   there.

2. **`FieldCode` / `FieldKey` global-uniqueness assumptions.** Grep for lookups by `FieldCode` or
   `FieldKey` that do not also filter by company or grid. Two tenants sharing a `FieldKey` is expected
   and fine — it is the jsonb document key. A *lookup* that resolves a key to the wrong tenant's
   `FieldId` is a live cross-tenant defect that B's index change makes reachable. Fix if small, report
   precisely if not.

3. **`custom-fields-jsonb-plan-verification.sql` coverage.** State which of the four shapes in Part 2
   § H it does not cover: `ORDER BY` on a custom field, case-insensitive `WHERE`, prefix/global
   search, and a key-existence/containment probe. Do not run it.

---

## Explicitly out of scope

- Re-implementing anything listed under "What is already done".
- Any change to the **implementation** of `CustomFieldPolicy` / `ICustomFieldPolicy` /
  `CustomFieldPolicyOptions` / `CustomFieldMeterCodes` / `MeterCodes` / `GovernanceMeterCodes`.
- The governance quota seed values — the user owns those numbers.
- `MaxValueLength`, `MaxDocumentBytes`, `MaxDocumentKeys` — engine limits, global by design.
- Adding an EF global query filter. There are zero `HasQueryFilter` calls in this solution and that is
  an architectural fact, not an oversight; every `HasQueryFilter` string in the codebase is a comment
  asserting exactly that.
- Executing any DDL or SQL, including the audit, the identify script and the negative scenarios.
- `prompts/import_code_generation_prompt.md`'s territory — `ContactCode` / `ReceiptNumber` generation,
  `import.generate_sequence_number`, step 5e.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. The `dotnet ef migrations add` command you ran, its output, and confirmation you did not hand-edit
   the model snapshot.
2. § B — the removed `HasIndex`, anything that depended on it, the generated drop statement and the
   name of the index it drops, and the two `Sql()` index statements as they appear in the migration.
3. § B — confirmation the cross-partition rule is still validator-only, and the run-order A2 edit.
4. § C — the read-only check for the user, the four outcome combinations and what each means, the
   guarded `Sql()` rewrite, and your decision on whether `CustomFieldGridCode` needs the same guard
   with the argument.
5. § D — what the repository evidence showed, which copy you concluded is live and on what basis, what
   you fixed or deleted, and whether the 42804 defect is latent, live, or still unknown.
6. § E — the three verification findings.
7. The complete run order the user must now follow, end to end, including which steps are read-only
   and which are irreversible.
8. Anything you could not complete and why.
