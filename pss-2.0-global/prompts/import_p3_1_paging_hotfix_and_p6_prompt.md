# Import remediation — HOTFIX P3.1-A (silent row loss) then Phase P6 (data correctness)

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`
Plan of record: `prompts/import_gap_remediation_prompt.md` (P6 table at lines 276–296)

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add` and do NOT edit `ApplicationDbContextModelSnapshot.cs`. Make compiling entity + EF-configuration changes only and hand the migration off by name.
- `PSS_2.0_Backend` and `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- Enterprise-level app. No shortcuts. Backend/service-layer validation, not frontend-only.

---

## PART 1 — HOTFIX P3.1-A: the batch loop silently drops rows (do this first)

File: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/ContactImport-fn-execute.sql`

### The defect (confirmed, live in shipped code)

`STEP 4` selects the batch with a predicate that **shrinks** as rows are processed:

```sql
:371  v_row_filter := v_eligible_filter || ' AND "ExecutionStatus" = 0';
:374-381
      SELECT "Id","RowNumber" FROM import.%I
      WHERE %s ORDER BY "RowNumber"
      OFFSET p_offset LIMIT p_batch_size
```

but the caller advances the offset monotonically
(`ImportExecutionService.cs:260` → `offset += BatchSize`, `BatchSize = 500`),
and `has_more` is computed from a **fixed** total (`:462`, `:1273`):

```sql
v_has_more := (p_offset + p_batch_size < v_total_valid);
```

Every row a batch imports becomes `ExecutionStatus = 1` and leaves the result set, so
the next batch's `OFFSET` skips rows that were never processed.

Worked example, 1200 valid rows:

| batch | p_offset | pending rows | window taken | outcome |
|---|---|---|---|---|
| 1 | 0 | 1..1200 | 1..500 | imported |
| 2 | 500 | 501..1200 (700) | 1001..1200 | **rows 501..1000 skipped** |
| 3 | 1000 | 501..1000 (500) | none — OFFSET past end | early return at `:392`, `has_more := FALSE` |

Result: **700 of 1200 imported and the session is stamped `Completed` (Status 9)**.
No error, no failed-row count, `ImportedRows` is simply short. Files ≤ 500 rows are
one batch and are unaffected, which is why this has not been noticed.

The `ExecutionStatus = 0` filter arrived in `fdcb171f3` (inline edit / accept-omit);
the paging was never re-derived to match it. `prompts/import_gap_remediation_prompt.md`
P3.1 already warns about exactly this shape.

### The fix

Because the predicate self-excludes every processed row (`1` success, `2` failed,
`3` skipped), the batch selection must become a **head-of-queue take**, not an offset walk.

1. **STEP 4, batch branch (`:373-381`)** — drop `OFFSET %s`; keep `ORDER BY "RowNumber" LIMIT %s`.
   Leave the `ELSE` (full-mode) branch alone. `p_offset` still drives `v_is_batch` / `v_is_first`,
   so keep the parameter and both flags exactly as they are — do not change the signature.

2. **STEP 5g (`:750-759`)** — the skip-marking window `"RowNumber" > p_offset AND <= p_offset + p_batch_size`
   is offset-derived and now inconsistent with a head-take. Replace it with the actual
   `RowNumber` range of the batch that was just selected:
   ```sql
   AND "RowNumber" BETWEEN (SELECT MIN(row_number) FROM _import_batch_ids)
                       AND (SELECT MAX(row_number) FROM _import_batch_ids)
   ```
   Guard for the case where `_import_batch_ids` is empty (both early-return paths already
   `RETURN` before this point, but assert it rather than assume).

3. **`has_more`, both sites (`:462` and `:1272-1276`)** — stop deriving it from `p_offset`.
   Compute it from what is actually left:
   ```sql
   EXECUTE format('SELECT EXISTS (SELECT 1 FROM import.%I WHERE %s)', v_table_name, v_row_filter)
   INTO v_has_more;
   ```
   Run this **after** all of STEP 5/5g/6 have stamped their statuses, so pending-but-
   deliberately-left rows (warning rows with no decision — see the STEP 5g comment) do not
   spin the loop forever. If such rows can remain `ExecutionStatus = 0` after a full pass,
   exclude them from `v_row_filter`'s "is there more" form explicitly rather than letting
   the loop run until the caller's cancel check fires. **Verify this — a non-terminating
   loop would be a worse bug than the one being fixed.**

4. **Belt-and-braces in the caller** — `Base.Support/Import/Services/ImportExecutionService.cs`:
   the loop must not be able to run unbounded. Add a guard that breaks when a batch reports
   zero rows processed *and* `has_more` is true, logging it as an anomaly. Keep
   `offset += BatchSize` (it still feeds `LastProcessedOffset` for progress) but it no longer
   controls row selection.

5. **Apply the identical fix to the donation execute SP** if it shares this shape —
   check `sql-scripts-dyanmic/` for the BulkDonation execute function and diff the STEP 4 /
   STEP 5g / STEP 7 blocks against the contact one. Report which functions you changed.

6. **Re-run cost**: sessions already stamped `Completed` with missing rows cannot be
   auto-repaired by this change. Write a detection query into the script header comment:
   ```sql
   -- Sessions that finished short (candidates for re-import):
   SELECT "ImportSessionId", "CompanyId", "ValidRows", "ImportedRows"
   FROM import."ImportSessions"
   WHERE "Status" = 9 AND "ValidRows" > 500
     AND "ImportedRows" < "ValidRows";
   ```
   Do not attempt to fix data. Report the query to the user.

### Verification to state in your summary
Walk the 1200-row example through the patched SP line by line and show that batches
1/2/3 take rows 1–500, 501–1000, 1001–1200 and that `has_more` goes true, true, false.

---

## PART 2 — Phase P6: data correctness (after Part 1 is staged)

Full item table: `prompts/import_gap_remediation_prompt.md` lines 280–293.
Almost everything lives in `Base.Infrastructure/Services/Import/FileParserService.cs`,
which is currently **completely untouched** by the remediation.

Two decisions are already made — implement them, do not re-open them:

- **P6.1 (`.xls`)** — *support* it, do not drop it from the allowlist. Replace both
  `new XSSFWorkbook(fileStream)` sites (`:37`, `:226`) with NPOI's
  `WorkbookFactory.Create(fileStream)`, which dispatches on the magic bytes to HSSF or XSSF.
  Today the validator accepts the `D0 CF 11 E0` OLE2 signature and the parser is XSSF-only,
  so every `.xls` upload is a guaranteed 500.
- **P6.4 (date formats)** — needs a new **nullable `DateFormat` varchar** on
  `import."ImportGridFields"` (entity + EF configuration only). Migration name to hand off:
  `Add_ImportGridField_DateFormat`. Parse with `CultureInfo.InvariantCulture` and, when the
  field carries a format, `DateTime.TryParseExact`. **Delete both `catch { }` blocks
  (`:190`, `:212`)** — a swallowed parse failure is the P6.3 defect in another costume.

The rest, in order:

- **P6.2** — `result.Errors` from the parse is never inspected, so unknown/misspelled columns
  vanish silently. Surface them as session-level errors on the review screen.
- **P6.3** — `int.TryParse(...) ? v : null` and the decimal twin (`:156-157`) turn `"12,500"`
  into NULL. A coercion failure must become a row validation error, never a silent null.
- **P6.5** — `RowNumber` is a re-sequenced counter, so the error grid cites row numbers that
  do not exist in the user's spreadsheet. Carry the source sheet row index.
- **P6.6** — CSV formula injection: prefix-escape `=`, `+`, `-`, `@` on **both** the template
  download and the error export.
- **P6.7** — archive-bomb guard before the workbook is opened (entry count / uncompressed size
  ceiling), not after.
- **P6.8** — `UploadImportFile.cs` uploads the blob before the row-count validation runs,
  leaving orphan blobs. Validate first, then upload.
- **P6.9** — tenant-prefix the blob path: `imports/{companyId}/{yyyy}/{MM}/{dd}/{guid}{ext}`.
- **P6.10** — delete the dead duplicate `ParseAndStageAsync` (`:28`).
- **P6.11** — doc drift: `IMPORT_BLOB_STORAGE` vs `PSSBLOB`. Reconcile to whatever the code uses.
- **P6.12** — index the staging tables on `(ValidationStatus, RowDecision)`. This was gated on
  P0, and P0 is closed, so it is back in scope. Staging tables are created dynamically —
  add the index in the same DDL path that creates the table, not as a migration.

## Output
Stage everything (`git add` in each affected repo). Report:
1. which SQL functions you changed and the 1200-row walkthrough,
2. the migration you need the user to create (`Add_ImportGridField_DateFormat`),
3. any P6 item you could not complete and why,
4. the short-session detection query result the user should run.
