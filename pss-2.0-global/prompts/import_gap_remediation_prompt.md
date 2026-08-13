# Generic Import — Gap Remediation Development Prompt

**Execute this in a fresh session.** Source of findings: `docs/Import-Enterprise-Review.md` (sections A–K). Read that document first — it contains the evidence, file paths and line references behind every item below. This prompt is the build order.

---

## 0. Your role and standing rules

You are a Senior .NET / Next.js engineer working on an **enterprise multi-tenant SaaS product**. No shortcuts. Optimise for correctness, tenant isolation, auditability and maintainability — not for implementation simplicity.

**Hard constraints — violating any of these breaks the workflow:**

| Rule | Detail |
|---|---|
| **Never commit** | `git add` only, then report. The user commits. Never `push`, `amend`, `tag`. Never add a `Co-Authored-By: Claude` trailer or a "Generated with Claude Code" line anywhere. |
| **Never build the backend** | Do not run `dotnet build`. Make compiling changes and hand off. |
| **Never create migrations** | Do not run `add-migration` / `ef migrations add`. Do not edit `ModelSnapshot`. When a schema change is needed, write the entity + configuration changes and **list the migration for the user to create**, with the exact name to use. |
| **Nested git repos** | `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` each own a `.git/`. `cd` into each to stage. |
| **Worktree** | Work only in `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`. Verify with `git status` that you have not drifted into the sibling `pwds-soruban\` worktree. |
| **Never touch** | `src/application/configs/navigation-configs/BaseUrlConfig.ts` (user-managed). |
| **Never print secrets** | `appsettings.Development.json` is git-ignored and holds live keys. Key *names* only, never values. |
| **Database** | PostgreSQL, not SQL Server. Seed SQL: `now()`, double-quoted identifiers, `TRUE`/`FALSE`, `WHERE NOT EXISTS`, idempotent, re-runnable. |
| **No browser dialogs** | Never `window.alert/confirm/prompt`. Use a Dialog component or inline capture. |
| **Reuse, never fork** | Grids go through the existing `FlowDataTable`/`AdvancedDataTable`. Forms use the app-wide `FormInput`/`FormSelect`/`FormDatePicker`. GraphQL queries live in `gql-queries/**` — grep before writing a new one. |
| **Out of scope** | Custom Fields. Email delivery of import outcomes. Anything tagged `[FUTURE]` in the review. |

**Before changing any file, read its siblings.** Every pattern below already exists somewhere in this codebase — mirror the canonical implementation rather than inventing a variant.

---

## 1. Phases

Build in this order. Each phase is independently shippable. **Do not start a phase until the previous one compiles and is staged.**

| Phase | Theme | Why this order |
|---|---|---|
| **P0** | SQL reconciliation (repo ↔ DB) | The two PL/pgSQL functions are forked. P3.1 and P6.12 edit exactly those files. |
| **P1** | Authorization + tenant isolation | Data-breach-class. Nothing else matters first. |
| **P2** | Plan quota enforcement (§7A) | Revenue leak; the plumbing already exists unused. |
| **P3** | Lifecycle: idempotency, cleanup, leaks | Ops risk; silent duplicate data. |
| **P4** | Audit trail | Compliance. |
| **P5** | Intimation + notification fan-out | The user-visible outcome the brief asked for. |
| **P6** | Data-correctness fixes | Silent corruption. |
| **P7** | Scale: async parse | Unblocks 100K rows. |
| **P8** | UI/UX (MVP set) | Polish on top of a correct backend. |
| **P9** | On-demand import + execution queue | Same-tenant concurrency is unguarded today — duplicate-insert class. Owns the concurrency rule P1.6 used to carry. |
| **P10** | Hardcoded FK / lookup removal | Literal IDs and hardcoded lookup targets in the execute function. Contains a **cross-tenant FK bind** (P10.1) that is data-breach-class, so P10.1 ships with P1. |

**Dependency note.** P0 blocks only **P3.1** and **P6.12** — the two items that edit the PL/pgSQL functions. **P1, P2, P4, P5, P7 and P8 touch no SQL function file** and can run in parallel with, or ahead of, P0.

---

## P0 — SQL reconciliation (repo ↔ database) `[PROD]` — **prerequisite for P3.1 and P6.12**

### Why this phase exists

`import.contact_import_validate_batch` and `import.contact_import_execute_batch` are **two-way forked**. Someone applied fixes directly in the database and never back-ported them; separately, the repo grew a newer `RowDecision` (accept/omit warnings) feature branch cut from an older base. **Neither side is a superset of the other.** Deploying the repo file as-is silently drops production fixes; dumping the DB file into the repo silently drops the accept/omit feature.

The DB-side dumps are kept for reference as:
- `sql-scripts-dyanmic/ContactImport-fn-validate-current.sql`
- `sql-scripts-dyanmic/ContactImport-fn-execute-current.sql`

**Steps P0.1–P0.4 have already been applied to the repo files.** Verify them before building on top; do not redo them.

### P0.1 `ImportProgresses` → `ImportProgress` (blocking runtime bug) — *applied*

The physical table is **singular**. `ApplicationDbContextModelSnapshot.cs:17380` has an explicit `b.ToTable("ImportProgress", "import")`, which overrides the DbSet pluralization in `ImportDbContext.cs:12`. Both repo function files referenced `import."ImportProgresses"` at six sites and would have thrown `relation does not exist` on first call. Renamed. The `ON CONFLICT ("ImportSessionId","Operation")` remains valid — that unique index is declared in `ImportProgressConfiguration.cs:30-31`.

### P0.2 DB-only validate logic ported forward — *applied*

Ported into `ContactImport-fn-validate.sql`, **translated to the repo's warning semantics** (`"ValidationStatus" = CASE WHEN stg."ValidationStatus" = 2 THEN 2 ELSE 3 END` plus `'severity','warning'`) so each becomes an acceptable warning rather than a hard error:

- **STEP 13e — combination duplicate check**, scoped per contact. Signature = contact identity (FirstName+LastName+DOB) ‖ every `IsPrimaryChildField OR IsConditional` field at that slot. Replaces an earlier file-wide check that produced false positives whenever two different contacts shared a State or AddressType. **Do not re-widen this scope.**
- **STEP 13d gating** on `ImportGridChildRelations.IsUniqueInFile = TRUE` and `ImportGridFields.IsConditional = FALSE`. Address rows carry `IsUniqueInFile = FALSE` because a family legitimately shares a home; dropping the filter re-introduces the false positives.
- **`ChildDisplayName`-based messages** on `GROUP_PRIMARY_REQUIRED` and `CONDITIONAL_REQUIRED`, with the `field` anchor restored to the staging **column** (not the display label) so the preview grid highlights the exact cell.
- **`import.try_cast_date` for the STEP 13b DOB compare.** Deliberately *not* the DB's stricter regex-then-`::date` version: a hard cast on a well-shaped but invalid date such as `'2024-13-45'` **raises**, whereas `try_cast_date` returns NULL and widens the match to name-only.

Both `IsUniqueInFile` and `ChildDisplayName` are genuine EF-mapped columns present since the initial migration (`ImportGridChildRelation.cs:24,:67`) — the repo files were simply cut from a base predating their use.

### P0.3 Execute-side dedup restored, **RowDecision-aware** — *applied*

The repo had removed the DB's execute-time dedup entirely. Restoring it unguarded would silently re-skip rows a human explicitly accepted (`RowDecision = 1`), defeating the accept/omit feature. Restored under two distinct rules — **preserve this distinction**:

| Guard | Scope | RowDecision-gated? |
|---|---|---|
| STEP 4b parent contact re-check | company | **yes** |
| 6a Email (`Email` + CompanyId) | company | **yes** |
| 6b Phone (`FullPhoneNumber` + CompanyId) | company | **yes** |
| 6e UPI (`UPIIdentifier`, no CompanyId column) | global | **yes** |
| 6c Address (8-column identity) | `ContactId` | no — idempotency |
| 6d ContactTypeAssignment | `ContactId` | no — idempotency |
| 6f SocialLink (`Link`) | `ContactId` | no — idempotency |

**The rule:** a *value-uniqueness* skip means the value belongs to some other contact — exactly what validation surfaced as a warning, so an explicit accept must win. A *contact-scoped identity* skip means an exact duplicate on the same contact, which accepting a row never asks for; it also makes re-running a partially-failed batch safe.

STEP 4b's early return also fixes a bug in the DB version: when every row in a batch turns out to be a duplicate it must return the **real** `has_more`, not `FALSE`, or the import stops mid-file.

### P0.4 STEP 13 `DependsOnField` validation — *kept, untested*

This check exists only in the repo file and has never run against production data. Keep it, but exercise it in P0.6 before trusting it.

### P0.5 Apply in order

1. `Import-fn-staging-row-decisions.sql` (creates `import.ensure_row_decision_column`)
2. `ContactImport-fn-validate.sql`
3. `ContactImport-fn-execute.sql`

### P0.6 Close the fork loop

After deploying, **re-dump both functions from the database and diff them against the repo files.** The fork happened because the functions were edited directly in the DB; the diff must come back empty. Delete the `-current` dumps once it does.

### P0.7 Reconcile the duplicate definition sites

Three locations currently hold versions of import SQL. Record the authority explicitly:
- `sql-scripts-dyanmic/ContactImport-fn-*.sql` — **authoritative** for the two batch functions.
- `DatabaseScripts/Functions/import/*` — **authoritative** for the shared helpers (`try_cast_date`, `to_boolean`, `resolve_*`, `safe_read_staging_field`, `column_exists_in_staging`) and the only home of `create_staging_table`.
- The `-current` dumps — reference only, delete after P0.6.

---

## P1 — Authorization and tenant isolation `[PROD]`

### P1.1 Capability + menu seed
Import currently has **no capability code at all**. Create one per import grid so contact-import and donation-import are separately grantable.

- Add a nullable `RequiredCapabilityCode` column to `import."ImportGridDefinitions"` (entity + EF configuration only — **list the migration for the user**, suggested name `Add_ImportGrid_RequiredCapability`).
- Write `sql-scripts-dyanmic/seed_import_capabilities.sql`: idempotent inserts into `MenuCapabilities` + `RoleCapabilities` for `IMPORT` on the CONTACT and DONATION menus, granted to `BUSINESSADMIN`. Mirror the canonical seed pattern from an existing `seed_*_menu.sql`.
- Populate `RequiredCapabilityCode` on the existing grid definition rows in the same script.

### P1.2 Lock every entry point
- `Base.API/Controller/ImportController.cs` — add `[CustomAuthorize(...)]` to all four actions (`upload`, `validate/{id}`, `execute/{id}`, `cancel/{id}`). The upload action's capability is resolved from the grid's `RequiredCapabilityCode`; if that requires a two-stage check, do the coarse `[CustomAuthorize]` on the class and the per-grid capability check inside the handler.
- `Base.API/EndPoints/Import/Mutations/ImportMutations.cs` and `ImportSessionMutations.cs` — add `[CustomAuthorize(...)]` to **every** mutation. `ImportSessionMutations.cs:17` has the pattern commented out; uncomment and complete it.
- `ImportQueries.cs` / `ImportSessionQueries.cs` — same.

### P1.3 Close the cross-tenant IDOR
Every session lookup currently resolves by `ImportSessionId` alone and there are **zero** EF global query filters in the codebase.

Add `&& s.CompanyId == currentCompanyId` to the lookup in:
- `Base.Application/Business/ImportBusiness/Sessions/Commands/StartValidation.cs`
- `.../StartImport.cs`
- `.../CancelImport.cs`
- `.../UpdateStagingRow.cs`
- `.../SetStagingRowDecision.cs`
- every import query handler

Use `httpContextAccessor.GetCurrentUserStaffCompanyId()` — the same call `UploadImportFile.cs` already makes. When the session is not found for the caller's company, return **NotFound**, not Forbidden (do not confirm the id exists for another tenant).

**Defence in depth:** add an EF global query filter on `ImportSession` scoped to the tenant context. Note this is the **first** `HasQueryFilter` in the codebase — verify it does not break the Hangfire jobs, which run without a tenant context (P1.5 handles that).

### P1.4 Secure the SignalR hub
`Base.Application/Hubs/ImportProgressHub.cs` — `JoinSession(string sessionId)` currently joins `import-{sessionId}` for anyone.

- `[Authorize]` on the hub class.
- In `JoinSession`, load the session, verify `CompanyId` matches the caller's, and **only then** `AddToGroupAsync`. On mismatch, do not join and do not reveal why.

### P1.5 Tenant context inside Hangfire jobs
`ImportExecutionService` / `ImportValidationService` / `ImportScheduledExecutionService` re-resolve everything from the session row with no `ITenantContext`. Job arguments are not trustworthy input.

- Establish a synthetic principal / tenant scope from `ImportSession.CompanyId` + `UserId` at the top of each job. **Reuse the existing synthetic-principal pattern** used elsewhere for Hangfire jobs in this codebase — grep for it, do not invent a new one.
- This is a prerequisite for P2 (quota gate skips when `companyId is null or <= 0`) and P4 (audit writer needs a user id without `HttpContext`).

### P1.6 Rate limiting + concurrency
- Add a named rate-limiter policy for import upload in `DependencyInjection.cs` (mirror the existing `eventreg-submit` / `ReceiptDownload` policies). Suggest 5 uploads/hour/tenant.
- **Concurrency is now owned by P9, not this phase.** An earlier draft of P1.6 said *reject a new upload while the same (tenant, grid) has a session in `Validating` or `Importing`*. That rule is **superseded**: the decided behaviour is **queue and wait**, not reject. Do not implement a rejection here — see **P9**.
- What remains in P1.6 is the rate limiter only. Uploading and queueing are always allowed (subject to the limiter); serialization happens at execution time.

### P1.7 Stop leaking exception text
- Every import GraphQL mutation currently does `catch (Exception ex) → Error(ex.Message)`. Replace with a correlation id + a safe message; log the detail server-side.
- `ImportExecutionService` / `ImportValidationService` write `$"Import error: {pgEx.MessageText} — {pgEx.Detail}"` into `session.ErrorMessage` **and broadcast it over SignalR**. `Detail` on a unique-violation contains another row's column values. Store the safe message in `ErrorMessage`; log the full detail. The REST controller already does this correctly — mirror it.

---

## P2 — Plan quota enforcement (§7A) `[PROD]`

The infrastructure exists and has **zero implementers**: `IBulkMeteredRequest.UnitCount` was written with the comment *"a bulk create must be checked as a whole (used + N <= limit); a one-at-a-time check would let a 500-row import walk past a 10-slot remainder"*, and `IUsageMeterService.EnsureStockCapacityAsync(companyId, meterCode, unitCount, ct)` takes the count. Nothing calls them.

**Check the quota twice — both are required and they do different jobs:**

1. **Advisory, at validation completion** — so the user is told *before* they commit. Compute `ValidRows` vs `IEntitlementService.GetLimitAsync` minus current usage, and surface on the review screen:
   > This file has **12,000** rows. Your plan allows **10,000** contacts; **8,430** are in use. **1,570** remaining.

   Do not block here — the user may omit rows to fit.

2. **Authoritative, inside the execution transaction** — call `EnsureStockCapacityAsync(companyId, meterCode, acceptedRowCount)` under the existing `pg_advisory_xact_lock`, so two concurrent imports cannot both take the last slots. On `PlanQuotaExceededException`, fail the session cleanly with a quota-specific status/message — not a generic failure.

**Wire-up:**
- Implement `IBulkMeteredRequest` on the import execution command with `UnitCount = <accepted row count>`.
- Add `[MeteredResource(...)]` with the correct meter code per grid — CONTACTS for contact import, DONATIONS for donation import. Store the meter code on `ImportGridDefinitions` (same migration as P1.1) rather than hardcoding a switch.
- **Note the bypass:** `QuotaBehavior` returns early when `IsSuperAdmin()` or `companyId is null or <= 0`. Annotating the Hangfire job alone will silently do nothing — P1.5's tenant context is a hard prerequisite, and the in-transaction call in (2) is the real gate.

Raise the `IMPORT_QUOTA_BLOCKED` intimation from P5 when (2) trips.

---

## P3 — Lifecycle: idempotency and cleanup `[PROD]`

### P3.1 Idempotency / double-insert (the worst correctness bug)
Each batch commits independently, so a failure at batch 40 leaves earlier rows committed and the session `Failed`. Nothing prevents re-validating that session back to `Validated` and re-running from `offset = 0`, **double-inserting every row the first run committed**. `LastProcessedOffset` is persisted but the execute path always starts at zero — resume is half-built.

Commit to the policy **"partial commit, resumable, never duplicated"** and implement it:
- Use the existing per-row `ExecutionStatus` column as the idempotency key: `execute_contact_import` must skip rows already `Success` (1). This is an SP change in `sql-scripts-dyanmic/ContactImport-fn-execute.sql` (authoritative over `DatabaseScripts/Functions/import/`).
- Resume the batch loop from `session.LastProcessedOffset` rather than 0.
- Block re-validation of any session that has ever entered `Importing`; offer **Resume** instead of Re-run.
- The completion summary must state created / failed / skipped **on the failure path too** — today a partial failure reads as "Import failed" with no hint that 20,000 records were created.

Beware: the batch loop pages with `OFFSET` over a predicate that shrinks as rows are processed. Verify the paging is still correct once rows are being skipped — this is a pre-existing hazard flagged in the review and P3.1 makes it live.

### P3.2 Staging + blob + cache leaks
- `Base.Support/Import/Services/DropExpiredStagingTablesJob.cs` filters `Status == Completed`. Extend to **all terminal statuses** (`Failed`, `Cancelled`, `ScheduleFailed`, `ScheduleValidationFailed`) and to abandoned sessions (`Parsed` / `Validated` / `Initiated` older than N days, N configurable, default 7). Keep the existing per-session try/catch — it is correct.
- `import."_lookup_cache_{sessionId}"` is dropped only on user cancel. Drop it in a `finally` on every terminal path.
- **Blobs are never deleted.** Delete the blob when the session is reaped. Set `StagingRetainUntil`-equivalent retention on failed sessions too (today only `Completed` gets one).

### P3.3 Bounded timeouts
`ImportExecutionService` sets `cmd.CommandTimeout = 0` (unbounded). Bound it — 10 minutes per batch — so a pathological batch cannot hang a Hangfire worker forever.

---

## P4 — Audit trail `[PROD]`

Import participates in **none** of the existing audit stack. `AuditEventPipelineBehavior` only recognises `Export*`/`Approve*`/`Reject*`/`Submit*` request-name prefixes, and execution runs in Hangfire where there is no `HttpContext` anyway.

- Add an `IMPORT` action type to the audit action enum/master data.
- Write audit rows explicitly through `IAuditLogWriter` (not the pipeline behavior) using the `CompanyId`/`UserId` captured on `ImportSession`, so the Hangfire paths work. Events:

| Event | Payload |
|---|---|
| `IMPORT_UPLOADED` | user, company, grid, filename, size, row count, blob path, session id |
| `IMPORT_VALIDATED` | session, valid / invalid / warning counts |
| `IMPORT_ROW_EDITED` | session, row number, field, **old → new value**, user |
| `IMPORT_ROW_OMITTED` | session, row number, user |
| `IMPORT_STARTED` | session, user, row count committed to |
| `IMPORT_COMPLETED` | session, created / failed counts, duration |
| `IMPORT_FAILED` / `IMPORT_CANCELLED` | session, reason, user or system |

`IMPORT_ROW_EDITED` / `IMPORT_ROW_OMITTED` matter most: inline edit and accept/omit are unlogged human mutations of data about to enter the system of record.

- **Provenance `[PROD]`:** stamp `ImportSessionId` on every entity row the import creates (contact, donation, …). Without it, audit rows cannot be joined to data and "where did this record come from?" is unanswerable once staging is reaped. This is an entity + SP change — **list the migration for the user**, suggested name `Add_ImportSessionId_Provenance`.
- **`[MVP]`** Add `ModifiedBy` / `ModifiedAt` to the staging table for cell edits.

---

## P5 — Intimation + notification fan-out `[MVP]`

**Use the existing generic systems. Do not build an import-specific notification mechanism.** In-app only — **no email in this phase** (the trigger-code design below makes email purely additive later).

Two seams, and they are **not** interchangeable:

| Seam | Use for |
|---|---|
| `INotificationDispatcher.DispatchAsync(triggerCode, companyId, ctx, ct)` | A **one-off fact addressed to a person** — "your import finished". |
| `IIntimationService.RaiseAsync(IntimationRequest)` / `ResolveAsync(...)` | A **standing tenant condition** that persists until acted on. Tenant-addressed by design (INV-10 — an intimation names a tenant, never a user). |

**Event → seam mapping:**

| Event | Notification | Intimation |
|---|---|---|
| Import completed | ✔ | — |
| Completed with failed rows | ✔ (warning) | — |
| Import failed | ✔ | ✔ |
| Validation done, invalid rows awaiting a human | — | ✔ |
| Scheduled re-validation failed (midnight, nobody watching) | ✔ | ✔ |
| Plan quota would be exceeded (P2) | — | ✔ `WARNING`, category `Subscription` |

**Work items:**
1. Trigger codes `IMPORT_COMPLETED`, `IMPORT_COMPLETED_WITH_ERRORS`, `IMPORT_FAILED` + seeded `notify.NotificationTemplates` rows. Mirror the existing template seed pattern.
2. Intimation type codes `IMPORT_FAILED`, `IMPORT_AWAITING_REVIEW`, `IMPORT_QUOTA_BLOCKED` in `IntimationTypeCodes` + `seed_intimation_masterdata.sql`. **`SourceKey = importSessionId`** so two failed imports don't collide on the dedup index `(CompanyId, IntimationTypeCode, SourceKey)`.
3. **Recipients `[MVP]`:** notify `ImportSession.UserId` only. On the intimation, set `RequiredMenuCode` + `RequiredCapability` to P1.1's import capability so the banner reaches only staff who can act on it — that mechanism already exists.
4. `ActionUrl` → the import session result page, one click from the error grid.
5. `ResolveAsync` when the user opens or acts on the session, so the banner self-clears.
6. Tokens / `MetadataJson`: session id, grid display name, file name, total / imported / failed counts, duration.

**Architecture requirement:** funnel every terminal path through **one** `CompleteSessionAsync(status, summary)` that writes audit (P4) + dispatches notification + raises/resolves intimation. Three separate call sites will drift; a single funnel means no future status can be added that forgets to notify. Both service contracts are explicitly "never throw into the caller", so no defensive try/catch ceremony is needed.

---

## P6 — Data-correctness fixes `[PROD]`

All in `Base.Infrastructure/Services/Import/FileParserService.cs` unless noted.

| # | Fix |
|---|---|
| P6.1 | **`.xls` is accepted but unparseable.** The validator allows `.xls` + its `D0 CF 11 E0` magic bytes; the parser uses `XSSFWorkbook` (XLSX-only) → guaranteed 500. **Decide and commit:** dispatch on magic bytes to `HSSFWorkbook`, or remove `.xls` from the allowlist and say so in the UI. Do not leave it half-supported. |
| P6.2 | **Unknown columns silently dropped.** `result.Errors.Add($"Unknown column: {headerText}")` is never inspected by the caller. Fail the upload when `Errors` is non-empty, and name the unrecognised header plus the nearest expected one. |
| P6.3 | **Coercion failures silently nulled.** `int.TryParse(...) ? intVal : null` — `"12,500"` becomes NULL, not an error. Same for DECIMAL / BOOLEAN / DATE. Record a **row-level validation error** instead of a NULL. |
| P6.4 | **Culture-dependent dates.** `DateTime.TryParse(stringValue)` uses ambient culture — `03/04/2026` differs by host. Use `CultureInfo.InvariantCulture` plus an explicit per-grid date-format config on `ImportGridFields`. Remove the `catch { }` that swallows failures. |
| P6.5 | **Row numbers don't match the spreadsheet.** `RowNumber` is a re-sequenced counter, so with blank rows the error grid cites a row the user cannot find. Carry the true Excel row index alongside it and show that to the user. |
| P6.6 | **Formula injection.** Sanitize any cell beginning `=`, `+`, `-`, `@` with a leading `'` on the generated template **and** on the error-report export from P8.2. |
| P6.7 | **Archive-bomb guard.** Cap decompressed size and entry count before `new XSSFWorkbook(stream)`. |
| P6.8 | **Blob uploaded before row-count validation** (`UploadImportFile.cs`) — every file rejected for `MaxRowCount` leaves an orphan blob. Move the upload after parse + row-count checks. |
| P6.9 | **Tenant-prefixed blob path** — `imports/{companyId}/{yyyy}/{MM}/{dd}/{guid}{ext}`. Stop embedding the raw user filename in the path (keep it in `OriginalFileName`). Cheap now, a migration later. |
| P6.10 | Delete the dead duplicate `ParseAndStageAsync` — it is `ParseToJsonAsync` copied, and they will drift. |
| P6.11 | Doc drift: `IImportFileStorageService` documents storage code `IMPORT_BLOB_STORAGE`; the implementation queries `PSSBLOB`. Align them. |
| P6.12 | Index the staging tables on `(ValidationStatus, RowDecision)` — the review grid, the counts and the execute predicate all filter on them. |

---

## P7 — Async parse for scale `[PROD]`

Today the file is buffered into a `MemoryStream`, `XSSFWorkbook` builds the full DOM, then every row becomes a `Dictionary<string,object?>` in a `List` — three full copies, **inside the HTTP request**. 100K rows times out; 1M rows is an OOM.

Restructure to:

| Stage | Work | Target |
|---|---|---|
| Request | magic bytes · size · traversal · AV hook → blob → create session (`Uploading`) → return session id | **< 2s** |
| Job 1 `PARSE` | stream blob → `staging_{id}` → `Parsed` | — |
| Job 2 `VALIDATE` | existing SP batch loop → `Validated` (+ P2 advisory quota) | — |
| Job 3 `EXECUTE` | existing SP batch loop, resumable, per-row idempotent (P3.1) | — |

- Replace `XSSFWorkbook` with NPOI's event/SAX reader or `ExcelDataReader`, and stream **straight into the binary `COPY` writer** — no intermediate `List<Dictionary>`.
- `StagingTableService.InsertStagingDataAsync` uses `rows.Skip(batch).Take(batchSize)` — an O(n²) walk. Fix while you're there.
- FE must handle the new `Uploading` → `Parsed` transition (progress for parse, not just validate/execute).

**State the supported ceiling in the UI.** xlsx at 1M rows is not a realistic target; CSV streaming is `[FUTURE]`.

---

## P8 — UI/UX (MVP set) `[MVP]`

Frontend: `PSS_2.0_Frontend/src/presentation/components/custom-components/import-wizard/`.

| # | Item |
|---|---|
| P8.1 | **Polling fallback for progress.** Today progress dies with the SignalR connection — refresh or tab-close and the job runs invisibly. The session row already carries everything needed. Add "you can close this page, we'll notify you" (backed by P5). |
| P8.2 | **Downloadable error report** — an xlsx of the invalid rows with an appended `Error` column, generated from staging. Single most-requested import feature; the data is already there. Apply P6.6 sanitization. |
| P8.3 | **Pre-validation preview** — first 10 parsed rows + the resolved column mapping, before a full validation pass. |
| P8.4 | **Undecided rows are silently excluded.** `RowDecision = NULL` rows just don't import. Say so explicitly — "12 rows have no decision and will not be imported" — with bulk accept-all / omit-all. |
| P8.5 | **Completion screen always states created / failed / skipped**, including on the failure path. |
| P8.6 | **Quota context before commit** (P2 advisory number). |
| P8.7 | **Per-field help during review** — required, format, allowed values. |
| P8.8 | **Confirmation Dialog before execute** — it is irreversible. Dialog component, never `window.confirm`. |
| P8.9 | **Cancel-during-execution messaging** — already-committed batches remain; the UI must say so. |
| P8.10 | **Human-readable field-level errors** anchored to a row/column the user can find in their file (depends on P6.5). Raw SP text must never reach the screen (P1.7). |

---

## P9 — On-demand import + execution queue `[PROD]`

**Problem.** Two execution paths exist and neither has any concurrency control:

| Path | Command | Behaviour today |
|---|---|---|
| On the spot | `StartImportCommand` → `importService.StartImportJob(id)` | Hangfire fire-and-forget, runs immediately |
| Nightly | `ScheduleImportCommand` | Registers a **recurring** Hangfire job per **(grid, company)**, cron `0 0 * * *`; at midnight `ExecuteScheduledImportsAsync` sweeps **every** `Scheduled` session for that grid |

`Base.API/DependencyInjection.cs:143` runs **one** Hangfire server with `WorkerCount = 5` over queues `default`, `emails`, `payments`. Import jobs land on `default`. Consequences:

1. **Two sessions of the same tenant can execute concurrently.** The duplicate guards in `contact_import_execute_batch` are read-then-insert inside a batch transaction — they are only correct because batches run sequentially and each commits before the next reads. Two concurrent sessions in separate transactions cannot see each other's uncommitted rows, so both guards pass and both insert. **Every duplicate guard silently stops working.**
2. **Imports and business jobs starve each other** across a shared 5-slot pool.

### P9.1 Serialization scope — decided

**One running import per tenant. Many tenants in parallel. Sequential inside each import.**

- Not per-grid: Contact and Donation imports for one tenant have a real dependency (donations reference contacts still being created).
- Cross-tenant parallelism is preserved — tenants are independent, so throughput is unaffected.
- **Do not add parallelism inside a single import.** The batch loop stays sequential. The worker thread only calls the SP and waits; PostgreSQL already does set-based inserts per batch. Tune batch size and indexes instead. Intra-import parallelism would break the duplicate guards, `RAISE NOTICE 'PROGRESS:'` ordering, partial-failure resume, and row-order determinism. Its **prerequisite** would be replacing every read-then-insert guard with real unique constraints + `ON CONFLICT DO NOTHING` — out of scope, and unjustified at current scale.

### P9.2 Enforcement — database-level, not application-level

An application `if (anyRunning) …` is check-then-act and always races. Enforce in PostgreSQL:

```
UNIQUE INDEX ON import."ImportSessions" ("CompanyId") WHERE "Status" = <Importing>
```

Two concurrent runs for one tenant become impossible at the database. Handle the unique violation as "slot busy → stay queued", not as an error.

**Migration for the user to create — `Add_ImportSession_ExecutionQueue`:**

| Column on `ImportSession` | Type | Purpose |
|---|---|---|
| `QueuedAt` | `DateTime?` | FIFO tiebreak |
| `QueuePriority` | `int` (default 0) | On-demand `10`, scheduled `0` |
| `QueueSequence` | `int?` | Server-managed manual order within the tenant queue |
| `HeartbeatAt` | `DateTime?` | Lease liveness; enables crash recovery |

Plus the partial unique index above (expression/filtered index → `migrationBuilder.Sql()`), and a new `ImportSessionStatus.Queued` value. **Append the enum value — do not renumber existing members.**

### P9.3 Dispatcher — one execution path

- `StartImportCommand` sets `Queued` + `QueuedAt` + `QueuePriority = 10`, then wakes the dispatcher. It no longer enqueues execution directly.
- The dispatcher attempts to claim the tenant slot (set `Importing`, stamp `HeartbeatAt`). Success → enqueue the execution job. Unique-violation → leave it queued, no error.
- **Preserve the existing ordering guarantee**: the status must be persisted as `Importing` *before* the Hangfire job is enqueued (the worker checks `session.Status == Importing` on startup and skips otherwise).
- On run completion — success, failure **or** cancel — the completion funnel wakes the dispatcher for that tenant to pull the next queued session. Wire this into the single completion path, not into each call site.
- A **1-minute recurring safety-net job** catches missed wakeups and reclaims leases whose `HeartbeatAt` has expired (worker crash / Coolify redeploy). Without this a crashed run leaves the session `Importing` forever and blocks that tenant's queue permanently.
- **Change the midnight sweep to enqueue, not execute.** `ExecuteScheduledImportsAsync` marks its sessions `Queued` (priority `0`) and returns. Two independent execution paths always drift, and the second one is always the one that bypasses the concurrency rule.

### P9.4 Dedicated Hangfire queue

Add `"imports"` to `options.Queues` and route import execution jobs to it with its own worker allocation, so a long import can never consume the slots emails and payments need — and a burst of email jobs can never make a staff member's "Import Now" look broken.

### P9.5 Manual reordering — decided shape

Staff need an escape from "50-row urgent fix stuck behind a 200k-row load". Build it as **relative move actions, not an editable order-number column** — a client-supplied absolute number races, duplicates, needs gap/renumber logic forever, and fights `QueuePriority`.

| Aspect | Rule |
|---|---|
| Staff action | **Move up / Move down / Move to top** buttons — no typed value |
| Atomicity | Server recomputes the tenant's whole `QueueSequence` in one transaction |
| Eligibility | Only while status = `Queued`. The running row shows *"Running — cannot reorder"* |
| Visibility | Hide the controls when queue depth ≤ 1 (the common case) |
| Permission | Capability-gated — jumping ahead of a colleague is a shared-resource decision |
| Sort key | `QueuePriority` desc → `QueueSequence` asc → `QueuedAt` asc |

### P9.6 Scenario matrix — required behaviour

| Scenario | Required behaviour |
|---|---|
| Import Now, nothing running | Runs immediately |
| Import Now while same tenant is importing | Queued; staff sees position, what's ahead, estimated start |
| Import Now while the midnight sweep is running | Queued, but takes the next slot ahead of scheduled work (priority) |
| Two staff hit Import Now in the same second | Resolved by the partial unique index; loser stays queued, no error shown |
| Session scheduled for tonight, staff wants it now | "Run now" un-schedules and enqueues at priority `10` |
| Cancel a **queued** session | Instant and clean — nothing has been touched |
| Cancel a **running** session | Existing semantics: committed batches stay, remainder stops |
| Worker crash / redeploy mid-import | Lease expires → safety-net job reclaims → next session runs |
| Session queued for hours, validation stale | Re-validate before execute if queued longer than a configurable threshold (default 12h) |
| Small import behind a huge one | Honest ETA + "schedule for tonight instead" + reorder (P9.5). **No preemption** — a running batch loop must not be killed mid-flight |
| Two queued imports each fit quota, together they don't | Quota stays authoritative **in-transaction at execute time** (P2); UI warns at queue time |
| App restarts with items queued | Queue is DB state, not in-memory. Extend `ImportScheduleRecoveryExtension` to re-register the dispatcher safety-net job on startup |

### P9.7 Staff-facing UI

Queue panel on the import screen: status chip (`Queued` / `Running`), position, what's ahead, estimated start, live progress once running, cancel-while-queued, reorder actions per P9.5, and "you can close this page — we'll notify you" (pairs with P5).

---

## P10 — Hardcoded FK / lookup removal `[PROD]`

### Why this phase exists

`ContactImport-fn-validate.sql` resolves every lookup **from metadata**: it reads `LookupType` / `LookupSchema` / `LookupTable` / `LookupCategory` / `LookupDisplayColumn` / `LookupCodeColumn` / `LookupValueColumn` off `import."ImportGridFields"` and builds its FK and MasterData caches dynamically (validate lines 191–247 and 286–299).

`ContactImport-fn-execute.sql` does **not**. It re-states the same lookup targets as string literals at 15 call sites, and falls back to literal primary keys when a lookup misses. So the two halves of the same import can disagree: validate passes a row against the metadata-declared table, execute then binds it against a different hardcoded one — and nothing detects the divergence. `BulkDonationImport-fn-execute.sql` already does this correctly (resolve from `sett."MasterDatas"`, `RAISE EXCEPTION` when unseeded); Contact is the outlier.

### P10.1 Cross-tenant FK bind — **data-breach-class, ship with P1**

`import.resolve_foreign_key_id` (both overloads, `DatabaseScripts/Functions/import/resolve_foreign_key_id.sql` and `resolve_foreign_key_id2.sql`) filters on `IsActive` / `IsDeleted` only. It **never filters `CompanyId`**:

```sql
'SELECT %I FROM %I.%I WHERE LOWER(TRIM(%I::TEXT)) = $1
   AND "IsActive" = TRUE AND "IsDeleted" = FALSE LIMIT 1'
```

Several of the tables it is pointed at are tenant-scoped (`ContactSource.CompanyId`, `ContactType.CompanyId`, both `int?`). Tenant A importing a contact whose `ContactType` string happens to match tenant B's custom type binds `corg."Contacts"` to **tenant B's row**. Same defect in the MasterData path: `sett."MasterDatas"."CompanyId"` and `sett."MasterDataTypes"."CompanyId"` are both `int?`, and neither the validate cache (lines 191–206, 259–273) nor the execute cache filters on them.

**Fix.** Add a `p_company_id INT` parameter to `resolve_foreign_key_id` and apply `AND ("CompanyId" IS NULL OR "CompanyId" = $2)` when the target table has the column (probe `information_schema.columns` once and cache the answer per table — do not assume). Same predicate on both MasterData cache builds, keyed on the session's `CompanyId`. Global rows (`CompanyId IS NULL`) stay visible to everyone; tenant rows only to their owner. Ranking: prefer the tenant-specific row over the global one when both match.

### P10.2 Hardcoded fallback IDs — replace with a hard failure

Three literal primary keys in `ContactImport-fn-execute.sql`:

| Line | Literal | Column it lands in | Why it is wrong |
|---|---|---|---|
| 420–423 | `v_contact_status_id := 9` | `corg."Contacts"."ContactStatusId"` | Comment says it plainly: *"Safety fallback: hardcoded ID 9 if MasterData is not seeded for ContactStatus/Active"*. `MasterDataId` is a surrogate key — 9 means "Active" on the dev database and something arbitrary (or nothing) anywhere else. |
| 508–511 | `v_primary_country_id := 1` | `corg."Contacts"."PrimaryCountryId"` | `CountryId = 1` is whatever row seeded first. |
| 790, 917 | `v_phone_country_id := 1`, `v_addr_country_id := 1` | `ContactPhoneNumbers."CountryId"`, `ContactAddresses."CountryId"` | Same, after two legitimate resolution attempts. |

These are not safety nets — they are silent data corruption. A missing seed produces contacts pointing at an unrelated master row, and the import reports **success**.

**Fix — decided.** Delete all three fallbacks. Resolve the defaults once per call at the top of the function, from the database, and `RAISE EXCEPTION` when unresolvable — exactly the `BulkDonationImport-fn-execute.sql:132–166` pattern:

- **ContactStatus default** — `sett."MasterDatas"` JOIN `sett."MasterDataTypes"` on `TypeCode = 'ContactStatus'`, tenant-filtered per P10.1, matching `DataName`/`DataValue` = `'Active'`. If NULL → `RAISE EXCEPTION 'ContactStatus master data (Active) is not seeded for company %'`.
- **Default country** — must not be a literal. Read it from the tenant's `sett."OrganizationSettings"` (`ParamCode` for the org's country); fall back to `com."Countries"` where `IsDefault` if that column exists, otherwise raise. Do **not** invent a new column for this — check `OrganizationSettings` first and reuse.

Failing the import loudly at row 0 is correct. A wrong `ContactStatusId` on 50,000 contacts is not recoverable without a manual audit.

### P10.3 Hardcoded lookup targets — drive execute from `ImportGridFields`

15 call sites in `ContactImport-fn-execute.sql` hardcode the schema/table/column quad that the grid metadata already declares:

| Lines | Hardcoded target | Metadata that already declares it |
|---|---|---|
| 465, 787, 908, 914 | `('com','Countries','CountryName','CountryId',…,'CountryShortCode')` | seed lines 657, 1327, 1581 |
| 467 | `('com','Languages','LanguageName','LanguageId')` | seed 684 |
| 469 | `('com','Occupations','OccupationName','OccupationId')` | seed 711 |
| 471 | `('com','Genders','GenderName','GenderId')` | seed 628 |
| 475 | `('corg','ContactSources','ContactSourceName','ContactSourceId','ContactSourceCode')` | seed 793 |
| 921–929 | `States` / `Districts` / `Cities` / `Pincodes` / `Localities` | seed 1608–1717 |
| 1013 | `('corg','ContactTypes','ContactTypeName','ContactTypeId','ContactTypeCode')` | seed 1747 |

and 9 `resolve_master_cached('<Category>', …)` calls (440, 442, 445, 447, 455, 459, 461, 713, 776, 906, 1087, 1143) hardcode the category string that `ImportGridFields."LookupCategory"` already carries for that field.

**Fix — decided.** Build the same `field_name → (schema, table, display_col, code_col, value_col)` and `field_name → LookupCategory` maps that validate already builds, into a temp table at the top of execute, then resolve **by field name**:

```
v_gender_id := import.resolve_fk_by_field(v_field_map, 'Gender', <staging value>, v_company_id);
```

The call site then names only the field, and the target comes from metadata — the same source validate used. Note the child fields are sequenced (`AddressCountry1`, `AddressCountry2`, …) while the metadata row is per generated field; the map is keyed on the generated `FieldName`, so `'AddressCountry' || v_seq` is the correct key and needs no special casing.

**Acceptance:** after P10.3, adding a lookup field to a grid requires a seed row only — **no edit to the execute function**. That is the whole point of the metadata table.

### P10.4 Drop the shadowed 5-arg overload

`import.resolve_foreign_key_id(text,text,text,text,text)` (5-arg) and `(text,text,text,text,text,text DEFAULT NULL)` (6-arg) both exist. Every call site passes 6 arguments (or 5 plus a defaulted 6th), so which overload PostgreSQL picks is ambiguous by argument count — and the 5-arg one is weaker: it checks `COALESCE("IsActive", true)` and **omits `IsDeleted` entirely**, so it can resolve soft-deleted rows. Drop the 5-arg overload and keep one definition. Both files live in `DatabaseScripts/Functions/import/`; delete `resolve_foreign_key_id.sql` and keep the tenant-aware rewrite of `resolve_foreign_key_id2.sql` under a single canonical filename.

### P10.5 `PSSBLOB` literal — already tracked

`ImportFileStorageService.cs:28` queries `StorageAccountCode == "PSSBLOB"` while its own doc comment says `IMPORT_BLOB_STORAGE`. Tracked as **P6.11**; listed here only so the hardcoded-value sweep is complete. Not a duplicate work item.

### P10.6 Not findings — do not "fix" these

Confirmed benign during the sweep; leave them alone:

- `COALESCE(a."CountryId", 0) = COALESCE(v_addr_country_id, 0)` (execute 946–949) — NULL-safe comparison sentinels in the address idempotency guard, not FK values.
- `'IMPORT'` / `'VALIDATION'` (execute 212, 1194; validate 153, 163) — `"Operation"` discriminators on the progress row.
- `"CreatedBy"` / `"AssignedByUserId"` — every insert passes `v_user_id`, read from the session. Correct.
- `FALSE  -- IsFamilyHead default` (execute 569) — a boolean domain default, not a foreign key.
- `'true'/'yes'/'1'` in `FileParserService.cs:168` — boolean token parsing.

### P10.7 Sequencing

P10.1 is a tenant-isolation defect and belongs with **P1**, not at the end of the queue. P10.2–P10.4 edit `ContactImport-fn-execute.sql`, so they inherit the **P0 prerequisite** exactly as P3.1 and P6.12 do — reconcile the repo↔DB fork first, or the fix will be written against a stale file. Sequence P10.2 → P10.3 → P10.4 in one pass over the function; do not open it three times.

---

## 2. Blob storage requirements (hand to the tech team)

The blob work is with the user's tech team. These are the requirements — do not block P1–P8 on them:

- Private container, no public access (**already correct**).
- Path `imports/{companyId}/{yyyy}/{MM}/{dd}/{guid}{ext}` — no user-controlled segment (P6.9).
- Lifecycle rule: delete after N days, aligned with the 30-day staging retention.
- Downloads via short-lived (≤15 min) user-delegation SAS, generated **only** after a tenant-ownership check. Never a public URL.
- Separate container or prefix + policy for quarantined / unscanned uploads.
- Managed identity instead of a connection string in `StorageAccounts` where the hosting allows.
- AV scan on upload, quarantine until clean.

---

## 3. Definition of done per phase

1. Code compiles (**the user builds — do not run `dotnet build`**).
2. Any schema change is listed for the user with the exact migration name to create. Never generate it yourself.
3. Seed SQL is idempotent, PostgreSQL-dialect, re-runnable, and placed in `sql-scripts-dyanmic/`.
4. Changes staged in **all three** repos as applicable (outer, `PSS_2.0_Backend`, `PSS_2.0_Frontend`) — `git add` only, **never commit**.
5. Report: what changed, which files, which migrations the user must create, which seed scripts to run and in what order, and anything deferred with the reason.

## 4. Do not

- Do not implement Custom Fields.
- Do not implement email delivery of import outcomes.
- Do not build a new notification or intimation mechanism — use `INotificationDispatcher` and `IIntimationService`.
- Do not fork the grid or form components.
- Do not implement anything tagged `[FUTURE]` in the review (column-mapping UI, dry-run, upsert, undo-import, import profiles, CSV, API import).
- **Do not edit `import.contact_import_validate_batch` or `import.contact_import_execute_batch` directly in the database.** The files in `sql-scripts-dyanmic/` are authoritative; change them, then apply. Editing in the DB is what caused the fork P0 exists to repair.
- Do not re-widen STEP 13e's combination check beyond per-contact scope, and do not drop the `IsUniqueInFile` / `IsConditional` gating on STEP 13d — both cause the false positives they were written to remove.
- Do not add an execute-side duplicate skip without deciding whether it is RowDecision-gated (see the P0.3 table). An ungated value-uniqueness skip silently overrules the staff accept/omit decision.
- **Do not add parallelism inside a single import** (parallel batch loops / multi-threaded row processing). It breaks every read-then-insert duplicate guard, progress ordering, resume, and determinism. See P9.1.
- **Do not implement concurrency as an application-level `if (anyRunning)` check.** Check-then-act races; the partial unique index in P9.2 is the enforcement mechanism.
- **Do not reject an upload or an Import Now because another import is in flight.** The decided behaviour is queue-and-wait (P9), which supersedes the earlier P1.6 rejection rule.
- **Do not replace a hardcoded fallback ID with a different hardcoded fallback ID, and do not keep a fallback at all.** When a default lookup cannot be resolved from the database, the import must fail loudly (P10.2). A silently-wrong FK on 50,000 rows is worse than a failed import.
- **Do not add new `resolve_foreign_key_id` call sites with literal schema/table arguments.** New lookups go through the metadata map (P10.3).
- Do not change the staging → validate → review → commit architecture. The review's verdict is that it is **correct**; the gaps are in the cross-cutting layers, not the pipeline.
