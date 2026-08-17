# Import remediation — P7 (async parse for scale)

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`
Plan of record: `prompts/import_gap_remediation_prompt.md` § P7
Prior phases complete: P0, P1, P2, P3, P4, P5, P6, P8 (bulk), P9, P10.
**P7 is the last structural phase.**

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. Make compiling entity + EF-configuration changes only and hand the migration off by name.
- `PSS_2.0_Backend` and `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server. Seed SQL idempotent.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.
- Scheduled imports are staying. Do not refactor the schedule stack.

---

## The problem

`UploadImportFileHandler` does everything on the HTTP request thread: parse the whole workbook, upload to blob, insert every staging row, then verify status. `WorkbookFactory.Create(fileStream)` builds the full DOM, and every row then becomes a `Dictionary<string,object?>` in a `List` — **three full copies of the file in memory inside a GraphQL request**. `MaxRowCount` defaults to **50,000**. That request cannot finish inside any reasonable proxy timeout, and the caller sees a network error while the upload may or may not have landed.

## Target shape

| Stage | Work | Target |
|---|---|---|
| Request | magic bytes · size · traversal checks · **grid authorization** · store file · create session (`Uploading`) · return session id | **< 2s** |
| Job `PARSE` | stream file → `staging_{id}` via binary `COPY` → `Parsed` | — |
| Job `VALIDATE` | existing SP batch loop → `Validated` | — |
| Job `EXECUTE` | existing SP batch loop (already resumable + per-row idempotent from P3.1) | — |

`VALIDATE` and `EXECUTE` already run as jobs. **The new work is PARSE**, plus the request-side split.

---

## P7.1 — Do not regress P6.8 (read this before touching the ordering)

Today's order is deliberate: parse → check row count → check size → **then** upload. The comment at STEP 3 records why — the old order uploaded first and threw afterwards, so every rejected file left an orphan blob that nothing referenced and nothing deleted. *"A user retrying a bad file ten times paid for ten permanent blobs."*

Async parse **inverts this by necessity**: the background job cannot parse a file that was never stored. You are going to reintroduce the orphan class. That is acceptable only if you close it deliberately:

- Keep in the request everything that does not require parsing: magic bytes, extension, filename traversal, `MaxFileSizeBytes`, grid resolution and `ImportGridAuthorization.EnsureGridAccessAsync`. Reject before storing wherever you still can.
- `MaxRowCount` can no longer be checked in the request — it needs the parse. Enforce it **inside the PARSE job**, and fail the session with the same user-facing message.
- Every stored file must be owned by a session row from the moment it is stored, so an orphan is detectable. Create the session **before or in the same transaction as** the store, never after.
- Extend the P3.2 orphan sweep in `DropExpiredStagingTablesJob` to cover stored files with no live session. Follow the existing precedent: **the sweep logs, it does not delete.** Do not make this one delete.

State in your summary how a file stored for a session that then fails to parse gets cleaned up.

## P7.2 — Streaming parse

- Replace the full-DOM `WorkbookFactory.Create` read in `FileParserService` with a streaming reader (NPOI's event/SAX API or `ExcelDataReader`).
- Feed rows **straight into the existing binary `COPY` writer** — `StagingTableService` already uses `BeginBinaryImportAsync` with `FORMAT BINARY` (`:163-165`), so the destination is right; what has to go is the intermediate `List<Dictionary<string,object?>>`. Stream row-by-row, never materialize the file.
- **Fix the O(n²) walk at `StagingTableService.cs:110`**: `rows.Skip(batch).Take(batchSize)` over a `List` re-enumerates from the head every batch. With 50k rows and `batchSize = 100` that is ~12.5M wasted enumeration steps. Index directly or take a span; if the source becomes a stream this may dissolve on its own — say which.
- Preserve exactly: current type coercion, the parse-error collection (`parseResult.Errors`), and `parseWarnings` surfaced on the session. A faster parser that changes how a date or a blank cell is interpreted is a data-correctness regression, not an optimization. If any coercion behaviour must change, call it out explicitly rather than absorbing it.
- Keep `.xls` working. The comment at `FileParserService.cs:65-68` records that `XSSFWorkbook` alone threw on every `.xls` and `WorkbookFactory` was the fix. If your streaming reader is xlsx-only, **keep a fallback path for `.xls`** — do not silently drop a format the validator still accepts.

## P7.3 — Request-side split and job registration

- The request returns a session id with status `Uploading`. It must not wait on parse.
- The PARSE job must resolve tenant and actor from the `ImportSession` row, not from `HttpContext` — same reasoning P4 applied for the Hangfire paths.
- Reuse the existing queue infrastructure. Read how `ImportQueueDispatcher` and `ImportScheduledExecutionService` enqueue and how the dedicated Hangfire queue from P9.4 is configured, and follow it. **Do not add a second dispatch mechanism.**
- **P9 interaction — check this explicitly.** The partial unique index `UX_ImportSessions_CompanyId_Running` serializes on `"Status" = 8` (`Importing`). Parsing is not importing. Decide and justify whether PARSE should also be serialized per tenant, or whether concurrent parses are safe (they write to separate `staging_{id}` tables, so they may well be). If you conclude parse must serialize, say what index change that implies — **do not change the index silently**, it is what makes the whole queue work.
- Failure inside PARSE must land on `Failed` (10) via `ImportSessionHelper.SetSessionFailedAsync`, which vacates the slot, stamps `StagingRetainUntil`, and fires the P5 terminal notification. Do not write a second failure path.
- Bound the parse job's DB work with a timeout the way P3.3 did for execute (`Import:Queue:BatchCommandTimeoutMinutes` is the precedent — a parse-side key alongside it, not a reuse of that one).

## P7.4 — Frontend

- Handle the new `Uploading → Parsing → Parsed` transition. Today the wizard treats upload as synchronous and moves straight to review.
- Progress must cover parse, not just validate and execute. The polling fallback already exists in [import-wizard-container.tsx:182-210](PSS_2.0_Frontend/src/presentation/components/custom-components/import-wizard/import-wizard-container.tsx#L182-L210) — extend its active-status set rather than adding a second poller.
- A file that fails to parse must show the reason on the wizard, not a dead spinner.
- **State the supported ceiling in the UI** near the upload control (rows and MB, read from the grid definition, not hardcoded). xlsx at 1M rows is not a target; CSV streaming is out of scope.

## P7.5 — Storage dependency (verify first, report if blocked)

`ImportFileStorageService` is hard-bound to Azure `BlobServiceClient` reading the `PSSBLOB` row from `StorageAccounts`. Synchronous parse tolerates weak storage because the file is already in memory; **a background parser must re-read the file**, so P7 makes storage load-bearing in a way it is not today.

Before building: confirm `PSSBLOB` is live and readable in the target environment. If it is not, **stop and report** — do not invent a local-disk fallback, and do not build an S3 provider. The storage backend choice is pending the tech team and is explicitly out of scope for this session. Implement against `IImportFileStorageService` so the provider can be swapped without touching the parse pipeline.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. The new request/job boundary and what validation stayed in the request vs moved to PARSE.
2. How orphaned stored files are detected and cleaned, given P6.8's ordering is now inverted.
3. The streaming reader chosen, whether `.xls` still works, and any coercion behaviour that changed.
4. Your P9 serialization decision for PARSE, with reasoning.
5. Whether `PSSBLOB` verified as readable — and if not, that P7 is blocked on it.
6. Any migration the user needs to create, by name; any seed file to run.
7. Anything you could not complete and why.
