# Grounding Audit — Import Pipeline UX, Completion Notification, Data Processing Flow

Answers §1 of `prompts/import_pipeline_ux_notification_prompt.md`. Every claim carries a `file:line`.
Paths are relative to `pss-2.0-global/`. Backend root is `PSS_2.0_Backend/PeopleServe/Services/Base`,
frontend root is `PSS_2.0_Frontend/src`.

Written **before any code**, as the prompt requires.

---

## §1.1 — Which toast library is actually mounted

**Both are mounted.** `presentation/provider/providers.tsx:11-13` renders three toasters side by side:

| Line | Component | Library |
|---|---|---|
| `providers.tsx:11` | `<ReactToaster />` | local shadcn `atoms/Toaster` (drives `atoms/Use-Toast`) |
| `providers.tsx:12` | `<Toaster />` | `react-hot-toast` (imported at `providers.tsx:4`) |
| `providers.tsx:13` | `<SonnToaster position="top-center" />` | `sonner` (`atoms/Sonner/index.tsx:2`) |

**Decision: use `sonner`.** Reasons, in order of weight:

1. It is the only one already used by the import wizard itself — `import-wizard/import-wizard-container.tsx:31`
   (`import { toast } from "sonner"`), used at e.g. `:639`, `:665`, `:684` for cancel/warn/info toasts.
2. It is the app-wide default by usage: `sonner` is imported across ~100 files under `presentation/`
   and `app/[lang]/`; `react-hot-toast` survives in exactly 6 files, all of them data-table
   export/retrieval options (e.g. `data-tables/advanced/data-table-general-options/data-table-data-retrieval-option.tsx:21`).
3. `SonnToaster` is configured with `richColors` and themed class overrides
   (`atoms/Sonner/index.tsx:10-20`), so success/error/warning intents render correctly with no extra work.
4. It is also the toaster mounted in the member shell (`app/[lang]/(member)/layout.tsx:31`), so a popup
   raised from the notification poll works in both shells.

`sonner`'s `toast.custom()` is what the once-only popup will use, so the popup can reuse the
notification-item presentation rather than being limited to title/description.

---

## §1.2 — The real `CurrentStep` values

`CurrentStep` is **free text, an English sentence** — never an enum, never a code. It is typed
`string?` on both progress DTOs (`Base.Application/Hubs/ImportProgressHub.cs`, `ValidationProgressDto`
and `ImportProgressSignalRDto`) and mirrored on the FE as `currentStep?: string`
(`presentation/hooks/use-import-signalr.ts:47`, `:67`).

It arrives from **two interleaved producers**:

**(a) PL/pgSQL `RAISE NOTICE` with a `PROGRESS:` payload**, parsed by
`Base.Support/Import/Common/ImportStoredProcedureHelper.cs:85-135`
(`CreateProgressNoticeHandler` → `ProgressNotice { Percent, Step, Processed, Total }`).

Common validation — `sql-scripts-dyanmic/ImportCommon-fn-validate.sql`, 14 stages, percent → step:

| % | Step |
|---|---|
| 2 | Rows reset, starting validation... |
| 10 | Lookup cache built |
| 12 | Validating required fields... |
| 16 | Validating required child fields... |
| 20 | Validating conditional fields... |
| 28 | Validating data types... |
| 34 | Validating field lengths... |
| 38 | Validating patterns... |
| 44 | Validating master data lookups... |
| 52 | Validating foreign key lookups... |
| 56 | Validating custom field options... |
| 60 | Validating dependencies... |
| 74 | Validating business rules... |
| 80 | Marking valid rows... |

Contact-specific validation adds 4 more — `sql-scripts-dyanmic/ContactImport-fn-validate.sql`:
65 "Checking intra-file duplicate contacts...", 67 "Checking duplicate contacts vs database...",
70 "Checking duplicate values (email, phone, ...)...", 75 "Checking combination duplicates...".

**(b) C# per-batch strings**, `Base.Support/Import/Services/ImportValidationService.cs` (~line 200):

    hasMore ? $"Validated {n} of {session.TotalRows} rows..." : "Validation complete"

and `Base.Support/Import/Services/ImportExecutionService.cs` (~line 300):

    $"Imported {importedSoFar} of {session.ValidRows} {entityName} ({totalChild} child records)..."
    /  "Import complete"

**Consequence for §3:** a rail cannot key off `CurrentStep` string equality — the sentences carry
interpolated counts and differ per grid. The rail must key off `ImportUIState` + session status
(the coarse pipeline nodes) and render `CurrentStep` as the *detail line* under the active node.

---

## §1.3 — The real execution stages per batch

Execution stages are **per-grid**, not global. There is no common execute function.

`sql-scripts-dyanmic/ContactImport-fn-execute.sql` — 9 stages: 2 "Initializing import...",
5 "Building lookup cache...", 8 "Inserting parent contact records...", 50 "Parent insert complete: N contacts",
62 "Email addresses inserted (N children so far)", 75 "Phone numbers inserted (N children so far)",
85 "Addresses inserted (N children so far)", 94 "All children inserted (N total)", 100 "Import complete".

`sql-scripts-dyanmic/BulkDonationImport-fn-execute.sql` — 3 stages: 2 "Initializing import...",
8 "Inserting donation records...", 100 "Import complete".

**Consequence for §4.4:** Tab 4 must not hardcode a contact-shaped stage list. The honest design is a
fixed *coarse* rail — Queued → Validating → Importing → Complete — with the grid's own `CurrentStep`
shown as free text beneath the active node.

---

## §1.4 — The notification gap chain (confirmed, with one correction)

| Prompt claim | Verdict | Evidence |
|---|---|---|
| `NotificationContext` has no source-entity fields | **Confirmed** | `Base.Application/Services/Notifications/NotificationContext.cs:1-21` — only `InitiatedByUserId`, `AssignedUserId`, `Tokens` |
| `NotificationDispatcher` never sets them | **Confirmed** | `NotificationDispatcher.cs:83-106` builds `NotificationWriteRequest` with 18 properties; `SourceEntityType`/`SourceEntityId` are not among them |
| `NotificationWriter` copies them and never sets `PushedAt` | **Confirmed** | `NotificationWriter.cs:116-117` copies both; no assignment to `PushedAt` anywhere in the file |
| `NotificationWriteRequest` already carries them | **Confirmed** | `NotificationWriteRequest.cs:63-66` |
| `PushedAt` is a live column written by nothing | **Confirmed** | `Base.Domain/Models/NotifyModels/Notification.cs:52` is the only non-migration reference in the entire backend; column shipped in migration `20260710031734_Add_NotificationJob` |
| Import notifications are already dispatched | **Confirmed** | `ImportNotificationService.cs:78` dispatches; 9 call sites of `NotifyImportTerminalAsync`: `ImportSessionHelper.cs:147`, `ImportQueueDispatcher.cs:324,453,539,569`, `ImportScheduledExecutionService.cs:298,355,421,520` |

**Correction to the prompt:** the prompt says "~N existing call sites" of `new NotificationContext(`.
There are exactly **two**: `NotificationTriggerHandler.cs:16` and `ImportNotificationService.cs:78`.
Adding two optional constructor parameters is therefore near-free.

So both columns exist end-to-end and are always NULL — purely because the context type cannot carry
the values across the dispatcher boundary. Prompt §2.1(a)–(c) is exactly the missing link.

Trigger codes seeded by `sql-scripts-dyanmic/import-notification-templates-seed.sql`:
`import.completed`, `import.completed_with_errors`, `import.failed`,
`import.schedule_validation_failed`, `import.schedule_failed`. `Cancelled` (status 11) deliberately
produces no trigger (status switch in `ImportNotificationService.cs`). The service never throws
(single try/catch wrapping the whole body).

---

## §1.5 — The hub is per-session-group only

**Confirmed.** `Base.Application/Hubs/ImportProgressHub.cs`:

- `[Authorize]` on the hub; `CallerCompanyId` reads the `CurrentCompanyId` claim and returns 0 to fail closed.
- `JoinSession` verifies the session exists in the caller's company, then
  `Groups.AddToGroupAsync(Context.ConnectionId, $"import-{sessionId}")`.
- `LeaveSession` removes the connection from that group.
- **There is no per-user group, and no `OnConnectedAsync` group join of any kind.**

`Base.Infrastructure/Services/Import/ImportProgressNotifier.cs:1-133` sends all 8 events
(`ValidationStarted`, `ValidationProgress`, `ValidationCompleted`, `ValidationFailed`, `ImportStarted`,
`ImportProgress`, `ImportCompleted`, `ImportFailed`) to `Group($"import-{sessionId}")` and nowhere else.

FE side matches: `presentation/hooks/use-import-signalr.ts:100-118` maps exactly those events plus
`JoinedSession` / `JoinSessionDenied`, and the connection is created per `sessionId`
(`use-import-signalr.ts:145`), mounted by the wizard at `import-wizard-container.tsx:184`.

**Consequence:** SignalR can only ever notify a user who is *sitting on the wizard for that session*.
A user who navigated away, or whose import was queued/scheduled and ran hours later, is unreachable
by the hub. That is precisely why the second delivery path (§2.2, the badge poll) is required — and
why it must not be replaced by "just add a per-user group", which would be a new transport (§6).

---

## §1.6 — `useNotificationCount` is the delivery channel to extend

**Confirmed**, `presentation/hooks/useNotification/useNotificationCount.ts:1-92`:

- Apollo `useQuery(NOTIFICATION_BADGE_QUERY)`, `fetchPolicy: "cache-and-network"` (`:46-51`).
- `pollInterval` is `isVisible && intervalSeconds > 0 ? intervalSeconds * 1000 : 0` (`:50`) —
  i.e. polling is **already visibility-aware**; default interval `NOTIFY_POLL_INTERVAL_SECONDS` (60s).
- `visibilitychange` listener (`:53-74`) stops polling when hidden and, on return, **refetches first
  then restarts the timer** (`:65-66`) so a restored tab is not stale.
- Initial `isVisible` is seeded from `document.visibilityState` (`:36-38`) so a background-restored
  tab fires no pointless request.
- Payload is three scalars — `unreadCount`, `latestNotificationId`, `latestCreatedDate` (`:85-87`),
  read off `data?.result?.data` (`:80`).

This is a correct, cheap, already-tuned timer. **No new timer will be created.** The popup rides this
hook's existing tick: when the poll runs, also ask the server for un-pushed rows.

---

## Contradictions with the prompt (§7, item 7) — the codebase wins

### C1. §2.1(d) "make `NotificationWriter` tolerate the unique violation as a no-op success" is not implementable where the prompt puts it

`NotificationWriter.StageAsync` **only stages** — it calls `dbContext.NotificationJobs.Add(job)` and
`dbContext.Notifications.Add(...)` per recipient and returns `recipients.Count`
(`NotificationWriter.cs`, through `:117`). It **never calls `SaveChangesAsync`**. The save happens in
`NotificationDispatcher.cs:116` (and `:197` for `SendTestAsync`), after the template loop.

Two consequences:

1. A `23505` unique violation can only surface at the dispatcher's `SaveChangesAsync`, so the
   catch-and-no-op has to live there, not in the writer.
2. Worse: the `NotificationJob` header and **all** per-recipient `Notification` rows are inserted in
   one `SaveChanges` transaction. One duplicate row therefore fails the *entire* batch — including
   legitimate rows for other recipients and other templates in the same dispatch. Swallowing the
   exception at the dispatcher would silently drop good notifications.

**What I will do instead** (stated here rather than coded around): a **pre-check before staging** —
the dispatcher queries `notify."Notifications"` for an existing live row matching
(ToUserId, template, SourceEntityType, SourceEntityId) and skips just those recipients — with the
partial unique index kept as the **race backstop**, and the `23505` catch at the dispatcher's
`SaveChangesAsync` degraded to "log and treat as delivered" rather than rethrow. The index still does
the real work under concurrency; the pre-check keeps the common case from poisoning a whole batch.

### C2. `new NotificationContext(` has 2 call sites, not "~N"

`NotificationTriggerHandler.cs:16`, `ImportNotificationService.cs:78`. Change (a) could add required
parameters, but I will still make them optional-with-default so both call sites and any future caller
stay source-compatible, per the prompt's stated intent.

### C3. The percent stream regresses backwards on every batch — the rail must not trust it monotonically

`CreateProgressNoticeHandler` dedupes only on `progress.Percent == lastPercent`, and that
`lastPercent` is a closure variable created **per handler instance**
(`ImportStoredProcedureHelper.cs:85-135`). The validation loop re-invokes `import.validate_common`
once per offset batch (batch loop in `ImportValidationService.cs`), and each invocation re-emits the
whole 2 → 80 notice ladder from the top.

So on a multi-batch session the raw notice percent goes 2…80, then **back to 2**, repeatedly. The C#
per-batch progress (`5 + offset * 85 / TotalRows`, capped at 90) is the monotonic one. Any rail or bar
that consumes `ProgressPercent` must clamp to a running maximum within a phase, or it will visibly
march backwards. This is a real defect the new UI would otherwise inherit and make more visible.

### C4. The wizard's tab mapping is richer than "3 tabs"

`import-wizard-container.tsx:538-593` (`getTabFromUIState`) already routes failures by discriminators
the prompt does not mention: `stagingAvailable === false` → tab 0 (parse failure / retention drop),
`validatedAt` stamped → tab 2 (execution failure) vs unset → tab 1 (validation failure), and the two
scheduled-failure statuses → tab 2. The 5-tab restructure must preserve every one of these routings,
not merely re-map 0/1/2 → 1..5. `ScheduledStatusJourney` (`:57-141`) is the rail being generalised;
`WIZARD_TABS` is at `:144-148`; the tab strip at `:1321-1370`; body switch at `:1224-1225`;
`goToTab` currently allows **backwards navigation only** (`:650-654`).

### C5. §4.4's `executionStatusFilter` does not exist

The prompt says the rolling record window should reuse `GetStagingDataQuery` "with `pageSize: 10`
and an `executionStatusFilter`". There is no such argument. `importApiService.getStagingData`
sends `sessionId`, `pageIndex`, `pageSize`, `searchTerm` and `validationStatusFilter` — and
`validationStatusFilter` is a `ValidationStatus` (valid / invalid / warning), which is about the
*validation* pass, not about whether a row has been written to the live table yet.

The row-level "already imported" signal that actually exists is the boolean `isImported` on
`StagingRow`. So the window pages to the import head (`pageIndex` derived from `processedRows`) at
`pageSize: 10` and reads `isImported` per row on the client. §6 forbids adding an endpoint or
touching the import engine, so filtering server-side was not an option — and it is not needed:
a 10-row page is the whole point.

---

---

## Component inventory confirmed for §4 reuse

| File | Lines | Tab |
|---|---|---|
| `import-wizard/import-template-download-section.tsx` | 774 | 1 Instructions / 2 Template |
| `import-wizard/import-step-upload-file.tsx` | 554 | 2 Template |
| `import-wizard/import-step-validation.tsx` | 231 | 3 Validation |
| `import-wizard/import-step-review-results.tsx` | 1642 | 3 Validation |
| `import-wizard/import-step-import-progress.tsx` | 197 | 4 Import Processing |
| `import-wizard/import-step-complete.tsx` | 263 | 5 Result |
| `import-wizard/import-wizard-container.tsx` | 1439 | shell |
| `application/stores/import-stores/import-store.ts` | 925 | state |

`ImportUIState` (14 states) is at `domain/types/import-types/index.ts:35-50`; `ImportSessionStatus`
(17 values, `Queued = 16` appended) at `:12-30`. Tab gating drives off these — no parallel state machine.

Rolling-window source confirmed present and reusable with no new endpoint:
`Base.Application/Business/ImportBusiness/Sessions/Queries/GetStagingData.cs:15-20` —
`GetStagingDataQuery(ImportSessionId, PageNumber = 1, PageSize = 50, ValidationStatusFilter, ExecutionStatusFilter)`,
`PageSize` validated `InclusiveBetween(1, 500)` (`:39-41`), so `pageSize: 10` is legal.
Row DTO exposes `ExecutionStatusName` and `ExecutionError`
(`Base.Application/Schemas/ImportSchemas/ImportSessionSchemas.cs:560,562`).
