# Import session grid — progress columns + detail view

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`
Prior work: import gap remediation P0–P10, all complete. Do not re-open those phases.

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`.
- `PSS_2.0_Backend` and `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server. Seed SQL idempotent.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.
- **No `window.confirm` / `window.alert` / `window.prompt`.** Dialog components only.
- Solid icon backgrounds with white foreground for status/mode badges (existing app convention).

---

## Scope

Two asks, both on the import **session list** — `PSS_2.0_Frontend/src/presentation/components/custom-components/import-wizard/import-session-list.tsx`:

1. Keep the current columns, add genuinely useful ones — progress above all.
2. A **View** action to inspect any session and see what happened, at any status.

Today the grid is **File · Status · Rows · Created · Actions**. Actions holds a context-sensitive Continue button and a Cancel. There is no progress indication and no way to inspect a finished or failed import.

---

## Read this first — the data already exists

`Base.Domain/Models/ImportModels/ImportSession.cs` already carries everything below. **This is a surfacing task. Do not add columns to `ImportSession` and do not create a migration unless you can prove a genuine gap** — and if you find one, report it rather than adding it.

| Field | What it gives you |
|---|---|
| `LastProcessedOffset` | the real execute cursor — **this is the progress numerator**, written by the resumable batch loop (P3.1) |
| `ValidRows` | the denominator. Not `TotalRows` — invalid rows are never written |
| `ImportedRows`, `ExecutionFailedRows` | committed vs failed at the row level |
| `HeartbeatAt` | last sign of life from the worker — the only way to tell *running* from *stalled* |
| `StartedAt`, `ValidatedAt`, `CompletedAt` | per-stage durations |
| `QueuedAt`, `QueuePriority`, `QueueSequence` | position in the P9 per-tenant queue |
| `ScheduledRunTime` | when a scheduled session will actually run |
| `ExecutionAttempts` | retry count — a session on attempt 3 is a different story from one on attempt 1 |
| `UserId` / `User` | who uploaded it |
| `ErrorMessage`, `ReValidationMessage` | why it failed |
| `ParseWarningsJson`, `ChildCountsJson` | parse-time warnings, child-entity counts |
| `StagingRetainUntil`, `StagingDroppedAt` | **whether per-row detail still exists — read the constraint below** |

---

## The constraint that shapes the design: staging is not permanent

`DropExpiredStagingTablesJob` (P3.2) drops `staging_{id}` once `StagingRetainUntil` passes, stamping `StagingDroppedAt`. **Per-row detail is therefore temporary; the session summary is permanent.**

A View screen that assumes staging rows exist will work in testing — where every session is minutes old — and break in production on any session older than the retention window. This is the single most likely way to get this feature wrong.

So:

- The detail view must have **two modes**, chosen off `StagingDroppedAt`: full (staging alive — per-row detail available) and **summary-only** (staging dropped — counts, timings, error message, who, when).
- In summary-only mode, say so plainly: the rows are no longer retained, with the date they were dropped. Do **not** render an empty grid, a spinner, or "no rows found" — all three read as "the import did nothing," which is a false and alarming statement about a successful import.
- Never resurrect a dropped staging table, and do not extend the retention window to make the view easier. Retention is a deliberate storage decision.

---

## Progress — the hard part

**Progress means different things per stage, and a single bar will be wrong.**

- `Parsing` (2) — no reliable row denominator until the parse finishes. Indeterminate. Do **not** fake a percentage.
- `Validating` (4) / `ReValidating` (12) — the SP batch loop. State what it exposes; if there is no cursor, indeterminate is the honest answer.
- `Importing` (8) — `LastProcessedOffset / ValidRows` is real, monotonic and resumable. **This is the only stage with a true percentage.**
- `Queued` (16) / `Scheduled` (6) — not running at all. Show queue position or scheduled run time, never a progress bar. A bar on a queued session reads as "working" when nothing is happening.
- Terminal (`Completed` 9, `Failed` 10, `Cancelled` 11) — final counts, not progress.

**Stalled detection.** A session `Importing` with a `HeartbeatAt` older than a sensible threshold is stuck, not working. Surface that distinctly — a spinner that spins forever is the worst of the available options. Derive the threshold from the existing heartbeat/liveness constant if one exists; do not invent a second one, and do not hardcode a bare number.

Do not add polling to the grid that duplicates the wizard's. `import-wizard-container.tsx:182-210` already has a poller with a slow tier; reuse the pattern and its interval, and only poll while at least one visible session is non-terminal. A list polling every session forever is a needless load on every tenant.

---

## Columns

Keep File, Status, Rows, Created, Actions. Add:

- **Progress** — per the rules above.
- **Submitted by** — `User`. On a shared grid, "who uploaded this" is the first question asked about a bad import.
- **Duration / finished** — elapsed for running sessions, total for terminal ones, derived from the timestamps above.
- **Trigger** — manual vs scheduled vs queue-dispatched. Already distinguishable from `ImportScheduleJobId` / `QueuedAt` / `ScheduledAt`; do not add a field for it if it is derivable, but say how you derived it.

Judge the rest yourself, and **justify anything you add**. A grid with fifteen columns is not more useful than one with eight. Guidance: put failure-diagnostic detail (attempts, queue sequence, blob path, staging table name) in the detail view, not the grid.

Respect the existing responsive behaviour — the current cells carry `px-3 sm:px-4` and the file cell truncates at `max-w-[200px]`. On narrow viewports, columns must collapse gracefully rather than forcing horizontal page scroll.

---

## View action

- Add **View** alongside the existing Continue/Cancel in the Actions cell. It must be available at **every** status, including `Failed` and `Cancelled` — those are the ones users most need to inspect. Continue stays status-gated as it is now; do not fold View into it.
- Decide and justify: dialog vs dedicated route. A dedicated route is linkable — "look at import 4821" is a message people send each other — but the grid lives inside a wizard shell, so check what routing already exists before committing. State your reasoning either way.
- Contents: the full session summary (all timestamps, counts, trigger, user, attempts, error message, parse warnings, child counts), plus per-row detail when staging is alive.
- **Reuse the review grid's row rendering** where staging is alive rather than writing a second one. `import-step-review-results.tsx` already renders staging rows with sanitization, paging, filtering and the P8.10 `SourceRowNumber` anchoring. A second renderer will drift from it. If it cannot be reused read-only, say why.
- **Reuse the P8.2 error-report export** rather than adding a second export path.
- **Read-only.** No edit, no decision changes, no re-trigger from the view — those belong to the wizard's review step, which has the state machine to support them.

---

## Authorization and tenancy — do not skip

- The list and the detail must be scoped to the caller's tenant and enforced **server-side**. A session id in a URL or a dialog parameter is user-supplied; never trust it. Confirm how the existing session-list query scopes by `CompanyId` and follow it exactly.
- Cross-grid authorization applies: a user with Contact-Import rights must not view a `BULKDONATION` session. `ImportGridAuthorization.EnsureGridAccessAsync` is the existing check (P1) — route through it, do not reimplement.
- Apply P6.6 `sanitizeCell` to every displayed cell value **and** to column headers (headers are tenant-authored on `ImportGridFields`).
- No blob URLs, no connection details, no raw SP text in the view (P1.7).

---

## Header and breadcrumb — adopt the app-standard component

The import wizard's header must look and behave like every other screen. Reference screen: **Grid Management**, `/en/setting/gridmanagement/grid`.

**Do not build a new generic header component. One already exists and is the app standard.**

`presentation/components/custom-components/page-header/screen-header.tsx` — `ScreenHeader` — is used by 40+ screens including Grid Management (`grid-config-page.tsx:88`), Contact index and GlobalDonation index. It already provides title, description tooltip, icon, breadcrumb trail, loading skeleton, a `headerActions` right slot and an optional fullscreen toggle.

**What import does instead.** `import-wizard-container.tsx:1046-1122` hand-rolls a near-copy of it — the `<h1>` at `:1076` carries `ScreenHeader`'s exact class string. The copy has since drifted:

| | `ScreenHeader` | import's copy |
|---|---|---|
| container | `bg-card`, `px-4 sm:px-6`, `border-b-2 border-foreground/10`, `shadow-sm` | `bg-background`, `px-3 sm:px-4`, `border-b border-border`, no shadow |
| Home crumb | active module's landing route via `useModuleHomeHref()` | **hardcoded `/${lang}/masterdashboard`** |
| info tooltip | `side="right"` | `side="bottom"` |

That is the visible non-uniformity: different background, lighter border, no shadow, tighter padding.

**The Home crumb is a real bug, not just a style drift.** `screen-header.tsx:58-65` documents why: `/masterdashboard` is the platform control plane and was never a tenant destination, so Home must resolve to the module the user is actually in. Import's hardcoded crumb sends tenant users somewhere wrong. Adopting `ScreenHeader` fixes it as a side effect — do not port the hardcoded href across.

**The work:**

- Replace the hand-rolled block at `:1046-1122` with `ScreenHeader`. Pass `title`, `description`, `icon`, and the trailing crumbs — **omit the Home crumb**, `ScreenHeader` prepends it correctly (`:66-78`). Keep the existing module / menu / grid / Import trail below it.
- The **SignalR live indicator** (`:1107-1120`) moves into `headerActions`. No component change needed.
- The **back button** (`:1051-1066`) sits to the *left* of the icon, and `ScreenHeader` has no leading slot. This is the only genuine gap. Add one **generic** optional prop to `ScreenHeader` for it — a leading node or a back-navigation option, your call — and justify the shape you chose. It must be usable by any screen, not named or typed for import. Default behaviour for the 40+ existing callers must be unchanged; do not make the prop required and do not alter the current DOM when it is absent.
- Apply the same header to the **session list / index** view, so the wizard and the list are not two different-looking screens.
- Do **not** restyle `ScreenHeader` to match import. Uniformity means import moves to the standard, not the standard bending to one screen.

Before writing anything, read `screen-header.tsx` in full and `grid-config-page.tsx:88-100` for how a compliant caller passes crumbs.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. The final column set, with a one-line justification each.
2. How progress is derived per status, and how a stalled `Importing` session is detected and shown.
3. Dialog vs route for View, with reasoning.
4. How the summary-only (staging dropped) mode presents, and how you tested it.
5. What you reused vs wrote new — specifically the row renderer and the export.
6. Confirmation that tenant + grid authorization are enforced server-side.
7. Any migration needed, by name — and if you believe one is needed, why the existing fields were insufficient.
8. The prop you added to `ScreenHeader` for the leading/back slot, and confirmation that existing callers render unchanged.
9. Anything you could not complete and why.
