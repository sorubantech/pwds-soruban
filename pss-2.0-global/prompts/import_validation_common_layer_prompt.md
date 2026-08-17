# Import validation — extract a common rules layer

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`
Scope: **validation only.** `ImportProcedure` (execution) is out of scope — do not touch the execute functions.

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`.
- Do NOT execute SQL against any database. Produce idempotent scripts and hand them off.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Correctness over convenience.

---

## Current state — read before designing

Validation dispatches by name: `ImportGridDefinition.ValidationProcedure` holds a function name and the job calls it. There is **one function per grid and no shared layer**.

| Grid | Seeded function | Script | Lines |
|---|---|---|---|
| CONTACT | `import.validate_contact_data` | `sql-scripts-dyanmic/ContactImport-fn-validate.sql` | 1,653 |
| BULKDONATION | `import.validate_bulk_donation_data` | `sql-scripts-dyanmic/BulkDonationImport-fn-validate.sql` | 564 |

The two are architecturally divergent, not merely duplicated:

- **Contact is metadata-driven and set-based.** STEP 5–13 each read `import."ImportGridFields"` and apply one rule class over the whole batch: required (5), child-required (6), conditional (7), data type (8), max length (9), regex (10), MasterData lookup (11), FK lookup (12), `DependsOnField` dependency (13). None of that logic knows it is validating contacts. STEP 13a–13e are the genuinely contact-specific rules (intra-file duplicate on FirstName+LastName+DOB, existing-DB duplicate, child-entity duplicate, combination duplicate).
- **Donation is hardcoded and row-by-row.** `grep -c ImportGridFields` returns **0**. STEP 4 is a ~330-line `FOR` loop with every field and rule spelled out inline (`IF v_donation_date IS NULL OR TRIM(...) = '' THEN`, `ELSIF NOT (... ~ '^\d{4}-\d{2}-\d{2}$')`, etc.).

Also present: `DatabaseScripts/Functions/import/validate_staging_data_dynamic.sql` (719 lines), an apparent earlier attempt at a generic validator. **Nothing references it** — no seed, no C# call. Read it for prior art, then decide explicitly whether to build on it or leave it; say which and why. Do not leave a third unreferenced validator behind.

---

## Target architecture

**Common is the entry point and calls the grid-specific function. Never the reverse.**

The reverse — grid function calls common — is fail-open: any future grid whose author forgets the call silently skips required/type/FK validation, and nothing surfaces until bad data is live. Make skipping common rules structurally impossible.

### Dispatch

`ImportValidationService` **always** calls `import.validate_common(...)`, passing the grid's `ValidationProcedure` value as an argument. C# never calls a grid function directly.

- No new column and **no migration** — `ValidationProcedure` keeps its current meaning (the grid's own function).
- A grid with no business rules passes `NULL`; the orchestrator skips the call.

### Fixed contract

Every grid business function implements one signature so the orchestrator can call any of them uniformly. Choose the exact shape after reading both functions, then apply it to both. It must carry at minimum: session id, staging table name, the row ids to check, company id — and return the number of error rows it wrote.

**`ValidationProcedure` is a data column, so its value is untrusted input. Do not interpolate it into SQL as-is.** Resolve it with `to_regprocedure()` against the exact expected signature first — that returns NULL rather than throwing when it does not match, so it both validates the name and confirms the function implements the contract. Fail closed with a clear error if it does not resolve. Use `format()` with identifier quoting, never string concatenation.

### What moves into `import.validate_common`

1. **The boilerplate** — session/grid/company load, first-batch initialization, batch row-id filter, and the closing summary stats / `has_more` / progress update. Both functions duplicate all of this today; it is a large share of the line count before any rule is deduplicated.
2. **The metadata-driven rules** — lift contact STEP 5–13 essentially as they are. They already work, are already set-based, and are already generic.

### What stays per grid

Only rules that cannot be expressed as field metadata. Contact keeps 13a–13e. Donation keeps its genuine business rules (whatever survives once metadata-expressible checks are removed).

If a rule looks business-specific but is really "required" or "max length" or "lookup" wearing a different name, it belongs in metadata. Say which rules you moved on that basis.

### Execution order — one pass, both sets of errors, no early return

Common and grid-specific validation run **in series within the same call**, and the user sees the combined result:

1. Common rules run over the batch and **record** every issue.
2. **Do not return, do not short-circuit, do not skip the business call because common found errors.**
3. The grid-specific function runs over **the same full batch** and records its issues.
4. Only after both have run does the call return, and the UI receives one complete error list.

The reason is the user's time. Returning after common errors means the user fixes required/length/FK problems, re-uploads a large file, waits through parse and validate again, and only then discovers the business-rule failures. That is two full round trips to learn something we already knew on the first pass.

**This makes defensive evaluation mandatory in the grid-specific function.** It now sees rows with missing, empty and malformed values, so:

- **It must not throw.** An unguarded `::numeric` or `::date` cast on a bad value raises, and because the batch runs in one transaction that rollback destroys the common errors already recorded for the whole batch — the user gets nothing back. Cast defensively throughout.
- **Skip the individual rule, not the whole row.** If a business rule depends on a field that common validation already flagged, that one rule is unevaluable — skip it and let the remaining business rules on other fields still run. Do not skip the row wholesale, and do not emit a derived error whose real cause is the field common already reported. One root cause, one error.
- Where common has already flagged a field, the row's other independent business rules still produce useful errors. That is exactly the point of the single pass.

State in your report how each grid-specific rule decides it is unevaluable, and confirm no cast in either business function can raise on arbitrary staging text.

---

## Donation: metadata first

The donation grid's `ImportGridFields` rows do not currently drive anything, and the hardcoded loop is the only source of truth for its rules.

- Extract every metadata-expressible donation rule (required, type, format/regex, max length, MasterData and FK lookups) into `ImportGridFields` seed rows.
- **Enumerate every rule in the current loop and account for each one**: moved to metadata, kept as business logic, or deliberately dropped with a reason. A rule that silently disappears in this refactor is a data-quality regression that will not surface until bad donation data is imported.
- Deliver as an idempotent seed script. Do not execute it.

Donation should come out substantially smaller and gain regex, max-length and dependency validation it does not have today. Note the newly gained checks explicitly — they may flag rows that previously passed, which the user needs to expect.

---

## Equivalence — the acceptance bar

This refactor is only safe if it changes no rule's behaviour. **A smaller function that validates differently is a failure, not a win.**

- Build a before/after comparison for **both** grids on the same input file, including deliberately bad rows: missing required, wrong type, over-length, bad format, unresolvable FK, unresolvable MasterData, dependency violation, and each duplicate class contact STEP 13a–13e covers.
- Include a row that **fails a common rule and a business rule at the same time, on different fields**. Both errors must come back from a single validation run. This is the case the single-pass design exists for, and the one a short-circuit would silently break.
- Include a row whose business-rule input is malformed (text in a numeric column, garbage date). The batch must complete and still return every other row's errors — proof that no cast raises and takes the transaction down with it.
- Compare the error rows produced — same rows flagged, same error type, same field, same message. Report any intentional difference and why it is an improvement.
- The user runs the comparison. Deliver it as a runnable script plus expected output; do not execute it and do not gate delivery on being able to run it.
- Error messages must stay human-readable — no SQL text, constraint names or stack detail reaching the UI (P1.7).
- `SourceRowNumber` anchoring must survive: errors still report the real spreadsheet row.

---

## Step zero — establish the authoritative file before editing anything

There are **multiple divergent copies of the contact validator on disk**, and editing the wrong one produces a refactor that never runs:

- `sql-scripts-dyanmic/ContactImport-fn-validate.sql` (1,653 lines)
- `DatabaseScripts/Functions/import/validate_contact_data.sql` (~1,750 lines)
- `-current.sql` siblings of both grids in `sql-scripts-dyanmic/`

All define `import.validate_contact_data`. Whichever was applied to the database last is what actually
executes, and the file line counts already tell you they are not the same function.

Before writing a single line:

1. Determine which copy matches deployed behaviour and say how you determined it.
2. Diff the copies and **report every behavioural difference you find** — a rule present in one and absent
   in the other is a live bug regardless of this refactor, and the user needs to know about it.
3. Nominate one authoritative location for validator scripts and move everything there. Delete the stale
   copies as part of this work. Leaving three definitions of one function behind is not acceptable
   output.

Same problem in the DDL layer, for context: `create_staging_table.sql` duplicates the staging DDL that
also lives inside `process_import_upload` steps 3–4, and its own header warns that a divergence between
them is a silent data bug. Do not add a fourth copy of anything.

---

## Config integrity — fix while you are in here

`ImportGridFields.ChildEntityType` joins to `ImportGridChildRelations.ChildEntityType` by **string, with no
foreign key**. `ImportGridFieldConfiguration.cs:73` gives it a non-unique index and nothing else.

The failure mode is silent and total: a misspelled `ChildEntityType` on a field row means no child
relation matches, the field never enters the child loops, and **that column is simply never validated**.
No error, no warning, bad data imports clean.

- Add a constraint that makes an orphaned `ChildEntityType` impossible — a composite FK to
  `ImportGridChildRelations (ImportGridDefinitionId, ChildEntityType)` is the correct shape, which needs
  a unique key on that pair first. If a schema change is genuinely unavoidable, **do not create the
  migration** — state exactly what is needed and hand it to the user.
- If a constraint cannot be added without a migration, deliver at minimum an idempotent config-audit
  query that lists every field row whose `ChildEntityType` matches no relation, and every child relation
  with no `IsPrimaryChildField` field. Wire it in wherever config is validated today.
- Report any orphans the audit finds in the current seed data. Those are columns silently going
  unvalidated right now.

---

## Also verify

- Batching still works — the validation job loops batches; confirm `has_more`, the batch row filter and progress updates behave identically after the move.
- Performance: contact's rules are set-based per batch, and they must stay set-based. Do not convert set-based passes into per-row loops to make the merge easier.
- Re-validation (`ReValidating` 12 → `ReValidated` 13) goes through the same path.
- Staging columns are generated from `ImportGridFields` at parse time and every one is `TEXT`. Common
  validation must keep guarding each column with the `information_schema.columns` existence check before
  referencing it — a config edit between parse and re-validate means the table and the metadata disagree,
  and an unguarded reference raises instead of skipping.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. Which validator copy you established as authoritative and how, every behavioural difference between the copies, and which files you deleted.
2. The `ChildEntityType` integrity fix: constraint added, or the exact migration the user must create; plus any orphaned field rows or child relations the audit found in current seed data.
3. The final contract signature, and how `to_regprocedure` validation and fail-closed behaviour are implemented.
4. Line counts before/after for both grid functions, plus the size of `validate_common`.
5. Every donation rule, mapped: moved to metadata / kept as business logic / dropped with reason.
6. How each grid-specific rule detects that its input is unevaluable, and confirmation that no cast in either business function can raise on arbitrary staging text.
7. Newly gained donation validations that previously did not run.
8. What you did with `validate_staging_data_dynamic.sql`.
9. The equivalence comparison script, how to run it, and expected output — including the mixed common+business error row and the malformed-input row.
10. Seed scripts the user must run, by filename, and in what order.
11. Confirmation that no migration is required — or, if you believe one is, exactly why.
12. Anything you could not complete and why.
