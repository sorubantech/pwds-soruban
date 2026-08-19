# Session handoff — import programme (contact done, bulk donation next)

Paste this as the first message of the new session.

---

## Who you are in this session

You are **guiding and tracking** the import programme, not executing phase-1 work — that runs in a
separate session. Your output is almost always **a prompt file on disk under `prompts/`**, grounded
in a real codebase audit, then staged. You do not build unless asked to build.

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`
Backend: `PSS_2.0_Backend/PeopleServe/Services/Base` — **nested git repo**
Frontend: `PSS_2.0_Frontend` — **nested git repo**

---

## Standing rules — non-negotiable

**Git**
- **NEVER `git commit`, in any situation.** Stage only (`git add`) and report. The user commits.
- Never push, amend, tag, or force.
- **Never** add a `Co-Authored-By: Claude` trailer or a "Generated with Claude Code" line to any
  commit message, suggested message, or PR body.
- Commit messages when asked to draft: single line, lowercase, no task/reference numbers.

**Build and run**
- The **user builds the backend**. Never run `dotnet build`.
- The **user creates EF migrations**. Never run `ef migrations add`; never edit
  `ApplicationDbContextModelSnapshot.cs`. Hand off a `migrationBuilder.Sql(...)` body as markdown
  plus an idempotent script under `sql-scripts-dyanmic/`.
- **Never execute SQL against any database.** Write scripts; the user runs them.
- Do not probe ports, processes, or API liveness. Do not gate any deliverable on environment
  readiness. ("avoid api running or not those kind stuff — start next development")
- `BaseUrlConfig.ts` is user-managed — never edit, stage, or revert it.

**Scope**
- No `auth.Modules` / menu / capability **data** changes by this session — produce idempotent seed
  scripts and hand them off.
- New screen ⇒ generate `seed_{entity}_menu.sql` (Menus + MenuCapabilities + RoleCapabilities,
  idempotent, BUSINESSADMIN).
- Do not call the Agent tool, workflows, or deep-research unless explicitly asked.
- Prefer Sonnet over Opus for any spawned agent.

**Quality bar**
- Enterprise application. No shortcuts. Optimize for correctness, maintainability, scalability, UX
  and production readiness — not implementation simplicity.
- Do not simply agree with the existing implementation.
- Never give a vague answer such as "both approaches can be used" — give one answer with reasoning.
- Critical validation must exist at the backend/service layer, not only in the frontend.
- Target is DEV/UAT, MVP-1 realtime — not a product release.
- No `window.prompt` / `alert` / `confirm` anywhere. Dialog components only.
- Never print, echo, or paste a secret value — key *names* only. `appsettings.Development.json` is
  git-ignored and holds live credentials; none of those values may be repeated anywhere.

**Tool hazards in this repo (learned the hard way)**
- `grep -rn` / `find` over the whole repo or over `PSS_2.0_Frontend/src` **times out at 120s**. Use
  the Grep tool with a narrow `path`, or `cd` into a specific directory and use plain `ls`/scoped
  `grep`.
- The Grep tool with **no** `path` silently misses nested-repo files.
- Bash heredocs fail on long markdown (`unexpected EOF`) — **use the Write tool for prompt files**.
- `cd` inside a Bash call does not persist reliably — `cd` explicitly at the start of every command.
- Watch for sibling-worktree drift: agents sometimes write to `pwds-soruban/` without the `- Copy`
  suffix. Verify with `git status`.

---

## Where the programme stands

**Contact import: working.** User confirmed end-to-end — upload → parse → stage → validate → review
→ Import Now (Hangfire) or Schedule (nightly re-validate + execute), with plan-quota gates and
terminal notifications.

**Quota model (established, don't re-derive).** Four gates, all keyed off
`ImportGridDefinition.EntityType` via `ImportQuotaGuard.ResolveMeterCode`:
- **A** advisory — `GetImportQuotaStatus`, review-screen strip, no consequences.
- **B** hard refuse — `EnsureAllowedAsync` at `StartImport.cs:141` / `ScheduleImport.cs:93`, throws
  `PlanQuotaExceededException` → 402 / `PLAN_QUOTA_EXCEEDED`.
- **C** re-check at scheduled re-validation in `ImportScheduledExecutionService`.
- **D** the actual guarantee — `EnsureCapacityAsync` at `ImportExecutionService.cs:365`, inside the
  batch transaction under `pg_advisory_xact_lock`, recounting inside the lock.

Arithmetic: `used + ValidRows <= limit`. `used` is a **live** `COUNT(*)` (`UsageMeterService.CountStockAsync`),
so deletions free quota. `limit == null` is UNLIMITED; `limit == 0` is not-provisioned and
fail-closed. Honest only because the import is **insert-only** — no `ON CONFLICT` upsert branch.
Nothing checks quota before upload/parse/staging (an offered, unaccepted improvement).

**Notification stack.** Dispatch is already fully wired: `ImportNotificationService`, 5 trigger
codes, **9 call sites**, through `INotificationDispatcher` → `INotificationWriter` →
`notify.Notifications`. What is missing is the popup layer, an idempotency key, and any use of
`PushedAt`.

---

## Prompts on disk (all staged, none executed)

| File | State |
|---|---|
| `prompts/import_code_generation_prompt.md` | Handed to user. Blocked on §A.1 — user must run `ContactImport-fn-execute-IDENTIFY.sql` to determine which of three execute-function copies is deployed. §B authors `import.generate_sequence_number`. |
| `prompts/import_pipeline_ux_notification_prompt.md` | Ready. 5-tab wizard + once-only completion popup, grid-neutral. |
| `prompts/bulk_donation_import_development_prompt.md` | Ready. Donation import parity: on-demand, scheduled, quota, route, menu, 3 decisions. |
| `prompts/bulk_donation_pipeline_notification_prompt.md` | Ready. Thin parity pass over the pipeline prompt. |

**Execution order:** `import_code_generation` §B → `bulk_donation_import_development` →
`import_pipeline_ux_notification` → `bulk_donation_pipeline_notification`.

---

## Live findings the new session must not re-derive

1. **`import.generate_sequence_number` does not exist in the repository** — no script, no migration,
   no `DatabaseScripts/Functions/import/` file. Yet `BulkDonationImport-fn-execute.sql:323` calls it
   and its header (26-27) declares it a hard prerequisite. Bulk donation import therefore fails at
   the first row needing a generated receipt number. Check with
   `SELECT to_regprocedure('import.generate_sequence_number(int,text,date)');` — if it exists in the
   DB but not the repo, that is worse: unversioned deployed code.
2. **`NotificationContext` cannot carry a source entity.** It has only `InitiatedByUserId`,
   `AssignedUserId`, `Tokens`. So `NotificationDispatcher.StageAsync` (82-105) never sets
   `SourceEntityType` / `SourceEntityId`, even though `NotificationWriteRequest`,
   `NotificationWriter` (60-130) and the `Notification` entity all support them. ⇒ no idempotency
   key, no deep link.
3. **`Notification.PushedAt` is a dead column** — present in entity and migrations, written by
   nothing. It is the natural server-side "popup already shown" marker.
4. **No new paged results API is needed.** `GetStagingDataQuery(sessionId, PageNumber, PageSize,
   ValidationStatusFilter, **ExecutionStatusFilter**)` already paginates 1-500 and
   `StagingTableService.GetStagingRowsAsync` already returns `ExecutionStatus`,
   `ExecutionStatusName`, `ExecutionError` per row.
5. **`ImportProgressHub` groups per session, not per user** (`JoinSession`). It cannot deliver a
   completion popup to a user who navigated away. Off-page delivery must ride the existing
   visibility-aware badge poll in `presentation/hooks/useNotification/useNotificationCount.ts`.
6. **Both `sonner` and `react-hot-toast` are in `package.json`.** Which is actually mounted is
   unresolved — must be established before building any toast.
7. **The pipeline rail already exists** at `import-wizard-container.tsx:85-150` (`steps` +
   `iconForState`). `WIZARD_TABS` is 3 tabs; the spec wants 5.
8. **The import route is an 8-line shim** — `app/[lang]/(core)/crm/contact/contactimport/page.tsx`
   renders `<ImportPageConfig gridCode="CONTACT" menuCode="CONTACTIMPORT" />`. It is the **only**
   import route in the app; bulk donation has none.
9. **Name collision:** the frontend uses `"BULKDONATION"` as a *data-table* grid code
   (`donation-service-entity-operations.ts:284`) for BulkDonation CRUD — unrelated to
   `import."ImportGridDefinitions"."GridCode" = 'BULKDONATION'`.
10. **The import wizard has zero grid literals** — no `CONTACT`, no `BULKDONATION`. It is fully
    grid-driven. Any grid-specific UI is a defect.
11. Bulk donation grid seed: `EntityType='GlobalDonation'` (→ uppercases to `GLOBALDONATION` →
    `MeterCodes.Donations` ✓), target `fund.GlobalDonations`, `HasChildren=FALSE`, 10 MB / 10,000
    rows. SQL assets exist: `BulkDonationImport-{seed,fn-validate,fn-execute,seed-validation-metadata}.sql`.

---

## Pending on the user (not on you)

- Run `ContactImport-fn-execute-IDENTIFY.sql` — unblocks `import_code_generation_prompt.md` §A.1.
- Custom fields **Track A**: `custom-fields-name-uniqueness-audit.sql` (read-only; sections 1-2 must
  return zero rows) → resolve duplicates → apply `20260818062300_Replace_Field_Name_Unique_Index`.
- **Track B**: `custom-fields-jsonb-plan-verification.sql` → generate DDL via GraphQL
  `customFieldIndexDdl` → run one statement at a time outside any transaction → re-verify.
- **Track C**: `__EFMigrationsHistory` / `to_regclass` check → apply `20260817154323` →
  `ImportCustomFields-seed.sql` + `-fn-build` + `ImportCommon-fn-validate` → verify
  `SELECT "GridCode","CustomFieldGridCode" FROM import."ImportGridDefinitions";` shows
  CONTACT→CONTACT and BULKDONATION→NULL.
- Deploy the corrected `create_staging_table`, then run `Import-repair-staging-execution-columns.sql`.
- Run `ImportCustomFields-negative-scenarios.sql` with real `cfneg.company_id` / `cfneg.user_id`.
- Run `billing-custom-field-governance-audit.sql`, decide numbers, then the quota seed (FREE tenants
  50/5 → 10/2).
- Confirm `20260817091615_Change_Text_To_JsonB_To_CustomFields_In_Contact_Entities` is applied.
- VS: right-click **Base.API** → Set as Startup Project.

## Offered, awaiting the user's call

- Pre-flight quota check in `UploadImportFile` against `TotalRows` (upper bound — can only refuse
  files that could never fit).
- True tenant-local schedule times (needs a company timezone source; `ImportScheduleJob.TimeZoneId`
  and `UpdateImportScheduleJob` already exist).
- Re-authoring a prompt for the stuck-`Uploading` / `Parsing` defects (none on disk).

---

## Decisions already made — do not relitigate

Scheduled/recurring imports stay · media upload stays anonymous · recurring donations stay visible ·
target is DEV/UAT · **CSV upload deferred** · BULKDONATION menu already enabled · **column mapping
deferred, custom fields ship first, template-only upload stays** · template download becomes
tenant-aware · DB segregation planned · `CustomFields` moves `text` → `jsonb` · `Field` uniqueness
splits on `IsSystem`.

## Tracked residue (known, deliberately unfixed)

`CancelImport` has no backend status guard · no exit from `Uploading`/`Parsing` ·
`ImportParseService` writes no `HeartbeatAt` · `IsStalled` scoped to `Importing` only ·
`process_import_upload.sql` Status=1 labelled "Uploaded" while FE maps 1 to a spinner ·
`Import-repair-staging-execution-columns.sql` loop guard tests only `ExecutionStatus` ·
`NullRetentionFallbackDays` still 30 · ~114 inert `enableImport: true` flags ·
`global_search.sql:70` hardcoded `'CONTACT'` · `PREFEREDCOMMUNICATION` typo at
`CommonFormFields.tsx:83` · `StartImportResultDto.JobId` now `string.Empty` · soft-deleted-`Importing`
edge on the P9 partial unique index · `GraphQL__AllowIntrospection=true` on Coolify DEV/UAT · ~50
`masterdashboard` breadcrumb links · import blobs never deleted · `MemoryStream` buffering comment
mismatch in `DownloadImportResultFileAsync` · `ex.Message` infra-name leak in the download handler's
`NotFound`.

---

## Start here

Ask me what to pick up. Do not begin work on any of the above until I say which.
