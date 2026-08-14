# Import remediation — P3.2 (staging leak) · P3.3 (unbounded timeout) · P5 (notifications)

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`
Plan of record: `prompts/import_gap_remediation_prompt.md`
Prior phase: `prompts/import_p3_1_paging_hotfix_and_p6_prompt.md` (P3.1-A + P6 — both complete, commit `6e62e413`)

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. Make compiling entity + EF-configuration changes only and hand the migration off by name.
- `PSS_2.0_Backend` and `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server. Seed SQL: `now()`, double-quoted identifiers, `TRUE`/`FALSE`, `WHERE NOT EXISTS`, idempotent.
- Enterprise-level app. No shortcuts. Backend/service-layer validation, not frontend-only.
- **Scheduled imports are staying.** Management reviewed a manual-trigger-only proposal and chose to keep the existing recurring-job model. Do not remove, deprecate, or refactor `ImportScheduleJob`, `ImportScheduledExecutionService`, `ImportCronHelper`, or `ScheduleImport`. P5 below exists precisely *because* schedules are staying — a 2 AM run that fails currently tells nobody.

---

## P3.2 — expired staging tables leak for every non-Completed session

File: `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Support/Import/Services/DropExpiredStagingTablesJob.cs`

### The defect

`:41-47`:

```csharp
var expiredSessions = await dbContext.Set<ImportSession>()
    .Where(s => s.Status == ImportSessionStatus.Completed
             && s.StagingRetainUntil != null
             && s.StagingRetainUntil < DateTime.UtcNow
             && s.StagingDroppedAt == null
             && !string.IsNullOrEmpty(s.StagingTableName))
```

Only `Completed` (9) is swept. Every other terminal state keeps its staging table **forever**:

| Status | Value | Currently swept? |
|---|---|---|
| `Completed` | 9 | yes |
| `Failed` | 10 | **no** |
| `Cancelled` | 11 | **no** |
| `ScheduleValidationFailed` | 14 | **no** |
| `ScheduleFailed` | 15 | **no** |

Worse, `StagingRetainUntil` is stamped on the *completion* path. A session that fails or is cancelled likely never gets one set at all, so even widening the status list will not catch it — the `StagingRetainUntil != null` clause silently excludes those rows. **Verify this before writing the fix**: read every write site of `StagingRetainUntil` and report which statuses actually get it stamped. The fix depends on the answer.

A staging table is a real physical table in the `import` schema, one per session. On DEV/UAT with repeated failed test imports this accumulates without bound and nothing in the system reports it.

### The fix

1. **Widen the sweep** to all terminal statuses: `Completed`, `Failed`, `Cancelled`, `ScheduleValidationFailed`, `ScheduleFailed`. Do **not** include `Importing` (8), `Queued` (16), `Scheduled` (6), `ReValidating` (12) or `ReValidated` (13) — those are live or pending and dropping their staging table would destroy an in-flight or scheduled run.

2. **Handle the null-retention case.** For terminal sessions where `StagingRetainUntil` was never stamped, fall back to a retention window measured from a timestamp that *is* always set (`CompletedAt`, else `UpdatedDate`, else `CreatedDate` — check which of these the entity actually has and use the first that is reliably populated). Put the fallback window in the same config/const as the existing 30-day default rather than hardcoding a second number. Failed sessions arguably deserve a *longer* window than successful ones, because someone will want to debug them — use the same 30 days for now but make it a distinct named constant so it can diverge later.

3. **Better: stamp it at the source.** Whichever code path moves a session into `Failed` / `Cancelled` / `ScheduleValidationFailed` / `ScheduleFailed` should set `StagingRetainUntil` the same way the completion path does. Do both — fix the write sites *and* keep the fallback in the job, because the fallback is what cleans up the rows that already leaked.

4. **Orphan sweep.** Sessions are not the only way a staging table appears. If `import.drop_staging_table()` or the session row itself was lost, the physical table has no owner and will never be found by an `ImportSessions` query. Add a second pass that lists physical tables in the `import` schema matching the staging-table naming convention, left-joins them against `ImportSessions.StagingTableName`, and **logs** (does not drop) any table with no owning session older than the retention window. Log only — a blind `DROP` driven by a name pattern is not something to run unattended. Report the query so the user can inspect results.

5. Keep the existing per-session `try/catch` continue-on-failure behaviour. Add a summary log line with dropped/failed/skipped counts.

---

## P3.3 — `CommandTimeout = 0` lets one wedged import hold a tenant's queue slot forever

File: `Base.Support/Import/Services/ImportExecutionService.cs`

### The defect

`:246`:

```csharp
cmd.CommandTimeout = 0; // No timeout — this is a background job, let the SP run to completion
```

The comment's reasoning is wrong in a specific way. It is true that a background job should not be cut off by a *request* timeout. It does not follow that it should have *no* timeout. The consequences:

- The P9 per-tenant serialization index `UX_ImportSessions_CompanyId_Running` (partial unique on `"Status" = 8`) means **one running import per tenant**. A batch that hangs holds that slot indefinitely and every other import for that tenant queues behind it — permanently, with no error and no operator signal.
- The P9 `HeartbeatAt` lease cannot reclaim it. The row genuinely *is* held by a live connection; the reaper has no basis to steal it, and if it did, two workers would run the same session.
- A lock wait inside the SP against a long-running transaction elsewhere never surfaces. It just stops.

`:399` and `:451` already use `CommandTimeout = 30` for the lighter helper commands, so the codebase already accepts that these calls are bounded.

### The fix

1. **Give the batch call a real timeout.** `BatchSize` is 500 rows. Size the ceiling to a generous multiple of realistic worst-case batch time, not to a guess — measure or reason from the SP's work per row and state your reasoning. A value in the low tens of minutes per *batch* is the right order of magnitude. Put it in a named constant next to `BatchSize`, not inline.

2. **Make it configurable** through the same options class the rest of import uses (`ImportQueueOptions` or the nearest equivalent — check what is already bound from configuration and follow it). A single hardcoded number will be wrong for someone's data.

3. **Handle the timeout correctly — this is the part that matters.** On `NpgsqlException` / `TimeoutException` from the batch command the loop must NOT simply rethrow into a generic handler that leaves the session in `Importing` (8). It must:
   - log the session id, batch number, offset and elapsed time;
   - move the session to `Failed` (10) with a message that says a batch exceeded the timeout, naming the constant, so the operator knows what knob exists;
   - **release the tenant queue slot** — confirm by reading the code that leaving `Importing` is what frees the partial unique index, and that the next queued session is then picked up (either by the continuation or by `ImportQueueDispatcher`'s safety-net tick). State in your summary how the next session gets started after this failure path.
   - run the same lookup-cache cleanup the cancellation path does at `:237` (`CleanupLookupCacheAsync`). A timeout that skips cleanup leaks the cache exactly like an unhandled crash.

4. **Do not touch** the `CommandTimeout = 30` sites at `:399` / `:451`.

5. While in this file: `int offset = 0` at `:206` never reads `session.LastProcessedOffset`, so a re-picked session restarts its progress reporting from 0%. Since P3.1-A made row selection head-of-queue, this is now cosmetic rather than data-affecting — already-imported rows carry `ExecutionStatus = 1` and are skipped. **Leave the selection logic alone.** Only make the progress percentage at `:312-314` correct for a resumed run, seeding `totalParent` from `session.ImportedRows` if that is safe. If it is not safe, say so and change nothing.

---

## P5 — import lifecycle notifications

**The notification engine already exists. Do not build one.** Confirm the shape before writing anything:

- `Base.Application/Services/Notifications/NotificationDispatcher.cs:28`
  `Task DispatchAsync(string triggerCode, int companyId, NotificationContext ctx, CancellationToken ct)`
  — matches active `notify.NotificationTemplates` on `TriggerEvent == triggerCode`, scoped to `CompanyId == companyId || IsSystem`, resolves recipients, renders tokens.
- `NotificationContext(int? initiatedByUserId, int? assignedUserId, IReadOnlyDictionary<string,string>? tokens)`
- `NotificationRequest`, `NotificationRecipientResolver`, `NotificationWriter`, `NotificationTokenRenderer` — all present.
- Email, separately: `IEmailTemplateService.SendEmailByTemplateKeyForCompanyAsync(...)` resolves the tenant's own provider via `CompanyEmailProviders`. The global-key `SendEmailByTemplateKeyAsync` is **not** correct for tenant-facing import mail.
- `UserNotificationPreference` supports muting by `TriggerCode` or by `Category` — respect it; the dispatcher may already do this, verify rather than assume.

Read `Base.Application/Business/NotifyBusiness/NotificationTriggers/NotificationTriggerHandler.cs` for the canonical call pattern and follow it. Do not invent a second dispatch path.

### Triggers to add

Follow the existing trigger-code naming convention exactly — inspect existing `TriggerEvent` values in the templates table/seed (the doc comment cites `"donation.created"`, `"lead.assigned"`) and match the style.

| Event | When | Why it matters |
|---|---|---|
| `import.completed` | session → `Completed` (9) | the 2 AM run finished; row counts are the payload |
| `import.failed` | session → `Failed` (10) | **the critical one** — today a failed nightly run is silent |
| `import.schedule_validation_failed` | → `ScheduleValidationFailed` (14) | data drifted between validation and the scheduled run; the user must re-review |
| `import.schedule_failed` | → `ScheduleFailed` (15) | exhausted retries |
| `import.completed_with_errors` | `Completed` but `FailedRows > 0` | rows were rejected; someone must look at the error grid |

Decide deliberately whether `import.completed_with_errors` is a distinct trigger or `import.completed` with a token — and justify the choice. A separate trigger lets an admin mute clean-run noise while still being told about rejections; that is the better default, but make the call explicitly rather than by accident.

`import.cancelled` (11) is a **user-initiated** action — the person who cancelled already knows. Do not notify unless there is a case for telling someone else; if you think there is, raise it, do not just build it.

### Recipients

Not "all admins". In order of preference:

1. `ImportSession.CreatedBy` / the user who uploaded or scheduled the session — this is the person who cares.
2. Fall back to the grid's owning-module admins only when the initiating user is gone or inactive.

Pass the initiating user through `NotificationContext.InitiatedByUserId`. Check whether the dispatcher's default recipient resolution already handles "notify the initiator" via `NotificationTemplate.RecipientType` — if it does, configure the template rather than writing bespoke recipient code.

### Tokens

At minimum: session id, grid/entity display name, file name, total rows, imported rows, failed rows, skipped rows, started-at, finished-at, duration, and a deep link to the session review screen. The failure triggers additionally need the failure reason. Deep links must be tenant-correct — check how existing notification `ActionUrl` values are built and reuse that, do not hardcode a host.

### Where to dispatch from

**Not** from inside the batch loop and **not** from the SP. Dispatch from the single place where the session's terminal status is written, so every path — interactive run, scheduled run, queue-dispatched run, and the new P3.3 timeout path — emits exactly one notification. Find that place; if there is more than one such site, that itself is worth reporting, and the notification should go into a small helper both call rather than being duplicated.

Dispatch must be **non-fatal**: a notification failure must never fail or roll back a successful import. Wrap it, log on failure, continue.

### Seed

Produce **`sql-scripts-dyanmic/import-notification-templates-seed.sql`** — idempotent (`WHERE NOT EXISTS`), PostgreSQL syntax, creating a system template (`IsSystem = TRUE`, `CompanyId = NULL`) per trigger so every tenant gets a working default without per-tenant setup. Mirror the column list and defaults of an existing template seed exactly; do not guess at `Category`, `Priority`, `RecipientType`, `Audience` or `IconCode` values — they are MasterData FKs. Report the file path; the user runs it.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. **P3.2** — which statuses now get swept, what you found about where `StagingRetainUntil` is actually stamped, and the orphan-table detection query for the user to run.
2. **P3.3** — the timeout value chosen and the reasoning behind it, the config key it binds to, and a walkthrough of what happens to the tenant's queue slot when a batch times out (how the next queued session gets picked up).
3. **P5** — the trigger codes added, your decision on `import.completed_with_errors`, the single dispatch site you chose and why, and the seed file path.
4. Any migration the user needs to create, by name.
5. Anything you could not complete and why.
