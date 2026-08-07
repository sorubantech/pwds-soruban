# PSS 2.0 — Bulk Email Job Reliability Build Prompt

> **Status:** NOT BUILT (written 2026-08-05) · BE + FE · **no migration** · **1 seed user-owned (verification only)**
> **Scope:** the bulk email job pipeline itself — duplicate sends, retries, pause/cancel, honest job status, provider fallback.
> **Depends on:** `PSS-2.0-COMMUNICATION-METERING-BUILD-PROMPT.md` — **run that one FIRST.** Both prompts edit `EmailExecutorService.cs` and `EmailSenderService.cs`; metering is the smaller diff and this prompt assumes its hooks are already in place.
> **Does not supersede anything.** No entity gets a new column. No table is created.

---

## ⚠️ Rules for whoever builds this

1. **Do not run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add` / `remove` / `database update`, never hand-author a migration or snapshot. **This build needs no migration** — if you think it does, stop and re-read §③.
3. **Frontend typecheck must actually run:** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, **no pipe**. Only **exit 0** counts. A run reporting only a pre-existing `TS2688` checked zero files.
4. **`PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored** — the Grep/Glob tools return zero `.cs` matches. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory. A repo-wide backend grep times out at 120 s. Absolute-path `Read` works.
5. **UTC only.** Every date column is `timestamp with time zone`; Npgsql throws on `Kind=Unspecified`. `DateTime.UtcNow`, `DateTimeKind.Utc` boundaries, never `DateTime.Today` in an EF predicate.
6. **HotChocolate** strips `Get` from resolver names and appends `Input` to input types. `tsc` cannot see GraphQL field names — verify against the generated schema.
7. **Never assume a property or column name.** Read the file. Audit fields are `createdDate` / `modifiedDate`.
8. **Do not "fix" anything outside §④.** This pipeline is load-bearing and the diff must stay readable.

---

## ⓪ What is actually on disk (verified 2026-08-05)

### The pipeline, as built

| Step | Where | What it does |
|---|---|---|
| 1 | `CreateEmailSendJob.cs:139` / `:147` / `:158` | MediatR. Saves the job row, hands off to Hangfire (`Enqueue` / `Schedule` / recurring). Returns immediately. |
| 2 | `EmailExecutorService.ProcessBulkEmailJobAsync` | Hangfire. Sets status PROCESSING, resolves recipients, renders, bulk-inserts `notify.EmailSendQueues`, enqueues step 3 at `:353`. |
| 3 | `EmailSenderService.SendQueuedEmailAsync` | Hangfire. Sets status SENDING, resolves the PRIMARY provider, calls `IParallelEmailOrchestrator.ProcessJobAsync`, writes final status + `NextExecutionAt`. |

### Already built and correct — do not rebuild

| Path | State |
|---|---|
| `Base.Support/Email/Services/EmailMasterDataHelper.cs:22-29` | ✅ Job statuses already defined: `PENDING`, `QUEUED`, `PROCESSING`, `SENDING`, `COMPLETED`, `FAILED`, **`CANCELLED`**, **`PAUSED`** |
| `EmailMasterDataHelper.cs:32-40` | ✅ Email statuses: `QUEUED`, `SENDING`, `SENT`, `DELIVERED`, `FAILED`, `BOUNCED`, `DROPPED`, `SKIPPED`, `BLOCKED` |
| `Base.Domain/Models/NotifyModels/EmailSendQueue.cs` | ✅ Retry columns already exist: `RetryCount`, `LastRetryAt`, `NextRetryAt`, `MaxRetryAttempts`, plus `ErrorCode`, `ErrorMessage`, `BounceType`, `BounceReason` |
| `Base.Domain/Models/NotifyModels/EmailExecutionLog.cs` | ✅ Rich per-attempt log: `LogLevel`, `LogType`, `ProviderErrorCode`, `HttpStatusCode`, `RetryAttempt`, `ExecutionTimeMs` |
| `DeleteEmailSendJob.cs:59-64` | ✅ **Correctly** cleans up Hangfire: `BackgroundJob.Delete(HangfireJobId)` and `RecurringJob.RemoveIfExists(HangfireRecurringJobId)`. Copy this pattern in §④.4. |
| `Base.Support/Email/Workers/ParallelEmailOrchestrator.cs` | ✅ Worker fan-out with isolated DbContext per worker, `Skip`/`Take` windows, returns `EmailJobResult { TotalProcessed, TotalSuccess, TotalFailed, WorkersUsed, Duration, WorkerResults }` |

> **Read the two tables above again.** `CANCELLED`, `PAUSED`, and every retry column **already exist**. This build writes almost no new schema and no new concepts. It makes the code use what is already there.

### Defects this build fixes

**D1 — ★ A failing bulk job is silently re-run up to 10 times, re-sending the whole campaign.**

`ProcessBulkEmailJobAsync` and `SendQueuedEmailAsync` carry **no `[AutomaticRetry]` attribute**. Hangfire's default is **10 attempts**. Both methods are wrapped in `try { … } catch (Exception ex) { … }` that logs — and, at the end of the catch, rethrows or lets Hangfire see the failure.

Every other Hangfire job in this codebase already knows this is dangerous:

```
Base.Application/Services/OnlineDonationMapJobs/OnlineDonationMapJobRunner.cs:35
    [AutomaticRetry(Attempts = 0)] // we own resume/recovery; never let Hangfire silently re-run
Base.Application/Services/PlatformBilling/SubscriptionRenewalService.cs:54
    [AutomaticRetry(Attempts = 0)] // a missed run is picked up by tomorrow's tick — never silently re-charge
Base.Support/Import/Services/ImportExecutionService.cs:55           [AutomaticRetry(Attempts = 0)]
Base.Application/Services/EventCommunications/EventCommunicationDispatcher.cs:62  [AutomaticRetry(Attempts = 0)]
```

The email pipeline — the one that talks to the outside world and cannot be undone — is the **only** one without it.

> ⚠️ Concretely: a 12,000-recipient newsletter that throws after queuing 12,000 rows gets re-run by Hangfire. Step 2 has no idempotency guard (D2), so it queues 12,000 **more** rows. Ten times. Your donors receive the same appeal up to ten times, and — once the metering prompt ships — it burns the tenant's quota ten times over. **This is the highest-severity item in this document.**

**D2 — Step 2 has no idempotency guard.** `ProcessBulkEmailJobAsync` reads the job at `:68`, sets it PROCESSING at `:78`, and never checks what the status *was*. A re-entry for any reason — Hangfire retry, a double `Enqueue`, an operator re-trigger — re-queues the entire recipient set. Nothing deduplicates `EmailSendQueues` rows.

**D3 — The retry columns are dead.** `EmailExecutorService.cs:302-303` writes them at insert:

```csharp
RetryCount        = 0,
MaxRetryAttempts  = 3,
```

and that is the **only** place in the entire solution any of `RetryCount`, `MaxRetryAttempts`, `NextRetryAt`, `LastRetryAt` is touched. Nothing ever retries. A transient 429 or a 5xx from the provider kills that recipient permanently, and the job still reports COMPLETED (D4).

**D4 — A near-total failure is reported as COMPLETED.** `EmailSenderService.cs:106-107`:

```csharp
var finalStatus = result.TotalFailed == 0 ? jobCompletedStatusId :
                 result.TotalSuccess == 0 ? jobFailedStatusId : jobCompletedStatusId;
```

Trace it: 4,999 of 5,000 failed, 1 succeeded → `TotalFailed != 0`, `TotalSuccess != 0` → **COMPLETED**. The tenant is told their campaign went out. `PARTIAL` is not in the master-data list either (§③.1).

**D5 — Step 2 never marks itself complete.** `EmailExecutorService.cs:335-340` — the status write is commented out:

```csharp
// Update job status to COMPLETED (queuing phase complete)
//await _emailSendJobRepository.UpdateJobStatusAsync(emailSendJobId, completedStatusId, cancellationToken);
//await _emailSendJobRepository.UpdateJobExecutionTrackingAsync(
//    emailSendJobId,
//    lastExecutionEndedAt: DateTime.UtcNow,
//    cancellationToken: cancellationToken);
```

`completedStatusId` is resolved at `:59` and then unused. A job stuck between step 2 and step 3 sits at PROCESSING forever with no way to tell "still queuing" from "step 3 never fired".

**D6 — Pause does nothing.** `ToggleEmailSendJobStatusHandler` flips `emailSendJob.IsActive` and **never touches Hangfire** — no `RecurringJob.RemoveIfExists`, no `BackgroundJob.Delete`. `DeleteEmailSendJob.cs:59-64` does it correctly; Toggle does not. So a user who "pauses" a recurring newsletter watches it send again next week.

**D7 — There is no cancel-in-flight.** Once step 2 has queued the rows, nothing stops step 3. There is no kill switch for a campaign sent to the wrong segment.

**D8 — The fallback provider is fetched and thrown away.** `EmailExecutorService.cs:176-185` assigns `companyFallbackEmailProvider`, then re-tests `companyEmailProvider` in the condition below it. The fallback never engages. Separately, `EmailSenderService.cs:83-91` selects only `EmailProviderType.DataValue == "PRIMARY"` and throws when there is none — it never looks at the fallback at all.

**D9 — Batching is vestigial.** `EmailExecutorService.cs:275` sets `int batchNumber = 1;` and nothing ever increments it. The `foreach` at `:280` builds one flat list; `:353` enqueues step 3 exactly once with `batchNumber: 1`. So `EmailSendQueue.BatchNumber` is always 1 and step 3's `batchNumber` parameter is always 1. **Not a bug — but do not write code that assumes batching works.** Leave it as is (§⑦).

**D10 — Untyped exceptions everywhere.** `throw new Exception($"Email job was not found…")` (`:71`), `throw new Exception("Job executed with 0 valid recipients.")` (`:224`), `throw new Exception($"No primary email provider configured for company {companyId}")` (`EmailSenderService.cs:90`). A bare `Exception` cannot be caught selectively, which is exactly what §④.1 needs.

---

## ① The one idea

**Send it once, retry only what deserves retrying, and tell the truth about what happened.**

Three failures, three fixes:

| Today | After |
|---|---|
| A job that throws is silently re-run by Hangfire and re-sends the whole campaign | Hangfire never retries; **we** own recovery, and step 2 refuses to run twice |
| A single provider hiccup permanently drops that recipient | Transient failures retry with backoff; permanent ones do not |
| "COMPLETED" whether 5,000 or 1 email got through | `COMPLETED` / `PARTIAL` / `FAILED` / `PAUSED` / `CANCELLED`, each meaning what it says |

---

## ② Design

### ②.1 Never let Hangfire re-run an email job

`[AutomaticRetry(Attempts = 0)]` on both entry points, with the same comment style the rest of the codebase uses.

Retrying a send is not like retrying an import. An import is idempotent-ish and reversible. **An email is neither.** Once it is in someone's inbox there is no undo, no credit note and no apology that helps.

So: Hangfire retries nothing. Recovery is explicit, owned by us, and visible in the UI (§④.6).

### ②.2 Step 2 refuses to run twice

Before doing anything, step 2 checks its own status:

- `PENDING` / `QUEUED` / `PAUSED` → proceed.
- `PROCESSING` / `SENDING` → **another run owns this job.** Log a warning, return. Do not throw — throwing invites a retry.
- `COMPLETED` / `PARTIAL` / `FAILED` / `CANCELLED` → terminal for a one-shot job. Return.
- **Exception:** a `RECURRING` job legitimately re-runs from a terminal status. Gate on job type, not status alone (§④.2).

The guard is a `PROCESSING` status write acting as a claim. Not a distributed lock — with `[AutomaticRetry(Attempts = 0)]` and a single enqueue point the race window is negligible, and a `pg_advisory_xact_lock` here would be over-engineering.

### ②.3 Retry the transient, never the permanent

The columns already exist. Populate them.

| Provider outcome | Retry? | Why |
|---|---|---|
| HTTP 429 (rate limited) | ✅ yes | Their throttle, not our problem with the address |
| HTTP 5xx | ✅ yes | Their outage |
| Timeout / socket error | ✅ yes | Transient |
| HTTP 4xx other than 429 | ❌ no | Bad request or bad credentials — retrying repeats the same mistake |
| Hard bounce (`BounceType = 'HARD'`) | ❌ **never** | The mailbox does not exist. Retrying a hard bounce is how you get your sending domain blocked. |
| Soft bounce (`BounceType = 'SOFT'`) | ❌ not in this build | Needs the webhook path; out of scope (§⑦) |
| Suppressed / dropped | ❌ never | They asked us to stop |

`MaxRetryAttempts = 3` (already the default written at `:302-303`). Backoff **5 min → 30 min → 2 h**, written into `NextRetryAt`. A recurring Hangfire sweep picks up due rows.

> **Deliverability, not just correctness.** Hammering a dead address is the single fastest way to wreck a sending reputation — and on the shared platform sender, one tenant's bad list damages every tenant's delivery. The hard-bounce rule is not optional.

### ②.4 Honest status

Add `PARTIAL` to the job-status master data (§③.1) and replace the D4 ternary:

| Result | Status |
|---|---|
| `TotalFailed == 0` | `COMPLETED` |
| `TotalSuccess == 0` | `FAILED` |
| both non-zero | **`PARTIAL`** |
| retries still pending | leave `SENDING` until the sweep drains them |

### ②.5 Pause and cancel mean different things

| Action | Hangfire | Queue rows | Reversible |
|---|---|---|---|
| **Pause** (recurring only) | `RecurringJob.RemoveIfExists` | untouched | ✅ Resume re-registers it |
| **Cancel** (in flight) | `BackgroundJob.Delete` | unsent rows → `BLOCKED` with a skip reason | ❌ No |

Sent is sent. Cancel stops what has not left; it never claims to recall what has.

---

## ③ Data

### ③.1 Seed — `email-job-status-partial-seed.sql` (user-owned)

Into repo-root `sql-scripts-dyanmic/`. Idempotent.

One `MasterData` row under `MasterDataType` code **`EMAILSENDJOBSTATUS`**:

| Code | Value | Notes |
|---|---|---|
| `PARTIAL` | `Partially Sent` | Sort order after `COMPLETED` |

Then add the matching constant to `EmailMasterDataHelper.cs` beside its siblings at `:22-29`:

```csharp
public const string JOB_STATUS_PARTIAL = "PARTIAL";
```

**Verification query to ship with the seed** — `CANCELLED` and `PAUSED` are declared in code but may never have been seeded. Confirm all eight exist under `EMAILSENDJOBSTATUS` before building §④.4/§④.5, or those paths will throw a `KeyNotFoundException` at `GetMultipleMasterDataIdsByCodesAsync`:

```sql
SELECT "DataCode" FROM app."MasterDatas" md
JOIN app."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
WHERE mdt."TypeCode" = 'EMAILSENDJOBSTATUS'
ORDER BY "DataCode";
-- expect: CANCELLED, COMPLETED, FAILED, PARTIAL, PAUSED, PENDING, PROCESSING, QUEUED, SENDING
```

### ③.2 No migration

Every column this build needs already exists:

- Retry: `RetryCount`, `MaxRetryAttempts`, `NextRetryAt`, `LastRetryAt`, `ErrorCode`, `ErrorMessage` on `EmailSendQueue`.
- Cancel: `SkipReason`, `EmailSendStatusId` on `EmailSendQueue`.
- Job: `IsActive`, `HangfireJobId`, `HangfireRecurringJobId`, `JobStatusId`, `LastExecutionEndedAt`, `NextExecutionAt` on `EmailSendJob`.

**If you find yourself wanting a new column, you have gone outside §④.** Stop and re-read §⑦.

---

## ④ Build steps

### ④.1 Typed exceptions

Add to `Base.Application/Exceptions/` (or the nearest existing email exception file — read first):

```csharp
public sealed class EmailJobAlreadyRunningException : Exception   // step 2 re-entry
public sealed class EmailJobNoRecipientsException  : Exception
public sealed class EmailProviderNotConfiguredException : Exception
```

Replace the three bare `throw new Exception(...)` at `EmailExecutorService.cs:71`, `:224` and `EmailSenderService.cs:90` (D10). Keep the message text — the FE and the log both read it.

### ④.2 ★ Stop the duplicate send

**a. Both entry points get the attribute.** On `EmailExecutorService.ProcessBulkEmailJobAsync` and `EmailSenderService.SendQueuedEmailAsync`:

```csharp
[AutomaticRetry(Attempts = 0)] // an email cannot be unsent — we own recovery, never let Hangfire silently re-run
```

Match the comment style already used at `OnlineDonationMapJobRunner.cs:35`.

**b. The idempotency guard.** In `ProcessBulkEmailJobAsync`, immediately after the job is loaded at `:68-71` and **before** the PROCESSING write at `:78`:

```csharp
// P-26 §②.2 — this job is not re-entrant. Hangfire no longer retries it, but a double-enqueue,
// an operator re-trigger or a redeploy mid-flight would otherwise re-queue the entire recipient set.
var jobTypeCode = /* resolve EmailSendJobType.DataCode — read EmailMasterDataHelper first */;
var currentStatusCode = /* resolve EmailJobStatus.DataCode */;

if (currentStatusCode is EmailMasterDataHelper.JOB_STATUS_PROCESSING
                      or EmailMasterDataHelper.JOB_STATUS_SENDING)
{
    await LogAsync(new EmailExecutionLogDto { … LogLevel = EmailLogLevel.Warning,
        LogMessage = $"Job {emailSendJobId} is already {currentStatusCode}; this run is a duplicate and was skipped." },
        cancellationToken);
    return;   // ← RETURN. Never throw: a throw is what invites a re-run.
}

if (jobTypeCode != EmailMasterDataHelper.JOB_TYPE_RECURRING
    && currentStatusCode is EmailMasterDataHelper.JOB_STATUS_COMPLETED
                         or EmailMasterDataHelper.JOB_STATUS_PARTIAL
                         or EmailMasterDataHelper.JOB_STATUS_FAILED
                         or EmailMasterDataHelper.JOB_STATUS_CANCELLED)
{
    // terminal for a one-shot job
    await LogAsync(… "already terminal …");
    return;
}
```

> `return`, not `throw`, in both branches. With `Attempts = 0` a throw would not retry — but it would mark the Hangfire job failed and mislead whoever reads the dashboard. A skipped duplicate is a warning, not a failure.

**c. Belt and braces.** Before the bulk insert at `~:310`, delete or skip any existing `EmailSendQueues` rows for `(EmailSendJobId, BatchNumber)` that are still `QUEUED`. If the guard ever leaks, this stops the actual duplicate mail.

### ④.3 Uncomment and fix the step-2 completion write (D5)

At `EmailExecutorService.cs:335-340`, restore the block — but **do not** write `COMPLETED`. Step 2 has only queued; step 3 has not run.

```csharp
// Queuing phase done — the job is QUEUED, not COMPLETED. Step 3 owns the terminal status.
await _emailSendJobRepository.UpdateJobStatusAsync(emailSendJobId, queuedStatusId, cancellationToken);
```

Resolve `JOB_STATUS_QUEUED` into the `statusCodes` dictionary at `:46-56`. `completedStatusId` at `:59` becomes genuinely unused in this method — **remove it**, do not leave it dangling.

### ④.4 Pause / resume (D6)

Rewrite `ToggleEmailSendJobStatusHandler` so flipping `IsActive` also acts on Hangfire, copying the pattern proven at `DeleteEmailSendJob.cs:59-64`:

- **Deactivating**, job type `RECURRING` → `RecurringJob.RemoveIfExists(emailSendJob.HangfireRecurringJobId)`, status → `PAUSED`.
- **Deactivating**, job type `SCHEDULE` and not yet started → `BackgroundJob.Delete(emailSendJob.HangfireJobId)`, status → `PAUSED`.
- **Reactivating**, `RECURRING` → re-register from `RecurringCronExpression`, store the new `HangfireRecurringJobId`, status → `PENDING`.
- **Reactivating**, `SCHEDULE` with `ScheduleStartDatetime` in the past → do **not** fire immediately. Status → `FAILED` with `"Scheduled time has passed. Edit the schedule and save to re-arm."`
- A job already `PROCESSING` or `SENDING` → toggle is rejected. Direct the user to Cancel (§④.5).

Null-guard both Hangfire ids. `RemoveIfExists` is safe on a missing id; `BackgroundJob.Delete` on a null id is not.

### ④.5 Cancel in flight (D7)

New MediatR command `CancelEmailSendJobCommand(int emailSendJobId)`, `[CustomAuthorize(DecoratorNotifyModules.EmailSendJob, Permissions.Toggle)]` — reuse the existing permission, do **not** invent a new capability code.

1. `BackgroundJob.Delete(HangfireJobId)` if present; `RecurringJob.RemoveIfExists(HangfireRecurringJobId)` if present.
2. All `EmailSendQueues` rows for this job still at `EMAIL_STATUS_QUEUED` → `EMAIL_STATUS_BLOCKED`, `SkipReason = "Cancelled by user"`. **One `ExecuteUpdate`, not a row loop** — a cancelled campaign can be 100,000 rows.
3. Job status → `CANCELLED`, `LastExecutionEndedAt = DateTime.UtcNow`.
4. Reject with a clear message if the job is already terminal.
5. Write one `EmailExecutionLog` row: `LogType = "JOB_CANCELLED"`, who and when.

> ⚠️ Rows already `SENDING` or `SENT` are **not** touched. Cancel is best-effort by definition — the workers may be mid-flight. The UI must say so (§⑤.3).

### ④.6 Retry sweep (D3)

**a. Classify at failure.** Wherever the orchestrator records a per-email failure (read `ParallelEmailOrchestrator` / `EmailWorkerContext` — do not assume the file), set on the `EmailSendQueue` row:

- `ErrorCode` = the provider status code as a string.
- Retryable (429, 5xx, timeout) **and** `RetryCount < MaxRetryAttempts` → `NextRetryAt = UtcNow + backoff(RetryCount)`, status stays `FAILED`.
- Not retryable, or attempts exhausted → `NextRetryAt = null`. Terminal.
- `BounceType == 'HARD'`, dropped or suppressed → `NextRetryAt = null` **unconditionally**, whatever `RetryCount` says (§②.3).

```csharp
private static TimeSpan Backoff(int retryCount) => retryCount switch
{
    0 => TimeSpan.FromMinutes(5),
    1 => TimeSpan.FromMinutes(30),
    _ => TimeSpan.FromHours(2),
};
```

**b. The sweep.** A recurring Hangfire service, every 10 minutes, registered beside the existing recurring registrations (find them — do not guess the file):

```csharp
[AutomaticRetry(Attempts = 0)] // a missed tick is picked up by the next run; retrying a send is never safe
public async Task SweepDueRetriesAsync(CancellationToken cancellationToken)
```

- Selects `EmailSendQueues` where `NextRetryAt <= UtcNow` **and** `NextRetryAt != null` **and** `RetryCount < MaxRetryAttempts`, `Take(500)` per tick.
- Groups by `EmailSendJobId` and re-sends through the same provider path the orchestrator uses. Do not open a second SendGrid code path.
- On each attempt: `RetryCount++`, `LastRetryAt = UtcNow`, and either clear `NextRetryAt` on success (status `SENT`) or re-schedule per the backoff.
- **Metering:** a successful retry is a delivered email. Increment `EMAILS` (and `EMAILS_PLATFORM` if `IsPlatformProvider`) by 1, exactly as the metering prompt's Hook B does. **A retry is not a free email.** Swallow increment failures; never fail a delivered send on a counter write.
- When a job's last pending retry drains, recompute its final status via §④.7.

### ④.7 Honest final status (D4)

Replace `EmailSenderService.cs:106-107`:

```csharp
var finalStatus =
    result.TotalFailed  == 0 ? jobCompletedStatusId :
    result.TotalSuccess == 0 ? jobFailedStatusId    :
                               jobPartialStatusId;   // ← was silently jobCompletedStatusId
```

Add `JOB_STATUS_PARTIAL` to the `statusCodes` dictionary at `:66-71`. Also persist `result.TotalSuccess` → `TotalEmailsSend` and `result.TotalFailed` → `TotalEmailsFailed` on the job row through `UpdateJobExecutionTrackingAsync` — both columns exist on `EmailSendJob` and are currently never populated.

**If any queue row for the job still has a non-null `NextRetryAt`, leave the job at `SENDING`.** The sweep sets the terminal status once retries drain. A job is not finished while it still has work pending.

### ④.8 Provider fallback (D8)

**a.** Fix `EmailExecutorService.cs:176-185` — test `companyFallbackEmailProvider`, the variable that was actually fetched.

**b.** In `EmailSenderService.cs:83-91`, when no `PRIMARY` provider is found, fall back to the `FALLBACK`-type provider by `Priority` before throwing. Throw `EmailProviderNotConfiguredException` only when **both** are absent, with the message the fail-closed design requires: *"No email provider is configured. Configure a provider under Settings → Communications before sending."*

**c. No appsettings fallback. Ever.** Everything is configuration-based; a tenant with nothing configured does not send, and is told why.

---

## ⑤ UI notes

### ⑤.1 Job list — status chips

Nine statuses. Solid backgrounds, white text — **never** `bg-X-50/100`, `text-X-700/800`, `bg-muted` or `text-muted-foreground`.

| Status | Chip |
|---|---|
| `PENDING` / `QUEUED` | `bg-slate-600` |
| `PROCESSING` / `SENDING` | `bg-blue-600` |
| `COMPLETED` | `bg-green-600` |
| **`PARTIAL`** | `bg-amber-600` |
| `FAILED` | `bg-red-600` |
| `PAUSED` | `bg-yellow-600` |
| `CANCELLED` | `bg-gray-600` |

`PARTIAL` must be visually distinct from `COMPLETED`. It is the whole point of §④.7 — a tenant needs to notice at a glance.

### ⑤.2 Job detail — the numbers

Queued / Sent / Failed / Pending retry, from `TotalEmailsQueued`, `TotalEmailsSend`, `TotalEmailsFailed` and a count of rows with `NextRetryAt != null`. Right-aligned (data context).

On `PARTIAL` or `FAILED`, show the top failure reasons grouped by `ErrorCode` with counts. `ErrorMessage` and `ProviderErrorMessage` are already captured — surface them instead of making the user open the log.

Shaped `Skeleton` while loading. Explicit empty and error states.

### ⑤.3 Cancel

Confirmation dialog, and it must be honest:

> *"Cancel this campaign? 4,200 emails have already been sent and cannot be recalled. The remaining 7,800 will not be sent."*

Never imply sent mail can be recalled. Only offer Cancel while the job is `PROCESSING` or `SENDING`.

### ⑤.4 Pause / resume

Only on `RECURRING` and future-dated `SCHEDULE` jobs. On a running job the control is **disabled with a tooltip** pointing at Cancel — not hidden, or the user thinks the feature is missing.

Resuming a `SCHEDULE` job whose time has passed shows the §④.4 message before anything is called, not after.

### ⑤.5 Retry visibility

When rows have a non-null `NextRetryAt`: *"312 emails will be retried automatically. Next attempt around 14:20."* Round it — do not print a false-precision timestamp for a sweep that runs every 10 minutes.

---

## ⑥ Invariants

| # | Invariant |
|---|---|
| INV-1 | **Hangfire never retries an email job.** `[AutomaticRetry(Attempts = 0)]` on every method that sends or queues mail. |
| INV-2 | Step 2 is not re-entrant. A duplicate run **returns**; it never throws and never re-queues. |
| INV-3 | A hard bounce, drop or suppression is **never** retried, regardless of `RetryCount`. |
| INV-4 | A retry is metered like any other delivered email. |
| INV-5 | A job with pending retries is not terminal. |
| INV-6 | `COMPLETED` means every email sent. Anything less is `PARTIAL` or `FAILED`. |
| INV-7 | Pause and Cancel both act on Hangfire, not only on `IsActive`. |
| INV-8 | Cancel never touches rows already `SENDING` or `SENT`, and the UI never implies recall. |
| INV-9 | No appsettings provider fallback. Unconfigured = no send + a clear message. |
| INV-10 | Bulk status transitions use `ExecuteUpdate`, never a row loop. |
| INV-11 | A metering or logging write never breaks the send it is observing. |

---

## ⑦ Out of scope

- **Everything in the metering prompt.** Quota checks, `PlanQuota` seeds, usage panels, the 80/95 % warnings. Run that prompt first; do not re-implement its hooks.
- **Soft-bounce retry via webhooks.** Needs the `SendGridWebhookProcessor` path; separate build.
- **Bounce/complaint auto-suspend, warm-up ramps, transactional/marketing stream separation, reputation scoring.** `BounceRate`, `SpamRate`, `IpReputationScore` and `DomainReputationScore` stay unread columns.
- **Provider rate caps** — `HourlyEmailLimit`, `DailyEmailLimit`, `MonthlyEmailLimit`, `RatePerSecond` stay dead. That is throttle layer L2 and belongs in its own build.
- **Real batching (D9).** `batchNumber` stays hard-coded to 1. Do not build a batching loop; do not remove the parameter either.
- **Rewriting `ParallelEmailOrchestrator`.** Worker sizing, `Skip`/`Take` windows and DbContext isolation are as designed. Read it; do not restructure it.
- **A new capability code for Cancel.** Reuse `Permissions.Toggle`.
- **Add-on packs, SMS, WhatsApp.** Not this build, not this channel.

---

## ⑧ Acceptance

| # | Check |
|---|---|
| 1 | `grep -n "AutomaticRetry" Base.Support/Email/Services/EmailExecutorService.cs Base.Support/Email/Services/EmailSenderService.cs` → both present, `Attempts = 0`. |
| 2 | Force a throw inside step 2 after the bulk insert. Hangfire shows **one** failed job, not ten. `EmailSendQueues` holds exactly one row per recipient. |
| 3 | Invoke `ProcessBulkEmailJobAsync` twice for the same job id. The second run logs a warning, returns, and inserts zero rows. The Hangfire job shows **succeeded**, not failed. |
| 4 | A `RECURRING` job at status `COMPLETED` still runs on its next tick — the terminal guard does not trap it. |
| 5 | After step 2, the job status is `QUEUED` (not `PROCESSING`, not `COMPLETED`). |
| 6 | A send with 1 success and 4,999 failures ends `PARTIAL`, with `TotalEmailsSend = 1` and `TotalEmailsFailed = 4999` persisted. |
| 7 | All-success ends `COMPLETED`; all-fail ends `FAILED`. |
| 8 | A 429 sets `NextRetryAt ≈ UtcNow + 5 min`, `RetryCount` unchanged until the attempt runs. |
| 9 | A hard bounce sets `NextRetryAt = null` with `RetryCount = 0`. It is never picked up by the sweep. |
| 10 | A 400 (bad request) sets `NextRetryAt = null`. Not retried. |
| 11 | The sweep retries a due row, and on success sets `SENT`, `RetryCount = 1`, `NextRetryAt = null`. |
| 12 | That successful retry incremented `billing.UsageCounter` for `EMAILS` by exactly 1. |
| 13 | A row that exhausts `MaxRetryAttempts = 3` stops being selected by the sweep. |
| 14 | A job with pending retries stays `SENDING`; when the last one drains it moves to `COMPLETED` or `PARTIAL`. |
| 15 | Pausing a `RECURRING` job removes it from Hangfire — verified in the Hangfire dashboard — and it does not fire on its next scheduled tick. |
| 16 | Resuming re-registers it with a new `HangfireRecurringJobId` and it fires on the following tick. |
| 17 | Toggling a `PROCESSING` job is rejected with a message pointing at Cancel. |
| 18 | Cancel deletes the Hangfire job, flips only `QUEUED` rows to `BLOCKED` with `SkipReason`, leaves `SENT` rows untouched, and sets the job `CANCELLED`. |
| 19 | Cancel on a 100,000-row job issues one `ExecuteUpdate`, not 100,000 updates. |
| 20 | With only a `FALLBACK` provider configured, a send succeeds through it. With neither, it fails with the configure-a-provider message and **no appsettings key is read**. |
| 21 | All nine job-status codes resolve from master data — no `KeyNotFoundException` from `GetMultipleMasterDataIdsByCodesAsync` on any path. |
| 22 | No bare `throw new Exception(` remains in either service. |
| 23 | `PARTIAL` renders `bg-amber-600` + `text-white` and is visually distinct from `COMPLETED`. |
| 24 | The cancel dialog states the already-sent count and does not imply recall. |
| 25 | `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` → **exit 0**, no pipe. |
| 26 | Every new GraphQL field name verified against the generated schema (rule 6). |
| 27 | No migration file, snapshot or `dotnet ef` invocation in the diff. No new entity column anywhere. |

---

## ⑨ Open questions

| # | Question | Status |
|---|---|---|
| **Q1** | Backoff 5 min → 30 min → 2 h, `MaxRetryAttempts = 3`. Ratified? | Assumed. `3` is already the on-disk default at `:302-303`; the intervals are mine. Changes two constants, no structure. Build may start. |
| **Q2** | Sweep cadence — 10 minutes assumed. Faster drains retries sooner but polls a large table more often. | Assumed. Blocks nothing. |
| **Q3** | On `PARTIAL`, should the tenant get an in-app notification, or is the job list enough? | Recommend **notify** — a silent partial failure is how a campaign quietly misses half its audience. Needs the PROMPT-22 service and `NOTIFY_ADMIN_ROLE_CODES`. |
| **Q4** | Are `CANCELLED` and `PAUSED` actually seeded in `EMAILSENDJOBSTATUS`? Declared in code since day one; never written by any code path, so possibly never seeded. | ⚠️ **Run the §③.1 query before building §④.4/§④.5.** If missing, they join the same seed file. |
| **Q5** | Should Cancel require a stronger permission than `Permissions.Toggle`? | Recommend **no** — anyone who can pause a campaign can stop one. Reuse. |

---

## ⑩ Build log

### Session 1 — 2026-08-05 — §④ + §⑤ built, no migration

**Status: complete.** Backend §④.1–④.8 and frontend §⑤.1–⑤.5 are on disk. One user-owned seed file.
No `dotnet build` run (rule 1), no `dotnet ef` invocation and no migration/snapshot in the diff
(rule 2, §⑧-27). No new entity column anywhere.

#### Backend — files touched

| File | Change |
|---|---|
| `…/EmailSendJobs/Commands/CancelEmailSendJob.cs` | **NEW.** §④.5. Stops Hangfire *first*, counts already-`SENT` rows *before* the update, then one `ExecuteUpdateAsync` flipping `QUEUED` → `BLOCKED` with `SkipReason`/`NextRetryAt = null` (INV-10). Never touches `SENDING`/`SENT` (INV-8). Hard-refuses if `QUEUED` or `BLOCKED` does not resolve. Writes an `EmailExecutionLog` (`JOB_CANCELLED`). |
| `…/EmailSendJobs/Commands/ToggleEmailSendJob.cs` | **Rewritten.** §④.4. Pause/resume now tear down and re-arm Hangfire (INV-7) instead of flipping a flag the scheduler never reads. Pausing a `PROCESSING`/`SENDING` job is refused with a message pointing at Cancel. Result carries a `message` the mutation prefers over the generic one. |
| `…/EmailSendJobs/Queries/GetEmailSendJobDeliveryStats.cs` | **NEW.** Aggregate read behind §⑤.2/§⑤.5 — see *Deviations* below. |
| `Base.API/…/Notify/Mutations/EmailSendJobMutations.cs` | New `cancelEmailSendJob` resolver; `activateDeactivateEmailSendJob` surfaces `result.message`. |
| `Base.API/…/Notify/Queries/EmailSendJobQueries.cs` | New `emailSendJobDeliveryStats` resolver. |
| `Base.Application/Schemas/NotifySchemas/EmailSendJobSchemas.cs` | `CancelEmailSendJobResponseDto`. |
| *(§④.1–④.3, ④.6, ④.7, ④.8 pipeline files)* | Typed exceptions, `AutomaticRetry(0)` + idempotency guard + pre-insert dedupe, step-1 completion write, retry classification + sweep service + DI/Hangfire registration, `PARTIAL` final status, provider fallback. |

#### Frontend — files touched

| File | Change |
|---|---|
| `…/data-tables/shared-cell-renderers/email-job-status-badge.tsx` | **NEW.** §⑤.1 nine-status chip, solid fill + white text. Registered in the barrel and in the flow `component-column.tsx` switch as `email-job-status-badge`. |
| `…/stores/email-send-job-stores/email-send-job-store.ts` | Pale `bg-yellow-100 text-yellow-400` map replaced by the exported `getEmailSendJobStatusColor`, shared by the list chip and the detail header so a job cannot be green in one place and amber in the other. |
| `…/emailsendjob/components/JobDeliverySummary.tsx` | **NEW.** §⑤.2 + §⑤.5. Queued / Sent / Failed / Pending-retry tiles (right-aligned), top failure reasons on `PARTIAL`/`FAILED`, retry line with a 5-minute-rounded next attempt. Shaped `Skeleton`, explicit empty and error states. |
| `…/emailsendjob/components/JobRunControls.tsx` | **NEW.** §⑤.3 + §⑤.4. Cancel dialog states the already-sent count and never implies recall; offered only on `PROCESSING`/`SENDING`. Pause/resume only on `RECURRING` and `SCHEDULE`, **disabled with a tooltip** (not hidden) while running. A resume of an elapsed `SCHEDULE` shows the §④.4 message client-side, before any mutation is called. |
| `…/emailsendjob/view-page.tsx` | Both panels wired in beside `CampaignBlockedNotice`. |
| `gql-mutations/…/EmailSendJobMutation.ts`, `gql-queries/…/EmailSendJobQuery.ts`, `entities/notify-service/EmailSendJobDto.ts` | New operations and DTOs. |

#### Verification

- `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` → **exit 0**, no pipe, no output at
  all (no `TS2688`, so files were genuinely checked). §⑧-25 ✅
- §⑧-26: there is **no generated `.graphql` schema file in the repo** — the schema is served at
  runtime only. Field names were therefore verified against the resolver signatures and DTO
  properties directly (`cancelEmailSendJob(emailSendJobId: Int!)`, `emailSendJobDeliveryStats(emailSendJobId: Int!)`,
  `Get` stripped, `Input` appended). This is the strongest check available offline; **worth one
  smoke-test against `/graphql` after the backend builds.**
- §⑧-23/24 are visual and copy assertions — verifiable on screen once the seed in the next section
  is applied.

#### Deviations from the prompt — all deliberate, all recorded

1. **MasterData lives in `sett`, not `app`.** §③.1's query says `app."MasterDatas"`; the tables are
   `sett."MasterDatas"` / `sett."MasterDataTypes"`. The seed file uses `sett` and says so inline.
2. **`ProviderErrorMessage` does not exist.** §⑤.2 names it, but `EmailSendQueue` has no such
   column (it has `ErrorCode`, `ErrorMessage`, `BounceReason`, `DropReason`). The stats query
   returns one representative `ErrorMessage` per `ErrorCode` group instead. No column was added.
3. **`GetMultipleMasterDataIdsByCodesAsync` cannot be used for the cancel status lookup.** `QUEUED`
   is a `DataValue` in *both* `EMAILSENDJOBSTATUS` and `EMAILSENDSTATUS`, and that helper keys its
   dictionary by `DataValue` — the two collide. `CancelEmailSendJob` resolves each id with
   `GetMasterDataIdByCodeAsync` (type-scoped) instead. Pre-existing trap, not introduced here.
4. **One query added slightly outside §④: `emailSendJobDeliveryStats`.** §⑤.2's four numbers plus
   the pending-retry count cannot be derived from the paginated `emailSendQueues` grid query, and
   client-side counting would materialise 200k rows for a large campaign. The aggregation is pushed
   to SQL (`GroupBy` + `Take` server-side). Adds no column, no migration.
5. **A new grid cell renderer needs a DB row updated.** The job-list chip is chosen by
   `sett."GridFields"."GridComponentName"`, so shipping the renderer alone changes nothing. The seed
   file carries a discovery `SELECT` plus a guarded, idempotent `UPDATE` (block 5). **Until that
   runs, the list still renders `PARTIAL` as plain text — indistinguishable from `COMPLETED`, which
   is exactly the failure §④.7 exists to fix.**

#### User-owned actions (nothing here was executed)

1. `dotnet build` the backend.
2. Apply `sql-scripts-dyanmic/email-job-status-partial-seed.sql`, **reading block 5a's output before
   running 5b**: (1) pre-check, (2) guarded `PARTIAL` insert into `EMAILSENDJOBSTATUS`,
   (3) verification — confirm `CANCELLED` and `PAUSED` are present (Q4), (4) `EMAILSENDSTATUS`
   pre-flight — `QUEUED` **and** `BLOCKED` must both exist or Cancel refuses to run, (5) the
   `GridComponentName` discovery + update above.

#### §⑨ answers

| # | Resolution |
|---|---|
| **Q1** | Built as assumed — backoff 5 min → 30 min → 2 h, `MaxRetryAttempts = 3` (the on-disk default was already 3). Two constants; change freely. |
| **Q2** | Built at a 10-minute sweep cadence. The §⑤.5 copy rounds the next attempt to a 5-minute mark precisely so a cadence change does not turn the UI into a liar. |
| **Q3** | **Not built** — out of scope without PROMPT-22. Recommendation stands: notify on `PARTIAL`. Today a tenant only learns about a partial send by opening the job; the amber chip is the whole of the current warning. |
| **Q4** | ⚠️ **Still open — needs the DB.** The seed file's block 3 answers it. `CANCELLED`/`PAUSED` are declared in code but may never have been seeded; if either is missing, §④.4/§④.5 succeed but display the wrong status. |
| **Q5** | Built as recommended — Cancel reuses `Permissions.Toggle`. No new capability code, so no RBAC seed needed. |
