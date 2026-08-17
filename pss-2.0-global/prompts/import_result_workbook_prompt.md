# Import result workbook — permanent outcome file, shorter staging retention

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. State the migration; the user creates it.
- Do NOT execute SQL against any database. Idempotent scripts, handed off.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.

---

## The problem

Per-row import outcomes — which rows failed, and why — exist in exactly one place: the session's
dynamically created `import.staging_{grid}_{sessionId}` table.

That table is dropped. `ImportExecutionService.cs:502-503` stamps
`StagingRetainUntil = now + 30 days` on completion, and `DropExpiredStagingTablesJob` (nightly, 2 AM)
drops it once that passes. From day 31 the session row survives with counts only, and **every error
message for that import is gone permanently**. There is no export, no archive, no second copy.

Meanwhile the uploaded source file sits in blob storage forever — `ImportFileStorageService` has
upload, download and exists, and **no delete method at all**. So today the platform keeps the input
forever and throws the results away. That is backwards.

Staging is also the expensive copy: one permanent table per session, every column `TEXT` and
uncompressed, carried into backups and replicas, adding catalog rows and autovacuum work per table.

## The fix, in one line

At terminal status, generate a **result workbook** from the staging table, store it in blob storage as
a **separate object**, record its path on the session — then shorten staging retention from 30 days to
7.

---

## Decisions already made — implement these, do not re-litigate

**1. Never mutate the uploaded file.** The original upload is the audit record of what the user
actually submitted, and re-validation re-reads it. A write that fails halfway destroys the input for a
session that can no longer be re-run. The result is a *new* object; the source is immutable.

**2. Generate at terminal status, not at drop time.** When the session reaches `Completed`, `Failed`
or `Cancelled`, staging is warm and the data is right there. Generating on day 30 instead makes the
permanent record depend on a Hangfire job firing correctly a month later — if it fails, the data is
gone with nothing to regenerate from.

**3. Shorten retention to 7 days — do not drop immediately.** The interactive review grid (search,
filter, page, status tabs) is what people actually use in the first week, and a downloadable workbook
cannot replace it. Seven days keeps the useful window and removes 23 days of storage per session. Net
result is cheaper *and* strictly more capable than today, because failure history becomes permanent
instead of vanishing at day 31.

---

## What to build

### A. Result generation service (backend)

New service in `Base.Support/Import/Services/` or alongside the existing import services — match where
`ImportExecutionService` and `ImportParseService` live.

Trigger: **every terminal transition** — `Completed` (9), `Failed` (10), `Cancelled` (11). Find all of
them; there is more than one code path. At minimum `ImportExecutionService`,
`ImportScheduledExecutionService` and `ImportQueueDispatcher` all stamp terminal state today (grep for
`StagingRetainUntil` and for `FailedRetainUntil` to find them). A path that stamps terminal status and
skips generation silently loses that session's history — enumerate every one you found and confirm each
is covered.

Hard requirements:

- **Generation must never fail the import.** A session that imported 4,000 rows successfully does not
  become `Failed` because a workbook could not be written. Wrap it, log it, stamp the session so the
  failure is visible, and let the import stand. Say how a generation failure surfaces to an
  administrator — silent is not acceptable either.
- **Idempotent.** A retried job must not produce a second file or a second blob object. Decide and
  state the key.
- **Streamed, not buffered.** Sessions run to tens of thousands of rows. Do not load the whole staging
  table into a `List<>` and then into memory as a workbook — page the read and write incrementally.
  State the page size and where it came from (reuse an existing import batch constant if one fits;
  do not invent a second one).
- **Cancelled sessions still get a file.** A cancellation mid-import is exactly when someone needs to
  know which rows made it.

### B. Workbook contents

One sheet minimum, and justify any additional sheet you add:

- Every staging row, in source order, anchored by **`SourceRowNumber`** — the real spreadsheet row, not
  the staging `Id`. P8.10 exists because those diverge; a result file that reports staging ids is
  useless for fixing the original file.
- All data columns, headers taken from `ImportGridFields` display names.
- Outcome per row: validation status, execution status, and the **error messages** — the whole reason
  this file exists.
- A summary block or sheet: file name, grid, submitted by, timestamps, total / valid / invalid /
  imported / execution-failed counts.

**P6.6 formula-injection sanitisation is mandatory** and this is the trap in this task. The existing
sanitiser is **frontend TypeScript** —
`PSS_2.0_Frontend/src/presentation/components/custom-components/import-wizard/import-cell-sanitize.ts`,
used by the P8.2 exporter `import-error-report-export.ts`. That exporter builds the workbook in the
browser with SheetJS and **cannot be called server-side**. So:

- You are writing a second sanitiser, in C#, and it must apply the identical rule to identical data —
  read the TypeScript one and match it exactly, including its numeric-value carve-out.
- Say plainly in your report that two implementations of this rule now exist and where they are, so the
  next person editing one knows to edit the other. Do not pretend this is reuse.
- Sanitise **column headers** too. They are tenant-authored on `ImportGridFields`.

For the writer itself, use whatever the backend already depends on —
`Base.Application/Business/ReportAuditBusiness/AuditLogs/ReportExport/ExportAuditTrailExcel.cs` already
writes xlsx. Reuse that dependency; do not add a second spreadsheet library.

**Column parity with the P8.2 download.** The administrator can download the browser-built report on
day 3 and the stored result file on day 30. Two files with the same purpose and different columns is a
support ticket. Either align the two column sets and say so, or state the deliberate difference and
why.

### C. Storage

Extend `ImportFileStorageService` (`Base.Infrastructure/Services/Import/`) with a result path builder
and upload, mirroring `BuildImportFilePath` / `UploadImportFileToPathAsync`. Same tenant-scoped
container conventions as the source file — read what `BuildImportFilePath` does and follow it, do not
invent a new layout.

**Never expose the blob path or a blob URL to the client** (P1.7). Download goes through an
authenticated API endpoint that streams the object; the client sends a session id and gets bytes.

### D. Schema

`ImportSession` needs, at minimum, the result blob path and when it was generated. Decide the full set
— a generation-failure indicator belongs here if that is how you surface failures — and justify each
field.

**Do not create the migration.** State the exact columns, types and nullability the user must add.
Every new column is nullable: existing sessions have no result file and never will.

### E. Retention change

`ImportStagingRetention` holds the constants (`CompletedRetainUntil`, `FailedRetainUntil`). Change
completed retention 30 → 7 days.

- **Decide and justify failed-session retention separately.** Failed sessions are the ones people
  re-open, and the argument for a longer window is stronger there. Do not blindly apply 7 to both.
- Read the value from configuration if the surrounding code already does; do not hardcode over an
  existing settings pattern.
- Confirm nothing else assumes 30 days — grep for the constant and for the raw number.
- **Guard the ordering.** Shortening retention while result generation is not yet deployed destroys
  history faster than today. State how the two changes are sequenced safely, and whether existing
  sessions with a 30-day `StagingRetainUntil` already stamped should be left alone (they should — say
  why or argue otherwise).

### F. Frontend

`import-session-detail-dialog.tsx` already exists and already has a summary-only mode for dropped
staging. Today that mode says the detail is no longer retained. It becomes a **download**:

- Staging alive → existing interactive grid, unchanged, plus the existing P8.2 export.
- Staging dropped, result file present → summary plus a **Download result file** action.
- Staging dropped, no result file (every session that terminated before this feature shipped) → the
  current honest message. Do not show a download that 404s.

Keep the existing `sanitizeCell` usage on everything rendered. No `window.confirm` / `alert` /
`prompt`.

### G. Authorization — do not skip

The download endpoint takes a session id from the client, which is user-supplied and untrusted.

- Scope to the caller's `CompanyId` server-side, exactly as the existing session queries do.
- Route grid access through `ImportGridAuthorization.EnsureGridAccessAsync` (P1) — a user with Contact
  import rights must not download a `BULKDONATION` result file. Do not reimplement the check.
- A session id belonging to another tenant must return the same response as one that does not exist.

---

## Also handle: blobs are never deleted

While you are in `ImportFileStorageService`, note that neither the source upload nor the new result
file has any expiry. `AzureBlobFileStorageService.cs:59` has a generic `DeleteFileAsync` that nothing
calls for imports.

This is a PII inconsistency, not just cost: staging holding personal data is dropped at 7 days, while
the source file holding the same personal data is kept forever with no policy.

**Do not implement blob deletion in this task** — deleting the audit record of what a user submitted is
a decision with legal weight and the user has not made it. Instead, report: what a retention policy
would need to cover (source file, result file, different windows likely), where the sweep would live,
and what the user must decide. One paragraph, in the output.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. Every terminal-status code path you found, and confirmation each one generates the result file.
2. How generation failure is contained, surfaced, and made idempotent on retry.
3. The workbook's sheets and columns, and whether they match the P8.2 browser export or deliberately differ.
4. The C# sanitiser: where it lives, how you verified it matches the TypeScript rule, and an explicit note that the rule now has two implementations.
5. How the read is paged/streamed, the page size, and where that number came from.
6. Exact `ImportSession` columns the user must add — name, type, nullability — and why each is needed.
7. The retention values you set for completed and failed, with the reasoning for treating them differently or the same, and how the change is sequenced safely against deployment.
8. How the download endpoint enforces tenant and grid authorization, and that no blob path reaches the client.
9. The three frontend detail-view states and how the pre-feature (no result file) case behaves.
10. The blob-retention paragraph: what a policy must cover and what the user must decide.
11. Anything you could not complete and why.
