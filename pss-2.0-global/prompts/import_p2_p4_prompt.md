# Import remediation — P2 (plan quota) · P4 (audit trail)

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`
Plan of record: `prompts/import_gap_remediation_prompt.md`
Prior phases: `prompts/import_p3_1_paging_hotfix_and_p6_prompt.md` (P3.1-A + P6) and
`prompts/import_p3_2_p3_3_p5_prompt.md` (P3.2 + P3.3 + P5) — all complete.

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. Make compiling entity + EF-configuration changes only and hand the migration off by name.
- `PSS_2.0_Backend` and `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server. Seed SQL idempotent: `now()`, double-quoted identifiers, `TRUE`/`FALSE`, `WHERE NOT EXISTS`.
- Enterprise-level app. No shortcuts. Backend/service-layer enforcement, never frontend-only.
- Scheduled imports are staying — management decided. Do not refactor the schedule stack.

**Both subsystems you need already exist and are mature. You are wiring import into them, not building them. Building a parallel mechanism for either one is a failed outcome, no matter how well it works.**

---

## P2 — plan quota on import

### What already exists (read all of it before designing anything)

- `Base.Application/Behaviors/QuotaBehavior.cs` — MediatR pipeline behavior, GATE 2 of three. Reads `MeteredResourceAttribute` off the request type; no attribute means no gate. Bypasses SuperAdmin and background/system contexts (no tenant id). `null` limit = unlimited, `0` = not provisioned / fail-closed.
- **`IBulkMeteredRequest.UnitCount`** — already handled at `QuotaBehavior.cs:63`, and the comment there names this exact scenario: *"a bulk create must be checked as a whole (used + N <= limit); a one-at-a-time check would let a 500-row import walk past a 10-slot remainder."* The seam you need was anticipated. Use it.
- `IUsageMeterService.GetUsedAsync` / `IncrementFlowAsync` / **`EnsureStockCapacityAsync`** — the last one is the drift-free guarantee, taken under `pg_advisory_xact_lock` inside the handler's own transaction. `QuotaBehavior` is explicitly documented as a **pre-check, not the guarantee**.
- `IEntitlementService.GetLimitAsync`, `PlanQuota` (`MeterCode`, `MeterType`, `LimitValue`, `Period`), `MeterTypes.Stock` / `MeterTypes.Flow`, `PlanQuotaExceededException(meterCode, limit, used)`, `FeatureEntitlementBehavior` as GATE 1.

### The three design questions — answer each explicitly in your summary

**1. Which meter does an import consume?**

Do **not** invent an `IMPORT_ROWS` meter as the primary gate. A contact import creates contacts; it must consume the same STOCK meter a hand-typed contact consumes, or the import path becomes a hole in plan enforcement — 10-contact plan, upload 5,000, done. Find the meter code the normal single-record create path uses for contacts and for donations (read the `[MeteredResource]` attributes on those create commands) and consume **those**.

A separate FLOW meter for import *operations* (imports per month) may be worth adding **in addition** — decide and justify. Do not add it silently.

**2. Where does the gate sit? This is the hard part.**

The row count is not known when the file is uploaded — it is known after parse. So the gate cannot live only on the upload command. Map the real sequence first (`UploadImportFile` → parse → `StartValidation` → `Validated` → `StartImport`/`ScheduleImport` → queue → `ImportExecutionService`) and place checks where the count is actually known:

- **After parse / at validation** — the tenant-facing check. Row count is known, nothing has been written to live tables, and the user can be told "this file has 5,000 rows, your plan allows 240 more" *before* they wait for a nightly run. Report it as a **validation-level error on the review screen**, in the same channel P6.2's unknown-column errors use — not as an exception the UI has to interpret.
- **At execution, inside the transaction** — the guarantee. `EnsureStockCapacityAsync` under the advisory lock, exactly as the existing annotated handlers do it. This is what stops two concurrent tenants' imports (or an import racing hand entry) from both passing a pre-check and jointly overshooting.

A pre-check without the execution-time guarantee is not enforcement; a guarantee without the pre-check is terrible UX after a nightly run. Do both.

**3. What happens on a partial overshoot?**

A 5,000-row import against 240 remaining slots. Decide and justify one:
- reject the whole import at validation (simple, predictable, no half-state), or
- import the first 240 rows and mark the rest `Skipped` with a quota reason.

**I would reject the whole file** — a silently truncated import is exactly the failure mode we spent P3.1-A eliminating, and "your file was too big" is a message a user can act on. But make the call yourself with reasoning; if you choose partial, the skipped rows must carry a distinct, visible reason code and the session must NOT be stamped `Completed` without that being obvious.

Also handle: capacity that shrinks between validation and a scheduled 2 AM run (hand entry consumed the slots). The re-validation pass in `ImportScheduledExecutionService` already exists for precisely this class of drift — route the quota check through it and let it land on `ScheduleValidationFailed` (14), which now notifies (P5).

### Constraints

- The background-context bypass at `QuotaBehavior.cs:47-55` means a queued/scheduled import running under a Hangfire principal has **no tenant id and will skip the gate entirely**. Verify this against the actual execution path. If it holds, the execution-time check must resolve the tenant from `ImportSession.CompanyId` explicitly rather than from `ITenantContext` — the same reasoning `WritePaymentEvent` documents for payment flows. **Do not weaken the bypass in `QuotaBehavior`** — other jobs depend on it.
- `PlanQuotaExceededException` must not surface to the review screen as a raw 500. Check how the GraphQL error pipeline currently renders it and match.
- Seed the quota rows idempotently if new meter codes are introduced: `sql-scripts-dyanmic/import-plan-quota-seed.sql`. Mirror an existing `PlanQuota` seed exactly.

---

## P4 — audit trail on import

### What already exists

- `IAuditLogWriter` — the single insert path. Uses a **separate scoped DbContext so rows survive a caller rollback**, and swallows its own failures. Methods: `WriteEntityChange`, `WriteAuthEvent`, `WriteExportEvent`, `WriteWorkflowEvent`, `WritePaymentEvent`.
- `AuditEventPipelineBehavior` — auto-audits by request-name convention (`Export*`, `Approve*`, `Reject*`, `Submit*`). **Import commands match none of these prefixes, which is exactly why import has no audit trail today.**
- `ISelfAuditedRequest` — marker that suppresses the pipeline's low-fidelity fallback row for handlers that write their own high-fidelity row.
- Read surface already built: `GetAuditTrailReport`, `GetAuditTrailById`, `GetAuditTrailByCorrelation`, `GetAuditTrailSummary`, CSV/Excel/PDF exports, `GetTenantAuditTrail`, `GetPlatformAuditTrail`.

### Events to record

| Event | Notes |
|---|---|
| File uploaded | file name, size, grid code, row count once parsed |
| Validation completed | valid / warning / invalid counts |
| **Row decision changed** | a staff member overrode a warning row or omitted it — a human judgement call on data that is about to be written |
| Import triggered | manual vs scheduled vs queue-dispatched, and by whom |
| Import completed | imported / failed / skipped counts, duration |
| Import failed / cancelled | reason; who cancelled |
| **Queue reordered** | who moved whose import ahead of whose — the P9 reorder is a privileged action over other users' work |
| Schedule created / updated / deleted | cron changed |

Row decisions and queue reorder are the two that matter most and are the two a name-prefix convention would never have caught.

### How to write them

- Prefer `WriteEntityChange` with `entityType = "ImportSession"` and `entityId = ImportSessionId` where it fits. Only add a new writer method if none of the five fits — and if you do, justify it, because `IAuditLogWriter` is documented as *the single code path* and a sixth method is a real cost.
- Mark the import commands `ISelfAuditedRequest` **only** where the handler writes its own row.
- **Correlation** — `GetAuditTrailByCorrelation` exists, so a correlation id already threads related rows. Use the import session id as the correlation key so upload → validate → decisions → execute → complete reads as one story. Check how existing callers populate correlation id and match; do not invent a second convention.
- **The Hangfire problem** — scheduled and queue-dispatched execution has no `HttpContext`, so a writer that reads tenant/actor from ambient context will mis-tenant or drop the row. `WritePaymentEvent` takes `companyId` and `userId` explicitly for exactly this reason and documents why. Import has the same shape. Resolve both from `ImportSession` (`CompanyId`, and the user who uploaded/scheduled) and pass them explicitly. **Verify the ambient-context behaviour before relying on it — a silently mis-tenanted audit row is worse than no audit row, because it leaks one tenant's activity into another's trail.**
- Audit must stay non-fatal. `IAuditLogWriter` already swallows; do not add a wrapper that re-throws.
- No file contents, no row data, no PII values in audit rows. Counts, ids, file *name*, decisions — not payloads.

### Retention

Import sessions are high-volume relative to most audited entities. Check whether `AuditLog` already has a retention policy; if it does, confirm import rows fall under it and say so. If it does not, **report that as a finding — do not build a retention system in this phase.**

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. **P2** — the meter code(s) chosen and why, every gate location with its justification, your partial-overshoot decision, and confirmation of whether the background-context bypass affects the execution path.
2. **P4** — the events recorded, which `IAuditLogWriter` method each uses, how correlation is threaded, and how tenant + actor are resolved on the Hangfire path.
3. Any seed file paths for the user to run.
4. Any migration the user needs to create, by name.
5. Anything you could not complete and why.
