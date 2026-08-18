# Import Pipeline UX, Completion Notification, and Data Processing Flow

## 0. Read this before you touch anything

The specification this prompt implements assumes there is **no in-app notification when an import
completes**. That premise is wrong, and building on it would produce a parallel notification stack —
exactly what the spec forbids.

What actually exists today, verified in the codebase:

| Spec asks for | Already built | What is genuinely missing |
|---|---|---|
| In-app notification on import completion | `ImportNotificationService` + `INotificationDispatcher` → `INotificationWriter` → `notify.Notifications`, wired at **9 call sites** | The **popup surface** and the **once-only rule** |
| Idempotent — reprocessing the same completion creates no duplicate | Nothing | Idempotency key + partial unique index |
| Backend is source of truth for "already seen" | `Notification.PushedAt` column exists **and is written by nothing** | A mark-pushed command that uses it |
| Pipeline rail with per-stage state icons | `import-wizard-container.tsx:85-150` — `steps` array + `iconForState` | Extend it to 5 tabs; do not rebuild it |
| Server-side paging of results when complete | `GetStagingDataQuery(sessionId, page, size, validationStatusFilter, **executionStatusFilter**)` returning `ExecutionStatus` / `ExecutionStatusName` / `ExecutionError` per row | **Nothing. No new API.** |
| Live progress transport | `ImportProgressHub` at `/hubs/import-progress`, 8 events, FE store already consumes them | Nothing for the wizard page; see §2.2 for the off-page case |

So this is a **UX + once-only-delivery** task with a *small*, precisely-bounded backend change. It is
not an import-engine change. Do not redesign the import engine. Do not introduce a second
notification path.

Your first commit must be the grounding audit in §1. Do not write UI first.

---

## 1. Grounding audit (do this first, write it down)

Produce a short findings file before any code. For each item, cite `file:line`.

1. **Which toast library is actually mounted?** `package.json` declares **both** `sonner ^1.7.4` and
   `react-hot-toast ^2.5.2`. Find which one has a live provider in the app shell / layout. Use that
   one. Do **not** add a third, and do **not** use `window.alert` / `confirm` — banned app-wide.
   If both are mounted, say so and pick the one already used by feature code, not by a demo page.
2. **What `CurrentStep` values does validation actually emit?** `ValidationProgressDto.CurrentStep`
   already ships on every `ValidationProgress` broadcast. Enumerate the real values produced by the
   validation service and the `ImportCommon-fn-validate` PL/pgSQL path. The Tab-3 pipeline stages
   (§4.3) must be **the real stages**. If the real set does not cover the spec's eight stages,
   report the delta and map to what exists — do not invent stages that no code emits.
3. **What execution stages does `ImportExecutionService` actually pass through per batch?** Same
   rule for Tab 4. `ImportProgress` is emitted per batch; establish its payload shape.
4. **Confirm the notification gap chain**, quoting each file:
   - `NotificationContext.cs` — has `InitiatedByUserId`, `AssignedUserId`, `Tokens`, and **no
     source-entity fields**.
   - `NotificationDispatcher.cs:82-105` — the `StageAsync(...)` construction sets ~17 fields and
     **never sets `SourceEntityType` / `SourceEntityId`**.
   - `NotificationWriter.cs:60-130` — *does* copy `request.SourceEntityType` / `SourceEntityId` onto
     each `Notification`, and **never sets `PushedAt`**.
   - Conclusion to confirm: the two columns exist end-to-end but are always null because the context
     object cannot carry them.
5. **Confirm the hub's scope limit.** `ImportProgressHub.JoinSession` puts the caller in a
   **per-session group**. There is no per-user group. Therefore SignalR cannot deliver a completion
   popup to a user who has navigated away from the wizard. State this explicitly — it is the reason
   §2.2 exists.
6. **Confirm the existing poll transport.** `presentation/hooks/useNotification/useNotificationCount.ts`
   already runs a visibility-aware Apollo poll of `GetNotificationBadge` (three scalars,
   `latestNotificationId` watched to decide whether to refetch the list). This is the delivery
   channel to extend. Do not build a new timer.

---

## 2. Import completion notification — once-only popup

### 2.1 Backend — the minimum change, and nothing beyond it

Four changes. Justify any fifth in writing before making it.

**(a) Let the context carry the source entity.**
Add `SourceEntityType` (string?) and `SourceEntityId` (int?) to `NotificationContext`. Keep the
existing constructor working — add an overload or optional parameters so the ~N existing call sites
across the app compile untouched. Enumerate those call sites and confirm zero behaviour change for
them.

**(b) Thread them through the dispatcher.**
In `NotificationDispatcher.StageAsync(...)`, set `SourceEntityType = context.SourceEntityType` and
`SourceEntityId = context.SourceEntityId`. `NotificationWriteRequest` and `NotificationWriter`
already carry them onward — verify, do not duplicate.

**(c) Stamp the import session.**
In `ImportNotificationService.NotifyImportTerminalAsync`, pass `("ImportSession", sessionId)`. This
gives two things at once: the idempotency key, and a deep link target for `ActionUrl`.

**(d) Idempotency.**
A completion event can be re-raised: Hangfire retries, a resumed batch, the scheduled-execution path
re-entering. Today that writes a second row.

Enforce it in the database, not in C#, because concurrent Hangfire workers are the exact case a
`SELECT`-then-`INSERT` check loses. Add a **partial unique index** on `notify."Notifications"` over
`("ToUserId", "TriggerCode-or-NotificationTemplateId", "SourceEntityType", "SourceEntityId")` where
`SourceEntityType IS NOT NULL AND "IsDeleted" IS NOT TRUE`. Decide between `TriggerCode` and
`NotificationTemplateId` by checking which is actually persisted on the row, and say which you chose
and why. Then make `NotificationWriter` tolerate the unique violation as a **no-op success**, not an
error — a duplicate suppressed is the correct outcome, and `ImportNotificationService` must keep its
"never throws" contract.

> **Migration handoff.** Do **not** run `dotnet ef migrations add` and do not edit
> `ApplicationDbContextModelSnapshot.cs`. Write the index as a `migrationBuilder.Sql(...)` body in a
> plain markdown handoff section at the end of your output, plus a standalone idempotent
> `sql-scripts-dyanmic/*.sql` the user can run directly. The user creates migrations.

**(e) The once-only marker.**
`Notification.PushedAt` is a live column written by nothing. It is exactly "the popup has been shown
to this user". Add:

- a query that returns notifications for the current user where `PushedAt IS NULL` (cap it — 5 rows,
  newest first; this is a popup feed, not an inbox);
- a mutation `markNotificationPushed(notificationIds: [Int!]!)` that sets `PushedAt = now()` **only
  where it is currently null**, scoped to the calling user and tenant.

`PushedAt` is deliberately independent of `IsRead`. Dismissing a popup marks it pushed; it does not
mark it read. The bell badge must keep counting it.

### 2.2 Frontend — where the popup comes from

Two delivery paths, one rule.

- **User is on the wizard page**: the `ImportCompleted` / `ImportFailed` SignalR event already
  arrives (`import-store.ts`). Show the popup from that, then immediately call
  `markNotificationPushed`.
- **User is anywhere else in the app**: the badge poll in `useNotificationCount` is the only channel
  that reaches them. Extend that hook (or add a sibling that shares its visibility-aware timer) to
  also fetch the `PushedAt IS NULL` feed when `latestNotificationId` changes, show each as a toast,
  and mark them pushed.

**The rule: the server decides, not the client.** No `localStorage`, no `sessionStorage`, no
in-memory `Set` as the primary guard. Those all fail the spec's stated cases — refresh, navigation,
and especially multi-tab. A client-side dedupe cache is acceptable only as a *within-tick* guard to
stop the same render pass firing twice; the durable answer is always `PushedAt`.

Multi-tab is handled by construction: whichever tab calls `markNotificationPushed` first wins,
because the update is `WHERE PushedAt IS NULL`; the other tab's next poll returns nothing.

Popup content: title, body, category/priority styling consistent with `notification-item.tsx`, and
an action that deep-links to the import session detail using `ActionUrl`. Reuse
`notifications-panel/notification-item.tsx` presentation; the dismissible-banner precedent at
`presentation/components/intimation/intimation-banner.tsx` is the closest existing surface if a
banner reads better than a toast for a long-running-job completion — pick one, state why.

---

## 3. The pipeline rail

`import-wizard-container.tsx:85-150` already has the rail: a `steps` array plus `iconForState`
mapping `done → ph:check-circle-fill` (green), `active → svg-spinners:ring-resize` (blue),
`failed → ph:x-circle-fill` (red), `pending → ph:circle` (gray).

Extend that component into a reusable `<ImportPipelineRail>` used by Tab 3 and Tab 4 as well as the
top-level tab strip. Add the `skipped` state the spec requires (neutral icon, distinct from
pending — e.g. `ph:minus-circle`).

**Never rely on colour alone.** Every state carries a distinct glyph *and* a text label *and* an
`aria-label`. A red-green pipeline is unreadable to ~8% of male users; this is a hard requirement,
not a nicety.

---

## 4. Five tabs

`WIZARD_TABS` is currently three: `download-upload`, `validation`, `import`. Go to five.

| Tab | Content | Reuse |
|---|---|---|
| 1. Instructions | Static per-grid guidance: what the file must contain, required columns, date formats, master-data expectations, row limits, quota | **New**, but source the content from the field metadata already returned by `GenerateFieldsAsync` (`DisplayName`, `IsRequired`, `DataType`, `MaxLength`, `DateFormat`, `AllowedValues`) — do not hardcode a prose list that drifts from the schema |
| 2. Template | Download + upload | `import-template-download-section.tsx` (774 lines) + `import-step-upload-file.tsx` (554) — split the existing combined tab, do not rewrite |
| 3. Validation | Stage pipeline (§4.3) | `import-step-validation.tsx` (231) + `import-step-review-results.tsx` (1642) |
| 4. Import / Processing | Live processing view (§4.4) | `import-step-import-progress.tsx` (197) |
| 5. Result | Summary + downloads (§4.5) | `import-step-complete.tsx` (263) |

Tab gating: a tab is reachable only when the session state permits it. Drive gating from the
existing `ImportUIState` enum (`import-types/index.ts:35-50`) — it already has all 14 states. Do not
add a parallel tab-state machine.

### 4.3 Tab 3 — validation as a pipeline

Render the real stages found in §1.2, driven by the `CurrentStep` already carried on
`ValidationProgress`. If the real stage set is coarser than the spec's eight, show the real ones —
a rail that displays stages the backend never reports would show a permanently-pending step, which
is worse than a shorter honest rail. Report the delta rather than faking it.

Reuse the existing validation framework outright. Do not write import-specific copies of rules that
`ImportCommon-fn-validate` and the C# validation services already run.

### 4.4 Tab 4 — live processing

- Progress rides the **existing** `ImportProgress` SignalR broadcast. Do **not** add a per-row
  broadcast; a 50,000-row import would emit 50,000 messages and the hub would become the bottleneck.
- The rolling record window (previous 10 + current 10) is fetched with the **existing**
  `GetStagingDataQuery` — `pageSize: 10`, `executionStatusFilter` as needed. On each `ImportProgress`
  tick, advance the page. No new endpoint.
- This is explicitly a UX enhancement. If the fetch cadence would outpace the batch cadence, throttle
  the fetch, never the import.
- Handle unsubscribe on unmount, tab switch, and cancellation. A `LeaveSession` that never fires
  leaks a hub group per navigation.
- Polling fallback only if the hub connection fails — and then at a sane interval (≥3s), stopping on
  terminal state and on `document.visibilityState === "hidden"`, mirroring what
  `useNotificationCount` already does.

### 4.5 Tabs 4→5 when complete

**No full result load, ever.** `GetStagingDataQuery` already paginates (`PageSize` validated 1-500)
and already filters by `ExecutionStatus`, and `StagingTableService.GetStagingRowsAsync` already
returns `ExecutionStatus`, `ExecutionStatusName`, and `ExecutionError` per row. Success / failed /
skipped tabs are three filtered calls to the same query.

Tab 5 shows: final status, total/imported/failed/skipped counts, duration, completion timestamp, an
error summary grouped by reason, and the download actions already served by
`DownloadImportResult`.

---

## 5. Error handling

- Never render "Something went wrong." Every failure names *what* failed, *where* (stage, row,
  column where known), and *what the user can do next*.
- Technical exception detail is logged server-side and correlated by reference id; it is not
  rendered. Note that the existing download handler leaks an infrastructure name via `ex.Message` in
  its `NotFound` — if you touch that file, fix it; otherwise leave it and list it.
- Failure at any stage marks that rail node `failed` and leaves downstream nodes `pending`, never
  silently `done`.
- Retry affordances must appear on validation failure and on import failure — the absence of a retry
  path on failure is a known live complaint.

---

## 6. Out of scope

- Column mapping, saved mapping templates, value mapping — deferred by decision.
- CSV upload — deferred by decision.
- Any change to the import execution engine, batching, quota gates, or the PL/pgSQL execute
  functions.
- Any new notification transport (email, push, web-push).
- Creating EF migrations. Hand off SQL + a migration body; the user applies them.

---

## 7. Output

1. The §1 findings file, with `file:line` citations, **first**.
2. Implementation plan: files touched, files added, in dependency order.
3. Backend diff for §2.1 (a)-(c) and (e) — compiling C# only; do not run `dotnet build`.
4. The idempotency index as (i) a `migrationBuilder.Sql(...)` body for the user to paste, and (ii) a
   standalone idempotent script under `sql-scripts-dyanmic/`.
5. Frontend diff, tab by tab.
6. Tests for the state transitions that matter: duplicate completion event → one notification;
   two tabs racing `markNotificationPushed` → one popup; failure mid-pipeline → correct rail states.
7. A short list of anything you found that contradicts this prompt. If the codebase disagrees with
   something written here, the codebase wins — say so rather than coding around it.

Stage your work. Do not commit.
