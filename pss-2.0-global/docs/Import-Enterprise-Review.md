# Generic Import — Enterprise Review

Scope: the config-driven Generic Import pipeline (upload → parse → stage → validate → execute), backend + frontend.
Out of scope by instruction: Custom Fields; email delivery of import outcomes.
Classification on every recommendation: **[MVP]** / **[PROD]** (production required) / **[FUTURE]**.

Review date: 2026-08-12. Reviewed against the brief in `prompts/import_recheck.txt`.

---

## 0. The flow as actually implemented

```
FE wizard (5 steps)  ──POST /api/import/upload (multipart)──▶ ImportController
                                                                │
                                        UploadImportFileCommand │  (synchronous, in-request)
                                                                ▼
              validator: extension + magic bytes + traversal + non-empty
                                                                ▼
              grid lookup (ImportGridDefinitions by GridCode) → MaxFileSizeBytes
                                                                ▼
              DynamicFieldGeneratorService → field list from ImportGridFields
                                                                ▼
              ImportFileStorageService.UploadAsync → Azure blob  ◀── happens BEFORE row validation
                                                                ▼
              FileParserService.ParseToJsonAsync (NPOI, whole workbook in memory)
                                                                ▼
              grid MaxRowCount check
                                                                ▼
              StagingTableService.ProcessImportUploadAsync
                  → import.create_staging_table(sessionId) → import."staging_{id}"
                  → binary COPY of all rows
                  → ImportSessions row, Status = Parsed
                                                                │
GQL startImportValidation ──▶ Hangfire job ──▶ import.validate_contact_data(session, offset, 1000) loop
                                                    │ RAISE NOTICE 'PROGRESS:{...}' → SignalR
                                                    ▼ Status = Validated, Valid/Invalid/Warning counts
FE review grid: inline edit invalid rows (updateImportStagingRow) / accept-omit (setImportStagingRowDecision)
                                                                │
GQL startImportExecution ──▶ Hangfire job ──▶ import.execute_contact_import(session, offset, 500) loop
                                                    │ each batch = its own transaction (committed)
                                                    ▼ Status = Completed, StagingRetainUntil = +30d
                                                      SignalR completion + summary
Nightly 2 AM: DropExpiredStagingTablesJob
Optional: ScheduleImport → midnight cron → ReValidating → ReValidated → execute
```

Terminal state has **no audit row, no notification, no intimation**. Confirmed by grep: `Intimation`, `NotificationDispatcher`, `AuditLog`, `IAudit` appear **zero times** anywhere under the import namespaces.

---

## A. What Is Already Good

These are genuinely well done and should not be touched.

| # | Item | Evidence |
|---|---|---|
| A1 | **File-type security is real, not cosmetic.** Extension allowlist *and* magic-byte sniffing (`50 4B 03 04` / `D0 CF 11 E0`), not extension alone. | `UploadImportFile.cs` validator |
| A2 | **Path-traversal guard on the filename** — rejects `..`, `/`, `\`, `\0`. | same validator |
| A3 | **Two-tier size limit**: hard 50 MB at the controller, per-grid `MaxFileSizeBytes` in config; plus per-grid `MaxRowCount`. Config-driven limits are the right call. | `ImportController.cs`, `UploadImportFile.cs` |
| A4 | **SP-name injection is closed.** `ImportStoredProcedureHelper` regex-validates `schema.function` before interpolation — the one place a config value reaches SQL text. | `ImportStoredProcedureHelper.cs:15-49` |
| A5 | **Staging writes are parameterised / binary COPY**, plus a `staging_` prefix assertion so the service cannot be pointed at a real table. | `StagingTableService.cs:97,154` |
| A6 | **Status is persisted *before* the Hangfire job is enqueued**, with an explicit comment about the worker winning the race. This is the correct ordering and most teams get it wrong. | `StartImport.cs` |
| A7 | **Cancel ordering is deliberate**: set `Cancelled` first, delete the job, and only drop staging when not mid-validate. Documented in code. | `CancelImport.cs` |
| A8 | **Batch-wise commit with resume support** — `LastProcessedOffset` persisted per batch; each batch is its own transaction, so a crash at row 40 000 does not lose the first 39 500. | `ImportExecutionService.cs:218` |
| A9 | **Cancellation is checked between batches**, and the lookup cache table is cleaned up on cancel. | `ImportExecutionService.cs:174-181` |
| A10 | **Progress telemetry through `RAISE NOTICE` → SignalR** is an elegant way to stream SP-internal progress without polling. | `ImportStoredProcedureHelper.CreateProgressNoticeHandler` |
| A11 | **REST exception mapping is thorough** — `NotFound`→404, `Forbidden`→403, `Validation`→400, `PostgresException` logged and genericised (does *not* leak SQL to the client), `OperationCanceled`→499. | `ImportController.cs` |
| A12 | **Execution failures are counted separately** (`ExecutionFailedRows`) from validation failures — the distinction most import systems collapse. | `ImportSession.cs:147` |
| A13 | **Staging retained 30 days after completion** so the result grid can be re-opened, with a nightly reaper rather than an immediate drop. Correct product decision. | `DropExpiredStagingTablesJob.cs` |
| A14 | **Review-before-commit with per-row inline edit + accept/omit** (`RowDecision` NULL/1/2). This is the right UX model and is better than most commercial importers. | `import-step-review-results.tsx` |
| A15 | **Scheduled import with mandatory re-validation** before execution (`ReValidating` → `ReValidated` / `ScheduleValidationFailed`) — data can drift between schedule and run, and the design knows it. | `ImportSessionStatus`, `ImportScheduledExecutionService` |

---

## B. Problems / Risks

### B-SEC — Security

| # | Finding | Severity |
|---|---|---|
| B1 | **No authorization anywhere on import.** `ImportController` carries no `[Authorize]`/`[CustomAuthorize]` on the class or any of its four actions. Import GraphQL mutations carry none either (only a commented-out `//[CustomAuthorize("MENU-READ")]` at `ImportSessionMutations.cs:17`). `MapControllers()`/`MapGraphQL()` have no `RequireAuthorization()` and there is no fallback authorization policy. | **Critical** |
| B2 | **Cross-tenant IDOR on every session-scoped operation.** `StartValidationHandler`, `StartImportHandler`, `CancelImportHandler`, the staging-row mutations and the session queries all resolve the session by `ImportSessionId` alone. There are **zero** EF global query filters in the codebase (`grep HasQueryFilter` → 0 hits), so nothing compensates. `CompanyId` is captured at upload and never re-checked. Tenant A can validate, execute, edit rows in, or cancel tenant B's import by guessing an integer. | **Critical** |
| B3 | **SignalR hub is unauthenticated and unscoped.** `ImportProgressHub` has no `[Authorize]`; `JoinSession(string sessionId)` adds the caller to group `import-{sessionId}` with no ownership check. Row counts, error text and `ImportRecordsSummaryDto` leak to anyone who guesses an id. | **Critical** |
| B4 | **Blob path has no tenant segment**: `imports/{yyyy/MM/dd}/{guid}_{fileName}`. Storage-level isolation is impossible; a future SAS or container-level policy cannot be scoped per tenant without a migration of existing paths. | **High** |
| B5 | **Raw exception messages returned to the client** from every import GraphQL mutation (`catch (Exception ex) → Error(ex.Message)`). The REST controller genericises Postgres errors; GraphQL does not. Same for `SetSessionFailedAsync($"Import error: {pgEx.MessageText} — {pgEx.Detail}")`, which lands in `ErrorMessage` and is rendered in the UI — `Detail` on a unique-violation contains **another row's column values**. | **High** |
| B6 | **No rate limiting on import upload.** Named limiter policies exist for `eventreg-submit` and `ReceiptDownload`; import — the most expensive endpoint in the product — has none. A loop of 50 MB uploads is an easy DoS on both the API and blob spend. | **High** |
| B7 | **No malware scanning** of the uploaded file, and no quarantine step. The file is stored and retained indefinitely. | Medium |
| B8 | **Zip-bomb / XXE exposure.** `new XSSFWorkbook(stream)` on attacker-supplied input with no entry-count or expansion-ratio limit. A 2 MB xlsx can expand to gigabytes. | Medium |
| B9 | **No CSV/formula-injection handling** on the generated template or on any future export of error rows. A cell beginning `=`, `+`, `-`, `@` re-opened in Excel executes. | Medium |
| B10 | Blob container is created at runtime by the app (`CreateIfNotExistsAsync`) — requires container-create rights on the connection string rather than a least-privilege, pre-provisioned container. | Low |
| B11 | Doc drift: `IImportFileStorageService` documents storage code `IMPORT_BLOB_STORAGE`; the implementation queries `PSSBLOB`. | Low |

### B-DATA — Data processing

| # | Finding | Severity |
|---|---|---|
| B12 | **`.xls` is accepted but cannot be parsed.** The validator allows `.xls` and its OLE2 magic bytes; `FileParserService` uses `new XSSFWorkbook(...)` (XLSX/OOXML only). An `.xls` upload throws deep in NPOI and surfaces as a generic 500. Either add `HSSFWorkbook` dispatch or remove `.xls` from the allowlist. | **High** |
| B13 | **Whole file parsed into memory, inside the HTTP request.** The file is buffered into a `MemoryStream`, then `XSSFWorkbook` builds the full DOM, then every row becomes a `Dictionary<string,object?>` in a `List`. Three full copies. At 100 K rows this is GB-scale and the request will time out before it finishes; at 1 M rows it is an OOM. | **Critical for scale** |
| B14 | **Blob is uploaded before row-count validation**, so every file rejected for `MaxRowCount` still leaves a permanent orphan blob. | Medium |
| B15 | **Unknown columns are recorded as errors but do not block.** `result.Errors.Add($"Unknown column: {headerText}")` — the caller never inspects `Errors`; parsing proceeds and the column is silently dropped. A user who mistypes a header gets a "successful" import with a missing field. | **High** |
| B16 | **Type coercion failures are silently nulled.** `int.TryParse(...) ? intVal : null` — `"12,500"` in an INTEGER column becomes NULL, not an error. Same for DECIMAL, BOOLEAN, DATE. Bad data becomes missing data with no trace. | **High** |
| B17 | **Ambiguous date parsing.** `DateTime.TryParse(stringValue)` uses ambient culture: `03/04/2026` is March 4 on a US host, April 3 on a UK host. Non-deterministic across environments. | **High** |
| B18 | **Duplicate parser implementations.** `ParseAndStageAsync` and `ParseToJsonAsync` are the same 80 lines twice, with `ParseAndStageAsync` apparently dead. They will drift. | Medium |
| B19 | **No plan/quota check (§7A).** The infrastructure already exists and is unused: `MeteredResourceAttribute`, `QuotaBehavior`, and `IBulkMeteredRequest.UnitCount` — which was written specifically so "a 500-row import cannot walk past a 10-slot remainder" — plus `IUsageMeterService.EnsureStockCapacityAsync(unitCount)`. `grep IBulkMeteredRequest` finds **no implementers**. A tenant on a 10 000-contact plan can import 500 000 contacts. | **Critical (business)** |
| B20 | **Empty-row detection is per-row `LastCellNum` scan** but `RowNumber` is a re-sequenced counter, not the Excel row index. Error messages therefore cite a row number the user cannot find in their spreadsheet when blank rows exist. | Medium |
| B21 | Execution `CommandTimeout = 0` (unbounded) per batch. A pathological batch hangs a Hangfire worker forever with no upper bound. | Medium |
| B22 | Validation counts on the final batch use `lastResult` (final aggregate) but intermediate accumulation into `cumulativeValid` is then discarded — two different accounting models in one method. Correct today only because the SP returns whole-table aggregates on the last call; brittle. | Medium |

### B-OPS — Lifecycle, jobs, cleanup

| # | Finding | Severity |
|---|---|---|
| B23 | **Hangfire jobs carry no tenant context.** `ExecuteImportAsync(sessionId)` re-resolves everything from the session row with a scoped `IApplicationDbContext` and no `ITenantContext`. This is why quota/entitlement gates cannot fire in the job, and why any future global query filter would break the job. | **High** |
| B24 | **Staging tables leak for every non-completed session.** `DropExpiredStagingTablesJob` filters `Status == Completed`. `Failed`, `Cancelled`, `ScheduleFailed`, and abandoned `Parsed`/`Validated` sessions keep their `import.staging_*` table **forever**. On a busy tenant this is unbounded schema growth — the `import` schema will accumulate thousands of tables. | **Critical (ops)** |
| B25 | **Blobs are never deleted.** No retention, no lifecycle rule, no delete on session failure or cleanup. Every uploaded file — containing PII — is kept indefinitely. Directly at odds with any data-retention commitment. | **High** |
| B26 | **`_lookup_cache_{sessionId}` is dropped only on user cancel** — not on failure, not on completion. Another unbounded table leak. | Medium |
| B27 | **No idempotency on re-execution.** `StartImport` requires `Validated`, but a session that failed mid-execution goes to `Failed`; nothing prevents re-validating it back to `Validated` and re-running from offset 0, double-inserting the rows the first run committed. `LastProcessedOffset` is stored but the execute path always starts at `offset = 0`. Resume is half-built. | **Critical** |
| B28 | `AutomaticRetry(Attempts = 0)` on execution is defensible (no idempotency), but combined with B27 there is no recovery path at all except manual. | Medium |
| B29 | Fire-and-forget `_ = Task.Run(...)` inside the Npgsql notice handler — unobserved, unordered, and can outlive the connection. Progress messages can arrive out of order. | Low |
| B30 | `session.Status = Completed` is set by both the SP (last batch) *and* by EF afterwards, with a `ReloadAsync` in between. Two writers for one field. | Low |

### B-AUD — Audit

| # | Finding | Severity |
|---|---|---|
| B31 | **No audit trail at all for import.** The product has a full audit stack (`IAuditLogWriter`, `AuditEventPipelineBehavior`, `ISelfAuditedRequest`, tenant + platform audit reports). Import participates in none of it. The behavior only recognises `Export*`/`Approve*`/`Reject*`/`Submit*` request names, and the execution runs in Hangfire where there is no `HttpContext` for the behavior anyway. | **Critical (compliance)** |
| B32 | The `ImportSessions` row is the *only* record of who did what — and it has no `ModifiedBy`, no record of who edited which staging cell, and no record of who omitted which rows. Inline edit and accept/omit are unlogged mutations of data about to enter the system of record. | **High** |
| B33 | No linkage from an imported entity back to its import session — after the staging table is dropped at day 30, "where did this contact come from?" is unanswerable. | **High** |

### B-UX

| # | Finding | Severity |
|---|---|---|
| B34 | Progress depends entirely on the SignalR connection. On disconnect, tab close, or refresh, the wizard has no polling fallback; the job keeps running invisibly. | **High** |
| B35 | **No downloadable error file.** Invalid rows are visible only in the on-screen grid. A user with 3 000 invalid rows out of 10 000 cannot take the errors back to their source system. | **High** |
| B36 | No pre-flight preview of the first N parsed rows before committing to validation — the user only learns their column mapping was wrong after a full validation pass. | Medium |
| B37 | No estimated time / throughput indication for long imports; percentage only. | Low |
| B38 | Import history exists (`import-sessions-log.tsx`) but there is no re-download of the original file and no re-run from a previous session. | Medium |

---

## C. Production Blockers

Ship-stoppers. In priority order.

| # | Blocker | Fix |
|---|---|---|
| **C1** | No authorization on any import endpoint (B1) | Add `[CustomAuthorize("<MENU>-IMPORT")]` to the controller actions and every import mutation/query; add a per-grid capability code on `ImportGridDefinitions` so contact-import and donation-import are separately grantable. |
| **C2** | Cross-tenant IDOR (B2) | Add `&& s.CompanyId == currentCompanyId` to **every** session lookup — the three commands, the staging-row mutations, and every query. Add an EF global query filter on `ImportSession` as defence in depth. Add an ownership check inside the Hangfire job too (job args are not trustworthy input). |
| **C3** | Unauthenticated SignalR hub (B3) | `[Authorize]` on the hub; in `JoinSession`, load the session and verify `CompanyId` matches the caller's before `AddToGroupAsync`. |
| **C4** | Plan quota not enforced (B19, §7A) | Implement `IBulkMeteredRequest` on the import execution command with `UnitCount = ValidRows`; call `EnsureStockCapacityAsync(companyId, meterCode, validRows)` inside the execution transaction. Also surface the check **at validation time** so the user is told "this file has 12 000 rows; your plan allows 10 000, 8 430 used → 1 570 remaining" *before* they commit. |
| **C5** | Staging tables and blobs leak forever (B24, B25, B26) | Extend the reaper to all terminal statuses and to abandoned sessions (`Parsed`/`Validated` older than N days); drop the lookup cache in a `finally`; delete the blob when the session is reaped. |
| **C6** | No idempotency / double-insert on re-run (B27) | Either make execution resume from `LastProcessedOffset`, or stamp each staging row's `ExecutionStatus` and have the SP skip rows already `Success` (the column exists — use it as the idempotency key). Block re-validation of a session that has ever entered `Importing`. |
| **C7** | Memory blowup at scale (B13) | Move parsing out of the request: upload → blob → return session id immediately; a Hangfire parse job streams from blob. Use NPOI's event/SAX reader or `ExcelDataReader` instead of `XSSFWorkbook`, and stream straight into the binary `COPY` writer without the intermediate `List<Dictionary>`. |
| **C8** | No audit trail (B31–B33) | See section H. |
| **C9** | `.xls` accepted but unparseable (B12) | Dispatch on magic bytes to `HSSFWorkbook`, or drop `.xls` from the allowlist and say so in the UI. Do not leave it half-supported. |
| **C10** | Silent data corruption: unknown columns dropped, coercion failures nulled, culture-dependent dates (B15, B16, B17) | Fail the upload when `Errors` is non-empty; record coercion failures as row-level validation errors rather than NULLs; parse dates with `CultureInfo.InvariantCulture` + an explicit per-grid date-format config. |
| **C11** | Exception text leaked to the client (B5) | Return a correlation id + a safe message; log the detail. Never surface `PostgresException.Detail`. |
| **C12** | No rate limiting (B6) | Add a named limiter policy on the upload endpoint (e.g. 5/hour/tenant) and a concurrency cap of 1 active import per grid per tenant. |

---

## D. MVP Improvements

Small, high-value, do them now.

1. **[MVP]** Per-tenant blob prefix: `imports/{companyId}/{yyyy/MM/dd}/{guid}{ext}` — and stop embedding the raw user filename in the path (keep it in `OriginalFileName`). Cheap now, migration later.
2. **[MVP]** Upload the blob **after** parse + row-count validation, not before.
3. **[MVP]** One active import per (tenant, grid) — reject a second upload while one is `Validating`/`Importing`. Prevents the most common self-inflicted duplicate-data incident.
4. **[MVP]** Downloadable error report: an xlsx of the invalid rows with an appended `Error` column, generated from staging. This is the single most-requested import feature and the data is already there.
5. **[MVP]** Preview the first 10 parsed rows plus the resolved column mapping before validation starts.
6. **[MVP]** Polling fallback for progress when the SignalR connection drops — the session row already carries everything needed.
7. **[MVP]** Fail fast on unknown columns and show which header was not recognised, with the nearest expected header.
8. **[MVP]** Show plan-quota remaining on the review step (C4).
9. **[MVP]** Delete the dead `ParseAndStageAsync` duplicate.
10. **[MVP]** Bound `CommandTimeout` on execution batches (e.g. 10 min) instead of `0`.

---

## E. Enterprise Enhancements

1. **[PROD]** Column-mapping UI — let the user map their headers to fields instead of requiring the exact template. This is what makes an importer usable outside a demo.
2. **[PROD]** Dry-run mode: full validation + a "what would happen" summary (X created, Y updated, Z skipped) with no writes.
3. **[PROD]** Update/upsert semantics with a configurable match key, not insert-only.
4. **[PROD]** Rollback of a completed import — the batch-commit model makes true rollback impossible today, so provide a compensating "undo import" that soft-deletes everything stamped with that `ImportSessionId`. This requires B33's linkage column.
5. **[PROD]** Per-tenant import concurrency and throughput controls (dedicated Hangfire queue, worker cap) so one tenant's 500 K-row import cannot starve everyone else's.
6. **[FUTURE]** Import profiles: save a mapping + options set and reuse it for recurring feeds.
7. **[FUTURE]** CSV support (streaming, far cheaper than xlsx at scale) and 1 M-row-class handling via server-side chunked upload.
8. **[FUTURE]** API-driven import for system-to-system feeds, reusing the same staging + validate + execute pipeline.
9. **[FUTURE]** Custom fields (explicitly deferred — the field-generation layer is already config-driven, so this is additive).

---

## F. Security Review

| Area | Verdict |
|---|---|
| Authentication | **Fail** — nothing enforced (B1). |
| Authorization / capability | **Fail** — no capability code exists for import at all. |
| Multi-tenant isolation | **Fail** — B2, B3, B4. Tenant binding exists only at upload. |
| File-type validation | **Pass** — extension + magic bytes + traversal guard (A1, A2). Best-in-class for this codebase. |
| File-size limits | **Pass** — two-tier (A3). |
| Malware scanning | **Missing** (B7). **[PROD]** — scan on upload, quarantine until clean; the blob-storage work is the natural moment to add it. |
| Archive-bomb / XXE | **Missing** (B8). **[PROD]** — cap decompressed size and entry count before opening the workbook. |
| SQL injection | **Pass** — the two risky surfaces (SP name, staging table name) are both explicitly guarded (A4, A5). |
| Formula injection | **Missing** (B9). **[PROD]** — prefix `'` on any exported cell starting `= + - @`. Applies to the error-report file in D4. |
| Error/information disclosure | **Fail** — B5. |
| Rate limiting / DoS | **Fail** — B6, plus the memory profile in B13 makes a single upload a viable DoS. |
| Data at rest | Container is private (good). No encryption-at-rest statement, no retention policy, no deletion (B25). |
| Download of the original file | Not implemented. When added, it **must** be a short-lived SAS scoped to the tenant's prefix, never a public URL. **[PROD]** |

**Blob-storage integration (pending with the tech team) — requirements to hand them:**
- Private container, no public access. ✔ already.
- Path `imports/{companyId}/{yyyy}/{MM}/{dd}/{guid}{ext}`, no user-controlled segment.
- Lifecycle rule: delete after N days (align with the 30-day staging retention).
- Downloads via short-lived (≤15 min) user-delegation SAS, generated only after a tenant-ownership check.
- Separate container (or at least separate prefix + policy) for quarantined/unscanned uploads.
- Managed identity rather than a connection string in `StorageAccounts` where the hosting allows it.

---

## G. Data Processing Review

**Validate-before-commit vs stream-import — verdict: the current design (stage → validate → review → commit) is correct.** Do not change it. For a tenant-facing importer where the user must be able to fix bad rows, staging is the right architecture; streaming-import belongs only to trusted system-to-system feeds (E8).

**Partial-failure handling — verdict: currently ambiguous, and this is a real problem.** Each batch commits independently (A8), so a failure at batch 40 leaves 20 000 rows committed and the session `Failed`. That is a defensible model, but:
- The user is told "Import failed" with no indication that 20 000 records were in fact created.
- There is no resume, so the natural user action (re-run) double-inserts (B27).

**[PROD]** Make the policy explicit and visible: *all-or-nothing* per file is not achievable with the batch model, so commit to **"partial commit, resumable, never duplicated"** and implement it — per-row `ExecutionStatus` as the idempotency key, resume from `LastProcessedOffset`, and a completion summary that always states created / failed / skipped even on the failure path.

**Sync vs async — verdict: async (Hangfire) for validate and execute is correct.** But upload/parse is still synchronous and must move to async too (C7). Recommended split:
- Request: accept file → magic-byte + size checks → blob → create session (`Uploading`) → return session id. Target < 2 s.
- Job 1: parse + stage → `Parsed`.
- Job 2: validate → `Validated`.
- Job 3: execute → `Completed`.

**Performance expectations after C7 (indicative, single worker):**

| Rows | Today | After streaming parse + async upload |
|---|---|---|
| 1 K | works, ~seconds | works |
| 10 K | works, slow upload request | works |
| 100 K | request timeout / very high memory | works, minutes |
| 1 M | OOM | works with chunked upload + CSV; xlsx at 1 M is not a realistic target — **[FUTURE]**, and state the supported ceiling in the UI |

Also: **[PROD]** index the staging tables on `(ValidationStatus, RowDecision)` — the review grid, the counts, and the execute predicate all filter on them; the batch loop's `OFFSET` over a shrinking predicate is a correctness hazard as well as an O(n²) scan.

---

## H. Audit Review

Today: **nothing**. This is the largest compliance gap in the feature — a bulk data-entry channel with no record of who introduced what.

**[PROD] Minimum audit set** (write through the existing `IAuditLogWriter`, adding an `IMPORT` action type):

| Event | Recorded |
|---|---|
| `IMPORT_UPLOADED` | user, company, grid, filename, size, row count, blob path, session id |
| `IMPORT_VALIDATED` | session, valid/invalid/warning counts |
| `IMPORT_ROW_EDITED` | session, row number, field, old → new value, user |
| `IMPORT_ROW_OMITTED` | session, row number, user |
| `IMPORT_STARTED` | session, user, row count committed to |
| `IMPORT_COMPLETED` | session, created/failed counts, duration |
| `IMPORT_FAILED` / `IMPORT_CANCELLED` | session, reason, user (or system) |

Because execution runs in Hangfire with no `HttpContext`, the audit writer must be callable with an explicit `userId` taken from `ImportSession.UserId` rather than from the ambient accessor — the same pattern already used elsewhere for synthetic job principals.

**[PROD] Provenance**: stamp `ImportSessionId` (and ideally `ImportedAt`) on every entity row the import creates. Without it, audit rows exist but cannot be joined to the data, and E4 (undo) is impossible.

**[MVP]** Also stamp who last edited a staging cell (`ModifiedBy`, `ModifiedAt` on the staging table) — cheap, and it is the step where a human silently changes data.

---

## I. Intimation Integration

The existing generic system is a good fit and needs **no new import-specific notification machinery** — exactly as the brief requires. Two seams already exist:

- `INotificationDispatcher.DispatchAsync(triggerCode, companyId, ctx, ct)` — template-driven in-app notification, resolves recipients, renders `{{tokens}}`, writes `notify.Notifications`.
- `IIntimationService.RaiseAsync(IntimationRequest)` / `ResolveAsync(...)` — tenant-addressed condition banner, deduped on `(CompanyId, IntimationTypeCode, SourceKey)`, never throws into the caller.

**Which seam for which event — this distinction matters and the two are not interchangeable:**

| Event | Seam | Why |
|---|---|---|
| Import completed | **Notification** | A one-off fact addressed to a person. |
| Import completed with failed rows | **Notification** (warning) | Same, with counts. |
| Import failed | **Notification** + **Intimation** | The person needs telling; the tenant has an unresolved condition sitting in the system. |
| Validation found invalid rows and the session is waiting on a human | **Intimation** | A *standing condition* — it persists until acted on, which is precisely what an intimation is and a notification is not. |
| Scheduled import re-validation failed | **Notification** + **Intimation** | Nobody is watching at midnight. |
| Plan quota would be exceeded by this import | **Intimation** (severity `WARNING`, category `Subscription`, action → billing) | Standing condition, and it already has a natural home next to `SUBSCRIPTION_EXPIRING`. |

**Recipient rules — [MVP]:** notify `ImportSession.UserId` (the person who started it) and no one else. Intimations are tenant-addressed by design; set `RequiredMenuCode` + `RequiredCapability` to the import capability from C1 so the banner reaches only staff who can act on it — the mechanism is already built for exactly this.
**[FUTURE]:** optional cc to a configured import-admin role.

**Concrete work:**
1. **[MVP]** Add trigger codes (`IMPORT_COMPLETED`, `IMPORT_COMPLETED_WITH_ERRORS`, `IMPORT_FAILED`) + seed notification templates, following the existing template seed pattern.
2. **[MVP]** Add intimation type codes `IMPORT_FAILED`, `IMPORT_AWAITING_REVIEW`, `IMPORT_QUOTA_BLOCKED` to `IntimationTypeCodes` + `seed_intimation_masterdata.sql`, with `SourceKey = importSessionId` so two failed imports do not collide on the dedup index.
3. **[MVP]** Call both seams from the terminal paths in `ImportExecutionService` (completed / failed) and `ImportScheduledExecutionService`. Both contracts are explicitly "never throw into the caller", so no try/catch ceremony is needed.
4. **[MVP]** `ActionUrl` → the import session's result page, so the banner is one click from the error grid.
5. **[MVP]** `ResolveAsync` when the user opens/acts on the session, so the banner clears itself.
6. **[FUTURE]** Email — the architecture above is already email-ready: adding an email channel to the same trigger codes requires no import-side change. Do not build it now.

**Metadata to carry in `MetadataJson` / notification tokens:** session id, grid display name, file name, total / imported / failed counts, duration. Enough for the notification body to be useful without a round-trip.

---

## J. UI/UX Review

**Good:** the five-step wizard is the right shape; the review-and-fix grid with inline edit + accept/omit (A14) is genuinely strong; live progress; a sessions log; an active-import indicator.

**Gaps, tagged:**

| # | Issue | Tag |
|---|---|---|
| J1 | Progress dies with the SignalR connection; no polling fallback, no "you can close this page, we'll notify you" affordance. | **[PROD]** |
| J2 | No error-file download (D4). Blocks any real-world data cleanup loop. | **[MVP]** |
| J3 | No pre-validation preview of parsed rows + mapping. | **[MVP]** |
| J4 | Undecided rows (`RowDecision = NULL`) are silently excluded from the import. The user must be told explicitly — "12 rows have no decision and will not be imported" — with a bulk accept-all / omit-all. | **[MVP]** |
| J5 | The completion screen must always state created / failed / skipped, including on the failure path (see G). | **[MVP]** |
| J6 | No quota context before commit ("this will use 12 000 of your 1 570 remaining"). | **[MVP]** |
| J7 | Template download is available but there is no per-field help — required, format, allowed values — visible during review. | **[MVP]** |
| J8 | No confirmation dialog before the irreversible execute step. | **[MVP]** |
| J9 | No ETA/throughput on long imports. | **[PROD]** |
| J10 | Import history does not offer re-download of the source file or re-run. | **[PROD]** |
| J11 | Cancel during execution stops future batches but already-committed batches remain; the UI does not say so. | **[PROD]** |
| J12 | Error messages are raw SP text (B5) — must become field-level, human-readable messages anchored to a row/column the user can find in their file (blocked on B20's row-number issue). | **[PROD]** |
| J13 | Accessibility/keyboard handling of the review grid at 10 K rows — virtualisation and keyboard-only edit not verified. | **[FUTURE]** |

---

## K. Recommended End-to-End Architecture

The brief's flow is right in outline; three things change — upload becomes non-blocking, quota is gated before commit, and the terminal fan-out is explicit.

```
                     ┌──────────────── FE Import Wizard ────────────────┐
                     │ 1 Select grid → 2 Template → 3 Upload            │
                     │ 4 Review & fix → 5 Commit → 6 Result             │
                     └──────────────────────┬──────────────────────────┘
                                            │ multipart
                     ┌──────────────────────▼──────────────────────────┐
   AUTHZ GATE  ─────▶│ POST /api/import/upload   [CustomAuthorize]      │
   rate limit        │ + rate limiter + 1-active-import-per-grid guard  │
                     │ magic bytes · size · traversal · AV scan hook    │
                     └──────────────────────┬──────────────────────────┘
                                            │  ≤2s: session created (Uploading), id returned
                     ┌──────────────────────▼──────────────────────────┐
                     │ Blob: imports/{companyId}/{yyyy/MM/dd}/{guid}   │  private + lifecycle rule
                     └──────────────────────┬──────────────────────────┘
                                            ▼
       ┌──────────── Hangfire (tenant-scoped job context) ─────────────┐
       │ JOB 1 PARSE   stream blob → staging_{id}   → Parsed           │
       │ JOB 2 VALIDATE  SP batch loop              → Validated        │
       │        └─ includes PLAN QUOTA pre-check (validRows vs limit)  │
       │ JOB 3 EXECUTE   SP batch loop, resumable, per-row idempotent  │
       │        └─ EnsureStockCapacityAsync(validRows) in-transaction  │
       └──────────────────────┬────────────────────┬──────────────────┘
                              │                    │
                   SignalR (authorized,      ┌─────▼──────┐
                   tenant-scoped group)      │  Postgres  │  + ImportSessionId stamped on each row
                   + POLLING FALLBACK        └─────┬──────┘
                              │                    │
                     ┌────────▼────────────────────▼───────────────────┐
                     │ TERMINAL FAN-OUT (completed / failed / partial) │
                     ├─────────────────────────────────────────────────┤
                     │ • AuditLog        IMPORT_* rows (who/what/when) │
                     │ • Notification    INotificationDispatcher →     │
                     │                   ImportSession.UserId, in-app  │
                     │ • Intimation      IIntimationService.RaiseAsync │
                     │                   tenant banner, capability-    │
                     │                   scoped, ActionUrl → session   │
                     │                   ResolveAsync when acted on    │
                     │ • (FUTURE) email — same trigger codes, no       │
                     │                   import-side change needed     │
                     └─────────────────────────────────────────────────┘
                              │
                     ┌────────▼────────────────────────────────────────┐
                     │ CLEANUP (nightly)                               │
                     │ • staging drop for ALL terminal + abandoned     │
                     │ • lookup-cache drop in finally                  │
                     │ • blob delete on retention expiry               │
                     └─────────────────────────────────────────────────┘
```

**Improvements over the brief's diagram, and why:**
1. **Upload returns immediately; parsing is a job.** The brief has upload → blob → create job, but parsing today happens in the request. Moving it is what makes 100 K rows possible at all.
2. **Quota is checked twice** — advisory at validation (so the user is told before they commit) and authoritatively inside the execution transaction under the advisory lock (so concurrent imports cannot both take the last slots). Both mechanisms already exist unused.
3. **Audit, notification and intimation are one terminal fan-out**, not three call sites — a single `CompleteSessionAsync(status, summary)` that every path funnels through, so no future status can be added that forgets to notify.
4. **Cleanup is a first-class stage**, not an afterthought — it is currently the largest operational risk after security.

---

## Priority order

1. **C1–C3** — authorization + tenant isolation + hub. Nothing else matters until these are done; this is a data-breach-class gap, not a hardening nicety.
2. **C4** — plan quota (revenue leak, and the plumbing already exists).
3. **C5, C6** — leaks and double-insert.
4. **C8 + section I** — audit + intimation/notification fan-out.
5. **C7, C9–C12** — scale and data-correctness.
6. **D1–D10** — MVP polish.
7. **E / [FUTURE]** — after MVP.

**Overall verdict:** the *data pipeline* design is above average for this class of product — the config-driven grid model, staging-with-review, batch commit with progress streaming, and scheduled re-validation are all sound engineering, and several details (SP-name guarding, status-before-enqueue, cancel ordering) show real care. The failures are concentrated in the *cross-cutting* layers the feature was never wired into: authorization, tenant isolation, audit, notification, quota, and lifecycle cleanup. Every one of those has existing, working infrastructure in this codebase that import simply does not call. That is a good position to be in — the work is integration, not invention.
