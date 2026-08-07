# Data Purge — soft delete, restore, and hard delete (platform side)

> **Status:** NOT BUILT (written 2026-08-06)
> **Do NOT run before the MVP-1 demo (6 Aug 2026 17:00).** §③ needs a migration; there is no safe window.
> **Order:** after `PSS-2.0-TENANT-ACCESS-CONTROL-BUILD-PROMPT.md`.
> **Prerequisite:** §⓪ Q1 and Q2 answered. The build branches on both.

---

## ⚠️ Standing rules (non-negotiable)

1. **Do NOT run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add/remove` or `database update`. Never hand-author a migration or a snapshot. Produce a **migration spec**; the user authors and applies it.
3. Seeds go to `sql-scripts-dyanmic/`. The user applies them.
4. **No raw SQL.** No `ExecuteSqlRawAsync`, no `FromSqlRaw`, no string-built SQL — anywhere, including the hard-delete path. `ExecuteDeleteAsync` / `ExecuteUpdateAsync` over a LINQ `IQueryable` are EF and are allowed. This rule is why §④.5 is written the way it is; do not "simplify" it back to a SQL script.
5. Frontend typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, **no pipe**. Only exit 0 counts.
6. `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored — Grep/Glob return nothing. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory. A repo-wide backend grep times out at 120 s. Absolute-path `Read` works.
7. HotChocolate strips `Get` from resolver names and appends `Input` to input types. tsc cannot see gql field names — a wrong name builds clean and fails only at runtime.
8. Every Postgres date column is `timestamp with time zone`. `DateTime.UtcNow` only; never `DateTime.Today` in an EF predicate.
9. `ops` / `billing` are platform-global: every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
10. Never assume a GraphQL field, DTO property, or column name — read the source first.
11. Widget/KPI icon containers and status badges: solid `bg-X-600` + `text-white`. Never `bg-X-50/100`, `text-X-700/800`, or `bg-muted`.
12. RBAC writes stay soft-delete only. Nothing in this prompt hard-deletes an `auth.*` row except as part of a **tenant** hard delete, and only for rows that belong to that tenant.

---

## §⓪ Blocking questions — answer before writing any code

### Q1 — is there a platform-level settings store?

The retention thresholds ("a lead untouched for N days is a purge candidate", "a soft-deleted record may be hard-deleted after M days") must be **configuration, not constants**. `sett.OrganizationSettings` is tenant-scoped and is the wrong home for a platform value.

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('ops','billing')
  AND (table_name ILIKE '%setting%' OR table_name ILIKE '%config%' OR table_name ILIKE '%param%')
ORDER BY 1,2;
```

| Result | Consequence |
|---|---|
| A platform settings/KV table exists | Store the four §②.6 keys there. No new table for config. |
| Nothing exists | §③.2 adds the four keys as columns on a single-row platform settings table — **raise this back to the user before inventing one.** Do not hard-code the numbers. |

### Q2 — does `ops.Leads` record last contact?

`Lead` (read `Base.Domain/Models/OpsModels/Lead.cs`) has **no `LastContactedOn` column**. The stale-lead rule the user described — *"certain days the leads not communicated"* — has nothing truthful to measure unless one of these is true:

```sql
-- is there any lead activity/note/timeline table?
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'ops' AND table_name ILIKE '%lead%' ORDER BY 1;
```

| Result | Consequence |
|---|---|
| A lead activity/note table exists | "Last touch" = `MAX(activity timestamp)`, falling back to `Lead.CreatedDate`. Correct. |
| Only `ops.Leads` exists | "Last touch" = `COALESCE(ModifiedDate, CreatedDate)`. **This is a proxy, not the truth** — an unrelated edit resets the clock, and a genuine phone call does not. Build it, but the UI column must be labelled **"Last updated"**, never "Last contacted". Adding a real `LastContactedOn` is §⑦ (out of scope). |

Record both answers in §⑩ before proceeding.

---

## §① The problem

Two kinds of dead weight accumulate on the platform side, and today there is no way to remove either.

**Dead leads.** A prospect fills the public enquiry form, nobody ever replies, and the row sits in `/ops/leads` forever. `DeleteLeadCommand` exists and soft-deletes one lead at a time, but:
- it is buried on the row, not surfaced as a reviewable list of stale candidates;
- it writes **no audit row** — `ops.PlatformAuditLog` never learns the lead existed;
- it is **not reversible from the UI** — once `IsDeleted = true`, the lead is gone from every query and only a manual SQL `UPDATE` brings it back;
- it never physically removes anything, so a test-data flood or a GDPR erasure request has no answer.

**Dead tenants.** Provisioning fails at step 4, or a trial tenant is created for a demo and abandoned. `app.Companies` keeps the row, `ops.TenantProvisioningRuns` keeps the run, and every tenant-owned table keeps whatever the half-finished steps wrote. `AbandonProvisioningRunCommand` marks the *run* abandoned — it does not touch the company or anything the run created. There is no delete of any kind for a tenant.

**What is missing, precisely:**

| Gap | Consequence today |
|---|---|
| No hard delete anywhere | Test tenants and abandoned prospects are permanent. No GDPR erasure path. |
| No restore | Soft delete is a one-way door in the UI. Operators avoid using it, so nothing gets cleaned. |
| No blast-radius preview | Nobody can see what a delete would destroy before pressing it. |
| No audit on delete | The one destructive operation on the platform is the one with no paper trail. |
| No candidate list | Cleanup requires knowing which rows are stale; nothing computes that. |

---

## §② The design

### ②.1 Two doors, and the second only opens through the first

There is exactly one legal sequence. **Nothing live can be hard-deleted.**

```
LIVE ──[soft delete + reason]──▶ SOFT-DELETED ──[cooling-off elapses]──▶ hard delete permitted
                                      │
                                      └──[restore]──▶ LIVE
```

| | Soft delete | Hard delete |
|---|---|---|
| What it does | `IsDeleted = true` on the target and its cascade | Physically removes the rows |
| Reversible | **Yes**, via Restore | **No** |
| Precondition | Target is live and passes §②.4 | Target is **already soft-deleted** and the cooling-off window has elapsed |
| Capability | `PLATFORM_DATA_PURGE` | `PLATFORM_DATA_PURGE_HARD` (a **separate** capability) |
| Confirmation | Reason + typed confirmation | Reason + typed confirmation + the record-count table re-shown |
| Audit | `ops.PlatformAuditLog` + `ops.DataPurgeRequests` | Both, and the purge row **survives the delete** |

**Why the two-key model:** an operator cleaning up test data and an operator destroying a real customer's history perform the same click today. Forcing the sequence means the destructive action is always a *second*, deliberate, later act on something already marked dead — and the cooling-off window is the time in which somebody notices the mistake and presses Restore.

Never offer both buttons on the same live record. A live record shows **Delete**. A soft-deleted record shows **Restore** and — only once eligible — **Delete permanently**.

### ②.2 One table records the whole lifecycle

`ops.DataPurgeRequests` (§③.1) is the spine. One row per purge, created at soft delete, updated on restore or hard delete. It carries:

- the **count snapshot** taken at soft-delete time (`CountsJson`) — this is what makes the hard-delete dialog honest, and it is the only surviving description of a tenant after its rows are gone;
- the **cascade manifest** (`ManifestJson`) — exactly which tables and which key ranges were soft-deleted, so Restore can undo precisely that and nothing else;
- the reason, actor, and timestamps for all three transitions.

**Why the manifest matters:** a tenant's soft delete cascades to rows that may *already* have been soft-deleted for unrelated reasons. A naive restore (`WHERE CompanyId = X SET IsDeleted = false`) resurrects rows the tenant deleted itself months ago. The manifest records only the ids this purge flipped, so Restore flips back only those.

`ops.DataPurgeRequests` is **never** hard-deleted by anything in this build.

### ②.3 The blast-radius preview — counts with business titles

Both dialogs open on a preview query, not on a guess. The preview returns a list of `{ title, count }`, non-zero only, largest first:

```
Contacts .................. 1,284
Donations ................... 962
Receipts .................... 940
Cases ....................... 118
Volunteers ................... 74
Users ......................... 9
```

**How the list is built — reflection over the EF model, not a hand-written list.** A hand-maintained table list is wrong the day someone adds an entity, and wrong silently.

```
foreach entityType in Db.Model.GetEntityTypes():
    if entityType has a property named "CompanyId"  →  it is tenant-owned
```

Count each with a generic helper (`CountForCompanyAsync<T>` invoked by reflection over the CLR type) filtered on `CompanyId == companyId` **and** `IsDeleted != true`, with `IgnoreQueryFilters()`.

**The title is business language, not the table name.** Resolve in this order:
1. an explicit override map for the entities whose CLR name reads badly (`GlobalDonation` → **Donations**, `Staff` → **Staff members**, `MasterData` → **Reference data**);
2. otherwise, humanise + pluralise the entity CLR name (`FamilyMember` → **Family members**).

Keep the override map in one `static readonly Dictionary<string,string>` next to the helper so it is one place to edit.

**Rules for the preview:**
- Zero-count entities are **omitted**. A wall of `0`s hides the three lines that matter.
- Purely structural join tables (`RoleCapabilities`, `UserRoles`, `RoleModules`) are grouped into one synthetic line **"Roles & permissions"** with the summed count. An operator does not need to read six join-table names.
- Show the **total** underneath, and the count of distinct categories.
- The preview is a **query**, gated by the *view* capability, and must never write anything.

For a **lead**, the same shape applies but the list is short and fixed: the lead itself, its commercial terms (split draft / submitted+), and any provisioning runs that reference it.

### ②.4 What can never be deleted

Enforce in the backend. The UI hides the button; the handler is what makes it true.

**A lead may not be soft-deleted when:**
- `ConvertedCompanyId IS NOT NULL` — it became a tenant; it is now the sales record of a live customer *(already enforced in `DeleteLeadCommand`)*;
- it has a `CommercialTerm` with `ApprovalStatus != DRAFT` *(already enforced)*.

**A tenant may not be soft-deleted when:**
- `Company.Status` is `ACTIVE` and the tenant has any successful payment or issued invoice. Money moved. Suspend it, do not delete it;
- a provisioning run for it is currently `RUNNING`. Abandon the run first.

**Nothing may be HARD-deleted when:**
- it is not already soft-deleted;
- the cooling-off window has not elapsed (§②.6);
- **financial records exist** — any `billing.*` row (invoice, payment, subscription with a paid period) or any tenant-side receipted donation. This is a legal retention line, not a preference. The handler must report *which* category blocked it, by name and count, so the operator is not left guessing;
- the actor lacks `PLATFORM_DATA_PURGE_HARD`.

A blocked hard delete is a `BadRequestException` with the blocking category named — never a silent no-op and never a generic "cannot delete".

### ②.5 Confirmation is typed, and the reason is mandatory

- **Soft delete:** reason required, minimum 10 characters. Free text, stored on the purge row and on the audit row.
- **Hard delete:** reason required (min 10), **plus** the operator must type the target's exact name — the lead's `CompanyName`, or the tenant's `CompanyName` — into a confirm field. Case-insensitive, trimmed. The button stays disabled until it matches.
- **Restore:** reason required (min 10). Restoring is also a decision somebody may need to explain.

The record-count table is shown in **all three** dialogs. In the hard-delete dialog it comes from `CountsJson` on the purge row (the snapshot taken at soft-delete time), not from a fresh query — the rows are already invisible to a normal read, and a fresh count would show zeros and read as "nothing will be lost".

### ②.6 Retention thresholds are configuration

Four keys, stored per §⓪ Q1. Ship defaults, never hard-code them at a call site:

| Key | Default | Meaning |
|---|---|---|
| `PURGE_LEAD_STALE_DAYS` | 90 | A lead untouched this long is listed as a purge candidate. **Listing only — never auto-deletes.** |
| `PURGE_TENANT_STALE_DAYS` | 30 | A tenant that never finished provisioning and has been idle this long is a candidate. |
| `PURGE_HARD_DELETE_COOLING_OFF_DAYS` | 30 | Time between soft delete and hard delete becoming permitted. |
| `PURGE_CANDIDATE_LIST_MAX_ROWS` | 500 | Guard on the candidate query. |

**Nothing in this build deletes automatically.** No background job, no scheduled sweep. The thresholds decide what appears on a review list; a human decides what happens to it. An automatic purge is §⑦.

### ②.7 Where it lives in the UI

| Surface | What is added |
|---|---|
| `/ops/leads` (list) | A **Show deleted** toggle. Deleted rows render dimmed with a `Deleted` chip and a Restore action. |
| `/ops/leads` (row actions) | **Delete** on live rows. On deleted rows: **Restore**, and **Delete permanently** once eligible. |
| `/ops/tenants/{id}` | A **Danger zone** section at the bottom of the tenant detail page — same three actions, same rules. |
| `/ops/data-cleanup` (new) | The candidate review screen: two tabs, **Stale leads** and **Abandoned tenants**, each a grid of candidates with their last-touch date and an inline Delete. Plus a third tab, **Recently deleted**, listing `ops.DataPurgeRequests` with Restore / Delete-permanently. |

The Danger zone follows the platform convention: solid `bg-red-600` + `text-white` on the destructive button, a `border-red-600/30 bg-red-600/5` container, never a muted panel.

---

## §③ Schema — migration spec (user-owned, do NOT author)

Write the spec into `PSS-2.0-DATA-PURGE-MIGRATION-SPEC.md`. Do not run any `dotnet ef` command.

### ③.1 New table `ops.DataPurgeRequests`

| Column | Type | Null | Notes |
|---|---|---|---|
| `DataPurgeRequestId` | `int` identity | no | PK |
| `TargetType` | `varchar(20)` | no | `LEAD` \| `TENANT` |
| `TargetId` | `int` | no | `LeadId` or `CompanyId`. **No FK** — the row must survive a hard delete of its target |
| `TargetName` | `varchar(400)` | no | Snapshot. The only human-readable trace left after a hard delete |
| `Mode` | `varchar(10)` | no | `SOFT` \| `HARD` — the mode of the **latest** transition |
| `Status` | `varchar(20)` | no | `SOFT_DELETED` \| `RESTORED` \| `HARD_DELETED` |
| `CountsJson` | `text` | yes | The §②.3 preview snapshot at soft-delete time |
| `ManifestJson` | `text` | yes | Cascade manifest — table → key list flipped by THIS purge |
| `Reason` | `varchar(2000)` | no | Soft-delete reason |
| `RestoreReason` | `varchar(2000)` | yes | |
| `HardDeleteReason` | `varchar(2000)` | yes | |
| `HardDeleteEligibleOn` | `timestamptz` | no | `RequestedOn + PURGE_HARD_DELETE_COOLING_OFF_DAYS`, stamped at soft delete |
| `RequestedByUserId` / `RequestedByUserName` | `int?` / `varchar(200)` | | Name is a snapshot |
| `RequestedOn` | `timestamptz` | no | |
| `RestoredByUserId` / `RestoredByUserName` / `RestoredOn` | | yes | |
| `HardDeletedByUserId` / `HardDeletedByUserName` / `HardDeletedOn` | | yes | |
| `IpAddress` | `varchar(64)` | yes | |
| *(base `Entity` audit columns)* | | | `CompanyId` must **not** be added — this is platform-global, exactly like `PlatformAuditLog` |

Indexes: `(TargetType, TargetId)`; `(Status, HardDeleteEligibleOn)` for the eligibility list.

**No `CompanyId` property on the entity** so the convention tenant filter never attaches — same reasoning as `PlatformAuditLog`. Every read still needs `IgnoreQueryFilters()` + an explicit `IsDeleted != true`.

### ③.2 Platform settings keys

Per §⓪ Q1. If a KV table exists → seed four rows in `sql-scripts-dyanmic/platform-purge-retention-seed.sql`. If it does not → **stop and ask**; do not invent a table.

### ③.3 Capabilities

Seed `sql-scripts-dyanmic/platform-data-purge-capability-seed.sql`:
- `PLATFORM_DATA_PURGE` — soft delete + restore
- `PLATFORM_DATA_PURGE_HARD` — hard delete only
- a `PLATFORM_DATA_CLEANUP` menu for `/ops/data-cleanup`

Grant both to `SUPERADMIN` and to the platform admin role. Match SUPERADMIN by `RoleCode` **alone** — joining `AND r."CompanyId" IS NULL` has silently inserted zero rows in this database. Soft-delete-and-reinsert, never `DELETE`.

### ③.4 Verify before building

```sql
-- does the tenant have money? (drives §②.4's hard block — confirm the real table names first)
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'billing' ORDER BY 1;

-- how many entities are actually tenant-owned? sanity-check the reflection sweep against this
SELECT COUNT(*) FROM information_schema.columns
WHERE column_name = 'CompanyId' AND table_schema IN ('app','auth','sett','finance','audit');
```

---

## §④ Backend

All new files under `Base.Application/Business/OpsBusiness/DataPurge/`.

### ④.1 `PurgeScopeResolver` — the shared, single source of truth

One class. Both the preview and the delete use it, so they can never disagree about what belongs to a tenant.

- `IReadOnlyList<PurgeTableDescriptor> ResolveTenantOwnedEntities()` — the reflection sweep of §②.3, cached in a `static Lazy<>` (the EF model does not change at runtime).
- `Task<List<PurgeCountDto>> CountAsync(int companyId, ct)` — the titled counts.
- `IReadOnlyList<PurgeTableDescriptor> DeletionOrder()` — the tenant-owned entities **topologically sorted by their EF foreign keys, dependents first**. Derive it from `entityType.GetForeignKeys()`; do not hand-order it. Log and fail loudly on a cycle rather than guessing.

### ④.2 `GetPurgePreviewQuery(targetType, targetId)` → `PurgePreviewResult`

Returns `{ targetName, canSoftDelete, canHardDelete, blockedReasons[], counts[], totalRecords, hardDeleteEligibleOn }`.
Gated by `PLATFORM_TENANT_VIEW` (tenant) / `PLATFORM_LEAD_VIEW` (lead) — read the existing capability codes from the neighbouring queries, do not assume these names. Writes nothing.

### ④.3 `SoftDeletePurgeTargetCommand(targetType, targetId, reason)`

One transaction:
1. Load the target with `IgnoreQueryFilters()`; 404 if absent, `BadRequestException` if already deleted.
2. Run the §②.4 guards. Reject with the blocking category named.
3. Take the count snapshot via `PurgeScopeResolver.CountAsync`.
4. For a **tenant**: walk `DeletionOrder()` and `ExecuteUpdateAsync` `IsDeleted = true, ModifiedDate = UtcNow` on rows `WHERE CompanyId == id AND IsDeleted != true`, **capturing the affected ids first** into the manifest. For a **lead**: reuse the existing `DeleteLeadCommand` guards and cascade, extended to write the manifest.
5. Set `Company.Status = 'DELETED'` (confirm the allowed status values first — §⑨ Q3).
6. Insert the `ops.DataPurgeRequests` row with `CountsJson`, `ManifestJson`, `HardDeleteEligibleOn`.
7. Insert an `ops.PlatformAuditLog` row: `ActionType = "platform.data.softdeleted"`, `EntityType = "Lead" | "Company"`, `TargetCompanyId` set for a tenant, `Description` = the one-liner including the total record count, `Reason`, `ChangesJson = CountsJson`.

Manifest capture must not load whole entities — project ids only (`.Select(x => x.Id).ToListAsync()`), and cap each list; if a table exceeds the cap, record `{ table, count, truncated: true }` and note in §⑥ that Restore falls back to a `CompanyId`-wide flip for that table with an explicit warning in the dialog.

### ④.4 `RestorePurgeTargetCommand(dataPurgeRequestId, reason)`

- Only from `Status = SOFT_DELETED`. Anything else → `BadRequestException` naming the current status.
- Replay `ManifestJson` **in reverse deletion order** (principals first), flipping `IsDeleted = false` only for the recorded ids.
- Restore `Company.Status` to its pre-delete value — store that value in `ManifestJson` at step 5 of §④.3, or it cannot be restored.
- Purge row → `Status = RESTORED`, stamp restorer + reason + `RestoredOn`.
- Audit: `platform.data.restored`.
- **Do not** re-send any welcome/activation email as a side effect of restore. Check `LaunchTenantCommand` is not invoked anywhere on this path.

### ④.5 `HardDeletePurgeTargetCommand(dataPurgeRequestId, reason, confirmName)`

- Requires `PLATFORM_DATA_PURGE_HARD`.
- Requires `Status = SOFT_DELETED` **and** `UtcNow >= HardDeleteEligibleOn` **and** `confirmName` matching `TargetName` (trimmed, case-insensitive). Each failure is its own message.
- Re-run the §②.4 financial block. Do not trust that it was checked at soft-delete time — invoices can be raised in between.
- Walk `DeletionOrder()` and call `ExecuteDeleteAsync()` per entity, filtered on `CompanyId == id` (for a tenant) — **`IgnoreQueryFilters()` is mandatory**, or the soft-deleted rows are invisible and the delete removes nothing while reporting success. One transaction. **No raw SQL** (rule 4).
- Delete the target row last.
- Purge row → `Status = HARD_DELETED, Mode = HARD`, stamped. **The purge row itself is never deleted.**
- Audit: `platform.data.harddeleted`, `Description` naming the target and the total record count from `CountsJson`.
- On any exception the transaction rolls back and the purge row stays `SOFT_DELETED`. Record the failure via the audit log, not by mutating the purge row's status.

### ④.6 `GetPurgeCandidatesQuery(kind, gridFilterRequest)`

`kind` = `STALE_LEADS` | `ABANDONED_TENANTS` | `RECENTLY_DELETED`.

- **Stale leads:** live leads whose last touch (§⓪ Q2) is older than `PURGE_LEAD_STALE_DAYS`, excluding converted leads and leads with non-draft terms — a candidate that cannot be deleted is noise.
- **Abandoned tenants:** companies whose provisioning never reached `SUCCEEDED` and whose run has been idle longer than `PURGE_TENANT_STALE_DAYS`.
- **Recently deleted:** `ops.DataPurgeRequests` with `Status = SOFT_DELETED`, carrying `HardDeleteEligibleOn` so the grid can render "eligible in 12 days".

Cap at `PURGE_CANDIDATE_LIST_MAX_ROWS`. Build boundaries as `DateTime.UtcNow.AddDays(-n)` computed **in C# before** the predicate — never `DateTime.Today`, never date arithmetic inside the EF expression.

### ④.7 GraphQL surface

Register in the ops endpoint alongside the existing tenant/lead resolvers. Remember `Get` is stripped and `Input` appended — the FE documents must use `purgePreview`, `purgeCandidates`, and the mutation names as HotChocolate actually emits them. **Verify the emitted names in the schema before writing the FE documents**; a wrong name compiles clean and fails only at runtime.

---

## §⑤ Frontend

### ⑤.1 `PurgeImpactTable` — one shared component

Used by all three dialogs. Props `{ counts, total, snapshotTakenOn? }`. Renders the titled rows, right-aligned counts, a total row, and — when `snapshotTakenOn` is set (hard-delete dialog) — a line stating the figures are the snapshot from that date. Skeleton rows while the preview query is in flight; the confirm button stays disabled until it resolves.

### ⑤.2 `SoftDeleteDialog` / `RestoreDialog` / `HardDeleteDialog`

- All three: the impact table, a required reason textarea (min 10, live counter), and the blocked-reason list rendered as a red panel with the confirm button disabled when non-empty.
- `HardDeleteDialog` adds the type-the-name field and the sentence **"This cannot be undone."** in `text-red-600 font-semibold`. Its confirm button is `bg-red-600 text-white hover:bg-red-700`.
- `RestoreDialog` is not destructive — normal primary button, no red.
- Every dialog reports the server's error text verbatim via `toast.error`; never replace a named blocking reason with a generic message.

### ⑤.3 `/ops/data-cleanup`

Three tabs per §②.7. Each grid: title, last-touch date, the candidate's key facts, an inline action. The Recently-deleted tab renders `HardDeleteEligibleOn` as a relative chip — `Eligible now` (solid `bg-red-600`) or `Eligible in N days` (solid `bg-amber-600`), white text in both.

### ⑤.4 Wiring

Menu entry gated on `PLATFORM_DATA_CLEANUP`; hard-delete affordances gated on `PLATFORM_DATA_PURGE_HARD` via `usePlatformCapabilities`. Add the Danger zone to the tenant detail page and the Show-deleted toggle to the lead list.

---

## §⑥ Known limits to state in the UI, not hide

1. **Truncated manifest** — if any table exceeded the id cap, the Restore dialog must say so and warn that restore for that table is `CompanyId`-wide and may resurrect rows deleted earlier for other reasons.
2. **Counts are a snapshot** — the hard-delete dialog says the date the figures were taken.
3. **Blob/file storage is not touched** — a hard delete removes database rows only. If a tenant has uploaded documents, they remain in storage. Say this in the hard-delete dialog; wiring storage cleanup is §⑦.
4. **`ops.PlatformAuditLog` and `ops.DataPurgeRequests` survive every purge** by design. A hard delete removes the customer's data, not the record that it happened.

---

## §⑦ Explicitly NOT in this prompt

- Any automatic/scheduled purge. Thresholds list candidates; humans act.
- Blob/document storage cleanup.
- A `LastContactedOn` column on `ops.Leads`, or a lead activity timeline.
- Tenant-side (BUSINESSADMIN) delete of their own data. This is a platform surface only.
- Export-before-delete / data takeout.
- Bulk multi-select delete. One target at a time — deliberately.
- Anonymisation as an alternative to deletion.

---

## §⑧ Acceptance

1. ☐ §⓪ Q1 and Q2 answered and recorded in §⑩
2. ☐ Migration spec written; **not** applied by the agent
3. ☐ `PurgeScopeResolver` finds tenant-owned entities by reflection — no hand-written table list
4. ☐ Deletion order derived from EF foreign keys, dependents first; cycles fail loudly
5. ☐ Preview shows business titles, omits zeros, groups join tables as "Roles & permissions"
6. ☐ Preview writes nothing
7. ☐ Converted lead cannot be soft-deleted (existing guard preserved)
8. ☐ Tenant with a payment/invoice cannot be hard-deleted; the block names the category
9. ☐ Hard delete rejected when the target is not soft-deleted
10. ☐ Hard delete rejected before `HardDeleteEligibleOn`
11. ☐ Hard delete rejected when the typed name does not match
12. ☐ Hard delete requires `PLATFORM_DATA_PURGE_HARD`; soft delete/restore require `PLATFORM_DATA_PURGE`
13. ☐ Every hard-delete `ExecuteDeleteAsync` carries `IgnoreQueryFilters()`
14. ☐ **No `ExecuteSqlRawAsync` / `FromSqlRaw` / string-built SQL anywhere in the diff** — grep the diff to prove it
15. ☐ Restore flips back only the manifest's ids, not everything with that `CompanyId`
16. ☐ Restore returns `Company.Status` to its pre-delete value
17. ☐ Restore sends no email
18. ☐ All three actions write `ops.PlatformAuditLog` **and** update `ops.DataPurgeRequests`
19. ☐ The purge row survives a hard delete of its target
20. ☐ Reason required (min 10) on all three
21. ☐ Retention values read from configuration, not constants
22. ☐ No background job or scheduler added
23. ☐ All date boundaries `DateTime.UtcNow`-derived in C#; no `DateTime.Today` in a predicate
24. ☐ Destructive UI uses solid `bg-red-600` + `text-white`
25. ☐ Truncated-manifest, snapshot-date, and blob-storage limits stated in the dialogs
26. ☐ GraphQL field names verified against the emitted schema, not assumed
27. ☐ `npx tsc --noEmit --incremental false` exits **0**
28. ☐ Backend compiles — **user runs this**

---

## §⑨ Open questions

| # | Question | Blocks |
|---|---|---|
| **Q1** | **§⓪ — is there a platform settings store?** | §③.2. Answer before starting |
| **Q2** | **§⓪ — does anything record lead contact?** | §④.6, the UI column label |
| **Q3** | Is `DELETED` an allowed `Company.Status` value, or does the status enum need extending? If extending, that is part of the §③ migration | §④.3 step 5 |
| Q4 | Cooling-off default — 30 days. Too long for test-tenant cleanup? An override for tenants that never completed provisioning (recommend **7 days** for those) would help | §②.6 |
| Q5 | Should a hard delete be permitted at all on a tenant that once had ANY donation recorded, even unreceipted? Recommend **no** — treat any `finance.*` row as a block | §②.4 |
| Q6 | Should Restore be time-limited too, or restorable indefinitely while soft-deleted? Recommend **indefinite** — the hard delete is the real expiry | §④.4 |
| Q7 | Who may hold `PLATFORM_DATA_PURGE_HARD` — SUPERADMIN only, or platform admins as well? Recommend **SUPERADMIN only** at MVP | §③.3 |
| Q8 | On hard delete of a tenant, do we also remove its `ops.TenantProvisioningRuns` and `ops.Leads` linkage, or keep the sales/provisioning history? Recommend **keep**, nulling `ConvertedCompanyId` | §④.5 |
| Q9 | Does a soft-deleted tenant still count against plan/quota or appear in platform dashboard counts? It must not. Confirm the dashboard queries carry an `IsDeleted` guard | §④.3 |

---

## §⑩ Build log

| Date | Section | What was done | Result |
|---|---|---|---|
| 2026-08-06 | — | Prompt written | Not built |
| 2026-08-06 | §⓪ | **Q1 result (platform settings store) — a store EXISTS; no new table.** `sett.OrganizationSettings` rows with `CompanyId IS NULL` under `SettingGroups.SettingGroupCode = 'PLATFORM'` (`IsVisibleInUI = false`), read through `IPlatformSettingsService` (`GetIntAsync/GetStringAsync/GetBoolAsync/GetDecimalAsync`, scoped, per-request cached, resolution `CurrentValue → ParamDefaultValue → fallback`). Precedent seeds: `sql-scripts-dyanmic/billing-platform-settings-seed.sql`, `notification-platform-settings-seed.sql`. | The four §②.6 keys are seeded there. Every read passes a hard-coded fallback, because the seed is user-applied and may not have run yet — a missing row must degrade, never throw. |
| 2026-08-06 | §⓪ | **Q2 result (lead last-contact) — nothing records contact.** `ops` holds only `Leads` and `LeadAssignments`; `LeadAssignment` is an ownership-episode history (who handed the lead to whom, and when), not an activity or contact log. There is no note, activity, task or email-thread table on the lead — deliberate, per the "thin CRM" scope in §①. | "Last touch" for the stale-lead candidate query = `COALESCE(ModifiedDate, CreatedDate)`. The UI column is labelled **"Last updated"**, never "Last contacted" — the data cannot support that claim. |
| 2026-08-06 | §⑨ | **Q3 answered from source — no schema change.** `CompanyConfiguration.cs:55` is `builder.Property(c => c.Status).HasMaxLength(20);` — plain `varchar(20)`, no CHECK constraint and no DB enum; `Company.Status` is `string?` with documented values `PROVISIONING / ACTIVE / SUSPENDED / CHURNED`. | `'DELETED'` fits as-is. The §③ migration therefore covers **only** the new `ops.DataPurgeRequests` table. |
