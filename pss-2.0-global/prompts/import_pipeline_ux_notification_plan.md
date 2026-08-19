# Import Pipeline UX + Once-Only Completion Popup — Implementation Plan & Migration Handoff

Companion to `import_pipeline_ux_notification_findings.md` (the §1 grounding audit). Read that
first: it establishes which toaster is mounted, what `CurrentStep` actually contains, and the five
places where the codebase contradicts the spec (C1–C5).

---

## 1. Dependency order

### Phase A — backend, once-only delivery (§2.1)

| # | File | Change |
|---|------|--------|
| A1 | `Base.Application/Services/Notifications/NotificationContext.cs` | Add optional `sourceEntityType` / `sourceEntityId` ctor params + properties. Both-or-neither normalisation. Existing 2 call sites keep compiling. |
| A2 | `.../Notifications/NotificationWriter.cs` | New `ApplySourceEntityDedupeAsync` — drops recipients already holding a live notification for the same `(template, source entity)`. Runs right after mute filtering, before the job header is built. |
| A3 | `.../Notifications/NotificationDispatcher.cs` | Pass `ctx.SourceEntityType` / `ctx.SourceEntityId` into `NotificationWriteRequest`; wrap the terminal `SaveChangesAsync` in a `23505`-tolerant catch. |
| A4 | `.../Notifications/ImportNotificationService.cs` | Pass `("ImportSession", sessionId)` on the dispatch. |
| A5 | `Base.Application/Schemas/NotifySchemas/NotificationSchemas.cs` | New `PendingPushNotificationDto`. |
| A6 | `.../NotifyBusiness/Notifications/Queries/GetPendingPushNotifications.cs` | **New.** `PushedAt IS NULL`, user+tenant scoped, newest first, cap 5. |
| A7 | `.../NotifyBusiness/Notifications/Commands/MarkNotificationsPushed.cs` | **New.** Stamps `PushedAt = utcnow` **only where null**; returns the ids actually claimed. |
| A8 | `Base.API/EndPoints/Notify/Queries/NotificationQueries.cs` | Expose `pendingPushNotifications`. |
| A9 | `Base.API/EndPoints/Notify/Mutations/NotificationMutations.cs` | Expose `markNotificationsPushed(notificationIds: [Int!]!)`. |
| A10 | `sql-scripts-dyanmic/notification-source-entity-unique-index.sql` | **New.** Partial unique index + supporting pending-push index, idempotent, with a duplicate pre-flight. |

**Status: A1–A10 done.**

### Phase B — frontend, once-only popup (§2.2)

| # | File | Change |
|---|------|--------|
| B1 | `src/infrastructure/gql-queries/notify-queries/NotificationsQuery.ts` + `src/infrastructure/gql-mutations/notify-mutations/NotificationMutation.ts` | `PENDING_PUSH_NOTIFICATIONS_QUERY`, `MARK_NOTIFICATIONS_PUSHED_MUTATION`. |
| B2 | `src/presentation/hooks/useNotification/useNotificationPushPopup.ts` | **New.** Claim-then-show: fetch pending → `markNotificationsPushed` → pop **only the ids the server returned**. Optional `suppressSource` so a surface already rendering the outcome inline does not double-report it. |
| B3 | `useNotificationCount.ts` consumer (bell) | Call B2 on each visible tick. No new timer, no new transport. |
| B4 | `import-wizard-container.tsx` | On `ImportCompleted` / `ImportFailed`, pop inline immediately **and** suppress the generic popup for that session id. |

**Status: B1–B4 done.**

### Phase C — pipeline rail (§3)

| # | File | Change |
|---|------|--------|
| C1 | `.../import-wizard/import-pipeline-rail.tsx` | **New.** Generalises `ScheduledStatusJourney` (`import-wizard-container.tsx:57-141`). States: `done` / `active` / `failed` / `pending` / `skipped`. Every state carries glyph **and** text label **and** `aria-label` — never colour alone. |
| C2 | `import-wizard-container.tsx` | Replace the inline journey with `<ImportPipelineRail>`. |

**Status: C1–C2 done.** The state vocabulary and `deriveRailStates` were split into a pure
`import-pipeline-rail-state.ts` (no React, no icons) so the "a failure stops the rail" rule is
directly testable without a browser; the component re-exports them, so no caller changed.

### Phase D — five tabs (§4)

Gating drives off the existing `ImportUIState`. No parallel state machine. Preserves every
routing in `getTabFromUIState` (see finding **C4**), which discriminates on `stagingAvailable`
and `validatedAt` — a naive 0/1/2 → 1..5 remap loses those.

| Old tab | New tabs |
|---------|----------|
| — | 1 Instructions (from `GenerateFieldsAsync` metadata, not prose) |
| 0 `download-upload` | 2 Template & Upload |
| 1 `validation` | 3 Validation |
| 2 `import` | 4 Import Processing (rail + live counters + rolling 10-row window) |
| 2 `import` (terminal) | 5 Result (counts, duration, errors grouped by reason, existing download actions) |

Tab 4 rolling window reuses `GetStagingDataQuery` at `pageSize: 10`, paging to the import head
and reading the row-level `isImported` flag client-side — there is **no** `executionStatusFilter`
on that query (finding **C5**). No new endpoint, no per-row broadcast, throttled fetch (3s floor,
paused while the tab is hidden), `LeaveSession` already handled on unmount by
`use-import-signalr.ts:525`. Tab 5 never loads the full result set — its error grouping comes from
`stagingData.errorTypeSummary`, which the store already holds.

**Status: Phase D done.** New files: `import-step-instructions.tsx` (tab 1, entirely metadata-driven
from `GenerateFieldsAsync` — no hardcoded prose), `import-live-record-window.tsx` (tab 4 rolling
window). `import-wizard-container.tsx` restructured to five tabs preserving every discriminator in
`getTabFromUIState`.

### Phase E — error surfaces (§5)
No "Something went wrong". Name what failed, where, and what to do next; keep exception text
server-side behind a correlation id. A failed rail node leaves downstream nodes `pending`, never
`done`. Retry affordances on both validation failure and import failure.

**Status: Phase E done.** `import-step-complete.tsx` (tab 5) was the main offender — it declared
"Import Completed Successfully" and drew four hardcoded green ticks regardless of the session's
actual status, so a failed run reported itself as a success. It now renders one of three outcomes
(failed / finished-with-rows-left-out / succeeded), a "What happened" card carrying
`session.errorMessage` plus what-next copy, the error groups, and the shared rail derived from the
real status.

### Phase F — tests (§7 item 6)

`PSS_2.0_Frontend/tests/e2e/screens/import-pipeline.spec.ts`. Playwright is the only runner in the
repo (no jest, no vitest, no `@testing-library`) and there is **no backend test project at all**
(`find PSS_2.0_Backend -iname "*Test*.csproj"` returns nothing), so:

| Case | How |
|------|-----|
| mid-pipeline failure → correct rail states | Pure assertions on `deriveRailStates`. Playwright specs run in Node, so this needs no browser. Six cases, including "an `active` stage downstream of a failure is pulled back to `pending`" and "`skipped` survives". |
| two tabs racing the push mutation → one popup | API level. Reads the NextAuth bearer the app itself uses, fires two `markNotificationsPushed` calls for the same ids without awaiting, and asserts the union is complete and the intersection empty — plus a third call claiming nothing. Skips loudly (never vacuously passes) when the BE is down or the user has no un-pushed notification. |
| duplicate completion → one notification | **Not automated**, and said so in the spec file rather than faked. Driving it needs two terminal dispatches for one session against a real database, and there is no test host to add it to. Delivered as a SQL verification against the partial unique index. |

No new test runner was introduced — that would have exceeded the prompt's scope.

---

## 2. Migration handoff — `migrationBuilder.Sql(...)`

> The user creates migrations. Nothing below was run; `ApplicationDbContextModelSnapshot.cs` is
> untouched and no `dotnet ef migrations add` was executed.

There is **no model change** — `Notification.SourceEntityType`, `SourceEntityId` and `PushedAt`
are already mapped columns. This migration adds indexes only, so it can be created empty
(`dotnet ef migrations add Add_Notification_SourceEntity_Idempotency_Index`) and the bodies below
pasted in.

### `Up`

```csharp
// Import once-only notification — source-entity idempotency backstop.
// Partial: rows without a source address are outside the index entirely, so nothing that
// existed before this migration is constrained by it.
// COALESCE(NotificationTemplateId, -1): PostgreSQL treats NULLs as DISTINCT in a unique index,
// so a null template id would let unlimited duplicates through.
// IsDeleted IS NOT TRUE (not = false): the column is nullable, and a soft-deleted notification
// must not block a fresh one.
migrationBuilder.Sql(@"
    CREATE UNIQUE INDEX IF NOT EXISTS ""UX_Notifications_Recipient_Template_SourceEntity""
        ON notify.""Notifications"" (
            ""ToUserId"",
            (COALESCE(""NotificationTemplateId"", -1)),
            ""SourceEntityType"",
            ""SourceEntityId""
        )
        WHERE ""SourceEntityType"" IS NOT NULL
          AND ""IsDeleted"" IS NOT TRUE;
");

// Supporting index for the once-only popup query, which rides the per-minute badge poll.
migrationBuilder.Sql(@"
    CREATE INDEX IF NOT EXISTS ""IX_Notifications_PendingPush""
        ON notify.""Notifications"" (""ToUserId"", ""NotificationId"" DESC)
        WHERE ""PushedAt"" IS NULL
          AND ""IsDeleted"" IS NOT TRUE;
");
```

### `Down`

```csharp
migrationBuilder.Sql(@"DROP INDEX IF EXISTS notify.""IX_Notifications_PendingPush"";");
migrationBuilder.Sql(@"DROP INDEX IF EXISTS notify.""UX_Notifications_Recipient_Template_SourceEntity"";");
```

### Before applying on an existing database

`CREATE UNIQUE INDEX` fails if duplicates already exist — and they will, on any environment where
an import has been retried. Run `sql-scripts-dyanmic/notification-source-entity-unique-index.sql`
first: its `DO $$` block reports duplicate groups and soft-deletes all but the earliest row in each,
then creates both indexes. That script is idempotent and is the recommended path; the migration
bodies above are the same DDL for environments applied purely through EF.
